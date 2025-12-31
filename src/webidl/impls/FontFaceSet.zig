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
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

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
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
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
/// Per CSS Font Loading spec §4.3, this should return a Promise<FontFaceSet>.
///
/// For WPT infrastructure tests, this Promise resolves immediately since we
/// don't actually load fonts - there's nothing to wait for.
pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // Get the engine interface and context for Promise creation
    const engine = instance.ctx.engine orelse {
        // No engine available - return undefined as fallback
        return runtime.JSValue.jsUndefined;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return runtime.JSValue.jsUndefined;
    };

    // Create a Promise through the engine abstraction
    const allocator = instance.ctx.allocator;
    const promise_handle = engine.createPromise(engine_ctx, allocator) catch {
        return runtime.JSValue.jsUndefined;
    };

    // Resolve the promise immediately with the FontFaceSet instance (wrapped)
    // Per spec, fonts.ready resolves with the FontFaceSet when all fonts loaded.
    // Since we have no fonts to load, it resolves immediately.
    // Use wrapInstance to get the JS wrapper, or resolve with null (undefined) if unavailable
    const resolve_value: ?*const anyopaque = if (engine.wrapInstance) |wrap_fn| blk: {
        const wrapped = wrap_fn(engine_ctx, instance) catch null;
        break :blk if (wrapped) |w| @ptrCast(w) else null;
    } else null;

    engine.resolvePromise(engine_ctx, promise_handle, resolve_value) catch {
        // If resolve fails, still return the promise (it will be pending forever)
    };

    // Get the JS Promise object
    const promise_ptr = engine.getPromiseObject(promise_handle);

    // Clean up the handle (Promise object is still valid, managed by GC)
    if (engine.destroyPromiseHandle) |destroy_fn| {
        destroy_fn(promise_handle, allocator);
    }

    return runtime.JSValue.fromPromise(promise_ptr);
}

/// Getter for status
/// Returns the loading status of the FontFaceSet.
/// Stub: Returns "loaded" since we don't actually load fonts.
/// Per CSS Font Loading spec §4.3, this is either "loading" or "loaded".
pub fn get_status(instance: *runtime.Instance) anyerror!enums.FontFaceSetLoadStatus {
    _ = instance;
    // Stub: Return "loaded" since we have no fonts to load
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
