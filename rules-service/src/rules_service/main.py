import random
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from rules_service.parser import parse


class Rule(BaseModel):
    id: str
    text: str


_RULES_PATH = Path(__file__).parent.parent.parent / "data" / "MagicCompRules.txt"
_RULES_LIST: list[Rule] = parse(_RULES_PATH)
_RULES_BY_ID: dict[str, Rule] = {r.id: r for r in _RULES_LIST}


app = FastAPI(title="rules-service", description="MTG rules backend")


@app.get("/rule/random", response_model=Rule)
def get_random_rule() -> Rule:
    return random.choice(_RULES_LIST)


@app.get("/rule/{rule_id}", response_model=Rule)
def get_rule_by_id(rule_id: str) -> Rule:
    rule = _RULES_BY_ID.get(rule_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Rule not found")
    return rule
