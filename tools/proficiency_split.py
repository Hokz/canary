"""Split data/items/proficiencies.json into one file per weapon category.

The single 420-entry file is hard to balance because nothing in it says which
weapon an entry belongs to. That link lives outside the file: each item in the
binary appearances catalog carries a proficiency_id flag pointing back at
ProficiencyId, and items.xml holds the attributes that say what kind of weapon
the item is.

This script rebuilds the per-category files from those three sources so the
split is reproducible rather than hand-maintained.

    python -m tools.proficiency_split split     # regenerate data/items/proficiencies/
    python -m tools.proficiency_split validate  # check the generated files

Requires: protobuf (pip install protobuf grpcio-tools) and a compiled
appearances_pb2 module; see build_appearances_pb2() below.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[1]
ITEMS_XML = REPO_ROOT / "data" / "items" / "items.xml"
APPEARANCES_DAT = REPO_ROOT / "data" / "items" / "appearances.dat"
LEGACY_JSON = REPO_ROOT / "data" / "items" / "proficiencies.json"
OUT_DIR = REPO_ROOT / "data" / "items" / "proficiencies"
PROTO_FILE = REPO_ROOT / "src" / "protobuf" / "appearances.proto"

SCHEMA_NAME = "proficiencies.schema.json"
SHAPING_JSON = OUT_DIR / "shaping" / "shaping.json"

# WeaponProficiencyBonus_t - src/enums/weapon_proficiency.hpp
BONUS_TYPES = {
    0: "ATTACK_DAMAGE",
    1: "DEFENSE_BONUS",
    2: "WEAPON_SHIELD_MODIFIER",
    3: "SKILL_BONUS",
    4: "SPECIALIZED_MAGIC_LEVEL",
    5: "SPELL_AUGMENT",
    6: "WEAPON_PROFICIENCY_BESTIARY",
    7: "POWERFUL_FOE_BONUS",
    8: "CRITICAL_HIT_CHANCE",
    9: "ELEMENTAL_HIT_CHANCE",
    10: "RUNE_CRITICAL_HIT_CHANCE",
    11: "AUTO_ATTACK_CRITICAL_HIT_CHANCE",
    12: "CRITICAL_EXTRA_DAMAGE",
    13: "ELEMENTAL_CRITICAL_EXTRA_DAMAGE",
    14: "RUNE_CRITICAL_EXTRA_DAMAGE",
    15: "AUTO_ATTACK_CRITICAL_EXTRA_DAMAGE",
    16: "MANA_LEECH",
    17: "LIFE_LEECH",
    18: "MANA_GAIN_ON_HIT",
    19: "LIFE_GAIN_ON_HIT",
    20: "MANA_GAIN_ON_KILL",
    21: "LIFE_GAIN_ON_KILL",
    22: "PERFECT_SHOT_DAMAGE",
    23: "RANGED_HIT_CHANCE",
    24: "ATTACK_RANGE",
    25: "SKILL_PERCENTAGE_AUTO_ATTACK",
    26: "SKILL_PERCENTAGE_SPELL_DAMAGE",
    27: "SKILL_PERCENTAGE_SPELL_HEALING",
    28: "ALPHA_STRIKE_EXTRA_DAMAGE",
    29: "OMEGA_STRIKE_EXTRA_DAMAGE",
    30: "ARMOR_PENETRATION",
    31: "ELEMENTAL_PIERCE",
}

# Value is an absolute amount for these (skill points, mana/life restored,
# perfect-shot damage, tiles of range); every other type is a fraction where
# 0.10 means 10%. Confirmed against how the engine consumes each value, e.g.
# applyOn() feeds LIFE/MANA_GAIN_ON_* straight into damage.primary.value.
FLAT_TYPES = {0, 1, 2, 3, 4, 18, 19, 20, 21, 22, 24}

# SPELL_AUGMENT carries a different unit per AugmentType: COOLDOWN is a raw
# millisecond reduction (always negative), everything else is a fraction.
AUGMENT_TYPES = {
    2: "DAMAGE",
    3: "HEAL",
    6: "COOLDOWN",
    14: "LIFE_LEECH",
    15: "MANA_LEECH",
    16: "CRITICAL_DAMAGE",
    17: "CRITICAL_CHANCE",
}
SPELL_AUGMENT = 5
AUGMENT_COOLDOWN = 6

# Highest Value each type currently uses. Going above it is legal but is almost
# always a misplaced decimal (typing 10 for 10% instead of 0.10), so validate()
# reports it as a warning. Raise a ceiling deliberately when balance calls for it.
VALUE_CEILINGS = {
    0: 15, 1: 5, 2: 4, 3: 4, 4: 3, 6: 0.25, 7: 0.06, 8: 0.05, 9: 0.03, 10: 0.02,
    11: 0.5, 12: 0.48, 13: 1.0, 14: 0.12, 15: 2.0, 16: 0.05, 17: 0.145, 18: 32,
    19: 16, 20: 30, 21: 40, 22: 25, 23: 1.0, 24: 1, 25: 2.0, 26: 2.0, 27: 10.0,
    28: 0.1, 29: 0.04, 30: 1.0, 31: 0.4,
}

# CipbiaSkills_t - src/utils/utils_definitions.hpp. NOT the server's skills_t:
# SkillId 8 is Sword here, but SKILL_CRITICAL_HIT_DAMAGE in skills_t. The loader
# converts via getSkillsFromCipbiaSkill(); an id outside this map makes the
# server log an error and silently drop the perk.
CIPBIA_SKILLS = {
    1: "MagicLevel",
    6: "Shield",
    7: "Distance",
    8: "Sword",
    9: "Club",
    10: "Axe",
    11: "Fist",
    13: "Fishing",
}

CATEGORIES = ["Sword", "Axe", "Club", "Bow", "Crossbow", "Wand", "Rod", "Fist", "Throwing"]

PRIMARYTYPE_TO_CATEGORY = {
    "sword weapons": "Sword",
    "axe weapons": "Axe",
    "club weapons": "Club",
    "fist weapons": "Fist",
    "wands": "Wand",
    "rods": "Rod",
}

WEAPONTYPE_TO_CATEGORY = {
    "sword": "Sword",
    "axe": "Axe",
    "club": "Club",
    "fist": "Fist",
}

# Names in proficiencies.json follow "<flavor> <1H|2H> <Category>" (in any order),
# which is the only category signal for items that predate the primarytype
# attribute or that items.xml does not define at all.
NAME_CATEGORY_TOKENS = ["Crossbow", "Bow", "Sword", "Axe", "Club", "Wand", "Rod", "Fist"]


def build_appearances_pb2(workdir: Path):
    """Compile appearances.proto on the fly and import the generated module."""
    subprocess.run(
        [
            sys.executable,
            "-m",
            "grpc_tools.protoc",
            f"-I{PROTO_FILE.parent}",
            f"--python_out={workdir}",
            str(PROTO_FILE),
        ],
        check=True,
        capture_output=True,
    )
    sys.path.insert(0, str(workdir))
    import appearances_pb2  # noqa: PLC0415

    return appearances_pb2


def load_item_attributes() -> dict[int, dict[str, str]]:
    root = ET.parse(ITEMS_XML).getroot()
    attributes: dict[int, dict[str, str]] = {}
    for item in root.findall("item"):
        if item.get("id"):
            ids: Iterable[int] = [int(item.get("id"))]
        elif item.get("fromid") and item.get("toid"):
            ids = range(int(item.get("fromid")), int(item.get("toid")) + 1)
        else:
            continue
        parsed = {a.get("key"): a.get("value") for a in item.findall("attribute") if a.get("key")}
        for item_id in ids:
            attributes[item_id] = parsed
    return attributes


def load_proficiency_items(pb2) -> dict[int, list[tuple[int, str]]]:
    appearances = pb2.Appearances()
    appearances.ParseFromString(APPEARANCES_DAT.read_bytes())
    linked: dict[int, list[tuple[int, str]]] = defaultdict(list)
    for obj in appearances.object:
        if obj.flags.HasField("proficiency"):
            name = obj.name.decode() if obj.HasField("name") else ""
            linked[obj.flags.proficiency.proficiency_id].append((obj.id, name))
    return linked


def category_from_name(name: str) -> str | None:
    for token in NAME_CATEGORY_TOKENS:
        if re.search(rf"\b{token}\b", name, re.IGNORECASE):
            return token
    if re.search(r"\bthrow\b", name, re.IGNORECASE):
        return "Throwing"
    return None


def category_from_item(item_id: int, attributes: dict[int, dict[str, str]], fallback: str | None) -> str | None:
    attrs = attributes.get(item_id, {})
    primary = attrs.get("primarytype")
    weapon = attrs.get("weaponType")
    ammo = attrs.get("ammotype")

    if primary in PRIMARYTYPE_TO_CATEGORY:
        return PRIMARYTYPE_TO_CATEGORY[primary]

    if primary == "distance weapons" or weapon == "distance":
        if ammo == "bolt":
            return "Crossbow"
        if ammo == "arrow":
            return "Bow"
        # Distance weapon that needs no separate ammunition: thrown by hand.
        return "Throwing"

    if weapon in WEAPONTYPE_TO_CATEGORY:
        return WEAPONTYPE_TO_CATEGORY[weapon]

    if weapon == "wand":
        # The engine has no WEAPON_ROD; rods are weaponType="wand" too. Only
        # primarytype separates them, and older items do not carry it.
        return fallback if fallback in ("Wand", "Rod") else "Wand"

    return None


def classify(entry: dict, linked_items: list[tuple[int, str]], attributes: dict[int, dict[str, str]]) -> tuple[set[str], str | None]:
    name_category = category_from_name(entry["Name"])
    categories = set()
    for item_id, _ in linked_items:
        resolved = category_from_item(item_id, attributes, name_category)
        if resolved:
            categories.add(resolved)
    if not categories and name_category:
        categories = {name_category}
    return categories, name_category


def unit_for(perk: dict) -> str:
    bonus_type = perk["Type"]
    if bonus_type == SPELL_AUGMENT:
        return "milliseconds" if perk.get("AugmentType") == AUGMENT_COOLDOWN else "percent"
    return "flat" if bonus_type in FLAT_TYPES else "percent"


def convert_perk(perk: dict) -> dict:
    bonus_type = perk["Type"]
    converted = {"Type": bonus_type, "TypeName": BONUS_TYPES.get(bonus_type, "UNKNOWN")}
    if "SkillId" in perk:
        converted["SkillId"] = perk["SkillId"]
        converted["SkillName"] = CIPBIA_SKILLS.get(perk["SkillId"], "INVALID")
    if "AugmentType" in perk:
        converted["AugmentType"] = perk["AugmentType"]
        converted["AugmentName"] = AUGMENT_TYPES.get(perk["AugmentType"], "UNKNOWN")
    for key in ("SpellId", "Range", "DamageType", "ElementId", "BestiaryId", "BestiaryName"):
        if key in perk:
            converted[key] = perk[key]
    converted["Value"] = perk["Value"]
    converted["Unit"] = unit_for(perk)
    return converted


def convert_entry(entry: dict, weapons: list[str], corrected_name: str | None) -> dict:
    converted = {
        "ProficiencyId": entry["ProficiencyId"],
        "Name": corrected_name or entry["Name"],
        "Weapon": weapons,
        "Version": entry.get("Version"),
        "Levels": [
            {"Level": index, "Perks": [convert_perk(perk) for perk in level["Perks"]]}
            for index, level in enumerate(entry["Levels"], start=1)
        ],
    }
    return converted


def rename_for_category(name: str, category: str) -> str:
    """Rewrite the category token in a Name that contradicts the real item."""
    for token in NAME_CATEGORY_TOKENS:
        if re.search(rf"\b{token}\b", name, re.IGNORECASE):
            return re.sub(rf"\b{token}\b", category, name, count=1, flags=re.IGNORECASE)
    return name


def split(pb2) -> int:
    if not LEGACY_JSON.exists():
        print(
            f"{LEGACY_JSON.relative_to(REPO_ROOT)} is gone, so the one-time migration cannot run again.\n"
            "The per-category files under data/items/proficiencies/ are the source of truth now;\n"
            "edit them directly and run `python -m tools.proficiency_split validate`.",
            file=sys.stderr,
        )
        return 1

    attributes = load_item_attributes()
    linked = load_proficiency_items(pb2)
    entries = json.loads(LEGACY_JSON.read_text(encoding="utf-8"))

    buckets: dict[str, list[dict]] = {category: [] for category in CATEGORIES}
    orphaned: list[dict] = []
    renamed: list[tuple[int, str, str]] = []

    for entry in entries:
        proficiency_id = entry["ProficiencyId"]
        items = linked.get(proficiency_id, [])
        if not items:
            orphaned.append(convert_entry(entry, [], None))
            continue

        categories, name_category = classify(entry, items, attributes)
        weapons = sorted({name for _, name in items if name})

        corrected = None
        if len(categories) == 1:
            only = next(iter(categories))
            if name_category and name_category != only:
                corrected = rename_for_category(entry["Name"], only)
                renamed.append((proficiency_id, entry["Name"], corrected))

        converted = convert_entry(entry, weapons, corrected)
        for category in sorted(categories):
            # Shared ids are written in full into every category they belong to:
            # each file must stand alone. validate() enforces that the copies
            # stay identical, because the loader lets the last file read win.
            buckets[category].append(json.loads(json.dumps(converted)))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for category, bucket in buckets.items():
        bucket.sort(key=lambda item: item["ProficiencyId"])
        payload = {
            "$schema": f"./{SCHEMA_NAME}",
            "Category": category,
            "Proficiencies": bucket,
        }
        path = OUT_DIR / f"{category.lower()}.json"
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"  {path.relative_to(REPO_ROOT)}: {len(bucket)} proficiencies")

    orphaned.sort(key=lambda item: item["ProficiencyId"])
    orphan_path = OUT_DIR / "_orphaned.json"
    orphan_path.write_text(
        json.dumps(
            {
                "$schema": f"./{SCHEMA_NAME}",
                "Category": "Orphaned",
                "Comment": "No item in appearances.dat references these ProficiencyIds. Kept for reference; not loaded as a weapon category.",
                "Proficiencies": orphaned,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"  {orphan_path.relative_to(REPO_ROOT)}: {len(orphaned)} proficiencies (unused)")

    if renamed:
        print("\nNames corrected against the real item:")
        for proficiency_id, before, after in renamed:
            print(f"  {proficiency_id}: {before!r} -> {after!r}")

    written = sum(len(bucket) for bucket in buckets.values()) + len(orphaned)
    print(f"\nsource entries: {len(entries)}   written entries: {written}")
    return 0


def _iter_generated() -> Iterable[tuple[Path, dict]]:
    for path in sorted(OUT_DIR.glob("*.json")):
        if path.name == SCHEMA_NAME:
            continue
        yield path, json.loads(path.read_text(encoding="utf-8"))


def validate_shaping(errors: list[str], warnings: list[str]) -> int:
    """Check the perk shaping rules the same way the proficiency files are checked.

    The engine rejects what would crash or silently do nothing; this catches what
    would merely be wrong - a mislabelled Type, a Unit that contradicts the Value,
    a rank table that gets worse as it goes up, a refine curve too short to reach
    an option's maximum rank. Returns how many options were checked.
    """
    if not SHAPING_JSON.exists():
        return 0

    rel = SHAPING_JSON.relative_to(REPO_ROOT)
    payload = json.loads(SHAPING_JSON.read_text(encoding="utf-8"))

    for position, slot in enumerate(payload.get("Slots", [])):
        if slot.get("Slot") != position:
            errors.append(
                f"{rel}: slot at position {position} declares Slot {slot.get('Slot')}. "
                "Slots must be listed in order starting at 0; the engine addresses them by position."
            )

    refine_costs = payload.get("Refine", {}).get("DustCostPerRank", [])
    options = payload.get("Options", [])
    seen_types: dict[int, int] = {}

    for option in options:
        bonus_type = option.get("Type")
        expected_name = BONUS_TYPES.get(bonus_type)
        if expected_name is None:
            errors.append(f"{rel}: unknown perk Type {bonus_type}")
            continue

        seen_types[bonus_type] = seen_types.get(bonus_type, 0) + 1

        if option.get("TypeName") != expected_name:
            errors.append(
                f"{rel}: Type {bonus_type} is {expected_name}, but TypeName says {option.get('TypeName')!r}"
            )

        expected_unit = unit_for(option)
        if option.get("Unit") != expected_unit:
            errors.append(
                f"{rel}: Type {bonus_type} takes a {expected_unit} Value, "
                f"but Unit says {option.get('Unit')!r}"
            )

        if not option.get("Weight", 1):
            errors.append(f"{rel}: Type {bonus_type} has Weight 0 and could never be rolled")

        values = option.get("ValuePerRank", [])
        if not values:
            errors.append(f"{rel}: Type {bonus_type} has an empty ValuePerRank")
            continue

        for rank in range(1, len(values)):
            if values[rank] < values[rank - 1]:
                errors.append(
                    f"{rel}: Type {bonus_type} ValuePerRank drops from {values[rank - 1]} at rank "
                    f"{rank - 1} to {values[rank]} at rank {rank}. Refining must not make a perk worse."
                )

        max_rank = len(values) - 1
        if max_rank and len(refine_costs) <= max_rank:
            errors.append(
                f"{rel}: Type {bonus_type} goes up to rank {max_rank}, but Refine.DustCostPerRank "
                f"only has {len(refine_costs)} entries, so that rank can never be bought."
            )

        ceiling = VALUE_CEILINGS.get(bonus_type)
        if ceiling is not None and values[-1] > ceiling:
            warnings.append(
                f"{rel}: Type {bonus_type} ({expected_name}) tops out at {values[-1]}, above the current "
                f"ceiling {ceiling}. Intentional, or a misplaced decimal? Raise VALUE_CEILINGS if intentional."
            )

    for bonus_type, count in seen_types.items():
        if count > 1:
            warnings.append(
                f"{rel}: Type {bonus_type} ({BONUS_TYPES.get(bonus_type)}) is listed {count} times. "
                "Fine if the entries differ by SpellId, ElementId or SkillId; otherwise they compete for the same roll."
            )

    for rank in range(1, len(refine_costs)):
        if refine_costs[rank] < refine_costs[rank - 1]:
            warnings.append(
                f"{rel}: Refine.DustCostPerRank falls from {refine_costs[rank - 1]} at rank {rank - 1} "
                f"to {refine_costs[rank]} at rank {rank}. Each step is meant to cost more than the last."
            )

    return len(options)


def validate() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    seen: dict[int, tuple[Path, str]] = {}

    for path, payload in _iter_generated():
        rel = path.relative_to(REPO_ROOT)
        ids_in_file = set()
        for entry in payload["Proficiencies"]:
            proficiency_id = entry["ProficiencyId"]
            if proficiency_id in ids_in_file:
                errors.append(f"{rel}: ProficiencyId {proficiency_id} appears twice in the same file")
            ids_in_file.add(proficiency_id)

            fingerprint = json.dumps(entry, sort_keys=True)
            if proficiency_id in seen:
                previous_path, previous_fingerprint = seen[proficiency_id]
                if previous_fingerprint != fingerprint:
                    errors.append(
                        f"ProficiencyId {proficiency_id} differs between {previous_path} and {rel}. "
                        "Shared ids must stay byte-identical: the loader keeps whichever file is read first."
                    )
            else:
                seen[proficiency_id] = (rel, fingerprint)

            for level_index, level in enumerate(entry["Levels"], start=1):
                if level["Level"] != level_index:
                    errors.append(f"{rel}: proficiency {proficiency_id} level {level['Level']} is at position {level_index}")
                for perk in level["Perks"]:
                    bonus_type = perk["Type"]
                    expected_name = BONUS_TYPES.get(bonus_type)
                    if expected_name is None:
                        errors.append(f"{rel}: proficiency {proficiency_id} uses unknown Type {bonus_type}")
                    elif perk.get("TypeName") != expected_name:
                        errors.append(
                            f"{rel}: proficiency {proficiency_id} Type {bonus_type} is {expected_name}, "
                            f"but TypeName says {perk.get('TypeName')!r}"
                        )

                    if "SkillId" in perk:
                        skill_name = CIPBIA_SKILLS.get(perk["SkillId"])
                        if skill_name is None:
                            errors.append(
                                f"{rel}: proficiency {proficiency_id} SkillId {perk['SkillId']} is not a CipbiaSkills_t "
                                "value; the server drops the perk at load time"
                            )
                        elif perk.get("SkillName") != skill_name:
                            errors.append(
                                f"{rel}: proficiency {proficiency_id} SkillId {perk['SkillId']} is {skill_name}, "
                                f"but SkillName says {perk.get('SkillName')!r}"
                            )

                    if bonus_type == SPELL_AUGMENT and "AugmentType" in perk:
                        augment_name = AUGMENT_TYPES.get(perk["AugmentType"])
                        if augment_name is None:
                            errors.append(
                                f"{rel}: proficiency {proficiency_id} uses unknown AugmentType {perk['AugmentType']}"
                            )
                        elif perk.get("AugmentName") != augment_name:
                            errors.append(
                                f"{rel}: proficiency {proficiency_id} AugmentType {perk['AugmentType']} is "
                                f"{augment_name}, but AugmentName says {perk.get('AugmentName')!r}"
                            )

                    expected_unit = unit_for(perk)
                    if perk.get("Unit") != expected_unit:
                        errors.append(
                            f"{rel}: proficiency {proficiency_id} Type {bonus_type} takes a {expected_unit} "
                            f"Value, but Unit says {perk.get('Unit')!r}"
                        )

                    ceiling = VALUE_CEILINGS.get(bonus_type)
                    if ceiling is not None and perk["Value"] > ceiling:
                        warnings.append(
                            f"{rel}: proficiency {proficiency_id} Type {bonus_type} "
                            f"({BONUS_TYPES.get(bonus_type)}) Value {perk['Value']} is above the current ceiling "
                            f"{ceiling}. Intentional, or a misplaced decimal? Raise VALUE_CEILINGS if intentional."
                        )

    if LEGACY_JSON.exists():
        legacy_ids = {entry["ProficiencyId"] for entry in json.loads(LEGACY_JSON.read_text(encoding="utf-8"))}
        missing = legacy_ids - set(seen)
        if missing:
            errors.append(f"ProficiencyIds lost during the split: {sorted(missing)}")

    shaping_options = validate_shaping(errors, warnings)

    for warning in warnings:
        print(f"WARN  {warning}")
    for error in errors:
        print(f"ERROR {error}")
    print(
        f"\n{len(seen)} distinct proficiencies and {shaping_options} shaping options checked, "
        f"{len(errors)} errors, {len(warnings)} warnings"
    )
    return 1 if errors else 0


def write_schema() -> int:
    """Emit the JSON Schema editors use for autocomplete and hover docs.

    Generated from the same constants the split and validation use, so the
    editor can never describe a Type differently from what the loader does.
    """
    type_values = sorted(BONUS_TYPES)
    perk_properties = {
        "Type": {
            "type": "integer",
            "description": "WeaponProficiencyBonus_t (src/enums/weapon_proficiency.hpp). Read by the engine.",
            "enum": type_values,
            "enumDescriptions": [BONUS_TYPES[value] for value in type_values],
        },
        "TypeName": {
            "type": "string",
            "description": "Label for Type. Ignored by the engine; validated to match Type.",
            "enum": [BONUS_TYPES[value] for value in type_values],
        },
        "SkillId": {
            "type": "integer",
            "description": (
                "CipbiaSkills_t, NOT the server's skills_t. 8 is Sword here but "
                "SKILL_CRITICAL_HIT_DAMAGE in skills_t. Any value outside this list makes "
                "the server log an error and drop the perk."
            ),
            "enum": sorted(CIPBIA_SKILLS),
            "enumDescriptions": [CIPBIA_SKILLS[value] for value in sorted(CIPBIA_SKILLS)],
        },
        "SkillName": {
            "type": "string",
            "description": "Label for SkillId. Ignored by the engine; validated to match SkillId.",
            "enum": [CIPBIA_SKILLS[value] for value in sorted(CIPBIA_SKILLS)],
        },
        "AugmentType": {
            "type": "integer",
            "description": "Only used with Type 5 (SPELL_AUGMENT). Decides the unit of Value.",
            "enum": sorted(AUGMENT_TYPES),
            "enumDescriptions": [AUGMENT_TYPES[value] for value in sorted(AUGMENT_TYPES)],
        },
        "AugmentName": {
            "type": "string",
            "description": "Label for AugmentType. Ignored by the engine; validated to match it.",
            "enum": [AUGMENT_TYPES[value] for value in sorted(AUGMENT_TYPES)],
        },
        "SpellId": {"type": "integer", "description": "Spell this augment applies to. Read by the engine."},
        "Range": {"type": "integer", "description": "Tiles, for PERFECT_SHOT_DAMAGE. Read by the engine."},
        "DamageType": {"type": "integer", "description": "Required by SPECIALIZED_MAGIC_LEVEL. Read by the engine."},
        "ElementId": {
            "type": "integer",
            "description": "Required by the ELEMENTAL_* types. Read by the engine.",
        },
        "BestiaryId": {"type": "integer", "description": "Read by the engine."},
        "BestiaryName": {"type": "string", "description": "Read by the engine."},
        "Value": {
            "type": "number",
            "description": (
                "The number to balance. Check Unit first: percent values are fractions, so "
                "0.10 means 10% and writing 10 means 1000%."
            ),
        },
        "Unit": {
            "type": "string",
            "description": "How Value is read. Ignored by the engine; validated against Type/AugmentType.",
            "enum": ["flat", "percent", "milliseconds"],
            "enumDescriptions": [
                "Absolute amount: skill points, mana or life restored, damage, tiles of range.",
                "Fraction of 1: 0.10 is 10%.",
                "Raw milliseconds, always negative (cooldown reduction).",
            ],
        },
    }

    schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "Canary weapon proficiencies",
        "description": (
            "One file per weapon category. Generated by tools/proficiency_split.py; "
            "run `python -m tools.proficiency_split validate` after editing."
        ),
        "type": "object",
        "required": ["Category", "Proficiencies"],
        "properties": {
            "$schema": {"type": "string"},
            "Category": {"type": "string", "enum": [*CATEGORIES, "Orphaned"]},
            "Comment": {"type": "string"},
            "Proficiencies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["ProficiencyId", "Levels"],
                    "properties": {
                        "ProficiencyId": {
                            "type": "integer",
                            "description": "The only link to a weapon: items in appearances.dat point here. Read by the engine.",
                        },
                        "Name": {"type": "string", "description": "Human label. Ignored by the engine."},
                        "Weapon": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Real item names that use this proficiency, from appearances.dat. Ignored by the engine.",
                        },
                        "Version": {"type": ["integer", "null"], "description": "Ignored by the engine."},
                        "Levels": {
                            "type": "array",
                            "description": "Order is the level order; the engine uses position, not the Level field.",
                            "items": {
                                "type": "object",
                                "required": ["Perks"],
                                "properties": {
                                    "Level": {"type": "integer", "description": "Position, 1-based. Ignored by the engine."},
                                    "Perks": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "required": ["Type", "Value"],
                                            "properties": perk_properties,
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / SCHEMA_NAME
    path.write_text(json.dumps(schema, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {path.relative_to(REPO_ROOT)}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["split", "validate", "schema"])
    args = parser.parse_args()

    if args.command == "validate":
        return validate()

    if args.command == "schema":
        return write_schema()

    with tempfile.TemporaryDirectory() as workdir:
        pb2 = build_appearances_pb2(Path(workdir))
        return split(pb2)


if __name__ == "__main__":
    raise SystemExit(main())
