//! A document's origin as other objects' security checks read it: its
//! origin's domain (HTML 7.1.1.2), which the document.domain setter sets and
//! "same origin-domain" compares. No IDL member tells a null domain from a
//! set one - document.domain returns the effective domain either way - so
//! Document installs this hook and Window's cross-origin checks ask it.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-domain
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain
//!
//! lint-impls: hook for Document
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// What Document supplies.
pub const Implementation = struct {
    /// `document`'s origin's domain, serialized, or null. BORROWED from the
    /// document until its domain next changes.
    domain: *const fn (document: *runtime.Instance) ?[]const u8,
};

var implementation: ?Implementation = null;

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `document`'s origin's domain, or null - which it is until the
/// document.domain setter runs, and for a document Document never made.
pub fn domain(document: *runtime.Instance) ?[]const u8 {
    const impl = implementation orelse return null;
    return impl.domain(document);
}
