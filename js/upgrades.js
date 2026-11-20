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
const sec = (ms, d) => String(parseFloat((ms / 1000).toFixed(d))).replace('.', ',');

// Разделы вкладки «Прокачка» (кнопки-чипсы сверху). short — надпись на чипсе. visible() — показывать ли сейчас.
const UPG_GROUPS = [
  { key: 'eq',         panel: 'normal', title: 'Оборудование', short: 'Оборудование' },
  { key: 'spd',        panel: 'normal', title: 'Скорость процесса', short: 'Скорость' },
  { key: 'luck',       panel: 'normal', title: 'Удача', short: 'Удача' },
  { key: 'income',     panel: 'normal', title: 'Доход', short: 'Доход' },
  { key: 'regen',      panel: 'normal', title: 'Восстановление точек', short: 'Точки' },
  { key: 'auto',       panel: 'normal', title: 'Работяги', short: 'Работяги' },
  { key: 'forge',      panel: 'normal', title: 'Кузница', short: 'Кузница', last: true, visible: () => G.meta.forgeUnlocked },
  { key: 'pbonus',     panel: 'prest',  title: 'Бонусы престижа', short: 'Бонусы' },
  { key: 'pupg2',      panel: 'prest',  title: 'Улучшения II', short: 'Улучшения II' },
  { key: 'automation', panel: 'prest',  title: 'Автофабрика', short: 'Автофабрика', last: true },
];

const UPGRADES = [
  // ===== Оборудование =====
  { key: 'acid', group: 'eq', currency: 'cash', name: 'Кислота почище', max: 15, start: 1,
    cost: l => stepCost(170, 1.65, l - 1),
    desc: (l, n) => `Выход золота из лома: ${pct(F.cycleEff(l, lv('fire'), lv('acidII'), lv('fireII')))}% → ${pct(F.cycleEff(n, lv('fire'), lv('acidII'), lv('fireII')))}%` },
  { key: 'fire', group: 'eq', currency: 'cash', name: 'Печь помощнее', max: 15, start: 1,
    cost: l => stepCost(170, 1.65, l - 1),
    desc: (l, n) => `Выход золота из лома: ${pct(F.cycleEff(lv('acid'), l, lv('acidII'), lv('fireII')))}% → ${pct(F.cycleEff(lv('acid'), n, lv('acidII'), lv('fireII')))}%` },
  { key: 'cap', group: 'eq', currency: 'cash', name: 'Складское место', max: 25, start: 1,
    cost: l => stepCost(120, 1.55, l - 1),
    desc: (l, n) => `Мест на складе: ${capMax()} → ${capMax() + F.cap(n) - F.cap(l)}` },
  { key: 'hold', group: 'eq', currency: 'cash', name: 'Турбо-палец', max: 1,
    cost: () => 1200,
    desc: l => l ? 'Зажми кнопку — она жмётся сама, пока держишь' : 'Разовая покупка: зажал кнопку — она жмётся сама' },

  // ===== Скорость процесса =====
  { key: 'scavspd', group: 'spd', currency: 'cash', name: 'Копать быстрее', max: 10,
    cost: l => stepCost(495, 1.7, l),
    desc: (l, n) => `Пауза между копками: ${sec(F.scavCd(l), 2)} с → ${sec(F.scavCd(n), 2)} с` },
  { key: 'acidspd', group: 'spd', currency: 'cash', name: 'Кислота быстрее', max: 20,
    cost: l => stepCost(495, 1.7, l),
    desc: (l, n) => `Время растворения: ${sec(acidDuration(l), 1)} с → ${sec(acidDuration(n), 1)} с` },
  { key: 'firespd', group: 'spd', currency: 'cash', name: 'Печь быстрее', max: 20,
    cost: l => stepCost(495, 1.7, l),
    desc: (l, n) => `Время плавки: ${sec(fireDuration(l), 1)} с → ${sec(fireDuration(n), 1)} с` },
  { key: 'secondacid', group: 'spd', currency: 'cash', name: 'Второй бак кислоты', max: 1,
    cost: () => 3000, onBuy: ensureVessels,
    desc: l => l ? 'Две ванны растворяют одновременно' : 'Вторая ванна — растворяет вместе с первой, вдвое быстрее' },
  { key: 'secondfire', group: 'spd', currency: 'cash', name: 'Вторая печь', max: 1,
    cost: () => 5000, onBuy: ensureVessels,
    desc: l => l ? 'Две печи плавят одновременно' : 'Вторая печь — плавит вместе с первой, вдвое быстрее' },

  // ===== Удача =====
  { key: 'goodeye', group: 'luck', currency: 'cash', name: 'Хороший глаз', max: 20,
    cost: l => stepCost(500, 1.8, l),
    desc: (l, n) => `Шанс найти вещь получше: ${pct(F.goodEye(l))}% → ${pct(F.goodEye(n))}%` },
  { key: 'luck', group: 'luck', currency: 'cash', name: 'Чуйка на золото', max: 15,
    cost: l => stepCost(700, 1.8, l),
    desc: (l, n) => `Шанс найти сразу две вещи: ${pct(F.luck(l))}% → ${pct(F.luck(n))}%` },

  // ===== Доход =====
  { key: 'reputation', group: 'income', currency: 'cash', name: 'Репутация', max: 10,
    cost: powCost(2500, 1.7),
    desc: (l, n) => `Надбавка к цене золота: +${F.reputation(l)}% → +${F.reputation(n)}%` },
  { key: 'wideZone', group: 'income', currency: 'cash', name: 'Широкая зона', max: 5,
    cost: powCost(5000, 1.7),
    desc: (l, n) => `Зелёная зона при продаже: ${F.wideZone(l)}% → ${F.wideZone(n)}%` },
  { key: 'offlineRate', group: 'income', currency: 'cash', name: 'Коэффициент оффлайна', max: 15, style: 'offline',
    cost: powCost(2000, 1.55),
    desc: (l, n) => `Доход, пока игра закрыта: ${F.offlineRate(l)}% → ${F.offlineRate(n)}%` },
  { key: 'offlineCap', group: 'income', currency: 'cash', name: 'Лимит оффлайна', max: 9, style: 'offline',
    cost: powCost(1500, 1.7),
    desc: (l, n) => `Доход копится до: ${F.offlineHours(l)} ч → ${F.offlineHours(n)} ч` },

  // ===== Восстановление точек (по строке на каждую открытую локацию) =====
  ...LOCATIONS.map(loc => ({
    key: 'regen:' + loc.key, group: 'regen', currency: 'cash', name: loc.name, max: 10,
    get: g => g.run.locs[loc.key].regenLv,
    set: (g, v) => { g.run.locs[loc.key].regenLv = v; },
    visible: () => G.run.locs[loc.key].unlocked,
    cost: l => Math.round(loc.regenCost * Math.pow(1.8, l)),
    desc: (l, n) => `Новая вещь появляется за: ${sec(F.regenInterval(loc, l), 1)} с → ${sec(F.regenInterval(loc, n), 1)} с`,
  })),

  // ===== Автоматизация: работяги за рубли =====
  { key: 'autoSpeed', group: 'auto', currency: 'cash', name: 'Скорость работяг', max: 10,
    cost: powCost(5000, 1.6),
    desc: (l, n) => `Работяга находит вещь за: ${sec(F.workerCd(l), 2)} с → ${sec(F.workerCd(n), 2)} с` },
  { key: 'autoLuck', group: 'auto', currency: 'cash', name: 'Удача работяг', max: 10,
    cost: powCost(4000, 1.7),
    desc: (l, n) => `Шанс двойной находки: ${F.workerLuck(l)}% → ${F.workerLuck(n)}%`,
    extra: () => hasAmulet('nightShift') ? ' · +10% от амулета' : '' },
  ...LOCATIONS.map(loc => ({
    key: 'autoDig:' + loc.key, group: 'auto', currency: 'cash', name: loc.name, max: 1, doneLabel: '✓ куплен',
    get: g => g.meta.autoDig[loc.key] ? 1 : 0,
    set: (g, v) => { g.meta.autoDig[loc.key] = v > 0; },
    visible: () => G.run.locs[loc.key].unlocked,
    cost: () => loc.autoDigCost,
    desc: l => l ? 'Работяга копает тут сам' : 'Нанять работягу — будет копать тут без тебя',
  })),

  // ===== Кузница =====
  { key: 'forgeSpeed', group: 'forge', currency: 'cash', name: 'Быстрее куём', max: 7,
    cost: powCost(8000, 1.7),
    desc: (l, n) => `Ковка быстрее на: −${pct(F.forgeSpeed(l))}% → −${pct(F.forgeSpeed(n))}%` },
  { key: 'forgeDiscount', group: 'forge', currency: 'cash', name: 'Дешевле рецепты', max: 10,
    cost: powCost(12000, 1.8),
    desc: (l, n) => `Рецепты дешевле на: −${pct(F.forgeDiscount(l))}% → −${pct(F.forgeDiscount(n))}%` },
  { key: 'forgeDuration', group: 'forge', currency: 'cash', name: 'Дольше живут', max: 5,
    cost: powCost(15000, 1.9),
    desc: (l, n) => `Амулеты живут дольше: +${l} прест. / +${pct(F.forgeDuration(l))}% → +${n} прест. / +${pct(F.forgeDuration(n))}%` },
  { key: 'twoForges', group: 'forge', currency: 'cash', name: 'Два горна', max: 1,
    cost: () => 25000,
    desc: l => l ? 'Михалыч куёт два амулета сразу' : 'Второй горн — Михалыч куёт два амулета сразу' },

  // ===== Престиж: бонусы =====
  { key: 'bonusBoost', group: 'pbonus', currency: 'points', name: 'Усиление бонуса', max: 20,
    cost: l => 1 + l,
    desc: (l, n) => `Бонус за каждый взнос: +${fmt(F.bonusBase(l), 2)}% → +${fmt(F.bonusBase(n), 2)}%` },
  { key: 'startCash', group: 'pbonus', currency: 'points', name: 'Стартовый капитал', max: 20,
    cost: l => 2 + l * 2,
    desc: (l, n) => `Деньги на старте: ${fmt(F.startCash(l))} → ${fmt(F.startCash(n))} ₽` },
  { key: 'locDiscount', group: 'pbonus', currency: 'points', name: 'Скидка на локации', max: 15,
    cost: l => 3 + l * 3,
    desc: (l, n) => `Скидка на точки: −${pct(F.locDiscount(l))}% → −${pct(F.locDiscount(n))}%` },

  // ===== Престиж: улучшения II =====
  { key: 'acidII', group: 'pupg2', currency: 'points', name: 'Кислота II', max: 10,
    cost: l => 2 + l * 2,
    desc: (l, n) => `Доп. выход золота: +${l}% → +${n}%` },
  { key: 'fireII', group: 'pupg2', currency: 'points', name: 'Печь II', max: 10,
    cost: l => 2 + l * 2,
    desc: (l, n) => `Доп. выход золота: +${l}% → +${n}%` },
  { key: 'capII', group: 'pupg2', currency: 'points', name: 'Склад II', max: 25,
    cost: l => 2 + l * 2,
    desc: (l, n) => `Доп. места на складе: +${F.capII(l)} → +${F.capII(n)}` },

  // ===== Престиж: авто-фабрика =====
  { key: 'automation', group: 'automation', currency: 'points', name: 'Автоматизация', max: 1,
    cost: () => 20,
    desc: l => l ? 'Фабрика запущена и работает сама' : 'Отдельная фабрика — сама копает, растворяет, плавит и продаёт. Руками всё равно выгоднее.' },
  ...[
    ['autoWorkers', 'Авто-работяги', 20, 'как часто авто-работяги копают лом',
      (l, n) => `Копают раз в: ${sec(F.autoWorkerInterval(l), 1)} с → ${sec(F.autoWorkerInterval(n), 1)} с`],
    ['autoCapLv', 'Авто-склад', 15, 'вместимость авто-склада',
      (l, n) => `Вместимость: ${F.autoCap(l)} → ${F.autoCap(n)}`],
    ['autoAcidSpeed', 'Авто-кислота (скорость)', 20, 'скорость переработки в авто-кислоте',
      (l, n) => `Цикл: ${sec(F.autoAcidInterval(l), 1)} с → ${sec(F.autoAcidInterval(n), 1)} с`],
    ['autoAcidPurity', 'Авто-кислота (чистота)', 15, 'чистота авто-кислоты — меньше потерь',
      (l, n) => `Выход: ${pct(F.autoAcidYield(l))}% → ${pct(F.autoAcidYield(n))}%`],
    ['autoFireSpeed', 'Авто-печь (скорость)', 20, 'скорость плавки в авто-печи',
      (l, n) => `Цикл: ${sec(F.autoFireInterval(l), 1)} с → ${sec(F.autoFireInterval(n), 1)} с`],
    ['autoFireHeat', 'Авто-печь (жар)', 15, 'жар авто-печи — меньше потерь',
      (l, n) => `Выход: ${pct(F.autoFireYield(l))}% → ${pct(F.autoFireYield(n))}%`],
    ['autoSaleSpeed', 'Авто-продажа (скорость)', 10, 'как часто авто-продажа сбывает слитки',
      (l, n) => `Продают раз в: ${sec(F.autoSaleInterval(l), 1)} с → ${sec(F.autoSaleInterval(n), 1)} с`],
    ['autoMarkup', 'Авто-наценка', 10, 'наценка авто-продажи',
      (l, n) => `Цена: ${F.autoSalePrice(l)} → ${F.autoSalePrice(n)} ₽/г`],
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
  if (!upgUnlocked(u) && u.lockedDesc) return u.lockedDesc;
  const next = l >= u.max ? l : l + 1;
  let text = u.desc(l, next);
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
