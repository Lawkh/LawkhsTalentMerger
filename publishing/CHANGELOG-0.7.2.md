# 0.7.2

- Raise the talent launcher above the talent canvas and explicitly enable mouse-up clicks.
- Run one initial duplicate check when the talent view opens if no check has been attempted yet.
- Distinguish an incomplete check from a check not yet attempted; do not loop on unreadable builds.
- Restore duplicate colors in the native dropdown from cached per-spec results without adding actions or scanning on menu open.

Validation: 48 core tests and 40 simulated UI tests, including launcher layering, one-time checks and cached menu coloring. Live click routing still requires an in-game check.
