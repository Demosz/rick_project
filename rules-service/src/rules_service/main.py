from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="rules-service", description="MTG rules backend")


class Rule(BaseModel):
    id: str
    text: str


PLACEHOLDER_RULE = Rule(
    id="100.1a",
    text=(
        "These Magic rules apply to any game with two or more players, "
        "including two-player games and multiplayer games."
    ),
)


@app.get("/rule/random", response_model=Rule)
def get_random_rule() -> Rule:
    return PLACEHOLDER_RULE


@app.get("/rule/{rule_id}", response_model=Rule)
def get_rule_by_id(rule_id: str) -> Rule:
    return PLACEHOLDER_RULE
