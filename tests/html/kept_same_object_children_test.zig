//! PR-N1 (tmp/analysis/fix-list.md): a [SameObject] child its owner keeps as
//! a bare pointer beside the traced edge that keeps it alive - an
//! ElementInternals' states, validity and labels, a form's and a fieldset's
//! elements - read a freed or reissued slot once the edge was lost (the
//! 2026-10-03 lesson: never let a native pointer live only because a JS edge
//! happens to exist). Each case drops the owner's edge by hand, collects,
//! lets objects of the same type take the freed slots, and reads again: the
//! child must be one that belongs to its owner - made again - never another
//! owner's object at the reissued address.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    return browser;
}

fn platformObject(browser: *browser_mod.Browser, source: []const u8) !*runtime.Instance {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        std.debug.print("expected true: {s}\n", .{source});
        return error.TestExpectedTrue;
    }
}

fn lostInternalsChildren() !void {
    const browser = try open();
    defer browser.deinit();
    const internals = try platformObject(browser,
        \\class Face extends HTMLElement {
        \\  static formAssociated = true;
        \\  constructor() { super(); this.internals = this.attachInternals(); }
        \\}
        \\customElements.define('lf2-kept-face', Face);
        \\globalThis.face = document.body.appendChild(new Face());
        \\face.id = 'mine';
        \\document.body.appendChild(Object.assign(document.createElement('label'), { htmlFor: 'mine' }));
        \\void face.internals.states, void face.internals.validity, void face.internals.labels;
        \\face.internals
    );
    // The edges that kept the three children, lost; the collector takes them
    // and other faces' children take their slots.
    for ([_][]const u8{ "states", "validity", "labels" }) |slot| engine.forgetTracedChild(internals, .{ .name = slot });
    try collect(browser);
    try run(browser,
        \\globalThis.others = [];
        \\for (let i = 0; i < 100; i++) {
        \\  const other = new Face();
        \\  other.internals.setValidity({});
        \\  others.push(other.internals.states, other.internals.validity, other.internals.labels, document.querySelectorAll('p'));
        \\}
        \\0
    );
    // Each reads as this face's own: made again if it was gone.
    try expectTrue(browser, "face.internals.states instanceof CustomStateSet && (face.internals.states.add('z'), face.matches(':state(z)'))");
    try expectTrue(browser, "face.internals.setValidity({ customError: true }, 'm'), face.internals.validity instanceof ValidityState && face.internals.validity.customError === true");
    try expectTrue(browser, "face.internals.labels instanceof NodeList && face.internals.labels.length === 1");
}

test "an ElementInternals whose children's edges were lost reads its own children, not freed ones" {
    try onFreshThread(lostInternalsChildren);
}

fn lostElementsCollections() !void {
    const browser = try open();
    defer browser.deinit();
    const form = try platformObject(browser,
        \\globalThis.form = document.body.appendChild(document.createElement('form'));
        \\for (let i = 0; i < 3; i++) form.appendChild(document.createElement('input'));
        \\void form.elements;
        \\form
    );
    const fieldset = try platformObject(browser,
        \\globalThis.fieldset = document.body.appendChild(document.createElement('fieldset'));
        \\for (let i = 0; i < 2; i++) fieldset.appendChild(document.createElement('select'));
        \\void fieldset.elements;
        \\fieldset
    );
    engine.forgetTracedChild(form, .{ .name = "elements" });
    engine.forgetTracedChild(fieldset, .{ .name = "elements" });
    try collect(browser);
    try run(browser,
        \\globalThis.others = [];
        \\for (let i = 0; i < 100; i++) {
        \\  others.push(document.createElement('form').elements, document.createElement('fieldset').elements);
        \\}
        \\0
    );
    try expectTrue(browser, "form.elements instanceof HTMLFormControlsCollection && form.elements.length === 3 && form.elements === form.elements");
    try expectTrue(browser, "fieldset.elements instanceof HTMLCollection && fieldset.elements.length === 2 && fieldset.elements === fieldset.elements");
}

test "a form and a fieldset whose elements collections' edges were lost read their own, not freed ones" {
    try onFreshThread(lostElementsCollections);
}
