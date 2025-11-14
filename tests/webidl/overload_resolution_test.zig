//! Tests migrated from src/webidl/overload_resolution.zig
//! Per WHATWG specifications

const std = @import("std");

const webidl = @import("webidl");

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