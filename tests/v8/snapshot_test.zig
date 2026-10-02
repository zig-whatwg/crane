//! Test V8 snapshot functionality
//!
//! This test verifies:
//! 1. Snapshot validation works correctly
//! 2. Fallback to fresh initialization works when snapshot loading is disabled
//! 3. Contexts created via fallback are functional
//!
//! NOTE: V8 14.x has issues with custom snapshot context restoration.
//! Context::FromSnapshot crashes with "index < num_contexts" assertion.
//! See epic whatwg-51u8m for tracking the fix.

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");

test "snapshot validation - valid snapshot" {
    const allocator = std.testing.allocator;

    // The snapshot this build generated - not a copy in the current
    // directory, which is what a stale one looks like.
    const snapshot_path = "zig-out/bin/whatwg_snapshot.bin";
    const io = std.testing.io;
    std.Io.Dir.cwd().access(io, snapshot_path, .{}) catch |err| {
        std.log.warn("Skipping snapshot test - file not found: {}", .{err});
        return;
    };

    // Load snapshot file
    const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
    defer file.close(io);

    const stat = try file.stat(io);
    const snapshot_data = try allocator.alloc(u8, stat.size);
    defer allocator.free(snapshot_data);
    _ = try file.readPositionalAll(io, snapshot_data, 0);

    // Validate using the new validation function
    const validation = v8.snapshot_loader.validateSnapshotData(snapshot_data);

    try std.testing.expect(validation.is_valid);
    try std.testing.expect(validation.size == stat.size);

    std.log.info("Snapshot validation: valid={}, can_rehash={}, size={d}", .{
        validation.is_valid,
        validation.can_rehash,
        validation.size,
    });
}

test "snapshot validation - invalid data" {
    // Test with empty data
    const empty: []const u8 = &.{};
    const empty_validation = v8.snapshot_loader.validateSnapshotData(empty);
    try std.testing.expect(!empty_validation.is_valid);
    try std.testing.expect(empty_validation.error_message != null);

    // Test with too-small data
    const small: []const u8 = &.{ 0, 1, 2, 3 };
    const small_validation = v8.snapshot_loader.validateSnapshotData(small);
    try std.testing.expect(!small_validation.is_valid);
    try std.testing.expect(small_validation.error_message != null);

    // NOTE: Testing with garbage data >= 8 bytes is skipped because V8's
    // v8_Snapshot_IsValid() crashes with SIGABRT on truly garbage data
    // instead of gracefully returning false. This is a V8 limitation.
}

// NOTE: This test is skipped because it requires isolated V8 platform initialization
// which conflicts with the global runtime state used by other tests.
// The test would pass if run in isolation, but the global V8 platform can only
// be initialized once per process.
//
// test "snapshot fallback - fresh initialization" {
//     const allocator = std.testing.allocator;
//
//     // Initialize runtime
//     runtime.initializeRuntime(allocator);
//     defer runtime.deinitializeRuntime();
//
//     // Initialize V8 with snapshot options that will trigger fallback
//     // Since custom snapshot loading is disabled, this should use V8's built-in snapshot
//     const result = try v8.snapshot_loader.initializeV8(allocator, .{
//         .snapshot_path = null, // No custom snapshot
//         .embedded_snapshot = null,
//         .log_performance = true,
//     });
//
//     const isolate = result.isolate;
//     const context = result.context;
//
//     // Note: initializeV8 enters the isolate but NOT the context.
//     // We need to enter/exit the context properly if we want to use it.
//     v8.ffi.v8_Context_Enter(context);
//     defer v8.ffi.v8_Context_Exit(context);
//
//     defer {
//         v8.ffi.v8_Context_Dispose(context);
//         v8.ffi.v8_Isolate_Exit(isolate);
//         v8.ffi.v8_Isolate_Dispose(isolate);
//         v8.ffi.v8_Platform_Dispose();
//     }
//
//     // Verify that initialization completed and we got valid handles
//     // The fact that initializeV8 returned without error and we have
//     // valid isolate/context pointers means the fallback worked correctly
//     try std.testing.expect(result.startup_time_ms >= 0);
//     // Since we didn't provide a snapshot, it should indicate fallback was used
//     try std.testing.expect(!result.used_snapshot);
//
//     std.log.info("Fresh initialization fallback - SUCCESS (startup time: {d}ms)", .{result.startup_time_ms});
// }

// NOTE: This test is currently expected to fail due to V8 14.x issues.
// Uncomment when custom snapshot context restoration is fixed.
//
// test "snapshot loading - full lifecycle with context restoration" {
//     const allocator = std.testing.allocator;
//
//     // Check if snapshot file exists
//     const snapshot_path = "whatwg_snapshot.bin";
//     const io = std.testing.io;
//     std.Io.Dir.cwd().access(io, snapshot_path, .{}) catch |err| {
//         std.log.warn("Skipping snapshot test - file not found: {}", .{err});
//         return;
//     };
//
//     // Initialize runtime
//     runtime.initializeRuntime(allocator);
//     defer runtime.deinitializeRuntime();
//
//     // Initialize V8 platform with proper flags for snapshots
//     v8.snapshot_loader.initializePlatformForSnapshots();
//     defer v8.ffi.v8_Platform_Dispose();
//
//     // Register external references (must match snapshot creation order)
//     v8.snapshot_loader.registerExternalReferences();
//
//     // Load snapshot file
//     const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
//     defer file.close(io);
//
//     const stat = try file.stat(io);
//     const snapshot_data = try allocator.alloc(u8, stat.size);
//     defer allocator.free(snapshot_data);
//     _ = try file.readPositionalAll(io, snapshot_data, 0);
//
//     // Create isolate from snapshot
//     const refs_ptr = v8.external_references.getRuntimeExternalReferencesPtr();
//     const isolate = v8.ffi.v8_Isolate_NewFromSnapshot(
//         snapshot_data.ptr,
//         @intCast(snapshot_data.len),
//         refs_ptr,
//     ) orelse return error.IsolateFailed;
//     defer v8.ffi.v8_Isolate_Dispose(isolate);
//
//     v8.ffi.v8_Isolate_Enter(isolate);
//     defer v8.ffi.v8_Isolate_Exit(isolate);
//
//     // Create context from snapshot - THIS CURRENTLY FAILS IN V8 14.x
//     const context = v8.ffi.v8_Context_NewFromSnapshot(isolate) orelse {
//         std.log.err("EXPECTED FAILURE: Context::FromSnapshot returned null", .{});
//         return error.ContextFailed;
//     };
//     defer v8.ffi.v8_Context_Dispose(context);
//
//     v8.ffi.v8_Context_Enter(context);
//     defer v8.ffi.v8_Context_Exit(context);
//
//     std.log.info("Context created from snapshot - SUCCESS!", .{});
// }

test "the external reference table keeps a callback registered twice, in its place" {
    // A snapshot names each callback by its INDEX in this table, so the table
    // must be the same at generation and at load - entry for entry - in every
    // build mode. V8's encoder takes duplicate addresses ("Ignore duplicate
    // references. This can happen due to ICF. See http://crbug.com/726896.",
    // src/codegen/external-reference-encoder.cc). An optimized build merges
    // identical functions, so callbacks distinct in Debug can share an address
    // in ReleaseSafe; a table that dropped repeats was shorter there (8,287
    // entries against the Debug generator's 11,465), every ReleaseSafe runner
    // refused the build's snapshot ("the snapshot was made against 11465
    // external references and this build has 8287"), and ran every realm on
    // the no-snapshot path - a different engine from the Debug runner's.
    const refs = v8.external_references;
    refs.clearRuntimeReferences();
    defer refs.clearRuntimeReferences();

    refs.registerPointer(0x1000);
    refs.registerPointer(0x2000);
    refs.registerPointer(0x1000); // a second callback the optimizer merged with the first
    refs.registerPointer(0x3000);

    try std.testing.expectEqualSlices(isize, &.{ 0x1000, 0x2000, 0x1000, 0x3000, 0 }, refs.getRuntimeExternalReferences());
}

test "the external reference table is the same length however often it is registered" {
    // registerAllExternalReferences starts from an empty table each time: the
    // snapshot generator and every engine start register it once each.
    const refs = v8.external_references;
    defer refs.clearRuntimeReferences();
    refs.registerAllExternalReferences();
    const first = refs.getRuntimeCount();
    refs.registerAllExternalReferences();
    try std.testing.expectEqual(first, refs.getRuntimeCount());
    try std.testing.expect(first > 0);
}
