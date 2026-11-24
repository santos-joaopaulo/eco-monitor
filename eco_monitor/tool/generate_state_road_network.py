#!/usr/bin/env python3
"""
Script de fatiamento e particionamento de malha viária OpenStreetMap em tiles espaciais.
Gera tiles espaciais compactos (~0.2° x 0.2°) e backbone rodoviário para o EcoMonitor (T14.1).
"""

import argparse
import json
import math
import os
import sys
from collections import defaultdict
from typing import Any, Dict, List, Set, Tuple


# Constants ---------------------------------------------------------------- //

DEFAULT_TILE_SIZE_DEG = 0.2
BACKBONE_HIGHWAYS = {
    "motorway",
    "motorway_link",
    "trunk",
    "trunk_link",
    "primary",
    "primary_link",
}


# Functions ---------------------------------------------------------------- //

def tile_key_for(lat: float, lon: float, tile_size: float) -> str:
    """Calcula a chave do tile correspondente à coordenada."""
    row = math.floor(lat / tile_size)
    col = math.floor(lon / tile_size)
    return f"{row}_{col}"


def tile_bbox_for(row: int, col: int, tile_size: float) -> List[float]:
    """Retorna a bounding box [minLat, minLon, maxLat, maxLon] do tile."""
    min_lat = row * tile_size
    min_lon = col * tile_size
    return [
        round(min_lat, 6),
        round(min_lon, 6),
        round(min_lat + tile_size, 6),
        round(min_lon + tile_size, 6),
    ]


def haversine_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calcula a distância geodésica em metros entre duas coordenadas."""
    r = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (math.sin(delta_phi / 2.0) ** 2 +
         math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return r * c


def partition_network(
    input_file: str,
    output_dir: str,
    tile_size: float = DEFAULT_TILE_SIZE_DEG,
    state_code: str = "BR",
) -> Dict[str, Any]:
    """Processa a malha viária e particiona nós e arestas em tiles compactos."""
    with open(input_file, "r", encoding="utf-8") as f:
        raw_data = json.load(f)

    nodes: List[List[float]] = raw_data.get("nodes", [])
    edges: List[List[Any]] = raw_data.get("edges", [])

    print(f"[*] Carregados {len(nodes)} nós e {len(edges)} arestas de '{input_file}'.")

    # Mapeamento de nós para tiles
    node_to_tile: Dict[int, str] = {}
    tile_nodes: Dict[str, List[int]] = defaultdict(list)

    for i, (lat, lon) in enumerate(nodes):
        key = tile_key_for(lat, lon, tile_size)
        node_to_tile[i] = key
        tile_nodes[key].append(i)

    # Agrupamento de arestas por tile e identificação do backbone
    tile_edges: Dict[str, List[List[Any]]] = defaultdict(list)
    backbone_edges: List[List[Any]] = []
    boundary_nodes: Dict[str, Set[int]] = defaultdict(set)
    backbone_node_ids: Set[int] = set()

    for edge in edges:
        u = edge[0]
        v = edge[1]
        tile_u = node_to_tile.get(u)
        tile_v = node_to_tile.get(v)

        # Se a aresta conecta nós de tiles diferentes, é uma conexão de fronteira
        if tile_u != tile_v:
            backbone_edges.append(edge)
            backbone_node_ids.add(u)
            backbone_node_ids.add(v)
            if tile_u:
                boundary_nodes[tile_u].add(u)
            if tile_v:
                boundary_nodes[tile_v].add(v)
        else:
            if tile_u:
                tile_edges[tile_u].append(edge)

    os.makedirs(output_dir, exist_ok=True)

    # Escreve arquivos individuais por tile
    generated_tiles_meta = []
    for tile_key, node_indices in tile_nodes.items():
        parts = tile_key.split("_")
        row, col = int(parts[0]), int(parts[1])
        bbox = tile_bbox_for(row, col, tile_size)

        tile_node_lats = [nodes[idx][0] for idx in node_indices]
        tile_node_lons = [nodes[idx][1] for idx in node_indices]

        tile_payload = {
            "tileKey": tile_key,
            "bbox": bbox,
            "nodeIds": node_indices,
            "nodeLats": tile_node_lats,
            "nodeLons": tile_node_lons,
            "edges": tile_edges.get(tile_key, []),
            "boundaryNodes": list(boundary_nodes.get(tile_key, set())),
        }

        tile_path = os.path.join(output_dir, f"tile_{tile_key}.json")
        with open(tile_path, "w", encoding="utf-8") as tf:
            json.dump(tile_payload, tf, separators=(",", ":"))

        generated_tiles_meta.append({
            "tileKey": tile_key,
            "bbox": bbox,
            "nodeCount": len(node_indices),
            "edgeCount": len(tile_edges.get(tile_key, [])),
        })

    # Escreve o backbone rodoviário
    sorted_backbone_nodes = sorted(list(backbone_node_ids))
    backbone_payload = {
        "nodeIds": sorted_backbone_nodes,
        "nodeLats": [nodes[idx][0] for idx in sorted_backbone_nodes],
        "nodeLons": [nodes[idx][1] for idx in sorted_backbone_nodes],
        "edges": backbone_edges,
    }

    backbone_path = os.path.join(output_dir, "backbone.json")
    with open(backbone_path, "w", encoding="utf-8") as bf:
        json.dump(backbone_payload, bf, separators=(",", ":"))

    # Manifest do pacote
    manifest = {
        "stateCode": state_code,
        "tileSize": tile_size,
        "totalNodes": len(nodes),
        "totalEdges": len(edges),
        "tileCount": len(tile_nodes),
        "backboneEdgeCount": len(backbone_edges),
        "tiles": generated_tiles_meta,
    }

    manifest_path = os.path.join(output_dir, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as mf:
        json.dump(manifest, mf, indent=2)

    print(f"[+] Particionamento concluído: {len(tile_nodes)} tiles e {len(backbone_edges)} arestas no backbone.")
    return manifest


# Main -------------------------------------------------------------------- //

def main():
    parser = argparse.ArgumentParser(
        description="Fatia malhas viárias OSM em tiles espaciais compactos para o EcoMonitor."
    )
    parser.add_argument("--input", required=True, help="Arquivo JSON de entrada contendo a malha viária.")
    parser.add_argument("--output-dir", required=True, help="Diretório onde os tiles serão gravados.")
    parser.add_argument("--tile-size", type=float, default=DEFAULT_TILE_SIZE_DEG, help="Tamanho angular do tile.")
    parser.add_argument("--state-code", default="BR", help="Sigla do estado (ex.: SE, BA, SP).")

    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f"[-] Erro: Arquivo de entrada '{args.input}' não encontrado.", file=sys.stderr)
        sys.exit(1)

    partition_network(
        input_file=args.input,
        output_dir=args.output_dir,
        tile_size=args.tile_size,
        state_code=args.state_code,
    )


if __name__ == "__main__":
    main()
