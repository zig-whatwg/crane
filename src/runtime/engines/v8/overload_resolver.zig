//! WebIDL Constructor Overload Resolution
//!
//! This module handles resolving overloaded constructors by matching JavaScript
//! arguments to the appropriate ConstructorArgs union variant.
//!
//! WebIDL allows interfaces to have multiple constructor signatures (overloading).
//! When JavaScript calls a constructor, we need to determine which overload variant
//! matches the provided arguments and build the appropriate union.

const std = @import("std");
const v8 = @import("ffi.zig");
const conv = @import("conversions.zig");

/// Resolve constructor overload by matching JavaScript arguments to union variant
///
/// This function inspects the ConstructorArgs union type at compile time,
/// examines the JavaScript arguments at runtime, and builds the matching variant.
///
/// Algorithm:
/// 1. Get all union variants at comptime
/// 2. For each variant, check if it matches the JavaScript arguments
/// 3. When a match is found, convert arguments and build the variant
/// 4. Return the constructed union
///
/// Example:
/// ```zig
/// // Interface has: union(enum) { Variant1: Type1, Variant2: struct { a: T1, b: T2 } }
/// const args = try resolveConstructorOverload(
///     Interface.ConstructorArgs,
///     info,
///     allocator,
///     isolate,
///     context
/// );
/// return try Interface.call_constructor(allocator, ctx, args);
/// ```
pub fn resolveConstructorOverload(
    comptime UnionType: type,
    info: *const v8.FunctionCallbackInfo,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
) !UnionType {
    const union_info = @typeInfo(UnionType).@"union";
    const js_arg_count = info.length();

    // Try each variant in order (WebIDL spec says to try in declaration order)
    inline for (union_info.fields) |field| {
        // Calculate expected argument count for this variant
        const variant_arg_count = countVariantArgs(field.type);

        // Check if this variant matches the JavaScript argument count
        // WebIDL allows fewer arguments (trailing optional parameters)
        if (js_arg_count >= variant_arg_count) {
            // Try to build this variant
            if (buildVariant(
                UnionType,
                field,
                info,
                allocator,
                isolate,
                context,
            )) |variant_result| {
                // Successfully built this variant
                return variant_result;
            } else |_| {
                // If building fails, try next variant
                // Common failures: type mismatch, conversion error
                // (continue to next iteration)
            }
        }
    }

    // No matching overload found
    return error.NoMatchingOverload;
}

/// Count the number of required arguments for a variant type
fn countVariantArgs(comptime VariantType: type) usize {
    // No-parameter variant (void)
    if (VariantType == void) {
        return 0;
    }

    const type_info = @typeInfo(VariantType);

    // Single-parameter variant (e.g., .CSSNumericValue: CSSNumericValue)
    if (type_info != .@"struct") {
        return 1;
    }

    // Multi-parameter variant (e.g., .Variant: struct { a: T1, b: T2 })
    // Count struct fields
    return type_info.@"struct".fields.len;
}

/// Build a union variant from JavaScript arguments
fn buildVariant(
    comptime UnionType: type,
    comptime field: std.builtin.Type.UnionField,
    info: *const v8.FunctionCallbackInfo,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
) !UnionType {
    const VariantType = field.type;

    // Case 0: No-parameter variant (void)
    if (VariantType == void) {
        return @unionInit(UnionType, field.name, {});
    }

    const type_info = @typeInfo(VariantType);

    // Case 1: Single-parameter variant
    if (type_info != .@"struct") {
        // Convert first JavaScript argument to variant type
        const v8_arg = info.get(0);
        const arg_value = try conv.fromV8Value(
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

    // Convert each JavaScript argument to corresponding struct field
    inline for (type_info.@"struct".fields, 0..) |struct_field, i| {
        const v8_arg = info.get(@intCast(i));
        const field_value = try conv.fromV8Value(
            struct_field.type,
            allocator,
            isolate,
            context,
            v8_arg,
        );
        @field(variant_struct, struct_field.name) = field_value;
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
