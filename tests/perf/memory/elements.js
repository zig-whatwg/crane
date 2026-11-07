// The cases of the memory-per-element pages (memory/elements-*.html; docs/performance.md,
// "Memory per element"): each page runs one case, through perf.retain (harness.js), in a fresh
// launch of its engine. setup(n) makes what a case needs besides its objects - a slot per object,
// a host to attach them to, the markup to parse - and the harness holds it to the end, so it is
// the same at both readings; create(n) makes the n objects and keeps them. Every case makes the
// same slots, so every page's first reading has the same things in it.
(function () {
  'use strict';
  // A slot per object, made up front: storing into it allocates nothing.
  function slots(n) {
    return new Array(n).fill(null);
  }
  globalThis.elementCases = {
    // The control: the same steps and the same slots, and nothing made - one object stored n
    // times. Its difference between the readings is the footprint's own drift over the same
    // steps, which every case's figure has subtracted.
    control: {
      setup(n) { this.keep = slots(n); this.one = {}; },
      create(n) { const k = this.keep, one = this.one; for (let i = 0; i < n; i++) k[i] = one; },
    },
    // Divs made with createElement and kept in a JS array, outside the document.
    detachedDiv: {
      setup(n) { this.keep = slots(n); },
      create(n) { const k = this.keep; for (let i = 0; i < n; i++) k[i] = document.createElement('div'); },
    },
    // Divs made with createElement and appended to the document: the document keeps them.
    attachedDiv: {
      setup(n) { this.keep = slots(n); this.host = document.body.appendChild(document.createElement('div')); },
      create(n) { const h = this.host; for (let i = 0; i < n; i++) h.appendChild(document.createElement('div')); },
    },
    // Detached divs with two attributes each, the same two values on every div (so the figure
    // is the attributes' storage, not a string per element).
    divTwoAttributes: {
      setup(n) { this.keep = slots(n); },
      create(n) {
        const k = this.keep;
        for (let i = 0; i < n; i++) {
          const e = document.createElement('div');
          e.setAttribute('class', 'item');
          e.setAttribute('data-k', 'v');
          k[i] = e;
        }
      },
    },
    // Text nodes made with createTextNode and kept in a JS array.
    textNode: {
      setup(n) { this.keep = slots(n); },
      create(n) { const k = this.keep; for (let i = 0; i < n; i++) k[i] = document.createTextNode('x'); },
    },
    // Spans made by the HTML fragment parser (innerHTML) in an element of the document, which
    // keeps them. The markup is made in setup by join, so it is one flat string at both readings
    // (a string built by concatenation can be flattened - copied - when the parser first reads it).
    parserSpan: {
      setup(n) {
        this.keep = slots(n);
        this.host = document.body.appendChild(document.createElement('div'));
        this.markup = new Array(n).fill('<span></span>').join('');
      },
      create() { this.host.innerHTML = this.markup; },
    },
  };
})();
