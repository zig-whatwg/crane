//! Generated from: cssom.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LinkStyleImpl = @import("impls").LinkStyle;
const StyleSheet = @import("interfaces").StyleSheet;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;

pub const LinkStyle = struct {
    pub const Meta = struct {
        pub const name = "LinkStyle";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            sheet: ?CSSStyleSheet = null,
            sheet: StyleSheet = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LinkStyle, .{
        .deinit_fn = &deinit_wrapper,

        .get_sheet = &get_sheet,
        .get_sheet = &get_sheet,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        LinkStyleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LinkStyleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sheet(instance: *runtime.Instance) anyerror!anyopaque {
        return try LinkStyleImpl.get_sheet(instance);
    }

    pub fn get_sheet(instance: *runtime.Instance) anyerror!StyleSheet {
        return try LinkStyleImpl.get_sheet(instance);
    }

};
