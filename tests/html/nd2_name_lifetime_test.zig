//! An element name record's lifetime, driven by script and ended by the
//! collector (lane nd2 batch 1-fix, tmp/redesign/node-memory-plan-v2.md B2).
//!
//! A name no static table has (a custom element's, createElementNS's) is a
//! record its Browser interns. Each element of the name counts one
//! reference, and the table is weak: the last element's teardown removes
//! and frees the record, at once, on the window agent's thread - Blink's
//! QualifiedNameImpl (counted, static names never; its destructor erases it
//! from the QualifiedNameCache: core/dom/qualified_name.cc), WebKit's
//! QualifiedName (~QualifiedNameImpl, dom/QualifiedName.cpp), Gecko's
//! NodeInfo (its last release removes it from the document's
//! nsNodeInfoManager: dom/base/nsNodeInfoManager.cpp). Batch 1 kept every
//! record for the Browser's life (appendix-nd2.md F1).
//!
//! Each case makes elements from script - createElement, createElementNS
//! with a prefix, the HTML fragment parser, the XML parser (DOMParser),
//! cloneNode - drops them, collects, and asks the Browser's table: back to
//! where it started. The red run on batch 1's tip keeps every name.

const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const helpers = @import("winslot_helpers.zig");

fn names(page: helpers.Page) usize {
    const table = page.browser.scope.existingTable(.element_names, dom.element_name.Table) orelse return 0;
    return table.count();
}

fn expectBack(page: helpers.Page, start: usize, comptime what: []const u8) !void {
    try page.collect();
    const now = names(page);
    if (now != start) std.debug.print(what ++ ": the Browser's name table holds {d} names, {d} at the start\n", .{ now, start });
    try testing.expectEqual(start, now);
}

test "names made by script and collected leave the Browser's name table where it started" {
    const page = try helpers.Page.open();
    defer page.close();
    const start = names(page);

    try page.run("for (let i = 0; i < 100000; i++) document.createElement('x-' + i);");
    try expectBack(page, start, "createElement('x-' + i)");

    try page.run("for (let i = 0; i < 100000; i++) document.createElementNS('urn:x', 'p:x' + i);");
    try expectBack(page, start, "createElementNS('urn:x', 'p:x' + i)");

    // The HTML fragment parser names its custom elements the same way.
    try page.run(
        \\{ const host = document.createElement('div'); let html = '';
        \\  for (let i = 0; i < 2000; i++) html += '<x-p' + i + '><x-q' + i + '></x-q' + i + '></x-p' + i + '>';
        \\  host.innerHTML = html; document.body.append(host); host.remove(); }
    );
    try expectBack(page, start, "innerHTML");

    // The XML parser: prefixed names, each its own record.
    try page.run(
        \\{ let xml = '<r xmlns:a="urn:a">';
        \\  for (let i = 0; i < 2000; i++) xml += '<a:e' + i + '/>';
        \\  new DOMParser().parseFromString(xml + '</r>', 'application/xml'); }
    );
    try expectBack(page, start, "DOMParser application/xml");

    // A clone names itself with its original's record and counts it.
    try page.run(
        \\{ const original = document.createElementNS('urn:c', 'c:item');
        \\  globalThis.kept = original.cloneNode(); }
    );
    try page.collect();
    try page.expectEval("kept.localName + ' ' + kept.prefix + ' ' + kept.namespaceURI + ' ' + kept.tagName", "item c urn:c c:item");
    try page.run("delete globalThis.kept;");
    try expectBack(page, start, "cloneNode");
}

test "an element's names stay whole after every other element of its name is collected" {
    const page = try helpers.Page.open();
    defer page.close();

    try page.run(
        \\globalThis.keep = document.createElement('x-shared');
        \\for (let i = 0; i < 1000; i++) document.createElement('x-shared');
        \\globalThis.keepNS = document.createElementNS('urn:k', 'k:Shared');
        \\for (let i = 0; i < 1000; i++) document.createElementNS('urn:k', 'k:Shared');
    );
    try page.collect();
    try page.expectEval("[keep.localName, keep.tagName, keep.namespaceURI, String(keep.prefix)].join(' ')", "x-shared X-SHARED http://www.w3.org/1999/xhtml null");
    try page.expectEval("[keepNS.localName, keepNS.tagName, keepNS.namespaceURI, keepNS.prefix, keepNS.nodeName].join(' ')", "Shared k:Shared urn:k k k:Shared");
    // A new element of the name finds the kept one's record.
    try page.expectEval("document.createElement('x-shared').tagName", "X-SHARED");
    try testing.expectEqual(@as(usize, 2), names(page));
}
