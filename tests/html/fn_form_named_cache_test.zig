//! A form's named properties and its elements collection, read from caches
//! kept under the node document's tree version (lane formnamed; codex-lpo
//! review M1): a property read on a form asks "is P a supported property
//! name?" for one P (WebIDL 3.9.7 step 1), and the answer must neither walk
//! the document nor allocate while nothing changed - and must follow every
//! change that can make a different answer, including the two changes of
//! form association that are not tree mutations (a parser association
//! recorded after insertion, a form-associated custom element's upgrade,
//! tests/html/lpo_form_cache_upgrade_test.zig).
//!
//! Engine-free: the realm has no agent, so no past names are recorded here
//! (tests/html/fn_form_past_names_test.zig has those).
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

fn supported(form: *runtime.Instance, name: []const u8) !bool {
    return interfaces.HTMLFormElement.isSupportedPropertyName(form, runtime.DOMString.initInterned(name));
}

/// The named getter's element, or null for undefined; a list is an error.
fn named(form: *runtime.Instance, name: []const u8) !?*runtime.Instance {
    const value = try interfaces.HTMLFormElement.call_getter__1(form, runtime.DOMString.initInterned(name));
    return switch (value) {
        .instance => |instance| if (instance.stateAs(interfaces.RadioNodeList.State) == null) instance else error.UnexpectedList,
        else => null,
    };
}

fn length(form: *runtime.Instance) !u32 {
    return interfaces.HTMLFormElement.get_length(form);
}

const Scenario = enum { follows_changes, unchanged_reads_allocate_nothing, failed_rebuild, owned_names };

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
    const root = try append(document, document, "div");
    const form = try append(document, root, "form");
    try attribute(form, "id", "f");
    const input = try append(document, form, "input");
    try attribute(input, "name", "field");
    try attribute(input, "id", "fieldId");
    const image = try append(document, form, "img");
    try attribute(image, "name", "picture");
    try testing.expect(try supported(form, "field"));
    try testing.expect(try supported(form, "fieldId"));
    try testing.expect(try supported(form, "picture"));
    try testing.expect(!(try supported(form, "")));
    try testing.expect(!(try supported(form, "missing")));
    try testing.expectEqual(@as(u32, 1), try length(form));

    switch (scenario) {
        .follows_changes => {
            // An image button is listed but has no name here (steps 2 and 1).
            try attribute(input, "type", "image");
            try testing.expect(!(try supported(form, "field")));
            try testing.expectEqual(@as(u32, 0), try length(form));
            try attribute(input, "type", "text");
            try testing.expect(try supported(form, "field"));
            try testing.expectEqual(input, (try named(form, "field")).?);
            // Renamed: the old name goes (no agent, so no past name).
            try attribute(input, "name", "renamed");
            try testing.expect(!(try supported(form, "field")));
            try testing.expect(try supported(form, "renamed"));
            // A control outside the form joins it through the form attribute,
            // and leaves when the form's id changes.
            const outside = try append(document, root, "input");
            try attribute(outside, "name", "outside");
            try testing.expect(!(try supported(form, "outside")));
            try testing.expectEqual(@as(u32, 1), try length(form));
            try attribute(outside, "form", "f");
            try testing.expect(try supported(form, "outside"));
            try testing.expectEqual(@as(u32, 2), try length(form));
            try attribute(form, "id", "other");
            try testing.expect(!(try supported(form, "outside")));
            try testing.expectEqual(@as(u32, 1), try length(form));
            // A parser association recorded after insertion (the inert
            // parser's) moves no node: the version must still move.
            const parsed = try append(document, root, "input");
            try attribute(parsed, "name", "parsed");
            try testing.expect(!(try supported(form, "parsed")));
            try testing.expectEqual(@as(u32, 1), try length(form));
            try forms.parserAssociate(parsed, form, root);
            try testing.expect(try supported(form, "parsed"));
            try testing.expectEqual(@as(u32, 2), try length(form));
            try testing.expectEqual(parsed, (try interfaces.HTMLFormElement.call_getter(form, 1)));
            // The image leaves with its removal.
            _ = try interfaces.Node.call_removeChild(form, image);
            defer dom.node_creation.destroyUninserted(image);
            try testing.expect(!(try supported(form, "picture")));
            try testing.expectEqual(@as(?*runtime.Instance, null), try named(form, "picture"));
        },
        .unchanged_reads_allocate_nothing => {
            // Warm: the first query builds the cache under this version.
            try testing.expectEqual(input, (try named(form, "field")).?);
            try testing.expectEqual(image, (try named(form, "picture")).?);
            try testing.expectEqual(input, try interfaces.HTMLFormElement.call_getter(form, 0));
            const elements = try interfaces.HTMLFormElement.get_elements(form);
            // Nothing changed: no allocation in the realm, hit or miss,
            // named or indexed (the elements collection is cached too, and
            // its named lookup reads ids and names in place).
            realm_allocations.fail_index = realm_allocations.alloc_index;
            defer realm_allocations.fail_index = std.math.maxInt(usize);
            for (0..3) |_| {
                try testing.expect(try supported(form, "field"));
                try testing.expect(try supported(form, "picture"));
                try testing.expect(!(try supported(form, "submit")));
                try testing.expect(!(try supported(form, "method")));
                try testing.expectEqual(input, (try named(form, "fieldId")).?);
                try testing.expectEqual(input, try interfaces.HTMLFormElement.call_getter(form, 0));
                try testing.expectEqual(@as(u32, 1), try length(form));
                try testing.expect(try interfaces.HTMLFormControlsCollection.isSupportedPropertyName(elements, runtime.DOMString.initInterned("field")));
                try testing.expect(try interfaces.HTMLFormControlsCollection.isSupportedPropertyName(elements, runtime.DOMString.initInterned("fieldId")));
                try testing.expect(!(try interfaces.HTMLFormControlsCollection.isSupportedPropertyName(elements, runtime.DOMString.initInterned("picture"))));
                const found = (try interfaces.HTMLFormControlsCollection.call_namedItem(elements, runtime.DOMString.initInterned("field"))).?;
                try testing.expectEqual(input, found.instance);
            }
        },
        .failed_rebuild => {
            // A rebuild that runs out of memory answers the error, keeps no
            // partial cache, and the next query rebuilds and answers right.
            for ([_][]const u8{ "one", "two", "three" }, 0..) |replacement, failure_offset| {
                try attribute(input, "name", replacement);
                realm_allocations.fail_index = realm_allocations.alloc_index + failure_offset;
                const attempt = supported(form, replacement);
                realm_allocations.fail_index = std.math.maxInt(usize);
                if (attempt) |answer| {
                    // The cache needed fewer allocations than the offset.
                    try testing.expect(answer);
                } else |err| try testing.expect(err == error.OutOfMemory);
                try testing.expect(try supported(form, replacement));
                try testing.expect(try supported(form, "fieldId"));
                try testing.expect(!(try supported(form, "field")));
            }
        },
        .owned_names => {
            // review-codex-lpo-m1 S2: the list is the caller's, strings
            // included - valid after the form's cache is rebuilt.
            const result = try interfaces.HTMLFormElement.getSupportedPropertyNames(form, testing.allocator);
            defer {
                for (result) |*name| name.deinit(testing.allocator);
                testing.allocator.free(result);
            }
            try attribute(input, "name", "rebuilt");
            try testing.expect(try supported(form, "rebuilt"));
            try testing.expectEqual(@as(usize, 3), result.len);
            try testing.expectEqualStrings("fieldId", result[0].asSlice());
            try testing.expectEqualStrings("field", result[1].asSlice());
            try testing.expectEqualStrings("picture", result[2].asSlice());
        },
    }
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

test "a form's named query and elements follow every change that makes a different answer" {
    try onThread(.follows_changes);
}

test "unchanged named and indexed reads on a form allocate nothing" {
    try onThread(.unchanged_reads_allocate_nothing);
}

test "a failed rebuild of a form's named cache keeps nothing partial" {
    try onThread(.failed_rebuild);
}

test "a form's supported property names are the caller's, strings included" {
    try onThread(.owned_names);
}
