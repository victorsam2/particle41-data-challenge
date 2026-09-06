#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ -n "${PYTHON:-}" ]]; then
    python_bin="$PYTHON"
else
    python_bin=""
    for candidate in python3.13 python3.12 python3.11 python3; do
        if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; raise SystemExit(not ((3, 11) <= sys.version_info[:2] < (3, 14)))'; then
            python_bin="$candidate"
            break
        fi
    done
fi

if [[ -z "$python_bin" ]] || ! "$python_bin" -c 'import sys; raise SystemExit(not ((3, 11) <= sys.version_info[:2] < (3, 14)))'; then
    echo "Python 3.11, 3.12, or 3.13 is required." >&2
    exit 1
fi

if [[ ! -x .venv/bin/python ]]; then
    "$python_bin" -m venv .venv
fi

.venv/bin/python -c 'import sys; sys.exit("Recreate .venv with Python 3.11-3.13.") if not ((3, 11) <= sys.version_info[:2] < (3, 14)) else None'
.venv/bin/python -m pip install --disable-pip-version-check -r requirements.txt
.venv/bin/python -m pip check

mkdir -p data
export DBT_SEND_ANONYMOUS_USAGE_STATS=false
export DUCKDB_PATH="$PWD/data/warehouse.duckdb"
.venv/bin/dbt parse --project-dir dbt --profiles-dir dbt --no-partial-parse

echo "Base environment and dbt configuration validated. Ingestion and models are not implemented yet."
