//! SVG 2 §4.3.3: specific interfaces through createElementNS, XML and HTML.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const helpers = @import("edges_node_holders_helpers.zig");

fn constructors() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    // Representative concrete and abstract classes from geometry, structure,
    // text, paint, animation and filters must reach their Node parent.
    inline for (.{ interfaces.SVGCircleElement, interfaces.SVGSVGElement, interfaces.SVGTextElement, interfaces.SVGLinearGradientElement, interfaces.SVGAnimateElement, interfaces.SVGFEBlendElement }) |T| {
        const element = try T.init(std.testing.allocator, &context);
        defer runtime.Instance.deinit(element);
        try std.testing.expectEqual(@as(u16, 1), try interfaces.Node.get_nodeType(element));
        try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("data-xm1"), .{ .domstring = runtime.DOMString.initInterned("value") });
        var value = (try interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("data-xm1"))) orelse return error.MissingAttribute;
        defer value.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("value", value.asSlice());
    }
}

test "SVG generated construction reaches Element and Node for every family" {
    try helpers.onFreshThread(constructors);
}

fn constructionFailure(allocator: std.mem.Allocator, context: runtime.Context) !void {
    inline for (.{ interfaces.SVGCircleElement, interfaces.SVGSVGElement, interfaces.SVGTextElement, interfaces.SVGLinearGradientElement, interfaces.SVGAnimateElement, interfaces.SVGFEBlendElement }) |T| {
        const element = try T.init(allocator, context);
        defer runtime.Instance.deinit(element);
        try std.testing.expectEqual(@as(u16, 1), try interfaces.Node.get_nodeType(element));
    }
}

fn allocationFailures() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    // The slab and context keep their normal leak-checking allocator; fail
    // each allocation made by the generated construction chain itself.
    try std.testing.checkAllAllocationFailures(std.testing.allocator, constructionFailure, .{&context});
}

test "SVG parent construction unwinds every failed allocation" {
    try helpers.onFreshThread(allocationFailures);
}

fn allElementInterfaces() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const svgCases = [["a","SVGAElement",true],["animate","SVGAnimateElement",false],["animateMotion","SVGAnimateMotionElement",false],["animateTransform","SVGAnimateTransformElement",false],["circle","SVGCircleElement",true],["clipPath","SVGClipPathElement",false],["defs","SVGDefsElement",true],["desc","SVGDescElement",false],["ellipse","SVGEllipseElement",true],["feBlend","SVGFEBlendElement",false],["feColorMatrix","SVGFEColorMatrixElement",false],["feComponentTransfer","SVGFEComponentTransferElement",false],["feComposite","SVGFECompositeElement",false],["feConvolveMatrix","SVGFEConvolveMatrixElement",false],["feDiffuseLighting","SVGFEDiffuseLightingElement",false],["feDisplacementMap","SVGFEDisplacementMapElement",false],["feDistantLight","SVGFEDistantLightElement",false],["feDropShadow","SVGFEDropShadowElement",false],["feFlood","SVGFEFloodElement",false],["feFuncA","SVGFEFuncAElement",false],["feFuncB","SVGFEFuncBElement",false],["feFuncG","SVGFEFuncGElement",false],["feFuncR","SVGFEFuncRElement",false],["feGaussianBlur","SVGFEGaussianBlurElement",false],["feImage","SVGFEImageElement",false],["feMerge","SVGFEMergeElement",false],["feMergeNode","SVGFEMergeNodeElement",false],["feMorphology","SVGFEMorphologyElement",false],["feOffset","SVGFEOffsetElement",false],["fePointLight","SVGFEPointLightElement",false],["feSpecularLighting","SVGFESpecularLightingElement",false],["feSpotLight","SVGFESpotLightElement",false],["feTile","SVGFETileElement",false],["feTurbulence","SVGFETurbulenceElement",false],["filter","SVGFilterElement",false],["foreignObject","SVGForeignObjectElement",true],["g","SVGGElement",true],["image","SVGImageElement",true],["line","SVGLineElement",true],["linearGradient","SVGLinearGradientElement",false],["marker","SVGMarkerElement",false],["mask","SVGMaskElement",false],["metadata","SVGMetadataElement",false],["mpath","SVGMPathElement",false],["path","SVGPathElement",true],["pattern","SVGPatternElement",false],["polygon","SVGPolygonElement",true],["polyline","SVGPolylineElement",true],["radialGradient","SVGRadialGradientElement",false],["rect","SVGRectElement",true],["script","SVGScriptElement",false],["set","SVGSetElement",false],["stop","SVGStopElement",false],["style","SVGStyleElement",false],["svg","SVGSVGElement",true],["switch","SVGSwitchElement",true],["symbol","SVGSymbolElement",true],["text","SVGTextElement",true],["textPath","SVGTextPathElement",true],["title","SVGTitleElement",false],["tspan","SVGTSpanElement",true],["use","SVGUseElement",true],["view","SVGViewElement",false],["xm1-unknown","SVGElement",false],["q","SVGElement",false]];
        \\const svgNamespace = 'http://www.w3.org/2000/svg';
        \\const makers = {
        \\  createElementNS: name => document.createElementNS(svgNamespace, name),
        \\  XML: name => new DOMParser().parseFromString('<' + name + ' xmlns="' + svgNamespace + '"/>', 'application/xml').documentElement,
        \\  HTML: name => {
        \\    const container = document.createElement('div');
        \\    container.innerHTML = '<svg><' + name + '></' + name + '></svg>';
        \\    return container.firstChild.firstChild;
        \\  }
        \\};
        \\const missing = svgCases.filter(([, type]) => typeof globalThis[type] !== 'function').map(([, type]) => type);
        \\if (missing.length) throw new Error('missing SVG constructors: ' + missing.join(', '));
        \\function checkSvgElement(e, name, type, graphics) {
        \\  if (!(e instanceof globalThis[type])) throw new Error(name + ': expected ' + type + ', got ' + e.constructor.name);
        \\  if (!(e instanceof SVGElement) || !(e instanceof Element)) throw new Error(name + ': missing ancestor interface');
        \\  if ((e instanceof SVGGraphicsElement) !== graphics) throw new Error(name + ': wrong graphics ancestry');
        \\  if (e.nodeType !== Node.ELEMENT_NODE || e.localName !== name || e.namespaceURI !== svgNamespace) throw new Error(name + ': node state');
        \\  e.setAttribute('data-xm1', 'value');
        \\  if (e.getAttribute('data-xm1') !== 'value') throw new Error(name + ': attribute state');
        \\  if (!(e.cloneNode(false) instanceof globalThis[type])) throw new Error(name + ': clone interface');
        \\}
        \\for (const [name, type, graphics] of svgCases) {
        \\  for (const make of Object.values(makers)) checkSvgElement(make(name), name, type, graphics);
        \\}
    );
}

test "all SVG element interfaces survive creation, XML parsing, HTML parsing and cloning" {
    try helpers.onFreshThread(allElementInterfaces);
}
