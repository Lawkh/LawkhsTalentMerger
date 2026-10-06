# 0.6.2

- Remove completed specialization restores from Undo history and drop operations with no remaining scopes.
- Clean up already-restored entries left by previous versions when opening Undo.
- Keep pending scopes and failed or partial restorations available for retry.

Validation: 46 core tests and 30 simulated UI tests.
