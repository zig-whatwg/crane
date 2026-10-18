//! Fetch "fetch" step 12: a request whose header list has no `Accept` gets
//! one before main fetch - `*/*`, the document `Accept` header value for a
//! prefetch or a document/frame/iframe destination, and the image, json and
//! style values the step lists for those destinations. Main fetch, and so a
//! service worker's fetch event (fetch-event.https.html "Service Worker
//! headers in the request of a fetch event"), sees it in the request's
//! header list.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const FetchJob = fetch.algorithms.FetchJob;
const InternalRequest = fetch.internal.InternalRequest;
const Destination = fetch.internal.Destination;

const document_accept = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8";

/// The `Accept` value fetch gives a request for `destination` (and
/// `initiator`), read from its header list once fetch has started.
fn acceptFor(destination: Destination, initiator: fetch.internal.Initiator, preset: ?[]const u8) ![]u8 {
    const request = try InternalRequest.init(testing.allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.destination = destination;
    request.initiator = initiator;
    if (preset) |value| try request.header_list.set("Accept", value);
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    _ = try job.start();
    const value = request.header_list.getFirstValue("Accept") orelse return error.TestExpectedAccept;
    return testing.allocator.dupe(u8, value);
}

fn expectAccept(expected: []const u8, destination: Destination, initiator: fetch.internal.Initiator, preset: ?[]const u8) !void {
    const value = try acceptFor(destination, initiator, preset);
    defer testing.allocator.free(value);
    try testing.expectEqualStrings(expected, value);
}

test "fetch step 12: document, frame and iframe destinations get the document Accept header value" {
    try expectAccept(document_accept, .document, .empty, null);
    try expectAccept(document_accept, .frame, .empty, null);
    try expectAccept(document_accept, .iframe, .empty, null);
}

test "fetch step 12: image, json and style destinations get their own values" {
    try expectAccept("image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5", .image, .empty, null);
    try expectAccept("application/json,*/*;q=0.5", .json, .empty, null);
    try expectAccept("text/css,*/*;q=0.1", .style, .empty, null);
}

test "fetch step 12: any other destination gets */*" {
    for ([_]Destination{ .empty, .script, .worker, .serviceworker, .font, .audio, .video, .object, .embed, .report }) |destination| {
        try expectAccept("*/*", destination, .empty, null);
    }
}

test "fetch step 12.2: a prefetch gets the document Accept header value whatever its destination" {
    try expectAccept(document_accept, .empty, .prefetch, null);
    try expectAccept(document_accept, .script, .prefetch, null);
}

test "fetch step 12: a request that has an Accept header keeps it" {
    try expectAccept("text/x-own", .document, .empty, "text/x-own");
    try expectAccept("application/x-own", .image, .prefetch, "application/x-own");
}
