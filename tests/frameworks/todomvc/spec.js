// Crane's port of TodoMVC's app spec to an in-page QUnit suite.
//
// The source: tastejs/todomvc at ff43b02e59dfa604386bb382034b2cd07c2bcd8a,
// cypress/e2e/spec.cy.js (29 tests, run by Cypress 15.14.2 against
// examples/<framework>) and cypress/support/commands.js. Each test below
// keeps the spec's name, module (its `context`) and steps, and cites the
// spec's lines; the Cypress commands are driver.js's. The spec's own data -
// its per-framework tables and tests/knownIssues.js - is read from the
// served tree at run time, never copied here, and the list of tests is
// checked against the spec's source before the run starts.
//
// The app: ?framework=<value>, exactly what Cypress takes as
// `--env framework=<value>` (spec.cy.js:18): a directory of examples/
// (react, vue, knockoutjs, ...) or a path below it, opened at '/examples/' +
// frameworkFolders[value] || value (spec.cy.js:53), served from the tree's
// root as the project's server serves it (cypress.config.js: baseUrl
// http://localhost:8000/examples/; tests/server.js: express.static(root)).
// The spec's own error text names the path form ("CYPRESS_framework=
// angular-dart/web"); the matrix passes it for the five apps whose build
// todomvc.com links is not the spec's default folder (backbone/dist,
// emberjs/todomvc/dist, javascript-es5/dist, jquery/dist,
// web-components/dist: the defaults are unbuilt sources), and those apps
// lose their name-keyed tables exactly as they do in Cypress.
//
// Cypress's configuration is read from the project's cypress.config.js
// (includeShadowDom: driver.js), never copied.
'use strict';

QUnit.config.autostart = false;
QUnit.config.reorder = false;
QUnit.config.testTimeout = 60000;
// The run as TAP on the console too (QUnit's own reporter), so any
// browser's console log carries it beside the HTML report.
QUnit.config.reporters.tap = true;

(async function () {
  const { cy } = Driver;
  const SPEC = '/cypress/e2e/spec.cy.js';
  const KNOWN_ISSUES = '/tests/knownIssues.js';
  const CONFIG = '/cypress.config.js';

  async function source(url) {
    const r = await fetch(url);
    if (!r.ok) throw new Error(`${url}: HTTP ${r.status}`);
    return r.text();
  }

  // A `const <name> = { ... }` table of spec.cy.js: keys to strings or
  // booleans, `...<other>` spreads.
  function table(src, name) {
    const head = `const ${name} = {`;
    const start = src.indexOf(head);
    if (start < 0) throw new Error(`${SPEC} has no table ${name}`);
    const end = src.indexOf('\n}', start);
    const out = {};
    for (let line of src.slice(start + head.length, end).split('\n')) {
      line = line.replace(/\/\/.*$/, '').trim();
      if (!line) continue;
      let m = /^\.\.\.(\w+),?$/.exec(line);
      if (m) {
        Object.assign(out, table(src, m[1]));
        continue;
      }
      m = /^(?:'([^']+)'|([\w$]+)):\s*(?:'([^']*)'|(true|false)),?$/.exec(line);
      if (!m) throw new Error(`${SPEC} ${name}: a line the port cannot read: ${line}`);
      out[m[1] || m[2]] = m[3] !== undefined ? m[3] : m[4] === 'true';
    }
    return out;
  }

  let spec;
  try {
    const [specSource, knownSource, configSource] = await Promise.all([source(SPEC), source(KNOWN_ISSUES), source(CONFIG)]);
    Object.assign(Driver.config, Driver.readCypressConfig(configSource));
    spec = {
      source: specSource,
      frameworkFolders: table(specSource, 'frameworkFolders'), // spec.cy.js:38-52
      noLocalStorageCheck: table(specSource, 'noLocalStorageCheck'), // :59-81
      noLocalStorageSpyCheck: table(specSource, 'noLocalStorageSpyCheck'), // :86-90
      noAppStartCheck: table(specSource, 'noAppStartCheck'), // :92-94
      badLocalStorageFormat: table(specSource, 'badLocalStorageFormat'), // :107-109
      blurAfterType: table(specSource, 'blurAfterType'), // :113-120
      usesIDSelectors: table(specSource, 'usesIDSelectors'), // :132-134
      // tests/knownIssues.js: module.exports = [ '<entry>', ... ]
      knownIssues: knownSource.split('\n').map((l) => /^\s*'([^']*)',?\s*$/.exec(l)).filter(Boolean).map((m) => m[1]),
    };
  } catch (e) {
    QUnit.onUncaughtException(new Error('the port could not read the spec: ' + e.message));
    QUnit.start();
    return;
  }

  const framework = new URLSearchParams(location.search).get('framework');
  if (!framework || !/^[A-Za-z0-9_-][A-Za-z0-9_.-]*(\/[A-Za-z0-9_-][A-Za-z0-9_.-]*)*$/.test(framework)) {
    QUnit.onUncaughtException(new Error('name the app: ?framework=<name> (a folder of examples/, or a path below it)'));
    QUnit.start();
    return;
  }
  document.title = `TodoMVC - ${framework} (Crane's port of the app spec)`;

  // spec.cy.js:53
  const getExampleFolder = (fw) => spec.frameworkFolders[fw] || fw;
  const { noLocalStorageCheck, noLocalStorageSpyCheck, badLocalStorageFormat, blurAfterType, usesIDSelectors } = spec;

  // spec.cy.js:124-129
  const safeBlur = (el) => {
    if (blurAfterType[framework]) {
      const event = new (el.ownerDocument.defaultView.Event)('blur', { force: true });
      el.dispatchEvent(event);
    }
  };

  // spec.cy.js:138-180: a test whose lower-cased title ends an entry of
  // tests/knownIssues.js for this framework is registered as skipped.
  const fw = framework.toLowerCase();
  const removeCommas = (s) => s.replace(/,/g, '');
  const issueNames = spec.knownIssues
    .map((s) => s.toLowerCase())
    .filter((name) => name.includes(`- ${fw},`) || name.startsWith(`${fw},`))
    .map(removeCommas);
  const knownIssue = (name) => issueNames.find((issueName) => issueName.endsWith(name.toLowerCase()));

  // The localStorage checks, spec.cy.js:182-318: each polls the app's
  // storage until it holds what is looked for (Cypress's cy.then: 4 s).
  async function pollStorage(what, ok) {
    const deadline = performance.now() + 4000;
    for (;;) {
      const storage = cy.window().localStorage;
      if (storage.length >= 1 && Object.keys(storage).some((key) => ok(storage.getItem(key)))) break;
      if (performance.now() > deadline) {
        QUnit.config.current.assert.pushResult({ result: false, actual: JSON.stringify({ ...storage }), expected: what, message: `localStorage: ${what}` });
        throw new Driver.CommandError(`localStorage: ${what}`);
      }
      await Driver.sleep(0);
    }
  }
  const parseItems = (text) => {
    try {
      return JSON.parse(text);
    } catch (e) {
      return undefined;
    }
  };
  // :183-210
  const checkTodosInLocalStorage = async (presentText, force) => {
    if (noLocalStorageCheck[framework] && !force) return;
    await pollStorage(`an item holding "${presentText}"`, (text) => text.includes(presentText));
  };
  // :212-242
  const checkCompletedKeywordInLocalStorage = async () => {
    if (badLocalStorageFormat[framework]) return;
    const variants = ['complete', 'isComplete'];
    await pollStorage('a completed item', (text) => variants.some((variant) => text.includes(variant)));
  };
  // :244-277
  const checkNumberOfTodosInLocalStorage = async (n) => {
    if (noLocalStorageCheck[framework]) return;
    await pollStorage(`${n} todo items`, (text) => { const items = parseItems(text); return !!items && items.length === n; });
  };
  // :279-318
  const checkNumberOfCompletedTodosInLocalStorage = async (n) => {
    if (noLocalStorageCheck[framework]) return;
    await pollStorage(`${n} completed items`, (text) => {
      const items = parseItems(text);
      if (!items || items.length < n) return false;
      const completed = items.filter((i) => i && i.completed === true).concat(items.filter((i) => i && i.complete === true));
      return completed.length === n;
    });
  };

  // spec.cy.js:337-339
  const TODO_ITEM_ONE = 'buy some cheese';
  const TODO_ITEM_TWO = 'feed the cat';
  const TODO_ITEM_THREE = 'book a doctors appointment';

  // :345-375
  const idSelectors = {
    newTodo: '#new-todo',
    todoList: '#todo-list',
    todoItems: '#todo-list li',
    todoItemsVisible: '#todo-list li:visible',
    count: 'span#todo-count',
    main: '#main',
    footer: '#footer',
    toggleAll: '#toggle-all',
    clearCompleted: '#clear-completed',
    filters: '#filters',
    filterItems: '#filters li a',
  };
  const classSelectors = {
    newTodo: '.new-todo',
    todoList: '.todo-list',
    todoItems: '.todo-list li',
    todoItemsVisible: '.todo-list li:visible',
    count: 'span.todo-count',
    main: '.main',
    footer: '.footer',
    toggleAll: '.toggle-all',
    clearCompleted: '.clear-completed',
    filters: '.filters',
    filterItems: '.filters li a',
  };
  let useIds;
  let selectors;
  const setSelectors = (ids) => {
    useIds = ids;
    selectors = useIds ? idSelectors : classSelectors;
  };

  // cypress/support/commands.js:1-88 (createTodoCommands)
  let commandSelectors;
  function createTodoCommands(idSelectorsOn) {
    commandSelectors = {
      newTodo: idSelectorsOn ? '#new-todo' : '.new-todo',
      todoList: idSelectorsOn ? '#todo-list' : '.todo-list',
      todoItems: idSelectorsOn ? '#todo-list li' : '.todo-list li',
    };
  }
  // commands.js:6-62
  async function createDefaultTodos() {
    const s = commandSelectors;
    await cy.get(s.newTodo).type(`${TODO_ITEM_ONE}{enter}`);
    await cy.get(s.todoItems).should('have.length', 1);
    await cy.get(s.newTodo).type(`${TODO_ITEM_TWO}{enter}`);
    await cy.get(s.todoItems).should('have.length', 2);
    await cy.get(s.newTodo).type(`${TODO_ITEM_THREE}{enter}`);
    await cy.get(s.todoItems).should('have.length', 3);
    const listItems = await cy.get(s.todoItems + ':visible').resolve();
    return cy.wrap(listItems, 'createDefaultTodos()');
  }
  // commands.js:64-87
  async function createTodo(todo) {
    const s = commandSelectors;
    await cy.get(s.newTodo).type(`${todo}{enter}`);
    const li = await cy.get(s.todoList).contains('li', todo.trim()).resolve();
    return cy.wrap(li, `createTodo('${todo}')`);
  }

  // :377
  const visibleTodos = () => cy.get(selectors.todoItemsVisible);
  // :379-380
  const hasNoItems = () => cy.get(selectors.todoItems).should('have.length', 0);
  // :382-389 checkItemSaved, and its spy (:413-430). Cypress spies on the
  // app window's Storage.prototype.setItem from cy.visit's onBeforeLoad,
  // before the app's scripts run; an in-page harness has no such hook, so
  // the port installs the same spy (cy.spy: Cypress 15.14.2's, Sinon 8.1.1's)
  // when the app has loaded (beforeEach, below): every check follows an
  // action of its test, after the load. The check is the spec's own: the
  // spy called (retried for Cypress's command timeout), then
  // invoke('reset') - which fails in Cypress 15.14.2, whose spies have
  // resetHistory() and no reset(), and so fails here too.
  let localStorageSetItem = null;
  const spyOnSetItem = () => {
    localStorageSetItem = null;
    if (noLocalStorageSpyCheck[framework]) return;
    localStorageSetItem = cy.spy(cy.window().Storage.prototype, 'setItem');
  };
  const checkItemSaved = async () => {
    if (noLocalStorageSpyCheck[framework]) return;
    await cy.wrap([localStorageSetItem], 'cy.wrap(localStorageSetItem)').should('have.been.called');
    await cy.wrap([localStorageSetItem], 'cy.wrap(localStorageSetItem)').invoke('reset');
  };

  // Shadow-piercing lookup, spec.cy.js:487-495.
  const findDeep = (root, selector) => {
    if (!root) return false;
    if (root.querySelector && root.querySelector(selector)) return true;
    const candidates = (root.querySelectorAll && root.querySelectorAll('*')) || [];
    for (const el of candidates) {
      if (el.shadowRoot && findDeep(el.shadowRoot, selector)) return true;
    }
    return false;
  };

  // Mocha's rule for a failed hook (Driver.HookSkips): the spec runs under
  // Cypress's Mocha, where a failed beforeEach or afterEach fails its test
  // and skips the rest of the suite that declared the hook. Every hook below
  // is declared in the describe (null) or in its context.
  const hookSkips = new Driver.HookSkips();
  const current = () => QUnit.config.current;
  function hook(declaredIn, fn) {
    return async function (assert) {
      if (hookSkips.skips(current().module.name)) return;
      try {
        await fn.call(this, assert);
      } catch (e) {
        hookSkips.failed(declaredIn, current().testId);
        throw e;
      }
    };
  }

  // The suite: describe(title) at spec.cy.js:335, its hooks at :394-530.
  QUnit.hooks.beforeEach(hook(null, async function () {
    Driver.reset();
    // :410-412 cy.visit('/' + folder) under baseUrl .../examples/.
    // :413-476 the onBeforeLoad hooks (the localStorage.setItem spy and the
    // addEventListener patch that marks the app started) run in the app's
    // window before its scripts in Cypress; an in-page harness cannot, so
    // the app counts as started at the spec's next step, its heading
    // visible and its input found.
    await cy.visit('/examples/' + getExampleFolder(framework));
    spyOnSetItem();
    // :482
    await cy.contains('h1', /^todos$/i).should('be.visible');
    // :496-517
    const doc = cy.document();
    if (framework in usesIDSelectors) {
      setSelectors(usesIDSelectors[framework]);
      createTodoCommands(usesIDSelectors[framework]);
    } else if (findDeep(doc, 'input#new-todo') && findDeep(doc, 'input.new-todo')) {
      throw new Error('Cannot determine what kind of selectors this app uses. Add it to usesIDSelectors.');
    } else if (findDeep(doc, 'input#new-todo')) {
      setSelectors(true);
      createTodoCommands(true);
    } else if (findDeep(doc, 'input.new-todo')) {
      setSelectors(false);
      createTodoCommands(false);
    } else {
      throw new Error('Cannot determine what kind of selectors this app uses.');
    }
  }));
  // :520-524
  QUnit.hooks.beforeEach(hook(null, async function () {
    await hasNoItems();
  }));
  // :526-530 reset the spy's test id: nothing to reset here. With
  // ?prove=layout, every visibility answer the test asked must be the one
  // Cypress's layout clauses give too (driver.js).
  QUnit.hooks.afterEach(function (assert) {
    if (Driver.proveLayout) assert.deepEqual(Driver.takeLayoutDisagreements(), [], 'Cypress\'s layout clauses change no visibility answer of this test');
  });

  const registered = [];
  // it(name, fn): skipped when the spec skips it for this framework; not run
  // after a failed hook of its suite (Mocha), which Cypress counts as
  // skipped and the matrix as not passed.
  function it(context, name, fn, specSkips) {
    registered.push([context, name]);
    if (knownIssue(name) || specSkips) QUnit.skip(name);
    else QUnit.test(name, async function (assert) {
      if (hookSkips.skips(context)) {
        if (hookSkips.test !== current().testId) assert.pushResult({ result: false, actual: 'not run', expected: 'run', message: 'Cypress does not run it: a hook failed earlier in its suite, and Mocha skips the rest of that suite' });
        return;
      }
      await fn.call(this, assert);
    });
  }

  // :532-544
  QUnit.module('When page is initially opened', function () {
    it('When page is initially opened', 'should focus on the todo input field', async function () {
      if (useIds) {
        await cy.focused().should('have.id', 'new-todo');
      } else {
        await cy.focused().should('have.class', 'new-todo');
      }
    });
  });

  // :546-558
  QUnit.module('No Todos', function () {
    it('No Todos', 'starts with nothing', async function () {
      await hasNoItems();
    });

    it('No Todos', 'should hide #main and #footer', async function () {
      await cy.get(selectors.todoItems).should('not.exist');
      await cy.get(selectors.main).should('not.be.visible');
      await cy.get(selectors.footer).should('not.be.visible');
    });
  });

  // :560-638
  QUnit.module('New Todo', function () {
    it('New Todo', 'should allow me to add todo items', async function () {
      await cy.get(selectors.newTodo).type(`${TODO_ITEM_ONE}{enter}`);
      await checkItemSaved();
      await cy.get(selectors.todoItems).eq(0).find('label').should('contain', TODO_ITEM_ONE);
      await cy.get(selectors.newTodo).type(`${TODO_ITEM_TWO}{enter}`);
      await checkItemSaved();
      await cy.get(selectors.todoItems).eq(1).find('label').should('contain', TODO_ITEM_TWO);
      await checkNumberOfTodosInLocalStorage(2);
    });

    it('New Todo', 'should clear text input field when an item is added', async function () {
      await cy.get(selectors.newTodo).type(`${TODO_ITEM_ONE}{enter}`);
      await cy.get(selectors.newTodo).should('have.text', '');
      await checkNumberOfTodosInLocalStorage(1);
    });

    it('New Todo', 'should append new items to the bottom of the list', async function () {
      (await createDefaultTodos()).as('todos');
      await cy.get(selectors.count).contains('3').resolve();
      await cy.get('@todos').eq(0).find('label').should('contain', TODO_ITEM_ONE);
      await cy.get('@todos').eq(1).find('label').should('contain', TODO_ITEM_TWO);
      await cy.get('@todos').eq(2).find('label').should('contain', TODO_ITEM_THREE);
      await checkNumberOfTodosInLocalStorage(3);
    });

    it('New Todo', 'should trim text input', async function () {
      await createTodo(`    ${TODO_ITEM_ONE}    `);
      await cy.get(selectors.todoItems).eq(0).find('label').should('have.text', TODO_ITEM_ONE);
      await checkNumberOfTodosInLocalStorage(1);
    });

    it('New Todo', 'should show #main and #footer when items added', async function () {
      await createTodo(TODO_ITEM_ONE);
      await cy.get(selectors.main).should('be.visible');
      await cy.get(selectors.footer).should('be.visible');
      await checkNumberOfTodosInLocalStorage(1);
    });
  });

  // :640-722
  QUnit.module('Mark all as completed', function (hooks) {
    hooks.beforeEach(hook('Mark all as completed', async function () {
      (await createDefaultTodos()).as('todos');
      await checkNumberOfTodosInLocalStorage(3);
      await checkItemSaved();
    }));
    hooks.afterEach(hook('Mark all as completed', async function () {
      await checkNumberOfTodosInLocalStorage(3);
    }));

    it('Mark all as completed', 'should allow me to mark all items as completed', async function () {
      await cy.get(selectors.toggleAll).check({ force: true });
      await checkItemSaved();
      await cy.get('@todos').eq(0).should('have.class', 'completed');
      await cy.get('@todos').eq(1).should('have.class', 'completed');
      await cy.get('@todos').eq(2).should('have.class', 'completed');
      await checkNumberOfCompletedTodosInLocalStorage(3);
    });

    it('Mark all as completed', 'should allow me to clear the complete state of all items', async function () {
      await cy.get(selectors.toggleAll).check({ force: true });
      await checkItemSaved();
      await cy.get(selectors.toggleAll).uncheck({ force: true });
      await checkItemSaved();
      await cy.get('@todos').eq(0).should('not.have.class', 'completed');
      await cy.get('@todos').eq(1).should('not.have.class', 'completed');
      await cy.get('@todos').eq(2).should('not.have.class', 'completed');
      await checkNumberOfCompletedTodosInLocalStorage(0);
    });

    it('Mark all as completed', 'complete all checkbox should update state when items are completed / cleared', async function () {
      await cy.get(selectors.toggleAll).check({ force: true });
      await checkItemSaved();
      await cy.get(selectors.toggleAll).should('be.checked');
      cy.get(selectors.todoItems).eq(0).as('firstTodo');
      await cy.get('@firstTodo').find('.toggle').uncheck({ force: true });
      await checkItemSaved();
      await cy.get(selectors.toggleAll).should('not.be.checked');
      await cy.get('@firstTodo').find('.toggle').check({ force: true });
      await checkItemSaved();
      await checkNumberOfCompletedTodosInLocalStorage(3);
      await cy.get(selectors.toggleAll).should('be.checked');
    });
  });

  // :724-792
  QUnit.module('Item', function () {
    it('Item', 'should allow me to mark items as complete', async function () {
      (await createTodo(TODO_ITEM_ONE)).as('firstTodo');
      (await createTodo(TODO_ITEM_TWO)).as('secondTodo');
      await cy.get('@firstTodo').find('.toggle').check();
      await cy.get('@firstTodo').should('have.class', 'completed');
      await cy.get('@secondTodo').should('not.have.class', 'completed');
      await cy.get('@secondTodo').find('.toggle').check();
      await cy.get('@firstTodo').should('have.class', 'completed');
      await cy.get('@secondTodo').should('have.class', 'completed');
      await checkNumberOfCompletedTodosInLocalStorage(2);
    });

    it('Item', 'should allow me to un-mark items as complete', async function () {
      (await createTodo(TODO_ITEM_ONE)).as('firstTodo');
      (await createTodo(TODO_ITEM_TWO)).as('secondTodo');
      await cy.get('@firstTodo').find('.toggle').check();
      await cy.get('@firstTodo').should('have.class', 'completed');
      await cy.get('@secondTodo').should('not.have.class', 'completed');
      await checkNumberOfCompletedTodosInLocalStorage(1);
      await cy.get('@firstTodo').find('.toggle').uncheck();
      await cy.get('@firstTodo').should('not.have.class', 'completed');
      await cy.get('@secondTodo').should('not.have.class', 'completed');
      await checkNumberOfCompletedTodosInLocalStorage(0);
    });

    it('Item', 'should allow me to edit an item', async function () {
      await createDefaultTodos();
      await checkTodosInLocalStorage(TODO_ITEM_TWO);
      await visibleTodos().eq(1).find('label').dblclick();
      const edit = await visibleTodos().eq(1).find('.edit').should('have.value', TODO_ITEM_TWO);
      const cleared = await edit.clear();
      const typed = await cleared.type('buy some sausages{enter}');
      safeBlur(typed.subject()[0]);
      await visibleTodos().eq(0).should('contain', TODO_ITEM_ONE);
      await visibleTodos().eq(1).should('contain', 'buy some sausages');
      await visibleTodos().eq(2).should('contain', TODO_ITEM_THREE);
      await checkTodosInLocalStorage('buy some sausages');
    });
  });

  // :794-878
  QUnit.module('Editing', function (hooks) {
    hooks.beforeEach(hook('Editing', async function () {
      (await createDefaultTodos()).as('todos');
      await checkNumberOfTodosInLocalStorage(3);
    }));

    it('Editing', 'should hide other controls when editing', async function () {
      await cy.get('@todos').eq(1).find('label').dblclick();
      await cy.get(selectors.todoItems).eq(1).find('.toggle').should('not.be.visible');
      await cy.get(selectors.todoItems).eq(1).find('label').should('not.be.visible');
      await checkNumberOfTodosInLocalStorage(3);
    });

    it('Editing', 'should save edits on blur', async function () {
      await cy.get('@todos').eq(1).find('label').dblclick();
      const edit = cy.get(selectors.todoItems).eq(1).find('.edit');
      const cleared = await edit.clear();
      const typed = await cleared.type('buy some sausages');
      await typed.blur();
      await visibleTodos().eq(0).should('contain', TODO_ITEM_ONE);
      await visibleTodos().eq(1).should('contain', 'buy some sausages');
      await visibleTodos().eq(2).should('contain', TODO_ITEM_THREE);
      await checkTodosInLocalStorage('buy some sausages');
    });

    it('Editing', 'should trim entered text', async function () {
      await cy.get('@todos').eq(1).find('label').dblclick();
      await checkTodosInLocalStorage(TODO_ITEM_TWO);
      const typed = await cy.get(selectors.todoItems).eq(1).find('.edit').type('{selectall}{backspace}    buy some sausages    {enter}');
      safeBlur(typed.subject()[0]);
      await visibleTodos().eq(0).should('contain', TODO_ITEM_ONE);
      await visibleTodos().eq(1).should('contain', 'buy some sausages');
      await visibleTodos().eq(2).should('contain', TODO_ITEM_THREE);
      await checkTodosInLocalStorage('buy some sausages');
    });

    it('Editing', 'should remove the item if an empty text string was entered', async function () {
      await cy.get('@todos').eq(1).find('label').dblclick();
      const cleared = await cy.get(selectors.todoItems).eq(1).find('.edit').clear();
      const typed = await cleared.type('{enter}');
      safeBlur(typed.subject()[0]);
      await visibleTodos().should('have.length', 2);
      await checkNumberOfTodosInLocalStorage(2);
    });

    it('Editing', 'should cancel edits on escape', async function () {
      await visibleTodos().eq(1).find('label').dblclick();
      await cy.get(selectors.todoItems).eq(1).find('.edit').type('{selectall}{backspace}foo{esc}');
      await visibleTodos().eq(0).should('contain', TODO_ITEM_ONE);
      await visibleTodos().eq(1).should('contain', TODO_ITEM_TWO);
      await visibleTodos().eq(2).should('contain', TODO_ITEM_THREE);
      await checkNumberOfTodosInLocalStorage(3);
    });
  });

  // :880-888
  QUnit.module('Counter', function () {
    it('Counter', 'should display the current number of todo items', async function () {
      await createTodo(TODO_ITEM_ONE);
      await cy.get(selectors.count).contains('1').resolve();
      await createTodo(TODO_ITEM_TWO);
      await cy.get(selectors.count).contains('2').resolve();
      await checkNumberOfTodosInLocalStorage(2);
    });
  });

  // :890-918
  QUnit.module('Clear completed button', function (hooks) {
    hooks.beforeEach(hook('Clear completed button', async function () {
      (await createDefaultTodos()).as('todos');
    }));

    it('Clear completed button', 'should display the correct text', async function () {
      await cy.get('@todos').eq(0).find('.toggle').check();
      await cy.get(selectors.clearCompleted).contains('Clear completed').resolve();
    });

    it('Clear completed button', 'should remove completed items when clicked', async function () {
      await cy.get('@todos').eq(1).find('.toggle').check();
      await cy.get(selectors.clearCompleted).click();
      await cy.get(selectors.todoItems).should('have.length', 2);
      await cy.get(selectors.todoItems).eq(0).should('contain', TODO_ITEM_ONE);
      await cy.get(selectors.todoItems).eq(1).should('contain', TODO_ITEM_THREE);
    });

    it('Clear completed button', 'should be hidden when there are no items that are completed', async function () {
      await cy.get('@todos').eq(1).find('.toggle').check();
      const button = await cy.get(selectors.clearCompleted).should('be.visible');
      await button.click();
      await cy.get(selectors.clearCompleted).should('not.be.visible');
    });
  });

  // :920-959: skipped for apps that keep nothing in localStorage (:927-929).
  QUnit.module('Persistence', function () {
    it('Persistence', 'should persist its data', async function () {
      async function testState() {
        await cy.get('@firstTodo').should('contain', TODO_ITEM_ONE);
        await cy.get('@firstTodo').should('have.class', 'completed');
        await cy.get('@secondTodo').should('contain', TODO_ITEM_TWO);
        await cy.get('@secondTodo').should('not.have.class', 'completed');
      }
      (await createTodo(TODO_ITEM_ONE)).as('firstTodo');
      (await createTodo(TODO_ITEM_TWO)).as('secondTodo');
      await cy.get('@firstTodo').find('.toggle').check();
      await testState();
      await checkTodosInLocalStorage(TODO_ITEM_ONE, true);
      await checkCompletedKeywordInLocalStorage();
      await checkNumberOfCompletedTodosInLocalStorage(1);
      // :955-957. The aliases are the commands' results (createTodo ends in
      // cy.then), which Cypress 12+ does not requery: after cy.reload()
      // their elements are gone with the old page, and testState fails as
      // in Cypress (the subject is no longer attached to the DOM).
      await cy.reload();
      await testState();
    }, !!noLocalStorageCheck[framework]);
  });

  // :961-1035
  QUnit.module('Routing', function (hooks) {
    hooks.beforeEach(hook('Routing', async function () {
      (await createDefaultTodos()).as('todos');
      await checkTodosInLocalStorage(TODO_ITEM_ONE);
    }));

    it('Routing', 'should allow me to display active items', async function () {
      await cy.get('@todos').eq(1).find('.toggle').check();
      await checkNumberOfCompletedTodosInLocalStorage(1);
      await cy.contains(selectors.filterItems, 'Active').click();
      await visibleTodos().should('have.length', 2);
      await visibleTodos().eq(0).should('contain', TODO_ITEM_ONE);
      await visibleTodos().eq(1).should('contain', TODO_ITEM_THREE);
    });

    it('Routing', 'should respect the back button', async function () {
      await cy.get('@todos').eq(1).find('.toggle').check();
      await checkNumberOfCompletedTodosInLocalStorage(1);
      await cy.contains(selectors.filterItems, 'All').click();
      await visibleTodos().should('have.length', 3);
      await cy.contains(selectors.filterItems, 'Active').click();
      await cy.contains(selectors.filterItems, 'Completed').click();
      await visibleTodos().should('have.length', 1);
      await cy.go('back');
      await visibleTodos().should('have.length', 2);
      await cy.go('back');
      await visibleTodos().should('have.length', 3);
    });

    it('Routing', 'should allow me to display completed items', async function () {
      await visibleTodos().eq(1).find('.toggle').check();
      await checkNumberOfCompletedTodosInLocalStorage(1);
      await cy.get(selectors.filters).contains('Completed').click();
      await visibleTodos().should('have.length', 1);
    });

    it('Routing', 'should allow me to display all items', async function () {
      await visibleTodos().eq(1).find('.toggle').check();
      await checkNumberOfCompletedTodosInLocalStorage(1);
      await cy.get(selectors.filters).contains('Active').click();
      await cy.get(selectors.filters).contains('Completed').click();
      await cy.get(selectors.filters).contains('All').click();
      await visibleTodos().should('have.length', 3);
    });

    it('Routing', 'should highlight the currently applied filter', async function () {
      await cy.contains(selectors.filterItems, 'All').should('have.class', 'selected');
      await cy.contains(selectors.filterItems, 'Active').click();
      await cy.contains(selectors.filterItems, 'Active').should('have.class', 'selected');
      await cy.contains(selectors.filterItems, 'Completed').click();
      await cy.contains(selectors.filterItems, 'Completed').should('have.class', 'selected');
    });
  });

  // The port against the spec: the same contexts and tests, in its order.
  const inSpec = [];
  let context = null;
  for (const m of spec.source.matchAll(/^\s*(context|it)\('([^']+)'/gm)) {
    if (m[1] === 'context') context = m[2];
    else inSpec.push([context, m[2]]);
  }
  const a = JSON.stringify(inSpec);
  const b = JSON.stringify(registered);
  if (a !== b) QUnit.onUncaughtException(new Error(`the port's tests are not the spec's: spec ${a}; port ${b}`));
  QUnit.start();
})();
