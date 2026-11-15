'use strict';
// Управление касаниями.
//
// Кнопки в разметке помечены атрибутами:
//   data-action="имя" (+ data-arg) — срабатывает при ОТПУСКАНИИ пальца, если он не сдвинулся
//                                    (чтобы прокрутка страницы не нажимала кнопки);
//   data-press="имя"               — срабатывает сразу при касании (копать, продать);
//                                    с «Турбо-пальцем» при удержании повторяется;
//   data-long="имя"                — срабатывает, если держать палец 3 секунды.
// Что делает каждое имя — в таблицах ACTIONS и PRESS ниже.

const MOVE_THRESHOLD = 12;   // px: сдвинул палец дальше — это прокрутка, а не нажатие
const TAP_DELAY = 30;        // мс до срабатывания data-press
const HOLD_DELAY = 350;      // мс удержания до начала автоповтора
const HOLD_INTERVAL = 220;   // мс между повторами
const LONG_PRESS_MS = 3000;

/** Действия по data-action. arg — значение data-arg, node — нажатый элемент. */
const ACTIONS = {
  // Меню и настройки
  'continue': () => continueGame(),
  'new-game': () => {
    if (hasSave() && !confirm('Стереть сохранение и начать заново?')) return;
    startNewGame();
  },
  'open-settings': () => openSettings(),
  'close-settings': () => closeSettings(),
  'open-album': () => openAlbum(),
  'close-album': () => el('albumModal').classList.remove('show'),
  'close-cut': () => { if (cut.canClose) closePrestigeCut(); },
  'tip-ok': () => dismissTip(),
  'to-menu': () => { saveGame(); closeSettings(); showScreen('menu'); },
  'reset-all': () => {
    if (!confirm('Сбросить весь прогресс?')) return;
    resetGame();
    closeSettings();
    showScreen('menu');
  },
  'toggle-setting': (key, node) => {
    G.settings[key] = !G.settings[key];
    toggleClass(node, 'on', G.settings[key]);
    if (key === 'sound' && G.settings.sound) initAudio();
    updateMusic();
    sndToggle(); vibe(15);
    saveGame();
  },
  'export-save': () => {
    const text = exportSave();
    const done = () => { closeSettings(); flashToast('Сейв скопирован — вставь его в заметки'); };
    const manual = () => { window.prompt('Скопируй этот текст и сохрани в заметки:', text); closeSettings(); };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, manual);
    else manual();
  },
  'import-save': () => {
    const text = window.prompt('Вставь сюда текст резервной копии:');
    if (!text) return;
    const game = parseBackup(text);
    if (!game) { sndDeny(); window.alert('Это не похоже на сейв ДРАГМЕТ. Проверь, что скопирован весь текст.'); return; }
    if (!window.confirm('Заменить текущий прогресс сейвом из копии?')) return;
    G = game;
    saveGame();
    closeSettings();
    enterGame();
    flashToast('Сейв восстановлен');
  },
  'claim-offline': () => { hideOfflineOverlay(); sndOfflineClaim(); vibe(40); bumpCash(); },

  // Навигация
  'tab': name => switchTab(name),
  'subtab': name => switchSub(name),
  'acc': key => toggleAccordion(key),
  'loc-step': delta => stepLoc(Number(delta)),

  // Игра
  'loc-unlock': () => unlockLoc(LOCATIONS[G.ui.locView].key),
  'item-info': k => flashToast(`${ITEMS[k].name} · ${fmt(ITEMS[k].gold * 1000)} мг золота`, ITEMS[k].tier, k),
  'lock': item => toggleLock(item),
  'acid-start': idx => startAcid(Number(idx)),
  'fire-start': idx => startFurnace(Number(idx)),
  'price-stop': () => priceGameStop(),
  'buy': (key, node) => { if (buyUpgrade(UPG_BY_KEY[key])) flashBought(node); },
  'prestige': () => doPrestige(),
  'amulet-craft': key => craftAmulet(key),
  'amulet-equip': key => equipAmulet(key),
  'amulet-unequip': () => unequipAmulet(),
  'amulet-dissolve': key => dissolveAmulet(key),
};

/** Действия по data-press (срабатывают сразу, с турбо-пальцем повторяются). */
const PRESS = {
  // Копать можно, только если на экране открытая точка
  dig: () => { if (G.run.locs[LOCATIONS[G.ui.locView].key].unlocked) dig(); },
  sell: () => sellIngots(),
};

const press = { active: false, target: null, x: 0, y: 0, moved: false, isPress: false, fired: false, pressFn: null, consumed: false, timers: [] };

function clearPressTimers() {
  press.timers.forEach(t => { clearTimeout(t); clearInterval(t); });
  press.timers = [];
}

function cancelAllPress() {
  clearPressTimers();
  press.active = false;
  press.target = null;
}

function overlayOpen() {
  return isPriceGameOpen() || isMinigameOpen();
}

function onPointerDown(e) {
  initAudio();
  if (isMinigameOpen()) return;   // у мини-игр свои кнопки
  clearPressTimers();
  Object.assign(press, { active: true, target: e.target, x: e.clientX, y: e.clientY, moved: false, isPress: false, consumed: false });

  const pressEl = e.target.closest('[data-press]');
  if (pressEl && !pressEl.disabled && !overlayOpen()) {
    const action = PRESS[pressEl.dataset.press];
    const fn = () => safely(action);
    press.isPress = true;
    press.pressFn = fn;
    press.fired = false;
    press.timers.push(setTimeout(() => {
      if (!press.active || press.moved) return;
      press.fired = true;
      fn();
      // Турбо-палец: держишь — действие повторяется
      if (lv('hold') && !overlayOpen()) {
        press.timers.push(setTimeout(() => {
          press.timers.push(setInterval(() => {
            if (!press.active || press.moved) return cancelAllPress();
            fn();
          }, HOLD_INTERVAL));
        }, HOLD_DELAY));
      }
    }, TAP_DELAY));
    return;
  }

  const longEl = e.target.closest('[data-long]');
  if (longEl && ACTIONS[longEl.dataset.long]) {
    press.timers.push(setTimeout(() => {
      if (!press.active || press.moved) return;
      press.consumed = true;
      safely(ACTIONS[longEl.dataset.long]);
    }, LONG_PRESS_MS));
  }
}

function onPointerMove(e) {
  if (!press.active || press.moved) return;
  const dx = e.clientX - press.x, dy = e.clientY - press.y;
  if (dx * dx + dy * dy > MOVE_THRESHOLD * MOVE_THRESHOLD) {
    press.moved = true;
    clearPressTimers();
  }
}

function onPointerUp() {
  if (!press.active) return;
  const { target, moved, isPress, consumed, fired, pressFn } = press;
  cancelAllPress();
  // Очень быстрый тап (отпустил раньше, чем сработал таймер) — всё равно нажимаем
  if (isPress) {
    if (!moved && !fired) pressFn();
    return;
  }
  if (moved || consumed || !target) return;
  const node = target.closest('[data-action]');
  if (!node || node.disabled) return;
  const fn = ACTIONS[node.dataset.action];
  if (fn) safely(() => fn(node.dataset.arg, node));
}

/** Выполнить действие; если внутри ошибка — показать её, а не молчать. */
function safely(fn) {
  try { fn(); } catch (err) { showError(err); }
}

function initInput() {
  document.addEventListener('pointerdown', onPointerDown, true);
  document.addEventListener('pointermove', onPointerMove, true);
  document.addEventListener('pointerup', onPointerUp, true);
  document.addEventListener('pointercancel', cancelAllPress, true);
}
