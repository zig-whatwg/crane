//! Tests for WebIDL runtime helpers
//!
//! Verifies the runtime API for querying WebIDL metadata.

const std = @import("std");
const testing = std.testing;
const webidl = @import("webidl");

// Import test interfaces
const EventTarget = @import("dom").EventTarget;
const Event = @import("dom").Event;
const Node = @import("dom").Node;
const Element = @import("dom").Element;
const ReadableStream = @import("streams").ReadableStream;
const WritableStream = @import("streams").WritableStream;
const console = @import("console").console;
// TODO: ParentNode not exported from dom module yet
// const ParentNode = @import("dom").ParentNode;

// ============================================================================
// isExposedIn Tests
// ============================================================================

test "isExposedIn: EventTarget exposed in Window" {
    try testing.expect(webidl.isExposedIn(EventTarget, .Window));
}

test "isExposedIn: EventTarget exposed in Worker" {
    try testing.expect(webidl.isExposedIn(EventTarget, .Worker));
}

test "isExposedIn: EventTarget exposed in all globals ([Exposed=*])" {
    // [Exposed=*] means exposed everywhere
    try testing.expect(webidl.isExposedIn(EventTarget, .Window));
    try testing.expect(webidl.isExposedIn(EventTarget, .Worker));
    try testing.expect(webidl.isExposedIn(EventTarget, .Worklet));
    try testing.expect(webidl.isExposedIn(EventTarget, .ServiceWorker));
}

test "isExposedIn: Node only exposed in Window" {
    try testing.expect(webidl.isExposedIn(Node, .Window));
    try testing.expect(!webidl.isExposedIn(Node, .Worker));
    try testing.expect(!webidl.isExposedIn(Node, .Worklet));
}

test "isExposedIn: ReadableStream exposed everywhere" {
    // [Exposed=*]
    try testing.expect(webidl.isExposedIn(ReadableStream, .Window));
    try testing.expect(webidl.isExposedIn(ReadableStream, .Worker));
}

test "isExposedIn: console exposed everywhere" {
    // [Exposed=*]
    try testing.expect(webidl.isExposedIn(console, .Window));
    try testing.expect(webidl.isExposedIn(console, .Worker));
}

// ============================================================================
// isTransferable Tests
// ============================================================================

test "isTransferable: ReadableStream is transferable" {
    try testing.expect(webidl.isTransferable(ReadableStream));
}

test "isTransferable: WritableStream is transferable" {
    try testing.expect(webidl.isTransferable(WritableStream));
}

test "isTransferable: Event is not transferable" {
    try testing.expect(!webidl.isTransferable(Event));
}

test "isTransferable: EventTarget is not transferable" {
    try testing.expect(!webidl.isTransferable(EventTarget));
}

test "isTransferable: Node is not transferable" {
    try testing.expect(!webidl.isTransferable(Node));
}

// ============================================================================
// getGlobalNames Tests
// ============================================================================

test "getGlobalNames: EventTarget returns null (exposed everywhere)" {
    const names = webidl.getGlobalNames(EventTarget);
    // [Exposed=*] returns null to indicate "all globals"
    try testing.expectEqual(@as(?[]const []const u8, null), names);
}

test "getGlobalNames: Node returns Window only" {
    const names = webidl.getGlobalNames(Node);
    try testing.expect(names != null);
    try testing.expectEqual(@as(usize, 1), names.?.len);
    try testing.expectEqualStrings("Window", names.?[0]);
}

test "getGlobalNames: ReadableStream returns null (exposed everywhere)" {
    const names = webidl.getGlobalNames(ReadableStream);
    try testing.expectEqual(@as(?[]const []const u8, null), names);
}

// ============================================================================
// getParent Tests
// ============================================================================

test "getParent: EventTarget has no parent" {
    const parent = webidl.getParent(EventTarget);
    try testing.expectEqual(@as(?[]const u8, null), parent);
}

test "getParent: Node inherits from EventTarget" {
    const parent = webidl.getParent(Node);
    try testing.expect(parent != null);
    try testing.expectEqualStrings("EventTarget", parent.?);
}

test "getParent: Element inherits from Node" {
    const parent = webidl.getParent(Element);
    try testing.expect(parent != null);
    try testing.expectEqualStrings("Node", parent.?);
}

test "getParent: ReadableStream has no parent" {
    const parent = webidl.getParent(ReadableStream);
    try testing.expectEqual(@as(?[]const u8, null), parent);
}

// ============================================================================
// isNamespace Tests
// ============================================================================

test "isNamespace: console is a namespace" {
    try testing.expect(webidl.isNamespace(console));
}

test "isNamespace: EventTarget is not a namespace" {
    try testing.expect(!webidl.isNamespace(EventTarget));
}

test "isNamespace: Node is not a namespace" {
    try testing.expect(!webidl.isNamespace(Node));
}

// ============================================================================
// isInterface Tests
// ============================================================================

test "isInterface: EventTarget is an interface" {
    try testing.expect(webidl.isInterfaceType(EventTarget));
}

test "isInterface: Node is an interface" {
    try testing.expect(webidl.isInterfaceType(Node));
}

test "isInterface: ReadableStream is an interface" {
    try testing.expect(webidl.isInterfaceType(ReadableStream));
}

test "isInterface: console is not an interface (it's a namespace)" {
    try testing.expect(!webidl.isInterfaceType(console));
}

// ============================================================================
// isMixin Tests
// ============================================================================

// TODO: Re-enable when ParentNode is exported from dom module
// test "isMixin: ParentNode is a mixin" {
//     try testing.expect(webidl.isMixin(ParentNode));
// }

test "isMixin: EventTarget is not a mixin" {
    try testing.expect(!webidl.isMixin(EventTarget));
}

test "isMixin: console is not a mixin" {
    try testing.expect(!webidl.isMixin(console));
}

// ============================================================================
// GlobalScope Tests
// ============================================================================

test "GlobalScope.fromString converts correctly" {
    try testing.expectEqual(webidl.GlobalScope.Window, webidl.GlobalScope.fromString("Window").?);
    try testing.expectEqual(webidl.GlobalScope.Worker, webidl.GlobalScope.fromString("Worker").?);
    try testing.expectEqual(webidl.GlobalScope.Worklet, webidl.GlobalScope.fromString("Worklet").?);
    try testing.expectEqual(@as(?webidl.GlobalScope, null), webidl.GlobalScope.fromString("Invalid"));
}

test "GlobalScope.toString converts correctly" {
    try testing.expectEqualStrings("Window", webidl.GlobalScope.Window.toString());
    try testing.expectEqualStrings("Worker", webidl.GlobalScope.Worker.toString());
    try testing.expectEqualStrings("Worklet", webidl.GlobalScope.Worklet.toString());
}

test "GlobalScope roundtrip conversion" {
    inline for (std.meta.fields(webidl.GlobalScope)) |field| {
        const scope: webidl.GlobalScope = @enumFromInt(field.value);
        const name = scope.toString();
        const parsed = webidl.GlobalScope.fromString(name);
        try testing.expectEqual(scope, parsed.?);
    }
}

// ============================================================================
// Integration Tests
// ============================================================================

test "check multiple properties on ReadableStream" {
    // ReadableStream should be:
    // - An interface (not namespace or mixin)
    // - Exposed everywhere ([Exposed=*])
    // - Transferable ([Transferable])
    // - No parent (doesn't inherit)

    try testing.expect(webidl.isInterfaceType(ReadableStream));
    try testing.expect(!webidl.isNamespace(ReadableStream));
    try testing.expect(!webidl.isMixin(ReadableStream));

    try testing.expect(webidl.isExposedIn(ReadableStream, .Window));
    try testing.expect(webidl.isExposedIn(ReadableStream, .Worker));

    try testing.expect(webidl.isTransferable(ReadableStream));

    const names = webidl.getGlobalNames(ReadableStream);
    try testing.expectEqual(@as(?[]const []const u8, null), names); // null = everywhere

    const parent = webidl.getParent(ReadableStream);
    try testing.expectEqual(@as(?[]const u8, null), parent);
}

test "check multiple properties on Element" {
    // Element should be:
    // - An interface
    // - Exposed only in Window ([Exposed=Window])
    // - Not transferable
    // - Inherits from Node

    try testing.expect(webidl.isInterfaceType(Element));
    try testing.expect(!webidl.isNamespace(Element));
    try testing.expect(!webidl.isMixin(Element));

    try testing.expect(webidl.isExposedIn(Element, .Window));
    try testing.expect(!webidl.isExposedIn(Element, .Worker));

    try testing.expect(!webidl.isTransferable(Element));

    const names = webidl.getGlobalNames(Element);
    try testing.expect(names != null);
    try testing.expectEqual(@as(usize, 1), names.?.len);
    try testing.expectEqualStrings("Window", names.?[0]);

    const parent = webidl.getParent(Element);
    try testing.expect(parent != null);
    try testing.expectEqualStrings("Node", parent.?);
}
