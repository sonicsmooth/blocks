#!/usr/bin/env python3
"""Test involute gear path generation."""
import math

def involute_gear_path(cx, cy, n=8, r_pitch=11.0, pressure_deg=20.0,
                       addendum=2.5, dedendum=2.5, n_pts=8):
    """
    Returns an SVG path string for an involute spur gear centered at (cx, cy).
    n         = tooth count
    r_pitch   = pitch circle radius
    pressure_deg = pressure angle in degrees
    addendum  = radial height of tooth above pitch circle
    dedendum  = radial depth below pitch circle
    n_pts     = number of line segments per involute flank
    """
    alpha = math.radians(pressure_deg)
    r_base = r_pitch * math.cos(alpha)
    r_tip  = r_pitch + addendum
    r_root = r_pitch - dedendum

    pitch_ang = 2 * math.pi / n          # full angular pitch
    # half tooth thickness angle at pitch circle (standard gear, no profile shift)
    half_tooth = math.pi / (2 * n)

    # involute of circle r_base, parameter t (=tan of pressure angle at that point)
    def inv_xy(t):
        x = r_base * (math.cos(t) + t * math.sin(t))
        y = r_base * (math.sin(t) - t * math.cos(t))
        return x, y

    # t at a given circle radius
    def t_at_r(r):
        return math.sqrt(max(0.0, (r / r_base) ** 2 - 1))

    t_pitch = t_at_r(r_pitch)
    t_tip   = t_at_r(r_tip)
    # angle of involute at t_pitch (polar angle of the point in the involute frame)
    x_p, y_p = inv_xy(t_pitch)
    inv_angle_at_pitch = math.atan2(y_p, x_p)

    # rotation so that the right flank sits at -half_tooth from the tooth centerline
    # at the pitch circle
    flank_rot = -half_tooth - inv_angle_at_pitch

    # Apply rotation R to an (x,y) point and translate to (cx,cy)
    def place(x, y, rot, tooth_i):
        total = tooth_i * pitch_ang + rot
        cos_r, sin_r = math.cos(total), math.sin(total)
        return cx + x * cos_r - y * sin_r, cy + x * sin_r + y * cos_r

    # Reflect point across the tooth centerline at tooth_i
    def reflect(px, py, tooth_i):
        base = tooth_i * pitch_ang
        dx, dy = px - cx, py - cy
        theta = math.atan2(dy, dx)
        r_dist = math.hypot(dx, dy)
        theta_ref = 2 * base - theta
        return cx + r_dist * math.cos(theta_ref), cy + r_dist * math.sin(theta_ref)

    def fmt(px, py): return f"{px:.3f},{py:.3f}"

    parts = []

    # t_start: if r_root >= r_base the involute exists all the way to root
    t_start = t_at_r(r_root) if r_root >= r_base else 0.0

    for i in range(n):
        # ---------- right flank (root → tip) ----------
        rf = []
        if r_root < r_base:
            # extend involute tangent at t=0 toward root: approximate by
            # placing root point at the same angular position as the base-circle start
            rfx, rfy = place(r_root, 0, flank_rot, i)
            rf.append((rfx, rfy))
        for k in range(n_pts + 1):
            t = t_start + (t_tip - t_start) * k / n_pts
            x, y = inv_xy(t)
            rf.append(place(x, y, flank_rot, i))

        # ---------- left flank (tip → root): mirror of right ----------
        lf = [reflect(px, py, i) for px, py in reversed(rf)]

        # ---------- path segments ----------
        if i == 0:
            parts.append(f"M {fmt(*rf[0])}")
        else:
            # root arc from previous tooth's left-flank root to this tooth's right-flank root
            parts.append(f"A {r_root:.3f},{r_root:.3f} 0 0 1 {fmt(*rf[0])}")

        for pt in rf[1:]:
            parts.append(f"L {fmt(*pt)}")

        # tip arc: right-flank tip → left-flank tip
        parts.append(f"A {r_tip:.3f},{r_tip:.3f} 0 0 1 {fmt(*lf[0])}")

        for pt in lf[1:]:
            parts.append(f"L {fmt(*pt)}")

    parts.append("Z")
    return " ".join(parts)


# --- emit a test SVG ---
path = involute_gear_path(32, 32, n=8, r_pitch=11, pressure_deg=20,
                          addendum=2.5, dedendum=2.5, n_pts=10)

svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="256" height="256">
  <rect width="64" height="64" fill="#3B6693"/>
  <path d="{path}" fill="white"/>
  <circle cx="32" cy="32" r="4.5" fill="#3B6693"/>
  <!-- reference circles -->
  <circle cx="32" cy="32" r="11"   fill="none" stroke="red"   stroke-width="0.3" opacity="0.5"/>
  <circle cx="32" cy="32" r="13.5" fill="none" stroke="green" stroke-width="0.3" opacity="0.5"/>
  <circle cx="32" cy="32" r="8.5"  fill="none" stroke="blue"  stroke-width="0.3" opacity="0.5"/>
</svg>"""

with open("/sessions/upbeat-nice-mccarthy/mnt/outputs/test_gear.svg", "w") as f:
    f.write(svg)
print("Wrote test_gear.svg")
print(f"r_base = {11 * math.cos(math.radians(20)):.3f}")
print(f"t_pitch = {math.sqrt((11/( 11*math.cos(math.radians(20))))**2 - 1):.4f}")
