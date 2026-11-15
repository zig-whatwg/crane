//! Lane ev1 (the Event's memory, step 2): what script sees of an event is
//! unchanged by where its bytes went - an event's type, kept without a copy
//! when it is a type a specification names (dom.event_construction's
//! `ownedType`); a CustomEvent's detail, kept by its wrapper now that the
//! CustomEvent has no block of its own; the currentTarget, which is the
//! dispatch's to keep and null at every other time; and the relatedTarget,
//! kept through a record made only for an event that has one.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const Page = h.Page;
const onFreshThread = h.onFreshThread;

const prelude =
    \\globalThis.failures = [];
    \\globalThis.assert = (ok, what) => { if (!ok) failures.push(what); };
    \\globalThis.done = () => { if (failures.length) throw new Error('ev1: ' + failures.join('; ')); };
    \\window.addEventListener('error', ev => {
    \\  if (!String(ev.message).includes('deliberate')) failures.push('uncaught: ' + ev.message);
    \\  ev.preventDefault();
    \\});
;

fn eventTypes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\// A listed type, an unlisted one, another case of a listed one, the
        \\// empty string, and a type made at run time (its bytes are the
        \\// argument conversion's, gone when the constructor returns).
        \\const made = ['cl', 'ick'].join('');
        \\const events = [new Event('click'), new Event('ev1-own-type'), new Event('Click'), new Event(''), new Event(made),
        \\  new MouseEvent('click'), new CustomEvent('load'), new CustomEvent('ev1-own-type')];
        \\const want = ['click', 'ev1-own-type', 'Click', '', 'click', 'click', 'load', 'ev1-own-type'];
        \\TestUtils.gc();
        \\events.forEach((e, i) => assert(e.type === want[i], 'type ' + i + ' is ' + JSON.stringify(e.type)));
        \\
        \\// initEvent replaces the type, from a listed type to an unlisted one
        \\// and back, and listeners are matched on the type it has.
        \\const e = new Event('click');
        \\let heard = [];
        \\for (const type of ['click', 'ev1-own-type', 'keydown']) document.addEventListener(type, ev => heard.push(ev.type));
        \\document.dispatchEvent(e);
        \\e.initEvent('ev1-own-type');
        \\assert(e.type === 'ev1-own-type', 'after initEvent to an unlisted type');
        \\document.dispatchEvent(e);
        \\e.initEvent('keydown', true, true);
        \\assert(e.type === 'keydown' && e.bubbles && e.cancelable, 'after initEvent to a listed type');
        \\document.dispatchEvent(e);
        \\assert(heard.join() === 'click,ev1-own-type,keydown', 'heard ' + heard.join());
        \\
        \\// createEvent makes an event with the empty type; initEvent names it.
        \\const legacy = document.createEvent('Event');
        \\assert(legacy.type === '', 'createEvent type');
        \\legacy.initEvent('click', true, false);
        \\assert(legacy.type === 'click', 'createEvent + initEvent');
        \\
        \\// Many events of one listed type, made and dropped and kept.
        \\const kept = [];
        \\for (let i = 0; i < 2000; i++) { const x = new Event(i % 2 ? 'input' : 'ev1-' + i); if (i % 100 === 0) kept.push(x); }
        \\TestUtils.gc();
        \\kept.forEach((x, i) => assert(x.type === 'ev1-' + i * 100, 'kept ' + i + ': ' + x.type));
        \\done();
    );
    try page.collect();
}

test "an event's type reads the same whether the engine lists it or the event copied it" {
    try onFreshThread(eventTypes);
}

fn customEvents() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\const detail = { n: 1 };
        \\const e = new CustomEvent('data', { detail, bubbles: true });
        \\assert(e.detail === detail && e.bubbles && e.type === 'data', 'the constructor');
        \\assert(new CustomEvent('data').detail === null, 'detail defaults to null');
        \\assert(new CustomEvent('data', { detail: undefined }).detail === null, 'an undefined member is the default');
        \\assert(new CustomEvent('data', { detail: 'text' }).detail === 'text', 'a string detail');
        \\assert(e instanceof Event && e instanceof CustomEvent, 'instanceof');
        \\
        \\// It dispatches (the Event state is made with it), and its detail
        \\// reaches the listener.
        \\let got = null, path = 0;
        \\document.body.addEventListener('data', ev => { got = ev.detail; path = ev.composedPath().length; });
        \\assert(document.body.dispatchEvent(e) === true, 'dispatchEvent');
        \\assert(got === detail && path === 4, 'the listener saw the detail and a path of ' + path);
        \\
        \\// initCustomEvent replaces the detail; not while it is dispatched.
        \\e.initCustomEvent('other', false, false, 42);
        \\assert(e.type === 'other' && e.detail === 42 && !e.bubbles, 'initCustomEvent');
        \\document.body.addEventListener('other', ev => { ev.initCustomEvent('never', true, true, 'never'); });
        \\document.body.dispatchEvent(e);
        \\assert(e.type === 'other' && e.detail === 42, 'initCustomEvent during dispatch does nothing');
        \\e.initCustomEvent('other');
        \\assert(e.detail === null, 'initCustomEvent without a detail');
        \\
        \\// createEvent('CustomEvent'): no detail until initCustomEvent gives one.
        \\const legacy = document.createEvent('CustomEvent');
        \\assert(legacy instanceof CustomEvent && legacy.detail === null && legacy.type === '', 'createEvent');
        \\let threw = false;
        \\try { document.dispatchEvent(legacy); } catch (x) { threw = x.name === 'InvalidStateError'; }
        \\assert(threw, 'an uninitialized event does not dispatch');
        \\legacy.initCustomEvent('legacy', true, true, detail);
        \\assert(legacy.detail === detail && legacy.type === 'legacy', 'createEvent + initCustomEvent');
        \\assert(document.dispatchEvent(legacy) === true, 'and it dispatches');
        \\
        \\// The detail lives as long as the event does, and no longer.
        \\globalThis.keptEvent = new CustomEvent('k', { detail: { big: new Array(1000).fill(7) } });
        \\for (let i = 0; i < 2000; i++) new CustomEvent('churn', { detail: { i } });
        \\TestUtils.gc(); TestUtils.gc();
        \\assert(keptEvent.detail.big.length === 1000 && keptEvent.detail.big[999] === 7, 'a kept event keeps its detail across collections');
        \\done();
    );
    try page.collect();
    try page.run("assert(keptEvent.detail.big[0] === 7, 'after a task turn'); keptEvent = null; done();");
    try page.collect();
}

test "a CustomEvent's detail and its Event state work with no block of its own" {
    try onFreshThread(customEvents);
}

fn currentTargets() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\const outer = document.body.appendChild(document.createElement('div'));
        \\const leaf = outer.appendChild(document.createElement('span'));
        \\const other = document.body.appendChild(document.createElement('b'));
        \\const a = new Event('a', { bubbles: true });
        \\const b = new Event('b', { bubbles: true });
        \\assert(a.currentTarget === null, 'before dispatch');
        \\const seen = [];
        \\other.addEventListener('b', ev => {
        \\  seen.push('b at other');
        \\  assert(ev.currentTarget === other && b.currentTarget === other, 'the nested event at its target');
        \\  assert(a.currentTarget === outer, 'the outer event keeps its currentTarget during a nested dispatch');
        \\});
        \\document.body.addEventListener('b', ev => { assert(ev.currentTarget === document.body, 'the nested event, bubbling'); });
        \\leaf.addEventListener('a', ev => { seen.push('a at leaf'); assert(ev.currentTarget === leaf, 'at the target'); });
        \\outer.addEventListener('a', ev => {
        \\  seen.push('a at outer');
        \\  assert(ev.currentTarget === outer, 'bubbling');
        \\  // Another event, not being dispatched: null before and after its
        \\  // own dispatch, though a dispatch is running.
        \\  assert(b.currentTarget === null, 'another event has no currentTarget before its dispatch');
        \\  other.dispatchEvent(b);
        \\  assert(b.currentTarget === null, 'nor after it');
        \\  assert(ev.currentTarget === outer, 'the outer event after the nested dispatch');
        \\  // An event made in a listener and never dispatched.
        \\  assert(new Event('c').currentTarget === null, 'an event made during a dispatch');
        \\});
        \\document.addEventListener('a', ev => { assert(ev.currentTarget === document, 'at the document'); }, true);
        \\leaf.dispatchEvent(a);
        \\assert(seen.join() === 'a at leaf,a at outer,b at other', 'order: ' + seen.join());
        \\assert(a.currentTarget === null && b.currentTarget === null, 'after dispatch');
        \\
        \\// stopPropagation leaves the currentTarget where it stopped until
        \\// dispatch ends.
        \\const s = new Event('s', { bubbles: true });
        \\leaf.addEventListener('s', ev => { ev.stopPropagation(); assert(ev.currentTarget === leaf, 'when stopped'); });
        \\leaf.dispatchEvent(s);
        \\assert(s.currentTarget === null, 'after a stopped dispatch');
        \\
        \\// A listener that throws, and an event kept past collections.
        \\globalThis.keptEvent = new Event('t', { bubbles: true });
        \\leaf.addEventListener('t', () => { throw new Error('deliberate'); });
        \\leaf.dispatchEvent(keptEvent);
        \\assert(keptEvent.currentTarget === null && keptEvent.target === leaf, 'after a listener threw');
        \\for (let i = 0; i < 200; i++) leaf.dispatchEvent(new Event('churn', { bubbles: true }));
        \\TestUtils.gc();
        \\assert(keptEvent.currentTarget === null && keptEvent.eventPhase === 0, 'a kept event, after other dispatches and a collection');
        \\done();
    );
}

test "currentTarget is the dispatch's: null before and after it, and for any event that is not being dispatched" {
    try onFreshThread(currentTargets);
}

fn relatedTargets() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\assert(new MouseEvent('click').relatedTarget === null, 'none given');
        \\assert(new FocusEvent('focus').relatedTarget === null, 'none given, focus');
        \\// The event alone keeps its relatedTarget: a node nothing else names.
        \\globalThis.over = new MouseEvent('mouseover', { bubbles: true, relatedTarget: document.createElement('b') });
        \\globalThis.focus = new FocusEvent('focusin', { relatedTarget: document.createElement('i') });
        \\for (let i = 0; i < 500; i++) new MouseEvent('mouseout', { relatedTarget: document.createElement('u') });
        \\TestUtils.gc(); TestUtils.gc();
        \\assert(over.relatedTarget.localName === 'b', 'a mouse event keeps its relatedTarget across a collection');
        \\assert(focus.relatedTarget.localName === 'i', 'a focus event keeps its relatedTarget across a collection');
        \\
        \\// Dispatch keeps it (no shadow tree: the same node all the way).
        \\let during = null;
        \\document.body.addEventListener('mouseover', ev => { during = ev.relatedTarget; });
        \\document.body.dispatchEvent(over);
        \\assert(during === over.relatedTarget && during.localName === 'b', 'during and after dispatch');
        \\
        \\// initMouseEvent replaces it, with another node and with none.
        \\const next = document.createElement('s');
        \\over.initMouseEvent('mouseover', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, next);
        \\assert(over.relatedTarget === next, 'initMouseEvent with another relatedTarget');
        \\over.initMouseEvent('mouseover', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
        \\assert(over.relatedTarget === null, 'initMouseEvent with none');
        \\over.initMouseEvent('mouseover', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, document.body);
        \\assert(over.relatedTarget === document.body, 'and with one again');
        \\done();
    );
    try page.collect();
    try page.run(
        \\assert(focus.relatedTarget.localName === 'i' && over.relatedTarget === document.body, 'after a task turn and collections');
        \\over = null; focus = null;
        \\done();
    );
    try page.collect();
}

test "a relatedTarget is kept by the event that has one, through collections, dispatch and re-initialization" {
    try onFreshThread(relatedTargets);
}
