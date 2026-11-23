//! WebIDL dictionary: SyncEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const SyncEventInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    tag: runtime.DOMString,
    lastChance: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "lastChance", .{ .boolean = false } },
    };
};
