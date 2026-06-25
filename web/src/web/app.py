from flask import Flask, render_template

app = Flask(__name__)

PLACEHOLDER_RULE = {
    "id": "100.1a",
    "text": (
        "These Magic rules apply to any game with two or more players, "
        "including two-player games and multiplayer games."
    ),
}


@app.route("/")
def index():
    return render_template("index.html", rule=PLACEHOLDER_RULE)
