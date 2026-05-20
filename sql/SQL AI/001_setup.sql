USE pubmed;

GO
    -- Enable server-level support for external endpoints and scoped credentials.
    EXECUTE sp_configure 'allow server scoped db credentials',
    1;

EXECUTE sp_configure 'external rest endpoint enabled',
1;

RECONFIGURE WITH OVERRIDE;

GO
    -- In theory it isn�t necessary, but if a database has been migrated from earlier versions of SQL Server, 
    -- sometimes you need to enable preview features for everything to work correctly. 
    -- I think this is probably a bug.
    ALTER DATABASE SCOPED CONFIGURATION
SET
    PREVIEW_FEATURES = ON;

GO
SELECT
    *
FROM
    sys.external_models
SELECT
    *
FROM
    sys.database_scoped_credentials -- DROP EXTERNAL MODEL BielikLocal
    -- DROP DATABASE SCOPED CREDENTIAL  [http://localhost:11434/api/embed]
    -- DROP MASTER KEY
    -- Create the master key protecting database-scoped credentials.
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MySuperSecretPassword2026!';

GO
    -- Credential for Azure OpenAI embedding endpoint.
    CREATE DATABASE SCOPED CREDENTIAL [https://<MS-FOUNDRY-ENDPOINT>.cognitiveservices.azure.com/] WITH IDENTITY = 'HTTPEndpointHeaders',
    SECRET = '{"api-key":"XYZ"}';

GO
    -- External embedding model pointing to Azure OpenAI deployment.
    CREATE EXTERNAL MODEL AzureTextEmbeddingSmall WITH (
        LOCATION = 'https://<MS-FOUNDRY-ENDPOINT>.cognitiveservices.azure.com/openai/deployments/text-embedding-3-small/embeddings?api-version=2023-05-15',
        API_FORMAT = 'Azure OpenAI',
        MODEL_TYPE = EMBEDDINGS,
        MODEL = 'text-embedding-3-small',
        CREDENTIAL = [https://<MS-FOUNDRY-ENDPOINT>.cognitiveservices.azure.com/]
    );

GO
    -- Credential for the local Bielik embedding endpoint.
    CREATE DATABASE SCOPED CREDENTIAL [https://localhost/api/embed] -- Could be different for you depending on how you set up the endpoint
    WITH IDENTITY = 'HTTPEndpointHeaders',
    SECRET = '{"api-key":"not important"}';

GO
    CREATE EXTERNAL MODEL BielikLocal WITH (
        LOCATION = 'https://localhost/api/embed',
        API_FORMAT = 'Ollama',
        MODEL_TYPE = EMBEDDINGS,
        MODEL = 'hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0',
        CREDENTIAL = [https://localhost/api/embed]
    );

GO
    -- Quick smoke test to verify if the model responds.
SELECT
    AI_GENERATE_EMBEDDINGS('test' USE MODEL BielikLocal);

GO
SELECT
    AI_GENERATE_EMBEDDINGS('test' USE MODEL AzureTextEmbeddingSmall);

GO
    -- Table naming convention:
    --   pubmed_article_chunk_vector   -> embeddings from BielikLocal (PCA-reduced 1998 dims)
    --   pubmed_article_chunk_vector_2 -> embeddings from text-embedding-3-small (Azure/OpenAI)
    -- What happens when we exceed the token limit?
    -- http 400 error is returned from the endpoint, no details what exactly happened
SELECT
    TOP (8) a.id,
    AI_GENERATE_EMBEDDINGS(a.article_text USE MODEL AzureTextEmbeddingSmall)
FROM
    [dbo].[pubmed_article] AS a;

GO
    -- Quick check of the dimensions of the returned embeddings.
SELECT
    COUNT(*) AS Dimensions
FROM
    OPENJSON(
        AI_GENERATE_EMBEDDINGS('test' USE MODEL BielikLocal)
    );

SELECT
    COUNT(*) AS Dimensions
FROM
    OPENJSON(
        AI_GENERATE_EMBEDDINGS('test' USE MODEL AzureTextEmbeddingSmall)
    );