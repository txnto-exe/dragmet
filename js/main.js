'use strict';
// Запуск игры и главный цикл.

const AUTOSAVE_MS = 2000;
const MAX_FRAME_MS = 500;   // длинные паузы догоняет catchUp(), а не обычный кадр

function enterGame() {
  showScreen('game');
  updateBloom();
  switchTab('dig', true);
}

/** Кнопка «Продолжить»: загрузить сейв и догнать время, пока игра была закрыта. */
function continueGame() {
  if (!loadGame()) return startNewGame();
  const offline = catchUp();
  enterGame();
  if (offline) showOfflineOverlay(offline);
  saveGame();
}

/** Сбросить всё (настройки звука и вибрации остаются). */
function resetGame() {
  const settings = G ? G.settings : null;
  deleteAllSaves();
  G = makeGame();
  if (settings) G.settings = settings;
  session.digLabel = TEXT.digLabels[0];
  session.graceUntil = { acid: 0, fire: 0 };
  stopAllLoops();
  cancelAllPress();
  closeAnyMinigame();
  closePriceGame();
  updateBloom();
}

function startNewGame() {
  resetGame();
  enterGame();
  saveGame();
}

let lastFrame = performance.now();
let sinceSave = 0;

function loop(now) {
  const dt = Math.min(now - lastFrame, MAX_FRAME_MS);
  lastFrame = now;
  try {
    if (currentScreen === 'game') {
      tick(dt);
      render();
      sinceSave += dt;
      if (sinceSave > AUTOSAVE_MS) {
        sinceSave = 0;
        saveGame();
      }
    } else if (currentScreen === 'menu') {
      renderMenuScene();
    }
  } catch (err) {
    showError(err);
  }
  requestAnimationFrame(loop);
}

function saveOnLeave() {
  cancelAllPress();
  if (currentScreen === 'game') saveGame();
}

/** Игру свернули или вернули на экран. */
function onVisibilityChange() {
  if (document.visibilityState === 'hidden') {
    saveOnLeave();
    stopAllLoops();
    return;
  }
  // Вернулись: догоняем время, пока игра была свёрнута
  if (currentScreen !== 'game') return;
  try {
    const offline = catchUp();
    if (offline) showOfflineOverlay(offline);
    saveGame();
  } catch (err) {
    showError(err);
  }
  lastFrame = performance.now();
}

function boot() {
  G = makeGame();   // пустое состояние, пока игрок не нажал «Продолжить» или «Новая игра»
  const found = findBestSave();   // заодно узнаём, в какой слот писать дальше

  lastSaveTs = found ? found.ts : 0;

  buildUi();
  initInput();
  window.addEventListener('pagehide', saveOnLeave);
  window.addEventListener('blur', saveOnLeave);
  document.addEventListener('visibilitychange', onVisibilityChange);
  // Показываем только ошибки нашей игры. Чужие скрипты (например, Telegram,
  // если ссылку открыли внутри него) дают «Script error.» без подробностей — их пропускаем.
  window.addEventListener('error', e => {
    if (!e.filename || !e.filename.startsWith(location.origin)) return;
    showError(e.error || e.message);
  });

  showScreen('menu');
  requestAnimationFrame(loop);
  window.__dmBooted = true;   // для аварийной диагностики в index.html: запуск прошёл
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
else boot();
