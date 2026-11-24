//! The tree part of take_snapshot: a frame's AXNode objects (CDP's
//! Accessibility.getFullAXTree answer) as Puppeteer keeps them, which nodes
//! a snapshot keeps, and the order it numbers them in. Translated from
//! puppeteer-core 25.17.0's lib/puppeteer/cdp/Accessibility.js
//! (Accessibility.snapshot with includeIframes, AXNode: isInteresting,
//! isLeafNode, isControl, isLandmark, createTree; Copyright 2018 Google Inc.,
//! Apache-2.0) and chrome-devtools-mcp-v1.13.0's src/TextSnapshot.ts (the
//! numbering's walk; Copyright 2025 Google LLC, Apache-2.0).
//! THIRD_PARTY_NOTICES.md.
//!
//! std only, so the MCP server (snapshot.zig, which serializes and prints
//! the kept nodes) and the differential suite's harness (tools/mcp_diff,
//! which replays Google's numbering on Chrome's tree) share one copy of the
//! rules.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// One AXNode of a frame's tree, as Puppeteer's AXNode keeps it.
pub const AX = struct {
    payload: std.json.ObjectMap,
    children: std.ArrayList(*AX) = .empty,
    /// An Iframe's own frame's tree (populateIframes: its content frame),
    /// and what a snapshot keeps of it.
    frame_tree: ?*AX = null,
    frame_kept: ?*Kept = null,
    role: []const u8,
    name: []const u8,
    description: []const u8,
    ignored: bool,
    richly_editable: bool = false,
    editable: bool = false,
    focusable: bool = false,
    hidden: bool = false,
    busy: bool = false,
    modal: bool = false,
    has_errormessage: bool = false,
    has_details: bool = false,
    roledescription: bool = false,
    /// `#live`: truthy and not "off".
    live: bool = false,
    cached_focusable_child: ?bool = null,
    /// The frame's loader (Puppeteer's realm.environment._loaderId) and id.
    loader_id: []const u8,
    frame_id: []const u8,

    fn init(payload: std.json.ObjectMap, loader_id: []const u8, frame_id: []const u8) AX {
        var self: AX = .{
            .payload = payload,
            .role = innerString(payload.get("role")) orelse "Unknown",
            .name = innerString(payload.get("name")) orelse "",
            .description = innerString(payload.get("description")) orelse "",
            .ignored = truthy(payload.get("ignored")),
            .loader_id = loader_id,
            .frame_id = frame_id,
        };
        for (properties(payload)) |property| {
            if (property != .object) continue;
            const name = str(property.object.get("name"));
            const value = propertyValue(property);
            if (eql(name, "editable")) {
                self.richly_editable = value != null and value.? == .string and eql(value.?.string, "richtext");
                self.editable = true;
            }
            if (eql(name, "focusable")) self.focusable = truthy(value);
            if (eql(name, "hidden")) self.hidden = truthy(value);
            if (eql(name, "busy")) self.busy = truthy(value);
            if (eql(name, "live")) self.live = truthy(value) and !(value.? == .string and eql(value.?.string, "off"));
            if (eql(name, "modal")) self.modal = truthy(value);
            if (eql(name, "roledescription")) self.roledescription = truthy(value);
            if (eql(name, "errormessage")) self.has_errormessage = true;
            if (eql(name, "details")) self.has_details = true;
        }
        return self;
    }

    fn isPlainTextField(self: *const AX) bool {
        if (self.richly_editable) return false;
        if (self.editable) return true;
        return eql(self.role, "textbox") or eql(self.role, "searchbox");
    }

    fn isTextOnlyObject(self: *const AX) bool {
        return oneOf(self.role, &.{ "LineBreak", "text", "InlineTextBox", "StaticText" });
    }

    fn hasFocusableChild(self: *AX) bool {
        if (self.cached_focusable_child) |c| return c;
        var found = false;
        for (self.children.items) |child| {
            if (child.focusable or child.hasFocusableChild()) {
                found = true;
                break;
            }
        }
        self.cached_focusable_child = found;
        return found;
    }

    pub fn isLeafNode(self: *AX) bool {
        if (self.children.items.len == 0) return true;
        // Children used as implementation details are exposed as a leaf.
        if (self.isPlainTextField() or self.isTextOnlyObject()) return true;
        // Roles whose children are only presentational.
        if (oneOf(self.role, &.{ "doc-cover", "graphics-symbol", "img", "image", "Meter", "scrollbar", "slider", "separator", "progressbar" })) return true;
        if (self.hasFocusableChild()) return false;
        if (eql(self.role, "heading") and self.name.len != 0) return true;
        return false;
    }

    pub fn isControl(self: *const AX) bool {
        return oneOf(self.role, &.{ "button", "checkbox", "ColorWell", "combobox", "DisclosureTriangle", "listbox", "menu", "menubar", "menuitem", "menuitemcheckbox", "menuitemradio", "radio", "scrollbar", "searchbox", "slider", "spinbutton", "switch", "tab", "textbox", "tree", "treeitem" });
    }

    fn isLandmark(self: *const AX) bool {
        return oneOf(self.role, &.{ "banner", "complementary", "contentinfo", "form", "main", "navigation", "region", "search" });
    }

    pub fn isInteresting(self: *AX, inside_control: bool) bool {
        if (eql(self.role, "Ignored") or self.hidden or self.ignored) return false;
        if (self.isLandmark()) return true;
        if (self.focusable or self.richly_editable or self.busy or self.live or self.modal or self.has_errormessage or self.has_details or self.roledescription) return true;
        // Not focusable but a control's role.
        if (self.isControl()) return true;
        // A control's non-focusable descendant.
        if (inside_control) return false;
        return self.isLeafNode() and (self.name.len != 0 or self.description.len != 0);
    }

    /// `payload.backendDOMNodeId`, when it names a node.
    pub fn backendNodeId(self: *const AX) ?i64 {
        const b = self.payload.get("backendDOMNodeId") orelse return null;
        return if (b == .integer and b.integer != 0) b.integer else null;
    }
};

/// A node a snapshot keeps (Puppeteer's serializeTree output, before
/// serialize): its kept descendants, then its frame's snapshot.
pub const Kept = struct {
    ax: *AX,
    children: std.ArrayList(*Kept) = .empty,
    frame: ?*Kept = null,
};

pub fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn oneOf(role: []const u8, roles: []const []const u8) bool {
    for (roles) |r| if (eql(role, r)) return true;
    return false;
}

pub fn str(value: ?std.json.Value) []const u8 {
    const v = value orelse return "";
    return if (v == .string) v.string else "";
}

/// An AXValue's `value`, when it is a string.
pub fn innerString(value: ?std.json.Value) ?[]const u8 {
    const v = value orelse return null;
    if (v != .object) return null;
    const inner = v.object.get("value") orelse return null;
    return if (inner == .string) inner.string else null;
}

pub fn properties(payload: std.json.ObjectMap) []const std.json.Value {
    const p = payload.get("properties") orelse return &.{};
    return if (p == .array) p.array.items else &.{};
}

/// A property's `value.value` (null: undefined).
pub fn propertyValue(property: std.json.Value) ?std.json.Value {
    const value = property.object.get("value") orelse return null;
    if (value != .object) return null;
    return value.object.get("value");
}

/// JavaScript truthiness (`!!value`; null is undefined).
pub fn truthy(value: ?std.json.Value) bool {
    const v = value orelse return false;
    return switch (v) {
        .null => false,
        .bool => |b| b,
        .integer => |i| i != 0,
        .float => |f| f != 0 and !std.math.isNan(f),
        .number_string => |s| s.len != 0,
        .string => |s| s.len != 0,
        .array, .object => true,
    };
}

/// AXNode.createTree: the nodes by id, children from childIds; the root is
/// the first node.
pub fn createTree(arena: Allocator, nodes: []const std.json.Value, loader_id: []const u8, frame_id: []const u8) !?*AX {
    var by_id: std.StringArrayHashMapUnmanaged(*AX) = .empty;
    for (nodes) |payload| {
        if (payload != .object) continue;
        const ax = try arena.create(AX);
        ax.* = AX.init(payload.object, loader_id, frame_id);
        try by_id.put(arena, str(payload.object.get("nodeId")), ax);
    }
    for (by_id.values()) |ax| {
        const ids = ax.payload.get("childIds") orelse continue;
        if (ids != .array) continue;
        for (ids.array.items) |child_id| {
            if (child_id != .string) continue;
            if (by_id.get(child_id.string)) |child| try ax.children.append(arena, child);
        }
    }
    if (by_id.count() == 0) return null;
    return by_id.values()[0];
}

/// The tree's Iframe nodes that have a DOM node, depth first
/// (populateIframes' walk): the caller gives each its frame's tree.
pub fn iframes(arena: Allocator, root: *AX, out: *std.ArrayList(*AX)) !void {
    const role = innerString(root.payload.get("role")) orelse "";
    if (eql(role, "Iframe") and root.backendNodeId() != null) try out.append(arena, root);
    for (root.children.items) |child| try iframes(arena, child, out);
}

/// The end of Accessibility.snapshot: each Iframe's own frame's snapshot
/// first (populateIframes, with the same options), then the nodes kept -
/// all of them when `verbose`, else the interesting ones and the Iframes
/// with a snapshot - and the first of what serializeTree returns.
pub fn keptTree(arena: Allocator, root: *AX, verbose: bool) !?*Kept {
    var frames: std.ArrayList(*AX) = .empty;
    try iframes(arena, root, &frames);
    for (frames.items) |iframe| {
        if (iframe.frame_tree) |tree| iframe.frame_kept = try keptTree(arena, tree, verbose);
    }
    if (verbose) {
        const all = try build(arena, root, null);
        return if (all.len > 0) all[0] else null;
    }
    var interesting: std.AutoHashMapUnmanaged(*AX, void) = .empty;
    try collectInteresting(arena, &interesting, root, false);
    const kept = try build(arena, root, &interesting);
    return if (kept.len > 0) kept[0] else null;
}

fn collectInteresting(arena: Allocator, set: *std.AutoHashMapUnmanaged(*AX, void), node: *AX, inside_control: bool) !void {
    if (node.isInteresting(inside_control) or node.frame_kept != null) try set.put(arena, node, {});
    if (node.isLeafNode()) return;
    const inside = inside_control or node.isControl();
    for (node.children.items) |child| try collectInteresting(arena, set, child, inside);
}

/// serializeTree: a kept node with its kept descendants, or - for one not
/// kept - its kept descendants in its place.
fn build(arena: Allocator, node: *AX, interesting: ?*std.AutoHashMapUnmanaged(*AX, void)) ![]*Kept {
    var children: std.ArrayList(*Kept) = .empty;
    for (node.children.items) |child| try children.appendSlice(arena, try build(arena, child, interesting));
    if (interesting) |set| if (!set.contains(node)) return children.items;
    const kept = try arena.create(Kept);
    kept.* = .{ .ax = node, .children = children, .frame = node.frame_kept };
    const one = try arena.alloc(*Kept, 1);
    one[0] = kept;
    return one;
}

/// TextSnapshot.create's walk: the kept nodes in the order assignIds
/// numbers them - pre-order, a node's children then its frame's snapshot,
/// layout-only InlineTextBox children (and what is under them) left out.
pub fn numberingOrder(arena: Allocator, kept: *Kept, out: *std.ArrayList(*Kept)) !void {
    try out.append(arena, kept);
    for (kept.children.items) |child| {
        if (eql(child.ax.role, "InlineTextBox")) continue;
        try numberingOrder(arena, child, out);
    }
    if (kept.frame) |frame| if (!eql(frame.ax.role, "InlineTextBox")) try numberingOrder(arena, frame, out);
}

test "keptTree: interesting nodes, a control's text left out, an iframe's snapshot under its Iframe; numbering order" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const main =
        \\[{"nodeId":"1","role":{"type":"internalRole","value":"RootWebArea"},"name":{"type":"computedString","value":"T"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}}],"childIds":["2","4"],"backendDOMNodeId":1},
        \\ {"nodeId":"2","role":{"type":"role","value":"button"},"name":{"type":"computedString","value":"Go"},"childIds":["3"],"backendDOMNodeId":2},
        \\ {"nodeId":"3","role":{"type":"role","value":"StaticText"},"name":{"type":"computedString","value":"Go"},"childIds":[],"backendDOMNodeId":3},
        \\ {"nodeId":"4","role":{"type":"internalRole","value":"Iframe"},"childIds":[],"backendDOMNodeId":4}]
    ;
    const inner =
        \\[{"nodeId":"1","role":{"type":"internalRole","value":"RootWebArea"},"name":{"type":"computedString","value":"In"},"properties":[{"name":"focusable","value":{"type":"booleanOrUndefined","value":true}}],"childIds":["2"],"backendDOMNodeId":10},
        \\ {"nodeId":"2","role":{"type":"role","value":"StaticText"},"name":{"type":"computedString","value":"hi"},"childIds":["3"],"backendDOMNodeId":11},
        \\ {"nodeId":"3","role":{"type":"role","value":"InlineTextBox"},"name":{"type":"computedString","value":"hi"},"childIds":[]}]
    ;
    const parse = struct {
        fn nodes(a: Allocator, text: []const u8) ![]const std.json.Value {
            return (try std.json.parseFromSliceLeaky(std.json.Value, a, text, .{})).array.items;
        }
    };
    const root = (try createTree(arena, try parse.nodes(arena, main), "L", "F")).?;
    var frames: std.ArrayList(*AX) = .empty;
    try iframes(arena, root, &frames);
    try std.testing.expectEqual(@as(usize, 1), frames.items.len);
    frames.items[0].frame_tree = (try createTree(arena, try parse.nodes(arena, inner), "M", "G")).?;

    const kept = (try keptTree(arena, root, false)).?;
    var order: std.ArrayList(*Kept) = .empty;
    try numberingOrder(arena, kept, &order);
    var ids: std.ArrayList(i64) = .empty;
    for (order.items) |k| try ids.append(arena, k.ax.backendNodeId().?);
    // The button's text is a control's: not kept. The Iframe is, for its
    // snapshot.
    try std.testing.expectEqualSlices(i64, &.{ 1, 2, 4, 10, 11 }, ids.items);

    // Verbose keeps every node; the InlineTextBox is not numbered.
    frames.items[0].frame_kept = null;
    const all = (try keptTree(arena, root, true)).?;
    order.clearRetainingCapacity();
    try numberingOrder(arena, all, &order);
    ids.clearRetainingCapacity();
    for (order.items) |k| try ids.append(arena, k.ax.backendNodeId() orelse 0);
    try std.testing.expectEqualSlices(i64, &.{ 1, 2, 3, 4, 10, 11 }, ids.items);
}
