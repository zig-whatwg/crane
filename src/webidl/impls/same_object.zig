//! Keeping a [SameObject] child alive for as long as its owner.
//!
//! `xhr.upload`, `controller.signal` and `response.body` each hand out one
//! object for the owner's whole life, and script routinely stores state on it
//! and then drops it: `xhr.upload.onprogress = f` leaves nothing in JavaScript
//! holding the upload object. The generated getter caches the child as a bare
//! `*runtime.Instance`, which V8 cannot see - the child's wrapper is weak, so a
//! collection frees the Instance and the owner is left holding a pointer into
//! the slab. `xhr/send-timeout-events.htm` hit exactly that: a 1 MB string
//! forced a collection between setting `xhr.upload.onloadend` and `send()`,
//! and `send()` fired `upload.loadstart` into freed memory.
//!
//! Blink keeps such a child alive by TRACING it from its owner
//! (`XMLHttpRequest::Trace` visits `upload_`); WebKit does it in
//! `visitChildren`. Crane has no tracing, so the owner holds a strong Global to
//! the child's wrapper instead: taken when the child is first handed out,
//! released in the owner's deinit. The owner's own wrapper stays weak, so a
//! dead owner still lets its child go.
//!
//! Use this only for a child that does not point back into its owner. A
//! `Headers` object's list lives INSIDE its Request or Response, so there the
//! dependency runs the other way - see `impls/Headers.zig`.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");

/// A strong reference to one Instance's JavaScript wrapper.
pub const Pin = struct {
    handle: ?v8.GlobalHandle = null,

    /// Hold `instance`'s wrapper strongly, creating the wrapper if JavaScript
    /// has not seen `instance` yet.
    ///
    /// Idempotent. Silently holds nothing when there is no isolate or context
    /// to wrap in - which is also a world with no garbage collector to guard
    /// against.
    pub fn hold(self: *Pin, instance: *runtime.Instance) void {
        if (self.handle != null) return;

        const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return;
        const engine_ctx = instance.ctx.engine_ctx orelse return;
        const context: *v8.ffi.Context = @ptrCast(@alignCast(engine_ctx));

        const scope = v8.ffi.v8_HandleScope_New(isolate) orelse return;
        defer v8.ffi.v8_HandleScope_Dispose(scope);

        // The wrapper cache's own Global - borrowed, never ours to dispose. A
        // later wrap of the same Instance (the binding layer, converting this
        // getter's return value) is a cache hit and returns this same object.
        const name = v8.template_registry.getInstanceInterfaceName(instance);
        const wrapper = v8.template_registry.wrapInstanceAsV8Object(instance, name, isolate, context) catch return;

        // Our own strong Global to the same object: `v8_Global_Get` lends a
        // Local in the scope above, `GlobalHandle.create` allocates the Global
        // that `release` disposes.
        const local = v8.ffi.v8_Global_Get(isolate, @ptrCast(wrapper)) orelse return;
        self.handle = v8.GlobalHandle.create(isolate, local);
    }

    pub fn isHeld(self: *const Pin) bool {
        return self.handle != null;
    }

    /// Let the wrapper go. Its lifetime is the wrapper cache's again.
    pub fn release(self: *Pin) void {
        if (self.handle) |handle| handle.dispose();
        self.handle = null;
    }
};

/// A link to an Instance that may be freed without telling the holder.
///
/// The slab recycles addresses, so a pointer alone cannot say whether it still
/// names the object it was taken on. The slot's generation can: it is stamped
/// on every alloc and reads `dead_generation` after a free.
pub const Link = struct {
    instance: *runtime.Instance,
    generation: u64,

    pub fn to(instance: *runtime.Instance) Link {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    /// Is `instance` still the object this link was taken on?
    pub fn isLive(self: Link) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};
