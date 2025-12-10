# 🔐 SSL Certificate for Local FastAPI + SQL Server 2025  
### **Why We Need It, What Fails Without It, and How to Configure It Correctly**

---

## 📝 1. Purpose of This Document
This document explains:

- Why an SSL certificate is required for local integration between **SQL Server 2025**, **FastAPI**, and **Python**.  
- What errors occur when the certificate is missing or invalid.  
- The exact certificate configuration needed (CN, SAN, stores, key properties).  
- Step‑by‑step manual creation and configuration.  
- That a PowerShell automation script exists in the project’s `powershell` folder.  
- That administrator rights are required for all certificate operations.

Assumed setup:

- SQL Server 2025 running locally  
- Local FastAPI application via Uvicorn  
- Python script calling FastAPI over HTTPS to generate embeddings and store them in SQL Server  

---

## 🔒 2. Why We Need an SSL Certificate

### ⚙️ 2.1 SQL Server 2025 Requires HTTPS for External AI Endpoints
SQL Server 2025 performs a full **TLS handshake** when calling external REST endpoints:

- **HTTP is not allowed**, only HTTPS  
- Server certificate must be trusted  
- SAN must match the hostname in the URL  

Even for local endpoints such as:

```
https://localhost:5001/openai/deployments/local/embeddings
```

This requires a valid certificate trusted by the machine.

---

### ⚡ 2.2 FastAPI / Uvicorn Needs a Certificate to Serve HTTPS
Uvicorn handles TLS termination, requiring:

- `cert.crt` (certificate)  
- `cert.key` (private key)  

Without these, Uvicorn serves **HTTP only**, which SQL Server rejects.

---

### 🐍 2.3 Python Validates TLS
Python (`aiohttp`) validates certificates:

- Untrusted or mismatched SAN → request fails  
- A proper CA or self-signed root must be trusted  

---

## ❗ 3. What Errors Occur Without a Proper SSL Certificate

### 🧱 3.1 SQL Server 2025 Errors
Common failures:

- `HRESULT: 0x80070018`  
- `Failed to communicate with external REST endpoint`

Indicates certificate trust or SAN mismatch issues.

---

### 🐍 3.2 Python (`aiohttp`) Errors
Typical messages:

- `ssl.SSLCertVerificationError: [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed`  
- `Cannot connect to host localhost:5001 ssl:True`

Occurs when Python cannot validate the server certificate.

---

### 🌐 3.3 Browser / API Client Warnings
Tools like Bruno/Postman show:

- “Your connection is not private”  
- “Certificate is not trusted”

Indicating missing Trusted Root import.

---

## 📜 4. Required Certificate Configuration

### 🏷️ 4.1 Subject and SAN
- **CN:** `localhost`  
- **SAN:**  
  - DNS: `localhost`  
  - IP: `127.0.0.1`  

---

### 🏛️ 4.2 Certificate Store Locations
Must be in **LocalMachine**, not CurrentUser:

- **Personal (My):** certificate + private key  
- **Trusted Root Certification Authorities:** public part for trust  

---

### 🔑 4.3 Key and Algorithm Requirements
- Exportable private key  
- RSA 2048+  
- SHA256  
- Valid for e.g., 5 years  

---

### 🔐 4.4 Trust Requirements
The `.cer` must be imported into:

**Local Computer → Trusted Root Certification Authorities**

Without this → SQL Server & Python fail certificate validation.

---

## 🧭 5. Manual Step‑by‑Step: Creating and Configuring the SSL Certificate  
_All steps require **Administrator** privileges._

---

### 🛠️ 5.1 Generate Self-Signed Certificate (PowerShell)

```powershell
$certName = "LocalhostSSL"

$cert = New-SelfSignedCertificate `
    -Subject "CN=localhost" `
    -DnsName "localhost","127.0.0.1" `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -FriendlyName $certName `
    -NotAfter (Get-Date).AddYears(5)
```

---

### 📤 5.2 Export `.cer`

```powershell
Export-Certificate -Cert $cert -FilePath "C:\SelfSSL\MyCert\LocalhostSSL.cer"
```

---

### 📦 5.3 Export `.pfx`

```powershell
$mypwd = ConvertTo-SecureString -String "YourStrongPasswordHere!" -Force -AsPlainText

Export-PfxCertificate `
    -Cert $cert `
    -FilePath "C:\SelfSSL\MyCert\LocalhostSSL.pfx" `
    -Password $mypwd
```

---

### 🏛️ 5.4 Import into Trusted Root (MMC)
1. Run `mmc.exe` as Admin  
2. Add Certificates → Computer account  
3. Navigate to *Trusted Root Certification Authorities*  
4. Import `.cer`  

---

### 🔧 5.5 Extract `cert.crt` and `cert.key` (OpenSSL)

```powershell
# Public certificate
& "C:\Program Files\OpenSSL-Win64\bin\openssl.exe" pkcs12 `
    -in C:\SelfSSL\MyCert\LocalhostSSL.pfx `
    -clcerts -nokeys `
    -out C:\SelfSSL\MyCert\cert.crt `
    -passin pass:"YourStrongPasswordHere!"

# Private key
& "C:\Program Files\OpenSSL-Win64\bin\openssl.exe" pkcs12 `
    -in C:\SelfSSL\MyCert\LocalhostSSL.pfx `
    -nocerts -nodes `
    -out C:\SelfSSL\MyCert\cert.key `
    -passin pass:"YourStrongPasswordHere!"
```

---

### 🚀 5.6 Run FastAPI with HTTPS

```bash
uvicorn app.main:app \
  --host localhost \
  --port 5001 \
  --ssl-certfile "C:\SelfSSL\MyCert\cert.crt" \
  --ssl-keyfile "C:\SelfSSL\MyCert\cert.key"
```

---

### 🐍 5.7 Configure Python to Trust Certificate

```python
import ssl
import aiohttp

ssl_context = ssl.create_default_context(
    cafile="C:/SelfSSL/MyCert/cert.crt"
)

connector = aiohttp.TCPConnector(
    limit=10,
    ssl=ssl_context,
)

async with aiohttp.ClientSession(connector=connector) as session:
    async with session.post(
        "https://localhost:5001/openai/deployments/local/embeddings",
        json={"input": ["example text"]}
    ) as resp:
        data = await resp.json()
```

---

### 🔍 5.8 Verification Checklist
- Browser opens `https://localhost:5001/docs` without warnings  
- Python script connects without SSL errors  
- SQL Server calls endpoint without `0x80070018`  

---

## ⚙️ 6. PowerShell Automation Script
Use:

```
powershell/generate_cert.ps1
```

It:

- Generates certificate  
- Exports `.cer` and `.pfx`  
- Extracts `cert.crt` + `cert.key`  
- Provides Uvicorn startup guidance  

Requires Administrator rights.

---

## 🔑 7. Administrator Privileges - Important Note
All steps require Admin permissions:

- Certificate creation  
- Importing into root store  
- Exporting private keys  
- Restarting services (SQL Server, FastAPI)  

Running without Admin rights → incorrect store placement, errors, failed trust.

---

## 🧾 Summary

- SQL Server 2025 **requires HTTPS** for external AI calls  
- A local FastAPI endpoint must use a proper SSL certificate  
- Certificate must have correct CN/SAN, live in `LocalMachine\My`, and be trusted in `Root`  
- Uvicorn uses `cert.crt` + `cert.key`  
- Python must trust the certificate via SSL context  
- PowerShell script automates entire setup  

---

