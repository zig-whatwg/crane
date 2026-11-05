// The documentation page's script: a table of contents from the headings, anchor links, and
// syntax highlighting of every code block (tokenized by regular expressions and rebuilt as
// spans, as client-side highlighters do).
(function () {
  'use strict';
  const toc = document.getElementById('toc');
  const ol = document.createElement('ol');
  for (const h of document.querySelectorAll('.content h2')) {
    const li = document.createElement('li');
    const a = document.createElement('a');
    a.href = '#' + h.id;
    a.textContent = h.textContent;
    li.appendChild(a);
    ol.appendChild(li);
    const anchor = document.createElement('a');
    anchor.className = 'anchor';
    anchor.href = '#' + h.id;
    anchor.textContent = '#';
    h.appendChild(anchor);
  }
  toc.appendChild(ol);
  const keywords = /^(const|let|var|await|async|function|return|if|else|for|new)$/;
  const token = /(\s+)|('[^']*')|(\d+)|([A-Za-z_$][\w$]*)|([^\s\w])/g;
  for (const code of document.querySelectorAll('pre code')) {
    const text = code.textContent;
    const out = document.createDocumentFragment();
    let m;
    token.lastIndex = 0;
    while ((m = token.exec(text))) {
      if (m[1]) { out.appendChild(document.createTextNode(m[1])); continue; }
      const span = document.createElement('span');
      span.className = m[2] ? 'tok-str' : m[3] ? 'tok-num' : (m[4] && keywords.test(m[4])) ? 'tok-kw' : 'tok';
      span.textContent = m[0];
      out.appendChild(span);
    }
    code.textContent = '';
    code.appendChild(out);
  }
  for (const table of document.querySelectorAll('table.api')) table.setAttribute('role', 'grid');
  globalThis.docsReady = Promise.resolve(performance.now());
})();
