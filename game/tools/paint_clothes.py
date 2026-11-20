# «Одевает» базового персонажа Quaternius: рисует одежду прямо в текстуру тела
# (куртка, штаны, сапоги, грязь), как это делают в low poly играх.
# Область одежды определяется по костям, к которым привязаны вершины.
# Запуск: python tools/paint_clothes.py   (из папки game)
import json, os, struct
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UBC = os.path.join(ROOT, 'assets', 'chars', 'ubc')
OUT = os.path.join(ROOT, 'assets', 'chars', 'skins')
os.makedirs(OUT, exist_ok=True)
RES = 1024

# Персонажи: цвета одежды (RGB), кожа, насколько грязный
OUTFITS = {
    'kolyan': {'jacket': (44, 62, 104), 'pants': (50, 50, 46), 'boots': (28, 24, 20), 'skin': 'Light', 'dirt': 0.55,
               'stripe': (150, 150, 140)},
    'buyer': {'jacket': (38, 30, 26), 'pants': (26, 26, 30), 'boots': (20, 18, 16), 'skin': 'Light', 'dirt': 0.25,
              'stripe': None},
    'suit': {'jacket': (22, 22, 26), 'pants': (20, 20, 24), 'boots': (12, 12, 12), 'skin': 'Light', 'dirt': 0.05,
             'stripe': None},
    'police': {'jacket': (58, 70, 92), 'pants': (40, 46, 60), 'boots': (14, 14, 14), 'skin': 'Light', 'dirt': 0.1,
               'stripe': (160, 40, 40)},
    'player': {'jacket': (60, 58, 40), 'pants': (44, 40, 34), 'boots': (26, 22, 18), 'skin': 'Light', 'dirt': 0.7,
               'stripe': None},
}

COMP = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
NCOMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}


def load_gltf(path):
    g = json.load(open(path, encoding='utf-8'))
    bin_data = open(os.path.join(os.path.dirname(path), g['buffers'][0]['uri']), 'rb').read()

    def acc(i):
        a = g['accessors'][i]
        bv = g['bufferViews'][a['bufferView']]
        fmt, size = COMP[a['componentType']]
        n = NCOMP[a['type']]
        stride = bv.get('byteStride', size * n)
        off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        out = np.zeros((a['count'], n), dtype=np.float64)
        for k in range(a['count']):
            out[k] = struct.unpack_from('<' + fmt * n, bin_data, off + k * stride)
        if a.get('normalized'):
            out /= {5121: 255.0, 5123: 65535.0, 5120: 127.0, 5122: 32767.0}[a['componentType']]
        return out
    return g, acc


def noise(size, cells, seed):
    r = np.random.default_rng(seed)
    gsz = cells
    grid = r.random((gsz + 1, gsz + 1))
    xs = np.linspace(0, gsz, size, endpoint=False)
    x0 = xs.astype(int)
    f = xs - x0
    f = f * f * (3 - 2 * f)
    a = grid[np.ix_(x0, x0)]
    b = grid[np.ix_(x0, x0 + 1)]
    c = grid[np.ix_(x0 + 1, x0)]
    d = grid[np.ix_(x0 + 1, x0 + 1)]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, seed):
    return noise(size, 8, seed) * 0.5 + noise(size, 32, seed + 1) * 0.3 + noise(size, 128, seed + 2) * 0.2


def main():
    g, acc = load_gltf(os.path.join(UBC, 'Superhero_Male_FullBody.gltf'))
    joint_names = [g['nodes'][j]['name'] for j in g['skins'][0]['joints']]
    prim = g['meshes'][2]['primitives'][0]
    pos = acc(prim['attributes']['POSITION'])
    uv = acc(prim['attributes']['TEXCOORD_0'])
    joints = acc(prim['attributes']['JOINTS_0']).astype(int)
    weights = acc(prim['attributes']['WEIGHTS_0'])
    idx = acc(prim['indices']).astype(int).reshape(-1, 3)
    print('verts', len(pos), 'tris', len(idx))

    def group(name):
        if name in ('neck_01', 'Head') or name.startswith(('hand', 'index', 'middle', 'pinky', 'ring', 'thumb')):
            return 0  # кожа
        if name.startswith(('foot', 'ball')):
            return 3  # сапоги
        if name.startswith(('thigh', 'calf')) or name in ('pelvis', 'root'):
            return 2  # штаны
        return 1      # куртка
    jg = np.array([group(n) for n in joint_names])
    gw = np.zeros((len(pos), 4))
    for k in range(4):
        np.add.at(gw, (np.arange(len(pos)), jg[joints[:, k]]), weights[:, k])
    vreg = gw.argmax(1)
    y = pos[:, 1]
    vreg[(vreg == 2) & (y > 0.9)] = 1      # подол куртки закрывает пояс
    vreg[(vreg == 0) & (y < 1.47) & (np.abs(pos[:, 0]) < 0.2)] = 1  # воротник
    vreg[(vreg == 2) & (y < 0.24)] = 3     # высокие сапоги

    # растеризация треугольников в UV
    region = np.full((RES, RES), -1, dtype=np.int8)
    uvp = uv * RES
    for t in idx:
        rs = vreg[t]
        r = np.bincount(rs, minlength=4).argmax()
        p = uvp[t]
        x0, y0 = np.floor(p.min(0)).astype(int)
        x1, y1 = np.ceil(p.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, RES - 1), min(y1, RES - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = p
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            continue
        w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        w2 = 1 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        sub = region[y0:y1 + 1, x0:x1 + 1]
        sub[m] = r

    # расширяем области за края островов, чтобы не было швов
    for _ in range(6):
        empty = region < 0
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(region, (dy, dx), (0, 1))
            fill = empty & (sh >= 0)
            region[fill] = sh[fill]
            empty = region < 0
    region[region < 0] = 1

    border = np.zeros_like(region, dtype=bool)
    for dy, dx in ((0, 2), (0, -2), (2, 0), (-2, 0)):
        border |= np.roll(region, (dy, dx), (0, 1)) != region

    for name, o in OUTFITS.items():
        skin = Image.open(os.path.join(UBC, 'T_Superhero_Male_%s.png' % o['skin'])).convert('RGB').resize((RES, RES), Image.LANCZOS)
        base = np.asarray(skin).astype(float)
        lum = base.mean(2, keepdims=True)
        detail = lum / max(lum.mean(), 1)
        seed = abs(hash(name)) % 1000
        fab = fbm(RES, seed)[..., None]
        weave = (noise(RES, 256, seed + 5)[..., None] - 0.5) * 0.18
        img = base.copy()
        for reg, key, rough in ((1, 'jacket', 0.35), (2, 'pants', 0.3), (3, 'boots', 0.25)):
            col = np.array(o[key], dtype=float)
            c = col * (0.78 + 0.44 * fab + weave) * (0.75 + 0.25 * detail)
            m = region == reg
            img[m] = c[m]
        if o['stripe'] is not None:
            # светоотражающая/цветная полоса на куртке (по высоте UV-острова не угадать — рисуем по шуму полосой)
            pass
        # швы на границах одежды
        img[border & (region > 0)] *= 0.55
        # грязь: тёмные пятна, сильнее на штанах и сапогах
        dirt = np.clip((fbm(RES, seed + 11) - 0.45) * 3.0, 0, 1)[..., None] * o['dirt']
        extra = np.where(((region == 2) | (region == 3))[..., None], 1.3, 1.0)
        img = img * (1 - dirt * 0.55 * extra) + np.array((40, 32, 22)) * dirt * 0.3 * extra
        # кожа тоже не чистая
        sk = (region == 0)[..., None]
        img = np.where(sk, img * (0.9 - 0.15 * o['dirt'] * fab), img)
        Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + '.png'))
        print('skin', name)

    # карта областей — для отладки
    pal = np.array([(220, 180, 150), (60, 80, 160), (80, 80, 80), (30, 20, 10)], dtype=np.uint8)
    Image.fromarray(pal[region]).save(os.path.join(OUT, '_regions.png'))


if __name__ == '__main__':
    main()
