#!/usr/bin/env python3
"""
Gera o grafo topológico viário de Aracaju/SE a partir do OpenStreetMap (OSM)
para roteamento nativo offline preciso (Abordagem B).
"""

import gzip
import json
import math
import os
import sys
import urllib.parse
import urllib.request


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calcula a distância ortodrômica em metros entre dois pontos geográficos."""
    r = 6371000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    )
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def encode_polyline(points: list[tuple[float, float]]) -> str:
    """Codifica lista de coordenadas (lat, lon) no algoritmo Google Polyline."""
    result: list[str] = []
    prev_lat = 0
    prev_lon = 0
    for lat, lon in points:
        lat_int = int(round(lat * 1e5))
        lon_int = int(round(lon * 1e5))
        d_lat = lat_int - prev_lat
        d_lon = lon_int - prev_lon
        prev_lat = lat_int
        prev_lon = lon_int
        for d in (d_lat, d_lon):
            s = d << 1
            if d < 0:
                s = ~s
            while s >= 0x20:
                result.append(chr((0x20 | (s & 0x1F)) + 63))
                s >>= 5
            result.append(chr(s + 63))
    return "".join(result)


def fetch_osm_ways(cache_path: str) -> list[dict]:
    """Obtém as vias do OSM via cache local ou Overpass API."""
    if os.path.exists(cache_path):
        print(f"Carregando dados OSM do cache: {cache_path}")
        with gzip.open(cache_path, "rb") as f:
            data = json.loads(f.read().decode("utf-8"))
            return data.get("elements", [])

    print("Baixando malha viária de Aracaju da Overpass API...")
    query = """
    [out:json][timeout:90];
    (
      way["highway"~"motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|pedestrian|cycleway|footway|path|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link"](-11.05,-37.15,-10.82,-37.00);
    );
    out tags geom;
    """
    url = "https://overpass.openstreetmap.fr/api/interpreter"
    req = urllib.request.Request(
        url,
        data=urllib.parse.urlencode({"data": query}).encode("utf-8"),
        headers={"User-Agent": "EcoMonitor/1.0 (contact@ecomonitor.app)"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read()

    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    with gzip.open(cache_path, "wb") as f:
        f.write(raw)

    data = json.loads(raw.decode("utf-8"))
    return data.get("elements", [])


def build_road_network(ways: list[dict], output_file: str):
    """Constrói o grafo topológico e grava o arquivo JSON final."""
    print(f"Processando {len(ways)} vias do OpenStreetMap...")

    highway_speeds = {
        "motorway": 80,
        "motorway_link": 50,
        "trunk": 70,
        "trunk_link": 45,
        "primary": 50,
        "primary_link": 40,
        "secondary": 45,
        "secondary_link": 35,
        "tertiary": 35,
        "tertiary_link": 30,
        "unclassified": 30,
        "residential": 30,
        "living_street": 20,
        "service": 20,
        "pedestrian": 5,
        "footway": 5,
        "cycleway": 15,
        "path": 5,
    }

    # 1. Contagem de nós para identificar interseções
    coord_counts: dict[tuple[float, float], int] = {}
    for w in ways:
        geom = w.get("geometry", [])
        if len(geom) < 2:
            continue
        for idx, p in enumerate(geom):
            pt = (round(p["lat"], 5), round(p["lon"], 5))
            coord_counts[pt] = coord_counts.get(pt, 0) + (
                10 if idx == 0 or idx == len(geom) - 1 else 1
            )

    node_map: dict[tuple[float, float], int] = {}
    node_coords: list[tuple[float, float]] = []
    for pt, count in coord_counts.items():
        if count >= 2:
            node_map[pt] = len(node_coords)
            node_coords.append(pt)

    print(f"Nós de interseção identificados: {len(node_coords)}")

    # 2. Segmentação em arestas
    raw_edges: list[tuple] = []
    adj: list[list[int]] = [[] for _ in range(len(node_coords))]

    for w in ways:
        geom = w.get("geometry", [])
        if len(geom) < 2:
            continue
        tags = w.get("tags", {})
        hw = tags.get("highway", "residential")
        speed = highway_speeds.get(hw, 30)
        oneway_tag = tags.get("oneway", "no").lower()
        is_oneway = oneway_tag in ("yes", "1", "true")
        is_reverse = oneway_tag in ("-1", "reverse")

        # Modais: 1=driving, 2=cycling, 4=walking
        modes = 0
        if hw not in ("pedestrian", "footway", "cycleway", "path", "steps"):
            modes |= 1
        if hw not in ("motorway", "steps"):
            modes |= 2
        if hw not in ("motorway",):
            modes |= 4

        current_segment: list[tuple[float, float]] = []
        start_node: int | None = None

        for p in geom:
            pt = (round(p["lat"], 5), round(p["lon"], 5))
            current_segment.append(pt)
            if pt in node_map:
                if start_node is not None and len(current_segment) >= 2:
                    end_node = node_map[pt]
                    if start_node != end_node:
                        dist = sum(
                            haversine(
                                current_segment[i][0],
                                current_segment[i][1],
                                current_segment[i + 1][0],
                                current_segment[i + 1][1],
                            )
                            for i in range(len(current_segment) - 1)
                        )
                        inter_pts = current_segment[1:-1]
                        encoded = (
                            encode_polyline(inter_pts) if inter_pts else ""
                        )
                        direction = (
                            1 if is_oneway else (2 if is_reverse else 0)
                        )
                        raw_edges.append(
                            (
                                start_node,
                                end_node,
                                modes,
                                speed,
                                direction,
                                encoded,
                                round(dist, 1),
                            )
                        )
                        adj[start_node].append(end_node)
                        adj[end_node].append(start_node)
                start_node = node_map[pt]
                current_segment = [pt]

    # 3. Filtro de componentes conexos >= 10 nós
    visited = [False] * len(node_coords)
    valid_nodes: set[int] = set()
    for i in range(len(node_coords)):
        if not visited[i]:
            comp: list[int] = []
            q = [i]
            visited[i] = True
            while q:
                u = q.pop()
                comp.append(u)
                for v in adj[u]:
                    if not visited[v]:
                        visited[v] = True
                        q.append(v)
            if len(comp) >= 10:
                valid_nodes.update(comp)

    print(
        f"Nós retidos na malha viária conexa: {len(valid_nodes)} / {len(node_coords)}"
    )

    old_to_new: dict[int, int] = {}
    new_node_coords: list[tuple[float, float]] = []
    for old_id in sorted(valid_nodes):
        old_to_new[old_id] = len(new_node_coords)
        new_node_coords.append(node_coords[old_id])

    filtered_edges: list[list] = []
    for u, v, modes, speed, direction, encoded, dist in raw_edges:
        if u in old_to_new and v in old_to_new:
            filtered_edges.append(
                [
                    old_to_new[u],
                    old_to_new[v],
                    modes,
                    speed,
                    direction,
                    encoded,
                    dist,
                ]
            )

    print(f"Arestas finais: {len(filtered_edges)}")

    output = {
        "bbox": [-11.05, -37.15, -10.82, -37.00],
        "nodes": [[lat, lon] for lat, lon in new_node_coords],
        "edges": filtered_edges,
    }

    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(output, f, separators=(",", ":"))

    size_mb = os.path.getsize(output_file) / (1024 * 1024)
    print(f"Grafo gravado em '{output_file}' ({size_mb:.2f} MB). Sucesso!")


if __name__ == "__main__":
    cache = "eco_monitor/tool/.cache/osm_aracaju.json.gz"
    out = "eco_monitor/assets/data/aracaju_road_network.json"
    ways = fetch_osm_ways(cache)
    build_road_network(ways, out)
