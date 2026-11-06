//! The browser's own reload of a page - its reload button, the console's
//! `.reload` (Browser.reloadTraversable) - is HTML "reload" with user
//! involvement "browser UI": step 1, firing the navigation API's navigate
//! event, is skipped ("If userInvolvement is not 'browser UI'"), so the page
//! cannot intercept or cancel the user's reload. location.reload() is the
//! page's own, with user involvement "none", and the page hears it (lane
//! loadpath1: the console reloaded through the script's path).
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const Site = @import("site.zig").Site;

const TitleGoal = struct {
    browser: *Browser,
    prefix: []const u8,
    seen: ?[]u8 = null,

    fn met(context: *anyopaque) bool {
        const self: *TitleGoal = @ptrCast(@alignCast(context));
        const ctx = self.browser.current_context orelse return false;
        const title = ctx.evaluateScriptToString("document.title", testing.allocator) catch return false;
        if (std.mem.startsWith(u8, title, self.prefix)) {
            self.seen = title;
            return true;
        }
        testing.allocator.free(title);
        return false;
    }
};

/// Run the loop until the page's title starts with `prefix`, and expect it to
/// be `expected`.
fn expectTitle(browser: *Browser, prefix: []const u8, expected: []const u8) !void {
    var goal: TitleGoal = .{ .browser = browser, .prefix = prefix };
    const outcome = try browser.spinEventLoopUntil(.{ .context = &goal, .met = TitleGoal.met }, 15_000);
    defer if (goal.seen) |title| testing.allocator.free(title);
    try testing.expectEqual(Browser.SpinOutcome.met, outcome);
    try testing.expectEqualStrings(expected, goal.seen.?);
}

test "the browser's reload fires no navigate event at the page; location.reload() does" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    const url = try site.url(testing.allocator, "/reload.html");
    defer testing.allocator.free(url);

    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateInPlace(url);
    try expectTitle(browser, "loads 1", "loads 1 navigates []");

    // The browser's reload: HTML "reload" given userInvolvement "browser
    // UI" skips step 1 - no navigate event.
    try browser.reloadTraversable(browser.hostTraversableId() orelse return error.NoTraversable);
    try expectTitle(browser, "loads 2", "loads 2 navigates []");

    // The page's own: userInvolvement "none", step 1 fires navigate with
    // navigationType "reload" before the reload goes on.
    try browser.current_context.?.runScript("location.reload();");
    try expectTitle(browser, "loads 3", "loads 3 navigates [reload,]");
}
