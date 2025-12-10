# SQL AI Scripts Overview

End-to-end SQL Server 2025 AI pipeline: enable external endpoints, define credentials and external models, chunk PubMed articles, embed chunks, build vector index, search by similarity, and call Azure OpenAI via REST. Scripts live in `sql/SQL AI`.

## 001_setup.sql
Purpose: enable AI features, create encryption key, define credentials for Azure OpenAI and local Bielik, and register external embedding models.

Key steps and syntax
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

Careful
- Server-level changes require sysadmin; apply in non-prod first.
- Replace placeholder endpoints and keys; protect secrets (Key Vault, secrets store). Do not commit real keys.
- Master key password must be strong; back up key or risk losing access to credentials.
- Azure/Bielik endpoint dimensions must match later table definitions (Bielik PCA 1998 dims; Azure 1536 dims).
- Token limits: long article_text can raise HTTP 400; consider chunking before embedding.

## 002_generate_vectors.sql
Purpose: sample embedding generation for first 10 chunks using Bielik model.

Key query
```sql
-- Generate embeddings for the first 10 chunks with BielikLocal
SELECT TOP (10)
       q.id,
       AI_GENERATE_EMBEDDINGS(q.text_chunk USE MODEL BielikLocal)
FROM [dbo].[pubmed_article_chunk] AS q;
GO
```

Careful
- Row-by-row `AI_GENERATE_EMBEDDINGS` is slow; prefer batch/offline scripts for volume.
- Ensure `pubmed_article_chunk_vector` column type matches Bielik dimension (1998); mismatches will fail at insert time.
- Respect endpoint rate limits; add throttling if looping.

## 003_generate_chunks.sql
Purpose: slice articles into fixed-length chunks and create vector storage table for Bielik embeddings.

Key steps and syntax
```sql
-- Chunk storage table
CREATE TABLE dbo.pubmed_article_chunk (
    id          INT IDENTITY PRIMARY KEY,
    article_id  INT,
    text_chunk  VARCHAR(1500) NOT NULL,
    chunk_order INT,
    CONSTRAINT FK_article_chunks FOREIGN KEY (article_id) REFERENCES pubmed_article(id)
);
GO

-- Generate chunks
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

-- Reset and recreate vector table for Bielik embeddings
DROP TABLE IF EXISTS [pubmed_article_chunk_vector];
GO

CREATE TABLE [pubmed_article_chunk_vector] (
    id     INT PRIMARY KEY,
    vector VECTOR(1998) NOT NULL,
    CONSTRAINT FK_vector_local_main FOREIGN KEY (id) REFERENCES [dbo].[pubmed_article_chunk](id)
);
GO
```

Careful
- DROP is destructive; back up existing vectors before rerun.
- Adjust `chunk_size`/`overlap` to keep text within embedding token limits and preserve context.
- Keep `vector` length aligned with Bielik output dimension (1998). Changing model requires schema change.

## 004_vector_search_distance.sql
Purpose: build cosine index and run both ANN and exact similarity searches for a sample query.

Key steps and syntax
```sql
-- Cosine ANN index on Bielik vectors
CREATE VECTOR INDEX idx_text_vector_cosine
ON dbo.pubmed_article_chunk_vector (vector)
WITH (METRIC = 'cosine');
GO
```

```sql
-- Query embeddings for Bielik and Azure models
DECLARE @query_vector_Bielik VECTOR(1998) =
     AI_GENERATE_EMBEDDINGS('burnout syndrome' USE MODEL BielikLocal);

DECLARE @query_vector_Azure VECTOR(1536) =
     AI_GENERATE_EMBEDDINGS('burnout syndrome' USE MODEL AzureTextEmbeddingSmall);
```

```sql
-- ANN similarity search (Azure vectors)
SELECT  
      v.id,
      vs.distance,            -- cosine distance (0 = identical)
      pac.article_id,
      pac.text_chunk
FROM VECTOR_SEARCH (
        TABLE      = dbo.pubmed_article_chunk_vector_2 AS v,
        COLUMN     = [vector],
        SIMILAR_TO = @query_vector_Azure,
        METRIC     = 'cosine',
        TOP_N      = 10
     ) AS vs
JOIN dbo.pubmed_article_chunk AS pac
      ON pac.id = v.id
INNER JOIN dbo.pubmed_article ap on ap.id = pac.article_id
ORDER BY vs.distance ASC;
```

```sql
-- Exact cosine distances for validation (Azure vectors)
SELECT TOP(10)
      v.id,
      VECTOR_DISTANCE('cosine', @query_vector_Azure, v.[vector]) AS distance,
      pac.article_id,
      pac.text_chunk
FROM dbo.pubmed_article_chunk_vector_2 AS v
JOIN dbo.pubmed_article_chunk AS pac
      ON pac.id = v.id
JOIN dbo.pubmed_article AS ap 
      ON ap.id = pac.article_id
ORDER BY VECTOR_DISTANCE('cosine', @query_vector_Azure, v.[vector]);
GO
```

Careful
- Ensure table/variable dimensions match model (`_vector` = 1998, `_vector_2` = 1536). Mismatch causes errors or bad results.
- Index build can be heavy on large tables; schedule during low-traffic windows.
- ANN results are approximate; use `VECTOR_DISTANCE` for spot-check accuracy but expect full scans to be expensive.
- Use consistent metric: index and queries both set to `cosine`.

## 005_invoke_rest_endpoint.sql
Purpose: call Azure OpenAI chat completion via `sp_invoke_external_rest_endpoint` and parse the response.

Key steps and syntax
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

Careful
- Replace `<foundry>` with your endpoint name and use the correct deployment/model/api-version.
- Credential must reference a scoped credential containing `{"api-key":"..."}`.
- REST call surfaces HTTP codes inside response JSON; check `http_status` for failures and log `full_response` for diagnostics.
- Protect payloads that may contain PII; avoid logging sensitive user prompts in production.

## Running the scripts safely
- Order: 001_setup -> 003_generate_chunks -> (optional) 002_generate_vectors -> 004_vector_search_distance -> 005_invoke_rest_endpoint.
- Permissions: server-level configs need sysadmin; external calls need proper endpoint firewall/VNet rules.
- Performance: batch embedding generation outside T-SQL for large corpora to avoid row-mode overhead and throttling.
- Data safety: avoid rerunning DROP statements on live data without backups.
- Monitoring: capture endpoint latency/errors; ANN index usage may impact CPU during build and warm-up.

## Common references
Key T-SQL features used across the AI pipeline.

| T-SQL feature | Why it matters | Docs |
| --- | --- | --- |
| `sp_configure` / `RECONFIGURE` | Enables scoped credentials and external REST endpoints before external models work. | https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-configure-transact-sql?view=sql-server-ver17, https://learn.microsoft.com/en-us/sql/t-sql/language-elements/reconfigure-transact-sql?view=sql-server-ver17 |
| `ALTER DATABASE SCOPED CONFIGURATION` | Turns on per-database preview flags when migrated DBs need AI features enabled. | https://learn.microsoft.com/sql/t-sql/statements/alter-database-scoped-configuration-transact-sql |
| `CREATE MASTER KEY` | Protects secrets stored in scoped credentials. | https://learn.microsoft.com/sql/t-sql/statements/create-master-key-transact-sql |
| `CREATE DATABASE SCOPED CREDENTIAL` | Stores endpoint headers/API keys used by external models and REST calls. | https://learn.microsoft.com/sql/t-sql/statements/create-database-scoped-credential-transact-sql |
| `CREATE EXTERNAL MODEL` | Registers REST-hosted AI models (Azure OpenAI, local Bielik/Ollama) for in-engine inferencing. | https://learn.microsoft.com/sql/t-sql/statements/create-external-model-transact-sql |
| `AI_GENERATE_CHUNKS` | Splits text into manageable pieces before embedding to stay within token limits. | https://learn.microsoft.com/sql/t-sql/functions/ai-generate-chunks-transact-sql |
| `AI_GENERATE_EMBEDDINGS` | Calls the registered model to produce vectors for text chunks or queries. | https://learn.microsoft.com/sql/t-sql/functions/ai-generate-embeddings-transact-sql |
| `VECTOR` type | Fixed-length numeric vectors used to store embeddings. | https://learn.microsoft.com/en-us/sql/t-sql/data-types/vector-data-type?view=sql-server-ver17&tabs=csharp |
| `CREATE VECTOR INDEX` | Builds ANN indexes for fast similarity search. | https://learn.microsoft.com/sql/t-sql/statements/create-vector-index-transact-sql |
| `VECTOR_SEARCH` | ANN search operator to retrieve top-N similar vectors. | https://learn.microsoft.com/sql/t-sql/functions/vector-search-transact-sql |
| `VECTOR_DISTANCE` | Exact distance computation for validation or small sets. | https://learn.microsoft.com/sql/t-sql/functions/vector-distance-transact-sql |
| `sp_invoke_external_rest_endpoint` | Makes REST calls from T-SQL for chat/inference or utility HTTP calls. | https://learn.microsoft.com/sql/relational-databases/system-stored-procedures/sp-invoke-external-rest-endpoint-transact-sql |
| `JSON_VALUE` | Extracts fields from JSON responses returned by REST calls. | https://learn.microsoft.com/sql/t-sql/functions/json-value-transact-sql |
