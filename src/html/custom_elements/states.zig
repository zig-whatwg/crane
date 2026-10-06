//! Native CustomStateSet backing storage (HTML 4.13.7.5 / WebIDL 3.7.12).
const std = @import("std");

pub const States = struct {
    allocator: std.mem.Allocator,
    values: std.ArrayList(?[]const u8) = .empty,
    size: usize = 0,
    iterations: usize = 0,

    pub fn init(allocator: std.mem.Allocator) States {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *States) void {
        for (self.values.items) |value| if (value) |text| self.allocator.free(text);
        self.values.deinit(self.allocator);
    }
    pub fn has(self: *const States, value: []const u8) bool {
        for (self.values.items) |item| if (item) |text| {
            if (std.mem.eql(u8, text, value)) return true;
        };
        return false;
    }
    pub fn add(self: *States, value: []const u8) !void {
        // WebIDL add step 6: SetData appends only when the value is absent.
        if (self.has(value)) return;
        const copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(copy);
        try self.values.append(self.allocator, copy);
        self.size += 1;
    }
    pub fn remove(self: *States, value: []const u8) bool {
        for (self.values.items, 0..) |item, index| if (item) |text| {
            if (!std.mem.eql(u8, text, value)) continue;
            self.allocator.free(text);
            self.values.items[index] = null;
            self.size -= 1;
            self.compact();
            return true;
        };
        return false;
    }
    pub fn clear(self: *States) void {
        // Set.prototype.clear retains slots while an iteration is in progress.
        for (self.values.items) |*item| {
            if (item.*) |text| self.allocator.free(text);
            item.* = null;
        }
        self.size = 0;
        self.compact();
    }
    pub fn beginIteration(self: *States) void {
        self.iterations += 1;
    }
    pub fn endIteration(self: *States) void {
        std.debug.assert(self.iterations > 0);
        self.iterations -= 1;
        self.compact();
    }
    pub fn next(self: *const States, cursor: *usize) ?[]const u8 {
        while (cursor.* < self.values.items.len) {
            const value = self.values.items[cursor.*];
            cursor.* += 1;
            if (value) |text| return text;
        }
        return null;
    }
    fn compact(self: *States) void {
        if (self.iterations != 0) return;
        var write: usize = 0;
        for (self.values.items) |item| if (item) |text| {
            self.values.items[write] = text;
            write += 1;
        };
        self.values.shrinkRetainingCapacity(write);
    }
};
