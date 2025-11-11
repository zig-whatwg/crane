//! NamedNodeMap interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-namednodemap
//! DOM §4.9

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const Attr = @import("attr").Attr;
const Element = @import("element").Element;

/// DOM §4.9 - NamedNodeMap interface
/// A NamedNodeMap is a live collection of attributes.
///
/// A NamedNodeMap has an associated element (an element).
/// A NamedNodeMap object's attribute list is its element's attribute list.
pub const NamedNodeMap = webidl.interface(struct {
    /// Associated element
    element: *Element,

    pub fn init(element: *Element) NamedNodeMap {
        return .{
            .element = element,
        };
    }

    pub fn deinit(self: *NamedNodeMap) void {
        _ = self;
        // No cleanup needed - we don't own the element
    }

    /// DOM §4.9 - length getter
    /// Returns the attribute list's size.
    pub fn get_length(self: *const NamedNodeMap) u32 {
        return @intCast(self.element.attributes.items.len);
    }

    /// DOM §4.9 - item(index)
    /// Returns the attribute at the given index, or null if out of bounds.
    ///
    /// Steps:
    /// 1. If index is equal to or greater than this's attribute list's size, then return null.
    /// 2. Otherwise, return this's attribute list[index].
    pub fn call_item(self: *const NamedNodeMap, index: u32) ?*Attr {
        if (index >= self.element.attributes.items.len) {
            return null;
        }
        return &self.element.attributes.items[index];
    }

    /// DOM §4.9 - getNamedItem(qualifiedName)
    /// Returns the attribute with the given qualified name, or null if not found.
    ///
    /// Steps: Return the result of getting an attribute given qualifiedName and element.
    pub fn call_getNamedItem(self: *const NamedNodeMap, qualified_name: []const u8) ?*Attr {
        // Get an attribute given qualifiedName and element
        for (self.element.attributes.items) |*attr| {
            if (std.mem.eql(u8, attr.name, qualified_name)) {
                return attr;
            }
        }
        return null;
    }

    /// DOM §4.9 - getNamedItemNS(namespace, localName)
    /// Returns the attribute with the given namespace and local name, or null if not found.
    ///
    /// Steps: Return the result of getting an attribute given namespace, localName, and element.
    pub fn call_getNamedItemNS(
        self: *const NamedNodeMap,
        namespace: ?[]const u8,
        local_name: []const u8,
    ) !?*Attr {
        _ = self;
        _ = namespace;
        _ = local_name;
        // TODO: Implement namespace-aware attribute handling
        return error.NotImplemented;
    }

    /// DOM §4.9 - setNamedItem(attr)
    /// Sets the given attribute. Returns the old attribute if replaced, or null.
    ///
    /// Steps: Return the result of setting an attribute given attr and element.
    /// [CEReactions] - Causes DOM mutations
    pub fn call_setNamedItem(self: *NamedNodeMap, attr: *Attr) !?*Attr {
        _ = self;
        _ = attr;
        // TODO: Implement attribute setting with proper mutation handling
        return error.NotImplemented;
    }

    /// DOM §4.9 - setNamedItemNS(attr)
    /// Sets the given attribute with namespace. Returns the old attribute if replaced, or null.
    ///
    /// Steps: Return the result of setting an attribute given attr and element.
    /// [CEReactions] - Causes DOM mutations
    pub fn call_setNamedItemNS(self: *NamedNodeMap, attr: *Attr) !?*Attr {
        _ = self;
        _ = attr;
        // TODO: Implement namespace-aware attribute setting
        return error.NotImplemented;
    }

    /// DOM §4.9 - removeNamedItem(qualifiedName)
    /// Removes the attribute with the given qualified name.
    /// Throws NotFoundError if the attribute doesn't exist.
    ///
    /// Steps:
    /// 1. Let attr be the result of removing an attribute given qualifiedName and element.
    /// 2. If attr is null, then throw a "NotFoundError" DOMException.
    /// 3. Return attr.
    /// [CEReactions] - Causes DOM mutations
    pub fn call_removeNamedItem(self: *NamedNodeMap, qualified_name: []const u8) !*Attr {
        _ = self;
        _ = qualified_name;
        // TODO: Implement attribute removal with proper mutation handling
        return error.NotImplemented;
    }

    /// DOM §4.9 - removeNamedItemNS(namespace, localName)
    /// Removes the attribute with the given namespace and local name.
    /// Throws NotFoundError if the attribute doesn't exist.
    ///
    /// Steps:
    /// 1. Let attr be the result of removing an attribute given namespace, localName, and element.
    /// 2. If attr is null, then throw a "NotFoundError" DOMException.
    /// 3. Return attr.
    /// [CEReactions] - Causes DOM mutations
    pub fn call_removeNamedItemNS(
        self: *NamedNodeMap,
        namespace: ?[]const u8,
        local_name: []const u8,
    ) !*Attr {
        _ = self;
        _ = namespace;
        _ = local_name;
        // TODO: Implement namespace-aware attribute removal
        return error.NotImplemented;
    }
}, .{
    .exposed = &.{.Window},
});
