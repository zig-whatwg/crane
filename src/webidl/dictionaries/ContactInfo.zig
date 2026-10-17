//! WebIDL dictionary: ContactInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ContactInfo = struct {
    address: ?[]const *runtime.Instance = null,
    email: ?[]const runtime.DOMString = null,
    icon: ?[]const *runtime.Instance = null,
    name: ?[]const runtime.DOMString = null,
    tel: ?[]const runtime.DOMString = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "address", "ContactAddress" },
        .{ "icon", "Blob" },
    };
};
