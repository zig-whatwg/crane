//! A range over a tree of any depth extracts, clones, deletes and
//! stringifies its contents in constant native stack (lane crash1 batch 3;
//! the zero-crashes rule).
//!
//! DOM 5.5 "extract" and "clone the contents" are recursive: a partially
//! contained child's contents are those of a subrange, extracted or cloned
//! the same way, so a range whose start or end lies N levels below its
//! common ancestor recurses N times. Range.zig's `extract` and
//! `cloneTheContents` recursed in native code, one set of frames a level:
//! crash1 batch 2's 30,000-level sweep overflowed the stack in `extract`
//! (9,992 frames in the crash report). toString's contained-Text walk
//! recursed once per level too. They now keep the subrange levels on the
//! heap (Range.zig `processContents`), as Blink's
//! Range::ProcessAncestorsAndTheirSiblings walks a vector of ancestors and
//! Gecko's nsRange::CutContents / CloneContents walk a RangeSubtreeIterator
//! with CloneParentsBetween's explicit parent stack.
//!
//! Each test builds its chains natively, 10,000 divs deep, and runs the
//! method on a thread with a pinned native stack under std.testing.allocator:
//! 8 MiB, a main thread's, for extract and clone (a Debug build's recursion
//! took more than 800 bytes a level, so 10,000 levels overflowed it); 1 MiB
//! for toString and deleteContents, whose per-level frames were smaller.
//! The fixed walks use the same stack at any depth. The trees are not
//! deeper because building one costs O(nodes x depth) in a Debug build
//! today (each insert walks to the root: the deep-construction item).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const depth = 10_000;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// An engine-less HTML document with a body.
const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    body: *runtime.Instance = undefined,

    fn open(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(testing.allocator), .ctx = try runtime.ContextData.init(testing.allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.body = try self.element("body");
        _ = try interfaces.Node.call_appendChild(self.document, self.body);
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

    fn text(self: *Page, data: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createTextNode(self.document, str(data));
    }

    /// `levels` divs nested under `parent`, the deepest holding a Text node
    /// of `data`; answers that Text node. Built top-down, natively.
    fn chain(self: *Page, parent: *runtime.Instance, levels: usize, data: []const u8) !*runtime.Instance {
        var leaf = parent;
        for (0..levels) |_| {
            const div = try self.element("div");
            _ = try interfaces.Node.call_appendChild(leaf, div);
            leaf = div;
        }
        const node = try self.text(data);
        _ = try interfaces.Node.call_appendChild(leaf, node);
        return node;
    }

    /// A div child of the body holding a Text node of `data`; answers the
    /// Text node.
    fn shallow(self: *Page, data: []const u8) !*runtime.Instance {
        return self.chain(self.body, 1, data);
    }

    fn range(self: *Page, start: *runtime.Instance, start_offset: u32, end: *runtime.Instance, end_offset: u32) !*runtime.Instance {
        const r = try interfaces.Document.call_createRange(self.document);
        errdefer interfaces.Range.deinit(r);
        try interfaces.Range.call_setStart(r, start, start_offset);
        try interfaces.Range.call_setEnd(r, end, end_offset);
        return r;
    }
};

/// Run `body` with an open Page on a thread whose native stack is pinned at
/// `stack_size`.
fn onStack(comptime stack_size: usize, comptime body: fn (*Page) anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            runBody() catch |err| {
                failure.* = err;
            };
        }

        fn runBody() !void {
            var page: Page = undefined;
            try page.open();
            defer page.close();
            try body(&page);
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{ .stack_size = stack_size }, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// How many levels below `root` its first-child chain goes, and the node at
/// its end.
fn firstChildChain(root: *runtime.Instance) !struct { levels: usize, leaf: *runtime.Instance } {
    var at = root;
    var levels: usize = 0;
    while (try interfaces.Node.get_firstChild(at)) |child| {
        at = child;
        levels += 1;
    }
    return .{ .levels = levels, .leaf = at };
}

fn expectData(node: *runtime.Instance, want: []const u8) !void {
    var data = try interfaces.CharacterData.get_data(node);
    defer data.deinit(node.ctx.allocator);
    try testing.expectEqualStrings(want, data.asSlice());
}

fn childAt(node: *runtime.Instance, index: usize) !*runtime.Instance {
    var child = try interfaces.Node.get_firstChild(node);
    var i: usize = 0;
    while (child) |c| : (i += 1) {
        if (i == index) return c;
        child = try interfaces.Node.get_nextSibling(c);
    }
    return error.NoSuchChild;
}

fn childCount(node: *runtime.Instance) !usize {
    var count: usize = 0;
    var child = try interfaces.Node.get_firstChild(node);
    while (child) |c| : (child = try interfaces.Node.get_nextSibling(c)) count += 1;
    return count;
}

/// The range is collapsed at (`node`, `offset`).
fn expectCollapsedAt(r: *runtime.Instance, node: *runtime.Instance, offset: u32) !void {
    try testing.expect(try interfaces.AbstractRange.get_collapsed(r));
    try testing.expectEqual(node, try interfaces.AbstractRange.get_startContainer(r));
    try testing.expectEqual(offset, try interfaces.AbstractRange.get_startOffset(r));
}

test "extractContents: a start 10,000 levels below the common ancestor comes out as one clone chain" {
    try onStack(8 * 1024 * 1024, struct {
        fn body(page: *Page) !void {
            const start = try page.chain(page.body, depth, "abcd");
            const mid = try page.shallow("MID");
            const mid_div = (try interfaces.Node.get_parentNode(mid)).?;
            const end = try page.shallow("wxyz");
            const r = try page.range(start, 2, end, 2);
            defer interfaces.Range.deinit(r);

            const fragment = try interfaces.Range.call_extractContents(r);
            defer dom.node_creation.destroyUninserted(fragment);

            // Step 17: a clone of every level from the body's child down to the
            // start, holding the start's data from its offset on.
            try testing.expectEqual(@as(usize, 3), try childCount(fragment));
            const left = try firstChildChain(try childAt(fragment, 0));
            try testing.expectEqual(@as(usize, depth), left.levels);
            try expectData(left.leaf, "cd");
            try expectData(start, "ab");
            // Step 18: the contained child moved; step 20: the end's side.
            try testing.expectEqual(mid_div, try childAt(fragment, 1));
            try expectData(try interfaces.Node.get_firstChild(try childAt(fragment, 2)) orelse return error.NoText, "wx");
            try expectData(end, "yz");
            // Step 15: (the body, the start's top level's index + 1).
            try expectCollapsedAt(r, page.body, 1);
            try testing.expectEqual(@as(usize, 2), try childCount(page.body));
        }
    }.body);
}

test "extractContents: an end 10,000 levels below the common ancestor comes out as one clone chain" {
    try onStack(8 * 1024 * 1024, struct {
        fn body(page: *Page) !void {
            const start = try page.shallow("abcd");
            const mid = try page.shallow("MID");
            const mid_div = (try interfaces.Node.get_parentNode(mid)).?;
            const end = try page.chain(page.body, depth, "wxyz");
            const r = try page.range(start, 2, end, 2);
            defer interfaces.Range.deinit(r);

            const fragment = try interfaces.Range.call_extractContents(r);
            defer dom.node_creation.destroyUninserted(fragment);

            try testing.expectEqual(@as(usize, 3), try childCount(fragment));
            try expectData(try interfaces.Node.get_firstChild(try childAt(fragment, 0)) orelse return error.NoText, "cd");
            try expectData(start, "ab");
            try testing.expectEqual(mid_div, try childAt(fragment, 1));
            // Step 20: a clone of every level from the body's child down to the
            // end, holding the end's data up to its offset.
            const right = try firstChildChain(try childAt(fragment, 2));
            try testing.expectEqual(@as(usize, depth), right.levels);
            try expectData(right.leaf, "wx");
            try expectData(end, "yz");
            try expectCollapsedAt(r, page.body, 1);
        }
    }.body);
}

test "cloneContents: a start and an end 10,000 levels deep clone as two chains, the tree untouched" {
    try onStack(8 * 1024 * 1024, struct {
        fn body(page: *Page) !void {
            const start = try page.chain(page.body, depth, "abcd");
            _ = try page.shallow("MID");
            const end = try page.chain(page.body, depth, "wxyz");
            const r = try page.range(start, 2, end, 2);
            defer interfaces.Range.deinit(r);

            const fragment = try interfaces.Range.call_cloneContents(r);
            defer dom.node_creation.destroyUninserted(fragment);

            try testing.expectEqual(@as(usize, 3), try childCount(fragment));
            const left = try firstChildChain(try childAt(fragment, 0));
            try testing.expectEqual(@as(usize, depth), left.levels);
            try expectData(left.leaf, "cd");
            // Step 15: a deep clone of the contained child.
            try expectData(try interfaces.Node.get_firstChild(try childAt(fragment, 1)) orelse return error.NoText, "MID");
            const right = try firstChildChain(try childAt(fragment, 2));
            try testing.expectEqual(@as(usize, depth), right.levels);
            try expectData(right.leaf, "wx");
            // Nothing moved or changed.
            try expectData(start, "abcd");
            try expectData(end, "wxyz");
            try testing.expectEqual(@as(usize, 3), try childCount(page.body));
            try testing.expectEqual(start, try interfaces.AbstractRange.get_startContainer(r));
        }
    }.body);
}

test "deleteContents: a range from 10,000 levels deep to 10,000 levels deep" {
    try onStack(1024 * 1024, struct {
        fn body(page: *Page) !void {
            const start = try page.chain(page.body, depth, "abcd");
            _ = try page.shallow("MID");
            const end = try page.chain(page.body, depth, "wxyz");
            const r = try page.range(start, 2, end, 2);
            defer interfaces.Range.deinit(r);

            try interfaces.Range.call_deleteContents(r);

            try expectData(start, "ab");
            try expectData(end, "yz");
            // The contained div went; both chains stayed whole.
            try testing.expectEqual(@as(usize, 2), try childCount(page.body));
            try testing.expectEqual(@as(usize, depth), (try firstChildChain(try childAt(page.body, 0))).levels);
            try testing.expectEqual(@as(usize, depth), (try firstChildChain(try childAt(page.body, 1))).levels);
            try expectCollapsedAt(r, page.body, 1);
        }
    }.body);
}

test "toString: a range from 10,000 levels deep to 10,000 levels deep" {
    try onStack(1024 * 1024, struct {
        fn body(page: *Page) !void {
            const start = try page.chain(page.body, depth, "abcd");
            const mid = try page.shallow("MID");
            // A contained element's Text descendants count, at any depth.
            _ = try page.chain((try interfaces.Node.get_parentNode(mid)).?, 3, "-in-");
            const end = try page.chain(page.body, depth, "wxyz");
            const r = try page.range(start, 2, end, 2);
            defer interfaces.Range.deinit(r);

            const s = try interfaces.Range.serialize(r);
            defer r.ctx.allocator.free(s);
            try testing.expectEqualStrings("cdMID-in-wx", s);
        }
    }.body);
}

test "toString: a CDATASection is a Text node - at the boundaries and contained" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    // CDATA sections exist only in XML documents.
    const xml = try interfaces.DOMImplementation.call_createDocument(
        try interfaces.Document.get_implementation(page.document),
        null,
        str("root"),
        .notPassed(),
    );
    defer interfaces.XMLDocument.deinit(xml);
    const root = (try interfaces.Document.get_documentElement(xml)).?;
    const first = try interfaces.Document.call_createCDATASection(xml, str("abcd"));
    _ = try interfaces.Node.call_appendChild(root, first);
    const middle = try interfaces.Document.call_createCDATASection(xml, str("MID"));
    _ = try interfaces.Node.call_appendChild(root, middle);
    const last = try interfaces.Document.call_createCDATASection(xml, str("wxyz"));
    _ = try interfaces.Node.call_appendChild(root, last);

    const r = try interfaces.Document.call_createRange(xml);
    defer interfaces.Range.deinit(r);
    try interfaces.Range.call_setStart(r, first, 1);
    try interfaces.Range.call_setEnd(r, last, 2);
    const across = try interfaces.Range.serialize(r);
    defer r.ctx.allocator.free(across);
    // DOM 5.5 stringifier steps 3-5 ("a Text node"; CDATASection inherits
    // Text): Blink Range::toString (kTextNode || kCdataSectionNode), Gecko
    // nsRange::ToString (GetAsText), WebKit Range::toString.
    try testing.expectEqualStrings("bcdMIDwx", across);

    try interfaces.Range.call_setEnd(r, first, 3);
    const inside = try interfaces.Range.serialize(r);
    defer r.ctx.allocator.free(inside);
    try testing.expectEqualStrings("bc", inside);
}
