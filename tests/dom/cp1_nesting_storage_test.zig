//! Q74: deep repeated-parent CSS must fit bounded linear storage.
//! This fixture is prepared before the shared-owner implementation.
const std = @import("std");
const dom = @import("dom");
const selector = @import("selector");
const a = std.testing.allocator;
const byte_budget: usize = 8 * 1024 * 1024;

/// Requested live bytes, excluding DebugAllocator's own bookkeeping and
/// the fixture's input construction. Once the budget is hit, fail every
/// subsequent growth request so a swallowed OOM cannot resume the case.
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

test "Q59 budget accounting fails closed and releases every accepted allocation" {
    var counting: BudgetAllocator = .{ .limit = 32 };
    const allocator = counting.allocator();
    {
        const first = try allocator.alloc(u8, 16);
        defer allocator.free(first);
        const second = try allocator.alloc(u8, 16);
        defer allocator.free(second);
        try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 1));
        try std.testing.expect(counting.budget_hit);
        try std.testing.expectEqual(@as(usize, 32), counting.peak);
    }
    // A case cannot resume allocating after crossing the budget.
    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 1));
    try std.testing.expectEqual(@as(usize, 0), counting.live);
    try std.testing.expectEqual(@as(usize, 2), counting.allocations);
}

const Storage = struct { retained: usize, peak: usize, allocations: usize };

fn measure(counting: *BudgetAllocator, source: []const u8) std.mem.Allocator.Error!usize {
    const allocator = counting.allocator();
    const record = try dom.style.SheetRecord.create(allocator, source, .{});
    defer record.unref();
    _ = try record.rulesWith(.{ .allocator = allocator });
    _ = try record.contentsOf(.{ .allocator = allocator });
    return counting.live;
}

fn storage(nested: []const u8, name: []const u8, depth: usize) !Storage {
    const source = try chain(nested, depth);
    defer a.free(source);
    var counting: BudgetAllocator = .{};
    const result = measure(&counting, source);
    // The measurement has released its SheetRecord before either branch.
    try std.testing.expectEqual(@as(usize, 0), counting.live);
    try std.testing.expect(counting.peak <= byte_budget);
    if (result) |retained| {
        try std.testing.expect(!counting.budget_hit);
        std.debug.print("CP1_NESTING_STORAGE case={s} depth={d} status=OK input_bytes={d} budget={d} retained_bytes={d} peak_live_bytes={d} allocations={d} final_live_bytes={d}\n", .{ name, depth, source.len, byte_budget, retained, counting.peak, counting.allocations, counting.live });
        return .{ .retained = retained, .peak = counting.peak, .allocations = counting.allocations };
    } else |_| {
        std.debug.print("CP1_NESTING_STORAGE case={s} depth={d} status={s} input_bytes={d} budget={d} peak_live_bytes={d} allocations={d} final_live_bytes={d}\n", .{ name, depth, if (counting.budget_hit) "BYTE_BUDGET_FAIL" else "ALLOCATOR_FAIL", source.len, byte_budget, counting.peak, counting.allocations, counting.live });
        // Unlike Q59's diagnostic, exhaustion FAILS this regression.
        return error.OutOfMemory;
    }
}

fn linear(nested: []const u8, name: []const u8) !void {
    const shallow = try storage(nested, name, 10);
    const deep = try storage(nested, name, 20);
    // Doubling depth may grow container capacities in steps; this permits
    // modest capacity slack while rejecting quadratic/exponential storage.
    try std.testing.expect(deep.retained * 2 <= shallow.retained * 5);
    std.debug.print("CP1_NESTING_STORAGE case={s} status=LINEAR retained_10={d} retained_20={d}\n", .{ name, shallow.retained, deep.retained });
}

fn chain(nested: []const u8, depth: usize) ![]u8 {
    var source: std.ArrayList(u8) = .empty;
    errdefer source.deinit(a);
    try source.appendSlice(a, ".a { color: red;");
    for (0..depth) |_| {
        try source.appendSlice(a, nested);
        try source.appendSlice(a, " { color: red;");
    }
    try source.appendNTimes(a, '}', depth + 1);
    return source.toOwnedSlice(a);
}

test "repeated parent selectors use bounded linear storage at depths ten and twenty" {
    try linear("&&", "double");
}

test "mixed parent selector lists use bounded linear storage at depths ten and twenty" {
    try linear("& .x, & .y", "mixed_list");
}

test "repeated parent selectors grow linearly from depth ten to twelve" {
    const shallow = try storage("&&", "double", 10);
    const deep = try storage("&&", "double", 12);
    try std.testing.expect(deep.retained * 2 <= shallow.retained * 3);
}

test "mixed parent selector lists grow linearly from depth ten to twelve" {
    const shallow = try storage("& .x, & .y", "mixed_list", 10);
    const deep = try storage("& .x, & .y", "mixed_list", 12);
    try std.testing.expect(deep.retained * 2 <= shallow.retained * 3);
}

test "record selector and rule payload sizes alongside storage measurements" {
    const Data = dom.style.rules.Data;
    std.debug.print("CP1_NESTING_SIZES SelectorList={d} Rule={d} Data={d} style={d} nested_declarations={d} container={d} scope={d} font_face={d}\n", .{ @sizeOf(selector.SelectorList), @sizeOf(dom.style.Rule), @sizeOf(Data), @sizeOf(@FieldType(Data, "style")), @sizeOf(@FieldType(Data, "nested_declarations")), @sizeOf(@FieldType(Data, "container")), @sizeOf(@FieldType(Data, "scope")), @sizeOf(@FieldType(Data, "font_face")) });
    const budget = @sizeOf(@FieldType(Data, "font_face"));
    inline for (.{ "style", "nested_declarations", "container", "scope" }) |kind|
        try std.testing.expect(@sizeOf(@FieldType(Data, kind)) <= budget);
}
