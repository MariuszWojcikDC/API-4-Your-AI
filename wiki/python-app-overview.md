# 🐍 Python OpenAI‑Compatible APIs - Deep Dive

## 📌 Read This First
- This folder represents **one application expressed at multiple complexity tiers** - pick the tier that matches your skills and integration needs.  
- All variants talk to the same **Bielik 4.5B Ollama model** (`MODEL_NAME` is identical), returning **OpenAI‑shaped responses** so you can switch tiers without rewriting clients.  
- Treat each script as a **learning template**: clone, modify, rerun, and observe how payloads, token usage, and SQL Server storage behave.

---

# 🧗 Complexity Ladder - What Each Tier Gives You

### **1️⃣ `demo_minimal_embeddings.py` - Minimal FastAPI**
- Tiny surface, two endpoints, **no token accounting**.  
- Ideal for smoke‑testing **Ollama connectivity** or teaching request/response structures.

### **2️⃣ `embeddings_api_basic.py` - Add OpenAI‑style `index` + `usage`**
- Good for **real clients** that track token usage.  
- Adds OpenAI‑shaped response fields.

### **3️⃣ `openai_compatible_api.py` - Full Drop‑In OpenAI API**
- Implements **embeddings**, **completions**, and **chat completions** with `choices`, `usage`, and message roles.  
- Suitable for SDKs/tools expecting OpenAI schema.

### **4️⃣ `ollama_api_project_with_pca` - Modular + SQL Server–Ready**
- Package layout with routers/services.  
- Includes **PCA reduction** to fit SQL Server 2025’s **VECTOR(1998)** limit while Bielik outputs **2,048 dimensions**.

---

# 🔍 Detailed Walkthroughs (Code‑Line References)

## ⭐ `demo_minimal_embeddings.py`
- Model is hard‑coded at **line 8**.  
- Simple request/response models (`10–18`).  
- `/generate` proxies directly to `ollama.chat` (`21–27`).  
- `/openai/deployments/local/embeddings` handles list/string inputs, loops, and calls `ollama.embeddings` (`31–42`).  
- Returns OpenAI‑shaped `data[]` without usage totals.

---

## ⭐ `embeddings_api_basic.py`
- Same model anchor (`line 8`).  
- Adds `index` + `usage` schemas (`14–25`).  
- Normalizes input → **one `ollama.embed` call** per request (`28–43`).  
- Token usage is computed from Ollama counters (`46–55`).

---

## ⭐ `openai_compatible_api.py`
- Full schema block (`10–58`): embeddings, completions, chat completions.  
- Embeddings: always uses Bielik (`61–88`).  
- Completions: wraps Ollama output in OpenAI `choices[0].text` (`90–125`).  
- Chat completions: converts OpenAI → Ollama schema → back (`133–168`).  
- Same `MODEL_NAME` everywhere (`line 8`).

---

# 🧮 PCA‑Enabled API for SQL Server 2025

### Why PCA?
SQL Server 2025 limits vectors to **1,998 dims**.  
Bielik emits **2,048 dims** → direct inserts fail.

### PCA Workflow
- Constants + PCA file path: `dim_reduction.py:6–9`.  
- Train with sample vectors: `train_pca()` (`18–26`).  
- Runtime reduction: `reduce_embedding()` (`28–40`).  
- If PCA missing → safe fallback: **slice first 1,998 dims**.

### Package Layout
- Entrypoint wires routers: `main.py:1–8`.  
- Model config: `config.py:1`.  
- Schemas: `openai_schemas.py:5–49`.  
- Ollama service wrapper: `ollama_service.py:4–10`.  
- Embeddings router: `embeddings.py:8–28`.  
- Completions router: `completions.py:7–21`.  
- Chat router: `chat_completions.py:7–24`.

### Run Command
From `python/ollama_api_project_with_pca`:
```
uvicorn app.main:app --reload
```
TLS example (from `run_app_command.txt:1`):
```
uvicorn app.main:app --host 127.0.0.1 --port 5001 --ssl-certfile "...cert.crt" --ssl-keyfile "...cert.key"
```

---

# 🛠️ Adaptation & Self‑Learning Checklist

- **Pick your tier:** start minimal → basic → compatible → PCA.  
- **Swap models safely:** always verify embedding dimension via `ollama.embed`.  
- **Train PCA:** gather several hundred sample embeddings → run `train_pca()`.  
- **Ensure SQL compatibility:** VECTOR column must match PCA output size.  
- **Understand fallback:** slicing works but degrades quality → train PCA ASAP.  
- **Extend endpoints:** reuse schemas from `openai_compatible_api.py` or PCA package.  
- **Iterative testing:** validate token usage before scaling workloads.

---

# 🎯 Key Takeaway
This repo is a **layered, OpenAI‑compatible template** for experimentation or production.  
The main operational constraint:  
**SQL Server 2025 VECTOR(1998) vs. Bielik’s 2,048‑dim embeddings → PCA is mandatory.**

Whenever you change models, quantization, or providers, **verify embedding size first**, then choose the tier that fits your goals.

