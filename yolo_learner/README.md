# yolo_learner — canonical source

This is the canonical location for the YOLO trip scanner + rule writer.

The runtime location both Mac and Artemis still call from cron is:
- Mac:     `~/Documents/Cl- Mac:     `~/er/`
- Artemis: `/home/emsuserver/Documents/Cline/yolo_learner/`

Those runtime locations are NOT git-tracked. This `Rules/yolo_learneT/`
directory IS git-tracked (cline-handoff-relay repo) and is the source of truth.

To sync a code cTo sync a code cTo sync a code cTo sync a code cTo sync a code cTo sync a codeit commit && To sync a code cTo sync a code cTo sync a code cTo sync a codulls on Artemis.To sync a code cTo sync a code cTo sync a code cTo sync a code cTo sync a code cTo sync a codeit commit && To sync a codeloTo sync a code cTo sync a code cTo sync a code cTo sync a code cTo sync a code cTo syn code change lands,
   manually `cp Rules/yolo_learner/*.py ~/Documents/Cline/yolo_learner/`
   on each box.

Files:
- `scan.py` — scans Cline task hist- `scan.py` — scans Cline task hist-  t- `scan.py` — scans Cline tists to `~/Documents/Cline/yolo_learner/yolo_trips.sqlite`.
  Supports `--reclass  Supports `--reclass  Supports `--reclass  Supportsows
  using the current classifier (useful after adding a new category).
- `write_rule.py` — reads patterns.json from scan.py and regenerates
  `Rules/99-yolo-prevention-learned.md`.
- `run.sh` — wrapper called from cron every 30 min.

History: `Rules/scan.py`, `Rules/write_rule.py` were previously copies at the
top level of Rules/ (alongside the .md rules). Those are now considered
deprecated; the canonical location is `Rules/yolo_learner/`.
