//! WebIDL dictionary: ContactInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ContactInfo = struct {
    address: ?[]const *runtime.Instance = null,
    email: ?[]const runtime.DOMString = null,
    icon: ?[]const *runtime.Instance = null,
    name: ?[]const runtime.DOMString = null,
    tel: ?[]const runtime.DOMString = null,
};
