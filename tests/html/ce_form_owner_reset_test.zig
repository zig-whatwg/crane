//! CE2-S1 (tmp/analysis/fix-list.md): a form-associated custom element's
//! form owner and disabled state are reset where a mutation can change them -
//! the inserted, removed or moved subtree, the elements whose form attribute
//! names an ID that entered, left or changed in a tree, a fieldset's
//! descendants when its disabled attribute or first legend changes - and no
//! longer by walking the whole tree on every mutation. Built-in listed
//! elements derive their owner on every read, so each case checks the FACE
//! against an <input> put through the same mutations (the integrator's
//! parity condition), and checks the callbacks the changes enqueue.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const html = @import("html");

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

/// The page defines x-face (form-associated) and logs its callbacks; `pair`
/// checks a FACE and an input against the same expected owner.
const setup =
    \\globalThis.log = [];
    \\class XFace extends HTMLElement {
    \\  static formAssociated = true;
    \\  constructor() { super(); this.internals = this.attachInternals(); }
    \\  formAssociatedCallback(form) { log.push(this.id + ':form=' + (form ? form.id || 'anon' : 'null')); }
    \\  formDisabledCallback(disabled) { log.push(this.id + ':disabled=' + disabled); }
    \\}
    \\customElements.define('x-face', XFace);
    \\globalThis.face = (id, attrs = {}) => {
    \\  const element = document.createElement('x-face');
    \\  element.id = id;
    \\  for (const [name, value] of Object.entries(attrs)) element.setAttribute(name, value);
    \\  return element;
    \\};
    \\globalThis.input = (id, attrs = {}) => {
    \\  const element = document.createElement('input');
    \\  element.id = id;
    \\  for (const [name, value] of Object.entries(attrs)) element.setAttribute(name, value);
    \\  return element;
    \\};
    \\globalThis.same = (f, i, expected) => f.internals.form === expected && i.form === expected;
    \\globalThis.take = () => { const out = log.join(' '); log.length = 0; return out; };
    \\0
;

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try run(browser, setup);
    return browser;
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

fn expectLog(browser: *browser_mod.Browser, expected: []const u8) !void {
    const held = try browser.evaluateScript("take()");
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const text = try engine.convertToDOMString(realm, held.borrow(), testing.allocator);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings(expected, text);
}

fn ancestorForms() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.form = document.body.appendChild(document.createElement('form')); form.id = 'a';
        \\globalThis.f = face('f'); globalThis.i = input('i');
        \\globalThis.wrap = document.createElement('div'); wrap.append(f, i);
        \\0
    );
    try expectLog(browser, "");
    // Inserted under a form: the subtree's elements are reset.
    try expectTrue(browser, "form.appendChild(wrap), same(f, i, form)");
    try expectLog(browser, "f:form=a");
    // Removed: so is the removed subtree.
    try expectTrue(browser, "wrap.remove(), same(f, i, null)");
    try expectLog(browser, "f:form=null");
    // Mutations elsewhere in the tree leave it alone.
    try run(browser, "form.appendChild(wrap); take(); document.body.appendChild(document.createElement('p')).remove(); 0");
    try expectLog(browser, "");
    try expectTrue(browser, "same(f, i, form)");
}

test "a form-associated element inserted under or removed from a form is reset with its subtree" {
    try onFreshThread(ancestorForms);
}

fn formAttributeTargets() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.f = document.body.appendChild(face('f', { form: 'target' }));
        \\globalThis.i = document.body.appendChild(input('i', { form: 'target' }));
        \\0
    );
    try expectTrue(browser, "same(f, i, null)");
    try expectLog(browser, "");
    // An element with the named ID is inserted: the observers are reset.
    try run(browser, "globalThis.form = document.createElement('form'); form.id = 'target'; document.body.prepend(form); 0");
    try expectTrue(browser, "same(f, i, form)");
    try expectLog(browser, "f:form=target");
    // The form is removed (condition 1: the owner outside the removed
    // subtree is reset).
    try expectTrue(browser, "form.remove(), same(f, i, null)");
    try expectLog(browser, "f:form=null");
    // Its id is given to another form already in the tree.
    try run(browser, "globalThis.other = document.body.appendChild(document.createElement('form')); 0");
    try expectLog(browser, "");
    try expectTrue(browser, "other.id = 'target', same(f, i, other)");
    try expectLog(browser, "f:form=target");
    // ...and taken away.
    try expectTrue(browser, "other.id = 'elsewhere', same(f, i, null)");
    try expectLog(browser, "f:form=null");
    // The form inside an inserted subtree, not the subtree's root.
    try run(browser, "const box = document.createElement('div'); box.appendChild(other); other.id = 'target'; document.body.appendChild(box); 0");
    try expectTrue(browser, "same(f, i, other)");
    try expectLog(browser, "f:form=target");
    // An earlier element with the same ID that is not a form wins.
    try expectTrue(browser, "document.body.prepend(Object.assign(document.createElement('div'), { id: 'target' })), same(f, i, null)");
    try expectLog(browser, "f:form=null");
    // ...and removed again: the form is the first with that ID once more.
    try expectTrue(browser, "document.body.firstChild.remove(), same(f, i, other)");
    try expectLog(browser, "f:form=target");
    // The form attribute itself changes.
    try expectTrue(browser, "f.setAttribute('form', 'nothing'), i.setAttribute('form', 'nothing'), same(f, i, null)");
    try expectLog(browser, "f:form=null");
    try expectTrue(browser, "f.setAttribute('form', 'target'), i.setAttribute('form', 'target'), same(f, i, other)");
    try expectLog(browser, "f:form=target");
    try expectTrue(browser, "f.removeAttribute('form'), i.removeAttribute('form'), same(f, i, null)");
    try expectLog(browser, "f:form=null");
}

test "a form attribute's ID target entering, leaving or changing resets its element (and matches an input)" {
    try onFreshThread(formAttributeTargets);
}

fn movedSubtrees() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.a = document.body.appendChild(document.createElement('form')); a.id = 'a';
        \\globalThis.b = document.body.appendChild(document.createElement('form')); b.id = 'b';
        \\globalThis.f = a.appendChild(face('f')); globalThis.i = a.appendChild(input('i'));
        \\take(); 0
    );
    // Crane's moveBefore removes and inserts (ParentNode.zig; DOM's move
    // algorithm, dom.mutation.move, has no caller yet), so the element is
    // reset on the way out and again in its new place; the owner it ends
    // with is the new form's.
    try expectTrue(browser, "b.moveBefore(f, null), b.moveBefore(i, null), same(f, i, b)");
    try expectTrue(browser, "log[log.length - 1] === 'f:form=b'");
    try run(browser, "take(); 0");
    // A moved element with the ID a form attribute names.
    try run(browser, "globalThis.g = document.body.appendChild(face('g', { form: 'a' })); b.id = 'a'; take(); 0");
    try expectTrue(browser, "g.internals.form === a");
    try expectTrue(browser, "document.body.moveBefore(b, a), g.internals.form === b");
    // b carries the ID 'a' now; g's owner was a, so a callback naming 'a'
    // is the change to b.
    try expectTrue(browser, "log.includes('g:form=a')");
}

test "a form-associated element moved with moveBefore ends with its new owner" {
    try onFreshThread(movedSubtrees);
}

fn shadowTrees() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.host = document.createElement('div');
        \\globalThis.root = host.attachShadow({ mode: 'open' });
        \\globalThis.inner = root.appendChild(document.createElement('form')); inner.id = 'inner';
        \\globalThis.f = root.appendChild(face('f', { form: 'inner' }));
        \\globalThis.i = root.appendChild(input('i', { form: 'inner' }));
        \\take(); 0
    );
    // Disconnected: the form attribute does not apply.
    try expectTrue(browser, "same(f, i, null)");
    // Connecting the host connects its shadow tree: reset through it.
    try expectTrue(browser, "document.body.appendChild(host), same(f, i, inner)");
    try expectLog(browser, "f:form=inner");
    try expectTrue(browser, "host.remove(), same(f, i, null)");
    try expectLog(browser, "f:form=null");
}

test "connecting a shadow host resets the form-associated elements of its shadow tree" {
    try onFreshThread(shadowTrees);
}

fn disabledFieldsets() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.set = document.body.appendChild(document.createElement('fieldset'));
        \\globalThis.legend = set.appendChild(document.createElement('legend'));
        \\globalThis.f = legend.appendChild(face('f'));
        \\globalThis.g = set.appendChild(face('g'));
        \\take(); 0
    );
    try run(browser, "set.disabled = true; 0");
    // In the first legend f stays enabled; g is disabled.
    try expectLog(browser, "g:disabled=true");
    // A new first legend: f is no longer in it.
    try run(browser, "set.insertBefore(document.createElement('legend'), legend); 0");
    try expectLog(browser, "f:disabled=true");
    try expectTrue(browser, "f.matches(':disabled') && g.matches(':disabled')");
    try run(browser, "set.firstChild.remove(); 0");
    try expectLog(browser, "f:disabled=false");
    try run(browser, "set.disabled = false; 0");
    try expectLog(browser, "g:disabled=false");
    try run(browser, "f.setAttribute('disabled', ''); 0");
    try expectLog(browser, "f:disabled=true");
}

test "a fieldset's disabled attribute and first legend reset its descendants" {
    try onFreshThread(disabledFieldsets);
}

fn observerCount(browser: *browser_mod.Browser) !usize {
    const realm = browser.getRealm() orelse return error.NoRealm;
    const state = html.custom_elements.stateForRealm(realm) orelse return error.NoAgentState;
    return state.form_id_observers.count();
}

fn observersLeaveWithTheirElements() !void {
    const browser = try open();
    defer browser.deinit();
    const before = try observerCount(browser);
    try run(browser,
        \\globalThis.kept = document.body.appendChild(face('kept', { form: 'x' }));
        \\for (let n = 0; n < 10000; n++) { const element = face('d' + n, { form: 'x' + n }); document.body.appendChild(element); element.remove(); }
        \\0
    );
    try testing.expect(try observerCount(browser) >= before + 1);
    try collect(browser);
    // Every dropped element's entry left with it (condition 3); the one in
    // the document stays.
    try testing.expectEqual(before + 1, try observerCount(browser));
    try run(browser, "kept.remove(); kept = null; 0");
    try collect(browser);
    try testing.expectEqual(before, try observerCount(browser));
}

test "an ID observer leaves the agent's map when its element is collected" {
    try onFreshThread(observersLeaveWithTheirElements);
}
