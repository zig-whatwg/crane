//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSVariableReferenceValueImpl = @import("../impls/CSSVariableReferenceValue.zig");

pub const CSSVariableReferenceValue = struct {
    pub const Meta = struct {
        pub const name = "CSSVariableReferenceValue";
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
        struct {
            variable: runtime.USVString = undefined,
            fallback: ?CSSUnparsedValue = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSVariableReferenceValue, .{
        .deinit_fn = &deinit_wrapper,

        .get_fallback = &get_fallback,
        .get_variable = &get_variable,

        .set_variable = &set_variable,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSVariableReferenceValueImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSVariableReferenceValueImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, variable: runtime.USVString, fallback: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSVariableReferenceValueImpl.constructor(state, variable, fallback);
        
        return instance;
    }

    pub fn get_variable(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return CSSVariableReferenceValueImpl.get_variable(state);
    }

    pub fn set_variable(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        CSSVariableReferenceValueImpl.set_variable(state, value);
    }

    pub fn get_fallback(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSVariableReferenceValueImpl.get_fallback(state);
    }

};
