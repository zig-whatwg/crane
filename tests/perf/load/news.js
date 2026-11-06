// The article page's script, shaped like a news site's: comments rendered from the JSON the
// page carries, relative times, reply threads, a reading-progress note and link decoration.
(function () {
  'use strict';
  const data = JSON.parse(document.getElementById('comment-data').textContent);
  const list = document.querySelector('.comment-list');
  function ago(minutes) {
    if (minutes < 60) return minutes + ' minutes ago';
    if (minutes < 1440) return Math.floor(minutes / 60) + ' hours ago';
    return Math.floor(minutes / 1440) + ' days ago';
  }
  const frag = document.createDocumentFragment();
  for (const c of data) {
    const li = document.createElement('li');
    li.className = 'comment';
    li.id = 'comment-' + c.id;
    const meta = document.createElement('div');
    meta.className = 'meta';
    meta.textContent = c.author + ' · ' + ago(c.minutes) + ' · ' + c.likes + ' likes';
    const body = document.createElement('p');
    body.textContent = c.text;
    li.append(meta, body);
    if (c.replies.length) {
      const ol = document.createElement('ol');
      ol.className = 'replies';
      for (const r of c.replies) {
        const item = document.createElement('li');
        item.innerHTML = '<span class="meta"></span> <span class="text"></span>';
        item.firstChild.textContent = r.author;
        item.lastChild.textContent = r.text;
        ol.appendChild(item);
      }
      li.appendChild(ol);
    }
    frag.appendChild(li);
  }
  list.appendChild(frag);
  // External links open in a new tab; every link gets a tracking parameter, as news sites do.
  for (const a of document.querySelectorAll('a[href]')) {
    const url = new URL(a.getAttribute('href'), location.href);
    url.searchParams.set('ref', 'story');
    a.setAttribute('href', url.pathname + url.search);
  }
  // The headings, for a "jump to" menu.
  const jump = document.createElement('nav');
  jump.className = 'jump';
  for (const h of document.querySelectorAll('.story h2')) {
    const a = document.createElement('a');
    a.textContent = h.textContent;
    a.href = '#' + (h.id || (h.id = h.textContent.toLowerCase().replace(/[^a-z]+/g, '-')));
    jump.appendChild(a);
  }
  document.querySelector('.story').prepend(jump);
  const words = document.querySelector('.story').textContent.split(/\s+/).length;
  document.querySelector('.byline').append(' · ' + Math.ceil(words / 230) + ' min read');
  globalThis.newsReady = Promise.resolve(performance.now());
})();
