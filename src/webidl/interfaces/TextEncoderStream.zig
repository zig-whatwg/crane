//! Generated from: encoding.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextEncoderStreamImpl = @import("impls").TextEncoderStream;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const TextEncoderCommon = @import("mixins").TextEncoderCommon;
const GenericTransformStream = @import("mixins").GenericTransformStream;
const ReadableStream = @import("ReadableStream.zig").ReadableStream;
const WritableStream = @import("WritableStream.zig").WritableStream;
const DOMString = @import("typedefs").DOMString;

pub const TextEncoderStream = struct {
    pub const Meta = struct {
        pub const name = "TextEncoderStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            TextEncoderCommon,
            GenericTransformStream,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "encoding", "get_encoding", null },
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
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
            .{ "encoding", "get_encoding", null },
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            encoding: typedefs.DOMString = undefined,
            readable: *runtime.Instance = undefined,
            writable: *runtime.Instance = undefined,
            _internal: ?*TextEncoderStreamImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_encoding = &get_encoding,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextEncoderStreamImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return TextEncoderStreamImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextEncoderStreamImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextEncoderStreamImpl.call_constructor(ctx);
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
        return try TextEncoderStreamImpl.get_encoding(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TextEncoderStreamImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TextEncoderStreamImpl.get_writable(instance);
    }

};
