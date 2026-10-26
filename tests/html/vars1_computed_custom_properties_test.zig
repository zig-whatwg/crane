//! getComputedStyle and custom properties (lane vars1): a custom property's
//! computed value through getPropertyValue (case-sensitive, "" for the
//! guaranteed-invalid value, one space for the empty value), and the
//! computed declaration's enumeration - every longhand, then every custom
//! property with a value in code-point order (css/cssom/
//! cssstyledeclaration-custom-properties.html; integrator Q3).
const std = @import("std");
const testing = std.testing;
const helper = @import("edges_node_holders_helpers.zig");

test "getComputedStyle reads and enumerates custom properties after the longhands" {
    try helper.onFreshThread(enumerate);
}

fn enumerate() !void {
    const page = try helper.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="p" style="--parent: p"><div id="a" style="--b: 1; --a: 2; --empty:; --bad: var(--missing); --Case: x; width: var(--w, 3px)"></div><div id="n"></div></div>';
        \\const a = getComputedStyle(document.getElementById('a'));
        \\const n = getComputedStyle(document.getElementById('n'));
        \\if (a.getPropertyValue('--a') !== '2') throw Error('--a ' + a.getPropertyValue('--a'));
        \\if (a.getPropertyValue('--parent') !== 'p') throw Error('inherited');
        \\if (a.getPropertyValue('--empty') !== ' ') throw Error('empty');
        \\if (a.getPropertyValue('--bad') !== '') throw Error('invalid');
        \\if (a.getPropertyValue('--case') !== '') throw Error('case-sensitive');
        \\if (a.getPropertyValue('--Case') !== 'x') throw Error('--Case');
        \\if (a.width !== '3px') throw Error('substituted width ' + a.width);
        \\const customs = Array.from(a).filter(name => name.startsWith('--'));
        \\if (customs.join(',') !== '--Case,--a,--b,--empty,--parent') throw Error('names ' + customs.join(','));
        \\if (a.length !== n.length + 4) throw Error('length ' + a.length + ' vs ' + n.length);
        \\if (!a[a.length - 1].startsWith('--')) throw Error('customs come last');
        \\if (a.item(a.length) !== '') throw Error('past the end');
        \\if (Array.from(a).slice(0, a.length - 5).some(name => name.startsWith('--'))) throw Error('a custom before a longhand');
    );
}

test "element.style reads, sets and removes custom properties and var() values" {
    try helper.onFreshThread(inlineStyle);
}

fn inlineStyle() !void {
    const page = try helper.Page.open();
    defer page.close();
    try page.run(
        \\const e = document.createElement('div');
        \\document.body.append(e);
        \\e.style.setProperty('--x', '  10px  ');
        \\if (e.style.getPropertyValue('--x') !== '10px') throw Error('set');
        \\e.style.margin = 'var(--x)';
        \\if (e.style.margin !== 'var(--x)') throw Error('margin ' + e.style.margin);
        \\if (e.style.marginTop !== '') throw Error('pending longhand');
        \\if (getComputedStyle(e).marginTop !== '10px') throw Error('computed ' + getComputedStyle(e).marginTop);
        \\if (e.getAttribute('style') !== '--x: 10px; margin: var(--x);') throw Error('attribute ' + e.getAttribute('style'));
        \\e.style.removeProperty('--x');
        \\if (getComputedStyle(e).marginTop !== '0px') throw Error('IACVT');
        \\if (!CSS.supports('color', 'var(--x)') || CSS.supports('color', 'var()')) throw Error('supports');
    );
}
