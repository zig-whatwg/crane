## 1. Introduction

*This section is not normative.*

This document introduces new CSS features to enable *implicit
transitions*, which describe how CSS properties can be made to change
smoothly from one value to another over a given duration.

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
keywords](https://www.w3.org/TR/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

## 2. Transitions

Normally when the value of a CSS property changes, the rendered result
is instantly updated, with the affected elements immediately changing
from the old property value to the new property value. This section
describes a way to specify gradual transitions using new CSS properties.
These properties are used to animate smoothly from the old state to the
new state over time.

For example, suppose that transitions of one second have been defined on
the
[left](https://www.w3.org/TR/CSS2/visuren.html#propdef-left) and
[background-color](https://www.w3.org/TR/CSS2/colors.html#propdef-background-color) properties. The following diagram
illustrates the effect of updating those properties on an element, in
this case moving it to the right and changing the background from red to
blue. This assumes other transition parameters still have their default
values.

![Transitions of
[left](https://www.w3.org/TR/CSS2/visuren.html#propdef-left) and
[background-color](https://www.w3.org/TR/CSS2/colors.html#propdef-background-color).](images/transition-example.svg){a
width="518"}

Transitions are a presentational effect. The [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) of a property transitions over time from the old value
to the new value. Therefore if a script queries the [computed
value] of a property (or other data depending
on it) as it is transitioning, it will see an intermediate value that
represents the current animated value of the property.

The transition for a property is defined using a number of new
properties. For example:

Example(s):

 div {
 transition-property: opacity;
 transition-duration: 2s;
 }

The above example defines a transition on the
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity) property that, when a new value is
assigned to it, will cause a smooth change between the old value and the
new value over a period of two seconds.

Each of the transition properties accepts a comma-separated list,
allowing multiple transitions to be defined, each acting on a different
property. In this case, the individual transitions take their parameters
from the same index in all the lists. For example:

Example(s):

 div {
 transition-property: opacity, left;
 transition-duration: 2s, 4s;
 }

This will cause the
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity) property to transition over a
period of two seconds and the left property to transition over a period
of four seconds.

In the case where the lists of values in transition properties do not
have the same length, the length of the
[transition-property](#propdef-transition-property) list determines the number of items
in each list examined when starting transitions. The lists are matched
up from the first value: excess values at the end are not used. If one
of the other properties doesn't have enough comma-separated values to
match the number of values of
[transition-property],
the user agent must calculate its used value by repeating the list of
values until there are enough. This truncation or repetition does not
affect the computed value. [ Note: This is analogous to the behavior of
the [background-\*] properties, with
[background-image](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-image) analogous to
[transition-property](#propdef-transition-property). ]

Example(s):

 div {
 transition-property: opacity, left, top, width;
 transition-duration: 2s, 1s;
 }

The above example defines a transition on the
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity) property of 2 seconds duration, a
transition on the
[left](https://www.w3.org/TR/CSS2/visuren.html#propdef-left) property of 1 second duration, a
transition on the
[top](https://www.w3.org/TR/CSS2/visuren.html#propdef-top) property of 2 seconds duration and
a transition on the
[width](https://www.w3.org/TR/CSS2/visudet.html#propdef-width) property of 1 second duration.

While authors can use transitions to create dynamically changing
content, dynamically changing content can lead to seizures in some
users. For information on how to avoid content that can lead to
seizures, see [Guideline 2.3: Seizures: Do not design content in a way
that is known to cause seizures](https://www.w3.org/TR/WCAG20/#seizure)
([\[WCAG20\]](#biblio-wcag20 "Web Content Accessibility Guidelines (WCAG) 2.0")).

### 2.1. [The [transition-property Property]]
The
[transition-property](#propdef-transition-property) property specifies the name of the
CSS property to which the transition is applied.

Name:

[transition-property]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<single-transition-property\>](#single-transition-property)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

all

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[none](#valdef-transition-property-none) else a list of identifiers

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

[\<single-transition-property\>] =
[all](#valdef-transition-property-all)
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value)

A value of [none]
means that no property will transition. Otherwise, a list of properties
to be transitioned, or the keyword [all] which indicates that all properties are to be transitioned,
is given.

If one of the identifiers listed is not a recognized property name, the
implementation must still start transitions on the animatable properties
in the list using the duration, delay, and timing function at their
respective indices in the lists for
[transition-duration](#propdef-transition-duration),
[transition-delay](#propdef-transition-delay), and
[transition-timing-function](#propdef-transition-timing-function). In other words, unrecognized
properties must be kept in the list to preserve the matching of indices.

The
[\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value) production in
[\<single-transition-property\>](#single-transition-property) also excludes the keyword
[none](#valdef-transition-property-none), in addition to the keywords always excluded
from [\<custom-ident\>]. This
means that [none],
[inherit](https://www.w3.org/TR/css-cascade-5/#valdef-all-inherit), and
[initial](https://www.w3.org/TR/css-cascade-5/#valdef-all-initial) are not permitted as items within a list of more
that one identifier; any list that uses them is syntactically invalid.

For the keyword
[all](#valdef-transition-property-all), or if one of the identifiers listed is a
shorthand property, implementations must start transitions for all its
longhand sub-properties (or, for
[all], all properties),
using the duration, delay, and timing function at the index
corresponding to the shorthand.

If a property is specified multiple times in the value of
[transition-property](#propdef-transition-property) (either on its own, via a shorthand
that contains it, or via the
[all](#valdef-transition-property-all) value), then the transition that starts uses the
duration, delay, and timing function at the index corresponding to the
*last* item in the value of
[transition-property]
that calls for animating that property.

Note: The
[all](#valdef-transition-property-all) value and
[all](https://www.w3.org/TR/css-cascade-5/#propdef-all) shorthand property work in similar
ways, so the [all] value
is just like a shorthand that covers all properties.

### 2.2. [The [transition-duration Property]]
The
[transition-duration](#propdef-transition-duration) property defines the length of time
that a transition takes.

Name:

[transition-duration]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<time
\[0s,∞\]\>](https://www.w3.org/TR/css-values-3/#time-value)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[0s]

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

This property specifies how long the transition from the old value to
the new value should take. By default the value is [0s], meaning
that the transition is immediate (i.e. there will be no animation). A
negative value for
[transition-duration](#propdef-transition-duration) renders the declaration invalid.

### 2.3. [The [transition-timing-function Property]]
The
[transition-timing-function](#propdef-transition-timing-function) property describes how the
intermediate values used during a transition will be calculated. It
allows for a transition to change speed over its duration. These effects
are commonly called *easing* functions.

Timing functions are defined in the separate CSS Easing Functions module
[\[css-easing-1\]](#biblio-css-easing-1 "CSS Easing Functions Level 1").
The [input progress
value](https://www.w3.org/TR/css-easing-2/#input-progress-value) used is the percentage of the transition duration, and
the [output progress
value](https://www.w3.org/TR/css-easing-2/#output-progress-value) is used as the `p` value when
[interpolating](https://www.w3.org/TR/css-values-4/#interpolation) the property value (see [§ 4 Application of
transitions](#application)).

Name:

[transition-timing-function]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<easing-function\>](https://www.w3.org/TR/css-easing-2/#typedef-easing-function)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[ease]

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
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

### 2.4. [The [transition-delay Property]]
The
[transition-delay](#propdef-transition-delay) property defines when the
transition will start. It allows a transition to begin execution after
some period of time from when it is applied. A
[transition-delay] value
of [0s] means the transition will execute as soon as the property
is changed. Otherwise, the value specifies an offset from the moment the
property is changed, and the transition will delay execution by that
offset.

If the value for
[transition-delay](#propdef-transition-delay) is a negative time offset then the
transition will execute the moment the property is changed, but will
appear to have begun execution at the specified offset. That is, the
transition will appear to begin part-way through its play cycle. In the
case where a transition has implied starting values and a negative
[transition-delay], the
starting values are taken from the moment the property is changed.

Name:

[transition-delay]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<time\>](https://www.w3.org/TR/css-values-3/#time-value)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[0s]

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

### 2.5. [The [transition Shorthand Property]]
The [transition](#propdef-transition) shorthand property combines the four
properties described above into a single property.

Name:

[transition]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<single-transition\>](#single-transition)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[\<single-transition\>] = \[
[none](#valdef-transition-property-none)
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<single-transition-property\>](#single-transition-property) \]
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<time\>](https://www.w3.org/TR/css-values-3/#time-value) [\|\|]
[\<easing-function\>](https://www.w3.org/TR/css-easing-2/#typedef-easing-function) [\|\|]
[\<time\>]

Note that order is important within the items in this property: the
first value that can be parsed as a time is assigned to the
transition-duration, and the second value that can be parsed as a time
is assigned to transition-delay.

If there is more than one
[\<single-transition\>](#single-transition) in the shorthand, and any of the
transitions has
[none](#valdef-transition-property-none) as the
[\<single-transition-property\>](#single-transition-property), then the declaration is invalid.

## 3. Starting of transitions

Implementations must maintain a set of [running
transitions], each of which applies to a specific
element and non-shorthand property. Each of these transitions also has a
[start time], [end
time], [start value], [end
value], [reversing-adjusted start
value], and [reversing
shortening factor]. Transitions
are added to this set as described in this section, and are removed from
this set when they [complete](#dfn-complete) or when implementations are required to
[cancel] them. [ For the rationale behind the
[reversing-adjusted start
value](#transition-reversing-adjusted-start-value) and [reversing shortening
factor](#transition-reversing-shortening-factor), see [§ 3.1 Faster reversing of interrupted
transitions](#reversing). ]

Implementations must also maintain a set of [completed
transitions], each of which (like [running
transitions](#running-transition)) applies to a specific element and non-shorthand
property. [ This specification maintains the invariant that there is
never both a [running
transition](#running-transition) and a [completed
transition](#completed-transition) for the same property and element. ]

If an element is no longer in the document, implementations must
[cancel](#transition-cancel)
any [running
transitions](#running-transition) on it and remove transitions on it from the [completed
transitions](#completed-transition).

This set of completed transitions needs to be maintained in order to
prevent transitions from repeating themselves in certain cases, i.e., to
maintain the invariant that this specification tries to maintain that
unrelated style changes do not trigger transitions.

An example where maintaining the set
of completed transitions is necessary would be a transition on an
inherited property, where the parent specifies a transition of that
property for a longer duration (say, [transition: 4s
text-indent](#propdef-transition)) and a child element that inherits the parent's
value specifies a transition of the same property for a shorter duration
(say, [transition: 1s text-indent]).
Without the maintenance of this set of completed transitions,
implementations could start additional transitions on the child after
the initial 1 second transition on the child completes.

Various things can cause the [computed
values](https://www.w3.org/TR/css-cascade-5/#computed-value) of properties on an element to change. These include
insertion and removal of elements from the document tree (which both
changes whether those elements have [computed
values] and can change the styles of other
elements through selector matching), changes to the document tree that
cause changes to which selectors match elements, changes to style sheets
or style attributes, and other things. This specification does not
define when [computed values] are updated,
beyond saying that implementations must not use, present, or display
something resulting from the CSS cascading, value computation, and
inheritance process
[\[CSS3CASCADE\]](#biblio-css3cascade "CSS Cascading and Inheritance Level 3")
without updating the [computed value] (which
means merely that implementations cannot avoid meeting requirements of
this specification by claiming not to have updated the [computed
value] as part of handling a style change).
However, when an implementation updates the [computed
value] of a property on an element to reflect
one of these changes, or computes the [computed
value] of a property on an element newly added
to the document, it must update the [computed
value] for all properties and elements to
reflect all of these changes at the same time (or at least it must be
undetectable that it was done at a different time). This processing of a
set of simultaneous style changes is called a [style change
event].
(Implementations typically have a [style change
event](#style-change-event)
to correspond with their desired screen refresh rate, and when
up-to-date computed style or layout information is needed for a script
API that depends on it.)

Since this specification does not define when a [style change
event](#style-change-event) occurs, and thus what changes to computed values are
considered simultaneous, authors should be aware that changing any of
the transition properties a small amount of time after making a change
that might transition can result in behavior that varies between
implementations, since the changes might be considered simultaneous in
some implementations but not others.

When a [style change
event](#style-change-event) occurs, implementations must start transitions based on
the [computed
values](https://www.w3.org/TR/css-cascade-5/#computed-value) that changed in that event. If an element is not in the
document during that style change event or was not in the document
during the previous style change event, then transitions are not started
for that element in that style change event. Otherwise, define the
[before-change style] as the [computed
values] of all properties on the element as
of the previous [style change event],
except with any styles derived from declarative animations such as CSS
Transitions, CSS Animations
([\[CSS3-ANIMATIONS\]](#biblio-css3-animations "CSS Animations Level 1")),
and SMIL Animations
([\[SMIL-ANIMATION\]](#biblio-smil-animation "SMIL Animation"),
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"))
updated to the current time. Likewise, define the [after-change
style]
as the [computed values] of all properties on
the element based on the information known at the start of that [style
change event], but using the computed
values of the [animation-\*] properties from the [before-change
style](#before-change-style), excluding any styles from CSS Transitions in the
computation, and inheriting from the [after-change
style](#after-change-style)
of the parent. Note that this means the [after-change
style] does not differ from the
[before-change style] due to newly
created or canceled CSS Animations.

Note that this definition of the [after-change
style](#after-change-style) means that a single change can start a transition on
the same property on both an ancestor element and its descendant
element. This can happen when a property change is inherited from one
element with [transition-\*] properties that say to animate the
changing property to another element with [transition-\*]
properties that also say to animate the changing property.

When this happens, both transitions will run, and the transition on the
descendant will override the transition on the ancestor because of the
normal CSS cascading and inheritance rules
([\[CSS3CASCADE\]](#biblio-css3cascade "CSS Cascading and Inheritance Level 3")).

If the transition on the descendant completes before the transition on
the ancestor, the descendant will then resume inheriting the (still
transitioning) value from its parent. This effect is likely not a
desirable effect, but it is essentially doing what the author asked for.

For each element with a [before-change
style](#before-change-style) and an [after-change
style](#after-change-style), and each property (other than shorthands), define the
[matching transition-property value] as the last value in the
[transition-property](#propdef-transition-property) in the element's [after-change
style] that matches the property, as
described in [§ 2.1 The transition-property
Property](#transition-property-property). If there is such a value, then
corresponding to it, there is a [matching transition
duration], a [matching transition delay], and a [matching transition
timing function] in the values in the [after-change
style] of
[transition-duration](#propdef-transition-duration),
[transition-delay](#propdef-transition-delay), and
[transition-timing-function](#propdef-transition-timing-function) (see [the rules on matching
lists](#list-matching)). Define the [combined
duration] of the transition as the
sum of max([matching transition
duration](#matching-transition-duration), [0s]) and the [matching transition
delay](#matching-transition-delay).

When comparing the [before-change
style](#before-change-style) and [after-change
style](#after-change-style) for a given property, the property values are
[transitionable] if they have an [animation
type](https://www.w3.org/TR/web-animations-1/#animation-type) that is *neither* [not
animatable](https://www.w3.org/TR/web-animations-1/#not-animatable) *nor*
[discrete](https://www.w3.org/TR/web-animations-1/#discrete).

 Even if a *property* is defined to have an [animation
type](https://www.w3.org/TR/web-animations-1/#animation-type) that is *not*
[discrete](https://www.w3.org/TR/web-animations-1/#discrete), for a particular pair of *property values* the
[animation type] may be
[discrete]. For example, the [animation
type] of the
[box-shadow](https://www.w3.org/TR/css-backgrounds-3/#propdef-box-shadow) property is [shadow
list](https://www.w3.org/TR/web-animations-1/#combining-shadow-lists), which defines that when the
[inset](https://www.w3.org/TR/css3-background/#shadow-inset) keyword is absent in one value but present in
the other, [discrete] animation is used. As a result
[0px 0px black] and [inset 10px 10px black] are *not*
[transitionable](#transitionable).

For each element and property, the implementation must act as follows:

1. If all of the following are true:
 - the element does not have a [running
 transition](#running-transition) for the property,
 - the [before-change
 style](#before-change-style) is different from the [after-change
 style](#after-change-style) for that property, and the values for the
 property are
 [transitionable](#transitionable),
 - the element does not have a [completed
 transition](#completed-transition) for the property or the [end
 value](#transition-end-value) of the [completed
 transition] is different from the
 [after-change
 style](#after-change-style) for the property,
 - there is a [matching transition-property
 value](#matching-transition-property-value), and
 - the [combined
 duration](#transition-combined-duration) is greater than [0s],

 then implementations must remove the [completed
 transition](#completed-transition) (if present) from the set of completed transitions
 and start a transition whose:
 - [start
 time](#transition-start-time) is the time of the [style change
 event](#style-change-event) plus the [matching transition
 delay](#matching-transition-delay),
 - [end time](#transition-end-time) is the [start
 time](#transition-start-time) plus the [matching transition
 duration](#matching-transition-duration),
 - [start
 value](#transition-start-value) is the value of the transitioning property in the
 [before-change
 style](#before-change-style),
 - [end value](#transition-end-value) is the value of the transitioning property in the
 [after-change
 style](#after-change-style),
 - [reversing-adjusted start
 value](#transition-reversing-adjusted-start-value) is the same as the [start
 value](#transition-start-value), and
 - [reversing shortening
 factor](#transition-reversing-shortening-factor) is 1.
2. Otherwise, if the element has a [completed
 transition](#completed-transition) for the property and the [end
 value](#transition-end-value) of the [completed
 transition] is different from the
 [after-change
 style](#after-change-style) for the property, then implementations must remove
 the [completed transition] from the
 set of [completed transitions].
3. If the element has a [running
 transition](#running-transition) or [completed
 transition](#completed-transition) for the property, and there is **not** a [matching
 transition-property
 value](#matching-transition-property-value), then implementations must
 [cancel](#transition-cancel) the [running
 transition] or remove the [completed
 transition] from the set of
 [completed transitions].
4. If the element has a [running
 transition](#running-transition) for the property, there is a [matching
 transition-property
 value](#matching-transition-property-value), and the [end
 value](#transition-end-value) of the [running
 transition] is **not** equal to the
 value of the property in the [after-change
 style](#after-change-style), then:
 1. If the [current value](#current-value) of the property in the [running
 transition](#running-transition) is equal to the value of the property in the
 [after-change
 style](#after-change-style), or if these two values are not
 [transitionable](#transitionable), then implementations must
 [cancel](#transition-cancel) the [running
 transition].
 2. Otherwise, if the [combined
 duration](#transition-combined-duration) is less than or equal to [0s], or if the
 [current value](#current-value) of the property in the [running
 transition](#running-transition) is not
 [transitionable](#transitionable) with the value of the property in the
 [after-change
 style](#after-change-style), then implementations must
 [cancel](#transition-cancel) the [running
 transition].
 3. Otherwise, if the [reversing-adjusted start
 value](#transition-reversing-adjusted-start-value) of the [running
 transition](#running-transition) is the same as the value of the property in the
 [after-change
 style](#after-change-style) [(see the [section on reversing of
 transitions](#reversing) for why these case exists)],
 implementations must
 [cancel](#transition-cancel) the [running
 transition] and start a new
 transition whose:
 - [reversing-adjusted start
 value](#transition-reversing-adjusted-start-value) is the [end
 value](#transition-end-value) of the [running
 transition](#running-transition) [(Note: This represents the logical start
 state of the transition, and allows some calculations to
 ignore that the transition started before that state was
 reached, which in turn allows repeated reversals of the same
 transition to work correctly),]
 - [reversing shortening
 factor](#transition-reversing-shortening-factor) is the absolute value, clamped to the range
 \[0, 1\], of the sum of:
 1. the output of the timing function of the old transition at
 the time of the [style change
 event](#style-change-event), times the [reversing shortening
 factor](#transition-reversing-shortening-factor) of the old transition
 2. 1 minus the [reversing shortening
 factor](#transition-reversing-shortening-factor) of the old transition.

 [Note: This represents the portion of the space between the
 [reversing-adjusted start
 value](#transition-reversing-adjusted-start-value) and the [end
 value](#transition-end-value) that the old transition has traversed (in
 amounts of the value, not time), except with the absolute
 value and clamping to handle timing functions that have y1 or
 y2 outside the range \[0, 1\].]
 - [start
 time](#transition-start-time) is the time of the [style change
 event](#style-change-event) plus:
 1. if the [matching transition
 delay](#matching-transition-delay) is nonnegative, the [matching transition
 delay], or
 2. if the [matching transition
 delay](#matching-transition-delay) is negative, the product of the new
 transition's [reversing shortening
 factor](#transition-reversing-shortening-factor) and the [matching transition
 delay],
 - [end time](#transition-end-time) is the [start
 time](#transition-start-time) plus the product of the [matching transition
 duration](#matching-transition-duration) and the new transition's [reversing
 shortening
 factor](#transition-reversing-shortening-factor),
 - [start
 value](#transition-start-value) is the [current
 value](#current-value) of the property in the [running
 transition](#running-transition),
 - [end
 value](#transition-end-value) is the value of the property in the
 [after-change
 style](#after-change-style),
 4. Otherwise, implementations must
 [cancel](#transition-cancel) the [running
 transition](#running-transition) and start a new transition whose:
 - [start
 time](#transition-start-time) is the time of the [style change
 event](#style-change-event) plus the [matching transition
 delay](#matching-transition-delay),
 - [end time](#transition-end-time) is the [start
 time](#transition-start-time) plus the [matching transition
 duration](#matching-transition-duration),
 - [start
 value](#transition-start-value) is the [current
 value](#current-value) of the property in the [running
 transition](#running-transition),
 - [end
 value](#transition-end-value) is the value of the property in the
 [after-change
 style](#after-change-style),
 - [reversing-adjusted start
 value](#transition-reversing-adjusted-start-value) is the same as the [start
 value](#transition-start-value), and
 - [reversing shortening
 factor](#transition-reversing-shortening-factor) is 1.

Note that the above rules mean that when the computed value of an
animatable property changes, the transitions that start are based on the
values of the
[transition-property](#propdef-transition-property),
[transition-duration](#propdef-transition-duration),
[transition-timing-function](#propdef-transition-timing-function), and
[transition-delay](#propdef-transition-delay) properties at the time the
animatable property would first have its new computed value. This means
that when one of these [transition-\*] properties changes at the
same time as a property whose change might transition, it is the *new*
values of the [transition-\*] properties that control the
transition.

Example(s):

This provides a way for authors to specify different values of the
[transition-\*] properties for the "forward" and "reverse"
transitions, when the transitions are between two states (but see
[below](#reversing) for special reversing behavior when an *incomplete*
transition is interrupted). Authors can specify the value of
[transition-duration](#propdef-transition-duration),
[transition-timing-function](#propdef-transition-timing-function), or
[transition-delay](#propdef-transition-delay) in the same rule where they specify
the value that triggers the transition, or can change these properties
at the same time as they change the property that triggers the
transition. Since it's the new values of these [transition-\*]
properties that affect the transition, these values will be used for the
transitions *to* the associated transitioning values. For example:

 li {
 transition: background-color linear 1s;
 background: blue;
 }
 li:hover {
 background-color: green;
 transition-duration: 2s; /* applies to the transition *to* the :hover state */
 }

When a list item with these style rules enters the :hover state, the
computed
[transition-duration](#propdef-transition-duration) at the time that
[background-color](https://www.w3.org/TR/CSS2/colors.html#propdef-background-color) would have its new value
([green](https://www.w3.org/TR/css-color-4/#valdef-color-green)) is [2s], so the transition from
[blue](https://www.w3.org/TR/css-color-4/#valdef-color-blue) to [green]
takes 2 seconds. However, when the list item leaves the :hover state,
the transition from [green] to
[blue] takes 1 second.

Note that once the transition of a property has started (including being
in its delay phase), it continues running based on the original timing
function, duration, and delay, even if the
[transition-timing-function](#propdef-transition-timing-function),
[transition-duration](#propdef-transition-duration), or
[transition-delay](#propdef-transition-delay) property changes before the
transition is complete. However, if the
[transition-property](#propdef-transition-property) property changes such that the
transition would not have started, the transition stops (and the
property immediately changes to its final value).

Note that above rules mean that transitions do not start when the
computed value of a property changes as a result of declarative
animation (as opposed to scripted animation). This happens because the
before-change style includes up-to-date style for declarative
animations.

### 3.1. Faster reversing of interrupted transitions

Many common transitions effects involve transitions between two states,
such as the transition that occurs when the mouse pointer moves over a
user interface element, and then later moves out of that element. With
these effects, it is common for a running transition to be interrupted
before it completes, and the property reset to the starting value of
that transition. An example is a hover effect on an element, where a
transition starts when the pointer enters the element, and then the
pointer exits the element before the effect has completed. If the
outgoing and incoming transitions are executed using their specified
durations and timing functions, the resulting effect can be
distractingly asymmetric because the second transition takes the full
specified time to move a shortened distance. Instead, this specification
makes second transition shorter.

The mechanism the above rules use to cause this involves the [reversing
shortening
factor](#transition-reversing-shortening-factor) and the [reversing-adjusted start
value](#transition-reversing-adjusted-start-value). In particular, the reversing behavior is present
whenever the [reversing shortening
factor] is less than
1.

Note that these rules do not fully address the problem for transition
patterns that involve more than two states.

Note that these rules lead to the entire timing function of the new
transition being used, rather than jumping into the middle of a timing
function, which can create a jarring effect.

This was one of several possibilities that was considered by the working
group. See the [reversing demo](examples/transition-reversing-demo)
demonstrating a number of them, leading to a working group resolution
made on 2013-06-07 and edits made on 2013-11-11.

## 4. Application of transitions

When a property on an element is undergoing a transition (that is, when
or after the transition has started and before the [end
time](#transition-end-time) of the transition) the transition adds a style called
the [current value] to the CSS cascade at the level defined for CSS Transitions
in
[\[CSS3CASCADE\]](#biblio-css3cascade "CSS Cascading and Inheritance Level 3").

Note that this means that computed values resulting from CSS transitions
can inherit to descendants just like any other computed values. In the
normal case, this means that a transition of an inherited property
applies to descendant elements just as an author would expect.

Implementations must add this value to the cascade if and only if that
property is not currently undergoing a CSS Animation
([\[CSS3-ANIMATIONS\]](#biblio-css3-animations "CSS Animations Level 1"))
on the same element.

Note that this behavior of transitions not applying to the cascade when
an animation on the same element and property is running does not affect
whether the transition has started or ended. APIs that expose whether
transitions are running (such as [transition
events](#transition-events)) still report that a transition is running.

If the current time is at or before the [start
time](#transition-start-time) of the transition (that is, during the delay phase of
the transition), the [current
value](#current-value) is a
specified style that will compute to the [start
value](#transition-start-value) of the transition.

If the current time is after the [start
time](#transition-start-time) of the transition (that is, during the duration phase
of the transition), the [current
value](#current-value) is a
specified style that will compute to the result of
[interpolating](https://www.w3.org/TR/css-values-4/#interpolation) the property using the following values:

- `V`~`a`~: [start
 value](#transition-start-value) of the transition

- `V`~`b`~: [end
 value](#transition-end-value) of the transition

- `p`: the output of the [timing
 function](#transition-timing-function-property) for input (current
 time - start time) / (end time - start time)

The specific
[interpolation](https://www.w3.org/TR/css-values-4/#interpolation) procedure to be used is defined by the property's
[animation
type](https://www.w3.org/TR/web-animations-1/#animation-type).

## 5. Completion of transitions

[Running transitions](#running-transition) [complete] at a time that is equal
to or after their end time, but prior to the first [style change
event](#style-change-event) whose time is equal to or after their [end
time](#transition-end-time). When a transition completes, implementations must move
all transitions that complete at that time from the set of [running
transitions] to the set of [completed
transitions](#completed-transition) and then fire the [events](#transition-events) for
those completions. [(Note that doing otherwise, that is, firing some of
the events before doing all of the moving from [running
transitions](#running-transition) to [completed
transitions](#completed-transition), could allow a style change event to happen without the
necessary transitions completing, since firing the event could cause a
style change event, if an event handler requests up-to-date computed
style or layout data.)]

## [6. ][[Transition Events]]
The creation, beginning, completion, and cancellation of CSS transitions
generate corresponding DOM Events. An event is
[dispatched](https://html.spec.whatwg.org/multipage/infrastructure.html#concept-event-dispatch) to the element for each property that undergoes a
transition on that element. This allows a content developer to perform
actions that synchronize with changes to transitions.

Each event provides the name of the property the transition is
associated with as well as the duration of the transition.

### 6.1. Interface [`TransitionEvent`]
The
[`TransitionEvent`](#transitionevent) interface provides specific contextual information
associated with transitions.

#### 6.1.1. IDL Definition

```
[Exposed=Window]
interface TransitionEvent : Event {
 constructor(CSSOMString type, optional TransitionEventInit transitionEventInitDict = );
 readonly attribute CSSOMString propertyName;
 readonly attribute double elapsedTime;
 readonly attribute CSSOMString pseudoElement;
};

dictionary TransitionEventInit : EventInit {
 CSSOMString propertyName = "";
 double elapsedTime = 0.0;
 CSSOMString pseudoElement = "";
};
```

#### 6.1.2. Attributes

[`propertyName`]`, `` of type `[`CSSOMString`](https://www.w3.org/TR/cssom-1/#cssomstring)`, readonly`

: The name of the CSS property associated with the transition.

 Note: This is always the name of a longhand property. See
 [transition-property](#propdef-transition-property) for how specifying shorthand
 properties causes transitions on longhands.

[`elapsedTime`]`, `` of type `[`double`](https://webidl.spec.whatwg.org/#idl-double)`, readonly`

: The amount of time the transition has been running, in seconds, when
 this event fired not including any time spent in the delay phase.
 The calculation for of this member is defined along with each event
 type.

[`pseudoElement`]`, `` of type `[`CSSOMString`](https://www.w3.org/TR/cssom-1/#cssomstring)`, readonly`

: The name (beginning with two colons) of the CSS pseudo-element on
 which the transition occurred (in which case the target of the event
 is that pseudo-element's corresponding element), or the empty string
 if the transition occurred on an element (which means the target of
 the event is that element).

[`TransitionEvent(type, transitionEventInitDict)`]
is an [event
constructor](https://dom.spec.whatwg.org/#constructing-events).

### 6.2. Types of `TransitionEvent`

The different types of transition events that can occur are:

[`transitionrun`]

: The [`transitionrun`](#transitionrun) event occurs when a transition is created (i.e.,
 when it is added to the set of [running
 transitions](#running-transition)).

 A negative
 [transition-delay](#propdef-transition-delay) will cause the event to fire
 with an
 [`elapsedTime`](#Events-TransitionEvent-elapsedTime) equal to the absolute value of the delay capped to
 the
 [transition-duration](#propdef-transition-duration) of the animation. That is, the
 elapsed time is equal to
 `min(max(-`[`transition-delay`](#propdef-transition-delay)`, 0), `[`transition-duration`](#propdef-transition-duration)`)`.

 - Bubbles: Yes
 - Cancelable: No
 - Context Info: propertyName, elapsedTime, pseudoElement

[`transitionstart`]

: The
 [`transitionstart`](#transitionstart) event occurs when a transition's delay phase ends.

 The value of
 [`elapsedTime`](#Events-TransitionEvent-elapsedTime) for
 [`transitionstart`](#transitionstart) events is the same as the value used for
 [`transitionrun`](#transitionrun) events.

 - Bubbles: Yes
 - Cancelable: No
 - Context Info: propertyName, elapsedTime, pseudoElement

[`transitionend`]

: The [`transitionend`](#transitionend) event occurs at the completion of the transition.
 In the case where a transition is removed before completion, such as
 if the
 [transition-property](#propdef-transition-property) is removed, then the event will
 not fire.

 The value of
 [`elapsedTime`](#Events-TransitionEvent-elapsedTime) for this event is equal to the value of
 [transition-duration](#propdef-transition-duration).

 - Bubbles: Yes
 - Cancelable: No
 - Context Info: propertyName, elapsedTime, pseudoElement

[`transitioncancel`]

: The
 [`transitioncancel`](#transitioncancel) event occurs when a transition is
 [canceled](#transition-cancel).

 The
 [`elapsedTime`](#Events-TransitionEvent-elapsedTime) for
 [`transitioncancel`](#transitioncancel) events is the number of seconds from the end of the
 transition's delay to the moment when the transition was canceled.
 If the transition had a negative
 [transition-delay](#propdef-transition-delay), the beginning of the
 transition is the moment equal to the absolute value of
 [transition-delay]
 seconds *prior* to when the transition was actually triggered.
 Alternatively, if the transition had a positive
 [transition-delay]
 and the event is fired before the transition's delay has expired,
 the
 [`elapsedTime`](https://www.w3.org/TR/css-animations-1/#dom-animationevent-elapsedtime) will be zero.

 - Bubbles: Yes
 - Cancelable: No
 - Context Info: propertyName, elapsedTime, pseudoElement

### 6.3. Event handlers on elements, `Document` objects, and `Window` objects

The following are the [event
handlers](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers) (and their corresponding [event handler event
types](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)) that must be supported by all [HTML
elements](https://html.spec.whatwg.org/multipage/infrastructure.html#html-elements), as both [event handler content
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-content-attributes) and [event handler IDL
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes); and that must be supported by all
[`Document`](https://html.spec.whatwg.org/#document) and
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) objects, as [event handler IDL
attributes]:

[Event
handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers)

[Event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)

[`ontransitionrun`](#dom-globaleventhandlers-ontransitionrun)

[transitionrun](#transitionrun)

[`ontransitionstart`](#dom-globaleventhandlers-ontransitionstart)

[transitionstart](#transitionstart)

[`ontransitionend`](#dom-globaleventhandlers-ontransitionend)

[transitionend](#transitionend)

[`ontransitioncancel`](#dom-globaleventhandlers-ontransitioncancel)

[transitioncancel](#transitioncancel)

## 7. DOM Interfaces

This specification extends the
[`GlobalEventHandlers`](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers) interface mixin from HTML to add [event handler IDL
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) for [transition events](#transition-events) as defined
in [§ 6.3 Event handlers on elements, Document objects, and Window
objects](#event-handlers-on-elements-document-objects-and-window-objects).

### 7.1. IDL Definition

```
partial interface mixin GlobalEventHandlers {
 attribute EventHandler ontransitionrun;
 attribute EventHandler ontransitionstart;
 attribute EventHandler ontransitionend;
 attribute EventHandler ontransitioncancel;
};
```

## 8. Security Considerations

*This section is not normative.*

The security implications of this specification are limited because it
doesn't allow Web content to do things that it could not do before.
Rather, it allows things that could previously be done with script to be
done declaratively, and it ways that implementations can optimize (for
frame rate and CPU usage).

One of the major categories of optimizations that implementations can
make is implementing animation of certain high-value properties (such as
[transform](https://www.w3.org/TR/css-transforms-1/#propdef-transform) and
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity)) run on a browser's compositor
thread or process without updating style or layout on the main Web
content thread unless up-to-date style data are needed. This
optimization often requires allocations of graphics memory to display
the contents of the element being animated. Implementations should take
care to ensure that Web content cannot trigger unsafe out-of-memory
handling by using large numbers of animations or animations on elements
covering large areas (where large may be defined in terms of
pre-transform or post-transform size).

## 9. Privacy Considerations

*This section is not normative.*

As for security, the privacy considerations of this specification are
limited because it does not allow Web content to do things that it could
not do before.

This specification may provide additional mechanisms that help to
determine characteristics of the user's hardware or software. However,
ability to determine performance characteristics of the user's hardware
or software is common to many Web technologies, and this specification
does not introduce new capabilities.

As described in [§ 10 Accessibility Considerations](#accessibility),
implementations may provide mitigations to help users with disabilities.
These mitigations are likely to be detectable by Web content, which
means that users who would benefit from these mitigations may face a
tradeoff between keeping their disability private from the Web content
or benefiting from the mitigation.

## 10. Accessibility Considerations

*This section is not normative.*

### 10.1. Motion

This specification provides declarative mechanisms for animations that
previously needed to be done using script. Providing a declarative
mechanism has multiple effects: it makes such animations easier to make
and thus likely to be more common, but it also makes it easier for user
agents to modify those animations if such modifications are needed to
meet a user's accessibility needs.

Thus, users who are sensitive to movement, or who require additional
time to read or understand content, may benefit from user agent features
that allow animations to be disabled or slowed down. (But see [§ 9
Privacy Considerations](#privacy) for information on the privacy
implications of such mitigations.)

User agent implementors should be aware that Web content may depend on
the firing of [transition events](#transition-events), so
implementations of such mitigations may wish to fire transition events
even if the transitions were not run as continuous animations. However,
it is probably poor practice for Web content to depend on such events to
function correctly.

### 10.2. Cascade

The CSS
[cascade](https://www.w3.org/TR/css-cascade-6/#cascade) is a general mechanism in CSS that allows user needs to
interact with author styles. This specification interacts with the
cascade, but since it only allows animation between values that result
from the existing cascade rules, it does not interfere with the user's
ability to force CSS properties to have particular values.

The cascade also allows users to disable transitions entirely by
overriding the transition properties.

## 11. Changes

### 11.1. Changes since Working Draft of 11 October 2018

The following are the substantive changes made since the [Working Draft
dated 11 October
2018](https://www.w3.org/TR/2018/WD-css-transitions-1-20181011/):

- Clarified that
 [`GlobalEventHandlers`](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers) is a mixin.

- Replaced defunct `<timing-function>` by
 [\<easing-function\>](https://www.w3.org/TR/css-easing-2/#typedef-easing-function).

- Added default value to
 [`transitionEventInitDict`](#dom-transitionevent-transitionevent-type-transitioneventinitdict-transitioneventinitdict) dictionary.

- Removed trailing semicolon from
 [\<single-transition-property\>](#single-transition-property) syntax.

- Associated event definitions with their
 [`GlobalEventHandlers`](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers) container.

- Added range definition notations to property values.

- Added Web Platform Tests coverage.

- Minor editorial fixes and improvements.

For more details on these changes, see the version control [change
log](https://github.com/w3c/csswg-drafts/commits/main/css-transitions-1/Overview.bs).

### 11.2. Earlier changes

For changes in earlier working drafts:

1. See the [changes section in the 11 October 2018 Working
 Draft](https://www.w3.org/TR/2018/WD-css-transitions-1-20181011/#changes).

2. See the [changes section in the 30 November 2017 Working
 Draft](https://www.w3.org/TR/2017/WD-css-transitions-1-20171130/#changes).

3. See the [changes section in the 19 November 2013 Working
 Draft](https://www.w3.org/TR/2013/WD-css3-transitions-20131119/#changes).

4. See the [the
 ChangeLog](https://www.w3.org/TR/2013/WD-css3-transitions-20130212/ChangeLog)
 for changes in previous working drafts.

5. For more details on these changes, see the version control change
 logs, which are split in many parts because of file renaming:

 - [change log since 2017 October
 12](https://github.com/w3c/csswg-drafts/commits/main/css-transitions-1/Overview.bs),

 - [change log from 2015 January 26 to 2017 October
 12](https://hg.csswg.org/drafts/log/tip/css-transitions/Overview.bs),

 - [change log from 2013 March 28 to 2015 January
 26](https://hg.csswg.org/drafts/log/tip/css-transitions/Overview.src.html),

 - [change log before 2013 March
 28](https://hg.csswg.org/drafts/log/tip/css3-transitions/Overview.src.html).

## 12. Acknowledgments

Thanks especially to the feedback from Tab Atkins, Carine Bournez, Aryeh
Gregor, Vincent Hardy, Anne van Kesteren, Cameron McCormack, Alex
Mogilevsky, Jasper St. Pierre, Estelle Weyl, and all the rest of the
[www-style](https://lists.w3.org/Archives/Public/www-style/) community.
