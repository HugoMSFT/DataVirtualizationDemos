# Presenter Notes — Seattle Safety Data Virtualization Demo

Run time: ~20–25 minutes end-to-end. Each script is self-contained, so you can skip any one if short on time.

## Before you start

1. Open Azure Data Studio / SSMS / `mssql` extension connected to an **empty** Azure SQL Database.
2. Confirm Data Virtualization is on by default — no `sp_configure` required. Mention this is the Azure SQL advantage (on-prem and Managed Instance need `EXEC sp_configure 'allow polybase export', 1; RECONFIGURE;`).
3. Have the [README](README.md) open in another tab for the data-source table.

## Act 1 — Ad-Hoc Exploration (01-AdHocExploration.sql)

**Narrative:** "We have a 1.87M-row Parquet dataset sitting in public blob storage. I want to answer questions about it *before* committing to ingest."

- Run **Step 1** (count + top 100). Highlight: *no table, no credential, no ETL* — we're querying a remote file with SQL syntax the audience already knows.
- Run **Step 2** (`sp_describe_first_result_set`). Highlight: the engine read the Parquet footer and gave us the schema.
- Run **Step 3** (monthly trend). This is the "I just got a business question" moment. Let it run — it *will* take ~30s because we're reading remote Parquet end-to-end. That's fine; it sells the next act.
- Run **Step 4** (`filename()`). Highlight: you can even see *which* file each row came from — great for forensics.

**Audience reaction to expect:** "Wait, I didn't create a table at all?"

## Act 2 — Ingest (02-IngestData.sql)

**Narrative:** "Ad-hoc is great, but for repeated queries we want local performance. Same syntax, one tweak: `SELECT INTO`."

- Run **Step 1**. When it completes, run `sp_help` and point at the auto-inferred types — call out anything surprising (wide `varchar`s, nullability).
- Run **Step 2** (indexes) and **Step 3** (group by). Then **Step 4** (remote vs local with `SET STATISTICS TIME ON`). Open the **Messages** tab and point at the two elapsed times side by side.

**Key takeaway:** *Same query, two tiers, different performance profiles.*

## Act 3 — External Tables (03-ExternalTables.sql)

**Narrative:** "`OPENROWSET` is great for exploration. For end users, we want a real table name."

- Show **Step 1** (`WITH` clause on OPENROWSET) — contrast with 01 which relied on inference. Mention: pin the schema to skip inference overhead and project only needed columns.
- Walk through **Steps 2–4** quickly: data source → file format → external table. Emphasize: `LOCATION = '/'` because the data source already points at the full path.
- **Step 4 stats:** this runs `CREATE STATISTICS ... WITH FULLSCAN`. Mention external tables **don't support SAMPLE**, only FULLSCAN — one full remote scan per stat.
- **Step 6** hybrid join — this is the money slide. One SELECT hits Parquet *and* a local lookup. "Lake + relational in a single query, no ETL."

## Act 4 — Advanced (04-AdvancedFeatures.sql)

**Narrative:** "Now let's push the engine: geospatial on virtualized data, and peek at pushdown."

- **Step 1** DMV version of describe-result-set (useful programmatically).
- **Step 2** geospatial — `geography::Point` + `STDistance` running over Parquet without a single row landing in a table. The "within 1 km of Space Needle" query is the hook.
- **Step 4** predicate pushdown — run the two queries, then the `dm_exec_external_work` query. Point at `bytes_processed` being smaller for the filtered execution. This is *proof* the engine isn't just scanning everything.

## Act 5 — Tiering (05-DataTiering.sql)

**Narrative:** "Real scenarios don't fit in one tier. Recent data is hot, history is cold. Let's do both with one mental model."

- **Step 2:** hot ingest via folder-targeted `OPENROWSET` — no scan of the entire dataset, just `year=2023/`.
- **Step 3:** show *two* cold objects (external table + OPENROWSET view). Explain the `filepath(1)` trick and why both exist.
- **Step 4:** the unified view is the "nobody cares where it lives" abstraction.
- **Step 6 A/B/C performance contrast** — this is the finale. Run all three; flip to Messages; point at the gap between B (full cold scan) and C (partition elimination).

## Act 5b — Optional performance deep-dive (05b-PerformanceTests.sql)

Only if you have extra time / the audience is SQL-heavy.

- **Test 1** shows why `WHERE YEAR(dateTime) = X` is bad (wraps the column, kills pushdown) versus folder-targeted OPENROWSET.
- **Test 2** schema inference vs `WITH` clause.
- **Test 3** run the "before stats" query first (enable actual plan with Ctrl+M), then create the stats, then re-run and compare estimated vs actual row counts.
- **Test 4** partition elimination scaling.

## Closing slide ideas

- "You just queried 1.87M rows of Parquet, built indexes, did geospatial, and set up hot/cold tiering — without a single ETL pipeline."
- Call to action: point attendees at this repo, mention the data is public so they can reproduce every step.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `The external location is not supported` | The database isn't on Azure SQL Database, or it's an older server version. Data Virtualization GA support started with relatively recent versions. |
| OPENROWSET returns 0 rows | Check the BULK path — `abs://` scheme is required for Azure Blob, and the container must be public or you need a `DATABASE SCOPED CREDENTIAL`. |
| `CREATE STATISTICS ... WITH SAMPLE` fails | External tables only support `FULLSCAN`. |
| Act 3 cleanup broke Act 4 | The cleanup block at the bottom of 03 is commented out by default — if you uncommented it, re-run 03 before 04. |
