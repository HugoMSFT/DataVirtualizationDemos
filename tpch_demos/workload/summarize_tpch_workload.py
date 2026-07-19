#!/usr/bin/env python3
import argparse
import csv
import re
import statistics
from collections import defaultdict
from decimal import Decimal
from pathlib import Path


FILE_PATTERN = re.compile(r"^(vm|azure)_(dbo|rs|ext)_([1-3])\.txt$")
PLATFORMS = ("vm", "azure")
SCHEMAS = ("dbo", "rs", "ext")
ITERATIONS = (1, 2, 3)
QUERY_IDS = (1, 2, 3, 4, 5, 99)
STORAGE_TYPES = {
    "dbo": "clustered columnstore",
    "rs": "rowstore",
    "ext": "Parquet external",
}


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    return parser.parse_args()


def parse_results(input_dir):
    rows = []
    files = {}

    for path in input_dir.glob("*.txt"):
        match = FILE_PATTERN.match(path.name)
        if match:
            key = (match.group(1), match.group(2), int(match.group(3)))
            files[key] = path

    expected = {
        (platform, schema, iteration)
        for platform in PLATFORMS
        for schema in SCHEMAS
        for iteration in ITERATIONS
    }
    missing = sorted(expected - set(files))
    if missing:
        raise ValueError(f"Missing result files: {missing}")

    for key in sorted(expected):
        platform, schema, iteration = key
        path = files[key]
        query_ids = set()

        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue

            fields = line.split("|")
            if len(fields) != 8:
                raise ValueError(f"Invalid result line in {path}: {line}")

            (
                database_name,
                result_schema,
                result_iteration,
                query_id,
                query_name,
                duration_ms,
                result_rows,
                result_checksum,
            ) = fields

            parsed_query_id = int(query_id)
            if result_schema != schema or int(result_iteration) != iteration:
                raise ValueError(f"Result identity mismatch in {path}: {line}")
            if parsed_query_id in query_ids:
                raise ValueError(f"Duplicate query {parsed_query_id} in {path}")
            query_ids.add(parsed_query_id)

            rows.append(
                {
                    "platform": platform,
                    "database_name": database_name,
                    "schema": schema,
                    "storage_type": STORAGE_TYPES[schema],
                    "iteration": iteration,
                    "query_id": parsed_query_id,
                    "query_name": query_name,
                    "duration_ms": Decimal(duration_ms),
                    "result_rows": None
                    if result_rows == "NULL"
                    else int(result_rows),
                    "result_checksum": None
                    if result_checksum == "NULL"
                    else int(result_checksum),
                }
            )

        if query_ids != set(QUERY_IDS):
            raise ValueError(f"Query set mismatch in {path}: {sorted(query_ids)}")

    return rows


def validate_signatures(rows):
    signatures = defaultdict(set)
    for row in rows:
        if row["query_id"] == 99:
            continue
        key = (row["platform"], row["schema"], row["query_id"])
        signatures[key].add((row["result_rows"], row["result_checksum"]))

    inconsistent = [key for key, values in signatures.items() if len(values) != 1]
    if inconsistent:
        raise ValueError(f"Signatures changed between iterations: {inconsistent}")

    for query_id in QUERY_IDS[:-1]:
        vm_values = {
            next(iter(signatures[("vm", schema, query_id)]))
            for schema in SCHEMAS
        }
        if len(vm_values) != 1:
            raise ValueError(
                f"VM schemas returned different results for query {query_id}"
            )

        azure_values = {
            next(iter(signatures[("azure", schema, query_id)]))
            for schema in ("dbo", "rs")
        }
        if len(azure_values) != 1:
            raise ValueError(
                f"Azure internal schemas returned different results for query {query_id}"
            )


def write_raw_csv(rows, output_dir):
    path = output_dir / "tpch_benchmark_results.csv"
    fieldnames = (
        "platform",
        "database_name",
        "schema",
        "storage_type",
        "iteration",
        "query_id",
        "query_name",
        "duration_ms",
        "result_rows",
        "result_checksum",
    )
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        for row in sorted(
            rows,
            key=lambda value: (
                value["platform"],
                value["iteration"],
                value["schema"],
                value["query_id"],
            ),
        ):
            writer.writerow(row)


def write_summary_csv(rows, output_dir):
    totals = defaultdict(list)
    first_runs = {}
    for row in rows:
        if row["query_id"] != 99:
            continue
        key = (row["platform"], row["schema"])
        totals[key].append(row["duration_ms"])
        if row["iteration"] == 1:
            first_runs[key] = row["duration_ms"]

    medians = {
        key: statistics.median(durations)
        for key, durations in totals.items()
    }

    path = output_dir / "tpch_benchmark_summary.csv"
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(
            (
                "platform",
                "schema",
                "storage_type",
                "runs",
                "first_run_ms",
                "median_ms",
                "min_ms",
                "max_ms",
                "mean_ms",
                "relative_to_columnstore",
            )
        )

        for platform in PLATFORMS:
            baseline = medians[(platform, "dbo")]
            for schema in SCHEMAS:
                key = (platform, schema)
                durations = totals[key]
                writer.writerow(
                    (
                        platform,
                        schema,
                        STORAGE_TYPES[schema],
                        len(durations),
                        first_runs[key],
                        medians[key],
                        min(durations),
                        max(durations),
                        Decimal(str(statistics.mean(durations))).quantize(
                            Decimal("0.001")
                        ),
                        (medians[key] / baseline).quantize(Decimal("0.001")),
                    )
                )


def write_query_summary_csv(rows, output_dir):
    durations = defaultdict(list)
    query_names = {}
    for row in rows:
        if row["query_id"] == 99:
            continue
        key = (row["platform"], row["schema"], row["query_id"])
        durations[key].append(row["duration_ms"])
        query_names[row["query_id"]] = row["query_name"]

    path = output_dir / "tpch_benchmark_query_summary.csv"
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(
            (
                "platform",
                "schema",
                "storage_type",
                "query_id",
                "query_name",
                "median_ms",
                "min_ms",
                "max_ms",
            )
        )
        for key in sorted(durations):
            platform, schema, query_id = key
            values = durations[key]
            writer.writerow(
                (
                    platform,
                    schema,
                    STORAGE_TYPES[schema],
                    query_id,
                    query_names[query_id],
                    statistics.median(values),
                    min(values),
                    max(values),
                )
            )


def main():
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    rows = parse_results(args.input_dir)
    validate_signatures(rows)
    write_raw_csv(rows, args.output_dir)
    write_summary_csv(rows, args.output_dir)
    write_query_summary_csv(rows, args.output_dir)


if __name__ == "__main__":
    main()
