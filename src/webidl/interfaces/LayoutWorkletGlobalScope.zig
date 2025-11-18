//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutWorkletGlobalScopeImpl = @import("impls").LayoutWorkletGlobalScope;
const WorkletGlobalScope = @import("interfaces").WorkletGlobalScope;
const VoidFunction = @import("callbacks").VoidFunction;

pub const LayoutWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "LayoutWorkletGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkletGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worklet", "LayoutWorklet" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "LayoutWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .LayoutWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LayoutWorkletGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .call_registerLayout = &call_registerLayout,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        LayoutWorkletGlobalScopeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutWorkletGlobalScopeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_registerLayout(instance: *runtime.Instance, name: DOMString, layoutCtor: VoidFunction) anyerror!void {
        
        return try LayoutWorkletGlobalScopeImpl.call_registerLayout(instance, name, layoutCtor);
    }

};
