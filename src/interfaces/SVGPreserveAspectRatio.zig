//! Generated from: SVG.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGPreserveAspectRatioImpl = @import("../impls/SVGPreserveAspectRatio.zig");

pub const SVGPreserveAspectRatio = struct {
    pub const Meta = struct {
        pub const name = "SVGPreserveAspectRatio";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            align: u16 = undefined,
            meetOrSlice: u16 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_UNKNOWN = 0;
    pub fn get_SVG_PRESERVEASPECTRATIO_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_NONE = 1;
    pub fn get_SVG_PRESERVEASPECTRATIO_NONE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_XMINYMIN = 2;
    pub fn get_SVG_PRESERVEASPECTRATIO_XMINYMIN() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_XMIDYMIN = 3;
    pub fn get_SVG_PRESERVEASPECTRATIO_XMIDYMIN() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_XMAXYMIN = 4;
    pub fn get_SVG_PRESERVEASPECTRATIO_XMAXYMIN() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_XMINYMID = 5;
    pub fn get_SVG_PRESERVEASPECTRATIO_XMINYMID() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_XMIDYMID = 6;
    pub fn get_SVG_PRESERVEASPECTRATIO_XMIDYMID() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_XMAXYMID = 7;
    pub fn get_SVG_PRESERVEASPECTRATIO_XMAXYMID() u16 {
        return 7;
    }

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_XMINYMAX = 8;
    pub fn get_SVG_PRESERVEASPECTRATIO_XMINYMAX() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_XMIDYMAX = 9;
    pub fn get_SVG_PRESERVEASPECTRATIO_XMIDYMAX() u16 {
        return 9;
    }

    /// WebIDL constant: const unsigned short SVG_PRESERVEASPECTRATIO_XMAXYMAX = 10;
    pub fn get_SVG_PRESERVEASPECTRATIO_XMAXYMAX() u16 {
        return 10;
    }

    /// WebIDL constant: const unsigned short SVG_MEETORSLICE_UNKNOWN = 0;
    pub fn get_SVG_MEETORSLICE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_MEETORSLICE_MEET = 1;
    pub fn get_SVG_MEETORSLICE_MEET() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_MEETORSLICE_SLICE = 2;
    pub fn get_SVG_MEETORSLICE_SLICE() u16 {
        return 2;
    }

    pub const vtable = runtime.buildVTable(SVGPreserveAspectRatio, .{
        .deinit_fn = &deinit_wrapper,

        .get_SVG_MEETORSLICE_MEET = &get_SVG_MEETORSLICE_MEET,
        .get_SVG_MEETORSLICE_SLICE = &get_SVG_MEETORSLICE_SLICE,
        .get_SVG_MEETORSLICE_UNKNOWN = &get_SVG_MEETORSLICE_UNKNOWN,
        .get_SVG_PRESERVEASPECTRATIO_NONE = &get_SVG_PRESERVEASPECTRATIO_NONE,
        .get_SVG_PRESERVEASPECTRATIO_UNKNOWN = &get_SVG_PRESERVEASPECTRATIO_UNKNOWN,
        .get_SVG_PRESERVEASPECTRATIO_XMAXYMAX = &get_SVG_PRESERVEASPECTRATIO_XMAXYMAX,
        .get_SVG_PRESERVEASPECTRATIO_XMAXYMID = &get_SVG_PRESERVEASPECTRATIO_XMAXYMID,
        .get_SVG_PRESERVEASPECTRATIO_XMAXYMIN = &get_SVG_PRESERVEASPECTRATIO_XMAXYMIN,
        .get_SVG_PRESERVEASPECTRATIO_XMIDYMAX = &get_SVG_PRESERVEASPECTRATIO_XMIDYMAX,
        .get_SVG_PRESERVEASPECTRATIO_XMIDYMID = &get_SVG_PRESERVEASPECTRATIO_XMIDYMID,
        .get_SVG_PRESERVEASPECTRATIO_XMIDYMIN = &get_SVG_PRESERVEASPECTRATIO_XMIDYMIN,
        .get_SVG_PRESERVEASPECTRATIO_XMINYMAX = &get_SVG_PRESERVEASPECTRATIO_XMINYMAX,
        .get_SVG_PRESERVEASPECTRATIO_XMINYMID = &get_SVG_PRESERVEASPECTRATIO_XMINYMID,
        .get_SVG_PRESERVEASPECTRATIO_XMINYMIN = &get_SVG_PRESERVEASPECTRATIO_XMINYMIN,
        .get_align = &get_align,
        .get_meetOrSlice = &get_meetOrSlice,

        .set_align = &set_align,
        .set_meetOrSlice = &set_meetOrSlice,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SVGPreserveAspectRatioImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SVGPreserveAspectRatioImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_align(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return SVGPreserveAspectRatioImpl.get_align(state);
    }

    pub fn set_align(instance: *runtime.Instance, value: u16) void {
        const state = instance.getState(State);
        SVGPreserveAspectRatioImpl.set_align(state, value);
    }

    pub fn get_meetOrSlice(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return SVGPreserveAspectRatioImpl.get_meetOrSlice(state);
    }

    pub fn set_meetOrSlice(instance: *runtime.Instance, value: u16) void {
        const state = instance.getState(State);
        SVGPreserveAspectRatioImpl.set_meetOrSlice(state, value);
    }

};
