//! Generated from: SVG.idl
//! Generated at: 2025-11-28T22:33:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GetSVGDocumentImpl = @import("impls").GetSVGDocument;
const mixins = @import("mixins");
const Document = @import("interfaces").Document;

pub const GetSVGDocument = struct {
    pub const Meta = struct {
        pub const name = "GetSVGDocument";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getSVGDocument", "call_getSVGDocument", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getSVGDocument",
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*GetSVGDocumentImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getSVGDocument = &call_getSVGDocument,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GetSVGDocumentImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GetSVGDocumentImpl.deinit(instance);
    }

    pub fn call_getSVGDocument(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try GetSVGDocumentImpl.call_getSVGDocument(instance);
    }

};
