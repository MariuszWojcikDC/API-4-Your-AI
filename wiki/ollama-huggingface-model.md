# 🧩 Run a Hugging Face Model Locally with Ollama

Use this quick guide to pull a **GGUF model directly from Hugging Face into Ollama** and run it fully locally (no external API calls).  
The example uses:  **`hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0`**, already referenced in:

```
python/ollama_api_project_with_pca/app/config.py
```

<img src="../images/bielik_ollama.jpg" alt="Hugging Face model card showing the Ollama option" width="75%" />
---

## 🧭 Understanding the Command

- **`ollama run`** → starts a new Ollama session.  
- **`hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF`** → points to the GGUF model stored on Hugging Face.  
- **`:Q8_0`** → specifies the quantization level (8‑bit), reducing memory/disk usage while keeping reasonable quality for a ~5B parameter model.

![Hugging Face Use this model -> Ollama command dialog](../images/ollama_get_model.jpg)

---

## 🛠️ Prerequisites

- Windows, macOS, or Linux with **Ollama installed and running** (Windows/macOS start `ollama serve` automatically) 
- Sufficient **RAM/VRAM** for Q8_0 (~5B params):  
  - Minimum: **8 GB RAM**  
  - Recommended: **16 GB+**  
- Enough **disk space** for GGUF download + model cache  
- Internet connectivity for the first download; afterward, everything runs locally

---

## 🚀 Steps to Run

### **1️⃣ Install Ollama (if needed)**  
Download from: https://ollama.com/

### **2️⃣ Open your terminal or PowerShell**

### **3️⃣ Pull the model and start a session**
```bash
ollama run hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0
```
- First run downloads the GGUF from Hugging Face (may take several minutes).  
- After download completes, an interactive prompt appears — type a message and press **Enter**.

### **4️⃣ (Optional) Create a shorter local alias**
```bash
ollama alias create bielik hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0

```
- This creates a reusable local model named **`bielik`**.

---

## 🧯 Notes & Troubleshooting

- **RAM constraints:** under 8 GB, inference may fail or be extremely slow.  
- **Download failures:** check internet access and disk space; rerun the same command to resume.  
- **Slow inference:**  
  - reduce prompt size  
  - close heavy system applications  
  - use a smaller quantization (if available)
- **Using with this repo:**  
  If the FastAPI service is running, **restart it after pulling the model** so Ollama can serve it.

---

## 🧪 Quick Test Prompt

```bash
ollama run hf.co/speakleash/Bielik-4.5B-v3.0-Instruct-GGUF:Q8_0 "Write a short summary of the API-4-Your-AI project."
```

