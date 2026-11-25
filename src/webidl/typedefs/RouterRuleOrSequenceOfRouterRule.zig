//! WebIDL typedef: RouterRuleOrSequenceOfRouterRule
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const RouterRuleOrSequenceOfRouterRule = union(enum) {
    router_rule: dictionaries.RouterRule,
    router_rule_sequence: []const dictionaries.RouterRule,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "router_rule", .kind = .dictionary },
        .{ .field = "router_rule_sequence", .kind = .{ .sequence = null } },
    };
};
