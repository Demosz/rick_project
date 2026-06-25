import re
from pathlib import Path

from rules_service.models import Rule

_RULE_PATTERN = re.compile(r"^(\d+\.\d+[a-z]?)\.?\s+(.+)$", re.MULTILINE)


def parse(path: Path) -> list[Rule]:
    text = path.read_text(encoding="utf-8-sig")
    return [Rule(id=rid, text=body) for rid, body in _RULE_PATTERN.findall(text)]
