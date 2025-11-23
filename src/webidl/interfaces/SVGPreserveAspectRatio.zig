//! Generated from: SVG.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGPreserveAspectRatioImpl = @import("impls").SVGPreserveAspectRatio;

pub const SVGPreserveAspectRatio = struct {
    pub const Meta = struct {
        pub const name = "SVGPreserveAspectRatio";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "align", "get_align", "set_align" },
            .{ "meetOrSlice", "get_meetOrSlice", "set_meetOrSlice" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "SVG_PRESERVEASPECTRATIO_UNKNOWN", "get_SVG_PRESERVEASPECTRATIO_UNKNOWN" },
            .{ "SVG_PRESERVEASPECTRATIO_NONE", "get_SVG_PRESERVEASPECTRATIO_NONE" },
            .{ "SVG_PRESERVEASPECTRATIO_XMINYMIN", "get_SVG_PRESERVEASPECTRATIO_XMINYMIN" },
            .{ "SVG_PRESERVEASPECTRATIO_XMIDYMIN", "get_SVG_PRESERVEASPECTRATIO_XMIDYMIN" },
            .{ "SVG_PRESERVEASPECTRATIO_XMAXYMIN", "get_SVG_PRESERVEASPECTRATIO_XMAXYMIN" },
            .{ "SVG_PRESERVEASPECTRATIO_XMINYMID", "get_SVG_PRESERVEASPECTRATIO_XMINYMID" },
            .{ "SVG_PRESERVEASPECTRATIO_XMIDYMID", "get_SVG_PRESERVEASPECTRATIO_XMIDYMID" },
            .{ "SVG_PRESERVEASPECTRATIO_XMAXYMID", "get_SVG_PRESERVEASPECTRATIO_XMAXYMID" },
            .{ "SVG_PRESERVEASPECTRATIO_XMINYMAX", "get_SVG_PRESERVEASPECTRATIO_XMINYMAX" },
            .{ "SVG_PRESERVEASPECTRATIO_XMIDYMAX", "get_SVG_PRESERVEASPECTRATIO_XMIDYMAX" },
            .{ "SVG_PRESERVEASPECTRATIO_XMAXYMAX", "get_SVG_PRESERVEASPECTRATIO_XMAXYMAX" },
            .{ "SVG_MEETORSLICE_UNKNOWN", "get_SVG_MEETORSLICE_UNKNOWN" },
            .{ "SVG_MEETORSLICE_MEET", "get_SVG_MEETORSLICE_MEET" },
            .{ "SVG_MEETORSLICE_SLICE", "get_SVG_MEETORSLICE_SLICE" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "align", "get_align", "set_align" },
            .{ "meetOrSlice", "get_meetOrSlice", "set_meetOrSlice" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            @"align": u16 = undefined,
            meetOrSlice: u16 = undefined,
            _internal: ?*SVGPreserveAspectRatioImpl.InternalState = null,
        },
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

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGPreserveAspectRatioImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGPreserveAspectRatioImpl.deinit(instance);
    }

    pub fn get_align(instance: *runtime.Instance) anyerror!u16 {
        return try SVGPreserveAspectRatioImpl.get_align(instance);
    }

    pub fn set_align(instance: *runtime.Instance, value: u16) anyerror!void {
        try SVGPreserveAspectRatioImpl.set_align(instance, value);
    }

    pub fn get_meetOrSlice(instance: *runtime.Instance) anyerror!u16 {
        return try SVGPreserveAspectRatioImpl.get_meetOrSlice(instance);
    }

    pub fn set_meetOrSlice(instance: *runtime.Instance, value: u16) anyerror!void {
        try SVGPreserveAspectRatioImpl.set_meetOrSlice(instance, value);
    }

};
