## 1. Introduction

Modern CSS renderers perform a number of complex optimizations in order
to render webpages quickly and efficiently. Unfortunately, employing
these optimizations often has a non-trivial start-up cost, which can
have a negative impact on the responsiveness of a page.

For example, when using CSS 3D
Transforms to move an element around the screen, the element and its
contents might be promoted to a "layer", where they can render
independently from the rest of the page and be composited in later. This
isolates the rendering of the content so that the rest of the page
doesn't have to be rerendered if the element's transform is the only
thing that changes between frames, and often provides significant speed
benefits.

However, setting up the element in a fresh layer is a relatively
expensive operation, which can delay the start of a
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) animation by a noticeable fraction
of a second.

The [will-change](#propdef-will-change) property defined in this
specification allows an author to declare ahead-of-time what properties
are likely to change in the future, so the UA can set up the appropriate
optimizations some time before they're needed. This way, when the actual
change happens, the page updates in a snappy manner.

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

### 1.2. Using [will-change Well]
The [will-change](#propdef-will-change) property, like all performance
hints, can be somewhat difficult to learn how to use "properly",
particularly since it has very little, if any, effect an author can
directly detect. However, there are several simple "Dos and Don'ts"
which hopefully will help develop a good intuition about how to use
[will-change] well.

#### [ Don't Spam [will-change](#propdef-will-change) Across Too Many Properties or Elements]
A common initial response to seeing
[will-change](#propdef-will-change) is to assume that code like this is a
good idea:

 * { will-change: transform, opacity /* , ... */; }

After all, this tells the browser to go ahead and optimize everything,
which has to be good right?

Wrong. The browser *already* tries as hard as it can to optimize
everything. Telling it to do so explicitly doesn't help anything, and in
fact has the capacity to do a lot of harm; some of the stronger
optimizations that are likely to be tied to
[will-change](#propdef-will-change) end up using a lot of a machine's
resources, and when overused like this can cause the page to slow down
or even crash.

In addition,
[will-change](#propdef-will-change) does have **some** side-effects, and
it's very unlikely that pages actually want all those side-effects on
every element.

#### [ Use [will-change](#propdef-will-change) Sparingly In Stylesheets]
Using [will-change](#propdef-will-change) directly in a stylesheet implies
that the targeted elements are always a few moments away from changing.
This is *usually* not what you actually mean; instead,
[will-change] should usually
be flipped on and off via scripting before and after the change occurs
(see [Don't Waste Resources On Elements That Have Stopped
Changing](#dont-waste)). However, there are some common circumstances in
which it is appropriate to use
[will-change] directly in a
stylesheet.

For example, specifying
[will-change](#propdef-will-change) for a small number of persistent UI
elements in a page which should react snappily to the user is
appropriate:

 body > .sidebar {
 will-change: transform;
 /* Will use 'transform' to slide it out
 when the user requests. */
 }

Because this is limited to a small number of elements, the fact that the
optimization is rarely actually used doesn't hurt very much.

Sometimes an element really *does*
change a property nearly constantly. Perhaps it responds to the user's
mouse movements, or just regularly takes some action that causes an
animation. In this case, just declaring the
[will-change](#propdef-will-change) value in the stylesheet is fine, as it
accurately describes that the element will regularly/constantly change,
and so should be kept optimized.

 .cats-flying-around-the-screen {
 will-change: left, top;
 }

#### [ Give [will-change](#propdef-will-change) Sufficient Time To Work]
Another common bad pattern is to apply
[will-change](#propdef-will-change) to an element *immediately* before
starting the animation or property change that it's meant to help with.
Unfortunately, most of those optimizations need time to be applied, and
so they don't have enough time to set-up when this is done, and the
[will-change] has little to no
effect. Instead, find some way to predict at least slightly ahead of
time that something will change, and set
[will-change] *then*.

For example, if an element is going to
change when a user clicks on it, setting
[will-change](#propdef-will-change) on hover will usually give at least 200
milliseconds for the optimizations to be set up, as human reaction time
is relatively slow. This can be done either via scripting, or rather
simply with a CSS rule:

 .element { transition: opacity .2s; opacity: 1; }
 .element:hover { will-change: opacity; }
 .element:active { opacity: .3; }

However, a rule like that is useless if the effect is going to happen on
hover. In cases like these, it is often still possible to find some way
to predict the action before it occurs. For example, hovering an
ancestor may give enough lead time:

 .element { transition: opacity .2s; opacity: 1; }
 .container:hover > .element { will-change: opacity; }
 .element:hover { opacity: .3; }

#### [ Don't Waste Resources On Elements That Have Stopped Changing]
Because the optimizations browsers use for changing some properties are
expensive, browsers remove them and revert to normal behavior as soon as
they can in normal circumstances. However,
[will-change](#propdef-will-change) will generally override this behavior,
maintaining the optimizations for much longer than the browser would
otherwise do.

As such, whenever you add
[will-change](#propdef-will-change) to an element, especially via scripting,
don't forget to *remove* it after the element is done changing, so the
browser can recover whatever resources the optimizations are claiming.

## 2. Hinting at Future Behavior: the [will-change property]
Name:

[will-change]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<animateable-feature\>](#typedef-animateable-feature)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

``` prod
<animateable-feature> = scroll-position | contents | <custom-ident>
```

The [will-change](#propdef-will-change) property provides a rendering hint
to the user agent, stating what kinds of changes the author expects to
perform on the element. This allows the user agent to perform
ahead-of-time any optimizations necessary for rendering those changes
smoothly, avoiding "jank" when the author does begin changing or
animating that feature.

Different browsers can use the information from
[will-change](#propdef-will-change) in different ways, and even a single
browser might use it in different ways at different time. For example, a
browser that promotes elements to their own "GPU layer" when they have
[will-change: transform] specified
might avoid doing that when there are *too many* elements declaring
that, to avoid exhausting GPU memory.

Values have the following meanings:

[auto]
: Expresses no particular intent; the user agent should apply whatever
 heuristics and optimizations it normally does.

[scroll-position]

: Indicates that the author expects to animate or change the scroll
 position of the element in the near future.

 (#example-c0594e8a) For example, browsers often only
 render the content in the \"scroll window\" on a scrollable element,
 and some of the content past that window, balancing memory and time
 savings from the skipped rendering against making scrolling look
 nice. A browser might take this value as a signal to expand the
 range of content around the scroll window that is rendered, so that
 longer/faster scrolls can be done smoothly.

[contents]

: Indicates that the author expects to animate or change something
 about the element's contents in the near future.

 :::
 (#example-5dd10a2f) For example, browsers often
 "cache" rendering of elements over time, because most things don't
 change very often, or only change their position. However, if an
 element *does* change its contents continually, producing and
 maintaining this cache is a waste of time. A browser might take this
 value as a signal to cache less aggressively on the element, or
 avoid caching at all and just continually re-render the element from
 scratch.
 This value is mostly intended to help browsers optimize JS-based
 animations of content, which change aspects of an element's contents
 many times per second. This kind of optimization, when possible, is
 already done automatically by browsers when declarative animations
 are used.
 :::

 This value more-or-less applies to the entire
 subtree of the element its declared on, as it indicates the browser
 should count on \*any\* of the descendants changing in some way.
 Using this on an element "high up" in your document might be very
 bad for your page's performance; try to only use this on elements
 near the "bottom" of your document tree, containing as little of the
 document as possible.

[[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)]

: If the
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the name of a built-in CSS property, it
 indicates that the author expects to animate or change the property
 with the given name on the element in the near future. If the
 property given is a shorthand, it indicates the expectation for all
 the longhands the shorthand expands to.

 (#example-03a1e696) For example, setting [will-change:
 background;](#propdef-will-change) is identical to setting [will-change:
 background-image, background-position,
 \...] for all the properties
 that
 [background](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) expands into.

 The
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) production used here excludes the
 keywords [will-change], [none], [all],
 [auto](#valdef-will-change-auto),
 [scroll-position](#valdef-will-change-scroll-position), and
 [contents](#valdef-will-change-contents), in addition to the keywords normally
 excluded from [\<custom-ident\>].

 Note that most properties will have no effect when
 specified, as the user agent doesn't perform any special
 optimizations for changes in most properties. It is still *safe* to
 specify them, though; it'll simply have no effect.

 Specifying a custom property must have no effect, which means that
 effects that happen through custom properties do not count for the
 rules below that are conditioned on any non-initial value of a
 property causing something.

 Specifying a value that's not recognized as a
 property is fine; it simply has no effect. This allows you to safely
 specify *new* properties that exist in some user agents without
 negatively affecting down-level user agents that don't know about
 that property.

 (#example-7225dcbc) For example, browsers often handle
 elements with
 [transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) set to a non-initial value very
 differently from normal elements, perhaps rendering them to their
 own "GPU layer" or using other mechanisms to make it easier to
 quickly make the sort of transformations that
 [transform] can produce. A
 browser might take a value of
 [transform] as a signal that
 it should go ahead and promote the element to its own layer
 immediately, before the element starts to be transformed, to avoid
 any delay involved in rerendering the old and new layers.

 If any non-initial value of a property would create a stacking
 context on the element, specifying that property in
 [will-change](#propdef-will-change) must create a stacking context
 on the element.

 If any non-initial value of a property would cause the element to
 generate a containing block for absolutely positioned elements,
 specifying that property in
 [will-change](#propdef-will-change) must cause the element to
 generate a containing block for absolutely positioned elements.

 If any non-initial value of a property would cause the element to
 generate a containing block for fixed positioned elements,
 specifying that property in
 [will-change](#propdef-will-change) must cause the element to
 generate a containing block for fixed positioned elements.

 If any non-initial value of a property would cause rendering
 differences on the element (such as using a different anti-aliasing
 strategy for text), the user agent should use that alternate
 rendering when the property is specified in
 [will-change](#propdef-will-change), to avoid sudden rendering
 differences when the property is eventually changed.

 (#example-e1300843) For example, setting
 [opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity) to any value other than
 [1] creates a stacking context on the element. Thus, setting
 [will-change:
 opacity](#propdef-will-change) also creates a stacking context, even if
 [opacity] is *currently* still
 equal to [1].

The [will-change](#propdef-will-change) property has no *direct* effect on
the element it is specified on, beyond the creation of stacking contexts
and containing blocks as specified above. It is solely a rendering hint
to the user agent, allowing it set up potentially-expensive
optimizations for certain types of changes before the changes actually
start occurring.

## 3. Security Considerations

No Security concerns have been raised against this document

## 4. Privacy Considerations

No Privacy concerns have been raised against this document

## 5. Acknowledgements

Thanks to Benoit Girard for originally suggesting the
[will-animate] property, and doing a lot of the initial design
work.

## 6. Changes

Since the [03 December 2015
CR](http://www.w3.org/TR/2015/CR-css-will-change-1-20151203/):

- Added Security and Privacy sections

- Clarified that unknown values are fine, and have no effect

- Specified that ASCII Case-Insensitive matching is used against
 property names

- Changed the animation type of the will-change property to not
 animatable

- Dropped the \"Media:\" entry from propdef tables, as with other CSS
 specifications

- Minor editorial clarifications, markup improvements

Since the [April 29 2014 Working
Draft](https://www.w3.org/TR/2014/WD-css-will-change-1-20140429/):

- Added an explanatory section giving guidance on how to use
 [will-change](#propdef-will-change) well.

- Specified the behavior of shorthands
