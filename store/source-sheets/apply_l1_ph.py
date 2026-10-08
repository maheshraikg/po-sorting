"""Apply the Karnataka Revised L1 PH sheet to the default scheme (Non-TD bag
rules) and the default air codes. Usage: apply.py SPEC REPO [--write]"""
import csv, io, re, sys, collections
spec_path, repo = sys.argv[1], sys.argv[2]
write = '--write' in sys.argv
D = repo + '/assets/schemes/'
REM = ''

entries = []  # (bag, air, state, kind, a, b)  kind P=prefix E=exact R=6-digit range
for line in open(spec_path, encoding='utf-8'):
    line = line.strip()
    if not line or line.startswith('#'): continue
    bag, air, state, series = line.split('|')
    for part in [x.strip() for x in series.split(',') if x.strip()]:
        m = re.fullmatch(r'(\d+)-(\d+)', part)
        if m and len(m.group(1)) == 6:
            entries.append((bag, air, state, 'R', m.group(1), m.group(2))); continue
        if m:
            lo, hi = m.group(1), m.group(2)
            assert len(lo) == len(hi), part
            keys = [str(i).zfill(len(lo)) for i in range(int(lo), int(hi) + 1)]
        else:
            keys = [part]
        for k in keys:
            assert len(k) in (3, 4, 6), (bag, k)
            entries.append((bag, air, state, 'E' if len(k) == 6 else 'P', k, None))

# Same key claimed by two bags at the same specificity.
by_key = collections.defaultdict(list)
for e in entries: by_key[(e[3], e[4], e[5])].append(e)
conflicts = {k: v for k, v in by_key.items() if len({x[0] for x in v}) > 1}

lines = open(D + 'mangaluru_default.csv', encoding='utf-8-sig').read().splitlines()
rows = list(csv.reader(lines))
H = rows[0]; I = {h: i for i, h in enumerate(H)}
body = rows[1:]
def nt(r): return r[I['Category']] == 'Non-TD'
def key(r):
    t = r[0].lower()
    if t == 'prefix': return ('P', r[I['Prefix']], None)
    if t in ('pin', 'exact'): return ('E', r[I['PIN']], None)
    if t == 'range': return ('R', r[I['PIN From']], r[I['PIN To']])
    return (t, None, None)
old = [r for r in body if nt(r)]
old_by_key = {key(r): r for r in old}
bag_meta = {}
for r in old: bag_meta.setdefault(r[I['Bag No']], (r[I['Bag Name']], r[I['Colour']]))

def covers(k, sheet_prefixes):
    kind, a, b = k
    if a is None: return False
    return any(a.startswith(p) for p in sheet_prefixes) if kind != 'R' else any(a.startswith(p) and b.startswith(p) for p in sheet_prefixes)
sheet_prefixes = {e[4] for e in entries if e[3] == 'P'} | {e[4][:3] for e in entries if e[3] != 'P'}
# keep: Non-TD rules outside every series the sheet lists, and the rule
# currently used for each equal-specificity conflict (resolved below).
kept, dropped, decided, also = [], [], {}, {}
for k, v in conflicts.items():
    names = list(dict.fromkeys(x[0] for x in v))
    decided[k] = names[0]  # first hub listed on the sheet
    codes = {x[0]: x[1] for x in v}
    also[k] = [f"{n} ({codes[n] or 'no air code'})" for n in names[1:]]
for r in old:
    k = key(r)
    if k[0] == 'prefix' or k[1] is None or (k[0] == 'P' and len(k[1]) < 3):
        kept.append(r); continue
    if covers(k, sheet_prefixes): dropped.append(r)
    else: kept.append(r)

MERGED = {'AGARTALA': 'SILCHAR', 'AIZWAL': 'SILCHAR', 'BERHAMPUR': 'BHUBANESWAR', 'SAMBALPUR': 'BHUBANESWAR', 'DEOGARH': 'RANCHI',
          'JAMSHEDPUR': 'RANCHI', 'DIBRUGARH': 'GUWAHATI', 'DIMPUR': 'GUWAHATI', 'ITANAGAR': 'GUWAHATI', 'SHILLONG': 'GUWAHATI',
          'GORAKHPUR': 'LUCKNOW', 'KANNUR': 'KOZHIKODE', 'LEH': 'DELHI', 'MARGAON': 'MUMBAI', 'PARWANOO': 'SHIMLA',
          'TRICHY': 'CHENNAI', 'VADODARA': 'AHMEDABAD', 'AJMER': 'JAIPUR', 'MUZAFFARPUR': 'PATNA'}
for r in kept:
    b = r[I['Bag No']]
    if b in MERGED:
        nb = MERGED[b]
        r[I['Bag No']] = nb
        r[I['Bag Name']], r[I['Colour']] = bag_meta.get(nb, (r[I['Bag Name']], r[I['Colour']]))
        r[I['Remarks']] = (r[I['Remarks']] + '; ' if r[I['Remarks']] else '') + f'{b} merged into {nb} ({REM})'
new_rules = []
seen = set()
for bag, air, state, kind, a, b in entries:
    k = (kind, a, b)
    if k in decided and decided[k] != bag: continue
    if k in seen: continue
    seen.add(k)
    name, colour = bag_meta.get(bag, (state, ''))
    if bag == 'ARMY POST (APS)': name, colour = bag_meta[bag]
    n = [''] * len(H)
    n[0] = {'P': 'Prefix', 'E': 'PIN', 'R': 'Range'}[kind]
    if kind == 'P': n[I['Prefix']] = a
    elif kind == 'E': n[I['PIN']] = a
    else: n[I['PIN From']], n[I['PIN To']] = a, b
    n[I['Bag No']] = bag; n[I['Bag Name']] = name if bag in bag_meta else state
    n[I['Category']] = 'Non-TD'; n[I['Colour']] = colour
    n[I['Remarks']] = f"Sheet also lists {a} under: {', '.join(also[k])}" if k in also else REM
    new_rules.append(n)

# Report
oldbags = {r[I['Bag No']] for r in old}; newbags = {r[I['Bag No']] for r in new_rules} | {r[I['Bag No']] for r in kept}
print('rules: old Non-TD', len(old), '| dropped', len(dropped), '| kept (outside sheet)', len(kept), '| new', len(new_rules))
print('bags removed:', sorted(oldbags - newbags))
print('bags added:', sorted(newbags - oldbags))
print('conflicts (same key, same length):')
for k, v in sorted(conflicts.items()): print('  ', k[1], [x[0] for x in v], '->', decided[k])
print('kept outside sheet:', sorted({(r[0], r[I['Prefix']] or r[I['PIN']] or r[I['PIN From']], r[I['Bag No']]) for r in kept if not (r[0]=='Prefix' and len(r[I['Prefix']])<3)}))
# changes per prefix: compare resolution of every 3-digit prefix
def resolver(rs):
    ex, rg, pf = {}, [], {}
    for r in rs:
        t = r[0].lower()
        if t in ('pin','exact'): ex[r[I['PIN']]] = r[I['Bag No']]
        elif t == 'range': rg.append((int(r[I['PIN From']]), int(r[I['PIN To']]), r[I['Bag No']]))
        elif t == 'prefix': pf[r[I['Prefix']]] = r[I['Bag No']]
    def f(pin):
        if pin in ex: return ex[pin]
        for lo, hi, bg in sorted(rg, key=lambda x: x[1]-x[0]):
            if lo <= int(pin) <= hi: return bg
        for l in range(6, 0, -1):
            if pin[:l] in pf: return pf[pin[:l]]
        return None
    return f
fo, fn = resolver(old), resolver(kept + new_rules)
changes = collections.Counter()
for p4 in range(1100, 9000):
    pin = f'{p4}50'
    a, b = fo(pin), fn(pin)
    if a != b: changes[(str(p4)[:3], a, b)] += 1
agg = collections.defaultdict(list)
for (p3, a, b), n in sorted(changes.items()): agg[(a, b)].append(p3)
print('moved series (old bag -> new bag: 3-digit prefixes):')
for (a, b), ps in sorted(agg.items(), key=lambda x: str(x)): print('  ', a, '->', b, ':', ' '.join(sorted(set(ps))))

if write:
    out_rows = [H] + [r for r in body if not nt(r)] + kept + new_rules
    o = io.StringIO(); csv.writer(o, lineterminator='\n').writerows(out_rows)
    open(D + 'mangaluru_default.csv', 'w', encoding='utf-8-sig').write(o.getvalue())
    # air codes
    ah = 'Type,PIN,PIN From,PIN To,Prefix,District,State,Air Code,Station,Via,Remarks'.split(',')
    A = {h: i for i, h in enumerate(ah)}
    arows, seen = [ah], set()
    for bag, air, state, kind, a, b in entries:
        k = (kind, a, b)
        if k in decided and decided[k] != bag: continue
        if k in seen or bag == 'MANGALORE': continue  # own PH: no air code
        seen.add(k)
        n = [''] * len(ah)
        n[0] = {'P': 'Prefix', 'E': 'PIN', 'R': 'Range'}[kind]
        if kind == 'P': n[A['Prefix']] = a
        elif kind == 'E': n[A['PIN']] = a
        else: n[A['PIN From']], n[A['PIN To']] = a, b
        n[A['Air Code']] = air or 'NIL'
        st = bag
        if bag == 'ARMY POST (APS)': st = '1 CBPO (APS)' if a == '900056' else '2 CBPO (APS)'
        n[A['Station']] = st
        n[A['Remarks']] = f"Sheet also lists {a} under: {', '.join(also[k])}" if k in also else REM
        arows.append(n)
    o = io.StringIO(); csv.writer(o, lineterminator='\n').writerows(arows)
    open(D + 'mangaluru_air_codes.csv', 'w', encoding='utf-8').write(o.getvalue())
    print('written', len(out_rows) - 1, 'scheme rows,', len(arows) - 1, 'air rules')
