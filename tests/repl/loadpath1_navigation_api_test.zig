//! The navigation API's view of a page that came over the network, as a WPT
//! page does (lane loadpath1): its script runs inside its navigation's
//! commit.
//!
//! - A NavigationHistoryEntry stands for its session history entry, whose
//!   document is the document "attempt to populate the history entry's
//!   document" loaded - set before any of the parser's tasks run, so an inline
//!   script's currentEntry is its own document's (sameDocument true), and
//!   stays so (sameDocument reads the entry's document, not a copy made with
//!   the object). navigation-api/navigation-history-entry/sameDocument-after-
//!   fragment-navigate.html: Chrome, Firefox and Safari pass it.
//! - A frame's javascript: URL navigation commits a document whose document
//!   state's origin is initiatorOrigin ("evaluate a javascript: URL"): the
//!   entry is the replaced one's place, same origin, and the frame's
//!   navigation API lists it. navigation-api/navigation-history-entry/
//!   entries-after-javascript-url-navigation.html: Chrome and Safari pass it.
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

fn expectLog(path: []const u8, expected: []const u8) !void {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    const url = try site.url(testing.allocator, path);
    defer testing.allocator.free(url);
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateInPlace(url);
    var goal: DoneGoal = .{ .browser = browser };
    const outcome = try browser.spinEventLoopUntil(.{ .context = &goal, .met = DoneGoal.met }, 15_000);
    try testing.expectEqual(Browser.SpinOutcome.met, outcome);
    const log = try evaluate(browser, "globalThis.log.join()");
    defer testing.allocator.free(log);
    try testing.expectEqualStrings(expected, log);
}

test "an entry handed out while its document parses is that document's, then and after its load" {
    try expectLog("/nav-same-document.html", "parse true,load true,current true");
}

test "a frame's javascript: URL document replaces its entry with the initiator's origin, and the frame's navigation API lists it" {
    // One entry - the javascript: URL's document replaced /b.html's ("evaluate
    // a javascript: URL" step 13, historyHandling "replace") - and it is the
    // current one, with the replaced entry's key.
    try expectLog("/nav-javascript-url.html", "1,true");
}
