//! HTML "navigate" steps 12-14 and 20, as `navigate_steps` resolves them.
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate

const std = @import("std");
const testing = std.testing;
const steps = @import("html_core").navigation.navigate_steps;

const page = "http://web-platform.test:8000/a/b.html";

test "auto is push for a different URL, replace for the same URL from the same origin" {
    const active: steps.ActiveDocument = .{ .url = page, .is_initial_about_blank = false };
    try testing.expectEqual(steps.HistoryHandling.push, steps.resolveHistoryHandling(.auto, "http://web-platform.test:8000/a/c.html", active, true));
    try testing.expectEqual(steps.HistoryHandling.replace, steps.resolveHistoryHandling(.auto, page, active, true));
    // Step 12.1 needs the initiator to be same origin too.
    try testing.expectEqual(steps.HistoryHandling.push, steps.resolveHistoryHandling(.auto, page, active, false));
}

test "an explicit behaviour is kept" {
    const active: steps.ActiveDocument = .{ .url = page, .is_initial_about_blank = false };
    try testing.expectEqual(steps.HistoryHandling.push, steps.resolveHistoryHandling(.push, page, active, true));
    try testing.expectEqual(steps.HistoryHandling.replace, steps.resolveHistoryHandling(.replace, "http://x.test/", active, true));
}

test "the navigation must be a replace: javascript: URLs and the initial about:blank" {
    const loaded: steps.ActiveDocument = .{ .url = page, .is_initial_about_blank = false };
    try testing.expectEqual(steps.HistoryHandling.replace, steps.resolveHistoryHandling(.push, "javascript:1", loaded, true));
    const initial: steps.ActiveDocument = .{ .url = "about:blank", .is_initial_about_blank = true };
    try testing.expectEqual(steps.HistoryHandling.replace, steps.resolveHistoryHandling(.push, page, initial, false));
    try testing.expectEqual(steps.HistoryHandling.replace, steps.resolveHistoryHandling(.auto, page, initial, false));
}

test "a fragment navigation needs a fragment on the same URL and no document resource" {
    try testing.expect(steps.isFragmentNavigation(page ++ "#x", page, false));
    try testing.expect(steps.isFragmentNavigation(page ++ "#x", page ++ "#y", false));
    // An empty fragment is still a fragment.
    try testing.expect(steps.isFragmentNavigation(page ++ "#", page, false));
    // No fragment: a reload-like navigation, not a fragment one.
    try testing.expect(!steps.isFragmentNavigation(page, page ++ "#y", false));
    try testing.expect(!steps.isFragmentNavigation("http://web-platform.test:8000/a/c.html#x", page, false));
    try testing.expect(!steps.isFragmentNavigation(page ++ "#x", page, true));
    // The query is part of the URL compared.
    try testing.expect(!steps.isFragmentNavigation(page ++ "?q#x", page, false));
}

test "matches about:blank ignores query and fragment, and nothing else" {
    try testing.expect(steps.matchesAboutBlank("about:blank"));
    try testing.expect(steps.matchesAboutBlank("about:blank?foo"));
    try testing.expect(steps.matchesAboutBlank("about:blank#bar"));
    try testing.expect(!steps.matchesAboutBlank("about:blankx"));
    try testing.expect(!steps.matchesAboutBlank("about:srcdoc"));
    try testing.expect(steps.matchesAboutSrcdoc("about:srcdoc"));
    try testing.expect(!steps.matchesAboutBlank("http://about:blank/"));
}

test "schemes" {
    try testing.expect(steps.isJavascript("javascript:void(0)"));
    try testing.expect(!steps.isJavascript("http://javascript.test/"));
    try testing.expect(steps.isFetchScheme("data:text/html,x"));
    try testing.expect(steps.isFetchScheme("https://x.test/"));
    try testing.expect(!steps.isFetchScheme("javascript:1"));
    try testing.expect(!steps.isFetchScheme("mailto:a@b"));
}

test "ongoing navigation equality" {
    const a: steps.OngoingNavigation = .{ .id = 3 };
    try testing.expect(a.eql(.{ .id = 3 }));
    try testing.expect(!a.eql(.{ .id = 4 }));
    try testing.expect(!a.eql(.traversal));
    try testing.expect((steps.OngoingNavigation{ .none = {} }).eql(.none));
}

test "every response but a 204 or 205 makes a document" {
    const proceed = @import("html_core").navigation.shouldNavigationProceed;
    try testing.expect(proceed(200));
    // The server's error page is a page: browsers show it, and fire load.
    try testing.expect(proceed(404));
    try testing.expect(proceed(500));
    try testing.expect(proceed(302));
    try testing.expect(!proceed(204));
    try testing.expect(!proceed(205));
}

test "the termination nesting level nests, and never goes below zero" {
    const level = @import("html_core").navigation.termination_nesting;
    try testing.expect(!level.active());
    level.enter();
    level.enter();
    level.leave();
    try testing.expect(level.active());
    level.leave();
    try testing.expect(!level.active());
    level.leave();
    try testing.expect(!level.active());
}
