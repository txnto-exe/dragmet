'use strict';
// Все игровые данные: предметы, локации, амулеты, тексты и числа баланса.
// Хочешь поменять баланс — почти всё здесь (формулы прокачек — в formulas.js и upgrades.js).

const VERSION_LABEL = 'v0.10 · прототип';

// ===== Предметы =====
// gold   — сколько граммов золота в одной штуке
// tier   — «редкость»: jk мусор, cm обычное, vl ценное, rp редкое, lg легендарное (цвет тоста)
// sound  — какой звук играть при находке
// prefix — начало сообщения о находке
const ITEMS = {
  resist:     { name: 'Резисторы',            icon: '🔘', gold: 0.005, tier: 'jk', sound: 'junk' },
  caps:       { name: 'Конденсаторы',         icon: '🔋', gold: 0.008, tier: 'jk', sound: 'junk' },
  trans:      { name: 'Транзисторы',          icon: '🔻', gold: 0.015, tier: 'jk', sound: 'junk' },
  chips:      { name: 'Микросхемы',           icon: '🔌', gold: 0.02,  tier: 'cm', sound: 'mid' },
  hdd:        { name: 'Жёсткие диски',        icon: '💽', gold: 0.04,  tier: 'cm', sound: 'mid' },
  phones:     { name: 'Телефоны',             icon: '📱', gold: 0.045, tier: 'cm', sound: 'nice' },
  ram:        { name: 'ОЗУ',                  icon: '💾', gold: 0.07,  tier: 'cm', sound: 'nice' },
  connect:    { name: 'Разъёмы',              icon: '🟡', gold: 0.09,  tier: 'vl', sound: 'pricey' },
  silverWire: { name: 'Серебряная проволока', icon: '⚪', gold: 0.12,  tier: 'rp', sound: 'pricey' },
  cpus:       { name: 'Процессоры',           icon: '🧠', gold: 0.18,  tier: 'vl', sound: 'pricey', prefix: 'Ценный процессор — ' },
  rare:       { name: 'Советская плата',      icon: '🟩', gold: 0.25,  tier: 'rp', sound: 'rare',   prefix: 'Редкая — ' },
  brass:      { name: 'Латунные детали',      icon: '🔶', gold: 0.3,   tier: 'rp', sound: 'pricey' },
  gContacts:  { name: 'Золотые контакты',     icon: '🟠', gold: 0.35,  tier: 'rp', sound: 'pricey', prefix: 'Золотые контакты — ' },
  goldPins:   { name: 'Золотые пины',         icon: '🪙', gold: 0.5,   tier: 'rp', sound: 'pricey', prefix: 'Золотые пины — ' },
  legend:     { name: 'Плата шифратора',      icon: '🟨', gold: 0.75,  tier: 'lg', sound: 'legend', prefix: 'Легендарка — ' },
  platinum:   { name: 'Платиновая пластина',  icon: '⬜', gold: 1.5,   tier: 'lg', sound: 'legend', prefix: 'Платина! ' },
};
// Порядок показа в инвентаре — от дешёвого к дорогому (как объявлены выше).
const ITEM_KEYS = Object.keys(ITEMS);

/** Мусор (jk) и обычные (cm) предметы могут «улучшиться» удачей; ценные — уже нет. */
function isCheapItem(key) {
  const t = ITEMS[key].tier;
  return t === 'jk' || t === 'cm';
}

// ===== Локации =====
// stock — запас точки, regen — за сколько мс восстанавливается 1 штука,
// regenCost — цена первого уровня «Восстановления точки», autoDigCost — цена работяги,
// loot — что там выпадает (w — вес, чем больше, тем чаще).
const LOCATIONS = [
  { key: 'yard', name: 'Баки во дворе', icon: '🗑️', unlockCost: 0, stock: 14, regen: 2200, regenCost: 350, autoDigCost: 800,
    loot: { chips: 35, caps: 15, resist: 15, phones: 20, ram: 10, hdd: 5 } },
  { key: 'construction', name: 'Заброшенная стройка', icon: '🏗️', unlockCost: 715, stock: 6, regen: 7200, regenCost: 700, autoDigCost: 2500,
    loot: { phones: 22, caps: 10, trans: 18, hdd: 15, ram: 18, silverWire: 12, chips: 5 } },
  { key: 'radiozavod', name: 'Свалка радиозавода', icon: '🏭', unlockCost: 2600, stock: 5, regen: 10400, regenCost: 1600, autoDigCost: 6000,
    loot: { ram: 15, trans: 8, hdd: 12, cpus: 10, connect: 14, silverWire: 10, rare: 22, chips: 4, legend: 5 } },
  { key: 'garages', name: 'Гаражный кооператив', icon: '🚪', unlockCost: 6500, stock: 4, regen: 14400, regenCost: 3200, autoDigCost: 15000,
    loot: { connect: 10, cpus: 10, silverWire: 12, legend: 18, rare: 28, ram: 14, hdd: 8 } },
  { key: 'workshop', name: 'Ремонтная мастерская', icon: '🔧', unlockCost: 14000, stock: 4, regen: 18000, regenCost: 5500, autoDigCost: 35000,
    loot: { trans: 12, hdd: 22, cpus: 14, brass: 14, rare: 22, connect: 14, ram: 4 } },
  { key: 'ats', name: 'Заброшенная АТС', icon: '📡', unlockCost: 32000, stock: 3, regen: 22000, regenCost: 9000, autoDigCost: 80000,
    loot: { cpus: 18, connect: 20, gContacts: 12, goldPins: 10, legend: 18, rare: 20, hdd: 8 } },
  { key: 'scrapyard', name: 'Приёмка металлолома', icon: '⚙️', unlockCost: 75000, stock: 5, regen: 28000, regenCost: 15000, autoDigCost: 180000,
    loot: { chips: 12, phones: 12, ram: 12, hdd: 12, cpus: 12, brass: 10, connect: 8, rare: 8, gContacts: 8, goldPins: 6, legend: 5 } },
  { key: 'datacenter', name: 'Заброшенный дата-центр', icon: '🖥️', unlockCost: 130000, stock: 4, regen: 30000, regenCost: 19000, autoDigCost: 260000,
    loot: { cpus: 20, connect: 14, gContacts: 14, goldPins: 16, rare: 12, legend: 14, platinum: 10 } },
  { key: 'institute', name: 'Институтский склад', icon: '🎓', unlockCost: 180000, stock: 3, regen: 34000, regenCost: 24000, autoDigCost: 400000,
    loot: { cpus: 16, connect: 14, goldPins: 14, rare: 26, gContacts: 12, platinum: 10, legend: 20 } },
];
const LOCS_PER_PAGE = 3;
const LOC_PAGES = Math.ceil(LOCATIONS.length / LOCS_PER_PAGE);

function locDef(key) {
  return LOCATIONS.find(l => l.key === key);
}

// ===== Амулеты =====
// dur: { prestiges: N } — живёт N престижей; { hours: N } — живёт N часов.
// craftMin — сколько минут куётся (до прокачек).
const AMULETS = [
  { key: 'nightShift',    name: 'Ночная смена',        icon: '🌙', color: '#6dc4e8', effect: '+10% к удаче работяг',
    recipe: { resist: 20, caps: 10, cpus: 5 },   dur: { prestiges: 3 }, craftMin: 5 },
  { key: 'secondChance',  name: 'Второй шанс',         icon: '🎲', color: '#c084fc', effect: 'При промахе в стоп-игре даётся один переброс',
    recipe: { trans: 15, connect: 8, rare: 3 },  dur: { hours: 24 },    craftMin: 60 },
  { key: 'goldVein',      name: 'Золотая жила',        icon: '✨', color: '#f0c94a', effect: '+15% шанс найти ценную вещь вместо мусора',
    recipe: { chips: 30, cpus: 12, legend: 2 },  dur: { prestiges: 2 }, craftMin: 30 },
  { key: 'cleaner',       name: 'Чистюля',             icon: '💧', color: '#a8d6f0', effect: 'Потери при переработке лома в слитки снижены вдвое',
    recipe: { caps: 25, connect: 10, cpus: 4 },  dur: { hours: 48 },    craftMin: 15 },
  { key: 'furnaceDemon',  name: 'Печной демон',        icon: '🔥', color: '#e8784a', effect: 'Кислота и печь работают на 25% быстрее',
    recipe: { resist: 25, phones: 10, cpus: 6 }, dur: { hours: 48 },    craftMin: 15 },
  { key: 'expander',      name: 'Расширитель',         icon: '📦', color: '#e88ab0', effect: '+8 мест на склад постоянно',
    recipe: { chips: 40, connect: 15, legend: 1 }, dur: { prestiges: 3 }, craftMin: 30 },
  { key: 'generousBuyer', name: 'Щедрый скупщик',      icon: '💰', color: '#f0a04a', effect: '+15% к цене продажи слитков',
    recipe: { phones: 20, connect: 10, cpus: 5 }, dur: { hours: 24 },   craftMin: 15 },
  { key: 'scavenger',     name: 'Мусорщик',            icon: '🗑️', color: '#8fa860', effect: 'Мусорные предметы выпадают в 3 раза чаще',
    recipe: { resist: 50, caps: 20, trans: 10 }, dur: { prestiges: 4 }, craftMin: 5 },
  { key: 'legendHunter',  name: 'Легендарный охотник', icon: '🏆', color: '#e87030', effect: '+5% шанс выпадения легендарки',
    recipe: { cpus: 30, connect: 15, legend: 3 }, dur: { prestiges: 2 }, craftMin: 30 },
  { key: 'patient',       name: 'Терпеливый',          icon: '⏳', color: '#6dc4a8', effect: 'Бегунок в стоп-игре движется в 2 раза медленнее',
    recipe: { ram: 15, connect: 8, rare: 2 },    dur: { hours: 36 },    craftMin: 60 },
];

function amuletDef(key) {
  return AMULETS.find(a => a.key === key) || null;
}

// ===== Числа баланса =====
const BAL = {
  // Стоп-игра «Контроль цены»
  priceMax: 4000,          // ₽/г при попадании в зону
  priceMin: 800,           // ₽/г при самом большом промахе
  priceAvgOffline: 3400,   // средняя цена, по которой считается оффлайн-доход
  priceZoneHalf: 5,        // половина ширины зелёной зоны, %
  priceRunnerSpeed: 1.3,   // скорость бегунка (полос в секунду)

  // Склад
  capStart: 15,            // мест на складе на старте
  capPerLevel: 8,          // +мест за уровень «Складского места»

  // Эффективность переработки лома в слитки (одна на весь цикл)
  cycleEffBase: 0.60,
  cycleEffStep: 0.0071,    // за уровень «Кислоты почище» и «Печи помощнее»
  cycleEffStepII: 0.01,    // за уровень «Кислоты II» и «Печи II»
  cycleEffCap: 1.0,

  // Престиж
  prestigeThresholdBase: 100000,
  prestigeThresholdMult: 1.5,
  prestigeMaxLevel: 20,
  // Сколько добавляет к «базе бонуса» каждый уровень «Усиления бонуса»
  bonusBoostSteps: [0.91, 0.88, 0.85, 0.82, 0.79, 0.76, 0.73, 0.70, 0.67, 0.64, 0.61, 0.58, 0.55, 0.52, 0.49, 0.46, 0.43, 0.40, 0.37, 0.34],

  // Оффлайн
  offlineMinSec: 300,      // меньше 5 минут отсутствия — оффлайн-доход не считаем
  autoOfflineRate: 0.60,   // доля дохода авто-фабрики в оффлайне

  // Мини-игры: после победы ещё 3 секунды можно запускать без мини-игры
  minigameGraceMs: 3000,

  // Кузница
  dissolveReturn: 0.4,     // сколько ресурсов вернёт растворение амулета
  craftMinMs: 15000,       // ковка не быстрее 15 секунд
};

// ===== Тексты =====
const TEXT = {
  digLabels: ['Копаемся…', 'Роемся в мусоре…', 'Ищем золотишко…', 'Обшариваем закрома…', 'Просеиваем хлам…',
    'Роемся в отходах…', 'Перебираем платы…', 'Ищем разъёмы…', 'Копаем глубже…', 'Шарим по бакам…'],
  priceHit: ['В точку!', 'В яблочко!', 'Удача!', 'Идеально!', 'Точно в цель!'],
  priceMiss: ['Мимо.', 'Промах.', 'Не повезло.', 'Мимо кассы.', 'Упустил момент.'],
  offline: ['Работяги топили печь, пока тебя не было.', 'Работяги не спали — копали всю смену.',
    'Мусор сам себя не разберёт — пришлось работягам.', 'Работяги честно пахали за еду.',
    'Работяги волокли хлам на склад без перекура.', 'Пока ты отдыхал, кто-то работал.',
    'Работяги нашли кое-что интересное, пока тебя не было.', 'Работяги выгребли всё, что смогли.'],
};
