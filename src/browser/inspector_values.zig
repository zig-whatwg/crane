//! How the agent's inspector describes the DOM's objects: the host's
//! valueSubtype and descriptionForValueSubtype (engine.InspectorClient), as
//! Blink's ThreadDebuggerCommonImpl answers V8's inspector
//! (third_party/blink/renderer/core/inspector/thread_debugger_common_impl.cc,
//! valueSubtype / descriptionForValueSubtype; BSD-3 - reproduced, not copied).
//!
//! The subtype is what CDP clients branch on: Puppeteer (createJSHandle) and
//! Playwright (crExecutionContext createHandle) make an ELEMENT handle - with
//! $eval, click, contentFrame - only for a RemoteObject of subtype "node";
//! every other object is a plain JS handle.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

/// valueSubtype: "node" for a Node; "array" for a NodeList, DOMTokenList,
/// HTMLCollection or HTMLAllCollection; "error" for a DOMException; "blob"
/// for a Blob; "trustedtype" for a TrustedHTML, TrustedScript or
/// TrustedScriptURL; null for any other platform object (the engine's own
/// answer).
pub fn valueSubtype(host: ?*anyopaque, instance: *runtime.Instance) ?[]const u8 {
    _ = host;
    if (instance.implements(interfaces.Node.State)) return "node";
    if (instance.implements(interfaces.NodeList.State) or
        instance.implements(interfaces.DOMTokenList.State) or
        instance.implements(interfaces.HTMLCollection.State) or
        instance.implements(interfaces.HTMLAllCollection.State)) return "array";
    if (instance.implements(interfaces.DOMException.State)) return "error";
    if (instance.implements(interfaces.Blob.State)) return "blob";
    if (instance.implements(interfaces.TrustedHTML.State) or
        instance.implements(interfaces.TrustedScript.State) or
        instance.implements(interfaces.TrustedScriptURL.State)) return "trustedtype";
    return null;
}

/// descriptionForValueSubtype: a trusted type's string; a node's - an
/// element's qualified name, then "#" and its id when it has one, then "."
/// and each of its classes; a doctype's "<!DOCTYPE name>"; any other node's
/// nodeName ("#document", "#text"). Null for the rest (the engine's own).
pub fn description(host: ?*anyopaque, instance: *runtime.Instance, buffer: []u8) ?[]const u8 {
    _ = host;
    const allocator = instance.ctx.allocator;
    var out: Writer = .{ .buffer = buffer };
    if (instance.implements(interfaces.TrustedHTML.State)) return stringifier(interfaces.TrustedHTML, instance, &out);
    if (instance.implements(interfaces.TrustedScript.State)) return stringifier(interfaces.TrustedScript, instance, &out);
    if (instance.implements(interfaces.TrustedScriptURL.State)) return stringifier(interfaces.TrustedScriptURL, instance, &out);
    if (!instance.implements(interfaces.Node.State)) return null;
    const node_type = interfaces.Node.get_nodeType(instance) catch return null;
    switch (node_type) {
        // ELEMENT_NODE: TagQName().ToString(), the id, the class names.
        1 => {
            if (interfaces.Element.get_prefix(instance) catch null) |prefix| {
                var p = prefix;
                defer p.deinit(allocator);
                out.append(p.asSlice());
                out.append(":");
            }
            var local = interfaces.Element.get_localName(instance) catch return null;
            defer local.deinit(allocator);
            out.append(local.asSlice());
            var id = interfaces.Element.get_id(instance) catch runtime.DOMString.initEmpty();
            defer id.deinit(allocator);
            if (id.asSlice().len > 0) {
                out.append("#");
                out.append(id.asSlice());
            }
            // Element::ClassNames: the class attribute's tokens, in order.
            var classes = interfaces.Element.get_className(instance) catch runtime.DOMString.initEmpty();
            defer classes.deinit(allocator);
            var tokens = std.mem.tokenizeAny(u8, classes.asSlice(), " \t\n\x0c\r");
            while (tokens.next()) |class| {
                out.append(".");
                out.append(class);
            }
        },
        // DOCUMENT_TYPE_NODE
        10 => {
            var name = interfaces.Node.get_nodeName(instance) catch return null;
            defer name.deinit(allocator);
            out.append("<!DOCTYPE ");
            out.append(name.asSlice());
            out.append(">");
        },
        else => {
            var name = interfaces.Node.get_nodeName(instance) catch return null;
            defer name.deinit(allocator);
            out.append(name.asSlice());
        },
    }
    return out.written();
}

/// A trusted type's data: its stringifier's value, which toJSON() answers too
/// (a DOMString, or a TrustedScriptURL's USVString: the bytes, OWNED by the
/// realm's allocator).
fn stringifier(comptime Interface: type, instance: *runtime.Instance, out: *Writer) ?[]const u8 {
    const allocator = instance.ctx.allocator;
    const text = Interface.call_toJSON(instance) catch return null;
    if (@TypeOf(text) == runtime.DOMString) {
        var owned = text;
        defer owned.deinit(allocator);
        out.append(owned.asSlice());
    } else {
        defer allocator.free(text);
        out.append(text);
    }
    return out.written();
}

/// Bytes into a fixed buffer; what does not fit is left out (a description
/// is for reading, and the engine's buffer is its bound), never cutting a
/// UTF-8 sequence.
const Writer = struct {
    buffer: []u8,
    len: usize = 0,
    full: bool = false,

    fn append(self: *Writer, bytes: []const u8) void {
        if (self.full) return;
        const room = self.buffer.len - self.len;
        if (bytes.len <= room) {
            @memcpy(self.buffer[self.len..][0..bytes.len], bytes);
            self.len += bytes.len;
            return;
        }
        // The longest prefix that ends on a sequence boundary.
        var cut = room;
        while (cut > 0 and (bytes[cut] & 0xC0) == 0x80) cut -= 1;
        @memcpy(self.buffer[self.len..][0..cut], bytes[0..cut]);
        self.len += cut;
        self.full = true;
    }

    fn written(self: *const Writer) []const u8 {
        return self.buffer[0..self.len];
    }
};
