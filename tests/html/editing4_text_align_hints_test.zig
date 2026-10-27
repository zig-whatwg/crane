//! Lane editing4: the text-align presentational hints (HTML 15.3.3, 15.3.8;
//! src/dom/style/html-hints.css) and the th rule (html.css), which the
//! justify commands' "alignment value" reads through computed text-align.
//! The browsers compute the hints' "align descendants" values as their own
//! keywords, inherited (integrator probe 1027a, Chrome 155 / Firefox 158 /
//! Safari 27: -webkit-center/-left/-right in Chrome and Safari, -moz-* in
//! Firefox; justify and absmiddle plain in all three), and center a th
//! unless its parent's text-align is not the initial value.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

fn hints() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<center id=c>x</center>' +
        \\  '<div id=dc align=center>x</div><div id=dm align=MIDDLE>x</div><div id=dl align=left>x</div>' +
        \\  '<div id=dr align=right>x</div><div id=dj align=justify>x</div><div id=dx align=bogus>x</div>' +
        \\  '<p id=pc align=center>x</p><h1 id=hr align=right>x</h1><p id=pj align=justify>x</p>' +
        \\  '<table><tbody id=tb align=right><tr id=tr align=left><td id=td align=center>x</td><th id=th align=justify>x</th>' +
        \\  '<td id=tm align=middle>x</td><td id=tn>x</td><th id=tha>x</th></tr></tbody>' +
        \\  '<tbody><tr><th id=th0>x</th></tr><tr style="text-align:right"><th id=thr>x</th></tr>' +
        \\  '<tr align=absmiddle><td id=tab>x</td></tr></tbody></table>' +
        \\  '<div align=center><span id=inner>x</span></div><p id=p>x</p>';
        \\globalThis.ta = (id) => getComputedStyle(document.getElementById(id)).textAlign;
    );
    // Flow content: center and div[align].
    try harness.expectEval(page, "['c','dc','dm','dl','dr','dj','dx'].map(ta).join()", "-webkit-center,-webkit-center,-webkit-center,-webkit-left,-webkit-right,justify,start");
    // p and h1-h6.
    try harness.expectEval(page, "['pc','hr','pj','p'].map(ta).join()", "-webkit-center,-webkit-right,justify,start");
    // Table parts, and a cell inheriting its row's value.
    try harness.expectEval(page, "['tb','tr','td','th','tm','tn','tab'].map(ta).join()", "-webkit-right,-webkit-left,-webkit-center,justify,-webkit-center,-webkit-left,center");
    // The th rule: center under an initial text-align, else the parent's.
    try harness.expectEval(page, "['th0','thr','tha'].map(ta).join()", "center,right,-webkit-left");
    // The descendants inherit the align value.
    try harness.expectEval(page, "ta('inner')", "-webkit-center");
    // The th rule under each parent value (probe 1027a).
    try page.run(
        \\document.body.insertAdjacentHTML('beforeend', '<table id=tright style="text-align:right"><tr><th id=th_tr>x</th></tr>' +
        \\  '<tr style="text-align:start"><th id=th_start>x</th></tr><tr style="text-align:left"><th id=th_left>x</th></tr>' +
        \\  '<tr align=center><th id=th_center>x</th></tr><tr><th id=th_own align=left>x</th></tr></table>' +
        \\  '<div id=author align=center style="text-align:left">x</div>');
    );
    try harness.expectEval(page, "['th_tr','th_start','th_left','th_center','th_own'].map(ta).join()", "right,center,left,-webkit-center,-webkit-left");
    // Author style beats the hint.
    try harness.expectEval(page, "ta('author')", "left");
    // The -internal- keyword is the UA sheet's alone.
    try harness.expectEval(page, "String(CSS.supports('text-align', '-internal-th-center'))", "false");
    try harness.expectEval(page, "(() => { document.head.insertAdjacentHTML('beforeend', '<style>#sheet_th { text-align: -internal-th-center }</style>'); document.body.insertAdjacentHTML('beforeend', '<div id=sheet_th>x</div>'); return ta('sheet_th'); })()", "start");
    // Authors may write the -webkit- keywords; the th keyword is the UA's.
    try harness.expectEval(page, "(() => { const d = document.createElement('div'); d.style.textAlign = '-webkit-center'; const a = d.style.textAlign; d.style.textAlign = '-internal-th-center'; return a + '|' + d.style.textAlign; })()", "-webkit-center|-webkit-center");
}

test "text-align presentational hints, the th rule and the -webkit- align keywords" {
    try helpers.onFreshThread(hints);
}
