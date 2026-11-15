//! Lane ev1 (the Event's memory, step 1): an event's path lives in the
//! dispatch that builds it, never in the Event - WebKit's EventPath is a
//! local of EventDispatcher::dispatchEventWithoutDebuggerDeferral, which the
//! Event points at only until Event::resetAfterDispatch; Gecko's target
//! chain is a local of EventDispatcher::Dispatch, which the event's mPath
//! names only while the chain is handled (dom.event_dispatch, "THE PATH IS
//! THE DISPATCH'S"). What script can see of that is DOM's: composedPath()
//! is the path while the event is dispatched and empty before and after
//! (dispatch step 9), whatever way the dispatch ends; a nested dispatch has
//! a path of its own; the same event dispatched again gets a new one.
//!
//! These read the page only, so they hold for the path wherever it is kept:
//! they passed on the tree before the path moved (main e0270810f7b) and pin
//! the behaviour across the move.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const Page = h.Page;
const onFreshThread = h.onFreshThread;

const prelude =
    \\// A failed check inside a listener would only be reported (inner invoke
    \\// reports a listener's exception): checks are recorded, and `done()`
    \\// throws them at the end of the script, where the test sees it.
    \\globalThis.failures = [];
    \\globalThis.assert = (ok, what) => { if (!ok) failures.push(what); };
    \\globalThis.done = () => { if (failures.length) throw new Error('ev1: ' + failures.join('; ')); };
    \\window.addEventListener('error', ev => {
    \\  const expected = String(ev.message).includes('deliberate') || (globalThis.stackErrorsExpected && /call stack/i.test(String(ev.message)));
    \\  if (!expected) failures.push('uncaught: ' + ev.message);
    \\  ev.preventDefault();
    \\});
    \\globalThis.same = (got, want, what) => {
    \\  assert(got.length === want.length, what + ': ' + got.length + ' targets, expected ' + want.length);
    \\  for (let i = 0; i < want.length; i++) assert(got[i] === want[i], what + ': target ' + i + ' differs');
    \\};
    \\globalThis.outer = document.body.appendChild(document.createElement('div'));
    \\globalThis.mid = outer.appendChild(document.createElement('p'));
    \\globalThis.leaf = mid.appendChild(document.createElement('span'));
    \\globalThis.full = [leaf, mid, outer, document.body, document.documentElement, document, window];
;

fn open() !Page {
    const page = try Page.open();
    errdefer page.close();
    try page.run(prelude);
    return page;
}

fn composedPathBeforeDuringAfter() !void {
    const page = try open();
    defer page.close();
    try page.run(
        \\const e = new Event('a', { bubbles: true });
        \\same(e.composedPath(), [], 'before dispatch');
        \\let seen = 0, expected = full;
        \\for (const target of full) {
        \\  target.addEventListener('a', ev => {
        \\    seen++;
        \\    assert(ev.currentTarget === target, 'currentTarget');
        \\    same(ev.composedPath(), expected, 'during dispatch');
        \\  });
        \\  target.addEventListener('a', ev => { seen++; same(ev.composedPath(), expected, 'capturing'); }, true);
        \\}
        \\leaf.dispatchEvent(e);
        \\assert(seen === 2 * full.length, 'every listener ran: ' + seen);
        \\same(e.composedPath(), [], 'after dispatch');
        \\assert(e.eventPhase === 0 && e.currentTarget === null && e.target === leaf, 'state after dispatch');
        \\
        \\// The same event again, at another target: a new path, not the old.
        \\seen = 0; expected = full.slice(1);
        \\mid.dispatchEvent(e);
        \\assert(seen === 2 * (full.length - 1), 'second dispatch: ' + seen);
        \\same(e.composedPath(), [], 'after the second dispatch');
        \\assert(e.target === mid, 'target after the second dispatch');
        \\
        \\// An event nobody hears still has a path while it is dispatched,
        \\// and none after; one that does not bubble has the same path.
        \\const quiet = new Event('nobody-listens');
        \\leaf.dispatchEvent(quiet);
        \\same(quiet.composedPath(), [], 'unheard event');
        \\let at = null;
        \\outer.addEventListener('nb', ev => { at = ev.composedPath(); }, true);
        \\leaf.dispatchEvent(new Event('nb'));
        \\same(at, full, 'a non-bubbling event, read while capturing');
        \\
        \\// The array composedPath() returned is script's: dispatch's end
        \\// does not empty it.
        \\let kept = null;
        \\leaf.addEventListener('k', ev => { kept = ev.composedPath(); });
        \\leaf.dispatchEvent(new Event('k', { bubbles: true }));
        \\same(kept, full, 'the returned array after dispatch');
        \\done();
    );
}

test "composedPath is the path during dispatch and empty before and after it" {
    try onFreshThread(composedPathBeforeDuringAfter);
}

fn nestedDispatches() !void {
    const page = try open();
    defer page.close();
    try page.run(
        \\globalThis.other = document.body.appendChild(document.createElement('b'));
        \\const otherPath = [other, document.body, document.documentElement, document, window];
        \\const a = new Event('a', { bubbles: true });
        \\const b = new Event('b', { bubbles: true });
        \\let inner = 0;
        \\other.addEventListener('b', ev => {
        \\  inner++;
        \\  same(ev.composedPath(), otherPath, 'the nested event, in its listener');
        \\  same(a.composedPath(), full, 'the outer event, read from the nested listener');
        \\  assert(a.currentTarget === mid && a.eventPhase === 3, 'the outer event keeps its place');
        \\});
        \\mid.addEventListener('a', ev => {
        \\  same(b.composedPath(), [], 'the nested event before its dispatch');
        \\  other.dispatchEvent(b);
        \\  same(b.composedPath(), [], 'the nested event after its dispatch');
        \\  same(ev.composedPath(), full, 'the outer event after the nested dispatch');
        \\});
        \\let after = 0;
        \\outer.addEventListener('a', ev => { after++; same(ev.composedPath(), full, 'further up, after the nested dispatch'); });
        \\leaf.dispatchEvent(a);
        \\assert(inner === 1 && after === 1, 'both dispatches ran');
        \\same(a.composedPath(), [], 'outer after');
        \\
        \\// The event being dispatched cannot be dispatched again from its
        \\// own listener (dispatch step 1), and its path is untouched.
        \\let refused = false;
        \\outer.addEventListener('r', ev => {
        \\  try { other.dispatchEvent(ev); } catch (x) { refused = x.name === 'InvalidStateError'; }
        \\  same(ev.composedPath(), full, 'after a refused re-entrant dispatch');
        \\});
        \\leaf.dispatchEvent(new Event('r', { bubbles: true }));
        \\assert(refused, 're-entrant dispatch throws InvalidStateError');
        \\
        \\// Dispatches nested many deep, each with its own event and path
        \\// (20: this build's unoptimized frames reach the engine's stack
        \\// check near 40).
        \\let depth = 0, deepest = 0;
        \\leaf.addEventListener('n', ev => {
        \\  depth++; deepest = Math.max(deepest, depth);
        \\  same(ev.composedPath(), full, 'depth ' + depth);
        \\  if (depth < 20) leaf.dispatchEvent(new Event('n', { bubbles: true }));
        \\  same(ev.composedPath(), full, 'depth ' + depth + ' after the deeper ones');
        \\  depth--;
        \\});
        \\leaf.dispatchEvent(new Event('n', { bubbles: true }));
        \\assert(deepest === 20 && depth === 0, 'nested 20 deep');
        \\done();
    );
}

test "a nested dispatch has a path of its own and leaves the outer one's alone" {
    try onFreshThread(nestedDispatches);
}

fn reentrantDispatchWithoutBound() !void {
    const page = try open();
    defer page.close();
    // Each nested dispatch has its path's inline items in its own stack
    // frame (WebKit's EventPath local is entered again the same way, once
    // per nested dispatchEvent). Entered again without bound, script gets
    // the engine's RangeError - its stack check runs on every entry to a
    // listener - never a crash of the stack, and the page dispatches
    // normally afterwards. How deep that is depends on the build: about 40
    // levels with this test build's unoptimized frames; the production
    // build's figure is measured with gc_bench (lane ev1's merge report),
    // beside Chrome's 43 (Blink stops re-entrant script at a fixed depth,
    // V8ScriptRunner's kMaxRecursionDepth) and Firefox's 338.
    try page.run(
        \\// The listener that cannot be entered throws the engine's
        \\// RangeError, which dispatch reports like any listener's exception.
        \\globalThis.stackErrorsExpected = true;
        \\let level = 0, reached = 0;
        \\leaf.addEventListener('forever', ev => {
        \\  level++; reached = Math.max(reached, level);
        \\  if (level <= 10) same(ev.composedPath(), full, 'level ' + level);
        \\  leaf.dispatchEvent(new Event('forever', { bubbles: true }));
        \\  level--;
        \\});
        \\leaf.dispatchEvent(new Event('forever', { bubbles: true }));
        \\globalThis.stackErrorsExpected = false;
        \\assert(level === 0, 'every level returned');
        \\assert(reached >= 20, 'unbounded re-entrant dispatch went only ' + reached + ' deep');
        \\
        \\// The page still dispatches.
        \\let ok = false;
        \\outer.addEventListener('afterwards', ev => { ok = ev.composedPath().length === full.length; });
        \\leaf.dispatchEvent(new Event('afterwards', { bubbles: true }));
        \\assert(ok, 'a dispatch after the deep one');
        \\done();
    );
}

test "re-entrant dispatch without bound ends in the engine's stack check, not a crash" {
    try onFreshThread(reentrantDispatchWithoutBound);
}

fn longPaths() !void {
    const page = try open();
    defer page.close();
    // Longer than any storage a dispatch keeps on its stack (WebKit's
    // EventPath keeps 32 contexts inline): 200 nested elements.
    try page.run(
        \\let node = document.body;
        \\const chain = [];
        \\for (let i = 0; i < 200; i++) { node = node.appendChild(document.createElement('div')); chain.unshift(node); }
        \\const want = [...chain, document.body, document.documentElement, document, window];
        \\let heard = 0;
        \\for (const target of [chain[0], chain[100], chain[199], window]) {
        \\  target.addEventListener('deep', ev => { heard++; same(ev.composedPath(), want, 'a 204-target path'); });
        \\}
        \\const e = new Event('deep', { bubbles: true });
        \\chain[0].dispatchEvent(e);
        \\assert(heard === 4, 'heard ' + heard);
        \\same(e.composedPath(), [], 'after');
        \\
        \\// A long path nested in a long path.
        \\let innerHeard = false;
        \\chain[150].addEventListener('deep2', ev => { innerHeard = true; same(ev.composedPath(), want.slice(150), 'the nested long path'); });
        \\chain[10].addEventListener('deep3', ev => {
        \\  chain[150].dispatchEvent(new Event('deep2', { bubbles: true }));
        \\  same(ev.composedPath(), want, 'the outer long path after the nested one');
        \\});
        \\chain[0].dispatchEvent(new Event('deep3', { bubbles: true }));
        \\assert(innerHeard, 'nested long dispatch ran');
        \\done();
    );
}

test "a path longer than a dispatch's inline storage is whole, nested or not" {
    try onFreshThread(longPaths);
}

fn shadowTrees() !void {
    const page = try open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\const root = host.attachShadow({ mode: 'closed' });
        \\const inner = root.appendChild(document.createElement('section'));
        \\const slot = inner.appendChild(document.createElement('slot'));
        \\const slotted = host.appendChild(document.createElement('i'));
        \\const deep = inner.appendChild(document.createElement('u'));
        \\const tail = [host, document.body, document.documentElement, document, window];
        \\
        \\// A composed event from inside the closed tree: listeners in the
        \\// tree see it all, listeners outside see it retargeted to the host
        \\// and without the tree's nodes.
        \\let inside = null, outside = null, targets = [];
        \\inner.addEventListener('c', ev => { inside = ev.composedPath(); targets.push(ev.target); });
        \\document.body.addEventListener('c', ev => { outside = ev.composedPath(); targets.push(ev.target); });
        \\const c = new Event('c', { bubbles: true, composed: true });
        \\deep.dispatchEvent(c);
        \\same(inside, [deep, inner, root, ...tail], 'inside the closed tree');
        \\same(outside, tail, 'outside the closed tree');
        \\assert(targets[0] === deep && targets[1] === host, 'target is retargeted to the host outside');
        \\assert(c.target === host, 'a composed event keeps the host as its target');
        \\same(c.composedPath(), [], 'after');
        \\
        \\// Not composed: the path ends at the shadow root, and the targets
        \\// are cleared when dispatch ends (step 11: clearTargets).
        \\let scoped = null;
        \\root.addEventListener('s', ev => { scoped = ev.composedPath(); });
        \\let leaked = false;
        \\host.addEventListener('s', () => { leaked = true; });
        \\const s = new Event('s', { bubbles: true });
        \\deep.dispatchEvent(s);
        \\same(scoped, [deep, inner, root], 'a scoped event stops at its root');
        \\assert(!leaked && s.target === null, 'scoped event: not heard outside, target cleared');
        \\
        \\// A slotted node's path goes through its slot and the closed tree;
        \\// a listener at the slotted node (outside the tree) does not see
        \\// the tree's nodes, one inside does.
        \\let atSlotted = null, atSlot = null;
        \\slotted.addEventListener('t', ev => { atSlotted = ev.composedPath(); });
        \\slot.addEventListener('t', ev => { atSlot = ev.composedPath(); });
        \\slotted.dispatchEvent(new Event('t', { bubbles: true }));
        \\same(atSlot, [slotted, slot, inner, root, ...tail], 'at the slot');
        \\same(atSlotted, [slotted, ...tail], 'at the slotted node');
        \\
        \\// relatedTarget is retargeted item by item: inside the tree it is
        \\// the node, outside it is the host - and a listener outside the
        \\// tree is not reached when the retargeted relatedTarget is its own
        \\// target (step 6.9.7).
        \\const seenRelated = [];
        \\inner.addEventListener('mouseover', ev => seenRelated.push(ev.relatedTarget));
        \\let reachedHost = false;
        \\host.addEventListener('mouseover', () => { reachedHost = true; });
        \\const over = new MouseEvent('mouseover', { bubbles: true, composed: true, relatedTarget: slot });
        \\deep.dispatchEvent(over);
        \\assert(seenRelated.length === 1 && seenRelated[0] === slot, 'relatedTarget inside the tree');
        \\assert(!reachedHost, 'the path stops where the host is both target and relatedTarget');
        \\const out = new MouseEvent('mouseout', { bubbles: true, composed: true, relatedTarget: deep });
        \\let relatedOutside = undefined;
        \\document.body.addEventListener('mouseout', ev => { relatedOutside = ev.relatedTarget; });
        \\outer.dispatchEvent(out);
        \\assert(relatedOutside === host, 'relatedTarget is retargeted to the host outside the tree');
        \\done();
    );
}

test "the path across shadow trees: retargeting, closed trees and slots" {
    try onFreshThread(shadowTrees);
}

fn endsOfDispatch() !void {
    const page = try open();
    defer page.close();
    try page.run(
        \\// A listener that throws: the exception is reported, the later
        \\// listeners still see the path, and dispatch ends as always.
        \\const e = new Event('x', { bubbles: true });
        \\let later = null;
        \\leaf.addEventListener('x', () => { throw new Error('deliberate: the listener threw'); });
        \\outer.addEventListener('x', ev => { later = ev.composedPath(); });
        \\assert(leaf.dispatchEvent(e) === true, 'dispatchEvent returns after a throwing listener');
        \\same(later, full, 'the path after a listener threw');
        \\same(e.composedPath(), [], 'after a dispatch whose listener threw');
        \\assert(e.eventPhase === 0 && e.currentTarget === null, 'state after a throwing listener');
        \\later = null;
        \\leaf.dispatchEvent(e);
        \\same(later, full, 'the event dispatches again after a throwing listener');
        \\
        \\// stopPropagation and stopImmediatePropagation end the walk, not
        \\// the dispatch's steps 7-11.
        \\const s = new Event('s', { bubbles: true });
        \\let ran = 0;
        \\leaf.addEventListener('s', ev => { ran++; ev.stopImmediatePropagation(); });
        \\leaf.addEventListener('s', () => { ran += 10; });
        \\outer.addEventListener('s', () => { ran += 100; });
        \\leaf.dispatchEvent(s);
        \\assert(ran === 1, 'stopImmediatePropagation: ' + ran);
        \\same(s.composedPath(), [], 'after stopImmediatePropagation');
        \\leaf.dispatchEvent(s);
        \\assert(ran === 2, 'the flags are unset for the next dispatch: ' + ran);
        \\
        \\// A node of the path removed while the event is dispatched stays
        \\// on the path until dispatch ends.
        \\const r = new Event('r', { bubbles: true });
        \\let afterRemoval = null;
        \\leaf.addEventListener('r', () => { mid.remove(); });
        \\outer.addEventListener('r', ev => { afterRemoval = ev.composedPath(); });
        \\leaf.dispatchEvent(r);
        \\same(afterRemoval, full, 'the path after one of its nodes was removed');
        \\outer.appendChild(mid);
        \\
        \\// An event dispatched again from inside its own activation
        \\// behaviour (dispatch step 12 runs after the path is emptied and
        \\// the dispatch flag unset): the second dispatch has its own path.
        \\const box = document.body.appendChild(document.createElement('input'));
        \\box.type = 'checkbox';
        \\const boxPath = [box, document.body, document.documentElement, document, window];
        \\const click = new MouseEvent('click', { bubbles: true, cancelable: true });
        \\let changes = 0, clicks = 0;
        \\box.addEventListener('click', ev => { clicks++; same(ev.composedPath(), boxPath, 'click ' + clicks); });
        \\box.addEventListener('change', () => {
        \\  changes++;
        \\  same(click.composedPath(), [], 'the click event inside its activation behaviour');
        \\  if (changes === 1) box.dispatchEvent(click);
        \\  same(click.composedPath(), [], 'after the dispatch from the activation behaviour');
        \\});
        \\box.dispatchEvent(click);
        \\assert(clicks === 2 && changes === 2, 'clicks ' + clicks + ', changes ' + changes);
        \\same(click.composedPath(), [], 'after both');
        \\done();
    );
}

test "every way a dispatch ends leaves the event with no path and ready to dispatch again" {
    try onFreshThread(endsOfDispatch);
}
