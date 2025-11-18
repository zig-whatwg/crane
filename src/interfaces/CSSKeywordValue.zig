//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSKeywordValueImpl = @import("../impls/CSSKeywordValue.zig");
const CSSStyleValue = @import("CSSStyleValue.zig");

pub const CSSKeywordValue = struct {
    pub const Meta = struct {
        pub const name = "CSSKeywordValue";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSStyleValue;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            value: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSKeywordValue, .{
        .deinit_fn = &deinit_wrapper,

        .get_value = &get_value,

        .set_value = &set_value,

        .call_parse = &call_parse,
        .call_parseAll = &call_parseAll,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSKeywordValueImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSKeywordValueImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, value: runtime.USVString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSKeywordValueImpl.constructor(state, value);
        
        return instance;
    }

    pub fn get_value(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return CSSKeywordValueImpl.get_value(state);
    }

    pub fn set_value(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        CSSKeywordValueImpl.set_value(state, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSKeywordValueImpl.call_parseAll(state, property, cssText);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parse(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSKeywordValueImpl.call_parse(state, property, cssText);
    }

};
