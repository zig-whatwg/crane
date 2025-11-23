//! Generated from: fenced-frame.idl
//! Generated at: 2025-11-23T20:06:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FencedFrameConfigImpl = @import("impls").FencedFrameConfig;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const FencedFrameConfig = struct {
    pub const Meta = struct {
        pub const name = "FencedFrameConfig";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "setSharedStorageContext", "call_setSharedStorageContext", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setSharedStorageContext",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_setSharedStorageContext = &call_setSharedStorageContext,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FencedFrameConfigImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FencedFrameConfigImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, url: runtime.USVString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FencedFrameConfigImpl.call_constructor(allocator, ctx, url);
    }

    pub fn call_setSharedStorageContext(instance: *runtime.Instance, contextString: DOMString) anyerror!void {
        
        return try FencedFrameConfigImpl.call_setSharedStorageContext(instance, contextString);
    }

};
