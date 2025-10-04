from textual.app import App, ComposeResult
from textual.containers import VerticalScroll, Vertical, Horizontal
from textual.widgets import Header, Footer, Label, Static, Input, Button
from music21 import environment

ALL_KEYS = [
    "autoDownload",
    "braillePath",
    "debug",
    "directoryScratch",
    "graphicsPath",
    "ipythonShowFormat",
    "lilypondBackend",
    "lilypondFormat",
    "lilypondPath",
    "lilypondVersion",
    "localCorporaSettings",
    "localCorpusPath",
    "localCorpusSettings",
    "manualCoreCorpusPath",
    "midiPath",
    "musescoreDirectPNGPath",
    "musicxmlPath",
    "pdfPath",
    "showFormat",
    "vectorPath",
    "warnings",
    "writeFormat",
]

class MyScrollableApp(App):
    TITLE = "Music21 Environment Configuration"
    SUB_TITLE="Quit: CRTL-Q"

    def compose(self) -> ComposeResult:
        us = environment.UserSettings()
        yield Header()
        with VerticalScroll():
            for key in ALL_KEYS:
                value = us[key]
                yield Label(f"{key}")
                yield Input(placeholder=f"Set value for {key}", id=key, value=str(value))
        yield Footer()

if __name__ == "__main__":
    app = MyScrollableApp()
    app.run()