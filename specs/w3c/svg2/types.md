# Chapter 4: Basic Data Types and Interfaces

::: }}
[Overview](Overview.html) · [Previous](render.html) ·
[Next](struct.html) · [Elements](eltindex.html) ·
[Attributes](attindex.html) · [Properties](propidx.html)

## Contents

1. 1. [[4.1.] Definitions](types.html#definitions)
 2. [[4.2.] Attribute syntax](types.html#syntax)
 1. [[4.2.1.] Real number
 precision](types.html#Precision)
 2. [[4.2.2.] Clamping values which are restricted to a
 particular range](types.html#RangeClamping)
 3. [[4.3.] SVG DOM overview](types.html#SVGDOMOverview)
 1. [[4.3.1.] Dependencies for SVG DOM
 support](types.html#SVGDOMDependencies)
 2. [[4.3.2.] Naming
 conventions](types.html#SVGDOMNamingConventions)
 3. [[4.3.3.] Elements in the SVG
 DOM](types.html#ElementsInTheSVGDOM)
 4. [[4.3.4.] Reflecting content attributes in the
 DOM](types.html#ReflectingAttributes)
 5. [[4.3.5.] Synchronizing reflected
 values](types.html#SynchronizingReflectedValues)
 6. [[4.3.6.] Reflecting an empty initial
 value](types.html#SVGObjectInitialization)
 7. [[4.3.7.] Invalid values](types.html#InvalidValues)
 4. [[4.4.] DOM interfaces for SVG
 elements](types.html#DOMInterfacesForSVGElements)
 1. [[4.4.1.] Interface
 SVGElement](types.html#InterfaceSVGElement)
 2. [[4.4.2.] Interface
 SVGGraphicsElement](types.html#InterfaceSVGGraphicsElement)
 3. [[4.4.3.] Interface
 SVGGeometryElement](types.html#InterfaceSVGGeometryElement)
 5. [[4.5.] DOM interfaces for basic data
 types](types.html#DOMInterfacesForBasicDataTypes)
 1. [[4.5.1.] Interface
 SVGNumber](types.html#InterfaceSVGNumber)
 2. [[4.5.2.] Interface
 SVGLength](types.html#InterfaceSVGLength)
 3. [[4.5.3.] Interface
 SVGAngle](types.html#InterfaceSVGAngle)
 4. [[4.5.4.] List
 interfaces](types.html#ListInterfaces)
 5. [[4.5.5.] Interface
 SVGNumberList](types.html#InterfaceSVGNumberList)
 6. [[4.5.6.] Interface
 SVGLengthList](types.html#InterfaceSVGLengthList)
 7. [[4.5.7.] Interface
 SVGStringList](types.html#InterfaceSVGStringList)
 6. [[4.6.] DOM interfaces for reflecting animatable SVG
 attributes](types.html#DOMInterfacesForReflectingSVGAttributes)
 1. [[4.6.1.] Interface
 SVGAnimatedBoolean](types.html#InterfaceSVGAnimatedBoolean)
 2. [[4.6.2.] Interface
 SVGAnimatedEnumeration](types.html#InterfaceSVGAnimatedEnumeration)
 3. [[4.6.3.] Interface
 SVGAnimatedInteger](types.html#InterfaceSVGAnimatedInteger)
 4. [[4.6.4.] Interface
 SVGAnimatedNumber](types.html#InterfaceSVGAnimatedNumber)
 5. [[4.6.5.] Interface
 SVGAnimatedLength](types.html#InterfaceSVGAnimatedLength)
 6. [[4.6.6.] Interface
 SVGAnimatedAngle](types.html#InterfaceSVGAnimatedAngle)
 7. [[4.6.7.] Interface
 SVGAnimatedString](types.html#InterfaceSVGAnimatedString)
 8. [[4.6.8.] Interface
 SVGAnimatedRect](types.html#InterfaceSVGAnimatedRect)
 9. [[4.6.9.] Interface
 SVGAnimatedNumberList](types.html#InterfaceSVGAnimatedNumberList)
 10. [[4.6.10.] Interface
 SVGAnimatedLengthList](types.html#InterfaceSVGAnimatedLengthList)
 7. [[4.7.] Other DOM
 interfaces](types.html#OtherDOMInterfaces)
 1. [[4.7.1.] Interface
 SVGUnitTypes](types.html#InterfaceSVGUnitTypes)
 2. [[4.7.2.] Mixin
 SVGTests](types.html#InterfaceSVGTests)
 3. [[4.7.3.] Mixin
 SVGFitToViewBox](types.html#InterfaceSVGFitToViewBox)
 4. [[4.7.4.] Mixin
 SVGURIReference](types.html#InterfaceSVGURIReference)

## 4.1. Definitions
[initial value]

: The initial value of an attribute or property is the value used when
 that attribute or property is not specified, or when it has an
 [invalid value](types.html#TermInvalidValue). This value is to be
 used for the purposes of rendering, calculating [animation
 values](https://svgwg.org/specs/animations/), and when accessing the
 attribute or property via DOM interfaces.

[invalid value]
: An invalid value specified for a
 [property](styling.html#TermProperty), either in a style sheet or a
 [presentation attribute](styling.html#TermPresentationAttribute), is
 one that is either not allowed according to the grammar defining the
 property\'s values, or is allowed by the grammar but subsequently
 disallowed in prose. A CSS declaration with an invalid value is
 [ignored](https://drafts.csswg.org/css-syntax/#css-ignored).

## 4.2. Attribute syntax
::::: ready-for-wider-review
In this specification, attributes are defined with an attribute
definition table, which looks like this:

 Name Value Initial value Animatable
 --------------------- ------------------------------------------------------------------ --------------- ------------
 [exampleattr] [\<length\>](https://www.w3.org/TR/css3-values/#lengths) \| none none yes

In the Value column is a description of the attribute\'s syntax. There
are six methods for describing an attribute\'s syntax:

1. Using the [CSS Value Definition
 Syntax](https://www.w3.org/TR/css-values/#value-defs)
 \[[css-values](refs.html#ref-css-values-3)\]. This is the notation
 used to define the syntax for most attributes in this specification
 and is the default.
2. By reference to an [EBNF
 symbol](https://www.w3.org/TR/REC-xml/#sec-notation) defined in this
 or another specification \[[xml](refs.html#ref-xml)\]. For external
 definitions, this is indicated by [\[EBNF\]] appearing in
 the Value column.
3. By reference to an [ABNF symbol](http://tools.ietf.org/html/std68)
 defined in another specification
 \[[rfc5234](refs.html#ref-rfc5234)\]. This is indicated by
 [\[ABNF\]] appearing in the Value column.
4. As a URL as defined by the [URL
 Standard](https://url.spec.whatwg.org/)
 \[[URL](refs.html#ref-URL)\]. This is indicated by
 [\[URL\]] appearing in the Value column.
5. As a type as defined by the [HTML
 Standard](https://html.spec.whatwg.org/)
 \[[HTML](refs.html#ref-html)\]. This is indicated by
 [\[HTML\]] appearing in the Value column.
6. In prose, below the attribute definition table. This is indicated by
 the text \"(see below)\" appearing in the Value column.

 -------------------- ----------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Consider relaxing case sensitivity of presentation attribute values.
 Resolution: [We will make property values case insensitivity.](http://www.w3.org/2011/10/28-svg-irc#T16-40-11)
 Purpose: To align presentation attribute syntax parsing with parsing of the corresponding CSS property.
 Owner: Cameron ([ACTION-3276](http://www.w3.org/Graphics/SVG/WG/track/actions/3276))
 Status: Done
 -------------------- ----------------------------------------------------------------------------------------------------

When a [presentation attribute](styling.html#TermPresentationAttribute)
defined using the CSS Value Definition Syntax is parsed, this is done as
follows:

1. Let `value` be the value of the attribute.
2. Let `grammar` be the grammar given in the attribute
 definition table\'s Value column.
3. Replace all instances of
 [\<length\>](https://www.w3.org/TR/css3-values/#lengths) in
 `grammar` with
 \[[\<length\>](https://www.w3.org/TR/css3-values/#lengths) \|
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers)\].
4. Replace all instances of
 [\<length-percentage\>](https://www.w3.org/TR/css-values/#typedef-length-percentage)
 in `grammar` with
 \[[\<length-percentage\>](https://www.w3.org/TR/css-values/#typedef-length-percentage)
 \| [\<number\>](https://www.w3.org/TR/css3-values/#numbers)\].
5. Replace all instances of
 [\<angle\>](https://www.w3.org/TR/css-values/#angles) in
 `grammar` with
 \[[\<angle\>](https://www.w3.org/TR/css-values/#angles) \|
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers)\].
6. Return the result of [parsing `value` with
 `grammar`](http://dev.w3.org/csswg/css-syntax/#parse-grammar).

The insertion of the
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) symbols allows
for unitless length and angles to be used in presentation attribute
while disallowing them in corresponding property values.

Note that all [presentation
attributes](styling.html#TermPresentationAttribute), since they are
defined by reference to their corresponding CSS properties, are defined
using the CSS Value Definition Syntax.

When any other attribute defined using the CSS Value Definition Syntax
is parsed, this is done by [parsing the attribute\'s value according to
the grammar given in attribute definition
table](http://dev.w3.org/csswg/css-syntax/#parse-grammar).

Note that this allows CSS comments and escapes to be used in such
attributes. For example, a value of [\'10\\px/\*\*/\']
would successfully parse as [\'10px\'] in the
['x'] presentation attribute of the
['[rect](shapes.html#RectElement)'] element.

When an attribute defined as a URL is parsed, this is done by invoking
the [URL parser](https://url.spec.whatwg.org/#concept-url-parser) with
the attribute\'s value as `input` and the document\'s URL as
`base` \[[URL](refs.html#ref-URL)\].

The Initial value column gives the [initial
value](types.html#TermInitialValue) for the attribute. When an attribute
fails to parse according to the specified CSS Value Definition Syntax,
ABNF or EBNF grammar, or if parsing according to the URL Standard or by
the prose describing how to parse the attribute indicates failure, the
attribute is assumed to have been specified as the given [initial
value](types.html#TermInitialValue).

The initial value of a [presentation
attribute](styling.html#TermPresentationAttribute) is its corresponding
property\'s initial value. Since the use of an [invalid
value](types.html#TermInvalidValue) in a [presentation
attribute](styling.html#TermPresentationAttribute) will be treated as if
the initial value was specified, this value can override values that
come from lower priority style sheet rules, such as those from the user
agent style sheet.

For example, although the user agent style sheet sets the value of the
[overflow](render.html#OverflowAndClipProperties) property to
[hidden] for
['[svg](struct.html#SVGElement)'] elements, specifying an
invalid presentation attribute such as
[overflow=\"invalid\"] will result in a rule setting
[overflow](render.html#OverflowAndClipProperties) to
[visible], overriding the user agent style sheet value.

The Animatable column indicates whether the attribute can be animated
using [animation
elements](https://svgwg.org/specs/animations/#TermAnimationElement) as
defined in the [SVG Animation](https://svgwg.org/specs/animations/)
module.

### 4.2.1. Real number precision
Unless stated otherwise, numeric values in SVG attributes and in
properties that are defined to have an effect on SVG elements must
support at least all finite single-precision values supported by the
host architecture.

It is recommended that higher precision floating point storage and
computation be performed on operations such as coordinate system
transformations to provide the best possible precision and to prevent
round-off errors.

[conforming SVG viewers](conform.html#ConformingSVGViewers) are required
to perform numerical computation in accordance with their conformance
class, as described in [Conformance Criteria](conform.html).

### 4.2.2. Clamping values which are restricted to a particular range
Some numeric attribute and property values have restricted ranges. Other
values will be restricted by the capabilities of the device. If not
otherwise specified, the user agent shall defer any out-of-range error
checking until as late as possible in the rendering process. This is
particularly important for device limitations, as compound operations
might produce intermediate values which are out-of-range but final
values which are within range.

## 4.3. SVG DOM overview
Conforming [SVG viewers](conform.html#TermSVGViewer) or [SVG
interpreters](conform.html#TermSVGInterpreter) that support [script
execution](conform.html#processing-modes) must implement SVG DOM
interfaces as defined throughout this specification, with the specific
requirements and dependencies listed in this section.

 -------------------- ----------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Improve the DOM.
 Resolution: [We will generally improve the SVG DOM for SVG 2.](http://www.w3.org/2011/10/27-svg-irc#T18-35-49)
 Purpose: Help authors use the SVG DOM by making it less Java-oriented.
 Owner: Cameron ([ACTION-3273](http://www.w3.org/Graphics/SVG/WG/track/actions/3273))
 Note: See [SVG 2 DOM](http://www.w3.org/Graphics/SVG/WG/wiki/SVG_2_DOM) Wiki page.
 -------------------- ----------------------------------------------------------------------------------------------------

 -------------------- ---------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Improve the SVG path DOM APIs.
 Resolution: [We will improve the SVG path DOM APIs in SVG 2.](http://www.w3.org/2011/10/27-svg-irc#T18-23-23)
 Purpose: Clean up SVGPathSegList interface, and possibly share an API with Canvas.
 Owner: Cameron (no action)
 -------------------- ---------------------------------------------------------------------------------------------------

### 4.3.1. Dependencies for SVG DOM support
The SVG DOM is defined in terms of [Web
IDL](https://heycam.github.io/webidl/) interfaces. All IDL fragments in
this specification must be interpreted as required for [conforming IDL
fragments](https://heycam.github.io/webidl/#dfn-conforming-set-of-idl-fragments),
as described in the Web IDL specification.
\[[WebIDL](refs.html#ref-webidl)\]

The SVG DOM builds upon a number of DOM specifications. In particular:

- The SVG DOM requires full support for the DOM, as defined by the most
 recent [Review Draft](https://dom.spec.whatwg.org/review-drafts/) of
 the DOM living standard at the time this specification was published,
 except for any features that have been removed or deprecated since.
 SVG software with DOM support should implement the [latest DOM
 standard](https://dom.spec.whatwg.org/) wherever possible
 \[[DOM](refs.html#ref-dom)\]
- The SVG DOM requires support for relevant aspects of [UI
 Events](https://www.w3.org/TR/uievents/) and [Clipboard API and
 events](https://www.w3.org/TR/clipboard-apis/)
 (\[[uievents](refs.html#ref-uievents)\],
 \[[clipboard-apis](refs.html#ref-clipboard-apis)\]). (For the specific
 features that are required, see [Relationship with UI
 Events](interact.html#RelationshipWithUIEVENTS).)
- The SVG DOM requires, at a minimum, complete support for all
 interfaces from [DOM Level 2
 Style](https://www.w3.org/TR/DOM-Level-2-Style/Overview.html)
 (\[[dom-level-2-style](refs.html#ref-dom-level-2-style)\]) that have
 not been dropped in the [CSS Object Model
 (CSSOM)](https://drafts.csswg.org/cssom/) specification. SVG software
 should implement the latest version of [CSS Object Model
 (CSSOM)](https://drafts.csswg.org/cssom/) wherever possible
 (\[[cssom-1](refs.html#ref-cssom-1)\])
- The SVG DOM requires complete support for [Geometry Interfaces Module
 Level 1](http://www.w3.org/TR/2014/CR-geometry-1-20141125/)
 (\[[geometry-1](refs.html#ref-geometry-1)\]).

### 4.3.2. Naming conventions
The SVG DOM follows similar naming conventions to HTML and DOM standards
(\[[HTML](refs.html#ref-html)\], \[[DOM](refs.html#ref-dom)\]).

All names are defined as one or more English words concatenated together
to form a single string. Property or method names start with the initial
keyword in lowercase, and each subsequent word starts with a capital
letter. For example, a property that returns document meta information
such as the date the file was created might be named
\"fileDateCreated\".

Interface names defined in this specification nearly all start with
\"SVG\". Interfaces that represent the DOM
[Element](https://dom.spec.whatwg.org/#interface-element)
object for an SVG-namespaced element follow the format
`SVG`*`ElementName`*`Element`, where *`ElementName`* is the element\'s
tag name with the initial letter capitalized. So
[SVGRadialGradientElement](pservers.html#InterfaceSVGRadialGradientElement)
is the interface for an
['[radialGradient](pservers.html#RadialGradientElement)']
element.

An exception to this casing convention is
[SVGSVGElement](struct.html#InterfaceSVGSVGElement), in
which the entire tag name is capitalized.

### 4.3.3. Elements in the SVG DOM
Any SVG software that is required to support the SVG DOM must enhance
the DOM elements created for [SVG document
fragments](struct.html#TermSVGDocumentFragment) as follows:

- Every
 [Element](https://dom.spec.whatwg.org/#interface-element)
 object that corresponds to a supported SVG element (that is, an
 element with namespace URI \"http://www.w3.org/2000/svg\" and a local
 name that is one of the elements defined in this specification or
 another specification implemented by the software) must also implement
 the DOM interface identified in the element definition.

- Elements in the SVG namespace whose local name does not match an
 element defined in any specification supported by the software must
 nonetheless implement the
 [SVGElement](types.html#InterfaceSVGElement) interface.

In [The ['rect'] element](shapes.html#RectElement), the
[SVGRectElement](shapes.html#InterfaceSVGRectElement)
interface is identified. This means that every
[Element](https://dom.spec.whatwg.org/#interface-element)
object whose namespace URI is \"http://www.w3.org/2000/svg\" and whose
local name is \"rect\" must also implement
[SVGRectElement](shapes.html#InterfaceSVGRectElement).

### 4.3.4. Reflecting content attributes in the DOM
Many SVG DOM properties (IDL attributes) [reflect] a content attribute or property on the corresponding
element, meaning that content and IDL attributes represent the same
underlying data. For example, the
[SVGAnimatedLength](types.html#InterfaceSVGAnimatedLength)
[ry](shapes.html#__svg__SVGRectElement__ry) in an
[SVGRectElement](shapes.html#InterfaceSVGRectElement)
reflects the [ry](geometry.html#RyProperty) presentation
attribute on the associated
['[rect](shapes.html#RectElement)'] element.

The way this reflection is done depends on the type of the IDL
attribute:

- If the type of the reflecting IDL attribute is a [primitive
 type](http://heycam.github.io/webidl/#dfn-primitive-type) (such as
 **long**, as used by
 [tabIndex](https://html.spec.whatwg.org/multipage/interaction.html#dom-tabindex)
 on [SVGElement](types.html#InterfaceSVGElement)) or
 **DOMString** (as used by
 [title](styling.html#__svg__SVGStyleElement__title) on
 [SVGStyleElement](styling.html#InterfaceSVGStyleElement)),
 then the rules for [reflecting content attributes in IDL
 attributes](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#reflect)
 in HTML are used.

- If the type of the reflecting IDL attribute is an
 [SVGAnimatedBoolean](types.html#InterfaceSVGAnimatedBoolean),
 [SVGAnimatedString](types.html#InterfaceSVGAnimatedString),
 [SVGAnimatedEnumeration](types.html#InterfaceSVGAnimatedEnumeration),
 [SVGAnimatedNumber](types.html#InterfaceSVGAnimatedNumber),
 [SVGAnimatedNumberList](types.html#InterfaceSVGAnimatedNumberList),
 [SVGAnimatedLength](types.html#InterfaceSVGAnimatedLength),
 [SVGAnimatedLengthList](types.html#InterfaceSVGAnimatedLengthList),
 [SVGAnimatedAngle](types.html#InterfaceSVGAnimatedAngle),
 [SVGAnimatedRect](types.html#InterfaceSVGAnimatedRect)
 or
 [SVGAnimatedPreserveAspectRatio](coords.html#InterfaceSVGAnimatedPreserveAspectRatio),
 then the rules in the corresponding section defining the reflecting
 interface are used.

 At a high level, the object\'s `baseVal` is used to reflect the value
 of the content attribute. For objects that reflect a CSS property, the
 `baseVal` is used to reflect the presentation attribute.

This relationship is live, and values must be synchronized (following
the rules in [Synchronizing reflected
values](#SynchronizingReflectedValues)) when either the attribute or its
reflected property is modified.

If the attribute hasn\'t been specified explicitly in the document
markup, the reflected object is nonetheless initialized upon access, to
the attribute\'s initial value. If the attribute\'s initial value is
[(none)], the object is initialized as defined in
[Reflecting an empty initial value](#SVGObjectInitialization). This
newly constructed object does not generate an attribute on the element
until it is modified for the first time. Modifications made to the
corresponding attribute are immediately reflected in the object.

If `lineElement.x1.baseVal` is accessed (where `lineElement` is an
instance of
[SVGLineElement](shapes.html#InterfaceSVGLineElement))
and the ['[x1](shapes.html#LineElementX1Attribute)']
attribute was not specified in the document, the returned
[SVGLength](types.html#InterfaceSVGLength) object would
represent the value [0 user units], because the initial
value for the attribute is [0].

### 4.3.5. Synchronizing reflected values
Whenever a reflected content attribute\'s base value changes, then the
reflecting object must be [synchronized], immediately after the value changed, by
running the following steps:

1. If the reflecting object is a [list
 interface](types.html#TermListInterface) object, then run the steps
 for [synchronizing a list interface object](#TermSynchronizeList).

2. Otherwise, update the object\'s value to be the base value of the
 reflected content attribute (using the attribute\'s [initial
 value](types.html#TermInitialValue) if it is not present or
 invalid).

 This will, for example, update the [value](#LengthValue) of an
 [SVGLength](types.html#InterfaceSVGLength) object.

When a [reflected](types.html#TermReflect) content attribute is to be
[reserialized],
optionally using a specific value, the following steps must be
performed:

1. Let `value` be the specific value given, or the value of
 the content attribute\'s reflecting IDL attribute if a specific
 value was not provided.
2. Depending on `value`\'s type:

 [SVGAnimatedBoolean](types.html#InterfaceSVGAnimatedBoolean)\
 [SVGAnimatedNumber](types.html#InterfaceSVGAnimatedNumber)\
 [SVGAnimatedLength](types.html#InterfaceSVGAnimatedLength)\
 [SVGAnimatedAngle](types.html#InterfaceSVGAnimatedAngle)\
 [SVGAnimatedRect](types.html#InterfaceSVGAnimatedRect)\
 [SVGAnimatedString](types.html#InterfaceSVGAnimatedString)\
 [SVGAnimatedNumberList](types.html#InterfaceSVGAnimatedNumberList)\
 [SVGAnimatedLengthList](types.html#InterfaceSVGAnimatedLengthList)\
 [SVGAnimatedTransformList](coords.html#InterfaceSVGAnimatedTransformList)
 : [Reserialize](#TermReserialize) the content attribute using
 `value`\'s baseVal member.

 [SVGAnimatedEnumeration](types.html#InterfaceSVGAnimatedEnumeration)

 : 1. Let `number` be the value of
 `value`\'s baseVal member.

 2. Let `keyword` be the content attribute\'s keyword
 value corresponding to `number`, or the empty
 string if `number` is 0.

 This means that if the enumeration value is somehow set to
 the \"unknown\" value, the content attribute will be set to
 the empty string. However, this unknown value can never be
 set directly on the `SVGAnimatedEnumeration` object; it
 represents an unknown attribute value set in the markup.

 3. Set the content attribute to `keyword`.

 boolean
 : Set the content attribute to \"true\" if `value` is
 true, and \"false\" otherwise.

 float\
 double
 : Set the content attribute to an implementation specific string
 that, if parsed as a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) using
 CSS syntax, would return the number value closest to
 `value`, given the implementation\'s supported [real
 number precision](#Precision).

 [SVGLength](types.html#InterfaceSVGLength)
 : Set the content attribute to the value that would be returned
 from getting `value`\'s
 [valueAsString](#__svg__SVGLength__valueAsString) member.

 [SVGAngle](types.html#InterfaceSVGAngle)
 : Set the content attribute to the value that would be returned
 from getting `value`\'s
 [valueAsString](#__svg__SVGAngle__valueAsString) member.

 [DOMRect](https://www.w3.org/TR/geometry-1/#DOMRect)

 : 1. Let `components` be a list of four values, being
 the values of the
 [x](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#dom-domrectreadonly-domrect-x),
 [y](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#dom-domrectreadonly-domrect-y),
 [width](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#dom-domrectreadonly-domrect-width)
 and
 [height](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#dom-domrectreadonly-domrect-height)
 members of `value`.
 2. Let `serialized components` be a list of four
 strings, where each is an implementation specific string
 that, if parsed as a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers)
 using CSS syntax, would return the number value closest to
 the corresponding value in `components`, given
 the implementation\'s supported [real number
 precision](#Precision).
 3. Set the content attribute to a string consisting of the
 strings in `serialized components` joined and
 separated by single U+0020 SPACE characters.

 DOMString
 : Set the content attribute to `value`.

 [SVGNumberList](types.html#InterfaceSVGNumberList)\
 [SVGLengthList](types.html#InterfaceSVGLengthList)\
 [SVGPointList](shapes.html#InterfaceSVGPointList)\
 [SVGTransformList](coords.html#InterfaceSVGTransformList)\
 [SVGStringList](types.html#InterfaceSVGStringList)

 : 1. Let `elements` be the list of values in
 `value`.

 The values will be
 [SVGNumber](types.html#InterfaceSVGNumber),
 [SVGLength](types.html#InterfaceSVGLength),
 [DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
 or
 [SVGTransform](coords.html#InterfaceSVGTransform)
 objects, or **DOMString** values, depending on
 `value`\'s type.

 2. Let `serialized elements` be a list of strings,
 where each string is formed based on the corresponding value
 in `elements` and its type:

 an [SVGNumber](types.html#InterfaceSVGNumber) object
 : The string is an implementation specific string that, if
 parsed as a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers)
 using CSS syntax, would return the number value closest
 to the
 [SVGNumber](types.html#InterfaceSVGNumber)
 object\'s [value](#__svg__SVGNumber__value) member,
 given the implementation\'s supported [real number
 precision](#Precision).

 an [SVGLength](types.html#InterfaceSVGLength) object
 : The string is the value that would be returned from
 getting the value\'s
 [valueAsString](#__svg__SVGLength__valueAsString)
 member.

 a [DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint) object
 : The string value is computed as follows:
 1. Let `string` be an empty string.
 2. Let `x` and `y` be the values
 of the
 [DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
 object\'s x and y coordinates, respectively.
 3. Append to `string` an implementation
 specific string that, if parsed as
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers)
 using CSS syntax, would return the number value
 closest to `x`, given the
 implementation\'s supported [real number
 precision](#Precision).
 4. Append a single U+002C COMMA character to
 `string`.
 5. Append to `string` an implementation
 specific string that, if parsed as
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers)
 using CSS syntax, would return the number value
 closest to `y`, given the
 implementation\'s supported [real number
 precision](#Precision).
 6. The string is `string`.

 a [SVGTransform](coords.html#InterfaceSVGTransform) object
 : The string is the
 [serialization](https://drafts.csswg.org/css-transforms-1/#serialization-of-transform-functions)
 of the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object\'s [matrix
 object](coords.html#TransformMatrixObject).

 a **DOMString**
 : The string is the **DOMString**\'s value itself.

 3. Set the content attribute to a string consisting of the
 strings in `serialized elements` joined and
 separated by single U+0020 SPACE characters.

### 4.3.6. Reflecting an empty initial value
When initializing an SVG DOM attribute that
[reflects](types.html#TermReflect) a null or empty initial value, then
the property must be initialized according to its data type, as defined
in this section. This occurs only if there is no explicit value for the
reflected content attribute, and the initial value in the attribute\'s
definition table is [(none)].

If an interface is not listed below that means that the object
initialization shall be done using the values for the objects that the
interface contains, e.g., an
[SVGAnimatedString](types.html#InterfaceSVGAnimatedString)
consists of two [DOMString] members, while a
[DOMRect](https://www.w3.org/TR/geometry-1/#DOMRect)
consists of many [double]s.

DOMString
: Initialized as the empty string ([\"\"]).

float\
long\
short\
Any other [numeric type](https://heycam.github.io/webidl/#dfn-numeric-type) defined in WebIDL
: Initialized as [0].

boolean
: Initialized as [false].

[SVGLength](types.html#InterfaceSVGLength)
: Initialized as [0 user units]
 ([SVG_LENGTHTYPE_NUMBER](types.html#__svg__SVGLength__SVG_LENGTHTYPE_NUMBER)).

[SVGLengthList](types.html#InterfaceSVGLengthList)\
[SVGNumberList](types.html#InterfaceSVGNumberList)\
[SVGPointList](shapes.html#InterfaceSVGPointList)\
[SVGStringList](types.html#InterfaceSVGStringList)\
[SVGTransformList](coords.html#InterfaceSVGTransformList)
: Initialized as the empty list.

[SVGAngle](types.html#InterfaceSVGAngle)
: Initialized as [0 in unspecified units]
 ([SVG_ANGLETYPE_UNSPECIFIED](types.html#__svg__SVGAngle__SVG_ANGLETYPE_UNSPECIFIED)).

[SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
: Initialized as [\'xMidYMid meet\'].

If `textElement.dx.baseVal` is accessed (where `textElement` is an
instance of
[SVGTextElement](text.html#InterfaceSVGTextElement)) and
the ['[dx](text.html#TextElementDXAttribute)'] attribute was
not specified in the document, the returned
[SVGLengthList](types.html#InterfaceSVGLengthList) object
would be empty.

### 4.3.7. Invalid values
If a script sets a [reflected](types.html#TermReflect) DOM attribute to
an [invalid value](types.html#TermInvalidValue) for the content
attribute (e.g., a negative number for an attribute that requires a
non-negative number), unless this specification indicates otherwise, no
exception shall be raised on setting, but the given document fragment
shall become technically *in error* as described in [Error
processing](conform.html#ErrorProcessing).

DOM attributes that reflect enumerated values using integer constants
are an exception: these throw a
[TypeError](https://heycam.github.io/webidl/#exceptiondef-typeerror)
when set to an out-of-range integer, or to the constant (0) that
represents an unknown attribute value. This is consistent with the
[behavior of the WebIDL enumeration
type](https://heycam.github.io/webidl/#es-enumeration)
\[[WebIDL](refs.html#ref-webidl)\].

## 4.4. DOM interfaces for SVG elements
::::: ready-for-wider-review
### 4.4.1. Interface SVGElement
All of the SVG DOM interfaces that correspond directly to elements in
the SVG language (such as the
[SVGPathElement](paths.html#InterfaceSVGPathElement)
interface for the ['[path](paths.html#PathElement)']
element) derive from the
[SVGElement](types.html#InterfaceSVGElement) interface.

The CSSOM specification [augments SVGElement with a style IDL
attribute](http://dev.w3.org/csswg/cssom/#the-elementcssinlinestyle-interface),
so that the ['[style](styling.html#StyleAttribute)']
attribute can be accessed in the same way as on HTML elements.

``` idl
[Exposed=Window]
interface SVGElement : Element {

 [SameObject] readonly attribute SVGAnimatedString className;

 readonly attribute SVGSVGElement? ownerSVGElement;
 readonly attribute SVGElement? viewportElement;
};

SVGElement includes GlobalEventHandlers;
SVGElement includes SVGElementInstance;
SVGElement includes HTMLOrSVGElement;
```

The **className** IDL attribute [reflects](types.html#TermReflect) the
['[class](styling.html#ClassAttribute)'] attribute.

This attribute is deprecated and may be removed in a future version of
this specification. Authors are advised to use Element.classList
instead.

The [className](types.html#__svg__SVGElement__className) attribute on
[SVGElement](types.html#InterfaceSVGElement) overrides
the correspond attribute on
[Element](https://dom.spec.whatwg.org/#interface-element),
following the WebIDL rules for
[inheritance](https://www.w3.org/TR/WebIDL/#dfn-inherit).

The **ownerSVGElement** IDL attribute represents the nearest ancestor
['[svg](struct.html#SVGElement)'] element. On getting
[ownerSVGElement](#__svg__SVGElement__ownerSVGElement), the nearest
ancestor ['[svg](struct.html#SVGElement)'] element is
returned; if the current element is the [outermost svg
element](struct.html#TermOutermostSVGElement), then null is returned.

The **viewportElement** IDL attribute represents the element that
provides the SVG viewport for the current element. On getting
[viewport](#__svg__SVGElement__viewportElement), the nearest ancestor
element that establishes an SVG viewport is returned; if the current
element is the [outermost svg
element](struct.html#TermOutermostSVGElement), then null is returned.

### 4.4.2. Interface SVGGraphicsElement
 -------------------- -------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Detect if a mouse event is on the fill or stroke of a shape.
 Resolution: [SVG 2 will make it easier to detect if an mouse event is on the stroke or fill of an element.](http://www.w3.org/2012/03/22-svg-irc#T20-20-03)
 Purpose: To allow authors to discriminate between pointer events on the fill and stroke of an element without having to duplicate the element
 Owner: Cameron ([ACTION-3279](http://www.w3.org/Graphics/SVG/WG/track/actions/3279))
 Status: Done.
 -------------------- -------------------------------------------------------------------------------------------------------------------------------------------------

[SVGGraphicsElement](types.html#InterfaceSVGGraphicsElement)
interface represents SVG elements whose primary purpose is to directly
render graphics into a group.

``` idl
dictionary SVGBoundingBoxOptions {
 boolean fill = true;
 boolean stroke = false;
 boolean markers = false;
 boolean clipped = false;
};

[Exposed=Window]
interface SVGGraphicsElement : SVGElement {
 [SameObject] readonly attribute SVGAnimatedTransformList transform;

 DOMRect getBBox(optional SVGBoundingBoxOptions options = );
 DOMMatrix? getCTM();
 DOMMatrix? getScreenCTM();
};

SVGGraphicsElement includes SVGTests;
```

The **transform** IDL attribute [reflects](types.html#TermReflect) the
computed value of the
[transform](coords.html#TransformProperty) property and its
corresponding ['transform'] presentation attribute.

The **getBBox** method is used to compute the bounding box of the
current element. When the getBBox(`options`) method is
called, the [bounding box algorithm](coords.html#BoundingBoxes) is
invoked for the current element, with `fill`,
`stroke`, `markers` and `clipped`
members of the `options` dictionary argument used to control
which parts of the element are included in the bounding box, using the
element\'s user coordinate system as the coordinate system to return the
bounding box in. A newly created
[DOMRect](https://www.w3.org/TR/geometry-1/#DOMRect)
object that defines the computed bounding box is returned. If
[getBBox](types.html#__svg__SVGGraphicsElement__getBBox) gets called on
a [non-rendered element](render.html#TermNonRenderedElement), and the UA
is not able to compute the geometry of the element, then throw an
[InvalidStateError](https://heycam.github.io/webidl/#invalidstateerror).

The **getCTM** method is used to get the matrix that transforms the
current element\'s coordinate system to its SVG viewport\'s coordinate
system. When getCTM() is called, the following steps are run:

1. If the current element is not in the document, then return null.
2. If the current element is a [non-rendered
 element](render.html#TermNonRenderedElement), and the UA is not able
 to resolve the style of the element, then return null.
3. Let `ctm` be a matrix determined based on what the
 current element is:

 the current element is the [outermost svg element](struct.html#TermOutermostSVGElement)
 : `ctm` is a matrix that transforms the coordinate
 space of the ['[svg](struct.html#SVGElement)']
 (including its
 [transform](coords.html#TransformProperty) property)
 to the coordinate space of the document\'s viewport. The matrix
 includes the transforms produced by the
 ['[viewBox](coords.html#ViewBoxAttribute)'] and
 ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 attributes, the
 [transform](coords.html#TransformProperty) property,
 and any transform due to
 [currentScale](struct.html#__svg__SVGSVGElement__currentScale)
 and
 [currentTranslate](struct.html#__svg__SVGSVGElement__currentTranslate)
 properties on the
 [SVGSVGElement](struct.html#InterfaceSVGSVGElement).

 any other element
 : `ctm` is a matrix that transforms the coordinate
 space of the current element (including its
 [transform](coords.html#TransformProperty) property)
 to the coordinate space of its closest ancestor
 viewport-establishing element (also including its
 [transform](coords.html#TransformProperty) property).
4. Return a newly created, [detached](coords.html#MatrixMode)
 [DOMMatrix](https://www.w3.org/TR/geometry-1/#DOMMatrix)
 object that represents the same matrix as `ctm`.

The **getScreenCTM** method is used to get the matrix that transforms
the current element\'s coordinate system to the coordinate system of the
SVG viewport for the SVG document fragment. When getScreenCTM() is
called, the following steps are run:

1. If the current element is not in the document, then return null.
2. If the current element is a [non-rendered
 element](render.html#TermNonRenderedElement), and the UA is not able
 to resolve the style of the element, then return null.
3. Let `ctm` be a matrix that transforms the coordinate
 space of the current element (including its
 [transform](coords.html#TransformProperty) property) to
 the coordinate space of the document\'s viewport.

 ::: note
 This will include:

 - all of the transforms from the current element up to the
 [outermost svg element](struct.html#TermOutermostSVGElement)
 - any transforms due to
 ['[viewBox](coords.html#ViewBoxAttribute)'],
 ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)'],
 the [transform](coords.html#TransformProperty) property
 and any transform due to
 [currentScale](struct.html#__svg__SVGSVGElement__currentScale) and
 [currentTranslate](struct.html#__svg__SVGSVGElement__currentTranslate)
 properties on the
 [SVGSVGElement](struct.html#InterfaceSVGSVGElement)
 for the [outermost svg
 element](struct.html#TermOutermostSVGElement)
 - any transforms from the SVG viewport\'s coordinate space to the
 document\'s viewport, i.e. taking into account the positions of
 all of the CSS boxes from the [outermost svg
 element](struct.html#TermOutermostSVGElement)\'s box to the
 initial containing block when the SVG document fragment is inline
 in an HTML document
 :::
4. Return a newly created, [detached](coords.html#MatrixMode)
 [DOMMatrix](https://www.w3.org/TR/geometry-1/#DOMMatrix)
 object that represents the same matrix as `ctm`.

This method would have been more aptly named as `getClientCTM`, but the
name `getScreenCTM` is kept for historical reasons.

::: ready-for-wider-review
### 4.4.3. Interface SVGGeometryElement
Interface
[SVGGeometryElement](types.html#InterfaceSVGGeometryElement)
represents SVG elements whose rendering is defined by geometry with an
[equivalent path](paths.html#TermEquivalentPath), and which can be
filled and stroked. This includes paths and the basic shapes.

``` idl
[Exposed=Window]
interface SVGGeometryElement : SVGGraphicsElement {
 [SameObject] readonly attribute SVGAnimatedNumber pathLength;

 boolean isPointInFill(optional DOMPointInit point = );
 boolean isPointInStroke(optional DOMPointInit point = );
 float getTotalLength();
 DOMPoint getPointAtLength(float distance);
};
```

The **isPointInFill** method, when invoked, must return true if the
point given by `point` passed to the method, in the
coordinate space of an element, is inside the intended path as
determined by the winding rule indicated by the
[fill-rule](painting.html#FillRuleProperty) property of an
element; and must return false otherwise. Open subpaths must be
implicitly closed when computing the area inside the path, without
affecting the actual subpaths. Points on the path itself must be
considered to be inside the path. The returned value is independent of
any visual CSS property but
[fill-rule](painting.html#FillRuleProperty) If either of the
`x` or `y` properties on `point` are
infinite or NaN, then the method must return false. If current element
is a [non-rendered element](render.html#TermNonRenderedElement), and the
UA is not able to compute the geometry of the element, then throw an
[InvalidStateError](https://heycam.github.io/webidl/#invalidstateerror).

[isPointInFill](#__svg__SVGGeometryElement__isPointInFill) takes the
winding rule indicated by the
[fill-rule](painting.html#FillRuleProperty) property of an
element even if the element is a child of a
['[clipPath](https://drafts.fxtf.org/css-masking-1/#ClipPathElement)']
element.

[isPointInFill](#__svg__SVGGeometryElement__isPointInFill) is aligned
with the
[isPointInPath](https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-ispointinpath)
method on the
[CanvasDrawPath](https://html.spec.whatwg.org/multipage/canvas.html#canvasdrawpath)
mixin as much as the SVG context allows it to be.

The **isPointInStroke** method, when invoked, must return true if the
point given by `point` passed to the method, in the
coordinate space of an element, is in or on the outline path of an
applied stroke on an element; and must return false otherwise. The
outline path must take the stroke properties
[stroke-width](painting.html#StrokeWidthProperty),
[stroke-linecap](painting.html#StrokeLinecapProperty),
[stroke-linejoin](painting.html#StrokeLinejoinProperty),
[stroke-miterlimit](painting.html#StrokeMiterlimitProperty),
[stroke-dasharray](painting.html#StrokeDasharrayProperty),
[stroke-dashoffset](painting.html#StrokeDashoffsetProperty)
and [vector-effect](coords.html#VectorEffectProperty) of an
element into account. See sections [Computing the shape of the
stroke](https://svgwg.org/svg2-draft/painting.html#StrokeShape) and
[Vector
effects](https://svgwg.org/svg2-draft/painting.html#PaintingVectorEffects)
for details. The returned value is independent of any visual CSS
property but the listed stroke properties. If either of the
`x` or `y` properties on `point` are
infinite or NaN, then the method must return false. If current element
is a [non-rendered element](render.html#TermNonRenderedElement), and the
UA is not able to compute the geometry of the element, then throw an
[InvalidStateError](https://heycam.github.io/webidl/#invalidstateerror).

[isPointInStroke](types.html#__svg__SVGGeometryElement__isPointInStroke)
is aligned with the
[isPointInStroke](https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-ispointinstroke)
method on the
[CanvasDrawPath](https://html.spec.whatwg.org/multipage/canvas.html#canvasdrawpath)
mixin as much as the SVG context allows it to be.

The **pathLength** IDL attribute [reflects](types.html#TermReflect) the
['[pathLength](paths.html#PathLengthAttribute)'] content
attribute.

The **getTotalLength** method is used to compute the length of the path.
When getTotalLength() is called, the user agent\'s computed value for
the total length of the path, in user units, is returned. If current
element is a [non-rendered element](render.html#TermNonRenderedElement),
and the UA is not able to compute the total length of the path, then
throw an
[InvalidStateError](https://heycam.github.io/webidl/#invalidstateerror).

The user agent\'s computed path length does not take the
['[pathLength](paths.html#PathLengthAttribute)'] attribute
into account.

The **getPointAtLength** method is used to return the point at a given
distance along the path. When getPointAtLength(`distance`) is
called, the following steps are run:

1. If current element is a [non-rendered
 element](render.html#TermNonRenderedElement), and the UA is not able
 to compute the total length of the path, then throw an
 [InvalidStateError](https://heycam.github.io/webidl/#invalidstateerror).

2. Let `length` be the user agent\'s computed value for the
 total length of the path, in user units.

 As with
 [getTotalLength](#__svg__SVGGeometryElement__getTotalLength), this
 does not take into account the
 ['[pathLength](paths.html#PathLengthAttribute)']
 attribute.

3. Clamp `distance` to \[0, `length`\].

4. Let (`x`, `y`) be the point on the path at
 distance `distance`.

5. Return a newly created, [detached](shapes.html#PointMode)
 [DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
 object representing the point (`x`, `y`).

## 4.5. DOM interfaces for basic data types
### 4.5.1. Interface SVGNumber
The [SVGNumber](types.html#InterfaceSVGNumber) interface
is used primarily to represent a
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) value that is a
part of an
[SVGNumberList](types.html#InterfaceSVGNumberList).
Individual [SVGNumber](types.html#InterfaceSVGNumber)
objects can also be created by script.

An [SVGNumber](types.html#InterfaceSVGNumber) object can
be designated as *read only*, which means that attempts to modify the
object will result in an exception being thrown, as described below.
[SVGNumber](types.html#InterfaceSVGNumber) objects
reflected through the animVal IDL attribute are always *read only*.

An [SVGNumber](types.html#InterfaceSVGNumber) object can
be *associated* with a particular element. The associated element is
used to determine which element\'s content attribute to update if the
object [reflects](types.html#TermReflect) an attribute. Unless otherwise
described, an [SVGNumber](types.html#InterfaceSVGNumber)
object is not associated with any element.

::: ready-for-wider-review
Every [SVGNumber](types.html#InterfaceSVGNumber) object
operates in one of two modes. It can:

1. *reflect an element of the base value* of a
 [reflected](types.html#TermReflect) animatable attribute (being
 exposed through the methods on the
 [baseVal](types.html#__svg__SVGAnimatedNumberList__baseVal) member
 of an
 [SVGAnimatedNumberList](types.html#InterfaceSVGAnimatedNumberList)),
2. *be detached*, which is the case for
 [SVGNumber](types.html#InterfaceSVGNumber) objects
 created with
 [createSVGNumber](struct.html#__svg__SVGSVGElement__createSVGNumber).

An [SVGNumber](types.html#InterfaceSVGNumber) object
maintains an internal number value, which is called its
[value].

``` idl
[Exposed=Window]
interface SVGNumber {
 attribute float value;
};
```

The **value** IDL attribute represents the number. On getting
[value](#__svg__SVGNumber__value), the
[SVGNumber](types.html#InterfaceSVGNumber)\'s
[value](#NumberValue) is returned.

On setting [value](#__svg__SVGNumber__value), the following steps are
run:

1. If the [SVGNumber](types.html#InterfaceSVGNumber) is
 [read only](#ReadOnlyNumber), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. Set the [SVGNumber](types.html#InterfaceSVGNumber)\'s
 [value](#NumberValue) to the value being assigned to the
 [value](#__svg__SVGNumber__value) member.
3. If the [SVGNumber](types.html#InterfaceSVGNumber)
 [reflects an element of the base value](#NumberMode) of a
 [reflected](types.html#TermReflect) attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

### 4.5.2. Interface SVGLength
The [SVGLength](types.html#InterfaceSVGLength) interface
is used to represent a value that can be a
[\<length\>](https://www.w3.org/TR/css3-values/#lengths),
[\<percentage\>](https://www.w3.org/TR/css3-values/#percentages) or
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) value.

An [SVGLength](types.html#InterfaceSVGLength) object can
be designated as *read only*, which means that attempts to modify the
object will result in an exception being thrown, as described below.
[SVGLength](types.html#InterfaceSVGLength) objects
reflected through the animVal IDL attribute are always *read only*.

An [SVGLength](types.html#InterfaceSVGLength) object can
be *associated* with a particular element, as well as being designated
with a *directionality*: horizontal, vertical or unspecified. The
associated element and the directionality of the length are used to
resolve percentage values to user units and is also used to determine
which element\'s content attribute to update if the object
[reflects](types.html#TermReflect) an attribute. Unless otherwise
described, an [SVGLength](types.html#InterfaceSVGLength)
object is not associated with any element and has unspecified
directionality.

::: ready-for-wider-review
Every [SVGLength](types.html#InterfaceSVGLength) object
operates in one of four modes. It can:

1. *reflect the base value* of a [reflected](types.html#TermReflect)
 animatable attribute (being exposed through the
 [baseVal](types.html#__svg__SVGAnimatedLength__baseVal) member of an
 [SVGAnimatedLength](types.html#InterfaceSVGAnimatedLength)),
2. *reflect a presentation attribute value* (such as by
 [SVGRectElement.width.baseVal](shapes.html#__svg__SVGRectElement__width)),
3. *reflect an element of the base value* of a
 [reflected](types.html#TermReflect) animatable attribute (being
 exposed through the methods on the
 [baseVal](types.html#__svg__SVGAnimatedLengthList__baseVal) member
 of an
 [SVGAnimatedLengthList](types.html#InterfaceSVGAnimatedLengthList)),
 or
4. *be detached*, which is the case for
 [SVGLength](types.html#InterfaceSVGLength) objects
 created with
 [createSVGLength](struct.html#__svg__SVGSVGElement__createSVGLength).

An [SVGLength](types.html#InterfaceSVGLength) object
maintains an internal
[\<length\>](https://www.w3.org/TR/css3-values/#lengths) or
[\<percentage\>](https://www.w3.org/TR/css3-values/#percentages) or
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) value, which is
called its [value].

``` idl
[Exposed=Window]
interface SVGLength {

 // Length Unit Types
 const unsigned short SVG_LENGTHTYPE_UNKNOWN = 0;
 const unsigned short SVG_LENGTHTYPE_NUMBER = 1;
 const unsigned short SVG_LENGTHTYPE_PERCENTAGE = 2;
 const unsigned short SVG_LENGTHTYPE_EMS = 3;
 const unsigned short SVG_LENGTHTYPE_EXS = 4;
 const unsigned short SVG_LENGTHTYPE_PX = 5;
 const unsigned short SVG_LENGTHTYPE_CM = 6;
 const unsigned short SVG_LENGTHTYPE_MM = 7;
 const unsigned short SVG_LENGTHTYPE_IN = 8;
 const unsigned short SVG_LENGTHTYPE_PT = 9;
 const unsigned short SVG_LENGTHTYPE_PC = 10;

 readonly attribute unsigned short unitType;
 attribute float value;
 attribute float valueInSpecifiedUnits;
 attribute DOMString valueAsString;

 undefined newValueSpecifiedUnits(unsigned short unitType, float valueInSpecifiedUnits);
 undefined convertToSpecifiedUnits(unsigned short unitType);
};
```

The numeric length unit type constants defined on
[SVGLength](types.html#InterfaceSVGLength) are used to
represent the type of an
[SVGLength](types.html#InterfaceSVGLength)\'s
[value](#LengthValue). Their meanings are as follows:

 Constant Meaning
 ------------------------------- ------------------------------------------------------------------------------------------------------------------
 **SVG_LENGTHTYPE_NUMBER** A unitless [\<number\>](https://www.w3.org/TR/css3-values/#numbers) interpreted as a value in [px].
 **SVG_LENGTHTYPE_PERCENTAGE** A [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages).
 **SVG_LENGTHTYPE_EMS** A [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with an [em] unit.
 **SVG_LENGTHTYPE_EXS** A [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with an [ex] unit.
 **SVG_LENGTHTYPE_PX** A [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with a [px] unit.
 **SVG_LENGTHTYPE_CM** A [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with a [cm] unit.
 **SVG_LENGTHTYPE_MM** A [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with a [mm] unit.
 **SVG_LENGTHTYPE_IN** A [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with an [in] unit.
 **SVG_LENGTHTYPE_PT** A [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with a [pt] unit.
 **SVG_LENGTHTYPE_PC** A [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with a [pc] unit.
 **SVG_LENGTHTYPE_UNKNOWN** Some other type of value.

The use of numeric length unit type constants is an anti-pattern and new
constant values will not be introduced for any other units or length
types supported by
[SVGLength](types.html#InterfaceSVGLength). If other
types of lengths are supported and used, the
[SVGLength](types.html#InterfaceSVGLength) uses the
[SVG_LENGTHTYPE_UNKNOWN](types.html#__svg__SVGLength__SVG_LENGTHTYPE_UNKNOWN)
unit type. See below for details on how the other properties of an
[SVGLength](types.html#InterfaceSVGLength) operate with
these types of lengths.

The **unitType** IDL attribute represents the type of value that the
[SVGLength](types.html#InterfaceSVGLength)\'s
[value](#LengthValue) is. On getting
[unitType](#__svg__SVGLength__unitType), the following steps are run:

1. If the [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) is a unitless
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers), a
 [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages), or
 a [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with an
 [em], [ex], [px],
 [cm], [mm], [in],
 [pt] or [pc] unit, then return the
 corresponding constant value from the length unit type table above.

2. Otherwise, return
 [SVG_LENGTHTYPE_UNKNOWN](types.html#__svg__SVGLength__SVG_LENGTHTYPE_UNKNOWN).

 For example, for a
 [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with a
 [ch] unit or one that has a non-scalar value such as
 [calc()],
 [SVG_LENGTHTYPE_UNKNOWN](types.html#__svg__SVGLength__SVG_LENGTHTYPE_UNKNOWN)
 would be returned.

The **value** IDL attribute represents the
[SVGLength](types.html#InterfaceSVGLength)\'s
[value](#LengthValue) in user units. On getting
[value](#__svg__SVGLength__value), the following steps are run:

1. Let `value` be the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue).
2. If `value` is a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers), return
 that number.
3. Let `viewport size` be a basis to resolve percentages
 against, based on the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [associated element](#LengthAssociatedElement) and
 [directionality](#LengthAssociatedElement):

 has no [associated element](#LengthAssociatedElement)
 : `size` is 100

 has an [associated element](#LengthAssociatedElement) and horizontal [directionality](#LengthAssociatedElement)
 : `size` is the width of the [associated
 element](#LengthAssociatedElement)\'s SVG viewport

 has an [associated element](#LengthAssociatedElement) and vertical [directionality](#LengthAssociatedElement)
 : `size` is the height of the [associated
 element](#LengthAssociatedElement)\'s SVG viewport

 has an [associated element](#LengthAssociatedElement) and unspecified [directionality](#LengthAssociatedElement)
 : `size` is the length of the [associated
 element](#LengthAssociatedElement)\'s SVG viewport diagonal (see
 [Units](coords.html#Units))
4. Let `font size` be a basis to resolve font size values
 against, based on the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [associated element](#LengthAssociatedElement):

 has no [associated element](#LengthAssociatedElement)
 : `font size` is the absolute length of the initial
 value of the
 [font-size](https://www.w3.org/TR/css-fonts-3/#font-size-prop)
 property

 has an [associated element](#LengthAssociatedElement)
 : `size` is the computed value of the [associated
 element](#LengthAssociatedElement)\'s
 [font-size](https://www.w3.org/TR/css-fonts-3/#font-size-prop)
 property
5. Return the result of converting `value` to an absolute
 length, using `viewport size` and `font size`
 as percentage and font size bases. If the conversion is not possible
 due to the lack of an [associated
 element](#LengthAssociatedElement), return 0.

On setting [value](#__svg__SVGLength__value), the following steps are
run:

1. If the [SVGLength](types.html#InterfaceSVGLength)
 object is [read only](#ReadOnlyLength), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. Let `value` be the value being assigned to
 [value](#__svg__SVGLength__value).
3. Set the [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) to a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) whose value
 is `value`.
4. If the [SVGLength](types.html#InterfaceSVGLength)
 [reflects the base value](#LengthMode) of a
 [reflected](types.html#TermReflect) attribute, [reflects a
 presentation attribute](#LengthMode), or [reflects an element of the
 base value](#LengthMode) of a [reflected](types.html#TermReflect)
 attribute, then [reserialize](types.html#TermReserialize) the
 reflected attribute.

The **valueInSpecifiedUnits** IDL attribute represents the numeric
factor of the
[SVGLength](types.html#InterfaceSVGLength)\'s
[value](#LengthValue). On getting
[valueInSpecifiedUnits](#__svg__SVGLength__valueInSpecifiedUnits), the
following steps are run:

1. Let `value` be the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue).

2. If `value` is a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers), return
 that number.

3. Otherwise, if `value` is a
 [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages) or
 any scalar [\<length\>](https://www.w3.org/TR/css3-values/#lengths)
 value, return the numeric factor before its unit.

4. Otherwise, return 0.

 Thus
 [valueInSpecifiedUnits](#__svg__SVGLength__valueInSpecifiedUnits)
 would return 12 for both [\'12%\'] and
 [12em], but 0 would be returned for non-scalar values
 like [calc(12px + 5%)].

On setting
[valueInSpecifiedUnits](#__svg__SVGLength__valueInSpecifiedUnits), the
following steps are run:

1. If the [SVGLength](types.html#InterfaceSVGLength)
 object is [read only](#ReadOnlyLength), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. Let `value` be the value being assigned to
 [valueInSpecifiedUnits](#__svg__SVGLength__valueInSpecifiedUnits).
3. If the [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) is a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers), then
 update its value to `value`.
4. Otherwise, if the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) is a
 [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages) or
 a scalar-valued
 [\<length\>](https://www.w3.org/TR/css3-values/#lengths), then
 update its numeric factor to `value`.
5. Otherwise, the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) is of some other type. Set it to a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) whose value
 is `value`.
6. If the [SVGLength](types.html#InterfaceSVGLength)
 [reflects the base value](#LengthMode) of a
 [reflected](types.html#TermReflect) attribute or [reflects an
 element of the base value](#LengthMode) of a
 [reflected](types.html#TermReflect) attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

The **valueAsString** IDL attribute represents the
[SVGLength](types.html#InterfaceSVGLength)\'s
[value](#LengthValue) as a string. On getting
[valueAsString](#__svg__SVGLength__valueAsString), the following steps
are run:

1. Let `value` be the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue).
2. Let `string` be an empty string.
3. If `value` is a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers),
 [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages) or
 scalar [\<length\>](https://www.w3.org/TR/css3-values/#lengths)
 value, then:
 1. Let `factor` be `value`\'s numeric factor,
 if it is a
 [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages)
 or [\<length\>](https://www.w3.org/TR/css3-values/#lengths), or
 `value` itself it is a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers).
 2. Append to `string` an implementation specific string
 that, if parsed as a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) using
 CSS syntax, would return the number value closest to
 `factor`, given the implementation\'s supported [real
 number precision](#Precision).
 3. If `value` is a
 [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages)
 then append to `string` a single U+0025 PERCENT SIGN
 character.
 4. Otherwise, if `value` is a
 [\<length\>](https://www.w3.org/TR/css3-values/#lengths), then
 append to `string` the canonical spelling of
 `value`\'s unit.
 5. Return `string`.
4. Otherwise, return an implementation specific string that, if parsed
 as a [\<length\>](https://www.w3.org/TR/css3-values/#lengths), would
 return the closest length value to `value`, given the
 implementation\'s supported [real number precision](#Precision).

On setting [valueAsString](#__svg__SVGLength__valueAsString), the
following steps are run:

1. If the [SVGLength](types.html#InterfaceSVGLength)
 object is [read only](#ReadOnlyLength), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. Let `value` be the value being assigned to
 [valueAsString](#__svg__SVGLength__valueAsString).
3. Parse `value` using the CSS syntax \[
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) \|
 [\<length\>](https://www.w3.org/TR/css3-values/#lengths) \|
 [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages) \].
4. If parsing failed, then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [SyntaxError](https://heycam.github.io/webidl/#syntaxerror).
5. Otherwise, parsing succeeded. Set
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) to the parsed value.
6. If the [SVGLength](types.html#InterfaceSVGLength)
 [reflects the base value](#LengthMode) of a
 [reflected](types.html#TermReflect) attribute or [reflects an
 element of the base value](#LengthMode) of a
 [reflected](types.html#TermReflect) attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

The **newValueSpecifiedUnits** method is used to set the
[SVGLength](types.html#InterfaceSVGLength)\'s value in a
typed manner. When newValueSpecifiedUnits(unitType,
valueInSpecifiedUnits) is called, the following steps are run:

1. If the [SVGLength](types.html#InterfaceSVGLength)
 object is [read only](#ReadOnlyLength), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. If `unitType` is
 [SVG_LENGTHTYPE_UNKNOWN](types.html#__svg__SVGLength__SVG_LENGTHTYPE_UNKNOWN)
 or is a value that does not appear in the length unit type table
 above, then [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NotSupportedError](https://heycam.github.io/webidl/#notsupportederror).
3. Set [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) depending on the value of
 `unitType`:

 [SVG_LENGTHTYPE_NUMBER](types.html#__svg__SVGLength__SVG_LENGTHTYPE_NUMBER)
 : a [\<number\>](https://www.w3.org/TR/css3-values/#numbers) whose
 value is `valueInSpecifiedUnits`

 [SVG_LENGTHTYPE_PERCENTAGE](types.html#__svg__SVGLength__SVG_LENGTHTYPE_PERCENTAGE)
 : a
 [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages)
 whose numeric factor is `valueInSpecifiedUnits`

 anything else
 : a [\<length\>](https://www.w3.org/TR/css3-values/#lengths) whose
 numeric factor is `valueInSpecifiedUnits` and whose
 unit is as indicated by the length unit type table above
4. If the [SVGLength](types.html#InterfaceSVGLength)
 [reflects the base value](#LengthMode) of a
 [reflected](types.html#TermReflect) attribute or [reflects an
 element of the base value](#LengthMode) of a
 [reflected](types.html#TermReflect) attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

The **convertToSpecifiedUnits** method is used to convert the
[SVGLength](types.html#InterfaceSVGLength)\'s value to a
specific type. When convertToSpecifiedUnits(unitType) is called, the
following steps are run:

1. If the [SVGLength](types.html#InterfaceSVGLength)
 object is [read only](#ReadOnlyLength), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. If `unitType` is
 [SVG_LENGTHTYPE_UNKNOWN](types.html#__svg__SVGLength__SVG_LENGTHTYPE_UNKNOWN)
 or is a value that does not appear in the length unit type table
 above, then [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NotSupportedError](https://heycam.github.io/webidl/#notsupportederror).
3. Let `absolute` be the value that would be returned from
 the [value](#__svg__SVGLength__value) member.
4. If `unitType` is
 [SVG_LENGTHTYPE_NUMBER](types.html#__svg__SVGLength__SVG_LENGTHTYPE_NUMBER),
 then:
 1. Set the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) to a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) whose
 value is `absolute`.
5. Otherwise, if `unitType` is
 [SVG_LENGTHTYPE_PERCENTAGE](types.html#__svg__SVGLength__SVG_LENGTHTYPE_PERCENTAGE),
 then:
 1. Let `viewport size` be a basis to resolve percentages
 against, based on the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [associated element](#LengthAssociatedElement) and
 [directionality](#LengthAssociatedElement):

 has no [associated element](#LengthAssociatedElement)
 : `size` is 100

 has an [associated element](#LengthAssociatedElement) and horizontal [directionality](#LengthAssociatedElement)
 : `size` is the width of the [associated
 element](#LengthAssociatedElement)\'s SVG viewport

 has an [associated element](#LengthAssociatedElement) and vertical [directionality](#LengthAssociatedElement)
 : `size` is the height of the [associated
 element](#LengthAssociatedElement)\'s SVG viewport

 has an [associated element](#LengthAssociatedElement) and unspecified [directionality](#LengthAssociatedElement)
 : `size` is the length of the [associated
 element](#LengthAssociatedElement)\'s SVG viewport diagonal
 (see [Units](coords.html#Units))
 2. Set the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) to the result of converting
 `absolute` to a
 [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages),
 using `viewport size` as the percentage basis.
6. Otherwise, if `unitType` is
 [SVG_LENGTHTYPE_EMS](types.html#__svg__SVGLength__SVG_LENGTHTYPE_EMS)
 or
 [SVG_LENGTHTYPE_EXS](types.html#__svg__SVGLength__SVG_LENGTHTYPE_EXS),
 then:
 1. Let `font size` be a basis to resolve font size
 values against, based on the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [associated element](#LengthAssociatedElement):

 has no [associated element](#LengthAssociatedElement)
 : `font size` is the absolute length of the initial
 value of the
 [font-size](https://www.w3.org/TR/css-fonts-3/#font-size-prop)
 property

 has an [associated element](#LengthAssociatedElement)
 : `size` is the computed value of the [associated
 element](#LengthAssociatedElement)\'s
 [font-size](https://www.w3.org/TR/css-fonts-3/#font-size-prop)
 property
 2. Set the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) to the result of converting
 `absolute` to a
 [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with an
 [em] or [ex] unit (depending on
 `unitType`), using `font size` as the
 [font-size](https://www.w3.org/TR/css-fonts-3/#font-size-prop)
 basis.
7. Otherwise:
 1. Set the
 [SVGLength](types.html#InterfaceSVGLength)\'s
 [value](#LengthValue) to the result of converting
 `absolute` to a
 [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with
 the unit found by looking up `unitType` in the length
 unit type table above.
8. If the [SVGLength](types.html#InterfaceSVGLength)
 [reflects the base value](#LengthMode) of a
 [reflected](types.html#TermReflect) attribute or [reflects an
 element of the base value](#LengthMode) of a
 [reflected](types.html#TermReflect) attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

### 4.5.3. Interface SVGAngle
The [SVGAngle](types.html#InterfaceSVGAngle) interface is
used to represent a value that can be an
[\<angle\>](https://www.w3.org/TR/css-values/#angles) or
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) value.

An [SVGAngle](types.html#InterfaceSVGAngle) object can be
designated as *read only*, which means that attempts to modify the
object will result in an exception being thrown, as described below. An
[SVGAngle](types.html#InterfaceSVGAngle) reflected
through the animVal attribute is always *read only*.

An [SVGAngle](types.html#InterfaceSVGAngle) object can be
*associated* with a particular element. The associated element is used
to determine which element\'s content attribute to update if the object
[reflects](types.html#TermReflect) an attribute. Unless otherwise
described, an [SVGAngle](types.html#InterfaceSVGAngle)
object is not associated with any element.

::: ready-for-wider-review
Every [SVGAngle](types.html#InterfaceSVGAngle) object
operates in one of two modes. It can:

1. *reflect the base value* of a [reflected](types.html#TermReflect)
 animatable attribute (being exposed through the
 [baseVal](types.html#__svg__SVGAnimatedAngle__baseVal) member of an
 [SVGAnimatedAngle](types.html#InterfaceSVGAnimatedAngle)),
2. *be detached*, which is the case for
 [SVGAngle](types.html#InterfaceSVGAngle) objects
 created with
 [createSVGAngle](struct.html#__svg__SVGSVGElement__createSVGAngle).

An [SVGAngle](types.html#InterfaceSVGAngle) object
maintains an internal
[\<angle\>](https://www.w3.org/TR/css-values/#angles) or
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) value, which is
called its [value].

``` idl
[Exposed=Window]
interface SVGAngle {

 // Angle Unit Types
 const unsigned short SVG_ANGLETYPE_UNKNOWN = 0;
 const unsigned short SVG_ANGLETYPE_UNSPECIFIED = 1;
 const unsigned short SVG_ANGLETYPE_DEG = 2;
 const unsigned short SVG_ANGLETYPE_RAD = 3;
 const unsigned short SVG_ANGLETYPE_GRAD = 4;

 readonly attribute unsigned short unitType;
 attribute float value;
 attribute float valueInSpecifiedUnits;
 attribute DOMString valueAsString;

 undefined newValueSpecifiedUnits(unsigned short unitType, float valueInSpecifiedUnits);
 undefined convertToSpecifiedUnits(unsigned short unitType);
};
```

The numeric angle unit type constants defined on
[SVGAngle](types.html#InterfaceSVGAngle) are used to
represent the type of an
[SVGAngle](types.html#InterfaceSVGAngle)\'s
[value](#AngleValue). Their meanings are as follows:

 Constant Meaning
 ------------------------------- --------------------------------------------------------------------------------------------------------
 **SVG_ANGLETYPE_UNSPECIFIED** A unitless [\<number\>](https://www.w3.org/TR/css3-values/#numbers) interpreted as a value in degrees.
 **SVG_ANGLETYPE_DEG** An [\<angle\>](https://www.w3.org/TR/css-values/#angles) with a [deg] unit.
 **SVG_ANGLETYPE_RAD** An [\<angle\>](https://www.w3.org/TR/css-values/#angles) with a [rad] unit.
 **SVG_ANGLETYPE_GRAD** An [\<angle\>](https://www.w3.org/TR/css-values/#angles) with a [grad] unit.
 **SVG_ANGLETYPE_UNKNOWN** Some other type of value.

The use of numeric angle unit type constants is an anti-pattern and new
constant values will not be introduced for any other units or angle
types supported by
[SVGAngle](types.html#InterfaceSVGAngle). If other types
of angles are supported and used, the
[SVGAngle](types.html#InterfaceSVGAngle) uses the
[SVG_ANGLETYPE_UNKNOWN](types.html#__svg__SVGAngle__SVG_ANGLETYPE_UNKNOWN)
unit type. See below for details on how the other properties of an
[SVGAngle](types.html#InterfaceSVGAngle) operate with
these types of angles.

The **unitType** IDL attribute represents the type of value that the
[SVGAngle](types.html#InterfaceSVGAngle)\'s
[value](#AngleValue) is. On getting
[unitType](#__svg__SVGAngle__unitType), the following steps are run:

1. If the [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue) is a unitless
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) or a
 [\<length\>](https://www.w3.org/TR/css3-values/#lengths) with a
 [deg], [rad] or [grad] unit,
 then return the corresponding constant value from the angle unit
 type table above.

2. Otherwise, return
 [SVG_ANGLETYPE_UNKNOWN](types.html#__svg__SVGAngle__SVG_ANGLETYPE_UNKNOWN).

 For example, for an
 [\<angle\>](https://www.w3.org/TR/css-values/#angles) with a
 [turn] unit,
 [SVG_ANGLETYPE_UNKNOWN](types.html#__svg__SVGAngle__SVG_ANGLETYPE_UNKNOWN)
 would be returned.

The **value** IDL attribute represents the
[SVGAngle](types.html#InterfaceSVGAngle)\'s
[value](#AngleValue) in degrees. On getting
[value](#__svg__SVGAngle__value), the following steps are run:

1. Let `value` be the
 [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue).
2. If `value` is a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers), return
 that number.
3. Return the result of converting `value` to an angle in
 degrees.

On setting [value](#__svg__SVGAngle__value), the following steps are
run:

1. If the [SVGAngle](types.html#InterfaceSVGAngle)
 object is [read only](#ReadOnlyAngle), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. Let `value` be the value being assigned to
 [value](#__svg__SVGAngle__value).
3. Set the [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue) to a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) whose value
 is `value`.
4. If the [SVGAngle](types.html#InterfaceSVGAngle)
 [reflects the base value](#AngleMode) of a
 [reflected](types.html#TermReflect) attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

The **valueInSpecifiedUnits** IDL attribute represents the numeric
factor of the [SVGAngle](types.html#InterfaceSVGAngle)\'s
[value](#AngleValue). On getting
[valueInSpecifiedUnits](#__svg__SVGAngle__valueInSpecifiedUnits), the
following steps are run:

1. Let `value` be the
 [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue).
2. If `value` is a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers), return
 that number.
3. Otherwise, `value` is an
 [\<angle\>](https://www.w3.org/TR/css-values/#angles) value. Return
 the numeric factor before its unit.

On setting
[valueInSpecifiedUnits](#__svg__SVGAngle__valueInSpecifiedUnits), the
following steps are run:

1. If the [SVGAngle](types.html#InterfaceSVGAngle)
 object is [read only](#ReadOnlyAngle), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. Let `value` be the value being assigned to
 [valueInSpecifiedUnits](#__svg__SVGAngle__valueInSpecifiedUnits).
3. If the [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue) is a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers), then
 update its value to `value`.
4. Otherwise, if the
 [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue) is an
 [\<angle\>](https://www.w3.org/TR/css-values/#angles), then update
 its numeric factor to `value`.
5. If the [SVGAngle](types.html#InterfaceSVGAngle)
 [reflects the base value](#AngleMode) of a
 [reflected](types.html#TermReflect) attribute or [reflects an
 element of the base value](#AngleMode) of a
 [reflected](types.html#TermReflect) attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

The **valueAsString** IDL attribute represents the
[SVGAngle](types.html#InterfaceSVGAngle)\'s
[value](#AngleValue) as a string. On getting
[valueAsString](#__svg__SVGAngle__valueAsString), the following steps
are run:

1. Let `value` be the
 [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue).
2. Let `string` be an empty string.
3. Let `factor` be `value`\'s numeric factor, if
 it is an [\<angle\>](https://www.w3.org/TR/css-values/#angles), or
 `value` itself it is a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers).
4. Append to `string` an implementation specific string
 that, if parsed as a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) using CSS
 syntax, would return the number value closest to
 `factor`, given the implementation\'s supported [real
 number precision](#Precision).
5. If `value` is an
 [\<angle\>](https://www.w3.org/TR/css-values/#angles), then append
 to `string` the canonical spelling of
 `value`\'s unit.
6. Return `string`.

On setting [valueAsString](#__svg__SVGAngle__valueAsString), the
following steps are run:

1. If the [SVGAngle](types.html#InterfaceSVGAngle)
 object is [read only](#ReadOnlyAngle), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. Let `value` be the value being assigned to
 [valueAsString](#__svg__SVGAngle__valueAsString).
3. Parse `value` using the CSS syntax \[
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) \|
 [\<angle\>](https://www.w3.org/TR/css-values/#angles) \].
4. If parsing failed, then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [SyntaxError](https://heycam.github.io/webidl/#syntaxerror).
5. Otherwise, parsing succeeded. Set
 [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue) to the parsed value.
6. If the [SVGAngle](types.html#InterfaceSVGAngle)
 [reflects the base value](#AngleMode) of a
 [reflected](types.html#TermReflect) attribute or [reflects an
 element of the base value](#AngleMode) of a
 [reflected](types.html#TermReflect) attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

The **newValueSpecifiedUnits** method is used to set the
[SVGAngle](types.html#InterfaceSVGAngle)\'s value in a
typed manner. When newValueSpecifiedUnits(unitType,
valueInSpecifiedUnits) is called, the following steps are run:

1. If the [SVGAngle](types.html#InterfaceSVGAngle)
 object is [read only](#ReadOnlyAngle), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. If `unitType` is
 [SVG_ANGLETYPE_UNKNOWN](types.html#__svg__SVGAngle__SVG_ANGLETYPE_UNKNOWN)
 or is a value that does not appear in the angle unit type table
 above, then [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NotSupportedError](https://heycam.github.io/webidl/#notsupportederror).
3. Set [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue) depending on the value of
 `unitType`:

 [SVG_ANGLETYPE_UNSPECIFIED](types.html#__svg__SVGAngle__SVG_ANGLETYPE_UNSPECIFIED)
 : a [\<number\>](https://www.w3.org/TR/css3-values/#numbers) whose
 value is `valueInSpecifiedUnits`

 anything else
 : an [\<angle\>](https://www.w3.org/TR/css-values/#angles) whose
 numeric factor is `valueInSpecifiedUnits` and whose
 unit is as indicated by the angle unit type table above
4. If the [SVGAngle](types.html#InterfaceSVGAngle)
 [reflects the base value](#AngleMode) of a
 [reflected](types.html#TermReflect) attribute or [reflects an
 element of the base value](#AngleMode) of a
 [reflected](types.html#TermReflect) attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

The **convertToSpecifiedUnits** method is used to convert the
[SVGAngle](types.html#InterfaceSVGAngle)\'s value to a
specific type. When convertToSpecifiedUnits(unitType) is called, the
following steps are run:

1. If the [SVGAngle](types.html#InterfaceSVGAngle)
 object is [read only](#ReadOnlyAngle), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. If `unitType` is
 [SVG_ANGLETYPE_UNKNOWN](types.html#__svg__SVGAngle__SVG_ANGLETYPE_UNKNOWN)
 or is a value that does not appear in the angle unit type table
 above, then [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NotSupportedError](https://heycam.github.io/webidl/#notsupportederror).
3. Let `degrees` be the value that would be returned from
 the [value](#__svg__SVGAngle__value) member.
4. If `unitType` is
 [SVG_ANGLETYPE_UNSPECIFIED](types.html#__svg__SVGAngle__SVG_ANGLETYPE_UNSPECIFIED),
 then:
 1. Set the
 [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue) to a
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) whose
 value is `degrees`.
5. Otherwise:
 1. Set the
 [SVGAngle](types.html#InterfaceSVGAngle)\'s
 [value](#AngleValue) to the result of converting
 `degrees` to an
 [\<angle\>](https://www.w3.org/TR/css-values/#angles) with the
 unit found by looking up `unitType` in the angle unit
 type table above.
6. If the [SVGAngle](types.html#InterfaceSVGAngle)
 [reflects the base value](#AngleMode) of a
 [reflected](types.html#TermReflect) attribute or [reflects an
 element of the base value](#AngleMode) of a
 [reflected](types.html#TermReflect) attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

### 4.5.4. List interfaces
 -------------------- ---------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Make the SVGList\* interfaces a bit more like other lists/arrays.
 Resolution: [Add array style indexing and .length and .item to svg list types.](http://www.w3.org/2011/02/28-svg-minutes.html#item04)
 Purpose: To align with other array types (e.g. NodeList). Already implemented in Opera and Firefox.
 Owner: Erik ([ACTION-2975](http://www.w3.org/Graphics/SVG/WG/track/actions/2975))
 Status: Done
 -------------------- ---------------------------------------------------------------------------------------------------------------------------

Some SVG attributes contain lists of values, and to represent these
values there are a number of SVG DOM [list
interfaces], one for
each required element type --
[SVGNumberList](types.html#InterfaceSVGNumberList),
[SVGLengthList](types.html#InterfaceSVGLengthList),
[SVGPointList](shapes.html#InterfaceSVGPointList),
[SVGTransformList](coords.html#InterfaceSVGTransformList)
and [SVGStringList](types.html#InterfaceSVGStringList).
The first four are used to represent the base and animated components of
[SVGAnimatedNumberList](types.html#InterfaceSVGAnimatedNumberList),
[SVGAnimatedLengthList](types.html#InterfaceSVGAnimatedLengthList),
[SVGAnimatedPoints](shapes.html#InterfaceSVGAnimatedPoints)
and
[SVGTransformList](coords.html#InterfaceSVGTransformList)
objects, while the fifth,
[SVGStringList](types.html#InterfaceSVGStringList), is
used to [reflect](types.html#TermReflect) a few unanimated attributes
that take a list of strings.

Most [list interfaces](types.html#TermListInterface) take the following
form:

``` example
interface SVGNameList {

 readonly attribute unsigned long length;
 readonly attribute unsigned long numberOfItems;

 undefined clear();
 Type initialize(Type newItem);
 getter Type getItem(unsigned long index);
 Type insertItemBefore(Type newItem, unsigned long index);
 Type replaceItem(Type newItem, unsigned long index);
 Type removeItem(unsigned long index);
 Type appendItem(Type newItem);
 setter undefined (unsigned long index, Type newItem);
};
```

where `Name` is a descriptive name for the list element\'s
(\"Number\", \"Length\", \"Point\", \"Transform\" or \"String\") and
`Type` is the IDL type of the list\'s elements
([SVGNumber](types.html#InterfaceSVGNumber),
[SVGLength](types.html#InterfaceSVGLength),
[DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint),
[SVGTransform](coords.html#InterfaceSVGTransform) or
**DOMString**).

The
[SVGTransformList](coords.html#InterfaceSVGTransformList)
interface takes the above form but has two additional methods on it.

All [list interface](types.html#TermListInterface) objects apart from
[SVGTransformList](coords.html#InterfaceSVGTransformList)
reflect the base value of a reflected content attribute.
[SVGTransformList](coords.html#InterfaceSVGTransformList)
objects reflect a presentation attribute (['transform'],
['[gradientTransform](pservers.html#LinearGradientElementGradientTransformAttribute)']
or
['[patternTransform](pservers.html#PatternElementPatternTransformAttribute)']).
All [list interface](types.html#TermListInterface) objects are
associated with a particular element. Unlike
[SVGLength](types.html#InterfaceSVGLength) and similar
objects, there are no \"detached\" [list
interface](types.html#TermListInterface) objects.

A [list interface](types.html#TermListInterface) object maintains an
internal list of elements, which is referred to in the text below simply
as \"the list\". The IDL attributes and methods are used to inspect and
manipulate elements of the list. The list can also be changed in
response to changes to the reflected content attribute and to animation
of the content attribute (or, for
[SVGTransformList](coords.html#InterfaceSVGTransformList)
objects, in response to changes to the computed value of the
[transform](coords.html#TransformProperty) property).

A [list interface](types.html#TermListInterface) object can be
designated as *read only*, which means that attempts to modify the
object will result in an exception being thrown, as described below.
[list interface](types.html#TermListInterface) objects reflected through
the animVal IDL attribute are always *read only*.

A [list interface](types.html#TermListInterface) object is
[synchronized] by
running the following steps:

1. Let `value` be the base value of the reflected content
 attribute (using the attribute\'s [initial
 value](types.html#TermInitialValue) if it is not present or
 invalid).
2. Let `length` be the number of items in the list.
3. Let `new length` be the number of values in
 `value`. If `value` is the keyword
 [none] (as supported by the
 [transform](coords.html#TransformProperty) property),
 `new length` is 0.
4. If the list element type is
 [SVGNumber](types.html#InterfaceSVGNumber),
 [SVGLength](types.html#InterfaceSVGLength),
 [DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
 or [SVGTransform](coords.html#InterfaceSVGTransform),
 then:
 1. If `length` \> `new length`, then:
 1. [Detach](types.html#TermDetach) each object in the list at
 an index greater than or equal to `new length`.
 2. Truncate the list to length `new length`.
 3. Set `length` to `new length`.
 2. While `length` \< `new length`:
 1. Let `item` be a newly created object of the list
 element type.
 2. [Attach](types.html#TermAttach) `item` to this
 [list interface](types.html#TermListInterface) object.
 3. Append `item` to the list.
 4. Set `length` to `length` + 1.
 3. Let `index` be 0.
 4. While `index` \< `length`:
 1. Let `item` be the object in the list at index
 `index`.
 2. Let `v` be the value in `value` at
 index `index`.
 3. Set `item`\'s value to `v`.
 4. If `item` is an
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object, then set the components of its [matrix
 object](coords.html#TransformMatrixObject) to match the new
 transform function value.
 5. Set `index` to `index` + 1.
5. Otherwise, the list element type is **DOMString**:
 1. Replace the list with a new list consisting of the values in
 `value`.

Whenever a list element object is to be [detached], the following steps are run, depending on the
list element type:

[SVGNumber](types.html#InterfaceSVGNumber)
: Set the [SVGNumber](types.html#InterfaceSVGNumber) to
 no longer be [associated](#NumberAssociatedElement) with any
 element. If the
 [SVGNumber](types.html#InterfaceSVGNumber) is [read
 only](#ReadOnlyNumber), set it to be no longer read only.

[SVGLength](types.html#InterfaceSVGLength)
: Set the [SVGLength](types.html#InterfaceSVGLength) to
 no longer be [associated](#LengthAssociatedElement) with any
 element. If the
 [SVGLength](types.html#InterfaceSVGLength) is [read
 only](#ReadOnlyLength), set it to be no longer read only. Set the
 [SVGLength](types.html#InterfaceSVGLength) to have
 unspecified [directionality](#LengthAssociatedElement).

[DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
: Set the
 [DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
 to no longer be [associated](shapes.html#PointAssociatedElement)
 with any element. If the
 [DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
 is [read only](shapes.html#ReadOnlyPoint), set it to be no longer
 read only.

[SVGTransform](coords.html#InterfaceSVGTransform)
: Set the
 [SVGTransform](coords.html#InterfaceSVGTransform) to
 no longer be [associated](coords.html#TransformAssociatedElement)
 with any element. If the
 [SVGTransform](coords.html#InterfaceSVGTransform) is
 [read only](coords.html#ReadOnlyTransform), set it to be no longer
 read only.

**DOMString**
: Nothing is done.

Whenever a list element object is to be [attached], the following steps are run, depending on the
list element type:

::: ready-for-wider-review

[SVGNumber](types.html#InterfaceSVGNumber)
: [Associate](#NumberAssociatedElement) the
 [SVGNumber](types.html#InterfaceSVGNumber) with the
 element that the [list interface](types.html#TermListInterface)
 object is associated with. Additionally, depending on which IDL
 attribute the [list interface](types.html#TermListInterface) object
 is reflected through:

 baseVal
 : Set the
 [SVGNumber](types.html#InterfaceSVGNumber) to
 [reflect an element of the base value](#NumberMode).

 animVal
 : Set the
 [SVGNumber](types.html#InterfaceSVGNumber) to
 [reflect an element of the base value](#NumberMode).

[SVGLength](types.html#InterfaceSVGLength)
: [Associate](#LengthAssociatedElement) the
 [SVGLength](types.html#InterfaceSVGLength) with the
 element that the [list interface](types.html#TermListInterface)
 object is associated with and set its
 [directionality](#LengthAssociatedElement) to that specified by the
 attribute being reflected. Additionally, depending on which IDL
 attribute the [list interface](types.html#TermListInterface) object
 is reflected through:

 baseVal
 : Set the
 [SVGLength](types.html#InterfaceSVGLength) to
 [reflect an element of the base value](#LengthMode).

 animVal
 : Set the
 [SVGLength](types.html#InterfaceSVGLength) to
 [reflect an element of the base value](#LengthMode). Set the
 [SVGLength](types.html#InterfaceSVGLength) to be
 *read only*.

[DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
: [Associate](shapes.html#PointAssociatedElement) the
 [DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
 with the element that the [list
 interface](types.html#TermListInterface) object is associated with.
 Additionally, depending on which IDL attribute the [list
 interface](types.html#TermListInterface) object is reflected
 through:

 baseVal
 : Set the
 [DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
 to [reflect an element of the base
 value](shapes.html#PointMode).

 animVal
 : Set the
 [DOMPoint](https://www.w3.org/TR/geometry-1/#dom-dompoint)
 to [reflect an element of the base
 value](shapes.html#PointMode).

[SVGTransform](coords.html#InterfaceSVGTransform)
: [Associate](coords.html#TransformAssociatedElement) the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 with the element that the [list
 interface](types.html#TermListInterface) object is associated with.
 Set the
 [SVGTransform](coords.html#InterfaceSVGTransform) to
 [reflect an element of a presentation attribute
 value](coords.html#TransformMode).

**DOMString**
: Nothing is done.

The [supported property
indices](http://heycam.github.io/webidl/#dfn-supported-property-indices)
of a [list interface](types.html#TermListInterface) object is the set of
all non-negative integers less than the length of the list.

The **length** and **numberOfItems** IDL attributes represents the
length of the list, and on getting simply return the length of the list.

The **clear** method is used to remove all items in the list. When
clear() is called, the following steps are run:

1. If the list is [read only](#ReadOnlyList), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. [Detach](types.html#TermDetach) and then remove all elements in the
 list.
3. If the list [reflects](types.html#TermReflect) an attribute, or
 represents the base value of an object that
 [reflects](types.html#TermReflect) an attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.

The **initialize** method is used to clear the list and add a single,
specified value to it. When initialize(`newItem`) is called,
the following steps are run:

1. If the list is [read only](#ReadOnlyList), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. [Detach](types.html#TermDetach) and then remove all elements in the
 list.
3. If `newItem` is an object type, and `newItem`
 is not a detached object, then set `newItem` to be a
 newly created object of the same type as `newItem` and
 which has the same (number or length) value.
4. [Attach](types.html#TermAttach) `newItem` to the [list
 interface](types.html#TermListInterface) object.
5. Append `newItem` to this list.
6. If the list [reflects](types.html#TermReflect) an attribute, or
 represents the base value of an object that
 [reflects](types.html#TermReflect) an attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.
7. Return `newItem`.

The **getItem** method is used to get an item from the list at the
specified position. When getItem(`index`) is called, the
following steps are run:

1. If `index` is greater than or equal to the length of the
 list, then [throw](https://heycam.github.io/webidl/#dfn-throw) an
 [IndexSizeError](https://heycam.github.io/webidl/#indexsizeerror).

2. Return the element in the list at position `index`.

 Note that if the list\'s element type is an object type, such as
 [SVGLength](types.html#InterfaceSVGLength), then a
 reference to that object and not a copy of it is returned.

The **insertItemBefore** method is used to insert an element into the
list at a specific position. When insertItemBefore(`newItem`,
`index`) is called, the following steps are run:

1. If the list is [read only](#ReadOnlyList), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. If `newItem` is an object type, and `newItem`
 is not a detached object, then set `newItem` to be a
 newly created object of the same type as `newItem` and
 which has the same (number or length) value.
3. If `index` is greater than the length of the list, then
 set `index` to be the list length.
4. Insert `newItem` into the list at index
 `index`.
5. Attach `newItem` to the [list
 interface](types.html#TermListInterface) object.
6. If the list [reflects](types.html#TermReflect) an attribute, or
 represents the base value of an object that
 [reflects](types.html#TermReflect) an attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.
7. Return `newItem`.

The **replaceItem** method is used to replace an existing item in the
list with a new item. When replaceItem(`newItem`,
`index`) is called, the following steps are run:

1. If the list is [read only](#ReadOnlyList), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. If `index` is greater than or equal to the length of the
 list, then [throw](https://heycam.github.io/webidl/#dfn-throw) an
 [IndexSizeError](https://heycam.github.io/webidl/#indexsizeerror).
3. If `newItem` is an object type, and `newItem`
 is not a detached object, then set `newItem` to be a
 newly created object of the same type as `newItem` and
 which has the same (number or length) value.
4. [Detach](types.html#TermDetach) the element in the list at index
 `index`.
5. Replace the element in the list at index `index` with
 `newItem`.
6. [Attach](types.html#TermAttach) `newItem` to the [list
 interface](types.html#TermListInterface) object.
7. If the list [reflects](types.html#TermReflect) an attribute, or
 represents the base value of an object that
 [reflects](types.html#TermReflect) an attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.
8. Return `newItem`.

The **removeItem** method is used to remove an item from the list. When
removeItem(`index`) is called, the following steps are run:

1. If the list is [read only](#ReadOnlyList), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. If `index` is greater than or equal to the length of the
 list, then [throw](https://heycam.github.io/webidl/#dfn-throw) an
 [IndexSizeError](https://heycam.github.io/webidl/#indexsizeerror)
 with code.
3. Let `item` be the list element at index
 `index`.
4. [Detach](types.html#TermDetach) `item`.
5. Remove the list element at index `index`.
6. Return `item`.

The **appendItem** method is used to append an item to the end of the
list. When appendItem(`newItem`) is called, the following
steps are run:

1. If the list is [read only](#ReadOnlyList), then
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NoModificationAllowedError](https://heycam.github.io/webidl/#nomodificationallowederror).
2. If `newItem` is an object type, and `newItem`
 is not a detached object, then set `newItem` to be a
 newly created object of the same type as `newItem` and
 which has the same (number or length) value.
3. Let `index` be the length of the list.
4. Append `newItem` to the end of the list.
5. [Attach](types.html#TermAttach) `newItem` to the [list
 interface](types.html#TermListInterface) object.
6. If the list [reflects](types.html#TermReflect) an attribute, or
 represents the base value of an object that
 [reflects](types.html#TermReflect) an attribute, then
 [reserialize](types.html#TermReserialize) the reflected attribute.
7. Return `newItem`.

The behavior of the **indexed property setter** is the same as that for
the [replaceItem](#__svg__SVGNameList__replaceItem) method.

### 4.5.5. Interface SVGNumberList
The [SVGNumberList](types.html#InterfaceSVGNumberList)
interface is a [list interface](types.html#TermListInterface) whose
elements are [SVGNumber](types.html#InterfaceSVGNumber)
objects. An
[SVGNumberList](types.html#InterfaceSVGNumberList) object
represents a list of numbers.

``` idl
[Exposed=Window]
interface SVGNumberList {

 readonly attribute unsigned long length;
 readonly attribute unsigned long numberOfItems;

 undefined clear();
 SVGNumber initialize(SVGNumber newItem);
 getter SVGNumber getItem(unsigned long index);
 SVGNumber insertItemBefore(SVGNumber newItem, unsigned long index);
 SVGNumber replaceItem(SVGNumber newItem, unsigned long index);
 SVGNumber removeItem(unsigned long index);
 SVGNumber appendItem(SVGNumber newItem);
 setter undefined (unsigned long index, SVGNumber newItem);
};
```

The behavior of all of the interface members of
[SVGNumberList](types.html#InterfaceSVGNumberList) are
defined in the [List interfaces](#ListInterfaces) section above.

### 4.5.6. Interface SVGLengthList
The [SVGLengthList](types.html#InterfaceSVGLengthList)
interface is a [list interface](types.html#TermListInterface) whose
elements are [SVGLength](types.html#InterfaceSVGLength)
objects. An
[SVGLengthList](types.html#InterfaceSVGLengthList) object
represents a list of lengths.

``` idl
[Exposed=Window]
interface SVGLengthList {

 readonly attribute unsigned long length;
 readonly attribute unsigned long numberOfItems;

 undefined clear();
 SVGLength initialize(SVGLength newItem);
 getter SVGLength getItem(unsigned long index);
 SVGLength insertItemBefore(SVGLength newItem, unsigned long index);
 SVGLength replaceItem(SVGLength newItem, unsigned long index);
 SVGLength removeItem(unsigned long index);
 SVGLength appendItem(SVGLength newItem);
 setter undefined (unsigned long index, SVGLength newItem);
};
```

The behavior of all of the interface members of
[SVGLengthList](types.html#InterfaceSVGLengthList) are
defined in the [List interfaces](#ListInterfaces) section above.

### 4.5.7. Interface SVGStringList
The [SVGStringList](types.html#InterfaceSVGStringList)
interface is a [list interface](types.html#TermListInterface) whose
elements are **DOMString** values. An
[SVGStringList](types.html#InterfaceSVGStringList) object
represents a list of strings.

``` idl
[Exposed=Window]
interface SVGStringList {

 readonly attribute unsigned long length;
 readonly attribute unsigned long numberOfItems;

 undefined clear();
 DOMString initialize(DOMString newItem);
 getter DOMString getItem(unsigned long index);
 DOMString insertItemBefore(DOMString newItem, unsigned long index);
 DOMString replaceItem(DOMString newItem, unsigned long index);
 DOMString removeItem(unsigned long index);
 DOMString appendItem(DOMString newItem);
 setter undefined (unsigned long index, DOMString newItem);
};
```

The behavior of all of the interface members of
[SVGStringList](types.html#InterfaceSVGStringList) are
defined in the [List interfaces](#ListInterfaces) section above.

## 4.6. DOM interfaces for reflecting animatable SVG attributes
The following interfaces are used to represent the reflected value of
animatable content attributes. They each consist of two component
objects, representing the same data: `baseVal` and `animVal`. The
`baseVal` (base value) object is modifiable, to update the corresponding
attribute value.

In SVG 1.1, the `animVal` attribute of the SVG DOM interfaces
represented the current animated value of the reflected attribute. In
this version of SVG, `animVal` no longer represents the current animated
value and is instead an alias of `baseVal`.

### 4.6.1. Interface SVGAnimatedBoolean
An
[SVGAnimatedBoolean](types.html#InterfaceSVGAnimatedBoolean)
object is used to [reflect](types.html#TermReflect) an animatable
attribute that takes a boolean value.

``` idl
[Exposed=Window]
interface SVGAnimatedBoolean {
 attribute boolean baseVal;
 readonly attribute boolean animVal;
};
```

The **baseVal** and **animVal** IDL attributes both represent the
current non-animated value of the reflected attribute. On getting
[baseVal](types.html#__svg__SVGAnimatedBoolean__baseVal) or
[animVal](types.html#__svg__SVGAnimatedBoolean__animVal), the following
steps are run:

1. Let `value` be the value of the reflected attribute, or
 the empty string if it is not present.
2. If `value` is not \"true\" or \"false\", then set
 `value` to the reflected attribute\'s [initial
 value](types.html#TermInitialValue).
3. Return true if `value` is \"true\", and false otherwise.

On setting [baseVal](types.html#__svg__SVGAnimatedBoolean__baseVal), the
reflected attribute is set to \"true\" if the value is true, and
\"false\" otherwise.

### 4.6.2. Interface SVGAnimatedEnumeration
An
[SVGAnimatedEnumeration](types.html#InterfaceSVGAnimatedEnumeration)
object is used to [reflect](types.html#TermReflect) an animatable
attribute that takes a keyword value (such as the
['[method](text.html#TextPathElementMethodAttribute)']
attribute on ['[textPath](text.html#TextPathElement)'])
or to reflect the type of value that an animatable attribute has (done
only by the
[orientType](painting.html#__svg__SVGMarkerElement__orientType) IDL
attribute for the
['[marker](painting.html#MarkerElement)'] element\'s
['[orient](painting.html#OrientAttribute)'] attribute).

``` idl
[Exposed=Window]
interface SVGAnimatedEnumeration {
 attribute unsigned short baseVal;
 readonly attribute unsigned short animVal;
};
```

For
[SVGAnimatedEnumeration](types.html#InterfaceSVGAnimatedEnumeration)
objects that [reflect](types.html#TermReflect) an animatable attribute
that takes only a keyword value, the **baseVal** and **animVal** IDL
attributes represents the current non-animated value of the reflected
attribute. For
[orientType](painting.html#__svg__SVGMarkerElement__orientType), they
represent the type of the current non-animated value of the reflected
['[orient](painting.html#OrientAttribute)'] attribute. On
getting [baseVal](#__svg__SVGAnimatedEnumeration__baseVal) or
[animVal](#__svg__SVGAnimatedEnumeration__animVal), the following steps
are run:

1. Let `value` be the value of the reflected attribute
 (using the attribute\'s [initial value](types.html#TermInitialValue)
 if it is not present or invalid).
2. Return the [numeric type value] for `value`, according to the
 reflecting IDL attribute\'s definition.

On setting [baseVal](types.html#__svg__SVGAnimatedEnumeration__baseVal),
the following steps are run:

1. Let `value` be the value being assigned to
 [baseVal](types.html#__svg__SVGAnimatedEnumeration__baseVal).
2. If `value` is 0 or is not the [numeric type
 value](types.html#TermNumericTypeValue) for any value of the
 reflected attribute, then throw a
 [TypeError](https://heycam.github.io/webidl/#exceptiondef-typeerror).
3. Otherwise, if the reflecting IDL attribute is
 [orientType](painting.html#__svg__SVGMarkerElement__orientType) and
 `value` is
 [SVG_MARKER_ORIENT_ANGLE](painting.html#__svg__SVGMarkerElement__SVG_MARKER_ORIENT_ANGLE),
 then set the reflected attribute to the string \"0\".
4. Otherwise, `value` is the [numeric type
 value](types.html#TermNumericTypeValue) for a specific, single
 keyword value for the reflected attribute. Set the reflected
 attribute to that value.

### 4.6.3. Interface SVGAnimatedInteger
An
[SVGAnimatedInteger](types.html#InterfaceSVGAnimatedInteger)
object is used to [reflect](types.html#TermReflect) an animatable
attribute that takes an integer value (such as
['[numOctaves](https://drafts.fxtf.org/filter-effects/#element-attrdef-feturbulence-numoctaves)']
on
['[feTurbulence](https://drafts.fxtf.org/filter-effects/#feTurbulenceElement)']).
It is also used to reflect one part of an animatable attribute that
takes an integer followed by an optional second integer (such as
['[order](https://drafts.fxtf.org/filter-effects/#element-attrdef-order)']
on
['[feConvolveMatrix](https://drafts.fxtf.org/filter-effects/#feConvolveMatrixElement)']).

This
[SVGAnimatedInteger](types.html#InterfaceSVGAnimatedInteger)
interface is not used in this specification, however the [Filter
Effects](https://www.w3.org/TR/filter-effects/) specification has a
number of uses of it.

``` idl
[Exposed=Window]
interface SVGAnimatedInteger {
 attribute long baseVal;
 readonly attribute long animVal;
};
```

For
[SVGAnimatedInteger](types.html#InterfaceSVGAnimatedInteger)
objects that [reflect](types.html#TermReflect) an animatable attribute
that takes a single integer value, the **baseVal** and **animVal** IDL
attributes represent the current non-animated value of the reflected
attribute. For those that reflect one integer of an attribute that takes
an integer followed by an optional second integer, they represent the
current non-animated value of one of the two integers. On getting
[baseVal](#__svg__SVGAnimatedInteger__baseVal) or
[animVal](#__svg__SVGAnimatedInteger__animVal), the following steps are
run:

1. Let `value` be the value of the reflected attribute
 (using the attribute\'s [initial value](types.html#TermInitialValue)
 if it is not present or invalid).
2. If the reflected attribute is defined to take an integer followed by
 an optional second integer, then:
 1. If this
 [SVGAnimatedInteger](types.html#InterfaceSVGAnimatedInteger)
 object reflects the first integer, then return the first value
 in `value`.

 2. Otherwise, this
 [SVGAnimatedInteger](types.html#InterfaceSVGAnimatedInteger)
 object reflects the second integer. Return the second value in
 `value` if it has been explicitly specified, and if
 not, return the implicit value as described in the definition of
 the attribute.

 For example, the definition of
 ['[order](https://drafts.fxtf.org/filter-effects/#element-attrdef-order)']
 says that the implicit second integer is the same as the
 explicit first integer.
3. Otherwise, the reflected attribute is defined to take a single
 integer value. Return `value`.

On setting [baseVal](#__svg__SVGAnimatedInteger__baseVal), the following
steps are run:

1. Let `value` be the value being assigned to
 [baseVal](types.html#__svg__SVGAnimatedInteger__baseVal).
2. Let `new` be a list of integers.
3. If the reflected attribute is defined to take an integer followed by
 an optional second integer, then:
 1. Let `current` be the value of the reflected attribute
 (using the attribute\'s [initial
 value](types.html#TermInitialValue) if it is not present or
 invalid).
 2. Let `first` be the first integer in
 `current`.
 3. Let `second` be the second integer in
 `current` if it has been explicitly specified, and if
 not, the implicit value as described in the definition of the
 attribute.
 4. If this
 [SVGAnimatedInteger](types.html#InterfaceSVGAnimatedInteger)
 object reflects the first integer, then set `first`
 to `value`. Otherwise, set `second` to
 `value`.
 5. Append `first` to `new`.
 6. Append `second` to `new`.
4. Otherwise, the reflected attribute is defined to take a single
 integer value. Append `value` to `new`.
5. Set the content attribute to a string consisting of each integer in
 `new` serialized to an implementation specific string
 that, if parsed as an
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) using CSS
 syntax, would return that integer, joined and separated by a single
 U+0020 SPACE character.

### 4.6.4. Interface SVGAnimatedNumber
An
[SVGAnimatedNumber](types.html#InterfaceSVGAnimatedNumber)
object is used to [reflect](types.html#TermReflect) an animatable
attribute that takes a number value (such as
['[pathLength](paths.html#PathLengthAttribute)'] on
['[path](paths.html#PathElement)']). It is also used to
reflect one part of an animatable attribute that takes an number
followed by an optional second number (such as
['[kernelUnitLength](https://drafts.fxtf.org/filter-effects/#element-attrdef-fediffuselighting-kernelunitlength)']
on
['[feDiffuseLighting](https://drafts.fxtf.org/filter-effects/#feDiffuseLightingElement)']).

``` idl
[Exposed=Window]
interface SVGAnimatedNumber {
 attribute float baseVal;
 readonly attribute float animVal;
};
```

For
[SVGAnimatedNumber](types.html#InterfaceSVGAnimatedNumber)
objects that [reflect](types.html#TermReflect) an animatable attribute
that takes a single number value, the **baseVal** and **animVal** IDL
attributes represent the current non-animated value of the reflected
attribute. For those that reflect one number of an attribute that takes
a number followed by an optional second number, they represent the
current non-animated value of one of the two numbers. On getting
[baseVal](#__svg__SVGAnimatedNumber__baseVal) or
[animVal](#__svg__SVGAnimatedNumber__animVal), the following steps are
run:

1. Let `value` be the value of the reflected attribute
 (using the attribute\'s [initial value](types.html#TermInitialValue)
 if it is not present or invalid).
2. If the reflected attribute is defined to take an number followed by
 an optional second number, then:
 1. If this
 [SVGAnimatedNumber](types.html#InterfaceSVGAnimatedNumber)
 object reflects the first number, then return the first value in
 `value`.

 2. Otherwise, this
 [SVGAnimatedNumber](types.html#InterfaceSVGAnimatedNumber)
 object reflects the second number. Return the second value in
 `value` if it has been explicitly specified, and if
 not, return the implicit value as described in the definition of
 the attribute.

 For example, the definition of
 ['[kernelUnitLength](https://drafts.fxtf.org/filter-effects/#element-attrdef-fediffuselighting-kernelunitlength)']
 says that the implicit second number is the same as the explicit
 first number.
3. Otherwise, the reflected attribute is defined to take a single
 number value. Return `value`.

On setting [baseVal](#__svg__SVGAnimatedNumber__baseVal), the following
steps are run:

1. Let `value` be the value being assigned to
 [baseVal](types.html#__svg__SVGAnimatedNumber__baseVal).
2. Let `new` be a list of numbers.
3. If the reflected attribute is defined to take an number followed by
 an optional second number, then:
 1. Let `current` be the value of the reflected attribute
 (using the attribute\'s [initial
 value](types.html#TermInitialValue) if it is not present or
 invalid).
 2. Let `first` be the first number in
 `current`.
 3. Let `second` be the second number in
 `current` if it has been explicitly specified, and if
 not, the implicit value as described in the definition of the
 attribute.
 4. If this
 [SVGAnimatedNumber](types.html#InterfaceSVGAnimatedNumber)
 object reflects the first number, then set `first` to
 `value`. Otherwise, set `second` to
 `value`.
 5. Append `first` to `new`.
 6. Append `second` to `new`.
4. Otherwise, the reflected attribute is defined to take a single
 number value. Append `value` to `new`.
5. Set the content attribute to a string consisting of each number in
 `new` serialized to an implementation specific string
 that, if parsed as an
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) using CSS
 syntax, would return the value closest to the number (given the
 implementation\'s supported [Precision](#Precision)real number
 precision), joined and separated by a single U+0020 SPACE character.

### 4.6.5. Interface SVGAnimatedLength
An
[SVGAnimatedLength](types.html#InterfaceSVGAnimatedLength)
object is used to [reflect](types.html#TermReflect) either (a) an
animatable attribute that takes a
[\<length\>](https://www.w3.org/TR/css3-values/#lengths),
[\<percentage\>](https://www.w3.org/TR/css3-values/#percentages) or
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) value, or (b) a
CSS property that takes one of these values and its corresponding
presentation attribute.

``` idl
[Exposed=Window]
interface SVGAnimatedLength {
 [SameObject] readonly attribute SVGLength baseVal;
 [SameObject] readonly attribute SVGLength animVal;
};
```

The **baseVal** and **animVal** IDL attributes represent the current
value of the reflected content attribute. On getting
[baseVal](#__svg__SVGAnimatedLength__baseVal) or
[animVal](#__svg__SVGAnimatedLength__animVal), an
[SVGLength](types.html#InterfaceSVGLength) object is
returned that:

- either [reflects the base value](#LengthMode) of the reflected
 attribute or [reflects the given presentation attribute](#LengthMode),
- is [associated with](#LengthAssociatedElement) the SVG element that
 the object with the reflecting IDL attribute of type
 [SVGAnimatedLength](types.html#InterfaceSVGAnimatedLength)
 was obtained from, and
- has a [directionality](#LengthAssociatedElement) as defined by the
 specific reflected attribute.

### 4.6.6. Interface SVGAnimatedAngle
An
[SVGAnimatedAngle](types.html#InterfaceSVGAnimatedAngle)
object is used to [reflect](types.html#TermReflect) the
[\<angle\>](https://www.w3.org/TR/css-values/#angles) value of the
animated ['[orient](painting.html#OrientAttribute)']
attribute on ['[marker](painting.html#MarkerElement)'],
through the
[orientAngle](painting.html#__svg__SVGMarkerElement__orientAngle) IDL
attribute.

``` idl
[Exposed=Window]
interface SVGAnimatedAngle {
 [SameObject] readonly attribute SVGAngle baseVal;
 [SameObject] readonly attribute SVGAngle animVal;
};
```

The **baseVal** and **animVal** IDL attributes represent the current
non-animated [\<angle\>](https://www.w3.org/TR/css-values/#angles) value
of the reflected ['[orient](painting.html#OrientAttribute)']
attribute. On getting [baseVal](#__svg__SVGAnimatedAngle__baseVal) or
[animVal](#__svg__SVGAnimatedAngle__animVal), an
[SVGAngle](types.html#InterfaceSVGAngle) object is
returned that:

- [reflects the base value](#AngleMode) of the reflected
 ['[orient](painting.html#OrientAttribute)'] attribute, and
- is [associated with](#AngleAssociatedElement) the SVG
 ['[marker](painting.html#MarkerElement)'] element that
 the object with the reflecting IDL attribute of type
 [SVGAnimatedAngle](types.html#InterfaceSVGAnimatedAngle)
 was obtained from.

### 4.6.7. Interface SVGAnimatedString
An
[SVGAnimatedString](types.html#InterfaceSVGAnimatedString)
object is used to [reflect](types.html#TermReflect) an animatable
attribute that takes a string value. It can optionally be defined to
additionally reflect a second, deprecated attribute.

``` idl
[Exposed=Window]
interface SVGAnimatedString {
 attribute (DOMString or TrustedScriptURL) baseVal;
 readonly attribute DOMString animVal;
};
```

The **baseVal** and **animVal** IDL attributes represent the current
non-animated value of the reflected attribute. On getting
[baseVal](types.html#__svg__SVGAnimatedString__baseVal) or
[animVal](types.html#__svg__SVGAnimatedString__animVal), the following
steps are run:

1. If the reflected attribute is not present, then:
 1. If the
 [SVGAnimatedString](types.html#InterfaceSVGAnimatedString)
 object is defined to additionally reflect a second, deprecated
 attribute, and that attribute is present, then return its value.
 2. Otherwise, if the reflected attribute has an [initial
 value](types.html#TermInitialValue), then return it.
 3. Otherwise, return the empty string.
2. Otherwise, the reflected attribute is present. Return its value.

For the [href](#__svg__SVGURIReference__href) member on the
[SVGURIReference](types.html#InterfaceSVGURIReference)
interface, this will result in the deprecated
['[xlink:href](linking.html#XLinkHrefAttribute)'] attribute
being returned if it is present and the ['href'] attribute
is not, and in the ['href'] attribute being returned in all
other cases.

On setting [baseVal](types.html#__svg__SVGAnimatedString__baseVal), the
following steps are run:

1. If the reflected attribute's element is an
 [SVGScriptElement](interact.html#InterfaceSVGScriptElement),
 let `value` be the result of executing the [Get Trusted
 Type compliant
 string](https://www.w3.org/TR/trusted-types/#get-trusted-type-compliant-string-algorithm)
 algorithm, with
 [TrustedScriptURL](https://www.w3.org/TR/trusted-types/#trustedscripturl),
 reflected attribute's Document\'s relevant global object,
 \'SVGScriptElement href\', and \'script\'.
2. Otherwise, let value be the specified value.
3. If the reflected attribute is not present, the
 [SVGAnimatedString](types.html#InterfaceSVGAnimatedString)
 object is defined to additionally reflect a second, deprecated
 attribute, and that deprecated attribute is present, then set that
 deprecated attribute to value.
4. Otherwise, set the reflected attribute to value.

SVG does not have a complete script processing model
[yet](https://github.com/w3c/svgwg/issues/196). [Trusted
Types](https://www.w3.org/TR/trusted-types/) assumes that the attribute
and text body modification protections behave similarly to ones for HTML
scripts.

For the [href](#__svg__SVGURIReference__href) member on the
[SVGURIReference](types.html#InterfaceSVGURIReference)
interface, this will result in the deprecated
['[xlink:href](linking.html#XLinkHrefAttribute)'] attribute
being set if it is present and the ['href'] attribute is
not, and in the ['href'] attribute being set in all other
cases.

### 4.6.8. Interface SVGAnimatedRect
An [SVGAnimatedRect](types.html#InterfaceSVGAnimatedRect)
object is used to [reflect](types.html#TermReflect) an animatable
attribute that takes a rectangle value as specified by an
`x`, `y`, `width` and
`height`.

In this specification the only attribute to be reflected as an
[SVGAnimatedRect](types.html#InterfaceSVGAnimatedRect) is
['[viewBox](coords.html#ViewBoxAttribute)'].

``` idl
[Exposed=Window]
interface SVGAnimatedRect {
 [SameObject] readonly attribute DOMRect baseVal;
 [SameObject] readonly attribute DOMRectReadOnly animVal;
};
```

The **baseVal** and **animVal** IDL attributes represent the current
non-animated rectangle value of the reflected attribute. On getting
[baseVal](#__svg__SVGAnimatedRect__baseVal) or
[animVal](#__svg__SVGAnimatedRect__animVal), a
[DOMRect](https://www.w3.org/TR/geometry-1/#DOMRect)
object is returned.

Upon creation of the [baseVal](#__svg__SVGAnimatedRect__baseVal) or
[animVal](#__svg__SVGAnimatedRect__animVal)
[DOMRect](https://www.w3.org/TR/geometry-1/#DOMRect)
objects, and afterwards whenever the reflected content attribute is
added, removed, or changed, the following steps are run:

1. Let `value` be the value of the reflected attribute
 (using the attribute\'s [initial value](types.html#TermInitialValue)
 if it is not present or invalid).
2. Let `x`, `y`, `width` and
 `height` be those corresponding components of
 `value`.
3. Set the
 [DOMRect](https://www.w3.org/TR/geometry-1/#DOMRect)
 object\'s [x
 coordinate](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#x-coordinate),
 [y
 coordinate](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#y-coordinate),
 [width](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#width)
 and
 [height](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#height)
 to `x`, `y`, `width` and
 `height`, respectively.

Whenever the [x
coordinate](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#x-coordinate),
[y
coordinate](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#y-coordinate),
[width](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#width) or
[height](https://www.w3.org/TR/2014/WD-geometry-1-20140522/#height)
property of the [baseVal](#__svg__SVGAnimatedRect__baseVal) or
[animVal](#__svg__SVGAnimatedRect__animVal)
[DOMRect](https://www.w3.org/TR/geometry-1/#DOMRect)
object changes, except as part of the previous algorithm that reflects
the value of the content attribute into the
[DOMRect](https://www.w3.org/TR/geometry-1/#DOMRect), the
reflected content attribute must be
[reserialized](types.html#TermReserialize).

### 4.6.9. Interface SVGAnimatedNumberList
An
[SVGAnimatedNumberList](types.html#InterfaceSVGAnimatedNumberList)
object is used to [reflect](types.html#TermReflect) an animatable
attribute that takes a list of
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) values.

``` idl
[Exposed=Window]
interface SVGAnimatedNumberList {
 [SameObject] readonly attribute SVGNumberList baseVal;
 [SameObject] readonly attribute SVGNumberList animVal;
};
```

The **baseVal** and **animVal** IDL attributes represent the current
non-animated value of the reflected attribute. On getting
[baseVal](#__svg__SVGAnimatedNumberList__baseVal) or
[animVal](#__svg__SVGAnimatedNumberList__animVal), an
[SVGNumberList](types.html#InterfaceSVGNumberList) object
is returned that reflects the base value of the reflected attribute.

### 4.6.10. Interface SVGAnimatedLengthList
An
[SVGAnimatedLengthList](types.html#InterfaceSVGAnimatedLengthList)
object is used to [reflect](types.html#TermReflect) an animatable
attribute that takes a list of
[\<length\>](https://www.w3.org/TR/css3-values/#lengths),
[\<percentage\>](https://www.w3.org/TR/css3-values/#percentages) or
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) values.

``` idl
[Exposed=Window]
interface SVGAnimatedLengthList {
 [SameObject] readonly attribute SVGLengthList baseVal;
 [SameObject] readonly attribute SVGLengthList animVal;
};
```

The **baseVal** or **animVal** IDL attributes represent the current
non-animated value of the reflected attribute. On getting
[baseVal](#__svg__SVGAnimatedLengthList__baseVal) or
[animVal](#__svg__SVGAnimatedLengthList__animVal), an
[SVGLengthList](types.html#InterfaceSVGLengthList) object
is returned that reflects the base value of the reflected attribute.

## 4.7. Other DOM interfaces
### 4.7.1. Interface SVGUnitTypes
The [SVGUnitTypes](types.html#InterfaceSVGUnitTypes)
interface defines a commonly used set of constants used for reflecting
['[gradientUnits](pservers.html#LinearGradientElementGradientUnitsAttribute)'],
['[patternContentUnits](pservers.html#PatternElementPatternContentUnitsAttribute)']
and other similar attributes.

``` idl
[Exposed=Window]
interface SVGUnitTypes {
 // Unit Types
 const unsigned short SVG_UNIT_TYPE_UNKNOWN = 0;
 const unsigned short SVG_UNIT_TYPE_USERSPACEONUSE = 1;
 const unsigned short SVG_UNIT_TYPE_OBJECTBOUNDINGBOX = 2;
};
```

The unit type constants defined on
[SVGUnitTypes](types.html#InterfaceSVGUnitTypes) have the
following meanings:

 Constant Meaning
 ------------------------------------- --------------------------------------------------------------------------
 **SVG_UNIT_TYPE_USERSPACEONUSE** Corresponds to the [\'userSpaceOnUse\'] attribute value.
 **SVG_UNIT_TYPE_OBJECTBOUNDINGBOX** Corresponds to the [\'objectBoundingBox\'] attribute value.
 **SVG_UNIT_TYPE_UNKNOWN** Some other type of value.

### 4.7.2. Mixin SVGTests
The [SVGTests](types.html#InterfaceSVGTests) interface is
used to reflect [conditional processing
attributes](struct.html#TermConditionalProcessingAttribute), and is
mixed in to other interfaces for elements that support these attributes.

``` idl
interface mixin SVGTests {
 [SameObject] readonly attribute SVGStringList requiredExtensions;
 [SameObject] readonly attribute SVGStringList systemLanguage;
};
```

The **requiredExtensions** IDL attribute
[reflects](types.html#TermReflect) the
['[requiredExtensions](struct.html#RequiredExtensionsAttribute)']
content attribute.

The **systemLanguage** IDL attribute [reflects](types.html#TermReflect)
the
['[systemLanguage](struct.html#SystemLanguageAttribute)']
content attribute.

### 4.7.3. Mixin SVGFitToViewBox
The
[SVGFitToViewBox](types.html#InterfaceSVGFitToViewBox)
interface is used to reflect the
['[viewBox](coords.html#ViewBoxAttribute)'] and
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attributes, and is mixed in to other interfaces for elements that
support these two attributes.

``` idl
interface mixin SVGFitToViewBox {
 [SameObject] readonly attribute SVGAnimatedRect viewBox;
 [SameObject] readonly attribute SVGAnimatedPreserveAspectRatio preserveAspectRatio;
};
```

The **viewBox** IDL attribute [reflects](types.html#TermReflect) the
['[viewBox](coords.html#ViewBoxAttribute)'] content
attribute.

The **preserveAspectRatio** IDL attribute
[reflects](types.html#TermReflect) the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
content attribute.

### 4.7.4. Mixin SVGURIReference
The
[SVGURIReference](types.html#InterfaceSVGURIReference)
interface is used to reflect the ['href'] attribute and the
deprecated ['[xlink:href](linking.html#XLinkHrefAttribute)']
attribute.

``` idl
interface mixin SVGURIReference {
 [SameObject] readonly attribute SVGAnimatedString href;
};
```

The **href** IDL attribute represents the value of the
['href'] attribute, and, on elements that are defined to
support it, the deprecated
['[xlink:href](linking.html#XLinkHrefAttribute)'] attribute.
On getting [href](#__svg__SVGURIReference__href), an
[SVGAnimatedString](types.html#InterfaceSVGAnimatedString)
object is returned that:

- reflects the ['href'] attribute, and
- if the element is defined to support the deprecated
 ['[xlink:href](linking.html#XLinkHrefAttribute)']
 attribute, additionally reflects that deprecated attribute.

The
[SVGAnimatedString](types.html#InterfaceSVGAnimatedString)
interface is defined to reflect, through its
[baseVal](#__svg__SVGAnimatedString__baseVal) and
[animVal](#__svg__SVGAnimatedString__animVal) members, the deprecated
['[xlink:href](linking.html#XLinkHrefAttribute)'] attribute,
if that attribute is present and the ['href'] is not, and to
reflect the ['href'] attribute in all other circumstances.
[Animation elements](https://svgwg.org/specs/animations/) treat
[attributeName=\'xlink:href\'] as being an alias for
targeting the ['href'] attribute.
