//! N1 for elements (lane cg1 batch 1; node-memory plan v2): an element's
//! family-wide [SameObject] caches leave its generated State for its sparse
//! rare block (dom.node_rare_data, lane rare1), through
//! dom.same_object_cache's element accessors.
//!
//! A div's State carried 7 pointers for them - Element's classList,
//! attributes, part and children, HTMLElement's style, attributeStyleMap and
//! dataset: 56 bytes, null on nearly every element (framework-pages.md table
//! E: only style is read on the framework pages, and classList in the grid).
//! attributes and style were cached twice: the impls keep the NamedNodeMap
//! and the inline style object in rare data already. Blink keeps all of them
//! in its ElementRareDataVector (kClassList, kAttributeMap, kPart, kDataset,
//! kCssomWrapper, kCssomMapWrapper).
//!
//! RED at 01edfb83b0a: the States still hold the caches, and nothing reads
//! or writes the rare data for them.
//!
//! What the States hold is pinned here, at comptime. The seven tests that
//! read the caches' objects at run time are in
//! tests/html/cg1_element_same_object_test.zig since lane lk1: such an
//! object is its wrapper's to free, and this directory's realm has no engine
//! (they ran over an arena here, or freed the objects by hand).
//!
//! These name only generated interfaces, their States and src/dom types
//! (AGENTS.md "The impls boundary").
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const rare_data = dom.node_rare_data;
/// Whether this build has N1's fields.
const n1 = @hasField(rare_data.Field, "dataset");

/// The names of `State`'s own-level fields that cache a [SameObject] child.
fn expectNoCaches(comptime State: type) !void {
    const Own = @FieldType(State, "own");
    var found = false;
    inline for (@typeInfo(Own).@"struct".field_names) |name| {
        if (comptime std.mem.startsWith(u8, name, "cached_")) {
            std.debug.print("{s} still caches {s} in its State\n", .{ @typeName(State), name });
            found = true;
        }
    }
    if (found) return error.CacheInState;
}

// ============================================================================
// The States (comptime)
// ============================================================================

test "Element's, HTMLElement's, SVGElement's and MathMLElement's States cache nothing: their own level is empty" {
    try expectNoCaches(interfaces.Element.State);
    try expectNoCaches(interfaces.HTMLElement.State);
    try expectNoCaches(interfaces.SVGElement.State);
    try expectNoCaches(interfaces.MathMLElement.State);
    // The level each pinned: 0 bytes of own fields for Element (32 at
    // 01edfb83b0a), HTMLElement (24), MathMLElement (24) and SVGElement (40
    // at 01edfb83b0a; 8, its impl's `_internal` pointer, until lane quick1
    // moved its nonce slot to the rare data's, 2026-11-12).
    inline for (.{ interfaces.Element.State, interfaces.HTMLElement.State, interfaces.MathMLElement.State, interfaces.SVGElement.State }) |State| {
        try testing.expectEqual(@as(usize, 0), @sizeOf(@FieldType(State, "own")));
    }
}

test "what stays in a State: a non-element's and a leaf element's own caches (Node's childNodes left it in lane nm2)" {
    try testing.expect(!@hasField(@FieldType(interfaces.Node.State, "own"), "cached_childNodes"));
    try testing.expectEqual(@as(usize, 0), @sizeOf(@FieldType(interfaces.Node.State, "own")));
    try testing.expect(@hasField(@FieldType(interfaces.Document.State, "own"), "cached_children"));
    try testing.expect(@hasField(@FieldType(interfaces.HTMLAnchorElement.State, "own"), "cached_relList"));
}

test "the rare fields: classList at bit 0 and style at bit 1, every cache a pointer slot" {
    if (comptime !n1) return error.NoN1Fields;
    try testing.expectEqual(@as(u5, 0), @backingInt(rare_data.Field.class_list));
    try testing.expectEqual(@as(u5, 1), @backingInt(rare_data.Field.style));
    inline for (.{ .class_list, .dataset, .children, .part, .attribute_style_map, .inline_style, .svg_class_name }) |field| {
        try testing.expect(rare_data.Value(field) == *runtime.Instance);
    }
}
