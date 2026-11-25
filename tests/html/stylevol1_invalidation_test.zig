//! Dynamic pseudo-class style caching and state-change invalidation (lane stylevol1).
//!
//! Verifies that:
//! 1. Styles inside `<form>`, `<fieldset>`, `<dialog>`, `[popover]`, `[dir=auto]`,
//!    custom elements (`:defined`, `:state()`), and media elements stay cached across
//!    repeated reads (`serial` unchanged, non-volatile) — including when author rules
//!    use dynamic pseudo-classes such as `input:invalid`.
//! 2. Every dynamic state mutation invalidates cached styles immediately (zero stale
//!    computed styles across direct selectors, ancestor/descendant/sibling combinators,
//!    `:has()`, inheritance, and CSS transitions).
//! 3. Moving focus between controls does not re-resolve unaffected ancestors (`html`,
//!    `body`, `form`, wrapper divs, `label`) when no rule reads `:focus-within` /
//!    combinator `:focus` on them, while `:focus`, `:focus-visible`, `:focus-within`,
//!    `input:focus + label`, and `:has(:focus)` still update accurately.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

fn element(page: helpers.Page, id: []const u8) !*runtime.Instance {
    const document = page.browser.current_context.?.document_instance.?;
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoElement;
}

fn serialOf(e: *runtime.Instance) u64 {
    const state = dom.style.element_style.existingOf(e) orelse return 0;
    const cached = state.cached orelse return 0;
    return cached.serial;
}

fn isVolatile(e: *runtime.Instance) bool {
    const state = dom.style.element_style.existingOf(e) orelse return false;
    const cached = state.cached orelse return false;
    return cached.@"volatile";
}

fn formSubtreeCached() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = `<style>
        \\  .card { color: rgb(20, 30, 40); }
        \\  input:invalid { outline: 1px solid rgb(255, 0, 0); }
        \\  fieldset:invalid { border-color: rgb(255, 0, 0); }
        \\</style>`;
        \\document.body.innerHTML = `
        \\  <form id="f">
        \\    <fieldset id="fs">
        \\      <div class="card" id="card">
        \\        <span id="cell">Cell</span>
        \\        <label id="lbl">Name <input id="inp" required value="ok"></label>
        \\        <textarea id="ta" dir="auto" placeholder="hint">hello</textarea>
        \\        <select id="sel"><option id="opt" selected>A</option></select>
        \\        <button id="btn" type="submit">Go</button>
        \\      </div>
        \\    </fieldset>
        \\  </form>
        \\`;
        \\for (const id of ['f', 'fs', 'card', 'cell', 'lbl', 'inp', 'ta', 'sel', 'opt', 'btn']) {
        \\  getComputedStyle(document.getElementById(id)).color;
        \\}
    );
    const ids = [_][]const u8{ "f", "fs", "card", "cell", "lbl", "inp", "ta", "sel", "opt", "btn" };
    var before: [ids.len]u64 = undefined;
    for (ids, 0..) |id, idx| {
        const el = try element(page, id);
        before[idx] = serialOf(el);
        try std.testing.expect(before[idx] != 0);
        try std.testing.expect(!isVolatile(el));
    }
    try page.run(
        \\for (let r = 0; r < 3; r++) {
        \\  for (const id of ['f', 'fs', 'card', 'cell', 'lbl', 'inp', 'ta', 'sel', 'opt', 'btn']) {
        \\    getComputedStyle(document.getElementById(id)).color;
        \\  }
        \\}
    );
    for (ids, 0..) |id, idx| {
        const el = try element(page, id);
        try std.testing.expectEqual(before[idx], serialOf(el));
    }
}

test "form subtree styles stay cached and non-volatile across repeated reads" {
    try helpers.onFreshThread(formSubtreeCached);
}

fn dialogPopoverCustomMediaCached() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = `<style>
        \\  dialog:modal { color: rgb(1, 2, 3); }
        \\  [popover]:popover-open { color: rgb(4, 5, 6); }
        \\  x-box:defined { color: rgb(7, 8, 9); }
        \\  x-box:state(on) { background-color: rgb(10, 20, 30); }
        \\  audio:paused { color: rgb(11, 22, 33); }
        \\</style>`;
        \\class XBox extends HTMLElement {
        \\  constructor() { super(); this._i = this.attachInternals(); }
        \\}
        \\customElements.define('x-box', XBox);
        \\document.body.innerHTML = `
        \\  <dialog id="dlg"><span id="dlgc">hi</span></dialog>
        \\  <div id="pop" popover="manual"><span id="popc">hi</span></div>
        \\  <x-box id="xb"><span id="xbc">hi</span></x-box>
        \\  <audio id="aud"></audio>
        \\`;
        \\document.getElementById('dlg').showModal();
        \\document.getElementById('pop').showPopover();
        \\for (const id of ['dlg', 'dlgc', 'pop', 'popc', 'xb', 'xbc', 'aud']) {
        \\  getComputedStyle(document.getElementById(id)).color;
        \\}
    );
    const ids = [_][]const u8{ "dlg", "dlgc", "pop", "popc", "xb", "xbc", "aud" };
    var before: [ids.len]u64 = undefined;
    for (ids, 0..) |id, idx| {
        const el = try element(page, id);
        before[idx] = serialOf(el);
        try std.testing.expect(before[idx] != 0);
        try std.testing.expect(!isVolatile(el));
    }
    try page.run(
        \\for (let r = 0; r < 3; r++) {
        \\  for (const id of ['dlg', 'dlgc', 'pop', 'popc', 'xb', 'xbc', 'aud']) {
        \\    getComputedStyle(document.getElementById(id)).color;
        \\  }
        \\}
    );
    for (ids, 0..) |id, idx| {
        const el = try element(page, id);
        try std.testing.expectEqual(before[idx], serialOf(el));
    }
}

test "dialog, popover, custom element, and media styles stay cached across repeated reads" {
    try helpers.onFreshThread(dialogPopoverCustomMediaCached);
}

fn focusLoopDoesNotInvalidateAncestors() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = `<style>
        \\  .card { color: rgb(20, 30, 40); }
        \\  .row { padding: 1px; }
        \\  input:invalid { outline: 1px solid rgb(255, 0, 0); }
        \\</style>`;
        \\document.body.innerHTML = `
        \\  <form id="f">
        \\    <div class="card" id="card">
        \\      <div class="row" id="row">
        \\        <label id="l0"><input id="i0" required value="a"></label>
        \\        <label id="l1"><input id="i1" required value="b"></label>
        \\      </div>
        \\    </div>
        \\  </form>
        \\`;
        \\document.getElementById('i0').focus();
        \\getComputedStyle(document.getElementById('i0')).outlineStyle;
        \\getComputedStyle(document.getElementById('i1')).outlineStyle;
    );
    const ancestors = [_][]const u8{ "f", "card", "row", "l0", "l1" };
    var before: [ancestors.len]u64 = undefined;
    for (ancestors, 0..) |id, idx| {
        const el = try element(page, id);
        before[idx] = serialOf(el);
        try std.testing.expect(before[idx] != 0);
    }
    try page.run(
        \\for (let k = 0; k < 6; k++) {
        \\  document.getElementById(k % 2 === 0 ? 'i1' : 'i0').focus();
        \\}
        \\if (getComputedStyle(document.getElementById('i0')).outlineStyle !== 'auto')
        \\  throw new Error('focused i0 should match :focus-visible outline:auto, got ' + getComputedStyle(document.getElementById('i0')).outlineStyle);
        \\if (getComputedStyle(document.getElementById('i1')).outlineStyle !== 'none')
        \\  throw new Error('unfocused i1 should have outline:none, got ' + getComputedStyle(document.getElementById('i1')).outlineStyle);
    );
    for (ancestors, 0..) |id, idx| {
        const el = try element(page, id);
        try std.testing.expectEqual(before[idx], serialOf(el));
    }
}

test "moving focus between inputs keeps unaffected ancestor styles cached" {
    try helpers.onFreshThread(focusLoopDoesNotInvalidateAncestors);
}

fn formStateMutationsInvalidate() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = `<style>
        \\  label { color: rgb(0, 0, 0); }
        \\  input:checked + label { color: rgb(0, 128, 0); }
        \\  input:indeterminate { color: rgb(10, 20, 30); }
        \\  form:has(input:checked) { background-color: rgb(1, 2, 3); }
        \\  input:valid { border-top-color: rgb(0, 200, 0); }
        \\  input:invalid { border-top-color: rgb(200, 0, 0); }
        \\  input:in-range { border-bottom-color: rgb(0, 100, 0); }
        \\  input:out-of-range { border-bottom-color: rgb(100, 0, 0); }
        \\  input:placeholder-shown { color: rgb(111, 111, 111); }
        \\  textarea:placeholder-shown { color: rgb(111, 111, 111); }
        \\  textarea:invalid { border-top-color: rgb(200, 0, 0); }
        \\  select:invalid { border-top-color: rgb(200, 0, 0); }
        \\  option:checked { color: rgb(0, 128, 0); }
        \\  button:invalid, fieldset:invalid, output:invalid, object:invalid { color: rgb(200, 0, 0); }
        \\  input:dir(rtl), textarea:dir(rtl) { color: rgb(50, 60, 70); }
        \\</style>`;
        \\document.body.innerHTML = `
        \\  <form id="f">
        \\    <input id="cb" type="checkbox"><label id="cbl">cb</label>
        \\    <input id="r1" type="radio" name="rg"><input id="r2" type="radio" name="rg">
        \\    <input id="txt" required placeholder="p">
        \\    <input id="num" type="number" min="0" max="10" step="2" value="4">
        \\    <input id="dirinp" dir="auto" value="hello">
        \\    <textarea id="ta" required placeholder="p" dir="auto"></textarea>
        \\    <select id="sel" required><option id="o1" value="">empty</option><option id="o2" value="x">x</option></select>
        \\    <button id="btn" type="submit">go</button>
        \\    <fieldset id="fs"></fieldset>
        \\    <output id="out"></output>
        \\    <object id="obj"></object>
        \\  </form>
        \\`;
        \\const $ = id => document.getElementById(id);
        \\const cs = id => getComputedStyle($(id));
        \\
        \\// 1. :checked + sibling combinator + :has()
        \\if (cs('cbl').color !== 'rgb(0, 0, 0)') throw new Error('cb initial');
        \\if (cs('f').backgroundColor === 'rgb(1, 2, 3)') throw new Error('form:has initial');
        \\$('cb').checked = true;
        \\if (cs('cbl').color !== 'rgb(0, 128, 0)') throw new Error('cb checked sibling');
        \\if (cs('f').backgroundColor !== 'rgb(1, 2, 3)') throw new Error('form:has checked');
        \\$('cb').checked = false;
        \\if (cs('cbl').color !== 'rgb(0, 0, 0)') throw new Error('cb unchecked');
        \\
        \\// 2. :indeterminate (checkbox + radio group)
        \\if (cs('cb').color === 'rgb(10, 20, 30)') throw new Error('cb not indet');
        \\$('cb').indeterminate = true;
        \\if (cs('cb').color !== 'rgb(10, 20, 30)') throw new Error('cb indet');
        \\$('cb').indeterminate = false;
        \\if (cs('cb').color === 'rgb(10, 20, 30)') throw new Error('cb indet cleared');
        \\if (cs('r1').color !== 'rgb(10, 20, 30)') throw new Error('radio initially indet');
        \\$('r2').checked = true;
        \\if (cs('r1').color === 'rgb(10, 20, 30)') throw new Error('radio group checked clears r1 indet');
        \\
        \\// 3. :valid/:invalid, :placeholder-shown, setRangeText, reset()
        \\if (cs('txt').borderTopColor !== 'rgb(200, 0, 0)') throw new Error('txt invalid');
        \\if (cs('txt').color !== 'rgb(111, 111, 111)') throw new Error('txt placeholder-shown');
        \\$('txt').value = 'abc';
        \\if (cs('txt').borderTopColor !== 'rgb(0, 200, 0)') throw new Error('txt valid after value');
        \\if (cs('txt').color === 'rgb(111, 111, 111)') throw new Error('txt placeholder hidden');
        \\$('txt').setRangeText('', 0, 3);
        \\if (cs('txt').borderTopColor !== 'rgb(200, 0, 0)') throw new Error('txt invalid after setRangeText');
        \\$('txt').value = 'ok';
        \\$('txt').setCustomValidity('bad');
        \\if (cs('txt').borderTopColor !== 'rgb(200, 0, 0)') throw new Error('txt customValidity');
        \\$('txt').setCustomValidity('');
        \\if (cs('txt').borderTopColor !== 'rgb(0, 200, 0)') throw new Error('txt customValidity cleared');
        \\$('f').reset();
        \\if (cs('txt').borderTopColor !== 'rgb(200, 0, 0)') throw new Error('txt invalid after reset');
        \\
        \\// 4. :in-range / :out-of-range + stepUp / valueAsNumber
        \\if (cs('num').borderBottomColor !== 'rgb(0, 100, 0)') throw new Error('num in-range');
        \\$('num').valueAsNumber = 20;
        \\if (cs('num').borderBottomColor !== 'rgb(100, 0, 0)') throw new Error('num out-of-range');
        \\$('num').valueAsNumber = 3;
        \\if (cs('num').borderTopColor !== 'rgb(200, 0, 0)') throw new Error('num stepMismatch invalid');
        \\$('num').stepUp(1);
        \\if (cs('num').borderTopColor !== 'rgb(0, 200, 0)') throw new Error('num valid after stepUp');
        \\
        \\// 5. :dir(rtl) on input & textarea with dir=auto
        \\if (cs('dirinp').color === 'rgb(50, 60, 70)') throw new Error('dirinp ltr');
        \\$('dirinp').value = '\u05D0';
        \\if (cs('dirinp').color !== 'rgb(50, 60, 70)') throw new Error('dirinp rtl');
        \\if (cs('ta').color !== 'rgb(111, 111, 111)') throw new Error('ta placeholder');
        \\if (cs('ta').borderTopColor !== 'rgb(200, 0, 0)') throw new Error('ta invalid');
        \\$('ta').value = '\u05D0';
        \\if (cs('ta').color !== 'rgb(50, 60, 70)') throw new Error('ta rtl');
        \\if (cs('ta').borderTopColor === 'rgb(200, 0, 0)') throw new Error('ta valid');
        \\
        \\// 6. select / option :checked and :invalid
        \\if (cs('sel').borderTopColor !== 'rgb(200, 0, 0)') throw new Error('sel invalid');
        \\$('o2').selected = true;
        \\if (cs('o2').color !== 'rgb(0, 128, 0)') throw new Error('o2 checked');
        \\if (cs('sel').borderTopColor === 'rgb(200, 0, 0)') throw new Error('sel valid');
        \\$('sel').selectedIndex = 0;
        \\if (cs('o2').color === 'rgb(0, 128, 0)') throw new Error('o2 unchecked after selectedIndex');
        \\if (cs('sel').borderTopColor !== 'rgb(200, 0, 0)') throw new Error('sel invalid after selectedIndex');
        \\
        \\// 7. setCustomValidity on button, select, textarea
        \\$('btn').setCustomValidity('nope');
        \\if (cs('btn').color !== 'rgb(200, 0, 0)') throw new Error('btn customValidity');
        \\$('btn').setCustomValidity('');
        \\if (cs('btn').color === 'rgb(200, 0, 0)') throw new Error('btn customValidity cleared');
    );
}

test "all form control dynamic state mutations invalidate cached styles" {
    try helpers.onFreshThread(formStateMutationsInvalidate);
}

fn customElementDialogPopoverMediaInvalidate() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = `<style>
        \\  x-late { color: rgb(255, 0, 0); }
        \\  x-late:defined { color: rgb(0, 128, 0); }
        \\  x-late:state(active) + span { color: rgb(0, 0, 255); }
        \\  x-late:invalid { background-color: rgb(200, 0, 0); }
        \\  dialog { color: rgb(1, 1, 1); }
        \\  dialog:modal { color: rgb(2, 2, 2); }
        \\  [popover] { color: rgb(3, 3, 3); }
        \\  [popover]:popover-open { color: rgb(4, 4, 4); }
        \\  audio { color: rgb(5, 5, 5); }
        \\  audio:muted { color: rgb(6, 6, 6); }
        \\</style>`;
        \\document.body.innerHTML = `
        \\  <x-late id="xl"></x-late><span id="sib">s</span>
        \\  <dialog id="dlg"></dialog>
        \\  <div id="pop" popover="manual"></div>
        \\  <audio id="aud"></audio>
        \\`;
        \\const $ = id => document.getElementById(id);
        \\const cs = id => getComputedStyle($(id));
        \\
        \\// :defined
        \\if (cs('xl').color !== 'rgb(255, 0, 0)') throw new Error('x-late undefined');
        \\class XLate extends HTMLElement {
        \\  static formAssociated = true;
        \\  constructor() { super(); this._i = this.attachInternals(); }
        \\}
        \\customElements.define('x-late', XLate);
        \\if (cs('xl').color !== 'rgb(0, 128, 0)') throw new Error('x-late defined');
        \\
        \\// :state() + sibling combinator
        \\if (cs('sib').color === 'rgb(0, 0, 255)') throw new Error('state before add');
        \\$('xl')._i.states.add('active');
        \\if (cs('sib').color !== 'rgb(0, 0, 255)') throw new Error('state after add');
        \\$('xl')._i.states.delete('active');
        \\if (cs('sib').color === 'rgb(0, 0, 255)') throw new Error('state after delete');
        \\$('xl')._i.states.add('active');
        \\if (cs('sib').color !== 'rgb(0, 0, 255)') throw new Error('state after re-add');
        \\$('xl')._i.states.clear();
        \\if (cs('sib').color === 'rgb(0, 0, 255)') throw new Error('state after clear');
        \\
        \\// ElementInternals.setValidity
        \\if (cs('xl').backgroundColor === 'rgb(200, 0, 0)') throw new Error('face valid');
        \\$('xl')._i.setValidity({ customError: true }, 'err');
        \\if (cs('xl').backgroundColor !== 'rgb(200, 0, 0)') throw new Error('face invalid');
        \\$('xl')._i.setValidity({});
        \\if (cs('xl').backgroundColor === 'rgb(200, 0, 0)') throw new Error('face valid again');
        \\
        \\// dialog :modal
        \\if (cs('dlg').color !== 'rgb(1, 1, 1)') throw new Error('dlg closed');
        \\$('dlg').showModal();
        \\if (cs('dlg').color !== 'rgb(2, 2, 2)') throw new Error('dlg modal');
        \\$('dlg').close();
        \\if (cs('dlg').color !== 'rgb(1, 1, 1)') throw new Error('dlg closed again');
        \\
        \\// popover :popover-open
        \\if (cs('pop').color !== 'rgb(3, 3, 3)') throw new Error('pop closed');
        \\$('pop').showPopover();
        \\if (cs('pop').color !== 'rgb(4, 4, 4)') throw new Error('pop open');
        \\$('pop').hidePopover();
        \\if (cs('pop').color !== 'rgb(3, 3, 3)') throw new Error('pop closed again');
        \\
        \\// media :muted
        \\if (cs('aud').color !== 'rgb(5, 5, 5)') throw new Error('aud unmuted');
        \\$('aud').muted = true;
        \\if (cs('aud').color !== 'rgb(6, 6, 6)') throw new Error('aud muted');
        \\$('aud').muted = false;
        \\if (cs('aud').color !== 'rgb(5, 5, 5)') throw new Error('aud unmuted again');
    );
}

test "custom element, dialog, popover, and media mutations invalidate cached styles" {
    try helpers.onFreshThread(customElementDialogPopoverMediaInvalidate);
}

fn focusCombinatorsAndInheritance() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = `<style>
        \\  #wrap { color: rgb(10, 10, 10); }
        \\  #wrap:focus-within { color: rgb(0, 128, 0); }
        \\  #box { color: rgb(20, 20, 20); }
        \\  #box:focus { color: rgb(0, 0, 255); }
        \\  #lbl { background-color: rgb(30, 30, 30); }
        \\  #i0:focus + #lbl { background-color: rgb(255, 128, 0); }
        \\  #hasbox { border-top-color: rgb(40, 40, 40); }
        \\  #hasbox:has(#i1:focus) { border-top-color: rgb(128, 0, 128); }
        \\</style>`;
        \\document.body.innerHTML = `
        \\  <div id="wrap">
        \\    <div id="box" tabindex="0"><span id="child">c</span></div>
        \\    <input id="i0"><label id="lbl">L</label>
        \\    <div id="hasbox"><input id="i1"></div>
        \\  </div>
        \\`;
        \\const $ = id => document.getElementById(id);
        \\const cs = id => getComputedStyle($(id));
        \\
        \\if (cs('wrap').color !== 'rgb(10, 10, 10)') throw new Error('wrap initial');
        \\if (cs('child').color !== 'rgb(20, 20, 20)') throw new Error('child initial');
        \\if (cs('lbl').backgroundColor !== 'rgb(30, 30, 30)') throw new Error('lbl initial');
        \\if (cs('hasbox').borderTopColor !== 'rgb(40, 40, 40)') throw new Error('hasbox initial');
        \\
        \\$('box').focus();
        \\if (cs('wrap').color !== 'rgb(0, 128, 0)') throw new Error('wrap focus-within');
        \\if (cs('child').color !== 'rgb(0, 0, 255)') throw new Error('child inherits box:focus');
        \\
        \\$('i0').focus();
        \\if (cs('child').color !== 'rgb(20, 20, 20)') throw new Error('child after box blur');
        \\if (cs('lbl').backgroundColor !== 'rgb(255, 128, 0)') throw new Error('sibling i0:focus + lbl');
        \\
        \\$('i1').focus();
        \\if (cs('lbl').backgroundColor !== 'rgb(30, 30, 30)') throw new Error('lbl after i0 blur');
        \\if (cs('hasbox').borderTopColor !== 'rgb(128, 0, 128)') throw new Error('hasbox:has(#i1:focus)');
        \\
        \\$('i1').blur();
        \\if (cs('wrap').color !== 'rgb(10, 10, 10)') throw new Error('wrap after blur');
        \\if (cs('hasbox').borderTopColor !== 'rgb(40, 40, 40)') throw new Error('hasbox after blur');
    );
}

test "focus combinators (:focus-within, :focus + sibling, :has(:focus)) and inheritance update accurately" {
    try helpers.onFreshThread(focusCombinatorsAndInheritance);
}

fn dynamicStateStartsTransitions() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = `<style>
        \\  #cb { color: rgb(255, 0, 0); transition: color 1s linear; }
        \\  #cb:checked { color: rgb(0, 0, 255); }
        \\  #pop { color: rgb(255, 0, 0); transition: color 1s linear; display: block; }
        \\  #pop:popover-open { color: rgb(0, 0, 255); }
        \\</style>`;
        \\document.body.innerHTML = '<input id="cb" type="checkbox"><div id="pop" popover="manual"></div>';
        \\globalThis.tRuns = [];
        \\document.getElementById('cb').addEventListener('transitionrun', () => tRuns.push('cb'));
        \\document.getElementById('pop').addEventListener('transitionrun', () => tRuns.push('pop'));
        \\// Establish before-change styles.
        \\getComputedStyle(document.getElementById('cb')).color;
        \\getComputedStyle(document.getElementById('pop')).color;
        \\// Mutate dynamic states without DOM attribute changes.
        \\document.getElementById('cb').checked = true;
        \\document.getElementById('pop').showPopover();
    );
    for (0..40) |_| {
        try page.turn();
        const count = try page.evaluate("String(tRuns.length)");
        defer std.testing.allocator.free(count);
        if (std.mem.eql(u8, count, "2")) break;
    }
    try page.run(
        \\if (!tRuns.includes('cb') || !tRuns.includes('pop'))
        \\  throw new Error('expected transitionrun for cb and pop, got ' + JSON.stringify(tRuns));
    );
}

test "dynamic state changes (:checked, :popover-open) trigger CSS transitions at rendering update" {
    try helpers.onFreshThread(dynamicStateStartsTransitions);
}
