'use strict';
// Запуск игры и главный цикл.

const AUTOSAVE_MS = 2000;
const MAX_FRAME_MS = 500;   // если вкладка долго спала — не перематываем время целиком

function enterGame() {
  showScreen('game');
  updateBloom();
  switchTab('dig', true);
}

/** Кнопка «Продолжить»: загрузить сейв, начислить оффлайн-доход. */
function continueGame() {
  if (!loadGame()) return startNewGame();
  const offline = applyOfflineIncome();
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

function boot() {
  G = makeGame();   // пустое состояние, пока игрок не нажал «Продолжить» или «Новая игра»
  const found = findBestSave();   // заодно узнаём, в какой слот писать дальше

  lastSaveTs = found ? found.ts : 0;

  buildUi();
  initInput();
  window.addEventListener('pagehide', saveOnLeave);
  window.addEventListener('blur', saveOnLeave);
  document.addEventListener('visibilitychange', saveOnLeave);
  // Показываем только ошибки нашей игры. Чужие скрипты (например, Telegram,
  // если ссылку открыли внутри него) дают «Script error.» без подробностей — их пропускаем.
  window.addEventListener('error', e => {
    if (!e.filename || !e.filename.startsWith(location.origin)) return;
    showError(e.error || e.message);
  });

  showScreen('menu');
  requestAnimationFrame(loop);
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
else boot();
