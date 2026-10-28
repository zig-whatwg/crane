//! Q74/Q75 shared selectors survive each CSSOM lifetime transition.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const selector = @import("selector");
const a = std.testing.allocator;
const Phase = enum { replacement, parent_deletion, child_deletion, teardown };

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.run, .{&result});
    thread.join();
    try result;
}

fn lifecycle(comptime phase: Phase) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(a, .{});
    defer context.deinit();
    const record = try dom.style.SheetRecord.create(a, ".old { && { color: green; } }", .{});
    var owns_record = true;
    defer if (owns_record) record.unref();
    const list = try record.rulesWith(.{ .allocator = a });
    const parent = list.items[0];
    const child = parent.children().?.items[0];
    child.ref();
    defer child.unref();
    const object = try interfaces.CSSStyleRule.initWith(a, &context, .{ .css_rule = parent });
    defer interfaces.CSSStyleRule.deinit(object);
    const old = parent.matchingSelectors().?.shared_owner.?;
    try std.testing.expectEqual(@as(u32, 3), old.refs);
    // An independent selector holder retains the old parent references.
    var held = try selector.nesting.clone(a, child.matchingSelectors().?);
    defer held.deinit();
    try std.testing.expectEqual(@as(u32, 5), old.refs);
    try interfaces.CSSStyleRule.set_selectorText(object, runtime.DOMString.initInterned("#replacement"));
    try std.testing.expect(old != parent.matchingSelectors().?.shared_owner.?);
    try std.testing.expectEqual(@as(u32, 2), old.refs);
    try std.testing.expectEqualStrings("old", held.selectors[0].compound.simple_selectors[0].PseudoClass.kind.Is.selectors[0].compound.simple_selectors[0].Class.class_name);
    try std.testing.expectEqual(@as(u32, 2), child.matchingSelectors().?.selectors[0].calculateSpecificity().id);
    const authored = try child.serialize(a);
    defer a.free(authored);
    try std.testing.expectEqualStrings("&& { color: green; }", authored);
    try std.testing.expect(old.isUnchanged());
    if (phase == .replacement) return;
    try dom.style.cssom.removeRule(object, .{ .sheet = record }, 0);
    try std.testing.expectEqual(@as(usize, 0), list.items.len);
    try std.testing.expect(parent.parent_sheet == null);
    try std.testing.expectEqual(@as(u32, 2), old.refs);
    if (phase == .parent_deletion) return;
    try dom.style.cssom.removeRule(object, .{ .rule = parent }, 0);
    try std.testing.expect(child.parent_rule == null);
    try std.testing.expectEqual(@as(u32, 0), child.matchingSelectors().?.selectors[0].calculateSpecificity().id);
    try std.testing.expectEqual(@as(u32, 2), old.refs);
    if (phase == .child_deletion) return;
    record.unref();
    owns_record = false;
    try std.testing.expectEqual(@as(u32, 2), old.refs);
    try std.testing.expect(old.isUnchanged());
}

fn flatInsertion(allocator: std.mem.Allocator) !void {
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const record = try dom.style.SheetRecord.create(allocator, ".flat { color: red; }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    const parent = list.items[0];
    const object = try interfaces.CSSStyleRule.initWith(allocator, &context, .{ .css_rule = parent });
    defer interfaces.CSSStyleRule.deinit(object);
    try std.testing.expect(parent.data.style.resolved == null);
    const original = parent.matchingSelectors().?;
    const compiled = try record.contentsOf(.{ .allocator = allocator });
    const version = record.contents_version;
    _ = dom.style.cssom.insertRule(object, .{ .rule = parent }, "&& { color: green; }", 0, .{}) catch |err| {
        try std.testing.expect(parent.data.style.resolved == null);
        try std.testing.expect(parent.matchingSelectors().? == original);
        try std.testing.expectEqual(@as(usize, 0), parent.children().?.items.len);
        try std.testing.expectEqualStrings(".flat", parent.prelude);
        try std.testing.expect(record.compiled.? == compiled);
        try std.testing.expectEqual(version, record.contents_version);
        return err;
    };
    const shared = parent.data.style.resolved.?.shared_owner.?;
    try std.testing.expectEqual(@as(u32, 3), shared.refs);
    try std.testing.expectEqual(@as(usize, 1), parent.children().?.items.len);
    try std.testing.expectEqualStrings("&&", parent.children().?.items[0].prelude);
    try std.testing.expectEqual(version +% 1, record.contents_version);
    try std.testing.expect(shared.isUnchanged());
    _ = try record.contentsOf(.{ .allocator = allocator });
}

fn allInsertions() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    try flatInsertion(a);
    try std.testing.checkAllAllocationFailures(a, flatInsertion, .{});
}

test "replacing a parent creates a new node while old child selectors remain readable" {
    if (comptime @hasDecl(selector.nesting, "SharedList")) {
        try onThread(struct {
            fn run() !void {
                try lifecycle(.replacement);
            }
        }.run);
    } else return error.MissingSharedNesting;
}
test "parent deletion preserves shared selectors until their last holder releases" {
    if (comptime @hasDecl(selector.nesting, "SharedList")) {
        try onThread(struct {
            fn run() !void {
                try lifecycle(.parent_deletion);
            }
        }.run);
    } else return error.MissingSharedNesting;
}
test "child deletion releases its shared parent references after re-resolution" {
    if (comptime @hasDecl(selector.nesting, "SharedList")) {
        try onThread(struct {
            fn run() !void {
                try lifecycle(.child_deletion);
            }
        }.run);
    } else return error.MissingSharedNesting;
}
test "sheet teardown leaves independently held shared selectors readable" {
    if (comptime @hasDecl(selector.nesting, "SharedList")) {
        try onThread(struct {
            fn run() !void {
                try lifecycle(.teardown);
            }
        }.run);
    } else return error.MissingSharedNesting;
}
test "flat-parent insertion promotes its selector atomically at every allocation failure" {
    if (comptime @hasDecl(selector.nesting, "SharedList")) {
        try onThread(allInsertions);
    } else return error.MissingSharedNesting;
}
