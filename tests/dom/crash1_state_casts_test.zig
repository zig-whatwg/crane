//! A hook that may be handed another type's object reads no state from it:
//! each answers "not mine" through the brand check (`instance.stateAs`),
//! never through the unchecked cast that read the other type's State at its
//! own `own._internal` offset as a pointer (lane crash1 batch 2; the SAFETY
//! item perf3 D1 queued after ProcessingInstruction's: type confusion is
//! memory corruption).
//!
//! `InternalStateAccessor.get` is `instance.getState(State).own._internal`,
//! and getState, finding no `State` in a foreign instance's ancestry, falls
//! back to a bare cast. So each test writes 0xaa over the 8 bytes at the
//! hook's own `_internal` offset in a div's State (computed at comptime from
//! the generated States, asserted inside the div's State and clear of the
//! div's own state pointer, if it has one), calls the hook with the div, and
//! puts the bytes back: an unchecked read dereferences 0xaaaaaaaaaaaaaaaa
//! and faults on every layout, not only an unlucky one (perf3d1_sheet_hooks_
//! test.zig's method). One test per hook family:
//!
//! - dom.blob_bytes (Blob bytesOf / dataOf): "null when `blob` is no Blob";
//! - dom.range_boundaries (Range's live `points`; and `of`, gated already);
//! - dom.live_collections.rootOf (HTMLCollection liveRoot);
//! - dom.custom_elements.isScoped (CustomElementRegistry: gated already);
//! - dom.selection (Selection bindDocument / rangeMutated);
//! - dom.event_dispatch.of (Event stateOf: gated already).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

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

    fn element(self: *Page, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, str(name), .{ .was_passed = false, .value = undefined });
    }

    /// A div in the body: the foreign object every hook here is handed.
    fn div(self: *Page) !*runtime.Instance {
        const el = try self.element("div");
        _ = try interfaces.Node.call_appendChild(self.body, el);
        return el;
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

const DivState = interfaces.HTMLDivElement.State;

/// Where `S`'s own level keeps its state pointer - the bytes an unchecked
/// cast to `S` reads, as a pointer, from any other instance's State - or null
/// when it keeps none (a level whose state is kept by value or is empty).
fn ownInternalOffset(comptime S: type) ?usize {
    if (!@hasField(@FieldType(S, "own"), "_internal")) return null;
    return @offsetOf(S, "own") + @offsetOf(@FieldType(S, "own"), "_internal");
}

/// Run `body` with the 8 bytes at `S`'s state offset in the div's State set
/// to 0xaa - what a safe build leaves in undefined memory - and put them
/// back after. Only an unchecked read of `S`'s state looks at them.
fn withPoisonFor(comptime S: type, div: *runtime.Instance, context: anytype, comptime body: fn (@TypeOf(context), *runtime.Instance) anyerror!void) !void {
    const offset = comptime ownInternalOffset(S) orelse @compileError(@typeName(S) ++ " keeps no state pointer to read");
    comptime {
        if (offset + 8 > @sizeOf(DivState)) @compileError("the state offset of " ++ @typeName(S) ++ " lies past a div's State");
        if (ownInternalOffset(DivState)) |own| {
            if (offset < own + 8 and own < offset + 8) @compileError("the state offset of " ++ @typeName(S) ++ " overlaps a div's own state pointer");
        }
    }
    const state = div.stateAs(DivState) orelse return error.WrongState;
    const bytes: [*]u8 = @ptrCast(state);
    const saved: [8]u8 = bytes[offset..][0..8].*;
    @memset(bytes[offset..][0..8], 0xaa);
    defer @memcpy(bytes[offset..][0..8], &saved);
    try body(context, div);
}

test "dom.blob_bytes: a div is no Blob - no bytes and no data, its state unread" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const div = try page.div();
    try withPoisonFor(interfaces.Blob.State, div, {}, struct {
        fn check(_: void, el: *runtime.Instance) anyerror!void {
            try testing.expect(dom.blob_bytes.bytesOf(el) == null);
            try testing.expect(dom.blob_bytes.dataOf(el) == null);
        }
    }.check);
}

test "dom.range_boundaries: a div has no Range state - no live points, no boundaries" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const div = try page.div();
    // A live range made the way createRange makes one, so the live-range
    // steps are installed and a real Range still answers.
    const range = try interfaces.Document.call_createRange(page.document);
    defer interfaces.Range.deinit(range);
    try testing.expect(dom.range_boundaries.liveRange().?.points(range) != null);
    try withPoisonFor(interfaces.Range.State, div, {}, struct {
        fn check(_: void, el: *runtime.Instance) anyerror!void {
            const live = dom.range_boundaries.liveRange() orelse return error.NoLiveRangeSteps;
            try testing.expect(live.points(el) == null);
            try testing.expect(dom.range_boundaries.of(el) == null);
        }
    }.check);
}

test "dom.live_collections: a div is no collection - no live root, its state unread" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const div = try page.div();
    try withPoisonFor(interfaces.HTMLCollection.State, div, {}, struct {
        fn check(_: void, el: *runtime.Instance) anyerror!void {
            try testing.expect(dom.live_collections.rootOf(el) == null);
        }
    }.check);
}

test "dom.custom_elements: a div is no registry - not scoped, its state unread" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const div = try page.div();
    try withPoisonFor(interfaces.CustomElementRegistry.State, div, {}, struct {
        fn check(_: void, el: *runtime.Instance) anyerror!void {
            try testing.expect(!dom.custom_elements.isScoped(el));
        }
    }.check);
}

test "dom.selection: a div is no Selection - binding a document or a range's mutation leaves it alone" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const div = try page.div();
    const range = try interfaces.Document.call_createRange(page.document);
    defer interfaces.Range.deinit(range);
    const Context = struct { document: *runtime.Instance, range: *runtime.Instance };
    try withPoisonFor(interfaces.Selection.State, div, Context{ .document = page.document, .range = range }, struct {
        fn check(context: Context, el: *runtime.Instance) anyerror!void {
            dom.selection.rangeMutated(el, context.range, true);
            dom.selection.bindDocument(el, context.document);
        }
    }.check);
}

test "dom.event_dispatch: a div is no Event - no event state, its state unread" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const div = try page.div();
    try withPoisonFor(interfaces.Event.State, div, {}, struct {
        fn check(_: void, el: *runtime.Instance) anyerror!void {
            try testing.expect(dom.event_dispatch.of(el) == null);
        }
    }.check);
}

// webidl.utils.InternalStateAccessor.get, the accessor 23 impls read their
// state through, is brand-checked itself (lane crash1 batch 3): Attr, one of
// them, through its dom.attr_nodes hooks.
test "dom.attr_nodes (InternalStateAccessor.get): a div is no Attr - naming or detaching it reads no Attr state" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const div = try page.div();
    try withPoisonFor(interfaces.Attr.State, div, {}, struct {
        fn check(_: void, el: *runtime.Instance) anyerror!void {
            try testing.expectError(error.InvalidStateError, dom.attr_nodes.detach(el, "value"));
            try testing.expectError(error.InvalidStateError, dom.attr_nodes.name(el, null, null, "id"));
        }
    }.check);
}
