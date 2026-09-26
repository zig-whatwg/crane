//! What a navigable container's content navigable owes its container
//! document: while it loads it delays the document's load event, and when it
//! finishes loading, the container runs its load event steps.
//!
//! HTML §4.8.5: an iframe "potentially delays the load event" of its node
//! document while its content navigable's active document is not ready for
//! post-load tasks or the navigable "is delaying load events"; and
//! "completely finish loading" ends with the iframe load event steps. The
//! navigable - its ongoing navigation, its load state - is the container's
//! state, and Document, whose "the end" waits on it, reaches it here. The
//! container installs this hook and Document asks it. The shape of
//! `navigable_container.zig`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html#potentially-delays-the-load-event
//!
//! lint-impls: hook for HTMLIFrameElement

const runtime = @import("runtime");

/// What the navigable containers supply.
pub const Implementation = struct {
    /// Whether any navigable container in `document` delays its load event.
    delays_load_event: *const fn (document: *runtime.Instance) bool,
    /// The container's load event steps ("iframe load event steps"), run as
    /// the last step of its content document's "completely finish loading".
    /// False when `container` is not one this implementation owns, and its
    /// caller fires the load event itself.
    run_load_event_steps: *const fn (container: *runtime.Instance) bool,
    /// HTML "stop loading" the navigable whose active document is
    /// `document`, if a container owns one: its ongoing navigation ends.
    stop_loading: *const fn (document: *runtime.Instance) void,
};

threadlocal var implementation: ?Implementation = null;

/// Called by the container. Idempotent: every call installs the same functions.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// "The end" step 8: whether anything a navigable container owns still
/// delays `document`'s load event.
pub fn delaysLoadEvent(document: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.delays_load_event(document);
}

/// "Completely finish loading" step 4's task: the load event steps of
/// `container`. False when no installed container owns it.
pub fn runLoadEventSteps(container: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.run_load_event_steps(container);
}

/// HTML "stop loading" `document`'s node navigable - the document open
/// steps' step 8 - when a navigable container holds it.
pub fn stopLoading(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.stop_loading(document);
}

test "without an installed implementation nothing delays a load event" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var document: runtime.Instance = undefined;
    try @import("std").testing.expect(!delaysLoadEvent(&document));
    try @import("std").testing.expect(!runLoadEventSteps(&document));
    stopLoading(&document);
}
