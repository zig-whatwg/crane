//! Generated from: css-parser-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSParserQualifiedRuleImpl = @import("../impls/CSSParserQualifiedRule.zig");
const CSSParserRule = @import("CSSParserRule.zig");

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
            prelude: FrozenArray<CSSParserValue> = undefined,
            body: FrozenArray<CSSParserRule> = undefined,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSParserQualifiedRuleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSParserQualifiedRuleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, prelude: anyopaque, body: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSParserQualifiedRuleImpl.constructor(state, prelude, body);
        
        return instance;
    }

    pub fn get_prelude(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSParserQualifiedRuleImpl.get_prelude(state);
    }

    pub fn get_body(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSParserQualifiedRuleImpl.get_body(state);
    }

};
