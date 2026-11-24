//! WebIDL dictionary: ElementCreationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const ElementCreationOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    customElementRegistry: webidl.Opt(?*runtime.Instance) = .notPassed(),
    is: ?runtime.DOMString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"customElementRegistry"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "customElementRegistry", "CustomElementRegistry" },
    };
};
