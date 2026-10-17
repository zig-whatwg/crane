//! Main fetch step 23 (Subresource Integrity) for a response a service
//! worker answered: its body arrives through the relay (AsyncFetch's
//! relay_source), not the network's source, and the `.body` wait holds
//! until the relay has ended - then the bytes are verified whole. Review S1
//! of Codex row 48: without it the job resumed at once with the pipe still
//! open and failed every such request, matching hash or not.

const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const AsyncFetch = fetch.algorithms.AsyncFetch;
const AgentFetches = fetch.algorithms.AgentFetches;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const swf = fetch.internal.service_worker_fetch;

/// sha256 of "abc".
const good = "sha256-ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=";

/// The service worker: hands every request a call, which the test answers.
const Workers = struct {
    call: ?*swf.Call = null,

    fn route(self: *Workers) fetch.internal.ServiceWorkerRoute {
        return .{ .context = self, .client = 1, .handle = handle };
    }

    fn handle(context: *anyopaque, _: *const InternalRequest, _: u64) std.mem.Allocator.Error!swf.Route.Start {
        const self: *Workers = @ptrCast(@alignCast(context));
        const call = try swf.Call.create(testing.allocator);
        // Made with two references: fetch's, and the worker side's, which
        // the test answers with and releases.
        @atomicStore(?*swf.Call, &self.call, call, .release);
        return .{ .call = call };
    }
};

/// What the fetch's client heard.
const Outcome = struct {
    done: bool = false,
    network_error: bool = false,
    body: std.ArrayListUnmanaged(u8) = .empty,

    fn client(self: *Outcome) AsyncFetch.Client {
        return .{ .context = self, .done = onDone, .alive = alive, .gone = gone };
    }

    fn onDone(context: *anyopaque, result: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Outcome = @ptrCast(@alignCast(context));
        self.done = true;
        var r = result catch {
            self.network_error = true;
            return;
        };
        defer r.deinit();
        self.network_error = r.response.response_type == .@"error";
        if (r.response.body) |b| self.body.appendSlice(testing.allocator, b.getBytes()) catch {};
    }

    fn alive(_: *anyopaque) bool {
        return true;
    }

    fn gone(context: *anyopaque) void {
        const self: *Outcome = @ptrCast(@alignCast(context));
        self.done = true;
    }
};

fn turns(fetches: *AgentFetches, n: usize) void {
    for (0..n) |_| {
        _ = fetches.pump();
        clock.sleep(std.time.ns_per_ms);
    }
}

fn turnUntilDone(fetches: *AgentFetches, outcome: *const Outcome) void {
    const deadline = clock.monotonicMillis() + 5_000;
    while (!outcome.done and clock.monotonicMillis() < deadline) turns(fetches, 1);
}

test "a service worker's response to a request with integrity metadata is verified once its relayed body has ended" {
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    for ([_]enum { match, mismatch, failed }{ .match, .mismatch, .failed }) |kind| {
        var fetches = AgentFetches.init(testing.allocator);
        defer fetches.deinit();
        var workers: Workers = .{};
        var outcome: Outcome = .{};
        defer outcome.body.deinit(testing.allocator);

        const request = try InternalRequest.init(testing.allocator, "https://a.test/x.js");
        request.mode = .same_origin;
        try request.setOrigin("https://a.test");
        try request.setIntegrityMetadata(if (kind == .mismatch) "sha512-AAAA" else good);
        request.service_worker = workers.route();
        _ = try AsyncFetch.start(testing.allocator, request, .{}, &fetches, outcome.client());
        turns(&fetches, 3);

        // The worker answers: a basic response, its body still to come.
        // AsyncFetch's first turns ran Handle Fetch.
        const call = workers.call orelse return error.TestExpectedServiceWorkerCall;
        const response = try InternalResponse.init(testing.allocator);
        response.response_type = .basic;
        try response.addUrl("https://a.test/x.js");
        const relay = try swf.BodyRelay.create(testing.allocator);
        call.answer(.{ .response = .{ .response = response, .body = relay } });
        call.release();
        // The writer's reference, let go however the test ends.
        var writing = true;
        defer if (writing) {
            relay.fail();
            relay.release();
        };
        try testing.expect(relay.write("a"));
        turns(&fetches, 5);
        // Part of the body: integrity waits for the rest.
        try testing.expect(!outcome.done);

        if (kind == .failed) relay.fail() else {
            try testing.expect(relay.write("bc"));
            relay.close();
        }
        writing = false;
        relay.release();
        turnUntilDone(&fetches, &outcome);
        try testing.expect(outcome.done);
        if (kind == .match) {
            try testing.expect(!outcome.network_error);
            try testing.expectEqualStrings("abc", outcome.body.items);
        } else {
            try testing.expect(outcome.network_error);
        }
        try testing.expectEqual(@as(usize, 0), fetches.inFlight());
    }
}

/// The worker side of the blocking test, on a thread of its own: it answers
/// the call once fetch() waits on it, then writes the body over a few turns.
const BlockingWorker = struct {
    workers: *Workers,
    kind: Kind,

    const Kind = enum { match, mismatch, failed };

    fn run(self: *BlockingWorker) void {
        // The call exists once fetch() has run Handle Fetch.
        while (@atomicLoad(?*swf.Call, &self.workers.call, .acquire) == null) clock.sleep(std.time.ns_per_ms);
        const call = self.workers.call.?;
        const response = InternalResponse.init(testing.allocator) catch unreachable;
        response.response_type = .basic;
        response.addUrl("https://a.test/x.js") catch unreachable;
        const relay = swf.BodyRelay.create(testing.allocator) catch unreachable;
        call.answer(.{ .response = .{ .response = response, .body = relay } });
        call.release();
        _ = relay.write("a");
        clock.sleep(5 * std.time.ns_per_ms);
        if (self.kind == .failed) relay.fail() else {
            _ = relay.write("bc");
            relay.close();
        }
        relay.release();
    }
};

test "the blocking fetch verifies a service worker's response once its relayed body is whole" {
    for ([_]BlockingWorker.Kind{ .match, .mismatch, .failed }) |kind| {
        var workers: Workers = .{};
        const request = try InternalRequest.init(testing.allocator, "https://a.test/x.js");
        defer request.deinit();
        request.mode = .same_origin;
        try request.setOrigin("https://a.test");
        try request.setIntegrityMetadata(if (kind == .mismatch) "sha512-AAAA" else good);
        request.service_worker = workers.route();
        var worker: BlockingWorker = .{ .workers = &workers, .kind = kind };
        const thread = try std.Thread.spawn(.{}, BlockingWorker.run, .{&worker});
        var result = fetch.fetch(testing.allocator, request, .{}) catch |err| {
            thread.join();
            return err;
        };
        thread.join();
        defer result.deinit();
        if (kind == .match) {
            try testing.expectEqual(fetch.internal.ResponseType.basic, result.response.response_type);
            try testing.expectEqualStrings("abc", result.response.body.?.getBytes());
        } else {
            try testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
        }
    }
}
