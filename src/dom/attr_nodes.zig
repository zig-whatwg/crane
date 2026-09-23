//! DOM § 4.9.2 Attr nodes, as the hook the rest of the engine reaches them
//! through where no IDL member fits.
//!
//! An element stores its attributes' data and makes an Attr node for one only
//! when script asks for it - `getAttributeNode`, `attributes`, and so on - the
//! design of Blink's Element::EnsureAttr and WebKit's Element::ensureAttr. A
//! node made that way needs its namespace, prefix and local name set, which
//! IDL gives no setter for; one whose attribute is removed must keep the
//! attribute's last value and lose its element. Neither the Element impl nor
//! Document's attribute factories may reach into the Attr impl for that, so
//! the Attr impl installs the implementation here in its `init` - which the
//! caller has always just run, through `interfaces.Attr.init`, to make the
//! node it passes in.
//!
//! lint-impls: hook for Attr

const runtime = @import("runtime");

pub const Error = error{ InvalidStateError, OutOfMemory };

/// What the Attr impl supplies.
pub const Implementation = struct {
    name: *const fn (attr: *runtime.Instance, namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) Error!void,
    attach: *const fn (attr: *runtime.Instance, element: *runtime.Instance) Error!void,
    detach: *const fn (attr: *runtime.Instance, value: []const u8) Error!void,
};

/// Per thread, like the nodes it serves.
threadlocal var implementation: ?Implementation = null;

/// Called by the Attr impl. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// Give a just-made Attr node its namespace, namespace prefix and local name.
pub fn name(attr: *runtime.Instance, namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.name(attr, namespace, prefix, local_name);
}

/// `attr` now stands for an attribute of `element`: its element is
/// `element`, its node document `element`'s, and its value is read from
/// `element`'s attribute list.
pub fn attach(attr: *runtime.Instance, element: *runtime.Instance) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.attach(attr, element);
}

/// The attribute `attr` stood for was removed or replaced: `attr` keeps
/// `value` and has no element.
pub fn detach(attr: *runtime.Instance, value: []const u8) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.detach(attr, value);
}
