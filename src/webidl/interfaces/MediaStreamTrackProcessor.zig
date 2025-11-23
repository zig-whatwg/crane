//! Generated from: mediacapture-transform.idl
//! Generated at: 2025-11-23T16:59:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaStreamTrackProcessorImpl = @import("impls").MediaStreamTrackProcessor;
const MediaStreamTrackProcessorInit = @import("dictionaries").MediaStreamTrackProcessorInit;
const ReadableStream = @import("interfaces").ReadableStream;

pub const MediaStreamTrackProcessor = struct {
    pub const Meta = struct {
        pub const name = "MediaStreamTrackProcessor";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "readable", "get_readable", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "readable", "get_readable", null },
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
            readable: ReadableStream = undefined,
            _internal: ?*MediaStreamTrackProcessorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_readable = &get_readable,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaStreamTrackProcessorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaStreamTrackProcessorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: MediaStreamTrackProcessorInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaStreamTrackProcessorImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!ReadableStream {
        return try MediaStreamTrackProcessorImpl.get_readable(instance);
    }

};
