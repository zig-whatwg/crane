# Chapter 5: Document Structure

::: }}
[Overview](./) · [Previous](types.html) · [Next](styling.html) ·
[Elements](eltindex.html) · [Attributes](attindex.html) ·
[Properties](propidx.html)

## Contents

1. 1. [[5.1.] Defining an SVG document fragment: the
 ['svg'] element](struct.html#NewDocument)
 1. [[5.1.1.] Overview](struct.html#NewDocumentOverview)
 2. [[5.1.2.] Namespace](struct.html#Namespace)
 3. [[5.1.3.] Definitions](struct.html#Definitions)
 4. [[5.1.4.] The ['svg']
 element](struct.html#SVGElement)
 2. [[5.2.] Grouping: the ['g']
 element](struct.html#Groups)
 1. [[5.2.1.] Overview](struct.html#GroupsOverview)
 2. [[5.2.2.] The ['g']
 element](struct.html#GElement)
 3. [[5.3.] Defining content for reuse, and the
 ['defs'] element](struct.html#Head)
 1. [[5.3.1.] Overview](struct.html#Overview)
 2. [[5.3.2.] The ['defs']
 element](struct.html#DefsElement)
 4. [[5.4.] The ['symbol']
 element](struct.html#SymbolElement)
 1. [[5.4.1.] Attributes](struct.html#SymbolAttributes)
 2. [[5.4.2.] Notes on symbols](struct.html#SymbolNotes)
 5. [[5.5.] The ['use']
 element](struct.html#UseElement)
 1. [[5.5.1.] The use-element shadow
 tree](struct.html#UseShadowTree)
 2. [[5.5.2.] Layout of re-used
 graphics](struct.html#UseLayout)
 3. [[5.5.3.] Style Scoping and
 Inheritance](struct.html#UseStyleInheritance)
 4. [[5.5.4.] Animations in use-element shadow
 trees](struct.html#UseAnimations)
 5. [[5.5.5.] Event handling in use-element shadow
 trees](struct.html#UseEventHandling)
 6. [[5.6.] Conditional
 processing](struct.html#ConditionalProcessing)
 1. [[5.6.1.] Conditional processing
 overview](struct.html#ConditionalProcessingOverview)
 2. [[5.6.2.]
 Definitions](struct.html#ConditionalProcessingDefinitions)
 3. [[5.6.3.] The ['switch']
 element](struct.html#SwitchElement)
 4. [[5.6.4.] The ['requiredExtensions']
 attribute](struct.html#ConditionalProcessingRequiredExtensionsAttribute)
 5. [[5.6.5.] The ['systemLanguage']
 attribute](struct.html#ConditionalProcessingSystemLanguageAttribute)
 7. [[5.7.] The ['desc'] and
 ['title']
 elements](struct.html#DescriptionAndTitleElements)
 1. [[5.7.1.]
 Definition](struct.html#DescriptionDefinitions)
 8. [[5.8.] The ['metadata']
 element](struct.html#MetadataElement)
 9. [[5.9.] HTML metadata
 elements](struct.html#HTMLMetadataElements)
 10. [[5.10.] Foreign namespaces and private
 data](struct.html#ForeignNamespaces)
 11. [[5.11.] Common
 attributes](struct.html#CommonAttributes)
 1. [[5.11.1.]
 Definitions](struct.html#CommonAttributeDefinitions)
 2. [[5.11.2.] Attributes common to all elements:
 ['id']](struct.html#Core.attrib)
 3. [[5.11.3.] The ['lang'] and
 ['xml:lang']
 attributes](struct.html#LangSpaceAttrs)
 4. [[5.11.4.] The ['xml:space']
 attribute](struct.html#WhitespaceProcessingXMLSpaceAttribute)
 5. [[5.11.5.] The ['tabindex']
 attribute](struct.html#tabindexattribute)
 6. [[5.11.6.] The ['autofocus']
 attribute](struct.html#autofocusattribute)
 7. [[5.11.7.] The ['data-\*']
 attributes](struct.html#DataAttributes)
 12. [[5.12.] WAI-ARIA
 attributes](struct.html#WAIARIAAttributes)
 1. [[5.12.1.]
 Definitions](struct.html#WAIARIA-definitions)
 2. [[5.12.2.] Role
 attribute](struct.html#roleattribute)
 3. [[5.12.3.] State and property attributes (all aria-
 attributes)](struct.html#ARIAStateandPropertyAttributes)
 4. [[5.12.4.] Implicit and Allowed ARIA
 Semantics](struct.html#implicit-aria-semantics)
 13. [[5.13.] DOM interfaces](struct.html#DOMInterfaces)
 1. [[5.13.1.] Extensions to the Document
 interface](struct.html#InterfaceDocumentExtensions)
 2. [[5.13.2.] Interface
 SVGSVGElement](struct.html#InterfaceSVGSVGElement)
 3. [[5.13.3.] Interface
 SVGGElement](struct.html#InterfaceSVGGElement)
 4. [[5.13.4.] Interface
 SVGDefsElement](struct.html#InterfaceSVGDefsElement)
 5. [[5.13.5.] Interface
 SVGDescElement](struct.html#InterfaceSVGDescElement)
 6. [[5.13.6.] Interface
 SVGMetadataElement](struct.html#InterfaceSVGMetadataElement)
 7. [[5.13.7.] Interface
 SVGTitleElement](struct.html#InterfaceSVGTitleElement)
 8. [[5.13.8.] Interface
 SVGSymbolElement](struct.html#InterfaceSVGSymbolElement)
 9. [[5.13.9.] Interface
 SVGUseElement](struct.html#InterfaceSVGUseElement)
 10. [[5.13.10.] Interface
 SVGUseElementShadowRoot](struct.html#InterfaceSVGUseElementShadowRoot)
 11. [[5.13.11.] Interface
 ShadowAnimation](struct.html#InterfaceShadowAnimation)
 12. [[5.13.12.] Interface
 SVGSwitchElement](struct.html#InterfaceSVGSwitchElement)
 13. [[5.13.13.] Mixin
 GetSVGDocument](struct.html#InterfaceGetSVGDocument)

## 5.1. Defining an SVG document fragment: the ['svg'] element
### 5.1.1. Overview
An [SVG document fragment](struct.html#TermSVGDocumentFragment) consists
of any number of SVG elements contained within an
['[svg](struct.html#SVGElement)'] element.

An SVG document fragment can range from an empty fragment (i.e., no
content inside of the ['[svg](struct.html#SVGElement)']
element), to a very simple SVG document fragment containing a single SVG
[graphics element](struct.html#TermGraphicsElement) such as a
['[rect](shapes.html#RectElement)'], to a complex, deeply
nested collection of [container
elements](struct.html#TermContainerElement) and [graphics
elements](struct.html#TermGraphicsElement).

An SVG document fragment can stand by itself as a self-contained file or
resource, in which case the SVG document fragment is an [SVG
document](struct.html#TermSVGDocumentFragment), or it can be embedded
inline as a fragment within a parent HTML or XML document.

The following example shows simple SVG content embedded inline as a
fragment within a parent XML document. Note the use of XML namespaces to
indicate that the ['[svg](struct.html#SVGElement)'] and
['[ellipse](shapes.html#EllipseElement)'] elements belong
to the [SVG namespace](struct.html#Namespace):

``` xml

<?xml version="1.0" standalone="yes"?>
<parent xmlns="http://example.org"
 xmlns:svg="http://www.w3.org/2000/svg">
 <!-- parent contents here -->
 <svg:svg width="4cm" height="8cm">
 <svg:ellipse cx="2cm" cy="4cm" rx="2cm" ry="1cm" />
 </svg:svg>
 <!-- ... -->
</parent>
```

This example shows a slightly more complex (i.e., it contains multiple
rectangles) stand-alone, self-contained SVG document:

``` xml
<?xml version="1.0" standalone="no"?>
<svg width="5cm" height="4cm" version="1.1"
 xmlns="http://www.w3.org/2000/svg">
 <desc>Four separate rectangles
 </desc>
 <rect x="0.5cm" y="0.5cm" width="2cm" height="1cm"/>
 <rect x="0.5cm" y="2cm" width="1cm" height="1.5cm"/>
 <rect x="3cm" y="0.5cm" width="1.5cm" height="2cm"/>
 <rect x="3.5cm" y="3cm" width="1cm" height="0.5cm"/>

 <!-- Show outline of viewport using 'rect' element -->
 <rect x=".01cm" y=".01cm" width="4.98cm" height="3.98cm"
 fill="none" stroke="blue" stroke-width=".02cm" />

</svg>
```

['[svg](struct.html#SVGElement)'] elements can appear in
the middle of SVG content. This is the mechanism by which SVG document
fragments can be embedded within other SVG document fragments.

Another use for ['[svg](struct.html#SVGElement)']
elements within the middle of SVG content is to establish a new SVG
viewport. (See [Establishing a new SVG
viewport](coords.html#EstablishingANewSVGViewport).)

### 5.1.2. Namespace
When SVG is parsed as a XML, for compliance with the [Namespaces in
XML](https://www.w3.org/TR/2006/REC-xml-names-20060816/) Recommendation
\[[xml-names](refs.html#ref-xml-names)\], an SVG namespace declaration
must be provided so that all SVG elements are identified as belonging to
the SVG namespace.

When using the HTML syntax, the namespace is provided automatically by
the HTML parser.

``` html

<html>
<svg viewBox="0 0 100 100">
 <circle cx="50" cy="50" r="50" fill="green">
</svg>
</html>
```

As the example shows there\'s no need to have an ['xmlns']
attribute declaring that the element is in the SVG namespace when using
the HTML parser. The HTML parser will automatically create the SVG
elements in the proper namespace.

This section should talk about how a document\'s
behavior is defined in terms of the DOM, and also explain how the HTML
parser can create SVG fragments.

The SVG 2 namespace is `http://www.w3.org/2000/svg`, which is the same
as for earlier versions of SVG.

The following are possible ways to provide a namespace declaration when
SVG is parsed as XML. An ['xmlns'] attribute without a
namespace prefix could be specified on an
['[svg](struct.html#SVGElement)'] element, which means
that SVG is the default namespace for all elements within the scope of
the element with the ['xmlns'] attribute:

``` xml

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
 <rect x="10" y="10" width="80" height="80" fill="green" />
</svg>
```

If a namespace prefix is specified on the ['xmlns']
attribute (e.g., `xmlns:svg="http://www.w3.org/2000/svg"`), then
the corresponding namespace is not the default namespace, so an explicit
namespace prefix must be assigned to the elements:

``` xml

<svg:svg xmlns:svg="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
 <svg:rect x="10" y="10" width="80" height="80" fill="green" />
</svg:svg>
```

Namespace prefixes can be specified on ancestor elements (illustrated in
the [above example](#EmbeddedSVGExample)). For more information, refer
to the [Namespaces in
XML](https://www.w3.org/TR/2006/REC-xml-names-20060816/) Recommendation
\[[xml-names](refs.html#ref-xml-names)\].

### 5.1.3. Definitions
[structural element]
: The structural elements are those which define the primary structure
 of an SVG document. Specifically, the following elements are
 structural elements:
 ['[defs](struct.html#DefsElement)'],
 ['[g](struct.html#GElement)'],
 ['[svg](struct.html#SVGElement)'],
 ['[symbol](struct.html#SymbolElement)'] and
 ['[use](struct.html#UseElement)'].

[structurally external element]
: Elements that define its structure by reference to an external
 resource. Specifically, the following elements are structurally
 external elements when they have an ['href'] attribute:
 ['[foreignObject](embedded.html#ForeignObjectElement)'],
 ['[image](embedded.html#ImageElement)'],
 ['[script](interact.html#ScriptElement)'] and
 ['[use](struct.html#UseElement)'].

[current SVG document fragment]
: The document sub-tree which starts with the outermost ancestor
 ['[svg](struct.html#SVGElement)'] element of a given
 SVG element, with the requirement that all container elements
 between the outermost
 ['[svg](struct.html#SVGElement)'] and the given
 element are all elements in the SVG namespace.

[outermost svg element]
: The furthest ['[svg](struct.html#SVGElement)']
 ancestor element that remains in the [current SVG document
 fragment](struct.html#TermCurrentSVGDocumentFragment).

[SVG document fragment]
: A document sub-tree which starts with an
 ['[svg](struct.html#SVGElement)'] element which is
 either the root element of the document or whose parent element is
 not in the SVG namespace. An SVG document fragment can consist of a
 stand-alone SVG document, or a fragment of a parent document
 enclosed by an ['[svg](struct.html#SVGElement)']
 element. However, an
 ['[svg](struct.html#SVGElement)'] element that is a
 direct child of another SVG-namespaced element is not the root of an
 SVG document fragment.

[SVG elements]
: Any element in the [SVG namespace](struct.html#Namespace).

[graphics element]
: One of the element types that can cause graphics to be drawn onto
 the target canvas. Specifically:
 ['[circle](shapes.html#CircleElement)'],
 ['[ellipse](shapes.html#EllipseElement)'],
 ['[foreignObject](embedded.html#ForeignObjectElement)'],
 ['[image](embedded.html#ImageElement)'],
 ['[line](shapes.html#LineElement)'],
 ['[path](paths.html#PathElement)'],
 ['[polygon](shapes.html#PolygonElement)'],
 ['[polyline](shapes.html#PolylineElement)'],
 ['[rect](shapes.html#RectElement)'],
 ['[text](text.html#TextElement)'],
 ['[textPath](text.html#TextPathElement)'] and
 ['[tspan](text.html#TextElement)'].

[graphics referencing element]
: A graphics element which uses a reference to a different document or
 element as the source of its graphical content. Specifically:
 ['[image](embedded.html#ImageElement)'] and
 ['[use](struct.html#UseElement)'].

### 5.1.4. The ['svg'] element
 -------------------- --------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Support transforming ['[svg](struct.html#SVGElement)'] elements.
 Resolution: [We will allow ['transform'] on ['svg'] in SVG 2.](https://www.w3.org/2011/10/28-svg-irc#T00-23-44)
 Purpose: To allow transforms on nested ['[svg](struct.html#SVGElement)'] elements, in line with author expectations.
 Owner: Dirk (no action)
 Status: Done
 -------------------- --------------------------------------------------------------------------------------------------------------------------------

:::: element-summary
::: element-summary-name
['[svg]']

Categories:
: [Container element](struct.html#TermContainerElement), [renderable
 element](render.html#TermRenderableElement), [structural
 element](struct.html#TermStructuralElement)

Content model:
: Any number of the following elements, in any order:
 - [animation
 elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)[
 ---
 ['[animate](https://w3c.github.io/svgwg/specs/animations/#AnimateElement)'],
 ['[animateMotion](https://w3c.github.io/svgwg/specs/animations/#AnimateMotionElement)'],
 ['[animateTransform](https://w3c.github.io/svgwg/specs/animations/#AnimateTransformElement)'],
 ['[set](https://w3c.github.io/svgwg/specs/animations/#SetElement)']]
 - [descriptive elements](struct.html#TermDescriptiveElement)[ ---
 ['[desc](struct.html#DescElement)'],
 ['[title](struct.html#TitleElement)'],
 ['[metadata](struct.html#MetadataElement)']]
 - [paint server elements](painting.html#TermPaintServerElement)[ ---
 ['[linearGradient](pservers.html#LinearGradientElement)'],
 ['[radialGradient](pservers.html#RadialGradientElement)'],
 ['[pattern](pservers.html#PatternElement)']]
 - [shape elements](shapes.html#TermShapeElement)[ ---
 ['[circle](shapes.html#CircleElement)'],
 ['[ellipse](shapes.html#EllipseElement)'],
 ['[line](shapes.html#LineElement)'],
 ['[path](paths.html#PathElement)'],
 ['[polygon](shapes.html#PolygonElement)'],
 ['[polyline](shapes.html#PolylineElement)'],
 ['[rect](shapes.html#RectElement)']]
 - [structural elements](struct.html#TermStructuralElement)[ ---
 ['[defs](struct.html#DefsElement)'],
 ['[g](struct.html#GElement)'],
 ['[svg](struct.html#SVGElement)'],
 ['[symbol](struct.html#SymbolElement)'],
 ['[use](struct.html#UseElement)']]

 [[a](linking.html#AElement)],
 [[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)],
 [[filter](https://drafts.csswg.org/filter-effects-1/#FilterElement)],
 [[foreignObject](embedded.html#ForeignObjectElement)],
 [[image](embedded.html#ImageElement)],
 [[marker](painting.html#MarkerElement)],
 [[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)],
 [[script](interact.html#ScriptElement)],
 [[style](styling.html#StyleElement)],
 [[switch](struct.html#SwitchElement)],
 [[text](text.html#TextElement)],
 [[view](linking.html#ViewElement)]

Attributes:

: - [aria attributes](struct.html#TermARIAAttribute)[ ---
 ['[aria-activedescendant](https://www.w3.org/TR/wai-aria-1.1/#aria-activedescendant)'],
 ['[aria-atomic](https://www.w3.org/TR/wai-aria-1.1/#aria-atomic)'],
 ['[aria-autocomplete](https://www.w3.org/TR/wai-aria-1.1/#aria-autocomplete)'],
 ['[aria-busy](https://www.w3.org/TR/wai-aria-1.1/#aria-busy)'],
 ['[aria-checked](https://www.w3.org/TR/wai-aria-1.1/#aria-checked)'],
 ['[aria-colcount](https://www.w3.org/TR/wai-aria-1.1/#aria-colcount)'],
 ['[aria-colindex](https://www.w3.org/TR/wai-aria-1.1/#aria-colindex)'],
 ['[aria-colspan](https://www.w3.org/TR/wai-aria-1.1/#aria-colspan)'],
 ['[aria-controls](https://www.w3.org/TR/wai-aria-1.1/#aria-controls)'],
 ['[aria-current](https://www.w3.org/TR/wai-aria-1.1/#aria-current)'],
 ['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)'],
 ['[aria-details](https://www.w3.org/TR/wai-aria-1.1/#aria-details)'],
 ['[aria-disabled](https://www.w3.org/TR/wai-aria-1.1/#aria-disabled)'],
 ['[aria-dropeffect](https://www.w3.org/TR/wai-aria-1.1/#aria-dropeffect)'],
 ['[aria-errormessage](https://www.w3.org/TR/wai-aria-1.1/#aria-errormessage)'],
 ['[aria-expanded](https://www.w3.org/TR/wai-aria-1.1/#aria-expanded)'],
 ['[aria-flowto](https://www.w3.org/TR/wai-aria-1.1/#aria-flowto)'],
 ['[aria-grabbed](https://www.w3.org/TR/wai-aria-1.1/#aria-grabbed)'],
 ['[aria-haspopup](https://www.w3.org/TR/wai-aria-1.1/#aria-haspopup)'],
 ['[aria-hidden](https://www.w3.org/TR/wai-aria-1.1/#aria-hidden)'],
 ['[aria-invalid](https://www.w3.org/TR/wai-aria-1.1/#aria-invalid)'],
 ['[aria-keyshortcuts](https://www.w3.org/TR/wai-aria-1.1/#aria-keyshortcuts)'],
 ['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)'],
 ['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)'],
 ['[aria-level](https://www.w3.org/TR/wai-aria-1.1/#aria-level)'],
 ['[aria-live](https://www.w3.org/TR/wai-aria-1.1/#aria-live)'],
 ['[aria-modal](https://www.w3.org/TR/wai-aria-1.1/#aria-modal)'],
 ['[aria-multiline](https://www.w3.org/TR/wai-aria-1.1/#aria-multiline)'],
 ['[aria-multiselectable](https://www.w3.org/TR/wai-aria-1.1/#aria-multiselectable)'],
 ['[aria-orientation](https://www.w3.org/TR/wai-aria-1.1/#aria-orientation)'],
 ['[aria-owns](https://www.w3.org/TR/wai-aria-1.1/#aria-owns)'],
 ['[aria-placeholder](https://www.w3.org/TR/wai-aria-1.1/#aria-placeholder)'],
 ['[aria-posinset](https://www.w3.org/TR/wai-aria-1.1/#aria-posinset)'],
 ['[aria-pressed](https://www.w3.org/TR/wai-aria-1.1/#aria-pressed)'],
 ['[aria-readonly](https://www.w3.org/TR/wai-aria-1.1/#aria-readonly)'],
 ['[aria-relevant](https://www.w3.org/TR/wai-aria-1.1/#aria-relevant)'],
 ['[aria-required](https://www.w3.org/TR/wai-aria-1.1/#aria-required)'],
 ['[aria-roledescription](https://www.w3.org/TR/wai-aria-1.1/#aria-roledescription)'],
 ['[aria-rowcount](https://www.w3.org/TR/wai-aria-1.1/#aria-rowcount)'],
 ['[aria-rowindex](https://www.w3.org/TR/wai-aria-1.1/#aria-rowindex)'],
 ['[aria-rowspan](https://www.w3.org/TR/wai-aria-1.1/#aria-rowspan)'],
 ['[aria-selected](https://www.w3.org/TR/wai-aria-1.1/#aria-selected)'],
 ['[aria-setsize](https://www.w3.org/TR/wai-aria-1.1/#aria-setsize)'],
 ['[aria-sort](https://www.w3.org/TR/wai-aria-1.1/#aria-sort)'],
 ['[aria-valuemax](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemax)'],
 ['[aria-valuemin](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemin)'],
 ['[aria-valuenow](https://www.w3.org/TR/wai-aria-1.1/#aria-valuenow)'],
 ['[aria-valuetext](https://www.w3.org/TR/wai-aria-1.1/#aria-valuetext)'],
 ['[role](struct.html#RoleAttribute)']]
 - [conditional processing
 attributes](struct.html#TermConditionalProcessingAttribute)[ ---
 ['[requiredExtensions](struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](struct.html#SystemLanguageAttribute)']]
 - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [document event attributes](interact.html#EventAttributes)[ ---
 ['[onunload](interact.html#EventAttributes)'],
 ['[onabort](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [presentation attributes](styling.html#TermPresentationAttribute)[
 --- ]
 - ['[viewBox](coords.html#ViewBoxAttribute)']
 - ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 - ['[transform](coords.html#TransformProperty)']

Geometry properties:

: - [x](geometry.html#XProperty)
 - [y](geometry.html#YProperty)
 - [width](geometry.html#Sizing)
 - [height](geometry.html#Sizing)

DOM Interfaces:

: - [SVGSVGElement](struct.html#InterfaceSVGSVGElement)

The [x](geometry.html#XProperty) and
[y](geometry.html#YProperty) attributes specify the top-left
corner of the rectangular region into which an embedded
['[svg](struct.html#SVGElement)'] element is placed. On
an [outermost svg element](struct.html#TermOutermostSVGElement), these
attributes have no effect.

For [outermost svg elements](struct.html#TermOutermostSVGElement), the
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) attributes specify the
intrinsic size of the SVG document fragment. For embedded
['[svg](struct.html#SVGElement)'] elements, they specify
the size of the rectangular region into which the
['[svg](struct.html#SVGElement)'] element is placed. In
either case, a computed style of [auto] is treated
equivalent to [100%].

If an SVG document is likely to be referenced as a component of another
document, the author will often want to include a
['[viewBox](coords.html#ViewBoxAttribute)'] attribute on the
[outermost svg element](struct.html#TermOutermostSVGElement) of the
referenced document. This attribute provides a convenient way to design
SVG documents to scale-to-fit into an arbitrary SVG viewport.

The ['[svg](struct.html#SVGElement)'] element exposes as
[event handler content
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-content-attributes)
a number of the [event
handlers](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers)
of the
[Window](https://html.spec.whatwg.org/multipage/window-object.html#window)
object. It also mirrors their [event handler IDL
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes).

The [onblur](interact.html),
['[onerror](interact.html#EventAttributes)'],
[onfocus](interact.html),
['[onload](interact.html#EventAttributes)'], and
['[onscroll](interact.html#EventAttributes)'] [event
handlers](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers)
of the
[Window](https://html.spec.whatwg.org/multipage/window-object.html#window)
object, exposed on the ['[svg](struct.html#SVGElement)']
element, replace the generic [event
handlers](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers)
with the same names normally supported by [SVG
elements](struct.html#TermSVGElements).

## 5.2. Grouping: the ['g'] element
### 5.2.1. Overview
[container element]
: An element which can have [graphics
 elements](struct.html#TermGraphicsElement) and other container
 elements as child elements. Specifically:
 ['[a](linking.html#AElement)'],
 ['[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)'],
 ['[defs](struct.html#DefsElement)'],
 ['[g](struct.html#GElement)'],
 ['[marker](painting.html#MarkerElement)'],
 ['[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)'],
 ['[pattern](pservers.html#PatternElement)'],
 ['[svg](struct.html#SVGElement)'],
 ['[switch](struct.html#SwitchElement)'] and
 ['[symbol](struct.html#SymbolElement)'].

The ['[g](struct.html#GElement)'] element is a [container
element](struct.html#TermContainerElement) for grouping together related
[graphics elements](struct.html#TermGraphicsElement).

A group of elements, as well as individual objects, can be given a name
using the ['[id](struct.html#IDAttribute)'] attribute. Named
groups are needed for several purposes such as animation and re-usable
objects.

An example:

``` xml
<?xml version="1.0" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg"
 version="1.1" width="5cm" height="5cm">
 <desc>Two groups, each of two rectangles</desc>
 <g id="group1" fill="red">
 <rect x="1cm" y="1cm" width="1cm" height="1cm"/>
 <rect x="3cm" y="1cm" width="1cm" height="1cm"/>
 </g>
 <g id="group2" fill="blue">
 <rect x="1cm" y="3cm" width="1cm" height="1cm"/>
 <rect x="3cm" y="3cm" width="1cm" height="1cm"/>
 </g>

 <!-- Show outline of viewport using 'rect' element -->
 <rect x=".01cm" y=".01cm" width="4.98cm" height="4.98cm"
 fill="none" stroke="blue" stroke-width=".02cm"/>
</svg>
```

[View this example as SVG (SVG-enabled browsers
only)](images/struct/grouping01.svg)

A ['[g](struct.html#GElement)'] element can contain other
['[g](struct.html#GElement)'] elements nested within it,
to an arbitrary depth.

### 5.2.2. The ['g'] element
:::: element-summary
::: element-summary-name
['[g]']

Categories:
: [Container element](struct.html#TermContainerElement), [renderable
 element](render.html#TermRenderableElement), [structural
 element](struct.html#TermStructuralElement)

Content model:
: Any number of the following elements, in any order:
 - [animation
 elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)[
 ---
 ['[animate](https://w3c.github.io/svgwg/specs/animations/#AnimateElement)'],
 ['[animateMotion](https://w3c.github.io/svgwg/specs/animations/#AnimateMotionElement)'],
 ['[animateTransform](https://w3c.github.io/svgwg/specs/animations/#AnimateTransformElement)'],
 ['[set](https://w3c.github.io/svgwg/specs/animations/#SetElement)']]
 - [descriptive elements](struct.html#TermDescriptiveElement)[ ---
 ['[desc](struct.html#DescElement)'],
 ['[title](struct.html#TitleElement)'],
 ['[metadata](struct.html#MetadataElement)']]
 - [paint server elements](painting.html#TermPaintServerElement)[ ---
 ['[linearGradient](pservers.html#LinearGradientElement)'],
 ['[radialGradient](pservers.html#RadialGradientElement)'],
 ['[pattern](pservers.html#PatternElement)']]
 - [shape elements](shapes.html#TermShapeElement)[ ---
 ['[circle](shapes.html#CircleElement)'],
 ['[ellipse](shapes.html#EllipseElement)'],
 ['[line](shapes.html#LineElement)'],
 ['[path](paths.html#PathElement)'],
 ['[polygon](shapes.html#PolygonElement)'],
 ['[polyline](shapes.html#PolylineElement)'],
 ['[rect](shapes.html#RectElement)']]
 - [structural elements](struct.html#TermStructuralElement)[ ---
 ['[defs](struct.html#DefsElement)'],
 ['[g](struct.html#GElement)'],
 ['[svg](struct.html#SVGElement)'],
 ['[symbol](struct.html#SymbolElement)'],
 ['[use](struct.html#UseElement)']]

 [[a](linking.html#AElement)],
 [[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)],
 [[filter](https://drafts.csswg.org/filter-effects-1/#FilterElement)],
 [[foreignObject](embedded.html#ForeignObjectElement)],
 [[image](embedded.html#ImageElement)],
 [[marker](painting.html#MarkerElement)],
 [[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)],
 [[script](interact.html#ScriptElement)],
 [[style](styling.html#StyleElement)],
 [[switch](struct.html#SwitchElement)],
 [[text](text.html#TextElement)],
 [[view](linking.html#ViewElement)]

Attributes:

: - [aria attributes](struct.html#TermARIAAttribute)[ ---
 ['[aria-activedescendant](https://www.w3.org/TR/wai-aria-1.1/#aria-activedescendant)'],
 ['[aria-atomic](https://www.w3.org/TR/wai-aria-1.1/#aria-atomic)'],
 ['[aria-autocomplete](https://www.w3.org/TR/wai-aria-1.1/#aria-autocomplete)'],
 ['[aria-busy](https://www.w3.org/TR/wai-aria-1.1/#aria-busy)'],
 ['[aria-checked](https://www.w3.org/TR/wai-aria-1.1/#aria-checked)'],
 ['[aria-colcount](https://www.w3.org/TR/wai-aria-1.1/#aria-colcount)'],
 ['[aria-colindex](https://www.w3.org/TR/wai-aria-1.1/#aria-colindex)'],
 ['[aria-colspan](https://www.w3.org/TR/wai-aria-1.1/#aria-colspan)'],
 ['[aria-controls](https://www.w3.org/TR/wai-aria-1.1/#aria-controls)'],
 ['[aria-current](https://www.w3.org/TR/wai-aria-1.1/#aria-current)'],
 ['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)'],
 ['[aria-details](https://www.w3.org/TR/wai-aria-1.1/#aria-details)'],
 ['[aria-disabled](https://www.w3.org/TR/wai-aria-1.1/#aria-disabled)'],
 ['[aria-dropeffect](https://www.w3.org/TR/wai-aria-1.1/#aria-dropeffect)'],
 ['[aria-errormessage](https://www.w3.org/TR/wai-aria-1.1/#aria-errormessage)'],
 ['[aria-expanded](https://www.w3.org/TR/wai-aria-1.1/#aria-expanded)'],
 ['[aria-flowto](https://www.w3.org/TR/wai-aria-1.1/#aria-flowto)'],
 ['[aria-grabbed](https://www.w3.org/TR/wai-aria-1.1/#aria-grabbed)'],
 ['[aria-haspopup](https://www.w3.org/TR/wai-aria-1.1/#aria-haspopup)'],
 ['[aria-hidden](https://www.w3.org/TR/wai-aria-1.1/#aria-hidden)'],
 ['[aria-invalid](https://www.w3.org/TR/wai-aria-1.1/#aria-invalid)'],
 ['[aria-keyshortcuts](https://www.w3.org/TR/wai-aria-1.1/#aria-keyshortcuts)'],
 ['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)'],
 ['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)'],
 ['[aria-level](https://www.w3.org/TR/wai-aria-1.1/#aria-level)'],
 ['[aria-live](https://www.w3.org/TR/wai-aria-1.1/#aria-live)'],
 ['[aria-modal](https://www.w3.org/TR/wai-aria-1.1/#aria-modal)'],
 ['[aria-multiline](https://www.w3.org/TR/wai-aria-1.1/#aria-multiline)'],
 ['[aria-multiselectable](https://www.w3.org/TR/wai-aria-1.1/#aria-multiselectable)'],
 ['[aria-orientation](https://www.w3.org/TR/wai-aria-1.1/#aria-orientation)'],
 ['[aria-owns](https://www.w3.org/TR/wai-aria-1.1/#aria-owns)'],
 ['[aria-placeholder](https://www.w3.org/TR/wai-aria-1.1/#aria-placeholder)'],
 ['[aria-posinset](https://www.w3.org/TR/wai-aria-1.1/#aria-posinset)'],
 ['[aria-pressed](https://www.w3.org/TR/wai-aria-1.1/#aria-pressed)'],
 ['[aria-readonly](https://www.w3.org/TR/wai-aria-1.1/#aria-readonly)'],
 ['[aria-relevant](https://www.w3.org/TR/wai-aria-1.1/#aria-relevant)'],
 ['[aria-required](https://www.w3.org/TR/wai-aria-1.1/#aria-required)'],
 ['[aria-roledescription](https://www.w3.org/TR/wai-aria-1.1/#aria-roledescription)'],
 ['[aria-rowcount](https://www.w3.org/TR/wai-aria-1.1/#aria-rowcount)'],
 ['[aria-rowindex](https://www.w3.org/TR/wai-aria-1.1/#aria-rowindex)'],
 ['[aria-rowspan](https://www.w3.org/TR/wai-aria-1.1/#aria-rowspan)'],
 ['[aria-selected](https://www.w3.org/TR/wai-aria-1.1/#aria-selected)'],
 ['[aria-setsize](https://www.w3.org/TR/wai-aria-1.1/#aria-setsize)'],
 ['[aria-sort](https://www.w3.org/TR/wai-aria-1.1/#aria-sort)'],
 ['[aria-valuemax](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemax)'],
 ['[aria-valuemin](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemin)'],
 ['[aria-valuenow](https://www.w3.org/TR/wai-aria-1.1/#aria-valuenow)'],
 ['[aria-valuetext](https://www.w3.org/TR/wai-aria-1.1/#aria-valuetext)'],
 ['[role](struct.html#RoleAttribute)']]
 - [conditional processing
 attributes](struct.html#TermConditionalProcessingAttribute)[ ---
 ['[requiredExtensions](struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](struct.html#SystemLanguageAttribute)']]
 - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [presentation attributes](styling.html#TermPresentationAttribute)[
 --- ]

DOM Interfaces:

: - [SVGGElement](struct.html#InterfaceSVGGElement)

## 5.3. Defining content for reuse, and the ['defs'] element
### 5.3.1. Overview
SVG allows a graphical object to be defined for later reuse. To do this,
SVG makes extensive use of the [URL
reference](linking.html#TermURLReference) construct
\[[rfc3987](refs.html#ref-rfc3987)\]. For example, to fill a rectangle
with a linear gradient, a
['[linearGradient](pservers.html#LinearGradientElement)']
element may be defined with an
['[id](struct.html#IDAttribute)'] property that may be
referenced in the value for the rectangle\'s
[fill](painting.html#FillProperty) property, as in the
following:

``` xml

<linearGradient id="MyGradient">...</linearGradient>
<rect style="fill:url(#MyGradient)"/>
```

Some types of element, such as gradients, will not by themselves produce
a graphical result. They can therefore be placed anywhere convenient.
However, sometimes it is desired to define a graphical object and
prevent it from being directly rendered. it is only there to be
referenced elsewhere. To do this, and to allow convenient grouping
defined content, SVG provides the ['defs'] element.

It is recommended that, where possible, referenced elements be defined
prior to the elements that use them, in document order. Collecting all
referenced elements inside of a single
['[defs](struct.html#DefsElement)'] element near the top
of the file can make the markup easier to read and understand.

### 5.3.2. The ['defs'] element
:::: element-summary
::: element-summary-name
['[defs]']

Categories:
: [Container element](struct.html#TermContainerElement),
 [never-rendered element](render.html#TermNeverRenderedElement),
 [structural element](struct.html#TermStructuralElement)

Content model:
: Any number of the following elements, in any order:
 - [animation
 elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)[
 ---
 ['[animate](https://w3c.github.io/svgwg/specs/animations/#AnimateElement)'],
 ['[animateMotion](https://w3c.github.io/svgwg/specs/animations/#AnimateMotionElement)'],
 ['[animateTransform](https://w3c.github.io/svgwg/specs/animations/#AnimateTransformElement)'],
 ['[set](https://w3c.github.io/svgwg/specs/animations/#SetElement)']]
 - [descriptive elements](struct.html#TermDescriptiveElement)[ ---
 ['[desc](struct.html#DescElement)'],
 ['[title](struct.html#TitleElement)'],
 ['[metadata](struct.html#MetadataElement)']]
 - [paint server elements](painting.html#TermPaintServerElement)[ ---
 ['[linearGradient](pservers.html#LinearGradientElement)'],
 ['[radialGradient](pservers.html#RadialGradientElement)'],
 ['[pattern](pservers.html#PatternElement)']]
 - [shape elements](shapes.html#TermShapeElement)[ ---
 ['[circle](shapes.html#CircleElement)'],
 ['[ellipse](shapes.html#EllipseElement)'],
 ['[line](shapes.html#LineElement)'],
 ['[path](paths.html#PathElement)'],
 ['[polygon](shapes.html#PolygonElement)'],
 ['[polyline](shapes.html#PolylineElement)'],
 ['[rect](shapes.html#RectElement)']]
 - [structural elements](struct.html#TermStructuralElement)[ ---
 ['[defs](struct.html#DefsElement)'],
 ['[g](struct.html#GElement)'],
 ['[svg](struct.html#SVGElement)'],
 ['[symbol](struct.html#SymbolElement)'],
 ['[use](struct.html#UseElement)']]

 [[a](linking.html#AElement)],
 [[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)],
 [[filter](https://drafts.csswg.org/filter-effects-1/#FilterElement)],
 [[foreignObject](embedded.html#ForeignObjectElement)],
 [[image](embedded.html#ImageElement)],
 [[marker](painting.html#MarkerElement)],
 [[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)],
 [[script](interact.html#ScriptElement)],
 [[style](styling.html#StyleElement)],
 [[switch](struct.html#SwitchElement)],
 [[text](text.html#TextElement)],
 [[view](linking.html#ViewElement)]

Attributes:

: - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [presentation attributes](styling.html#TermPresentationAttribute)[
 --- ]

DOM Interfaces:

: - [SVGDefsElement](struct.html#InterfaceSVGDefsElement)

The ['[defs](struct.html#DefsElement)'] element is a
container element for [referenced elements](struct.html#Head). For
understandability and [accessibility](access.html) reasons, it is
recommended that, whenever possible, referenced elements be defined
inside of a ['[defs](struct.html#DefsElement)'].

The content model for ['[defs](struct.html#DefsElement)']
is the same as for the ['[g](struct.html#GElement)']
element; thus, any element that can be a child of a
['[g](struct.html#GElement)'] can also be a child of a
['[defs](struct.html#DefsElement)'], and vice versa.

Elements that are descendants of a
['[defs](struct.html#DefsElement)'] are not rendered
directly; the [display](render.html#VisibilityControl) value
for the ['[defs](struct.html#DefsElement)'] element must
always be set to [none] by the [user agent style
sheet](styling.html#UAStyleSheet), and this declaration must have
importance over any other CSS rule or presentation attribute. Note,
however, that the descendants of a
['[defs](struct.html#DefsElement)'] are always present in
the source tree and thus can always be referenced by other elements;
thus, the value of the
[display](render.html#VisibilityControl) property on the
['[defs](struct.html#DefsElement)'] element does not
prevent those elements from being referenced by other elements.

::::::::::::::::::: ready-for-wider-review
## 5.4. The ['symbol'] element
The ['[symbol](struct.html#SymbolElement)'] element is
used to define graphical templates which can be instantiated by a
['[use](struct.html#UseElement)'] element but which are
not rendered directly.

A ['[symbol](struct.html#SymbolElement)'] establishes a
nested coordinate system for the graphics it contains. When a symbol is
instantiated as the [referenced
element](struct.html#TermReferencedElement) of a
['[use](struct.html#UseElement)'] element, it is
therefore rendered very similarly to a nested
['[svg](struct.html#SVGElement)'] element.

:::: element-summary
::: element-summary-name
['[symbol]']

Categories:
: [Container element](struct.html#TermContainerElement), [structural
 element](struct.html#TermStructuralElement)

Content model:
: Any number of the following elements, in any order:
 - [animation
 elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)[
 ---
 ['[animate](https://w3c.github.io/svgwg/specs/animations/#AnimateElement)'],
 ['[animateMotion](https://w3c.github.io/svgwg/specs/animations/#AnimateMotionElement)'],
 ['[animateTransform](https://w3c.github.io/svgwg/specs/animations/#AnimateTransformElement)'],
 ['[set](https://w3c.github.io/svgwg/specs/animations/#SetElement)']]
 - [descriptive elements](struct.html#TermDescriptiveElement)[ ---
 ['[desc](struct.html#DescElement)'],
 ['[title](struct.html#TitleElement)'],
 ['[metadata](struct.html#MetadataElement)']]
 - [paint server elements](painting.html#TermPaintServerElement)[ ---
 ['[linearGradient](pservers.html#LinearGradientElement)'],
 ['[radialGradient](pservers.html#RadialGradientElement)'],
 ['[pattern](pservers.html#PatternElement)']]
 - [shape elements](shapes.html#TermShapeElement)[ ---
 ['[circle](shapes.html#CircleElement)'],
 ['[ellipse](shapes.html#EllipseElement)'],
 ['[line](shapes.html#LineElement)'],
 ['[path](paths.html#PathElement)'],
 ['[polygon](shapes.html#PolygonElement)'],
 ['[polyline](shapes.html#PolylineElement)'],
 ['[rect](shapes.html#RectElement)']]
 - [structural elements](struct.html#TermStructuralElement)[ ---
 ['[defs](struct.html#DefsElement)'],
 ['[g](struct.html#GElement)'],
 ['[svg](struct.html#SVGElement)'],
 ['[symbol](struct.html#SymbolElement)'],
 ['[use](struct.html#UseElement)']]

 [[a](linking.html#AElement)],
 [[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)],
 [[filter](https://drafts.csswg.org/filter-effects-1/#FilterElement)],
 [[foreignObject](embedded.html#ForeignObjectElement)],
 [[image](embedded.html#ImageElement)],
 [[marker](painting.html#MarkerElement)],
 [[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)],
 [[script](interact.html#ScriptElement)],
 [[style](styling.html#StyleElement)],
 [[switch](struct.html#SwitchElement)],
 [[text](text.html#TextElement)],
 [[view](linking.html#ViewElement)]

Attributes:

: - [aria attributes](struct.html#TermARIAAttribute)[ ---
 ['[aria-activedescendant](https://www.w3.org/TR/wai-aria-1.1/#aria-activedescendant)'],
 ['[aria-atomic](https://www.w3.org/TR/wai-aria-1.1/#aria-atomic)'],
 ['[aria-autocomplete](https://www.w3.org/TR/wai-aria-1.1/#aria-autocomplete)'],
 ['[aria-busy](https://www.w3.org/TR/wai-aria-1.1/#aria-busy)'],
 ['[aria-checked](https://www.w3.org/TR/wai-aria-1.1/#aria-checked)'],
 ['[aria-colcount](https://www.w3.org/TR/wai-aria-1.1/#aria-colcount)'],
 ['[aria-colindex](https://www.w3.org/TR/wai-aria-1.1/#aria-colindex)'],
 ['[aria-colspan](https://www.w3.org/TR/wai-aria-1.1/#aria-colspan)'],
 ['[aria-controls](https://www.w3.org/TR/wai-aria-1.1/#aria-controls)'],
 ['[aria-current](https://www.w3.org/TR/wai-aria-1.1/#aria-current)'],
 ['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)'],
 ['[aria-details](https://www.w3.org/TR/wai-aria-1.1/#aria-details)'],
 ['[aria-disabled](https://www.w3.org/TR/wai-aria-1.1/#aria-disabled)'],
 ['[aria-dropeffect](https://www.w3.org/TR/wai-aria-1.1/#aria-dropeffect)'],
 ['[aria-errormessage](https://www.w3.org/TR/wai-aria-1.1/#aria-errormessage)'],
 ['[aria-expanded](https://www.w3.org/TR/wai-aria-1.1/#aria-expanded)'],
 ['[aria-flowto](https://www.w3.org/TR/wai-aria-1.1/#aria-flowto)'],
 ['[aria-grabbed](https://www.w3.org/TR/wai-aria-1.1/#aria-grabbed)'],
 ['[aria-haspopup](https://www.w3.org/TR/wai-aria-1.1/#aria-haspopup)'],
 ['[aria-hidden](https://www.w3.org/TR/wai-aria-1.1/#aria-hidden)'],
 ['[aria-invalid](https://www.w3.org/TR/wai-aria-1.1/#aria-invalid)'],
 ['[aria-keyshortcuts](https://www.w3.org/TR/wai-aria-1.1/#aria-keyshortcuts)'],
 ['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)'],
 ['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)'],
 ['[aria-level](https://www.w3.org/TR/wai-aria-1.1/#aria-level)'],
 ['[aria-live](https://www.w3.org/TR/wai-aria-1.1/#aria-live)'],
 ['[aria-modal](https://www.w3.org/TR/wai-aria-1.1/#aria-modal)'],
 ['[aria-multiline](https://www.w3.org/TR/wai-aria-1.1/#aria-multiline)'],
 ['[aria-multiselectable](https://www.w3.org/TR/wai-aria-1.1/#aria-multiselectable)'],
 ['[aria-orientation](https://www.w3.org/TR/wai-aria-1.1/#aria-orientation)'],
 ['[aria-owns](https://www.w3.org/TR/wai-aria-1.1/#aria-owns)'],
 ['[aria-placeholder](https://www.w3.org/TR/wai-aria-1.1/#aria-placeholder)'],
 ['[aria-posinset](https://www.w3.org/TR/wai-aria-1.1/#aria-posinset)'],
 ['[aria-pressed](https://www.w3.org/TR/wai-aria-1.1/#aria-pressed)'],
 ['[aria-readonly](https://www.w3.org/TR/wai-aria-1.1/#aria-readonly)'],
 ['[aria-relevant](https://www.w3.org/TR/wai-aria-1.1/#aria-relevant)'],
 ['[aria-required](https://www.w3.org/TR/wai-aria-1.1/#aria-required)'],
 ['[aria-roledescription](https://www.w3.org/TR/wai-aria-1.1/#aria-roledescription)'],
 ['[aria-rowcount](https://www.w3.org/TR/wai-aria-1.1/#aria-rowcount)'],
 ['[aria-rowindex](https://www.w3.org/TR/wai-aria-1.1/#aria-rowindex)'],
 ['[aria-rowspan](https://www.w3.org/TR/wai-aria-1.1/#aria-rowspan)'],
 ['[aria-selected](https://www.w3.org/TR/wai-aria-1.1/#aria-selected)'],
 ['[aria-setsize](https://www.w3.org/TR/wai-aria-1.1/#aria-setsize)'],
 ['[aria-sort](https://www.w3.org/TR/wai-aria-1.1/#aria-sort)'],
 ['[aria-valuemax](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemax)'],
 ['[aria-valuemin](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemin)'],
 ['[aria-valuenow](https://www.w3.org/TR/wai-aria-1.1/#aria-valuenow)'],
 ['[aria-valuetext](https://www.w3.org/TR/wai-aria-1.1/#aria-valuetext)'],
 ['[role](struct.html#RoleAttribute)']]
 - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [presentation attributes](styling.html#TermPresentationAttribute)[
 --- ]
 - ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 - ['[viewBox](coords.html#ViewBoxAttribute)']
 - ['[refX](struct.html#SymbolElementRefXAttribute)']
 - ['[refY](struct.html#SymbolElementRefYAttribute)']

Geometry properties:

: - [x](geometry.html#XProperty)
 - [y](geometry.html#YProperty)
 - [width](geometry.html#Sizing)
 - [height](geometry.html#Sizing)

DOM Interfaces:

: - [SVGSymbolElement](struct.html#InterfaceSVGSymbolElement)

The [x](geometry.html#XProperty),
[y](geometry.html#YProperty),
[width](geometry.html#Sizing), and
[height](geometry.html#Sizing) geometry properties have the
same effect as on an ['[svg](struct.html#SVGElement)']
element, when the ['[symbol](struct.html#SymbolElement)']
is instantiated by a ['[use](struct.html#UseElement)']
element. In particular, if [width](geometry.html#Sizing) and
[height](geometry.html#Sizing) compute to [auto]
(and are not over-ridden by values on the instantiating
['[use](struct.html#UseElement)'] element), then they
will be treated as a value of [100%].

New in SVG 2. Allowing geometry properties to be specified on a symbol
provides a more consistent rendering model, and allows authors to set a
default size for each symbol (which may still be over-ridden by
attributes on the ['[use](struct.html#UseElement)']
element).

### 5.4.1. Attributes
 Name Value Initial value Animatable
 ----------------------------------------------------------------------------------- ------------------------------------------------------------------------------------- --------------- ------------
 [refX] [\<length\>](https://www.w3.org/TR/css3-values/#lengths) \| left \| center \| right (none) yes
 [refY] [\<length\>](https://www.w3.org/TR/css3-values/#lengths) \| top \| center \| bottom (none) yes

New in SVG 2. Added to make it easier to align symbols to a particular
point, as is often done in maps. Similar to the matching attributes on
['[marker](painting.html#MarkerElement)'].

Add refX/refY to symbol element. Resolved at [Leipzig
F2F](https://www.w3.org/2014/04/08-svg-minutes.html#item12). Status:
Done.

We will add top/center/bottom, left/center/right keywords to refX/refY
on marker/symbol. Resolved at [London
F2F](https://www.w3.org/2014/08/26-svg-minutes.html#item07). Values
inspired by
[\'background-position\'](https://www.w3.org/TR/css3-background/#the-background-position).
Status: Done.

The ['[refX](struct.html#SymbolElementRefXAttribute)'] and
['[refY](struct.html#SymbolElementRefYAttribute)']
attributes define the reference point of the symbol which is to be
placed exactly at the symbol\'s [x,y] positioning
coordinate, as defined by the cumulative effect of the
[x](geometry.html#XProperty) and
[y](geometry.html#YProperty) properties and any
transformations on the
['[symbol](struct.html#SymbolElement)'] and its
[host](struct.html#TermShadowHost)
['[use](struct.html#UseElement)'] element.

Keyword values have the same meaning as for the
['[refX](painting.html#MarkerElementRefXAttribute)'] and
['[refY](painting.html#MarkerElementRefYAttribute)']
attributes on the
['[marker](painting.html#MarkerElement)'] element,
resolving to 0%, 50%, or 100% in the applicable direction.

Unlike other positioning attributes,
['[refX](struct.html#SymbolElementRefXAttribute)'] and
['[refY](struct.html#SymbolElementRefYAttribute)'] are
interpreted as being in the coordinate system of the symbol contents,
after application of the
['[viewBox](coords.html#ViewBoxAttribute)'] and
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attributes. If one or both of the attributes is not specified, no
adjustment is made in the corresponding dimension, and the top or left
side of the symbol\'s rectangular viewport region (regardless of the
['[viewBox](coords.html#ViewBoxAttribute)'] coordinates) is
positioned at the [x,y] point.

For backwards compatibility, the behavior when
['[refX](struct.html#SymbolElementRefXAttribute)'] and
['[refY](struct.html#SymbolElementRefYAttribute)'] are not
specified on a ['[symbol](struct.html#SymbolElement)'] is
different from when they are specified with a value of [0],
and therefore different from the behavior when equivalent attributes are
not specified on a
['[marker](painting.html#MarkerElement)'].

### 5.4.2. Notes on symbols
The use of ['[symbol](struct.html#SymbolElement)']
elements for graphics that are used multiple times in the same document
adds structure and semantics. Closely related to the
['[symbol](struct.html#SymbolElement)'] element are the
['[marker](painting.html#MarkerElement)'] and
['[pattern](pservers.html#PatternElement)'] elements; all
three define a container of graphical content that can be rendered
repeatedly at various positions and scales in the SVG. However, while
[re-used graphics](render.html#TermReusedGraphics) in a pattern and
marker provide a graphical effect on another element, the content in a
['[symbol](struct.html#SymbolElement)'] will be embedded
as fully interactive content, within a [use-element shadow
tree](struct.html#TermUseElementShadowTree).

The [user agent style sheet](styling.html#UAStyleSheet) sets the
[overflow](render.html#OverflowAndClipProperties) property
for ['[symbol](struct.html#SymbolElement)'] elements to
[hidden], which causes a rectangular clipping path to be
created at the bounds of symbol\'s SVG viewport. Unless the
[overflow](render.html#OverflowAndClipProperties) property is
overridden, any graphics within the symbol which goes outside of the
symbol\'s SVG viewport will be clipped.

['[symbol](struct.html#SymbolElement)'] elements must
never be rendered directly; their only usage is as something that can be
referenced using the ['[use](struct.html#UseElement)']
element. The user agent must set the
[display](render.html#VisibilityControl) property on the
['[symbol](struct.html#SymbolElement)'] element to
[none], as part of the [user agent style
sheet](styling.html#UAStyleSheet), and this declaration must have
importance over any other CSS rule or presentation attribute.

The generated [instance](struct.html#TermElementInstance) of a
['[symbol](struct.html#SymbolElement)'] that is the
direct [referenced element](struct.html#TermReferencedElement) of a
['[use](struct.html#UseElement)'] element must always
have a computed value of [inline] for the
[display](render.html#VisibilityControl) property. In other
words, it must be rendered whenever the host
['[use](struct.html#UseElement)'] element is rendered.
The [user agent style sheet](styling.html#UAStyleSheet) again defines
this declaration to have importance over any other CSS rule or
presentation attribute. Any other
['[symbol](struct.html#SymbolElement)'] that is cloned to
create an [element instance](struct.html#TermElementInstance) within the
[use-element shadow tree](struct.html#TermUseElementShadowTree) behaves
as a symbol definition, and must not be rendered.

## 5.5. The ['use'] element
 -------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Allow ['[use](struct.html#UseElement)'] to reference an external document\'s root element by omitting the fragment.
 Resolution: [We will relax referencing requirements to particular elements to allow dropping fragments to mean referencing root element, where it makes sense, such as with use, in SVG 2.](https://www.w3.org/2011/10/28-svg-irc#T00-33-43)
 Purpose: To avoid requiring authors to modify the referenced document to add an ID to the root element.
 Owner: Cameron ([ACTION-3417](https://www.w3.org/Graphics/SVG/WG/track/actions/3417))
 Status: Done
 -------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

:::: element-summary
::: element-summary-name
['[use]']

Categories:
: [Graphics referencing
 element](struct.html#TermGraphicsReferencingElement), [renderable
 element](render.html#TermRenderableElement), [structural
 element](struct.html#TermStructuralElement), [structurally external
 element](struct.html#TermStructurallyExternalElement)

Content model:
: Any number of the following elements, in any order:
 - [animation
 elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)[
 ---
 ['[animate](https://w3c.github.io/svgwg/specs/animations/#AnimateElement)'],
 ['[animateMotion](https://w3c.github.io/svgwg/specs/animations/#AnimateMotionElement)'],
 ['[animateTransform](https://w3c.github.io/svgwg/specs/animations/#AnimateTransformElement)'],
 ['[set](https://w3c.github.io/svgwg/specs/animations/#SetElement)']]
 - [descriptive elements](struct.html#TermDescriptiveElement)[ ---
 ['[desc](struct.html#DescElement)'],
 ['[title](struct.html#TitleElement)'],
 ['[metadata](struct.html#MetadataElement)']]

 [[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)],
 [[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)],
 [[script](interact.html#ScriptElement)],
 [[style](styling.html#StyleElement)]

Attributes:

: - [aria attributes](struct.html#TermARIAAttribute)[ ---
 ['[aria-activedescendant](https://www.w3.org/TR/wai-aria-1.1/#aria-activedescendant)'],
 ['[aria-atomic](https://www.w3.org/TR/wai-aria-1.1/#aria-atomic)'],
 ['[aria-autocomplete](https://www.w3.org/TR/wai-aria-1.1/#aria-autocomplete)'],
 ['[aria-busy](https://www.w3.org/TR/wai-aria-1.1/#aria-busy)'],
 ['[aria-checked](https://www.w3.org/TR/wai-aria-1.1/#aria-checked)'],
 ['[aria-colcount](https://www.w3.org/TR/wai-aria-1.1/#aria-colcount)'],
 ['[aria-colindex](https://www.w3.org/TR/wai-aria-1.1/#aria-colindex)'],
 ['[aria-colspan](https://www.w3.org/TR/wai-aria-1.1/#aria-colspan)'],
 ['[aria-controls](https://www.w3.org/TR/wai-aria-1.1/#aria-controls)'],
 ['[aria-current](https://www.w3.org/TR/wai-aria-1.1/#aria-current)'],
 ['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)'],
 ['[aria-details](https://www.w3.org/TR/wai-aria-1.1/#aria-details)'],
 ['[aria-disabled](https://www.w3.org/TR/wai-aria-1.1/#aria-disabled)'],
 ['[aria-dropeffect](https://www.w3.org/TR/wai-aria-1.1/#aria-dropeffect)'],
 ['[aria-errormessage](https://www.w3.org/TR/wai-aria-1.1/#aria-errormessage)'],
 ['[aria-expanded](https://www.w3.org/TR/wai-aria-1.1/#aria-expanded)'],
 ['[aria-flowto](https://www.w3.org/TR/wai-aria-1.1/#aria-flowto)'],
 ['[aria-grabbed](https://www.w3.org/TR/wai-aria-1.1/#aria-grabbed)'],
 ['[aria-haspopup](https://www.w3.org/TR/wai-aria-1.1/#aria-haspopup)'],
 ['[aria-hidden](https://www.w3.org/TR/wai-aria-1.1/#aria-hidden)'],
 ['[aria-invalid](https://www.w3.org/TR/wai-aria-1.1/#aria-invalid)'],
 ['[aria-keyshortcuts](https://www.w3.org/TR/wai-aria-1.1/#aria-keyshortcuts)'],
 ['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)'],
 ['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)'],
 ['[aria-level](https://www.w3.org/TR/wai-aria-1.1/#aria-level)'],
 ['[aria-live](https://www.w3.org/TR/wai-aria-1.1/#aria-live)'],
 ['[aria-modal](https://www.w3.org/TR/wai-aria-1.1/#aria-modal)'],
 ['[aria-multiline](https://www.w3.org/TR/wai-aria-1.1/#aria-multiline)'],
 ['[aria-multiselectable](https://www.w3.org/TR/wai-aria-1.1/#aria-multiselectable)'],
 ['[aria-orientation](https://www.w3.org/TR/wai-aria-1.1/#aria-orientation)'],
 ['[aria-owns](https://www.w3.org/TR/wai-aria-1.1/#aria-owns)'],
 ['[aria-placeholder](https://www.w3.org/TR/wai-aria-1.1/#aria-placeholder)'],
 ['[aria-posinset](https://www.w3.org/TR/wai-aria-1.1/#aria-posinset)'],
 ['[aria-pressed](https://www.w3.org/TR/wai-aria-1.1/#aria-pressed)'],
 ['[aria-readonly](https://www.w3.org/TR/wai-aria-1.1/#aria-readonly)'],
 ['[aria-relevant](https://www.w3.org/TR/wai-aria-1.1/#aria-relevant)'],
 ['[aria-required](https://www.w3.org/TR/wai-aria-1.1/#aria-required)'],
 ['[aria-roledescription](https://www.w3.org/TR/wai-aria-1.1/#aria-roledescription)'],
 ['[aria-rowcount](https://www.w3.org/TR/wai-aria-1.1/#aria-rowcount)'],
 ['[aria-rowindex](https://www.w3.org/TR/wai-aria-1.1/#aria-rowindex)'],
 ['[aria-rowspan](https://www.w3.org/TR/wai-aria-1.1/#aria-rowspan)'],
 ['[aria-selected](https://www.w3.org/TR/wai-aria-1.1/#aria-selected)'],
 ['[aria-setsize](https://www.w3.org/TR/wai-aria-1.1/#aria-setsize)'],
 ['[aria-sort](https://www.w3.org/TR/wai-aria-1.1/#aria-sort)'],
 ['[aria-valuemax](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemax)'],
 ['[aria-valuemin](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemin)'],
 ['[aria-valuenow](https://www.w3.org/TR/wai-aria-1.1/#aria-valuenow)'],
 ['[aria-valuetext](https://www.w3.org/TR/wai-aria-1.1/#aria-valuetext)'],
 ['[role](struct.html#RoleAttribute)']]
 - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [conditional processing
 attributes](struct.html#TermConditionalProcessingAttribute)[ ---
 ['[requiredExtensions](struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](struct.html#SystemLanguageAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [presentation attributes](styling.html#TermPresentationAttribute)[
 --- ]
 - [deprecated xlink attributes](linking.html#XLinkRefAttrs)[ ---
 ['[xlink:href](linking.html#XLinkHrefAttribute)'],
 ['[xlink:title](linking.html#XLinkTitleAttribute)']]
 - ['[href](struct.html#UseElementHrefAttribute)']

Geometry properties:

: - [x](geometry.html#XProperty)
 - [y](geometry.html#YProperty)
 - [width](geometry.html#Sizing)
 - [height](geometry.html#Sizing)

DOM Interfaces:

: - [SVGUseElement](struct.html#InterfaceSVGUseElement)

The ['[use](struct.html#UseElement)'] element references
another element, a copy of which is rendered in place of the
['[use](struct.html#UseElement)'] in the document. The
[referenced element](struct.html#TermReferencedElement) may be a
[container element](struct.html#TermContainerElement), in which case a
copy of the complete SVG document subtree rooted at that element is
used.

The cloned content inherits styles from the
['[use](struct.html#UseElement)'] element and can be the
target of user events. However, these cloned [element
instances](struct.html#TermElementInstance) remain linked to the
referenced source and reflect DOM mutations in the original. In
addition, all style rules that apply in the scope of the referenced
element also apply in the scope of the cloned [shadow
tree](struct.html#TermShadowTree).

The [x](geometry.html#XProperty),
[y](geometry.html#YProperty),
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) geometric properties specify
the positioning of the referenced element. The
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) attributes only have an effect
if the [referenced element](struct.html#TermReferencedElement) defines a
viewport (i.e., if it is a
['[svg](struct.html#SVGElement)'] or
['[symbol](struct.html#SymbolElement)']); if so, a value
other than [auto] for the
['[use](struct.html#UseElement)'] element overrides the
value of the corresponding geometric property on that element.

A negative value for [width](geometry.html#Sizing) or
[height](geometry.html#Sizing) is
[invalid](types.html#TermInvalidValue) and must be
[ignored](https://drafts.csswg.org/css-syntax/#css-ignored). If
[width](geometry.html#Sizing) or
[height](geometry.html#Sizing) is zero, and the properties
have an effect on the [referenced
element](struct.html#TermReferencedElement), then rendering of that
element will be disabled.

The [x](geometry.html#XProperty) and
[y](geometry.html#YProperty) properties affect the user
coordinate system for the element. See the [Layout](#UseLayout) section
for implementation details.

 Name Value Initial value Animatable
 --------------------------------------- -------------------------------------------------- --------------- ------------
 [href] URL [\[URL\]](types.html#attribute-url) (none) yes

An [URL reference](linking.html#URLReference) to the element/fragment
within an SVG document to be cloned for rendering.

The ['[use](struct.html#UseElement)'] element can
reference an entire SVG document by specifying an
['[href](struct.html#UseElementHrefAttribute)'] value
without a fragment. Such references are taken to be referring to the
root element of the referenced document.

Refer to the common handling defined for [URL reference
attributes](linking.html#linkRefAttrs) and [deprecated XLink
attributes](linking.html#XLinkRefAttrs).

New in SVG 2. An
['[href](struct.html#UseElementHrefAttribute)'] without a
fragment allows an entire SVG document to be referenced without having
to ensure that it has an ID on its root element.

User agents may restrict external resource documents for security
reasons. In particular, this specification does not allow cross-origin
and [data URL](linking.html#TermDataURL) resource requests in
['[use](struct.html#UseElement)'].

When the ['[href](struct.html#UseElementHrefAttribute)']
attribute is set (or, in the absence of an
['[href](struct.html#UseElementHrefAttribute)'] attribute,
an ['[xlink:href](linking.html#XLinkHrefAttribute)']
attribute), the user agent must [process the
URL](linking.html#processingURL). The target element that results from
URL processing is the [referenced
element](struct.html#TermReferencedElement) of the
['[use](struct.html#UseElement)'].

If the [referenced element](struct.html#TermReferencedElement) that
results from resolving the URL is not an SVG element, then the reference
is [invalid](types.html#TermInvalidValue) and the
['[use](struct.html#UseElement)'] element is in error.

If the referenced element is a (shadow-including) ancestor of the
['[use](struct.html#UseElement)'] element, then this is
an [invalid circular reference](linking.html#TermCircularReference) and
the ['[use](struct.html#UseElement)'] element is in
error.

Otherwise, the user agent must generate a [shadow
tree](struct.html#TermShadowTree) of [re-used
graphics](render.html#TermReusedGraphics) to render as the contents of
the ['[use](struct.html#UseElement)'] element, as
described in the next section, [The use-element shadow
tree](#UseShadowTree).

A ['[use](struct.html#UseElement)'] that has an
[unresolved](linking.html#TermUnresolvedReference) or
[invalid](types.html#TermInvalidValue) URL reference is not rendered.
For the purpose of bounding box calculations, it is equivalent to an
empty container element.

### 5.5.1. The use-element shadow tree
The [re-used graphics](render.html#TermReusedGraphics) generated by a
['[use](struct.html#UseElement)'] element are defined in
terms of a [shadow tree](struct.html#TermShadowTree). In terms of
interactivity and style inheritance, they are therefore quite different
from other types of [re-used graphics](render.html#TermReusedGraphics)
in SVG, such as
['[pattern](pservers.html#PatternElement)'] and
['[marker](painting.html#MarkerElement)'] content.

Elements in the shadow tree are rendered as if the
['[use](struct.html#UseElement)'] element was a container
and they were its children. However, the SVG Document Object Model (DOM)
only contains the ['[use](struct.html#UseElement)']
element and its attributes. The SVG DOM does not include the element
instances as children of the
['[use](struct.html#UseElement)'] element.

User agents that support scripting and the document object model must
implement the [use-element shadow
tree](struct.html#TermUseElementShadowTree) as described in this section
and in conformance with the [dom](refs.html#ref-dom) specification
[\[dom\]](refs.html#ref-dom), or its future replacement. In contrast,
user agents that do *not* support the dynamic interactive processing
mode may not need to implement all the details of the shadow DOM.
However, all user agents must ensure that the [layout](#UseLayout) and
[style inheritance](#UseStyleInheritance) for the re-used graphics and
[declarative animations](#UseAnimations) if applicable, are rendered in
the same way as if the shadow DOM was implemented.

The following definitions apply when discussing
['[use](struct.html#UseElement)'] elements and their
shadow trees:

[referenced element]
: The element specified by the
 ['[href](struct.html#UseElementHrefAttribute)'] (or
 ['[xlink:href](linking.html#XLinkHrefAttribute)'])
 attribute on the ['[use](struct.html#UseElement)']
 element, or the root element of a document referenced by that
 attribute if the URL provided does not include a target fragment
 that links to a specific element
 ['[id](struct.html#IDAttribute)'].

[referenced document subtree]\
referenced graphics
: The referenced element, and all of its descendent nodes.

[shadow root]
: A
 [ShadowRoot](https://dom.spec.whatwg.org/#interface-shadowroot)
 object, a type of
 [DocumentFragment](https://dom.spec.whatwg.org/#interface-documentfragment)
 node which is associated with a host
 [Element](https://dom.spec.whatwg.org/#interface-element),
 and which contains the content that will be used to render that
 host. A shadow root should be implemented in conformance with the
 [dom](refs.html#ref-dom) specification [\[dom\]](refs.html#ref-dom),
 or its future replacement.

[shadow host]\
host
: An element that has an associated shadow root; usage is consistent
 the definition of
 [host](https://dom.spec.whatwg.org/#concept-documentfragment-host)
 in the DOM standard.

[shadow tree]
: A node tree whose root is a shadow root; usage is consistent the
 definition of [shadow
 tree](https://dom.spec.whatwg.org/#shadow-trees) in the DOM
 standard.

[use-element shadow tree]
: A shadow tree whose host is a
 ['[use](struct.html#UseElement)'] element, which
 contains element instances generated by cloning the referenced
 graphics.

[element instance]\
instance
: An element in the [use-element shadow
 tree](struct.html#TermUseElementShadowTree), which is generated by
 cloning a corresponding element in the referenced document subtree.

[instance root]
: The [element instance](struct.html#TermElementInstance) for the
 referenced element; it is always a direct child of the
 ['[use](struct.html#UseElement)'] element\'s shadow
 root.

The following example and diagram illustrate how these definitions
relate to each other when a
['[use](struct.html#UseElement)'] element references a
group:

 <svg>
 <defs>
 <g id="icon">
 <circle/>
 <rect/>
 </g>
 </defs>
 <use href="#icon"/>
 </svg>

!(data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA4MjAgNDMwIiB3aWR0aD0iODIwIiBoZWlnaHQ9IjQzMCIgZm9udC1mYW1pbHk9InNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTMiPgogIDx0aXRsZT5EaWFncmFtIHNob3dpbmcgdGhlIHJlbGF0aW9uc2hpcCBiZXR3ZWVuIGEgdXNlIGVsZW1lbnQmIzM5O3MgZG9jdW1lbnQgdHJlZSBhbmQgaXRzIHNoYWRvdyB0cmVlLCB3aXRoIGRlZmluZWQgdGVybXMgbGFiZWxlZC48L3RpdGxlPgoKICA8ZGVmcz4KICAgIDxtYXJrZXIgaWQ9ImFycm93LWJsdWUiIHZpZXdib3g9IjAgMCAxMCA2IiByZWZ4PSIxMCIgcmVmeT0iMyIgbWFya2Vyd2lkdGg9IjgiIG1hcmtlcmhlaWdodD0iNiIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPgogICAgICA8cGF0aCBkPSJNMCwwIEwxMCwzIEwwLDYiIGZpbGw9IiM0YTkwZDkiIC8+CiAgICA8L21hcmtlcj4KICAgIDxtYXJrZXIgaWQ9ImFycm93LWdvbGQiIHZpZXdib3g9IjAgMCAxMCA2IiByZWZ4PSIxMCIgcmVmeT0iMyIgbWFya2Vyd2lkdGg9IjgiIG1hcmtlcmhlaWdodD0iNiIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPgogICAgICA8cGF0aCBkPSJNMCwwIEwxMCwzIEwwLDYiIGZpbGw9IiNkNGEwMTciIC8+CiAgICA8L21hcmtlcj4KICA8L2RlZnM+CgogIDwhLS0gPT09PT09PT09PT09PT09PT09PT0gRG9jdW1lbnQgdHJlZSBzaWRlID09PT09PT09PT09PT09PT09PT09IC0tPgogIDx0ZXh0IHg9IjE3MCIgeT0iMjQiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTUiIGZvbnQtd2VpZ2h0PSJib2xkIiBmaWxsPSIjMzQ1Ij5Eb2N1bWVudCB0cmVlPC90ZXh0PgoKICA8IS0tIDxzdmc+IG5vZGUgLS0+CiAgPHJlY3QgeD0iMTIwIiB5PSI0MCIgd2lkdGg9IjEwMCIgaGVpZ2h0PSIzMiIgcng9IjYiIGZpbGw9IiNlOGYwZmUiIHN0cm9rZT0iI2EwYmZlMCIgc3Ryb2tlLXdpZHRoPSIxLjIiIC8+CiAgPHRleHQgeD0iMTcwIiB5PSI2MSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZmlsbD0iIzIzNCI+Jmx0O3N2ZyZndDs8L3RleHQ+CgogIDwhLS0gdHJlZSBsaW5lczogc3ZnIOKGkiBkZWZzLCBzdmcg4oaSIHVzZSAtLT4KICA8bGluZSB4MT0iMTUwIiB5MT0iNzIiIHgyPSI5MCIgeTI9IjExMCIgc3Ryb2tlPSIjYTBiZmUwIiBzdHJva2Utd2lkdGg9IjEuMiI+PC9saW5lPgogIDxsaW5lIHgxPSIxOTAiIHkxPSI3MiIgeDI9IjI4MCIgeTI9IjExMCIgc3Ryb2tlPSIjYTBiZmUwIiBzdHJva2Utd2lkdGg9IjEuMiI+PC9saW5lPgoKICA8IS0tIDxkZWZzPiBub2RlIC0tPgogIDxyZWN0IHg9IjQwIiB5PSIxMTAiIHdpZHRoPSIxMDAiIGhlaWdodD0iMzIiIHJ4PSI2IiBmaWxsPSIjZThmMGZlIiBzdHJva2U9IiNhMGJmZTAiIHN0cm9rZS13aWR0aD0iMS4yIiAvPgogIDx0ZXh0IHg9IjkwIiB5PSIxMzEiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZpbGw9IiMyMzQiPiZsdDtkZWZzJmd0OzwvdGV4dD4KCiAgPCEtLSA8dXNlPiBub2RlIChzaGFkb3cgaG9zdCkgLS0+CiAgPHJlY3QgeD0iMjAwIiB5PSIxMTAiIHdpZHRoPSIxNjAiIGhlaWdodD0iMzIiIHJ4PSI2IiBmaWxsPSIjZmZmM2NkIiBzdHJva2U9IiNkNGEwMTciIHN0cm9rZS13aWR0aD0iMS41IiAvPgogIDx0ZXh0IHg9IjI4MCIgeT0iMTMxIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjMjM0Ij4mbHQ7dXNlIGhyZWY9JnF1b3Q7I2ljb24mcXVvdDsvJmd0OzwvdGV4dD4KICA8dGV4dCB4PSIyODAiIHk9IjE1OCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzg1NjQwNCIgZm9udC13ZWlnaHQ9ImJvbGQiPnNoYWRvdyBob3N0PC90ZXh0PgoKICA8IS0tIHRyZWUgbGluZTogZGVmcyDihpIgZyAoZW50ZXJzIHBpbmsgYm94KSAtLT4KICA8bGluZSB4MT0iOTAiIHkxPSIxNDIiIHgyPSIxMTUiIHkyPSIyMTAiIHN0cm9rZT0iI2EwYmZlMCIgc3Ryb2tlLXdpZHRoPSIxLjIiPjwvbGluZT4KCiAgPCEtLSBSZWZlcmVuY2VkIGRvY3VtZW50IHN1YnRyZWUgYm94IChwaW5rL3Jvc2UgZGFzaGVkKSAtLT4KICA8cmVjdCB4PSIyMiIgeT0iMTc4IiB3aWR0aD0iMjUwIiBoZWlnaHQ9IjIxMCIgcng9IjEwIiBmaWxsPSIjZmVmNWY1IiBzdHJva2U9IiNkNGEwYTgiIHN0cm9rZS13aWR0aD0iMSIgc3Ryb2tlLWRhc2hhcnJheT0iNiwzIiBmaWxsLW9wYWNpdHk9IjAuNSIgLz4KICA8dGV4dCB4PSIxNDciIHk9IjE5OCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMSIgZmlsbD0iI2EwNDA1OCIgZm9udC13ZWlnaHQ9ImJvbGQiPnJlZmVyZW5jZWQgZG9jdW1lbnQgc3VidHJlZTwvdGV4dD4KCiAgPCEtLSA8ZyBpZD0iaWNvbiI+IG5vZGUgKHJlZmVyZW5jZWQgZWxlbWVudCkgLS0+CiAgPHJlY3QgeD0iNTUiIHk9IjIxMCIgd2lkdGg9IjE1NSIgaGVpZ2h0PSIzMiIgcng9IjYiIGZpbGw9IiNkY2VlZmIiIHN0cm9rZT0iIzRhOTBkOSIgc3Ryb2tlLXdpZHRoPSIxLjUiIC8+CiAgPHRleHQgeD0iMTMyIiB5PSIyMzEiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZpbGw9IiMyMzQiPiZsdDtnIGlkPSZxdW90O2ljb24mcXVvdDsmZ3Q7PC90ZXh0PgoKICA8IS0tIHRyZWUgbGluZXM6IGcg4oaSIGNpcmNsZSwgZyDihpIgcmVjdCAtLT4KICA8bGluZSB4MT0iMTEwIiB5MT0iMjQyIiB4Mj0iOTAiIHkyPSIyODAiIHN0cm9rZT0iI2EwYmZlMCIgc3Ryb2tlLXdpZHRoPSIxLjIiPjwvbGluZT4KICA8bGluZSB4MT0iMTU1IiB5MT0iMjQyIiB4Mj0iMjAwIiB5Mj0iMzQwIiBzdHJva2U9IiNhMGJmZTAiIHN0cm9rZS13aWR0aD0iMS4yIj48L2xpbmU+CgogIDwhLS0gPGNpcmNsZS8+IGNoaWxkIChoaWdoZXIpIC0tPgogIDxyZWN0IHg9IjQwIiB5PSIyODAiIHdpZHRoPSIxMDAiIGhlaWdodD0iMzIiIHJ4PSI2IiBmaWxsPSIjZThmMGZlIiBzdHJva2U9IiNhMGJmZTAiIHN0cm9rZS13aWR0aD0iMS4yIiAvPgogIDx0ZXh0IHg9IjkwIiB5PSIzMDEiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZpbGw9IiMyMzQiPiZsdDtjaXJjbGUvJmd0OzwvdGV4dD4KCiAgPCEtLSA8cmVjdC8+IGNoaWxkIChsb3dlcikgLS0+CiAgPHJlY3QgeD0iMTU1IiB5PSIzNDAiIHdpZHRoPSIxMDAiIGhlaWdodD0iMzIiIHJ4PSI2IiBmaWxsPSIjZThmMGZlIiBzdHJva2U9IiNhMGJmZTAiIHN0cm9rZS13aWR0aD0iMS4yIiAvPgogIDx0ZXh0IHg9IjIwNSIgeT0iMzYxIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjMjM0Ij4mbHQ7cmVjdC8mZ3Q7PC90ZXh0PgoKICA8IS0tID09PT09PT09PT09PT09PT09PT09IFNoYWRvdyB0cmVlIHNpZGUgPT09PT09PT09PT09PT09PT09PT0gLS0+CiAgPHRleHQgeD0iNjAwIiB5PSIyNCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxNSIgZm9udC13ZWlnaHQ9ImJvbGQiIGZpbGw9IiMyYTUiPnVzZS1lbGVtZW50IHNoYWRvdyB0cmVlPC90ZXh0PgoKICA8IS0tIEdyZWVuIGRhc2hlZCBib3VuZGluZyBib3ggLS0+CiAgPHJlY3QgeD0iNDMwIiB5PSIzNiIgd2lkdGg9IjM4MCIgaGVpZ2h0PSIzODUiIHJ4PSIxMCIgZmlsbD0iI2YwZmFmMCIgc3Ryb2tlPSIjOGVjYmEwIiBzdHJva2Utd2lkdGg9IjEiIHN0cm9rZS1kYXNoYXJyYXk9IjYsMyIgZmlsbC1vcGFjaXR5PSIwLjUiIC8+CgogIDwhLS0gc2hhZG93IHJvb3QgbGFiZWwgKyBub2RlIC0tPgogIDx0ZXh0IHg9IjYwMCIgeT0iMTA1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjExIiBmaWxsPSIjM2E3ZDRhIiBmb250LXdlaWdodD0iYm9sZCI+c2hhZG93IHJvb3Q8L3RleHQ+CiAgPHJlY3QgeD0iNTM1IiB5PSIxMTAiIHdpZHRoPSIxMzAiIGhlaWdodD0iMzIiIHJ4PSI2IiBmaWxsPSIjZDRlZGRhIiBzdHJva2U9IiM2Y2JmODQiIHN0cm9rZS13aWR0aD0iMS41IiAvPgogIDx0ZXh0IHg9IjYwMCIgeT0iMTMxIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjMjM0Ij4jc2hhZG93LXJvb3Q8L3RleHQ+CgogIDwhLS0gdHJlZSBsaW5lOiBzaGFkb3cgcm9vdCDihpIgZyBpbnN0YW5jZSAtLT4KICA8bGluZSB4MT0iNjAwIiB5MT0iMTQyIiB4Mj0iNjAwIiB5Mj0iMjEwIiBzdHJva2U9IiM2Y2JmODQiIHN0cm9rZS13aWR0aD0iMS4yIj48L2xpbmU+CgogIDwhLS0gaW5zdGFuY2Ugcm9vdCBsYWJlbCAod2l0aCB3aGl0ZSBrbm9ja291dCBvdmVyIHRyZWUgbGluZSkgLS0+CiAgPHJlY3QgeD0iNTU1IiB5PSIxNzAiIHdpZHRoPSI5MCIgaGVpZ2h0PSIxNSIgcng9IjIiIGZpbGw9IndoaXRlIiAvPgogIDx0ZXh0IHg9IjYwMCIgeT0iMTgyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjExIiBmaWxsPSIjMmQ2ZTNmIiBmb250LXdlaWdodD0iYm9sZCI+aW5zdGFuY2Ugcm9vdDwvdGV4dD4KCiAgPCEtLSA8Zz4gaW5zdGFuY2UgKGFsaWduZWQgd2l0aCBkb2N1bWVudC1zaWRlIGcgYXQgeT0yMTApIC0tPgogIDxyZWN0IHg9IjUyNSIgeT0iMjEwIiB3aWR0aD0iMTUwIiBoZWlnaHQ9IjMyIiByeD0iNiIgZmlsbD0iI2MzZTZjYiIgc3Ryb2tlPSIjNDhhODY4IiBzdHJva2Utd2lkdGg9IjEuOCIgLz4KICA8dGV4dCB4PSI2MDAiIHk9IjIzMSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZmlsbD0iIzIzNCI+Jmx0O2cmZ3Q7PC90ZXh0PgoKICA8IS0tIHRyZWUgbGluZXM6IGcgaW5zdGFuY2Ug4oaSIGNpcmNsZSBpbnN0YW5jZSwgZyBpbnN0YW5jZSDihpIgcmVjdCBpbnN0YW5jZSAtLT4KICA8bGluZSB4MT0iNTc1IiB5MT0iMjQyIiB4Mj0iNTQ1IiB5Mj0iMjgwIiBzdHJva2U9IiM2Y2JmODQiIHN0cm9rZS13aWR0aD0iMS4yIj48L2xpbmU+CiAgPGxpbmUgeDE9IjYyNSIgeTE9IjI0MiIgeDI9IjY3MCIgeTI9IjM0MCIgc3Ryb2tlPSIjNmNiZjg0IiBzdHJva2Utd2lkdGg9IjEuMiI+PC9saW5lPgoKICA8IS0tIDxjaXJjbGUvPiBpbnN0YW5jZSAoYWxpZ25lZCB3aXRoIGRvY3VtZW50IGNpcmNsZSBhdCB5PTI4MCkgLS0+CiAgPHJlY3QgeD0iNDk1IiB5PSIyODAiIHdpZHRoPSIxMDAiIGhlaWdodD0iMzIiIHJ4PSI2IiBmaWxsPSIjZDRlZGRhIiBzdHJva2U9IiM2Y2JmODQiIHN0cm9rZS13aWR0aD0iMS4yIiAvPgogIDx0ZXh0IHg9IjU0NSIgeT0iMzAxIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjMjM0Ij4mbHQ7Y2lyY2xlLyZndDs8L3RleHQ+CiAgPHRleHQgeD0iNTQ1IiB5PSIzMjYiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiMzYTdkNGEiIGZvbnQtd2VpZ2h0PSJib2xkIj5lbGVtZW50IGluc3RhbmNlPC90ZXh0PgoKICA8IS0tIDxyZWN0Lz4gaW5zdGFuY2UgKGFsaWduZWQgd2l0aCBkb2N1bWVudCByZWN0IGF0IHk9MzQwKSAtLT4KICA8cmVjdCB4PSI2MjUiIHk9IjM0MCIgd2lkdGg9IjEwMCIgaGVpZ2h0PSIzMiIgcng9IjYiIGZpbGw9IiNkNGVkZGEiIHN0cm9rZT0iIzZjYmY4NCIgc3Ryb2tlLXdpZHRoPSIxLjIiIC8+CiAgPHRleHQgeD0iNjc1IiB5PSIzNjEiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZpbGw9IiMyMzQiPiZsdDtyZWN0LyZndDs8L3RleHQ+CiAgPHRleHQgeD0iNjc1IiB5PSIzODYiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiMzYTdkNGEiIGZvbnQtd2VpZ2h0PSJib2xkIj5lbGVtZW50IGluc3RhbmNlPC90ZXh0PgoKICA8IS0tID09PT09PT09PT09PT09PT09PT09IEFycm93cyA9PT09PT09PT09PT09PT09PT09PSAtLT4KCiAgPCEtLSBob3N0IGFycm93OiB1c2Ug4oaSIHNoYWRvdyByb290IChzdHJhaWdodCBob3Jpem9udGFsKSAtLT4KICA8cGF0aCBkPSJNMzYwLDEyNiBMNTMzLDEyNiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjZDRhMDE3IiBzdHJva2Utd2lkdGg9IjEuNSIgbWFya2VyLWVuZD0idXJsKCNhcnJvdy1nb2xkKSIgLz4KICA8dGV4dCB4PSI0MjIiIHk9IjExOCIgdGV4dC1hbmNob3I9ImVuZCIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzg1NjQwNCIgZm9udC1zdHlsZT0iaXRhbGljIj5ob3N0PC90ZXh0PgoKICA8IS0tIGNsb25lZC1mcm9tOiBnIOKGkiBnIGluc3RhbmNlIChzdHJhaWdodCBob3Jpem9udGFsIGF0IHk9MjI2KSAtLT4KICA8cGF0aCBkPSJNMjEwLDIyNiBMNTIzLDIyNiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjNGE5MGQ5IiBzdHJva2Utd2lkdGg9IjEiIHN0cm9rZS1kYXNoYXJyYXk9IjUsMyIgbWFya2VyLWVuZD0idXJsKCNhcnJvdy1ibHVlKSIgLz4KICA8dGV4dCB4PSI0MjIiIHk9IjIyMCIgdGV4dC1hbmNob3I9ImVuZCIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzRhOTBkOSIgZm9udC1zdHlsZT0iaXRhbGljIj5jbG9uZWQgZnJvbTwvdGV4dD4KCiAgPCEtLSBjbG9uZWQtZnJvbTogY2lyY2xlIOKGkiBjaXJjbGUgaW5zdGFuY2UgKHN0cmFpZ2h0IGhvcml6b250YWwgYXQgeT0yOTYpIC0tPgogIDxwYXRoIGQ9Ik0xNDAsMjk2IEw0OTMsMjk2IiBmaWxsPSJub25lIiBzdHJva2U9IiM0YTkwZDkiIHN0cm9rZS13aWR0aD0iMSIgc3Ryb2tlLWRhc2hhcnJheT0iNSwzIiBtYXJrZXItZW5kPSJ1cmwoI2Fycm93LWJsdWUpIiAvPgoKICA8IS0tIGNsb25lZC1mcm9tOiByZWN0IOKGkiByZWN0IGluc3RhbmNlIChzdHJhaWdodCBob3Jpem9udGFsIGF0IHk9MzU2KSAtLT4KICA8cGF0aCBkPSJNMjU1LDM1NiBMNjIzLDM1NiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjNGE5MGQ5IiBzdHJva2Utd2lkdGg9IjEiIHN0cm9rZS1kYXNoYXJyYXk9IjUsMyIgbWFya2VyLWVuZD0idXJsKCNhcnJvdy1ibHVlKSIgLz4KPC9zdmc+)

The relationship between a document tree containing a
['[use](struct.html#UseElement)'] element and its
[use-element shadow tree](struct.html#TermUseElementShadowTree). Blue
dashed arrows show that each [element
instance](struct.html#TermElementInstance) in the shadow tree is a clone
of an element in the [referenced document
subtree](struct.html#TermReferencedDocumentSubtree). The
['[use](struct.html#UseElement)'] element is the [shadow
host](struct.html#TermShadowHost), and the [instance
root](struct.html#TermInstanceRoot) is the direct child of the [shadow
root](struct.html#TermShadowRoot).

When the user agent successfully resolves a
['[use](struct.html#UseElement)'] element to identify a
[referenced element](struct.html#TermReferencedElement), the user agent
must create a [use-element shadow
tree](struct.html#TermUseElementShadowTree) whose host is the
['[use](struct.html#UseElement)'] element itself. The
shadow tree must be created even if the
['[use](struct.html#UseElement)'] element is not rendered
because it is a descendent of a [never-rendered
element](render.html#TermNeverRenderedElement), because of conditional
processing, or because of the
[display](render.html#VisibilityControl) property being set
to [none] on it or an ancestor element.

Each node in the shadow tree is an
[instance](struct.html#TermElementInstance) of a corresponding node from
the [referenced document
subtree](struct.html#TermReferencedDocumentSubtree). The shadow nodes
all descend from the [instance root](struct.html#TermInstanceRoot),
which is the instance of the [referenced
element](struct.html#TermReferencedElement), and which itself is a
direct child of the [shadow root](struct.html#TermShadowRoot) node.

The shadow tree is open (inspectable by script), but read-only. Any
attempt to directly modify the elements, attributes, and other nodes in
the shadow tree must throw a `NoModificationAllowedError`.

Within a [use-element shadow
tree](struct.html#TermUseElementShadowTree),
['[script](interact.html#ScriptElement)'] elements are
inert (do not execute).

Previous versions of SVG restricted the contents of the shadow tree to
SVG graphics elements. This specification allows any valid SVG document
subtree to be cloned. Cloning non-graphical content, however, will not
usually have any visible effect.

If the [referenced element](struct.html#TermReferencedElement) is in an
external file, then all [URL references](linking.html#TermURLReference)
in attributes and style properties must be made absolute as described in
[Generating the absolute URL](linking.html#processingURL-absolute),
before copying the value to the [element
instances](struct.html#TermElementInstance). The shadow tree itself uses
the same document base URL as the document that includes it.

The user agent must ensure that all mutations to the [referenced
document subtree](struct.html#TermReferencedDocumentSubtree) are
reflected in the shadow tree. This includes changes to elements,
attributes, and text and other nodes. In addition, changes to the
stylesheets in effect for the referenced graphics must be reflected in
changes to the stylesheets in the shadow tree\'s scope, as described
further in the section on [style inheritance](#UseStyleInheritance).

If either the ['[use](struct.html#UseElement)'] element
or the [referenced element](struct.html#TermReferencedElement) is
altered in a way that causes the
['[use](struct.html#UseElement)'] element\'s URL
reference to become [unresolved](linking.html#TermUnresolvedReference)
again, then the entire shadow tree for that use element is discarded.

When a ['[use](struct.html#UseElement)'] references
another element which is another
['[use](struct.html#UseElement)'] or whose content
contains a ['[use](struct.html#UseElement)'] element,
then the shadow DOM cloning approach described above is recursive.
However, a set of references that directly or indirectly reference a
element to create a circular dependency is an [invalid circular
reference](linking.html#TermCircularReference). The
['[use](struct.html#UseElement)'] element or element
instance whose shadow tree would create the circular reference is in
error and must not be rendered by the user agent.

### 5.5.2. Layout of re-used graphics
The value of the [x](geometry.html#XProperty),
[y](geometry.html#YProperty),
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) properties on a
['[use](struct.html#UseElement)'] element are used to
position the re-used graphics and to set the viewport size if the
[referenced element](struct.html#TermReferencedElement) defines a nested
viewport. The effect of these properties on a
['[use](struct.html#UseElement)'] element is notably
different from their effect on a [graphics
element](struct.html#TermGraphicsElement), or from their effect in CSS
box layout.

The [x](geometry.html#XProperty) and
[y](geometry.html#YProperty) properties define an additional
transformation ([translate(x,y)], where [x]
and [y] represent the computed value of the corresponding
property) to be applied to the
['[use](struct.html#UseElement)'] element, after any
transformations specified with other properties (i.e., appended to the
right-side of the transformation list).

For historical reasons, the supplemental transformation is applied to
the ['[use](struct.html#UseElement)'] element itself,
rather than solely to the re-used content in the shadow tree. This
affects the coordinate system used for any masks, clipping paths, or
filters applied to the ['[use](struct.html#UseElement)']
element and calculated in [userSpaceOnUse] units.

To apply [userSpaceOnUse] graphical effects in an
un-transformed coordinate space, while also using the
[x](geometry.html#XProperty) and
[y](geometry.html#YProperty) to position the graphics,
authors can nest the ['[use](struct.html#UseElement)']
element inside a ['[g](struct.html#GElement)'], and apply
the graphical effects to the
['[g](struct.html#GElement)'] element.

The [width](geometry.html#Sizing) and
[height](geometry.html#Sizing) properties on the
['[use](struct.html#UseElement)'] element override the
values for the corresponding properties on a referenced
['[svg](struct.html#SVGElement)'] or
['[symbol](struct.html#SymbolElement)'] element when
determining the used value for that property on the [instance
root](struct.html#TermInstanceRoot) element. However, if the computed
value for the property on the
['[use](struct.html#UseElement)'] element is
[auto], then the property is computed as normal for the
element instance.

These properties can therefore be used to scale a graphic that defines
its own coordinate system, each time it is re-used. Because
[auto] is the initial value, if dimensions are not
explicitly set on the ['[use](struct.html#UseElement)']
element, the values set on the
['[svg](struct.html#SVGElement)'] or
['[symbol](struct.html#SymbolElement)'] will be used as
defaults.

The [width](geometry.html#Sizing) and
[height](geometry.html#Sizing) properties on the
['[use](struct.html#UseElement)'] element have no effect
if the [referenced element](struct.html#TermReferencedElement) does not
[establish a new viewport](coords.html#EstablishingANewSVGViewport). In
particular, the ['[use](struct.html#UseElement)'] element
does not itself establish a new viewport, and therefore does not affect
the interpretation of percentages in the re-used graphics.

In all other ways, rendering and layout of elements within the
[use-element shadow tree](struct.html#TermUseElementShadowTree) occurs
as if the ['[use](struct.html#UseElement)'] element was a
container for its shadow content. In particular, unless elements within
the shadow tree establish a new viewport, they must be drawn in the
coordinate system in which the
['[use](struct.html#UseElement)'] element is defined
(including any cumulative transformations). This affects the
interpretation of percentage lengths, and also graphical effects with
[userSpaceOnUse] units.

### 5.5.3. Style Scoping and Inheritance
The [use-element shadow tree](struct.html#TermUseElementShadowTree),
like other shadow trees, exhibits style encapsulation, as defined in the
[CSS Scoping](https://www.w3.org/TR/css-scoping-1/) module
[\[css-scoping-1\]](refs.html#ref-css-scoping-1). This means that
elements in the shadow tree inherit styles from its
[host](struct.html#TermShadowHost)
['[use](struct.html#UseElement)'] element, but that style
rules defined in the outer document do not match the elements in the
shadow tree. Instead, the shadow tree maintains its own list of
stylesheets, whose CSS rules are matched against elements in the shadow
tree.

Presentation attributes and the
['[style](styling.html#StyleAttribute)'] attribute are
cloned from the elements in the [referenced
graphics](struct.html#TermReferencedDocumentSubtree) into the [element
instances](struct.html#TermElementInstance) in the same manner as other
attributes.

When the [referenced element](struct.html#TermReferencedElement) is from
the same document as the
['[use](struct.html#UseElement)'] element, the same
document stylesheets will apply in both the original document and the
shadow tree document fragment. Any changes to the stylesheets in the
main document also affect the shadow tree; the `StyleSheetList` object
accessed through the document and shadow root document fragment\'s
`styleSheets` properties must be identical. If a
['[style](styling.html#StyleElement)'] element is
duplicated as part of the [referenced document
subtree](struct.html#TermReferencedDocumentSubtree), then the
`styleSheet` property on the [element
instance](struct.html#TermElementInstance) points to the same object as
for the source element in the [referenced document
subtree](struct.html#TermReferencedDocumentSubtree).

When the [referenced element](struct.html#TermReferencedElement) is from
an external document, the stylesheet objects generated when processing
that document apply to the shadow tree, and are read-only. All [URL
references](linking.html#TermURLReference) in the stylesheet, including
fragment-only references, must be made absolute, relative to the URL of
the document that contains the [referenced
element](struct.html#TermReferencedElement). User agents may re-use the
same stylesheet objects for any shadow trees that reference that same
external document.

Style rules that are scoped to the shadow tree cannot normally affect
any elements in the main document. Similarly, style rules in the main
document can only affect the shadow tree elements by changing inherited
values. However, [CSS Scoping](https://www.w3.org/TR/css-scoping-1/)
defines special selectors for styling the
[host](struct.html#TermShadowHost) element from within the shadow tree,
or for adjusting styles within the shadow tree in response to changes in
the host\'s context [\[css-scoping-1\]](refs.html#ref-css-scoping-1).

CSS media queries within a shadow tree\'s scope are evaluated using the
same device features and dimensions as the corresponding \"light\"
document (that is, the document that contains the host
['[use](struct.html#UseElement)'] element for the shadow
tree, after recursively exiting all nested shadow trees).

In most cases, the [element instance](struct.html#TermElementInstance)
in the shadow tree will match the same style rules as its source element
in the [referenced document
subtree](struct.html#TermReferencedDocumentSubtree). However, if a CSS
rule uses a [complex
selector](https://drafts.csswg.org/selectors/#complex) to match an
element based on its ancestors or siblings, and those ancestors or
siblings are not cloned as part of the shadow tree, then that rule would
no longer match the [element instance](struct.html#TermElementInstance).
Similarly, child-indexed pseudo-classes such as `nth-of-type` and
`nth-child` may apply to one element but not the other. This represents
a change from how style cloning was defined in previous versions of SVG.

The following example demonstrates both the consistent and changed
style-matching rules. The circle on the left is re-used to draw the
circle on the right. The original circle has styles set in various ways:

- [stroke-width](painting.html#StrokeWidthProperty) (20) is
 set in a presentation attribute on the circle itself.
- [stroke-opacity](painting.html#StrokeOpacityProperty) (0.7)
 is set via a CSS rule with a simple selector matching the circle tag
 name.
- [stroke](painting.html#StrokeProperty) color (green) is set
 using a complex CSS selector, matching the circle as a descendent of
 an element with class `special`.
- [fill](painting.html#FillProperty) color is not set
 directly on the circle, so is inherited from the style set on the
 containing ['[g](struct.html#GElement)'] element
 (blue).

In the SVG 1.1 style-cloning model, the [specified style
values](https://www.w3.org/TR/css-cascade-3/#specified) would be cloned
from the original element to the element instance. The re-used circle
would have the same styles as the original, except that the
[fill](painting.html#FillProperty) value would be inherited
from the ['[use](struct.html#UseElement)'] (orange)
instead of from the ['[g](struct.html#GElement)'] (blue).

In the shadow DOM model required by SVG 2, the styles for the re-used
circle are calculated as follows:

- the [stroke-width](painting.html#StrokeWidthProperty) (20)
 presentation attribute is cloned to the element instance.
- the CSS rule setting
 [stroke-opacity](painting.html#StrokeOpacityProperty) (0.7)
 is part of the CSS stylesheet cloned into the shadow tree; it matches
 the circle tag name of the [element
 instance](struct.html#TermElementInstance), so is applied.
- the CSS rule with the complex selector is also part of the cloned
 stylesheet, but it does not match the [element
 instance](struct.html#TermElementInstance) of the circle, which is not
 a descendent of an element with class `special`; instead,
 [stroke](painting.html#StrokeProperty) color on the circle
 is inherited from the host
 ['[use](struct.html#UseElement)'] element (purple).
- [fill](painting.html#FillProperty) color is still not set
 directly, so is once again inherited from the host
 ['[use](struct.html#UseElement)'] element.

The re-used circle therefore differs from the original in both fill
color (because it inherits from a different element) and stroke color
(because the complex selector no longer matches).

``` xml
<svg xmlns="http://www.w3.org/2000/svg"
 xmlns:xlink="http://www.w3.org/1999/xlink"
 width="200" height="100" viewBox="0 0 200 100">
 <title>Style inheritance and the use element</title>
 <desc>
 Two circles, one of which is a re-styled clone of the other.
 This file demonstrates one of the cases where
 the shadow-DOM style matching rules in SVG 2
 have a different effect than the SVG 1.1 style cloning rules.
 The original circle on the left
 should have blue fill
 and green stroke.
 In a conforming SVG 1.1 user agent,
 the re-used circle on the right
 should have orange fill and green stroke.
 In a conforming SVG 2 user agent,
 the re-used circle should have orange fill and purple stroke.
 In all cases,
 the stroke should be partially transparent
 and 20 units wide,
 relative to a total circle diameter of 100 units.
 </desc>
 <style type="text/css">
 circle { stroke-opacity: 0.7; }
 .special circle { stroke: green; }
 use { stroke: purple;
 fill: orange; }
 </style>
 <g class="special" style="fill: blue">
 <circle id="c" cy="50" cx="50" r="40"
 stroke-width="20" />
 </g>
 <use xlink:href="#c" x="100" />
</svg>
```

![Example Use-changed-styles --- A \'use\' element copying a \'circle\',
with various style matching rules
demonstrated](images/struct/Use-changed-styles.png)

Example Use-changed-styles

[View this example as SVG (SVG-enabled browsers
only)](images/struct/Use-changed-styles.svg)

Previous versions of SVG were not clear about how dynamic pseudo-classes
(such as `:hover`) should apply to element instances. The shadow tree
model requires that all such pseudo-classes are matched independently to
the [element instance](struct.html#TermElementInstance) or to its source
element in the [referenced document
subtree](struct.html#TermReferencedDocumentSubtree), depending on which
element the user is interacting with.

Specifying [\'visibility:hidden\'] on a
['[use](struct.html#UseElement)'] element does not
guarantee that the referenced content will not be rendered. Unlike the
[display](render.html#VisibilityControl) or the
[opacity](render.html#ObjectAndGroupOpacityProperties)
properties, the [visibility](render.html#VisibilityControl)
property does not apply directly to container elements, and therefore
does not apply directly to the
['[use](struct.html#UseElement)'] element. Because
[visibility](render.html#VisibilityControl) is normally
inherited, hiding the use element will often hide the child content, but
not necessarily. If any graphics elements in the shadow tree have
[\'visibility:visible\'] specified, then that element will
be visible even if the ['[use](struct.html#UseElement)']
element specifies [\'visibility:hidden\'].

In the following example, key style rules are as follows:

``` css

.dark {
 visibility: hidden;
}
.eyes {
 visibility: visible;
}
svg:hover .dark, svg:focus .dark {
 visibility: visible;
}
```

The \"dark\" class is set on the group containing the
['[use](struct.html#UseElement)'] elements, so all parts
of the re-used graphics inherit the hidden visibility setting, except
for the subtrees with class \"eyes\", where it is reset to visible. Upon
hovering or focusing the graphic, the hiding effect is removed.

![Multiple use-copies of a creature-symbol on a black background; the
use elements have visibility: hidden, but the creatures\' eyes have
visibility: visible.](images/struct/Use-visibility-inheritance.png)

Example Use-visibility-hidden, default styles

![Multiple use-copies of a rabbit-symbol on a light green background;
each rabbit has different=coloured fur, but the same pink noses and
white fluffy tails.](images/struct/Use-visibility-inheritance.2.png)

Example Use-visibility-hidden, interactive styles

[View this example as SVG](images/struct/Use-visibility-inheritance.svg)

The example also demonstrates inheritance of other style properties
([fill](painting.html#FillProperty) and
[stroke](painting.html#StrokeProperty)) specified on the
['[use](struct.html#UseElement)'] elements, and how these
are also not used if any elements within the symbol specify explicit
values (e.g., the pink noses and ears and the white tails).

### 5.5.4. Animations in use-element shadow trees
The [Web Animations API](https://www.w3.org/TR/web-animations-1/)
\[[web-animations-1](refs.html#ref-web-animations-1)\] and the [SVG
Animations](https://w3c.github.io/svgwg/specs/animations/) specification
\[[svg-animation](refs.html#ref-svg-animation)\] define non-CSS ways to
animate attributes and styles on targetted elements without directly
manipulating DOM properties (see the [Animation appendix](animate.html)
for details). User agents that implement those features must ensure that
all animations that apply to an element in a [referenced document
subtree](struct.html#TermReferencedDocumentSubtree) also apply to
instances of that element in a [use-element shadow
tree](struct.html#TermUseElementShadowTree), as described in this
section.

Scripted animations created by directly manipulating attributes on
elements in the [referenced
graphics](struct.html#TermReferencedDocumentSubtree) (including the
['[style](styling.html#StyleAttribute)'] attribute or its
IDL property) will be propagated to the [element
instances](struct.html#TermElementInstance) in the shadow tree in the
same manner as any other DOM manipulations.

Animation effects applied using CSS will be duplicated along with other
stylesheet rules, following the procedure specified in the [Style
Scoping and Inheritance](#UseStyleInheritance) section.

All animations within a [use-element shadow
tree](struct.html#TermUseElementShadowTree) operate in the same document
timeline as for the host
['[use](struct.html#UseElement)'] element, regardless of
whether the [referenced element](struct.html#TermReferencedElement) is
from the same or an external document.

For animation effects applied using a [Web Animations
API](https://www.w3.org/TR/web-animations-1/) method
[\[web-animations-1\]](refs.html#ref-web-animations-1), if the target of
the animation is an element in the [referenced document
subtree](struct.html#TermReferencedDocumentSubtree) to an [element
instance](struct.html#TermElementInstance) in a shadow tree, the user
agent must construct a
[ShadowAnimation](struct.html#InterfaceShadowAnimation)
whose source is that
[Animation](https://www.w3.org/TR/web-animations-1/#the-animation-interface)
object and whose target is the [element
instance](struct.html#TermElementInstance). If there are multiple
instances of the element in different trees, then there will be multiple
shadow animations, one for each.

The user agent must create such a
[ShadowAnimation](struct.html#InterfaceShadowAnimation)
for all Web Animations API animations in effect (including pending and
frozen animations) at the time the shadow tree is generated, and for any
new animations applied while the shadow tree exists. The user agent must
not create
[ShadowAnimation](struct.html#InterfaceShadowAnimation)
objects for CSS animations or animation elements (as these are
duplicated separately).

As part of the interface definition, a
[ShadowAnimation](struct.html#InterfaceShadowAnimation)
is read-only, and must reflect any changes to its
[sourceAnimation](struct.html#__svg__ShadowAnimation__sourceAnimation).

Any attempts to directly apply new animations to a target that is a
read-only [element instance](struct.html#TermElementInstance) (or
pseudo-element) within a [use-element shadow
tree](struct.html#TermUseElementShadowTree) must throw a
`NoModificationAllowedError`.

For each [animation
element](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)
\[[svg-animation](refs.html#ref-svg-animation)\] that targets an element
in the [referenced document
subtree](struct.html#TermReferencedDocumentSubtree), the user agent must
ensure that an equivalent animation element is in effect in the
[use-element shadow tree](struct.html#TermUseElementShadowTree). If the
animation element itself is part of the referenced document subtree,
then this happens as a matter of course through the creation of an
[element instance](struct.html#TermElementInstance) for the animation
element. Otherwise, the user agent must generate an [element
instance](struct.html#TermElementInstance) for the animation element
that has the same effect as if it was a node in the shadow tree. The
effective document order for these generated animation elements must be
the same as the document order for their source elements in the
[referenced document
subtree](struct.html#TermReferencedDocumentSubtree).

Each animation element or instance must only affect a target element in
the same node tree (shadow or light), regardless of whether the
targetting is implicit (the parent element) or explicit (a URL
cross-reference to an element
['[id](struct.html#IDAttribute)']). In this way, the
one-to-one relationship between animation elements and target elements
is preserved.

The ['[id](struct.html#IDAttribute)'] attribute is cloned,
like any other attribute, from the source element to the [element
instance](struct.html#TermElementInstance); This does not conflict with
the requirement for ['[id](struct.html#IDAttribute)'] to be
unique, because the clone and the original are in distinct node trees.

All animation elements, in the document or in the shadow trees, which
are timed to begin or end in response to an event on another element
identified by its ['[id](struct.html#IDAttribute)']
attribute, must also begin or end when any
[instance](struct.html#TermElementInstance) of an element with that
['[id](struct.html#IDAttribute)'] receives the same event.
This is consistent with how event listeners on a referenced element also
listen to events on instances of that element, as described in the
section on [Event handling in use-element shadow
trees](#UseEventHandling). This behavior does not apply to animation
begin or end times defined only by an event and not by an
['[id](struct.html#IDAttribute)'] (and therefore implicitly
listening for the event on the target element); in that case, each
animation element is only triggered by its own target.

At the time an [instance](struct.html#TermElementInstance) of an
animation element is generated within a shadow tree, if there is an
active animation associated with the source element in the [referenced
document subtree](struct.html#TermReferencedDocumentSubtree) (including
a frozen animation), and the timing event that initiated that animation
would also have initiated the instance if it existed, then the animation
for the [element instance](struct.html#TermElementInstance) must be
initiated, with its begin time adjusted backwards in the document
timeline to match the timing of the source element.

In many cases, the requirements of this section mean that the [element
instance](struct.html#TermElementInstance) and its source element will
animate synchronously. This will be the case if the animation is purely
time-based, or if it begins and ends in response to user interaction on
an element referenced by its
['[id](struct.html#IDAttribute)']. However, if the animation
is triggered by a user interaction event on the targetted element
(implicitly), then only the element or element instance that receives
the interaction event will display the animation.

This is a change from previous versions of SVG, which required all
animations on the source element to be mirrored, regardless of user
interaction, but which did not offer clear guidance for responding to
user interactions with the element instances. The change ensures that
interactive animations declared with animation elements behave in the
same manner as interactive CSS styles and CSS animations.

In order to create animations that apply to all instances when any
instance or the original element receives an event, specify the element
['[id](struct.html#IDAttribute)'] explicitly:

 <set href="#target" begin="mouseover" ... />
 <!-- only affects the element that is moused over -->

 <set href="#target" begin="target.mouseover" ... />
 <!-- affects all instances of the element with the id 'target',
 in all light and shadow node trees,
 when any of them are moused over -->

### 5.5.5. Event handling in use-element shadow trees
Element in a [use-element shadow
tree](struct.html#TermUseElementShadowTree) can both listen for and be
the target of DOM events. Event retargetting provides encapsulation, so
that the details of the shadow DOM structure are masked when an event
bubbles out of the shadow tree and into the light.

Event retargeting is new in SVG 2. It provides consistency with the
Shadow DOM specification, with existing implementations, and with the
expectations of authors who are only concerned with elements in the main
DOM.

Any event listeners defined on an element in the [referenced
graphics](struct.html#TermReferencedDocumentSubtree) must also listen
for the same event, at the same capture phase, on each
[instance](struct.html#TermElementInstance) of that element in a
[use-element shadow tree](struct.html#TermUseElementShadowTree). This
includes event listeners assigned using [event
attributes](interact.html#TermEventAttribute) (which would be duplicated
as with any other DOM attribute) and also event listeners assigned using
the
[`addEventListener`](https://www.w3.org/TR/dom/#dom-eventtarget-addeventlistener)
method. The user agent must ensure that the list of event listeners for
each [element instance](struct.html#TermElementInstance) is synchronized
to match its source element in the [referenced document
subtree](struct.html#TermReferencedDocumentSubtree). An event listener
cannot be directly assigned to a read-only [element
instance](struct.html#TermElementInstance) in a [use-element shadow
tree](struct.html#TermUseElementShadowTree). Any attempt to add an event
listener to such an element must throw a `NoModificationAllowedError`.

Events in the [use-element shadow
tree](struct.html#TermUseElementShadowTree) are dispatched and bubble
according to the shadow tree [event path and event retargeting
algorithm](https://dom.spec.whatwg.org/#events)
\[[DOM](refs.html#ref-dom)\].

In general, the event path for a [use-element shadow
tree](struct.html#TermUseElementShadowTree) is constructed from the
ancestors of the event target element up to the [shadow
root](struct.html#TermShadowRoot), then the
[host](struct.html#TermShadowHost)
['[use](struct.html#UseElement)'] element and its event
path through to the document window. This means that, in the capture
phase, an event propagates from the window through the regular document
tree to the ['[use](struct.html#UseElement)'] element and
then to the shadow root object and down through the shadow tree (or
recursively through multiple shadow trees) to the event target element.
In the bubbling phase, the event passes in the opposite direction, from
the shadow tree elements to the shadow root, then to the
['[use](struct.html#UseElement)'] element and its
ancestors.

The event retargeting algorithm ensures that from the perspective of
event listeners on the ['[use](struct.html#UseElement)']
element or its ancestors, all events targetted to [element
instances](struct.html#TermElementInstance) in the shadow tree instead
have a target of the ['[use](struct.html#UseElement)']
element itself. If the event has both a
[`target`](https://www.w3.org/TR/dom/#dom-event-target) and a
`relatedTarget`, and both of these properties would be retargeted to
point to the same ['[use](struct.html#UseElement)']
element, then the event is not propagated at all outside of the shadow
tree. This would occur, for example, if focus moved from one element
inside the shadow tree to another. Certain other event types are
constrained to not propagate outside of the shadow tree in which they
were created.

In contrast, event listeners that process the event while it is
propagating through the shadow tree (because the listener has been added
to a source element in the [referenced document
subtree](struct.html#TermReferencedDocumentSubtree)) will receive the
event with its [`target`](https://www.w3.org/TR/dom/#dom-event-target)
pointing to a read-only [element
instance](struct.html#TermElementInstance) in the shadow tree.

## 5.6. Conditional processing
### 5.6.1. Conditional processing overview
SVG contains a ['[switch](struct.html#SwitchElement)']
element along with attributes
['[requiredExtensions](struct.html#RequiredExtensionsAttribute)']
and
['[systemLanguage](struct.html#SystemLanguageAttribute)'] to
provide an ability to specify alternate viewing depending on the
capabilities of a given user agent or the user\'s language.

Attributes
['[requiredExtensions](struct.html#RequiredExtensionsAttribute)']
and
['[systemLanguage](struct.html#SystemLanguageAttribute)']
act as tests and evaluate to either true or false. The
['[switch](struct.html#SwitchElement)'] renders the first
of its children for which all of these attributes test true. If the
given attribute is not specified, then a true value is assumed.

When an element is excluded because of conditional processing, it is
treated as if it had a used value of `none` for the
[display](render.html#VisibilityControl) property. Similar to
the [display](render.html#VisibilityControl) property,
conditional processing attributes only affect the direct rendering of
elements and do not prevent elements from being successfully referenced
by other elements (such as via a
['[use](struct.html#UseElement)']).

In consequence:

- conditional processing affects the visual display of [graphics
 elements](struct.html#TermGraphicsElement),
 ['[a](linking.html#AElement)'],
 ['[foreignObject](embedded.html#ForeignObjectElement)'],
 and [text content elements](text.html#TermTextContentElement).
- conditional processing prevents [animation
 elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)
 from playing.
- conditional processing will have no effect on [never-rendered
 elements](render.html#TermNeverRenderedElement); in particular,
 conditional processing does not affect the processing of a
 ['[style](styling.html#StyleElement)'] or
 ['[script](interact.html#ScriptElement)'] element.
- conditional processing of child content of a never-rendered container
 element (e.g., a
 ['[pattern](pservers.html#PatternElement)'] or a
 ['[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)'])
 will affect whether that child content contributes to the graphical
 effect.

Previous versions of SVG included a third conditional processing
attribute, `requiredFeatures`. This was intended to allow authors to
provide fallback behavior for user agents that only implemented parts of
the SVG specification. Unfortunately, poor specification and
implementation of this attribute made it unreliable as a test of feature
support.

### 5.6.2. Definitions
[conditional processing attribute]
: A conditional processing attribute is one that controls whether or
 not the element on which it appears is processed. Most elements, but
 not all, may have conditional processing attributes specified on
 them. See [Conditional
 processing](struct.html#ConditionalProcessing) for details. The
 conditional processing attributes defined in SVG 2 are
 ['[requiredExtensions](struct.html#RequiredExtensionsAttribute)']
 and
 ['[systemLanguage](struct.html#SystemLanguageAttribute)'].

### 5.6.3. The ['switch'] element
:::: element-summary
::: element-summary-name
['[switch]']

Categories:
: [Container element](struct.html#TermContainerElement), [renderable
 element](render.html#TermRenderableElement)

Content model:
: Any number of the following elements, in any order:
 - [animation
 elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)[
 ---
 ['[animate](https://w3c.github.io/svgwg/specs/animations/#AnimateElement)'],
 ['[animateMotion](https://w3c.github.io/svgwg/specs/animations/#AnimateMotionElement)'],
 ['[animateTransform](https://w3c.github.io/svgwg/specs/animations/#AnimateTransformElement)'],
 ['[set](https://w3c.github.io/svgwg/specs/animations/#SetElement)']]
 - [shape elements](shapes.html#TermShapeElement)[ ---
 ['[circle](shapes.html#CircleElement)'],
 ['[ellipse](shapes.html#EllipseElement)'],
 ['[line](shapes.html#LineElement)'],
 ['[path](paths.html#PathElement)'],
 ['[polygon](shapes.html#PolygonElement)'],
 ['[polyline](shapes.html#PolylineElement)'],
 ['[rect](shapes.html#RectElement)']]

 [[a](linking.html#AElement)],
 [[foreignObject](embedded.html#ForeignObjectElement)],
 [[g](struct.html#GElement)],
 [[image](embedded.html#ImageElement)],
 [[svg](struct.html#SVGElement)],
 [[switch](struct.html#SwitchElement)],
 [[text](text.html#TextElement)],
 [[use](struct.html#UseElement)]

Attributes:

: - [aria attributes](struct.html#TermARIAAttribute)[ ---
 ['[aria-activedescendant](https://www.w3.org/TR/wai-aria-1.1/#aria-activedescendant)'],
 ['[aria-atomic](https://www.w3.org/TR/wai-aria-1.1/#aria-atomic)'],
 ['[aria-autocomplete](https://www.w3.org/TR/wai-aria-1.1/#aria-autocomplete)'],
 ['[aria-busy](https://www.w3.org/TR/wai-aria-1.1/#aria-busy)'],
 ['[aria-checked](https://www.w3.org/TR/wai-aria-1.1/#aria-checked)'],
 ['[aria-colcount](https://www.w3.org/TR/wai-aria-1.1/#aria-colcount)'],
 ['[aria-colindex](https://www.w3.org/TR/wai-aria-1.1/#aria-colindex)'],
 ['[aria-colspan](https://www.w3.org/TR/wai-aria-1.1/#aria-colspan)'],
 ['[aria-controls](https://www.w3.org/TR/wai-aria-1.1/#aria-controls)'],
 ['[aria-current](https://www.w3.org/TR/wai-aria-1.1/#aria-current)'],
 ['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)'],
 ['[aria-details](https://www.w3.org/TR/wai-aria-1.1/#aria-details)'],
 ['[aria-disabled](https://www.w3.org/TR/wai-aria-1.1/#aria-disabled)'],
 ['[aria-dropeffect](https://www.w3.org/TR/wai-aria-1.1/#aria-dropeffect)'],
 ['[aria-errormessage](https://www.w3.org/TR/wai-aria-1.1/#aria-errormessage)'],
 ['[aria-expanded](https://www.w3.org/TR/wai-aria-1.1/#aria-expanded)'],
 ['[aria-flowto](https://www.w3.org/TR/wai-aria-1.1/#aria-flowto)'],
 ['[aria-grabbed](https://www.w3.org/TR/wai-aria-1.1/#aria-grabbed)'],
 ['[aria-haspopup](https://www.w3.org/TR/wai-aria-1.1/#aria-haspopup)'],
 ['[aria-hidden](https://www.w3.org/TR/wai-aria-1.1/#aria-hidden)'],
 ['[aria-invalid](https://www.w3.org/TR/wai-aria-1.1/#aria-invalid)'],
 ['[aria-keyshortcuts](https://www.w3.org/TR/wai-aria-1.1/#aria-keyshortcuts)'],
 ['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)'],
 ['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)'],
 ['[aria-level](https://www.w3.org/TR/wai-aria-1.1/#aria-level)'],
 ['[aria-live](https://www.w3.org/TR/wai-aria-1.1/#aria-live)'],
 ['[aria-modal](https://www.w3.org/TR/wai-aria-1.1/#aria-modal)'],
 ['[aria-multiline](https://www.w3.org/TR/wai-aria-1.1/#aria-multiline)'],
 ['[aria-multiselectable](https://www.w3.org/TR/wai-aria-1.1/#aria-multiselectable)'],
 ['[aria-orientation](https://www.w3.org/TR/wai-aria-1.1/#aria-orientation)'],
 ['[aria-owns](https://www.w3.org/TR/wai-aria-1.1/#aria-owns)'],
 ['[aria-placeholder](https://www.w3.org/TR/wai-aria-1.1/#aria-placeholder)'],
 ['[aria-posinset](https://www.w3.org/TR/wai-aria-1.1/#aria-posinset)'],
 ['[aria-pressed](https://www.w3.org/TR/wai-aria-1.1/#aria-pressed)'],
 ['[aria-readonly](https://www.w3.org/TR/wai-aria-1.1/#aria-readonly)'],
 ['[aria-relevant](https://www.w3.org/TR/wai-aria-1.1/#aria-relevant)'],
 ['[aria-required](https://www.w3.org/TR/wai-aria-1.1/#aria-required)'],
 ['[aria-roledescription](https://www.w3.org/TR/wai-aria-1.1/#aria-roledescription)'],
 ['[aria-rowcount](https://www.w3.org/TR/wai-aria-1.1/#aria-rowcount)'],
 ['[aria-rowindex](https://www.w3.org/TR/wai-aria-1.1/#aria-rowindex)'],
 ['[aria-rowspan](https://www.w3.org/TR/wai-aria-1.1/#aria-rowspan)'],
 ['[aria-selected](https://www.w3.org/TR/wai-aria-1.1/#aria-selected)'],
 ['[aria-setsize](https://www.w3.org/TR/wai-aria-1.1/#aria-setsize)'],
 ['[aria-sort](https://www.w3.org/TR/wai-aria-1.1/#aria-sort)'],
 ['[aria-valuemax](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemax)'],
 ['[aria-valuemin](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemin)'],
 ['[aria-valuenow](https://www.w3.org/TR/wai-aria-1.1/#aria-valuenow)'],
 ['[aria-valuetext](https://www.w3.org/TR/wai-aria-1.1/#aria-valuetext)'],
 ['[role](struct.html#RoleAttribute)']]
 - [conditional processing
 attributes](struct.html#TermConditionalProcessingAttribute)[ ---
 ['[requiredExtensions](struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](struct.html#SystemLanguageAttribute)']]
 - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [presentation attributes](styling.html#TermPresentationAttribute)[
 --- ]

DOM Interfaces:

: - [SVGSwitchElement](struct.html#InterfaceSVGSwitchElement)

The ['[switch](struct.html#SwitchElement)'] element
evaluates the
['[requiredExtensions](struct.html#RequiredExtensionsAttribute)']
and
['[systemLanguage](struct.html#SystemLanguageAttribute)']
attributes on its direct child elements in order, and then processes and
renders the first child for which these attributes evaluate to true. All
others will be bypassed and therefore not rendered. If the child element
is a container element such as a
['[g](struct.html#GElement)'], then the entire subtree is
either processed/rendered or bypassed/not rendered.

In SVG, when evaluating the
['[systemLanguage](struct.html#SystemLanguageAttribute)']
attribute, the order of evaluation of descendant elements of the
['[switch](struct.html#SwitchElement)'] element must be
as if the
[\'allowReorder\'](https://www.w3.org/TR/REC-smil/smil-content.html#adef-allowReorder)
attribute, defined in the SMIL specification
\[[SMIL](refs.html#ref-SMIL)\] always has a value of \'yes\'.

Note that the values of properties
[display](render.html#VisibilityControl) and
[visibility](render.html#VisibilityControl) have no effect on
['[switch](struct.html#SwitchElement)'] element
processing. In particular, setting
[display](render.html#VisibilityControl) to
[none] on a child of a
['[switch](struct.html#SwitchElement)'] element has no
effect on true/false testing associated with
['[switch](struct.html#SwitchElement)'] element
processing.

The ['[switch](struct.html#SwitchElement)'] element does
not affect the processing of
['[script](interact.html#ScriptElement)'] and
['[style](styling.html#StyleElement)'] elements.

For more information and an example, see [Embedding foreign object
types](embedded.html#ForeignObjectElement).

### 5.6.4. The ['requiredExtensions'] attribute
The
['[requiredExtensions](struct.html#RequiredExtensionsAttribute)']
attribute defines a list of required language extensions. Language
extensions are capabilities within a user agent that go beyond the
feature set defined in this specification. Each extension is identified
by an [URL reference](linking.html#URLReference).

 Name Value Initial value Animatable
 --------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------- --------------- ------------
 [requiredExtensions] [set of space-separated tokens](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#set-of-space-separated-tokens) [\[HTML\]] (none) no

The value is a list of [URL reference](linking.html#URLReference)s which
identify the required extensions, with the individual values separated
by white space. Determines whether all of the named *extensions* are
supported by the user agent. If all of the given extensions are
supported, then the attribute evaluates to true; otherwise, the current
element and its children are skipped and thus will not be rendered.

If a given [URL reference](linking.html#URLReference) contains white
space within itself, that white space must be escaped.

If the attribute is not present, then it implicitly evaluates to
\"true\". If a null string or empty string value is given to attribute
['[requiredExtensions](struct.html#RequiredExtensionsAttribute)'],
the attribute evaluates to \"false\".

['[requiredExtensions](struct.html#RequiredExtensionsAttribute)']
is often used in conjunction with the
['[switch](struct.html#SwitchElement)'] element. If the
['[requiredExtensions](struct.html#RequiredExtensionsAttribute)']
is used in other situations, then it represents a simple switch on the
given element whether to render the element or not.

The URL names for the extension should include versioning information,
such as \"http://example.org/SVGExtensionXYZ/1.0\", so that script
writers can distinguish between different versions of a given extension.

### 5.6.5. The ['systemLanguage'] attribute
 Name Value Initial value Animatable
 ------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------- --------------- ------------
 [systemLanguage] [set of comma-separated tokens](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#set-of-comma-separated-tokens) [\[HTML\]] (none) no

The value is a [set of comma-separated
tokens](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#set-of-comma-separated-tokens),
each of which must be a
[Language-Tag](https://tools.ietf.org/html/bcp47#section-2.1) value, as
defined in [BCP 47](https://www.ietf.org/rfc/bcp/bcp47.txt)
\[[BCP47](refs.html#ref-bcp47)\].

**To evaluate the ['systemLanguage'] attribute** with value
`V`:

1. Let `tags` be the result of parsing `V` as a
 [set of comma-separated
 tokens](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#set-of-comma-separated-tokens)
 [\[[HTML](refs.html#ref-html)\]].

2. Remove from `tags` any token that is the empty string.

3. If `tags` is empty, return false.

4. Let `user languages` be the user\'s ordered list of
 preferred languages.

5. For each `tag` in `tags`, for each
 `user-lang` in `user languages`:

 1. If `tag` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match for `user-lang`, return true.

 2. If `user-lang` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 prefix of `tag` and the code point in
 `tag` immediately following the prefix is U+002D
 HYPHEN-MINUS (-), return true.

6. Return false.

If the attribute is not present, then it implicitly evaluates to
\"true\".

This use of a prefix matching rule does not imply that language tags are
assigned to languages in such a way that it is always true that if a
user understands a language with a certain tag, then this user will also
understand all languages with tags for which this tag is a prefix.

The prefix rule simply allows the use of prefix tags if this is the
case.

Implementation note: When making the choice of linguistic preference
available to the user, implementers should take into account the fact
that users are not familiar with the details of language matching as
described above, and should provide appropriate guidance. As an example,
users may assume that on selecting \"en-gb\", they will be served any
kind of English document if British English is not available. The user
interface for setting user preferences should guide the user to add
\"en\" to get the best matching behavior.

Multiple languages may be listed for content that is intended for
multiple audiences. For example, content that is presented
simultaneously in the original Maori and English versions, would call
for:

 <text systemLanguage="mi, en"><!-- content goes here --></text>

However, just because multiple languages are present within the object
on which the ['systemLanguage'] test attribute is placed,
this does not mean that it is intended for multiple linguistic
audiences. An example would be a beginner\'s language primer, such as
\"A First Lesson in Latin,\" which is clearly intended to be used by an
English-literate audience. In this case, the
['systemLanguage'] test attribute should only include
\"en\".

The ['switch'] element evaluates each child\'s
['systemLanguage'] attribute in order and renders only the
first match. A final child without ['systemLanguage'] acts
as a catch-all, ensuring content is always displayed regardless of the
user\'s language preferences.

 <switch>
 <text systemLanguage="fr" x="10" y="30">Bonjour</text>
 <text systemLanguage="ja" x="10" y="30">こんにちは</text>
 <text x="10" y="30">Hello</text>
 </switch>

A user with language preference \"fr\" sees \"Bonjour\". A user with
\"ja\" sees \"こんにちは\". Any other user sees the catch-all \"Hello\".

The prefix matching rule allows authors to provide progressively
specific language variants. More specific tags should appear first,
since the ['switch'] element renders the first matching
child.

 <switch>
 <text systemLanguage="zh-Hans" x="10" y="30">简体中文</text>
 <text systemLanguage="zh-Hant" x="10" y="30">繁體中文</text>
 <text systemLanguage="zh" x="10" y="30">中文</text>
 </switch>

A user with language preference \"zh-Hans-CN\" matches the first child,
because \"zh-Hans\" is an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
prefix of \"zh-Hans-CN\" followed by \"-\". A user with \"zh-TW\" does
not match \"zh-Hans\" or \"zh-Hant\", but matches the \"zh\" fallback.

Authoring note: Authors should realize that if several alternative
language objects are enclosed in a ['switch'], and none
of them matches, this may lead to situations where no content is
displayed. It is thus recommended to include a \"catch-all\" choice at
the end of such a ['switch'] which is acceptable in all
cases.

['systemLanguage'] is often used in conjunction with the
['switch'] element. If the ['systemLanguage']
is used in other situations, then it represents a simple switch on the
given element whether to render the element or not.

## 5.7. The ['desc'] and ['title'] elements
### 5.7.1. Definition
[descriptive element]
: An element which provides supplementary descriptive information
 about its parent. Specifically, the following elements are
 descriptive elements:
 ['[desc](struct.html#DescElement)'],
 ['[metadata](struct.html#MetadataElement)'] and
 ['[title](struct.html#TitleElement)'].

Multilingual descriptive text selection, based on the
['[lang](struct.html#LangAttribute)'] attribute, was added
to allow internationalization of the
['[desc](struct.html#DescElement)'] and
['[title](struct.html#TitleElement)'] elements.

New in SVG 2. Adding \'lang\' resolved at Rigi Kaltbad face-to-face.
Removed text that limited number of \'desc\' and \'title\' elements.
Status: Done.

:::::::::: ready-for-wider-review
Any [container element](struct.html#TermContainerElement) or [graphics
element](struct.html#TermGraphicsElement) in an SVG document can have
zero or more ['[desc](struct.html#DescElement)'] and/or
['[title](struct.html#TitleElement)'] elements as
children, whose content is text.
['[desc](struct.html#DescElement)'] and
['[title](struct.html#TitleElement)'] elements are not
visually rendered as part of the graphics. The
[display](render.html#VisibilityControl) value for the
['[title](struct.html#TitleElement)'] and
['[desc](struct.html#DescElement)'] elements must always
be set to [none] by the [user agent style
sheet](styling.html#UAStyleSheet), and this declaration must have
importance over any other CSS rule or presentation attribute.

Multiple sibling ['[desc](struct.html#DescElement)'] or
['[title](struct.html#TitleElement)'] elements must have
different languages, as defined using a
['[lang](struct.html#LangAttribute)'] attribute (or
`xml:lang` attribute) on the descriptive element or an ancestor. The
user agent must select the element of each type whose language best
matches language preferences set by the user. A descriptive element with
an empty-string language tag (indicating no language, for example a text
alternative consisting of emoji symbols) is a lowest-priority match for
any user, ranked below all user-specified language preferences. If
multiple equally valid matches exist, the first match should be used. If
no match exists for either \'title\' or \'desc\', the first element of
that type must be selected.

The following example shows alternative language titles on a re-used
star icon, inline in an HTML document. The example assumes that the HTML
document as a whole has a correctly-declared language of `en` (English
without a specified country code).

 <svg>
 <use href="#star">
 <title>Favourite</title>
 <title lang="en-us">Favorite</title>
 <title lang="nl">Favoriet</title>
 <title lang="">★</title>
 </use>
 </svg>

The first `title` element inherits the language of the document (`en`);
the others have explicitly-declared languages for each element. If the
user\'s preferred language (out of those provided) is American English,
the icon title is the American spelling \"Favorite\". If the user\'s
preferred language is Dutch, the icon title is \"Favoriet\". If the
user\'s preference list includes generic English ranked higher than
Dutch, the title is \"Favourite\" with British spelling. If the user
does not understand either Dutch or English, the title will be the star
symbol character---which is not ideal (most screen readers will read it
as a localized version of \"black star\"), but better than no text
alternative at all.

Authors should be aware that SVG 1.1-supporting user agents that have
not yet implemented multi-lingual descriptive text will normally select
the first element of each type, regardless of user preferences. SVG 1.1
user agents may also fail to recognize a `title` element that is not the
first child of its parent, or a `desc` element that has previous
siblings that are not other descriptive elements.

The use of more than one
['[title](struct.html#TitleElement)'] or
['[desc](struct.html#DescElement)'] element to provide
localised information is at risk, with no known implementations.

User agents must make the text content of selected \'title\' and
\'desc\' elements available to platform accessibility APIs as part of
the name and description computation for the parent element, as defined
in the [SVG Accessibility API Mappings
\[SVG-AAM\]](https://www.w3.org/TR/svg-aam-1.0/) specification.

Inclusion of any \'title\' or \'desc\' elements as a direct child of a
[rendered element](render.html#TermRenderedElement) indicates that the
rendered element is of semantic importance in the graphic. Authors
should not, and [SVG generators](conform.html#TermSVGGenerator) must
not, include empty \'title\' or \'desc\' elements with no text content
or whitespace-only text content, as this will result in a nameless
object being presented to assistive technology users.

If an individual graphic element has no meaning on its own, alternative
text should instead be provided for the nearest container element that
describes a meaningful object. Authors should use grouping
(['[g](struct.html#GElement)']) elements to structure
their drawing elements into meaningful objects, and name those groups
with ['[title](struct.html#TitleElement)']. Conversely,
if a container object is used simply to apply styles or layout, and
neither defines an object nor provides meaningful grouping structure, it
does not need alternative text.

Descriptive text elements whose parent is [not
rendered](render.html#Rendered-vs-NonRendered) may be used by authors or
authoring tools as reference information; authors are warned that this
data is not normally available to end users viewing the graphic through
assistive technologies. Nonetheless, a [non-rendered
element](render.html#TermNonRenderedElement) may be referenced as part
of the accessible name or description of a rendered element (as defined
in [SVG-AAM](https://www.w3.org/TR/svg-aam-1.0/)), and the recursive
computation will use descriptive child elements of the referenced
element.

Description and title elements may contain marked-up text from other
namespaces, using standard XML mechanisms to indicate the namespace.
However, authors should not rely on such markup to provide meaning to
alternative text; only the plain text content is currently required to
be exposed to assistive technologies.

The HTML parser treats all markup within
['[title](struct.html#TitleElement)'] and
['[desc](struct.html#DescElement)'] the same way it
treats markup in an HTML fragment; most elements will be assigned to the
HTML namespace.

User agents may use markup within
['[title](struct.html#TitleElement)'] to influence the
visual presentation of titles (such as tooltips), but are not required
to do so.

:::: element-summary
::: element-summary-name
['[title]']

Categories:
: [Descriptive element](struct.html#TermDescriptiveElement),
 [never-rendered element](render.html#TermNeverRenderedElement)

Content model:
: Any elements or character data.

Attributes:

: - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]

DOM Interfaces:

: - [SVGTitleElement](struct.html#InterfaceSVGTitleElement)

The ['[title](struct.html#TitleElement)'] child element
represents a short text alternative for the element.

On a link, this could be the title or a description of the target
resource; on an image or drawing object, it could be a short description
of the graphic; on interactive content, it could be a label for, or
instructions for, use of the element; and so forth.

Authors should not provide redundant information in a
['[title](struct.html#TitleElement)'] element if there is
also a visible label for the drawing element (e.g., using a
['[text](text.html#TextElement)'] element). Instead, the
visual label should be associated with the drawing element using an
['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)']
attribute.

Interactive user agents should make the plain text content of
['[title](struct.html#TitleElement)'] elements available
in response to user interaction, in a manner consistent with platform
conventions; existing user agents commonly render
['[title](struct.html#TitleElement)'] elements as a
tooltip on hovering the parent element.

Authors should provide a
['[title](struct.html#TitleElement)'] child element to
the root svg element within a stand-alone SVG document. Since users
often consult documents out of context, authors should provide
context-rich titles. Thus, instead of a title such as \"Introduction\",
which doesn\'t provide much contextual background, authors should supply
a title such as \"Introduction to Medieval Bee-Keeping\" instead. For
reasons of accessibility, user agents should always make the content of
the 'title' child element to the root svg element available to users.
However, this is typically done through other means than the tooltips
used for nested SVG and graphics elements, e.g., by displaying in a
browser tab.

:::: element-summary
::: element-summary-name
['[desc]']

Categories:
: [Descriptive element](struct.html#TermDescriptiveElement),
 [never-rendered element](render.html#TermNeverRenderedElement)

Content model:
: Any elements or character data.

Attributes:

: - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]

DOM Interfaces:

: - [SVGDescElement](struct.html#InterfaceSVGDescElement)

The ['[desc](struct.html#DescElement)'] element
represents more detailed textual information for the element such as a
description. This is typically exposed to assistive technologies to
provide more detailed information, such as a description of the visual
appearance of a graphic or help to explain the functionality of a
complex widget. It is not typically available to other users, so should
not be used for essential instructions.

Authors may associate detailed information, including visible text, with
part of the graphic using
['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)']
attribute (on the described element or a parent container), with the
value being an ID reference to one or more SVG or HTML elements
containing the description. The
['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)']
attribute takes precedence over the child
['[desc](struct.html#DescElement)'] when providing a
description. If an element has both visible description and a child
['[desc](struct.html#DescElement)'] element providing
supplementary information, authors should explicitly include the
['[id](struct.html#IDAttribute)'] of the element itself in
its own
['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)']
list, in order to concatenate the two descriptions together.

## 5.8. The ['metadata'] element
Metadata which is included with SVG content should be specified within
['[metadata](struct.html#MetadataElement)'] elements. The
contents of the
['[metadata](struct.html#MetadataElement)'] should be
elements from other XML namespaces, with these elements from these
namespaces expressed in a manner conforming with the [Namespaces in
XML](https://www.w3.org/TR/2006/REC-xml-names-20060816/) Recommendation
\[[xml-names](refs.html#ref-xml-names)\].

SVG 2 removes the recommendation to structure metadata elements in any
particular way.

:::: element-summary
::: element-summary-name
['[metadata]']

Categories:
: [Descriptive element](struct.html#TermDescriptiveElement),
 [never-rendered element](render.html#TermNeverRenderedElement)

Content model:
: Any elements or character data.

Attributes:

: - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]

DOM Interfaces:

: - [SVGMetadataElement](struct.html#InterfaceSVGMetadataElement)

Metadata content is not directly rendered; the
[display](render.html#VisibilityControl) value for the
['[metadata](struct.html#MetadataElement)'] element must
always be set to [none] by the [user agent style
sheet](styling.html#UAStyleSheet), and this declaration must have
importance over any other CSS rule or presentation attribute.

Here is an example of how metadata can be included in an SVG document.
The example uses the Dublin Core version 1.1 schema. (Other
XML-compatible metadata languages, including ones not based on RDF, can
be used also.)

 <?xml version="1.0" standalone="yes"?>
 <svg width="4in" height="3in"
 xmlns = 'http://www.w3.org/2000/svg'>
 <desc xmlns:myfoo="http://example.org/myfoo">
 <myfoo:title>This is a financial report</myfoo:title>
 <myfoo:descr>The global description uses markup from the
 <myfoo:emph>myfoo</myfoo:emph> namespace.</myfoo:descr>
 <myfoo:scene><myfoo:what>widget $growth</myfoo:what>
 <myfoo:contains>$three $graph-bar</myfoo:contains>
 <myfoo:when>1998 $through 2000</myfoo:when> </myfoo:scene>
 </desc>
 <metadata>
 <rdf:RDF
 xmlns:rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
 xmlns:rdfs = "http://www.w3.org/2000/01/rdf-schema#"
 xmlns:dc = "http://purl.org/dc/elements/1.1/" >
 <rdf:Description about="http://example.org/myfoo"
 dc:title="MyFoo Financial Report"
 dc:description="$three $bar $thousands $dollars $from 1998 $through 2000"
 dc:publisher="Example Organization"
 dc:date="2000-04-11"
 dc:format="image/svg+xml"
 dc:language="en" >
 <dc:creator>
 <rdf:Bag>
 <rdf:li>Irving Bird</rdf:li>
 <rdf:li>Mary Lambert</rdf:li>
 </rdf:Bag>
 </dc:creator>
 </rdf:Description>
 </rdf:RDF>
 </metadata>
 </svg>

## 5.9. HTML metadata elements
For user agents that support HTML, the following HTML elements (in the
HTML namespace) must be supported in SVG documents:

- the
 [`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element)
 element
- the
 [`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element)
 element
- the
 [`meta`](https://html.spec.whatwg.org/multipage/semantics.html#the-meta-element)
 element
- the
 [`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element)
 element
- the
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#the-script-element)
 element

Note that the
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element)
element will affect all URL values in the document, including e.g. paint
server references or ['[use](struct.html#UseElement)']
element references. However, when [processing URL
references](linking.html#processingURL-absolute) to identify a specific
target element, the user agent must always compare the generated
absolute URL against the current document base URL to determine whether
it is a [same-document URL reference](linking.html#TermSameDocumentURL).
In this way, target-fragment only references to elements in the same
document remain valid, regardless of any changes to the document base
URL.

## 5.10. Foreign namespaces and private data
SVG allows inclusion of elements from foreign namespaces anywhere within
the SVG content. In general, the SVG user agent must include the unknown
foreign-namespaced elements in the DOM but will ignore and exclude them
for rendering purposes.

The notable exceptions is described in the [Embedded Content
chapter](embedded.html) under [Embedding Foreign Object
Types](embedded.html#ForeignObjectElement).

Additionally, SVG allows inclusion of attributes from foreign namespaces
on any SVG element. The SVG user agent must include unknown attributes
in the DOM but should otherwise ignore unknown attributes.

Authors should be aware that unknown namespaced elements and attributes
will not be parsed as such by the HTML parser. Instead, the namespace
prefix will be included in the tag or attribute name, elements will be
placed in the parent element namespace and attributes in the default
namespace.

To add custom attributes in a way that will result in consistent parsing
in both XML and HTML documents, authors may use the
[['data-\*'] attributes](#DataAttributes). These can be
added to SVG ['[metadata](struct.html#MetadataElement)']
elements if the information they encode is not associated with any other
element in the document.

SVG\'s ability to include foreign namespaces can be used for the
following purposes:

- Application-specific information so that authoring applications can
 include model-level data in the SVG content to serve their
 \"roundtripping\" purposes (i.e., the ability to write, then read a
 file without loss of higher-level information).
- Supplemental data for extensibility. For example, suppose there is an
 extension which extrudes 2D graphics into three dimensions according
 to certain parameters; these parameters may be included in the SVG
 content by inserting elements from the extension\'s namespace.

For example, a business graphics authoring application might want to
include some private data within an SVG document so that it could
properly reassemble the chart (a pie chart in this case) upon reading it
back in:

 <?xml version="1.0" standalone="yes"?>
 <svg width="4in" height="3in"
 xmlns = 'http://www.w3.org/2000/svg'>
 <defs>
 <myapp:piechart xmlns:myapp="http://example.org/myapp"
 title="Sales by Region">
 <myapp:pieslice label="Northern Region" value="1.23"/>
 <myapp:pieslice label="Eastern Region" value="2.53"/>
 <myapp:pieslice label="Southern Region" value="3.89"/>
 <myapp:pieslice label="Western Region" value="2.04"/>
 <!-- Other private data goes here -->
 </myapp:piechart>
 </defs>
 <desc>This chart includes private data in another namespace
 </desc>
 <!-- In here would be the actual SVG graphics elements which
 draw the pie chart -->
 </svg>

## 5.11. Common attributes
### 5.11.1. Definitions
[core attributes]
: The core attributes are those attributes that can be specified on
 any SVG element. The core attributes are
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'] and
 ['[style](styling.html#StyleAttribute)'], along with all
 [custom data attributes](struct.html#DataAttributes).

### 5.11.2. Attributes common to all elements: ['id'](#Core.attrib)

The ['[id](struct.html#IDAttribute)'] attribute is available
on all SVG elements:

 Name Value Initial value Animatable
 --------------------------------------------------------------------------- ------------- --------------- ------------
 [id] (see below) (none) no

Must reflect the [element\'s ID](https://www.w3.org/TR/dom/#concept-id)
\[[DOM](refs.html#ref-dom)\]. The
['[id](struct.html#IDAttribute)'] attribute must be unique
within the node tree, must not be an empty string, and must not contain
any whitespace characters.

Additional requirements apply in order for the
['[id](struct.html#IDAttribute)'] attribute to be valid in
XML documents, as defined in the specification for the relevant version
of XML. A stand-alone SVG document uses XML 1.0 syntax
\[[xml](refs.html#ref-xml)\], which specifies that valid
['[id](struct.html#IDAttribute)'] values are [XML name
tokens](https://www.w3.org/TR/xml/#NT-Name). Valid XML 1.0 names only
include designated characters (letters, digits, and a few punctuation
marks), and do not start with a digit, a full stop (.) character, or a
hyphen-minus (-) character.

User agents should process ['[id](struct.html#IDAttribute)']
values in SVG files irrespective of XML validity.

Authors should avoid the use of
['[id](struct.html#IDAttribute)'] values that would be
parsed as an [SVG view specification](linking.html#SVGViewSpecification)
or a [basic media fragment](linking.html#MediaFragments) when used as a
URL target fragment.

### 5.11.3. The ['lang'] and ['xml:lang'] attributes
The ['lang'] attribute (in no namespace) specifies the
primary language for the element\'s contents and for any of the
element\'s attributes that contain text.

The ['lang'] attribute in the XML namespace is defined in
XML \[[xml](refs.html#ref-xml)\].

If these attributes are omitted from an element, then the language of
this element is the same as the language of its parent element, if any.

The ['lang'] attribute in the XML namespace may be used on
SVG elements in XML documents. If both the ['lang']
attribute in no namespace and the ['lang'] attribute in the
XML namespace are specified on the same element, they must have exactly
the same value when compared in an ASCII case-insensitive manner.

If both the ['lang'] attribute in no namespace and the
['lang'] attribute in the XML namespace are set on an
element, user agents must use the ['lang'] attribute in the
XML namespace, and the ['lang'] attribute in no namespace
must be ignored for the purposes of determining the element\'s language.

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------- ----------------------------------------------------------------------------------- --------------- ------------
 [lang] [Language-Tag](https://tools.ietf.org/html/bcp47#section-2.1) [\[ABNF\]] (none) no

The ['lang'] attribute specifies the primary language for
the element\'s contents and for any of the element\'s attributes that
contain text. Its value must be a valid BCP 47 language tag, or the
empty string. Setting the attribute to the empty string indicates that
the primary language is unknown. \[[BCP47](refs.html#ref-bcp47)\].

### 5.11.4. The ['xml:space'] attribute
 -------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Deprecate the use of ['xml:space'] to affect text layout and use the '[white-space]' property instead.
 Resolution: [We drop xml:space from SVG 2 and remove the relating tests from the SVG 1.1. test suite.](https://www.w3.org/2011/03/03-svg-minutes.html#item04)
 Purpose: To align with CSS.
 Owner: Chris ([ACTION-3004](https://www.w3.org/Graphics/SVG/WG/track/actions/3004), done; and [ACTION-3005](https://www.w3.org/Graphics/SVG/WG/track/actions/3005), done)
 Status Done.
 -------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------

 Name Value Initial value Animatable
 ---------------------------------------------------------------------------------------- ------------- --------------- ------------
 [xml:space] (see below) default no

Deprecated XML attribute to specify whether white space is preserved in
character data. The only possible values are the strings
[\'default\'] and [\'preserve\'], without
white space. Refer to the [Extensible Markup Language (XML)
1.0](https://www.w3.org/TR/2008/REC-xml-20081126/) Recommendation
\[[xml](refs.html#ref-xml)\] and to the discussion [white space
handling](text.html#WhiteSpace) in SVG.

New content should use the
[white-space](https://www.w3.org/TR/css-text-3/#white-space-property)
property instead.

### 5.11.5. The ['tabindex'] attribute
 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------- --------------- ------------
 [tabindex] [valid integer](https://html.spec.whatwg.org/#valid-integer) [\[HTML\]] (none) no

This content attribute allows authors to control whether an element is
focusable, whether it is supposed to be reachable using [sequential
focus navigation](interact.html#Focus), and what is to be the relative
order of the element for the purposes of sequential focus navigation.

The name \"tab index\" comes from the common use of the \"tab\" key to
navigate through the focusable elements. The term \"tabbing\" refers to
moving forward through the focusable elements that can be reached using
sequential focus navigation.

### 5.11.6. The ['autofocus'] attribute
 Name Value Initial value Animatable
 --------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------- --------------- ------------
 [autofocus] [boolean attribute](https://html.spec.whatwg.org/C/#boolean-attribute) [\[HTML\]] (none) no

This content attribute allows authors to ask a focusable element to be
focused after it\'s connected to a document. See
[autofocus](https://html.spec.whatwg.org/C/#attr-fe-autofocus) in the
HTML specification for details.

The attribute has no effect if the element is not already
[focusable](interact.html#TermFocusable).

::: ready-for-wider-review
### 5.11.7. The ['data-\*'] attributes
All SVG elements support [custom data
attributes](https://www.w3.org/TR/2014/CR-html5-20140204/dom.html#custom-data-attribute),
which are those in no namespace whose names begin with the string
\"data-\". See the [requirements for custom data
attributes](https://www.w3.org/TR/2014/CR-html5-20140204/dom.html#embedding-custom-non-visible-data-with-the-data-*-attributes)
in the HTML specification.

## 5.12. WAI-ARIA attributes
### 5.12.1. Definitions
[ARIA attributes]
: These are the attributes defined in WAI-ARIA, consisting of WAI-ARIA
 states and properties as well as the role attribute. See the
 WAI-ARIA [Definition of
 Roles](https://www.w3.org/TR/wai-aria-1.1/#role_definitions), the
 WAI-ARIA Graphics Module [Graphics
 Roles](https://www.w3.org/TR/graphics-aria-1.0/#roles), and the
 WAI-ARIA [Supported States and
 Properties](https://www.w3.org/TR/wai-aria/#states_and_properties).
 The aria attributes are
 ['[aria-activedescendant](https://www.w3.org/TR/wai-aria-1.1/#aria-activedescendant)'],
 ['[aria-atomic](https://www.w3.org/TR/wai-aria-1.1/#aria-atomic)'],
 ['[aria-autocomplete](https://www.w3.org/TR/wai-aria-1.1/#aria-autocomplete)'],
 ['[aria-busy](https://www.w3.org/TR/wai-aria-1.1/#aria-busy)'],
 ['[aria-checked](https://www.w3.org/TR/wai-aria-1.1/#aria-checked)'],
 ['[aria-colcount](https://www.w3.org/TR/wai-aria-1.1/#aria-colcount)'],
 ['[aria-colindex](https://www.w3.org/TR/wai-aria-1.1/#aria-colindex)'],
 ['[aria-colspan](https://www.w3.org/TR/wai-aria-1.1/#aria-colspan)'],
 ['[aria-controls](https://www.w3.org/TR/wai-aria-1.1/#aria-controls)'],
 ['[aria-current](https://www.w3.org/TR/wai-aria-1.1/#aria-current)'],
 ['[aria-describedby](https://www.w3.org/TR/wai-aria-1.1/#aria-describedby)'],
 ['[aria-details](https://www.w3.org/TR/wai-aria-1.1/#aria-details)'],
 ['[aria-disabled](https://www.w3.org/TR/wai-aria-1.1/#aria-disabled)'],
 ['[aria-dropeffect](https://www.w3.org/TR/wai-aria-1.1/#aria-dropeffect)'],
 ['[aria-errormessage](https://www.w3.org/TR/wai-aria-1.1/#aria-errormessage)'],
 ['[aria-expanded](https://www.w3.org/TR/wai-aria-1.1/#aria-expanded)'],
 ['[aria-flowto](https://www.w3.org/TR/wai-aria-1.1/#aria-flowto)'],
 ['[aria-grabbed](https://www.w3.org/TR/wai-aria-1.1/#aria-grabbed)'],
 ['[aria-haspopup](https://www.w3.org/TR/wai-aria-1.1/#aria-haspopup)'],
 ['[aria-hidden](https://www.w3.org/TR/wai-aria-1.1/#aria-hidden)'],
 ['[aria-invalid](https://www.w3.org/TR/wai-aria-1.1/#aria-invalid)'],
 ['[aria-keyshortcuts](https://www.w3.org/TR/wai-aria-1.1/#aria-keyshortcuts)'],
 ['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)'],
 ['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)'],
 ['[aria-level](https://www.w3.org/TR/wai-aria-1.1/#aria-level)'],
 ['[aria-live](https://www.w3.org/TR/wai-aria-1.1/#aria-live)'],
 ['[aria-modal](https://www.w3.org/TR/wai-aria-1.1/#aria-modal)'],
 ['[aria-multiline](https://www.w3.org/TR/wai-aria-1.1/#aria-multiline)'],
 ['[aria-multiselectable](https://www.w3.org/TR/wai-aria-1.1/#aria-multiselectable)'],
 ['[aria-orientation](https://www.w3.org/TR/wai-aria-1.1/#aria-orientation)'],
 ['[aria-owns](https://www.w3.org/TR/wai-aria-1.1/#aria-owns)'],
 ['[aria-placeholder](https://www.w3.org/TR/wai-aria-1.1/#aria-placeholder)'],
 ['[aria-posinset](https://www.w3.org/TR/wai-aria-1.1/#aria-posinset)'],
 ['[aria-pressed](https://www.w3.org/TR/wai-aria-1.1/#aria-pressed)'],
 ['[aria-readonly](https://www.w3.org/TR/wai-aria-1.1/#aria-readonly)'],
 ['[aria-relevant](https://www.w3.org/TR/wai-aria-1.1/#aria-relevant)'],
 ['[aria-required](https://www.w3.org/TR/wai-aria-1.1/#aria-required)'],
 ['[aria-roledescription](https://www.w3.org/TR/wai-aria-1.1/#aria-roledescription)'],
 ['[aria-rowcount](https://www.w3.org/TR/wai-aria-1.1/#aria-rowcount)'],
 ['[aria-rowindex](https://www.w3.org/TR/wai-aria-1.1/#aria-rowindex)'],
 ['[aria-rowspan](https://www.w3.org/TR/wai-aria-1.1/#aria-rowspan)'],
 ['[aria-selected](https://www.w3.org/TR/wai-aria-1.1/#aria-selected)'],
 ['[aria-setsize](https://www.w3.org/TR/wai-aria-1.1/#aria-setsize)'],
 ['[aria-sort](https://www.w3.org/TR/wai-aria-1.1/#aria-sort)'],
 ['[aria-valuemax](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemax)'],
 ['[aria-valuemin](https://www.w3.org/TR/wai-aria-1.1/#aria-valuemin)'],
 ['[aria-valuenow](https://www.w3.org/TR/wai-aria-1.1/#aria-valuenow)'],
 ['[aria-valuetext](https://www.w3.org/TR/wai-aria-1.1/#aria-valuetext)']
 and ['[role](struct.html#RoleAttribute)'].

Note that the above list of ARIA attributes may be expanded by future
WAI-ARIA specifications.

### 5.12.2. Role attribute
Any [renderable element](render.html#TermRenderableElement) may have an
ARIA role attribute specified; the role attribute is ignored on
[non-rendered elements](render.html#TermNonRenderedElement). The
attribute, if specified, must have a value that is a [set of
space-separated
tokens](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#set-of-space-separated-tokens)
representing the various WAI-ARIA roles that the element belongs to.
These tokens are role values defined in [Definition of
Roles](https://www.w3.org/TR/wai-aria-1.1/#role_definitions)
(\[[wai-aria](refs.html#ref-wai-aria)\], section 5.4) and [Graphics
Roles](https://www.w3.org/TR/graphics-aria-1.0/#roles)
(\[[graphics-aria-1.0](refs.html#ref-graphics-aria-1.0)\], section 4).

The WAI-ARIA role that an SVG element has assigned to it is the first
valid role found in the list of tokens generated when the role attribute
is split on spaces. A valid role is a recognized, non-abstract role that
is [allowed for the element type](#implicit-aria-semantics).

 Name Value Initial value Animatable
 --------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------- --------------- ------------
 [role] [set of space-separated tokens](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#set-of-space-separated-tokens) [\[HTML\]] (see below) no

The ['[role](struct.html#RoleAttribute)'] attribute must be
a [set of space-separated
tokens](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#set-of-space-separated-tokens)
having values defined in [Definition of
Roles](https://www.w3.org/TR/wai-aria-1.1/#role_definitions)
(\[[wai-aria](refs.html#ref-wai-aria)\], section 5.4).

The role value is a set of white-space separated machine-extractable
semantic information used to define the purpose of the element.

The [initial value](types.html#TermInitialValue) for the
['[role](struct.html#RoleAttribute)'] attribute, for each
SVG element, is the corresponding [default implied ARIA semantic for SVG
elements](#implicit-aria-semantics).

To be valid and useful, many element roles require additional
information to be provided in the form of an accessible name or explicit
[state and property values](#ARIAStateandPropertyAttributes). Accessible
names may be provided using SVG [descriptive
elements](struct.html#TermDescriptiveElement) or [ARIA
attributes](struct.html#TermARIAAttribute). The requirements for each
role are indicated where the role is defined, e.g., in
[WAI-ARIA](https://www.w3.org/TR/wai-aria-1.1/#role_definitions)
(\[[WAI-ARIA](refs.html#ref-wai-aria)\]) or the [WAI-ARIA Graphics
Module](https://www.w3.org/TR/graphics-aria-1.0/#roles)
(\[[graphics-aria-1.0](refs.html#ref-graphics-aria-1.0)\]).

### 5.12.3. State and property attributes (all aria- attributes)
WAI-ARIA state and property attributes may be specified on SVG elements.
These attributes are defined by ARIA in [Definitions of States and
Properties (all aria-\*
attributes)](https://www.w3.org/TR/wai-aria-1.1/#state_prop_def)
(\[[wai-aria](refs.html#ref-wai-aria)\], section 6.6).

These attributes, if specified, must have a value that is the WAI-ARIA
value type in the \"Value\" field of the definition for the state or
property, mapped to the appropriate SVG value type according to [Mapping
WAI-ARIA Value types to
languages](https://www.w3.org/TR/wai-aria-1.1/#typemapping) using the
SVG mapping (\[[wai-aria](refs.html#ref-wai-aria)\], section 10.2).

The attributes are animatable; if animation is used to change the state
of the graphic, or to change its content in a way that alters the
correct alternative text description, the same method of animation
should be used to update the corresponding ARIA state or property
attribute.

WAI-ARIA State and Property attributes can be used on any element. They
are not always meaningful, however, and in such cases user agents might
not perform any processing aside from including them in the DOM. State
and property attributes are processed according to the
[ARIA](https://www.w3.org/TR/wai-aria-1.1/) and [SVG Accessibility API
Mappings](https://www.w3.org/TR/svg-aam-1.0/) specification
specifications. \[[wai-aria](refs.html#ref-wai-aria)\]
\[[svg-aam-1.0](refs.html#ref-svg-aam-1.0)\]

### 5.12.4. Implicit and Allowed ARIA Semantics
The following table defines the default implicit ARIA semantics that
apply to [SVG elements](eltindex.html). Each language feature (element)
in a cell in the first column implies the ARIA semantics (role, states,
and/or properties) given in the cell in the second column of the same
row. The third column defines restrictions as to what WAI-ARIA semantic
(role, state, or property) may or may not apply.

For many graphics elements, an implicit role is only assigned if the
author provides information that indicates semantic importance. The
complete [inclusion criteria] for the accessibility tree are defined by the [SVG
Accessibility API Mappings](https://www.w3.org/TR/svg-aam-1.0/)
specification for user agents
\[[svg-aam-1.0](refs.html#ref-svg-aam-1.0)\]. For authors, the preferred
means of indicating semantic importance is to provide an accessible name
for the element. This can be done through a direct child
['[title](struct.html#TitleElement)'] element, or through
the
['[aria-label](https://www.w3.org/TR/wai-aria-1.1/#aria-label)']
or
['[aria-labelledby](https://www.w3.org/TR/wai-aria-1.1/#aria-labelledby)']
attributes. Authors should use one of these methods to provide an
accessible name for any content that is essential to the comprehension
of the SVG, and especially for any interactive content.

 Language feature Default implied ARIA semantics Allowed roles
 ----------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ------------------------
 ['[a](linking.html#AElement)'] `link`{title="attr-aria-role-link"} role if the element has a valid `href` or `xlink:href` attribute. For `a` elements that are not links, the default semantics are the same as `tspan` if the `a` element is a descendent of `text`, or the same as `g` otherwise. no restrictions
 ['[circle](shapes.html#CircleElement)'] `graphics-symbol` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)'] none no role may be applied
 ['[defs](struct.html#DefsElement)'] none no role may be applied
 ['[desc](struct.html#DescElement)'] none no role may be applied
 ['[ellipse](shapes.html#EllipseElement)'] `graphics-symbol` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[feBlend](https://drafts.csswg.org/filter-effects-1/#feBlendElement)'] none no role may be applied
 ['[feColorMatrix](https://drafts.csswg.org/filter-effects-1/#feColorMatrixElement)'] none no role may be applied
 ['[feComponentTransfer](https://drafts.csswg.org/filter-effects-1/#feComponentTransferElement)'] none no role may be applied
 ['[feComposite](https://drafts.csswg.org/filter-effects-1/#feCompositeElement)'] none no role may be applied
 ['[feConvolveMatrix](https://drafts.csswg.org/filter-effects-1/#feConvolveMatrixElement)'] none no role may be applied
 ['[feDiffuseLighting](https://drafts.csswg.org/filter-effects-1/#feDiffuseLightingElement)'] none no role may be applied
 ['[feDisplacementMap](https://drafts.csswg.org/filter-effects-1/#feDisplacementMapElement)'] none no role may be applied
 ['[feDistantLight](https://drafts.csswg.org/filter-effects-1/#feDistantLightElement)'] none no role may be applied
 ['[feDropShadow](https://drafts.csswg.org/filter-effects-1/#feDropShadowElement)'] none no role may be applied
 ['[feFlood](https://drafts.csswg.org/filter-effects-1/#feFloodElement)'] none no role may be applied
 ['[feFuncA](https://drafts.csswg.org/filter-effects-1/#feFuncAElement)'] none no role may be applied
 ['[feFuncB](https://drafts.csswg.org/filter-effects-1/#feFuncBElement)'] none no role may be applied
 ['[feFuncG](https://drafts.csswg.org/filter-effects-1/#feFuncGElement)'] none no role may be applied
 ['[feFuncR](https://drafts.csswg.org/filter-effects-1/#feFuncRElement)'] none no role may be applied
 ['[feGaussianBlur](https://drafts.csswg.org/filter-effects-1/#feGaussianBlurElement)'] none no role may be applied
 ['[feImage](https://drafts.csswg.org/filter-effects-1/#feImageElement)'] none no role may be applied
 ['[feMerge](https://drafts.csswg.org/filter-effects-1/#feMergeElement)'] none no role may be applied
 ['[feMergeNode](https://drafts.csswg.org/filter-effects-1/#feMergeElement)'] none no role may be applied
 ['[feMorphology](https://drafts.csswg.org/filter-effects-1/#feMorphologyElement)'] none no role may be applied
 ['[feOffset](https://drafts.csswg.org/filter-effects-1/#feOffsetElement)'] none no role may be applied
 ['[fePointLight](https://drafts.csswg.org/filter-effects-1/#fePointLightElement)'] none no role may be applied
 ['[feSpecularLighting](https://drafts.csswg.org/filter-effects-1/#feSpecularLightingElement)'] none no role may be applied
 ['[feSpotLight](https://drafts.csswg.org/filter-effects-1/#feSpotLightElement)'] none no role may be applied
 ['[feTile](https://drafts.csswg.org/filter-effects-1/#feTileElement)'] none no role may be applied
 ['[feTurbulence](https://drafts.csswg.org/filter-effects-1/#feTurbulenceElement)'] none no role may be applied
 ['[filter](https://drafts.csswg.org/filter-effects-1/#FilterElement)'] none no role may be applied
 ['[foreignObject](embedded.html#ForeignObjectElement)'] `group` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[g](struct.html#GElement)'] `group` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[image](embedded.html#ImageElement)'] `img`{title="attr-aria-role-img"} role no restrictions
 ['[line](shapes.html#LineElement)'] `graphics-symbol` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[linearGradient](pservers.html#LinearGradientElement)'] none no role may be applied
 ['[marker](painting.html#MarkerElement)'] none no role may be applied
 ['[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)'] none no role may be applied
 ['[metadata](struct.html#MetadataElement)'] none no role may be applied
 ['[mpath](https://w3c.github.io/svgwg/specs/animations/#MPathElement)'] none no role may be applied
 ['[path](paths.html#PathElement)'] `graphics-symbol` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[pattern](pservers.html#PatternElement)'] none no role may be applied
 ['[polygon](shapes.html#PolygonElement)'] `graphics-symbol` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[polyline](shapes.html#PolylineElement)'] `graphics-symbol` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[radialGradient](pservers.html#RadialGradientElement)'] none no role may be applied
 ['[rect](shapes.html#RectElement)'] `graphics-symbol` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[script](interact.html#ScriptElement)'] none no role may be applied
 ['[stop](pservers.html#StopElement)'] none no role may be applied
 ['[style](styling.html#StyleElement)'] none no role may be applied
 ['[svg](struct.html#SVGElement)'] `graphics-document` role no restrictions
 ['[switch](struct.html#SwitchElement)'] none no role may be applied
 ['[symbol](struct.html#SymbolElement)'] `graphics-object` role if the element is a rendered [element instance](struct.html#TermElementInstance) that meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[text](text.html#TextElement)'] `group`role, with platform-specific role mappings, as defined in the [SVG Accessibility API Mappings](https://w3c.github.io/svg-aam/#details-id-69) specification no restrictions
 ['[textPath](text.html#TextPathElement)'] `group` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[title](struct.html#TitleElement)'] none no role may be applied
 ['[tspan](text.html#TextElement)'] `group` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[use](struct.html#UseElement)'] `graphics-object` role if the element meets the [inclusion criteria](struct.html#TermInclusionCriteria), otherwise `none` no restrictions
 ['[view](linking.html#ViewElement)'] none no role may be applied

## 5.13. DOM interfaces
:::::: ready-for-wider-review
### 5.13.1. Extensions to the Document interface
The DOM Core specification defines a
[Document](https://dom.spec.whatwg.org/#interface-document)
interface, which this specification extends.

In the case where an SVG document is embedded by reference, such as when
an HTML document has an ['object'] element whose
['data'] attribute references an SVG document (i.e., a
document whose MIME type is \"image/svg+xml\" and whose root element is
thus an ['[svg](struct.html#SVGElement)'] element), there
will exist two distinct DOM hierarchies. The first DOM hierarchy will be
for the referencing document (e.g., an XHTML document). The second DOM
hierarchy will be for the referenced SVG document.

``` idl
partial interface Document {
 readonly attribute SVGSVGElement? rootElement;
};
```

The **rootElement** IDL attribute represents the root
['[svg](struct.html#SVGElement)'] element. On getting
[rootElement](#__svg__SVGDocument__rootElement), the root element of the
document is returned, if it is an
['[svg](struct.html#SVGElement)'] element, or null
otherwise.

This attribute is deprecated, and may be removed in a future SVG
specification. Authors are encouraged to use the
[documentElement](https://www.w3.org/TR/dom/#dom-document-documentelement)
attribute on
[Document](https://dom.spec.whatwg.org/#interface-document)
instead.

SVG implementations that implement HTML must support the [HTML
extensions to the document
interface](https://html.spec.whatwg.org/multipage/dom.html#the-document-object).
Other SVG implementations must support the following IDL fragment.

```
// must only be implemented in certain implementations
partial interface Document {
 readonly attribute DOMString title;
 readonly attribute DOMString referrer;
 readonly attribute DOMString domain;
 readonly attribute Element? activeElement;
};
```

The title, referrer, domain and
[activeElement] IDL attributes must
behave the same as [the corresponding IDL attributes defined in
HTML](https://html.spec.whatwg.org/multipage/dom.html#the-document-object).

### 5.13.2. Interface SVGSVGElement
An [SVGSVGElement](struct.html#InterfaceSVGSVGElement)
object represents an ['[svg](struct.html#SVGElement)']
element in the DOM. The
[SVGSVGElement](struct.html#InterfaceSVGSVGElement)
interface also contains miscellaneous utility methods, such as data type
object factory methods.

An [SVGSVGElement](struct.html#InterfaceSVGSVGElement)
object maintains an internal
[SVGPoint](https://drafts.csswg.org/geometry-1/#dompoint)
object, called its [current translate point
object],
which is the object returned from the
[currentTranslate](#__svg__SVGSVGElement__currentTranslate) IDL
attribute.

``` idl
[Exposed=Window]
interface SVGSVGElement : SVGGraphicsElement {

 [SameObject] readonly attribute SVGAnimatedLength x;
 [SameObject] readonly attribute SVGAnimatedLength y;
 [SameObject] readonly attribute SVGAnimatedLength width;
 [SameObject] readonly attribute SVGAnimatedLength height;

 attribute float currentScale;
 [SameObject] readonly attribute SVGPoint currentTranslate;

 NodeList getIntersectionList(SVGRect rect, SVGElement? referenceElement);
 NodeList getEnclosureList(SVGRect rect, SVGElement? referenceElement);
 boolean checkIntersection(SVGElement element, SVGRect rect);
 boolean checkEnclosure(SVGElement element, SVGRect rect);

 undefined deselectAll();

 [NewObject] SVGNumber createSVGNumber();
 [NewObject] SVGLength createSVGLength();
 [NewObject] SVGAngle createSVGAngle();
 [NewObject] SVGPoint createSVGPoint();
 [NewObject] SVGMatrix createSVGMatrix();
 [NewObject] SVGRect createSVGRect();
 [NewObject] SVGTransform createSVGTransform();
 [NewObject] SVGTransform createSVGTransformFromMatrix(optional DOMMatrix2DInit matrix = );

 Element? getElementById(DOMString elementId);

 // Deprecated methods that have no effect when called,
 // but which are kept for compatibility reasons.
 unsigned long suspendRedraw(unsigned long maxWaitMilliseconds);
 undefined unsuspendRedraw(unsigned long suspendHandleID);
 undefined unsuspendRedrawAll();
 undefined forceRedraw();
};

SVGSVGElement includes SVGFitToViewBox;
SVGSVGElement includes WindowEventHandlers;
```

The **x**, **y**, **width** and **height** IDL attributes
[reflect](types.html#TermReflect) the computed values of the
[x](geometry.html#XProperty),
[y](geometry.html#YProperty),
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) properties and their
corresponding presentation attributes, respectively.

The **currentScale** and **currentTranslate** IDL attributes represent
an additional transform applied to the SVG. They only have an effect on
the [outermost svg element](struct.html#TermOutermostSVGElement) of an
[SVG document fragment](struct.html#TermSVGDocumentFragment).

The document\'s magnification and panning transform is a 2x3 matrix of
the form
`[currentScale 0 0 currentScale currentTranslate.x currentTranslate.y]`.
The value of the
['[transform](coords.html#TransformProperty)'] property does
not affect [currentScale](#__svg__SVGSVGElement__currentScale) or
[currentTranslate](#__svg__SVGSVGElement__currentTranslate).

Previous versions of SVG recommended that user agents implement
controls, by default, for the user to set the scale (zoom) and translate
(pan) of the graphic. Transformations from these user actions *would* be
reflected in the values of `currentScale` and `currentTranslate`. These
user controls were not well implemented, and are no longer recommended.
However, authors should be aware that the user agent may update these
values.

The obsolete attribute `zoomAndPan="disable"`, on the outermost SVG
element, should disable any user agent manipulation of the values based
on user action, but may have unwanted side effects in some user agents.

The interaction of currentScale and
currentTranslate with other ways of transforming the document root
(transforms and SVG views) is poorly defined. See the [GitHub
issue](https://github.com/w3c/svgwg/issues/360) for more.

On getting [currentScale](#__svg__SVGSVGElement__currentScale), the
following steps are run:

1. If the current ['[svg](struct.html#SVGElement)']
 element is not the [outermost svg
 element](struct.html#TermOutermostSVGElement), then return 1.
2. Let \[`a` `b` `c` `d`
 `e` `f`\] be the 2x3 matrix that represents
 the document\'s magnification and panning transform.
3. Return `a`.

On setting [currentScale](#__svg__SVGSVGElement__currentScale), the
following steps are run:

1. If the current ['[svg](struct.html#SVGElement)']
 element is not the [outermost svg
 element](struct.html#TermOutermostSVGElement), then return.
2. Let `scale` be the value being assigned to
 [currentScale](#__svg__SVGSVGElement__currentScale).
3. Let \[`a` `b` `c` `d`
 `e` `f`\] be the 2x3 matrix that represents
 the document\'s magnification and panning transform.
4. Set the document\'s magnification and panning transform to
 \[`scale` 0 0 `scale` `e`
 `f`\].

On getting [currentTranslate](#__svg__SVGSVGElement__currentTranslate),
the [SVGSVGElement](struct.html#InterfaceSVGSVGElement)
object\'s [current translate point object](#CurrentTranslatePointObject)
is returned. This object [represents the current
translation](shapes.html#PointMode) for the
['[svg](struct.html#SVGElement)'] element. A [current
translate point object](#CurrentTranslatePointObject) must be [read
only](shapes.html#ReadOnlyPoint) when its
['[svg](struct.html#SVGElement)'] element is not the
[outermost svg element](struct.html#TermOutermostSVGElement), and
writable otherwise.

See the rules for [assigning to a
SVGPoint](shapes.html#AssignToDOMPoint) for how modifying the [current
translate point object](#CurrentTranslatePointObject) affects the
document\'s magnification and panning transform.

Whenever the document\'s magnification and panning transform changes in
response to user interaction or whenever the [outermost svg
element](struct.html#TermOutermostSVGElement) changes, the following
steps are run:

1. Let \[`a` `b` `c` `d`
 `e` `f`\] be the 2x3 matrix that represents
 the document\'s magnification and panning transform.
2. Let `element` be the [outermost svg
 element](struct.html#TermOutermostSVGElement).
3. Update the x and y components of `element`\'s [current
 translate point object](#CurrentTranslatePointObject) to
 `e` and `f`, respectively.

Running these steps when the [outermost svg
element](struct.html#TermOutermostSVGElement) changes will ensure that
if the document element is replaced with a different
['[svg](struct.html#SVGElement)'] element, that its
[currentTranslate](#__svg__SVGSVGElement__currentTranslate) will be
immediately updated to reflect the translation component of the
document\'s magnification and panning transform.

Whenever an ['[svg](struct.html#SVGElement)'] element is
no longer [outermost svg element](struct.html#TermOutermostSVGElement),
the x and y components of its [current translate point
object](#CurrentTranslatePointObject) must be set to 0.

The **suspendRedraw**, **unsuspendRedraw**, **unsuspendRedrawAll** and
**forceRedraw** methods are all deprecated and defined to have no
effect. When the suspendRedraw method is called, it must return 1.

The **getIntersectionList**, **getEnclosureList**, **checkIntersection**
and **checkEnclosure** methods are used to perform geometry operations
on [graphics elements](struct.html#TermGraphicsElement) to find those
whose (or check whether their) graphical content lies partially or
completely within a given rectangle.

To [find the intersecting or enclosed
descendants] of a given element `element` with a
given rectangle `rectangle` using `ancestor` as
the element in whose coordinate space `rectangle` is to be
interpreted, the following steps are run:

1. Let `result` be an initially empty list.
2. If `element` is not displayed, due to having a
 [display](render.html#VisibilityControl) value of
 [none] or being in a subtree that has failing
 [conditional processing
 attributes](struct.html#TermConditionalProcessingAttribute) or a
 failing branch of a
 ['[switch](struct.html#SwitchElement)'], then return
 `result`.
3. For each child element `child` of `element`,
 in document order:
 1. If `child` is an
 ['[svg](struct.html#SVGElement)'] or
 ['[g](struct.html#GElement)'] element, then:
 1. Let `descendants` be the result of [finding the
 intersecting (or enclosed)
 descendants](#TermFindIntersectingOrEnclosedDescendants) of
 `child` with `rectangle` in
 `ancestor`\'s coordinate space.
 2. Append to `result` all the elements of
 `descendants`.
 2. Otherwise, if `child` is a
 ['[use](struct.html#UseElement)'] element, then:
 1. Let `root` be the root of the
 `child`\'s shadow tree.

 2. Let `descendants` be the result of [finding the
 intersecting (or enclosed)
 descendants](#TermFindIntersectingOrEnclosedDescendants) of
 `root` with `rectangle` in
 `ancestor`\'s coordinate space.

 3. If `descendants` is not empty, then append
 `child` to `result`.

 This means that although we look at the elements in the
 [use-element shadow
 tree](struct.html#TermUseElementShadowTree), we don\'t place
 the [element instances](struct.html#TermElementInstance) or
 their source elements in the [referenced document
 subtree](struct.html#TermReferencedDocumentSubtree) in the
 `result` list; only the
 ['[use](struct.html#UseElement)'] element
 itself is returned.
 3. Otherwise, if `child` is a [graphics
 element](struct.html#TermGraphicsElement), then:
 1. Let `region` be the shape in
 `child`\'s coordinate system that is sensitive to
 hit detection, taking into account the rules for
 interpreting `child`\'s
 [pointer-events](interact.html#PointerEventsProperty)
 value.
 2. Transform `region` into `ancestor`\'s
 coordinate system.
 3. If we are finding intersecting descendants and
 `region` lies partially or fully within
 `rectangle`, then append `child` to
 `result`.
 4. Otherwise, we are finding enclosed descendants. If
 `region` lies fully within
 `rectangle`, then append `child` to
 `result`.
4. Return `result`.

To [find the non-container graphics
elements] within a given element `element`, the following
steps are run:

1. Let `result` be an initially empty list.
2. If `element` is an
 ['[svg](struct.html#SVGElement)'] or
 ['[g](struct.html#GElement)'] element, then for each
 child element `child` of `element`, in
 document order:
 1. Let `descendants` be the result of [finding the
 non-container graphics
 elements](#TermFindNonContainerGraphicsElements) within
 `child`.
 2. Append to `result` all the elements of
 `descendants`.
3. Otherwise, if `element` is a [graphics
 element](struct.html#TermGraphicsElement) then append
 `element` to `result`.
4. Return `result`.

When getIntersectionList(`rect`,
`referenceElement`) or getEnclosureList(`rect`,
`referenceElement`) is called, the following steps are run:

1. Let `descendants` be a list, depending on what method we
 are in:

 [getIntersectionList](#__svg__SVGSVGElement__getIntersectionList)
 : `descendants` is the result of [finding the
 intersecting
 descendants](#TermFindIntersectingOrEnclosedDescendants) of the
 current ['[svg](struct.html#SVGElement)'] element
 with rectangle `rect` in the current
 ['[svg](struct.html#SVGElement)'] element\'s
 coordinate system.

 [getEnclosureList](#__svg__SVGSVGElement__getEnclosureList)
 : `descendants` is the result of [finding the enclosed
 descendants](#TermFindIntersectingOrEnclosedDescendants) of the
 current ['[svg](struct.html#SVGElement)'] element
 with rectangle `rect` in the current
 ['[svg](struct.html#SVGElement)'] element\'s
 coordinate system.
2. If `referenceElement` is not null, then remove from
 `descendants` any element that does not have
 `referenceElement` as an ancestor.
3. Return a
 [static](https://www.w3.org/TR/dom/#concept-collection-static)
 [NodeList](https://dom.spec.whatwg.org/#interface-nodelist)
 that contains all of the elements in `descendants`.
 (\[[DOM](refs.html#ref-dom)\], section 5.2.7)

When checkIntersection(`element`, `rect`) or
checkEnclosure(`element`, `rect`) is called, the
following steps are run:

1. Let `descendants` be a list, depending on what method we
 are in:

 [getIntersectionList](#__svg__SVGSVGElement__getIntersectionList)
 : `descendants` is the result of [finding the
 intersecting
 descendants](#TermFindIntersectingOrEnclosedDescendants) of the
 current ['[svg](struct.html#SVGElement)'] element
 with rectangle `rect` in the current
 ['[svg](struct.html#SVGElement)'] element\'s
 coordinate system.

 [getEnclosureList](#__svg__SVGSVGElement__getEnclosureList)
 : `descendants` is the result of [finding the enclosed
 descendants](#TermFindIntersectingOrEnclosedDescendants) of the
 current ['[svg](struct.html#SVGElement)'] element
 with rectangle `rect` in the current
 ['[svg](struct.html#SVGElement)'] element\'s
 coordinate system.
2. Let `elements` be the result of [finding the
 non-container graphics
 elements](#TermFindNonContainerGraphicsElements) within
 `element`.
3. If `elements` is empty, then return false.
4. If any element in `elements` is not also in
 `descendants`, then return false.
5. Return true.

::: ready-for-wider-review
The **deselectAll** method is used to remove any selections from the
document. When deselectAll() is called, all
[ranges](https://www.w3.org/TR/2014/WD-dom-20140204/#concept-range) from
the document\'s
[selection](https://w3c.github.io/selection-api/#dom-selection) are
removed and the
[selection](https://w3c.github.io/selection-api/#dom-selection)\'s
[direction](https://w3c.github.io/selection-api/#dfn-direction) is set
to forwards.
\[[DOM](refs.html#ref-dom)\]\[[EDITING](refs.html#ref-editing)\] This
method is deprecated, as it duplicates functionality from the Selection
API.

This is equivalent to calling
`document.getSelection().removeAllRanges()` on the document that this
['[svg](struct.html#SVGElement)'] element is in.

The **createSVGNumber**, **createSVGLength**, **createSVGAngle**,
**createSVGPoint**, **createSVGMatrix**, **createSVGRect** and
**createSVGTransform** methods are all factory functions used to create
a new datatype object of a particular type. When one of these methods is
called, a new object is returned according to the following table:

 Method Object and details
 ----------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [createSVGNumber](#__svg__SVGSVGElement__createSVGNumber) A new, [detached](types.html#NumberMode) [SVGNumber](types.html#InterfaceSVGNumber) object whose value is 0.
 [createSVGLength](#__svg__SVGSVGElement__createSVGLength) A new, [detached](types.html#LengthMode) [SVGLength](types.html#InterfaceSVGLength) object whose value is the unitless [\<number\>](https://www.w3.org/TR/css3-values/#numbers) 0.
 [createSVGAngle](#__svg__SVGSVGElement__createSVGAngle) A new, [detached](types.html#AngleMode) [SVGAngle](types.html#InterfaceSVGAngle) object whose value is the unitless [\<number\>](https://www.w3.org/TR/css3-values/#numbers) 0.
 [createSVGPoint](#__svg__SVGSVGElement__createSVGPoint) A new, [detached](shapes.html#PointMode) [SVGPoint](https://drafts.csswg.org/geometry-1/#dompoint) object whose coordinates are all 0.
 [createSVGMatrix](#__svg__SVGSVGElement__createSVGMatrix) A new, [detached](coords.html#MatrixMode) [SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix) object representing the identity matrix.
 [createSVGRect](#__svg__SVGSVGElement__createSVGRect) A new, [SVGRect](https://drafts.csswg.org/geometry-1/#domrect) object whose x, y, width and height are all 0.
 [createSVGTransform](#__svg__SVGSVGElement__createSVGTransform) A new, [detached](coords.html#TransformMode) [SVGTransform](coords.html#InterfaceSVGTransform) object whose value is [matrix(1, 0, 0, 1, 0, 0)].

The [createSVGPoint](#__svg__SVGSVGElement__createSVGPoint),
[createSVGMatrix](#__svg__SVGSVGElement__createSVGMatrix) and
[createSVGRect](#__svg__SVGSVGElement__createSVGRect) methods are all
deprecated and kept only for compatibility with legacy content. Authors
are encouraged to use the
[SVGPoint](https://drafts.csswg.org/geometry-1/#dompoint),
[SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)
and
[SVGRect](https://drafts.csswg.org/geometry-1/#domrect)
constructors instead.

The **createSVGTransformFromMatrix** method is used to create a new
[SVGTransform](coords.html#InterfaceSVGTransform) object
from a matrix object. Its behavior is the same as the
[createSVGTransformFromMatrix](coords.html#__svg__SVGTransformList__createSVGTransformFromMatrix)
method on
[SVGTransformList](coords.html#InterfaceSVGTransformList).

::: ready-for-wider-review
The **getElementById** method, must return the first element in [tree
order](https://dom.spec.whatwg.org/#concept-tree-order), within the
['[svg](struct.html#SVGElement)'] element\'s descendants,
whose ID is `elementId`, or null if there is no such element.

### 5.13.3. Interface SVGGElement
An [SVGGElement](struct.html#InterfaceSVGGElement) object
represents a ['[g](struct.html#GElement)'] element in the
DOM.

``` idl
[Exposed=Window]
interface SVGGElement : SVGGraphicsElement ;
```

### 5.13.4. Interface SVGDefsElement
An [SVGDefsElement](struct.html#InterfaceSVGDefsElement)
object represents a ['[defs](struct.html#DefsElement)']
element in the DOM.

``` idl
[Exposed=Window]
interface SVGDefsElement : SVGGraphicsElement ;
```

### 5.13.5. Interface SVGDescElement
An [SVGDescElement](struct.html#InterfaceSVGDescElement)
object represents a ['[desc](struct.html#DescElement)']
element in the DOM.

``` idl
[Exposed=Window]
interface SVGDescElement : SVGElement ;
```

### 5.13.6. Interface SVGMetadataElement
An
[SVGMetadataElement](struct.html#InterfaceSVGMetadataElement)
object represents a
['[metadata](struct.html#MetadataElement)'] element in
the DOM.

``` idl
[Exposed=Window]
interface SVGMetadataElement : SVGElement ;
```

### 5.13.7. Interface SVGTitleElement
An
[SVGTitleElement](struct.html#InterfaceSVGTitleElement)
object represents a ['[title](struct.html#TitleElement)']
element in the DOM.

``` idl
[Exposed=Window]
interface SVGTitleElement : SVGElement ;
```

### 5.13.8. Interface SVGSymbolElement
An
[SVGSymbolElement](struct.html#InterfaceSVGSymbolElement)
object represents a
['[symbol](struct.html#SymbolElement)'] element in the
DOM.

``` idl
[Exposed=Window]
interface SVGSymbolElement : SVGGraphicsElement ;

SVGSymbolElement includes SVGFitToViewBox;
```

New in SVG 2. The
[SVGSymbolElement](struct.html#InterfaceSVGSymbolElement)
interface now inherits from
[SVGGraphicsElement](types.html#InterfaceSVGGraphicsElement),
so that the instantiated symbol in the shadow DOM can be queried as a
graphics element.

### 5.13.9. Interface SVGUseElement
An [SVGUseElement](struct.html#InterfaceSVGUseElement)
object represents a ['[use](struct.html#UseElement)']
element in the DOM.

``` idl
[Exposed=Window]
interface SVGUseElement : SVGGraphicsElement {
 [SameObject] readonly attribute SVGAnimatedLength x;
 [SameObject] readonly attribute SVGAnimatedLength y;
 [SameObject] readonly attribute SVGAnimatedLength width;
 [SameObject] readonly attribute SVGAnimatedLength height;
};

SVGUseElement includes SVGURIReference;
```

The **x**, **y**, **width** and **height** IDL attributes
[reflect](types.html#TermReflect) the computed values of the
[x](geometry.html#XProperty),
[y](geometry.html#YProperty),
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) properties and their
corresponding presentation attributes, respectively.

### 5.13.10. Interface SVGUseElementShadowRoot
The root object of each [use-element shadow
tree](struct.html#TermUseElementShadowTree) implements the
[SVGUseElementShadowRoot](struct.html#InterfaceSVGUseElementShadowRoot)
interface. This interface does not currently define any extensions to
the properties and methods defined for the
[ShadowRoot](https://dom.spec.whatwg.org/#interface-shadowroot)
interface and
[DocumentOrShadowRoot](https://dom.spec.whatwg.org/#mixin-documentorshadowroot)
mixin. However, the tree rooted at this node is entirely read-only from
the perspective of author scripts.

``` idl
[Exposed=Window]
interface SVGUseElementShadowRoot : ShadowRoot ;
```

### 5.13.11. Interface ShadowAnimation
The
[ShadowAnimation](struct.html#InterfaceShadowAnimation)
interface defines a read-only
[Animation](https://www.w3.org/TR/web-animations-1/#the-animation-interface)
object, which mirrors all changes to the
[sourceAnimation](struct.html#__svg__ShadowAnimation__sourceAnimation)
object from which it was constructed. They are used to mirror
author-initiated animation objects in the [use-element shadow
tree](struct.html#TermUseElementShadowTree).

``` idl
[Exposed=Window]
interface ShadowAnimation : Animation {
 constructor(Animation source, (Element or CSSPseudoElement) newTarget);
 [SameObject] readonly attribute Animation sourceAnimation;
};
```

The **sourceAnimation** IDL property points to the
[Animation](https://www.w3.org/TR/web-animations-1/#the-animation-interface)
object passed in the constructor.

The constructor generates a new
[ShadowAnimation](struct.html#InterfaceShadowAnimation)
object, which reflects all properties on the
[sourceAnimation](struct.html#__svg__ShadowAnimation__sourceAnimation),
except that its
[`effect`](https://www.w3.org/TR/web-animations-1/#dom-animation-effect)
is created by constructing a new
[`KeyframeEffectReadOnly`](https://www.w3.org/TR/web-animations-1/#keyframeeffectreadonly)
using the keyframe effect of the
[sourceAnimation](struct.html#__svg__ShadowAnimation__sourceAnimation)
as its source, and then modifying its
[`target`](https://www.w3.org/TR/web-animations-1/#dom-keyframeeffectreadonly-target)
to match the `newTarget` parameter.

A [ShadowAnimation](struct.html#InterfaceShadowAnimation)
is read-only. Any attempt to set any of the inherited IDL properties, or
call any of the
[Animation](https://www.w3.org/TR/web-animations-1/#the-animation-interface)
methods that change its state, must throw a
`NoModificationAllowedError`. However, the user agent must ensure that
any changes to the properties or state of the
[sourceAnimation](struct.html#__svg__ShadowAnimation__sourceAnimation)
are reflected in changes to the
[ShadowAnimation](struct.html#InterfaceShadowAnimation).

### 5.13.12. Interface SVGSwitchElement
An
[SVGSwitchElement](struct.html#InterfaceSVGSwitchElement)
object represents a
['[switch](struct.html#SwitchElement)'] element in the
DOM.

``` idl
[Exposed=Window]
interface SVGSwitchElement : SVGGraphicsElement ;
```

### 5.13.13. Mixin GetSVGDocument
This interface provides access to an SVG document embedded by reference
in another DOM-based language. The expectation is that the interface is
implemented on DOM objects that allow such SVG document references.

This interface is deprecated and may be dropped from future versions of
the SVG specification. To access the SVG document inside an
['iframe'] or ['object'] element, authors
are suggested to use the `contentDocument` attribute on the
[HTMLIFrameElement](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#htmliframeelement)
or
[HTMLObjectElement](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#htmlobjectelement)
interface, respectively.

The
[HTMLIFrameElement](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#htmliframeelement),
[HTMLEmbedElement](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#htmlembedelement)
and
[HTMLObjectElement](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#htmlobjectelement)
interfaces all define their own getSVGDocument method, which provides
access to the SVG document in the same way that the
[GetSVGDocument](struct.html#InterfaceGetSVGDocument)
does. Those three interfaces therefore do not need to implement
[GetSVGDocument](struct.html#InterfaceGetSVGDocument).
Still, authors are strongly recommended to use contentDocument instead.

``` idl
interface mixin GetSVGDocument {
 Document getSVGDocument();
};
```

The **getSVGDocument** method is used to return a referenced SVG
document. When getSVGDocument() is called, it must return the
[Document](https://dom.spec.whatwg.org/#interface-document)
object referenced by the embedding element that implements the
[GetSVGDocument](struct.html#InterfaceGetSVGDocument)
interface; if there is no document, null is returned.

Note that this does no check to see whether the referenced document is
indeed an SVG document. Instead, any document is returned.
