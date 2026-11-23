//! DOM.setOuterHTML's patch (lane cdpd1, batch 3): the new markup is parsed
//! and diffed against the old nodes, and only what differs is changed -
//! nodes that are the same (by a digest of their subtree) stay, so their
//! node ids and state survive the edit - through the agent's editor, whose
//! history can undo the whole patch.
//!
//! Translated from Chromium's DOMPatchSupport - upstream repository
//! https://chromium.googlesource.com/chromium/src, file
//! third_party/blink/renderer/core/inspector/dom_patch_support.cc, revision
//! tag 157.0.8103.78 (commit 4b3d0dabb8250b6f152d2d85d79e7706e309d087):
//! PatchDocument, PatchNode, InnerPatchNode, Diff, InnerPatchChildren,
//! CreateDigest, InsertBeforeAndMarkAsUsed, RemoveChildAndMoveToNew,
//! MarkNodeAsUsed.
//!     Copyright (C) 2012 Google Inc. All rights reserved.
//!     License: BSD-3-Clause, as the file's header states ("Redistribution
//!     and use in source and binary forms, with or without modification,
//!     are permitted provided that ..."); the full text is
//!     THIRD_PARTY_NOTICES.md, text B.
//! One stated difference: Blink walks its `merges` map in its hash table's
//! order (keys are Digest pointers), so with several merges its edits come
//! in an order no client can rely on; here they come in the order the
//! merges were found.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const dom_editor = @import("dom_editor.zig");
const Editor = dom_editor.Editor;
const Error = dom_editor.Error;

/// A node's digest (DOMPatchSupport::Digest): its SHA-256 over its type,
/// name, value, children's digests and attributes, as Blink prints it (the
/// first 10 bytes in Base64).
const Digest = struct {
    node: *runtime.Instance,
    sha: [16]u8,
    attrs_sha: ?[16]u8 = null,
    children: []*Digest = &.{},
};

const Sha = [16]u8;

/// The patch is done with `root`, the tree it parsed (a fragment, or the
/// new document), never wrapped. Its nodes may live on in the history: a
/// node the patch moved into the page is recorded with the parent it left
/// (InsertBeforeAction's RemoveChildAction), which undo puts it back into -
/// Blink's actions keep those nodes as Members, so the parsed tree lives as
/// long as an action names a node of it. So only an emptied root goes now;
/// one that kept children loses its creator's reference alone, and the
/// counts free its tree once no action holds a node of it (the rule of
/// dom.mutation.dropConvertedNode: refcount step 7, counts decide).
fn dropParsed(root: *runtime.Instance, generation: u64) void {
    if (runtime.SlabAllocator.generationOf(root) != generation) return;
    const base = dom.instance_bridge.getNodeBase(root) orelse return;
    if (base.firstChild() == null and base.parent_node == null) return dom.node_creation.releaseIfUnwrapped(root, generation);
    dom.refcount.releaseCreatorReference(base);
}

/// The patch's state (a DOMPatchSupport).
pub const Patch = struct {
    arena: Allocator,
    editor: *Editor,
    document: *runtime.Instance,
    /// unused_nodes_map_: the new tree's digests not used yet, by digest -
    /// the first made for a digest kept (WTF HashMap::insert).
    // tombstones: short-lived - one Patch lives for one patchNode call, its table in that call's arena
    unused: std.AutoHashMapUnmanaged(Sha, *Digest) = .empty,

    /// PatchNode: `node` replaced by `markup` parsed in its parent's
    /// context, by the least edits; the node now at its place (null: the
    /// document was patched, or nothing took its place).
    pub fn patchNode(self: *Patch, node: *runtime.Instance, markup: []const u8) Error!?*runtime.Instance {
        // "Don't parse <html> as a fragment."
        const parent = (interfaces.Node.get_parentNode(node) catch null);
        const is_document = (interfaces.Node.get_nodeType(node) catch 0) == 9;
        if (is_document or (parent != null and (interfaces.Node.get_nodeType(parent.?) catch 0) == 9)) {
            try self.patchDocument(markup);
            return null;
        }
        const parent_node = parent orelse return null;
        const previous = interfaces.Node.get_previousSibling(node) catch null;
        // ParentElementOrShadowRoot, else the document element; a shadow
        // root's children parse in the body's context.
        var target: ?*runtime.Instance = parent_node;
        const parent_type = interfaces.Node.get_nodeType(parent_node) catch 0;
        if (parent_type != 1 and !parent_node.implements(interfaces.ShadowRoot.State)) target = interfaces.Document.get_documentElement(self.document) catch null;
        if (target) |t| if (t.implements(interfaces.ShadowRoot.State)) {
            target = interfaces.Document.get_body(self.document) catch null;
        };
        const fragment = try self.parseFragment(markup, target);
        const fragment_generation = runtime.SlabAllocator.generationOf(fragment);
        defer dropParsed(fragment, fragment_generation);

        // Compose the old list.
        var old_list: std.ArrayListUnmanaged(*Digest) = .empty;
        var child = interfaces.Node.get_firstChild(parent_node) catch null;
        while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) try old_list.append(self.arena, try self.createDigest(c, false));

        // Compose the new list.
        const lowered = try std.ascii.allocLowerString(self.arena, markup);
        var new_list: std.ArrayListUnmanaged(*Digest) = .empty;
        child = interfaces.Node.get_firstChild(parent_node) catch null;
        while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
            if (c == node) break;
            try new_list.append(self.arena, try self.createDigest(c, false));
        }
        child = interfaces.Node.get_firstChild(fragment) catch null;
        while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
            const has_children = (interfaces.Node.get_firstChild(c) catch null) != null;
            // "HTML5 parser inserts empty <head> tag whenever it parses
            // <body>", and an empty <body> whenever it parses </head>.
            if (isHtml(c, "head") and !has_children and std.mem.indexOf(u8, lowered, "</head>") == null) continue;
            if (isHtml(c, "body") and !has_children and std.mem.indexOf(u8, lowered, "</body>") == null) continue;
            try new_list.append(self.arena, try self.createDigest(c, true));
        }
        child = interfaces.Node.get_nextSibling(node) catch null;
        while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) try new_list.append(self.arena, try self.createDigest(c, false));

        self.innerPatchChildren(parent_node, old_list.items, new_list.items) catch |err| switch (err) {
            error.OutOfMemory => return err,
            // "Fall back to total replace."
            error.DomException => try self.editor.replaceChild(parent_node, fragment, node),
        };
        if (previous) |p| return interfaces.Node.get_nextSibling(p) catch null;
        return interfaces.Node.get_firstChild(parent_node) catch null;
    }

    /// PatchDocument: a new document of the same kind parsed from `markup`,
    /// its document element diffed against the old; with no way to patch,
    /// the document is written anew (document.write, then close). A
    /// non-HTML document whose markup is not well-formed is left alone.
    pub fn patchDocument(self: *Patch, markup: []const u8) Error!void {
        const html = @import("html");
        const is_html = @import("dom").document_internals.getDocumentType(self.document) != .xml;
        const new_document = if (is_html)
            html.dom_parser.parseHTML(self.document.ctx.allocator, self.document.ctx, markup, .{}) catch return error.OutOfMemory
        else blk: {
            const document = interfaces.XMLDocument.initWith(self.document.ctx.allocator, self.document.ctx, .{ .ready_state = ._complete_ }) catch return error.OutOfMemory;
            // "Avoid breakage on non-well-formed documents."
            const failure = html.xml_document_parser.parseInto(document, markup, .{ .scripting = false }) catch {
                dom.node_creation.destroyUninserted(document);
                return;
            };
            if (failure != null) {
                dom.node_creation.destroyUninserted(document);
                return;
            }
            break :blk document;
        };
        const generation = runtime.SlabAllocator.generationOf(new_document);
        defer dropParsed(new_document, generation);
        const old_root = (interfaces.Document.get_documentElement(self.document) catch null) orelse return self.rewrite(markup);
        const new_root = (interfaces.Document.get_documentElement(new_document) catch null) orelse return self.rewrite(markup);
        const old_info = try self.createDigest(old_root, false);
        const new_info = try self.createDigest(new_root, true);
        self.innerPatchNode(old_info, new_info) catch |err| switch (err) {
            error.OutOfMemory => return err,
            error.DomException => return self.rewrite(markup),
        };
    }

    /// The fallback: GetDocument().write(markup); close().
    fn rewrite(self: *Patch, markup: []const u8) Error!void {
        var text = runtime.DOMString.initDupe(self.arena, markup) catch return error.OutOfMemory;
        defer text.deinit(self.arena);
        interfaces.Document.call_write(self.document, &.{.{ .domstring = text }}) catch {};
        interfaces.Document.call_close(self.document) catch {};
    }

    /// The markup as a fragment in `context`'s (Blink's ParseHTML /
    /// ParseXML into a DocumentFragment of the document).
    fn parseFragment(self: *Patch, markup: []const u8, context: ?*runtime.Instance) Error!*runtime.Instance {
        const html = @import("html");
        return html.dom_parser.parseFragmentIn(self.document.ctx.allocator, self.document.ctx, markup, context, .inert) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => self.editor.fail(err, .replace_child),
        };
    }

    /// InnerPatchNode.
    fn innerPatchNode(self: *Patch, old: *Digest, new: *Digest) Error!void {
        if (std.mem.eql(u8, &old.sha, &new.sha)) return;
        const old_node = old.node;
        const new_node = new.node;
        if (!sameTypeAndName(old_node, new_node)) {
            const parent = (interfaces.Node.get_parentNode(old_node) catch null) orelse return;
            return self.editor.replaceChild(parent, new_node, old_node);
        }
        const old_value = try valueOf(self.arena, old_node);
        const new_value = try valueOf(self.arena, new_node);
        if (!optionalEql(old_value, new_value)) try self.editor.setNodeValue(old_node, new_value orelse "");
        if ((interfaces.Node.get_nodeType(old_node) catch 0) != 1) return;
        // Patch attributes.
        if (!optionalShaEql(old.attrs_sha, new.attrs_sha)) {
            while (dom.element_attributes.count(old_node) != 0) {
                const attribute = dom.element_attributes.at(old_node, 0) orelse break;
                try self.editor.removeAttribute(old_node, try qualified(self.arena, attribute));
            }
            const count = dom.element_attributes.count(new_node);
            for (0..count) |i| {
                const attribute = dom.element_attributes.at(new_node, i) orelse continue;
                try self.editor.setAttribute(old_node, try qualified(self.arena, attribute), try self.arena.dupe(u8, attribute.value));
            }
        }
        defer _ = self.unused.remove(new.sha);
        try self.innerPatchChildren(old_node, old.children, new.children);
    }

    const Pair = struct { digest: ?*Digest = null, index: usize = 0 };

    /// Diff: the old and new lists' matches, by digest.
    fn diff(self: *Patch, old_list: []*Digest, new_list: []*Digest) Allocator.Error!struct { old: []Pair, new: []Pair } {
        const old_map = try self.arena.alloc(Pair, old_list.len);
        const new_map = try self.arena.alloc(Pair, new_list.len);
        @memset(old_map, .{});
        @memset(new_map, .{});
        // Trim head and tail.
        var i: usize = 0;
        while (i < old_list.len and i < new_list.len and std.mem.eql(u8, &old_list[i].sha, &new_list[i].sha)) : (i += 1) {
            old_map[i] = .{ .digest = old_list[i], .index = i };
            new_map[i] = .{ .digest = new_list[i], .index = i };
        }
        i = 0;
        while (i < old_list.len and i < new_list.len and std.mem.eql(u8, &old_list[old_list.len - i - 1].sha, &new_list[new_list.len - i - 1].sha)) : (i += 1) {
            const old_index = old_list.len - i - 1;
            const new_index = new_list.len - i - 1;
            old_map[old_index] = .{ .digest = old_list[old_index], .index = new_index };
            new_map[new_index] = .{ .digest = new_list[new_index], .index = old_index };
        }
        // Digests that occur once on each side.
        var new_table: std.AutoArrayHashMapUnmanaged(Sha, std.ArrayListUnmanaged(usize)) = .empty;
        var old_table: std.AutoArrayHashMapUnmanaged(Sha, std.ArrayListUnmanaged(usize)) = .empty;
        for (new_list, 0..) |d, n| {
            const got = try new_table.getOrPut(self.arena, d.sha);
            if (!got.found_existing) got.value_ptr.* = .empty;
            try got.value_ptr.append(self.arena, n);
        }
        for (old_list, 0..) |d, n| {
            const got = try old_table.getOrPut(self.arena, d.sha);
            if (!got.found_existing) got.value_ptr.* = .empty;
            try got.value_ptr.append(self.arena, n);
        }
        for (new_table.keys(), new_table.values()) |sha, new_indices| {
            if (new_indices.items.len != 1) continue;
            const old_indices = old_table.get(sha) orelse continue;
            if (old_indices.items.len != 1) continue;
            new_map[new_indices.items[0]] = .{ .digest = new_list[new_indices.items[0]], .index = old_indices.items[0] };
            old_map[old_indices.items[0]] = .{ .digest = old_list[old_indices.items[0]], .index = new_indices.items[0] };
        }
        // Extend the matches forward, then backward.
        if (new_list.len > 0) {
            i = 0;
            while (i < new_list.len - 1) : (i += 1) {
                if (new_map[i].digest == null or new_map[i + 1].digest != null) continue;
                const j = new_map[i].index + 1;
                if (j < old_map.len and old_map[j].digest == null and std.mem.eql(u8, &new_list[i + 1].sha, &old_list[j].sha)) {
                    new_map[i + 1] = .{ .digest = new_list[i + 1], .index = j };
                    old_map[j] = .{ .digest = old_list[j], .index = i + 1 };
                }
            }
            i = new_list.len - 1;
            while (i > 0) : (i -= 1) {
                if (new_map[i].digest == null or new_map[i - 1].digest != null or new_map[i].index == 0) continue;
                const j = new_map[i].index - 1;
                if (old_map[j].digest == null and std.mem.eql(u8, &new_list[i - 1].sha, &old_list[j].sha)) {
                    new_map[i - 1] = .{ .digest = new_list[i - 1], .index = j };
                    old_map[j] = .{ .digest = old_list[j], .index = i - 1 };
                }
            }
        }
        return .{ .old = old_map, .new = new_map };
    }

    /// InnerPatchChildren.
    fn innerPatchChildren(self: *Patch, parent: *runtime.Instance, old_list: []*Digest, new_list: []*Digest) Error!void {
        const maps = try self.diff(old_list, new_list);
        const old_map = maps.old;
        const new_map = maps.new;
        var old_head: ?*Digest = null;
        var old_body: ?*Digest = null;
        // 1. First strip everything except for the nodes that retain.
        // Collect pending merges (new digest -> old digest).
        var merges: std.AutoArrayHashMapUnmanaged(*Digest, *Digest) = .empty;
        var used_new: std.AutoHashMapUnmanaged(usize, void) = .empty;
        for (old_list, 0..) |old, i| {
            if (old_map[i].digest != null) {
                const got = try used_new.getOrPut(self.arena, old_map[i].index);
                if (!got.found_existing) continue;
                old_map[i] = .{};
            }
            // "Always match <head> and <body> tags with each other - we
            // can't remove them from the DOM upon patching."
            if (isHtml(old.node, "head")) {
                old_head = old;
                continue;
            }
            if (isHtml(old.node, "body")) {
                old_body = old;
                continue;
            }
            // "Check if this change is between stable nodes. If it is,
            // consider it as "modified"."
            if (!self.unused.contains(old.sha) and (i == 0 or old_map[i - 1].digest != null) and (i == old_map.len - 1 or old_map[i + 1].digest != null)) {
                const anchor_candidate = if (i != 0) old_map[i - 1].index + 1 else 0;
                const anchor_after = if (i == old_map.len - 1) anchor_candidate + 1 else old_map[i + 1].index;
                if (anchor_after -% anchor_candidate == 1 and anchor_candidate < new_list.len) {
                    try merges.put(self.arena, new_list[anchor_candidate], old);
                } else try self.removeChildAndMoveToNew(old);
            } else try self.removeChildAndMoveToNew(old);
        }
        // Mark retained nodes as used; no node is reused twice.
        var used_old: std.AutoHashMapUnmanaged(usize, void) = .empty;
        for (new_map) |*pair| {
            const digest = pair.digest orelse continue;
            const got = try used_old.getOrPut(self.arena, pair.index);
            if (got.found_existing) {
                pair.* = .{};
                continue;
            }
            self.markNodeAsUsed(digest);
        }
        // Mark <head> and <body> nodes for merge.
        if (old_head != null or old_body != null) {
            for (new_list) |new| {
                if (old_head) |head| if (isHtml(new.node, "head")) try merges.put(self.arena, new, head);
                if (old_body) |body| if (isHtml(new.node, "body")) try merges.put(self.arena, new, body);
            }
        }
        // 2. Patch nodes marked for merge.
        for (merges.keys(), merges.values()) |new, old| try self.innerPatchNode(old, new);
        // 3. Insert missing nodes.
        for (new_map, 0..) |pair, i| {
            if (pair.digest != null or merges.contains(new_list[i])) continue;
            try self.insertBeforeAndMarkAsUsed(parent, new_list[i], childAt(parent, i));
        }
        // 4. Then put all nodes that retained into their slots (sort by new
        // index).
        for (old_map) |pair| {
            const digest = pair.digest orelse continue;
            const node = digest.node;
            const anchor = childAt(parent, pair.index);
            if (anchor == node) continue;
            // "Never move head or body, move the rest of the nodes around
            // them."
            if (isHtml(node, "body") or isHtml(node, "head")) continue;
            try self.editor.insertBefore(parent, node, anchor);
        }
    }

    /// CreateDigest; with `unused` the digest (and every one under it) joins
    /// unused_nodes_map_.
    fn createDigest(self: *Patch, node: *runtime.Instance, unused: bool) Error!*Digest {
        const digest = try self.arena.create(Digest);
        digest.* = .{ .node = node, .sha = undefined };
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        const node_type: u32 = interfaces.Node.get_nodeType(node) catch 0;
        hasher.update(std.mem.asBytes(&node_type));
        var name = interfaces.Node.get_nodeName(node) catch runtime.DOMString.initEmpty();
        defer name.deinit(node.ctx.allocator);
        hasher.update(name.asSlice());
        if (try valueOf(self.arena, node)) |value| hasher.update(value);
        if (node_type == 1) {
            var children: std.ArrayListUnmanaged(*Digest) = .empty;
            var child = interfaces.Node.get_firstChild(node) catch null;
            while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
                const child_digest = try self.createDigest(c, unused);
                hasher.update(&child_digest.sha);
                try children.append(self.arena, child_digest);
            }
            digest.children = children.items;
            const count = dom.element_attributes.count(node);
            if (count != 0) {
                var attrs = std.crypto.hash.sha2.Sha256.init(.{});
                for (0..count) |i| {
                    const attribute = dom.element_attributes.at(node, i) orelse continue;
                    attrs.update(try qualified(self.arena, attribute));
                    attrs.update(attribute.value);
                }
                digest.attrs_sha = base64Of(&attrs);
                hasher.update(&digest.attrs_sha.?);
            }
        }
        digest.sha = base64Of(&hasher);
        if (unused) {
            const got = try self.unused.getOrPut(self.arena, digest.sha);
            if (!got.found_existing) got.value_ptr.* = digest;
        }
        return digest;
    }

    /// InsertBeforeAndMarkAsUsed.
    fn insertBeforeAndMarkAsUsed(self: *Patch, parent: *runtime.Instance, digest: *Digest, anchor: ?*runtime.Instance) Error!void {
        defer self.markNodeAsUsed(digest);
        try self.editor.insertBefore(parent, digest.node, anchor);
    }

    /// RemoveChildAndMoveToNew: the old node goes; if the new tree has a
    /// digest equal to it, the old node takes that one's place there ("in
    /// order not to lose the node identity when user prepends their HTML
    /// with "<div>""), else its children are tried the same way.
    fn removeChildAndMoveToNew(self: *Patch, old: *Digest) Error!void {
        const old_node = old.node;
        const parent = (interfaces.Node.get_parentNode(old_node) catch null) orelse return;
        try self.editor.removeChild(parent, old_node);
        if (self.unused.get(old.sha)) |new| {
            const new_node = new.node;
            const new_parent = (interfaces.Node.get_parentNode(new_node) catch null) orelse return;
            try self.editor.replaceChild(new_parent, old_node, new_node);
            new.node = old_node;
            self.markNodeAsUsed(new);
            return;
        }
        for (old.children) |child| try self.removeChildAndMoveToNew(child);
    }

    /// MarkNodeAsUsed: the digest and every one under it leave the unused
    /// map.
    fn markNodeAsUsed(self: *Patch, digest: *Digest) void {
        var queue: std.ArrayListUnmanaged(*Digest) = .empty;
        queue.append(self.arena, digest) catch return;
        var head: usize = 0;
        while (head < queue.items.len) : (head += 1) {
            const first = queue.items[head];
            _ = self.unused.remove(first.sha);
            for (first.children) |child| queue.append(self.arena, child) catch return;
        }
    }
};

/// Base64 of the first 10 bytes of the digest (Blink's
/// Base64Encode(base::span(digest_result).first<10>())).
fn base64Of(hasher: *std.crypto.hash.sha2.Sha256) [16]u8 {
    var full: [32]u8 = undefined;
    hasher.final(&full);
    var out: [16]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&out, full[0..10]);
    return out;
}

fn optionalShaEql(a: ?Sha, b: ?Sha) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return std.mem.eql(u8, &x, &y);
}

fn optionalEql(a: ?[]const u8, b: ?[]const u8) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return std.mem.eql(u8, x, y);
}

/// NodeTraversal::ChildAt.
fn childAt(parent: *runtime.Instance, index: usize) ?*runtime.Instance {
    var child = interfaces.Node.get_firstChild(parent) catch null;
    var i: usize = 0;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
        if (i == index) return c;
        i += 1;
    }
    return null;
}

fn sameTypeAndName(a: *runtime.Instance, b: *runtime.Instance) bool {
    if ((interfaces.Node.get_nodeType(a) catch 0) != (interfaces.Node.get_nodeType(b) catch 0)) return false;
    var a_name = interfaces.Node.get_nodeName(a) catch return false;
    defer a_name.deinit(a.ctx.allocator);
    var b_name = interfaces.Node.get_nodeName(b) catch return false;
    defer b_name.deinit(b.ctx.allocator);
    return std.mem.eql(u8, a_name.asSlice(), b_name.asSlice());
}

/// Node.nodeValue, copied into `arena`; null for none.
fn valueOf(arena: Allocator, node: *runtime.Instance) Allocator.Error!?[]const u8 {
    var value = (interfaces.Node.get_nodeValue(node) catch return null) orelse return null;
    defer value.deinit(node.ctx.allocator);
    return try arena.dupe(u8, value.asSlice());
}

fn qualified(arena: Allocator, attribute: dom.element_attributes.Attribute) Allocator.Error![]const u8 {
    const prefix = attribute.prefix orelse return arena.dupe(u8, attribute.local_name);
    if (prefix.len == 0) return arena.dupe(u8, attribute.local_name);
    return std.mem.concat(arena, u8, &.{ prefix, ":", attribute.local_name });
}

/// An HTML element named `name` (Blink's IsA<HTMLHeadElement> and the like).
fn isHtml(node: *runtime.Instance, comptime name: []const u8) bool {
    if ((interfaces.Node.get_nodeType(node) catch 0) != 1) return false;
    var ns = (interfaces.Element.get_namespaceURI(node) catch null) orelse return false;
    defer ns.deinit(node.ctx.allocator);
    if (!std.mem.eql(u8, ns.asSlice(), "http://www.w3.org/1999/xhtml")) return false;
    var local = interfaces.Element.get_localName(node) catch return false;
    defer local.deinit(node.ctx.allocator);
    return std.mem.eql(u8, local.asSlice(), name);
}
