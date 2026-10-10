//! Which generated interfaces' wrappers own a counted reference
//! (`VTable.counted`, refcount design 2.1, step 4): every node type, and no
//! other (decision D3, nodes first). tests/runtime/vtable_counted_test.zig pins
//! the predicate's default on synthetic states; this pins it on the real ones.

const std = @import("std");
const testing = std.testing;
const interfaces = @import("interfaces");

test "every node interface is counted" {
    inline for (.{
        interfaces.Node,                  interfaces.Element,             interfaces.HTMLElement,
        interfaces.HTMLDivElement,        interfaces.HTMLTemplateElement, interfaces.SVGElement,
        interfaces.Text,                  interfaces.CDATASection,        interfaces.Comment,
        interfaces.ProcessingInstruction, interfaces.DocumentType,        interfaces.DocumentFragment,
        interfaces.ShadowRoot,            interfaces.Document,            interfaces.XMLDocument,
        interfaces.Attr,
    }) |Interface| {
        if (Interface.vtable.counted == null) {
            std.debug.print("{s} is not counted\n", .{Interface.vtable.name});
            return error.NodeNotCounted;
        }
    }
}

test "no other interface is counted: the default" {
    inline for (.{
        interfaces.EventTarget,  interfaces.Window,         interfaces.Event,
        interfaces.NodeList,     interfaces.HTMLCollection, interfaces.Range,
        interfaces.Headers,      interfaces.AbortSignal,    interfaces.MutationRecord,
        interfaces.DOMTokenList, interfaces.NamedNodeMap,   interfaces.CSSStyleDeclaration,
    }) |Interface| {
        if (Interface.vtable.counted != null) {
            std.debug.print("{s} is counted\n", .{Interface.vtable.name});
            return error.CountedByMistake;
        }
    }
}
