//! WebIDL dictionary: GamepadEffectParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GamepadEffectParameters = struct {
    duration: ?u64 = null,
    startDelay: ?u64 = null,
    strongMagnitude: ?f64 = null,
    weakMagnitude: ?f64 = null,
    leftTrigger: ?f64 = null,
    rightTrigger: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "strongMagnitude", "weakMagnitude", "leftTrigger", "rightTrigger" };
};
