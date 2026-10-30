//! Conditional 5 §§5, 5.1, 6.1, 7; Q94: eligible containers have no
//! geometry provider yet. Keep lengths unresolved and skip scalar consumers.
const helpers = @import("edges_node_holders_helpers.zig");

fn check(comptime _: []const u8, comptime exercise: fn () anyerror!void) !void {
    try helpers.onFreshThread(exercise);
}

fn run(script: []const u8) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<section id="outer"><section id="inner"><div id="target"></div></section></section>';
        \\globalThis.outer = document.getElementById('outer');
        \\globalThis.inner = document.getElementById('inner');
        \\globalThis.target = document.getElementById('target');
        \\globalThis.units = [['cqw','svw'],['cqh','svh'],['cqi','svi'],['cqb','svb'],['cqmin','svmin'],['cqmax','svmax']];
        \\globalThis.equal = function(actual, expected, label) {
        \\  if (actual !== expected) throw Error(label + ': expected ' + expected + ', got ' + actual);
        \\};
        \\globalThis.retained = function(unit) {
        \\  target.style.left = '2' + unit;
        \\  equal(target.style.left, '2' + unit, 'specified ' + unit);
        \\  equal(getComputedStyle(target).left, '2' + unit, 'retained ' + unit);
        \\};
        \\globalThis.fallback = function(unit, viewport) {
        \\  target.style.left = '2' + viewport;
        \\  const expected = getComputedStyle(target).left;
        \\  target.style.left = '2' + unit;
        \\  equal(getComputedStyle(target).left, expected, 'fallback ' + unit);
        \\};
    );
    try page.run(script);
}

test "cp1 container default and self exclusion keep all six viewport fallbacks" {
    try check("defaultAndSelf", defaultAndSelf);
}
fn defaultAndSelf() !void {
    try run(
        \\for (const [unit, viewport] of units) fallback(unit, viewport);
        \\target.style.containerType = 'size';
        \\equal(target.style.containerType, 'size', 'supported container-type');
        \\for (const [unit, viewport] of units) fallback(unit, viewport);
    );
}

test "cp1 size ancestor retains all six container lengths" {
    try check("sizeAncestor", sizeAncestor);
}
fn sizeAncestor() !void {
    try run(
        \\inner.style.containerType = 'size';
        \\for (const [unit] of units) retained(unit);
    );
}

test "cp1 horizontal inline container selects its own inline axis" {
    try check("horizontalInline", horizontalInline);
}
fn horizontalInline() !void {
    try run(
        \\inner.style.containerType = 'inline-size';
        \\target.style.writingMode = 'vertical-rl';
        \\for (const unit of ['cqw','cqb','cqmin','cqmax']) retained(unit);
        \\fallback('cqh', 'svh');
        \\fallback('cqi', 'svi');
    );
}

test "cp1 vertical inline container selects height even for a horizontal child" {
    try check("verticalInline", verticalInline);
}
fn verticalInline() !void {
    try run(
        \\inner.style.containerType = 'inline-size';
        \\inner.style.writingMode = 'vertical-lr';
        \\target.style.writingMode = 'horizontal-tb';
        \\for (const unit of ['cqh','cqb','cqmin','cqmax']) retained(unit);
        \\fallback('cqw', 'svw');
        \\fallback('cqi', 'svi');
        \\target.style.writingMode = 'vertical-rl';
        \\retained('cqi');
        \\fallback('cqb', 'svb');
    );
}

test "cp1 different physical axes may select different ancestors" {
    try check("differentAncestors", differentAncestors);
}
fn differentAncestors() !void {
    try run(
        \\outer.style.containerType = 'inline-size';
        \\inner.style.cssText = 'container-type: inline-size; writing-mode: vertical-rl';
        \\target.style.writingMode = 'horizontal-tb';
        \\for (const [unit] of units) retained(unit);
        \\outer.style.containerType = 'size';
        \\retained('cqb');
    );
}

test "cp1 slotted elements select flat ancestors and pseudos include their origin" {
    try check("flatAncestors", flatAncestors);
}
fn flatAncestors() !void {
    try run(
        \\const shadow = inner.attachShadow({mode:'open'});
        \\shadow.innerHTML = '<section style="container-type:size"><slot></slot></section>';
        \\retained('cqw');
        \\target.style.containerType = 'size';
        \\const style = document.createElement('style');
        \\style.textContent = '#target::before { content: ""; left: 2cqh; }';
        \\document.head.appendChild(style);
        \\equal(getComputedStyle(target, '::before').left, '2cqh', 'pseudo originating container');
    );
}

test "cp1 scroll-state alone supplies no size axes but a combined size does" {
    try check("scrollState", scrollState);
}
fn scrollState() !void {
    try run(
        \\inner.style.containerType = 'scroll-state';
        \\for (const [unit, viewport] of units) fallback(unit, viewport);
        \\inner.style.containerType = 'size scroll-state';
        \\for (const [unit] of units) retained(unit);
    );
}

test "cp1 unavailable container scalar skips to the retained candidate" {
    try check("scalarSkip", scalarSkip);
}
fn scalarSkip() !void {
    try run(
        \\inner.style.containerType = 'size';
        \\const style = document.createElement('style');
        \\style.textContent = '#target { tab-size: 7; }';
        \\document.head.appendChild(style);
        \\target.style.tabSize = 'sign(2cqw - 10px)';
        \\equal(getComputedStyle(target).tabSize, '7', 'unavailable scalar skips');
        \\target.style.setProperty('--scalar', 'sign(2cqw - 10px)');
        \\target.style.tabSize = 'var(--scalar)';
        \\equal(getComputedStyle(target).tabSize, '7', 'substituted scalar skips');
    );
}

test "cp1 nested color scalar uses the same unavailable candidate decision" {
    try check("nestedScalarSkip", nestedScalarSkip);
}
fn nestedScalarSkip() !void {
    try run(
        \\inner.style.containerType = 'size';
        \\const style = document.createElement('style');
        \\style.textContent = '#target { color: rgb(9, 8, 7); }';
        \\document.head.appendChild(style);
        \\target.style.color = 'rgb(sign(2cqw - 10px) 0 0)';
        \\if (!target.style.color.includes('sign(')) throw Error('nested scalar was not parsed');
        \\equal(getComputedStyle(target).color, 'rgb(9, 8, 7)', 'nested unavailable scalar skips');
    );
}

test "cp1 algebraically eliminated container dependency remains computable" {
    try check("cancelledDependency", cancelledDependency);
}
fn cancelledDependency() !void {
    try run(
        \\inner.style.containerType = 'size';
        \\target.style.tabSize = 'calc(2cqw / 1cqw)';
        \\equal(getComputedStyle(target).tabSize, '2', 'cancelled dependency');
    );
}

test "cp1 boxless containers are skipped to a boxed outer container" {
    try check("boxlessContainers", boxlessContainers);
}
fn boxlessContainers() !void {
    try run(
        \\for (const display of ['none', 'contents']) {
        \\  for (const type of ['size', 'inline-size']) {
        \\    outer.style.containerType = 'normal';
        \\    inner.style.cssText = 'display: ' + display + '; container-type: ' + type;
        \\    for (const [unit, viewport] of units) fallback(unit, viewport);
        \\    outer.style.containerType = 'size';
        \\    for (const [unit] of units) retained(unit);
        \\  }
        \\}
    );
}

test "cp1 hidden container and hidden consumer have different eligibility" {
    try check("hiddenElements", hiddenElements);
}
fn hiddenElements() !void {
    try run(
        \\inner.style.containerType = 'size';
        \\outer.style.display = 'none';
        \\for (const [unit, viewport] of units) fallback(unit, viewport);
        \\outer.style.display = 'block';
        \\target.style.display = 'none';
        \\for (const [unit] of units) retained(unit);
        \\target.style.display = 'inline';
        \\for (const [unit] of units) retained(unit);
    );
}

test "cp1 font size skips an unavailable length while width retains it" {
    try check("nonGeometryLength", nonGeometryLength);
}
fn nonGeometryLength() !void {
    try run(
        \\inner.style.containerType = 'size';
        \\const style = document.createElement('style');
        \\style.textContent = '#target { font-size: 14px; }';
        \\document.head.appendChild(style);
        \\target.style.fontSize = '10cqw';
        \\target.style.width = '10cqw';
        \\equal(getComputedStyle(target).fontSize, '14px', 'font size skips');
        \\equal(getComputedStyle(target).width, '10cqw', 'width retains');
    );
}
