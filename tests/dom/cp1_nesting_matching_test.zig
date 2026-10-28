//! Q75 LOCAL DIAGNOSTIC on a shared Mac: matching shape, not cost acceptance.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const clock = @import("clock");
const a = std.testing.allocator;
const byte_budget: usize = 8 * 1024 * 1024;

const BudgetAllocator = struct {
    child: std.mem.Allocator = a,
    limit: usize = byte_budget,
    live: usize = 0,
    peak: usize = 0,
    alloc_calls: usize = 0,
    allocations: usize = 0,
    resize_calls: usize = 0,
    remap_calls: usize = 0,
    budget_hit: bool = false,

    fn allocator(self: *BudgetAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn permits(self: *BudgetAllocator, old: usize, new: usize) bool {
        if (new <= old) return true;
        if (self.budget_hit) return false;
        if (new - old > self.limit - self.live) {
            self.budget_hit = true;
            return false;
        }
        return true;
    }

    fn record(self: *BudgetAllocator, old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *BudgetAllocator = @ptrCast(@alignCast(ctx));
        self.alloc_calls += 1;
        if (!self.permits(0, len)) return null;
        const result = self.child.rawAlloc(len, alignment, ra) orelse return null;
        self.allocations += 1;
        self.record(0, len);
        return result;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *BudgetAllocator = @ptrCast(@alignCast(ctx));
        self.resize_calls += 1;
        if (!self.permits(memory.len, new_len)) return false;
        if (!self.child.rawResize(memory, alignment, new_len, ra)) return false;
        self.record(memory.len, new_len);
        return true;
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *BudgetAllocator = @ptrCast(@alignCast(ctx));
        self.remap_calls += 1;
        if (!self.permits(memory.len, new_len)) return null;
        const result = self.child.rawRemap(memory, alignment, new_len, ra) orelse return null;
        self.record(memory.len, new_len);
        return result;
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *BudgetAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(memory, alignment, ra);
        self.record(memory.len, 0);
    }
};

fn chain(depth: usize) ![]u8 {
    var source: std.ArrayList(u8) = .empty;
    errdefer source.deinit(a);
    try source.appendSlice(a, ".a { color: red;");
    for (0..depth) |_| try source.appendSlice(a, "&& { color: red;");
    try source.appendNTimes(a, '}', depth + 1);
    return source.toOwnedSlice(a);
}

fn measure(counting: *BudgetAllocator, source: []const u8, depth: usize, element: *runtime.Instance) !void {
    const allocator = counting.allocator();
    const record = try dom.style.SheetRecord.create(allocator, source, .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    var deepest = list.items[0];
    for (0..depth) |_| {
        try std.testing.expectEqual(@as(usize, 1), deepest.children().?.items.len);
        deepest = deepest.children().?.items[0];
    }
    const complex = &deepest.matchingSelectors().?.selectors[0];
    var reads: dom.selector_matching.StateReads = .{};
    var matcher = dom.selector_matching.StyleMatcher.init(element, &reads) orelse return error.MissingMatcher;
    try std.testing.expect(matcher.matches(element, complex, null));
    const iterations: usize = switch (depth) {
        8 => 256,
        10 => 64,
        else => 1,
    };
    var samples: [5]u64 = undefined;
    for (&samples, 0..) |*sample, rep| {
        var matches_count: usize = 0;
        const start = clock.monotonicNanos();
        for (0..iterations) |_| {
            matches_count += @intFromBool(matcher.matches(element, complex, null));
        }
        const elapsed = clock.monotonicNanos() - start;
        try std.testing.expectEqual(iterations, matches_count);
        try std.testing.expect(elapsed > 0);
        sample.* = @intCast(@divTrunc(elapsed, iterations));
        std.debug.print("CP1_NESTING_MATCH_DIAGNOSTIC depth={d} repetition={d} iterations={d} elapsed_ns={d} ns_per_match={d} shared_mac=true\n", .{ depth, rep + 1, iterations, elapsed, sample.* });
    }
    std.mem.sort(u64, &samples, {}, std.sort.asc(u64));
    std.debug.print("CP1_NESTING_MATCH_DIAGNOSTIC depth={d} status=OK repetitions=5 median_ns={d} retained_bytes={d} peak_live_bytes={d}\n", .{ depth, samples[2], counting.live, counting.peak });
}

fn diagnostic(depth: usize) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(a, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(a, &context);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setContentType(document, "text/html");
    try dom.document_internals.setDocumentType(document, .html);
    const element = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
    defer runtime.Instance.deinit(element);
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("class"), .{ .domstring = runtime.DOMString.initInterned("a") });
    const source = try chain(depth);
    defer a.free(source);
    var counting: BudgetAllocator = .{};
    const result = measure(&counting, source, depth, element);
    try std.testing.expectEqual(@as(usize, 0), counting.live);
    try std.testing.expect(counting.peak <= byte_budget);
    if (result) |_| {
        try std.testing.expect(!counting.budget_hit);
    } else |err| {
        if (err != error.OutOfMemory or !counting.budget_hit or depth != 20) return err;
        // Q75: this DIAGNOSTIC records why no old depth-20 timing exists.
        // The separate storage regression FAILS this same byte-budget stop.
        std.debug.print("CP1_NESTING_MATCH_DIAGNOSTIC depth=20 status=BYTE_BUDGET matching=NOT_RUN peak_live_bytes={d} final_live_bytes={d}\n", .{ counting.peak, counting.live });
    }
}

fn onThread(depth: usize) !void {
    const Run = struct {
        fn run(value: usize, result: *anyerror!void) void {
            result.* = diagnostic(value);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.run, .{ depth, &result });
    thread.join();
    try result;
}

test "matching shape diagnostic at nesting depth eight" {
    try onThread(8);
}
test "matching shape diagnostic at nesting depth ten" {
    try onThread(10);
}
test "matching shape diagnostic at nesting depth twenty or bounded old allocation stop" {
    try onThread(20);
}
