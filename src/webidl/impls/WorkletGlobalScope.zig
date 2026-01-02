//! Implementation for WorkletGlobalScope interface
//!
//! Spec: HTML Standard § 10.3.2 The WorkletGlobalScope interface
//! https://html.spec.whatwg.org/#workletglobalscope
//!
//! WorkletGlobalScope is the base class for all worklet global scopes.
//! Unlike Workers, Worklets:
//! - Are designed for high-performance, low-latency operations
//! - Can have multiple instances running in parallel
//! - Have a restricted API surface (no DOM, limited globals)
//! - Load modules via Worklet.addModule()

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WorkletGlobalScope = interfaces.WorkletGlobalScope;

pub const State = WorkletGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    ModuleLoadError,
    OutOfMemory,
};

/// Type of worklet - determines which specialized global scope to use
pub const WorkletType = enum {
    audio,
    paint,
    animation,
    layout,
    shared_storage,

    pub fn getName(self: WorkletType) []const u8 {
        return switch (self) {
            .audio => "AudioWorkletGlobalScope",
            .paint => "PaintWorkletGlobalScope",
            .animation => "AnimationWorkletGlobalScope",
            .layout => "LayoutWorkletGlobalScope",
            .shared_storage => "SharedStorageWorkletGlobalScope",
        };
    }
};

/// Represents a loaded module in the worklet
pub const LoadedModule = struct {
    /// The module URL (normalized)
    url: []const u8,
    /// Whether the module has been evaluated
    evaluated: bool,
    /// Module record (opaque pointer to V8 module)
    module_record: ?*anyopaque,

    pub fn deinit(self: *LoadedModule, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        // Note: module_record is owned by V8, we don't free it
    }
};

/// Internal state for WorkletGlobalScope implementation
pub const InternalState = struct {
    /// Type of this worklet
    worklet_type: WorkletType,

    /// The origin for this worklet
    origin: []const u8,

    /// Whether this is a secure context (worklets require secure context)
    is_secure_context: bool,

    /// Loaded modules registry
    loaded_modules: std.StringHashMap(LoadedModule),

    /// Pending module fetches (URLs currently being loaded)
    pending_modules: std.StringHashMap(void),

    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        worklet_type: WorkletType,
        origin: []const u8,
        is_secure_context: bool,
    ) !*InternalState {
        const internal = try allocator.create(InternalState);
        errdefer allocator.destroy(internal);

        const origin_copy = try allocator.dupe(u8, origin);
        errdefer allocator.free(origin_copy);

        internal.* = InternalState{
            .worklet_type = worklet_type,
            .origin = origin_copy,
            .is_secure_context = is_secure_context,
            .loaded_modules = std.StringHashMap(LoadedModule).init(allocator),
            .pending_modules = std.StringHashMap(void).init(allocator),
            .allocator = allocator,
        };

        return internal;
    }

    pub fn deinit(self: *InternalState) void {
        // Clean up loaded modules
        var mod_iter = self.loaded_modules.iterator();
        while (mod_iter.next()) |entry| {
            var module = entry.value_ptr;
            module.deinit(self.allocator);
        }
        self.loaded_modules.deinit();

        // Clean up pending modules (just keys, no values to free)
        self.pending_modules.deinit();

        self.allocator.free(self.origin);
        self.allocator.destroy(self);
    }

    /// Check if a module is already loaded
    pub fn isModuleLoaded(self: *InternalState, url: []const u8) bool {
        return self.loaded_modules.contains(url);
    }

    /// Check if a module is currently being loaded
    pub fn isModulePending(self: *InternalState, url: []const u8) bool {
        return self.pending_modules.contains(url);
    }

    /// Mark a module as pending (being loaded)
    pub fn markModulePending(self: *InternalState, url: []const u8) !void {
        const url_copy = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(url_copy);
        try self.pending_modules.put(url_copy, {});
    }

    /// Register a loaded module
    pub fn registerModule(self: *InternalState, url: []const u8, module_record: ?*anyopaque) !void {
        // Remove from pending
        if (self.pending_modules.fetchRemove(url)) |kv| {
            self.allocator.free(kv.key);
        }

        // Add to loaded modules
        const url_copy = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(url_copy);

        try self.loaded_modules.put(url_copy, LoadedModule{
            .url = url_copy,
            .evaluated = true,
            .module_record = module_record,
        });
    }

    /// Mark module load as failed (remove from pending)
    pub fn markModuleFailed(self: *InternalState, url: []const u8) void {
        if (self.pending_modules.fetchRemove(url)) |kv| {
            self.allocator.free(kv.key);
        }
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // Note: Internal state should be set up by initWithType or specialized worklet init
    return instance;
}

/// Initialize with worklet type and origin
pub fn initWithType(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    worklet_type: WorkletType,
    origin: []const u8,
    is_secure_context: bool,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const internal = try InternalState.init(allocator, worklet_type, origin, is_secure_context);

    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Helper to get internal state from instance
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Get internal state with a custom state type (for subclasses)
pub fn getInternalStateTyped(instance: *runtime.Instance, comptime StateType: type) ?*InternalState {
    const state = instance.getState(StateType);
    // Navigate to the base WorkletGlobalScope state
    if (@hasField(@TypeOf(state.*), "base")) {
        if (@hasField(@TypeOf(state.base), "own")) {
            return state.base.own._internal;
        }
    }
    if (@hasField(@TypeOf(state.*), "own")) {
        return state.own._internal;
    }
    return null;
}

// ============================================================================
// Public API for integration
// ============================================================================

/// Create a new WorkletGlobalScope for a given origin and type
/// This is used when creating a new worklet context.
pub fn createForOrigin(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    worklet_type: WorkletType,
    origin: []const u8,
    is_secure_context: bool,
) !*runtime.Instance {
    return initWithType(allocator, StateType, vtable, ctx, worklet_type, origin, is_secure_context);
}

/// Get the worklet type for this scope
pub fn getWorkletType(instance: *runtime.Instance) ?WorkletType {
    const internal = getInternalState(instance) orelse return null;
    return internal.worklet_type;
}

/// Get the origin for this worklet
pub fn getOrigin(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternalState(instance) orelse return null;
    return internal.origin;
}

/// Check if this worklet is in a secure context
pub fn isSecureContext(instance: *runtime.Instance) bool {
    const internal = getInternalState(instance) orelse return false;
    return internal.is_secure_context;
}

/// Check if a module URL is already loaded in this worklet
pub fn isModuleLoaded(instance: *runtime.Instance, url: []const u8) bool {
    const internal = getInternalState(instance) orelse return false;
    return internal.isModuleLoaded(url);
}

/// Register a module as loaded
pub fn registerModule(instance: *runtime.Instance, url: []const u8, module_record: ?*anyopaque) !void {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return internal.registerModule(url, module_record);
}

/// Create internal state for a worklet global scope
/// This is called by Worklet.addModule() to prepare worklet state before
/// the actual V8 context is created.
/// Returns the internal state that should be stored by the caller.
pub fn createInternalStateForWorklet(
    allocator: std.mem.Allocator,
    worklet_type: WorkletType,
    origin: []const u8,
) !*InternalState {
    return try InternalState.init(
        allocator,
        worklet_type,
        origin,
        true, // Worklets always require secure context
    );
}

// ============================================================================
// Module Evaluation
// ============================================================================

/// Evaluate a module in this worklet's context
///
/// Spec: HTML Standard § 10.3.2 The WorkletGlobalScope interface
/// https://html.spec.whatwg.org/#worklet-global-scope-type
///
/// This compiles and evaluates JavaScript module source code in the worklet's
/// V8 context. The module is registered upon successful evaluation.
///
/// Arguments:
///   - instance: The WorkletGlobalScope instance
///   - source: UTF-8 encoded JavaScript module source code
///   - url: The module's URL (for import resolution and error reporting)
///
/// Returns:
///   - Opaque pointer to the compiled module on success
///   - null if compilation or evaluation failed
///   - Error on critical failures
pub fn evaluateModule(
    instance: *runtime.Instance,
    source: []const u8,
    url: []const u8,
) !?*anyopaque {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    const ctx = instance.ctx;

    // Get the engine interface
    const engine = ctx.getEngine() orelse return error.ModuleLoadError;
    const engine_ctx = ctx.getEngineContext() orelse return error.ModuleLoadError;

    // Check if module is already loaded
    if (internal.isModuleLoaded(url)) {
        // Return existing module record
        if (internal.loaded_modules.get(url)) |loaded| {
            return loaded.module_record;
        }
        return null;
    }

    // Compile the module
    const compile_fn = engine.compileModule orelse return error.NotImplemented;
    const module = compile_fn(engine_ctx, source, url) catch |err| {
        internal.markModuleFailed(url);
        return err;
    };

    if (module == null) {
        internal.markModuleFailed(url);
        return null;
    }

    // Check for top-level await
    const has_tla_fn = engine.hasTopLevelAwait orelse {
        // No TLA check available, run synchronously
        const run_fn = engine.runModule orelse return error.NotImplemented;
        run_fn(engine_ctx, module.?) catch |err| {
            internal.markModuleFailed(url);
            return err;
        };
        try internal.registerModule(url, module);
        return module;
    };

    const has_tla = has_tla_fn(module.?);

    if (has_tla) {
        // Module has top-level await - run asynchronously
        const run_async_fn = engine.runModuleAsync orelse {
            // Fall back to sync if async not available
            const run_fn = engine.runModule orelse return error.NotImplemented;
            run_fn(engine_ctx, module.?) catch |err| {
                internal.markModuleFailed(url);
                return err;
            };
            try internal.registerModule(url, module);
            return module;
        };

        // Run async - the promise will resolve when module evaluation completes
        _ = run_async_fn(engine_ctx, module.?) catch |err| {
            internal.markModuleFailed(url);
            return err;
        };
    } else {
        // No TLA - run synchronously
        const run_fn = engine.runModule orelse return error.NotImplemented;
        run_fn(engine_ctx, module.?) catch |err| {
            internal.markModuleFailed(url);
            return err;
        };
    }

    // Register the module as loaded
    try internal.registerModule(url, module);
    return module;
}

/// Evaluate multiple modules in order
///
/// This evaluates a list of modules in the order they were added.
/// Each module is compiled and evaluated before moving to the next.
///
/// Arguments:
///   - instance: The WorkletGlobalScope instance
///   - modules: List of (url, source) pairs to evaluate
///
/// Returns:
///   - Number of modules successfully evaluated
///   - Error on critical failures
pub fn evaluateModules(
    instance: *runtime.Instance,
    modules: []const struct { url: []const u8, source: []const u8 },
) !usize {
    var count: usize = 0;
    for (modules) |mod| {
        const result = try evaluateModule(instance, mod.source, mod.url);
        if (result != null) {
            count += 1;
        }
    }
    return count;
}
