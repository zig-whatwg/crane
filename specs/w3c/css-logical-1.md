## 1. Introduction

 See
[\[css-writing-modes-4\]](#biblio-css-writing-modes-4 "CSS Writing Modes Level 4")
for a proper introduction to writing modes; this module assumes
familiarity with its terminology.

Because different writing systems are written in different directions, a
variety of [writing
modes](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) exist: left to right, top to bottom; right to left, top
to bottom; bottom to top, right to left; etc. logical concepts like the
"start" of a page or line map differently to physical concepts like the
"top" of a line or "left edge" of a paragraph. Some aspects of a layout
are actually relative to the writing directions, and thus will vary when
the page is translated to a different system; others are inherently
relative to the page's physical orientation.

For example, lists, headings, and
paragraphs are typically left-aligned in English; but actually they are
start-aligned, because in Arabic the same constructs are right-aligned,
and a multilingual document will need to accommodate both writing
systems accordingly.

The following code exemplifies how using logical syntax can help you
write code that works across different writing systems:

![Rendering of the below code in a compatible
browser](./images/example01.png){height="109" width="300"}

``` highlight
<blockquote dir="auto">Quotation in English</blockquote>
<blockquote dir="auto">اقتباس في العربية</blockquote>
```

``` highlight
blockquote {
 text-align: start; /* left in latin, right in arabic */
 margin-inline-start: 0px; /* margin-left in latin, margin-right in arabic */
 border-inline-start: 5px solid gray; /* border-left in latin, border-right in arabic */
 padding-inline-start: 5px; /* padding-left in latin, padding-right in arabic */
}
```

Documents might need both logical and physical properties. For instance
the drop shadows on buttons on a page must remain consistent throughout,
so their offset will be chosen based on visual considerations and
physical directions, and not vary by writing system.

Since CSS was originally designed with only physical coordinates in its
controls, this module introduces text-flow--relative equivalents so that
declarations in a CSS style sheet can be expressed in
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) terms. It defines the mapping and cascading of
equivalent properties, some new properties and values equivalent to
those in CSS2.1, and the principles used to derive their syntaxes.
Future CSS specifications are expected to incorporate both sets of
coordinates in their property and value definitions, so this module will
not track the introduction of [flow-relative]
variants of newer CSS features.

[CSS Writing Modes](http://www.w3.org/TR/css-writing-modes/)' [Abstract
Box
Terminology](https://www.w3.org/TR/css-writing-modes-3/#abstract-box)
section defines how to map between flow-relative and physical terms.
This mapping, which depends on the [used
values](https://drafts.csswg.org/css-cascade-5/#used-value) of
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation), controls the interpretation of
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) keywords and properties.

![Correspondence of physical and flow-relative terms in typical English
text layout](diagrams/sizing-ltr-tb.svg){height="239" width="392"}

![Correspondence of physical and flow-relative terms in vertical Chinese
text layout](diagrams/sizing-ttb-rl.svg){height="239" width="392"}

 Due to its interaction with [text-orientation:
upright](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation), the
[used](https://drafts.csswg.org/css-cascade-5/#used-value)
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) depends on the [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) of
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) and
[text-orientation].

Tests

General tests for logical properties

- [getComputedStyle-listing.html](https://wpt.fyi/results/css/css-logical/getComputedStyle-listing.html "css/css-logical/getComputedStyle-listing.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/getComputedStyle-listing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/getComputedStyle-listing.html)
- [inheritance.html](https://wpt.fyi/results/css/css-logical/inheritance.html "css/css-logical/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/inheritance.html)
- [logicalprops-quirklength.html](https://wpt.fyi/results/css/css-logical/logicalprops-quirklength.html "css/css-logical/logicalprops-quirklength.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logicalprops-quirklength.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logicalprops-quirklength.html)

------------------------------------------------------------------------

**Things That Are Unstable** Since
implementation of parts of this module is effectively required for
shipping an implementation of [CSS Writing
Modes](https://www.w3.org/TR/css-writing-modes-3/) on the Web (in order
to correctly implement the default HTML styles), the CSSWG resolved that
the requisite features in [§ 2 Flow-Relative Values: block-start,
block-end, inline-start, inline-end](#directional-keywords) and [§ 4
Flow-Relative Box Model Properties](#box) are approved for shipping.
(See [FPWD
announcement](https://lists.w3.org/Archives/Public/www-style/2017Dec/0043.html)
for additional background.)

However, there are a few significant open issues:

- The [logical] keyword on shorthands, because the name of the
 keyword may change or it may be replaced by some other syntactic
 marker. (This feature will be deferred from this level for further
 development if there is no clearly satisfactory mechanism proposed,
 see [Issue 1282](https://github.com/w3c/csswg-drafts/issues/1282).)
- Whether flow-relative longhands inherit from their namesake on the
 parent, or are mapped to a physical property and inherit from that
 property. (See [Issue
 3029](https://github.com/w3c/csswg-drafts/issues/3029).)
- Whether shorthands like
 [margin](https://drafts.csswg.org/css-box-4/#propdef-margin) expand to both sets of longhands,
 or only the ones that were set. (See [Issue
 3030](https://github.com/w3c/csswg-drafts/issues/3030).)

Comments, suggestions, and use cases are welcome on these issues. Please
file them in GitHub, tweet them to \@csswg, or send them to
www-style@w3.org.

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

## [2. ][ Flow-Relative Values: [block-start], [block-end], [inline-start], [inline-end]]
Many CSS properties have historically accepted [directional
keyword] values that are
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) ([top], [bottom], [left],
[right]). This specification introduces [directional
keyword](#directional-keyword) values that are
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative): [block-start], [block-end],
[inline-start], [inline-end].

A property's effect can be either 1-dimensional or 2-dimensional. When
contextually constrained to one dimension, the flow-relative keywords
are abbreviated (to [start] and [end]).

CSS Level 2 properties are here redefined to also accept
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) directional keywords. Such values can be used in place
of the corresponding physical values. For properties that take multiple
keywords, combinations of flow-relative and physical values are not
allowed (unless otherwise specified in a future specification).

 Newer CSS specifications are expected in most cases to
define
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) or
[line-relative](https://drafts.csswg.org/css-writing-modes-4/#line-relative) values instead of or in addition to any
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) ones. In general, the mapping of such relative values
are expected to use the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) when affecting the box itself, and that of the box
itself when affecting its contents. Regardless, which [writing
modes] is used for the mapping needs to be
explicitly defined.

### [2.1. ][ Logical Values for the [caption-side](https://drafts.csswg.org/css2/#propdef-caption-side) Property]
Name:

[caption-side](https://drafts.csswg.org/css2/#propdef-caption-side)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

inline-start
[\|](https://drafts.csswg.org/css-values-4/#comb-one) inline-end

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

Tests

- [caption-side-no-interpolation.html](https://wpt.fyi/results/css/css-logical/animations/caption-side-no-interpolation.html "css/css-logical/animations/caption-side-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/animations/caption-side-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/animations/caption-side-no-interpolation.html)

These two values are added only for implementations that support
[left] and [right] values for
[caption-side](https://drafts.csswg.org/css2/#propdef-caption-side). The [left] and [right]
values themselves are defined to be
[line-relative](https://drafts.csswg.org/css-writing-modes-4/#line-relative).

The existing [top] and [bottom] values are idiosyncratically
redefined as assigning to the
[block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) and
[block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) sides of the table, respectively.

The mapping on this property uses the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the caption's [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) (that is, the [table wrapper
box](https://drafts.csswg.org/css-tables-3/#table-wrapper-box)).

### [2.2. ][ Flow-Relative Values for the [float](https://drafts.csswg.org/css2/#propdef-float) and [clear](https://drafts.csswg.org/css2/#propdef-clear) Properties]
Name:

[float](https://drafts.csswg.org/css2/#propdef-float),
[clear](https://drafts.csswg.org/css2/#propdef-clear)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

inline-start
[\|](https://drafts.csswg.org/css-values-4/#comb-one) inline-end

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

Tests

- [float-interpolation.html](https://wpt.fyi/results/css/css-logical/animations/float-interpolation.html "css/css-logical/animations/float-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/animations/float-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/animations/float-interpolation.html)
- [logical-values-float-clear-1.html](https://wpt.fyi/results/css/css-logical/logical-values-float-clear-1.html "css/css-logical/logical-values-float-clear-1.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-values-float-clear-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-values-float-clear-1.html)
- [logical-values-float-clear-2.html](https://wpt.fyi/results/css/css-logical/logical-values-float-clear-2.html "css/css-logical/logical-values-float-clear-2.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-values-float-clear-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-values-float-clear-2.html)
- [logical-values-float-clear-3.html](https://wpt.fyi/results/css/css-logical/logical-values-float-clear-3.html "css/css-logical/logical-values-float-clear-3.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-values-float-clear-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-values-float-clear-3.html)
- [logical-values-float-clear-4.html](https://wpt.fyi/results/css/css-logical/logical-values-float-clear-4.html "css/css-logical/logical-values-float-clear-4.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-values-float-clear-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-values-float-clear-4.html)
- [logical-values-float-clear-reftest.html](https://wpt.fyi/results/css/css-logical/logical-values-float-clear-reftest.html "css/css-logical/logical-values-float-clear-reftest.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-values-float-clear-reftest.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-values-float-clear-reftest.html)
- [logical-values-float-clear.html](https://wpt.fyi/results/css/css-logical/logical-values-float-clear.html "css/css-logical/logical-values-float-clear.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-values-float-clear.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-values-float-clear.html)

The mapping on these properties uses the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the element's [containing
block](https://drafts.csswg.org/css-display-4/#containing-block).

 These properties are 1-dimensional in CSS2, but are
planned to be expanded to two dimensions, and therefore are given
unabbreviated
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) keywords.

### [2.3. ][ Flow-Relative Values for the [text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align) Property]
Name:

[text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

start
[\|](https://drafts.csswg.org/css-values-4/#comb-one) end

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

These values are normatively defined in
[\[css-text-3\]](#biblio-css-text-3 "CSS Text Module Level 3").

## 3. Flow-Relative Page Classifications

In CSS, all pages are classified by user agents as either left pages or
right pages.
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
Which page is first in a spread, however, depends on whether the page
progression is left-to-right or right-to-left.

To allow control of page breaking to the page that is on the earlier or
later side of a spread, rather than to the left or right side of a
spread, this module introduces the following additional keywords for the
[page-break-after](https://drafts.csswg.org/css2/#propdef-page-break-after) and
[page-break-before](https://drafts.csswg.org/css2/#propdef-page-break-before) properties
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"):

[recto]
: Equivalent to
 [right](https://drafts.csswg.org/css-position-3/#propdef-right) in left-to-right page
 progressions and
 [left](https://drafts.csswg.org/css-position-3/#propdef-left) in right-to-left page
 progressions.

[verso]
: Equivalent to
 [left](https://drafts.csswg.org/css-position-3/#propdef-left) in left-to-right page
 progressions and
 [right](https://drafts.csswg.org/css-position-3/#propdef-right) in right-to-left page
 progressions.

These values are computed as specified and are further defined in
[\[css-break-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3").

Although authors typically place page numbers using physical placements,
the contents of headers often follows conventions depending on which
page in the spread is earlier. Therefore the following flow-relative
[page selectors](https://www.w3.org/TR/CSS2/page.html#page-selectors)
are also added to support flow-relative page selection:

[:recto]
: Equivalent to \':right\' in left-to-right page progressions and
 \':left\' in right-to-left page progressions.

[:verso]
: Equivalent to \':left\' in left-to-right page progressions and
 \':right\' in right-to-left page progressions.

The flow-relative page selectors have specificity equal to the \':left\'
and \':right\' page selectors.

## 4. Flow-Relative Box Model Properties

For many formatting effects, the axis or direction affected is encoded
in the property name rather than in its value. The type of directional
or axis mapping
([flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) or
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical)) of each such property is called its [mapping
logic].
Historically, all properties have been encoded in
[physical] terms; this specification introduces new
CSS properties that are [flow-relative]
equivalents of CSS2's [physical] box model
properties.

 Newer CSS specifications are expected in most cases to
define
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) or
[line-relative](https://drafts.csswg.org/css-writing-modes-4/#line-relative) properties instead of or in addition to any
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) ones.

Each set of parallel
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) properties and
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) properties (ignoring
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) properties) related by setting equivalent styles on the
various sides or dimensions of a box, forms a [logical property
group]. For example, the [padding-\*] properties form a single
[logical property
group](#logical-property-group), the [margin-\*] properties form a separate
[logical property group], the
[border-\*-style] properties form another [logical property
group], etc. (Each [longhand
property](https://drafts.csswg.org/css-cascade-5/#longhand) can belong to at most one [logical property
group].)

Within each [logical property
group](#logical-property-group), corresponding
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) and
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) properties are paired using the element's own
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value) [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode). Although the [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) of each property remains distinct, paired properties
share a [computed value]. This shared value is
determined by
[cascading](https://drafts.csswg.org/css-cascade-6/#cascade) the declarations of both properties together as one; in
other words, the [computed value] of both
properties in the pair is derived from the [specified
value] of the property declared with higher
priority in the CSS [cascade].
[\[CSS-CASCADE-3\]](#biblio-css-cascade-3 "CSS Cascading and Inheritance Level 3")

Note that this requires implementations to maintain relative order of
declarations within a CSS declaration block, which was not previously
required for CSS cascading. It also requires that
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation) be computed as a prerequisite for
cascading together the
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) and
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) declarations of a [logical property
group](#logical-property-group) to find their [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value).

For example, given the following rule:

```
p {
 margin-inline-start: 1px;
 margin-left: 2px;
 margin-inline-end: 3px;
}
```

In a paragraph with computed
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) being
[horizontal-tb](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-horizontal-tb) and computed
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) being
[ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr), the computed value of
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) is [2px], since for that
[writing-mode] and
[direction],
[margin-inline-start](#propdef-margin-inline-start) and
[margin-left] share a computed
value, and the declaration of
[margin-left] is after the
declaration of
[margin-inline-start].
However, if the computed [direction] were instead
[rtl](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-rtl), the computed value of
[margin-left] is [3px],
since
[margin-inline-end](#propdef-margin-inline-end) and
[margin-left] share a computed
value, and the declaration of
[margin-inline-end] is
after the declaration of [margin-left].

[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
APIs that return computed values (such as `getComputedStyle()`) must
return the same value for each individual property in such a pair.

 Depending on the element's own [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) for mapping every
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) property to its
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) equivalent simplifies the cascading calculations and
gives a straightforward model for authors to reason about. However, it
is problematic in many cases, see for example [this
discussion](https://www.w3.org/mid/20161108202634.GA7235@mail.internode.on.net).
Authors may need to use nested elements to get the correct mapping
behavior when changing an element's [writing
mode] from its parent.

Inheritance of each property is from its corresponding property on the
parent. For example, although the
[inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) margin of
an[rtl](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-rtl) box is its right margin,
[margin-inline-start](#propdef-margin-inline-start) on this box will inherit the
[margin-inline-start]
of an
[ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr) parent even though that happens to be the
parent's *left* margin.

Unless otherwise specified, [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that encompass both logical and physical longhands
(such as the
[all](https://drafts.csswg.org/css-cascade-5/#propdef-all) shorthand) set their physical
longhands last. For example, [all: inherit]
will set all of the
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin) properties to
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit), but since the physical longhands are set last,
the child's margins will inherit from their physical counterparts in the
parent.

Tests

- [animation-001.html](https://wpt.fyi/results/css/css-logical/animation-001.html "css/css-logical/animation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/animation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/animation-001.html)
- [animation-002.html](https://wpt.fyi/results/css/css-logical/animation-002.html "css/css-logical/animation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/animation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/animation-002.html)
- [animation-004.html](https://wpt.fyi/results/css/css-logical/animation-004.html "css/css-logical/animation-004.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/animation-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/animation-004.html)
- [logicalprops-with-deferred-writing-mode.html](https://wpt.fyi/results/css/css-logical/logicalprops-with-deferred-writing-mode.html "css/css-logical/logicalprops-with-deferred-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logicalprops-with-deferred-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logicalprops-with-deferred-writing-mode.html)
- [logicalprops-with-variables.html](https://wpt.fyi/results/css/css-logical/logicalprops-with-variables.html "css/css-logical/logicalprops-with-variables.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logicalprops-with-variables.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logicalprops-with-variables.html)

### 4.1. Logical Height and Logical Width: the [block-size/[inline-size](#propdef-inline-size), [min-block-size](#propdef-min-block-size)/[min-inline-size](#propdef-min-inline-size), and [max-block-size](#propdef-max-block-size)/[max-inline-size](#propdef-max-inline-size) properties]
Name:

[block-size], [inline-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'width\'\>](https://drafts.csswg.org/css-sizing-3/#propdef-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

As for the corresponding physical property

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Same as
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height),
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[size](https://drafts.csswg.org/css-sizing-4/#propdef-size)

Tests

- [cascading-001.html](https://wpt.fyi/results/css/css-logical/cascading-001.html "css/css-logical/cascading-001.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/cascading-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/cascading-001.html)
- [logical-box-size.html](https://wpt.fyi/results/css/css-logical/logical-box-size.html "css/css-logical/logical-box-size.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-box-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-box-size.html)
- [logicalprops-block-size-vlr.html](https://wpt.fyi/results/css/css-logical/logicalprops-block-size-vlr.html "css/css-logical/logicalprops-block-size-vlr.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logicalprops-block-size-vlr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logicalprops-block-size-vlr.html)
- [logicalprops-block-size.html](https://wpt.fyi/results/css/css-logical/logicalprops-block-size.html "css/css-logical/logicalprops-block-size.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logicalprops-block-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logicalprops-block-size.html)
- [logicalprops-inline-size-vlr.html](https://wpt.fyi/results/css/css-logical/logicalprops-inline-size-vlr.html "css/css-logical/logicalprops-inline-size-vlr.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logicalprops-inline-size-vlr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logicalprops-inline-size-vlr.html)
- [logicalprops-inline-size.html](https://wpt.fyi/results/css/css-logical/logicalprops-inline-size.html "css/css-logical/logicalprops-inline-size.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logicalprops-inline-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logicalprops-inline-size.html)
- [block-size-computed.html](https://wpt.fyi/results/css/css-logical/parsing/block-size-computed.html "css/css-logical/parsing/block-size-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/block-size-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/block-size-computed.html)
- [block-size-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/block-size-invalid.html "css/css-logical/parsing/block-size-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/block-size-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/block-size-invalid.html)
- [block-size-valid.html](https://wpt.fyi/results/css/css-logical/parsing/block-size-valid.html "css/css-logical/parsing/block-size-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/block-size-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/block-size-valid.html)
- [inline-size-computed.html](https://wpt.fyi/results/css/css-logical/parsing/inline-size-computed.html "css/css-logical/parsing/inline-size-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inline-size-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inline-size-computed.html)
- [inline-size-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/inline-size-invalid.html "css/css-logical/parsing/inline-size-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inline-size-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inline-size-invalid.html)
- [inline-size-valid.html](https://wpt.fyi/results/css/css-logical/parsing/inline-size-valid.html "css/css-logical/parsing/inline-size-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inline-size-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inline-size-valid.html)

These properties correspond to the
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode).

Name:

[min-block-size],
[min-inline-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'min-width\'\>](https://drafts.csswg.org/css2/#propdef-min-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

same as
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

As for the corresponding physical property

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Same as
[min-height](https://drafts.csswg.org/css2/#propdef-min-height),
[min-width](https://drafts.csswg.org/css2/#propdef-min-width)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[min-size](https://drafts.csswg.org/css-sizing-4/#propdef-min-size)

Tests

- [min-block-size-computed.html](https://wpt.fyi/results/css/css-logical/parsing/min-block-size-computed.html "css/css-logical/parsing/min-block-size-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/min-block-size-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/min-block-size-computed.html)
- [min-block-size-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/min-block-size-invalid.html "css/css-logical/parsing/min-block-size-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/min-block-size-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/min-block-size-invalid.html)
- [min-block-size-valid.html](https://wpt.fyi/results/css/css-logical/parsing/min-block-size-valid.html "css/css-logical/parsing/min-block-size-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/min-block-size-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/min-block-size-valid.html)
- [min-inline-size-computed.html](https://wpt.fyi/results/css/css-logical/parsing/min-inline-size-computed.html "css/css-logical/parsing/min-inline-size-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/min-inline-size-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/min-inline-size-computed.html)
- [min-inline-size-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/min-inline-size-invalid.html "css/css-logical/parsing/min-inline-size-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/min-inline-size-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/min-inline-size-invalid.html)
- [min-inline-size-valid.html](https://wpt.fyi/results/css/css-logical/parsing/min-inline-size-valid.html "css/css-logical/parsing/min-inline-size-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/min-inline-size-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/min-inline-size-valid.html)

These properties correspond to the
[min-height](https://drafts.csswg.org/css2/#propdef-min-height) and
[min-width](https://drafts.csswg.org/css2/#propdef-min-width) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode).

Name:

[max-block-size],
[max-inline-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'max-width\'\>](https://drafts.csswg.org/css2/#propdef-max-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

same as
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

As for the corresponding physical property

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Same as
[max-height](https://drafts.csswg.org/css2/#propdef-max-height),
[max-width](https://drafts.csswg.org/css2/#propdef-max-width)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[max-size](https://drafts.csswg.org/css-sizing-4/#propdef-max-size)

Tests

- [max-block-size-computed.html](https://wpt.fyi/results/css/css-logical/parsing/max-block-size-computed.html "css/css-logical/parsing/max-block-size-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/max-block-size-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/max-block-size-computed.html)
- [max-block-size-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/max-block-size-invalid.html "css/css-logical/parsing/max-block-size-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/max-block-size-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/max-block-size-invalid.html)
- [max-block-size-valid.html](https://wpt.fyi/results/css/css-logical/parsing/max-block-size-valid.html "css/css-logical/parsing/max-block-size-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/max-block-size-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/max-block-size-valid.html)
- [max-inline-size-computed.html](https://wpt.fyi/results/css/css-logical/parsing/max-inline-size-computed.html "css/css-logical/parsing/max-inline-size-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/max-inline-size-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/max-inline-size-computed.html)
- [max-inline-size-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/max-inline-size-invalid.html "css/css-logical/parsing/max-inline-size-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/max-inline-size-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/max-inline-size-invalid.html)
- [max-inline-size-valid.html](https://wpt.fyi/results/css/css-logical/parsing/max-inline-size-valid.html "css/css-logical/parsing/max-inline-size-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/max-inline-size-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/max-inline-size-valid.html)

These properties correspond to the
[max-height](https://drafts.csswg.org/css2/#propdef-max-height) and
[max-width](https://drafts.csswg.org/css2/#propdef-max-width) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode).

### 4.2. Flow-Relative Margins: the [margin-block-start, [margin-block-end](#propdef-margin-block-end), [margin-inline-start](#propdef-margin-inline-start), [margin-inline-end](#propdef-margin-inline-end) properties and [margin-block](#propdef-margin-block) and [margin-inline](#propdef-margin-inline) shorthands]
Name:

[margin-block-start],
[margin-block-end],
[margin-inline-start],
[margin-inline-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'margin-top\'\>](https://drafts.csswg.org/css-box-4/#propdef-margin-top)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

As for the corresponding physical property

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Same as corresponding [margin-\*] properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[margin](https://drafts.csswg.org/css-box-4/#propdef-margin)

Tests

- [logical-box-margin.html](https://wpt.fyi/results/css/css-logical/logical-box-margin.html "css/css-logical/logical-box-margin.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-box-margin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-box-margin.html)
- [margin-block-inline-computed.html](https://wpt.fyi/results/css/css-logical/parsing/margin-block-inline-computed.html "css/css-logical/parsing/margin-block-inline-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/margin-block-inline-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/margin-block-inline-computed.html)
- [margin-block-inline-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/margin-block-inline-invalid.html "css/css-logical/parsing/margin-block-inline-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/margin-block-inline-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/margin-block-inline-invalid.html)
- [margin-block-inline-shorthand.html](https://wpt.fyi/results/css/css-logical/parsing/margin-block-inline-shorthand.html "css/css-logical/parsing/margin-block-inline-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/margin-block-inline-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/margin-block-inline-shorthand.html)
- [margin-block-inline-valid.html](https://wpt.fyi/results/css/css-logical/parsing/margin-block-inline-valid.html "css/css-logical/parsing/margin-block-inline-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/margin-block-inline-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/margin-block-inline-valid.html)

These properties correspond to the
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top),
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom),
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left), and
[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation).

Name:

[margin-block], [margin-inline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'margin-top\'\>](https://drafts.csswg.org/css-box-4/#propdef-margin-top)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

Tests

- [margin-block-interpolation.html](https://wpt.fyi/results/css/css-logical/animations/margin-block-interpolation.html "css/css-logical/animations/margin-block-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/animations/margin-block-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/animations/margin-block-interpolation.html)
- [margin-inline-interpolation.html](https://wpt.fyi/results/css/css-logical/animations/margin-inline-interpolation.html "css/css-logical/animations/margin-inline-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/animations/margin-inline-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/animations/margin-inline-interpolation.html)

These two [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) set the
[margin-block-start](#propdef-margin-block-start) &
[margin-block-end](#propdef-margin-block-end) and
[margin-inline-start](#propdef-margin-inline-start) &
[margin-inline-end](#propdef-margin-inline-end), respectively. The first value
represents the
[start](https://drafts.csswg.org/css-writing-modes-3/#css-start) edge style, and the second value represents the
[end](https://drafts.csswg.org/css-writing-modes-3/#css-end) edge style. If only one value is given, it applies to
both the [start] and [end]
edges.

### 4.3. Flow-Relative Offsets: the [inset-block-start, [inset-block-end](#propdef-inset-block-end), [inset-inline-start](#propdef-inset-inline-start), [inset-inline-end](#propdef-inset-inline-end) properties and [inset-block](#propdef-inset-block), [inset-inline](#propdef-inset-inline), and [inset](#propdef-inset) shorthands]
The
[top](https://drafts.csswg.org/css-position-3/#propdef-top),
[left](https://drafts.csswg.org/css-position-3/#propdef-left),
[bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom),
[right](https://drafts.csswg.org/css-position-3/#propdef-right) physical properties, their
[inset-block-start](#propdef-inset-block-start),
[inset-block-end](#propdef-inset-block-end),
[inset-inline-start](#propdef-inset-inline-start),
[inset-inline-end](#propdef-inset-inline-end) flow-relative correspondents, and
the [inset-block](#propdef-inset-block),
[inset-inline](#propdef-inset-inline), and
[inset](#propdef-inset) shorthands, are collectively known as the [inset
properties].

Name:

[inset-block-start],
[inset-block-end],
[inset-inline-start],
[inset-inline-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'top\'\>](https://drafts.csswg.org/css-position-3/#propdef-top)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

positioned elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

As for the corresponding physical property

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Same as corresponding
[top](https://drafts.csswg.org/css-position-3/#propdef-top)/[right](https://drafts.csswg.org/css-position-3/#propdef-right)/[bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom)/[left](https://drafts.csswg.org/css-position-3/#propdef-left) properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[inset](#propdef-inset)

Tests

- [logical-box-inset.html](https://wpt.fyi/results/css/css-logical/logical-box-inset.html "css/css-logical/logical-box-inset.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-box-inset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-box-inset.html)
- [inset-block-inline-computed.html](https://wpt.fyi/results/css/css-logical/parsing/inset-block-inline-computed.html "css/css-logical/parsing/inset-block-inline-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inset-block-inline-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inset-block-inline-computed.html)
- [inset-block-inline-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/inset-block-inline-invalid.html "css/css-logical/parsing/inset-block-inline-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inset-block-inline-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inset-block-inline-invalid.html)
- [inset-block-inline-shorthand.html](https://wpt.fyi/results/css/css-logical/parsing/inset-block-inline-shorthand.html "css/css-logical/parsing/inset-block-inline-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inset-block-inline-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inset-block-inline-shorthand.html)
- [inset-block-inline-valid.html](https://wpt.fyi/results/css/css-logical/parsing/inset-block-inline-valid.html "css/css-logical/parsing/inset-block-inline-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inset-block-inline-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inset-block-inline-valid.html)

These properties correspond to the
[top](https://drafts.csswg.org/css-position-3/#propdef-top),
[bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom),
[left](https://drafts.csswg.org/css-position-3/#propdef-left), and
[right](https://drafts.csswg.org/css-position-3/#propdef-right) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation).

Name:

[inset-block], [inset-inline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'top\'\>](https://drafts.csswg.org/css-position-3/#propdef-top)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These two [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) set the
[inset-block-start](#propdef-inset-block-start) &
[inset-block-end](#propdef-inset-block-end) and
[inset-inline-start](#propdef-inset-inline-start) &
[inset-inline-end](#propdef-inset-inline-end), respectively. The first value
represents the
[start](https://drafts.csswg.org/css-writing-modes-3/#css-start) edge style, and the second value represents the
[end](https://drafts.csswg.org/css-writing-modes-3/#css-end) edge style. If only one value is given, it applies to
both the [start] and [end]
edges.

Name:

[inset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'top\'\>](https://drafts.csswg.org/css-position-3/#propdef-top)[{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

Tests

- [inset-computed.html](https://wpt.fyi/results/css/css-logical/parsing/inset-computed.html "css/css-logical/parsing/inset-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inset-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inset-computed.html)
- [inset-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/inset-invalid.html "css/css-logical/parsing/inset-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inset-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inset-invalid.html)
- [inset-shorthand.html](https://wpt.fyi/results/css/css-logical/parsing/inset-shorthand.html "css/css-logical/parsing/inset-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inset-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inset-shorthand.html)
- [inset-valid.html](https://wpt.fyi/results/css/css-logical/parsing/inset-valid.html "css/css-logical/parsing/inset-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/inset-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/inset-valid.html)

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets the
[top](https://drafts.csswg.org/css-position-3/#propdef-top),
[right](https://drafts.csswg.org/css-position-3/#propdef-right),
[bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom), and
[left](https://drafts.csswg.org/css-position-3/#propdef-left) properties. Values are assigned to
its
[sub-properties](https://drafts.csswg.org/css-cascade-5/#longhand) as for
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin).

### 4.4. Flow-Relative Padding: the [padding-block-start, [padding-block-end](#propdef-padding-block-end), [padding-inline-start](#propdef-padding-inline-start), [padding-inline-end](#propdef-padding-inline-end) properties and [padding-block](#propdef-padding-block) and [padding-inline](#propdef-padding-inline) shorthands]
Name:

[padding-block-start],
[padding-block-end],
[padding-inline-start],
[padding-inline-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'padding-top\'\>](https://drafts.csswg.org/css-box-4/#propdef-padding-top)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

As for the corresponding physical property

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Same as corresponding [padding-\*] properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[padding](https://drafts.csswg.org/css-box-4/#propdef-padding)

Tests

- [logical-box-padding.html](https://wpt.fyi/results/css/css-logical/logical-box-padding.html "css/css-logical/logical-box-padding.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-box-padding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-box-padding.html)
- [padding-block-inline-computed.html](https://wpt.fyi/results/css/css-logical/parsing/padding-block-inline-computed.html "css/css-logical/parsing/padding-block-inline-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/padding-block-inline-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/padding-block-inline-computed.html)
- [padding-block-inline-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/padding-block-inline-invalid.html "css/css-logical/parsing/padding-block-inline-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/padding-block-inline-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/padding-block-inline-invalid.html)
- [padding-block-inline-shorthand.html](https://wpt.fyi/results/css/css-logical/parsing/padding-block-inline-shorthand.html "css/css-logical/parsing/padding-block-inline-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/padding-block-inline-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/padding-block-inline-shorthand.html)
- [padding-block-inline-valid.html](https://wpt.fyi/results/css/css-logical/parsing/padding-block-inline-valid.html "css/css-logical/parsing/padding-block-inline-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/padding-block-inline-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/padding-block-inline-valid.html)

These properties correspond to the
[padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top),
[padding-bottom](https://drafts.csswg.org/css-box-4/#propdef-padding-bottom),
[padding-left](https://drafts.csswg.org/css-box-4/#propdef-padding-left), and
[padding-right](https://drafts.csswg.org/css-box-4/#propdef-padding-right) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation).

Name:

[padding-block], [padding-inline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'padding-top\'\>](https://drafts.csswg.org/css-box-4/#propdef-padding-top)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

Tests

- [padding-block-interpolation.html](https://wpt.fyi/results/css/css-logical/animations/padding-block-interpolation.html "css/css-logical/animations/padding-block-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/animations/padding-block-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/animations/padding-block-interpolation.html)
- [padding-inline-interpolation.html](https://wpt.fyi/results/css/css-logical/animations/padding-inline-interpolation.html "css/css-logical/animations/padding-inline-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/animations/padding-inline-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/animations/padding-inline-interpolation.html)

These two [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) set the
[padding-block-start](#propdef-padding-block-start) &
[padding-block-end](#propdef-padding-block-end) and
[padding-inline-start](#propdef-padding-inline-start) &
[padding-inline-end](#propdef-padding-inline-end), respectively. The first value
represents the
[start](https://drafts.csswg.org/css-writing-modes-3/#css-start) edge style, and the second value represents the
[end](https://drafts.csswg.org/css-writing-modes-3/#css-end) edge style. If only one value is given, it applies to
both the [start] and [end]
edges.

### 4.5. Flow-Relative Borders

#### 4.5.1. Flow-Relative Border Widths: the [border-block-start-width, [border-block-end-width](#propdef-border-block-end-width), [border-inline-start-width](#propdef-border-inline-start-width), [border-inline-end-width](#propdef-border-inline-end-width) properties and [border-block-width](#propdef-border-block-width) and [border-inline-width](#propdef-border-inline-width) shorthands]
Name:

[border-block-start-width],
[border-block-end-width],
[border-inline-start-width],
[border-inline-end-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-width\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

medium

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[border-top-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-width)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Same as corresponding [border-\*-width] properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-width)

Tests

- [logical-box-border-width.html](https://wpt.fyi/results/css/css-logical/logical-box-border-width.html "css/css-logical/logical-box-border-width.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-box-border-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-box-border-width.html)

These properties correspond to the
[border-top-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-width),
[border-bottom-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-bottom-width),
[border-left-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-left-width), and
[border-right-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-right-width) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation).

Name:

[border-block-width],
[border-inline-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-width\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-width)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

Tests

- [border-block-width-computed.html](https://wpt.fyi/results/css/css-logical/parsing/border-block-width-computed.html "css/css-logical/parsing/border-block-width-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-block-width-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-block-width-computed.html)
- [border-block-width-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/border-block-width-invalid.html "css/css-logical/parsing/border-block-width-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-block-width-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-block-width-invalid.html)
- [border-block-width-valid.html](https://wpt.fyi/results/css/css-logical/parsing/border-block-width-valid.html "css/css-logical/parsing/border-block-width-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-block-width-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-block-width-valid.html)
- [border-inline-width-computed.html](https://wpt.fyi/results/css/css-logical/parsing/border-inline-width-computed.html "css/css-logical/parsing/border-inline-width-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-inline-width-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-inline-width-computed.html)
- [border-inline-width-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/border-inline-width-invalid.html "css/css-logical/parsing/border-inline-width-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-inline-width-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-inline-width-invalid.html)
- [border-inline-width-valid.html](https://wpt.fyi/results/css/css-logical/parsing/border-inline-width-valid.html "css/css-logical/parsing/border-inline-width-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-inline-width-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-inline-width-valid.html)

These two [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) set the
[border-block-start-width](#propdef-border-block-start-width) &
[border-block-end-width](#propdef-border-block-end-width) and
[border-inline-start-width](#propdef-border-inline-start-width) &
[border-inline-end-width](#propdef-border-inline-end-width), respectively. The first value
represents the
[start](https://drafts.csswg.org/css-writing-modes-3/#css-start) edge width, and the second value represents the
[end](https://drafts.csswg.org/css-writing-modes-3/#css-end) edge width. If only one value is given, it applies to
both the [start] and [end]
edges.

#### 4.5.2. Flow-Relative Border Styles: the [border-block-start-style, [border-block-end-style](#propdef-border-block-end-style), [border-inline-start-style](#propdef-border-inline-start-style), [border-inline-end-style](#propdef-border-inline-end-style) properties and [border-block-style](#propdef-border-block-style) and [border-inline-style](#propdef-border-inline-style) shorthands]
Name:

[border-block-start-style],
[border-block-end-style],
[border-inline-start-style],
[border-inline-end-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-style\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-style)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[border-top-style](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-style)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Same as corresponding [border-\*-style] properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-style](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-style)

Tests

- [logical-box-border-style.html](https://wpt.fyi/results/css/css-logical/logical-box-border-style.html "css/css-logical/logical-box-border-style.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-box-border-style.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-box-border-style.html)
- [border-block-style-computed.html](https://wpt.fyi/results/css/css-logical/parsing/border-block-style-computed.html "css/css-logical/parsing/border-block-style-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-block-style-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-block-style-computed.html)
- [border-block-style-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/border-block-style-invalid.html "css/css-logical/parsing/border-block-style-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-block-style-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-block-style-invalid.html)
- [border-block-style-valid.html](https://wpt.fyi/results/css/css-logical/parsing/border-block-style-valid.html "css/css-logical/parsing/border-block-style-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-block-style-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-block-style-valid.html)
- [border-inline-style-computed.html](https://wpt.fyi/results/css/css-logical/parsing/border-inline-style-computed.html "css/css-logical/parsing/border-inline-style-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-inline-style-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-inline-style-computed.html)
- [border-inline-style-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/border-inline-style-invalid.html "css/css-logical/parsing/border-inline-style-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-inline-style-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-inline-style-invalid.html)
- [border-inline-style-valid.html](https://wpt.fyi/results/css/css-logical/parsing/border-inline-style-valid.html "css/css-logical/parsing/border-inline-style-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-inline-style-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-inline-style-valid.html)

These properties correspond to the
[border-top-style](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-style),
[border-bottom-style](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-bottom-style),
[border-left-style](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-left-style), and
[border-right-style](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-right-style) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation).

Name:

[border-block-style],
[border-inline-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-style\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-style)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These two [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) set the
[border-block-start-style](#propdef-border-block-start-style) &
[border-block-end-style](#propdef-border-block-end-style) and
[border-inline-start-style](#propdef-border-inline-start-style) &
[border-inline-end-style](#propdef-border-inline-end-style), respectively. The first value
represents the
[start](https://drafts.csswg.org/css-writing-modes-3/#css-start) edge style, and the second value represents the
[end](https://drafts.csswg.org/css-writing-modes-3/#css-end) edge style. If only one value is given, it applies to
both the [start] and [end]
edges.

#### 4.5.3. Flow-Relative Border Colors: the [border-block-start-color, [border-block-end-color](#propdef-border-block-end-color), [border-inline-start-color](#propdef-border-inline-start-color), [border-inline-end-color](#propdef-border-inline-end-color) properties and [border-block-color](#propdef-border-block-color) and [border-inline-color](#propdef-border-inline-color) shorthands]
Name:

[border-block-start-color],
[border-block-end-color],
[border-inline-start-color],
[border-inline-end-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-color\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

currentcolor

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[border-top-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-color)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Same as corresponding [border-\*-color] properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-color)

Tests

- [logical-box-border-color.html](https://wpt.fyi/results/css/css-logical/logical-box-border-color.html "css/css-logical/logical-box-border-color.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-box-border-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-box-border-color.html)
- [border-block-color-computed.html](https://wpt.fyi/results/css/css-logical/parsing/border-block-color-computed.html "css/css-logical/parsing/border-block-color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-block-color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-block-color-computed.html)
- [border-block-color-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/border-block-color-invalid.html "css/css-logical/parsing/border-block-color-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-block-color-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-block-color-invalid.html)
- [border-block-color-valid.html](https://wpt.fyi/results/css/css-logical/parsing/border-block-color-valid.html "css/css-logical/parsing/border-block-color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-block-color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-block-color-valid.html)
- [border-inline-color-computed.html](https://wpt.fyi/results/css/css-logical/parsing/border-inline-color-computed.html "css/css-logical/parsing/border-inline-color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-inline-color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-inline-color-computed.html)
- [border-inline-color-invalid.html](https://wpt.fyi/results/css/css-logical/parsing/border-inline-color-invalid.html "css/css-logical/parsing/border-inline-color-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-inline-color-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-inline-color-invalid.html)
- [border-inline-color-valid.html](https://wpt.fyi/results/css/css-logical/parsing/border-inline-color-valid.html "css/css-logical/parsing/border-inline-color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-inline-color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-inline-color-valid.html)

These properties correspond to the
[border-top-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-color),
[border-bottom-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-bottom-color),
[border-left-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-left-color), and
[border-right-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-right-color) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation).

Name:

[border-block-color],
[border-inline-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-color\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-color)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These two [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) set the
[border-block-start-color](#propdef-border-block-start-color) &
[border-block-end-color](#propdef-border-block-end-color) and
[border-inline-start-color](#propdef-border-inline-start-color) &
[border-inline-end-color](#propdef-border-inline-end-color), respectively. The first value
represents the
[start](https://drafts.csswg.org/css-writing-modes-3/#css-start) edge color, and the second value represents the
[end](https://drafts.csswg.org/css-writing-modes-3/#css-end) edge color. If only one value is given, it applies to
both the [start] and [end]
edges.

#### 4.5.4. Flow-Relative Border Shorthands: the [border-block-start, [border-block-end](#propdef-border-block-end), [border-inline-start](#propdef-border-inline-start), [border-inline-end](#propdef-border-inline-end) properties and [border-block](#propdef-border-block) and [border-inline](#propdef-border-inline) shorthands]
Name:

[border-block-start],
[border-block-end],
[border-inline-start],
[border-inline-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-width\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-width)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'border-top-style\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-style) [\|\|]
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

Tests

- [logical-box-border-shorthands.html](https://wpt.fyi/results/css/css-logical/logical-box-border-shorthands.html "css/css-logical/logical-box-border-shorthands.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-box-border-shorthands.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-box-border-shorthands.html)
- [border-block-valid.html](https://wpt.fyi/results/css/css-logical/parsing/border-block-valid.html "css/css-logical/parsing/border-block-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-block-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-block-valid.html)

These properties correspond to the
[border-top](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top),
[border-bottom](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-bottom),
[border-left](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-left), and
[border-right](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-right) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation).

Name:

[border-block], [border-inline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-block-start\'\>](#propdef-border-block-start)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

Tests

- [border-inline-valid.html](https://wpt.fyi/results/css/css-logical/parsing/border-inline-valid.html "css/css-logical/parsing/border-inline-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/parsing/border-inline-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/parsing/border-inline-valid.html)

These two [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) set the
[border-block-start](#propdef-border-block-start) &
[border-block-end](#propdef-border-block-end) or
[border-inline-start](#propdef-border-inline-start) &
[border-inline-end](#propdef-border-inline-end), respectively, both to the same
style.

### 4.6. Flow-Relative Corner Rounding: the [border-start-start-radius, [border-start-end-radius](#propdef-border-start-end-radius), [border-end-start-radius](#propdef-border-end-start-radius), [border-end-end-radius](#propdef-border-end-end-radius) properties]
Name:

[border-start-start-radius],
[border-start-end-radius],
[border-end-start-radius],
[border-end-end-radius]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-left-radius\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-left-radius)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

Same as
[border-top-left-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-left-radius)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[border-top-left-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-left-radius)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Same as
[border-top-left-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-left-radius)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Same as corresponding physical [border-\*-radius] properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-radius)

Tests

- [logical-box-border-radius.html](https://wpt.fyi/results/css/css-logical/logical-box-border-radius.html "css/css-logical/logical-box-border-radius.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-box-border-radius.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-box-border-radius.html)

These properties correspond to the
[border-top-left-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-left-radius),
[border-bottom-left-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-bottom-left-radius),
[border-top-right-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-right-radius), and
[border-bottom-right-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-bottom-right-radius) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation), with the first start/end giving
the block axis side, and the second the inline-axis side (i.e. patterned
as \'border-`block`-`inline`-radius\').

### [4.7. ][ Four-Directional Shorthand Properties: the [margin](https://drafts.csswg.org/css-box-4/#propdef-margin), [padding](https://drafts.csswg.org/css-box-4/#propdef-padding), [border-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-width), [border-style](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-style), and [border-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-color) shorthands]
The shorthand properties for margin, padding, and border set values for
physical properties by default. But authors can specify the
[logical] keyword at the beginning of the property
value to indicate that the values map to the flow-relative properties
instead of the physical ones.

The proposed syntax for this feature is
[under discussion](https://github.com/w3c/csswg-drafts/issues/1282) and
is almost guaranteed to change from what is described here. This section
remains in the draft to promote discussion of alternatives, to document
the affected properties, and to specify the expected impact on the
interpretation of whatever syntactic switch is ultimately chosen.

The following
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
shorthand properties accept the
[logical](#valdef-margin-logical) keyword:

- [inset](#propdef-inset)
- [margin](https://drafts.csswg.org/css-box-4/#propdef-margin)
- [padding](https://drafts.csswg.org/css-box-4/#propdef-padding)
- [border-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-width)
- [border-style](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-style)
- [border-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-color)
- [scroll-padding](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding)
- [scroll-margin](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin)

The syntax for these properties is effectively changed by replacing

``` prod
<value-type>{1,4}
```

with

``` prod
logical? <value-type>{1,4}
```

When the
[logical](#valdef-margin-logical) keyword is present in the value, the values that
follow are assigned to its flow-relative longhands as follows:

- If only one value is set, the value applies to all four flow-relative
 [longhands](https://drafts.csswg.org/css-cascade-5/#longhand).
- If two values are set, the first is for block-start and block-end, the
 second is for inline-start and inline-end.
- If three values are set, the first is for block-start, the second is
 for inline-start and inline-end, and the third is for block-end.
- If four values are set, they apply to the block-start, inline-start,
 block-end, and inline-end sides in that order.

In the following example, the two
rules are equivalent:

```
blockquote {
 margin: logical 1em 2em 3em 4em;
}
blockquote {
 margin-block-start: 1em;
 margin-inline-start: 2em;
 margin-block-end: 3em;
 margin-inline-end: 4em;
}
```

## 5. Acknowledgements

Cameron McCormack, David Baron, Oriol Brufau, Shinyu Murakami, Tab
Atkins

## 6. Changes

Changes since the [27 August 2018 Working
Draft](https://www.w3.org/TR/2018/WD-css-logical-1-20180827/) include:

- Defined inheritance of flow-relative properties.
- Moved flow-relative values of
 [resize](https://drafts.csswg.org/css-ui-4/#propdef-resize) to
 [\[CSS-UI-4\]](#biblio-css-ui-4 "CSS Basic User Interface Module Level 4").
- Editorially rewrote large parts of the specification for clarity.
- Added
 [text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation) to list of mapping dependencies.
- Clarified that
 [border-inline](#propdef-border-inline) and
 [border-block](#propdef-border-block) set both affected sides to the
 same value.
- Clarified the mapping for border-radius.
- Referred to physical margin, border, and padding properties in the
 elements they apply to, so ruby base containers and ruby annotation
 containers are excluded.
- Made margin and padding properties refer to [\*-top] properties
 for consistency.
- Defined the term [inset
 properties](#inset-properties).
- Miscellaneous minor clarifications.
- Added Web Platform Tests coverage.

Changes between the earlier Editors Drafts and the [18 May 2017 First
Public Working
Draft](https://www.w3.org/TR/2017/WD-css-logical-1-20170518/) include:

- Making all properties cascade using the [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) specified on the element, not on its parent.
- Making the ordering of longhands within
 [margin](https://drafts.csswg.org/css-box-4/#propdef-margin)-like shorthands put inline-start
 before inline-end.
- Adding the [\*-inline] and [\*-block] shorthand forms for
 margins/borders/padding.
- Renaming the [offset-\*] properties to [inset-\*] and
 marking an issue for discussion.
- Adding an Introduction section.
- Updating to current terminology of CSS Writing Modes.
- Miscellaneous prose cleanup.

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.

Tests

Features from other specs

- [logical-values-resize.html](https://wpt.fyi/results/css/css-logical/logical-values-resize.html "css/css-logical/logical-values-resize.html")
 [[(live
 test)]](http://wpt.live/css/css-logical/logical-values-resize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-logical/logical-values-resize.html)

------------------------------------------------------------------------
