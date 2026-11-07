//! Lane forms1 (C1): HTML 15.5.16's base-appearance styles for the select
//! element through the UA style sheet - a drop-down select with
//! `appearance: base-select`, its ::picker(select), options, optgroups and
//! legends, the native appearance unchanged, a nested select, a list box,
//! the picker as the flat-tree parent of a drop-down select's children, and
//! the UA-only -internal-auto-base() / :-internal-list-box refused to author
//! style. Expected values: the HTML blocks and
//! customizable-select/select-base-appearance-computed-style.html,
//! base-appearance-inheritance.html (Chrome passes both).
const std = @import("std");
const Page = @import("edges_node_holders_helpers.zig").Page;
const onFreshThread = @import("edges_node_holders_helpers.zig").onFreshThread;

const helpers =
    \\globalThis.eq = (actual, expected, what) => {
    \\  if (actual !== expected) throw new Error(what + ': expected ' + JSON.stringify(expected) + ' got ' + JSON.stringify(actual));
    \\};
    \\globalThis.cs = (element, pseudo) => getComputedStyle(element, pseudo || null);
    \\globalThis.styleSheet = (text) => {
    \\  const style = document.createElement('style');
    \\  style.textContent = text;
    \\  document.head.append(style);
    \\  return style;
    \\};
;

fn page() !Page {
    const p = try Page.open();
    errdefer p.close();
    try p.run(helpers);
    return p;
}

fn baseDropDown() !void {
    const p = try page();
    defer p.close();
    try p.run(
        \\styleSheet('select, ::picker(select) { appearance: base-select }');
        \\const parent = document.createElement('div');
        \\parent.style.letterSpacing = '1px';
        \\parent.style.wordSpacing = '2px';
        \\parent.style.lineHeight = '13px';
        \\parent.style.textShadow = 'rgb(1, 1, 1) 1px 1px 1px';
        \\parent.style.textRendering = 'optimizeLegibility';
        \\parent.innerHTML = '<select><option>one</option><option disabled>two</option></select>';
        \\document.body.append(parent);
        \\const select = parent.querySelector('select');
        \\eq(cs(select).display, 'inline-flex', 'select display');
        \\eq(cs(select).borderTopWidth, '1px', 'select border-top-width');
        \\eq(cs(select).borderTopStyle, 'solid', 'select border-top-style');
        \\eq(cs(select).userSelect, 'none', 'select user-select');
        \\eq(cs(select).boxSizing, 'border-box', 'select box-sizing');
        \\eq(cs(select).backgroundColor, 'rgba(0, 0, 0, 0)', 'select background-color');
        \\eq(cs(select).paddingInlineStart, '8px', 'select padding-inline-start');
        \\eq(cs(select).paddingBlockStart, '4px', 'select padding-block-start');
        \\eq(cs(select).borderTopLeftRadius, '8px', 'select border-radius');
        \\eq(cs(select).columnGap, '8px', 'select gap');
        \\// Inherited, not reset as with native appearance.
        \\eq(cs(select).letterSpacing, '1px', 'select letter-spacing');
        \\eq(cs(select).wordSpacing, '2px', 'select word-spacing');
        \\eq(cs(select).lineHeight, '13px', 'select line-height');
        \\eq(cs(select).textShadow, 'rgb(1, 1, 1) 1px 1px 1px', 'select text-shadow');
        \\eq(cs(select)['text-rendering'], 'optimizelegibility', 'select text-rendering');
        \\const option = select.options[0];
        \\eq(cs(option).display, 'flex', 'option display');
        \\eq(cs(option).minInlineSize, '24px', 'option min-inline-size');
        \\eq(cs(option).minBlockSize, '24px', 'option min-block-size');
        \\eq(cs(option).paddingInlineStart, '8px', 'option padding-inline-start');
        \\eq(cs(option).paddingBlockEnd, '0px', 'option padding-block-end');
        \\eq(cs(option).alignItems, 'center', 'option align-items');
        \\eq(cs(option).whiteSpace, 'nowrap', 'option white-space');
        \\eq(cs(option, '::checkmark').content, '"✓" / ""', 'option::checkmark content');
        \\eq(cs(select.options[1]).color, 'oklab(0 0 0 / 0.5)', 'disabled option color');
        \\eq(cs(select, '::picker-icon').content, 'counter(fake-counter-name, disclosure-open)', '::picker-icon content');
        \\eq(cs(select, '::picker-icon').display, 'block', '::picker-icon display');
        \\const picker = cs(select, '::picker(select)');
        \\eq(picker.boxSizing, 'border-box', 'picker box-sizing');
        \\eq(picker.color, 'rgb(0, 0, 0)', 'picker color (CanvasText)');
        \\eq(picker.backgroundColor, 'rgb(255, 255, 255)', 'picker background-color (Canvas)');
        \\eq(picker.borderTopWidth, '1px', 'picker border-top-width');
    );
}

test "a base-select drop-down select computes HTML 15.5.16's base-appearance styles" {
    try onFreshThread(baseDropDown);
}

fn nativeUnchanged() !void {
    const p = try page();
    defer p.close();
    try p.run(
        \\const parent = document.createElement('div');
        \\parent.style.letterSpacing = '1px';
        \\parent.style.textShadow = 'rgb(1, 1, 1) 1px 1px 1px';
        \\parent.innerHTML = '<select><option>one</option><optgroup><option>two</option></optgroup></select>';
        \\document.body.append(parent);
        \\const select = parent.querySelector('select');
        \\eq(cs(select).display, 'inline-block', 'native select display');
        \\eq(cs(select).letterSpacing, 'normal', 'native select letter-spacing (initial)');
        \\eq(cs(select).textShadow, 'none', 'native select text-shadow (15.3.10)');
        \\eq(cs(select).borderTopStyle, 'none', 'native select border');
        \\eq(cs(select).userSelect, 'auto', 'native select user-select');
        \\eq(cs(select).alignContent, 'center', 'native drop-down align-content');
        \\eq(cs(select.options[0]).display, 'block', 'native option display');
        \\eq(cs(select.options[1]).fontWeight, '700', 'native option in optgroup font-weight');
    );
}

test "a select with native appearance keeps HTML 15.5.16's native styles" {
    try onFreshThread(nativeUnchanged);
}

fn optgroupAndLegend() !void {
    const p = try page();
    defer p.close();
    try p.run(
        \\styleSheet('select, ::picker(select) { appearance: base-select }');
        \\const parent = document.createElement('div');
        \\parent.style.lineHeight = '13px';
        \\parent.style.fontWeight = '500';
        \\parent.innerHTML = '<select><optgroup><legend>l</legend><option>one</option></optgroup><hr></select>';
        \\document.body.append(parent);
        \\const optgroup = parent.querySelector('optgroup');
        \\eq(cs(optgroup).fontWeight, '700', 'optgroup font-weight (bolder)');
        \\eq(cs(optgroup).display, 'block', 'optgroup display');
        \\eq(cs(parent.querySelector('optgroup option')).fontWeight, '400', 'option in optgroup font-weight');
        \\const legend = parent.querySelector('legend');
        \\eq(cs(legend).minBlockSize, '13px', 'legend min-block-size (1lh)');
        \\eq(cs(legend).paddingInlineStart, '8px', 'legend padding-inline-start');
    );
}

test "a base-select select's optgroup, option in it and legend" {
    try onFreshThread(optgroupAndLegend);
}

fn buttonAndNested() !void {
    const p = try page();
    defer p.close();
    try p.run(
        \\styleSheet('.custom, .custom::picker(select) { appearance: base-select }');
        \\const select = document.createElement('select');
        \\select.className = 'custom';
        \\select.innerHTML = '<button>b</button><option>one</option>';
        \\document.body.append(select);
        \\eq(cs(select.querySelector('button')).display, 'contents', 'first-child button display');
        \\eq(cs(select.options[0]).display, 'flex', 'outer option display');
        \\// base-appearance-inheritance.html: base appearance stops at an
        \\// element that itself supports it.
        \\const nested = document.createElement('select');
        \\const nestedOption = document.createElement('option');
        \\select.append(nested);
        \\nested.append(nestedOption);
        \\eq(cs(select).display, 'inline-flex', 'outer select display');
        \\eq(cs(nested).display, 'inline-block', 'nested select display');
        \\eq(cs(nestedOption).display, 'block', 'nested option display');
    );
}

test "a base select's first-child button, and a nested select without base appearance" {
    try onFreshThread(buttonAndNested);
}

fn pickerParent() !void {
    const p = try page();
    defer p.close();
    try p.run(
        \\styleSheet('select, ::picker(select) { appearance: base-select } ::picker(select) { color: rgb(1, 2, 3) } .auto::picker(select) { appearance: auto }');
        \\const select = document.createElement('select');
        \\select.innerHTML = '<button>b</button><option>one</option>';
        \\document.body.append(select);
        \\// HTML 15.5.16: the select popover slot, inside ::picker(select),
        \\// takes the children; the select button slot takes the button.
        \\eq(cs(select.options[0]).color, 'rgb(1, 2, 3)', 'option inherits from ::picker(select)');
        \\eq(cs(select.querySelector('button')).color, cs(select).color, 'first-child button inherits from the select');
        \\// The select's contents are base only when its picker is too.
        \\const auto = document.createElement('select');
        \\auto.className = 'auto';
        \\auto.innerHTML = '<option>one</option>';
        \\document.body.append(auto);
        \\eq(cs(auto).display, 'inline-flex', 'select with an auto picker display');
        \\eq(cs(auto.options[0]).display, 'block', 'option of an auto picker display');
        \\// A list box has no picker: its options inherit from it.
        \\const listbox = document.createElement('select');
        \\listbox.size = 4;
        \\listbox.innerHTML = '<option>one</option>';
        \\document.body.append(listbox);
        \\eq(cs(listbox).display, 'inline-block', 'list box display');
        \\eq(cs(listbox).overflowY, 'auto', 'base list box overflow');
        \\eq(cs(listbox.options[0]).color, cs(listbox).color, 'list box option inherits from the select');
        \\eq(cs(listbox.options[0]).display, 'flex', 'base list box option display');
    );
}

test "a drop-down select's children inherit from its ::picker(select); a list box's from it" {
    try onFreshThread(pickerParent);
}

fn cachedStyles() !void {
    const p = try page();
    defer p.close();
    try p.run(
        \\const sheet = styleSheet('');
        \\const select = document.createElement('select');
        \\select.innerHTML = '<option>one</option>';
        \\document.body.append(select);
        \\const option = select.options[0];
        \\eq(cs(option).display, 'block', 'option before');
        \\eq(cs(select).display, 'inline-block', 'select before');
        \\// The option's cached style is keyed on its picker's.
        \\sheet.textContent = 'select, ::picker(select) { appearance: base-select }';
        \\eq(cs(select).display, 'inline-flex', 'select after the sheet');
        \\eq(cs(option).display, 'flex', 'option after the sheet');
        \\select.multiple = true;
        \\eq(cs(select).display, 'inline-block', 'select after multiple');
        \\eq(cs(select).alignContent, 'normal', 'list box align-content');
        \\select.multiple = false;
        \\eq(cs(select).display, 'inline-flex', 'select after multiple removed');
        \\select.style.appearance = 'auto';
        \\eq(cs(select).display, 'inline-block', 'select after appearance auto');
        \\eq(cs(option).display, 'block', 'option after appearance auto');
    );
}

test "styles follow a select's appearance, picker and multiple changes" {
    try onFreshThread(cachedStyles);
}

fn uaOnly() !void {
    const p = try page();
    defer p.close();
    try p.run(
        \\eq(CSS.supports('display', '-internal-auto-base(inline, block)'), false, 'CSS.supports -internal-auto-base');
        \\eq(CSS.supports('selector(:-internal-list-box)'), false, 'CSS.supports :-internal-list-box');
        \\let threw = false;
        \\try { document.querySelector('select:-internal-list-box'); } catch (e) { threw = e.name === 'SyntaxError'; }
        \\eq(threw, true, 'querySelector(:-internal-list-box) throws SyntaxError');
        \\const listbox = document.createElement('select');
        \\listbox.multiple = true;
        \\document.body.append(listbox);
        \\for (const call of [() => listbox.matches(':-internal-list-box'), () => listbox.closest(':-internal-list-box'), () => document.querySelectorAll(':-internal-list-box')]) {
        \\  let thrown = '';
        \\  try { call(); } catch (e) { thrown = e.name; }
        \\  eq(thrown, 'SyntaxError', 'matches/closest/querySelectorAll(:-internal-list-box)');
        \\}
        \\const style = styleSheet('select:-internal-list-box { color: red } div { display: -internal-auto-base(inline, block) }');
        \\eq(style.sheet.cssRules.length, 1, 'the :-internal-list-box rule is dropped');
        \\eq(style.sheet.cssRules[0].style.display, '', 'the -internal-auto-base() declaration is dropped');
        \\const div = document.createElement('div');
        \\div.style.display = '-internal-auto-base(inline, block)';
        \\eq(div.style.display, '', 'style attribute -internal-auto-base()');
        \\document.body.append(div);
        \\eq(cs(div).display, 'block', 'div display stays the UA block');
    );
}

test "author style cannot use -internal-auto-base() or :-internal-list-box" {
    try onFreshThread(uaOnly);
}
