# 🔍 Why Two Models Are Used

This repository demonstrates how to generate embeddings and perform semantic search using two very different language models - each chosen to highlight a specific purpose in the workflow.

- **OpenAI `text-embedding-3-small`** - a dedicated embedding model optimized for semantic tasks.  
- **Bielik-4.5B-v3.0-Instruct (GGUF Q8_0)** - a local, quantized Polish generative model from HuggingFace:  
  https://hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF

The pairing is intentional to show both the *correct* usage of a specialized embedding model and the *limitations* of relying on a generative LLM for embedding tasks.

---

## 🧠 text-embedding-3-small - Proper Semantic Search Embeddings

`text-embedding-3-small` is trained specifically for semantic search, ranking, clustering, classification, RAG, and multilingual use cases (including Polish).

### ✅ Advantages
- High-quality, contrastively trained embeddings in a normalized vector space (ideal for cosine similarity).
- Strong performance on European languages.
- Lightweight, fast, and inexpensive for production.
- Stable embedding behavior regardless of input length.

### ⚠️ Limitations
- Requires the OpenAI API - cannot run offline.
- For specialized domains, the larger variant may perform better.

---

## 🏗️ Bielik-4.5B-v3.0-Instruct (GGUF Q8_0) - *Intentionally* Not an Embedding Model

`Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0` is a quantized, instruction-tuned, decoder-only Polish LLM intended for **generation**, not embeddings.

It is included to illustrate an important principle:

> You *can* extract embeddings from almost any LLM -> but that does **not** mean they will be good for semantic search.

In this repository, Bielik is used to:
- Run a fully local GGUF model without external APIs.
- Demonstrate an end‑to‑end SQL Server integration with a self-hosted LLM.
- Contrast embeddings from a generative model vs. a dedicated embedding model.

### 👍 Advantages in this demo
- 100% local execution.
- Great for demonstrating the pipeline (local model → API → SQL Server).
- Provides a strong counterexample to proper embedding models.

### ⚠️ Limitations as an embedding model
- No contrastive training → weak semantic similarity.
- Vectors are not normalized or semantically structured.
- Cosine similarity does not correlate well with meaning.
- Poor accuracy for semantic search.
- Embeddings are unstable and sensitive to prompt variations.

---

## 📘 Summary Comparison

| Model                                     | Intended Use     | Embedding Quality | Purpose in This Project                                              |
| ----------------------------------------- | ---------------- | ----------------- | -------------------------------------------------------------------- |
| **text-embedding-3-small**                | Embedding model  | ⭐ High           | Demonstrates proper semantic search implementation                   |
| **Bielik-4.5B-v3.0-Instruct (GGUF Q8_0)** | Generative LLM   | ❌ Very low       | Shows offline execution and SQL Server integration for comparison    |

---

