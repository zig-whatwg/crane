const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

fn navigation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id="start">a</button><div style="interactivity:inert"><button id="blocked">b</button><button id="restored" style="interactivity:auto">c</button></div><div inert><button style="interactivity:auto" id="hostBlocked">d</button></div><button id="end">e</button>';
        \\start.focus(); blocked.focus();
    );
    try expectScript(page, "document.activeElement.id", "start");
    const document = page.browser.current_context.?.document_instance.?;
    html.focus.navigateSequentially(document, .forward);
    try expectScript(page, "document.activeElement.id", "restored");
    html.focus.navigateSequentially(document, .forward);
    try expectScript(page, "document.activeElement.id", "end");
    html.focus.navigateSequentially(document, .backward);
    try expectScript(page, "document.activeElement.id", "restored");
    try page.run("hostBlocked.focus()");
    try expectScript(page, "document.activeElement.id", "restored");
}

fn modal() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div inert style="interactivity:inert"><dialog id="modal"><button id="inside">a</button></dialog></div>';
        \\modal.showModal(); inside.focus();
    );
    try expectScript(page, "JSON.stringify([document.activeElement.id,getComputedStyle(modal).interactivity])", "[\"inside\",\"auto\"]");
    // HTML unfocusing step 2 returns for an already-inert target. Blur
    // while focusable so this tests refusal to acquire focus, not fixup timing.
    try page.run("inside.blur(); modal.style.interactivity = 'inert'; inside.focus()");
    try expectScript(page, "document.activeElement === inside", "false");
    try page.run("modal.style.interactivity = 'auto'; modal.inert = true; inside.focus()");
    try expectScript(page, "JSON.stringify([document.activeElement === inside,getComputedStyle(modal).interactivity])", "[false,\"inert\"]");
    try page.run("modal.close()");
}

fn selection() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="root"><span>a</span><span id="middle" style="interactivity:inert">b<strong style="user-select:text">c</strong><em style="interactivity:auto">d</em></span><span>e</span></div>';
        \\const range = document.createRange(); range.selectNodeContents(root);
        \\getSelection().addRange(range);
    );
    try expectScript(page, "JSON.stringify([getSelection().toString(),range.toString(),root.innerText])", "[\"ade\",\"abcde\",\"abcde\"]");
    try page.run("middle.inert = true");
    try expectScript(page, "JSON.stringify([getSelection().toString(),range.toString(),root.innerText])", "[\"ae\",\"abcde\",\"abcde\"]");
    try page.run("middle.inert = false; middle.style.interactivity = 'auto'");
    try expectScript(page, "getSelection().toString()", "abcde");
}

test "CSS inertness filters explicit and sequential focus while HTML inertness stays authoritative" {
    try helpers.onFreshThread(navigation);
}

test "modal UA interactivity escapes inherited inertness but keeps its own inert state" {
    try helpers.onFreshThread(modal);
}

fn foreignAttribute() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const answers = [];
        \\function selected(node) { getSelection().selectAllChildren(node); return getSelection().toString(); }
        \\for (const [ns, parentName, childName] of [
        \\ ['http://www.w3.org/2000/svg', 'svg', 'text'],
        \\ ['http://www.w3.org/1998/Math/MathML', 'math', 'mi']]) {
        \\ const host = document.createElement('div');
        \\ const parent = document.createElementNS(ns, parentName), child = document.createElementNS(ns, childName);
        \\ child.textContent = 'foreign'; parent.append(child); host.append(parent); document.body.append(host);
        \\ child.setAttribute('inert',''); answers.push(selected(child)); child.removeAttribute('inert');
        \\ parent.setAttribute('inert',''); answers.push(selected(child)); parent.removeAttribute('inert');
        \\ host.inert = true; answers.push(selected(child)); host.inert = false;
        \\ parent.setAttribute('style','interactivity:inert'); answers.push(selected(child));
        \\ host.remove();
        \\}
    );
    try expectScript(page, "JSON.stringify(answers)", "[\"foreign\",\"foreign\",\"\",\"\",\"foreign\",\"foreign\",\"\",\"\"]");
}

fn modalForeignAttribute() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<svg inert><text id="outside">outside</text></svg><dialog id="modal"><svg inert><text id="inside">inside</text></svg></dialog>';
        \\modal.showModal();
        \\getSelection().selectAllChildren(inside); const insideText = getSelection().toString();
        \\getSelection().selectAllChildren(outside); const outsideText = getSelection().toString();
    );
    try expectScript(page, "JSON.stringify([insideText,outsideText])", "[\"inside\",\"\"]");
    try page.run("modal.close()");
}

test "inert attributes apply only to HTML while CSS inertness reaches foreign elements" {
    try helpers.onFreshThread(foreignAttribute);
}

test "modal inertness ignores foreign attributes inside and blocks the outside subtree" {
    try helpers.onFreshThread(modalForeignAttribute);
}
