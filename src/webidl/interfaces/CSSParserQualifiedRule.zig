//! Generated from: css-parser-api.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSParserQualifiedRuleImpl = @import("impls").CSSParserQualifiedRule;
const CSSParserRule = @import("interfaces").CSSParserRule;
const CSSToken = @import("typedefs").CSSToken;
const CSSParserValue = @import("interfaces").CSSParserValue;
const DOMString = @import("typedefs").DOMString;

pub const CSSParserQualifiedRule = struct {
    pub const Meta = struct {
        pub const name = "CSSParserQualifiedRule";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSParserRule;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            prelude: runtime.FrozenArray(CSSParserValue) = undefined,
            body: runtime.FrozenArray(CSSParserRule) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSParserQualifiedRule, .{
        .deinit_fn = &deinit_wrapper,

        .get_body = &get_body,
        .get_prelude = &get_prelude,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CSSParserQualifiedRuleImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSParserQualifiedRuleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, prelude: anyopaque, body: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSParserQualifiedRuleImpl.constructor(instance, prelude, body);
        
        return instance;
    }

    pub fn get_prelude(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSParserQualifiedRuleImpl.get_prelude(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSParserQualifiedRuleImpl.get_body(instance);
    }

};
