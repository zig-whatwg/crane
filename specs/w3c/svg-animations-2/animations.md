
[![W3C](https://www.w3.org/Icons/w3c_home){height="48"
width="72"}](https://www.w3.org/)

# SVG Animations Level 2

## W3C Editor's Draft *14 September 2025*

This version:
: [https://svgwg.org/specs/animations/](https://svgwg.org/specs/animations/)

Latest version:
: ()

GitHub repository:
: <https://github.com/w3c/svgwg/tree/main/specs/animations>

Feedback:
: [www-svg@w3.org](mailto:www-svg@w3.org) with subject line
 "`[svg-animation] … `*`message topic`*` …`"
 ([archive](http://lists.w3.org/Archives/Public/www-svg/))

Editor:
: Brian Birtles,
 Mozilla\<[bbirtles@mozilla.com](mailto:bbirtles@mozilla.com)\>

[Copyright](http://www.w3.org/Consortium/Legal/ipr-notice#Copyright) ©
2025 [[W3C]](http://www.w3.org/)^®^ ([[MIT]](http://www.csail.mit.edu/),
[[ERCIM]](http://www.ercim.eu/),
[Keio](http://www.keio.ac.jp/), [Beihang](http://ev.buaa.edu.cn/)). W3C
[liability](http://www.w3.org/Consortium/Legal/ipr-notice#Legal_Disclaimer),
[trademark](http://www.w3.org/Consortium/Legal/ipr-notice#W3C_Trademarks)
and [document
use](http://www.w3.org/Consortium/Legal/copyright-documents) rules
apply.

------------------------------------------------------------------------

## Abstract

This specification defines SVG Animations, a set of features based on
SMIL for declaratively animating SVG content.

## Status of This Document

*This section describes the status of this document at the time of its
publication. Other documents may supersede this document. A list of
current W3C publications and the latest revision of this technical
report can be found in the [W3C technical reports
index](http://www.w3.org/TR/) at http://www.w3.org/TR/*.

This document is the 14 September 2025 **Editor's Draft** of SVG
Animation. The purpose of this specification is to separate out SVG\'s
animation features into a separate document.

Comments on this Editor's Draft are welcome. Comments can be sent to
[www-svg@w3.org](mailto:www-svg@w3.org), the public email list for
issues related to vector graphics on the Web. This list is
[archived](http://lists.w3.org/Archives/Public/www-svg/) and senders
must agree to have their message publicly archived from their first
posting. To subscribe send an email to
[www-svg-request@w3.org](mailto:www-svg-request@w3.org) with the
word `subscribe` in the subject line.

This document has been produced by the [W3C SVG Working
Group](http://www.w3.org/Graphics/SVG/WG) as part of the [Graphics
Activity](http://www.w3.org/Graphics/Activity) within the [W3C
Interaction Domain](http://www.w3.org/Interaction/). The goals of the
W3C SVG Working Group are discussed in the [W3C SVG
Charter](https://www.w3.org/Graphics/SVG/svg-2019.html). The W3C SVG
Working Group maintains a public Web page,
[http://www.w3.org/Graphics/SVG/](http://www.w3.org/Graphics/SVG/),
that contains further background information. The authors of this
document are the SVG Working Group participants.

This document was produced by a group operating under the [5 February
2004 W3C Patent
Policy](http://www.w3.org/Consortium/Patent-Policy-20040205/). W3C
maintains a [public list of any patent
disclosures](http://www.w3.org/2004/01/pp-impl/19480/status){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent which the individual believes contains
[Essential
Claim(s)](http://www.w3.org/Consortium/Patent-Policy-20040205/#def-essential)
must disclose the information in accordance with [section 6 of the W3C
Patent
Policy](http://www.w3.org/Consortium/Patent-Policy-20040205/#sec-Disclosure).

Publication as a Editor's Draft does not imply endorsement by the W3C
Membership. This is a draft document and may be updated, replaced or
obsoleted by other documents at any time. It is inappropriate to cite
this document as other than work in progress.

A list of current W3C Recommendations and other technical documents can
be found at [http://www.w3.org/TR/](http://www.w3.org/TR/). W3C
publications may be updated, replaced, or obsoleted by other documents
at any time.

This document is governed by the [1 August 2014 W3C Process
Document](http://www.w3.org/2014/Process-20140801/).

## Table of Contents

1. [[1.] Introduction](#intro)
 1. [[1.1.] Module interactions](#placement)
2. [[2.] Animation elements](#AnimationElements)
 1. [[2.1.] Overview](#AnimationElementsIntro)
 2. [[2.2.] Definitions](#AnimationDefinitions)
 3. [[2.3.] Relationship to SMIL
 Animation](#RelationshipToSMILAnimation)
 4. [[2.4.] Animation elements
 example](#AnimationElementsExample)
 5. [[2.5.] Attributes to identify the target element for an
 animation](#TargetElement)
 6. [[2.6.] Attributes to identify the target attribute or
 property for an animation](#TargetAttributes)
 7. [[2.7.] Animation with namespaces](#Animation.nsexample)
 8. [[2.8.] Paced animation and complex
 types](#complexDistances)
 9. [[2.9.] Attributes to control the timing of the
 animation](#TimingAttributes)
 1. [[2.9.1.] Clock values](#ClockValueSyntax)
 10. [[2.10.] Attributes that define animation values over
 time](#ValueAttributes)
 11. [[2.11.] Attributes that control whether animations are
 additive](#AdditionAttributes)
 12. [[2.12.] Inheritance](#Inheritance)
 13. [[2.13.] The ['animate']
 element](#AnimateElement)
 14. [[2.14.] The ['set']
 element](#SetElement)
 15. [[2.15.] The ['animateMotion']
 element](#AnimateMotionElement)
 16. [[2.16.] The ['animateTransform']
 element](#AnimateTransformElement)
 17. [[2.17.] Elements, attributes and properties that can be
 animated](#AnimationAttributesAndProperties)
 18. [[2.18.] Implicit ARIA
 Semantics](#implicit-aria-semantics)
3. [[3.] Animation using the SVG DOM](#DOMAnimationExample)
4. [[4.] Extensions to SVG 2](#extensions)
 1. [[4.1.] Extensions to the ['svg']
 element](#SVGElement)
 2. [[4.2.] Extensions to conditional processing
 elements](#ConditionalProcessing)
5. [[5.] IDL](#IDL)
 1. [[5.1.] Interface TimeEvent](#InterfaceTimeEvent)
 2. [[5.2.] Interface
 SVGAnimationElement](#InterfaceSVGAnimationElement)
 3. [[5.3.] Interface
 SVGAnimateElement](#InterfaceSVGAnimateElement)
 4. [[5.4.] Interface
 SVGSetElement](#InterfaceSVGSetElement)
 5. [[5.5.] Interface
 SVGAnimateMotionElement](#InterfaceSVGAnimateMotionElement)
 6. [[5.6.] Interface
 SVGMPathElement](#InterfaceSVGMPathElement)
 7. [[5.7.] Interface
 SVGAnimateTransformElement](#InterfaceSVGAnimateTransformElement)
 8. [[5.8.] Extensions to interface
 SVGSVGElement](#InterfaceSVGSVGElement)
6. [[6.] References](#refs)
 1. [[6.1.] Normative references](#normrefs)
 2. [[6.2.] Non-normative references](#nonnormrefs)
7. [[7.] Changes since SVG 1.1 Second
 Edition](#ChangesSinceSVG11)

## 1. Introduction
*This section is non-normative.*

SVG supports the ability to change vector graphics over time. SVG
content can be animated in the following ways:

- Using SVG\'s [animation elements](#AnimationElements). SVG document
 fragments can describe time-based modifications to the document\'s
 elements. Using the various animation elements, authors can define
 motion paths, or interpolate the element\'s attributes and style
 properties. These effects can be chained together or triggered in
 response to other events in the document.
- Using [CSS
 Animations](http://www.w3.org/TR/2012/WD-css-animations-1-20120403/)
 \[[CSSANIMATIONS](#ref-CSS3ANIMATIONS)\]. A CSS module that describes
 a way for authors to animate the values of CSS properties over time,
 using keyframes. The behavior of these keyframe animations can be
 controlled by specifying their duration, number of repeats, and
 repeating behavior.
- Using [CSS
 Transitions](http://www.w3.org/TR/2012/WD-css-transitions-1-20120403/)
 \[[CSS3TRANSITIONS](#ref-CSS3TRANSITIONS)\]. A CSS module that allows
 changes to values of CSS properties to occur smoothly over a specified
 duration.
- Using the [SVG DOM](https://svgwg.org/svg2-draft/svgdom.html). The SVG
 DOM is defined based on the DOM4 specification \[[DOM4](#ref-DOM4)\].
 Every attribute and style sheet setting is accessible to scripting,
 and SVG offers a set of additional DOM interfaces to support efficient
 animation via scripting. (See [example](#DOMAnimationExample) below.)

### 1.1. Module interactions
This module extends definitions in SVG 2.[\[SVG2\]](#ref-SVG2)

## 2. Animation elements
::::: ready-for-wider-review
### 2.1. Overview
SVG\'s animation elements were developed in collaboration with the W3C
Synchronized Multimedia (SYMM) Working Group, developers of the
[Synchronized Multimedia Integration Language (SMIL) 3.0
Specification](http://www.w3.org/TR/2008/REC-SMIL3-20081201/)
\[[SMIL](#ref-SMIL)\].

The SYMM Working Group, in collaboration with the SVG Working Group, has
authored the [SMIL Animation
specification](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
\[[SMILANIM](#ref-SMILANIM)\], which represents a general-purpose XML
animation feature set. SVG incorporates the animation features defined
in the SMIL Animation specification and provides some SVG-specific
extensions.

For an introduction to the approach and features available in any
language that supports SMIL Animation, see [SMIL Animation
overview](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#AnimationFramework)
and [SMIL Animation animation
model](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#AnimationModel)
(\[[SMILANIM](#ref-SMILANIM)\], sections 2 and 3). For the list of
animation features which go beyond SMIL Animation, see [SVG extensions
to SMIL Animation](#SVGExtensionsToSMILAnimation).

### 2.2. Definitions
[animation element]
: An animation element is an element that can be used to animate the
 attribute or property value of another element. The following
 elements are animation elements:
 ['[animate](#AnimateElement)'],
 ['[animateMotion](#AnimateMotionElement)'],
 ['[animateTransform](#AnimateTransformElement)'] and
 ['[set](#SetElement)'].

[animation event attribute]
: An animation event attribute is an [event
 attribute](https://svgwg.org/svg2-draft/interact.html#TermEventAttribute)
 that specifies script to run for a particular animation-related
 event. See [Animation event
 attributes](https://svgwg.org/svg2-draft/interact.html#AnimationEvents).
 The animation event attributes are
 ['[onbegin](http://svgwg.org/svg2-draft/interact.html#OnBeginEventAttribute)'],
 ['[onend](http://svgwg.org/svg2-draft/interact.html#OnEndEventAttribute)']
 and
 ['[onrepeat](http://svgwg.org/svg2-draft/interact.html#OnRepeatEventAttribute)'].

### 2.3. Relationship to SMIL Animation
SVG is a host language in terms of SMIL Animation and therefore
introduces additional constraints and features as permitted by that
specification. Except for any SVG-specific rules explicitly mentioned in
this specification, the normative definition for SVG\'s animation
elements and attributes is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification \[[SMILANIM](#ref-SMILANIM)\].

SVG supports the following three animation elements which are defined in
the SMIL Animation specification:

 ----------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ['[animate](#AnimateElement)'] allows attributes and properties to be assigned different values over time
 ['[set](#SetElement)'] a convenient shorthand for ['[animate](#AnimateElement)'], which produces a discrete change to an animated attribute or property. It is most commonly used with values which do not support linear interpolation, such as the [visibility](https://svgwg.org/svg2-draft/render.html#VisibilityControl) property
 ['[animateMotion](#AnimateMotionElement)'] moves an element along a motion path
 ----------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Additionally, SVG includes the following compatible extensions to SMIL
Animation:

 ---------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ['[animateTransform](#AnimateTransformElement)'] modifies one of SVG\'s transformation values over time, such as the [transform](https://svgwg.org/svg2-draft/coords.html#TransformProperty) property or the ['[patternTransform](https://svgwg.org/svg2-draft/pservers.html#PatternElementPatternTransformAttribute)'] attribute.
 ['[path](#AnimateMotionElementPathAttribute)'] attribute SVG allows any feature from SVG\'s [path data](https://svgwg.org/svg2-draft/paths.html#PathData) syntax to be specified in a ['[path](#AnimateMotionElementPathAttribute)'] attribute to the ['[animateMotion](#AnimateMotionElement)'] element (SMIL Animation only allows a subset of SVG\'s path data syntax within a ['[path](#AnimateMotionElementPathAttribute)'] attribute)
 ['[mpath](#MPathElement)'] element SVG allows an ['[animateMotion](#AnimateMotionElement)'] element to contain a child ['[mpath](#MPathElement)'] element which references an SVG ['[path](https://svgwg.org/svg2-draft/paths.html#PathElement)'] element or [shape](https://svgwg.org/svg2-draft/shapes.html#TermShapeElement) element as the definition of the motion path
 ['[keyPoints](#KeyPointsAttribute)'] attribute SVG adds a ['[keyPoints](#KeyPointsAttribute)'] attribute to the ['[animateMotion](#AnimateMotionElement)'] to provide precise control of the velocity of motion path animations
 ['[rotate](#RotateAttribute)'] attribute SVG adds a ['[rotate](#RotateAttribute)'] attribute to the ['[animateMotion](#AnimateMotionElement)'] to control whether an object is automatically rotated so that its x-axis points in the same direction (or opposite direction) as the directional tangent vector of the motion path
 ---------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

For compatibility with other aspects of the language, SVG uses [URL
references](https://svgwg.org/svg2-draft/linking.html#TermURLReference)
via an ['[href](#HrefAttribute)'] attribute to identify the
elements which are to be targets of the animations, as allowed in SMIL
3.0.

SMIL Animation requires that the host language define the meaning for
*document begin* and the *document end*. Since an
['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
is sometimes the root of the XML document tree and other times can be a
component of a parent XML grammar, the document begin for a given [SVG
document
fragment](https://svgwg.org/svg2-draft/struct.html#TermSVGDocumentFragment)
is defined to be the exact time at which the
['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
element\'s [load
event](https://svgwg.org/svg2-draft/interact.html#LoadEvent) is
triggered. The document end of an SVG document fragment is the point at
which the document fragment has been released and is no longer being
processed by the user agent. However, nested
['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
elements within an SVG document do not constitute document fragments in
this sense, and do not define a separate document begin; all times
within the nested SVG fragment are relative to the document time defined
for the root
['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
element.

For SVG, the term [presentation time] indicates
the position in the timeline relative to the document begin of a given
document fragment.

### 2.4. Animation elements example
[Example anim01] below demonstrates each of SVG\'s four
animation elements.

 <?xml version="1.0" standalone="no"?>
 <svg width="8cm" height="3cm" viewBox="0 0 800 300"
 xmlns="http://www.w3.org/2000/svg">
 <desc>Example anim01 - demonstrate animation elements</desc>
 <rect x="1" y="1" width="798" height="298"
 fill="none" stroke="blue" stroke-width="2" />
 <!-- The following illustrates the use of the 'animate' element
 to animate a rectangles x, y, and width attributes so that
 the rectangle grows to ultimately fill the viewport. -->
 <rect id="RectElement" x="300" y="100" width="300" height="100"
 fill="rgb(255,255,0)" >
 <animate attributeName="x" begin="0s" dur="9s"
 fill="freeze" from="300" to="0" />
 <animate attributeName="y" begin="0s" dur="9s"
 fill="freeze" from="100" to="0" />
 <animate attributeName="width" begin="0s" dur="9s"
 fill="freeze" from="300" to="800" />
 <animate attributeName="height" begin="0s" dur="9s"
 fill="freeze" from="100" to="300" />
 </rect>
 <!-- Set up a new user coordinate system so that
 the text string's origin is at (0,0), allowing
 rotation and scale relative to the new origin -->
 <g transform="translate(100,100)" >
 <!-- The following illustrates the use of the 'set', 'animateMotion',
 'animate' and 'animateTransform' elements. The 'text' element
 below starts off hidden (i.e., invisible). At 3 seconds, it:
 * becomes visible
 * continuously moves diagonally across the viewport
 * changes color from blue to dark red
 * rotates from -30 to zero degrees
 * scales by a factor of three. -->
 <text id="TextElement" x="0" y="0"
 font-family="Verdana" font-size="35.27" visibility="hidden" >
 It's alive!
 <set attributeName="visibility" to="visible"
 begin="3s" dur="6s" fill="freeze" />
 <animateMotion path="M 0 0 L 100 100"
 begin="3s" dur="6s" fill="freeze" />
 <animate attributeName="fill"
 from="rgb(0,0,255)" to="rgb(128,0,0)"
 begin="3s" dur="6s" fill="freeze" />
 <animateTransform attributeName="transform"
 type="rotate" from="-30" to="0"
 begin="3s" dur="6s" fill="freeze" />
 <animateTransform attributeName="transform"
 type="scale" from="1" to="3" additive="sum"
 begin="3s" dur="6s" fill="freeze" />
 </text>
 </g>
 </svg>

 ---------------------------------------------------------------------------------------------------------------------- --- ------------------------------------------------------------------------------------------------------------------------
 ![Example anim01 - at zero seconds](images/anim01a.png){width="256" height="91"} [At zero seconds]   ![Example anim01 - at three seconds](images/anim01b.png){width="256" height="91"} [At three seconds]
 ![Example anim01 - at six seconds](images/anim01c.png){width="256" height="91"} [At six seconds]   ![Example anim01 - at nine seconds](images/anim01d.png){width="256" height="91"} [At nine seconds]
 ---------------------------------------------------------------------------------------------------------------------- --- ------------------------------------------------------------------------------------------------------------------------

 : Example anim01

[View this example as SVG (SVG-enabled browsers
only)](images/anim01.svg)

The sections below describe the various animation attributes and
elements.

:::: ready-for-wider-review
### 2.5. Attributes to identify the target element for an animation
The following attribute is common to all animation elements and
identifies the target element for the animation.

*Attribute definitions:*

 Name Value Initial value Animatable
 ----------------------------------------------------------------------- ------------------------------------------------------------------------------- --------------- ------------
 [href] URL [\[URL\]](https://svgwg.org/svg2-draft/types.html#attribute-url) (none) no

A [URL
reference](https://svgwg.org/svg2-draft/linking.html#TermURLReference)
to the element which is the target of this animation element and which
therefore will be modified over time.

The URL must point to exactly one target element which is capable of
being the target of the given animation element. If the URL points to
multiple target elements, if the given target element is not capable of
being a target of the given animation element, or if the given target
element is not part of the current document, then the animation element
will not affect any target element. However, the animation element will
still operate normally with regard to its timing properties.
Specifically, [TimeEvent](#InterfaceTimeEvent)s are
dispatched and the animation element can be used as
[syncbase](#syncbase) in an identical fashion to when the URL refers to
a valid target element.

If the ['[href](#HrefAttribute)'] attribute or the
deprecated
['[xlink:href](https://svgwg.org/svg2-draft/linking.html#XLinkHrefAttribute)']
attribute is not provided, then the target element will be the immediate
parent element of the current animation element. The behavior when both
['[href](#HrefAttribute)'] and
['[xlink:href](https://svgwg.org/svg2-draft/linking.html#XLinkHrefAttribute)']
are specified is defined by the common handling for [deprecated XLink
attributes](https://svgwg.org/svg2-draft/linking.html#XLinkRefAttrs).

Refer to the descriptions of the individual animation elements for any
restrictions on what types of elements can be targets of particular
types of animations.

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: Specifying the
animation
target](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#SpecifyingAnimationTarget)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.1).

Reference the deprecated
['[xlink:href](https://svgwg.org/svg2-draft/linking.html#XLinkHrefAttribute)']
attribute and its handling as defined in [SVG
2](https://svgwg.org/svg2-draft/linking.html#XLinkRefAttrs).

### 2.6. Attributes to identify the target attribute or property for an animation
The following attribute identifies the target attribute or property for
the given [target element](#TargetElement) whose value changes over
time.

*Attribute definitions:*

 Name Value Initial value Animatable
 ----------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------- --------------- ------------
 [attributeName] [Name](http://www.w3.org/TR/xml/#NT-Name) [\[EBNF\]](https://svgwg.org/svg2-draft/types.html#syntax) (none) no

Specifies the name of the target property or attribute.

Unlike [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/), the
[attributeType] attribute is not supported by SVG. SVG\'s
animation elements follow the behavior defined for the
[auto] value of [attributeType]. That is,
when determining if
['[attributeName](#AttributeNameAttribute)'] corresponds to
an attribute name or a CSS property name, the implementation must first
search through the list of CSS properties for a matching property name.
If no matching property is found, the implementation must search for a
matching attribute on the target element.

When referencing an attribute, an XMLNS prefix may be used to indicate
the XML namespace for the attribute. The prefix will be interpreted in
the scope of the current (i.e., the referencing) animation element.
Otherwise the implementation must use the default XML namespace for the
target element.

Note that, as a result of the behavior, it is not possible to animate
the list of coordinates specified by the
['[x](https://svgwg.org/svg2-draft/text.html#TextElementXAttribute)']
and
['[y](https://svgwg.org/svg2-draft/text.html#TextElementYAttribute)']
attributes on
['[text](https://svgwg.org/svg2-draft/text.html#TextElement)']
and
['[tspan](https://svgwg.org/svg2-draft/text.html#TextElement)']
elements. This is because '[x]' and
'[y]' are also CSS properties where they only accept a
single length as a value.

Due to the complex mapping between characters and glyphs, using the
list-based syntax for
['[x](https://svgwg.org/svg2-draft/text.html#TextElementXAttribute)']
and
['[y](https://svgwg.org/svg2-draft/text.html#TextElementYAttribute)']
to specify glyph positions does not scale well to anything beyond very
simple Latin text and its use is discouraged. Authors who nevertheless
wish to animate this list of coordinates may be able to achieve a
comparable effect using the
['[dx](https://svgwg.org/svg2-draft/text.html#TextElementDXAttribute)']
and
['[dy](https://svgwg.org/svg2-draft/text.html#TextElementDYAttribute)']
attributes instead since these names to not overlap with CSS properties.

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: Specifying the
animation
target](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#SpecifyingAnimationTarget)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.1).

### 2.7. Animation with namespaces(#Animation.nsexample)

[Example animns01] below shows a namespace prefix being
resolved to a namespace name in the scope of the referencing element,
and that namespace name being used (regardless of the prefix which
happens to be used in the target scope) to identify the attribute being
animated.

``` xml
<?xml version="1.0" encoding="UTF-8"?>
<svg version="1.1" xmlns="http://www.w3.org/2000/svg">
 <title>Demonstration of the resolution of namespaces for animation</title>
 <!-- at the point of definition, the QName a:href resolves to the namespace
 name "http://www.w3.org/1999/xlink" and the local name "href" -->
 <g xmlns:a="http://www.w3.org/1999/xlink">
 <animate attributeName="a:href" href="#foo" dur="2s" to="two.png" fill="freeze"/>
 </g>
 <!-- at the point of use, the namespace name "http://www.w3.org/1999/xlink"
 happens to be bound to the namespace prefix 'b' -->
 <g xmlns:b="http://www.w3.org/1999/xlink">
 <image id="foo" b:href="one.png" x="35" y="50" width="410" height="160"/>
 </g>
</svg>
```

[View this example as SVG (SVG-enabled browsers
only)](images/animns01.svg)

### 2.8. Paced animation and complex types
Paced animations assume a notion of distance between the various
animation values defined by the ['[to](#ToAttribute)'],
['[from](#FromAttribute)'],
['[by](#ByAttribute)'] and
['[values](#ValuesAttribute)'] attributes. Distance is
defined only for scalar types (such as
[\<length\>](https://www.w3.org/TR/css3-values/#lengths)), colors and
the subset of transformation types that are supported by
['[animateTransform](#AnimateTransformElement)']. In the
list of distance functions below, V~a~ and V~b~ represent the two values
the distance between which is being calculated.

Since paced animation is intended to produce an animation with an even
pace of change, it does not make sense to define distance functions for
all data types. Distance can be usefully defined for types whose values
are `n`-dimensional vectors (including scalars, which are
1-dimensional vectors). For example, a
[\<length\>](https://www.w3.org/TR/css3-values/#lengths) value is a
scalar value, and a
[\<color\>](https://www.w3.org/TR/css3-values/#colors) value is a
3-dimensional vector. Thus attributes of these types can have paced
animation applied to them. On the other hand, a
[\<dasharray\>](https://svgwg.org/svg2-draft/painting.html#DataTypeDasharray)
(as used by
['[stroke-dasharray]'](https://svgwg.org/svg2-draft/painting.html#StrokeDasharrayProperty))
is a list of scalars (1-dimensional vectors), and
[\<points\>](https://svgwg.org/svg2-draft/shapes.html#DataTypePoints)
(as used by the
[['points']](https://svgwg.org/svg2-draft/shapes.html#PolygonElementPointsAttribute)
attribute on a
[['polygon']](https://svgwg.org/svg2-draft/shapes.html#PolygonElement))
is a list of 2-dimensional vectors. Therefore, these types do not have a
distance function defined and cannot have paced animation applied to
them.

The distance functions for types that support paced animation are as
follows:

[\<integer\>](https://www.w3.org/TR/css3-values/#integers), [\<length\>](https://www.w3.org/TR/css3-values/#lengths) and [\<number\>](https://www.w3.org/TR/css3-values/#numbers)

: distance(V~a~, V~b~) = \|V~a~ − V~b~\|

 Examples: animating the
 ['[x](https://svgwg.org/svg2-draft/text.html#TextElementXAttribute)']
 attribute on a
 ['[text](https://svgwg.org/svg2-draft/text.html#TextElement)'],
 or the
 [stroke-width](https://svgwg.org/svg2-draft/painting.html#StrokeWidthProperty)
 property on a
 ['[circle](https://svgwg.org/svg2-draft/shapes.html#CircleElement)'].

[\<color\>](https://www.w3.org/TR/css3-values/#colors)

: distance(V~a~, V~b~) = sqrt((V~a~.red − V~b~.red)^2^ + (V~a~.green −
 V~b~.green)^2^ + (V~a~.blue − V~b~.blue)^2^), where:

 :::::: vardefs
 :::
 V~`i`~.red is the red component of the V~`i`~
 color value,
 :::

 :::
 V~`i`~.green is the green component of the
 V~`i`~ color value, and
 :::

 :::
 V~`i`~.blue is the blue component of the
 V~`i`~ color value.
 :::
 ::::::

 Each of the color component values is usually in the range \[0, 1\],
 where 0 represents none of that color component, and 1 represents
 the maximum amount of that color component, in the sRGB gamut
 \[[SRGB](#ref-SRGB)\]. Since
 [\<color\>](https://www.w3.org/TR/css3-values/#colors) values may
 specify colors outside of the sRGB gamut, these component values may
 lie outside the range \[0, 1\].

 Example: animating the
 [fill](https://svgwg.org/svg2-draft/painting.html#FillProperty)
 property on an
 ['[ellipse](https://svgwg.org/svg2-draft/shapes.html#EllipseElement)'].

Transform definitions of type [\'translate\']

: distance(V~a~, V~b~) = sqrt((V~a~.tx − V~b~.tx)^2^ + (V~a~.ty −
 V~b~.ty)^2^), where:

 ::::: vardefs
 :::
 V~`i`~.tx is the `x` component of the
 V~`i`~ translation transform value, and
 :::

 :::
 V~`i`~.ty is the `y` component of the
 V~`i`~ translation transform value.
 :::
 :::::

 Example (for all transform definition types): animating the
 [transform](https://svgwg.org/svg2-draft/coords.html#TransformProperty)
 attribute on a
 ['[g](https://svgwg.org/svg2-draft/struct.html#GElement)']
 using
 ['[animateTransform](#AnimateTransformElement)'].

Transform definitions of type [\'scale\']

: distance(V~a~, V~b~) = sqrt((V~a~.sx − V~b~.sx)^2^ + (V~a~.sy −
 V~b~.sy)^2^), where:

 ::::: vardefs
 :::
 V~`i`~.sx is the `x` component of the
 V~`i`~ scale transform value, and
 :::

 :::
 V~`i`~.sy is the `y` component of the
 V~`i`~ scale transform value.
 :::
 :::::

 Note that, as when specifying scale transformations in a
 [\<transform-list\>](http://dev.w3.org/csswg/css-transforms/#typedef-transform-list),
 if the `y` component of the scale is omitted it is
 implicitly equal to the `x` component.

Transform definitions of type [\'rotate\'], [\'skewX\'] and [\'skewY\']

: distance(V~a~, V~b~) = sqrt((V~a~.angle − V~b~.angle)^2^), where:

 :::: vardefs
 :::
 V~`i`~.angle is the angle component of the
 V~`i`~ rotation or skew transform value.
 :::
 ::::

 Since the distance function for rotations is not in terms of the
 rotation center point components, a paced animation that changes the
 rotation center point may not appear to have a paced movement when
 the animation is applied.

Distance functions for all other data types are not defined. If
[calcMode=\"paced\"] is used on an animation of an
attribute or property whose type is not one of those listed above, the
animation effect is undefined. [SVG user
agents](https://svgwg.org/svg2-draft/conform.html#TermUserAgent) may
choose to perform the animation as if
[calcMode=\"linear\"], but this is not required. Authors
are recommended not to specify paced animation on types not listed
above.

### 2.9. Attributes to control the timing of the animation
The following attributes are the [animation timing
attributes]. They are common to all
animation elements and control the timing of the animation, including
what causes the animation to start and end, whether the animation runs
repeatedly, and whether to retain the end state the animation once the
animation ends.

In the syntax specifications that follow, optional white space is
indicated as \"S\", defined as follows:

 S ::= (#x20 | #x9 | #xD | #xA)*

Align with whitespace used in CSS and SVG, adding
#xC to S.

*Attribute definitions:*

 Name Value Initial value Animatable
 ------------------------------------------------------------------------- ------------------------------------------- --------------- ------------
 [begin] [begin-value-list](#BeginValueListSyntax) 0s no

Attribute syntax needs fixing.

Defines when the element should begin (i.e. become active).

The attribute value is a semicolon separated list of values.

begin-value-list ::= [begin-value](#BeginValueSyntax) (S? \";\" S? begin-value-list )?
: A semicolon separated list of begin values. The interpretation of a
 list of begin times is detailed in SMIL Animation\'s section on
 [\"Evaluation of begin and end time
 lists\"](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Timing-EvaluationOfBeginEndTimeLists).

begin-value ::= ( [offset-value](#OffsetValueSyntax) \| [syncbase-value](#SyncbaseValueSyntax) \| [event-value](#EventValueSyntax) \| [repeat-value](#RepeatValueSyntax) \| [accessKey-value](#AccessKeyValueSyntax) \| [wallclock-sync-value](#WallclockSyncValueSyntax) \| [\"indefinite\"](#IndefiniteValue) )
: Describes the element begin.

offset-value ::= ( S? \"+\" \| \"-\" S? )? ( [Clock-value](#ClockValueSyntax) )
: For SMIL Animation, this describes the element begin as an offset
 from an implicit syncbase. For SVG, the implicit syncbase begin is
 defined to be relative to the document begin. Negative begin times
 are entirely valid and easy to compute, as long as there is a
 resolved document begin time.

syncbase-value ::= ( Id-value \".\" ( \"begin\" \| \"end\" ) ) ( S? (\"+\"\|\"-\") S? [Clock-value](#ClockValueSyntax) )?
: Describes a [syncbase] and an optional offset from
 that syncbase. The element begin is defined relative to the begin or
 active end of another animation. A syncbase consists of an ID
 reference to another animation element followed by either `begin` or
 `end` to identify whether to synchronize with the beginning or
 active end of the referenced animation element.

event-value ::= ( Id-value \".\" )? ( event-ref ) ( S? (\"+\"\|\"-\") S? [Clock-value](#ClockValueSyntax) )?
: Describes an event and an optional offset that determine the element
 begin. The animation begin is defined relative to the time that the
 event is raised. The list of event-symbols available for a given
 event-base element is the list of event attributes available for the
 given element as defined in the [Scripting and
 Interactivity](https://svgwg.org/svg2-draft/interact.html) chapter,
 with the one difference that the leading \'on\' is removed from the
 event name (i.e., the animation event name is \'click\', not
 \'onclick\'). A list of all events supported by SVG can be found in
 [Complete list of supported
 events](https://svgwg.org/svg2-draft/interact.html#SVGEvents).
 Details of event-based timing are described in [SMIL Animation:
 Unifying Event-based and Scheduled
 Timing](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Unifying).

repeat-value ::= ( Id-value \".\" )? \"repeat(\" integer \")\" ( S? (\"+\"\|\"-\") S? [Clock-value](#ClockValueSyntax) )?
: Describes a qualified repeat event. The element begin is defined
 relative to the time that the repeat event is raised with the
 specified iteration value.

accessKey-value ::= \"accessKey(\" character \")\" ( S? (\"+\"\|\"-\") S? [Clock-value](#ClockValueSyntax) )?
: Describes an accessKey that determines the element begin. The
 element begin is defined relative to the time that the accessKey
 character is input by the user.

wallclock-sync-value ::= \"wallclock(\" wallclock-value \")\"
: Describes the element begin as a real-world clock time. The
 wallclock time syntax is based upon syntax defined in Representation
 of dates and times \[[ISO8601](#ref-ISO8601)\].

\"indefinite\"

: The begin of the animation will be determined by a
 \"beginElement()\" method call or a hyperlink targeted to the
 element.

 The animation DOM methods are described in [IDL](#IDL).

 Hyperlink-based timing is described in [SMIL Animation: Hyperlinks
 and
 timing](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#HyperlinkSemantics).

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'begin\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#SpecifyingAnimationTarget)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.2.1).

 Name Value Initial value Animatable
 --------------------------------------------------------------------- ----------------------------------------------------------------- --------------- ------------
 [dur] [Clock-value](#ClockValueSyntax) \| \"media\" \| \"indefinite\" indefinite no

Attribute syntax needs fixing.

Specifies the simple duration.

The attribute value can be one of the following:

[Clock-value](#ClockValueSyntax)
: Specifies the length of the simple duration in [presentation
 time](#PresentationTime). Value must be greater than 0.

\"media\"
: Specifies the simple duration as the intrinsic media duration. This
 is only valid for elements that define media.\
 (For SVG\'s [animation elements](#AnimationElements), if
 [\'media\'] is specified, the attribute will be
 ignored.)

\"indefinite\"
: Specifies the simple duration as indefinite.

If the animation does not have a ['[dur](#DurAttribute)']
attribute, the simple duration is indefinite. Note that interpolation
will not work if the simple duration is indefinite (although this may
still be useful for ['[set](#SetElement)'] elements).
Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'dur\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#DurAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.2.1).

 Name Value Initial value Animatable
 --------------------------------------------------------------------- --------------------------------------- --------------- ------------
 [end] [end-value-list](#EndValueListSyntax) (none) no

Attribute syntax needs fixing.

Defines an end value for the animation that can constrain the active
duration. The attribute value is a semicolon separated list of values.

end-value-list ::= [end-value](#EndValueSyntax) (S? \";\" S? end-value-list )?
: A semicolon separated list of end values. The interpretation of a
 list of end times is detailed below.

<!-- -->

end-value ::= ( [offset-value](#OffsetValueSyntax) \| [syncbase-value](#SyncbaseValueSyntax) \| [event-value](#EventValueSyntax) \| [repeat-value](#RepeatValueSyntax) \| [accessKey-value](#AccessKeyValueSyntax) \| [wallclock-sync-value](#WallclockSyncValueSyntax) \| \"indefinite\" )
: Describes the active end of the animation.

A value of [\'indefinite\'] specifies that the end of the
animation will be determined by an
[endElement](#__svg__SVGAnimationElement__endElement) method call (the
animation DOM methods are described in [IDL](#IDL)).

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'end\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#EndActiveAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.3.2).

 Name Value Initial value Animatable
 --------------------------------------------------------------------- ----------------------------------------------- --------------- ------------
 [min] [Clock-value](#ClockValueSyntax) \| \"media\" 0s no
 [max] [Clock-value](#ClockValueSyntax) \| \"media\" (none) no

Attribute syntax needs fixing.

The ['[min](#MinAttribute)'] and
['[max](#MaxAttribute)'] attributes specify the minimum and
maximum value of the active duration, respectively.

The attribute values can be either of the following:

[Clock-value](#ClockValueSyntax)

: Specifies the length of the minimum or maximum value of the active
 duration, measured in local time.

 Value must be greater than 0.

\"media\"
: Specifies the minimum value of the active duration as the intrinsic
 media duration. This is only valid for elements that define media.
 (For SVG\'s [animation elements](#AnimationElements), if
 [\'media\'] is specified, the attribute will be
 ignored.)

The initial value for ['[min](#MinAttribute)'] is
[\'0\'] and there is no initial value for
['[max](#MaxAttribute)']. In both cases, this does not
constrain the active duration at all.

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for these attributes is the
[SMIL Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: The min and max
attributes](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#MinMax)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.3.3).

 Name Value Initial value Animatable
 ----------------------------------------------------------------------------- ---------------------------------- --------------- ------------
 [restart] always \| whenNotActive \| never always no

[always]
: The animation can be restarted at any time. This is the default
 value.

[whenNotActive]
: The animation can only be restarted when it is not active (i.e.
 after the active end). Attempts to restart the animation during its
 active duration are ignored.

[never]
: The element cannot be restarted for the remainder of the current
 simple duration of the parent time container. (In the case of SVG,
 since the parent time container is the SVG document fragment, then
 the animation cannot be restarted for the remainder of the document
 duration.)

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'restart\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#RestartAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.3.7).

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------- ------------------------------------------------------------------------ --------------- ------------
 [repeatCount] [\<number\>](https://www.w3.org/TR/css3-values/#numbers) \| indefinite (none) no

Specifies the number of iterations of the animation function. It can
have the following attribute values:

[\<number\>](https://www.w3.org/TR/css3-values/#numbers)
: This is a (base 10) \"floating point\" numeric value that specifies
 the number of iterations. It can include partial iterations
 expressed as fraction values. A fractional value describes a portion
 of the [simple
 duration](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#SpecifyingAnimationFunction).
 Values must be greater than 0.

indefinite
: The animation is defined to repeat indefinitely (i.e. until the
 document ends).

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'repeatCount\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#RepeatCountAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.3.1).

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------- ---------------------------------------------------- --------------- ------------
 [repeatDur] [Clock-value](#ClockValueSyntax) \| \"indefinite\" (none) no

Attribute syntax needs fixing.

Specifies the total duration for repeat. It can have the following
attribute values:

[Clock-value](#ClockValueSyntax)
: Specifies the duration in [presentation time](#PresentationTime) to
 repeat the animation function **`f(t)`**.

\"indefinite\"
: The animation is defined to repeat indefinitely (i.e. until the
 document ends).

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'repeatDur\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#RepeatDurAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.3.1).

 Name Value Initial value Animatable
 ----------------------------------------------------------------------- ------------------ --------------- ------------
 [fill] freeze \| remove remove no

This attribute can have the following values:

[freeze]
: The animation effect
 [F(t)](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#AnimationModel)
 is defined to freeze the effect value at the last value of the
 active duration. The animation effect is \"frozen\" for the
 remainder of the document duration (or until the animation is
 restarted - see [SMIL Animation: Restarting
 animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Restart)).

[remove]

: The animation effect is removed (no longer applied) when the active
 duration of the animation is over. After the active end of the
 animation, the animation no longer affects the target (unless the
 animation is restarted - see [SMIL Animation: Restarting
 animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Restart)).

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'fill\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#FillAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.3.5).

The [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification \[[SMILANIM](#ref-SMILANIM)\] defines the detailed
processing rules associated with the above attributes. Except for any
SVG-specific rules explicitly mentioned in this specification, the SMIL
Animation specification is the normative definition of the processing
rules for the above attributes.

#### 2.9.1. Clock values
Clock values have the same syntax as in [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification \[[SMILANIM](#ref-SMILANIM)\]. The grammar for clock
values is repeated here:

 Clock-val ::= Full-clock-val | Partial-clock-val
 | Timecount-val
 Full-clock-val ::= Hours ":" Minutes ":" Seconds ("." Fraction)?
 Partial-clock-val ::= Minutes ":" Seconds ("." Fraction)?
 Timecount-val ::= Timecount ("." Fraction)? (Metric)?
 Metric ::= "h" | "min" | "s" | "ms"
 Hours ::= DIGIT+; any positive number
 Minutes ::= 2DIGIT; range from 00 to 59
 Seconds ::= 2DIGIT; range from 00 to 59
 Fraction ::= DIGIT+
 Timecount ::= DIGIT+
 2DIGIT ::= DIGIT DIGIT
 DIGIT ::= [0-9]

For Timecount values, the default metric suffix is \"s\" (for seconds).
No embedded white space is allowed in clock values, although leading and
trailing white space characters will be ignored.

Clock values describe [presentation time](#PresentationTime).

The following are examples of legal clock values:

- Full clock values: \
 `  02:30:03   ` = 2 hours, 30 minutes and 3 seconds\
 `  50:00:10.25` = 50 hours, 10 seconds and 250 milliseconds
- Partial clock value: \
 `  02:33  ` = 2 minutes and 33 seconds\
 `  00:10.5` = 10.5 seconds = 10 seconds and 500 milliseconds
- Timecount values:\
 `  3.2h   ` = 3.2 hours = 3 hours and 12 minutes\
 `  45min  ` = 45 minutes\
 `  30s    ` = 30 seconds\
 `  5ms    ` = 5 milliseconds\
 `  12.467 ` = 12 seconds and 467 milliseconds

Fractional values are just (base 10) floating point definitions of
seconds. Thus:

`  00.5s    ` = 500 milliseconds\
`  00:00.005` = 5 milliseconds

### 2.10. Attributes that define animation values over time
The following attributes are the [animation value
attributes]. They are common to
elements ['[animate](#AnimateElement)'],
['[animateMotion](#AnimateMotionElement)'] and
['[animateTransform](#AnimateTransformElement)']. These
attributes define the values that are assigned to the target attribute
or property over time. The attributes below provide control over the
relative timing of keyframes and the interpolation method between
discrete values.

*Attribute definitions:*

 Name Value Initial value Animatable
 ------------------------------------- --------------------------------------- --------------- ------------
 [calcMode] discrete \| linear \| paced \| spline (none) no

Specifies the interpolation mode for the animation. This can take any of
the following values. The default mode is [\'linear\'],
however if the attribute does not support linear interpolation (e.g. for
strings), the ['[calcMode](#CalcModeAttribute)'] attribute
is ignored and discrete interpolation is used.

[discrete]
: This specifies that the animation function will jump from one value
 to the next without any interpolation.

[linear]
: Simple linear interpolation between values is used to calculate the
 animation function. Except for
 ['[animateMotion](#AnimateMotionElement)'], this is
 the default ['[calcMode](#CalcModeAttribute)'].

[paced]
: Defines interpolation to produce an even pace of change across the
 animation. This is only supported for the data types for which there
 is an appropriate distance function defined, which includes only
 scalar numeric types plus the types listed in [Paced animation and
 complex types](#complexDistances). If [\'paced\'] is
 specified, any ['[keyTimes](#KeyTimesAttribute)'] or
 ['[keySplines](#KeySplinesAttribute)'] will be ignored.
 For ['[animateMotion](#AnimateMotionElement)'], this
 is the default ['[calcMode](#CalcModeAttribute)'].
 Authors are discouraged from using paced animation on types that do
 not have a distance function defined, due to its unpredictable
 behavior in some user agents.

[spline]
: Interpolates from one value in the
 ['[values](#ValuesAttribute)'] list to the next
 according to a time function defined by a cubic Bézier spline. The
 points of the spline are defined in the
 ['[keyTimes](#KeyTimesAttribute)'] attribute, and the
 control points for each interval are defined in the
 ['[keySplines](#KeySplinesAttribute)'] attribute.

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'calcMode\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#CalcModeAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.2.3).

 Name Value Initial value Animatable
 --------------------------------------------------------------------------- ------------- --------------- ------------
 [values] (see below) (none) no

::: ready-for-wider-review
The ['[values](#ValuesAttribute)'] attribute specifies a
sequence of values to use over the course of the animation.

The attribute is parsed as follows:

1. Let `attribute` be the value of the
 ['[values](#ValuesAttribute)'] attribute.
2. Let `values` be a list of strings formed by splitting
 `attribute` at each U+003B SEMICOLON character.
3. Strip any leading and trailing [white space
 characters](https://svgwg.org/svg2-draft/text.html#TermWhiteSpaceCharacter)
 from each value of `values`.
4. Remove the final value in `values` if it is the empty
 string.
5. Parse each value in `values` using the rules for parsing
 the attribute identified by the
 ['[href](#HrefAttribute)'], and
 ['[attributeName](#AttributeNameAttribute)'] attributes.

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'values\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#ValuesAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.2.2).

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------ --------------- ------------
 [keyTimes] [\<number\>](https://www.w3.org/TR/css3-values/#numbers) \[; [\<number\>](https://www.w3.org/TR/css3-values/#numbers)\]\* ;? (none) no

A semicolon-separated list of time values used to control the pacing of
the animation. Each time in the list corresponds to a value in the
['[values](#ValuesAttribute)'] attribute list, and defines
when the value is used in the animation function.

Each time value in the ['[keyTimes](#KeyTimesAttribute)']
list is specified as a floating point value between 0 and 1 (inclusive),
representing a proportional offset into the simple duration of the
animation element.

If the last semicolon separator is followed by either just white space
or no more characters, ignore both the separator and the trailing white
space.

For animations specified with a
['[values](#ValuesAttribute)'] list, the
['[keyTimes](#KeyTimesAttribute)'] attribute if specified
must have exactly as many values as there are in the
['[values](#ValuesAttribute)'] attribute. For from/to/by
animations, the ['[keyTimes](#KeyTimesAttribute)'] attribute
if specified must have two values.

Each successive time value must be greater than or equal to the
preceding time value.

The ['[keyTimes](#KeyTimesAttribute)'] list semantics
depends upon the interpolation mode:

- For linear and spline animation, the first time value in the list must
 be 0, and the last time value in the list must be 1. The key time
 associated with each value defines when the value is set; values are
 interpolated between the key times.
- For discrete animation, the first time value in the list must be 0.
 The time associated with each value defines when the value is set; the
 animation function uses that value until the next time defined in
 ['[keyTimes](#KeyTimesAttribute)'].

If the interpolation mode is [\'paced\'], the
['[keyTimes](#KeyTimesAttribute)'] attribute is ignored.

If there are any errors in the
['[keyTimes](#KeyTimesAttribute)'] specification (bad
values, too many or too few values), the document fragment is in error
(see [error
processing](https://svgwg.org/svg2-draft/implnote.html#ErrorProcessing)).

If the simple duration is indefinite, any
['[keyTimes](#KeyTimesAttribute)'] specification will be
ignored.

Because paced animation interpolation is unspecified for some value
types, authors are encouraged to use [\'linear\'] animation
interpolation with calculated
['[keyTimes](#KeyTimesAttribute)'] to achieve particular
interpolation behavior for these types.

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'keyTimes\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#KeyTimesAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.2.3).

 Name Value Initial value Animatable
 ----------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------- --------------- ------------
 [keySplines] [\<control-point\>](#DataTypeControlPoint) \[; [\<control-point\>](#DataTypeControlPoint)\]\* ;? (none) no

where:

[\<control-point\>] =
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) ,?
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) ,?
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) ,?
[\<number\>](https://www.w3.org/TR/css3-values/#numbers)

A set of Bézier control points associated with the
['[keyTimes](#KeyTimesAttribute)'] list, defining a cubic
Bézier function that controls interval pacing. The attribute value is a
semicolon-separated list of control point descriptions.

If the last semicolon separator is followed by either just white space
or no more characters, ignore both the separator and the trailing white
space.

Each control point description is a set of four values: `x1 y1 x2 y2`,
describing the Bézier control points for one time segment. Note:
[SMIL](http://www.w3.org/TR/2008/REC-SMIL3-20081201/smil-animation.html#adef-keySplines)
allows these values to be separated either by commas with optional
whitespace, or by whitespace alone. The
['[keyTimes](#KeyTimesAttribute)'] values that define the
associated segment are the Bézier \"anchor points\", and the
['[keySplines](#KeySplinesAttribute)'] values are the
control points. Thus, there must be one fewer sets of control points
than there are ['[keyTimes](#KeyTimesAttribute)'].

The values must all be in the range 0 to 1.

This attribute is ignored unless the
['[calcMode](#CalcModeAttribute)'] is set to
[\'spline\'].

If there are any errors in the
['[keySplines](#KeySplinesAttribute)'] specification (bad
values, too many or too few values), the document fragment is in error
(see [error
processing](https://svgwg.org/svg2-draft/implnote.html#ErrorProcessing)).

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'keySplines\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#KeySplinesAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.2.3).

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------------------------------------------- ------------- --------------- ------------
 [from], [to], [by] (see below) (none) no

The ['[from](#FromAttribute)'] and
['[to](#ToAttribute)'] attributes specify the starting and
ending value of the animation, while the
['[by](#ByAttribute)'] attribute specifies a relative offset
value for the animation.

::: ready-for-wider-review
All three attributes must be parsed using the rules for parsing the
attribute identified by the ['[href](#HrefAttribute)'] and
['[attributeName](#AttributeNameAttribute)'] attributes.

For example, if ['[href](#HrefAttribute)'] identified a
['[circle](https://svgwg.org/svg2-draft/shapes.html#CircleElement)']
element and ['[attributeName](#AttributeNameAttribute)'] is
[\'stroke-width\'], then the
['[from](#FromAttribute)'],
['[to](#ToAttribute)'] or ['[by](#ByAttribute)']
attribute is parsed as a
\[[\<percentage\>](https://www.w3.org/TR/css3-values/#percentages) \|
[\<length\>](https://www.w3.org/TR/css3-values/#lengths)\].

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for these attributes is the
[SMIL Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: Animation function
values](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#FromAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.2.2).

The [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification \[[SMILANIM](#ref-SMILANIM)\] defines the detailed
processing rules associated with the above attributes. Except for any
SVG-specific rules explicitly mentioned in this specification, the SMIL
Animation specification is the normative definition of the processing
rules for the above attributes.

The animation values specified in the animation element must be legal
values for the specified attribute. Leading and trailing white space,
and white space before and after semicolon separators, will be ignored.

All values specified must be legal values for the specified attribute
(as defined in the associated namespace). If any values are not legal,
the document fragment is in error (see [error
processing](https://svgwg.org/svg2-draft/implnote.html#ErrorProcessing)).

If a list of values is used, the animation will apply the values in
order over the course of the animation. If a list of
['[values](#ValuesAttribute)'] is specified, any
['[from](#FromAttribute)'],
['[to](#ToAttribute)'] and
['[by](#ByAttribute)'] attribute values are ignored.

The processing rules for the variants of *from/by/to* animations are
described in [Animation function
values](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#AnimFuncValues)
with the following exception.

In order to provide behavior that is intuitive and consistent between
discrete animations with an explicitly specified
['[from](#FromAttribute)'] attribute (e.g. \"from-to
animation\") and those where the underlying value is used (e.g. \"to
animation\"), the behavior of discrete to-animation in SVG deviates from
the definition in SMIL Animation. As with a discrete from-to animation,
a discrete to animation will set the underlying value for the first half
of the simple duration (or, if a
['[keyTimes](#KeyTimesAttribute)'] list is provided, until
the simple duration specified by the second value in the
['[keyTimes](#KeyTimesAttribute)'] list) and the
['[to](#ToAttribute)'] value for the remainder of the simple
duration.

The following figure illustrates the interpretation of the
['[keySplines](#KeySplinesAttribute)'] attribute. Each
diagram illustrates the effect of
['[keySplines](#KeySplinesAttribute)'] settings for a single
interval (i.e. between the associated pairs of values in the
['[keyTimes](#KeyTimesAttribute)'] and
['[values](#ValuesAttribute)'] lists.). The horizontal axis
can be thought of as the input value for the *unit progress* of
interpolation within the interval - i.e. the pace with which
interpolation proceeds along the given interval. The vertical axis is
the resulting value for the *unit progress*, yielded by the function
that the ['[keySplines](#KeySplinesAttribute)'] attribute
defines. Another way of describing this is that the horizontal axis is
the input *unit time* for the interval, and the vertical axis is the
output *unit time*. See also the section [Timing and real-world clock
times](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#TimingAndRealWorldClockTime).

 ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
 ![Example keySplines01 - keySplines of 0 0 1 1 (the default)](images/keySplines01.svg) [keySplines=\"0 0 1 1\" (the default)] ![Example keySplines01 - keySplines of .5 0 .5 1](images/keySplines02.svg) [keySplines=\".5 0 .5 1\"]
 ![Example keySplines01 - keySplines of 0 .75 .25 1](images/keySplines03.svg) [keySplines=\"0 .75 .25 1\"] ![Example keySplines01 - keySplines of 1 0 .25 .25](images/keySplines04.svg)[keySplines=\"1 0 .25 .25\"]
 ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------

 : Examples of [keySplines]
 {style="border-collapse:separate; border-spacing: 20px;"}

To illustrate the calculations, consider the simple example:

 <animate dur="4s" values="10; 20" keyTimes="0; 1"
 calcMode="spline" keySplines={as in table} />

Using the ['[keySplines](#KeySplinesAttribute)'] values for
each of the four cases above, the approximate interpolated values as the
animation proceeds are:

 Value of ['keySplines'] Initial value After 1s After 2s After 3s Final value
 ------------------------------------- --------------- ---------- ---------- ---------- -------------
 0 0 1 1 10.0 12.5 15.0 17.5 20.0
 .5 0 .5 1 10.0 11.0 15.0 19.0 20.0
 0 .75 .25 1 10.0 18.0 19.3 19.8 20.0
 1 0 .25 .25 10.0 10.1 10.6 16.9 20.0

 : keySplines values

For a formal definition of Bézier spline calculation, see
\[[FOLEY-VANDAM](#ref-FOLEY-VANDAM)\], pp. 488-491.

### 2.11. Attributes that control whether animations are additive
It is frequently useful to define animation as an offset or delta to an
attribute\'s value, rather than as absolute values.

A simple \"grow\" animation can increase the width of an object by 10
pixels:

 <rect width="20px" ...>
 <animate attributeName="width" from="0px" to="10px" dur="10s"
 additive="sum"/>
 </rect>

It is frequently useful for repeated animations to build upon the
previous results, accumulating with each iteration.

The following example causes the rectangle to continue to grow with each
repeat of the animation:

 <rect width="20px" ...>
 <animate attributeName="width" from="0px" to="10px" dur="10s"
 additive="sum" accumulate="sum" repeatCount="5"/>
 </rect>

At the end of the first repetition, the rectangle has a width of 30
pixels. At the end of the second repetition, the rectangle has a width
of 40 pixels. At the end of the fifth repetition, the rectangle has a
width of 70 pixels.

For more information about additive animations, see [SMIL Animation:
Additive
animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#AdditiveAnim).
For more information on cumulative animations, see [SMIL Animation:
Controlling behavior of repeating animation - Cumulative
animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Accumulate).

The following attributes are the [animation addition
attributes], which are common to
elements ['[animate](#AnimateElement)'],
['[animateMotion](#AnimateMotionElement)'] and
['[animateTransform](#AnimateTransformElement)'].

*Attribute definitions:*

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------- ---------------- --------------- ------------
 [additive] replace \| sum replace no

Controls whether or not the animation is additive.

[replace]
: Specifies that the animation will override the underlying value of
 the attribute and other lower priority animations. This is the
 default, however the behavior is also affected by the animation
 value attributes ['[by](#ByAttribute)'] and
 ['[to](#ToAttribute)'], as described in [SMIL Animation:
 How from, to and by attributes affect additive
 behavior](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#FromToByAndAdditive).

[sum]
: Specifies that the animation will add to the underlying value of the
 attribute and other lower priority animations.

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'additive\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#AdditiveAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.3.6).

 Name Value Initial value Animatable
 ----------------------------------------------------------------------------------- ------------- --------------- ------------
 [accumulate] none \| sum none no

Controls whether or not the animation is cumulative.

[none]
: Specifies that repeat iterations are not cumulative. This is the
 default.

[sum]
: Specifies that each repeat iteration after the first builds upon the
 last value of the previous iteration.

This attribute is ignored if the target attribute value does not support
addition, or if the animation element does not repeat.

Cumulative animation is not defined for \"*to animation*\".

This attribute will be ignored if the animation function is specified
with only the ['[to](#ToAttribute)'] attribute.

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this attribute is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'accumulate\'
attribute](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#AccumulateAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 3.3.1).

### 2.12. Inheritance
SVG allows both attributes and properties to be animated. If a given
attribute or property is inheritable by descendants, then animations on
a parent element such as a
['[g](https://svgwg.org/svg2-draft/struct.html#GElement)']
element has the effect of propagating the attribute or property
animation values to descendant elements as the animation proceeds; thus,
descendant elements can inherit animated attributes and properties from
their ancestors.

### 2.13. The ['animate'] element
The ['[animate](#AnimateElement)'] element is used to
animate a single attribute or property over time.

This example makes a rectangle repeatedly fade away over 5 seconds:

 <rect>
 <animate attributeName="opacity"
 from="1" to="0" dur="5s" repeatCount="indefinite" />
 </rect>

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this element is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'animate\'
element](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#animateElement)
(\[[SMILANIM](#ref-SMILANIM)\], section 4.1).

:::: element-summary
::: element-summary-name
['[animate]']

Categories:
: [Animation element](#TermAnimationElement)

Content model:
: Any number of the following elements, in any order:
 - [descriptive
 elements](https://svgwg.org/svg2-draft/struct.html#TermDescriptiveElement)[
 ---
 ['[desc](https://svgwg.org/svg2-draft/struct.html#DescElement)'],
 ['[title](https://svgwg.org/svg2-draft/struct.html#TitleElement)'],
 ['[metadata](https://svgwg.org/svg2-draft/struct.html#MetadataElement)']]

 [[script](https://svgwg.org/svg2-draft/interact.html#ScriptElement)]

Attributes:

: - [animation addition attributes](#AdditionAttributes)[ ---
 ['[additive](#AdditiveAttribute)'],
 ['[accumulate](#AccumulateAttribute)']]
 - [animation event attributes](#TermAnimationEventAttribute)[ ---
 ['[onbegin](http://svgwg.org/svg2-draft/interact.html#OnBeginEventAttribute)'],
 ['[onend](http://svgwg.org/svg2-draft/interact.html#OnEndEventAttribute)'],
 ['[onrepeat](http://svgwg.org/svg2-draft/interact.html#OnRepeatEventAttribute)']]
 - [animation target element attributes](#TargetElement)[ ---
 ['[href](#HrefAttribute)']]
 - [animation attribute target attributes](#AttributeNameAttribute)[
 ---
 ['[attributeName](#AttributeNameAttribute)']]
 - [animation timing attributes](#TimingAttributes)[ ---
 ['[begin](#BeginAttribute)'],
 ['[dur](#DurAttribute)'],
 ['[end](#EndAttribute)'],
 ['[min](#MinAttribute)'],
 ['[max](#MaxAttribute)'],
 ['[restart](#RestartAttribute)'],
 ['[repeatCount](#RepeatCountAttribute)'],
 ['[repeatDur](#RepeatDurAttribute)'],
 ['[fill](#FillAttribute)']]
 - [animation value attributes](#ValueAttributes)[ ---
 ['[calcMode](#CalcModeAttribute)'],
 ['[values](#ValuesAttribute)'],
 ['[keyTimes](#KeyTimesAttribute)'],
 ['[keySplines](#KeySplinesAttribute)'],
 ['[from](#FromAttribute)'],
 ['[to](#ToAttribute)'],
 ['[by](#ByAttribute)']]
 - [conditional processing
 attributes](https://svgwg.org/svg2-draft/struct.html#TermConditionalProcessingAttribute)[
 ---
 ['[requiredExtensions](https://svgwg.org/svg2-draft/struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](https://svgwg.org/svg2-draft/struct.html#SystemLanguageAttribute)']]
 - [core
 attributes](https://svgwg.org/svg2-draft/struct.html#TermCoreAttribute)[
 ---
 ['[id](https://svgwg.org/svg2-draft/struct.html#IDAttribute)'],
 ['[tabindex](https://svgwg.org/svg2-draft/struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](https://svgwg.org/svg2-draft/struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](https://svgwg.org/svg2-draft/struct.html#LangAttribute)'],
 ['[xml:space](https://svgwg.org/svg2-draft/struct.html#XMLSpaceAttribute)'],
 ['[class](https://svgwg.org/svg2-draft/styling.html#ClassAttribute)'],
 ['[style](https://svgwg.org/svg2-draft/styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 ---
 ['[oncancel](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncanplay](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncanplaythrough](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onchange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onclick](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onclose](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncopy](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncuechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncut](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondblclick](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondrag](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragend](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragenter](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragexit](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragleave](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragover](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragstart](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondrop](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondurationchange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onemptied](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onended](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onerror](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onfocus](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oninput](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oninvalid](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeydown](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeypress](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeyup](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onload](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadeddata](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadedmetadata](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadstart](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmousedown](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseenter](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseleave](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmousemove](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseout](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseover](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseup](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onpaste](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onpause](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onplay](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onplaying](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onprogress](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onratechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onreset](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onresize](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onscroll](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onseeked](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onseeking](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onselect](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onshow](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onstalled](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onsubmit](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onsuspend](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ontimeupdate](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ontoggle](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onvolumechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onwaiting](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onwheel](https://svgwg.org/svg2-draft/interact.html#EventAttributes)']]
 - [presentation
 attributes](https://svgwg.org/svg2-draft/styling.html#TermPresentationAttribute)[
 --- ]

DOM Interfaces:

: - [SVGAnimateElement](#InterfaceSVGAnimateElement)

[color-interpolation](https://svgwg.org/svg2-draft/painting.html#ColorInterpolationProperty)
property applies to color interpolations that result from animations
using the ['[animate](#AnimateElement)'] element.

For a list of attributes and properties that can be animated using the
['[animate](#AnimateElement)'] element, see [Elements,
attributes and properties that can be
animated](#AnimationAttributesAndProperties).

### 2.14. The ['set'] element
The ['[set](#SetElement)'] element provides a simple
means of just setting the value of an attribute for a specified
duration. It supports all attribute types, including those that cannot
reasonably be interpolated, such as string and boolean values. The
['[set](#SetElement)'] element is non-additive. The
additive and accumulate attributes are not allowed, and will be ignored
if specified.

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this element is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'set\'
element](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#setElement)
(\[[SMILANIM](#ref-SMILANIM)\], section 4.2).

:::: element-summary
::: element-summary-name
['[set]']

Categories:
: [Animation element](#TermAnimationElement)

Content model:
: Any number of the following elements, in any order:
 - [descriptive
 elements](https://svgwg.org/svg2-draft/struct.html#TermDescriptiveElement)[
 ---
 ['[desc](https://svgwg.org/svg2-draft/struct.html#DescElement)'],
 ['[title](https://svgwg.org/svg2-draft/struct.html#TitleElement)'],
 ['[metadata](https://svgwg.org/svg2-draft/struct.html#MetadataElement)']]

 [[script](https://svgwg.org/svg2-draft/interact.html#ScriptElement)]

Attributes:

: - [animation event attributes](#TermAnimationEventAttribute)[ ---
 ['[onbegin](http://svgwg.org/svg2-draft/interact.html#OnBeginEventAttribute)'],
 ['[onend](http://svgwg.org/svg2-draft/interact.html#OnEndEventAttribute)'],
 ['[onrepeat](http://svgwg.org/svg2-draft/interact.html#OnRepeatEventAttribute)']]
 - [animation target element attributes](#TargetElement)[ ---
 ['[href](#HrefAttribute)']]
 - [animation attribute target attributes](#AttributeNameAttribute)[
 ---
 ['[attributeName](#AttributeNameAttribute)']]
 - [animation timing attributes](#TimingAttributes)[ ---
 ['[begin](#BeginAttribute)'],
 ['[dur](#DurAttribute)'],
 ['[end](#EndAttribute)'],
 ['[min](#MinAttribute)'],
 ['[max](#MaxAttribute)'],
 ['[restart](#RestartAttribute)'],
 ['[repeatCount](#RepeatCountAttribute)'],
 ['[repeatDur](#RepeatDurAttribute)'],
 ['[fill](#FillAttribute)']]
 - [conditional processing
 attributes](https://svgwg.org/svg2-draft/struct.html#TermConditionalProcessingAttribute)[
 ---
 ['[requiredExtensions](https://svgwg.org/svg2-draft/struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](https://svgwg.org/svg2-draft/struct.html#SystemLanguageAttribute)']]
 - [core
 attributes](https://svgwg.org/svg2-draft/struct.html#TermCoreAttribute)[
 ---
 ['[id](https://svgwg.org/svg2-draft/struct.html#IDAttribute)'],
 ['[tabindex](https://svgwg.org/svg2-draft/struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](https://svgwg.org/svg2-draft/struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](https://svgwg.org/svg2-draft/struct.html#LangAttribute)'],
 ['[xml:space](https://svgwg.org/svg2-draft/struct.html#XMLSpaceAttribute)'],
 ['[class](https://svgwg.org/svg2-draft/styling.html#ClassAttribute)'],
 ['[style](https://svgwg.org/svg2-draft/styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 ---
 ['[oncancel](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncanplay](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncanplaythrough](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onchange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onclick](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onclose](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncopy](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncuechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncut](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondblclick](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondrag](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragend](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragenter](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragexit](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragleave](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragover](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragstart](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondrop](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondurationchange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onemptied](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onended](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onerror](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onfocus](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oninput](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oninvalid](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeydown](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeypress](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeyup](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onload](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadeddata](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadedmetadata](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadstart](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmousedown](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseenter](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseleave](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmousemove](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseout](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseover](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseup](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onpaste](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onpause](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onplay](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onplaying](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onprogress](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onratechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onreset](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onresize](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onscroll](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onseeked](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onseeking](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onselect](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onshow](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onstalled](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onsubmit](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onsuspend](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ontimeupdate](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ontoggle](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onvolumechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onwaiting](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onwheel](https://svgwg.org/svg2-draft/interact.html#EventAttributes)']]
 - ['[to](#SetElementToAttribute)']

DOM Interfaces:

: - [SVGSetElement](#InterfaceSVGSetElement)

*Attribute definitions:*

 Name Value Initial value Animatable
 ------------------------------------------------------------------------- ----------- --------------- ------------
 [to] \<value\> (none) no

Specifies the value for the attribute during the duration of the
['[set](#SetElement)'] element. The argument value must
match the attribute type.

For a list of attributes and properties that can be animated using the
['[set](#SetElement)'] element, see [Elements, attributes
and properties that can be animated](#AnimationAttributesAndProperties).

### 2.15. The ['animateMotion'] element
The ['[animateMotion](#AnimateMotionElement)'] element
causes a referenced element to move along a motion path.

Except for any SVG-specific rules explicitly mentioned in this
specification, the normative definition for this element is the [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/)
specification. In particular, see [SMIL Animation: \'animateMotion\'
element](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#animateMotionElement)
(\[[SMILANIM](#ref-SMILANIM)\], section 4.3).

:::: element-summary
::: element-summary-name
['[animateMotion]']

Categories:
: [Animation element](#TermAnimationElement)

Content model:
: Any number of [descriptive
 elements](https://svgwg.org/svg2-draft/struct.html#TermDescriptiveElement),
 ['[script](https://svgwg.org/svg2-draft/interact.html#ScriptElement)']
 and at most one ['[mpath](#MPathElement)'] element,
 in any order.

Attributes:

: - [animation addition attributes](#AdditionAttributes)[ ---
 ['[additive](#AdditiveAttribute)'],
 ['[accumulate](#AccumulateAttribute)']]
 - [animation event attributes](#TermAnimationEventAttribute)[ ---
 ['[onbegin](http://svgwg.org/svg2-draft/interact.html#OnBeginEventAttribute)'],
 ['[onend](http://svgwg.org/svg2-draft/interact.html#OnEndEventAttribute)'],
 ['[onrepeat](http://svgwg.org/svg2-draft/interact.html#OnRepeatEventAttribute)']]
 - [animation target element attributes](#TargetElement)[ ---
 ['[href](#HrefAttribute)']]
 - [animation timing attributes](#TimingAttributes)[ ---
 ['[begin](#BeginAttribute)'],
 ['[dur](#DurAttribute)'],
 ['[end](#EndAttribute)'],
 ['[min](#MinAttribute)'],
 ['[max](#MaxAttribute)'],
 ['[restart](#RestartAttribute)'],
 ['[repeatCount](#RepeatCountAttribute)'],
 ['[repeatDur](#RepeatDurAttribute)'],
 ['[fill](#FillAttribute)']]
 - [animation value attributes](#ValueAttributes)[ ---
 ['[calcMode](#CalcModeAttribute)'],
 ['[values](#ValuesAttribute)'],
 ['[keyTimes](#KeyTimesAttribute)'],
 ['[keySplines](#KeySplinesAttribute)'],
 ['[from](#FromAttribute)'],
 ['[to](#ToAttribute)'],
 ['[by](#ByAttribute)']]
 - [conditional processing
 attributes](https://svgwg.org/svg2-draft/struct.html#TermConditionalProcessingAttribute)[
 ---
 ['[requiredExtensions](https://svgwg.org/svg2-draft/struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](https://svgwg.org/svg2-draft/struct.html#SystemLanguageAttribute)']]
 - [core
 attributes](https://svgwg.org/svg2-draft/struct.html#TermCoreAttribute)[
 ---
 ['[id](https://svgwg.org/svg2-draft/struct.html#IDAttribute)'],
 ['[tabindex](https://svgwg.org/svg2-draft/struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](https://svgwg.org/svg2-draft/struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](https://svgwg.org/svg2-draft/struct.html#LangAttribute)'],
 ['[xml:space](https://svgwg.org/svg2-draft/struct.html#XMLSpaceAttribute)'],
 ['[class](https://svgwg.org/svg2-draft/styling.html#ClassAttribute)'],
 ['[style](https://svgwg.org/svg2-draft/styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 ---
 ['[oncancel](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncanplay](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncanplaythrough](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onchange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onclick](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onclose](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncopy](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncuechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncut](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondblclick](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondrag](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragend](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragenter](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragexit](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragleave](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragover](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragstart](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondrop](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondurationchange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onemptied](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onended](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onerror](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onfocus](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oninput](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oninvalid](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeydown](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeypress](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeyup](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onload](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadeddata](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadedmetadata](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadstart](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmousedown](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseenter](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseleave](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmousemove](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseout](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseover](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseup](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onpaste](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onpause](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onplay](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onplaying](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onprogress](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onratechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onreset](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onresize](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onscroll](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onseeked](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onseeking](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onselect](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onshow](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onstalled](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onsubmit](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onsuspend](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ontimeupdate](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ontoggle](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onvolumechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onwaiting](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onwheel](https://svgwg.org/svg2-draft/interact.html#EventAttributes)']]
 - ['[path](#AnimateMotionElementPathAttribute)']
 - ['[keyPoints](#KeyPointsAttribute)']
 - ['[rotate](#RotateAttribute)']
 - ['[origin](#OriginAttribute)']

DOM Interfaces:

: - [SVGAnimateMotionElement](#InterfaceSVGAnimateMotionElement)

*Attribute definitions:*

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------------------------------- --------------------------------------- --------------- ------------
 [calcMode] discrete \| linear \| paced \| spline paced no

Specifies the interpolation mode for the animation. Refer to general
description of the ['[calcMode](#CalcModeAttribute)']
attribute above. The only difference is that the default value for the
['[calcMode](#CalcModeAttribute)'] for
['[animateMotion](#AnimateMotionElement)'] is
[\'paced\']. See [SMIL Animation: \'calcMode\' attribute
for
\'animateMotion\'](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#MotionCalcModeAttribute).

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------- --------------- ------------
 [path] [svg-path](https://svgwg.org/svg2-draft/paths.html#PathDataBNF) [\[EBNF\]](https://svgwg.org/svg2-draft/types.html#syntax) (none) no

The motion path, expressed in the same format and interpreted the same
way as the
[d](https://svgwg.org/svg2-draft/paths.html#DProperty)
geometric property for the
['[path](https://svgwg.org/svg2-draft/paths.html#PathElement)']
element. The effect of a motion path animation is to add a supplemental
transformation matrix onto the
[CTM](https://www.w3.org/TR/css-transforms-1/#current-transformation-matrix)
for the referenced object which causes a translation along the x- and
y-axes of the current user coordinate system by the computed X and Y
values computed over time.

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------ --------------- ------------
 [keyPoints] [\<number\>](https://www.w3.org/TR/css3-values/#numbers) \[; [\<number\>](https://www.w3.org/TR/css3-values/#numbers)\]\* ;? (none) no

['[keyPoints](#KeyPointsAttribute)'] takes a
semicolon-separated list of floating point values between 0 and 1 and
indicates how far along the motion path the object shall move at the
moment in time specified by corresponding
['[keyTimes](#KeyTimesAttribute)'] value. Distance
calculations use the user agent\'s [distance along the
path](https://svgwg.org/svg2-draft/paths.html#DistanceAlongAPath)
algorithm. Each progress value in the list corresponds to a value in the
['[keyTimes](#KeyTimesAttribute)'] attribute list.

If a list of ['[keyPoints](#KeyPointsAttribute)'] is
specified, there must be exactly as many values in the
['[keyPoints](#KeyPointsAttribute)'] list as in the
['[keyTimes](#KeyTimesAttribute)'] list.

If the last semicolon separator is followed by either just white space
or no more characters, ignore both the separator and the trailing white
space.

If there are any errors in the
['[keyPoints](#KeyPointsAttribute)'] specification (bad
values, too many or too few values), then the document is in error (see
[Error
processing](https://svgwg.org/svg2-draft/implnote.html#ErrorProcessing)).

 Name Value Initial value Animatable
 --------------------------------------------------------------------------- ---------------------------------------------------------------------------------- --------------- ------------
 [rotate] [\<number\>](https://www.w3.org/TR/css3-values/#numbers) \| auto \| auto-reverse 0 no

The ['[rotate](#RotateAttribute)'] attribute post-multiplies
a supplemental transformation matrix onto the
[CTM](https://www.w3.org/TR/css-transforms-1/#current-transformation-matrix)
of the target element to apply a rotation transformation about the
origin of the current user coordinate system. The rotation
transformation is applied after the supplemental translation
transformation that is computed due to the
['[path](#AnimateMotionElementPathAttribute)'] attribute.

[auto]
: Indicates that the object is rotated over time by the angle of the
 direction (i.e., directional tangent vector) of the motion path.

[auto-reverse]
: Indicates that the object is rotated over time by the angle of the
 direction (i.e., directional tangent vector) of the motion path plus
 180 degrees.

[[\<number\>](https://www.w3.org/TR/css3-values/#numbers)]
: Indicates that the target element has a constant rotation
 transformation applied to it, where the rotation angle is the
 specified number of degrees.

 Name Value Initial value Animatable
 --------------------------------------------------------------------------- --------- --------------- ------------
 [origin] default default no

The ['[origin](#OriginAttribute)'] attribute is [defined in
the SMIL Animation
specification](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#MotionOriginAttribute)
(\[[SMILANIM](#ref-SMILANIM)\], section 4.3). It has no effect in SVG.

:::: element-summary
::: element-summary-name
['[mpath]']

Categories:
: None

Content model:
: Any number of the following elements, in any order:
 - [descriptive
 elements](https://svgwg.org/svg2-draft/struct.html#TermDescriptiveElement)[
 ---
 ['[desc](https://svgwg.org/svg2-draft/struct.html#DescElement)'],
 ['[title](https://svgwg.org/svg2-draft/struct.html#TitleElement)'],
 ['[metadata](https://svgwg.org/svg2-draft/struct.html#MetadataElement)']]

 [[script](https://svgwg.org/svg2-draft/interact.html#ScriptElement)]

Attributes:

: - [core
 attributes](https://svgwg.org/svg2-draft/struct.html#TermCoreAttribute)[
 ---
 ['[id](https://svgwg.org/svg2-draft/struct.html#IDAttribute)'],
 ['[tabindex](https://svgwg.org/svg2-draft/struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](https://svgwg.org/svg2-draft/struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](https://svgwg.org/svg2-draft/struct.html#LangAttribute)'],
 ['[xml:space](https://svgwg.org/svg2-draft/struct.html#XMLSpaceAttribute)'],
 ['[class](https://svgwg.org/svg2-draft/styling.html#ClassAttribute)'],
 ['[style](https://svgwg.org/svg2-draft/styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 ---
 ['[oncancel](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncanplay](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncanplaythrough](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onchange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onclick](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onclose](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncopy](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncuechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncut](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondblclick](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondrag](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragend](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragenter](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragexit](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragleave](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragover](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragstart](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondrop](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondurationchange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onemptied](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onended](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onerror](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onfocus](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oninput](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oninvalid](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeydown](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeypress](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeyup](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onload](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadeddata](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadedmetadata](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadstart](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmousedown](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseenter](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseleave](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmousemove](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseout](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseover](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseup](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onpaste](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onpause](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onplay](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onplaying](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onprogress](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onratechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onreset](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onresize](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onscroll](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onseeked](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onseeking](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onselect](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onshow](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onstalled](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onsubmit](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onsuspend](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ontimeupdate](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ontoggle](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onvolumechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onwaiting](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onwheel](https://svgwg.org/svg2-draft/interact.html#EventAttributes)']]
 - ['[href](#MPathElementHrefAttribute)']

DOM Interfaces:

: - [SVGMPathElement](#InterfaceSVGMPathElement)

*Attribute definitions:*

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------- ------------------------------------------------------------------------------- --------------- ------------
 [href] URL [\[URL\]](https://svgwg.org/svg2-draft/types.html#attribute-url) (none) no

A [URL
reference](https://svgwg.org/svg2-draft/linking.html#TermURLReference)
to the
['[path](https://svgwg.org/svg2-draft/paths.html#PathElement)']
element or
[shape](https://svgwg.org/svg2-draft/shapes.html#TermShapeElement)
element which defines the motion path. Refer to the common handling
defined for [URL reference
attributes](https://svgwg.org/svg2-draft/linking.html#linkRefAttrs) and
[deprecated XLink
attributes](https://svgwg.org/svg2-draft/linking.html#XLinkRefAttrs).

For ['[animateMotion](#AnimateMotionElement)'], the
specified values for ['[from](#FromAttribute)'],
['[by](#ByAttribute)'], ['[to](#ToAttribute)']
and ['[values](#ValuesAttribute)'] consists of x, y
coordinate pairs, with a single comma and/or white space separating the
x coordinate from the y coordinate. For example,
[from=\"33,15\"] specifies an x coordinate value of
[33] and a y coordinate value of [15].

If provided, the ['[values](#ValuesAttribute)'] attribute
must consists of a list of x, y coordinate pairs. Coordinate values are
separated by at least one white space character or a comma. Additional
white space around the separator is allowed. For example,
[values=\"10,20;30,20;30,40\"] or
[values=\"10mm,20mm;30mm,20mm;30mm,40mm\"]. Each coordinate
represents a [\<length\>](https://www.w3.org/TR/css3-values/#lengths).
Attributes ['[from](#FromAttribute)'],
['[by](#ByAttribute)'], ['[to](#ToAttribute)']
and ['[values](#ValuesAttribute)'] specify a shape on the
current canvas which represents the motion path.

Two options are available which allow definition of a motion path using
any of SVG\'s [path
data](https://svgwg.org/svg2-draft/paths.html#PathData) commands:

- the ['[path](#AnimateMotionElementPathAttribute)']
 attribute defines a motion path directly on
 ['[animateMotion](#AnimateMotionElement)'] element
 using any of SVG\'s [path
 data](https://svgwg.org/svg2-draft/paths.html#PathData) commands.
- the ['[mpath](#MPathElement)'] sub-element provides the
 ability to reference an external
 ['[path](https://svgwg.org/svg2-draft/paths.html#PathElement)']
 element or
 [shape](https://svgwg.org/svg2-draft/shapes.html#TermShapeElement)
 element as the definition of the motion path. If the
 ['[mpath](#MPathElement)'] sub-element refers to a
 [shape](https://svgwg.org/svg2-draft/shapes.html#TermShapeElement)
 element, the motion path is defined by the [equivalent
 path](https://svgwg.org/svg2-draft/paths.html#TermEquivalentPath) of
 the [shape](https://svgwg.org/svg2-draft/shapes.html#TermShapeElement)
 element.

Note that SVG\'s [path
data](https://svgwg.org/svg2-draft/paths.html#PathData) commands can
only contain values in local coordinate system, whereas
['[from](#FromAttribute)'],
['[by](#ByAttribute)'], ['[to](#ToAttribute)']
and ['[values](#ValuesAttribute)'] can specify coordinates
in local coordinate system or using unit identifiers. See
[Units](https://svgwg.org/svg2-draft/coords.html#Units).

The various (x,y) points of the shape provide a supplemental
transformation matrix onto the
[CTM](https://www.w3.org/TR/css-transforms-1/#current-transformation-matrix)
for the referenced object which causes a translation along the x- and
y-axes of the current user coordinate system by the (x,y) values of the
shape computed over time. Thus, the referenced object is translated over
time by the offset of the motion path relative to the origin of the
current user coordinate system. The supplemental transformation is
applied on top of any transformations due to the target element\'s
[transform](https://svgwg.org/svg2-draft/coords.html#TransformProperty)
property or any animations on that attribute due to
['[animateTransform](#AnimateTransformElement)'] elements
on the target element.

The ['[additive](#AdditiveAttribute)'] and
['[accumulate](#AccumulateAttribute)'] attributes apply to
['[animateMotion](#AnimateMotionElement)'] elements.
Multiple ['[animateMotion](#AnimateMotionElement)']
elements all simultaneously referencing the same target element can be
additive with respect to each other; however, the transformations which
result from the
['[animateMotion](#AnimateMotionElement)'] elements are
always supplemental to any transformations due to the target element\'s
[transform](https://svgwg.org/svg2-draft/coords.html#TransformProperty)
property or any
['[animateTransform](#AnimateTransformElement)']
elements.

The default calculation mode
(['[calcMode](#CalcModeAttribute)']) for
['[animateMotion](#AnimateMotionElement)'] is \"paced\".
This will produce constant velocity motion along the specified path.
Note that while animateMotion elements can be additive, it is important
to observe that the addition of two or more \"paced\" (constant
velocity) animations might not result in a combined motion animation
with constant velocity.

When a path is combined with \"discrete\", \"linear\" or \"spline\"
['[calcMode](#CalcModeAttribute)'] settings, and if
attribute ['[keyPoints](#KeyPointsAttribute)'] is not
provided, the number of values is defined to be the number of points
defined by the path, unless there are \"move to\" commands within the
path. A \"move to\" command within the path (i.e. other than at the
beginning of the path description) A \"move to\" command does not count
as an additional point when dividing up the duration, or when
associating ['[keyTimes](#KeyTimesAttribute)'],
['[keySplines](#KeySplinesAttribute)'] and
['[keyPoints](#KeyPointsAttribute)'] values. When a path is
combined with a \"paced\" ['[calcMode](#CalcModeAttribute)']
setting, all \"move to\" commands are considered to have 0 length (i.e.
they always happen instantaneously), and is not considered in computing
the pacing.

For more flexibility in controlling the velocity along the motion path,
the ['[keyPoints](#KeyPointsAttribute)'] attribute provides
the ability to specify the progress along the motion path for each of
the ['[keyTimes](#KeyTimesAttribute)'] specified values. If
specified, ['[keyPoints](#KeyPointsAttribute)'] causes
['[keyTimes](#KeyTimesAttribute)'] to apply to the values in
['[keyPoints](#KeyPointsAttribute)'] rather than the points
specified in the ['[values](#ValuesAttribute)'] attribute
array or the points on the
['[path](#AnimateMotionElementPathAttribute)'] attribute.

The override rules for
['[animateMotion](#AnimateMotionElement)'] are as
follows. Regarding the definition of the motion path, the
['[mpath](#MPathElement)'] element overrides the
['[path](#AnimateMotionElementPathAttribute)'] attribute,
which overrides ['[values](#ValuesAttribute)'], which
overrides ['[from](#FromAttribute)'],
['[by](#ByAttribute)'] and
['[to](#ToAttribute)']. Regarding determining the points
which correspond to the ['[keyTimes](#KeyTimesAttribute)']
attributes, the ['[keyPoints](#KeyPointsAttribute)']
attribute overrides
['[path](#AnimateMotionElementPathAttribute)'], which
overrides ['[values](#ValuesAttribute)'], which overrides
['[from](#FromAttribute)'],
['[by](#ByAttribute)'] and
['[to](#ToAttribute)'].

At any time *t* within a motion path animation of duration *dur*, the
computed coordinate (x,y) along the motion path is determined by finding
the point (x,y) which is *t/dur* distance along the motion path using
the user agent\'s [distance along the
path](https://svgwg.org/svg2-draft/paths.html#DistanceAlongAPath)
algorithm.

The following example demonstrates the supplemental transformation
matrices that are computed during a motion path animation.

[Example animMotion01] shows a triangle moving along a
motion path.

 <?xml version="1.0" standalone="no"?>
 <svg width="5cm" height="3cm" viewBox="0 0 500 300"
 xmlns="http://www.w3.org/2000/svg">
 <desc>Example animMotion01 - demonstrate motion animation computations</desc>
 <rect x="1" y="1" width="498" height="298"
 fill="none" stroke="blue" stroke-width="2" />
 <!-- Draw the outline of the motion path in blue, along
 with three small circles at the start, middle and end. -->
 <path id="path1" d="M100,250 C 100,50 400,50 400,250"
 fill="none" stroke="blue" stroke-width="7.06" />
 <circle cx="100" cy="250" r="17.64" fill="blue" />
 <circle cx="250" cy="100" r="17.64" fill="blue" />
 <circle cx="400" cy="250" r="17.64" fill="blue" />
 <!-- Here is a triangle which will be moved about the motion path.
 It is defined with an upright orientation with the base of
 the triangle centered horizontally just above the origin. -->
 <path d="M-25,-12.5 L25,-12.5 L 0,-87.5 z"
 fill="yellow" stroke="red" stroke-width="7.06" >
 <!-- Define the motion path animation -->
 <animateMotion dur="6s" repeatCount="indefinite" rotate="auto" >
 <mpath href="#path1"/>
 </animateMotion>
 </path>
 </svg>

 ------------------------------------------------ ------------------------------------------------ ------------------------------------------------
 ![Example animMotion01 - at zero ![Example animMotion01 - at three ![Example animMotion01 - at six
 seconds](images/animMotion01a.png){width="144" seconds](images/animMotion01b.png){width="144" seconds](images/animMotion01c.png){width="144"
 height="91"}\ height="91"}\ height="91"}\
 [At zero seconds] [At three seconds] [At six seconds]

 ------------------------------------------------ ------------------------------------------------ ------------------------------------------------

 : Example animMotion01

[View this example as SVG (SVG-enabled browsers
only)](images/animMotion01.svg)

The following table shows the supplemental transformation matrices that
are applied to achieve the effect of the motion path animation.

 After 0s After 3s After 6s
 -------------------------------------------------------------- -------------------- -------------------- --------------------
 Supplemental transform due to movement along motion path translate(100,250) translate(250,100) translate(400,250)
 Supplemental transform due to [rotate=\"auto\"] rotate(-90) rotate(0) rotate(90)

 : Example animMotion01 time slices

For a list of elements that can be animated using the
['[animateMotion](#AnimateMotionElement)'] element, see
[Elements, attributes and properties that can be
animated](#AnimationAttributesAndProperties).

### 2.16. The ['animateTransform'] element
The ['[animateTransform](#AnimateTransformElement)']
element animates a transformation attribute on a target element, thereby
allowing animations to control translation, scaling, rotation and/or
skewing.

This section should talk about the
[transform](https://svgwg.org/svg2-draft/coords.html#TransformProperty)
property.

:::: element-summary
::: element-summary-name
['[animateTransform]']

Categories:
: [Animation element](#TermAnimationElement)

Content model:
: Any number of the following elements, in any order:
 - [descriptive
 elements](https://svgwg.org/svg2-draft/struct.html#TermDescriptiveElement)[
 ---
 ['[desc](https://svgwg.org/svg2-draft/struct.html#DescElement)'],
 ['[title](https://svgwg.org/svg2-draft/struct.html#TitleElement)'],
 ['[metadata](https://svgwg.org/svg2-draft/struct.html#MetadataElement)']]

 [[script](https://svgwg.org/svg2-draft/interact.html#ScriptElement)]

Attributes:

: - [animation addition attributes](#AdditionAttributes)[ ---
 ['[additive](#AdditiveAttribute)'],
 ['[accumulate](#AccumulateAttribute)']]
 - [animation event attributes](#TermAnimationEventAttribute)[ ---
 ['[onbegin](http://svgwg.org/svg2-draft/interact.html#OnBeginEventAttribute)'],
 ['[onend](http://svgwg.org/svg2-draft/interact.html#OnEndEventAttribute)'],
 ['[onrepeat](http://svgwg.org/svg2-draft/interact.html#OnRepeatEventAttribute)']]
 - [animation target element attributes](#TargetElement)[ ---
 ['[href](#HrefAttribute)']]
 - [animation attribute target attributes](#AttributeNameAttribute)[
 ---
 ['[attributeName](#AttributeNameAttribute)']]
 - [animation timing attributes](#TimingAttributes)[ ---
 ['[begin](#BeginAttribute)'],
 ['[dur](#DurAttribute)'],
 ['[end](#EndAttribute)'],
 ['[min](#MinAttribute)'],
 ['[max](#MaxAttribute)'],
 ['[restart](#RestartAttribute)'],
 ['[repeatCount](#RepeatCountAttribute)'],
 ['[repeatDur](#RepeatDurAttribute)'],
 ['[fill](#FillAttribute)']]
 - [animation value attributes](#ValueAttributes)[ ---
 ['[calcMode](#CalcModeAttribute)'],
 ['[values](#ValuesAttribute)'],
 ['[keyTimes](#KeyTimesAttribute)'],
 ['[keySplines](#KeySplinesAttribute)'],
 ['[from](#FromAttribute)'],
 ['[to](#ToAttribute)'],
 ['[by](#ByAttribute)']]
 - [conditional processing
 attributes](https://svgwg.org/svg2-draft/struct.html#TermConditionalProcessingAttribute)[
 ---
 ['[requiredExtensions](https://svgwg.org/svg2-draft/struct.html#RequiredExtensionsAttribute)'],
 ['[systemLanguage](https://svgwg.org/svg2-draft/struct.html#SystemLanguageAttribute)']]
 - [core
 attributes](https://svgwg.org/svg2-draft/struct.html#TermCoreAttribute)[
 ---
 ['[id](https://svgwg.org/svg2-draft/struct.html#IDAttribute)'],
 ['[tabindex](https://svgwg.org/svg2-draft/struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](https://svgwg.org/svg2-draft/struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](https://svgwg.org/svg2-draft/struct.html#LangAttribute)'],
 ['[xml:space](https://svgwg.org/svg2-draft/struct.html#XMLSpaceAttribute)'],
 ['[class](https://svgwg.org/svg2-draft/styling.html#ClassAttribute)'],
 ['[style](https://svgwg.org/svg2-draft/styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 ---
 ['[oncancel](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncanplay](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncanplaythrough](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onchange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onclick](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onclose](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncopy](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncuechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oncut](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondblclick](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondrag](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragend](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragenter](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragexit](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragleave](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragover](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondragstart](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondrop](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ondurationchange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onemptied](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onended](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onerror](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onfocus](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oninput](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[oninvalid](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeydown](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeypress](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onkeyup](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onload](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadeddata](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadedmetadata](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onloadstart](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmousedown](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseenter](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseleave](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmousemove](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseout](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseover](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onmouseup](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onpaste](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onpause](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onplay](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onplaying](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onprogress](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onratechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onreset](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onresize](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onscroll](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onseeked](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onseeking](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onselect](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onshow](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onstalled](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onsubmit](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onsuspend](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ontimeupdate](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[ontoggle](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onvolumechange](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onwaiting](https://svgwg.org/svg2-draft/interact.html#EventAttributes)'],
 ['[onwheel](https://svgwg.org/svg2-draft/interact.html#EventAttributes)']]
 - ['[type](#AnimateTransformElementTypeAttribute)']

DOM Interfaces:

: - [SVGAnimateTransformElement](#InterfaceSVGAnimateTransformElement)

*Attribute definitions:*

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------------------------- ------------------------------------------------ --------------- ------------
 [type] translate \| scale \| rotate \| skewX \| skewY translate no

Indicates the type of transformation which is to have its values change
over time.

The ['[from](#FromAttribute)'],
['[by](#ByAttribute)'] and
['[to](#ToAttribute)'] attributes take a value expressed
using the same syntax that is available for the given transformation
type:

- For a [type=\"translate\"], each individual value is
 expressed as [\<tx\> \[,\<ty\>\]].
- For a [type=\"scale\"], each individual value is
 expressed as [\<sx\> \[,\<sy\>\]].
- For a [type=\"rotate\"], each individual value is
 expressed as [\<rotate-angle\> \[\<cx\> \<cy\>\]].
- For a [type=\"skewX\"] and [type=\"skewY\"],
 each individual value is expressed as [\<skew-angle\>].

(See [The '[transform]'
property](https://svgwg.org/svg2-draft/coords.html#TransformProperty).)

The ['[values](#ValuesAttribute)'] attribute for the
['[animateTransform](#AnimateTransformElement)'] element
consists of a semicolon-separated list of values, where each individual
value is expressed as described above for
['[from](#FromAttribute)'],
['[by](#ByAttribute)'] and
['[to](#ToAttribute)'].

The animation effect for
['[animateTransform](#AnimateTransformElement)'] is
post-multiplied to the underlying value for additive
['[animateTransform](#AnimateTransformElement)']
animations (see below) instead of added to the underlying value, due to
the specific behavior of
['[animateTransform](#AnimateTransformElement)'].

*From-to*, *from-by* and *by animations* are defined in SMIL to be
equivalent to a corresponding *values animation*. See the [Animation
function
values](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#AnimFuncValues)
section of SMIL Animation (\[[SMILANIM](#ref-SMILANIM)\], section
3.2.2). However, *to animations* are a mixture of additive and
non-additive behavior, as described in the [How from, to and by
attributes affect additive
behavior](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#FromToByAndAdditive)
section of SMIL Animation (\[[SMILANIM](#ref-SMILANIM)\], section
3.3.6). *To animations* provide specific functionality to get a smooth
change from the underlying value to the
['[to](#ToAttribute)'] attribute value, which conflicts
mathematically with the requirement for additive transform animations to
be post-multiplied. As a consequence, in SVG 1.1 the behavior of *to
animations* for
['[animateTransform](#AnimateTransformElement)'] is
undefined. Authors are suggested to use *from-to*, *from-by*, *by* or
*values animations* to achieve any desired transform animation.

If [['calcMode']](#CalcModeAttribute) has the value
[\'paced\'], then the \"distance\" for the transformation
is calculated as further described in [Paced animations and complex
types](#complexDistances).

When an animation is active, the effect of non-additive
['[animateTransform](#AnimateTransformElement)'] (i.e.,
[additive=\"replace\"]) is to replace the given
attribute\'s value with the transformation defined by the
['[animateTransform](#AnimateTransformElement)']. The
effect of additive (i.e., [additive=\"sum\"]) is to
post-multiply the transformation matrix corresponding to the
transformation defined by this
['[animateTransform](#AnimateTransformElement)'].

To illustrate:

 <rect transform="skewX(30)"...>
 <animateTransform attributeName="transform"
 type="rotate" from="0" to="90" dur="5s"
 additive="replace" fill="freeze"/>
 <animateTransform attributeName="transform"
 type="scale" from="1" to="2" dur="5s"
 additive="replace" fill="freeze"/>
 </rect>

In the code snippet above, because the both animations have
[additive=\"replace\"], the first animation overrides the
transformation on the rectangle itself and the second animation
overrides the transformation from the first animation; therefore, at
time 5 seconds, the visual result of the above two animations would be
equivalent to the following static rectangle:

 <rect transform="scale(2)" ... />

 <rect transform="skewX(30)"...>
 <animateTransform attributeName="transform"
 type="rotate" from="0" to="90" dur="5s"
 additive="sum" fill="freeze"/>
 <animateTransform attributeName="transform"
 type="scale" from="1" to="2" dur="5s"
 additive="sum" fill="freeze"/>
 </rect>

In this code snippet, because the both animations have
[additive=\"sum\"], the first animation post-multiplies its
transformation to any transformations on the rectangle itself and the
second animation post-multiplies its transformation to any
transformation from the first animation; therefore, at time 5 seconds,
the visual result of the above two animations would be equivalent to the
following static rectangle:

 <rect transform="skewX(30) rotate(90) scale(2)" ... />

The zero value used when performing a *by animation* with
[type=\"scale\"] is indeed 0. Thus, performing the
following animation causes the rectangle to be invisible at time 0s
(since the animated transform list value is
[\'scale(0)\']), and be scaled back to its original size at
time 5s (since the animated transform list value is
[\'scale(1)\']):

 <rect width="100" height="100">
 <animateTransform attributeName="transform"
 type="scale" by="1" dur="5s" fill="freeze"/>
 </rect>

When a transform animation has [accumulate=\'sum\'], the
accumulation that occurs for each completed repetition of the animation
is computed on the values specified in the
['[animateTransform](#AnimateTransformElement)']
element\'s [animation value attributes](#ValueAttributes) (i.e.,
['[values](#ValuesAttribute)'],
['[from](#FromAttribute)'],
['[to](#ToAttribute)'] and
['[by](#ByAttribute)']) and not on the transformation matrix
that these values represent.

For example, in the following code snippet, 3 is added to the scale
value at the start of each repetition:

 <rect width="100" height="100">
 <animateTransform attributeName="transform"
 type="scale" from="2" to="3" repeatCount="3" dur="4s"
 fill="freeze"/>
 </rect>

The following graph and table shows the animated
[transform](https://svgwg.org/svg2-draft/coords.html#TransformProperty)
value on the
['[rect](https://svgwg.org/svg2-draft/shapes.html#RectElement)']
over the course of the animation:

+-----------------------------------------------------------+-----------------------------------+
| ![The scale value animates from 2 to 12 with | Time Value |
| discontinuities at 4s and | ------ ------------- |
| 8s.](images/cumulative-transform-graph-1.png){width="430" | 0s scale(2) |
| height="320"} | 1s scale(2.25) |
| | 2s scale(2.5) |
| | 3s scale(2.75) |
| | 4s scale(5) |
| | 5s scale(5.25) |
| | 6s scale(5.5) |
| | 7s scale(5.75) |
| | 8s scale(8) |
| | 9s scale(8.25) |
| | 10s scale(8.5) |
| | 11s scale(8.75) |
| | 12s scale(9) |
+-----------------------------------------------------------+-----------------------------------+

Transform item types that can have multiple values --
[\'translate\'], [\'scale\'] and
[\'rotate\'] -- are treated as vectors and accumulation is
performed with vector addition. Optional values that are omitted are
taken to have their usual implied value: [1] for the
[\<sy\>] component of a [\'scale\'] and
[0] for the [\<tx\>] component of a
[\'translate\'] and the [\<cx cy\>] components
of a [\'rotate\'].

For example, consider the following code snippet, which has a cumulative
transform animation of type [\'rotate\']:

 <rect width="100" height="100">
 <animateTransform attributeName="transform"
 type="rotate" from="0 30 40" to="10 30 40"
 repeatCount="2" dur="1s" fill="freeze"/>
 </rect>

At time 1 second, the animated value of
[transform](https://svgwg.org/svg2-draft/coords.html#TransformProperty)
on the
['[rect](https://svgwg.org/svg2-draft/shapes.html#RectElement)']
will jump from [\'rotate(10 30 40)\'] to [\'rotate(10 60
80)\'], because the effect of the accumulation is to take
the value at the end of the first repetition, [\'10 30
40\'], and add to it the value at simple duration
`t` = 0s, which is [\'0 30 40\'].

For a list of attributes and properties that can be animated using the
['[animateTransform](#AnimateTransformElement)'] element,
see [Elements, attributes and properties that can be
animated](#AnimationAttributesAndProperties).

### 2.17. Elements, attributes and properties that can be animated
The following lists all of the elements which can be animated by an
['[animateMotion](#AnimateMotionElement)'] element:

- ['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
- ['[g](https://svgwg.org/svg2-draft/struct.html#GElement)']
- ['[defs](https://svgwg.org/svg2-draft/struct.html#DefsElement)']
- ['[use](https://svgwg.org/svg2-draft/struct.html#UseElement)']
- ['[image](https://svgwg.org/svg2-draft/embedded.html#ImageElement)']
- ['[switch](https://svgwg.org/svg2-draft/struct.html#SwitchElement)']
- ['[path](https://svgwg.org/svg2-draft/paths.html#PathElement)']
- ['[rect](https://svgwg.org/svg2-draft/shapes.html#RectElement)']
- ['[circle](https://svgwg.org/svg2-draft/shapes.html#CircleElement)']
- ['[ellipse](https://svgwg.org/svg2-draft/shapes.html#EllipseElement)']
- ['[line](https://svgwg.org/svg2-draft/shapes.html#LineElement)']
- ['[polyline](https://svgwg.org/svg2-draft/shapes.html#PolylineElement)']
- ['[polygon](https://svgwg.org/svg2-draft/shapes.html#PolygonElement)']
- ['[text](https://svgwg.org/svg2-draft/text.html#TextElement)']
- ['[clipPath](https://drafts.fxtf.org/css-masking-1/#ClipPathElement)']
- ['[mask](https://drafts.fxtf.org/css-masking-1/#MaskElement)']
- ['[a](https://svgwg.org/svg2-draft/linking.html#AElement)']
- ['[foreignObject](https://svgwg.org/svg2-draft/embedded.html#ForeignObjectElement)']

Each attribute or property within this specification indicates whether
or not it can be animated by SVG\'s animation elements. Animatable
attributes and properties are designated as follows:

[Animatable: yes.]

whereas attributes and properties that cannot be animated are
designated:

[Animatable: no.]

Some properties are defined as being animatable but only for
non-additive animations:

[Animatable: yes (non-additive).]

SVG has a number of different data types used for its various supported
attributes and properties. For those attributes and properties that can
be animated, the following table indicates which animation elements can
be used to animate each of the basic data types. If a given attribute or
property can take values of keywords (which are not additive) or numeric
values (which are additive), then additive animations are possible if
the subsequent animation uses a numeric value even if the base animation
uses a keyword value; however, if the subsequent animation uses a
keyword value, additive animation is not possible.

 Data type Additive? ['[animate](#AnimateElement)'] ['[set](#SetElement)'] ['[animateTransform](#AnimateTransformElement)'] Notes
 ------------------------------------------------------------------------- ----------- ----------------------------------------------- --------------------------------------- ----------------------------------------------------------------- ---------------------------------------------------------------
 [\<angle\>](https://www.w3.org/TR/css-values/#angles) yes yes yes no  
 [\<color\>](https://www.w3.org/TR/css3-values/#colors) yes yes yes no Only additive if each value can be converted to an RGB color.
 [\<frequency\>](https://www.w3.org/TR/css3-values/#frequency) no no no no  
 [\<integer\>](https://www.w3.org/TR/css3-values/#integers) yes yes yes no  
 [\<length\>](https://www.w3.org/TR/css3-values/#lengths) yes yes yes no  
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) yes yes yes no  
 [\<paint\>](https://svgwg.org/svg2-draft/painting.html#SpecifyingPaint) yes yes yes no Only additive if each value can be converted to an RGB color.
 [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages) yes yes yes no  
 [\<time\>](https://www.w3.org/TR/css3-values/#time) no no no no  
 URL no yes yes no  
 All other data types used in animatable attributes and properties no yes yes no  

 : Animatable data types

Any deviation from the above table or other special note about the
animation capabilities of a particular attribute or property is included
in the section of the specification where the given attribute or
property is defined.

### 2.18. Implicit ARIA Semantics
[Animation elements](#TermAnimationElement) have no default implied ARIA
semantics. Furthermore, no role may be applied to [animation
elements](#TermAnimationElement).

## 3. Animation using the SVG DOM
[Example dom01] shows a simple animation using the DOM.

 <?xml version="1.0" standalone="no"?>
 <svg width="4cm" height="2cm" viewBox="0 0 400 200"
 xmlns="http://www.w3.org/2000/svg"
 onload="StartAnimation(evt)">
 <script type="application/ecmascript"><![CDATA[
 var timevalue = 0;
 var timer_increment = 50;
 var max_time = 5000;
 var text_element;
 function StartAnimation(evt) {
 text_element = evt.target.ownerDocument.getElementById("TextElement");
 ShowAndGrowElement();
 }
 function ShowAndGrowElement() {
 timevalue = timevalue + timer_increment;
 if (timevalue > max_time)
 return;
 // Scale the text string gradually until it is 20 times larger
 scalefactor = (timevalue * 20.) / max_time;
 text_element.setAttribute("transform", "scale(" + scalefactor + ")");
 // Make the string more opaque
 opacityfactor = timevalue / max_time;
 text_element.setAttribute("opacity", opacityfactor);
 // Call ShowAndGrowElement again <timer_increment> milliseconds later.
 setTimeout("ShowAndGrowElement()", timer_increment)
 }
 window.ShowAndGrowElement = ShowAndGrowElement
 ]]></script>
 <rect x="1" y="1" width="398" height="198"
 fill="none" stroke="blue" stroke-width="2"/>
 <g transform="translate(50,150)" fill="red" font-size="7">
 <text id="TextElement">SVG</text>
 </g>
 </svg>

 ----------------------------------------- ----------------------------------------- -----------------------------------------
 ![Example dom01 - at zero ![Example dom01 - at three ![Example dom01 - at six
 seconds](images/dom01a.png){width="151" seconds](images/dom01b.png){width="151" seconds](images/dom01c.png){width="151"
 height="76"}\ height="76"}\ height="76"}\
 At zero seconds At 2.5 seconds At five seconds

 ----------------------------------------- ----------------------------------------- -----------------------------------------

 : Example dom01

[View this example as SVG (SVG-enabled browsers only)](images/dom01.svg)

The above SVG file contains a single graphics element, a text string
that says \"SVG\". The animation loops for 5 seconds. The text string
starts out small and transparent and grows to be large and opaque. Here
is an explanation of how this example works:

- The [onload=\"StartAnimation(evt)\"] attribute indicates
 that, once the document has been fully loaded and processed, invoke
 ECMAScript function `StartAnimation`.
- The
 ['[script](https://svgwg.org/svg2-draft/interact.html#ScriptElement)']
 element defines the ECMAScript which makes the animation happen. The
 `StartAnimation()` function is only called once to give a value to
 global variable `text_element` and to make the initial call to
 `ShowAndGrowElement()`. `ShowAndGrowElement()` is called every 50
 milliseconds and resets the
 [transform](https://svgwg.org/svg2-draft/coords.html#TransformProperty)
 and
 ['[style](https://svgwg.org/svg2-draft/styling.html#StyleAttribute)']
 attributes on the text element to new values each time it is called.
 At the end of `ShowAndGrowElement`, the function tells the ECMAScript
 engine to call itself again after 50 more milliseconds.
- The
 ['[g](https://svgwg.org/svg2-draft/struct.html#GElement)']
 element shifts the coordinate system so that the origin is shifted
 toward the lower-left of the viewing area. It also defines the fill
 color and font-size to use when drawing the text string.
- The
 ['[text](https://svgwg.org/svg2-draft/text.html#TextElement)']
 element contains the text string and is the element whose attributes
 get changed during the animation.

If scripts are modifying the same attributes or properties that are
being animated by SVG\'s [animation elements](#AnimationElements), the
scripts modify the base value for the animation. If a base value is
modified while an animation element is animating the corresponding
attribute or property, the animations are required to adjust dynamically
to the new base value.

If a script is modifying a property on the override style sheet at the
same time that an [animation element](#TermAnimationElement) is
animating that property, the result is implementation-dependent; thus,
it is recommended that this be avoided.

## 4. Extensions to SVG 2
This specification extends the definitions in SVG 2 \[\[SVG2\]\] in the
following ways.

### 4.1. Extensions to the ['svg'] element
 -------------------- ----------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Should support the playbackorder attribute to inform UA to not display controls to seek backwards.
 Resolution: [Support the playbackorder attribute.](http://www.w3.org/2012/03/29-svg-irc#T20-39-02)
 Purpose: To inform UA to not display controls to seek backwards.
 Owner: Cyril
 -------------------- ----------------------------------------------------------------------------------------------------

 -------------------- ------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Support a means for having SMIL animations start before their time container has fully loaded.
 Resolution: [Timeline control.](http://www.w3.org/2012/03/29-svg-irc#T20-23-57)
 Purpose: To start animations before the SVG document is fully loaded (useful for large SVG documents).
 Owner: Cyril
 -------------------- ------------------------------------------------------------------------------------------------

*Attribute definitions:*

 Name Value Initial value Animatable
 --------------------------------------------------------- -------------------- --------------- ------------
 [playbackorder] forwardonly \| all all no

Indicates whether it is possible to seek backwards in the document. In
earlier versions of SVG there was no need to put restrictions on the
direction of seeking but with the newly introduced facilities for
long-running documents there is sometimes a need to restrict this.

If ['playbackorder'] is set to
[\'forwardonly\'], the content will likely contain scripts
that destroy resources, thus seeking back in the document fragment\'s
timeline may result in missing content. If ['playbackorder']
is [\'forwardonly\'], the content should not provide a way,
through hyperlinking or script, of seeking backwards in the timeline.
Similarly the UA should disable any controls it may provide in the user
interface for seeking backwards. Content with
[playbackorder=\"forwardonly\"] that provides a mechanism
for seeking backwards in time may result in undefined behavior or a
document that is in error.

Can\'t we define this so that there is no
undefined behavior?

Attribute values have the following meanings:

[\'forwardonly\']
: This file is intended to be played only in the forward direction,
 sequentially, therefore seeking backwards should not be allowed.

[\'all\']
: Indicates that the document is authored appropriately for seeking in
 both directions.

 Name Value Initial value Animatable
 --------------------------------------------------------- ---------------------- --------------- ------------
 [timelinebegin] loadend \| loadbegin loadend no

Controls the initialization of the timeline for the [SVG document
fragment](https://svgwg.org/svg2-draft/struct.html#TermSVGDocumentFragment).

The [outermost svg
element](https://svgwg.org/svg2-draft/struct.html#TermOutermostSVGElement)
of an [SVG document
fragment](https://svgwg.org/svg2-draft/struct.html#TermSVGDocumentFragment)
defines a *timeline*. Absolute times used by [animation
elements](#TermAnimationElement) in an [SVG document
fragment](https://svgwg.org/svg2-draft/struct.html#TermSVGDocumentFragment)
are relative to the document fragment\'s *timeline*.

By default, the *timeline* is initialized when the document fragment\'s
[`load`](https://svgwg.org/svg2-draft/interact.html#LoadEvent) event is
fired but for progressively loaded animations, the author may set this
attribute to [\'loadend\'], thus allowing the timeline to
begin as the document loads, rather than waiting until the complete
document is loaded.

Attribute values have the following meanings:

[\'loadend\']
: The document fragment\'s timeline starts the moment the
 [`load`](https://svgwg.org/svg2-draft/interact.html#LoadEvent) event
 for the [outermost svg
 element](https://svgwg.org/svg2-draft/struct.html#TermOutermostSVGElement)
 is triggered.

[\'loadbegin\']
: The document\'s timeline starts at the moment the [outermost svg
 element](https://svgwg.org/svg2-draft/struct.html#TermOutermostSVGElement)\'s
 *start-tag* (as defined in [XML
 1.0](http://www.w3.org/TR/2006/REC-xml-20060816/#sec-starttags)
 \[[XML10](#ref-XML10)\] or
 [HTML](http://www.w3.org/TR/html5/syntax.html#syntax-start-tag)
 \[[HTML](#ref-HTML)\] when using the HTML parser) is fully parsed.

### 4.2. Extensions to conditional processing elements
If the conditional statement on the
['[requiredExtensions](https://svgwg.org/svg2-draft/struct.html#RequiredExtensionsAttribute)']
and
['[systemLanguage](https://svgwg.org/svg2-draft/struct.html#SystemLanguageAttribute)']
attributes on [animation elements](#TermAnimationElement) fails, the
animation will never be triggered.

## 5. IDL
Below are the DOM interfaces for the elements defined in this chapter.
In addition, [TimeEvent](#InterfaceTimeEvent), which is
from [SMIL
Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/), is
included here for easy reference.

### 5.1. Interface TimeEvent
The [TimeEvent](#InterfaceTimeEvent) interface, defined
in [SMIL Animation: Supported
interfaces](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#DOMSupport),
provides specific contextual information associated with Time events.

The different types of events that can occur are:

**beginEvent**
: This event is raised when the element local timeline begins to play.
 It will be raised each time the element begins the active duration
 (i.e. when it restarts, but not when it repeats). It may be raised
 both in the course of normal (i.e. scheduled or interactive)
 timeline play, as well as in the case that the element was begun
 with the [beginElement](#__svg__SVGAnimationElement__beginElement)
 or [beginElementAt](#__svg__SVGAnimationElement__beginElementAt)
 methods. Note that if an element is restarted while it is currently
 playing, the element will raise an end event and another begin
 event, as the element restarts.
 - Bubbles: No
 - Cancelable: No
 - Context Info: None

**endEvent**
: This event is raised at the active end of the element. Note that
 this event is not raised at the simple end of each repeat. This
 event may be raised both in the course of normal (i.e. scheduled or
 interactive) timeline play, as well as in the case that the element
 was ended with the
 [endElement](#__svg__SVGAnimationElement__endElement) or
 [endElementAt](#__svg__SVGAnimationElement__endElementAt) methods.
 Note that if an element is restarted while it is currently playing,
 the element will raise an end event and another begin event, as the
 element restarts.
 - Bubbles: No
 - Cancelable: No
 - Context Info: None

**repeatEvent**
: This event is raised when an element local timeline repeats. It will
 be raised each time the element repeats, after the first iteration.\
 The event provides a numerical indication of which repeat iteration
 is beginning. The value is a 0-based integer, but the repeat event
 is not raised for the first iteration and so the observed values of
 the detail attribute will be \>= 1.
 - Bubbles: No
 - Cancelable: No
 - Context Info: detail (current iteration)

``` idl
[Exposed=Window]
interface TimeEvent : Event {

 readonly attribute WindowProxy? view;
 readonly attribute long detail;

 undefined initTimeEvent(DOMString typeArg, optional Window? viewArg = null, optional long detailArg = 0);
};
```

Attributes:

:

 **view**[ (readonly [WindowProxy](https://html.spec.whatwg.org/multipage/window-object.html#windowproxy)?)]

 : :::
 The [view](#__svg__TimeEvent__view) attribute identifies the
 [Window](https://html.spec.whatwg.org/multipage/window-object.html#window)
 from which the event was generated.
 :::

 **detail**[ (readonly long)]

 : :::
 Specifies some detail information about the Event, depending on
 the type of the event. For this event type, indicates the repeat
 number for the animation.
 :::

Operations:

:

 undefined **initTimeEvent**(DOMString `typeArg`, optional [Window](https://html.spec.whatwg.org/multipage/window-object.html#window)? `viewArg` = null, optional long `detailArg` = 0)

 : :::
 The [initTimeEvent](#__svg__TimeEvent__initTimeEvent) method is
 used to initialize the value of a
 [TimeEvent](#InterfaceTimeEvent) created with
 `document.createEvent()`. This method may only be called before
 the [TimeEvent](#InterfaceTimeEvent) has been
 dispatched via the dispatchEvent method, though it may be called
 multiple times during that phase if necessary. If called
 multiple times, the final invocation takes precedence.
 :::

 Parameters

 : 1. :::
 DOMString `typeArg`
 :::

 :::
 Specifies the event type.
 :::

 2. :::
 [Window](https://html.spec.whatwg.org/multipage/window-object.html#window)?
 `viewArg`
 :::

 :::
 Specifies the Event\'s
 [Window](https://html.spec.whatwg.org/multipage/window-object.html#window).
 :::

 3. :::
 long `detailArg`
 :::

 :::
 Specifies the Event\'s detail.
 :::

### 5.2. Interface SVGAnimationElement
The [SVGAnimationElement](#InterfaceSVGAnimationElement)
interface is the base interface for all of the animation element
interfaces:
[SVGAnimateElement](#InterfaceSVGAnimateElement),
[SVGSetElement](#InterfaceSVGSetElement),
[SVGAnimateMotionElement](#InterfaceSVGAnimateMotionElement)
and
[SVGAnimateTransformElement](#InterfaceSVGAnimateTransformElement).

Unlike other SVG DOM interfaces, the SVG DOM does not specify
convenience DOM properties corresponding to the various language
attributes on SVG\'s animation elements. Specification of these
convenience properties in a way that will be compatible with future
versions of SMIL Animation is expected in a future version of SVG. The
current method for accessing and modifying the attributes on the
animation elements is to use the standard `getAttribute`,
`setAttribute`, `getAttributeNS` and `setAttributeNS` defined in
[DOM4](http://www.w3.org/TR/dom/) \[[DOM4](#ref-DOM4)\].

SMIL Animation supports several methods for controlling the behavior of
animation: `beginElement()`, `beginElementAt()`, `endElement()` and
`endElementAt()`. These methods are used to begin and end the active
duration of an element. Authors can (but are not required to) declare
the timing to respond to the DOM using the following syntax:

 <animate begin="indefinite" end="indefinite" .../>

If a DOM method call is made to begin or end the element (using
`beginElement()`, `beginElementAt()`, `endElement()` or
`endElementAt()`), each method call creates a single instance time (in
the appropriate instance times list). These times are then interpreted
as part of the semantics of lists of times, as described in [Evaluation
of begin and end time
lists](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Timing-EvaluationOfBeginEndTimeLists).

- The instance time associated with a `beginElement()` or `endElement()`
 call is the current presentation time at the time of the DOM method
 call.
- The instance time associated with a `beginElementAt()` or
 `endElementAt()` call is the current presentation time at the time of
 the DOM method call, plus or minus the specified offset.
- Note that `beginElement()` is subject to the
 ['[restart](#RestartAttribute)'] attribute in the same
 manner that event-based begin timing is. Refer also to [SMIL
 Animation: Restarting
 animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Restart)
 (\[[SMILANIM](#ref-SMILANIM)\], section 3.3.7).

``` idl
[Exposed=Window]
interface SVGAnimationElement : SVGElement {

 readonly attribute SVGElement? targetElement;

 attribute EventHandler onbegin;
 attribute EventHandler onend;
 attribute EventHandler onrepeat;

 float getStartTime();
 float getCurrentTime();
 float getSimpleDuration();

 undefined beginElement();
 undefined beginElementAt(float offset);
 undefined endElement();
 undefined endElementAt(float offset);
};

SVGAnimationElement includes SVGTests;
```

Attributes:

:

 **targetElement**[ (readonly [SVGElement](https://svgwg.org/svg2-draft/types.html#InterfaceSVGElement)?)]

 : :::
 The element which is being animated. If no target element is
 being animated (for example, because the URL in \'animate/href\'
 does not match a valid element) the value returned is null.
 :::

 **onbegin**[ ([EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler))]

 : :::
 The event handler for the
 [beginEvent](https://svgwg.org/svg2-draft/interact.html#BeginEvent).
 :::

 **onend**[ ([EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler))]

 : :::
 The event handler for the
 [endEvent](https://svgwg.org/svg2-draft/interact.html#EndEvent).
 :::

 **onrepeat**[ ([EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler))]

 : :::
 The event handler for the
 [repeatEvent](https://svgwg.org/svg2-draft/interact.html#RepeatEvent).
 :::

Operations:

:

 float **getStartTime**()

 : :::
 Returns the begin time, in seconds, for this animation
 element\'s current interval, if it exists, regardless of whether
 the interval has begun yet. If there is no current interval,
 then a DOMException with code INVALID_STATE_ERR is thrown.
 :::

 Returns

 : :::
 The start time, in seconds, of this animation element\'s
 current interval.
 :::

 Exceptions

 :

 [DOMException](https://heycam.github.io/webidl/#idl-DOMException), code INVALID_STATE_ERR
 : The animation element does not have a current interval.

 float **getCurrentTime**()

 : :::
 Returns the current time in seconds relative to time zero for
 the given time container.
 :::

 Returns

 : :::
 The current time in seconds relative to time zero for the
 given time container.
 :::

 float **getSimpleDuration**()

 : :::
 Returns the number of seconds for the simple duration for this
 animation. If the simple duration is undefined (e.g., the end
 time is indefinite), then an exception is raised.
 :::

 Returns

 : :::
 number of seconds for the simple duration for this
 animation.
 :::

 Exceptions

 :

 [DOMException](https://heycam.github.io/webidl/#idl-DOMException), code NOT_SUPPORTED_ERR
 : The simple duration is not determined on the given
 element.

 undefined **beginElement**()

 : :::
 Creates a begin instance time for the current time. The new
 instance time is added to the [*begin instance times
 list*](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Timing-BeginEnd-InstanceTimesLists).
 The behavior of this method is equivalent to
 `beginElementAt(0)`.
 :::

 undefined **beginElementAt**(float `offset`)

 : :::
 Creates a begin instance time for the current time plus the
 specified offset. The new instance time is added to the [*begin
 instance times
 list*](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Timing-BeginEnd-InstanceTimesLists).
 :::

 Parameters

 : 1. :::
 float `offset`
 :::

 :::
 The offset from the current document time, in seconds,
 at which to begin the element.
 :::

 undefined **endElement**()

 : :::
 Creates an end instance time for the current time. The new
 instance time is added to the [*end instance times
 list*](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Timing-BeginEnd-InstanceTimesLists).
 The behavior of this method is equivalent to `endElementAt(0)`.
 :::

 undefined **endElementAt**(float `offset`)

 : :::
 Creates a end instance time for the current time plus the
 specified offset. The new instance time is added to the [*end
 instance times
 list*](http://www.w3.org/TR/2001/REC-smil-animation-20010904/#Timing-BeginEnd-InstanceTimesLists).
 :::

 Parameters

 : 1. :::
 float `offset`
 :::

 :::
 The offset from the current document time, in seconds,
 at which to end the element.
 :::

### 5.3. Interface SVGAnimateElement
The [SVGAnimateElement](#InterfaceSVGAnimateElement)
interface corresponds to the
['[animate](#AnimateElement)'] element.

Object-oriented access to the attributes of the
['[animate](#AnimateElement)'] element via the SVG DOM is
not available.

``` idl
[Exposed=Window]
interface SVGAnimateElement : SVGAnimationElement ;
```

### 5.4. Interface SVGSetElement
The [SVGSetElement](#InterfaceSVGSetElement) interface
corresponds to the ['[set](#SetElement)'] element.

Object-oriented access to the attributes of the
['[set](#SetElement)'] element via the SVG DOM is not
available.

``` idl
[Exposed=Window]
interface SVGSetElement : SVGAnimationElement ;
```

### 5.5. Interface SVGAnimateMotionElement
The
[SVGAnimateMotionElement](#InterfaceSVGAnimateMotionElement)
interface corresponds to the
['[animateMotion](#AnimateMotionElement)'] element.

Object-oriented access to the attributes of the
['[animateMotion](#AnimateMotionElement)'] element via
the SVG DOM is not available.

``` idl
[Exposed=Window]
interface SVGAnimateMotionElement : SVGAnimationElement ;
```

### 5.6. Interface SVGMPathElement
The [SVGMPathElement](#InterfaceSVGMPathElement)
interface corresponds to the ['[mpath](#MPathElement)']
element.

``` idl
[Exposed=Window]
interface SVGMPathElement : SVGElement ;

SVGMPathElement includes SVGURIReference;
```

### 5.7. Interface SVGAnimateTransformElement
The
[SVGAnimateTransformElement](#InterfaceSVGAnimateTransformElement)
interface corresponds to the
['[animateTransform](#AnimateTransformElement)'] element.

Object-oriented access to the attributes of the
['[animateTransform](#AnimateTransformElement)'] element
via the SVG DOM is not available.

``` idl
[Exposed=Window]
interface SVGAnimateTransformElement : SVGAnimationElement ;
```

### 5.8. Extensions to interface SVGSVGElement
``` idl
partial interface SVGSVGElement {
 undefined pauseAnimations();
 undefined unpauseAnimations();
 boolean animationsPaused();
 float getCurrentTime();
 undefined setCurrentTime(float seconds);
};
```

The **pauseAnimations** and **unpauseAnimations** methods are used to
pause and unpause all of the animations within the [SVG document
fragment](https://svgwg.org/svg2-draft/struct.html#TermSVGDocumentFragment).

When pauseAnimations() is called, the following steps are run:

1. If the current
 ['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
 element is not the [outermost svg
 element](https://svgwg.org/svg2-draft/struct.html#TermOutermostSVGElement),
 then return.
2. Pause the timeline that controls SVG animations for the [SVG
 document
 fragment](https://svgwg.org/svg2-draft/struct.html#TermSVGDocumentFragment)
 that the
 ['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
 element is in.

When unpauseAnimations() is called, the following steps are run:

1. If the current
 ['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
 element is not the [outermost svg
 element](https://svgwg.org/svg2-draft/struct.html#TermOutermostSVGElement),
 then return.
2. Unpause the timeline that controls SVG animations for the [SVG
 document
 fragment](https://svgwg.org/svg2-draft/struct.html#TermSVGDocumentFragment)
 that the
 ['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
 element is in.

The [pauseAnimations](#__svg__SVGSVGElement__pauseAnimations) and
[unpauseAnimations](#__svg__SVGSVGElement__unpauseAnimations) methods
only affect animations defined using SVG\'s [animation
elements](#TermAnimationElement). They have no effect on CSS Transitions
or Animations
\[[CSS3ANIMATIONS](#ref-CSS3ANIMATIONS)\]\[[CSS3TRANSITIONS](#ref-CSS3TRANSITIONS)\]
or animations created using script.

The **animationsPaused** method returns whether SVG animation timeline
has been paused. When animationsPaused() is called, true is returned if
the timeline that controls SVG animations for the [SVG document
fragment](https://svgwg.org/svg2-draft/struct.html#TermSVGDocumentFragment)
that the
['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
element in has been paused by
[pauseAnimations](#__svg__SVGSVGElement__pauseAnimations); otherwise,
false is returned.

The **getCurrentTime** and **setCurrentTime** methods are used to get
and set the current time of the timeline that controls SVG animations.
When getCurrentTime() is called, the following steps are run:

1. If the timeline for the [current SVG document
 fragment](https://svgwg.org/svg2-draft/struct.html#TermCurrentSVGDocumentFragment)
 has not yet begun, then return 0.

 This is the case, for example, if the [outermost svg
 element](https://svgwg.org/svg2-draft/struct.html#TermOutermostSVGElement)
 has its
 ['[timelinebegin](#SVGElementTimelinebeginAttribute)']
 attribute set to [\'loadend\'] and the load event has
 not yet fired.

2. Otherwise, the timeline for the [current SVG document
 fragment](https://svgwg.org/svg2-draft/struct.html#TermCurrentSVGDocumentFragment)
 has begun. Return the current time in seconds relative to the start
 time of the timeline.

When setCurrentTime(`seconds`) is called, the following steps
are run:

1. If the current
 ['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
 element is not the [outermost svg
 element](https://svgwg.org/svg2-draft/struct.html#TermOutermostSVGElement),
 then return.
2. If the timeline for the [current SVG document
 fragment](https://svgwg.org/svg2-draft/struct.html#TermCurrentSVGDocumentFragment)
 has begun, then the timeline\'s current time (in seconds, relative
 to the start time of the timeline) is set to `seconds`.
3. Otherwise, the timeline has not begun. `seconds` is
 recorded on the [current SVG document
 fragment](https://svgwg.org/svg2-draft/struct.html#TermCurrentSVGDocumentFragment)
 as the time to be seeked to once the timeline has begun. If multiple
 calls to [setCurrentTime](#__svg__SVGSVGElement__setCurrentTime) are
 made before the timeline has begun, the most recent call\'s time
 will be used to seek the timeline once it begins.

## 6. References
### 6.1. Normative references
\[DOM2VIEWS\]
: [Document Object Model (DOM) Level 2 Views
 Specification](http://www.w3.org/TR/2000/REC-DOM-Level-2-Views-20001113/), A.
 Le Hors, L. Cable, eds. World Wide Web Consortium, 13 November
 2000.\
 This edition of DOM 2 Views is
 http://www.w3.org/TR/2000/REC-DOM-Level-2-Views-20001113/.\
 The [latest edition of DOM 2
 Views](http://www.w3.org/TR/DOM-Level-2-Views/) is available at
 http://www.w3.org/TR/DOM-Level-2-Views/.

\[DOM4\]
: [DOM4](http://www.w3.org/TR/2014/WD-dom-20140204/), A. van
 Kesteren, A. Gregor, Ms2ger, A. Russell, R. Berjon, eds. World Wide
 Web Consortium, 04 February 2014.\
 This edition of DOM4 is http://www.w3.org/TR/2014/WD-dom-20140204/.\
 The [latest edition of DOM4](http://www.w3.org/TR/dom/) is available
 at http://www.w3.org/TR/dom/.

\[HTML\]
: [HTML5 A vocabulary and associated APIs for HTML and
 XHTML](http://www.w3.org/TR/html5/), I. Hickson, R. Berjon, S.
 Faulkner, T. Leithead, E.D. Navara, E. O\'Connor, S. Pfeiffer, eds.
 World Wide Web Consortium, 28 October 2014. W3C Recommendation.\
 This edition of HTML5 is
 <http://www.w3.org/TR/2014/REC-html5-20141028/>.\
 The [latest version of html](http://www.w3.org/TR/html/) is
 available at <http://www.w3.org/TR/html/>.

\[ISO8601\]
: [Data elements and interchange formats - Information interchange -
 Representation of dates and
 times](http://www.iso.org/iso/catalogue_detail?csnumber=40874),
 International Organization for Standardization, 2004. Available at
 http://www.iso.org/iso/catalogue_detail?csnumber=40874.

**\[RFC2119\]**
: [Key words for use in RFCs to Indicate Requirement
 Levels](http://tools.ietf.org/html/rfc2119), S. Bradner, March
 1997.\
 Available at http://tools.ietf.org/html/rfc2119.

\[SMIL\]
: [Synchronized Multimedia Integration Language (SMIL
 3.0)](http://www.w3.org/TR/2008/REC-SMIL3-20081201/), D. Bulterman
 *et al.*, eds. 01 December 2008.\
 This edition of SMIL is
 http://www.w3.org/TR/2008/REC-SMIL3-20081201/.\
 The [latest edition of SMIL](http://www.w3.org/TR/smil/) is
 available at http://www.w3.org/TR/smil/.

\[SMILANIM\]
: [SMIL
 Animation](http://www.w3.org/TR/2001/REC-smil-animation-20010904/), P.
 Schmitz, A. Cohen. World Wide Web Consortium, 04 September 2001.\
 This edition of SMIL Animation is
 http://www.w3.org/TR/2001/REC-smil-animation-20010904/.\
 The [latest edition of SMIL
 Animation](http://www.w3.org/TR/smil-animation/) is available at
 http://www.w3.org/TR/smil-animation/.

\[SRGB\]
: IEC 61966-2-1/Amd 1:2003 : Multimedia systems and equipment ---
 Colour measurement and management --- Part 2-1: Colour management
 --- Default RGB colour space --- sRGB, International
 Electrotechnical Commission, 2003.\
 Available at <https://webstore.iec.ch/publication/6168>.\
 See also <http://www.color.org/chardata/rgb/srgb.xalter> for
 technical data and color profiles.

**\[SVG2\]**
: [Scalable Vector Graphics (SVG)
 2](http://www.w3.org/TR/2015/WD-SVG2-20150409/), N. Andronikos, T.
 Bah, A. Bellamy-Royds, B. Birtles, C. Concolato, E. Dahlström, C.
 Lilley, C. McCormack, D. Schepers, D. Schulze, R. Schwerdtfeger, S.
 Takagi, J. Watt, eds. World Wide Web Consortium, 09 April 2015.\
 This edition of SVG 2 is
 http://www.w3.org/TR/2015/WD-SVG2-20150409/.\
 The [latest edition of SVG 2](http://www.w3.org/TR/SVG2/) is
 available at http://www.w3.org/TR/SVG2/.

\[XML10\]
: [Extensible Markup Language (XML) 1.0 (Fifth
 Edition)](http://www.w3.org/TR/2008/REC-xml-20081126/), T. Bray, J.
 Paoli, C. M. Sperberg-McQueen, E. Maler, F. Yergeau, eds. World Wide
 Web Consortium, 26 November 2008.\
 This edition of XML 1.0 is
 http://www.w3.org/TR/2008/REC-xml-20081126/.\
 The [latest edition of XML 1.0](http://www.w3.org/TR/xml/) is
 available at http://www.w3.org/TR/xml/.

### 6.2. Non-normative references
\[CSS3ANIMATIONS\]
: [CSS
 Animations](http://www.w3.org/TR/2012/WD-css-animations-1-20120403/), D.
 Jackson, D. Hyatt, C. Marrin, S. Galineau, L. D. Baron, eds. World
 Wide Web Consortium, 3 April 2012. W3C Working Draft. (Work in
 progress.)\
 This edition of CSS Animations is
 http://www.w3.org/TR/2012/WD-css-animations-1-20120403/.\
 The [latest edition of CSS
 Animations](http://www.w3.org/TR/charmod/) is available at
 http://www.w3.org/TR/css-animations-1/.

\[CSS3TRANSITIONS\]
: [CSS
 Transitions](http://www.w3.org/TR/2012/WD-css-transitions-1-20120403/), D.
 Jackson, D. Hyatt, C. Marrin, L. D. Baron, eds. World Wide Web
 Consortium, 3 April 2012. W3C Working Draft. (Work in progress.)\
 This edition of CSS Transitions is
 http://www.w3.org/TR/2012/WD-css-transitions-1-20120403/.\
 The [latest edition of CSS
 Transitions](http://www.w3.org/TR/css-transitions-1/) is available
 at http://www.w3.org/TR/css-transitions-1/.

\[FOLEY-VANDAM\]
: Computer Graphics: Principles and Practice, Second Edition, J. D.
 Foley, A. van Dam, S. K. Feiner, J. F. Hughes, R. L. Phillips.
 Addison-Wesley, 1995.

## 7. Changes since SVG 1.1 Second Edition
- Removed the [attributeType] attribute.
- Folded the ElementTimeControl interface into
 [SVGAnimationElement](#InterfaceSVGAnimationElement).
- Removed the [animateColor] element.
- Added the onbegin, onend and onrepeat attributes to the
 [SVGAnimationElement](#InterfaceSVGAnimationElement)
 interface.
- The ['[values](#ValuesAttribute)'],
 ['[keyTimes](#KeyTimesAttribute)'] and
 ['[keySplines](#KeySplinesAttribute)'] attributes now
 ignore the last semicolon separator if it\'s not followed by a value.
- Allowed the ['[mpath](#MPathElement)'] element to refer
 to a
 [shape](https://svgwg.org/svg2-draft/shapes.html#TermShapeElement)
 element.
- Added the
 ['[timelinebegin](#SVGElementTimelinebeginAttribute)'] and
 ['[playbackorder](#SVGElementPlaybackorderAttribute)']
 attributes on the
 ['[svg](https://svgwg.org/svg2-draft/struct.html#SVGElement)']
 element.
