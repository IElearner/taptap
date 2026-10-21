"""Independent pixel QA native runner. Preserve raw errors, including ShaderError."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tests/v2/evidence/raw'
p = argparse.ArgumentParser()
p.add_argument('test')
p.add_argument('--run', required=True)
p.add_argument('--width', type=int, default=844)
p.add_argument('--height', type=int, default=390)
p.add_argument('--frames', type=int, default=65)
p.add_argument('--timeout', type=int, default=130)
a = p.parse_args()
assert a.run.replace('-', '').replace('_', '').isalnum()
OUT.mkdir(parents=True, exist_ok=True)
for folder in ['visual','construction']:
    (ROOT/'tests/v2/evidence'/folder).mkdir(parents=True, exist_ok=True)
report = OUT / (a.run + '-raw.json')
log = OUT / (a.run + '-raw.log')
assert not report.exists() and not log.exists(), 'Use a new --run ID; raw evidence must not be overwritten'
def digest():
    sources = sorted(list((ROOT / 'scripts').rglob('*.lua')) + [p for p in (ROOT / 'assets/art/pixel-v1').rglob('*') if p.is_file() and p.suffix in ('.png', '.json')] + list((ROOT / 'assets/Fonts').glob('FusionPixel*')))
    h = hashlib.sha256()
    for path in sources:
        h.update(str(path.relative_to(ROOT)).encode())
        h.update(path.read_bytes())
    return h.hexdigest()
before = digest()
env = os.environ.copy()
env.update(VILLAGE_SHADER_CACHE=str(ROOT / '.cli/ResCache'), LIBGL_ALWAYS_SOFTWARE='1', GALLIUM_DRIVER='llvmpipe', EGL_PLATFORM='surfaceless')
cmd = [str(ROOT / '.cli/UrhoXRuntime'), 'main.lua', f'-tapcode_dir={ROOT}', '-tool_mode', '-graphicssurfaceless', '-nosound', '-validate', f'-validate-frames={a.frames}', f'-validate-timeout={a.timeout-10}', '-validate-spike-threshold=1500', f'-validate-output={report}', f'-validate-test={ROOT/a.test}', f'-pixelqa-run={a.run}', '-x', str(a.width), '-y', str(a.height)]
with log.open('w') as stream:
    try:
        result = subprocess.run(cmd, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=a.timeout)
        code = result.returncode
    except subprocess.TimeoutExpired:
        code = 124
data = json.loads(report.read_text()) if report.exists() else {}
errors = [e for phase in data.get('phases', {}).values() for e in phase.get('errors', [])]
raw_lines = [line for line in log.read_text(errors='replace').splitlines() if any(term in line.lower() for term in ['shadererror', 'error:', 'failed to load', 'could not find resource'])]
record = {'run': a.run, 'test': a.test, 'viewport': [a.width, a.height], 'sourceBefore': before, 'sourceAfter': digest(), 'rawResult': data.get('result', 'NO_REPORT'), 'exitCode': code, 'assertions': data.get('test_assertions'), 'issues': data.get('test_issues'), 'rawErrors': errors, 'rawLogErrorLines': raw_lines, 'missing': data.get('missing_resources', []), 'report': str(report), 'log': str(log), 'phoneTested': False}
(OUT / (a.run + '-manifest.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2))
print(json.dumps(record, ensure_ascii=False), flush=True)
raise SystemExit(0 if code == 0 and data.get('result') == 'PASS' and not errors and not raw_lines else 1)
