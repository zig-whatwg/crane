//! WebIDL Overload Resolution Algorithm
//!
//! Spec: https://webidl.spec.whatwg.org/#dfn-overload-resolution-algorithm
//!
//! The overload resolution algorithm determines which overloaded operation,
//! constructor, or callback to invoke based on the types of JavaScript arguments.
//!
//! This module provides the infrastructure for code generators to
//! generate correct overload dispatch logic.

const std = @import("std");
const primitives = @import("types/primitives.zig");

const JSValue = primitives.JSValue;

/// Represents an overload entry in an effective overload set
///
/// Spec: § 3.7.9 "effective overload set"
///
/// Each entry contains:
/// - Type list: IDL types for each parameter
/// - Optionality list: whether each parameter is optional
/// - Operation/constructor reference
pub const OverloadEntry = struct {
    /// Parameter types for this overload
    types: []const Type,

    /// Whether each parameter is optional
    optionality: []const Optionality,

    /// Reference to the operation/constructor/callback
    /// In a code generator, this would be a function pointer or identifier
    operation: []const u8,

    pub const Type = enum {
        undefined_type,
        boolean,
        numeric,
        bigint,
        string,
        object,
        interface,
        dictionary,
        sequence,
        frozen_array,
        callback_function,
        nullable,
        union_type,
        any,
    };

    pub const Optionality = enum {
        required,
        optional,
    };
};

/// Effective overload set
///
/// Spec: Collection of all overload entries for a given operation name
pub const EffectiveOverloadSet = struct {
    entries: []const OverloadEntry,

    /// Get distinguishing argument index
    ///
    /// Spec: § 3.7.9 "distinguishing argument index"
    ///
    /// Returns the index of the first argument that differs between overloads.
    /// Returns null if all overloads have identical types up to the shortest length.
    pub fn getDistinguishingArgumentIndex(self: EffectiveOverloadSet) ?usize {
        if (self.entries.len <= 1) return null;

        // Find the minimum argument count
        var min_args: usize = std.math.maxInt(usize);
        for (self.entries) |entry| {
            if (entry.types.len < min_args) {
                min_args = entry.types.len;
            }
        }

        // Find first index where types differ
        var i: usize = 0;
        while (i < min_args) : (i += 1) {
            const first_type = self.entries[0].types[i];
            for (self.entries[1..]) |entry| {
                if (!std.meta.eql(entry.types[i], first_type)) {
                    return i;
                }
            }
        }

        return null;
    }
};

/// Overload resolution result
///
/// Spec: Output of overload resolution algorithm
///
/// Contains:
/// - Selected operation/constructor
/// - Converted argument values or "missing" markers
pub const ResolutionResult = struct {
    operation: []const u8,
    values: []const Value,

    pub const Value = union(enum) {
        missing: void,
        value: JSValue,
    };
};

/// Resolve overload from arguments
///
/// Spec: https://webidl.spec.whatwg.org/#dfn-overload-resolution-algorithm
///
/// Algorithm (simplified):
/// 1. Let maxarg be the length of the longest type list
/// 2. Let n be the size of args
/// 3. Initialize argcount to min(maxarg, n)
/// 4. Remove from S all entries whose type list is not of length argcount
/// 5. If S is empty, throw TypeError
/// 6-12. Perform type discrimination at distinguishing argument index
/// 13. Convert all arguments and return selected operation + values
///
/// TODO(zig-js-runtime): Implement full algorithm with all discrimination steps
/// TODO(zig-js-runtime): Add buffer source type discrimination (steps 6-9)
/// TODO(zig-js-runtime): Add callback discrimination (step 10)
/// TODO(zig-js-runtime): Add async sequence discrimination (step 11)
/// TODO(zig-js-runtime): Add sequence discrimination (step 12)
/// TODO(zig-js-runtime): Add dictionary/record/callback interface discrimination (step 13)
/// TODO(zig-js-runtime): Add boolean/numeric/bigint/string discrimination (steps 14-17)
pub fn resolveOverload(
    allocator: std.mem.Allocator,
    set: EffectiveOverloadSet,
    args: []const JSValue,
) !ResolutionResult {
    // TODO(zig-js-runtime): Implement full overload resolution algorithm
    // For now, return NotImplemented - this will be completed when needed for codegen
    _ = allocator;
    _ = set;
    _ = args;

    return error.NotImplemented;
}

const testing = std.testing;

test "EffectiveOverloadSet - distinguishing argument index" {
    const entries = [_]OverloadEntry{
        .{
            .types = &[_]OverloadEntry.Type{ .string, .numeric },
            .optionality = &[_]OverloadEntry.Optionality{ .required, .required },
            .operation = "overload1",
        },
        .{
            .types = &[_]OverloadEntry.Type{ .string, .boolean },
            .optionality = &[_]OverloadEntry.Optionality{ .required, .required },
            .operation = "overload2",
        },
    };

    const set = EffectiveOverloadSet{ .entries = &entries };

    // First argument is same (string), second differs (numeric vs boolean)
    const d = set.getDistinguishingArgumentIndex();
    try testing.expect(d != null);
    try testing.expectEqual(@as(usize, 1), d.?);
}

test "EffectiveOverloadSet - no distinguishing index when identical" {
    const entries = [_]OverloadEntry{
        .{
            .types = &[_]OverloadEntry.Type{.string},
            .optionality = &[_]OverloadEntry.Optionality{.required},
            .operation = "overload1",
        },
    };

    const set = EffectiveOverloadSet{ .entries = &entries };

    // Single entry has no distinguishing index
    const d = set.getDistinguishingArgumentIndex();
    try testing.expect(d == null);
}

test "resolveOverload - not yet implemented" {
    const entries = [_]OverloadEntry{
        .{
            .types = &[_]OverloadEntry.Type{.string},
            .optionality = &[_]OverloadEntry.Optionality{.required},
            .operation = "test",
        },
    };

    const set = EffectiveOverloadSet{ .entries = &entries };
    const args = [_]JSValue{.{ .string = "test" }};

    // TODO: This will work once full algorithm is implemented
    try testing.expectError(error.NotImplemented, resolveOverload(testing.allocator, set, &args));
}
