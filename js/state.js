'use strict';
// Состояние игры. Всё, что сохраняется, лежит в одном объекте G и делится на части:
//   G.run      — текущий забег: сбрасывается при престиже (деньги, лом, обычные прокачки…)
//   G.meta     — то, что остаётся навсегда (престиж, очки, амулеты, работяги, авто-фабрика…)
//   G.ui       — положение интерфейса (открытые аккордеоны, страница локаций, бейджи)
//   G.settings — звук и вибрация
// Благодаря этому делению престиж — это просто «G.run = новый забег».

let G = null;

function makeVessel() {
  return { active: false, progress: 0, duration: 0, yieldAmt: 0 };
}

/** Новый забег (начало игры или после престижа). */
function makeRun() {
  const junk = {}, locked = {};
  for (const k of ITEM_KEYS) { junk[k] = 0; locked[k] = false; }
  const locs = {};
  for (const loc of LOCATIONS) {
    locs[loc.key] = { stock: loc.stock, regenTimer: 0, regenLv: 0, unlocked: loc.unlockCost === 0 };
  }
  return {
    cash: 0,
    ingots: 0,             // граммы слитков
    solution: 0,           // раствор после кислоты (в граммах будущего золота)
    junk,                  // лом на складе: сколько штук каждого предмета
    locked,                // предметы с замком (не идут в кислоту)
    acid: [makeVessel()],  // ванны кислоты (вторая появляется с прокачкой)
    fire: [makeVessel()],  // печи
    activeLoc: 'yard',
    locs,
    scavCd: 0,             // сколько мс ещё ждать до следующей копки
    lv: {},                // уровни обычных прокачек (заполняет upgrades.js)
  };
}

/** То, что переживает престиж. */
function makeMeta() {
  const autoDig = {}, autoTimers = {};
  for (const loc of LOCATIONS) { autoDig[loc.key] = false; autoTimers[loc.key] = 0; }
  return {
    prestige: 0,
    points: 0,
    lv: {},                // уровни прокачек за очки престижа (заполняет upgrades.js)
    autoDig,               // купленные работяги по локациям
    autoTimers,
    auto: { junk: 0, solution: 0, ingots: 0, workerTimer: 0, acidTimer: 0, fireTimer: 0, saleTimer: 0 },
    forgeUnlocked: false,
    amulets: {},           // скованные амулеты: { ключ: { prestigeLeft } или { expiresAt } }
    equipped: null,        // надетый амулет
    crafts: [],            // что сейчас куётся: [{ id, startedAt, duration }]
  };
}

function makeUi() {
  return {
    locView: 0,            // какая точка сбора на экране (номер в LOCATIONS)
    acc: { eq: true, pbonus: true },
    badgeSeen: { fire: -1, acid: -1, upg: -1, forge: -1 },
  };
}

function makeGame() {
  const game = {
    run: makeRun(),
    meta: makeMeta(),
    ui: makeUi(),
    settings: { sound: true, vibe: true },
    lastSeenTs: Date.now(),
  };
  fillUpgradeLevels(game);
  return game;
}

// ===== Удобные подсчёты по складу =====

function totalJunk() {
  let t = 0;
  for (const k of ITEM_KEYS) t += G.run.junk[k];
  return t;
}

/** Сколько граммов золота в ломе на складе (onlyUnlocked — только без замка). */
function junkGold(onlyUnlocked) {
  let sum = 0;
  for (const k of ITEM_KEYS) {
    if (onlyUnlocked && G.run.locked[k]) continue;
    sum += G.run.junk[k] * ITEMS[k].gold;
  }
  return sum;
}

function bestUnlockedLoc() {
  for (let i = LOCATIONS.length - 1; i >= 0; i--) {
    if (G.run.locs[LOCATIONS[i].key].unlocked) return LOCATIONS[i];
  }
  return null;
}

function freeVessels(list) {
  return list.filter(v => !v.active).length;
}
