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

    // Set up constructor inheritance chain
    // In browsers, child constructors have their __proto__ set to parent constructors
    // Example: Element.__proto__ === Node, Node.__proto__ === EventTarget
    setupConstructorInheritance(isolate, context);
}

/// Set up constructor inheritance chain after all constructors are registered
///
/// This automatically sets the __proto__ of child constructors to parent constructors
/// based on each interface's Meta.BaseType field.
///
/// For example:
/// - Element.__proto__ = Node (because Element.Meta.BaseType = Node)
/// - Node.__proto__ = EventTarget (because Node.Meta.BaseType = EventTarget)
/// - HTMLElement.__proto__ = Element (because HTMLElement.Meta.BaseType = Element)
///
/// This matches browser behavior where constructors inherit from each other.
pub fn setupConstructorInheritance(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    const global = v8.v8_Context_Global(context);

    // Helper to get a global constructor
    const GetConstructor = struct {
        fn call(iso: *v8.Isolate, global_obj: *v8.Object, ctx: *v8.Context, name: []const u8) ?*v8.Object {
            const key = v8.v8_String_NewFromUtf8(
                iso,
                name.ptr,
                @intCast(name.len),
            ) orelse return null;

            const value = v8.v8_Object_Get(global_obj, ctx, @ptrCast(key));
            if (value == null) return null;

            // Cast to Object (constructors are Function objects, which are Objects)
            return @ptrCast(@alignCast(value));
        }
    };

    // Helper to set __proto__ on an object
    const setProto = struct {
        fn set(child: *v8.Object, parent: *v8.Object, ctx: *v8.Context) void {
            // Use V8's SetPrototype method
            // This is equivalent to Object.setPrototypeOf(child, parent) in JavaScript
            _ = v8.v8_Object_SetPrototype(child, ctx, @ptrCast(parent));
        }
    }.set;

    // Automatically set up inheritance chain for all interfaces
    // Iterate over all interface declarations and set Constructor.__proto__ based on Meta.BaseType
    //
    // Note: We skip interfaces with broken dependencies (e.g., ViewCSS → AbstractView)
    // This is acceptable because those interfaces likely aren't registered anyway.
    @setEvalBranchQuota(10000); // Increase quota for large number of interfaces

    // List of interfaces to skip due to missing dependencies or other issues
    const skip_list = [_][]const u8{
        "ViewCSS", // References missing AbstractView
        "AbstractView", // Missing implementation
        // Add other problematic interfaces here as needed
    };

    const decls = @typeInfo(interfaces).@"struct".decls;

    inline for (decls) |decl| {
        // Skip problematic interfaces
        const should_skip = comptime blk: {
            for (skip_list) |skip| {
                if (std.mem.eql(u8, decl.name, skip)) break :blk true;
            }
            break :blk false;
        };
        if (should_skip) continue;

        const InterfaceType = @field(interfaces, decl.name);

        // Only process types that have Meta (actual interfaces)
        if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
            // Skip mixins - they don't have constructors
            const is_mixin = comptime blk: {
                const Meta = InterfaceType.Meta;
                if (@hasDecl(Meta, "is_mixin")) {
                    break :blk Meta.is_mixin;
                }
                break :blk false;
            };
            if (is_mixin) continue;

            // Check if this interface has a parent (ParentInterface)
            // ParentInterface is the actual interface type (e.g., Node), while
            // BaseType is the state type (e.g., Node.State). We need ParentInterface
            // to get the interface name for constructor prototype chain setup.
            const has_parent = comptime @hasDecl(InterfaceType.Meta, "ParentInterface");

            if (has_parent) {
                const ParentTypeRaw = InterfaceType.Meta.ParentInterface;

                // Dereference pointer types (*Element -> Element)
                const ParentType = comptime blk: {
                    const type_info = @typeInfo(ParentTypeRaw);
                    if (type_info == .pointer) {
                        break :blk type_info.pointer.child;
                    }
                    break :blk ParentTypeRaw;
                };

                // Only proceed if ParentType is an actual interface (struct type)
                // Some interfaces have ParentInterface = ?*anyopaque which means no parent
                const parent_is_interface = comptime blk: {
                    const type_info = @typeInfo(ParentType);
                    if (type_info != .@"struct") break :blk false;
                    if (!@hasDecl(ParentType, "Meta")) break :blk false;
                    break :blk true;
                };

                if (parent_is_interface) {
                    // Get parent interface name from its Meta.name field
                    const parent_name = comptime ParentType.Meta.name;

                    // Set child.__proto__ = parent
                    if (GetConstructor.call(isolate, global.?, context, decl.name)) |child_ctor| {
                        if (GetConstructor.call(isolate, global.?, context, parent_name)) |parent_ctor| {
                            setProto(child_ctor, parent_ctor, context);
                        }
                    }
                }
            }
        }
    }
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
