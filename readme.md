
# 🤖 API-4-Your-AI  
### **OpenAI‑compatible local FastAPI endpoints powered by Ollama - integrated with SQL Server 2025 AI**

Local HTTPS AI endpoints, SQL Server 2025 vector pipeline scripts, TLS automation, embedding workflows, and full end‑to‑end samples.

---

## 🚀 What This Repo Delivers
- **Local HTTPS FastAPI endpoints** (embeddings, completions, chat) mimicking OpenAI payloads → enabling seamless switching between local Bielik and cloud models.  
  _See:_ [`wiki/python-app-overview.md`](wiki/python-app-overview.md)

- **SQL Server 2025 AI/vector pipeline**: enabling external REST endpoints, chunking, embeddings, ANN similarity search, REST invocation.  
  _See:_ [`wiki/sql-ai-scripts-overview.md`](wiki/sql-ai-scripts-overview.md)

- **End-to-end TLS setup** so SQL Server, FastAPI/Uvicorn, Python, and browsers fully trust the same certificate.  
  _See:_ [`wiki/ssl-certificate-local-fastapi-sqlserver.md`](wiki/ssl-certificate-local-fastapi-sqlserver.md)

- **Embedding model notes** including Bielik GGUF vs `text-embedding-3-small`, Hugging Face/Ollama usage, and configuration.  
  _See:_  
  - [`wiki/embedding-models-explained.md`](wiki/embedding-models-explained.md)  
  - [`wiki/ollama-huggingface-model.md`](wiki/ollama-huggingface-model.md)

---

## 🗺️ Repo Map
- **`python/ollama_api_project_with_pca`** - main FastAPI app with OpenAI-style routes, PCA reducer to SQL Server `VECTOR(1998)`, TLS-ready start command.  
- **Light API variants:**  
  - `demo_minimal_embeddings.py`  
  - `embeddings_api_basic.py`  
  - `openai_compatible_api.py`  
- **Vectorizer:**  
  `python/vectorizer/local_vector.py` - async batch embedding generation → SQL inserts.  
- **TLS automation & docs:**  
  - `powershell/generate_cert.ps1`  
- **SQL Server AI pipeline:**  
  `sql/SQL AI` - setup, chunking, embedding, ANN search, REST samples.  
- **Sample data:** `database` (PubMed).  
- **Postman/Bruno quick tests:** [`wiki/postman-bruno-test.md`](wiki/postman-bruno-test.md) - ready-to-send requests for local FastAPI endpoints.  
- **Deep documentation:** `wiki` + screenshots in `images`.

---

## 📦 Prerequisites
- **Windows (Admin rights required)**  
- **SQL Server 2025** (Enterprise/Developer) with:  
  - Database Engine Services  
  - AI Services and Language Extensions  
  - Full‑Text  
  _See:_ [`wiki/sql-server-2025-installation.md`](wiki/sql-server-2025-installation.md)

- **Python 3.12+**  
  `pip install -r python/ollama_api_project_with_pca/requirements.txt`

- **Ollama installed** and pull Bielik:  
  ```
  ollama run hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0
  ```

- **OpenSSL**  
- **Trusted local TLS certificate** for `localhost` + `127.0.0.1` (exportable key).  
  _Use:_ `powershell/generate_cert.ps1`

---

## 🛠️ Setup Flow (Start Here)

### 1️⃣ Install SQL Server 2025 with required features  
Checklist: [`wiki/sql-server-2025-installation.md`](wiki/sql-server-2025-installation.md)

---

### 2️⃣ Create & trust the local TLS certificate  
Run **as Administrator**:

`powershell/generate_cert.ps1`

Produces:

- `LocalhostSSL.cer`, `LocalhostSSL.pfx`  
- `cert.crt`, `cert.key` for Uvicorn  

Import `.cer` into **LocalMachine\Root**, restart SQL Server.

Guide: [`wiki/ssl-certificate-local-fastapi-sqlserver.md`](wiki/ssl-certificate-local-fastapi-sqlserver.md)

---

### 3️⃣ Pull and register Bielik model in Ollama  
```
ollama run hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0
```

Ensure `app/config.py` references the correct name.

---

### 4️⃣ Configure Python and select API tier  
Full PCA-enabled API:

```bash
uvicorn app.main:app --host 127.0.0.1 --port 5001 \
  --ssl-certfile "C:\SelfSSL\MyCert\cert.crt" \
  --ssl-keyfile "C:\SelfSSL\MyCert\cert.key"
```

Minimal API variants available for smoke tests.

---

### 5️⃣ Run the SQL Server AI pipeline  
Order:

1. **001_setup.sql** - enable REST, create keys + credentials, register models  
2. **003_generate_chunks.sql** - chunk text, create vector tables  
3. **002_generate_vectors.sql** - (optional) sample embedding test  
4. **004_vector_search_distance.sql** - ANN + exact cosine validation  
5. **005_invoke_rest_endpoint.sql** - call Azure OpenAI from SQL  

---

### 6️⃣ Batch vectorize from Python  
`local_vector.py`:

- Reads chunks  
- Sends batches to local embedding API (TLS)  
- Inserts vectors into SQL Server  

Configure:

- connection strings  
- batch size  
- API URL  
- `cafile="C:/SelfSSL/MyCert/cert.crt"`

---

### 7️⃣ Validate search + REST integrations  
Use:

- `004_vector_search_distance.sql` → ANN & cosine reference  
- `005_invoke_rest_endpoint.sql` → exercise OpenAI chat call  

Check embedding dimensions:  
- Bielik → **1998**  
- OpenAI `text-embedding-3-small` → **1536**

---

## 🧱 Pick an OpenAI-Compatible API Tier
- **Minimal embeddings:** `demo_minimal_embeddings.py`  
- **Basic OpenAI structure:** `embeddings_api_basic.py`  
- **Full API (embeddings + chat + completions):** `openai_compatible_api.py`  
- **Production-style modular API:** `ollama_api_project_with_pca`

PCA reduces 2,048-dim Bielik vectors → **1,998** for SQL Server.

---

## 🧪 SQL AI Scripts Quick Reference
- **001_setup.sql** - keys, credentials, external models  
- **003_generate_chunks.sql** - chunk text + create vector table  
- **002_generate_vectors.sql** - small embedding demo  
- **004_vector_search_distance.sql** - ANN + cosine validation  
- **005_invoke_rest_endpoint.sql** - Azure OpenAI via REST  

Order: **001 → 003 → (002 optional) → 004 → 005**

---

## 🧬 Embedding Models in This Repo
### ☁️ `text-embedding-3-small`  
- 1536 dims  
- High-quality semantic vectors  

### 🏡 Bielik GGUF (`Q8_0`)  
- 2048 dims raw  
- PCA → 1998 dims  
- Good for offline demos; not state-of-the-art semantic quality  

Model notes: [`wiki/embedding-models-explained.md`](wiki/embedding-models-explained.md)

---

## 🔐 TLS Quick Reference + Common Errors
- Certificate must be in:  
  - `LocalMachine\My` (private key)  
  - `LocalMachine\Root` (trusted)  
- CN = `localhost`  
- SAN = `localhost`, `127.0.0.1`  
- SQL error if cert invalid: **HRESULT 0x80070018**  
- Python error: `SSLCertVerificationError`  
- SQL dimension mismatch → fix PCA output or VECTOR column length  

---

## 📚 Where To Dive Deeper
- Architecture, costs, security guide: [`sqlserver-ai-architecture-costs-security-guide.md`](wiki/sqlserver-ai-architecture-costs-security-guide.md)  
- TLS details: [`ssl-certificate-local-fastapi-sqlserver.md`](wiki/ssl-certificate-local-fastapi-sqlserver.md)  
- SQL pipeline: [`sql-ai-scripts-overview.md`](wiki/sql-ai-scripts-overview.md)  
- FastAPI/PCA notes: [`python-app-overview.md`](wiki/python-app-overview.md)  
- Models explained: [`embedding-models-explained.md`](wiki/embedding-models-explained.md)  
- Chunking + Bielik journey: [`chunked-embeddings-with-bielik.md`](wiki/chunked-embeddings-with-bielik.md)  
- Hugging Face/Ollama pulls: [`ollama-huggingface-model.md`](wiki/ollama-huggingface-model.md)

---

## 📦 PubMed Database Backup
A backup link is available in:

`database/pubmed_backup.txt`

Direct link:  
https://drive.google.com/file/d/1QzYsYoSeJbKXKKSu7nWWZ_rV-Zvjp9NU/view?usp=sharing

Contains embeddings for:  
- `pubmed_article_chunk_vector_2` → OpenAI (1536 dims)  
- `pubmed_article_chunk_vector` → Bielik (1998 dims)

---

## 👤 Author

**Mariusz Wójcik**  
LinkedIn: https://www.linkedin.com/in/mariusz-wojcik/

---

## 🙏 Special Thanks

### For inspiration, and introduction to vectors, embeddings, and FastAPI  
**Michał Kowalczewski**  
LinkedIn: https://www.linkedin.com/in/micha%C5%82-kowalczewski-470b14b4/

### For review and expert support  
**Maciej Kępa**  
LinkedIn: https://www.linkedin.com/in/maciej-kepa/
