//! WebIDL dictionary: ReadableWritablePair
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ReadableWritablePair = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    readable: *runtime.Instance,
    writable: *runtime.Instance,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "readable", "ReadableStream" },
        .{ "writable", "WritableStream" },
    };
};
