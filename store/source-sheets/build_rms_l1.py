"""Builds assets/schemes/rms_l1.csv and rms_nph.csv from the MR RMS sorting
data (one row per office: Pincode, Office, Type, Circle, NPH, NSH, RMS L1).
Each L1 / NPH gets the shortest PIN series that reproduces it exactly for
every PIN in the data (3-, 4-, 5-digit prefixes or single PINs)."""
import json, collections, csv, io, sys
rows = json.load(open(sys.argv[1]))
out_dir = sys.argv[2]
per = {}
circle = collections.defaultdict(collections.Counter)
for r in rows:
    per[r[0]] = r
def tidy(s):
    return ' '.join(s.split())
def build(col, kind, fname):
    val = {p: tidy(r[col]) for p, r in per.items() if p.isdigit() and len(p) == 6}
    groups = collections.defaultdict(list)
    for p, v in val.items():
        if v: groups[v].append(p)
    circ = collections.defaultdict(collections.Counter)
    for p, r in per.items():
        v = tidy(r[col])
        if v: circ[v][r[3]] += 1
    # values per prefix (including blank)
    pre = {n: collections.defaultdict(set) for n in (3, 4, 5)}
    for p, v in val.items():
        for n in (3, 4, 5): pre[n][p[:n]].add(v)
    out = []
    for name in sorted(groups):
        pins = sorted(groups[name]); covered = set(); parts = []
        for n in (3, 4, 5):
            for pf in sorted({p[:n] for p in pins if p not in covered}):
                if pre[n][pf] == {name}:
                    parts.append(pf); covered |= {p for p in pins if p.startswith(pf)}
        parts += [p for p in pins if p not in covered]
        # merge consecutive same-length numbers into ranges
        def merge(items):
            byl = collections.defaultdict(list)
            for x in items: byl[len(x)].append(int(x))
            res = []
            for l in sorted(byl):
                v = sorted(set(byl[l])); a = 0
                while a < len(v):
                    b = a
                    while b + 1 < len(v) and v[b + 1] == v[b] + 1: b += 1
                    f = lambda x: str(x).zfill(l)
                    res.append(f(v[a]) if a == b else f'{f(v[a])}-{f(v[b])}')
                    a = b + 1
            return res
        out.append((name, kind, circ[name].most_common(1)[0][0], ', '.join(merge(parts))))
    o = io.StringIO(); w = csv.writer(o, lineterminator='\n')
    w.writerow(['Hub', 'Kind', 'Circle', 'Series', 'Mapped To', 'Exclude'])
    for name, k, c, s in out: w.writerow([name, k, c, s, '', ''])
    open(f'{out_dir}/{fname}', 'w', encoding='utf-8').write(o.getvalue())
    print(fname, len(out), 'groups', len(o.getvalue()) // 1024, 'KB', 'pins', len(val), 'with value', sum(1 for v in val.values() if v))
    return val
l1 = build(6, 'L1', 'rms_l1.csv')
nph = build(4, 'NPH', 'rms_nph.csv')
nsh = build(5, 'NSH', 'rms_nsh.csv')
