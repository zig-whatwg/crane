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
const builtin = @import("builtin");
const v8 = @import("v8");
const memory = @import("memory");
const Browser = @import("browser").Browser;
const runtime = @import("runtime");
const instance_bridge = @import("dom").instance_bridge;
const context_manager = v8.context_manager;
const WrapperCache = v8.wrapper_cache_mod.WrapperCache;

const log = std.log.scoped(.gc_bench);

pub const std_options: std.Options = .{
    // The browser logs heavily at debug and info; this tool's output is a table and
    // must stay readable. Warnings and errors still come through.
    .log_level = .warn,
};

/// Wraps an allocator and tracks bytes currently outstanding.
///
/// The arena and the slab report themselves; the general-purpose allocator does
/// not, and after the control run that is where the unexplained majority has to
/// be. Counting it turns "3,373 bytes unaccounted" into a number that can be
/// attributed.
///
/// Outstanding, not cumulative: the question is what is still held, and a
/// cumulative figure would climb identically whether or not anything was freed.
const CountingAllocator = struct {
    child: std.mem.Allocator,
    outstanding: usize = 0,
    peak: usize = 0,

    /// Optional per-allocation bookkeeping, enabled by `--profile`.
    ///
    /// Totals say how much is outstanding; they cannot say WHERE it was allocated,
    /// and a leak-checking allocator is no help here because everything is freed in
    /// bulk at process exit - the memory is retained during the run, not lost. This
    /// records the return address of each live allocation so the sites holding the
    /// most bytes MID-RUN can be named.
    profile: bool = false,
    /// pointer -> {len, return address}
    live: ?std.AutoHashMapUnmanaged(usize, Live) = null,
    tracking_allocator: std.mem.Allocator = undefined,

    const Live = struct { len: usize, ra: usize };

    /// Bytes and count outstanding per return address.
    const SiteTotal = struct { ra: usize, bytes: usize, count: usize };

    fn track(self: *CountingAllocator, ptr: [*]u8, len: usize, ra: usize) void {
        if (!self.profile) return;
        const map = &(self.live orelse return);
        // Bookkeeping failure must not perturb the measurement it is measuring, so
        // an OOM here drops the record rather than propagating.
        map.put(self.tracking_allocator, @intFromPtr(ptr), .{ .len = len, .ra = ra }) catch {};
    }

    fn untrack(self: *CountingAllocator, ptr: [*]u8) void {
        if (!self.profile) return;
        const map = &(self.live orelse return);
        _ = map.remove(@intFromPtr(ptr));
    }

    /// The sites holding the most outstanding bytes, largest first.
    fn topSites(self: *CountingAllocator, gpa: std.mem.Allocator, limit: usize) ![]SiteTotal {
        const map = &(self.live orelse return &.{});

        var by_site: std.AutoHashMapUnmanaged(usize, SiteTotal) = .empty;
        defer by_site.deinit(gpa);

        var it = map.valueIterator();
        while (it.next()) |v| {
            const gop = try by_site.getOrPut(gpa, v.ra);
            if (!gop.found_existing) gop.value_ptr.* = .{ .ra = v.ra, .bytes = 0, .count = 0 };
            gop.value_ptr.bytes += v.len;
            gop.value_ptr.count += 1;
        }

        var all: std.ArrayListUnmanaged(SiteTotal) = .empty;
        defer all.deinit(gpa);
        var sit = by_site.valueIterator();
        while (sit.next()) |v| try all.append(gpa, v.*);

        std.mem.sort(SiteTotal, all.items, {}, struct {
            fn lt(_: void, a: SiteTotal, b: SiteTotal) bool {
                return a.bytes > b.bytes;
            }
        }.lt);

        return gpa.dupe(SiteTotal, all.items[0..@min(limit, all.items.len)]);
    }

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn note(self: *CountingAllocator, delta: isize) void {
        if (delta >= 0) {
            self.outstanding +|= @intCast(delta);
            if (self.outstanding > self.peak) self.peak = self.outstanding;
        } else {
            self.outstanding -|= @intCast(-delta);
        }
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const p = self.child.rawAlloc(len, alignment, ra) orelse return null;
        self.note(@intCast(len));
        self.track(p, len, ra);
        return p;
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        if (!self.child.rawResize(buf, alignment, new_len, ra)) return false;
        self.note(@as(isize, @intCast(new_len)) - @as(isize, @intCast(buf.len)));
        return true;
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const p = self.child.rawRemap(buf, alignment, new_len, ra) orelse return null;
        self.note(@as(isize, @intCast(new_len)) - @as(isize, @intCast(buf.len)));
        self.untrack(buf.ptr);
        self.track(p, new_len, ra);
        return p;
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(buf, alignment, ra);
        self.note(-@as(isize, @intCast(buf.len)));
        self.untrack(buf.ptr);
    }
};

var counting: CountingAllocator = undefined;

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
    /// Allocations satisfied from a free list. Zero while a discard loop runs means
    /// states are not being returned at all.
    arena_recycled: usize,
    /// Instance handles that were allocated and never returned. The slab recycles,
    /// so this rising means instances are not being deinit'd at all - a different
    /// bug from "state is not freed".
    live_instances: usize,
    /// Entries in the instance -> NodeBase map. Keyed on a recycled address, so
    /// this rising is both a leak and a type-confusion hazard (M13).
    bridge_entries: usize,
    /// Bytes outstanding in the general-purpose allocator - everything that is
    /// neither arena state nor a slab slot.
    gpa_outstanding: usize,
    /// Entries in the V8 wrapper cache. Each holds a CacheEntry plus a
    /// Global<Object>, and its weak callback is what frees the instance - so if
    /// this is not shrinking, nothing downstream of it can.
    wrapper_entries: usize,
    /// V8's own heap accounting. Distinguishes objects genuinely retained (`used`
    /// climbs) from V8 simply not handing pages back (`used` flat while RSS climbs).
    v8_used: usize,
    v8_total: usize,
    /// Cumulative Global<T> creations. Each is a C++ allocation plus a slot in
    /// V8's global handle table, which `used_heap_size` does not count.
    live_strings: i64,
    /// Global<String> handles LIVE right now (created minus disposed). Unlike the
    /// cumulative count, this shows whether a family is actually leaking: flat
    /// means every string created per element is also released.
    live_string_globals: i64,
    /// Live Global<Context> handles - the family with the highest creation rate.
    live_context_globals: i64,
    /// Live Global<Object> handles.
    live_object_globals: i64,
    /// Bytes held by malloc - the C++ heap. Distinguishes a missing `delete` from
    /// V8's page allocator not returning memory.
    malloc_in_use: usize,
};

/// The isolate to ask for heap statistics, set once the browser exists.
var heap_isolate: ?*v8.ffi.Isolate = null;

/// How far this image was slid by ASLR, so a recorded return address can be turned
/// into the static address `atos` understands.
///
/// Without this the addresses printed below resolve to whatever symbol happens to
/// sit at that offset in an unslid image - which is not an approximation, it is a
/// different function entirely, and it produced two confidently wrong attributions
/// before this was added.
extern fn _dyld_get_image_vmaddr_slide(image_index: u32) usize;

fn imageSlide() usize {
    return if (builtin.os.tag == .macos) _dyld_get_image_vmaddr_slide(0) else 0;
}

/// The wrapper cache lives on the runtime Context, not globally.
var wrapper_cache_ref: ?*WrapperCache = null;

fn takeSample(cycle: usize) Sample {
    const arena = runtime.ArenaAllocator.tryGet() catch null;
    const slab = runtime.SlabAllocator.tryGet() catch null;
    return .{
        .cycle = cycle,
        .resident = memory.residentBytes(),
        // bytes_in_use, not total_bytes_allocated: the question is how much is
        // HELD. The cumulative figure rises identically whether or not anything is
        // freed, so it reported the arena as leaking even after recycling landed.
        .arena_bytes = if (arena) |a| a.stats().bytes_in_use else 0,
        .arena_allocations = if (arena) |a| a.stats().total_allocations else 0,
        .arena_recycled = if (arena) |a| a.stats().total_recycled else 0,
        .live_instances = if (slab) |sl| sl.stats().currently_allocated else 0,
        .bridge_entries = instance_bridge.entryCount(),
        .gpa_outstanding = counting.outstanding,
        .wrapper_entries = if (wrapper_cache_ref) |wc| wc.size() else 0,
        .v8_used = blk: {
            const iso = heap_isolate orelse break :blk 0;
            var used: usize = 0;
            v8.ffi.v8_Isolate_GetHeapUsage(iso, &used, null, null);
            break :blk used;
        },
        .live_strings = v8.ffi.v8_Debug_CreatedGlobals(),
        .live_string_globals = v8.ffi.v8_Debug_LiveStringGlobals(),
        .live_context_globals = v8.ffi.v8_Debug_LiveContextGlobals(),
        .live_object_globals = v8.ffi.v8_Debug_LiveObjectGlobals(),
        .malloc_in_use = memory.mallocInUseBytes() orelse 0,
        .v8_total = blk: {
            const iso = heap_isolate orelse break :blk 0;
            var total: usize = 0;
            v8.ffi.v8_Isolate_GetHeapUsage(iso, null, &total, null);
            break :blk total;
        },
    };
}

/// 0.16 removed `std.process.argsAlloc` - arguments are no longer process-global,
/// they arrive on `std.process.Init`, which also carries the gpa and a
/// process-lifetime arena.
pub fn main(init: std.process.Init) !void {
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
    // `--control` allocates a plain JS object instead of an Element, with everything
    // else identical. It answers the question any RSS growth figure has to survive:
    // how much of it is V8's heap simply not returning pages, which is normal engine
    // behaviour and not a leak? Whatever the control retains is the floor, and only
    // the excess above it is Crane's to fix.
    var control = false;
    // `--profile` names the allocation sites holding the most bytes MID-RUN. A
    // leak-checking allocator cannot do this: everything here is freed in bulk at
    // process exit, so nothing is lost - it is retained, which no leak checker
    // reports.
    var profile = false;
    for (args[1..]) |a| {
        if (std.mem.eql(u8, a, "--gc")) force_gc = true;
        if (std.mem.eql(u8, a, "--control")) control = true;
        if (std.mem.eql(u8, a, "--profile")) profile = true;
    }

    var debug_gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_gpa.deinit();

    counting = .{ .child = debug_gpa.allocator() };
    if (profile) {
        counting.profile = true;
        counting.live = .empty;
        // Bookkeeping uses the RAW allocator, never the counted one: recording an
        // allocation must not itself register as an allocation.
        counting.tracking_allocator = debug_gpa.allocator();
    }
    defer if (counting.live) |*m| m.deinit(counting.tracking_allocator);
    const allocator = counting.allocator();

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

    heap_isolate = isolate;

    if (context_manager.get(context)) |runtime_ctx| {
        if (runtime_ctx.getV8WrapperCacheStorage()) |storage| {
            wrapper_cache_ref = @ptrCast(@alignCast(storage));
        }
    }

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
        const body = if (control)
            // Shaped to cost V8 about what a wrapper does - an object with a couple
            // of properties - while touching no DOM state at all.
            "void ({ a: i, b: 'x' });"
        else
            "void document.createElement('div');";

        const source = try std.fmt.allocPrint(
            allocator,
            "for (let i = 0; i < {d}; i++) {{ {s} }}",
            .{ batch, body },
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

    report(samples.items, force_gc, control);

    {
        const names = [_][]const u8{
            "FunctionCallbackInfo_This", "PropertyCallbackInfo_This",
            "Context_Global",            "GetGlobalPrototype",
            "FunctionTemplate_GetProto", "ObjectTemplate_NewInstance",
        };
        const cycles_run = samples.items[samples.items.len - 1].cycle;
        std.debug.print("\nGlobal<Object> creations per element, by entry point:\n", .{});
        for (names, 0..) |n, i| {
            const c = v8.ffi.v8_Debug_ObjSrc(@intCast(i));
            if (c <= 0) continue;
            std.debug.print("  {s:<28} {d:>9}  ({d:.2}/elem)\n", .{
                n, c, @as(f64, @floatFromInt(c)) / @as(f64, @floatFromInt(@max(cycles_run, 1))),
            });
        }
    }

    {
        // Where the leaked Global<T> handles are created. Counts are cumulative
        // creations, not live ones, but on a create-and-discard loop the site that
        // dominates creation is where the leak is.
        const Site = struct { pc: usize, count: i64 };
        var sites: std.ArrayListUnmanaged(Site) = .empty;
        defer sites.deinit(allocator);

        var i: c_int = 0;
        while (i < 512) : (i += 1) {
            var pc: usize = 0;
            var count: i64 = 0;
            if (!v8.ffi.v8_Debug_GlobalSite(i, &pc, &count)) break;
            if (pc != 0 and count > 0) try sites.append(allocator, .{ .pc = pc, .count = count });
        }
        std.mem.sort(Site, sites.items, {}, struct {
            fn lt(_: void, a: Site, b: Site) bool {
                return a.count > b.count;
            }
        }.lt);

        const shown = @min(sites.items.len, 10);
        std.debug.print("\nGlobal<T> creations by site (top {d} of {d}):\n", .{ shown, sites.items.len });
        for (sites.items[0..shown]) |site| {
            std.debug.print("  {d:>12} creations  at 0x{x}\n", .{ site.count, site.pc -| imageSlide() });
        }
        std.debug.print("\nResolve with:  atos -o zig-out/bin/gc_bench <address>\n", .{});
    }

    if (profile) {
        const sites = try counting.topSites(allocator, 12);
        defer allocator.free(sites);
        std.debug.print("\nOutstanding bytes by allocation site (top {d}):\n", .{sites.len});
        for (sites) |site| {
            std.debug.print("  {d:>10} bytes  {d:>7} live  at 0x{x}\n", .{
                site.bytes,
                site.count,
                site.ra -| imageSlide(),
            });
        }
        std.debug.print(
            "\nResolve with:  atos -o zig-out/bin/gc_bench <address>\n",
            .{},
        );
    }
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

fn report(samples: []const Sample, gc_was_forced: bool, was_control: bool) void {
    std.debug.print("\n=== Phase 6: {s}{s} ===\n\n", .{
        if (was_control) "plain JS object (CONTROL)" else "createElement + discard",
        if (gc_was_forced) ", V8 GC forced" else "",
    });
    std.debug.print("{s:>8}  {s:>11}  {s:>13}  {s:>12}  {s:>11}  {s:>10}\n", .{
        "cycle",   "resident MB", "since start",
        "B/cycle", "malloc MB",   "live Object<>",
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
            std.debug.print("{d:>8}  {d:>11.1}  {d:>13.1}  {d:>12.1}  {d:>11.1}  {d:>10.1}\n", .{
                s.cycle,
                mb,
                growth,
                slope,
                @as(f64, @floatFromInt(s.malloc_in_use)) / (1024.0 * 1024.0),
                @as(f64, @floatFromInt(s.live_object_globals)),
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
            "  state arena held: {d:.1} MB, {d} bytes per element ({d}% of RSS growth)\n",
            .{
                @as(f64, @floatFromInt(arena_delta)) / (1024.0 * 1024.0),
                arena_per,
                if (total > 0) @divTrunc(arena_delta * 100, total) else 0,
            },
        );
        // NOT additive with the arena line above. The arena takes its chunks FROM
        // the general allocator, so its bytes are counted in both - profiling showed
        // the largest outstanding site is the arena's own doubling chunk list
        // (~30 MB of chunks holding the 21 MB the arena reports as requested).
        // Reporting these as two shares summed to more than the total.
        const gpa_delta = @as(i128, @intCast(last.gpa_outstanding)) - @as(i128, @intCast(samples[0].gpa_outstanding));
        std.debug.print(
            "  general allocator, INCLUDING the arena's chunks: {d:.1} MB, {d} bytes per element\n",
            .{
                @as(f64, @floatFromInt(gpa_delta)) / (1024.0 * 1024.0),
                @divTrunc(gpa_delta, @as(i128, @intCast(last.cycle))),
            },
        );
        std.debug.print(
            "  so {d:.1} MB of the {d:.1} MB is Zig-side; the rest is V8 heap and overhead\n",
            .{
                @as(f64, @floatFromInt(gpa_delta)) / (1024.0 * 1024.0),
                @as(f64, @floatFromInt(total)) / (1024.0 * 1024.0),
            },
        );
        std.debug.print(
            "  states recycled: {d} of {d} arena allocations\n",
            .{ last.arena_recycled, last.arena_allocations },
        );
        std.debug.print(
            "  wrapper cache entries: {d} (each is a CacheEntry plus a Global<Object>,\n" ++
                "    and its weak callback is what frees the instance)\n",
            .{last.wrapper_entries},
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
