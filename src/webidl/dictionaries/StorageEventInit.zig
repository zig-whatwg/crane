//! WebIDL dictionary: StorageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const StorageEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    key: ?runtime.DOMString = null,
    oldValue: ?runtime.DOMString = null,
    newValue: ?runtime.DOMString = null,
    url: ?runtime.USVString = null,
    storageArea: ?*runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "key", "oldValue", "newValue", "storageArea" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "storageArea", "Storage" },
    };
};
