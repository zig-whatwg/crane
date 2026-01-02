//! Implementation for Worklet interface
//! Implements the Worklet API per HTML spec section 10.3
//! https://html.spec.whatwg.org/multipage/worklets.html

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const html_core = @import("html_core");
const script_fetch = html_core.workers.script_fetch;
const Worklet = interfaces.Worklet;
const WorkletGlobalScopeImpl = @import("WorkletGlobalScope.zig");

pub const State = Worklet.State;

pub const ImplError = error{
    NotImplemented,
    InvalidURL,
    NetworkError,
    ModuleParseError,
    SecurityError,
    OutOfMemory,
};

/// Worklet type determines which global scope type to create
/// Re-export from WorkletGlobalScope for consistent type usage
pub const WorkletType = WorkletGlobalScopeImpl.WorkletType;

/// Module record for tracking loaded modules
pub const ModuleRecord = struct {
    url: []const u8,
    source: ?[]const u8, // null when pending, set after fetch
    status: ModuleStatus,

    pub const ModuleStatus = enum {
        pending,
        loaded,
        failed,
    };
};

/// Internal state for Worklet implementation
pub const InternalState = struct {
    /// The type of worklet (determines global scope type)
    worklet_type: WorkletType,

    /// Allocator for this worklet's resources
    allocator: std.mem.Allocator,

    /// List of worklet global scopes (can have multiple for parallelism)
    global_scopes: std.ArrayList(*runtime.Instance),

    /// Module map - URLs to module records
    module_map: std.StringHashMap(ModuleRecord),

    /// Added module URLs in order
    added_module_urls: std.ArrayList([]const u8),

    /// Document's base URL for resolving relative URLs
    document_base_url: ?[]const u8,

    /// Whether this worklet is associated with a secure context
    is_secure_context: bool,

    /// Pending scope states (created before V8 contexts are ready)
    pending_scope_states: std.ArrayList(*WorkletGlobalScopeImpl.InternalState),

    pub fn init(allocator: std.mem.Allocator, worklet_type: WorkletType) !*InternalState {
        const state = try allocator.create(InternalState);
        state.* = .{
            .worklet_type = worklet_type,
            .allocator = allocator,
            .global_scopes = .{},
            .module_map = std.StringHashMap(ModuleRecord).init(allocator),
            .added_module_urls = .{},
            .document_base_url = null,
            .is_secure_context = true, // Worklets require secure context
            .pending_scope_states = .{},
        };
        return state;
    }

    pub fn deinit(self: *InternalState) void {
        // Clean up global scopes
        for (self.global_scopes.items) |scope| {
            scope.deinit();
        }
        self.global_scopes.deinit(self.allocator);

        // Clean up pending scope states
        for (self.pending_scope_states.items) |scope_state| {
            scope_state.deinit();
        }
        self.pending_scope_states.deinit(self.allocator);

        // Clean up module URLs
        for (self.added_module_urls.items) |url| {
            self.allocator.free(url);
        }
        self.added_module_urls.deinit(self.allocator);

        // Clean up module map
        var iter = self.module_map.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.module_map.deinit();

        if (self.document_base_url) |base_url| {
            self.allocator.free(base_url);
        }

        self.allocator.destroy(self);
    }

    /// Create internal state for a new worklet global scope
    /// Note: The actual V8 context creation happens later when modules are evaluated
    pub fn createGlobalScopeState(self: *InternalState) !*WorkletGlobalScopeImpl.InternalState {
        // Get origin from document base URL or use a default secure origin
        const origin = self.document_base_url orelse "https://localhost";
        const scope_state = try WorkletGlobalScopeImpl.createInternalStateForWorklet(
            self.allocator,
            self.worklet_type,
            origin,
        );
        // Store the state for later use when V8 context is created
        // Note: global_scopes will store actual instances once V8 contexts are ready
        return scope_state;
    }

    /// Check if a module URL has already been added
    pub fn hasModule(self: *InternalState, url: []const u8) bool {
        return self.module_map.contains(url);
    }

    /// Add a module URL to the worklet
    pub fn addModule(self: *InternalState, url: []const u8, source: ?[]const u8) !void {
        if (self.hasModule(url)) return;

        const url_copy = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(url_copy);

        // Dupe source if provided
        const source_copy: ?[]const u8 = if (source) |s| try self.allocator.dupe(u8, s) else null;
        errdefer if (source_copy) |s| self.allocator.free(s);

        try self.module_map.put(url_copy, .{
            .url = url_copy,
            .source = source_copy,
            .status = if (source != null) .loaded else .pending,
        });
        try self.added_module_urls.append(self.allocator, url_copy);
    }

    /// Mark a module as loaded
    pub fn markModuleLoaded(self: *InternalState, url: []const u8) void {
        if (self.module_map.getPtr(url)) |record| {
            record.status = .loaded;
        }
    }

    /// Mark a module as failed
    pub fn markModuleFailed(self: *InternalState, url: []const u8) void {
        if (self.module_map.getPtr(url)) |record| {
            record.status = .failed;
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
    return instance;
}

/// Initialize with specific worklet type
pub fn initWithType(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    worklet_type: WorkletType,
) !*runtime.Instance {
    const instance = try interfaces.Worklet.init(allocator, ctx);
    errdefer instance.deinit();

    const internal = try InternalState.init(allocator, worklet_type);

    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        state.own._internal = null;
    }
}

/// Helper to get internal state
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Operation: addModule
/// Per spec: https://html.spec.whatwg.org/multipage/worklets.html#dom-worklet-addmodule
///
/// The addModule(moduleURL, options) method steps are:
/// 1. Let outsideSettings be the relevant settings object of this.
/// 2. Let moduleURLRecord be the result of encoding-parsing a URL given moduleURL,
///    relative to outsideSettings.
/// 3. If moduleURLRecord is failure, then return a promise rejected with a
///    "SyntaxError" DOMException.
/// 4. Return the result of fetching a worklet script graph given moduleURLRecord,
///    outsideSettings, this's global scopes, and options.
pub fn call_addModule(
    instance: *runtime.Instance,
    moduleURL: runtime.USVString,
    options: webidl.Opt(dictionaries.WorkletOptions),
) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse {
        // Worklet not properly initialized - create default internal state
        const allocator = instance.ctx.getAllocator();
        const new_internal = try InternalState.init(allocator, .audio);
        const state = instance.getState(State);
        state.own._internal = new_internal;
        return call_addModule(instance, moduleURL, options);
    };

    // Get the module URL as a string
    const url_slice = moduleURL;

    // Validate URL is not empty
    if (url_slice.len == 0) {
        return error.SyntaxError;
    }

    // Check if module already loaded
    if (internal.hasModule(url_slice)) {
        // Return resolved promise - module already added
        const ctx = instance.ctx;
        const engine = ctx.getEngine() orelse {
            return runtime.JSValue{ .undefined = {} };
        };
        const engine_ctx = ctx.engine_ctx orelse {
            return runtime.JSValue{ .undefined = {} };
        };

        const promise_handle = engine.createPromise(engine_ctx, internal.allocator) catch {
            return runtime.JSValue{ .undefined = {} };
        };
        engine.resolvePromise(engine_ctx, promise_handle, null) catch {};
        const promise_obj = engine.getPromiseObject(promise_handle);
        // Don't destroy handle yet - the promise object needs it
        return runtime.JSValue{
            .handle = .{
                .ptr = promise_obj,
                .needs_disposal = false, // Engine manages promise lifecycle
            },
        };
    }

    // Add module to tracking (source will be set after fetching)
    try internal.addModule(url_slice, null);

    // Create internal state for a global scope if we don't have one yet
    // Note: The actual V8 context creation happens when modules are evaluated
    if (internal.pending_scope_states.items.len == 0) {
        const scope_state = try internal.createGlobalScopeState();
        try internal.pending_scope_states.append(internal.allocator, scope_state);
    }

    // Get credentials mode from options
    const credentials = if (options.was_passed)
        options.value.credentials orelse ._same_origin_
    else
        ._same_origin_;

    // Convert WebIDL credentials enum to script_fetch credentials
    const fetch_credentials: script_fetch.WorkerScriptFetchOptions.CredentialsMode = switch (credentials) {
        ._omit_ => .omit,
        ._same_origin_ => .same_origin,
        ._include_ => .include,
    };

    // Fetch the module script per spec step 4:
    // "Fetch a worklet script given moduleURLRecord, credentials, outsideSettings,
    // workletGlobalScope, and moduleResponsesMap"
    var fetched_script = script_fetch.fetchWorkerScript(internal.allocator, url_slice, .{
        .credentials = fetch_credentials,
        .csp_list = null, // TODO: Get CSP from document
    }) catch |err| {
        // Fetch failed - return error
        std.log.warn("Worklet.addModule: Failed to fetch {s}: {}", .{ url_slice, err });
        return error.NetworkError;
    };
    defer fetched_script.deinit();

    // Store the fetched source in module_map for later evaluation
    // The actual V8 module evaluation will happen when the worklet context is used
    const url_copy = internal.allocator.dupe(u8, url_slice) catch return error.OutOfMemory;
    errdefer internal.allocator.free(url_copy);

    const source_copy = internal.allocator.dupe(u8, fetched_script.source) catch {
        internal.allocator.free(url_copy);
        return error.OutOfMemory;
    };

    internal.module_map.put(url_copy, ModuleRecord{
        .url = url_copy,
        .source = source_copy,
        .status = .loaded,
    }) catch {
        internal.allocator.free(url_copy);
        internal.allocator.free(source_copy);
        return error.OutOfMemory;
    };

    // Mark module as pending in each worklet global scope
    for (internal.pending_scope_states.items) |scope_state| {
        scope_state.markModulePending(url_slice) catch |err| {
            std.log.warn("Worklet.addModule: Failed to mark module pending in scope: {}", .{err});
            // Continue with other scopes even if one fails
        };
    }

    // Create and return a resolved Promise per spec
    // The addModule method returns a Promise that resolves with undefined on success
    const ctx = instance.ctx;
    const engine = ctx.getEngine() orelse {
        // No engine available - return undefined as fallback
        return runtime.JSValue{ .undefined = {} };
    };
    const engine_ctx = ctx.engine_ctx orelse {
        return runtime.JSValue{ .undefined = {} };
    };

    // Create the Promise
    const promise_handle = engine.createPromise(engine_ctx, internal.allocator) catch {
        // Promise creation failed - return undefined as fallback
        return runtime.JSValue{ .undefined = {} };
    };

    // Resolve with undefined (success)
    engine.resolvePromise(engine_ctx, promise_handle, null) catch {
        // Resolution failed - still return the promise
    };

    // Get the Promise object to return
    const promise_obj = engine.getPromiseObject(promise_handle);

    // Don't destroy handle yet - the promise object needs it
    return runtime.JSValue{
        .handle = .{
            .ptr = promise_obj,
            .needs_disposal = false, // Engine manages promise lifecycle
        },
    };
}

// Tests
test "Worklet InternalState lifecycle" {
    const allocator = std.testing.allocator;

    const internal = try InternalState.init(allocator, .audio);
    defer internal.deinit();

    try std.testing.expectEqual(WorkletType.audio, internal.worklet_type);
    try std.testing.expectEqual(@as(usize, 0), internal.global_scopes.items.len);
    try std.testing.expectEqual(@as(usize, 0), internal.added_module_urls.items.len);
}

test "Worklet module tracking" {
    const allocator = std.testing.allocator;

    const internal = try InternalState.init(allocator, .paint);
    defer internal.deinit();

    // Add a module
    try internal.addModule("https://example.com/worklet.js");
    try std.testing.expect(internal.hasModule("https://example.com/worklet.js"));
    try std.testing.expect(!internal.hasModule("https://example.com/other.js"));

    // Adding same module again should be no-op
    try internal.addModule("https://example.com/worklet.js");
    try std.testing.expectEqual(@as(usize, 1), internal.added_module_urls.items.len);

    // Mark as loaded
    internal.markModuleLoaded("https://example.com/worklet.js");
    const record = internal.module_map.get("https://example.com/worklet.js").?;
    try std.testing.expectEqual(ModuleRecord.ModuleStatus.loaded, record.status);
}
