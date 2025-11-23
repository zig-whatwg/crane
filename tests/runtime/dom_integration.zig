//! DOM Integration Tests
//!
//! Demonstrates how Document and Element interfaces integrate with a V8-like JS engine.
//! Shows realistic binding patterns and object lifecycle management.

const std = @import("std");
const runtime = @import("runtime");
const mock_js = @import("mock_jsengine.zig");

// Import generated interfaces
const Document = @import("interfaces").Document;
const Element = @import("interfaces").Element;

test "DOM integration - Document and Element lifecycle" {
    const allocator = std.testing.allocator;

    // Create mock V8 isolate (JS VM)
    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    // Create HandleScope (manages Local<T> lifetime)
    const scope = try mock_js.HandleScope.create(context);
    defer scope.destroy();

    // Create a Document instance (like 'new Document()' in JS)
    const doc_instance = try Document.init(allocator, ctx);
    const doc_handle = try mock_js.ObjectHandle.createLocal(context, doc_instance, "Document");

    // Create an Element instance (like 'document.createElement("div")' in JS)
    const elem_instance = try Element.init(allocator, ctx);
    const elem_handle = try mock_js.ObjectHandle.createLocal(context, elem_instance, "Element");

    // Verify context is properly threaded through
    try std.testing.expectEqual(ctx, doc_instance.ctx);
    try std.testing.expectEqual(ctx, elem_instance.ctx);

    // Verify instances are wrapped in handles
    try std.testing.expectEqual(doc_instance, doc_handle.unwrap());
    try std.testing.expectEqual(elem_instance, elem_handle.unwrap());

    // Verify interface names
    try std.testing.expectEqualStrings("Document", doc_handle.interface_name);
    try std.testing.expectEqualStrings("Element", elem_handle.interface_name);
}

test "DOM integration - Persistent handles survive HandleScope" {
    const allocator = std.testing.allocator;

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    // Create a persistent Document (like storing in a global variable)
    const doc_instance = try Document.init(allocator, ctx);
    const doc_persistent = try mock_js.ObjectHandle.createPersistent(context, doc_instance, "Document");

    {
        // Create temporary HandleScope
        const scope = try mock_js.HandleScope.create(context);
        defer scope.destroy();

        // Create local Element (dies when scope exits)
        const elem_instance = try Element.init(allocator, ctx);
        const elem_local = try mock_js.ObjectHandle.createLocal(context, elem_instance, "Element");

        // Both are valid within the scope
        try std.testing.expectEqual(doc_instance, doc_persistent.unwrap());
        try std.testing.expectEqual(elem_instance, elem_local.unwrap());
    }
    // HandleScope destroyed, local Element cleaned up

    // Persistent Document still alive
    try std.testing.expectEqual(doc_instance, doc_persistent.unwrap());
    try std.testing.expect(doc_persistent.persistent);
}

test "DOM integration - Global object registration" {
    const allocator = std.testing.allocator;

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();
    context.global_object = std.StringHashMap(*mock_js.ObjectHandle).init(allocator);
    defer context.global_object.deinit();

    // Register global 'document' object (like window.document)
    const doc_instance = try Document.init(allocator, ctx);
    const doc_handle = try mock_js.ObjectHandle.createPersistent(context, doc_instance, "Document");
    try context.setGlobalConstructor("document", doc_handle);

    // Retrieve it (simulating JS accessing 'document')
    const retrieved = context.getGlobalConstructor("document");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(doc_handle, retrieved.?);
    try std.testing.expectEqualStrings("Document", retrieved.?.interface_name);
}

test "DOM integration - Property access simulation" {
    const allocator = std.testing.allocator;

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    const scope = try mock_js.HandleScope.create(context);
    defer scope.destroy();

    // Create Element
    const elem_instance = try Element.init(allocator, ctx);
    const elem_handle = try mock_js.ObjectHandle.createLocal(context, elem_instance, "Element");

    // Simulate property callback info (like elem.tagName getter)
    var prop_info = mock_js.PropertyCallbackInfo{
        .context = context,
        .this = elem_handle,
        .return_value = null,
    };

    // The binding would call Element.get_tagName(instance)
    // For this test, we just verify the structure exists
    try std.testing.expectEqual(elem_instance, prop_info.getThis().unwrap());
}

test "DOM integration - Method call simulation" {
    const allocator = std.testing.allocator;

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    const scope = try mock_js.HandleScope.create(context);
    defer scope.destroy();

    // Create Element
    const elem_instance = try Element.init(allocator, ctx);
    const elem_handle = try mock_js.ObjectHandle.createLocal(context, elem_instance, "Element");

    // Simulate function callback info (like elem.getAttribute("id"))
    const arg_value = try mock_js.createString(context, "id");
    const args = [_]*mock_js.ObjectHandle{};

    var func_info = mock_js.FunctionCallbackInfo{
        .context = context,
        .this = elem_handle,
        .args = &args,
        .return_value = null,
    };

    // The binding would call Element.call_getAttribute(instance, "id")
    try std.testing.expectEqual(elem_instance, func_info.getThis().?.unwrap());
    try std.testing.expectEqual(context, func_info.getContext());
    _ = arg_value;
}

test "DOM integration - Multiple Elements with same Document context" {
    const allocator = std.testing.allocator;

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    const scope = try mock_js.HandleScope.create(context);
    defer scope.destroy();

    // Create Document
    const doc_instance = try Document.init(allocator, ctx);
    _ = try mock_js.ObjectHandle.createLocal(context, doc_instance, "Document");

    // Create multiple Elements (like document.createElement() multiple times)
    const elem1 = try Element.init(allocator, ctx);
    const elem2 = try Element.init(allocator, ctx);
    const elem3 = try Element.init(allocator, ctx);

    const handle1 = try mock_js.ObjectHandle.createLocal(context, elem1, "Element");
    const handle2 = try mock_js.ObjectHandle.createLocal(context, elem2, "Element");
    const handle3 = try mock_js.ObjectHandle.createLocal(context, elem3, "Element");

    // All share same context
    try std.testing.expectEqual(ctx, elem1.ctx);
    try std.testing.expectEqual(ctx, elem2.ctx);
    try std.testing.expectEqual(ctx, elem3.ctx);

    // All are distinct instances
    try std.testing.expect(elem1 != elem2);
    try std.testing.expect(elem2 != elem3);
    try std.testing.expect(elem1 != elem3);

    // All have distinct handles
    try std.testing.expect(handle1 != handle2);
    try std.testing.expect(handle2 != handle3);
    try std.testing.expect(handle1 != handle3);
}

test "DOM integration - Context pointer extraction" {
    const allocator = std.testing.allocator;

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    const scope = try mock_js.HandleScope.create(context);
    defer scope.destroy();

    // Create Element with context
    const elem_instance = try Element.init(allocator, ctx);

    // Extract context from instance (needed for callbacks)
    const extracted_ctx: *mock_js.Context = @ptrCast(@alignCast(elem_instance.ctx.?));

    // Verify we can get back to the isolate
    try std.testing.expectEqual(isolate, extracted_ctx.isolate);
    try std.testing.expectEqual(context, extracted_ctx);
}

test "DOM integration - Memory tracking across objects" {
    const allocator = std.testing.allocator;

    const isolate = try mock_js.Isolate.create(allocator);
    defer isolate.destroy();

    const context = isolate.getCurrentContext();
    const ctx = context.asRuntimeContext();

    // Track initial object count
    const initial_count = context.objects.items.len;

    {
        const scope = try mock_js.HandleScope.create(context);
        defer scope.destroy();

        // Create persistent objects
        const doc_instance = try Document.init(allocator, ctx);
        _ = try mock_js.ObjectHandle.createPersistent(context, doc_instance, "Document");

        const elem_instance = try Element.init(allocator, ctx);
        _ = try mock_js.ObjectHandle.createPersistent(context, elem_instance, "Element");

        // Verify tracking
        try std.testing.expectEqual(initial_count + 2, context.objects.items.len);
    }

    // Persistent objects still tracked after scope exit
    try std.testing.expectEqual(initial_count + 2, context.objects.items.len);
}
