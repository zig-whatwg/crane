//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLAllCollectionImpl = @import("impls").HTMLAllCollection;
const Element = @import("interfaces").Element;
const HTMLCollection = @import("interfaces").HTMLCollection;
const DOMString = @import("typedefs").DOMString;

pub const HTMLAllCollection = struct {
    pub const Meta = struct {
        pub const name = "HTMLAllCollection";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyUnenumerableNamedProperties" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HTMLAllCollection, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_item = &call_item,
        .call_namedItem = &call_namedItem,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return HTMLAllCollectionImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLAllCollectionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLAllCollectionImpl.get_length(instance);
    }

    pub fn call_item(instance: *runtime.Instance, nameOrIndex: DOMString) anyerror!anyopaque {
        
        return try HTMLAllCollectionImpl.call_item(instance, nameOrIndex);
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: DOMString) anyerror!anyopaque {
        
        return try HTMLAllCollectionImpl.call_namedItem(instance, name);
    }

};
