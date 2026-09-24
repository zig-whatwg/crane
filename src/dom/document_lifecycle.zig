//! HTML "the end" (§13.2.7) for a document whose parser finishes outside
//! Document: the top-level document's (impls/HTMLParser) and a frame's
//! (html/scripted_parser).
//!
//! A document's readiness and the tasks that finish loading it are Document's
//! state, and no IDL member reaches them, so Document installs this hook and
//! the parsers ask it. The shape of `navigable_container.zig`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-end
//!
//! lint-impls: hook for Document

const runtime = @import("runtime");

/// What Document supplies.
pub const Implementation = struct {
    parsing_stopped: *const fn (document: *runtime.Instance) void,
    finish_loading: *const fn (document: *runtime.Instance) void,
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

/// "The end" steps 6 and 9, as the tasks they are: DOMContentLoaded; then
/// readiness "complete", load at the window, pageshow, and "completely finish
/// loading", which fires load at the document's container.
pub fn finishLoading(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.finish_loading(document);
}

test "without an installed implementation nothing is asked of a document" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var document: runtime.Instance = undefined;
    parsingStopped(&document);
    finishLoading(&document);
}
