#!/usr/bin/env python3
"""Replace hardcoded UI strings with .tr() using en/it translation value maps."""
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRANS_DIR = ROOT / "assets" / "translations"
TARGET_DIRS = [ROOT / "lib" / "presentation", ROOT / "lib" / "widgets"]

SKIP_SUBSTRINGS = (
    "package:", "assets/", "http://", "https://", "dart:", "Icons.",
    "FontWeight", "MainAxis", "CrossAxis", "BorderRadius", "EdgeInsets",
    "Color(", "Theme.of", "Navigator.", "supabase", "debugPrint",
    "print(", "Routes.", "/", "grappling", "fitness",
)
SKIP_EXACT = {
    "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
    "draft", "active", "paused", "completed", "none", "weekly", "monthly",
    "students", "instructors", "administrators", "sent", "scheduled",
    "principal_admin", "instructor_admin", "admin", "student",
}
IMPORT_LINE = "import '../../core/app_export.dart';"
IMPORT_LINE_ALT = "import '../../../core/app_export.dart';"
IMPORT_LINE_DEEP = "import '../../../../core/app_export.dart';"


def flatten(obj, prefix=""):
    out = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{prefix}.{k}" if prefix else k
            out.update(flatten(v, p))
    elif isinstance(obj, str):
        out[prefix] = obj
    return out


def load_maps():
    value_to_key = {}
    for lang in ("en", "it"):
        data = json.loads((TRANS_DIR / f"{lang}.json").read_text(encoding="utf-8"))
        flat = flatten(data)
        for key, val in flat.items():
            if val and val not in value_to_key:
                value_to_key[val] = key
            # normalized whitespace
            norm = " ".join(val.split())
            if norm and norm not in value_to_key:
                value_to_key[norm] = key
    return value_to_key


# Extra manual mappings (Italian/English -> key) for strings with placeholders handled in code
MANUAL = {
    "Festività aggiunta: {name}": "holidays.added_success",
    "Holiday added: {name}": "holidays.added_success",
    "Aggiunte {count} festività nazionali": "holidays.national_added",
    "Added {count} national holidays": "holidays.national_added",
    "Festività Programmate ({count})": "holidays.scheduled_count",
    "Scheduled Holidays ({count})": "holidays.scheduled_count",
    "Prossime Lezioni ({count})": "seasonal_schedule.upcoming_lessons",
    "Tutti i Template ({count})": "seasonal_schedule.all_templates",
    "lezione/i": "bulk_schedule.lesson_unit",
    "{count} lezioni pronte per l'attivazione": "bulk_schedule.lessons_ready",
    "{count} classes ready for activation": "bulk_schedule.lessons_ready",
    "Elimina": "common.delete",
    "Delete": "common.delete",
    "Note": "common.description",
    "Notes": "common.description",
    "Aggiorna": "seasonal_schedule.update",
    "Update": "seasonal_schedule.update",
    "HH:MM": "seasonal_schedule.time_hint",
    "20": "seasonal_schedule.capacity_hint",
    "es. Palestra Principale": "seasonal_schedule.location_hint",
    "e.g. Main Gym": "seasonal_schedule.location_hint",
    "es. Natale, Ferragosto": "holidays.name_hint",
    "e.g. Christmas, Ferragosto": "holidays.name_hint",
    "es. Palinsesto 2025/2026": "seasonal_schedule.season_title_hint",
    "es. Orari stagione 2025/2026": "seasonal_schedule.season_desc_hint",
    "Registrazione...": "registration.in_progress",
    "Registration...": "registration.in_progress",
    "Errore": "common.error",
    "Error": "common.error",
    "Oggi": "reminders.today",
    "Today": "reminders.today",
    "Prossimi 7 giorni": "reminders.next_7_days",
    "Next 7 days": "reminders.next_7_days",
    "SMS": "reminders.sms",
    "Salva Impostazioni": "reminders.save_settings",
    "Save Settings": "reminders.save_settings",
    "Totale Inviati": "reminders.total_sent",
    "Consegnati": "reminders.delivered",
    "Falliti": "reminders.failed",
    "Tasso Successo": "reminders.success_rate",
    "Seleziona almeno un utente": "reminders.select_user",
    "Cerca per nome o email...": "reminders.search_users_hint",
    "Cerca sponsor...": "admin_sponsor.search_hint",
    "Fotocamera": "common.camera",
    "Camera": "common.camera",
    "Titolo": "common.title",
    "Title": "common.title",
    "Bozza": "common.draft",
    "Draft": "common.draft",
    "Attivo": "common.active",
    "Active": "common.active",
    "In pausa": "common.paused",
    "Paused": "common.paused",
    "Completato": "common.completed",
    "Completed": "common.completed",
    "Lunedì": "seasonal_schedule.monday",
    "Martedì": "seasonal_schedule.tuesday",
    "Mercoledì": "seasonal_schedule.wednesday",
    "Giovedì": "seasonal_schedule.thursday",
    "Venerdì": "seasonal_schedule.friday",
    "Sabato": "seasonal_schedule.saturday",
    "Domenica": "seasonal_schedule.sunday",
    "Monday": "seasonal_schedule.monday",
    "Tuesday": "seasonal_schedule.tuesday",
    "Wednesday": "seasonal_schedule.wednesday",
    "Thursday": "seasonal_schedule.thursday",
    "Friday": "seasonal_schedule.friday",
    "Saturday": "seasonal_schedule.saturday",
    "Sunday": "seasonal_schedule.sunday",
    "Sala 1° piano": "seasonal_schedule.floor_1",
    "Sala 2° piano": "seasonal_schedule.floor_2",
    "1st floor": "seasonal_schedule.floor_1",
    "2nd floor": "seasonal_schedule.floor_2",
    "Capodanno": "holidays.new_year",
    "Epifania": "holidays.epiphany",
    "Festa della Liberazione": "holidays.liberation_day",
    "Festa del Lavoro": "holidays.labour_day",
    "Festa della Repubblica": "holidays.republic_day",
    "Ferragosto": "holidays.assumption",
    "Ognissanti": "holidays.all_saints",
    "Immacolata Concezione": "holidays.immaculate_conception",
    "Natale": "holidays.christmas",
    "Santo Stefano": "holidays.boxing_day",
    "Grappling": "disciplines.grappling",
    "Fitness": "disciplines.fitness",
    "-30 min": "bulk_schedule.shift_minus_30",
    "-15 min": "bulk_schedule.shift_minus_15",
    "+15 min": "bulk_schedule.shift_plus_15",
    "+30 min": "bulk_schedule.shift_plus_30",
}

STRING_RE = re.compile(
    r"""(const\s+)?Text\s*\(\s*'((?:\\'|[^'])*)'\s*"""
    r"""|(?:const\s+)?Text\s*\(\s*"((?:\\"|[^"])*)"\s*"""
    r"""|label(?:Text)?:\s*'((?:\\'|[^'])*)'"""
    r"""|hintText:\s*'((?:\\'|[^'])*)'"""
    r"""|title:\s*(?:const\s+)?Text\s*\(\s*'((?:\\'|[^'])*)'"""
    r"""|title:\s*'((?:\\'|[^'])*)'"""
    r"""|subtitle:\s*(?:const\s+)?Text\s*\(\s*'((?:\\'|[^'])*)'"""
    r"""|label:\s*(?:const\s+)?Text\s*\(\s*'((?:\\'|[^'])*)'"""
    r"""|child:\s*(?:const\s+)?Text\s*\(\s*'((?:\\'|[^'])*)'"""
    r"""|content:\s*(?:const\s+)?Text\s*\(\s*'((?:\\'|[^'])*)'"""
    r"""|_show\w+SnackBar\s*\(\s*'((?:\\'|[^'])*)'"""
    r"""|SnackBar\s*\(\s*content:\s*(?:const\s+)?Text\s*\(\s*'((?:\\'|[^'])*)'"""
)


def should_skip(s: str) -> bool:
    if len(s) < 3:
        return True
    if s in SKIP_EXACT:
        return True
    if s.replace(".", "").replace("_", "").isidentifier() and "_" in s and " " not in s:
        return True
    if any(x in s for x in SKIP_SUBSTRINGS):
        return True
    if re.match(r"^[a-z_]+$", s):
        return True
    if s.endswith(".tr()"):
        return True
    if ".tr(" in s:
        return True
    return False


def rel_import(path: Path) -> str:
    depth = len(path.relative_to(ROOT / "lib").parts) - 1
    prefix = "../" * depth
    return f"import '{prefix}core/app_export.dart';"


def process_file(path: Path, value_to_key: dict) -> int:
    text = path.read_text(encoding="utf-8")
    if "easy_localization" in text and "app_export" not in text:
        pass
    original = text
    changes = 0

    def replacer(m):
        nonlocal changes
        s = next(g for g in m.groups() if g is not None)
        s = s.replace("\\'", "'").replace('\\"', '"')
        if should_skip(s):
            return m.group(0)
        if m.group(0).find(".tr(") >= 0:
            return m.group(0)
        key = MANUAL.get(s) or value_to_key.get(s) or value_to_key.get(" ".join(s.split()))
        if not key:
            return m.group(0)
        changes += 1
        # preserve const Text if present
        is_const = m.group(0).startswith("const ")
        tr = f"'{key}'.tr()"
        if is_const and "const Text" in m.group(0):
            return m.group(0).replace(f"'{s}'", tr).replace("const Text", "Text")
        return m.group(0).replace(f"'{s}'", tr)

    # Simple quoted strings in common UI positions
    for pattern in [
        r"(const\s+Text\s*\(\s*)'((?:\\'|[^'])*)'(\s*[,)])",
        r"(Text\s*\(\s*)'((?:\\'|[^'])*)'(\s*[,)])",
        r"(labelText:\s*)'((?:\\'|[^'])*)'",
        r"(hintText:\s*)'((?:\\'|[^'])*)'",
        r"(title:\s*)'((?:\\'|[^'])*)'",
        r"(_show\w+SnackBar\s*\(\s*)'((?:\\'|[^'])*)'",
        r"(SnackBar\s*\(\s*content:\s*Text\s*\(\s*)'((?:\\'|[^'])*)'",
        r"(child:\s*Text\s*\(\s*)'((?:\\'|[^'])*)'",
        r"(label:\s*Text\s*\(\s*)'((?:\\'|[^'])*)'",
    ]:
        def sub_fn(m):
            nonlocal changes
            prefix, s, suffix = m.group(1), m.group(2), m.group(3) if m.lastindex >= 3 else ""
            s_unesc = s.replace("\\'", "'")
            if should_skip(s_unesc):
                return m.group(0)
            # skip if already tr
            after = text[m.end() : m.end() + 20] if False else ""
            key = MANUAL.get(s_unesc) or value_to_key.get(s_unesc)
            if not key:
                return m.group(0)
            changes += 1
            new = f"{prefix}'{key}'.tr(){suffix}"
            if "const Text" in prefix:
                new = new.replace("const Text", "Text")
            return new

        text = re.sub(pattern, sub_fn, text)

    # Multi-line Text( '...' ) 
    def replace_multiline_text(content):
        nonlocal changes
        pat = re.compile(
            r"Text\s*\(\s*\n\s*'((?:[^'\\]|\\.)+)'\s*,",
            re.MULTILINE,
        )
        def inner(m):
            nonlocal changes
            s = m.group(1).replace("\\'", "'")
            if should_skip(s):
                return m.group(0)
            key = MANUAL.get(s) or value_to_key.get(s) or value_to_key.get(" ".join(s.split()))
            if not key:
                return m.group(0)
            changes += 1
            return f"Text(\n              '{key}'.tr(),"
        return pat.sub(inner, content)

    text = replace_multiline_text(text)

    if changes and ".tr()" in text and "app_export.dart" not in text:
        imp = rel_import(path)
        # insert after first import block
        lines = text.split("\n")
        insert_at = 0
        for i, line in enumerate(lines):
            if line.startswith("import "):
                insert_at = i + 1
            elif insert_at > 0 and not line.startswith("import ") and line.strip():
                break
        if not any("app_export.dart" in l for l in lines):
            lines.insert(insert_at, imp)
            text = "\n".join(lines)

    if text != original:
        path.write_text(text, encoding="utf-8")
    return changes


def main():
    value_to_key = load_maps()
    value_to_key.update(MANUAL)
    total_files = 0
    total_changes = 0
    for base in TARGET_DIRS:
        for path in base.rglob("*.dart"):
            n = process_file(path, value_to_key)
            if n:
                total_files += 1
                total_changes += n
                print(f"{path.relative_to(ROOT)}: {n}")
    print(f"Done: {total_files} files, {total_changes} replacements")


if __name__ == "__main__":
    main()
