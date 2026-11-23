//! The live DOM over CDP (lane cdpd1, batch 3; roadmap cdp-live-dom): the
//! DOM-domain edits and their history - Blink's InspectorDOMAgent edits over
//! DOMEditor and InspectorHistory (inspector_dom_agent.cc, dom_editor.cc,
//! inspector_history.cc, dom_patch_support.cc at Chrome 157.0.8103.78):
//! setAttributeValue, setAttributesAsText, removeAttribute, setNodeValue,
//! setNodeName, removeNode, setOuterHTML, moveTo, copyTo, undo, redo,
//! markUndoableState. Every edit runs through the DOM's algorithms, so the
//! session hears its own edits as mutation events and the page's mutation
//! observers see them.
//!
//! The page and its node ids are the harness's (cdpd1_harness.zig):
//!     #document 1, HTML 2, HEAD 3, BODY 4, DIV#a 5, SPAN 6, "x" 7, P#b 8

const std = @import("std");
const testing = std.testing;
const harness = @import("cdpd1_harness.zig");
const Harness = harness.Harness;
const page = harness.page;
const setUp = harness.setUp;
const expectEvents = harness.expectEvents;

fn fmt(h: *Harness, comptime format: []const u8, args: anytype) ![]const u8 {
    return std.fmt.allocPrint(h.arena(), format, args);
}

test "setAttributeValue and removeAttribute are attribute events, and undo / redo take them back and again (SetAttributeAction, RemoveAttributeAction)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    _ = try h.call("DOM.setAttributeValue", "{\"nodeId\":5,\"name\":\"title\",\"value\":\"t\"}");
    _ = try h.call("DOM.undo", "{}");
    _ = try h.call("DOM.redo", "{}");
    _ = try h.call("DOM.removeAttribute", "{\"nodeId\":5,\"name\":\"id\"}");
    _ = try h.call("DOM.undo", "{}");
    // With no undoable-state mark, an undo goes back to the start of the
    // history (InspectorHistory::Undo stops only at a mark): it takes back
    // the removal and then the setting before it. The front end marks after
    // each edit (markUndoableState), and so undoes one at a time.
    try expectEvents(&h, from,
        \\attributeModified 5 title=t
        \\attributeRemoved 5 title
        \\attributeModified 5 title=t
        \\attributeRemoved 5 id
        \\attributeModified 5 id=a
        \\attributeRemoved 5 title
        \\
    );
}

test "markUndoableState groups edits: undo goes back to the previous mark, redo forward to the next" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    _ = try h.call("DOM.setAttributeValue", "{\"nodeId\":5,\"name\":\"a\",\"value\":\"1\"}");
    _ = try h.call("DOM.markUndoableState", "{}");
    _ = try h.call("DOM.setAttributeValue", "{\"nodeId\":5,\"name\":\"b\",\"value\":\"2\"}");
    _ = try h.call("DOM.setAttributeValue", "{\"nodeId\":5,\"name\":\"c\",\"value\":\"3\"}");
    var from = h.seen.items.len;
    _ = try h.call("DOM.undo", "{}");
    try expectEvents(&h, from,
        \\attributeRemoved 5 c
        \\attributeRemoved 5 b
        \\
    );
    from = h.seen.items.len;
    _ = try h.call("DOM.redo", "{}");
    try expectEvents(&h, from,
        \\attributeModified 5 b=2
        \\attributeModified 5 c=3
        \\
    );
}

test "setAttributesAsText sets each parsed attribute and removes the named one it no longer has" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    _ = try h.call("DOM.setAttributesAsText", "{\"nodeId\":5,\"text\":\"TITLE='x' lang=en\",\"name\":\"id\"}");
    try expectEvents(&h, from,
        \\attributeModified 5 title=x
        \\attributeModified 5 lang=en
        \\attributeRemoved 5 id
        \\
    );
}

test "setNodeValue changes a text node's data; other nodes are refused" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    _ = try h.call("DOM.setNodeValue", "{\"nodeId\":7,\"value\":\"zz\"}");
    try expectEvents(&h, from,
        \\characterDataModified 7 zz
        \\
    );
    try testing.expectEqualStrings("Can only set value of text nodes or processing instructions", try h.errorMessage(try h.sendOn(0, "DOM.setNodeValue", "{\"nodeId\":5,\"value\":\"zz\"}")));
}

test "removeNode removes, and undo puts the same node back where it was (RemoveChildAction)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    _ = try h.call("DOM.removeNode", "{\"nodeId\":8}");
    _ = try h.call("DOM.undo", "{}");
    try expectEvents(&h, from,
        \\childNodeRemoved 4 8
        \\childNodeInserted 4 5 P#9/0{id=b}
        \\
    );
    const same = try h.call("Runtime.evaluate", "{\"expression\":\"document.body.lastChild.id\"}");
    try testing.expectEqualStrings("b", same.object.get("result").?.object.get("value").?.string);
}

test "setNodeName replaces an element with a new one of that name, its attributes and children moved; the old node's removal unbound it, so its children are not pushed again (InspectorDOMAgent::setNodeName)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    const got = try h.call("DOM.setNodeName", "{\"nodeId\":5,\"name\":\"section\"}");
    try testing.expectEqual(@as(i64, 9), got.object.get("nodeId").?.integer);
    try expectEvents(&h, from,
        \\childNodeRemoved 5 6
        \\childNodeInserted 4 5 SECTION#9/1{id=a}
        \\childNodeRemoved 4 5
        \\
    );
}

test "moveTo moves a node into a target before an anchor; a node cannot move into itself (InsertBeforeAction)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    try testing.expectEqualStrings("Unable to move node into self or descendant", try h.errorMessage(try h.sendOn(0, "DOM.moveTo", "{\"nodeId\":5,\"targetNodeId\":6}")));
    const from = h.seen.items.len;
    const got = try h.call("DOM.moveTo", "{\"nodeId\":8,\"targetNodeId\":5}");
    try testing.expectEqual(@as(i64, 9), got.object.get("nodeId").?.integer);
    _ = try h.call("DOM.undo", "{}");
    try expectEvents(&h, from,
        \\childNodeRemoved 4 8
        \\childNodeInserted 5 6 P#9/0{id=b}
        \\childNodeRemoved 5 9
        \\childNodeInserted 4 5 P#10/0{id=b}
        \\
    );
}

test "copyTo inserts a deep clone (InspectorDOMAgent::copyTo)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    const got = try h.call("DOM.copyTo", "{\"nodeId\":6,\"targetNodeId\":8}");
    try testing.expectEqual(@as(i64, 9), got.object.get("nodeId").?.integer);
    try expectEvents(&h, from,
        \\childNodeInserted 8 0 SPAN#9/1[#text#10'x']
        \\
    );
}

test "setOuterHTML patches the least it can: a changed child is merged into the old node, which keeps its id; a renamed one is replaced; undo takes the patch back (DOMPatchSupport)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    var from = h.seen.items.len;
    _ = try h.call("DOM.setOuterHTML", "{\"nodeId\":8,\"outerHTML\":\"<p id=b>new</p>\"}");
    try expectEvents(&h, from,
        \\childNodeInserted 8 0 #text#9'new'
        \\
    );
    from = h.seen.items.len;
    _ = try h.call("DOM.undo", "{}");
    try expectEvents(&h, from,
        \\childNodeRemoved 8 9
        \\
    );
    from = h.seen.items.len;
    _ = try h.call("DOM.setOuterHTML", "{\"nodeId\":6,\"outerHTML\":\"<b>q</b>\"}");
    try expectEvents(&h, from,
        \\childNodeRemoved 5 6
        \\childNodeInserted 5 0 B#10/1[#text#11'q']
        \\
    );
}

test "an edit is seen by the page's mutation observers, as any DOM change" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    try h.run("window.seen = []; new MutationObserver((records) => { for (const r of records) seen.push(r.type + ':' + (r.attributeName || '')); }).observe(document.body, { subtree: true, attributes: true, childList: true });");
    _ = try h.call("DOM.setAttributeValue", "{\"nodeId\":5,\"name\":\"title\",\"value\":\"t\"}");
    _ = try h.call("DOM.removeNode", "{\"nodeId\":8}");
    const got = try h.call("Runtime.evaluate", "{\"expression\":\"new Promise((resolve) => setTimeout(() => resolve(seen.join(',')), 0))\",\"awaitPromise\":true}");
    try testing.expectEqualStrings("attributes:title,childList:", got.object.get("result").?.object.get("value").?.string);
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

test "the history holds what an undo could put back - a removed node the page dropped stays - and lets it go when the agent is disabled (main's D1: Blink's actions hold Member<Node>)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const described = try h.call("DOM.describeNode", "{\"nodeId\":8}");
    const backend = described.object.get("node").?.object.get("backendNodeId").?.integer;
    _ = try h.call("DOM.removeNode", "{\"nodeId\":8}");
    for (0..3) |_| try h.run("TestUtils.gc(); TestUtils.gc();");
    try testing.expect(try alive(&h, 0, backend));
    _ = try h.call("DOM.disable", "{}");
    var gone = false;
    for (0..50) |_| {
        try h.run("TestUtils.gc(); TestUtils.gc();");
        if (!try alive(&h, 0, backend)) {
            gone = true;
            break;
        }
    }
    try testing.expect(gone);
}

test "undo, redo and markUndoableState are refused while the agent is not enabled" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    try testing.expectEqualStrings("DOM agent is not enabled", try h.errorMessage(try h.sendOn(0, "DOM.undo", "{}")));
    try testing.expectEqualStrings("DOM agent is not enabled", try h.errorMessage(try h.sendOn(0, "DOM.redo", "{}")));
    try testing.expectEqualStrings("DOM agent is not enabled", try h.errorMessage(try h.sendOn(0, "DOM.markUndoableState", "{}")));
}
