//! Lane refcount8 (H-RC8-XML-MOVEHOLD): a hole the zombie audit's
//! resurrection reports found after refcount step 7's prerequisites (b)/(b2).
//! The XML parser's error message block moved the svg root with removeChild
//! then appendChild, leaving it garbage between the two calls
//! (crane/xp-domparser-error-document.html, 1 report): it holds the svg across.
//! Since refcount step 7 (lane refcount9) the counts decide, and a garbage
//! tree held again before its slice is the switch's resurrection.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const dom = h.dom;

fn xmlErrorBlockHoldsTheSvgItMoves() !void {
    const page = try h.Page.open();
    defer page.close();
    const books = dom.refcount_teardown.booksOf(try page.node("document")) orelse return error.NoAgent;
    const before = books.resurrections;
    try page.run(
        \\globalThis.parsed = new DOMParser().parseFromString('<svg xmlns="http://www.w3.org/2000/svg"><g></svg>', 'image/svg+xml');
        \\if (!parsed.querySelector('parsererror')) throw new Error('no error block');
        \\0;
    );
    _ = try page.browser.runEventLoopBlocking(20);
    if (books.resurrections != before) std.debug.print("resurrections {d} -> {d}\n", .{ before, books.resurrections });
    try testing.expectEqual(before, books.resurrections);
}

test "the XML parser's error message block holds the svg root it moves" {
    try h.onFreshThread(xmlErrorBlockHoldsTheSvgItMoves);
}
