//! A document's origin as other objects' security checks read it: its
//! origin record (dom.origin_record) - the object it shares with every
//! document whose origin HTML says is its own - and that origin's domain
//! (HTML 7.1.1.2), which the document.domain setter sets and "same
//! origin-domain" compares. No IDL member tells a null domain from a set one
//! - document.domain returns the effective domain either way - and no IDL
//! member returns the origin object, so Document installs this hook and the
//! cross-origin checks ask it, never an access-checked getter.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-domain
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain
//!
//! lint-impls: hook for Document
const process_start = @import("process_start.zig");

const runtime = @import("runtime");
const OriginRecord = @import("origin_record.zig").OriginRecord;

/// What Document supplies.
pub const Implementation = struct {
    /// `document`'s origin's domain, serialized, or null. BORROWED from the
    /// document's origin record until its domain next changes.
    domain: *const fn (document: *runtime.Instance) ?[]const u8,
    /// `document`'s origin record. BORROWED: a holder that keeps it past the
    /// call retains it.
    record: *const fn (document: *runtime.Instance) ?*OriginRecord,
    /// `document`'s origin record with its serialization resolved: what a
    /// document made with this one's origin is given (Document's `origin`
    /// construction argument). BORROWED, as `record`.
    shareable: *const fn (document: *runtime.Instance) error{OutOfMemory}!?*OriginRecord,
};

var implementation: ?Implementation = null;

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `document`'s origin's domain, or null - which it is until the
/// document.domain setter runs on a document of its origin, and for a
/// document Document never made.
pub fn domain(document: *runtime.Instance) ?[]const u8 {
    const impl = implementation orelse return null;
    return impl.domain(document);
}

/// `document`'s origin record (borrowed), or null for a document Document
/// never made.
pub fn record(document: *runtime.Instance) ?*OriginRecord {
    const impl = implementation orelse return null;
    return impl.record(document);
}

/// `document`'s origin record with its serialization resolved (borrowed), to
/// give a document made with its origin; null for a document Document never
/// made.
pub fn shareable(document: *runtime.Instance) error{OutOfMemory}!?*OriginRecord {
    const impl = implementation orelse return null;
    return impl.shareable(document);
}
