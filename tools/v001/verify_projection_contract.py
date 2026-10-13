#!/usr/bin/env python3
"""Dependency-free math/topology tests for proposed Nile Kiosk iso v0.1.

Does NOT claim the open legacy V001 Blender/Godot code uses this projection.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "art" / "contracts" / "isometric-v0.1.json"


def close(actual: float, expected: float, eps: float = 1e-8) -> None:
    assert abs(actual - expected) < eps, (actual, expected)


def project(x: float, y: float, z: float, x0: float, y0: float, a: float, b: float, h: float) -> tuple[float, float]:
    return (x0 + a * (x - y), y0 + b * (x + y) - h * z)


def invert(sx: float, sy: float, z: float, x0: float, y0: float, a: float, b: float, h: float) -> tuple[float, float]:
    difference = (sx - x0) / a
    sum_ = (sy - y0 + h * z) / b
    return (0.5 * (sum_ + difference), 0.5 * (sum_ - difference))


def main() -> None:
    cfg = json.loads(PATH.read_text(encoding="utf-8"))
    assert cfg["contract_id"] == "nk-isometric-v0.1"
    assert cfg["status"] == "proposed-authoring-target-not-yet-live"
    w, height = cfg["tile_diamond_px"]
    close(w / height, 2.0)
    close(cfg["camera"]["elevation_deg"], 30.0)
    a, b = w / 2, height / 2
    h = a * math.sqrt(3 / 2)
    actual = cfg["project_coefficients_px_per_m"]
    for key, vector in {
        "x_to_screen": (a, b),
        "y_to_screen": (-a, b),
        "z_to_screen": (0, -h),
    }.items():
        for got, want in zip(actual[key], vector):
            close(got, want)
    origin = cfg["view_origin_px"]
    samples = [
        (0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 0),
        (4, 5, 0), (9, 11, 0), (4, 5, 3.4),
        (8.25, 7.5, 17.0), (6, 9, 20.4),
    ]
    for x, y, z in samples:
        sx, sy = project(x, y, z, *origin, a, b, h)
        rx, ry = invert(sx, sy, z, *origin, a, b, h)
        close(rx, x)
        close(ry, y)
    close(project(1, 0, 0, *origin, a, b, h)[0], 502.0)
    close(project(1, 0, 0, *origin, a, b, h)[1], 396.0)
    close(project(0, 1, 0, *origin, a, b, h)[0], 478.0)
    close(project(0, 0, 3.4, *origin, a, b, h)[1], 390 - 3.4 * h)
    floor_height = cfg["floor"]["height_m"]
    close(floor_height, 3.4)
    close(project(0, 0, 0, *origin, a, b, h)[1] - project(0, 0, floor_height, *origin, a, b, h)[1], 3.4 * h)
    spaces = cfg["footprint_m"]
    apt, roof = spaces["south_apartment"], spaces["roof_room"]
    assert math.prod(apt["size"]) == 60
    assert math.prod(roof["size"]) == 24
    for i in (0, 1):
        assert apt["origin"][i] <= roof["origin"][i]
        assert roof["origin"][i] + roof["size"][i] <= apt["origin"][i] + apt["size"][i]
    # Shared landing lies directly between opaque northern neighbor and southern flat.
    neighbor, landing = spaces["neighbor_opaque"], spaces["shared_landing"]
    close(neighbor["origin"][1] + neighbor["size"][1], landing["origin"][1])
    close(landing["origin"][1] + landing["size"][1], apt["origin"][1])
    assert cfg["levels"]["shared_roof_elevation_index"] - cfg["levels"]["top_south_flat_elevation_index"] == 1
    print(f"NK_ISO_CONTRACT_PASS: ratio 2:1, 9 inverse samples, 3 elevations, 24m2/60m2 containment; floor {floor_height*h:.6f}px")


if __name__ == "__main__":
    main()
