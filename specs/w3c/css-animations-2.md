## 1. Delta specification

This is a delta specification, meaning that it currently contains only
the differences from CSS Animations Level 1
[\[CSS3-ANIMATIONS\]](#biblio-css3-animations "CSS Animations Level 1").
Once the Level 1 specification is closer to complete, it will be merged
with the additions here into a complete level 2 specification.

## 2. Animations

Changes to any of the animation properties defined in this specification
cause the corresponding
[`CSSAnimation`](#cssanimation) object and its associated objects to be updated
according to the correspondence between these properties and Web
Animations concepts defined in [§ 3 Assembling Keyframes](#keyframes).

However, if the author modifies the animation using the Web Animations
programming interface, the changes from the programming interface take
precedence as follows:

- After a successful call to
 [`setKeyframes()`](https://drafts.csswg.org/web-animations-1/#dom-keyframeeffect-setkeyframes) on the
 [`KeyframeEffect`](https://drafts.csswg.org/web-animations-1/#keyframeeffect) associated with a
 [`CSSAnimation`](#cssanimation), any subsequent change to matching
 [\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) rules or the resolved value of the
 [animation-timing-function](https://drafts.csswg.org/css-animations-1/#propdef-animation-timing-function) property for the target element
 will not be reflected in that animation.

 However, if the last matching
 [\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) rule is removed the animation must still be
 canceled.

- After a successful call to
 [`updateTiming()`](https://drafts.csswg.org/web-animations-1/#dom-animationeffect-updatetiming) on the
 [`KeyframeEffect`](https://drafts.csswg.org/web-animations-1/#keyframeeffect) associated with a
 [`CSSAnimation`](#cssanimation), for each property included in the
 [`timing`](https://drafts.csswg.org/web-animations-1/#dom-animationeffect-updatetiming-timing-timing) parameter, any subsequent change to a corresponding
 animation property will not be reflected in that animation.

 For example, calling
 `cssAnimation.effect.updateTiming({ duration: 1000 })` would cause
 subsequent changes to
 [animation-duration](#propdef-animation-duration) to be ignored whilst changes to
 [animation-delay](#propdef-animation-delay) would still be reflected in the
 [`KeyframeEffect`](https://drafts.csswg.org/web-animations-1/#keyframeeffect)'s timing.

- After a successful call to
 [`play()`](https://drafts.csswg.org/web-animations-1/#dom-animation-play) or
 [`pause()`](https://drafts.csswg.org/web-animations-1/#dom-animation-pause) on a
 [`CSSAnimation`](#cssanimation), any subsequent change to the
 [animation-play-state](https://drafts.csswg.org/css-animations-1/#propdef-animation-play-state) will no longer cause the
 [`CSSAnimation`](#cssanimation) to be played or paused as defined in [§ 4.5 The
 animation-play-state property](#animation-play-state).

- After a successful call to
 [`reverse()`](https://drafts.csswg.org/web-animations-1/#dom-animation-reverse) on a
 [`CSSAnimation`](#cssanimation) or after successfully setting the
 [`startTime`](https://drafts.csswg.org/web-animations-2/#dom-animation-starttime) on a
 [`CSSAnimation`](#cssanimation), if, as a result of that call the [play
 state](https://drafts.csswg.org/web-animations-1/#animation-play-state) of the
 [`CSSAnimation`](#cssanimation) changes to or from the
 [paused](https://drafts.csswg.org/web-animations-1/#play-state-paused) play state, any subsequent change to the
 [animation-play-state](https://drafts.csswg.org/css-animations-1/#propdef-animation-play-state) will no longer cause the
 [`CSSAnimation`](#cssanimation) to be played or paused as defined in [§ 4.5 The
 animation-play-state property](#animation-play-state).

 The requirement for a change to or from the
 [paused](https://drafts.csswg.org/web-animations-1/#play-state-paused) state ensures that even after calling
 [`reverse()`](https://drafts.csswg.org/web-animations-1/#dom-animation-reverse) or setting the
 [`startTime`](https://drafts.csswg.org/web-animations-2/#dom-animation-starttime) on a running animation, the animation continues to
 observe changes in
 [animation-play-state](https://drafts.csswg.org/css-animations-1/#propdef-animation-play-state).

- After successfully setting the
 [`effect`](https://drafts.csswg.org/web-animations-1/#dom-animation-effect) of a
 [`CSSAnimation`](#cssanimation) to `null` or some
 [`AnimationEffect`](https://drafts.csswg.org/web-animations-1/#animationeffect) other than the original
 [`KeyframeEffect`](https://drafts.csswg.org/web-animations-1/#keyframeeffect), all subsequent changes to animation properties other
 than
 [animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name),
 [animation-play-state](https://drafts.csswg.org/css-animations-1/#propdef-animation-play-state), or
 [animation-timeline](#propdef-animation-timeline) will not be reflected in that
 animation. Similarly, any change to matching
 [\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) rules will not be reflected in that animation.
 However, if the last matching
 [\@keyframes] rule is removed the
 animation must still be canceled.

[Note,] the reference to a successful call in the above rules
is necessary to ensure that when an exception is thrown by any of these
methods, the override behavior is *not* applied.

### 2.1. Owning element

The [owning element] of an animation refers to the element or pseudo-element to
which the
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) property was applied that generated
the animation.

If the
[display](https://drafts.csswg.org/css-display-4/#propdef-display) property of an element is set to
[none](https://drafts.csswg.org/css-display-4/#valdef-display-none) and its [display] value would compute to [none] when ignoring the Transitions and Animations [cascade
origins](https://drafts.csswg.org/css-cascade-6/#origin), then terminate running animations with this [owning
element](#owning-element). If
an element has a [display] of
[none] and its
[display] value had computed to
[none] when ignoring the Transitions
and Animations [cascade origins], updating
[display] to a value other than
[none] will start all animations
applied to the element by the
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) property.

 In practice, this means that an animation to a
[display](https://drafts.csswg.org/css-display-4/#propdef-display) value of
[none](https://drafts.csswg.org/css-display-4/#valdef-display-none) will not terminate running animations unless the
style also computes to [none]
without the effect of the animations.

If an animation generated using the markup defined in this specification
is later disassociated from that markup by an update to the computed
value of the
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) property on the [owning
element](#owning-element), the
animation is disassociated from its [owning
element] (that is, it has no [owning
element] from that point forwards).

In the example below, `animation`'s initial [owning
element](#owning-element) is
`elem`. `animation` is disassociated from `element` through an update to
the computed value of `elem`'s
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) property.

```
elem.style.animation = 'spin 1s';
let animation = elem.getAnimations()[0]; // animation's owning element is elem
elem.style.animation = ""; // animation no longer has an owning element
```

Note that although the [owning
element](#owning-element) is
often equal to the [target
element](https://drafts.csswg.org/web-animations-1/#effect-target-target-element) of an animation's [associated
effect](https://drafts.csswg.org/web-animations-1/#animation-associated-effect), this is not always the case. The following example
demonstrates some of the situations where these two elements may differ.

```
elem.style.animation = 'move 1s';
let animation = elem.getAnimations()[0];
// animation.effect.target == elem == animation's owning element

animation.effect.target = elem2;
// animation.effect.target == elem2 != animation's owning element

animation.effect = null;
// animation.effect?.target is undefined != animation's owning element
```

### 2.2. Animation composite order

[Animations](https://drafts.csswg.org/web-animations-1/#concept-animation) generated from the markup defined in this specification
have an [animation
class](https://drafts.csswg.org/web-animations-1/#animation-class) of 'CSS Animation'.

CSS Animations *with* an [owning
element](#owning-element) have
a *later* composite order than CSS Transitions but an *earlier*
composite order than animations without a specific [animation
class](https://drafts.csswg.org/web-animations-1/#animation-class).

Within the set of CSS Animations *with* an [owning
element](#owning-element), two
animations `A` and `B` are sorted in composite
order (first to last) as follows:

1. If the [owning element](#owning-element) of `A` and `B` differs, sort
 `A` and `B` by [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order) of their corresponding [owning
 elements]. With regard to pseudo-elements,
 the sort order is as follows:

 - element

 - ::marker

 - ::before

 - any other pseudo-elements not mentioned specifically in this list,
 sorted in ascending order by the Unicode codepoints that make up
 each selector

 - ::after

 - element children

2. Otherwise, sort `A` and `B` based on their
 position in the computed value of the
 [animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) property of the (common)
 [owning element](#owning-element).

When determining the composite order in order to sort [animation
events](#events) where either or both of the events is an
[`animationcancel`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationcancel) event, treat the CSS Animation(s) for which the
[`animationcancel`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationcancel) event was generated as having an [owning
element](#owning-element)
corresponding to the owning element in use at the moment when the CSS
Animation was cancelled. Furthermore, use the position of the animation
in the
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) property in effect at the time when
the CSS Animation was cancelled sorting such that positions of cancelled
animations sort before positions of animations that have not been
cancelled.

The composite order of CSS Animations *without* an [owning
element](#owning-element) is
based on their position in the [global animation
list](https://drafts.csswg.org/web-animations-1/#global-animation-list).

This differs from the behavior defined
for transitions. We should probably sort transitions first, then
animation, then use the global animation list. The reason being that
when developer tools etc. hang on to orphaned animations and transitions
in order to replay them, they should maintain roughly the same composite
order.

CSS Animations generated using the markup defined in this specification
are *not* added to the [global animation
list](https://drafts.csswg.org/web-animations-1/#global-animation-list) when they are created. Instead, these animations are
appended to the [global animation list]
at the first moment when they transition out of the
[idle](https://drafts.csswg.org/web-animations-1/#play-state-idle) play state after being disassociated from their [owning
element](#owning-element).
CSS Animations that have been disassociated from their [owning
element] but are still
[idle] do not have a defined composite order.

[Note,] this behavior relies on the fact that disassociating an
animation from its [owning
element](#owning-element)
always causes it to enter (or remain) in the
[idle](https://drafts.csswg.org/web-animations-1/#play-state-idle) play state.

## 3. Assembling Keyframes

### [3.1. ][ Declaring Keyframes: the [\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) rule]
See [CSS Animations 1 § 3 Declaring
Keyframes](https://drafts.csswg.org/css-animations-1/#keyframes).

### 3.2. Processing Keyframes

For each animation effect defined by the `N`th item in the
[coordinated value
list](https://drafts.csswg.org/css-values-4/#coordinated-value-list) of the [animation-\*] properties on target
(pseudo-)element `element`, its associated
[keyframes](https://drafts.csswg.org/web-animations-1/#keyframe) are generated as follows:

1. **Set Defaults:**

 - Let `default timing function` be the corresponding
 [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [animation-timing-function](https://drafts.csswg.org/css-animations-1/#propdef-animation-timing-function) on `element`.

 - Let `default composite` be the corresponding [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [animation-composition](#propdef-animation-composition) on `element`.

 - Let `keyframes` be an empty sequence of
 [keyframe](https://drafts.csswg.org/web-animations-1/#keyframe) objects, each possessing a
 `keyframe offset`,
 `keyframe timing function`,
 `keyframe composite`, and `keyframe values`.

 - Let `animated properties` be an empty set of CSS
 [property
 names](https://drafts.csswg.org/cssom-1/#css-declaration-property-name).

2. **Collect Declared Keyframes:**

 1. Find the last
 [\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) at-rule in document order with
 [\<keyframes-name\>](https://drafts.csswg.org/css-animations-1/#typedef-keyframes-name) matching the corresponding
 [animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) value `name`.

 If there is no
 [\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) at-rule with
 [\<keyframes-name\>](https://drafts.csswg.org/css-animations-1/#typedef-keyframes-name) matching `name`
 (or if `name` is
 [none](https://drafts.csswg.org/css-animations-1/#valdef-animation-name-none)), abort this procedure. In this case no
 animation is generated, and any existing animation matching
 `name` is canceled.

 2. Group together all
 [\<keyframe-block\>](https://drafts.csswg.org/css-animations-1/#typedef-keyframe-block) declarations that share the
 same
 [specified](https://drafts.csswg.org/css-cascade-5/#specified-value)
 [\<keyframe-selector\>](https://drafts.csswg.org/css-animations-1/#typedef-keyframe-selector) (treating [from] as
 [0%] and [to] as [100%]), last declared
 [animation-timing-function](https://drafts.csswg.org/css-animations-1/#propdef-animation-timing-function) [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) (defaulting to
 `default timing function` if there is no such
 declaration), and last declared
 [animation-composition](#propdef-animation-composition) [computed
 value] (defaulting to
 `default composite` if there is no such declaration).

 3. For each such group of matching
 [\<keyframe-block\>](https://drafts.csswg.org/css-animations-1/#typedef-keyframe-block) declarations, ordered by
 their earliest
 [\<keyframe-block\>] in the sorted order:

 1. [Cascade](https://drafts.csswg.org/css-cascade-6/#cascade) together all of its [declaration
 blocks](https://www.w3.org/TR/CSS2/syndata.html#x14) such that for each CSS property (except
 those that are "not animatable", which must be ignored) the
 last declaration among all its
 [\<keyframe-block\>](https://drafts.csswg.org/css-animations-1/#typedef-keyframe-block) declarations takes
 precedence.
 [\[CSS-CASCADE-4\]](#biblio-css-cascade-4 "CSS Cascading and Inheritance Level 4")

 The
 [cascade](https://drafts.csswg.org/css-cascade-6/#cascade) will expand [shorthand
 properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) into their
 [sub-properties](https://drafts.csswg.org/css-cascade-5/#longhand) and map together corresponding property
 pairs in each [logical property
 group](https://drafts.csswg.org/css-logical-1/#logical-property-group) according to the `element`'s
 [computed](https://drafts.csswg.org/css-cascade-5/#computed-value) [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode).

 2. Append to `keyframes` a new empty
 [keyframe](https://drafts.csswg.org/web-animations-1/#keyframe) with the group's
 `keyframe offset`,
 `keyframe timing function`, and
 `keyframe composite`. Give its
 `keyframe values` the set of [declared
 values](https://drafts.csswg.org/css-cascade-5/#declared-value) resulting from this cascade.

 3. Add each [property
 name](https://drafts.csswg.org/cssom-1/#css-declaration-property-name) that was added to its
 [`cssRules`](https://drafts.csswg.org/css-animations-1/#dom-csskeyframesrule-cssrules) to `animated properties`.

3. **Generate Initial and Final Frames:**

 1. Find or create the `initial keyframe`, a
 [keyframe](https://drafts.csswg.org/web-animations-1/#keyframe) with a `keyframe offset` of
 [0%], `default timing function` as its
 `keyframe timing function`, and
 `default composite` as its
 `keyframe composite`.

 2. For any property in `animated properties` that is not
 otherwise present in a keyframe with an offset of [0%] or
 one that would be positioned earlier in the [used keyframe
 order](#used-keyframe-order), add the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of that property on `element` to
 `initial keyframe`'s `keyframe values`.

 3. If `initial keyframe`'s `keyframe values`
 is not empty, prepend `initial keyframe` to
 `keyframes`.

 4. Repeat for `final keyframe`, using an offset of
 [100%], considering keyframes positioned *later* in the
 [used keyframe
 order](#used-keyframe-order), and *appending* to `keyframes`.

4. **Sort Frames:**

 - The [specified order] of
 `keyframes` is the order resulting from the steps
 above, i.e. document order with duplicate keyframes collapsed to
 the earliest position.

 - The [computed order] of
 `keyframes`---​which is the order returned by
 [`getKeyframes()`](https://drafts.csswg.org/web-animations-1/#dom-keyframeeffect-getkeyframes)---​is found by shifting any keyframes whose offset
 was specified as a
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), [from] keyword, or
 [to] keyword to the front of the list (after the generated
 `initial keyframe`, if any), and performing a stable
 sort on these keyframes by their `keyframe offset`s.

 - The [used order] of
 `keyframes`---​which is the order used to interpolate
 and compute the actual animation frames---​is found by attaching
 the `keyframes` onto the animation effect's timeline
 assuming an [iteration
 count](https://drafts.csswg.org/web-animations-1/#iteration-count) of 1 and ordering them from earliest to latest,
 breaking ties by using the [computed keyframe
 order](#computed-keyframe-order).

 (#issue-67663de2) Any specific requirements on sorting
 computed keyframes introduced by this spec should be integrated into
 [Web Animations § 5.3.3 Calculating computed
 keyframes](https://drafts.csswg.org/web-animations-1/#calculating-computed-keyframes).
 Any specific requirements on used keyframes introduced by this spec
 should be integrated into [Web Animations § 5.3.4 The effect value
 of a keyframe
 effect](https://drafts.csswg.org/web-animations-1/#the-effect-value-of-a-keyframe-animation-effect).
 The above description of the distinction between these sets of
 keyframes should be moved to an informative note.

 Although the [computed keyframe
 order](#computed-keyframe-order) sorts keyframes with
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) offsets, it maintains keyframes
 specified with a
 [\<timeline-range-name\>](https://drafts.csswg.org/scroll-animations-1/#typedef-timeline-range-name) in their [specified keyframe
 order](#specified-keyframe-order)---​after any
 [\<percentage\>] keyframes
 (other than a generated `final keyframe`), even if these
 come later in the [used keyframe
 order](#used-keyframe-order).

## 4. Declaring Animations

CSS Animations are defined by binding keyframes to an element using the
[animation-\*] properties. These list-valued properties, which are
all
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand) of the
[animation](https://drafts.csswg.org/css-animations-1/#propdef-animation)
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property), form a [coordinating list property
group](https://drafts.csswg.org/css-values-4/#coordinating-list-property) with
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) as the [coordinating list base
property](https://drafts.csswg.org/css-values-4/#coordinating-list-base-property) and each item in the [coordinated value
list](https://drafts.csswg.org/css-values-4/#coordinated-value-list) defining the properties of a single animation effect.

See [CSS Values 4 § A Coordinating List-Valued
Properties](https://drafts.csswg.org/css-values-4/#linked-properties)
for how the individual [animation-\*] property values coordinate.

### 4.1. The [animation-duration property]
Name:

[animation-duration]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<time
\[0s,∞\]\>](https://drafts.csswg.org/css-values-4/#time-value)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item either a time or the keyword
[auto](#valdef-animation-duration-auto)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

The
[animation-duration](#propdef-animation-duration) property specifies the [iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) of the animation's associated [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

[auto]

: For time-driven animations, equivalent to [0s].

 For [scroll-driven
 animations](https://drafts.csswg.org/scroll-animations-1/#scroll-driven-animations), equivalent to the duration necessary to fill the
 timeline in consideration of
 [animation-range](https://drafts.csswg.org/scroll-animations-1/#propdef-animation-range),
 [animation-delay](#propdef-animation-delay), and
 [animation-iteration-count](https://drafts.csswg.org/css-animations-1/#propdef-animation-iteration-count). See [Scroll-driven Animations
 § 4.1 Finite Timeline
 Calculations](https://drafts.csswg.org/scroll-animations-1/#finite-attachment).

[[\<time \[0s,∞\]\>](https://drafts.csswg.org/css-values-4/#time-value)]

: For time-driven animations, specifies the length of time that an
 animation takes to complete one cycle. A negative
 [\<time\>](https://drafts.csswg.org/css-values-4/#time-value) is invalid.

 For [scroll-driven
 animations](https://drafts.csswg.org/scroll-animations-1/#scroll-driven-animations), treated as
 [auto](#valdef-animation-duration-auto).

If the
[used](https://drafts.csswg.org/css-cascade-5/#used-value)
[animation-duration](#propdef-animation-duration) is [0s], the animation itself
still occurs (instantaneously). The animation's start and end events are
still fired. If
[animation-fill-mode](https://drafts.csswg.org/css-animations-1/#propdef-animation-fill-mode) is set to [backwards] or
[both], the first frame of the animation (as defined by
[animation-direction](https://drafts.csswg.org/css-animations-1/#propdef-animation-direction)) will be displayed during the
[animation-delay](#propdef-animation-delay); and if
[animation-fill-mode]
is set to [forwards] or [both], the last frame of the
animation (as defined by
[animation-direction])
will be displayed after the
[animation-delay]. However,
if [animation-fill-mode] is set to
[none](https://drafts.csswg.org/css-animations-1/#valdef-animation-fill-mode-none) the keyframes of the animation animation will
have no noticeable effect.

For backwards-compatibility with Level 1, when the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
[animation-timeline](#propdef-animation-timeline) is
[auto](#valdef-animation-timeline-auto) (i.e. only one list value, and that value being
[auto]), the [resolved
value](https://drafts.csswg.org/cssom-1/#resolved-value) of
[auto](#valdef-animation-duration-auto) for
[animation-duration](#propdef-animation-duration) is [0s] whenever its [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) would also be [0s].

### [4.2. ][The [animation-timing-function](https://drafts.csswg.org/css-animations-1/#propdef-animation-timing-function) property]
The
[animation-timing-function](https://drafts.csswg.org/css-animations-1/#propdef-animation-timing-function) is used to determine the [timing
function](https://drafts.csswg.org/css-easing-2/#easing-function) applied to each
[keyframe](https://drafts.csswg.org/web-animations-1/#keyframe) as defined in [§ 3 Assembling Keyframes](#keyframes).

### [4.3. ][The [animation-iteration-count](https://drafts.csswg.org/css-animations-1/#propdef-animation-iteration-count) property]
The
[animation-iteration-count](https://drafts.csswg.org/css-animations-1/#propdef-animation-iteration-count) property specifies the [iteration
count](https://drafts.csswg.org/web-animations-1/#iteration-count) of the animation's associated [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

### [4.4. ][The [animation-direction](https://drafts.csswg.org/css-animations-1/#propdef-animation-direction) property]
The
[animation-direction](https://drafts.csswg.org/css-animations-1/#propdef-animation-direction) property specifies the [playback
direction](https://drafts.csswg.org/web-animations-1/#playback-direction) of the animation's associated [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

### [4.5. ][The [animation-play-state](https://drafts.csswg.org/css-animations-1/#propdef-animation-play-state) property]
The
[animation-play-state](https://drafts.csswg.org/css-animations-1/#propdef-animation-play-state) is used to pause or play the
animation.

If at any time, including when the animation is first generated, the
resolved value of
[animation-play-state](https://drafts.csswg.org/css-animations-1/#propdef-animation-play-state) corresponding to an animation is
newly
[running](https://drafts.csswg.org/css-animations-1/#valdef-animation-play-state-running), the implementation must run the procedure to
[play an
animation](https://drafts.csswg.org/web-animations-1/#play-an-animation) for the given animation with the
`auto-rewind flag` set to false.

If at any time, including when the animation is first generated, the
resolved value of
[animation-play-state](https://drafts.csswg.org/css-animations-1/#propdef-animation-play-state) corresponding to an animation is
newly
[paused](https://drafts.csswg.org/css-animations-1/#valdef-animation-play-state-paused), the implementation must run the procedure to
[pause an
animation](https://drafts.csswg.org/web-animations-1/#pause-an-animation) for the given animation.

The above requirements do not apply if the animation's play state is
being overridden by the Web Animations API as described in [§ 2
Animations](#animations).

### 4.6. The [animation-delay-start property]
The
[animation-delay-start](#propdef-animation-delay-start) property specifies the [start
delay](https://drafts.csswg.org/web-animations-1/#start-delay) of the animation's associated [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect), which defines when the animation will start. It allows
an animation to begin execution some time after it is applied, or to
appear to have begun execution some time *before* it is applied.

Name:

[animation-delay-start]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<time\>](https://drafts.csswg.org/css-values-4/#time-value)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0s

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a duration

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

[[\<time\>](https://drafts.csswg.org/css-values-4/#time-value)]

: The
 [\<time\>](https://drafts.csswg.org/css-values-4/#time-value) defines how long of a delay there
 is between the start of the animation (when the animation is applied
 to the element via these properties) and when it begins executing. A
 delay of [0s] (the initial value) means that the animation
 will execute as soon as it is applied.

 A negative delay is **valid**. Similar to a delay of [0s], it
 means that the animation executes immediately, but is automatically
 progressed by the absolute value of the delay, as if the animation
 had started the specified time in the past, and so it appears to
 start partway through its [active
 duration](https://drafts.csswg.org/web-animations-1/#active-duration). If an animation's keyframes have an implied
 starting value, the values are taken from the time the animation
 starts, not some time in the past.

### 4.7. The [animation-delay-end property]
The
[animation-delay-end](#propdef-animation-delay-end) property specifies the [end
delay](https://drafts.csswg.org/web-animations-1/#end-delay) of the animation's associated [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect), which defines when the animation will start when it is
reversed.

Name:

[animation-delay-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<time
\[0s,∞\]\>](https://drafts.csswg.org/css-values-4/#time-value)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0s

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a duration

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Should animation-delay-end support
negative values? If so, what would it mean?

Should animation-delay-end be added to
the animation shorthand?

### 4.8. The [animation-delay shorthand]
Name:

[animation-delay]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<\'animation-delay-start\'\>](#propdef-animation-delay-start)
[\<\'animation-delay-end\'\>](#propdef-animation-delay-end)[?](https://drafts.csswg.org/css-values-4/#mult-opt)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

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

The
[animation-delay](#propdef-animation-delay) property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets
[animation-delay-start](#propdef-animation-delay-start) and
[animation-delay-end](#propdef-animation-delay-end) together in a single declaration.
Specifying a single value will set the
[animation-delay-start] to that value, and will reset
[animation-delay-end]
to its initial value, for backward compatibility with the
[animation-delay] previous
longhand behavior.

### [4.9. ][The [animation-fill-mode](https://drafts.csswg.org/css-animations-1/#propdef-animation-fill-mode) property]
The
[animation-fill-mode](https://drafts.csswg.org/css-animations-1/#propdef-animation-fill-mode) property specifies the [fill
mode](https://drafts.csswg.org/web-animations-1/#fill-mode) of the animation's associated [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

### 4.10. The [animation-composition property]
The
[animation-composition](#propdef-animation-composition) property defines the [composite
operation](https://drafts.csswg.org/web-animations-1/#composite-operation) used when multiple animations affect the same property
simultaneously.

Name:

[animation-composition]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<single-animation-composition\>](#typedef-single-animation-composition)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

replace

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a keyword as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

[[\<single-animation-composition\>] = replace
[\|](https://drafts.csswg.org/css-values-4/#comb-one) add [\|] accumulate]

The values of
[animation-composition](#propdef-animation-composition) have the meaning defined for the
corresponding values of the [composite
operation](https://drafts.csswg.org/web-animations-1/#composite-operation) defined in Web Animations
[\[WEB-ANIMATIONS\]](#biblio-web-animations "Web Animations").

When specified in a keyframe,
[animation-composition](#propdef-animation-composition) defines the composite operation to
use for each property specified in that keyframe until the next keyframe
specifying each property.

For example, the following stylesheet
defines two different animations targeting the
[scale](https://drafts.csswg.org/css-transforms-2/#propdef-scale) property.

 @keyframes heartbeat {
 from {
 scale: 1;
 animation-timing-function: ease-out;
 }
 30% {
 scale: 1.3;
 }
 }
 .heartbeat {
 animation: heartbeat 0.3s 2s infinite;
 }

 @keyframes throb {
 50% {
 scale: 1.8;
 }
 }
 .icon:mouseover {
 animation: throb 0.4s add;
 }

If these two animations are applied to the same element, normally only
one animation would apply, but by specifying [add] as the
[animation-composition](#propdef-animation-composition) on the second animation, the result
of the two animations will be combined.

Since CSS Transitions
[\[CSS3-TRANSITIONS\]](#biblio-css3-transitions "CSS Transitions Module Level 1")
have a lower composite order, it is possible to use
[animation-composition](#propdef-animation-composition) to combine CSS Animations with
underlying transitions as in the following example.

 .icon {
 filter: blur(20px);
 transition: filter 0.5s;
 }
 .icon:hover {
 filter: blur(0px);
 animation: brightness-pulse 3s infinite add;
 }

 @keyframes brightness-pulse {
 0% {
 scale: 1.1;
 filter: brightness(130%);
 }
 10% {
 scale: 1;
 filter: brightness(100%);
 }
 }

Create pictures of these examples and
verify they make sense.

### 4.11. The [animation-timeline property]
The
[animation-timeline](#propdef-animation-timeline) property defines the
[timeline](https://drafts.csswg.org/web-animations-1/#timeline) used with the animation.

 This specification does not introduce any syntax to
specify animation timelines but instead it is up to others
specifications such as Scroll-linked Animations
[\[SCROLL-ANIMATIONS\]](#biblio-scroll-animations "Scroll-driven Animations")
to do so.

Name:

[animation-timeline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<single-animation-timeline\>](#typedef-single-animation-timeline)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item either the keyword [none], the keyword
[auto], a case-sensitive [css
identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier), a computed
[scroll()](https://drafts.csswg.org/scroll-animations-1/#funcdef-scroll) function, or a computed
[view()](https://drafts.csswg.org/scroll-animations-1/#funcdef-view) function

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

``` prod
<single-animation-timeline> = auto | none | <dashed-ident> | <scroll()> | <view()>
```

The
[animation-timeline](#propdef-animation-timeline) property is similar to properties
like
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) and
[animation-duration](#propdef-animation-duration) in that it can have one or more
values, each one imparting additional behavior to a corresponding
[animation](https://drafts.csswg.org/web-animations-1/#concept-animation) on the element, with the timelines matched up with
animations as described
[here](https://drafts.csswg.org/css-animations-1/#animation-name).

Each value has type
[\<single-animation-timeline\>](#typedef-single-animation-timeline), whose possible values have the
following effects:

[auto]

: The animation's
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) is a
 [`DocumentTimeline`](https://drafts.csswg.org/web-animations-1/#documenttimeline), more specifically the [default document
 timeline](https://drafts.csswg.org/web-animations-1/#document-default-document-timeline).

[none]

: The animation is not associated with a
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline).

[[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident)]

: If a named [scroll progress
 timeline](https://drafts.csswg.org/scroll-animations-1/#scroll-progress-timelines) or [view progress
 timeline](https://drafts.csswg.org/scroll-animations-1/#view-progress-timelines) is in scope on this element, use the referenced
 timeline as defined in [Scroll-driven Animations §  Declaring a
 Named Timeline's Scope: the timeline-scope
 property](https://drafts.csswg.org/scroll-animations-1/#timeline-scope).

 Otherwise the animation is not associated with a
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline).

[[\<scroll()\>](https://drafts.csswg.org/scroll-animations-1/#funcdef-scroll)]

: Use the [scroll progress
 timeline](https://drafts.csswg.org/scroll-animations-1/#scroll-progress-timelines) indicated by the given
 [scroll()](https://drafts.csswg.org/scroll-animations-1/#funcdef-scroll) function. See [Scroll-driven Animations
 § 2.2.1 The scroll()
 notation](https://drafts.csswg.org/scroll-animations-1/#scroll-notation).

[[\<view()\>](https://drafts.csswg.org/scroll-animations-1/#funcdef-view)]

: Use the [view progress
 timeline](https://drafts.csswg.org/scroll-animations-1/#view-progress-timelines) indicated by the given
 [view()](https://drafts.csswg.org/scroll-animations-1/#funcdef-view) function. See [Scroll-driven Animations
 § 3.3.1 The view()
 notation](https://drafts.csswg.org/scroll-animations-1/#view-notation).

Make it easier to use
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) to select the timeline when
[animation-timeline](#propdef-animation-timeline) is not specified. Allowing
[animation-name] to be used
for selecting timeline enables most common animations to have to use a
single name for both their keyframes and timeline which is simple and
ergonomics. The
[animation-timeline]
property gives authors additional control to independently select
keyframes and timeline if necessary.

When multiple [animation-\*] properties are set simultaneously,
[animation-timeline](#propdef-animation-timeline) is updated first, so e.g. a change
to
[animation-play-state](https://drafts.csswg.org/css-animations-1/#propdef-animation-play-state) applies to the
simultaneously-applied timeline specified in
[animation-timeline].

### [4.12. ][The [animation](https://drafts.csswg.org/css-animations-1/#propdef-animation) shorthand property]
The
[animation](https://drafts.csswg.org/css-animations-1/#propdef-animation) shorthand property syntax is as
follows:

[[\<single-animation\>] =
[\<\'animation-duration\'\>](#propdef-animation-duration)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function) [\|\|]
[\<\'animation-delay-start\'\>](#propdef-animation-delay-start) [\|\|]
[\<single-animation-iteration-count\>](https://drafts.csswg.org/css-animations-1/#typedef-single-animation-iteration-count) [\|\|]
[\<single-animation-direction\>](https://drafts.csswg.org/css-animations-1/#typedef-single-animation-direction) [\|\|]
[\<single-animation-fill-mode\>](https://drafts.csswg.org/css-animations-1/#typedef-single-animation-fill-mode) [\|\|]
[\<single-animation-play-state\>](https://drafts.csswg.org/css-animations-1/#typedef-single-animation-play-state) [\|\|] \[ none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<keyframes-name\>](https://drafts.csswg.org/css-animations-1/#typedef-keyframes-name) \] [\|\|]
[\<single-animation-timeline\>](#typedef-single-animation-timeline)]

## 5. Animation Events

### 5.1. Event dispatch

[Note,] this is a more general description of event dispatch
than that of CSS Animations Level 1
[\[CSS3-ANIMATIONS\]](#biblio-css3-animations "CSS Animations Level 1")
since it must account for the possibility of animations being seeked or
reversed using the Web Animations API
[\[WEB-ANIMATIONS\]](#biblio-web-animations "Web Animations").

The
[target](https://dom.spec.whatwg.org/#event-target) for a CSS animation event is the animation's [owning
element](#owning-element). If
there is no [owning element], no CSS
animation events are dispatched (although the [animation playback
events](https://drafts.csswg.org/web-animations-1/#animation-playback-events) defined in Web Animations are still dispatched at the
corresponding
[`CSSAnimation`](#cssanimation) object).

For the purpose of determining which events to dispatch, the
[phases](https://drafts.csswg.org/web-animations-1/#animation-effect-phases-and-states)
defined in the Web Animations model are used. These definitions apply to
an [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect), however, for the purpose of dispatching events, we
consider a CSS Animation to have the same phase as its [associated
effect](https://drafts.csswg.org/web-animations-1/#animation-associated-effect). For example, a CSS Animation is in the [before
phase](https://drafts.csswg.org/web-animations-1/#animation-effect-before-phase) if its [associated
effect] is in the [before
phase].

A CSS Animation that does not have an [associated
effect](https://drafts.csswg.org/web-animations-1/#animation-associated-effect) is considered to be in the [idle
phase](https://drafts.csswg.org/web-animations-1/#animation-effect-idle-phase) if its [current
time](https://drafts.csswg.org/web-animations-1/#animation-current-time) is
[unresolved](https://drafts.csswg.org/web-animations-1/#unresolved), in the [before
phase](https://drafts.csswg.org/web-animations-1/#animation-effect-before-phase) if its [current time]
is less than zero, and in the [after
phase](https://drafts.csswg.org/web-animations-1/#animation-effect-after-phase) otherwise.

Similarly, subsequent references to the [start
delay](https://drafts.csswg.org/web-animations-1/#start-delay), [active
duration](https://drafts.csswg.org/web-animations-1/#active-duration), [current
iteration](https://www.w3.org/TR/web-animations-1/#current-iteration), [iteration
start](https://drafts.csswg.org/web-animations-1/#iteration-start), and [iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) of a CSS animation should be understood to refer to the
corresponding properties of the animation's [associated
effect](https://drafts.csswg.org/web-animations-1/#animation-associated-effect).

For calculating the
[`elapsedTime`](https://drafts.csswg.org/css-animations-1/#dom-animationevent-elapsedtime) of each event, the following definitions are used:

- [interval start] =
 `max(min(-`[`start delay`](https://drafts.csswg.org/web-animations-1/#start-delay)`, `[`active duration`](https://drafts.csswg.org/web-animations-1/#active-duration)`), 0)`

- [interval end] =
 `max(min(`[`associated effect end`](https://drafts.csswg.org/web-animations-1/#associated-effect-end)` - `[`start delay`](https://drafts.csswg.org/web-animations-1/#start-delay)`, `[`active duration`](https://drafts.csswg.org/web-animations-1/#active-duration)`), 0)`

Each time a new [animation
frame](https://drafts.csswg.org/web-animations-1/#animation-frame) is established and the animation does *not* have a
[pending play
task](https://drafts.csswg.org/web-animations-1/#pending-play-task) or [pending pause
task](https://drafts.csswg.org/web-animations-1/#pending-pause-task), the events to dispatch are determined by comparing the
animation's phase before and after establishing the new [animation
frame] as follows:

Change

Events dispatched

[Elapsed time] (ms)

[idle](https://drafts.csswg.org/web-animations-1/#animation-effect-idle-phase) or
[before](https://drafts.csswg.org/web-animations-1/#animation-effect-before-phase) →
[active](https://drafts.csswg.org/web-animations-1/#animation-effect-active-phase)

[`animationstart`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationstart)

[interval start](#interval-start)

[idle](https://drafts.csswg.org/web-animations-1/#animation-effect-idle-phase) or
[before](https://drafts.csswg.org/web-animations-1/#animation-effect-before-phase) →
[after](https://drafts.csswg.org/web-animations-1/#animation-effect-after-phase) [٭](#multiple-events-note)

[`animationstart`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationstart)

[interval start](#interval-start)

[`animationend`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationend)

[interval end](#interval-end)

[active](https://drafts.csswg.org/web-animations-1/#animation-effect-active-phase) →
[before](https://drafts.csswg.org/web-animations-1/#animation-effect-before-phase)

[`animationend`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationend)

[interval start](#interval-start)

[active](https://drafts.csswg.org/web-animations-1/#animation-effect-active-phase) → [active]
*and* the [current
iteration](https://www.w3.org/TR/web-animations-1/#current-iteration) of the animation's [associated
effect](https://drafts.csswg.org/web-animations-1/#animation-associated-effect) has changed since the previous animation frame

[`animationiteration`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationiteration)

(See below) [†](#animation-iteration-elapsed-time)

[active](https://drafts.csswg.org/web-animations-1/#animation-effect-active-phase) →
[after](https://drafts.csswg.org/web-animations-1/#animation-effect-after-phase)

[`animationend`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationend)

[interval end](#interval-end)

[after](https://drafts.csswg.org/web-animations-1/#animation-effect-after-phase) →
[active](https://drafts.csswg.org/web-animations-1/#animation-effect-active-phase)

[`animationstart`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationstart)

[interval end](#interval-end)

[after](https://drafts.csswg.org/web-animations-1/#animation-effect-after-phase) →
[before](https://drafts.csswg.org/web-animations-1/#animation-effect-before-phase) [٭](#multiple-events-note)

[`animationstart`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationstart)

[interval end](#interval-end)

[`animationend`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationend)

[interval start](#interval-start)

*not*
[idle](https://drafts.csswg.org/web-animations-1/#animation-effect-idle-phase) and *not*
[after](https://drafts.csswg.org/web-animations-1/#animation-effect-after-phase) → [idle]

[`animationcancel`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationcancel)

The [active
time](https://drafts.csswg.org/web-animations-1/#active-time) of the animation at the moment it was cancelled
calculated using a [fill
mode](https://drafts.csswg.org/web-animations-1/#fill-mode) of both.

٭ Where multiple events are listed for a state change, all events are
dispatched in the order listed and in immediate succession.

† The [elapsed time](#elapsed-time) for an
[`animationiteration`](https://drafts.csswg.org/css-animations-1/#eventdef-globaleventhandlers-animationiteration) event is defined as follows:

1. Let `previous current iteration` be the [current
 iteration](https://www.w3.org/TR/web-animations-1/#current-iteration) from the previous animation frame.

2. If `previous current iteration` is greater than [current
 iteration](https://www.w3.org/TR/web-animations-1/#current-iteration), let `iteration boundary` be
 [`current iteration`](https://www.w3.org/TR/web-animations-1/#current-iteration)` + 1`, otherwise let it be [current
 iteration].

3. The [elapsed time](#elapsed-time) is the result of evaluating
 `(``iteration boundary`` - `[`iteration start`](https://drafts.csswg.org/web-animations-1/#iteration-start)`) × `[`iteration duration`](https://drafts.csswg.org/web-animations-1/#iteration-duration)`)`.

Since the [elapsed time](#elapsed-time) defined in the table and procedure above is expressed
in milliseconds, it must be divided by 1,000 to produce a value in
seconds before being assigned to the
[`elapsedTime`](https://drafts.csswg.org/css-animations-1/#dom-animationevent-elapsedtime) member of the
[`AnimationEvent`](https://drafts.csswg.org/css-animations-1/#animationevent).

### 5.2. The `AnimationEvent` Interface

#### 5.2.1. IDL Definition

Add
[`animation`](#dom-animationevent-animation) to the
[`AnimationEvent`](https://drafts.csswg.org/css-animations-1/#animationevent) interface and
[`AnimationEventInit`](https://drafts.csswg.org/css-animations-1/#dictdef-animationeventinit) dictionary as follows:

```
[Exposed=Window]
partial interface AnimationEvent {
 readonly attribute CSSAnimation? animation;
};

partial dictionary AnimationEventInit {
 CSSAnimation? animation = null;
};
```

#### 5.2.2. Attributes

Add attribute descriptions as follows:

[`animation`], of type [CSSAnimation](#cssanimation), readonly, nullable
: The CSS Animation that fired the event.

## 6. DOM Interfaces

### 6.1. The CSSAnimation interface

```
[Exposed=Window]
interface CSSAnimation : Animation {
 readonly attribute CSSOMString animationName;
};
```

[`animationName`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring), readonly

: The key used to find matching keyframes rules that define the
 [associated
 effect](https://drafts.csswg.org/web-animations-1/#animation-associated-effect) at the point when the animation was created. This
 is the value of the
 [animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) property that caused this
 object to be generated.

### 6.2. Requirements on pending style changes

Various operations may affect the [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) of properties on elements. User agents may, as an
optimization, defer recomputing these values until it becomes necessary.
However, all operations included in programming interface defined in
this specification, as well as those operations defined in Web
Animations
[\[WEB-ANIMATIONS\]](#biblio-web-animations "Web Animations")
that may return objects or animation state defined by this
specification, must produce a result consistent with having fully
processed any such pending changes to computed values.

As an example, in the following code fragment, when the specified style
of `elem` is initially updated, a user agent may defer recalculating the
computed value of the
[animation](https://drafts.csswg.org/css-animations-1/#propdef-animation) property.

However, the
[`getAnimations()`](https://drafts.csswg.org/web-animations-1/#dom-animatable-getanimations) method called on `elem` is specified by Web Animations
and can return
[`CSSAnimation`](#cssanimation) objects as defined in this specification. Hence, as
result of the requirements in this section, the user agent must
calculate the updated value of `elem`'s
[animation](https://drafts.csswg.org/css-animations-1/#propdef-animation) property and create the requested
[`CSSAnimation`](#cssanimation) object before returning its result.

```
elem.style.animation = 'fadeOut 1s';
elem.getAnimations()[0].pause();
```

Similarly, reading
[`playState`](https://drafts.csswg.org/web-animations-1/#dom-animation-playstate) may depend on pending style changes.

```
elem.style.animation = 'fadeOut 1s paused';
const anim = elem.getAnimations()[0];
elem.style.animationPlayState = 'running';
console.log(anim.playState); // Should be 'running'.
```

## 7. Privacy Considerations

No privacy concerns have been reported on this specification.

## 8. Security Considerations

No security concerns have been reported on this specification.

## 9. Changes

### 9.1. Recent Changes

Changes since the [2 June 2023 Working
Draft](https://www.w3.org/TR/2023/WD-css-animations-2-20230602/):

- Moved the animation-trigger property to a new spec,
 animation-triggers-1 ([PR
 13571](https://github.com/w3c/csswg-drafts/pull/13571))
- Define trigger scope. Flattened tree; removed anchor-scope reference
 ([PR 13241](https://github.com/w3c/csswg-drafts/pull/13241))
- Added play-once animation-action ([Issue
 12611](https://github.com/w3c/csswg-drafts/issues/12611))
- Defined that event triggers can be defined to have enter/exit pairs,
 like timelines.
- Separated trigger concept from trigger instance
- Changed initial value of the exit ranges to auto, to match the start
 ranges
- Changed \"animation-trigger-behavior\" to \"animation-trigger\" and
 largely rewrote the definition ([PR
 13009](https://github.com/w3c/csswg-drafts/pull/13009))
- Changed animation-trigger-type to animation-trigger-behavior ([PR
 12223](https://github.com/w3c/csswg-drafts/pull/12223))
- Clarified that setting \"effect\" should not prevent the timeline to
 set \"set\" via animation-timeline ([PR
 11812](https://github.com/w3c/csswg-drafts/pull/11812))
- Defined animation-trigger-\* as reset-only sub-properties of animation
 ([PR
 11653](https://github.com/w3c/csswg-drafts/pull/11653#issue-2831268235))
- Added note to Animation Frames about running the updating animation
 trigger state procedure
- Added algorithm for Setting a Trigger of an Animation
- Added the AnimationTrigger interface
- Moved all new definitions from web-animations-1 to web-animations-2
- Specified the animation-trigger property ([Issue
 8942](https://github.com/w3c/csswg-drafts/issues/8942#issuecomment-1854342340))
- Defined order for sorting animationcancel events ([Issue
 11064](https://github.com/w3c/csswg-drafts/issues/11064))
- Made animation-duration:auto resolve to 0s, for legacy compat ([Issue
 6530](https://github.com/w3c/csswg-drafts/issues/6530))
- Switched timeline names from
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) to
 [\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident) ([Issue
 8746](https://github.com/w3c/csswg-drafts/issues/8746))

Changes since the [2 March 2023 Working
Draft](https://www.w3.org/TR/2023/WD-css-animations-2-20230302/):

- Added
 [auto](#valdef-animation-duration-auto) as the [initial
 value](https://drafts.csswg.org/css-cascade-5/#initial-value) of
 [animation-duration](#propdef-animation-duration). ([Issue
 6530](https://github.com/w3c/csswg-drafts/issues/6530))
- Rewrote [§ 3.2 Processing Keyframes](#keyframe-processing) to re-use
 the
 [cascade](https://drafts.csswg.org/css-cascade-6/#cascade), to handle non-percentage keyframe offsets, to handle
 keyframes with offsets outside the \[0,1\] range, and to use the value
 of
 [animation-composition](#propdef-animation-composition) as the default composite.
- Reduced the cases where [display:
 none](https://drafts.csswg.org/css-display-4/#propdef-display) cancel an animation. ([Issue
 6429](https://github.com/w3c/csswg-drafts/issues/6429))
- Cross-linked to [CSS Values 4 § A Coordinating List-Valued
 Properties](https://drafts.csswg.org/css-values-4/#linked-properties)
 to define how the various [animation-\*] properties interact.
- Clarified that among the animation properties,
 [animation-timeline](#propdef-animation-timeline) is applied first.

### 9.2. Changes since CSS Animations, Level 1

- The interaction between CSS Animations and Web Animations is defined,
 and the concepts of the owning element and animation composite order
 are introduced.
- Generation of keyframe objects is described in detail.
- The
 [animation-composition](#propdef-animation-composition) property is introduced, which
 defines the composite operation used when multiple animations affect
 the same property simultaneously.
- The
 [animation-timeline](#propdef-animation-timeline) property is introduced, which
 defines the timeline used with the animation.
- The
 [animation](https://drafts.csswg.org/css-animations-1/#propdef-animation) shorthand property is updated to
 account for these new properties.
- Dispatch of animation events is described.
- The [`CSSAnimation`](#cssanimation) interface is added.
- Requirements on pending style changes are described.
