//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLFormControlsCollectionImpl = @import("../impls/HTMLFormControlsCollection.zig");
const HTMLCollection = @import("HTMLCollection.zig");

pub const HTMLFormControlsCollection = struct {
    pub const Meta = struct {
        pub const name = "HTMLFormControlsCollection";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLCollection;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HTMLFormControlsCollection, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_item = &call_item,
        .call_namedItem = &call_namedItem,
        .call_namedItem = &call_namedItem,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        HTMLFormControlsCollectionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HTMLFormControlsCollectionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return HTMLFormControlsCollectionImpl.get_length(state);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return HTMLFormControlsCollectionImpl.call_item(state, index);
    }

    /// Arguments for namedItem (WebIDL overloading)
    pub const NamedItemArgs = union(enum) {
        /// namedItem(name)
        string: runtime.DOMString,
        /// namedItem(name)
        string: runtime.DOMString,
    };

    pub fn call_namedItem(instance: *runtime.Instance, args: NamedItemArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .string => |arg| return HTMLFormControlsCollectionImpl.string(state, arg),
            .string => |arg| return HTMLFormControlsCollectionImpl.string(state, arg),
        }
    }

};
