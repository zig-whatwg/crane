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
    const kind = comptime internalKind(OwnFields);
    const Own = if (kind == .embedded or kind == .empty) WithoutInternal(OwnFields) else OwnFields;
    const Live = if (BaseType == null and kind == .embedded) LiveWord else void;
    return struct {
        /// Base type state (if inherits from another interface)
        base: if (BaseType) |B| B else void,

        /// Mixin fields (flattened from all mixins)
        mixins: MixinFieldsStruct(MixinTypes),

        /// Own fields (defined by this interface) - less `_internal` when
        /// the impl's state is kept by value here or is empty
        /// (`internal_kind`).
        own: Own,

        /// The impl's InternalState BY VALUE, when it is kept in this State
        /// (runtime.OwnState) - else void, 0 bytes (`Embedded`). Lane perf2
        /// batch 5 (Z7; tmp/plans/perf2b5-design.md 3.2): every level of a
        /// node keeps its state here, at a comptime offset inside its own
        /// State, which a derived State nests through `base` - so a node's
        /// whole chain is ONE allocation, as Blink, WebKit and Gecko lay a
        /// node out by inheritance and Lightpanda's Factory makes "1 large
        /// allocation for the total size" of the chain (`chainOffsetOf`).
        /// Made zeroed with the State (Instance.init).
        _embedded: Embedded(OwnFields) = undefined,

        /// The chain's live word, at its root only (else void, 0 bytes): bit
        /// `d` set while the level `d` steps above the root has its embedded
        /// state made and not yet torn down (runtime.OwnState's `create` and
        /// `remove`). Lane perf2 batch 6: it replaces a pointer per level -
        /// `own._internal`, which pointed at `_embedded` or was null, 8
        /// bytes a level, five on a div - with 4 bytes per object, as Blink
        /// keeps such facts as bits of the node (Node::node_flags_), not as
        /// pointers to itself. Zeroed with the State: nothing is live.
        _live: Live = std.mem.zeroes(Live),

        /// How this level keeps its impl's InternalState (`InternalKind`).
        pub const internal_kind: InternalKind = kind;

        /// Check if a field exists by name (compile-time only)
        /// This is used for reflection and code generation
        pub fn hasField(comptime name: []const u8) bool {
            // Check own fields
            const own_info = @typeInfo(Own);
            if (own_info == .@"struct") {
                inline for (own_info.@"struct".field_names) |field_name| {
                    if (std.mem.eql(u8, field_name, name)) return true;
                }
            }

            // Check mixin fields
            const MixinStruct = MixinFieldsStruct(MixinTypes);
            const mixin_info = @typeInfo(MixinStruct);
            if (mixin_info == .@"struct") {
                inline for (mixin_info.@"struct".field_names) |field_name| {
                    if (std.mem.eql(u8, field_name, name)) return true;
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

/// The live word's type (`FlattenedState._live`): a bit per level of a chain,
/// so a chain may be up to 32 levels deep (runtime.OwnState checks it).
pub const LiveWord = u32;

/// How a level of a generated State keeps its impl's InternalState, read from
/// the type its generated `own._internal: ?*T` points at - so the runtime
/// names no impl (lane perf2 batch 6).
pub const InternalKind = enum {
    /// No `_internal` field: a hand-written State.
    none,
    /// `T` lives in a block of its own, reached through `own._internal`
    /// (runtime.InstanceRegistry, or set by its impl).
    pointer,
    /// `T` is kept by value in the State (`_embedded`; it declares
    /// `pub const embedded_in_state = true`, runtime.OwnState): no pointer,
    /// a bit of the root's live word says whether it is made.
    embedded,
    /// `T` has no fields (`InternalState = struct {}`, the impls that keep no
    /// state): there is nothing to point at, and no pointer is kept.
    empty,
};

/// The type `own._internal` points at, or null for none.
fn InternalTarget(comptime OwnFields: type) ?type {
    if (@typeInfo(OwnFields) != .@"struct" or !@hasField(OwnFields, "_internal")) return null;
    const Field = @FieldType(OwnFields, "_internal");
    const optional = @typeInfo(Field);
    if (optional != .optional) return null;
    const pointer = @typeInfo(optional.optional.child);
    if (pointer != .pointer or pointer.pointer.size != .one) return null;
    return pointer.pointer.child;
}

/// `OwnFields`' InternalKind.
pub fn internalKind(comptime OwnFields: type) InternalKind {
    const T = InternalTarget(OwnFields) orelse return .none;
    if (@typeInfo(T) != .@"struct") return .pointer;
    if (@hasDecl(T, "embedded_in_state") and T.embedded_in_state) return .embedded;
    if (@typeInfo(T).@"struct".field_names.len == 0) return .empty;
    return .pointer;
}

/// `OwnFields` less its `_internal` field: the same fields, in the same
/// order, with their defaults.
fn WithoutInternal(comptime OwnFields: type) type {
    const info = @typeInfo(OwnFields).@"struct";
    const count = info.field_names.len - 1;
    var names: [count][:0]const u8 = undefined;
    var types: [count]type = undefined;
    var attrs: [count]std.builtin.Type.Struct.FieldAttributes = undefined;
    var at: usize = 0;
    for (info.field_names, info.field_types, info.field_attrs) |name, field_type, field_attrs| {
        if (std.mem.eql(u8, name, "_internal")) continue;
        names[at] = name;
        types[at] = field_type;
        attrs[at] = field_attrs;
        at += 1;
    }
    return @Struct(.auto, null, &names, &types, &attrs);
}

/// The InternalState a State keeps by value (`_embedded`): the type
/// `OwnFields._internal` points at, when that type declares
/// `pub const embedded_in_state = true` - the marker every runtime.OwnState
/// user's InternalState carries - and void otherwise. Read from the field's
/// type, so the runtime names no impl.
pub fn Embedded(comptime OwnFields: type) type {
    if (internalKind(OwnFields) != .embedded) return void;
    return InternalTarget(OwnFields).?;
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
        total_fields += mixin_info.@"struct".field_names.len;
    }

    // Build the three parallel arrays @Struct takes. Zig 0.16 removed @Type in
    // favour of @Int/@Struct/@Enum/@Tuple/@Pointer/@Fn, and @Struct does not
    // accept a []const StructField - it takes names, types and attributes
    // separately, so the single field array has to be split.
    var names: [total_fields][:0]const u8 = undefined;
    var types: [total_fields]type = undefined;
    var attrs: [total_fields]std.builtin.Type.Struct.FieldAttributes = undefined;
    comptime var field_index: usize = 0;

    // Collect fields from all mixins
    inline for (MixinTypes) |MixinType| {
        const mixin_info = @typeInfo(MixinType).@"struct";
        inline for (mixin_info.field_names, mixin_info.field_types, mixin_info.field_attrs) |field_name, field_type, field_attrs| {
            names[field_index] = field_name;
            types[field_index] = field_type;
            attrs[field_index] = field_attrs;
            field_index += 1;
        }
    }

    // Create merged struct type. `.auto` layout, no backing integer - the same
    // shape the old @Type call produced. Reified types cannot carry decls in
    // 0.16 either, so nothing is lost by the empty decls list going away.
    return @Struct(.auto, null, &names, &types, &attrs);
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
