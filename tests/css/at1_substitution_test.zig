//! Values 5 §8.7 through the real arbitrary-substitution engine.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const sub = css.substitution;
const Allocator = std.mem.Allocator;

const Attribute = struct { name: []const u8, value: []const u8 };
const Guard = struct { key: []const u8, cyclic: bool = false };
const Host = struct {
    allocator: Allocator,
    attributes: []const Attribute = &.{},
    guards: std.ArrayList(Guard) = .empty,
    guard_count: usize = 0,
    fn deinit(self: *Host) void {
        for (self.guards.items) |g| self.allocator.free(g.key);
        self.guards.deinit(self.allocator);
    }
    fn lookup(context: *anyopaque, _: u64, _: ?*const sub.NamespaceMap, prefix: ?[]const u8, name: []const u8) ?sub.Attribute {
        const self: *Host = @ptrCast(@alignCast(context));
        if (prefix != null) return null;
        for (self.attributes) |attr| if (std.mem.eql(u8, attr.name, name)) return .{ .value = attr.value, .namespace = null, .local_name = attr.name };
        return null;
    }
    fn custom(_: *anyopaque, name: []const u8) sub.Error!?sub.Computed {
        if (std.mem.eql(u8, name, "--header")) return .{ .text = "data-n px" };
        if (std.mem.eql(u8, name, "--type")) return .{ .text = "<length>" };
        if (std.mem.eql(u8, name, "--extra")) return .{ .text = "data-n, 1px, 2px" };
        return null;
    }
    fn wouldCycle(context: *anyopaque, kind: sub.GuardKind, name: []const u8) bool {
        std.debug.assert(kind == .attribute);
        const self: *Host = @ptrCast(@alignCast(context));
        for (self.guards.items) |g| if (std.mem.eql(u8, g.key, name)) return true;
        return false;
    }
    fn guard(context: *anyopaque, kind: sub.GuardKind, name: []const u8) Allocator.Error!usize {
        std.debug.assert(kind == .attribute);
        const self: *Host = @ptrCast(@alignCast(context));
        const key = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key);
        var cycle = false;
        for (self.guards.items) |*g| {
            if (std.mem.eql(u8, g.key, name)) cycle = true;
            if (cycle) g.cyclic = true;
        }
        const token = self.guards.items.len;
        try self.guards.append(self.allocator, .{ .key = key });
        self.guard_count += 1;
        return token;
    }
    fn unguard(context: *anyopaque, token: usize) bool {
        const self: *Host = @ptrCast(@alignCast(context));
        std.debug.assert(token + 1 == self.guards.items.len);
        const g = self.guards.pop().?;
        self.allocator.free(g.key);
        return g.cyclic;
    }
    fn host(self: *Host) sub.Host {
        return .{ .context = self, .attribute = lookup, .custom_value = custom, .guard = guard, .unguard = unguard, .would_cycle = wouldCycle };
    }
};

fn expect(host: *Host, source: []const u8, expected: ?[]const u8) !void {
    var arena = std.heap.ArenaAllocator.init(host.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const nodes = sub.parse(a, source) catch |err| switch (err) {
        error.Invalid => return testing.expect(expected == null),
        else => return err,
    };
    const result = sub.substituteAndRender(a, nodes, host.host(), .{ .property = "width" }) catch |err| switch (err) {
        error.Invalid => return testing.expect(expected == null),
        else => return err,
    };
    try testing.expectEqual(@as(usize, 0), host.guards.items.len);
    if (expected) |text| try testing.expectEqualStrings(text, result.text) else return error.ExpectedInvalid;
}

test "attr plugin: primitive conversion, missing values and lazy fallback" {
    var host: Host = .{ .allocator = testing.allocator, .attributes = &.{ .{ .name = "data-n", .value = "12" }, .{ .name = "data-raw", .value = "var(--missing)" } } };
    defer host.deinit();
    try expect(&host, "attr(data-n)", "\"12\"");
    try expect(&host, "attr(data-n px, var(--missing))", "12px");
    try expect(&host, "attr(data-raw raw-string)", "\"var(--missing)\"");
    try expect(&host, "attr(data-n number)", "12");
    try expect(&host, "attr(data-n inherit, 9px)", "9px");
    try expect(&host, "attr(missing)", "\"\"");
    try expect(&host, "attr(missing raw-string)", null);
    try expect(&host, "[attr(missing,)]", "[]");
    try testing.expectEqual(@as(usize, 5), host.guard_count);
}

test "attr plugin: shared syntax definitions serialize the specified value" {
    var host: Host = .{ .allocator = testing.allocator, .attributes = &.{ .{ .name = "data-n", .value = "2em" }, .{ .name = "data-wide", .value = "inherit" }, .{ .name = "data-empty", .value = "" } } };
    defer host.deinit();
    try expect(&host, "attr(data-n type(<length>))", "2em");
    try expect(&host, "attr(data-n type(\"<length>\"))", "2em");
    try expect(&host, "attr(data-wide type(*))", "inherit");
    try expect(&host, "[attr(data-empty type(*))]", "[]");
    try expect(&host, "attr(data-wide type(<length>), 7px)", "7px");
}

test "attr plugin: strict free-form arguments and deferred header validation" {
    var host: Host = .{ .allocator = testing.allocator, .attributes = &.{.{ .name = "data-n", .value = "12" }} };
    defer host.deinit();
    try expect(&host, "attr({data-n px})", "12px");
    try expect(&host, "attr(missing, {red, blue})", "red, blue");
    try expect(&host, "attr(missing, red, blue)", null);
    try expect(&host, "attr(missing, red {})", null);
    try expect(&host, "attr(var(--header))", "12px");
    try expect(&host, "attr(data-n type(var(--type)), 9px)", "9px");
    try expect(&host, "attr(...var(--extra))", null);
    for ([_][]const u8{ "attr()", "attr(1, 2px)", "attr(x type(<url> | <length>), 2px)", "attr(x type(<length> +), 2px)", "attr(x unknown(), 2px)" }) |text| {
        try testing.expect(!try sub.validate(testing.allocator, text));
    }
    try testing.expect(try sub.validate(testing.allocator, "attr(data-n type(var(--type)), 9px)"));
}

test "attr plugin: every successful lookup is guarded, missing names never are" {
    var host: Host = .{ .allocator = testing.allocator, .attributes = &.{.{ .name = "x", .value = "attr(x raw-string)" }} };
    defer host.deinit();
    try expect(&host, "attr(x type(*), safe)", "safe");
    try testing.expectEqual(@as(usize, 2), host.guard_count);
    try expect(&host, "attr(x px, attr(x raw-string))", "\"attr(x raw-string)\"");
    try testing.expectEqual(@as(usize, 4), host.guard_count);
    try expect(&host, "attr(missing, attr(missing, safe))", "safe");
    try testing.expectEqual(@as(usize, 4), host.guard_count);
}

test "attr plugin: direct empty substitution taints its container and stores no token range" {
    var host: Host = .{ .allocator = testing.allocator };
    defer host.deinit();
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const direct = try sub.substituteAndRender(a, try sub.parse(a, "src(\"literal\" attr(missing,))"), host.host(), .{});
    try testing.expectEqualStrings("src(\"literal\" )", direct.text);
    try testing.expect(direct.taint.len != 0);
    const stored = try sub.substituteAndRender(a, try sub.parse(a, "attr(missing,)"), host.host(), .{});
    try testing.expectEqualStrings("", stored.text);
    try testing.expectEqual(@as(usize, 0), stored.taint.len);
}

fn allocationCase(allocator: Allocator) !void {
    var host: Host = .{ .allocator = allocator, .attributes = &.{.{ .name = "x", .value = "attr(x raw-string)" }} };
    defer host.deinit();
    try expect(&host, "attr(x type(*), safe)", "safe");
}

test "attr plugin: nested conversion and guards clean up each allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{});
}
