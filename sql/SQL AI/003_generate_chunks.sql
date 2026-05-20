USE pubmed;

GO
    -- Create table storing sliced article chunks.
    CREATE TABLE dbo.pubmed_article_chunk (
        id INT IDENTITY PRIMARY KEY,
        article_id INT,
        text_chunk VARCHAR(1500) NOT NULL,
        chunk_order INT,
        CONSTRAINT FK_article_chunks FOREIGN KEY (article_id) REFERENCES pubmed_article(id)
    );

GO
    -- Generate text chunks for each article.
INSERT INTO
    pubmed_article_chunk (article_id, text_chunk, chunk_order)
SELECT
    TOP 10 a.id,
    c.chunk,
    c.chunk_order
FROM
    pubmed_article AS a
    CROSS APPLY AI_GENERATE_CHUNKS(
        source = a.article_text,
        chunk_type = FIXED,
        chunk_size = 1500,
        overlap = 15
    ) AS c;

GO
    -- Reset the vectors table if it already exists.
    DROP TABLE IF EXISTS [pubmed_article_chunk_vector];

GO
    -- Table for embedding vectors for each chunk (Bielik model).
    CREATE TABLE [pubmed_article_chunk_vector] (
        id INT PRIMARY KEY,
        -- also serves as FK
        vector VECTOR(1998) NOT NULL,
        CONSTRAINT FK_vector_local_main FOREIGN KEY (id) REFERENCES [dbo].[pubmed_article_chunk](id)
    );

GO