# Рисует пиксельные текстуры интерфейса «в стиле подвала»: ржавые железные плиты с заклёпками,
# картон, фанера, кнопки-пластины, клавиши. Каждая рисуется в маленьком разрешении и
# увеличивается в SCALE раз без сглаживания — получаются крупные «пиксели».
# Запуск: python tools/make_ui.py   (из папки game)
import os, random
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'ui')
SCALE = 3
os.makedirs(OUT, exist_ok=True)


def clamp(v):
    return max(0, min(255, int(v)))


def col(c, k=1.0, a=255):
    return (clamp(c[0] * k), clamp(c[1] * k), clamp(c[2] * k), a)


def save(im, name):
    im = im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)
    im.save(os.path.join(OUT, name))
    print(name, im.size)


def plate(w, h, base, rng, rust=0.12, bevel=1, rivets=True, edge_dark=0.45, alpha=255, speck=0.1):
    """Железная плита: шум, ржавые пятна, фаска, заклёпки по углам."""
    im = Image.new('RGBA', (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            k = 1.0 + rng.uniform(-speck, speck)
            c = col(base, k, alpha)
            px[x, y] = c
    # ржавые пятна
    for _ in range(int(w * h * rust / 6)):
        cx, cy = rng.randrange(w), rng.randrange(h)
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                if 0 <= cx + dx < w and 0 <= cy + dy < h and rng.random() < 0.6:
                    r = px[cx + dx, cy + dy]
                    px[cx + dx, cy + dy] = (clamp(r[0] * 0.7 + 70), clamp(r[1] * 0.7 + 32), clamp(r[2] * 0.6 + 10), alpha)
    # фаска: светлый верх/лево, тёмный низ/право, чёрная обводка
    for x in range(w):
        for y in range(h):
            r = px[x, y]
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                px[x, y] = col((10, 9, 8), 1.0, alpha)
            elif x <= bevel or y <= bevel:
                px[x, y] = col(r, 1.35, alpha)
            elif x >= w - 1 - bevel or y >= h - 1 - bevel:
                px[x, y] = col(r, edge_dark, alpha)
    if rivets:
        for (rx, ry) in [(3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)]:
            px[rx, ry] = col(base, 1.7, alpha)
            px[rx + 1, ry] = col(base, 1.1, alpha)
            px[rx, ry + 1] = col(base, 1.1, alpha)
            px[rx + 1, ry + 1] = col(base, 0.5, alpha)
    return im


def steel_panel(w, h, rng):
    """Большая панель: тёмная сталь с рамкой-швом и болтами. Ржавчина только по краям,
    середина ровная — при повторении (тайлинге) нет узора «обоями»."""
    base = (46, 45, 42)
    im = Image.new('RGBA', (w, h))
    px = im.load()
    for y in range(h):
        row = rng.uniform(-0.03, 0.03)          # горизонтальные «прокатные» полосы
        for x in range(w):
            px[x, y] = col(base, 1.0 + row + rng.uniform(-0.035, 0.035), 246)
    # рамка 7 px: светлая сталь, ржавые подтёки
    F = 7
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d < F:
                k = 1.25 + rng.uniform(-0.06, 0.06)
                c = col((66, 63, 57), k)
                if rng.random() < 0.10:
                    c = (clamp(120 + rng.randint(-15, 15)), clamp(64 + rng.randint(-10, 10)), 30, 255)
                px[x, y] = c
            if d == 0:
                px[x, y] = (10, 9, 8, 255)
            elif d == 1:
                px[x, y] = col(px[x, y], 1.3) if (x == 1 or y == 1) else col(px[x, y], 0.55)
            elif d == F - 1:
                px[x, y] = (18, 17, 15, 255)          # шов между рамкой и полем
            elif d == F:
                px[x, y] = col(base, 1.35, 246) if (x == F or y == F) else col(base, 0.6, 246)
    # болты в углах рамки
    for (rx, ry) in [(3, 3), (w - 5, 3), (3, h - 5), (w - 5, h - 5)]:
        px[rx, ry] = (190, 184, 170, 255)
        px[rx + 1, ry] = (120, 116, 108, 255)
        px[rx, ry + 1] = (120, 116, 108, 255)
        px[rx + 1, ry + 1] = (30, 28, 25, 255)
    return im


def btn(w, h, base, rng, top_glow=None, pressed=False):
    """Кнопка-пластина: ровная, с фаской и парой царапин, без ржавых точек."""
    im = Image.new('RGBA', (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = col(base, 1.0 + rng.uniform(-0.04, 0.04))
    for x in range(w):
        for y in range(h):
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                px[x, y] = (10, 9, 8, 255)
            elif x == 1 or y == 1:
                px[x, y] = col(base, 0.55 if pressed else 1.45)
            elif x == w - 2 or y == h - 2:
                px[x, y] = col(base, 1.25 if pressed else 0.5)
    if top_glow:
        for x in range(2, w - 2):
            px[x, 1] = top_glow
    return im


def main():
    rng = random.Random(7)
    # большая панель (диалоги, меню, мини-игры)
    save(steel_panel(64, 48, rng), 'panel_metal.png')
    save(btn(32, 12, (70, 67, 61), rng), 'btn_normal.png')
    save(btn(32, 12, (122, 88, 42), rng, top_glow=(255, 205, 120, 255)), 'btn_hover.png')
    save(btn(32, 12, (92, 66, 32), rng, pressed=True), 'btn_pressed.png')
    save(btn(32, 12, (40, 38, 35), rng), 'btn_disabled.png')
    # ячейка (строка мешка, карточка товара): утопленная тёмная
    s = Image.new('RGBA', (16, 12))
    sp = s.load()
    for y in range(12):
        for x in range(16):
            c = (24 + rng.randint(-3, 3), 22 + rng.randint(-3, 3), 19 + rng.randint(-3, 3), 235)
            if y == 0 or x == 0:
                c = (8, 7, 6, 255)
            elif y == 11 or x == 15:
                c = (70, 64, 56, 255)
            sp[x, y] = c
    save(s, 'slot.png')
    # ячейка отложенная: синеватая
    s2 = s.copy()
    sp = s2.load()
    for y in range(1, 11):
        for x in range(1, 15):
            r = sp[x, y]
            sp[x, y] = (r[0], clamp(r[1] + 8), clamp(r[2] + 26), 240)
    save(s2, 'slot_locked.png')
    # картон (мешок)
    cb = Image.new('RGBA', (24, 24))
    cp = cb.load()
    for y in range(24):
        for x in range(24):
            k = 1.0 + rng.uniform(-0.07, 0.07) + (0.06 if x % 3 == 0 else 0.0)
            cp[x, y] = col((124, 92, 58), k)
    for x in range(24):
        for y in range(24):
            if x == 0 or y == 0 or x == 23 or y == 23:
                cp[x, y] = (30, 20, 12, 255)
            elif y in (1, 2) or y in (21, 22):
                cp[x, y] = col(cp[x, y], 0.8)
    # скотч сверху
    for x in range(8, 16):
        for y in range(0, 5):
            cp[x, y] = (196, 180, 140, 230) if y > 0 else (60, 50, 30, 255)
    save(cb, 'panel_cardboard.png')
    # фанера (лавка Коляна): доски с гвоздями
    pw = Image.new('RGBA', (24, 24))
    pp = pw.load()
    for y in range(24):
        for x in range(24):
            grain = 0.08 * ((x * 7 + y * 3) % 5 == 0)
            k = 1.0 + rng.uniform(-0.06, 0.06) - grain
            pp[x, y] = col((112, 84, 52), k)
            if y % 8 == 0:
                pp[x, y] = col((112, 84, 52), 0.55)
    for x in range(24):
        for y in range(24):
            if x == 0 or y == 0 or x == 23 or y == 23:
                pp[x, y] = (24, 16, 9, 255)
    for (nx, ny) in [(3, 3), (20, 3), (3, 20), (20, 20)]:
        pp[nx, ny] = (170, 170, 175, 255)
        pp[nx + 1, ny + 1] = (50, 50, 55, 255)
    save(pw, 'panel_wood.png')
    # клавиша
    k = Image.new('RGBA', (10, 10), (0, 0, 0, 0))
    kp = k.load()
    for y in range(10):
        for x in range(10):
            if x in (0, 9) or y in (0, 9):
                c = (14, 12, 10, 255)
            elif y >= 7:
                c = (70, 66, 60, 255)      # «боковина» клавиши
            elif y == 1 or x == 1:
                c = (225, 218, 200, 255)
            else:
                c = (182, 176, 162, 255)
            kp[x, y] = c
    save(k, 'key.png')
    # табличка находки: латунная пластинка
    save(plate(20, 12, (96, 80, 46), rng, rust=0.06, bevel=1), 'tag_brass.png')
    # полоска мини-игры
    save(plate(12, 6, (26, 25, 22), rng, rust=0.0, bevel=0, rivets=False, speck=0.05), 'track.png')


main()
