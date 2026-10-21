//! HTML 2.6.1 element-reference reflection. Element owns this lazy state.
//! Explicit associations are weak; the independently cached FrozenArray is
//! traced from its owner. Blink Element::{Get,Set}ElementArrayAttribute and
//! WebKit Element::{elementForAttributeInternal,setElementsArrayAttribute}
//! use the same separation (no browser implementation code is copied).
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const infra = @import("infra");
const data = @import("element_data.zig");
const attributes = @import("element_attributes.zig");
const bridge = @import("instance_bridge.zig");
const tree_map = @import("tree_ordered_map.zig");
const NodeBase = @import("node_base.zig").NodeBase;
const Weak = @import("custom_elements.zig").KeptInstance;

pub const array_attributes = .{
    "aria-controls", "aria-describedby", "aria-details", "aria-errormessage",
    "aria-flowto",   "aria-labelledby",  "aria-owns",
};

const ArrayState = struct {
    explicit: ?[]Weak = null,
    cached: ?[]Weak = null,
};

/// Native identities only: traced values live on the owner's wrapper.
pub const State = struct {
    single: ?Weak = null,
    arrays: [array_attributes.len]ArrayState = @splat(.{}),

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        for (&self.arrays) |*entry| {
            if (entry.explicit) |values| allocator.free(values);
            if (entry.cached) |values| allocator.free(values);
        }
        self.* = .{};
    }

    /// HTML attribute change steps 1-2. Called even for same-value writes.
    pub fn attributeChanged(self: *State, allocator: std.mem.Allocator, name: []const u8) void {
        if (std.mem.eql(u8, name, "aria-activedescendant")) self.single = null;
        inline for (array_attributes, 0..) |attribute, i| {
            if (std.mem.eql(u8, name, attribute)) {
                if (self.arrays[i].explicit) |values| allocator.free(values);
                self.arrays[i].explicit = null;
                return;
            }
        }
    }

    /// An owner freed without a wrapper must release any waiting cache edges.
    pub fn releaseUnwrapped(owner: *runtime.Instance) void {
        if (engine.hasWrapper(owner)) return;
        inline for (array_attributes) |attribute| engine.forgetTracedChild(owner, cacheSlot(attribute));
    }
};

fn arrayIndex(comptime attribute: []const u8) usize {
    inline for (array_attributes, 0..) |name, i| if (comptime std.mem.eql(u8, attribute, name)) return i;
    @compileError("Unknown reflected array attribute");
}

fn cacheSlot(comptime attribute: []const u8) engine.TracedSlot {
    return .{ .name = "element-reference:" ++ attribute ++ ":cached" };
}

fn parent(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_parentNode(node) catch null;
}

fn root(node: *runtime.Instance) *runtime.Instance {
    var result = node;
    while (parent(result)) |p| result = p;
    return result;
}

/// An explicit target must be a descendant of a shadow-including ancestor.
pub fn inScope(owner: *runtime.Instance, target: *runtime.Instance) bool {
    const target_root = root(target);
    var scope = root(owner);
    while (true) {
        if (scope == target_root) return true;
        if (scope.stateAs(interfaces.ShadowRoot.State) == null) return false;
        const host = interfaces.ShadowRoot.get_host(scope) catch return false;
        scope = root(host);
    }
}

/// Resolve an ID in the element's tree scope, including disconnected trees.
pub fn byId(owner: *runtime.Instance, id: []const u8) ?*runtime.Instance {
    if (id.len == 0) return null;
    const scope = root(owner);
    switch (tree_map.elementById(scope, id)) {
        .found => |found| return found,
        .unindexed => {},
    }
    const base = bridge.getNodeBase(scope) orelse return null;
    // Blink getElementByIdIncludingDisconnected and WebKit's identically
    // named helper search descendants, excluding the disconnected root.
    var at = base.first_child;
    while (at) |node| {
        if (bridge.getInstanceTyped(runtime.Instance, node)) |candidate| {
            if (data.of(candidate)) |element| if (std.mem.eql(u8, element.id.asSlice(), id)) return candidate;
        }
        at = next(node, base);
    }
    return null;
}

fn next(node: *NodeBase, boundary: *NodeBase) ?*NodeBase {
    if (node.first_child) |child| return child;
    var current = node;
    while (current != boundary) {
        if (current.next_sibling) |sibling| return sibling;
        current = current.parent_node orelse return null;
    }
    return null;
}

/// HTML get the attr-associated element, steps 1-5.
pub fn getSingle(owner: *runtime.Instance, state: ?*State) ?*runtime.Instance {
    if (state) |s| if (s.single) |weak| {
        const target = weak.get() orelse return null;
        return if (inScope(owner, target)) target else null;
    };
    const element = data.of(owner) orelse return null;
    const attribute = element.findAttribute(null, "aria-activedescendant") orelse return null;
    return byId(owner, attribute.value);
}

/// HTML FrozenArray getter steps 1-6; returns an owned engine value.
pub fn getArray(owner: *runtime.Instance, state: *State, allocator: std.mem.Allocator, comptime attribute: []const u8) !?runtime.JSValue {
    const entry = &state.arrays[comptime arrayIndex(attribute)];
    var elements = infra.List(Weak).init(allocator);
    defer elements.deinit();
    if (entry.explicit) |targets| {
        // Associated elements steps 3.1-3.2: filter without erasing targets.
        for (targets) |weak| if (weak.get()) |target| {
            if (inScope(owner, target)) try elements.append(weak);
        };
    } else {
        // Steps 4.1-4.4: absent differs from an empty token list.
        const element = data.of(owner) orelse return error.InvalidStateError;
        const content = element.findAttribute(null, attribute) orelse {
            if (entry.cached) |previous| allocator.free(previous);
            entry.cached = null;
            engine.forgetTracedChild(owner, cacheSlot(attribute));
            return null;
        };
        var tokens = std.mem.tokenizeAny(u8, content.value, " \t\n\r\x0c");
        while (tokens.next()) |id| if (byId(owner, id)) |target| try elements.append(Weak.of(target));
    }
    if (entry.cached) |cached| {
        var equal = cached.len == elements.len;
        if (equal) for (cached, elements.toSlice()) |a, b| {
            if (a.get() != b.get()) {
                equal = false;
                break;
            }
        };
        if (equal) if (engine.tracedValue(owner, cacheSlot(attribute))) |array| return array.take();
    }
    const cached = try allocator.dupe(Weak, elements.toSlice());
    errdefer allocator.free(cached);
    const values = try allocator.alloc(runtime.JSValue, elements.len);
    defer allocator.free(values);
    for (elements.toSlice(), values) |weak, *value| value.* = .{ .instance = weak.get() orelse return error.InvalidStateError };
    const array = try engine.createFrozenArray(engine.currentRealm() orelse owner.ctx, values);
    engine.traceValue(owner, array.borrow(), cacheSlot(attribute));
    if (entry.cached) |previous| allocator.free(previous);
    entry.cached = cached;
    return array.take();
}

/// WebIDL FrozenArray<Element> conversion precedes HTML's setter steps.
/// Own the yielded wrappers until iteration (which may run script/GC) ends.
pub const Converted = struct {
    realm: runtime.Context,
    nodes: infra.List(Weak),
    values: infra.List(engine.Owned),

    pub fn init(realm: runtime.Context, allocator: std.mem.Allocator, value: runtime.JSValue) !Converted {
        if (engine.typeOf(realm, value) != .object) return error.TypeError;
        var result: Converted = .{ .realm = realm, .nodes = .init(allocator), .values = .init(allocator) };
        errdefer result.deinit();
        if (!try engine.iterate(realm, value, item, &result)) return error.TypeError;
        return result;
    }

    pub fn deinit(self: *Converted) void {
        for (self.values.toSlice()) |value| value.release();
        self.values.deinit();
        self.nodes.deinit();
    }

    fn item(user_data: ?*anyopaque, value: runtime.JSValue) engine.Error!void {
        const self: *Converted = @ptrCast(@alignCast(user_data.?));
        const node = engine.convertToPlatformObject(self.realm, value) orelse return error.TypeError;
        if (node.stateAs(interfaces.Element.State) == null) return error.TypeError;
        const held = try engine.retainValue(node.ctx, .{ .instance = node });
        errdefer held.release();
        try self.nodes.append(Weak.of(node));
        try self.values.append(held);
    }
};

/// HTML setter steps 2-5, after conversion and allocation have succeeded.
/// The attribute mutation clears the old association before installing this.
pub fn setArray(owner: *runtime.Instance, state: *State, allocator: std.mem.Allocator, comptime attribute: []const u8, targets: []const Weak) !void {
    const replacement = try allocator.dupe(Weak, targets);
    errdefer allocator.free(replacement);
    try attributes.set(owner, attribute, "", .{});
    const entry = &state.arrays[comptime arrayIndex(attribute)];
    if (entry.explicit) |old| allocator.free(old);
    entry.explicit = replacement;
}
