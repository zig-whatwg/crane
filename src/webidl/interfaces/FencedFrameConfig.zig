//! Generated from: fenced-frame.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FencedFrameConfigImpl = @import("impls").FencedFrameConfig;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const FencedFrameConfig = struct {
    pub const Meta = struct {
        pub const name = "FencedFrameConfig";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        struct {
            _internal: ?*FencedFrameConfigImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_setSharedStorageContext = &call_setSharedStorageContext,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FencedFrameConfigImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return FencedFrameConfigImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FencedFrameConfigImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, url: runtime.USVString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FencedFrameConfigImpl.call_constructor(ctx, url);
    }

    pub fn call_setSharedStorageContext(instance: *runtime.Instance, contextString: DOMString) anyerror!void {
        
        return try FencedFrameConfigImpl.call_setSharedStorageContext(instance, contextString);
    }

};
