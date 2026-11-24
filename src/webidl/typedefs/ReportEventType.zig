//! WebIDL typedef: ReportEventType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const ReportEventType = union(enum) {
    fence_event: dictionaries.FenceEvent,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "fence_event", .kind = .dictionary },
        .{ .field = "domstring", .kind = .string },
    };
};
