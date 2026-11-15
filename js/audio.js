'use strict';
// Звуки и вибрация. Все звуки синтезируются на лету — файлов со звуками нет.

const SOUND_VOLUME = Math.min(0.07 * 14, 0.99);

let audioCtx = null;
let audioBroken = false;
const soundLoops = { acid: null, fire: null };

/** Звук в iOS можно включить только после касания — вызывается на каждое нажатие. */
function initAudio() {
  if (audioBroken) return;
  try {
    if (!audioCtx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) { audioBroken = true; return; }
      audioCtx = new Ctx();
    }
    if (audioCtx.state === 'suspended') audioCtx.resume();
  } catch (e) {
    audioBroken = true;
    audioCtx = null;
  }
}

function canPlay() {
  return audioCtx && G && G.settings.sound;
}

/** Один короткий звук. freqTo — если задан, тон плавно едет к нему. */
function beep(freq, dur, type = 'sine', delay = 0, freqTo = null, volume = 1) {
  if (!canPlay()) return;
  try {
    const t0 = audioCtx.currentTime + delay;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    if (freqTo) osc.frequency.exponentialRampToValueAtTime(Math.max(freqTo, 20), t0 + dur);
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(Math.min(SOUND_VOLUME * volume, 0.99), t0 + 0.005);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  } catch (e) { /* звук не критичен */ }
}
const tone = (f, dur, type, delay) => beep(f, dur, type, delay);
const slide = (f1, f2, dur, type, delay) => beep(f1, dur, type, delay, f2);
const crackle = (f, dur, vol) => beep(f, dur, 'square', 0, null, vol);
/** Чуть случайная частота, чтобы одинаковые звуки не надоедали. */
const rnd = f => f * (0.94 + Math.random() * 0.12);
/** Аккорд-«арпеджио»: несколько нот подряд. */
const arp = (freqs, dur, type, step, random = true) =>
  freqs.forEach((f, i) => tone(random ? rnd(f) : f, dur, type, i * step));

function sndTab() { tone(rnd(1400), 0.05, 'square'); tone(rnd(1000), 0.07, 'triangle', 0.01); }
function sndAccOpen() { tone(rnd(1100), 0.06, 'triangle'); tone(rnd(1600), 0.07, 'triangle', 0.03); }
function sndAccClose() { tone(rnd(1600), 0.06, 'triangle'); tone(rnd(1100), 0.08, 'triangle', 0.03); }
function sndToggle() { tone(rnd(1200), 0.05, 'square'); tone(rnd(1800), 0.06, 'square', 0.03); }
function sndSelect() { tone(rnd(1500), 0.05, 'square'); tone(rnd(2000), 0.06, 'square', 0.03); }
function sndStartProcess() { slide(rnd(600), rnd(1400), 0.15, 'triangle'); slide(rnd(500), rnd(1100), 0.18, 'triangle', 0.06); }
function sndBuy() { arp([1200, 1700, 2300], 0.08, 'square', 0.05); }
function sndDeny() { slide(rnd(700), rnd(300), 0.18, 'sawtooth'); }
function sndCooldown() { tone(rnd(500), 0.04, 'triangle'); }
function sndCoins() { arp([1400, 1800, 2200, 2800], 0.22, 'square', 0.05); }
function sndPrestige() { arp([880, 1100, 1400, 1800], 0.5, 'triangle', 0.12, false); }
function sndOfflineClaim() { arp([1100, 1500, 2000], 0.3, 'triangle', 0.08, false); }
function sndPriceHit() { arp([1600, 2000, 2600, 3200], 0.18, 'square', 0.04); }
function sndPriceMiss() { slide(rnd(500), rnd(250), 0.22, 'sawtooth'); }
function sndDoubleDrop() { arp([2200, 2800, 3400], 0.1, 'square', 0.05); }
function sndCraftStart() { arp([600, 900, 1200], 0.15, 'triangle', 0.08); }
function sndCraftDone() { arp([1400, 1800, 2400, 3000], 0.25, 'square', 0.08); }
function sndMgOk() { arp([1400, 1800], 0.14, 'square', 0.07); }
function sndMgWin() { arp([1600, 2000, 2400, 3000], 0.22, 'square', 0.08); }
function sndMgFail() { slide(rnd(700), rnd(200), 0.35, 'sawtooth'); }
function sndAutoSale() { arp([1800, 2400, 3000], 0.12, 'triangle', 0.04); }

/** Звук и вибрация находки — зависят от ценности предмета. */
const FIND_SOUNDS = {
  junk:   { vibe: 12, play: () => { tone(rnd(600), 0.05, 'triangle'); tone(rnd(400), 0.07, 'triangle', 0.02); } },
  mid:    { vibe: 15, play: () => { tone(rnd(900), 0.06, 'triangle'); tone(rnd(650), 0.08, 'triangle', 0.02); } },
  nice:   { vibe: 18, play: () => { tone(rnd(1200), 0.06, 'square'); tone(rnd(1700), 0.08, 'square', 0.03); } },
  rare:   { vibe: 28, play: () => arp([1500, 2000, 2600], 0.12, 'square', 0.05) },
  pricey: { vibe: 30, play: () => arp([1800, 2300, 2900], 0.16, 'square', 0.04) },
  legend: { vibe: 40, play: () => arp([1800, 2200, 2700, 3300], 0.35, 'triangle', 0.05) },
};
function sndFind(itemKey) {
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
      // Тон кислоты растёт по мере растворения
      const f1 = 600 + avgAcidProgress() * 1200 + Math.random() * 150;
      slide(f1, f1 + 150 + Math.random() * 350, 0.1, 'triangle');
      return 140 + Math.random() * 180;
    });
  }
  if (!acidRunning && soundLoops.acid) stopLoop('acid');

  if (fireRunning && !soundLoops.fire) {
    startLoop('fire', () => {
      const f = 800 + Math.random() * 1000;
      crackle(f, 0.025, 0.6);
      if (Math.random() < 0.45) crackle(f * (0.6 + Math.random() * 0.3), 0.018, 0.45);
      if (Math.random() < 0.15) crackle(f * 1.4, 0.03, 0.5);
      return 80 + Math.random() * 120;
    });
  }
  if (!fireRunning && soundLoops.fire) stopLoop('fire');
}

function stopAllLoops() {
  stopLoop('acid');
  stopLoop('fire');
}

function vibe(ms = 15) {
  if (!G || !G.settings.vibe || !navigator.vibrate) return;
  try { navigator.vibrate(ms); } catch (e) { /* не все телефоны умеют */ }
}
