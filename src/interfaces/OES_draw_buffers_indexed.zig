//! Generated from: OES_draw_buffers_indexed.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OES_draw_buffers_indexedImpl = @import("../impls/OES_draw_buffers_indexed.zig");

pub const OES_draw_buffers_indexed = struct {
    pub const Meta = struct {
        pub const name = "OES_draw_buffers_indexed";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(OES_draw_buffers_indexed, .{
        .deinit_fn = &deinit_wrapper,

        .call_blendEquationSeparateiOES = &call_blendEquationSeparateiOES,
        .call_blendEquationiOES = &call_blendEquationiOES,
        .call_blendFuncSeparateiOES = &call_blendFuncSeparateiOES,
        .call_blendFunciOES = &call_blendFunciOES,
        .call_colorMaskiOES = &call_colorMaskiOES,
        .call_disableiOES = &call_disableiOES,
        .call_enableiOES = &call_enableiOES,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        OES_draw_buffers_indexedImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        OES_draw_buffers_indexedImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_enableiOES(instance: *runtime.Instance, target: anyopaque, index: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OES_draw_buffers_indexedImpl.call_enableiOES(state, target, index);
    }

    pub fn call_blendEquationiOES(instance: *runtime.Instance, buf: anyopaque, mode: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OES_draw_buffers_indexedImpl.call_blendEquationiOES(state, buf, mode);
    }

    pub fn call_blendEquationSeparateiOES(instance: *runtime.Instance, buf: anyopaque, modeRGB: anyopaque, modeAlpha: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OES_draw_buffers_indexedImpl.call_blendEquationSeparateiOES(state, buf, modeRGB, modeAlpha);
    }

    pub fn call_blendFunciOES(instance: *runtime.Instance, buf: anyopaque, src: anyopaque, dst: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OES_draw_buffers_indexedImpl.call_blendFunciOES(state, buf, src, dst);
    }

    pub fn call_blendFuncSeparateiOES(instance: *runtime.Instance, buf: anyopaque, srcRGB: anyopaque, dstRGB: anyopaque, srcAlpha: anyopaque, dstAlpha: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OES_draw_buffers_indexedImpl.call_blendFuncSeparateiOES(state, buf, srcRGB, dstRGB, srcAlpha, dstAlpha);
    }

    pub fn call_colorMaskiOES(instance: *runtime.Instance, buf: anyopaque, r: anyopaque, g: anyopaque, b: anyopaque, a: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OES_draw_buffers_indexedImpl.call_colorMaskiOES(state, buf, r, g, b, a);
    }

    pub fn call_disableiOES(instance: *runtime.Instance, target: anyopaque, index: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OES_draw_buffers_indexedImpl.call_disableiOES(state, target, index);
    }

};
