//! Generated from: shared-storage.idl
//! Generated at: 2025-11-28T19:11:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLSharedStorageWritableElementUtilsImpl = @import("impls").HTMLSharedStorageWritableElementUtils;
const mixins = @import("mixins");

pub const HTMLSharedStorageWritableElementUtils = struct {
    pub const Meta = struct {
        pub const name = "HTMLSharedStorageWritableElementUtils";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sharedStorageWritable", "get_sharedStorageWritable", "set_sharedStorageWritable" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sharedStorageWritable", "get_sharedStorageWritable", "set_sharedStorageWritable" },
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
            sharedStorageWritable: bool = undefined,
            _internal: ?*HTMLSharedStorageWritableElementUtilsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_sharedStorageWritable = &get_sharedStorageWritable,

        .set_sharedStorageWritable = &set_sharedStorageWritable,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLSharedStorageWritableElementUtilsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLSharedStorageWritableElementUtilsImpl.deinit(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn get_sharedStorageWritable(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSharedStorageWritableElementUtilsImpl.get_sharedStorageWritable(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn set_sharedStorageWritable(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLSharedStorageWritableElementUtilsImpl.set_sharedStorageWritable(instance, value);
    }

};
