import io
import json
import os
import sys

src = sys.argv[1]
out = sys.argv[2]
fails = []
cur = {}
counts = {'success': 0, 'failure': 0, 'error': 0}
errs = {}
with io.open(src, encoding='utf-8', errors='replace') as fh:
    for line in fh:
        line = line.strip()
        if not line.startswith('{'):
            continue
        try:
            ev = json.loads(line)
        except Exception:
            continue
        t = ev.get('type')
        if t == 'testStart':
            cur[ev['test']['id']] = ev['test'].get('name', '?')
        elif t == 'error':
            errs[ev.get('testID')] = ev.get('error', '')
        elif t == 'testDone':
            if ev.get('hidden'):
                continue
            res = ev.get('result')
            counts[res] = counts.get(res, 0) + 1
            if res != 'success':
                fails.append((cur.get(ev['testID'], '?'), errs.get(ev.get('testID'), '')))

with io.open(out, 'w', encoding='utf-8') as fh:
    fh.write('ok=%d fail=%d err=%d\n' % (
        counts.get('success', 0), counts.get('failure', 0), counts.get('error', 0)))
    for name, msg in fails:
        fh.write('FAIL: %s\n' % name[:150])
        for ln in (msg or '').splitlines()[:14]:
            fh.write('    %s\n' % ln[:180])
        fh.write('\n')
print('отчёт: %s' % out)
