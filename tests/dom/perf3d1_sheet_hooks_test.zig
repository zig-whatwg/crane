//! A style sheet's owner hooks never read one owner type's state as another's
//! (lane perf3 D1's FULL A/B: 65 crashes).
//!
//! dom.style.hooks asks every owner type in turn - `sheetOf` asks the style,
//! the link and then the processing-instruction hook; `linkSheetArrived`
//! hands a fetched sheet to the link's and then the PI's step - so each
//! hook is called with instances of the OTHER types too, and must answer
//! "not mine" for them. The ProcessingInstruction impl read its state with
//! an unchecked cast (InternalStateAccessor: `instance.getState(State)`, no
//! brand check), so for a link element it read whatever lies at the PI
//! state's `own._internal` offset as a pointer. When D1 shrank Element's
//! embedded state, that offset fell on undefined bytes (0xaa..) and every
//! link stylesheet load crashed (SEGV at 0xaaaaaaaaaaaaaa4b in the PI's
//! sheetArrived). HTMLLinkElement and HTMLStyleElement check the brand
//! (`instance.stateAs(State)`); the PI now does too.

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

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

/// `el`'s sheet through every owner hook is its own, or none: never a record
/// read from another type's state. A connected style element has its own
/// (HTML "update a style block" makes one, empty text included); a link with
/// no stylesheet load and a div have none.
fn expectOwnSheetOrNone(el: *runtime.Instance, has_own: bool) !void {
    const record = dom.style.hooks.sheetOf(el);
    if (has_own) {
        const r = record orelse return error.NoOwnSheet;
        try testing.expect(r.owner_node == el);
    } else {
        try testing.expect(record == null);
    }
}

test "a link, style or div element's sheet through every owner hook is its own or none, never the PI's reading" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    inline for (.{ .{ "link", false }, .{ "style", true }, .{ "div", false } }) |case| {
        const el = try page.element(case[0]);
        try interfaces.Element.call_setAttribute(el, str("title"), .{ .domstring = str("t") });
        _ = try interfaces.Node.call_appendChild(page.body, el);
        try expectOwnSheetOrNone(el, case[1]);
    }
}

test "a sheet arriving for a link that loads none is taken by no owner hook" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    // rel is not "stylesheet": the link's own step does nothing, and the
    // PI's must see that this is no processing instruction.
    const link = try page.element("link");
    try interfaces.Element.call_setAttribute(link, str("rel"), .{ .domstring = str("icon") });
    try interfaces.Element.call_setAttribute(link, str("media"), .{ .domstring = str("screen") });
    _ = try interfaces.Node.call_appendChild(page.body, link);
    dom.style.hooks.linkSheetArrived(link, "p { color: red }", "http://example.test/a.css", true);
    try testing.expect(dom.style.hooks.sheetOf(link) == null);
}

/// Where the PI impl finds its state in a ProcessingInstruction's State: the
/// bytes an unchecked cast reads, as a pointer, from any other instance.
const PIState = interfaces.ProcessingInstruction.State;
const pi_offset = @offsetOf(PIState, "own") + @offsetOf(@FieldType(PIState, "own"), "_internal");

fn ownInternalOffset(comptime S: type) usize {
    return @offsetOf(S, "own") + @offsetOf(@FieldType(S, "own"), "_internal");
}

/// Run `body` with the 8 bytes at the PI's state offset of `el`'s State set
/// to 0xaa - undefined memory in a safe build, what the ReleaseSafe runner's
/// layout put there - and put them back after. Only the PI's unchecked read
/// looks at them: the link and style hooks read their own level's state.
fn withPoisonAtPiOffset(comptime S: type, el: *runtime.Instance, context: anytype, comptime body: fn (@TypeOf(context), *runtime.Instance) anyerror!void) !void {
    comptime {
        if (pi_offset + 8 > @sizeOf(S)) @compileError("the PI state offset lies past " ++ @typeName(S));
        const own = ownInternalOffset(S);
        if (pi_offset < own + 8 and own < pi_offset + 8) @compileError("the PI state offset overlaps " ++ @typeName(S) ++ "'s own state pointer");
    }
    const state = el.stateAs(S) orelse return error.WrongState;
    const bytes: [*]u8 = @ptrCast(state);
    const saved: [8]u8 = bytes[pi_offset..][0..8].*;
    @memset(bytes[pi_offset..][0..8], 0xaa);
    defer @memcpy(bytes[pi_offset..][0..8], &saved);
    try body(context, el);
}

test "the PI's sheet hooks check the brand: a link, style or div whose bytes at the PI's state offset are undefined" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    const link = try page.element("link");
    _ = try interfaces.Node.call_appendChild(page.body, link);
    const style = try page.element("style");
    _ = try interfaces.Node.call_appendChild(page.body, style);
    const div = try page.element("div");
    _ = try interfaces.Node.call_appendChild(page.body, div);

    const Checks = struct {
        fn noSheet(_: void, el: *runtime.Instance) anyerror!void {
            try expectOwnSheetOrNone(el, false);
        }
        fn ownSheet(_: void, el: *runtime.Instance) anyerror!void {
            try expectOwnSheetOrNone(el, true);
        }
        fn arrives(_: void, el: *runtime.Instance) anyerror!void {
            dom.style.hooks.linkSheetArrived(el, "p { color: red }", "http://example.test/a.css", true);
            try testing.expect(dom.style.hooks.sheetOf(el) == null);
        }
    };
    // sheetOf asks the style, the link and then the PI hook; the style
    // element answers with its own sheet before the PI's is asked, so its
    // case checks the record is its own.
    try withPoisonAtPiOffset(interfaces.HTMLLinkElement.State, link, {}, Checks.noSheet);
    try withPoisonAtPiOffset(interfaces.HTMLStyleElement.State, style, {}, Checks.ownSheet);
    try withPoisonAtPiOffset(interfaces.HTMLDivElement.State, div, {}, Checks.noSheet);
    // A fetched sheet goes to the link's step and then the PI's: for a node
    // that is neither, both must decline without reading its state.
    try withPoisonAtPiOffset(interfaces.HTMLDivElement.State, div, {}, Checks.arrives);
}
