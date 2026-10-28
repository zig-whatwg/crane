//! Q97–99: unavailable container input never enters custom or pending caches.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn check(comptime name: []const u8, comptime exercise: fn () anyerror!void) !void {
    errdefer std.debug.print("CP1_CQ_CUSTOM FAIL: {s}\n", .{name});
    try helpers.onFreshThread(exercise);
    std.debug.print("CP1_CQ_CUSTOM PASS: {s}\n", .{name});
}

fn run(script: []const u8) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<section style="container-type:size"><div id="target"></div></section>';
        \\globalThis.target = document.getElementById('target');
        \\globalThis.sheet = document.createElement('style'); document.head.appendChild(sheet);
        \\globalThis.equal = (actual, expected, label) => { if (actual !== expected) throw Error(label + ': expected ' + expected + ', got ' + actual); };
        \\globalThis.register = (syntax, initialValue) => CSS.registerProperty({name:'--cq',syntax,initialValue,inherits:false});
        \\globalThis.custom = () => getComputedStyle(target).getPropertyValue('--cq').trim();
    );
    try page.run(script);
}

test "cp1 registered number skips unavailable input before custom storage" {
    try check("registeredNumber", registeredNumber);
}
fn registeredNumber() !void {
    try run(
        \\register('<number>', '4');
        \\sheet.textContent = '#target { --cq: 7; }';
        \\target.style.cssText = '--cq:sign(2cqw - 10px); width:calc(var(--cq) * 1px); font-size:calc(var(--cq) * 1px)';
        \\equal(custom(), '7', 'stored lower scalar');
        \\equal(getComputedStyle(target).width, '7px', 'scalar into width');
        \\equal(getComputedStyle(target).fontSize, '7px', 'scalar into font-size');
    );
}

test "cp1 registered unavailable length selects its lower absolute value" {
    try check("registeredLength", registeredLength);
}
fn registeredLength() !void {
    try run(
        \\register('<length>', '4px');
        \\sheet.textContent = '#target { --cq: 7px; font-size: 14px; }';
        \\target.style.cssText = '--cq:10cqw; width:var(--cq); font-size:var(--cq)';
        \\equal(custom(), '7px', 'stored lower absolute length');
        \\equal(getComputedStyle(target).width, '7px', 'length into width');
        \\equal(getComputedStyle(target).fontSize, '7px', 'length into font-size');
    );
}

test "cp1 registered scalar lists discard the whole candidate" {
    try check("scalarList", scalarList);
}
fn scalarList() !void {
    try run(
        \\register('<number>#', '4, 5');
        \\sheet.textContent = '#target { --cq: 7, 8; }';
        \\target.style.setProperty('--cq', '9, sign(2cqw - 10px)');
        \\equal(custom(), '7, 8', 'no partial scalar list enters storage');
    );
}

test "cp1 registered length lists discard the whole unavailable candidate" {
    try check("lengthList", lengthList);
}
fn lengthList() !void {
    try run(
        \\register('<length>#', '4px, 5px');
        \\sheet.textContent = '#target { --cq: 7px, 8px; }';
        \\target.style.setProperty('--cq', '9px, 10cqw');
        \\equal(custom(), '7px, 8px', 'stored lower length list');
    );
}

test "cp1 registered union rejects unavailable scalar and length inputs" {
    try check("unionSyntax", unionSyntax);
}
fn unionSyntax() !void {
    try run(
        \\register('<number> | <length>', '4');
        \\sheet.textContent = '#target { --cq: 7px; font-size: 14px; }';
        \\target.style.cssText = '--cq:sign(2cqw - 10px); width:var(--cq); font-size:var(--cq)';
        \\equal(custom(), '7px', 'union scalar skipped');
        \\equal(getComputedStyle(target).fontSize, '7px', 'lower union length');
        \\target.style.setProperty('--cq', '10cqw');
        \\equal(custom(), '7px', 'union length skipped');
        \\equal(getComputedStyle(target).width, '7px', 'union width');
        \\equal(getComputedStyle(target).fontSize, '7px', 'union font-size');
    );
}

test "cp1 registered inherited length cannot be remapped by child writing mode" {
    try check("registeredInheritance", registeredInheritance);
}
fn registeredInheritance() !void {
    try run(
        \\CSS.registerProperty({name:'--cq', syntax:'<length>', initialValue:'4px', inherits:true});
        \\target.parentElement.style.containerType = 'inline-size';
        \\sheet.textContent = '#target { --cq:7px }';
        \\target.style.cssText = '--cq:2cqi; writing-mode:horizontal-tb';
        \\const child = document.createElement('div'); target.appendChild(child);
        \\child.style.cssText = 'writing-mode:vertical-rl; width:var(--cq)';
        \\equal(getComputedStyle(child).width, '7px', 'inherited lower value keeps its computed length');
        \\equal(custom(), '7px', 'declaring element lower absolute value');
        \\sheet.textContent = '';
        \\equal(getComputedStyle(child).width, '4px', 'inherited initial absolute value');
        \\equal(custom(), '4px', 'declaring element initial value');
    );
}

test "cp1 unregistered inherited length uses the consuming child axis" {
    try check("unregisteredInheritance", unregisteredInheritance);
}
fn unregisteredInheritance() !void {
    try run(
        \\target.parentElement.style.containerType = 'inline-size';
        \\target.style.cssText = '--cq:2cqi; writing-mode:horizontal-tb';
        \\const child = document.createElement('div'); target.appendChild(child);
        \\child.style.cssText = 'writing-mode:vertical-rl; width:2svi';
        \\const expected = getComputedStyle(child).width;
        \\child.style.width = 'var(--cq)';
        \\equal(getComputedStyle(child).width, expected, 'unregistered text uses the child axis');
        \\equal(custom(), '2cqi', 'unregistered text remains specified');
    );
}

test "cp1 cached pending shorthand cannot leak a placeholder to another side" {
    try check("pendingShorthand", pendingShorthand);
}
fn pendingShorthand() !void {
    try run(
        \\sheet.textContent = '#target { margin:1px 2px 3px 4px; width:9px; }';
        \\target.style.margin = 'random-item(fixed sign(2cqw - 10px), 11px, 12px)';
        \\const computed = getComputedStyle(target);
        \\for (const [side, value] of [['Top','1px'],['Right','2px'],['Bottom','3px'],['Left','4px']]) equal(computed['margin' + side], value, 'cached side ' + side);
        \\equal(computed.width, '9px', 'outer note remains clean');
    );
}

test "cp1 pending selected length retains geometry and unused branches do not taint" {
    try check("selectedPending", selectedPending);
}
fn selectedPending() !void {
    try run(
        \\target.style.margin = 'random-item(fixed 0, 2cqw, 3px)';
        \\for (const side of ['Top','Right','Bottom','Left']) equal(getComputedStyle(target)['margin' + side], '2cqw', 'selected length ' + side);
        \\target.style.margin = 'random-item(fixed 1, calc(sign(2cqw - 10px) * 1px), 3px)';
        \\for (const side of ['Top','Right','Bottom','Left']) equal(getComputedStyle(target)['margin' + side], '3px', 'unused input ' + side);
    );
}

test "cp1 unregistered custom pending input cannot store a placeholder selection" {
    try check("unregisteredPending", unregisteredPending);
}
fn unregisteredPending() !void {
    try run(
        \\sheet.textContent = '#target { --cq:7px; font-size:14px; }';
        \\target.style.cssText = '--cq:random-item(fixed sign(2cqw - 10px), 11px, 12px); width:var(--cq); font-size:var(--cq)';
        \\equal(custom(), '7px', 'unregistered lower candidate');
        \\equal(getComputedStyle(target).width, '7px', 'custom lower width');
        \\equal(getComputedStyle(target).fontSize, '7px', 'custom lower font');
        \\target.style.setProperty('--cq', 'random-item(fixed 0, 2cqw, 3px)');
        \\equal(custom(), '2cqw', 'unregistered selected text');
        \\equal(getComputedStyle(target).width, '2cqw', 'selected custom geometry');
        \\equal(getComputedStyle(target).fontSize, '14px', 'selected custom nongeometry skips');
    );
}

test "cp1 candidate retry preserves revert layer and has no fixed skip limit" {
    try check("candidateRetry", candidateRetry);
}
fn candidateRetry() !void {
    try run(
        \\sheet.textContent = '@layer low,high; @layer low { #target { tab-size:7; } ' + '#target { tab-size:sign(2cqw - 10px); }'.repeat(20) + ' } @layer high { #target { tab-size:revert-layer; } }';
        \\equal(getComputedStyle(target).tabSize, '7', 'twenty exact skips after revert-layer');
    );
}

fn displayCase(comptime display: []const u8, comptime eligible: bool) !void {
    try run(
        "const container = target.parentElement; container.style.display = '" ++ display ++ "';" ++
            "for (const type of ['size', 'inline-size']) {" ++
            "container.style.containerType = type; target.style.left = '2svw';" ++
            "const fallback = getComputedStyle(target).left; target.style.left = '2cqw';" ++
            "equal(getComputedStyle(target).left, " ++ (if (eligible) "'2cqw'" else "fallback") ++ ", '" ++ display ++ " ' + type); }",
    );
}

test "cp1 non atomic inline containers are ineligible" {
    try check("inlineContainer", inlineContainer);
}
fn inlineContainer() !void {
    try displayCase("inline", false);
}

test "cp1 inline block containers are eligible" {
    try check("inlineBlockContainer", inlineBlockContainer);
}
fn inlineBlockContainer() !void {
    try displayCase("inline-block", true);
}

test "cp1 table containers are ineligible for size containment" {
    try check("tableContainer", tableContainer);
}
fn tableContainer() !void {
    try displayCase("table", false);
}

test "cp1 table cell containers are ineligible for size containment" {
    try check("tableCellContainer", tableCellContainer);
}
fn tableCellContainer() !void {
    try displayCase("table-cell", false);
}
