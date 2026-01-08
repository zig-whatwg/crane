//! V8 Snapshot Generator with WebIDL Interface Registration
//!
//! This build-time tool creates a V8 heap snapshot containing V8 builtins
//! AND all WebIDL interfaces pre-registered on the global object.
//!
//! ## How It Works
//!
//! 1. Creates a SnapshotCreator with external references (required for callbacks)
//! 2. Gets the isolate from SnapshotCreator
//! 3. Creates a global ObjectTemplate with proper configuration:
//!    - 2 internal fields (for Window impl pointer + destructor type)
//!    - Immutable prototype (per WebIDL spec §3.8)
//!    - Indexed property handlers (for frames[index] access)
//! 4. Creates contexts with ALL WebIDL interfaces registered
//! 5. Creates the snapshot blob
//! 6. Writes the blob to a file (whatwg_snapshot.bin)
//!
//! ## What's In The Snapshot
//!
//! - V8 JavaScript builtins (Object, Array, Promise, Map, Set, etc.)
//! - ALL WebIDL interfaces (EventTarget, Node, Element, Document, etc.)
//! - Constructor inheritance chains (Element.__proto__ = Node, etc.)
//! - Pre-compiled bytecode for faster startup
//! - Global template with proper internal fields for Window binding
//!
//! ## External References
//!
//! External references are C++ callback function pointers that V8 needs to
//! resolve when loading the snapshot. The SAME external references array
//! (in the SAME order) MUST be provided at both snapshot creation and loading.
//!
//! ## Usage
//!
//! Build and run:
//! ```bash
//! zig build snapshot
//! ```
//!
//! The output file is loaded at runtime:
//! ```zig
//! const isolate = v8.v8_Isolate_NewFromSnapshot(data, size, ext_refs);
//! const context = v8.v8_Context_NewFromSnapshot(isolate);  // Interfaces already registered!
//! // No need to call initializeBindings() - interfaces are in snapshot!
//! ```

const std = @import("std");
const v8 = @import("v8");
const context_manager = v8.context_manager;

// Import interface bindings for registration
const interface_bindings = v8.interface_bindings;

// Import global constructor handler for lazy interface installation
const global_constructor_handler = v8.global_constructor_handler;

// Import snapshot context index for multi-context snapshot generation
const SnapshotContextIndex = v8.SnapshotContextIndex;

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

    // Step 4: Enter isolate and enable snapshot mode
    log(allocator, "Step 4: Entering isolate...\\n", .{});
    v8.ffi.v8_Isolate_Enter(isolate);

    // Enable snapshot mode - this tracks all Global handles created
    // so they can be cleared before CreateBlob (which requires no Global handles)
    v8.ffi.v8_Snapshot_EnableMode();
    log(allocator, "  Isolate entered, snapshot mode enabled\\n\\n", .{});

    // Step 5: Create and set up snapshot contexts WITH WebIDL interfaces
    // V8's SnapshotCreator requires SetDefaultContext() to be called.
    // We create contexts manually so we can register ALL WebIDL interfaces.
    log(allocator, "Step 5: Creating contexts with WebIDL interfaces...\\n", .{});

    // Step 5a: Create global ObjectTemplate with proper configuration
    // This matches what context_manager.zig expects at runtime:
    // - 2 internal fields (for Window impl pointer + type info)
    // - Immutable prototype (per WebIDL spec §3.8)
    // - Indexed property handlers (for frames[index] access)
    log(allocator, "  5a: Creating global template with internal fields and handlers...\\n", .{});
    const global_template = v8.ffi.v8_ObjectTemplate_New(isolate);

    // Set 2 internal fields for Window binding (instance pointer + type info)
    v8.ffi.v8_ObjectTemplate_SetInternalFieldCount(global_template, 2);

    // Set immutable prototype per WebIDL spec §3.8 for global objects
    v8.ffi.v8_ObjectTemplate_SetImmutableProto(global_template);

    // Set indexed property handlers for frames[index] access (WindowProxy behavior)
    // These callbacks are registered in external_references via context_manager.registerExternalReferences()
    v8.ffi.v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
        global_template,
        context_manager.windowIndexedPropertyGetter,
        null, // setter - not needed for read-only frames access
        context_manager.windowIndexedPropertyQuery,
        context_manager.windowIndexedPropertyEnumerator,
        null, // descriptor - not needed
    );

    // Set named property handler for lazy global constructor installation
    // When JavaScript accesses `window.MessageEvent` (or any non-core interface),
    // this handler creates the template on-demand and installs the constructor.
    // Uses kNonMasking flag so it only fires for properties that don't exist yet.
    global_constructor_handler.installOnGlobalTemplate(global_template);
    log(allocator, "  Global template configured: 2 internal fields, immutable proto, indexed handlers, lazy constructors\\n", .{});

    // Step 5b: Create default context with global template
    log(allocator, "  5b: Creating default context with global template...\\n", .{});
    const default_context = v8.ffi.v8_Context_NewWithGlobalTemplate(isolate, global_template) orelse {
        log(allocator, "  ERROR: Failed to create default context\\n", .{});
        v8.ffi.v8_Isolate_Exit(isolate);
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.ContextFailed;
    };

    // Enter context and register all interfaces
    log(allocator, "  5c: Entering default context and registering interfaces...\\n", .{});
    v8.ffi.v8_Context_Enter(default_context);

    // Register only core DOM interfaces in default context (Chromium-style minimal snapshot)
    // Non-core interfaces are created on-demand via createTemplateOnDemand()
    interface_bindings.initializeCoreBindingsForScope(isolate, default_context, .Window);
    log(allocator, "  5d: Core DOM interfaces registered in default context (minimal snapshot)\\n", .{});

    // Exit context before adding to snapshot
    v8.ffi.v8_Context_Exit(default_context);

    // Set as default context for snapshot
    v8.ffi.v8_SnapshotCreator_SetDefaultContext(creator, default_context);
    log(allocator, "  Default context with interfaces set\\n", .{});

    // Step 5e: Create indexed contexts - one per implemented scope kind
    // Each scope kind (window, dedicated_worker, etc.) gets its own context with
    // only the interfaces exposed to that scope. Contexts are added at indices
    // matching SnapshotContextIndex enum values for deterministic restoration.
    log(allocator, "  5e: Creating indexed contexts for each scope kind...\\n", .{});

    // Create a context for each implemented scope kind
    // Use inline for to make scope_index comptime-known (required by initializeBindingsForScope)
    inline for (SnapshotContextIndex.implemented) |scope_index| {
        const helper_scope = comptime scope_index.toHelperScope();
        const scope_name = scope_index.globalInterfaceName();

        log(allocator, "    Creating context for {s} (index {d})...\\n", .{ scope_name, @intFromEnum(scope_index) });

        // Create context with the global template
        const scope_context = v8.ffi.v8_Context_NewWithGlobalTemplate(isolate, global_template) orelse {
            log(allocator, "    ERROR: Failed to create context for {s}\\n", .{scope_name});
            v8.ffi.v8_Isolate_Exit(isolate);
            v8.ffi.v8_SnapshotCreator_Dispose(creator);
            return error.ContextFailed;
        };

        // Enter context and register scope-specific interfaces
        v8.ffi.v8_Context_Enter(scope_context);

        // Register only core DOM interfaces for this scope (Chromium-style minimal snapshot)
        // Non-core interfaces are created on-demand via createTemplateOnDemand()
        interface_bindings.initializeCoreBindingsForScope(isolate, scope_context, helper_scope);

        // Exit context before adding to snapshot
        v8.ffi.v8_Context_Exit(scope_context);

        // Add context at the index matching the scope kind
        // V8's AddContext returns the actual index assigned
        const assigned_index = v8.ffi.v8_SnapshotCreator_AddContext(creator, scope_context);
        const expected_index = @intFromEnum(scope_index);

        if (assigned_index == std.math.maxInt(usize)) {
            log(allocator, "    ERROR: Failed to add context for {s}\\n", .{scope_name});
            v8.ffi.v8_Isolate_Exit(isolate);
            v8.ffi.v8_SnapshotCreator_Dispose(creator);
            return error.ContextFailed;
        }

        // Verify deterministic index assignment
        if (assigned_index != expected_index) {
            log(allocator, "    WARNING: Context index mismatch for {s}: expected {d}, got {d}\\n", .{ scope_name, expected_index, assigned_index });
        }

        log(allocator, "    {s} context added at index {d}\\n", .{ scope_name, assigned_index });
    }

    log(allocator, "  Created {d} scope-specific contexts\\n\\n", .{SnapshotContextIndex.implemented.len});

    // Step 6: Create the snapshot blob
    log(allocator, "Step 6: Creating snapshot blob...\\n", .{});

    // Clear all Global handles created during interface registration.
    // V8's SnapshotCreator::CreateBlob() requires that there be no outstanding
    // Global handles when called. Our wrapper tracks all Global handles created
    // since v8_Snapshot_EnableMode() was called.
    //
    // NOTE: This does NOT affect the contexts - SetDefaultContext and AddContext
    // have already captured the context state internally. The Global handles we're
    // clearing are the intermediate ones created during interface registration.
    log(allocator, "  Clearing Global handles created during registration...\\n", .{});
    v8.ffi.v8_Snapshot_ClearGlobalHandles();

    // Exit isolate before creating blob (required by V8)
    v8.ffi.v8_Isolate_Exit(isolate);

    // Disable snapshot mode
    v8.ffi.v8_Snapshot_DisableMode();

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
    log(allocator, "\\nThis snapshot contains V8 builtins AND scope-specific WebIDL interfaces!\\n", .{});
    log(allocator, "Contains {d} contexts (one per implemented scope kind):\\n", .{SnapshotContextIndex.implemented.len});
    for (SnapshotContextIndex.implemented) |scope_index| {
        log(allocator, "  - {s} (index {d})\\n", .{ scope_index.globalInterfaceName(), @intFromEnum(scope_index) });
    }
    log(allocator, "\\nTo use this snapshot at runtime:\\n", .{});
    log(allocator, "  1. Load the blob from file\\n", .{});
    log(allocator, "  2. Create isolate with v8_Isolate_NewFromSnapshot(data, size, ext_refs)\\n", .{});
    log(allocator, "  3. Restore context with v8_Context_FromSnapshot(isolate, scope_index)\\n", .{});
    log(allocator, "  4. Only interfaces for that scope are available - scope-specific!\\n", .{});
}
