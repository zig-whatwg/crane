//! A speculation rules script's parsed rule set is freed once its rules are
//! registered (lane exitleak1).
//!
//! "Prepare the script element" for a `speculationrules` script parses the
//! rule set (script_execution.parseSpeculationRules) and registers its URLs
//! as the document's prefetch hints, which copy them. Only the parse's error
//! message was freed; each rule's resolved URLs, tags and referrer policy
//! leaked - one block per absolute URL. The WPT runner reported it at exit
//! after html/browsers/browsing-the-web/history-traversal/pagereveal/
//! order-in-prerender-activation.https.html (main's sweep: one `leaked:` in
//! shard aan/2), whose page prerenders through such a script.

const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

const base_url = "http://exitleak1.test/speculation.html";

test "a speculation rules script leaves nothing of its parsed rules behind" {
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(base_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html><body>
        \\<script type="speculationrules">
        \\{"prerender": [{"source": "list", "urls": ["http://exitleak1.test/next.html", "/relative.html"], "tag": "t"}],
        \\ "prefetch": [{"urls": ["http://exitleak1.test/other.html"], "referrer_policy": "no-referrer"}],
        \\ "tag": "set"}
        \\</script>
    , .{ .base_url = base_url });
    _ = try browser.runEventLoopBlocking(10);
    // browser.deinit (deferred): testing.allocator reports what is not freed.
}
