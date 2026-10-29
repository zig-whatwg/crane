//! Properties and Values API §6.2, registered computed-value reification.
//! Integrator Q56, 2026-10-27: the existing syntax parser may reconstruct
//! this canonical computed Text on demand. No cascade or snapshot storage
//! changes, and no parsing on the ordinary computed-style hot path.
const std = @import("std");
const syntax = @import("../syntax_definitions.zig");
const syntax_values = @import("../syntax_values.zig");
const properties = @import("../properties.zig");
const Allocator = std.mem.Allocator;

pub const Registered = struct {
    allocator: Allocator,
    refs: usize = 1,
    value: syntax_values.Value,

    pub fn retain(self: *Registered) void {
        self.refs += 1;
    }
    pub fn release(self: *Registered) void {
        self.refs -= 1;
        if (self.refs != 0) return;
        self.value.deinit();
        self.allocator.destroy(self);
    }
    pub fn count(self: *const Registered) usize {
        return switch (self.value.data) {
            .single, .universal => 1,
            .list => |list| list.items.len,
        };
    }
    /// Borrowed from this owner, including strings and numeric/image trees.
    pub fn item(self: *const Registered, index: usize) ?syntax_values.Item {
        return switch (self.value.data) {
            .universal => null,
            .single => |item_value| if (index == 0) item_value else null,
            .list => |list| if (index < list.items.len) list.items[index] else null,
        };
    }
};

pub fn parseComputed(options: properties.ParseOptions, definition: *const syntax.Definition, text: []const u8) Allocator.Error!?*Registered {
    // Re-use the registration's parsed syntax. The input is its computed
    // serialization, so no environment/var()/attr()/if() resolution runs.
    var value = try definition.parseValue(options, text) orelse return null;
    errdefer value.deinit();
    const result = try options.allocator.create(Registered);
    result.* = .{ .allocator = options.allocator, .value = value };
    return result;
}
