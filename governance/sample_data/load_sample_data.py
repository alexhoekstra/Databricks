"""Run the sample-data SQL through the Databricks SQL Statement Execution API."""

import argparse
import os
import sys
import time
from pathlib import Path

from databricks.sdk import WorkspaceClient
from databricks.sdk.service.sql import StatementState

# row_filters_masks.sql must run LAST: the gold CTAS statements read silver
# before the filters bind, otherwise the aggregates silently lose rows.
DEFAULT_FILES = [
    "sample_data_hr.sql",
    "sample_data_finance.sql",
    "sample_data_programs.sql",
    "row_filters_masks.sql",
]

POLL_SECONDS = 2


def split_statements(sql: str) -> list[str]:
    """Split on ';' after stripping '--' comment lines (the SQL is written so
    every ';' ends a statement)."""
    code_lines = [
        line for line in sql.splitlines() if not line.strip().startswith("--")
    ]
    return [s.strip() for s in "\n".join(code_lines).split(";") if s.strip()]


def pick_warehouse(client: WorkspaceClient) -> str:
    """Warehouse from the env override, else the first in the workspace."""
    if warehouse_id := os.environ.get("DATABRICKS_WAREHOUSE_ID"):
        return warehouse_id
    warehouses = list(client.warehouses.list())
    if warehouses and warehouses[0].id:
        return warehouses[0].id
    sys.exit("No SQL warehouse found and DATABRICKS_WAREHOUSE_ID is not set.")


def execute(client: WorkspaceClient, warehouse_id: str, statement: str) -> None:
    """Run one statement and poll until it finishes; exit on failure."""
    response = client.statement_execution.execute_statement(
        statement=statement,
        warehouse_id=warehouse_id,
        wait_timeout="50s",  # API maximum; poll beyond it
    )
    statement_id, status = response.statement_id, response.status
    if statement_id is None:
        sys.exit("Statement execution returned no statement_id.")

    while status and status.state in (StatementState.PENDING, StatementState.RUNNING):
        time.sleep(POLL_SECONDS)
        status = client.statement_execution.get_statement(statement_id).status

    if status is None or status.state != StatementState.SUCCEEDED:
        message = (status.error.message if status and status.error else None) or (
            str(status.state) if status else "no status returned"
        )
        sys.exit(f"FAILED: {message}\n  in statement: {statement[:160]}...")


def main() -> None:
    """CLI entry point."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hr-catalog", default="hr")
    parser.add_argument("--finance-catalog", default="finance")
    parser.add_argument("--programs-catalog", default="programs")
    parser.add_argument(
        "--files",
        nargs="+",
        default=DEFAULT_FILES,
        help="SQL files (relative to this script) to run, in order",
    )
    args = parser.parse_args()

    substitutions = {
        "{{hr}}": args.hr_catalog,
        "{{finance}}": args.finance_catalog,
        "{{programs}}": args.programs_catalog,
    }

    client = WorkspaceClient()
    warehouse_id = pick_warehouse(client)
    print(f"Using warehouse {warehouse_id}")

    script_dir = Path(__file__).resolve().parent
    for file_name in args.files:
        sql = (script_dir / file_name).read_text(encoding="utf-8")
        for placeholder, value in substitutions.items():
            sql = sql.replace(placeholder, value)

        statements = split_statements(sql)
        print(f"{file_name}: {len(statements)} statements")
        for index, statement in enumerate(statements, start=1):
            first_line = statement.splitlines()[0]
            print(f"  [{index}/{len(statements)}] {first_line[:80]}")
            execute(client, warehouse_id, statement)

    print("Done.")


if __name__ == "__main__":
    main()
