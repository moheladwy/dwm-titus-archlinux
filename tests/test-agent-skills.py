#!/usr/bin/env python3
"""Validate the shipped agent skills against the Agent Skills format and this tree."""

import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SKILLS = REPO / "config" / "agents" / "skills"
# Agents discover project skills here; both entries link to SKILLS.
LINK_DIRS = (REPO / ".agents" / "skills", REPO / ".claude" / "skills")
NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
# A helper named as a command: at the start of a code line or right after a
# backtick, followed by whitespace, a backtick, or the end of the line.
COMMAND = re.compile(r"(?:^|`)\s*((?:dwm-[a-z0-9-]+|webapp-[a-z]+|install-[a-z]+|"
                     r"[a-z0-9-]+\.sh))(?=[\s`]|$)", re.M)
# Product and file names that look like helpers but are not commands.
NOT_COMMANDS = {"dwm-titus", "install.sh"}
failures = []


def fail(message):
    failures.append(message)


def frontmatter(path):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        fail(f"{path}: frontmatter must open on the first line")
        return {}, text
    end = text.find("\n---\n", 4)
    if end < 0:
        fail(f"{path}: frontmatter is not closed")
        return {}, text
    fields, key = {}, None
    for line in text[4:end].splitlines():
        match = re.fullmatch(r"([a-z_-]+):\s*(.*)", line)
        if match:
            key = match.group(1)
            fields[key] = "" if match.group(2) in (">", ">-", "|", "|-") else match.group(2)
        elif key and line.startswith("  "):
            fields[key] = (fields[key] + " " + line.strip()).strip()
        elif line.strip():
            fail(f"{path}: unexpected frontmatter line: {line!r}")
    return fields, text[end + 5:]


def commands():
    makefile = (REPO / "Makefile").read_text(encoding="utf-8")
    block = re.search(r"^INSTALL_COMMANDS = \\\n((?:\t.*\\?\n)+)", makefile, re.M)
    if block is None:
        fail("Makefile: INSTALL_COMMANDS was not found")
        return set()
    return {Path(entry).name for entry in block.group(1).replace("\\", " ").split()}


skills = sorted(path for path in SKILLS.iterdir() if path.is_dir()) if SKILLS.is_dir() else []
if not skills:
    fail(f"{SKILLS}: no skills found")
installed = commands()
for skill in skills:
    manifest = skill / "SKILL.md"
    if not manifest.is_file():
        fail(f"{skill}: SKILL.md is missing")
        continue
    fields, body = frontmatter(manifest)
    name, description = fields.get("name", ""), fields.get("description", "")
    if name != skill.name or not NAME.fullmatch(name) or len(name) > 64:
        fail(f"{manifest}: name must be lowercase-hyphenated, at most 64 characters, and match {skill.name!r}")
    if not description or len(description) > 1024:
        fail(f"{manifest}: description must be 1-1024 characters, found {len(description)}")
    if len(manifest.read_text(encoding="utf-8").splitlines()) >= 500:
        fail(f"{manifest}: keep SKILL.md under 500 lines")
    for target in re.findall(r"\]\(([^)#:]+\.md)\)", body):
        if not (skill / target).is_file():
            fail(f"{manifest}: linked guide {target} does not exist")
    for document in sorted(skill.rglob("*.md")):
        text = document.read_text(encoding="utf-8")
        if not text.isascii():
            fail(f"{document}: use ASCII punctuation only")
        for command in sorted(set(COMMAND.findall(text)) - NOT_COMMANDS):
            if command not in installed:
                fail(f"{document}: {command} is not an installed command in INSTALL_COMMANDS")
    for link_dir in LINK_DIRS:
        link = link_dir / skill.name
        if not link.is_symlink() or os.readlink(link) != f"../../config/agents/skills/{skill.name}":
            fail(f"{link}: must be a symlink to ../../config/agents/skills/{skill.name}")
for link_dir in LINK_DIRS:
    for entry in sorted(link_dir.iterdir()) if link_dir.is_dir() else []:
        if not (SKILLS / entry.name).is_dir():
            fail(f"{entry}: linked skill has no config/agents/skills source")

if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
print(f"Agent skills: {len(skills)} validated")
