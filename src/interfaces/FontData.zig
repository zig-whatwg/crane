//! Generated from: local-font-access.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontDataImpl = @import("../impls/FontData.zig");

pub const FontData = struct {
    pub const Meta = struct {
        pub const name = "FontData";
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
            postscriptName: runtime.USVString = undefined,
            fullName: runtime.USVString = undefined,
            family: runtime.USVString = undefined,
            style: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FontData, .{
        .deinit_fn = &deinit_wrapper,

        .get_family = &get_family,
        .get_fullName = &get_fullName,
        .get_postscriptName = &get_postscriptName,
        .get_style = &get_style,

        .call_blob = &call_blob,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FontDataImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FontDataImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_postscriptName(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FontDataImpl.get_postscriptName(state);
    }

    pub fn get_fullName(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FontDataImpl.get_fullName(state);
    }

    pub fn get_family(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FontDataImpl.get_family(state);
    }

    pub fn get_style(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FontDataImpl.get_style(state);
    }

    pub fn call_blob(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontDataImpl.call_blob(state);
    }

};
