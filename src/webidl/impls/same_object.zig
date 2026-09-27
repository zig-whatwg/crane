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
//! `visitChildren`. Crane has no tracing, so the owner holds the child's
//! wrapper strongly instead (`engine.retainValue`): taken when the child is
//! first handed out, released in the owner's deinit. The owner's own wrapper
//! stays weak, so a dead owner still lets its child go.
//!
//! Use this only for a child that does not point back into its owner. A
//! `Headers` object's list lives INSIDE its Request or Response, so there the
//! dependency runs the other way - see `impls/Headers.zig`.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

/// A strong reference to one Instance's JavaScript wrapper.
pub const Pin = struct {
    held: ?engine.Owned = null,

    /// Hold `instance`'s wrapper strongly, creating the wrapper - in the
    /// instance's relevant realm - if JavaScript has not seen `instance` yet.
    /// A later wrap of the same Instance (the binding layer, converting this
    /// getter's return value) is a cache hit and returns this same object.
    ///
    /// Idempotent. Silently holds nothing when the realm has no engine to
    /// wrap in - which is also a world with no garbage collector to guard
    /// against.
    pub fn hold(self: *Pin, instance: *runtime.Instance) void {
        if (self.held != null) return;
        self.held = engine.retainValue(instance.ctx, .{ .instance = instance }) catch return;
    }

    pub fn isHeld(self: *const Pin) bool {
        return self.held != null;
    }

    /// Let the wrapper go. Its lifetime is the wrapper cache's again.
    pub fn release(self: *Pin) void {
        if (self.held) |held| held.release();
        self.held = null;
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
