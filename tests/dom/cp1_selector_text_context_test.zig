//! Q78/Q79: rejecting selectorText does not resolve a parent or change CSSOM.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const selector = @import("selector");
const a = std.testing.allocator;

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}

const Work = struct { allocations: usize, allocated_bytes: usize };

fn rejected(context: runtime.Context, nested: bool) !Work {
    var measured = std.testing.FailingAllocator.init(a, .{});
    const allocator = measured.allocator();
    const record = try dom.style.SheetRecord.create(allocator, if (nested) ".parent { .child { color: red; } }" else ".child { color: red; }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    const outer = list.items[0];
    const child = if (nested) outer.children().?.items[0] else outer;
    const object = try interfaces.CSSStyleRule.initWith(a, context, .{ .css_rule = child });
    defer interfaces.CSSStyleRule.deinit(object);
    const compiled = try record.contentsOf(.{ .allocator = allocator });
    _ = try record.namespaceMap(object);
    const version = record.contents_version;
    const matching = child.matchingSelectors().?;
    const authored = child.prelude;
    const owner = outer.data.style.resolved;
    const refs: u32 = if (owner) |view| view.shared_owner.?.refs else 0;
    if (nested) try std.testing.expect(owner != null) else try std.testing.expect(owner == null);
    const before_allocations = measured.allocations;
    const before_bytes = measured.allocated_bytes;
    const before_live = measured.allocated_bytes - measured.freed_bytes;
    // Invalid before context-sensitive implicit & insertion. Both cases
    // therefore perform the same rejected parse, with no parent work.
    try interfaces.CSSStyleRule.set_selectorText(object, runtime.DOMString.initInterned("[]"));
    const work = Work{ .allocations = measured.allocations - before_allocations, .allocated_bytes = measured.allocated_bytes - before_bytes };
    try std.testing.expectEqual(before_live, measured.allocated_bytes - measured.freed_bytes);
    try std.testing.expectEqual(owner, outer.data.style.resolved);
    if (owner) |view| {
        try std.testing.expectEqual(refs, view.shared_owner.?.refs);
        try std.testing.expect(view.shared_owner.?.isUnchanged());
    }
    try std.testing.expect(child.matchingSelectors().? == matching);
    try std.testing.expect(child.prelude.ptr == authored.ptr);
    try std.testing.expectEqualStrings(authored, child.prelude);
    try std.testing.expect(record.compiled.? == compiled);
    try std.testing.expectEqual(version, record.contents_version);
    return work;
}

fn flat() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(a, .{});
    defer context.deinit();
    _ = try rejected(&context, false);
}

fn nestedAndControl() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(a, .{});
    defer context.deinit();
    const control = try rejected(&context, false);
    const nested = try rejected(&context, true);
    try std.testing.expectEqual(control.allocations, nested.allocations);
    try std.testing.expectEqual(control.allocated_bytes, nested.allocated_bytes);
}

fn kindOnly() !void {
    var measured = std.testing.FailingAllocator.init(a, .{});
    const allocator = measured.allocator();
    const record = try dom.style.SheetRecord.create(allocator, ".flat { color: red; }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    const parent = list.items[0];
    try std.testing.expect(parent.data.style.resolved == null);
    const before = measured.allocations;
    measured.fail_index = measured.alloc_index;
    measured.resize_fail_index = measured.resize_index;
    try std.testing.expectEqual(@as(?selector.parser.NestingContext, .style), dom.style.rules.nestingKindInside(parent));
    try std.testing.expectEqual(before, measured.allocations);
    try std.testing.expect(!measured.has_induced_failure);
    try std.testing.expect(parent.data.style.resolved == null);
}

test "invalid selectorText preserves an ordinary flat rule without promotion" {
    if (comptime @hasDecl(dom.style.rules, "nestingKindInside")) {
        try onThread(flat);
    } else return error.MissingReadOnlyNestingContext;
}

test "invalid nested selectorText preserves its parent and adds no parent allocation" {
    if (comptime @hasDecl(dom.style.rules, "nestingKindInside")) {
        try onThread(nestedAndControl);
    } else return error.MissingReadOnlyNestingContext;
}

test "reading a flat parent's nesting kind allocates nothing and leaves it unpromoted" {
    if (comptime @hasDecl(dom.style.rules, "nestingKindInside")) {
        try kindOnly();
    } else return error.MissingReadOnlyNestingContext;
}
