//! WebIDL dictionary: CrossOriginStorageRequestFileHandleOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const CrossOriginStorageRequestFileHandleOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    create: ?bool = null,
    origins: ?typedefs.DOMStringOrSequenceOfDOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "create", .{ .boolean = false } },
    };
};
