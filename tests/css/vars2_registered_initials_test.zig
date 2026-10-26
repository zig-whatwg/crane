//! Registered custom properties' initial values (lane vars1b2; CSS
//! Properties and Values API 1 §§2.4, 3): computed ONCE per registration
//! per document - a `registered_properties.Snapshot` of the registry, keyed
//! by the registry's version and the viewport (Blink StyleInitialData,
//! built per document by StyleEngine::MaybeCreateAndGetInitialData) - and
//! never stored per element.
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const registered = css.registered_properties;

/// A registration as the registry holds it: its syntax text and its
/// parsed (specified) initial value.
const Def = struct { name: []const u8, syntax: []const u8, inherits: bool, initial: ?[]const u8 };

/// A snapshot of `defs`, parsed the way CSS.registerProperty parses them.
pub fn snapshotOf(allocator: Allocator, environment: registered.Environment, list: []const Def) !*registered.Snapshot {
    var definitions: std.ArrayList(css.syntax_definitions.Definition) = .empty;
    defer {
        for (definitions.items) |*d| d.deinit();
        definitions.deinit(allocator);
    }
    var initials: std.ArrayList(?css.syntax_values.Value) = .empty;
    defer {
        for (initials.items) |*v| if (v.*) |*value| value.deinit();
        initials.deinit(allocator);
    }
    for (list) |def| {
        try definitions.ensureUnusedCapacity(allocator, 1);
        try initials.ensureUnusedCapacity(allocator, 1);
        var definition = css.syntax_definitions.parse(allocator, def.syntax) catch |err| switch (err) {
            error.InvalidSyntax => return error.TestUnexpectedResult,
            else => |e| return e,
        };
        errdefer definition.deinit();
        const initial = if (def.initial) |text| (try definition.parseValue(.{ .allocator = allocator }, text)) orelse return error.TestUnexpectedResult else null;
        definitions.appendAssumeCapacity(definition);
        initials.appendAssumeCapacity(initial);
    }
    const sources = try allocator.alloc(registered.Source, list.len);
    defer allocator.free(sources);
    for (list, sources, 0..) |def, *source, i| source.* = .{
        .name = def.name,
        .syntax_text = def.syntax,
        .inherits = def.inherits,
        .initial_value = if (initials.items[i]) |*v| v else null,
    };
    return registered.Snapshot.create(allocator, environment, sources);
}

fn expectInitial(snapshot: *const registered.Snapshot, name: []const u8, expected: ?[]const u8) !void {
    const entry = snapshot.find(name) orelse return error.TestExpectedEqual;
    if (expected) |e| {
        const got = entry.initial orelse {
            std.debug.print("{s}: expected initial \"{s}\", got the guaranteed-invalid value\n", .{ name, e });
            return error.TestExpectedEqual;
        };
        try testing.expectEqualStrings(e, got.bytes);
    } else try testing.expect(entry.initial == null);
}

const defs = [_]Def{
    .{ .name = "--len", .syntax = "<length>", .inherits = false, .initial = "10px" },
    .{ .name = "--calc", .syntax = "<length>", .inherits = true, .initial = "calc(1px + 2px)" },
    .{ .name = "--vw", .syntax = "<length>", .inherits = false, .initial = "10vw" },
    .{ .name = "--any", .syntax = "*", .inherits = true, .initial = null },
    .{ .name = "--angle", .syntax = "<angle>", .inherits = true, .initial = "1turn" },
    .{ .name = "--color", .syntax = "<color>", .inherits = true, .initial = "red" },
};

fn initialsAreComputed(allocator: Allocator) !void {
    const snapshot = try snapshotOf(allocator, .{ .viewport_width = 1000, .viewport_height = 500 }, &defs);
    defer snapshot.release();
    try expectInitial(snapshot, "--len", "10px");
    try expectInitial(snapshot, "--calc", "3px");
    // Viewport units are the one global input (hence the viewport key).
    try expectInitial(snapshot, "--vw", "100px");
    // A universal registration without an initial value: guaranteed-invalid.
    try expectInitial(snapshot, "--any", null);
    try expectInitial(snapshot, "--angle", "360deg");
    try expectInitial(snapshot, "--color", "rgb(255, 0, 0)");
    try testing.expect(snapshot.find("--unregistered") == null);
    try testing.expect(!snapshot.find("--len").?.inherits);
    try testing.expect(snapshot.find("--calc").?.inherits);
}

test "a snapshot computes each registration's initial value once, in the document's viewport" {
    try initialsAreComputed(testing.allocator);
}

test "building a snapshot survives every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, initialsAreComputed, .{});
}

test "a snapshot with no registration is empty, and lookups miss" {
    const snapshot = try registered.Snapshot.create(testing.allocator, .{}, &.{});
    defer snapshot.release();
    try testing.expect(snapshot.isEmpty());
    try testing.expect(snapshot.find("--len") == null);
}

test "a snapshot is shared by reference" {
    const snapshot = try snapshotOf(testing.allocator, .{}, defs[0..1]);
    snapshot.retain();
    snapshot.release();
    try expectInitial(snapshot, "--len", "10px");
    snapshot.release();
}
