//! V8 Snapshot Generator for WebIDL Interfaces
//!
//! This build-time tool creates a V8 heap snapshot containing all registered
//! WebIDL interfaces. The snapshot can be loaded at runtime for instant
//! interface availability without re-registering ~1200 interfaces via FFI.
//!
//! ## How It Works
//!
//! 1. Registers all interface callbacks with external references registry
//! 2. Creates a SnapshotCreator with those external references
//! 3. Gets the isolate from SnapshotCreator
//! 4. Creates a context and registers all WebIDL interfaces
//! 5. Sets the context as the default context for the snapshot
//! 6. Creates the snapshot blob
//! 7. Writes the blob to a file (whatwg_snapshot.bin)
//!
//! ## Usage
//!
//! Build and run:
//! ```bash
//! zig build snapshot-generator
//! ./zig-out/bin/snapshot_generator [output_path]
//! ```
//!
//! The output file can then be loaded at runtime:
//! ```zig
//! const isolate = v8.v8_Isolate_NewFromSnapshot(data, size, external_refs);
//! const context = v8.v8_Context_NewFromSnapshot(isolate);
//! // All interfaces are already registered!
//! ```
//!
//! ## Critical Requirements
//!
//! - External references MUST be in the SAME ORDER at creation and loading time
//! - The snapshot is V8-version-specific (must be regenerated for V8 updates)
//! - All callback pointers must be registered before snapshot creation

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const namespaces = @import("namespaces");
const ext_refs = v8.external_references;
const interface_bindings = v8.interface_bindings;
// Additional modules for external reference parity with snapshot_loader
const intl_binding = v8.intl_binding;
const window_properties = v8.window_properties;
const context_manager = v8.context_manager;

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

    log(allocator, "V8 Snapshot Generator for WebIDL Interfaces\n", .{});
    log(allocator, "============================================\n\n", .{});

    // Step 1: Register all external references
    log(allocator, "Step 1: Registering external references for all interfaces...\n", .{});
    registerAllExternalReferences();
    const ref_count = ext_refs.getRuntimeCount();
    log(allocator, "  Registered {d} external references\n\n", .{ref_count});

    // Step 2: Initialize V8 platform
    log(allocator, "Step 2: Initializing V8 platform...\n", .{});
    v8.ffi.v8_Platform_Initialize();
    log(allocator, "  V8 platform initialized\n\n", .{});

    // Step 3: Create SnapshotCreator with external references
    log(allocator, "Step 3: Creating SnapshotCreator...\n", .{});
    const refs_ptr = ext_refs.getRuntimeExternalReferencesPtr();
    const creator = v8.ffi.v8_SnapshotCreator_New(refs_ptr) orelse {
        log(allocator, "  ERROR: Failed to create SnapshotCreator\n", .{});
        return error.SnapshotCreatorFailed;
    };
    log(allocator, "  SnapshotCreator created successfully\n\n", .{});

    // Step 4: Get the isolate from SnapshotCreator
    log(allocator, "Step 4: Getting isolate from SnapshotCreator...\n", .{});
    const isolate = v8.ffi.v8_SnapshotCreator_GetIsolate(creator) orelse {
        log(allocator, "  ERROR: Failed to get isolate from SnapshotCreator\n", .{});
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.IsolateFailed;
    };
    log(allocator, "  Isolate obtained\n\n", .{});

    // Step 5: Enter isolate and create context
    log(allocator, "Step 5: Creating context and registering interfaces...\n", .{});
    v8.ffi.v8_Isolate_Enter(isolate);

    // Enable snapshot mode BEFORE creating any V8 objects
    // This enables tracking of Global handles in C++ for cleanup before CreateBlob
    v8.template_registry.snapshot_mode = true;
    v8.ffi.v8_Snapshot_EnableMode();

    const context = v8.ffi.v8_Context_New(isolate) orelse {
        log(allocator, "  ERROR: Failed to create context\n", .{});
        v8.ffi.v8_Isolate_Exit(isolate);
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.ContextFailed;
    };

    v8.ffi.v8_Context_Enter(context);

    // Initialize WebIDL runtime
    runtime.initializeRuntime(allocator);

    // Register all WebIDL interfaces
    interface_bindings.initializeBindings(isolate, context);
    log(allocator, "  Interfaces registered\n", .{});

    // Register all namespaces
    interface_bindings.registerNamespacesGeneric(namespaces, isolate, context);
    log(allocator, "  Namespaces registered\n\n", .{});

    // Step 6: Set default context for snapshot
    log(allocator, "Step 6: Setting default context for snapshot...\n", .{});
    v8.ffi.v8_SnapshotCreator_SetDefaultContext(creator, context);
    log(allocator, "  Default context set\n\n", .{});

    // Step 7: Create the snapshot blob
    log(allocator, "Step 7: Creating snapshot blob...\n", .{});

    // Exit context before creating blob (required by V8)
    v8.ffi.v8_Context_Exit(context);
    v8.ffi.v8_Isolate_Exit(isolate);

    // CRITICAL: Clear all tracked Global handles before CreateBlob
    // V8 requires no outstanding Global handles when creating a snapshot
    log(allocator, "  Clearing tracked Global handles...\n", .{});
    v8.ffi.v8_Snapshot_ClearGlobalHandles();

    var out_data: ?[*]const u8 = null;
    var out_size: c_int = 0;
    const success = v8.ffi.v8_SnapshotCreator_CreateBlob(
        creator,
        @intFromEnum(v8.ffi.FunctionCodeHandling.Keep), // Keep compiled code for faster startup
        &out_data,
        &out_size,
    );

    if (!success or out_data == null) {
        log(allocator, "  ERROR: Failed to create snapshot blob\n", .{});
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        runtime.deinitializeRuntime();
        return error.SnapshotCreationFailed;
    }

    const blob_size: usize = @intCast(out_size);
    log(allocator, "  Snapshot blob created: {d} bytes ({d:.2} MB)\n\n", .{
        blob_size,
        @as(f64, @floatFromInt(blob_size)) / (1024.0 * 1024.0),
    });

    // Step 8: Dispose SnapshotCreator (this also disposes the isolate)
    log(allocator, "Step 8: Disposing SnapshotCreator...\n", .{});
    v8.ffi.v8_SnapshotCreator_Dispose(creator);
    log(allocator, "  SnapshotCreator disposed\n\n", .{});

    // Disable snapshot mode now that snapshot is created
    v8.template_registry.snapshot_mode = false;
    v8.ffi.v8_Snapshot_DisableMode();

    // Cleanup WebIDL runtime
    runtime.deinitializeRuntime();

    // Step 9: Write blob to file
    log(allocator, "Step 9: Writing snapshot to file: {s}\n", .{output_path});
    const blob_data = out_data.?[0..blob_size];
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(blob_data);

    // Free snapshot data
    v8.ffi.v8_Snapshot_FreeData(out_data);

    log(allocator, "  Snapshot written successfully\n\n", .{});

    // Summary
    log(allocator, "============================================\n", .{});
    log(allocator, "Snapshot generation complete!\n", .{});
    log(allocator, "  Output: {s}\n", .{output_path});
    log(allocator, "  Size: {d} bytes ({d:.2} MB)\n", .{
        blob_size,
        @as(f64, @floatFromInt(blob_size)) / (1024.0 * 1024.0),
    });
    log(allocator, "  External refs: {d}\n", .{ref_count});
    log(allocator, "\nTo use this snapshot at runtime:\n", .{});
    log(allocator, "  1. Load the blob from file\n", .{});
    log(allocator, "  2. Create isolate with v8_Isolate_NewFromSnapshot()\n", .{});
    log(allocator, "  3. Create context with v8_Context_NewFromSnapshot()\n", .{});
    log(allocator, "  4. All interfaces are already registered!\n", .{});
}

/// Register external references for ALL interfaces
///
/// This iterates over all interfaces and calls registerExternalReferences()
/// on each one. This MUST be done before creating the snapshot.
fn registerAllExternalReferences() void {
    @setEvalBranchQuota(200_000);

    // Clear any previous registrations
    ext_refs.clearRuntimeReferences();

    // Register callbacks for all interfaces
    const iface_decls = @typeInfo(interfaces).@"struct".decls;
    inline for (iface_decls) |decl| {
        // Skip problematic interfaces
        if (comptime interface_bindings.shouldSkipInterface(decl.name)) continue;

        const InterfaceType = @field(interfaces, decl.name);

        // Only process types that have Meta (actual interfaces)
        if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
            // Get the V8Interface binding and register its callbacks
            const V8Binding = v8.V8Interface(InterfaceType);
            V8Binding.registerExternalReferences();
        }
    }

    // NOTE: Namespace callbacks are registered AFTER all other callbacks
    // to match the order in snapshot_loader.registerAllExternalReferences()
    // followed by registerNamespaceExternalReferences()

    // Register C++ callbacks that are created in v8_wrapper.cpp
    // These are used by FunctionTemplates but are defined in C++, not Zig
    ext_refs.registerCallbackRuntime(v8.ffi.v8_GetAsyncIteratorNextCallback());
    ext_refs.registerCallbackRuntime(v8.ffi.v8_GetAsyncIteratorReturnCallback());
    ext_refs.registerCallbackRuntime(v8.ffi.v8_GetAsyncIteratorSelfCallback());

    // Register Zig callbacks that are used for Promise handlers and dynamic callbacks
    // These are created by zig_callbacks.zig when streams invoke JS callbacks
    const zig_callbacks = @import("v8").zig_callbacks;
    ext_refs.registerCallbackRuntime(zig_callbacks.genericZigCallback);

    // Register Intl callbacks for V8 snapshot compatibility
    // MUST match snapshot_loader.registerAllExternalReferences()
    intl_binding.registerExternalReferences();

    // Register WindowProperties named property callbacks
    // MUST match snapshot_loader.registerAllExternalReferences()
    window_properties.registerExternalReferences();

    // Register context manager callbacks (Window indexed property handlers)
    // MUST match snapshot_loader.registerAllExternalReferences()
    context_manager.registerExternalReferences();

    // FINALLY: Register namespace callbacks (console, etc.)
    // This MUST be last to match the order in Browser.registerSnapshotExternalReferences()
    // which calls registerAllExternalReferences() THEN registerNamespaceExternalReferences()
    const ns_decls = @typeInfo(namespaces).@"struct".decls;
    inline for (ns_decls) |decl| {
        const NamespaceType = @field(namespaces, decl.name);

        if (@typeInfo(NamespaceType) == .@"struct" and @hasDecl(NamespaceType, "Meta")) {
            // V8Namespace might not have registerExternalReferences, but if it does, call it
            if (@hasDecl(v8.V8Namespace(NamespaceType), "registerExternalReferences")) {
                v8.V8Namespace(NamespaceType).registerExternalReferences();
            }
        }
    }
}

test "snapshot generator - external reference collection" {
    // Clear previous registrations
    ext_refs.clearRuntimeReferences();

    // Register all interface callbacks
    registerAllExternalReferences();

    // Verify we collected references
    const count = ext_refs.getRuntimeCount();
    try std.testing.expect(count > 0);

    // Get the references array
    const refs = ext_refs.getRuntimeExternalReferences();
    try std.testing.expect(refs.len > 1); // At least one ref + null terminator
    try std.testing.expectEqual(@as(isize, 0), refs[refs.len - 1]); // null-terminated
}
