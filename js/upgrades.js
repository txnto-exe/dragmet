'use strict';
// ТАБЛИЦА ВСЕХ ПРОКАЧЕК.
// Каждая прокачка описана здесь один раз. По этой таблице игра сама:
//   • рисует строку на вкладке «Прокачка»,
//   • считает цену и проверяет максимум,
//   • покупает,
//   • считает бейдж на вкладке,
//   • сохраняет и загружает уровень.
// Чтобы добавить прокачку — добавь строку сюда и используй lv('ключ') в формуле.
//
// Поля:
//   key       — ключ (под ним хранится уровень)
//   group     — в каком аккордеоне показывать (см. UPG_GROUPS)
//   currency  — 'cash' (рубли, сбрасывается при престиже) или 'points' (очки престижа, навсегда)
//   max       — максимальный уровень (1 = разовая покупка)
//   start     — стартовый уровень (по умолчанию 0)
//   cost(l)   — цена перехода с уровня l на l+1
//   desc(l,n) — описание: l — текущий уровень, n — следующий (на максимуме n = l)
//   style     — особый цвет кнопки ('offline')
//   requires  — ключ разовой прокачки, без которой эта недоступна
//   doneLabel — надпись на кнопке после разовой покупки
//   onBuy()   — что сделать сразу после покупки

/** Цена, которая растёт в mult раз за уровень, с округлением на каждом шаге. */
function stepCost(base, mult, steps) {
  let c = base;
  for (let i = 0; i < steps; i++) c = Math.round(c * mult);
  return c;
}
/** Цена base × mult^уровень. */
function powCost(base, mult) {
  return l => Math.round(base * Math.pow(mult, l));
}
const pct = x => Math.round(x * 100);
const sec = (ms, d) => (ms / 1000).toFixed(d);

// Аккордеоны вкладки «Прокачка». visible() — показывать ли группу сейчас.
const UPG_GROUPS = [
  { key: 'eq',         panel: 'normal', title: 'Оборудование' },
  { key: 'spd',        panel: 'normal', title: 'Скорость процесса' },
  { key: 'luck',       panel: 'normal', title: 'Удача' },
  { key: 'income',     panel: 'normal', title: 'Доход' },
  { key: 'regen',      panel: 'normal', title: 'Восстановление точек' },
  { key: 'auto',       panel: 'normal', title: 'Автоматизация' },
  { key: 'forge',      panel: 'normal', title: 'Кузница', last: true, visible: () => G.meta.forgeUnlocked },
  { key: 'pbonus',     panel: 'prest',  title: 'Бонусы престижа' },
  { key: 'pupg2',      panel: 'prest',  title: 'Улучшения II' },
  { key: 'automation', panel: 'prest',  title: 'Автоматизация', last: true },
];

const UPGRADES = [
  // ===== Оборудование =====
  { key: 'acid', group: 'eq', currency: 'cash', name: 'Кислота почище', max: 15, start: 1,
    cost: l => stepCost(170, 1.65, l - 1),
    desc: (l, n) => `Общая эффективность переработки лома в слитки: ${pct(F.cycleEff(l, lv('fire'), lv('acidII'), lv('fireII')))}% → ${pct(F.cycleEff(n, lv('fire'), lv('acidII'), lv('fireII')))}%` },
  { key: 'fire', group: 'eq', currency: 'cash', name: 'Печь помощнее', max: 15, start: 1,
    cost: l => stepCost(170, 1.65, l - 1),
    desc: (l, n) => `Общая эффективность переработки лома в слитки: ${pct(F.cycleEff(lv('acid'), l, lv('acidII'), lv('fireII')))}% → ${pct(F.cycleEff(lv('acid'), n, lv('acidII'), lv('fireII')))}%` },
  { key: 'cap', group: 'eq', currency: 'cash', name: 'Складское место', max: 25, start: 1,
    cost: l => stepCost(120, 1.55, l - 1),
    desc: (l, n) => `сколько лома влезает на склад: ${capMax()} → ${capMax() + F.cap(n) - F.cap(l)}` },
  { key: 'hold', group: 'eq', currency: 'cash', name: 'Турбо-палец', max: 1,
    cost: () => 1200,
    desc: l => l ? 'куплено — зажми кнопку и она будет работать сама' : 'покупка один раз — зажми кнопку, действие повторится' },

  // ===== Скорость процесса =====
  { key: 'scavspd', group: 'spd', currency: 'cash', name: 'Копать быстрее', max: 10,
    cost: l => stepCost(495, 1.7, l),
    desc: (l, n) => `пауза между копками: ${sec(F.scavCd(l), 2)}с → ${sec(F.scavCd(n), 2)}с` },
  { key: 'acidspd', group: 'spd', currency: 'cash', name: 'Кислота быстрее', max: 20,
    cost: l => stepCost(495, 1.7, l),
    desc: (l, n) => `время растворения: ${sec(acidDuration(l), 1)}с → ${sec(acidDuration(n), 1)}с` },
  { key: 'firespd', group: 'spd', currency: 'cash', name: 'Печь быстрее', max: 20,
    cost: l => stepCost(495, 1.7, l),
    desc: (l, n) => `время выпаривания: ${sec(fireDuration(l), 1)}с → ${sec(fireDuration(n), 1)}с` },
  { key: 'secondacid', group: 'spd', currency: 'cash', name: 'Второй бак кислоты', max: 1,
    cost: () => 3000, onBuy: ensureVessels,
    desc: l => l ? 'куплено — два бака работают одновременно' : 'покупка один раз — можно запустить вторую кислоту параллельно' },
  { key: 'secondfire', group: 'spd', currency: 'cash', name: 'Вторая печь', max: 1,
    cost: () => 5000, onBuy: ensureVessels,
    desc: l => l ? 'куплено — две печи работают одновременно' : 'покупка один раз — можно запустить вторую печь параллельно' },

  // ===== Удача =====
  { key: 'goodeye', group: 'luck', currency: 'cash', name: 'Хороший глаз', max: 20,
    cost: l => stepCost(500, 1.8, l),
    desc: (l, n) => `шанс заменить находку предметом из этой локации: ${pct(F.goodEye(l))}% → ${pct(F.goodEye(n))}%` },
  { key: 'luck', group: 'luck', currency: 'cash', name: 'Чуйка на золото', max: 15,
    cost: l => stepCost(700, 1.8, l),
    desc: (l, n) => `шанс найти две вещи: ${pct(F.luck(l))}% → ${pct(F.luck(n))}%` },

  // ===== Доход =====
  { key: 'reputation', group: 'income', currency: 'cash', name: 'Репутация', max: 10,
    cost: powCost(2500, 1.7),
    desc: (l, n) => `наценка скупщика: +${F.reputation(l)}% → +${F.reputation(n)}%` },
  { key: 'wideZone', group: 'income', currency: 'cash', name: 'Широкая зона', max: 5,
    cost: powCost(5000, 1.7),
    desc: (l, n) => `зелёная зона в стоп-игре: ${F.wideZone(l)}% → ${F.wideZone(n)}%` },
  { key: 'offlineRate', group: 'income', currency: 'cash', name: 'Коэффициент оффлайна', max: 15, style: 'offline',
    cost: powCost(2000, 1.55),
    desc: (l, n) => `доход в оффлайне: ${F.offlineRate(l)}% → ${F.offlineRate(n)}%` },
  { key: 'offlineCap', group: 'income', currency: 'cash', name: 'Лимит оффлайна', max: 9, style: 'offline',
    cost: powCost(1500, 1.7),
    desc: (l, n) => `максимум часов: ${F.offlineHours(l)} → ${F.offlineHours(n)} ч` },

  // ===== Восстановление точек (по строке на каждую открытую локацию) =====
  ...LOCATIONS.map(loc => ({
    key: 'regen:' + loc.key, group: 'regen', currency: 'cash', name: loc.name, max: 10,
    get: g => g.run.locs[loc.key].regenLv,
    set: (g, v) => { g.run.locs[loc.key].regenLv = v; },
    visible: () => G.run.locs[loc.key].unlocked,
    cost: l => Math.round(loc.regenCost * Math.pow(1.8, l)),
    desc: (l, n) => `точка пополняется: ${sec(F.regenInterval(loc, l), 1)}с → ${sec(F.regenInterval(loc, n), 1)}с на одну штуку`,
  })),

  // ===== Автоматизация: работяги за рубли =====
  { key: 'autoSpeed', group: 'auto', currency: 'cash', name: 'Скорость работяг', max: 10,
    cost: powCost(5000, 1.6),
    desc: (l, n) => `время на один предмет: ${sec(F.workerCd(l), 2)}с → ${sec(F.workerCd(n), 2)}с` },
  { key: 'autoLuck', group: 'auto', currency: 'cash', name: 'Удача работяг', max: 10,
    cost: powCost(4000, 1.7),
    desc: (l, n) => `шанс двойного дропа: ${F.workerLuck(l)}% → ${F.workerLuck(n)}%`,
    extra: () => hasAmulet('nightShift') ? ' · +10% от амулета' : '' },
  ...LOCATIONS.map(loc => ({
    key: 'autoDig:' + loc.key, group: 'auto', currency: 'cash', name: loc.name, max: 1, doneLabel: '✓ куплен',
    get: g => g.meta.autoDig[loc.key] ? 1 : 0,
    set: (g, v) => { g.meta.autoDig[loc.key] = v > 0; },
    visible: () => G.run.locs[loc.key].unlocked,
    cost: () => loc.autoDigCost,
    desc: l => l ? 'куплен — копает сам' : 'покупка один раз — работяга копает в этой точке без остановки',
  })),

  // ===== Кузница =====
  { key: 'forgeSpeed', group: 'forge', currency: 'cash', name: 'Быстрее куём', max: 7,
    cost: powCost(8000, 1.7),
    desc: (l, n) => `время ковки: −${pct(F.forgeSpeed(l))}% → −${pct(F.forgeSpeed(n))}%` },
  { key: 'forgeDiscount', group: 'forge', currency: 'cash', name: 'Дешевле рецепты', max: 10,
    cost: powCost(12000, 1.8),
    desc: (l, n) => `рецепты дешевле: −${pct(F.forgeDiscount(l))}% → −${pct(F.forgeDiscount(n))}%` },
  { key: 'forgeDuration', group: 'forge', currency: 'cash', name: 'Дольше живут', max: 5,
    cost: powCost(15000, 1.9),
    desc: (l, n) => `амулеты живут дольше: +${l} прест. / +${pct(F.forgeDuration(l))}% → +${n} прест. / +${pct(F.forgeDuration(n))}%` },
  { key: 'twoForges', group: 'forge', currency: 'cash', name: 'Два горна', max: 1,
    cost: () => 25000,
    desc: l => l ? 'куплено — кузнец куёт два амулета одновременно' : 'покупка один раз — кузнец сможет ковать два амулета одновременно' },

  // ===== Престиж: бонусы =====
  { key: 'bonusBoost', group: 'pbonus', currency: 'points', name: 'Усиление бонуса', max: 20,
    cost: l => 1 + l,
    desc: (l, n) => `база бонуса за престиж: +${F.bonusBase(l).toFixed(2)}% → +${F.bonusBase(n).toFixed(2)}%` },
  { key: 'startCash', group: 'pbonus', currency: 'points', name: 'Стартовый капитал', max: 20,
    cost: l => 2 + l * 2,
    desc: (l, n) => `стартовый капитал: ${fmt(F.startCash(l))} → ${fmt(F.startCash(n))} ₽` },
  { key: 'locDiscount', group: 'pbonus', currency: 'points', name: 'Скидка на локации', max: 15,
    cost: l => 3 + l * 3,
    desc: (l, n) => `скидка на открытие точек: −${pct(F.locDiscount(l))}% → −${pct(F.locDiscount(n))}%` },

  // ===== Престиж: улучшения II =====
  { key: 'acidII', group: 'pupg2', currency: 'points', name: 'Кислота II', max: 10,
    cost: l => 2 + l * 2,
    desc: (l, n) => `доп. эффективность переработки: +${l}% → +${n}%` },
  { key: 'fireII', group: 'pupg2', currency: 'points', name: 'Печь II', max: 10,
    cost: l => 2 + l * 2,
    desc: (l, n) => `доп. эффективность переработки: +${l}% → +${n}%` },
  { key: 'capII', group: 'pupg2', currency: 'points', name: 'Склад II', max: 25,
    cost: l => 2 + l * 2,
    desc: (l, n) => `доп. места на складе: +${F.capII(l)} → +${F.capII(n)}` },

  // ===== Престиж: авто-фабрика =====
  { key: 'automation', group: 'automation', currency: 'points', name: 'Автоматизация', max: 1,
    cost: () => 20,
    desc: l => l ? 'куплена — фабрика запущена' : 'параллельная фабрика — работает сама, отдельно от ручной. Ручное всегда выгоднее.' },
  ...[
    ['autoWorkers', 'Авто-работяги', 20, 'как часто авто-работяги копают лом',
      (l, n) => `интервал копки: ${sec(F.autoWorkerInterval(l), 1)}с → ${sec(F.autoWorkerInterval(n), 1)}с`],
    ['autoCapLv', 'Авто-склад', 15, 'вместимость авто-склада',
      (l, n) => `вместимость: ${F.autoCap(l)} → ${F.autoCap(n)}`],
    ['autoAcidSpeed', 'Авто-кислота (скорость)', 20, 'скорость переработки в авто-кислоте',
      (l, n) => `цикл: ${sec(F.autoAcidInterval(l), 1)}с → ${sec(F.autoAcidInterval(n), 1)}с`],
    ['autoAcidPurity', 'Авто-кислота (чистота)', 15, 'чистота авто-кислоты — меньше потерь',
      (l, n) => `выход: ${pct(F.autoAcidYield(l))}% → ${pct(F.autoAcidYield(n))}%`],
    ['autoFireSpeed', 'Авто-печь (скорость)', 20, 'скорость плавки в авто-печи',
      (l, n) => `цикл: ${sec(F.autoFireInterval(l), 1)}с → ${sec(F.autoFireInterval(n), 1)}с`],
    ['autoFireHeat', 'Авто-печь (жар)', 15, 'жар авто-печи — меньше потерь',
      (l, n) => `выход: ${pct(F.autoFireYield(l))}% → ${pct(F.autoFireYield(n))}%`],
    ['autoSaleSpeed', 'Авто-продажа (скорость)', 10, 'как часто авто-продажа сбывает слитки',
      (l, n) => `интервал продажи: ${sec(F.autoSaleInterval(l), 1)}с → ${sec(F.autoSaleInterval(n), 1)}с`],
    ['autoMarkup', 'Авто-наценка', 10, 'наценка авто-продажи',
      (l, n) => `цена: ${F.autoSalePrice(l)} → ${F.autoSalePrice(n)} ₽/г`],
  ].map(([key, name, max, lockedDesc, desc]) => ({
    key, group: 'automation', currency: 'points', name, max, requires: 'automation',
    cost: l => l + 1,
    lockedDesc,
    desc,
  })),
];

const UPG_BY_KEY = {};
for (const u of UPGRADES) UPG_BY_KEY[u.key] = u;

// ===== Работа с уровнями =====

function upgLevel(u, g = G) {
  if (u.get) return u.get(g);
  const store = u.currency === 'cash' ? g.run.lv : g.meta.lv;
  return store[u.key];
}

function upgSetLevel(u, value, g = G) {
  if (u.set) return u.set(g, value);
  const store = u.currency === 'cash' ? g.run.lv : g.meta.lv;
  store[u.key] = value;
}

/** Уровень прокачки по ключу: lv('acid'). */
function lv(key) {
  return upgLevel(UPG_BY_KEY[key]);
}

/** Проставить стартовые уровни всем прокачкам, у которых уровня ещё нет. */
function fillUpgradeLevels(g) {
  for (const u of UPGRADES) {
    if (u.get) continue;
    const store = u.currency === 'cash' ? g.run.lv : g.meta.lv;
    if (typeof store[u.key] !== 'number') store[u.key] = u.start || 0;
  }
}

function upgVisible(u) {
  const group = UPG_GROUPS.find(gr => gr.key === u.group);
  if (group.visible && !group.visible()) return false;
  return !u.visible || u.visible();
}

function upgUnlocked(u) {
  return !u.requires || lv(u.requires) > 0;
}

function upgMaxed(u) {
  return upgLevel(u) >= u.max;
}

function upgCost(u) {
  return u.cost(upgLevel(u));
}

function wallet(u) {
  return u.currency === 'cash' ? G.run.cash : G.meta.points;
}

/** Можно ли купить прямо сейчас (видна, доступна, не максимум, хватает денег). */
function upgAffordable(u) {
  return upgVisible(u) && upgUnlocked(u) && !upgMaxed(u) && wallet(u) >= upgCost(u);
}

/** Текст описания с уровнем: «… (уровень 3/10)». */
function upgDescription(u) {
  const l = upgLevel(u);
  if (!upgUnlocked(u) && u.lockedDesc) return `${u.lockedDesc} (уровень ${l}/${u.max})`;
  const next = l >= u.max ? l : l + 1;
  let text = u.desc(l, next);
  if (u.max > 1) text += ` (уровень ${l}/${u.max})`;
  if (u.extra) text += u.extra();
  return text;
}

/** Купить прокачку. Возвращает true, если покупка прошла. */
function buyUpgrade(u) {
  if (!upgVisible(u) || upgMaxed(u)) return false;
  if (!upgUnlocked(u) || wallet(u) < upgCost(u)) {
    sndDeny(); vibe(30);
    return false;
  }
  const cost = upgCost(u);
  if (u.currency === 'cash') G.run.cash -= cost;
  else G.meta.points -= cost;
  upgSetLevel(u, upgLevel(u) + 1);
  if (u.onBuy) u.onBuy();
  sndBuy(); vibe(25);
  if (u.currency === 'cash') bumpCash();
  saveGame();
  return true;
}

/** Ванн и печей столько, сколько куплено (1 или 2). */
function ensureVessels() {
  const wantAcid = 1 + lv('secondacid');
  const wantFire = 1 + lv('secondfire');
  while (G.run.acid.length < wantAcid) G.run.acid.push(makeVessel());
  while (G.run.fire.length < wantFire) G.run.fire.push(makeVessel());
  G.run.acid.length = wantAcid;
  G.run.fire.length = wantFire;
}
