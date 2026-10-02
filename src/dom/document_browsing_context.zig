//! A Document's browsing context, as the code that creates a document for a
//! window sets it.
//!
//! HTML's "create and initialize a Document object" makes a document whose
//! browsing context is the navigable's, and `document.defaultView` answers
//! that browsing context's WindowProxy from then on. The association is the
//! Document's state and no IDL member sets it, so Document installs this hook
//! from its `init` and the parsers that build a frame's document ask it -
//! the shape of `document_lifecycle.zig`. Setting it also keeps the
//! document's wrapper alive for as long as the window's realm lives, as the
//! window's `document` does in WebKit (a strong reference).
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#initialise-the-document-object
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-defaultview
//!
//! lint-impls: hook for Document

const runtime = @import("runtime");

/// What Document supplies.
pub const Implementation = struct {
    /// Make `window` `document`'s browsing context's window; a no-op for an
    /// object that is no Document.
    set_window: *const fn (document: *runtime.Instance, window: *runtime.Instance) void,
    /// `document` was destroyed: HTML "destroy a document" step 8 sets its
    /// browsing context to null, so its defaultView answers null from then
    /// on - and nothing keeps it for the window any more.
    clear_window: ?*const fn (document: *runtime.Instance) void = null,
};

/// Per thread, like the documents it serves.
threadlocal var implementation: ?Implementation = null;

/// Called by Document. Idempotent: every call installs the same function.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// Make `window` `document`'s window - what its defaultView answers.
pub fn setWindow(document: *runtime.Instance, window: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.set_window(document, window);
}

/// `document` was destroyed: its browsing context is null from now on (HTML
/// "destroy a document" step 8).
pub fn clearWindow(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    const clear = impl.clear_window orelse return;
    clear(document);
}

test "without an installed implementation setting the window does nothing" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads them.
    var document: runtime.Instance = undefined;
    var window: runtime.Instance = undefined;
    setWindow(&document, &window);
}
