//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSStyleValueImpl = @import("../impls/CSSStyleValue.zig");

pub const CSSStyleValue = struct {
    pub const Meta = struct {
        pub const name = "CSSStyleValue";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSStyleValue, .{
        .deinit_fn = &deinit_wrapper,

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
        CSSStyleValueImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSStyleValueImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSStyleValueImpl.call_parseAll(state, property, cssText);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parse(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSStyleValueImpl.call_parse(state, property, cssText);
    }

};
