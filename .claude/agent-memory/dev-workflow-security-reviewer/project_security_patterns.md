---
name: Project Security Patterns
description: Recurring security patterns in GKGB project — secure storage usage, API key management, platform-specific security considerations
type: project
---

GKGB uses flutter_secure_storage with WindowsOptions(useBackwardCompatibility: false) for sensitive data (API keys, activation data). Established pattern in LlmConfigService and ActivationService.

**Why:** Constitution mandates encrypted storage for API keys, no plaintext in SQLite or logs.

**How to apply:** When reviewing new features that store secrets, verify they follow the LlmConfigService pattern. Check that WindowsOptions are set correctly and Android minSdkVersion supports EncryptedSharedPreferences (API 23+).

**Offline Activation (approved 2026-04-07):** Ed25519 challenge-response scheme with device-bound machine codes. Public key split across 3 source files with SHA-256 integrity check. Private key stored outside repo via env var, password-protected PEM. .gitignore + pre-commit hook protect against key leakage. Clock rollback detection with 10-min tolerance. Anti-bruteforce with exponential backoff persisted in secure storage.
