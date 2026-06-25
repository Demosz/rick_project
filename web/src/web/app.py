from flask import Flask, render_template
import os
import requests

app = Flask(__name__)

RULES_SERVICE_URL = os.environ.get("RULES_SERVICE_URL", "http://localhost:8001")

PLACEHOLDER_RULE = {
    "id": "100.1a",
    "text": (
        "These Magic rules apply to any game with two or more players, "
        "including two-player games and multiplayer games."
    ),
}


@app.route("/")
def index():
    try:
        response = requests.get(f"{RULES_SERVICE_URL}/rule/random", timeout=2)
        response.raise_for_status()
        return render_template("index.html", rule=response.json())
    except requests.exceptions.RequestException:
        return render_template("index.html", rule=None), 502


@app.route("/healthz")
def healthz():
    return {"status": "ok"}
