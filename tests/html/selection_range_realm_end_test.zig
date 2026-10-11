//! A Selection whose Range was made in a frame's realm (review of Codex row
//! 17, S1): `new frame.contentWindow.Range()`, moved into the top document by
//! setStart, added to the top selection, and the frame removed.
//!
//! Two measurements, then the net:
//! - While the page lives, the Range is KEPT: the selection's traced edge
//!   keeps its wrapper, and the wrapper keeps the frame's realm from being
//!   collected (a removed frame's realm is only detached, and ends when the
//!   collector takes it or with its page).
//! - When the frame's realm does end before the selection - here by ending
//!   the detached realm now, as its page's end does - its wrapper cache frees
//!   the Range (it is not a node and no other realm wraps it), and the slab
//!   reissues its slot.
//! - The selection then reads its range as gone, by its slab generation: an
//!   empty selection, never the freed Range. A teardown net, not the
//!   behaviour; run under std.testing.allocator.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;

const Selection = interfaces.Selection;

fn expectSelectionEmpty(selection: *runtime.Instance, text: *runtime.Instance) !void {
    try testing.expectEqual(@as(u32, 0), try Selection.get_rangeCount(selection));
    try testing.expect((try Selection.get_anchorNode(selection)) == null);
    try testing.expect((try Selection.get_focusNode(selection)) == null);
    try testing.expectEqual(@as(u32, 0), try Selection.get_anchorOffset(selection));
    try testing.expectEqual(@as(u32, 0), try Selection.get_focusOffset(selection));
    try testing.expect(try Selection.get_isCollapsed(selection));
    try testing.expectEqualStrings("None", (try Selection.get_type(selection)).asSlice());
    try testing.expectEqualStrings("none", (try Selection.get_direction(selection)).asSlice());
    try testing.expectError(error.IndexSizeError, Selection.call_getRangeAt(selection, 0));
    try testing.expect(!try Selection.call_containsNode(selection, text, .passed(true)));
    try testing.expectError(error.InvalidStateError, Selection.call_collapseToStart(selection));
    try testing.expectError(error.InvalidStateError, Selection.call_extend(selection, text, .passed(1)));
    const serialized = try Selection.serialize(selection);
    try testing.expectEqual(@as(usize, 0), serialized.len);
    // Nothing to delete: the text is untouched.
    try Selection.call_deleteFromDocument(selection);
    var data = try interfaces.CharacterData.get_data(text);
    defer data.deinit(text.ctx.allocator);
    try testing.expectEqualStrings("top text", data.asSlice());
}

fn frameRangeOutlivedByItsSelection() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><p id=t>top text</p><iframe id=f></iframe></body>", .{ .base_url = "http://example.test/selection" });
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\(() => {
        \\  const frame = document.getElementById('f');
        \\  const text = document.getElementById('t').firstChild;
        \\  const range = new frame.contentWindow.Range();
        \\  range.setStart(text, 1);
        \\  range.setEnd(text, 4);
        \\  getSelection().removeAllRanges();
        \\  getSelection().addRange(range);
        \\  if (getSelection().rangeCount !== 1) throw new Error('not added');
        \\  frame.remove();
        \\})();
    );
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript("TestUtils.gc(); TestUtils.gc();");
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript("TestUtils.gc(); TestUtils.gc();");

    const document = page.document_instance orelse return error.NoDocument;
    const selection = (try interfaces.Document.call_getSelection(document)) orelse return error.NoSelection;
    const text = (try interfaces.Node.get_firstChild((try interfaces.Document.call_getElementById(document, .initInterned("t"))) orelse return error.NoElement)) orelse return error.NoText;

    // Measurement 1: the removed frame's Range is kept while the selection
    // holds it.
    try testing.expectEqual(@as(u32, 1), try Selection.get_rangeCount(selection));
    const range = try Selection.call_getRangeAt(selection, 0);
    const generation = runtime.SlabAllocator.generationOf(range);
    try testing.expect((try Selection.get_anchorNode(selection)) == text);
    try testing.expectEqual(@as(u32, 1), try Selection.get_anchorOffset(selection));
    try testing.expectEqual(@as(u32, 4), try Selection.get_focusOffset(selection));
    const frame_realm = range.ctx;
    try testing.expect(frame_realm != document.ctx);
    try testing.expect(frame_realm.hasEngine());

    // Measurement 2: the frame's realm ends while the page lives - a removed
    // frame's realm is detached, so this ends it now - and frees the Range.
    engine.destroyWindowRealm(frame_realm, .navigable_destroyed);
    try testing.expect(runtime.SlabAllocator.generationOf(range) != generation);

    // The net: the selection reads as empty, never the freed Range.
    try expectSelectionEmpty(selection, text);

    // And it takes a new range afterwards.
    try page.runScript(
        \\getSelection().collapse(document.getElementById('t').firstChild, 2);
        \\if (getSelection().rangeCount !== 1) throw new Error('no range after the dead one');
        \\if (getSelection().anchorOffset !== 2) throw new Error('anchorOffset ' + getSelection().anchorOffset);
        \\getSelection().removeAllRanges();
    );
    try testing.expectEqual(@as(u32, 0), try Selection.get_rangeCount(selection));
}

test "a selection whose Range's realm ended reads as empty, never the freed Range" {
    try onFreshThread(frameRangeOutlivedByItsSelection);
}
