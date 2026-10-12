//! HTML "same origin-domain" (7.1.1.2) between the entry settings object's
//! origin and a Window's - the step the Location interface's members begin
//! with: "If this's relevant Document is non-null and its origin is not same
//! origin-domain with the entry settings object's origin, then throw a
//! "SecurityError" DOMException."
//!
//! A shared helper, not an impl's: a Window's origin is its settings
//! object's (dom.global_settings) - its serialization and its origin record,
//! the associated Document's, whose identity and domain decide. Never the
//! access-checked Window.document getter, whose own check this one serves.
//! Window's own checks use the same comparison (dom.origin_record).
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-location-interface

const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

/// The pure comparison over serializations and domains (dom.origin_record).
pub const sameOriginDomainValues = dom.origin_record.sameOriginDomainValues;

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
/// objects: their associated Documents' origins. An about:blank or srcdoc
/// document shares its creator's origin record, so its domain is its
/// creator's without walking to the creator.
pub fn sameOriginDomain(a: *runtime.Instance, b: *runtime.Instance) bool {
    return dom.global_settings.sameOriginDomain(a, b);
}
