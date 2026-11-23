//! Whether a document has ever had an element with a headingoffset or
//! headingreset attribute: HTML 4.3.11.1's computed heading offset walks a
//! heading's inclusive ancestors for those two attributes, and :heading asks
//! it of every heading it tests; while a document never had either, every
//! walk would add 0, so it is skipped (src/html/pseudo_classes.zig).
//!
//! A sticky bit of the Document's own (NodeBase.DocumentBits, in its
//! NodeBase's `element` byte: read with a pointer load, no lookup of the
//! Document's state): set by every path that gives an element one of the two
//! attributes - append (setAttribute and its kin), the parser's token
//! attributes, a clone's copied list (src/webidl/impls/Element.zig) - and
//! carried to a new document by adoption (dom.mutation.adopt); never cleared,
//! so a removal needs no count. Lane maj6 (main's design, 2026-11-21; the
//! user's "fix first" moved it from the Document's rare data, whose lookup
//! cost a never-seen document 4.3% per :heading match).

const std = @import("std");
const attribute_names = @import("attribute_names.zig");
const NodeBase = @import("node_base.zig").NodeBase;

const NameId = attribute_names.NameId;

const offset_id = attribute_names.comptimeLocalId("headingoffset");
const reset_id = attribute_names.comptimeLocalId("headingreset");
/// The two are adjacent static names: one range compare finds either.
const adjacent = @backingInt(reset_id) == @backingInt(offset_id) + 1;

/// Whether `name` is headingoffset or headingreset in no namespace: one
/// compare of static ids, on the attribute write paths. A dynamic id is
/// never either: a name in no namespace with no prefix is always static
/// (dom.attribute_names), and the attributes are in no namespace.
pub inline fn names(name: NameId) bool {
    if (comptime adjacent) return @backingInt(name) -% @backingInt(offset_id) < 2;
    return name == offset_id or name == reset_id;
}

/// `document` (its NodeBase) has an element with one of the two attributes
/// now: its bit is set.
pub fn note(document: *NodeBase) void {
    if (document.node_type != NodeBase.DOCUMENT_NODE) return;
    document.documentBits().heading_offsets_seen = true;
}

/// Whether `document` (its NodeBase) ever had an element with one of the two
/// attributes. A node that is no Document answers true: the walk decides.
pub inline fn seen(document: *NodeBase) bool {
    if (document.node_type != NodeBase.DOCUMENT_NODE) return true;
    return document.documentBits().heading_offsets_seen;
}

/// DOM "adopt" step 3: nodes moved from `old` to `new` may have the
/// attributes; `new` has seen them if `old` had.
pub fn adopted(old: *NodeBase, new: *NodeBase) void {
    if (old == new) return;
    if (seen(old)) note(new);
}

test "headingoffset and headingreset are found by one compare, no other name" {
    try std.testing.expect(names(offset_id));
    try std.testing.expect(names(reset_id));
    try std.testing.expect(!names(attribute_names.comptimeLocalId("id")));
    try std.testing.expect(!names(attribute_names.comptimeLocalId("height")));
    try std.testing.expect(!names(attribute_names.comptimeLocalId("headers")));
    try std.testing.expect(adjacent);
}

test "a Document's bit lives in its NodeBase's element byte, sticky, carried by adoption" {
    var a: NodeBase = undefined;
    a.node_type = NodeBase.DOCUMENT_NODE;
    a.element = .{};
    var b: NodeBase = undefined;
    b.node_type = NodeBase.DOCUMENT_NODE;
    b.element = .{};
    try std.testing.expect(!seen(&a) and !seen(&b));
    adopted(&a, &b);
    try std.testing.expect(!seen(&b));
    note(&a);
    try std.testing.expect(seen(&a));
    adopted(&a, &b);
    try std.testing.expect(seen(&b));
    // The byte is the Document's own: no element flag reads as set.
    try std.testing.expectEqual(@as(u8, 1), @as(u8, @bitCast(a.element)));
}
