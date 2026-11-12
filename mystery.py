"""Second format: dark "part 1" mystery shorts. Caption on top, one illustration, red reveal, end card.

Usage: python3 mystery.py sheet|render [id-substring ...]
"""
import math
import os
import random
import subprocess
import sys

import skia

import audio
from engine import C, PF, PS, TF_BLACK, TF_BOLD, TF_MED, back, clamp, ease, font, mix, parse, plain, poly, wrap

W, H, FPS = 1080, 1920, 30
YEL, RED, SKIN, INK = '#ffd23f', '#ff3b30', '#f6d2b0', '#08080c'
STEP = 0.26  # seconds between caption words
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output', 'mystery')


# ---------- primitives ----------
def rect(cv, x, y, w, h, col, a=255):
    cv.drawRect(skia.Rect.MakeXYWH(x, y, w, h), PF(col, a))


def rr(cv, x, y, w, h, r, col, a=255):
    cv.drawRoundRect(skia.Rect.MakeXYWH(x, y, w, h), r, r, PF(col, a))


def circ(cv, x, y, r, col, a=255):
    cv.drawCircle(x, y, r, PF(col, a))


def ell(cv, x, y, rx, ry, col, a=255):
    cv.drawOval(skia.Rect.MakeLTRB(x - rx, y - ry, x + rx, y + ry), PF(col, a))


def ln(cv, x1, y1, x2, y2, col, w, a=255):
    cv.drawLine(x1, y1, x2, y2, PS(col, w, a))


def arc(cv, x, y, rx, ry, a0, sweep, col, w, a=255):
    cv.drawArc(skia.Rect.MakeLTRB(x - rx, y - ry, x + rx, y + ry), a0, sweep, False, PS(col, w, a))


def glow(cv, x, y, r, col, a):
    p = skia.Paint(AntiAlias=True)
    p.setShader(skia.GradientShader.MakeRadial(center=(x, y), radius=r, colors=[C(col, a), C(col, 0)]))
    cv.drawCircle(x, y, r, p)


def txt(cv, s, x, y, f, col='#ffffff', align='c', a=255, shadow=0):
    w = f.measureText(s)
    x -= w / 2 if align == 'c' else w if align == 'r' else 0
    if shadow:
        p = PF('#000000', a * 0.75)
        p.setMaskFilter(skia.MaskFilter.MakeBlur(skia.kNormal_BlurStyle, shadow))
        cv.drawString(s, x, y + shadow * 0.7, f, p)
    cv.drawString(s, x, y, f, PF(col, a))


def clip_rr(cv, x, y, w, h, r):
    p = skia.Path()
    p.addRoundRect(skia.Rect.MakeXYWH(x, y, w, h), r, r)
    cv.clipPath(p, True)


def scanlines(cv, w, h):
    for y in range(0, int(h), 8):
        rect(cv, 0, y, w, 2, '#000000', 22)


# ---------- characters ----------
def head(cv, x, y, r, hair='#3a241c', style='long', expr='neutral', t=0, blink_off=0.0, back_view=False):
    if style == 'long':
        rr(cv, x - r * 1.1, y - r * 1.05, r * 2.2, r * 2.7, r * 0.9, hair)
    elif style == 'bun':
        circ(cv, x, y - r * 1.12, r * 0.45, hair)
    circ(cv, x, y, r, SKIN)
    if back_view:
        circ(cv, x, y, r * 1.04, hair)
        return
    cv.save()
    cp = skia.Path()
    cp.addCircle(x, y, r)
    cv.clipPath(cp, True)
    ell(cv, x, y - r * 0.98, r * 1.3, r * 0.62, hair)
    if style == 'long':
        for sx in (-1, 1):
            rr(cv, x + sx * r * 0.88 - r * 0.2, y - r * 0.7, r * 0.4, r * 2, r * 0.2, hair)
    cv.restore()
    if style == 'long':
        arc(cv, x, y - r * 0.38, r * 0.86, r * 0.55, 205, 130, '#f1dccf', r * 0.07)
    ex, ey, k = r * 0.36, y + r * 0.08, r / 66
    blink = ((t + blink_off) % 3.7) < 0.13
    for sx in (-1, 1):
        if expr == 'sleep' or blink:
            arc(cv, x + sx * ex, ey - 4 * k, 10 * k, 8 * k, 20, 140, '#1c1c24', 4 * k)
        elif expr == 'scared':
            circ(cv, x + sx * ex, ey, 13 * k, '#ffffff')
            circ(cv, x + sx * ex, ey, 5 * k, '#1c1c24')
        else:
            circ(cv, x + sx * ex, ey, 7 * k, '#1c1c24')
        ell(cv, x + sx * r * 0.6, y + r * 0.4, r * 0.17, r * 0.12, '#ff8fa0', 120)
        if expr == 'sad':
            ln(cv, x + sx * ex - sx * 12 * k, ey - 22 * k, x + sx * ex + sx * 10 * k, ey - 16 * k, '#3a241c', 4 * k)
    my = y + r * 0.52
    if expr in ('sad',):
        arc(cv, x, my + 12 * k, 15 * k, 12 * k, 205, 130, '#7a2a2a', 4.5 * k)
    elif expr == 'smile':
        arc(cv, x, my - 8 * k, 16 * k, 12 * k, 25, 130, '#7a2a2a', 4.5 * k)
    elif expr == 'grin':
        arc(cv, x, my - 16 * k, 30 * k, 24 * k, 15, 150, '#7a2a2a', 6 * k)
    elif expr in ('scared', 'sleep'):
        ell(cv, x, my + 2 * k, 7 * k, 9 * k, '#7a2a2a')
    else:
        ln(cv, x - 10 * k, my, x + 10 * k, my, '#7a2a2a', 4.5 * k)


def person(cv, x, y, s=1.0, top='#8a5cd6', hair='#3a241c', style='long', expr='neutral', arms='down',
           back_view=False, t=0, blink_off=0.0, legs=True, shake=0):
    cv.save()
    cv.translate(x + (math.sin(t * 50) * shake if shake else 0), y)
    cv.scale(s, s)
    bob = math.sin(t * 2.2 + x * 0.01) * 2.5
    if legs:
        ell(cv, 0, 2, 84, 12, '#000000', 80)
        for sx in (-1, 1):
            rr(cv, sx * 24 - 12, -75, 24, 75, 8, '#2b2b3a')
    ap = PS(mix(top, '#000000', 0.1), 26)
    for sx in (-1, 1):
        up = arms == 'both' or (arms == 'up' and sx == 1) or (arms == 'up_l' and sx == -1)
        if up:
            x1, y1 = sx * 86, -345 + bob
        elif arms == 'wave' and sx == 1:
            x1, y1 = 92 + math.sin(t * 10) * 14, -338 + bob
        else:
            x1, y1 = sx * 72, -105 + bob
        cv.drawLine(sx * 56, -212 + bob, x1, y1, ap)
    rr(cv, -60, -238 + bob, 120, 172, 46, top)
    head(cv, 0, -298 + bob, 66, hair, style, expr, t, blink_off, back_view)
    cv.restore()


def shade(cv, x, y, s=1.0, wave=0, t=0, a=255):
    """the dark figure: black capsule with white dot eyes"""
    cv.save()
    cv.translate(x, y)
    cv.scale(s, s)
    rr(cv, -36, -235, 72, 235, 32, INK, a)
    circ(cv, 0, -270, 44, INK, a)
    if wave:
        ln(cv, 30, -200, 60 + math.sin(t * 9) * 12, -320, INK, 20, a)
    for sx in (-1, 1):
        circ(cv, sx * 15, -274, 6, '#ffffff', a)
    cv.restore()


def handprint(cv, x, y, s, a):
    col = '#dfe6ff'
    ell(cv, x, y, 34 * s, 40 * s, col, a * 0.8)
    for i, (dx, ln_) in enumerate(((-34, 44), (-16, 62), (4, 68), (24, 60))):
        cv.drawLine(x + dx * s, y - 30 * s, x + (dx - 4 + i * 3) * s, y - (30 + ln_) * s, PS(col, 17 * s, a * 0.8))
    cv.drawLine(x + 30 * s, y + 6 * s, x + 64 * s, y - 22 * s, PS(col, 18 * s, a * 0.8))


# ---------- mini scenes (drawn in a w x h box; reused in cards and phone screens) ----------
def _room(cv, w, h, wall='#2c3050', floor='#1d1f33', fy=0.84):
    rect(cv, 0, 0, w, h, wall)
    rect(cv, 0, h * fy, w, h * (1 - fy), floor)


def m_monitor(cv, w, h, t, rv, p):
    _room(cv, w, h, '#232644', '#3a2c24', 0.76)
    col = RED if p.get('red') else '#59e08a'
    for i in range(3):
        k = (t * 0.9 + i / 3) % 1
        for sx in (-1, 1):
            arc(cv, w * 0.5, h * 0.52, w * (0.2 + 0.2 * k), w * (0.2 + 0.2 * k), -35 if sx > 0 else 145, 70, col,
                h * 0.012, 200 * (1 - k))
    ln(cv, w * 0.6, h * 0.36, w * 0.66, h * 0.2, '#c9cddb', h * 0.014)
    circ(cv, w * 0.66, h * 0.2, h * 0.016, col)
    rr(cv, w * 0.36, h * 0.34, w * 0.28, h * 0.42, w * 0.05, '#e9ecf5')
    rr(cv, w * 0.395, h * 0.385, w * 0.21, h * 0.16, w * 0.02, '#141826')
    for i in range(6):
        bh = h * (0.02 + 0.11 * abs(math.sin(t * (5 + i) + i * 1.3)))
        rr(cv, w * (0.412 + i * 0.031), h * 0.53 - bh, w * 0.019, bh, 4, col)
    for i in range(12):
        circ(cv, w * (0.43 + (i % 4) * 0.047), h * (0.6 + (i // 4) * 0.04), h * 0.01, '#9aa0b5')
    if p.get('notes'):
        for i in range(3):
            k = (t * 0.45 + i / 3) % 1
            nx, ny = w * (0.2 + i * 0.3) + math.sin(t * 2 + i) * 20, h * (0.36 - 0.26 * k)
            a = 255 * math.sin(math.pi * k)
            ell(cv, nx, ny, h * 0.022, h * 0.017, '#ffffff', a)
            ln(cv, nx + h * 0.02, ny, nx + h * 0.02, ny - h * 0.075, '#ffffff', h * 0.008, a)
            ln(cv, nx + h * 0.02, ny - h * 0.075, nx + h * 0.05, ny - h * 0.06, '#ffffff', h * 0.012, a)


def m_crib(cv, w, h, t, rv, p):
    rect(cv, 0, 0, w, h, '#0e2218')
    rect(cv, 0, h * 0.8, w, h * 0.2, '#0a1911')
    if p.get('shade'):
        shade(cv, w * 0.68, h * 0.84, h / 330, 0, t, 255 * rv)
    g = '#8fe6ad'
    rr(cv, w * 0.2, h * 0.62, w * 0.6, h * 0.1, 10, '#2f6a48')
    ell(cv, w * 0.48, h * 0.6, w * 0.14, h * 0.05, '#bff5cf')
    circ(cv, w * 0.36, h * 0.585, h * 0.045, '#d9ffe6')
    for i in range(11):
        x = w * (0.2 + i * 0.06)
        ln(cv, x, h * 0.48, x, h * 0.78, g, h * 0.012)
    ln(cv, w * 0.18, h * 0.48, w * 0.82, h * 0.48, g, h * 0.02)
    ln(cv, w * 0.18, h * 0.78, w * 0.82, h * 0.78, g, h * 0.02)
    for x in (0.2, 0.8):
        ln(cv, w * x, h * 0.78, w * x, h * 0.86, g, h * 0.02)
    scanlines(cv, w, h)


def m_closet(cv, w, h, t, rv, p):
    _room(cv, w, h, '#2c3050', '#1d1f33', 0.9)
    rr(cv, w * 0.2, h * 0.1, w * 0.6, h * 0.82, 12, '#4a3628')
    rect(cv, w * 0.24, h * 0.14, w * 0.52, h * 0.72, '#0b0b12')
    ln(cv, w * 0.26, h * 0.22, w * 0.74, h * 0.22, '#8d93a8', h * 0.012)
    for i in range(3):
        x = w * (0.36 + i * 0.14)
        sway = math.sin(t * 2 + i) * w * 0.008
        ln(cv, x, h * 0.22, x + sway, h * 0.27, '#8d93a8', 5)
        ln(cv, x + sway, h * 0.27, x + sway - w * 0.05, h * 0.32, '#8d93a8', 5)
        ln(cv, x + sway, h * 0.27, x + sway + w * 0.05, h * 0.32, '#8d93a8', 5)
        ln(cv, x + sway - w * 0.05, h * 0.32, x + sway + w * 0.05, h * 0.32, '#8d93a8', 5)
    cv.drawPath(poly([(w * 0.24, h * 0.14), (w * 0.05, h * 0.07), (w * 0.05, h * 0.95), (w * 0.24, h * 0.86)]), PF('#6b4e3a'))
    cv.drawPath(poly([(w * 0.76, h * 0.14), (w * 0.95, h * 0.07), (w * 0.95, h * 0.95), (w * 0.76, h * 0.86)]), PF('#5f4433'))
    if p.get('eyes'):
        for sx in (-1, 1):
            circ(cv, w * 0.5 + sx * w * 0.03, h * 0.5, h * 0.012, '#ffffff', 255 * rv)


def m_door(cv, w, h, t, rv, p):
    _room(cv, w, h, '#2c3050', '#1d1f33', 0.88)
    x0, y0, dw, dh = w * 0.27, h * 0.13, w * 0.46, h * 0.75
    dx = math.sin(t * 45) * w * 0.008 if p.get('knock') and (t % 1.1) < 0.42 else 0
    rr(cv, x0 - w * 0.03, y0 - h * 0.025, dw + w * 0.06, dh + h * 0.025, 8, '#1a1c2e')
    rect(cv, x0, y0 + dh, dw, h * 0.014, '#ffd98a', 230)
    glow(cv, x0 + dw / 2, y0 + dh, dw * 0.7, '#ffd98a', 60)
    if p.get('feet'):
        for sx in (-1, 1):
            rect(cv, x0 + dw / 2 + sx * dw * 0.14 - dw * 0.07, y0 + dh, dw * 0.14, h * 0.014, INK, 255 * rv)
    cv.save()
    cv.translate(dx, 0)
    rr(cv, x0, y0, dw, dh, 8, '#5a4334')
    for yy in (0.06, 0.52):
        rr(cv, x0 + dw * 0.12, y0 + dh * yy, dw * 0.76, dh * 0.4, 6, '#4d392c')
    circ(cv, x0 + dw / 2, y0 + dh * 0.3, h * 0.014, '#c9cddb')
    if p.get('num'):
        txt(cv, p['num'], x0 + dw / 2, y0 + dh * 0.2, font(TF_BLACK, h * 0.06), '#d9c48a')
    hx, hy = x0 + dw * 0.86, y0 + dh * 0.53
    circ(cv, hx, hy, h * 0.022, '#c9a24a')
    cv.save()
    cv.translate(hx, hy)
    cv.rotate(p.get('handle', 0) * rv * 38)
    rr(cv, -dw * 0.24, -h * 0.011, dw * 0.25, h * 0.022, h * 0.011, '#e0bb5e')
    cv.restore()
    cv.restore()
    if p.get('speech'):
        f = font(TF_BOLD, h * 0.05)
        lines = wrap(p['speech'], f, w * 0.5)
        bw = max(f.measureText(l) for l in lines) + w * 0.07
        bh = len(lines) * h * 0.064 + h * 0.05
        k = back(rv)
        cv.save()
        cv.translate(w * 0.5, h * 0.02 + bh / 2)
        cv.scale(k, k)
        rr(cv, -bw / 2, -bh / 2, bw, bh, 22, '#ffffff')
        cv.drawPath(poly([(-20, bh / 2 - 2), (20, bh / 2 - 2), (0, bh / 2 + 30)]), PF('#ffffff'))
        for i, l in enumerate(lines):
            txt(cv, l, 0, -bh / 2 + h * 0.07 + i * h * 0.064, f, '#1c1c24')
        cv.restore()


def m_mirror(cv, w, h, t, rv, p):
    _room(cv, w, h, '#2c3050', '#1d1f33', 0.9)
    mx, my, mw, mh = w * 0.14, h * 0.05, w * 0.72, h * 0.72
    rr(cv, mx - 16, my - 16, mw + 32, mh + 32, 28, '#b08a4a')
    cv.save()
    clip_rr(cv, mx, my, mw, mh, 16)
    rect(cv, mx, my, mw, mh, '#39446b')
    rect(cv, mx, my + mh * 0.82, mw, mh * 0.2, '#2a3252')
    rs = 1 + (p.get('rs', 1) - 1) * (rv if p.get('rs_anim') else 1)
    person(cv, w * 0.5, h * (0.2 + 0.573 * rs), rs * h / 520, top='#8a5cd6', expr=p.get('rexpr', 'neutral'),
           arms=p.get('rarms', 'down'), t=t, blink_off=1.3)
    if p.get('palm'):
        handprint(cv, w * 0.755, h * 0.34, h / 520, 235 * rv)
    cv.drawPath(poly([(mx + mw * 0.1, my), (mx + mw * 0.3, my), (mx + mw * 0.05, my + mh), (mx - mw * 0.15, my + mh)]),
                PF('#ffffff', 18))
    cv.restore()
    person(cv, w * 0.5, h * (1.32 + 0.1 * p.get('back', 0)), (1 - 0.14 * p.get('back', 0)) * h / 400, top='#8a5cd6',
           arms=p.get('arms', 'down'), back_view=True, t=t, legs=False)


def m_bed(cv, w, h, t, rv, p):
    _room(cv, w, h, '#232644', '#191b2e', 0.8)
    if p.get('clock'):
        rr(cv, w * 0.1, h * 0.07, w * 0.24, h * 0.1, 12, '#101220')
        txt(cv, p['clock'], w * 0.22, h * 0.145, font(TF_BLACK, h * 0.07), RED)
    rr(cv, w * 0.08, h * 0.28, w * 0.06, h * 0.5, 12, '#4a3628')
    girl = p.get('girl')
    if girl == 'sit':
        person(cv, w * 0.6, h * 0.62, h / 600, top='#3fa37a', expr=p.get('expr', 'neutral'), t=t, legs=False,
               shake=p.get('shake', 0))
    rect(cv, w * 0.14, h * 0.64, w * 0.74, h * 0.16, '#06060a')
    rr(cv, w * 0.12, h * 0.52, w * 0.78, h * 0.13, 10, '#5a4334')
    rr(cv, w * 0.14, h * 0.45, w * 0.74, h * 0.11, 16, '#d9dcea')
    rr(cv, w * 0.16, h * 0.385, w * 0.2, h * 0.09, 18, '#f4f5fa')
    if girl == 'sleep':
        head(cv, w * 0.27, h * 0.385, h * 0.07, expr='sleep', t=t)
        rr(cv, w * 0.31, h * 0.4, w * 0.56, h * 0.2, 22, '#5b6bb8')
        f = font(TF_BLACK, h * 0.06)
        for i, c in enumerate('zzZ'):
            txt(cv, c, w * (0.38 + i * 0.05), h * (0.32 - i * 0.045) + math.sin(t * 2 + i) * 6, f, '#cfd8ff')
    else:
        rr(cv, w * 0.42, h * 0.43, w * 0.46, h * 0.19, 22, '#5b6bb8')
    for x in (0.14, 0.86):
        rr(cv, w * x - 10, h * 0.64, 20, h * 0.17, 6, '#4a3628')
    if p.get('glow'):
        glow(cv, w * 0.5, h * 0.75, w * 0.36, '#a9d4ff', 200 * rv)
        rr(cv, w * 0.46, h * 0.745, w * 0.08, h * 0.03, 4, '#e6f3ff', 255 * rv)
        for i in range(3):
            k = (t * 1.2 + i / 3) % 1
            arc(cv, w * 0.5, h * 0.76, w * (0.06 + 0.12 * k), h * (0.04 + 0.06 * k), 200, 140, '#e6f3ff', 5,
                220 * (1 - k) * rv)


def m_facade(cv, w, h, t, rv, p):
    rect(cv, 0, 0, w, h, '#0b0e24')
    lit = p.get('lit', [])
    z = 1 + 1.3 * max(p.get('zoomed', 0), p.get('zoom', 0) * rv)
    if lit:
        fx_, fy_ = w * (0.22 + lit[0][0] * 0.185), h * (0.2275 + lit[0][1] * 0.165)
        cv.translate(w / 2, h / 2)
        cv.scale(z, z)
        cv.translate(-(w / 2 + (fx_ - w / 2) * min(1, z - 1)), -(h / 2 + (fy_ - h / 2) * min(1, z - 1)))
    rnd = random.Random(3)
    for i in range(26):
        circ(cv, rnd.random() * w, rnd.random() * h * 0.14, 2.5, '#ffffff', 120 + 100 * math.sin(t * 2 + i))
    rect(cv, w * 0.08, h * 0.1, w * 0.84, h * 0.9, '#1e2238')
    for c in range(4):
        for r in range(5):
            wx, wy, ww, wh = w * (0.15 + c * 0.185), h * (0.17 + r * 0.165), w * 0.14, h * 0.115
            on = (c, r) in lit
            if on:
                glow(cv, wx + ww / 2, wy + wh / 2, ww * 1.5, '#ffd98a', 110)
            rect(cv, wx, wy, ww, wh, '#ffd98a' if on else '#12152a')
            if on and p.get('fig'):
                cv.save()
                cv.clipRect(skia.Rect.MakeXYWH(wx, wy, ww, wh))
                shade(cv, wx + ww / 2, wy + wh * 1.25, wh / 250, p.get('wave', 0), t)
                cv.restore()
            if on:
                ln(cv, wx + ww / 2, wy, wx + ww / 2, wy + wh, '#1e2238', 4)


def m_window(cv, w, h, t, rv, p):
    _room(cv, w, h, '#232644', '#191b2e', 0.9)
    x0, y0, ww, wh = w * 0.16, h * 0.1, w * 0.68, h * 0.7
    rr(cv, x0 - 18, y0 - 18, ww + 36, wh + 36, 10, '#d9dcea')
    rect(cv, x0, y0, ww, wh, '#0b0e24')
    circ(cv, x0 + ww * 0.8, y0 + wh * 0.14, h * 0.04, '#e8e2c8')
    rect(cv, x0 + ww * 0.1, y0 + wh * 0.5, ww * 0.32, wh * 0.5, '#161a30')
    for i in range(6):
        rect(cv, x0 + ww * (0.14 + (i % 2) * 0.13), y0 + wh * (0.56 + (i // 2) * 0.14), ww * 0.07, wh * 0.07,
             '#ffd98a' if i == p.get('farlit', 2) else '#0d1024')
    if p.get('palm'):
        handprint(cv, x0 + ww * 0.7, y0 + wh * 0.55, h / 380, 235 * rv)
        glow(cv, x0 + ww * 0.7, y0 + wh * 0.5, ww * 0.3, '#dfe6ff', 50 * rv)
    ln(cv, x0 + ww / 2, y0, x0 + ww / 2, y0 + wh, '#d9dcea', 12)
    rr(cv, x0 - 40, y0 + wh + 14, ww + 80, h * 0.035, 6, '#eef0f7')
    for sx in (0, 1):
        rr(cv, w * (0.02 if sx == 0 else 0.84), h * 0.04, w * 0.14, h * 0.82, 20, '#3b3f66')


def m_speaker(cv, w, h, t, rv, p):
    _room(cv, w, h, '#232644', '#3a2c24', 0.76)
    col = p.get('col', '#4aa8ff')
    pulse = 0.5 + 0.5 * math.sin(t * 7)
    glow(cv, w * 0.5, h * 0.5, w * 0.36, col, 70 + 60 * pulse)
    rr(cv, w * 0.37, h * 0.46, w * 0.26, h * 0.34, w * 0.07, '#2b2f42')
    ell(cv, w * 0.5, h * 0.48, w * 0.13, h * 0.04, '#3a3f58')
    arc(cv, w * 0.5, h * 0.48, w * 0.11, h * 0.03, 0, 360, col, h * 0.012, 140 + 115 * pulse)
    for i in range(18):
        circ(cv, w * (0.41 + (i % 6) * 0.036), h * (0.6 + (i // 6) * 0.045), h * 0.008, '#4a5070')
    if p.get('say'):
        f = font(TF_BOLD, h * 0.055)
        lines = wrap('«' + p['say'] + '»', f, w * 0.76)
        bh = len(lines) * h * 0.07 + h * 0.06
        k = back(rv) if p.get('say_rv') else 1
        cv.save()
        cv.translate(w * 0.5, h * 0.36)
        cv.scale(k, k)
        bw = max(f.measureText(l) for l in lines) + w * 0.08
        rr(cv, -bw / 2, -bh - 30, bw, bh, 24, '#ffffff')
        cv.drawPath(poly([(-22, -32), (22, -32), (0, 0)]), PF('#ffffff'))
        for i, l in enumerate(lines):
            txt(cv, l, 0, -bh - 30 + h * 0.078 + i * h * 0.07, f, '#1c1c24')
        cv.restore()


def _bunny(cv, x, y, s, mode, t, red=False):
    cv.save()
    cv.translate(x, y)
    cv.scale(s, s)
    wht = '#f1ece4'
    for sx in (-1, 1):
        rr(cv, sx * 34 - 17, -330, 34, 130, 17, wht)
        rr(cv, sx * 34 - 7, -312, 14, 90, 7, '#f3b6c2')
        ell(cv, sx * 44, -8, 30, 16, wht)
    ell(cv, 0, -80, 72, 86, wht)
    ell(cv, 0, -70, 40, 50, '#ffffff')
    circ(cv, 0, -200, 66, wht)
    off = 22 if mode == 'side' else 0
    for sx in (-1, 1):
        if mode == 'cam':
            circ(cv, sx * 24, -208, 15, '#101014')
            circ(cv, sx * 24, -208, 5, RED if red else '#ffffff')
        else:
            circ(cv, sx * 22 + off, -206, 8, '#101014')
    cv.drawPath(poly([(off * 0.8 - 8, -186), (off * 0.8 + 8, -186), (off * 0.8, -176)]), PF('#f08aa0'))
    cv.restore()


def m_shelf(cv, w, h, t, rv, p):
    _room(cv, w, h, '#2c3050', '#2c3050', 1)
    z = 1 + p.get('zoom', 0) * rv
    cv.save()
    cv.translate(w * 0.5, h * 0.42)
    cv.scale(z, z)
    cv.translate(-w * 0.5, -h * 0.3)
    for i, c in enumerate(('#c0524f', '#3f7fd9', '#e0a030', '#35a36b')):
        rr(cv, w * (0.1 + i * 0.045), h * (0.44 + (i % 2) * 0.03), w * 0.04, h * (0.22 - (i % 2) * 0.03), 4, c)
    rr(cv, w * 0.78, h * 0.56, w * 0.1, h * 0.1, 8, '#b5673e')
    for i in (-1, 0, 1):
        ell(cv, w * 0.83 + i * w * 0.04, h * 0.5 - abs(i) * -h * 0.02, w * 0.03, h * 0.07, '#35a36b')
    b = p.get('bunny')
    if b:
        _bunny(cv, w * 0.5, h * 0.66, h / 520, b, t, p.get('red'))
    else:
        ell(cv, w * 0.5, h * 0.655, w * 0.08, h * 0.012, '#000000', 90)
    rr(cv, w * 0.05, h * 0.66, w * 0.9, h * 0.045, 6, '#6b4a34')
    cv.restore()
    if p.get('night'):
        rect(cv, 0, 0, w, h, '#06351c', 150)
        scanlines(cv, w, h)


def m_house(cv, w, h, t, rv, p):
    rect(cv, 0, 0, w, h, '#0b0e24')
    circ(cv, w * 0.8, h * 0.14, h * 0.05, '#e8e2c8')
    rect(cv, w * 0.18, h * 0.24, w * 0.64, h * 0.76, '#22263f')
    for i in range(15):
        c, r = i % 3, i // 3
        on = i == 7
        if on:
            glow(cv, w * (0.31 + c * 0.19), h * (0.34 + r * 0.13), w * 0.16, '#ffd98a', 120)
        rect(cv, w * (0.25 + c * 0.19), h * (0.3 + r * 0.13), w * 0.12, h * 0.08, '#ffd98a' if on else '#12152a')
    rect(cv, 0, h * 0.94, w, h * 0.06, '#101326')


def m_entrance(cv, w, h, t, rv, p):
    rect(cv, 0, 0, w, h, '#22263f')
    rect(cv, 0, h * 0.86, w, h * 0.14, '#101326')
    glow(cv, w * 0.5, h * 0.24, w * 0.5, '#ffd98a', 120)
    rr(cv, w * 0.2, h * 0.26, w * 0.6, h * 0.05, 4, '#3b4058')
    circ(cv, w * 0.5, h * 0.22, h * 0.025, '#ffe9b0')
    rect(cv, w * 0.28, h * 0.33, w * 0.44, h * 0.53, '#4a3a2e')
    rect(cv, w * 0.33, h * 0.38, w * 0.15, h * 0.2, '#12152a')
    rect(cv, w * 0.52, h * 0.38, w * 0.15, h * 0.2, '#12152a')
    rr(cv, w * 0.76, h * 0.42, w * 0.12, h * 0.14, 6, '#8d93a8')
    txt(cv, 'ПОДЪЕЗД 2', w * 0.5, h * 0.15, font(TF_BOLD, h * 0.05), '#c9cddb')


def m_back(cv, w, h, t, rv, p):
    _room(cv, w, h, '#2c3050', '#1d1f33', 0.82)
    rr(cv, w * 0.08, h * 0.2, w * 0.3, h * 0.28, 6, '#0b0e24')
    glow(cv, w * 0.5, h * 0.62, w * 0.3, '#a9d4ff', 90)
    person(cv, w * 0.5, h * 0.98, h / 470, top='#e86fa8', back_view=True, t=t)


def m_behind(cv, w, h, t, rv, p):
    _room(cv, w, h, '#1c1e33', '#131424', 0.86)
    rect(cv, w * 0.56, h * 0.16, w * 0.3, h * 0.7, '#050508')
    rr(cv, w * 0.54, h * 0.14, w * 0.34, h * 0.03, 4, '#2c3050')
    for sx in (-1, 1):
        circ(cv, w * 0.71 + sx * w * 0.026, h * 0.36, h * 0.012, '#ffffff', 255 * rv)
    glow(cv, w * 0.36, h * 0.66, w * 0.24, '#a9d4ff', 110)
    person(cv, w * 0.34, h * 0.98, h / 470, top='#e86fa8', expr='scared', t=t, shake=3 * rv)
    rr(cv, w * 0.36, h * 0.67, w * 0.05, h * 0.08, 6, '#dbeaff')


MINI = dict(monitor=m_monitor, crib=m_crib, closet=m_closet, door=m_door, mirror=m_mirror, bed=m_bed,
            facade=m_facade, window=m_window, speaker=m_speaker, shelf=m_shelf, house=m_house, entrance=m_entrance,
            back=m_back, behind=m_behind)


def mini(cv, x, y, w, h, r, kind, t, rv, p):
    cv.save()
    clip_rr(cv, x, y, w, h, r)
    cv.translate(x, y)
    MINI[kind](cv, w, h, t, rv, p)
    cv.restore()


# ---------- stage visuals ----------
def v_frame(cv, t, lt, rv, tr, p):
    s = 840
    rr(cv, 540 - s / 2 - 8, 1030 - s / 2 - 8, s + 16, s + 16, 44, '#3b4058')
    mini(cv, 540 - s / 2, 1030 - s / 2, s, s, 36, p['kind'], t, rv, p)


def v_people(cv, t, lt, rv, tr, p):
    n = len(p['who'])
    for i, a in enumerate(p['who']):
        a = dict(a)
        x = 540 + (i - (n - 1) / 2) * 330
        person(cv, x, 1500, a.pop('s', 1.75), t=t, blink_off=i * 1.1, **a)


def _stick(cv, x, y, hgt, col, w=7):
    r = hgt * 0.17
    cv.drawCircle(x, y - hgt + r, r, PS(col, w))
    ln(cv, x, y - hgt + 2 * r, x, y - hgt * 0.35, col, w)
    ln(cv, x - hgt * 0.22, y - hgt * 0.55, x + hgt * 0.22, y - hgt * 0.55, col, w)
    ln(cv, x, y - hgt * 0.35, x - hgt * 0.16, y, col, w)
    ln(cv, x, y - hgt * 0.35, x + hgt * 0.16, y, col, w)


def _black(cv, x, y, hgt, a=255):
    rnd = random.Random(int(x) + int(hgt))
    for i in range(14):
        ln(cv, x - 16 + rnd.random() * 32, y - hgt * 0.72 + rnd.random() * 10, x - 16 + rnd.random() * 32, y, '#0c0c10',
           9, a)
    circ(cv, x, y - hgt * 0.84, hgt * 0.14, '#0c0c10', a)
    for sx in (-1, 1):
        circ(cv, x + sx * hgt * 0.05, y - hgt * 0.85, 3.5, '#ffffff', a)


def _paper(cv, kind, t, rv, hot):
    rr(cv, -150, -180, 300, 360, 6, '#000000', 90)
    rr(cv, -150, -186, 300, 360, 6, '#f4efe2')
    if kind == 'family':
        circ(cv, 104, -140, 22, '#f2c94c')
        ln(cv, -130, 110, 130, 110, '#59b85a', 9)
        _stick(cv, -92, 106, 120, '#d9577a')
        _stick(cv, -34, 106, 128, '#3f7fd9')
        _stick(cv, 18, 106, 78, '#e0902e')
        _black(cv, 92, 106, 190, 255 * (rv if hot else 1))
    else:
        cv.drawRoundRect(skia.Rect.MakeXYWH(-120, 20, 200, 70), 8, 8, PS('#8a5a34', 8))
        ln(cv, -120, 20, -120, -30, '#8a5a34', 8)
        cv.drawCircle(-84, 4, 18, PS('#d9577a', 7))
        ln(cv, -62, 14, 40, 14, '#d9577a', 7)
        ln(cv, 10, 14, 62, -30, '#d9577a', 7)
        _black(cv, 96, 110, 230, 255)
        ln(cv, 62, -30, 86, -50, '#0c0c10', 9)


def v_papers(cv, t, lt, rv, tr, p):
    items = p['items']
    if len(items) == 1:
        k = back(lt / 0.4)
        cv.save()
        cv.translate(540, 1040)
        cv.rotate(-4 + math.sin(t * 1.3) * 1.2)
        cv.scale(2.25 * k, 2.25 * k)
        _paper(cv, items[0], t, rv, p.get('hot'))
        cv.restore()
        return
    pos = ((-300, -90, -8), (0, 120, 3), (300, -70, 7))
    for i, kind in enumerate(items):
        k = back((lt - 0.15 - i * 0.55) / 0.35)
        if k <= 0:
            continue
        cv.save()
        cv.translate(540 + pos[i][0], 980 + pos[i][1])
        cv.rotate(pos[i][2] + math.sin(t * 1.3 + i) * 1.2)
        cv.scale(1.08 * k, 1.08 * k)
        _paper(cv, kind, t, rv, False)
        cv.restore()


# phone apps draw in phone-local coords, screen = x -186..186, y -390..390
SF = lambda n: font(TF_MED, n)
SB = lambda n: font(TF_BOLD, n)


def a_gallery(cv, t, lt, rv, tr, p):
    txt(cv, p.get('label', 'ГАЛЕРЕЯ'), 0, -300, SB(22), '#8a90a8')
    mini(cv, -170, -262, 340, 440, 8, p['kind'], t, rv, p)
    cv.drawRoundRect(skia.Rect.MakeXYWH(-170, -262, 340, 440), 8, 8, PS('#3b4058', 3))


def a_cam(cv, t, lt, rv, tr, p):
    txt(cv, 'КАМЕРА', 0, -300, SB(22), '#8a90a8')
    mini(cv, -170, -262, 340, 440, 8, p['kind'], t, rv, p)
    if (t % 1) < 0.6:
        circ(cv, -140, -232, 9, RED)
    txt(cv, 'REC', -122, -223, SB(22), '#ffffff', 'l')
    txt(cv, p.get('time', '03:00'), 150, -223, SB(22), '#ffffff', 'r')


def a_chat(cv, t, lt, rv, tr, p):
    rect(cv, -186, -350, 372, 96, '#1d2236')
    circ(cv, -130, -302, 30, p.get('col', '#5b6070'))
    txt(cv, p.get('letter', '?'), -130, -291, SB(30), '#ffffff')
    txt(cv, p['name'], -88, -306, SB(26), '#ffffff', 'l')
    txt(cv, p.get('sub', 'в сети'), -88, -276, SF(19), '#8a90a8', 'l')
    y = -232
    f = SF(28)
    shown = p.get('shown', 0)
    msgs = p['msgs']
    for i, (side, text) in enumerate(msgs):
        if i < shown:
            k = 1
        elif p.get('last_rv') and i == len(msgs) - 1:
            k = back(tr / 0.25) if tr > 0 else 0
        else:
            k = back((lt - 0.3 - (i - shown) * 0.75) / 0.25)
        if k <= 0:
            continue
        lines = wrap(text, f, 262)
        bw = max(f.measureText(l) for l in lines) + 36
        bh = len(lines) * 36 + 24
        bx = 170 - bw if side == 'out' else -170
        cv.save()
        cv.translate(bx + (bw if side == 'out' else 0), y + bh)
        cv.scale(0.6 + 0.4 * k, 0.6 + 0.4 * k)
        cv.translate(-(bx + (bw if side == 'out' else 0)), -(y + bh))
        rr(cv, bx, y, bw, bh, 18, '#2f7df6' if side == 'out' else '#2a2f45')
        for j, l in enumerate(lines):
            txt(cv, l, bx + 18, y + 37 + j * 36, f, '#ffffff', 'l')
        cv.restore()
        y += bh + 14


def a_call(cv, t, lt, rv, tr, p):
    for i in range(3):
        k = (t * 0.7 + i / 3) % 1
        cv.drawCircle(0, -150, 80 + 90 * k, PS('#59e08a', 5, 200 * (1 - k)))
    circ(cv, 0, -150, 80, p.get('col', '#e86fa8'))
    txt(cv, p.get('letter', 'Ж'), 0, -122, SB(84), '#ffffff')
    txt(cv, p['name'], 0, 10, SB(44), '#ffffff')
    txt(cv, p.get('sub', 'входящий вызов'), 0, 56, SF(24), '#8a90a8')
    circ(cv, -90, 270, 48, RED)
    circ(cv, 90, 270 + math.sin(t * 12) * 5, 48, '#35c26b')
    rr(cv, -112, 262, 44, 16, 8, '#ffffff')
    rr(cv, 68, 262 + math.sin(t * 12) * 5, 44, 16, 8, '#ffffff')


MAP_PATH = [(-70, -180), (-70, -40), (-70, 20), (80, 20), (80, 78)]


def a_map(cv, t, lt, rv, tr, p):
    txt(cv, 'ГЕОЛОКАЦИЯ', 0, -300, SB(22), '#8a90a8')
    rect(cv, -170, -262, 340, 560, '#0f1322')
    rooms = (('СПАЛЬНЯ', -160, -252, 190, 220), ('КУХНЯ', 40, -252, 120, 220), ('КОРИДОР', -160, -22, 320, 90),
             ('ТВОЯ КОМНАТА', -30, 78, 190, 200), ('ВАННАЯ', -160, 78, 120, 200))
    for name, x, y, w, h in rooms:
        rr(cv, x, y, w, h, 6, '#1c2238')
        cv.drawRoundRect(skia.Rect.MakeXYWH(x, y, w, h), 6, 6, PS('#3b4468', 4))
        txt(cv, name, x + w / 2, y + 30, SB(18), '#8088a8')
    rect(cv, -95, -36, 50, 18, '#1c2238')
    rect(cv, 55, 64, 50, 18, '#1c2238')
    circ(cv, 80, 200, 14, '#4aa8ff')
    txt(cv, 'ТЫ', 80, 240, SB(20), '#4aa8ff')
    pos = p.get('pos', 0)
    if 'pos2' in p and tr > 0:
        pos += (p['pos2'] - pos) * clamp(tr / 2.4)
    f = pos * (len(MAP_PATH) - 1)
    i = min(int(f), len(MAP_PATH) - 2)
    (x1, y1), (x2, y2) = MAP_PATH[i], MAP_PATH[i + 1]
    x, y = x1 + (x2 - x1) * (f - i), y1 + (y2 - y1) * (f - i)
    k = (t * 1.2) % 1
    circ(cv, x, y, 16 + 40 * k, RED, 150 * (1 - k))
    circ(cv, x, y, 16, RED)
    circ(cv, x, y, 6, '#ffffff')
    txt(cv, p.get('who', 'ЖЕНА'), x, y - 28, SB(20), '#ff8a80')


def a_list(cv, t, lt, rv, tr, p):
    txt(cv, p.get('title', 'ИСТОРИЯ'), 0, -300, SB(22), '#8a90a8')
    rows = p['rows']
    for i, (a, b) in enumerate(rows):
        k = ease((lt - 0.2 - i * 0.18) / 0.25)
        if k <= 0:
            continue
        hot = p.get('hot') == i and tr > 0
        y = -262 + i * 86
        rr(cv, -170, y, 340, 74, 12, '#5a1616' if hot else '#1d2236', 255 * k)
        txt(cv, a, -152, y + 27, SB(19), '#ff8a80' if hot else '#6f7796', 'l', 255 * k)
        fb = SF(25)
        if fb.measureText(b) > 308:
            fb = SF(25 * 308 / fb.measureText(b))
        txt(cv, b, -152, y + 58, fb, '#ffffff', 'l', 255 * k)


def a_alarm(cv, t, lt, rv, tr, p):
    txt(cv, 'БУДИЛЬНИК', 0, -300, SB(22), '#8a90a8')
    if p.get('gone'):
        txt(cv, 'Нет будильников', 0, -40, SF(28), '#6f7796')
        return
    k = back(rv) if p.get('pop') else 1
    ring = p.get('ring') and tr > 0
    cv.save()
    cv.translate((math.sin(t * 60) * 5) if ring else 0, -60)
    cv.scale(k, k)
    rr(cv, -165, -150, 330, 300, 26, '#3a1414' if ring else '#1d2236')
    txt(cv, p.get('time', '3:33'), 0, 0, font(TF_BLACK, 120), '#ffffff')
    rr(cv, 70, 70, 76, 40, 20, '#35c26b')
    circ(cv, 126, 90, 16, '#ffffff')
    txt(cv, 'каждую ночь', -140, 100, SF(22), '#8a90a8', 'l')
    cv.restore()
    if p.get('label'):
        kk = back(rv) if p.get('label_rv') else 1
        cv.save()
        cv.translate(0, 190)
        cv.scale(kk, kk)
        txt(cv, 'Подпись:', 0, -44, SF(22), '#8a90a8')
        txt(cv, p['label'], 0, 14, font(TF_BLACK, 52), YEL)
        cv.restore()


APPS = dict(gallery=a_gallery, cam=a_cam, chat=a_chat, call=a_call, map=a_map, list=a_list, alarm=a_alarm)


def v_phone(cv, t, lt, rv, tr, p):
    cv.save()
    cv.translate(540, 1040 + math.sin(t * 1.4) * 8)
    cv.rotate(math.sin(t * 0.9) * 1.2)
    cv.scale(1.22, 1.22)
    rr(cv, -214, -424, 428, 868, 66, '#000000', 110)
    rr(cv, -210, -430, 420, 860, 64, '#3b4058')
    rr(cv, -196, -416, 392, 832, 52, '#141826')
    cv.save()
    clip_rr(cv, -196, -416, 392, 832, 52)
    APPS[p['app']](cv, t, lt, rv, tr, p)
    cv.restore()
    rr(cv, -62, -400, 124, 34, 17, '#05060a')
    cv.restore()


VIS = dict(frame=v_frame, people=v_people, papers=v_papers, phone=v_phone)


# ---------- backgrounds, captions, end card ----------
def backdrop(cv, kind, red=0.0):
    c1, c2 = ('#3a3d66', '#0b0c16') if kind == 'room' else ('#1a2142', '#05060c')
    if red:
        c1, c2 = mix(c1, '#5a1018', red), mix(c2, '#1a0306', red)
    p = skia.Paint(AntiAlias=True)
    p.setShader(skia.GradientShader.MakeRadial(center=(540, 900), radius=1250, colors=[C(c1), C(c2)]))
    cv.drawPaint(p)
    if kind == 'room':
        fl = skia.Paint(AntiAlias=True)
        fl.setShader(skia.GradientShader.MakeLinear(points=[(0, 1490), (0, 1920)],
                                                    colors=[C(mix('#2c2a3c', '#3a0c12', red)), C('#0a0a12')]))
        cv.drawRect(skia.Rect.MakeLTRB(0, 1490, W, H), fl)


def layout(words, f, maxw=960):
    sp = f.measureText(' ')
    lines, cur, cw = [], [], 0
    for i, (w, c) in enumerate(words):
        ww = f.measureText(w.upper())
        if cur and cw + sp + ww > maxw:
            lines.append((cur, cw))
            cur, cw = [], 0
        cw += (sp if cur else 0) + ww
        cur.append((i, w.upper(), c, ww))
    if cur:
        lines.append((cur, cw))
    return lines, sp


def caption(cv, words, lt, w0=0.35, y0=176, size=68):
    f = font(TF_BLACK, size)
    lines, sp = layout(words, f)
    while len(lines) > 4 and size > 52:
        size -= 4
        f = font(TF_BLACK, size)
        lines, sp = layout(words, f)
    for li, (ln_, lw) in enumerate(lines):
        x = 540 - lw / 2
        y = y0 + li * size * 1.2
        for i, w, c, ww in ln_:
            k = clamp((lt - w0 - i * STEP) / 0.16)
            if k > 0:
                s = 0.55 + 0.45 * back(k)
                cv.save()
                cv.translate(x + ww / 2, y - size * 0.35 + (1 - k) * 22)
                cv.scale(s, s)
                txt(cv, w, 0, size * 0.35, f, YEL if c else '#ffffff', 'c', 255 * min(1, k * 1.6), shadow=7)
                cv.restore()
            x += ww + sp


def bell(cv, x, y, s):
    p = skia.Path()
    p.moveTo(-16 * s, 10 * s)
    p.cubicTo(-12 * s, -28 * s, 12 * s, -28 * s, 16 * s, 10 * s)
    p.lineTo(22 * s, 16 * s)
    p.lineTo(-22 * s, 16 * s)
    p.close()
    cv.save()
    cv.translate(x, y)
    cv.drawPath(p, PF('#ffc93c'))
    circ(cv, 0, 21 * s, 6 * s, '#f2a51c')
    cv.restore()


def endcard(cv, lt, story):
    p = skia.Paint(AntiAlias=True)
    p.setShader(skia.GradientShader.MakeRadial(center=(540, 900), radius=1200, colors=[C('#3a1412'), C('#0a0506')]))
    cv.drawPaint(p)
    f = font(TF_BLACK, 104)
    k = back(lt / 0.3)
    cv.save()
    cv.translate(540, 830)
    cv.scale(k, k)
    wa, wb = f.measureText('ЧАСТЬ '), f.measureText('2')
    txt(cv, 'ЧАСТЬ ', -(wa + wb) / 2, 0, f, '#ffffff', 'l', shadow=8)
    txt(cv, '2', -(wa + wb) / 2 + wa, 0, f, YEL, 'l', shadow=8)
    cv.restore()
    k = back((lt - 0.25) / 0.3)
    if k > 0:
        cv.save()
        cv.translate(540, 950)
        cv.scale(k, k)
        txt(cv, 'УЖЕ СКОРО', 0, 0, f, '#ffffff', shadow=8)
        cv.restore()
    a = 255 * clamp((lt - 0.7) / 0.3)
    f2 = font(TF_BLACK, 46)
    l1, l2 = 'ПОДПИШИСЬ,', ' ' + story.get('cta', 'ЧТОБЫ УЗНАТЬ')
    w1, w2 = f2.measureText(l1), f2.measureText(l2)
    txt(cv, l1, 540 - (w1 + w2) / 2, 1080, f2, YEL, 'l', a, shadow=5)
    txt(cv, l2, 540 - (w1 + w2) / 2 + w1, 1080, f2, '#ffffff', 'l', a, shadow=5)
    l3 = story.get('cta2', 'ПРАВДУ')
    w3 = f2.measureText(l3)
    txt(cv, l3, 540 - 30, 1146, f2, '#ffffff', 'c', a, shadow=5)
    if a > 0:
        cv.saveLayerAlpha(None, int(a))
        bell(cv, 540 + w3 / 2 + 22, 1128, 1.5)
        cv.restore()
    a = 255 * clamp((lt - 1.2) / 0.3) * (0.75 + 0.25 * math.sin(lt * 6))
    f3 = font(TF_BLACK, 38)
    wt = f3.measureText('НЕ МОРГАЙ')
    ell(cv, 540 - wt / 2 - 14, 1716, 24, 14, '#ffffff', a)
    circ(cv, 540 - wt / 2 - 14, 1716, 9, '#3a241c', a)
    txt(cv, 'НЕ МОРГАЙ', 540 + 24, 1730, f3, '#ff3b6b', 'c', a)


def S(text, vis, bottom=None, fx=None, sfx=None, **p):
    return dict(text=text, vis=vis, bottom=bottom, fx=fx, sfx=sfx, p=p)


class Film:
    def __init__(self, story):
        self.story = story
        self.sc, self.events, self.subs = [], [], []
        T = 0.0
        last = len(story['scenes']) - 1
        for i, s in enumerate(story['scenes']):
            words = parse(s['text'])
            ri = next((j for j, (_, c) in enumerate(words) if c), len(words) - 1)
            w0 = 0.35 if i else 0.04  # the hook caption starts on the first frames
            rev = w0 + ri * STEP
            wend = w0 + len(words) * STEP
            dur = wend + 1.55 + (1.0 if s['bottom'] else 0)
            self.sc.append(dict(s, t0=T, t1=T + dur, words=words, rev=rev, bot=wend + 0.35, w0=w0))
            self.events.append((T, 'boom', 0.75))
            for j in range(len(words)):
                self.events.append((T + w0 + j * STEP, 'tick', 0.3))
            if s['fx'] == 'red' or i == 0:
                self.events.append((T + (rev if i else 0), 'sting', 0.8))
            if i == last:
                self.events.append((T + max(0, rev - 0.8), 'riser', 0.7))
            if s['sfx']:
                self.events.append((T + rev, s['sfx'], 0.9))
            if s['bottom']:
                self.events.append((T + wend + 0.35, 'boom', 0.9))
                self.subs.append((T + wend + 0.35, T + dur, s['bottom']))
            self.subs.append((T + w0, T + (wend + 0.3 if s['bottom'] else dur), plain(s['text'])))
            T += dur
        self.end0 = T
        self.events.append((T, 'boom', 0.9))
        self.events.append((T + 0.25, 'ding', 0.5))
        self.total = T + 3.5
        self.moods = [(0, self.total, 'spooky')]
        self.subs.sort()
        self.surface = skia.Surface(W, H)

    def frame(self, t):
        cv = self.surface.getCanvas()
        cv.clear(C('#000000'))
        if t >= self.end0:
            lt = t - self.end0
            endcard(cv, lt, self.story)
            cv.drawColor(C('#000000', 255 * (1 - clamp(lt / 0.2))))
            return self.surface
        i = max(j for j, s in enumerate(self.sc) if s['t0'] <= t)
        s = self.sc[i]
        lt = t - s['t0']
        tr = lt - s['rev']
        p = dict(s['p'])
        if tr >= 0 and 'after' in p:
            p.update(p['after'])
        rv = ease(tr / 0.4) if tr > 0 else 0.0
        hot = s['fx'] == 'red'
        red = (0.55 * rv if hot else 0) + (0.9 * (1 - clamp(lt / 0.7)) if i == 0 else 0)
        backdrop(cv, 'room' if s['vis'] == 'people' else 'blue', min(1, red))
        z = (0.86 + 0.14 * back((lt + (0.4 if i == 0 else 0)) / 0.4)) * (1 + 0.035 * lt / (s['t1'] - s['t0']))
        if hot and tr > 0:
            z *= 1 + 0.07 * (1 - ease(tr / 0.5))
        shx = math.sin(t * 80) * 12 * (1 - clamp(tr / 0.5)) if hot and tr > 0 else 0
        cv.save()
        cv.translate(540 + shx, 1040)
        cv.scale(z, z)
        cv.translate(-540, -1040)
        if s['vis'] != 'people':
            glow(cv, 540, 1040, 640, RED if hot and tr > 0 else '#3d63c9', 60)
        VIS[s['vis']](cv, t, lt, rv, tr, p)
        cv.restore()
        if hot and tr > 0:
            cv.drawColor(C('#ff1a1a', 120 * (1 - clamp(tr / 0.7))))
        caption(cv, s['words'], lt, s['w0'])
        if s['bottom'] and lt > s['bot']:
            f = font(TF_BLACK, 78)
            if f.measureText(s['bottom']) > 980:
                f = font(TF_BLACK, 78 * 980 / f.measureText(s['bottom']))
            k = back((lt - s['bot']) / 0.25)
            cv.save()
            cv.translate(540 + math.sin(t * 40) * 3, 1735)
            cv.scale(k, k)
            gp = PF(RED, 200)
            gp.setMaskFilter(skia.MaskFilter.MakeBlur(skia.kNormal_BlurStyle, 18))
            cv.drawString(s['bottom'], -f.measureText(s['bottom']) / 2, 0, f, gp)
            txt(cv, s['bottom'], 0, 0, f, RED, shadow=6)
            cv.restore()
        if i:
            cv.drawColor(C('#000000', 255 * (1 - clamp(lt / 0.22))))
        return self.surface


# ---------- stories ----------
GIRL = dict(top='#8a5cd6', hair='#3a241c', style='long')
MOM = dict(top='#35a37a', hair='#6b4226', style='bun')
MAN = dict(top='#3f7fd9', hair='#3a2a20', style='short')
BOY = dict(top='#e0902e', hair='#6b4226', style='short', s=1.35)
TAGS = '#страшныеистории #мистика #истории #анимация #часть1 #неморгай #рек'


def stories():
    return [
        dict(id='M01_shepot_iz_radionyani', title='Шёпот из радионяни',
             caption='Ночью из радионяни кто-то запел колыбельную. Мужским голосом 😨 Часть 2 — уже скоро, подпишись, чтобы не пропустить.\n\n' + TAGS + ' #радионяня',
             scenes=[
                 S('Аня купила радионяню. Ночью из неё раздался *чей-то шёпот*', 'frame', kind='monitor'),
                 S('Мужской голос тихо пел *колыбельную*', 'frame', kind='monitor', notes=1),
                 S('Муж отмахнулся: «Помехи». Но Аня *не могла уснуть*', 'people',
                   who=[dict(MAN, expr='neutral'), dict(GIRL, expr='sad')]),
                 S('Она включила камеру. Ребёнок спал. А над кроваткой *кто-то стоял*', 'phone', fx='red', app='cam',
                   kind='crib', time='03:07', after=dict(shade=1)),
                 S('Аня вбежала в детскую. *Никого*', 'people', who=[dict(GIRL, expr='scared')]),
                 S('А из радионяни прошептали: *«Тише. Разбудишь»*', 'frame', fx='red', kind='monitor',
                   after=dict(red=1), bottom='ОН ВСЁ ЕЩЁ ТАМ'),
             ]),
        dict(id='M02_chetvertyy_na_risunke', title='Четвёртый на рисунке', cta='ЧТОБЫ УЗНАТЬ,', cta2='КТО ЭТО',
             caption='Сын рисует семью каждый день. И каждый раз нас на рисунке четверо 😳 Кто четвёртый — в части 2. Подпишись.\n\n' + TAGS + ' #детскийрисунок',
             scenes=[
                 S('Сын каждый день рисует семью. И на каждом рисунке нас *четверо*', 'papers',
                   items=['family', 'family', 'family']),
                 S('Мама, папа, он. И высокий *чёрный человек*', 'papers', items=['family'], hot=1),
                 S('«Кто это?» — «Он живёт *у нас в шкафу*»', 'people',
                   who=[dict(MOM, expr='neutral'), dict(BOY, expr='smile')]),
                 S('Мама открыла шкаф. *Пусто*', 'frame', kind='closet'),
                 S('Сын пожал плечами: «Конечно. *Ночью он выходит*»', 'people', who=[dict(BOY, expr='neutral', s=1.6)]),
                 S('Утром на столе лежал новый рисунок. Чёрный человек стоял *у её кровати*', 'papers', fx='red',
                   items=['bed'], bottom='И ДЕРЖАЛ ЕЁ ЗА РУКУ'),
             ]),
        dict(id='M03_tochka_na_karte', title='Точка на карте',
             caption='Жена уехала, а её геолокация показывает, что она дома. И точка двигается 😨 Продолжение в части 2.\n\n' + TAGS + ' #геолокация',
             scenes=[
                 S('Дима открыл геолокацию жены. Точка была *дома. В спальне*', 'phone', app='map', pos=0),
                 S('Но жена ещё утром уехала *в другой город*', 'phone', app='chat', name='Жена', letter='Ж',
                   col='#e86fa8', msgs=[('in', 'Села в поезд!'), ('in', 'Буду в четверг'), ('out', 'Хорошей дороги')]),
                 S('Он позвонил. «Я в поезде. Телефон *со мной*»', 'phone', app='call', name='Жена', letter='Ж',
                   sub='идёт вызов…'),
                 S('Дима посмотрел на карту. Точка *начала двигаться*', 'phone', fx='red', app='map', pos=0, pos2=0.5),
                 S('Из спальни — в коридор. *К его комнате*', 'phone', app='map', pos=0.5, pos2=1.0),
                 S('Он поднял глаза. Дверная ручка *медленно опустилась*', 'frame', fx='red', kind='door', handle=1,
                   after=dict(feet=1), bottom='ТОЧКА — ЗА ДВЕРЬЮ'),
             ]),
        dict(id='M04_soobshenie_ot_sebya', title='Сообщение от себя',
             caption='В 3:00 мне пришло сообщение. С моего же номера: «Не открывай дверь» 😨 Что было дальше — в части 2.\n\n' + TAGS + ' #переписка',
             scenes=[
                 S('В 3:00 Кате пришло сообщение. *С её же номера*', 'phone', app='chat', name='Катя (Вы)', letter='К',
                   col='#8a5cd6', sub='был(а) только что', msgs=[('in', 'Это я. То есть ты.')]),
                 S('«Не открывай дверь. *Что бы ты ни услышала*»', 'phone', app='chat', name='Катя (Вы)', letter='К',
                   col='#8a5cd6', sub='печатает…', shown=1,
                   msgs=[('in', 'Это я. То есть ты.'), ('in', 'Не открывай дверь.'), ('in', 'Что бы ты ни услышала.')]),
                 S('Катя решила: взлом. И *легла спать*', 'frame', kind='bed', girl='sleep', clock='3:02'),
                 S('В 3:15 в дверь *постучали*', 'frame', fx='red', sfx='knock', kind='door', num='27',
                   after=dict(knock=1)),
                 S('«Катя, открой. Это мама», — сказал *мамин голос*', 'frame', kind='door', num='27', knock=1,
                   speech='Катя, открой. Это мама'),
                 S('Телефон звякнул: «Мама спит *в соседней комнате*»', 'phone', fx='red', sfx='knock', app='chat',
                   name='Катя (Вы)', letter='К', col='#8a5cd6', sub='печатает…', shown=2, last_rv=1,
                   msgs=[('in', 'Не открывай дверь.'), ('in', 'Что бы ты ни услышала.'),
                         ('in', 'Мама спит в соседней комнате.')], bottom='СТУК ПОВТОРИЛСЯ'),
             ]),
        dict(id='M05_otrazhenie_opazdyvaet', title='Отражение опаздывает',
             caption='Моё отражение моргает на секунду позже меня. А вчера оно подняло не ту руку 😨 Часть 2 скоро.\n\n' + TAGS + ' #зеркало',
             scenes=[
                 S('Лена заметила: её отражение моргает *на секунду позже*', 'frame', kind='mirror'),
                 S('Подруга смеялась: «Тебе надо *выспаться*»', 'people',
                   who=[dict(top='#e0902e', hair='#b5673e', style='long', expr='smile'), dict(GIRL, expr='sad')]),
                 S('Ночью Лена встала перед зеркалом и *подняла руку*', 'frame', kind='mirror',
                   after=dict(arms='up')),
                 S('Отражение подняло тоже. Но *другую*', 'frame', fx='red', kind='mirror', arms='up',
                   after=dict(rarms='up_l')),
                 S('Лена отступила на шаг. А оно — *шагнуло вперёд*', 'frame', kind='mirror', back=1,
                   after=dict(rs=1.45, rs_anim=1)),
                 S('И прижало ладонь к стеклу. *Изнутри*', 'frame', fx='red', kind='mirror', back=1, rs=1.45,
                   after=dict(palm=1, rexpr='grin'), bottom='ОНО УЛЫБАЛОСЬ'),
             ]),
        dict(id='M06_budilnik_na_3_33', title='Будильник на 3:33',
             caption='На новом телефоне стоит будильник на 3:33. Я его не ставила. И он не удаляется 😨 Часть 2 — скоро.\n\n' + TAGS + ' #будильник',
             scenes=[
                 S('На новом телефоне Оли стоял будильник на 3:33. Она его *не ставила*', 'phone', app='alarm'),
                 S('Оля удалила его. Утром он *появился снова*', 'phone', app='alarm', gone=1,
                   after=dict(gone=0, pop=1)),
                 S('А под ним — подпись: *«Не спи»*', 'phone', app='alarm', after=dict(label='«НЕ СПИ»', label_rv=1)),
                 S('Ночью Оля решила не ложиться и *проверить*', 'frame', kind='bed', girl='sit', clock='3:32'),
                 S('В 3:33 будильник зазвонил. Но *не на её телефоне*', 'frame', fx='red', kind='bed', girl='sit',
                   clock='3:33', after=dict(expr='scared', shake=3)),
                 S('Звук шёл *из-под кровати*', 'frame', fx='red', kind='bed', girl='sit', clock='3:33', expr='scared',
                   after=dict(glow=1), bottom='ТАМ ГОРЕЛ ЭКРАН'),
             ]),
        dict(id='M07_chetyre_foto', title='Четыре фото', cta='ЧТОБЫ УЗНАТЬ,', cta2='КТО СНИМАЛ',
             caption='С незнакомого номера пришло фото моего дома. Потом подъезда. Потом двери. А четвёртое… 😨 Часть 2 скоро.\n\n' + TAGS + ' #незнакомыйномер',
             scenes=[
                 S('Марине пришло фото с незнакомого номера. На нём — *её дом*', 'phone', app='gallery',
                   label='НЕИЗВЕСТНЫЙ НОМЕР', kind='house'),
                 S('Через минуту — второе. *Её подъезд*', 'phone', app='gallery', label='ФОТО 2', kind='entrance'),
                 S('Потом третье. *Её дверь*', 'phone', fx='red', app='gallery', label='ФОТО 3', kind='door', num='27'),
                 S('Она написала: «Кто это?» *Ответа не было*', 'phone', app='chat', name='Неизвестный', sub='в сети',
                   msgs=[('out', 'Кто это?'), ('out', 'Я вызову полицию')]),
                 S('Пришло четвёртое фото. На нём была *она сама*', 'phone', app='gallery', label='ФОТО 4', kind='back'),
                 S('Со спины. В этой комнате. *Только что*', 'frame', fx='red', kind='behind',
                   bottom='ОНА НЕ ОБЕРНУЛАСЬ'),
             ]),
        dict(id='M08_okno_naprotiv', title='Окно напротив',
             caption='В доме напротив каждую ночь горит одно окно. И кто-то смотрит на меня. А дом расселили год назад 😨 Часть 2 скоро.\n\n' + TAGS + ' #окнонапротив',
             scenes=[
                 S('В доме напротив каждую ночь горит *одно окно*', 'frame', kind='facade', lit=[(2, 1)]),
                 S('В нём стоит человек. И *смотрит на Сашу*', 'frame', kind='facade', lit=[(2, 1)], fig=1, zoom=1),
                 S('Саша помахал ему. Человек *помахал в ответ*', 'frame', fx='red', kind='facade', lit=[(2, 1)], fig=1,
                   zoomed=1, after=dict(wave=1)),
                 S('Утром сосед сказал: тот дом *год как расселён*', 'people',
                   who=[dict(top='#7a6a5a', hair='#b9b9c6', style='short', expr='neutral'),
                        dict(MAN, top='#c0524f', expr='scared')]),
                 S('Ночью окно загорелось снова. Но человека *в нём не было*', 'frame', kind='facade', lit=[(2, 1)], zoom=1),
                 S('А на стекле Сашиного окна был след ладони. *Снаружи*', 'frame', fx='red', kind='window',
                   after=dict(palm=1), bottom='ДЕВЯТЫЙ ЭТАЖ'),
             ]),
        dict(id='M09_kolonka_otvetila', title='Колонка ответила', cta='ЧТОБЫ УЗНАТЬ,', cta2='КТО СПРАШИВАЛ',
             caption='Ночью умная колонка с кем-то разговаривала. Утром я открыла историю запросов 😨 Я живу одна. Часть 2 скоро.\n\n' + TAGS + ' #умнаяколонка',
             scenes=[
                 S('Ночью умная колонка включилась сама: *«Повторите вопрос»*', 'frame', kind='speaker',
                   say='Повторите вопрос', say_rv=1),
                 S('Но Вика молчала. *Она спала*', 'frame', kind='bed', girl='sleep', clock='3:00'),
                 S('Утром в истории было сорок запросов. Все — *в три ночи*', 'phone', app='list',
                   rows=[('03:00', 'Кто сейчас дома?'), ('03:00', 'Она спит?'), ('03:01', 'Выключи свет в коридоре'),
                         ('03:01', 'Громкость на ноль'), ('03:02', 'Не буди её')]),
                 S('Голос на записях был *мужской*', 'people', who=[dict(GIRL, top='#3fa37a', expr='scared')]),
                 S('Последний запрос: *«Как тихо открыть дверь?»*', 'phone', fx='red', app='list', hot=4,
                   rows=[('03:01', 'Выключи свет в коридоре'), ('03:01', 'Громкость на ноль'), ('03:02', 'Не буди её'),
                         ('03:03', 'Где её комната?'), ('03:04', 'Как тихо открыть дверь?')]),
                 S('Вика живёт одна. А колонка *ему ответила*', 'frame', fx='red', kind='speaker', col='#ff3b30',
                   say='Готово. Дверь открыта', say_rv=1, bottom='ДВЕРЬ БЫЛА ОТКРЫТА'),
             ]),
        dict(id='M10_zayac_na_polke', title='Заяц на полке',
             caption='Плюшевый заяц каждое утро сидит на новом месте. Я поставила камеру на ночь 😨 Зря. Часть 2 скоро.\n\n' + TAGS + ' #игрушка',
             scenes=[
                 S('Плюшевый заяц каждое утро сидит *на новом месте*', 'frame', kind='shelf', bunny='side'),
                 S('Маша думала — шутит брат. Но брат *уехал в лагерь*', 'people',
                   who=[dict(MOM, expr='neutral'), dict(GIRL, expr='sad', s=1.45)]),
                 S('Тогда она поставила на ночь *камеру*', 'phone', app='cam', kind='shelf', bunny='side', night=1,
                   time='23:10'),
                 S('В 3:00 на записи заяц *повернул голову*', 'phone', fx='red', app='cam', kind='shelf', bunny='side',
                   night=1, time='03:00', after=dict(bunny='cam')),
                 S('И посмотрел *прямо в камеру*', 'phone', app='cam', kind='shelf', bunny='cam', night=1, time='03:00',
                   after=dict(zoom=0.9, red=1)),
                 S('Маша обернулась. Зайца на полке *не было*', 'frame', fx='red', kind='shelf', bunny='side',
                   after=dict(bunny=None), bottom='ОН СИДЕЛ У ДВЕРИ'),
             ]),
    ]


# ---------- output ----------
def ts(t):
    ms = int(round(t * 1000))
    return '%02d:%02d:%02d,%03d' % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)


def sheet(story):
    fl = Film(story)
    cols, tw, th = 7, 270, 480
    surf = skia.Surface(cols * tw, 2 * th)
    cv = surf.getCanvas()
    shots = []
    for s in fl.sc:
        shots.append(s['t0'] + s['rev'] - 0.05)
        shots.append(s['t1'] - 0.1)
    shots = shots[:12] + [fl.end0 + 0.5, fl.total - 0.2]
    for k, t in enumerate(shots):
        img = fl.frame(t).makeImageSnapshot()
        cv.drawImageRect(img, skia.Rect.MakeXYWH((k % cols) * tw, (k // cols) * th, tw, th),
                         skia.SamplingOptions(skia.FilterMode.kLinear))
    os.makedirs('/tmp/msheets', exist_ok=True)
    surf.makeImageSnapshot().save('/tmp/msheets/%s.jpg' % story['id'], skia.kJPEG)
    print('%s: %.1fs' % (story['id'], fl.total))


def render(story):
    fl = Film(story)
    d = os.path.join(OUT, story['id'])
    os.makedirs(d, exist_ok=True)
    base = os.path.join(d, story['id'])
    with open(base + '_subtitles_RU.srt', 'w') as f:
        for i, (a, b, s) in enumerate(fl.subs, 1):
            f.write('%d\n%s --> %s\n%s\n\n' % (i, ts(a), ts(b), s))
    with open(base + '_script_RU.txt', 'w') as f:
        f.write(story['title'] + '\n' + '=' * len(story['title']) + '\n\n')
        for s in fl.sc:
            f.write('%s  %s\n' % (ts(s['t0'])[:8], plain(s['text'])))
            if s['bottom']:
                f.write('          [%s]\n' % s['bottom'])
        f.write('%s  ЧАСТЬ 2 УЖЕ СКОРО\n' % ts(fl.end0)[:8])
    with open(base + '_caption_RU.txt', 'w') as f:
        f.write(story['caption'] + '\n')
    wav = base + '.wav'
    audio.build(fl, wav, seed=sum(map(ord, story['id'])))
    ff = subprocess.Popen(
        ['ffmpeg', '-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'bgra', '-s', '%dx%d' % (W, H), '-r', str(FPS),
         '-i', '-', '-i', wav, '-c:v', 'libx264', '-preset', 'fast', '-crf', '20', '-pix_fmt', 'yuv420p', '-c:a', 'aac',
         '-b:a', '160k', '-shortest', '-movflags', '+faststart', base + '.mp4'], stdin=subprocess.PIPE)
    for i in range(int(fl.total * FPS)):
        ff.stdin.write(fl.frame(i / FPS).toarray().tobytes())
    ff.stdin.close()
    if ff.wait():
        raise SystemExit('ffmpeg failed for ' + story['id'])
    os.remove(wav)
    print('%s: %.1fs rendered' % (story['id'], fl.total), flush=True)


if __name__ == '__main__':
    cmd, filt = sys.argv[1], sys.argv[2:]
    for st in stories():
        if not filt or any(x in st['id'] for x in filt):
            (sheet if cmd == 'sheet' else render)(st)
