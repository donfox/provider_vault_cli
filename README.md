# Provider Vault CLI (v1.5)

Now with:
- No-dup imports (dedupe by NPI)
- "Clear all records" menu item
- Auto-seed only on first run
- Deduplicate on add
- Friendly "no providers yet" message

## Quick start

```bash
cd provider_vault_cli_v1_5
mix deps.get
iex -S mix
ProviderVault.CLI.Main.start()
# or: mix provider.start
```
