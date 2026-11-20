//! Lane edit3: an element whose contenteditable is true inside richly
//! editable content is edited as content of the outer editing host, not as a
//! host of its own (src/html/execcommand/common.zig isEditingHost) - all
//! three browsers (Blink's RootEditableElement is the highest editable
//! ancestor). editing/other/shadow_root_iteration_in_block_style.html: with
//! removeFormat the browsers then split three ways on the span (Chrome
//! style="", Safari no style attribute, Firefox unwraps it); with no majority
//! there the Editing spec decides - unwrap, Firefox's result (wpt.fyi
//! 2358bd4835; the integrator's golden-rule-2 ruling of 2026-11-20).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

fn nestedHost() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="container" contenteditable></div><div id="div" contenteditable>hello<span id="span" contenteditable style="color:red">world</span></div>';
        \\container.attachShadow({ mode: 'open' }).innerHTML = '<span contenteditable>shadow root</span>';
        \\globalThis.inputs = [];
        \\div.addEventListener('input', (e) => inputs.push(e.target.id + ':' + e.inputType));
        \\span.addEventListener('input', (e) => inputs.push('span saw ' + e.inputType));
        \\const range = document.createRange();
        \\range.selectNodeContents(span);
        \\getSelection().removeAllRanges();
        \\getSelection().addRange(range);
        \\globalThis.returned = document.execCommand('RemoveFormat');
    );
    // The span goes (the spec, Firefox); the input event goes to the outer
    // host - the affected editing host - and bubbles past nothing else.
    try harness.expectEval(page, "String(returned) + '|' + div.innerHTML + '|' + inputs.join(',')", "true|helloworld|div:formatRemove");
    // A plaintext-only element nested in a true host stays its own host: no
    // bold there (Chrome and Safari; root.zig isPlaintextOnly).
    try page.run(
        \\document.body.innerHTML = '<div contenteditable>a<span id=p contenteditable=plaintext-only>bc</span></div>';
        \\getSelection().selectAllChildren(p);
        \\globalThis.bolded = document.execCommand('bold');
    );
    try harness.expectEval(page, "String(bolded) + '|' + p.outerHTML", "false|<span id=\"p\" contenteditable=\"plaintext-only\">bc</span>");
    // A true element nested in a plaintext-only host is a rich host of its
    // own: bold applies there.
    try page.run(
        \\document.body.innerHTML = '<div contenteditable=plaintext-only>a<span id=r contenteditable>bc</span></div>';
        \\getSelection().selectAllChildren(r);
        \\globalThis.bolded = document.execCommand('bold');
    );
    try harness.expectEval(page, "String(bolded) + '|' + r.innerHTML", "true|<b>bc</b>");
}

test "a contenteditable element inside an editable host is the outer host's content" {
    try helpers.onFreshThread(nestedHost);
}
