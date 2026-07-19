#!/usr/bin/env python3
import os
import sys
from pathlib import Path


secret_file = os.environ.get("MSSQL_PASSWORD_FILE")
if secret_file:
    secret = Path(secret_file).read_text(encoding="utf-8").rstrip("\r\n")
else:
    secret = os.environ.get("MSSQL_PASSWORD")
if not secret:
    raise RuntimeError("MSSQL_PASSWORD or MSSQL_PASSWORD_FILE must be set")

escaped_secret = secret.replace("#", r"\#")

for line in sys.stdin:
    sys.stdout.write(
        line.replace(secret, "[REDACTED]").replace(escaped_secret, "[REDACTED]")
    )
    sys.stdout.flush()
