#!/usr/bin/env python3
"""Write the PinComp app icon SVGs (default, dark, tinted) into scripts/icon/.

Original artwork: a flat gold pushpin pressed into a single hexagon tile, on a
near-black background with a faint purple-to-gold gradient ring around the hex.
Render to 1024 px PNGs with: swift scripts/icon/render_icon.swift
"""

import math
import os

OUT = os.path.dirname(os.path.abspath(__file__))
SIZE = 1024
CX, CY = 512, 548


def hexagon(r, cx=CX, cy=CY):
    pts = []
    for k in range(6):
        a = math.radians(-90 + 60 * k)
        pts.append("%.1f,%.1f" % (cx + r * math.cos(a), cy + r * math.sin(a)))
    return " ".join(pts)


def svg(variant):
    if variant == "tinted":
        # Grayscale on transparent; the system applies the tint.
        bg = None
        ring_a, ring_b, ring_opacity = "#FFFFFF", "#FFFFFF", 0.35
        tile, tile_edge = "#3A3A3A", "#5A5A5A"
        gold, gold_light, gold_dark = "#FFFFFF", "#FFFFFF", "#C8C8C8"
        needle, shadow = "#9A9A9A", "#000000"
    else:
        bg = None if variant == "dark" else "#0A0A0D"
        ring_a, ring_b, ring_opacity = "#A35CF2", "#F9C238", 0.55
        tile, tile_edge = "#17171D", "#26262F"
        gold, gold_light, gold_dark = "#F5B82E", "#FFD866", "#C98F14"
        needle, shadow = "#B9B9C4", "#000000"

    background = '<rect width="%d" height="%d" fill="%s"/>' % (SIZE, SIZE, bg) if bg else ""
    return """<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">
  <defs>
    <linearGradient id="ring" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{ring_a}"/>
      <stop offset="1" stop-color="{ring_b}"/>
    </linearGradient>
  </defs>
  {background}
  <polygon points="{ring}" fill="none" stroke="url(#ring)" stroke-width="16" stroke-linejoin="round" opacity="{ring_opacity}"/>
  <polygon points="{hex}" fill="{tile}" stroke="{tile_edge}" stroke-width="10" stroke-linejoin="round"/>
  <g transform="translate(-100 72)">
  <ellipse cx="{cx}" cy="{shadow_y}" rx="74" ry="22" fill="{shadow}" opacity="0.45"/>
  <g transform="rotate(28 {cx} {press_y})">
    <rect x="{needle_x}" y="{needle_top}" width="16" height="84" rx="8" fill="{needle}"/>
    <ellipse cx="{cx}" cy="{base_y}" rx="112" ry="30" fill="{gold_dark}"/>
    <polygon points="{collar}" fill="{gold}"/>
    <ellipse cx="{cx}" cy="{base_y_top}" rx="112" ry="30" fill="{gold}"/>
    <circle cx="{cx}" cy="{head_y}" r="104" fill="{gold}"/>
    <path d="M {hl_x0} {hl_y0} A 76 76 0 0 1 {hl_x1} {hl_y1}" fill="none" stroke="{gold_light}" stroke-width="22" stroke-linecap="round"/>
  </g>
  </g>
</svg>
""".format(
        S=SIZE,
        background=background,
        ring=hexagon(372),
        hex=hexagon(318),
        ring_a=ring_a, ring_b=ring_b, ring_opacity=ring_opacity,
        tile=tile, tile_edge=tile_edge, shadow=shadow,
        gold=gold, gold_light=gold_light, gold_dark=gold_dark, needle=needle,
        cx=CX,
        press_y=CY + 40,
        shadow_y=CY + 42,
        needle_x=CX - 8, needle_top=CY - 40,
        base_y=CY - 34, base_y_top=CY - 46,
        collar="%d,%d %d,%d %d,%d %d,%d" % (CX - 112, CY - 46, CX - 56, CY - 196, CX + 56, CY - 196, CX + 112, CY - 46),
        head_y=CY - 250,
        hl_x0=CX - 66, hl_y0=CY - 280, hl_x1=CX - 10, hl_y1=CY - 322,
    )


for variant in ("default", "dark", "tinted"):
    path = os.path.join(OUT, "AppIcon-%s.svg" % variant)
    with open(path, "w") as f:
        f.write(svg(variant))
    print(path)
