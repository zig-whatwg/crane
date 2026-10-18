//! WebIDL dictionary: KeyframeEffectOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const EffectTiming = @import("EffectTiming.zig").EffectTiming;

pub const KeyframeEffectOptions = struct {
    // Inherited from EffectTiming
    base: EffectTiming,

    composite: ?enums.CompositeOperation = null,
    pseudoElement: ?typedefs.CSSOMString = null,
    iterationComposite: ?enums.IterationCompositeOperation = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "composite", .{ .string = "replace" } },
        .{ "pseudoElement", .null },
        .{ "iterationComposite", .{ .string = "replace" } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"pseudoElement"};
};
