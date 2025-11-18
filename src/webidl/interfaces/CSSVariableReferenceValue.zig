//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSVariableReferenceValueImpl = @import("impls").CSSVariableReferenceValue;
const CSSUnparsedValue = @import("interfaces").CSSUnparsedValue;

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
        
        // Initialize the instance (Impl receives full instance)
        CSSVariableReferenceValueImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSVariableReferenceValueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, variable: runtime.USVString, fallback: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSVariableReferenceValueImpl.constructor(instance, variable, fallback);
        
        return instance;
    }

    pub fn get_variable(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CSSVariableReferenceValueImpl.get_variable(instance);
    }

    pub fn set_variable(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try CSSVariableReferenceValueImpl.set_variable(instance, value);
    }

    pub fn get_fallback(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSVariableReferenceValueImpl.get_fallback(instance);
    }

};
