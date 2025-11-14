//! Tests migrated from src/webidl/legacy_platform_objects.zig
//! Per WHATWG specifications

const std = @import("std");

const webidl = @import("webidl");
const source = @import("../../src/webidl/legacy_platform_objects.zig");

test "LegacyPlatformObjectConfig - basic structure" {
    // Simple smoke test to verify types compile
    const config = LegacyPlatformObjectConfig{
        .override_builtins = true,
        .unenumerable_named = false,
    };

    try testing.expect(config.override_builtins);
    try testing.expect(!config.unenumerable_named);
}
test "createLegacyPlatformObject - not yet implemented" {
    const config = LegacyPlatformObjectConfig{};

    // Will work once V8 integration is complete
    try testing.expectError(error.NotImplemented, createLegacyPlatformObject(config));
}