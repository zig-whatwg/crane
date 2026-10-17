//! WebIDL dictionary: ShadowRootInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const enums = @import("enums");

pub const ShadowRootInit = struct {
    mode: enums.ShadowRootMode,
    delegatesFocus: ?bool = null,
    serializable: ?bool = null,
    slotAssignment: ?enums.SlotAssignmentMode = null,
    clonable: ?bool = null,
    customElementRegistry: webidl.Opt(?*runtime.Instance) = .notPassed(),

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"customElementRegistry"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "customElementRegistry", "CustomElementRegistry" },
    };
};
