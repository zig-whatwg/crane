//! Lane leak3, item 2: a listener added with a `signal` costs a small record
//! for as long as the LISTENER is there, not a page for as long as the signal
//! is.
//!
//! DOM 2.7 "add an event listener" step 6 gives the signal abort steps that
//! remove the listener. EventTarget kept those steps' record on
//! std.heap.page_allocator - one mapped page per listener, 16 KiB on macOS,
//! 4 KiB and a mapping on Linux - and freed it only when the signal aborted
//! or was collected (allocator-hardening design 10.1 item 3): a listener
//! removed any other way left its record, and its entry in the signal's
//! abort algorithms, until then. One long-lived AbortController over a
//! component tree's listeners - the shape that tears listeners down with one
//! controller - kept a page per listener ever added.
//!
//! Now the record is the Browser allocator's, and it leaves the signal with
//! its listener - however the listener goes (Gecko's ListenerSignalFollower
//! unfollows its signal when its listener is removed: dom/events/
//! EventListenerManager.cpp, reproduced, not copied):
//!
//! - added and removed with removeEventListener, a `once` listener that
//!   fired, a target collected while its signal lives: the Browser
//!   allocator's live bytes stay flat over thousands, and the signal's abort
//!   algorithms with them;
//! - kept until the signal aborts: no page each - the process's minor page
//!   faults (every build) and its footprint (not under ThreadSanitizer),
//!   against the same listeners added with no signal;
//! - removed by an earlier abort algorithm while the signal's own abort walk
//!   holds the record: the walk still runs it, once, and it is freed once
//!   (std.testing.allocator under every Browser here).

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

/// Live bytes through a Browser's allocator (as lis1_listener_storage_test).
/// Atomic: a Browser's threads share its allocator.
const CountingAllocator = struct {
    child: std.mem.Allocator,
    live: std.atomic.Value(isize) = .init(0),

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn note(self: *CountingAllocator, old_len: usize, new_len: usize) void {
        _ = self.live.fetchAdd(@as(isize, @intCast(new_len)) - @as(isize, @intCast(old_len)), .monotonic);
    }
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child.rawAlloc(len, alignment, ra) orelse return null;
        self.note(0, len);
        return result;
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        if (!self.child.rawResize(memory, alignment, new_len, ra)) return false;
        self.note(memory.len, new_len);
        return true;
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child.rawRemap(memory, alignment, new_len, ra) orelse return null;
        self.note(memory.len, new_len);
        return result;
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(memory, alignment, ra);
        self.note(memory.len, 0);
    }
};

const Page = struct {
    counting: *CountingAllocator,
    browser: *browser_mod.Browser,

    fn open(counting: *CountingAllocator) !Page {
        const browser = try browser_mod.Browser.init(counting.allocator(), .{ .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        // The initial about:blank's realm goes now, not inside a count.
        for (0..3) |_| {
            try page.runScript("TestUtils.gc(); TestUtils.gc();");
            _ = try browser.runEventLoopBlocking(20);
        }
        return .{ .counting = counting, .browser = browser };
    }

    fn close(self: Page) void {
        self.browser.deinit();
    }

    fn run(self: Page, source: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        page.runScript(source) catch |err| {
            std.debug.print("script failed: {s}\n", .{source});
            return err;
        };
    }

    fn evaluate(self: Page, source: []const u8) ![]u8 {
        const page = self.browser.current_context orelse return error.NoPage;
        return page.evaluateScriptToString(source, testing.allocator);
    }

    /// The platform object `source` evaluates to. Script keeps it alive (a
    /// global names it); the completion's own hold is released here.
    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        const page = self.browser.current_context orelse return error.NoPage;
        const realm = page.realm orelse return error.NoPage;
        const held = try page.evaluateScript(source);
        defer held.release();
        return engine.convertToPlatformObject(realm, held.value) orelse error.NotAPlatformObject;
    }

    fn collect(self: Page) !void {
        try self.run("TestUtils.gc(); TestUtils.gc();");
        _ = try self.browser.runEventLoopBlocking(20);
        try self.run("TestUtils.gc();");
    }

    fn live(self: Page) isize {
        return self.counting.live.load(.monotonic);
    }

    fn expectNoFailure(self: Page) !void {
        const failed = try self.evaluate("String(globalThis.failed || '')");
        defer testing.allocator.free(failed);
        if (failed.len != 0) {
            std.debug.print("page check failed: {s}\n", .{failed});
            return error.PageCheckFailed;
        }
    }
};

/// What a step may leave in the Browser allocator over thousands of
/// listeners whose records must all be gone: never a record or an abort
/// algorithm per listener (a kept algorithm alone is 24 B: the signal's list
/// grows past this within the second run of every step below).
const flat_slack: isize = 8 * 1024;

/// Run `script` twice in `page`, on a signal made for the step, and require
/// the second run to leave the Browser allocator's live bytes where the
/// first left them: the first settles what is made once (a list's block, the
/// arena's and the slab's chunks), the second shows what each listener
/// keeps - its record, and its entry in the signal's abort algorithms.
fn expectFlat(page: Page, what: []const u8, script: []const u8) !void {
    try page.run("globalThis.controller = new AbortController(); 0");
    try page.run(script);
    try page.collect();
    const before = page.live();
    try page.run(script);
    try page.collect();
    const after = page.live();
    std.debug.print("leak3: {s}: Browser allocator {d} -> {d} ({d} B)\n", .{ what, before, after, after - before });
    try page.expectNoFailure();
    if (after - before > flat_slack) return error.SignalRecordsKept;
}

fn removedListenersLeaveTheirSignal() !void {
    var counting: CountingAllocator = .{ .child = testing.allocator };
    const page = try Page.open(&counting);
    defer page.close();
    // A controller lives for each step's two runs, as a component
    // framework's lives for the page.
    try page.run(
        \\globalThis.target = new EventTarget();
        \\globalThis.calls = 0;
        \\0
    );

    // removeEventListener: 4,000 listeners added with the signal and removed.
    try expectFlat(page, "removeEventListener",
        \\for (let i = 0; i < 4000; ++i) {
        \\  const f = () => { ++calls; };
        \\  target.addEventListener('x', f, { signal: controller.signal });
        \\  target.removeEventListener('x', f);
        \\}
        \\0
    );

    // A `once` listener that fired: inner invoke removed it.
    try expectFlat(page, "once",
        \\calls = 0;
        \\for (let i = 0; i < 3000; ++i) {
        \\  target.addEventListener('y', () => { ++calls; }, { signal: controller.signal, once: true });
        \\  target.dispatchEvent(new Event('y'));
        \\  target.dispatchEvent(new Event('y'));
        \\}
        \\if (calls !== 3000) globalThis.failed = 'once listeners ran ' + calls + ' times, want 3000';
        \\0
    );

    // A target collected while the signal lives: its teardown releases its
    // listeners, and their records leave the signal with them. A plain
    // EventTarget (its own state) and an element (a node's list).
    try expectFlat(page, "collected targets",
        \\(() => {
        \\  for (let i = 0; i < 2000; ++i) {
        \\    new EventTarget().addEventListener('z', () => {}, { signal: controller.signal });
        \\    document.createElement('div').addEventListener('z', () => {}, { signal: controller.signal });
        \\  }
        \\})();
        \\0
    );

    // The signal still works for what it still holds: a listener added now
    // goes when it aborts.
    try page.run(
        \\calls = 0;
        \\target.addEventListener('w', () => { ++calls; }, { signal: controller.signal });
        \\controller.abort();
        \\target.dispatchEvent(new Event('w'));
        \\if (calls !== 0) globalThis.failed = 'an aborted signal left its listener: ' + calls;
        \\0
    );
    try page.expectNoFailure();
}

test "a listener removed, fired once or collected with its target takes its abort steps off its signal" {
    try helpers.onFreshThread(removedListenersLeaveTheirSignal);
}

const MiB: usize = 1024 * 1024;

/// The memory the OS charges this process for: darwin's phys_footprint,
/// Linux's resident set (tests/v8/ab1_array_buffer_footprint_test.zig).
fn footprint() usize {
    if (comptime builtin.os.tag.isDarwin()) {
        var info: std.c.task_vm_info_data_t = undefined;
        var count: std.c.mach_msg_type_number_t = std.c.TASK.VM.INFO_COUNT;
        if (std.c.task_info(std.c.mach_task_self(), std.c.TASK.VM.INFO, @ptrCast(&info), &count) != 0) return 0;
        return @intCast(info.phys_footprint);
    }
    var buf: [128]u8 = undefined;
    const fd = std.c.open("/proc/self/statm", .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
    if (fd < 0) return 0;
    defer _ = std.c.close(fd);
    const n = std.c.read(fd, &buf, buf.len);
    if (n <= 0) return 0;
    var it = std.mem.tokenizeScalar(u8, buf[0..@intCast(n)], ' ');
    _ = it.next();
    const pages = std.fmt.parseInt(usize, it.next() orelse return 0, 10) catch return 0;
    return pages * std.heap.pageSize();
}

/// The process's memory mappings: Linux's /proc/self/maps lines (null
/// elsewhere). Past vm.max_map_count (65,530 by default) every mmap fails.
fn mappings() ?usize {
    if (comptime builtin.os.tag != .linux) return null;
    const fd = std.c.open("/proc/self/maps", .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
    if (fd < 0) return null;
    defer _ = std.c.close(fd);
    var lines: usize = 0;
    var buf: [64 * 1024]u8 = undefined;
    while (true) {
        const n = std.c.read(fd, &buf, buf.len);
        if (n <= 0) break;
        lines += std.mem.count(u8, buf[0..@intCast(n)], "\n");
    }
    return lines;
}

/// The process's minor page faults so far: each first touch of a page the
/// process has not touched yet (getrusage's ru_minflt, every thread). A
/// record on its own page is one each; records sharing an allocator's pages
/// are one per page of them. Exact where the footprint is not: a
/// ThreadSanitizer build commits its shadow and metadata memory in steps of
/// megabytes, but faults only on the pages touched.
fn minorFaults() usize {
    const usage = std.posix.getrusage(std.posix.rusage.SELF);
    return @intCast(usage.minflt);
}

/// What one kept batch cost.
const Cost = struct { bytes: usize, faults: usize, maps: ?usize };

/// 4,000 listeners added with `options`, ten to a fresh target, kept: the
/// footprint's rise, the minor faults', and the mappings', over the adding
/// alone. Ten a target: "add an event listener" step 5 compares each with
/// every listener its target has, so one target of 4,000 would time the
/// comparisons.
fn keptListenersCost(page: Page, options: []const u8) !Cost {
    const before = footprint();
    const faults_before = minorFaults();
    const maps_before = mappings();
    var script_buf: [512]u8 = undefined;
    const script = try std.fmt.bufPrint(&script_buf,
        \\(() => {{
        \\  let t = null;
        \\  for (let i = 0; i < 4000; ++i) {{
        \\    if (i % 10 === 0) {{ t = new EventTarget(); kept.push(t); }}
        \\    t.addEventListener('k', () => {{ ++calls; }}, {s});
        \\  }}
        \\}})();
        \\0
    , .{options});
    try page.run(script);
    const faults_after = minorFaults();
    const after = footprint();
    const maps_after = mappings();
    return .{
        .bytes = after -| before,
        .faults = faults_after -| faults_before,
        .maps = if (maps_before) |b| (maps_after orelse b) -| b else null,
    };
}

/// Whether the footprint can be read for this: not under ThreadSanitizer,
/// whose shadow and metadata mappings move the process footprint in
/// multi-megabyte steps (seen: +13,620 KiB on a 4,000-listener batch that
/// allocated well under 1 MiB, and +0 KiB on its control); the page faults
/// are asserted in every build.
const footprint_is_measured = !builtin.sanitize_thread;

/// The extra first-touch faults 4,000 kept signal listeners may cost over
/// their control batch: half of one per listener. Measured on Linux
/// (server1): a page each (the bug) +4,042, a record each +470. Under
/// ThreadSanitizer every heap page touched also faults its shadow - a page
/// each +12,406, a record each +1,628 to +1,805 - so the limit there is three
/// halves of one per listener.
const fault_limit: usize = if (builtin.sanitize_thread) 6000 else 2000;

fn keptListenersCostNoPageEach() !void {
    var counting: CountingAllocator = .{ .child = testing.allocator };
    const page = try Page.open(&counting);
    defer page.close();
    try page.run(
        \\globalThis.controller = new AbortController();
        \\globalThis.kept = [];
        \\globalThis.calls = 0;
        \\0
    );
    // A first batch of each settles the engine's young generation and the
    // lists' growth; the second of each is measured.
    _ = try keptListenersCost(page, "{ passive: false }");
    _ = try keptListenersCost(page, "{ signal: controller.signal }");
    const plain = try keptListenersCost(page, "{ passive: false }");
    const signal = try keptListenersCost(page, "{ signal: controller.signal }");
    const extra = signal.bytes -| plain.bytes;
    const extra_faults = signal.faults -| plain.faults;
    std.debug.print("leak3: 4,000 kept listeners: footprint +{d} KiB with no signal, +{d} KiB with one; minor faults +{d} / +{d}; mappings +{?d} / +{?d}\n", .{ plain.bytes / 1024, signal.bytes / 1024, plain.faults, signal.faults, plain.maps, signal.maps });
    // A page each is a first-touch fault each: 4,000 or more here. A record,
    // its index entry and its abort algorithm, about 100 B each, share an
    // allocator's pages: about 100 pages, and the lists' growth.
    if (extra_faults > fault_limit) return error.PagePerSignalListener;
    // And 16 MiB (Linux) to 64 MiB (macOS) of footprint, against 0.4 MiB.
    if (footprint_is_measured and extra > 4 * MiB) return error.FootprintPerSignalListener;
    // The mappings are printed, never asserted: Linux merges adjacent
    // anonymous mappings, so a page per listener added +11 to +120 of them
    // over 4,000 (lane leak3's red runs), not 4,000.

    // Abort: every kept signal listener goes, and its record with it (the
    // testing allocator under the Browser finds any left at its end).
    try page.run(
        \\controller.abort();
        \\for (const t of kept) t.dispatchEvent(new Event('k'));
        \\if (calls !== 8000) globalThis.failed = 'after abort ' + calls + ' calls, want 8000 (the no-signal listeners)';
        \\0
    );
    try page.expectNoFailure();
}

test "listeners kept on a signal until it aborts cost a record each, not a page" {
    try helpers.onFreshThread(keptListenersCostNoPageEach);
}

/// An abort algorithm that runs between two listeners' abort steps on the
/// same signal and erases every listener of the target (HTML "erase all
/// event listeners and handlers", what document.open() runs): the second
/// listener's record is out of the signal's list - its abort walk holds it
/// - when its listener is removed.
const EraseTarget = struct {
    target: *runtime.Instance,
    ran: usize = 0,

    fn run(ctx: *anyopaque) void {
        const self: *EraseTarget = @ptrCast(@alignCast(ctx));
        self.ran += 1;
        dom.event_handlers.eraseAll(self.target);
    }
};

fn removalDuringAbortWalk() !void {
    var counting: CountingAllocator = .{ .child = testing.allocator };
    const page = try Page.open(&counting);
    defer page.close();
    try page.run(
        \\globalThis.controller = new AbortController();
        \\globalThis.target = new EventTarget();
        \\globalThis.calls = 0;
        \\target.addEventListener('x', () => { ++calls; }, { signal: controller.signal });
        \\0
    );
    const signal = try page.instance("controller.signal");
    const target = try page.instance("target");
    var erase: EraseTarget = .{ .target = target };
    try dom.abort_algorithms.add(signal, .{ .ctx = &erase, .run = EraseTarget.run });
    try page.run(
        \\target.addEventListener('x', () => { ++calls; }, { signal: controller.signal });
        \\target.addEventListener('y', () => { ++calls; }, { signal: controller.signal });
        \\controller.abort();
        \\target.dispatchEvent(new Event('x'));
        \\target.dispatchEvent(new Event('y'));
        \\if (calls !== 0) globalThis.failed = 'listeners ran after their signal aborted: ' + calls;
        \\0
    );
    try testing.expectEqual(@as(usize, 1), erase.ran);
    try page.expectNoFailure();
    // Everything the walk and the erase let go of is freed, each once: the
    // testing allocator under the counter finds a double free, a write
    // after free or a leak at the Browser's end.
}

test "a listener removed while its signal's abort walk holds its record is removed and freed once" {
    try helpers.onFreshThread(removalDuringAbortWalk);
}
