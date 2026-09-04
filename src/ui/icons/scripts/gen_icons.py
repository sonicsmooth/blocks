#!/usr/bin/env python3
"""Generate a set of modern, filled, gradient UI icons as SVG (+ glyph-only
variants used to composite clean, non-banded PNGs with PIL)."""
import os
import subprocess


def text_to_svg_path(text, x_off, y_off, font_size=11,
                     font_match="Liberation Sans:style=Regular"):
    """Convert text to SVG path outlines via freetype-py (no <text> element —
    works with pixie and other SVG renderers that lack text support)."""
    try:
        import freetype
    except ImportError:
        return f'<text x="{x_off}" y="{y_off}" font-size="{font_size}" fill="#ffffff">{text}</text>'

    result = subprocess.run(
        ['fc-match', '--format=%{file}', font_match],
        capture_output=True, text=True)
    font_path = result.stdout.strip()
    if not font_path:
        return f'<text x="{x_off}" y="{y_off}" font-size="{font_size}" fill="#ffffff">{text}</text>'

    face = freetype.Face(font_path)
    face.set_char_size(font_size * 64)

    def contour_to_d(pts, tgs, xo, yo):
        def px(p): return f"{xo + p[0]/64:.2f}"
        def py(p): return f"{yo - p[1]/64:.2f}"
        n = len(pts)
        d = []
        i = 0
        while i < n:
            t = tgs[i] & 0x03
            if t == 1:
                cmd = "M" if not d else "L"
                d.append(f"{cmd}{px(pts[i])} {py(pts[i])}")
                i += 1
            elif t == 2:  # cubic
                c1, c2, ep = pts[i], pts[i+1], pts[i+2]
                d.append(f"C{px(c1)} {py(c1)} {px(c2)} {py(c2)} {px(ep)} {py(ep)}")
                i += 3
            else:  # conic / quadratic
                c = pts[i]
                if i + 1 < n and (tgs[i+1] & 0x03) == 0:
                    mid = ((c[0]+pts[i+1][0])//2, (c[1]+pts[i+1][1])//2)
                    if not d: d.append(f"M{px(mid)} {py(mid)}")
                    d.append(f"Q{px(c)} {py(c)} {px(mid)} {py(mid)}")
                else:
                    ep = pts[(i+1) % n]
                    if not d: d.append(f"M{px(ep)} {py(ep)}")
                    d.append(f"Q{px(c)} {py(c)} {px(ep)} {py(ep)}")
                i += 1
        d.append("Z")
        return "".join(d)

    all_d = []
    x = x_off
    for ch in text:
        face.load_char(ch, freetype.FT_LOAD_NO_BITMAP)
        adv = face.glyph.advance.x / 64
        if ch != ' ':
            ol = face.glyph.outline
            start = 0
            for end in ol.contours:
                all_d.append(contour_to_d(list(ol.points[start:end+1]),
                                          list(ol.tags[start:end+1]), x, y_off))
                start = end + 1
        x += adv

    return f'<path d="{"".join(all_d)}" fill="#ffffff" fill-rule="evenodd"/>'

OUT      = os.path.join("..", "icons")
SVG_DIR  = os.path.join(OUT, "svg")
os.makedirs(SVG_DIR, exist_ok=True)

R = 7  # badge corner radius (squared-off, not fully sharp)
GLYPH_WHITE = "#ffffff"

# SVG-level scale factors (applied via <g transform>, no CSS involved)
# Hover = full size (1.0), Normal = 2% smaller, Pressed = 5% smaller than Normal
SCALE_NORMAL  = 1.0
SCALE_HOVER   = 1.04
SCALE_PRESSED = 0.98


import math


def involute_gear_path(cx, cy, n=8, r_pitch=11.0, pressure_deg=20.0,
                       addendum=2.5, dedendum=2.5, n_pts=8):
    """SVG path string for an involute spur gear centered at (cx, cy).
    Produces proper involute flanks + tip/root arcs — looks like a real gear, not a star."""
    alpha  = math.radians(pressure_deg)
    r_base = r_pitch * math.cos(alpha)
    r_tip  = r_pitch + addendum
    r_root = r_pitch - dedendum
    pitch_ang  = 2 * math.pi / n
    half_tooth = math.pi / (2 * n)

    def inv_xy(t):
        return (r_base * (math.cos(t) + t * math.sin(t)),
                r_base * (math.sin(t) - t * math.cos(t)))

    def t_at_r(r):
        return math.sqrt(max(0.0, (r / r_base) ** 2 - 1))

    t_pitch = t_at_r(r_pitch)
    t_tip   = t_at_r(r_tip)
    xp, yp  = inv_xy(t_pitch)
    inv_angle_at_pitch = math.atan2(yp, xp)
    flank_rot = -half_tooth - inv_angle_at_pitch

    def place(x, y, rot, tooth_i):
        total = tooth_i * pitch_ang + rot
        c, s = math.cos(total), math.sin(total)
        return cx + x * c - y * s, cy + x * s + y * c

    def reflect(px, py, tooth_i):
        base = tooth_i * pitch_ang
        dx, dy = px - cx, py - cy
        theta_ref = 2 * base - math.atan2(dy, dx)
        r_dist = math.hypot(dx, dy)
        return cx + r_dist * math.cos(theta_ref), cy + r_dist * math.sin(theta_ref)

    def f(px, py): return f"{px:.3f},{py:.3f}"

    t_start = t_at_r(r_root) if r_root >= r_base else 0.0
    parts = []

    for i in range(n):
        rf = []
        if r_root < r_base:
            rf.append(place(r_root, 0, flank_rot, i))
        for k in range(n_pts + 1):
            t = t_start + (t_tip - t_start) * k / n_pts
            rf.append(place(*inv_xy(t), flank_rot, i))

        lf = [reflect(px, py, i) for px, py in reversed(rf)]

        if i == 0:
            parts.append(f"M {f(*rf[0])}")
        else:
            parts.append(f"A {r_root:.3f},{r_root:.3f} 0 0 1 {f(*rf[0])}")

        for pt in rf[1:]:
            parts.append(f"L {f(*pt)}")
        parts.append(f"A {r_tip:.3f},{r_tip:.3f} 0 0 1 {f(*lf[0])}")
        for pt in lf[1:]:
            parts.append(f"L {f(*pt)}")

    parts.append("Z")
    return " ".join(parts)


def gear(cx, cy, body_r=11, tooth_w=6, tooth_len=14, hole_r=4.5,
         body_color=GLYPH_WHITE, hole_color="#ffffff", n_teeth=8):
    """Shared gear glyph: body + radiating teeth + colored center hole.

    Teeth are emitted as pre-rotated <polygon> points (not SVG transforms)
    so they rasterize identically in every renderer, including simple
    SVG-to-PNG tools that don't support transform="rotate(...)".
    """
    x_l, x_r = cx - tooth_w / 2, cx + tooth_w / 2
    y_top = cy - body_r - (tooth_len - body_r * 0.35)
    y_bot = cy - body_r + body_r * 0.35
    corners = [(x_l, y_top), (x_r, y_top), (x_r, y_bot), (x_l, y_bot)]

    teeth = []
    for i in range(n_teeth):
        rad = math.radians(360 / n_teeth * i)
        cos_a, sin_a = math.cos(rad), math.sin(rad)
        pts = []
        for px, py in corners:
            dx, dy = px - cx, py - cy
            nx = cx + dx * cos_a - dy * sin_a
            ny = cy + dx * sin_a + dy * cos_a
            pts.append(f"{nx:.2f},{ny:.2f}")
        teeth.append(f'<polygon points="{" ".join(pts)}" fill="{body_color}"/>')

    return (
        f'<circle cx="{cx}" cy="{cy}" r="{body_r}" fill="{body_color}"/>\n    '
        + "\n    ".join(teeth)
        + f'\n    <circle cx="{cx}" cy="{cy}" r="{hole_r}" fill="{hole_color}"/>'
    )


def grid_squares(x0, y0, n=3, cell=10, gap=2.5, color=GLYPH_WHITE, opacity=1):
    cells = []
    for row in range(n):
        for col in range(n):
            x = x0 + col * (cell + gap)
            y = y0 + row * (cell + gap)
            cells.append(
                f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="1.2" '
                f'fill="{color}" opacity="{opacity}"/>'
            )
    return "\n    ".join(cells)


def power_badge(cx, cy, r, badge_color, glyph_color=GLYPH_WHITE):
    """Corner emblem: filled circle + power on/off glyph. Stroke scales with r."""
    gr = r * 0.5
    sw = r * 0.19   # ≈1.7 at r=9, ≈2.5 at r=13
    return f"""<circle cx="{cx}" cy="{cy}" r="{r}" fill="{badge_color}"/>
    <line x1="{cx}" y1="{cy - gr - 0.5}" x2="{cx}" y2="{cy - gr * 0.15}" stroke="{glyph_color}" stroke-width="{sw:.2f}" stroke-linecap="round"/>
    <path d="M{cx - gr * 0.72:.1f} {cy - gr * 0.35:.1f} A{gr:.1f} {gr:.1f} 0 1 0 {cx + gr * 0.72:.1f} {cy - gr * 0.35:.1f}" fill="none" stroke="{glyph_color}" stroke-width="{sw:.2f}" stroke-linecap="round"/>"""


def gear_badge(cx, cy, r, badge_color, glyph_color=GLYPH_WHITE):
    """Small corner emblem: filled circle + mini gear glyph."""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{badge_color}"/>\n    ' + gear(
        cx, cy, body_r=r * 0.62, tooth_w=r * 0.34, tooth_len=r * 0.8,
        hole_r=r * 0.26, body_color=glyph_color, hole_color=badge_color, n_teeth=8
    )


def full_svg_hover(name, c0, c1, glyph):
    """Hover state: slightly lighter badge, stronger top highlight, +2% scale."""
    grad_id = f"g_{name}"
    x0, x1 = 2 + R, 62 - R
    S = SCALE_HOVER
    body = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="128" height="128">
  <linearGradient id="{grad_id}" gradientUnits="userSpaceOnUse" x1="2" y1="2" x2="62" y2="62">
    <stop offset="0" stop-color="{c0}"/>
    <stop offset="1" stop-color="{c1}"/>
  </linearGradient>
  <g transform="translate(32,32) scale({S}) translate(-32,-32)">
  <rect x="2" y="2" width="60" height="60" rx="{R}" fill="url(#{grad_id})"/>
  <path d="M{x0} 3.3 H{x1}" stroke="#ffffff" stroke-opacity="0.40" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M{x0} 60.7 H{x1}" stroke="#000000" stroke-opacity="0.12" stroke-width="1.4" stroke-linecap="round"/>
  <rect x="2" y="2" width="60" height="60" rx="{R}" fill="none" stroke="#000000" stroke-opacity="0.10" stroke-width="1.2"/>
  {glyph}
  </g>
</svg>"""
    with open(os.path.join(SVG_DIR, f"{name}.svg"), "w") as f:
        f.write(body)


def full_svg_pressed(name, c0, c1, glyph):
    """Pressed/active state: 5% smaller than normal (via SVG scale), reversed bevel + gradient."""
    grad_id = f"g_{name}"
    x0, x1 = 2 + R, 62 - R
    S = SCALE_PRESSED
    body = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="128" height="128">
  <linearGradient id="{grad_id}" gradientUnits="userSpaceOnUse" x1="62" y1="62" x2="2" y2="2">
    <stop offset="0" stop-color="{c0}"/>
    <stop offset="1" stop-color="{c1}"/>
  </linearGradient>
  <g transform="translate(32,32) scale({S}) translate(-32,-32)">
  <rect x="2" y="2" width="60" height="60" rx="{R}" fill="url(#{grad_id})"/>
  <path d="M{x0} 3.3 H{x1}" stroke="#000000" stroke-opacity="0.22" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M{x0} 60.7 H{x1}" stroke="#ffffff" stroke-opacity="0.18" stroke-width="1.4" stroke-linecap="round"/>
  <rect x="2" y="2" width="60" height="60" rx="{R}" fill="none" stroke="#000000" stroke-opacity="0.18" stroke-width="1.2"/>
  {glyph}
  </g>
</svg>"""
    with open(os.path.join(SVG_DIR, f"{name}.svg"), "w") as f:
        f.write(body)


def full_svg_shadow(name, c0, c1, glyph):
    """Normal state with feDropShadow restored — for browser-only comparison."""
    grad_id   = f"g_{name}"
    filter_id = f"ds_{name}"
    x0, x1 = 2 + R, 62 - R
    body = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="128" height="128">
  <linearGradient id="{grad_id}" gradientUnits="userSpaceOnUse" x1="2" y1="2" x2="62" y2="62">
    <stop offset="0" stop-color="{c0}"/>
    <stop offset="1" stop-color="{c1}"/>
  </linearGradient>
  <defs>
    <filter id="{filter_id}" x="-25%" y="-25%" width="150%" height="150%">
      <feDropShadow dx="0" dy="1.1" stdDeviation="0.8" flood-opacity="0.38"/>
    </filter>
  </defs>
  <g filter="url(#{filter_id})">
    <rect x="2" y="2" width="60" height="60" rx="{R}" fill="url(#{grad_id})"/>
  </g>
  <path d="M{x0} 3.3 H{x1}" stroke="#ffffff" stroke-opacity="0.22" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M{x0} 60.7 H{x1}" stroke="#000000" stroke-opacity="0.18" stroke-width="1.4" stroke-linecap="round"/>
  <rect x="2" y="2" width="60" height="60" rx="{R}" fill="none" stroke="#000000" stroke-opacity="0.12" stroke-width="1.2"/>
  {glyph}
</svg>"""
    with open(os.path.join(SVG_DIR, f"{name}_shadow.svg"), "w") as f:
        f.write(body)


def full_svg(name, c0, c1, glyph):
    grad_id = f"g_{name}"
    x0, x1 = 2 + R, 62 - R
    S = SCALE_NORMAL
    body = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="128" height="128">
  <linearGradient id="{grad_id}" gradientUnits="userSpaceOnUse" x1="2" y1="2" x2="62" y2="62">
    <stop offset="0" stop-color="{c0}"/>
    <stop offset="1" stop-color="{c1}"/>
  </linearGradient>
  <g transform="translate(32,32) scale({S}) translate(-32,-32)">
  <rect x="2" y="2" width="60" height="60" rx="{R}" fill="url(#{grad_id})"/>
  <path d="M{x0} 3.3 H{x1}" stroke="#ffffff" stroke-opacity="0.22" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M{x0} 60.7 H{x1}" stroke="#000000" stroke-opacity="0.18" stroke-width="1.4" stroke-linecap="round"/>
  <rect x="2" y="2" width="60" height="60" rx="{R}" fill="none" stroke="#000000" stroke-opacity="0.12" stroke-width="1.2"/>
  {glyph}
  </g>
</svg>"""
    with open(os.path.join(SVG_DIR, f"{name}.svg"), "w") as f:
        f.write(body)





icons = {}

icons["folder_open"] = dict(
    grad=("#6E9CC4", "#3B6693"),
    glyph=f"""
    <!-- Back panel: white@0.42 pre-blended over badge mid #5885af → #9eb8d1 -->
    <path d="M14 47 V19 Q14 17 16 17 H28 L33 24 H50 Q52 24 52 26 V47 Z" fill="#9eb8d1"/>
    <!-- Stroke the tab outline -->
    <path d="M14 19 Q14 17 16 17 H28 L33 24 H50 Q52 24 52 26" fill="none" stroke="{GLYPH_WHITE}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
    <!-- Crease line: #3b6693@0.35 pre-blended over #9eb8d1 → #7b9bbb -->
    <line x1="14" y1="28" x2="52" y2="28" stroke="#7b9bbb" stroke-width="1.1"/>
    <!-- Front panel (open folder face) -->
    <path d="M11 29 H53 L49.5 48.5 Q49 50 47 50 H17 Q15 50 14.5 48.5 Z" fill="{GLYPH_WHITE}"/>
    """
)

icons["file_open"] = dict(
    grad=("#6E9CC4", "#3B6693"),
    glyph=f"""
    <path d="M18 12 h17 l9 9 v27 a1.5 1.5 0 0 1 -3 3 H18 a1.5 1.5 0 0 1 -3 -3 V15 a1.5 1.5 0 0 1 3 -3z" fill="{GLYPH_WHITE}"/>
    <path d="M35 12 v9 h9 z" fill="{GLYPH_WHITE}" opacity="0.55"/>
    <rect x="20" y="30" width="19" height="3" rx="0.8" fill="#3B6693"/>
    <rect x="20" y="37" width="19" height="3" rx="0.8" fill="#3B6693"/>
    <rect x="20" y="44" width="12" height="3" rx="0.8" fill="#3B6693"/>
    """
)

icons["new_document"] = dict(
    grad=("#6E9CC4", "#3B6693"),
    glyph=f"""
    <path d="M17 12 h16 l9 9 v27 a1.5 1.5 0 0 1 -3 3 H17 a1.5 1.5 0 0 1 -3 -3 V15 a1.5 1.5 0 0 1 3 -3z" fill="{GLYPH_WHITE}"/>
    <path d="M33 12 v9 h9 z" fill="{GLYPH_WHITE}" opacity="0.55"/>
    <rect x="19" y="42" width="16" height="3" rx="0.8" fill="#3B6693"/>
    <circle cx="40" cy="42" r="11" fill="#3B6693"/>
    <rect x="35.5" y="37.5" width="9" height="3" rx="0.6" fill="{GLYPH_WHITE}"/>
    <rect x="38.5" y="34.5" width="3" height="9" rx="0.6" fill="{GLYPH_WHITE}"/>
    """
)

icons["save"] = dict(
    grad=("#6E9CC4", "#3B6693"),
    glyph=f"""
    <path d="M15 12 h26 l7 7 v29 a1.5 1.5 0 0 1 -3 3 H15 a1.5 1.5 0 0 1 -3 -3 V15 a1.5 1.5 0 0 1 3 -3z" fill="{GLYPH_WHITE}"/>
    <path d="M22 12 h14 v10 a1 1 0 0 1 -2 2 H24 a1 1 0 0 1 -2 -2 z" fill="#3B6693" opacity="0.85"/>
    <rect x="26" y="12" width="4" height="7" fill="{GLYPH_WHITE}"/>
    <rect x="19" y="34" width="26" height="17" rx="1" fill="#3B6693" opacity="0.85"/>
    <rect x="23" y="38" width="18" height="9" rx="0.8" fill="{GLYPH_WHITE}"/>
    """
)

icons["close"] = dict(
    grad=("#C97B72", "#9C433B"),
    glyph=f"""
    <line x1="21" y1="21" x2="43" y2="43" stroke="{GLYPH_WHITE}" stroke-width="6" stroke-linecap="round"/>
    <line x1="43" y1="21" x2="21" y2="43" stroke="{GLYPH_WHITE}" stroke-width="6" stroke-linecap="round"/>
    """
)

icons["exit"] = dict(
    grad=("#C97B72", "#9C433B"),
    glyph=f"""
    <!-- Door body: white@0.45 pre-blended over red badge mid #b5635a → #d6a9a4 -->
    <path d="M16 14 h16 v36 h-16 a1.5 1.5 0 0 1 -3 -3 V17 a1.5 1.5 0 0 1 3 -3z" fill="#d6a9a4"/>
    <!-- Door outline -->
    <rect x="16" y="14" width="16" height="36" rx="0.8" fill="none" stroke="{GLYPH_WHITE}" stroke-width="2.5"/>
    <!-- Door panels: full white (thin stroke provides subtlety, no opacity needed) -->
    <rect x="18.5" y="16.5" width="11" height="12" rx="0.6" fill="none" stroke="{GLYPH_WHITE}" stroke-width="1.2"/>
    <rect x="18.5" y="31.5" width="11" height="16" rx="0.6" fill="none" stroke="{GLYPH_WHITE}" stroke-width="1.2"/>
    <!-- Doorknob -->
    <circle cx="29" cy="28" r="1.8" fill="{GLYPH_WHITE}"/>
    <!-- Exit arrow -->
    <line x1="26" y1="32" x2="49" y2="32" stroke="{GLYPH_WHITE}" stroke-width="4.5" stroke-linecap="round"/>
    <path d="M41 23 L50 32 L41 41" fill="none" stroke="{GLYPH_WHITE}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>
    """
)

icons["info"] = dict(
    grad=("#6E9CC4", "#3B6693"),
    glyph=f"""
    <circle cx="32" cy="21.5" r="4.2" fill="{GLYPH_WHITE}"/>
    <rect x="27.5" y="29" width="9" height="19" rx="1.8" fill="{GLYPH_WHITE}"/>
    """
)

icons["help"] = dict(
    grad=("#6E9CC4", "#3B6693"),
    glyph=f"""
    <path d="M24 24.5 a8.5 8 0 1 1 13.2 6.6 c-2.6 1.9 -4.2 3.4 -4.2 6.4 v1" fill="none" stroke="{GLYPH_WHITE}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="32" cy="46" r="4.3" fill="{GLYPH_WHITE}"/>
    """
)

icons["placement"] = dict(
    grad=("#6E9CC4", "#3B6693"),
    glyph=f"""
    <!-- Block 1: left, already placed -->
    <polygon points="13,40 22,35 31,40 22,45" fill="#ffffff"/>
    <polygon points="13,40 22,45 22,52 13,47" fill="#d0dde9"/>
    <polygon points="31,40 22,45 22,52 31,47" fill="#9eb8d1"/>
    <!-- Block 2: right, already placed -->
    <polygon points="31,40 40,35 49,40 40,45" fill="#ffffff"/>
    <polygon points="31,40 40,45 40,52 31,47" fill="#d0dde9"/>
    <polygon points="49,40 40,45 40,52 49,47" fill="#9eb8d1"/>
    <!-- Target slot: dashed outline where block 3 will land on top of block 2 -->
    <polygon points="31,29 40,24 49,29 40,34" fill="none" stroke="#d0dde9" stroke-width="1.4" stroke-dasharray="2.5 2"/>
    <!-- Block 3: hovering above target slot, being placed -->
    <polygon points="31,16 40,11 49,16 40,21" fill="#ffffff"/>
    <polygon points="31,16 40,21 40,28 31,23" fill="#d0dde9"/>
    <polygon points="49,16 40,21 40,28 49,23" fill="#9eb8d1"/>
    <!-- Downward arrow -->
    <line x1="40" y1="28" x2="40" y2="32" stroke="{GLYPH_WHITE}" stroke-width="2.5" stroke-linecap="round"/>
    <path d="M37 30 L40 33 L43 30" fill="none" stroke="{GLYPH_WHITE}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
    """
)

icons["route"] = dict(
    grad=("#6E9CC4", "#3B6693"),
    glyph=f"""
    <circle cx="14" cy="48" r="5" fill="{GLYPH_WHITE}"/>
    <circle cx="50" cy="16" r="5" fill="{GLYPH_WHITE}"/>
    <polyline points="14,48 21,48 31,38 31,26 41,16 50,16" fill="none" stroke="{GLYPH_WHITE}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>
    """
)

icons["move"] = dict(
    grad=("#6E9CC4", "#3B6693"),
    glyph=f"""
    <line x1="32" y1="14" x2="32" y2="50" stroke="{GLYPH_WHITE}" stroke-width="4.5" stroke-linecap="round"/>
    <line x1="14" y1="32" x2="50" y2="32" stroke="{GLYPH_WHITE}" stroke-width="4.5" stroke-linecap="round"/>
    <path d="M32 14 L26 21 M32 14 L38 21" stroke="{GLYPH_WHITE}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
    <path d="M32 50 L26 43 M32 50 L38 43" stroke="{GLYPH_WHITE}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
    <path d="M14 32 L21 26 M14 32 L21 38" stroke="{GLYPH_WHITE}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
    <path d="M50 32 L43 26 M50 32 L43 38" stroke="{GLYPH_WHITE}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
    """
)

icons["delete"] = dict(
    grad=("#C97B72", "#9C433B"),
    glyph=f"""
    <rect x="16" y="21" width="32" height="4" rx="1" fill="{GLYPH_WHITE}"/>
    <path d="M25 21 v-3 a1.5 1.5 0 0 1 3 -3 h8 a1.5 1.5 0 0 1 3 3 v3" fill="none" stroke="{GLYPH_WHITE}" stroke-width="3.6"/>
    <path d="M19.5 25 h25 l-2.6 24.3 a1.8 1.8 0 0 1 -3.5 3.2 H25.6 a1.8 1.8 0 0 1 -3.5 -3.2z" fill="{GLYPH_WHITE}"/>
    <line x1="27" y1="31" x2="27" y2="45" stroke="#9C433B" stroke-width="3" stroke-linecap="round"/>
    <line x1="32" y1="31" x2="32" y2="45" stroke="#9C433B" stroke-width="3" stroke-linecap="round"/>
    <line x1="37" y1="31" x2="37" y2="45" stroke="#9C433B" stroke-width="3" stroke-linecap="round"/>
    """
)


# --- shared "configuration" family: settings -> grid settings -> grid on/off
# all three reuse the same gear() and/or grid_squares() building blocks so
# the visual language carries across the set.

_c0, _c1 = "#6E9CC4", "#3B6693"
icons["settings"] = dict(
    grad=(_c0, _c1),
    glyph=f"""
    <path d="{involute_gear_path(32, 32, n=8, r_pitch=15.5, pressure_deg=20,
                                  addendum=3.2, dedendum=3.2, n_pts=12)}"
          fill="{GLYPH_WHITE}"/>
    <circle cx="32" cy="32" r="6.0" fill="{_c1}"/>
    """
)

_gs_gear = involute_gear_path(43, 43, n=8, r_pitch=11, pressure_deg=20,
                               addendum=2.5, dedendum=2.5, n_pts=10)
icons["grid_settings"] = dict(
    grad=(_c0, _c1),
    glyph=f"""
    {grid_squares(10, 10, n=3, cell=13, gap=3, color="#d0dde9")}
    <path d="{_gs_gear}" fill="none" stroke="{_c1}" stroke-width="5" stroke-linejoin="round"/>
    <path d="{_gs_gear}" fill="{GLYPH_WHITE}"/>
    <circle cx="43" cy="43" r="4.5" fill="{_c1}"/>
    """
)

icons["grid_on_off"] = dict(
    grad=(_c0, _c1),
    glyph=f"""
    {grid_squares(10, 10, n=3, cell=13, gap=3, color="#d0dde9")}
    {power_badge(43, 43, 12, badge_color=_c1)}
    """
)

_c0, _c1 = "#6E9CC4", "#3B6693"
icons["preferences"] = dict(
    grad=(_c0, _c1),
    glyph=f"""
    <line x1="14" y1="21" x2="50" y2="21" stroke="#9ab5ce" stroke-width="3" stroke-linecap="round"/>
    <line x1="14" y1="21" x2="29" y2="21" stroke="{GLYPH_WHITE}" stroke-width="3" stroke-linecap="round"/>
    <circle cx="29" cy="21" r="5.5" fill="{GLYPH_WHITE}"/>
    <circle cx="29" cy="21" r="2" fill="{_c1}"/>
    <line x1="14" y1="32" x2="50" y2="32" stroke="#9ab5ce" stroke-width="3" stroke-linecap="round"/>
    <line x1="14" y1="32" x2="42" y2="32" stroke="{GLYPH_WHITE}" stroke-width="3" stroke-linecap="round"/>
    <circle cx="42" cy="32" r="5.5" fill="{GLYPH_WHITE}"/>
    <circle cx="42" cy="32" r="2" fill="{_c1}"/>
    <line x1="14" y1="43" x2="50" y2="43" stroke="#9ab5ce" stroke-width="3" stroke-linecap="round"/>
    <line x1="14" y1="43" x2="22" y2="43" stroke="{GLYPH_WHITE}" stroke-width="3" stroke-linecap="round"/>
    <circle cx="22" cy="43" r="5.5" fill="{GLYPH_WHITE}"/>
    <circle cx="22" cy="43" r="2" fill="{_c1}"/>
    """
)

# ── Alignment icons ────────────────────────────────────────────────────────
# Rect fill: white@0.72 pre-blended over badge mid (#5885af) → #d0dde9
# This keeps rects visually distinct from the bright-white alignment line/bracket
# without relying on SVG opacity (which IM renders unreliably).
_c0, _c1 = "#6E9CC4", "#3B6693"
# Pre-blended fills over badge mid ≈ #5884AF:
#   R_LT = white@0.72 → #d0dde9  (lighter, "front" block)
#   R_DK = white@0.42 → #9eb8d1  (darker,  "back"  block)
#   R_SK = #3b6693@0.35 over #9eb8d1 → #7b9bbb (rect outline stroke)
R_LT = "#d0dde9"
R_DK = "#9eb8d1"
R_SK = "#7b9bbb"
SW   = "0.8"       # rect stroke-width
LW   = "2.5"       # alignment guide line stroke-width

# Horizontal alignment (line = vertical guide, rects aligned to it)
# Rect outlines make each block read as a distinct shape.
icons["align_left"] = dict(grad=(_c0, _c1), glyph=f"""
    <line x1="12" y1="9" x2="12" y2="53" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round"/>
    <rect x="12" y="12" width="30" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="12" y="25" width="20" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="12" y="38" width="26" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

icons["align_center"] = dict(grad=(_c0, _c1), glyph=f"""
    <line x1="32" y1="9" x2="32" y2="53" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round"/>
    <rect x="17" y="12" width="30" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="22" y="25" width="20" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="19" y="38" width="26" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

icons["align_right"] = dict(grad=(_c0, _c1), glyph=f"""
    <line x1="52" y1="9" x2="52" y2="53" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round"/>
    <rect x="22" y="12" width="30" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="32" y="25" width="20" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="26" y="38" width="26" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

# Vertical alignment (line = horizontal guide, rects aligned to it)
icons["align_top"] = dict(grad=(_c0, _c1), glyph=f"""
    <line x1="9" y1="12" x2="53" y2="12" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round"/>
    <rect x="11" y="12" width="11" height="28" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="26" y="12" width="11" height="18" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="41" y="12" width="11" height="24" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

icons["align_mid"] = dict(grad=(_c0, _c1), glyph=f"""
    <line x1="9" y1="32" x2="53" y2="32" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round"/>
    <rect x="11" y="18" width="11" height="28" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="26" y="23" width="11" height="18" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="41" y="20" width="11" height="24" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

icons["align_bottom"] = dict(grad=(_c0, _c1), glyph=f"""
    <line x1="9" y1="52" x2="53" y2="52" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round"/>
    <rect x="11" y="24" width="11" height="28" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="26" y="34" width="11" height="18" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="41" y="28" width="11" height="24" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

# Corner alignment icons — 8 total: 4 positions × 2 ordering modes.
# _hv: horizontal (wide/short) block is "first" — flush against bracket corner,
#      R_LT (lighter). Vertical block is secondary, R_DK, in the remaining slot.
# _vh: vertical (narrow/tall) block is "first" — flush against bracket corner,
#      R_LT (lighter). Horizontal block is secondary, R_DK, in the remaining slot.
# Block POSITIONS differ between _hv and _vh, not just fill colors.

_BR = "{LW}"  # bracket stroke-width alias already defined

# upper-left
_ul_bracket = f'<path d="M11 27 L11 11 L27 11" fill="none" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round"/>'
_ul_wide   = 'x="14" y="14" width="30" height="13"'
_ul_narrow = 'x="14" y="29" width="13" height="23"'
icons["align_upper_left_hv"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ul_bracket}
    <rect {_ul_wide}   rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect {_ul_narrow} rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
""")
icons["align_upper_left_vh"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ul_bracket}
    <rect x="29" y="14" width="15" height="13" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="14" y="14" width="13" height="38" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

# upper-right
_ur_bracket = f'<path d="M37 11 L53 11 L53 27" fill="none" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round"/>'
_ur_wide   = 'x="20" y="14" width="30" height="13"'
_ur_narrow = 'x="37" y="29" width="13" height="23"'
icons["align_upper_right_hv"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ur_bracket}
    <rect {_ur_wide}   rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect {_ur_narrow} rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
""")
icons["align_upper_right_vh"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ur_bracket}
    <rect x="20" y="14" width="15" height="13" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="37" y="14" width="13" height="38" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

# lower-left
_ll_bracket = f'<path d="M11 37 L11 53 L27 53" fill="none" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round"/>'
_ll_wide   = 'x="14" y="35" width="30" height="13"'
_ll_narrow = 'x="14" y="12" width="13" height="21"'
icons["align_lower_left_hv"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ll_bracket}
    <rect {_ll_wide}   rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect {_ll_narrow} rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
""")
icons["align_lower_left_vh"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ll_bracket}
    <rect x="29" y="35" width="15" height="13" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="14" y="12" width="13" height="38" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

# lower-right
_lr_bracket = f'<path d="M37 53 L53 53 L53 37" fill="none" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round"/>'
_lr_wide   = 'x="20" y="35" width="30" height="13"'
_lr_narrow = 'x="37" y="12" width="13" height="21"'
icons["align_lower_right_hv"] = dict(grad=(_c0,_c1), glyph=f"""
    {_lr_bracket}
    <rect {_lr_wide}   rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect {_lr_narrow} rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
""")
icons["align_lower_right_vh"] = dict(grad=(_c0,_c1), glyph=f"""
    {_lr_bracket}
    <rect x="20" y="35" width="15" height="13" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="37" y="12" width="13" height="38" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

# ── Corner alignment icons WITH diagonal arrival arrows ────────────────────
# Blocks are ~20% smaller than the plain corner icons to make room for the arrow.
# Arrow (half-scale) sits in the quadrant opposite the corner, pointing toward it.

def _small_arrow_pts(cx, cy, deg, scale=0.5):
    """Arrow polygon scaled to `scale` of standard size, centered at (cx,cy),
    pointing in direction `deg` degrees CW from straight-up."""
    pts_up = [
        (32, 10), (46, 30), (38, 30), (38, 54), (26, 54), (26, 30), (18, 30),
    ]
    rad = math.radians(deg)
    c, s = math.cos(rad), math.sin(rad)
    out = []
    for px, py in pts_up:
        dx, dy = (px - 32) * scale, (py - 32) * scale
        nx = cx + dx * c - dy * s
        ny = cy + dx * s + dy * c
        out.append(f"{nx:.1f},{ny:.1f}")
    return " ".join(out)

# upper-left with arrow (arrow in lower-right, pointing NW = 315°)
_ul_a_brkt  = f'<path d="M11 25 L11 11 L25 11" fill="none" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round"/>'
_ul_a_arrow = f'<polygon points="{_small_arrow_pts(44, 44, 315, 0.5)}" fill="{GLYPH_WHITE}"/>'
icons["align_upper_left_hv_arrow"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ul_a_brkt}
    {_ul_a_arrow}
    <rect x="14" y="14" width="22" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="14" y="26" width="10" height="17" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
""")
icons["align_upper_left_vh_arrow"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ul_a_brkt}
    {_ul_a_arrow}
    <rect x="26" y="14" width="12" height="10" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="14" y="14" width="10" height="28" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

# upper-right with arrow (arrow in lower-left, pointing NE = 45°)
_ur_a_brkt  = f'<path d="M39 11 L53 11 L53 25" fill="none" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round"/>'
_ur_a_arrow = f'<polygon points="{_small_arrow_pts(21, 44, 45, 0.5)}" fill="{GLYPH_WHITE}"/>'
icons["align_upper_right_hv_arrow"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ur_a_brkt}
    {_ur_a_arrow}
    <rect x="28" y="14" width="22" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="40" y="26" width="10" height="17" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
""")
icons["align_upper_right_vh_arrow"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ur_a_brkt}
    {_ur_a_arrow}
    <rect x="28" y="14" width="12" height="10" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="40" y="14" width="10" height="28" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

# lower-left with arrow (arrow in upper-right, pointing SW = 225°)
_ll_a_brkt  = f'<path d="M11 39 L11 53 L25 53" fill="none" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round"/>'
_ll_a_arrow = f'<polygon points="{_small_arrow_pts(44, 20, 225, 0.5)}" fill="{GLYPH_WHITE}"/>'
icons["align_lower_left_hv_arrow"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ll_a_brkt}
    {_ll_a_arrow}
    <rect x="14" y="38" width="22" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="14" y="16" width="10" height="20" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
""")
icons["align_lower_left_vh_arrow"] = dict(grad=(_c0,_c1), glyph=f"""
    {_ll_a_brkt}
    {_ll_a_arrow}
    <rect x="26" y="38" width="12" height="10" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="14" y="16" width="10" height="32" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

# lower-right with arrow (arrow in upper-left, pointing SE = 135°)
_lr_a_brkt  = f'<path d="M39 53 L53 53 L53 39" fill="none" stroke="{GLYPH_WHITE}" stroke-width="{LW}" stroke-linecap="round" stroke-linejoin="round"/>'
_lr_a_arrow = f'<polygon points="{_small_arrow_pts(20, 20, 135, 0.5)}" fill="{GLYPH_WHITE}"/>'
icons["align_lower_right_hv_arrow"] = dict(grad=(_c0,_c1), glyph=f"""
    {_lr_a_brkt}
    {_lr_a_arrow}
    <rect x="28" y="38" width="22" height="10" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="40" y="16" width="10" height="20" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
""")
icons["align_lower_right_vh_arrow"] = dict(grad=(_c0,_c1), glyph=f"""
    {_lr_a_brkt}
    {_lr_a_arrow}
    <rect x="26" y="38" width="12" height="10" rx="1.5" fill="{R_DK}" stroke="{R_SK}" stroke-width="{SW}"/>
    <rect x="40" y="16" width="10" height="32" rx="1.5" fill="{R_LT}" stroke="{R_SK}" stroke-width="{SW}"/>
""")

# ── Directional arrow icons ─────────────────────────────────────────────────
# Arrow polygon defined pointing UP, then rotated CW for each of 8 directions.
# CW rotation in SVG (y-down) around center (32,32):
#   nx = 32 + dx*cos(θ) - dy*sin(θ)
#   ny = 32 + dx*sin(θ) + dy*cos(θ)
def _arrow_pts(deg):
    pts_up = [
        (32, 10),  # tip
        (46, 30),  # right flare
        (38, 30),  # right inner notch
        (38, 54),  # shaft BR
        (26, 54),  # shaft BL
        (26, 30),  # left inner notch
        (18, 30),  # left flare
    ]
    rad = math.radians(deg)
    c, s = math.cos(rad), math.sin(rad)
    cx, cy = 32.0, 32.0
    out = []
    for px, py in pts_up:
        dx, dy = px - cx, py - cy
        nx = cx + dx * c - dy * s
        ny = cy + dx * s + dy * c
        out.append(f"{nx:.1f},{ny:.1f}")
    return " ".join(out)

_ac0, _ac1 = "#6E9CC4", "#3B6693"
_dirs = [
    ("arrow_up",         0),
    ("arrow_up_right",  45),
    ("arrow_right",     90),
    ("arrow_down_right",135),
    ("arrow_down",      180),
    ("arrow_down_left", 225),
    ("arrow_left",      270),
    ("arrow_up_left",   315),
]
for _name, _deg in _dirs:
    icons[_name] = dict(
        grad=(_ac0, _ac1),
        glyph=f'<polygon points="{_arrow_pts(_deg)}" fill="{GLYPH_WHITE}"/>'
    )

# ── Undo ────────────────────────────────────────────────────────────────────
# Stroke-based path: upper arm goes right, CW semicircle wraps the right side,
# shorter lower arm returns left and ends with a rounded cap (the tail).
# Arrowhead polygon covers the stroke end at the upper-left.
# Upper arm: y=22, from x=22 to x=44.  Arc r=9, center (44,31).
# Lower arm: returns to x=34 — shorter than upper, giving the tapered look.
icons["undo"] = dict(
    grad=(_ac0, _ac1),
    glyph=f"""
    <path d="M 22 22 H 44 A 9 9 0 0 1 44 40 H 34"
          fill="none" stroke="{GLYPH_WHITE}" stroke-width="6.5"
          stroke-linecap="round" stroke-linejoin="round"/>
    <polygon points="12,22 22,14 22,30" fill="{GLYPH_WHITE}"/>
    """
)

# ── Done (checkmark only) ────────────────────────────────────────────────────
# Bold white checkmark spanning the badge — no box.
icons["done"] = dict(
    grad=(_ac0, _ac1),
    glyph=f"""
    <path d="M 12 34 L 26 48 L 52 18"
          fill="none" stroke="{GLYPH_WHITE}" stroke-width="7"
          stroke-linecap="round" stroke-linejoin="round"/>
    """
)

# ── Search (magnifying glass) ────────────────────────────────────────────────
# Lens circle + diagonal handle going lower-right.
icons["search"] = dict(
    grad=(_ac0, _ac1),
    glyph=f"""
    <circle cx="27" cy="26" r="13" fill="none" stroke="{GLYPH_WHITE}" stroke-width="6.5"/>
    <line x1="36" y1="35" x2="52" y2="51"
          stroke="{GLYPH_WHITE}" stroke-width="6.5" stroke-linecap="round"/>
    """
)

# ── Stop (octagon) ───────────────────────────────────────────────────────────
# Standard stop-sign octagon, white stroke on gradient.
def _octagon_pts(cx, cy, r, start_deg=22.5):
    pts = []
    for k in range(8):
        ang = math.radians(start_deg + k * 45)
        pts.append(f"{cx + r * math.cos(ang):.1f},{cy + r * math.sin(ang):.1f}")
    return " ".join(pts)

icons["stop"] = dict(
    grad=("#D94F4F", "#A82020"),
    glyph=f"""
    <polygon points="{_octagon_pts(32, 32, 24)}"
             fill="none" stroke="{GLYPH_WHITE}" stroke-width="4"
             stroke-linejoin="round"/>
    """
)


# ── Drag (cursor dragging selection box, hot-spot at bottom-right corner) ─────
# Box occupies (8,8)-(40,40); right and bottom edges stop 8px before corner,
# leaving a gap. Crosshair floats at (40,40) in that gap. Cursor tip at (40,40).
# Fill is very light (much lighter than in-app rgba) so it reads against the gradient.
_drag_cursor = "40,40 40,56 44,52 47,59 49,57 46,50 51,50"
_drag_glyph_raw = f"""
    <rect x="8" y="8" width="32" height="32"
          fill="rgba(220,240,255,0.45)"/>
    <path d="M8,8 H40 V32 M8,8 V40 H32"
          fill="none" stroke="#0078D7" stroke-width="1.5" stroke-dasharray="3,2"
          stroke-linecap="square"/>
    <line x1="34" y1="40" x2="38" y2="40" stroke="{GLYPH_WHITE}" stroke-width="1.5"/>
    <line x1="42" y1="40" x2="46" y2="40" stroke="{GLYPH_WHITE}" stroke-width="1.5"/>
    <line x1="40" y1="34" x2="40" y2="38" stroke="{GLYPH_WHITE}" stroke-width="1.5"/>
    <line x1="40" y1="42" x2="40" y2="46" stroke="{GLYPH_WHITE}" stroke-width="1.5"/>
    <polygon points="{_drag_cursor}" fill="{GLYPH_WHITE}"
             stroke="{GLYPH_WHITE}" stroke-width="0.5" stroke-linejoin="round"/>
    """
icons["drag"] = dict(
    grad=(_c0, _c1),
    glyph=_drag_glyph_raw,
)

# ── Drag Region (wide button: 110×30, text + drag glyph) ─────────────────────
_BTN_W, _BTN_H = 110, 30
# Scale drag glyph (64-space) into the right ~28px of the button
_draw_region_text = text_to_svg_path("Draw Region", x_off=7, y_off=19, font_size=11)
_drag_region_glyph = f"""
    {_draw_region_text}
    <line x1="77" y1="4" x2="77" y2="26"
          stroke="{GLYPH_WHITE}" stroke-opacity="0.30" stroke-width="0.8"/>
    <g transform="translate(81,0) scale(0.4375)">
    {_drag_glyph_raw}
    </g>
    """
icons["draw_region"] = dict(
    grad=(_c0, _c1),
    glyph=_drag_region_glyph,
    wide=True, w=_BTN_W, h=_BTN_H,
)


def darken_hex(h, factor=0.78):
    h = h.lstrip('#')
    r, g, b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
    return f"#{int(r*factor):02x}{int(g*factor):02x}{int(b*factor):02x}"

def lighten_hex(h, factor=1.08):
    h = h.lstrip('#')
    r, g, b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
    return f"#{min(255,int(r*factor)):02x}{min(255,int(g*factor)):02x}{min(255,int(b*factor)):02x}"


def wide_svg(name, c0, c1, glyph, w=110, h=30, rx=5):
    """Normal state for a wide (non-square) button badge."""
    grad_id = f"g_{name}"
    cx, cy = w / 2, h / 2
    S = SCALE_NORMAL
    x0, x1 = rx, w - rx
    body = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w*2}" height="{h*2}">
  <linearGradient id="{grad_id}" gradientUnits="userSpaceOnUse" x1="{cx}" y1="1" x2="{cx}" y2="{h-1}">
    <stop offset="0" stop-color="{c0}"/>
    <stop offset="1" stop-color="{c1}"/>
  </linearGradient>
  <g transform="translate({cx},{cy}) scale({S}) translate(-{cx},-{cy})">
  <rect x="1" y="1" width="{w-2}" height="{h-2}" rx="{rx}" fill="url(#{grad_id})"/>
  <path d="M{x0} 2.0 H{x1}" stroke="#ffffff" stroke-opacity="0.22" stroke-width="1.0" stroke-linecap="round"/>
  <path d="M{x0} {h-2.0:.1f} H{x1}" stroke="#000000" stroke-opacity="0.18" stroke-width="1.0" stroke-linecap="round"/>
  <rect x="1" y="1" width="{w-2}" height="{h-2}" rx="{rx}" fill="none" stroke="#000000" stroke-opacity="0.12" stroke-width="0.8"/>
  {glyph}
  </g>
</svg>"""
    with open(os.path.join(SVG_DIR, f"{name}.svg"), "w") as f:
        f.write(body)


def wide_svg_hover(name, c0, c1, glyph, w=110, h=30, rx=5):
    """Hover state for a wide button badge."""
    grad_id = f"g_{name}"
    cx, cy = w / 2, h / 2
    S = SCALE_HOVER
    x0, x1 = rx, w - rx
    body = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w*2}" height="{h*2}">
  <linearGradient id="{grad_id}" gradientUnits="userSpaceOnUse" x1="{cx}" y1="1" x2="{cx}" y2="{h-1}">
    <stop offset="0" stop-color="{c0}"/>
    <stop offset="1" stop-color="{c1}"/>
  </linearGradient>
  <g transform="translate({cx},{cy}) scale({S}) translate(-{cx},-{cy})">
  <rect x="1" y="1" width="{w-2}" height="{h-2}" rx="{rx}" fill="url(#{grad_id})"/>
  <path d="M{x0} 2.0 H{x1}" stroke="#ffffff" stroke-opacity="0.40" stroke-width="1.0" stroke-linecap="round"/>
  <path d="M{x0} {h-2.0:.1f} H{x1}" stroke="#000000" stroke-opacity="0.12" stroke-width="1.0" stroke-linecap="round"/>
  <rect x="1" y="1" width="{w-2}" height="{h-2}" rx="{rx}" fill="none" stroke="#000000" stroke-opacity="0.10" stroke-width="0.8"/>
  {glyph}
  </g>
</svg>"""
    with open(os.path.join(SVG_DIR, f"{name}.svg"), "w") as f:
        f.write(body)


def wide_svg_pressed(name, c0, c1, glyph, w=110, h=30, rx=5):
    """Pressed state for a wide button badge."""
    grad_id = f"g_{name}"
    cx, cy = w / 2, h / 2
    S = SCALE_PRESSED
    x0, x1 = rx, w - rx
    body = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w*2}" height="{h*2}">
  <linearGradient id="{grad_id}" gradientUnits="userSpaceOnUse" x1="{cx}" y1="{h-1}" x2="{cx}" y2="1">
    <stop offset="0" stop-color="{c0}"/>
    <stop offset="1" stop-color="{c1}"/>
  </linearGradient>
  <g transform="translate({cx},{cy}) scale({S}) translate(-{cx},-{cy})">
  <rect x="1" y="1" width="{w-2}" height="{h-2}" rx="{rx}" fill="url(#{grad_id})"/>
  <path d="M{x0} 2.0 H{x1}" stroke="#000000" stroke-opacity="0.22" stroke-width="1.0" stroke-linecap="round"/>
  <path d="M{x0} {h-2.0:.1f} H{x1}" stroke="#ffffff" stroke-opacity="0.18" stroke-width="1.0" stroke-linecap="round"/>
  <rect x="1" y="1" width="{w-2}" height="{h-2}" rx="{rx}" fill="none" stroke="#000000" stroke-opacity="0.18" stroke-width="0.8"/>
  {glyph}
  </g>
</svg>"""
    with open(os.path.join(SVG_DIR, f"{name}.svg"), "w") as f:
        f.write(body)


# ── Labels for HTML preview ───────────────────────────────────────────────────
LABELS = {
    "folder_open": "Folder open",   "file_open": "File open",
    "new_document": "New document", "save": "Save",
    "close": "Close",               "exit": "Exit",
    "info": "Info",                 "help": "Help",
    "placement": "Placement",       "route": "Route",
    "move": "Move",                 "delete": "Delete",
    "settings": "Settings",         "preferences": "Preferences",
    "grid_settings": "Grid settings","grid_on_off": "Grid on/off",
    "align_left": "Align left",     "align_center": "Align center",
    "align_right": "Align right",   "align_top": "Align top",
    "align_mid": "Align mid",       "align_bottom": "Align bottom",
    "align_upper_left_hv":  "UL H->V",  "align_upper_left_vh":  "UL V->H",
    "align_upper_right_hv": "UR H->V",  "align_upper_right_vh": "UR V->H",
    "align_lower_left_hv":  "LL H->V",  "align_lower_left_vh":  "LL V->H",
    "align_lower_right_hv": "LR H->V",  "align_lower_right_vh": "LR V->H",
    "align_upper_left_hv_arrow":  "UL H->V arrow", "align_upper_left_vh_arrow":  "UL V->H arrow",
    "align_upper_right_hv_arrow": "UR H->V arrow", "align_upper_right_vh_arrow": "UR V->H arrow",
    "align_lower_left_hv_arrow":  "LL H->V arrow", "align_lower_left_vh_arrow":  "LL V->H arrow",
    "align_lower_right_hv_arrow": "LR H->V arrow", "align_lower_right_vh_arrow": "LR V->H arrow",
    "arrow_up": "Arrow up",         "arrow_up_right": "Arrow up right",
    "arrow_right": "Arrow right",   "arrow_down_right": "Arrow down right",
    "arrow_down": "Arrow down",     "arrow_down_left": "Arrow down left",
    "arrow_left": "Arrow left",     "arrow_up_left": "Arrow up left",
    "undo": "Undo",                 "done": "Done",
    "search": "Search",             "stop": "Stop",
    "drag": "Drag",                 "draw_region": "Draw region",
}

# ── Generate SVGs ─────────────────────────────────────────────────────────────
for name, spec in icons.items():
    c0, c1 = spec["grad"]
    glyph = spec["glyph"]
    if spec.get("wide"):
        w, h = spec.get("w", 110), spec.get("h", 30)
        wide_svg(name, c0, c1, glyph, w, h)
        wide_svg_hover(f"{name}_hover", lighten_hex(c0), lighten_hex(c1), glyph, w, h)
        wide_svg_pressed(f"{name}_pressed", darken_hex(c0, 0.95), darken_hex(c1, 0.95), glyph, w, h)
    else:
        full_svg(name, c0, c1, glyph)
        full_svg_hover(f"{name}_hover", lighten_hex(c0), lighten_hex(c1), glyph)
        full_svg_pressed(f"{name}_pressed", darken_hex(c0, 0.95), darken_hex(c1, 0.95), glyph)

# ── Generate icon_preview.html ────────────────────────────────────────────────
PREVIEW_DIR = os.path.join(OUT, "preview")
os.makedirs(PREVIEW_DIR, exist_ok=True)
PREVIEW_OUT = os.path.join(PREVIEW_DIR, "icon_preview.html")
DETAIL_OUT  = os.path.join(PREVIEW_DIR, "icon_detail.html")

cards = []
for name, spec in icons.items():
    label = LABELS.get(name, name.replace("_", " ").title())
    if spec.get("wide"):
        w, h = spec.get("w", 110), spec.get("h", 30)
        img_style = f' style="width:{w}px;height:{h}px"'
        card_class = "card widecard"
    else:
        img_style = ""
        card_class = "card"
    cards.append(
        f'    <div class="{card_class}" data-icon="{name}" data-label="{label}">\n'
        f'      <img src="../svg/{name}.svg" alt="{label}" draggable="false"{img_style}>\n'
        f'      <span>{label}</span>\n'
        f'    </div>'
    )

preview_html = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Icon Set Preview</title>
<style>
  body { margin:0; padding:48px 32px; background:#f4f5f8;
         font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
         color:#1c1e26; }
  h1 { font-size:22px; margin:0 0 6px; }
  p.sub { margin:0 0 32px; color:#6b7280; font-size:14px; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(80px,1fr));
          gap:20px; max-width:1100px; }
  .card { display:flex; flex-direction:column; align-items:center; }
  .card img { width:64px; height:64px; margin-bottom:8px; cursor:pointer; display:block;
              user-select:none; -webkit-user-drag:none; }
  .card span { font-size:12px; font-weight:500; text-align:center; color:#6b7280; }
</style>
</head>
<body>
  <h1>Icon Set</h1>
  <p class="sub">""" + str(len(icons)) + """ icons &mdash; click any icon to view full size</p>
  <div class="grid">
""" + "\n".join(cards) + """
  </div>
<script>
  document.querySelectorAll('.card').forEach(card => {
    const icon  = card.dataset.icon;
    const label = card.dataset.label;
    const img = card.querySelector('img');
    const src = state => `../svg/${icon}${state}.svg`;
    let isDown = false;
    img.addEventListener('mouseenter', () => { img.src = src(isDown ? '_pressed' : '_hover'); });
    img.addEventListener('mouseleave', () => { img.src = src(''); });
    img.addEventListener('mousedown',  (e) => { e.preventDefault(); isDown = true; img.src = src('_pressed'); });
    img.addEventListener('mouseup',    () => { isDown = false; img.src = src('_hover'); });
    document.addEventListener('mouseup', () => { isDown = false; });
    img.addEventListener('dblclick',   () => {
      window.location.href = `icon_detail.html?icon=${encodeURIComponent(icon)}&label=${encodeURIComponent(label)}`;
    });
  });
</script>
</body>
</html>
"""

with open(PREVIEW_OUT, "w") as f:
    f.write(preview_html)

# ── Generate icon_detail.html ─────────────────────────────────────────────────
import json as _json
_svg_sources = {}
for _n in icons:
    for _suffix in ("", "_hover", "_pressed"):
        _key = f"{_n}{_suffix}"
        with open(os.path.join(SVG_DIR, f"{_key}.svg")) as _f:
            _svg_sources[_key] = _f.read()

detail_html = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Icon Detail</title>
<style>
  body { margin:0; padding:48px 32px; background:#f4f5f8;
         font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
         color:#1c1e26; display:flex; flex-direction:column; align-items:flex-start; }
  a.back { font-size:14px; color:#3B6693; text-decoration:none; margin-bottom:40px; }
  a.back:hover { text-decoration:underline; }
  .detail { display:flex; flex-direction:column; align-items:center;
            background:#fff; border-radius:20px; padding:48px 64px;
            box-shadow:0 2px 8px rgba(0,0,0,0.08); width:100%; max-width:860px;
            box-sizing:border-box; }
  .detail img { width:256px; height:256px; margin-bottom:24px;
                user-select:none; -webkit-user-drag:none; }
  .detail h2 { margin:0 0 8px; font-size:22px; }
  .detail code { font-size:13px; color:#6b7280; background:#f4f5f8;
                 padding:4px 10px; border-radius:6px; margin-bottom:32px; }
  pre { margin:0; width:100%; background:#f4f5f8; border-radius:10px;
        padding:20px 24px; box-sizing:border-box; overflow-x:auto;
        font-size:12px; line-height:1.55; color:#374151; white-space:pre; }
</style>
</head>
<body>
  <a class="back" href="icon_preview.html">&larr; Back to all icons</a>
  <div class="detail">
    <img id="icon-img" src="" alt="" draggable="false">
    <h2 id="icon-label"></h2>
    <code id="icon-name"></code>
    <pre id="svg-source">Loading&hellip;</pre>
  </div>
<script>
  const params = new URLSearchParams(window.location.search);
  const icon   = params.get('icon')  || '';
  const label  = params.get('label') || icon;
  document.getElementById('icon-label').textContent = label;
  document.getElementById('icon-name').textContent  = icon + '.svg';
  const img = document.getElementById('icon-img');
  img.alt   = label;
  const SVG_SOURCES = SVG_SOURCES_PLACEHOLDER;
  const src = state => `../svg/${icon}${state}.svg`;
  let isDown = false;
  function showState(state) {
    img.src = src(state);
    document.getElementById('icon-name').textContent = icon + state + '.svg';
    document.getElementById('svg-source').textContent = SVG_SOURCES[icon + state] || '(not found)';
  }
  img.style.cursor = 'pointer';
  showState('');
  img.addEventListener('mouseenter', () => { showState(isDown ? '_pressed' : '_hover'); });
  img.addEventListener('mouseleave', () => { showState(''); });
  img.addEventListener('mousedown',  (e) => { e.preventDefault(); isDown = true; showState('_pressed'); });
  img.addEventListener('mouseup',    () => { isDown = false; showState('_hover'); });
  document.addEventListener('mouseup', () => { isDown = false; });
</script>
</body>
</html>
"""

detail_html = detail_html.replace(
    'SVG_SOURCES_PLACEHOLDER', _json.dumps(_svg_sources, ensure_ascii=False)
)

with open(DETAIL_OUT, "w") as f:
    f.write(detail_html)

print(f"Generated {len(icons)} icons ({len(icons)*3} SVGs) + icon_preview.html + icon_detail.html")
