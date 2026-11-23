#!/usr/bin/env python3
"""Builds docs/DATA_DICTIONARY.md and docs/ERD.md from the catalog dump of the installed database.
   psql -d diamate -f tools/dump_catalog.sql -o docs/_catalog.json   (produces the JSON)
   python3 tools/make_docs.py docs/_catalog.json docs
"""
import json, os, re, sys

src, out = sys.argv[1], sys.argv[2]
cat = json.load(open(src))
tables = cat["tables"]
by_name = {(t["schema"], t["name"]): t for t in tables}


def esc(s):
    return (s or "").replace("|", "\\|").replace("\n", " ")


def short_type(c):
    t = c["type"]
    t = t.replace("timestamp with time zone", "timestamptz").replace("timestamp without time zone", "timestamp")
    t = t.replace("character varying", "varchar").replace("double precision", "float8")
    if c["identity"] in ("a", "d"):
        t += " (identity)"
    return t


def pretty_check(s):
    """(((col)::text = ANY ((ARRAY['A'::character varying, ...])::text[]))) -> col IN ('A', 'B')"""
    m = re.search(r"\(\(\((\w+)\)::text = ANY \(\(ARRAY\[(.*?)\]\)::text\[\]\)\)\)", s)
    if m:
        return f"({m.group(1)} IN (" + ", ".join(f"'{v}'" for v in re.findall(r"'([^']*)'", m.group(2))) + "))"
    return re.sub(r"::(character varying|text|integer|numeric|bigint|smallint)", "", s)


def constraint_notes(t):
    pk, fks, checks, uniq = [], [], [], []
    for k in t["constraints"] or []:
        if k["type"] == "p":
            pk.append(re.sub(r"^PRIMARY KEY ", "", k["def"]))
        elif k["type"] == "f":
            fks.append(re.sub(r"^FOREIGN KEY ", "", k["def"]))
        elif k["type"] == "c":
            checks.append(pretty_check(re.sub(r"^CHECK ", "", k["def"])))
        elif k["type"] == "u":
            uniq.append(re.sub(r"^UNIQUE ", "", k["def"]))
    return pk, fks, checks, uniq


# ------------------------------------------------------------------------------------------------ data dictionary
md = ["# DiaMate data dictionary", "",
      f"Generated from the installed database (PostgreSQL {cat['server_version']}) on {cat['generated_at'][:10]}. Do not edit by hand: run `tools/make_docs.py`.", "",
      "Schema **public** = application (what the backend uses). Schema **research** = merged open datasets (read-only reference / training data).", "",
      "## Contents", ""]
for schema in ("public", "research"):
    for kind, label in (("r", "tables"), ("v", "views")):
        ts = [t for t in tables if t["schema"] == schema and t["kind"] == kind]
        if ts:
            md.append(f"- **{schema} {label}:** " + ", ".join(f"[{t['name']}](#{schema}{t['name']})" for t in ts))
md.append("")
for schema in ("public", "research"):
    md += [f"## Schema `{schema}`", ""]
    for t in [t for t in tables if t["schema"] == schema]:
        kind = "view" if t["kind"] == "v" else "table"
        md += [f'<a id="{schema}{t["name"]}"></a>', f"### {schema}.{t['name']} ({kind})", ""]
        if t["comment"]:
            md += [t["comment"], ""]
        md += ["| Column | Type | Null | Default | Description |", "|---|---|---|---|---|"]
        for c in t["columns"]:
            default = "" if c["identity"] in ("a", "d") else esc(c["default"])
            md.append(f"| `{c['name']}` | {esc(short_type(c))} | {'NO' if c['notnull'] else 'yes'} | {default} | {esc(c['comment'])} |")
        md.append("")
        if t["kind"] == "r":
            pk, fks, checks, uniq = constraint_notes(t)
            if pk:
                md.append("- **Primary key:** " + ", ".join(f"`{x}`" for x in pk))
            for f in fks:
                md.append(f"- **Foreign key:** `{f}`")
            for u in uniq:
                md.append(f"- **Unique:** `{u}`")
            for k in checks:
                md.append(f"- **Check:** `{k}`")
            for i in t["indexes"] or []:
                if "_pkey" not in i:
                    md.append(f"- **Index:** `{re.sub(r'^CREATE ', '', i)}`")
            md.append("")
md += ["## Functions", "", "| Function | Arguments | Returns | Description |", "|---|---|---|---|"]
for f in cat["functions"] or []:
    md.append(f"| `{f['name']}` | `{esc(f['args'])}` | `{esc(f['returns'])}` | {esc(f['comment'])} |")
open(os.path.join(out, "DATA_DICTIONARY.md"), "w").write("\n".join(md) + "\n")

# ------------------------------------------------------------------------------------------------------------- ERD
def erd(schema, names=None):
    ts = [t for t in tables if t["schema"] == schema and t["kind"] == "r" and (names is None or t["name"] in names)]
    lines, rels = ["erDiagram"], []
    for t in ts:
        pk_cols = set()
        fk_cols = set()
        for k in t["constraints"] or []:
            m = re.search(r"\(([^)]*)\)", k["def"])
            cols = [x.strip() for x in m.group(1).split(",")] if m else []
            if k["type"] == "p":
                pk_cols.update(cols)
            if k["type"] == "f":
                fk_cols.update(cols)
                ref = re.search(r"REFERENCES ([\w\.]+)\(", k["def"])
                if ref:
                    target = ref.group(1).split(".")[-1]
                    if names is None or target in names:
                        rels.append((target, t["name"], cols[0]))
        lines.append(f"    {t['name']} {{")
        for c in t["columns"]:
            tp = re.sub(r"[^A-Za-z0-9_]", "", short_type(c).split("(")[0].strip().replace(" ", "_")) or "text"
            key = "PK" if c["name"] in pk_cols else ("FK" if c["name"] in fk_cols else "")
            lines.append(f"        {tp} {c['name']} {key}".rstrip())
        lines.append("    }")
    seen = set()
    for parent, child, col in rels:
        if (parent, child, col) in seen or parent == child:
            continue
        seen.add((parent, child, col))
        lines.append(f'    {parent} ||--o{{ {child} : "{col}"')
    return "\n".join(lines)


groups = {
    "Accounts, roles and sharing": ["users", "patient_profiles", "clinician_profiles", "care_relationships", "treatment_plans", "user_settings",
                                    "refresh_tokens", "password_reset_tokens", "device_tokens"],
    "Daily logs": ["patient_profiles", "glucose_logs", "meal_logs", "meal_log_items", "food_catalog", "insulin_logs", "activity_logs",
                   "wearable_samples", "symptom_logs", "lab_results"],
    "Medication, reminders, alerts": ["patient_profiles", "medications", "medication_intakes", "reminders", "reminder_events", "alerts",
                                      "notifications", "recommendations", "clinician_profiles", "users"],
    "Reports, imports, AI assistant, audit": ["patient_profiles", "reports", "csv_imports", "ai_conversations", "ai_messages", "audit_logs", "users"],
}
md = ["# DiaMate entity-relationship diagrams", "",
      "Mermaid diagrams (GitHub, VS Code, Obsidian and many other tools render them). Generated from the foreign keys of the installed database.", ""]
for title, names in groups.items():
    md += [f"## {title}", "", "```mermaid", erd("public", set(names)), "```", ""]
md += ["## Research schema (open datasets)", "", "```mermaid", erd("research"), "```", ""]
open(os.path.join(out, "ERD.md"), "w").write("\n".join(md) + "\n")
print("written", os.path.join(out, "DATA_DICTIONARY.md"), os.path.join(out, "ERD.md"))
