//! The live DOM over CDP (lane cdpd1, batch 1; roadmap cdp-live-dom): the
//! DOM-domain events a DOM-enabled session is sent when the page mutates its
//! tree, in Chrome's order and shape - Blink's InspectorDOMAgent
//! (third_party/blink/renderer/core/inspector/inspector_dom_agent.cc at
//! Chrome 157.0.8103.78: DidInsertDOMNode, WillRemoveDOMNode /
//! DOMNodeRemoved, DidModifyDOMAttr, DidRemoveDOMAttr, CharacterDataModified,
//! DidInvalidateStyleAttr, DidPushShadowRoot, TopLayerElementsChanged,
//! InvalidateFrameOwnerElement).
//!
//! Through page sessions attached to a Browser on its own thread, with no
//! transport (the cdph harness's shape): what is checked is what a client
//! would be sent. Each expected node id follows Blink's bind order: getDocument
//! binds depth-first in tree order from 1, and every node an event pushes
//! takes the next id.
//!
//! Every test page is
//!     <body><div id=a><span>x</span></div><p id=b></p></body>
//! (no doctype, no whitespace), which DOM.getDocument {depth: -1} binds as
//!     #document 1, HTML 2, HEAD 3, BODY 4, DIV#a 5, SPAN 6, "x" 7, P#b 8
//! unless the test says otherwise.

const std = @import("std");
const testing = std.testing;
const devtools = @import("devtools");
const browser_mod = @import("browser");
const BrowserHost = browser_mod.BrowserHost;
const outbound = devtools.outbound;

const page = "data:text/html,<body><div id=a><span>x</span></div><p id=b></p></body>";

/// A Browser on its own thread with page sessions on one tab, and the
/// messages they send.
const Harness = struct {
    allocator: std.mem.Allocator,
    host: *BrowserHost,
    queue: *outbound.Outbound,
    side: *devtools.BrowserSide,
    links: [2]?*outbound.SessionLink = .{ null, null },
    sessions: [2]?*devtools.PageSession = .{ null, null },
    tab: u64,
    next_id: i64 = 1,
    /// Messages read so far, parsed, OWNED.
    seen: std.ArrayList(std.json.Parsed(std.json.Value)) = .empty,

    const session_names = [2][]const u8{ "SESSION1", "SESSION2" };

    fn init(self: *Harness, allocator: std.mem.Allocator) !void {
        self.* = .{ .allocator = allocator, .host = undefined, .queue = undefined, .side = undefined, .tab = 0 };
        self.host = try BrowserHost.start(allocator, .{});
        self.queue = try outbound.Outbound.create(allocator);
        var context_id: [32]u8 = undefined;
        @memset(&context_id, 'C');
        var sink_context: u8 = 0;
        self.side = try devtools.BrowserSide.create(allocator, self.host, 0xC0FFEE, context_id, .{ .context = &sink_context, .post = sinkPost });
        try devtools.browser_side.InstallTask.post(self.side);
        self.tab = try self.host.createTab(.{});
        try self.attach(0);
    }

    /// Attach session `index` (0 or 1) to the tab.
    fn attach(self: *Harness, index: usize) !void {
        const link = try outbound.SessionLink.create(self.allocator, self.queue, session_names[index]);
        self.links[index] = link;
        const session = try devtools.PageSession.allocate(self.allocator, link, self.tab, devtools.ids.frameId(0xC0FFEE, self.tab));
        self.sessions[index] = session;
        try devtools.browser_side.AttachTask.post(self.side, session);
    }

    /// Detach session `index`.
    fn detach(self: *Harness, index: usize) void {
        const session = self.sessions[index] orelse return;
        devtools.browser_side.DetachTask.post(self.side, session);
        self.sessions[index] = null;
    }

    fn sinkPost(context: *anyopaque, side: *devtools.BrowserSide, event: devtools.browser_side.TargetEvent) void {
        _ = context;
        switch (event) {
            .navigated => |navigated| side.allocator.free(navigated.url),
            .title_changed => |changed| side.allocator.free(changed.title),
            else => {},
        }
    }

    fn deinit(self: *Harness) void {
        for (0..2) |i| self.detach(i);
        devtools.browser_side.uninstallAndWait(self.side);
        self.host.stop();
        self.side.destroy();
        for (self.links) |link| if (link) |l| l.release();
        self.drain();
        self.queue.release();
        for (self.seen.items) |*parsed| parsed.deinit();
        self.seen.deinit(self.allocator);
    }

    fn sendOn(self: *Harness, index: usize, method: []const u8, params_json: []const u8) !i64 {
        const id = self.next_id;
        self.next_id += 1;
        const message = try std.fmt.allocPrint(self.allocator, "{{\"id\":{d},\"method\":\"{s}\",\"params\":{s},\"sessionId\":\"{s}\"}}", .{ id, method, params_json, session_names[index] });
        defer self.allocator.free(message);
        try devtools.browser_side.MessageTask.post(self.side, self.sessions[index].?, message);
        return id;
    }

    fn drain(self: *Harness) void {
        var items: std.ArrayList(outbound.Item) = .empty;
        defer items.deinit(self.allocator);
        _ = self.queue.takeAll(&items) catch return;
        for (items.items) |item| {
            defer self.allocator.free(item.bytes);
            const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, item.bytes, .{}) catch continue;
            self.seen.append(self.allocator, parsed) catch {};
        }
    }

    /// The response to `id` (10 s): its result, or error.CommandFailed.
    fn result(self: *Harness, id: i64) !std.json.Value {
        var waited: u32 = 0;
        while (waited < 10_000) : (waited += 10) {
            self.drain();
            for (self.seen.items) |parsed| {
                const object = parsed.value.object;
                const got = object.get("id") orelse continue;
                if (got != .integer or got.integer != id) continue;
                if (object.get("error")) |_| return error.CommandFailed;
                return object.get("result") orelse error.NoResult;
            }
            self.queue.wait(10 * std.time.ns_per_ms);
        }
        return error.Timeout;
    }

    /// The error message the response to `id` carries.
    fn errorMessage(self: *Harness, id: i64) ![]const u8 {
        var waited: u32 = 0;
        while (waited < 10_000) : (waited += 10) {
            self.drain();
            for (self.seen.items) |parsed| {
                const object = parsed.value.object;
                const got = object.get("id") orelse continue;
                if (got != .integer or got.integer != id) continue;
                const err = object.get("error") orelse return error.NoError;
                return err.object.get("message").?.string;
            }
            self.queue.wait(10 * std.time.ns_per_ms);
        }
        return error.Timeout;
    }

    fn call(self: *Harness, method: []const u8, params_json: []const u8) !std.json.Value {
        return self.result(try self.sendOn(0, method, params_json));
    }

    fn callOn(self: *Harness, index: usize, method: []const u8, params_json: []const u8) !std.json.Value {
        return self.result(try self.sendOn(index, method, params_json));
    }

    /// Wait (10 s) for an event `method` at or after index `from` of `seen`.
    fn waitEvent(self: *Harness, method: []const u8, from: usize) !usize {
        var waited: u32 = 0;
        while (waited < 10_000) : (waited += 10) {
            self.drain();
            for (self.seen.items[from..], from..) |parsed, i| {
                const m = parsed.value.object.get("method") orelse continue;
                if (m == .string and std.mem.eql(u8, m.string, method)) return i;
            }
            self.queue.wait(10 * std.time.ns_per_ms);
        }
        return error.Timeout;
    }

    /// Navigate the tab to `url` and wait for its load event.
    fn load(self: *Harness, url: []const u8) !void {
        _ = try self.call("Page.enable", "{}");
        const from = self.seen.items.len;
        const params = try std.fmt.allocPrint(self.allocator, "{{\"url\":\"{s}\"}}", .{url});
        defer self.allocator.free(params);
        _ = try self.call("Page.navigate", params);
        _ = try self.waitEvent("Page.loadEventFired", from);
    }

    /// Run `source` in the page's main world.
    fn run(self: *Harness, source: []const u8) !void {
        const done = try self.host.evaluate(self.allocator, self.tab, source, .{}, 5_000);
        done.deinit(self.allocator);
    }

    /// Session `index`'s DOM.* events from index `from` of `seen`, one line
    /// each (`line`).
    fn domEvents(self: *Harness, index: usize, from: usize, out: *std.ArrayList(u8)) !void {
        self.drain();
        for (self.seen.items[from..]) |parsed| {
            const object = parsed.value.object;
            const method = object.get("method") orelse continue;
            if (!std.mem.startsWith(u8, method.string, "DOM.")) continue;
            const session = object.get("sessionId") orelse continue;
            if (!std.mem.eql(u8, session.string, session_names[index])) continue;
            try line(self.allocator, method.string["DOM.".len..], object.get("params"), out);
            try out.append(self.allocator, '\n');
        }
    }
};

/// One event as a line: its name, then its parameters in the protocol's
/// order, nodes as `describe` writes them.
fn line(allocator: std.mem.Allocator, name: []const u8, params_value: ?std.json.Value, out: *std.ArrayList(u8)) !void {
    try out.appendSlice(allocator, name);
    const params = (params_value orelse return).object;
    if (std.mem.eql(u8, name, "childNodeInserted")) {
        try out.print(allocator, " {d} {d} ", .{ params.get("parentNodeId").?.integer, params.get("previousNodeId").?.integer });
        try describe(allocator, params.get("node").?, out);
    } else if (std.mem.eql(u8, name, "childNodeRemoved")) {
        try out.print(allocator, " {d} {d}", .{ params.get("parentNodeId").?.integer, params.get("nodeId").?.integer });
    } else if (std.mem.eql(u8, name, "childNodeCountUpdated")) {
        try out.print(allocator, " {d} {d}", .{ params.get("nodeId").?.integer, params.get("childNodeCount").?.integer });
    } else if (std.mem.eql(u8, name, "attributeModified")) {
        try out.print(allocator, " {d} {s}={s}", .{ params.get("nodeId").?.integer, params.get("name").?.string, params.get("value").?.string });
    } else if (std.mem.eql(u8, name, "attributeRemoved")) {
        try out.print(allocator, " {d} {s}", .{ params.get("nodeId").?.integer, params.get("name").?.string });
    } else if (std.mem.eql(u8, name, "characterDataModified")) {
        try out.print(allocator, " {d} {s}", .{ params.get("nodeId").?.integer, params.get("characterData").?.string });
    } else if (std.mem.eql(u8, name, "inlineStyleInvalidated")) {
        // Blink sends the ids in its HeapHashSet's order: compared sorted.
        const ids = params.get("nodeIds").?.array.items;
        const sorted = try allocator.alloc(i64, ids.len);
        defer allocator.free(sorted);
        for (ids, sorted) |id, *s| s.* = id.integer;
        std.mem.sort(i64, sorted, {}, std.sort.asc(i64));
        try out.appendSlice(allocator, " [");
        for (sorted, 0..) |id, i| try out.print(allocator, "{s}{d}", .{ if (i == 0) "" else ",", id });
        try out.append(allocator, ']');
    } else if (std.mem.eql(u8, name, "shadowRootPushed")) {
        try out.print(allocator, " {d} ", .{params.get("hostId").?.integer});
        try describe(allocator, params.get("root").?, out);
    } else if (std.mem.eql(u8, name, "setChildNodes")) {
        try out.print(allocator, " {d} [", .{params.get("parentId").?.integer});
        for (params.get("nodes").?.array.items, 0..) |node, i| {
            if (i != 0) try out.append(allocator, ',');
            try describe(allocator, node, out);
        }
        try out.append(allocator, ']');
    }
}

/// A node: nodeName#nodeId, a text-like node's value in quotes, a
/// container's /childNodeCount, its attributes in {}, a shadow root's type,
/// a frame owner's content document in (), and its children in [].
fn describe(allocator: std.mem.Allocator, value: std.json.Value, out: *std.ArrayList(u8)) error{OutOfMemory}!void {
    const node = value.object;
    try out.print(allocator, "{s}#{d}", .{ node.get("nodeName").?.string, node.get("nodeId").?.integer });
    const node_type = node.get("nodeType").?.integer;
    if (node_type == 3 or node_type == 8) try out.print(allocator, "'{s}'", .{node.get("nodeValue").?.string});
    if (node.get("childNodeCount")) |count| try out.print(allocator, "/{d}", .{count.integer});
    if (node.get("attributes")) |attributes| if (attributes.array.items.len != 0) {
        try out.append(allocator, '{');
        var i: usize = 0;
        while (i + 1 < attributes.array.items.len) : (i += 2) {
            if (i != 0) try out.append(allocator, ',');
            try out.print(allocator, "{s}={s}", .{ attributes.array.items[i].string, attributes.array.items[i + 1].string });
        }
        try out.append(allocator, '}');
    };
    if (node.get("shadowRootType")) |t| try out.print(allocator, " {s}", .{t.string});
    if (node.get("contentDocument")) |document| {
        try out.append(allocator, '(');
        try describe(allocator, document, out);
        try out.append(allocator, ')');
    }
    if (node.get("children")) |children| {
        try out.append(allocator, '[');
        for (children.array.items, 0..) |child, i| {
            if (i != 0) try out.append(allocator, ',');
            try describe(allocator, child, out);
        }
        try out.append(allocator, ']');
    }
}

/// Load `url`, enable DOM and take the whole document (depth -1, or `depth`).
fn setUp(h: *Harness, url: []const u8, depth: ?i64) !void {
    try h.load(url);
    _ = try h.call("DOM.enable", "{}");
    const params = if (depth) |d| try std.fmt.allocPrint(h.allocator, "{{\"depth\":{d}}}", .{d}) else try h.allocator.dupe(u8, "{\"depth\":-1}");
    defer h.allocator.free(params);
    _ = try h.call("DOM.getDocument", params);
}

/// Run `source`, then check session 0's DOM events since `from` against
/// `expected`.
fn expectEvents(h: *Harness, from: usize, expected: []const u8) !void {
    var lines: std.ArrayList(u8) = .empty;
    defer lines.deinit(h.allocator);
    try h.domEvents(0, from, &lines);
    try testing.expectEqualStrings(expected, lines.items);
}

test "an insertion under a parent whose children the client has is childNodeInserted, with the previous inner sibling and the node built at depth 0 (DidInsertDOMNode)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const b = document.getElementById('b');
        \\b.appendChild(document.createElement('i'));
        \\b.insertBefore(document.createElement('em'), b.firstChild);
        \\b.appendChild(document.createTextNode('tt'));
        \\b.appendChild(document.createTextNode('  '));
        \\const s = document.createElement('span');
        \\s.textContent = 'y';
        \\b.appendChild(s);
    );
    // The whitespace-only text node is skipped (ShouldSkipNode), and so is
    // it as the span's previous sibling (InnerPreviousSibling); a node with
    // an only text child takes it along (BuildArrayForContainerChildren's
    // special case).
    try expectEvents(&h, from,
        \\childNodeInserted 8 0 I#9/0
        \\childNodeInserted 8 0 EM#10/0
        \\childNodeInserted 8 9 #text#11'tt'
        \\childNodeInserted 8 11 SPAN#12/1[#text#13'y']
        \\
    );
}

test "a parent the client has not been sent the children of gets childNodeCountUpdated, from the count it was sent; deeper changes send nothing" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    // Depth 2: #document 1, HTML 2, HEAD 3, BODY 4 (children not sent).
    try setUp(&h, page, 2);
    const from = h.seen.items.len;
    try h.run(
        \\document.body.appendChild(document.createElement('i'));
        \\document.getElementById('b').remove();
        \\document.getElementById('a').appendChild(document.createElement('q'));
    );
    try expectEvents(&h, from,
        \\childNodeCountUpdated 4 3
        \\childNodeCountUpdated 4 2
        \\
    );
}

test "a removal is childNodeRemoved and unbinds the subtree: changes inside it send nothing, and reinserting it binds it anew (WillRemoveDOMNode, Unbind)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const a = document.getElementById('a');
        \\a.remove();
        \\a.firstChild.appendChild(document.createElement('b'));
        \\a.setAttribute('title', 't');
        \\document.body.appendChild(a);
    );
    try expectEvents(&h, from,
        \\childNodeRemoved 4 5
        \\childNodeInserted 4 8 DIV#9/1{id=a,title=t}
        \\
    );
}

test "attributes: attributeModified with the qualified name, nothing for the same value, attributeRemoved; unbound elements send nothing (DidModifyDOMAttr, DidRemoveDOMAttr)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const a = document.getElementById('a');
        \\a.setAttribute('title', 't');
        \\a.setAttribute('title', 't');
        \\a.setAttribute('title', 'u');
        \\a.removeAttribute('title');
        \\a.removeAttribute('nope');
        \\a.setAttributeNS('http://www.w3.org/1999/xlink', 'xl:href', 'v');
        \\a.removeAttributeNS('http://www.w3.org/1999/xlink', 'href');
        \\a.id = 'a2';
        \\a.toggleAttribute('hidden');
        \\document.createElement('q').setAttribute('z', '1');
    );
    try expectEvents(&h, from,
        \\attributeModified 5 title=t
        \\attributeModified 5 title=u
        \\attributeRemoved 5 title
        \\attributeModified 5 xl:href=v
        \\attributeRemoved 5 xl:href
        \\attributeModified 5 id=a2
        \\attributeModified 5 hidden=
        \\
    );
}

test "character data: characterDataModified with the whole data; a bound text node turned whitespace-only is removed, and one that stops being so is inserted (CharacterDataModified)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const t = document.querySelector('span').firstChild;
        \\t.data = 'y';
        \\t.appendData('z');
        \\t.data = '  ';
        \\t.data = 'w';
    );
    try expectEvents(&h, from,
        \\characterDataModified 7 y
        \\characterDataModified 7 yz
        \\childNodeRemoved 6 7
        \\childNodeInserted 6 0 #text#9'w'
        \\
    );
}

test "a fragment's children are inserted one by one, each after the last; innerHTML removes then inserts" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const f = document.createDocumentFragment();
        \\f.append('one', document.createElement('em'), 'two');
        \\document.getElementById('b').append(f);
        \\document.getElementById('a').innerHTML = '<b>q</b>';
    );
    try expectEvents(&h, from,
        \\childNodeInserted 8 0 #text#9'one'
        \\childNodeInserted 8 9 EM#10/0
        \\childNodeInserted 8 10 #text#11'two'
        \\childNodeRemoved 5 6
        \\childNodeInserted 5 0 B#12/1[#text#13'q']
        \\
    );
}

test "CSSOM invalidates the inline style in a later task with no attributeModified; setting the style attribute sends both (DidInvalidateStyleAttr, InspectorRevalidateDOMTask)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    var from = h.seen.items.len;
    try h.run("document.getElementById('a').style.color = 'red';");
    _ = try h.waitEvent("DOM.inlineStyleInvalidated", from);
    try expectEvents(&h, from,
        \\inlineStyleInvalidated [5]
        \\
    );
    from = h.seen.items.len;
    try h.run(
        \\const a = document.getElementById('a');
        \\a.setAttribute('style', 'color: blue');
        \\document.querySelector('span').style.color = 'green';
    );
    _ = try h.waitEvent("DOM.inlineStyleInvalidated", from);
    try expectEvents(&h, from,
        \\attributeModified 5 style=color: blue
        \\inlineStyleInvalidated [5,6]
        \\
    );
}

test "attaching a shadow root to a bound host is shadowRootPushed with the root built at depth 0; the root's children are counted (DidPushShadowRoot)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const root = document.getElementById('a').attachShadow({ mode: 'open' });
        \\root.append(document.createElement('slot'));
        \\document.getElementById('b').attachShadow({ mode: 'closed' });
        \\document.createElement('div').attachShadow({ mode: 'open' });
    );
    try expectEvents(&h, from,
        \\shadowRootPushed 5 #document-fragment#9/0 open
        \\childNodeCountUpdated 9 1
        \\shadowRootPushed 8 #document-fragment#10/0 closed
        \\
    );
}

test "a modal dialog entering and leaving the top layer is topLayerElementsUpdated, after its open attribute changes (TopLayerElementsChanged)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    // DIALOG#d is 9.
    try setUp(&h, "data:text/html,<body><div id=a><span>x</span></div><p id=b></p><dialog id=d></dialog></body>", null);
    const from = h.seen.items.len;
    try h.run("document.getElementById('d').showModal();");
    try h.run("document.getElementById('d').close();");
    try expectEvents(&h, from,
        \\attributeModified 9 open=
        \\topLayerElementsUpdated
        \\attributeRemoved 9 open
        \\topLayerElementsUpdated
        \\
    );
}

test "a child frame's new document re-sends its owner: childNodeRemoved, then childNodeInserted with the new content document (InvalidateFrameOwnerElement)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    // #document 1, HTML 2, HEAD 3, BODY 4, IFRAME#f 5, its #document 6.
    try setUp(&h, "data:text/html,<body><iframe id=f></iframe></body>", null);
    const from = h.seen.items.len;
    try h.run("document.getElementById('f').src = 'data:text/html,<p>z';");
    _ = try h.waitEvent("DOM.childNodeInserted", from);
    try expectEvents(&h, from,
        \\attributeModified 5 src=data:text/html,<p>z
        \\childNodeRemoved 4 5
        \\childNodeInserted 4 0 IFRAME#7/0{id=f,src=data:text/html,<p>z}(#document#8/1)
        \\
    );
}

test "every DOM-enabled session is sent the events, each with its own node ids; a disabled one is sent none, and disable when not enabled fails as Chrome's" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.attach(1);
    try setUp(&h, page, null);
    _ = try h.callOn(1, "DOM.getDocument", "{\"depth\":2}");
    var from = h.seen.items.len;
    try h.run("document.getElementById('b').appendChild(document.createElement('i'));");
    var first: std.ArrayList(u8) = .empty;
    defer first.deinit(h.allocator);
    try h.domEvents(0, from, &first);
    try testing.expectEqualStrings("childNodeInserted 8 0 I#9/0\n", first.items);
    var second: std.ArrayList(u8) = .empty;
    defer second.deinit(h.allocator);
    try h.domEvents(1, from, &second);
    // Session 2 took the document at depth 2: P#b was never sent to it.
    try testing.expectEqualStrings("", second.items);

    _ = try h.callOn(1, "DOM.disable", "{}");
    try testing.expectEqualStrings("DOM agent hasn't been enabled", try h.errorMessage(try h.sendOn(1, "DOM.disable", "{}")));
    from = h.seen.items.len;
    try h.run("document.body.appendChild(document.createElement('i'));");
    second.clearRetainingCapacity();
    try h.domEvents(1, from, &second);
    try testing.expectEqualStrings("", second.items);
    first.clearRetainingCapacity();
    try h.domEvents(0, from, &first);
    try testing.expectEqualStrings("childNodeInserted 4 8 I#10/0\n", first.items);
}

test "the probes' gate opens with an enabled DOM agent and closes with its disable or its session's end (Blink's CoreProbeSink::s_existingAgents)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    const before = devtools.dom_events.enabledAgentCount();
    try h.load(page);
    _ = try h.call("DOM.enable", "{}");
    _ = try h.call("DOM.enable", "{}");
    try testing.expectEqual(before + 1, devtools.dom_events.enabledAgentCount());
    _ = try h.call("DOM.disable", "{}");
    try testing.expectEqual(before, devtools.dom_events.enabledAgentCount());
    // getDocument enables the agent ("Backward compatibility").
    _ = try h.call("DOM.getDocument", "{}");
    try testing.expectEqual(before + 1, devtools.dom_events.enabledAgentCount());
    h.detach(0);
    // The detach runs on the Browser thread; a later session message
    // follows it there.
    try h.attach(1);
    _ = try h.callOn(1, "Page.getFrameTree", "{}");
    try testing.expectEqual(before, devtools.dom_events.enabledAgentCount());
}
