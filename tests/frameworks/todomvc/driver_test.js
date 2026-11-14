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

  QUnit.start();
})();
