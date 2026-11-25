# Evidence

Raw logs from the iPhone 17 Pro, unedited, every run included. How each test is done and what passes:
[docs/phone-day.md](../phone-day.md).

| File | What it holds |
| --- | --- |
| `routing-log.jsonl` | The planning runs: task, where it ran, why, model, ms and the validator's verdict, straight from the phone |
| `lidar-accuracy.csv` | 10 panels: measured against tape and calipers |
| `offline-runs.csv` | 10 airplane-mode runs of the whole flow |
| `ar-lines.csv` | AR cut lines against a ruler |
| `cut-check.csv` | Real cut pieces against a caliper, with the app's verdict |
