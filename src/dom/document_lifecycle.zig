//! A document's lifecycle (HTML §7.5, §13.2.7) as seen from outside Document:
//! Active parser ownership and "the end" for navigation and written input,
//! and the steps navigation takes on the document it is leaving: firing
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
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// What Document supplies.
pub const Implementation = struct {
    /// Rendering is a document lifecycle operation; share its installed table.
    rendering: @import("document_rendering.zig").Implementation,
    /// Only Document casts these parser pointers to the HTML owner type.
    associate_parser: *const fn (document: *runtime.Instance, parser: *anyopaque) bool,
    discard_parser: *const fn (document: *runtime.Instance, expected: ?*anyopaque) void,
    parser_finished: *const fn (document: *runtime.Instance, parser: *anyopaque) void,
    finish_without_parser: *const fn (document: *runtime.Instance) void,
    parsing_stopped: *const fn (document: *runtime.Instance) void,
    finish_loading: *const fn (document: *runtime.Instance) void,
    load_delay_may_have_ended: *const fn (document: *runtime.Instance) void,
    script_delivery_discarded: *const fn (document: *runtime.Instance, removed_parser_blocker: bool) void,
    delays_load_event: *const fn (document: *runtime.Instance) bool,
    is_ready_for_post_load_tasks: *const fn (document: *runtime.Instance) bool,
    mark_ready_for_post_load_tasks: *const fn (document: *runtime.Instance) void,
    is_completely_loaded: *const fn (document: *runtime.Instance) bool,
    is_initial_about_blank: *const fn (document: *runtime.Instance) bool,
    mark_initial_about_blank: *const fn (document: *runtime.Instance) void,
    is_unloading: *const fn (document: *runtime.Instance) bool,
    fire_beforeunload: *const fn (document: *runtime.Instance) BeforeUnloadResult,
    unload: *const fn (document: *runtime.Instance) void,
    abort: *const fn (document: *runtime.Instance) void,
    /// Navigation's provisional abort, before the replacement commits.
    abort_for_navigation: *const fn (document: *runtime.Instance) void,
    /// Abort a document and its descendants, step 3.2: propagate the
    /// descendant's unsalvageable state to the root after its abort task.
    propagate_abort: *const fn (parent: *runtime.Instance, child: *runtime.Instance) void,
    destroy: *const fn (document: *runtime.Instance) void,
    set_about_base_url: *const fn (document: *runtime.Instance, url: ?[]const u8) void,
    about_fallback_base_url: *const fn (document: *runtime.Instance) ?[]const u8,
    declarative_refresh: *const fn (document: *runtime.Instance, input: []const u8, meta: ?*runtime.Instance) void,
    set_iframe_load_in_progress: *const fn (document: *runtime.Instance, in_progress: bool) void,
    is_iframe_load_muted: *const fn (document: *runtime.Instance) bool,
    delay_load_event: *const fn (document: *runtime.Instance) void,
    undelay_load_event: *const fn (document: *runtime.Instance) void,
};

/// The "steps to fire beforeunload" result that navigation reads: whether the
/// user was asked, and whether they cancelled.
pub const BeforeUnloadResult = struct {
    prompt_shown: bool = false,
    canceled: bool = false,
    /// A handler asked for the prompt - cancelled the event or set its
    /// returnValue - which is shown only with sticky activation.
    prompt_requested: bool = false,
};

var implementation: ?Implementation = null;

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// The rendering seam shares this process-start table without mutable state
/// of its own; all returned state still belongs to the queried Document.
pub fn renderingImplementation() ?@import("document_rendering.zig").Implementation {
    const impl = implementation orelse return null;
    return impl.rendering;
}

/// Document acquires a parser reference independently of the initiating
/// caller's reference, which stays alive through every parsing callback.
pub fn associateParser(document: *runtime.Instance, parser: *anyopaque) bool {
    const impl = implementation orelse return false;
    return impl.associate_parser(document, parser);
}

/// Cancel the current parser, or only `expected` when supplied. This never
/// runs normal EOF or loading completion, and cannot discard a replacement.
pub fn discardParser(document: *runtime.Instance, expected: ?*anyopaque) void {
    const impl = implementation orelse return;
    impl.discard_parser(document, expected);
}

/// Actual EOF, once, with a pump reference held. Document detaches before
/// running its guarded readiness and deferred script steps.
pub fn parserFinished(document: *runtime.Instance, parser: *anyopaque) void {
    const impl = implementation orelse return;
    impl.parser_finished(document, parser);
}

/// Finish a received document for which navigation has no parser. This
/// uses the same guarded "the end" steps, and cannot finish an active parser.
pub fn finishWithoutParser(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.finish_without_parser(document);
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

/// A delivery owner relinquished its preparation and load delay. Recheck
/// the surviving document on a later task, including a parser whose blocker
/// was removed. Task.drop may call this during allocation failure: this
/// never runs script or lifecycle events synchronously, even without a loop.
pub fn scriptDeliveryDiscarded(document: *runtime.Instance, removed_parser_blocker: bool) void {
    const impl = implementation orelse return;
    impl.script_delivery_discarded(document, removed_parser_blocker);
}

/// Whether anything delays this document's load event ("the end", step 8).
/// A container asks this about its active document even when that document
/// was opened after it became ready for post-load tasks.
pub fn delaysLoadEvent(document: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.delays_load_event(document);
}

/// HTML "ready for post-load tasks", independent of current readiness and
/// completely-loaded time. Document.open does not reset this state.
pub fn isReadyForPostLoadTasks(document: *runtime.Instance) bool {
    const impl = implementation orelse return true;
    return impl.is_ready_for_post_load_tasks(document);
}

/// DOMImplementation-created documents are ready immediately (HTML §3.1).
pub fn markReadyForPostLoadTasks(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.mark_ready_for_post_load_tasks(document);
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

/// HTML "abort" `document` (§7.5.6): a parser still running - a navigation
/// of its navigable began while the page was loading - is aborted, and the
/// document never fires DOMContentLoaded or load (or load at its container)
/// and is no longer salvageable.
pub fn abort(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.abort(document);
}

/// Navigation's abort uses the same parser steps, while fetch owners can
/// distinguish provisional loading from an explicit stop/document.open.
pub fn abortForNavigation(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.abort_for_navigation(document);
}

/// HTML "abort a document and its descendants" step 3.2: if child's
/// salvageable state is false, parent's becomes false as well. Neither
/// document's activity changes merely because it cannot enter the bfcache.
pub fn propagateAbort(parent: *runtime.Instance, child: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.propagate_abort(parent, child);
}

/// HTML "destroy" `document` (§7.5.5): it is no longer salvageable and its
/// browsing context is null - `document.defaultView` answers null from here
/// on. What "destroy a child navigable" does to the documents of a removed
/// frame, and what "unload" ends with for a document nothing keeps.
pub fn destroy(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.destroy(document);
}

/// "Create and initialize a Document object" and "create a new browsing
/// context and document": `document`'s about base URL - its creator's, or
/// the navigation's source document's, document base URL - which an
/// about:blank or iframe srcdoc document uses as its fallback base URL.
/// Copied. Called by the navigable as it makes the document, before any of
/// its script runs.
pub fn setAboutBaseUrl(document: *runtime.Instance, url: ?[]const u8) void {
    const impl = implementation orelse return;
    impl.set_about_base_url(document, url);
}

/// HTML "fallback base URL" steps 1-2: the about base URL, when `document` is
/// an iframe srcdoc document or its URL matches about:blank and it has one;
/// otherwise null, and the fallback base URL is the document's URL (step 3).
/// Borrowed from the document.
pub fn aboutFallbackBaseUrl(document: *runtime.Instance) ?[]const u8 {
    const impl = implementation orelse return null;
    return impl.about_fallback_base_url(document);
}

/// HTML "shared declarative refresh steps" given `document`, `input` - a
/// meta refresh's content value, or a `Refresh` header's - and, for the
/// meta element's pragma, `meta`: once the refresh has come due,
/// `document`'s node navigable is navigated. "Will declaratively refresh"
/// is the document's, so only its first refresh counts.
pub fn declarativeRefresh(document: *runtime.Instance, input: []const u8, meta: ?*runtime.Instance) void {
    const impl = implementation orelse return;
    impl.declarative_refresh(document, input, meta);
}

/// The iframe load event steps, steps 5 and 7: set `document`'s "iframe
/// load in progress" flag while load is fired at its iframe, and unset it
/// after. A document opened meanwhile is muted (the document open steps,
/// step 14).
pub fn setIframeLoadInProgress(document: *runtime.Instance, in_progress: bool) void {
    const impl = implementation orelse return;
    impl.set_iframe_load_in_progress(document, in_progress);
}

/// Whether `document` has its "mute iframe load" flag set: the iframe load
/// event steps fire no load at its iframe (step 3).
pub fn isIframeLoadMuted(document: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.is_iframe_load_muted(document);
}

/// HTML "delay the load event": `document`'s load event - "the end" step 8 -
/// waits until a matching `undelayLoadEvent`. For work that has no other
/// term in step 8: an object element's fetch and the task that processes it
/// (4.8.7), say. Blink's Document::IncrementLoadEventDelayCount. Every
/// delay must be undelayed on every path its work can end by - done,
/// failed, the element removed, the document unloaded - or the document
/// never loads; a holder keeps the document and its slab generation, and
/// skips the undelay of a document that is gone.
pub fn delayLoadEvent(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.delay_load_event(document);
}

/// The end of one `delayLoadEvent`: if nothing else delays `document`'s load
/// event, "the end" goes on (Blink's DecrementLoadEventDelayCount).
pub fn undelayLoadEvent(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.undelay_load_event(document);
}

test "without an installed implementation nothing is asked of a document" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var document: runtime.Instance = undefined;
    try std.testing.expect(!associateParser(&document, &document));
    discardParser(&document, null);
    parserFinished(&document, &document);
    parsingStopped(&document);
    finishLoading(&document);
    loadDelayMayHaveEnded(&document);
    markReadyForPostLoadTasks(&document);
    delayLoadEvent(&document);
    undelayLoadEvent(&document);
    markInitialAboutBlank(&document);
    unload(&document);
    abort(&document);
    propagateAbort(&document, &document);
    destroy(&document);
    setAboutBaseUrl(&document, "http://x.test/");
    declarativeRefresh(&document, "0; url=http://x.test/", null);
    setIframeLoadInProgress(&document, true);
    // The answers that let a caller go on: a document nobody can ask about
    // is loaded, is no initial about:blank, is not unloading, and nobody
    // cancels leaving it.
    try std.testing.expect(isCompletelyLoaded(&document));
    try std.testing.expect(isReadyForPostLoadTasks(&document));
    try std.testing.expect(!delaysLoadEvent(&document));
    try std.testing.expect(!isInitialAboutBlank(&document));
    try std.testing.expect(!isUnloading(&document));
    try std.testing.expect(!fireBeforeUnload(&document).canceled);
    try std.testing.expect(aboutFallbackBaseUrl(&document) == null);
    // Nor is its load at its iframe muted: the load event fires.
    try std.testing.expect(!isIframeLoadMuted(&document));
}
