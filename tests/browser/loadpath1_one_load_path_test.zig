//! A Browser loads a page as a browser does: its page is a top-level
//! traversable made with an initial about:blank document (HTML "create a new
//! top-level traversable"), and every load the embedder asks for is HTML
//! "navigate" of that traversable with user involvement "browser UI" - the
//! embedder's markup passed as the navigation's response, as WebKit's
//! loadHTMLString (SubstituteData) and Chromium's LoadDataWithBaseURL pass
//! theirs (lane loadpath1). There is no second, embedder-only way to put a
//! document into a Window.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

fn evaluate(browser: *Browser, script: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(script, testing.allocator);
}

test "a Browser's page starts on an initial about:blank of an opaque origin, and its first load gives the page a Window of its own" {
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false });
    defer browser.deinit();

    // HTML "create a new browsing context and document" given a null
    // creator: step 7 determines the origin given about:blank and a null
    // creatorOrigin - "determining the origin" step 5, about:blank's own
    // origin, a new opaque one. A new tab's initial empty document is opaque
    // in Chrome, Firefox and Safari alike.
    const initial = try evaluate(browser, "[self.origin, document.URL, history.length].join('|')");
    defer testing.allocator.free(initial);
    try testing.expectEqualStrings("null|about:blank|1", initial);

    const ctx = browser.current_context.?;
    try ctx.runScript("window.markedBeforeTheLoad = 1;");
    try ctx.loadHTML("<!doctype html><title>page</title><p>page", .{ .base_url = "http://example.test/page.html" });

    // "Create and initialize a Document object" step 6 keeps the initial
    // about:blank's Window only when its origin is same origin-domain with
    // navigationParams's origin. An opaque origin never is with
    // http://example.test, so step 7 made a new Window: nothing set on the
    // initial about:blank's survives (Blink's ShouldReuseDOMWindow, Gecko's
    // nsGlobalWindowOuter::WouldReuseInnerWindow and WebKit's
    // DocumentWriter::begin all refuse the same way). The navigation from the
    // initial about:blank replaced its entry: history.length stays 1.
    const loaded = try evaluate(browser, "[typeof markedBeforeTheLoad, self.origin, document.URL, document.title, history.length].join('|')");
    defer testing.allocator.free(loaded);
    try testing.expectEqualStrings("undefined|http://example.test|http://example.test/page.html|page|1", loaded);
}

test "a second load of a page is a navigation of the same traversable: a push, and its Window is new" {
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false });
    defer browser.deinit();
    const ctx = browser.current_context.?;
    try ctx.loadHTML("<!doctype html><title>one</title>", .{ .base_url = "http://example.test/one" });
    try ctx.runScript("window.markedOnOne = 1;");
    try ctx.loadHTML("<!doctype html><title>two</title>", .{ .base_url = "http://example.test/two" });

    // Navigate step 13 ("auto" history handling): not the initial
    // about:blank, another URL - a push. Step 6 of "create and initialize a
    // Document object" reuses only an initial about:blank's Window, so the
    // second document has a new one even though its origin is the same.
    const loaded = try evaluate(browser, "[typeof markedOnOne, document.title, history.length].join('|')");
    defer testing.allocator.free(loaded);
    try testing.expectEqualStrings("undefined|two|2", loaded);
}

test "a Browser's load of a URL that cannot be fetched fails as the navigation fails" {
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false });
    defer browser.deinit();
    // A refused connection: the navigation's fetch is a network error. The
    // traversable shows an error document, and the embedder's call says the
    // navigation failed, as CDP's Page.navigate returns its errorText.
    try testing.expectError(error.NetworkError, browser.navigate("http://127.0.0.1:9/", .window));
}
