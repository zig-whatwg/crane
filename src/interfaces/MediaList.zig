//! Generated from: cssom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaListImpl = @import("../impls/MediaList.zig");

pub const MediaList = struct {
    pub const Meta = struct {
        pub const name = "MediaList";
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
            mediaText: CSSOMString = undefined,
            length: u32 = undefined,
            mediaText: runtime.DOMString = undefined,
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_length = &get_length,
        .get_mediaText = &get_mediaText,
        .get_mediaText = &get_mediaText,

        .set_mediaText = &set_mediaText,
        .set_mediaText = &set_mediaText,

        .call_appendMedium = &call_appendMedium,
        .call_appendMedium = &call_appendMedium,
        .call_deleteMedium = &call_deleteMedium,
        .call_deleteMedium = &call_deleteMedium,
        .call_item = &call_item,
        .call_item = &call_item,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MediaListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_mediaText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaListImpl.get_mediaText(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_mediaText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaListImpl.set_mediaText(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return MediaListImpl.get_length(state);
    }

    pub fn get_mediaText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaListImpl.get_mediaText(state);
    }

    pub fn set_mediaText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        MediaListImpl.set_mediaText(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return MediaListImpl.get_length(state);
    }

    /// Arguments for item (WebIDL overloading)
    pub const ItemArgs = union(enum) {
        /// item(index)
        long: u32,
        /// item(index)
        long: u32,
    };

    pub fn call_item(instance: *runtime.Instance, args: ItemArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .long => |arg| return MediaListImpl.long(state, arg),
            .long => |arg| return MediaListImpl.long(state, arg),
        }
    }

    /// Arguments for deleteMedium (WebIDL overloading)
    pub const DeleteMediumArgs = union(enum) {
        /// deleteMedium(medium)
        CSSOMString: anyopaque,
        /// deleteMedium(oldMedium)
        string: runtime.DOMString,
    };

    pub fn call_deleteMedium(instance: *runtime.Instance, args: DeleteMediumArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return MediaListImpl.CSSOMString(state, arg),
            .string => |arg| return MediaListImpl.string(state, arg),
        }
    }

    /// Arguments for appendMedium (WebIDL overloading)
    pub const AppendMediumArgs = union(enum) {
        /// appendMedium(medium)
        CSSOMString: anyopaque,
        /// appendMedium(newMedium)
        string: runtime.DOMString,
    };

    pub fn call_appendMedium(instance: *runtime.Instance, args: AppendMediumArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return MediaListImpl.CSSOMString(state, arg),
            .string => |arg| return MediaListImpl.string(state, arg),
        }
    }

};
