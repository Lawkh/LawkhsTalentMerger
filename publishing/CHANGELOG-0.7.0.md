# 0.7.0

- Remove menu modifications and all addon actions from the native loadout dropdown.
- Use the talent-window launcher to open the addon panel.
- Add a last-check badge beneath the launcher: green ready check, yellow duplicate warning, or not checked.
- Analyze once on panel open or Refresh; reuse snapshots for selections and display filters.
- Ordinary talent events no longer trigger scans even with the window open.
- Check once after a new saved loadout (including imports) is available; skip internal configs and addon restore operations.

Validation: 48 core tests and 37 simulated UI tests; 1,196 translated strings checked.
