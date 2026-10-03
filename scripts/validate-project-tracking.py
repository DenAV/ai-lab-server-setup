#!/usr/bin/env python3
"""Validate roadmap and TODO phase traceability."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ROADMAP_PATH = ROOT / "docs" / "project" / "ROADMAP.md"
TODO_PATH = ROOT / "docs" / "project" / "TODO.md"
PHASE_HEADING = re.compile(r"^## (P\d+): .+$", re.MULTILINE)
CURRENT_PHASE = re.compile(r"^\*\*Current phase:\*\* (?:\[)?(P\d+)", re.MULTILINE)
TODO_STATUS = re.compile(
    r"^\*\*Status:\*\* ([A-Za-z ]+?)(?: — (\d+)/(\d+) tasks)?$", re.MULTILINE
)
ROADMAP_STATUS = re.compile(r"^\*\*Status:\*\* ([A-Za-z ]+)$", re.MULTILINE)
TASK = re.compile(r"^- \[([ x])\] \*\*(P\d+-\d{2})\*\*", re.MULTILINE)
ROADMAP_TABLE = re.compile(
    r"^\| \[(P\d+)\]\([^)]+\) \| ([A-Za-z ]+) \| (\d+)/(\d+) \|",
    re.MULTILINE,
)


def sections(text: str) -> dict[str, str]:
    headings = list(PHASE_HEADING.finditer(text))
    return {
        match.group(1): text[match.end() : headings[index + 1].start()]
        if index + 1 < len(headings)
        else text[match.end() :]
        for index, match in enumerate(headings)
    }


def main() -> int:
    roadmap = ROADMAP_PATH.read_text(encoding="utf-8")
    todo = TODO_PATH.read_text(encoding="utf-8")
    errors: list[str] = []

    roadmap_sections = sections(roadmap)
    todo_sections = sections(todo)
    if set(roadmap_sections) != set(todo_sections):
        errors.append(
            f"phase IDs differ: roadmap={sorted(roadmap_sections)}, "
            f"todo={sorted(todo_sections)}"
        )

    roadmap_current = CURRENT_PHASE.search(roadmap)
    todo_current = CURRENT_PHASE.search(todo)
    if not roadmap_current or not todo_current:
        errors.append("roadmap and TODO must both declare Current phase")
    elif roadmap_current.group(1) != todo_current.group(1):
        errors.append(
            f"current phase differs: roadmap={roadmap_current.group(1)}, "
            f"todo={todo_current.group(1)}"
        )

    table_rows = {
        phase: (status.strip(), int(done), int(total))
        for phase, status, done, total in ROADMAP_TABLE.findall(roadmap)
    }
    if set(table_rows) != set(roadmap_sections):
        errors.append("roadmap status table must contain every phase exactly once")

    all_task_ids: list[str] = []
    for phase, section in todo_sections.items():
        status_match = TODO_STATUS.search(section)
        if not status_match or status_match.group(2) is None:
            errors.append(f"TODO {phase} must declare status and completed/total task count")
            continue
        status = status_match.group(1).strip()
        declared_done = int(status_match.group(2))
        declared_total = int(status_match.group(3))
        tasks = TASK.findall(section)
        task_ids = [task_id for _, task_id in tasks]
        all_task_ids.extend(task_ids)
        actual_done = sum(marker == "x" for marker, _ in tasks)
        if any(not task_id.startswith(f"{phase}-") for task_id in task_ids):
            errors.append(f"TODO {phase} contains a task ID from another phase")
        if (declared_done, declared_total) != (actual_done, len(tasks)):
            errors.append(
                f"TODO {phase} declares {declared_done}/{declared_total}, "
                f"but checkboxes are {actual_done}/{len(tasks)}"
            )
        table_status = table_rows.get(phase)
        if table_status and table_status != (status, actual_done, len(tasks)):
            errors.append(
                f"roadmap table {phase} is {table_status}, "
                f"but TODO is {(status, actual_done, len(tasks))}"
            )

    if len(all_task_ids) != len(set(all_task_ids)):
        errors.append("TODO task IDs must be unique")

    for phase, section in roadmap_sections.items():
        status_match = ROADMAP_STATUS.search(section)
        if not status_match:
            errors.append(f"roadmap {phase} must declare a status")
        elif phase in table_rows and status_match.group(1).strip() != table_rows[phase][0]:
            errors.append(f"roadmap {phase} status differs from its status table row")
        if "**Exit gate:**" not in section:
            errors.append(f"roadmap {phase} must include a checkbox exit gate")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        f"Project tracking valid: {len(todo_sections)} phases, "
        f"{len(all_task_ids)} stable tasks, current {roadmap_current.group(1)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
