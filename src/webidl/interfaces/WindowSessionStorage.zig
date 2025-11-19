//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowSessionStorageImpl = @import("impls").WindowSessionStorage;
const Storage = @import("interfaces").Storage;

pub const WindowSessionStorage = struct {
    pub const Meta = struct {
        pub const name = "WindowSessionStorage";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            sessionStorage: Storage = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WindowSessionStorage, .{
        .deinit_fn = &deinit_wrapper,

        .get_sessionStorage = &get_sessionStorage,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return WindowSessionStorageImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowSessionStorageImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sessionStorage(instance: *runtime.Instance) anyerror!Storage {
        return try WindowSessionStorageImpl.get_sessionStorage(instance);
    }

};
