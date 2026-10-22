//! Implementation for DOMStringMap interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DOMStringMap = interfaces.DOMStringMap;

pub const State = DOMStringMap.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    element: *runtime.Instance,

    pub fn init(allocator: std.mem.Allocator, element: *runtime.Instance) InternalState {
        return .{
            .allocator = allocator,
            .element = element,
        };
    }
};

/// Get internal state from instance
const utils = @import("webidl").utils;
const Registry = runtime.InstanceRegistry(.dom_string_map, InternalState);

pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
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

    return instance;
}

/// Factory for DOMStringMap
pub fn create(allocator: std.mem.Allocator, ctx: runtime.Context, element: *runtime.Instance) !*runtime.Instance {
    const instance = try init(allocator, State, &DOMStringMap.vtable, ctx);
    errdefer deinit(instance);

    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator, element);
    try Registry.set(instance, internal);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    if (Registry.get(instance)) |internal| {
        internal.allocator.destroy(internal);
    }
    Registry.remove(instance);
}

/// Get supported property names for named property enumeration.
/// Per HTML spec §2.4.2.4: data-* attributes converted to camelCase.
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    const internal = getInternalState(instance) orelse return &[_]runtime.DOMString{};
    const elem_internal = @import("dom").element_data.of(internal.element) orelse return &[_]runtime.DOMString{};

    var names: std.ArrayListUnmanaged(runtime.DOMString) = .empty;
    errdefer {
        for (names.items) |*n| n.deinit(allocator);
        names.deinit(allocator);
    }

    var iter = elem_internal.attributeIterator();
    while (iter.next()) |entry| {
        const local_name = entry.local_name;
        // Check if attribute name starts with "data-" and contains no uppercase letters
        if (std.mem.startsWith(u8, local_name, "data-")) {
            var has_uppercase = false;
            for (local_name) |c| {
                if (std.ascii.isUpper(c)) {
                    has_uppercase = true;
                    break;
                }
            }
            if (has_uppercase) continue;

            // Remove "data-" prefix
            const name = local_name[5..];

            // Convert to camelCase
            // Spec: "If name does not contain a hyphen followed by a lowercase, append name.
            // Otherwise, convert to camelCase."
            const camel_name = try toCamelCase(allocator, name);
            const dom_str = runtime.DOMString.initOwned(camel_name);
            try names.append(allocator, dom_str);
        }
    }

    return names.toOwnedSlice(allocator);
}

fn toCamelCase(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var i: usize = 0;
    while (i < name.len) {
        if (name[i] == '-' and i + 1 < name.len and std.ascii.isLower(name[i + 1])) {
            try result.append(allocator, std.ascii.toUpper(name[i + 1]));
            i += 2;
        } else {
            try result.append(allocator, name[i]);
            i += 1;
        }
    }
    return result.toOwnedSlice(allocator);
}

/// Convert camelCase name to hyphenated attribute name (data-*)
fn toHyphenated(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    // Prefix with "data-"
    try result.appendSlice(allocator, "data-");

    for (name) |c| {
        if (std.ascii.isUpper(c)) {
            try result.append(allocator, '-');
            try result.append(allocator, std.ascii.toLower(c));
        } else {
            try result.append(allocator, c);
        }
    }
    return result.toOwnedSlice(allocator);
}

/// Named property getter - WebIDL getter DOMString (DOMString name)
/// Per HTML spec §2.4.2.4: Returns the value of the data-* attribute with the given camelCase name.
/// Note: Per WebIDL spec, this is only called when the property exists (interceptor checks first).
pub fn call_getter(instance: *runtime.Instance, name: runtime.DOMString) !runtime.DOMString {
    const internal = getInternalState(instance) orelse return error.InvalidState;

    // Convert camelCase name to hyphenated attribute name
    const allocator = internal.allocator;
    const attr_name = try toHyphenated(allocator, name.asSlice());
    defer allocator.free(attr_name);

    // Get the attribute value from the element
    const attr_dom_str = runtime.DOMString.initInterned(attr_name);
    const value = try interfaces.Element.call_getAttribute(internal.element, attr_dom_str);

    // Return empty string if attribute doesn't exist (shouldn't happen if interceptor checks first)
    return value orelse runtime.DOMString.initEmpty();
}

/// Named property setter - WebIDL setter void (DOMString name, DOMString value)
/// Per HTML spec §2.4.2.4: Sets the data-* attribute with the given camelCase name.
pub fn call_setter(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) !void {
    const internal = getInternalState(instance) orelse return error.InvalidState;

    // HTML DOMStringMap setter step 1: reject a hyphen followed by an ASCII
    // lower alpha before converting or validating the attribute name.
    // Blink DatasetDOMStringMap::SetItem checks IsValidPropertyName first.
    const property = name.asSlice();
    for (property, 0..) |character, index| {
        if (character == '-' and index + 1 < property.len and std.ascii.isLower(property[index + 1])) return error.SyntaxError;
    }

    // Steps 2–3: ASCII uppercase becomes hyphen + lowercase; prefix data-.
    const allocator = internal.allocator;
    const attr_name = try toHyphenated(allocator, property);
    defer allocator.free(attr_name);

    // Step 4 uses DOM's attribute-local-name grammar, not the XML Name grammar.
    if (!@import("dom").names.isValidAttributeLocalName(attr_name)) return error.InvalidCharacterError;

    // Step 5: DOM's "set an attribute value" defaults to a null namespace.
    // HTML 177b8a506931 (2016-05-19) made this explicit; Firefox passes
    // custom-attrs.html, while Blink/WebKit still use setAttribute. Follow
    // the newer spec already shipped by Firefox (golden rule 2).
    // https://github.com/whatwg/html/commit/177b8a506931a51ecaeae71d4518431ee01ce783
    // https://wpt.fyi/results/html/dom/elements/global-attributes/custom-attrs.html
    try @import("dom").element_attributes.set(internal.element, attr_name, value.asSlice(), .{});
}

/// Named property deleter - WebIDL deleter void (DOMString name)
/// Per HTML spec §2.4.2.4: Removes the data-* attribute with the given camelCase name.
pub fn call_deleter(instance: *runtime.Instance, name: runtime.DOMString) !void {
    const internal = getInternalState(instance) orelse return error.InvalidState;

    // Convert camelCase name to hyphenated attribute name
    const allocator = internal.allocator;
    const attr_name = try toHyphenated(allocator, name.asSlice());
    defer allocator.free(attr_name);

    // Remove the attribute from the element
    const attr_dom_str = runtime.DOMString.initInterned(attr_name);
    try interfaces.Element.call_removeAttribute(internal.element, attr_dom_str);
}
