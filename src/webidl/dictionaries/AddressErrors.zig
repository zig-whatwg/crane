//! WebIDL dictionary: AddressErrors
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const AddressErrors = struct {
    addressLine: ?runtime.DOMString = null,
    city: ?runtime.DOMString = null,
    country: ?runtime.DOMString = null,
    dependentLocality: ?runtime.DOMString = null,
    organization: ?runtime.DOMString = null,
    phone: ?runtime.DOMString = null,
    postalCode: ?runtime.DOMString = null,
    recipient: ?runtime.DOMString = null,
    region: ?runtime.DOMString = null,
    sortingCode: ?runtime.DOMString = null,
};
