//! HTML "same origin-domain" (7.1.1.2) between the entry settings object's
//! origin and a Window's - the step the Location interface's members begin
//! with: "If this's relevant Document is non-null and its origin is not same
//! origin-domain with the entry settings object's origin, then throw a
//! "SecurityError" DOMException."
//!
//! A shared helper, not an impl's: types reach a Window's origin and document
//! through its interface (the WindowOrWorkerGlobalScope `origin` getter,
//! `document`) and the document's origin's domain through the
//! dom.document_origin hook. Window's own checks still use its private copy
//! of the comparison (Window.zig sameOriginDomain), queued to move here.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-location-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

/// The Window that is `realm`'s global object, or null for a realm whose
/// global is not a Window (a worker's, a ShadowRealm's).
pub fn windowOfRealm(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// Whether the entry settings object's origin is same origin-domain with
/// `window`'s - its document's, which a Window's settings object's origin
/// is. With no entry realm there is no script on the stack: the host itself
/// is asking, which is the window's own access.
pub fn entryIsSameOriginDomainWith(window: *runtime.Instance) bool {
    const entry = engine.entryRealm() orelse return true;
    // A Location is only exposed in Window realms; script of any other
    // global reaching one is not same origin-domain with it.
    const entry_window = windowOfRealm(entry) orelse return false;
    if (entry_window == window) return true;
    return sameOriginDomain(entry_window, window);
}

/// HTML "same origin-domain" for the origins of two Windows' settings
/// objects.
pub fn sameOriginDomain(a: *runtime.Instance, b: *runtime.Instance) bool {
    if (a == b) return true;
    const a_origin = interfaces.Window.get_origin(a) catch return false;
    defer a.ctx.allocator.free(a_origin);
    const b_origin = interfaces.Window.get_origin(b) catch return false;
    defer b.ctx.allocator.free(b_origin);
    // 1. "If A and B are the same opaque origin, then return true." An
    // opaque origin serializes as "null", which does not say which one it
    // is: two different windows are not known to share one.
    if (std.mem.eql(u8, a_origin, "null") or std.mem.eql(u8, b_origin, "null")) return false;
    // 2. "If A and B are both tuple origins, run these substeps:"
    const a_domain = domainOf(a);
    const b_domain = domainOf(b);
    // 2.1. "If A and B's schemes are identical, and their domains are
    // identical and non-null, then return true."
    if (a_domain != null and b_domain != null) {
        return std.mem.eql(u8, schemeOf(a_origin), schemeOf(b_origin)) and std.mem.eql(u8, a_domain.?, b_domain.?);
    }
    // 2.2. "Otherwise, if A and B are same origin and their domains are
    // identical and null, then return true."
    if (a_domain == null and b_domain == null) return std.mem.eql(u8, a_origin, b_origin);
    // 3. "Return false."
    return false;
}

/// The domain of `window`'s document's origin, or null (BORROWED from the
/// document).
///
/// Deviations, stated: the document is read through Window's `document`
/// getter, which answers only an accessor same origin-domain with the
/// window by the INCUMBENT realm's measure - a document it refuses reads as
/// a null domain; and a document whose origin is its creator's (about:blank)
/// reads its own domain, not its creator's (Window.zig's originDomainOf walks
/// to the creator). Both differ from the spec only after document.domain was
/// set.
fn domainOf(window: *runtime.Instance) ?[]const u8 {
    const document = interfaces.Window.get_document(window) catch return null;
    return dom.document_origin.domain(document);
}

/// The scheme of a tuple origin's serialization.
fn schemeOf(serialized: []const u8) []const u8 {
    return serialized[0 .. std.mem.indexOf(u8, serialized, "://") orelse serialized.len];
}

test "schemeOf reads the scheme of a serialized tuple origin" {
    try std.testing.expectEqualStrings("https", schemeOf("https://example.com"));
    try std.testing.expectEqualStrings("http", schemeOf("http://www1.web-platform.test:8000"));
}
