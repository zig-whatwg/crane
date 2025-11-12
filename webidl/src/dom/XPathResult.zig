//! XPathResult interface - DOM §6.4

const std = @import("std");
const Node = @import("node").Node;
const Value = @import("dom").xpath.value.Value;
const NodeSet = @import("dom").xpath.value.NodeSet;

pub const XPathResult = struct {
    allocator: std.mem.Allocator,
    result_type: u16,
    value: Value,
    iterator_index: usize,

    // Constants
    pub const ANY_TYPE: u16 = 0;
    pub const NUMBER_TYPE: u16 = 1;
    pub const STRING_TYPE: u16 = 2;
    pub const BOOLEAN_TYPE: u16 = 3;
    pub const UNORDERED_NODE_ITERATOR_TYPE: u16 = 4;
    pub const ORDERED_NODE_ITERATOR_TYPE: u16 = 5;
    pub const UNORDERED_NODE_SNAPSHOT_TYPE: u16 = 6;
    pub const ORDERED_NODE_SNAPSHOT_TYPE: u16 = 7;
    pub const ANY_UNORDERED_NODE_TYPE: u16 = 8;
    pub const FIRST_ORDERED_NODE_TYPE: u16 = 9;

    pub fn init(allocator: std.mem.Allocator, result_type: u16, value: Value) !*XPathResult {
        const self = try allocator.create(XPathResult);
        self.* = .{
            .allocator = allocator,
            .result_type = result_type,
            .value = value,
            .iterator_index = 0,
        };
        return self;
    }

    pub fn deinit(self: *XPathResult) void {
        var val = self.value;
        val.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn getResultType(self: *const XPathResult) u16 {
        return self.result_type;
    }

    pub fn getNumberValue(self: *const XPathResult) !f64 {
        return switch (self.value) {
            .number => |n| n,
            else => error.TypeMismatch,
        };
    }

    pub fn getStringValue(self: *XPathResult) ![]const u8 {
        return switch (self.value) {
            .string => |s| s,
            else => error.TypeMismatch,
        };
    }

    pub fn getBooleanValue(self: *const XPathResult) !bool {
        return switch (self.value) {
            .boolean => |b| b,
            else => error.TypeMismatch,
        };
    }

    pub fn getSingleNodeValue(self: *const XPathResult) !?*Node {
        return switch (self.value) {
            .node_set => |ns| ns.getFirst(),
            else => error.TypeMismatch,
        };
    }

    pub fn getSnapshotLength(self: *const XPathResult) !usize {
        return switch (self.value) {
            .node_set => |ns| ns.size(),
            else => error.TypeMismatch,
        };
    }

    pub fn iterateNext(self: *XPathResult) !?*Node {
        const ns = switch (self.value) {
            .node_set => |n| n,
            else => return error.TypeMismatch,
        };

        if (self.iterator_index >= ns.size()) {
            return null;
        }

        const node = ns.get(self.iterator_index);
        self.iterator_index += 1;
        return node;
    }

    pub fn snapshotItem(self: *const XPathResult, index: usize) !?*Node {
        const ns = switch (self.value) {
            .node_set => |n| n,
            else => return error.TypeMismatch,
        };

        return ns.get(index);
    }
};
