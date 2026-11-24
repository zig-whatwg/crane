//! Chrome's user-agent shadow nodes, set apart in its snapshots (main,
//! 12:25 AM ET 2026-11-24; lesson
//! testing-compare-an-ax-tree-with-chrome-after-setting-its-user-agent-shadow-nodes-apart.md).
//! Chrome's accessibility tree has objects for its form controls' user-agent
//! shadow trees - a text field's inner editor and its text, a select's
//! pop-up - each with a real DOM node, so Google's snapshot numbers them and
//! every later uid is one higher than Crane's, which has no such DOM.
//!
//! After each Chrome answer that carries a snapshot, the harness reads
//! Chrome's own page over a second CDP connection (its remote debugging port,
//! given to Chrome through chrome-devtools-mcp's --chromeArg):
//! DOM.getDocument {depth: -1, pierce: true} names the nodes under
//! shadowRootType "user-agent" roots, and the page's trees
//! (Accessibility.getFullAXTree per frame) replay Google's numbering - the
//! MCP server's own rules, ax_tree.zig - so every uid Google printed has its
//! DOM node. Then, in the answer's text, a user-agent node's line goes (and
//! its nodeless lines with it), its page-DOM descendants move up to its
//! nearest kept ancestor, the select's MenuListPopup stays with no uid (how
//! Crane answers it), and the uids are renumbered without the user-agent
//! nodes, as Crane numbers them. A uid a later call names is mapped back for
//! Chrome. When the replay does not reproduce what Google printed, the
//! answer is left as it is and the report says so: nothing is guessed.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const ax_tree = @import("ax_tree");
const cdp_ws = @import("cdp_ws");

/// The backendNodeIds of every node in a user-agent shadow root under
/// `node` (a DOM.Node of DOM.getDocument's answer).
pub fn userAgentIds(arena: Allocator, node: std.json.Value, inside: bool, out: *std.AutoHashMapUnmanaged(i64, void)) !void {
    if (node != .object) return;
    if (inside) if (node.object.get("backendNodeId")) |id| if (id == .integer) try out.put(arena, id.integer, {});
    if (node.object.get("children")) |children| if (children == .array) for (children.array.items) |child| try userAgentIds(arena, child, inside, out);
    if (node.object.get("shadowRoots")) |roots| if (roots == .array) for (roots.array.items) |root| {
        const kind = if (root == .object) ax_tree.str(root.object.get("shadowRootType")) else "";
        try userAgentIds(arena, root, inside or std.mem.eql(u8, kind, "user-agent"), out);
    };
    if (node.object.get("contentDocument")) |child| try userAgentIds(arena, child, false, out);
    if (node.object.get("pseudoElements")) |pseudos| if (pseudos == .array) for (pseudos.array.items) |p| try userAgentIds(arena, p, inside, out);
}

/// What one Chrome uid becomes.
pub const Fate = union(enum) {
    /// A page-DOM node: its uid as Crane numbers it.
    uid: []const u8,
    /// A user-agent node: its line goes.
    drop,
    /// The select's pop-up: its line stays, with no uid.
    nodeless,
};

/// One snapshot's replay: Chrome's uid for each numbered node, and what it
/// becomes; the role Google prints for it (checked against the line).
pub const Numbered = struct {
    chrome_uid: []const u8,
    fate: Fate,
    role: []const u8,
};

/// A case's state on Chrome's side: Google's uid map replayed (its
/// uniqueBackendNodeIdToMcpId), the same map as Crane numbers it, and the
/// uids seen so far.
pub const Replay = struct {
    /// TextSnapshot.nextSnapshotId: both servers start a case at 1.
    next_snapshot: u32 = 1,
    /// "<loaderId>_<backendNodeId>" to Chrome's uid, and to Crane's.
    chrome_map: std.StringHashMapUnmanaged([]const u8) = .empty,
    crane_map: std.StringHashMapUnmanaged([]const u8) = .empty,
    /// Every Chrome uid seen, and what it became; Crane's uid back to
    /// Chrome's (for a later call's arguments).
    fates: std.StringHashMapUnmanaged(Fate) = .empty,
    back: std.StringHashMapUnmanaged([]const u8) = .empty,
    /// The replay failed once: the case's uids are not mapped any more.
    broken: bool = false,

    /// Number `kept` (the snapshot Google made of `ua`'s page) as Google
    /// does and as Crane would without the user-agent nodes. The maps keep
    /// only what this snapshot saw, as TextSnapshot.create's clean-up does.
    pub fn number(self: *Replay, arena: Allocator, kept: *ax_tree.Kept, ua: *const std.AutoHashMapUnmanaged(i64, void)) ![]Numbered {
        const snapshot_id = self.next_snapshot;
        self.next_snapshot += 1;
        var order: std.ArrayList(*ax_tree.Kept) = .empty;
        try ax_tree.numberingOrder(arena, kept, &order);
        var chrome_next: std.StringHashMapUnmanaged([]const u8) = .empty;
        var crane_next: std.StringHashMapUnmanaged([]const u8) = .empty;
        var chrome_counter: u32 = 0;
        var crane_counter: u32 = 0;
        var out: std.ArrayList(Numbered) = .empty;
        for (order.items) |k| {
            const backend = k.ax.backendNodeId() orelse continue;
            const key = try std.fmt.allocPrint(arena, "{s}_{d}", .{ k.ax.loader_id, backend });
            const chrome_uid = chrome_next.get(key) orelse self.chrome_map.get(key) orelse blk: {
                defer chrome_counter += 1;
                break :blk try std.fmt.allocPrint(arena, "{d}_{d}", .{ snapshot_id, chrome_counter });
            };
            try chrome_next.put(arena, key, chrome_uid);
            const fate: Fate = if (ua.contains(backend))
                (if (std.mem.eql(u8, k.ax.role, "MenuListPopup")) .nodeless else .drop)
            else blk: {
                const crane_uid = crane_next.get(key) orelse self.crane_map.get(key) orelse uid: {
                    defer crane_counter += 1;
                    break :uid try std.fmt.allocPrint(arena, "{d}_{d}", .{ snapshot_id, crane_counter });
                };
                try crane_next.put(arena, key, crane_uid);
                try self.back.put(arena, crane_uid, chrome_uid);
                break :blk .{ .uid = crane_uid };
            };
            try self.fates.put(arena, chrome_uid, fate);
            try out.append(arena, .{ .chrome_uid = chrome_uid, .fate = fate, .role = k.ax.role });
        }
        self.chrome_map = chrome_next;
        self.crane_map = crane_next;
        return out.items;
    }

    /// A later call's arguments for Chrome: every string that is a uid
    /// Crane's numbering gave, as Chrome numbered it.
    pub fn argsForChrome(self: *const Replay, arena: Allocator, value: std.json.Value) !std.json.Value {
        if (self.broken or self.back.count() == 0) return value;
        return switch (value) {
            .string => |s| .{ .string = self.back.get(s) orelse s },
            .array => |a| blk: {
                var copy = std.json.Array.init(arena);
                for (a.items) |item| try copy.append(try self.argsForChrome(arena, item));
                break :blk .{ .array = copy };
            },
            .object => |o| blk: {
                var copy: std.json.ObjectMap = .empty;
                var it = o.iterator();
                while (it.next()) |e| try copy.put(arena, e.key_ptr.*, try self.argsForChrome(arena, e.value_ptr.*));
                break :blk .{ .object = copy };
            },
            else => value,
        };
    }
};

const snapshot_header = "## Latest page snapshot";

/// The snapshot section's lines of `text`, as [start, end) line indices.
fn snapshotLines(lines: []const []const u8) ?[2]usize {
    for (lines, 0..) |line, i| {
        if (!std.mem.eql(u8, line, snapshot_header)) continue;
        var end = i + 1;
        while (end < lines.len and !std.mem.startsWith(u8, lines[end], "## ")) end += 1;
        return .{ i + 1, end };
    }
    return null;
}

/// Whether `text` carries a snapshot.
pub fn hasSnapshot(text: []const u8) bool {
    return std.mem.indexOf(u8, text, snapshot_header) != null;
}

/// The RootWebArea's URL on the snapshot's first line (its page).
pub fn snapshotUrl(text: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    var after = false;
    while (lines.next()) |line| {
        if (after) {
            const at = std.mem.indexOf(u8, line, " url=\"") orelse return null;
            const rest = line[at + " url=\"".len ..];
            const end = std.mem.indexOfScalar(u8, rest, '"') orelse return null;
            return rest[0..end];
        }
        if (std.mem.eql(u8, line, snapshot_header)) after = true;
    }
    return null;
}

/// A snapshot line: its depth, its uid ("" for none) and what follows.
const Line = struct { depth: usize, uid: []const u8, rest: []const u8 };

fn parseLine(line: []const u8) Line {
    var spaces: usize = 0;
    while (spaces < line.len and line[spaces] == ' ') spaces += 1;
    const body = line[spaces..];
    if (std.mem.startsWith(u8, body, "uid=")) {
        const space = std.mem.indexOfScalar(u8, body, ' ') orelse body.len;
        return .{ .depth = spaces / 2, .uid = body["uid=".len..space], .rest = if (space < body.len) body[space + 1 ..] else "" };
    }
    return .{ .depth = spaces / 2, .uid = "", .rest = body };
}

/// The role a line prints for `role` (SnapshotFormatter: none for
/// StaticText, "ignored" for none).
fn printedRole(role: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, role, "StaticText")) return null;
    if (std.mem.eql(u8, role, "none")) return "ignored";
    return role;
}

/// Whether every uid line of the snapshot is one `numbered` names, with
/// the role it prints - the replay reproduced Google's numbering.
pub fn agrees(arena: Allocator, text: []const u8, numbered: []const Numbered) !bool {
    var by_uid: std.StringHashMapUnmanaged([]const u8) = .empty;
    for (numbered) |n| try by_uid.put(arena, n.chrome_uid, n.role);
    var lines = std.mem.splitScalar(u8, text, '\n');
    var inside = false;
    while (lines.next()) |raw| {
        if (std.mem.eql(u8, raw, snapshot_header)) {
            inside = true;
            continue;
        }
        if (!inside) continue;
        if (std.mem.startsWith(u8, raw, "## ")) break;
        const line = parseLine(raw);
        if (line.uid.len == 0) continue;
        const role = by_uid.get(line.uid) orelse return false;
        const first = if (std.mem.indexOfScalar(u8, line.rest, ' ')) |sp| line.rest[0..sp] else line.rest;
        if (printedRole(role)) |want| {
            if (!std.mem.eql(u8, first, want)) return false;
        } else if (first.len != 0 and first[0] != '"') return false;
    }
    return true;
}

/// The answer's text with its snapshot's user-agent nodes set apart and
/// its uids as Crane numbers them (`fates`: every Chrome uid seen).
pub fn setApart(arena: Allocator, text: []const u8, fates: *const std.StringHashMapUnmanaged(Fate)) ![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| try lines.append(arena, line);
    const range = snapshotLines(lines.items) orelse return text;
    var out: std.ArrayList([]const u8) = .empty;
    try out.appendSlice(arena, lines.items[0..range[0]]);
    // The ancestors of the current line: each one's depth and whether its
    // line went.
    const Open = struct { depth: usize, dropped: bool };
    var open: std.ArrayList(Open) = .empty;
    for (lines.items[range[0]..range[1]]) |raw| {
        if (raw.len == 0) {
            try out.append(arena, raw);
            continue;
        }
        const line = parseLine(raw);
        while (open.items.len > 0 and open.items[open.items.len - 1].depth >= line.depth) _ = open.pop();
        var dropped_above: usize = 0;
        for (open.items) |o| {
            if (o.dropped) dropped_above += 1;
        }
        const parent_dropped = open.items.len > 0 and open.items[open.items.len - 1].dropped;
        const depth = line.depth - dropped_above;
        if (line.uid.len == 0) {
            // A nodeless line: it goes with a dropped parent.
            if (parent_dropped) {
                try open.append(arena, .{ .depth = line.depth, .dropped = true });
                continue;
            }
            try out.append(arena, try indented(arena, depth, "", line.rest));
            try open.append(arena, .{ .depth = line.depth, .dropped = false });
            continue;
        }
        switch (fates.get(line.uid) orelse Fate{ .uid = line.uid }) {
            .drop => try open.append(arena, .{ .depth = line.depth, .dropped = true }),
            .nodeless => {
                try out.append(arena, try indented(arena, depth, "", line.rest));
                try open.append(arena, .{ .depth = line.depth, .dropped = false });
            },
            .uid => |uid| {
                try out.append(arena, try indented(arena, depth, uid, line.rest));
                try open.append(arena, .{ .depth = line.depth, .dropped = false });
            },
        }
    }
    try out.appendSlice(arena, lines.items[range[1]..]);
    return std.mem.join(arena, "\n", out.items);
}

fn indented(arena: Allocator, depth: usize, uid: []const u8, rest: []const u8) ![]const u8 {
    var w: Io.Writer.Allocating = .init(arena);
    try w.writer.splatByteAll(' ', depth * 2);
    if (uid.len != 0) {
        try w.writer.print("uid={s}", .{uid});
        if (rest.len != 0) try w.writer.writeByte(' ');
    }
    try w.writer.writeAll(rest);
    return w.written();
}

// ----------------------------------------------------------------------
// Chrome's page over CDP
// ----------------------------------------------------------------------

/// A free TCP port on the loopback (for Chrome's remote debugging port).
pub fn freePort(io: Io) !u16 {
    const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(0) };
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    return server.socket.address.getPort();
}

/// The browser target's WebSocket path (/json/version), waiting up to
/// `wait_ms` for Chrome to listen.
fn browserPath(arena: Allocator, io: Io, port: u16, wait_ms: u32) ![]const u8 {
    var waited: u32 = 0;
    while (true) : (waited += 100) {
        if (httpGet(arena, io, port, "/json/version")) |body| {
            const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, body, .{});
            const ws = ax_tree.str(parsed.object.get("webSocketDebuggerUrl"));
            const at = std.mem.indexOf(u8, ws, "/devtools/") orelse return error.NoBrowserTarget;
            return ws[at..];
        } else |_| {
            if (waited >= wait_ms) return error.ChromeNotListening;
            Io.sleep(io, .fromMilliseconds(100), .awake) catch {};
        }
    }
}

fn httpGet(arena: Allocator, io: Io, port: u16, path: []const u8) ![]const u8 {
    const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(port) };
    const stream = try address.connect(io, .{ .mode = .stream });
    defer stream.close(io);
    var out_buf: [512]u8 = undefined;
    var writer = stream.writer(io, &out_buf);
    try writer.interface.print("GET {s} HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nConnection: close\r\n\r\n", .{ path, port });
    try writer.interface.flush();
    var in_buf: [16 * 1024]u8 = undefined;
    var reader = stream.reader(io, &in_buf);
    // The head, then Content-Length bytes: Chrome's DevTools HTTP server
    // keeps the connection open, whatever the request says.
    while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
        reader.interface.fillMore() catch return error.BadResponse;
    }
    const buffered = reader.interface.buffered();
    const head_end = std.mem.indexOf(u8, buffered, "\r\n\r\n").? + 4;
    const length = contentLength(buffered[0..head_end]) orelse return error.BadResponse;
    reader.interface.toss(head_end);
    const body = try arena.alloc(u8, length);
    reader.interface.readSliceAll(body) catch return error.BadResponse;
    return body;
}

/// A response head's Content-Length.
fn contentLength(head: []const u8) ?usize {
    var lines = std.mem.splitSequence(u8, head, "\r\n");
    while (lines.next()) |line| {
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " "), "content-length")) continue;
        return std.fmt.parseInt(usize, std.mem.trim(u8, line[colon + 1 ..], " \t"), 10) catch null;
    }
    return null;
}

test "contentLength: the header's value, any case" {
    try testing.expectEqual(@as(?usize, 42), contentLength("HTTP/1.1 200 OK\r\ncontent-length: 42\r\n\r\n"));
    try testing.expectEqual(@as(?usize, 7), contentLength("HTTP/1.1 200 OK\r\nContent-Type: x\r\nContent-Length:7\r\n\r\n"));
    try testing.expectEqual(@as(?usize, null), contentLength("HTTP/1.1 200 OK\r\n\r\n"));
}

/// What Chrome's page shows now: its user-agent nodes and the snapshot
/// Google would make of it, `verbose` or not.
pub const Page = struct {
    ua: std.AutoHashMapUnmanaged(i64, void),
    kept: ?*ax_tree.Kept,
};

/// Read the page whose URL is `url` from Chrome's port: attach, read, detach.
pub fn readPage(arena: Allocator, gpa: Allocator, io: Io, port: u16, url: []const u8, verbose: bool) !Page {
    const path = try browserPath(arena, io, port, 5000);
    var ws: cdp_ws.WebSocket = undefined;
    try ws.connect(io, port, path);
    defer ws.close();
    var session: cdp_ws.Session = .{ .ws = &ws, .gpa = gpa };
    const targets = try parsedCall(arena, &session, "Target.getTargets", "{}", null);
    var target_id: ?[]const u8 = null;
    for (resultOf(targets).object.get("targetInfos").?.array.items) |info| {
        if (!std.mem.eql(u8, ax_tree.str(info.object.get("type")), "page")) continue;
        if (std.mem.eql(u8, ax_tree.str(info.object.get("url")), url)) {
            target_id = ax_tree.str(info.object.get("targetId"));
            break;
        }
    }
    const attached = try parsedCall(arena, &session, "Target.attachToTarget", try std.fmt.allocPrint(arena, "{{\"targetId\":{f},\"flatten\":true}}", .{std.json.fmt(target_id orelse return error.NoSuchPage, .{})}), null);
    const sid = ax_tree.str(resultOf(attached).object.get("sessionId"));
    defer _ = parsedCall(arena, &session, "Target.detachFromTarget", std.fmt.allocPrint(arena, "{{\"sessionId\":{f}}}", .{std.json.fmt(sid, .{})}) catch "{}", null) catch {};

    var page: Page = .{ .ua = .empty, .kept = null };
    const document = try parsedCall(arena, &session, "DOM.getDocument", "{\"depth\":-1,\"pierce\":true}", sid);
    if (resultOf(document).object.get("root")) |root| try userAgentIds(arena, root, false, &page.ua);
    // The frames' loaders, then each frame's tree as tools/snapshot.zig
    // reads Crane's (populateIframes).
    var loaders: std.StringHashMapUnmanaged([]const u8) = .empty;
    const frame_tree = try parsedCall(arena, &session, "Page.getFrameTree", "{}", sid);
    try collectLoaders(arena, resultOf(frame_tree).object.get("frameTree").?, &loaders);
    const main_frame = ax_tree.str(resultOf(frame_tree).object.get("frameTree").?.object.get("frame").?.object.get("id"));
    const root = (try frameAx(arena, &session, sid, main_frame, &loaders)) orelse return page;
    page.kept = try ax_tree.keptTree(arena, root, verbose);
    return page;
}

fn collectLoaders(arena: Allocator, tree: std.json.Value, out: *std.StringHashMapUnmanaged([]const u8)) !void {
    const frame = tree.object.get("frame").?.object;
    try out.put(arena, ax_tree.str(frame.get("id")), ax_tree.str(frame.get("loaderId")));
    if (tree.object.get("childFrames")) |children| for (children.array.items) |child| try collectLoaders(arena, child, out);
}

fn frameAx(arena: Allocator, session: *cdp_ws.Session, sid: []const u8, frame_id: []const u8, loaders: *const std.StringHashMapUnmanaged([]const u8)) anyerror!?*ax_tree.AX {
    const answer = try parsedCall(arena, session, "Accessibility.getFullAXTree", try std.fmt.allocPrint(arena, "{{\"frameId\":{f}}}", .{std.json.fmt(frame_id, .{})}), sid);
    const nodes = resultOf(answer).object.get("nodes") orelse return null;
    const root = (try ax_tree.createTree(arena, nodes.array.items, loaders.get(frame_id) orelse "", frame_id)) orelse return null;
    var frames: std.ArrayList(*ax_tree.AX) = .empty;
    try ax_tree.iframes(arena, root, &frames);
    for (frames.items) |iframe| {
        const described = parsedCall(arena, session, "DOM.describeNode", try std.fmt.allocPrint(arena, "{{\"backendNodeId\":{d}}}", .{iframe.backendNodeId().?}), sid) catch continue;
        const node = resultOf(described).object.get("node") orelse continue;
        const child = ax_tree.str(node.object.get("frameId"));
        if (child.len == 0) continue;
        iframe.frame_tree = frameAx(arena, session, sid, child, loaders) catch null;
    }
    return root;
}

fn parsedCall(arena: Allocator, session: *cdp_ws.Session, method: []const u8, params: []const u8, sid: ?[]const u8) !std.json.Value {
    const text = try session.call(method, params, sid);
    defer session.gpa.free(text);
    return std.json.parseFromSliceLeaky(std.json.Value, arena, text, .{ .allocate = .alloc_always });
}

fn resultOf(message: std.json.Value) std.json.Value {
    return message.object.get("result") orelse .{ .object = .empty };
}

// ----------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------

const testing = std.testing;

test "userAgentIds: the nodes under user-agent shadow roots, not an open root's, a frame's document starting outside" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const document = try std.json.parseFromSliceLeaky(std.json.Value, arena,
        \\{"backendNodeId":1,"children":[{"backendNodeId":2,"nodeName":"INPUT","shadowRoots":[{"backendNodeId":3,"shadowRootType":"user-agent","children":[{"backendNodeId":4,"children":[{"backendNodeId":5}]}]}]},
        \\ {"backendNodeId":6,"shadowRoots":[{"backendNodeId":7,"shadowRootType":"open","children":[{"backendNodeId":8}]}]}]}
    , .{});
    var ua: std.AutoHashMapUnmanaged(i64, void) = .empty;
    try userAgentIds(arena, document, false, &ua);
    try testing.expectEqual(@as(u32, 3), ua.count());
    for ([_]i64{ 3, 4, 5 }) |id| try testing.expect(ua.contains(id));
}

fn parseNodes(arena: Allocator, text: []const u8) ![]const std.json.Value {
    return (try std.json.parseFromSliceLeaky(std.json.Value, arena, text, .{})).array.items;
}

/// A form's text field and select as Chrome 157's tree has them: the text
/// field's inner editor (7) and its text (8), the select's pop-up (10).
const chrome_form =
    \\[{"nodeId":"1","role":{"type":"internalRole","value":"RootWebArea"},"name":{"type":"computedString","value":"F"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}}],"childIds":["2","5"],"backendDOMNodeId":1},
    \\ {"nodeId":"2","role":{"type":"role","value":"textbox"},"name":{"type":"computedString","value":"Name"},"value":{"type":"string","value":"Ada"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}}],"childIds":["3"],"backendDOMNodeId":6},
    \\ {"nodeId":"3","role":{"type":"role","value":"generic"},"childIds":["4"],"backendDOMNodeId":7},
    \\ {"nodeId":"4","role":{"type":"role","value":"StaticText"},"name":{"type":"computedString","value":"Ada"},"childIds":[],"backendDOMNodeId":8},
    \\ {"nodeId":"5","role":{"type":"role","value":"combobox"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}}],"childIds":["6"],"backendDOMNodeId":9},
    \\ {"nodeId":"6","role":{"type":"internalRole","value":"MenuListPopup"},"childIds":["7"],"backendDOMNodeId":10},
    \\ {"nodeId":"7","role":{"type":"role","value":"option"},"name":{"type":"computedString","value":"Red"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}}],"childIds":[],"backendDOMNodeId":11}]
;

test "a verbose snapshot: the inner editor and its text go, the pop-up loses its uid, later uids as Crane numbers them" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const root = (try ax_tree.createTree(arena, try parseNodes(arena, chrome_form), "L", "F")).?;
    var ua: std.AutoHashMapUnmanaged(i64, void) = .empty;
    for ([_]i64{ 7, 8, 10 }) |id| try ua.put(arena, id, {});
    var replay: Replay = .{};
    const kept = (try ax_tree.keptTree(arena, root, true)).?;
    const numbered = try replay.number(arena, kept, &ua);
    // Google's numbering: 1_0 root, 1_1 textbox, 1_2 generic, 1_3 text,
    // 1_4 combobox, 1_5 popup, 1_6 option.
    try testing.expectEqual(@as(usize, 7), numbered.len);
    const google =
        \\## Latest page snapshot
        \\uid=1_0 RootWebArea "F"
        \\  uid=1_1 textbox "Name" value="Ada"
        \\    uid=1_2 generic
        \\      uid=1_3 "Ada"
        \\  uid=1_4 combobox
        \\    uid=1_5 MenuListPopup
        \\      uid=1_6 option "Red"
        \\
    ;
    try testing.expect(try agrees(arena, google, numbered));
    try testing.expectEqualStrings(
        \\## Latest page snapshot
        \\uid=1_0 RootWebArea "F"
        \\  uid=1_1 textbox "Name" value="Ada"
        \\  uid=1_2 combobox
        \\    MenuListPopup
        \\      uid=1_3 option "Red"
        \\
    , try setApart(arena, google, &replay.fates));
    // A later call's uid, as Crane numbered it, back to Chrome's.
    const args = try std.json.parseFromSliceLeaky(std.json.Value, arena, "{\"args\":[\"1_3\",\"9_9\"]}", .{});
    const mapped = try replay.argsForChrome(arena, args);
    try testing.expectEqualStrings("1_6", mapped.object.get("args").?.array.items[0].string);
    try testing.expectEqualStrings("9_9", mapped.object.get("args").?.array.items[1].string);
}

test "agrees: a line whose uid or role the replay does not give is a failed replay" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const numbered = [_]Numbered{
        .{ .chrome_uid = "1_0", .fate = .{ .uid = "1_0" }, .role = "RootWebArea" },
        .{ .chrome_uid = "1_1", .fate = .{ .uid = "1_1" }, .role = "StaticText" },
    };
    try testing.expect(try agrees(arena, "## Latest page snapshot\nuid=1_0 RootWebArea \"T\"\n  uid=1_1 \"x\"\n", &numbered));
    try testing.expect(!try agrees(arena, "## Latest page snapshot\nuid=1_0 button \"T\"\n", &numbered));
    try testing.expect(!try agrees(arena, "## Latest page snapshot\nuid=1_7 RootWebArea \"T\"\n", &numbered));
}

test "setApart: a dropped node's page-DOM child moves up to the nearest kept ancestor; its nodeless child goes" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var fates: std.StringHashMapUnmanaged(Fate) = .empty;
    try fates.put(arena, "2_0", .{ .uid = "2_0" });
    try fates.put(arena, "2_1", .drop);
    try fates.put(arena, "2_2", .{ .uid = "2_1" });
    const text =
        \\Element matching one of ["x"] found.
        \\## Latest page snapshot
        \\uid=2_0 RootWebArea
        \\  uid=2_1 generic
        \\    ignored
        \\    uid=2_2 option "x"
        \\
    ;
    try testing.expectEqualStrings(
        \\Element matching one of ["x"] found.
        \\## Latest page snapshot
        \\uid=2_0 RootWebArea
        \\  uid=2_1 option "x"
        \\
    , try setApart(arena, text, &fates));
}
