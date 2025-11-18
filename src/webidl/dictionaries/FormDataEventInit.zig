//! WebIDL dictionary: FormDataEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const FormDataEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    formData: anyopaque,
};
