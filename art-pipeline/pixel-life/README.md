# Life interaction artwork

Original OpenAI image generation was explicitly authorized by the user after the Maker art service failed. `sources/` retains the full generated source images; no original v1/v3 runtime textures are overwritten.

Run `python art-pipeline/pixel-life/import_assets.py` from any directory to reproduce nearest-neighbour crops and atlas registration. `import-records.json` and runtime `life/life-import.json` record source regions, scale, cell dimensions and anchors. Actor bodies retain the existing approximately 22–24 pixel height; 80×72 cells provide padding for rods and contact poses.

Atlases use four columns. Fisher actions: rest, rise, cast, reel, stow. Additional direction rows: cast-N, reel-N, wait-N, cast-S, reel-S, wait-S. Direction names are candidates until verified against a real shore in the engine. Props: rocking chair; fish tank 0/1/3/5; cart empty/rider/stone/gold; rails/rails/curve/shaft; workbench empty/rough/half/cut. Stock display must round down by true stored inventory, with exact quantity in UI. It must not create decorative fish or stone products.

Contact points must be reviewed in the engine: a common foot anchor is not sufficient to seat a figure on a chair. Clean workshop/mine backgrounds remove baked carts and product piles; dynamic props must follow actual work phase and inventory. Outer structure bounds are registered to the old 256×224 canvas; doorway contact still requires native verification.

Metadata UUIDs are generated only by Maker's official `generate_resource_meta` tool after the code/assets batch is ready.

The replacement `fisher-rocker.png` / `rocker-empty.png` pair has four matched 80×72 frames with floor anchor (40,64). The occupied artwork contains the reclining figure and chair, so the renderer must suppress a second chair and actor layer. The original separate sitting experiment remains provenance, not the final resting pose.

`chef-lean.png` has four 40×48 frames anchored at (20,44); its actual body is 24px high. Wall contact must be checked in the native kitchen scene.

`fisher-vertical.png` supersedes the lateral-looking N/S experiment. It uses 80×128 frames, the same foot (40,64), and six rows cast-N/reel-N/wait-N/cast-S/reel-S/wait-S. The extra canvas retains complete vertical rods. South/east/west casting also requires an actual safe bank-edge approach, not a display-only character shift. Hook positions must be verified against rendered water.

Workshop candidates are reproduced by `import_workshops.py`. Its default output is a work staging directory, so generating candidates cannot change an active QA source freeze. During the next authorized asset window, pass `--output` for the runtime life directory. Miller, baker and butcher each have eight rows (idle/prepare/work/finish for both retained original worker appearances); carpenter, smith and leatherworker each have four rows. All use 80×72 cells with (40,64) foot anchors and standing-equivalent 24px bodies. Finished product pixels may only appear after a real completed recipe; role mother animations must not invent finished bows, spears or armor. Native contact review is mandatory.

Independent low outdoor stations are packed by `import_ground_props.py`: hand mill, kneading board, chopping block, sawhorses; cold forge/anvil, scraping bench, empty output rack and steps. `ground-props-import.json` records registration and provisional pixel contact points. All eight source props are empty: flame, grain, dough, timber, hides, ingots and finished goods must be drawn from actual simulation state. Ground and hand-contact placement still requires native checks.
