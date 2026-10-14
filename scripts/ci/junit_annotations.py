"""Turns a JUnit XML report into GitHub annotations and a job summary.

Annotations and summaries are visible on public runs without signing in, so failures can be
diagnosed from the run page. Usage: python scripts/ci/junit_annotations.py report.xml
"""

import os
import sys
import xml.etree.ElementTree as ET

MAX = 20


def main(path: str) -> int:
    root = ET.parse(path).getroot()
    failures = []
    for case in root.iter("testcase"):
        problem = case.find("failure")
        if problem is None:
            problem = case.find("error")
        if problem is None:
            continue
        name = f"{case.get('classname', '')}::{case.get('name', '')}"
        text = (problem.get("message") or "") + "\n" + (problem.text or "")
        failures.append((name, text.strip()))

    for name, text in failures[:MAX]:
        tail = " | ".join(line for line in text.splitlines()[-12:] if line.strip())
        tail = tail.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
        print(f"::error title={name}::{tail[:1800]}")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as out:
            out.write(f"## Test failures ({len(failures)})\n\n")
            for name, text in failures[:MAX]:
                out.write(
                    f"<details><summary>{name}</summary>\n\n```\n{text[-4000:]}\n```\n</details>\n\n"
                )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
