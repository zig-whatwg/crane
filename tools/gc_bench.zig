//! Phase 6 measurement: does discarded DOM state come back?
//!
//! The exit criterion is *"RSS flat across 10,000 `document.createElement` +
//! discard cycles"*. This runs exactly that and prints the resident-memory series,
//! so the criterion is a number rather than an opinion.
//!
//! ## Why a tool and not a test
//!
//! The answer is a curve, not a boolean. Before a collector exists the useful
//! output is "how much per element, and is it linear" - which says whether the
//! growth is DOM state, V8 heap, or a fixed startup cost being amortised. A test
//! can only say pass or fail, and would say "fail" for months while reporting
//! nothing that helps. Once the number is flat this becomes a test.
//!
//! ## Usage
//!
//!   zig build gc-bench                  # 10,000 cycles, the criterion
//!   zig build gc-bench -- 50000 5000    # 50,000 cycles, sample every 5,000
//!
//! ## Reading the output
//!
//! `bytes/cycle` is the slope between the last two samples, not the average from
//! the start: startup dominates the first sample and would flatter every later one.
//! A collector that works drives the slope to zero while the absolute figure stays
//! put; an allocator that merely reuses memory without returning pages shows a
//! plateau too, which is why the absolute figure is printed alongside.

const std = @import("std");
const v8 = @import("v8");
const memory = @import("memory");
const Browser = @import("browser").Browser;
const runtime = @import("runtime");
const instance_bridge = @import("dom").instance_bridge;

const log = std.log.scoped(.gc_bench);

pub const std_options: std.Options = .{
    // The browser logs heavily at debug and info; this tool's output is a table and
    // must stay readable. Warnings and errors still come through.
    .log_level = .warn,
};

/// One reading at a known cycle count.
///
/// Resident bytes alone say how much is retained; the allocator counters say WHERE.
/// Without the split, "5,893 bytes per element" cannot be acted on - it does not
/// distinguish DOM state in the arena from V8's heap from registry entries.
const Sample = struct {
    cycle: usize,
    resident: ?usize,
    /// Cumulative bytes handed out by the state arena. Cumulative is the right
    /// figure precisely because the arena never resets: allocated == retained.
    arena_bytes: usize,
    arena_allocations: usize,
    /// Instance handles that were allocated and never returned. The slab recycles,
    /// so this rising means instances are not being deinit'd at all - a different
    /// bug from "state is not freed".
    live_instances: usize,
    /// Entries in the instance -> NodeBase map. Keyed on a recycled address, so
    /// this rising is both a leak and a type-confusion hazard (M13).
    bridge_entries: usize,
};

fn takeSample(cycle: usize) Sample {
    const arena = runtime.ArenaAllocator.tryGet() catch null;
    const slab = runtime.SlabAllocator.tryGet() catch null;
    return .{
        .cycle = cycle,
        .resident = memory.residentBytes(),
        .arena_bytes = if (arena) |a| a.stats().total_bytes_allocated else 0,
        .arena_allocations = if (arena) |a| a.stats().total_allocations else 0,
        .live_instances = if (slab) |sl| sl.stats().currently_allocated else 0,
        .bridge_entries = instance_bridge.entryCount(),
    };
}

/// 0.16 removed `std.process.argsAlloc` - arguments are no longer process-global,
/// they arrive on `std.process.Init`, which also carries the gpa and a
/// process-lifetime arena.
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    const cycles: usize = if (args.len > 1)
        std.fmt.parseInt(usize, args[1], 10) catch 10_000
    else
        10_000;
    const every: usize = if (args.len > 2)
        std.fmt.parseInt(usize, args[2], 10) catch 1_000
    else
        1_000;

    // `--gc` forces a full V8 collection before each reading. This is the
    // decomposition experiment, not a mode of the benchmark: if RSS still climbs
    // with V8 collecting, the retained bytes are Zig-side - the arena that never
    // resets, and the registries keyed on recycled addresses - and no amount of JS
    // heap work will reach them. If it flattens, the retention is V8's.
    var force_gc = false;
    for (args[1..]) |a| {
        if (std.mem.eql(u8, a, "--gc")) force_gc = true;
    }

    if (memory.residentBytes() == null) {
        std.debug.print("resident memory is not available on this platform; nothing to measure\n", .{});
        return error.ResidentSizeUnavailable;
    }

    // `Browser.deinit` destroys the Browser itself (Browser.zig:352), so the caller
    // must NOT also destroy it. The REPL's extra `destroy` is a latent double free
    // that its own exit path happens not to reach.
    const browser = try Browser.init(allocator, .{});
    defer browser.deinit();
    try browser.navigate("about:blank", .window);

    const isolate = browser.isolate orelse return error.NoIsolate;
    const context = (browser.current_context orelse return error.NoContext).v8_context orelse
        return error.NoV8Context;

    var samples: std.ArrayListUnmanaged(Sample) = .empty;
    defer samples.deinit(allocator);

    // Baseline AFTER browser startup: the snapshot, the templates and V8's own heap
    // are a fixed cost, and counting them as cycle-zero growth would hide a real
    // leak behind a large constant.
    try samples.append(allocator, takeSample(0));

    var done: usize = 0;
    while (done < cycles) {
        const batch = @min(every, cycles - done);

        // The element is created and dropped inside the loop, so nothing in JS
        // holds it afterwards. `void` on the createElement call keeps V8 from
        // retaining a completion value for the statement.
        //
        // A fresh script per batch rather than one long-running script: a single
        // 10,000-iteration script keeps one JS stack frame alive throughout, which
        // is itself a root, and would confound "did the state come back".
        const source = try std.fmt.allocPrint(
            allocator,
            "for (let i = 0; i < {d}; i++) {{ void document.createElement('div'); }}",
            .{batch},
        );
        defer allocator.free(source);

        try runScript(isolate, context, source);

        if (force_gc) {
            // Twice: one pass can leave objects that only become unreachable once
            // the first pass has cleared what referenced them, and a single
            // collection would under-report what V8 can actually reclaim.
            v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
            v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
            v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
        }

        done += batch;
        try samples.append(allocator, takeSample(done));
    }

    report(samples.items, force_gc);
}

fn runScript(isolate: *v8.ffi.Isolate, context: *v8.ffi.Context, source: []const u8) !void {
    const handle_scope = v8.ffi.v8_HandleScope_New(isolate) orelse return error.HandleScopeFailed;
    defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

    v8.ffi.v8_Context_Enter(context);
    defer v8.ffi.v8_Context_Exit(context);

    const source_str = v8.ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse
        return error.StringCreationFailed;

    const script = v8.ffi.v8_Script_Compile(context, source_str) orelse return error.CompileFailed;
    _ = v8.ffi.v8_Script_Run(context, script) orelse return error.RunFailed;

    // Drain microtasks so anything the cycle queued has finished before the next
    // reading; otherwise the sample catches work in flight and the series is noise.
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
}

fn report(samples: []const Sample, gc_was_forced: bool) void {
    std.debug.print("\n=== Phase 6: createElement + discard{s} ===\n\n", .{
        if (gc_was_forced) " (V8 GC forced)" else "",
    });
    std.debug.print("{s:>8}  {s:>11}  {s:>13}  {s:>12}  {s:>11}  {s:>10}\n", .{
        "cycle",   "resident MB", "since start",
        "B/cycle", "arena MB",    "live inst",
    });

    const first = samples[0].resident;

    var prev: ?Sample = null;
    for (samples) |s| {
        const res = s.resident orelse {
            std.debug.print("{d:>10}  {s:>12}\n", .{ s.cycle, "unmeasured" });
            continue;
        };

        const mb = @as(f64, @floatFromInt(res)) / (1024.0 * 1024.0);

        if (first) |f| {
            const growth = @as(f64, @floatFromInt(@as(i128, @intCast(res)) - @as(i128, @intCast(f)))) /
                (1024.0 * 1024.0);

            // Slope over the last interval only. An average from cycle 0 would be
            // dragged down by startup and make any leak look like it is shrinking.
            var slope: f64 = 0;
            if (prev) |p| {
                if (p.resident) |pr| {
                    const d_cycles = s.cycle - p.cycle;
                    if (d_cycles > 0) {
                        slope = @as(f64, @floatFromInt(@as(i128, @intCast(res)) - @as(i128, @intCast(pr)))) /
                            @as(f64, @floatFromInt(d_cycles));
                    }
                }
            }
            const arena_mb = @as(f64, @floatFromInt(s.arena_bytes)) / (1024.0 * 1024.0);
            std.debug.print("{d:>8}  {d:>11.1}  {d:>13.1}  {d:>12.1}  {d:>11.1}  {d:>10}\n", .{
                s.cycle, mb, growth, slope, arena_mb, s.live_instances,
            });
        } else {
            std.debug.print("{d:>8}  {d:>11.1}\n", .{ s.cycle, mb });
        }

        prev = s;
    }

    const last = samples[samples.len - 1];
    if (first != null and last.resident != null and last.cycle > 0) {
        const total = @as(i128, @intCast(last.resident.?)) - @as(i128, @intCast(first.?));
        const per = @divTrunc(total, @as(i128, @intCast(last.cycle)));
        std.debug.print(
            "\n{d} cycles: {d:.1} MB total, {d} bytes per element\n",
            .{ last.cycle, @as(f64, @floatFromInt(total)) / (1024.0 * 1024.0), per },
        );
        // The decomposition. Arena growth is the part a state GC can reclaim; the
        // remainder is V8 heap, registries and allocator overhead, and needs a
        // different fix. Reporting only the total invites attributing all of it to
        // whichever cause is currently being worked on.
        const arena_delta = @as(i128, @intCast(last.arena_bytes)) - @as(i128, @intCast(samples[0].arena_bytes));
        const arena_per = @divTrunc(arena_delta, @as(i128, @intCast(last.cycle)));
        std.debug.print(
            "  of which state arena: {d:.1} MB, {d} bytes per element ({d}% of RSS growth)\n",
            .{
                @as(f64, @floatFromInt(arena_delta)) / (1024.0 * 1024.0),
                arena_per,
                if (total > 0) @divTrunc(arena_delta * 100, total) else 0,
            },
        );
        std.debug.print(
            "  instances still live: {d} (slab recycles, so a rising count means\n" ++
                "    instances are never deinit'd - a different bug from state retention)\n",
            .{last.live_instances},
        );
        std.debug.print(
            "  instance->NodeBase entries: {d} (keyed on a RECYCLED address, so a\n" ++
                "    stale entry is inherited by the next object there - M13)\n",
            .{last.bridge_entries},
        );
        std.debug.print(
            "\nPhase 6 exit wants this flat. Non-zero bytes/element means discarded\n" ++
                "state is retained - see M1: ArenaAllocator.reset() never runs in production.\n",
            .{},
        );
    }
}
