//! Shared by lane vars1b2's registered-property tests: a
//! registered_properties.Snapshot made from registrations written as text,
//! parsed the way CSS.registerProperty parses them (the test-only stand-in
//! for the document's registry).
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const registered = css.registered_properties;

/// A registration as the registry holds it: its syntax text and its
/// parsed (specified) initial value.
pub const Def = struct { name: []const u8, syntax: []const u8, inherits: bool, initial: ?[]const u8 };

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
