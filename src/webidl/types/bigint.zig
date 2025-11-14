//! WebIDL BigInt Type Support
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-bigint
//!
//! BigInt represents arbitrary-precision integers in JavaScript.
//! For the stub implementation, we use i64/u64 storage.

const std = @import("std");
const primitives = @import("primitives.zig");

/// BigInt represents an arbitrary-precision integer.
/// Stub implementation using i64 storage.
pub const BigInt = struct {
    value: i64,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .value = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn fromI64(allocator: std.mem.Allocator, n: i64) !Self {
        return .{
            .value = n,
            .allocator = allocator,
        };
    }

    pub fn fromU64(allocator: std.mem.Allocator, n: u64) !Self {
        if (n > @as(u64, @intCast(std.math.maxInt(i64)))) {
            return error.ValueOutOfRange;
        }
        return .{
            .value = @intCast(n),
            .allocator = allocator,
        };
    }

    pub fn toI64(self: Self) !i64 {
        return self.value;
    }

    pub fn toU64(self: Self) !u64 {
        if (self.value < 0) {
            return error.ValueOutOfRange;
        }
        return @intCast(self.value);
    }

    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        return .{
            .value = self.value,
            .allocator = allocator,
        };
    }

    pub fn isNegative(self: Self) bool {
        return self.value < 0;
    }

    pub fn isZero(self: Self) bool {
        return self.value == 0;
    }
};

/// Convert JavaScript value to WebIDL bigint.
/// Spec: https://webidl.spec.whatwg.org/#es-bigint
pub fn toBigInt(allocator: std.mem.Allocator, value: primitives.JSValue) !BigInt {
    const num = value.toNumber();

    if (std.math.isNan(num) or std.math.isInf(num)) {
        return error.TypeError;
    }

    const int_value: i64 = @intFromFloat(@round(num));
    return BigInt.fromI64(allocator, int_value);
}

/// Convert JavaScript value to WebIDL bigint with [EnforceRange].
/// Spec: https://webidl.spec.whatwg.org/#es-bigint
pub fn toBigIntEnforceRange(allocator: std.mem.Allocator, value: primitives.JSValue) !BigInt {
    const num = value.toNumber();

    if (std.math.isNan(num) or std.math.isInf(num)) {
        return error.TypeError;
    }

    const rounded = @round(num);
    if (num != rounded) {
        return error.TypeError;
    }

    const int_value: i64 = @intFromFloat(rounded);
    return BigInt.fromI64(allocator, int_value);
}

/// Convert JavaScript value to WebIDL bigint with [Clamp].
/// Spec: https://webidl.spec.whatwg.org/#es-bigint
pub fn toBigIntClamped(allocator: std.mem.Allocator, value: primitives.JSValue) !BigInt {
    var num = value.toNumber();

    if (std.math.isNan(num)) {
        return BigInt.fromI64(allocator, 0);
    }

    if (std.math.isInf(num)) {
        if (num > 0) {
            return BigInt.fromI64(allocator, std.math.maxInt(i64));
        } else {
            return BigInt.fromI64(allocator, std.math.minInt(i64));
        }
    }

    num = @round(num);
    const int_value: i64 = @intFromFloat(num);
    return BigInt.fromI64(allocator, int_value);
}

const testing = std.testing;

















// ============================================================================
// WebIDL Type Alias
// ============================================================================

/// WebIDL 'bigint' type - arbitrary-precision integer
pub const bigint_type = BigInt;
