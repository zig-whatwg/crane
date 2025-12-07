//! WebIDL dictionary: NavigationCurrentEntryChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const NavigationCurrentEntryChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    navigationType: ?enums.NavigationType = null,
    from: *runtime.Instance,
};
