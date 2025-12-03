//! Tests for Window, Location, and History APIs
//!
//! Per HTML Standard §7.1-7.2, these APIs provide navigation and session history.
//! https://html.spec.whatwg.org/multipage/history.html

const std = @import("std");
const testing = std.testing;

const html = @import("html");
const BrowsingContext = html.window.BrowsingContext;
const WindowProxy = html.window.WindowProxy;
const Origin = html.window.Origin;

// ============================================================================
// Window Navigation Tests (using WindowProxy)
// ============================================================================

test "Window - closed property reflects browsing context state" {
    const allocator = testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    const proxy = WindowProxy.init(allocator, ctx);

    // Initially not closed
    try testing.expect(!proxy.getClosed());

    // Close the browsing context
    ctx.close();

    // Now should be closed
    try testing.expect(proxy.getClosed());
}

test "Window - length property reflects child frame count" {
    const allocator = testing.allocator;

    const parent = try BrowsingContext.initTopLevel(allocator);
    defer parent.deinit();

    const proxy = WindowProxy.init(allocator, parent);

    // No children initially
    try testing.expectEqual(@as(u32, 0), proxy.getLength());

    // Add child (iframe)
    _ = try BrowsingContext.initChild(allocator, parent);
    try testing.expectEqual(@as(u32, 1), proxy.getLength());

    // Add another child
    _ = try BrowsingContext.initChild(allocator, parent);
    try testing.expectEqual(@as(u32, 2), proxy.getLength());
}

test "Window - top returns topmost browsing context" {
    const allocator = testing.allocator;

    const top = try BrowsingContext.initTopLevel(allocator);
    defer top.deinit();

    // For top-level context, top === self
    try testing.expect(top.getTop() == top);

    // Create child context
    const child = try BrowsingContext.initChild(allocator, top);

    // Child's top should be the parent
    try testing.expect(child.getTop() == top);
}

// ============================================================================
// BrowsingContext Hierarchy Tests
// ============================================================================

test "BrowsingContext - top level context is its own top" {
    const allocator = testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    try testing.expect(ctx.isTopLevel());
    try testing.expect(ctx.getTop() == ctx);
}

test "BrowsingContext - child context has correct hierarchy" {
    const allocator = testing.allocator;

    const parent = try BrowsingContext.initTopLevel(allocator);
    defer parent.deinit();

    const child = try BrowsingContext.initChild(allocator, parent);

    try testing.expect(!child.isTopLevel());
    try testing.expect(child.isChild());
    try testing.expect(child.getTop() == parent);
}

test "BrowsingContext - nested child chain has correct top" {
    const allocator = testing.allocator;

    const top = try BrowsingContext.initTopLevel(allocator);
    defer top.deinit();

    const child = try BrowsingContext.initChild(allocator, top);
    const grandchild = try BrowsingContext.initChild(allocator, child);

    // Both child and grandchild should have top as their top
    try testing.expect(child.getTop() == top);
    try testing.expect(grandchild.getTop() == top);
}

test "BrowsingContext - getChildCount tracks children" {
    const allocator = testing.allocator;

    const parent = try BrowsingContext.initTopLevel(allocator);
    defer parent.deinit();

    try testing.expectEqual(@as(u32, 0), parent.getChildCount());

    _ = try BrowsingContext.initChild(allocator, parent);
    try testing.expectEqual(@as(u32, 1), parent.getChildCount());

    _ = try BrowsingContext.initChild(allocator, parent);
    try testing.expectEqual(@as(u32, 2), parent.getChildCount());
}

test "BrowsingContext - getChildByIndex returns correct child" {
    const allocator = testing.allocator;

    const parent = try BrowsingContext.initTopLevel(allocator);
    defer parent.deinit();

    const child1 = try BrowsingContext.initChild(allocator, parent);
    const child2 = try BrowsingContext.initChild(allocator, parent);

    try testing.expect(parent.getChildByIndex(0) == child1);
    try testing.expect(parent.getChildByIndex(1) == child2);
    try testing.expect(parent.getChildByIndex(2) == null);
}

// ============================================================================
// BrowsingContext - Close and Disown Tests
// ============================================================================

test "BrowsingContext - close marks context as closed" {
    const allocator = testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    try testing.expect(!ctx.is_closed);

    ctx.close();

    try testing.expect(ctx.is_closed);
}

test "BrowsingContext - auxiliary context with opener" {
    const allocator = testing.allocator;

    const opener = try BrowsingContext.initTopLevel(allocator);
    defer opener.deinit();

    const aux = try BrowsingContext.initAuxiliary(allocator, opener, true);
    defer aux.deinit();

    try testing.expect(aux.opener == opener);
    try testing.expect(aux.is_popup);
}

test "BrowsingContext - disown removes opener" {
    const allocator = testing.allocator;

    const opener = try BrowsingContext.initTopLevel(allocator);
    defer opener.deinit();

    const aux = try BrowsingContext.initAuxiliary(allocator, opener, false);
    defer aux.deinit();

    try testing.expect(aux.opener == opener);

    aux.disown();

    try testing.expect(aux.opener == null);
}

// ============================================================================
// BrowsingContext - Sandbox Flags Tests
// ============================================================================

test "BrowsingContext - default allows all" {
    const allocator = testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    try testing.expect(ctx.allowsScripts());
    try testing.expect(ctx.allowsForms());
    try testing.expect(ctx.allowsPopups());
    try testing.expect(ctx.allowsTopNavigation());
    try testing.expect(ctx.allowsModals());
}

test "BrowsingContext - sandbox flags can restrict" {
    const allocator = testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    // Restrictive flags (all false) means all features are restricted
    const flags = html.window.SandboxFlags{
        .allow_scripts = false,
        .allow_forms = false,
        .allow_modals = false,
        .allow_popups = true, // Only popups allowed
    };
    ctx.setSandboxFlags(flags);

    try testing.expect(!ctx.allowsScripts());
    try testing.expect(!ctx.allowsForms());
    try testing.expect(!ctx.allowsModals());
    try testing.expect(ctx.allowsPopups()); // This one is allowed
}

test "BrowsingContext - clearSandboxFlags restores access" {
    const allocator = testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    // Set restrictive flags (scripts not allowed)
    const flags = html.window.SandboxFlags{
        .allow_scripts = false,
    };
    ctx.setSandboxFlags(flags);

    try testing.expect(!ctx.allowsScripts());

    ctx.clearSandboxFlags();

    try testing.expect(ctx.allowsScripts());
}

// ============================================================================
// BrowsingContext - Target Name Tests
// ============================================================================

test "BrowsingContext - setTargetName and findByTargetName" {
    const allocator = testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    try ctx.setTargetName("myframe");

    // Should find itself
    const found = ctx.findByTargetName("myframe");
    try testing.expect(found == ctx);

    // Should not find non-existent name
    const not_found = ctx.findByTargetName("other");
    try testing.expect(not_found == null);
}

test "BrowsingContext - findByTargetName searches children" {
    const allocator = testing.allocator;

    const parent = try BrowsingContext.initTopLevel(allocator);
    defer parent.deinit();

    const child = try BrowsingContext.initChild(allocator, parent);
    try child.setTargetName("child-frame");

    // Parent should find child by name
    const found = parent.findByTargetName("child-frame");
    try testing.expect(found == child);
}

// ============================================================================
// Cross-Origin Security Tests
// ============================================================================

test "WindowProxy - cross-origin access to location is allowed" {
    const allocator = testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    var proxy = WindowProxy.init(allocator, ctx);
    proxy.setDocumentOrigin(Origin.init("https", "example.com", 443));

    const cross_origin = Origin.init("https", "other.com", 443);

    // location (getter) is allowed cross-origin
    try proxy.accessProperty(cross_origin, "location");

    // Verify location is in the cross-origin allowed list
    try testing.expect(WindowProxy.isCrossOriginAllowedProperty("location") != null);
}

test "WindowProxy - history is NOT cross-origin accessible" {
    // history is NOT in the cross-origin allowed list
    // (history.length reveals browsing history which is sensitive)
    try testing.expect(WindowProxy.isCrossOriginAllowedProperty("history") == null);
}

test "WindowProxy - postMessage is cross-origin accessible" {
    // postMessage is the primary way to communicate cross-origin
    try testing.expect(WindowProxy.isCrossOriginAllowedProperty("postMessage") != null);
}

test "WindowProxy - close is cross-origin accessible" {
    // window.close() is allowed cross-origin (for popups)
    try testing.expect(WindowProxy.isCrossOriginAllowedProperty("close") != null);
}

test "WindowProxy - focus and blur are cross-origin accessible" {
    // focus/blur are allowed cross-origin
    try testing.expect(WindowProxy.isCrossOriginAllowedProperty("focus") != null);
    try testing.expect(WindowProxy.isCrossOriginAllowedProperty("blur") != null);
}

test "WindowProxy - document is NOT cross-origin accessible" {
    // document would allow reading DOM content
    try testing.expect(WindowProxy.isCrossOriginAllowedProperty("document") == null);
}

test "WindowProxy - localStorage is NOT cross-origin accessible" {
    // localStorage is origin-bound storage
    try testing.expect(WindowProxy.isCrossOriginAllowedProperty("localStorage") == null);
}

// ============================================================================
// BrowsingContext Group Tests
// ============================================================================

test "BrowsingContext - contexts have virtual group IDs" {
    const allocator = testing.allocator;

    const ctx1 = try BrowsingContext.initTopLevel(allocator);
    defer ctx1.deinit();

    const ctx2 = try BrowsingContext.initTopLevel(allocator);
    defer ctx2.deinit();

    // Each context has a virtual_group_id
    // Top-level contexts have their own IDs
    try testing.expect(ctx1.virtual_group_id != 0);
    try testing.expect(ctx2.virtual_group_id != 0);
}

test "BrowsingContext - isScriptClosable for auxiliary" {
    const allocator = testing.allocator;

    const opener = try BrowsingContext.initTopLevel(allocator);
    defer opener.deinit();

    // Top-level context is not script closable by default
    try testing.expect(!opener.isScriptClosable());

    // Auxiliary (popup) context is script closable
    const aux = try BrowsingContext.initAuxiliary(allocator, opener, true);
    defer aux.deinit();

    try testing.expect(aux.isScriptClosable());
}
