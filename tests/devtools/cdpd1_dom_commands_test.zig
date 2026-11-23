//! The live DOM over CDP (lane cdpd1, batch 2; roadmap cdp-live-dom): the
//! DOM-domain commands that read the tree and push nodes to the client -
//! Blink's InspectorDOMAgent (inspector_dom_agent.cc at Chrome
//! 157.0.8103.78: getAttributes, requestNode with PushNodePathToFrontend's
//! detached-subtree push, pushNodeByPathToFrontend / NodeForPath,
//! pushNodesByBackendIdsToFrontend, getFlattenedDocument,
//! collectClassNamesFromSubtree, getTopLayerElements, performSearch /
//! getSearchResults / discardSearchResults, focus).
//!
//! The page and its node ids are the harness's (cdpd1_harness.zig):
//!     #document 1, HTML 2, HEAD 3, BODY 4, DIV#a 5, SPAN 6, "x" 7, P#b 8
//! after DOM.getDocument {depth: -1}; with {depth: 2} only 1-4 are bound and
//! BODY's children were not sent.

const std = @import("std");
const testing = std.testing;
const devtools = @import("devtools");
const harness = @import("cdpd1_harness.zig");
const Harness = harness.Harness;
const page = harness.page;
const setUp = harness.setUp;
const expectEvents = harness.expectEvents;

/// The remote object id of what `expression` evaluates to, in the page.
fn objectId(h: *Harness, expression: []const u8) ![]const u8 {
    const params = try fmt(h, "{{\"expression\":\"{s}\"}}", .{expression});
    const got = try h.call("Runtime.evaluate", params);
    return got.object.get("result").?.object.get("objectId").?.string;
}

/// Formatted params, freed with the test's arena.
fn fmt(h: *Harness, comptime format: []const u8, args: anytype) ![]const u8 {
    return std.fmt.allocPrint(h.arena(), format, args);
}

/// The integers of a JSON array, as "a,b,c".
fn ints(h: *Harness, value: std.json.Value, out: *std.ArrayList(u8)) !void {
    for (value.array.items, 0..) |item, i| try out.print(h.allocator, "{s}{d}", .{ if (i == 0) "" else ",", item.integer });
}

test "getAttributes answers the flattened list; a node that is no element is refused (AssertElement)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const got = try h.call("DOM.getAttributes", "{\"nodeId\":5}");
    try testing.expectEqual(@as(usize, 2), got.object.get("attributes").?.array.items.len);
    try testing.expectEqualStrings("id", got.object.get("attributes").?.array.items[0].string);
    try testing.expectEqualStrings("a", got.object.get("attributes").?.array.items[1].string);
    try testing.expectEqualStrings("Node is not an Element", try h.errorMessage(try h.sendOn(0, "DOM.getAttributes", "{\"nodeId\":7}")));
    try testing.expectEqualStrings("Could not find node with given id", try h.errorMessage(try h.sendOn(0, "DOM.getAttributes", "{\"nodeId\":999}")));
}

test "requestNode pushes the path to a connected node, and a detached node's subtree root as setChildNodes with parent 0, its own path inside it; nothing inside a detached tree is an event until it is inserted (PushNodePathToFrontend)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, 2);
    var from = h.seen.items.len;
    const b = try objectId(&h, "document.getElementById('b')");
    const found = try h.call("DOM.requestNode", try fmt(&h, "{{\"objectId\":\"{s}\"}}", .{b}));
    try testing.expectEqual(@as(i64, 6), found.object.get("nodeId").?.integer);
    try expectEvents(&h, from,
        \\setChildNodes 4 [DIV#5/1{id=a},P#6/0{id=b}]
        \\
    );
    from = h.seen.items.len;
    const i = try objectId(&h, "(() => { const s = document.createElement('section'); const i = document.createElement('i'); s.append(i); window.s = s; return i; })()");
    const detached = try h.call("DOM.requestNode", try fmt(&h, "{{\"objectId\":\"{s}\"}}", .{i}));
    try testing.expectEqual(@as(i64, 8), detached.object.get("nodeId").?.integer);
    try h.run("window.s.append(document.createElement('b')); document.body.append(window.s);");
    // The section's ids are the detached tree's own map's: once in the
    // document it is bound there anew (DidInsertDOMNode's BoundNodeId reads
    // the document's map only).
    try expectEvents(&h, from,
        \\setChildNodes 0 [SECTION#7/1]
        \\setChildNodes 7 [I#8/0]
        \\childNodeInserted 4 6 SECTION#9/2
        \\
    );
    // The detached tree's ids still name its nodes (id_to_node_).
    _ = try h.call("DOM.describeNode", "{\"nodeId\":8}");
}

test "pushNodeByPathToFrontend walks the inner children by index and name and pushes the path (NodeForPath)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    try testing.expectEqualStrings("DOM agent is not enabled", try h.errorMessage(try h.sendOn(0, "DOM.pushNodeByPathToFrontend", "{\"path\":\"0,HTML\"}")));
    _ = try h.call("DOM.getDocument", "{\"depth\":2}");
    const from = h.seen.items.len;
    const got = try h.call("DOM.pushNodeByPathToFrontend", "{\"path\":\"0,HTML,1,BODY,0,DIV\"}");
    try testing.expectEqual(@as(i64, 5), got.object.get("nodeId").?.integer);
    try expectEvents(&h, from,
        \\setChildNodes 4 [DIV#5/1{id=a},P#6/0{id=b}]
        \\
    );
    try testing.expectEqualStrings("No node with given path found", try h.errorMessage(try h.sendOn(0, "DOM.pushNodeByPathToFrontend", "{\"path\":\"0,HTML,1,HEAD\"}")));
    try testing.expectEqualStrings("No node with given path found", try h.errorMessage(try h.sendOn(0, "DOM.pushNodeByPathToFrontend", "{\"path\":\"1,HTML\"}")));
}

test "pushNodesByBackendIdsToFrontend pushes each node of the inspected frames, 0 for an unknown id; the document must be requested first" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    const b = try objectId(&h, "document.getElementById('b')");
    const described = try h.call("DOM.describeNode", try fmt(&h, "{{\"objectId\":\"{s}\"}}", .{b}));
    const backend = described.object.get("node").?.object.get("backendNodeId").?.integer;
    const params = try fmt(&h, "{{\"backendNodeIds\":[{d},999999]}}", .{backend});
    try testing.expectEqualStrings("Document needs to be requested first", try h.errorMessage(try h.sendOn(0, "DOM.pushNodesByBackendIdsToFrontend", params)));
    _ = try h.call("DOM.getDocument", "{\"depth\":2}");
    const from = h.seen.items.len;
    const got = try h.call("DOM.pushNodesByBackendIdsToFrontend", params);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(h.allocator);
    try ints(&h, got.object.get("nodeIds").?, &out);
    try testing.expectEqualStrings("6,0", out.items);
    try expectEvents(&h, from,
        \\setChildNodes 4 [DIV#5/1{id=a},P#6/0{id=b}]
        \\
    );
}

test "getFlattenedDocument binds the whole document anew and answers every node after its descendants, each with its parentId and an empty children list (BuildObjectForNode's flatten_result)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    try testing.expectEqualStrings("DOM agent hasn't been enabled", try h.errorMessage(try h.sendOn(0, "DOM.getFlattenedDocument", "{}")));
    _ = try h.call("DOM.enable", "{}");
    const got = try h.call("DOM.getFlattenedDocument", "{}");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(h.allocator);
    for (got.object.get("nodes").?.array.items) |node| {
        try harness.describe(h.allocator, node, &out);
        if (node.object.get("parentId")) |parent| try out.print(h.allocator, "^{d}", .{parent.integer});
        try out.append(h.allocator, '\n');
    }
    try testing.expectEqualStrings(
        \\HEAD#3/0[]^2
        \\#text#7'x'^6
        \\SPAN#6/1[]^5
        \\DIV#5/1{id=a}[]^4
        \\P#8/0{id=b}[]^4
        \\BODY#4/2[]^2
        \\HTML#2/2[]^1
        \\#document#1/1[]
        \\
    , out.items);
}

test "collectClassNamesFromSubtree collects each class once over the flat tree; a node that is no container is refused" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, "data:text/html,<body><div class='a b'><span class='b c'>x</span></div></body>", null);
    const got = try h.call("DOM.collectClassNamesFromSubtree", "{\"nodeId\":4}");
    var names: std.ArrayList([]const u8) = .empty;
    defer names.deinit(h.allocator);
    for (got.object.get("classNames").?.array.items) |name| try names.append(h.allocator, name.string);
    std.mem.sort([]const u8, names.items, {}, struct {
        fn less(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.less);
    try testing.expectEqual(@as(usize, 3), names.items.len);
    try testing.expectEqualStrings("a", names.items[0]);
    try testing.expectEqualStrings("b", names.items[1]);
    try testing.expectEqualStrings("c", names.items[2]);
    try testing.expectEqualStrings("No suitable node with given id found", try h.errorMessage(try h.sendOn(0, "DOM.collectClassNamesFromSubtree", "{\"nodeId\":7}")));
}

test "getTopLayerElements answers the top layer's elements, their paths pushed" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load("data:text/html,<body><div id=a><span>x</span></div><p id=b></p><dialog id=d></dialog></body>");
    try testing.expectEqualStrings("DOM agent hasn't been enabled", try h.errorMessage(try h.sendOn(0, "DOM.getTopLayerElements", "{}")));
    _ = try h.call("DOM.getDocument", "{\"depth\":2}");
    const from = h.seen.items.len;
    // showModal changes the top layer (TopLayerElementsChanged, at once);
    // the rendering update after it gives the dialog its ::backdrop, and an
    // element with pseudo-elements is sent with its children array, empty
    // here (BuildObjectForNode's force_push_children).
    try h.run("document.getElementById('d').showModal();");
    try h.settle();
    const got = try h.call("DOM.getTopLayerElements", "{}");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(h.allocator);
    try ints(&h, got.object.get("nodeIds").?, &out);
    try testing.expectEqualStrings("7", out.items);
    try expectEvents(&h, from,
        \\topLayerElementsUpdated
        \\setChildNodes 4 [DIV#5/1{id=a},P#6/0{id=b},DIALOG#7/0{id=d,open=}[]<::backdrop#8/0 backdrop>]
        \\
    );
}

test "performSearch finds by selector, by text and names, and by XPath; getSearchResults pushes a range; discardSearchResults forgets the search" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    try testing.expectEqualStrings("DOM agent is not enabled", try h.errorMessage(try h.sendOn(0, "DOM.performSearch", "{\"query\":\"span\"}")));
    _ = try h.call("DOM.getDocument", "{\"depth\":2}");
    const search = try h.call("DOM.performSearch", "{\"query\":\"span\"}");
    try testing.expectEqual(@as(i64, 1), search.object.get("resultCount").?.integer);
    const id = search.object.get("searchId").?.string;
    // IdentifiersFactory::CreateIdentifier: "<process>.<n>".
    try testing.expect(std.mem.indexOfScalar(u8, id, '.') != null);
    const from = h.seen.items.len;
    const range = try fmt(&h, "{{\"searchId\":\"{s}\",\"fromIndex\":0,\"toIndex\":1}}", .{id});
    const results = try h.call("DOM.getSearchResults", range);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(h.allocator);
    try ints(&h, results.object.get("nodeIds").?, &out);
    try testing.expectEqualStrings("7", out.items);
    try expectEvents(&h, from,
        \\setChildNodes 4 [DIV#5/1{id=a},P#6/0{id=b}]
        \\setChildNodes 5 [SPAN#7/1[#text#8'x']]
        \\
    );
    const bad = try fmt(&h, "{{\"searchId\":\"{s}\",\"fromIndex\":0,\"toIndex\":2}}", .{id});
    try testing.expectEqualStrings("Invalid search result range", try h.errorMessage(try h.sendOn(0, "DOM.getSearchResults", bad)));
    // Text: the text node; an exact quoted attribute value; an XPath.
    try testing.expectEqual(@as(i64, 1), (try h.call("DOM.performSearch", "{\"query\":\"x\"}")).object.get("resultCount").?.integer);
    try testing.expectEqual(@as(i64, 1), (try h.call("DOM.performSearch", "{\"query\":\"\\\"a\\\"\"}")).object.get("resultCount").?.integer);
    try testing.expectEqual(@as(i64, 1), (try h.call("DOM.performSearch", "{\"query\":\"//p\"}")).object.get("resultCount").?.integer);
    try testing.expectEqual(@as(i64, 1), (try h.call("DOM.performSearch", "{\"query\":\"<div>\"}")).object.get("resultCount").?.integer);
    _ = try h.call("DOM.discardSearchResults", try fmt(&h, "{{\"searchId\":\"{s}\"}}", .{id}));
    try testing.expectEqualStrings("No search session with given id found", try h.errorMessage(try h.sendOn(0, "DOM.getSearchResults", range)));
}

test "focus focuses a focusable element as a user would; another element is refused (InspectorDOMAgent::focus)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    // INPUT#c is 9.
    try setUp(&h, "data:text/html,<body><div id=a><span>x</span></div><p id=b></p><input id=c></body>", null);
    _ = try h.call("DOM.focus", "{\"nodeId\":9}");
    const active = try h.call("Runtime.evaluate", "{\"expression\":\"document.activeElement.id\"}");
    try testing.expectEqualStrings("c", active.object.get("result").?.object.get("value").?.string);
    try testing.expectEqualStrings("Element is not focusable", try h.errorMessage(try h.sendOn(0, "DOM.focus", "{\"nodeId\":5}")));
    try testing.expectEqualStrings("Node is not an Element", try h.errorMessage(try h.sendOn(0, "DOM.focus", "{\"nodeId\":7}")));
}

/// Whether DOM.describeNode on session `index` still finds `backend_id`.
fn alive(h: *Harness, index: usize, backend_id: i64) !bool {
    const id = try h.sendOn(index, "DOM.describeNode", try fmt(h, "{{\"backendNodeId\":{d}}}", .{backend_id}));
    _ = h.result(id) catch |err| switch (err) {
        error.CommandFailed => return false,
        else => return err,
    };
    return true;
}

test "a search holds its nodes while its session lives - removed and dropped by the page, they stay - and a session ended mid-search lets every one go (main's D1: Blink's search_results_ are Member<Node>)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.attach(1);
    try h.load(page);
    _ = try h.call("DOM.getDocument", "{\"depth\":-1}");
    try h.run("for (let i = 0; i < 3; i++) document.body.append(document.createElement('em'));");
    const search = try h.call("DOM.performSearch", "{\"query\":\"<em>\"}");
    try testing.expectEqual(@as(i64, 3), search.object.get("resultCount").?.integer);
    const id = search.object.get("searchId").?.string;
    const results = try h.call("DOM.getSearchResults", try fmt(&h, "{{\"searchId\":\"{s}\",\"fromIndex\":0,\"toIndex\":3}}", .{id}));
    var backend_ids: [3]i64 = undefined;
    for (results.object.get("nodeIds").?.array.items, &backend_ids) |node_id, *backend| {
        const described = try h.call("DOM.describeNode", try fmt(&h, "{{\"nodeId\":{d}}}", .{node_id.integer}));
        backend.* = described.object.get("node").?.object.get("backendNodeId").?.integer;
    }
    // The page lets them go; the search does not.
    try h.run("document.querySelectorAll('em').forEach((e) => e.remove());");
    for (0..3) |_| try h.run("TestUtils.gc(); TestUtils.gc();");
    for (backend_ids) |backend| try testing.expect(try alive(&h, 1, backend));
    // Session 1 ends with the search; every node goes with the next
    // collections (freed from the event loop's teardown slices).
    h.detach(0);
    _ = try h.callOn(1, "Page.getFrameTree", "{}");
    var gone: usize = 0;
    for (0..50) |_| {
        try h.run("TestUtils.gc(); TestUtils.gc();");
        gone = 0;
        for (backend_ids) |backend| {
            if (!try alive(&h, 1, backend)) gone += 1;
        }
        if (gone == backend_ids.len) break;
    }
    try testing.expectEqual(backend_ids.len, gone);
}

test "DOM.focus runs the focus() steps a user gesture takes: the caret goes to an editing host's start before it is focused (Element::Focus with FocusTrigger::kUserGesture -> UpdateSelectionOnFocus)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    // DIV#e 5, "abc" 6, P#b 7, "x" 8.
    try setUp(&h, "data:text/html,<body><div id=e contenteditable>abc</div><p id=b>x</p></body>", null);
    try h.run("getSelection().collapse(document.getElementById('b').firstChild, 1);");
    _ = try h.call("DOM.focus", "{\"nodeId\":5}");
    const got = try h.call("Runtime.evaluate", "{\"expression\":\"document.activeElement.id + ':' + document.getElementById('e').contains(getSelection().anchorNode) + ':' + getSelection().anchorOffset\"}");
    try testing.expectEqualStrings("e:true:0", got.object.get("result").?.object.get("value").?.string);
}

test "node stack traces: with setNodeStackTracesEnabled a node made by script has its creation stack, one made by the parser none (NodeCreated, getNodeStackTraces)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    _ = try h.call("DOM.setNodeStackTracesEnabled", "{\"enable\":true}");
    const from = h.seen.items.len;
    _ = try h.call("Runtime.evaluate", "{\"expression\":\"function makeIt() { document.getElementById('b').appendChild(document.createElement('i')); } makeIt();\"}");
    try expectEvents(&h, from,
        \\childNodeInserted 8 0 I#9/0
        \\
    );
    const traces = try h.call("DOM.getNodeStackTraces", "{\"nodeId\":9}");
    const frames = traces.object.get("creation").?.object.get("callFrames").?.array.items;
    try testing.expect(frames.len >= 1);
    try testing.expectEqualStrings("makeIt", frames[0].object.get("functionName").?.string);
    const parsed = try h.call("DOM.getNodeStackTraces", "{\"nodeId\":5}");
    try testing.expect(parsed.object.get("creation") == null);
}

test "container queries: getContainerForNode finds the named query container; getQueryingDescendantsForContainer the descendants whose matched @container rules query it (FindContainerForElement, ContainerQueriedByElement)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    // #document 1, HTML 2, HEAD 3, STYLE 4, its text 5, BODY 6, DIV.cc 7,
    // P.q 8, "x" 9, P 10, "y" 11.
    try setUp(&h, "data:text/html,<style>.cc{container-name:card;--x:1}@container card style(--x: 1){.q{color:red}}</style><body><div class=cc><p class=q>x</p><p>y</p></div></body>", null);
    const found = try h.call("DOM.getContainerForNode", "{\"nodeId\":8,\"containerName\":\"card\"}");
    try testing.expectEqual(@as(i64, 7), found.object.get("nodeId").?.integer);
    const none = try h.call("DOM.getContainerForNode", "{\"nodeId\":7,\"containerName\":\"card\"}");
    try testing.expect(none.object.get("nodeId") == null);
    const querying = try h.call("DOM.getQueryingDescendantsForContainer", "{\"nodeId\":7}");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(h.allocator);
    try ints(&h, querying.object.get("nodeIds").?, &out);
    try testing.expectEqualStrings("8", out.items);
}
