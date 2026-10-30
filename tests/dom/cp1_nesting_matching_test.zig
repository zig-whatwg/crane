//! Nested parent selectors match correctly without retaining allocations.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
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

fn matchDeepest(counting: *BudgetAllocator, source: []const u8, depth: usize, element: *runtime.Instance) !void {
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
}

fn correctness(depth: usize) !void {
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
    const result = matchDeepest(&counting, source, depth, element);
    try std.testing.expectEqual(@as(usize, 0), counting.live);
    try std.testing.expect(counting.peak <= byte_budget);
    try result;
    try std.testing.expect(!counting.budget_hit);
}

fn onThread(depth: usize) !void {
    const Run = struct {
        fn run(value: usize, result: *anyerror!void) void {
            result.* = correctness(value);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.run, .{ depth, &result });
    thread.join();
    try result;
}

test "repeated parent selectors match at nesting depth eight and release their storage" {
    try onThread(8);
}
