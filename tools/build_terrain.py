#!/usr/bin/env python3
"""
Construit Resources/terrain.json à partir de Resources/map.bin et de Natural Earth.

Pour chaque région : un type de terrain
  0 plaine, 1 forêt, 2 collines, 3 montagne, 4 désert, 5 jungle/marais, 6 urbain, 7 toundra
Pour chaque paire de régions voisines séparées par un grand fleuve : [a, b]

Sources (domaine public) :
  ne_10m_geography_regions_polys  (chaînes de montagnes, déserts, plateaux, zones humides…)
  ne_10m_rivers_lake_centerlines  (grands fleuves)
  ne_10m_populated_places_simple  (grandes villes)

Usage : build_terrain.py map.bin geo.geojson rivers.geojson places.geojson terrain.json rapport.txt
"""
import json, math, struct, sys
from collections import Counter, defaultdict

from shapely.geometry import shape, Polygon, MultiPolygon, LineString, Point
from shapely.strtree import STRtree
from shapely.ops import unary_union

MAP, GEO, RIVERS, PLACES, OUT, REPORT = sys.argv[1:7]

# ------------------------------------------------------------ lecture de map.bin
data = open(MAP, "rb").read()
pos = 0
def take(fmt):
    global pos
    v = struct.unpack_from(fmt, data, pos)
    pos += struct.calcsize(fmt)
    return v
def rstr():
    (n,) = take("<H")
    global pos
    s = data[pos:pos + n].decode("utf-8")
    pos += n
    return s

magic = data[:4].decode()
pos = 4
assert magic in ("MAP2", "MAP3"), magic
(count,) = take("<I")
regions = []
for i in range(count):
    code = data[pos:pos + 3].decode("ascii").strip(); pos += 3
    name = rstr(); cname = rstr()
    lat, lon, area = take("<fff")
    (nr,) = take("<H")
    polys = []
    for _ in range(nr):
        (n,) = take("<I")
        pts = [take("<ff") for _ in range(n)]
        if len(pts) >= 3:
            p = Polygon(pts)
            if not p.is_valid:
                p = p.buffer(0)
            if not p.is_empty:
                polys.append(p)
    (nn,) = take("<H")
    nbs = [take("<H")[0] for _ in range(nn)]
    if magic == "MAP3":
        take("<B")
    geom = unary_union(polys) if polys else Point(lon, lat).buffer(0.1)
    regions.append(dict(code=code, name=name, lat=lat, lon=lon, area=area, geom=geom, nbs=nbs))
print("régions :", len(regions))

def load(path):
    try:
        return json.load(open(path, encoding="utf-8"))["features"]
    except Exception as e:
        print("pas de données :", path, e)
        return []

def prop(f, *keys):
    p = f.get("properties") or {}
    low = {k.lower(): v for k, v in p.items()}
    for k in keys:
        v = low.get(k.lower())
        if v not in (None, ""):
            return v
    return None

# ------------------------------------------------------------ zones géographiques
geo_feats = load(GEO)
classes = Counter()
zones = defaultdict(list)          # catégorie -> géométries
for f in geo_feats:
    cl = str(prop(f, "featurecla") or "").lower()
    classes[cl] += 1
    try:
        g = shape(f["geometry"])
        if not g.is_valid:
            g = g.buffer(0)
    except Exception:
        continue
    if "range" in cl or "mtn" in cl or "mountain" in cl:
        zones["mountain"].append(g)
    elif "desert" in cl:
        zones["desert"].append(g)
    elif "plateau" in cl:
        zones["plateau"].append(g)
    elif "wetland" in cl or "delta" in cl or "swamp" in cl or "marsh" in cl:
        zones["wetland"].append(g)
    elif "tundra" in cl:
        zones["tundra"].append(g)
    elif "foothill" in cl or "hill" in cl:
        zones["hills"].append(g)

trees = {k: (STRtree(v), v) for k, v in zones.items()}

def coverage(region_geom, kind):
    if kind not in trees:
        return 0.0
    tree, geoms = trees[kind]
    total = region_geom.area
    if total <= 0:
        return 0.0
    hit = 0.0
    for idx in tree.query(region_geom):
        try:
            hit += region_geom.intersection(geoms[idx]).area
        except Exception:
            pass
    return min(1.0, hit / total)

# ------------------------------------------------------------ villes
places = []
for f in load(PLACES):
    pop = prop(f, "pop_max", "pop_min") or 0
    try:
        pop = float(pop)
    except Exception:
        pop = 0
    if pop < 700_000:
        continue
    try:
        g = shape(f["geometry"])
    except Exception:
        continue
    places.append((g, pop, prop(f, "name") or ""))
place_tree = STRtree([p[0] for p in places]) if places else None

# ------------------------------------------------------------ classement
PLAIN, FOREST, HILLS, MOUNTAIN, DESERT, JUNGLE, URBAN, TUNDRA = range(8)
terrain = []
city_of = {}
stats = Counter()
for i, r in enumerate(regions):
    g, lat, area = r["geom"], r["lat"], max(r["area"], 1)
    mtn = coverage(g, "mountain")
    des = coverage(g, "desert")
    pla = coverage(g, "plateau")
    wet = coverage(g, "wetland")
    tun = coverage(g, "tundra")
    hil = coverage(g, "hills")
    pop = 0.0
    biggest = None
    if place_tree is not None:
        for idx in place_tree.query(g):
            pg, pp, pn = places[idx]
            if g.contains(pg):
                pop += pp
                if biggest is None or pp > biggest[1]:
                    biggest = (pn, pp)
    density = pop / area
    if biggest:
        city_of[i] = biggest[0]
    alat = abs(lat)
    if (density > 900 and area < 25000) or (pop > 3_000_000 and area < 9000):
        t = URBAN
    elif mtn >= 0.40:
        t = MOUNTAIN
    elif des >= 0.40 or (des >= 0.2 and 15 <= alat <= 35):
        t = DESERT
    elif tun >= 0.40 or alat >= 66:
        t = TUNDRA
    elif wet >= 0.35:
        t = JUNGLE
    elif mtn >= 0.15 or pla >= 0.45 or hil >= 0.4:
        t = HILLS
    elif alat < 12:
        t = JUNGLE
    elif 52 <= alat < 66:
        t = FOREST
    elif not trees and 15 <= alat <= 32:
        t = DESERT
    else:
        t = PLAIN
    terrain.append(t)
    stats[t] += 1

# ------------------------------------------------------------ fleuves
river_lines = []
for f in load(RIVERS):
    rank = prop(f, "scalerank")
    try:
        rank = int(rank)
    except Exception:
        rank = 99
    fc = str(prop(f, "featurecla") or "").lower()
    if rank > 5 or "lake" in fc:
        continue
    try:
        river_lines.append(shape(f["geometry"]))
    except Exception:
        pass
rivers = []
if river_lines:
    rtree = STRtree(river_lines)
    seen = set()
    for i, r in enumerate(regions):
        for j in r["nbs"]:
            if j <= i or (i, j) in seen:
                continue
            seen.add((i, j))
            a, b = regions[i], regions[j]
            seg = LineString([(a["lon"], a["lat"]), (b["lon"], b["lat"])])
            if seg.length > 25:
                continue
            # Le fleuve doit couper le trajet entre les deux régions ET longer leur frontière.
            border = a["geom"].buffer(0.05).intersection(b["geom"].buffer(0.05))
            for idx in rtree.query(seg):
                line = river_lines[idx]
                try:
                    if line.intersects(seg) and not border.is_empty and line.intersects(border.buffer(0.05)):
                        rivers.append([i, j])
                        break
                except Exception:
                    pass

names = ["plaine", "forêt", "collines", "montagne", "désert", "jungle/marais", "urbain", "toundra"]
json.dump({"regions": len(regions), "terrain": terrain, "rivers": rivers,
           "cities": {str(k): v for k, v in city_of.items()}},
          open(OUT, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))

with open(REPORT, "w", encoding="utf-8") as fh:
    fh.write(f"régions {len(regions)}, fleuves {len(rivers)}, villes {len(places)}\n")
    fh.write("classes Natural Earth : " + ", ".join(f"{k} {v}" for k, v in classes.most_common()) + "\n")
    fh.write("terrains : " + ", ".join(f"{names[k]} {v}" for k, v in sorted(stats.items())) + "\n")
    for code in ["UKR", "RUS", "FRA", "CHE", "AFG", "EGY", "BRA", "ARM", "AZE", "ISR", "TWN", "VEN", "GUY"]:
        items = [f"{r['name']}={names[terrain[i]]}" for i, r in enumerate(regions) if r["code"] == code]
        fh.write(f"{code} : " + " | ".join(items[:60]) + "\n")
    fh.write("fleuves UKR/RUS : " + " | ".join(
        f"{regions[a]['name']}–{regions[b]['name']}" for a, b in rivers
        if regions[a]["code"] in ("UKR", "RUS") or regions[b]["code"] in ("UKR", "RUS")) + "\n")
print(open(REPORT, encoding="utf-8").read()[:4000])
