//! Generated from: local-font-access.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontDataImpl = @import("impls").FontData;
const Promise<Blob> = @import("interfaces").Promise<Blob>;

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
        
        // Initialize the instance (Impl receives full instance)
        FontDataImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontDataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_postscriptName(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_postscriptName(instance);
    }

    pub fn get_fullName(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_fullName(instance);
    }

    pub fn get_family(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_family(instance);
    }

    pub fn get_style(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_style(instance);
    }

    pub fn call_blob(instance: *runtime.Instance) anyerror!anyopaque {
        return try FontDataImpl.call_blob(instance);
    }

};
