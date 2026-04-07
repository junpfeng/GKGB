---
name: GKGB Architecture Review Patterns
description: Common architectural issues found in GKGB exam prep app design reviews
type: project
---

Key architecture risks identified in full_app feature review (2026-04-07):

1. DatabaseHelper singleton exposed via Provider to Screen layer, violating layered architecture
2. sqflite needs sqflite_common_ffi for Windows desktop support
3. flutter_secure_storage has limitations on Windows (wincred size limits, visible in Credential Manager)
4. LLM streamChat lacks fallback mechanism unlike chat()
5. Database schema v1 has no onUpgrade handler and no indexes
6. llm_config table has api_key_encrypted field conflicting with flutter_secure_storage approach

**Why:** These are recurring Flutter cross-platform pitfalls specific to this project's Windows+Android target.
**How to apply:** Check these patterns in future design reviews for this project.
