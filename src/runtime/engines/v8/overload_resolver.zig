//! WebIDL constructor overload resolution.
//!
//! Spec: https://webidl.spec.whatwg.org/#dfn-overload-resolution-algorithm
//!
//! An interface with several constructors takes its generated
//! `ConstructorArgs`, a union with a variant per constructor, and codegen
//! describes the same constructors, in the same order, in
//! `constructor_overloads` - the table an overloaded operation has
//! (`overloads`). The overload resolution algorithm
//! (`webidl.overload_resolution.select`) picks the constructor from the
//! arguments' count and, where that is not enough, the type of the value at
//! the distinguishing argument index; only then are the arguments converted,
//! to that constructor's types (steps 11, 15 and 16), and a conversion that
//! throws is the constructor call's exception.
//!
//! This replaced trying each variant in turn until one converted: a
//! conversion that threw in one variant was left pending while the next was
//! tried (and its getters ran again), a value of the wrong type converted
//! happily into the first variant that would take it (an XRRigidTransform
//! into XRRay's DOMPointInit), and a constructor whose one argument is a
//! dictionary (OfflineAudioContext(contextOptions)) was taken for a struct
//! of arguments.

const std = @import("std");
const v8 = @import("ffi.zig");
const interface_mod = @import("interface.zig");
const webidl = @import("webidl");

/// The overload table's types, re-exported for tests/v8 (whose target does
/// not import `webidl`).
pub const Overload = webidl.overload_resolution.Overload;
pub const Kind = webidl.overload_resolution.Kind;

/// The overload resolution algorithm over `overloads` - the constructors of
/// `UnionType`, one entry per variant in its order - with the call's
/// arguments, and the chosen variant built from them.
///
/// Errors: `error.TypeError` where the algorithm throws one (no constructor
/// takes this many arguments, or none takes the value at the distinguishing
/// index); `error.ExceptionPending` where script threw - a GetMethod during
/// selection, or a conversion; and whatever a conversion fails with.
pub fn resolveConstructorOverload(
    comptime UnionType: type,
    comptime overloads: []const Overload,
    info: *const v8.FunctionCallbackInfo,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
) !UnionType {
    const fields = @typeInfo(UnionType).@"union".fields;
    comptime std.debug.assert(fields.len == overloads.len);

    // Steps 1-12: the entry of S the arguments select.
    var args = interface_mod.OverloadArgs{ .info = info, .isolate = isolate };
    defer args.release();
    const arg_count: usize = @intCast(@max(info.length(), 0));
    const chosen = webidl.overload_resolution.select(overloads, arg_count, &args) catch |err| switch (err) {
        error.TypeError => {
            args.release();
            // Step 12.20 throws only after step 11 has converted the
            // arguments before the distinguishing index - and an exception
            // one of those conversions throws is the one script sees.
            if (webidl.overload_resolution.distinguishingPrefix(overloads, arg_count)) |prefix| {
                try convertPrefix(UnionType, overloads, prefix, info, allocator, isolate, context);
            }
            return error.TypeError;
        },
        // GetMethod (steps 12.9/12.10) threw: the exception is pending.
        error.JavaScriptException => return error.ExceptionPending,
    };
    args.release();

    // Steps 11, 13 and 15-16: convert the arguments to the chosen
    // constructor's types. The entries left in S agree on every type before
    // the distinguishing index, so converting them as the chosen one's is
    // step 11.
    inline for (fields, 0..) |field, k| {
        if (k == chosen) return buildVariant(UnionType, field, overloads[k].args.len, info, allocator, isolate, context);
    }
    unreachable;
}

/// Step 11 alone: convert, and free again, the arguments before the
/// distinguishing index as variant `prefix.entry`'s - for a call step 12 is
/// about to reject, so that what those conversions run (a toString(), a
/// dictionary's getters) runs, and what they throw is thrown.
fn convertPrefix(
    comptime UnionType: type,
    comptime overloads: []const Overload,
    prefix: webidl.overload_resolution.Prefix,
    info: *const v8.FunctionCallbackInfo,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
) !void {
    inline for (@typeInfo(UnionType).@"union".fields, 0..) |field, k| {
        // A variant of one argument has no argument before index 0.
        if (comptime overloads[k].args.len > 1) {
            if (k == prefix.entry) {
                inline for (@typeInfo(field.type).@"struct".fields, 0..) |arg_field, i| {
                    if (i < prefix.d) {
                        const value = try interface_mod.convertArgReleasing(arg_field.type, allocator, isolate, context, info.get(@intCast(i)));
                        interface_mod.freeArgument(arg_field.type, allocator, value);
                    }
                }
            }
        }
    }
}

/// Free what `resolveConstructorOverload` built, once the constructor has
/// returned: each argument of the variant it chose, as the binding frees a
/// non-overloaded constructor's (`interface.freeArgument`) - the strings it
/// copied, the dictionaries it read, the handles an `any` or a buffer source
/// kept. The impl borrowed them for the call; one that keeps a value takes
/// its own copy or hold. Nothing freed them before: `new URLPattern(...)`
/// leaked its input and base URL on every call.
pub fn freeConstructorOverload(comptime UnionType: type, comptime overloads: []const Overload, allocator: std.mem.Allocator, args: UnionType) void {
    switch (args) {
        inline else => |payload, tag| {
            const VariantType = @TypeOf(payload);
            if (VariantType == void) return;
            // The shapes buildVariant makes: one argument is the variant
            // itself (a dictionary too, though it is a struct); more are a
            // struct with a field per argument.
            const arity = comptime overloads[@intFromEnum(tag)].args.len;
            if (comptime arity > 1) {
                inline for (@typeInfo(VariantType).@"struct".fields) |field| {
                    interface_mod.freeArgument(field.type, allocator, @field(payload, field.name));
                }
            } else {
                interface_mod.freeArgument(VariantType, allocator, payload);
            }
        },
    }
}

/// Build the union variant `field`, whose constructor declares `arity`
/// arguments, from the call's arguments. An argument past the ones passed
/// reads as undefined - "missing" for an optional one (a `webidl.Opt` not
/// passed), which is all step 16 leaves: the algorithm chose an entry of
/// exactly the length passed (capped at the longest), so every argument past
/// it is optional.
fn buildVariant(
    comptime UnionType: type,
    comptime field: std.builtin.Type.UnionField,
    comptime arity: usize,
    info: *const v8.FunctionCallbackInfo,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
) !UnionType {
    const VariantType = field.type;

    // Case 0: No-parameter variant (void)
    if (comptime arity == 0) {
        return @unionInit(UnionType, field.name, {});
    }

    const type_info = @typeInfo(VariantType);

    // Case 1: one argument - the variant itself, whatever its type (a
    // dictionary is a struct, but one argument).
    if (comptime arity == 1) {
        // `info.get` makes a Global per call: released by the binding's
        // argument rule (interface.convertArgReleasing), or every call
        // leaked one.
        const v8_arg = info.get(0);
        const arg_value = try interface_mod.convertArgReleasing(
            VariantType,
            allocator,
            isolate,
            context,
            v8_arg,
        );

        // Build union with this variant
        return @unionInit(UnionType, field.name, arg_value);
    }

    // Case 2: Multi-parameter variant (struct with multiple fields)
    var variant_struct: VariantType = undefined;
    // An argument that fails to convert ends the call with the arguments
    // before it converted - a string copied, an `any`'s handle kept - and
    // they are freed here: kept, every `new URLPattern(input, baseURL)`
    // whose base URL failed leaked its input.
    var converted: usize = 0;
    errdefer inline for (type_info.@"struct".fields, 0..) |struct_field, i| {
        if (i < converted) interface_mod.freeArgument(struct_field.type, allocator, @field(variant_struct, struct_field.name));
    };

    // Convert each JavaScript argument to corresponding struct field
    inline for (type_info.@"struct".fields, 0..) |struct_field, i| {
        const v8_arg = info.get(@intCast(i));
        const field_value = try interface_mod.convertArgReleasing(
            struct_field.type,
            allocator,
            isolate,
            context,
            v8_arg,
        );
        @field(variant_struct, struct_field.name) = field_value;
        converted += 1;
    }

    // Build union with the populated struct
    return @unionInit(UnionType, field.name, variant_struct);
}

// ============================================================================
// Tests
// ============================================================================

test "overload resolver compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}
