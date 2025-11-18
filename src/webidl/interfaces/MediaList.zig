//! Generated from: cssom.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaListImpl = @import("impls").MediaList;
const CSSOMString = @import("interfaces").CSSOMString;

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
        .call_deleteMedium = &call_deleteMedium,
        .call_item = &call_item,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        MediaListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_mediaText(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaListImpl.get_mediaText(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_mediaText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try MediaListImpl.set_mediaText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try MediaListImpl.get_length(instance);
    }

    pub fn get_mediaText(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaListImpl.get_mediaText(instance);
    }

    pub fn set_mediaText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try MediaListImpl.set_mediaText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try MediaListImpl.get_length(instance);
    }

    /// Arguments for item (WebIDL overloading)
    pub const ItemArgs = union(enum) {
        /// item(index)
        long: u32,
        /// item(index)
        long: u32,
    };

    pub fn call_item(instance: *runtime.Instance, args: ItemArgs) anyerror!anyopaque {
        switch (args) {
            .long => |arg| return try MediaListImpl.long(instance, arg),
            .long => |arg| return try MediaListImpl.long(instance, arg),
        }
    }

    /// Arguments for deleteMedium (WebIDL overloading)
    pub const DeleteMediumArgs = union(enum) {
        /// deleteMedium(medium)
        CSSOMString: anyopaque,
        /// deleteMedium(oldMedium)
        string: DOMString,
    };

    pub fn call_deleteMedium(instance: *runtime.Instance, args: DeleteMediumArgs) anyerror!void {
        switch (args) {
            .CSSOMString => |arg| return try MediaListImpl.CSSOMString(instance, arg),
            .string => |arg| return try MediaListImpl.string(instance, arg),
        }
    }

    /// Arguments for appendMedium (WebIDL overloading)
    pub const AppendMediumArgs = union(enum) {
        /// appendMedium(medium)
        CSSOMString: anyopaque,
        /// appendMedium(newMedium)
        string: DOMString,
    };

    pub fn call_appendMedium(instance: *runtime.Instance, args: AppendMediumArgs) anyerror!void {
        switch (args) {
            .CSSOMString => |arg| return try MediaListImpl.CSSOMString(instance, arg),
            .string => |arg| return try MediaListImpl.string(instance, arg),
        }
    }

};
