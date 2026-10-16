//! Lane orphanleak: a form control's own state - its custom validity, an
//! output's default value override, a select's collections, a fieldset's -
//! needs an exit when the control is an ORPHAN: removed from its tree while
//! script held no wrapper of it, so nothing deinits it before its Browser
//! ends (docs/lessons/architecture-an-orphan-s-state-needs-a-sweep-or-the-arena.md).
//! A fieldset's state is made with it; a button's and a select's when their
//! validity is first read - by script, or natively by matching :valid and
//! :invalid, which wraps nothing.
//!
//! The Browser runs on std.testing.allocator, so a block or a string left at
//! its end fails the test. Each test runs on a thread of its own: tests/html
//! is one executable, and a Browser's agent belongs to the thread that made
//! it.
const helpers = @import("edges_node_holders_helpers.zig");

fn parsedControlsDropped() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // The fragment parser makes the controls; nothing ever wraps them.
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<form><fieldset><legend>l</legend><button>b</button><output>o</output>' +
        \\                 '<select><option>1<option selected>2</select></fieldset></form>';
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    );
}

test "parsed form controls dropped unwrapped leave nothing at the Browser's end" {
    try helpers.onFreshThread(parsedControlsDropped);
}

fn matchedStateOrphaned() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Matching :valid and :invalid reads each control's validity natively
    // (form_associated.validationState): a button's and a select's state is
    // made while nothing wraps them. The static list goes first, then the
    // tree.
    try page.run(
        \\globalThis.host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<form><button>b</button><select required><option value="">none</select>' +
        \\                 '<input required><textarea required></textarea></form>';
        \\if (host.querySelectorAll(':valid, :invalid').length !== 5) throw new Error('matched');
    );
    try page.turn();
    try page.run("collectNow();");
    try page.run(
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    );
}

test "controls whose state constraint matching made, dropped unwrapped, leave nothing" {
    try helpers.onFreshThread(matchedStateOrphaned);
}

fn formWithPastNamesReplaced() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Reading a named element off a form records a past name: the form is
    // in the agent's list of forms with entries (dom.form_past_names). Its
    // tree goes by replace-all.
    try page.run(
        \\globalThis.host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<div><form><input name=past></form></div>';
        \\(() => {
        \\  const form = host.querySelector('form');
        \\  if (form.past !== form.firstChild) throw new Error('named');
        \\  form.firstChild.name = 'renamed';
        \\  if (form.past !== form.firstChild) throw new Error('past name');
        \\})();
    );
    try page.turn();
    try page.run("collectNow();");
    try page.run(
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
        \\// A change the agent's list hears after the form went.
        \\host.innerHTML = '<form id=other><input name=x></form>';
    );
    try page.turn();
    try page.run("collectNow();");
}

test "a form with past names, its tree replaced, leaves nothing and its list hears on" {
    try helpers.onFreshThread(formWithPastNamesReplaced);
}

fn retainedControlKeepsState() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const button = document.createElement('button');
        \\button.setCustomValidity('kept');
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.appendChild(button);
        \\host.innerHTML = '';
        \\if (button.validationMessage !== 'kept' || button.checkValidity()) throw new Error('lost its validity');
    );
}

test "a retained control keeps its custom validity after its tree is dropped" {
    try helpers.onFreshThread(retainedControlKeepsState);
}
