//! Main fetch step 19's MIME checks: "should response to request be blocked
//! due to its MIME type?" and "... due to nosniff?", and "determine
//! nosniff". "Extract a MIME type" is internal/mime.zig's.
//!
//! Both are keyed on request's destination, so they bite only for requests
//! that carry one (a script, a worker, a stylesheet).
//!
//! Spec: https://fetch.spec.whatwg.org/#should-response-to-request-be-blocked-due-to-mime-type?
//! Spec: https://fetch.spec.whatwg.org/#should-response-to-request-be-blocked-due-to-nosniff?

const std = @import("std");
const Allocator = std.mem.Allocator;
const HeaderList = @import("../internal/header_list.zig").HeaderList;
const Destination = @import("../internal/request.zig").Destination;
const mime = @import("../internal/mime.zig");
const mimesniff = @import("mimesniff");

/// Fetch "should response to request be blocked due to its MIME type?"
pub fn blockedDueToMimeType(allocator: Allocator, destination: Destination, headers: *const HeaderList) !bool {
    // 1. Let mimeType be the result of extracting a MIME type from response's
    //    header list.
    const essence = (try extractMimeEssence(allocator, headers)) orelse {
        // 2. If mimeType is failure, then return allowed.
        return false;
    };
    defer allocator.free(essence);
    // 3-4. If destination is script-like and mimeType's essence starts with
    //      "audio/", "image/", or "video/", or is "text/csv": blocked.
    if (!destination.isScriptLike()) return false;
    return std.mem.startsWith(u8, essence, "audio/") or std.mem.startsWith(u8, essence, "image/") or
        std.mem.startsWith(u8, essence, "video/") or std.mem.eql(u8, essence, "text/csv");
}

/// Fetch "should response to request be blocked due to nosniff?"
pub fn blockedDueToNosniff(allocator: Allocator, destination: Destination, headers: *const HeaderList) !bool {
    // 1. If determine nosniff with response's header list is false, then
    //    return allowed.
    if (!try determineNosniff(allocator, headers)) return false;
    // 2. Let mimeType be the result of extracting a MIME type from
    //    response's header list.
    const essence = try extractMimeEssence(allocator, headers);
    defer if (essence) |e| allocator.free(e);
    // 3-4. If destination is script-like and mimeType is failure or is not
    //      a JavaScript MIME type: blocked.
    if (destination.isScriptLike()) {
        const e = essence orelse return true;
        return !mimesniff.predicates.isJavaScriptMimeTypeEssenceMatch(e);
    }
    // 5. If destination is "style" and mimeType is failure or its essence
    //    is not "text/css": blocked.
    if (destination == .style) {
        const e = essence orelse return true;
        return !std.mem.eql(u8, e, "text/css");
    }
    // 6. Return allowed.
    return false;
}

/// Fetch "determine nosniff": the first `X-Content-Type-Options` value is
/// `nosniff` (ASCII case-insensitive).
pub fn determineNosniff(allocator: Allocator, headers: *const HeaderList) !bool {
    // 1. Let values be the result of getting, decoding, and splitting
    //    `X-Content-Type-Options` from list.
    const values = (try headers.getDecodeSplit(allocator, "X-Content-Type-Options")) orelse {
        // 2. If values is null, then return false.
        return false;
    };
    defer {
        for (values) |v| allocator.free(v);
        allocator.free(values);
    }
    // 3. If values[0] is an ASCII case-insensitive match for "nosniff",
    //    then return true. 4. Return false.
    return values.len > 0 and std.ascii.eqlIgnoreCase(values[0], "nosniff");
}

const extractMimeEssence = mime.extractMimeEssence;

fn listOf(allocator: Allocator, pairs: []const [2][]const u8) !HeaderList {
    var list = HeaderList.init(allocator);
    errdefer list.deinit();
    for (pairs) |pair| try list.append(pair[0], pair[1]);
    return list;
}

test "blocked due to its MIME type: audio, image, video and text/csv, for script-like destinations only" {
    const allocator = std.testing.allocator;
    const Case = struct { destination: Destination, content_type: []const u8, blocked: bool };
    const cases = [_]Case{
        .{ .destination = .script, .content_type = "image/jpeg", .blocked = true },
        .{ .destination = .worker, .content_type = "audio/midi", .blocked = true },
        .{ .destination = .script, .content_type = "video/whatever", .blocked = true },
        .{ .destination = .script, .content_type = "text/csv", .blocked = true },
        .{ .destination = .script, .content_type = "text/html", .blocked = false },
        .{ .destination = .script, .content_type = "text/plain", .blocked = false },
        .{ .destination = .image, .content_type = "image/jpeg", .blocked = false },
        .{ .destination = .empty, .content_type = "text/csv", .blocked = false },
    };
    for (cases) |case| {
        var list = try listOf(allocator, &.{.{ "Content-Type", case.content_type }});
        defer list.deinit();
        try std.testing.expectEqual(case.blocked, try blockedDueToMimeType(allocator, case.destination, &list));
    }
}

test "blocked due to nosniff: scripts need a JavaScript MIME type, styles text/css" {
    const allocator = std.testing.allocator;
    const Case = struct { destination: Destination, content_type: ?[]const u8, nosniff: ?[]const u8, blocked: bool };
    const cases = [_]Case{
        .{ .destination = .script, .content_type = "text/plain", .nosniff = "nosniff", .blocked = true },
        .{ .destination = .script, .content_type = "text/javascript", .nosniff = "NoSniff", .blocked = false },
        .{ .destination = .script, .content_type = "application/x-javascript", .nosniff = "nosniff, bogus", .blocked = false },
        .{ .destination = .script, .content_type = null, .nosniff = "nosniff", .blocked = true },
        .{ .destination = .script, .content_type = "text/plain", .nosniff = "bogus, nosniff", .blocked = false },
        .{ .destination = .script, .content_type = "text/plain", .nosniff = null, .blocked = false },
        .{ .destination = .style, .content_type = "text/plain", .nosniff = "nosniff", .blocked = true },
        .{ .destination = .style, .content_type = "text/css;charset=utf-8", .nosniff = "nosniff", .blocked = false },
        .{ .destination = .image, .content_type = "text/plain", .nosniff = "nosniff", .blocked = false },
    };
    for (cases) |case| {
        var list = HeaderList.init(allocator);
        defer list.deinit();
        if (case.content_type) |ct| try list.append("Content-Type", ct);
        if (case.nosniff) |n| try list.append("X-Content-Type-Options", n);
        try std.testing.expectEqual(case.blocked, try blockedDueToNosniff(allocator, case.destination, &list));
    }
}
