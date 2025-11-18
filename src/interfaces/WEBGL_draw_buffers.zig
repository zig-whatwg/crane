//! Generated from: WEBGL_draw_buffers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_draw_buffersImpl = @import("../impls/WEBGL_draw_buffers.zig");

pub const WEBGL_draw_buffers = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_draw_buffers";
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

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT0_WEBGL = 36064;
    pub fn get_COLOR_ATTACHMENT0_WEBGL() GLenum {
        return 36064;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT1_WEBGL = 36065;
    pub fn get_COLOR_ATTACHMENT1_WEBGL() GLenum {
        return 36065;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT2_WEBGL = 36066;
    pub fn get_COLOR_ATTACHMENT2_WEBGL() GLenum {
        return 36066;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT3_WEBGL = 36067;
    pub fn get_COLOR_ATTACHMENT3_WEBGL() GLenum {
        return 36067;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT4_WEBGL = 36068;
    pub fn get_COLOR_ATTACHMENT4_WEBGL() GLenum {
        return 36068;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT5_WEBGL = 36069;
    pub fn get_COLOR_ATTACHMENT5_WEBGL() GLenum {
        return 36069;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT6_WEBGL = 36070;
    pub fn get_COLOR_ATTACHMENT6_WEBGL() GLenum {
        return 36070;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT7_WEBGL = 36071;
    pub fn get_COLOR_ATTACHMENT7_WEBGL() GLenum {
        return 36071;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT8_WEBGL = 36072;
    pub fn get_COLOR_ATTACHMENT8_WEBGL() GLenum {
        return 36072;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT9_WEBGL = 36073;
    pub fn get_COLOR_ATTACHMENT9_WEBGL() GLenum {
        return 36073;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT10_WEBGL = 36074;
    pub fn get_COLOR_ATTACHMENT10_WEBGL() GLenum {
        return 36074;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT11_WEBGL = 36075;
    pub fn get_COLOR_ATTACHMENT11_WEBGL() GLenum {
        return 36075;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT12_WEBGL = 36076;
    pub fn get_COLOR_ATTACHMENT12_WEBGL() GLenum {
        return 36076;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT13_WEBGL = 36077;
    pub fn get_COLOR_ATTACHMENT13_WEBGL() GLenum {
        return 36077;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT14_WEBGL = 36078;
    pub fn get_COLOR_ATTACHMENT14_WEBGL() GLenum {
        return 36078;
    }

    /// WebIDL constant: const GLenum COLOR_ATTACHMENT15_WEBGL = 36079;
    pub fn get_COLOR_ATTACHMENT15_WEBGL() GLenum {
        return 36079;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER0_WEBGL = 34853;
    pub fn get_DRAW_BUFFER0_WEBGL() GLenum {
        return 34853;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER1_WEBGL = 34854;
    pub fn get_DRAW_BUFFER1_WEBGL() GLenum {
        return 34854;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER2_WEBGL = 34855;
    pub fn get_DRAW_BUFFER2_WEBGL() GLenum {
        return 34855;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER3_WEBGL = 34856;
    pub fn get_DRAW_BUFFER3_WEBGL() GLenum {
        return 34856;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER4_WEBGL = 34857;
    pub fn get_DRAW_BUFFER4_WEBGL() GLenum {
        return 34857;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER5_WEBGL = 34858;
    pub fn get_DRAW_BUFFER5_WEBGL() GLenum {
        return 34858;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER6_WEBGL = 34859;
    pub fn get_DRAW_BUFFER6_WEBGL() GLenum {
        return 34859;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER7_WEBGL = 34860;
    pub fn get_DRAW_BUFFER7_WEBGL() GLenum {
        return 34860;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER8_WEBGL = 34861;
    pub fn get_DRAW_BUFFER8_WEBGL() GLenum {
        return 34861;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER9_WEBGL = 34862;
    pub fn get_DRAW_BUFFER9_WEBGL() GLenum {
        return 34862;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER10_WEBGL = 34863;
    pub fn get_DRAW_BUFFER10_WEBGL() GLenum {
        return 34863;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER11_WEBGL = 34864;
    pub fn get_DRAW_BUFFER11_WEBGL() GLenum {
        return 34864;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER12_WEBGL = 34865;
    pub fn get_DRAW_BUFFER12_WEBGL() GLenum {
        return 34865;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER13_WEBGL = 34866;
    pub fn get_DRAW_BUFFER13_WEBGL() GLenum {
        return 34866;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER14_WEBGL = 34867;
    pub fn get_DRAW_BUFFER14_WEBGL() GLenum {
        return 34867;
    }

    /// WebIDL constant: const GLenum DRAW_BUFFER15_WEBGL = 34868;
    pub fn get_DRAW_BUFFER15_WEBGL() GLenum {
        return 34868;
    }

    /// WebIDL constant: const GLenum MAX_COLOR_ATTACHMENTS_WEBGL = 36063;
    pub fn get_MAX_COLOR_ATTACHMENTS_WEBGL() GLenum {
        return 36063;
    }

    /// WebIDL constant: const GLenum MAX_DRAW_BUFFERS_WEBGL = 34852;
    pub fn get_MAX_DRAW_BUFFERS_WEBGL() GLenum {
        return 34852;
    }

    pub const vtable = runtime.buildVTable(WEBGL_draw_buffers, .{
        .deinit_fn = &deinit_wrapper,

        .get_COLOR_ATTACHMENT0_WEBGL = &get_COLOR_ATTACHMENT0_WEBGL,
        .get_COLOR_ATTACHMENT10_WEBGL = &get_COLOR_ATTACHMENT10_WEBGL,
        .get_COLOR_ATTACHMENT11_WEBGL = &get_COLOR_ATTACHMENT11_WEBGL,
        .get_COLOR_ATTACHMENT12_WEBGL = &get_COLOR_ATTACHMENT12_WEBGL,
        .get_COLOR_ATTACHMENT13_WEBGL = &get_COLOR_ATTACHMENT13_WEBGL,
        .get_COLOR_ATTACHMENT14_WEBGL = &get_COLOR_ATTACHMENT14_WEBGL,
        .get_COLOR_ATTACHMENT15_WEBGL = &get_COLOR_ATTACHMENT15_WEBGL,
        .get_COLOR_ATTACHMENT1_WEBGL = &get_COLOR_ATTACHMENT1_WEBGL,
        .get_COLOR_ATTACHMENT2_WEBGL = &get_COLOR_ATTACHMENT2_WEBGL,
        .get_COLOR_ATTACHMENT3_WEBGL = &get_COLOR_ATTACHMENT3_WEBGL,
        .get_COLOR_ATTACHMENT4_WEBGL = &get_COLOR_ATTACHMENT4_WEBGL,
        .get_COLOR_ATTACHMENT5_WEBGL = &get_COLOR_ATTACHMENT5_WEBGL,
        .get_COLOR_ATTACHMENT6_WEBGL = &get_COLOR_ATTACHMENT6_WEBGL,
        .get_COLOR_ATTACHMENT7_WEBGL = &get_COLOR_ATTACHMENT7_WEBGL,
        .get_COLOR_ATTACHMENT8_WEBGL = &get_COLOR_ATTACHMENT8_WEBGL,
        .get_COLOR_ATTACHMENT9_WEBGL = &get_COLOR_ATTACHMENT9_WEBGL,
        .get_DRAW_BUFFER0_WEBGL = &get_DRAW_BUFFER0_WEBGL,
        .get_DRAW_BUFFER10_WEBGL = &get_DRAW_BUFFER10_WEBGL,
        .get_DRAW_BUFFER11_WEBGL = &get_DRAW_BUFFER11_WEBGL,
        .get_DRAW_BUFFER12_WEBGL = &get_DRAW_BUFFER12_WEBGL,
        .get_DRAW_BUFFER13_WEBGL = &get_DRAW_BUFFER13_WEBGL,
        .get_DRAW_BUFFER14_WEBGL = &get_DRAW_BUFFER14_WEBGL,
        .get_DRAW_BUFFER15_WEBGL = &get_DRAW_BUFFER15_WEBGL,
        .get_DRAW_BUFFER1_WEBGL = &get_DRAW_BUFFER1_WEBGL,
        .get_DRAW_BUFFER2_WEBGL = &get_DRAW_BUFFER2_WEBGL,
        .get_DRAW_BUFFER3_WEBGL = &get_DRAW_BUFFER3_WEBGL,
        .get_DRAW_BUFFER4_WEBGL = &get_DRAW_BUFFER4_WEBGL,
        .get_DRAW_BUFFER5_WEBGL = &get_DRAW_BUFFER5_WEBGL,
        .get_DRAW_BUFFER6_WEBGL = &get_DRAW_BUFFER6_WEBGL,
        .get_DRAW_BUFFER7_WEBGL = &get_DRAW_BUFFER7_WEBGL,
        .get_DRAW_BUFFER8_WEBGL = &get_DRAW_BUFFER8_WEBGL,
        .get_DRAW_BUFFER9_WEBGL = &get_DRAW_BUFFER9_WEBGL,
        .get_MAX_COLOR_ATTACHMENTS_WEBGL = &get_MAX_COLOR_ATTACHMENTS_WEBGL,
        .get_MAX_DRAW_BUFFERS_WEBGL = &get_MAX_DRAW_BUFFERS_WEBGL,

        .call_drawBuffersWEBGL = &call_drawBuffersWEBGL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WEBGL_draw_buffersImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WEBGL_draw_buffersImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_drawBuffersWEBGL(instance: *runtime.Instance, buffers: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WEBGL_draw_buffersImpl.call_drawBuffersWEBGL(state, buffers);
    }

};
