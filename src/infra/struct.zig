//! WHATWG Infra Struct Operations
//!
//! Spec: https://infra.spec.whatwg.org/#struct
//!
//! A struct is a specification type with named fields. In Zig, Infra structs
//! map directly to Zig structs with named fields.
//!
//! # Design
//!
//! Infra structs are compile-time defined types in Zig. The spec describes
//! structs as "a specification type consisting of named fields", which maps
//! naturally to Zig's struct type system.
//!
//! # Usage
//!
//! ```zig
//! // Define an Infra struct
//! const Person = struct {
//!     name: []const u8,
//!     age: u32,
//! };
//!
//! // Create instance
//! const person = Person{
//!     .name = "Alice",
//!     .age = 30,
//! };
//!
//! // Access fields
//! const name = person.name;
//! const age = person.age;
//! ```
//!
//! # Note
//!
//! Since Infra structs map directly to Zig structs, there's no need for
//! additional wrapper types or operations. This module exists primarily
//! for documentation and to provide helper utilities if needed.

const std = @import("std");

test "struct - basic usage" {
    const TestStruct = struct {
        field1: u32,
        field2: []const u8,
    };

    const instance = TestStruct{
        .field1 = 42,
        .field2 = "hello",
    };

    try std.testing.expectEqual(@as(u32, 42), instance.field1);
    try std.testing.expectEqualStrings("hello", instance.field2);
}

test "struct - nested structs" {
    const Inner = struct {
        value: u32,
    };

    const Outer = struct {
        inner: Inner,
        name: []const u8,
    };

    const instance = Outer{
        .inner = Inner{ .value = 100 },
        .name = "outer",
    };

    try std.testing.expectEqual(@as(u32, 100), instance.inner.value);
    try std.testing.expectEqualStrings("outer", instance.name);
}

test "struct - optional fields" {
    const OptionalStruct = struct {
        required: u32,
        optional: ?[]const u8,
    };

    const with_optional = OptionalStruct{
        .required = 42,
        .optional = "present",
    };

    const without_optional = OptionalStruct{
        .required = 42,
        .optional = null,
    };

    try std.testing.expectEqual(@as(u32, 42), with_optional.required);
    try std.testing.expectEqualStrings("present", with_optional.optional.?);

    try std.testing.expectEqual(@as(u32, 42), without_optional.required);
    try std.testing.expectEqual(@as(?[]const u8, null), without_optional.optional);
}

test "struct - default field values" {
    const DefaultStruct = struct {
        value: u32 = 100,
        name: []const u8 = "default",
    };

    const with_defaults = DefaultStruct{};
    const with_custom = DefaultStruct{ .value = 200 };

    try std.testing.expectEqual(@as(u32, 100), with_defaults.value);
    try std.testing.expectEqualStrings("default", with_defaults.name);

    try std.testing.expectEqual(@as(u32, 200), with_custom.value);
    try std.testing.expectEqualStrings("default", with_custom.name);
}

test "struct - methods" {
    const Rectangle = struct {
        width: u32,
        height: u32,

        pub fn area(self: @This()) u32 {
            return self.width * self.height;
        }
    };

    const rect = Rectangle{ .width = 10, .height = 5 };
    try std.testing.expectEqual(@as(u32, 50), rect.area());
}
