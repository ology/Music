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
            yield Button("Save", id="save_button", variant="primary")
            yield Button("Quit", id="quit_button", variant="default")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "quit_button":
            self.exit()

        elif event.button.id == "save_button":
            us = environment.UserSettings()
            for key in us.keys():
                input_widget = self.query_one(f"#input_{key}", Input)
                new_value = input_widget.value
                us[key] = new_value

            # nb: music21 automatically saves changes to the settings file
            self.log("Settings saved successfully!")
            self.exit()

if __name__ == "__main__":
    app = MyScrollableApp()
    app.run()