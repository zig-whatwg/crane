//! Q59: bounded, untimed measurements of the proposed owned nesting tree.
//! This is a measurement fixture, not a product expansion limit. Keep it in
//! scratch until the corresponding native RED and the measurement grant.
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

// AST nodes mean SelectorList, ComplexSelector, CompoundSelector,
// CombinatorPair, and SimpleSelector values. Strings and allocation
// headers are reflected in bytes, not in this structural node count.
fn listNodes(list: *const selector.SelectorList) usize {
    var count: usize = 1;
    for (list.selectors) |*complex| {
        count += 1 + compoundNodes(&complex.compound);
        for (complex.combinators) |*pair| count += 1 + compoundNodes(&pair.compound);
    }
    return count;
}

fn compoundNodes(compound: *const selector.CompoundSelector) usize {
    var count: usize = 1;
    for (compound.simple_selectors) |simple| {
        count += 1;
        switch (simple) {
            .PseudoClass => |pseudo| switch (pseudo.kind) {
                .Is, .Where, .Not, .Has => |list| count += listNodes(list),
                .Host => |maybe| if (maybe) |list| {
                    count += listNodes(list);
                },
                .NthChild, .NthLastChild => |pattern| if (pattern.of) |list| {
                    count += listNodes(list);
                },
                else => {},
            },
            .PseudoElement => |pseudo| if (pseudo.argument) |list| {
                count += listNodes(list);
            },
            else => {},
        }
    }
    return count;
}

const Counts = struct {
    rules: usize = 0,
    source_nodes: usize = 0,
    resolved_nodes: usize = 0,
    matching_nodes: usize = 0,
    largest_matching_list: usize = 0,
    compiled_selectors: usize = 0,
    retained_bytes: usize = 0,

    fn visit(self: *Counts, rule: *dom.style.rules.Rule) void {
        self.rules += 1;
        switch (rule.data) {
            .style => |*style| {
                self.source_nodes += listNodes(&style.selectors);
                if (style.resolved) |list| self.resolved_nodes += listNodes(list);
            },
            .nested_declarations => |*decls| self.resolved_nodes += listNodes(&decls.selectors),
            else => {},
        }
        if (rule.matchingSelectors()) |list| {
            const nodes = listNodes(list);
            self.matching_nodes += nodes;
            self.largest_matching_list = @max(self.largest_matching_list, nodes);
        }
        if (rule.children()) |children| for (children.items) |child| self.visit(child);
    }
};

fn measure(counting: *BudgetAllocator, source: []const u8) std.mem.Allocator.Error!Counts {
    const allocator = counting.allocator();
    const record = try dom.style.SheetRecord.create(allocator, source, .{});
    defer record.unref();
    const rules = try record.rulesWith(.{ .allocator = allocator });
    var result: Counts = .{};
    for (rules.items) |rule| result.visit(rule);
    const compiled = try record.contentsOf(.{ .allocator = allocator });
    result.compiled_selectors = compiled.rules.items.len;
    result.retained_bytes = counting.live;
    return result;
}

fn runCase(_: []const u8, _: usize, expected_rules: usize, source: []const u8) anyerror!void {
    var counting: BudgetAllocator = .{};
    const result: ?Counts = measure(&counting, source) catch blk: {
        // measure returns only OutOfMemory; keep a real allocator failure
        // distinct from the deliberately bounded measurement outcome.
        if (!counting.budget_hit) return error.OutOfMemory;
        break :blk null;
    };
    try std.testing.expectEqual(@as(usize, 0), counting.live);
    try std.testing.expect(counting.peak <= byte_budget);
    if (counting.budget_hit) {
        return;
    }
    const counts = result orelse return error.MissingMeasurement;
    try std.testing.expectEqual(expected_rules, counts.rules);
    try std.testing.expect(counts.compiled_selectors >= expected_rules);
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

fn cards(nested: bool) ![]u8 {
    var source: std.ArrayList(u8) = .empty;
    errdefer source.deinit(a);
    for (0..50) |i| {
        const block = if (nested)
            try std.fmt.allocPrint(a, ".card-{d} {{color:red; & .body {{color:green; &:hover {{color:blue; & > .icon {{color:black;}}}}}}}}\n", .{i})
        else
            try std.fmt.allocPrint(a, ".card-{d} {{color:red;}} .card-{d} .body {{color:green;}} .card-{d} .body:hover {{color:blue;}} .card-{d} .body:hover > .icon {{color:black;}}\n", .{ i, i, i, i });
        defer a.free(block);
        try source.appendSlice(a, block);
    }
    return source.toOwnedSlice(a);
}

test "Q59 bounded nesting growth measurement and realistic 200-rule controls" {
    // The common-case chain includes EVERY depth 1..10 (integrator Q59/2).
    for (1..11) |depth| {
        const source = try chain("&", depth);
        defer a.free(source);
        try runCase("single", depth, depth + 1, source);
    }
    for ([_]usize{ 1, 2, 4, 8, 10 }) |depth| {
        for ([_][]const u8{ "&&", "& .x, & .y" }, [_][]const u8{ "double", "mixed_list" }) |nested, name| {
            const source = try chain(nested, depth);
            defer a.free(source);
            try runCase(name, depth, depth + 1, source);
        }
    }
    // Fifty independent components, four rules each and at most three
    // nested levels; the flat form has the same selector/declaration effect.
    for ([_]bool{ false, true }) |nested| {
        const source = try cards(nested);
        defer a.free(source);
        try runCase(if (nested) "nested_200" else "flat_200", if (nested) 3 else 0, 200, source);
    }
}
