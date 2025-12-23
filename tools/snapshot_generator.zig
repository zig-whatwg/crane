//! V8 Snapshot Generator for Fast Startup
//!
//! This build-time tool creates a V8 heap snapshot containing V8 builtins
//! (Object, Array, Promise, Map, etc.) with pre-compiled bytecode.
//!
//! ## How It Works
//!
//! 1. Creates a SnapshotCreator (no external references needed)
//! 2. Gets the isolate from SnapshotCreator
//! 3. Creates minimal contexts (V8 builtins only)
//! 4. Creates the snapshot blob
//! 5. Writes the blob to a file (whatwg_snapshot.bin)
//!
//! ## What's In The Snapshot
//!
//! - V8 JavaScript builtins (Object, Array, Promise, Map, Set, etc.)
//! - Pre-compiled bytecode for faster startup
//!
//! ## What's NOT In The Snapshot
//!
//! - WebIDL interfaces (registered at runtime via initializeBindings())
//! - External references (not needed for builtins-only snapshot)
//!
//! ## Usage
//!
//! Build and run:
//! ```bash
//! zig build snapshot-generator
//! ./zig-out/bin/snapshot_generator [output_path]
//! ```
//!
//! The output file is loaded at runtime:
//! ```zig
//! const isolate = v8.v8_Isolate_NewFromSnapshot(data, size, null);
//! const context = v8.v8_Context_New(isolate);  // Fresh context
//! interface_bindings.initializeBindings(isolate, context);  // Register WebIDL
//! ```

const std = @import("std");
const v8 = @import("v8");

/// Default output file for the snapshot blob
const DEFAULT_OUTPUT_PATH = "whatwg_snapshot.bin";

/// Print helper function
fn log(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void {
    const str = std.fmt.allocPrint(allocator, fmt, args) catch return;
    defer allocator.free(str);
    const stdout_file = std.fs.File.stdout();
    stdout_file.writeAll(str) catch {};
}

/// Entry point
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const output_path = if (args.len > 1) args[1] else DEFAULT_OUTPUT_PATH;

    log(allocator, "V8 Snapshot Generator with WebIDL Interfaces\n", .{});
    log(allocator, "=============================================\n\n", .{});
    log(allocator, "This creates a snapshot with V8 builtins AND WebIDL interfaces.\n", .{});
    log(allocator, "This snapshot provides fast V8 isolate startup with builtins pre-compiled.\n\n", .{});

    // Step 1: Initialize V8 platform with deterministic flags
    // These flags ensure deterministic snapshot creation:
    // - --hash-seed=0: Deterministic hash seed for rehashable snapshots
    // - --predictable: Forces deterministic behavior (disables random GC, etc.)
    //
    // CRITICAL: These MUST be set BEFORE v8_Platform_Initialize() is called,
    // and they MUST match the flags used in snapshot_loader.zig for loading.
    log(allocator, "Step 1: Initializing V8 platform...\\n", .{});
    v8.ffi.v8_SetFlagsFromString(v8.snapshot_loader.SNAPSHOT_V8_FLAGS);
    v8.ffi.v8_Platform_Initialize();
    log(allocator, "  V8 platform initialized\n\n", .{});

    // Step 2: Register all external references and create SnapshotCreator
    // External references are REQUIRED for V8 snapshots - they allow V8 to
    // resolve callback function pointers when restoring context from snapshot.
    log(allocator, "Step 2: Registering external references...\n", .{});
    v8.external_references.registerAllExternalReferences();
    const stats = v8.external_references.getExternalReferenceStats();
    log(allocator, "  Registered {d} external references\n", .{stats.count});
    log(allocator, "  Reference hash: 0x{x:0>16} (for determinism verification)\n", .{stats.hash});

    const ext_refs = v8.external_references.getRuntimeExternalReferencesPtr();
    log(allocator, "Step 2b: Creating SnapshotCreator with external references...\n", .{});
    const creator = v8.ffi.v8_SnapshotCreator_New(ext_refs) orelse {
        log(allocator, "  ERROR: Failed to create SnapshotCreator\n", .{});
        return error.SnapshotCreatorFailed;
    };
    log(allocator, "  SnapshotCreator created successfully\n\n", .{});

    // Step 3: Getting isolate from SnapshotCreator
    log(allocator, "Step 3: Getting isolate from SnapshotCreator...\n", .{});
    const isolate = v8.ffi.v8_SnapshotCreator_GetIsolate(creator) orelse {
        log(allocator, "  ERROR: Failed to get isolate from SnapshotCreator\n", .{});
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.IsolateFailed;
    };
    log(allocator, "  Isolate obtained\n\n", .{});

    // Step 4: Enter isolate
    log(allocator, "Step 4: Entering isolate...\n", .{});
    v8.ffi.v8_Isolate_Enter(isolate);
    log(allocator, "  Isolate entered\n\n", .{});

    // Step 5: Create and set up snapshot contexts
    // V8's SnapshotCreator requires SetDefaultContext() to be called.
    // We ONLY set the default context - no indexed contexts.
    log(allocator, "Step 5: Creating default context for snapshot...\\n", .{});

    // Set the default context (required by CreateBlob)
    if (!v8.ffi.v8_SnapshotCreator_CreateAndSetDefaultContext(creator)) {
        log(allocator, "  ERROR: Failed to create and set default context\\n", .{});
        v8.ffi.v8_Isolate_Exit(isolate);
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.ContextFailed;
    }
    log(allocator, "  Default context set (no indexed contexts)\\n\\n", .{});

    // Step 6: Create the snapshot blob
    log(allocator, "Step 6: Creating snapshot blob...\n", .{});

    // NOTE: We do NOT clear Global handles here anymore.
    // The context handles must remain valid until CreateBlob serializes them.
    // V8's SetDefaultContext and AddContext store references to the contexts,
    // and invalidating those handles before CreateBlob causes rehashability errors.

    // Exit isolate before creating blob (required by V8)
    v8.ffi.v8_Isolate_Exit(isolate);

    var out_data: ?[*]const u8 = null;
    var out_size: c_int = 0;
    // Use Clear to discard compiled code - this may help with rehashability issues
    // by ensuring the snapshot contains only the essential heap state
    const success = v8.ffi.v8_SnapshotCreator_CreateBlob(
        creator,
        @intFromEnum(v8.ffi.FunctionCodeHandling.Clear),
        &out_data,
        &out_size,
    );

    if (!success or out_data == null) {
        log(allocator, "  ERROR: Failed to create snapshot blob\n", .{});
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.SnapshotCreationFailed;
    }

    const blob_size: usize = @intCast(out_size);
    log(allocator, "  Snapshot blob created: {d} bytes ({d:.2} KB)\n\n", .{
        blob_size,
        @as(f64, @floatFromInt(blob_size)) / 1024.0,
    });

    // Step 7: Dispose SnapshotCreator (this also disposes the isolate)
    log(allocator, "Step 7: Disposing SnapshotCreator...\n", .{});
    v8.ffi.v8_SnapshotCreator_Dispose(creator);
    log(allocator, "  SnapshotCreator disposed\n\n", .{});

    // Step 8: Write blob to file
    log(allocator, "Step 8: Writing snapshot to file: {s}\n", .{output_path});
    const blob_data = out_data.?[0..blob_size];
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(blob_data);

    // Free snapshot data
    v8.ffi.v8_Snapshot_FreeData(out_data);

    log(allocator, "  Snapshot written successfully\n\n", .{});

    // Summary
    log(allocator, "=============================================\n", .{});
    log(allocator, "Snapshot generation complete!\n", .{});
    log(allocator, "  Output: {s}\n", .{output_path});
    log(allocator, "  Size: {d} bytes ({d:.2} KB)\n", .{
        blob_size,
        @as(f64, @floatFromInt(blob_size)) / 1024.0,
    });
    log(allocator, "\nThis snapshot contains V8 builtins for fast isolate startup.\n", .{});
    log(allocator, "WebIDL interfaces are registered at runtime via initializeBindings().\n", .{});
    log(allocator, "\nTo use this snapshot at runtime:\n", .{});
    log(allocator, "  1. Load the blob from file\n", .{});
    log(allocator, "  2. Create isolate with v8_Isolate_NewFromSnapshot(data, size, NULL)\n", .{});
    log(allocator, "  3. Create fresh context with v8_Context_New(isolate)\n", .{});
    log(allocator, "  4. Register WebIDL interfaces with initializeBindings()\n", .{});
}
