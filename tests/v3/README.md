# Independent v3 QA

This directory tests the 25-facility expansion. It does **not** claim the full game is accepted or 95% complete. The scoring contract is `QA_ACCEPTANCE_MATRIX.md`; unverified atoms score zero.

Run each test serially against a declared frozen source/art candidate:

```sh
python tests/v3/run_native.py tests/v3/map_mill_validate.lua --run UNIQUE-map-mill --frames 210
python tests/v3/run_native.py tests/v3/economy_orders_validate.lua --run UNIQUE-orders --frames 510
python tests/v3/run_native.py tests/v3/forestry_validate.lua --run UNIQUE-forest --frames 710
python tests/v3/run_native.py tests/v3/deposits_validate.lua --run UNIQUE-deposits --frames 40
python tests/v3/run_native.py tests/v3/migration_validate.lua --run UNIQUE-migration --frames 310
python tests/v3/run_native.py tests/v3/military_validate.lua --run UNIQUE-military --frames 40
python tests/v3/run_native.py tests/v3/inherited_boundaries_validate.lua --run UNIQUE-inherited --frames 460
python tests/v3/run_native.py tests/v3/entry_hud_validate.lua --run UNIQUE-entry --frames 60
python tests/v3/run_native.py tests/v3/refund_delivery_validate.lua --run UNIQUE-refund --frames 60
python tests/v3/run_native.py tests/v3/new_goods_transit_validate.lua --run UNIQUE-cargo --frames 510
```

`end_to_end_validate.lua` is in progress pending the twenty-lesson campaign API. Do not treat its source, any isolated stock fixture, or an aggregate assertion count as evidence of a no-gift full playthrough. The atomic production, reserve and military suites intentionally construct controlled inventory states. The E2E suite must pay every construction and recruit from actual starter/earned resources.

The runner preserves raw JSON/logs and test/fixture/source hashes. It never overwrites an existing run ID. This container's native runtime cannot open its default `/home/agent/logs/lua/…` log file; raw launcher results remain FAIL and that environment error is classified separately from assertions. Do not change HOME, write into the home directory, omit raw errors, or relabel raw FAIL as PASS. Confirm every sourceBefore equals sourceAfter before using evidence.

Local native tests use `.cli/UrhoXRuntime` in surfaceless mode; they do not start a Maker preview, build remotely or submit code. Real phone/device performance remains unverified.

## Preserved first candidates

- `d50-*`: first independent expansion unit/integration run. Test-only issues in the old lesson-index expectation and smelter placement/refund fixture remain preserved.
- `715-*`: schema6 map/mill candidate, source `715423ad4de26c6d74f4afb973a3e9e777a62836c1705baea1bba110689a1962`. Eight suites passed 407 assertions. The separately added refund suite passed 4/6 and reproduced an actual tutorial bypass: physically returned unused wood was counted as new sawmill production. This candidate is not accepted.

Per-run manifests bind exact test text; tests may be expanded later. Read the manifest rather than assuming the current file is identical to an earlier test.
