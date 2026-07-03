"""Lint access_matrix.json + members/*.csv for the PR check.

Validates CSV headers/emails, the 1:1 team<->CSV mapping, and that matrix
privileges stay within the allowed set. Exit 0 clean, 1 with violations printed.
"""

import argparse
import json
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
GOV_DIR = SCRIPT_DIR.parent
DEFAULT_MATRIX = GOV_DIR / "access_matrix.json"
DEFAULT_MEMBERS_DIR = GOV_DIR / "members"
ALLOWED_PRIVILEGES = {"USE_SCHEMA", "SELECT", "MODIFY"}
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def lint(matrix_path: Path, members_dir: Path) -> list[str]:
    """Return a list of violations; empty means the config is clean."""
    violations: list[str] = []

    matrix = json.loads(matrix_path.read_text(encoding="utf-8"))
    teams = matrix.get("teams", {})
    matrix_team_set = set(teams.keys())

    # Privilege allow-set
    for team_key, team in teams.items():
        for schema_key, privileges in team.get("schema_grants", {}).items():
            bad = [p for p in privileges if p not in ALLOWED_PRIVILEGES]
            if bad:
                violations.append(
                    f"{matrix_path.name}: team '{team_key}' grant '{schema_key}' has "
                    f"privilege(s) {bad} outside the allowed set {sorted(ALLOWED_PRIVILEGES)}."
                )

    # CSV team set vs matrix team set (1:1)
    csv_team_set = {p.stem for p in members_dir.glob("*.csv")}
    for missing in sorted(matrix_team_set - csv_team_set):
        violations.append(
            f"team '{missing}' is in {matrix_path.name} but has no members/{missing}.csv."
        )
    for extra in sorted(csv_team_set - matrix_team_set):
        violations.append(
            f"members/{extra}.csv exists but '{extra}' is not a team in {matrix_path.name}."
        )

    # Per-CSV header + email checks
    for team_key in sorted(csv_team_set):
        csv_path = members_dir / f"{team_key}.csv"
        lines = csv_path.read_text(encoding="utf-8").splitlines()
        if not lines or [c.strip() for c in lines[0].split(",")] != ["name", "email"]:
            header = lines[0] if lines else "<empty file>"
            violations.append(
                f"members/{team_key}.csv: header must be exactly 'name,email' (got '{header}')."
            )
            continue
        seen: set[str] = set()
        for n, line in enumerate(lines[1:], start=2):
            if not line.strip():
                continue
            cols = [c.strip() for c in line.split(",")]
            if len(cols) < 2 or not cols[1]:
                violations.append(f"members/{team_key}.csv:{n}: row has no email.")
                continue
            email = cols[1].lower()
            if not EMAIL_RE.match(email):
                violations.append(
                    f"members/{team_key}.csv:{n}: '{cols[1]}' is not a plausible email."
                )
            if email in seen:
                violations.append(
                    f"members/{team_key}.csv:{n}: duplicate email '{email}' within the team."
                )
            seen.add(email)

    return violations


def main() -> None:
    """CLI entry point."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", type=Path, default=DEFAULT_MATRIX)
    parser.add_argument("--members-dir", type=Path, default=DEFAULT_MEMBERS_DIR)
    args = parser.parse_args()

    violations = lint(args.matrix, args.members_dir)
    if violations:
        print(f"Access config lint FAILED ({len(violations)} violation(s)):")
        for v in violations:
            print(f"  - {v}")
        sys.exit(1)
    print("Access config lint passed.")


if __name__ == "__main__":
    main()
