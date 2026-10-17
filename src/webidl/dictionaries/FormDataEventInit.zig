//! WebIDL dictionary: FormDataEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const FormDataEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    formData: *runtime.Instance,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "formData", "FormData" },
    };
};
