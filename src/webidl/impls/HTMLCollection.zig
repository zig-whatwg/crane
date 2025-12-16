//! Implementation for HTMLCollection interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-htmlcollection
//! WHATWG DOM Standard §4.2.7
//!
//! An HTMLCollection is a live collection of elements. It's used for
//! document.getElementsByTagName, document.getElementsByClassName, etc.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const HTMLCollection = interfaces.HTMLCollection;

pub const State = HTMLCollection.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for HTMLCollection implementation
/// HTMLCollection is always a live collection that reflects DOM changes
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The list of elements
    elements: infra.List(*runtime.Instance),

    /// Root node for live collection updates
    root: ?*runtime.Instance = null,

    /// Filter function for matching elements (for getElementsByClassName, etc.)
    filter_tag: ?runtime.DOMString = null,
    filter_class: ?runtime.DOMString = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .elements = infra.List(*runtime.Instance).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.elements.deinit();
        if (self.filter_tag) |*tag| {
            tag.deinit(self.allocator);
        }
        if (self.filter_class) |*class| {
            class.deinit(self.allocator);
        }
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    // Initialize length to 0
    state.own.length = 0;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for length
/// Spec: https://dom.spec.whatwg.org/#dom-htmlcollection-length
/// Returns the number of elements in the collection.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return @intCast(internal.elements.size());
}

/// Operation: item(index)
/// Spec: https://dom.spec.whatwg.org/#dom-htmlcollection-item
/// Returns the element at the given index, or null if out of bounds.
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    // Return null for out of bounds per spec
    return internal.elements.get(index);
}

/// Operation: namedItem(name)
/// Spec: https://dom.spec.whatwg.org/#dom-htmlcollection-nameditem
/// Returns the first element with the given id or name attribute.
///
/// The namedItem(name) method steps are to return the first element in the
/// collection for which at least one of the following is true:
/// - it has an ID which is name;
/// - it is in the HTML namespace and has a name attribute whose value is name;
/// or null if there is no such element.
pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const name_slice = name.asSlice();

    // Empty name returns null
    if (name_slice.len == 0) return null;

    // Iterate through elements looking for matching id or name attribute
    const elements = internal.elements.toSlice();
    const Element = interfaces.Element;

    for (elements) |element| {
        // Check id attribute first
        var id = try Element.get_id(element);
        defer id.deinit(internal.allocator);
        if (std.mem.eql(u8, id.asSlice(), name_slice)) {
            return element;
        }

        // Check name attribute for HTML namespace elements
        // Per spec: "it is in the HTML namespace and has a name attribute whose value is name"
        var name_attr = Element.call_getAttribute(element, runtime.DOMString.initInterned("name")) catch null;
        if (name_attr) |*attr| {
            defer attr.deinit(internal.allocator);
            if (std.mem.eql(u8, attr.asSlice(), name_slice)) {
                return element;
            }
        }
    }

    return null;
}

// ============================================================================
// Internal helper functions (for DOM implementation)
// ============================================================================

/// Add an element to the collection
pub fn addElement(instance: *runtime.Instance, element: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    try internal.elements.append(element);

    // Update length in state
    const state = instance.getState(State);
    state.own.length = @intCast(internal.elements.size());
}

/// Clear all elements from the collection
pub fn clear(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.elements.clear();

    // Update length in state
    const state = instance.getState(State);
    state.own.length = 0;
}

/// Set the root for live collection updates
pub fn setRoot(instance: *runtime.Instance, root: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.root = root;
}

/// Get the elements as a slice (for iteration)
pub fn getElements(instance: *runtime.Instance) []const *runtime.Instance {
    const internal = getInternal(instance) orelse return &[_]*runtime.Instance{};
    return internal.elements.toSlice();
}

/// Get supported property names for named property enumeration
/// Per WebIDL spec §3.9.3, returns the id and name attributes of elements
///
/// The supported property names are the values of:
/// - id attribute of each element in tree order
/// - name attribute of each HTML namespace element in tree order
/// with earlier values taking precedence (no duplicates)
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    const internal = getInternal(instance) orelse return &[_]runtime.DOMString{};

    const elements = internal.elements.toSlice();
    if (elements.len == 0) return &[_]runtime.DOMString{};

    const Element = interfaces.Element;

    // Use ArrayList to collect unique names
    var names: std.ArrayListUnmanaged(runtime.DOMString) = .{};
    errdefer {
        for (names.items) |*n| n.deinit(allocator);
        names.deinit(allocator);
    }

    // Collect id and name attributes from elements in tree order
    for (elements) |element| {
        // Check id attribute
        var id = Element.get_id(element) catch continue;
        const id_slice = id.asSlice();
        if (id_slice.len > 0) {
            // Check if already in list
            var found = false;
            for (names.items) |existing| {
                if (std.mem.eql(u8, existing.asSlice(), id_slice)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                // Clone the id for our list
                const cloned = try runtime.DOMString.initDupe(allocator, id_slice);
                try names.append(allocator, cloned);
            }
        }
        id.deinit(internal.allocator);

        // Check name attribute for HTML namespace elements
        var name_attr = Element.call_getAttribute(element, runtime.DOMString.initInterned("name")) catch null;
        if (name_attr) |*attr| {
            defer attr.deinit(internal.allocator);
            const attr_slice = attr.asSlice();
            if (attr_slice.len > 0) {
                // Check if already in list
                var found = false;
                for (names.items) |existing| {
                    if (std.mem.eql(u8, existing.asSlice(), attr_slice)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    const cloned = try runtime.DOMString.initDupe(allocator, attr_slice);
                    try names.append(allocator, cloned);
                }
            }
        }
    }

    return names.toOwnedSlice(allocator);
}
