//! A dedicated worker's thread ends, and what the thread kept for itself
//! must end with it.
//!
//! Every dedicated worker runs its agent on a thread of its own
//! (docs/instances.md, "Decisions"). The adapter and the impls keep some
//! per-agent bookkeeping in threadlocal containers - the worker realms made
//! on the thread (worker_realm.zig `records`), its wrapper caches
//! (wrapper_cache.zig `live_caches`), its callback wrappers
//! (callback_registry.zig `live`), its module records (protocol_modules.zig
//! `records`), its MessagePorts (MessagePort.zig `live_ports`). Each entry is
//! removed when its owner goes, but a container that keeps its capacity
//! after its last entry leaves it allocated when the thread's TLS goes: one
//! block per container per worker thread, for the life of the process. The
//! page_allocator ones are invisible to `leaks --atExit` (mmap, not malloc),
//! so this counts them directly: Zig's page_allocator maps anonymous memory
//! with no VM tag (V8 tags its own mappings 255, malloc its zones), and the
//! untagged anonymous bytes mapped in the process must not grow with the
//! number of worker threads that have come and gone.
//!
//! tests/v8 is one executable: the engine may already be started, and each
//! worker thread here makes and ends its own agent, as a worker does.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const c = std.c;

/// Not page_allocator: this test's own memory must not be what it counts.
const allocator = std.heap.c_allocator;

/// What each worker thread's realm runs: a MessagePort pair, an event
/// listener (a callback wrapper), platform objects in the wrapper cache.
const worker_script =
    \\const channel = new MessageChannel();
    \\channel.port1.start();
    \\const target = new EventTarget();
    \\let heard = 0;
    \\target.addEventListener("x", () => { heard++; });
    \\target.dispatchEvent(new Event("x"));
    \\channel.port1.close();
;

/// A worker script that throws did not make what this test counts.
fn failOnReport(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const thrown: *bool = @ptrCast(@alignCast(host.?));
    thrown.* = true;
    std.debug.print("worker thread state: the worker script threw: {s}\n", .{info.message});
}

/// An address range of anonymous memory mapped with no VM tag.
const Range = struct { start: u64, end: u64 };

/// Every range of anonymous memory mapped with no VM tag in this process now,
/// in address order. OWNED (`allocator`).
fn untaggedAnonymousRanges() ![]Range {
    var ranges: std.ArrayListUnmanaged(Range) = .empty;
    errdefer ranges.deinit(allocator);
    var address: c.mach_vm_address_t = 0;
    while (true) {
        var size: c.mach_vm_size_t = 0;
        var info: c.vm_region_extended_info = undefined;
        var count: c.mach_msg_type_number_t = c.VM.REGION.EXTENDED_INFO_COUNT;
        var object: c.mach_port_t = 0;
        const result = c.mach_vm_region(c.mach_task_self(), &address, &size, c.VM.REGION.EXTENDED_INFO, @ptrCast(&info), &count, &object);
        if (result != 0) break; // KERN_INVALID_ADDRESS: past the last region
        if (info.user_tag == 0 and info.external_pager == 0) try ranges.append(allocator, .{ .start = address, .end = address + size });
        address += size;
    }
    return ranges.toOwnedSlice(allocator);
}

/// The bytes of `after` that no range of `before` covers: memory mapped
/// since `before` was taken and still mapped. What was unmapped meanwhile
/// does not offset it.
fn newlyMapped(before: []const Range, after: []const Range) u64 {
    var total: u64 = 0;
    for (after) |range| {
        var uncovered: u64 = range.end - range.start;
        for (before) |old| {
            const lo = @max(range.start, old.start);
            const hi = @min(range.end, old.end);
            if (hi > lo) uncovered -= hi - lo;
        }
        total += uncovered;
    }
    return total;
}

/// One worker thread's life, as WorkerThread runs it: an agent made on the
/// thread (its host agent), a worker realm whose script makes ports,
/// listeners and wrappers, a module parsed and let go, the realm's end, the
/// agent's end, and the thread's own state ended.
fn workerLife(failed: *?anyerror) void {
    workerSteps() catch |err| {
        failed.* = err;
    };
    runtime.instance_lifecycle.deinit();
}

fn workerSteps() !void {
    const agent = try engine.createAgent(.{
        .can_block = true,
        .from_snapshot = false,
        .hooks = &.{},
        .allocator = allocator,
    });
    defer engine.destroyAgent(agent);
    const made = try engine.createWorkerRealm(agent, &.{
        .url = "http://web-platform.test:8000/workers/w.js",
        .timer = null,
        .allocator = allocator,
    });
    defer engine.destroyWorkerRealm(made.realm, null, null);
    var thrown = false;
    engine.runClassicScript(made.realm, .{ .utf8 = worker_script }, "w.js", null, .{ .report = failOnReport, .host = &thrown }) catch |err| switch (err) {
        error.ExceptionReported => {},
        else => return err,
    };
    if (thrown) return error.WorkerScriptThrew;
    switch (try engine.parseModule(made.realm, "export const x = 1;", "http://web-platform.test:8000/workers/m.js", null)) {
        .record => |record| engine.releaseModuleRecord(record),
        .parse_error => |parse_error| {
            parse_error.release();
            return error.ModuleDidNotParse;
        },
    }
}

fn runWorkers(n: usize) !void {
    for (0..n) |_| {
        var failed: ?anyerror = null;
        const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, workerLife, .{&failed});
        thread.join();
        if (failed) |err| return err;
    }
}

test "worker threads that end leave no per-thread containers mapped" {
    if (runtime.SlabAllocator.tryGet()) |_| {} else |_| runtime.initializeRuntime(std.heap.page_allocator);
    @import("interfaces").process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});

    // First use of every process-wide pool and cache, before counting.
    try runWorkers(8);
    const before = try untaggedAnonymousRanges();
    defer allocator.free(before);
    const workers = 32;
    try runWorkers(workers);
    const after = try untaggedAnonymousRanges();
    defer allocator.free(after);

    // A leaked container is at least one page per worker thread; allow a
    // quarter of a page per thread for the process's own churn.
    const grown = newlyMapped(before, after);
    const limit: u64 = workers * std.heap.pageSize() / 4;
    std.debug.print("worker thread state: {d} bytes of untagged anonymous memory newly mapped over {d} worker threads (limit {d})\n", .{ grown, workers, limit });
    if (grown >= limit) return error.PerThreadStateLeaked;
}
