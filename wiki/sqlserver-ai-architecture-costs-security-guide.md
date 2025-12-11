
# 📘 Full Educational Project Report  
## **Architecture • Costs • Security • Ideas**

This document is part of the repository and is intended to **educate users** about the architecture, financial implications, security considerations, and operational risks associated with using this SQL Server + AI solution.  
It explains **what is free**, **what may generate costs**, **where risks may appear**, and **how to avoid unexpected expenses** when experimenting with or deploying this system.

---

# 🎯 1. Purpose of the Solution
This repository demonstrates a complete AI-driven pipeline integrating:

- **SQL Server 2025** with native vector search  
- **Cloud and local embedding models**  
- **Local LLM (Bielik / GGUF)**  
- **Python-based REST API and embedding pipeline**  
- **SSL certificates for secure local communication**  
- **Retrieval-Augmented Generation (RAG)** architecture  

The solution supports:

- **100% local execution** (zero financial cost)  
- **Hybrid or cloud execution** (costs may apply)

This document explains architecture, costs, token usage, and security principles to ensure safe and responsible usage.

---

# 🧱 2. Architecture Overview

## 🗄️ 2.1 SQL Server 2025 - Native Vector Search and AI Integration
SQL Server provides:

- storage for documents, chunks, embeddings  
- native VECTOR data type  
- approximate and exact vector search  
- indexing for high-performance ANN search  
- hybrid relational + semantic querying  

Vector search inside SQL Server is **purely mathematical**, not dependent on AI model tokens.

---

## 🐍 2.2 Python - AI Runtime, Preprocessing, and API Layer
Python handles:

- embedding generation  
- LLM inference  
- text preprocessing and chunking  
- integration with SQL Server  
- SSL-based REST endpoints  
- local model execution using GGUF  

---

## 🤖 2.3 AI Models

### ☁️ Cloud Embeddings - `text-embedding-3-small`
- Accurate and inexpensive  
- Stable across large datasets  
- Recommended for production  

### 🏡 Local LLM - Bielik (GGUF)
- Offline, zero API cost  
- Good for text generation  
- **Not suitable for high‑quality embeddings**

---

## 🔐 2.4 SSL Certificates
The repository includes:

- a self-signed certificate generator  
- automated PowerShell setup  
- explanations of common SSL issues  

---

# 💻 3. System Requirements

### Minimum:
- Windows 10/11
- SQL Server 2025 Developer Edition  
- Python 3.10+  
- 16 GB RAM  

### For Local LLM:
- 6+ cores  
- 16–32 GB RAM  
- GPU optional  

---

# 💰 4. Cost Analysis - Critical For Users

---

# 🏷️ 4.1 SQL Server Licensing Cost

SQL Server is the **highest potential cost** in enterprise environments.

The repository runs **free** using:

- SQL Server Developer Edition  
- SQL Server Express  

### Approximate Production Costs

| Edition | Price (USD) | Model |
|--------|-------------|--------|
| Enterprise | $15,123 per 2‑core pack | core-based |
| Standard (per core) | $3,945 per 2‑core pack | 4‑core minimum |
| Standard (server) | $989 | per server |
| Standard CAL | $230 | per user |
| Developer | Free | non‑prod |
| Express | Free | limited |

### Summary
✔ Development usage = **$0**  
✔ Production can start at **$7,890** and reach **$30,246+** depending on licensing  

---

# 📌 5. Vector Search Cost Clarification

SQL Server performs vector search as a mathematical CPU operation.  
You **only pay for generating the query embedding**, not for running the semantic search.

SQL Server currently provides **no built‑in telemetry** for tracking token usage.

---

# 💡 6. Suggested Improvement (Conceptual) - Expanded Educational Version

While SQL Server 2025 includes strong AI integration, one major opportunity for improvement is **enhanced observability of AI-related activity** inside SQL Server.  
Today, SQL Server executes embedding generation by calling external AI models, but **none of the model‑returned metadata is exposed inside SQL Server**.

External AI model providers typically return:

- number of input tokens  
- number of output tokens  
- model name/version  
- processing latency  
- billing category  
- usage limits/throttling info  
- trace or request IDs  

**SQL Server receives these values internally, but does not surface them.**

This creates challenges for:

- cost tracking  
- troubleshooting  
- governance  
- performance analysis  
- auditing  

### Potential Future Improvements

**1. System views summarizing AI operations**  
Examples: aggregated call counts, failure metrics, latency averages.

**2. Observability events for AI requests**  
Useful for correlation with SQL workloads.

**3. Lightweight usage metrics**  
Token counts, input sizes, model identifiers.

**4. Integration with monitoring tools**  
Allowing AI telemetry to flow into existing SQL monitoring systems.

### Why this matters
- Some teams lack direct access to cloud provider dashboards  
- AI governance requires cost tracking  
- Production workloads require visibility  
- Troubleshooting complex RAG systems requires correlation tools  

---

# 🔐 7. Security Considerations For AI + SQL Server Integrations

AI introduces new security risks not present in traditional SQL workloads.

---

## 🔒 7.1 Secure Communication With Cloud Models

### Risks:
- Data traveling over the public internet  
- TLS misconfiguration  
- Accidental use of public endpoints  

### Best Practices:
- Prefer **Private Endpoints**  
- Disable **Public Network Access**  
- Require **TLS 1.2+**  
- Restrict outbound firewall rules  
- Avoid logging sensitive data  

---

## 🧬 7.2 Sensitive Data Leakage Through Embeddings

Embeddings can leak meaning even though they look like numeric vectors.

### Risks:
- reconstruction attacks  
- PII leakage  
- inference attacks  

### Best Practices:
- treat embeddings as sensitive  
- encrypt vector data  
- apply row/column-level security  
- avoid exporting embeddings  

---

## ⚔️ 7.3 Prompt Injection & AI-to-SQL Injection

LLM output should never directly generate or modify SQL commands.

### Best Practices:
- parameterized SQL  
- prompt sanitization  
- validation of AI-generated text  

---

## 🔑 7.4 API Key and Credential Security

### Risks:
- plaintext secrets  
- committing secrets to Git  
- exposed URLs with API keys  

### Best Practices:
- use Key Vault / secret managers  
- rotate keys  
- prevent secret logging  
- avoid placing secrets in repos  

---

## 📊 7.5 Logging and Observability Gaps

SQL Server lacks model-level telemetry.

### Best Practices:
- log AI requests in Python layer  
- capture latency, token usage, model names  
- set up API rate limits  

---

## 🏷️ 7.6 Data Classification & Governance

Before sending data to a model, classify it:

- PII  
- medical data  
- financial data  
- confidential IP  

### Best Practices:
- restrict which data can be sent to cloud models  
- use local models for sensitive categories  
- maintain governance documentation  

---

# 🛡️ 8. Safe and Cost-Free Use Guidelines

- Use SQL Server Developer Edition  
- Use `text-embedding-3-small`  
- Prefer GPT‑4o‑mini or Bielik locally  
- Configure Azure budgets  
- Log request metadata  
- Test everything locally  
- Review loops calling AI models  


Following these guidelines, users can run the system **entirely free in development** 

---

