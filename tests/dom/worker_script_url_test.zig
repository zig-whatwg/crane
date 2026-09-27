//! The Worker constructor's script URL (HTML "new Worker(scriptURL, options)"
//! steps 2-4): "encoding-parse a URL given scriptURL, relative to outside
//! settings" - its API base URL, which for a window is its document's URL -
//! and a "SyntaxError" DOMException on failure.
//!
//! Crane used to resolve it against the document's ORIGIN (a thread-local the
//! test runner set), so `new Worker("support/x.js")` from /workers/y.html
//! fetched /support/x.js. `Worker.resolveScriptURL` is the parse, given the API
//! base URL the constructor looked up.

const std = @import("std");
const testing = std.testing;
const WorkerImpl = @import("impls").Worker;

const document = "http://web-platform.test:8000/workers/constructors/Worker/page.html";

fn expectResolved(expected: []const u8, script_url: []const u8, base: ?[]const u8) !void {
    const resolved = try WorkerImpl.resolveScriptURL(testing.allocator, script_url, base);
    defer testing.allocator.free(resolved);
    try testing.expectEqualStrings(expected, resolved);
}

test "a relative URL resolves against the document's URL, not its origin" {
    try expectResolved("http://web-platform.test:8000/workers/constructors/Worker/support/x.js", "support/x.js", document);
    try expectResolved("http://web-platform.test:8000/workers/constructors/Worker/x.js", "./x.js", document);
    try expectResolved("http://web-platform.test:8000/workers/x.js", "../../x.js", document);
    try expectResolved("http://web-platform.test:8000/workers/constructors/Worker/page.html?q", "?q", document);
}

test "a path-absolute URL resolves against the document's origin" {
    try expectResolved("http://web-platform.test:8000/crane/resources/w.js", "/crane/resources/w.js", document);
}

test "an absolute URL is parsed and serialized, whatever the base" {
    try expectResolved("http://www1.web-platform.test:8000/w.js", "http://www1.web-platform.test:8000/w.js", document);
    try expectResolved("data:text/javascript,postMessage(1)", "data:text/javascript,postMessage(1)", document);
    try expectResolved("blob:http://web-platform.test:8000/2c8d-uuid", "blob:http://web-platform.test:8000/2c8d-uuid", null);
    // The parser normalizes: the scheme and host are lowercased.
    try expectResolved("http://example.com/w.js", "HTTP://EXAMPLE.COM/w.js", document);
}

test "a URL that does not parse is a SyntaxError" {
    try testing.expectError(error.SyntaxError, WorkerImpl.resolveScriptURL(testing.allocator, "http://[", document));
    try testing.expectError(error.SyntaxError, WorkerImpl.resolveScriptURL(testing.allocator, "http://exa mple.com/w.js", document));
    // A relative URL with no base to resolve against.
    try testing.expectError(error.SyntaxError, WorkerImpl.resolveScriptURL(testing.allocator, "support/x.js", null));
}
