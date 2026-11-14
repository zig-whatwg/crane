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

  // Cypress's configuration as the project sets it in cypress.config.js
  // (spec.js reads it before the run), Cypress's defaults where it sets
  // nothing (packages/config: includeShadowDom false).
  const config = { includeShadowDom: false };

  // What cypress.config.js sets for the options the port honours. TodoMVC's
  // sets includeShadowDom: true in its e2e block ("required for the spec's
  // selectors to find anything in the web-component apps"); the port reads
  // the project's file, never a copy, and refuses one it cannot read as one
  // value.
  function readCypressConfig(text) {
    const code = text.replace(/\/\*[\s\S]*?\*\//g, '').split('\n').map((line) => line.replace(/^\s*\/\/.*$/, '')).join('\n');
    const found = [...code.matchAll(/\bincludeShadowDom\s*:\s*(true|false)\b/g)];
    if (found.length > 1) throw new Error('cypress.config.js sets includeShadowDom more than once; the port reads one value');
    return { includeShadowDom: found.length === 1 && found[0][1] === 'true' };
  }

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
  // Text, as cy.contains matches it (Cypress dom/elements/utils.ts
  // normalizeWhitespaces): textContent with each run of whitespace made one
  // space, not trimmed; a <pre>'s text as it is.

  const textOf = (el) => {
    const text = el.textContent || '';
    return el.localName === 'pre' ? text : text.replace(/\s+/g, ' ');
  };

  // ---------------------------------------------------------------------
  // Shadow roots, as Cypress finds them (dom/elements/shadow.ts
  // findAllShadowRoots): every open shadow root below `root`, depth first
  // from the last one found, each root's own (a tree walker over elements
  // that host one) before the roots inside them.

  function findShadowRoots(root) {
    const doc = root.getRootNode({ composed: true });
    const walker = doc.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_DOCUMENT_FRAGMENT, {
      acceptNode(node) {
        return node.shadowRoot ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP;
      },
    });
    const roots = [];
    if (root.shadowRoot) roots.push(root.shadowRoot);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) roots.push(node.shadowRoot);
    return roots;
  }

  function findAllShadowRoots(root) {
    const pending = [root];
    const nodes = [];
    for (let current = pending.pop(); current; current = pending.pop()) {
      const childRoots = findShadowRoots(current);
      if (childRoots.length > 0) {
        pending.push(...childRoots);
        nodes.push(...childRoots);
      }
    }
    return nodes;
  }

  // jQuery 3.7.1's uniqueSort (the jQuery Cypress 15.14.2 bundles), which
  // orders what a query over several contexts found: document order within
  // one tree; two nodes of different trees (compareDocumentPosition says
  // DISCONNECTED: a shadow tree and the document, or two shadow trees)
  // compare equal, as neither is in jQuery's own document (Cypress's spec
  // frame), so the stable sort keeps the order they were found in.
  function uniqueSort(nodes) {
    let hasDuplicate = false;
    nodes.sort((a, b) => {
      if (a === b) {
        hasDuplicate = true;
        return 0;
      }
      const compare = (a.ownerDocument || a) === (b.ownerDocument || b) ? a.compareDocumentPosition(b) : 1;
      if (compare & 1) return 0;
      return compare & 4 ? -1 : 1;
    });
    if (!hasDuplicate) return nodes;
    return nodes.filter((node, i) => i === 0 || node !== nodes[i - 1]);
  }

  // ---------------------------------------------------------------------
  // Queries: a chain re-evaluated on every retry, as Cypress re-runs its
  // queries until the assertion that follows them passes or times out.

  // A selector's comma-separated groups (outside brackets and strings).
  function selectorGroups(selector) {
    const groups = [];
    let depth = 0;
    let quote = null;
    let start = 0;
    for (let i = 0; i < selector.length; i++) {
      const c = selector[i];
      if (quote) {
        if (c === '\\') i++;
        else if (c === quote) quote = null;
      } else if (c === '"' || c === "'") quote = c;
      else if (c === '(' || c === '[') depth++;
      else if (c === ')' || c === ']') depth--;
      else if (c === ',' && depth === 0) {
        groups.push(selector.slice(start, i).trim());
        start = i + 1;
      }
    }
    groups.push(selector.slice(start).trim());
    return groups;
  }

  // jQuery.find(selector, context): in an element, each group of the
  // selector is scoped to it (Sizzle's "#nid <group>" rewrite: the whole
  // group matches inside the element); in a document or shadow root, as it
  // is. The spec's one jQuery extension, a trailing `:visible`
  // (spec.cy.js:349,362; commands.js:42), is Cypress's visibility (its
  // config/jquery.ts replaces jQuery's).
  function findIn(context, selector) {
    const m = /^(.*):visible$/.exec(selector);
    const plain = m ? m[1] : selector;
    const scoped = context.nodeType === 1 ? selectorGroups(plain).map((g) => ':scope ' + g).join(', ') : plain;
    const found = [...context.querySelectorAll(scoped)];
    return m ? found.filter((el) => isVisible(el)) : found;
  }

  // jQuery.fn.find over a set of contexts: each context's matches in turn,
  // then uniqueSort when there was more than one context.
  function findInEach(contexts, selector) {
    const out = [];
    for (const context of contexts) out.push(...findIn(context, selector));
    return contexts.length > 1 ? uniqueSort(out) : out;
  }

  // cy.get within `root` (querying.ts get): with includeShadowDom, in each
  // of root's shadow roots and then root itself; the document alone
  // otherwise.
  function getIn(root, selector) {
    return findInEach(config.includeShadowDom ? findAllShadowRoots(root).concat(root) : [root], selector);
  }

  // The elements cy.contains' selector matches within one context
  // (find.ts getContainsSelector): for each group of the filter (any
  // element when there is none), an element whose text holds the content
  // (`:cy-contains`, matched case and all) or matches the RegExp
  // (`:cy-contains-regex`, a submit input by its value), or a submit input
  // of that group whose value holds the content as a word
  // (`[type='submit'][value~=...]`), in document order. Sizzle runs these
  // non-native pseudos itself: a group's ancestors are not scoped to the
  // context, as with querySelectorAll.
  function containsMatch(el, filter, content) {
    const groups = filter ? selectorGroups(filter) : ['*'];
    const isSubmit = el.localName === 'input' && el.type === 'submit';
    const literal = content instanceof RegExp ? content.toString() : String(content);
    return groups.some((g) => {
      if (!el.matches(g)) return false;
      if (content instanceof RegExp) {
        if (isSubmit ? content.test(el.value) : content.test(textOf(el))) return true;
      } else if (textOf(el).includes(literal)) return true;
      return el.getAttribute('type') === 'submit' && (el.getAttribute('value') || '').split(/\s+/).includes(literal);
    });
  }
  function containsIn(context, filter, content) {
    return [...context.querySelectorAll('*')].filter((el) => containsMatch(el, filter, content));
  }

  // find.ts getFirstDeepestElement: from the first match, step to the next
  // while it is inside the current one (script and style skipped); stop at
  // a priority element (submit input, button, a, label), else yield the
  // last match that is a priority-element ancestor of the current one.
  const PRIORITY = "input[type='submit'], button, a, label";
  function jqContains(a, b) { // jQuery.contains
    const up = b && b.parentNode;
    return a === up || !!(up && up.nodeType === 1 && a.contains(up));
  }
  function getFirstDeepestElement(els, index = 0) {
    const current = els[index];
    if (current === undefined) return [];
    const next = els[index + 1];
    if (current.localName === 'script' || current.localName === 'style') return getFirstDeepestElement(els, index + 1);
    if (jqContains(current, next)) return getFirstDeepestElement(els, index + 1);
    if (current.matches(PRIORITY)) return [current];
    const parents = [];
    for (let p = parentOf(current); p; p = parentOf(p)) if (p.matches(PRIORITY)) parents.push(p);
    const priorities = els.filter((el) => parents.includes(el));
    return priorities.length ? [priorities[priorities.length - 1]] : [current];
  }

  // cy.contains on a subject (querying.ts contains): its matches in each
  // subject element (and that element's shadow roots, with
  // includeShadowDom), merged in jQuery's order; when there are none, the
  // subject elements that match themselves; then the first deepest.
  function containsWithin(subject, filter, content) {
    let found = [];
    for (const el of subject) {
      const scope = config.includeShadowDom ? findAllShadowRoots(el).concat(el) : [el];
      const inEl = [];
      for (const context of scope) inEl.push(...containsIn(context, filter, content));
      found = uniqueSort(found.concat(scope.length > 1 ? uniqueSort(inEl) : inEl));
    }
    if (found.length === 0) found = subject.filter((el) => containsMatch(el, filter, content));
    return getFirstDeepestElement(found);
  }

  // A command's result is what it was: Cypress re-runs queries, never
  // commands, so a chain that starts from one (cy.wrap, an action's
  // subject, an alias of either) checks before every query, assertion or
  // action on it that its elements are still in a page - connected, their
  // document's window active (cypress/ensure.ts isAttached,
  // dom/elements/detached.ts) - and otherwise fails as Cypress does
  // (error_messages.ts subject.detached_after_command).
  class DetachedError extends Error {}
  const attached = (el) => !(el && el.nodeType === 1) || (el.isConnected && !!el.ownerDocument.defaultView);
  function commandResult(els) {
    return () => {
      if (!els.every(attached)) throw new DetachedError('the page updated as a result of this command: the subject is no longer attached to the DOM, and Cypress cannot requery the page after a command');
      return els;
    };
  }

  class Chain {
    // `result`: the elements of a command's result, which `then` hands on
    // as they are (no attachment check: cy.then is not a query).
    constructor(run, label, result = null) {
      this.run = run;
      this.label = label;
      this.result = result;
    }

    // What `.then(fn)` passes fn: a command's result as it was, else the
    // query's current elements.
    subject() {
      return this.result || this.run();
    }

    // .invoke(name) (connectors.ts): the subject's method, retried until the
    // property exists; Cypress fails "the property: <name> does not exist on
    // your subject" otherwise.
    async invoke(name, ...args) {
      const deadline = performance.now() + COMMAND_TIMEOUT;
      for (;;) {
        let subject;
        try {
          subject = this.run()[0];
        } catch (e) {}
        if (subject != null && typeof subject[name] === 'function') return subject[name](...args);
        if (performance.now() > deadline) break;
        await sleep(RETRY_INTERVAL);
      }
      record(false, `${this.label}.invoke('${name}'): the property ${name} does not exist on your subject`);
      return undefined;
    }

    eq(i) {
      return new Chain(() => { const els = this.run(); return els[i] ? [els[i]] : []; }, `${this.label}.eq(${i})`);
    }

    // .find(selector) (traversals.ts): in the subject's elements, and with
    // includeShadowDom in their shadow roots too (the set merged by
    // jQuery's .add, which sorts it).
    find(selector) {
      return new Chain(() => {
        const subject = this.run();
        const contexts = config.includeShadowDom ? uniqueSort(subject.concat(subject.flatMap((el) => findAllShadowRoots(el)))) : subject;
        return findInEach(contexts, selector);
      }, `${this.label}.find('${selector}')`);
    }

    // .contains(content) / .contains(selector, content) within the subject
    // (containsWithin above).
    contains(a, b) {
      const filter = b === undefined ? '' : a;
      const content = b === undefined ? a : b;
      return new Chain(() => containsWithin(this.run(), filter, content), `${this.label}.contains(${filter ? `'${filter}', ` : ''}${content})`);
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
      let why = 'never found';
      for (;;) {
        let els = [];
        try {
          els = this.run();
        } catch (e) {
          if (e instanceof DetachedError) why = e.message;
        }
        if (els.length > 0) return els;
        if (performance.now() > deadline) break;
        await sleep(RETRY_INTERVAL);
      }
      record(false, `${this.label}: ${why}`);
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
          if (e instanceof DetachedError) {
            last = { pass: false, actual: e.message, expected: 'its subject attached' };
            if (performance.now() > deadline) break;
            await sleep(RETRY_INTERVAL);
            continue;
          }
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
        } catch (e) {
          if (e instanceof DetachedError) why = e.message;
        }
        if (els.length === 1) {
          const el = els[0];
          if (!el.isConnected) why = 'it is detached from the document';
          else if (visible && !isVisible(el, false)) why = 'it is not visible';
          else if (el.disabled) why = 'it is disabled';
          else return el;
        } else if (els.length > 1) why = `it is ${els.length} elements`;
        else if (!why || !why.startsWith('the page updated')) why = 'it was never found';
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
        commitChange(el);
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
    return new Chain(commandResult([el]), chain.label, [el]);
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
      // A spy (sinon-chai's calledWith family): called at least once.
      case 'have.been.called': return needs(exists && els[0].callCount > 0, `called ${exists ? els[0].callCount : 0} time(s)`, 'called at least once');
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
      if (doc.activeElement !== target) {
        if (doc.activeElement) commitChange(doc.activeElement);
        target.focus();
      }
    } else if (doc.activeElement && doc.activeElement !== doc.body) {
      commitChange(doc.activeElement);
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

  // Cypress fires `change` itself once typing has changed a field's value
  // and the field is committed - {enter} into an input, or the field losing
  // focus - as a browser does for a user's edit (Cypress
  // packages/driver/src/cy/commands/actions/type.ts onValueChange and
  // onEnterPressed, cy/focused.ts fireBlur); a value a script sets makes no
  // browser fire it. Apps that add a todo on `change` (the vanilla
  // JavaScript ones) rely on it.
  let pendingChange = null;
  function noteValueChange(el, original) {
    if (!pendingChange || pendingChange.el !== el) pendingChange = { el, original };
  }
  function commitChange(el) {
    if (!pendingChange || pendingChange.el !== el) return;
    const changed = el.value !== pendingChange.original;
    pendingChange = null;
    if (changed) el.dispatchEvent(new (el.ownerDocument.defaultView.Event)('change', { bubbles: true }));
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
    noteValueChange(el, v);
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
      // Enter's keypress, then (an input, not a textarea) the change its
      // typing made, then the form's implicit submission (HTML 4.10.21.2)
      // when the field is in a form.
      if (keyEvent(el, 'keypress', key, code, keyCode, keyCode)) {
        if (el.localName === 'input') commitChange(el);
        if (el.form) implicitSubmission(el);
      }
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

  // complexElements.ts isFocused: the active element of the element's own
  // root (its shadow root, else its document), which is not the default
  // (none, or a body that is not editable).
  function isFocused(el, root) {
    const active = root.activeElement;
    if (!active || (active === root.body && !active.isContentEditable)) return false;
    return active === el;
  }
  function getFocused(root) {
    if (!root) return null;
    const active = root.activeElement;
    if (!isFocused(active, root)) return null;
    if (active.shadowRoot && active.shadowRoot.activeElement) return getFocused(active.shadowRoot);
    return active;
  }

  const cy = {
    // cy.visit:Cypress 12+ test isolation clears the page (about:blank)
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
      return new Chain(() => getIn(aut.doc, selector), `cy.get('${selector}')`);
    },
    // cy.contains with no subject: within the body (querying.ts).
    contains(a, b) {
      return new Chain(() => (aut.doc.body ? [aut.doc.body] : []), 'cy').contains(a, b);
    },
    // cy.focused() (cy/focused.ts getFocused): the document's focused
    // element, or, when that hosts a shadow root with a focused element,
    // that root's, innermost first - whatever includeShadowDom says.
    focused() {
      return new Chain(() => {
        const el = getFocused(aut.doc);
        return el ? [el] : [];
      }, 'cy.focused()');
    },
    // cy.wrap(subject): a command's result (commandResult above).
    wrap(els, label) {
      return new Chain(commandResult(els), label || 'cy.wrap()', els);
    },
    // cy.spy(obj, method), as Cypress 15.14.2's (Sinon 8.1.1's spy): the
    // method wrapped, its calls counted; resetHistory(), and no reset() -
    // Sinon gives reset() to stubs only, so a spec's invoke('reset') on a
    // spy fails in Cypress, and here.
    spy(obj, method) {
      const original = obj[method];
      const s = function () {
        s.callCount += 1;
        s.called = true;
        return original.apply(this, arguments);
      };
      s.callCount = 0;
      s.called = false;
      s.resetHistory = () => {
        s.callCount = 0;
        s.called = false;
      };
      obj[method] = s;
      return s;
    },
    window() { return aut.win; },
    document() { return aut.doc; },
  };

  // Mocha's rule for a failed hook (Mocha 7.2.0, Cypress 15.14.2's): when a
  // beforeEach or afterEach hook fails, the test it ran for fails, and no
  // later test of the suite that declared the hook runs - the whole
  // describe for one of its own hooks, the context for a context's - which
  // Cypress reports as skipped. `failed(null)` is the describe's hook,
  // `failed(name)` a context's.
  class HookSkips {
    constructor() {
      this.scope = null;
      this.test = null;
    }
    failed(context, testId) {
      if (!this.scope || !this.scope.all) this.scope = context === null ? { all: true } : { context };
      this.test = testId;
    }
    skips(context) {
      return !!this.scope && (this.scope.all || this.scope.context === context);
    }
  }

  global.Driver = {
    HookSkips,
    cy,
    aut,
    config,
    readCypressConfig,
    CommandError,
    proveLayout,
    isVisible,
    // Per test: a fresh alias table and disagreement list.
    reset() {
      aliases = Object.create(null);
      layoutDisagreements = [];
      pendingChange = null;
    },
    takeLayoutDisagreements() {
      const d = layoutDisagreements;
      layoutDisagreements = [];
      return d;
    },
    sleep,
  };
})(window);
