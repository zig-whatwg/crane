//! Generated from: json-ld-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RemoteDocumentImpl = @import("impls").RemoteDocument;
const mixins = @import("mixins");
const USVString = @import("interfaces").USVString;

pub const RemoteDocument = struct {
    pub const Meta = struct {
        pub const name = "RemoteDocument";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "JsonLd" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .JsonLd = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "contentType", "get_contentType", null },
            .{ "contextUrl", "get_contextUrl", null },
            .{ "document", "get_document", "set_document" },
            .{ "documentUrl", "get_documentUrl", null },
            .{ "profile", "get_profile", null },
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
            .{ "contentType", "get_contentType", null },
            .{ "contextUrl", "get_contextUrl", null },
            .{ "document", "get_document", "set_document" },
            .{ "documentUrl", "get_documentUrl", null },
            .{ "profile", "get_profile", null },
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
            contentType: runtime.USVString = undefined,
            contextUrl: runtime.USVString = undefined,
            document: runtime.JSValue = undefined,
            documentUrl: runtime.USVString = undefined,
            profile: runtime.USVString = undefined,
            _internal: ?*RemoteDocumentImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_contentType = &get_contentType,
        .get_contextUrl = &get_contextUrl,
        .get_document = &get_document,
        .get_documentUrl = &get_documentUrl,
        .get_profile = &get_profile,

        .set_document = &set_document,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RemoteDocumentImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return RemoteDocumentImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RemoteDocumentImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RemoteDocumentImpl.call_constructor(ctx);
    }

    pub fn get_contentType(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RemoteDocumentImpl.get_contentType(instance);
    }

    pub fn get_contextUrl(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RemoteDocumentImpl.get_contextUrl(instance);
    }

    pub fn get_document(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RemoteDocumentImpl.get_document(instance);
    }

    pub fn set_document(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try RemoteDocumentImpl.set_document(instance, value);
    }

    pub fn get_documentUrl(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RemoteDocumentImpl.get_documentUrl(instance);
    }

    pub fn get_profile(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RemoteDocumentImpl.get_profile(instance);
    }

};
