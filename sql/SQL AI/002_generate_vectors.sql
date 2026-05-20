USE pubmed;
GO

-- Generate embeddings for the first ten chunks using the Bielik model.
-- Table mapping:
--   pubmed_article_chunk_vector   -> Bielik model (local)
--   pubmed_article_chunk_vector_2 -> text-embedding-3-small (Azure/OpenAI)
--INSERT INTO [dbo].[pubmed_article_chunk_vector] (id, vector)
-- but this query runs in row mode only and is very slow
-- better approach is to use other tolls - like script in python with batch mode enabled
SELECT TOP (10)
       q.id,
       AI_GENERATE_EMBEDDINGS(q.text_chunk USE MODEL AzureTextEmbeddingSmall)
FROM [dbo].[pubmed_article_chunk] AS q;
GO
