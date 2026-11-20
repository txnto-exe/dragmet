'use strict';
// Мини-игры: «Растворение» (перед кислотой), «Выплавка» (перед печью)
// и стоп-игра «Контроль цены» (при продаже слитков).

/** Покадровый цикл: fn(dtСекунд) вызывается каждый кадр, пока не вызван stop(). */
function frameLoop(fn) {
  let last = 0, raf = 0, stopped = false;
  const step = ts => {
    if (stopped) return;
    const dt = last ? Math.min((ts - last) / 1000, 0.1) : 0;
    last = ts;
    fn(dt);
    if (!stopped) raf = requestAnimationFrame(step);
  };
  raf = requestAnimationFrame(step);
  return () => { stopped = true; cancelAnimationFrame(raf); };
}

/** Кнопка, которую держат пальцем: onDown при нажатии, onUp при отпускании. */
function bindHold(button, onDown, onUp) {
  button.addEventListener('pointerdown', e => {
    e.preventDefault();
    try { button.setPointerCapture(e.pointerId); } catch (er) { /* не страшно */ }
    onDown();
  });
  button.addEventListener('pointerup', e => { e.preventDefault(); onUp(); });
  button.addEventListener('pointercancel', onUp);
}

// Открытая сейчас мини-игра «Растворение» или «Выплавка» (null — никакой)
let activeMinigame = null;

function isMinigameOpen() {
  return activeMinigame !== null;
}

function setMgResult(id, text, kind) {
  const r = el(id);
  r.textContent = text;
  r.className = 'mg-result' + (kind ? ' ' + kind : '');
}

// ===== «Растворение»: три колбы, зажми и отпусти уровень в зоне =====

const FLASKS = [
  { label: 'Вода', speed: 40, c: '#6dc4e8', d: '#3a6ec8' },
  { label: 'Кислота', speed: 55, c: '#c8ee68', d: '#3f8a2a' },
  { label: 'Щёлочь', speed: 70, c: '#c09af0', d: '#6a4a9a' },
];
const flaskEls = [];
const FLASK_W = 40, FLASK_H = 94;

function buildAcidMiniGame() {
  const box = el('amgFlasks');
  FLASKS.forEach((fl, i) => {
    const wrap = make('div', 'amg-flask-wrap');
    const flask = make('div', 'amg-flask');
    const cv = make('canvas', 'amg-cv');
    cv.width = FLASK_W;
    cv.height = FLASK_H;
    cv.style.width = FLASK_W * PX + 'px';
    cv.style.height = FLASK_H * PX + 'px';
    flask.appendChild(cv);
    const btn = make('button', 'amg-btn', 'Держи');
    btn.type = 'button';
    wrap.append(flask, make('div', 'amg-label', fl.label), btn);
    box.appendChild(wrap);
    flaskEls.push({ flask, cv, ctx: cv.getContext('2d'), btn, bubbles: [] });
    bindHold(btn, () => acidPourStart(i), () => acidPourStop(i));
  });
}

function openAcidMiniGame(onWin) {
  const st = {
    kind: 'acid', onWin, gameOver: false, pouring: -1,
    flasks: FLASKS.map(() => {
      const w = 16 + Math.random() * 6;
      const start = 12 + Math.random() * (100 - 12 - w - 12);
      return { pos: 0, dir: 1, done: false, zone: { start, end: start + w } };
    }),
  };
  activeMinigame = st;
  st.flasks.forEach((f, i) => {
    const e = flaskEls[i];
    e.flask.classList.remove('ok', 'fail');
    e.btn.classList.remove('done', 'pouring');
    e.btn.textContent = 'Держи';
    e.bubbles = [];
    drawFlask(i);
  });
  setMgResult('amgResult', '');
  el('acidMgOverlay').classList.add('show');
  st.stop = frameLoop(dt => {
    if (st.pouring < 0 || st.gameOver) return;
    const f = st.flasks[st.pouring];
    f.pos += f.dir * FLASKS[st.pouring].speed * dt;
    if (f.pos >= 100) { f.pos = 100; f.dir = -1; }
    if (f.pos <= 0) { f.pos = 0; f.dir = 1; }
    drawFlask(st.pouring);
  });
}

/** Нарисовать колбу i: стекло, жидкость до текущего уровня, зону, струю и пузыри. */
function drawFlask(i) {
  const e = flaskEls[i], fl = FLASKS[i], ctx = e.ctx;
  const st = activeMinigame && activeMinigame.kind === 'acid' ? activeMinigame : null;
  const f = st ? st.flasks[i] : { pos: 0, zone: { start: 40, end: 60 } };
  const W = FLASK_W, H = FLASK_H, cx = W / 2;
  const ok = e.flask.classList.contains('ok'), fail = e.flask.classList.contains('fail');
  const pouring = st && st.pouring === i;
  // полуширина стекла на строке y: горлышко → плечи → тулово → скруглённое дно
  const hw = y => (y < 16 ? 5 : y < 26 ? Math.round(5 + 10 * (y - 16) / 10) : y > H - 4 ? 14 - (y - (H - 4)) : 15);
  const top = 28, bot = H - 4;
  const yOf = p => Math.round(bot - (bot - top) * p / 100);
  const surf = yOf(f.pos);
  const zTop = yOf(f.zone.end), zBot = yOf(f.zone.start);
  const edge = fail ? '#e05050' : ok ? '#c8ee68' : '#a8c0c8';
  ctx.clearRect(0, 0, W, H);

  for (let y = 4; y < H - 1; y++) {
    const h = hw(y), x0 = cx - h, x1 = cx + h - 1;
    // стекло
    rect(ctx, x0, y, h * 2, 1, 'rgba(190,225,235,0.10)');
    // жидкость
    if (y >= surf && y >= 6) {
      const c = y === surf ? lighten(fl.c, 0.45) : y > bot - 3 ? fl.d : fl.c;
      rect(ctx, x0, y, h * 2, 1, c);
      dot(ctx, x0, y, fl.d);
      dot(ctx, x1, y, fl.d);
    }
    // зона поверх жидкости
    if (y >= zTop && y <= zBot) {
      const zc = ok ? 'rgba(200,238,104,0.55)' : fail ? 'rgba(224,80,80,0.4)' : 'rgba(255,255,240,0.16)';
      rect(ctx, x0, y, x1 - x0 + 1, 1, zc);
    }
    // контур стекла
    dot(ctx, x0 - 1, y, edge);
    dot(ctx, x1 + 1, y, edge);
    // блик
    if (y > 8 && y < H - 8 && y !== surf) dot(ctx, x0 + 2, y, 'rgba(255,255,255,0.28)');
  }
  // дно и горлышко
  rect(ctx, cx - 11, H - 1, 22, 1, edge);
  rect(ctx, cx - 7, 2, 14, 2, edge);
  rect(ctx, cx - 6, 3, 12, 1, 'rgba(255,255,255,0.35)');
  // риски шкалы
  for (let p = 10; p < 100; p += 10) dot(ctx, cx + 12, yOf(p), 'rgba(255,255,255,0.35)');
  // стрелки зоны снаружи
  [zTop, zBot].forEach(y => {
    rect(ctx, 0, y, 3, 1, ok ? '#c8ee68' : fail ? '#e05050' : '#e8e0b0');
    rect(ctx, W - 3, y, 3, 1, ok ? '#c8ee68' : fail ? '#e05050' : '#e8e0b0');
  });
  // струя и пузыри, пока льём
  if (pouring) {
    rect(ctx, cx - 1, 0, 2, Math.max(0, surf), fl.c);
    dot(ctx, cx - 1, 0, lighten(fl.c, 0.5));
    if (Math.random() < 0.5) e.bubbles.push({ x: cx - 10 + Math.random() * 20, y: bot - 1 });
  }
  e.bubbles = e.bubbles.filter(b => (b.y -= 0.7) > surf + 1);
  e.bubbles.forEach(b => dot(ctx, b.x, b.y, 'rgba(255,255,255,0.7)'));
}

function acidPourStart(i) {
  const st = activeMinigame;
  if (!st || st.kind !== 'acid' || st.gameOver || st.flasks[i].done || st.pouring >= 0) return;
  st.pouring = i;
  flaskEls[i].btn.classList.add('pouring');
  vibe(10);
}

function acidPourStop(i) {
  const st = activeMinigame;
  if (!st || st.kind !== 'acid' || st.pouring !== i) return;
  st.pouring = -1;
  flaskEls[i].btn.classList.remove('pouring');
  if (st.gameOver) return;

  const f = st.flasks[i];
  if (f.pos < f.zone.start || f.pos > f.zone.end) {
    // Промах — всё заново
    st.gameOver = true;
    flaskEls.forEach((e, k) => { e.flask.classList.add('fail'); drawFlask(k); });
    setMgResult('amgResult', '✕ Промах — попробуй снова', 'fail');
    sndMgFail(); vibe(60);
    setTimeout(() => closeMinigame(st), 800);
    return;
  }
  f.done = true;
  flaskEls[i].flask.classList.add('ok');
  flaskEls[i].btn.classList.add('done');
  flaskEls[i].btn.textContent = '✓';
  drawFlask(i);
  sndMgOk(); vibe(30);
  if (st.flasks.every(x => x.done)) {
    st.gameOver = true;
    setMgResult('amgResult', '✓ Раствор готов', 'ok');
    sndMgWin(); vibe(50);
    setTimeout(() => { if (closeMinigame(st)) st.onWin(); }, 700);
  }
}

// ===== «Выплавка»: одна кнопка-мехи. Держишь — жар растёт, отпустил — падает. =====
// Нужно держать стрелку жара в светлой рамке, пока не наберётся 100% готовности.

const FMG = {
  heatUp: 90,       // разгон жара, пока держишь (ед./с²)
  coolDown: 75,     // остывание, когда отпустил
  maxSpeed: 38,     // предел скорости стрелки (ед./с)
  zoneHalf: 12,     // полуширина рамки (шкала 0–100)
  readySec: 3.5,    // сколько секунд в рамке нужно для 100%
  loseRate: 22,     // сколько % готовности теряется за секунду вне рамки
  failSec: 7,       // сколько секунд всего можно провести вне рамки
};

function buildFireMiniGame() {
  const blow = on => {
    const st = activeMinigame;
    if (!st || st.kind !== 'fire') return;
    if (on && st.gameOver) return;
    st.blowing = on;
    toggleClass('fmgBlow', 'on', on);
    if (on) vibe(8);
  };
  bindHold(el('fmgBlow'), () => blow(true), () => blow(false));
}

function openFireMiniGame(onWin) {
  const st = {
    kind: 'fire', onWin, gameOver: false,
    zone: 45 + Math.random() * 25, zoneT: Math.random() * 10, zoneHalf: FMG.zoneHalf,
    heat: 12, vel: 0, blowing: false,
    ready: 0,        // «Готовность», %
    outsideMs: -2500, // сколько всего пробыл вне рамки (первые 2,5 с на разогрев не считаются)
  };
  st.zoneBase = st.zone;
  setMgResult('fmgResult', '');
  toggleClass('fmgBlow', 'on', false);
  activeMinigame = st;
  el('fireMgOverlay').classList.add('show');
  if (!fireMgScene) fireMgScene = new PixelScene(el('fmgCanvas'), 54, drawFurnace);
  fireMgScene.w = 0;
  drawFireMiniGame(st);
  st.stop = frameLoop(dt => {
    if (st.gameOver) return;
    // рамка медленно плавает туда-сюда
    st.zoneT += dt;
    st.zone = clamp(st.zoneBase + Math.sin(st.zoneT * 0.9) * 12 + Math.sin(st.zoneT * 2.3) * 4, st.zoneHalf + 4, 100 - st.zoneHalf - 4);
    // жар: мехи разгоняют, без них остывает
    st.vel += (st.blowing ? FMG.heatUp : -FMG.coolDown) * dt;
    st.vel = clamp(st.vel, -FMG.maxSpeed, FMG.maxSpeed);
    st.heat += st.vel * dt;
    if (st.heat <= 0) { st.heat = 0; st.vel = Math.max(0, st.vel); }
    if (st.heat >= 100) { st.heat = 100; st.vel = Math.min(0, st.vel); }

    if (Math.abs(st.heat - st.zone) <= st.zoneHalf) {
      st.ready = Math.min(100, st.ready + dt * 100 / FMG.readySec);
    } else {
      st.ready = Math.max(0, st.ready - dt * FMG.loseRate);
      st.outsideMs += dt * 1000;
      if (st.outsideMs >= FMG.failSec * 1000) {
        st.gameOver = true;
        setMgResult('fmgResult', '✕ Металл не взялся — попробуй снова', 'fail');
        sndMgFail(); vibe(60);
        setTimeout(() => closeMinigame(st), 900);
      }
    }
    if (st.ready >= 100 && !st.gameOver) {
      st.gameOver = true;
      setMgResult('fmgResult', '✓ Слиток готов!', 'ok');
      sndMgWin(); vibe(50);
      setTimeout(() => { if (closeMinigame(st)) st.onWin(); }, 700);
    }
    drawFireMiniGame(st);
  });
}

let fireMgScene = null;

function drawFireMiniGame(st) {
  fireMgScene.state.mg = st;
  fireMgScene.frame();
  const inZone = Math.abs(st.heat - st.zone) <= st.zoneHalf;
  setWidth('fmgProgress', st.ready);
  const z = el('fmgZone');
  z.style.left = (st.zone - st.zoneHalf) + '%';
  z.style.width = (st.zoneHalf * 2) + '%';
  toggleClass(z, 'in', inZone);
  el('fmgNeedle').style.left = st.heat + '%';
  setText('fmgPct', Math.floor(st.ready) + '%');
  setText('fmgState', st.gameOver ? (st.ready >= 100 ? 'Готово' : 'Остыло')
    : inZone ? 'Отлично, держи так!' : st.heat < st.zone ? 'Холодно — держи кнопку' : 'Перегрев — отпусти');
}

/** Цвет жара: слева холодно (синий), справа белый накал. */
function heatColor(p) {
  const stops = ['#3a6ec8', '#8a3ac8', '#c8403c', '#e0802a', '#e8b83a', '#f8f0c0'];
  const k = clamp(p, 0, 100) / 100 * (stops.length - 1);
  const i = Math.min(stops.length - 2, Math.floor(k));
  return mixColor(stops[i], stops[i + 1], k - i);
}

/** Сцена мини-игры «Выплавка»: печь, тигель и пламя (шкала жара — отдельно, под сценой). */
function drawFurnace(ctx, w, h, t, dt, scene) {
  const st = scene.state.mg;
  if (!st) return;
  const inZone = Math.abs(st.heat - st.zone) <= st.zoneHalf;
  drawBricks(ctx, w, 54, '#3a2418');
  rect(ctx, 0, 52, w, 2, '#1a0e08');
  // печь
  const fx = Math.round(w / 2 - 26), fw = 52, fy = 8;
  rect(ctx, fx - 1, fy - 1, fw + 2, 46, '#120a06');
  rect(ctx, fx, fy, fw, 44, '#6a6a72');
  for (let y = fy + 4; y < fy + 44; y += 6) rect(ctx, fx, y, fw, 1, '#4c4c54');
  rect(ctx, fx, fy, fw, 1, '#9a9aa2');
  // труба и дым
  rect(ctx, fx + fw - 12, 0, 8, fy, '#4c4c54');
  rect(ctx, fx + fw - 12, 0, 1, fy, '#7a7a82');
  const puff = (t / 40) % 30;
  dot(ctx, fx + fw - 8 + Math.round(Math.sin(t / 300) * 2), Math.round(6 - puff / 5), 'rgba(160,160,160,0.4)');
  // топка
  const mx = fx + 10, mw = fw - 20, my = fy + 14, mh = 26;
  rect(ctx, mx - 1, my - 1, mw + 2, mh + 2, '#1a1410');
  rect(ctx, mx, my, mw, mh, '#0a0604');
  const heat = st.heat;
  const hc = heatColor(heat);
  glow(ctx, mx + mw / 2, my + mh - 2, mw / 2 + 6, 10, hexToRgb(hc).join(','), 0.10 + heat / 500);
  // пламя: выше и светлее от жара
  const flameH = 4 + Math.round(heat / 100 * 16);
  for (let x = 0; x < mw; x++) {
    const hh = Math.max(1, flameH - Math.abs(x - mw / 2) / 3 + Math.round(Math.sin(t / 90 + x * 1.7) * 2));
    for (let y = 0; y < hh; y++) {
      const k = y / hh;
      dot(ctx, mx + x, my + mh - 1 - y, k < 0.35 ? lighten(hc, 0.5) : k < 0.7 ? hc : darken(hc, 0.35));
    }
  }
  // угли
  for (let x = 0; x < mw; x += 2) dot(ctx, mx + x, my + mh - 1, (x + Math.floor(t / 200)) % 3 ? '#e0802a' : '#8a2a10');
  // тигель: нагревается вместе с «Готовностью»
  const cc = st.ready < 50 ? mixColor('#4c5262', '#e0802a', st.ready / 50) : mixColor('#e0802a', '#f8e890', (st.ready - 50) / 50);
  const tx = mx + mw / 2 - 7, ty = my + 2;
  rect(ctx, tx - 1, ty, 16, 1, '#1a1410');
  rect(ctx, tx, ty + 1, 14, 7, cc);
  rect(ctx, tx + 1, ty + 8, 12, 1, darken(cc, 0.3));
  rect(ctx, tx + 1, ty + 1, 12, 1, lighten(cc, 0.4));
  if (inZone && Math.random() < 0.35) scene.fx.push({ kind: 'spark', x: tx + 2 + Math.random() * 10, y: ty, vx: (Math.random() - 0.5) * 0.04, vy: -0.05 - Math.random() * 0.04, age: 0, life: 500, color: '#f8d060' });
  // дверца-заслонка над топкой
  rect(ctx, mx - 2, my - 4, mw + 4, 3, '#2c2c34');
  rect(ctx, mx - 2, my - 4, mw + 4, 1, '#5c5c64');

}

/** Закрыть мини-игру st. Возвращает false, если она уже закрыта (например, начали новую игру). */
function closeMinigame(st) {
  if (activeMinigame !== st) return false;
  st.stop();
  activeMinigame = null;
  el(st.kind === 'acid' ? 'acidMgOverlay' : 'fireMgOverlay').classList.remove('show');
  return true;
}

function closeAnyMinigame() {
  if (activeMinigame) closeMinigame(activeMinigame);
}

// ===== Стоп-игра «Контроль цены» =====

const priceGame = { open: false, running: false, pos: 0, dir: 1, zoneCenter: 50, zoneHalf: 5, secondChanceUsed: false, stop: null, sceneStop: null };
let pgScene = null;

/** Сколько скупщик даёт за грамм, если остановить бегунок в позиции pos. */
function priceAt(pos) {
  const { zoneCenter, zoneHalf } = priceGame;
  const d = Math.abs(pos - zoneCenter);
  if (d <= zoneHalf) return BAL.priceMax;
  const maxDist = Math.max(zoneCenter, 100 - zoneCenter) - zoneHalf;
  const ratio = Math.min((d - zoneHalf) / maxDist, 1);
  return Math.round(BAL.priceMax - (BAL.priceMax - BAL.priceMin) * ratio);
}

/** Облачко скупщика над сценой. */
function pgSay(text, kind) {
  const b = el('pgOffer');
  if (b.textContent !== text) b.textContent = text;
  const cls = 'pg-offer' + (kind ? ' ' + kind : '');
  if (b.className !== cls) b.className = cls;
}

function isPriceGameOpen() {
  return priceGame.open;
}

function openPriceGame() {
  if (priceGame.open) return;
  Object.assign(priceGame, {
    open: true,
    zoneCenter: 25 + Math.random() * 50,
    zoneHalf: BAL.priceZoneHalf + F.wideZone(lv('wideZone')),
    secondChanceUsed: false,
  });
  el('pgZone').style.left = (priceGame.zoneCenter - priceGame.zoneHalf) + '%';
  el('pgZone').style.width = (priceGame.zoneHalf * 2) + '%';
  const mult = priceMultiplier();
  const res = el('pgResult');
  res.textContent = `${fmt(Math.round(BAL.priceMin * mult))} – ${fmt(Math.round(BAL.priceMax * mult))} ₽/г`;
  res.className = 'pg-result hint';
  setText('pgResultSub', '');
  el('pgOverlay').classList.add('show');
  if (!pgScene) pgScene = new PixelScene(el('pgCanvas'), 56, drawMarketScene);
  pgScene.w = 0;
  pgSay('Ну, что принёс?');
  priceGame.sceneStop = frameLoop(() => pgScene.frame());
  runPriceRunner();
}

function runPriceRunner() {
  priceGame.running = true;
  priceGame.pos = 0;
  priceGame.dir = 1;
  el('pgStop').disabled = false;
  el('pgStop').textContent = 'СТОП';
  el('pgRunner').style.left = '0%';
  priceGame.stop = frameLoop(dt => {
    const speed = BAL.priceRunnerSpeed * (hasAmulet('patient') ? 0.5 : 1);
    priceGame.pos += priceGame.dir * speed * dt * 100;
    if (priceGame.pos >= 100) { priceGame.pos = 100; priceGame.dir = -1; }
    if (priceGame.pos <= 0) { priceGame.pos = 0; priceGame.dir = 1; }
    el('pgRunner').style.left = priceGame.pos + '%';
    const p = priceAt(priceGame.pos);
    pgSay(`Даю ${fmt(Math.round(p * priceMultiplier()))} ₽/г`, p >= BAL.priceMax ? 'best' : p > (BAL.priceMax + BAL.priceMin) / 2 ? 'good' : '');
  });
}

/** Кнопка «СТОП»: цена зависит от того, насколько бегунок далеко от зелёной зоны. */
function priceGameStop() {
  if (!priceGame.running) return;
  priceGame.running = false;
  priceGame.stop();
  el('pgStop').disabled = true;

  const { pos, zoneCenter, zoneHalf } = priceGame;
  const hit = Math.abs(pos - zoneCenter) <= zoneHalf;
  const price = priceAt(pos);

  // Амулет «Второй шанс»: один переброс при промахе
  if (!hit && hasAmulet('secondChance') && !priceGame.secondChanceUsed) {
    priceGame.secondChanceUsed = true;
    setText('pgResultSub', 'Второй шанс!');
    pgSay('Ладно, давай ещё раз');
    setText('pgResult', '');
    el('pgResult').className = 'pg-result';
    sndPriceHit();
    runPriceRunner();
    return;
  }

  const res = el('pgResult');
  res.textContent = Math.round(price * priceMultiplier()) + ' ₽/г';
  res.className = 'pg-result ' + (hit ? 'hit' : 'miss');
  const msg = pickRandom(hit ? TEXT.priceHit : TEXT.priceMiss);
  setText('pgResultSub', msg);
  pgSay(hit ? pickRandom(['По рукам!', 'Хороший металл', 'Уговорил']) : pickRandom(['Больше не дам', 'Бери, пока дают', 'Это моя цена']), hit ? 'best' : 'bad');
  if (pgScene && hit) pgScene.flash = 0.5;
  if (hit) { sndPriceHit(); vibe(40); } else { sndPriceMiss(); vibe(20); }

  setTimeout(() => {
    if (!priceGame.open) return;
    finishSale(price, hit, msg);
    closePriceGame();
  }, 900);
}

function closePriceGame() {
  if (priceGame.running) priceGame.stop();
  priceGame.running = false;
  priceGame.open = false;
  if (priceGame.sceneStop) { priceGame.sceneStop(); priceGame.sceneStop = null; }
  el('pgOverlay').classList.remove('show');
}
