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
const Registry = utils.InstanceRegistry(InternalState);

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
    const ElementImpl = @import("Element.zig");
    const elem_internal = ElementImpl.getInternalState(internal.element) orelse return &[_]runtime.DOMString{};

    var names: std.ArrayListUnmanaged(runtime.DOMString) = .{};
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
    var result: std.ArrayList(u8) = .{};
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
