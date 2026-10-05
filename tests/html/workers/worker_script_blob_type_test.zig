//! A worker's script from a blob: URL, and its MIME type.
//!
//! HTML "fetch a classic worker script", processResponseConsumeBody step 3:
//! the script is refused for its MIME type only when "response's URL's scheme
//! is an HTTP(S) scheme" and its type is not a JavaScript MIME type - so a
//! classic worker made from a blob (or data:) URL runs whatever the blob's
//! type. A module worker's script is a module script, which "fetch a single
//! module script" accepts only with a JavaScript MIME type, whatever the
//! scheme.

const std = @import("std");
const testing = std.testing;
const workers = @import("html_core").workers;

fn plainTextBlob(allocator: std.mem.Allocator, _: []const u8, _: []const u8) ?workers.BlobResolveResult {
    const bytes = allocator.dupe(u8, "postMessage(1);") catch return null;
    const content_type = allocator.dupe(u8, "text/plain") catch {
        allocator.free(bytes);
        return null;
    };
    return .{ .bytes = bytes, .content_type = content_type, .owns_bytes = true };
}

test "a classic worker's blob script runs whatever the blob's type" {
    workers.setBlobResolver(plainTextBlob);
    defer workers.clearBlobResolver();
    var fetched = try workers.fetchWorkerScript(testing.allocator, "blob:http://web-platform.test:8000/x", .{
        .worker_type = .classic,
        .requesting_origin = "http://web-platform.test:8000",
    });
    defer fetched.deinit();
    try testing.expectEqualStrings("postMessage(1);", fetched.source);
}

test "a module worker's blob script with a type that is not JavaScript is refused" {
    workers.setBlobResolver(plainTextBlob);
    defer workers.clearBlobResolver();
    try testing.expectError(error.ParseError, workers.fetchWorkerScript(testing.allocator, "blob:http://web-platform.test:8000/x", .{
        .worker_type = .module,
        .requesting_origin = "http://web-platform.test:8000",
    }));
}
