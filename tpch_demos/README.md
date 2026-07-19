# TPC-H SF10 data-virtualization demo

This demo records an end-to-end SF10 workflow built with HammerDB 5.0,
SQL Server 2025, Azure SQL Database, Azure Blob Storage, Parquet, and external
tables. It includes the reusable build/export/validation scripts, exact final
schema-only DDL, and the aggregated results from a small read-only analytic
workload.

The HammerDB data generator calls this workload **TPROC-H**. This repository
uses the familiar TPC-H table names to describe the resulting data layout, but
the measured workload contains five original queries and is **not** an
audited or official TPC-H benchmark result.

## Completed layouts

| Target | Final database layout |
|---|---|
| SQL Server 2025 VM, `tpchsf10_columnstore` | `dbo`: eight clustered-columnstore tables. `rs`: eight HammerDB-style rowstore tables, 14 B-tree indexes, and 10 enabled/trusted foreign keys. `hp`: eight heaps with no indexes or foreign keys. `ext`: eight Parquet external tables. |
| Azure SQL Database, `tpchsf100` | `dbo`: eight clustered-columnstore tables. `rs`: eight rowstore tables, 8 B-tree indexes, and 10 enabled/trusted foreign keys. `ext`: eight Parquet external tables. There is no `hp` schema. |

`tpchsf100` is the retained Azure database name, but the data was generated at
SF10. Azure SQL rejected an attempted 64 GB `MAXSIZE` change with error 45122,
so the database remained on the 32 GB Azure SQL Free Limit offer.

The internal data sets differ slightly because they were generated
independently:

| Data set | `lineitem` rows |
|---|---:|
| VM internal (`dbo`, `rs`, and `hp`) | 59,999,496 |
| Azure internal (`dbo` and `rs`) | 60,001,203 |
| Canonical Parquet data read by both `ext` schemas | 59,999,496 |

Both external schemas intentionally read the VM rowstore-origin Parquet data.
The shared external data source is anonymous and has no database credential:

```sql
CREATE EXTERNAL DATA SOURCE [TPCHParquetBlob]
WITH
(
    LOCATION = N'abs://tpch@tpcpublicstorage.blob.core.windows.net/'
);
```

## Repository contents

| Folder | Contents |
|---|---|
| [`hammerdb/`](hammerdb/) | HammerDB 5.0 SF10 build definitions, Docker runner, BCP shim, and stream redactor. |
| [`database/`](database/) | VM/Azure physical-layout creation, final layout validation, and the optional standalone rowstore archive workflow. |
| [`database/backups/`](database/backups/) | Blob backup credential helper, exact `.bak` commands, verification, and portable BACPAC export/upload helper. |
| [`parquet/`](parquet/) | Temporary CETAS credential setup, Parquet export/validation/cleanup, adjacent DDL publication, and anonymous external-table creation. |
| [`schemas/`](schemas/) | Schema generator plus the exact final VM and Azure schema-only DDL. |
| [`workload/`](workload/) | Five-query workload, rotated runner, summarizer, raw aggregated CSV, total summary, and per-query summary. |

## Prerequisites

- An Azure Linux host (or another Linux/macOS host) with Docker Engine.
- HammerDB 5.0's official `linux/amd64` image:
  `tpcorg/hammerdb:v5.0`.
- A SQL Server 2025 instance and an Azure SQL logical server reachable from
  the client.
- `sqlcmd` from Microsoft SQL command-line tools for database scripts.
- `sqlpackage`, Azure CLI, `curl`, and `unzip` for BACPAC publication.
- Azure CLI for publishing adjacent schema DDL after CETAS.
- A storage SAS with only the permissions and lifetime needed for CETAS or
  SQL Server `BACKUP TO URL`. BACPAC upload uses the caller's Azure CLI login
  and Azure RBAC instead of an account key.

All passwords and storage credentials are runtime inputs. Do not put them in
this repository, command files, Docker images, or captured logs. The helpers
fail when required values are absent and never contain a password, SAS token,
or account key.

The examples use SQL authentication:

```bash
export SQL_SERVER='server.example.net,1433'
export SQL_USER='demo_login'
read -rsp 'SQL password: ' SQLCMDPASSWORD
printf '\n'
export SQLCMDPASSWORD
```

Set `SQLCMD_TRUST_SERVER_CERTIFICATE=1` only for a VM endpoint whose
certificate you have independently decided to trust. Azure SQL should retain
certificate validation.

## 1. Generate SF10 with HammerDB 5.0

Pull the version-pinned image on the Azure Linux Docker host:

```bash
docker pull tpcorg/hammerdb:v5.0
```

The two Python definitions select four build threads, SF10, `MAXDOP 4`,
clustered columnstore, and BCP loading:

- [`mssqls_tproch_build_sf10.py`](hammerdb/mssqls_tproch_build_sf10.py)
  enables Azure SQL connection behavior.
- [`mssqls_tproch_build_sqlvm_sf10.py`](hammerdb/mssqls_tproch_build_sqlvm_sf10.py)
  enables SQL Server behavior and trusted-server-certificate mode.

Create empty target databases first. The completed workflow used
`tpchsf100` on Azure SQL and `tpchsf10_columnstore` on the VM. Then run:

```bash
cd tpch_demos

# Azure SQL Database
export MSSQL_SERVER='logical-server.database.windows.net'
export MSSQL_DATABASE='tpchsf100'
export MSSQL_USERNAME="$SQL_USER"
export MSSQL_PASSWORD="$SQLCMDPASSWORD"
./hammerdb/run_hammerdb_build.sh azure

# SQL Server 2025 VM
export MSSQL_SERVER='sql-vm.example.net'
export MSSQL_DATABASE='tpchsf10_columnstore'
./hammerdb/run_hammerdb_build.sh sqlvm

unset MSSQL_PASSWORD
```

The runner mounts the password into the container as a temporary read-only
secret file, places [`hammerdb/bin/bcp`](hammerdb/bin/bcp) first on `PATH`,
and filters HammerDB output through
[`redact_stream.py`](hammerdb/redact_stream.py). Set
`HAMMERDB_DOCKER_NETWORK` only when the container needs a non-default Docker
network.

## 2. Create the comparison layouts

### SQL Server VM

Run the following against the VM. The first script makes schema-identical
heap copies in `rs` and `hp`; the second adds the exact 14-index,
10-foreign-key rowstore design to `rs`.

```bash
sqlcmd -S "$SQL_SERVER" -d master -U "$SQL_USER" -N -C -b \
  -i database/create_vm_benchmark_copies.sql

sqlcmd -S "$SQL_SERVER" -d master -U "$SQL_USER" -N -C -b \
  -i database/create_vm_rs_indexes.sql
```

Scripts:

- [`create_vm_benchmark_copies.sql`](database/create_vm_benchmark_copies.sql)
- [`create_vm_rs_indexes.sql`](database/create_vm_rs_indexes.sql)

`hp` deliberately remains eight unindexed heaps with no foreign keys.

### Azure SQL Database

The Azure copy has no `hp` schema. It reproduces the live eight-index
rowstore design:

```bash
export SQL_SERVER='logical-server.database.windows.net'

sqlcmd -S "$SQL_SERVER" -d tpchsf100 -U "$SQL_USER" -N -b \
  -i database/create_azure_benchmark_copy.sql

sqlcmd -S "$SQL_SERVER" -d tpchsf100 -U "$SQL_USER" -N -b \
  -i database/create_azure_rs_indexes.sql
```

Scripts:

- [`create_azure_benchmark_copy.sql`](database/create_azure_benchmark_copy.sql)
- [`create_azure_rs_indexes.sql`](database/create_azure_rs_indexes.sql)

### Optional standalone rowstore archive

The public `tpchsf10_rowstore.bak` and `.bacpac` came from a standalone
rowstore database derived from the VM columnstore database. It is an archival
artifact, not the database used by the final benchmark. The original
machine-specific `F:`/`G:` file paths were removed; this version uses the SQL
Server instance's default data and log locations.

Run, in order:

1. [`archive/create_tpchsf10_rowstore.sql`](database/archive/create_tpchsf10_rowstore.sql)
2. [`archive/copy_tpchsf10_rowstore.sql`](database/archive/copy_tpchsf10_rowstore.sql)
3. [`archive/index_tpchsf10_rowstore.sql`](database/archive/index_tpchsf10_rowstore.sql)
4. [`archive/validate_tpchsf10_rowstore.sql`](database/archive/validate_tpchsf10_rowstore.sql)

## 3. Write and verify Blob `.bak` backups

The exact backup scripts target the public `tpch` container. Blob write
access still requires a short-lived SAS credential on the SQL Server
instance.

```bash
export SQL_SERVER='sql-vm.example.net'
export SQLCMD_TRUST_SERVER_CERTIFICATE=1
read -rsp 'Container SAS: ' AZURE_STORAGE_SAS_TOKEN
printf '\n'
export AZURE_STORAGE_SAS_TOKEN

./database/backups/configure_backup_credential.sh

sqlcmd -S "$SQL_SERVER" -d master -U "$SQL_USER" -N -C -b \
  -i database/backups/backup_tpchsf10_columnstore.sql

sqlcmd -S "$SQL_SERVER" -d master -U "$SQL_USER" -N -C -b \
  -i database/backups/backup_tpchsf10_rowstore.sql

sqlcmd -S "$SQL_SERVER" -d master -U "$SQL_USER" -N -C -b \
  -i database/backups/verify_tpchsf10_blob_backups.sql
```

After verification, remove the server credential and clear the token:

```bash
sqlcmd -S "$SQL_SERVER" -d master -U "$SQL_USER" -N -C -b -Q \
  "DROP CREDENTIAL [https://tpcpublicstorage.blob.core.windows.net/tpch];"
unset AZURE_STORAGE_SAS_TOKEN
```

Published backups:

- [`tpchsf10_columnstore.bak`](https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_columnstore.bak)
- [`tpchsf10_rowstore.bak`](https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_rowstore.bak)

## 4. Export and publish BACPACs

[`export_bacpac_to_blob.sh`](database/backups/export_bacpac_to_blob.sh)
uses `sqlpackage` locally and `az storage blob upload --auth-mode login`.
The caller needs Storage Blob Data Contributor (or equivalent) on the target
container. No account key is read or cached by the script.

```bash
az login
export SQLPACKAGE_BIN=/path/to/sqlpackage
export AZURE_STORAGE_ACCOUNT=tpcpublicstorage
export AZURE_STORAGE_CONTAINER=tpch

./database/backups/export_bacpac_to_blob.sh tpchsf10_columnstore
./database/backups/export_bacpac_to_blob.sh tpchsf10_rowstore
```

The helper validates the BACPAC ZIP, records a SHA-256 metadata value, uploads
without overwrite, and checks the public Blob length and hash metadata. Set
`OUTPUT_DIR`, `BACPAC_BLOB_PREFIX`, or `DELETE_LOCAL_AFTER_UPLOAD=1` as
needed.

Published BACPACs:

- [`tpchsf10_columnstore.bacpac`](https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_columnstore.bacpac)
- [`tpchsf10_rowstore.bacpac`](https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_rowstore.bacpac)

## 5. Export Parquet with CETAS and publish adjacent DDL

The canonical external-table data came from the standalone VM rowstore
database. The columnstore source was also exported for comparison. Each
destination prefix must be empty because CETAS does not overwrite output.

```bash
export SQL_SERVER='sql-vm.example.net'
export SQLCMD_TRUST_SERVER_CERTIFICATE=1
read -rsp 'Container SAS: ' AZURE_STORAGE_SAS_TOKEN
printf '\n'
export AZURE_STORAGE_SAS_TOKEN

./parquet/export_parquet_to_blob.sh tpchsf10_rowstore
./parquet/export_parquet_to_blob.sh tpchsf10_columnstore

unset AZURE_STORAGE_SAS_TOKEN
```

The wrapper performs these steps:

1. [`configure_cetas_credential.sh`](parquet/configure_cetas_credential.sh)
   creates a temporary SAS credential, CETAS data source, and Parquet format.
2. [`export_tpch_tables_parquet.sql`](parquet/export_tpch_tables_parquet.sql)
   runs eight CETAS operations under `tpch_parquet/<database>/dbo.<table>/`.
3. [`validate_tpch_parquet.sql`](parquet/validate_tpch_parquet.sql) reads every
   exported table and compares its row count with the source.
4. [`generate_tpch_schema.sql`](schemas/generate_tpch_schema.sql) produces one
   root `_schema.sql` plus a table-only `_schema.sql` adjacent to each table's
   Parquet files; Azure CLI uploads them with the same runtime SAS.
5. [`cleanup_tpch_parquet_objects.sql`](parquet/cleanup_tpch_parquet_objects.sql)
   removes the temporary external objects and scoped credential. It does not
   drop a database master key because that key might predate this workflow.

Public Parquet roots:

- [`tpch_parquet/tpchsf10_rowstore/`](https://tpcpublicstorage.blob.core.windows.net/tpch/tpch_parquet/tpchsf10_rowstore/_schema.sql)
- [`tpch_parquet/tpchsf10_columnstore/`](https://tpcpublicstorage.blob.core.windows.net/tpch/tpch_parquet/tpchsf10_columnstore/_schema.sql)

## 6. Create anonymous public external tables

Run these scripts in each final target database:

```bash
sqlcmd -S "$SQL_SERVER" -d "$SQL_DATABASE" -U "$SQL_USER" -N -b \
  -i parquet/create_tpch_parquet_resources.sql

sqlcmd -S "$SQL_SERVER" -d "$SQL_DATABASE" -U "$SQL_USER" -N -b \
  -v TARGET_SCHEMA=ext SOURCE_PREFIX=tpchsf10_rowstore \
  -i parquet/create_tpch_parquet_tables.sql

sqlcmd -S "$SQL_SERVER" -d "$SQL_DATABASE" -U "$SQL_USER" -N -b \
  -v TARGET_SCHEMA=ext \
  -i parquet/validate_tpch_parquet_external_tables.sql
```

The scripts are:

- [`create_tpch_parquet_resources.sql`](parquet/create_tpch_parquet_resources.sql)
- [`create_tpch_parquet_tables.sql`](parquet/create_tpch_parquet_tables.sql)
- [`validate_tpch_parquet_external_tables.sql`](parquet/validate_tpch_parquet_external_tables.sql)

No `DATABASE SCOPED CREDENTIAL` is associated with
`TPCHParquetBlob`; anonymous container access is intentional.

## 7. Generate and retain exact schema-only DDL

[`generate_tpch_schema.sql`](schemas/generate_tpch_schema.sql) reads internal
tables, indexes, key constraints, trusted/disabled foreign-key state, external
data sources, formats, and external tables. Run it in SQLCMD mode:

```bash
sqlcmd -S "$SQL_SERVER" -d "$SQL_DATABASE" -U "$SQL_USER" -N -b \
  -h -1 -W -w 65535 \
  -v SCHEMA_MODE=full SCHEMA_FILTER='*' TABLE_FILTER='*' \
  -i schemas/generate_tpch_schema.sql \
  -o generated_schema.sql
```

The exact final outputs are:

- [`tpchsf10_columnstore_schema.sql`](schemas/tpchsf10_columnstore_schema.sql)
  for the SQL Server VM.
- [`tpchsf100_schema.sql`](schemas/tpchsf100_schema.sql) for Azure SQL.

Public copies:

- <https://tpcpublicstorage.blob.core.windows.net/tpch/tpch_schemas/tpchsf10_columnstore_schema.sql>
- <https://tpcpublicstorage.blob.core.windows.net/tpch/tpch_schemas/tpchsf100_schema.sql>

## 8. Validate the final layouts

[`validate_tpch_demo_layout.sql`](database/validate_tpch_demo_layout.sql)
checks schema/table counts, physical index types, exact `rs` index count, all
10 trusted/enabled foreign keys, VM heap purity, internal column definitions,
internal row counts and checksums, all external row counts and paths, and the
anonymous external data source.

VM:

```bash
sqlcmd -S "$SQL_SERVER" -d tpchsf10_columnstore -U "$SQL_USER" -N -C -b \
  -v HAS_HP=1 RS_INDEX_COUNT=14 \
  -i database/validate_tpch_demo_layout.sql
```

Azure:

```bash
sqlcmd -S "$SQL_SERVER" -d tpchsf100 -U "$SQL_USER" -N -b \
  -v HAS_HP=0 RS_INDEX_COUNT=8 \
  -i database/validate_tpch_demo_layout.sql
```

The external count expectation is the canonical VM data set, including
59,999,496 `lineitem` rows, even when validation runs in Azure.

## 9. Run the read-only workload

[`tpch_readonly_workload.sql`](workload/tpch_readonly_workload.sql) contains
five original read-only analytic queries:

1. Shipping-mode summary.
2. Monthly customer-segment orders.
3. Regional realized revenue.
4. Supplier inventory value.
5. Late-delivery analysis.

These are not official TPC-H query texts. Every query uses `MAXDOP 4`.
Server-side UTC timestamps surround each query, and the workload total is the
sum of its five measured durations.

[`run_tpch_workload.sh`](workload/run_tpch_workload.sh) performs three
measured runs per schema in rotated order:

```text
run 1: dbo, rs, ext
run 2: rs, ext, dbo
run 3: ext, dbo, rs
```

There is no cache flush. The runner retries at most three times only for
recognized transient transport/database-resume failures. Failed attempts are
written to a temporary file and are never accepted as measurements.

Run both platforms into the same raw-results directory:

```bash
# VM
export SQL_SERVER='sql-vm.example.net'
export SQL_DATABASE='tpchsf10_columnstore'
export SQL_USER='demo_login'
export PLATFORM_LABEL=vm
export OUTPUT_DIR="$PWD/benchmark_raw"
export SQLCMD_TRUST_SERVER_CERTIFICATE=1
./workload/run_tpch_workload.sh

# Azure
export SQL_SERVER='logical-server.database.windows.net'
export SQL_DATABASE='tpchsf100'
export PLATFORM_LABEL=azure
unset SQLCMD_TRUST_SERVER_CERTIFICATE
./workload/run_tpch_workload.sh
```

Summarize the 18 successful run files:

```bash
python3 workload/summarize_tpch_workload.py \
  benchmark_raw \
  benchmark_summary
```

The summarizer validates file completeness and stable result signatures, then
writes:

- [`tpch_benchmark_results.csv`](workload/tpch_benchmark_results.csv): raw
  aggregated query/run rows.
- [`tpch_benchmark_summary.csv`](workload/tpch_benchmark_summary.csv): total
  median, minimum, maximum, mean, and relative median.
- [`tpch_benchmark_query_summary.csv`](workload/tpch_benchmark_query_summary.csv):
  per-query median and range.

Raw transient `sqlcmd` logs are deliberately not committed.

## Measured sample

| Environment | Configuration |
|---|---|
| VM | SQL Server 2025 `17.0.4065.4`, 4 vCPU, 16 GB RAM |
| Azure | General Purpose serverless `GP_S_Gen5_4`, 32 GB Free Limit maximum |

| Platform | Schema | Median total (ms) | Min-max (ms) | Relative median vs `dbo` |
|---|---|---:|---:|---:|
| VM | `dbo` | 7,702.216 | 7,696.564-8,484.814 | 1.000x |
| VM | `rs` | 69,776.388 | 63,346.022-71,550.015 | 9.059x |
| VM | `ext` | 22,560.034 | 22,165.645-36,505.472 | 2.929x |
| Azure | `dbo` | 13,228.108 | 10,501.126-15,570.172 | 1.000x |
| Azure | `rs` | 162,012.317 | 161,880.321-184,136.773 | 12.248x |
| Azure | `ext` | 28,002.765 | 27,810.244-53,781.392 | 2.117x |

These values describe one environment-specific sample workload. They are not
an audited or official TPC-H benchmark result, and VM-to-Azure timings are not
directly comparable.

## Public final artifacts

| Artifact | Public Blob URL |
|---|---|
| VM schema-only DDL | <https://tpcpublicstorage.blob.core.windows.net/tpch/tpch_schemas/tpchsf10_columnstore_schema.sql> |
| Azure schema-only DDL | <https://tpcpublicstorage.blob.core.windows.net/tpch/tpch_schemas/tpchsf100_schema.sql> |
| Workload SQL | <https://tpcpublicstorage.blob.core.windows.net/tpch/workload/tpch_readonly_workload.sql> |
| Workload runner | <https://tpcpublicstorage.blob.core.windows.net/tpch/workload/run_tpch_workload.sh> |
| Workload summarizer | <https://tpcpublicstorage.blob.core.windows.net/tpch/workload/summarize_tpch_workload.py> |
| Raw aggregated results | <https://tpcpublicstorage.blob.core.windows.net/tpch/workload/tpch_benchmark_results.csv> |
| Total summary | <https://tpcpublicstorage.blob.core.windows.net/tpch/workload/tpch_benchmark_summary.csv> |
| Per-query summary | <https://tpcpublicstorage.blob.core.windows.net/tpch/workload/tpch_benchmark_query_summary.csv> |

The same public container also hosts the top-level `.bak` and `.bacpac`
artifacts and the
[`tpch_parquet/`](https://tpcpublicstorage.blob.core.windows.net/tpch?restype=container&comp=list&prefix=tpch_parquet/)
roots described above.

## Sanitization and deliberate omissions

- No password, SAS token, storage account key, authentication cache, or
  credential-bearing command file is included.
- Raw per-attempt workload logs, temporary Blob manifests, validation
  manifests, and upload scratch files are excluded.
- Redundant exploratory probes and machine-specific one-off copy helpers are
  excluded. The supported archive sequence uses default SQL Server file
  locations instead.
- Generated schema DDL and the three final aggregated CSV artifacts are
  retained byte-for-byte from the completed workflow.
