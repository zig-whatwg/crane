//! The Accessibility domain's commands, their shape and their errors (lane
//! a11y1, batch 1; design tmp/plans/a11y1-design.md): what chrome-devtools-mcp's
//! take_snapshot, uids and wait_for rely on (main, 4:58 PM ET 2026-11-23),
//! each checked on its own here; the trees themselves are compared with
//! Chrome 157's in a11y1_chrome_trace_test.zig.
//!
//! Blink's InspectorAccessibilityAgent (inspector_accessibility_agent.cc at
//! Chrome 157.0.8103.78) is the reference for every message.

const std = @import("std");
const testing = std.testing;
const harness = @import("cdpd1_harness.zig");
const Harness = harness.Harness;

const page = "data:text/html,<!doctype html><title>T</title><h1>Hello world</h1><button>Click me</button>" ++
    "<input type=checkbox checked aria-label=Agree><input disabled aria-label=Off>" ++
    "<div style=display:none><span>gone</span></div><iframe srcdoc='<button>In frame</button>'></iframe>";

fn fmt(h: *Harness, comptime format: []const u8, args: anytype) ![]const u8 {
    return std.fmt.allocPrint(h.arena(), format, args);
}

/// The backendNodeId of what `expression` evaluates to.
fn backendOf(h: *Harness, expression: []const u8) !i64 {
    const object = try h.call("Runtime.evaluate", try fmt(h, "{{\"expression\":\"{s}\"}}", .{expression}));
    const id = object.object.get("result").?.object.get("objectId").?.string;
    const described = try h.call("DOM.describeNode", try fmt(h, "{{\"objectId\":\"{s}\"}}", .{id}));
    return described.object.get("node").?.object.get("backendNodeId").?.integer;
}

fn str(value: std.json.Value, comptime path: []const u8) ?[]const u8 {
    var at = value;
    var it = std.mem.splitScalar(u8, path, '.');
    while (it.next()) |key| at = (if (at == .object) at.object.get(key) else null) orelse return null;
    return if (at == .string) at.string else null;
}

fn property(node: std.json.Value, name: []const u8) ?std.json.Value {
    const list = node.object.get("properties") orelse return null;
    for (list.array.items) |p| if (std.mem.eql(u8, p.object.get("name").?.string, name)) return p.object.get("value").?.object.get("value");
    return null;
}

fn findByName(nodes: std.json.Value, name: []const u8) ?std.json.Value {
    for (nodes.array.items) |n| if (str(n, "name.value")) |v| if (std.mem.eql(u8, v, name)) return n;
    return null;
}

test "getFullAXTree: the root first (RootWebArea, with the frame's id), each node's id its DOM node's backendNodeId, children and parents consistent" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    const got = try h.call("Accessibility.getFullAXTree", "{}");
    const nodes = got.object.get("nodes").?;
    const root = nodes.array.items[0];
    try testing.expectEqualStrings("RootWebArea", str(root, "role.value").?);
    try testing.expectEqualStrings("internalRole", str(root, "role.type").?);
    try testing.expectEqualStrings("T", str(root, "name.value").?);
    try testing.expect(root.object.get("frameId") != null);
    try testing.expect(root.object.get("parentId") == null);
    var ids: std.StringHashMapUnmanaged(void) = .empty;
    defer ids.deinit(testing.allocator);
    for (nodes.array.items) |n| try ids.put(testing.allocator, n.object.get("nodeId").?.string, {});
    for (nodes.array.items, 0..) |n, i| {
        const id = n.object.get("nodeId").?.string;
        if (n.object.get("backendDOMNodeId")) |backend| {
            try testing.expectEqualStrings(try fmt(&h, "{d}", .{backend.integer}), id);
        } else {
            // Nodeless objects have Chrome's generated negative ids.
            try testing.expect(std.mem.startsWith(u8, id, "-"));
        }
        if (i != 0) try testing.expect(ids.contains(n.object.get("parentId").?.string));
        for (n.object.get("childIds").?.array.items) |child| try testing.expect(ids.contains(child.string));
    }
    // The button, by its name, is the DOM's own node.
    const button = findByName(nodes, "Click me") orelse return error.NoButton;
    try testing.expectEqualStrings("button", str(button, "role.value").?);
    try testing.expectEqual(try backendOf(&h, "document.querySelector('button')"), button.object.get("backendDOMNodeId").?.integer);
    try testing.expect(!button.object.get("ignored").?.bool);
    // States: a checked checkbox, a disabled field, a heading's level.
    const checkbox = findByName(nodes, "Agree") orelse return error.NoCheckbox;
    try testing.expectEqualStrings("true", property(checkbox, "checked").?.string);
    const off = findByName(nodes, "Off") orelse return error.NoField;
    try testing.expect(property(off, "disabled").?.bool);
    const heading = findByName(nodes, "Hello world") orelse return error.NoHeading;
    try testing.expectEqual(@as(i64, 1), property(heading, "level").?.integer);
    // display:none content is not in the tree.
    try testing.expect(findByName(nodes, "gone") == null);
}

test "getFullAXTree: an iframe has no children in its parent's tree; its frame's tree is its own, by frameId" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    const main = (try h.call("Accessibility.getFullAXTree", "{}")).object.get("nodes").?;
    var iframe: ?std.json.Value = null;
    for (main.array.items) |n| if (str(n, "role.value")) |r| if (std.mem.eql(u8, r, "Iframe")) {
        iframe = n;
    };
    try testing.expectEqual(@as(usize, 0), iframe.?.object.get("childIds").?.array.items.len);
    try testing.expect(findByName(main, "In frame") == null);
    const tree = try h.call("Page.getFrameTree", "{}");
    const child = tree.object.get("frameTree").?.object.get("childFrames").?.array.items[0];
    const frame_id = str(child, "frame.id").?;
    const inner = (try h.call("Accessibility.getFullAXTree", try fmt(&h, "{{\"frameId\":\"{s}\"}}", .{frame_id}))).object.get("nodes").?;
    try testing.expectEqualStrings("RootWebArea", str(inner.array.items[0], "role.value").?);
    try testing.expectEqualStrings(frame_id, str(inner.array.items[0], "frameId").?);
    try testing.expect(findByName(inner, "In frame") != null);
    try testing.expectEqualStrings("Frame with the given frameId is not found.", try h.errorMessage(try h.sendOn(0, "Accessibility.getFullAXTree", "{\"frameId\":\"NOPE\"}")));
}

test "queryAXTree: by name, by role, by both, from an object - each match with its backendDOMNodeId" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    const doc = (try h.call("Runtime.evaluate", "{\"expression\":\"document\"}")).object.get("result").?.object.get("objectId").?.string;
    const by_name = (try h.call("Accessibility.queryAXTree", try fmt(&h, "{{\"objectId\":\"{s}\",\"accessibleName\":\"Click me\"}}", .{doc}))).object.get("nodes").?;
    var buttons: usize = 0;
    for (by_name.array.items) |n| if (std.mem.eql(u8, str(n, "role.value").?, "button")) {
        buttons += 1;
        try testing.expectEqual(try backendOf(&h, "document.querySelector('button')"), n.object.get("backendDOMNodeId").?.integer);
    };
    try testing.expectEqual(@as(usize, 1), buttons);
    const both = (try h.call("Accessibility.queryAXTree", try fmt(&h, "{{\"objectId\":\"{s}\",\"accessibleName\":\"Click me\",\"role\":\"button\"}}", .{doc}))).object.get("nodes").?;
    try testing.expectEqual(@as(usize, 1), both.array.items.len);
    const headings = (try h.call("Accessibility.queryAXTree", try fmt(&h, "{{\"objectId\":\"{s}\",\"role\":\"heading\"}}", .{doc}))).object.get("nodes").?;
    try testing.expectEqual(@as(usize, 1), headings.array.items.len);
    try testing.expectEqualStrings("Hello world", str(headings.array.items[0], "name.value").?);
    try testing.expectEqualStrings("Either nodeId, backendNodeId or objectId must be specified", try h.errorMessage(try h.sendOn(0, "Accessibility.queryAXTree", "{\"accessibleName\":\"x\"}")));
}

test "the commands that need enable refuse without it; enabled, root, children and ancestors answer" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    try testing.expectEqualStrings("Accessibility has not been enabled.", try h.errorMessage(try h.sendOn(0, "Accessibility.getRootAXNode", "{}")));
    try testing.expectEqualStrings("Accessibility has not been enabled.", try h.errorMessage(try h.sendOn(0, "Accessibility.getChildAXNodes", "{\"id\":\"1\"}")));
    try testing.expectEqualStrings("Accessibility has not been enabled.", try h.errorMessage(try h.sendOn(0, "Accessibility.getAXNodeAndAncestors", "{\"backendNodeId\":1}")));
    _ = try h.call("Accessibility.enable", "{}");
    const root = (try h.call("Accessibility.getRootAXNode", "{}")).object.get("node").?;
    try testing.expectEqualStrings("RootWebArea", str(root, "role.value").?);
    const root_id = root.object.get("nodeId").?.string;
    const children = (try h.call("Accessibility.getChildAXNodes", try fmt(&h, "{{\"id\":\"{s}\"}}", .{root_id}))).object.get("nodes").?;
    try testing.expect(children.array.items.len > 0);
    try testing.expectEqualStrings(root_id, children.array.items[0].object.get("parentId").?.string);
    try testing.expectEqualStrings("Invalid ID", try h.errorMessage(try h.sendOn(0, "Accessibility.getChildAXNodes", "{\"id\":\"bogus\"}")));
    const button = try backendOf(&h, "document.querySelector('button')");
    const chain = (try h.call("Accessibility.getAXNodeAndAncestors", try fmt(&h, "{{\"backendNodeId\":{d}}}", .{button}))).object.get("nodes").?;
    try testing.expectEqual(button, chain.array.items[0].object.get("backendDOMNodeId").?.integer);
    try testing.expectEqualStrings("RootWebArea", str(chain.array.items[chain.array.items.len - 1], "role.value").?);
    _ = try h.call("Accessibility.disable", "{}");
    try testing.expectEqualStrings("Accessibility has not been enabled.", try h.errorMessage(try h.sendOn(0, "Accessibility.getRootAXNode", "{}")));
}

test "getPartialAXTree: the node alone without relatives; a display:none node's object is ignored, not rendered; a node with no object (in <head>) stands in with id 0" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.load(page);
    const button = try backendOf(&h, "document.querySelector('button')");
    const alone = (try h.call("Accessibility.getPartialAXTree", try fmt(&h, "{{\"backendNodeId\":{d},\"fetchRelatives\":false}}", .{button}))).object.get("nodes").?;
    try testing.expectEqual(@as(usize, 1), alone.array.items.len);
    try testing.expectEqualStrings("button", str(alone.array.items[0], "role.value").?);
    // Blink has an object for a display:none element (not in the tree):
    // its own id, ignored as not rendered (Chrome 157: the trace's hidden
    // page, step partial-none).
    const span = try backendOf(&h, "document.querySelector('span')");
    const hidden = (try h.call("Accessibility.getPartialAXTree", try fmt(&h, "{{\"backendNodeId\":{d}}}", .{span}))).object.get("nodes").?;
    const object = hidden.array.items[0];
    try testing.expectEqualStrings(try fmt(&h, "{d}", .{span}), object.object.get("nodeId").?.string);
    try testing.expect(object.object.get("ignored").?.bool);
    try testing.expectEqualStrings("notRendered", object.object.get("ignoredReasons").?.array.items[0].object.get("name").?.string);
    // A <title> gets no object at all (IsSubtreePrunedForAccessibility):
    // BuildProtocolAXNodeForDOMNodeWithNoAXNode's stand-in, id 0.
    const title = try backendOf(&h, "document.querySelector('title')");
    const missing = (try h.call("Accessibility.getPartialAXTree", try fmt(&h, "{{\"backendNodeId\":{d}}}", .{title}))).object.get("nodes").?;
    const stand_in = missing.array.items[0];
    try testing.expectEqualStrings("0", stand_in.object.get("nodeId").?.string);
    try testing.expect(stand_in.object.get("ignored").?.bool);
    try testing.expectEqualStrings("notRendered", stand_in.object.get("ignoredReasons").?.array.items[0].object.get("name").?.string);
    try testing.expectEqual(title, stand_in.object.get("backendDOMNodeId").?.integer);
}
