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
// The app: ?framework=<name> (react, vue, svelte, angular), at
// '/examples/' + the spec's folder for it, served from the tree's root as
// the project's server serves it (cypress.config.js: baseUrl
// http://localhost:8000/examples/; tests/server.js: express.static(root)).
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
    const [specSource, knownSource] = await Promise.all([source(SPEC), source(KNOWN_ISSUES)]);
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
  if (!framework) {
    QUnit.onUncaughtException(new Error('name the app: ?framework=<name> (a folder of examples/)'));
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
  // :382-389: the spy is Cypress's, set in cy.visit's onBeforeLoad, before
  // the app's scripts run; an in-page harness has no such hook. Every app
  // of the matrix is in noLocalStorageSpyCheck, so it is never reached.
  const checkItemSaved = () => {
    if (noLocalStorageSpyCheck[framework]) return;
    throw new Error(`checkItemSaved for ${framework}: the localStorage.setItem spy needs Cypress's onBeforeLoad (not ported)`);
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

  // The suite: describe(title) at spec.cy.js:335, its hooks at :394-530.
  QUnit.hooks.beforeEach(async function () {
    Driver.reset();
    // :410-412 cy.visit('/' + folder) under baseUrl .../examples/.
    // :413-476 the onBeforeLoad hooks (the localStorage.setItem spy and the
    // addEventListener patch that marks the app started) run in the app's
    // window before its scripts in Cypress; an in-page harness cannot, so
    // the app counts as started at the spec's next step, its heading
    // visible and its input found.
    await cy.visit('/examples/' + getExampleFolder(framework));
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
  });
  // :520-524
  QUnit.hooks.beforeEach(async function () {
    await hasNoItems();
  });
  // :526-530 reset the spy's test id: nothing to reset here. With
  // ?prove=layout, every visibility answer the test asked must be the one
  // Cypress's layout clauses give too (driver.js).
  QUnit.hooks.afterEach(function (assert) {
    if (Driver.proveLayout) assert.deepEqual(Driver.takeLayoutDisagreements(), [], 'Cypress\'s layout clauses change no visibility answer of this test');
  });

  const registered = [];
  // it(name, fn): skipped when the spec skips it for this framework.
  function it(context, name, fn, specSkips) {
    registered.push([context, name]);
    if (knownIssue(name) || specSkips) QUnit.skip(name);
    else QUnit.test(name, fn);
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
      checkItemSaved();
      await cy.get(selectors.todoItems).eq(0).find('label').should('contain', TODO_ITEM_ONE);
      await cy.get(selectors.newTodo).type(`${TODO_ITEM_TWO}{enter}`);
      checkItemSaved();
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
    hooks.beforeEach(async function () {
      (await createDefaultTodos()).as('todos');
      await checkNumberOfTodosInLocalStorage(3);
      checkItemSaved();
    });
    hooks.afterEach(async function () {
      await checkNumberOfTodosInLocalStorage(3);
    });

    it('Mark all as completed', 'should allow me to mark all items as completed', async function () {
      await cy.get(selectors.toggleAll).check({ force: true });
      checkItemSaved();
      await cy.get('@todos').eq(0).should('have.class', 'completed');
      await cy.get('@todos').eq(1).should('have.class', 'completed');
      await cy.get('@todos').eq(2).should('have.class', 'completed');
      await checkNumberOfCompletedTodosInLocalStorage(3);
    });

    it('Mark all as completed', 'should allow me to clear the complete state of all items', async function () {
      await cy.get(selectors.toggleAll).check({ force: true });
      checkItemSaved();
      await cy.get(selectors.toggleAll).uncheck({ force: true });
      checkItemSaved();
      await cy.get('@todos').eq(0).should('not.have.class', 'completed');
      await cy.get('@todos').eq(1).should('not.have.class', 'completed');
      await cy.get('@todos').eq(2).should('not.have.class', 'completed');
      await checkNumberOfCompletedTodosInLocalStorage(0);
    });

    it('Mark all as completed', 'complete all checkbox should update state when items are completed / cleared', async function () {
      await cy.get(selectors.toggleAll).check({ force: true });
      checkItemSaved();
      await cy.get(selectors.toggleAll).should('be.checked');
      cy.get(selectors.todoItems).eq(0).as('firstTodo');
      await cy.get('@firstTodo').find('.toggle').uncheck({ force: true });
      checkItemSaved();
      await cy.get(selectors.toggleAll).should('not.be.checked');
      await cy.get('@firstTodo').find('.toggle').check({ force: true });
      checkItemSaved();
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
      safeBlur((await typed.resolve())[0]);
      await visibleTodos().eq(0).should('contain', TODO_ITEM_ONE);
      await visibleTodos().eq(1).should('contain', 'buy some sausages');
      await visibleTodos().eq(2).should('contain', TODO_ITEM_THREE);
      await checkTodosInLocalStorage('buy some sausages');
    });
  });

  // :794-878
  QUnit.module('Editing', function (hooks) {
    hooks.beforeEach(async function () {
      (await createDefaultTodos()).as('todos');
      await checkNumberOfTodosInLocalStorage(3);
    });

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
      safeBlur((await typed.resolve())[0]);
      await visibleTodos().eq(0).should('contain', TODO_ITEM_ONE);
      await visibleTodos().eq(1).should('contain', 'buy some sausages');
      await visibleTodos().eq(2).should('contain', TODO_ITEM_THREE);
      await checkTodosInLocalStorage('buy some sausages');
    });

    it('Editing', 'should remove the item if an empty text string was entered', async function () {
      await cy.get('@todos').eq(1).find('label').dblclick();
      const cleared = await cy.get(selectors.todoItems).eq(1).find('.edit').clear();
      const typed = await cleared.type('{enter}');
      safeBlur((await typed.resolve())[0]);
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
    hooks.beforeEach(async function () {
      (await createDefaultTodos()).as('todos');
    });

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
      // cy.reload() re-queries the aliases' queries in Cypress 12+; these
      // are the commands' results, found again by their text.
      await cy.reload();
      cy.get(selectors.todoList).contains('li', TODO_ITEM_ONE).as('firstTodo');
      cy.get(selectors.todoList).contains('li', TODO_ITEM_TWO).as('secondTodo');
      await testState();
    }, !!noLocalStorageCheck[framework]);
  });

  // :961-1035
  QUnit.module('Routing', function (hooks) {
    hooks.beforeEach(async function () {
      (await createDefaultTodos()).as('todos');
      await checkTodosInLocalStorage(TODO_ITEM_ONE);
    });

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
