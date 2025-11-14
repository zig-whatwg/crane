//! Tests migrated from src/webidl/overload_resolution.zig
//! Per WHATWG specifications

const std = @import("std");

const webidl = @import("webidl");
const source = @import("../../src/webidl/overload_resolution.zig");

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

    // Not implemented until JS runtime integration
    try testing.expectError(error.NotImplemented, resolveOverload(testing.allocator, set, &args));
}