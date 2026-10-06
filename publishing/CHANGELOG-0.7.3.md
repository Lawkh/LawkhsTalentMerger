# 0.7.3

- Move the launcher into an independent UIParent container anchored to the talent window, above the canvas input layer.
- Replace inherited button behavior with explicit hover, press and reset visuals.
- Open on mouse press and prevent the subsequent click from running a second scan.
- Keep the launcher visibility synchronized with the talent view and bring the opened panel to the front.
- Report panel-opening errors in chat and add /tm launcher diagnostics.

Validation: 48 core tests and 42 simulated UI tests. Actual mouse routing needs confirmation in the live client.
