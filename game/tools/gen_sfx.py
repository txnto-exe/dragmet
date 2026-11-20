# Генератор звуков для ДРАГМЕТ: всё синтезируется, без чужих сэмплов.
# Запуск: python tools/gen_sfx.py   (из папки game)
import os, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'sfx')
os.makedirs(OUT, exist_ok=True)
SR = 22050
R = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.005, decay=8.0):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x * decay)


def lowpass(x, k):
    """Простой фильтр: скользящее среднее k отсчётов (k>1 — глуше)."""
    if k <= 1:
        return x
    c = np.cumsum(np.insert(x, 0, 0))
    y = (c[k:] - c[:-k]) / k
    return np.concatenate([y, np.zeros(k - 1)])


def highpass(x, k):
    return x - lowpass(x, k)


def noise(sec):
    return R.uniform(-1, 1, int(SR * sec))


def write(name, x, gain=0.8):
    x = np.asarray(x, dtype=float)
    peak = np.max(np.abs(x)) or 1
    x = x / peak * gain
    data = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def pad(x, sec):
    return np.concatenate([x, np.zeros(int(SR * sec))])


# Капля: «плинк» с падающим тоном
def drip():
    tt = t(0.25)
    f = 1500 * np.exp(-tt * 9) + 600
    ph = np.cumsum(2 * np.pi * f / SR)
    x = np.sin(ph) * env(len(tt), 0.001, 22)
    x += lowpass(noise(0.25), 3) * env(len(tt), 0.001, 60) * 0.3
    return x


# Шипение кислоты
def sizzle():
    tt = t(0.9)
    x = highpass(noise(0.9), 3) * env(len(tt), 0.01, 3.5)
    x *= 0.6 + 0.4 * np.abs(np.sin(tt * 90 + R.uniform(0, 3)))
    return x


# Шаг по бетону с крошкой
def step(seed):
    r = np.random.default_rng(seed)
    tt = t(0.16)
    body = lowpass(r.uniform(-1, 1, len(tt)), 9) * env(len(tt), 0.002, 30)
    grit = highpass(r.uniform(-1, 1, len(tt)), 2) * env(len(tt), 0.001, 55) * 0.35
    thump = np.sin(2 * np.pi * (90 + seed * 7) * tt) * env(len(tt), 0.001, 40) * 0.6
    return body + grit + thump


# Шорох хлама (пакеты, картон)
def rustle(seed):
    r = np.random.default_rng(seed)
    tt = t(0.4)
    x = highpass(r.uniform(-1, 1, len(tt)), 2)
    am = lowpass(r.uniform(0, 1, len(tt)), 300) ** 2
    return x * am * env(len(tt), 0.01, 6) * 3


# Глухой удар
def thud():
    tt = t(0.35)
    x = np.sin(2 * np.pi * (70 + 40 * np.exp(-tt * 20)) * tt) * env(len(tt), 0.002, 12)
    x += lowpass(noise(0.35), 12) * env(len(tt), 0.001, 25) * 0.5
    return x


# Стук в дверь: три удара костяшками по металлу
def knock(hard=False):
    one = []
    tt = t(0.22)
    base = 150 if not hard else 110
    hit = (np.sin(2 * np.pi * base * tt) + 0.5 * np.sin(2 * np.pi * base * 2.7 * tt)
           + 0.25 * np.sin(2 * np.pi * base * 5.1 * tt)) * env(len(tt), 0.001, 18 if not hard else 12)
    hit += lowpass(noise(0.22), 4) * env(len(tt), 0.001, 70) * 0.6
    gap = 0.24 if not hard else 0.2
    out = np.zeros(int(SR * (gap * 3 + 0.3)))
    for i in range(3 if not hard else 4):
        s = int(SR * gap * i)
        if s + len(hit) > len(out):
            out = np.concatenate([out, np.zeros(s + len(hit) - len(out))])
        out[s:s + len(hit)] += hit * (1.0 if i != 1 else 0.85)
    return out


# Скрип двери
def creak():
    tt = t(1.3)
    f = 230 + 90 * np.sin(tt * 3.1) + 40 * np.sin(tt * 11)
    ph = np.cumsum(2 * np.pi * f / SR)
    saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
    grain = (R.uniform(0, 1, len(tt)) > 0.6).astype(float)
    x = lowpass(saw * grain, 4) * np.sin(np.pi * tt / 1.3) ** 0.7
    return x


def door_shut():
    x = thud()
    tt = t(0.35)
    x += np.sin(2 * np.pi * 420 * tt) * env(len(tt), 0.001, 30) * 0.3
    return x


# Монеты
def coins():
    out = np.zeros(int(SR * 0.6))
    for i, f in enumerate((2100, 2600, 1900, 3100, 2400)):
        tt = t(0.25)
        s = int(SR * (0.05 * i + R.uniform(0, 0.02)))
        x = (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * f * 2.4 * tt)) * env(len(tt), 0.001, 20)
        out[s:s + len(tt)] += x[:len(out) - s]
    return out


# Подобрал находку
def pickup():
    tt = t(0.22)
    f = 520 + 900 * tt / 0.22
    ph = np.cumsum(2 * np.pi * f / SR)
    sq = np.sign(np.sin(ph)) * 0.5 + np.sin(ph) * 0.5
    return lowpass(sq, 2) * env(len(tt), 0.002, 9)


# Голосок в диалоге (питч меняется в игре)
def blip():
    tt = t(0.06)
    sq = np.sign(np.sin(2 * np.pi * 220 * tt))
    return lowpass(sq, 3) * env(len(tt), 0.002, 40)


# Монета/купюра в щель ящика
def slot():
    tt = t(0.4)
    x = lowpass(noise(0.4), 2) * env(len(tt), 0.002, 25) * 0.5
    x += np.sin(2 * np.pi * 900 * tt) * env(len(tt), 0.001, 18) * 0.6
    x += np.sin(2 * np.pi * 1350 * tt) * env(len(tt), 0.001, 22) * 0.3
    return pad(x, 0.1)


# Плохо: низкий гул-удар
def bad():
    tt = t(1.2)
    x = np.sin(2 * np.pi * 55 * tt) * env(len(tt), 0.01, 2.5)
    x += np.sin(2 * np.pi * 58 * tt) * env(len(tt), 0.01, 2.5)
    x += lowpass(noise(1.2), 30) * env(len(tt), 0.001, 4) * 0.6
    return x


# Треск лампочки
def buzz():
    tt = t(0.35)
    x = np.sign(np.sin(2 * np.pi * 100 * tt)) * 0.5 + highpass(noise(0.35), 2) * 0.5
    gate = (lowpass(R.uniform(0, 1, len(tt)), 200) > 0.5).astype(float)
    return x * gate * env(len(tt), 0.002, 4)


# Фоновый гул подвала: трансформаторный гул + низкий дрон + воздух. Ровно 8 секунд — шов не слышен.
def ambience():
    sec = 8.0
    tt = t(sec)
    hum = 0.25 * np.sin(2 * np.pi * 50 * tt) + 0.15 * np.sin(2 * np.pi * 100 * tt) + 0.06 * np.sin(2 * np.pi * 150 * tt)
    drone = 0.35 * np.sin(2 * np.pi * 41.25 * tt + 0.3 * np.sin(2 * np.pi * 0.25 * tt))
    drone += 0.2 * np.sin(2 * np.pi * 61.875 * tt) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.125 * tt))
    air = lowpass(noise(sec), 40) * 3
    air *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.25 * tt)
    x = hum * 0.5 + drone + air * 0.5
    fade = int(SR * 0.05)
    x[:fade] *= np.linspace(0, 1, fade) * 0 + 1  # периоды кратны 8 с, шов ровный
    return x


# Порез/больно
def hurt():
    tt = t(0.4)
    x = highpass(noise(0.4), 2) * env(len(tt), 0.001, 14)
    x += np.sin(2 * np.pi * (300 - 200 * tt) * tt) * env(len(tt), 0.001, 8) * 0.6
    return x


# Крыса пищит
def squeak():
    tt = t(0.3)
    f = 2600 + 700 * np.sin(tt * 60)
    ph = np.cumsum(2 * np.pi * f / SR)
    return np.sin(ph) * env(len(tt), 0.01, 10)


write('drip', drip(), 0.7)
write('sizzle', sizzle(), 0.5)
for i in range(4):
    write('step%d' % i, step(i + 1), 0.6)
for i in range(3):
    write('rustle%d' % i, rustle(10 + i), 0.7)
write('thud', thud(), 0.8)
write('knock', knock(), 0.9)
write('knock_hard', knock(True), 0.95)
write('creak', creak(), 0.6)
write('door_shut', door_shut(), 0.8)
write('coins', coins(), 0.6)
write('pickup', pickup(), 0.5)
write('blip', blip(), 0.4)
write('slot', slot(), 0.7)
write('bad', bad(), 0.9)
write('buzz', buzz(), 0.4)
write('ambience', ambience(), 0.5)
write('hurt', hurt(), 0.7)
write('squeak', squeak(), 0.4)
print('sfx ok')


# Звонок старого таксофона
def ring():
    out = np.zeros(int(SR * 2.2))
    for k in range(2):
        tt = t(0.4)
        x = (np.sin(2 * np.pi * 440 * tt) + np.sin(2 * np.pi * 480 * tt)) * (np.sin(2 * np.pi * 25 * tt) > 0)
        s = int(SR * 0.5 * k)
        out[s:s + len(tt)] += x * 0.5
    return out


write('ring', ring(), 0.6)


# ---------- бак на подъёмнике, кислота, печь ----------

# Гидравлика подъёмника: гул мотора с подвыванием + шипение
def lift():
    sec = 2.6
    tt = t(sec)
    f = 62 + 18 * np.clip(tt / 0.4, 0, 1) - 10 * np.clip((tt - 2.1) / 0.5, 0, 1)
    ph = np.cumsum(2 * np.pi * f / SR)
    motor = np.sign(np.sin(ph)) * 0.35 + np.sin(ph * 2) * 0.3
    whine = 0.12 * np.sin(np.cumsum(2 * np.pi * (f * 7.5) / SR))
    hiss = highpass(noise(sec), 2) * 0.25
    shape = np.clip(tt / 0.15, 0, 1) * np.clip((sec - tt) / 0.3, 0, 1)
    return lowpass(motor + whine, 3) * shape + hiss * shape * 0.6


# Железный лязг (бак встал / створки)
def clank():
    tt = t(0.6)
    x = np.zeros(len(tt))
    for f, d in ((180, 9), (433, 12), (791, 16), (1260, 22)):
        x += np.sin(2 * np.pi * f * tt) * env(len(tt), 0.001, d)
    x += lowpass(noise(0.6), 3) * env(len(tt), 0.001, 40) * 0.8
    return x


# Бульканье кислоты (петля 4 с)
def bubbles():
    sec = 4.0
    out = highpass(noise(sec), 3) * 0.08
    for i in range(70):
        s = int(R.uniform(0, sec - 0.1) * SR)
        tt = t(0.05)
        f0 = R.uniform(300, 900)
        f = f0 * (1 + tt * 18)
        b = np.sin(np.cumsum(2 * np.pi * f / SR)) * env(len(tt), 0.002, 50)
        out[s:s + len(b)] += b * R.uniform(0.2, 0.6)
    return out


# Огонь в печи: треск поверх гула (петля 4 с)
def fire():
    sec = 4.0
    tt = t(sec)
    roar = lowpass(noise(sec), 25) * 4 * (0.8 + 0.2 * np.sin(2 * np.pi * 0.5 * tt))
    out = roar
    for i in range(90):
        s = int(R.uniform(0, sec - 0.05) * SR)
        c = highpass(R.uniform(-1, 1, int(SR * 0.012)), 2) * R.uniform(0.2, 0.9)
        out[s:s + len(c)] += c
    return out


# Мехи: вдох-выдох воздуха
def bellows():
    tt = t(0.7)
    x = lowpass(noise(0.7), 6) * np.sin(np.pi * tt / 0.7) ** 1.5
    return x * 2


# Кусачки перекусили замок
def snip():
    tt = t(0.3)
    x = (np.sin(2 * np.pi * 2400 * tt) + np.sin(2 * np.pi * 3700 * tt)) * env(len(tt), 0.001, 30)
    x += highpass(noise(0.3), 2) * env(len(tt), 0.001, 45)
    return pad(x, 0.1)


# Удачно (находка открылась / хорошее качество): два коротких тона вверх
def good():
    out = np.zeros(int(SR * 0.35))
    for i, f in enumerate((660, 990)):
        tt = t(0.16)
        s = int(SR * 0.09 * i)
        x = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * f * 2 * tt)) * env(len(tt), 0.002, 14)
        out[s:s + len(tt)] += x
    return out


write('lift', lift(), 0.7)
write('clank', clank(), 0.8)
write('bubbles', bubbles(), 0.5)
write('fire', fire(), 0.5)
write('bellows', bellows(), 0.6)
write('snip', snip(), 0.7)
write('good', good(), 0.5)
print('sfx2 ok')
