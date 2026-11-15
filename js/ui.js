'use strict';
// Всё, что касается экрана: построение элементов и их обновление каждый кадр.
// Правило: здесь ничего не меняется в игре — только показывается состояние G.
// (Исключение — переключение вкладок и аккордеонов: это состояние интерфейса.)

let currentScreen = 'menu';
let currentTab = 'dig';
let currentSub = 'normal';

// ===== Экраны и вкладки =====

function showScreen(name) {
  currentScreen = name;
  toggleClass('menuScreen', 'active', name === 'menu');
  toggleClass('gameScreen', 'active', name === 'game');
  if (name === 'menu') updateMenu();
  window.scrollTo(0, 0);
}

function switchTab(name, silent) {
  currentTab = name;
  setRevealedAmulet(null);
  document.querySelectorAll('.tab-section').forEach(s => toggleClass(s, 'active', s.dataset.tab === name));
  document.querySelectorAll('.tab-btn').forEach(b => toggleClass(b, 'active', b.dataset.tab === name));
  if (name === 'upg') applyAccordions();
  // Бейдж гаснет при заходе во вкладку
  if (BADGES[name]) G.ui.badgeSeen[name] = BADGES[name]();
  window.scrollTo(0, 0);
  if (!silent) { sndTab(); vibe(8); }
}

function switchSub(name) {
  currentSub = name;
  setHidden('subviewNormal', name !== 'normal');
  setHidden('subviewPrest', name !== 'prest');
  toggleClass('subtabNormal', 'active', name === 'normal');
  toggleClass('subtabPrest', 'active', name === 'prest');
  window.scrollTo(0, 0);
  sndTab(); vibe(8);
}

function toggleAccordion(key) {
  G.ui.acc[key] = !G.ui.acc[key];
  if (G.ui.acc[key]) sndAccOpen(); else sndAccClose();
  vibe(8);
  applyAccordions();
  saveGame();
}

function applyAccordions() {
  document.querySelectorAll('[data-acc]').forEach(h => toggleClass(h, 'open', !!G.ui.acc[h.dataset.acc]));
  document.querySelectorAll('[data-accbody]').forEach(b => toggleClass(b, 'open', !!G.ui.acc[b.dataset.accbody]));
}

// ===== Короткие эффекты =====

let toastTimer = null;
/** Всплывающее сообщение. tier — цвет (jk/cm/vl/rp/lg), icon — спрайт перед текстом. */
function flashToast(msg, tier, icon) {
  const t = el('toast');
  t.className = 'toast' + (tier ? ' t-' + tier : '');
  t.textContent = '';
  if (icon) t.appendChild(pxIcon(icon, 'toast-ic'));
  t.appendChild(document.createTextNode(msg));
  // На вкладке «Копать» тост встаёт на небо сцены, чтобы не закрывать кнопки
  let left = '50%', top = '50%';
  if (currentTab === 'dig' && currentScreen === 'game') {
    const r = el('digSceneWrap').getBoundingClientRect();
    if (r.top >= 40 && r.bottom <= window.innerHeight - 120) {
      left = (r.left + r.width / 2) + 'px';
      top = (r.top + 52) + 'px';
    }
  }
  t.style.left = left;
  t.style.top = top;
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 1600);
}

const bumpCash = () => replayAnim('cashWrap', 'bump', 200);
const shakeDigBtn = () => replayAnim('digBtn', 'shake', 400);
const flashSellBtn = () => replayAnim('sellBtn', 'flash', 450);
const flashPrestBtn = () => replayAnim('prestBtn', 'flash', 650);
const flashBought = e => replayAnim(e, 'bought', 450);

let autoSalePopTimer = null;
function showAutoSalePop(amount) {
  const e = el('autoSalePop');
  e.textContent = '+' + fmt(amount) + '₽';
  e.classList.remove('show');
  void e.offsetWidth;
  e.classList.add('show');
  clearTimeout(autoSalePopTimer);
  autoSalePopTimer = setTimeout(() => e.classList.remove('show'), 1500);
}

/** Цветное свечение по краям экрана от надетого амулета. */
function updateBloom() {
  const ov = el('bloomOverlay');
  const a = G && G.meta.equipped ? amuletDef(G.meta.equipped) : null;
  ov.style.background = a ? `radial-gradient(ellipse 80% 70% at center, transparent 15%, ${a.color} 85%, transparent 100%)` : 'transparent';
  toggleClass(ov, 'active', !!a);
}

/** Показать ошибку на экране (раньше ошибки молча проглатывались). */
let errorShown = false;
function showError(err) {
  console.error(err);
  if (errorShown) return;
  errorShown = true;
  const b = el('errorBanner');
  b.textContent = 'Ошибка в игре: ' + (err && err.message ? err.message : err) + ' (тапни, чтобы скрыть)';
  b.classList.add('show');
  b.onclick = () => b.classList.remove('show');
}

// ===== Меню, настройки, оффлайн =====

function updateMenu() {
  const has = hasSave();
  setHidden('btnContinue', !has);
  let info = '';
  if (has && lastSaveTs) {
    const t = new Date(lastSaveTs);
    info = `Сохранение от ${t.getDate()}.${pad2(t.getMonth() + 1)} ${pad2(t.getHours())}:${pad2(t.getMinutes())}`;
  }
  setText('saveInfo', info);
  setText('menuVersion', VERSION_LABEL);
}

function openSettings() {
  const t = lastSaveTs ? new Date(lastSaveTs) : null;
  setText('settingsSaveInfo', t ? `последнее: ${pad2(t.getHours())}:${pad2(t.getMinutes())}` : 'нет сохранения');
  toggleClass('tglSound', 'on', G.settings.sound);
  toggleClass('tglMusic', 'on', G.settings.music);
  toggleClass('tglVibe', 'on', G.settings.vibe);
  el('settingsModal').classList.add('show');
}

function closeSettings() {
  el('settingsModal').classList.remove('show');
}

// ===== Альбом находок =====

const TIER_NAME = { jk: 'мусор', cm: 'обычное', vl: 'ценное', rp: 'редкое', lg: 'легендарное' };

function openAlbum() {
  const grid = el('albumGrid');
  grid.innerHTML = '';
  let have = 0;
  for (const k of ITEM_KEYS) {
    const it = ITEMS[k], n = G.meta.found[k] || 0;
    if (n) have++;
    const card = make('div', 'album-item t-' + it.tier + (n ? '' : ' unknown'));
    card.appendChild(pxIcon(k, null, n ? null : { silhouette: true }));
    card.appendChild(make('div', 'album-name', n ? it.name : '???'));
    card.appendChild(make('div', 'album-meta', n ? `${TIER_NAME[it.tier]} · найдено ${fmt(n)}` : TIER_NAME[it.tier]));
    grid.appendChild(card);
  }
  setText('albumSub', `Собрано ${have} из ${ITEM_KEYS.length}. Альбом не сбрасывается при престиже.`);
  sndAccOpen();
  el('albumModal').classList.add('show');
}

function showOfflineOverlay(info) {
  setText('ocTime', 'Тебя не было: ' + fmtHoursMinutes(info.elapsedSec * 1000));
  setText('ocTotal', '+' + fmt(info.total) + ' ₽');
  setText('ocManual', '+' + fmt(info.manual) + ' ₽');
  setText('ocAuto', '+' + fmt(info.auto) + ' ₽');
  setHidden('ocAutoRow', !info.hasAuto);
  setText('ocNote', pickRandom(TEXT.offline));
  el('offlineOverlay').classList.add('show');
}

function hideOfflineOverlay() {
  el('offlineOverlay').classList.remove('show');
}

// ===== Построение элементов (один раз при запуске) =====

const ui = { locDots: [], invCells: {}, acidLines: {}, upgRows: {}, groupWraps: {}, amuletRows: {} };

function buildUi() {
  fillStaticIcons();
  buildScenes();
  buildLocDots();
  buildInventory();
  buildAcidInventory();
  buildUpgradePanels();
  buildAmuletList();
  buildAcidMiniGame();
  buildFireMiniGame();
  document.addEventListener('pointerdown', closeRevealedOnOutsideTap, true);
}

/** Картинки в разметке: <img data-icon="имя" data-scale="2">. */
function fillStaticIcons() {
  document.querySelectorAll('img[data-icon]').forEach(img => {
    img.classList.add('px-ic');
    setIcon(img, img.dataset.icon, null, Number(img.dataset.scale || PX));
  });
}

/** Точки-индикаторы под сценой: какая по счёту точка сбора на экране. */
function buildLocDots() {
  const box = el('locDots');
  for (let i = 0; i < LOCATIONS.length; i++) {
    const d = make('span', 'scene-dot');
    box.appendChild(d);
    ui.locDots.push(d);
  }
}

function buildInventory() {
  const row = el('invRow');
  for (const k of ITEM_KEYS) {
    const it = ITEMS[k];
    const cell = make('div', 'inv-item');
    cell.dataset.action = 'item-info';
    cell.dataset.arg = k;
    const n = make('div', 'n', '0');
    cell.append(pxIcon(k, 'ic'), n);
    row.appendChild(cell);
    ui.invCells[k] = { cell, n };
  }
}

function buildAcidInventory() {
  const box = el('acidInvList');
  for (const k of ITEM_KEYS) {
    const it = ITEMS[k];
    const line = make('div', 'inv-line');
    line.dataset.action = 'lock';
    line.dataset.arg = k;
    const cnt = make('span', 'il-cnt'), au = make('span', 'il-au');
    line.append(pxIcon('lock', 'il-lock', null, 1), pxIcon(k, 'il-ic'), make('span', 'il-name', it.name), cnt, au);
    box.appendChild(line);
    ui.acidLines[k] = { line, cnt, au };
  }
}

// Картинка для каждой прокачки (по ключу; regen:… и autoDig:… — по началу ключа)
const UPG_ICON = {
  acid: 'flask', fire: 'fire', cap: 'box', hold: 'finger', scavspd: 'pickaxe', acidspd: 'clock', firespd: 'clock',
  secondacid: 'flask', secondfire: 'fire', goodeye: 'eye', luck: 'clover', reputation: 'medal', wideZone: 'target',
  offlineRate: 'moon', offlineCap: 'sack', regen: 'recycle', autoSpeed: 'clock', autoLuck: 'clover', autoDig: 'worker',
  forgeSpeed: 'anvil', forgeDiscount: 'coin', forgeDuration: 'clock', twoForges: 'anvil',
  bonusBoost: 'pstar', startCash: 'coin', locDiscount: 'lock', acidII: 'flask', fireII: 'fire', capII: 'box',
  automation: 'gear', autoWorkers: 'worker', autoCapLv: 'box', autoAcidSpeed: 'flask', autoAcidPurity: 'flask',
  autoFireSpeed: 'fire', autoFireHeat: 'fire', autoSaleSpeed: 'ingot', autoMarkup: 'coin',
};
const upgIconName = key => UPG_ICON[key] || UPG_ICON[key.split(':')[0]] || 'up';

function buildUpgradePanels() {
  for (const group of UPG_GROUPS) {
    const isPrest = group.panel === 'prest';
    const wrap = make('div');
    const head = make('div', 'acc-head' + (isPrest ? ' prest' : '') + (group.last ? ' no-border' : ''));
    head.dataset.action = 'acc';
    head.dataset.arg = group.key;
    head.dataset.acc = group.key;
    head.append(make('span', 'acc-title', group.title), make('span', 'acc-arrow', '▼'));
    const body = make('div', 'acc-body');
    body.dataset.accbody = group.key;
    for (const u of UPGRADES.filter(x => x.group === group.key)) {
      const row = make('div', 'upg' + (isPrest ? ' prest' : '') + (u.style ? ' ' + u.style : ''));
      const slot = make('div', 'upg-ic');
      slot.appendChild(pxIcon(upgIconName(u.key)));
      const info = make('div', 'upg-info');
      const desc = make('div', 'upg-desc');
      info.append(make('div', 'upg-name', u.name), desc);
      let segs = null;
      const lvl = make('span', 'upg-lvl');
      if (u.max > 1) {
        const segRow = make('div', 'upg-segrow');
        const bar = make('div', 'upg-segs');
        segs = [];
        for (let i = 0; i < u.max; i++) segs.push(bar.appendChild(make('span')));
        segRow.append(bar, lvl);
        info.appendChild(segRow);
      }
      const btn = make('button', 'upg-btn');
      btn.type = 'button';
      btn.dataset.action = 'buy';
      btn.dataset.arg = u.key;
      row.append(slot, info, btn);
      body.appendChild(row);
      ui.upgRows[u.key] = { row, desc, btn, lvl, segs, lastLv: -1 };
    }
    wrap.append(head, body);
    el(isPrest ? 'upgPrestPanel' : 'upgNormalPanel').appendChild(wrap);
    ui.groupWraps[group.key] = wrap;
  }
}

function buildAmuletList() {
  const box = el('amuletList');
  for (const a of AMULETS) {
    const wrap = make('div', 'amulet-row-wrap');
    const trash = make('div', 'amulet-trash');
    trash.appendChild(pxIcon('trash'));
    trash.dataset.action = 'amulet-dissolve';
    trash.dataset.arg = a.key;

    const row = make('div', 'amulet-row');
    const icon = make('div', 'am-icon');
    icon.appendChild(pxIcon('amulet', null, { tint: a.color }));

    const body = make('div', 'am-body');
    const time = make('div', 'am-time');
    const recipe = make('div', 'am-recipe');
    const chips = {};
    for (const k in a.recipe) {
      const chip = make('span', 'rec-chip');
      chips[k] = { chip, txt: make('span') };
      chip.append(pxIcon(k, 'chip-ic', null, 1), chips[k].txt);
      recipe.appendChild(chip);
    }
    body.append(make('p', 'am-name', a.name), make('div', 'am-effect', a.effect), time, recipe);

    const action = make('div', 'am-action');
    const equipBtn = make('button', 'am-btn');
    equipBtn.type = 'button';
    equipBtn.dataset.arg = a.key;
    const swipeHint = make('div', 'am-swipe-hint', 'свайп ← удалить');
    const craftBtn = make('button', 'am-btn craft');
    craftBtn.type = 'button';
    craftBtn.dataset.action = 'amulet-craft';
    craftBtn.dataset.arg = a.key;
    const craftTime = make('div', 'am-time-to-craft');
    action.append(equipBtn, swipeHint, craftBtn, craftTime);

    row.append(icon, body, action);
    wrap.append(trash, row);
    box.appendChild(wrap);
    ui.amuletRows[a.key] = { wrap, trash, row, time, recipe, chips, equipBtn, swipeHint, craftBtn, craftTime };
    attachSwipe(row, a.key);
  }
}

// ===== Свайп амулета влево — показать корзину =====

const SWIPE_WIDTH = 78;
let revealedAmulet = null;
let swipeActive = false;

function setRevealedAmulet(key) {
  revealedAmulet = key;
  for (const k in ui.amuletRows) {
    const row = ui.amuletRows[k].row;
    row.style.transform = k === key ? `translateX(-${SWIPE_WIDTH}px)` : 'translateX(0)';
  }
}

function closeRevealedOnOutsideTap(e) {
  if (revealedAmulet && !e.target.closest('.amulet-row-wrap')) setRevealedAmulet(null);
}

function attachSwipe(row, key) {
  let startX = 0, startY = 0, x = 0, dragging = false, swiping = false, pid = null;
  const base = () => (revealedAmulet === key ? -SWIPE_WIDTH : 0);
  const finish = () => {
    dragging = false;
    swipeActive = false;
    row.classList.remove('swiping');
    try { row.releasePointerCapture(pid); } catch (er) { /* уже отпущен */ }
    pid = null;
  };
  row.addEventListener('pointerdown', e => {
    if (!G.meta.amulets[key] || swipeActive) return;
    if (revealedAmulet && revealedAmulet !== key) setRevealedAmulet(null);
    startX = e.clientX; startY = e.clientY;
    x = base();
    dragging = true; swiping = false; swipeActive = true; pid = e.pointerId;
    try { row.setPointerCapture(pid); } catch (er) { /* не страшно */ }
    row.classList.add('swiping');
  });
  row.addEventListener('pointermove', e => {
    if (!dragging || e.pointerId !== pid) return;
    const dx = e.clientX - startX, dy = e.clientY - startY;
    if (!swiping) {
      if (Math.abs(dx) > 8 && Math.abs(dx) > Math.abs(dy) * 1.1) swiping = true;
      else if (Math.abs(dy) > 8) { finish(); row.style.transform = `translateX(${base()}px)`; return; }
      else return;
    }
    e.preventDefault();
    x = clamp(base() + dx, -SWIPE_WIDTH, 0);
    row.style.transform = `translateX(${x}px)`;
  });
  const end = () => {
    if (!dragging) return;
    finish();
    // Свайпнул больше чем наполовину — корзина открыта; иначе (и при простом тапе) — закрыта
    setRevealedAmulet(swiping && x < -SWIPE_WIDTH / 2 ? key : null);
  };
  row.addEventListener('pointerup', end);
  row.addEventListener('pointercancel', end);
}

// ===== Подсказки новичку =====
// Показываются по одной, когда случается нужная ситуация. Пропадают по «Понял»
// или когда игрок сделал то, что советовали.

const TIPS = [
  { id: 'dig', when: () => currentTab === 'dig' && !ITEM_KEYS.some(k => G.meta.found[k]),
    text: 'Жми «Порыться» — я буду искать лом в мусоре.' },
  { id: 'full', when: () => totalJunk() >= capMax(),
    text: 'Склад полон! Неси лом на вкладку «Кислота» и растворяй.' },
  { id: 'acid', when: () => currentTab === 'acid' && totalJunk() > 0 && G.run.solution <= 0 && !G.run.acid.some(v => v.active),
    text: 'Жми «Растворить»: лом растворится, получится раствор.' },
  { id: 'fire', when: () => G.run.solution > 0 && G.run.ingots <= MIN_SELLABLE && !G.run.fire.some(v => v.active),
    text: 'Раствор есть — на вкладке «Печь» выплавь из него золото.' },
  { id: 'sell', when: () => G.run.ingots > MIN_SELLABLE,
    text: 'Золото готово! Продай его скупщику во вкладке «Печь».' },
  { id: 'upg', when: () => currentTab !== 'upg' && UPGRADES.some(u => u.currency === 'cash' && upgVisible(u) && upgUnlocked(u) && !upgMaxed(u) && G.run.cash >= upgCost(u)),
    text: 'Хватает денег на прокачку — загляни во вкладку «Прокачка».' },
  { id: 'prest', when: () => !isMaxPrestige() && G.run.cash >= F.prestigeThreshold(G.meta.prestige),
    text: 'Можно сделать престиж: «Прокачка» → «Престиж». Начнёшь заново, но сильнее.' },
];
let tipShown = null;

function renderTip() {
  const box = el('tipBox');
  const seen = G.meta.tips;
  let tip = null;
  if (!seen.all && currentScreen === 'game' && !isMinigameOpen() && !isPriceGameOpen() && !cut.open) {
    tip = TIPS.find(x => !seen[x.id] && x.when()) || null;
  }
  // Подсказка пропала сама — значит, игрок сделал, что советовали
  if (tipShown && tip !== tipShown && !tipShown.when()) seen[tipShown.id] = true;
  if (tip !== tipShown) {
    tipShown = tip;
    if (tip) setText('tipText', tip.text);
    toggleClass(box, 'show', !!tip);
  }
}

function dismissTip() {
  if (!tipShown) return;
  G.meta.tips[tipShown.id] = true;
  tipShown = null;
  el('tipBox').classList.remove('show');
  sndTab();
}

// ===== Обновление экрана (каждый кадр) =====

function render() {
  renderHeader();
  if (currentTab === 'forge') renderForge();
  else if (currentTab === 'dig') renderDig();
  else if (currentTab === 'acid') renderAcid();
  else if (currentTab === 'fire') renderFire();
  else if (currentTab === 'upg') renderUpgrades();
  renderBadges();
  renderTip();
}

function vesselsProgress(list) {
  let p = 0, d = 0;
  for (const v of list) if (v.active) { p += v.progress; d += v.duration; }
  return d > 0 ? p / d * 100 : 0;
}

function renderHeader() {
  setText('cash', fmt(Math.floor(G.run.cash)));
  setText('ingots', fmt(G.run.ingots, 3));
  const hasPrest = G.meta.prestige > 0;
  toggleClass('gameHeader', 'has-prestige', hasPrest);
  setHidden('hdrRight', !hasPrest);
  setText('prestLvl', G.meta.prestige);
  setText('prestPts', G.meta.points);

  const a = G.meta.equipped ? amuletDef(G.meta.equipped) : null;
  setIcon(el('amuletDot'), 'amulet', { tint: a ? a.color : '#4a4e46' });
  setText('amuletName', a ? a.name : 'Нет амулета');
  el('amuletName').style.color = a ? a.color : '#8a916e';

  setWidth('prog-acid', vesselsProgress(G.run.acid));
  setWidth('prog-fire', vesselsProgress(G.run.fire));
  setIcon(el('forgeTabIcon'), G.meta.forgeUnlocked ? 'anvil' : 'lock');
  setText('forgeTabLabel', G.meta.forgeUnlocked ? 'Кузнец' : '');
}

// --- Копать ---

function renderDig() {
  // Сцена точки сбора
  const view = LOCATIONS[G.ui.locView], vs = G.run.locs[view.key];
  digScene.frame();
  setText('locName', view.name);
  setText('locStock', vs.unlocked ? `${vs.stock} / ${view.stock}` : 'закрыто');
  toggleClass('locStock', 'loc-empty', vs.unlocked && vs.stock === 0);
  setHidden('locAuto', !(vs.unlocked && G.meta.autoDig[view.key]));
  setHidden('locLock', vs.unlocked);
  if (!vs.unlocked) {
    const cost = locUnlockCost(view);
    setText('unlockBtn', `Открыть · ${fmt(cost)} ₽`);
    setDisabled('unlockBtn', G.run.cash < cost);
    const disc = lv('locDiscount');
    setText('locDiscount', disc ? `скидка −${pct(F.locDiscount(disc))}%` : '');
  }
  setDisabled('locPrev', G.ui.locView <= 0);
  setDisabled('locNext', G.ui.locView >= LOCATIONS.length - 1);
  ui.locDots.forEach((dEl, i) => {
    const l = LOCATIONS[i];
    setClass(dEl, 'scene-dot' + (i === G.ui.locView ? ' on' : '') + (G.run.locs[l.key].unlocked ? '' : ' locked'));
  });

  // Кнопка «Порыться»
  const loc = locDef(G.run.activeLoc), ls = G.run.locs[loc.key];
  const full = totalJunk() >= capMax();
  let label, fill = 0, disabled = false, fillColor = 'rgba(0,0,0,0.30)';
  if (!vs.unlocked) {
    disabled = true;
    label = 'Точка закрыта';
  } else if (ls.stock <= 0) {
    disabled = true;
    label = `${loc.name}: пусто, ~${Math.ceil(Math.max(0, locRegenInterval(loc) - ls.regenTimer) / 1000)}с`;
  } else if (full) {
    disabled = true; fill = 100; fillColor = 'rgba(143,179,57,0.45)';
    label = 'Склад забит — переработай лом';
  } else if (G.run.scavCd > 0) {
    fill = 100 - G.run.scavCd / scavCdMax() * 100;
    label = session.digLabel;
  } else {
    label = 'Порыться: ' + loc.name;
  }
  setDisabled('digBtn', disabled);
  setWidth('digFill', fill);
  if (el('digFill').style.background !== fillColor) el('digFill').style.background = fillColor;
  setText('digLabel', label);

  // Склад и инвентарь
  setWidth('capFill', Math.min(100, totalJunk() / capMax() * 100));
  setHidden('capCellAuto', !lv('automation'));
  setText('capAutoVal', `${Math.floor(G.meta.auto.junk)} / ${autoCap()}`);
  setText('capManVal', `${totalJunk()} / ${capMax()}`);
  setText('albumBtn', `Альбом ${ITEM_KEYS.filter(k => G.meta.found[k]).length}/${ITEM_KEYS.length}`);
  for (const k of ITEM_KEYS) {
    setText(ui.invCells[k].n, G.run.junk[k]);
    toggleClass(ui.invCells[k].cell, 'empty', G.run.junk[k] === 0);
  }
}

// --- Кислота и печь ---

/** Построить строки процессов (ванны/печи), если их число изменилось. */
function ensureStages(boxId, kind, count) {
  const box = el(boxId);
  if (box.children.length === count) return;
  box.innerHTML = '';
  for (let i = 0; i < count; i++) {
    const label = count > 1 ? (kind === 'acid' ? 'Ванна #' : 'Печь #') + (i + 1) : 'Процесс';
    const stage = make('div', 'stage');
    const icon = make('div', `stage-icon ic-${kind}`);
    icon.appendChild(pxIcon(kind === 'acid' ? 'flask' : 'fire'));
    icon.id = `${kind}-icon-${i}`;
    const body = make('div', 'stage-body');
    const top = make('div', 'stage-top');
    const status = make('b');
    status.id = `${kind}-status-${i}`;
    top.append(make('span', null, label), status);
    const bar = make('div', 'bar');
    const fill = make('div', `bar-fill ${kind}`);
    fill.id = `${kind}-bar-${i}`;
    bar.appendChild(fill);
    const btn = make('button', 'stage-btn');
    btn.type = 'button';
    btn.id = `${kind}-btn-${i}`;
    btn.dataset.action = kind + '-start';
    btn.dataset.arg = i;
    body.append(top, bar, btn);
    stage.append(icon, body);
    box.appendChild(stage);
  }
}

function renderStage(kind, i, v, status, btnText, ready) {
  setText(`${kind}-status-${i}`, status);
  setWidth(`${kind}-bar-${i}`, v.active ? v.progress / v.duration * 100 : 0);
  setText(`${kind}-btn-${i}`, btnText);
  setDisabled(`${kind}-btn-${i}`, !ready);
  setClass(`${kind}-btn-${i}`, 'stage-btn' + (ready ? ' ready' : ''));
  toggleClass(`${kind}-icon-${i}`, 'active', v.active);
}

function renderAcid() {
  acidScene.frame();
  ensureStages('acidStages', 'acid', G.run.acid.length);
  const gold = junkGold(true);
  const free = freeVessels(G.run.acid);
  G.run.acid.forEach((b, i) => {
    if (b.active) renderStage('acid', i, b, fmt(b.yieldAmt, 2) + ' г Au', 'Растворяется...', false);
    else if (gold <= 0) renderStage('acid', i, b, fmt(G.run.solution, 2) + ' л раствора', 'Нечего растворять', false);
    else renderStage('acid', i, b, fmt(G.run.solution, 2) + ' л раствора', `Растворить ~${fmt(gold / Math.max(free, 1) * cycleEffEffective(), 2)} г Au`, true);
  });

  // Склад под растворение
  let any = false;
  for (const k of ITEM_KEYS) {
    const l = ui.acidLines[k], cnt = G.run.junk[k];
    if (cnt > 0) any = true;
    setClass(l.line, 'inv-line' + (cnt === 0 ? ' dim' : '') + (G.run.locked[k] ? ' locked' : ''));
    setText(l.cnt, cnt + ' шт');
    setText(l.au, fmt(cnt * ITEMS[k].gold, 3) + ' г');
  }
  setHidden('acidInvList', !any);
  setHidden('acidInvEmpty', any);
  setText('acidStockAu', fmt(junkGold(false), 3) + ' г Au');

  // Авто-кислота
  const on = lv('automation') > 0;
  setHidden('autoAcidPanel', !on);
  if (on) {
    const a = G.meta.auto, iv = autoAcidInterval();
    setWidth('autoAcidBar', Math.min(100, a.acidTimer / iv * 100));
    setText('autoAcidStatus', a.junk <= 0 ? 'Ждёт лом' : `Работает · ~${Math.ceil(Math.max(0, iv - a.acidTimer) / 1000)}с`);
    setText('autoAcidSolution', a.solution.toFixed(1));
    setText('autoAcidJunk', `${Math.floor(a.junk)} / ${autoCap()}`);
  }
}

function renderFire() {
  fireScene.frame();
  marketScene.frame();
  ensureStages('fireStages', 'fire', G.run.fire.length);
  const free = freeVessels(G.run.fire);
  G.run.fire.forEach((f, i) => {
    if (f.active) renderStage('fire', i, f, fmt(f.yieldAmt, 3) + ' г слитков', 'Плавится...', false);
    else if (G.run.solution <= 0) renderStage('fire', i, f, fmt(G.run.solution, 2) + ' л раствора', 'Нет раствора', false);
    else renderStage('fire', i, f, fmt(G.run.solution, 2) + ' л раствора', `Выпарить ~${fmt(G.run.solution / Math.max(free, 1), 3)} г`, true);
  });

  // Скупщик
  setText('ingotBig', fmt(G.run.ingots, 3));
  const mult = priceMultiplier();
  setText('priceTxt', `${fmt(Math.round(BAL.priceMin * mult))} – ${fmt(Math.round(BAL.priceMax * mult))} ₽`);
  const canSell = G.run.ingots > MIN_SELLABLE;
  setDisabled('sellBtn', !canSell);
  setText('sellBtn', canSell ? `Продать ${fmt(G.run.ingots, 3)} г` : 'Нет слитков на продажу');

  // Авто-печь
  const on = lv('automation') > 0;
  setHidden('autoFirePanel', !on);
  if (on) {
    const a = G.meta.auto, iv = autoFireInterval();
    setWidth('autoFireBar', Math.min(100, a.fireTimer / iv * 100));
    setText('autoFireStatus', a.solution <= 0 ? 'Ждёт раствор' : `Работает · ~${Math.ceil(Math.max(0, iv - a.fireTimer) / 1000)}с`);
    setText('autoFireIngots', a.ingots.toFixed(1));
    setText('autoFireSolution', a.solution.toFixed(1));
  }
}

// --- Прокачка ---

function renderUpgrades() {
  for (const group of UPG_GROUPS) setHidden(ui.groupWraps[group.key], group.visible && !group.visible());

  for (const u of UPGRADES) {
    const r = ui.upgRows[u.key];
    const visible = upgVisible(u);
    setHidden(r.row, !visible);
    if (!visible) continue;
    setText(r.desc, upgDescription(u));
    const l = lv(u.key);
    if (r.segs && r.lastLv !== l) {
      r.lastLv = l;
      r.segs.forEach((s, i) => { s.className = i < l ? 'on' : ''; });
      setText(r.lvl, `${l}/${u.max}`);
    }
    toggleClass(r.row, 'maxed', upgMaxed(u));

    const base = 'upg-btn' + (u.currency === 'points' ? ' prest' : '') + (u.style ? ' ' + u.style : '');
    if (upgMaxed(u)) {
      setText(r.btn, u.max === 1 ? (u.doneLabel || '✓ куплено') : '✓ макс');
      setClass(r.btn, base + ' owned');
      setDisabled(r.btn, true);
    } else if (!upgUnlocked(u)) {
      setText(r.btn, '—');
      setClass(r.btn, base);
      setDisabled(r.btn, true);
    } else {
      const cost = upgCost(u);
      setText(r.btn, u.currency === 'cash' ? fmt(cost) + ' ₽' : cost + ' очк.');
      setClass(r.btn, base);
      setDisabled(r.btn, wallet(u) < cost);
    }
  }

  // Блок престижа
  const maxed = isMaxPrestige();
  const thr = F.prestigeThreshold(G.meta.prestige);
  setText('psLvl', G.meta.prestige);
  setText('psPts', G.meta.points);
  setText('psBonus', '+' + parseFloat(prestigeBonusPct().toFixed(2)) + '%');
  setText('psThreshold', maxed ? '—' : fmt(thr) + ' ₽');
  setText('psReward', maxed ? '—' : F.prestigeReward(G.meta.prestige + 1));
  setText('prestThresholdInfo', maxed ? 'Максимум достигнут · сбросить нельзя'
    : `Порог: ${fmt(thr)} ₽ · сбросит всё кроме прокачек Престижа и амулетов`);
  setDisabled('prestBtn', maxed || G.run.cash < thr);
  setText('prestBtn', maxed ? `★ ФИНАЛ — престиж ${BAL.prestigeMaxLevel}`
    : G.run.cash < thr ? `Нужно ${fmt(thr)} ₽ (сейчас ${fmt(Math.floor(G.run.cash))})`
    : `Сделать престиж → получить ${F.prestigeReward(G.meta.prestige + 1)} очков`);
}

// --- Кузница ---

function renderForge() {
  const open = G.meta.forgeUnlocked;
  toggleClass('forgeFrame', 'forge-locked', !open);
  toggleClass('forgeFrame', 'forge-unlocked', open);
  const src = open ? 'kuznec.png' : 'kuznec-locked.png';
  if (el('forgeImg').getAttribute('src') !== src) el('forgeImg').setAttribute('src', src);
  setHidden('forgePanelTitle', !open);
  setHidden('forgeLockedNote', open);
  setHidden('amuletList', !open);
  renderCrafts();
  if (!open) return;

  const busy = forgeSlotsBusy();
  for (const a of AMULETS) {
    const r = ui.amuletRows[a.key];
    const owned = !!G.meta.amulets[a.key];
    setHidden(r.trash, !owned);
    setHidden(r.time, !owned);
    setHidden(r.recipe, owned);
    setHidden(r.equipBtn, !owned);
    setHidden(r.swipeHint, !owned);
    setHidden(r.craftBtn, owned);
    setHidden(r.craftTime, owned);
    if (!owned && revealedAmulet === a.key) setRevealedAmulet(null);

    if (owned) {
      const equipped = G.meta.equipped === a.key;
      setText(r.time, amuletTimeLeftText(a.key));
      setText(r.equipBtn, equipped ? 'Снять' : 'Надеть');
      setClass(r.equipBtn, 'am-btn ' + (equipped ? 'unequip' : 'equip'));
      r.equipBtn.dataset.action = equipped ? 'amulet-unequip' : 'amulet-equip';
    } else {
      const rec = recipeFor(a.key);
      for (const k in rec) {
        const have = G.run.junk[k];
        setText(r.chips[k].txt, `${ITEMS[k].name} ${have}/${rec[k]}`);
        setClass(r.chips[k].chip, 'rec-chip' + (have >= rec[k] ? '' : ' miss'));
      }
      const can = canCraft(a.key);
      setText(r.craftBtn, busy ? 'Занят' : can ? 'Создать' : 'Мало');
      setDisabled(r.craftBtn, busy || !can);
      setText(r.craftTime, `~${Math.ceil(craftTimeMs(a.key) / 60000)} мин`);
    }
  }
}

function renderCrafts() {
  const box = el('craftStatusBox');
  const crafts = G.meta.forgeUnlocked ? G.meta.crafts : [];
  if (box.children.length !== crafts.length || box.dataset.ids !== crafts.map(c => c.id).join()) {
    box.innerHTML = '';
    box.dataset.ids = crafts.map(c => c.id).join();
    crafts.forEach((c, i) => {
      const label = lv('twoForges') ? `Горн #${i + 1}` : 'Куётся';
      const st = make('div', 'craft-status');
      const line = make('div', 'cs-line');
      const name = make('span', null, label + ': ');
      name.appendChild(make('b', null, amuletDef(c.id).name));
      const left = make('span');
      left.id = 'craft-left-' + i;
      line.append(name, left);
      const bar = make('div', 'cs-bar');
      const fill = make('div', 'cs-bar-fill');
      fill.id = 'craft-fill-' + i;
      bar.appendChild(fill);
      st.append(line, bar);
      box.appendChild(st);
    });
  }
  const now = Date.now();
  crafts.forEach((c, i) => {
    const elapsed = now - c.startedAt;
    setText('craft-left-' + i, `~${Math.ceil(Math.max(0, c.duration - elapsed) / 60000)} мин`);
    setWidth('craft-fill-' + i, Math.min(100, elapsed / c.duration * 100));
  });
}

// ===== Бейджи на таббаре =====
// Число возможных действий во вкладке. Бейдж гаснет при заходе во вкладку
// и загорается снова, только когда действий стало больше, чем было при заходе.

const BADGES = {
  fire: () => (G.run.solution > 0 ? freeVessels(G.run.fire) : 0),
  acid: () => (junkGold(true) > 0 ? freeVessels(G.run.acid) : 0),
  upg: () => UPGRADES.filter(upgAffordable).length,
  forge: () => {
    if (!G.meta.forgeUnlocked || forgeSlotsBusy()) return 0;
    return AMULETS.filter(a => !G.meta.amulets[a.key] && !isCrafting(a.key) && canCraft(a.key)).length;
  },
};

function renderBadges() {
  for (const tab in BADGES) {
    const count = BADGES[tab]();
    const seen = G.ui.badgeSeen[tab];
    const badge = el('badge-' + tab);
    const show = count > 0 && count > seen;
    if (show) setText(badge, count > 9 ? '9+' : count);
    toggleClass(badge, 'show', show);
    if (count < seen) G.ui.badgeSeen[tab] = count;
  }
}
