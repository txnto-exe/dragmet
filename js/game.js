'use strict';
// Игровая логика: что происходит, когда игрок что-то делает, и что меняется со временем.
// Здесь нет работы с разметкой — только с состоянием G. Показ на экране — в ui.js.

// То, что живёт только пока открыта игра (не сохраняется)
const session = {
  digLabel: TEXT.digLabels[0],       // надпись на кнопке копки во время паузы
  graceUntil: { acid: 0, fire: 0 },  // до какого момента можно запускать без мини-игры
};

// ===== Копка =====

/** Случайный предмет из локации с учётом весов (и амулета «Мусорщик»). */
function pickLoot(loc) {
  const weight = k => loc.loot[k] * (hasAmulet('scavenger') && ITEMS[k].tier === 'jk' ? 3 : 1);
  const keys = Object.keys(loc.loot);
  let r = Math.random() * keys.reduce((sum, k) => sum + weight(k), 0);
  for (const k of keys) {
    if (r < weight(k)) return k;
    r -= weight(k);
  }
  return keys[0];
}

/** Любой предмет локации с равной вероятностью. */
function pickLootEqual(loc) {
  return pickRandom(Object.keys(loc.loot));
}

/** «Хороший глаз» и амулеты могут заменить дешёвую находку на другую. */
function maybeUpgradeDrop(item, loc) {
  if (!isCheapItem(item)) return item;
  if (Math.random() < F.goodEye(lv('goodeye'))) return pickLootEqual(loc);
  if (hasAmulet('legendHunter') && Math.random() < 0.05) return 'legend';
  if (hasAmulet('goldVein') && Math.random() < 0.15) return pickLootEqual(loc);
  return item;
}

/**
 * Одна находка в локации. byWorker — копает работяга: не тратит запас точки,
 * своя удача, без сообщений и звуков. Возвращает false, если копать нельзя.
 */
function scavengeOnce(loc, byWorker) {
  const ls = G.run.locs[loc.key];
  if (!ls.unlocked) return false;
  if (!byWorker && ls.stock <= 0) return false;
  if (totalJunk() >= capMax()) return false;

  const item = maybeUpgradeDrop(pickLoot(loc), loc);
  const luck = byWorker ? workerLuckChance() : F.luck(lv('luck'));
  const isDouble = Math.random() < luck && totalJunk() + 2 <= capMax();
  G.run.junk[item] += isDouble ? 2 : 1;
  const isNew = !G.meta.found[item];
  G.meta.found[item] = (G.meta.found[item] || 0) + (isDouble ? 2 : 1);
  if (byWorker) return true;

  ls.stock--;
  const it = ITEMS[item];
  let msg = isDouble ? `Двойной дроп! ${it.name} ×2`
    : `${it.prefix || 'Нашёл: '}${it.name}`;
  if (isNew) msg = `Новое в альбоме! ${it.name}`;
  flashToast(msg, it.tier, item);
  sceneOnFind(item, isDouble);
  sndFind(item);
  if (isDouble) sndDoubleDrop();
  return true;
}

/** Кнопка «Порыться». */
function dig() {
  if (G.run.scavCd > 0) { sndCooldown(); vibe(6); return; }
  const loc = locDef(G.run.activeLoc);
  if (scavengeOnce(loc, false)) {
    G.run.scavCd = scavCdMax();
    session.digLabel = pickRandom(TEXT.digLabels);
    saveGame();
    return;
  }
  if (G.run.locs[loc.key].stock <= 0) flashToast('Точка пуста — жди');
  else flashToast('Склад забит — переработай лом');
  shakeDigBtn(); sndDeny(); vibe(40);
}

function unlockLoc(key) {
  const loc = locDef(key), ls = G.run.locs[key];
  if (ls.unlocked) return;
  const cost = locUnlockCost(loc);
  if (G.run.cash < cost) { sndDeny(); vibe(40); return; }
  G.run.cash -= cost;
  ls.unlocked = true;
  G.run.activeLoc = key;
  sndBuy(); vibe(25); bumpCash();
  saveGame();
}

/** Стрелки на сцене: листать точки сбора. Открытая точка сразу становится текущей. */
function stepLoc(delta) {
  const i = clamp(G.ui.locView + delta, 0, LOCATIONS.length - 1);
  if (i === G.ui.locView) return;
  G.ui.locView = i;
  const loc = LOCATIONS[i];
  if (G.run.locs[loc.key].unlocked) G.run.activeLoc = loc.key;
  sndTab(); vibe(8);
  saveGame();
}

function toggleLock(item) {
  G.run.locked[item] = !G.run.locked[item];
  sndSelect(); vibe(10);
  saveGame();
}

// ===== Кислота =====

/** Кнопка «Растворить»: сначала мини-игра (если не прошло 3 сек после прошлой победы). */
function startAcid(idx) {
  const bath = G.run.acid[idx];
  if (!bath || bath.active) return;
  if (junkGold(true) <= 0) { sndDeny(); vibe(30); return; }
  if (Date.now() < session.graceUntil.acid) runAcid(idx);
  else openAcidMiniGame(() => { session.graceUntil.acid = Date.now() + BAL.minigameGraceMs; runAcid(idx); });
}

/**
 * Запустить ванну. Если свободных ванн две — каждая берёт половину лома
 * (по каждому предмету поровну, остаток по одной штуке раздаётся самым «дробным»).
 */
function runAcid(idx) {
  const bath = G.run.acid[idx];
  if (!bath || bath.active) return;
  const free = freeVessels(G.run.acid);
  if (free <= 0 || junkGold(true) <= 0) { sndDeny(); vibe(30); return; }
  const fraction = 1 / free;

  const plan = [];
  let total = 0;
  for (const k of ITEM_KEYS) {
    const cnt = G.run.junk[k];
    if (G.run.locked[k] || cnt <= 0) continue;
    total += cnt;
    const share = cnt * fraction;
    plan.push({ k, cnt, take: Math.floor(share), rem: share - Math.floor(share) });
  }
  const target = Math.floor(total * fraction);
  let taken = plan.reduce((sum, x) => sum + x.take, 0);
  plan.sort((a, b) => b.rem - a.rem);
  while (taken < target) {
    const x = plan.find(x => x.take < x.cnt);
    if (!x) break;
    x.take++;
    taken++;
  }

  let gold = 0;
  for (const x of plan) {
    G.run.junk[x.k] -= x.take;
    gold += x.take * ITEMS[x.k].gold;
  }
  if (gold <= 0) return;

  // Вся потеря цикла срезается здесь, один раз
  bath.yieldAmt = gold * cycleEffEffective();
  bath.active = true;
  bath.progress = 0;
  bath.duration = acidDuration();
  sndStartProcess(); vibe(20);
  saveGame();
}

// ===== Печь =====

function startFurnace(idx) {
  const f = G.run.fire[idx];
  if (!f || f.active) return;
  if (G.run.solution <= 0) { sndDeny(); vibe(30); return; }
  if (Date.now() < session.graceUntil.fire) runFurnace(idx);
  else openFireMiniGame(() => { session.graceUntil.fire = Date.now() + BAL.minigameGraceMs; runFurnace(idx); });
}

/** Запустить печь: берёт раствор (поровну на свободные печи), потерь нет. */
function runFurnace(idx) {
  const f = G.run.fire[idx];
  if (!f || f.active) return;
  const free = freeVessels(G.run.fire);
  if (free <= 0 || G.run.solution <= 0) { sndDeny(); vibe(30); return; }
  const taken = G.run.solution / free;
  G.run.solution -= taken;
  f.yieldAmt = taken;
  f.active = true;
  f.progress = 0;
  f.duration = fireDuration();
  vibe(20);
  saveGame();
}

// ===== Продажа =====

const MIN_SELLABLE = 0.0005;

function sellIngots() {
  if (G.run.ingots <= MIN_SELLABLE) { sndDeny(); vibe(30); return; }
  openPriceGame();
}

/** Итог стоп-игры: продаём все слитки по цене price (до бонусов). */
function finishSale(price, hit, msg) {
  const bonus = hasAmulet('generousBuyer') ? 1.15 : 1;
  const earned = G.run.ingots * price * priceMultiplier() * bonus;
  G.run.cash += earned;
  G.run.ingots = 0;
  sndCoins(); bumpCash(); flashSellBtn();
  sceneOnSale(hit);
  saveGame();
  flashToast(`${msg} +${fmt(Math.floor(earned))} ₽`, hit ? 'lg' : null);
}

// ===== Престиж =====

function doPrestige() {
  if (isMaxPrestige()) {
    sndDeny(); vibe(40);
    flashToast(`Престиж ${BAL.prestigeMaxLevel} — максимум`);
    return;
  }
  if (G.run.cash < F.prestigeThreshold(G.meta.prestige)) { sndDeny(); vibe(40); return; }

  const level = G.meta.prestige + 1;
  const reward = F.prestigeReward(level);
  G.meta.prestige = level;
  G.meta.points += reward;
  G.meta.forgeUnlocked = true;
  for (const loc of LOCATIONS) G.meta.autoTimers[loc.key] = 0;

  // Амулеты «на престижи» теряют один престиж срока
  for (const key in G.meta.amulets) {
    const entry = G.meta.amulets[key];
    if (amuletDef(key).dur.prestiges && --entry.prestigeLeft <= 0) removeAmulet(key);
  }

  // Новый забег: всё, что в G.run, начинается заново
  G.run = makeRun();
  fillUpgradeLevels(G);
  G.run.cash = F.startCash(lv('startCash'));
  G.ui.locView = 0;
  G.ui.badgeSeen = makeUi().badgeSeen;

  updateBloom();
  sndPrestige(); vibe(80); flashPrestBtn();
  saveGame();
  switchTab('dig');
  playPrestigeCut(level, reward);
}

// ===== Кузница =====

function canCraft(key) {
  const rec = recipeFor(key);
  return Object.keys(rec).every(k => G.run.junk[k] >= rec[k]);
}

function isCrafting(key) {
  return G.meta.crafts.some(c => c.id === key);
}

function forgeSlotsBusy() {
  return G.meta.crafts.length >= maxForges();
}

function craftAmulet(key) {
  const deny = msg => { sndDeny(); vibe(30); flashToast(msg); };
  if (forgeSlotsBusy()) return deny(lv('twoForges') ? 'Оба горна заняты' : 'Кузнец уже занят');
  if (G.meta.amulets[key]) return deny('Уже есть');
  if (isCrafting(key)) return deny('Уже куётся');
  if (!canCraft(key)) return deny('Не хватает материалов');

  const rec = recipeFor(key);
  for (const k in rec) G.run.junk[k] -= rec[k];
  G.meta.crafts.push({ id: key, startedAt: Date.now(), duration: craftTimeMs(key) });
  sndCraftStart(); vibe(30);
  saveGame();
}

function grantAmulet(key) {
  const a = amuletDef(key);
  if (a.dur.prestiges) {
    // «Дольше живут»: +1 престиж срока за уровень
    G.meta.amulets[key] = { prestigeLeft: a.dur.prestiges + lv('forgeDuration') };
  } else {
    const ms = a.dur.hours * 3600000 * (1 + F.forgeDuration(lv('forgeDuration')));
    G.meta.amulets[key] = { expiresAt: Date.now() + ms };
  }
}

function removeAmulet(key) {
  delete G.meta.amulets[key];
  if (G.meta.equipped === key) G.meta.equipped = null;
}

function equipAmulet(key) {
  if (!G.meta.amulets[key]) return;
  G.meta.equipped = key;
  updateBloom(); sndBuy(); vibe(25);
  saveGame();
}

function unequipAmulet() {
  G.meta.equipped = null;
  updateBloom(); sndToggle(); vibe(15);
  saveGame();
}

/** Растворить амулет: вернуть 40% ресурсов рецепта. */
function dissolveAmulet(key) {
  if (!G.meta.amulets[key]) return;
  const rec = recipeFor(key);
  const returned = [];
  for (const k in rec) {
    const amount = Math.floor(rec[k] * BAL.dissolveReturn);
    if (amount <= 0) continue;
    G.run.junk[k] += amount;
    returned.push(`${ITEMS[k].name} ×${amount}`);
  }
  removeAmulet(key);
  updateBloom();
  flashToast('Растворено. Вернулось: ' + (returned.length ? returned.join(', ') : 'ничего'), 'rp');
  saveGame();
}

function amuletTimeLeftText(key) {
  const entry = G.meta.amulets[key];
  if (!entry) return '';
  if (amuletDef(key).dur.prestiges) return `Осталось: ${entry.prestigeLeft} прест.`;
  const ms = entry.expiresAt - Date.now();
  return ms <= 0 ? 'Истёк' : 'Осталось: ' + fmtHoursMinutes(ms);
}

// ===== Течение времени =====

function tickVessels(list, dt, onDone) {
  let running = false;
  for (const v of list) {
    if (!v.active) continue;
    running = true;
    v.progress += dt;
    if (v.progress >= v.duration) {
      onDone(v.yieldAmt);
      v.active = false;
      v.progress = 0;
    }
  }
  return running;
}

function tickRegen(dt) {
  for (const loc of LOCATIONS) {
    const ls = G.run.locs[loc.key];
    if (!ls.unlocked || ls.stock >= loc.stock) continue;
    ls.regenTimer += dt;
    const iv = locRegenInterval(loc);
    while (ls.regenTimer >= iv && ls.stock < loc.stock) {
      ls.regenTimer -= iv;
      ls.stock++;
    }
    if (ls.stock >= loc.stock) ls.regenTimer = 0;
  }
}

/** Работяги за рубли: копают в своей точке, не тратя её запас. */
function tickWorkers(dt) {
  const cd = F.workerCd(lv('autoSpeed'));
  for (const loc of LOCATIONS) {
    if (!G.meta.autoDig[loc.key] || !G.run.locs[loc.key].unlocked) continue;
    G.meta.autoTimers[loc.key] += dt;
    if (G.meta.autoTimers[loc.key] >= cd) {
      // Склад полон — попробуем чуть позже
      G.meta.autoTimers[loc.key] = scavengeOnce(loc, true) ? 0 : cd * 0.9;
    }
  }
}

/** Авто-фабрика (после покупки «Автоматизации»): лом → раствор → слитки → деньги. */
function tickFactory(dt) {
  if (!lv('automation')) return;
  const a = G.meta.auto;

  // Авто-работяги таскают лом на авто-склад
  if (a.junk < autoCap()) {
    a.workerTimer += dt;
    const iv = autoWorkerInterval();
    if (a.workerTimer >= iv) {
      a.workerTimer -= iv;
      a.junk++;
    }
  }

  // Авто-кислота: 1 лом → раствор
  if (a.junk <= 0) a.acidTimer = 0;
  else {
    a.acidTimer += dt;
    const iv = autoAcidInterval();
    if (a.acidTimer >= iv) {
      a.acidTimer -= iv;
      a.junk--;
      a.solution += autoAcidYield();
    }
  }

  // Авто-печь: 1 раствор → слитки
  if (a.solution <= 0) a.fireTimer = 0;
  else {
    a.fireTimer += dt;
    const iv = autoFireInterval();
    if (a.fireTimer >= iv) {
      a.fireTimer -= iv;
      a.solution--;
      a.ingots += autoFireYield();
    }
  }

  // Авто-продажа: продаёт все авто-слитки по таймеру
  if (a.ingots <= 0) a.saleTimer = 0;
  else {
    a.saleTimer += dt;
    if (a.saleTimer >= autoSaleInterval()) {
      a.saleTimer = 0;
      const earned = a.ingots * autoSalePrice();
      a.ingots = 0;
      G.run.cash += earned;
      bumpCash(); sndAutoSale(); showAutoSalePop(Math.floor(earned));
    }
  }
}

function tickForge() {
  const now = Date.now();
  for (let i = G.meta.crafts.length - 1; i >= 0; i--) {
    const c = G.meta.crafts[i];
    if (now - c.startedAt < c.duration) continue;
    grantAmulet(c.id);
    G.meta.crafts.splice(i, 1);
    sndCraftDone(); vibe(60);
    flashToast('Готово: ' + amuletDef(c.id).name, 'lg');
    saveGame();
  }
  for (const key in G.meta.amulets) {
    const entry = G.meta.amulets[key];
    if (entry.expiresAt && entry.expiresAt <= now) {
      removeAmulet(key);
      updateBloom();
    }
  }
}

/** Один шаг времени (dt — сколько мс прошло с прошлого кадра). */
function tick(dt) {
  if (G.run.scavCd > 0) G.run.scavCd = Math.max(0, G.run.scavCd - dt);
  const acidRunning = tickVessels(G.run.acid, dt, amt => { G.run.solution += amt; });
  const fireRunning = tickVessels(G.run.fire, dt, amt => { G.run.ingots += amt; });
  updateSoundLoops(acidRunning, fireRunning);
  tickRegen(dt);
  tickWorkers(dt);
  tickFactory(dt);
  tickForge();
}

// ===== Оффлайн-доход =====

/** Сколько ₽ в час приносят работяги за рубли (до коэффициента оффлайна). */
function workersIncomePerHour() {
  let gold = 0;
  const digsPerHour = 3600000 / Math.max(F.workerCd(lv('autoSpeed')), 100);
  for (const loc of LOCATIONS) {
    if (!G.meta.autoDig[loc.key] || !G.run.locs[loc.key].unlocked) continue;
    let totalW = 0, avgGold = 0;
    for (const k in loc.loot) {
      const w = loc.loot[k] * (hasAmulet('scavenger') && ITEMS[k].tier === 'jk' ? 3 : 1);
      totalW += w;
      avgGold += w * ITEMS[k].gold;
    }
    if (totalW <= 0) continue;
    gold += digsPerHour * (avgGold / totalW) * (1 + workerLuckChance()) * cycleEffEffective();
  }
  return gold * BAL.priceAvgOffline * priceMultiplier();
}

/** Сколько ₽ в час даёт авто-фабрика (упирается в самый медленный участок). */
function factoryIncomePerHour() {
  if (!lv('automation')) return 0;
  const perHour = ms => 3600000 / Math.max(ms, 100);
  const yA = autoAcidYield(), yF = autoFireYield();
  const junkPerHour = Math.min(perHour(autoWorkerInterval()), perHour(autoAcidInterval()), perHour(autoFireInterval()) / yA);
  return junkPerHour * yA * yF * autoSalePrice();
}

/**
 * Догнать время, пока игры не было на экране (свёрнута или закрыта).
 *   • Меньше 5 минут — честно «проматываем» игру: процессы, работяги, фабрика идут как обычно.
 *   • 5 минут и больше — начисляем оффлайн-доход по формуле, а начатые процессы
 *     (кислота, печь) успевают закончиться и точки сбора восстанавливаются.
 * Возвращает данные для окна «Пока тебя не было» или null.
 */
function catchUp() {
  const elapsedMs = Math.max(0, Date.now() - G.lastSeenTs);
  G.lastSeenTs = Date.now();
  if (elapsedMs < BAL.offlineMinSec * 1000) {
    for (let left = elapsedMs; left > 0; left -= 1000) tick(Math.min(1000, left));
    return null;
  }
  tickVessels(G.run.acid, elapsedMs, amt => { G.run.solution += amt; });
  tickVessels(G.run.fire, elapsedMs, amt => { G.run.ingots += amt; });
  tickRegen(elapsedMs);
  G.run.scavCd = 0;
  tickForge();
  return applyOfflineIncome(elapsedMs / 1000);
}

/** Начислить оффлайн-доход за elapsedSec секунд. Возвращает данные для окна или null. */
function applyOfflineIncome(elapsedSec) {
  const hours = Math.min(elapsedSec / 3600, F.offlineHours(lv('offlineCap')));
  const manual = Math.floor(workersIncomePerHour() * hours * F.offlineRate(lv('offlineRate')) / 100);
  const auto = Math.floor(factoryIncomePerHour() * hours * BAL.autoOfflineRate);
  const total = manual + auto;
  if (total <= 0) return null;
  G.run.cash += total;
  return { total, manual, auto, elapsedSec, hasAuto: lv('automation') > 0 };
}
