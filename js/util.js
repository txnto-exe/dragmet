'use strict';
// Мелкие помощники, которыми пользуются все остальные файлы.

/** Элемент по id (с запоминанием, чтобы не искать каждый кадр). */
const _elCache = {};
function el(id) {
  let e = _elCache[id];
  if (!e || !e.isConnected) {
    e = document.getElementById(id);
    if (e) _elCache[id] = e;
  }
  return e;
}

/** Создать элемент: make('div', 'class-name', 'текст'). */
function make(tag, className, text) {
  const e = document.createElement(tag);
  if (className) e.className = className;
  if (text != null) e.textContent = text;
  return e;
}

/** Записать текст, только если он изменился (экономит перерисовку). */
function setText(target, value) {
  const e = typeof target === 'string' ? el(target) : target;
  if (!e) return;
  const v = String(value);
  if (e.textContent !== v) e.textContent = v;
}

function setClass(target, className) {
  const e = typeof target === 'string' ? el(target) : target;
  if (e && e.className !== className) e.className = className;
}

function toggleClass(target, className, on) {
  const e = typeof target === 'string' ? el(target) : target;
  if (e && e.classList.contains(className) !== !!on) e.classList.toggle(className, !!on);
}

function setHidden(target, hidden) {
  toggleClass(target, 'hidden', hidden);
}

function setWidth(target, pct) {
  const e = typeof target === 'string' ? el(target) : target;
  if (!e) return;
  const v = pct + '%';
  if (e.style.width !== v) e.style.width = v;
}

function setDisabled(target, disabled) {
  const e = typeof target === 'string' ? el(target) : target;
  if (e && e.disabled !== !!disabled) e.disabled = !!disabled;
}

/** Число по-русски: 12 345 или 1,234. */
function fmt(n, digits = 0) {
  try {
    return n.toLocaleString('ru-RU', { minimumFractionDigits: digits, maximumFractionDigits: digits });
  } catch (e) {
    return n.toFixed(digits);
  }
}

function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v));
}

function pickRandom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

/** Перезапустить CSS-анимацию на элементе (снять класс и тут же поставить снова). */
function replayAnim(target, className, ms) {
  const e = typeof target === 'string' ? el(target) : target;
  if (!e) return;
  e.classList.remove(className);
  void e.offsetWidth;
  e.classList.add(className);
  setTimeout(() => e.classList.remove(className), ms);
}

/** Время «2 ч 15 мин» / «15 мин». */
function fmtHoursMinutes(ms) {
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  return h > 0 ? `${h} ч ${m} мин` : `${m} мин`;
}

function pad2(n) {
  return ('0' + n).slice(-2);
}
