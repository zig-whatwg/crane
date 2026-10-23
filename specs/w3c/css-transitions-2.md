## 1. Delta specification

This is a delta specification, meaning that it currently contains only
the differences from CSS Transitions Level 1
[\[CSS-TRANSITIONS-1\]](#biblio-css-transitions-1 "CSS Transitions Module Level 1").
Once the Level 1 specification is closer to complete, it will be merged
with the additions here into a complete level 2 specification.

## 2. Transitions

### [2.1. ][The [transition-property](https://drafts.csswg.org/css-transitions-1/#propdef-transition-property) Property]
Insert text from [CSS Transitions 1
§ 2.1 The transition-property
Property](https://drafts.csswg.org/css-transitions-1/#transition-property-property)
and backport the following paragraph.

Although the
[transition-property](https://drafts.csswg.org/css-transitions-1/#propdef-transition-property) may specify shorthand properties
and the
[all](https://drafts.csswg.org/css-transitions-1/#valdef-transition-property-all) keyword, individual transitions are generated
for each longhand sub-property that is
[transitionable](#transitionable). The [expanded transition property
name] of a
transition is the name of the longhand sub-property for which the
transition was generated (e.g.
[border-left-width](https://drafts.csswg.org/css-borders-4/#propdef-border-left-width)).

Update the defining instance of
[transitionable](#transitionable) once it is ported from Level 1.

In CSS Transitions Level 2, when comparing the [before-change
style](https://drafts.csswg.org/css-transitions-1/#before-change-style) and [after-change
style](https://drafts.csswg.org/css-transitions-1/#after-change-style) for a given property, the property values are
[transitionable] if:

1. They have an [animation
 type](https://drafts.csswg.org/web-animations-1/#animation-type) that is neither [not
 animatable](https://drafts.csswg.org/web-animations-1/#not-animatable) nor
 [discrete](https://drafts.csswg.org/web-animations-1/#discrete), or
2. The
 [transition-behavior](#propdef-transition-behavior) is [allow-discrete] and
 they have an [animation
 type](https://drafts.csswg.org/web-animations-1/#animation-type) that is
 [discrete](https://drafts.csswg.org/web-animations-1/#discrete).

 When values with a
[discrete](https://drafts.csswg.org/web-animations-1/#discrete) [animation
type](https://drafts.csswg.org/web-animations-1/#animation-type) are transitioned, they flip at 50% progress.

### [2.2. ][The [transition-duration](https://drafts.csswg.org/css-transitions-1/#propdef-transition-duration) Property]
The
[transition-duration](https://drafts.csswg.org/css-transitions-1/#propdef-transition-duration) property specifies the [iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) of the transition's associated [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

### [2.3. ][The [transition-timing-function](https://drafts.csswg.org/css-transitions-1/#propdef-transition-timing-function) Property]
The
[transition-timing-function](https://drafts.csswg.org/css-transitions-1/#propdef-transition-timing-function) property specifies the [timing
function](https://drafts.csswg.org/css-easing-2/#easing-function) of the transition's associated [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) (see [Web Animations § 4.6.11 Easing (effect timing
transformations)](https://drafts.csswg.org/web-animations-1/#time-transformations)).

 Unlike CSS animations, the timing function for CSS
transitions applies to the animation effect as opposed to the individual
keyframes since this allows it to be reflected in the [transformed
progress](https://drafts.csswg.org/web-animations-1/#transformed-progress) as used when calculating the reversing shortening
factor.

### [2.4. ][The [transition-delay](https://drafts.csswg.org/css-transitions-1/#propdef-transition-delay) Property]
The
[transition-delay](https://drafts.csswg.org/css-transitions-1/#propdef-transition-delay) property specifies the [start
delay](https://drafts.csswg.org/web-animations-1/#start-delay) of the transition's associated [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

### 2.5. The [transition-behavior Property]
The
[transition-behavior](#propdef-transition-behavior) property specifies whether
transitions will be started or not for discrete properties.

Name:

[transition-behavior]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<transition-behavior-value\>](#typedef-transition-behavior-value)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[All
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

The syntax for specifying
[transition-behavior](#propdef-transition-behavior) is as follows:

[[\<transition-behavior-value\>](#typedef-transition-behavior-value)] = normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) allow-discrete

When [normal] is specified, transitions will not be started for
discrete properties, only for interpolable properties. When
[allow-discrete] is specified, transitions will be started for
discrete properties as well as interpolable properties.

### [2.6. ][The [transition](https://drafts.csswg.org/css-transitions-1/#propdef-transition) Shorthand Property]
The syntax for specifying an item in the
[transition](https://drafts.csswg.org/css-transitions-1/#propdef-transition) shorthand is as follows:

[\<single-transition\>] = \[
[none](https://drafts.csswg.org/css-transitions-1/#valdef-transition-property-none)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<single-transition-property\>](https://drafts.csswg.org/css-transitions-1/#single-transition-property) \]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<time\>](https://drafts.csswg.org/css-values-4/#time-value) [\|\|]
[\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function) [\|\|]
[\<time\>] [\|\|]
[\<transition-behavior-value\>](#typedef-transition-behavior-value)

## 3. Starting of transitions

The [owning element] of a transition refers to the element or pseudo-element to
which the
[transition-property](https://drafts.csswg.org/css-transitions-1/#propdef-transition-property) property was applied that generated
the animation. A transition may be disassociated from its [owning
element](#owning-element) such
that it has no [owning element].

The set of [running
transitions](https://drafts.csswg.org/css-transitions-1/#running-transition) includes only those transitions that have an [owning
element](#owning-element).

Whenever an implementation is required to
[cancel](https://drafts.csswg.org/css-transitions-1/#transition-cancel) a transition, it must disassociate the transition from
its [owning element](#owning-element) and run the procedure to [cancel an
animation](https://drafts.csswg.org/web-animations-1/#cancel-an-animation) on the transition.

Although not explicitly defined by level 1 of this specification, in
addition to
[canceling](https://drafts.csswg.org/css-transitions-1/#transition-cancel) transitions on elements that are no longer
[connected](https://dom.spec.whatwg.org/#connected), implementations must also
[cancel] any running transitions on
elements that are no longer [being
rendered](https://html.spec.whatwg.org/multipage/rendering.html#being-rendered) and remove transitions on them from the set of
[completed
transitions](https://drafts.csswg.org/css-transitions-1/#completed-transition).

Note that calling the
[`cancel()`](https://drafts.csswg.org/web-animations-1/#dom-animation-cancel) method on the
[`CSSTransition`](#csstransition) object representing a [running
transition](https://drafts.csswg.org/css-transitions-1/#running-transition) does *not* cause the transition to be disassociated
from its [owning element](#owning-element).

### 3.1. Faster reversing of interrupted transitions

The [reversing shortening
factor](https://drafts.csswg.org/css-transitions-1/#transition-reversing-shortening-factor) and [reversing-adjusted start
value](https://drafts.csswg.org/css-transitions-1/#transition-reversing-adjusted-start-value) associated with a transition in order to produce
correct reverse behavior, are associated with the transition itself and
not, for example, its [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect). As a result, transitions will use these same values
when producing a reversed transition, even if the transition's
associated [animation effect] has been
updated or replaced using the Web Animations API
[\[WEB-ANIMATIONS\]](#biblio-web-animations "Web Animations").

### 3.2. The current transition generation

Associated with each top-level browsing context is a [current transition
generation] that is
incremented on each [style change
event](https://drafts.csswg.org/css-transitions-1/#style-change-event).

Each time a new transition is generated, the current value of the
(already incremented) [current transition
generation](#current-transition-generation) is stored as the transition's [transition
generation].

### [3.3. ][Defining [before-change style](https://drafts.csswg.org/css-transitions-1/#before-change-style): the [\@starting-style](#at-ruledef-starting-style) rule]
In Level 1 of this specification, transitions can only start during a
[style change
event](https://drafts.csswg.org/css-transitions-1/#style-change-event) for elements which have a defined [before-change
style](https://drafts.csswg.org/css-transitions-1/#before-change-style) established by the previous [style change
event]. That means a transition could not
be started on an element that was not being rendered for the previous
[style change event] (see: [CSS
Transitions 1 § 3 Starting of
transitions](https://drafts.csswg.org/css-transitions-1/#starting)).

In some cases it makes sense to start transitions on newly inserted
elements or elements that change from not [being
rendered](https://html.spec.whatwg.org/multipage/rendering.html#being-rendered) to being rendered. To allow for that, this
specification introduces
[\@starting-style](#at-ruledef-starting-style).

The [\@starting-style] rule is a grouping rule. The style rules
inside it are used to establish styles to transition from, if the
previous [style change
event](https://drafts.csswg.org/css-transitions-1/#style-change-event) did not establish a [before-change
style](https://drafts.csswg.org/css-transitions-1/#before-change-style) for the element whose styles are being computed.

 This means that
[\@starting-style](#at-ruledef-starting-style) rules only apply to some elements during a
computed style update, namely elements that were not rendered or part of
the DOM during the previous [style change
event](https://drafts.csswg.org/css-transitions-1/#style-change-event).

Define [starting style] for an element as the [after-change
style](https://drafts.csswg.org/css-transitions-1/#after-change-style) with
[\@starting-style](#at-ruledef-starting-style) rules applied in addition. If an element does
not have a [before-change
style](https://drafts.csswg.org/css-transitions-1/#before-change-style) for a given [style change
event](https://drafts.csswg.org/css-transitions-1/#style-change-event), the [starting
style](#starting-style) is used
instead of the [before-change style] to
compare with the [after-change style] to
start transitions ([CSS Transitions 1 § 3 Starting of
transitions](https://drafts.csswg.org/css-transitions-1/#starting)).

The rules inside
[\@starting-style](#at-ruledef-starting-style) cascade as any other grouped style rules without
introducing any new ordering to the cascade, which means rules inside
[\@starting-style] do not
necessarily win over those outside.

Style rules in
[\@starting-style](#at-ruledef-starting-style) do not apply to [after-change
style](https://drafts.csswg.org/css-transitions-1/#after-change-style). Thus, the presence of matching rules in
[\@starting-style] can cause
transitions to occur on elements that otherwise could not have
transitions because they lack a [before-change
style](https://drafts.csswg.org/css-transitions-1/#before-change-style).

[Starting style](#starting-style) inherits from the parent's [after-change
style](https://drafts.csswg.org/css-transitions-1/#after-change-style) just like [after-change
style] does.

The
[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color) of an `h1` element can be
transitioned from transparent to green when it is initially rendered:

```
h1 {
 transition: background-color 1.5s;
 background-color: green;
}
@starting-style {
 h1 {
 background-color: transparent;
 }
}
```

Conditional rules can be used with CSS Nesting:

```
h1 {
 transition: background-color 1.5s;
 background-color: green;
 @starting-style {
 background-color: transparent;
 }
}
```

The
[opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity) of an element can be transitioned
when the element changes to or from [display:
none](https://drafts.csswg.org/css-display-4/#propdef-display):

```
#target {
 transition-property: opacity, display;
 transition-duration: 0.5s;
 display: block;
 opacity: 1;
 @starting-style {
 opacity: 0;
 }
}
#target.hidden {
 display: none;
 opacity: 0;
}
```

The display is transitioning to allow for an opacity transition before
flipping from [display:block] to [display:none].

Specifying [opacity:
0](https://drafts.csswg.org/css-color-4/#propdef-opacity) in the
[\@starting-style](#at-ruledef-starting-style) rule means the element will transition opacity
from [0] to [1] when inserted into the tree or when the
`hidden` class flips
[display](https://drafts.csswg.org/css-display-4/#propdef-display) from
[none](https://drafts.csswg.org/css-display-4/#valdef-display-none) to
[block](https://drafts.csswg.org/css-display-4/#valdef-display-block) as the target element does not already have a
[before-change
style](https://drafts.csswg.org/css-transitions-1/#before-change-style) in those cases.

Specifying [opacity:
0](https://drafts.csswg.org/css-color-4/#propdef-opacity) in the `#target.hidden` rule makes
[opacity] transition from [1]
to [0] when the `hidden` class is added.

Global, name-defining at-rules such as
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes),
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule), and
[\@layer](https://drafts.csswg.org/css-cascade-5/#at-ruledef-layer) are allowed inside
[\@starting-style](#at-ruledef-starting-style), and when present behave as if they were outside
of [\@starting-style].

#### 3.3.1. The `CSSStartingStyleRule` interface

The
[`CSSStartingStyleRule`](#cssstartingstylerule) interface represents a
[\@starting-style](#at-ruledef-starting-style) rule.

```
[Exposed=Window]
interface CSSStartingStyleRule : CSSGroupingRule ;
```

## 4. Application of transitions

### 4.1. Animation composite order

[Animations](https://drafts.csswg.org/web-animations-1/#concept-animation) generated from the markup defined in this specification
have an [animation
class](https://drafts.csswg.org/web-animations-1/#animation-class) of 'CSS Transition'.

CSS Transitions have an *earlier* composite order that CSS Animations
and animations without a specific [animation
class](https://drafts.csswg.org/web-animations-1/#animation-class).

Within the set of CSS Transitions, two animations `A` and
`B` are sorted in composite order (first to last) as follows:

1. If neither `A` nor `B` has an [owning
 element](#owning-element),
 sort based on their relative position in the [global animation
 list](https://drafts.csswg.org/web-animations-1/#global-animation-list).

2. Otherwise, if only one of `A` or `B` has an
 [owning element](#owning-element), let the animation *with* an [owning
 element] sort first.

3. Otherwise, if the [owning
 element](#owning-element)
 of `A` and `B` differs, sort `A`
 and `B` by [tree
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

4. Otherwise, if `A` and `B` have different
 [transition
 generation](#transition-generation) values, sort by their corresponding [transition
 generation] in ascending order.

5. Otherwise, sort `A` and `B` in ascending order
 by the Unicode codepoints that make up the [expanded transition
 property
 name](#expanded-transition-property-name) of each transition (i.e. without attempting case
 conversion and such that '-moz-column-width' sorts before
 'column-width').

When determining the composite order in order to sort transition events
where either or both of the events is a
[`transitioncancel`](https://drafts.csswg.org/css-transitions-1/#transitioncancel) event, use the [owning
element](#owning-element) and
[transition
generation](#transition-generation) that were set immediately prior to canceling the
transition.

Transitions generated using the markup defined in this specification are
*not* added to the [global animation
list](https://drafts.csswg.org/web-animations-1/#global-animation-list) when they are created. Instead, these animations are
appended to the [global animation list]
at the first moment when they transition out of the [idle play
state](https://drafts.csswg.org/web-animations-1/#play-state-idle) after being disassociated from their [owning
element](#owning-element).
Transitions that have been disassociated from their [owning
element] but are still
[idle] do not have a defined composite order.

 This behavior relies on the fact that disassociating a
transition from its [owning
element](#owning-element)
always causes it to enter (or remain) in the [idle play
state](https://drafts.csswg.org/web-animations-1/#play-state-idle).

### 4.2. Animation cascade level

Animations with an [animation
class](https://drafts.csswg.org/web-animations-1/#animation-class) of 'CSS Transition' that have an [owning
element](#owning-element) are
applied to the 'Transitions declaration' level of the CSS cascade. All
other animations generated by the markup defined in this specification,
including animations that no longer have an [owning
element], are applied to the 'Animation
declarations' level of the cascade. (See [Web Animations § 5.4.5
Applying the composited
result](https://drafts.csswg.org/web-animations-1/#applying-the-composited-result).)

## 5. Transition Events

### 5.1. Event dispatch

[Note,] this is a more general description of event dispatch
than that of CSS Transitions Level 1
[\[CSS-TRANSITIONS-1\]](#biblio-css-transitions-1 "CSS Transitions Module Level 1")
since it must account for the possibility of animations being seeked or
reversed using the Web Animations API
[\[WEB-ANIMATIONS\]](#biblio-web-animations "Web Animations").
Furthermore, it is possible using the Web Animations API to substitute
the transition effect with an entirely different effect with properties
not normally used with transitions (e.g. an effect that repeats multiple
times) and hence this section provides a generic definition that
accounts for the full complexity of the Web Animations model.

The
[target](https://dom.spec.whatwg.org/#event-target) for a transition event is the transition's [owning
element](#owning-element). If
there is no [owning element], no transition
events are dispatched (although the [animation playback
events](https://drafts.csswg.org/web-animations-1/#animation-playback-events) defined in Web Animations are still dispatched at the
corresponding
[`CSSTransition`](#csstransition) object).

To avoid firing redundant events, the set of events to dispatch is based
on comparing the [phase](#transition-phase) of the transition in the previous [animation
frame](https://drafts.csswg.org/web-animations-1/#animation-frame) to its current state.

The [transition phase] of a transition is initially 'idle' and is
updated on each [animation
frame](https://drafts.csswg.org/web-animations-1/#animation-frame) according to the first matching condition from below:

If the transition has no [associated effect](https://drafts.csswg.org/web-animations-1/#animation-associated-effect),
: The transition phase is set according to the first matching
 condition from below:

 If the transition has an [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) [current time](https://drafts.csswg.org/web-animations-1/#animation-current-time),
 : The transition phase is 'idle'.

 If the transition has a [current time](https://drafts.csswg.org/web-animations-1/#animation-current-time) \< 0,
 : The transition phase is 'before'.

 Otherwise,
 : The transition phase is 'after'.

If the transition has a [pending play task](https://drafts.csswg.org/web-animations-1/#pending-play-task) or a [pending pause task](https://drafts.csswg.org/web-animations-1/#pending-pause-task) and its phase was previously 'idle' or 'pending',
: The transition phase is 'pending'.

Otherwise,
: The transition phase is the
 [phase](https://drafts.csswg.org/web-animations-1/#animation-effect-phases-and-states)
 of its [associated
 effect](https://drafts.csswg.org/web-animations-1/#animation-associated-effect).

For calculating the
[`elapsedTime`](https://drafts.csswg.org/css-transitions-1/#Events-TransitionEvent-elapsedTime) of each event, the following definitions are used:

- [interval start] =
 `max(min(-`[`start delay`](https://drafts.csswg.org/web-animations-1/#start-delay)`, `[`active duration`](https://drafts.csswg.org/web-animations-1/#active-duration)`), 0)`

- [interval end] =
 `max(min(`[`associated effect end`](https://drafts.csswg.org/web-animations-1/#associated-effect-end)` - `[`start delay`](https://drafts.csswg.org/web-animations-1/#start-delay)`, `[`active duration`](https://drafts.csswg.org/web-animations-1/#active-duration)`), 0)`

In the above formulae, references to the [start
delay](https://drafts.csswg.org/web-animations-1/#start-delay), [active
duration](https://drafts.csswg.org/web-animations-1/#active-duration), [current
iteration](https://www.w3.org/TR/web-animations-1/#current-iteration), [iteration
start](https://drafts.csswg.org/web-animations-1/#iteration-start), and [iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) of a transition should be understood to refer to the
corresponding properties of the transition's [associated
effect](https://drafts.csswg.org/web-animations-1/#animation-associated-effect).

Each time a new [animation
frame](https://drafts.csswg.org/web-animations-1/#animation-frame) is established, the events to dispatch are determined
by comparing the [transition
phase](#transition-phase) in
the previous and current [animation frame] as
follows:

Change

Events dispatched

[Elapsed time] (ms)

idle → pending or before

[`transitionrun`](https://drafts.csswg.org/css-transitions-1/#transitionrun)

[interval start](#interval-start)

idle → active [٭](#multiple-events-note)

[`transitionrun`](https://drafts.csswg.org/css-transitions-1/#transitionrun)

[interval start](#interval-start)

[`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart)

idle → after [٭](#multiple-events-note)

[`transitionrun`](https://drafts.csswg.org/css-transitions-1/#transitionrun)

[interval start](#interval-start)

[`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart)

[`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend)

[interval end](#interval-end)

pending or before → active

[`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart)

[interval start](#interval-start)

pending or before → after [٭](#multiple-events-note)

[`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart)

[interval start](#interval-start)

[`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend)

[interval end](#interval-end)

active → after

[`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend)

[interval end](#interval-end)

active → before

[`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend)

[interval start](#interval-start)

after → active

[`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart)

[interval end](#interval-end)

after → before [٭](#multiple-events-note)

[`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart)

[interval end](#interval-end)

[`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend)

[interval start](#interval-start)

*not* idle and *not* after → idle

[`transitioncancel`](https://drafts.csswg.org/css-transitions-1/#transitioncancel)

The [active
time](https://drafts.csswg.org/web-animations-1/#active-time) of the animation at the moment it was canceled
calculated using a [fill
mode](https://drafts.csswg.org/web-animations-1/#fill-mode) of both.

٭ Where multiple events are listed for a state change, all events are
dispatched in the order listed and in immediate succession.

Since the [elapsed time](#elapsed-time) defined in the table and procedure above is expressed
in milliseconds, it must be divided by 1,000 to produce a value in
seconds before being assigned to the
[`elapsedTime`](https://drafts.csswg.org/css-transitions-1/#Events-TransitionEvent-elapsedTime) member of the
[`TransitionEvent`](https://drafts.csswg.org/css-transitions-1/#transitionevent).

The above state transition chart ensures that, with the exception of
transitions that are paused or have an infinite running time, the
following invariants hold:

- For every
 [`transitionrun`](https://drafts.csswg.org/css-transitions-1/#transitionrun) event there will be a exactly one
 [`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend) *or*
 [`transitioncancel`](https://drafts.csswg.org/css-transitions-1/#transitioncancel) and never both.

- For every
 [`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart) event there will be a exactly one
 [`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend) *or*
 [`transitioncancel`](https://drafts.csswg.org/css-transitions-1/#transitioncancel) and never both.

- Every
 [`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend) event is preceded by a corresponding
 [`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart) event.

The typical sequences of events, then, are as follows:

- Regular playback:
 [`transitionrun`](https://drafts.csswg.org/css-transitions-1/#transitionrun),
 [`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart),
 [`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend).

- Interrupted playback:
 [`transitionrun`](https://drafts.csswg.org/css-transitions-1/#transitionrun),
 [`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart),
 [`transitioncancel`](https://drafts.csswg.org/css-transitions-1/#transitioncancel).

- Interrupted playback during delay or pending phase:
 [`transitionrun`](https://drafts.csswg.org/css-transitions-1/#transitionrun),
 [`transitioncancel`](https://drafts.csswg.org/css-transitions-1/#transitioncancel).

- Reversed playback after completion:
 [`transitionrun`](https://drafts.csswg.org/css-transitions-1/#transitionrun),
 [`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart),
 [`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend),
 [`transitionstart`](https://drafts.csswg.org/css-transitions-1/#transitionstart),
 [`transitionend`](https://drafts.csswg.org/css-transitions-1/#transitionend).

### [5.2. ][Interface [`TransitionEvent`](https://drafts.csswg.org/css-transitions-1/#transitionevent)]
Add animation to the
[`TransitionEvent`](https://drafts.csswg.org/css-transitions-1/#transitionevent) interface and
[`TransitionEventInit`](https://drafts.csswg.org/css-transitions-1/#dictdef-transitioneventinit) dictionary as follows:

#### 5.2.1. IDL Definition

```
[Exposed=Window]
partial interface TransitionEvent {
 readonly attribute CSSTransition? animation;
};

partial dictionary TransitionEventInit {
 CSSTransition? animation = null;
};
```

#### 5.2.2. Attributes

Add attribute descriptions as follows:

[`animation`]`, `` of type `[`CSSTransition`](#csstransition)`, readonly, nullable`

: The CSS Transition corresponding to the transition that fired the
 event.

## 6. DOM Interfaces

### 6.1. The CSSTransition interface

```
[Exposed=Window]
interface CSSTransition : Animation {
 readonly attribute CSSOMString transitionProperty;
};
```

[`transitionProperty`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring), readonly

: The [expanded transition property
 name](#expanded-transition-property-name) of this transition.

### 6.2. Requirements on pending style changes

Various operations may affect the [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) of properties on elements. User agents may, as an
optimization, defer recomputing these values until it becomes necessary.
However, all operations included in programming interface defined in
this specification, as well as those operations defined in Web
Animations
[\[WEB-ANIMATIONS\]](#biblio-web-animations "Web Animations")
that may return objects defined by this specification, must produce a
result consistent with having fully processed any such pending changes
to computed values.

As an example, in the following code fragment, when the specified value
of `elem`'s
[opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity) property is updated, a user agent
may defer recalculating the computed value of the
[opacity] property.

The first time this occurs, calling
[`getComputedStyle(elt)`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle) and subsequently accessing the `opacity` property of
the result will cause the user agent to recompute the value of opacity.

After the
[opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity) property is updated a second time,
the
[`getAnimations()`](https://drafts.csswg.org/web-animations-1/#dom-animatable-getanimations) method is called on `elem`. This method is specified by
Web Animations and can return
[`CSSTransition`](#csstransition) objects as defined in this specification. Hence, as
result of the requirements in this section, the user agent must apply
any pending style changes thus generating a new
[`CSSTransition`](#csstransition) for the [opacity]
property before returning its result.

```
elem.style.transition = 'opacity 100s';
elem.style.opacity = '0';
window.getComputedStyle(elem).opacity; // 0
elem.style.opacity = '1';
elem.getAnimations()[0].transitionProperty // 'opacity'
```

## 7. Privacy Considerations

No new privacy considerations have been reported on this specification.

## 8. Security Considerations

No new security considerations have been reported on this specification.

## 9. Changes

### 9.1. Changes since Working Draft (4 February 2026)

### 9.2. Changes since First Public Working Draft (5 September 2023)

- Define the order of
 [`transitioncancel`](https://drafts.csswg.org/css-transitions-1/#transitioncancel) events. (See [issue
 #11064](https://github.com/w3c/csswg-drafts/issues/11064).)

### 9.3. Changes since Level 1, in First Public Working Draft

- Transitions can now occur on discretely-animatable properties. The
 newly-introduced
 [transition-behavior](#propdef-transition-behavior) property allows opting in to this
 behavior.
- The
 [\@starting-style](#at-ruledef-starting-style) rule (and
 [`CSSStartingStyleRule`](#cssstartingstylerule) interface) is introduced to allow transitions on
 elements whose style changes from not being rendered to being
 rendered.
- Interactions with the Web Animations API are more clearly specified:
 - The [`CSSTransition`](#csstransition) interface is defined.
 - The composite order of the generated animations is defined.
 - The animation class of the generated animations is defined.
 - The cascade level of animation objects that were created from
 transitions and then reused through the Web Animations API is
 defined, along with the concept of [owning
 element](#owning-element)
 needed to define it.
 - The rules for event dispatch have been specified to explain what
 happens when the animations are seeked or reversed using the Web
 Animations API.
 - Interaction of the Web Animations API with the rules for faster
 reversing of interrupted transitions is specified.
 - [§ 6.2 Requirements on pending style
 changes](#requirements-on-pending-style-changes) are specified.
- The handling of transitions on elements that are no longer being
 rendered is more clearly defined (the transitions are canceled and
 removed from the set of completed transitions).

## 10. Issues commonly raised as issues with previous levels

These issues were commonly reported issues with the previous level of
the specification.

More powerful timing function syntax is a common request from
developers. See, for example: [2013
message](https://lists.w3.org/Archives/Public/www-style/2013Jun/0376.html)
or [2015
thread](https://lists.w3.org/Archives/Public/public-fx/2015JulSep/thread.html#msg34).

Developers frequently have to trigger style flushes in order to force
transitions to start. It would be good to have an API that would avoid
this requirement. See, for example, [2011
proposal](https://lists.w3.org/Archives/Public/www-style/2011Mar/0729.html).

## 11. Issues deferred from previous levels of the spec

These issues were in previous levels of the specification, but may not
turn out to be important in this level either.

We may ultimately want to support a
keypath syntax for the
[transition-property](https://drafts.csswg.org/css-transitions-1/#propdef-transition-property) property. A keypath syntax would
enable different transitions to be specified for components of a
property. For example the blur of a shadow could have a different
transition than the color of a shadow.
