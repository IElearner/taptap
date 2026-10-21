# Independent life QA

当前实际结果：最终复合院落候选4946已限定验收。见 [最终QA报告](evidence/FINAL4946_COMPOUND_QA.md) 与 [完整运行索引](evidence/FINAL4946_COMPOUND_RUN_INDEX.json)：451条当前源码原生断言、66条明确d186继承证据分列。以下早期“prepared/待执行”段是各历史阶段的准备记录，不是最新完成状态。原始失败/截断均保留，手机与全游戏95%未签。

Do not start native while production or art is changing. Root/development owns the current source window. No military/old95/sustainability reruns are part of this slice.

Prepared scripts (syntax checked only; not acceptance evidence):

- `cycle_validate.lua`: real complete fish/mine/quarry/mason cycles and per-phase JSON.
- `boundaries_validate.lua`: cancellation, committed loads, hunger, staff, disconnection, shared pool, full shelf.
- `yard_save_validate.lua`: actual new reserved work yards, bank geometry, immutable earned schema8 migration, malformed holds.
- `visual_sequence.lua`: autonomous same-actor state trace and held native screenshots. Run IDs ending `visual-fishery-n`, `-s`, `-e`, `-w` select real legal directional banks; adding `-clip` records a continuous PNG sequence, not a fabricated animation montage. Other kinds include mason/ironmine/quarry.

`support.lua` explicitly provisions isolated construction stocks, completed buildings/roads and finite test pool/input amounts. These are controlled fixtures, never evidence of resources earned by a player. No helper assigns a WorkLife phase or calls commit/store. Role food requests are artificially induced only in the labelled hunger edge case.

Runner source hashing includes all production Lua, pixel-v1 PNG/JSON including life/, and fonts. It also records every fixture file and all life helper/test Lua hashes before/after; do not edit any during a run. Use unique run names and retain raw errors. Host logger permission errors remain raw FAIL and must be separated from product assertions.

Example after a joint freeze:

```sh
python tests/life/run_native.py tests/life/cycle_validate.lua --run life1-cycle --frames 850 --timeout 240
python tests/life/run_native.py tests/life/boundaries_validate.lua --run life1-boundaries --frames 1600 --timeout 240
python tests/life/run_native.py tests/life/yard_save_validate.lua --run life1-yard-save --frames 450 --timeout 130
python tests/life/run_native.py tests/life/visual_sequence.lua --run life1-visual-fishery-e-clip --frames 3230 --timeout 300 --width 1280 --height 720
```

These commands are plans, not executed results. Actual PNG review, actor contact and carry occlusion are mandatory. Phone remains unverified.

Native host log permission (validated 2026-10-20): invoke the native runner through
`exec_command` with `sandbox_permissions="with_additional_permissions"` and
`additional_permissions.file_system.write=["/home/agent/logs/lua"]`. This grants
only the existing host logger directory; it changes no production files or game
behavior. f6b runs use this condition and can report actual raw PASS. Earlier a824
raw host-permission FAIL reports remain unmodified.

## C+D prepared suites (not yet executed)

These files currently have syntax validation only. Do not interpret their
presence as accepted behavior or use development-state failures as product bugs.
Run them serially only after the shared production/assets freeze:

- `carrier_sites_validate.lua`: six real production→private pickup cycles,
  instrumented actual `Economy.take`, loading midpoint and phase JSON.
- `carrier_boundaries_validate.lua`: old flagless job, loaded missing return
  route, empty loading shelf, shared station competition. Resource/road
  interventions are explicitly controlled boundary fixtures.
- `carrier_compact_validate.lua`: declared synthetic schema8 fixture, unchanged
  geometry and reachable compact new-job opt-in. It does not replace the actual
  earned35 migration fixture.
- `carrier_sites_visual.lua`: run name `...-pickup-fishery` (or a mineral/mason
  kind), 4230 frames, real same-carrier phases held at least3 render frames.
- `workbreaks_validate.lua`, `workbreaks_boundaries_validate.lua`: ten workshop
  natural idle/return/real work and blocked-reason matrices. **Pending adaptation
  to the newly announced Save10 ground-station/workLoad→storage contract.**
  Current draft's same-commit output assertion must not be run as the final gate.
- `workshop_visual.lua`: run name `...-workshop-mill` (or another of the ten
  workshop kinds), 5630 frames; real same actor idle/work/finish/meal sequences.
  Also needs final ground-station API review before execution.
- `cargo_contacts_validate.lua`: contact-only primitive inspection of four long
  ware types×four directions. A conservative face-zone check is supplementary;
  `cargo_visual.lua` native88-image review still decides actual contact quality.
- `wind_isolated_visual.lua` with `compare_wind_roi.py`: normal simulation clock
  on one genuine standing tree. Neighbor-tree clearing is an explicit rendering
  isolation fixture with no inventory reward, not logging/economy evidence.

Do not rerun frozen B captures in a changing C+D working tree. Their manifests
retain the exact historic source hashes and raw results.

`offline_life_validate.lua` adds the life/outdoor-only offline gate (syntax checked,
not yet executed). It uses 6 WorkLife + 10 workshop cases with declared hunger95
and one real recipe/source batch, actual `Offline.step`, food/pantry/job totals,
mid-settlement wall-time checkpoint, repeated completed reload, and real paid-meal
continuation. No hunger/R02 threshold is relaxed and no military suite is reopened.
# Integrated-compound tests

The `compound_*.lua` group targets the schema11 candidate contract agreed with
development: `site.compound={version=1,bounds={xmin,ymin,xmax,ymax},ground,source}`
and shared world-space `site.railRoute`. They must run only after root releases
the frozen production/asset build to QA. The c083 first run is sealed in
`evidence/C083_COMPOUND_REVIEW.md`: models/script checks pass, visual integration
requires revision. Prior diagnostics remain preserved.

- `compound_validate.lua`: real preview/build geometry, rounded plot ownership,
  preserved public doorway, registered work/stock/rest points, finite source
  identity, JSON, and authentic schema8 already-carried jobs. Use at least 880
  frames and require its `<run>-complete.json`.
- `compound_terrain_validate.lua`: actual positive siting, near-but-inaccessible
  mature trees, dry reachable banks, and exhausted resource identity. Use at
  least 730 frames and require its complete JSON. Boundary obstacles are explicit
  test setup, not a player-built village.
- `compound_rail_validate.lua`: actual mine-in/out movement on the shared rail,
  every relevant phase JSON, safe stop while genuinely loaded, and single
  delivery/resource conservation. Use at least 1830 frames and require complete
  JSON.
- `compound_visual.lua`: run names must contain `compoundvisual-<kind>`.
  Recommended viewport 1280×720, initially 2420 frames (2400-frame test budget).
  A run name suffix `budget6400` requests a 6400-frame test / 6420-frame runtime
  if the natural cycle genuinely needs more time; preserve incomplete earlier
  evidence instead of claiming the short budget passed. Its fixed building camera
  records actual autonomous phases and ordinary carrier pickup with four held
  renders per screenshot. Require final state JSON, all five assertions, and
  independent image inspection; no custom shader or fake actor overlay is used.

Materials, initial input supply and completed structures/roads are explicitly
controlled scaffolding. These files do not prove earned construction, whole-village
economic endurance, physical phone performance, or building demolition/refunds.
The existing `cancelPlacement` UI only exits placement mode; do not invent a paid
building cancellation API. Existing production interruption tests cover ordinary
stop/staff/meal handling separately. Previous old-source manifests remain intact.

