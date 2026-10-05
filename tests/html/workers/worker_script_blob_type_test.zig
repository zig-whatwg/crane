//! A worker's script from a blob: URL, and its MIME type.
//!
//! HTML "fetch a classic worker script", processResponseConsumeBody step 3:
//! the script is refused for its MIME type only when "response's URL's scheme
//! is an HTTP(S) scheme" and its type is not a JavaScript MIME type - so a
//! classic worker made from a blob (or data:) URL runs whatever the blob's
//! type. A module worker's script is a module script, which "fetch a single
//! module script" accepts only with a JavaScript MIME type, whatever the
//! scheme. (The blob's bytes and type come from fetch's scheme fetch "blob",
//! whose resolver the blob URL store's owner installs at process start.)

const std = @import("std");
const testing = std.testing;
const script_fetch = @import("html_core").workers.script_fetch;

const url = "blob:http://web-platform.test:8000/x";

test "a classic worker's blob script runs whatever the blob's type" {
    var fetched = try script_fetch.scriptFromBlob(testing.allocator, url, .classic, "postMessage(1);", "text/plain");
    defer fetched.deinit();
    try testing.expectEqualStrings("postMessage(1);", fetched.source);
    try testing.expectEqualStrings(url, fetched.final_url);
}

test "a module worker's blob script with a type that is not JavaScript is refused" {
    try testing.expectError(error.ParseError, script_fetch.scriptFromBlob(testing.allocator, url, .module, "export {};", "text/plain"));
}

test "a module worker's blob script with a JavaScript type is accepted" {
    var fetched = try script_fetch.scriptFromBlob(testing.allocator, url, .module, "export {};", "text/javascript");
    defer fetched.deinit();
    try testing.expectEqualStrings("export {};", fetched.source);
}

test "a blob: worker script with no requesting origin is a network error" {
    try testing.expectError(error.FetchFailed, script_fetch.fetchWorkerScript(testing.allocator, url, .{ .worker_type = .classic }));
}
