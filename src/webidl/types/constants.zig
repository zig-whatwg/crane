//! WebIDL Constants Support
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-constants
//!
//! Constants are compile-time values associated with an interface.
//! They are commonly used in legacy DOM APIs to represent enum-like values.
//!
//! # Usage
//!
//! ```zig
//! const constants = @import("constants.zig");
//!
//! pub const Node = struct {
//!     pub const ELEMENT_NODE = Constant(u16, 1);
//!     pub const ATTRIBUTE_NODE = Constant(u16, 2);
//!     pub const TEXT_NODE = Constant(u16, 3);
//! };
//!
//! // Usage:
//! if (node_type == Node.ELEMENT_NODE) {
//!     // ...
//! }
//! ```
//!
//! # Web Platform Examples
//!
//! ## Node Interface
//! ```webidl
//! interface Node {
//!   const unsigned short ELEMENT_NODE = 1;
//!   const unsigned short ATTRIBUTE_NODE = 2;
//!   const unsigned short TEXT_NODE = 3;
//!   const unsigned short CDATA_SECTION_NODE = 4;
//!   const unsigned short PROCESSING_INSTRUCTION_NODE = 7;
//!   const unsigned short COMMENT_NODE = 8;
//!   const unsigned short DOCUMENT_NODE = 9;
//!   const unsigned short DOCUMENT_TYPE_NODE = 10;
//!   const unsigned short DOCUMENT_FRAGMENT_NODE = 11;
//! };
//! ```
//!
//! ## XMLHttpRequest
//! ```webidl
//! interface XMLHttpRequest {
//!   const unsigned short UNSENT = 0;
//!   const unsigned short OPENED = 1;
//!   const unsigned short HEADERS_RECEIVED = 2;
//!   const unsigned short LOADING = 3;
//!   const unsigned short DONE = 4;
//! };
//! ```

const std = @import("std");

/// Constant represents a WebIDL constant value.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-constants
///
/// Constants are compile-time values that can be of any integer or floating-point type.
/// They are accessed directly as values, not through function calls.
///
/// Example:
/// ```zig
/// pub const EventPhase = struct {
///     pub const NONE = Constant(u16, 0);
///     pub const CAPTURING_PHASE = Constant(u16, 1);
///     pub const AT_TARGET = Constant(u16, 2);
///     pub const BUBBLING_PHASE = Constant(u16, 3);
/// };
///
/// // Usage:
/// if (phase == EventPhase.AT_TARGET) { }
/// ```
pub fn Constant(comptime T: type, comptime value: T) T {
    return value;
}

/// ConstantGroup is a helper for defining groups of constants
///
/// Note: In Zig, it's simpler to just define constants directly in a struct
/// rather than using a generic helper. This is kept for documentation purposes.
///
/// Recommended pattern:
/// ```zig
/// pub const NodeType = struct {
///     pub const ELEMENT_NODE: u16 = 1;
///     pub const ATTRIBUTE_NODE: u16 = 2;
///     pub const TEXT_NODE: u16 = 3;
/// };
/// ```
pub const ConstantGroupInfo = struct {
    pub const recommendation =
        \\For constant groups, directly define them in a struct:
        \\
        \\pub const MyConstants = struct {
        \\    pub const VALUE1: Type = value1;
        \\    pub const VALUE2: Type = value2;
        \\};
        \\
        \\This is clearer and more idiomatic in Zig than using a generic wrapper.
    ;
};

// ============================================================================
// Common WebIDL Constant Patterns
// ============================================================================

/// Node type constants (from DOM specification)
///
/// Spec: https://dom.spec.whatwg.org/#interface-node
pub const NodeType = struct {
    pub const ELEMENT_NODE: u16 = 1;
    pub const ATTRIBUTE_NODE: u16 = 2;
    pub const TEXT_NODE: u16 = 3;
    pub const CDATA_SECTION_NODE: u16 = 4;
    pub const PROCESSING_INSTRUCTION_NODE: u16 = 7;
    pub const COMMENT_NODE: u16 = 8;
    pub const DOCUMENT_NODE: u16 = 9;
    pub const DOCUMENT_TYPE_NODE: u16 = 10;
    pub const DOCUMENT_FRAGMENT_NODE: u16 = 11;
};

/// Document position constants (from DOM specification)
///
/// Spec: https://dom.spec.whatwg.org/#interface-node
pub const DocumentPosition = struct {
    pub const DISCONNECTED: u16 = 0x01;
    pub const PRECEDING: u16 = 0x02;
    pub const FOLLOWING: u16 = 0x04;
    pub const CONTAINS: u16 = 0x08;
    pub const CONTAINED_BY: u16 = 0x10;
    pub const IMPLEMENTATION_SPECIFIC: u16 = 0x20;
};

/// XMLHttpRequest ready state constants
///
/// Spec: https://xhr.spec.whatwg.org/#interface-xmlhttprequest
pub const XHRReadyState = struct {
    pub const UNSENT: u16 = 0;
    pub const OPENED: u16 = 1;
    pub const HEADERS_RECEIVED: u16 = 2;
    pub const LOADING: u16 = 3;
    pub const DONE: u16 = 4;
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "Constant - basic usage" {
    const value = Constant(u16, 42);
    try testing.expectEqual(@as(u16, 42), value);
}

test "Constant - in struct" {
    const MyConstants = struct {
        pub const VALUE1 = Constant(i32, 100);
        pub const VALUE2 = Constant(i32, 200);
    };

    try testing.expectEqual(@as(i32, 100), MyConstants.VALUE1);
    try testing.expectEqual(@as(i32, 200), MyConstants.VALUE2);
}

test "Constant - float values" {
    const MathConstants = struct {
        pub const PI = Constant(f64, 3.14159);
        pub const E = Constant(f64, 2.71828);
    };

    try testing.expectEqual(@as(f64, 3.14159), MathConstants.PI);
    try testing.expectEqual(@as(f64, 2.71828), MathConstants.E);
}

test "NodeType constants" {
    try testing.expectEqual(@as(u16, 1), NodeType.ELEMENT_NODE);
    try testing.expectEqual(@as(u16, 3), NodeType.TEXT_NODE);
    try testing.expectEqual(@as(u16, 9), NodeType.DOCUMENT_NODE);
}

test "DocumentPosition constants - bitflags" {
    try testing.expectEqual(@as(u16, 0x01), DocumentPosition.DISCONNECTED);
    try testing.expectEqual(@as(u16, 0x02), DocumentPosition.PRECEDING);
    try testing.expectEqual(@as(u16, 0x08), DocumentPosition.CONTAINS);
}

test "XHRReadyState constants" {
    try testing.expectEqual(@as(u16, 0), XHRReadyState.UNSENT);
    try testing.expectEqual(@as(u16, 1), XHRReadyState.OPENED);
    try testing.expectEqual(@as(u16, 4), XHRReadyState.DONE);
}

test "Constants - use in conditionals" {
    const node_type: u16 = 1;

    if (node_type == NodeType.ELEMENT_NODE) {
        try testing.expect(true);
    } else {
        try testing.expect(false);
    }
}

test "Constants - use in switch" {
    const node_type: u16 = 3;

    const result = switch (node_type) {
        NodeType.ELEMENT_NODE => "element",
        NodeType.TEXT_NODE => "text",
        NodeType.COMMENT_NODE => "comment",
        else => "other",
    };

    try testing.expectEqualStrings("text", result);
}

test "Constants - compile-time evaluation" {
    // Constants should be comptime-known
    comptime {
        const value = NodeType.ELEMENT_NODE;
        std.debug.assert(value == 1);
    }
}
