//! A popup whose opener's navigable switches browsing context group has no
//! opener from then on (HTML "obtain a browsing context to use for a
//! navigation response" steps 10-14: the navigable's next document is in a
//! NEW browsing context; the popup's opener browsing context was the old
//! one, which is discarded). window.opener answers null, as in Chrome,
//! Firefox and Safari (html/cross-origin-opener-policy/
//! coop-popup-opener-navigates.https.html: 1/1 in each, wpt.fyi cc74d2669f).
//! The Window getter reads `disowned` before any opener it kept, so the
//! switch disowns the popup: `BrowsingContext.switchGroup`.

const std = @import("std");
const runtime = @import("runtime");
const html_core = @import("html_core");

const testing = std.testing;
const BrowsingContext = html_core.BrowsingContext;
const Navigables = html_core.Navigables;

test "a group switch disowns every popup its context opened, and none other" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const navigables = try scope.table(.navigables, Navigables);
    const opener = try BrowsingContext.initTopLevel(testing.allocator, navigables);
    defer opener.deinit();
    const popup = try BrowsingContext.initAuxiliary(testing.allocator, opener, true);
    defer popup.deinit();
    const other_top = try BrowsingContext.initTopLevel(testing.allocator, navigables);
    defer other_top.deinit();
    const other_popup = try BrowsingContext.initAuxiliary(testing.allocator, other_top, true);
    defer other_popup.deinit();
    try testing.expect(!popup.disowned);

    opener.switchGroup(.none, .empty);
    try testing.expect(popup.opener == null);
    try testing.expect(popup.disowned);
    // Another context's popup keeps its opener.
    try testing.expect(other_popup.opener == other_top);
    try testing.expect(!other_popup.disowned);
}
