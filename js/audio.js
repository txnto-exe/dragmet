'use strict';
// 8-битный звук и вибрация. Всё синтезируется на лету, как в старых приставках:
// два «квадратных» канала, «треугольный» бас и шумовой канал. Файлов со звуками нет.
//
// Музыка — короткая зацикленная мелодия (см. MUSIC ниже), играет тихо фоном.

const SFX_VOLUME = 0.22;
const MUSIC_VOLUME = 0.07;

let audioCtx = null;
let audioBroken = false;
let sfxBus = null, musicBus = null, noiseBuf = null;
const soundLoops = { acid: null, fire: null };

/** Звук в iOS можно включить только после касания — вызывается на каждое нажатие. */
function initAudio() {
  if (audioBroken) return;
  try {
    if (!audioCtx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) { audioBroken = true; return; }
      audioCtx = new Ctx();
      sfxBus = audioCtx.createGain();
      sfxBus.gain.value = SFX_VOLUME;
      sfxBus.connect(audioCtx.destination);
      musicBus = audioCtx.createGain();
      musicBus.gain.value = MUSIC_VOLUME;
      musicBus.connect(audioCtx.destination);
      // белый шум для шумового канала
      noiseBuf = audioCtx.createBuffer(1, audioCtx.sampleRate, audioCtx.sampleRate);
      const data = noiseBuf.getChannelData(0);
      for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    }
    if (audioCtx.state === 'suspended') audioCtx.resume();
    updateMusic();
  } catch (e) {
    audioBroken = true;
    audioCtx = null;
  }
}

function canPlay() {
  return audioCtx && G && G.settings.sound;
}

// ===== Каналы =====

/**
 * Нота: частота f, длительность dur (с), тип волны, задержка.
 * freqTo — частота в конце (свип вверх/вниз), vol — громкость 0..1, bus — куда (звуки/музыка).
 */
function note(f, dur, type = 'square', delay = 0, freqTo = null, vol = 1, bus = sfxBus, at = null) {
  if (!audioCtx || !bus) return;
  try {
    const t0 = at != null ? at : audioCtx.currentTime + delay;
    const osc = audioCtx.createOscillator();
    const g = audioCtx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(f, t0);
    if (freqTo) osc.frequency.exponentialRampToValueAtTime(Math.max(freqTo, 20), t0 + dur);
    // «приставочная» огибающая: резкая атака, ступенчатое затухание
    g.gain.setValueAtTime(vol, t0);
    g.gain.setValueAtTime(vol * 0.7, t0 + dur * 0.5);
    g.gain.linearRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(g);
    g.connect(bus);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  } catch (e) { /* звук не критичен */ }
}

/** Шумовой канал: «хруст», «шорох», «тарелка». hp — фильтр (выше — тоньше звук). */
function noise(dur, delay = 0, vol = 0.6, hp = 1000, bus = sfxBus, at = null) {
  if (!audioCtx || !bus || !noiseBuf) return;
  try {
    const t0 = at != null ? at : audioCtx.currentTime + delay;
    const src = audioCtx.createBufferSource();
    src.buffer = noiseBuf;
    src.playbackRate.value = 0.5 + Math.random();
    const filt = audioCtx.createBiquadFilter();
    filt.type = 'highpass';
    filt.frequency.value = hp;
    const g = audioCtx.createGain();
    g.gain.setValueAtTime(vol, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    src.connect(filt); filt.connect(g); g.connect(bus);
    src.start(t0, Math.random() * 0.5);
    src.stop(t0 + dur + 0.02);
  } catch (e) { /* не критично */ }
}

const sfx = (...a) => { if (canPlay()) note(...a); };
const sfxNoise = (...a) => { if (canPlay()) noise(...a); };
/** Быстрое арпеджио — главный приём 8-битной музыки. */
function arp(freqs, step = 0.05, dur = 0.06, type = 'square', vol = 0.8) {
  freqs.forEach((f, i) => sfx(f, dur, type, i * step, null, vol));
}
const rnd = f => f * (0.97 + Math.random() * 0.06);

// Ноты (Гц)
const N = {
  C4: 262, D4: 294, E4: 330, F4: 349, G4: 392, A4: 440, B4: 494,
  C5: 523, D5: 587, E5: 659, F5: 698, G5: 784, A5: 880, B5: 988,
  C6: 1047, D6: 1175, E6: 1319, G6: 1568, A6: 1760, C7: 2093,
};

// ===== Звуки интерфейса и игры =====

function sndTab() { sfx(rnd(N.A5), 0.035, 'square', 0, null, 0.5); }
function sndAccOpen() { sfx(N.E5, 0.04, 'square', 0, null, 0.5); sfx(N.A5, 0.05, 'square', 0.035, null, 0.5); }
function sndAccClose() { sfx(N.A5, 0.04, 'square', 0, null, 0.5); sfx(N.E5, 0.05, 'square', 0.035, null, 0.5); }
function sndToggle() { sfx(N.C6, 0.04, 'square', 0, null, 0.5); sfx(N.G6, 0.05, 'square', 0.04, null, 0.5); }
function sndSelect() { sfx(N.G5, 0.04, 'square', 0, null, 0.6); }
function sndStartProcess() { sfx(N.C5, 0.18, 'square', 0, N.C6, 0.6); sfxNoise(0.15, 0, 0.25, 3000); }
function sndBuy() { arp([N.C5, N.E5, N.G5, N.C6], 0.045, 0.06); }
function sndDeny() { sfx(180, 0.12, 'square', 0, 120, 0.7); sfx(150, 0.14, 'square', 0.08, 100, 0.6); }
function sndCooldown() { sfx(N.C4, 0.02, 'triangle', 0, null, 0.4); }
function sndCoins() { sfx(N.B5, 0.07, 'square', 0, null, 0.8); sfx(N.E6, 0.28, 'square', 0.07, null, 0.8); }
function sndPrestige() {
  arp([N.C5, N.E5, N.G5, N.C6, N.E6, N.G6], 0.07, 0.12, 'square', 0.8);
  [N.C4, N.G4, N.C5].forEach((f, i) => sfx(f, 0.3, 'triangle', 0.45 + i * 0.12, null, 1));
  sfxNoise(0.6, 0.45, 0.25, 6000);
}
function sndOfflineClaim() { arp([N.G5, N.C6, N.E6, N.G6], 0.06, 0.1); sfx(N.C4, 0.3, 'triangle', 0.05, null, 1); }
function sndPriceHit() { arp([N.E6, N.G6, N.C7], 0.05, 0.08); sfx(N.B5, 0.07, 'square', 0.18); sfx(N.E6, 0.3, 'square', 0.25); }
function sndPriceMiss() { sfx(N.G4, 0.12, 'square', 0, null, 0.7); sfx(N.D4, 0.25, 'square', 0.12, 150, 0.7); }
function sndDoubleDrop() { arp([N.C6, N.E6, N.G6], 0.04, 0.05); }
function sndCraftStart() { sfxNoise(0.06, 0, 0.7, 2500); sfxNoise(0.06, 0.18, 0.7, 2500); sfx(N.C5, 0.05, 'square', 0, null, 0.5); sfx(N.C5, 0.05, 'square', 0.18, null, 0.5); }
function sndCraftDone() { arp([N.G5, N.B5, N.D6, N.G6], 0.07, 0.12); }
function sndMgOk() { arp([N.E5, N.A5], 0.06, 0.07); }
function sndMgWin() { arp([N.C5, N.E5, N.G5, N.C6, N.G5, N.C6], 0.06, 0.09); }
function sndMgFail() { sfx(N.E4, 0.15, 'square', 0, null, 0.7); sfx(N.C4, 0.3, 'square', 0.15, 80, 0.7); }
function sndAutoSale() { sfx(N.B5, 0.05, 'square', 0, null, 0.4); sfx(N.E6, 0.12, 'square', 0.05, null, 0.4); }

/** Звук находки — чем дороже предмет, тем богаче мелодия. Перед ним — шорох копания. */
const FIND_SOUNDS = {
  junk:   { vibe: 12, play: () => { sfx(rnd(N.C5), 0.04, 'square', 0.03, null, 0.5); } },
  mid:    { vibe: 15, play: () => { sfx(rnd(N.E5), 0.04, 'square', 0.03, null, 0.6); sfx(rnd(N.A5), 0.05, 'square', 0.07, null, 0.6); } },
  nice:   { vibe: 18, play: () => arp([N.A5, N.C6, N.E6], 0.04, 0.05, 'square', 0.7) },
  rare:   { vibe: 28, play: () => { arp([N.C6, N.E6, N.G6, N.C7], 0.05, 0.07); sfxNoise(0.25, 0.1, 0.15, 7000); } },
  pricey: { vibe: 30, play: () => arp([N.G5, N.B5, N.D6, N.G6], 0.05, 0.08) },
  legend: { vibe: 40, play: () => {
    arp([N.C6, N.E6, N.G6, N.C7, N.G6, N.C7], 0.07, 0.12, 'square', 0.9);
    [N.C4, N.E4, N.G4].forEach((f, i) => sfx(f, 0.4, 'triangle', i * 0.14, null, 1));
    sfxNoise(0.8, 0.1, 0.2, 8000);
  } },
};
function sndFind(itemKey) {
  sfxNoise(0.07, 0, 0.5, 900);   // шорох в мусоре
  const s = FIND_SOUNDS[ITEMS[itemKey].sound];
  s.play();
  vibe(s.vibe);
}

// ===== Фоновые звуки процессов: бульканье кислоты и треск печи =====

function avgAcidProgress() {
  const active = G.run.acid.filter(b => b.active);
  if (!active.length) return 0;
  return active.reduce((sum, b) => sum + b.progress / b.duration, 0) / active.length;
}

function startLoop(name, step) {
  if (!canPlay() || soundLoops[name]) return;
  const loop = { timer: 0 };
  soundLoops[name] = loop;
  const run = () => {
    if (soundLoops[name] !== loop) return;
    loop.timer = setTimeout(run, step());
  };
  run();
}

function stopLoop(name) {
  if (soundLoops[name]) clearTimeout(soundLoops[name].timer);
  soundLoops[name] = null;
}

/** Включает/выключает фоновые звуки в зависимости от того, идут ли процессы. */
function updateSoundLoops(acidRunning, fireRunning) {
  if (acidRunning && !soundLoops.acid) {
    startLoop('acid', () => {
      // «бульк» — короткий свип вверх; чем дальше растворение, тем выше
      const f = 300 + avgAcidProgress() * 500 + Math.random() * 120;
      sfx(f, 0.05, 'triangle', 0, f * 2.2, 0.35);
      return 180 + Math.random() * 260;
    });
  }
  if (!acidRunning && soundLoops.acid) stopLoop('acid');

  if (fireRunning && !soundLoops.fire) {
    startLoop('fire', () => {
      sfxNoise(0.02 + Math.random() * 0.03, 0, 0.18 + Math.random() * 0.2, 1500 + Math.random() * 3000);
      return 60 + Math.random() * 140;
    });
  }
  if (!fireRunning && soundLoops.fire) stopLoop('fire');
}

function stopAllLoops() {
  stopLoop('acid');
  stopLoop('fire');
}

// ===== Музыка =====
// 4 такта по 16 шагов. Аккорды: Am – F – C – G, спокойный уличный мотив.
// Бас — треугольник, мелодия — квадрат, «тарелочки» — шум.

const MUSIC = {
  bpm: 96,
  chords: [
    [N.A4 / 4, [N.A4, N.C5, N.E5]],
    [N.F4 / 4, [N.F4, N.A4, N.C5]],
    [N.C4 / 2, [N.C5, N.E5, N.G5]],
    [N.G4 / 4, [N.G4, N.B4, N.D5]],
  ],
  // мелодия: индекс ноты аккорда (0–2), 3 — октавой выше первой, null — пауза
  lead: [0, null, 2, null, 1, null, 2, 3, null, 2, null, 1, 0, null, null, null],
};

const music = { timer: 0, step: 0, nextAt: 0, on: false };

function wantMusic() {
  return audioCtx && G && G.settings.sound && G.settings.music && document.visibilityState !== 'hidden';
}

/** Включить или выключить музыку по настройкам (вызывается при любом изменении). */
function updateMusic() {
  if (wantMusic() && !music.on) {
    music.on = true;
    music.nextAt = audioCtx.currentTime + 0.1;
    music.step = 0;
    musicBus.gain.setValueAtTime(MUSIC_VOLUME, audioCtx.currentTime);
    music.timer = setInterval(scheduleMusic, 100);
  } else if (!wantMusic() && music.on) {
    music.on = false;
    clearInterval(music.timer);
    if (musicBus) musicBus.gain.setValueAtTime(0, audioCtx.currentTime);
  }
}

/** Планируем ноты на ~0.3 секунды вперёд — так музыка не сбивается от подтормаживаний. */
function scheduleMusic() {
  if (!music.on) return;
  const stepDur = 60 / MUSIC.bpm / 4;
  while (music.nextAt < audioCtx.currentTime + 0.3) {
    const s = music.step % 16, bar = Math.floor(music.step / 16) % 4;
    const [bass, chord] = MUSIC.chords[bar];
    const t = music.nextAt;
    // бас: на сильные доли и «отскок»
    if (s % 4 === 0) note(bass, stepDur * 1.8, 'triangle', 0, null, 1, musicBus, t);
    if (s % 8 === 6) note(bass * 2, stepDur * 0.9, 'triangle', 0, null, 0.8, musicBus, t);
    // мелодия
    const li = MUSIC.lead[s];
    if (li != null) {
      const f = li === 3 ? chord[0] * 2 : chord[li];
      note(f, stepDur * 0.9, 'square', 0, null, 0.45, musicBus, t);
    }
    // тихое арпеджио аккорда на заднем плане
    if (s % 2 === 1) note(chord[(s >> 1) % 3] * 2, stepDur * 0.5, 'square', 0, null, 0.12, musicBus, t);
    // ударные: «бочка» и «тарелочки»
    if (s % 8 === 0) note(120, stepDur, 'triangle', 0, 40, 1, musicBus, t);
    if (s % 4 === 2) noise(0.04, 0, 0.35, 6000, musicBus, t);
    music.nextAt += stepDur;
    music.step++;
  }
}

function vibe(ms = 15) {
  if (!G || !G.settings.vibe || !navigator.vibrate) return;
  try { navigator.vibrate(ms); } catch (e) { /* не все телефоны умеют */ }
}
