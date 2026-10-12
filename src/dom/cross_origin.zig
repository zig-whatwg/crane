//! HTML 7.2.1 cross-origin objects, the host's half [cross_origin_objects].
//! The engine runs the WindowProxy's and Location's cross-origin internal
//! methods. What it asks the host is here: whether the current realm is
//! same origin-domain with a platform object's (IsPlatformObjectSameOrigin,
//! supplied as WindowRealmOptions.is_platform_object_same_origin), and which
//! child navigable a cross-origin name reaches.
//!
//! Both read origins through the settings objects (global_settings) and the
//! Window's IDL members, never an access-checked getter, and keep nothing:
//! a document's domain changes at any time, and the engine asks again on
//! every access.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#security-infrastructure-for-window,-windowproxy,-and-location-objects

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const global_settings = @import("global_settings.zig");

/// `realm`'s global object, as its realm record keeps it.
fn globalOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// HTML 7.2.1.3.3 IsPlatformObjectSameOrigin(O): "Return true if the current
/// settings object's origin is same origin-domain with O's relevant
/// settings object's origin, and false otherwise." `current` is the current
/// realm and `object` O - a Window or a Location; their settings objects'
/// origins are their globals' (a Window's: its associated Document's).
/// False when either global is unknown: an access the host cannot place is
/// refused. `host` is not read - a frame's realm is made with a host that
/// lives only while it is made.
pub fn isPlatformObjectSameOrigin(host: ?*anyopaque, current: runtime.Context, object: *runtime.Instance) bool {
    _ = host;
    const current_global = globalOf(current) orelse return false;
    const object_global = globalOf(object.ctx) orelse return false;
    return global_settings.sameOriginDomain(current_global, object_global);
}

/// HTML 7.2.3.5 [[GetOwnProperty]] step 6, for a cross-origin `window` (W):
/// the named child navigable with target name `name` - the first of W's
/// document-tree child navigables with it, in tree order - whose WindowProxy
/// the engine answers. Null when none has it.
///
/// Deviation, as the browsers do: HTML's document-tree child navigable
/// target name property set (7.2.2.3 step 5) keeps only the children whose
/// active document is same origin with W, but Chrome, Firefox and Safari
/// expose every named child of a cross-origin window. wpt.fyi:
/// html/browsers/the-window-object/named-access-on-the-window-object/
/// cross-origin-named-access.sub.html, which tests step 5, passes 1/3 in
/// Chrome 155 and 0/3 in Firefox 157 and Safari 27, and
/// html/browsers/origin/relaxing-the-same-origin-restriction/
/// document_domain_access_details.sub.html, which reaches a sibling at
/// another origin through `parent[name]`, passes 12/12, 12/12 and 10/12.
/// Blink's cross-origin named getter answers Frame::Tree().ScopedChild(name)
/// with no origin check.
pub fn childNavigableNamed(window: *runtime.Instance, name: []const u8) ?*runtime.Instance {
    if (name.len == 0) return null;
    const count = interfaces.Window.get_length(window) catch return null;
    var index: u32 = 0;
    while (index < count) : (index += 1) {
        const child = (interfaces.Window.call_item(window, index) catch null) orelse continue;
        var child_name = interfaces.Window.get_name(child) catch continue;
        defer child_name.deinit(child.ctx.allocator);
        if (std.mem.eql(u8, child_name.asSlice(), name)) return child;
    }
    return null;
}
