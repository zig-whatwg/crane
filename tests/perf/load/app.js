// The dashboard's script, shaped like a single-page app: it fetches its data, renders a
// 500-row table, sorts it, applies a filter, and keeps a summary - the page is ready when the
// data is on it (appReady).
(function () {
  'use strict';
  const tbody = document.querySelector('#grid tbody');
  const summary = document.getElementById('summary');
  let rows = [];
  function render(list) {
    const frag = document.createDocumentFragment();
    for (const r of list) {
      const tr = document.createElement('tr');
      if (!r.active) tr.className = 'inactive';
      tr.dataset.id = String(r.id);
      for (const v of [r.id, r.name, r.price.toFixed(2), r.tags.join(', '), r.active ? 'Active' : 'Closed']) {
        const td = document.createElement('td');
        td.textContent = String(v);
        tr.appendChild(td);
      }
      frag.appendChild(tr);
    }
    tbody.replaceChildren(frag);
    const total = list.reduce((s, r) => s + r.price, 0);
    summary.textContent = list.length + ' orders, ' + total.toFixed(2) + ' total';
  }
  function view() {
    const q = document.getElementById('filter').value.toLowerCase();
    const key = document.getElementById('sort').value;
    const list = rows.filter((r) => !q || r.name.includes(q)).sort((a, b) => (a[key] < b[key] ? -1 : a[key] > b[key] ? 1 : 0));
    render(list);
  }
  document.getElementById('filter').addEventListener('input', view);
  document.getElementById('sort').addEventListener('change', view);
  globalThis.appReady = fetch('/__perf/json?n=500').then((r) => r.json()).then((data) => {
    rows = data;
    view();
    document.getElementById('sort').value = 'price';
    view();
    return performance.now();
  });
})();
