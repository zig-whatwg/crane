//! An Intl object's internal slots live exactly as long as the object, and
//! never past its agent.
//!
//! Each Intl constructor keeps what it resolved (locale, options) natively,
//! in a cell of its agent's (intl_binding.Objects, on the agent's record):
//! freed by a weak callback once the garbage collector takes the object, and
//! by the agent's end for whatever is still alive then. Until lane intlleak
//! the state sat in nine process-wide registries that nothing freed but the
//! host agent's end - the weak handle was armed on the wrong value and never
//! fired, the objects were rooted besides, and each entry took three pages:
//! gc_bench read ~48 KB of RSS per `new Intl.Collator()` (+1.45 GB over 30k).
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: protocol.HostHooks = .{};

/// c_allocator, counting the bytes outstanding: what an agent made with it
/// still holds. Atomic: an agent's allocator may be reached off its thread.
const Counting = struct {
    outstanding: std.atomic.Value(i64) = .init(0),

    fn allocator(self: *Counting) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        const ptr = std.heap.c_allocator.rawAlloc(len, alignment, ret_addr) orelse return null;
        _ = self.outstanding.fetchAdd(@intCast(len), .monotonic);
        return ptr;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        if (!std.heap.c_allocator.rawResize(memory, alignment, new_len, ret_addr)) return false;
        _ = self.outstanding.fetchAdd(@as(i64, @intCast(new_len)) - @as(i64, @intCast(memory.len)), .monotonic);
        return true;
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        const ptr = std.heap.c_allocator.rawRemap(memory, alignment, new_len, ret_addr) orelse return null;
        _ = self.outstanding.fetchAdd(@as(i64, @intCast(new_len)) - @as(i64, @intCast(memory.len)), .monotonic);
        return ptr;
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        std.heap.c_allocator.rawFree(memory, alignment, ret_addr);
        _ = self.outstanding.fetchSub(@intCast(memory.len), .monotonic);
    }
};

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open(agent_allocator: std.mem.Allocator) !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null, .allocator = agent_allocator });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    /// `source`'s completion value as a string, which must be `expected`;
    /// nothing reported.
    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        var reports: Reports = .{};
        const got = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported): {s}\n", .{ @errorName(err), reports.count, source });
            return err;
        };
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        try testing.expectEqualStrings(expected, got);
    }
};

/// One object of each Intl constructor (Locale's twice: its maximize()
/// makes another), dropped.
const one_of_each =
    \\new Intl.DateTimeFormat('en', { dateStyle: 'short' });
    \\new Intl.NumberFormat('en', { style: 'currency', currency: 'USD' });
    \\new Intl.Collator('en', { sensitivity: 'base' });
    \\new Intl.PluralRules('en');
    \\new Intl.RelativeTimeFormat('en');
    \\new Intl.ListFormat('en');
    \\new Intl.DisplayNames('en', { type: 'region' });
    \\new Intl.Segmenter('en');
    \\new Intl.Locale('en-US').maximize();
;

test "a collected Intl object's state is freed" {
    const page = try Page.open(std.heap.c_allocator);
    defer page.close();
    try page.collect();
    const before = v8.intl_binding.liveObjectCount(page.isolate());
    try page.expect("(() => { for (let i = 0; i < 100; i++) {" ++ one_of_each ++ "} return 'ok'; })()", "ok");
    // 1,000 made: none collected yet is fine, all collected is the point.
    try page.collect();
    try testing.expectEqual(before, v8.intl_binding.liveObjectCount(page.isolate()));
}

test "an Intl object still reachable keeps its state, and answers as it did" {
    const page = try Page.open(std.heap.c_allocator);
    defer page.close();
    try page.collect();
    const before = v8.intl_binding.liveObjectCount(page.isolate());
    try page.expect(
        \\globalThis.kept = [
        \\  new Intl.Collator('en', { sensitivity: 'base' }),
        \\  new Intl.NumberFormat('en', { minimumFractionDigits: 2 }),
        \\  new Intl.Locale('en-Latn-US'),
        \\];
        \\for (let i = 0; i < 200; i++) {
    ++ one_of_each ++
        \\}
        \\'ok'
    , "ok");
    try page.collect();
    try testing.expectEqual(before + 3, v8.intl_binding.liveObjectCount(page.isolate()));
    try page.expect(
        \\[kept[0].compare('a', 'A'), kept[0].resolvedOptions().sensitivity,
        \\ kept[1].format(1.5), kept[2].region(), kept[2].toString()].join(' ')
    , "0 base 1.50 US en-Latn-US");
    try page.expect("delete globalThis.kept; 'ok'", "ok");
    try page.collect();
    try testing.expectEqual(before, v8.intl_binding.liveObjectCount(page.isolate()));
}

test "an Intl object's state is out of script's reach" {
    const page = try Page.open(std.heap.c_allocator);
    defer page.close();
    // No property holds it - the registries' indexes were ordinary,
    // writable properties - and another constructor's method finds none.
    try page.expect(
        \\(() => {
        \\  const collator = new Intl.Collator();
        \\  const keys = Object.getOwnPropertyNames(collator).sort().join();
        \\  let threw = 'no';
        \\  try { new Intl.NumberFormat().format.call(collator, 1); } catch (e) { threw = e.constructor.name; }
        \\  return keys + ' ' + threw + ' ' + collator.compare.call({}, 'a', 'b');
        \\})()
    , "compare,resolvedOptions TypeError 0");
}

test "an agent's end frees its live Intl objects' state" {
    // Two agents with allocators of their own: one whose script kept Intl
    // objects alive to its end, and a control that made none. Each agent's
    // end frees what it holds; the Intl one holds nothing more.
    var with_intl: Counting = .{};
    var control: Counting = .{};
    {
        const page = try Page.open(with_intl.allocator());
        defer page.close();
        try page.expect("globalThis.kept = [];for (let i = 0; i < 50; i++) { kept.push(new Intl.Collator('en'), new Intl.Locale('en-US'), new Intl.Segmenter('en')); } 'ok'", "ok");
        try testing.expectEqual(@as(usize, 150), v8.intl_binding.liveObjectCount(page.isolate()));
    }
    {
        const page = try Page.open(control.allocator());
        defer page.close();
        try page.expect("globalThis.kept = []; 'ok'", "ok");
    }
    try testing.expectEqual(control.outstanding.load(.monotonic), with_intl.outstanding.load(.monotonic));
}
