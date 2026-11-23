//! The live DOM against Chrome (lane cdpd1, batch 5; roadmap cdp-live-dom's
//! proof): one page and one list of steps - page script that mutates the
//! tree, then the DOM domain's commands - run over CDP with the DOM domain
//! enabled, and every DOM-domain event and answer of each step compared,
//! step by step, with what Chrome for Testing 157.0.8103.78 sent for the same
//! steps (tests/devtools/fixtures/cdpd1-chrome157-trace.txt).
//!
//! Both are driven the same way: this file's Zig CDP client over a page
//! target's WebSocket (cdp_client.zig), each step followed by a settle (a
//! rendering update and a task after it, so Blink's lazy and batched events
//! - style revalidation, slot distribution, pseudo-elements - are in).
//!
//! What is compared is normalized (`canonical`): object keys sorted;
//! backendNodeIds, frame and loader ids, search ids and styleSheetIds renamed
//! in order of first appearance (Chrome's renderer hands DOMNodeIds to other
//! subsystems too, so its numbers are not Crane's); nodeIds EXACT; the ids of
//! inlineStyleInvalidated and the names of collectClassNamesFromSubtree as
//! sets (Blink fills both from hash sets); remote object ids left out. Left
//! out as geometry or Chrome-only state Crane does not have (main's D8):
//! isScrollable, affectedByStartingStyles, adProvenance and their events.
//!
//! The page avoids the two DOM fast paths where Blink's tree changes differ
//! from the DOM standard's (tmp/plans/feature-queue.md, "GOLDEN-RULE-2
//! CHECK (lane cdpd1)"): Text.splitText, and textContent set to an only
//! text child's own text.
//!
//! RECORDING the fixture: run Chrome for Testing 157 with
//! `--headless=new --remote-debugging-port=<port> --user-data-dir=<empty dir> about:blank`
//! and this test with CRANE_CDP_TRACE_CHROME_PORT=<port> and
//! CRANE_CDP_TRACE_OUT=<file>: it drives that Chrome instead and writes what
//! it saw.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

const fixture_path = "tests/devtools/fixtures/cdpd1-chrome157-trace.txt";

const page_url = "data:text/html,<!doctype html><html><head><style>.k::before{content:'b'}</style></head>" ++
    "<body><div id=a class=k><span>x</span></div><p id=b></p><ul><li>one</li></ul>" ++
    "<dialog id=d></dialog><section id=h><template shadowrootmode=open><slot></slot></template><i>slotted</i></section>" ++
    "<article id=g></article><iframe id=f></iframe></body></html>";

const Step = struct {
    label: []const u8,
    /// A DOM-domain (or Runtime/Page) command, or "script" for page script.
    method: []const u8,
    /// The command's params, or the script.
    params: []const u8,
};

/// The steps, in order. Node ids in params are Chrome's after the
/// getDocument step (the fixture is the record of them).
const steps = [_]Step{
    .{ .label = "getDocument", .method = "DOM.getDocument", .params = "{\"depth\":-1,\"pierce\":true}" },
    .{ .label = "insert", .method = "script", .params = "const b = document.getElementById('b'); b.appendChild(document.createElement('i')); b.insertBefore(document.createElement('em'), b.firstChild); b.appendChild(document.createTextNode('tt')); b.appendChild(document.createTextNode('  ')); const s = document.createElement('span'); s.textContent = 'y'; b.appendChild(s);" },
    .{ .label = "remove-and-reinsert", .method = "script", .params = "const a = document.getElementById('a'); a.remove(); a.firstChild.appendChild(document.createElement('b')); a.setAttribute('title', 't'); document.body.insertBefore(a, document.body.firstChild);" },
    .{ .label = "attributes", .method = "script", .params = "const a = document.getElementById('a'); a.setAttribute('lang', 'en'); a.setAttribute('lang', 'en'); a.setAttribute('lang', 'fr'); a.removeAttribute('lang'); a.removeAttribute('nope'); a.setAttributeNS('http://www.w3.org/1999/xlink', 'xl:href', 'v'); a.removeAttributeNS('http://www.w3.org/1999/xlink', 'href'); a.toggleAttribute('hidden'); a.toggleAttribute('hidden');" },
    .{ .label = "character-data", .method = "script", .params = "const t = document.querySelector('li').firstChild; t.data = 'two'; t.appendData('!'); t.data = '  '; t.data = 'three';" },
    .{ .label = "fragment-and-innerHTML", .method = "script", .params = "const f = document.createDocumentFragment(); f.append('one', document.createElement('em'), 'two'); document.querySelector('ul').append(f); document.querySelector('li').innerHTML = '<b>q</b>';" },
    .{ .label = "inline-style", .method = "script", .params = "document.getElementById('a').style.color = 'red'; document.querySelector('span').setAttribute('style', 'color: blue');" },
    .{ .label = "attach-shadow", .method = "script", .params = "const root = document.getElementById('g').attachShadow({ mode: 'open' }); root.innerHTML = '<slot></slot>';" },
    .{ .label = "distribution", .method = "script", .params = "document.getElementById('h').appendChild(document.createElement('u'));" },
    .{ .label = "top-layer-open", .method = "script", .params = "document.getElementById('d').showModal();" },
    .{ .label = "top-layer-close", .method = "script", .params = "document.getElementById('d').close();" },
    .{ .label = "pseudo-toggle", .method = "script", .params = "document.getElementById('a').classList.remove('k'); document.getElementById('b').classList.add('k');" },
    .{ .label = "adopted-sheets", .method = "script", .params = "window.s1 = new CSSStyleSheet(); document.adoptedStyleSheets = [s1];" },
    .{ .label = "frame-commit", .method = "script", .params = "await new Promise((resolve) => { const f = document.getElementById('f'); f.onload = resolve; f.srcdoc = '<p>z</p>'; });" },
    .{ .label = "setAttributeValue", .method = "DOM.setAttributeValue", .params = "{\"nodeId\":0,\"name\":\"title\",\"value\":\"edited\"}" },
    .{ .label = "undo", .method = "DOM.undo", .params = "{}" },
    .{ .label = "redo", .method = "DOM.redo", .params = "{}" },
    .{ .label = "setAttributesAsText", .method = "DOM.setAttributesAsText", .params = "{\"nodeId\":0,\"text\":\"TITLE='x' data-q=1\",\"name\":\"title\"}" },
    .{ .label = "removeAttribute", .method = "DOM.removeAttribute", .params = "{\"nodeId\":0,\"name\":\"data-q\"}" },
    .{ .label = "markUndoableState", .method = "DOM.markUndoableState", .params = "{}" },
    .{ .label = "removeNode", .method = "DOM.removeNode", .params = "{\"nodeId\":0}" },
    .{ .label = "undo-remove", .method = "DOM.undo", .params = "{}" },
    .{ .label = "moveTo", .method = "DOM.moveTo", .params = "{\"nodeId\":0,\"targetNodeId\":0}" },
    .{ .label = "copyTo", .method = "DOM.copyTo", .params = "{\"nodeId\":0,\"targetNodeId\":0}" },
    .{ .label = "setNodeName", .method = "DOM.setNodeName", .params = "{\"nodeId\":0,\"name\":\"article\"}" },
    .{ .label = "setOuterHTML-merge", .method = "DOM.setOuterHTML", .params = "{\"nodeId\":0,\"outerHTML\":\"<p id=b class=k>merged</p>\"}" },
    .{ .label = "getAttributes", .method = "DOM.getAttributes", .params = "{\"nodeId\":0}" },
    .{ .label = "performSearch", .method = "DOM.performSearch", .params = "{\"query\":\"<li>\"}" },
    .{ .label = "getSearchResults", .method = "DOM.getSearchResults", .params = "{\"searchId\":\"\",\"fromIndex\":0,\"toIndex\":1}" },
    .{ .label = "pushNodeByPathToFrontend", .method = "DOM.pushNodeByPathToFrontend", .params = "{\"path\":\"1,HTML,1,BODY,0,DIV\"}" },
    .{ .label = "collectClassNamesFromSubtree", .method = "DOM.collectClassNamesFromSubtree", .params = "{\"nodeId\":0}" },
    .{ .label = "getTopLayerElements", .method = "DOM.getTopLayerElements", .params = "{}" },
    .{ .label = "getFlattenedDocument", .method = "DOM.getFlattenedDocument", .params = "{\"depth\":2}" },
};

/// The steps whose node ids are found at run time, not written in: each
/// step's params get the nodeId (and targetNodeId) of the node a selector
/// finds, by DOM.querySelector from the document - itself a DOM command,
/// in both browsers, recorded with the step.
const Lookup = struct { label: []const u8, node: ?[]const u8 = null, target: ?[]const u8 = null };
const lookups = [_]Lookup{
    .{ .label = "setAttributeValue", .node = "#a" },
    .{ .label = "setAttributesAsText", .node = "#a" },
    .{ .label = "removeAttribute", .node = "#a" },
    .{ .label = "removeNode", .node = "ul" },
    .{ .label = "moveTo", .node = "#b", .target = "#a" },
    .{ .label = "copyTo", .node = "span", .target = "section" },
    .{ .label = "setNodeName", .node = "#a" },
    .{ .label = "setOuterHTML-merge", .node = "#b" },
    .{ .label = "getAttributes", .node = "#b" },
    .{ .label = "collectClassNamesFromSubtree", .node = "body" },
};

/// A CDP page target to drive: a WebSocket client to its page endpoint.
const Target = struct {
    client: *cdp.Client,
    document_id: i64 = 0,
    search_id: ?[]u8 = null,
};

fn evaluate(allocator: Allocator, client: *cdp.Client, expression: []const u8) !void {
    var params: std.ArrayList(u8) = .empty;
    defer params.deinit(allocator);
    try params.appendSlice(allocator, "{\"expression\":");
    try jsonString(allocator, expression, &params);
    try params.appendSlice(allocator, ",\"awaitPromise\":true}");
    var got = try client.call("Runtime.evaluate", params.items, "");
    got.deinit();
}

/// A rendering update and a task after it.
fn settle(allocator: Allocator, client: *cdp.Client) !void {
    try evaluate(allocator, client, "new Promise((resolve) => requestAnimationFrame(() => setTimeout(resolve, 0)))");
}

/// The nodeId DOM.querySelector answers for `selector` from the document.
fn querySelector(allocator: Allocator, target: *Target, selector: []const u8, out: *std.ArrayList(u8)) !i64 {
    const params = try std.fmt.allocPrint(allocator, "{{\"nodeId\":{d},\"selector\":\"{s}\"}}", .{ target.document_id, selector });
    defer allocator.free(params);
    var got = try target.client.call("DOM.querySelector", params, "");
    defer got.deinit();
    try out.print(allocator, "  lookup {s}\n", .{selector});
    const result = got.value.object.get("result") orelse return 0;
    return result.object.get("nodeId").?.integer;
}

/// Run every step on `target`, writing each step's events and answer.
fn runSteps(allocator: Allocator, target: *Target, out: *std.ArrayList(u8)) !void {
    var names: Names = .{};
    defer names.deinit(allocator);
    var page = try target.client.call("Page.enable", "{}", "");
    page.deinit();
    const navigate = try std.fmt.allocPrint(allocator, "{{\"url\":\"{s}\"}}", .{page_url});
    defer allocator.free(navigate);
    var nav = try target.client.call("Page.navigate", navigate, "");
    nav.deinit();
    var loaded = try target.client.waitEvent("Page.loadEventFired");
    loaded.deinit();
    try settle(allocator, target.client);
    var enable = try target.client.call("DOM.enable", "{}", "");
    enable.deinit();
    _ = target.client.dropQueued("DOM.documentUpdated");
    for (steps) |step| {
        try out.print(allocator, "step {s}\n", .{step.label});
        var params: []const u8 = step.params;
        var owned: ?[]u8 = null;
        defer if (owned) |o| allocator.free(o);
        for (lookups) |lookup| {
            if (!std.mem.eql(u8, lookup.label, step.label)) continue;
            var text = try allocator.dupe(u8, step.params);
            if (lookup.node) |selector| {
                const id = try querySelector(allocator, target, selector, out);
                const replaced = try std.fmt.allocPrint(allocator, "\"nodeId\":{d}", .{id});
                defer allocator.free(replaced);
                const next = try std.mem.replaceOwned(u8, allocator, text, "\"nodeId\":0", replaced);
                allocator.free(text);
                text = next;
            }
            if (lookup.target) |selector| {
                const id = try querySelector(allocator, target, selector, out);
                const replaced = try std.fmt.allocPrint(allocator, "\"targetNodeId\":{d}", .{id});
                defer allocator.free(replaced);
                const next = try std.mem.replaceOwned(u8, allocator, text, "\"targetNodeId\":0", replaced);
                allocator.free(text);
                text = next;
            }
            owned = text;
            params = text;
        }
        if (std.mem.eql(u8, step.label, "getSearchResults")) {
            const text = try std.fmt.allocPrint(allocator, "{{\"searchId\":\"{s}\",\"fromIndex\":0,\"toIndex\":1}}", .{target.search_id orelse ""});
            owned = text;
            params = text;
        }
        if (std.mem.eql(u8, step.method, "script")) {
            const wrapped = try std.fmt.allocPrint(allocator, "(async () => {{ {s} }})()", .{params});
            defer allocator.free(wrapped);
            try evaluate(allocator, target.client, wrapped);
        } else {
            var got = try target.client.call(step.method, params, "");
            defer got.deinit();
            if (std.mem.eql(u8, step.method, "DOM.getDocument")) {
                target.document_id = got.value.object.get("result").?.object.get("root").?.object.get("nodeId").?.integer;
            }
            if (std.mem.eql(u8, step.method, "DOM.performSearch")) {
                if (got.value.object.get("result")) |r| target.search_id = try allocator.dupe(u8, r.object.get("searchId").?.string);
            }
            try out.appendSlice(allocator, "  answer ");
            if (got.value.object.get("result")) |r| {
                try canonical(allocator, &names, r, step.method, out);
            } else if (got.value.object.get("error")) |e| {
                try out.print(allocator, "error {s}", .{e.object.get("message").?.string});
            }
            try out.append(allocator, '\n');
        }
        try settle(allocator, target.client);
        // The DOM events of the step, in order.
        var i: usize = 0;
        while (i < target.client.queued.items.len) {
            const text = target.client.queued.items[i];
            const parsed = std.json.parseFromSlice(std.json.Value, allocator, text, .{}) catch {
                i += 1;
                continue;
            };
            defer parsed.deinit();
            const method = if (parsed.value.object.get("method")) |m| m.string else "";
            if (!std.mem.startsWith(u8, method, "DOM.") or ignoredEvent(method)) {
                allocator.free(target.client.queued.orderedRemove(i));
                continue;
            }
            try out.print(allocator, "  event {s} ", .{method});
            try canonical(allocator, &names, parsed.value.object.get("params") orelse .null, method, out);
            try out.append(allocator, '\n');
            allocator.free(target.client.queued.orderedRemove(i));
        }
    }
    if (target.search_id) |id| allocator.free(id);
}

/// Events Crane does not send (main's D8): geometry and Chrome's ad tagging.
fn ignoredEvent(method: []const u8) bool {
    for ([_][]const u8{ "DOM.scrollableFlagUpdated", "DOM.affectedByStartingStylesFlagUpdated", "DOM.adRelatedStateUpdated" }) |m| {
        if (std.mem.eql(u8, method, m)) return true;
    }
    return false;
}

/// First-appearance renaming of ids that are not Crane's to match.
const Names = struct {
    map: std.StringHashMapUnmanaged([]const u8) = .empty,
    counts: [5]usize = .{ 0, 0, 0, 0, 0 },

    fn deinit(self: *Names, allocator: Allocator) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.map.deinit(allocator);
    }

    fn name(self: *Names, allocator: Allocator, kind: usize, key: []const u8) ![]const u8 {
        const full = try std.fmt.allocPrint(allocator, "{d}:{s}", .{ kind, key });
        if (self.map.get(full)) |n| {
            allocator.free(full);
            return n;
        }
        self.counts[kind] += 1;
        const prefix = [_][]const u8{ "backend", "frame", "loader", "search", "sheet" };
        const n = try std.fmt.allocPrint(allocator, "{s}{d}", .{ prefix[kind], self.counts[kind] });
        try self.map.put(allocator, full, n);
        return n;
    }
};

/// The value as canonical text: keys sorted, renamed ids, dropped fields.
fn canonical(allocator: Allocator, names: *Names, value: std.json.Value, method: []const u8, out: *std.ArrayList(u8)) error{OutOfMemory}!void {
    switch (value) {
        .object => |object| {
            var keys: std.ArrayList([]const u8) = .empty;
            defer keys.deinit(allocator);
            var it = object.iterator();
            while (it.next()) |entry| {
                const key = entry.key_ptr.*;
                if (dropped(key)) continue;
                try keys.append(allocator, key);
            }
            std.mem.sort([]const u8, keys.items, {}, struct {
                fn less(_: void, a: []const u8, b: []const u8) bool {
                    return std.mem.lessThan(u8, a, b);
                }
            }.less);
            try out.append(allocator, '{');
            for (keys.items, 0..) |key, i| {
                if (i != 0) try out.append(allocator, ',');
                try out.print(allocator, "{s}:", .{key});
                const v = object.get(key).?;
                if (renamed(key)) |kind| {
                    const text = switch (v) {
                        .integer => |n| try std.fmt.allocPrint(allocator, "{d}", .{n}),
                        .string => |s| try allocator.dupe(u8, s),
                        else => try allocator.dupe(u8, "?"),
                    };
                    defer allocator.free(text);
                    try out.appendSlice(allocator, try names.name(allocator, kind, text));
                } else if (std.mem.eql(u8, key, "adoptedStyleSheets")) {
                    try out.append(allocator, '[');
                    for (v.array.items, 0..) |sheet, n| {
                        if (n != 0) try out.append(allocator, ',');
                        try out.appendSlice(allocator, try names.name(allocator, 4, sheet.string));
                    }
                    try out.append(allocator, ']');
                } else if (setValued(method, key)) {
                    try sortedArray(allocator, v, out);
                } else {
                    try canonical(allocator, names, v, method, out);
                }
            }
            try out.append(allocator, '}');
        },
        .array => |array| {
            try out.append(allocator, '[');
            for (array.items, 0..) |item, i| {
                if (i != 0) try out.append(allocator, ',');
                try canonical(allocator, names, item, method, out);
            }
            try out.append(allocator, ']');
        },
        .string => |s| try jsonString(allocator, s, out),
        .integer => |n| try out.print(allocator, "{d}", .{n}),
        .float => |f| try out.print(allocator, "{d}", .{f}),
        .bool => |b| try out.appendSlice(allocator, if (b) "true" else "false"),
        .null => try out.appendSlice(allocator, "null"),
        .number_string => |s| try out.appendSlice(allocator, s),
    }
}

/// `s` as a JSON string.
fn jsonString(allocator: Allocator, s: []const u8, out: *std.ArrayList(u8)) error{OutOfMemory}!void {
    try out.append(allocator, '"');
    for (s) |c| switch (c) {
        '"' => try out.appendSlice(allocator, "\\\""),
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '\n' => try out.appendSlice(allocator, "\\n"),
        '\r' => try out.appendSlice(allocator, "\\r"),
        '\t' => try out.appendSlice(allocator, "\\t"),
        0...8, 11, 12, 14...31 => try out.print(allocator, "\\u{x:0>4}", .{c}),
        else => try out.append(allocator, c),
    };
    try out.append(allocator, '"');
}

fn dropped(key: []const u8) bool {
    for ([_][]const u8{ "isScrollable", "affectedByStartingStyles", "adProvenance", "objectId" }) |k| if (std.mem.eql(u8, key, k)) return true;
    return false;
}

fn renamed(key: []const u8) ?usize {
    if (std.mem.eql(u8, key, "backendNodeId")) return 0;
    if (std.mem.eql(u8, key, "frameId")) return 1;
    if (std.mem.eql(u8, key, "loaderId")) return 2;
    if (std.mem.eql(u8, key, "searchId")) return 3;
    return null;
}

/// Lists Blink builds from hash sets: compared as sets.
fn setValued(method: []const u8, key: []const u8) bool {
    if (std.mem.eql(u8, method, "DOM.inlineStyleInvalidated") and std.mem.eql(u8, key, "nodeIds")) return true;
    if (std.mem.eql(u8, method, "DOM.collectClassNamesFromSubtree") and std.mem.eql(u8, key, "classNames")) return true;
    return false;
}

fn sortedArray(allocator: Allocator, value: std.json.Value, out: *std.ArrayList(u8)) !void {
    var texts: std.ArrayList([]u8) = .empty;
    defer {
        for (texts.items) |t| allocator.free(t);
        texts.deinit(allocator);
    }
    for (value.array.items) |item| {
        try texts.append(allocator, switch (item) {
            .integer => |n| try std.fmt.allocPrint(allocator, "{d:0>12}", .{@as(u64, @intCast(n))}),
            .string => |s| try allocator.dupe(u8, s),
            else => try allocator.dupe(u8, "?"),
        });
    }
    std.mem.sort([]u8, texts.items, {}, struct {
        fn less(_: void, a: []u8, b: []u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.less);
    try out.append(allocator, '[');
    for (texts.items, 0..) |t, i| {
        if (i != 0) try out.append(allocator, ',');
        try out.appendSlice(allocator, t);
    }
    try out.append(allocator, ']');
}

/// The page target's WebSocket path on a server at `port`, from /json/list.
fn pagePath(allocator: Allocator, port: u16) ![]u8 {
    var tries: usize = 0;
    while (true) : (tries += 1) {
        var list = try cdp.httpGet(allocator, port, "/json/list", &.{"Host: 127.0.0.1"});
        defer list.deinit();
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, list.body, .{}) catch null;
        if (parsed) |p| {
            defer p.deinit();
            for (p.value.array.items) |entry| {
                if (!std.mem.eql(u8, entry.object.get("type").?.string, "page")) continue;
                return std.fmt.allocPrint(allocator, "/devtools/page/{s}", .{entry.object.get("id").?.string});
            }
        }
        if (tries == 100) return error.NoPage;
        @import("platform").sleepThread(20 * std.time.ns_per_ms);
    }
}

test "the DOM domain's events and answers for one page script and one list of commands equal Chrome 157's, step by step" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    var trace: std.ArrayList(u8) = .empty;
    defer trace.deinit(allocator);

    // Record mode: drive a Chrome for Testing 157 instead and write its trace.
    if (std.c.getenv("CRANE_CDP_TRACE_CHROME_PORT")) |port_text| {
        const port = try std.fmt.parseInt(u16, std.mem.span(port_text), 10);
        const path = try pagePath(allocator, port);
        defer allocator.free(path);
        const client = try cdp.Client.openWebSocket(allocator, port, path, null);
        defer client.close();
        var target: Target = .{ .client = client };
        try runSteps(allocator, &target, &trace);
        const out_path = std.mem.span(std.c.getenv("CRANE_CDP_TRACE_OUT") orelse return error.NoOutPath);
        const io = testing.io;
        const file = try std.Io.Dir.cwd().createFile(io, out_path, .{});
        defer file.close(io);
        try file.writeStreamingAll(io, trace.items);
        return;
    }

    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const path = try pagePath(allocator, server.port);
    defer allocator.free(path);
    const client = try cdp.Client.openWebSocket(allocator, server.port, path, null);
    defer client.close();
    var target: Target = .{ .client = client };
    try runSteps(allocator, &target, &trace);

    const expected = std.Io.Dir.cwd().readFileAlloc(testing.io, fixture_path, allocator, .limited(4 * 1024 * 1024)) catch |err| {
        // Until the fixture is recorded (the lane's batch 5), this run
        // prints Crane's trace and is skipped - never a pass.
        std.debug.print("no Chrome fixture at {s} ({t}); Crane's trace:\n{s}\n", .{ fixture_path, err, trace.items });
        return error.SkipZigTest;
    };
    defer allocator.free(expected);
    try testing.expectEqualStrings(expected, trace.items);
}
