## 📝 License
Released under the [MIT License](./LICENSE).  
© 2025 Don Fox

# ProviderVault CLI (v1.7)
A lightweight Elixir CLI for managing healthcare provider records (NPPES-style).  
It supports CSV import/export, Excel → CSV conversion, simple search/edit operations, and automatic fetching of monthly NPPES data releases.

---

## 🧭 Project Goals
- Provide an easy-to-use local CLI to view and maintain provider data.  
- Experiment with functional design and behaviours before adding a Postgres adapter.  
- Eventually evolve into a modular data ingestion pipeline with CLI + API layers.

---

## ⚙️ Quick Start
```bash
# 1. Build and run the escript
mix do clean, compile, escript.build
./provider_vault_cli

# or start it via Mix:
mix provider.start