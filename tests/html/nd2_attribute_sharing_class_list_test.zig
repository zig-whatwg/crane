//! Attribute-block sharing (lane nd2 batch 4, plan-v2 A3), the writer that
//! goes through classList: of two parser-made elements that hold ONE
//! attribute block, the one whose classList adds a token copies the block,
//! and the other keeps it and its attributes. The other writers (setAttribute,
//! removeAttribute, toggleAttribute, an Attr's value, setAttributeNode) are
//! in tests/dom/nd2_attribute_sharing_test.zig, where this case was too.
//!
//! Lane mp1 moved it here: classList's DOMTokenList is its WRAPPER's to end
//! (native_read_page.zig), and tests/dom's realm has no engine, so there the
//! case ran over an arena that hid whatever it left. Here it has a page of a
//! real Browser on std.testing.allocator: the list is wrapped when the
//! getter makes it, kept by its element's edge, and freed by its wrapper -
//! no arena.
//!
//! One difference a real page makes: its realm has timers, so the document's
//! cache of shared blocks lives 10 s past the parse (dom.attribute_block_cache;
//! nd2_document_attribute_cache_test.zig) and holds the block too. The test
//! therefore reads the holder count before the write and expects the write
//! to take exactly one holder away - the writer - where the engine-less page
//! expected the one holder left.
//!
//! These name only generated interfaces and src/dom (AGENTS.md "The impls
//! boundary").
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const native_read_page = @import("native_read_page.zig");

const Page = native_read_page.Page;
const str = native_read_page.str;

/// The block `el`'s attributes are in, or null.
fn blockOf(el: *runtime.Instance) ?*const dom.element_data.AttributeList {
    return dom.element_data.of(el).?.data.attrs;
}

fn get(el: *runtime.Instance, name: []const u8) ?[]const u8 {
    return dom.element_data.of(el).?.findValue(null, name);
}

fn classListWriterCopies(page: Page) !void {
    // One parser run (the fragment parser) makes both spans.
    const div = try page.element("div");
    try interfaces.Element.set_innerHTML(div, .{ .domstring = str("<span class=\"k\" title=t></span><span class=\"k\" title=t></span>") });
    const el = (try interfaces.Element.get_firstElementChild(div)).?;
    const other = (try interfaces.Element.get_nextElementSibling(el)).?;
    const shared = blockOf(el).?;
    try testing.expect(blockOf(other).? == shared);
    const holders_before = shared.holders;
    try testing.expect(holders_before >= 2);

    try interfaces.DOMTokenList.call_add(try interfaces.Element.get_classList(el), &.{str("m")});

    // The other element keeps the block and its attributes.
    try testing.expect(blockOf(other).? == shared);
    try testing.expectEqualStrings("k", get(other, "class").?);
    try testing.expectEqualStrings("t", get(other, "title").?);
    try testing.expect(get(other, "lang") == null);
    // The writer let go of it, and nobody else did.
    try testing.expectEqual(holders_before - 1, shared.holders);
    // The writer has a list of its own, with the write in it.
    const mine = blockOf(el).?;
    try testing.expect(mine != shared and !mine.isShared());
    try testing.expectEqualStrings("k m", get(el, "class").?);
    try testing.expectEqualStrings("t", get(el, "title").?);
}

test "A3: classList.add on one of two sharing elements copies and leaves the other untouched" {
    try native_read_page.onPage(classListWriterCopies);
}
