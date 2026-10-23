//! Q96: until container-type is supported, every element really has no
//! eligible ancestor; Conditional 5 §7 therefore uses the small viewport.
const helpers = @import("edges_node_holders_helpers.zig");

test "container units on real elements fall back to small viewport units" {
    try helpers.onFreshThread(realElement);
}

fn realElement() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="plain"></div><section id="parent"><div id="child"></div></section>';
        \\const parent = document.getElementById('parent');
        \\parent.style.setProperty('container-type', 'size');
        \\if (parent.style.getPropertyValue('container-type') !== '') throw Error('unsupported container-type was retained');
        \\for (const id of ['plain', 'child']) {
        \\  const target = document.getElementById(id);
        \\  for (const [cq, sv] of [['cqw','svw'],['cqh','svh'],['cqi','svi'],['cqb','svb'],['cqmin','svmin'],['cqmax','svmax']]) {
        \\    target.style.left = '2' + sv;
        \\    const expected = getComputedStyle(target).left;
        \\    target.style.left = '2' + cq;
        \\    if (target.style.left !== '2' + cq) throw Error('container unit dropped: ' + cq);
        \\    if (getComputedStyle(target).left !== expected) throw Error(id + ' ' + cq + ' fallback');
        \\  }
        \\}
    );
}
