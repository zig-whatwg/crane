//! WebIDL dictionary: BasePropertyIndexedKeyframe
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("typedefs");

pub const BasePropertyIndexedKeyframe = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    offset: webidl.Opt(?typedefs.DoubleOrSequenceOfNullableDouble) = .notPassed(),
    easing: ?typedefs.DOMStringOrSequenceOfDOMString = null,
    composite: ?typedefs.CompositeOperationOrAutoOrSequenceOfCompositeOperationOrAuto = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "offset", .empty_sequence },
        .{ "easing", .empty_sequence },
        .{ "composite", .empty_sequence },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"offset"};
};
