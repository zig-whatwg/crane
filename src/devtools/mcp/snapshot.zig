//! take_snapshot's text: a page's accessibility tree as chrome-devtools-mcp
//! prints it. Translated from puppeteer-core 25.17.0's
//! lib/puppeteer/cdp/Accessibility.js (Accessibility.snapshot: the tree
//! from Accessibility.getFullAXTree, each iframe's own snapshot under it,
//! only the "interesting" nodes unless verbose, AXNode.serialize; Copyright
//! 2018 Google Inc., Apache-2.0) and chrome-devtools-mcp-v1.13.0's
//! src/TextSnapshot.ts (uids "<snapshot>_<n>" in pre-order, kept for a node
//! across snapshots of one document by "<loaderId>_<backendNodeId>") and
//! src/formatters/SnapshotFormatter.ts (one line per node: uid, role, the
//! quoted name, then its attributes in key order; Copyright 2025 Google LLC,
//! Apache-2.0). THIRD_PARTY_NOTICES.md.
//!
//! The CDP part (getFullAXTree per frame, the iframes' content frames) is
//! tools/snapshot.zig's, the tree and which nodes a snapshot keeps
//! ax_tree.zig's (shared with tools/mcp_diff): this file serializes,
//! numbers and prints the kept nodes.

const std = @import("std");
const Allocator = std.mem.Allocator;
const text_util = @import("text.zig");
const console = @import("console.zig");
const ax_tree = @import("ax_tree.zig");

/// A serialized node (Puppeteer's SerializedAXNode, chrome-devtools-mcp's
/// TextSnapshotNode).
pub const Node = struct {
    role: []const u8,
    /// The `name` key's value; null when absent or undefined.
    name: ?[]const u8 = null,
    /// The other keys serialize() set (the formatter sorts them).
    attrs: std.StringArrayHashMapUnmanaged(Value) = .empty,
    backend_node_id: ?i64 = null,
    loader_id: []const u8 = "",
    /// The frame whose tree holds it (its element resolves there).
    frame_id: []const u8 = "",
    /// The uid ("" for a node with no DOM node).
    id: []const u8 = "",
    children: std.ArrayList(*Node) = .empty,
};

pub const Value = union(enum) {
    string: []const u8,
    boolean: bool,
    number: f64,
};

const AX = ax_tree.AX;
const eql = ax_tree.eql;
const str = ax_tree.str;
const truthy = ax_tree.truthy;
const properties = ax_tree.properties;
const propertyValue = ax_tree.propertyValue;

/// AXNode.serialize.
fn serialize(arena: Allocator, self: *const AX) !*Node {
    const node = try arena.create(Node);
    node.* = .{
        .role = self.role,
        .backend_node_id = self.backendNodeId(),
        .loader_id = self.loader_id,
        .frame_id = self.frame_id,
    };
    // The properties by lower-cased name (a missing value is
    // undefined: null here), then name, value and description.
    var props: std.StringArrayHashMapUnmanaged(?std.json.Value) = .empty;
    for (properties(self.payload)) |property| {
        if (property != .object) continue;
        try props.put(arena, try std.ascii.allocLowerString(arena, str(property.object.get("name"))), propertyValue(property));
    }
    for ([_][]const u8{ "name", "value", "description" }) |field| {
        const v = self.payload.get(field) orelse continue;
        if (v != .object) continue;
        try props.put(arena, field, v.object.get("value"));
    }
    // userStringProperties (undefined ones print nothing).
    for ([_][]const u8{ "name", "value", "description", "keyshortcuts", "roledescription", "valuetext", "url" }) |key| {
        const v = (props.get(key) orelse continue) orelse continue;
        if (eql(key, "name")) {
            node.name = if (v == .string) v.string else try jsStringOf(arena, v);
            continue;
        }
        try node.attrs.put(arena, key, try asValue(arena, v));
    }
    // booleanProperties: a RootWebArea's focus is its frame's.
    for ([_][]const u8{ "disabled", "expanded", "focused", "modal", "multiline", "multiselectable", "readonly", "required", "selected", "busy", "atomic" }) |key| {
        if (eql(key, "focused") and eql(self.role, "RootWebArea")) continue;
        const v = props.get(key) orelse continue;
        try node.attrs.put(arena, key, .{ .boolean = truthy(v) });
    }
    // tristateProperties.
    for ([_][]const u8{ "checked", "pressed" }) |key| {
        const v = props.get(key) orelse continue;
        const text = if (v != null and v.? == .string) v.?.string else "";
        try node.attrs.put(arena, key, if (eql(text, "mixed")) .{ .string = "mixed" } else .{ .boolean = eql(text, "true") });
    }
    // numericalProperties.
    for ([_][]const u8{ "level", "valuemax", "valuemin" }) |key| {
        const v = (props.get(key) orelse continue) orelse continue;
        try node.attrs.put(arena, key, try asValue(arena, v));
    }
    // tokenProperties: kept when truthy and not "false".
    for ([_][]const u8{ "autocomplete", "haspopup", "invalid", "orientation", "live", "relevant", "errormessage", "details" }) |key| {
        const v = (props.get(key) orelse continue) orelse continue;
        if (!truthy(v) or (v == .string and eql(v.string, "false"))) continue;
        try node.attrs.put(arena, key, try asValue(arena, v));
    }
    return node;
}

fn asValue(arena: Allocator, value: std.json.Value) !Value {
    return switch (value) {
        .string => |s| .{ .string = s },
        .bool => |b| .{ .boolean = b },
        .integer => |i| .{ .number = @floatFromInt(i) },
        .float => |f| .{ .number = f },
        else => .{ .string = try jsStringOf(arena, value) },
    };
}

fn jsStringOf(arena: Allocator, value: std.json.Value) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    try console.jsString(&out.writer, value);
    return out.written();
}

/// AXNode.createTree (ax_tree.zig).
pub const createTree = ax_tree.createTree;

/// Accessibility.snapshot's result: the kept nodes (ax_tree.keptTree)
/// serialized, an Iframe's frame snapshot its last child.
pub fn serializeRoot(arena: Allocator, root: *AX, verbose: bool) !?*Node {
    const kept = (try ax_tree.keptTree(arena, root, verbose)) orelse return null;
    return try fromKept(arena, kept);
}

fn fromKept(arena: Allocator, kept: *const ax_tree.Kept) !*Node {
    const node = try serialize(arena, kept.ax);
    for (kept.children.items) |child| try node.children.append(arena, try fromKept(arena, child));
    if (kept.frame) |frame| try node.children.append(arena, try fromKept(arena, frame));
    return node;
}

// ----------------------------------------------------------------------
// TextSnapshot: the uids
// ----------------------------------------------------------------------

/// A uid's DOM node, kept by the page until its next snapshot (idToNode).
pub const Target = struct {
    backend_node_id: i64,
    loader_id: []const u8,
    frame_id: []const u8,
};

/// The page's uniqueBackendNodeIdToMcpId: "<loaderId>_<backendNodeId>" to
/// uid, keys and values OWNED by `allocator`. Rebuilt whole by each
/// snapshot (TextSnapshot.create keeps only the keys it saw): nothing is
/// ever removed from it, so it holds no tombstones.
pub const UidMap = struct {
    map: std.StringHashMapUnmanaged([]u8) = .empty,

    pub fn deinit(self: *UidMap, allocator: Allocator) void {
        freeMap(allocator, &self.map);
    }
};

fn freeMap(allocator: Allocator, map: *std.StringHashMapUnmanaged([]u8)) void {
    var it = map.iterator();
    while (it.next()) |e| {
        allocator.free(e.key_ptr.*);
        allocator.free(e.value_ptr.*);
    }
    map.deinit(allocator);
}

/// TextSnapshot.create's numbering: pre-order, InlineTextBox children
/// dropped (layout fragments), an option's value its name; a node with a
/// DOM node keeps the uid the page gave its "<loaderId>_<backendNodeId>"
/// before, else gets "<snapshot>_<n>"; the page's map then forgets every
/// key this snapshot did not see. `targets` (in `arena`) gets each numbered
/// node by uid; uids are copied into `arena`.
pub fn assignIds(
    arena: Allocator,
    allocator: Allocator,
    root: *Node,
    snapshot_id: u32,
    uids: *UidMap,
    targets: *std.StringArrayHashMapUnmanaged(Target),
) !void {
    var state: Numbering = .{ .arena = arena, .allocator = allocator, .snapshot_id = snapshot_id, .previous = &uids.map, .targets = targets };
    errdefer freeMap(allocator, &state.next);
    try state.assign(root);
    // The keys this snapshot saw, and no other.
    uids.deinit(allocator);
    uids.map = state.next;
}

const Numbering = struct {
    arena: Allocator,
    allocator: Allocator,
    snapshot_id: u32,
    /// The map as the last snapshot left it.
    previous: *const std.StringHashMapUnmanaged([]u8),
    /// The map this snapshot makes: the keys it sees (OWNED).
    next: std.StringHashMapUnmanaged([]u8) = .empty,
    targets: *std.StringArrayHashMapUnmanaged(Target),
    counter: u32 = 0,

    fn assign(self: *Numbering, node: *Node) !void {
        if (node.backend_node_id) |backend| {
            const unique = try std.fmt.allocPrint(self.arena, "{s}_{d}", .{ node.loader_id, backend });
            if (self.next.get(unique)) |id| {
                node.id = try self.arena.dupe(u8, id);
            } else {
                // Re-use the uid when the unique id is the same; only a
                // node not seen before gets a new one.
                const id = if (self.previous.get(unique)) |existing|
                    try self.allocator.dupe(u8, existing)
                else blk: {
                    defer self.counter += 1;
                    break :blk try std.fmt.allocPrint(self.allocator, "{d}_{d}", .{ self.snapshot_id, self.counter });
                };
                errdefer self.allocator.free(id);
                const key = try self.allocator.dupe(u8, unique);
                errdefer self.allocator.free(key);
                try self.next.put(self.allocator, key, id);
                node.id = try self.arena.dupe(u8, id);
            }
        }
        var kept: std.ArrayList(*Node) = .empty;
        for (node.children.items) |child| {
            if (eql(child.role, "InlineTextBox")) continue;
            try kept.append(self.arena, child);
        }
        node.children = kept;
        for (node.children.items) |child| try self.assign(child);
        // An option's AXNode has no value: its text is.
        if (eql(node.role, "option")) if (node.name) |name| if (name.len != 0) {
            try node.attrs.put(self.arena, "value", .{ .string = name });
        };
        if (node.id.len != 0) try self.targets.put(self.arena, node.id, .{
            .backend_node_id = node.backend_node_id.?,
            .loader_id = node.loader_id,
            .frame_id = node.frame_id,
        });
    }
};

// ----------------------------------------------------------------------
// SnapshotFormatter.toString
// ----------------------------------------------------------------------

/// The snapshot's text: one line per node, each ending in a newline.
pub fn format(arena: Allocator, root: *const Node, verbose: bool) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    try formatNode(arena, &out.writer, root, 0, verbose);
    return out.written();
}

fn formatNode(arena: Allocator, w: *std.Io.Writer, node: *const Node, depth: usize, verbose: bool) !void {
    try w.splatByteAll(' ', depth * 2);
    for (try attributesOf(arena, node), 0..) |a, i| {
        if (i != 0) try w.writeByte(' ');
        try w.writeAll(a);
    }
    try w.writeByte('\n');
    if (try hasRedundantTextChildren(arena, node, verbose)) return;
    for (node.children.items) |child| try formatNode(arena, w, child, depth + 1, verbose);
}

/// Children that are only StaticText leaves spelling the node's name.
fn hasRedundantTextChildren(arena: Allocator, node: *const Node, verbose: bool) !bool {
    const name = node.name orelse return false;
    if (verbose or name.len == 0 or node.children.items.len == 0) return false;
    var text: std.ArrayList(u8) = .empty;
    for (node.children.items) |child| {
        if (!eql(child.role, "StaticText") or child.children.items.len != 0) return false;
        try text.appendSlice(arena, child.name orelse "");
    }
    return equalIgnoringWhitespace(text.items, name);
}

/// stripWhitespace(a) === stripWhitespace(b): JavaScript's \s removed.
fn equalIgnoringWhitespace(a: []const u8, b: []const u8) bool {
    var i: usize = 0;
    var j: usize = 0;
    while (true) {
        i = skipSpace(a, i);
        j = skipSpace(b, j);
        if (i >= a.len or j >= b.len) return i >= a.len and j >= b.len;
        if (a[i] != b[j]) return false;
        i += 1;
        j += 1;
    }
}

fn skipSpace(s: []const u8, from: usize) usize {
    var i = from;
    while (i < s.len) {
        const len = std.unicode.utf8ByteSequenceLength(s[i]) catch return i;
        if (i + len > s.len) return i;
        const cp = std.unicode.utf8Decode(s[i .. i + len]) catch return i;
        if (!text_util.isJsSpace(cp)) return i;
        i += len;
    }
    return i;
}

/// booleanPropertyMap.
fn mappedName(attr: []const u8) ?[]const u8 {
    if (eql(attr, "disabled")) return "disableable";
    if (eql(attr, "expanded")) return "expandable";
    if (eql(attr, "focused")) return "focusable";
    if (eql(attr, "selected")) return "selectable";
    return null;
}

/// #getAttributes: the uid, the role ("none" printed "ignored", none for
/// StaticText), the quoted name, then each key in order - a boolean key's
/// mapped name whenever it is present, its own name when true, a string's
/// or number's `key="value"` (an option's value equal to its name left
/// out; a data: URL cut).
fn attributesOf(arena: Allocator, node: *const Node) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    if (node.id.len != 0) try out.append(arena, try std.fmt.allocPrint(arena, "uid={s}", .{node.id}));
    if (node.role.len != 0 and !eql(node.role, "StaticText")) try out.append(arena, if (eql(node.role, "none")) "ignored" else node.role);
    if (node.name) |name| if (name.len != 0) try out.append(arena, try std.fmt.allocPrint(arena, "\"{s}\"", .{name}));
    const keys = try arena.dupe([]const u8, node.attrs.keys());
    // Array.prototype.sort: UTF-16 code unit order (the keys are ASCII).
    std.mem.sort([]const u8, keys, {}, struct {
        fn less(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.less);
    const is_option = eql(node.role, "option");
    for (keys) |key| {
        const value = node.attrs.get(key).?;
        if (mappedName(key)) |mapped| if (value == .boolean and !(is_option and eql(mapped, "selectable"))) {
            try out.append(arena, mapped);
        };
        switch (value) {
            .boolean => |b| if (b) try out.append(arena, key),
            .string => |s| {
                const shown = if (eql(key, "url") and std.mem.startsWith(u8, s, "data:")) try text_util.truncateUrl(arena, s) else s;
                if (is_option and eql(key, "value") and node.name != null and eql(shown, node.name.?)) continue;
                try out.append(arena, try std.fmt.allocPrint(arena, "{s}=\"{s}\"", .{ key, shown }));
            },
            .number => |n| {
                var number: std.Io.Writer.Allocating = .init(arena);
                try console.jsNumber(&number.writer, n);
                try out.append(arena, try std.fmt.allocPrint(arena, "{s}=\"{s}\"", .{ key, number.written() }));
            },
        }
    }
    return out.items;
}

// ----------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------

const testing = std.testing;

fn parseNodes(arena: Allocator, text: []const u8) ![]const std.json.Value {
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, text, .{});
    return parsed.array.items;
}

/// A page as getFullAXTree gives it: a link, a heading, an ignored generic
/// around a checkbox, a focused text field and a disabled button.
const sample_page =
    \\[{"nodeId":"1","ignored":false,"role":{"type":"internalRole","value":"RootWebArea"},"name":{"type":"computedString","value":"T"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}},{"name":"focused","value":{"type":"booleanOrUndefined","value":true}}],"childIds":["2","5","7","9","10"],"backendDOMNodeId":1},
    \\ {"nodeId":"2","ignored":false,"role":{"type":"role","value":"link"},"name":{"type":"computedString","value":"Go"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}}],"childIds":["3"],"backendDOMNodeId":7},
    \\ {"nodeId":"3","ignored":false,"role":{"type":"role","value":"StaticText"},"name":{"type":"computedString","value":"Go"},"childIds":["4"],"backendDOMNodeId":8},
    \\ {"nodeId":"4","ignored":false,"role":{"type":"role","value":"InlineTextBox"},"name":{"type":"computedString","value":"Go"},"childIds":[]},
    \\ {"nodeId":"5","ignored":false,"role":{"type":"role","value":"heading"},"name":{"type":"computedString","value":"Title"},"properties":[{"name":"level","value":{"type":"integer","value":2}}],"childIds":["6"],"backendDOMNodeId":9},
    \\ {"nodeId":"6","ignored":false,"role":{"type":"role","value":"StaticText"},"name":{"type":"computedString","value":"Title"},"childIds":[],"backendDOMNodeId":10},
    \\ {"nodeId":"7","ignored":true,"role":{"type":"role","value":"none"},"childIds":["8"],"backendDOMNodeId":11},
    \\ {"nodeId":"8","ignored":false,"role":{"type":"role","value":"checkbox"},"name":{"type":"computedString","value":"Agree"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}},{"name":"checked","value":{"type":"tristate","value":"mixed"}}],"childIds":[],"backendDOMNodeId":12},
    \\ {"nodeId":"9","ignored":false,"role":{"type":"role","value":"textbox"},"name":{"type":"computedString","value":"Name"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}},{"name":"focused","value":{"type":"booleanOrUndefined","value":true}},{"name":"editable","value":{"type":"token","value":"plaintext"}},{"name":"multiline","value":{"type":"boolean","value":false}},{"name":"readonly","value":{"type":"boolean","value":false}},{"name":"required","value":{"type":"boolean","value":false}}],"childIds":[],"backendDOMNodeId":13},
    \\ {"nodeId":"10","ignored":false,"role":{"type":"role","value":"button"},"name":{"type":"computedString","value":"Send"},"properties":[{"name":"disabled","value":{"type":"boolean","value":true}},{"name":"invalid","value":{"type":"token","value":"false"}}],"childIds":["11"],"backendDOMNodeId":14},
    \\ {"nodeId":"11","ignored":false,"role":{"type":"role","value":"StaticText"},"name":{"type":"computedString","value":"Send"},"childIds":[],"backendDOMNodeId":15}]
;

fn numbered(arena: Allocator, uids: *UidMap, targets: *std.StringArrayHashMapUnmanaged(Target), tree: []const u8, loader: []const u8, snapshot_id: u32, verbose: bool) !*Node {
    const root = (try createTree(arena, try parseNodes(arena, tree), loader, "F")).?;
    const serialized = (try serializeRoot(arena, root, verbose)).?;
    try assignIds(arena, testing.allocator, serialized, snapshot_id, uids, targets);
    return serialized;
}

test "a snapshot keeps the interesting nodes, numbers them in pre-order and prints their attributes in key order" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var uids: UidMap = .{};
    defer uids.deinit(testing.allocator);
    var targets: std.StringArrayHashMapUnmanaged(Target) = .empty;
    const root = try numbered(arena, &uids, &targets, sample_page, "L", 1, false);
    // The link's only text spells its name: not repeated. The ignored
    // generic goes; its checkbox moves up. A RootWebArea's focus is its
    // frame's; "focusable" is printed for a "focused" key; a control's
    // text is not interesting; an "invalid" of "false" is not a token.
    try testing.expectEqualStrings(
        \\uid=1_0 RootWebArea "T"
        \\  uid=1_1 link "Go"
        \\  uid=1_3 heading "Title" level="2"
        \\  uid=1_4 checkbox "Agree" checked="mixed"
        \\  uid=1_5 textbox "Name" focusable focused
        \\  uid=1_6 button "Send" disableable disabled
        \\
    , try format(arena, root, false));
    try testing.expectEqual(@as(usize, 7), targets.count());
    try testing.expectEqual(@as(i64, 8), targets.get("1_2").?.backend_node_id);
    try testing.expectEqualStrings("F", targets.get("1_2").?.frame_id);
}

test "a later snapshot of the same document keeps its uids; a new document's are new and the old ones forgotten" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var uids: UidMap = .{};
    defer uids.deinit(testing.allocator);
    var t1: std.StringArrayHashMapUnmanaged(Target) = .empty;
    _ = try numbered(arena, &uids, &t1, sample_page, "L", 1, false);
    try testing.expectEqual(@as(u32, 7), uids.map.count());
    var t2: std.StringArrayHashMapUnmanaged(Target) = .empty;
    const second = try numbered(arena, &uids, &t2, sample_page, "L", 2, false);
    try testing.expectEqualStrings("1_1", second.children.items[0].id);
    var t3: std.StringArrayHashMapUnmanaged(Target) = .empty;
    const third = try numbered(arena, &uids, &t3, sample_page, "M", 3, false);
    try testing.expectEqualStrings("3_1", third.children.items[0].id);
    try testing.expectEqual(@as(u32, 7), uids.map.count());
}

test "verbose keeps every node but the InlineTextBoxes, and prints text children" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var uids: UidMap = .{};
    defer uids.deinit(testing.allocator);
    var targets: std.StringArrayHashMapUnmanaged(Target) = .empty;
    const root = try numbered(arena, &uids, &targets, sample_page, "L", 1, true);
    try testing.expectEqualStrings(
        \\uid=1_0 RootWebArea "T"
        \\  uid=1_1 link "Go"
        \\    uid=1_2 "Go"
        \\  uid=1_3 heading "Title" level="2"
        \\    uid=1_4 "Title"
        \\  uid=1_5 ignored
        \\    uid=1_6 checkbox "Agree" checked="mixed"
        \\  uid=1_7 textbox "Name" focusable focused
        \\  uid=1_8 button "Send" disableable disabled
        \\    uid=1_9 "Send"
        \\
    , try format(arena, root, true));
}

test "an option's value is its name, printed once; a data: URL is cut" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const run_300: [300]u8 = @splat('a');
    const run_239: [255 - 16]u8 = @splat('a');
    const long_url = "data:text/plain," ++ run_300;
    const tree = "[" ++
        \\{"nodeId":"1","role":{"type":"internalRole","value":"RootWebArea"},"name":{"type":"computedString","value":""},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}}],"childIds":["2","3"],"backendDOMNodeId":1},
        \\{"nodeId":"2","role":{"type":"role","value":"option"},"name":{"type":"computedString","value":"Red"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}},{"name":"selected","value":{"type":"booleanOrUndefined","value":true}}],"childIds":[],"backendDOMNodeId":2},
        \\{"nodeId":"3","role":{"type":"role","value":"link"},"name":{"type":"computedString","value":"L"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}},{"name":"url","value":{"type":"string","value":"
    ++ long_url ++
        \\"}}],"childIds":[],"backendDOMNodeId":3}]
    ;
    var uids: UidMap = .{};
    defer uids.deinit(testing.allocator);
    var targets: std.StringArrayHashMapUnmanaged(Target) = .empty;
    const root = try numbered(arena, &uids, &targets, tree, "L", 1, false);
    const cut = "data:text/plain," ++ run_239 ++ "... <truncated>";
    try testing.expectEqualStrings("uid=1_0 RootWebArea\n  uid=1_1 option \"Red\" selected\n  uid=1_2 link \"L\" url=\"" ++ cut ++ "\"\n", try format(arena, root, false));
}

test "names compare without JavaScript's \\s: ASCII and Unicode spaces" {
    try testing.expect(equalIgnoringWhitespace("a b\u{a0}c", "abc"));
    try testing.expect(!equalIgnoringWhitespace("ab", "abc"));
    try testing.expect(equalIgnoringWhitespace(" ", ""));
}
