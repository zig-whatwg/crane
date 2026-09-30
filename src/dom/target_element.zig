//! HTML 7.4.6.4: every Document has a target element, "used in defining the
//! :target pseudo-class and ... updated by" scroll to the fragment. It is
//! initially null.
//!
//! The state is the Document's; the selector matcher and "scroll to the
//! fragment" reach it here. Document installs the implementation from its
//! init, before any document can have a target.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#target-element
//!
//! lint-impls: hook for Document

const runtime = @import("runtime");

/// What the Document impl supplies.
pub const Implementation = struct {
    /// `document`'s target element, or null - also when the element it was
    /// set to has since been freed.
    get: *const fn (document: *runtime.Instance) ?*runtime.Instance,
    /// Set `document`'s target element.
    set: *const fn (document: *runtime.Instance, element: ?*runtime.Instance) void,
};

/// Per thread, like the documents.
threadlocal var implementation: ?Implementation = null;

/// Called by Document. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// `document`'s target element.
pub fn get(document: *runtime.Instance) ?*runtime.Instance {
    const impl = implementation orelse return null;
    return impl.get(document);
}

/// "Set document's target element to" `element`.
pub fn set(document: *runtime.Instance, element: ?*runtime.Instance) void {
    const impl = implementation orelse return;
    impl.set(document, element);
}
