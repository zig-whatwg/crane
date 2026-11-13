## 1. Introduction

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

*This section is non-normative.*

This CSS module introduces properties to influence the visual styling of
scrollbars, including their color
([scrollbar-color](#propdef-scrollbar-color)) and thickness
([scrollbar-width](#propdef-scrollbar-width)).

### 1.1. Scope

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

The CSS Scrollbars Module is specifically for styling scrollbar controls
themselves, e.g. their color & width in Level 1, and not their layout
nor whether any content is scrollable. All layout impacts and content
scrollability are specified in the [CSS Overflow
Module](https://drafts.csswg.org/css-overflow/).

Based on [documented
use-cases](https://www.w3.org/wiki/Css-scrollbars#Use-cases), there are
three main use-cases around scrollbars this module intends to resolve:

1. Coloring scrollbars to fit better into the UI of a web application.
2. Using a thinner scrollbar when the scrolling area is small.
3. Hiding UA-provided scrollbars, to allow the provision of custom
 interfaces for scrolling without affecting other aspects of
 scrollability.

Tests

Tests that related to the specification as a whole, without exerting any
specific part

- [invalid-needs-layout-crash.html](https://wpt.fyi/results/css/css-scrollbars/invalid-needs-layout-crash.html "css/css-scrollbars/invalid-needs-layout-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/invalid-needs-layout-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/invalid-needs-layout-crash.html)
- [scrollbar-after-remove-resize.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-after-remove-resize.html "css/css-scrollbars/scrollbar-after-remove-resize.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-after-remove-resize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-after-remove-resize.html)

------------------------------------------------------------------------

#### 1.1.1. Out Of Scope

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

The internal structure, layout, and configuration of scrollbars, as well
as precise control over their coloring, is out of scope. This is because
different platforms have different scrollbar structures and styling
conventions, and operating systems continuously evolve their scrollbar
designs to provide better user experience. Pseudo-elements for selecting
specific parts of a scrollbar, for example, were considered and
rejected. While this level of fine control would be tempting for
authors, the arrangement of the various parts---​or whether they're even
all present---​cannot be depended on. Providing too much control would
allow authors to get perfect results on some platforms, but at the
expense of broken results on others.

 Exposing the scrollbar-related `::-webkit-` prefixed
pseudo-elements to the Web is considered a mistake by both the CSS
Working Group and Webkit. Nevertheless, see [§ 2.1 Interaction with
non-standard features](#color-compat) and [§ 3.1 Interaction with
non-standard features](#width-compat).

### 1.2. Value Definitions

Tests

This section does not introduce any new normative requirement, it does
not need tests.

------------------------------------------------------------------------

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

## 2. Scrollbar Colors: the [scrollbar-color property]
Tests

This section has partial test coverage. Missing: \* Tests checking that
the property does anything \* Tests checking that the colors apply to
the right parts \* Initial value

------------------------------------------------------------------------

The following tests have no basis in the spec: they assume that making
the thumb and the track transparent must make the whole scollbar
invisible. This is not necessarily true: \* the scrollbar may have other
parts, such as scroll up/down/left/right buttons \* the spec does not
require that the thumb / track are painted solid with the specified
colors

- [scrollbar-color-012.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-012.html "css/css-scrollbars/scrollbar-color-012.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-012.html)
- [transparent-on-root.html](https://wpt.fyi/results/css/css-scrollbars/transparent-on-root.html "css/css-scrollbars/transparent-on-root.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/transparent-on-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/transparent-on-root.html)

------------------------------------------------------------------------

Name:

[scrollbar-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)[{2}](https://drafts.csswg.org/css-values-4/#mult-num)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword or two computed colors

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Tests

- [inheritance.html](https://wpt.fyi/results/css/css-scrollbars/inheritance.html "css/css-scrollbars/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/inheritance.html)
- [scrollbar-color-parsing.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-parsing.html "css/css-scrollbars/scrollbar-color-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-parsing.html)

<!-- -->

- [scrollbar-interpolation.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/scrollbar-interpolation.html "web-animations/animation-model/animation-types/scrollbar-interpolation.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/scrollbar-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/scrollbar-interpolation.html)
- [interpolation-per-property-002.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/interpolation-per-property-002.html "web-animations/animation-model/animation-types/interpolation-per-property-002.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/interpolation-per-property-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/interpolation-per-property-002.html)
- [addition-per-property-002.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/addition-per-property-002.html "web-animations/animation-model/animation-types/addition-per-property-002.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/addition-per-property-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/addition-per-property-002.html)
- [accumulation-per-property-002.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/accumulation-per-property-002.html "web-animations/animation-model/animation-types/accumulation-per-property-002.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/accumulation-per-property-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/accumulation-per-property-002.html)

This property allows the author to set colors of an element's
scrollbars.

Tests

This test useful but insufficient: it checks what the property doesn\'t
do, not what it does.

- [input-scrollbar-color.html](https://wpt.fyi/results/css/css-scrollbars/input-scrollbar-color.html "css/css-scrollbars/input-scrollbar-color.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/input-scrollbar-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/input-scrollbar-color.html)

------------------------------------------------------------------------

This test useful but insufficient: it checks that \*if\* the property
works, current-color works.

- [scrollbar-color-011.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-011.html "css/css-scrollbars/scrollbar-color-011.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-011.html)

------------------------------------------------------------------------

These tests are useful but insufficient: \*if\* the property works at
all, they check that it updates correctly.

- [scrollbar-color-dynamic-1.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-dynamic-1.html "css/css-scrollbars/scrollbar-color-dynamic-1.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-dynamic-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-dynamic-1.html)
- [scrollbar-color-dynamic-2.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-dynamic-2.html "css/css-scrollbars/scrollbar-color-dynamic-2.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-dynamic-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-dynamic-2.html)
- [scrollbar-color-dynamic-3.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-dynamic-3.html "css/css-scrollbars/scrollbar-color-dynamic-3.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-dynamic-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-dynamic-3.html)
- [scrollbar-color-dynamic-4.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-dynamic-4.html "css/css-scrollbars/scrollbar-color-dynamic-4.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-dynamic-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-dynamic-4.html)
- [scrollbar-color-dynamic-5.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-dynamic-5.html "css/css-scrollbars/scrollbar-color-dynamic-5.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-dynamic-5.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-dynamic-5.html)
- [scrollbar-color-dynamic-6.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-dynamic-6.html "css/css-scrollbars/scrollbar-color-dynamic-6.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-dynamic-6.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-dynamic-6.html)
- [scrollbar-color-dynamic-7.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-dynamic-7.html "css/css-scrollbars/scrollbar-color-dynamic-7.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-dynamic-7.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-dynamic-7.html)

------------------------------------------------------------------------

UAs must apply the scrollbar-color value set on the root element to the
viewport.

Tests

The following test about viewport propagation is useful but
insufficient; the test will pass if the property has no effect at all.
Also missing: \* tests that check the interaction with css-contain, and
in particular that that disables propagation

- [viewport-scrollbar.html](https://wpt.fyi/results/css/css-scrollbars/viewport-scrollbar.html "css/css-scrollbars/viewport-scrollbar.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/viewport-scrollbar.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/viewport-scrollbar.html)

------------------------------------------------------------------------

 Unlike
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) (and overflow-\*) properties,
scrollbar-color value set on the HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element are not propagated to the viewport.

Tests

- [viewport-scrollbar-body.html](https://wpt.fyi/results/css/css-scrollbars/viewport-scrollbar-body.html "css/css-scrollbars/viewport-scrollbar-body.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/viewport-scrollbar-body.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/viewport-scrollbar-body.html)

[auto]

: The user agent determines the colors of the scrollbar. It should
 follow platform conventions, but may adjust the colors in accordance
 with
 [color-scheme](https://drafts.csswg.org/css-color-adjust-1/#propdef-color-scheme) or other contextual information
 to better suit the page.

 Tests

 These tests check that that if the scrollbar adjusts based on the
 color scheme, then dynamic updates to the color scheme do cause an
 update of the scrollbar\'s colors.

 - [scrollbar-color-scheme-dynamic-1.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-scheme-dynamic-1.html "css/css-scrollbars/scrollbar-color-scheme-dynamic-1.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-scheme-dynamic-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-scheme-dynamic-1.html)
 - [scrollbar-color-scheme-dynamic-2.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-scheme-dynamic-2.html "css/css-scrollbars/scrollbar-color-scheme-dynamic-2.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-scheme-dynamic-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-scheme-dynamic-2.html)
 - [scrollbar-color-scheme-dynamic-3.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-scheme-dynamic-3.html "css/css-scrollbars/scrollbar-color-scheme-dynamic-3.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-scheme-dynamic-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-scheme-dynamic-3.html)
 - [scrollbar-color-scheme-dynamic-4.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-scheme-dynamic-4.html "css/css-scrollbars/scrollbar-color-scheme-dynamic-4.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-scheme-dynamic-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-scheme-dynamic-4.html)

 ------------------------------------------------------------------------

[[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)]
: The user agent should use the specified colors to adjust the
 rendering of the element's scollbars, if any, applying the first
 color to the [thumb](#thumb) of the
 scrollbar, and the second color to the
 [track](#track) of the scrollbar.

The [track] refers
to the background of the scrollbar, which is generally fixed regardless
of the scrolling position.

The [thumb] refers
to the moving part of the scrollbar, which usually floats on top of the
[track](#track).

Some scrollbars also include additional controls, refered to as
[buttons], which
usually sit at the top or bottom of the scrollbar on top of the
[track](#track). This specification
does not define whether and how buttons---​if present---​are colored.

![Anatomy of a
scrollbar](images/parts.svg){a
height="129" width="270"}

If this property computes to a value other than
[auto](#valdef-scrollbar-color-auto), implementations may render a simpler scrollbar
than the default platform UI rendering, and color it accordingly.

 Sometimes the UA is unable to customize the colors of
native scrollbars, perhaps due to how they're structured, or to a lack
of control given by the native toolkit. The provision above allows the
UA to replace them with differently-constructed scrollbars, which it
does know how to color.

 User agents are expected to use the color in the
rendering of the scrollbar, but that does not imply they need to paint
the entire thumb or track with a single solid featureless color. The
specified color can be used as a tint for part of the component, lighter
or darker shades of the color can be used for highlights, shadows,
texture...

The following image represents a possible
rendition of a scrollbar given the following css:

``` highlight
scrollbar-color: #8eb0dc #d2d4d6;
```

This specific design is not only that single shade of blue over that
single shade of gray: the [thumb](#thumb) has a subtle vertical gradient going from a lighter
shade at the top to a slightly darker shade at the bottom, darker
notches in the middle, as well as a darker outline, all derived from the
specified shade of blue; the light gray [track](#track) has a darker outline. This design also happens to
include [buttons](#buttons).

![A horizontal scrollbar with a textured, shaded and outlined blue
thumb, over a light gray track which is itself outlined, and flanked by
two \'scroll left\' and \'scroll right\' buttons, as was commonly seen
in scrollbar designs of the early
2000s](images/non-flat-bar.png){height="17" width="318"}

Nevertheless, authors cannot assume that this will necessarily be the
case, as on a different platform or a different user agent the rendering
could be a solid color [thumb](#thumb)
over a solid color [track](#track), as
seen below.

![A horizontal scrollbar with a blue featureless rounded rectangle as a
thumb over a featureless light gray track, as was commonly seen in
scrollbar designs of the early 2020s](images/flat-bar.png){height="15"
width="318"}

Implementations may ignore any of the colors if the corresponding part
do not exist on the underlying platform.

When using
[scrollbar-color](#propdef-scrollbar-color) property with specific color
values, authors should ensure the specified colors have enough contrast
between them. For the
[auto](#valdef-scrollbar-color-auto) value, UAs should ensure the colors they use
have enough contrast. See [WCAG 2.1 SC 1.4.11 Non-text
Contrast](https://www.w3.org/TR/WCAG21/#non-text-contrast)
[\[WCAG21\]](#biblio-wcag21 "Web Content Accessibility Guidelines (WCAG) 2.1").
UAs may ignore these contrast requirements based on explicit user
preferences (for example, when users choose a configuration
option/setting that always ensures a particular scrollbar color / use of
system default scrollbars).

 Implementations can take advantage of the fact that
they have full discretion in how to apply the specified colors in order
to visually respond to user interactions with the scrollbar (e.g.
hovering or activating): they could alter which scrollbar parts the
specified colors apply to, use darker or lighter shades of the specified
colors, more or less saturated variants...

If the user agent displays the scrollbar without the
[track](#track), they must ensure
reasonable contrast between the [thumb](#thumb) and what is behind it. However, if the author set the
color of the [track] to be fully transparent, the user
agent may assume that the author has provided for sufficient contrast
even with an invisible track.

 This is typically relevant in the case of [overlay
scrollbars](https://drafts.csswg.org/css-overflow-3/#overlay-scrollbars), either on platforms where the
[track](#track) is never displayed, or
on platforms where it is only displayed when the scrollbar is being
interacted with but not when scrolling with the mouse wheel or the
track-pad. This does not apply in cases where the entire scrollbar is
hidden as is often the case with [overlay
scrollbars] while no scroll operation is
ongoing *and* when the scrollbar is not being interacted with either.

Note: The user agent is free to achieve this by any of a variety of
means, depending on the platform, on design choices, or on what is
practical to implement, such as:

- Doing nothing if it can determine that contrast is already sufficient

- Doing nothing if the design and geometry of the thumb ensures that
 some part of it will always be visible regardless of what is behind it

- Adding an outline, shadow, or glow around the
 [thumb](#thumb) to provide contrast
 (possibly using the [track](#track)
 color as the contrasting color, or possibly using a different shade of
 the [thumb] color)

- Adding some texture or geometry to the [thumb](#thumb) so that it's color isn't uniform

- Drawing the [track](#track) anyway in
 cases where not doing so yields insufficient contrast

- Replacing the [thumb](#thumb) color
 with the [track](#track) color when
 that provides better contrast

- Altering the luminosity of the specified
 [thumb](#thumb) color while
 preserving its hue

- Disregarding the specified [thumb](#thumb) color altogether and use automatically determined
 alternative

### 2.1. Interaction with non-standard features

On any element or
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) where the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
[scrollbar-color](#propdef-scrollbar-color) is anything other than the initial
[auto](#valdef-scrollbar-color-auto) value, user agents must ignore any alternative
non-standard means for authors to influence the rendering of scrollbars,
[such as the [::webkit-scrollbar] family of
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element)].

Tests

- [scrollbar-color-001.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-001.html "css/css-scrollbars/scrollbar-color-001.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-001.html)
- [scrollbar-color-002.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-002.html "css/css-scrollbars/scrollbar-color-002.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-002.html)
- [scrollbar-color-003.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-003.html "css/css-scrollbars/scrollbar-color-003.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-003.html)
- [scrollbar-color-004.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-004.html "css/css-scrollbars/scrollbar-color-004.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-004.html)
- [scrollbar-color-005.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-005.html "css/css-scrollbars/scrollbar-color-005.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-005.html)
- [scrollbar-color-006.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-006.html "css/css-scrollbars/scrollbar-color-006.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-006.html)
- [scrollbar-color-007.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-007.html "css/css-scrollbars/scrollbar-color-007.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-007.html)
- [scrollbar-color-008.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-008.html "css/css-scrollbars/scrollbar-color-008.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-008.html)
- [scrollbar-color-009.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-009.html "css/css-scrollbars/scrollbar-color-009.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-009.html)
- [scrollbar-color-010.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-010.html "css/css-scrollbars/scrollbar-color-010.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-010.html)
- [scrollbar-color-dynamic-8.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-color-dynamic-8.html "css/css-scrollbars/scrollbar-color-dynamic-8.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-color-dynamic-8.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-color-dynamic-8.html)

## 3. Scrollbar Thickness: the [scrollbar-width property]
Tests

This section has partial test coverage. Missing: \* Test that thin does
something different from auto in at least some cases \* Test that none
does not affect scrollability \* Initial value

------------------------------------------------------------------------

Name:

[scrollbar-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) thin [\|] none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Tests

- [inheritance.html](https://wpt.fyi/results/css/css-scrollbars/inheritance.html "css/css-scrollbars/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/inheritance.html)
- [scrollbar-width-parsing.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-parsing.html "css/css-scrollbars/scrollbar-width-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-parsing.html)
- [textarea-scrollbar-width-none.html](https://wpt.fyi/results/css/css-scrollbars/textarea-scrollbar-width-none.html "css/css-scrollbars/textarea-scrollbar-width-none.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/textarea-scrollbar-width-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/textarea-scrollbar-width-none.html)

<!-- -->

- [interpolation-per-property-002.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/interpolation-per-property-002.html "web-animations/animation-model/animation-types/interpolation-per-property-002.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/interpolation-per-property-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/interpolation-per-property-002.html)
- [addition-per-property-002.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/addition-per-property-002.html "web-animations/animation-model/animation-types/addition-per-property-002.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/addition-per-property-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/addition-per-property-002.html)
- [accumulation-per-property-002.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/accumulation-per-property-002.html "web-animations/animation-model/animation-types/accumulation-per-property-002.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/accumulation-per-property-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/accumulation-per-property-002.html)

This property allows the author to specify the desired thickness of an
element's scrollbars.

Tests

- [scrollbar-width-paint-001.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-paint-001.html "css/css-scrollbars/scrollbar-width-paint-001.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-paint-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-paint-001.html)
- [scrollbar-width-paint-002.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-paint-002.html "css/css-scrollbars/scrollbar-width-paint-002.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-paint-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-paint-002.html)
- [scrollbar-width-paint-003.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-paint-003.html "css/css-scrollbars/scrollbar-width-paint-003.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-paint-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-paint-003.html)
- [scrollbar-width-paint-004.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-paint-004.html "css/css-scrollbars/scrollbar-width-paint-004.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-paint-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-paint-004.html)
- [scrollbar-width-paint-005.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-paint-005.html "css/css-scrollbars/scrollbar-width-paint-005.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-paint-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-paint-005.html)
- [scrollbar-width-paint-006.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-paint-006.html "css/css-scrollbars/scrollbar-width-paint-006.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-paint-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-paint-006.html)

The primary purpose of this property is not to allow authors to choose a
particular scrollbar aesthetic for their pages, but to let them indicate
for certain small or cramped elements of their pages that a smaller
scrollbar would be desirable.

Scrollbars are a UI mechanism essential to interact with the page.
Operating systems tend to want consistency in such controls to improve
usability through familiarity, and users with specific preferences or
needs can adjust the appearance of various UI components, including
scrollbars, through OS or UA settings.

While using this property in support of specific UX goals is
appropriate, authors should otherwise refrain from overriding such user
preferences.

[auto]

: Implementations must use the default scrollbar width.

 On most systems, this corresponds to the
 traditional somewhat wide scrollbar. However, through OS or UA
 settings, users can have the ability to change what this default
 corresponds to, possibly making the default scrollbar wider or
 narrower than is typical.

[thin]

: Implementations should use thinner scrollbars than
 [auto](#valdef-scrollbar-width-auto). This may mean a thin variant of scrollbar
 provided by the platform, or a custom scrollbar thinner than the
 default platform scrollbar. The scrollbar must nonetheless remain
 wide enough to be usable. (Implementers may wish to consult [WCAG
 2.1 SC 2.5.5 Target
 Size](https://www.w3.org/TR/WCAG21/#target-size).
 [\[WCAG21\]](#biblio-wcag21 "Web Content Accessibility Guidelines (WCAG) 2.1"))

 Tests

 - [scrollbar-width-keywords.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-keywords.html "css/css-scrollbars/scrollbar-width-keywords.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-keywords.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-keywords.html)
 - [scrollbar-width-001.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-001.html "css/css-scrollbars/scrollbar-width-001.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-001.html)
 - [scrollbar-width-002.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-002.html "css/css-scrollbars/scrollbar-width-002.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-002.html)
 - [scrollbar-width-003.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-003.html "css/css-scrollbars/scrollbar-width-003.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-003.html)
 - [scrollbar-width-004.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-004.html "css/css-scrollbars/scrollbar-width-004.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-004.html)

 User agents can use various strategies to ensure
 the usability of narrow scrollbars. For instance, in the case of
 [overlay
 scrollbars](https://drafts.csswg.org/css-overflow-3/#overlay-scrollbars), they can dynamically enlarge the scrollbar in
 response to a user attempting to interact with it. User agents on
 devices with touch screens can also adjust how they interpret finger
 taps to facilitate interacting with visually small touch targets.

 User agents may disregard this value and treat it as
 [auto](#valdef-scrollbar-width-auto), for instance when the user has indicated
 discomfort for thin scrollbars through some UA or OS setting. (User
 agents are encouraged to provide such a setting.)

 Some platforms only have a tiny scrollbar by
 default which cannot be reasonably made thinner. In such cases, this
 value will behave as
 [auto](#valdef-scrollbar-width-auto).

[none]

: Implementations must not display any scrollbar, however the
 element's scrollability by other means is not affected.

 Tests

 - [textarea-scrollbar-width-none.html](https://wpt.fyi/results/css/css-scrollbars/textarea-scrollbar-width-none.html "css/css-scrollbars/textarea-scrollbar-width-none.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/textarea-scrollbar-width-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/textarea-scrollbar-width-none.html)
 - [scrollbar-width-keywords.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-keywords.html "css/css-scrollbars/scrollbar-width-keywords.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-keywords.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-keywords.html)
 - [scrollbar-width-001.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-001.html "css/css-scrollbars/scrollbar-width-001.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-001.html)
 - [scrollbar-width-002.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-002.html "css/css-scrollbars/scrollbar-width-002.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-002.html)
 - [scrollbar-width-003.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-003.html "css/css-scrollbars/scrollbar-width-003.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-003.html)
 - [scrollbar-width-004.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-004.html "css/css-scrollbars/scrollbar-width-004.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-004.html)
 - [scrollbar-width-007.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-007.html "css/css-scrollbars/scrollbar-width-007.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-007.html)

 ::: advisement
 Using this value can prevent mouse-only users from being able to
 scroll. Authors should ensure that mouse-only users can still reach
 hidden content, even if they have no scrollwheel.
 :::

 ::: advisement
 Authors that use
 [none](#valdef-scrollbar-width-none) should provide an alternative/equivalent
 visual hint that scrolling is possible and there is more content.
 :::

 For situations where an element is to be scrolled
 *only* by programmatic means, and not by direct user manipulation,
 [overflow:
 hidden](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) is appropriate, not [scrollbar-width:
 none](#propdef-scrollbar-width).

Note: Users who find the
[thin](#valdef-scrollbar-width-thin) style of scrollbars unusable can include the
following rule in their [user style
sheet](https://drafts.csswg.org/css-cascade-5/#cascade-origin-user):

```
* { scrollbar-width: auto !important; }
```

This will ensure that all scrollbars are sized as per OS and UA settings
regardless of author styles.

UAs must apply the
[scrollbar-width](#propdef-scrollbar-width) value set on the root element to
the viewport.

Tests

- [scrollbar-width-005.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-005.html "css/css-scrollbars/scrollbar-width-005.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-005.html)
- [scrollbar-width-006.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-006.html "css/css-scrollbars/scrollbar-width-006.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-006.html)
- [scrollbar-width-007.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-007.html "css/css-scrollbars/scrollbar-width-007.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-007.html)

 Unlike the
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) property (and its longhands), a
[scrollbar-width](#propdef-scrollbar-width) value set on the HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element is not propagated to the viewport.

Tests

- [scrollbar-width-008.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-008.html "css/css-scrollbars/scrollbar-width-008.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-008.html)
- [scrollbar-width-009.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-009.html "css/css-scrollbars/scrollbar-width-009.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-009.html)

 This specification does not define the exact position
or shape of the scrollbar, or any animation thereof, such as fading or
sliding in/out of view.

### 3.1. Interaction with non-standard features

On any element or
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) where the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
[scrollbar-width](#propdef-scrollbar-width) is anything other than the initial
[auto](#valdef-scrollbar-width-auto) value, user agents must ignore any alternative
non-standard means for authors to influence the rendering of scrollbars,
[such as the [::webkit-scrollbar] family of
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element)].

Tests

- [scrollbar-width-010.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-010.html "css/css-scrollbars/scrollbar-width-010.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-010.html)
- [scrollbar-width-011.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-011.html "css/css-scrollbars/scrollbar-width-011.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-011.html)
- [scrollbar-width-012.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-012.html "css/css-scrollbars/scrollbar-width-012.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-012.html)
- [scrollbar-width-013.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-013.html "css/css-scrollbars/scrollbar-width-013.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-013.html)
- [scrollbar-width-014.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-014.html "css/css-scrollbars/scrollbar-width-014.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-014.html)
- [scrollbar-width-015.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-015.html "css/css-scrollbars/scrollbar-width-015.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-015.html)
- [scrollbar-width-016.html](https://wpt.fyi/results/css/css-scrollbars/scrollbar-width-016.html "css/css-scrollbars/scrollbar-width-016.html")
 [[(live
 test)]](http://wpt.live/css/css-scrollbars/scrollbar-width-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-scrollbars/scrollbar-width-016.html)

## [ Appendix A. Acknowledgments]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

This appendix is *non-normative*.

The CSS Working Group and the Editors of this specification would like
to express our gratitude to the following people, as this specification
would not have been possible without their feedback and contributions:
Chris Lilley, Emilio Cobos Álvarez, Eric Shepherd, Eric Willigers,
fantasai, Greg Whitworth, jonjohnjohnson, L. David Baron, Luke Warlow,
Oriol Brufau, Patrick H. Lauke, Rene Haas, Rick Byers, Simon Fraser, Tab
Atkins Jr., Xidorn Quan.

In particular, thanks for the use-cases, prototyping, implementation,
and feedback from [Tab Atkins](https://xanthir.com/) and
[Xidorn Quan](https://www.upsuper.org/). Thanks for
accessibility review and contributions
([#3315](https://github.com/w3c/csswg-drafts/issues/3315)) from [Patrick
H. Lauke](https://www.splintered.co.uk).

## [ Appendix B. Changes]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

This appendix is *non-normative*.

### [ Changes since the [9 December 2021 Candidate Recommendation](https://www.w3.org/TR/2021/CR-css-scrollbars-1-20211200/)]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

- Switched the Animation type of
 [scrollbar-width](#propdef-scrollbar-width) to
 [discrete](https://drafts.csswg.org/web-animations-1/#discrete), reflecting the fact that this property only takes
 keyword values.

### [ Changes since the [2021-12-02 Working Draft](https://www.w3.org/TR/css-scrollbars-1/)]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

- Boilerplate changes for CR

### [ Changes from the [2021-08-05 Working Draft](https://www.w3.org/TR/2021/WD-css-scrollbars-1-20210805/)]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

- Switched \"should\" to a \"must\" with regards to accessibility of
 narrow scrollbars. (see [Issue
 6675](https://github.com/w3c/csswg-drafts/issues/6675))

### [ Changes from the [2018-09-25 First Public Working Draft](https://www.w3.org/TR/2018/WD-css-scrollbars-1-20180925/)]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

- [#6538](https://github.com/w3c/csswg-drafts/issues/6438): removed
 [light] and [dark] values of
 [scrollbar-color](#propdef-scrollbar-color) in favor of allowing the UA to
 tune
 [auto](#valdef-scrollbar-color-auto) in accordance with
 [color-scheme](https://drafts.csswg.org/css-color-adjust-1/#propdef-color-scheme) or other contextual information.
- [#3237](https://github.com/w3c/csswg-drafts/issues/3237):
 scrollbar-color computed value changed to: specified keyword or two
 computed colors
- [#4693](https://github.com/w3c/csswg-drafts/issues/4693): Clarified
 scope: styling scrollbar controls themselves, no layout or
 scrollability.
- [#3315](https://github.com/w3c/csswg-drafts/issues/3315): More and
 updated accessibility considerations for scrollbar-color and
 scrollbar-width.

## [ Appendix C. Security and Privacy]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

This appendix is *non-normative*.

### [ Considerations for Security]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

No specific concerns regarding security have been identified for this
specification.

### [ Considerations for Privacy]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

No specific concerns regarding privacy have been identified for this
specification.

### [ Self-review questionnaire]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

Per the [Self-Review Questionnaire: Security and Privacy: Questions to
Consider](https://www.w3.org/TR/security-privacy-questionnaire/#questions)

1. Does this specification deal with personally-identifiable
 information?

 No.

2. Does this specification deal with high-value data?

 No.

3. Does this specification introduce new state for an origin that
 persists across browsing sessions?

 No.

4. Does this specification expose persistent, cross-origin state to the
 web?

 No.

5. Does this specification expose any other data to an origin that it
 doesn't currently have access to?

 No.

6. Does this specification enable new script execution/loading
 mechanisms?

 No.

7. Does this specification allow an origin access to a user's location?

 No.

8. Does this specification allow an origin access to sensors on a
 user's device?

 No.

9. Does this specification allow an origin access to aspects of a
 user's local computing environment?

 No.

10. Does this specification allow an origin access to other devices?

 No.

11. Does this specification allow an origin some measure of control over
 a user agent's native UI?

 Yes. The [scrollbar-\*] properties enable the page to change
 the color and width of the scrollbar of the user agent's native UI,
 e.g. scrollbars on the page's window, on framed content embedded in
 the page, or on overflowing elements with scrollbars in the page.

12. Does this specification expose temporary identifiers to the web?

 No.

13. Does this specification distinguish between behavior in first-party
 and third-party contexts?

 No.

14. How should this specification work in the context of a user agent's
 \"incognito\" mode?

 No differently.

15. Does this specification persist data to a user's local device?

 No.

16. Does this specification have a \"Security Considerations\" and
 \"Privacy Considerations\" section?

 Yes.

17. Does this specification allow downgrading default security
 characteristics?

 No.

## [ Appendix D. Considerations for accessibility]
Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

This appendix is *non-normative*.

As noted [in the definition of the property](#scrollbar-width), authors
need to be mindful of the accessibility implications of using
[scrollbar-width:
thin](#propdef-scrollbar-width). Scrollbars are a important piece of the user
agent's interface, and it is not appropriate for a web site author to
change their size over aesthetic considerations. The property is
available to support cases where the author wants to indicate that in a
cramped area of the web page a thin scrollbar would be a more effective
use of space. However, ultimately, the user, through their user agent,
needs to have the last word on such things.

Using this property in such cases is preferable to authors building a
custom thin-looking scrollbar in via script or proprietary extensions,
because it does give the user the opportunity to override it.

[User style
sheets](https://drafts.csswg.org/css-cascade-5/#cascade-origin-user) do provide such an override, and additionally, user
agents are encouraged to expose a setting letting users express that
they do not want thin scrollbars to be used.

The CSS Working Group also acknowledges the needs of some users to have
scrollbars that are wider than is typical. Operating systems and user
agents can offer a means to let users express that preference, and in
such cases, CSS will honor that choice.
