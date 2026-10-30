//! if() through the shared Values 5 substitution table, with recording Host
//! callbacks. No alternative var()/env() resolver lives in these tests.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const sub = css.substitution;

const Probe = struct {
    allocator: Allocator,
    calls: std.ArrayList([]const u8) = .empty,
    tainted: bool = false,
    custom_tainted: bool = false,
    oom: bool = false,
    quirks: bool = false,

    fn deinit(self: *Probe) void {
        for (self.calls.items) |call| self.allocator.free(call);
        self.calls.deinit(self.allocator);
    }

    fn record(self: *Probe, name: []const u8) !void {
        if (self.oom) return error.OutOfMemory;
        const copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(copy);
        try self.calls.append(self.allocator, copy);
    }

    fn saw(self: *Probe, name: []const u8) bool {
        for (self.calls.items) |call| if (std.mem.eql(u8, call, name)) return true;
        return false;
    }

    fn custom(context: *anyopaque, name: []const u8) sub.Error!?sub.Computed {
        const self: *Probe = @ptrCast(@alignCast(context));
        try self.record(name);
        const text: []const u8 = if (std.mem.eql(u8, name, "--condition")) "style(--yes)" else if (std.mem.eql(u8, name, "--else")) "else" else if (std.mem.eql(u8, name, "--yes")) "yes" else if (std.mem.eql(u8, name, "--empty")) "" else if (std.mem.eql(u8, name, "--branches")) "else: yes" else return null;
        return .{ .text = text, .taint = if (self.tainted or self.custom_tainted) &.{.{ .start = 0, .end = text.len, .kind = .own }} else &.{} };
    }

    fn has(context: *anyopaque, name: []const u8) sub.Error!sub.Flagged(bool) {
        const self: *Probe = @ptrCast(@alignCast(context));
        try self.record(name);
        return .{ .value = std.mem.eql(u8, name, "--yes") or std.mem.eql(u8, name, "--empty"), .tainted = self.tainted };
    }

    fn matches(context: *anyopaque, name: []const u8, value: []const u8) sub.Error!?sub.Flagged(bool) {
        const self: *Probe = @ptrCast(@alignCast(context));
        try self.record(name);
        try self.record(value);
        // The caller must substitute the original Node span first, lazily.
        if (sub.mentionsFunction(value)) return error.Invalid;
        return .{ .value = (std.mem.eql(u8, name, "--yes") and std.mem.eql(u8, value, "yes")) or
            (std.mem.eql(u8, name, "--empty") and value.len == 0), .tainted = self.tainted };
    }

    fn numeric(context: *anyopaque, value: []const u8) sub.Error!?sub.Flagged(sub.Numeric) {
        const self: *Probe = @ptrCast(@alignCast(context));
        try self.record(value);
        const n = std.fmt.parseFloat(f64, value) catch return null;
        return .{ .value = .{ .value = n, .dimension = .number }, .tainted = self.tainted };
    }

    fn media(context: *anyopaque, value: []const u8) sub.Error!bool {
        const self: *Probe = @ptrCast(@alignCast(context));
        try self.record(value);
        if (std.mem.eql(u8, value, "unknown")) return error.Invalid;
        return std.mem.eql(u8, value, "true");
    }

    fn supports(context: *anyopaque, value: []const u8, quirks: bool, _: ?*const sub.NamespaceMap) sub.Error!bool {
        const self: *Probe = @ptrCast(@alignCast(context));
        self.quirks = quirks;
        return media(context, value);
    }

    fn host(self: *Probe) sub.Host {
        return .{ .context = self, .custom_value = custom, .has_value = has, .query_value_matches = matches, .numeric_value = numeric, .media = media, .supports = supports };
    }
};

fn expect(allocator: Allocator, probe: *Probe, text: []const u8, expected: ?[]const u8) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const nodes = try sub.parse(arena.allocator(), text);
    const output = sub.substituteAndRender(arena.allocator(), nodes, probe.host(), .{ .property = "--result", .quirks = true }) catch |err| switch (err) {
        error.Invalid => return testing.expect(expected == null),
        else => |e| return e,
    };
    try testing.expect(expected != null);
    try testing.expectEqualStrings(expected.?, output.text);
}

test "if integration: the table selects the first branch, empty value, braces and IACVT" {
    var probe: Probe = .{ .allocator = testing.allocator };
    defer probe.deinit();
    try expect(testing.allocator, &probe, "if(else: yes)", "yes");
    try expect(testing.allocator, &probe, "if(style(--yes): var(--yes); else: var(--never);)", "yes");
    try expect(testing.allocator, &probe, "[if(else:)]", "[]");
    try expect(testing.allocator, &probe, "if(else: {a, b})", "{a, b}");
    try expect(testing.allocator, &probe, "if(nonsense: no; {else}: no; else: yes)", "yes");
    try expect(testing.allocator, &probe, "if(style(--missing): no)", null);
    try testing.expect(!probe.saw("--never"));
}

test "if integration: argument grammar and early spread use the shared parser" {
    for ([_][]const u8{ "if()", "if(:x)", "if(else)", "if(else:x;;)", "if(else:a,b)", "if({a:b}:x)", "if(else:!important)" }) |text|
        try testing.expect(!try sub.validate(testing.allocator, text));
    var probe: Probe = .{ .allocator = testing.allocator };
    defer probe.deinit();
    try expect(testing.allocator, &probe, "if(...var(--branches))", "yes");
    try expect(testing.allocator, &probe, "IF(ELSE: [a:b;c,d]", "[a:b;c,d]");
    try expect(testing.allocator, &probe, "if(style(--y\\65 s): yes; else:no)", "yes");
}

test "if integration: condition-level var and env expand through the shared table" {
    var probe: Probe = .{ .allocator = testing.allocator };
    defer probe.deinit();
    try expect(testing.allocator, &probe, "if(var(--condition): yes; else:no)", "yes");
    try expect(testing.allocator, &probe, "if((var(--condition)) and (not style(--missing)): yes; else:no)", "yes");
    try expect(testing.allocator, &probe, "if(env(undefined, var(--else)): yes; else:no)", "yes");
    try expect(testing.allocator, &probe, "if(var(--missing): no; else:yes)", "yes");
}

test "if integration: failed feature substitutions are false and skipped leaves stay unvisited" {
    var probe: Probe = .{ .allocator = testing.allocator };
    defer probe.deinit();
    try expect(testing.allocator, &probe, "if(style(not (--yes: var(--missing))): yes; else:no)", "yes");
    try expect(testing.allocator, &probe, "if(style((--yes) or (--other: var(--never))): yes; else:no)", "yes");
    try expect(testing.allocator, &probe, "if(style((--missing) and (--other: var(--never))): no; else:yes)", "yes");
    try expect(testing.allocator, &probe, "if(style(--yes) or style(--other: var(--never)): yes; else:no)", "yes");
    try expect(testing.allocator, &probe, "if(style(--yes: var(--yes)): yes; else:no)", "yes");
    try testing.expect(!probe.saw("--never"));
    try testing.expect(!probe.saw("--other"));
}

test "if integration: unknown stays unknown under not, Host receives quirks and errors" {
    var probe: Probe = .{ .allocator = testing.allocator };
    defer probe.deinit();
    for ([_][]const u8{ "if(not style(color:red): no; else:yes)", "if(not style(unknown:red):no;else:yes)", "if(not supports(unknown):no;else:yes)", "if(not media(unknown):no;else:yes)", "if(not supports(false):yes;else:no)" }) |text|
        try expect(testing.allocator, &probe, text, "yes");
    try testing.expect(!probe.saw("color"));
    try testing.expect(!probe.saw("unknown:red"));
    try testing.expect(probe.quirks);
    probe.oom = true;
    try testing.expectError(error.OutOfMemory, expect(testing.allocator, &probe, "if(style(--yes):yes)", "yes"));
    try testing.expectError(error.OutOfMemory, expect(testing.allocator, &probe, "if(supports(true):yes)", "yes"));
}

test "if integration: range reference is evaluated first, then both bounds even after false" {
    var probe: Probe = .{ .allocator = testing.allocator };
    defer probe.deinit();
    try expect(testing.allocator, &probe, "if(style(3 < 2 < 1): no; else:yes)", "yes");
    try testing.expectEqual(@as(usize, 3), probe.calls.items.len);
    for ([_][]const u8{ "2", "3", "1" }, probe.calls.items) |wanted, got| try testing.expectEqualStrings(wanted, got);
}

test "if integration: queried and empty substituted taint survive selection" {
    var probe: Probe = .{ .allocator = testing.allocator, .tainted = true };
    defer probe.deinit();
    for ([_][]const u8{ "if(style(--yes):yes)", "if(style(--yes:yes):)", "if(style(1 < 2):yes)", "if(var(--else):)", "if(style(--empty:var(--missing,var(--empty))):yes)", "if(...var(--branches))" }) |text| {
        var arena = std.heap.ArenaAllocator.init(testing.allocator);
        defer arena.deinit();
        const nodes = try sub.parse(arena.allocator(), text);
        var resolver: sub.Resolver = .{ .allocator = arena.allocator(), .host = probe.host(), .property = "--result" };
        const replacement = try resolver.substituteWithTaint(nodes, false);
        try testing.expect(replacement.tainted);
    }
}

fn allocationScenario(allocator: Allocator) !void {
    var probe: Probe = .{ .allocator = allocator };
    defer probe.deinit();
    try expect(allocator, &probe, "if((var(--condition)) and style(not (--yes: var(--missing))): var(--yes); else:no)", "yes");
}

test "if integration: parser, callbacks and substitution release every failing allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationScenario, .{});
}

// Q18/Q20: the Host comparison contributes NO taint here. Only an empty
// var() result through another var() fallback can taint the selected value.
test "if integration: empty query substitution alone taints, skipped values do not" {
    var probe: Probe = .{ .allocator = testing.allocator, .custom_tainted = true };
    defer probe.deinit();
    for ([_]struct { text: []const u8, tainted: bool }{
        .{ .text = "if(style(--empty:var(--missing,var(--empty))):yes)", .tainted = true },
        .{ .text = "if(style((--yes) or (--empty:var(--empty))):yes)", .tainted = false },
    }) |case| {
        var arena = std.heap.ArenaAllocator.init(testing.allocator);
        defer arena.deinit();
        const nodes = try sub.parse(arena.allocator(), case.text);
        var resolver: sub.Resolver = .{ .allocator = arena.allocator(), .host = probe.host(), .property = "--result" };
        try testing.expectEqual(case.tainted, (try resolver.substituteWithTaint(nodes, false)).tainted);
    }
}

test "if integration: a selected nonempty branch retains its trailing whitespace" {
    // if-conditionals.html's second subtest: only the initial argument space
    // is consumed. The selected value's final space is observable in CSSOM.
    var probe: Probe = .{ .allocator = testing.allocator };
    defer probe.deinit();
    try expect(testing.allocator, &probe, "if( style( --yes ) : yes )", "yes ");
    try expect(testing.allocator, &probe, "if(else:yes ; )", "yes ");
    try expect(testing.allocator, &probe, "[if(else:   )]", "[]");
}
