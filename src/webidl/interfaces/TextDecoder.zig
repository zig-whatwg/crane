//! Generated from: encoding.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextDecoderImpl = @import("impls").TextDecoder;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const TextDecoderCommon = @import("mixins").TextDecoderCommon;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const TextDecoderOptions = @import("dictionaries").TextDecoderOptions;
const TextDecodeOptions = @import("dictionaries").TextDecodeOptions;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const TextDecoder = struct {
    pub const Meta = struct {
        pub const name = "TextDecoder";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            TextDecoderCommon,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "encoding", "get_encoding", null },
            .{ "fatal", "get_fatal", null },
            .{ "ignoreBOM", "get_ignoreBOM", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "decode", "call_decode", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "decode",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "encoding", "get_encoding", null },
            .{ "fatal", "get_fatal", null },
            .{ "ignoreBOM", "get_ignoreBOM", null },
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
            fatal: bool = undefined,
            ignoreBOM: bool = undefined,
            _internal: ?*TextDecoderImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_encoding = &get_encoding,
        .get_fatal = &get_fatal,
        .get_ignoreBOM = &get_ignoreBOM,

        .call_decode = &call_decode,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextDecoderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return TextDecoderImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextDecoderImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, label: webidl.Opt(DOMString), options: webidl.Opt(TextDecoderOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextDecoderImpl.call_constructor(ctx, label, options);
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
        return try TextDecoderImpl.get_encoding(instance);
    }

    pub fn get_fatal(instance: *runtime.Instance) anyerror!bool {
        return try TextDecoderImpl.get_fatal(instance);
    }

    pub fn get_ignoreBOM(instance: *runtime.Instance) anyerror!bool {
        return try TextDecoderImpl.get_ignoreBOM(instance);
    }

    pub fn call_decode(instance: *runtime.Instance, input: webidl.Opt(AllowSharedBufferSource), options: webidl.Opt(TextDecodeOptions)) anyerror!runtime.USVString {
        
        return try TextDecoderImpl.call_decode(instance, input, options);
    }

};
