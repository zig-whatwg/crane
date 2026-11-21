//! V8 Snapshot Generator: Crane's startup snapshot (whatwg_snapshot.bin).
//!
//! A build-time tool. The blob holds V8's builtins, a PLAIN default context,
//! and one Window context (index 0) made from Window's instance template -
//! with no interface object built. Blink's model (V8ContextSnapshotImpl,
//! Chromium bindings/modules/v8/v8_context_snapshot_impl.cc, BSD; lane
//! tmpl1):
//!
//! 1. A SnapshotCreator with the external references (every callback the
//!    snapshot holds is one: the same table, in the same order, at load).
//! 2. EventTarget's and Window's templates; Window's instance template is the
//!    global's: two internal fields, an immutable [[Prototype]], the
//!    WindowProxy's indexed handlers (`frames[i]`), and every exposed
//!    construct a Window realm always has as a LAZY DATA PROPERTY
//!    (interface_bindings.installExposedConstructs) - built when a realm's
//!    script first reads it.
//! 3. The default context (the base of every Context::New in a restored
//!    isolate): plain.
//! 4. The Window context, at index 0: Crane's Intl and the built-ins'
//!    toLocaleString (installSnapshotIntrinsics), Window's function
//!    instantiated.
//! 5. The two templates attached to the isolate snapshot (AddData), which a
//!    restored isolate takes back once (interface_bindings.
//!    takeSnapshotTemplates): its one copy of them. Every other template is
//!    made on first use.
//! 6. The blob, then its build stamp (the external-reference count).
//!
//! What it no longer holds - every interface object, in both contexts - cost
//! every restored isolate 1.42 MB and every restored realm ~860 KB it never
//! used (tmp/plans/tmpl1-measure.md).
//!
//! ## Usage
//!
//! ```bash
//! zig build snapshot
//! ```
//!
//! Loaded at run time by snapshot_loader / protocol_agents.createAgent
//! (v8_Isolate_NewFromSnapshot), the Window context by
//! protocol_realms.createWindowRealm (v8_Context_NewFromSnapshot).

const std = @import("std");
const v8 = @import("v8");
const context_manager = v8.context_manager;

// Import interface bindings for registration
const interface_bindings = v8.interface_bindings;

/// Default output file for the snapshot blob
const DEFAULT_OUTPUT_PATH = "whatwg_snapshot.bin";

/// The generator's progress log: kept while it works, then written to stdout
/// when it succeeded and to stderr when it failed (snapshot_generator_log.zig
/// says why: a passing build step must write nothing to stderr).
const Log = @import("snapshot_generator_log.zig").Log;

/// Entry point
///
/// Zig 0.16 removed std.process.argsAlloc and moved the filesystem onto std.Io;
/// std.process.Init supplies the argument vector, a gpa and the process Io.
pub fn main(init: std.process.Init) !void {
    // First, before any thread exists: V8's platform, and with it the key of
    // its thread isolation on x86-64 Linux, which only threads created after
    // it inherit - the engine protocol's initializeBeforeThreadCreation, as
    // every Crane process's main makes it (protocol.zig).
    v8.ffi.v8_Platform_InitializeBeforeThreadCreation();
    const io = init.io;

    var log: Log = .init(init.gpa);
    defer log.deinit();
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(io, &stdout_buf);
    var stderr_buf: [4096]u8 = undefined;
    var stderr_writer = std.Io.File.stderr().writerStreaming(io, &stderr_buf);
    generate(init, &log) catch |err| {
        log.print("snapshot generator failed: {t}\n", .{err});
        log.finish(.failed, &stdout_writer.interface, &stderr_writer.interface) catch {};
        return err;
    };
    try log.finish(.succeeded, &stdout_writer.interface, &stderr_writer.interface);
}

/// Steps 1-8 (the file comment), each logged to `log`.
fn generate(init: std.process.Init, log: *Log) !void {
    const io = init.io;

    // Parse command line arguments. `toSlice` may point into the argument vector,
    // so it is given the process-lifetime arena rather than the gpa.
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    const output_path = if (args.len > 1) args[1] else DEFAULT_OUTPUT_PATH;

    log.print("V8 Snapshot Generator with WebIDL Interfaces\n", .{});
    log.print("=============================================\n\n", .{});
    log.print("This creates a snapshot with V8 builtins AND WebIDL interfaces.\n", .{});
    log.print("This snapshot provides fast V8 isolate startup with builtins pre-compiled.\n\n", .{});

    // Step 1: Initialize V8 platform with deterministic flags
    // These flags ensure deterministic snapshot creation:
    // - --hash-seed=0: Deterministic hash seed for rehashable snapshots
    // - --predictable: Forces deterministic behavior (disables random GC, etc.)
    //
    // CRITICAL: These MUST be set BEFORE the platform starts, and they MUST
    // match the flags used in snapshot_loader.zig for loading. One
    // v8_Platform_Start sets them and starts it (initializePlatformForSnapshots).
    log.print("Step 1: Initializing V8 platform...\n", .{});
    v8.snapshot_loader.initializePlatformForSnapshots();
    log.print("  V8 platform initialized\n\n", .{});

    // Step 2: Register all external references and create SnapshotCreator
    // External references are REQUIRED for V8 snapshots - they allow V8 to
    // resolve callback function pointers when restoring context from snapshot.
    log.print("Step 2: Registering external references...\n", .{});
    v8.external_references.registerAllExternalReferences();
    const stats = v8.external_references.getExternalReferenceStats();
    log.print("  Registered {d} external references\n", .{stats.count});
    log.print("  Reference hash: 0x{x:0>16} (for determinism verification)\n", .{stats.hash});

    const ext_refs = v8.external_references.getRuntimeExternalReferencesPtr();
    log.print("Step 2b: Creating SnapshotCreator with external references...\n", .{});
    const creator = v8.ffi.v8_SnapshotCreator_New(ext_refs) orelse {
        log.print("  ERROR: Failed to create SnapshotCreator\n", .{});
        return error.SnapshotCreatorFailed;
    };
    log.print("  SnapshotCreator created successfully\n\n", .{});

    // Step 3: Getting isolate from SnapshotCreator
    log.print("Step 3: Getting isolate from SnapshotCreator...\n", .{});
    const isolate = v8.ffi.v8_SnapshotCreator_GetIsolate(creator) orelse {
        log.print("  ERROR: Failed to get isolate from SnapshotCreator\n", .{});
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.IsolateFailed;
    };
    log.print("  Isolate obtained\n\n", .{});

    // Step 4: Enter isolate and enable snapshot mode
    log.print("Step 4: Entering isolate...\n", .{});
    v8.ffi.v8_Isolate_Enter(isolate);

    // Enable snapshot mode - this tracks all Global handles created
    // so they can be cleared before CreateBlob (which requires no Global handles)
    v8.ffi.v8_Snapshot_EnableMode();
    log.print("  Isolate entered, snapshot mode enabled\n\n", .{});

    // Step 5: Create and set up snapshot contexts WITH WebIDL interfaces
    // V8's SnapshotCreator requires SetDefaultContext() to be called.
    // We create contexts manually so we can register ALL WebIDL interfaces.
    log.print("Step 5: Creating contexts with WebIDL interfaces...\n", .{});

    // Step 5a: Create global template using Window's InstanceTemplate
    // This is CRITICAL for `window instanceof Window` to work:
    // - Window's FunctionTemplate inherits from EventTarget
    // - When we use Window's InstanceTemplate as the global template,
    //   the global object's prototype chain will be: global → Window.prototype → EventTarget.prototype
    // - This makes `window instanceof Window` return true
    log.print("  5a: Creating Window FunctionTemplate for global...\n", .{});

    // Create EventTarget template first (Window's parent in the inheritance chain)
    // We must create and register it BEFORE Window so that Window's creation uses the
    // same EventTarget template instead of creating a new one.
    const event_target_template = interface_bindings.EventTarget.createTemplate(isolate);
    v8.template_registry.register("EventTarget", event_target_template, isolate);
    log.print("  EventTarget FunctionTemplate created and registered\n", .{});

    // Create the Window FunctionTemplate (with inheritance chain)
    // Since EventTarget is already in template_registry, Window's createTemplate will
    // use the same EventTarget template we just created.
    const window_template = interface_bindings.Window.createTemplate(isolate);
    log.print("  Window FunctionTemplate created (inherits from EventTarget)\n", .{});

    // Registered, as EventTarget's is: Step 5d attaches the registered
    // templates to the isolate snapshot.
    v8.template_registry.register("Window", window_template, isolate);
    log.print("  Window template registered in template_registry\n", .{});

    // Get Window's InstanceTemplate - this will be our global template
    // The Window interface already configures:
    // - 2 internal fields (for impl pointer + type info)
    // - Immutable prototype (per WebIDL spec §3.8 for global interfaces)
    const global_template = v8.ffi.v8_FunctionTemplate_InstanceTemplate(window_template);
    log.print("  Got Window's InstanceTemplate as global template\n", .{});

    // Add indexed property handlers for frames[index] access (WindowProxy behavior)
    // These callbacks are registered in external_references via context_manager.registerExternalReferences()
    v8.ffi.v8_ObjectTemplate_SetIndexedPropertyHandlerWithDefiner(
        global_template,
        context_manager.windowIndexedPropertyGetter,
        null, // setter - not needed for read-only frames access
        context_manager.windowIndexedPropertyQuery,
        context_manager.windowIndexedPropertyDeleter, // WindowProxy [[Delete]] for an index
        context_manager.windowIndexedPropertyEnumerator,
        null, // definer - not needed
        null, // descriptor - not needed
    );
    log.print("  Global template configured with indexed handlers for frames[index]\n", .{});

    // No named property handler on the global itself. WebIDL puts a [Global]
    // interface's named properties on its named properties object
    // (WindowProperties, window_properties.zig), which sits in the global's
    // prototype chain - below its own properties. An interceptor here answered
    // BEFORE them, so `<div id=log>` shadowed the page's `log` function, and it
    // ran on every global identifier lookup. Named elements and child
    // navigable names are both WindowProperties' job.

    // Every Window realm's exposed constructs (WebIDL 3.7): lazy data
    // properties of the global's template, so the snapshot's context - and
    // every context restored from it - has them and builds none of them
    // (Blink: IDLMemberInstaller::InstallExposedConstructs on Window's
    // instance template). The snapshot holds no interface object: until lane
    // tmpl1 both of its contexts held all of them, and every realm restored
    // from it deserialized and replaced them - keeping both - while the
    // isolate kept the templates twice (tmp/plans/tmpl1-measure.md).
    interface_bindings.installExposedConstructs(.Window, global_template);
    log.print("  Window's exposed constructs: lazy data properties of its instance template\n", .{});

    // Step 5b: the DEFAULT context - the one every Context::New in a restored
    // isolate starts from (a worker or worklet realm's, a plain utility
    // global's) - plain, with nothing of the Window's: Blink's
    // V8ContextSnapshotImpl::TakeSnapshot, "SetDefaultContext(
    // v8::Context::New(isolate))". It held every interface object, and every
    // such Context::New deserialized it and copied them onto its global.
    log.print("  5b: Creating the plain default context...\n", .{});
    const default_context = v8.ffi.v8_Context_New(isolate) orelse {
        log.print("  ERROR: Failed to create default context\n", .{});
        v8.ffi.v8_Isolate_Exit(isolate);
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.ContextFailed;
    };
    v8.ffi.v8_SnapshotCreator_SetDefaultContext(creator, default_context);
    log.print("  Default context set\n", .{});

    // Step 5c: the Window context (index 0, what Context::FromSnapshot(isolate,
    // 0) restores): its global an instance of Window's instance template.
    log.print("  5c: Creating the Window context (index 0)...\n", .{});
    const indexed_context = v8.ffi.v8_Context_NewWithGlobalTemplate(isolate, global_template) orelse {
        log.print("  ERROR: Failed to create indexed context\n", .{});
        v8.ffi.v8_Isolate_Exit(isolate);
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.ContextFailed;
    };
    v8.ffi.v8_Context_Enter(indexed_context);
    // What a Window realm's context has beside its template's: Crane's Intl
    // and the built-ins' toLocaleString.
    interface_bindings.installSnapshotIntrinsics(isolate, indexed_context);
    // Window's function instantiated in the context, so the context's
    // template instantiation cache carries it: a restored realm's lazily
    // built Window interface object is then this one, whose prototype the
    // global's chain has. Instantiated only - not set up as an interface
    // object (that is each realm's, as it is first read: its [SecureContext]
    // members depend on the realm).
    if (v8.ffi.v8_FunctionTemplate_GetFunction(window_template, indexed_context)) |window_function| v8.ffi.v8_Function_Dispose(window_function);
    v8.ffi.v8_Context_Exit(indexed_context);

    const context_index = v8.ffi.v8_SnapshotCreator_AddContext(creator, indexed_context);
    if (context_index != 0) {
        log.print("  ERROR: the Window context went to index {d}, not 0\n", .{context_index});
        v8.ffi.v8_Isolate_Exit(isolate);
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.ContextFailed;
    }
    log.print("  Window context added at index 0\n", .{});

    // Step 5d: the templates that context was made from, attached to the
    // isolate snapshot for a restored isolate to take back once
    // (interface_bindings.snapshot_templates, takeSnapshotTemplates; Blink:
    // TakeSnapshotForWorld's AddData) - its one copy of them.
    for (interface_bindings.snapshot_templates, 0..) |name, expected_index| {
        const template = v8.template_registry.getTemplateForIsolate(name, isolate) orelse {
            log.print("  ERROR: no {s} template to attach\n", .{name});
            v8.ffi.v8_Isolate_Exit(isolate);
            v8.ffi.v8_SnapshotCreator_Dispose(creator);
            return error.ContextFailed;
        };
        const data_index = v8.ffi.v8_SnapshotCreator_AddFunctionTemplate(creator, template);
        if (data_index != expected_index) {
            log.print("  ERROR: {s}'s template went to data index {d}, not {d}\n", .{ name, data_index, expected_index });
            v8.ffi.v8_Isolate_Exit(isolate);
            v8.ffi.v8_SnapshotCreator_Dispose(creator);
            return error.ContextFailed;
        }
    }
    log.print("  {d} templates attached to the isolate snapshot\n\n", .{interface_bindings.snapshot_templates.len});

    // Step 6: Create the snapshot blob
    log.print("Step 6: Creating snapshot blob...\n", .{});

    // Clear all Global handles created during interface registration.
    // V8's SnapshotCreator::CreateBlob() requires that there be no outstanding
    // Global handles when called. Our wrapper tracks all Global handles created
    // since v8_Snapshot_EnableMode() was called.
    //
    // NOTE: This does NOT affect the contexts - SetDefaultContext and AddContext
    // have already captured the context state internally. The Global handles we're
    // clearing are the intermediate ones created during interface registration.
    log.print("  Clearing Global handles created during registration...\n", .{});
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
        @backingInt(v8.ffi.FunctionCodeHandling.Clear),
        &out_data,
        &out_size,
    );

    if (!success or out_data == null) {
        log.print("  ERROR: Failed to create snapshot blob\n", .{});
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return error.SnapshotCreationFailed;
    }

    const blob_size: usize = @intCast(out_size);
    log.print("  Snapshot blob created: {d} bytes ({d:.2} KB)\n\n", .{
        blob_size,
        @as(f64, @floatFromInt(blob_size)) / 1024.0,
    });

    // Step 7: Dispose SnapshotCreator (this also disposes the isolate)
    log.print("Step 7: Disposing SnapshotCreator...\n", .{});
    v8.ffi.v8_SnapshotCreator_Dispose(creator);
    log.print("  SnapshotCreator disposed\n\n", .{});

    // Step 8: Write blob to file
    log.print("Step 8: Writing snapshot to file: {s}\n", .{output_path});
    const blob_data = out_data.?[0..blob_size];
    const file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, blob_data);
    // The build stamp: the loader restores only a blob made against its own
    // external-reference table (snapshot_loader.splitStamp).
    var stamp: [v8.snapshot_loader.stamp_len]u8 = undefined;
    v8.snapshot_loader.writeStamp(&stamp, stats.count);
    try file.writeStreamingAll(io, &stamp);

    // Free snapshot data
    v8.ffi.v8_Snapshot_FreeData(out_data);

    log.print("  Snapshot written successfully\n\n", .{});

    // Summary
    log.print("=============================================\n", .{});
    log.print("Snapshot generation complete!\n", .{});
    log.print("  Output: {s}\n", .{output_path});
    log.print("  Size: {d} bytes ({d:.2} KB)\n", .{
        blob_size,
        @as(f64, @floatFromInt(blob_size)) / 1024.0,
    });
    log.print("  Holds: V8's builtins, a plain default context, the Window context (exposed constructs lazy), {d} templates\n", .{interface_bindings.snapshot_templates.len});
}
