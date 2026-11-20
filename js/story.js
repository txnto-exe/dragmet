'use strict';
// История и персонажи.
//
// Палыч должен Хозяину. Хозяин звонит по таксофону и требует 20 взносов (это престижи).
// Сначала Палыч один у бочки с огнём, потом к нему по одному прибиваются другие бомжи:
// у каждого своя сценка-знакомство и свой бонус. Все, кто прибился, сидят в «Лагере».
//
// Здесь же: портреты, окно диалога, заказы Зины, Шнырь (ворует на точках),
// участковый («Шухер!»).

// ===== Кто говорит =====
const SPEAKERS = {
  palych:   { name: 'Палыч',     color: '#e05a5a', pitch: 220 },
  hozyain:  { name: 'Хозяин',    color: '#e8b83a', pitch: 110 },
  zhora:    { name: 'Жора',      color: '#c8a070', pitch: 160 },
  police:   { name: 'Участковый', color: '#8ab0e8', pitch: 140 },
  cat:      { name: 'Помойка',   color: '#e8a050', pitch: 660 },
  kolyan:   { name: 'Колян',     color: '#6a9ae8', pitch: 190 },
  zina:     { name: 'Зина',      color: '#e86a8a', pitch: 330 },
  shnyr:    { name: 'Шнырь',     color: '#9ccc3c', pitch: 260 },
  mihalych: { name: 'Михалыч',   color: '#e8a050', pitch: 130 },
  valyok:   { name: 'Валёк',     color: '#6dc4e8', pitch: 240 },
  prof:     { name: 'Профессор', color: '#c09af0', pitch: 280 },
};

// ===== Бригада =====
// when()  — когда персонаж приходит; intro — сценка знакомства; lines — что говорит в лагере.
const CREW = [
  { id: 'cat', role: 'кот', bio: 'Рыжий, тощий, ничей. Теперь — талисман бригады.',
    bonus: 'Иногда притаскивает находку, когда роешься сам',
    hint: 'Придёт, когда наберёшь 10 находок',
    when: () => foundTotal() >= 10,
    intro: [['cat', 'Мр-р-ряу.'], ['palych', 'О, котяра. Тоже никому не нужен?'], ['cat', '*трётся о сапог*'],
      ['palych', 'Ладно. Будешь Помойкой. Держись рядом.']],
    lines: ['Мр-р.', 'Мяу!', '*мурчит*', '*умывается*'] },
  { id: 'kolyan', role: 'работяга', bio: 'Бывший слесарь с радиозавода. Руки золотые, характер — не очень.',
    bonus: 'Работяги копают на 10% быстрее',
    hint: 'Придёт, когда наймёшь первого работягу',
    when: () => Object.values(G.meta.autoDig).some(Boolean),
    intro: [['kolyan', 'Слышь, братан, это ты тут золото из мусора варишь?'], ['palych', 'Ну я. А тебе что?'],
      ['kolyan', 'Возьми копать, а? За еду. Я с завода, руки помнят.'],
      ['palych', 'Баки твои. Только не пей на смене.'], ['kolyan', 'Обижаешь! …Ну, почти не буду.']],
    lines: ['Ещё по одной… плате', 'Спина болит, но копаю', 'На заводе хоть обед был', 'Братан, всё путём'] },
  { id: 'zina', role: 'барахольщица', bio: 'Сорок лет собирает всё подряд. Знает, кому что продать.',
    bonus: 'Даёт заказы: принёс, что просит, — получил деньги',
    hint: 'Встретишь на заброшенной стройке',
    when: () => G.run.locs.construction.unlocked || G.meta.prestige > 0,
    intro: [['zina', 'Ой, милок, а ты чего тут роешься? Это моя стройка была!'],
      ['palych', 'Была. Теперь тут золото ищут.'],
      ['zina', 'Золото, говоришь… Я тоже кой-чего ищу. Детальки разные.'],
      ['zina', 'Принесёшь, что попрошу, — не обижу. Деньги у Зины водятся.']],
    lines: ['Милок, кушал сегодня?', 'Ох, ноги мои ноги', 'Детальки, детальки…', 'Всё в хозяйстве пригодится'] },
  { id: 'shnyr', role: 'бывший конкурент', bio: 'Воровал с твоих точек, пока не получил по шее. Знает все места.',
    bonus: 'Точки восстанавливаются на 15% быстрее',
    hint: 'Кто-то ворует на твоих точках. Прогони его три раза — тап по нему',
    when: () => G.meta.story.shnyrChases >= 3,
    intro: [['shnyr', 'Ну всё, всё! Понял я, понял!'], ['shnyr', 'Слушай… давай я лучше с тобой. Я тут все места знаю.'],
      ['palych', 'А воровать у своих будешь?'], ['shnyr', 'У своих — никогда. Честное шнырское.']],
    lines: ['Я ничего не брал!', 'Знаю одно местечко…', 'Тс-с, участковый!', 'Свои — это святое'] },
  { id: 'mihalych', role: 'кузнец', bio: 'Сорок лет у горна. Завод закрыли — горн забрал в гараж.',
    bonus: 'Открыл кузню: амулеты из хлама',
    hint: 'Придёт после первого взноса Хозяину',
    when: () => G.meta.prestige >= 1,
    intro: [['mihalych', 'Ты, что ли, Палыч? Хозяин звонил. Сказал — помочь.'], ['palych', 'А ты кто такой?'],
      ['mihalych', 'Михалыч. Кузнец. Завод закрыли — горн забрал в гараж.'],
      ['mihalych', 'Тащи хлам — скую обереги. Удачу приманивают, сам увидишь.']],
    lines: ['Железо лени не любит', 'Горн остывать не должен', 'В моё время платы были золотые', 'Куй, пока горячо'] },
  { id: 'valyok', role: 'гармонист', bio: 'Гармонь есть, дома нет. Играет всё, что попросишь.',
    bonus: 'Оффлайн-доход +15%: под гармонь работяги пашут и без тебя',
    hint: 'Придёт после третьего взноса',
    when: () => G.meta.prestige >= 3,
    intro: [['valyok', '♪ Ой, мороз, моро-оз… ♪'], ['palych', 'Это ещё кто?'],
      ['valyok', 'Валёк я! Гармонь есть, дома нет. Пустите погреться?'],
      ['valyok', 'Я играть буду, вы работать. Под музыку и без тебя пахать будут.']],
    lines: ['♪ Тра-ля-ля ♪', 'Заказывайте песни!', '♪ Ой, то не вечер… ♪', 'Гармонь — она душу греет'] },
  { id: 'prof', role: 'бывший химик', bio: 'Кандидат химических наук. Институт закрыли, а его — забыли.',
    bonus: 'Золото дороже на 10%: знает, как чистить',
    hint: 'Живёт где-то у дата-центра или института',
    when: () => G.run.locs.datacenter.unlocked || G.run.locs.institute.unlocked,
    intro: [['prof', 'Простите… это у вас царская водка в ванне? Какая безграмотная пропорция!'],
      ['palych', 'Ты кто, умник?'], ['prof', 'Кандидат химических наук. Бывший. Институт закрыли, а меня забыли.'],
      ['prof', 'Позвольте помочь. С правильной очисткой ваше золото будет стоить дороже.']],
    lines: ['Электрохимический ряд не обманешь', 'Au — от слова «аурум»', 'Три к одному, коллега!', 'Наука — сила'] },
];

const PALYCH_LINES = ['Двадцать взносов… Справимся', 'Хорошая у нас бригада', 'Эх, жизнь…', 'Огонь греет, и ладно'];

const crewHas = id => !!(G && G.meta.crew && G.meta.crew[id]);
const crewDef = id => CREW.find(c => c.id === id);
function foundTotal() {
  let n = 0;
  for (const k in G.meta.found) n += G.meta.found[k];
  return n;
}
function unlockedLocCount() {
  return LOCATIONS.filter(l => G.run.locs[l.key].unlocked).length;
}

// Бонусы бригады (используются в формулах)
const crewWorkerMult = () => (crewHas('kolyan') ? 0.9 : 1);
const crewRegenMult = () => (crewHas('shnyr') ? 0.85 : 1);
const crewPriceMult = () => (crewHas('prof') ? 1.1 : 1);
const crewOfflineMult = () => (crewHas('valyok') ? 1.15 : 1);

// ===== Портреты 24×24 =====

const FACES = {
  palych:   { bg: '#2a3a24', skin: '#e0a878', hat: ['beanie', '#8e2a32', '#c0444e'], beard: '#9c9a8c', coat: '#5c6b36', nose: '#d08060' },
  hozyain:  { bg: '#2a0e0e', hood: '#1a1414', coat: '#1a1414' },
  zhora:    { bg: '#3a2a14', skin: '#e0a878', hat: ['cap', '#1e1a18', '#2c2c34'], coat: '#2c2c34', stubble: '#5a4030', tooth: true, cig: true },
  police:   { bg: '#1a2030', skin: '#e0a878', hat: ['police'], mustache: '#4a3020', coat: '#4a5a7a', badge: true },
  kolyan:   { bg: '#1e2a40', skin: '#e8b088', hat: ['beanie', '#2a4a8a', '#3a6ac8'], stubble: '#4a3a2a', coat: '#3a4a7a', stripes: true, nose: '#d86a5a', blush: true },
  zina:     { bg: '#3a1e34', skin: '#e8b898', hat: ['scarf', '#2a6a8a'], coat: '#6a3a7a', blush: true, earring: true, wrinkles: true },
  shnyr:    { bg: '#24301a', skin: '#d09870', hat: ['flat', '#1e1e1e', '#323232'], stubble: '#5a5048', coat: '#4a5a2a', scar: true, sly: true },
  mihalych: { bg: '#3a2414', skin: '#d89868', hat: ['bald', '#e8e8e0'], beard: '#e8e8e0', coat: '#5a5a62', apron: true, brow: '#e8e8e0' },
  valyok:   { bg: '#1a2238', skin: '#e8a880', hat: ['ushanka', '#6a4a2a', '#b8a080'], mustache: '#7a5030', coat: '#2a3a5a', blush: true },
  prof:     { bg: '#2a2a30', skin: '#e0b090', hat: ['messy', '#b0b0b0'], goatee: '#b8b8b8', coat: '#7a5a3a', glasses: true, tie: true },
};

const _faceCache = {};

/** Портрет персонажа (dataURL). silhouette — тёмный силуэт для ещё не встреченных. */
function faceURL(id, silhouette) {
  const key = id + (silhouette ? '_s' : '');
  if (_faceCache[key]) return _faceCache[key];
  const cv = document.createElement('canvas');
  cv.width = 24; cv.height = 24;
  const ctx = cv.getContext('2d');
  const f = FACES[id] || { bg: '#2a2a2a' };
  rect(ctx, 0, 0, 24, 24, f.bg);
  for (let x = 0; x < 24; x += 2) dot(ctx, x + (x % 4 ? 1 : 0), 0, lighten(f.bg, 0.12));
  const R = (x, y, w, h, c) => rect(ctx, 2 + x, 3 + y, w, h, c);
  const D = (x, y, c) => dot(ctx, 2 + x, 3 + y, c);
  if (id === 'cat') drawCatFace(R, D);
  else if (id === 'hozyain') drawBossFace(f, R, D);
  else drawHumanFace(f, R, D);
  if (silhouette) {
    const img = ctx.getImageData(0, 0, 24, 24), bg = hexToRgb(f.bg), px = img.data;
    for (let i = 0; i < px.length; i += 4) {
      const isBg = Math.abs(px[i] - bg[0]) + Math.abs(px[i + 1] - bg[1]) + Math.abs(px[i + 2] - bg[2]) < 40;
      if (isBg) { px[i] = 30; px[i + 1] = 34; px[i + 2] = 26; } else { px[i] = 58; px[i + 1] = 66; px[i + 2] = 50; }
    }
    ctx.putImageData(img, 0, 0);
  }
  return (_faceCache[key] = cv.toDataURL());
}

function faceImg(id, className, silhouette) {
  const img = make('img', 'px-face' + (className ? ' ' + className : ''));
  img.src = faceURL(id, silhouette);
  img.width = 48;
  img.height = 48;
  img.alt = '';
  img.draggable = false;
  return img;
}

const OUT = '#120e0c';

function drawHumanFace(f, R, D) {
  const skin = f.skin, sd = darken(skin, 0.2);
  // тело
  R(-1, 14, 22, 7, OUT);
  R(0, 15, 20, 6, f.coat);
  R(1, 15, 18, 1, lighten(f.coat, 0.18));
  if (f.stripes) { R(2, 15, 1, 6, '#f2f4ea'); R(17, 15, 1, 6, '#f2f4ea'); R(10, 15, 1, 6, darken(f.coat, 0.35)); }
  if (f.apron) { R(5, 15, 10, 6, '#7a5230'); R(8, 18, 4, 2, '#5a3a20'); R(5, 15, 1, 1, '#4a3018'); R(14, 15, 1, 1, '#4a3018'); }
  if (f.tie) { R(8, 15, 4, 1, '#e8e8e0'); R(9, 15, 2, 6, '#8a2a2a'); }
  if (f.badge) R(14, 16, 2, 2, '#e8b83a');
  R(8, 13, 4, 2, sd);   // шея
  // голова с контуром
  R(5, 2, 10, 14, OUT); R(4, 3, 12, 12, OUT);
  R(6, 3, 8, 12, skin); R(5, 4, 10, 10, skin);
  R(13, 4, 1, 10, sd); R(6, 14, 8, 1, sd);
  R(4, 7, 1, 3, sd); R(15, 7, 1, 3, sd);   // уши
  // брови и глаза
  const brow = f.brow || darken(skin, 0.6);
  R(6, 7, 3, 1, brow); R(11, 7, 3, 1, brow);
  if (f.sly) { R(7, 8, 2, 1, '#161210'); R(11, 8, 2, 1, '#161210'); }
  else { R(7, 8, 1, 2, '#161210'); R(12, 8, 1, 2, '#161210'); D(7, 8, '#3a3632'); D(12, 8, '#3a3632'); }
  if (f.wrinkles) { R(8, 5, 4, 1, sd); D(5, 10, sd); D(14, 10, sd); }
  // нос и рот
  R(9, 9, 2, 2, f.nose || sd);
  R(8, 12, 4, 1, '#6a2a22');
  if (f.blush) { D(6, 11, '#e07a6a'); D(13, 11, '#e07a6a'); }
  // растительность
  if (f.beard) {
    R(5, 11, 10, 3, f.beard); R(6, 14, 8, 1, f.beard); R(7, 15, 6, 1, f.beard);
    R(8, 12, 4, 1, darken(f.beard, 0.55)); D(6, 12, lighten(f.beard, 0.25)); D(12, 13, lighten(f.beard, 0.25));
  }
  if (f.stubble) {
    const sc = mixColor(skin, f.stubble, 0.55);
    for (let y = 11; y <= 14; y++) for (let x = 5; x <= 14; x++) if ((x + y) % 2 && !(y === 12 && x >= 8 && x <= 11) && !(y === 11 && x >= 9 && x <= 10)) D(x, y, sc);
  }
  if (f.mustache) { R(7, 11, 6, 1, f.mustache); D(6, 12, f.mustache); D(13, 12, f.mustache); }
  if (f.goatee) { R(8, 11, 4, 1, f.goatee); R(8, 13, 4, 2, f.goatee); R(9, 15, 2, 1, f.goatee); }
  if (f.scar) { D(6, 9, '#a04848'); D(7, 10, '#a04848'); D(6, 11, '#a04848'); }
  if (f.tooth) D(10, 12, '#f5d060');
  if (f.cig) { R(12, 12, 3, 1, '#e8e8e0'); D(15, 12, '#ff6020'); D(16, 11, 'rgba(200,200,200,0.5)'); }
  if (f.earring) D(4, 10, '#e8b83a');
  if (f.glasses) {
    R(5, 7, 4, 3, '#141414'); R(11, 7, 4, 3, '#141414'); R(9, 8, 2, 1, '#141414');
    R(6, 8, 2, 1, '#bfe4f2'); R(12, 8, 2, 1, '#bfe4f2'); D(6, 8, '#ffffff'); D(12, 8, '#ffffff');
  }
  // голова сверху: шапки, платки, волосы
  const [kind, c1, c2] = f.hat;
  if (kind === 'beanie') {
    R(4, 0, 12, 7, OUT); R(5, 1, 10, 4, c1); R(4, 5, 12, 2, c2); R(3, 5, 1, 2, OUT); R(16, 5, 1, 2, OUT);
    for (let x = 5; x < 15; x += 2) D(x, 2, darken(c1, 0.18));
    R(8, -1, 4, 1, OUT); R(9, -2, 2, 1, c2);
  } else if (kind === 'cap') {
    R(4, 1, 12, 5, OUT); R(5, 2, 10, 3, c1); R(3, 5, 13, 1, c2); R(3, 6, 13, 1, OUT); D(9, 2, lighten(c1, 0.2));
  } else if (kind === 'flat') {
    R(3, 2, 14, 4, OUT); R(4, 3, 12, 2, c1); R(3, 5, 14, 1, c2); D(6, 3, lighten(c1, 0.2));
  } else if (kind === 'scarf') {
    R(3, 0, 14, 8, OUT); R(4, 1, 12, 6, c1); R(3, 6, 3, 8, c1); R(14, 6, 3, 8, c1); R(2, 6, 1, 8, OUT); R(17, 6, 1, 8, OUT);
    R(8, 14, 4, 2, c1);
    [[6, 2], [11, 3], [8, 5], [13, 5], [4, 10], [15, 9]].forEach(([x, y]) => { D(x, y, '#f0d060'); D(x + 1, y, '#e86a8a'); });
    R(4, 6, 12, 1, darken(c1, 0.25));
  } else if (kind === 'bald') {
    R(4, 6, 2, 5, c1); R(14, 6, 2, 5, c1); D(8, 4, lighten(skin, 0.4)); D(9, 4, lighten(skin, 0.4));
  } else if (kind === 'messy') {
    R(5, 1, 10, 3, c1); R(4, 3, 1, 5, c1); R(15, 3, 1, 5, c1);
    [5, 8, 11, 14].forEach(x => D(x, 0, c1)); D(7, 2, lighten(c1, 0.25));
  } else if (kind === 'ushanka') {
    R(3, 0, 14, 6, OUT); R(4, 1, 12, 4, c1); R(4, 4, 12, 2, c2); R(2, 6, 3, 7, c1); R(15, 6, 3, 7, c1);
    R(2, 12, 3, 1, c2); R(15, 12, 3, 1, c2); D(9, 1, lighten(c1, 0.2));
  } else if (kind === 'police') {
    R(4, 0, 12, 6, OUT); R(5, 1, 10, 3, '#2e3c5c'); R(4, 4, 12, 1, '#c83030'); R(4, 5, 12, 1, '#141414');
    D(9, 2, '#e8b83a'); D(10, 2, '#e8b83a');
  }
}

/** Хозяин: лица не видно — капюшон, глаза и огонёк сигареты. */
function drawBossFace(f, R, D) {
  R(-1, 14, 22, 7, OUT); R(0, 15, 20, 6, f.coat);
  R(2, 0, 16, 16, OUT); R(3, 1, 14, 15, f.hood); R(4, 1, 12, 1, lighten(f.hood, 0.12));
  R(6, 5, 8, 9, '#050404');
  D(7, 8, '#e8c060'); D(12, 8, '#e8c060');
  R(11, 12, 3, 1, '#c8c8c0'); D(14, 12, '#ff6020'); D(15, 11, 'rgba(255,120,40,0.5)');
  R(13, 17, 3, 1, '#e8b83a');   // золотая цепь
}

function drawCatFace(R, D) {
  const c = '#d8823a', dk = '#9a5220';
  R(4, 15, 12, 6, OUT); R(5, 16, 10, 5, c); R(8, 16, 4, 4, '#f2e8d8');
  R(3, 2, 5, 6, OUT); R(12, 2, 5, 6, OUT); R(2, 6, 16, 11, OUT);
  R(4, 3, 3, 4, c); R(13, 3, 3, 4, c); D(5, 4, '#e88ab0'); D(14, 4, '#e88ab0');
  R(3, 7, 14, 9, c); R(4, 6, 12, 1, c);
  R(8, 6, 1, 2, dk); R(11, 6, 1, 2, dk); R(9, 7, 2, 1, dk); R(3, 10, 2, 1, dk); R(15, 10, 2, 1, dk);
  R(6, 9, 2, 2, '#9ccc3c'); R(12, 9, 2, 2, '#9ccc3c'); D(7, 9, '#161210'); D(12, 9, '#161210');
  R(9, 12, 2, 1, '#e88ab0'); D(9, 13, dk); D(10, 13, dk);
  R(0, 12, 3, 1, '#f2f4ea'); R(17, 12, 3, 1, '#f2f4ea'); R(0, 14, 3, 1, '#f2f4ea'); R(17, 14, 3, 1, '#f2f4ea');
}

// ===== Как бригада выглядит на сценах (тело героя с другими цветами) =====

const CREW_LOOK = {
  palych:   {},
  kolyan:   { h: '#2a4a8a', i: '#3a6ac8', g: '#4a3a2a', f: '#5a4a3a', c: '#3a4a7a', d: '#2a3458', p: '#2a3458', q: '#1e2640' },
  zina:     { h: '#2a6a8a', i: '#3a8aaa', g: '#e0a878', f: '#e8b898', c: '#6a3a7a', d: '#4a2658', p: '#3a3a3a', q: '#2a2a2a' },
  shnyr:    { h: '#1e1e1e', i: '#323232', g: '#5a5048', f: '#6a6058', c: '#4a5a2a', d: '#323e1a' },
  mihalych: { h: '#d89868', i: '#e8e8e0', g: '#e8e8e0', f: '#ffffff', c: '#7a5230', d: '#5a3a20' },
  valyok:   { h: '#6a4a2a', i: '#b8a080', g: '#e8a880', f: '#7a5030', c: '#2a3a5a', d: '#1a2640' },
  prof:     { h: '#b0b0b0', i: '#c8c8c8', g: '#b8b8b8', f: '#d0d0d0', c: '#7a5a3a', d: '#5a4028' },
  police:   { h: '#2e3c5c', i: '#c83030', g: '#e0a878', f: '#4a3020', c: '#4a5a7a', d: '#34405a', p: '#2a3048', q: '#1e2236' },
};

/** Нарисовать члена бригады (стоит, дышит). x, y — левый верх спрайта 16×24. */
function drawCrewMember(ctx, id, x, y, t, flip, phase = 0) {
  if (id === 'cat') {
    drawSprite(ctx, 'cat', x, y + 19, null, flip);
    return;
  }
  const frame = Math.floor((t + phase) / 800) % 2 ? 'heroIdle' : 'heroIdle2';
  const swap = id === 'palych' ? heroSwap() : CREW_LOOK[id];
  drawSprite(ctx, frame, x, y, { swap }, flip);
  const fx = k => (flip ? x + 15 - k : x + k);
  if (id === 'prof') {   // очки
    dot(ctx, fx(9), y + 5, '#141414'); dot(ctx, fx(10), y + 5, '#bfe4f2'); dot(ctx, fx(11), y + 5, '#141414');
  }
  if (id === 'valyok') {   // гармонь меха ходят туда-сюда
    const open = Math.floor((t + phase) / 300) % 2;
    const ax = flip ? x + 2 : x + 7;
    rect(ctx, ax - 1, y + 11, 8 + open, 6, '#141414');
    rect(ctx, ax, y + 12, 2, 4, '#c83030');
    for (let k = 0; k < 2 + open; k++) rect(ctx, ax + 2 + k * 2, y + 12, 1, 4, '#e8e0c8');
    rect(ctx, ax + 4 + open, y + 12, 2, 4, '#c83030');
  }
  if (id === 'palych' && G.meta.prestige >= 3) { dot(ctx, fx(9), y + 11, '#f5d060'); dot(ctx, fx(10), y + 12, '#f5d060'); dot(ctx, fx(11), y + 11, '#f5d060'); }
}

// Места вокруг бочки: dx от бочки, dy — сдвиг ног (назад/вперёд), flip — лицом влево
const CAMP_SLOTS = [
  { dx: 18, dy: 0, flip: true }, { dx: -38, dy: -4 }, { dx: 35, dy: -3, flip: true },
  { dx: -56, dy: 1 }, { dx: 52, dy: 2, flip: true }, { dx: -73, dy: -3 },
];

/**
 * Лагерь у бочки: Палыч и все, кто прибился. bx, by — левый верх бочки 14×14.
 * Возвращает, кто где стоит (для облачков с репликами).
 */
function drawCampCrew(ctx, bx, by, t, crew) {
  const feet = by + 12;
  const people = [{ id: 'palych', dx: -20, dy: 0, flip: false }];
  CREW.filter(c => c.id !== 'cat' && crew[c.id]).forEach((c, i) => {
    const s = CAMP_SLOTS[i];
    if (s) people.push({ id: c.id, dx: s.dx, dy: s.dy, flip: !!s.flip });
  });
  const spots = [];
  people.slice().sort((a, b) => a.dy - b.dy).forEach((p, i) => {
    const x = bx + p.dx, y = feet + p.dy - 24;
    drawCrewMember(ctx, p.id, x, y, t, p.flip, i * 370);
    spots.push({ id: p.id, x: x + 8, y });
  });
  if (crew.cat) {
    const cx = bx + 4 + Math.round(Math.sin(t / 2000) * 2);
    drawSprite(ctx, 'cat', cx, feet - 4, null, Math.floor(t / 4000) % 2 === 0);
    spots.push({ id: 'cat', x: cx + 5, y: feet - 8 });
  }
  return spots;
}

/** Кто из бригады есть: в игре — из G, в меню (до «Продолжить») — из сейва. */
let menuSaveCrew = {};
function campCrewNow() {
  return currentScreen === 'game' || Object.keys(G.meta.crew).length ? G.meta.crew : menuSaveCrew;
}

// ===== Окно диалога =====

const dlg = { open: false, queue: [], script: null, i: 0, shown: 0, full: '', timer: null, onDone: null };

function isDialogOpen() {
  return dlg.open;
}

/** Поставить сценку в очередь. lines: [[кто, текст], …]. */
function say(lines, onDone) {
  dlg.queue.push({ lines, onDone });
}

function storyBlocked() {
  return currentScreen !== 'game' || cut.open || isMinigameOpen() || isPriceGameOpen()
    || !!document.querySelector('.modal-overlay.show, .offline-overlay.show');
}

function pumpDialog() {
  if (dlg.open || !dlg.queue.length || storyBlocked()) return;
  const s = dlg.queue.shift();
  dlg.script = s.lines;
  dlg.onDone = s.onDone || null;
  dlg.i = 0;
  dlg.open = true;
  el('dlgOverlay').classList.add('show');
  showDialogLine();
}

function showDialogLine() {
  const [who, text] = dlg.script[dlg.i];
  const sp = SPEAKERS[who] || { name: who, color: '#f2f4ea', pitch: 200 };
  el('dlgFace').src = faceURL(who);
  setText('dlgName', sp.name);
  el('dlgName').style.color = sp.color;
  dlg.full = text;
  dlg.shown = 0;
  setText('dlgText', '');
  el('dlgOverlay').classList.remove('done');
  clearInterval(dlg.timer);
  dlg.timer = setInterval(() => {
    dlg.shown++;
    setText('dlgText', dlg.full.slice(0, dlg.shown));
    if (dlg.shown % 2 === 0 && dlg.full[dlg.shown - 1] !== ' ') sfx(sp.pitch * (0.9 + Math.random() * 0.2), 0.035, 'square', 0, null, 0.35);
    if (dlg.shown >= dlg.full.length) finishTyping();
  }, 28);
}

function finishTyping() {
  clearInterval(dlg.timer);
  dlg.timer = null;
  dlg.shown = dlg.full.length;
  setText('dlgText', dlg.full);
  el('dlgOverlay').classList.add('done');
}

/** Тап по окну диалога: дописать строку или перейти к следующей. */
function dialogNext() {
  if (!dlg.open) return;
  if (dlg.timer) { finishTyping(); return; }
  dlg.i++;
  if (dlg.i < dlg.script.length) { showDialogLine(); return; }
  dlg.open = false;
  el('dlgOverlay').classList.remove('show', 'done');
  const cb = dlg.onDone;
  dlg.onDone = null;
  if (cb) cb();
  saveGame();
}

// ===== Сюжет =====

const INTRO = [
  ['palych', '…Алло?'],
  ['hozyain', 'Палыч. Узнал? Ты мне должен. Много.'],
  ['palych', 'Я всё верну, честно! Только денег нет…'],
  ['hozyain', 'Денег нет, зато руки есть. Во дворе баки. В старых платах — золото.'],
  ['hozyain', 'Растворяешь, плавишь, сдаёшь Жоре в ларёк. Каждый взнос — мне.'],
  ['hozyain', 'Двадцать взносов — и мы в расчёте. Иди работай.'],
];

const CALLS = {
  1: [['hozyain', 'Первый взнос дошёл. Неплохо для бомжа.'], ['hozyain', 'В гаражах живёт Михалыч, кузнец. Скажешь — от меня.']],
  2: [['hozyain', 'Второй. Не расслабляйся — проценты капают.']],
  3: [['hozyain', 'Третий. Слышу, у тебя там гармонь играет?'], ['palych', 'Это Валёк, он…'], ['hozyain', 'Мне всё равно, кто. Работайте.']],
  5: [['hozyain', 'Пятый взнос. Ты меня удивляешь, Палыч.']],
  10: [['hozyain', 'Половина. Знаешь… я тебя почти уважаю.'], ['palych', 'Может, скостишь немного?'], ['hozyain', 'Почти.']],
  15: [['hozyain', 'Осталось пять. Даже не думай свалить.']],
  19: [['hozyain', 'Последний остался. Не подведи.']],
  20: [['hozyain', 'Двадцатый. Всё. Мы в расчёте.'], ['palych', 'И… что теперь?'],
    ['hozyain', 'Теперь ты свободен. Хотя с такой бригадой ты и сам можешь стать хозяином.'],
    ['palych', 'Подумаю. А пока — бочка горит, мусор не кончается.']],
};
const CALL_GENERIC = ['Взнос принят. Осталось {n}.', 'Деньги пришли. Ещё {n}, Палыч.', 'Хорошо. Но долг ещё не закрыт: {n}.', 'Принял. Не тормози — осталось {n}.'];

function hozyainCall(level) {
  const left = BAL.prestigeMaxLevel - level;
  const lines = CALLS[level] || [['hozyain', pickRandom(CALL_GENERIC).replace('{n}', left)]];
  return [['palych', 'Алло?']].concat(lines);
}

/** Сколько взносов Хозяину ещё осталось. */
function debtLeft() {
  return BAL.prestigeMaxLevel - G.meta.prestige;
}

function joinCrew(c, silent) {
  G.meta.crew[c.id] = Date.now();
  if (c.id === 'zina') G.run.orderNext = 0;
  if (silent) return;
  say(c.intro, () => {
    flashToast(`К бочке прибился: ${SPEAKERS[c.id].name}`, 'rp');
    sndNewCrew();
  });
}

/** Звонок таксофона: дзынь-дзынь. */
function sndPhone() {
  for (let r = 0; r < 2; r++) for (let k = 0; k < 6; k++) sfx(k % 2 ? 1180 : 940, 0.045, 'square', r * 0.7 + k * 0.05, null, 0.45);
}

function sndNewCrew() {
  arp([392, 494, 587, 784], 0.08, 0.1, 'square', 0.7);
}

let storyAcc = 0;

/** Раз в полсекунды: кто пришёл, кто звонит, события. */
function storyTick(dt) {
  storyAcc += dt;
  tickEvents(dt);
  if (storyAcc < 500) return;
  storyAcc = 0;
  const st = G.meta.story;
  if (!dlg.open && !dlg.queue.length && !storyBlocked()) {
    if (!st.intro) {
      st.intro = true;
      sndPhone();
      if (st.veteran) {
        const came = CREW.filter(c => c.id !== 'shnyr' && c.when());
        came.forEach(c => joinCrew(c, true));
        const names = came.map(c => SPEAKERS[c.id].name);
        say(INTRO.slice(0, 2).concat([
          ['palych', 'Помню, помню. Взносы плачу.'],
          ['hozyain', `Плати дальше. Осталось ${debtLeft()}. Двадцать взносов — и мы в расчёте.`],
        ], names.length ? [['palych', `Хорошо хоть не один. У бочки уже: ${names.join(', ')}.`]] : []));
      } else {
        say(INTRO.concat([['palych', '…Ну, баки так баки.']]));
      }
    } else if (st.call) {
      const lv = st.call;
      st.call = 0;
      sndPhone();
      say(hozyainCall(lv));
    } else {
      const c = CREW.find(x => !G.meta.crew[x.id] && x.when());
      if (c) joinCrew(c);
    }
  }
  pumpDialog();
}

/** Первая продажа — знакомство с Жорой. */
function storyOnSale() {
  if (G.meta.story.zhora) return;
  G.meta.story.zhora = true;
  say([['zhora', 'Ну, показывай, что принёс.'], ['zhora', 'Хозяин предупредил: тебе по-честному.'], ['zhora', '…Почти по-честному. Заходи ещё.']]);
}

// ===== Заказы Зины =====

const ORDER_QTY = { jk: [5, 9], cm: [3, 6], vl: [2, 3], rp: [1, 2], lg: [1, 1] };

function makeOrder() {
  const pool = ITEM_KEYS.filter(k => G.meta.found[k] && LOCATIONS.some(l => G.run.locs[l.key].unlocked && l.loot[k]));
  if (!pool.length) return null;
  const picks = [];
  const n = pool.length > 1 && Math.random() < 0.45 ? 2 : 1;
  while (picks.length < n) {
    const k = pickRandom(pool);
    if (!picks.includes(k)) picks.push(k);
  }
  const items = {};
  let gold = 0, total = 0;
  const room = Math.max(2, capMax() - 2);
  for (const k of picks) {
    const [a, b] = ORDER_QTY[ITEMS[k].tier];
    const q = Math.max(1, Math.min(a + Math.floor(Math.random() * (b - a + 1)), room - total));
    items[k] = q;
    total += q;
    gold += ITEMS[k].gold * q;
  }
  const reward = Math.max(200, Math.round(gold * BAL.priceMax * priceMultiplier() * 1.8 / 10) * 10);
  return { items, reward };
}

function orderReady() {
  const o = G.run.order;
  return !!o && Object.keys(o.items).every(k => G.run.junk[k] >= o.items[k]);
}

function giveOrder() {
  const o = G.run.order;
  if (!o) return;
  if (!orderReady()) { sndDeny(); vibe(30); flashToast('Зина: «Не всё принёс, милок»'); return; }
  for (const k in o.items) G.run.junk[k] -= o.items[k];
  G.run.cash += o.reward;
  G.run.order = null;
  G.run.orderNext = Date.now() + (90 + Math.random() * 90) * 1000;
  flashToast(`Зина: «${pickRandom(['Спасибо, милок!', 'Вот это уважил!', 'Золотые руки!'])}» +${fmt(o.reward)} ₽`, 'vl', 'coin');
  sndBuy(); vibe(30); bumpCash();
  coinBurst(el('orderBtn'), 10);
  saveGame();
}

function skipOrder() {
  if (!G.run.order) return;
  G.run.order = null;
  G.run.orderNext = Date.now() + 45000;
  sndTab();
  saveGame();
}

function tickOrders() {
  if (!crewHas('zina') || G.run.order || Date.now() < G.run.orderNext) return;
  G.run.order = makeOrder();
}

// ===== События: Шнырь и участковый =====

const shnyr = { on: false, loc: null, x: 0, steal: 0, life: 0, fleeing: false, box: null, nextAt: 0 };
const cop = { state: null, t: 0, x: -20, hidden: false, nextAt: 0 };

function tickEvents(dt) {
  if (currentScreen !== 'game') return;
  const now = performance.now();
  tickOrders();
  // Шнырь: пока не прибился, иногда ворует на текущей точке
  if (!crewHas('shnyr') && unlockedLocCount() >= 3) {
    if (!shnyr.nextAt) shnyr.nextAt = now + 60000 + Math.random() * 60000;
    if (!shnyr.on && now >= shnyr.nextAt && currentTab === 'dig' && !storyBlocked() && !dlg.open && !cop.state) {
      Object.assign(shnyr, { on: true, loc: G.run.activeLoc, x: 0, steal: 0, life: 0, fleeing: false });
      heroSay(pickRandom(['Эй! Это моя точка!', 'А ну пошёл отсюда!', 'Опять этот…']), 2200);
    }
    if (shnyr.on && !shnyr.fleeing) {
      shnyr.life += dt;
      shnyr.steal += dt;
      if (shnyr.steal >= 5000) {
        shnyr.steal = 0;
        const ls = G.run.locs[shnyr.loc];
        if (ls && ls.stock > 0) { ls.stock--; shnyrSay(pickRandom(['Моё!', 'Хе-хе', 'Не твоё — не трогай', 'Кто первый встал…'])); }
      }
      if (shnyr.life > 40000) { shnyr.fleeing = true; shnyrSay('Ну, бывай!'); }
    }
  }
  // Участковый: с гаражей иногда проверяет точку
  if (unlockedLocCount() >= 4) {
    if (!cop.nextAt) cop.nextAt = now + 180000 + Math.random() * 120000;
    if (!cop.state && now >= cop.nextAt && currentTab === 'dig' && totalJunk() >= 5 && !storyBlocked() && !dlg.open && !shnyr.on) {
      Object.assign(cop, { state: 'alert', t: 0, x: -20, hidden: false });
      el('copAlert').classList.add('show');
      sndCopAlert(); vibe([60, 40, 60]);
    }
    if (cop.state) {
      cop.t += dt;
      if (cop.state === 'alert' && currentTab !== 'dig') endCop();
      else if (cop.state === 'alert' && cop.t >= 2800) resolveCop();
      else if (cop.state === 'leave' && cop.t >= 3500) endCop();
    }
  }
}

function shnyrSay(text) {
  const st = digScene && digScene.state;
  if (!shnyr.box || currentTab !== 'dig' || !st) return;
  bubble(el('digSceneWrap'), (shnyr.box.x + 8) * PX, shnyr.box.y * PX - 6, text, 1600);
}

/** Тап по сцене: попал ли в Шныря. clientX/Y — координаты касания. */
function shnyrHit(clientX, clientY) {
  if (!shnyr.on || shnyr.fleeing || !shnyr.box) return false;
  const r = el('digCanvas').getBoundingClientRect();
  const x = (clientX - r.left) / PX, y = (clientY - r.top) / PX, b = shnyr.box;
  return x >= b.x - 6 && x <= b.x + 22 && y >= b.y - 6 && y <= b.y + 30;
}

function chaseShnyr() {
  shnyr.fleeing = true;
  G.meta.story.shnyrChases++;
  const left = 3 - G.meta.story.shnyrChases;
  shnyrSay(left > 0 ? pickRandom(['Ай! Ухожу, ухожу!', 'Да понял я!', 'Злой ты, Палыч']) : 'Всё-всё, сдаюсь!');
  heroSay(pickRandom(['Пшёл вон!', 'И чтоб я тебя не видел!', 'Ещё раз увижу — пожалеешь']), 1800);
  sndPriceMiss(); vibe(30);
  shnyr.nextAt = performance.now() + 120000 + Math.random() * 120000;
  saveGame();
}

/** Тап по сцене во время «Шухер!»: прячем мешок. */
function hideSack() {
  if (cop.state !== 'alert' || cop.hidden) return;
  cop.hidden = true;
  el('copAlert').classList.remove('show');
  heroSay(pickRandom(['Я тут просто гуляю', 'Какой мешок? Нет мешка', 'Добрый вечер, начальник']), 2200);
  sndTab(); vibe(15);
}

function resolveCop() {
  el('copAlert').classList.remove('show');
  cop.state = 'leave';
  cop.t = 0;
  const box = el('digSceneWrap');
  const x = (cop.x + 8) * PX, y = (digScene.h - 40) * PX;
  if (cop.hidden) {
    bubble(box, x, y, pickRandom(['Показалось…', 'Ладно, гуляй', 'Смотри у меня']), 2000);
    return;
  }
  let take = Math.max(1, Math.floor(totalJunk() * 0.2));
  const taken = take;
  for (const k of ITEM_KEYS) {
    while (take > 0 && G.run.junk[k] > 0) { G.run.junk[k]--; take--; }
  }
  bubble(box, x, y, pickRandom(['Это я изымаю', 'Вещдоки, гражданин', 'Конфискация!']), 2200);
  flashToast(`Участковый забрал ${taken} шт. лома`);
  sndDeny(); vibe(60);
  saveGame();
}

function endCop() {
  el('copAlert').classList.remove('show');
  cop.state = null;
  cop.nextAt = performance.now() + 300000 + Math.random() * 240000;
}

function sndCopAlert() {
  [0, 0.22, 0.44].forEach(d => { sfx(880, 0.12, 'square', d, null, 0.6); sfx(660, 0.12, 'square', d + 0.11, null, 0.6); });
}

/** Нарисовать Шныря и участкового на сцене «Копать». */
function drawStoryActors(ctx, scene, w, groundY, px, dt, t) {
  const loc = LOCATIONS[G.ui.locView];
  shnyr.box = null;
  if (shnyr.on && loc.key === shnyr.loc) {
    if (!shnyr.x) shnyr.x = Math.min(w - 18, px + 40);
    const y = groundY - 24;
    if (shnyr.fleeing) {
      shnyr.x += dt * 0.09;
      drawCrewMember(ctx, 'shnyr', shnyr.x, y - (Math.floor(t / 90) % 2), t, false);
      if (shnyr.x > w + 20) { shnyr.on = false; if (!shnyr.nextAt || shnyr.nextAt < performance.now()) shnyr.nextAt = performance.now() + 120000 + Math.random() * 120000; }
    } else {
      const frame = Math.floor(t / 260) % 2 ? 'heroDig1' : 'heroDig2';
      drawSprite(ctx, frame, shnyr.x, y, { swap: CREW_LOOK.shnyr }, true);
      shnyr.box = { x: shnyr.x, y };
    }
  } else if (shnyr.on && shnyr.fleeing) {
    shnyr.on = false;
  }
  if (cop.state) {
    const target = Math.max(4, px - 64);
    const y = groundY - 24;
    if (cop.state === 'alert') cop.x = Math.min(target, cop.x + dt * 0.03);
    else if (cop.t > 1200) cop.x -= dt * 0.04;
    const walking = (cop.state === 'alert' && cop.x < target) || (cop.state === 'leave' && cop.t > 1200);
    drawCrewMember(ctx, 'police', cop.x, y - (walking && Math.floor(t / 150) % 2 ? 1 : 0), walking ? t : 0, cop.state === 'leave' && cop.t > 1200);
  }
}

// ===== Окно «Лагерь» =====

let campScene = null;
const camp = { stop: null, talkIn: 0, spots: [] };

function drawCampScene(ctx, w, h, t, dt, scene) {
  const d = Math.max(0.85, nightness());
  const gy = h - 22;
  drawSky(ctx, w, gy, d, 4321);
  bgFar(ctx, w, gy, d, seededRandom(4322), 30);
  drawGround(ctx, w, gy, h, '#3a3b36', d, 4321);
  const bx = Math.floor(w / 2) - 7 + 10, by = gy + 4;
  glow(ctx, bx + 7, by + 2, 40, 14, '255,140,40', 0.12);
  rect(ctx, bx - 1, by - 1, 16, 15, '#101010');
  rect(ctx, bx, by, 14, 14, '#4a3a30');
  rect(ctx, bx, by + 4, 14, 1, '#6a5a4a'); rect(ctx, bx, by + 10, 14, 1, '#6a5a4a');
  for (let fx = 0; fx < 12; fx++) {
    const n = Math.sin(t / 80 + fx * 1.3) + Math.sin(t / 51 + fx * 0.7);
    const fh = Math.max(2, Math.round(7 + n * 2.5));
    for (let fy = 0; fy < fh; fy++) {
      const k = fy / fh;
      dot(ctx, bx + 1 + fx, by - 1 - fy, k < 0.3 ? '#fff0a0' : k < 0.65 ? '#ffb030' : '#e05a20');
    }
  }
  camp.spots = drawCampCrew(ctx, bx, by, t, G.meta.crew);
  camp.talkIn -= dt;
  if (camp.talkIn <= 0) { camp.talkIn = 3500 + Math.random() * 2500; campTalk(); }
}

function campTalk() {
  if (!camp.spots.length) return;
  const s = pickRandom(camp.spots);
  const lines = s.id === 'palych' ? PALYCH_LINES : crewDef(s.id).lines;
  bubble(el('campCanvas').parentElement, s.x * PX, s.y * PX - 4, pickRandom(lines), 2600);
}

function openCamp() {
  const list = el('campList');
  list.innerHTML = '';
  const have = CREW.filter(c => crewHas(c.id)).length;
  setText('campSub', `В бригаде ${have} из ${CREW.length}. Долг Хозяину: осталось ${debtLeft()} взносов из ${BAL.prestigeMaxLevel}.`);
  for (const c of CREW) {
    const met = crewHas(c.id);
    const card = make('div', 'camp-item' + (met ? '' : ' unknown'));
    card.appendChild(faceImg(c.id, null, !met));
    const info = make('div', 'camp-info');
    const nm = make('div', 'camp-name', met ? SPEAKERS[c.id].name : '???');
    if (met) nm.style.color = SPEAKERS[c.id].color;
    info.append(nm, make('div', 'camp-role', met ? c.role : 'ещё не встречал'));
    if (met) info.append(make('div', 'camp-bio', c.bio), make('div', 'camp-bonus', c.bonus));
    else info.append(make('div', 'camp-bio', c.hint));
    card.appendChild(info);
    list.appendChild(card);
  }
  el('campModal').classList.add('show');
  sndAccOpen();
  if (!campScene) campScene = new PixelScene(el('campCanvas'), 64, drawCampScene);
  campScene.w = 0;
  camp.talkIn = 800;
  if (camp.stop) camp.stop();
  camp.stop = frameLoop(() => campScene.frame());
}

function closeCamp() {
  el('campModal').classList.remove('show');
  if (camp.stop) { camp.stop(); camp.stop = null; }
}

/** Новая игра: убрать недоигранные сценки и события. */
function resetStory() {
  dlg.queue = [];
  if (dlg.open) { clearInterval(dlg.timer); dlg.timer = null; dlg.open = false; el('dlgOverlay').classList.remove('show', 'done'); }
  Object.assign(shnyr, { on: false, nextAt: 0, box: null });
  Object.assign(cop, { state: null, nextAt: 0 });
  el('copAlert').classList.remove('show');
  orderUi.key = '';
}

// ===== Панель заказа на вкладке «Копать» =====

const orderUi = { key: '', cells: [] };

function renderOrder() {
  const panel = el('orderPanel');
  const has = crewHas('zina');
  if (has && !el('orderFace').getAttribute('src')) el('orderFace').src = faceURL('zina');
  setHidden(panel, !has);
  if (!has) return;
  const o = G.run.order;
  const key = o ? Object.keys(o.items).join(',') + o.reward : 'none';
  if (key !== orderUi.key) {
    orderUi.key = key;
    const box = el('orderItems');
    box.innerHTML = '';
    orderUi.cells = [];
    if (o) {
      for (const k in o.items) {
        const chip = make('span', 'order-chip');
        chip.appendChild(pxIcon(k));
        const txt = make('span', '', '');
        chip.appendChild(txt);
        box.appendChild(chip);
        orderUi.cells.push({ k, txt, chip, need: o.items[k] });
      }
    }
    setHidden('orderActions', !o);
  }
  if (o) {
    setText('orderWho', 'Зина просит:');
    for (const c of orderUi.cells) {
      const n = Math.min(G.run.junk[c.k], c.need);
      setText(c.txt, `${ITEMS[c.k].name} ${n}/${c.need}`);
      toggleClass(c.chip, 'ok', n >= c.need);
    }
    setText('orderBtn', `Отдать → ${fmt(o.reward)} ₽`);
    setDisabled('orderBtn', !orderReady());
  } else {
    const s = Math.max(0, Math.ceil((G.run.orderNext - Date.now()) / 1000));
    setText('orderWho', s > 0 ? `Зина думает, что попросить… ${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}` : 'Зина ищет, что попросить…');
  }
}
