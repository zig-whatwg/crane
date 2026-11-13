//! Attribute values as counted, interned per-Browser records and attribute
//! names as u32 ids (lane nd2 batch 2: A1 + A2; tmp/redesign/
//! node-memory-plan-v2.md I7, I8; the integrator's decision of 2026-11-10
//! 19:41 UTC).
//!
//! An element's attribute block is a header and 8-byte entries {name id,
//! value id}; a value is ONE record its Browser shares among every
//! attribute that has it now (Blink's and WebKit's AtomString values), freed
//! with its last reference. A growth of the block moves ids, never bytes, so
//! a value view is the record's bytes, stable while the record is counted -
//! and a holder across a point where script can run counts it.
//!
//! The first test is the integrator's red test: a change step that runs
//! "script" - appends to the same element and removes the attribute - while
//! a later step still reads the old and new values. On main the new value's
//! buffer and the data-* name record are freed by the removal, and the
//! later step reads 0xAA (std.testing.allocator poisons a free). No real
//! path reaches it today (img's src step, the one step that runs script, runs
//! last), so the test installs its own two steps (attribute_change_steps
//! .overrideForTest).
//!
//! These name only generated interfaces and src/dom: no impl (AGENTS.md "The
//! impls boundary").

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const infra = @import("infra");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try self.element("div");
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    fn element(self: *Page, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, str(name), .{ .was_passed = false, .value = undefined });
    }

    fn child(self: *Page, name: []const u8) !*runtime.Instance {
        const el = try self.element(name);
        _ = try interfaces.Node.call_appendChild(self.div, el);
        return el;
    }

    fn set(el: *runtime.Instance, name: []const u8, value: []const u8) !void {
        try interfaces.Element.call_setAttribute(el, str(name), .{ .domstring = str(value) });
    }

    fn remove(el: *runtime.Instance, name: []const u8) !void {
        try interfaces.Element.call_removeAttribute(el, str(name));
    }

    /// The values an attribute (or a holder) counts now - not the parked.
    fn values(self: *Page) usize {
        const table = dom.attribute_values.tableOf(&self.scope) orelse return 0;
        return table.liveCount();
    }

    fn names(self: *Page) usize {
        const table = dom.attribute_names.tableOf(&self.scope) orelse return 0;
        return table.count();
    }
};

// ============================================================================
// The red test: a step that changes the element, then a step that reads
// ============================================================================

/// The two steps the test installs, and what the second saw.
const Steps = struct {
    /// What the later step was handed for "data-v", copied at once.
    const Seen = struct { old: ?[]u8, new: ?[]u8 };
    var seen: std.ArrayList(Seen) = .empty;
    var acted = false;

    /// Runs first (the namespace-wide attribute steps run before the
    /// element type's): on data-v's change to "two", "script" grows the
    /// same element's list past its capacity and removes data-v.
    fn script(element: *runtime.Instance, local_name: []const u8, _: ?[]const u8, value: ?[]const u8, _: ?[]const u8) void {
        _ = local_name;
        const new = value orelse return;
        if (acted or !std.mem.eql(u8, new, "two")) return;
        acted = true;
        var i: usize = 0;
        while (i < 20) : (i += 1) {
            var buffer: [16]u8 = undefined;
            const name = std.fmt.bufPrint(&buffer, "a{d}", .{i}) catch unreachable;
            dom.element_attributes.set(element, name, "x", .{}) catch @panic("set");
        }
        dom.element_attributes.remove(element, null, "data-v");
    }

    /// Runs after: copies the name and values it is handed for data-v.
    fn later(_: *runtime.Instance, local_name: []const u8, old: ?[]const u8, value: ?[]const u8, _: ?[]const u8) void {
        if (!std.mem.eql(u8, local_name, "data-v")) return;
        seen.append(testing.allocator, .{
            .old = if (old) |o| testing.allocator.dupe(u8, o) catch @panic("oom") else null,
            .new = if (value) |v| testing.allocator.dupe(u8, v) catch @panic("oom") else null,
        }) catch @panic("oom");
    }

    fn reset() void {
        for (seen.items) |item| {
            if (item.old) |o| testing.allocator.free(o);
            if (item.new) |n| testing.allocator.free(n);
        }
        seen.deinit(testing.allocator);
        seen = .empty;
        acted = false;
    }
};

fn expectSeen(index: usize, old: ?[]const u8, new: ?[]const u8) !void {
    try testing.expect(index < Steps.seen.items.len);
    const item = Steps.seen.items[index];
    if (old) |o| try testing.expectEqualStrings(o, item.old orelse return error.OldMissing) else try testing.expect(item.old == null);
    if (new) |n| try testing.expectEqualStrings(n, item.new orelse return error.NewMissing) else try testing.expect(item.new == null);
}

test "a change step whose script grows the list and removes the attribute leaves the later step's name, old and new values readable" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const override = dom.attribute_change_steps.overrideForTest();
    defer override.restore();
    defer Steps.reset();
    dom.attribute_change_steps.installForAttribute(infra.namespaces.HTML_NAMESPACE, "data-v", .{ .change = &Steps.script });
    dom.attribute_change_steps.install("div", &Steps.later);

    try Page.set(page.div, "data-v", "one");
    try Page.set(page.div, "data-v", "two");

    // The later step saw, in order: the append ("one"), the removal inside
    // the script ("two" -> null), and the change it ran after - its name,
    // "one" and "two", read after the script removed the attribute.
    try testing.expectEqual(@as(usize, 3), Steps.seen.items.len);
    try expectSeen(0, null, "one");
    try expectSeen(1, "two", null);
    try expectSeen(2, "one", "two");
    var value = try interfaces.Element.call_getAttribute(page.div, str("data-v"));
    defer if (value) |*v| v.deinit(page.ctx.allocator);
    try testing.expect(value == null);
    // The holds were let go: data-v's name record is freed (the twenty a<n>
    // the script appended keep theirs), and only their one value "x" lives.
    try testing.expectEqual(@as(usize, 20), page.names());
    try testing.expectEqual(@as(usize, 1), page.values());
}

// ============================================================================
// Sharing, lifetime, growth
// ============================================================================

test "elements with the same value share one record, freed with the last" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const a = try page.child("span");
    const b = try page.child("p");
    try Page.set(a, "class", "btn btn-primary btn-large");
    try Page.set(b, "class", "btn btn-primary btn-large");
    try Page.set(b, "title", "btn btn-primary btn-large");
    try testing.expectEqual(@as(usize, 1), page.values());
    try Page.set(a, "class", "other");
    try testing.expectEqual(@as(usize, 2), page.values());
    try Page.remove(b, "class");
    try Page.remove(b, "title");
    try testing.expectEqual(@as(usize, 1), page.values());
    try Page.remove(a, "class");
    try testing.expectEqual(@as(usize, 0), page.values());
    // The empty value has no record.
    try Page.set(a, "hidden", "");
    try testing.expectEqual(@as(usize, 0), page.values());
}

test "a value changed in a loop keeps one record alive, and a data-* name dies with its last attribute" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const el = try page.child("span");
    var i: usize = 0;
    while (i < 5_000) : (i += 1) {
        var buffer: [24]u8 = undefined;
        try Page.set(el, "data-x", try std.fmt.bufPrint(&buffer, "value {d}", .{i}));
    }
    try testing.expectEqual(@as(usize, 1), page.values());
    try testing.expectEqual(@as(usize, 1), page.names());
    var value = (try interfaces.Element.call_getAttribute(el, str("data-x"))).?;
    defer value.deinit(page.ctx.allocator);
    try testing.expectEqualStrings("value 4999", value.asSlice());
    try Page.remove(el, "data-x");
    try testing.expectEqual(@as(usize, 0), page.values());
    try testing.expectEqual(@as(usize, 0), page.names());
}

test "a clone shares its source's list (lane nd2 batch 4), and no new record" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const el = try page.child("span");
    const attrs = [_][]const u8{ "id", "class", "title", "data-a", "data-b" };
    for (attrs) |name| try Page.set(el, name, "shared value");
    try testing.expectEqual(@as(usize, 1), page.values());
    // Script's appends grew the source 1, 4, 8.
    try testing.expectEqual(@as(usize, 8), dom.element_data.of(el).?.data.attrs.?.capacity());
    const clone = try interfaces.Node.call_cloneNode(el, .{ .was_passed = true, .value = false });
    // The clone holds the source's block - the source's own list became a
    // shared one in place (plan-v2 A3) - and no new record.
    const block = dom.element_data.of(el).?.data.attrs.?;
    try testing.expect(dom.element_data.of(clone).?.data.attrs.? == block);
    try testing.expectEqual(@as(u8, 2), block.holders);
    try testing.expectEqual(@as(usize, 1), page.values());
    try testing.expectEqual(@as(usize, 2), page.names());
    const view = dom.element_data.of(clone).?;
    for (attrs, 0..) |name, i| {
        const entry = view.attributeAt(i).?;
        try testing.expectEqualStrings(name, entry.local_name);
        try testing.expectEqualStrings("shared value", entry.value);
    }
    // The source's first removal copies the list (copy on write), taking
    // references on the records: the clone keeps the block and its records.
    for (attrs) |name| try Page.remove(el, name);
    try testing.expectEqual(@as(usize, 1), page.values());
    try testing.expectEqual(@as(usize, 2), page.names());
    try testing.expectEqualStrings("shared value", dom.element_data.of(clone).?.idValue());
}

test "a value read before its element's list grew still reads its bytes after" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const el = try page.child("span");
    try Page.set(el, "data-first", "first value");
    const before = dom.element_data.of(el).?.findAttribute(null, "data-first").?;
    const block = @intFromPtr(dom.element_data.of(el).?.data.attrs.?);
    var i: usize = 0;
    while (i < 40) : (i += 1) {
        var buffer: [16]u8 = undefined;
        try Page.set(el, try std.fmt.bufPrint(&buffer, "a{d}", .{i}), "x");
    }
    try testing.expect(@intFromPtr(dom.element_data.of(el).?.data.attrs.?) != block);
    try testing.expectEqualStrings("first value", before.value);
    try testing.expectEqualStrings("data-first", before.local_name);
}
