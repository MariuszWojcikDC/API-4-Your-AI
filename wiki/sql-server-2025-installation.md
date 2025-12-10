
# 🛠️ SQL Server 2025 Installation - Required Features Checklist

Use this checklist to install **SQL Server 2025** with the features required for the **AI + Vector** demos in this repository.

---

## 📸 Required Feature Selection Screenshot
<img src="../images/sql_server_required_features.jpg" alt="SQL Server 2025 Feature Selection showing required options" width="50%" />

---

## ✅ What You Need
- **Windows** with administrator rights (installer elevates and writes services).  
- **SQL Server 2025 media** (Enterprise or Developer edition).  
- **~2 GB free disk space** for the engine + AI components; additional space for databases/backups.  
- Installer prerequisites (automatically validated):  
  - Windows PowerShell 3.0+  
  - Microsoft Visual C++ 2017 Redistributable  
  - Microsoft MPI v10  

---

## 📦 Required Feature Selection  
During setup, on **Feature Selection**, enable the following checkboxes:

### ✔️ Essential for AI + Vector workloads
- **`Database Engine Services`**  
  Core engine + support for external REST endpoints.

- **`AI Services and Language Extensions`**  
  Required for in-database AI, Python/R capabilities, and REST model integrations.

- **`Full-Text and Semantic Extractions for Search`**  
  Needed for semantic search and vector scenarios used in the sample scripts.

---

## 🚫 Optional / Not Required for This Repo
Leave these unchecked unless you explicitly need them:
- `PolyBase Query Service for External Data`  
- `Analysis Services`  
- `Integration Services`  
- Scale-out services for SSIS

Keep the **default instance root directory** unless you have a specific requirement.

---

## 🔍 Post‑Install Sanity Checks
- Ensure the SQL Server service starts (`MSSQLSERVER` or your named instance).  
- Install **ODBC Driver 18** if not already present - required for the Python vectorizer.  
- Run the SQL scripts under **`sql/SQL AI`** to enable external REST endpoints and vector search features.

---

