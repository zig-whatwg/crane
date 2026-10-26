//! Shared by lane vars1b2's registered-property tests: a
//! registered_properties.Snapshot made from registrations written as text,
//! parsed the way CSS.registerProperty parses them (the test-only stand-in
//! for the document's registry).
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const registered = css.registered_properties;
const cascade_mod = css.cascade;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;
const Snapshot = registered.Snapshot;

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

pub const Tree = struct {
    allocator: Allocator,
    registered: ?*Snapshot = null,
    styles: std.ArrayList(*ComputedStyle) = .empty,

    pub fn deinit(self: *Tree) void {
        var i = self.styles.items.len;
        while (i > 0) {
            i -= 1;
            self.styles.items[i].destroy();
        }
        self.styles.deinit(self.allocator);
    }

    /// A child of the last element styled (the root first), with `text` as
    /// its one author block.
    pub fn element(self: *Tree, text: []const u8) !*ComputedStyle {
        var block = try DeclarationBlock.parse(.{ .allocator = self.allocator }, text);
        defer block.deinit();
        const parent: ?*const ComputedStyle = if (self.styles.items.len == 0) null else self.styles.items[self.styles.items.len - 1];
        try self.styles.ensureUnusedCapacity(self.allocator, 1);
        const style = try cascade_mod.cascade(.{
            .allocator = self.allocator,
            .parent = parent,
            .is_root = parent == null,
            .registered = self.registered,
        }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        self.styles.appendAssumeCapacity(style);
        return style;
    }
};

pub fn expectCustom(style: *const ComputedStyle, name: []const u8, expected: ?[]const u8) !void {
    const got = style.customValue(name);
    if (expected) |e| {
        if (got == null) {
            std.debug.print("{s}: expected \"{s}\", got the guaranteed-invalid value\n", .{ name, e });
            return error.TestExpectedEqual;
        }
        testing.expectEqualStrings(e, got.?.bytes) catch |err| {
            std.debug.print("  (for {s})\n", .{name});
            return err;
        };
    } else if (got) |g| {
        std.debug.print("{s}: expected the guaranteed-invalid value, got \"{s}\"\n", .{ name, g.bytes });
        return error.TestExpectedEqual;
    }
}
