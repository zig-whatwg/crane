//! Generated from: dom.idl
//! Generated at: 2025-12-07T19:33:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const AbstractRangeImpl = @import("impls").AbstractRange;
const mixins = @import("mixins");
const Node = @import("interfaces").Node;

pub const AbstractRange = struct {
    pub const Meta = struct {
        pub const name = "AbstractRange";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "startContainer", "get_startContainer", null },
            .{ "startOffset", "get_startOffset", null },
            .{ "endContainer", "get_endContainer", null },
            .{ "endOffset", "get_endOffset", null },
            .{ "collapsed", "get_collapsed", null },
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
            .{ "startContainer", "get_startContainer", null },
            .{ "startOffset", "get_startOffset", null },
            .{ "endContainer", "get_endContainer", null },
            .{ "endOffset", "get_endOffset", null },
            .{ "collapsed", "get_collapsed", null },
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
            startContainer: *runtime.Instance = undefined,
            startOffset: u32 = undefined,
            endContainer: *runtime.Instance = undefined,
            endOffset: u32 = undefined,
            collapsed: bool = undefined,
            _internal: ?*AbstractRangeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_collapsed = &get_collapsed,
        .get_endContainer = &get_endContainer,
        .get_endOffset = &get_endOffset,
        .get_startContainer = &get_startContainer,
        .get_startOffset = &get_startOffset,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AbstractRangeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AbstractRangeImpl.deinit(instance);
    }

    pub fn get_startContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AbstractRangeImpl.get_startContainer(instance);
    }

    pub fn get_startOffset(instance: *runtime.Instance) anyerror!u32 {
        return try AbstractRangeImpl.get_startOffset(instance);
    }

    pub fn get_endContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AbstractRangeImpl.get_endContainer(instance);
    }

    pub fn get_endOffset(instance: *runtime.Instance) anyerror!u32 {
        return try AbstractRangeImpl.get_endOffset(instance);
    }

    pub fn get_collapsed(instance: *runtime.Instance) anyerror!bool {
        return try AbstractRangeImpl.get_collapsed(instance);
    }

};
