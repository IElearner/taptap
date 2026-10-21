# D186 compound QA — sealed, save blocker remains

Source: `d18631775292a1a36053e4e37c77b6ead0437c3c075a47e1e4524b07349e7ebb`, 192 production files, Save12. All native processes exited and QA formally released the development window. No production files were edited by QA.

Six **completed** accepted groups contain **66/66 assertions**, raw PASS. This does **not** mean this candidate is accepted overall: a genuine mid-pickup save/load failure remains. [Machine-readable index](D186_COMPOUND_RUN_INDEX.json) binds every accepted group to matching source/test/helper/fixture hashes, its explicit V.finish marker and `complete=true` artifact.

| Run | Actual completed assertions | Evidence |
|---|---:|---|
| d186-upgrade | 34/34 | [manifest](raw/d186-upgrade-manifest.json), [complete](d186-upgrade-complete.json) |
| d186-upgrade-hud | 12/12 | [manifest](raw/d186-upgrade-hud-manifest.json), [states](visual/d186-upgrade-hud-states.json) |
| d186-compoundvisual-woodcutter | 5/5 | [manifest](raw/d186-compoundvisual-woodcutter-manifest.json), [states](visual/d186-compoundvisual-woodcutter-states.json) |
| d186-compoundvisual-fishery | 5/5 | [manifest](raw/d186-compoundvisual-fishery-manifest.json), [states](visual/d186-compoundvisual-fishery-states.json) |
| d186-compoundvisual-quarry | 5/5 | [manifest](raw/d186-compoundvisual-quarry-manifest.json), [states](visual/d186-compoundvisual-quarry-states.json) |
| d186-compoundvisual-mill-complete | 5/5 | [manifest](raw/d186-compoundvisual-mill-complete-manifest.json), [states](visual/d186-compoundvisual-mill-complete-states.json) |

Native commands granted only additional write access to `/home/agent/logs/lua`. The raw files have no host-log permission failure. Historical raw files were not modified.

## Blocking defect and excluded results

`d186-woodrack` and `d186-woodrack-diagnostic` each finished FAIL, 7/9. They reproduce **one defect**, not two: a genuine ordinary carrier in `sitePickup.phase=approach` cannot reload its save. SaveData line327 compares recomputed private target coordinates with exact equality. After native cjson roundtrip, recomputed target y is `3.8916666666666666`, persisted target y is `3.8916666666666671` (one ULP); x agrees at `3.8875000000000002`. The product rejects `private pickup destination` before the test's own comparison. [Failed real save](d186-woodrack-diagnostic-failed-save.json), [diagnostic raw](raw/d186-woodrack-diagnostic-raw.log). Proposed production tolerance is still a future-candidate change, not a d186 pass.

`d186-compoundvisual-mill` exhausted an experimental 1800-frame budget. The launcher automatically wrote PASS1/1, but there is no complete artifact or complete five-assertion denominator. **Excluded.** The later `mill-complete` run naturally reached every required phase, explicitly finished at frame1957 and retained47 screenshots; it did not reset a phase, worker, ingredient or timer to pass.

## Direct native visual assessment

QA actually opened all four overviews plus natural work/stack/stow and ordinary pickup originals. Designer independently reviewed the four compositions and accepted their smaller integrated courtyards; root independently opened wood stack/pickup, fish overview, quarry rail and HUD.

- **Woodcutter:** [overview](visual/d186-compoundvisual-woodcutter-overview-1.png), [real stack](visual/d186-compoundvisual-woodcutter-stack-2.png), [ordinary pickup](visual/d186-compoundvisual-woodcutter-carrier-picked-2.png). The physical rack is now on the small front platform. The logger stacks at `(3.8875,3.8916666667)` at23.9s, still holding rawwood and not stocked; the ordinary carrier later loads at that same contact at36.7s with a visible `pickup` projection and `cargo=rawwood`. This closes the previous empty-door drop/hidden-carrier visual gap **without claiming mid-trip save safety**.
- **Fishery:** [overview](visual/d186-compoundvisual-fishery-overview-1.png), [side stow](visual/d186-compoundvisual-fishery-stow-2.png). Compact front deck joins the house, tank and rocker; the eastern finger extends to the water edge. Side stow remains visible. This is the actual east-bank fixture, not evidence for the separately identified south-bank deck-foot bounds issue.
- **Quarry:** [initialized cave](visual/d186-compoundvisual-quarry-rest-2.png), [rail out](visual/d186-compoundvisual-quarry-rideOut-2.png), [ordinary pickup](visual/d186-compoundvisual-quarry-carrier-picked-2.png). The rail reaches the registered cave mouth. The source decoration uses natural pixel rocks/mineral marks rather than the former large geometric marker over the public road. At71.2s the loaded miner rides out; at74.8s stow takes place at `(0.8875,12.2916666667)`; at88.6s the ordinary carrier visibly picks up rawstone there. The t0 overview still shows the pre-initialized rock-filled building image; the first normal tick selects the actual cave image, so inspection uses the initialized and real-cycle images too.
- **Mill:** [overview](visual/d186-compoundvisual-mill-complete-overview-1.png), [work](visual/d186-compoundvisual-mill-complete-work-2.png), [stow](visual/d186-compoundvisual-mill-complete-stow-2.png). Smaller irregular front ground groups the real low millstone and storage basket with the house. Worker hand contact and actual side-basket stow are visible. The original large millstone remains in the building illustration; the designer judged the current composition acceptable, while the functional device is the small outdoor station.

These images are controlled construction/material fixtures with natural actors, routes, production and hauling. They do not establish earned construction, a full-village layout, all orientations, long-term economic stability or a physical phone result.

## Player-accessible safe upgrade

The API group checks stopped/unstaffed prerequisites, rejection without persistent mutations, successful same-anchor upgrade, exact stock/roads/population/jobs/actors preservation, save/load and repeat rejection. Its success fixture is explicitly a synthetic schema8 save with absent sites; authentic historical schema8 already-carried jobs separately verify refusal.

The 844×390 HUD group uses **actual map touch, real drawer swipes and hit-test-coordinate button touches**. The first touch rejects a running mill and shows stop-work guidance. After a normal public `setWorking(false)` operation (not a fake button), the second actual upgrade-button touch succeeds. It never directly calls upgradeCompound. [Before button](visual/d186-upgrade-hud-before-busy-touch.png), [busy feedback](visual/d186-upgrade-hud-busy-reason.png), [success](visual/d186-upgrade-hud-success.png). The obsolete button disappears, stock/roads/population remain unchanged and the upgraded site reloads.

## Next gate

Root/developer will apply the minimal SaveData coordinate fix and a separate south-bank deck-foot rendering trim. Re-run the complete wood-rack phase-save test and relevant save/terrain/rail checks under the new frozen hash. Use an exact reverse source bridge to inherit unaffected d186 visuals, while explicitly excluding the changed southern deck edge. No whole-game percentage or military/old R02 acceptance is claimed.
