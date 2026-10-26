## 1. Introduction

In CSS Level 1
[\[CSS1\]](#biblio-css1 "Cascading Style Sheets, level 1"),
placing more content than would fit inside an element with a specified
size was generally an authoring error. Doing so caused the content to
extend outside the bounds of the element, which would likely cause that
content to overlap with other elements.

CSS Level 2
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
introduced the [overflow](#propdef-overflow) property, which allows authors to
have overflow be handled by scrolling, which means it is no longer an
authoring error. It also allows authors to specify that overflow is
handled by clipping, which makes sense when the author's intent is that
the content not be shown.

This specification defines the long-standing de-facto
[overflow-x](#propdef-overflow-x) and
[overflow-y](#propdef-overflow-y) properties, adds a
[clip](#valdef-overflow-clip) value, introduces an
[overflow-clip-margin](#propdef-overflow-clip-margin) property, and defines overflow
handling more fully. It also introduces control over smooth scrolling
via
[scroll-behavior](#propdef-scroll-behavior) and for reserving space for the
scrollbar via
[scrollbar-gutter](#propdef-scrollbar-gutter).

 This specification also reproduces the definition of
the
[text-overflow](#propdef-text-overflow) property previously defined in
[\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)"),
with no addition or modification, in order to present
[text-overflow] and
[block-ellipsis](https://drafts.csswg.org/css-overflow-4/#propdef-block-ellipsis) together.

### 1.1. Value Definitions

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS2/about.html#property-defs) from
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
using the [value definition
syntax](https://www.w3.org/TR/css-values-3/#value-defs) from
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Value types not defined in this specification are defined in CSS Values
& Units
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Combination with other CSS modules may expand the definitions of these
value types.

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept the [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

### 1.2. Module Interactions

This module replaces (supersedes) and extends features defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
section [11.1 Overflow and
clipping](https://www.w3.org/TR/CSS2/visufx.html#overflow-clipping) and
[\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)")
section [5.2. Overflow Ellipsis: the text-overflow
property](https://www.w3.org/TR/css-ui-3/#text-overflow).

When applied to \'display: table\' elements, the properties defined in
this module apply to the [table grid
box](https://drafts.csswg.org/css-tables-3/#table-grid-box) (not the [table wrapper
box](https://drafts.csswg.org/css-tables-3/#table-wrapper-box)).
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
[\[CSS-TABLES-3\]](#biblio-css-tables-3 "CSS Table Module Level 3")

## 2. Overflow Concepts and Terminology

CSS uses the term [overflow] to describe the contents of a box that extend outside one of
that box's edges (i.e., its *content edge*, *padding edge*, *border
edge*, or *margin edge*). The term might be interpreted as elements or
features that cause this overflow, the non-rectangular region occupied
by these features, or, more commonly, as the minimal rectangle that
bounds that region. A box's overflow is computed based on the layout and
styling of the box itself and of all descendants whose [containing block
chain](https://drafts.csswg.org/css-display-4/#containing-block-chain) includes the box.

In most cases, [overflow](#overflow)
can be computed for any box from the bounds and properties of that box
itself, plus the [overflow] of each of its children.
However, this is not always the case; for example, when
[transform-style:
preserve-3d](https://drafts.csswg.org/css-transforms-2/#propdef-transform-style)
[\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")
is used on some of the children, any of their descendants with
[transform-style: preserve-3d]
must also be examined.

There are two different types of overflow, which are used for different
purposes by the UA:

- [ink overflow](#ink-overflow)
- [scrollable
 overflow](#scrollable-overflow)

### 2.1. Ink Overflow

The [ink overflow] of a box is the part of that box and its contents that
creates a visual effect outside of the box's border box. Ink overflow is
the overflow of painting effects defined to not affect layout or
otherwise extend the [scrollable overflow
area](#scrollable-overflow-region), such as [box
shadows](https://www.w3.org/TR/css-backgrounds/#box-shadow), [border
images](), [text decoration](https://www.w3.org/TR/css-text-decor-3/),
overhanging glyphs (with negative side bearings, or with
ascenders/descenders extending outside the em box),
[outlines](https://www.w3.org/TR/css-ui-3/#outline-props), etc.

Since some effects in CSS (for example, the blurs in
[text-shadow](https://drafts.csswg.org/css-text-decor-4/#propdef-text-shadow)
[\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3")
and
[box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow)
[\[CSS-BACKGROUNDS-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3"),
which are theoretically infinite; or text rendering, where shaping and
rasterization can vary by platform) do not precisely define what visual
extent they cover, the extent of the [ink
overflow](#ink-overflow) is
undefined, and may vary across UAs.

The [ink overflow area]
is the non-rectangular area occupied by the [ink
overflow](#ink-overflow) of a
box and its contents, and the [ink overflow
rectangle] is the minimal rectangle whose axes are aligned to the box's
axes and that contains the [ink overflow
area](#ink-overflow-region). Note that the [ink overflow
rectangle](#ink-overflow-rectangle) is a rectangle in the box's coordinate system, but
might be non-rectangular in other coordinate systems due to transforms.
[\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

Any overflow of
[replaced](https://drafts.csswg.org/css-display-4/#replaced-element) content is always [ink
overflow](#ink-overflow) (as
opposed to [scrollable
overflow](#scrollable-overflow)).

### 2.2. Scrollable Overflow

The [scrollable overflow] of a box is the set of things extending
outside of that box's padding edge for which a scrolling mechanism needs
to be provided.

The [scrollable overflow area] is the
non-rectangular region occupied by the [scrollable
overflow](#scrollable-overflow), and the [scrollable overflow
rectangle] is the minimal rectangle whose axes are
aligned to the box's axes and that contains the [scrollable overflow
area](#scrollable-overflow-region). See [§ 3.3 Calculating the Scrollable Overflow
Area](#scrollable-overflow-calculation) for details.

### 2.3. Scrolling Overflow

A box's [overflow](#overflow) can be
visible or clipped. CSS also allows a box to be a [scroll
container]
that allows clipped parts of its [scrollable overflow
area](#scrollable-overflow-region) to be scrolled into view. The visual "viewport" of a
[scroll container](#scroll-container) (through which the [scrollable overflow
area] can be viewed) coincides
with its padding box, and is called the [scrollport]. A box's [nearest scroll
container] is the nearest [scroll container]
ancestor in the [containing block
chain](https://drafts.csswg.org/css-display-4/#containing-block-chain). (See [§ 3 Clipping and Scrolling
Overflow](#overflow-properties) for control over whether a box clips or
scrolls its overflow.)

Scrolling operations can be initiated by the user (for example, by
manipulating a scrollbar, swiping a touchscreen, or using keyboard
controls) or by script ([for example, by the
[`scrollIntoView()`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrollintoview) or
[`focus()`](https://html.spec.whatwg.org/multipage/interaction.html#dom-window-focus) APIs]). The initial position of the
[scrollable overflow
rectangle](#scrollable-overflow-rectangle) within the
[scrollport](#scrollport) before
any scrolling operations take effect is the [initial scroll
position]. The [initial scroll
position](#initial-scroll-position) is typically dependent on the [scroll
container](#scroll-container)'s [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode), and, unless otherwise specified, coincides with its
[scroll origin
position](#scroll-origin-position). For example,
[scroll-initial-target](https://drafts.csswg.org/css-scroll-snap-2/#propdef-scroll-initial-target) property can be used to change the
[initial scroll position].
[\[CSS-SCROLL-SNAP-2\]](#biblio-css-scroll-snap-2 "CSS Scroll Snap Module Level 2")

A [scroll position] is a particular alignment of the [scrollable overflow
rectangle](#scrollable-overflow-rectangle) within its
[scrollport](#scrollport). It is
associated with a [scroll offset] which is its distance from the [scroll
origin](#scroll-origin).

The [scroll origin] is the anchor coordinate of the [scrollable overflow
rectangle](#scrollable-overflow-rectangle), from which the [scrollable overflow
rectangle] expands. Unless
otherwise specified, it is the
[block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start)
[inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) corner of the [scrollable overflow
rectangle]. (For example, in a
[flex
container](https://drafts.csswg.org/css-flexbox-2/#flex-container) it is the
[main-start](https://drafts.csswg.org/css-flexbox-2/#main-start)
[cross-start](https://drafts.csswg.org/css-flexbox-2/#cross-start) corner.) A [scroll
container](#scroll-container) is said to be scrolled to its [scroll
origin](#scroll-origin) when
its [scroll origin] coincides with the
corresponding corner of its
[scrollport](#scrollport). This
[scroll position](#scroll-position), the [scroll origin position], usually, but not always,
coincides with the [initial scroll
position](#initial-scroll-position).

For example, [scroll
snapping](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap)
[\[CSS-SCROLL-SNAP-1\]](#biblio-css-scroll-snap-1 "CSS Scroll Snap Module Level 1")
can change the [initial scroll
position](#initial-scroll-position) away from the [scroll origin
position](#scroll-origin-position).

Check whether things like [baseline
alignment](https://drafts.csswg.org/css-align-3/#baseline-alignment) depend on the [initial scroll
position](#initial-scroll-position) or the [scroll origin
position](#scroll-origin-position).

This doesn't define a coordinate system
for [scroll offsets](#scroll-offset). Whether they increase downward/rightward,
block/inline-axis endward, or away from the [scroll
origin](#scroll-origin) is not
defined. Should each API define its coordinate model?

Unless otherwise adjusted (e.g. [by content
alignment](https://drafts.csswg.org/css-align-3/#overflow-scroll-position)
[\[css-align-3\]](#biblio-css-align-3 "CSS Box Alignment Module Level 3")),
the area beyond the [scroll
origin](#scroll-origin) in
either axis is considered the [unreachable scrollable overflow
region]: content rendered here is not accessible to
the reader, see [§ 2.2 Scrollable Overflow](#scrollable).

The root viewport, which scrolls the page
[canvas](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermCanvas), uses the [principal writing
mode](https://drafts.csswg.org/css-writing-modes-4/#principal-writing-mode) for determining its [scroll
origin](#scroll-origin) and
[initial scroll
position](#initial-scroll-position).

 In the case where a [scroll
container](#scroll-container) (or one of its ancestors) is the target of a graphical
transform, the UA might need to take this transform into account when
mapping user inputs to scrolling operations. For instance, on a touch
screen where the user scrolls by directly dragging the content, the
transform would be expected to be taken into account to match the
direction of scrolling to the gesture. On the other hand, other user
inputs (such as the Page Down key, or a 1D scroll wheel) might be more
naturally interpreted ignoring the transform. Choosing the appropriate
behavior for each scrolling mechanism is the responsibility of the UA.

## 3. Clipping and Scrolling Overflow

The properties in this chapter specify whether and where a box's
[overflow](#overflow) is clipped; if
so, whether it is a [scroll
container](#scroll-container); and if so, in which axis(es) it is allowed to scroll
(its [scrollable axis(es)]), thus which of the
following types of [scroll container] it is:

[single-axis scroll container]
: A [scroll container](#scroll-container) that is scrollable in only one axis.

[dual-axis scroll container]
: A [scroll container](#scroll-container) that is scrollable in both axes.

[block-axis scroll container]\
[inline-axis scroll container]\
[x-axis scroll container]\
[y-axis scroll container]
: A [scroll container](#scroll-container) that is scrollable in the specified axis,
 regardless of whether it can also scroll in the other axis.

### 3.1. Managing Overflow: the [overflow-x, [overflow-y](#propdef-overflow-y), and [overflow](#propdef-overflow) properties]
Name:

[overflow-x], [overflow-y],
[overflow-block],
[overflow-inline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

visible
[\|](https://drafts.csswg.org/css-values-4/#comb-one) hidden [\|] clip
[\|] scroll [\|] auto

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[visible](#valdef-overflow-visible)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container)
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
[flex
containers](https://drafts.csswg.org/css-flexbox-2/#flex-container)
[\[CSS-FLEXBOX-1\]](#biblio-css-flexbox-1 "CSS Flexible Box Layout Module Level 1"),
[grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container)
[\[CSS-GRID-1\]](#biblio-css-grid-1 "CSS Grid Layout Module Level 1"),
and [table grid
boxes](https://drafts.csswg.org/css-tables-3/#table-grid-box)
[\[CSS-TABLES-3\]](#biblio-css-tables-3 "CSS Table Module Level 3")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

usually specified value, but see text

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[overflow](#propdef-overflow)

The [overflow-x](#propdef-overflow-x) property specifies the handling of
[overflow](#overflow) in the
horizontal axis (i.e., overflow from the left and right sides of the
box), and the
[overflow-y](#propdef-overflow-y) property specifies the handling of
[overflow] in the vertical axis (i.e., overflow from
the top and bottom sides of the box).

The
[overflow-block](#propdef-overflow-block) and
[overflow-inline](#propdef-overflow-inline) properties likewise specify the
handling of [overflow](#overflow) in
the
[block](https://drafts.csswg.org/css-writing-modes-4/#block-axis) and
[inline](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) axis, respectively

These four properties form a [logical property
group](https://drafts.csswg.org/css-logical-1/#logical-property-group) together with the
[overflow](#propdef-overflow)
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property), and interact as defined in [CSS Logical Properties 1
§ 4 Flow-Relative Box Model
Properties](https://drafts.csswg.org/css-logical-1/#box).

Name:

[overflow]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'overflow-block\'\>](#propdef-overflow-block)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

visible

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

block containers
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
flex containers
[\[CSS3-FLEXBOX\]](#biblio-css3-flexbox "CSS Flexible Box Layout Module Level 1"),
and grid containers
[\[CSS3-GRID-LAYOUT\]](#biblio-css3-grid-layout "CSS Grid Layout Module Level 1")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

The [overflow](#propdef-overflow) property is a [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets the specified values of
[overflow-x](#propdef-overflow-x) and
[overflow-y](#propdef-overflow-y) in that order. If the second value is
omitted, it is copied from the first.

Values have the following meanings:

[visible]
: There is no special handling of overflow, that is, the box's content
 is rendered outside the box if positioned there.

[hidden]
: This value indicates that the box's content is clipped to its
 [overflow clip
 edge](#overflow-clip-edge) and that the UA must not provide any scrolling user
 interface to view the content outside the clipping region, nor allow
 scrolling by direct intervention of the user, such as dragging on a
 touch screen or using the scrolling wheel on a mouse. However, the
 content must still be scrollable programmatically, for example using
 the mechanisms defined in
 [\[CSSOM-VIEW\]](#biblio-cssom-view "CSSOM View Module").

[clip]

: This value indicates that the box's content is clipped to its
 [overflow clip
 edge](#overflow-clip-edge) and that no scrolling user interface should be
 provided by the UA to view the content outside the clipping region.
 In addition, unlike [overflow:
 hidden](#propdef-overflow) which still allows programmatic scrolling,
 [overflow: clip] forbids scrolling
 entirely, through any mechanism.

 Unlike
 [hidden](#valdef-overflow-hidden), this value **does not** cause the element
 to establish a new formatting context.

 Authors who also want the box to establish a
 formatting context can use [display:
 flow-root](https://drafts.csswg.org/css-display-3/#propdef-display) together with [overflow:
 clip](#propdef-overflow).

[scroll]

: This value indicates that the content is clipped to the [overflow
 clip edge](#overflow-clip-edge), but can be scrolled into view.

 Furthermore, if the user agent uses a scrolling mechanism that is
 visible on the screen (such as a scroll bar or a panner), that
 mechanism should be displayed whether or not any of its content is
 clipped. This avoids any problem with scrollbars appearing and
 disappearing in a dynamic environment. When the target medium is
 [print], overflowing content may be printed; it is not defined
 where it may be printed.

[auto]
: Like
 [scroll](#valdef-overflow-scroll) when the box has [scrollable
 overflow](#scrollable-overflow); like
 [hidden](#valdef-overflow-hidden) otherwise. Thus, if the user agent uses a
 scrolling mechanism that is visible on the screen (such as a scroll
 bar or a panner), that mechanism will only be displayed if there is
 overflow.

The [scroll](#valdef-overflow-scroll),
[auto](#valdef-overflow-auto), and
[hidden](#valdef-overflow-hidden) values are known as the [scrollable
values] of
[overflow](#propdef-overflow). They cause the box to be a [scroll
container](#scroll-container) and the affected axis to be a [scrollable
axis](#scrollable-axis). A
[block
box](https://drafts.csswg.org/css-display-4/#block-box) that becomes a [scroll
container] also establishes an [independent
formatting
context](https://drafts.csswg.org/css-display-4/#independent-formatting-context).

The
[visible](#valdef-overflow-visible) and
[clip](#valdef-overflow-clip) values are known as the [non-scrollable
values]. However, if the other
axis specifies a [scrollable
value](#scrollable-overflow-value), a specified value of
[visible]
[computes](https://drafts.csswg.org/css-cascade-5/#computed-value) to
[auto](#valdef-overflow-auto), enabling scrolling in its axis. If neither axis
computes to a [scrollable value],
the box is not a [scroll
container](#scroll-container). If only one axis computes to a [scrollable
value] (i.e. the other axis is
[clip]), the box is a [single-axis
scroll
container](#single-axis-scroll-container).

User agents must also support the [overlay] keyword as a [legacy value
alias](https://drafts.csswg.org/css-cascade-5/#css-legacy-value-alias) of
[auto](#valdef-overflow-auto).

 The
[overflow](#propdef-overflow) properties are expanded to apply to [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) in [Level 4](http://www.w3.org/TR/css-overflow-4/).

#### [3.1.1. ][ Interaction of [visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) and [overflow](#propdef-overflow)]
If the computed value of the
[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) property is
[hidden](https://drafts.csswg.org/css-display-4/#valdef-visibility-hidden) (or
[collapse](https://drafts.csswg.org/css-display-4/#valdef-visibility-collapse) when it has the same effect as
[hidden]), and
[overflow](#propdef-overflow) is either
[scroll](#valdef-overflow-scroll) or
[auto](#valdef-overflow-auto), then:

- The user agent must not make any scrolling mechanism visible. To the
 extent that the scrolling mechanism that would normally be visible in
 the absence of [visibility:
 hidden](https://drafts.csswg.org/css-display-4/#propdef-visibility) affects layout, it continues to do so, but
 is not painted.

- As would be the case with [overflow:
 hidden](#propdef-overflow), scrolling directly triggered by user
 interactions is disabled, but programmatic scrolling continues to take
 effect.

- The lack of interactive direct scrolling is enforced even if the user
 interacts (e.g. with a mouse scrolling wheel) with a descendent of the
 [visibility:
 hidden](https://drafts.csswg.org/css-display-4/#propdef-visibility) [scroll
 container](#scroll-container) that is itself set to [visibility:
 visible].

#### [3.1.2. ][ Interaction of [border-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-radius) and [overflow](#propdef-overflow)]
As mentioned in [CSS Backgrounds 3 § 4.3 Corner
Clipping](https://drafts.csswg.org/css-backgrounds-3/#corner-clipping),
the clipping region established by
[overflow](#propdef-overflow) can be rounded:

- When [overflow-x](#propdef-overflow-x) and
 [overflow-y](#propdef-overflow-y) compute to
 [hidden](#valdef-overflow-hidden),
 [scroll](#valdef-overflow-scroll), or
 [auto](#valdef-overflow-auto), the clipping region is rounded based on the border
 radius, adjusted to the [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge), as described in [CSS Backgrounds 3 § 4.2 Corner
 Shaping](https://drafts.csswg.org/css-backgrounds-3/#corner-shaping).

- When both
 [overflow-x](#propdef-overflow-x) and
 [overflow-y](#propdef-overflow-y) compute to
 [clip](#valdef-overflow-clip), the clipping region is rounded as described in
 [§ 3.2 Expanding Clipping Bounds: the overflow-clip-margin
 property](#overflow-clip-margin).

- However, when one of
 [overflow-x](#propdef-overflow-x) or
 [overflow-y](#propdef-overflow-y) computes to
 [clip](#valdef-overflow-clip) and the other computes to
 [visible](#valdef-overflow-visible), the clipping region is not rounded.

#### 3.1.3. Overflow in Print and Other Static Media

Since scrolling is not possible in static media (such as print) authors
should be careful to make content accessible in such media, for example
by using [\@media print, (update: none) { ... }] to adjust layout
such that all relevant content is simultaneously visible.

On [scroll containers](#scroll-container) in non-interactive media with an
[overflow](#propdef-overflow) value of
[auto](#valdef-overflow-auto) or
[scroll](#valdef-overflow-scroll) (but not
[hidden](#valdef-overflow-hidden)) UAs may display an indication of any scrollable
overflow, such as by displaying scrollbars or an ellipsis.

 Not all [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media) is non-interactive: for example, e-book readers
paginate content, but are interactive.

#### 3.1.4. Overflow Viewport Propagation

UAs must apply the
[overflow](#propdef-overflow) values set on the root element to the
[viewport](https://w3c.github.io/epub-specs/epub33/core/#dfn-viewport) when the root element's
[display](https://drafts.csswg.org/css-display-3/#propdef-display) value is not
[none](https://drafts.csswg.org/css-display-4/#valdef-display-none). However, when the root element is an
[\[HTML\]](#biblio-html "HTML Standard")
[`html`](https://html.spec.whatwg.org/multipage/semantics.html#the-html-element) element (including [XML syntax for
HTML](https://html.spec.whatwg.org/multipage/introduction.html#html-vs-xhtml))
whose [overflow] value is
[visible](#valdef-overflow-visible) (in both axes), and that element has as a child
a
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element whose [display] value is also not [none],
user agents must instead apply the
[overflow] values of the first
such child element to the viewport. The element from which the value is
propagated must then have a used [overflow] value of [visible].

 Using
[containment](https://drafts.csswg.org/css-contain-2/#containment) on the HTML
[`html`](https://html.spec.whatwg.org/multipage/semantics.html#the-html-element) or
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) elements disables this special handling of the HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element. See the [CSS Containment 1 § 2 Strong
Containment: the contain
property](https://drafts.csswg.org/css-contain-1/#contain-property) for
details.

 [overflow:
hidden](#propdef-overflow) on the root element might not clip everything
outside the [Initial Containing
Block](https://drafts.csswg.org/css-display-4/#initial-containing-block) if the ICB is smaller than the viewport, which can
happen on mobile.

If [visible](#valdef-overflow-visible) is applied to the viewport, it must be
interpreted as
[auto](#valdef-overflow-auto). If
[clip](#valdef-overflow-clip) is applied to the viewport, it must be interpreted as
[hidden](#valdef-overflow-hidden).

### 3.2. Expanding Clipping Bounds: the [overflow-clip-margin property]
Name:

[overflow-clip-margin]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[0px]

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

boxes to which [overflow](#propdef-overflow) applies

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the computed
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) and a
[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box) keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

per computed value if the
[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box) values match; otherwise discrete

This property defines the [overflow clip edge] of the box, i.e. precisely where
the box's content is allowed to paint before being clipped by effects
(such as [overflow: clip](#propdef-overflow), above) that are defined to clip to the box's
[overflow clip edge](#overflow-clip-edge).

Values are defined as follows:

[[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box)]

: Specifies the box edge to use as the [overflow clip
 edge](#overflow-clip-edge) origin, i.e. when the specified offset is zero.

 If omitted, defaults to [padding-box].

[[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)]

: The specified offset dictates how much the [overflow clip
 edge](#overflow-clip-edge) is expanded from the specified box edge. Negative
 values indicate insets, instead. Defaults to zero if omitted.

The [overflow clip
edge](#overflow-clip-edge)
is shaped in the corners exactly the same way as an [outer
box-shadow](https://drafts.csswg.org/css-backgrounds-3/#box-shadow-outer-box-shadow) with a spread radius of the same cumulative offset from
the box's [border
edge](https://drafts.csswg.org/css-box-4/#border-edge). See [CSS Backgrounds 3 § 4.2 Corner
Shaping](https://drafts.csswg.org/css-backgrounds-3/#corner-shaping) and
[CSS Backgrounds 3 § 6.1.1 Shadow Shape, Spread, and
Knockout](https://drafts.csswg.org/css-backgrounds-3/#shadow-shape),
noting in particular the formula for outsets beyond the [border
edge].

If the box is a [scroll
container](#scroll-container):

- the [overflow clip
 edge](#overflow-clip-edge) is clamped to stay within the element's [padding
 box](https://drafts.csswg.org/css-box-4/#padding-box). (This does not affect the
 [computed](https://drafts.csswg.org/css-cascade-5/#computed-value) or [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) of this property.)

- the [border-box] value ignores any specified offset (and, due to
 the previous bullet point, effectively acts as [padding-box])

 This property was previously defined to only affect
[overflow: clip](#propdef-overflow). It now also affects [scroll
containers](#scroll-container), but only to shrink the clipping edge.

### 3.3. Calculating the Scrollable Overflow Area

The [scrollable overflow
area](#scrollable-overflow-region) of a box is the union of:

- Its own [padding
 box](https://drafts.csswg.org/css-box-4/#padding-box).

- All [line
 boxes](https://drafts.csswg.org/css-inline-3/#line-box) it directly contains.

- The border boxes of all boxes for which it is the containing block and
 whose border boxes are positioned not wholly within its [unreachable
 scrollable overflow
 region](#unreachable-scrollable-overflow-region) (if any), accounting for transforms by projecting
 each box onto the plane of the element that establishes its [3D
 rendering
 context](https://drafts.csswg.org/css-transforms-2/#3d-rendering-context).
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 (#issue-df7ef6c3) Is this description of handling
 transforms sufficiently accurate?

 Border boxes with zero area do not affect the [scrollable overflow
 area](#scrollable-overflow-region).

- The margin areas of [grid
 item](https://drafts.csswg.org/css-grid-2/#grid-item) and [flex
 item](https://drafts.csswg.org/css-flexbox-2/#flex-item) boxes for which the box establishes a containing
 block.

 The UA may *additionally* include the margin areas of other boxes for
 which the box establishes a containing block; however, the conditions
 under which such margin areas are included is undefined in this level.
 [(#issue-b9c7269c)This needs further testing and
 investigation; is therefore deferred in this draft.]

- The [scrollable overflow
 rectangles](#scrollable-overflow-rectangle) of all of the above boxes (including zero-area
 boxes), clipped to their [overflow clip
 edge](#overflow-clip-edge) if
 [overflow](#propdef-overflow) is not
 [visible](#valdef-overflow-visible) or
 [contain](https://drafts.csswg.org/css-contain-2/#propdef-contain) applies
 [paint](https://drafts.csswg.org/css-contain-2/#valdef-contain-paint), and accounting for transforms as described
 above.

 The
 [clip](https://drafts.csswg.org/css-masking-1/#propdef-clip),
 [clip-path](https://drafts.csswg.org/css-masking-1/#propdef-clip-path), and [mask-\*] properties
 [\[CSS-MASKING-1\]](#biblio-css-masking-1 "CSS Masking Module Level 1")
 do not affect the [scrollable overflow
 area](#scrollable-overflow-region). Only effects that clip to the [overflow clip
 edge](#overflow-clip-edge) are taken into account.

 The [scrollable overflow
 rectangle](#scrollable-overflow-rectangle) is always a rectangle in its box's own coordinate
 system, but might be non-rectangular in ancestor coordinate systems
 due to transforms
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1").
 This means scrollbars can sometimes appear when not actually
 necessary.

- Additional padding added to the [scrollable overflow
 rectangle](#scrollable-overflow-rectangle) as necessary to enable scroll positions that satisfy
 the requirements of both [place-content:
 start](https://drafts.csswg.org/css-align-3/#propdef-place-content) and [place-content:
 end] alignment.

 This padding represents, within the [scrollable
 overflow
 rectangle](#scrollable-overflow-rectangle), the box's own padding so that when its content is
 scrolled to its end, there is padding between the edge of its
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) (or floated) content and the border edge of the box.
 It typically ends up being exactly the same size as the box's own
 padding, except in a few cases---​such as when an
 [out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow) positioned element, or the visible overflow of a
 descendent, has already increased the size of the [scrollable overflow
 rectangle] outside the
 conceptual "content edge" of the [scroll
 container](#scroll-container)'s content.

 ![Issue: Replace this image with a proper
 SVG.](images/scroll-align-padding.jpg){height="404" width="917"}

Additionally, due to Web-compatibility constraints (caused by authors
exploiting legacy bugs to surreptitiously hide content from visual
readers but not search engines and/or speech output), UAs must clip any
content in the [unreachable scrollable overflow
region](#unreachable-scrollable-overflow-region).

 The [content-distribution
properties](https://drafts.csswg.org/css-align-3/#content-distribution-properties) can [alter the unreachable scrollable overflow
region](https://drafts.csswg.org/css-align-3/#overflow-scroll-position)
to ensure that a [scroll
container](#scroll-container)'s [alignment
subject](https://drafts.csswg.org/css-align-3/#alignment-subject) is reachable after alignment.
[\[css-align-3\]](#biblio-css-align-3 "CSS Box Alignment Module Level 3")

## 4. Scrolling Behaviors and Animations

CSS provides several controls over how scrolling behaves when triggered.

- [CSS Scroll Snap](https://www.w3.org/TR/css-scroll-snap/) allows
 defining \"snap positions\", which are scroll positions to which the
 [scroll container](#scroll-container) is biased to land.

- [CSS Overscroll Behavior](https://www.w3.org/TR/css-overscroll/)
 allows controlling what happens when scrolling past the end of the
 scrollable area.

- [scroll-behavior](#propdef-scroll-behavior), defined below, controls whether
 programmatic scrolling animates smoothly or not.

 For animating other things in conjunction with
scrolling, see
[\[SCROLL-ANIMATIONS-1\]](#biblio-scroll-animations-1 "Scroll-driven Animations").

### 4.1. Smooth Scrolling: the [scroll-behavior Property]
Name:

[scroll-behavior]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) smooth

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll containers](#scroll-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

The
[scroll-behavior](#propdef-scroll-behavior) property specifies the scrolling
behavior for a [scroll
container](#scroll-container), when scrolling happens due to navigation, scrolling
APIs
[\[CSSOM-VIEW\]](#biblio-cssom-view "CSSOM View Module"),
or scroll snapping operations not initiated by the user
[\[CSS-SCROLL-SNAP-1\]](#biblio-css-scroll-snap-1 "CSS Scroll Snap Module Level 1").
Any other scrolls, e.g. those that are performed by the user, are not
affected by this property. When this property is specified on the root
element, it applies to the
[viewport](https://w3c.github.io/epub-specs/epub33/core/#dfn-viewport) instead.

 The
[scroll-behavior](#propdef-scroll-behavior) property of the HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element is *not* propagated to the viewport.

[auto]
: The [scroll
 container](#scroll-container) is scrolled in an
 [instant](https://drafts.csswg.org/cssom-view-1/#concept-instant-scroll) fashion.

[smooth]
: The [scroll
 container](#scroll-container) is scrolled in a
 [smooth](https://drafts.csswg.org/cssom-view-1/#concept-smooth-scroll) fashion using a user-agent-defined timing function
 over a user-agent-defined period of time. User agents should follow
 platform conventions, if any.

User agents may ignore this property.

## 5. Scrollbars and Layout

### 5.1. Scrollbar Contributions to Sizing

The space reserved for the scrollbar is located between the [padding
area](https://drafts.csswg.org/css-box-4/#padding-area) and the [border
area](https://drafts.csswg.org/css-box-4/#border-area) of the [scroll
container](#scroll-container) box. However, for the purpose of the [background
positioning
area](https://drafts.csswg.org/css-backgrounds-4/#background-positioning-area) and [background painting
area](https://drafts.csswg.org/css-backgrounds-4/#background-painting-area), this reserved space is treated as part of the [padding
area].

In the following document fragment,
both an absolutely-positioned element and a background image are
positioned to the top right of the box.

``` highlight
<style>
 article {
 background: top right no-repeat url(circle.png);
 position: relative;
 overflow: auto; }
 aside { position: absolute; top: 0; right: 0; }
</style>
<article>
 <aside>×</aside>
</article>
```

If no scrollbars are present on `<article>`, they will both coincide in
the top right padding edge corner. However, if scrollbars are present
then `<aside>` will be completely visible, on the right padding-box edge
adjacent to the scrollbars; whereas the background image will be tucked
underneath the scrollbars, in the top right corner of the
scrollbar-extended [background positioning
area](https://drafts.csswg.org/css-backgrounds-4/#background-positioning-area).

When the box is intrinsically sized, this reserved space is added to the
size of its contents. It is otherwise subtracted from space allotted to
the [content
area](https://drafts.csswg.org/css-box-4/#content-area). To the extent that the presence of scrollbars can
affect sizing, UAs must start with the assumption that no scrollbars are
needed, and recalculate sizes if it turns out they are.

In the following document fragment,
the outer `<article>` has [height:
auto](https://drafts.csswg.org/css-sizing-3/#propdef-height), but [max-height:
5em](https://drafts.csswg.org/css-sizing-3/#propdef-max-height). The inner `<section>` has large margins and
would normally just fit:

``` highlight
...
 article { overflow: auto; max-height: 5em; width: max-content; }
 section { margin: 2em; line-height: 1 }
...
<article>
 <section>
 This section has big margins.
 </section>
</article>
```

If we assumed that `<article>` needed scrollbars, then the height of
`<section>`, including the single line of text and twice 2em of margins,
adds up to 5em plus a scrollbar. Since that is greater than 5em, the
maximum allowed height, it seems we made the right assumption and d1
indeed needs scrollbars.

However, we should have started by assuming that no scrollbars are
needed. In that case the content height of `<article>` is exactly the
maximum height of 5em, proving that the assumption was correct and
`<article>` indeed should not have scrollbars.

### 5.2. Reserving space for the scrollbar: the [scrollbar-gutter property]
The space between the inner border edge and the outer padding edge which
user agents may reserve to display the scrollbar is called the
[scrollbar gutter].

The
[scrollbar-gutter](#propdef-scrollbar-gutter) property gives control to the
author over the presence of [scrollbar
gutters](#scrollbar-gutter)
separately from the ability to control the presence of scrollbars
provided by the
[overflow](#propdef-overflow) property.

Name:

[scrollbar-gutter]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) stable
[&&](https://drafts.csswg.org/css-values-4/#comb-all)
both-edges[?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll containers](#scroll-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword(s)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property affects the presence of [scrollbar
gutters](#scrollbar-gutter)
placed at the [inline
start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) edge or [inline
end](https://drafts.csswg.org/css-writing-modes-4/#inline-end) edge of the box.

The presence of a [scrollbar
gutter](#scrollbar-gutter)
at the [block
start](https://drafts.csswg.org/css-writing-modes-4/#block-start) edge and [block
end](https://drafts.csswg.org/css-writing-modes-4/#block-end) edge of the box cannot be controlled in this level, and
is determined the same way as the presence of [scrollbar
gutters] placed at the [inline
start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) edge or [inline
end](https://drafts.csswg.org/css-writing-modes-4/#inline-end) edge of the box when
[scrollbar-gutter](#propdef-scrollbar-gutter) is
[auto](#valdef-scrollbar-gutter-auto).

Scrollbars which by default are placed over the content box and do not
cause [scrollbar gutters](#scrollbar-gutter) to be created are called [overlay
scrollbars]. Such scrollbars are usually partially transparent, revealing
the content behind them if any. Their appearance and size may vary based
on whether and how the user is interacting with them.

Scrollbars which are always placed in a [scrollbar
gutter](#scrollbar-gutter),
consuming space when present, are called [classic
scrollbars]. Such scrollbars are usually opaque.

Whether [classic
scrollbars](#classic-scrollbars) or [overlay
scrollbars](#overlay-scrollbars) are used, the appearance and size of the scrollbar, and
whether scrollbars appear on the start or end edge of the box, is UA
defined.

 Which side a scrollbar appears on may depend on
operating system conventions,
[bidirectionality](https://drafts.csswg.org/css-writing-modes-4/#bidirectionality), or other ergonomic considerations.

In the case of [classic
scrollbars](#classic-scrollbars), the width of the [scrollbar
gutter](#scrollbar-gutter),
if present (see below), is the same as the width of the scrollbar. In
the case of [overlay
scrollbars](#overlay-scrollbars), no [scrollbar gutter] is
present.

 There are known use cases that could be addressed by
enabling [scrollbar
gutters](#scrollbar-gutter)
for [overlay
scrollbars](#overlay-scrollbars), but no satisfactory design has been agreed to so far.
This could be addressed by future extensions of this property. See [CSS
Overflow 4 § A Possible extensions for
scrollbar-gutter](https://drafts.csswg.org/css-overflow-4/#sbg-ext).

The values of this property have the following meaning:

[auto]
: [Classic
 scrollbars](#classic-scrollbars) consume space by creating a [scrollbar
 gutter](#scrollbar-gutter) when
 [overflow](#propdef-overflow) is
 [scroll](#valdef-overflow-scroll), or when
 [overflow] is
 [auto](#valdef-overflow-auto) and the box is overflowing. [Overlay
 scrollbars](#overlay-scrollbars) do not consume space.

[stable]

: The [scrollbar
 gutter](#scrollbar-gutter) is present for [classic
 scrollbars](#classic-scrollbars) when
 [overflow](#propdef-overflow) is
 [hidden](#valdef-overflow-hidden),
 [scroll](#valdef-overflow-scroll), or
 [auto](#valdef-overflow-auto), regardless of whether the box is actually
 overflowing. [Overlay
 scrollbars](#overlay-scrollbars) do not consume space.

 This does not change whether the scrollbar itself
 is visible, only the presence of a gutter is affected.

[both-edges]
: If a [scrollbar
 gutter](#scrollbar-gutter) would be present on one of the inline start edge or
 the inline end edge of the box, another [scrollbar
 gutter] must be present on the opposite
 edge as well.

When the [scrollbar
gutter](#scrollbar-gutter)
is present but the scrollbar is not, or the scrollbar is transparent or
otherwise does not fully obscure the [scrollbar
gutter], the background of the [scrollbar
gutter] must be painted as an extension of
the padding.

As for the [overflow](#propdef-overflow) property, when
[scrollbar-gutter](#propdef-scrollbar-gutter) is set on the root element, the
user agent must apply it to the viewport instead, and the used value on
the root element itself is [scrollbar-gutter:
auto]. However, unlike the
[overflow] property, the user
agent must not propagate
[scrollbar-gutter] from
the HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element.

Note: The following table summarizes the interaction of
[overflow](#propdef-overflow) and
[scrollbar-gutter](#propdef-scrollbar-gutter) showing in which case space is
reserved for a [classic
scrollbar](#classic-scrollbars)'s [scrollbar
gutter](#scrollbar-gutter).

Should a [classic
scrollbar](#classic-scrollbars)'s [scrollbar
gutter](#scrollbar-gutter)
be present?

[overflow](#propdef-overflow)

[scrollbar-gutter](#propdef-scrollbar-gutter)

Overflowing

Not overflowing

[scroll](#valdef-overflow-scroll)

[auto](#valdef-scrollbar-gutter-auto)

yes

yes

[stable](#valdef-scrollbar-gutter-stable)

yes

yes

[auto](#valdef-overflow-auto)

[auto](#valdef-scrollbar-gutter-auto)

yes

[stable](#valdef-scrollbar-gutter-stable)

yes

yes

[hidden](#valdef-overflow-hidden)

[auto](#valdef-scrollbar-gutter-auto)

[stable](#valdef-scrollbar-gutter-stable)

yes

yes

[visible](#valdef-overflow-visible),
[clip](#valdef-overflow-clip)

[auto](#valdef-scrollbar-gutter-auto)

[stable](#valdef-scrollbar-gutter-stable)

## 6. Automatic Ellipses

### 6.1. Overflow Ellipsis: the [text-overflow property]
Name:

[text-overflow]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

clip
[\|](https://drafts.csswg.org/css-values-4/#comb-one) ellipsis

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

clip

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

block containers

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property specifies rendering when inline content overflows its
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) line box edge in the inline progression direction of
its block container element (\"the block\") that has
[overflow](#propdef-overflow) other than
[visible](#valdef-overflow-visible).

Text can overflow for example when it is prevented from wrapping (e.g.
due to `white-space: nowrap` or a single word is
too long to fit). Values have the following meanings:

[clip]
: Clip inline content that overflows its block container element.
 Characters may be only partially rendered.

[ellipsis]
: Render an ellipsis character (U+2026) to represent clipped inline
 content. Implementations may substitute a more language, script, or
 writing-mode appropriate ellipsis character, or three dots \"\...\"
 if the ellipsis character is unavailable.

The term \"character\" is used in this property definition for better
readability and means \"grapheme cluster\"
[\[UAX29\]](#biblio-uax29 "Unicode Text Segmentation")
for implementation purposes.

For the ellipsis value implementations must hide characters and [atomic
inline-level
elements](https://www.w3.org/TR/CSS2/visuren.html#inline-boxes) at the
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) edge of the line as necessary to fit the ellipsis, and
place the ellipsis immediately adjacent to the [end]
edge of the remaining inline content. The first character or [atomic
inline-level
element](https://www.w3.org/TR/CSS2/visuren.html#inline-boxes) on a line
must be clipped rather than ellipsed.

#### [Bidi ellipsis examples]
These examples demonstrate which characters get hidden to make room for
the ellipsis in a bidi situation: those visually at the end edge of the
line.

Sample CSS:

``` highlight
div {
 font-family: monospace;
 white-space: pre;
 overflow: hidden;
 width: 9ch;
 text-overflow: ellipsis;
}
```

Sample HTML fragments, renderings, and your browser:

HTML

Reference rendering

Your Browser

`<div>שלום 123456</div>`

::: {style="font-family:monospace"}
123456 ם...

::: {style="font-family: monospace; white-space: pre; overflow: hidden; width: 9ch; text-overflow: ellipsis"}
שלום 123456

`<div dir=rtl>שלום 123456</div>`

::: {style="font-family:monospace"}
...456 שלום

::: {dir="rtl" style="font-family: monospace; white-space: pre; overflow: hidden; width: 9ch; text-overflow: ellipsis"}
שלום 123456

#### [ ellipsing details]
- Ellipsing only affects rendering and must not affect layout nor
 dispatching of pointer events: The UA should dispatch any pointer
 event on the ellipsis to the elided element, as if
 [text-overflow](#propdef-text-overflow) had been [none].
- The ellipsis is styled and baseline-aligned according to the block.
- Ellipsing occurs after relative positioning and other graphical
 transformations.
- If there is insufficient space for the ellipsis, then clip the
 rendering of the ellipsis itself (on the same side that neutral
 characters on the line would have otherwise been clipped with the
 [text-overflow:clip] value).

#### [ user interaction with ellipsis]
- When the user is interacting with content (e.g. editing, selecting,
 scrolling), the user agent may treat [text-overflow:
 ellipsis](#propdef-text-overflow) as [text-overflow:
 clip].
- Selecting the ellipsis should select the ellipsed text. If all of the
 ellipsed text is selected, UAs should show selection of the ellipsis.
 Behavior of partially-selected ellipsed text is up to the UA.

Example(s):

#### [text-overflow examples]
These examples demonstrate setting the text-overflow of a block
container element that has text which overflows its dimensions:

sample CSS for a div:

``` highlight
div {
 font-family:Helvetica,sans-serif; line-height:1.1;
 width:3.1em; padding:.2em; border:solid .1em black; margin:1em 0;
}
```

sample HTML fragments, renderings, and your browser:

HTML

sample rendering

your browser

``` highlight
<div>
CSS IS AWESOME, YES
</div>
```

First, a box with text drawing outside of it.

::: {style="width:3.1em; border:solid .1em black; margin:1em 0; padding:.2em; font-family:Helvetica,sans-serif; line-height:1.1;"}
CSS IS AWESOME, YES

``` highlight
<div style="text-overflow:clip; overflow:hidden">
CSS IS AWESOME, YES
</div>
```

Second, a similar box with the text clipped outside the box.

::: {style="width:3.1em; border:solid .1em black; margin:1em 0; padding:.2em; font-family:Helvetica,sans-serif; line-height:1.1; overflow:hidden;text-overflow:clip;"}
CSS IS AWESOME, YES

``` highlight
<div style="text-overflow:ellipsis; overflow:hidden">
CSS IS AWESOME, YES
</div>
```

Third, a similar box with an ellipsis representing the clipped text.

::: {style="width:3.1em; border:solid .1em black; margin:1em 0; padding:.2em; font-family:Helvetica,sans-serif; line-height:1.1; overflow:hidden;text-overflow:ellipsis;"}
CSS IS AWESOME, YES

``` highlight
<div style="text-overflow:ellipsis; overflow:hidden">
NESTED
 <p>PARAGRAPH</p>
WON'T ELLIPSE.
</div>
```

Fourth, a box with a nested paragraph demonstrating anonymous block
boxes equivalency and non-inheritance into a nested element.

::: {style="width:3.1em; border:solid .1em black; margin:1em 0; padding:.2em; font-family:Helvetica,sans-serif; line-height:1.1; overflow:hidden;text-overflow:ellipsis;"}
NESTED

PARAGRAPH

WON'T ELLIPSE.

 the side of the line that the ellipsis is placed
depends on the
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) of the block. E.g. an overflow
hidden right-to-left (`direction: rtl`) block
clips inline content on the
[left](https://drafts.csswg.org/css-writing-modes-3/#physical-left) side, thus would place a text-overflow ellipsis on the
[left] to represent that clipped content.

#### [ ellipsis interaction with scrolling interfaces]
This section applies to elements with text-overflow other than
[text-overflow:clip] (non-clip text-overflow) and overflow:scroll.

When an element with non-clip text-overflow has overflow of scroll in
the inline progression dimension of the text, and the browser provides a
mechanism for scrolling (e.g. a scrollbar on the element, or a touch
interface to swipe-scroll, etc.), there are additional implementation
details that provide a better user experience:

When an element is scrolled (e.g. by the user, DOM manipulation), more
of the element's content is shown. The value of text-overflow should not
affect whether more of the element's content is shown or not. If a
non-clip text-overflow is set, then as more content is scrolled into
view, implementations should show whatever additional content fits, only
truncating content which would otherwise be clipped (or is necessary to
make room for the ellipsis/string), until the element is scrolled far
enough to display the edge of the content at which point that content
should be displayed rather than an ellipsis/string.

This example uses text-overflow on an element with overflow scroll to
demonstrate the above described behavior.

sample CSS:

``` highlight
div.crawlbar {
 text-overflow: ellipsis;
 height: 2em;
 overflow: scroll;
 white-space: nowrap;
 width: 15em;
 border:1em solid black;
}
```

sample HTML fragment:

``` highlight
<div class="crawlbar">
CSS is awesome, especially when you can scroll
to see extra text instead of just
having it overlap other text by default.
</div>
```

demonstration of sample CSS and HTML:

::: {style="text-overflow: ellipsis; height: 2em; overflow: scroll; white-space: nowrap; width: 15em; border:1em solid black;"}
CSS is awesome, especially when you can scroll to see extra text instead
of just having it overlap other text by default.

While the content is being scrolled, implementations may adjust their
rendering of ellipses (e.g. align to the box edge rather than line
edge).

## [Appendix A. Privacy Considerations]
This specification introduces no new privacy concerns.

## [Appendix B. Security Considerations]
This specification introduces no new security concerns.

## [Appendix C. Changes]
This appendix is *informative*.

Significant changes since the [7 October 2025 Working
Draft](https://www.w3.org/TR/2025/WD-css-overflow-3-20251007/):

- Allow combining [overflow:
 clip](#propdef-overflow) behavior in one axis with scrolling in the
 other, to allow single-axis trapping for e.g. [sticky
 positioning](https://drafts.csswg.org/css-position-3/#sticky-position). ([Issue
 12289](https://github.com/w3c/csswg-drafts/issues/12289))

- Clarify which clipping affects limit contributions to the scrollable
 overflow area of the nearest [scroll
 container](#scroll-container). ([Issue
 8607](https://github.com/w3c/csswg-drafts/issues/8607))

- Clarify application of
 [overflow](#propdef-overflow) to tables. ([Isue
 10881](https://github.com/w3c/csswg-drafts/issues/10881))

Significant changes since the [29 March 2023 Working
Draft](https://www.w3.org/TR/2023/WD-css-overflow-3-20230329/):

- Define that [overflow:
 hidden](#propdef-overflow) is treated as [overflow:
 clip] on [replaced
 elements](https://drafts.csswg.org/css-display-4/#replaced-element). ([Issue
 7714](https://github.com/w3c/csswg-drafts/issues/7714))

- Redefine the interaction of overflowing [content
 distribution](https://drafts.csswg.org/css-align-3/#content-distribute) and [scroll
 containers](#scroll-container) to not impact layout, but to only affect the extent
 of the [scrollable overflow
 area](#scrollable-overflow-region). ([Issue
 4957](https://github.com/w3c/csswg-drafts/issues/4957))

- Defined some more terminology to help other specs connect to concepts
 in this one.

See also [Previous
Changes](https://www.w3.org/TR/2023/WD-css-overflow-3-20230329/#changes).

## [ Acknowledgments]
Thanks especially to the feedback from Rossen Atanassov, Tab Atkins,
Bert Bos, Tantek Çelik, John Daggett, Daniel Glazman, Vincent Hardy, Ian
Kilpatrick, Håkon Wium Lie, Peter Linss, Robert O'Callahan, Florian
Rivoal, Alan Stearns, Steve Zilles, and all the rest of the
[www-style](http://lists.w3.org/Archives/Public/www-style/) community.
