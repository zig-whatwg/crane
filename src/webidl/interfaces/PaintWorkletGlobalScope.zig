//! Generated from: css-paint-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaintWorkletGlobalScopeImpl = @import("impls").PaintWorkletGlobalScope;
const WorkletGlobalScope = @import("interfaces").WorkletGlobalScope;
const VoidFunction = @import("callbacks").VoidFunction;

pub const PaintWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "PaintWorkletGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkletGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worklet", "PaintWorklet" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "PaintWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .PaintWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            devicePixelRatio: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PaintWorkletGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .get_devicePixelRatio = &get_devicePixelRatio,

        .call_registerPaint = &call_registerPaint,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PaintWorkletGlobalScopeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaintWorkletGlobalScopeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_devicePixelRatio(instance: *runtime.Instance) anyerror!f64 {
        return try PaintWorkletGlobalScopeImpl.get_devicePixelRatio(instance);
    }

    pub fn call_registerPaint(instance: *runtime.Instance, name: DOMString, paintCtor: VoidFunction) anyerror!void {
        
        return try PaintWorkletGlobalScopeImpl.call_registerPaint(instance, name, paintCtor);
    }

};
