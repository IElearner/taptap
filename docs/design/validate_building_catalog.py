#!/usr/bin/env python3
"""Validate spatial and staffing coverage for the proposal building catalog only."""
from __future__ import annotations
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
catalog = json.loads((HERE / "building_catalog.json").read_text(encoding="utf-8"))
economy = json.loads((HERE / "launch_economy.json").read_text(encoding="utf-8"))
rows = catalog["buildings"]
expected = economy["buildings"]

def fail(msg: str) -> None:
    raise SystemExit(f"FAIL: {msg}")

if len(rows) != 32 or len(rows) != economy["target_building_count"]:
    fail(f"expected 32 catalog entries, got {len(rows)}")
if [(r["id"], r["name"]) for r in rows] != [(b["id"], b["name"]) for b in expected]:
    fail("catalog IDs/names/order differ from the economic roster")
if len({r["id"] for r in rows}) != len(rows):
    fail("duplicate building ID")
footprint_shapes = {tuple(sorted(tuple(c) for c in r["footprint"])) for r in rows}
footprint_areas = {len(r["footprint"]) for r in rows}
if len(footprint_shapes) < 5 or len(footprint_areas) < 4:
    fail("footprint variety is too small for the varied-building requirement")
if not any(len(r["footprint"]) < (max(c[0] for c in r["footprint"])+1)*(max(c[1] for c in r["footprint"])+1) for r in rows):
    fail("expected at least one non-rectangular footprint")
by_id = {r["id"]: r for r in rows}
if len(by_id["home"]["footprint"]) != 6 or len(by_id["warehouse"]["footprint"]) <= len(by_id["home"]["footprint"]):
    fail("home/warehouse scale hierarchy is inconsistent")
if "water_adjacent" not in by_id["mill"]["site_constraints"] or "shore_adjacent" not in by_id["fishery"]["site_constraints"]:
    fail("mill/fishery site constraints must reflect their water function")
cardinal = {(0, -1), (1, 0), (0, 1), (-1, 0)}
for r in rows:
    name = r["name"]
    cells = r["footprint"]
    if not cells or len(cells) != len({tuple(c) for c in cells}):
        fail(f"{name}: footprint is empty or has duplicate cells")
    if any(len(c) != 2 or any(not isinstance(v, int) for v in c) or min(c) < 0 for c in cells):
        fail(f"{name}: footprint must use non-negative integer [x,y] cells")
    occupied = {tuple(c) for c in cells}
    # One connected footprint so all placed subcells form a single building.
    pending = [next(iter(occupied))]
    seen = set(pending)
    while pending:
        x, y = pending.pop()
        for dx, dy in cardinal:
            n = (x + dx, y + dy)
            if n in occupied and n not in seen:
                seen.add(n)
                pending.append(n)
    if seen != occupied:
        fail(f"{name}: disconnected footprint")
    ent = r["entrance"]
    cell = tuple(ent["cell"])
    outward = tuple(ent["outward"])
    if cell not in occupied or outward not in cardinal:
        fail(f"{name}: entrance cell must be in footprint with cardinal outward direction")
    approach = (cell[0] + outward[0], cell[1] + outward[1])
    if approach in occupied:
        fail(f"{name}: entrance approach is blocked by its own footprint")
    for field in ("storage_capacity_units", "max_operational_staff", "household_capacity", "dining_seats", "construction_workpoints", "construction_total_work_units"):
        value = r[field]
        if not isinstance(value, int) or value < 0:
            fail(f"{name}: {field} must be a non-negative integer")
    if r["construction_workpoints"] < 1 or r["construction_total_work_units"] < 1:
        fail(f"{name}: construction points and total labor must be positive")
    if r["max_operational_staff"] == 0 and (r["dining_seats"] or r["household_capacity"]):
        # Non-job services and homes may be occupied without an operator.
        pass
    if r["dining_seats"] and r["name"] != "食堂":
        fail(f"{name}: unexpected dining-seat count")
    if r["household_capacity"] and r["name"] != "家院":
        fail(f"{name}: unexpected household capacity")

print(f"PASS: {len(rows)} spatial specs match the 32-building economic roster in order")
print(f"PASS: every footprint is connected, unique-cell, and has an unobstructed cardinal entrance")
print(f"PASS: all buildings specify finite storage, operating staffing, construction points, and total work")
print(f"PASS: {next(r['dining_seats'] for r in rows if r['name']=='食堂')} dining seats are explicit and separate from construction staffing")
print("LIMIT: all dimensions/capacities/work values are original design proposals; no placement, traffic, balance, or implementation claim")
