# HammerDB TPROC-H SF10 Public Data Virtualization Demo

> [!IMPORTANT]
> This is **not an official TPC-H dataset or benchmark**. The data was generated
> by HammerDB's independently implemented TPROC-H workload. Names such as
> `TPC-H`, `TPCH`, and `SF10` are descriptive or legacy identifiers only.

This repository publishes a scale factor 10 dataset in three ready-to-use
formats: BACPAC, SQL Server backup, and public Parquet. No storage credentials,
SAS tokens, account keys, or private endpoints are required.

The included read-only workload and results are original, illustrative, and
unaudited. Do not represent them as official TPC-H benchmark results.

## Get the data

Choose a layout and download the format you need:

| Layout | SQL Server backup | BACPAC | Approximate size |
|---|---|---|---:|
| Clustered columnstore | [`tpchsf10_columnstore.bak`](https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_columnstore.bak) | [`tpchsf10_columnstore.bacpac`](https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_columnstore.bacpac) | 3.62 GiB `.bak`, 3.24 GiB BACPAC |
| Rowstore | [`tpchsf10_rowstore.bak`](https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_rowstore.bak) | [`tpchsf10_rowstore.bacpac`](https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_rowstore.bacpac) | 5.71 GiB `.bak`, 3.30 GiB BACPAC |

For the simplest start, import a BACPAC with the Azure portal, SSMS, or
`sqlpackage`. On SQL Server, you can instead download a `.bak` and restore it
normally. No repository setup is required for either path.

### Query Parquet directly

The canonical [public Parquet sample](https://tpcpublicstorage.blob.core.windows.net/tpch/tpch_parquet/tpchsf10_rowstore/_schema.sql)
uses anonymous Blob access. To create external tables, run the scripts in
[`parquet/`](parquet/) against an empty database. The scripts create the data
source, file format, eight external tables, and row-count validation.

An additional [columnstore-origin export](https://tpcpublicstorage.blob.core.windows.net/tpch/tpch_parquet/tpchsf10_columnstore/_schema.sql)
is also public; the repository scripts target the canonical rowstore-origin
sample.

## Dataset shape

Every public backup, BACPAC, and the canonical Parquet sample contains these
row counts:

| Table | Rows |
|---|---:|
| `region` | 5 |
| `nation` | 25 |
| `supplier` | 100,000 |
| `customer` | 1,500,000 |
| `part` | 2,000,000 |
| `partsupp` | 8,000,000 |
| `orders` | 15,000,000 |
| `lineitem` | 59,999,496 |

## Workload

[`tpch_readonly_workload.sql`](workload/tpch_readonly_workload.sql) contains
five original analytic queries covering shipping modes, customer segments,
regional revenue, supplier inventory, and late deliveries.

Use [`run_tpch_workload.sh`](workload/run_tpch_workload.sh) to run the workload
and [`summarize_tpch_workload.py`](workload/summarize_tpch_workload.py) to build
the result summaries. Published outputs include the [total summary](workload/tpch_benchmark_summary.csv),
[per-query summary](workload/tpch_benchmark_query_summary.csv), and
[aggregated results](workload/tpch_benchmark_results.csv).

## Published sample results

The original measured environments were:

| Environment | Configuration |
|---|---|
| VM | SQL Server 2025 `17.0.4065.4`, 4 vCPU, 16 GB RAM |
| Azure | General Purpose serverless `GP_S_Gen5_4`, 32 GB maximum |

| Platform | Schema | Median total (ms) | Range (ms) | Relative median vs `dbo` |
|---|---|---:|---:|---:|
| VM | `dbo` | 7,702.216 | 7,696.564-8,484.814 | 1.000x |
| VM | `rs` | 69,776.388 | 63,346.022-71,550.015 | 9.059x |
| VM | `ext` | 22,560.034 | 22,165.645-36,505.472 | 2.929x |
| Azure | `dbo` | 13,228.108 | 10,501.126-15,570.172 | 1.000x |
| Azure | `rs` | 162,012.317 | 161,880.321-184,136.773 | 12.248x |
| Azure | `ext` | 28,002.765 | 27,810.244-53,781.392 | 2.117x |

### Schema legend

- `dbo`: columnstore layout
- `ext`: external Parquet tables over Azure Blob Storage
- `rs`: rowstore layout

These timings are environment-specific TPROC-H-derived sample workload results,
not official TPC-H benchmark results. Cross-platform timings are not directly
comparable.

## Repository contents

| Folder | Contents |
|---|---|
| [`database/`](database/) | Validation for public columnstore, rowstore, and Parquet layouts. |
| [`parquet/`](parquet/) | Anonymous external data source, external tables, and row-count validation. |
| [`schemas/`](schemas/) | Exact schema-only references from the completed SQL Server and Azure SQL environments. |
| [`workload/`](workload/) | Read-only queries, runner, summarizer, aggregated results, and total/per-query summaries. |

This folder contains only public-data consumption assets. It has no storage
write path, publishing credentials, private service addresses, authentication
caches, or generated data files.
