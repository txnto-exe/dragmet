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
  { label: 'Вода', speed: 40 },
  { label: 'Кислота', speed: 55 },
  { label: 'Щёлочь', speed: 70 },
];
const flaskEls = [];

function buildAcidMiniGame() {
  const box = el('amgFlasks');
  FLASKS.forEach((fl, i) => {
    const wrap = make('div', 'amg-flask-wrap');
    const flask = make('div', 'amg-flask');
    const fill = make('div', 'amg-fill');
    const zone = make('div', 'amg-zone');
    const marker = make('div', 'amg-marker');
    flask.append(fill, zone, marker);
    const btn = make('button', 'amg-btn', 'Держи');
    btn.type = 'button';
    wrap.append(flask, make('div', 'amg-label', fl.label), btn);
    box.appendChild(wrap);
    flaskEls.push({ flask, fill, zone, marker, btn });
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
  st.flasks.forEach((f, i) => {
    const e = flaskEls[i];
    e.zone.style.bottom = f.zone.start + '%';
    e.zone.style.height = (f.zone.end - f.zone.start) + '%';
    e.flask.classList.remove('ok', 'fail');
    e.btn.classList.remove('done', 'pouring');
    e.btn.textContent = 'Держи';
    drawFlask(i, 0);
  });
  setMgResult('amgResult', '');
  activeMinigame = st;
  el('acidMgOverlay').classList.add('show');
  st.stop = frameLoop(dt => {
    if (st.pouring < 0 || st.gameOver) return;
    const f = st.flasks[st.pouring];
    f.pos += f.dir * FLASKS[st.pouring].speed * dt;
    if (f.pos >= 100) { f.pos = 100; f.dir = -1; }
    if (f.pos <= 0) { f.pos = 0; f.dir = 1; }
    drawFlask(st.pouring, f.pos);
  });
}

function drawFlask(i, pos) {
  flaskEls[i].marker.style.bottom = pos + '%';
  flaskEls[i].fill.style.height = pos + '%';
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
    flaskEls.forEach(e => e.flask.classList.add('fail'));
    setMgResult('amgResult', '✕ Промах — попробуй снова', 'fail');
    sndMgFail(); vibe(60);
    setTimeout(() => closeMinigame(st), 800);
    return;
  }
  f.done = true;
  flaskEls[i].flask.classList.add('ok');
  flaskEls[i].btn.classList.add('done');
  flaskEls[i].btn.textContent = '✓';
  sndMgOk(); vibe(30);
  if (st.flasks.every(x => x.done)) {
    st.gameOver = true;
    setMgResult('amgResult', '✓ Раствор готов', 'ok');
    sndMgWin(); vibe(50);
    setTimeout(() => { if (closeMinigame(st)) st.onWin(); }, 700);
  }
}

// ===== «Выплавка»: держи бегунок в движущейся зоне =====

function buildFireMiniGame() {
  const press = (side, on) => {
    const st = activeMinigame;
    if (!st || st.kind !== 'fire') return;
    if (on && st.gameOver) return;
    st.hold[side] = on;
    if (on) {
      st.runner = clamp(st.runner + (side === 'right' ? 2 : -2), 0, 100);
      vibe(8);
    }
  };
  bindHold(el('fmgPlus'), () => press('right', true), () => press('right', false));
  bindHold(el('fmgMinus'), () => press('left', true), () => press('left', false));
}

function openFireMiniGame(onWin) {
  const st = {
    kind: 'fire', onWin, gameOver: false,
    zone: 30 + Math.random() * 40, zoneDir: Math.random() < 0.5 ? 1 : -1, zoneHalf: 9, zoneSpeed: 35 + Math.random() * 20,
    runner: 50, runnerSpeed: 55,
    ready: 0,        // «Готовность», %
    outsideMs: 0,    // сколько всего пробыл вне зоны (5 секунд — провал)
    hold: { left: false, right: false },
  };
  setMgResult('fmgResult', '');
  activeMinigame = st;
  drawFireMiniGame(st);
  el('fireMgOverlay').classList.add('show');
  st.stop = frameLoop(dt => {
    if (st.gameOver) return;
    st.zone += st.zoneDir * st.zoneSpeed * dt;
    if (st.zone >= 100 - st.zoneHalf) { st.zone = 100 - st.zoneHalf; st.zoneDir = -1; }
    if (st.zone <= st.zoneHalf) { st.zone = st.zoneHalf; st.zoneDir = 1; }
    if (st.hold.left !== st.hold.right) st.runner += (st.hold.right ? 1 : -1) * st.runnerSpeed * dt;
    st.runner = clamp(st.runner, 0, 100);

    if (Math.abs(st.runner - st.zone) <= st.zoneHalf) {
      st.ready = Math.min(100, st.ready + dt * 100 / 3);   // 3 секунды в зоне — 100%
    } else {
      st.ready = Math.max(0, st.ready - dt * 100);          // 1 секунда вне зоны — до нуля
      st.outsideMs += dt * 1000;
      if (st.outsideMs >= 5000) {
        st.gameOver = true;
        setMgResult('fmgResult', '✕ Прогар — попробуй снова', 'fail');
        sndMgFail(); vibe(60);
        setTimeout(() => closeMinigame(st), 800);
      }
    }
    if (st.ready >= 100 && !st.gameOver) {
      st.gameOver = true;
      setMgResult('fmgResult', '✓ Готово', 'ok');
      sndMgWin(); vibe(50);
      setTimeout(() => { if (closeMinigame(st)) st.onWin(); }, 700);
    }
    drawFireMiniGame(st);
  });
}

function drawFireMiniGame(st) {
  el('fmgZone').style.left = (st.zone - st.zoneHalf) + '%';
  el('fmgZone').style.width = (st.zoneHalf * 2) + '%';
  el('fmgRunner').style.left = st.runner + '%';
  el('fmgProgress').style.width = st.ready + '%';
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

const priceGame = { open: false, running: false, pos: 0, dir: 1, zoneCenter: 50, zoneHalf: 5, secondChanceUsed: false, stop: null };

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
  });
}

/** Кнопка «СТОП»: цена зависит от того, насколько бегунок далеко от зелёной зоны. */
function priceGameStop() {
  if (!priceGame.running) return;
  priceGame.running = false;
  priceGame.stop();
  el('pgStop').disabled = true;

  const { pos, zoneCenter, zoneHalf } = priceGame;
  const d = Math.abs(pos - zoneCenter);
  const hit = d <= zoneHalf;
  let price = BAL.priceMax;
  if (!hit) {
    const maxDist = Math.max(zoneCenter, 100 - zoneCenter) - zoneHalf;
    const ratio = Math.min((d - zoneHalf) / maxDist, 1);
    price = Math.round(BAL.priceMax - (BAL.priceMax - BAL.priceMin) * ratio);
  }

  // Амулет «Второй шанс»: один переброс при промахе
  if (!hit && hasAmulet('secondChance') && !priceGame.secondChanceUsed) {
    priceGame.secondChanceUsed = true;
    setText('pgResultSub', 'Второй шанс!');
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
  el('pgOverlay').classList.remove('show');
}
