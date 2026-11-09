//! Range's contents algorithms against the DOM's steps as written, on
//! random trees (lane crash1 batch 3).
//!
//! Range.zig answers extract, clone the contents, deleteContents and the
//! stringifier from where the start's and end's paths meet (Meeting): the
//! common ancestor's children on the two paths are the partially contained
//! ones, the children strictly between them are contained, and the subrange
//! levels run on a heap stack instead of recursing. That is an argument
//! about the steps; this file is the proof (docs/lessons/architecture-
//! count-tree-scopes-from-the-walks-moves.md): each random tree is copied
//! twice, the same range is taken in both, Range runs on one copy and a
//! literal transcription of DOM 5.5 - its own boundary point comparison,
//! "contained" and "partially contained" by their definitions, recursion
//! over subranges - on the other, and the two documents, fragments, strings
//! and collapsed boundary points must agree.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const webidl = @import("webidl");

const Node = *runtime.Instance;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// An engine-less HTML document with a body.
const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: Node = undefined,
    body: Node = undefined,

    fn open(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(testing.allocator), .ctx = try runtime.ContextData.init(testing.allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.body = try interfaces.Document.call_createElement(self.document, str("body"), .notPassed());
        _ = try interfaces.Node.call_appendChild(self.document, self.body);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

// ---------------------------------------------------------------------------
// The tree, read through the Node interface
// ---------------------------------------------------------------------------

fn parentOf(node: Node) ?Node {
    return interfaces.Node.get_parentNode(node) catch null;
}

fn firstChildOf(node: Node) ?Node {
    return interfaces.Node.get_firstChild(node) catch null;
}

fn nextOf(node: Node) ?Node {
    return interfaces.Node.get_nextSibling(node) catch null;
}

fn indexOf(node: Node) u32 {
    var i: u32 = 0;
    var sibling = interfaces.Node.get_previousSibling(node) catch null;
    while (sibling) |s| : (sibling = interfaces.Node.get_previousSibling(s) catch null) i += 1;
    return i;
}

fn nodeType(node: Node) u16 {
    return interfaces.Node.get_nodeType(node) catch 0;
}

fn isCharacterData(node: Node) bool {
    const t = nodeType(node);
    return t == interfaces.Node.get_TEXT_NODE() or t == interfaces.Node.get_COMMENT_NODE() or
        t == interfaces.Node.get_PROCESSING_INSTRUCTION_NODE() or t == interfaces.Node.get_CDATA_SECTION_NODE();
}

fn isText(node: Node) bool {
    const t = nodeType(node);
    return t == interfaces.Node.get_TEXT_NODE() or t == interfaces.Node.get_CDATA_SECTION_NODE();
}

/// DOM 4.2 "length".
fn lengthOf(node: Node) u32 {
    if (isCharacterData(node)) return interfaces.CharacterData.get_length(node) catch 0;
    var count: u32 = 0;
    var child = firstChildOf(node);
    while (child) |c| : (child = nextOf(c)) count += 1;
    return count;
}

fn rootOf(node: Node) Node {
    var current = node;
    while (parentOf(current)) |p| current = p;
    return current;
}

fn isInclusiveAncestor(ancestor: Node, node: Node) bool {
    var current: ?Node = node;
    while (current) |c| : (current = parentOf(c)) {
        if (c == ancestor) return true;
    }
    return false;
}

fn isAncestor(ancestor: Node, node: Node) bool {
    return ancestor != node and isInclusiveAncestor(ancestor, node);
}

/// The node's indices from its root down, root first excluded.
fn pathOf(allocator: std.mem.Allocator, node: Node, root: Node) ![]u32 {
    var path: std.ArrayListUnmanaged(u32) = .empty;
    errdefer path.deinit(allocator);
    var current = node;
    while (current != root) {
        try path.append(allocator, indexOf(current));
        current = parentOf(current) orelse return error.NotUnderRoot;
    }
    std.mem.reverse(u32, path.items);
    return path.toOwnedSlice(allocator);
}

fn nodeAt(root: Node, path: []const u32) !Node {
    var current = root;
    for (path) |index| {
        var child = firstChildOf(current);
        var i: u32 = 0;
        while (child) |c| : (child = nextOf(c)) {
            if (i == index) break;
            i += 1;
        }
        current = child orelse return error.NoSuchNode;
    }
    return current;
}

/// "A is following B": A after B in tree order (same tree).
fn isFollowing(allocator: std.mem.Allocator, a: Node, b: Node) !bool {
    if (a == b) return false;
    const root = rootOf(a);
    if (rootOf(b) != root) return false;
    const pa = try pathOf(allocator, a, root);
    defer allocator.free(pa);
    const pb = try pathOf(allocator, b, root);
    defer allocator.free(pb);
    const n = @min(pa.len, pb.len);
    for (pa[0..n], pb[0..n]) |x, y| {
        if (x != y) return x > y;
    }
    return pa.len > pb.len;
}

const Position = enum { before, equal, after };

/// DOM 5.2, the steps as written.
fn position(allocator: std.mem.Allocator, node_a: Node, offset_a: u32, node_b: Node, offset_b: u32) !Position {
    if (node_a == node_b) {
        if (offset_a == offset_b) return .equal;
        return if (offset_a < offset_b) .before else .after;
    }
    if (try isFollowing(allocator, node_a, node_b)) {
        return switch (try position(allocator, node_b, offset_b, node_a, offset_a)) {
            .before => .after,
            .after => .before,
            .equal => .equal,
        };
    }
    if (isAncestor(node_a, node_b)) {
        var child = node_b;
        while (parentOf(child)) |p| {
            if (p == node_a) break;
            child = p;
        }
        if (indexOf(child) < offset_a) return .after;
    }
    return .before;
}

// ---------------------------------------------------------------------------
// DOM 5.5, transcribed
// ---------------------------------------------------------------------------

const Bounds = struct { start_node: Node, start_offset: u32, end_node: Node, end_offset: u32 };

const Literal = struct {
    allocator: std.mem.Allocator,
    document: Node,

    fn contained(self: Literal, b: Bounds, node: Node) !bool {
        if (rootOf(node) != rootOf(b.start_node)) return false;
        if (try position(self.allocator, node, 0, b.start_node, b.start_offset) != .after) return false;
        return try position(self.allocator, node, lengthOf(node), b.end_node, b.end_offset) == .before;
    }

    fn partiallyContained(_: Literal, b: Bounds, node: Node) bool {
        return isInclusiveAncestor(node, b.start_node) != isInclusiveAncestor(node, b.end_node);
    }

    fn substringClone(_: Literal, node: Node, offset: u32, count: u32) !Node {
        const clone = try interfaces.Node.call_cloneNode(node, webidl.Opt(bool).passed(false));
        var data = try interfaces.CharacterData.call_substringData(node, offset, count);
        defer data.deinit(node.ctx.allocator);
        try interfaces.CharacterData.set_data(clone, data);
        return clone;
    }

    fn replaceEmpty(_: Literal, node: Node, offset: u32, count: u32) !void {
        try interfaces.CharacterData.call_replaceData(node, offset, count, runtime.DOMString.initEmpty());
    }

    /// "extract" (`clone` false) or "clone the contents" (`clone` true) of
    /// `b`; for the range itself (`range` non-null) step 15 sets it.
    fn contents(self: Literal, b: Bounds, clone: bool, range: ?Node) anyerror!Node {
        const fragment = try interfaces.Document.call_createDocumentFragment(self.document);
        if (b.start_node == b.end_node and b.start_offset == b.end_offset) return fragment;
        if (b.start_node == b.end_node and isCharacterData(b.start_node)) {
            _ = try interfaces.Node.call_appendChild(fragment, try self.substringClone(b.start_node, b.start_offset, b.end_offset - b.start_offset));
            if (!clone) try self.replaceEmpty(b.start_node, b.start_offset, b.end_offset - b.start_offset);
            return fragment;
        }
        var common = b.start_node;
        while (!isInclusiveAncestor(common, b.end_node)) common = parentOf(common).?;
        var first: ?Node = null;
        if (!isInclusiveAncestor(b.start_node, b.end_node)) {
            var c = firstChildOf(common);
            while (c) |n| : (c = nextOf(n)) {
                if (self.partiallyContained(b, n)) {
                    first = n;
                    break;
                }
            }
        }
        var last: ?Node = null;
        if (!isInclusiveAncestor(b.end_node, b.start_node)) {
            var c = interfaces.Node.get_lastChild(common) catch null;
            while (c) |n| : (c = interfaces.Node.get_previousSibling(n) catch null) {
                if (self.partiallyContained(b, n)) {
                    last = n;
                    break;
                }
            }
        }
        var children: std.ArrayListUnmanaged(Node) = .empty;
        defer children.deinit(self.allocator);
        var c = firstChildOf(common);
        while (c) |n| : (c = nextOf(n)) {
            if (try self.contained(b, n)) try children.append(self.allocator, n);
        }
        if (!clone) {
            if (range) |r| {
                var new_node = b.start_node;
                var new_offset = b.start_offset;
                if (!isInclusiveAncestor(b.start_node, b.end_node)) {
                    var reference = b.start_node;
                    while (parentOf(reference)) |p| {
                        if (isInclusiveAncestor(p, b.end_node)) break;
                        reference = p;
                    }
                    new_node = parentOf(reference).?;
                    new_offset = indexOf(reference) + 1;
                }
                try interfaces.Range.call_setStart(r, new_node, new_offset);
                try interfaces.Range.call_setEnd(r, new_node, new_offset);
            }
        }
        if (first) |f| {
            if (isCharacterData(f)) {
                const count = lengthOf(b.start_node) - b.start_offset;
                _ = try interfaces.Node.call_appendChild(fragment, try self.substringClone(b.start_node, b.start_offset, count));
                if (!clone) try self.replaceEmpty(b.start_node, b.start_offset, count);
            } else {
                const copy = try interfaces.Node.call_cloneNode(f, webidl.Opt(bool).passed(false));
                _ = try interfaces.Node.call_appendChild(fragment, copy);
                const sub = try self.contents(.{ .start_node = b.start_node, .start_offset = b.start_offset, .end_node = f, .end_offset = lengthOf(f) }, clone, null);
                _ = try interfaces.Node.call_appendChild(copy, sub);
            }
        }
        for (children.items) |child| {
            const node = if (clone) try interfaces.Node.call_cloneNode(child, webidl.Opt(bool).passed(true)) else child;
            _ = try interfaces.Node.call_appendChild(fragment, node);
        }
        if (last) |l| {
            if (isCharacterData(l)) {
                _ = try interfaces.Node.call_appendChild(fragment, try self.substringClone(b.end_node, 0, b.end_offset));
                if (!clone) try self.replaceEmpty(b.end_node, 0, b.end_offset);
            } else {
                const copy = try interfaces.Node.call_cloneNode(l, webidl.Opt(bool).passed(false));
                _ = try interfaces.Node.call_appendChild(fragment, copy);
                const sub = try self.contents(.{ .start_node = l, .start_offset = 0, .end_node = b.end_node, .end_offset = b.end_offset }, clone, null);
                _ = try interfaces.Node.call_appendChild(copy, sub);
            }
        }
        return fragment;
    }

    /// Every node of `root`'s tree in tree order.
    fn treeOrder(self: Literal, root: Node) !std.ArrayListUnmanaged(Node) {
        var list: std.ArrayListUnmanaged(Node) = .empty;
        errdefer list.deinit(self.allocator);
        var node: ?Node = root;
        while (node) |n| {
            try list.append(self.allocator, n);
            if (firstChildOf(n)) |child| {
                node = child;
                continue;
            }
            var at = n;
            node = null;
            while (true) {
                if (nextOf(at)) |s| {
                    node = s;
                    break;
                }
                at = parentOf(at) orelse break;
            }
        }
        return list;
    }

    fn deleteContents(self: Literal, b: Bounds, range: Node) !void {
        if (b.start_node == b.end_node and b.start_offset == b.end_offset) return;
        if (b.start_node == b.end_node and isCharacterData(b.start_node)) {
            return self.replaceEmpty(b.start_node, b.start_offset, b.end_offset - b.start_offset);
        }
        var all = try self.treeOrder(rootOf(b.start_node));
        defer all.deinit(self.allocator);
        var remove: std.ArrayListUnmanaged(Node) = .empty;
        defer remove.deinit(self.allocator);
        for (all.items) |n| {
            if (!try self.contained(b, n)) continue;
            if (parentOf(n)) |p| {
                if (try self.contained(b, p)) continue;
            }
            try remove.append(self.allocator, n);
        }
        var new_node = b.start_node;
        var new_offset = b.start_offset;
        if (!isInclusiveAncestor(b.start_node, b.end_node)) {
            var reference = b.start_node;
            while (parentOf(reference)) |p| {
                if (isInclusiveAncestor(p, b.end_node)) break;
                reference = p;
            }
            new_node = parentOf(reference).?;
            new_offset = indexOf(reference) + 1;
        }
        try interfaces.Range.call_setStart(range, new_node, new_offset);
        try interfaces.Range.call_setEnd(range, new_node, new_offset);
        if (isCharacterData(b.start_node)) try self.replaceEmpty(b.start_node, b.start_offset, lengthOf(b.start_node) - b.start_offset);
        for (remove.items) |n| _ = try interfaces.Node.call_removeChild(parentOf(n).?, n);
        if (isCharacterData(b.end_node)) try self.replaceEmpty(b.end_node, 0, b.end_offset);
    }

    fn stringify(self: Literal, b: Bounds, out: *std.ArrayListUnmanaged(u8)) !void {
        const appendPiece = struct {
            fn run(gpa: std.mem.Allocator, list: *std.ArrayListUnmanaged(u8), node: Node, offset: u32, count: u32) !void {
                var data = try interfaces.CharacterData.call_substringData(node, offset, count);
                defer data.deinit(node.ctx.allocator);
                try list.appendSlice(gpa, data.asSlice());
            }
        }.run;
        if (b.start_node == b.end_node and isText(b.start_node)) {
            return appendPiece(self.allocator, out, b.start_node, b.start_offset, b.end_offset - b.start_offset);
        }
        if (isText(b.start_node)) try appendPiece(self.allocator, out, b.start_node, b.start_offset, lengthOf(b.start_node) - b.start_offset);
        var all = try self.treeOrder(rootOf(b.start_node));
        defer all.deinit(self.allocator);
        for (all.items) |n| {
            if (isText(n) and try self.contained(b, n)) try appendPiece(self.allocator, out, n, 0, lengthOf(n));
        }
        if (isText(b.end_node)) try appendPiece(self.allocator, out, b.end_node, 0, b.end_offset);
    }
};

// ---------------------------------------------------------------------------
// Random trees and their serialization
// ---------------------------------------------------------------------------

const names = [_][]const u8{ "div", "span", "p", "b" };
const words = [_][]const u8{ "", "a", "xy", "hello", "q r" };

fn randomTree(page: *Page, random: std.Random, parent: Node, depth: u32) !void {
    const children = random.uintLessThan(u32, if (depth == 0) 5 else 4);
    for (0..children) |_| {
        const pick = random.uintLessThan(u32, 10);
        const node = if (pick < 3)
            try interfaces.Document.call_createTextNode(page.document, str(words[random.uintLessThan(usize, words.len)]))
        else if (pick < 4)
            try interfaces.Document.call_createComment(page.document, str(words[random.uintLessThan(usize, words.len)]))
        else
            try interfaces.Document.call_createElement(page.document, str(names[random.uintLessThan(usize, names.len)]), .notPassed());
        _ = try interfaces.Node.call_appendChild(parent, node);
        if (pick >= 4 and depth < 4) try randomTree(page, random, node, depth + 1);
    }
}

fn serialize(allocator: std.mem.Allocator, node: Node, out: *std.ArrayListUnmanaged(u8)) !void {
    const t = nodeType(node);
    if (isCharacterData(node)) {
        var data = try interfaces.CharacterData.get_data(node);
        defer data.deinit(node.ctx.allocator);
        try out.appendSlice(allocator, if (t == interfaces.Node.get_COMMENT_NODE()) "<!--" else "\"");
        try out.appendSlice(allocator, data.asSlice());
        try out.appendSlice(allocator, if (t == interfaces.Node.get_COMMENT_NODE()) "-->" else "\"");
        return;
    }
    var name = try interfaces.Node.get_nodeName(node);
    defer name.deinit(node.ctx.allocator);
    try out.appendSlice(allocator, "<");
    try out.appendSlice(allocator, name.asSlice());
    try out.appendSlice(allocator, ">");
    var child = firstChildOf(node);
    while (child) |c| : (child = nextOf(c)) try serialize(allocator, c, out);
    try out.appendSlice(allocator, "</>");
}

fn expectSameTree(a: Node, b: Node) !void {
    var sa: std.ArrayListUnmanaged(u8) = .empty;
    defer sa.deinit(testing.allocator);
    var sb: std.ArrayListUnmanaged(u8) = .empty;
    defer sb.deinit(testing.allocator);
    try serialize(testing.allocator, a, &sa);
    try serialize(testing.allocator, b, &sb);
    try testing.expectEqualStrings(sb.items, sa.items);
}

/// Every boundary point of `root`'s inclusive descendants.
fn randomPoint(allocator: std.mem.Allocator, random: std.Random, root: Node) !struct { path: []u32, offset: u32 } {
    var lit: Literal = .{ .allocator = allocator, .document = root };
    var all = try lit.treeOrder(root);
    defer all.deinit(allocator);
    // treeOrder walks past `root` to its following nodes; keep its subtree.
    var inside: usize = 0;
    for (all.items) |n| {
        if (!isInclusiveAncestor(root, n)) break;
        inside += 1;
    }
    const node = all.items[random.uintLessThan(usize, inside)];
    return .{ .path = try pathOf(allocator, node, root), .offset = random.uintAtMost(u32, lengthOf(node)) };
}

const Op = enum { extract, clone, delete, stringify };

fn compareOne(page: *Page, random: std.Random, template: Node, op: Op) !void {
    const allocator = testing.allocator;
    const a = try interfaces.Node.call_cloneNode(template, webidl.Opt(bool).passed(true));
    _ = try interfaces.Node.call_appendChild(page.body, a);
    const b = try interfaces.Node.call_cloneNode(template, webidl.Opt(bool).passed(true));
    _ = try interfaces.Node.call_appendChild(page.body, b);
    defer for ([_]Node{ a, b }) |copy| {
        if (parentOf(copy)) |p| _ = interfaces.Node.call_removeChild(p, copy) catch {};
        dom.node_creation.destroyUninserted(copy);
    };

    // Two points, ordered.
    const p1 = try randomPoint(allocator, random, a);
    defer allocator.free(p1.path);
    const p2 = try randomPoint(allocator, random, a);
    defer allocator.free(p2.path);
    var first = p1;
    var second = p2;
    if (try position(allocator, try nodeAt(a, p1.path), p1.offset, try nodeAt(a, p2.path), p2.offset) == .after) {
        first = p2;
        second = p1;
    }
    const ra = try interfaces.Document.call_createRange(page.document);
    defer interfaces.Range.deinit(ra);
    try interfaces.Range.call_setStart(ra, try nodeAt(a, first.path), first.offset);
    try interfaces.Range.call_setEnd(ra, try nodeAt(a, second.path), second.offset);
    const rb = try interfaces.Document.call_createRange(page.document);
    defer interfaces.Range.deinit(rb);
    const bb: Bounds = .{ .start_node = try nodeAt(b, first.path), .start_offset = first.offset, .end_node = try nodeAt(b, second.path), .end_offset = second.offset };
    try interfaces.Range.call_setStart(rb, bb.start_node, bb.start_offset);
    try interfaces.Range.call_setEnd(rb, bb.end_node, bb.end_offset);
    const literal: Literal = .{ .allocator = allocator, .document = page.document };

    switch (op) {
        .extract, .clone => {
            const fa = if (op == .extract) try interfaces.Range.call_extractContents(ra) else try interfaces.Range.call_cloneContents(ra);
            defer dom.node_creation.destroyUninserted(fa);
            const fb = try literal.contents(bb, op == .clone, if (op == .extract) rb else null);
            defer dom.node_creation.destroyUninserted(fb);
            try expectSameTree(fa, fb);
        },
        .delete => {
            try interfaces.Range.call_deleteContents(ra);
            try literal.deleteContents(bb, rb);
        },
        .stringify => {
            const sa = try interfaces.Range.serialize(ra);
            defer ra.ctx.allocator.free(sa);
            var sb: std.ArrayListUnmanaged(u8) = .empty;
            defer sb.deinit(allocator);
            try literal.stringify(bb, &sb);
            try testing.expectEqualStrings(sb.items, sa);
        },
    }
    try expectSameTree(a, b);
    // The ranges agree, as paths from their copies.
    const sa_node = try interfaces.AbstractRange.get_startContainer(ra);
    const sb_node = try interfaces.AbstractRange.get_startContainer(rb);
    const pa = try pathOf(allocator, sa_node, a);
    defer allocator.free(pa);
    const pb = try pathOf(allocator, sb_node, b);
    defer allocator.free(pb);
    try testing.expectEqualSlices(u32, pb, pa);
    try testing.expectEqual(try interfaces.AbstractRange.get_startOffset(rb), try interfaces.AbstractRange.get_startOffset(ra));
    try testing.expectEqual(try interfaces.AbstractRange.get_endOffset(rb), try interfaces.AbstractRange.get_endOffset(ra));
}

test "extract, clone the contents, deleteContents and the stringifier agree with DOM 5.5's steps on 600 random ranges" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    var prng = std.Random.DefaultPrng.init(0x3c4a_11b3);
    const random = prng.random();
    for (0..150) |_| {
        const template = try interfaces.Document.call_createElement(page.document, str("div"), .notPassed());
        defer dom.node_creation.destroyUninserted(template);
        try randomTree(&page, random, template, 0);
        for ([_]Op{ .extract, .clone, .delete, .stringify }) |op| try compareOne(&page, random, template, op);
    }
}
