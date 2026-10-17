//! WebIDL dictionary: MediaEncryptedEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const MediaEncryptedEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    initDataType: ?runtime.DOMString = null,
    initData: ?runtime.JSValue = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"initData"};
};
