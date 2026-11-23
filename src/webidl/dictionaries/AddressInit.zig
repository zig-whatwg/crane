//! WebIDL dictionary: AddressInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AddressInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
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

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "country", .{ .string = "" } },
        .{ "addressLine", .empty_sequence },
        .{ "region", .{ .string = "" } },
        .{ "city", .{ .string = "" } },
        .{ "dependentLocality", .{ .string = "" } },
        .{ "postalCode", .{ .string = "" } },
        .{ "sortingCode", .{ .string = "" } },
        .{ "organization", .{ .string = "" } },
        .{ "recipient", .{ .string = "" } },
        .{ "phone", .{ .string = "" } },
    };
};
