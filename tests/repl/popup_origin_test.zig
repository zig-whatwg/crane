//! A popup opened by a page the console loaded. The console loads a page by
//! HTML "navigate" through the host page's top-level traversable
//! (Browser.navigateTraversable -> Context.navigate), whose commit makes the
//! page's new Window (Context.realmForTraversableDocument -> replaceRealm) -
//! a path the WPT runner, which loads each file as an embedder load, rarely
//! takes. window.open() gives a popup its opener's origin, and a same-origin
//! popup's first navigation reuses the Window its initial about:blank
//! document had (HTML "create and initialize a Document object" step 6), so
//! `p.onload` set right after open() fires (wpt
//! html/webappapis/scripting/processing-model-2/integration-with-the-javascript-job-queue/promise-job-entry.html,
//! html/interaction/focus/the-autofocus-attribute/document-with-fragment-valid.html).
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const Console = @import("repl").Console;
const Site = @import("site.zig").Site;

test "a same-origin popup of a page the console opened loads in the Window open() returned: its load listener runs" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    const a = try site.url(testing.allocator, "/a.html");
    defer testing.allocator.free(a);

    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    var output: std.Io.Writer.Allocating = .init(testing.allocator);
    defer output.deinit();
    var console = Console.init(testing.allocator, browser, &output.writer);
    defer console.deinit();
    console.load_timeout_ms = 20_000;
    console.deadline_ms = 10_000;

    console.open(a);
    try console.runUntilReady();
    output.clearRetainingCapacity();
    _ = try console.feedLine("window.origin");
    const origin = try std.fmt.allocPrint(testing.allocator, "'http://127.0.0.1:{d}'\n", .{site.listener.port()});
    defer testing.allocator.free(origin);
    try testing.expectEqualStrings(origin, output.written());

    output.clearRetainingCapacity();
    _ = try console.feedLine("await new Promise(r => { const p = window.open('/popup.html'); p.onload = () => r(p.document.title); })");
    const printed = output.written();
    if (std.mem.indexOf(u8, printed, "'Popup'\n") == null) {
        std.debug.print("printed:\n{s}\n", .{printed});
        return error.TestPopupLoadNotSeen;
    }
}
