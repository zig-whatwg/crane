//! Tests migrated from src/webidl/overload_resolution.zig
//! Per WHATWG specifications

const std = @import("std");
const testing = std.testing;

const webidl = @import("webidl");
const OverloadEntry = webidl.overload_resolution.OverloadEntry;
const EffectiveOverloadSet = webidl.overload_resolution.EffectiveOverloadSet;
const JSValue = webidl.JSValue;

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
    try testing.expectError(error.NotImplemented, webidl.overload_resolution.resolveOverload(testing.allocator, set, &args));
}
