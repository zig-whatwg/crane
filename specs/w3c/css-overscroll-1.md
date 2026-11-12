## 1. Introduction

*This section is not normative.*

A content author does not necessarily want [scroll
chaining](#scroll-chaining) to
occur for all [scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container). Some [scroll containers]
may be part of a [containing block
chain](https://drafts.csswg.org/css-display-4/#containing-block-chain) but may serve a different logical purpose in the
document and may want to prevent scrolling from continuing up the
[scroll chain](#scroll-chain). To
achieve this, a content author will install event listeners without the
[passive flag] set and will use
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) when there is a risk that scroll chaining will occur.
This is detrimental for the following reasons:

- The user agent may in the future introduce new input methods for
 scrolling that are not supported by the content author's event
 listeners.

- A non passive event listener will delay scrolling because the user
 agent will have to wait for the result of the event listener to
 determine if
 [`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) was called causing increased scroll latency.

- When scrolling is performed near the edge of the [scroll
 boundary](#scroll-boundary),
 the [default
 action](https://w3c.github.io/uievents/#default-action) may cause both scrolling to the edge of the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) and a [boundary default
 action](#boundary-default-action). Calling
 [`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) will not only cancel the [boundary default
 action] but also the scroll to the
 edge of the
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport).

- The [default
 action](https://w3c.github.io/uievents/#default-action) for the event may also provide additional behavior
 that the author does not want to cancel such as an overscroll
 affordance.
 [`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) doesn't allow the content author to cancel only some
 of the [default actions] such as scroll
 chaining.

Thus, it is not possible for a content author to control [scroll
chaining](#scroll-chaining)
and overscroll in a robust, performant and forward compatible way. The
[overscroll-behavior](#propdef-overscroll-behavior) property fixes this shortcoming.

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

## 2. Motivating Examples

A position fixed left navigation bar
does not want to hand off scrolling to the document because a scroll
gesture performed on the navigation bar is almost never meant to scroll
the document. Note that using the native overscroll affordances are
still desirable while scroll chaining is to be prevented.

```
#sidebar {
 overscroll-behavior: contain;
}
```

In this case, the author can use
[contain](#valdef-overscroll-behavior-contain) on the sidebar to prevent scrolling from being
chained to the parent document element.

A page wants to implement their own
pull-to-refresh effect and thus needs to disable browser native
overscroll action.

```
html {
 /* only disable pull-to-refresh but allow swipe navigations */
 overscroll-behavior-y: contain;
}
```

In this case, the author can use
[contain](#valdef-overscroll-behavior-contain) on the viewport defining element to prevent
overscroll from triggering navigation actions.

A infinite scrollers loads more
content as user reaches the boundary and thus wants to disable the
potentially confusing rubber banding effect in addition to scroll
chaining.

```
#infinite_scroller {
 overscroll-behavior-y: none;
}
```

In this case the author can use
[none](#valdef-overscroll-behavior-none) on the infinite scroller to prevent both scroll
chaining and overscroll affordance.

## 3. Scroll chaining and boundary default actions

*Operating Systems have rules for scrolling such as scroll chaining and
overscroll affordances. This specification does not mandate if and how
scroll chaining or overscroll affordances be implemented. This
specification only allows the content author to disable them if any are
implemented.*

[Scroll chaining] is when scrolling is propagated from one [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) to an ancestor [scroll
container] following the [scroll
chain](#scroll-chain). Typically
scroll chaining is performed starting at the event target recursing up
the [containing block
chain](https://drafts.csswg.org/css-display-4/#containing-block-chain). When a [scroll container]
in this chain receives a scroll event or gesture it may act on it and/or
pass it up the chain. Chaining typically occurs when the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) has reached its boundary.

A [scroll chain] is the order in which scrolling is propagated from one
[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) to another. For a given [scroll
container] and scroll, the next link in its
[scroll chain](#scroll-chain) is
the nearest ancestor [scroll container] in
the [containing block
chain](https://drafts.csswg.org/css-display-4/#containing-block-chain) that is scrollable in the scroll's axis. The
[viewport](https://w3c.github.io/epub-specs/epub33/core/#dfn-viewport) participates in [scroll
chaining](#scroll-chaining)
as the document's [scrollingElement], both regarding
placement in the scroll chain as well as adhering to the chaining rules
applied to it.

[Scroll boundary] refers to when the scroll position of a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) reaches the edge of the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport). If a [scroll container]
has no potential to scroll, because it does not
[overflow](https://drafts.csswg.org/css-overflow-3/#overflow) in the direction of the scroll, the element is always
considered to be at the scroll boundary. A [single-axis scroll
container](https://drafts.csswg.org/css-overflow-3/#single-axis-scroll-container) only has a [scroll
boundary](#scroll-boundary)
in its [scrollable
axis](https://drafts.csswg.org/css-overflow-3/#scrollable-axis); if the scroll is in its other axis, this element won't
be part of the [scroll chain](#scroll-chain) at all.

[Boundary default action] refers to the user-agent-defined [default
action](https://w3c.github.io/uievents/#default-action) performed when scrolling against the edge of the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport). A [local boundary default
action] is a [boundary default
action](#boundary-default-action) which is performed on the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) without interacting with the page, for example
displaying a overscroll UI affordance. Conversely, a [non-local boundary
default action] interacts with the page, for example scroll
chaining or a navigation action.

## 4. Overscroll Behavior Properties

The [overscroll behavior] controls the permitted [boundary default
action](#boundary-default-action) for a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) element when its
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) reaches the boundary of its scroll box.

The
[overscroll-behavior](#propdef-overscroll-behavior) property specifies the [overscroll
behavior](#overscroll-behavior) for a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) element. It allows the content author to specify that a
[scroll container] element must prevent
scroll chaining and/or overscroll affordances.

An element that is not [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) must accept but ignore the values of this property.
This property must be applied to all scrolling methods supported by the
user agent.

 This property should provide guarantees that are, at
least, as strong as
[preventDefault](https://www.w3.org/TR/touch-events/#dfn-preventdefault) for preventing both scroll chaining and overscroll.
Doing otherwise would cause content authors to use
[preventDefault] instead.

### 4.1. The [overscroll-behavior Shorthand]
Name:

[overscroll-behavior]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ contain
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none [\|] auto
[\|] chain
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

[per grammar]

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

The
[overscroll-behavior](#propdef-overscroll-behavior) property is a shorthand property
that sets the specified values of
[overscroll-behavior-x](#propdef-overscroll-behavior-x) and
[overscroll-behavior-y](#propdef-overscroll-behavior-y) in that order. If only one value is
specified, the second value defaults to the same value.

Values have the following meanings:

[contain]
: This value indicates that the element must not perform [non-local
 boundary default
 actions](#non-local-boundary-default-action) such as scroll chaining or navigation. The user
 agent must not perform scroll chaining to any ancestors along the
 [scroll chain](#scroll-chain) regardless of whether the scroll originated at this
 element or one of its descendants. This value must not modify the
 behavior of how [local boundary default
 actions](#local-boundary-default-action) should behave, such as showing any overscroll
 affordances.

[none]
: This value implies the same behavior as
 [contain](#valdef-overscroll-behavior-contain) and in addition this element must also not
 perform [local boundary default
 actions](#local-boundary-default-action) such as showing any overscroll affordances.

[chain]
: This value indicates that the element may perform [non-local
 boundary default
 actions](#non-local-boundary-default-action) such as scroll chaining or navigation. However, the
 element must not perform [local boundary default
 actions](#local-boundary-default-action), such as showing any overscroll affordances.

[auto]
: This value indicates that the user agent should perform the usual
 [boundary default
 action](#boundary-default-action) with respect to [scroll
 chaining](#scroll-chaining), overscroll and navigation gestures.

 In the case where a user agent does not implement
scroll chaining and overscroll affordances, these values will have no
side effects for a compliant implementation.

 Programmatic scrolling is clamped and can not trigger
any [boundary default
actions](#boundary-default-action).

### 4.2. Overscroll and Positioned Elements

This specification does not generally dictate what, if any,
\"overscroll\" or similar actions might occur as a [local boundary
default
action](#local-boundary-default-action).

However, if a user agent *does* use \"overscroll\" behavior (that is,
allowing a scrollable element to be scrolled slightly \"past the end\"
of its scrollable area, usually with a \"rubber-banding\" effect after
the scroll or drag is completed), then the following applies:

If an element uses [fixed
positioning](https://drafts.csswg.org/css-position-3/#fixed-position) and is positioned relative to the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block), or is a [sticky
positioned](https://drafts.csswg.org/css-position-3/#sticky-position) element which is currently stuck to the
[viewport](https://w3c.github.io/epub-specs/epub33/core/#dfn-viewport), then when the [root scroller] experiences
\"overscroll\", that element *must not* overscroll with the rest of the
document's content; it must instead remain positioned as if the scroller
was at its minimum/maximum scroll position, whichever it will return to
when the overscroll is finished.

Even tho this can visually shift the fixed/sticky element relative to
other elements on the page, it must be treated purely as a visual
effect, and not reported as an actual layout/position change to APIs
such as
[`getBoundingClientRect()`](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect).

 This behavior is because fixpos and viewport-stuck
stickypos elements are positioned relative to \"the viewport\", which is
conceptually above the root scroller in the page hierarchy (effectively,
it's the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) holding the root scroller). Thus, overscrolling the
root scroller shouldn't have any effect on them, just like how an abspos
that is a child of a scroller but whose abspos containing block is
*above* the scroller isn't affected by the scroller doing anything at
all, including overscroll.

### 4.3. Physical Longhands for [overscroll-behavior]
Name:

[overscroll-behavior-x],
[overscroll-behavior-y]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

contain
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none [\|] auto
[\|] chain

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

[per grammar]

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[overscroll-behavior](#propdef-overscroll-behavior)

Media:

visual

The
[overscroll-behavior-x](#propdef-overscroll-behavior-x) property specifies the [overscroll
behavior](#overscroll-behavior) in the horizontal axis and the
[overscroll-behavior-y](#propdef-overscroll-behavior-y) property specifies the [overscroll
behavior] in the vertical axis. When
scrolling is performed along both the horizontal and vertical axes at
the same time, the [overscroll behavior]
of each respective axis should be considered independently.

### 4.4. Flow-relative Longhands for [overscroll-behavior]
Name:

[overscroll-behavior-inline],
[overscroll-behavior-block]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

contain
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none [\|] auto
[\|] chain

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

[per grammar]

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[overscroll-behavior](#propdef-overscroll-behavior)

Media:

visual

These properties correspond to the
[overscroll-behavior-x](#propdef-overscroll-behavior-x) and
[overscroll-behavior-y](#propdef-overscroll-behavior-y) properties. The mapping depends on
the element's
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode).

## 5. Security Considerations

There are no known security impacts of this feature. The feature may be
used to prevent certain native UI features such as overscroll
affordances and overscroll navigations (e.g., pull- to-refresh, swipe
navigations). However, this does not expose any additional abilities
beyond what is already possible in the platform e.g., by preventing the
default action of the event that would cause a scroll.

## 6. Privacy Considerations

No new privacy considerations have been reported on this specification.
