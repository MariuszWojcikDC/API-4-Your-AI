# API-4-Your-AI
Local OpenAI-compatible FastAPI endpoints powered by Ollama, wired to SQL Server 2025 AI features, plus scripts to vectorize data and validate the end-to-end pipeline.

## What this repo delivers
- Local HTTPS FastAPI surfaces (embeddings, completions, chat) that mimic OpenAI payloads so you can swap between local Bielik and cloud models without changing clients (see [wiki/python-app-overview.md](wiki/python-app-overview.md)).
- SQL Server 2025 AI/vector pipeline from enabling external REST endpoints to ANN search and REST invocation samples (see [wiki/sql-ai-scripts-overview.md](wiki/sql-ai-scripts-overview.md)).
- End-to-end TLS guidance so SQL Server, FastAPI/Uvicorn, Python clients, and browsers all trust the same cert (see [wiki/ssl-certificate-local-fastapi-sqlserver.md](wiki/ssl-certificate-local-fastapi-sqlserver.md)).
- Model selection notes comparing the local Bielik GGUF model to OpenAI `text-embedding-3-small`, plus Hugging Face/Ollama commands (see [wiki/embedding-models-explained.md](wiki/embedding-models-explained.md) and [wiki/ollama-huggingface-model.md](wiki/ollama-huggingface-model.md)).

## Repo map
- [python/ollama_api_project_with_pca](python/ollama_api_project_with_pca) - main FastAPI app with OpenAI-style routes, PCA reducer targeting SQL Server `VECTOR(1998)`, and TLS-ready launch ([python/run_app_command.txt](python/run_app_command.txt)).
- [python/demo_minimal_embeddings.py](python/demo_minimal_embeddings.py), [python/embeddings_api_basic.py](python/embeddings_api_basic.py), [python/openai_compatible_api.py](python/openai_compatible_api.py) - lighter API variants for smoke tests or SDK compatibility.
- [python/vectorizer/local_vector.py](python/vectorizer/local_vector.py) - async batch vectorizer that posts to the local embedding endpoint (TLS trusted) and inserts vectors into SQL Server.
- [powershell/generate_cert.ps1](powershell/generate_cert.ps1) + [powershell/generate_cert.md](powershell/generate_cert.md) - automation and walkthrough for creating/exporting the local SSL cert.
- [sql/SQL AI](sql/SQL%20AI) - SQL Server setup, chunking, embedding, ANN search, and REST invocation samples.
- [database](database) - sample data (PubMed articles) for the SQL scripts.
- [wiki](wiki) - deeper docs referenced throughout this README; [images](images) holds their screenshots.

## Prerequisites
- Windows with administrator rights for certificate stores and SQL Server configuration.
- SQL Server 2025 (Enterprise/Developer) with required features: Database Engine Services, AI Services and Language Extensions, and Full-Text (see [wiki/sql-server-2025-installation.md](wiki/sql-server-2025-installation.md)). Install ODBC Driver 18 for pyodbc.
- Python 3.12+; install deps with `pip install -r python/ollama_api_project_with_pca/requirements.txt` (FastAPI, uvicorn, ollama, scikit-learn, pyodbc, etc.).
- Ollama installed and running; pull the Bielik GGUF model:  
  `ollama run hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0` (alias option in [wiki/ollama-huggingface-model.md](wiki/ollama-huggingface-model.md)).
- OpenSSL available at `C:\Program Files\OpenSSL-Win64\bin\openssl.exe` (or update the PowerShell script path).
- Trusted local SSL certificate for `localhost` and `127.0.0.1` with an exportable key. Use [powershell/generate_cert.ps1](powershell/generate_cert.ps1) or follow [wiki/ssl-certificate-local-fastapi-sqlserver.md](wiki/ssl-certificate-local-fastapi-sqlserver.md) (CN=localhost, SAN includes localhost and 127.0.0.1).

## Setup flow (start here)
1) **Install SQL Server 2025 with required features**  
   Use [wiki/sql-server-2025-installation.md](wiki/sql-server-2025-installation.md) as a checklist: enable Database Engine Services, AI Services and Language Extensions, and Full-Text. Confirm the service starts.
2) **Create and trust the local TLS cert**  
   Run [powershell/generate_cert.ps1](powershell/generate_cert.ps1) as Administrator to create `LocalhostSSL`, export `.cer/.pfx`, and extract `cert.crt`/`cert.key`. Import the `.cer` into `LocalMachine\Root`, keep the private key in `LocalMachine\My`, and restart SQL Server after trust changes. Manual steps and error explanations are in [wiki/ssl-certificate-local-fastapi-sqlserver.md](wiki/ssl-certificate-local-fastapi-sqlserver.md).
3) **Pull and register the model in Ollama**  
   `ollama run hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0` (or create the `bielik` alias from [wiki/ollama-huggingface-model.md](wiki/ollama-huggingface-model.md)). Ensure `app/config.py` points to the same name.
4) **Configure Python and choose your API tier**  
   Install requirements. For a full surface with PCA, run from [python/ollama_api_project_with_pca](python/ollama_api_project_with_pca):  
   ```bash
   uvicorn app.main:app --host 127.0.0.1 --port 5001 --ssl-certfile "C:\SelfSSL\MyCert\cert.crt" --ssl-keyfile "C:\SelfSSL\MyCert\cert.key"
   ```  
   See [python/run_app_command.txt](python/run_app_command.txt) for the ready-to-run TLS command. Minimal scripts ([python/demo_minimal_embeddings.py](python/demo_minimal_embeddings.py), [python/embeddings_api_basic.py](python/embeddings_api_basic.py), [python/openai_compatible_api.py](python/openai_compatible_api.py)) are available for quick smoke tests.
5) **Run the SQL Server AI pipeline**  
   Order: [sql/SQL AI/001_setup.sql](sql/SQL%20AI/001_setup.sql) (enable external REST, create master key and scoped credentials, register Azure and local models) -> [sql/SQL AI/003_generate_chunks.sql](sql/SQL%20AI/003_generate_chunks.sql) (chunk articles, create `pubmed_article_chunk_vector` with `VECTOR(1998)`) -> [sql/SQL AI/002_generate_vectors.sql](sql/SQL%20AI/002_generate_vectors.sql) (optional slow inline sample) -> [sql/SQL AI/004_vector_search_distance.sql](sql/SQL%20AI/004_vector_search_distance.sql) (build cosine index, test `VECTOR_SEARCH` and `VECTOR_DISTANCE`) -> [sql/SQL AI/005_invoke_rest_endpoint.sql](sql/SQL%20AI/005_invoke_rest_endpoint.sql) (call Azure OpenAI via `sp_invoke_external_rest_endpoint`). Replace placeholder endpoints/keys before running.
6) **Batch vectorize from Python (faster than T-SQL loops)**  
   [python/vectorizer/local_vector.py](python/vectorizer/local_vector.py) reads `pubmed_article_chunk`, posts micro-batches to the local embeddings endpoint over HTTPS, and inserts into `pubmed_article_chunk_vector`. Configure connection strings, table names, batch sizes, `embedding_api_url`, and `cafile="C:/SelfSSL/MyCert/cert.crt"`.
7) **Validate search and REST**  
   Use [sql/SQL AI/004_vector_search_distance.sql](sql/SQL%20AI/004_vector_search_distance.sql) to compare ANN vs exact cosine distances and ensure dimensions match (`VECTOR(1998)` for Bielik, `VECTOR(1536)` for `text-embedding-3-small`). Use [sql/SQL AI/005_invoke_rest_endpoint.sql](sql/SQL%20AI/005_invoke_rest_endpoint.sql) to exercise Azure chat and inspect `http_status` from the response JSON.

## Pick an API tier (OpenAI-compatible)
- [python/demo_minimal_embeddings.py](python/demo_minimal_embeddings.py) - smallest surface (generate + embeddings), ideal to verify Ollama connectivity and payload shapes.
- [python/embeddings_api_basic.py](python/embeddings_api_basic.py) - adds OpenAI-style `index` and `usage` to the embeddings response for basic client integration.
- [python/openai_compatible_api.py](python/openai_compatible_api.py) - full embeddings/completions/chat surface matching OpenAI schemas for SDK drop-in tests.
- [python/ollama_api_project_with_pca](python/ollama_api_project_with_pca) - modular app with routers and optional PCA reducer. PCA trims Bielik's 2,048-dim embeddings to 1,998 for SQL Server; if no PCA file exists, it slices to 1,998 so the service stays online (train a PCA file for better quality).

## SQL AI scripts quick reference ([sql/SQL AI](sql/SQL%20AI))
- [001_setup.sql](sql/SQL%20AI/001_setup.sql) - enable `sp_configure` flags, create the database master key, scoped credentials for Azure and local HTTPS, and register external embedding models. Replace placeholder endpoints/keys; keep vector dimensions aligned with your models.
- [003_generate_chunks.sql](sql/SQL%20AI/003_generate_chunks.sql) - create `pubmed_article_chunk`, generate fixed chunks via `AI_GENERATE_CHUNKS`, and build `pubmed_article_chunk_vector` with `VECTOR(1998)` (drop/recreate warning).
- [002_generate_vectors.sql](sql/SQL%20AI/002_generate_vectors.sql) - sample embedding generation for the first 10 chunks using `BielikLocal` (illustrative; slow for volume).
- [004_vector_search_distance.sql](sql/SQL%20AI/004_vector_search_distance.sql) - create a cosine ANN index, generate query vectors for Bielik (1998) and Azure (1536), run `VECTOR_SEARCH`, and validate with `VECTOR_DISTANCE`.
- [005_invoke_rest_endpoint.sql](sql/SQL%20AI/005_invoke_rest_endpoint.sql) - call Azure OpenAI chat via `sp_invoke_external_rest_endpoint`, then parse `assistant_reply` and `http_status` with `JSON_VALUE`.
- Recommended order: 001_setup -> 003_generate_chunks -> (optional) 002_generate_vectors -> 004_vector_search_distance -> 005_invoke_rest_endpoint.

## Embedding models in this repo
- `text-embedding-3-small` - dedicated embedding model (1536 dims); high-quality semantic search vectors. Requires Azure/OpenAI API (see [sql/SQL AI/001_setup.sql](sql/SQL%20AI/001_setup.sql) placeholders).
- `Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0` - local generative LLM used here for demo embeddings. Outputs up to 2,048 dims; PCA or slicing to 1,998 is required for SQL Server inserts. Good for offline pipeline demos, not a strong semantic search model (see [wiki/embedding-models-explained.md](wiki/embedding-models-explained.md)).
- Hugging Face/Ollama usage and aliasing instructions live in [wiki/ollama-huggingface-model.md](wiki/ollama-huggingface-model.md).

## TLS quick reference and common errors
- Certificate must be created/imported under `Cert:\LocalMachine\My` (with private key, exportable) and `Cert:\LocalMachine\Root` (trust). CN=localhost; SAN includes `localhost` and `127.0.0.1`.
- Uvicorn uses `cert.crt`/`cert.key`; Python clients must trust the same `cert.crt` via `cafile`. SQL Server requires the cert chain to be trusted or it returns `HRESULT: 0x80070018`.
- If browsers or Python warn about trust, re-import the `.cer` into Trusted Root and restart affected services. If SQL inserts fail on dimension, confirm PCA output length and table `VECTOR` length match.

## Where to dive deeper
- TLS and manual cert steps: [wiki/ssl-certificate-local-fastapi-sqlserver.md](wiki/ssl-certificate-local-fastapi-sqlserver.md)
- SQL pipeline details and docs links: [wiki/sql-ai-scripts-overview.md](wiki/sql-ai-scripts-overview.md)
- FastAPI variants, PCA behavior, and extension tips: [wiki/python-app-overview.md](wiki/python-app-overview.md)
- Model rationale and quality notes: [wiki/embedding-models-explained.md](wiki/embedding-models-explained.md)
- Chunking + Bielik embedding walkthrough with logs and cost notes: [wiki/chunked-embeddings-with-bielik.md](wiki/chunked-embeddings-with-bielik.md)
- Ollama/Hugging Face pull commands and troubleshooting: [wiki/ollama-huggingface-model.md](wiki/ollama-huggingface-model.md)

## PubMed database backup

A backup for the PubMed database is available at [`database/pubmed_backup.txt`](database/pubmed_backup.txt), which contains the public download link (OneDrive) for the full `.bak` file. Download it from that link or directly [here](https://drive.google.com/file/d/1QzYsYoSeJbKXKKSu7nWWZ_rV-Zvjp9NU/view?usp=sharing), then restore the database in SQL Server 2025. The backup already includes embeddings: `dbo.pubmed_article_chunk_vector_2` for `text-embedding-3-small` and `dbo.pubmed_article_chunk_vector` for Bielik.

