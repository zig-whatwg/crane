//! WebIDL dictionary: AddressInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AddressInit = struct {
    country: ?runtime.DOMString = null,
    addressLine: ?[]const runtime.DOMString = null,
    region: ?runtime.DOMString = null,
    city: ?runtime.DOMString = null,
    dependentLocality: ?runtime.DOMString = null,
    postalCode: ?runtime.DOMString = null,
    sortingCode: ?runtime.DOMString = null,
    organization: ?runtime.DOMString = null,
    recipient: ?runtime.DOMString = null,
    phone: ?runtime.DOMString = null,
};
