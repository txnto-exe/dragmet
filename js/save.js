'use strict';
// Сохранение и загрузка.
//
// Сейв пишется по очереди в два слота (A и B): если телефон выключится посреди записи,
// второй слот останется целым. При загрузке берётся более свежий.
//
// Старые сейвы (версия DeepSeek, ключи *_v2) при первой загрузке переводятся в новый формат.
// Сами старые ключи не трогаем — откатиться на старую версию игры можно без потери прогресса.

const SAVE_FORMAT = 3;
const SAVE_KEYS = ['dragmet_save_a_v3', 'dragmet_save_b_v3'];
const OLD_SAVE_KEYS = ['dragmet_save_a_v2', 'dragmet_save_b_v2'];

let lastSaveTs = 0;   // когда последний раз сохранялись (для меню и настроек)
let nextSlot = 0;     // в какой слот писать следующий сейв

function readJson(key) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch (e) {
    return null;
  }
}

function readSlots(keys, isValid) {
  return keys.map(k => readJson(k)).map(d => (d && isValid(d) ? d : null));
}

const isNewSave = d => d.format === SAVE_FORMAT && d.game && d.game.run && d.game.meta;
const isOldSave = d => d.s && d.p;

/** Самый свежий сейв: { game, ts } или null. */
function findBestSave() {
  const slots = readSlots(SAVE_KEYS, isNewSave);
  let best = -1;
  slots.forEach((d, i) => { if (d && (best < 0 || d.ts > slots[best].ts)) best = i; });
  if (best >= 0) {
    nextSlot = 1 - best;
    return { game: slots[best].game, ts: slots[best].ts };
  }
  const old = readSlots(OLD_SAVE_KEYS, isOldSave).filter(Boolean).sort((a, b) => b.ts - a.ts)[0];
  if (old) {
    nextSlot = 0;
    return { game: migrateOldSave(old), ts: old.ts || 0 };
  }
  return null;
}

function hasSave() {
  return findBestSave() !== null;
}

function saveGame() {
  if (!G) return false;
  try {
    G.lastSeenTs = Date.now();
    const data = { format: SAVE_FORMAT, ts: Date.now(), game: G };
    localStorage.setItem(SAVE_KEYS[nextSlot], JSON.stringify(data));
    nextSlot = 1 - nextSlot;
    lastSaveTs = data.ts;
    return true;
  } catch (e) {
    console.error('Не удалось сохранить игру', e);
    if (!saveWarned) {
      saveWarned = true;
      showError(new Error('не получается сохранить игру — память браузера недоступна или переполнена'));
    }
    return false;
  }
}
let saveWarned = false;

/** Загрузить сейв в G. Возвращает true, если сейв нашёлся. */
function loadGame() {
  const found = findBestSave();
  if (!found) return false;
  G = sanitizeGame(found.game);
  lastSaveTs = found.ts;
  return true;
}

function deleteAllSaves() {
  try {
    for (const k of SAVE_KEYS.concat(OLD_SAVE_KEYS)) localStorage.removeItem(k);
  } catch (e) { /* хранилище недоступно — и так пусто */ }
  lastSaveTs = 0;
  nextSlot = 0;
}

// ===== Резервная копия текстом (на случай удаления иконки или смены телефона) =====

const BACKUP_PREFIX = 'DRAGMET:';

/** Сейв одной строкой, которую можно сохранить в заметки или переслать себе. */
function exportSave() {
  saveGame();
  const json = JSON.stringify({ format: SAVE_FORMAT, ts: Date.now(), game: G });
  return BACKUP_PREFIX + btoa(unescape(encodeURIComponent(json)));
}

/** Разобрать строку резервной копии. Возвращает готовое состояние или null, если строка кривая. */
function parseBackup(text) {
  try {
    const raw = String(text || '').trim();
    if (!raw.startsWith(BACKUP_PREFIX)) return null;
    const data = JSON.parse(decodeURIComponent(escape(atob(raw.slice(BACKUP_PREFIX.length)))));
    return isNewSave(data) ? sanitizeGame(data.game) : null;
  } catch (e) {
    return null;
  }
}

// ===== Проверка загруженных данных =====
// Берём чистое новое состояние и переносим в него из сейва только то, что выглядит правильно.
// Так кривой или старый сейв не сломает игру.

const isNum = v => typeof v === 'number' && isFinite(v);
const isObj = v => v && typeof v === 'object' && !Array.isArray(v);
const num = (v, def = 0) => (isNum(v) ? v : def);

function sanitizeVessels(list) {
  if (!Array.isArray(list) || !list.length) return [makeVessel()];
  return list.map(v => ({
    active: !!(v && v.active),
    progress: num(v && v.progress),
    duration: num(v && v.duration),
    yieldAmt: num(v && v.yieldAmt),
  }));
}

function sanitizeGame(src) {
  const g = makeGame();
  if (!isObj(src)) return g;
  const run = isObj(src.run) ? src.run : {};
  const meta = isObj(src.meta) ? src.meta : {};
  const ui = isObj(src.ui) ? src.ui : {};

  // --- Забег ---
  g.run.cash = num(run.cash);
  g.run.ingots = num(run.ingots);
  g.run.solution = num(run.solution);
  for (const k of ITEM_KEYS) {
    if (isObj(run.junk)) g.run.junk[k] = Math.max(0, Math.floor(num(run.junk[k])));
    if (isObj(run.locked)) g.run.locked[k] = !!run.locked[k];
  }
  g.run.acid = sanitizeVessels(run.acid);
  g.run.fire = sanitizeVessels(run.fire);
  if (isObj(run.locs)) {
    for (const loc of LOCATIONS) {
      const s = run.locs[loc.key];
      if (!isObj(s)) continue;
      const d = g.run.locs[loc.key];
      d.stock = clamp(Math.floor(num(s.stock, loc.stock)), 0, loc.stock);
      d.regenTimer = num(s.regenTimer);
      d.unlocked = d.unlocked || !!s.unlocked;
      d.regenLv = Math.floor(num(s.regenLv));
    }
  }
  if (locDef(run.activeLoc) && g.run.locs[run.activeLoc].unlocked) g.run.activeLoc = run.activeLoc;

  // --- Навсегда ---
  g.meta.prestige = clamp(Math.floor(num(meta.prestige)), 0, BAL.prestigeMaxLevel);
  g.meta.points = num(meta.points);
  for (const loc of LOCATIONS) {
    if (isObj(meta.autoDig)) g.meta.autoDig[loc.key] = !!meta.autoDig[loc.key];
    if (isObj(meta.autoTimers)) g.meta.autoTimers[loc.key] = num(meta.autoTimers[loc.key]);
  }
  if (isObj(meta.auto)) for (const k in g.meta.auto) g.meta.auto[k] = num(meta.auto[k]);
  g.meta.forgeUnlocked = !!meta.forgeUnlocked;
  if (isObj(meta.amulets)) {
    for (const k in meta.amulets) {
      const a = meta.amulets[k];
      if (amuletDef(k) && isObj(a)) g.meta.amulets[k] = isNum(a.expiresAt) ? { expiresAt: a.expiresAt } : { prestigeLeft: num(a.prestigeLeft) };
    }
  }
  if (g.meta.amulets[meta.equipped]) g.meta.equipped = meta.equipped;
  if (Array.isArray(meta.crafts)) {
    g.meta.crafts = meta.crafts
      .filter(c => isObj(c) && amuletDef(c.id) && isNum(c.startedAt) && isNum(c.duration))
      .map(c => ({ id: c.id, startedAt: c.startedAt, duration: c.duration }));
  }

  // --- Уровни прокачек (обрезаем по максимуму на случай, если максимум уменьшили) ---
  const runLv = isObj(run.lv) ? run.lv : {};
  const metaLv = isObj(meta.lv) ? meta.lv : {};
  for (const u of UPGRADES) {
    const saved = u.get ? upgLevel(u, g) : (u.currency === 'cash' ? runLv : metaLv)[u.key];
    if (isNum(saved)) upgSetLevel(u, clamp(Math.floor(saved), u.start || 0, u.max), g);
  }

  // --- Интерфейс и настройки ---
  g.ui.locPage = clamp(Math.floor(num(ui.locPage)), 0, LOC_PAGES - 1);
  if (isObj(ui.acc)) for (const k in ui.acc) g.ui.acc[k] = !!ui.acc[k];
  if (isObj(ui.badgeSeen)) for (const k in g.ui.badgeSeen) g.ui.badgeSeen[k] = num(ui.badgeSeen[k], -1);
  if (isObj(src.settings)) {
    if (typeof src.settings.sound === 'boolean') g.settings.sound = src.settings.sound;
    if (typeof src.settings.vibe === 'boolean') g.settings.vibe = src.settings.vibe;
  }
  g.lastSeenTs = num(src.lastSeenTs, Date.now());

  // Ванн и печей должно быть столько, сколько куплено
  const prevG = G;
  G = g;
  ensureVessels();
  G = prevG;
  return g;
}

// ===== Перевод старого сейва (DeepSeek, ver ≤ 37) в новый формат =====
function migrateOldSave(old) {
  const s = old.s, p = old.p;
  const locs = {};
  if (Array.isArray(s.locs)) for (const l of s.locs) if (l && l.key) locs[l.key] = l;

  const metaLv = Object.assign({}, isObj(p.lv) ? p.lv : {});
  metaLv.automation = p.automationBought ? 1 : 0;

  let crafts = [];
  if (Array.isArray(s.forgeCrafts)) crafts = s.forgeCrafts;
  else if (s.forgeCraft) crafts = [s.forgeCraft];

  return {
    run: {
      cash: s.cash, ingots: s.ingots, solution: s.solution,
      junk: s.junk, locked: s.locked,
      acid: s.acid, fire: s.fire,
      activeLoc: s.activeLoc, locs,
      lv: s.lv,
    },
    meta: {
      prestige: p.level, points: p.points, lv: metaLv,
      autoDig: p.autoDig, autoTimers: p.autoTimers,
      auto: {
        junk: p.autoJunk, solution: p.autoSolution, ingots: p.autoIngots,
        workerTimer: p.autoWorkerTimer, acidTimer: p.autoAcidTimer,
        fireTimer: p.autoFireTimer, saleTimer: p.autoSaleTimer,
      },
      forgeUnlocked: s.forgeUnlocked,
      amulets: s.amulets, equipped: s.equippedAmulet, crafts,
    },
    ui: { locPage: s.locPage, acc: s.accState, badgeSeen: s.badgeSeen },
    settings: s.settings,
    lastSeenTs: s.lastSeenTs,
  };
}
