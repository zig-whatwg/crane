//! Generated from: css-font-loading.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontFaceSourceImpl = @import("../impls/FontFaceSource.zig");

pub const FontFaceSource = struct {
    pub const Meta = struct {
        pub const name = "FontFaceSource";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            fonts: FontFaceSet = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FontFaceSource, .{
        .deinit_fn = &deinit_wrapper,

        .get_fonts = &get_fonts,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FontFaceSourceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FontFaceSourceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceSourceImpl.get_fonts(state);
    }

};
