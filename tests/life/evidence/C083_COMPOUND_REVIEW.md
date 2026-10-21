# C083 integrated-building QA — sealed, visual revision required

Production `c083700670e9bc548eacc26ff97ecd910292142c1c85aaf12602dad4c41aaeb8`, 192 files, schema11. Root/developer held production and assets unchanged throughout these runs. Native ownership was released after all four visual runs exited. This scope concerns integrated buildings, attached work areas and terrain; it does not reopen military or claim economic endurance/whole-game95.

## Independent executable evidence

Seven final runs total **430/430 assertions, raw PASS**, with stable source, helpers and fixtures within each run. Each has a written `complete=true` artifact and an explicit test-finish marker before the runtime end. [Index](C083_COMPOUND_RUN_INDEX.json) records exact manifests and excludes superseded diagnostics.

| Run | Assertions | Scope |
|---|---:|---|
| `c083-compound-model-final` | 336 | Seventeen profession/building compounds, actual canBuild/build and preview identity, rounded ownership/public door, bounds/access, resource identity, JSON, authentic old loaded carriers |
| `c083-compound-terrain` | 22 | Positive real source placement, inaccessible mature-tree boundary, dry reachable shore, depleted source identity |
| `c083-compound-rail` | 52 | Four real mine/cart cycles on shared rail geometry, phase JSON, natural load, safe stop and single delivery with finite-resource conservation |
| `c083-compoundvisual-fishery` | 5 | Actual rest/shore/catch/side stow/ordinary pickup, fixed building camera |
| `c083-compoundvisual-quarry` | 5 | Actual cart/mine/loaded return/stow/ordinary pickup |
| `c083-compoundvisual-mill` | 5 | Actual work/held product/stow/ordinary pickup |
| `c083-compoundvisual-woodcutter` | 5 | Actual chop/carry/stack/picked-up job; visible contact limitations below |

Native logging used narrowly authorized write access to `/home/agent/logs/lua`. Material stock, initial recipe inputs, completed buildings and connecting roads were declared test scaffolding. No actor phase, load, site or production commit was assigned to manufacture an animation. These runs do **not** verify earned construction labor, a full25-building layout under the new plot rules, housing/food sustainability, or physical-phone behavior.

Initial `compound-model` and `compound-model-diagnostic` each retained 335/336. The sole difference was an iron-mine door-coordinate JSON roundtrip: `3.416666666666667` versus `3.4166666666666665`, delta `4.44e-16`. The final comparator permits `1e-9` only for recursive `x`/`y`; every other numeric field uses exact equality. The intermediate broader comparator run is superseded, not added to the accepted count. Material payment and resource-conservation assertions use exact equality throughout.

## Actual visual review

QA opened all four overviews and representative rest/work/carry/stow frames. Designer independently reviewed the four overviews and relevant stages. Model assertions do not supersede the following image findings.

- **Fishery:** house, tank and rocker share a continuous platform. Actual side stow is visible: at t76.8 the worker is `(13.8875,7.2916667)`, tank `(14.2,7.25)`, `life.load=fish2`, output buffer still0. The later carrier uses the same side contact. Rest and cast/wait remain readable. The large regular full rectangular deck still has a conspicuous carpet-like composition; integrated visual design is not signed merely because bounds contain the props.
- **Quarry:** actual cart wheels follow the continuous short rail into the registered opening, and the worker unloads on the same stone forecourt. However the visible source outcrop `(4,11)` is drawn over a public stone-road tile. A logical source binding plus a geometric marker on a road is not accepted as natural rock/mine integration. Initial t0 overview uses the pre-Life closed-rock building asset; after the first ordinary update the open-mouth asset is used. Review actual cycle frames, not that initial frame alone.
- **Mill:** real hand contact with the low outdoor mill and product placement are visible. The building art also contains a separate large millstone; this and the flat rectangular earth patch leave the equipment visually scattered. QA flags composition for revision, while the actual work/output chain passes its declared executable checks.
- **Woodcutter:** trees are genuinely approached and chopped. At `stack-2`, t22.1, the worker is at `(6,4)`, the public door, holding rawwood with `stockedLoad=false`. It places wood on the empty right side of the platform, away from the timber rack/bench painted into the building at the left. The generic compound has no rack/storage contact point. `carrier-picked-2` has `projection=nil` during legacy doorway packing: a real picked-up job exists, but this frame does not show a visible worker taking wood from the rack. A platform alone has not integrated the timber handling interaction. The large regular wooden deck also retains the carpet-like appearance noted by design.

Representative originals:

- [Fish overview](visual/c083-compoundvisual-fishery-overview-1.png), [rest](visual/c083-compoundvisual-fishery-rest-2.png), [side stow](visual/c083-compoundvisual-fishery-stow-2.png).
- [Quarry overview](visual/c083-compoundvisual-quarry-overview-1.png), [cart entering](visual/c083-compoundvisual-quarry-rideIn-2.png), [stow](visual/c083-compoundvisual-quarry-stow-2.png).
- [Mill overview](visual/c083-compoundvisual-mill-overview-1.png), [work](visual/c083-compoundvisual-mill-work-2.png), [stow](visual/c083-compoundvisual-mill-stow-2.png).
- [Logger overview](visual/c083-compoundvisual-woodcutter-overview-1.png), [chop](visual/c083-compoundvisual-woodcutter-chop-2.png), [stack](visual/c083-compoundvisual-woodcutter-stack-2.png), [hidden pickup phase](visual/c083-compoundvisual-woodcutter-carrier-picked-2.png).

All prefixes have matching `-states.json` containing full phase snapshots and trace. Do not count a screenshot label as proof that its actor is visible.

## Next independent gates

Revise the forecourt composition and geological presentation, and bind the logger's real storage/ordinary pickup to a visible physical rack. Preserve source identity/reserves, old site/path/load compatibility, real movement and one-time stow/take semantics. A future safe-reorganization UI must be tested separately once implemented; current tests do not invent demolition/refund support. Re-record affected real scenes on the next frozen hash, with only explicitly unaffected evidence bridged. No further native work is authorized in this released window.
