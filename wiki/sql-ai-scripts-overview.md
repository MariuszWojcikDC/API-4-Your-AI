# 🚀 SQL AI Scripts Overview

_End-to-end SQL Server 2025 AI pipeline:_  
Enable external endpoints, define credentials and external models, chunk PubMed articles, embed chunks, build vector indexes, run similarity search, and call Azure OpenAI via REST.  
Scripts live in **`sql/SQL AI`**.

---

## 🧩 001_setup.sql  
**Purpose:** Enable AI features, create encryption key, define credentials for Azure OpenAI and local Bielik, and register external embedding models.

### 🔧 Key steps and syntax
```sql
USE pubmed;
GO

EXECUTE sp_configure 'allow server scoped db credentials', 1;
EXECUTE sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;
GO

-- Enable preview features when needed for migrated DBs
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

-- Master key protecting scoped credentials
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MySuperSecretPassword2025!';
GO

-- Azure OpenAI credential and model
CREATE DATABASE SCOPED CREDENTIAL [https://<foundry>.cognitiveservices.azure.com/]
    WITH IDENTITY = 'HTTPEndpointHeaders',
         SECRET = '{"api-key":"my-azure-openai-api-key"}';
GO

CREATE EXTERNAL MODEL AzureTextEmbeddingSmall
WITH (
    LOCATION = 'https://<foundry>.cognitiveservices.azure.com/openai/deployments/text-embedding-3-small/embeddings?api-version=2023-05-15',
    API_FORMAT = 'Azure OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'text-embedding-3-small',
    CREDENTIAL = [https://<foundry>.cognitiveservices.azure.com/]
);
GO

-- Local Bielik credential and model
CREATE DATABASE SCOPED CREDENTIAL [https://127.0.0.1:5001]
    WITH IDENTITY = 'HTTPEndpointHeaders',
         SECRET = '{"api-key":"not important"}';
GO

CREATE EXTERNAL MODEL BielikLocal
WITH (
    LOCATION = 'https://127.0.0.1:5001/openai/deployments/local/embeddings',
    API_FORMAT = 'Azure OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'local',
    CREDENTIAL = [https://127.0.0.1:5001]
);
GO

-- Smoke tests for embeddings and token limits
SELECT AI_GENERATE_EMBEDDINGS('test' USE MODEL BielikLocal);
GO

SELECT TOP (8) a.id,
       AI_GENERATE_EMBEDDINGS(a.article_text USE MODEL AzureTextEmbeddingSmall)
FROM [dbo].[pubmed_article] AS a;
GO
```

### ⚠️ Careful
- Server-level changes require **sysadmin**; apply in non‑prod first.  
- Replace placeholder endpoints/keys; protect secrets (Key Vault).  
- Master key password must be backed up.  
- Ensure embedding dimensions match later table definitions.  
- Token limits may require chunking.

---

## 🧮 002_generate_vectors.sql  
**Purpose:** Sample embedding generation for first 10 chunks using Bielik model.

### 🔧 Key query
```sql
SELECT TOP (10)
       q.id,
       AI_GENERATE_EMBEDDINGS(q.text_chunk USE MODEL BielikLocal)
FROM [dbo].[pubmed_article_chunk] AS q;
GO
```

### ⚠️ Careful
- Row-by-row embedding generation is slow.  
- Ensure column dimension matches **1998**.  
- Rate limits may require throttling.

---

## ✂️ 003_generate_chunks.sql  
**Purpose:** Slice articles into fixed-length chunks and create vector storage table for Bielik embeddings.

### 🔧 Key steps and syntax
```sql
CREATE TABLE dbo.pubmed_article_chunk (
    id          INT IDENTITY PRIMARY KEY,
    article_id  INT,
    text_chunk  VARCHAR(1500) NOT NULL,
    chunk_order INT,
    CONSTRAINT FK_article_chunks FOREIGN KEY (article_id) REFERENCES pubmed_article(id)
);
GO

INSERT INTO pubmed_article_chunk (article_id, text_chunk, chunk_order)
SELECT 
    a.id,
    c.chunk,
    c.chunk_order
FROM pubmed_article AS a
CROSS APPLY AI_GENERATE_CHUNKS(
    source     = a.article_text,
    chunk_type = FIXED,
    chunk_size = 1500,
    overlap    = 15
) AS c;
GO

DROP TABLE IF EXISTS [pubmed_article_chunk_vector];
GO

CREATE TABLE [pubmed_article_chunk_vector] (
    id     INT PRIMARY KEY,
    vector VECTOR(1998) NOT NULL,
    CONSTRAINT FK_vector_local_main FOREIGN KEY (id) REFERENCES [dbo].[pubmed_article_chunk](id)
);
GO
```

### ⚠️ Careful
- `DROP TABLE` is destructive.  
- Chunking strategy impacts embedding quality.  
- Vector length must match model output.

---

## 🔍 004_vector_search_distance.sql  
**Purpose:** Build cosine index and run ANN/exact similarity searches.

### 🔧 Key steps and syntax
```sql
CREATE VECTOR INDEX idx_text_vector_cosine
ON dbo.pubmed_article_chunk_vector (vector)
WITH (METRIC = 'cosine');
GO
```

```sql
DECLARE @query_vector_Bielik VECTOR(1998) =
     AI_GENERATE_EMBEDDINGS('burnout syndrome' USE MODEL BielikLocal);

DECLARE @query_vector_Azure VECTOR(1536) =
     AI_GENERATE_EMBEDDINGS('burnout syndrome' USE MODEL AzureTextEmbeddingSmall);
```

```sql
SELECT  
      v.id,
      vs.distance,
      pac.article_id,
      pac.text_chunk
FROM VECTOR_SEARCH (
        TABLE      = dbo.pubmed_article_chunk_vector_2 AS v,
        COLUMN     = [vector],
        SIMILAR_TO = @query_vector_Azure,
        METRIC     = 'cosine',
        TOP_N      = 10
     ) AS vs
JOIN dbo.pubmed_article_chunk AS pac ON pac.id = v.id
INNER JOIN dbo.pubmed_article ap on ap.id = pac.article_id
ORDER BY vs.distance ASC;
```

```sql
SELECT TOP(10)
      v.id,
      VECTOR_DISTANCE('cosine', @query_vector_Azure, v.[vector]) AS distance,
      pac.article_id,
      pac.text_chunk
FROM dbo.pubmed_article_chunk_vector_2 AS v
JOIN dbo.pubmed_article_chunk AS pac ON pac.id = v.id
JOIN dbo.pubmed_article AS ap ON ap.id = pac.article_id
ORDER BY VECTOR_DISTANCE('cosine', @query_vector_Azure, v.[vector]);
GO
```

### ⚠️ Careful
- Dimensions **must** match model.  
- ANN index build can be resource‑intensive.  
- ANN is approximate—validate with `VECTOR_DISTANCE`.  
- Use consistent metric (`cosine`).

---

## 🌐 005_invoke_rest_endpoint.sql  
**Purpose:** Call Azure OpenAI chat completion via `sp_invoke_external_rest_endpoint`.

### 🔧 Key steps and syntax
```sql
DECLARE @body nvarchar(max) = N'{
  "model": "gpt-4o",
  "messages": [
    { "role": "user", "content": "Hello there! Tell me a joke about SQL Server 2025" }
  ]
}';

DECLARE @ret int, @full_response nvarchar(max);

EXEC @ret = sys.sp_invoke_external_rest_endpoint
    @url = N'https://<foundry>.cognitiveservices.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2024-05-01-preview',
    @method = 'POST',
    @payload = @body,
    @credential = [https://<foundry>.cognitiveservices.azure.com/],
    @response = @full_response OUTPUT;

SELECT @full_response AS full_response,
       JSON_VALUE(@full_response,'$.result.choices[0].message.content') AS assistant_reply,
       JSON_VALUE(@full_response,'$.response.status.http.code') AS http_status;
```

### ⚠️ Careful
- Replace `<foundry>` with valid endpoint.  
- Credentials must contain API key.  
- Check HTTP code for failures.  
- Avoid logging sensitive prompts.

---

## 🛡️ Running the scripts safely
- **Order:** 001 → 003 → (optional 002) → 004 → 005  
- Requires **sysadmin** for server configs.  
- Batch embeddings outside SQL for large corpora.  
- Avoid destructive operations without backups.  
- Monitor latency/errors on external endpoints.

---

## 📚 Common references

| T-SQL feature | Why it matters | Docs |
| --- | --- | --- |
| `sp_configure` / `RECONFIGURE` | Enables scoped credentials and external REST endpoints. | https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-configure-transact-sql?view=sql-server-ver17, https://learn.microsoft.com/en-us/sql/t-sql/language-elements/reconfigure-transact-sql?view=sql-server-ver17 |
| `ALTER DATABASE SCOPED CONFIGURATION` | Enables preview flags needed by AI features. | https://learn.microsoft.com/sql/t-sql/statements/alter-database-scoped-configuration-transact-sql |
| `CREATE MASTER KEY` | Protects secrets for credentials. | https://learn.microsoft.com/sql/t-sql/statements/create-master-key-transact-sql |
| `CREATE DATABASE SCOPED CREDENTIAL` | Stores endpoint headers/API keys. | https://learn.microsoft.com/sql/t-sql/statements/create-database-scoped-credential-transact-sql |
| `CREATE EXTERNAL MODEL` | Registers external REST‑hosted AI models. | https://learn.microsoft.com/sql/t-sql/statements/create-external-model-transact-sql |
| `AI_GENERATE_CHUNKS` | Splits long text into feasible embedding chunks. | https://learn.microsoft.com/sql/t-sql/functions/ai-generate-chunks-transact-sql |
| `AI_GENERATE_EMBEDDINGS` | Produces embeddings. | https://learn.microsoft.com/sql/t-sql/functions/ai-generate-embeddings-transact-sql |
| `VECTOR` type | Stores embeddings as fixed-length arrays. | https://learn.microsoft.com/en-us/sql/t-sql/data-types/vector-data-type?view=sql-server-ver17&tabs=csharp |
| `CREATE VECTOR INDEX` | Builds ANN index. | https://learn.microsoft.com/sql/t-sql/statements/create-vector-index-transact-sql |
| `VECTOR_SEARCH` | Performs ANN search. | https://learn.microsoft.com/sql/t-sql/functions/vector-search-transact-sql |
| `VECTOR_DISTANCE` | Exact comparison of vectors. | https://learn.microsoft.com/sql/t-sql/functions/vector-distance-transact-sql |
| `sp_invoke_external_rest_endpoint` | Executes REST calls from SQL. | https://learn.microsoft.com/sql/relational-databases/system-stored-procedures/sp-invoke-external-rest-endpoint-transact-sql |
| `JSON_VALUE` | Extracts data from JSON. | https://learn.microsoft.com/sql/t-sql/functions/json-value-transact-sql |
