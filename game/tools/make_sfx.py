# Собирает звуки игры (sfx/*.wav) из настоящих записей под лицензией CC0.
# Источники (все CC0, список авторов — в CREDITS.md):
#   * Kenney — Impact Sounds, RPG Audio, Interface Sounds, Casino Audio (https://kenney.nl)
#   * Freesound — отдельные записи, номер записи указан ниже (https://freesound.org/s/<номер>/)
# Запуск: python tools/make_sfx.py <папка с распакованными паками Kenney> <папка с mp3 Freesound (<номер>.mp3)>
# Скрипт режет нужный кусок, делает мягкие края, бесшовные петли и выравнивает громкость
# по прежним (подобранным в игре) уровням.
import os, sys, json
import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'sfx')
SR = 44100

KEN, FS = sys.argv[1], sys.argv[2]


def ken(pack, name):
    return os.path.join(KEN, pack, 'Audio', name)


def fs(sid):
    return os.path.join(FS, '%d.mp3' % sid)


# имя: (файл, начало c, конец c (None — до конца), петля c (0 — не петля), громкость дБ относительно прежней, опции)
SOUNDS = {
    # шаги по бетону
    'step0': (ken('impact-sounds', 'footstep_concrete_000.ogg'), 0, None, 0, -3, {}),
    'step1': (ken('impact-sounds', 'footstep_concrete_001.ogg'), 0, None, 0, -3, {}),
    'step2': (ken('impact-sounds', 'footstep_concrete_002.ogg'), 0, None, 0, -3, {}),
    'step3': (ken('impact-sounds', 'footstep_concrete_003.ogg'), 0, None, 0, -3, {}),
    # хлам в баке: бумага, пакет, тряпка
    'rustle0': (fs(197179), 0.25, 0.8, 0, -2, {}),
    'rustle1': (fs(655630), 0.35, 0.95, 0, -2, {}),
    'rustle2': (ken('rpg-audio', 'cloth1.ogg'), 0, None, 0, -2, {}),
    'thud': (ken('impact-sounds', 'impactSoft_heavy_001.ogg'), 0, None, 0, -1, {}),
    'glass': (ken('impact-sounds', 'impactGlass_light_001.ogg'), 0, None, 0, 0, {}),
    'clank': (ken('impact-sounds', 'impactMetal_heavy_000.ogg'), 0, None, 0, -3, {}),
    'hurt': (ken('impact-sounds', 'impactPunch_medium_000.ogg'), 0, None, 0, -2, {}),
    'creak': (ken('rpg-audio', 'creak1.ogg'), 0, None, 0, -1, {}),
    'door_shut': (ken('rpg-audio', 'doorClose_1.ogg'), 0, None, 0, -1, {}),
    'snip': (ken('rpg-audio', 'metalLatch.ogg'), 0, None, 0, 0, {}),
    'pickup': (ken('rpg-audio', 'handleSmallLeather.ogg'), 0, None, 0, 0, {}),
    'coins': (ken('rpg-audio', 'handleCoins.ogg'), 0, None, 0, -1, {}),
    'slot': (ken('casino-audio', 'chip-lay-1.ogg'), 0, None, 0, 0, {}),
    # интерфейс — тихо и мягко
    'blip': (ken('interface-sounds', 'select_002.ogg'), 0, None, 0, -6, {}),
    'good': (ken('interface-sounds', 'confirmation_001.ogg'), 0, None, 0, -4, {}),
    'bad': (ken('interface-sounds', 'error_004.ogg'), 0, None, 0, -5, {}),
    # Freesound
    'knock': (fs(254981), 0.0, 2.0, 0, 0, {}),
    'ring': (fs(332073), 0.0, 2.2, 0, -3, {'fade_out': 0.5}),
    'drip': (fs(273870), 0.0, None, 0, -2, {'limit': True}),
    'sizzle': (fs(382313), 0.6, 1.6, 0, -3, {'fade_out': 0.35, 'limit': True}),
    'squeak': (fs(288941), 0.0, 0.7, 0, -4, {'fade_out': 0.2}),
    'lift': (fs(403075), 1.0, 4.0, 0, -2, {'fade_out': 0.6}),
    'buzz': (fs(553075), 2.0, 2.45, 0, -4, {}),
    'bellows': (fs(361771), 0.05, 0.75, 0, -2, {'fade_out': 0.2}),
    'bubbles': (fs(202094), 0.15, 2.05, 0.3, -2, {}),
    'fire': (fs(532191), 20.0, 34.0, 1.0, -2, {'limit': True}),
    'ambience': (fs(208073), 6.0, 44.0, 2.0, -4, {}),
}


def load(path):
    x, sr = sf.read(path, always_2d=True, dtype='float64')
    x = x.mean(axis=1)
    if sr != SR:
        n = int(round(len(x) * SR / sr))
        x = np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)
    return x


def active_rms(x):
    if len(x) == 0:
        return 1e-9
    hop = max(1, SR // 50)
    fr = [np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, max(1, len(x) - hop + 1), hop)]
    fr = np.array(fr)
    keep = fr[fr > fr.max() * 0.03]
    return float(np.sqrt(np.mean(keep ** 2))) if len(keep) else float(fr.max())


def fade(x, a, b):
    na, nb = int(a * SR), int(b * SR)
    if na > 0:
        x[:na] *= np.linspace(0, 1, na) ** 2
    if nb > 0:
        x[-nb:] *= np.linspace(1, 0, nb) ** 2
    return x


def make(name, spec):
    path, t0, t1, loop, rel_db, opt = spec
    x = load(path)
    a = int(t0 * SR)
    b = len(x) if t1 is None else min(len(x), int(t1 * SR))
    if loop > 0:
        xf = int(loop * SR)
        seg = x[a:b].copy()
        body = seg[:-xf].copy()
        tail = seg[-xf:]
        t = np.linspace(0, 1, xf)
        body[:xf] = body[:xf] * np.sqrt(t) + tail * np.sqrt(1 - t)
        x = body
    else:
        x = x[a:b].copy()
        # убираем тишину в начале у коротких звуков
        thr = np.abs(x).max() * 0.02
        nz = np.nonzero(np.abs(x) > thr)[0]
        if len(nz) and t1 is None:
            x = x[max(0, nz[0] - int(0.003 * SR)):]
        x = fade(x, 0.004, opt.get('fade_out', 0.03))
    x -= np.mean(x)
    old = os.path.join(OUT, name + '.wav')
    target = LEVELS[name] * 10 ** (rel_db / 20) if name in LEVELS else None
    if target:
        x *= target / active_rms(x)
    if opt.get('limit'):
        x = 0.89 * np.tanh(x / 0.89)   # мягкий лимитер: щелчки огня не «стреляют»
    peak = np.abs(x).max()
    if peak > 0.89:
        x *= 0.89 / peak
    sf.write(old, x.astype(np.float32), SR, subtype='PCM_16')
    print('%-10s %5.2fs  rms %.3f  peak %.2f' % (name, len(x) / SR, active_rms(x), np.abs(x).max()))


LEVELS_P = os.path.join(ROOT, 'tools', 'sfx_levels.json')
if os.path.exists(LEVELS_P):
    LEVELS = json.load(open(LEVELS_P))
else:
    # первый запуск: запоминаем громкость прежних (синтезированных) звуков как ориентир
    LEVELS = {n: active_rms(load(os.path.join(OUT, n + '.wav'))) for n in SOUNDS if os.path.exists(os.path.join(OUT, n + '.wav'))}
    json.dump(LEVELS, open(LEVELS_P, 'w'), indent=1)

if __name__ == '__main__':
    for n, s in SOUNDS.items():
        make(n, s)
