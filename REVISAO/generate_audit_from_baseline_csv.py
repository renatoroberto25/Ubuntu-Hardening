#!/usr/bin/env python3
import csv
import sys


FIELDS = ("type", "description", "info", "solution", "reference", "see_also", "cmd", "expect")


def quote(value):
    return (value or "").replace("\\", "\\\\").replace('"', '\\"')


def main():
    if len(sys.argv) != 3:
        print("Usage: generate_audit_from_baseline_csv.py <baseline.csv> <output.audit>", file=sys.stderr)
        return 2

    csv_path, audit_path = sys.argv[1], sys.argv[2]

    with open(csv_path, encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source, delimiter=";"))

    with open(audit_path, "w", encoding="utf-8", newline="\n") as target:
        target.write('<check_type:"Unix">\n\n')
        for row in rows:
            audit_type = row.get("audit_type") or row.get("type") or "CMD_EXEC"
            values = {
                "type": audit_type,
                "description": row.get("description") or f'{row.get("id", "")}, {row.get("topic", "")}',
                "info": row.get("info", ""),
                "solution": row.get("solution", ""),
                "reference": row.get("reference", ""),
                "see_also": row.get("see_also", ""),
                "cmd": row.get("cmd", ""),
                "expect": row.get("expect", ""),
            }

            target.write("<custom_item>\n")
            for field in FIELDS:
                if values[field]:
                    if field == "type":
                        target.write(f'  {field:<11} : {values[field]}\n')
                    else:
                        target.write(f'  {field:<11} : "{quote(values[field])}"\n')
            target.write("</custom_item>\n\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
