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

/// An object an owner makes once, keeps in its own state and hands out as the
/// same object for its whole life: a document's getSelection() Selection,
/// document.all, document.fonts and document.styleSheets (Document.zig), and
/// an element's shadow root (Element.zig).
///
/// Kept as a bare pointer, such a child dangles as soon as script drops it.
/// Its wrapper is weak, so a collection frees the instance
/// (wrapper_cache.weakCallback -> gc.onObjectFreed) while the owner still
/// points at it, and the next read wraps whatever took the slot:
/// Range-mutations.js runs `getSelection().removeAllRanges()` in every "with
/// selected" subtest and got "removeAllRanges is not a function", or
/// undefined, from wherever the collector happened to run; a host whose
/// shadow root's wrapper was collected answered `host.shadowRoot` from a freed
/// slot (scoped-registry-effective-global-registry.html, a safety panic in
/// ShadowRoot.get_mode). The owner's teardown then deinit'd that slot,
/// whoever owned it by then.
///
/// Blink traces each of them from the owner (TreeScope::Trace visits
/// selection_ and style_sheet_list_; ElementRareData traces the shadow root).
/// Crane has no tracing, so the owner holds the child's wrapper strongly from
/// the first hand-out (`Pin`) until the owner goes, as AbortController does
/// for its signal.
///
/// A child that points back at its owner (a shadow root's host) is safe here
/// only because `release`'s `sever` step makes it stop: for a shadow root,
/// dom.shadow_hosts tells it its host is gone.
pub const KeptChild = struct {
    pin: Pin = .{},
    /// The child as it was when its owner made it.
    link: ?Link = null,

    /// `child` was just made and stored in the owner's state.
    pub fn made(self: *KeptChild, child: *runtime.Instance) void {
        self.link = Link.to(child);
    }

    /// `child` is going to script: keep its wrapper for as long as the owner
    /// lives. Idempotent.
    pub fn handOut(self: *KeptChild, child: *runtime.Instance) void {
        self.pin.hold(child);
    }

    /// The owner is going. `child`, if it is still the object the owner made,
    /// is severed from it (`sever`: its interface's deinit, which releases its
    /// state, so script that still holds it gets InvalidStateError, not an
    /// owner that is gone - or, for a shadow root, a step that only makes it
    /// forget its host). Then its wrapper is let go, and the wrapper cache
    /// frees the instance once script drops it too.
    pub fn release(self: *KeptChild, child: *runtime.Instance, sever: *const fn (*runtime.Instance) void) void {
        if (self.link) |link| if (link.isLive()) sever(child);
        self.pin.release();
        self.* = .{};
    }
};
