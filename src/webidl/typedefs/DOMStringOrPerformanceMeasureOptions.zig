//! WebIDL typedef: DOMStringOrPerformanceMeasureOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const DOMStringOrPerformanceMeasureOptions = union(enum) {
    domstring: runtime.DOMString,
    performance_measure_options: dictionaries.PerformanceMeasureOptions,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "performance_measure_options", .kind = .dictionary },
    };
};
