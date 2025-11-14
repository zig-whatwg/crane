//! Tests migrated from src/webidl/legacy_platform_objects.zig
//! Per WHATWG specifications

const std = @import("std");
const testing = std.testing;

const webidl = @import("webidl");
const LegacyPlatformObjectConfig = webidl.legacy_platform_objects.LegacyPlatformObjectConfig;

test "createLegacyPlatformObject - not yet implemented" {
    const config = LegacyPlatformObjectConfig{};

    // Will work once V8 integration is complete
    try testing.expectError(error.NotImplemented, webidl.legacy_platform_objects.createLegacyPlatformObject(config));
}
