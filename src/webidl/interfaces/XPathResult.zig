//! Generated from: dom.idl
//! Generated at: 2025-11-23T20:06:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XPathResultImpl = @import("impls").XPathResult;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const XPathResult = struct {
    pub const Meta = struct {
        pub const name = "XPathResult";
        pub const is_mixin = false;
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
            .{ "resultType", "get_resultType", null },
            .{ "numberValue", "get_numberValue", null },
            .{ "stringValue", "get_stringValue", null },
            .{ "booleanValue", "get_booleanValue", null },
            .{ "singleNodeValue", "get_singleNodeValue", null },
            .{ "invalidIteratorState", "get_invalidIteratorState", null },
            .{ "snapshotLength", "get_snapshotLength", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "iterateNext", "call_iterateNext", 0 },
            .{ "snapshotItem", "call_snapshotItem", 1 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "ANY_TYPE", "get_ANY_TYPE" },
            .{ "NUMBER_TYPE", "get_NUMBER_TYPE" },
            .{ "STRING_TYPE", "get_STRING_TYPE" },
            .{ "BOOLEAN_TYPE", "get_BOOLEAN_TYPE" },
            .{ "UNORDERED_NODE_ITERATOR_TYPE", "get_UNORDERED_NODE_ITERATOR_TYPE" },
            .{ "ORDERED_NODE_ITERATOR_TYPE", "get_ORDERED_NODE_ITERATOR_TYPE" },
            .{ "UNORDERED_NODE_SNAPSHOT_TYPE", "get_UNORDERED_NODE_SNAPSHOT_TYPE" },
            .{ "ORDERED_NODE_SNAPSHOT_TYPE", "get_ORDERED_NODE_SNAPSHOT_TYPE" },
            .{ "ANY_UNORDERED_NODE_TYPE", "get_ANY_UNORDERED_NODE_TYPE" },
            .{ "FIRST_ORDERED_NODE_TYPE", "get_FIRST_ORDERED_NODE_TYPE" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "iterateNext",
            "snapshotItem",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "resultType", "get_resultType", null },
            .{ "numberValue", "get_numberValue", null },
            .{ "stringValue", "get_stringValue", null },
            .{ "booleanValue", "get_booleanValue", null },
            .{ "singleNodeValue", "get_singleNodeValue", null },
            .{ "invalidIteratorState", "get_invalidIteratorState", null },
            .{ "snapshotLength", "get_snapshotLength", null },
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
            resultType: u16 = undefined,
            numberValue: f64 = undefined,
            stringValue: runtime.DOMString = undefined,
            booleanValue: bool = undefined,
            singleNodeValue: ?*runtime.Instance = null,
            invalidIteratorState: bool = undefined,
            snapshotLength: u32 = undefined,
            _internal: ?*XPathResultImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short ANY_TYPE = 0;
    pub fn get_ANY_TYPE() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short NUMBER_TYPE = 1;
    pub fn get_NUMBER_TYPE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short STRING_TYPE = 2;
    pub fn get_STRING_TYPE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short BOOLEAN_TYPE = 3;
    pub fn get_BOOLEAN_TYPE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short UNORDERED_NODE_ITERATOR_TYPE = 4;
    pub fn get_UNORDERED_NODE_ITERATOR_TYPE() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short ORDERED_NODE_ITERATOR_TYPE = 5;
    pub fn get_ORDERED_NODE_ITERATOR_TYPE() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short UNORDERED_NODE_SNAPSHOT_TYPE = 6;
    pub fn get_UNORDERED_NODE_SNAPSHOT_TYPE() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short ORDERED_NODE_SNAPSHOT_TYPE = 7;
    pub fn get_ORDERED_NODE_SNAPSHOT_TYPE() u16 {
        return 7;
    }

    /// WebIDL constant: const unsigned short ANY_UNORDERED_NODE_TYPE = 8;
    pub fn get_ANY_UNORDERED_NODE_TYPE() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short FIRST_ORDERED_NODE_TYPE = 9;
    pub fn get_FIRST_ORDERED_NODE_TYPE() u16 {
        return 9;
    }

    const delegates = .{

        .get_ANY_TYPE = &get_ANY_TYPE,
        .get_ANY_UNORDERED_NODE_TYPE = &get_ANY_UNORDERED_NODE_TYPE,
        .get_BOOLEAN_TYPE = &get_BOOLEAN_TYPE,
        .get_FIRST_ORDERED_NODE_TYPE = &get_FIRST_ORDERED_NODE_TYPE,
        .get_NUMBER_TYPE = &get_NUMBER_TYPE,
        .get_ORDERED_NODE_ITERATOR_TYPE = &get_ORDERED_NODE_ITERATOR_TYPE,
        .get_ORDERED_NODE_SNAPSHOT_TYPE = &get_ORDERED_NODE_SNAPSHOT_TYPE,
        .get_STRING_TYPE = &get_STRING_TYPE,
        .get_UNORDERED_NODE_ITERATOR_TYPE = &get_UNORDERED_NODE_ITERATOR_TYPE,
        .get_UNORDERED_NODE_SNAPSHOT_TYPE = &get_UNORDERED_NODE_SNAPSHOT_TYPE,
        .get_booleanValue = &get_booleanValue,
        .get_invalidIteratorState = &get_invalidIteratorState,
        .get_numberValue = &get_numberValue,
        .get_resultType = &get_resultType,
        .get_singleNodeValue = &get_singleNodeValue,
        .get_snapshotLength = &get_snapshotLength,
        .get_stringValue = &get_stringValue,

        .call_iterateNext = &call_iterateNext,
        .call_snapshotItem = &call_snapshotItem,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XPathResultImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XPathResultImpl.deinit(instance);
    }

    pub fn get_resultType(instance: *runtime.Instance) anyerror!u16 {
        return try XPathResultImpl.get_resultType(instance);
    }

    pub fn get_numberValue(instance: *runtime.Instance) anyerror!f64 {
        return try XPathResultImpl.get_numberValue(instance);
    }

    pub fn get_stringValue(instance: *runtime.Instance) anyerror!DOMString {
        return try XPathResultImpl.get_stringValue(instance);
    }

    pub fn get_booleanValue(instance: *runtime.Instance) anyerror!bool {
        return try XPathResultImpl.get_booleanValue(instance);
    }

    pub fn get_singleNodeValue(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XPathResultImpl.get_singleNodeValue(instance);
    }

    pub fn get_invalidIteratorState(instance: *runtime.Instance) anyerror!bool {
        return try XPathResultImpl.get_invalidIteratorState(instance);
    }

    pub fn get_snapshotLength(instance: *runtime.Instance) anyerror!u32 {
        return try XPathResultImpl.get_snapshotLength(instance);
    }

    pub fn call_snapshotItem(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        
        return try XPathResultImpl.call_snapshotItem(instance, index);
    }

    pub fn call_iterateNext(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XPathResultImpl.call_iterateNext(instance);
    }

};
