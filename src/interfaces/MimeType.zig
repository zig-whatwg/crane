//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MimeTypeImpl = @import("../impls/MimeType.zig");

pub const MimeType = struct {
    pub const Meta = struct {
        pub const name = "MimeType";
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
            type: runtime.DOMString = undefined,
            description: runtime.DOMString = undefined,
            suffixes: runtime.DOMString = undefined,
            enabledPlugin: Plugin = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MimeType, .{
        .deinit_fn = &deinit_wrapper,

        .get_description = &get_description,
        .get_enabledPlugin = &get_enabledPlugin,
        .get_suffixes = &get_suffixes,
        .get_type = &get_type,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MimeTypeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MimeTypeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MimeTypeImpl.get_type(state);
    }

    pub fn get_description(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MimeTypeImpl.get_description(state);
    }

    pub fn get_suffixes(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MimeTypeImpl.get_suffixes(state);
    }

    pub fn get_enabledPlugin(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MimeTypeImpl.get_enabledPlugin(state);
    }

};
