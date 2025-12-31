//! Implementation for FontFaceSet interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const FontFaceSet = interfaces.FontFaceSet;

pub const State = FontFaceSet.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Per CSS Font Loading spec §4.3, FontFaceSet has:
/// - [[ReadyPromise]]: Cached promise returned by .ready getter
/// - [[LoadingFonts]], [[LoadedFonts]], [[FailedFonts]]: Font tracking sets
pub const InternalState = struct {
    /// [[ReadyPromise]] slot - cached promise for .ready getter
    /// Per spec, same promise must be returned on repeated access
    ready_promise_ptr: ?*anyopaque = null,

    /// Current loading status
    status: enums.FontFaceSetLoadStatus = ._loaded_,

    pub fn deinit(self: *InternalState) void {
        // Promise is GC-managed, just clear our reference
        self.ready_promise_ptr = null;
    }
};

/// Registry to store internal state per instance
var internal_registry: ?std.AutoHashMap(*runtime.Instance, *InternalState) = null;

fn getRegistry(allocator: std.mem.Allocator) *std.AutoHashMap(*runtime.Instance, *InternalState) {
    if (internal_registry == null) {
        internal_registry = std.AutoHashMap(*runtime.Instance, *InternalState).init(allocator);
    }
    return &internal_registry.?;
}

fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const registry = getRegistry(instance.ctx.allocator);
    return registry.get(instance);
}

fn getOrCreateInternalState(instance: *runtime.Instance) !*InternalState {
    const allocator = instance.ctx.allocator;
    const registry = getRegistry(allocator);

    if (registry.get(instance)) |state| {
        return state;
    }

    const state = try allocator.create(InternalState);
    state.* = .{};
    try registry.put(instance, state);
    return state;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state
    const allocator = instance.ctx.allocator;
    if (internal_registry) |*registry| {
        if (registry.fetchRemove(instance)) |kv| {
            kv.value.deinit();
            allocator.destroy(kv.value);
        }
    }
}

/// Getter for onloading
pub fn get_onloading(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onloadingdone
pub fn get_onloadingdone(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onloadingerror
pub fn get_onloadingerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ready
/// Returns a Promise that resolves when the FontFaceSet is done loading fonts.
/// Per CSS Font Loading spec §4.3:
/// - Returns Promise<FontFaceSet> stored in [[ReadyPromise]] slot
/// - Same promise must be returned on repeated access
/// - Promise resolves with FontFaceSet when status becomes "loaded"
pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // Get the engine interface and context for Promise creation
    const engine = instance.ctx.engine orelse {
        // No engine available - this is an error condition
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Get or create internal state for [[ReadyPromise]] slot
    const internal = try getOrCreateInternalState(instance);

    // Per spec: return same promise on repeated access
    if (internal.ready_promise_ptr) |cached_ptr| {
        return runtime.JSValue.fromPromise(cached_ptr);
    }

    // Create a new Promise for [[ReadyPromise]] slot
    const allocator = instance.ctx.allocator;
    const promise_handle = try engine.createPromise(engine_ctx, allocator);

    // Get the Promise object pointer before resolving (we need to cache it)
    const promise_ptr = engine.getPromiseObject(promise_handle);

    // Cache the promise in [[ReadyPromise]] slot for future accesses
    internal.ready_promise_ptr = promise_ptr;

    // Resolve the promise with the FontFaceSet instance (wrapped as JS object)
    // Per spec: resolves with FontFaceSet when all fonts loaded
    // Since status is "loaded" (no fonts to load), resolve immediately
    const resolve_value: ?*const anyopaque = if (engine.wrapInstance) |wrap_fn| blk: {
        const wrapped = wrap_fn(engine_ctx, instance) catch |err| {
            // If wrapping fails, reject the promise
            engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
            if (engine.destroyPromiseHandle) |destroy_fn| {
                destroy_fn(promise_handle, allocator);
            }
            return err;
        };
        break :blk @ptrCast(wrapped);
    } else null;

    // Resolve with the wrapped FontFaceSet instance
    try engine.resolvePromise(engine_ctx, promise_handle, resolve_value);

    // Clean up the handle (Promise object is GC-managed)
    if (engine.destroyPromiseHandle) |destroy_fn| {
        destroy_fn(promise_handle, allocator);
    }

    return runtime.JSValue.fromPromise(promise_ptr);
}

/// Getter for status
/// Returns the loading status of the FontFaceSet.
/// Per CSS Font Loading spec §4.3, this is either "loading" or "loaded".
pub fn get_status(instance: *runtime.Instance) anyerror!enums.FontFaceSetLoadStatus {
    if (getInternalState(instance)) |internal| {
        return internal.status;
    }
    // Default to "loaded" if no internal state (no fonts to load)
    return ._loaded_;
}

/// Setter for onloading
pub fn set_onloading(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onloadingdone
pub fn set_onloadingdone(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onloadingerror
pub fn set_onloadingerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance, font: *runtime.Instance) anyerror!bool {
    _ = instance;
    _ = font;
    return error.NotImplemented;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, font: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    _ = font;
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: load
pub fn call_load(instance: *runtime.Instance, font: typedefs.CSSOMString, text: webidl.Opt(typedefs.CSSOMString)) anyerror!runtime.JSValue {
    _ = instance;
    _ = font;
    _ = text;
    return error.NotImplemented;
}

/// Operation: check
pub fn call_check(instance: *runtime.Instance, font: typedefs.CSSOMString, text: webidl.Opt(typedefs.CSSOMString)) anyerror!bool {
    _ = instance;
    _ = font;
    _ = text;
    return error.NotImplemented;
}
