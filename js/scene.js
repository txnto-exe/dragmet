'use strict';
// Живые пиксельные сцены: двор с героем (вкладка «Копать»), кислотная, печь,
// скупщик и главное меню. Плюс эффекты: полёт находок, искры, вспышки, монеты.
//
// Сцена рисуется в canvas маленького разрешения (1 точка = 1 пиксель арта),
// а CSS растягивает его в PX раз без сглаживания.
// Здесь ничего не меняется в игре — только показывается состояние G.

// ===== Время суток и погода (по часам телефона) =====

/** Насколько темно: 0 — день, 1 — ночь. Плавно на рассвете (6–8) и закате (18–21). */
function nightness(date = new Date()) {
  const h = date.getHours() + date.getMinutes() / 60;
  if (h >= 8 && h < 18) return 0;
  if (h >= 21 || h < 6) return 1;
  if (h >= 6 && h < 8) return 1 - (h - 6) / 2;
  return (h - 18) / 3;
}

/** Погода на текущий час: одинакова весь час, меняется от часа к часу. */
function weatherNow(date = new Date()) {
  const seed = Math.floor(date.getTime() / 3600000);
  const r = seededRandom(seed * 7919 + 13)();
  const winter = [10, 11, 0, 1, 2].includes(date.getMonth());
  if (r < 0.22) return winter ? 'snow' : 'rain';
  if (r < 0.30) return 'rain';
  return 'clear';
}

const SKY_DAY = ['#4f6f96', '#7f9fbf', '#bccdd0'];
const SKY_NIGHT = ['#05070f', '#0d1426', '#1b2538'];
const NIGHT_TINT = '#0a0f1e';

/** Цвет предмета с учётом темноты. */
function nightTint(c, d, k = 0.72) {
  return d > 0 ? mixColor(c, NIGHT_TINT, d * k) : c;
}

// ===== Основа сцены =====

class PixelScene {
  constructor(canvas, height, draw) {
    this.cv = canvas;
    this.ctx = canvas.getContext('2d');
    this.h = height;
    this.w = 0;
    this.draw = draw;
    this.t = 0;
    this.last = 0;
    this.fx = [];        // эффекты: полёты, искры
    this.shake = 0;      // мс тряски
    this.flash = 0;      // 0..1 белая вспышка
    this.state = {};     // данные конкретной сцены
  }
  /** Подогнать ширину под контейнер: ширина в пикселях арта = ширина в CSS / PX. */
  fit() {
    const box = this.cv.parentElement;
    const cssW = box ? box.clientWidth : 0;
    if (!cssW) return false;
    const w = Math.max(40, Math.floor(cssW / PX));
    if (w !== this.w) {
      this.w = w;
      this.cv.width = w;
      this.cv.height = this.h;
      this.cv.style.width = w * PX + 'px';
      this.cv.style.height = this.h * PX + 'px';
    }
    return true;
  }
  frame() {
    const now = performance.now();
    const dt = this.last ? Math.min(now - this.last, 100) : 16;
    this.last = now;
    if (!this.fit()) return;
    this.t += dt;
    const ctx = this.ctx;
    ctx.save();
    if (this.shake > 0) {
      this.shake -= dt;
      ctx.translate(Math.round(Math.random() * 2 - 1), Math.round(Math.random() * 2 - 1));
    }
    this.draw(ctx, this.w, this.h, this.t, dt, this);
    drawEffects(ctx, this, dt);
    if (this.flash > 0) {
      ctx.fillStyle = `rgba(255,248,220,${this.flash * 0.7})`;
      ctx.fillRect(0, 0, this.w, this.h);
      this.flash = Math.max(0, this.flash - dt / 400);
    }
    ctx.restore();
  }
}

// ===== Мелкие функции рисования =====

function rect(ctx, x, y, w, h, c) {
  ctx.fillStyle = c;
  ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
}
function dot(ctx, x, y, c) { rect(ctx, x, y, 1, 1, c); }

/** Небо полосами с шахматным переходом между ними (дизер). */
function drawSky(ctx, w, horizon, d, seed) {
  const cols = [0, 1, 2].map(i => mixColor(SKY_DAY[i], SKY_NIGHT[i], d));
  // на закате и рассвете — тёплая полоса у горизонта
  const dusk = d > 0.05 && d < 0.95 ? 1 - Math.abs(d - 0.5) * 2 : 0;
  if (dusk > 0) cols[2] = mixColor(cols[2], '#d8784a', dusk * 0.8);
  if (dusk > 0) cols[1] = mixColor(cols[1], '#7a4a6a', dusk * 0.5);
  const bands = [[0, Math.floor(horizon * 0.45), cols[0]], [Math.floor(horizon * 0.45), Math.floor(horizon * 0.8), cols[1]], [Math.floor(horizon * 0.8), horizon, cols[2]]];
  for (const [y0, y1, c] of bands) rect(ctx, 0, y0, w, y1 - y0, c);
  // дизер на стыках полос
  for (let b = 1; b < bands.length; b++) {
    const y = bands[b][0];
    for (let x = 0; x < w; x++) {
      if ((x + y) % 2 === 0) dot(ctx, x, y - 1, bands[b][2]);
      if ((x + y) % 2 === 1) dot(ctx, x, y, bands[b - 1][2]);
    }
  }
  // звёзды и луна ночью
  if (d > 0.5) {
    const rnd = seededRandom(seed + 99);
    const a = (d - 0.5) * 2;
    for (let i = 0; i < w / 5; i++) {
      const sx = Math.floor(rnd() * w), sy = Math.floor(rnd() * horizon * 0.7);
      const tw = Math.sin(performance.now() / 600 + i) > 0.6 ? 1 : 0.55;
      dot(ctx, sx, sy, `rgba(240,240,255,${a * tw})`);
    }
    const mx = Math.floor(w * 0.82), my = 8;
    ctx.globalAlpha = a;
    rect(ctx, mx + 1, my, 4, 6, '#e8e4c8'); rect(ctx, mx, my + 1, 6, 4, '#e8e4c8');
    rect(ctx, mx + 3, my + 1, 2, 2, '#c8c4a8');
    ctx.globalAlpha = 1;
  }
}

/** Земля: асфальт или грунт с крапинками. */
function drawGround(ctx, w, y0, h, base, d, seed) {
  const c = nightTint(base, d, 0.6);
  rect(ctx, 0, y0, w, h - y0, c);
  rect(ctx, 0, y0, w, 1, lighten(c, 0.18));
  const rnd = seededRandom(seed + 5);
  for (let i = 0; i < w * 1.2; i++) {
    const x = Math.floor(rnd() * w), y = y0 + 2 + Math.floor(rnd() * (h - y0 - 2));
    dot(ctx, x, y, rnd() < 0.5 ? darken(c, 0.25) : lighten(c, 0.1));
  }
}

/** Окна в прямоугольнике здания. lit — доля горящих окон ночью. */
function drawWindows(ctx, x, y, w, h, stepX, stepY, d, rnd, lit = 0.45) {
  for (let wy = y + 2; wy + 2 <= y + h - 2; wy += stepY) {
    for (let wx = x + 2; wx + 2 <= x + w - 1; wx += stepX) {
      const on = rnd() < lit;
      let c = d > 0.4 ? (on ? '#f0c860' : '#141a28') : '#8a9cac';
      if (d > 0.4 && on && rnd() < 0.25) c = '#a8d0f0';   // телевизор
      rect(ctx, wx, wy, 2, 2, c);
    }
  }
}

/** Фонарь со светом ночью. */
function drawLamp(ctx, x, groundY, d) {
  rect(ctx, x, groundY - 34, 1, 34, nightTint('#5a5e58', d, 0.5));
  rect(ctx, x, groundY - 34, 6, 1, nightTint('#5a5e58', d, 0.5));
  rect(ctx, x + 4, groundY - 33, 3, 2, d > 0.4 ? '#ffe9a0' : '#9a9a8a');
  if (d > 0.4) {
    const a = (d - 0.4) / 0.6;
    // конус света: в середине гуще, к краям — шахматкой
    for (let yy = 0; yy < 32; yy++) {
      const half = Math.floor(yy * 0.42) + 1;
      for (let xx = -half; xx <= half; xx++) {
        const edge = Math.abs(xx) > half * 0.6;
        if (edge && (xx + yy) % 2) continue;
        dot(ctx, x + 5 + xx, groundY - 31 + yy, `rgba(255,214,120,${0.13 * a})`);
      }
    }
    // пятно света на земле
    for (let xx = -16; xx <= 16; xx++) {
      for (let yy = -2; yy <= 2; yy++) {
        if ((xx * xx) / 256 + (yy * yy) / 6 > 1) continue;
        dot(ctx, x + 5 + xx, groundY + yy, `rgba(255,214,120,${0.16 * a})`);
      }
    }
  }
}

/** Дальний город: силуэты домов в дымке, чтобы небо не было пустым. */
function bgFar(ctx, w, gy, d, rnd, maxH) {
  const haze = mixColor(mixColor(SKY_DAY[2], SKY_NIGHT[2], d), '#000000', 0.25);
  const c = mixColor(nightTint('#5a6070', d), haze, 0.55);
  for (let x = -4; x < w;) {
    const bw = 8 + Math.floor(rnd() * 14), bh = Math.floor(maxH * (0.35 + rnd() * 0.65));
    rect(ctx, x, gy - bh, bw, bh, c);
    if (rnd() < 0.3) rect(ctx, x + Math.floor(bw / 2), gy - bh - 5, 1, 5, c);   // антенна
    if (d > 0.4) {
      for (let wy = gy - bh + 3; wy < gy - 2; wy += 4) {
        for (let wx = x + 2; wx < x + bw - 1; wx += 3) if (rnd() < 0.18) dot(ctx, wx, wy, 'rgba(240,200,110,0.55)');
      }
    }
    x += bw + 1 + Math.floor(rnd() * 3);
  }
}

// ===== Кот: иногда проходит по сцене =====
function drawCat(ctx, scene, w, groundY, dt) {
  const st = scene.state;
  if (!st.cat) st.cat = { x: -20, dir: 1, wait: 4000 + Math.random() * 8000 };
  const c = st.cat;
  if (c.wait > 0) { c.wait -= dt; return; }
  c.x += c.dir * dt * 0.018;
  const frame = Math.floor(c.x / 3) % 2 ? 'cat' : 'cat2';
  drawSprite(ctx, frame, c.x, groundY - 8, null, c.dir < 0);
  if (c.x > w + 20 || c.x < -24) {
    c.dir = -c.dir;
    c.x = c.dir > 0 ? -20 : w + 18;
    c.wait = 20000 + Math.random() * 30000;
  }
}

// ===== Фоны локаций (силуэты на горизонте) =====

const LOC_LOOK = {
  yard:         { ground: '#3a3b36', bg: bgYard, dumpster: true, lamp: true },
  construction: { ground: '#5a4a36', bg: bgConstruction },
  radiozavod:   { ground: '#3e3a30', bg: bgFactory },
  garages:      { ground: '#3c3a34', bg: bgGarages, lamp: true },
  workshop:     { ground: '#3a3a3a', bg: bgWorkshop },
  ats:          { ground: '#3a3c34', bg: bgAts },
  scrapyard:    { ground: '#4a3e30', bg: bgScrap },
  datacenter:   { ground: '#34383c', bg: bgDatacenter },
  institute:    { ground: '#3c3c38', bg: bgInstitute, lamp: true },
};

function bgYard(ctx, w, gy, d, rnd) {
  const c1 = nightTint('#7a7468', d), c2 = nightTint('#6a665c', d);
  // две панельные пятиэтажки
  rect(ctx, 4, gy - 40, Math.floor(w * 0.42), 40, c1);
  drawWindows(ctx, 4, gy - 40, Math.floor(w * 0.42), 40, 5, 7, d, rnd);
  const x2 = Math.floor(w * 0.55);
  rect(ctx, x2, gy - 34, w - x2 - 2, 34, c2);
  drawWindows(ctx, x2, gy - 34, w - x2 - 2, 34, 5, 7, d, rnd);
  // крыши
  rect(ctx, 4, gy - 41, Math.floor(w * 0.42), 1, darken(c1, 0.3));
  rect(ctx, x2, gy - 35, w - x2 - 2, 1, darken(c2, 0.3));
  // дерево
  const tx = Math.floor(w * 0.47);
  rect(ctx, tx, gy - 10, 2, 10, nightTint('#4a3420', d));
  for (let i = 0; i < 30; i++) dot(ctx, tx - 5 + Math.floor(rnd() * 12), gy - 20 + Math.floor(rnd() * 11), nightTint(rnd() < 0.5 ? '#3a5a2a' : '#4a6e32', d));
}

function bgConstruction(ctx, w, gy, d, rnd) {
  const c = nightTint('#8a8a84', d);
  // каркас недостроя
  const x0 = Math.floor(w * 0.1), bw = Math.floor(w * 0.5);
  for (let f = 0; f < 5; f++) rect(ctx, x0, gy - 8 - f * 9, bw, 2, c);
  for (let p = 0; p <= 5; p++) rect(ctx, x0 + Math.floor(p * (bw - 2) / 5), gy - 46, 2, 46, c);
  // кран
  const cx = Math.floor(w * 0.78), cy = gy - 58, yel = nightTint('#d8a830', d);
  rect(ctx, cx, cy, 2, 58, yel);
  for (let y = cy; y < gy; y += 4) dot(ctx, cx + (y / 4 % 2 ? 0 : 1), y + 2, darken(yel, 0.4));
  rect(ctx, cx - 30, cy, 44, 2, yel);
  rect(ctx, cx - 22, cy + 2, 1, 12 + Math.round(Math.sin(performance.now() / 1500) * 2), nightTint('#3a3a3a', d));
  if (d > 0.4 && Math.floor(performance.now() / 700) % 2) dot(ctx, cx + 13, cy - 1, '#ff4040');
  // забор
  for (let x = 0; x < w; x += 3) rect(ctx, x, gy - 7, 2, 7, nightTint('#5a6a4a', d));
}

function bgFactory(ctx, w, gy, d, rnd) {
  const c = nightTint('#6e5a4a', d);
  const x0 = 6, bw = Math.floor(w * 0.6);
  rect(ctx, x0, gy - 26, bw, 26, c);
  // пилообразная крыша
  for (let x = 0; x < bw; x++) {
    const hgt = (x % 12) < 8 ? Math.floor((x % 12) / 2) : 0;
    rect(ctx, x0 + x, gy - 26 - hgt, 1, hgt, c);
  }
  drawWindows(ctx, x0, gy - 22, bw, 14, 4, 6, d, rnd, 0.2);
  // трубы
  const t1 = Math.floor(w * 0.72), t2 = Math.floor(w * 0.85);
  rect(ctx, t1, gy - 52, 5, 52, nightTint('#8a4a3a', d));
  for (let y = gy - 52; y < gy; y += 8) rect(ctx, t1, y, 5, 3, nightTint('#d8d0c0', d));
  rect(ctx, t2, gy - 40, 4, 40, nightTint('#6a6460', d));
  // дым
  const now = performance.now() / 1000;
  for (let i = 0; i < 6; i++) {
    const k = (now * 0.3 + i / 6) % 1;
    const sx = t1 + 2 + Math.round(k * 14 + Math.sin(now + i) * 2), sy = gy - 54 - Math.round(k * 22);
    ctx.globalAlpha = (1 - k) * 0.6;
    rect(ctx, sx, sy, 3, 2, nightTint('#a8a8a0', d, 0.5));
  }
  ctx.globalAlpha = 1;
}

function bgGarages(ctx, w, gy, d, rnd) {
  const doors = ['#7a4a2a', '#3a5a7a', '#4a6a3a', '#7a6a3a', '#5a5a5a', '#6a3a3a'];
  const gw = 18;
  for (let x = 2, i = 0; x < w - gw; x += gw + 1, i++) {
    rect(ctx, x, gy - 18, gw, 18, nightTint('#8a8478', d));
    rect(ctx, x, gy - 19, gw, 1, nightTint('#5a564e', d));
    rect(ctx, x + 2, gy - 14, gw - 4, 14, nightTint(doors[i % doors.length], d));
    for (let y = gy - 13; y < gy; y += 3) rect(ctx, x + 2, y, gw - 4, 1, nightTint(darken(doors[i % doors.length], 0.25), d));
    if (rnd() < 0.3) for (let k = 0; k < 6; k++) dot(ctx, x + 3 + Math.floor(rnd() * (gw - 6)), gy - 12 + Math.floor(rnd() * 10), nightTint('#8a4a20', d));
  }
}

function bgWorkshop(ctx, w, gy, d, rnd) {
  const c = nightTint('#6a6e74', d);
  const x0 = Math.floor(w * 0.12), bw = Math.floor(w * 0.5);
  rect(ctx, x0, gy - 28, bw, 28, c);
  rect(ctx, x0 - 2, gy - 30, bw + 4, 3, nightTint('#4a4e54', d));
  // вывеска
  rect(ctx, x0 + 6, gy - 26, bw - 12, 6, nightTint('#2a4a7a', d));
  if (d > 0.4 && Math.floor(performance.now() / 300) % 9) rect(ctx, x0 + 8, gy - 24, bw - 16, 2, '#7ad0ff');
  else rect(ctx, x0 + 8, gy - 24, bw - 16, 2, nightTint('#c8d8e8', d));
  rect(ctx, x0 + 6, gy - 16, 14, 16, nightTint('#3a3a3a', d));
  drawWindows(ctx, x0 + 24, gy - 16, bw - 28, 10, 5, 6, d, rnd, 0.6);
  // покрышки
  const tx = Math.floor(w * 0.8);
  for (let i = 0; i < 4; i++) rect(ctx, tx, gy - 4 - i * 4, 12, 3, nightTint('#1e1e1e', d * 0.5));
}

function bgAts(ctx, w, gy, d, rnd) {
  const c = nightTint('#8a5a44', d);
  const x0 = 8, bw = Math.floor(w * 0.55);
  rect(ctx, x0, gy - 32, bw, 32, c);
  for (let y = gy - 32; y < gy; y += 3) for (let x = x0 + ((y / 3) % 2 ? 0 : 2); x < x0 + bw; x += 5) dot(ctx, x, y, darken(c, 0.2));
  drawWindows(ctx, x0, gy - 30, bw, 24, 6, 8, d, rnd, 0.1);
  // мачта
  const mx = Math.floor(w * 0.78), mc = nightTint('#9a9a9a', d);
  for (let y = 0; y < 60; y++) { dot(ctx, mx - Math.floor(y / 12), gy - y, mc); dot(ctx, mx + Math.floor(y / 12), gy - y, mc); }
  for (let y = 4; y < 60; y += 6) rect(ctx, mx - Math.floor(y / 12), gy - y, Math.floor(y / 6) + 1, 1, mc);
  if (Math.floor(performance.now() / 800) % 2) dot(ctx, mx, gy - 61, d > 0.3 ? '#ff3030' : '#c03030');
}

function bgScrap(ctx, w, gy, d, rnd) {
  // горы металлолома
  const heaps = [[0.18, 22, 0.3], [0.5, 30, 0.35], [0.85, 18, 0.25]];
  for (const [fx, hh, wr] of heaps) {
    const cx = Math.floor(w * fx), hw = Math.floor(w * wr);
    for (let x = -hw; x <= hw; x++) {
      const k = 1 - (x / hw) ** 2;
      const hgt = Math.floor(hh * k + (rnd() * 3));
      for (let y = 0; y < hgt; y++) dot(ctx, cx + x, gy - y, nightTint(['#5a4a3a', '#6a5a4a', '#4a4a4a', '#7a5a3a'][Math.floor(rnd() * 4)], d));
    }
  }
  // кран с магнитом
  const cx = Math.floor(w * 0.66), cc = nightTint('#c87830', d);
  rect(ctx, cx, gy - 48, 2, 48, cc);
  rect(ctx, cx - 18, gy - 48, 24, 2, cc);
  const sw = Math.round(Math.sin(performance.now() / 1200) * 2);
  rect(ctx, cx - 16 + sw, gy - 46, 1, 10, nightTint('#2a2a2a', d));
  rect(ctx, cx - 19 + sw, gy - 36, 7, 3, nightTint('#3a3a40', d));
}

function bgDatacenter(ctx, w, gy, d, rnd) {
  const c = nightTint('#4a5058', d);
  const x0 = 6, bw = Math.floor(w * 0.7);
  rect(ctx, x0, gy - 30, bw, 30, c);
  rect(ctx, x0, gy - 31, bw, 1, lighten(c, 0.2));
  // кондиционеры на крыше
  for (let x = x0 + 4; x < x0 + bw - 8; x += 12) rect(ctx, x, gy - 35, 8, 4, nightTint('#8a9098', d));
  // полосы огоньков
  const now = performance.now();
  for (let y = gy - 24; y < gy - 4; y += 5) {
    for (let x = x0 + 4; x < x0 + bw - 4; x += 3) {
      const on = (Math.floor(now / 200) + x * 7 + y * 3) % 11 < 3;
      dot(ctx, x, y, on ? (d > 0.3 ? '#40e0ff' : '#5aa8c0') : darken(c, 0.3));
    }
  }
}

function bgInstitute(ctx, w, gy, d, rnd) {
  const c = nightTint('#b8ae98', d);
  const x0 = Math.floor(w * 0.1), bw = Math.floor(w * 0.66);
  rect(ctx, x0, gy - 30, bw, 30, c);
  // фронтон
  for (let i = 0; i < 10; i++) rect(ctx, x0 + bw / 2 - 26 + i * 2.6, gy - 31 - i, 52 - i * 5.2, 1, c);
  // колонны
  for (let x = x0 + 6; x < x0 + bw - 4; x += 7) rect(ctx, x, gy - 26, 3, 26, lighten(c, 0.15));
  rect(ctx, x0, gy - 28, bw, 2, darken(c, 0.15));
  drawWindows(ctx, x0 + 9, gy - 24, bw - 14, 18, 7, 9, d, rnd, 0.15);
}

// ===== Мусорная куча и бак =====

const JUNK_COLORS = ['#6a6a60', '#8a8478', '#4a5a3a', '#5a4632', '#7a6a50', '#3a4a5a', '#8a5a3a', '#585858', '#6a7a4a'];

/** Куча мусора: ширина maxW, высота maxH * frac. В куче иногда блестит золото. */
function drawPile(ctx, cx, baseY, maxW, maxH, frac, seed, d, richness) {
  const half = Math.floor(maxW / 2);
  const rnd = seededRandom(seed);
  const tops = [];
  for (let x = -half; x <= half; x++) {
    const k = Math.sqrt(Math.max(0, 1 - (x / (half + 0.5)) ** 2));
    const hgt = Math.max(frac > 0 ? 1 : 0, Math.floor(maxH * frac * k + rnd() * 2.2 * frac));
    tops.push(hgt);
    for (let y = 0; y < hgt; y++) {
      let c = JUNK_COLORS[Math.floor(rnd() * JUNK_COLORS.length)];
      if (y === hgt - 1) c = lighten(c, 0.18);
      dot(ctx, cx + x, baseY - 1 - y, nightTint(c, d, 0.55));
    }
  }
  // контур сверху
  tops.forEach((hgt, i) => { if (hgt > 0) dot(ctx, cx - half + i, baseY - 1 - hgt, nightTint('#1a1c16', d, 0.3)); });
  // блеск ценного
  if (frac > 0) {
    const n = 1 + Math.floor(richness * 3);
    for (let i = 0; i < n; i++) {
      const tw = Math.sin(performance.now() / 350 + i * 2.1 + seed);
      if (tw < 0.7) continue;
      const ix = Math.floor((rnd() * 2 - 1) * half * 0.7);
      const top = tops[ix + half] || 1;
      const sy = baseY - 1 - Math.floor(rnd() * top);
      dot(ctx, cx + ix, sy, '#fff2a0');
      if (tw > 0.93) { dot(ctx, cx + ix - 1, sy, '#f5d060'); dot(ctx, cx + ix + 1, sy, '#f5d060'); dot(ctx, cx + ix, sy - 1, '#f5d060'); }
    }
  }
}

/** Зелёный мусорный бак. Возвращает y верхнего края (для кучи внутри). */
function drawDumpster(ctx, cx, groundY, d) {
  const w = 34, h = 16, x = cx - w / 2, y = groundY - h - 2;
  const body = nightTint('#3e6a3a', d, 0.6), dark = darken(body, 0.35), light = lighten(body, 0.2);
  rect(ctx, x - 1, y - 1, w + 2, h + 2, darken(body, 0.7));   // контур
  rect(ctx, x, y, w, h, body);
  rect(ctx, x, y, w, 2, light);
  for (let i = 4; i < w - 2; i += 6) rect(ctx, x + i, y + 3, 1, h - 4, dark);
  rect(ctx, x + 2, y + 6, 8, 3, nightTint('#e8e4d0', d, 0.6));   // табличка
  // колёса
  rect(ctx, x + 3, groundY - 2, 3, 2, '#141414'); rect(ctx, x + w - 6, groundY - 2, 3, 2, '#141414');
  return y;
}

/** Мешок героя: растёт по мере заполнения склада. */
function drawSack(ctx, x, groundY, fill, d, bump) {
  const w = 8 + Math.round(fill * 8), h = 7 + Math.round(fill * 9) + (bump > 0 ? 1 : 0);
  const c = nightTint('#a08860', d, 0.55), dk = darken(c, 0.35);
  rect(ctx, x - 1, groundY - h - 1, w + 2, h + 1, darken(c, 0.7));
  rect(ctx, x, groundY - h, w, h, c);
  rect(ctx, x, groundY - h, w, 1, lighten(c, 0.2));
  rect(ctx, x + w - 2, groundY - h + 1, 2, h - 1, dk);
  rect(ctx, x + Math.floor(w / 2) - 1, groundY - h - 2, 3, 2, dk);   // завязка
  return { x: x + w / 2, y: groundY - h };
}

// ===== Погода =====

function drawWeather(ctx, scene, w, h, dt) {
  const kind = weatherNow();
  const st = scene.state;
  if (st.weatherKind !== kind || !st.drops) {
    st.weatherKind = kind;
    st.drops = [];
    const n = kind === 'rain' ? Math.floor(w / 3) : kind === 'snow' ? Math.floor(w / 3) : 0;
    for (let i = 0; i < n; i++) st.drops.push({ x: Math.random() * w, y: Math.random() * h, s: 0.6 + Math.random() * 0.6 });
  }
  if (kind === 'rain') {
    for (const p of st.drops) {
      p.x -= 0.05 * dt * p.s; p.y += 0.22 * dt * p.s;
      if (p.y > h) { p.y = -3; p.x = Math.random() * (w + 20); }
      if (p.x < -2) p.x = w;
      rect(ctx, p.x, p.y, 1, 3, 'rgba(160,190,220,0.55)');
    }
  } else if (kind === 'snow') {
    for (const p of st.drops) {
      p.y += 0.025 * dt * p.s; p.x += Math.sin(scene.t / 700 + p.s * 9) * 0.02 * dt;
      if (p.y > h) { p.y = -1; p.x = Math.random() * w; }
      dot(ctx, p.x, p.y, 'rgba(240,244,255,0.9)');
    }
  }
}

// ===== Эффекты =====

const TIER_COLOR = { jk: '#9a9a8a', cm: '#e8eede', vl: '#6dc4e8', rp: '#d8a8ff', lg: '#f5d060' };

function addSparks(scene, x, y, color, n = 8, speed = 0.06) {
  for (let i = 0; i < n; i++) {
    const a = Math.random() * Math.PI * 2, v = speed * (0.4 + Math.random());
    scene.fx.push({ kind: 'spark', x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 0.03, life: 500 + Math.random() * 400, age: 0, color });
  }
}

function drawEffects(ctx, scene, dt) {
  const keep = [];
  for (const f of scene.fx) {
    f.age += dt;
    if (f.kind === 'spark') {
      f.x += f.vx * dt; f.y += f.vy * dt; f.vy += 0.00012 * dt;
      if (f.age < f.life) {
        ctx.globalAlpha = 1 - f.age / f.life;
        dot(ctx, f.x, f.y, f.color);
        ctx.globalAlpha = 1;
        keep.push(f);
      }
    } else if (f.kind === 'fly') {
      if (f.age < 0) { keep.push(f); continue; }
      const k = Math.min(1, f.age / f.dur);
      const x = f.x0 + (f.x1 - f.x0) * k;
      const y = f.y0 + (f.y1 - f.y0) * k - Math.sin(k * Math.PI) * f.arc;
      if (f.tier === 'lg' || f.tier === 'rp') {
        // лучи за редкой находкой
        ctx.globalAlpha = 0.5;
        for (let r = 0; r < 8; r++) {
          const a = r / 8 * Math.PI * 2 + f.age / 300;
          for (let l = 9; l < 15; l++) dot(ctx, x + 7 + Math.cos(a) * l, y + 7 + Math.sin(a) * l, TIER_COLOR[f.tier]);
        }
        ctx.globalAlpha = 1;
        if (Math.random() < 0.5) scene.fx.push({ kind: 'spark', x: x + 7, y: y + 7, vx: (Math.random() - 0.5) * 0.04, vy: -0.02, life: 400, age: 0, color: TIER_COLOR[f.tier] });
      }
      drawSprite(ctx, f.spr, x, y);
      if (k < 1) keep.push(f);
      else if (f.onLand) f.onLand();
    } else if (f.kind === 'coin') {
      f.x += f.vx * dt; f.y += f.vy * dt; f.vy += 0.0004 * dt;
      if (f.y > scene.h + 10) continue;
      drawSprite(ctx, 'coin', f.x, f.y);
      keep.push(f);
    }
  }
  scene.fx = keep;
}

/** Надпись, всплывающая над сценой (обычный текст пиксельным шрифтом). */
function floatText(wrap, xCss, yCss, text, color) {
  if (!wrap) return;
  const e = make('div', 'scene-float', text);
  e.style.left = xCss + 'px';
  e.style.top = yCss + 'px';
  if (color) e.style.color = color;
  wrap.appendChild(e);
  setTimeout(() => e.remove(), 1000);
}

/** Монетки летят от элемента к плашке денег в шапке. */
function coinBurst(fromEl, n = 10) {
  const to = el('cashWrap');
  if (!fromEl || !to) return;
  const a = fromEl.getBoundingClientRect(), b = to.getBoundingClientRect();
  for (let i = 0; i < n; i++) {
    const img = pxIcon('coin', 'fly-coin');
    const sx = a.left + a.width / 2 + (Math.random() - 0.5) * a.width * 0.6;
    const sy = a.top + a.height / 2;
    img.style.left = sx + 'px';
    img.style.top = sy + 'px';
    document.body.appendChild(img);
    const dx = b.left + b.width / 2 - sx, dy = b.top + b.height / 2 - sy;
    const midX = (Math.random() - 0.5) * 80, midY = -60 - Math.random() * 60;
    const anim = img.animate([
      { transform: 'translate(0,0)' },
      { transform: `translate(${midX}px,${midY}px)`, offset: 0.4 },
      { transform: `translate(${dx}px,${dy}px)` },
    ], { duration: 650 + Math.random() * 250, delay: i * 45, easing: 'ease-in', fill: 'forwards' });
    anim.onfinish = () => img.remove();
    setTimeout(() => img.remove(), 2000);
  }
}

// ===== Сцена «Копать»: точка сбора с героем =====

let digScene = null;
const DIG_H = 120;

/** Внешность героя меняется с престижем. */
function heroSwap(p = G.meta.prestige) {
  const swap = {};
  if (p >= 1) Object.assign(swap, { c: '#6b4a2a', d: '#4a301a' });          // кожанка
  if (p >= 5) Object.assign(swap, { h: '#2a2a30', i: '#4a4a58' });          // чёрная шапка
  if (p >= 10) Object.assign(swap, { c: '#4a2e6a', d: '#2e1a46' });         // фиолетовый пиджак
  return swap;
}
const WORKER_SWAP = { h: '#5a3a8a', i: '#8a6ac8', c: '#5a5e66', d: '#3a3e46' };
// У каждой точки свой работяга: во дворе — Колян, дальше — разные мужики из бригады
const WORKER_LOOKS = [
  null,
  { h: '#6a6a2a', i: '#8a8a3a', c: '#6a3a2a', d: '#4a2618', g: '#3a2a1a', f: '#4a3a2a' },
  { h: '#2a2a2a', i: '#e8e8e0', c: '#3a5a5a', d: '#243c3c', g: '#7a7a72', f: '#9a9a90' },
  { h: '#8a2a6a', i: '#b04a8a', c: '#5a5e66', d: '#3a3e46', g: '#5a4030', f: '#6a5040' },
  { h: '#d89868', i: '#5a4030', c: '#2a4a2a', d: '#1a321a', g: '#5a4030', f: '#6a5040' },
  { h: '#c87a2a', i: '#e8a050', c: '#4a4a6a', d: '#30304a', g: '#c0c0b8', f: '#e0e0d8' },
  { h: '#3a6a3a', i: '#5a8a5a', c: '#7a6a5a', d: '#5a4a3a', g: '#3a2a1a', f: '#4a3a2a' },
  { h: '#1e2a4a', i: '#2e3e6a', c: '#6a6a72', d: '#4a4a52', g: '#9a9a90', f: '#b8b8b0' },
  { h: '#5a3a8a', i: '#8a6ac8', c: '#5a5e66', d: '#3a3e46' },
];
function workerLook(i) {
  return i === 0 ? CREW_LOOK.kolyan : (WORKER_LOOKS[i] || WORKER_SWAP);
}

function drawDigScene(ctx, w, h, t, dt, scene) {
  const loc = LOCATIONS[G.ui.locView];
  const look = LOC_LOOK[loc.key] || LOC_LOOK.yard;
  const ls = G.run.locs[loc.key];
  const d = nightness();
  const seed = 1000 + G.ui.locView * 77;
  const gy = h - 40;

  drawSky(ctx, w, gy, d, seed);
  bgFar(ctx, w, gy, d, seededRandom(seed + 3), 54);
  look.bg(ctx, w, gy, d, seededRandom(seed));
  drawGround(ctx, w, gy, h, look.ground, d, seed);
  if (look.lamp) drawLamp(ctx, 10, h - 10, d);

  const px = Math.round(w * 0.62);
  const groundY = h - 10;
  // тени под кучей и героем
  ctx.fillStyle = 'rgba(0,0,0,0.25)';
  ctx.fillRect(px - 26, groundY - 1, 52, 3);
  const frac = ls.unlocked ? ls.stock / loc.stock : 0.8;
  const richness = G.ui.locView / (LOCATIONS.length - 1);
  let pileTop;
  if (look.dumpster) {
    const top = drawDumpster(ctx, px, groundY, d);
    drawPile(ctx, px, top + 1, 30, 9, frac, seed, d, richness);
    pileTop = top - Math.round(9 * frac);
  } else {
    drawPile(ctx, px, groundY, 46, 20, Math.max(frac, 0.08), seed, d, richness);
    pileTop = groundY - Math.round(20 * frac);
  }
  scene.state.pile = { x: px, y: pileTop };

  if (ls.unlocked && G.run.activeLoc === loc.key) {
    // герой и мешок
    const st = scene.state;
    st.anim = Math.max(0, (st.anim || 0) - dt);
    let frame = Math.floor(t / 700) % 2 ? 'heroIdle' : 'heroIdle2';
    if (st.anim > 0) frame = st.anim > 260 ? 'heroDig1' : 'heroDig2';
    const hx = px - 36, hy = groundY - 26;
    st.hero = { x: hx + 9, y: hy };
    // иногда герой что-то бормочет
    st.talkIn = (st.talkIn == null ? 15000 : st.talkIn) - dt;
    if (st.talkIn <= 0) { st.talkIn = 35000 + Math.random() * 40000; heroSay(pickRandom(idleLines())); }
    ctx.fillStyle = 'rgba(0,0,0,0.25)';
    ctx.fillRect(hx + 3, groundY - 1, 14, 2);
    const sackFill = Math.min(1, totalJunk() / capMax());
    st.sackBump = Math.max(0, (st.sackBump || 0) - dt);
    // чем больше склад, тем больше полных мешков стоит позади
    const extra = Math.min(3, Math.floor((lv('cap') - 1) / 6));
    for (let k = extra; k >= 1; k--) drawSack(ctx, hx - 12 - k * 7, groundY - (k % 2), 0.55, d, 0);
    st.sack = drawSack(ctx, hx - 12, groundY, sackFill, d, st.sackBump);
    drawSprite(ctx, frame, hx, hy, { swap: heroSwap() });
    // золотая цепь с 3-го престижа и амулет на груди
    if (G.meta.prestige >= 3) { dot(ctx, hx + 9, hy + 11, '#f5d060'); dot(ctx, hx + 10, hy + 12, '#f5d060'); dot(ctx, hx + 11, hy + 11, '#f5d060'); }
    const am = G.meta.equipped ? amuletDef(G.meta.equipped) : null;
    if (am) { dot(ctx, hx + 10, hy + 13, am.color); dot(ctx, hx + 10, hy + 14, darken(am.color, 0.3)); }
  }
  if (ls.unlocked && G.meta.autoDig[loc.key]) {
    // работяга копает с другой стороны
    const wf = Math.floor(t / 320) % 3;
    drawSprite(ctx, wf === 0 ? 'heroDig1' : wf === 1 ? 'heroDig2' : 'heroIdle', px + 12, groundY - 26, { swap: workerLook(G.ui.locView) }, true);
  }
  if (!(ls.unlocked && G.run.activeLoc === loc.key)) scene.state.hero = null;
  if (ls.unlocked) drawStoryActors(ctx, scene, w, groundY, px, dt, t);
  drawCat(ctx, scene, w, groundY + 2, dt);
  if (!ls.unlocked) {
    ctx.fillStyle = 'rgba(6,8,12,0.55)';
    ctx.fillRect(0, 0, w, h);
  }
  drawWeather(ctx, scene, w, h, dt);
}

/** Герой нашёл предмет: анимация и полёт находки в мешок. */
function sceneOnFind(itemKey, isDouble) {
  if (!digScene || currentTab !== 'dig') return;
  const sc = digScene, st = sc.state;
  st.anim = 480;
  const it = ITEMS[itemKey];
  const from = st.pile || { x: sc.w * 0.6, y: 60 };
  const to = st.sack || { x: sc.w * 0.3, y: 80 };
  const n = isDouble ? 2 : 1;
  for (let i = 0; i < n; i++) {
    sc.fx.push({
      kind: 'fly', spr: itemKey, tier: it.tier, age: -i * 120, dur: it.tier === 'lg' ? 900 : 560,
      x0: from.x - 7, y0: from.y - 10, x1: to.x - 7, y1: to.y - 10, arc: it.tier === 'lg' ? 36 : 24,
      onLand: () => { st.sackBump = 120; addSparks(sc, to.x, to.y, '#c8b080', 4, 0.03); },
    });
  }
  addSparks(sc, from.x, from.y, '#8a8070', 6, 0.05);
  if (it.tier === 'rp') addSparks(sc, from.x, from.y - 6, TIER_COLOR.rp, 14, 0.08);
  if (it.tier === 'lg') {
    sc.flash = 1;
    sc.shake = 500;
    addSparks(sc, from.x, from.y - 6, TIER_COLOR.lg, 30, 0.1);
    replayAnim('digSceneWrap', 'legend-pop', 900);
  }
  if (it.tier === 'lg') heroSay(pickRandom(['Ого!', 'Вот это да!', 'Живём!', 'Это я удачно зашёл']), 2400);
  else if (it.tier === 'rp' && Math.random() < 0.5) heroSay(pickRandom(['Неплохо', 'О, полезное', 'В хозяйстве пригодится']));
  const wrap = el('digSceneWrap');
  floatText(wrap, from.x * PX, (from.y - 16) * PX, isDouble ? '×2' : '+1', TIER_COLOR[it.tier]);
}

// ===== Сцена «Кислота»: сарай с ваннами =====

let acidScene = null;
const ACID_H = 72;

function drawPlanks(ctx, w, h, base) {
  rect(ctx, 0, 0, w, h, base);
  for (let x = 0; x < w; x += 9) {
    rect(ctx, x, 0, 1, h, darken(base, 0.35));
    for (let y = 3; y < h; y += 17) dot(ctx, x + 4, y + (x % 3), darken(base, 0.5));
  }
  for (let i = 0; i < w; i += 5) dot(ctx, i + 2, (i * 13) % h, lighten(base, 0.08));
}

/** Маленькое окно со временем суток. */
function drawWindowSmall(ctx, x, y, d) {
  rect(ctx, x - 1, y - 1, 18, 14, '#1e140a');
  rect(ctx, x, y, 16, 12, mixColor(SKY_DAY[1], SKY_NIGHT[1], d));
  rect(ctx, x, y + 8, 16, 4, mixColor(SKY_DAY[2], SKY_NIGHT[2], d));
  if (d > 0.5) { dot(ctx, x + 3, y + 2, '#e8e4c8'); dot(ctx, x + 11, y + 4, '#ffffff'); }
  if (weatherNow() === 'rain') for (let i = 0; i < 6; i++) dot(ctx, x + (i * 5 + Math.floor(performance.now() / 60)) % 16, y + (i * 7 + Math.floor(performance.now() / 30)) % 12, 'rgba(170,200,230,0.7)');
  rect(ctx, x + 7, y, 2, 12, '#2a1c10');
  rect(ctx, x, y + 5, 16, 2, '#2a1c10');
}

/** Мягкое свечение шахматкой вокруг точки. */
function glow(ctx, cx, cy, rx, ry, color, alpha) {
  for (let y = -ry; y <= ry; y++) {
    for (let x = -rx; x <= rx; x++) {
      const k = (x * x) / (rx * rx) + (y * y) / (ry * ry);
      if (k > 1) continue;
      if (k > 0.5 && (x + y) % 2) continue;
      dot(ctx, cx + x, cy + y, `rgba(${color},${alpha * (1 - k * 0.6)})`);
    }
  }
}

function drawAcidScene(ctx, w, h, t, dt, scene) {
  const d = nightness();
  drawPlanks(ctx, w, h, '#4a3420');
  const floorY = h - 10;
  rect(ctx, 0, floorY, w, 10, '#2e2c28');
  rect(ctx, 0, floorY, w, 1, '#4a4842');
  for (let x = 3; x < w; x += 11) dot(ctx, x, floorY + 4 + (x % 4), '#24221e');
  drawWindowSmall(ctx, w - 40, 9, d);
  // полка с бутылками
  rect(ctx, 4, 16, 32, 2, '#2a1c10');
  ['#6a9a3a', '#3a5a8a', '#8a3a3a', '#c8c8b0'].forEach((c, i) => {
    rect(ctx, 7 + i * 7, 9, 4, 7, c); rect(ctx, 8 + i * 7, 7, 2, 2, darken(c, 0.3)); dot(ctx, 8 + i * 7, 10, lighten(c, 0.4));
  });
  // противогаз на гвозде
  rect(ctx, 44, 10, 1, 2, '#1a1a1a');
  rect(ctx, 41, 12, 7, 6, '#3a4a3a'); dot(ctx, 42, 14, '#a8c8d0'); dot(ctx, 46, 14, '#a8c8d0'); rect(ctx, 43, 18, 3, 3, '#2a3a2a');
  // лампочка
  const lx = Math.floor(w / 2);
  rect(ctx, lx, 0, 1, 7, '#1a1a1a');
  rect(ctx, lx - 1, 7, 3, 3, '#ffe9a0');
  glow(ctx, lx, 9, 14, 9, '255,230,150', 0.14);

  const tubs = G.run.acid.slice(0, 3);
  // вид ванны по уровню «Кислота почище»: ржавая → пластиковая → стальная
  const tier = lv('acid') >= 10 ? 2 : lv('acid') >= 5 ? 1 : 0;
  const TUB = [
    { rim: '#f4f6f0', body: '#d8dcd4', top: '#b8bcb4', side: '#a8aca4', bot: '#a0a49c', leg: '#3a3a3a' },
    { rim: '#6aaae8', body: '#3a7ac8', top: '#2a5a98', side: '#2a5a98', bot: '#22487a', leg: '#2a2a30' },
    { rim: '#eef4f8', body: '#a8b4bc', top: '#8a96a0', side: '#7a8690', bot: '#6a7680', leg: '#8a96a0' },
  ][tier];
  const tw = tubs.length > 2 ? 34 : 42;
  const area = w - 34;   // справа — бочка и канистра
  const gap = Math.max(4, Math.floor((area - tubs.length * tw) / (tubs.length + 1)));
  let x = gap;
  const st = scene.state;
  st.bubbles = st.bubbles || [];
  st.steam = st.steam || [];
  tubs.forEach((v, i) => {
    const ty = floorY - 19;
    const p = v.active ? v.progress / v.duration : 0;
    const liquid = v.active ? mixColor('#6a7a2a', '#b0f848', p) : '#3e4a2a';
    if (v.active) glow(ctx, x + tw / 2, ty + 4, tw / 2 + 8, 12, '170,240,80', 0.16);
    // ванна на ножках: бортик, жидкость, бок
    rect(ctx, x - 1, ty - 1, tw + 2, 18, '#1e1e1e');
    rect(ctx, x, ty, tw, 3, TUB.rim);
    rect(ctx, x + 2, ty + 1, tw - 4, 2, liquid);
    if (v.active) {
      const sx = x + 3 + Math.floor((t / 80 + i * 7) % (tw - 7));
      rect(ctx, sx, ty + 1, 2, 1, lighten(liquid, 0.5));
    }
    rect(ctx, x, ty + 3, tw, 13, TUB.body);
    rect(ctx, x, ty + 3, tw, 1, TUB.top);
    rect(ctx, x + tw - 4, ty + 4, 4, 12, TUB.side);
    rect(ctx, x + 1, ty + 15, tw - 2, 1, TUB.bot);
    if (tier === 0) {
      for (let k = 4; k < tw - 4; k += 9) dot(ctx, x + k, ty + 8 + (k % 3), '#c0b090');   // ржавые пятна
    } else if (tier === 1) {
      rect(ctx, x + 4, ty + 7, 7, 5, '#e8c83a');                                         // наклейка «опасно»
      dot(ctx, x + 7, ty + 8, '#1a1a1a'); dot(ctx, x + 7, ty + 10, '#1a1a1a');
      dot(ctx, x + 2, ty + 5, lighten(TUB.body, 0.3));
    } else {
      for (let k = 2; k < tw - 2; k += 5) { dot(ctx, x + k, ty + 4, '#5a6670'); dot(ctx, x + k, ty + 14, '#5a6670'); }   // заклёпки
      rect(ctx, x + 4, ty + 7, 5, 5, '#2a2e34'); rect(ctx, x + 5, ty + 8, 3, 3, '#f2f4ea');                            // манометр
      dot(ctx, x + 6 + (v.active ? 1 : 0), ty + 9, '#c8403c');
      rect(ctx, x + tw - 3, ty - 6, 2, 6, '#7a8690');                                                                   // трубка
    }
    rect(ctx, x + 2, floorY - 3, 3, 3, TUB.leg); rect(ctx, x + tw - 5, floorY - 3, 3, 3, TUB.leg);
    if (v.active) {
      if (Math.random() < dt / 70) st.bubbles.push({ x: x + 3 + Math.random() * (tw - 7), y: ty + 1, age: 0, life: 260 + Math.random() * 200, c: liquid });
      if (Math.random() < dt / 160) st.steam.push({ x: x + 4 + Math.random() * (tw - 10), y: ty - 2, age: 0, life: 1200 + Math.random() * 800 });
    }
    x += tw + gap;
  });
  // пузыри: растут и лопаются брызгами
  st.bubbles = st.bubbles.filter(b => {
    b.age += dt;
    if (b.age > b.life) return false;
    const k = b.age / b.life;
    if (k < 0.75) rect(ctx, b.x, b.y - (k > 0.4 ? 1 : 0), k > 0.4 ? 2 : 1, k > 0.4 ? 2 : 1, lighten(b.c, 0.45));
    else { dot(ctx, b.x - 1, b.y - 2, lighten(b.c, 0.6)); dot(ctx, b.x + 2, b.y - 2, lighten(b.c, 0.6)); dot(ctx, b.x + 0.5, b.y - 3, lighten(b.c, 0.6)); }
    return true;
  });
  // пар: облачка поднимаются и расплываются
  st.steam = st.steam.filter(s => {
    s.age += dt;
    if (s.age > s.life) return false;
    const k = s.age / s.life;
    const size = 2 + Math.floor(k * 3);
    ctx.globalAlpha = 0.45 * (1 - k);
    rect(ctx, s.x + Math.sin(s.age / 300) * 2, s.y - k * 26, size + 1, size, '#d8f0c0');
    ctx.globalAlpha = 1;
    return true;
  });
  // бочка с кислотой и канистра с раствором
  const bx = w - 30, by = floorY - 18;
  rect(ctx, bx - 1, by - 1, 14, 19, '#0e1a2a');
  rect(ctx, bx, by, 12, 18, '#2a5a9a');
  rect(ctx, bx, by + 3, 12, 1, '#3a6aaa'); rect(ctx, bx, by + 13, 12, 1, '#3a6aaa');
  rect(ctx, bx + 3, by + 6, 6, 5, '#e8c020'); dot(ctx, bx + 5, by + 8, '#1a1a1a'); dot(ctx, bx + 6, by + 8, '#1a1a1a');
  const cx = w - 15, cy = floorY - 14;
  rect(ctx, cx - 1, cy - 1, 12, 15, '#1a1a10');
  rect(ctx, cx, cy, 10, 14, '#c8a020');
  rect(ctx, cx, cy, 10, 1, '#f0d050');
  rect(ctx, cx + 6, cy - 3, 3, 3, '#8a7010');
  const sol = Math.min(1, G.run.solution / 2);
  rect(ctx, cx + 2, cy + 13 - Math.round(sol * 10), 2, Math.round(sol * 10), '#a8f040');
}

// ===== Сцена «Печь»: бочки-буржуйки =====

let fireScene = null;
const FIRE_H = 72;

function drawBricks(ctx, w, h, base) {
  rect(ctx, 0, 0, w, h, base);
  const mortar = darken(base, 0.45);
  for (let y = 0; y < h; y += 5) {
    rect(ctx, 0, y, w, 1, mortar);
    for (let x = (y / 5) % 2 ? 0 : 5; x < w; x += 10) rect(ctx, x, y, 1, 5, mortar);
  }
  for (let i = 0; i < w; i += 7) dot(ctx, i + 3, (i * 11) % h, lighten(base, 0.12));
}

function drawFireScene(ctx, w, h, t, dt, scene) {
  drawBricks(ctx, w, h, '#5a2e22');
  const floorY = h - 10;
  rect(ctx, 0, floorY, w, 10, '#2a2622');
  rect(ctx, 0, floorY, w, 1, '#4a4440');
  const st = scene.state;
  st.sparks = st.sparks || [];
  const stoves = G.run.fire.slice(0, 3);
  // вид печи по уровню «Печь помощнее»: бочка → кирпичная → заводская
  const tier = lv('fire') >= 10 ? 2 : lv('fire') >= 5 ? 1 : 0;
  const STOVE = [
    { body: '#3a3a40', band: '#5a5a62', hl: '#5a5a62', sh: '#2a2a30' },
    { body: '#8a4a32', band: '#5a2e1e', hl: '#a8603e', sh: '#6a3624' },
    { body: '#4a5460', band: '#e8b83a', hl: '#6a7480', sh: '#343c46' },
  ][tier];
  const bw = stoves.length > 2 ? 22 : 26;
  const area = w - 38;
  const gap = Math.max(6, Math.floor((area - stoves.length * bw) / (stoves.length + 1)));
  let x = gap;
  stoves.forEach((v, i) => {
    const bh = 30, by = floorY - bh;
    const flick = 0.85 + Math.sin(t / 90 + i) * 0.1 + Math.random() * 0.05;
    if (v.active) {
      glow(ctx, x + bw / 2, by + 16, bw + 6, 20, '255,140,40', 0.13 * flick);
      glow(ctx, x + bw / 2, floorY + 2, bw, 4, '255,150,60', 0.2 * flick);
    }
    // труба в потолок
    rect(ctx, x + bw - 8, 0, 4, by, '#2a2a2e');
    rect(ctx, x + bw - 8, 0, 1, by, '#4a4a50');
    rect(ctx, x + bw - 9, Math.floor(by / 2), 6, 2, '#3a3a40');
    // бочка
    rect(ctx, x - 1, by - 1, bw + 2, bh + 1, '#101012');
    rect(ctx, x, by, bw, bh, STOVE.body);
    if (tier === 1) {
      for (let yy = 3; yy < bh; yy += 4) {
        rect(ctx, x, by + yy, bw, 1, STOVE.band);
        for (let xx = (yy / 4) % 2 ? 2 : 5; xx < bw; xx += 6) rect(ctx, x + xx, by + yy - 3, 1, 3, STOVE.band);
      }
    } else if (tier === 2) {
      for (let xx = 0; xx < bw; xx += 4) { rect(ctx, x + xx, by + bh - 4, 2, 3, '#e8b83a'); rect(ctx, x + xx + 2, by + bh - 4, 2, 3, '#1a1a1a'); }
      [2, bw - 4].forEach(xx => { dot(ctx, x + xx, by + 2, '#8a96a0'); dot(ctx, x + xx, by + bh - 7, '#8a96a0'); });
    } else {
      rect(ctx, x, by + 6, bw, 1, STOVE.band); rect(ctx, x, by + bh - 7, bw, 1, STOVE.band);
    }
    rect(ctx, x + 1, by, 2, bh, STOVE.hl);
    rect(ctx, x + bw - 3, by, 2, bh, STOVE.sh);
    // окно с огнём
    const ox = x + 5, oy = by + 11, ow = bw - 10, oh = 9;
    rect(ctx, ox - 1, oy - 1, ow + 2, oh + 2, '#18181a');
    rect(ctx, ox, oy, ow, oh, '#1a0a04');
    for (let fx = 0; fx < ow; fx++) {
      const n = Math.sin(t / 70 + fx * 1.7 + i) + Math.sin(t / 43 + fx * 0.9);
      const fh = v.active ? Math.max(2, Math.round((oh - 1) * (0.6 + n * 0.18))) : 1 + (fx % 3 === 0 ? 1 : 0);
      for (let fy = 0; fy < fh; fy++) {
        const k = fy / Math.max(1, fh);
        const c = v.active ? (k < 0.3 ? '#fff0a0' : k < 0.6 ? '#ffb030' : '#e05a20') : (Math.sin(t / 400 + fx) > 0.3 ? '#a03a10' : '#5a1a08');
        dot(ctx, ox + fx, oy + oh - 1 - fy, c);
      }
    }
    // слиток на бочке и искры
    if (v.active) {
      const p = v.progress / v.duration;
      drawSprite(ctx, 'ingot', x + 3, by - 5);
      if (p > 0.6 && Math.floor(t / 200) % 2) dot(ctx, x + 7, by - 4, '#ffffff');
      if (Math.random() < dt / 120) st.sparks.push({ x: ox + Math.random() * ow, y: oy, vx: (Math.random() - 0.5) * 0.03, vy: -0.03 - Math.random() * 0.03, age: 0, life: 500 + Math.random() * 500 });
    }
    // уголь рядом
    for (let k = 0; k < 7; k++) dot(ctx, x - 5 + (k % 4), floorY - 1 - Math.floor(k / 4), '#1a1a1a');
    x += bw + gap;
  });
  st.sparks = st.sparks.filter(s => {
    s.age += dt; s.x += s.vx * dt; s.y += s.vy * dt;
    if (s.age > s.life) return false;
    dot(ctx, s.x, s.y, s.age < s.life * 0.5 ? '#ffd060' : '#c05020');
    return true;
  });
  // стопка слитков на полу
  const n = Math.min(14, Math.ceil(G.run.ingots / 0.25));
  const sx = w - 32;
  for (let i = 0; i < n; i++) {
    const row = Math.floor(i / 4), col = i % 4;
    drawSprite(ctx, 'ingot', sx + col * 6 + row * 2, floorY - 4 - row * 3);
  }
}

// ===== Сцена «Скупщик»: ларёк =====

let marketScene = null;
const MARKET_H = 60;

function drawMarketScene(ctx, w, h, t, dt, scene) {
  const d = nightness();
  drawSky(ctx, w, 30, d, 4242);
  // стена ларька и козырёк
  rect(ctx, 0, 10, w, h - 10, nightTint('#3a4a5a', d, 0.5));
  rect(ctx, 0, 6, w, 5, nightTint('#e8e0d0', d, 0.4));
  for (let x = 0; x < w; x += 8) rect(ctx, x, 6, 4, 5, nightTint('#d84030', d, 0.4));
  rect(ctx, 0, 11, w, 1, '#101418');
  // окно ларька с тёплым светом
  const wx = 8, wy = 14, ww = w - 16, counterY = h - 12;
  rect(ctx, wx - 1, wy - 1, ww + 2, counterY - wy + 2, '#101418');
  rect(ctx, wx, wy, ww, counterY - wy, '#40321e');
  glow(ctx, Math.floor(w / 2), wy + 8, Math.floor(ww / 2), 14, '255,210,130', 0.12);
  // полки с товаром
  rect(ctx, wx, wy + 9, ww, 1, '#2a2014');
  for (let i = 0; i < Math.floor(ww / 7); i++) {
    const c = ['#c84030', '#3a8a3a', '#d8b030', '#3a6ab8', '#c8c8b8'][i % 5];
    rect(ctx, wx + 2 + i * 7, wy + 3, 4, 6, c);
    dot(ctx, wx + 3 + i * 7, wy + 4, lighten(c, 0.4));
  }
  // скупщик за прилавком
  const bx = Math.round(w / 2 - 9), by = counterY - 15 + (Math.floor(t / 900) % 2);
  drawSprite(ctx, 'buyer', bx, by);
  if (Math.floor(t / 400) % 3) dot(ctx, bx + 15, by + 9, '#ff6020');   // сигарета
  // весы на прилавке
  rect(ctx, w - 30, counterY - 6, 12, 2, '#b8bec8');
  rect(ctx, w - 25, counterY - 4, 2, 4, '#7c8492');
  // прилавок
  rect(ctx, 0, counterY, w, h - counterY, nightTint('#6a4a2a', d, 0.4));
  rect(ctx, 0, counterY, w, 1, nightTint('#9a7040', d, 0.4));
  for (let x = 4; x < w; x += 12) rect(ctx, x, counterY + 3, 1, h - counterY - 3, nightTint('#4a3018', d, 0.4));
  // слитки на прилавке
  const n = Math.min(8, Math.ceil(G.run.ingots / 0.4));
  for (let i = 0; i < n; i++) drawSprite(ctx, 'ingot', 12 + i * 9, counterY - 5);
  drawWeather(ctx, scene, w, h, dt);
}

/** Продажа: монеты подлетают над прилавком и летят в кошелёк. */
function sceneOnSale(hit) {
  if (marketScene && marketScene.w) {
    for (let i = 0; i < (hit ? 18 : 8); i++) {
      marketScene.fx.push({ kind: 'coin', x: marketScene.w / 2 + (Math.random() - 0.5) * 30, y: 40, vx: (Math.random() - 0.5) * 0.08, vy: -0.12 - Math.random() * 0.08, age: 0 });
    }
    if (hit) marketScene.flash = 0.6;
  }
  coinBurst(el('sellBtn'), hit ? 14 : 8);
  const box = el('marketCanvas') && el('marketCanvas').parentElement;
  if (box && marketScene.w) {
    bubble(box, marketScene.w / 2 * PX, 18, pickRandom(hit ? ['Хорош, по рукам', 'Отличный металл', 'Заходи ещё'] : ['Ну, сам виноват', 'Больше не дам', 'Бери, пока дают']), 2200);
  }
}

// ===== Реплики =====

function idleLines() {
  const w = weatherNow(), d = nightness();
  if (w === 'rain') return ['Опять дождь…', 'Промок до нитки', 'Хорошо, что не снег'];
  if (w === 'snow') return ['Ну и холодрыга', 'Руки мёрзнут', 'Снег — к деньгам'];
  if (d > 0.6) return ['Ночью тут спокойнее', 'Где-то тут было…', 'Темно, хоть глаз выколи'];
  return ['Эх, жизнь…', 'Ещё чуть-чуть', 'Где-то тут было…', 'Золото само себя не найдёт'];
}

/** Облачко с текстом над точкой (x, y — в CSS-пикселях внутри контейнера). */
function bubble(box, x, y, text, ms = 1800) {
  const old = box.querySelector('.scene-bubble');
  if (old) old.remove();
  const b = make('div', 'scene-bubble', text);
  b.style.left = x + 'px';
  b.style.top = y + 'px';
  box.appendChild(b);
  setTimeout(() => b.remove(), ms);
}

/** Герой говорит (если он на экране). */
function heroSay(text, ms) {
  const st = digScene && digScene.state;
  if (!st || !st.hero || currentTab !== 'dig') return;
  bubble(el('digSceneWrap'), st.hero.x * PX, st.hero.y * PX - 6, text, ms);
}

// ===== Главное меню: ночной двор с костром =====

let menuScene = null;

function drawMenuScene(ctx, w, h, t, dt, scene) {
  const d = Math.max(0.85, nightness());
  const gy = Math.floor(h * 0.7);
  drawSky(ctx, w, gy, d, 777);
  bgFar(ctx, w, gy, d, seededRandom(778), Math.floor(h * 0.3));
  const rnd = seededRandom(777);
  bgYard(ctx, w, gy, d, rnd);
  drawGround(ctx, w, gy, h, '#3a3b36', d, 777);
  drawLamp(ctx, 12, gy + 34, d);
  // бочка с костром
  const bx = Math.floor(w * 0.58), by = gy + 22;
  for (let k = 0; k < 120; k++) {
    const a = k / 120 * Math.PI * 2, r = 10 + (k % 6) * 4;
    dot(ctx, bx + 7 + Math.cos(a) * r, by + Math.sin(a) * r * 0.6, 'rgba(255,140,40,0.10)');
  }
  rect(ctx, bx - 1, by - 1, 16, 15, '#101010');
  rect(ctx, bx, by, 14, 14, '#4a3a30');
  rect(ctx, bx, by + 4, 14, 1, '#6a5a4a'); rect(ctx, bx, by + 10, 14, 1, '#6a5a4a');
  for (let fx = 0; fx < 12; fx++) {
    const n = Math.sin(t / 80 + fx * 1.3) + Math.sin(t / 51 + fx * 0.7);
    const fh = Math.max(2, Math.round(7 + n * 2.5));
    for (let fy = 0; fy < fh; fy++) {
      const k = fy / fh;
      dot(ctx, bx + 1 + fx, by - 1 - fy, k < 0.3 ? '#fff0a0' : k < 0.65 ? '#ffb030' : '#e05a20');
    }
  }
  const st = scene.state;
  st.sparks = st.sparks || [];
  if (Math.random() < dt / 120) st.sparks.push({ x: bx + 3 + Math.random() * 8, y: by - 8, age: 0, life: 900 + Math.random() * 600 });
  st.sparks = st.sparks.filter(s => {
    s.age += dt; s.y -= dt * 0.025; s.x += Math.sin(s.age / 200) * 0.1;
    if (s.age > s.life) return false;
    dot(ctx, s.x, s.y, s.age < s.life * 0.5 ? '#ffd060' : '#c05020');
    return true;
  });
  // герой греет руки
  drawCampCrew(ctx, bx, by, t, campCrewNow());
  drawWeather(ctx, scene, w, h, dt);
}

// ===== Катсцена престижа =====
// Ночь, с неба сыплются монеты → вспышка → рассвет, герой в новой одёжке.

let cutScene = null;
const cut = { open: false, stop: null, level: 0, canClose: false };

function playPrestigeCut(level, reward) {
  const ov = el('prestCut');
  if (!cutScene) cutScene = new PixelScene(el('cutCanvas'), 400, drawCutScene);
  Object.assign(cut, { open: true, level, canClose: false });
  cutScene.h = Math.ceil(window.innerHeight / PX);
  cutScene.w = 0;
  cutScene.t = 0;
  cutScene.last = 0;
  cutScene.fx = [];
  cutScene.state = { flashed: false };
  setText('cutBig', `ПРЕСТИЖ ${level}`);
  setText('cutSub', `+${reward} очков престижа · бонус +${parseFloat(prestigeBonusPct().toFixed(2))}%`);
  ov.classList.remove('phase2', 'phase3');
  ov.classList.add('show');
  if (cut.stop) cut.stop();
  cut.stop = frameLoop(() => {
    cutScene.frame();
    const t = cutScene.t;
    if (t > 1900) ov.classList.add('phase2');
    if (t > 3200) { ov.classList.add('phase3'); cut.canClose = true; }
    if (t > 9000) closePrestigeCut();
  });
}

function closePrestigeCut() {
  if (!cut.open) return;
  cut.open = false;
  if (cut.stop) { cut.stop(); cut.stop = null; }
  el('prestCut').classList.remove('show', 'phase2', 'phase3');
}

function drawCutScene(ctx, w, h, t, dt, scene) {
  const st = scene.state;
  // ночь → рассвет после вспышки
  const d = t < 1800 ? 1 : Math.max(0.1, 1 - (t - 1800) / 1600);
  const gy = Math.floor(h * 0.66);
  drawSky(ctx, w, gy, d, 999);
  bgFar(ctx, w, gy, d, seededRandom(998), Math.floor(h * 0.28));
  bgYard(ctx, w, gy, d, seededRandom(999));
  drawGround(ctx, w, gy, h, '#3a3b36', d, 999);
  const cx = Math.floor(w / 2);
  const feet = gy + 44;
  // монетный дождь до вспышки
  if (t < 1800 && Math.random() < dt / 30) {
    scene.fx.push({ kind: 'coin', x: Math.random() * w, y: -8, vx: (Math.random() - 0.5) * 0.02, vy: 0.04 + Math.random() * 0.05, age: 0 });
  }
  // куча монет растёт у ног
  const pile = Math.min(1, t / 1800);
  const prnd = seededRandom(55);
  for (let i = 0; i < Math.round(pile * 24); i++) {
    const row = Math.floor(i / 6), a = prnd();
    drawSprite(ctx, 'coin', cx - 34 + row * 4 + Math.round(a * (60 - row * 8)), feet - 6 - row * 3);
  }
  if (t >= 1800 && !st.flashed) {
    st.flashed = true;
    scene.flash = 1;
    scene.shake = 350;
    for (let i = 0; i < 40; i++) {
      const a = Math.random() * Math.PI * 2, v = 0.04 + Math.random() * 0.08;
      scene.fx.push({ kind: 'spark', x: cx, y: feet - 28, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 0.03, life: 700 + Math.random() * 600, age: 0, color: ['#f8d060', '#ffffff', '#c09af0'][i % 3] });
    }
  }
  // сияние и звёзды вокруг героя после вспышки
  if (t > 1800) {
    glow(ctx, cx, feet - 26, 46, 36, '255,220,140', 0.16);
    for (let i = 0; i < 6; i++) {
      const a = t / 900 + i * Math.PI * 2 / 6;
      drawSprite(ctx, i % 2 ? 'star' : 'pstar', cx - 4 + Math.round(Math.cos(a) * 38), feet - 30 + Math.round(Math.sin(a) * 14));
    }
  }
  // герой: до вспышки — старая одёжка, после — новая, и подпрыгивает от радости
  const jump = t > 1800 && t < 3000 ? Math.round(Math.abs(Math.sin((t - 1800) / 160)) * 5) : 0;
  const swap = heroSwap(t < 1800 ? cut.level - 1 : cut.level);
  const hero = spriteCanvas(Math.floor(t / 700) % 2 ? 'heroIdle' : 'heroIdle2', { swap });
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(hero, cx - hero.width, feet - hero.height * 2 - jump * 2, hero.width * 2, hero.height * 2);
}

// ===== Создание сцен и кадр =====

function buildScenes() {
  digScene = new PixelScene(el('digCanvas'), DIG_H, drawDigScene);
  acidScene = new PixelScene(el('acidCanvas'), ACID_H, drawAcidScene);
  fireScene = new PixelScene(el('fireCanvas'), FIRE_H, drawFireScene);
  marketScene = new PixelScene(el('marketCanvas'), MARKET_H, drawMarketScene);
  menuScene = new PixelScene(el('menuCanvas'), 400, drawMenuScene);
}

/** Меню: высота сцены по высоте экрана. */
function renderMenuScene() {
  if (!menuScene) return;
  const hh = Math.ceil(window.innerHeight / PX);
  if (menuScene.h !== hh) { menuScene.h = hh; menuScene.w = 0; }
  menuScene.frame();
}
