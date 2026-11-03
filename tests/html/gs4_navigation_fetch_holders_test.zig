//! The guarantees of html_core's navigation fetch holders that a
//! navigation's tickets rely on (HTMLIFrameElement, lane gstate4: a holder
//! keeps the navigation's Browser's navigations and its ID, and frees that
//! ticket exactly once, at its own end):
//!
//! - a StreamedBody's `kept` is released exactly once, when the body is
//!   released - not when another holder takes it (`handTo`) - and release
//!   stops the body's transfer (and terminates an adopted fetch, which then
//!   calls nothing back) before it;
//! - an ArrivingResponse's consumer hears the body until the response is
//!   taken or destroyed, and nothing after.
const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const fetch_integration = @import("html_core").navigation.fetch_integration;
const StreamedBody = fetch_integration.StreamedBody;
const ArrivingResponse = fetch_integration.ArrivingResponse;
const PipeSource = fetch.internal.body_pipe.PipeSource;

const Counts = struct {
    alive_calls: usize = 0,
    kept_releases: usize = 0,
    notified: usize = 0,
    cancelled: usize = 0,

    fn alive(context: *anyopaque) bool {
        const self: *Counts = @ptrCast(@alignCast(context));
        self.alive_calls += 1;
        return true;
    }

    fn release(context: *anyopaque) void {
        const self: *Counts = @ptrCast(@alignCast(context));
        self.kept_releases += 1;
    }

    fn notify(context: *anyopaque) void {
        const self: *Counts = @ptrCast(@alignCast(context));
        self.notified += 1;
    }

    fn cancel(context: *anyopaque) void {
        const self: *Counts = @ptrCast(@alignCast(context));
        self.cancelled += 1;
    }
};

test "a streamed body releases what it keeps exactly once, at its release, after stopping its transfer" {
    var counts: Counts = .{};
    var parser_holder: Counts = .{};
    const source = try PipeSource.create(testing.allocator);
    source.producer = .{ .context = &counts, .cancel = &Counts.cancel };
    const pipe = try source.branch();
    const body = try StreamedBody.create(testing.allocator, pipe, .{ .context = &counts, .alive = &Counts.alive });
    body.kept = .{ .context = &counts, .release = &Counts.release };
    source.push("<p>a");
    // The document's parser takes the body: nothing is released.
    body.handTo(.{ .context = &parser_holder, .alive = &Counts.alive });
    try testing.expectEqual(@as(usize, 0), counts.kept_releases);
    // The parser lets it go: the transfer stops, then what it kept goes, once.
    body.release();
    try testing.expectEqual(@as(usize, 1), counts.cancelled);
    try testing.expectEqual(@as(usize, 1), counts.kept_releases);
}

/// A response whose body arrives through a pipe of `source`.
fn arrivingResult(source: *PipeSource) !fetch.algorithms.FetchResult {
    const response = try fetch.internal.InternalResponse.init(testing.allocator);
    errdefer response.deinit();
    response.body = try fetch.internal.Body.fromPipe(testing.allocator, try source.branch());
    return .{ .response = response, .timing_info = .{ .allocator = testing.allocator } };
}

test "an arriving response's consumer hears its body until the response is taken, and nothing after" {
    var counts: Counts = .{};
    // No producer: the source goes with its last reader.
    const source = try PipeSource.create(testing.allocator);
    const arriving = try ArrivingResponse.create(testing.allocator, try arrivingResult(source), null, .{ .context = &counts, .notify = &Counts.notify });
    source.push("a");
    try testing.expect(counts.notified >= 1);
    var taken = arriving.take();
    const before = counts.notified;
    // Still the body's reader, the result is no longer heard.
    source.push("b");
    try testing.expectEqual(before, counts.notified);
    taken.result.deinit();
}

test "an arriving response destroyed with the navigation's result notifies nothing and stops its transfer" {
    var counts: Counts = .{};
    const source = try PipeSource.create(testing.allocator);
    source.producer = .{ .context = &counts, .cancel = &Counts.cancel };
    var waiting = fetch_integration.NavigationFetchResult.init(testing.allocator);
    waiting.arriving = try ArrivingResponse.create(testing.allocator, try arrivingResult(source), null, .{ .context = &counts, .notify = &Counts.notify });
    source.push("a");
    const before = counts.notified;
    // The result's end destroys the response: its reader goes - the last,
    // so the transfer stops (and the source with it) - and the consumer
    // hears nothing of it.
    waiting.deinit();
    try testing.expectEqual(before, counts.notified);
    try testing.expectEqual(@as(usize, 1), counts.cancelled);
}
