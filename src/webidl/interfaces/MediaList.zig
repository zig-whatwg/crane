//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaListImpl = @import("impls").MediaList;
const mixins = @import("mixins");
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const MediaList = struct {
    pub const Meta = struct {
        pub const name = "MediaList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "mediaText", "get_mediaText", "set_mediaText" },
            .{ "length", "get_length", null },
            .{ "mediaText", "get_mediaText", "set_mediaText" },
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "appendMedium", "call_appendMedium", 1 },
            .{ "deleteMedium", "call_deleteMedium", 1 },
            .{ "item", "call_item", 1 },
            .{ "deleteMedium", "call_deleteMedium", 1 },
            .{ "appendMedium", "call_appendMedium", 1 },
            .{ "toString", "get_mediaText", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "appendMedium",
            "deleteMedium",
            "item",
            "deleteMedium",
            "appendMedium",
            "toString",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mediaText", "get_mediaText", "set_mediaText" },
            .{ "length", "get_length", null },
            .{ "mediaText", "get_mediaText", "set_mediaText" },
            .{ "length", "get_length", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            mediaText: CSSOMString = undefined,
            length: u32 = undefined,
            _internal: ?*MediaListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,
        .get_mediaText = &get_mediaText,

        .set_mediaText = &set_mediaText,

        .call_appendMedium = &call_appendMedium,
        .call_deleteMedium = &call_deleteMedium,
        .call_item = &call_item,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MediaListImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaListImpl.deinit(instance);
    }

    /// Extended attributes: [Stringifier], [LegacyNullToEmptyString]
    pub fn get_mediaText(instance: *runtime.Instance) anyerror!CSSOMString {
        return try MediaListImpl.get_mediaText(instance);
    }

    /// Extended attributes: [Stringifier], [LegacyNullToEmptyString]
    pub fn set_mediaText(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try MediaListImpl.set_mediaText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try MediaListImpl.get_length(instance);
    }

    pub fn call_appendMedium(instance: *runtime.Instance, medium: CSSOMString) anyerror!void {
        
        return try MediaListImpl.call_appendMedium(instance, medium);
    }

    pub fn call_deleteMedium(instance: *runtime.Instance, medium: CSSOMString) anyerror!void {
        
        return try MediaListImpl.call_deleteMedium(instance, medium);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?CSSOMString {
        
        return try MediaListImpl.call_item(instance, index);
    }

};
