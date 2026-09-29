//! WebIDL dictionary: WheelEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MouseEventInit = @import("MouseEventInit.zig").MouseEventInit;

pub const WheelEventInit = struct {
    // Inherited from MouseEventInit
    base: MouseEventInit,

    deltaX: ?f64 = null,
    deltaY: ?f64 = null,
    deltaZ: ?f64 = null,
    deltaMode: ?u32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "deltaX", "deltaY", "deltaZ" };
};
