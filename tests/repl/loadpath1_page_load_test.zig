//! A Browser's page load over the network is HTML "navigate" of its
//! top-level traversable with user involvement "browser UI" - the one path a
//! browser has, which the console and the WPT runner both take now - and a
//! Window's origin is its associated Document's (lane loadpath1).
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const Site = @import("site.zig").Site;

fn evaluate(browser: *Browser, script: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(script, testing.allocator);
}

test "an embedder's load of a URL is a navigation request: mode navigate, destination document" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    const url = try site.url(testing.allocator, "/metadata.html");
    defer testing.allocator.free(url);

    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate(url, .window);

    // HTML "create navigation params by fetching" step 3: the request's mode
    // is "navigate" and, for a top-level traversable, its destination
    // "document" - Fetch Metadata sends both (Sec-Fetch-Mode,
    // Sec-Fetch-Dest), as Chrome, Firefox and Safari do for an address-bar
    // load.
    const sent = try evaluate(browser, "document.getElementById('metadata').textContent");
    defer testing.allocator.free(sent);
    try testing.expectEqualStrings("navigate|document", sent);
}

const TitleGoal = struct {
    browser: *Browser,
    seen: ?[]u8 = null,

    fn met(context: *anyopaque) bool {
        const self: *TitleGoal = @ptrCast(@alignCast(context));
        const title = evaluate(self.browser, "document.title") catch return false;
        if (std.mem.startsWith(u8, title, "popup: ")) {
            self.seen = title;
            return true;
        }
        testing.allocator.free(title);
        return false;
    }
};

fn expectPopupLoaded(browser: *Browser) !void {
    var goal: TitleGoal = .{ .browser = browser };
    const outcome = try browser.spinEventLoopUntil(.{ .context = &goal, .met = TitleGoal.met }, 15_000);
    defer if (goal.seen) |title| testing.allocator.free(title);
    try testing.expectEqual(Browser.SpinOutcome.met, outcome);
    try testing.expectEqualStrings("popup: Popup", goal.seen.?);
}

test "a page loaded by navigating its traversable opens a same-origin popup that loads in the Window open() returned" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    const url = try site.url(testing.allocator, "/opener.html");
    defer testing.allocator.free(url);

    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    // The address bar's navigation of the page the Browser shows (the
    // console's .open), whose commit gives the page a new Window.
    try browser.navigateInPlace(url);

    // HTML "create a new auxiliary browsing context and document" step 4
    // creates the popup with the opener's active document as its creator,
    // and "create a new browsing context and document" step 5.1 takes
    // creatorOrigin from that DOCUMENT's origin - the site's. The popup's
    // initial about:blank has it, so its first navigation, to the same
    // origin, keeps that document's Window ("create and initialize a
    // Document object" step 6) and the onload set right after open() fires.
    try expectPopupLoaded(browser);
}

test "a cross-origin frame's popup is of the frame's document's origin, and loads in the Window open() returned" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    const url = try site.url(testing.allocator, "/cross-origin-frame-opener.html");
    defer testing.allocator.free(url);

    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate(url, .window);

    // The frame's document is of localhost; the frame's Window was made for
    // its initial about:blank, whose origin was its container's
    // (127.0.0.1). The popup's creatorOrigin is the frame's DOCUMENT's
    // origin (step 5.1), so its initial about:blank is localhost's, and its
    // navigation to /popup.html on localhost keeps the Window open()
    // returned.
    try expectPopupLoaded(browser);
}
