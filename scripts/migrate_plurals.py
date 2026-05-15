#!/usr/bin/env python3
"""Migrate flat (1 X / %d Xs) catalog pairs to xcstrings plural variations.

Background (S35): four flat-key pairs in `Resources/Localizable.xcstrings`
encode plural forms by hand (1 minute / %d minutes, 1 hour / %d hours,
Currently: 1 external display / Currently: %lld external displays). Languages
like Russian and Polish have 3+ plural forms (one/few/many/other) that the
two-flat-keys pattern can't capture cleanly, and Apple's xcstrings format
supports a `variations.plural.{one,few,many,other}` map natively. This script
consolidates the pairs into single keys with `variations.plural`.

Plural-form strategy per language:
- en/de/es/fr/it/pt-BR: one + other (CLDR rule)
- ko/ja/zh-Hans/zh-Hant: other only (no grammatical plural)
- ru: one + other for now (catalog only holds two forms today; community PR
  can refine to one/few/many/other later — see TRANSLATIONS.md)

Source key '%d X' → target key '%lld X' (Swift Int interpolation uses %lld).
External-display pair already uses '%lld' so no rename needed.

Usage:
    python3 scripts/migrate_plurals.py            # dry-run (prints diff)
    python3 scripts/migrate_plurals.py --apply    # writes back
"""

from __future__ import annotations

import json
import sys
from copy import deepcopy
from pathlib import Path

CATALOG = Path("Resources/Localizable.xcstrings")

# (one_key, other_key, target_key)
# one_key / other_key are deleted after migration; target_key is created
# (or reused if already present) with variations.plural.
MIGRATIONS = [
    ("1 minute", "%d minutes", "%lld minutes"),
    ("1 hour", "%d hours", "%lld hours"),
    ("Currently: 1 external display", "Currently: %lld external displays",
     "Currently: %lld external displays"),
]

# Languages that distinguish one vs other (en + most European). Catalog
# languages NOT in this set get only `other` (ko/ja/zh-Hans/zh-Hant).
# ru is here because the catalog already supplies a singular-shaped value
# in the "1 minute" pair; native-speaker community PR will refine.
LANGS_ONE_OTHER = {"en", "de", "es", "fr", "it", "pt-BR", "ru"}


def percent_d_to_lld(s: str) -> str:
    """Rewrite '%d' → '%lld' in the value. Most translations already use
    '%d'; the target key uses '%lld' so the value placeholder must match.
    External-display values already use '%lld' so this is a no-op for them."""
    return s.replace("%d", "%lld")


def build_plural_entry(
    one_loc: dict, other_loc: dict, lang: str
) -> dict:
    """Build a localizations[lang] dict with variations.plural."""
    one_value = one_loc["stringUnit"]["value"]
    other_value = percent_d_to_lld(other_loc["stringUnit"]["value"])

    plural_map = {
        "other": {"stringUnit": {"state": "translated", "value": other_value}}
    }
    if lang in LANGS_ONE_OTHER:
        # The one form is the catalog's flat "1 X" value; keep the literal
        # numeral so the singular renders as "1 minute" rather than
        # "%lld minute". CLDR `one` matches n=1 in en/de/es/fr/it/pt-BR/ru.
        plural_map["one"] = {
            "stringUnit": {"state": "translated", "value": one_value}
        }

    return {"variations": {"plural": plural_map}}


def migrate(strings: dict, one_key: str, other_key: str, target_key: str) -> dict:
    """Returns a new strings dict with the migration applied."""
    if one_key not in strings:
        raise ValueError(f"missing source key: {one_key}")
    if other_key not in strings:
        raise ValueError(f"missing source key: {other_key}")

    one_entry = strings[one_key]
    other_entry = strings[other_key]
    one_locs = one_entry.get("localizations", {})
    other_locs = other_entry.get("localizations", {})

    # Verify both have the same language set.
    langs = sorted(set(one_locs.keys()) | set(other_locs.keys()))

    new_entry = {
        "extractionState": "manual",
        "localizations": {},
    }
    for lang in langs:
        if lang not in one_locs:
            raise ValueError(f"{one_key!r}: missing lang {lang}")
        if lang not in other_locs:
            raise ValueError(f"{other_key!r}: missing lang {lang}")
        new_entry["localizations"][lang] = build_plural_entry(
            one_locs[lang], other_locs[lang], lang
        )

    # Build new strings dict in insertion order: target_key first if it's
    # new, otherwise replace at its existing position.
    new_strings = {}
    placed = False
    for k, v in strings.items():
        if k == one_key or k == other_key:
            # If target == other_key we replace it in place; otherwise drop.
            if k == target_key and not placed:
                new_strings[target_key] = new_entry
                placed = True
            continue
        new_strings[k] = v
    if not placed:
        # target_key was different from both source keys → append at end.
        new_strings[target_key] = new_entry

    return new_strings


def main() -> int:
    apply = "--apply" in sys.argv

    d = json.loads(CATALOG.read_text())
    strings = d["strings"]
    before_count = len(strings)

    for one_key, other_key, target_key in MIGRATIONS:
        strings = migrate(strings, one_key, other_key, target_key)

    after_count = len(strings)
    d["strings"] = strings

    print(f"Keys: {before_count} → {after_count} "
          f"(net {after_count - before_count:+d})")
    for one_key, other_key, target_key in MIGRATIONS:
        print(f"  - {one_key!r} + {other_key!r} → {target_key!r} (plural)")

    if not apply:
        print("\nDry-run only. Re-run with --apply to write back.")
        return 0

    CATALOG.write_text(
        json.dumps(d, ensure_ascii=False, indent=2, sort_keys=False) + "\n"
    )
    print(f"\nWrote {CATALOG}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
