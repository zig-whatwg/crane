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

const log = std.log.scoped(.gc_bench);

pub const std_options: std.Options = .{
    // The browser logs heavily at debug and info; this tool's output is a table and
    // must stay readable. Warnings and errors still come through.
    .log_level = .warn,
};

/// One resident-memory reading at a known cycle count.
const Sample = struct {
    cycle: usize,
    resident: ?usize,
};

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
    try samples.append(allocator, .{ .cycle = 0, .resident = memory.residentBytes() });

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

        done += batch;
        try samples.append(allocator, .{ .cycle = done, .resident = memory.residentBytes() });
    }

    report(samples.items);
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

fn report(samples: []const Sample) void {
    std.debug.print("\n=== Phase 6: createElement + discard ===\n\n", .{});
    std.debug.print("{s:>10}  {s:>12}  {s:>14}  {s:>14}\n", .{ "cycle", "resident MB", "since start MB", "bytes/cycle" });

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
            std.debug.print("{d:>10}  {d:>12.1}  {d:>14.1}  {d:>14.1}\n", .{ s.cycle, mb, growth, slope });
        } else {
            std.debug.print("{d:>10}  {d:>12.1}\n", .{ s.cycle, mb });
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
        std.debug.print(
            "\nPhase 6 exit wants this flat. Non-zero bytes/element means discarded\n" ++
                "state is retained - see M1: ArenaAllocator.reset() never runs in production.\n",
            .{},
        );
    }
}
