//! A frame's navigation that replaces one still delaying its container
//! document's load event does not delay it: the container's load fires once
//! the replaced navigation has ended, without waiting for the new one's
//! response, as in Safari (lane loadpath1;
//! html/browsers/browsing-the-web/overlapping-navigations-and-traversals/
//! nav-cancelation-2.sub.html). Golden rule 2, mechanism by mechanism: the
//! three browsers differ (Chrome blocks the container's load on the new
//! navigation, as HTML navigate step 16 does; Firefox does not block but
//! fires the load synchronously at the cancel; Safari does not block and
//! fires it asynchronously), and the two majorities - not blocked, fired
//! asynchronously - are Safari's behaviour (integrator ruling, 2026-11-06).
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const Site = @import("site.zig").Site;

fn evaluate(browser: *Browser, script: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(script, testing.allocator);
}

const DoneGoal = struct {
    browser: *Browser,
    fn met(context: *anyopaque) bool {
        const self: *DoneGoal = @ptrCast(@alignCast(context));
        const answer = evaluate(self.browser, "String(globalThis.done === true)") catch return false;
        defer testing.allocator.free(answer);
        return std.mem.eql(u8, answer, "true");
    }
};

test "a frame's navigation that replaces one delaying its container's load does not delay it" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    const url = try site.url(testing.allocator, "/navc-page.html");
    defer testing.allocator.free(url);
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateInPlace(url);
    var goal: DoneGoal = .{ .browser = browser };
    const outcome = try browser.spinEventLoopUntil(.{ .context = &goal, .met = DoneGoal.met }, 15_000);
    try testing.expectEqual(Browser.SpinOutcome.met, outcome);
    // The page navigated its frame's frame, which was loading /slow?first;
    // the frame and then the page loaded, and 20 ms later the frame's frame
    // had still not loaded - its new response, /slow?second, takes a second.
    const log = try evaluate(browser, "globalThis.log.join()");
    defer testing.allocator.free(log);
    try testing.expectEqualStrings("navigated,child load,load", log);
}
