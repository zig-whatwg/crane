//! A pair iterable's iterator prototype template in a worker realm.
//!
//! WebIDL 3.7.10: each realm has one "%<Interface> Iterator Prototype%" per
//! iterable interface. The V8 adapter makes it from a FunctionTemplate per
//! isolate (`iteratorPrototypeTemplate` in interface.zig), kept in the
//! isolate's template storage under "<Interface> Iterator". A worker realm
//! ends its template storage with the realm (worker_realm.zig,
//! destroyWorkerRealmIn -> isolate_templates.cleanupTemplateStorage), and
//! the storage disposed only the templates the registry held: every iterator
//! prototype template was left behind - one 16-byte Global<FunctionTemplate>
//! per iterable interface iterated, per worker realm. lane sw1-b2's
//! leaks --atExit over the cache-storage worker variants named it
//! (`v8_FunctionTemplate_New` from `V8Interface(Headers).returnNewIterator`
//! on worker threads, 21 roots).
//!
//! Measured as V8 counts handles (global handle bytes, every live Global's
//! slot) across worker realm rounds in one agent, for each kind of worker
//! global (dedicated, shared, service), and across many iterations in one
//! realm (the iterator objects themselves hold no Global).

const std = @import("std");
/// Every worker realm has an event loop; this test drives none.
const inline_task_loop = @import("inline_task_loop.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const ffi = v8.ffi;

var set_up = false;

fn setup() void {
    if (set_up) return;
    set_up = true;
    runtime.initializeRuntime(std.heap.page_allocator);
    v8.context_manager.init(std.heap.page_allocator) catch {};
}

const Reports = struct {
    count: usize = 0,
    buffer: [256]u8 = undefined,
    len: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        self.len = @min(info.message.len, self.buffer.len);
        @memcpy(self.buffer[0..self.len], info.message[0..self.len]);
    }
};

fn evalIn(realm: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    return protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, std.testing.allocator, .{ .report = Reports.report, .host = &reports }) catch |err| {
        if (reports.count > 0) std.debug.print("{s} threw: {s}\n", .{ source, reports.buffer[0..reports.len] });
        return err;
    };
}

const Kind = enum { dedicated, shared, service };

fn workerRealm(agent: *runtime.Agent, kind: Kind) !runtime.WorkerRealm {
    return v8.worker_realm.createWorkerRealm(agent, switch (kind) {
        .dedicated => .{
            .url = "http://web-platform.test:8000/fetch/w.js",
            .timer = null,
            .event_loop = inline_task_loop.eventLoop(),
            .allocator = std.heap.page_allocator,
        },
        .shared => .{
            .url = "http://web-platform.test:8000/fetch/shared.js",
            .timer = null,
            .event_loop = inline_task_loop.eventLoop(),
            .global = .shared,
            .allocator = std.heap.page_allocator,
        },
        .service => .{
            .url = "https://web-platform.test:8443/fetch/sw.js",
            .timer = null,
            .event_loop = inline_task_loop.eventLoop(),
            .global = .service,
            .allocator = std.heap.page_allocator,
        },
    });
}

/// Iterates every pair iterable a worker has - Headers, FormData and
/// URLSearchParams - through @@iterator, entries(), keys() and values(), and
/// reads each iterator's prototype's class string: the iterator prototype
/// is made in this realm.
const iterate_all =
    \\(() => {
    \\  const headers = new Headers([['a', '1'], ['b', '2']]);
    \\  const form = new FormData(); form.append('a', '1');
    \\  const params = new URLSearchParams('a=1&b=2');
    \\  let n = 0;
    \\  for (const target of [headers, form, params]) {
    \\    for (const _ of target) n++;
    \\    for (const _ of target.entries()) n++;
    \\    for (const _ of target.keys()) n++;
    \\    for (const _ of target.values()) n++;
    \\  }
    \\  return [n, Object.prototype.toString.call(Object.getPrototypeOf(headers.keys())),
    \\    Object.prototype.toString.call(Object.getPrototypeOf(form.keys())),
    \\    Object.prototype.toString.call(Object.getPrototypeOf(params.keys()))].join();
    \\})()
;
const iterate_all_result = "20,[object Headers Iterator],[object FormData Iterator],[object URLSearchParams Iterator]";

/// What one Global costs in V8's count.
fn oneHandleBytes(isolate: *ffi.Isolate) usize {
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const one = ffi.v8_Number_New(isolate, 1);
    const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    ffi.v8_Value_Dispose(@ptrCast(one));
    return with_one - start;
}

fn iterateInNewRealm(agent: *runtime.Agent, kind: Kind) !void {
    const made = try workerRealm(agent, kind);
    defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);
    const result = try evalIn(made.realm, iterate_all);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(iterate_all_result, result);
}

// A worker realm that iterates Headers, FormData and URLSearchParams, made
// and destroyed in one agent: the iterator prototype templates its template
// storage made go with the storage. Red before: three handles a round (one
// per interface iterated) for every kind of worker global.
test "worker realms that iterate pair iterables leave no iterator prototype template behind" {
    setup();
    inline for (.{ Kind.dedicated, Kind.shared, Kind.service }) |kind| {
        const agent = try v8.worker_realm.createAgent();
        defer v8.worker_realm.destroyAgent(agent);
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        const handle_bytes = oneHandleBytes(isolate);
        // The first realm makes what every later one reuses.
        try iterateInNewRealm(agent, kind);
        const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const rounds = 4;
        for (0..rounds) |_| try iterateInNewRealm(agent, kind);
        const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        if (after -| before >= handle_bytes) {
            std.debug.print("{s} worker realms: global handles {d} -> {d} bytes ({d} a handle, {d} handles a realm) over {d} realms\n", .{ @tagName(kind), before, after, handle_bytes, (after - before) / handle_bytes / rounds, rounds });
            return error.HandlesLeaked;
        }
    }
}

// Many iterations in one worker realm: the template is made once for the
// isolate and every later iterator reuses it, so nothing grows per call.
test "iterating pair iterables many times in one worker realm keeps global handles flat" {
    setup();
    const agent = try v8.worker_realm.createAgent();
    defer v8.worker_realm.destroyAgent(agent);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    const handle_bytes = oneHandleBytes(isolate);
    const made = try workerRealm(agent, .dedicated);
    defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);

    const first = try evalIn(made.realm, iterate_all);
    defer std.testing.allocator.free(first);
    try std.testing.expectEqualStrings(iterate_all_result, first);
    protocol.requestGarbageCollection(agent);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..50) |_| {
        const again = try evalIn(made.realm, iterate_all);
        defer std.testing.allocator.free(again);
        try std.testing.expectEqualStrings(iterate_all_result, again);
    }
    protocol.requestGarbageCollection(agent);
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after -| before >= handle_bytes) {
        std.debug.print("one worker realm: global handles {d} -> {d} bytes ({d} a handle) over 50 rounds of iteration\n", .{ before, after, handle_bytes });
        return error.HandlesLeaked;
    }
}
