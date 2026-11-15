'use strict';
// Пиксель-арт: палитра, спрайты и их отрисовка.
//
// Спрайт — массив строк, каждая буква = пиксель своего цвета, точка = пусто.
// Движок сам обводит спрайт тёмным контуром и (если shade не выключен) делает
// объём: верхние пиксели светлее, нижние темнее. Поэтому в строках достаточно
// «залить» форму базовыми цветами.
//
// На экране один пиксель спрайта = 2px (как рамки и шрифт).

const PX = 2;

// ===== Палитра =====
// Заглавные буквы — базовые цвета для предметов и иконок (с автообъёмом).
// Строчные — ручные цвета для персонажей (без автообъёма).
const PAL = {
  K: '#2c3028', E: '#4c5262', X: '#7c8492', G: '#6b7360', S: '#b8bec8', Z: '#d2e4ee', W: '#f2f4ea',
  Y: '#e8b83a', H: '#c8963a', O: '#e0802a', R: '#c8403c', B: '#3a6ec8', C: '#6dc4e8',
  N: '#3f8a2a', L: '#9ccc3c', A: '#c8ee68', P: '#8a5ac8', M: '#8a5a2e', T: '#d6b884', D: '#4a2e14', Q: '#e88ab0',
  // персонажи
  h: '#8e2a32', i: '#c0444e', s: '#e0a878', t: '#b07848', k: '#161210', g: '#9c9a8c', f: '#cfcdbd',
  c: '#5c6b36', d: '#3c4822', p: '#3a4262', q: '#262c44', b: '#2b211a', n: '#f5d060',
  m: '#5a4c44', j: '#2c2c34', J: '#4c4c5c', w: '#e8e8e0', r: '#a83a3a', u: '#3a6ea8', v: '#6a4a9a',
};

// ===== Работа с цветом =====
function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function rgbToHex(r, g, b) {
  return '#' + [r, g, b].map(v => clamp(Math.round(v), 0, 255).toString(16).padStart(2, '0')).join('');
}
/** Смешать цвет с другим: t=0 — первый, t=1 — второй. */
function mixColor(a, b, t) {
  const x = hexToRgb(a), y = hexToRgb(b);
  return rgbToHex(x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t);
}
const lighten = (c, t) => mixColor(c, '#ffffff', t);
const darken = (c, t) => mixColor(c, '#000000', t);

// ===== Спрайты =====

const SPR = {
  // --- Предметы (12×12) ---
  resist: ['............', '............', '............', '............', '..TTTTTTTT..', 'SSTRTYTBTTSS',
    'SSTRTYTBTTSS', '..TTTTTTTT..', '............', '............', '............', '............'],
  caps: ['...SSSSSS...', '...BBBBBB...', '...BBBBWB...', '...BBBBWB...', '...BBBBWB...', '...BBBBWB...',
    '...BBBBWB...', '...BBBBBB...', '...BBBBBB...', '....S..S....', '....S..S....', '....S..S....'],
  trans: ['............', '....KKKK....', '...KKKKKK...', '...KKKKKK...', '...KKKKKK...', '...KKKKKK...',
    '...GGGGGG...', '....S.S.S...', '....S.S.S...', '....S.S.S...', '....S.S.S...', '............'],
  chips: ['............', '..S.S.S.S.S.', '..S.S.S.S.S.', '.KKKKKKKKKK.', '.KWKKKKKKKK.', '.KKKKKKKKKK.',
    '.KKKKKKKKKK.', '.KKKKKKKKKK.', '.KKKKKKKKKK.', '..S.S.S.S.S.', '..S.S.S.S.S.', '............'],
  hdd: ['............', '.SSSSSSSSSS.', '.SSXXXXXSSS.', '.SXXXXXXXSS.', '.SXXWKKXXSS.', '.SXXXKKXXSS.',
    '.SXXXXXXXSS.', '.SSXXXXXSKS.', '.SSSSSSSSKS.', '.SSSSSSSSSS.', '.SSKSSSSKSS.', '............'],
  phones: ['....KKKK....', '...KKKKKK...', '...KCCCCK...', '...KCCCCK...', '...KCWCCK...', '...KCCCCK...',
    '...KKKKKK...', '...KSKKSK...', '...KKSSKK...', '...KSKKSK...', '...KKKKKK...', '....KKKK....'],
  ram: ['............', '............', '............', 'NNNNNNNNNNNN', 'NKKNKKNKKNNN', 'NKKNKKNKKNWN',
    'NNNNNNNNNNNN', 'YNYNYNYNYNYN', 'Y.Y.Y.Y.Y.Y.', '............', '............', '............'],
  connect: ['............', '...Y.Y.Y.Y..', '...Y.Y.Y.Y..', '...Y.Y.Y.Y..', '..KKKKKKKKK.', '..KKKKKKKKK.',
    '..KKKKKKKKK.', '...Y.Y.Y.Y..', '...Y.Y.Y.Y..', '............', '............', '............'],
  silverWire: ['...SSSSSS...', '..SS....SS..', '.SS.SSSS.SS.', '.S.SS..SS.S.', '.S.S....S.S.', '.S.S....S.S.',
    '.S.SS..SS.S.', '.SS.SSSS.SS.', '..SS....SS..', '...SSSSSS...', '........SSS.', '..........SS'],
  cpus: ['............', '.NNNNNNNNNN.', '.NSSSSSSSSN.', '.NSZZZZZZSN.', '.NSZSSSSZSN.', '.NSZSSSSZSN.',
    '.NSZSSSSZSN.', '.NSZZZZZZSN.', '.NSSSSSSSSN.', '.YNNNNNNNNN.', '............', '............'],
  rare: ['............', '.NNNNNNNNNN.', '.NNNNNNNNYN.', '.NNNRNNLLYN.', '.NRRRRRNNYN.', '.NNRRRNNLLN.',
    '.NNRNRNNNLN.', '.NNNNNNNNLN.', '.NKKNKKNNNN.', '.NNNNNNNNNN.', '............', '............'],
  brass: ['............', '...HHHHH....', '..HHHHHHH...', '.HHHHHHHHH..', '.HHHKKKHHH..', '.HHHK.KHHH..',
    '.HHHKKKHHH..', '.HHHHHHHHH..', '..HHHHHHH...', '...HHHHH....', '............', '............'],
  gContacts: ['............', '............', 'NNNNNNNNNNNN', 'NNKKKNNNKKKN', 'NNKKKNNNKKKN', 'NNNNNNNNNNNN',
    'YNYNYNYNYNYN', 'Y.Y.Y.Y.Y.Y.', 'Y.Y.Y.Y.Y.Y.', 'Y.Y.Y.Y.Y.Y.', '............', '............'],
  goldPins: ['............', '...Y....Y...', '...Y...Y....', '....Y.Y..Y..', '.....YY.Y...', '....YYYYY...',
    '...YYYYYYY..', '..YYYYYYYYY.', '.YYYYYYYYYYY', '............', '............', '............'],
  legend: ['............', '.PPPPPPPPPP.', '.PKKKKPYYYP.', '.PKWKKPPPYP.', '.PKKKKPYYYP.', '.PPPPPPYPPP.',
    '.PYYYPPYPSP.', '.PPPYYYYPSP.', '.PPPPPPPPPP.', '.Y.Y.Y.Y.Y..', '............', '............'],
  platinum: ['..........W.', '.........WWW', '..ZZZZZZZZW.', '.ZZZZZZZZZZ.', '.ZWWZZZZZZZ.', '.ZWZZZZZZZZ.',
    '.ZZZZZZZZZZ.', '.ZZZZZZZZZZ.', '.ZZZZZZZZZZ.', '..ZZZZZZZZ..', '............', '............'],

  // --- Интерфейс ---
  pickaxe: ['..SSSSSSS...', '.SS.....SS..', 'SS...MM...SS', 'S....MM....S', '.....MM.....', '.....MM.....',
    '.....MM.....', '.....MM.....', '.....MM.....', '.....MM.....', '.....MM.....', '............'],
  flask: ['....CCCC....', '.....CC.....', '.....CC.....', '....CAAC....', '...CAAAAC...', '..CAAAAAAC..',
    '.CAAAAWAAAC.', '.CAAAAAAAAC.', '.CAAAAAAAAC.', '..CCCCCCCC..', '............', '............'],
  fire: ['.....R......', '.....RR.....', '....RRR.....', '....RORR....', '...RROORR...', '..RROOYORR..',
    '..ROOYYOOR..', '.RROYYYYORR.', '.ROOYWWYOOR.', '.ROOYWWYOOR.', '..ROOYYOOR..', '...RRRRRR...'],
  up: ['.....CC.....', '....CCCC....', '...CCCCCC...', '..CCCCCCCC..', '.CCCCCCCCCC.', '....CCCC....',
    '....CCCC....', '....CCCC....', '....CCCC....', '....CCCC....', '....CCCC....', '............'],
  lock: ['............', '....SSSS....', '...SS..SS...', '...S....S...', '...S....S...', '..YYYYYYYY..',
    '..YYYYYYYY..', '..YYYKKYYY..', '..YYYKKYYY..', '..YYYYYYYY..', '..YYYYYYYY..', '............'],
  anvil: ['............', '.......M....', '......MMM...', '..EEEEEMEEEE', 'EEEEEEEEEEE.', '.EEEEEEEEE..',
    '....EEEE....', '....EEEE....', '...EEEEEE...', '..EEEEEEEE..', '..EEEEEEEE..', '............'],
  gear: ['....SS....', '.S.SSSS.S.', '..SSSSSS..', '.SSS..SSS.', 'SSS....SSS', 'SSS....SSS',
    '.SSS..SSS.', '..SSSSSS..', '.S.SSSS.S.', '....SS....'],
  star: ['....Y....', '....Y....', '...YYY...', 'YYYYYYYYY', '.YYYYYYY.', '..YYYYY..', '..YY.YY..', '.YY...YY.', '.Y.....Y.'],
  pstar: ['....P....', '....P....', '...PPP...', 'PPPPPPPPP', '.PPPPPPP.', '..PPPPP..', '..PP.PP..', '.PP...PP.', '.P.....P.'],
  trash: ['....EEEE....', '.EEEEEEEEEE.', '............', '..EEEEEEEE..', '..EKEEKEEK..', '..EKEEKEEK..',
    '..EKEEKEEK..', '..EKEEKEEK..', '..EEEEEEEE..', '............'],
  coin: ['..YYY..', '.YYYYY.', 'YYYKYYY', 'YYYKYYY', 'YYYKYYY', '.YYYYY.', '..YYY..'],
  ingot: ['..YYYY..', '.YYYYYY.', 'YYYYYYYY'],
  bolt: ['.Y.', 'YYY', '.Y.'],
  arrowL: ['...W', '..WW', '.WWW', 'WWWW', '.WWW', '..WW', '...W'],
  arrowR: ['W...', 'WW..', 'WWW.', 'WWWW', 'WWW.', 'WW..', 'W...'],
  // иконки прокачек
  box: ['............', '.MMMMMMMMMM.', '.MTTTTTTTTM.', '.MMMMMMMMMM.', '.MTMTTTTMTM.', '.MTTMTTMTTM.', '.MTTTMMTTTM.', '.MTTTMMTTTM.', '.MTTMTTMTTM.', '.MTMTTTTMTM.', '.MMMMMMMMMM.', '............'],
  finger: ['.....TT.....', '.....TT.....', '.....TT.....', '.....TTTT...', '..TT.TTTTTT.', '..TTTTTTTTT.', '...TTTTTTTT.', '...TTTTTTT..', '....TTTTTT..', '....TTTTT...', '....BBBBB...', '....BBBBB...'],
  clock: ['....SSSS....', '..SSWWWWSS..', '.SWWWWKWWWS.', '.SWWWWKWWWS.', 'SWWWWWKWWWWS', 'SWWWWWKKKWWS', 'SWWWWWWWWWWS', '.SWWWWWWWWS.', '.SWWWWWWWWS.', '..SSWWWWSS..', '....SSSS....', '............'],
  clover: ['............', '..NN....NN..', '.NNNN..NNNN.', '.NNNNNNNNNN.', '..NNNNNNNN..', '....NNNN....', '....NNNN....', '..NNNNNNNN..', '.NNNNNNNNNN.', '.NNNN..NNNN.', '..NN.MM.NN..', '......MM....'],
  eye: ['............', '............', '....KKKK....', '..KKWWWWKK..', '.KWWWBBWWWK.', 'KWWWBBKBWWWK', 'KWWWBKKBWWWK', '.KWWWBBWWWK.', '..KKWWWWKK..', '....KKKK....', '............', '............'],
  medal: ['..RR....RR..', '...RR..RR...', '....RRRR....', '.....RR.....', '....YYYY....', '...YYYYYY...', '..YYYWWYYY..', '..YYWWWWYY..', '..YYYWWYYY..', '...YYYYYY...', '....YYYY....', '............'],
  target: ['....RRRR....', '..RRWWWWRR..', '.RWWRRRRWWR.', '.RWRRWWRRWR.', 'RWRRWWWWRRWR', 'RWRWWRRWWRWR', 'RWRWWRRWWRWR', 'RWRRWWWWRRWR', '.RWRRWWRRWR.', '.RWWRRRRWWR.', '..RRWWWWRR..', '....RRRR....'],
  moon: ['....ZZZZ....', '..ZZZZZ.....', '.ZZZZZ......', '.ZZZZ.......', 'ZZZZ.....Y..', 'ZZZZ....YYY.', 'ZZZZ.....Y..', 'ZZZZ........', '.ZZZZ.......', '.ZZZZZ......', '..ZZZZZ.....', '....ZZZZ....'],
  sack: ['.....MM.....', '....M..M....', '.....MM.....', '....TTTT....', '...TTTTTT...', '..TTTTTTTT..', '.TTTTTTTTTT.', '.TTTTYYTTTT.', '.TTTYTTTTTT.', '.TTTTYYTTTT.', '..TTTTTTTT..', '...TTTTTT...'],
  recycle: ['....LLLL....', '..LLLLLLLL..', '.LL......LL.', '.L......LLLL', 'LL.......LL.', 'LL..........', '..........LL', '.LL.......LL', 'LLLL......L.', '.LL......LL.', '..LLLLLLLL..', '....LLLL....'],
  cat: ['.......m.m', 'm......mnm', '.mmmmmmmmm', '..mmmmmmm.', '..m.m..m.m'],
  cat2: ['.......m.m', 'm......mnm', '.mmmmmmmmm', '..mmmmmmm.', '...m.mm.m.'],
  worker: ['..PP..', '.PPPP.', '.TTTT.', '..TT..', '.GGGG.', 'GGGGGG', '.G..G.'],
  // Амулет: @ — цвет конкретного амулета
  amulet: ['..S....S..', '...S..S...', '....SS....', '....YY....', '...Y@@Y...', '..Y@@@@Y..',
    '..Y@W@@Y..', '..Y@@@@Y..', '...Y@@Y...', '....YY....'],

  // --- Герой (16×24), без автообъёма ---
  heroIdle: [
    '................', '......hhhh......', '.....hhhhhh.....', '.....iiiiiii....', '.....tsssssss...',
    '.....tsssskss...', '.....tssssssss..', '.....tgggggggg..', '......gfgggggg..', '....ddccgggcc...',
    '...dcccccccccc..', '...dccccccccccs.', '...dcddccccccss.', '...dcdccccccc...', '...dcdccccccc...',
    '...ddcccccccc...', '....qpppppppp...', '....qppp..ppp...', '....qppp..ppp...', '....qppp..ppp...',
    '....qppp..ppp...', '...bbbbb.bbbbb..', '...bbbbb.bbbbb..', '................'],
  heroDig1: [
    '................', '................', '................', '........hhhh....', '.......hhhhhh...',
    '.......iiiiiii..', '.......tssssss..', '......dtssskss..', '.....ddtgggggg..', '....dccccgggg...',
    '...dcccccccccc..', '...dccccccccccc.', '...dcccccccccss.', '...ddccccccc.ss.', '....dcccccc..ss.',
    '....ddccccc.....', '....qpppppppp...', '....qppp..ppp...', '....qppp..ppp...', '....qppp..ppp...',
    '....qppp..ppp...', '...bbbbb.bbbbb..', '...bbbbb.bbbbb..', '................'],
  heroDig2: [
    '..............s.', '......hhhh...ss.', '.....hhhhhh..cs.', '.....iiiiiii.cc.', '.....tsssssscc..',
    '.....tsssskcc...', '.....tssssssc...', '.....tggggggg...', '......gfggggg...', '....ddccgggcc...',
    '...dcccccccccc..', '...dcccccccccc..', '...dcddccccccc..', '...dcdccccccc...', '...dcdccccccc...',
    '...ddcccccccc...', '....qpppppppp...', '....qppp..ppp...', '....qppp..ppp...', '....qppp..ppp...',
    '....qppp..ppp...', '...bbbbb.bbbbb..', '...bbbbb.bbbbb..', '................'],
  // Скупщик за прилавком (видна верхняя половина)
  buyer: [
    '................', '.....kkkkkk.....', '....kkkkkkkk....', '....kkkkkkkkkkk.', '.....tsssssss...',
    '.....tkkkskkk...', '.....tssssssss..', '.....tsssskkss..', '......tsssssss..', '....jjjtssstjjj.',
    '...jjjjjnnnjjjj.', '..jjJjjjjnjjjJjj', '..jjJjjjjjjjjJjj', '..jjJjjjjjjjjJjj', '..jjjjjjjjjjjjjj'],
};

// Спрайты без автообъёма (персонажи нарисованы вручную)
const NO_SHADE = { heroIdle: 1, heroDig1: 1, heroDig2: 1, buyer: 1, cat: 1, cat2: 1 };

// Герой: кадр «вдох» — верх тела опущен на пиксель
SPR.heroIdle2 = ['................'].concat(SPR.heroIdle.slice(0, 15), SPR.heroIdle.slice(16));
NO_SHADE.heroIdle2 = 1;

// ===== Отрисовка спрайта в canvas =====

const _sprCache = {};

/**
 * Готовый canvas спрайта в «логических» пикселях (1 пиксель = 1 точка),
 * уже с контуром. opts: tint — цвет для «@», swap — замена цветов { 'c': '#hex' }, outline: false.
 */
function spriteCanvas(name, opts) {
  opts = opts || {};
  const key = name + '|' + JSON.stringify(opts);
  if (_sprCache[key]) return _sprCache[key];
  const rows = SPR[name];
  if (!rows) throw new Error('Нет спрайта ' + name);
  const h = rows.length, w = Math.max(...rows.map(r => r.length));
  const shade = !NO_SHADE[name] && opts.shade !== false && !opts.silhouette;
  const colorOf = ch => (opts.silhouette ? '#3a4232' : ch === '@' ? opts.tint : (opts.swap && opts.swap[ch]) || PAL[ch]);
  const at = (x, y) => (y >= 0 && y < h && x >= 0 && x < w && rows[y][x] && rows[y][x] !== '.' ? rows[y][x] : null);

  const pad = opts.outline === false ? 0 : 1;
  const cv = document.createElement('canvas');
  cv.width = w + pad * 2;
  cv.height = h + pad * 2;
  const ctx = cv.getContext('2d');

  // Контур: пустой пиксель рядом с заполненным — тёмный оттенок соседа
  if (pad) {
    for (let y = -1; y <= h; y++) {
      for (let x = -1; x <= w; x++) {
        if (at(x, y)) continue;
        const n = at(x, y - 1) || at(x, y + 1) || at(x - 1, y) || at(x + 1, y);
        if (!n) continue;
        ctx.fillStyle = darken(colorOf(n) || '#000000', 0.72);
        ctx.fillRect(x + pad, y + pad, 1, 1);
      }
    }
  }
  // Заливка с объёмом
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const ch = at(x, y);
      if (!ch) continue;
      let c = colorOf(ch);
      if (shade) {
        if (at(x, y - 1) !== ch) c = lighten(c, 0.28);
        else if (at(x, y + 1) !== ch || at(x + 1, y) !== ch) c = darken(c, 0.22);
      }
      ctx.fillStyle = c;
      ctx.fillRect(x + pad, y + pad, 1, 1);
    }
  }
  _sprCache[key] = cv;
  return cv;
}

const _urlCache = {};
/** Картинка спрайта (data:URL) — для <img> в разметке. */
function spriteURL(name, opts) {
  const key = name + '|' + JSON.stringify(opts || {});
  if (!_urlCache[key]) _urlCache[key] = spriteCanvas(name, opts).toDataURL();
  return _urlCache[key];
}

/** <img> со спрайтом в масштабе PX (или scale). */
function pxIcon(name, className, opts, scale = PX) {
  const img = document.createElement('img');
  const cv = spriteCanvas(name, opts);
  img.src = spriteURL(name, opts);
  img.className = 'px-ic' + (className ? ' ' + className : '');
  img.width = cv.width * scale;
  img.height = cv.height * scale;
  img.alt = '';
  img.draggable = false;
  return img;
}

/** Поставить картинку спрайта в существующий <img>, если она поменялась. */
function setIcon(img, name, opts, scale = PX) {
  if (!img) return;
  const src = spriteURL(name, opts);
  if (img.getAttribute('src') === src) return;
  const cv = spriteCanvas(name, opts);
  img.src = src;
  img.width = cv.width * scale;
  img.height = cv.height * scale;
}

/** Нарисовать спрайт на сцене. flip — зеркально по горизонтали. */
function drawSprite(ctx, name, x, y, opts, flip = false) {
  const cv = spriteCanvas(name, opts);
  if (!flip) { ctx.drawImage(cv, Math.round(x), Math.round(y)); return; }
  ctx.save();
  ctx.translate(Math.round(x) + cv.width, Math.round(y));
  ctx.scale(-1, 1);
  ctx.drawImage(cv, 0, 0);
  ctx.restore();
}

/** Детерминированный генератор случайных чисел (одна и та же «случайность» на каждый кадр). */
function seededRandom(seed) {
  let s = seed >>> 0 || 1;
  return () => {
    s ^= s << 13; s >>>= 0;
    s ^= s >> 17;
    s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
}
