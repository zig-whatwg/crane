//! Lane impls8: the steps the last impls-boundary references reached into
//! other types' impls for, now reached the way every other caller reaches a
//! type (src/webidl/AGENTS.md, "The impls boundary"): an IDL member through
//! its generated interface, a step with no IDL member through the hook its
//! owner installs.
//!
//! - Window's named getter (HTML 7.2.2.3, `getter object (DOMString name)`)
//!   and its supported property names, which the engine's named properties
//!   object (WindowProperties) asks through `interfaces.Window`.
//! - A Window's Location and History name the Window they were made for
//!   (`dom.window_objects`), which the wrapper cache asks; the Window hands
//!   out the Location it made (`dom.window_globals.location`), which a
//!   frame's URL update sets.
//! - An iframe's sandbox list is associated like every reflected
//!   DOMTokenList (`dom.token_lists.associate`), and the association gives
//!   it the sandboxing keywords as its supported tokens (HTML 4.8.5: "The
//!   supported tokens for sandbox's DOMTokenList are the allowed values
//!   defined in the sandbox attribute and supported by the user agent").
const std = @import("std");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const webidl = @import("webidl");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

fn str(s: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(s);
}

fn windowOf(page: helpers.Page) !*runtime.Instance {
    return page.browser.current_context.?.window_instance orelse error.NoWindow;
}

fn namedGetter() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<span id=impls8One></span><b id=impls8Two></b><i id=impls8Two></i>';
        \\const impls8Frame = document.createElement('iframe');
        \\impls8Frame.name = 'impls8Frame';
        \\document.body.append(impls8Frame);
        \\void impls8Frame.contentWindow;
    );
    const window = try windowOf(page);

    // The supported property names: an element's id, a child navigable's
    // target name; not a name nothing carries.
    try std.testing.expect(try interfaces.Window.isSupportedPropertyName(window, str("impls8One")));
    try std.testing.expect(try interfaces.Window.isSupportedPropertyName(window, str("impls8Two")));
    try std.testing.expect(try interfaces.Window.isSupportedPropertyName(window, str("impls8Frame")));
    try std.testing.expect(!try interfaces.Window.isSupportedPropertyName(window, str("impls8None")));

    // "Determine the value of a named property": one element is that
    // element; several are a collection; a child navigable is its
    // WindowProxy (the frame's Window).
    const one = try interfaces.Window.call_getter(window, str("impls8One"));
    try std.testing.expectEqualStrings("HTMLSpanElement", one.instance.vtable.name);
    const two = try interfaces.Window.call_getter(window, str("impls8Two"));
    // Made for this call, unwrapped: the caller frees it (no wrapper will).
    defer runtime.gc.onObjectFreed(two.instance);
    try std.testing.expectEqualStrings("HTMLCollection", two.instance.vtable.name);
    const frame = try interfaces.Window.call_getter(window, str("impls8Frame"));
    try std.testing.expectEqualStrings("Window", frame.instance.vtable.name);
    try std.testing.expect(frame.instance != window);
    // WebIDL asks the getter only for a supported name; for any other it
    // answers undefined, so the named properties object asks once.
    try std.testing.expect(try interfaces.Window.call_getter(window, str("impls8None")) == .undefined);
}

test "Window's named getter and supported property names answer through its generated interface" {
    try helpers.onFreshThread(namedGetter);
}

fn windowObjects() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const window = try windowOf(page);

    const location = try interfaces.Window.get_location(window);
    try std.testing.expectEqual(@as(?*runtime.Instance, window), dom.window_objects.locationWindow(location));
    // The Location the Window made - read, not made.
    try std.testing.expectEqual(@as(?*runtime.Instance, location), dom.window_globals.location(window));

    const history = try interfaces.Window.get_history(window);
    try std.testing.expectEqual(@as(?*runtime.Instance, window), dom.window_objects.historyWindow(history));

    // Neither question has an answer for another type.
    try std.testing.expectEqual(@as(?*runtime.Instance, null), dom.window_objects.locationWindow(history));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), dom.window_objects.historyWindow(location));
}

test "a Window's Location and History name their Window through dom.window_objects" {
    try helpers.onFreshThread(windowObjects);
}

fn sandboxTokens() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<iframe id=impls8Sandboxed></iframe>';");
    const window = try windowOf(page);
    const document = try interfaces.Window.get_document(window);
    const iframe = (try interfaces.Document.call_getElementById(document, str("impls8Sandboxed"))) orelse return error.NoIframe;

    const list = try interfaces.DOMTokenList.init(iframe.ctx.allocator, iframe.ctx);
    defer runtime.gc.onObjectFreed(list);
    try dom.token_lists.associate(list, iframe, "sandbox");
    try std.testing.expect(try interfaces.DOMTokenList.call_supports(list, str("allow-scripts")));
    try std.testing.expect(try interfaces.DOMTokenList.call_supports(list, str("ALLOW-SAME-ORIGIN")));
    try std.testing.expect(!try interfaces.DOMTokenList.call_supports(list, str("allow-everything")));
    // The list is the attribute's.
    try interfaces.DOMTokenList.call_add(list, &.{str("allow-forms")});
    try std.testing.expect(try interfaces.Element.call_hasAttribute(iframe, str("sandbox")));

    // The iframe's own [SameObject] sandbox list is made the same way.
    const own = try page.evaluate(
        \\const impls8Own = document.getElementById('impls8Sandboxed').sandbox;
        \\[impls8Own.supports('allow-popups'), impls8Own.supports('allow-nothing'), impls8Own.value,
        \\ impls8Own === document.getElementById('impls8Sandboxed').sandbox].join()
    );
    defer std.testing.allocator.free(own);
    try std.testing.expectEqualStrings("true,false,allow-forms,true", own);
}

test "an iframe's sandbox list takes the sandboxing keywords as its supported tokens from its association" {
    try helpers.onFreshThread(sandboxTokens);
}
