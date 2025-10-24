#!/usr/bin/env python3

# Simple Tkinter app to build a YAML list of control items.

import os
import json
import tkinter as tk
from tkinter import ttk, messagebox
from tkinter import scrolledtext
import yaml
import yaml

OUTFILE = os.path.join(os.path.dirname(__file__), "controls.yaml")

def try_load_existing():
    try:
        with open(OUTFILE, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or []
            return data if isinstance(data, list) else []
    except Exception:
        # if file missing or yaml not installed or parse error, ignore and return empty list
        try:
            if not os.path.exists(OUTFILE):
                return []
            with open(OUTFILE, "r", encoding="utf-8") as f:
                # very simple parse: look for lines that start with '- ' and naive key: value pairs
                items = []
                curr = None
                for ln in f:
                    ln = ln.rstrip("\n")
                    if ln.strip().startswith("-"):
                        if curr:
                            items.append(curr)
                        curr = {}
                    else:
                        if ":" in ln and curr is not None:
                            k, v = ln.split(":", 1)
                            k = k.strip()
                            v = v.strip().strip('"').strip("'")
                            curr[k] = v
                if curr:
                    items.append(curr)
                return items
        except Exception:
            return []

def dump_yaml(data_list):
    try:
        # preserve block style list
        return yaml.safe_dump(data_list, default_flow_style=False, sort_keys=False, allow_unicode=True)
    except Exception:
        # simple YAML-ish dump using JSON for values (valid YAML)
        lines = []
        for item in data_list:
            lines.append("-")
            for k, v in item.items():
                # use json.dumps to produce a safe quoted representation
                lines.append(f"  {k}: {json.dumps(v, ensure_ascii=False)}")
        return "\n".join(lines) + ("\n" if lines else "")

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("TK Control -> YAML")
        self.resizable(False, False)
        self.items = try_load_existing()

        midi_range = [ i for i in range(128) ]
        self.type_choices = ["control_change", "note_on", "pitchwheel"]
        self.cmd_choices = ["control_change", "start", "stop", "pitchwheel", "program_change"]
        self.note_choices = midi_range
        self.control_choices = midi_range
        self.target_choices = midi_range
        self.data_choices = midi_range

        frm = ttk.Frame(self, padding=10)
        frm.grid(row=0, column=0, sticky="nsew")

        # Build form
        self.vars = {}
        row = 0
        def add_row(label, name, values):
            nonlocal row
            ttk.Label(frm, text=label).grid(row=row, column=0, sticky="w", padx=(0,6))
            cb = ttk.Combobox(frm, values=values, width=30)
            cb.grid(row=row, column=1, sticky="w")
            cb.set(values[0] if values else "")
            self.vars[name] = cb
            row += 1

        add_row("type*:", "type", self.type_choices)
        add_row("cmd*:", "cmd", self.cmd_choices)
        add_row("note:", "note", self.note_choices)
        add_row("control:", "control", self.control_choices)
        add_row("target:", "target", self.target_choices)
        add_row("data:", "data", self.data_choices)

        # Buttons
        btn_frame = ttk.Frame(frm)
        btn_frame.grid(row=row, column=0, columnspan=2, pady=(8,0), sticky="w")
        self.add_btn = ttk.Button(btn_frame, text="Add Item", command=self.add_item)
        self.add_btn.grid(row=0, column=0, padx=(0,6))
        ttk.Button(btn_frame, text="Save Now", command=self.save_items).grid(row=0, column=1, padx=(0,6))
        ttk.Button(btn_frame, text="Clear List", command=self.clear_list).grid(row=0, column=2)

        # YAML display
        row += 1
        ttk.Label(frm, text="controls.yaml preview:").grid(row=row, column=0, columnspan=2, sticky="w", pady=(8,0))
        row += 1
        self.preview = scrolledtext.ScrolledText(frm, width=60, height=15)
        self.preview.grid(row=row, column=0, columnspan=2, pady=(4,0))
        self.preview.configure(state="disabled")

        # Trace combobox edits to validate required fields
        for name in ("type", "cmd"):
            widget = self.vars[name]
            widget.bind("<<ComboboxSelected>>", lambda e: self.validate())
            widget.bind("<KeyRelease>", lambda e: self.validate())

        self.validate()
        self.refresh_preview()

    def validate(self):
        t = self.vars["type"].get().strip()
        c = self.vars["cmd"].get().strip()
        if t and c:
            self.add_btn.state(["!disabled"])
        else:
            self.add_btn.state(["disabled"])

    def add_item(self):
        t = self.vars["type"].get().strip()
        c = self.vars["cmd"].get().strip()
        if not t or not c:
            messagebox.showwarning("Required", "Fields 'type' and 'cmd' are required.")
            return
        item = {"type": t, "cmd": c}
        for k in ("note", "control", "target", "data"):
            v = self.vars[k].get().strip()
            if v != "":
                item[k] = v
        self.items.append(item)
        self.save_items()
        # clear optional fields and keep type/cmd for convenience
        for k in ("note", "control", "target", "data"):
            self.vars[k].set("")
        self.refresh_preview()

    def save_items(self):
        txt = dump_yaml(self.items)
        try:
            with open(OUTFILE, "w", encoding="utf-8") as f:
                f.write(txt)
            self.refresh_preview()
        except Exception as e:
            messagebox.showerror("Save error", f"Could not write {OUTFILE}:\n{e}")

    def refresh_preview(self):
        txt = dump_yaml(self.items)
        self.preview.configure(state="normal")
        self.preview.delete("1.0", "end")
        self.preview.insert("1.0", txt)
        self.preview.configure(state="disabled")

    def clear_list(self):
        if not messagebox.askyesno("Clear", "Clear all items from list and delete controls.yaml?"):
            return
        self.items = []
        try:
            if os.path.exists(OUTFILE):
                os.remove(OUTFILE)
        except Exception:
            pass
        self.refresh_preview()

if __name__ == "__main__":
    app = App()
    app.mainloop()