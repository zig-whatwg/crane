//! V8 Interface Bindings Registry
//!
//! This module provides centralized registration for all WebIDL interfaces.
//! It uses the V8Interface comptime generator to create bindings for all
//! generated interface structs.
//!
//! ## Usage
//!
//! ```zig
//! const interface_bindings = @import("v8/interface_bindings.zig");
//!
//! // Register all interfaces as global constructors
//! interface_bindings.registerAll(isolate, context);
//!
//! // Now JavaScript can use:
//! // const target = new EventTarget();
//! // const event = new Event('click');
//! // target.addEventListener('click', handler);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const V8Interface = @import("interface.zig").V8Interface;

// Import generated interfaces
const interfaces = @import("interfaces");

// ============================================================================
// Interface Bindings (Comptime Generated)
// ============================================================================

/// EventTarget V8 binding
pub const EventTarget = V8Interface(interfaces.EventTarget.EventTarget);

/// Event V8 binding
pub const Event = V8Interface(interfaces.Event.Event);

/// Node V8 binding
pub const Node = V8Interface(interfaces.Node.Node);

/// Element V8 binding
pub const Element = V8Interface(interfaces.Element.Element);

/// Document V8 binding
pub const Document = V8Interface(interfaces.Document.Document);

/// Window V8 binding
pub const Window = V8Interface(interfaces.Window.Window);

// Add more interfaces as needed...

// ============================================================================
// Registration
// ============================================================================

/// Register all core DOM interfaces in the global scope
///
/// This function registers the most commonly used DOM interfaces:
/// - EventTarget
/// - Event
/// - Node
/// - Element
/// - Document
/// - Window
///
/// Example JavaScript usage after initialization:
/// ```javascript
/// const target = new EventTarget();
/// const event = new Event('test');
/// target.dispatchEvent(event);
/// ```
pub fn registerCoreDOMInterfaces(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    // EventTarget is the base for all event-handling interfaces
    EventTarget.registerGlobal(isolate, context, "EventTarget");

    // Event is the base event object
    Event.registerGlobal(isolate, context, "Event");

    // Node is the base for all DOM nodes
    Node.registerGlobal(isolate, context, "Node");

    // Element represents HTML/XML elements
    Element.registerGlobal(isolate, context, "Element");

    // Document represents the document tree
    Document.registerGlobal(isolate, context, "Document");

    // Window is the global object in browsers
    Window.registerGlobal(isolate, context, "Window");
}

/// Register all interfaces (future: all 1240 interfaces)
///
/// Currently registers only core DOM interfaces.
/// In the future, this will register all generated interfaces.
pub fn registerAll(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    registerCoreDOMInterfaces(isolate, context);

    // Future: Iterate through all generated interfaces and register them
    // This could be done with comptime reflection over the interfaces module
}

// ============================================================================
// Metadata
// ============================================================================

/// Get list of all registered interfaces
pub fn getRegisteredInterfaces() []const InterfaceInfo {
    return &.{
        .{ .name = "EventTarget", .method_count = EventTarget.all_methods.len },
        .{ .name = "Event", .method_count = Event.all_methods.len },
        .{ .name = "Node", .method_count = Node.all_methods.len },
        .{ .name = "Element", .method_count = Element.all_methods.len },
        .{ .name = "Document", .method_count = Document.all_methods.len },
        .{ .name = "Window", .method_count = Window.all_methods.len },
    };
}

/// Information about a registered interface
pub const InterfaceInfo = struct {
    name: []const u8,
    method_count: usize,
};

// ============================================================================
// Testing
// ============================================================================

test "interface bindings module compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}

test "EventTarget binding has methods" {
    const testing = std.testing;

    // Verify EventTarget has methods extracted
    try testing.expect(EventTarget.all_methods.len > 0);

    // Check for known EventTarget methods
    var has_addEventListener = false;
    var has_removeEventListener = false;
    var has_dispatchEvent = false;

    for (EventTarget.all_methods) |method| {
        if (std.mem.eql(u8, method.name, "addEventListener")) has_addEventListener = true;
        if (std.mem.eql(u8, method.name, "removeEventListener")) has_removeEventListener = true;
        if (std.mem.eql(u8, method.name, "dispatchEvent")) has_dispatchEvent = true;
    }

    try testing.expect(has_addEventListener);
    try testing.expect(has_removeEventListener);
    try testing.expect(has_dispatchEvent);
}
