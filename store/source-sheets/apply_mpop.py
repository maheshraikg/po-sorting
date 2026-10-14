"""Apply the MPOP parcel-hub rationalisation (Parcel Directorate letter
F.No. 39-04/2025-PD dated 24.09.2026, effective 07.10.2026) to the NPH table.

Each NPH row is "L1 PH / L2 PH" (or "L1 PH" alone); its last hub is the one
nearest to the PIN. That hub is looked up in the revised lists:
  - now an L1 hub (Annexure I)  -> row becomes "<L1>"
  - an L2 hub (Annexure II)     -> row becomes "<mapped L1> / <L2>"
  - not in either list          -> row kept, reported
Usage: python3 apply_mpop.py mpop.txt rms_nph.csv out.csv mpop_hubs.csv
"""
import csv, re, sys

txt, src, out, hubs_out = sys.argv[1:5]
lines = open(txt, encoding='utf-8').read().split('\n')

ALIAS = {
    'bangalore': 'bengaluru', 'hubballi': 'hubli', 'vishakhapatnam': 'visakhapatnam', 'bhubaneshwar': 'bhubaneswar',
    'chhatrapatisambhajinagar': 'csnagar', 'jhanshi': 'jhansi', 'mehasana': 'mehsana', 'devangere': 'davanagere',
    'tumakuru': 'tumkur', 'jajpurroad': 'jajpur', 'ananthapur': 'ananthpur', 'anantapur': 'ananthpur',
    'kannaur': 'kannur', 'jolarpettai': 'jolarpatti', 'jollarpettai': 'jolarpatti', 'vriddhachalam': 'vridhachalam',
    'mayiladuthurai': 'mayiladuuturai', 'nagercoil': 'nagarcoil', 'tiruchirappalli': 'trichy', 'kalaburagi': 'gulbarga',
    'belgaum': 'belagavi', 'mysore': 'mysuru', 'mangaluru': 'mangalore', 'hosapet': 'hosapete', 'davangere': 'davanagere',
    'rajahmundry': 'rajamundry', 'kadapa': 'cuddapah', 'bdeoghar': 'bdeoghar', 'deoghar': 'bdeoghar', 'portblair': 'portblair',
    'trivandrum': 'thiruvananthapuram', 'thiruvanathapuram': 'thiruvananthapuram', 'kozikode': 'kozhikode', 'calicut': 'kozhikode',
    'srigangangar': 'sriganganagar', 'bhatinda': 'bhatinda', 'bathinda': 'bhatinda', 'margao': 'margaon', 'madgaon': 'margaon',
    'berhamporewb': 'berhampore', 'meerutcantt': 'meerut', 'junagadh': 'junagarh', 'chandrapur': 'chandarpur', 'burdwan': 'burdwan',
    'bardhaman': 'burdwan', 'gurugram': 'gurgaon', 'prayagraj': 'prayagraj', 'allahabad': 'prayagraj', 'csn': 'csnagar',
    'tirupathi': 'tirupati', 'ahilyanagar': 'ahmednagar', 'ayodhya': 'faizabad', 'bilaspurchhattisgarh': 'bilaspur',
    'jeyporek': 'jeypore', 'mayiladuturai': 'mayiladuuturai', 'integratedampc': 'delhi', 'integratedparcelhubampc': 'delhi',
    'ampc': 'delhi', 'lucknowrms': 'lucknow',
}

def key(name):
    k = name.lower()
    k = re.sub(r'\b(l1|l2|n?ph|parcel hub|rms|nph|hub|cantt|wb|road)\b', ' ', k)
    k = re.sub(r'[^a-z0-9]', '', k)
    return ALIAS.get(k, k)

def section(title):
    i = next(n for n, l in enumerate(lines) if title in l)
    return lines[i + 1:]

l1 = {}
for l in section('Revised List of L1 Parcel Hubs'):
    if 'Annexure' in l: break
    m = re.match(r'\s*\d+\s+(.+?)\s*$', l)
    if not m or l.strip().startswith('S. No'): continue
    parts = m.group(1)
    # "Karnataka Mangalore": the last word(s) after the circle are the hub.
    for circle in sorted(CIRCLES := ['Andhra Pradesh','Assam','Bihar','Chhattisgarh','Delhi','Gujarat','Haryana','Himachal Pradesh',
            'Jammu & Kashmir','Jharkhand','Karnataka','Kerala','Madhya Pradesh','Maharashtra','North East','Orissa','Punjab','Rajasthan',
            'Tamil Nadu','Telangana','Uttar Pradesh','Uttarakhand','Uttara-khand','West Bengal','Odisha','Tamilnadu'], key=len, reverse=True):
        if parts.startswith(circle + ' '):
            hub = parts[len(circle) + 1:]; break
    else:
        circle, hub = '', parts
    l1[key(hub)] = (hub.strip().title() if hub.isupper() and not any(c.isdigit() for c in hub) else hub.strip(), circle)

l2 = {}
for l in section('Revised List of L2 Parcel Hubs'):
    if not l.strip(): continue
    if 'Annexure III' in l: break
    m = re.match(r'\s*\d+\s+(.+?)\s*$', l)
    if not m: continue
    s = m.group(1)
    for circle in sorted(CIRCLES, key=len, reverse=True):
        if s.startswith(circle + ' '):
            rest = s[len(circle) + 1:]; break
    else:
        continue
    # "<L2 hub> <Mapped L1>": the mapped L1 is the longest known L1 at the end.
    words = rest.split()
    for n in range(len(words) - 1, 0, -1):
        if key(' '.join(words[n:])) in l1:
            l2[key(' '.join(words[:n]))] = (' '.join(words[:n]), key(' '.join(words[n:])), circle)
            break
    else:
        print('L2 parse?', rest)

direct = []
for l in section('L2 Hubs Authorized for Direct Bag Closure'):
    m = re.match(r'\s*(\d+)\s+(.+)$', l)
    if m and int(m.group(1)) <= 52:
        direct.append(m.group(2).strip())
    elif direct and l.strip() and not l.strip().startswith('No.'):
        direct[-1] += ' ' + l.strip()

print(len(l1), 'L1,', len(l2), 'L2,', len(direct), 'direct')

rows = list(csv.reader(open(src, encoding='utf-8-sig')))
head, body = rows[0], rows[1:]
# Existing display spellings for L1 hubs ("Bengaluru Parcel Hub", "KOLKATA PH").
spell = {}
for r in body:
    segs = [s.strip() for s in r[0].split('/')]
    if len(segs) == 1: spell.setdefault(key(segs[0]), segs[0])
def l1name(k):
    return spell.get(k, l1[k][0] + ' PH')

changed, kept = 0, []
out_rows = [head]
for r in body:
    segs = [s.strip() for s in r[0].split('/')]
    last = key(segs[-1])
    if last in l1:
        new = l1name(last)
    elif last in l2:
        # "L1 PH B.Deoghar" is an L2 hub now: "B.Deoghar PH".
        l2name = re.sub(r'^L1 (PH|Parcel Hub) (.+)$', r'\2 PH', segs[-1])
        new = f'{l1name(l2[last][1])} / {l2name}'
    else:
        new = r[0]; kept.append(r[0])
    if new != r[0]:
        changed += 1
        print(f'  {r[0]}  ->  {new}')
    out_rows.append([new] + r[1:])
# Rows that now have the same hub: merge their PIN series.
merged = {}
for r in out_rows[1:]:
    if r[0] in merged:
        m = merged[r[0]]
        m[3] = ', '.join(x for x in [m[3], r[3]] if x)
    else:
        merged[r[0]] = list(r)
with open(out, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, lineterminator='\n'); w.writerow(head); w.writerows(merged.values())
print('changed', changed, 'merged rows', len(out_rows) - 1 - len(merged), 'kept (not in circular):', kept)

with open(hubs_out, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, lineterminator='\n')
    w.writerow(['Level', 'Circle', 'Hub', 'Mapped L1', 'Direct bag closure to'])
    dmap = {}
    for d in direct:
        for circle in sorted(CIRCLES, key=len, reverse=True):
            if d.startswith(circle + ' '):
                rest = d[len(circle) + 1:]; break
        else: continue
        hub, _, to = rest.partition(' ')
        if rest.startswith('B.Deoghar') or rest.startswith('Sri '): hub, to = rest.split(' ', 1)
        dmap[key(hub)] = to.strip()
    for k, (name, circle) in l1.items(): w.writerow(['L1', circle, name, '', dmap.pop(k, '')])
    for k, (name, mk, circle) in l2.items():
        w.writerow(['L2', circle, name, l1[mk][0], dmap.pop(k, '')])
    for k, to in dmap.items(): print('direct w/o L2 row:', k, to)
