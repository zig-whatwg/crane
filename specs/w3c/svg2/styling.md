# Chapter 6: Styling

::: }}
[Overview](Overview.html) · [Previous](struct.html) ·
[Next](geometry.html) · [Elements](eltindex.html) ·
[Attributes](attindex.html) · [Properties](propidx.html)

## Contents

1. 1. [[6.1.] Styling SVG content using
 CSS](styling.html#StylingUsingCSS)
 2. [[6.2.] Inline style sheets: the
 ['style'] element](styling.html#StyleElement)
 3. [[6.3.] External style sheets: the effect of the HTML
 ['link'] element](styling.html#LinkElement)
 4. [[6.4.] Style sheets in HTML
 documents](styling.html#StyleSheetsInHTMLDocuments)
 5. [[6.5.] Element-specific styling: the
 ['class'] and ['style']
 attributes](styling.html#ElementSpecificStyling)
 6. [[6.6.] Presentation
 attributes](styling.html#PresentationAttributes)
 7. [[6.7.] Required
 properties](styling.html#RequiredProperties)
 8. [[6.8.] User agent style
 sheet](styling.html#UAStyleSheet)
 9. [[6.9.] Required CSS
 features](styling.html#RequiredCSSFeatures)
 10. [[6.10.] DOM interfaces](styling.html#DOMInterfaces)
 1. [[6.10.1.] Interface
 SVGStyleElement](styling.html#InterfaceSVGStyleElement)

## 6.1. Styling SVG content using CSS
Elements in an SVG document can be styled using CSS. Most visual
characteristics and some aspects of element geometry are controlled
using CSS [properties]. For example,
the [fill](painting.html#FillProperty) property controls the
paint used to fill the inside of a shape, and the
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) properties are used to control
the size of a ['[rect](shapes.html#RectElement)']
element.

SVG user agents must support all of the CSS styling mechanisms described
in this chapter.

In SVG 1.1, support for inline style sheets using the
['[style](styling.html#StyleElement)'] element and
['[style](styling.html#StyleAttribute)'] was not required.
In SVG 2, these are required.

## 6.2. Inline style sheets: the ['style'] element
 -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Add HTML5 ['style'] element attributes to SVG\'s ['[style](styling.html#StyleElement)'] element.
 Resolution: [SVG 2 ['style'] element shall be aligned with the HTML5 ['style'] element.](http://www.w3.org/2011/10/28-svg-irc#T18-45-45)
 Purpose: To not surprise authors with different behavior for the ['style'] element in HTML and SVG content.
 Owner: Cameron ([ACTION-3277](http://www.w3.org/Graphics/SVG/WG/track/actions/3277))
 -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------

The ['[style](styling.html#StyleElement)'] element allows
style sheets to be embedded directly within SVG content. SVG\'s
['[style](styling.html#StyleElement)'] element has the
same attributes as the [corresponding element in
HTML](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element).

:::: element-summary
::: element-summary-name
['[style]']

Categories:
: [Never-rendered element](render.html#TermNeverRenderedElement)

Content model:
: Character data.

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
 - ['[type](styling.html#StyleElementTypeAttribute)']
 - ['[media](styling.html#StyleElementMediaAttribute)']
 - ['[title](styling.html#StyleElementTitleAttribute)']

DOM Interfaces:

: - [SVGStyleElement](styling.html#InterfaceSVGStyleElement)

*Attribute definitions:*

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------------- ------------- --------------- ------------
 [type] (see below) text/css no

This attribute specifies the style sheet language of the element\'s
contents, as a [media type](http://www.ietf.org/rfc/rfc2046.txt).
\[[rfc2046](refs.html#ref-rfc2046)\]. If the attribute is not specified,
then the style sheet language is assumed to be CSS.

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------------------- ------------- --------------- ------------
 [media] (see below) all no

This attribute specifies a media query that must be matched for the
style sheet to apply. Its value is parsed as a
[media_query_list](https://www.w3.org/TR/css3-mediaqueries/#syntax). If
not specified, the style sheet applies unconditionally.

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------------------- ------------- --------------- ------------
 [title] (see below) (none) no

This attribute specifies a title for the style sheet, which is used when
exposing and selecting between alternate style sheets. The attribute
takes any value.

The semantics and processing of a
['[style](styling.html#StyleElement)'] and its attributes
must be the same as is defined for the [HTML ['style']
element](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element).

The style sheet\'s text content is never directly rendered; the
[display](render.html#VisibilityControl) value for the
['[style](styling.html#StyleElement)'] element must
always be set to [none] by the [user agent style
sheet](styling.html#UAStyleSheet), and this declaration must have
importance over any other CSS rule or presentation attribute.

## 6.3. External style sheets: the effect of the HTML ['link'] element
An [HTML ['link']
element](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element)
in an SVG document (that is, an element in the HTML namespace with local
name \"link\") with its ['rel'] attribute set to
[\'stylesheet\'] must be processed as defined in the HTML
specification and cause external style sheets to be loaded and applied
to the document. Such elements in HTML documents outside of an inline
SVG fragment must also apply to the SVG content.

Because the element is required to be in the HTML namespace, it is not
possible for an [HTML ['link']
element](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element)
to be parsed as part of an inline SVG fragment in a text/html document.
However, when parsing an SVG document using XML syntax, XML namespace
declarations can be used to place the element in the HTML namespace.

Note that an alternative way to reference external style sheets without
using the [HTML ['link']
element](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element)
is to use an \@import rule in an inline style sheet. For example:

 <svg xmlns="http://www.w3.org/2000/svg">
 <style>
 @import url(mystyles.css);
 </style>
 <rect .../>
 </svg>

would behave similarly to:

 <svg xmlns="http://www.w3.org/2000/svg">
 <link xmlns="http://www.w3.org/1999/xhtml" rel="stylesheet" href="mystyles.css" type="text/css"/>
 <rect .../>
 </svg>

Or, in XML documents, external CSS style sheets may be included using
the [\<?xml-stylesheet?\>](https://www.w3.org/TR/xml-stylesheet)
processing instruction
\[[xml-stylesheet](refs.html#ref-xml-stylesheet)\].

## 6.4. Style sheets in HTML documents
When an SVG ['[style](styling.html#StyleElement)'] or an
HTML ['style'] element is used in an HTML document, those
style sheets must apply to all HTML and inline SVG content in the
document. Similarly, any HTML ['style'] element used in an
SVG document must also apply its style sheet to the document.

## 6.5. Element-specific styling: the ['class'] and ['style'] attributes
As with HTML, SVG supports the
['[class](styling.html#ClassAttribute)'] and
['[style](styling.html#StyleAttribute)'] attributes on all
elements to support element-specific styling.

*Attribute definitions:*

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------- --------------- ------------
 [class] [set of space-separated tokens](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#set-of-space-separated-tokens) [\[HTML\]] (none) yes

The ['[class](styling.html#ClassAttribute)'] attribute
assigns one or more class names to an element, which can then be used
for addressing by the styling language.

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------- ------------- --------------- ------------
 [style] (see below) (none) no

The ['[style](styling.html#StyleAttribute)'] attribute is
used to supply a CSS declaration of an element. The attribute is [parsed
as a
declaration-list](https://www.w3.org/TR/2013/REC-css-style-attr-20131107/#syntax).

Aside from the way that the
['[class](styling.html#ClassAttribute)'] attribute is
reflected in the SVG DOM (in the
[className](types.html#__svg__SVGElement__className) IDL attribute on
[SVGElement](types.html#InterfaceSVGElement)), the
semantics and behavior of the
['[class](styling.html#ClassAttribute)'] and
['[style](styling.html#StyleAttribute)'] attributes must be
the same as that for [the corresponding attributes in
HTML](https://html.spec.whatwg.org/multipage/dom.html#global-attributes).

In the following example, the
['[text](text.html#TextElement)'] element is used in
conjunction with the
['[class](styling.html#ClassAttribute)'] attribute to markup
document messages. Messages appear in both English and French versions.

 <!-- English messages -->
 <text class="info" lang="en">Variable declared twice</text>
 <text class="warning" lang="en">Undeclared variable</text>
 <text class="error" lang="en">Bad syntax for variable name</text>
 <!-- French messages -->
 <text class="info" lang="fr">Variable déclarée deux fois</text>
 <text class="warning" lang="fr">Variable indéfinie</text>
 <text class="error" lang="fr">Erreur de syntaxe pour variable</text>

The following CSS style rules would tell visual user agents to display
informational messages in green, warning messages in yellow, and error
messages in red:

 text.info { fill: green; }
 text.warning { fill: yellow; }
 text.error { fill: red; }

This example shows how the
['[style](styling.html#StyleAttribute)'] attribute can be
used to style ['[text](text.html#TextElement)'] elements
similarly to the previous example:

 <text style="fill: green;" lang="en">Variable declared twice</text>
 <text style="fill: yellow;" lang="en">Undeclared variable</text>
 <text style="fill: red;" lang="en">Bad syntax for variable name</text>

## 6.6. Presentation attributes
Some styling properties can be specified not only in style sheets and
['[style](styling.html#StyleAttribute)'] attributes, but
also in [presentation attributes]. These are attributes whose name matches (or
is similar to) a given CSS property and whose value is parsed as a value
of that property. Presentation attributes contribute to the [author
level](https://drafts.csswg.org/css-cascade-3/#preshint) of the cascade,
followed by all other author-level style sheets, and have specificity 0.

Since presentation attributes are parsed as CSS values, not
declarations, an [[!important]
declaration](https://www.w3.org/TR/2011/REC-CSS2-20110607/cascade.html#important-rules)
within a presentation attribute will cause it to have an [invalid
value](types.html#TermInvalidValue). See [Attribute
syntax](types.html#presentation-attribute-css-value) for details on how
presentation attributes are parsed.

Not all style properties that can affect SVG rendering have a
corresponding presentation attribute. Other attributes (which happen to
share the name of a style property) must not be parsed as a presentation
attribute and must not affect CSS cascading and inheritance. Also, only
elements in the SVG namespace support presentation attributes. Most SVG
presentation attributes may be specified on any element in the SVG
namespace where there is not a name clash with an existing attribute.
However, the [geometry properties](geometry.html#geometry-properties)
only have equivalent presentation attributes on designated elements.
Attributes of the same name on other elements must not affect CSS
cascading and inheritance.

Except as noted in the table for the
[transform](coords.html#TransformProperty) presentation
attributes, the presentation attribute name is the same as the property
name, in lower-case letters.

+----------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------+
| Properties with a presentation attribute | Elements that support the presentation attribute |
+======================================================================================================================+========================================================================================================+
| [cx](geometry.html#CxProperty), [cy](geometry.html#CyProperty) | ['[circle](shapes.html#CircleElement)'] and |
| | ['[ellipse](shapes.html#EllipseElement)'] |
+----------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------+
| [height](geometry.html#Sizing), [width](geometry.html#Sizing), | ['[foreignObject](embedded.html#ForeignObjectElement)'], |
| [x](geometry.html#XProperty), [y](geometry.html#YProperty) | ['[image](embedded.html#ImageElement)'], |
| | ['[rect](shapes.html#RectElement)'], ['[svg](struct.html#SVGElement)'], |
| | ['[symbol](struct.html#SymbolElement)'], and |
| | ['[use](struct.html#UseElement)'] |
+----------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------+
| [r](geometry.html#RProperty) | ['[circle](shapes.html#CircleElement)'] |
+----------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------+
| [rx](geometry.html#RxProperty), [ry](geometry.html#RyProperty) | ['[ellipse](shapes.html#EllipseElement)'] and |
| | ['[rect](shapes.html#RectElement)'] |
+----------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------+
| [d](paths.html#DProperty) | ['[path](paths.html#PathElement)'] |
+----------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------+
| [fill](painting.html#FillProperty) | Any element in the SVG namespace except for [animation |
| | elements](https://svgwg.org/specs/animations/#TermAnimationElement), which have a different |
| | ['[fill](https://svgwg.org/specs/animations/#FillAttribute)'] attribute. |
+----------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------+
| [transform](coords.html#TransformProperty) | For historical reasons, the [transform](coords.html#TransformProperty) property gets |
| | represented by different presentation attributes depending on the SVG element it applies to: |
| | |
| | [transform](coords.html#TransformProperty) |
| | : Any element in the SVG namespace with the exception of the |
| | ['[pattern](pservers.html#PatternElement)'], |
| | ['[linearGradient](pservers.html#LinearGradientElement)'] and |
| | ['[radialGradient](pservers.html#RadialGradientElement)'] elements. |
| | |
| | ['[patternTransform](pservers.html#PatternElementPatternTransformAttribute)'] |
| | : ['[pattern](pservers.html#PatternElement)']. |
| | ['[patternTransform](pservers.html#PatternElementPatternTransformAttribute)'] gets |
| | mapped to the [transform](coords.html#TransformProperty) CSS property |
| | \[[css-transforms-1](refs.html#ref-css-transforms-1)\]. |
| | |
| | ['[gradientTransform](pservers.html#LinearGradientElementGradientTransformAttribute)'] |
| | : ['[linearGradient](pservers.html#LinearGradientElement)'] and |
| | ['[radialGradient](pservers.html#RadialGradientElement)'] elements. |
| | ['[gradientTransform](pservers.html#LinearGradientElementGradientTransformAttribute)'] |
| | gets mapped to the [transform](coords.html#TransformProperty) CSS property |
| | \[[css-transforms-1](refs.html#ref-css-transforms-1)\]. |
+----------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------+
| [alignment-baseline](text.html#AlignmentBaselineProperty), | Any element in the SVG namespace. |
| [baseline-shift](text.html#BaselineShiftProperty), | |
| [clip-path](https://drafts.fxtf.org/css-masking-1/#the-clip-path), | |
| [clip-rule](https://drafts.fxtf.org/css-masking-1/#the-clip-rule), | |
| [color](painting.html#ColorProperty), | |
| [color-interpolation](painting.html#ColorInterpolationProperty), | |
| [color-interpolation-filters](https://drafts.fxtf.org/filter-effects/#ColorInterpolationFiltersProperty), | |
| [cursor](https://www.w3.org/TR/css-ui-3/#cursor), [direction](text.html#DirectionProperty), | |
| [display](render.html#VisibilityControl), | |
| [dominant-baseline](text.html#DominantBaselineProperty), | |
| [fill-opacity](painting.html#FillOpacityProperty), | |
| [fill-rule](painting.html#FillRuleProperty), | |
| [filter](https://drafts.fxtf.org/filter-effects/#FilterProperty), | |
| [flood-color](https://drafts.fxtf.org/filter-effects/#FloodColorProperty), | |
| [flood-opacity](https://drafts.fxtf.org/filter-effects/#FloodOpacityProperty), | |
| [font-family](https://www.w3.org/TR/css-fonts-3/#font-family-prop), | |
| [font-size](https://www.w3.org/TR/css-fonts-3/#font-size-prop), | |
| [font-size-adjust](https://www.w3.org/TR/css-fonts-3/#font-size-adjust-prop), | |
| [font-stretch](https://www.w3.org/TR/css-fonts-3/#font-stretch-prop), | |
| [font-style](https://www.w3.org/TR/css-fonts-3/#font-style-prop), | |
| [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant), | |
| [font-weight](https://www.w3.org/TR/css-fonts-3/#font-weight-prop), | |
| [glyph-orientation-vertical](text.html#GlyphOrientationVerticalProperty), | |
| [image-rendering](painting.html#ImageRenderingProperty), | |
| [letter-spacing](https://www.w3.org/TR/css-text-3/#letter-spacing-property), | |
| [lighting-color](https://drafts.fxtf.org/filter-effects/#LightingColorProperty), | |
| [marker-end](painting.html#MarkerEndProperty), [marker-mid](painting.html#MarkerMidProperty), | |
| [marker-start](painting.html#MarkerStartProperty), | |
| [mask](https://drafts.fxtf.org/css-masking-1/#propdef-mask), | |
| [mask-type](https://drafts.fxtf.org/css-masking-1/#propdef-mask-type), | |
| [opacity](render.html#ObjectAndGroupOpacityProperties), | |
| [overflow](render.html#OverflowAndClipProperties), | |
| [paint-order](painting.html#PaintOrderProperty), | |
| [pointer-events](interact.html#PointerEventsProperty), | |
| [shape-rendering](painting.html#ShapeRenderingProperty), | |
| [stop-color](pservers.html#StopColorProperty), | |
| [stop-opacity](pservers.html#StopOpacityProperty), [stroke](painting.html#StrokeProperty), | |
| [stroke-dasharray](painting.html#StrokeDasharrayProperty), | |
| [stroke-dashoffset](painting.html#StrokeDashoffsetProperty), | |
| [stroke-linecap](painting.html#StrokeLinecapProperty), | |
| [stroke-linejoin](painting.html#StrokeLinejoinProperty), | |
| [stroke-miterlimit](painting.html#StrokeMiterlimitProperty), | |
| [stroke-opacity](painting.html#StrokeOpacityProperty), | |
| [stroke-width](painting.html#StrokeWidthProperty), | |
| [text-anchor](text.html#TextAnchorProperty), | |
| [text-decoration](text.html#TextDecorationProperties), | |
| [text-overflow](text.html#TextOverflowProperty), | |
| [text-rendering](painting.html#TextRenderingProperty), | |
| [transform-origin](https://drafts.csswg.org/css-transforms/#transform-origin-property), | |
| [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#unicode-bidi), | |
| [vector-effect](coords.html#VectorEffectProperty), | |
| [visibility](render.html#VisibilityControl), | |
| [white-space](https://www.w3.org/TR/css-text-3/#white-space-property), | |
| [word-spacing](https://www.w3.org/TR/css-text-3/#word-spacing-property), | |
| [writing-mode](text.html#WritingModeProperty) | |
+----------------------------------------------------------------------------------------------------------------------+--------------------------------------------------------------------------------------------------------+

Note that ['cx'], ['cy'], ['r'],
['x'], ['y'], ['width'] and
['height'] attributes are not always presentation
attributes. For example, the
['[x](text.html#TextElementXAttribute)'] attribute on
['[text](text.html#TextElement)'] and
['[tspan](text.html#TextElement)'] is not a presentation
attribute for the [x](geometry.html#XProperty) property, and
the ['[r](pservers.html#RadialGradientElementRAttribute)']
attribute on a
['[radialGradient](pservers.html#RadialGradientElement)']
is not a presentation attribute for the
[r](geometry.html#RProperty) property.

In the future, any new properties that apply to SVG content will not
gain presentation attributes. Therefore, authors are suggested to use
styling properties, either through inline
['[style](styling.html#StyleAttribute)'] properties or style
sheets, rather than presentation attributes, for styling SVG content.

Animation of presentation attributes is equivalent to animating the
corresponding property.

## 6.7. Required properties
The following properties must be supported by all SVG user agents:

- all properties defined in this specification
- the [display](render.html#VisibilityControl),
 [overflow](render.html#OverflowAndClipProperties) and
 [visibility](render.html#VisibilityControl) properties
 \[[CSS2](refs.html#ref-css2)\]
- the [cursor](https://www.w3.org/TR/css-ui-3/#cursor) and
 [text-overflow](text.html#TextOverflowProperty) property
 \[[css-overflow-3](refs.html#ref-css-overflow-3)\]
- the
 [clip-path](https://drafts.fxtf.org/css-masking-1/#the-clip-path),
 [clip-rule](https://drafts.fxtf.org/css-masking-1/#the-clip-rule)
 and
 [mask](https://drafts.fxtf.org/css-masking-1/#propdef-mask)
 properties \[[css-masking-1](refs.html#ref-css-masking-1)\]
- the [color](painting.html#ColorProperty) and
 [opacity](render.html#ObjectAndGroupOpacityProperties)
 properties \[[css-color-3](refs.html#ref-css-color-3)\]
- the
 [color-interpolation-filters](https://drafts.fxtf.org/filter-effects/#ColorInterpolationFiltersProperty),
 [filter](https://drafts.fxtf.org/filter-effects/#FilterProperty),
 [flood-color](https://drafts.fxtf.org/filter-effects/#FloodColorProperty),
 [flood-opacity](https://drafts.fxtf.org/filter-effects/#FloodOpacityProperty)
 and
 [lighting-color](https://drafts.fxtf.org/filter-effects/#LightingColorProperty)
 properties \[[filter-effects-1](refs.html#ref-filter-effects-1)\]
- the
 [isolation](https://www.w3.org/TR/2015/CR-compositing-1-20150113/#isolation)
 property \[[compositing-1](refs.html#ref-compositing-1)\]
- the [transform](coords.html#TransformProperty),
 [transform-box](https://drafts.csswg.org/css-transforms/#transform-box)
 and
 [transform-origin](https://drafts.csswg.org/css-transforms/#transform-origin-property)
 properties \[[css-transforms-1](refs.html#ref-css-transforms-1)\]
- the
 [letter-spacing](https://www.w3.org/TR/css-text-3/#letter-spacing-property),
 [text-align](https://www.w3.org/TR/css-text-3/#text-align-property),
 [text-align-last](https://www.w3.org/TR/css-text-3/#text-align-last-property),
 [text-indent](https://www.w3.org/TR/css-text-3/#text-indent-property)
 and
 [word-spacing](https://www.w3.org/TR/css-text-3/#word-spacing-property)
 properties \[[css-text-3](refs.html#ref-css-text-3)\]
- the
 [white-space](https://www.w3.org/TR/css-text-3/#white-space-property)
 property \[[css-text-4](refs.html#ref-css-text-4)\]
- the
 [vertical-align](https://drafts.csswg.org/css-inline/#transverse-alignment),
 [dominant-baseline](text.html#DominantBaselineProperty),
 [alignment-baseline](text.html#AlignmentBaselineProperty),
 and [baseline-shift](text.html#BaselineShiftProperty)
 properties \[[css-inline-3](refs.html#ref-css-inline-3)\]
- the [direction](text.html#DirectionProperty),
 [text-orientation](https://www.w3.org/TR/css3-writing-modes/#text-orientation)
 and [writing-mode](text.html#WritingModeProperty)
 properties
 \[[css-writing-modes-3](refs.html#ref-css-writing-modes-3)\]
- the [font](https://www.w3.org/TR/css-fonts-3/#font-prop),
 [font-family](https://www.w3.org/TR/css-fonts-3/#font-family-prop),
 [font-feature-settings](https://www.w3.org/TR/css-fonts-3/#font-feature-settings-prop),
 [font-kerning](https://www.w3.org/TR/css-fonts-3/#font-kerning-prop),
 [font-size](https://www.w3.org/TR/css-fonts-3/#font-size-prop),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-3/#font-size-adjust-prop),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#font-stretch-prop),
 [font-style](https://www.w3.org/TR/css-fonts-3/#font-style-prop),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant)
 (along with its subproperties) and
 [font-weight](https://www.w3.org/TR/css-fonts-3/#font-weight-prop)
 properties \[[css-fonts-3](refs.html#ref-css-fonts-3)\]
- the [text-decoration](text.html#TextDecorationProperties),
 [text-decoration-line](text.html#TextDecorationProperties),
 [text-decoration-style](text.html#TextDecorationProperties)
 and
 [text-decoration-color](text.html#TextDecorationProperties)
 properties \[[css-text-decor-3](refs.html#ref-css-text-decor-3)\]

## 6.8. User agent style sheet
The following [user agent style
sheet](https://www.w3.org/TR/2011/REC-CSS2-20110607/cascade.html#cascade)
must be applied in all SVG user agents.

 @namespace url(http://www.w3.org/2000/svg);
 @namespace xml url(http://www.w3.org/XML/1998/namespace);

 svg:not(:root), image, marker, pattern, symbol { overflow: hidden; }

 *:not(svg),
 *:not(foreignObject) > svg {
 transform-origin: 0 0;
 }

 *[xml|space=preserve] {
 white-space-collapse: preserve-spaces;
 }

 defs,
 clipPath, mask, marker,
 desc, title, metadata,
 pattern, linearGradient, radialGradient,
 script, style,
 symbol {
 display: none !important;
 }
 :host(use) > symbol {
 display: inline !important;
 }
 :link, :visited {
 cursor: pointer;
 }

In addition, all interactive user agents are required to apply
distinctive styles to the `:focus` pseudo-class (normally using the
`outline` property) and the `::selection` pseudo-element (using an
appropriate highlighting technique, such as redrawing the selected
glyphs with inverse colors).

An `!important` rule in a user agent stylesheet [over-rides all user and
author styles](https://www.w3.org/TR/css-cascade-4/#importance)
\[[css-cascade-4](refs.html#ref-css-cascade-4)\]. The display value for
[never-rendered elements](render.html#TermNeverRenderedElement) and for
['[symbol](struct.html#SymbolElement)'] elements can
therefore not be changed. A symbol must only be rendered if it is the
direct child of a shadow root whose host is a
['[use](struct.html#UseElement)'] element (and must
always be rendered if the host
['[use](struct.html#UseElement)'] element is rendered).
The other elements, and their child content, are never rendered
directly.

CSS Transforms defines that the initial value for
[transform-origin](https://drafts.csswg.org/css-transforms/#transform-origin-property)
is [50% 50%]. Since elements in
SVG must, by default, transform around their origin at (0, 0),
[transform-origin](https://drafts.csswg.org/css-transforms/#transform-origin-property)
is overridden and set to a default value of [0 0] for all SVG elements (except for root
['[svg](struct.html#SVGElement)'] elements and
['[svg](struct.html#SVGElement)'] elements that are the
child of a
['[foreignObject](embedded.html#ForeignObjectElement)']
element or an element in a non-SVG namespace; these elements must
transform around their center).
\[[css-transforms-1](refs.html#ref-css-transforms-1)\]

The OpenType specification [requires an additional user agent style
sheet](https://www.microsoft.com/typography/otspec/svg.htm) to be
applied when processing \[[OPENTYPE](refs.html#ref-opentype)\]. It is as
follows:

``` {style="background-color: #eee; padding: 0.5em"}
@namespace svg url(http://www.w3.org/2000/svg);

svg|text, svg|foreignObject {
 display: none !important;
}

:root {
 fill: context-fill;
 fill-opacity: context-fill-opacity;
 stroke: context-stroke;
 stroke-opacity: context-stroke-opacity;
 stroke-width: context-value;
 stroke-dasharray: context-value;
 stroke-dashoffset: context-value;
}
```

The [context-fill](painting.html#context-paint) and
[context-stroke](painting.html#context-paint) keywords are as defined in
this specification, where the [context
element](painting.html#TermContextElement) for a font glyph is the
corresponding [text content element](text.html#TermTextContentElement).
The other keywords are as defined in the OpenType specification, and
ensure that the style values from the [text content
element](text.html#TermTextContentElement) are propagated to the font
glyphs, with appropriate adjustments for the change in the coordinate
system \[[OPENTYPE](refs.html#ref-opentype)\].

## 6.9. Required CSS features
Besides the features described above, the following CSS features must be
also supported in SVG user agents:

- in XML documents, external CSS style sheets using the
 [\<?xml-stylesheet?\>](https://www.w3.org/TR/xml-stylesheet)
 processing instruction
 \[[xml-stylesheet](refs.html#ref-xml-stylesheet)\]
- [\@media](https://www.w3.org/TR/2011/REC-CSS2-20110607/media.html#at-media-rule),
 [\@import](https://www.w3.org/TR/2011/REC-CSS2-20110607/cascade.html#at-import)
 and
 [\@charset](https://www.w3.org/TR/2011/REC-CSS2-20110607/syndata.html#charset)
 rules within style sheets, as defined in CSS 2.1
- [\@font-face](https://www.w3.org/TR/2011/WD-css3-fonts-20111004/#font-face-rule)
 rules within style sheets \[[css-fonts-3](refs.html#ref-css-fonts-3)\]
- all pseudo-classes defined in CSS 2.1 (including :hover, :link,
 :active, :visited, :focus, :first-child and :lang)
- the ::first-letter and ::first-line pseudo-elements defined in CSS 2.1
 (on ['[text](text.html#TextElement)'] elements)

## 6.10. DOM interfaces
### 6.10.1. Interface SVGStyleElement
An
[SVGStyleElement](styling.html#InterfaceSVGStyleElement)
object represents a
['[style](styling.html#StyleElement)'] element in the
DOM.

``` idl
[Exposed=Window]
interface SVGStyleElement : SVGElement {
 attribute DOMString type;
 attribute DOMString media;
 attribute DOMString title;
 attribute boolean disabled;
};

SVGStyleElement includes LinkStyle;
```

The **type**, **media** and **title** IDL attributes
[reflect](types.html#TermReflect) the
['[type](styling.html#StyleElementTypeAttribute)'],
['[media](styling.html#StyleElementMediaAttribute)'] and
['[title](styling.html#StyleElementTitleAttribute)'] content
attributes, respectively.
