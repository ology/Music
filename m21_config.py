import json
import os
from textual.app import App, ComposeResult
from textual.containers import VerticalScroll
from textual.widgets import Header, Footer, Label, Input, Button
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

class M21EnvConfig(App):
    TITLE = "Music21 Environment Configuration"
    SUB_TITLE="Quit: CRTL-Q"

    def compose(self) -> ComposeResult:
        us = environment.UserSettings()
        yield Header()
        with VerticalScroll():
            for key in ALL_KEYS:
                value = us[key]
                if value is None:
                    value = ''
                else:
                    value = str(value)
                yield Label(f"{key}")
                yield Input(placeholder=f"Set value for {key}", id=key, value=value)
            yield Button("Save", id="save_button", variant="primary", compact=True)
            yield Button("Quit", id="quit_button", variant="default", compact=True)

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "quit_button":
            self.exit()
        elif event.button.id == "save_button":
            us = environment.UserSettings()
            for key in ALL_KEYS:
                input_widget = self.query_one(f"#{key}", Input)
                new_value = input_widget.value
                try:
                    new_value
                except NameError:
                    pass
                else:
                    is_path = key.endswith("Path")
                    if is_path and not os.path.exists(new_value):
                        new_value = ''
                    if key == 'localCorporaSettings':
                        new_value = json.loads(new_value)
                    if key == 'localCorpusSettings':
                        pass # XXX setting this value is confusing so far...
                    else:
                        us[key] = new_value

            # nb: music21 automatically saves changes to the settings file
            self.log("Settings saved successfully!")
            self.exit()

if __name__ == "__main__":
    app = M21EnvConfig()
    app.run()