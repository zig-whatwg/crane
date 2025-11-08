//! WHATWG Infra Standard Implementation
//!
//! Spec: https://infra.spec.whatwg.org/
//!
//! This library implements the WHATWG Infra Standard, providing primitive
//! data types and algorithms used by other WHATWG specifications (DOM, Fetch,
//! URL, etc.).

const std = @import("std");

pub const string = @import("string.zig");
pub const code_point = @import("code_point.zig");
pub const bytes = @import("bytes.zig");
pub const list = @import("list.zig");
pub const map = @import("map.zig");
pub const set = @import("set.zig");
pub const stack = @import("stack.zig");
pub const queue = @import("queue.zig");
pub const infra_struct = @import("struct.zig");
pub const tuple = @import("tuple.zig");
pub const json = @import("json.zig");
pub const base64 = @import("base64.zig");
pub const namespaces = @import("namespaces.zig");
pub const time = @import("time.zig");

pub const String = string.String;
pub const CodePoint = code_point.CodePoint;
pub const ByteSequence = bytes.ByteSequence;
pub const List = list.List;
pub const ListWithCapacity = list.ListWithCapacity;
pub const OrderedMap = map.OrderedMap;
pub const OrderedSet = set.OrderedSet;
pub const Stack = stack.Stack;
pub const Queue = queue.Queue;
pub const InfraValue = json.InfraValue;
pub const InfraError = string.InfraError;
pub const Moment = time.Moment;
pub const Duration = time.Duration;

// Numeric type aliases for clarity
// WHATWG Infra Standard §4.3
pub const U8 = u8;
pub const U16 = u16;
pub const U32 = u32;
pub const U64 = u64;
pub const U128 = u128;
pub const I8 = i8;
pub const I16 = i16;
pub const I32 = i32;
pub const I64 = i64;

/// An IPv6 address is a 128-bit unsigned integer.
/// WHATWG Infra Standard §4.3
pub const IPv6Address = u128;

test {
    std.testing.refAllDecls(@This());
}
