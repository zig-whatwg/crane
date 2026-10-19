//! DOM selection stringification shares rendered-text processing with innerText.
const helpers = @import("edges_node_holders_helpers.zig");

fn exercise() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.createElement('div');
        \\document.body.append(host);
        \\const selection = getSelection();
        \\function selected(start, a, end, b) {
        \\  selection.setBaseAndExtent(start, a, end, b);
        \\  return selection.toString();
        \\}
        \\host.innerHTML = '  alpha <span style="display:none">hidden</span>  beta  ';
        \\if (selected(host, 0, host, 3) !== 'alpha beta') throw new Error('raw DOM text returned');
        \\if (selection.getRangeAt(0).toString() !== '  alpha hidden  beta  ') throw new Error('Range changed');
        \\host.textContent = 'one  two';
        \\if (selected(host.firstChild, 3, host.firstChild, 4) !== ' ') throw new Error('partial whitespace lost context');
        \\host.textContent = 'straßE';
        \\host.style.textTransform = 'uppercase';
        \\if (selected(host.firstChild, 4, host.firstChild, 5) !== 'SS') throw new Error('case expansion lost offsets');
        \\host.innerHTML = 'a<span>bc</span> def';
        \\host.style.textTransform = 'capitalize';
        \\const middle = host.querySelector('span').firstChild;
        \\if (selected(middle, 0, middle, 2) !== 'bc') throw new Error('capitalize lost inline context');
        \\if (host.innerText !== 'Abc Def') throw new Error('innerText changed');
        \\selection.removeAllRanges();
        \\host.remove();
    );
}

test "rendered selection bounds preserve whitespace and casing context without leaking" {
    try helpers.onFreshThread(exercise);
}

fn shadowLanguage() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.createElement('div');
        \\host.lang = 'tr';
        \\host.style.textTransform = 'uppercase';
        \\document.body.append(host);
        \\const shadow = host.attachShadow({mode:'open'});
        \\shadow.append(document.createTextNode('i'));
        \\const selection = getSelection();
        \\selection.selectAllChildren(shadow);
        \\const text = selection.toString();
        \\if (text !== 'İ') throw new Error('shadow selection lost host language: ' + JSON.stringify(text));
        \\selection.removeAllRanges();
        \\host.remove();
    );
}

test "rendered selection inherits the shadow host language for direct shadow text" {
    // HTML language inheritance crosses the shadow host. This is the same
    // Turkish casing rule pinned by inner_text_dom_test's slotted-text case.
    try helpers.onFreshThread(shadowLanguage);
}
