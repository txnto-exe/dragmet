'use strict';
// DEV-КОНСОЛЬ — только для тестов. Открывается зажатием шестерёнки на 3 секунды.
// ПЕРЕД РЕЛИЗОМ: удалить этот файл и строку <script src="js/dev.js"> в index.html. Больше ничего трогать не нужно.

(function () {
  const css = `
.dev-overlay{position:fixed;inset:0;background:rgba(0,0,0,0.94);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);display:none;align-items:center;justify-content:center;z-index:99999;padding:16px;}
.dev-overlay.show{display:flex;}
.dev-card{background:linear-gradient(180deg,rgba(30,38,24,0.95),rgba(14,18,10,0.98));border:1px solid rgba(240,201,74,0.35);border-radius:24px;padding:18px;max-width:440px;width:100%;max-height:92vh;overflow-y:auto;box-shadow:0 20px 60px rgba(240,201,74,0.20);}
.dev-title{font-size:14px;font-weight:800;color:#f0c94a;text-align:center;margin-bottom:12px;font-family:ui-monospace,monospace;letter-spacing:1.5px;}
.dev-section{font-size:10px;color:#8a916e;text-transform:uppercase;letter-spacing:0.7px;margin:14px 0 8px;font-weight:700;}
.dev-buttons{display:flex;gap:6px;flex-wrap:wrap;}
.dev-btn{flex:1;min-width:60px;padding:10px 6px;font-size:12px;font-weight:700;background:linear-gradient(180deg,rgba(50,60,40,0.55),rgba(28,36,22,0.75));border:none;color:#c9a227;border-radius:var(--r-sm);cursor:pointer;font-family:ui-monospace,monospace;touch-action:manipulation;}
.dev-item-row{display:flex;align-items:center;gap:6px;padding:5px 0;border-bottom:1px solid rgba(60,70,45,0.5);}
.dev-item-row:last-child{border-bottom:none;}
.dev-item-row .ic{font-size:15px;width:20px;text-align:center;}
.dev-item-row .nm{flex:1;font-size:10.5px;color:#dfe4c8;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.dev-item-row .dev-btn{padding:6px 8px;font-size:10.5px;min-width:36px;flex:0 0 auto;}
.dev-close{width:100%;padding:14px;margin-top:16px;background:linear-gradient(180deg,#e05a5a,#c73a3a);color:#fff;border:none;border-radius:var(--r-md);font-size:14px;font-weight:700;cursor:pointer;font-family:inherit;touch-action:manipulation;}`;

  const btn = (arg, label) => `<button class="dev-btn" data-action="dev-add" data-arg="${arg}" type="button">${label}</button>`;
  const row = (title, type, amounts, unit = '') =>
    `<div class="dev-section">${title}</div><div class="dev-buttons">${amounts.map(a => btn(`${type}:${a}`, '+' + fmtShort(a) + unit)).join('')}</div>`;
  function fmtShort(n) {
    return n >= 1000000 ? n / 1000000 + 'M' : n >= 10000 ? n / 1000 + 'k' : String(n);
  }

  const items = ITEM_KEYS.map(k => `<div class="dev-item-row"><span class="ic">${ITEMS[k].icon}</span><span class="nm">${ITEMS[k].name}</span>`
    + [10, 100, 1000].map(n => btn(`item:${k}:${n}`, '+' + n)).join('') + '</div>').join('');

  const style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);

  const overlay = document.createElement('div');
  overlay.className = 'dev-overlay';
  overlay.innerHTML = `<div class="dev-card">
    <div class="dev-title">🛠 DEV CONSOLE</div>
    ${row('Деньги', 'cash', [10000, 100000, 1000000, 10000000])}
    ${row('Слитки', 'ingots', [1, 10, 100, 1000], ' г')}
    ${row('Очки престижа', 'points', [10, 100, 1000, 10000])}
    <div class="dev-section">Предметы</div>${items}
    <button class="dev-close" data-action="dev-close" type="button">Закрыть</button>
  </div>`;
  document.body.appendChild(overlay);

  ACTIONS['open-dev'] = () => overlay.classList.add('show');
  ACTIONS['dev-close'] = () => overlay.classList.remove('show');
  ACTIONS['dev-add'] = arg => {
    const [type, a, b] = arg.split(':');
    if (type === 'cash') { G.run.cash += Number(a); bumpCash(); }
    else if (type === 'ingots') G.run.ingots += Number(a);
    else if (type === 'points') G.meta.points += Number(a);
    else if (type === 'item' && ITEMS[a]) G.run.junk[a] += Number(b);
    saveGame();
  };
})();
