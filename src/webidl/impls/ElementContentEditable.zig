//! Implementation for the ElementContentEditable mixin (HTML §6.8):
//! contentEditable, enterKeyHint, isContentEditable, inputMode, and
//! virtualKeyboardPolicy, included by HTMLElement.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const element_data = dom.element_data;
const ElementContentEditable = interfaces.ElementContentEditable;

pub const State = ElementContentEditable.State;

pub const ImplError = error{
    NotImplemented,
    SyntaxError,
};

pub const InternalState = struct {};

fn getContentAttribute(instance: *runtime.Instance, name: []const u8) ?runtime.DOMString {
    const data = element_data.of(instance) orelse return null;
    const attr = element_data.getAttributeByNamespaceAndLocalName(data, null, name) orelse return null;
    return runtime.DOMString.initInterned(attr.value);
}

fn setContentAttribute(instance: *runtime.Instance, name: []const u8, value: runtime.DOMString) !void {
    try dom.element_attributes.set(instance, name, value.asSlice(), .{});
}

/// Getter for contentEditable (HTML §6.8.1).
pub fn get_contentEditable(instance: *runtime.Instance) anyerror!runtime.DOMString {
    var attribute = try interfaces.Element.call_getAttributeNS(instance, null, runtime.DOMString.initInterned("contenteditable"));
    defer if (attribute) |*value| value.deinit(instance.ctx.allocator);
    if (attribute) |value| {
        const keyword = value.asSlice();
        if (keyword.len == 0) return runtime.DOMString.initInterned("true");
        inline for (.{ "true", "false", "plaintext-only" }) |state|
            if (std.ascii.eqlIgnoreCase(keyword, state)) return runtime.DOMString.initInterned(state);
    }
    return runtime.DOMString.initInterned("inherit");
}

/// Setter for contentEditable (HTML §6.8.1).
pub fn set_contentEditable(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const keyword = value.asSlice();
    const name = runtime.DOMString.initInterned("contenteditable");
    if (std.ascii.eqlIgnoreCase(keyword, "inherit")) {
        try interfaces.Element.call_removeAttributeNS(instance, null, name);
        return;
    }
    inline for (.{ "true", "false", "plaintext-only" }) |state| {
        if (std.ascii.eqlIgnoreCase(keyword, state)) {
            try interfaces.Element.call_setAttributeNS(instance, null, name, .{ .domstring = runtime.DOMString.initInterned(state) });
            return;
        }
    }
    return error.SyntaxError;
}

/// Getter for enterKeyHint (HTML §6.8.7).
pub fn get_enterKeyHint(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return dom.reflection.getEnumerated(runtime.DOMString, instance, .{
        .name = "enterkeyhint",
        .keywords = &.{ "enter", "done", "go", "next", "previous", "search", "send" },
    });
}

/// Setter for enterKeyHint (HTML §6.8.7).
pub fn set_enterKeyHint(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "enterkeyhint", value);
}

/// Getter for isContentEditable (HTML §6.8.4).
pub fn get_isContentEditable(instance: *runtime.Instance) anyerror!bool {
    var current: ?*runtime.Instance = instance;
    while (current) |element| {
        var namespace = try interfaces.Element.get_namespaceURI(element);
        defer if (namespace) |*value| value.deinit(element.ctx.allocator);
        const ns = if (namespace) |value| value.asSlice() else "";
        const is_html = std.mem.eql(u8, ns, "http://www.w3.org/1999/xhtml");
        const parent = try interfaces.Node.get_parentNode(element);
        if (is_html) {
            var state = try interfaces.HTMLElement.get_contentEditable(element);
            defer state.deinit(element.ctx.allocator);
            const value = state.asSlice();
            if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "plaintext-only")) return true;
            if (parent) |node| {
                if (try interfaces.Node.get_nodeType(node) == interfaces.Node.get_DOCUMENT_NODE()) {
                    var mode = try interfaces.Document.get_designMode(node);
                    defer mode.deinit(node.ctx.allocator);
                    return std.mem.eql(u8, mode.asSlice(), "on");
                }
            }
            if (std.mem.eql(u8, value, "false")) return false;
        } else {
            var name = try interfaces.Element.get_localName(element);
            defer name.deinit(element.ctx.allocator);
            if (!((std.mem.eql(u8, ns, "http://www.w3.org/2000/svg") and std.mem.eql(u8, name.asSlice(), "svg")) or
                (std.mem.eql(u8, ns, "http://www.w3.org/1998/Math/MathML") and std.mem.eql(u8, name.asSlice(), "math")))) return false;
        }
        current = if (parent) |node|
            if (try interfaces.Node.get_nodeType(node) == interfaces.Node.get_ELEMENT_NODE()) node else null
        else
            null;
    }
    return false;
}

/// Getter for inputMode (HTML §6.8.6).
pub fn get_inputMode(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return dom.reflection.getEnumerated(runtime.DOMString, instance, .{
        .name = "inputmode",
        .keywords = &.{ "none", "text", "tel", "url", "email", "numeric", "decimal", "search" },
    });
}

/// Setter for inputMode (HTML §6.8.6).
pub fn set_inputMode(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "inputmode", value);
}

/// Getter for virtualKeyboardPolicy (VirtualKeyboard API).
pub fn get_virtualKeyboardPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "virtualkeyboardpolicy") orelse runtime.DOMString.initEmpty();
}

/// Setter for virtualKeyboardPolicy (VirtualKeyboard API).
pub fn set_virtualKeyboardPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "virtualkeyboardpolicy", value);
}
