# Скачивает CC0-ассеты с Poly Haven (модели glTF 1k и текстуры) и ужимает текстуры
# до «пиксельного» размера. Запуск: python tools/get_polyhaven.py   (из папки game)
import json, os, sys, subprocess, urllib.request
from concurrent.futures import ThreadPoolExecutor
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(ROOT, 'assets', 'ph')
TEX_DIR = os.path.join(ROOT, 'assets', 'tex')
UA = {'User-Agent': 'dragmet-asset-fetch/1.0'}

MODELS = [
    'Barrel_01', 'barrel_03', 'barrel_stove', 'cardboard_box_01', 'trashbag', 'metal_trash_can', 'can_rusted',
    'circuit_board', 'cassette_player', 'television_02', 'old_tyre', 'wooden_crate_01', 'wooden_crate_02',
    'plastic_crate_01', 'steel_frame_shelves_01', 'worn_metal_rack', 'metal_office_desk', 'WoodenChair_01',
    'metal_stool_01', 'folding_wooden_stool', 'lightbulb_01', 'mounted_fluorescent_lights',
    'power_box_01', 'street_rat', 'old_bed_frame', 'cement_bag', 'compost_bags', 'plastic_bottle_gallon',
    'bleach_bottle', 'chemistry_set', 'propane_tank', 'metal_toolbox', 'bench_vice_01', 'old_gas_mask',
    'metal_jerrycan', 'pot_enamel_01', 'russian_food_cans_01', 'cigarette_pack', 'modular_chainlink_fence',
    'rubber_boots', 'wooden_bucket_01', 'korean_public_payphone_01', 'utility_box_01', 'retro_multimeter',
    'vintage_telephone_wall_clock', 'classic_laptop', 'wooden_military_crate', 'industrial_pastic_container',
]
# поверхность → id текстуры
TEXTURES = {
    'floor': 'concrete_floor_worn_001', 'wall_low': 'peeling_painted_wall', 'wall_top': 'damaged_plaster',
    'ceiling': 'concrete_wall_006', 'metal': 'rusty_metal_02', 'door': 'rusty_painted_metal',
    'grate': 'rusty_metal_grid', 'planks': 'distressed_painted_planks', 'brick': 'broken_brick_wall',
    'carpet': 'dirty_carpet', 'plaster_dirty': 'grey_plaster_03',
}
MODEL_TEX_MAX = 256
SURF_TEX_MAX = 256


def get_json(url):
    out = subprocess.run(['curl', '-sSL', '--max-time', '40', '--retry', '3', '-A', UA['User-Agent'], url],
                         capture_output=True, check=True).stdout
    return json.loads(out.decode('utf-8'))


def download(url, path):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(['curl', '-sSL', '--max-time', '120', '--retry', '3', '-A', UA['User-Agent'], '-o', path, url], check=True)


def shrink(path, max_size):
    try:
        im = Image.open(path)
    except Exception:
        return
    if max(im.size) <= max_size:
        return
    s = max_size / max(im.size)
    im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    if path.lower().endswith(('.jpg', '.jpeg')):
        im.convert('RGB').save(path, quality=92)
    else:
        im.save(path)


def fetch_model(mid):
    files = get_json('https://api.polyhaven.com/files/' + mid)
    g = files.get('gltf', {})
    res = '1k' if '1k' in g else sorted(g.keys())[0]
    entry = g[res]['gltf']
    out = os.path.join(MODELS_DIR, mid)
    download(entry['url'], os.path.join(out, mid + '.gltf'))
    for rel, inc in entry.get('include', {}).items():
        p = os.path.join(out, rel)
        download(inc['url'], p)
        if rel.lower().endswith(('.jpg', '.jpeg', '.png')):
            shrink(p, MODEL_TEX_MAX)
    total = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(out) for f in fs)
    print('model', mid, res, '%.1f MB' % (total / 1e6))


def fetch_texture(name, tid):
    files = get_json('https://api.polyhaven.com/files/' + tid)
    want = {'Diffuse': 'diff', 'nor_gl': 'nor', 'Rough': 'rough'}
    for key, suf in want.items():
        if key not in files:
            continue
        r = files[key]
        res = '1k' if '1k' in r else sorted(r.keys())[0]
        fmt = 'jpg' if 'jpg' in r[res] else list(r[res].keys())[0]
        p = os.path.join(TEX_DIR, '%s_%s.%s' % (name, suf, fmt))
        download(r[res][fmt]['url'], p)
        shrink(p, SURF_TEX_MAX)
    print('tex', name, tid)


if __name__ == '__main__':
    only = sys.argv[1:]

    def job(kind, a, b=None):
        try:
            fetch_texture(a, b) if kind == 'tex' else fetch_model(a)
        except Exception as e:
            print('FAIL', kind, a, e)
    jobs = [('tex', n, t) for n, t in TEXTURES.items() if not only or n in only]
    jobs += [('model', m, None) for m in MODELS if not only or m in only]
    with ThreadPoolExecutor(8) as ex:
        list(ex.map(lambda j: job(*j), jobs))
