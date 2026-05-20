USE pubmed;
GO

-- Table naming convention:
--   pubmed_article_chunk_vector   -> embeddings from BielikLocal (PCA-reduced to 1998 dims)
--   pubmed_article_chunk_vector_2 -> embeddings from text-embedding-3-small (Azure/OpenAI)

------------------------------------------------------------
-- Create cosine vector index
------------------------------------------------------------
SELECT * from sys.vector_indexes

CREATE VECTOR INDEX idx_text_vector_cosine
ON dbo.pubmed_article_chunk_vector (vector)
WITH (METRIC = 'cosine');
GO

------------------------------------------------------------
-- Generate embedding for user query ("burnout syndrome")
------------------------------------------------------------
DECLARE @raw_vector NVARCHAR(MAX) = (SELECT CAST(AI_GENERATE_EMBEDDINGS('burnout syndrome' USE MODEL BielikLocal) AS NVARCHAR(MAX)));

DECLARE @query_vector_Bielik VECTOR(1998);

-- We will need to parse the raw JSON array returned by AI_GENERATE_EMBEDDINGS into the VECTOR format required for VECTOR_SEARCH
SET @query_vector_Bielik = (
    SELECT CAST('[' + STRING_AGG(CAST(value AS NVARCHAR(MAX)), ',') WITHIN GROUP (ORDER BY CAST([key] AS INT)) + ']' AS VECTOR(1998))
    FROM OPENJSON(@raw_vector)
    WHERE CAST([key] AS INT) < 1998
);

-- DECLARE @query_vector_Bielik VECTOR(1998) =
--      AI_GENERATE_EMBEDDINGS('burnout syndrome' USE MODEL BielikLocal);

------------------------------------------------------------
-- Perform vector similarity search
------------------------------------------------------------
SELECT  
      v.id,
      vs.distance,            -- cosine distance (0 = identical)
      pac.article_id,
      pac.text_chunk
FROM VECTOR_SEARCH (
        TABLE      = dbo.pubmed_article_chunk_vector AS v, -- use _vector for BielikLocal or _vector_2 for AzureTextEmbeddingSmall (text-embedding-3-small)
        COLUMN     = [vector],
        SIMILAR_TO = @query_vector_Bielik,
        METRIC     = 'cosine',
        TOP_N      = 10
     ) AS vs
JOIN dbo.pubmed_article_chunk AS pac
      ON pac.id = v.id
INNER JOIN dbo.pubmed_article ap on ap.id = pac.article_id
ORDER BY vs.distance ASC;     -- smaller = more similar


------------------------------------------------------------
-- Exact vector distance computation (brute-force scan)
------------------------------------------------------------
DECLARE @query_vector_Azure VECTOR(1536) =
     AI_GENERATE_EMBEDDINGS('burnout syndrome' USE MODEL AzureTextEmbeddingSmall);

SELECT TOP(10)
      v.id,
      VECTOR_DISTANCE('cosine', @query_vector_Azure, v.[vector]) AS distance,
      pac.article_id,
      pac.text_chunk
FROM dbo.pubmed_article_chunk_vector_2 AS v -- swap to pubmed_article_chunk_vector for BielikLocal
JOIN dbo.pubmed_article_chunk AS pac
      ON pac.id = v.id
JOIN dbo.pubmed_article AS ap 
      ON ap.id = pac.article_id
ORDER BY VECTOR_DISTANCE('cosine', @query_vector_Azure, v.[vector]);
GO


