# 0.6.3

- Stop talent scans and UI creation on background events while the window is closed.
- Ignore unrelated addon loads and coalesce visible talent updates.
- Remove the redundant refresh of the legacy hidden list; read each spec once per dashboard refresh.
- Preserve dialog snapshots without rebuilding them on background events.
- Reuse tree node lists within each read and share specialization snapshots throughout Undo history rendering.
- Store only restorable backup data, without duplicate comparison signatures.
- Add /tm memory to report runtime addon memory, backup text size and talent-read count without scanning talents or forcing garbage collection.

Validation: 48 core tests and 34 simulated UI tests, including event bursts, frame reuse and scan counts. Runtime memory reduction still needs an in-game measurement.
