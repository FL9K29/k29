"""Cartoon short renderer: flat outlined characters, hook card, rule badges, word-pop subtitles."""
import bisect
import copy
import math
import os
import random

import skia

W, H, FPS = 1080, 1920, 24
FY, GY = 1240, 1570  # floor horizon / feet line
ROOT = os.path.dirname(os.path.abspath(__file__))
OL = '#111111'


def _tf(name):
    return skia.Typeface.MakeFromFile(os.path.join(ROOT, 'assets/fonts', name))


TF_BLACK, TF_BOLD, TF_MED = _tf('Montserrat-Black.ttf'), _tf('Montserrat-Bold.ttf'), _tf('Montserrat-Medium.ttf')


# ---------- drawing helpers ----------
def C(h, a=255):
    h = h.lstrip('#')
    return skia.Color(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), int(a))


def PF(h, a=255):
    return skia.Paint(Color=C(h, a), AntiAlias=True)


def PS(h, w, a=255):
    return skia.Paint(Color=C(h, a), AntiAlias=True, Style=skia.Paint.kStroke_Style, StrokeWidth=w,
                      StrokeCap=skia.Paint.kRound_Cap, StrokeJoin=skia.Paint.kRound_Join)


def opath(cv, p, col, sw=8):
    cv.drawPath(p, PF(col))
    cv.drawPath(p, PS(OL, sw))


def ocirc(cv, x, y, r, col, sw=8):
    cv.drawCircle(x, y, r, PF(col))
    cv.drawCircle(x, y, r, PS(OL, sw))


def orr(cv, x, y, w, h, r, col, sw=8, a=255):
    rc = skia.Rect.MakeXYWH(x, y, w, h)
    cv.drawRoundRect(rc, r, r, PF(col, a))
    if sw:
        cv.drawRoundRect(rc, r, r, PS(OL, sw))


def oval(cv, x, y, rx, ry, col, sw=8):
    rc = skia.Rect.MakeLTRB(x - rx, y - ry, x + rx, y + ry)
    cv.drawOval(rc, PF(col))
    if sw:
        cv.drawOval(rc, PS(OL, sw))


def line(cv, x1, y1, x2, y2, col=OL, w=8):
    cv.drawLine(x1, y1, x2, y2, PS(col, w))


def poly(pts):
    p = skia.Path()
    p.moveTo(*pts[0])
    for q in pts[1:]:
        p.lineTo(*q)
    p.close()
    return p


def font(tf, size):
    f = skia.Font(tf, size)
    f.setSubpixel(True)
    return f


def otext(cv, txt, x, y, f, col='#ffffff', ow=12, align='c', a=255):
    w = f.measureText(txt)
    if align == 'c':
        x -= w / 2
    elif align == 'r':
        x -= w
    if ow:
        cv.drawString(txt, x, y, f, PS(OL, ow, a))
    cv.drawString(txt, x, y, f, PF(col, a))


def wrap(txt, f, maxw):
    lines, cur = [], ''
    for w in txt.split():
        t = (cur + ' ' + w).strip()
        if cur and f.measureText(t) > maxw:
            lines.append(cur)
            cur = w
        else:
            cur = t
    if cur:
        lines.append(cur)
    return lines


def clamp(k, a=0.0, b=1.0):
    return max(a, min(b, k))


def ease(k):
    k = clamp(k)
    return 1 - (1 - k) ** 3


def back(k):
    k = clamp(k)
    c1 = 1.70158
    return 1 + (c1 + 1) * (k - 1) ** 3 + c1 * (k - 1) ** 2


def mix(h1, h2, k):
    a, b = h1.lstrip('#'), h2.lstrip('#')
    return '#' + ''.join('%02x' % int(int(a[i:i + 2], 16) * (1 - k) + int(b[i:i + 2], 16) * k) for i in (0, 2, 4))


def label(cv, txt, cx, cy, size, col='#3a2414', flip=1, maxw=None):
    f = font(TF_BLACK, size)
    if maxw and f.measureText(txt) > maxw:
        f = font(TF_BLACK, size * maxw / f.measureText(txt))
    cv.save()
    cv.translate(cx, cy)
    cv.scale(flip, 1)
    otext(cv, txt, 0, f.getSize() * 0.36, f, col, 0)
    cv.restore()


# ---------- characters ----------
KINDS = {
    'gosha': dict(top='#4fbf4a', pocket=1, strings=1, legs='#2e4a9e', shoes='#f2672e', hat=('beanie', '#f7941d')),
    'masha': dict(top='#5fb8a5', pocket=1, strings=1, legs='#3a3f6b', shoes='#e8e8e8', hat=('bob', '#7a4526')),
    'mom': dict(top='#f58a3c', skirt='#5a5475', legs='#3a3f5b', shoes='#8a2040', hat=('bob', '#8a4a2a')),
    'baba': dict(top='#8e5aa8', skirt='#4d4a63', legs='#4d4a63', shoes='#5b3a4a', hat=('bob', '#b9b9c6'), glasses=1),
    'monster': dict(skin='#9b6be0', top='#7a48c8', stripes='#5b2fa6', legs='#5b2fa6', shoes='#4a2590',
                    hat=('spiky', '#4a2590'), nocheek=1),
    'dad': dict(top='#3d7edb', legs='#44485a', shoes='#2b2b33', hat=('short', '#4a3222'), moustache=1),
    'teacher': dict(top='#d9577a', skirt='#3f3f55', legs='#3f3f55', shoes='#2b2b33', hat=('bun', '#5a3a2a'), glasses=1),
    'vova': dict(top='#35b6d6', pocket=1, strings=1, legs='#444a70', shoes='#eeeeee', hat=('cap', '#e23b3b')),
    'courier': dict(top='#ffd23f', pocket=1, legs='#33353f', shoes='#222222', hat=('cap', '#ffd23f')),
    'aunt': dict(top='#e86fa8', skirt='#7a3f6b', legs='#7a3f6b', shoes='#5b2a4a', hat=('bob', '#f2d16b')),
    'cashier': dict(top='#e23b3b', legs='#33353f', shoes='#222222', hat=('bob', '#3d4fa8'), apron=1),
}
#            eyes     mouth     extras
EXPR = {
    'happy': ('open', 'open'), 'smile': ('open', 'smile'), 'neutral': ('open', 'flat'),
    'shock': ('wide', 'o'), 'scared': ('wide', 'wavy', 'sweat'), 'bored': ('half', 'flat'),
    'smug': ('half', 'smirk'), 'angry': ('half', 'frown', 'brow'), 'sad': ('closed', 'frown'),
    'cry': ('closed', 'bigfrown', 'tears'), 'joy': ('joy', 'open'), 'grin': ('wide', 'teeth'),
    'wink': ('wink', 'smile'), 'sleep': ('closed', 'o'),
}
POSES = {
    'idle': ((-112, -150), (112, -150)), 'wave': ((-112, -150), (170, -470)),
    'up': ((-175, -500), (175, -500)), 'point': ((-112, -150), (250, -255)),
    'spread': ((-240, -255), (240, -255)), 'think': ((-112, -150), (72, -262)),
    'phone': ((-112, -150), (128, -300)), 'hold': ((-112, -150), (175, -215)),
    'hips': ((-98, -195), (98, -195)), 'face': ((-112, -150), (40, -430)),
    'cover': ((-112, -350), (112, -350)),
}
R = 128  # head radius


def _eyes(cv, eyes, hy, t, look, skin, seed):
    ey = hy - 12
    er = 42 if eyes == 'wide' else 36
    blink = eyes in ('open', 'wide') and ((t + seed + 0.5) % 3.4) < 0.12
    for sx in (-1, 1):
        x = sx * 54
        if eyes == 'closed' or blink:
            cv.drawArc(skia.Rect.MakeLTRB(x - 28, ey - 24, x + 28, ey + 12), 20, 140, False, PS(OL, 8))
        elif eyes == 'joy' or (eyes == 'wink' and sx == 1):
            cv.drawArc(skia.Rect.MakeLTRB(x - 28, ey - 12, x + 28, ey + 28), 200, 140, False, PS(OL, 8))
        else:
            ocirc(cv, x, ey, er, '#ffffff', 7)
            pr = 9 if eyes == 'wide' else 14
            px, py = x + look[0] * 13, ey + look[1] * 13 + (9 if eyes == 'half' else 0)
            cv.drawCircle(px, py, pr, PF(OL))
            cv.drawCircle(px - pr * 0.3, py - pr * 0.3, pr * 0.3, PF('#ffffff'))
            if eyes == 'half':
                cv.save()
                cp = skia.Path()
                cp.addCircle(x, ey, er - 3)
                cv.clipPath(cp, True)
                cv.drawRect(skia.Rect.MakeLTRB(x - er, ey - er, x + er, ey - er * 0.12), PF(skin))
                line(cv, x - er, ey - er * 0.12, x + er, ey - er * 0.12, OL, 7)
                cv.restore()
                cv.drawCircle(x, ey, er, PS(OL, 7))


def _face(cv, expr, hy, t, look, skin, seed):
    e = EXPR[expr]
    eyes, mouth, ex = e[0], e[1], e[2:]
    _eyes(cv, eyes, hy, t, look, skin, seed)
    ey = hy - 12
    if 'brow' in ex:
        for sx in (-1, 1):
            line(cv, sx * 96, ey - 66, sx * 20, ey - 40, OL, 10)
    my = hy + 64
    dark = '#7a1f2b'
    if mouth == 'open':
        p = skia.Path()
        p.moveTo(-38, my - 10)
        p.cubicTo(-32, my + 48, 32, my + 48, 38, my - 10)
        p.close()
        opath(cv, p, dark, 7)
    elif mouth == 'smile':
        cv.drawArc(skia.Rect.MakeLTRB(-34, my - 36, 34, my + 12), 25, 130, False, PS(OL, 8))
    elif mouth == 'flat':
        line(cv, -26, my, 26, my)
    elif mouth == 'o':
        oval(cv, 0, my + 4, 15, 19, dark, 7)
    elif mouth == 'frown':
        cv.drawArc(skia.Rect.MakeLTRB(-30, my - 6, 30, my + 38), 205, 130, False, PS(OL, 8))
    elif mouth == 'smirk':
        p = skia.Path()
        p.moveTo(-22, my + 2)
        p.quadTo(8, my + 16, 32, my - 12)
        cv.drawPath(p, PS(OL, 8))
    elif mouth == 'teeth':
        orr(cv, -54, my - 22, 108, 44, 18, '#ffffff', 7)
        for i in range(-2, 3):
            line(cv, i * 18, my - 20, i * 18, my + 20, OL, 4)
    elif mouth == 'wavy':
        p = skia.Path()
        p.moveTo(-30, my)
        for i in range(1, 7):
            p.lineTo(-30 + i * 10, my + (7 if i % 2 else -7))
        cv.drawPath(p, PS(OL, 7))
    elif mouth == 'bigfrown':
        p = skia.Path()
        p.moveTo(-34, my + 30)
        p.cubicTo(-28, my - 26, 28, my - 26, 34, my + 30)
        p.close()
        opath(cv, p, dark, 7)
    if 'sweat' in ex:
        for i, (dx, dy) in enumerate(((-R - 14, -70), (-R - 2, -8))):
            ocirc(cv, dx, hy + dy + ((t * 60 + i * 20) % 30), 11, '#4aa8ff', 5)
    if 'tears' in ex:
        for sx in (-1, 1):
            ln = 60 + 14 * math.sin(t * 9 + sx)
            orr(cv, sx * 54 - 11, ey + 8, 22, ln, 11, '#6cc4ff', 5)


def _hat_back(cv, hat, hy):
    kind, col = hat
    if kind == 'bob':
        orr(cv, -(R + 26), hy - R - 30, 2 * R + 52, 2 * R + 80, 140, col)
    elif kind == 'bun':
        ocirc(cv, 0, hy - R - 26, 52, col)
        ocirc(cv, 0, hy - 6, R + 16, col)
    elif kind == 'spiky':
        pts = []
        for i in range(11):
            ang = math.radians(196 + i * 14.8)
            rr = R + (82 if i % 2 else 4)
            pts.append((math.cos(ang) * rr, hy + math.sin(ang) * rr))
        opath(cv, poly(pts), col)


def _hat_front(cv, hat, hy):
    kind, col = hat
    if kind in ('beanie', 'cap'):
        r = R + 8
        yb = hy - 0.28 * R
        p = skia.Path()
        p.arcTo(skia.Rect.MakeLTRB(-r, hy - r, r, hy + r), 195, 150, True)
        p.quadTo(0, yb - 34, -r * math.cos(math.radians(15)), yb)
        p.close()
        opath(cv, p, col)
        if kind == 'cap':
            orr(cv, 30, yb - 30, 150, 30, 14, col)
    elif kind in ('bob', 'bun', 'short'):
        cv.save()
        cp = skia.Path()
        cp.addCircle(0, hy, R - 3)
        cv.clipPath(cp, True)
        ry = R * (0.6 if kind != 'short' else 0.5)
        oval(cv, 0, hy - R, R * 1.2, ry, col)
        cv.restore()
        cv.drawCircle(0, hy, R, PS(OL, 8))


def _held(cv, hold, hx, hy, flip):
    if hold == 'phone':
        orr(cv, hx - 24, hy - 62, 48, 84, 9, '#2b2f3a', 6)
        cv.drawRect(skia.Rect.MakeXYWH(hx - 16, hy - 52, 32, 60), PF('#8fd3ff'))
    elif hold == 'mop':
        line(cv, hx, hy - 380, hx, hy + 150, OL, 20)
        line(cv, hx, hy - 380, hx, hy + 150, '#c9a36b', 10)
        orr(cv, hx - 60, hy - 430, 120, 60, 16, '#d9dde6', 7)
        for i in range(-2, 3):
            line(cv, hx + i * 20, hy - 420, hx + i * 20, hy - 380, OL, 4)
    elif isinstance(hold, (tuple, list)):
        kind, txt, col = hold
        f = font(TF_BLACK, 32)
        w = max(130, f.measureText(txt) + 44)
        if kind == 'plate':
            oval(cv, hx + 10, hy - 34, w / 2 + 14, 30, '#f4f4f4', 7)
            oval(cv, hx + 10, hy - 40, w / 2 - 6, 22, col, 6)
            label(cv, txt, hx + 10, hy - 40, 26, '#ffffff', flip)
        elif kind == 'bag':
            opath(cv, poly([(hx - w / 2 + 10, hy - 150), (hx + w / 2 + 10, hy - 150), (hx + w / 2 + 24, hy + 10),
                            (hx - w / 2 - 4, hy + 10)]), col, 7)
            label(cv, txt, hx + 10, hy - 70, 34, '#3a2414', flip)
        else:
            orr(cv, hx + 10 - w / 2, hy - 86, w, 78, 10, col, 7)
            label(cv, txt, hx + 10, hy - 47, 32, '#3a2414', flip)


def draw_cat(cv, a, t, eyes_only=False):
    if eyes_only:
        for sx in (-1, 1):
            oval(cv, sx * 26, -176, 13, 17, '#d8ff5a', 5)
            cv.drawOval(skia.Rect.MakeLTRB(sx * 26 - 4, -190, sx * 26 + 4, -162), PF(OL))
        return
    col = '#f2a03d'
    cv.drawOval(skia.Rect.MakeLTRB(-90, -12, 90, 20), PF('#000000', 60))
    p = skia.Path()
    p.moveTo(60, -30)
    p.cubicTo(150, -30, 150, -140 + 10 * math.sin(t * 3), 110, -150)
    cv.drawPath(p, PS(OL, 34))
    cv.drawPath(p, PS(col, 20))
    oval(cv, 0, -70, 78, 72, col)
    oval(cv, 0, -50, 40, 46, '#ffe3b8', 0)
    for sx in (-1, 1):
        opath(cv, poly([(sx * 62, -205), (sx * 60, -262), (sx * 18, -228)]), col)
    ocirc(cv, 0, -170, 70, col)
    half = a.get('expr') in ('smug', 'bored')
    for sx in (-1, 1):
        oval(cv, sx * 26, -176, 13, 17, '#ffffff', 5)
        cv.drawOval(skia.Rect.MakeLTRB(sx * 26 - 5, -186, sx * 26 + 5, -164), PF(OL))
        if half:
            cv.drawRect(skia.Rect.MakeLTRB(sx * 26 - 18, -196, sx * 26 + 18, -178), PF(col))
            line(cv, sx * 26 - 15, -178, sx * 26 + 15, -178, OL, 5)
        for k in (-1, 0, 1):
            line(cv, sx * 44, -150 + k * 3, sx * 96, -150 + k * 14, OL, 3)
    opath(cv, poly([(-8, -152), (8, -152), (0, -142)]), '#ff8fa3', 4)
    if a.get('hold'):
        _held(cv, a['hold'], 110, -10, -1 if a.get('flip') else 1)


def draw_char(cv, a, t, eyes_only=False):
    k = clamp((t - a.get('show_t', -9)) / 0.28)
    if k <= 0:
        return
    s = a['s'] * back(k)
    flip = -1 if a.get('flip') else 1
    seed = (a['x'] * 0.013 + len(a['kind'])) % 3
    cv.save()
    sh = a.get('shake', 0)
    cv.translate(a['x'] + (math.sin(t * 55) * sh if sh else 0), a['y'])
    cv.scale(s * flip, s * (0.9 + 0.1 * back(k)))
    if a['kind'] == 'cat':
        draw_cat(cv, a, t, eyes_only)
        cv.restore()
        return
    K = dict(KINDS[a['kind']])
    K.update(a.get('over') or {})
    expr = a.get('expr', 'smile')
    skin = K.get('skin', '#ffffff')
    if expr == 'scared' and 'skin' not in K:
        skin = '#d5dcee'
    bob = math.sin(t * 2.4 + seed * 2) * 4
    hy = -405 + bob * 1.4
    look = a.get('look', (0, 0))
    if eyes_only:
        _eyes(cv, EXPR[expr][0], hy, t, look, '#0a0a18', seed)
        cv.restore()
        return
    cv.drawOval(skia.Rect.MakeLTRB(-125, -14, 125, 24), PF('#000000', 60))
    walk = a.get('walk', 0)
    for sx in (-1, 1):
        ly = -28 - (max(0, math.sin(t * 14 + sx)) * 22 if walk else 0)
        line(cv, sx * 40, -125, sx * 40, ly, OL, 46)
        line(cv, sx * 40, -125, sx * 40, ly, K['legs'], 30)
        oval(cv, sx * 40 + 8, ly + 12, 36, 21, K['shoes'])
    if K.get('skirt'):
        opath(cv, poly([(-84, -200), (84, -200), (104, -92), (-104, -92)]), K['skirt'])
    by = -312 + bob
    orr(cv, -92, by, 184, 208, 52, K['top'])
    if K.get('stripes'):
        cv.save()
        cp = skia.Path()
        cp.addRoundRect(skia.Rect.MakeXYWH(-88, by + 4, 176, 200), 50, 50)
        cv.clipPath(cp, True)
        for i in range(5):
            line(cv, -100, by + 70 + i * 36, 100, by + 70 + i * 36, K['stripes'], 12)
        cv.restore()
    if K.get('apron'):
        orr(cv, -62, by + 70, 124, 150, 18, '#f4f4f4', 6)
    if K.get('pocket'):
        orr(cv, -48, by + 122, 96, 56, 16, mix(K['top'], '#000000', 0.12), 6)
    if K.get('strings'):
        for sx in (-1, 1):
            line(cv, sx * 20, by + 78, sx * 20, by + 104, OL, 5)
            cv.drawCircle(sx * 20, by + 110, 6, PF('#ffffff'))
            cv.drawCircle(sx * 20, by + 110, 6, PS(OL, 4))
    hat = K.get('hat')
    if hat:
        _hat_back(cv, hat, hy)
    ocirc(cv, 0, hy, R, skin)
    if not K.get('nocheek'):
        for sx in (-1, 1):
            cv.drawCircle(sx * 92, hy + 40, 22, PF('#ff8fa8', 130))
    _face(cv, expr, hy, t, look, skin, seed)
    if K.get('glasses'):
        for sx in (-1, 1):
            cv.drawCircle(sx * 54, hy - 12, 48, PS(OL, 7))
        line(cv, -8, hy - 14, 8, hy - 14, OL, 7)
    if hat:
        _hat_front(cv, hat, hy)
    if K.get('moustache'):
        oval(cv, 0, hy + 42, 46, 14, '#4a3222', 6)
    if K.get('beard'):
        p = skia.Path()
        p.moveTo(-R * 0.82, hy + 60)
        p.cubicTo(-R * 0.7, hy + R + 150, R * 0.7, hy + R + 150, R * 0.82, hy + 60)
        p.cubicTo(R * 0.3, hy + 120, -R * 0.3, hy + 120, -R * 0.82, hy + 60)
        opath(cv, p, '#d9d9e2')
    # arms
    pose = a.get('pose', 'idle')
    hold = a.get('hold')
    if hold and pose == 'idle':
        pose = 'phone' if hold == 'phone' else 'hold'
    hands = [list(POSES[pose][0]), list(POSES[pose][1])]
    if pose == 'wave':
        hands[1][0] += math.sin(t * 11) * 26
    if pose == 'up':
        for i in (0, 1):
            hands[i][1] += math.sin(t * 13 + i) * 12
    for i, sx in enumerate((-1, 1)):
        sxp, syp = sx * 78, by + 46
        hx, hyy = hands[i]
        ex = (sxp + hx) / 2 + sx * (95 if pose == 'hips' else 34)
        eyy = (syp + hyy) / 2 + 22
        p = skia.Path()
        p.moveTo(sxp, syp)
        p.quadTo(ex, eyy, hx, hyy)
        cv.drawPath(p, PS(OL, 46))
        cv.drawPath(p, PS(K['top'], 30))
        if i == 1 and hold:
            _held(cv, hold, hx, hyy, flip)
        ocirc(cv, hx, hyy, 26, skin)
    cv.restore()


# ---------- backgrounds ----------
def _floor(cv, col, lcol, vx=540):
    cv.drawRect(skia.Rect.MakeLTRB(0, FY, W, H), PF(col))
    for i in range(-3, 13):
        x = i * 120
        line(cv, x, FY, vx + (x - vx) * 2.1, H, lcol, 5)
    line(cv, 0, FY, W, FY, OL, 8)


def _window(cv, x, y, w, h, night, t=0):
    orr(cv, x, y, w, h, 6, '#141a3d' if night else '#8fc4ee')
    if night:
        cv.drawCircle(x + w * 0.68, y + h * 0.2, 30, PF('#e8e2c8'))
        rnd = random.Random(7)
        for i in range(3):
            bx = x + 14 + i * (w - 28) / 3
            bh = h * (0.3 + 0.2 * rnd.random())
            cv.drawRect(skia.Rect.MakeXYWH(bx, y + h - bh - 6, (w - 40) / 3, bh), PF('#0c1030'))
            for j in range(4):
                if rnd.random() < 0.6:
                    cv.drawRect(skia.Rect.MakeXYWH(bx + 10 + (j % 2) * 26, y + h - bh + 12 + (j // 2) * 40, 12, 14),
                                PF('#ffd95a'))
    else:
        cv.drawRect(skia.Rect.MakeXYWH(x + 10, y + h * 0.62, w - 20, h * 0.38 - 8), PF('#a9d2f2'))
    line(cv, x + w / 2, y, x + w / 2, y + h, '#2d3f6a', 10)
    cv.drawRoundRect(skia.Rect.MakeXYWH(x, y, w, h), 6, 6, PS('#2d3f6a', 14))


def bg_room(cv, t, p):
    cv.drawRect(skia.Rect.MakeLTRB(0, 0, W, FY), PF('#e9dfb5'))
    for i in range(0, W, 120):
        cv.drawRect(skia.Rect.MakeXYWH(i, 0, 60, FY), PF('#dfd3a3'))
    _window(cv, 410, 130, 260, 600, p.get('night'))
    _floor(cv, '#9a6a3f', '#7d5230')
    orr(cv, -60, 1020, 400, 230, 50, '#a34a55')
    orr(cv, -30, 970, 330, 120, 40, '#b5596a')
    orr(cv, 190, 1040, 80, 34, 8, '#f2d45a', 6)
    line(cv, 372, 880, 372, 1240, OL, 10)
    opath(cv, poly([(330, 760), (414, 760), (440, 880), (304, 880)]), '#f3ecd2')
    orr(cv, 800, 600, 330, 640, 8, '#8a5a34')
    for yy in (640, 950):
        orr(cv, 840, yy, 250, 260, 6, '#7a4c2a', 6)
    cv.drawCircle(826, 930, 9, PF('#f2d45a'))


def bg_night_room(cv, t, p):
    cv.drawRect(skia.Rect.MakeLTRB(0, 0, W, FY), PF('#3f4280'))
    _window(cv, 600, 120, 250, 560, True)
    cv.drawRect(skia.Rect.MakeLTRB(0, FY, W, H), PF('#4d4a70'))
    line(cv, 0, FY, W, FY, OL, 8)
    orr(cv, 60, 760, 60, 480, 6, '#6b4630')
    orr(cv, 60, 1010, 560, 230, 10, '#6b4630')
    orr(cv, 120, 950, 480, 120, 30, '#8f96c9')
    orr(cv, 130, 900, 190, 110, 36, '#e3e6f5')
    orr(cv, 800, 1020, 220, 220, 8, '#5a3a28')
    orr(cv, 830, 930, 160, 90, 8, '#1a1a22')
    f = font(TF_BLACK, 52)
    otext(cv, p.get('clock', '3:00'), 910, 994, f, '#ff3b30', 0)


def bg_hall(cv, t, p):
    cv.drawRect(skia.Rect.MakeLTRB(0, 0, W, FY), PF('#8e9c84'))
    cv.drawRect(skia.Rect.MakeLTRB(0, 0, W, 420), PF('#9dab92'))
    line(cv, 0, 420, W, 420, '#7c8a73', 8)
    cv.drawRect(skia.Rect.MakeLTRB(0, FY, W, H), PF('#6f6a62'))
    line(cv, 0, FY, W, FY, OL, 8)
    orr(cv, 360, 470, 360, 770, 6, '#3b2a1c')
    if p.get('open'):
        cv.drawRect(skia.Rect.MakeXYWH(380, 490, 320, 750), PF('#0c0c12'))
        opath(cv, poly([(380, 490), (300, 450), (300, 1290), (380, 1240)]), '#7a5232')
    else:
        orr(cv, 380, 490, 320, 750, 4, '#7a5232', 6)
        orr(cv, 420, 540, 240, 300, 6, '#6b4628', 5)
        orr(cv, 420, 880, 240, 300, 6, '#6b4628', 5)
        cv.drawCircle(540, 700, 12, PF('#d9d2b8'))
        cv.drawCircle(540, 700, 12, PS(OL, 5))
        cv.drawCircle(670, 880, 13, PF('#f2d45a'))
        cv.drawCircle(670, 880, 13, PS(OL, 5))
    if p.get('num'):
        orr(cv, 480, 380, 120, 64, 10, '#f3ecd2', 6)
        label(cv, p['num'], 540, 412, 40)
    if p.get('sign'):
        orr(cv, 290, 220, 500, 110, 14, '#22252e', 8)
        label(cv, p['sign'], 540, 275, 62, '#ff4a3d', 1, 450)
    orr(cv, 440, 1230, 200, 26, 6, '#5a4a3a', 6)


def bg_kitchen(cv, t, p):
    cv.drawRect(skia.Rect.MakeLTRB(0, 0, W, FY), PF('#f1e3b0'))
    for y in range(520, 1000, 80):
        line(cv, 0, y, 700, y, '#e2d39a', 4)
    for x in range(0, 700, 80):
        line(cv, x, 520, x, 980, '#e2d39a', 4)
    _window(cv, 120, 130, 300, 340, p.get('night'))
    _floor(cv, '#b9a68c', '#a08e76')
    orr(cv, -20, 980, 480, 270, 8, '#c98f4e')
    orr(cv, -20, 950, 500, 44, 8, '#e8dcc6')
    orr(cv, 60, 1040, 150, 170, 8, '#b57c3e', 6)
    orr(cv, 250, 1040, 150, 170, 8, '#b57c3e', 6)
    orr(cv, 200, 880, 150, 74, 14, '#c9ccd4')
    line(cv, 170, 900, 200, 900, OL, 12)
    orr(cv, 690, 380, 330, 870, 26, '#f4f6f8')
    if p.get('open'):
        orr(cv, 712, 404, 286, 480, 12, '#fff3b0', 6)
        for yy in (540, 680, 800):
            line(cv, 716, yy, 994, yy, '#b9c2cc', 8)
        for i, c in enumerate(('#e2574c', '#6cc46a', '#f2c94c', '#8fd3ff')):
            orr(cv, 730 + (i % 2) * 130, 470 + (i // 2) * 140, 90, 66, 12, c, 5)
        opath(cv, poly([(1020, 380), (1100, 340), (1100, 950), (1020, 900)]), '#dfe4ea')
    else:
        line(cv, 730, 470, 730, 760, OL, 14)
    line(cv, 694, 900, 1016, 900, OL, 8)
    line(cv, 730, 950, 730, 1100, OL, 14)


def bg_elevator(cv, t, p):
    cv.drawRect(skia.Rect.MakeLTRB(0, 0, W, FY), PF('#b9bec7'))
    for x in (130, 950):
        line(cv, x, 0, x, FY, '#a3a9b4', 8)
    cv.drawRect(skia.Rect.MakeLTRB(0, FY, W, H), PF('#5a5f6a'))
    line(cv, 0, FY, W, FY, OL, 8)
    orr(cv, 250, 400, 520, 840, 4, p.get('behind', '#0c0c12'))
    g = 190 * p.get('open', 0)
    for sx in (-1, 1):
        x0 = 510 + sx * g if sx > 0 else 250 - g
        cv.save()
        cv.clipRect(skia.Rect.MakeXYWH(250, 400, 520, 840))
        orr(cv, x0, 400, 260, 840, 0, '#9aa1ad', 6)
        orr(cv, x0 + 40, 470, 180, 700, 4, '#a8aeb9', 4)
        cv.restore()
    cv.drawRect(skia.Rect.MakeXYWH(250, 400, 520, 840), PS(OL, 10))
    orr(cv, 420, 270, 180, 96, 12, '#15161c')
    label(cv, str(p.get('floor', '5')), 510, 318, 62, '#ff3b30')
    orr(cv, 850, 620, 150, 400, 14, '#8d939e')
    n = p.get('n', 9)
    for i in range(n):
        cx, cy = 890 + (i % 2) * 70, 960 - (i // 2) * 64
        hot = (i == n - 1 and p.get('hot'))
        cv.drawCircle(cx, cy, 22, PF('#ff5a3d' if hot else '#e7e9ee'))
        cv.drawCircle(cx, cy, 22, PS(OL, 5))


def bg_klass(cv, t, p):
    cv.drawRect(skia.Rect.MakeLTRB(0, 0, W, FY), PF('#cfe3c4'))
    cv.drawRect(skia.Rect.MakeLTRB(0, 900, W, FY), PF('#b9d3ad'))
    _floor(cv, '#b08a5a', '#96744a')
    orr(cv, 110, 300, 860, 500, 8, '#8a5a34')
    orr(cv, 136, 326, 808, 448, 4, '#2f5d46', 6)
    f = font(TF_BOLD, 40)
    otext(cv, p.get('board', 'КОНТРОЛЬНАЯ'), 900, 750, f, '#b9d3c4', 0, 'r')
    orr(cv, 700, 780, 110, 26, 6, '#f4f4f4', 5)


def bg_shop(cv, t, p):
    cv.drawRect(skia.Rect.MakeLTRB(0, 0, W, FY), PF('#e6eef5'))
    rnd = random.Random(p.get('seed', 3))
    cols = ('#e2574c', '#f2c94c', '#6cc46a', '#5aa9e6', '#b57edc', '#f58a3c', '#f4f4f4')
    orr(cv, 240, 40, 600, 100, 16, '#e2574c')
    label(cv, 'ПРОДУКТЫ', 540, 90, 60, '#ffffff')
    for row in range(3):
        y = 555 + row * 225
        x = 20
        while x < W - 40:
            w = rnd.choice((60, 80, 100))
            h = rnd.choice((110, 140, 170))
            orr(cv, x, y + 190 - h, w, h, 8, rnd.choice(cols), 6)
            x += w + 12
        orr(cv, -10, y + 190, W + 20, 30, 4, '#c9a36b', 7)
    cv.drawRect(skia.Rect.MakeLTRB(0, FY, W, H), PF('#dfe3e8'))
    for i in range(-3, 13):
        line(cv, i * 120, FY, 540 + (i * 120 - 540) * 2.1, H, '#c5ccd5', 5)
    for y in (1380, 1600):
        line(cv, 0, y, W, y, '#c5ccd5', 5)
    line(cv, 0, FY, W, FY, OL, 8)


def bg_train(cv, t, p):
    night = p.get('night')
    cv.drawRect(skia.Rect.MakeLTRB(0, 0, W, FY), PF('#d9c7a3'))
    x, y, w, h = 290, 360, 500, 520
    cv.save()
    cv.clipRect(skia.Rect.MakeXYWH(x, y, w, h))
    cv.drawRect(skia.Rect.MakeXYWH(x, y, w, h), PF('#141a3d' if night else '#9fd0f5'))
    if night:
        cv.drawCircle(x + 380, y + 110, 34, PF('#e8e2c8'))
    for layer, (col, sp, amp, base) in enumerate((('#7fb56b', 180, 60, 330), ('#5c9a52', 420, 40, 400))):
        pth = skia.Path()
        pth.moveTo(x, y + h)
        for i in range(0, w + 21, 20):
            pth.lineTo(x + i, y + base + amp * math.sin((i + t * sp) * 0.012 + layer * 2))
        pth.lineTo(x + w, y + h)
        pth.close()
        cv.drawPath(pth, PF(mix(col, '#0c1030', 0.7) if night else col))
    px = x + w - ((t * 620) % (w + 300))
    line(cv, px, y + 120, px, y + h, '#5a4a3a', 12)
    cv.restore()
    cv.drawRoundRect(skia.Rect.MakeXYWH(x, y, w, h), 20, 20, PS(OL, 12))
    for sx in (x - 10, x + w - 60):
        orr(cv, sx, y - 20, 70, h * 0.7, 10, '#c0524f', 6)
    orr(cv, 400, 960, 280, 30, 8, '#b98a5a')
    line(cv, 540, 990, 540, 1240, OL, 14)
    orr(cv, 560, 890, 54, 70, 8, '#c98f4e', 6)
    for sx in (0, 1):
        x0 = -40 if sx == 0 else 800
        orr(cv, x0, 500, 320, 70, 14, '#8a3b3b')
        orr(cv, x0, 1060, 320, 190, 18, '#8a3b3b')
        orr(cv, x0, 1030, 320, 60, 18, '#a34a4a')
    cv.drawRect(skia.Rect.MakeLTRB(0, FY, W, H), PF('#7a6a5a'))
    line(cv, 0, FY, W, FY, OL, 8)


def bg_facade(cv, t, p):
    cv.drawRect(skia.Rect.MakeLTRB(0, 0, W, H), PF('#0d1030'))
    rnd = random.Random(5)
    for i in range(60):
        cv.drawCircle(rnd.random() * W, rnd.random() * 300, 2 + rnd.random() * 2,
                      PF('#ffffff', 120 + 100 * math.sin(t * 2 + i)))
    cv.drawRect(skia.Rect.MakeLTRB(0, 300, W, H), PF('#23263d'))
    line(cv, 0, 300, W, 300, OL, 8)
    lit = p.get('lit', [])
    for c in range(4):
        for r in range(6):
            x, y = 60 + c * 260, 400 + r * 250
            on = (c, r) in lit or [c, r] in lit
            if on:
                sh = skia.Paint(AntiAlias=True)
                sh.setShader(skia.GradientShader.MakeRadial(center=(x + 90, y + 95), radius=240,
                                                            colors=[C('#ffd95a', 110), C('#ffd95a', 0)]))
                cv.drawCircle(x + 90, y + 95, 240, sh)
            orr(cv, x, y, 180, 190, 4, '#ffd95a' if on else '#161829', 6)
            if on:
                line(cv, x + 90, y, x + 90, y + 190, OL, 5)


def bg_grad(cv, t, p):
    sh = skia.Paint(AntiAlias=True)
    sh.setShader(skia.GradientShader.MakeRadial(center=(540, p.get('cy', 1100)), radius=1200,
                                                colors=[C(p.get('c1', '#fff3b0')), C(p.get('c2', '#d9b64a'))]))
    cv.drawPaint(sh)


def bg_black(cv, t, p):
    cv.drawColor(C('#050508'))


BGS = dict(room=bg_room, night_room=bg_night_room, hall=bg_hall, kitchen=bg_kitchen, elevator=bg_elevator,
           klass=bg_klass, shop=bg_shop, train=bg_train, facade=bg_facade, grad=bg_grad, black=bg_black)


# ---------- props ----------
def draw_prop(cv, p, t):
    k = clamp((t - p.get('show_t', -9)) / 0.25)
    if k <= 0:
        return
    cv.save()
    cv.translate(p['x'], p['y'])
    s = p.get('s', 1) * back(k)
    cv.scale(s, s)
    cv.rotate(p.get('rot', 0) + (math.sin(t * 30) * 4 if p.get('wiggle') else 0))
    kind = p['kind']
    if kind == 'box':
        f = font(TF_BLACK, 40)
        w = p.get('w', max(180, f.measureText(p['label']) + 60))
        h = p.get('h', 90)
        orr(cv, -w / 2, -h, w, h, 10, p.get('col', '#c9a36b'))
        label(cv, p['label'], 0, -h / 2, max(40, h * 0.3), p.get('tcol', '#b02a1e'), 1, w - 30)
    elif kind in ('plate', 'stack'):
        items = p['items'] if kind == 'stack' else [(p['label'], p.get('col', '#8a4a2a'))]
        for i, (txt, col) in enumerate(items):
            y = -i * 74
            dx = math.sin(i * 1.7 + t * 2) * 8 * min(i, 3)
            oval(cv, dx, y - 30, 150, 44, '#f4f4f4')
            oval(cv, dx, y - 40, 118, 30, col, 6)
            label(cv, txt, dx, y - 40, 30, '#ffffff', 1, 200)
    elif kind == 'note':
        f = font(TF_BOLD, p.get('size', 54))
        lines = p['text'].split('|')
        w = max(f.measureText(l) for l in lines) + 90
        h = len(lines) * f.getSize() * 1.3 + 80
        orr(cv, -w / 2, -h / 2, w, h, 8, p.get('col', '#fff8d6'))
        orr(cv, -40, -h / 2 - 22, 80, 40, 6, '#e2574c', 6)
        for i, l in enumerate(lines):
            otext(cv, l, 0, -h / 2 + 50 + (i + 0.8) * f.getSize() * 1.3, f, p.get('tcol', '#2a2a3a'), 0)
    elif kind == 'panel':
        n = p.get('n', 9)
        rows = (n + 1) // 2
        hh = rows * 130 + 110
        orr(cv, -190, -hh / 2, 380, hh, 30, '#8d939e')
        f = font(TF_BLACK, 54)
        for i in range(n):
            cx, cy = -85 + (i % 2) * 170, hh / 2 - 110 - (i // 2) * 130
            hot = i >= p.get('base', 9)
            pulse = 1 + (0.08 * math.sin(t * 9) if hot else 0)
            if hot:
                cv.drawCircle(cx, cy, 78 * pulse, PF('#ff3b30', 70))
            ocirc(cv, cx, cy, 52 * pulse, '#ff5a3d' if hot else '#e7e9ee')
            otext(cv, str(i + 1), cx, cy + 19, f, '#ffffff' if hot else '#33353f', 0)
    elif kind == 'cart':
        items = p.get('items', [])
        for i, (txt, col) in enumerate(items):
            f = font(TF_BLACK, 30)
            w = max(120, f.measureText(txt) + 36)
            x = -110 + (i % 2) * 150 + (i // 2 % 2) * 30
            y = -250 - (i // 2) * 76
            orr(cv, x - w / 2 + 40, y - 70, w, 70, 8, col, 6)
            label(cv, txt, x + 40, y - 35, 30, '#ffffff', 1)
        opath(cv, poly([(-190, -250), (190, -250), (150, -70), (-150, -70)]), '#c9ccd4')
        for i in range(-3, 4):
            line(cv, i * 50, -246, i * 40, -74, '#8d939e', 5)
        line(cv, -170, -160, 170, -160, '#8d939e', 5)
        line(cv, 190, -250, 250, -300, OL, 12)
        for sx in (-110, 110):
            ocirc(cv, sx, -30, 26, '#33353f')
    elif kind == 'feet':
        for i, sx in enumerate((-50, 50)):
            sw = math.sin(t * 16 + i * 2) * 26 if p.get('wave') else math.sin(t * 2 + i) * 4
            line(cv, sx, -200, sx + sw, 60, OL, 62)
            line(cv, sx, -200, sx + sw, 60, '#f1c9a5', 46)
            oval(cv, sx + sw, 90, 44, 58, p.get('col', '#e2574c'))
            line(cv, sx + sw - 30, 70, sx + sw + 30, 70, '#ffffff', 8)
    elif kind == 'sign':
        f = font(TF_BLACK, p.get('size', 60))
        lines = p['text'].split('|')
        w = max(f.measureText(l) for l in lines) + 90
        h = len(lines) * f.getSize() * 1.25 + 60
        orr(cv, -w / 2, -h / 2, w, h, 16, p.get('col', '#ffffff'), 10)
        cv.drawRoundRect(skia.Rect.MakeXYWH(-w / 2 + 14, -h / 2 + 14, w - 28, h - 28), 8, 8,
                         PS(p.get('tcol', '#d62b1e'), 6))
        for i, l in enumerate(lines):
            otext(cv, l, 0, -h / 2 + 30 + (i + 0.82) * f.getSize() * 1.25, f, p.get('tcol', '#d62b1e'), 0)
    elif kind == 'text':
        f = font(TF_BLACK, p.get('size', 90))
        for i, l in enumerate(p['text'].split('|')):
            otext(cv, l, 0, i * p.get('size', 90) * 1.15, f, p.get('col', '#ffffff'), 16)
    cv.restore()


# ---------- chat ----------
CHAT_FONT = font(TF_MED, 42)
SENDER_COL = ['#ff8fb1', '#6cc4ff', '#ffd23f', '#8ee88a', '#c79bff']


def _msg_layout(m):
    kind = m['side']
    if kind == 'sys':
        return 70, 0, []
    if m.get('deleted'):
        lines = ['Сообщение удалено']
    elif kind == 'voice':
        lines = ['']
    elif kind == 'stickers':
        return 172, 860, []
    else:
        lines = wrap(m['text'], CHAT_FONT, 620)
    w = max([CHAT_FONT.measureText(l) for l in lines] + [330 if kind == 'voice' else 60]) + 56
    if m.get('sender'):
        w = max(w, font(TF_BOLD, 30).measureText(m['sender']) + 56)
    h = len(lines) * 54 + 40 + (40 if m.get('sender') else 0)
    return h + 18, w, lines


def draw_chat(cv, chat, msgs, typing, t):
    X, Y, Wd, Hh = 50, 790, 980, 1010
    orr(cv, X, Y, Wd, Hh, 40, '#14161c', 10)
    cv.save()
    cp = skia.Path()
    cp.addRoundRect(skia.Rect.MakeXYWH(X + 5, Y + 5, Wd - 10, Hh - 10), 36, 36)
    cv.clipPath(cp, True)
    cv.drawRect(skia.Rect.MakeXYWH(X, Y, Wd, 124), PF('#232733'))
    cv.drawCircle(X + 76, Y + 62, 38, PF(chat.get('col', '#5b6070')))
    otext(cv, chat.get('letter', '?'), X + 76, Y + 78, font(TF_BOLD, 44), '#ffffff', 0)
    otext(cv, chat['title'], X + 134, Y + 58, font(TF_BOLD, 40), '#ffffff', 0, 'l')
    sub = typing if isinstance(typing, str) else chat.get('sub', '')
    otext(cv, sub, X + 134, Y + 98, font(TF_MED, 27), '#6cc4ff' if isinstance(typing, str) else '#8a90a0', 0, 'l')
    top, avail = Y + 150, Hh - 180
    cv.clipRect(skia.Rect.MakeXYWH(X, Y + 126, Wd, Hh - 126))
    lay = [(m,) + _msg_layout(m) for m in msgs if t >= m['t0']]
    total = 0
    for m, h, w, lines in lay:
        total += h * ease((t - m['t0']) / 0.2)
    if typing:
        total += 100
    y = top + min(0, avail - total)
    for m, h, w, lines in lay:
        k = ease((t - m['t0']) / 0.2)
        side = m['side']
        if side == 'sys':
            otext(cv, m['text'], 540, y + 46, font(TF_BOLD, 34), '#d5d9e6', 0, 'c', 255 * k)
            y += h * k
            continue
        out = side in ('out', 'voice')
        bx = X + Wd - 34 - w if out else X + 34
        cv.save()
        cv.translate(bx + (w if out else 0), y + h - 18)
        cv.scale(0.6 + 0.4 * back(k), 0.6 + 0.4 * back(k))
        cv.translate(-(bx + (w if out else 0)), -(y + h - 18))
        if side == 'stickers':
            for si in range(5):
                sk = back((t - m['t0'] - si * 0.06) / 0.2)
                if sk <= 0:
                    continue
                cv.save()
                cv.translate(bx + 80 + si * 172, y + 76)
                cv.scale(sk, sk)
                cv.rotate(math.sin(t * 5 + si + m['t0'] * 9) * 8)
                orr(cv, -70, -66, 140, 132, 30, ('#ffd23f', '#ff8fb1', '#8ee88a', '#6cc4ff', '#c79bff')[(si + m['n']) % 5], 6)
                cv.drawCircle(-22, -14, 9, PF(OL))
                cv.drawCircle(22, -14, 9, PF(OL))
                cv.drawArc(skia.Rect.MakeLTRB(-32, -16, 32, 38), 20, 140, False, PS(OL, 7))
                cv.restore()
        else:
            orr(cv, bx, y, w, h - 18, 28, '#2f7df6' if out else '#2f3441', 0)
            ty = y + 50
            if m.get('sender'):
                col = SENDER_COL[sum(map(ord, m['sender'])) % len(SENDER_COL)]
                otext(cv, m['sender'], bx + 28, y + 42, font(TF_BOLD, 30), col, 0, 'l')
                ty += 40
            if side == 'voice' and not m.get('deleted'):
                opath(cv, poly([(bx + 30, y + 26), (bx + 30, y + 70), (bx + 66, y + 48)]), '#ffffff', 0)
                rnd = random.Random(4)
                for i in range(14):
                    hh = 8 + rnd.random() * 34
                    line(cv, bx + 92 + i * 15, y + 48 - hh / 2, bx + 92 + i * 15, y + 48 + hh / 2, '#ffffff', 6)
                otext(cv, '0:07', bx + w - 28, y + 62, font(TF_MED, 30), '#dbe7ff', 0, 'r')
            for i, l in enumerate(lines):
                otext(cv, l, bx + 28, ty + i * 54, CHAT_FONT, '#9aa0b0' if m.get('deleted') else '#ffffff', 0, 'l')
        cv.restore()
        y += h * k
    if typing:
        orr(cv, X + 34, y, 150, 76, 28, '#2f3441', 0)
        for i in range(3):
            cv.drawCircle(X + 78 + i * 32, y + 38 - 8 * max(0, math.sin(t * 8 - i * 0.9)), 9, PF('#c5cad8'))
    cv.restore()


# ---------- text overlays ----------
RED, YEL = '#ff3b30', '#ffe14d'


def parse(text):
    """'*red*' and '_yellow_' markup -> [(word, colorkey)]"""
    out, cur, mode, wcol = [], '', None, None
    for ch in text + ' ':
        if ch in '*_':
            mode = None if mode else ('r' if ch == '*' else 'y')
        elif ch == ' ':
            if cur:
                out.append((cur, wcol))
            cur, wcol = '', None
        else:
            cur += ch
            wcol = wcol or mode
    merged = []
    for w, c in out:
        if w in ('—', '-') and merged:
            merged[-1] = (merged[-1][0] + ' ' + w, merged[-1][1])
        else:
            merged.append((w, c))
    return merged


def plain(text):
    return text.replace('*', '').replace('_', '')


def draw_words(cv, words, y, f, base, maxw, t=None, t0=0, step=0.1, ow=14, lh=1.18):
    """centered, wrapped, per-word colored text; words pop in one by one when t is given"""
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
    for li, (ln, lw) in enumerate(lines):
        x = 540 - lw / 2
        yy = y + li * f.getSize() * lh
        for i, w, c, ww in ln:
            k = 1 if t is None else clamp((t - t0 - i * step) / 0.09)
            if k > 0:
                col = RED if c == 'r' else YEL if c == 'y' else base
                cv.save()
                cv.translate(x + ww / 2, yy - f.getSize() * 0.35)
                s = 0.7 + 0.3 * back(k)
                cv.scale(s, s)
                otext(cv, w, 0, f.getSize() * 0.35, f, col, ow)
                cv.restore()
            x += ww + sp
    return len(lines)


def draw_hook(cv, lines, t, t1):
    f = font(TF_BLACK, 70)
    parsed = [parse(l) for l in lines]
    wmax = max(f.measureText(' '.join(w.upper() for w, _ in p)) for p in parsed)
    if wmax > 920:
        f = font(TF_BLACK, 70 * 920 / wmax)
        wmax = 920
    lh = f.getSize() * 1.22
    h = lh * len(lines) + 56
    k = clamp((t1 - t) / 0.18)
    s = (1 + 0.1 * (1 - ease(t / 0.3))) * (0.7 + 0.3 * k) + 0.012 * math.sin(t * 6)
    cv.save()
    cv.translate(540, 470)
    cv.scale(s, s)
    cv.translate(-540, -470)
    orr(cv, 540 - wmax / 2 - 44, 470 - h / 2, wmax + 88, h, 26, '#000000', 0, 165 * k)
    for i, p in enumerate(parsed):
        draw_words(cv, p, 470 - h / 2 + 28 + lh * (i + 0.76), f, YEL if i == 0 else '#ffffff', 2000, ow=10)
    cv.restore()


def draw_rule(cv, rule, t, t0):
    n, txt = rule
    k = clamp((t - t0) / 0.3)
    f = font(TF_BLACK, 62)
    s = 'ПРАВИЛО №%d' % n
    w = f.measureText(s) + 60
    cv.save()
    cv.translate(540, 262)
    cv.rotate(-3)
    cv.scale(back(k), back(k))
    orr(cv, -w / 2, -52, w, 100, 14, '#ffd23f', 9)
    otext(cv, s, 0, 20, f, '#111111', 0)
    cv.restore()
    k2 = clamp((t - t0 - 0.15) / 0.25)
    if k2 > 0:
        size = 58
        while size > 44 and len(wrap(txt.upper(), font(TF_BLACK, size), 960)) > 3:
            size -= 4
        f2 = font(TF_BLACK, size)
        cv.save()
        cv.translate(540, 380)
        cv.scale(0.8 + 0.2 * back(k2), 0.8 + 0.2 * back(k2))
        cv.translate(-540, -380)
        draw_words(cv, [(w, None) for w in txt.split()], 394, f2, '#ffffff', 960, ow=12, lh=1.16)
        cv.restore()


SPEAK = {  # code: (script name, subtitle color)
    'N': ('РАССКАЗЧИК', '#ffffff'), 'G': ('ГОША', '#8dff7a'), 'M': ('МАМА', '#ffb066'),
    'MA': ('МАША', '#7df0d6'), 'B': ('БАБУШКА', '#ffe14d'), 'X': ('МОНСТР', '#d1a8ff'),
    'P': ('ПАПА', '#7fc0ff'), 'T': ('УЧИТЕЛЬНИЦА', '#ff9dbb'), 'V': ('ВОВА', '#7fe3ff'),
    'K': ('КУРЬЕР', '#ffd23f'), 'C': ('КОТ', '#ffb35a'), 'Q': ('НЕИЗВЕСТНЫЙ', '#ff6b61'),
    'A': ('ТЁТЯ ВАЛЯ', '#ff9dd0'), 'S': ('КАССИР', '#ff8a80'), 'VO': ('ГОЛОС С КУХНИ', '#ffb066'),
    'U': ('???', '#ff6b61'),
}
SUB_Y = 668
SUB_FONT = font(TF_BLACK, 64)


# ---------- timeline ----------
def B(sp, text='', d=None, **ch):
    return dict(sp=sp, text=text, d=d, ch=ch)


def A(kind, x=540, **kw):
    a = dict(kind=kind, x=x, y=GY, s=1.5, expr='smile', pose='idle', show=True)
    a.update(kw)
    return a


def Pr(kind, x=540, y=GY, **kw):
    p = dict(kind=kind, x=x, y=y, show=True, z=1)
    p.update(kw)
    return p


GAP, PAD = 0.12, 0.22
SPECIAL = ('sfx', 'fx', 'big', 'dark', 'cam', 'bgp', 'msg', 'typing', 'hook', 'delmsg', 'bigcol')


def chunk(words):
    out, cur = [], []
    for w in words:
        cur.append(w)
        n = sum(len(x[0]) + 1 for x in cur)
        if len(cur) >= 4 or n >= 26 or (w[0][-1] in '.!?…»:' and len(cur) >= 2 and n >= 12):
            out.append(cur)
            cur = []
    if cur:
        if out and len(cur) == 1 and len(out[-1]) <= 4:
            out[-1] += cur
        else:
            out.append(cur)
    return out


class Timeline:
    def __init__(self, story):
        self.story = story
        self.beats, self.events, self.moods, self.subs, self.script = [], [], [], [], []
        T, last_rule, rule_t, chatlogs = 0.0, None, 0, {}
        self.events.append((0.0, 'boom', 0.8))
        for si, sc in enumerate(story['scenes']):
            actors = {k: dict(v, show_t=-9 if v.get('show', True) else 1e9) for k, v in sc.get('actors', {}).items()}
            props = {k: dict(v, show_t=-9 if v.get('show', True) else 1e9) for k, v in sc.get('props', {}).items()}
            st = dict(bgp=dict(sc.get('bgp', {})), dark=sc.get('dark', 0), cam=sc.get('cam', (1, 540, 960)),
                      typing=False)
            chat = sc.get('chat')
            log = chatlogs.setdefault(chat['title'], []) if chat else None
            rule = sc.get('rule')
            if rule and rule[0] != last_rule:
                rule_t, last_rule = T, rule[0]
                self.events.append((T, 'ding', 0.5))
                self.script.append(('rule', 'ПРАВИЛО №%d — %s' % (rule[0], plain(rule[1]))))
            if si:
                self.events.append((max(0, T - 0.1), 'whoosh', 0.45))
            s0 = T
            for bi, b in enumerate(sc['beats']):
                ch = b['ch']
                for key, val in ch.items():
                    if key in SPECIAL:
                        continue
                    tgt = actors.get(key) or props[key]
                    was = tgt.get('show', True)
                    tgt.update(val)
                    if tgt.get('show', True) and not was:
                        tgt['show_t'] = T
                    elif not tgt.get('show', True):
                        tgt['show_t'] = 1e9
                if 'bgp' in ch:
                    st['bgp'] = dict(st['bgp'], **ch['bgp'])
                for key in ('dark', 'cam', 'typing'):
                    if key in ch:
                        st[key] = ch[key]
                if 'delmsg' in ch:
                    log[ch['delmsg']] = dict(log[ch['delmsg']], deleted=True)
                if 'msg' in ch:
                    ms = ch['msg'] if isinstance(ch['msg'], list) else [ch['msg']]
                    for mi, m in enumerate(ms):
                        d = dict(side=m[0], text=m[1] if len(m) > 1 else '', sender=m[2] if len(m) > 2 else None,
                                 t0=T + mi * 0.16)
                        d['n'] = len(log)
                        log.append(d)
                        if mi < 6:
                            self.events.append((d['t0'], 'msg' if m[0] not in ('out', 'voice') else 'pop', 0.5))
                    st['typing'] = ch.get('typing', False)
                words = parse(b['text'])
                hook = ch.get('hook')
                dur = b['d'] or (3.9 if hook else max(1.25, 0.5 + 0.36 * len(words)))
                chunks = []
                if words and not hook:
                    cs = chunk(words)
                    tot = sum(len(c) for c in cs)
                    ct = T
                    for c in cs:
                        cd = (dur - 0.05) * len(c) / tot
                        chunks.append((ct, ct + cd, c))
                        self.subs.append((ct, ct + cd - 0.03, ' '.join(w for w, _ in c)))
                        self.events.append((ct, 'tick', 0.22))
                        ct += cd
                if b['text']:
                    self.script.append((T, SPEAK[b['sp']][0], plain(b['text'])))
                for s in ([ch['sfx']] if isinstance(ch.get('sfx'), str) else ch.get('sfx', [])):
                    nm, _, off = s.partition('@')
                    self.events.append((T + (float(off) if off else 0), nm, 0.8))
                fx = [ch['fx']] if isinstance(ch.get('fx'), str) else list(ch.get('fx', []))
                self.beats.append(dict(
                    t0=T, t1=T + dur, si=si, s0=s0, sp=b['sp'], chunks=chunks, hook=hook, fx=fx,
                    big=ch.get('big'), bigcol=ch.get('bigcol', '#ffffff'), rule=rule, rule_t=rule_t,
                    actors=copy.deepcopy(actors), props=copy.deepcopy(props), msgs=list(log) if chat else None,
                    chat=chat, bg=sc['bg'], **copy.deepcopy(st)))
                T += dur + GAP
            self.moods.append((s0, T, sc.get('mood', story.get('mood', 'comedy'))))
            T += PAD
        self.total = T + 0.5
        self.starts = [b['t0'] for b in self.beats]
        self.surface = skia.Surface(W, H)

    def frame(self, t, subs=False):
        """draws frame; returns surface. Call with subs=True right after subs=False to add subtitles on top."""
        cv = self.surface.getCanvas()
        i = max(0, bisect.bisect_right(self.starts, t) - 1)
        b = self.beats[i]
        if subs:
            for c0, c1, words in b['chunks']:
                if c0 <= t < c1:
                    step = min(0.13, 0.45 * (c1 - c0) / len(words))
                    draw_words(cv, words, SUB_Y, SUB_FONT, SPEAK[b['sp']][1], 960, t, c0, step)
            return self.surface
        prev = self.beats[i - 1] if i and self.beats[i - 1]['si'] == b['si'] else None
        bt = t - b['t0']
        kk = ease(bt / 0.3)
        tw = (lambda cur, old: old + (cur - old) * kk) if prev else (lambda cur, old: cur)
        cam = b['cam']
        pc = prev['cam'] if prev else cam
        z, cx, cy = (tw(cam[j], pc[j]) for j in range(3))
        z *= 1 + 0.03 * clamp((t - b['s0']) / 8) + 0.03 * (1 - ease(bt / 0.22))
        if 'zoom' in b['fx']:
            z *= 1 + 0.14 * (1 - ease(bt / 0.4))
        intro = b['si'] > 0 and (t - b['s0']) < 0.2
        if intro:
            z *= 1 + 0.1 * (1 - ease((t - b['s0']) / 0.2))
        shx = shy = 0
        if 'shake' in b['fx'] and bt < 0.5:
            amp = 26 * (1 - bt / 0.5)
            shx, shy = math.sin(t * 90) * amp, math.cos(t * 70) * amp
        if shx or shy:
            z *= 1.06
        cx = clamp(cx, 540 / z, W - 540 / z)
        cy = clamp(cy, 960 / z, H - 960 / z)
        cv.clear(C('#000000'))
        cv.save()
        cv.translate(540 + shx / 2, 960 + shy / 2)
        cv.scale(z, z)
        cv.translate(-cx, -cy)
        BGS[b['bg']](cv, t, b['bgp'])
        props = [p for p in b['props'].values() if p.get('show', True)]
        for p in props:
            if p.get('z', 1) < 0:
                draw_prop(cv, p, t)
        acts = []
        for name, a in b['actors'].items():
            if not a.get('show', True):
                continue
            a = dict(a)
            if prev and name in prev['actors'] and prev['actors'][name].get('show', True):
                o = prev['actors'][name]
                for key in ('x', 'y', 's'):
                    a[key] = tw(a[key], o[key])
                if abs(a['x'] - b['actors'][name]['x']) > 6:
                    a['walk'] = 1
            acts.append(a)
            draw_char(cv, a, t)
        for p in props:
            if p.get('z', 1) >= 0:
                draw_prop(cv, p, t)
        dark = tw(b['dark'], prev['dark']) if prev else b['dark']
        if dark > 0.01:
            cv.drawRect(skia.Rect.MakeLTRB(-600, -600, W + 600, H + 600), PF('#06061a', 235 * dark))
            if dark > 0.8:
                for a in acts:
                    draw_char(cv, a, t, True)
        cv.restore()
        if b['chat']:
            draw_chat(cv, b['chat'], b['msgs'], b['typing'], t)
        if intro:
            cv.drawColor(C('#ffffff', 110 * (1 - (t - b['s0']) / 0.2)))
        if 'flash' in b['fx'] and bt < 0.3:
            cv.drawColor(C('#ffffff', 200 * (1 - bt / 0.3)))
        if 'red' in b['fx']:
            cv.drawColor(C('#ff1a1a', 90 * max(0, 1 - bt / 0.9)))
        if b['big']:
            lines = b['big'].split('|')
            f = font(TF_BLACK, 150)
            mw = max(f.measureText(l) for l in lines)
            if mw > 960:
                f = font(TF_BLACK, 150 * 960 / mw)
            cv.save()
            cv.translate(540 + math.sin(t * 50) * 5, 1340)
            s = back(bt / 0.22)
            cv.scale(s, s)
            cv.rotate(-4)
            for li, l in enumerate(lines):
                otext(cv, l, 0, li * f.getSize() * 1.1, f, b['bigcol'], 22)
            cv.restore()
        if b['hook']:
            draw_hook(cv, self.story['hook'], bt, b['t1'] - b['t0'])
        elif b['rule']:
            draw_rule(cv, b['rule'], t, b['rule_t'])
        return self.surface


def avatar(path, size=1024):
    surf = skia.Surface(size, size)
    cv = surf.getCanvas()
    sh = skia.Paint(AntiAlias=True)
    sh.setShader(skia.GradientShader.MakeRadial(center=(size / 2, size * 0.55), radius=size * 0.75,
                                                colors=[C('#ffe873'), C('#ff9d2e')]))
    cv.drawPaint(sh)
    for i in range(12):
        cv.save()
        cv.translate(size / 2, size * 0.55)
        cv.rotate(i * 30)
        cv.drawPath(poly([(0, 0), (-70, -size), (70, -size)]), PF('#ffffff', 40))
        cv.restore()
    a = A('gosha', size / 2, y=size * 1.42, s=size / 1024 * 2.25, expr='shock', pose='cover', look=(0, -0.2))
    draw_char(cv, a, 1.0)
    surf.makeImageSnapshot().save(path, skia.kPNG)
