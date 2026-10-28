//! Script selection behavior independent of coordinate-based caret placement.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn collapseSiblings() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id="button"></button><div id="a" contenteditable></div><div id="b" contenteditable></div>';
        \\button.focus();
        \\getSelection().collapse(a);
    );
    const first = try page.evaluate("document.activeElement.id");
    defer std.testing.allocator.free(first);
    try std.testing.expectEqualStrings("a", first);
    try page.run("getSelection().collapse(b)");
    const second = try page.evaluate("document.activeElement.id");
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualStrings("b", second);
}

fn collapseCanonicalization() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.sd1Outcomes = [];
        \\for (const [markup, expected] of [['', 'outer'], ['x', 'outer'], ['<span contenteditable="false">x</span>', 'outer'], ['\n<div contenteditable="false"><div contenteditable="true" id="inner"></div></div>\n', 'guard'], ['<span contenteditable="true">x</span>', 'outer']]) {
        \\  document.body.innerHTML = '<button id="guard">guard</button><div id="outer" contenteditable="true">' + markup + '</div>';
        \\  const host = document.getElementById('outer'), guard = document.getElementById('guard');
        \\  for (let offset=0; offset<=host.childNodes.length; ++offset) {
        \\    guard.focus(); getSelection().collapse(host, offset);
        \\    sd1Outcomes.push(document.activeElement.id === expected && getSelection().anchorNode === host && getSelection().anchorOffset === offset);
        \\  }
        \\}
    );
    const actual = try page.evaluate("JSON.stringify(sd1Outcomes)");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings("[true,true,true,true,true,true,true,true,true,true,true]", actual);
}

test "sd1 collapse focus follows all eleven browser canonicalization probe cases" {
    try helpers.onFreshThread(collapseCanonicalization);
}

test "sd1 Selection collapse moves focus between empty sibling editing hosts" {
    try helpers.onFreshThread(collapseSiblings);
}

fn collapseTextPositions() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Q20 browser probe (2026-10-27): all three focus hidden text, preserved
    // whitespace and empty Text, and reject noneditable Text. Chrome/Safari
    // also reject inert Text and collapsed whitespace beside a noneditable
    // block; Firefox alone focuses those positions. The Range never changes.
    try page.run(
        \\globalThis.sd1TextFailures = []; globalThis.sd1TextCount = 0;
        \\const cases = [
        \\ ['before', '\n<div contenteditable="false"><div contenteditable="true"></div></div>\n', h=>h.firstChild, 'guard'],
        \\ ['after', '\n<div contenteditable="false"><div contenteditable="true"></div></div>\n', h=>h.lastChild, 'guard'],
        \\ ['hidden', '<span style="display:none">abc</span>', h=>h.firstChild.firstChild, 'outer'],
        \\ ['inert', '<span inert>abc</span>', h=>h.firstChild.firstChild, 'guard'],
        \\ ['preserved', '<span style="white-space:pre"> </span><div contenteditable="false">x</div>', h=>h.firstChild.firstChild, 'outer'],
        \\ ['empty', '', h=>h.appendChild(document.createTextNode('')), 'outer'],
        \\ ['noneditable', '<span contenteditable="false">abc</span>', h=>h.firstChild.firstChild, 'guard'],
        \\];
        \\for (const [label, markup, point, expected] of cases) {
        \\ document.body.innerHTML = '<button id="guard">guard</button><div id="outer" contenteditable="true">' + markup + '</div>';
        \\ const host = document.getElementById('outer'), guard = document.getElementById('guard'), node = point(host);
        \\ for (const offset of [...new Set([0, Math.min(1, node.length), node.length])]) {
        \\   guard.focus(); getSelection().collapse(node, offset);
        \\   ++sd1TextCount;
        \\   const active = document.activeElement.id, sameNode = getSelection().anchorNode === node, anchorOffset = getSelection().anchorOffset;
        \\   if (active !== expected || !sameNode || anchorOffset !== offset)
        \\     sd1TextFailures.push({label, offset, expected, active, sameNode, anchorOffset});
        \\ }
        \\}
    );
    const actual = try page.evaluate("JSON.stringify({count:sd1TextCount,failures:sd1TextFailures})");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings("{\"count\":16,\"failures\":[]}", actual);
}

test "sd1 collapse focus follows all sixteen text-position browser probe cases" {
    try helpers.onFreshThread(collapseTextPositions);
}

fn reentrantCollapse() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id="guard">guard</button><div id="first" contenteditable></div><div id="second" contenteditable></div>';
        \\const first = document.getElementById('first'), second = document.getElementById('second');
        \\document.getElementById('guard').focus();
        \\first.addEventListener('focus', () => getSelection().collapse(second, 0), {once:true});
        \\getSelection().collapse(first, 0);
    );
    const actual = try page.evaluate("JSON.stringify([document.activeElement.id, getSelection().anchorNode.id, getSelection().anchorOffset])");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings("[\"second\",\"second\",0]", actual);
}

test "sd1 collapse preserves a focus listener's replacement selection" {
    try helpers.onFreshThread(reentrantCollapse);
}
