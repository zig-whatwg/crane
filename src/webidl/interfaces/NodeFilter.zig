//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NodeFilterImpl = @import("impls").NodeFilter;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("Node.zig").Node;

pub const NodeFilter = struct {
    pub const Meta = struct {
        pub const name = "NodeFilter";
        pub const is_mixin = false;
        pub const is_callback_interface = true;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "acceptNode", "call_acceptNode", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "acceptNode",
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*NodeFilterImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short FILTER_ACCEPT = 1;
    pub fn get_FILTER_ACCEPT() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short FILTER_REJECT = 2;
    pub fn get_FILTER_REJECT() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short FILTER_SKIP = 3;
    pub fn get_FILTER_SKIP() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned long SHOW_ALL = 4294967295;
    pub fn get_SHOW_ALL() u32 {
        return 4294967295;
    }

    /// WebIDL constant: const unsigned long SHOW_ELEMENT = 1;
    pub fn get_SHOW_ELEMENT() u32 {
        return 1;
    }

    /// WebIDL constant: const unsigned long SHOW_ATTRIBUTE = 2;
    pub fn get_SHOW_ATTRIBUTE() u32 {
        return 2;
    }

    /// WebIDL constant: const unsigned long SHOW_TEXT = 4;
    pub fn get_SHOW_TEXT() u32 {
        return 4;
    }

    /// WebIDL constant: const unsigned long SHOW_CDATA_SECTION = 8;
    pub fn get_SHOW_CDATA_SECTION() u32 {
        return 8;
    }

    /// WebIDL constant: const unsigned long SHOW_ENTITY_REFERENCE = 16;
    pub fn get_SHOW_ENTITY_REFERENCE() u32 {
        return 16;
    }

    /// WebIDL constant: const unsigned long SHOW_ENTITY = 32;
    pub fn get_SHOW_ENTITY() u32 {
        return 32;
    }

    /// WebIDL constant: const unsigned long SHOW_PROCESSING_INSTRUCTION = 64;
    pub fn get_SHOW_PROCESSING_INSTRUCTION() u32 {
        return 64;
    }

    /// WebIDL constant: const unsigned long SHOW_COMMENT = 128;
    pub fn get_SHOW_COMMENT() u32 {
        return 128;
    }

    /// WebIDL constant: const unsigned long SHOW_DOCUMENT = 256;
    pub fn get_SHOW_DOCUMENT() u32 {
        return 256;
    }

    /// WebIDL constant: const unsigned long SHOW_DOCUMENT_TYPE = 512;
    pub fn get_SHOW_DOCUMENT_TYPE() u32 {
        return 512;
    }

    /// WebIDL constant: const unsigned long SHOW_DOCUMENT_FRAGMENT = 1024;
    pub fn get_SHOW_DOCUMENT_FRAGMENT() u32 {
        return 1024;
    }

    /// WebIDL constant: const unsigned long SHOW_NOTATION = 2048;
    pub fn get_SHOW_NOTATION() u32 {
        return 2048;
    }

    const delegates = .{

        .get_FILTER_ACCEPT = &get_FILTER_ACCEPT,
        .get_FILTER_REJECT = &get_FILTER_REJECT,
        .get_FILTER_SKIP = &get_FILTER_SKIP,
        .get_SHOW_ALL = &get_SHOW_ALL,
        .get_SHOW_ATTRIBUTE = &get_SHOW_ATTRIBUTE,
        .get_SHOW_CDATA_SECTION = &get_SHOW_CDATA_SECTION,
        .get_SHOW_COMMENT = &get_SHOW_COMMENT,
        .get_SHOW_DOCUMENT = &get_SHOW_DOCUMENT,
        .get_SHOW_DOCUMENT_FRAGMENT = &get_SHOW_DOCUMENT_FRAGMENT,
        .get_SHOW_DOCUMENT_TYPE = &get_SHOW_DOCUMENT_TYPE,
        .get_SHOW_ELEMENT = &get_SHOW_ELEMENT,
        .get_SHOW_ENTITY = &get_SHOW_ENTITY,
        .get_SHOW_ENTITY_REFERENCE = &get_SHOW_ENTITY_REFERENCE,
        .get_SHOW_NOTATION = &get_SHOW_NOTATION,
        .get_SHOW_PROCESSING_INSTRUCTION = &get_SHOW_PROCESSING_INSTRUCTION,
        .get_SHOW_TEXT = &get_SHOW_TEXT,

        .call_acceptNode = &call_acceptNode,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NodeFilterImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return NodeFilterImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NodeFilterImpl.deinit(instance);
    }

    pub fn call_acceptNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!u16 {
        
        return try NodeFilterImpl.call_acceptNode(instance, node);
    }

};
