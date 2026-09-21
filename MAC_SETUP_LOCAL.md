# Mac setup (local) — env ready, do not run until weekend

Repo: `~/git/dev/hadoop-vs-spark-experiment`
Branch: `feature/mvp-experiment-scaffold`

## Done
- Checked out feature branch
- `.env.high_ram` raised for 48GB Mac (MEM_LIMIT=24g, Spark driver/executor 16g)
- `.env.high_ram.win32ref` = previous 16g Windows-style profile
- `.env.low_ram` unchanged (same tight profile as Windows)

## Before weekend run (manual)
1. Docker Desktop → Settings → Resources → Memory **~32 GB** (host has 48 GB)
2. `docker compose --env-file .env.high_ram config` should succeed
3. Generate/copy data if `data/` incomplete
4. Write results as `results_*_mac.csv` (Windows results are `*_win.csv`)

## Do not
- Do not `compose_up` / `run_experiment` until Polly says go
