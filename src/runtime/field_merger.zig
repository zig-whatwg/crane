//! Compile-time field composition for WebIDL interface state
//!
//! This module provides compile-time utilities for composing interface state
//! from multiple sources:
//! - Base type fields (from inherited interface)
//! - Mixin type fields (from interface mixins)
//! - Own fields (from the interface itself)
//!
//! WebIDL interfaces support inheritance and mixins:
//! - Node inherits from EventTarget
//! - Element inherits from Node and includes mixins
//! - HTMLElement inherits from Element
//!
//! The field merger flattens this hierarchy into a single efficient struct.

const std = @import("std");

/// Flatten base + mixins + own fields into a single struct
///
/// This function composes a final state struct from:
/// - BaseType: The parent interface's state (null for root interfaces)
/// - MixinTypes: Array of mixin interface states
/// - OwnFields: The interface's own fields
///
/// Example:
///   // Element inherits from Node and includes mixins
///   const ElementState = FlattenedState(
///       Node.State,           // Base type
///       &[_]type{},          // No mixins for Element
///       ElementOwnFields,    // Element's own fields
///   );
///
///   // ElementState will contain:
///   // .base (Node.State, which contains EventTarget.State)
///   // .mixins (empty struct for Element)
///   // .own (ElementOwnFields)
pub fn FlattenedState(
    comptime BaseType: ?type,
    comptime MixinTypes: []const type,
    comptime OwnFields: type,
) type {
    return struct {
        /// Base type state (if inherits from another interface)
        base: if (BaseType) |B| B else void,

        /// Mixin fields (flattened from all mixins)
        mixins: MixinFieldsStruct(MixinTypes),

        /// Own fields (defined by this interface)
        own: OwnFields,

        /// Check if a field exists by name (compile-time only)
        /// This is used for reflection and code generation
        pub fn hasField(comptime name: []const u8) bool {
            // Check own fields
            const own_info = @typeInfo(OwnFields);
            if (own_info == .@"struct") {
                inline for (own_info.@"struct".fields) |field| {
                    if (std.mem.eql(u8, field.name, name)) return true;
                }
            }

            // Check mixin fields
            const MixinStruct = MixinFieldsStruct(MixinTypes);
            const mixin_info = @typeInfo(MixinStruct);
            if (mixin_info == .@"struct") {
                inline for (mixin_info.@"struct".fields) |field| {
                    if (std.mem.eql(u8, field.name, name)) return true;
                }
            }

            // Check base fields recursively
            if (BaseType) |B| {
                if (@hasDecl(B, "hasField")) {
                    return B.hasField(name);
                }
            }

            return false;
        }
    };
}

/// Build a struct containing all mixin fields
///
/// Takes an array of mixin types and merges their fields into a single struct.
/// If no mixins, returns an empty struct (void-sized).
///
/// Example:
///   const Mixin1 = struct {
///       field1: u32,
///   };
///   const Mixin2 = struct {
///       field2: []const u8,
///   };
///   const MixinStruct = MixinFieldsStruct(&[_]type{Mixin1, Mixin2});
///   // MixinStruct contains both field1 and field2
fn MixinFieldsStruct(comptime MixinTypes: []const type) type {
    if (MixinTypes.len == 0) {
        // No mixins - return empty struct
        return struct {};
    }

    // Count total fields across all mixins
    comptime var total_fields: usize = 0;
    inline for (MixinTypes) |MixinType| {
        const mixin_info = @typeInfo(MixinType);
        if (mixin_info != .@"struct") {
            @compileError("Mixin type must be a struct");
        }
        total_fields += mixin_info.@"struct".fields.len;
    }

    // Build field array
    var fields: [total_fields]std.builtin.Type.StructField = undefined;
    comptime var field_index: usize = 0;

    // Collect fields from all mixins
    inline for (MixinTypes) |MixinType| {
        const mixin_info = @typeInfo(MixinType).@"struct";
        inline for (mixin_info.fields) |field| {
            fields[field_index] = field;
            field_index += 1;
        }
    }

    // Create merged struct type
    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

/// Merge multiple struct types into one (alternative approach)
///
/// This is useful when you want to merge struct instances, not just types.
pub fn mergeStructs(comptime structs: []const type) type {
    return MixinFieldsStruct(structs);
}

// Unit tests
const testing = std.testing;

test "FlattenedState with no base, no mixins" {
    const OwnFields = struct {
        value: u32,
    };

    const State = FlattenedState(null, &[_]type{}, OwnFields);

    var state: State = undefined;
    state.own.value = 42;

    try testing.expectEqual(@as(u32, 42), state.own.value);
    try testing.expect(State.hasField("value"));
    try testing.expect(!State.hasField("nonexistent"));
}

test "FlattenedState with base, no mixins" {
    const BaseFields = struct {
        base_value: u32,
    };

    const Base = struct {
        base: BaseFields,
        mixins: struct {},
        own: struct {},

        pub fn hasField(comptime name: []const u8) bool {
            return std.mem.eql(u8, name, "base_value");
        }
    };

    const OwnFields = struct {
        own_value: u64,
    };

    const State = FlattenedState(Base, &[_]type{}, OwnFields);

    var state: State = undefined;
    state.base.base.base_value = 100;
    state.own.own_value = 200;

    try testing.expectEqual(@as(u32, 100), state.base.base.base_value);
    try testing.expectEqual(@as(u64, 200), state.own.own_value);

    try testing.expect(State.hasField("own_value"));
    try testing.expect(State.hasField("base_value")); // From base
}

test "FlattenedState with mixins" {
    const Mixin1 = struct {
        mixin1_field: u8,
    };

    const Mixin2 = struct {
        mixin2_field: u16,
    };

    const OwnFields = struct {
        own_field: u32,
    };

    const State = FlattenedState(null, &[_]type{ Mixin1, Mixin2 }, OwnFields);

    var state: State = undefined;
    state.mixins.mixin1_field = 1;
    state.mixins.mixin2_field = 2;
    state.own.own_field = 3;

    try testing.expectEqual(@as(u8, 1), state.mixins.mixin1_field);
    try testing.expectEqual(@as(u16, 2), state.mixins.mixin2_field);
    try testing.expectEqual(@as(u32, 3), state.own.own_field);

    try testing.expect(State.hasField("own_field"));
    try testing.expect(State.hasField("mixin1_field"));
    try testing.expect(State.hasField("mixin2_field"));
}

test "FlattenedState with base and mixins" {
    const BaseFields = struct {
        base_field: u8,
    };

    const Base = struct {
        base: BaseFields,
        mixins: struct {},
        own: struct {},

        pub fn hasField(comptime name: []const u8) bool {
            return std.mem.eql(u8, name, "base_field");
        }
    };

    const Mixin1 = struct {
        mixin_field: u16,
    };

    const OwnFields = struct {
        own_field: u32,
    };

    const State = FlattenedState(Base, &[_]type{Mixin1}, OwnFields);

    var state: State = undefined;
    state.base.base.base_field = 10;
    state.mixins.mixin_field = 20;
    state.own.own_field = 30;

    try testing.expectEqual(@as(u8, 10), state.base.base.base_field);
    try testing.expectEqual(@as(u16, 20), state.mixins.mixin_field);
    try testing.expectEqual(@as(u32, 30), state.own.own_field);

    try testing.expect(State.hasField("base_field"));
    try testing.expect(State.hasField("mixin_field"));
    try testing.expect(State.hasField("own_field"));
}

test "MixinFieldsStruct empty mixins" {
    const MixinStruct = MixinFieldsStruct(&[_]type{});
    const mixins: MixinStruct = .{};
    _ = mixins;

    // Should be empty struct
    try testing.expectEqual(@as(usize, 0), @sizeOf(MixinStruct));
}

test "MixinFieldsStruct single mixin" {
    const Mixin = struct {
        field1: u32,
        field2: u64,
    };

    const MixinStruct = MixinFieldsStruct(&[_]type{Mixin});

    var mixins: MixinStruct = undefined;
    mixins.field1 = 100;
    mixins.field2 = 200;

    try testing.expectEqual(@as(u32, 100), mixins.field1);
    try testing.expectEqual(@as(u64, 200), mixins.field2);
}

test "MixinFieldsStruct multiple mixins" {
    const Mixin1 = struct {
        a: u8,
    };

    const Mixin2 = struct {
        b: u16,
    };

    const Mixin3 = struct {
        c: u32,
    };

    const MixinStruct = MixinFieldsStruct(&[_]type{ Mixin1, Mixin2, Mixin3 });

    var mixins: MixinStruct = undefined;
    mixins.a = 1;
    mixins.b = 2;
    mixins.c = 3;

    try testing.expectEqual(@as(u8, 1), mixins.a);
    try testing.expectEqual(@as(u16, 2), mixins.b);
    try testing.expectEqual(@as(u32, 3), mixins.c);
}

test "mergeStructs works" {
    const Struct1 = struct {
        x: u32,
    };

    const Struct2 = struct {
        y: u64,
    };

    const Merged = mergeStructs(&[_]type{ Struct1, Struct2 });

    var merged: Merged = undefined;
    merged.x = 10;
    merged.y = 20;

    try testing.expectEqual(@as(u32, 10), merged.x);
    try testing.expectEqual(@as(u64, 20), merged.y);
}
