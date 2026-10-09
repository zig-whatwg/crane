//! PlatformBackend Comprehensive Unit Tests
//!
//! This test file provides comprehensive coverage of the PlatformBackend system:
//! - Core PlatformBackend struct operations
//! - Capability management and queries
//! - C API exports for FFI
//! - Stub backend functionality
//! - Memory safety and error handling
//!
//! These tests verify the platform abstraction layer works correctly for
//! embedders using Swift, Kotlin, or other FFI-compatible languages.

const std = @import("std");
const testing = std.testing;

const platform_backend = @import("platform").platform_backend;
const PlatformBackend = platform_backend.PlatformBackend;
const Capability = platform_backend.Capability;
const PLATFORM_BACKEND_VERSION = platform_backend.PLATFORM_BACKEND_VERSION;

const stub = @import("platform").stub_platform_backend;
const StubContext = stub.StubContext;

const vtables = @import("platform").vtables;
const ClipboardResult = vtables.ClipboardResult;
const StorageResult = vtables.StorageResult;

const exports = @import("platform").exports;

// =============================================================================
// PlatformBackend Core Tests
// =============================================================================

test "PlatformBackend - default initialization has no capabilities" {
    const backend = platform_backend.empty();

    // All capabilities should be null by default
    try testing.expect(backend.clipboard == null);
    try testing.expect(backend.timer == null);
    try testing.expect(backend.network == null);
    try testing.expect(backend.storage == null);
    try testing.expect(backend.layout == null);
    try testing.expect(backend.ui == null);
    try testing.expect(backend.geolocation == null);
    try testing.expect(backend.bluetooth == null);

    // Should have correct version
    try testing.expectEqual(PLATFORM_BACKEND_VERSION, backend.version);
}

test "PlatformBackend - hasCapability returns correct results" {
    var backend = platform_backend.empty();

    // Before setting - all false
    try testing.expect(!backend.hasCapability(.clipboard));
    try testing.expect(!backend.hasCapability(.timer));

    // After setting clipboard
    backend.clipboard = &stub.stub_clipboard_vtable;
    try testing.expect(backend.hasCapability(.clipboard));
    try testing.expect(!backend.hasCapability(.timer));

    // After setting timer
    backend.timer = &stub.stub_timer_vtable;
    try testing.expect(backend.hasCapability(.clipboard));
    try testing.expect(backend.hasCapability(.timer));
}

test "PlatformBackend - getAvailableCapabilities returns correct list" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    const backend = stub.createStubBackend(&ctx);

    const caps = try backend.getAvailableCapabilities(testing.allocator);
    defer testing.allocator.free(caps);

    // Stub backend has these capabilities
    var has_clipboard = false;
    var has_timer = false;
    var has_storage = false;
    var has_geolocation = false;

    for (caps) |cap| {
        switch (cap) {
            .clipboard => has_clipboard = true,
            .timer => has_timer = true,
            .storage => has_storage = true,
            .geolocation => has_geolocation = true,
            else => {},
        }
    }

    try testing.expect(has_clipboard);
    try testing.expect(has_timer);
    try testing.expect(has_storage);
    try testing.expect(has_geolocation);
}

test "PlatformBackend - isCompatible checks version" {
    var backend = platform_backend.empty();

    // Default version should be compatible
    try testing.expect(backend.isCompatible());

    // Modified version should not be compatible
    backend.version = PLATFORM_BACKEND_VERSION + 1;
    try testing.expect(!backend.isCompatible());
}

test "PlatformBackend - withContext sets user_context" {
    var my_context: u32 = 42;
    const backend = platform_backend.withContext(&my_context);

    try testing.expect(backend.user_context != null);
    const ctx: *u32 = @ptrCast(@alignCast(backend.user_context.?));
    try testing.expectEqual(@as(u32, 42), ctx.*);
}

test "PlatformBackend - extern struct layout is C-compatible" {
    // Verify the struct is extern (required for C FFI)
    const info = @typeInfo(PlatformBackend);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// Capability Enum Tests
// =============================================================================

test "Capability - all capabilities have unique values" {
    // Verify no duplicate enum values
    var seen = std.AutoHashMap(u8, void).init(testing.allocator);
    defer seen.deinit();

    inline for (std.meta.fields(Capability)) |field| {
        const result = seen.getOrPut(field.value) catch unreachable;
        try testing.expect(!result.found_existing);
    }
}

test "Capability - name returns correct strings" {
    try testing.expectEqualStrings("clipboard", Capability.clipboard.name());
    try testing.expectEqualStrings("network", Capability.network.name());
    try testing.expectEqualStrings("storage", Capability.storage.name());
    try testing.expectEqualStrings("geolocation", Capability.geolocation.name());
    try testing.expectEqualStrings("bluetooth", Capability.bluetooth.name());
}

// =============================================================================
// C API Export Tests
// =============================================================================

test "C API - whatwg_platform_create and destroy" {
    const backend = exports.whatwg_platform_create();
    try testing.expect(backend != null);

    // Verify it's properly initialized
    try testing.expectEqual(PLATFORM_BACKEND_VERSION, backend.?.version);
    try testing.expect(backend.?.clipboard == null);

    // Cleanup
    exports.whatwg_platform_destroy(backend);
}

test "C API - whatwg_platform_create_with_context" {
    var my_context: u64 = 0xDEADBEEF;
    const backend = exports.whatwg_platform_create_with_context(&my_context);
    try testing.expect(backend != null);
    defer exports.whatwg_platform_destroy(backend);

    // Verify context is set
    const ctx = exports.whatwg_platform_get_user_context(backend);
    try testing.expect(ctx != null);

    const ctx_ptr: *u64 = @ptrCast(@alignCast(ctx.?));
    try testing.expectEqual(@as(u64, 0xDEADBEEF), ctx_ptr.*);
}

test "C API - whatwg_platform_get_version" {
    const backend = exports.whatwg_platform_create();
    defer exports.whatwg_platform_destroy(backend);

    const version = exports.whatwg_platform_get_version(backend);
    try testing.expectEqual(PLATFORM_BACKEND_VERSION, version);

    // Null backend returns 0
    try testing.expectEqual(@as(u32, 0), exports.whatwg_platform_get_version(null));
}

test "C API - whatwg_platform_expected_version" {
    const expected = exports.whatwg_platform_expected_version();
    try testing.expectEqual(PLATFORM_BACKEND_VERSION, expected);
}

test "C API - whatwg_platform_is_compatible" {
    const backend = exports.whatwg_platform_create();
    defer exports.whatwg_platform_destroy(backend);

    try testing.expect(exports.whatwg_platform_is_compatible(backend));

    // Null backend is not compatible
    try testing.expect(!exports.whatwg_platform_is_compatible(null));
}

test "C API - whatwg_platform_has_capability" {
    const backend = exports.whatwg_platform_create();
    defer exports.whatwg_platform_destroy(backend);

    // Empty backend has no capabilities
    try testing.expect(!exports.whatwg_platform_has_capability(backend, exports.WHATWG_CAP_CLIPBOARD));
    try testing.expect(!exports.whatwg_platform_has_capability(backend, exports.WHATWG_CAP_NETWORK));

    // Set clipboard capability
    exports.whatwg_platform_set_clipboard(backend, &stub.stub_clipboard_vtable);
    try testing.expect(exports.whatwg_platform_has_capability(backend, exports.WHATWG_CAP_CLIPBOARD));
    try testing.expect(!exports.whatwg_platform_has_capability(backend, exports.WHATWG_CAP_NETWORK));
}

test "C API - whatwg_platform_capability_count" {
    const backend = exports.whatwg_platform_create();
    defer exports.whatwg_platform_destroy(backend);

    // Empty backend
    try testing.expectEqual(@as(u32, 0), exports.whatwg_platform_capability_count(backend));

    // Add capabilities
    exports.whatwg_platform_set_clipboard(backend, &stub.stub_clipboard_vtable);
    try testing.expectEqual(@as(u32, 1), exports.whatwg_platform_capability_count(backend));

    exports.whatwg_platform_set_timer(backend, &stub.stub_timer_vtable);
    try testing.expectEqual(@as(u32, 2), exports.whatwg_platform_capability_count(backend));

    exports.whatwg_platform_set_storage(backend, &stub.stub_storage_vtable);
    try testing.expectEqual(@as(u32, 3), exports.whatwg_platform_capability_count(backend));
}

test "C API - capability setters work correctly" {
    const backend = exports.whatwg_platform_create();
    defer exports.whatwg_platform_destroy(backend);

    // Set all core capabilities
    exports.whatwg_platform_set_clipboard(backend, &stub.stub_clipboard_vtable);
    exports.whatwg_platform_set_timer(backend, &stub.stub_timer_vtable);
    exports.whatwg_platform_set_network(backend, &stub.stub_network_vtable);
    exports.whatwg_platform_set_storage(backend, &stub.stub_storage_vtable);
    exports.whatwg_platform_set_layout(backend, &stub.stub_layout_vtable);
    exports.whatwg_platform_set_ui(backend, &stub.stub_ui_vtable);
    exports.whatwg_platform_set_screen(backend, &stub.stub_screen_vtable);
    exports.whatwg_platform_set_geolocation(backend, &stub.stub_geolocation_vtable);

    // Verify all are set
    try testing.expect(backend.?.clipboard != null);
    try testing.expect(backend.?.timer != null);
    try testing.expect(backend.?.network != null);
    try testing.expect(backend.?.storage != null);
    try testing.expect(backend.?.layout != null);
    try testing.expect(backend.?.ui != null);
    try testing.expect(backend.?.screen != null);
    try testing.expect(backend.?.geolocation != null);
}

test "C API - null-safe operations" {
    // All operations should handle null gracefully
    exports.whatwg_platform_destroy(null);
    try testing.expectEqual(@as(u32, 0), exports.whatwg_platform_get_version(null));
    try testing.expect(!exports.whatwg_platform_is_compatible(null));
    try testing.expect(!exports.whatwg_platform_has_capability(null, 0));
    try testing.expectEqual(@as(u32, 0), exports.whatwg_platform_capability_count(null));
    try testing.expect(exports.whatwg_platform_get_user_context(null) == null);

    // Setters should be safe with null backend
    exports.whatwg_platform_set_user_context(null, null);
    exports.whatwg_platform_set_clipboard(null, null);
    exports.whatwg_platform_set_timer(null, null);
}

// =============================================================================
// Stub Backend Tests
// =============================================================================

test "StubContext - memory management" {
    var ctx = StubContext.init(testing.allocator);

    // Set values that require allocation
    try ctx.setClipboardText("Hello, World!");
    try ctx.setStorageValue("key1", "value1");
    try ctx.setStorageValue("key2", "value2");

    // Verify values are set
    try testing.expectEqualStrings("Hello, World!", ctx.clipboard_text.?);

    // deinit should free all allocated memory
    ctx.deinit();
    // If we get here without leak, memory management is correct
}

test "StubContext - time advancement" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    try testing.expectEqual(@as(i64, 0), ctx.current_time_ms);
    try testing.expectEqual(@as(i64, 0), ctx.high_res_time_ns);

    ctx.advanceTime(100);
    try testing.expectEqual(@as(i64, 100), ctx.current_time_ms);
    try testing.expectEqual(@as(i64, 100_000_000), ctx.high_res_time_ns);

    ctx.advanceTime(1000);
    try testing.expectEqual(@as(i64, 1100), ctx.current_time_ms);
    try testing.expectEqual(@as(i64, 1_100_000_000), ctx.high_res_time_ns);
}

test "StubContext - storage operations" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    // Set multiple values
    try ctx.setStorageValue("name", "Alice");
    try ctx.setStorageValue("age", "30");

    // Verify using vtable
    var buffer: [100]u8 = undefined;
    const name_len = stub.stub_storage_vtable.call_getItem(&ctx, "name", 4, &buffer, buffer.len);
    try testing.expectEqual(@as(i32, 5), name_len);
    try testing.expectEqualStrings("Alice", buffer[0..@intCast(name_len)]);

    // Overwrite value
    try ctx.setStorageValue("name", "Bob");
    const new_len = stub.stub_storage_vtable.call_getItem(&ctx, "name", 4, &buffer, buffer.len);
    try testing.expectEqual(@as(i32, 3), new_len);
    try testing.expectEqualStrings("Bob", buffer[0..@intCast(new_len)]);
}

test "createStubBackend - all implemented capabilities work" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    const backend = stub.createStubBackend(&ctx);

    // Test clipboard
    try testing.expect(backend.clipboard != null);
    const write_result = backend.clipboard.?.call_writeText(&ctx, "test", 4);
    try testing.expectEqual(ClipboardResult.success, write_result);

    // Test timer
    try testing.expect(backend.timer != null);
    ctx.current_time_ms = 12345;
    try testing.expectEqual(@as(i64, 12345), backend.timer.?.getCurrentTime(&ctx));

    // Test storage
    try testing.expect(backend.storage != null);
    const set_result = backend.storage.?.call_setItem(&ctx, "k", 1, "v", 1);
    try testing.expectEqual(StorageResult.success, set_result);
    try testing.expectEqual(@as(u32, 1), backend.storage.?.get_length(&ctx));

    // Test geolocation (async API, just verify vtable is set)
    try testing.expect(backend.geolocation != null);
    // GeolocationVTable uses async callbacks, so we just verify the vtable exists
    // Actual geolocation testing would require callback setup

    // Test screen
    try testing.expect(backend.screen != null);
    try testing.expectEqual(@as(u32, 1920), backend.screen.?.get_width(&ctx));
    try testing.expectEqual(@as(u32, 1080), backend.screen.?.get_height(&ctx));

    // Test battery
    try testing.expect(backend.battery != null);
    try testing.expectEqual(@as(f64, 1.0), backend.battery.?.get_level(&ctx));
    try testing.expect(backend.battery.?.get_charging(&ctx));
}

test "createEmptyBackend - no capabilities available" {
    const backend = stub.createEmptyBackend();

    // All capabilities should be null
    try testing.expect(backend.clipboard == null);
    try testing.expect(backend.timer == null);
    try testing.expect(backend.network == null);
    try testing.expect(backend.storage == null);
    try testing.expect(backend.layout == null);
    try testing.expect(backend.geolocation == null);

    // hasCapability should return false for all
    inline for (std.meta.fields(Capability)) |field| {
        const cap: Capability = @enumFromInt(field.value);
        try testing.expect(!backend.hasCapability(cap));
    }
}

// =============================================================================
// VTable Integration Tests
// =============================================================================

test "Clipboard VTable - permission denied handling" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    // Disable read permission
    ctx.clipboard_read_allowed = false;

    var buffer: [100]u8 = undefined;
    const result = stub.stub_clipboard_vtable.call_readText(&ctx, &buffer, buffer.len);
    try testing.expectEqual(@intFromEnum(ClipboardResult.permission_denied), result);
}

test "Clipboard VTable - empty clipboard handling" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    // Don't set any clipboard content
    var buffer: [100]u8 = undefined;
    const result = stub.stub_clipboard_vtable.call_readText(&ctx, &buffer, buffer.len);
    try testing.expectEqual(@intFromEnum(ClipboardResult.empty), result);
}

test "Clipboard VTable - buffer size query" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    try ctx.setClipboardText("Hello");

    // Query size by passing null buffer
    const size = stub.stub_clipboard_vtable.call_readText(&ctx, null, 0);
    try testing.expectEqual(@as(i32, 5), size);
}

test "Storage VTable - non-existent key" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    var buffer: [100]u8 = undefined;
    const result = stub.stub_storage_vtable.call_getItem(&ctx, "nonexistent", 11, &buffer, buffer.len);
    try testing.expectEqual(@intFromEnum(StorageResult.not_found), result);
}

test "Storage VTable - clear operation" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    // Add items
    _ = stub.stub_storage_vtable.call_setItem(&ctx, "a", 1, "1", 1);
    _ = stub.stub_storage_vtable.call_setItem(&ctx, "b", 1, "2", 1);
    try testing.expectEqual(@as(u32, 2), stub.stub_storage_vtable.get_length(&ctx));

    // Clear
    _ = stub.stub_storage_vtable.call_clear(&ctx);
    try testing.expectEqual(@as(u32, 0), stub.stub_storage_vtable.get_length(&ctx));
}

test "Layout VTable - bounding rect" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    ctx.default_width = 200;
    ctx.default_height = 100;

    var rect: vtables.CDOMRect = undefined;
    stub.stub_layout_vtable.call_getBoundingClientRect(&ctx, null, &rect);

    try testing.expectEqual(@as(f64, 0), rect.x);
    try testing.expectEqual(@as(f64, 0), rect.y);
    try testing.expectEqual(@as(f64, 200), rect.width);
    try testing.expectEqual(@as(f64, 100), rect.height);
}

// =============================================================================
// Memory Safety Tests
// =============================================================================

test "Memory - no leaks with repeated create/destroy" {
    // Rapidly create and destroy backends to verify no leaks
    for (0..100) |_| {
        const backend = exports.whatwg_platform_create();
        exports.whatwg_platform_destroy(backend);
    }
    // If testing.allocator (which is std.testing.allocator) doesn't
    // report leaks, we're good
}

test "Memory - stub context handles repeated operations" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    // Repeatedly set clipboard text (should free old value)
    for (0..50) |i| {
        var buf: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "text_{d}", .{i}) catch unreachable;
        try ctx.setClipboardText(text);
    }

    // Repeatedly set storage values (should handle updates correctly)
    for (0..50) |i| {
        var buf: [32]u8 = undefined;
        const value = std.fmt.bufPrint(&buf, "value_{d}", .{i}) catch unreachable;
        try ctx.setStorageValue("key", value);
    }
}

// =============================================================================
// Edge Case Tests
// =============================================================================

test "Edge case - empty strings" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    // Empty clipboard text
    try ctx.setClipboardText("");
    try testing.expect(ctx.clipboard_text != null);
    try testing.expectEqual(@as(usize, 0), ctx.clipboard_text.?.len);

    // Empty storage value
    _ = stub.stub_storage_vtable.call_setItem(&ctx, "empty", 5, "", 0);
    var buffer: [100]u8 = undefined;
    const len = stub.stub_storage_vtable.call_getItem(&ctx, "empty", 5, &buffer, buffer.len);
    try testing.expectEqual(@as(i32, 0), len);
}

test "Edge case - large buffer operations" {
    var ctx = StubContext.init(testing.allocator);
    defer ctx.deinit();

    // Create large text
    const large_text = try testing.allocator.alloc(u8, 10000);
    defer testing.allocator.free(large_text);
    @memset(large_text, 'A');

    // Write large text to clipboard
    const write_result = stub.stub_clipboard_vtable.call_writeText(&ctx, large_text.ptr, large_text.len);
    try testing.expectEqual(ClipboardResult.success, write_result);

    // Read back with adequate buffer
    const read_buffer = try testing.allocator.alloc(u8, 10000);
    defer testing.allocator.free(read_buffer);

    const read_len = stub.stub_clipboard_vtable.call_readText(&ctx, read_buffer.ptr, read_buffer.len);
    try testing.expectEqual(@as(i32, 10000), read_len);
}

test "Edge case - invalid capability constant" {
    const backend = exports.whatwg_platform_create();
    defer exports.whatwg_platform_destroy(backend);

    // Invalid capability constant (> max enum value)
    try testing.expect(!exports.whatwg_platform_has_capability(backend, 255));
}
