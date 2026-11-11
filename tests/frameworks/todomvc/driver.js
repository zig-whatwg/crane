// Crane's in-page driver for its port of TodoMVC's app spec: the Cypress
// commands cypress/e2e/spec.cy.js and cypress/support/commands.js use
// (tastejs/todomvc ff43b02e59df, Cypress 15.14.2 per its package-lock.json),
// acting on the app under test in this page's #aut frame through the DOM, as
// a user's input reaches it: pointer, mouse and keyboard events created in
// the app's own window, values set through the element's own setter, focus
// moved by focus() and blur(), navigation by the app's links and its
// window's history. Cypress itself runs the app in an iframe of its runner
// page, as this page does.
//
// What Cypress does that this driver does not (geometry: Crane draws
// nothing, the user's ruling of 2026-11-11), each said where it applies:
// scrolling into view, the covered-element check (elementFromPoint), event
// coordinates, and the layout clauses of its visibility rules. The style
// clauses of those rules are run (hiddenByStyle below); `?prove=layout`
// also evaluates the layout clauses and records every answer they would
// change (the Chrome run of the port, never a measurement).
//
// No upstream file is loaded into the app or edited; nothing is injected
// into the app's window.
'use strict';

(function (global) {
  // Cypress's defaults (packages/config: defaultCommandTimeout 4000,
  // pageLoadTimeout 60000; cy.type's keystroke delay 10 ms).
  const COMMAND_TIMEOUT = 4000;
  const PAGE_LOAD_TIMEOUT = 60000;
  const KEYSTROKE_DELAY = 10;
  const RETRY_INTERVAL = 16;

  const params = new URLSearchParams(location.search);
  const proveLayout = params.get('prove') === 'layout';

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  class CommandError extends Error {}

  // ---------------------------------------------------------------------
  // The app under test.

  const aut = {
    frame: null,
    get win() { return this.frame.contentWindow; },
    get doc() { return this.frame.contentDocument; },
  };

  let aliases = Object.create(null);
  let layoutDisagreements = [];

  function describe(el) {
    if (!el || el.nodeType !== 1) return String(el);
    let s = el.localName;
    if (el.id) s += '#' + el.id;
    if (el.classList && el.classList.length) s += '.' + [...el.classList].join('.');
    return '<' + s + '>';
  }

  // ---------------------------------------------------------------------
  // Visibility: Cypress 15.14.2 packages/driver/src/dom/visibility.ts,
  // isHidden = isStrictlyHidden || isHiddenByAncestors.

  const isBodyOrHtml = (el) => el.localName === 'body' || el.localName === 'html';

  // The parent in the flat tree (an element in a shadow tree: its host).
  function parentOf(el) {
    if (el.parentElement) return el.parentElement;
    const root = el.parentNode;
    return root && root.host ? root.host : null;
  }

  // The clauses decided by computed style alone. checkOpacity: false for
  // actionability (Cypress's ensure.ts:134 - an opacity: 0 element can be
  // acted on), true for the visibility assertions.
  function hiddenByStyle(el, checkOpacity = true) {
    if (!el.isConnected) return true; // detached: no box at all
    if (isBodyOrHtml(el)) return false; // visibility.ts:62
    if (el.localName === 'option' || el.localName === 'optgroup') { // :67-77
      const select = el.closest('select');
      return select ? hiddenByStyle(select, checkOpacity) : true;
    }
    const win = el.ownerDocument.defaultView;
    const style = win.getComputedStyle(el);
    // :96, :196-206 (visibility inherits: the element's own value decides).
    if (style.visibility === 'hidden' || style.visibility === 'collapse') return true;
    // :108 (the element) and :435 (an ancestor, elIsHiddenByAncestors).
    // No box (display: none on the element or an ancestor): what
    // getClientRects().length <= 0 detects for them (:151-153, :171).
    for (let n = el; n && !isBodyOrHtml(n); n = parentOf(n)) {
      const s = n === el ? style : win.getComputedStyle(n);
      if (s.display === 'none') return true;
      if (checkOpacity && s.opacity === '0') return true;
    }
    return false;
  }

  // The clauses that need layout (never decide a result; ?prove=layout).
  const OVERFLOW_PROPS = ['hidden', 'clip', 'scroll', 'auto']; // :11
  function overflowValues(style) { return [style.overflow, style.overflowX, style.overflowY]; }
  function hasNoEffectiveWidthOrHeight(el) { // :143-172
    const style = el.ownerDocument.defaultView.getComputedStyle(el);
    const transform = style.getPropertyValue('transform') || 'none';
    const hasTextContent = !!(el.textContent && el.textContent.trim().length);
    const r = el.getBoundingClientRect();
    const overflowHidden = overflowValues(style).some((v) => v && v.includes('hidden'));
    return ((r.width <= 0 && transform === 'none') || (r.height <= 0 && transform === 'none')) && !hasTextContent ||
      ((r.width <= 0 || r.height <= 0) && overflowHidden) ||
      el.getClientRects().length <= 0;
  }
  function hiddenByLayout(el) {
    const win = el.ownerDocument.defaultView;
    if (isBodyOrHtml(el)) return false;
    if (hasNoEffectiveWidthOrHeight(el)) { // :84-90
      if (win.getComputedStyle(el).display === 'inline') return ![...el.children].some((c) => !hiddenByStyle(c) && !hiddenByLayout(c));
      return true;
    }
    const rect = el.getBoundingClientRect();
    for (let p = parentOf(el); p && !isBodyOrHtml(p); p = parentOf(p)) {
      const ps = win.getComputedStyle(p);
      // :439 an ancestor with overflow hidden and no effective size.
      if (overflowValues(ps).some((v) => v && v.includes('hidden')) && hasNoEffectiveWidthOrHeight(p)) return true;
      // :362-405 out of the bounds of an ancestor that clips its overflow.
      if (overflowValues(ps).some((v) => OVERFLOW_PROPS.includes(v))) {
        const pr = p.getBoundingClientRect();
        if (rect.right <= pr.left || rect.left >= pr.right || rect.bottom <= pr.top || rect.top >= pr.bottom) return true;
      }
    }
    // :134-135 fixed or sticky: hidden when another element is at its centre.
    for (let n = el; n && !isBodyOrHtml(n); n = parentOf(n)) {
      const pos = win.getComputedStyle(n).position;
      if (pos === 'fixed' || pos === 'sticky') {
        const at = el.ownerDocument.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
        return !(at && (at === el || el.contains(at)));
      }
    }
    return false;
  }

  function isVisible(el, checkOpacity = true) {
    const hidden = hiddenByStyle(el, checkOpacity);
    if (proveLayout && !hidden && hiddenByLayout(el)) {
      layoutDisagreements.push(describe(el) + ' is visible by computed style but hidden by Cypress\'s layout clauses');
    }
    return !hidden;
  }

  // ---------------------------------------------------------------------
  // Text, as cy.contains matches it: whitespace collapsed and trimmed.

  const textOf = (el) => (el.textContent || '').replace(/\s+/g, ' ').trim();
  const textMatches = (el, content) => (content instanceof RegExp ? content.test(textOf(el)) : textOf(el).includes(String(content)));

  // ---------------------------------------------------------------------
  // Queries: a chain re-evaluated on every retry, as Cypress re-runs its
  // queries until the assertion that follows them passes or times out.

  function querySelectorAllVisible(root, selector) {
    // The spec's one jQuery extension, a trailing `:visible`
    // (spec.cy.js:349,362; commands.js:42).
    const m = /^(.*):visible$/.exec(selector);
    if (!m) return [...root.querySelectorAll(selector)];
    return [...root.querySelectorAll(m[1])].filter(isVisible);
  }

  class Chain {
    constructor(run, label) {
      this.run = run;
      this.label = label;
    }

    eq(i) {
      return new Chain(() => { const els = this.run(); return els[i] ? [els[i]] : []; }, `${this.label}.eq(${i})`);
    }

    find(selector) {
      return new Chain(() => this.run().flatMap((el) => querySelectorAllVisible(el, selector)), `${this.label}.find('${selector}')`);
    }

    // .contains(content) / .contains(selector, content) within the subject:
    // Cypress yields the deepest element containing the text, or the
    // nearest a / button / label / submit input around it.
    contains(a, b) {
      const selector = b === undefined ? null : a;
      const content = b === undefined ? a : b;
      return new Chain(() => {
        const out = [];
        for (const subject of this.run()) {
          const found = containsWithin(subject, selector, content);
          if (found) out.push(found);
        }
        return out.slice(0, 1);
      }, `${this.label}.contains(${selector ? `'${selector}', ` : ''}${content})`);
    }

    // .as(name): Cypress 12+ re-runs an aliased query each time the alias
    // is used; a command's result (cy.wrap here) is what it was.
    as(name) {
      aliases[name] = this.run;
      return this;
    }

    // The subject, retried until there is one: what a Cypress query
    // asserts by itself before the command after it (its implicit
    // existence assertion), recorded only when it fails.
    async resolve() {
      const deadline = performance.now() + COMMAND_TIMEOUT;
      for (;;) {
        let els = [];
        try {
          els = this.run();
        } catch (e) {}
        if (els.length > 0) return els;
        if (performance.now() > deadline) break;
        await sleep(RETRY_INTERVAL);
      }
      record(false, `${this.label}: never found`);
      return [];
    }

    // Retry until the chainer passes; a failure ends the test, as a failed
    // Cypress command does.
    async should(chainer, ...args) {
      const deadline = performance.now() + COMMAND_TIMEOUT;
      let last;
      for (;;) {
        let els;
        try {
          els = this.run();
        } catch (e) {
          els = [];
        }
        last = evaluate(chainer, args, els);
        if (last.pass) break;
        if (performance.now() > deadline) break;
        await sleep(RETRY_INTERVAL);
      }
      record(last.pass, `${this.label}.should('${chainer}'${args.map((x) => ', ' + JSON.stringify(String(x))).join('')})`, last.actual, last.expected);
      return this;
    }

    // The subject, retried until it is one element (and actionable when the
    // action needs it): what Cypress's actionability waits for, without
    // its geometry (scrolling, the covered check).
    async one(what, { visible = true } = {}) {
      const deadline = performance.now() + COMMAND_TIMEOUT;
      let why;
      for (;;) {
        let els = [];
        try {
          els = this.run();
        } catch (e) {}
        if (els.length === 1) {
          const el = els[0];
          if (!el.isConnected) why = 'it is detached from the document';
          else if (visible && !isVisible(el, false)) why = 'it is not visible';
          else if (el.disabled) why = 'it is disabled';
          else return el;
        } else why = els.length === 0 ? 'it was never found' : `it is ${els.length} elements`;
        if (performance.now() > deadline) break;
        await sleep(RETRY_INTERVAL);
      }
      record(false, `${this.label}.${what}(): ${why}`);
      return null;
    }

    async click(options = {}) { return act(this, 'click', options, (el) => click(el)); }
    async dblclick(options = {}) { return act(this, 'dblclick', options, (el) => dblclick(el)); }
    async check(options = {}) { return act(this, 'check', options, async (el) => { if (!el.checked) await click(el); }); }
    async uncheck(options = {}) { return act(this, 'uncheck', options, async (el) => { if (el.checked) await click(el); }); }
    async type(text, options = {}) { return act(this, 'type', options, (el) => type(el, text)); }
    async clear(options = {}) { return act(this, 'clear', options, (el) => type(el, '{selectall}{del}')); }
    async blur(options = {}) {
      return act(this, 'blur', { force: true, ...options }, (el) => {
        if (el.ownerDocument.activeElement !== el) throw new CommandError(`.blur() needs the focused element; ${describe(el)} is not focused`);
        el.blur();
      });
    }
  }

  async function act(chain, what, options, fn) {
    const el = await chain.one(what, { visible: !options.force });
    try {
      await fn(el);
    } catch (e) {
      if (e instanceof CommandError) record(false, `${chain.label}.${what}(): ${e.message}`);
      throw e;
    }
    return new Chain(() => [el], chain.label);
  }

  function containsWithin(subject, selector, content) {
    const candidates = [subject, ...subject.querySelectorAll(selector || '*')].filter((el) => (selector ? el.matches(selector) : true) && !['script', 'style'].includes(el.localName) && textMatches(el, content));
    if (candidates.length === 0) return null;
    if (selector) return candidates[0];
    // The deepest: a candidate with no candidate inside it.
    const deepest = candidates.find((el) => !candidates.some((o) => o !== el && el.contains(o)));
    const priority = deepest.closest('input[type=submit], button, a, label');
    return priority && subject.contains(priority) ? priority : deepest;
  }

  function evaluate(chainer, args, els) {
    const exists = els.length > 0;
    const anyVisible = () => els.some(isVisible);
    const jqText = () => els.map((e) => e.textContent).join('');
    // Since Cypress 6, an assertion other than non-existence or length on
    // an element that is not there fails (Cypress 6.0.0 changelog).
    const needs = (pass, actual, expected) => ({ pass: exists && pass, actual: exists ? actual : 'no element', expected });
    switch (chainer) {
      case 'have.length': return { pass: els.length === args[0], actual: els.length, expected: args[0] };
      case 'not.exist': return { pass: !exists, actual: els.length + ' element(s)', expected: 'none' };
      case 'exist': return { pass: exists, actual: els.length + ' element(s)', expected: 'one or more' };
      case 'be.visible': return needs(anyVisible(), anyVisible() ? 'visible' : 'hidden', 'visible');
      case 'not.be.visible': return needs(!anyVisible(), anyVisible() ? 'visible' : 'hidden', 'hidden');
      case 'contain': return needs(jqText().includes(args[0]), jqText(), args[0]);
      case 'have.text': return needs(jqText() === args[0], jqText(), args[0]);
      case 'have.value': return needs(exists && els[0].value === args[0], exists ? els[0].value : undefined, args[0]);
      case 'have.class': return needs(els.some((e) => e.classList.contains(args[0])), els.map((e) => e.className).join(' | '), args[0]);
      case 'not.have.class': return needs(!els.some((e) => e.classList.contains(args[0])), els.map((e) => e.className).join(' | '), 'not ' + args[0]);
      case 'have.id': return needs(els.some((e) => e.id === args[0]), els.map((e) => e.id).join(' | '), args[0]);
      case 'be.checked': return needs(els.some((e) => e.checked), els.map((e) => e.checked).join(' | '), true);
      case 'not.be.checked': return needs(!els.some((e) => e.checked), els.map((e) => e.checked).join(' | '), false);
      default: throw new Error('the port does not know the chainer ' + chainer);
    }
  }

  function record(pass, message, actual, expected) {
    const assert = QUnit.config.current && QUnit.config.current.assert;
    if (!assert) throw new Error('no running test: ' + message);
    assert.pushResult({ result: pass, actual, expected, message });
    if (!pass) throw new CommandError(message);
  }

  // ---------------------------------------------------------------------
  // Input, as Cypress 15's mouse and keyboard simulate it (its
  // packages/driver/src/cy/mouse.ts and keyboard.ts): the events a user's
  // input fires, created in the app's window, without coordinates.

  function mouseInit(el, extra) {
    return { bubbles: true, cancelable: true, composed: true, view: el.ownerDocument.defaultView, button: 0, detail: 1, ...extra };
  }

  function fire(el, Ctor, type, init) {
    const win = el.ownerDocument.defaultView;
    // A click is a PointerEvent (Pointer Events 3, "click"); a MouseEvent
    // where the window has no PointerEvent.
    const C = win[Ctor] || win.MouseEvent;
    return el.dispatchEvent(new C(type, init));
  }

  // The focus a mousedown's default action gives: the nearest focusable
  // inclusive ancestor, else the focused element loses focus.
  const focusableSelector = 'a[href], area[href], button, input, select, textarea, iframe, [tabindex], [contenteditable=""], [contenteditable="true"]';
  function focusOnMouseDown(el) {
    const doc = el.ownerDocument;
    const target = el.closest(focusableSelector);
    if (target && !target.disabled) {
      if (doc.activeElement !== target) target.focus();
    } else if (doc.activeElement && doc.activeElement !== doc.body) {
      doc.activeElement.blur();
    }
  }

  function press(el, detail) {
    const down = fire(el, 'PointerEvent', 'pointerdown', mouseInit(el, { pointerId: 1, pointerType: 'mouse', isPrimary: true, buttons: 1, detail: 0 }));
    let mousedown = true;
    if (down) mousedown = fire(el, 'MouseEvent', 'mousedown', mouseInit(el, { buttons: 1, detail }));
    if (mousedown) focusOnMouseDown(el);
    fire(el, 'PointerEvent', 'pointerup', mouseInit(el, { pointerId: 1, pointerType: 'mouse', isPrimary: true, buttons: 0, detail: 0 }));
    if (down) fire(el, 'MouseEvent', 'mouseup', mouseInit(el, { buttons: 0, detail }));
    // A click MouseEvent runs the element's activation behaviour (DOM
    // dispatch, "activation target"): a checkbox toggles, a link follows.
    fire(el, 'PointerEvent', 'click', mouseInit(el, { pointerId: 1, pointerType: 'mouse', isPrimary: true, detail }));
  }

  async function click(el) {
    press(el, 1);
    await sleep(0);
  }

  async function dblclick(el) {
    press(el, 1);
    press(el, 2);
    fire(el, 'MouseEvent', 'dblclick', mouseInit(el, { detail: 2 }));
    await sleep(0);
  }

  // Keys by name: [key, code, keyCode].
  const SPECIAL = {
    enter: ['Enter', 'Enter', 13],
    esc: ['Escape', 'Escape', 27],
    backspace: ['Backspace', 'Backspace', 8],
    del: ['Delete', 'Delete', 46],
  };

  function keyEvent(el, type, key, code, keyCode, charCode) {
    const init = { bubbles: true, cancelable: true, composed: true, view: el.ownerDocument.defaultView, key, code, keyCode, charCode, which: type === 'keypress' ? charCode : keyCode };
    const win = el.ownerDocument.defaultView;
    const ev = new win.KeyboardEvent(type, init);
    // The legacy codes, where the constructor does not take them (UI
    // Events' legacy KeyboardEventInit members).
    for (const [k, v] of [['keyCode', type === 'keypress' ? charCode : keyCode], ['charCode', type === 'keypress' ? charCode : 0], ['which', type === 'keypress' ? charCode : keyCode]]) {
      if (ev[k] !== v) Object.defineProperty(ev, k, { value: v });
    }
    return el.dispatchEvent(ev);
  }

  function inputEvent(el, type, inputType, data) {
    const win = el.ownerDocument.defaultView;
    return el.dispatchEvent(new win.InputEvent(type, { bubbles: true, cancelable: type === 'beforeinput', composed: true, inputType, data }));
  }

  // The element's value through the prototype's setter (what a user's
  // typing changes), not an own property a framework may have put on it.
  function setValue(el, value) {
    const win = el.ownerDocument.defaultView;
    const proto = el.localName === 'textarea' ? win.HTMLTextAreaElement.prototype : win.HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, value);
  }

  function editValue(el, inputType, data) {
    const v = el.value;
    let start = el.selectionStart;
    let end = el.selectionEnd;
    if (start === null || end === null) start = end = v.length;
    if (inputType === 'deleteContentBackward' && start === end) start = Math.max(0, start - 1);
    if (inputType === 'deleteContentForward' && start === end) end = Math.min(v.length, end + 1);
    if (start === end && inputType !== 'insertText') return false;
    const insert = data || '';
    setValue(el, v.slice(0, start) + insert + v.slice(end));
    el.setSelectionRange(start + insert.length, start + insert.length);
    return true;
  }

  function typeCharacter(el, ch) {
    const keyCode = ch.toUpperCase().charCodeAt(0);
    if (keyEvent(el, 'keydown', ch, '', keyCode, 0) && keyEvent(el, 'keypress', ch, '', ch.charCodeAt(0), ch.charCodeAt(0)) && inputEvent(el, 'beforeinput', 'insertText', ch)) {
      editValue(el, 'insertText', ch);
      inputEvent(el, 'input', 'insertText', ch);
    }
    keyEvent(el, 'keyup', ch, '', keyCode, 0);
  }

  function typeSpecial(el, name) {
    if (name === 'selectall') {
      el.select();
      return;
    }
    const spec = SPECIAL[name];
    if (!spec) throw new CommandError(`the port does not type {${name}}`);
    const [key, code, keyCode] = spec;
    const down = keyEvent(el, 'keydown', key, code, keyCode, 0);
    if (down && name === 'enter') {
      // Enter's keypress, then the form's implicit submission (HTML
      // 4.10.21.2) when the field is in a form.
      if (keyEvent(el, 'keypress', key, code, keyCode, keyCode) && el.form) implicitSubmission(el);
    } else if (down && (name === 'backspace' || name === 'del')) {
      const inputType = name === 'backspace' ? 'deleteContentBackward' : 'deleteContentForward';
      const v = el.value;
      const hasSomething = el.selectionStart !== el.selectionEnd || (name === 'backspace' ? el.selectionStart > 0 : el.selectionEnd < v.length);
      if (hasSomething && inputEvent(el, 'beforeinput', inputType, null) && editValue(el, inputType, null)) inputEvent(el, 'input', inputType, null);
    }
    keyEvent(el, 'keyup', key, code, keyCode, 0);
  }

  function implicitSubmission(el) {
    const form = el.form;
    const submitter = [...form.elements].find((e) => (e.localName === 'button' && (e.type || 'submit') === 'submit') || (e.localName === 'input' && ['submit', 'image'].includes(e.type)));
    if (submitter) {
      if (!submitter.disabled) press(submitter, 1);
      return;
    }
    const blocking = [...form.elements].filter((e) => e.localName === 'input' && ['text', 'search', 'url', 'tel', 'email', 'password', 'date', 'month', 'week', 'time', 'datetime-local', 'number'].includes(e.type));
    if (blocking.length <= 1) form.requestSubmit();
  }

  function tokens(text) {
    const out = [];
    const re = /\{([a-z]+)\}|([^{]|\{(?![a-z]+\}))/g;
    let m;
    while ((m = re.exec(text))) out.push(m[1] ? { special: m[1] } : { ch: m[2] });
    return out;
  }

  async function type(el, text) {
    const doc = el.ownerDocument;
    // Cypress clicks a field that is not focused before typing into it,
    // then types at the end of its value.
    if (doc.activeElement !== el) {
      await click(el);
      if (doc.activeElement !== el) el.focus();
    }
    if (typeof el.setSelectionRange === 'function') el.setSelectionRange(el.value.length, el.value.length);
    for (const t of tokens(text)) {
      if (t.special) typeSpecial(el, t.special);
      else typeCharacter(el, t.ch);
      await sleep(KEYSTROKE_DELAY);
    }
  }

  // ---------------------------------------------------------------------
  // Commands on the window.

  function waitForLoad(frame) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new CommandError(`the page did not load within ${PAGE_LOAD_TIMEOUT} ms`)), PAGE_LOAD_TIMEOUT);
      frame.addEventListener('load', () => { clearTimeout(timer); resolve(); }, { once: true });
    });
  }

  const cy = {
    // cy.visit: Cypress 12+ test isolation clears the page (about:blank)
    // and the origin's storage before each test, then loads the URL.
    async visit(url) {
      try {
        aut.frame.contentWindow.localStorage.clear();
      } catch (e) {}
      localStorage.clear();
      if (aut.frame.contentWindow.location.href !== 'about:blank') {
        const blank = waitForLoad(aut.frame);
        aut.frame.src = 'about:blank';
        await blank;
      }
      const loaded = waitForLoad(aut.frame);
      aut.frame.src = url;
      try {
        await loaded;
      } catch (e) {
        record(false, `cy.visit('${url}'): ${e.message}`);
      }
    },
    async reload() {
      const loaded = waitForLoad(aut.frame);
      aut.win.location.reload();
      await loaded;
    },
    async go(direction) {
      if (direction === 'back') aut.win.history.back();
      else if (direction === 'forward') aut.win.history.forward();
      else aut.win.history.go(direction);
      await sleep(0);
    },
    get(selector) {
      if (selector.startsWith('@')) {
        const name = selector.slice(1);
        return new Chain(() => {
          if (!(name in aliases)) throw new Error('no alias ' + name);
          return aliases[name]();
        }, `cy.get('${selector}')`);
      }
      return new Chain(() => querySelectorAllVisible(aut.doc, selector), `cy.get('${selector}')`);
    },
    contains(a, b) {
      return new Chain(() => [aut.doc.documentElement], 'cy').contains(a, b);
    },
    focused() {
      return new Chain(() => {
        const a = aut.doc.activeElement;
        return a && a !== aut.doc.body ? [a] : [];
      }, 'cy.focused()');
    },
    wrap(els, label) {
      return new Chain(() => els, label || 'cy.wrap()');
    },
    window() { return aut.win; },
    document() { return aut.doc; },
  };

  global.Driver = {
    cy,
    aut,
    CommandError,
    proveLayout,
    isVisible,
    // Per test: a fresh alias table and disagreement list.
    reset() {
      aliases = Object.create(null);
      layoutDisagreements = [];
    },
    takeLayoutDisagreements() {
      const d = layoutDisagreements;
      layoutDisagreements = [];
      return d;
    },
    sleep,
  };
})(window);
