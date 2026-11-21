//! Whether a document has ever had an element with a headingoffset or
//! headingreset attribute: HTML 4.3.11.1's computed heading offset walks a
//! heading's inclusive ancestors for those two attributes, and :heading asks
//! it of every heading it tests; while a document never had either, every
//! walk would add 0, so it is skipped (src/html/pseudo_classes.zig).
//!
//! A sticky bit in the Document's rare data (dom.document_rare_data): set by
//! every path that gives an element one of the two attributes - append
//! (setAttribute and its kin), the parser's token attributes, a clone's
//! copied list (src/webidl/impls/Element.zig) - and carried to a new
//! document by adoption (dom.mutation.adopt); never cleared, so a removal
//! needs no count. A document that never sets either makes no rare data for
//! it. Lane maj6 (main's design, 2026-11-21): the walk cost the heading rows
//! of the lane's cost pair up to 1.86x main's instructions.

const std = @import("std");
const runtime = @import("runtime");
const attribute_names = @import("attribute_names.zig");
const document_state = @import("document_state.zig");

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

/// `document` has an element with one of the two attributes now: its bit is
/// set (its rare data made, when it had none).
pub fn note(document: *runtime.Instance) error{OutOfMemory}!void {
    const state = document_state.Registry.get(document) orelse return;
    if (state.rareData()) |rare| if (rare.heading_offsets_seen) return;
    const rare = try state.ensureRareData(document);
    rare.heading_offsets_seen = true;
}

/// Whether `document` ever had an element with one of the two attributes.
/// A document with no state answers true: the walk then decides.
pub fn seen(document: *runtime.Instance) bool {
    const state = document_state.Registry.get(document) orelse return true;
    const rare = state.rareData() orelse return false;
    return rare.heading_offsets_seen;
}

/// DOM "adopt" step 3: nodes moved from `old` to `new` may have the
/// attributes; `new` has seen them if `old` had.
pub fn adopted(old: *runtime.Instance, new: *runtime.Instance) error{OutOfMemory}!void {
    if (old == new) return;
    const state = document_state.Registry.get(old) orelse return;
    const rare = state.rareData() orelse return;
    if (rare.heading_offsets_seen) try note(new);
}

test "headingoffset and headingreset are found by one compare, no other name" {
    try std.testing.expect(names(offset_id));
    try std.testing.expect(names(reset_id));
    try std.testing.expect(!names(attribute_names.comptimeLocalId("id")));
    try std.testing.expect(!names(attribute_names.comptimeLocalId("height")));
    try std.testing.expect(!names(attribute_names.comptimeLocalId("headers")));
    try std.testing.expect(adjacent);
}
