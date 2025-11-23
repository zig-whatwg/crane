//! V8 Value Type Implementation
//!
//! Concrete implementation of the abstract Value interface for V8.
//! In real V8 integration, this would wrap v8::Local<v8::Value>.

const std = @import("std");

/// Mock V8 Array for testing
///
/// In real V8, this would be v8::Local<v8::Array>
pub const MockV8Array = struct {
    items: std.ArrayList(Value),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MockV8Array {
        return .{
            .items = std.ArrayList(Value){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MockV8Array) void {
        // Note: We don't free strings here because they might be string literals
        // In real V8, string handles would be managed by V8's GC
        // Caller is responsible for string lifetime management
        self.items.deinit(self.allocator);
    }

    pub fn append(self: *MockV8Array, value: Value) !void {
        try self.items.append(self.allocator, value);
    }

    pub fn length(self: *const MockV8Array) u32 {
        return @intCast(self.items.items.len);
    }

    pub fn get(self: *const MockV8Array, index: u32) ?Value {
        if (index >= self.items.items.len) return null;
        return self.items.items[index];
    }
};

/// V8 Value - concrete implementation
///
/// In real V8 integration, this would be v8::Local<v8::Value>
/// For now, it's a mock handle representing different V8 types
pub const Value = union(enum) {
    undefined: void,
    null_value: void,
    boolean: bool,
    int32: i32,
    uint32: u32,
    int64: i64,
    uint64: u64,
    float: f32,
    double: f64,
    string: []const u8,
    object: usize, // Mock object handle
    array: *MockV8Array, // Mock array
    bigint: i64,

    /// Check if value is undefined
    pub fn isUndefined(self: Value) bool {
        return self == .undefined;
    }

    /// Check if value is null
    pub fn isNull(self: Value) bool {
        return self == .null_value;
    }

    /// Check if value is nullish (null or undefined)
    pub fn isNullish(self: Value) bool {
        return self.isNull() or self.isUndefined();
    }

    /// Check if value is boolean
    pub fn isBoolean(self: Value) bool {
        return self == .boolean;
    }

    /// Check if value is number
    pub fn isNumber(self: Value) bool {
        return switch (self) {
            .int32, .uint32, .int64, .uint64, .float, .double => true,
            else => false,
        };
    }

    /// Check if value is string
    pub fn isString(self: Value) bool {
        return self == .string;
    }

    /// Check if value is object
    pub fn isObject(self: Value) bool {
        return self == .object;
    }

    /// Check if value is array
    pub fn isArray(self: Value) bool {
        return self == .array;
    }
};
