"""Render a markdown access diff (base vs head) for a governance PR.

Compares two versions of access_matrix.json + members/*.csv and emits
"who gains/loses what" lines. CI extracts the base copies with `git show`
and posts the output as a sticky PR comment.
"""

import argparse
import json
from pathlib import Path


def load_matrix(path: Path) -> dict:
    """Load an access matrix; a missing file counts as no teams."""
    if not path or not path.exists():
        return {"teams": {}}
    return json.loads(path.read_text(encoding="utf-8"))


def load_members(members_dir: Path) -> dict[str, dict[str, str]]:
    """team -> {email: name}. Missing dir/file = empty."""
    out: dict[str, dict[str, str]] = {}
    if not members_dir or not members_dir.exists():
        return out
    for csv_path in sorted(members_dir.glob("*.csv")):
        lines = csv_path.read_text(encoding="utf-8").splitlines()
        people: dict[str, str] = {}
        for line in lines[1:]:  # skip header
            if not line.strip():
                continue
            cols = [c.strip() for c in line.split(",")]
            if len(cols) >= 2 and cols[1]:
                people[cols[1].lower()] = cols[0]
        out[csv_path.stem] = people
    return out


def grant_set(matrix: dict) -> dict[tuple[str, str], set[str]]:
    """(team, "catalog/schema") -> set(privileges)."""
    out: dict[tuple[str, str], set[str]] = {}
    for team_key, team in matrix.get("teams", {}).items():
        for schema_key, privileges in team.get("schema_grants", {}).items():
            out[(team_key, schema_key)] = set(privileges)
    return out


def render(base_matrix: dict, head_matrix: dict,
           base_members: dict, head_members: dict) -> str:
    """Build the markdown diff of grants and membership."""
    lines: list[str] = []

    # access matrix changes
    base_g = grant_set(base_matrix)
    head_g = grant_set(head_matrix)
    base_teams = set(base_matrix.get("teams", {}))
    head_teams = set(head_matrix.get("teams", {}))

    access_lines: list[str] = []
    for team in sorted(head_teams - base_teams):
        access_lines.append(f"- **new team** `{team}`")
    for team in sorted(base_teams - head_teams):
        access_lines.append(f"- **team removed** `{team}`")

    def privs(items: list[str]) -> str:
        return ", ".join(f"`{p}`" for p in items)

    for key in sorted(set(base_g) | set(head_g)):
        team, schema = key
        before = base_g.get(key, set())
        after = head_g.get(key, set())
        if before == after:
            continue
        gained = sorted(after - before)
        lost = sorted(before - after)
        if before and not after:
            access_lines.append(
                f"- `{team}` **loses all access** to `{schema}` (was {privs(sorted(before))})"
            )
            continue
        if after and not before:
            access_lines.append(f"- `{team}` **gains** {privs(gained)} on `{schema}`")
            continue
        parts = []
        if gained:
            parts.append(f"gains {privs(gained)}")
        if lost:
            parts.append(f"loses {privs(lost)}")
        access_lines.append(f"- `{team}` {' and '.join(parts)} on `{schema}`")

    lines.append("### Access matrix changes")
    lines.append("")
    lines.extend(access_lines if access_lines else ["_No grant changes._"])
    lines.append("")

    # membership changes
    member_lines: list[str] = []
    for team in sorted(set(base_members) | set(head_members)):
        before = base_members.get(team, {})
        after = head_members.get(team, {})
        for email in sorted(set(after) - set(before)):
            member_lines.append(f"- + {after[email]} (`{email}`) joins `{team}`")
        for email in sorted(set(before) - set(after)):
            member_lines.append(f"- − {before[email]} (`{email}`) leaves `{team}`")

    lines.append("### Membership changes")
    lines.append("")
    lines.extend(member_lines if member_lines else ["_No membership changes._"])
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    """CLI entry point."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-matrix", type=Path, required=True)
    parser.add_argument("--head-matrix", type=Path, required=True)
    parser.add_argument("--base-members-dir", type=Path, required=True)
    parser.add_argument("--head-members-dir", type=Path, required=True)
    args = parser.parse_args()

    print(render(
        load_matrix(args.base_matrix), load_matrix(args.head_matrix),
        load_members(args.base_members_dir), load_members(args.head_members_dir),
    ))


if __name__ == "__main__":
    main()
