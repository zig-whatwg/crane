// The port's own tests of driver.js: each pins one thing Cypress 15.14.2
// does (its source cited per test) on the fixture fixtures/shadow.html, so a
// change to the driver is checked before the 43 apps run. Run by
// driver_test.html in any browser; its TAP goes to the console as the app
// spec's does.
'use strict';

QUnit.config.autostart = false;
QUnit.config.reorder = false;
QUnit.config.reporters.tap = true;

(async function () {
  const { cy } = Driver;
  const FIXTURE = 'fixtures/shadow.html';
  const ids = (els) => els.map((el) => el.localName + (el.className ? '.' + el.className : '') + (el.getRootNode() === el.ownerDocument ? '' : '@shadow'));

  QUnit.module('Driver: includeShadowDom', function (hooks) {
    hooks.before(async function () {
      Driver.aut.frame = document.getElementById('aut');
      await cy.visit(FIXTURE);
    });
    hooks.afterEach(function () {
      Driver.config.includeShadowDom = false;
    });

    // cypress.config.js is read as the project wrote it: the e2e block's
    // value (TodoMVC's: true), Cypress's default (false) when it sets none.
    QUnit.test('the project\'s cypress.config.js sets includeShadowDom', function (assert) {
      const todomvc = "import { defineConfig } from 'cypress';\nexport default defineConfig({\n  e2e: {\n    baseUrl: 'http://localhost:8000/examples/',\n    // shadow-dom piercing globally is a no-op for light-DOM apps\n    includeShadowDom: true,\n  },\n});\n";
      assert.deepEqual(Driver.readCypressConfig(todomvc), { includeShadowDom: true });
      assert.deepEqual(Driver.readCypressConfig("export default defineConfig({ e2e: { baseUrl: 'http://x/' } })"), { includeShadowDom: false });
      assert.deepEqual(Driver.readCypressConfig("export default defineConfig({ e2e: {\n  includeShadowDom: false,\n} })"), { includeShadowDom: false });
      assert.throws(() => Driver.readCypressConfig('includeShadowDom: true,\nincludeShadowDom: false,\n'), /includeShadowDom/);
    });

    // querying.ts get: without the option, the document alone.
    QUnit.test('without includeShadowDom cy.get sees the light DOM only', function (assert) {
      assert.deepEqual(ids(cy.get('.new-todo').run()), []);
      assert.deepEqual(ids(cy.get('h1').run()), ['h1.light']);
    });

    // querying.ts get: scope = findAllShadowRoots(root).concat(root), the
    // selector found in each (shadow.ts).
    QUnit.test('with includeShadowDom cy.get finds elements inside shadow roots', function (assert) {
      Driver.config.includeShadowDom = true;
      assert.deepEqual(ids(cy.get('.new-todo').run()), ['input.new-todo@shadow']);
      assert.deepEqual(ids(cy.get('.toggle').run()), ['input.toggle@shadow', 'input.toggle@shadow']);
    });

    // The selector is run in each root by itself, so a descendant
    // combinator never crosses a shadow boundary: '.todo-list li' finds the
    // flat list's items, not the items of todo-item's roots (tests/cya.js:
    // "includeShadowDom: true doesn't pierce three nested shadow roots").
    QUnit.test('a selector matches within one root, never across a shadow boundary', function (assert) {
      Driver.config.includeShadowDom = true;
      assert.deepEqual(ids(cy.get('.todo-list li').run()), ['li.flat@shadow', 'li.flat@shadow']);
      assert.deepEqual(ids(cy.get('li.deep').run()), ['li.deep@shadow', 'li.deep@shadow']);
    });

    // The roots' results first, the document's last (the scope's order;
    // jQuery 3.7.1's uniqueSort keeps the order of nodes in different trees).
    QUnit.test('results from shadow roots come before the document\'s', function (assert) {
      Driver.config.includeShadowDom = true;
      assert.deepEqual(ids(cy.get('h1').run()), ['h1@shadow', 'h1.light']);
    });

    // traversals.ts find: the subject and its shadow roots.
    QUnit.test('.find() looks into the subject\'s shadow roots with includeShadowDom', function (assert) {
      assert.deepEqual(ids(cy.get('todo-app').find('.new-todo').run()), []);
      Driver.config.includeShadowDom = true;
      assert.deepEqual(ids(cy.get('todo-app').find('.new-todo').run()), ['input.new-todo@shadow']);
    });

    // querying.ts contains: a get of the contains selector, scoped to body.
    QUnit.test('cy.contains finds text inside shadow roots with includeShadowDom', function (assert) {
      assert.deepEqual(ids(cy.contains('h1', /^todos$/i).run()), []);
      Driver.config.includeShadowDom = true;
      assert.deepEqual(ids(cy.contains('h1', /^todos$/i).run()), ['h1@shadow']);
      assert.deepEqual(ids(cy.contains('Clear completed').run()), ['button.clear-completed@shadow']);
    });

    // cy/focused.ts getFocused: the active element of the innermost shadow
    // root, whatever includeShadowDom says.
    QUnit.test('cy.focused() yields the focused element inside a shadow root', function (assert) {
      const input = cy.document().querySelector('todo-app').shadowRoot.querySelector('.new-todo');
      input.focus();
      assert.deepEqual(ids(cy.focused().run()), ['input.new-todo@shadow']);
      input.blur();
      assert.deepEqual(ids(cy.focused().run()), []);
    });
  });

  QUnit.module('Driver: Cypress\'s subjects and hooks', function (hooks) {
    hooks.before(async function () {
      Driver.aut.frame = document.getElementById('aut');
      await cy.visit(FIXTURE);
    });

    // cypress/ensure.ts isAttached: a command's result is not requeried, so
    // it fails once its element leaves the page; a query finds the new one.
    QUnit.test('a command\'s result fails once detached; a query is run again', function (assert) {
      const doc = cy.document();
      const p = doc.createElement('p');
      p.className = 'tmp';
      doc.body.append(p);
      const wrapped = cy.wrap([p], 'cy.wrap(p)');
      assert.deepEqual(ids(wrapped.run()), ['p.tmp']);
      const alias = wrapped.as('p');
      p.remove();
      assert.throws(() => wrapped.run(), /no longer attached to the DOM/);
      assert.throws(() => cy.get('@p').eq(0).run(), /no longer attached to the DOM/);
      // cy.then hands a command's result on as it was.
      assert.strictEqual(alias.subject()[0], p);
      const again = doc.createElement('p');
      again.className = 'tmp';
      doc.body.append(again);
      cy.get('p.tmp').as('q');
      assert.strictEqual(cy.get('@q').run()[0], again);
      again.remove();
      assert.deepEqual(cy.get('@q').run(), []);
    });

    // Cypress 15.14.2's cy.spy is Sinon 8.1.1's spy: resetHistory(), no reset().
    QUnit.test('cy.spy counts calls, and has resetHistory but no reset', async function (assert) {
      const target = { setItem(k, v) { return k + '=' + v; } };
      const spy = cy.spy(target, 'setItem');
      assert.strictEqual(spy.callCount, 0);
      assert.strictEqual(target.setItem('a', 1), 'a=1');
      assert.strictEqual(spy.callCount, 1);
      assert.strictEqual(typeof spy.reset, 'undefined');
      assert.strictEqual(await cy.wrap([spy]).invoke('resetHistory'), undefined);
      assert.strictEqual(spy.callCount, 0);
    });

    // cy/actionability.ts: an action that is not forced waits for a second
    // coordinate sample, one retry interval (16 ms) after the first; a forced
    // one acts at once.
    QUnit.test('an action waits one retry interval for its second look; a forced one does not', async function (assert) {
      const doc = cy.document();
      const b = doc.createElement('button');
      b.className = 'tmp-b';
      doc.body.append(b);
      let ready = false;
      let seen = null;
      b.addEventListener('click', () => { seen = ready; });
      setTimeout(() => { ready = true; }, 4);
      await cy.get('button.tmp-b').click();
      assert.strictEqual(seen, true, 'the click came after a task 4 ms later');
      ready = false;
      setTimeout(() => { ready = true; }, 4);
      await cy.get('button.tmp-b').click({ force: true });
      assert.strictEqual(seen, false, 'the forced click came at once');
      b.remove();
    });

    // Cypress 12+'s test isolation: about:blank when a test ends, the
    // storage cleared when the next begins, so a page's save on unload is
    // gone before the next visit.
    QUnit.test('what a page saves as it unloads does not reach the next visit', async function (assert) {
      await cy.visit('fixtures/unload.html');
      assert.strictEqual(localStorage.getItem('fixture-saved-on-unload'), null);
      await cy.visit(FIXTURE);
      assert.strictEqual(localStorage.getItem('fixture-saved-on-unload'), null);
    });

    // Mocha 7.2.0: a failed hook fails its test and skips the rest of the
    // suite that declared it.
    QUnit.test('a failed hook skips the rest of its suite: its context, or all of the describe', function (assert) {
      const h = new Driver.HookSkips();
      assert.false(h.skips('Editing'));
      h.failed('Mark all as completed', 't1');
      assert.true(h.skips('Mark all as completed'));
      assert.false(h.skips('Item'));
      h.failed('Editing', 't2');
      assert.true(h.skips('Editing'));
      assert.strictEqual(h.test, 't2');
      h.failed(null, 't3');
      assert.true(h.skips('Routing'));
      h.failed('Routing', 't4');
      assert.true(h.skips('Counter'), 'the describe\'s skip outlasts a context\'s');
    });
  });

  QUnit.start();
})();
