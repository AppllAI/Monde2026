#!/usr/bin/env python3
"""
Construit Resources/map.bin à partir de Natural Earth (domaine public).

- Régions = subdivisions administratives réelles (états, oblasts, régions…),
  regroupées pour obtenir un nombre de régions proportionné à la taille du pays.
- Pour chaque région : pays, nom, point d'étiquette, superficie, contours, voisins.
- Frontières partagées entre régions (pour dessiner frontières et lignes de front).

Format binaire (petit-boutiste) :
  "MAP2"
  u32 nombre de régions
  pour chaque région :
     3 octets code pays, chaîne nom, chaîne nom du pays,
     f32 lat étiquette, f32 lon étiquette, f32 superficie km²,
     u16 nombre d'anneaux ; pour chaque anneau : u32 n, n × (f32 lon, f32 lat)
     u16 nombre de voisins, u16 × voisins
  u32 nombre de frontières
  pour chaque frontière : u16 a, u16 b, u16 nombre de lignes ;
     pour chaque ligne : u32 n, n × (f32 lon, f32 lat)
  chaîne = u16 longueur + UTF-8
"""
import json, math, re, struct, sys, glob, os
from collections import defaultdict

from shapely.geometry import shape, Polygon, MultiPolygon, LineString, MultiLineString, GeometryCollection
from shapely.ops import unary_union, linemerge
from shapely.strtree import STRtree
try:
    from shapely.ops import polylabel
except ImportError:
    polylabel = None

SRC = sys.argv[1]
OUT = sys.argv[2]
REPORT = sys.argv[3]

# Pays du jeu (lus dans le code Swift).
game = set()
for path in glob.glob("Monde2026/WorldData*.swift"):
    for m in re.finditer(r'c\("([A-Z]{3})"', open(path, encoding="utf-8").read()):
        game.add(m.group(1))
print("pays du jeu :", len(game))

# Codes Natural Earth -> codes du jeu (territoires rattachés à leur État).
ALIAS = {
    "KOS": "XKX", "SDS": "SSD", "SOL": "SOM", "CYN": "CYP", "GRL": "DNK", "FRO": "DNK",
    "KAB": "KAZ", "ALD": "FIN", "PRI": "USA", "GUM": "USA", "VIR": "USA", "HKG": "CHN", "MAC": "CHN",
    "NCL": "FRA", "PYF": "FRA", "SPM": "FRA", "WLF": "FRA", "BLM": "FRA", "MAF": "FRA",
    "JEY": "GBR", "GGY": "GBR", "IMN": "GBR", "FLK": "GBR", "BMU": "GBR", "CYM": "GBR", "TCA": "GBR",
    "AIA": "GBR", "VGB": "GBR", "MSR": "GBR", "SHN": "GBR", "SGS": "GBR", "IOT": "GBR", "GIB": "GBR",
    "ABW": "NLD", "CUW": "NLD", "SXM": "NLD", "ASM": "USA", "MNP": "USA", "UMI": "USA",
    "NFK": "AUS", "HMD": "AUS", "COK": "NZL", "NIU": "NZL", "ATF": "FRA", "SJM": "NOR", "BVT": "NOR",
    "USG": "CUB", "ESB": "CYP", "WSB": "CYP", "PGA": "CHN", "SCR": "CHN", "SER": "COL", "BJN": "COL",
    "IOA": "AUS", "CSI": "AUS", "CLP": "FRA", "BRI": "IND", "KAS": "IND", "CNM": "CYP",
}
SKIP = {"ATA"}

# Régions rattachées de jure à un autre État que dans les données (le jeu gère l'occupation lui-même).
DE_JURE = {"crimea": "UKR", "sevastopol": "UKR", "sébastopol": "UKR", "krym": "UKR"}

# Régions qui ne doivent jamais être fusionnées (lieux clés de conflits).
PROTECTED = ["crimea", "crimée", "krym", "donetsk", "luhansk", "lugansk", "lougansk", "zaporizh", "zaporij", "kherson",
             "abkhaz", "nistr", "transnistr", "northern cyprus", "chypre du nord", "taiwan", "kashmir", "cachemire",
             "golan", "quneitra", "kosovo"]

NEUTRAL_FR = {
    "AND": "Andorre", "ATG": "Antigua-et-Barbuda", "BHS": "Bahamas", "BLZ": "Belize", "BRB": "Barbade",
    "BRN": "Brunei", "BTN": "Bhoutan", "COM": "Comores", "CPV": "Cap-Vert", "DMA": "Dominique",
    "FSM": "Micronésie", "GMB": "Gambie", "GNB": "Guinée-Bissau", "GNQ": "Guinée équatoriale", "GRD": "Grenade",
    "KIR": "Kiribati", "KNA": "Saint-Christophe", "LBR": "Liberia", "LCA": "Sainte-Lucie", "LIE": "Liechtenstein",
    "LSO": "Lesotho", "MCO": "Monaco", "MDV": "Maldives", "MHL": "Îles Marshall", "MLT": "Malte", "MUS": "Maurice",
    "NRU": "Nauru", "PLW": "Palaos", "PSX": "Palestine", "SAH": "Sahara occidental", "SLB": "Îles Salomon",
    "SLE": "Sierra Leone", "SMR": "Saint-Marin", "STP": "Sao Tomé-et-Principe", "SWZ": "Eswatini",
    "SYC": "Seychelles", "TLS": "Timor oriental", "TON": "Tonga", "TTO": "Trinité-et-Tobago", "TUV": "Tuvalu",
    "VAT": "Vatican", "VCT": "Saint-Vincent", "VUT": "Vanuatu", "WSM": "Samoa", "PCN": "Pitcairn",
    "ATC": "Ashmore-et-Cartier",
}

PREFIXES = ["oblast de ", "oblast d'", "kraï de ", "kraï du ", "république de ", "république des ", "république du ",
            "république d'", "province de ", "province du ", "province d'", "région de ", "région du ", "région d'",
            "gouvernorat de ", "gouvernorat d'", "état de ", "état du ", "état d'", "de la ", "de l'", "du ", "des ", "de ",
            "d'", "l'", "la ", "le "]

def clean(name):
    n = name.strip().replace(" S.A.R.", "").replace(" S.A.R", "")
    changed = True
    while changed:
        changed = False
        for pre in PREFIXES:
            if n.lower().startswith(pre) and len(n) > len(pre) + 2:
                n = n[len(pre):]
                changed = True
    return n[:1].upper() + n[1:] if n else name

def code_for(props):
    a3 = props.get("adm0_a3") or props.get("ADM0_A3") or ""
    raw = " ".join(str(props.get(k) or "") for k in ("name", "name_en", "name_fr")).lower()
    for key, target in DE_JURE.items():
        if key in raw and target in game:
            return target
    if a3 in SKIP:
        return None
    if a3 in game:
        return a3
    if a3 in ALIAS:
        return ALIAS[a3]
    return a3  # pays neutre (non jouable)

def name_for(props):
    for key in ("name_fr", "name", "name_en", "gn_name", "woe_name", "name_local"):
        v = props.get(key)
        if v:
            return clean(v)
    return "?"

# ----------------------------------------------------------------- lecture
data = json.load(open(SRC, encoding="utf-8"))
units = defaultdict(list)          # pays -> [ {geom, name, region, area} ]
country_names = {}
for f in data["features"]:
    p = f["properties"]
    code = code_for(p)
    if not code:
        continue
    try:
        g = shape(f["geometry"])
    except Exception:
        continue
    if g.is_empty:
        continue
    if not g.is_valid:
        g = g.buffer(0)
    lat = g.centroid.y
    area = g.area * (111.32 ** 2) * max(0.05, math.cos(math.radians(lat)))
    a3 = p.get("adm0_a3") or ""
    region = (p.get("region") or "").strip()
    name = name_for(p)
    if code != a3 and code in DE_JURE.values() and a3 not in ALIAS:
        # Région rattachée de jure (Crimée, Sébastopol) : une seule région « Crimée ».
        region = "__crimee"
        name = "Crimée"
    elif a3 in ALIAS and ALIAS[a3] == code:
        # Territoire rattaché (Hong Kong, Groenland…) : une seule région à son nom.
        region = "__" + a3
        name = clean(NEUTRAL_FR.get(a3) or p.get("admin") or name)
    raw = " ".join(str(p.get(k) or "") for k in ("name", "name_en", "name_fr")).lower()
    protected = any(k in raw for k in PROTECTED)
    units[code].append({"geom": g, "name": name, "region": region, "area": area, "protected": protected})
    if code not in country_names:
        country_names[code] = NEUTRAL_FR.get(code) or (p.get("admin") or code)
print("pays trouvés :", len(units))

# ----------------------------------------------------------------- regroupement
def target_count(code, total_area, n_units):
    if code not in game:
        return 1
    t = round(math.sqrt(total_area) / 40)
    special = {"USA": 52, "RUS": 62, "CHN": 36, "IND": 32, "UKR": 25, "BRA": 27, "DEU": 16, "FRA": 18,
               "GBR": 14, "JPN": 16, "ITA": 20, "ESP": 17, "TUR": 20, "IRN": 18, "MEX": 26, "IDN": 22,
               "AUS": 10, "CAN": 14, "DNK": 4, "NLD": 6}
    t = special.get(code, t)
    return max(1, min(n_units, min(60, t)))

final = []   # dicts: code, name, geom, area
for code in sorted(units):
    items = units[code]
    total = sum(u["area"] for u in items)
    n_target = target_count(code, total, len(items))
    # groupes
    groups = {i: {"members": [i], "area": u["area"], "regions": {u["region"]}} for i, u in enumerate(items)}
    geoms = [u["geom"] for u in items]
    tree = STRtree(geoms)
    adj = defaultdict(set)
    for i, g in enumerate(geoms):
        for j in tree.query(g.buffer(0.02)):
            j = int(j)
            if j != i and geoms[j].distance(g) < 0.02:
                adj[i].add(j)
    owner = {i: i for i in range(len(items))}   # unité -> groupe
    def neighbors_of(gid):
        out = set()
        for m in groups[gid]["members"]:
            for j in adj[m]:
                h = owner[j]
                if h != gid:
                    out.add(h)
        return out
    def same_region_neighbors(gid):
        regs = groups[gid]["regions"] - {""}
        return {k for k in neighbors_of(gid) if (groups[k]["regions"] & regs) and not groups[k].get("protected")}
    for gid in groups:
        groups[gid]["protected"] = items[gid]["protected"]
    # Phase 1 : fusionner à l'intérieur des vraies régions (ex. départements -> régions françaises).
    while len(groups) > n_target:
        options = [k for k in groups if not groups[k]["protected"] and same_region_neighbors(k)]
        if not options:
            break
        gid = min(options, key=lambda k: groups[k]["area"])
        best = min(same_region_neighbors(gid), key=lambda k: groups[k]["area"])
        g1, g2 = groups[best], groups.pop(gid)
        g1["members"] += g2["members"]
        g1["area"] += g2["area"]
        g1["regions"] |= g2["regions"]
        for m in g2["members"]:
            owner[m] = best
    # Phase 2 : fusions libres entre voisins.
    while len(groups) > n_target:
        free = [k for k in groups if not groups[k]["protected"]]
        if not free:
            break
        gid = min(free, key=lambda k: groups[k]["area"])
        cand = {k for k in neighbors_of(gid) if not groups[k]["protected"]} or neighbors_of(gid)
        if not cand:
            # île : rattachée au groupe le plus proche
            c0 = unary_union([geoms[m] for m in groups[gid]["members"]]).centroid
            others = [k for k in groups if k != gid]
            if not others:
                break
            cand = {min(others, key=lambda k: geoms[groups[k]["members"][0]].centroid.distance(c0))}
        if not cand:
            break
        regs = groups[gid]["regions"]
        best = min(cand, key=lambda k: (0 if (groups[k]["regions"] & regs) - {""} else 1, groups[k]["area"]))
        g1, g2 = groups[best], groups.pop(gid)
        g1["members"] += g2["members"]
        g1["area"] += g2["area"]
        g1["regions"] |= g2["regions"]
        for m in g2["members"]:
            owner[m] = best
    region_sizes = defaultdict(int)
    for u in items:
        region_sizes[u["region"]] += 1
    for gid, g in groups.items():
        members = g["members"]
        geom = unary_union([geoms[m] for m in members])
        if not geom.is_valid:
            geom = geom.buffer(0)
        if code not in game:
            name = country_names.get(code, code)
        elif len(members) == 1:
            name = items[members[0]]["name"]
        else:
            regs = {items[m]["region"] for m in members}
            reg = next(iter(regs))
            if len(regs) == 1 and reg.startswith("__"):
                name = items[members[0]]["name"]
            elif len(regs) == 1 and reg and region_sizes[reg] == len(members):
                name = clean(reg)
            else:
                name = max((items[m] for m in members), key=lambda u: u["area"])["name"]
        final.append({"code": code, "name": name, "geom": geom, "area": g["area"],
                      "cname": country_names.get(code, code)})
print("régions :", len(final))

# ----------------------------------------------------------------- voisins et frontières
geoms = [f["geom"] for f in final]
tree = STRtree(geoms)
neighbors = defaultdict(set)
edges = []
for i, g in enumerate(geoms):
    for j in tree.query(g.buffer(0.03)):
        j = int(j)
        if j <= i:
            continue
        if geoms[j].distance(g) > 0.03:
            continue
        neighbors[i].add(j)
        neighbors[j].add(i)
        try:
            shared = g.boundary.intersection(geoms[j].buffer(0.02))
        except Exception:
            continue
        lines = []
        def collect(s):
            if s.is_empty:
                return
            if isinstance(s, LineString):
                lines.append(s)
            elif isinstance(s, (MultiLineString, GeometryCollection)):
                for part in s.geoms:
                    collect(part)
        collect(shared)
        if not lines:
            continue
        merged = linemerge(lines) if len(lines) > 1 else lines[0]
        parts = list(merged.geoms) if isinstance(merged, MultiLineString) else [merged]
        out = []
        for ln in parts:
            ln = ln.simplify(0.015)
            if ln.length < 0.02:
                continue
            out.append(list(ln.coords))
        if out:
            edges.append((i, j, out))
print("frontières :", len(edges))

# ----------------------------------------------------------------- écriture
def wstr(fh, s):
    b = s.encode("utf-8")[:65000]
    fh.write(struct.pack("<H", len(b)))
    fh.write(b)

def rings_of(geom):
    polys = [geom] if isinstance(geom, Polygon) else list(getattr(geom, "geoms", []))
    polys = [p for p in polys if isinstance(p, Polygon)]
    polys.sort(key=lambda p: -p.area)
    out = []
    for k, p in enumerate(polys):
        if k > 0 and p.area < 0.003:     # minuscules îlots ignorés
            continue
        s = p.simplify(0.02 if p.area > 0.5 else 0.008, preserve_topology=True)
        if s.is_empty or not isinstance(s, Polygon):
            continue
        coords = list(s.exterior.coords)
        if len(coords) >= 4:
            out.append(coords[:-1])
    if not out and polys:
        out.append(list(polys[0].exterior.coords)[:-1])
    return out

def label_point(geom):
    polys = [geom] if isinstance(geom, Polygon) else [p for p in getattr(geom, "geoms", []) if isinstance(p, Polygon)]
    big = max(polys, key=lambda p: p.area)
    if polylabel is not None:
        try:
            return polylabel(big, tolerance=0.05)
        except Exception:
            pass
    return big.representative_point()

total_points = 0
with open(OUT, "wb") as fh:
    fh.write(b"MAP2")
    fh.write(struct.pack("<I", len(final)))
    for i, f in enumerate(final):
        fh.write(f["code"].encode("ascii")[:3].ljust(3, b" "))
        wstr(fh, f["name"])
        wstr(fh, f["cname"])
        lp = label_point(f["geom"])
        fh.write(struct.pack("<fff", lp.y, lp.x, f["area"]))
        rings = rings_of(f["geom"])
        fh.write(struct.pack("<H", len(rings)))
        for r in rings:
            fh.write(struct.pack("<I", len(r)))
            total_points += len(r)
            for x, y in r:
                fh.write(struct.pack("<ff", x, y))
        nb = sorted(neighbors[i])
        fh.write(struct.pack("<H", len(nb)))
        for n in nb:
            fh.write(struct.pack("<H", n))
    fh.write(struct.pack("<I", len(edges)))
    for a, b, lines in edges:
        fh.write(struct.pack("<HHH", a, b, len(lines)))
        for ln in lines:
            fh.write(struct.pack("<I", len(ln)))
            total_points += len(ln)
            for x, y in ln:
                fh.write(struct.pack("<ff", x, y))

with open(REPORT, "w", encoding="utf-8") as fh:
    fh.write(f"régions {len(final)}, frontières {len(edges)}, points {total_points}, taille {os.path.getsize(OUT)} octets\n")
    fh.write("pays du jeu sans région : " + ", ".join(sorted(game - set(units))) + "\n")
    fh.write("pays neutres : " + ", ".join(sorted(f"{c} ({country_names.get(c, c)})" for c in set(units) - game)) + "\n")
    by = defaultdict(list)
    for f in final:
        by[f["code"]].append(f["name"])
    for c in sorted(by):
        fh.write(f"{c} ({len(by[c])}) : " + " | ".join(sorted(by[c])) + "\n")
print(open(REPORT, encoding="utf-8").read()[:3000])
# version 0.8 : petits États jouables
