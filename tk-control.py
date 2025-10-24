#!/usr/bin/env python3

# Tkinter app to build a YAML list of MIDI controls.

import os
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import yaml

OUTFILE = os.path.join(os.path.dirname(__file__), "controls.yaml")

def load_existing():
    try:
        with open(OUTFILE, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
            msgs = data.get('messages', [])
            return data, msgs
    except Exception as e:
        print(f"WARNING: {e}")
        return {}, []

def dump_yaml(data):
    return yaml.safe_dump(
        data,
        default_flow_style=False, sort_keys=False, allow_unicode=True)

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Configure MIDI Control Devices")
        self.resizable(False, False)

        self.data, self.items = load_existing()
        self.controller = self.data.get('controller', 'controller')
        self.device = self.data.get('device', 'device')

        midi_range = [ i for i in range(128) ]
        self.type_choices = ["control_change", "note_on", "note_off", "pitchwheel"]
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
            cb = ttk.Combobox(frm, values=values, width=20)
            cb.grid(row=row, column=1, sticky="w")
            cb.set(values[0] if values else "")
            self.vars[name] = cb
            row += 1

        def add_entry(label, name, text=''):
            nonlocal row
            ttk.Label(frm, text=label).grid(row=row, column=0, sticky="w", padx=(0,6))
            ent = ttk.Entry(frm, width=10)
            ent.grid(row=row, column=1, sticky="w")
            ent.insert(0, text)
            self.vars[name] = ent
            row += 1

        add_entry("controller*:", 'controller', text=self.controller)
        add_entry("device*:", 'device', text=self.device)
        add_row("type*:", "type", self.type_choices)
        add_row("cmd*:", "cmd", self.cmd_choices)
        add_row("note:", "note", self.note_choices)
        add_row("control:", "control", self.control_choices)
        add_row("target:", "target", self.target_choices)
        add_row("data:", "data", self.data_choices)

        # blank optional message bits
        for k in ("note", "control", "target", "data"):
            self.set_var(k, "")

        # Buttons
        btn_frame = ttk.Frame(frm)
        btn_frame.grid(row=row, column=0, columnspan=2, pady=(8,0), sticky="w")
        self.add_btn = ttk.Button(btn_frame, text="Add Item", command=self.add_item)
        self.add_btn.grid(row=0, column=0, padx=(0,6))
        ttk.Button(btn_frame, text="Save Now", command=self.save_items).grid(row=0, column=1, padx=(0,6))
        ttk.Button(btn_frame, text="Clear List", command=self.clear_list).grid(row=0, column=2)

        # YAML display
        row += 1
        ttk.Label(frm, text="Configuration:").grid(row=row, column=0, columnspan=2, sticky="w", pady=(8,0))
        row += 1
        self.preview = scrolledtext.ScrolledText(frm, width=60, height=15)
        self.preview.grid(row=row, column=0, columnspan=2, pady=(4,0))
        self.preview.configure(state="disabled")

        # validate required fields
        for name in ("type", "cmd", "controller", "device"):
            widget = self.vars[name]
            try:
                widget.bind("<<ComboboxSelected>>", lambda e: self.validate())
            except Exception:
                pass
            widget.bind("<KeyRelease>", lambda e: self.validate())

        self.validate()
        self.refresh_preview()

    def set_var(self, name, value):
        w = self.vars.get(name)
        if w is None:
            return
        if hasattr(w, "set"):
            w.set(value)
        else:
            # Entry widget
            w.delete(0, "end")
            w.insert(0, value)

    def get_var(self, name):
        w = self.vars.get(name)
        if w is None:
            return ""
        try:
            return w.get().strip()
        except Exception:
            return ""

    def validate(self):
        t = self.get_var("type")
        c = self.get_var("cmd")
        cn = self.get_var("controller")
        dn = self.get_var("device")
        if t and c and cn and dn:
            self.add_btn.state(["!disabled"])
        else:
            self.add_btn.state(["disabled"])

    def add_item(self):
        t = self.get_var("type")
        c = self.get_var("cmd")
        cn = self.get_var("controller")
        dn = self.get_var("device")
        if not t or not c or not cn or not dn:
            messagebox.showwarning("Required", "Required fields missing.")
            return

        item = {"type": t, "cmd": c}
        # include the existing controls if provided
        for k in ("note", "control", "target", "data"):
            v = self.get_var(k)
            if v != "":
                item[k] = v
        self.items.append(item)
        self.data['controller'] = self.get_var('controller')
        self.data['device'] = self.get_var('device')
        self.data['messages'] = self.items
        self.save_items()
        # clear optional numeric fields and keep type/cmd and controller/device
        for k in ("note", "control", "target", "data"):
            self.set_var(k, "")
        self.refresh_preview()

    def save_items(self):
        txt = dump_yaml(self.data)
        try:
            with open(OUTFILE, "w", encoding="utf-8") as f:
                f.write(txt)
            self.refresh_preview()
        except Exception as e:
            messagebox.showerror("Save error", f"Could not write {OUTFILE}:\n{e}")

    def refresh_preview(self):
        txt = dump_yaml(self.data)
        self.preview.configure(state="normal")
        self.preview.delete("1.0", "end")
        self.preview.insert("1.0", txt)
        self.preview.configure(state="disabled")

    def clear_list(self):
        if not messagebox.askyesno("Clear", "Clear all data and delete controls.yaml?"):
            return
        self.data = {}
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
