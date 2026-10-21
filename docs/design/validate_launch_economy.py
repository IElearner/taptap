#!/usr/bin/env python3
"""Check first-launch design data integrity. This is not a balance/gameplay test."""
from __future__ import annotations

import json
import math
import re
import sys
from collections import defaultdict
from pathlib import Path


HERE = Path(__file__).resolve().parent
DATA_PATH = HERE / "launch_economy.json"
GDD_PATH = HERE / "CHINESE_VILLAGE_GDD.md"


def fail(message: str) -> None:
    raise AssertionError(message)


def main() -> int:
    data = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    gdd = GDD_PATH.read_text(encoding="utf-8")
    buildings = data["buildings"]
    resources = data["resources"]
    resource_set = set(resources)

    if len(buildings) != data["target_building_count"]:
        fail(f"building count {len(buildings)} != target {data['target_building_count']}")
    for key, label in (("id", "id"), ("name", "name")):
        values = [b[key] for b in buildings]
        if len(values) != len(set(values)):
            fail(f"duplicate building {label}")
    if len(resources) != len(resource_set):
        fail("duplicate resource key")
    if any(plot.get("counts_as_building") for plot in data["plots"]):
        fail("land plots must not inflate building count")
    if len(data["plots"]) != 4:
        fail("expected the four explicitly scoped land/water plot types")

    source_nodes: dict[str, list[str]] = defaultdict(list)
    sink_nodes: dict[str, list[str]] = defaultdict(list)
    for plot in data["plots"]:
        for item in plot.get("source_resources", []):
            source_nodes[item].append(f"plot:{plot['name']}")
        if "source_resource" in plot:
            source_nodes[plot["source_resource"]].append(f"plot:{plot['name']}")
        for item in plot.get("output", {}):
            source_nodes[item].append(f"plot:{plot['name']}")

    def check_map(owner: str, mapping: dict[str, int], side: str) -> None:
        for item, quantity in mapping.items():
            if item not in resource_set:
                fail(f"unlisted resource {item!r} in {owner}.{side}")
            if not isinstance(quantity, (int, float)) or quantity <= 0:
                fail(f"non-positive quantity for {item!r} in {owner}.{side}")

    def recipes_for(building: dict) -> list[dict]:
        recipes = building.get("recipes")
        if recipes:
            return recipes
        if building.get("inputs") or building.get("outputs"):
            return [{"name": building["name"], "inputs": building.get("inputs", {}), "outputs": building.get("outputs", {})}]
        return []

    for b in buildings:
        owner = f"building:{b['name']}"
        check_map(owner, b.get("construction", {}), "construction")
        # A recipe list is authoritative for alternative orders. Union maps support UI summaries only.
        for recipe in recipes_for(b):
            rin = recipe.get("inputs", {})
            rout = recipe.get("outputs", {})
            if "可交易物資" in rin:
                rin = {item: rin["可交易物資"] for item in b.get("trade_inputs", [])}
            check_map(owner + "/" + recipe.get("name", "recipe"), rin, "inputs")
            check_map(owner + "/" + recipe.get("name", "recipe"), rout, "outputs")
            for item in rin:
                sink_nodes[item].append(owner)
            for item in rout:
                source_nodes[item].append(owner)
            for item in recipe.get("terminal_sinks", {}):
                if item not in resource_set:
                    fail(f"unlisted terminal sink resource {item!r} in {owner}/{recipe.get('name')}")
                sink_nodes[item].append(owner + "/recipe-terminal")
        for item in b.get("trade_inputs", []):
            if item not in resource_set:
                fail(f"unlisted trade input {item!r} in {owner}")
            sink_nodes[item].append(owner + "/trade")
        for item in b.get("construction", {}):
            sink_nodes[item].append(owner + "/construction")
        for item in b.get("terminal_sinks", {}):
            if item not in resource_set:
                fail(f"unlisted terminal sink resource {item!r} in {owner}")
            sink_nodes[item].append(owner + "/terminal")

    for unit in data["unit_recipes"]:
        owner = f"unit:{unit['name']}"
        check_map(owner, unit["inputs"], "inputs")
        check_map(owner, unit.get("outputs", {}), "outputs")
        for item in unit["inputs"]:
            sink_nodes[item].append(owner)
        for item in unit.get("outputs", {}):
            source_nodes[item].append(owner)

    for transition in data.get("population_transitions", []):
        owner = f"population:{transition['name']}"
        check_map(owner, transition.get("inputs", {}), "inputs")
        check_map(owner, transition.get("outputs", {}), "outputs")
        for item in transition.get("inputs", {}):
            sink_nodes[item].append(owner)
        for item in transition.get("outputs", {}):
            source_nodes[item].append(owner)

    for item, quantity in data.get("validation_seed_stocks", {}).items():
        if item not in resource_set or quantity <= 0:
            fail(f"invalid starting stock {item!r}")
        source_nodes[item].append("starting_stock")
    for item in data.get("terminal_sinks", {}):
        if item not in resource_set:
            fail(f"unlisted terminal sink resource {item!r}")
        sink_nodes[item].append("terminal_sink")

    missing_sources = sorted(item for item in resource_set if not source_nodes[item])
    missing_sinks = sorted(item for item in resource_set if not sink_nodes[item])
    if missing_sources:
        fail("resources without a source: " + ", ".join(missing_sources))
    if missing_sinks:
        fail("resources without a sink: " + ", ".join(missing_sinks))

    # Design-table names must stay aligned with the machine-readable 32-building roster.
    for b in buildings:
        if b["name"] not in gdd:
            fail(f"GDD does not mention building {b['name']}")
    if "首发设计固定 **32 种可建建筑**" not in gdd:
        fail("GDD scope/count statement missing")
    table_rows = re.findall(r"^\|\s*(\d+)\s*\|\s*([^|]+)\|", gdd, re.MULTILINE)
    if [int(number) for number, _ in table_rows] != list(range(1, len(buildings) + 1)):
        fail("GDD building table must enumerate exactly 1..N in order")
    table_names = [name.strip() for _, name in table_rows]
    if table_names != [b["name"] for b in buildings]:
        fail("GDD building table differs from machine-readable building order/names")

    pop = data["population"]
    food = data["food_math"]
    daily_need = (food["target_population"] + food["target_military_units"]) * food["portions_per_person_per_day"]
    if daily_need != food["daily_food_for_target"]:
        fail(f"daily food mismatch: calculated {daily_need}, declared {food['daily_food_for_target']}")
    if not math.isclose(daily_need / food["game_day_minutes"], food["daily_food_per_minute"]):
        fail("daily food-per-minute arithmetic mismatch")
    starting_need = food["starting_population"] * food["portions_per_person_per_day"]
    if starting_need != food["starting_food_need_per_day"]:
        fail("starting-population food calculation mismatch")
    if not math.isclose(starting_need / food["game_day_minutes"], food["starting_food_per_minute"]):
        fail("starting-population food-per-minute mismatch")
    if pop["starting_residents"] != food["starting_population"]:
        fail("starting population mismatch between economy and food sections")
    if pop["houses"] * pop["capacity_per_house"] < pop["starting_residents"]:
        fail("starting households do not fit the stated residents")
    initial_buildings = data.get("validation_seed_buildings", {})
    known_buildings = {b["name"] for b in buildings}
    if not initial_buildings or set(initial_buildings) - known_buildings:
        fail("starting buildings are missing or include an unlisted type")
    if initial_buildings.get("家院") != pop["houses"]:
        fail("starting house count differs from household capacity data")
    if pop["baseline_simultaneous_haulers"] + pop["baseline_simultaneous_construction_workers"] + pop["assigned_specialists"] + pop["available_labor_reserve"] != pop["starting_residents"]:
        fail("starting labor assignments do not add up to starting residents")
    if data.get("validation_seed_stocks", {}).get("可征兵劳力") != pop["available_labor_reserve"]:
        fail("available manpower stock must equal the stated free labor reserve")
    for item, quantity in data.get("validation_seed_stocks", {}).items():
        if quantity <= 0:
            fail(f"starting stock {item} must be positive; omit zero stock entries")
    field = next(p for p in data["plots"] if p["name"] == "麥田")
    if sum(field["phases"].values()) != field["cycle_seconds"]:
        fail("field phase durations do not sum to the declared crop cycle")
    bakery = next(b for b in buildings if b["id"] == "bakery")
    bakery_yield = bakery["outputs"]["面餅"] * 60 / bakery["cycle_seconds"]
    target_bakery_yield = bakery_yield * food["bakery_count_target"]
    if target_bakery_yield < food["daily_food_per_minute"]:
        fail("target bakery count nominal rate does not meet target food rate")
    if bakery_yield >= food["daily_food_per_minute"]:
        fail("single bakery unexpectedly meets resident-plus-military target; update bottleneck arithmetic")
    flour_needed = daily_need / food["bread_per_flour"]
    mill = next(b for b in buildings if b["id"] == "mill")
    field_daily_grain = field["output"]["麥粒"] * food["game_day_minutes"] * 60 / field["cycle_seconds"]
    daily_mill_cycles = flour_needed / food["mill_flour_per_cycle"]
    grain_needed = daily_mill_cycles * food["mill_grain_per_cycle"]
    bran_daily = daily_mill_cycles * food["mill_bran_per_cycle"]
    if grain_needed > field_daily_grain:
        fail("single-field theoretical grain output cannot meet daily bread target")
    pigfarm = next(b for b in buildings if b["id"] == "swine")
    pig_feed = pigfarm.get("inputs", {}).get("麩皮", 0)
    pig_capacity = food["game_day_minutes"] * 60 / pigfarm["cycle_seconds"]
    bran_supported_pigs = bran_daily / pig_feed

    logistics = data["logistics"]
    porter_capacity = logistics["porters"] * pop["game_day_minutes"] * 60 / logistics["average_round_trip_seconds"]
    if int(porter_capacity) != food["porter_daily_trips"]:
        fail("porter daily trip capacity arithmetic mismatch")
    food_trips = math.ceil(grain_needed / logistics["load_units_per_trip"])
    food_trips += math.ceil(flour_needed / logistics["load_units_per_trip"])
    food_trips += math.ceil(daily_need / logistics["load_units_per_trip"])
    if food_trips != food["inn_food_transport_trips_per_day"]:
        fail(f"food chain transport trip mismatch: calculated {food_trips}, declared {food['inn_food_transport_trips_per_day']}")
    if food_trips > porter_capacity:
        fail("two-porter nominal capacity cannot transport the daily bread chain")

    print(f"PASS: {len(buildings)} unique building types; {len(data['plots'])} plot types excluded from building count")
    print(f"PASS: {len(resources)} listed resource/state items each have at least one source and one sink")
    print(f"PASS: validation seed lists {sum(initial_buildings.values())} prebuilt buildings and {len(data['validation_seed_stocks'])} positive stock entries")
    print(f"PASS: {daily_need} target rations/day = {food['daily_food_per_minute']:.2f}/min; target bakeries={food['bakery_count_target']}x{bakery_yield:.2f}={target_bakery_yield:.2f}/min")
    print(f"PASS: starting {starting_need} meals/day = {food['starting_food_per_minute']:.2f}/min; target expansion is explicit")
    print(f"PASS: target bread requires {grain_needed:.0f} grain/day and yields {bran_daily:.0f} bran/day; one field theoretical={field_daily_grain:.0f} grain/day")
    print(f"PASS: bran supports {bran_supported_pigs:.0f} pigs/day vs pig pen theoretical {pig_capacity:.0f}/day; feed is the stated bottleneck")
    print(f"PASS: daily food chain={food_trips} porter trips; capacity={porter_capacity:.0f} trips/day")
    print("LIMIT: integrity/nominal arithmetic only; no gameplay balance, pathfinding, frame-time, or implementation claim")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, KeyError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
