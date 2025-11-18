//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSTransformValueImpl = @import("impls").CSSTransformValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const DOMMatrix = @import("interfaces").DOMMatrix;

pub const CSSTransformValue = struct {
    pub const Meta = struct {
        pub const name = "CSSTransformValue";
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
            length: u32 = undefined,
            is2D: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSTransformValue, .{
        .deinit_fn = &deinit_wrapper,

        .get_is2D = &get_is2D,
        .get_length = &get_length,

        .call_parse = &call_parse,
        .call_parseAll = &call_parseAll,
        .call_toMatrix = &call_toMatrix,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSTransformValueImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSTransformValueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, transforms: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSTransformValueImpl.constructor(instance, transforms);
        
        return instance;
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSTransformValueImpl.get_length(instance);
    }

    pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
        return try CSSTransformValueImpl.get_is2D(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!anyopaque {
        
        return try CSSTransformValueImpl.call_parseAll(instance, property, cssText);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parse(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!CSSStyleValue {
        
        return try CSSTransformValueImpl.call_parse(instance, property, cssText);
    }

    pub fn call_toMatrix(instance: *runtime.Instance) anyerror!DOMMatrix {
        return try CSSTransformValueImpl.call_toMatrix(instance);
    }

};
