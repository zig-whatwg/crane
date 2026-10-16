//! HTML "the form element": the past names map. Determining the value of a
//! named property records the single candidate it returns under the name it
//! was asked for (step 5), and answers from the map when no candidate is
//! left (step 3), so a control keeps answering to a name it no longer has;
//! "if an element listed in a form element's past names map changes form
//! owner, then its entries must be removed from that map" - at the change,
//! not at the next read: a removal and a reinsertion between two reads
//! leave the owner what it was, and the entries still gone
//! (tmp/plans/codex-lpo-questions.md Q2). The supported property names list
//! the past names too (step 4), after the element's id and name, oldest first
//! (step 5).
//!
//! Driven through script in a Browser: the map needs its agent (the forms
//! that hold one are the agent's), and the named getter is how script asks.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

const prelude =
    \\const fails = [];
    \\function eq(actual, expected, message) {
    \\  if (actual !== expected) fails.push(message + ': got ' + String(actual));
    \\}
    \\function input(parent, name, id) {
    \\  const element = document.createElement('input');
    \\  if (name !== undefined) element.name = name;
    \\  if (id !== undefined) element.id = id;
    \\  return parent.appendChild(element);
    \\}
    \\
;
const epilogue =
    \\
    \\fails.length ? fails.join('; ') : 'ok';
;

const Page = struct {
    browser: *@import("browser").Browser,

    fn open(html: []const u8) !Page {
        const browser = try @import("browser").Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML(html, .{ .base_url = "http://example.test/fn-form-past-names" });
        return .{ .browser = browser };
    }

    fn close(self: Page) void {
        self.browser.deinit();
    }

    /// Run `body` between the prelude and the epilogue; "ok" or the failures.
    fn expectOk(self: Page, comptime body: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        const result = try page.evaluateScriptToString(prelude ++ body ++ epilogue, testing.allocator);
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("ok", result);
    }

    fn element(self: Page, id: []const u8) !*runtime.Instance {
        const page = self.browser.current_context orelse return error.NoPage;
        const document = page.document_instance orelse return error.NoDocument;
        return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoElement;
    }
};

fn names(form: *runtime.Instance, expected: []const []const u8) !void {
    const result = try interfaces.HTMLFormElement.getSupportedPropertyNames(form, testing.allocator);
    defer {
        for (result) |*name| name.deinit(testing.allocator);
        testing.allocator.free(result);
    }
    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(testing.allocator);
    for (result) |name| {
        try joined.appendSlice(testing.allocator, name.asSlice());
        try joined.append(testing.allocator, ' ');
    }
    var wanted: std.ArrayList(u8) = .empty;
    defer wanted.deinit(testing.allocator);
    for (expected) |name| {
        try wanted.appendSlice(testing.allocator, name);
        try wanted.append(testing.allocator, ' ');
    }
    try testing.expectEqualStrings(wanted.items, joined.items);
}

fn renamesKeepTheirPastNames() !void {
    const page = try Page.open("<!doctype html><form id=f></form><form id=g></form>");
    defer page.close();
    try page.expectOk(
        \\const form = document.getElementById('f');
        \\const control = input(form, 'first', 'firstId');
        \\eq(form.first, control, 'a current name');
        \\eq(form.firstId, control, 'a current id');
        \\control.name = 'second';
        \\control.id = 'secondId';
        \\eq(form.first, control, 'step 3: the past name answers');
        \\eq(form.firstId, control, 'step 3: the past id answers');
        \\eq('first' in form, true, 'step 4: a past name is a supported property name');
        \\eq(Object.getOwnPropertyDescriptor(form, 'first').value, control, 'its descriptor');
        \\eq(form.second, control, 'the new name');
        \\control.removeAttribute('name');
        \\control.removeAttribute('id');
        \\eq(form.first, control, 'no name at all: still the past name');
        \\eq(form.second, control, 'and the one recorded since');
        \\eq('never' in form, false, 'a name never asked is no past name');
        \\// An owner that stays the same keeps the entries: moved inside the
        \\// form (moveBefore: it never leaves the tree), given a form
        \\// attribute naming its own form, the form taken out of the
        \\// document with the control inside it.
        \\form.moveBefore(control, form.firstChild);
        \\eq(form.first, control, 'moved within its form');
        \\control.setAttribute('form', 'f');
        \\eq(form.first, control, 'a form attribute naming the same form');
        \\control.removeAttribute('form');
        \\eq(form.first, control, 'the attribute removed, still in the form');
        \\form.remove();
        \\eq(form.first, control, 'the form out of the document, the control in it');
        \\document.body.appendChild(form);
        \\eq(form.first, control, 'and back');
        \\// An image button is no candidate, and keeps its form owner.
        \\control.type = 'image';
        \\eq(form.first, control, 'an image button keeps its past names');
        \\// insertBefore of a node in the tree removes it first: its owner was
        \\// null in between (the removing steps reset it), as in every browser.
        \\form.insertBefore(control, form.firstChild);
        \\eq(form.first, undefined, 'removed and inserted by insertBefore');
    );
}

fn ownerChangesRemoveEntries() !void {
    const page = try Page.open("<!doctype html><form id=f></form><form id=g></form><div id=outside></div>");
    defer page.close();
    try page.expectOk(
        \\const form = document.getElementById('f');
        \\const other = document.getElementById('g');
        \\const outside = document.getElementById('outside');
        \\// Removal: the owner becomes null.
        \\const removed = input(form, 'removedName');
        \\eq(form.removedName, removed, 'recorded');
        \\removed.name = 'renamed1';
        \\removed.remove();
        \\eq(form.removedName, undefined, 'removal drops the entry');
        \\eq('removedName' in form, false, 'and the supported name');
        \\// Removed and reinserted between two reads: the owner changed twice.
        \\const back = input(form, 'backName');
        \\eq(form.backName, back, 'recorded');
        \\back.name = 'renamed2';
        \\back.remove();
        \\form.appendChild(back);
        \\eq(form.backName, undefined, 'a reinsertion does not bring an entry back');
        \\eq(form.renamed2, back, 'the current name still answers');
        \\// Moved into another form.
        \\const moved = input(form, 'movedName');
        \\eq(form.movedName, moved, 'recorded');
        \\moved.name = 'renamed3';
        \\other.appendChild(moved);
        \\eq(form.movedName, undefined, 'moved to another form');
        \\eq(other.movedName, undefined, 'the other form never recorded it');
        \\// A form attribute naming another form.
        \\const pointed = input(form, 'pointedName');
        \\eq(form.pointedName, pointed, 'recorded');
        \\pointed.name = 'renamed4';
        \\pointed.setAttribute('form', 'g');
        \\eq(form.pointedName, undefined, 'a form attribute naming another form');
        \\eq(other.renamed4, pointed, 'now the other form owns it');
        \\// A form attribute naming this form, from outside; the form's id
        \\// then changes, and the control has no owner.
        \\const associated = input(outside, 'associatedName');
        \\associated.setAttribute('form', 'f');
        \\eq(form.associatedName, associated, 'recorded through the form attribute');
        \\associated.name = 'renamed5';
        \\form.id = 'f2';
        \\eq(form.associatedName, undefined, 'the form id it named changed');
        \\form.id = 'f';
        \\eq(form.associatedName, undefined, 'and back: the entry stays gone');
        \\eq(form.renamed5, associated, 'the current name answers again');
        \\// An element earlier in the tree takes the id the form attribute names.
        \\const named = input(outside, 'namedName');
        \\named.setAttribute('form', 'f');
        \\eq(form.namedName, named, 'recorded');
        \\named.name = 'renamed6';
        \\const decoy = document.createElement('div');
        \\decoy.id = 'f';
        \\document.body.insertBefore(decoy, document.body.firstChild);
        \\eq(form.namedName, undefined, 'the first element with that id is no form');
        \\decoy.remove();
        \\// An img leaving the form.
        \\const image = form.appendChild(document.createElement('img'));
        \\image.name = 'imageName';
        \\eq(form.imageName, image, 'an img is recorded');
        \\image.name = 'renamed7';
        \\eq(form.imageName, image, 'its past name answers');
        \\image.remove();
        \\eq(form.imageName, undefined, 'an img leaving the form drops it');
        \\// The form's own removal, with a control that named it by attribute.
        \\const far = input(outside, 'farName');
        \\far.setAttribute('form', 'f');
        \\eq(form.farName, far, 'recorded');
        \\far.name = 'renamed8';
        \\form.remove();
        \\eq(form.farName, undefined, 'the form left the tree the control is in');
        \\document.body.appendChild(form);
        \\eq(form.farName, undefined, 'and stays gone');
        \\// innerHTML replacement removes the controls.
        \\const inner = input(form, 'innerName');
        \\eq(form.innerName, inner, 'recorded');
        \\inner.name = 'renamed9';
        \\form.innerHTML = '';
        \\eq(form.innerName, undefined, 'replaced by innerHTML');
    );
}

fn candidatesComeFirst() !void {
    const page = try Page.open("<!doctype html><form id=f></form>");
    defer page.close();
    try page.expectOk(
        \\const form = document.getElementById('f');
        \\// Two candidates: a list, and nothing recorded (step 4 returns first).
        \\const one = input(form, 'pair');
        \\const two = input(form, 'pair');
        \\eq(form.pair instanceof RadioNodeList, true, 'two candidates');
        \\one.name = 'x1';
        \\two.name = 'x2';
        \\eq(form.pair, undefined, 'a list records nothing');
        \\// The current candidate wins over the past entry (step 3 is only for
        \\// none), and replaces it (step 5).
        \\const first = input(form, 'shared');
        \\eq(form.shared, first, 'recorded');
        \\first.name = 'y1';
        \\eq(form.shared, first, 'from the map');
        \\const second = input(form, 'shared');
        \\eq(form.shared, second, 'a current candidate first');
        \\second.name = 'y2';
        \\eq(form.shared, second, 'the entry was replaced');
        \\// A current img candidate also comes before the map (step 2).
        \\const third = input(form, 'kept');
        \\eq(form.kept, third, 'recorded');
        \\third.name = 'y3';
        \\const image = form.appendChild(document.createElement('img'));
        \\image.name = 'kept';
        \\eq(form.kept, image, 'the img is a candidate, and replaces the entry');
        \\image.remove();
        \\eq(form.kept, undefined, 'the img left the form: its entry went with it');
    );
}

fn adoptedFormsKeepWatching() !void {
    const page = try Page.open("<!doctype html><body></body>");
    defer page.close();
    try page.expectOk(
        \\// The agent watches the form, not a document: adopted with its
        \\// control, it still hears the control's removal in its new one.
        \\const other = document.implementation.createHTMLDocument('elsewhere');
        \\const form = other.body.appendChild(other.createElement('form'));
        \\const control = form.appendChild(other.createElement('input'));
        \\control.name = 'adopted';
        \\eq(form.adopted, control, 'recorded in the other document');
        \\control.name = 'adoptedNow';
        \\document.body.appendChild(form);
        \\eq(form.adopted, control, 'adopted with its control: the same owner');
        \\// A change in the document the form left reaches it no more.
        \\other.body.appendChild(other.createElement('div')).remove();
        \\eq(form.adopted, control, 'a change in another document');
        \\control.remove();
        \\eq(form.adopted, undefined, 'removed in its new document');
        \\// A control adopted away from its form, the form left behind.
        \\const kept = form.appendChild(document.createElement('input'));
        \\kept.name = 'leaving';
        \\eq(form.leaving, kept, 'recorded');
        \\kept.name = 'leavingNow';
        \\other.body.appendChild(kept);
        \\eq(form.leaving, undefined, 'adopted away: the removal from this document');
    );
}

fn supportedNamesListPastNames() !void {
    const page = try Page.open("<!doctype html><form id=f><input id=one name=a><input id=two name=b></form>");
    defer page.close();
    try page.expectOk(
        \\const form = document.getElementById('f');
        \\const one = document.getElementById('one');
        \\const two = document.getElementById('two');
        \\eq(form.a, one, 'a');
        \\eq(form.b, two, 'b');
        \\one.name = 'e';
        \\eq(form.e, one, 'e');
        \\one.name = 'c';
        \\two.name = 'd';
        \\one.removeAttribute('id');
        \\two.removeAttribute('id');
    );
    // Step 5: by tree order of the element, then id, name, past - and the
    // past entries of one element oldest first; step 7 drops repeats.
    try names(try page.element("f"), &.{ "c", "a", "e", "d", "b" });
}

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            body() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "a renamed control answers to its past names while its form owner stays" {
    try onThread(renamesKeepTheirPastNames);
}

test "every change of form owner removes the element's past names, at the change" {
    try onThread(ownerChangesRemoveEntries);
}

test "current candidates come before the past names map, and replace its entry" {
    try onThread(candidatesComeFirst);
}

test "a form adopted into another document keeps hearing its elements' changes" {
    try onThread(adoptedFormsKeepWatching);
}

test "the supported property names list past names after the element's own" {
    try onThread(supportedNamesListPastNames);
}
