//! Generated from: css-font-loading.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontFacePaletteImpl = @import("impls").FontFacePalette;

pub const FontFacePalette = struct {
    pub const Meta = struct {
        pub const name = "FontFacePalette";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
            usableWithLightBackground: bool = undefined,
            usableWithDarkBackground: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FontFacePalette, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_usableWithDarkBackground = &get_usableWithDarkBackground,
        .get_usableWithLightBackground = &get_usableWithLightBackground,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        FontFacePaletteImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontFacePaletteImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try FontFacePaletteImpl.get_length(instance);
    }

    pub fn get_usableWithLightBackground(instance: *runtime.Instance) anyerror!bool {
        return try FontFacePaletteImpl.get_usableWithLightBackground(instance);
    }

    pub fn get_usableWithDarkBackground(instance: *runtime.Instance) anyerror!bool {
        return try FontFacePaletteImpl.get_usableWithDarkBackground(instance);
    }

};
