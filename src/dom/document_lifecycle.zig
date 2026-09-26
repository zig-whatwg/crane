//! A document's lifecycle (HTML §7.5, §13.2.7) as seen from outside Document:
//! "the end" for a document whose parser finishes outside Document - the
//! top-level document's (impls/HTMLParser) and a frame's (html/scripted_parser)
//! - and the steps navigation takes on the document it is leaving: firing
//! beforeunload, unloading it, and asking whether it is still loading.
//!
//! A document's readiness, page showing flag, unload counter, salvageable
//! state and visibility state are Document's state, and no IDL member reaches
//! them, so Document installs this hook and the parsers and navigation ask it.
//! The shape of `navigable_container.zig`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-end
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#unloading-documents
//!
//! lint-impls: hook for Document

const runtime = @import("runtime");

/// What Document supplies.
pub const Implementation = struct {
    parsing_stopped: *const fn (document: *runtime.Instance) void,
    finish_loading: *const fn (document: *runtime.Instance) void,
    load_delay_may_have_ended: *const fn (document: *runtime.Instance) void,
    is_completely_loaded: *const fn (document: *runtime.Instance) bool,
    is_initial_about_blank: *const fn (document: *runtime.Instance) bool,
    mark_initial_about_blank: *const fn (document: *runtime.Instance) void,
    is_unloading: *const fn (document: *runtime.Instance) bool,
    fire_beforeunload: *const fn (document: *runtime.Instance) BeforeUnloadResult,
    unload: *const fn (document: *runtime.Instance) void,
};

/// The "steps to fire beforeunload" result that navigation reads: whether the
/// user was asked, and whether they cancelled.
pub const BeforeUnloadResult = struct {
    prompt_shown: bool = false,
    canceled: bool = false,
};

threadlocal var implementation: ?Implementation = null;

/// Called by Document. Idempotent: every call installs the same functions.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// "The end" step 3: the parser has stopped, and readiness becomes
/// "interactive" - before the deferred scripts, which see it.
pub fn parsingStopped(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.parsing_stopped(document);
}

/// "The end" steps 6-9, as the tasks they are: DOMContentLoaded; then, once
/// nothing delays the load event (step 8), readiness "complete", load at the
/// window, pageshow, and "completely finish loading", which fires load at the
/// document's container.
pub fn finishLoading(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.finish_loading(document);
}

/// Something that delayed `document`'s load event may have stopped: if "the
/// end" is waiting at step 8 and nothing delays it now, it goes on.
pub fn loadDelayMayHaveEnded(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.load_delay_may_have_ended(document);
}

/// Whether `document` is "completely loaded": "completely finish loading" has
/// run for it.
pub fn isCompletelyLoaded(document: *runtime.Instance) bool {
    const impl = implementation orelse return true;
    return impl.is_completely_loaded(document);
}

/// A document's "is initial about:blank".
pub fn isInitialAboutBlank(document: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.is_initial_about_blank(document);
}

/// "Create a new browsing context and document" step 15's document is the
/// initial about:blank one: its creator says so.
pub fn markInitialAboutBlank(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.mark_initial_about_blank(document);
}

/// Whether `document`'s unload counter is above zero - it is firing
/// beforeunload, pagehide or unload - which "navigate" step 9 refuses.
pub fn isUnloading(document: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.is_unloading(document);
}

/// The "steps to fire beforeunload" given `document`.
pub fn fireBeforeUnload(document: *runtime.Instance) BeforeUnloadResult {
    const impl = implementation orelse return .{};
    return impl.fire_beforeunload(document);
}

/// "Unload" `document`: pagehide, visibilitychange and unload, with its
/// unload counter raised throughout.
pub fn unload(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.unload(document);
}

test "without an installed implementation nothing is asked of a document" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var document: runtime.Instance = undefined;
    parsingStopped(&document);
    finishLoading(&document);
    loadDelayMayHaveEnded(&document);
    markInitialAboutBlank(&document);
    unload(&document);
    // The answers that let a caller go on: a document nobody can ask about
    // is loaded, is no initial about:blank, is not unloading, and nobody
    // cancels leaving it.
    try std.testing.expect(isCompletelyLoaded(&document));
    try std.testing.expect(!isInitialAboutBlank(&document));
    try std.testing.expect(!isUnloading(&document));
    try std.testing.expect(!fireBeforeUnload(&document).canceled);
}
