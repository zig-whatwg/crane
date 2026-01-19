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

    // Step 5a: Create global template using Window's InstanceTemplate
    // This is CRITICAL for `window instanceof Window` to work:
    // - Window's FunctionTemplate inherits from EventTarget
    // - When we use Window's InstanceTemplate as the global template,
    //   the global object's prototype chain will be: global → Window.prototype → EventTarget.prototype
    // - This makes `window instanceof Window` return true
    log(allocator, "  5a: Creating Window FunctionTemplate for global...\\n", .{});

    // Create EventTarget template first (Window's parent in the inheritance chain)
    // We must create and register it BEFORE Window so that Window's creation uses the
    // same EventTarget template instead of creating a new one.
    const event_target_template = interface_bindings.EventTarget.createTemplate(isolate);
    v8.template_registry.register("EventTarget", event_target_template, isolate);
    log(allocator, "  EventTarget FunctionTemplate created and registered\\n", .{});

    // Create the Window FunctionTemplate (with inheritance chain)
    // Since EventTarget is already in template_registry, Window's createTemplate will
    // use the same EventTarget template we just created.
    const window_template = interface_bindings.Window.createTemplate(isolate);
    log(allocator, "  Window FunctionTemplate created (inherits from EventTarget)\\n", .{});

    // CRITICAL: Register Window template in template_registry BEFORE initializeBindings
    // This ensures that when initializeBindings calls registerGlobalFast for Window,
    // it reuses this SAME template instead of creating a new one. Otherwise we'd have
    // TWO Window templates with different prototypes, breaking `window instanceof Window`.
    v8.template_registry.register("Window", window_template, isolate);
    log(allocator, "  Window template registered in template_registry\\n", .{});

    // Get Window's InstanceTemplate - this will be our global template
    // The Window interface already configures:
    // - 2 internal fields (for impl pointer + type info)
    // - Immutable prototype (per WebIDL spec §3.8 for global interfaces)
    const global_template = v8.ffi.v8_FunctionTemplate_InstanceTemplate(window_template);
    log(allocator, "  Got Window's InstanceTemplate as global template\\n", .{});

    // Add indexed property handlers for frames[index] access (WindowProxy behavior)
    // These callbacks are registered in external_references via context_manager.registerExternalReferences()
    v8.ffi.v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
        global_template,
        context_manager.windowIndexedPropertyGetter,
        null, // setter - not needed for read-only frames access
        context_manager.windowIndexedPropertyQuery,
        context_manager.windowIndexedPropertyEnumerator,
        null, // descriptor - not needed
    );
    log(allocator, "  Global template configured with indexed handlers for frames[index]\\n", .{});

    // Add named property handlers for frames['name'] and named element access
    // Per HTML spec §7.4.3, Window supports named property access for:
    // 1. Child browsing contexts (iframe names) - frames['name'] returns contentWindow
    // 2. Named elements in the document (elements with id/name attributes)
    //
    // IMPORTANT: Use kNone flag to intercept all named property access
    // The getter checks isBuiltinWindowProperty() to skip built-in Window properties
    v8.ffi.v8_ObjectTemplate_SetNamedPropertyHandlerFull(
        global_template,
        context_manager.windowNamedPropertyGetter,
        null, // setter - not needed for read-only frames access
        context_manager.windowNamedPropertyQuery,
        null, // deleter - not needed
        null, // enumerator - not needed (named frame properties are not enumerable)
        null, // descriptor - not needed
        .kNone, // No flags - intercept all named properties
    );
    log(allocator, "  Global template configured with named handlers for frames['name']\\n", .{});

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

    // Register ALL WebIDL interfaces in this context
    interface_bindings.initializeBindings(isolate, default_context);
    log(allocator, "  5d: WebIDL interfaces registered in default context\\n", .{});

    // CRITICAL: Set global's prototype to Window.prototype for `window instanceof Window`
    // This must be done AFTER initializeBindings registers Window constructor but BEFORE
    // the context is serialized into the snapshot. The global was created from Window's
    // InstanceTemplate, but ObjectTemplate doesn't automatically inherit FunctionTemplate's
    // prototype chain. We must set it manually here during snapshot creation.
    setGlobalPrototypeToWindow(isolate, default_context, allocator);

    // Exit context before adding to snapshot
    v8.ffi.v8_Context_Exit(default_context);

    // Set as default context for snapshot
    v8.ffi.v8_SnapshotCreator_SetDefaultContext(creator, default_context);
    log(allocator, "  Default context with interfaces set\\n", .{});

    // Step 5e: Create indexed context (at index 0) with the same global template
    // This is the context that will be restored via Context::FromSnapshot(isolate, 0)
    log(allocator, "  5e: Creating indexed context with global template...\\n", .{});
    const indexed_context = v8.ffi.v8_Context_NewWithGlobalTemplate(isolate, global_template) orelse {
        log(allocator, "  ERROR: Failed to create indexed context\\n", .{});
        v8.ffi.v8_Isolate_Exit(isolate);
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.ContextFailed;
    };

    // Enter context and register all interfaces
    log(allocator, "  5f: Entering indexed context and registering interfaces...\\n", .{});
    v8.ffi.v8_Context_Enter(indexed_context);

    // Register ALL WebIDL interfaces in this context too
    interface_bindings.initializeBindings(isolate, indexed_context);
    log(allocator, "  5g: WebIDL interfaces registered in indexed context\\n", .{});

    // CRITICAL: Set global's prototype to Window.prototype for `window instanceof Window`
    setGlobalPrototypeToWindow(isolate, indexed_context, allocator);

    // Exit context before adding to snapshot
    v8.ffi.v8_Context_Exit(indexed_context);

    // Add indexed context at index 0 - this is what Context::FromSnapshot(isolate, 0) retrieves
    const context_index = v8.ffi.v8_SnapshotCreator_AddContext(creator, indexed_context);
    if (context_index == std.math.maxInt(usize)) {
        log(allocator, "  ERROR: Failed to add indexed context\\n", .{});
        v8.ffi.v8_Isolate_Exit(isolate);
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.ContextFailed;
    }
    log(allocator, "  Indexed context with interfaces added at index {d}\\n\\n", .{context_index});

    // Note: ShadowRealm contexts use index 0 as well. V8's ShadowRealm implementation
    // correctly filters out host objects (document, window, etc.) from the global scope.
    // Per TC39 spec, ShadowRealm only exposes JavaScript built-ins, not Web APIs.

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
    log(allocator, "\\nThis snapshot contains V8 builtins AND WebIDL interfaces!\\n", .{});
    log(allocator, "All interfaces are pre-registered - no runtime registration needed.\\n", .{});
    log(allocator, "\\nTo use this snapshot at runtime:\\n", .{});
    log(allocator, "  1. Load the blob from file\\n", .{});
    log(allocator, "  2. Create isolate with v8_Isolate_NewFromSnapshot(data, size, ext_refs)\\n", .{});
    log(allocator, "  3. Restore context with v8_Context_NewFromSnapshot(isolate)\\n", .{});
    log(allocator, "  4. Interfaces are already available - no initializeBindings() needed!\\n", .{});
}

/// Set global's prototype to Window.prototype for `window instanceof Window`
///
/// This is called during snapshot creation AFTER initializeBindings registers the Window
/// constructor. The global object was created from an ObjectTemplate, which doesn't
/// automatically inherit the FunctionTemplate's prototype chain. We must set
/// global.__proto__ = Window.prototype manually.
///
/// This must be done BEFORE the snapshot is finalized because:
/// 1. After snapshot, the global's prototype is immutable (SetImmutableProto)
/// 2. SetPrototypeV2 will fail at runtime on the restored context
fn setGlobalPrototypeToWindow(isolate: *v8.ffi.Isolate, context: *v8.ffi.Context, allocator: std.mem.Allocator) void {
    log(allocator, "  Setting global's prototype to Window.prototype...\\n", .{});

    const global = v8.ffi.v8_Context_Global(context) orelse {
        log(allocator, "  ERROR: Failed to get global object\\n", .{});
        return;
    };

    // Get Window constructor from global
    const window_key = v8.ffi.v8_String_NewFromUtf8(isolate, "Window", 6);
    if (window_key == null) {
        log(allocator, "  ERROR: Failed to create 'Window' string\\n", .{});
        return;
    }

    const window_ctor = v8.ffi.v8_Object_Get(global, context, @ptrCast(window_key)) orelse {
        log(allocator, "  ERROR: Window constructor not found on global\\n", .{});
        return;
    };

    // Get Window.prototype
    const proto_key = v8.ffi.v8_String_NewFromUtf8(isolate, "prototype", 9);
    if (proto_key == null) {
        log(allocator, "  ERROR: Failed to create 'prototype' string\\n", .{});
        return;
    }

    const window_proto = v8.ffi.v8_Object_Get(@ptrCast(window_ctor), context, @ptrCast(proto_key)) orelse {
        log(allocator, "  ERROR: Window.prototype not found\\n", .{});
        return;
    };

    // Set global's prototype to Window.prototype
    // Use SetPrototypeV2 which is the proper API for global objects
    const result = v8.ffi.v8_Object_SetPrototypeV2(global, context, window_proto);
    if (result) {
        log(allocator, "  SUCCESS: global.__proto__ = Window.prototype\\n", .{});
    } else {
        log(allocator, "  WARNING: SetPrototypeV2 returned false - trying old API...\\n", .{});
        // Fallback to old API
        const old_result = v8.ffi.v8_Object_SetPrototype(global, context, window_proto);
        if (old_result) {
            log(allocator, "  SUCCESS (old API): global.__proto__ = Window.prototype\\n", .{});
        } else {
            log(allocator, "  ERROR: Both SetPrototypeV2 and SetPrototype failed!\\n", .{});
        }
    }
}
