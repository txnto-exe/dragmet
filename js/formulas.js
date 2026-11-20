'use strict';
// Формулы игры. Каждая формула записана ОДИН раз: и игра, и тексты прокачек
// («было → станет») считают через неё. Поменял число здесь — поменялось везде.
//
// Формулы с параметром lv — «какое значение будет на уровне lv».
// Функции без параметров — «какое значение сейчас» (с учётом уровней и амулета).

const F = {
  // --- Склад ---
  cap: lv => BAL.capStart + BAL.capPerLevel * (lv - 1),          // «Складское место», старт с 1 уровня
  capII: lv => lv * 2,                                            // «Склад II»

  // --- Скорости ручного цикла (мс) ---
  scavCd: lv => Math.max(650, 1200 - 55 * lv),                    // пауза между копками
  acidTime: lv => Math.max(1000, 4200 - 160 * lv),                // растворение
  fireTime: lv => Math.max(1000, 3400 - 120 * lv),                // выпаривание

  // --- Удача ---
  goodEye: lv => Math.min(lv * 0.04, 0.80),                       // шанс заменить находку предметом локации
  luck: lv => Math.min(lv * 0.04667, 0.70),                       // шанс двойной находки при ручной копке

  // --- Доход ---
  reputation: lv => lv * 10,                                      // наценка скупщика, %
  wideZone: lv => Math.min(lv, 5),                                // расширение зелёной зоны, %
  offlineRate: lv => Math.min(lv * 5, 75),                        // доля оффлайн-дохода, %
  offlineHours: lv => 1 + lv,                                     // лимит оффлайна, часов

  // --- Работяги за кэш ---
  workerCd: lv => Math.max(2000, 6000 - 400 * lv),                // мс на одну находку
  workerLuck: lv => lv * 5,                                       // шанс двойной находки, %

  // --- Кузница ---
  forgeSpeed: lv => Math.min(lv * 0.10, 0.70),                    // −% времени ковки
  forgeDiscount: lv => Math.min(lv * 0.05, 0.50),                 // −% ресурсов рецепта
  forgeDuration: lv => lv * 0.25,                                 // +% к сроку «часовых» амулетов

  // --- Точки сбора ---
  regenInterval: (loc, lv) => loc.regen / (1 + lv * 0.28),        // мс на восстановление 1 штуки

  // --- Престиж ---
  bonusBase: lv => 5 + BAL.bonusBoostSteps.slice(0, lv).reduce((a, b) => a + b, 0), // % бонуса за 1 престиж
  startCash: lv => lv * 1000000,
  locDiscount: lv => Math.min(lv * 0.04, 0.60),
  prestigeThreshold: level => Math.round(BAL.prestigeThresholdBase * Math.pow(BAL.prestigeThresholdMult, level)),
  prestigeReward: newLevel => Math.round(10 * Math.pow(2.5, newLevel - 1)),

  // --- Эффективность переработки ---
  cycleEff: (acidLv, fireLv, acidIILv, fireIILv) => Math.min(
    BAL.cycleEffBase
      + (acidLv - 1) * BAL.cycleEffStep
      + (fireLv - 1) * BAL.cycleEffStep
      + (acidIILv + fireIILv) * BAL.cycleEffStepII,
    BAL.cycleEffCap),

  // --- Авто-фабрика (прокачки за очки престижа) ---
  autoWorkerInterval: lv => Math.max(6000, 60000 - 2700 * lv),
  autoCap: lv => 50 + 50 * lv,
  autoAcidInterval: lv => Math.max(5000, 30000 - 1250 * lv),
  autoAcidYield: lv => Math.min(0.9, 0.5 + 0.02667 * lv),
  autoFireInterval: lv => Math.max(5000, 30000 - 1250 * lv),
  autoFireYield: lv => Math.min(0.9, 0.5 + 0.02667 * lv),
  autoSaleInterval: lv => Math.max(6000, 30000 - 2400 * lv),
  autoSalePrice: lv => 1600 + 200 * lv,
};

// ===== Текущие значения (с учётом уровней и надетого амулета) =====

function hasAmulet(key) {
  return G.meta.equipped === key;
}

function capMax() {
  return F.cap(lv('cap')) + F.capII(lv('capII')) + (hasAmulet('expander') ? 8 : 0);
}

function cycleEff() {
  return F.cycleEff(lv('acid'), lv('fire'), lv('acidII'), lv('fireII'));
}

/** Эффективность с амулетом «Чистюля» (потери вдвое меньше), но не больше 99%. */
function cycleEffEffective() {
  let e = cycleEff();
  if (hasAmulet('cleaner')) e = (1 + e) / 2;
  return Math.min(e, 0.99);
}

function withFurnaceDemon(ms) {
  return hasAmulet('furnaceDemon') ? Math.max(1000, ms * 0.75) : ms;
}
function acidDuration(level = lv('acidspd')) { return withFurnaceDemon(F.acidTime(level)); }
function fireDuration(level = lv('firespd')) { return withFurnaceDemon(F.fireTime(level)); }
function scavCdMax() { return F.scavCd(lv('scavspd')); }

function workerLuckChance() {
  let pct = F.workerLuck(lv('autoLuck'));
  if (hasAmulet('nightShift')) pct += 10;
  return Math.min(pct / 100, 0.99);
}

function prestigeBonusPct() {
  return F.bonusBase(lv('bonusBoost')) * G.meta.prestige;
}

/** Множитель цены продажи: бонус престижа × репутация. */
function priceMultiplier() {
  return (1 + prestigeBonusPct() / 100) * (1 + F.reputation(lv('reputation')) / 100) * crewPriceMult();
}

function isMaxPrestige() {
  return G.meta.prestige >= BAL.prestigeMaxLevel;
}

function locUnlockCost(loc) {
  return Math.round(loc.unlockCost * (1 - F.locDiscount(lv('locDiscount'))));
}

function locRegenInterval(loc) {
  return F.regenInterval(loc, G.run.locs[loc.key].regenLv) * crewRegenMult();
}

function maxForges() {
  return lv('twoForges') ? 2 : 1;
}

// --- Авто-фабрика ---
function autoCap() { return F.autoCap(lv('autoCapLv')); }
function autoWorkerInterval() { return F.autoWorkerInterval(lv('autoWorkers')); }
function autoAcidInterval() { return F.autoAcidInterval(lv('autoAcidSpeed')); }
function autoAcidYield() { return F.autoAcidYield(lv('autoAcidPurity')); }
function autoFireInterval() { return F.autoFireInterval(lv('autoFireSpeed')); }
function autoFireYield() { return F.autoFireYield(lv('autoFireHeat')); }
function autoSaleInterval() { return F.autoSaleInterval(lv('autoSaleSpeed')); }
function autoSalePrice() { return F.autoSalePrice(lv('autoMarkup')); }

// --- Кузница ---
function recipeFor(key) {
  const a = amuletDef(key);
  const disc = 1 - F.forgeDiscount(lv('forgeDiscount'));
  const out = {};
  for (const item in a.recipe) out[item] = Math.max(1, Math.ceil(a.recipe[item] * disc));
  return out;
}

function craftTimeMs(key) {
  const a = amuletDef(key);
  return Math.max(BAL.craftMinMs, Math.round(a.craftMin * 60000 * (1 - F.forgeSpeed(lv('forgeSpeed')))));
}
