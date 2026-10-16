//! Form name-cache lifetime and invalidation, through the generated interface.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const forms = @import("html").form_associated;
const testing = std.testing;

fn append(document: *runtime.Instance, parent: *runtime.Instance, tag: []const u8) !*runtime.Instance {
    const element = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(tag), .notPassed());
    errdefer dom.node_creation.destroyUninserted(element);
    _ = try interfaces.Node.call_appendChild(parent, element);
    return element;
}

fn attribute(element: *runtime.Instance, key: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned(key), .{ .domstring = runtime.DOMString.initInterned(value) });
}

fn names(form: *runtime.Instance, expected: []const []const u8) !void {
    const result = try interfaces.HTMLFormElement.getSupportedPropertyNames(form, testing.allocator);
    defer {
        for (result) |*name| name.deinit(testing.allocator);
        testing.allocator.free(result);
    }
    try testing.expectEqual(expected.len, result.len);
    for (expected, result) |want, actual| try testing.expectEqualStrings(want, actual.asSlice());
}

const Scenario = enum { cached_read, mutations, allocation_failure, parser_association };

fn exercise(comptime scenario: Scenario) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var realm_allocations = testing.FailingAllocator.init(testing.allocator, .{});
    const object_allocator = realm_allocations.allocator();
    var context = try runtime.ContextData.init(object_allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(object_allocator, &context);
    defer interfaces.Document.deinit(document);
    const other_document = try interfaces.Document.init(object_allocator, &context);
    defer interfaces.Document.deinit(other_document);
    const root = try append(document, document, "div");
    const other_root = try append(other_document, other_document, "div");
    const form = try append(document, root, "form");
    try attribute(form, "id", "f");
    const input = try append(document, form, "input");
    try attribute(input, "name", "field");
    try names(form, &.{"field"});

    if (scenario == .parser_association) {
        // dom_parser associates its converted controls after insertion.
        // Cover the hook itself, including a previously observed form.
        const image = try append(document, root, "img");
        try attribute(image, "name", "parsedImage");
        try names(form, &.{"field"});
        // Recording the association moves the tree version (formnamed):
        // every cache of form membership keyed on it reads again.
        const before_association = dom.live_collections.treeVersion(document).?;
        try forms.parserAssociate(image, form, root);
        try testing.expect(dom.live_collections.treeVersion(document).? != before_association);
        try names(form, &.{ "field", "parsedImage" });
        return;
    }

    if (scenario == .allocation_failure) {
        // The list is the caller's (formnamed): a failure at any of its
        // allocations - a string copy or the array's growth - frees what it
        // made (the testing allocator's leak check) and publishes nothing.
        // A failed rebuild of the form's own cache is
        // tests/html/fn_form_named_cache_test.zig's.
        try attribute(input, "id", "identifier");
        for ([_][]const u8{ "replacement", "again", "last" }, 0..) |replacement, failure_offset| {
            try attribute(input, "name", replacement);
            var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = failure_offset });
            const attempt = interfaces.HTMLFormElement.getSupportedPropertyNames(form, failing.allocator());
            if (attempt) |result| {
                for (result) |*name| name.deinit(testing.allocator);
                testing.allocator.free(result);
                return error.ExpectedCacheAllocationFailure;
            } else |err| try testing.expect(err == error.OutOfMemory);
            try names(form, &.{ "identifier", replacement });
        }
        return;
    }

    if (scenario == .cached_read) {
        // A read allocates the caller-owned return value - the array and,
        // since formnamed (review-codex-lpo-m1 S2), its strings - but must
        // not copy attributes or allocate traversal data in the realm. The
        // elements retain this allocator from construction, so blocking it
        // also catches getAttribute copies using their own stored allocator.
        // The per-name question every property read asks allocates nothing
        // at all (tests/html/fn_form_named_cache_test.zig).
        realm_allocations.fail_index = realm_allocations.alloc_index;
        defer realm_allocations.fail_index = std.math.maxInt(usize);
        const output_allocator = testing.allocator;
        const result = try interfaces.HTMLFormElement.getSupportedPropertyNames(form, output_allocator);
        defer {
            for (result) |*name| name.deinit(output_allocator);
            output_allocator.free(result);
        }
        try testing.expectEqual(@as(usize, 1), result.len);
        try testing.expectEqualStrings("field", result[0].asSlice());
        return;
    }

    const external = try append(document, root, "input");
    try attribute(external, "name", "outside");
    const version = dom.live_collections.treeVersion(document).?;
    try attribute(external, "form", "f");
    try testing.expectEqual(false, dom.live_collections.treeVersion(document).? == version);
    try names(form, &.{ "field", "outside" });
    const id_version = dom.live_collections.treeVersion(document).?;
    try attribute(form, "id", "renamed");
    try testing.expect(dom.live_collections.treeVersion(document).? != id_version);
    try names(form, &.{"field"});
    try attribute(input, "name", "changed");
    try names(form, &.{"changed"});
    try attribute(input, "type", "image");
    try names(form, &.{});
    try attribute(input, "type", "text");
    try names(form, &.{"changed"});
    try attribute(external, "form", "renamed");
    try names(form, &.{ "changed", "outside" });
    _ = try interfaces.Node.call_appendChild(other_root, form);
    try names(form, &.{"changed"});
    _ = try interfaces.Node.call_removeChild(other_root, form);
    defer dom.node_creation.destroyUninserted(form);
    try names(form, &.{"changed"});

    // The parser associates before insertion; insertion is the versioned
    // boundary before author script can observe the new listed element.
    const parser_form = try append(document, root, "form");
    try names(parser_form, &.{});
    const parsed = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("input"), .notPassed());
    try attribute(parsed, "name", "parsed");
    const parser_version = dom.live_collections.treeVersion(document).?;
    try forms.parserAssociate(parsed, parser_form, root);
    _ = try interfaces.Node.call_appendChild(root, parsed);
    try testing.expect(dom.live_collections.treeVersion(document).? != parser_version);
    try names(parser_form, &.{"parsed"});
}

fn onThread(comptime scenario: Scenario) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(scenario) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "form supported names allocate only the returned list" {
    try onThread(.cached_read);
}

test "form names follow form id name type adoption and detached-tree changes" {
    try onThread(.mutations);
}

test "a failed form name-cache rebuild leaves no partial result or allocation" {
    try onThread(.allocation_failure);
}

test "form names follow a parser association established after insertion" {
    try onThread(.parser_association);
}
