## 1. Introduction

::: informative-bg
*This section is non-normative*

This specification defines a model (the [Web Animations
model]) for supporting animation and synchronization on the Web
platform. It is intended that other specifications will build on this
model and expose its features through declarative means.

In addition, this specification also defines a programming interface to
the model (the [Web Animations [API]], defined in [§ 6 Programming
interface](#programming-interface)) that may be implemented by user
agents that provide support for scripting.

### 1.1. Use cases

The [Web Animations
model](#web-animations-model) is intended to provide the features necessary for
expressing CSS Transitions
[\[CSS-TRANSITIONS-1\]](#biblio-css-transitions-1 "CSS Transitions Module Level 1"),
CSS Animations
[\[CSS-ANIMATIONS-1\]](#biblio-css-animations-1 "CSS Animations Level 1"),
and SVG
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)").
As such, the use cases of the [Web Animations
model] are the union of use cases for
those three specifications.

The use cases for the [Web Animations
API](#web-animations-api)
include the following:

Inspecting running animations

: Often Web applications need to wait for certain animated effects to
 complete before updating some state. The [Web Animations
 API](#web-animations-api) allows such applications to wait for all currently
 running animation to complete, regardless of whether they are
 defined by CSS Transitions, CSS Animations, SVG animations, or
 created directly using the [Web Animations
 API].

 :::
 (#example-e8eccc9e)
 ``` highlight
 // Wait until all animations have finished before removing the element
 Promise.all(
 elem.getAnimations().map(animation => animation.finished)
 ).then(() => elem.remove());
 ```
 :::

 Alternatively, applications can query the playback state of
 animations without waiting.

 :::
 (#example-9a95d87d)
 ``` highlight
 const isAnimating = elem.getAnimations().some(
 animation => animation.playState === 'running'
 );
 ```
 :::

Controlling running animations

: It is sometimes useful to perform [playback
 control](#playback-control) on animations so that they can respond to external
 inputs. For example, it might be necessary to pause all existing
 animations before displaying a modal dialog so that they do not
 distract the user's attention.

 :::
 (#example-e7bbf635)
 ``` highlight
 // Pause all existing animations in the document
 for (const animation of document.getAnimations()) {
 animation.pause()
 }
 ```
 :::

Creating animations from script

: While it is possible to use ECMAScript to perform animation using
 `requestAnimationFrame`
 [\[HTML\]](#biblio-html "HTML Standard"), such
 animations behave differently to declarative animation in terms of
 how they are represented in the CSS cascade and the performance
 optimizations that are possible, such as performing the animation on
 a separate thread. Using the [Web Animations
 API](#web-animations-api), it is possible to create animations from script
 that have the same behavior and performance characteristics as
 declarative animations.

 :::
 (#example-824e8c83)
 ``` highlight
 // Fade out quickly
 elem.animate({ transform: 'scale(0)', opacity: 0 }, 300);
 ```
 :::

Animation debugging

: In a complex application, it can be difficult to determine how an
 element arrived in its present state. The [Web Animations
 API](#web-animations-api) can be used to inspect running animations to answer
 questions such as, "Why is the opacity of this element changing?"

 :::
 (#example-6c6854a7)
 ``` highlight
 // Print the id of any opacity animations on elem
 for (const animation of elem.getAnimations()) {
 if (
 animation.effect instanceof KeyframeEffect &&
 animation.effect
 .getKeyframes()
 .some(frame => frame.hasOwnProperty('opacity'))
 ) {
 console.log(animation.id);
 }
 }
 ```
 :::

 Likewise, in order to fine tune animations, it is often necessary to
 reduce their playback rate and replay them.

 :::
 (#example-06eda695)
 ``` highlight
 // Slow down and replay any transform animations
 const transformAnimations = elem.getAnimations().filter(
 animation =>
 animation.effect instanceof KeyframeEffect &&
 animation.effect.getKeyframes().some(
 frame => frame.hasOwnProperty('transform')
 )
 );

 for (const animation of transformAnimations) {
 animation.currentTime = 0;
 animation.updatePlaybackRate(0.5);
 }
 ```
 :::

Testing animations

: In order to test applications that make use of animations it is
 often impractical to wait for such animations to run to completion.
 Rather, it is desirable to seek the animations to specific times.

 :::
 (#example-d0c0c637)
 ``` highlight
 // Seek to the half-way point of an animation and check that the opacity is 50%
 for (const animation of elem.getAnimations()) {
 const { delay, activeDuration } = animation.effect.getComputedTiming();
 animation.currentTime = delay + activeDuration / 2;
 }
 assert.strictEqual(getComputedStyle(elem).opacity, '0.5');

 // Check that the loading screen is hidden after the animations finish
 for (const animation of elem.getAnimations()) {
 animation.finish();
 }
 // Wait one frame so that event handlers have a chance to run
 requestAnimationFrame(() => {
 assert.strictEqual(
 getComputedStyle(document.querySelector('#loading')).display, 'none');
 });
 ```
 :::

### 1.2. Relationship to other specifications

CSS Transitions
[\[CSS-TRANSITIONS-1\]](#biblio-css-transitions-1 "CSS Transitions Module Level 1"),
CSS Animations
[\[CSS-ANIMATIONS-1\]](#biblio-css-animations-1 "CSS Animations Level 1"),
and SVG
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)")
all provide mechanisms that generate animated content on a Web page.
Although the three specifications provide many similar features, they
are described in different terms. This specification proposes an
abstract animation model that encompasses the common features of all
three specifications. This [Web Animations
model](#web-animations-model) is backwards-compatible with the current behavior of
these specifications such that they can be defined in terms of this
model without any observable change.

The animation features in SVG 1.1 are defined in terms of SMIL Animation
[\[SMIL-ANIMATION\]](#biblio-smil-animation "SMIL Animation").
It is intended that by defining SVG's animation features in terms of the
[Web Animations
model](#web-animations-model), the dependency between SVG and SMIL Animation can be
removed.

As with [animation frame
callbacks](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html.html#animation-frames) (commonly referred to as \"requestAnimationFrame\")
[\[HTML\]](#biblio-html "HTML Standard"), the [Web
Animations API](#web-animations-api) allows animations to be created from script. The
animations created using the [Web Animations
API], however, once created, are executed
entirely by the user agent, meaning they share the same performance
characteristics as animations defined declaratively. Using this
interface it is possible to create animations from script in a simpler
and more performant manner.

The time values used within the [Web Animations
API](#web-animations-api)
correspond with those used in [animation frame
callbacks](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html.html#animation-frames)
[\[HTML\]](#biblio-html "HTML Standard") and their
execution order is defined such that the two interfaces can be used
simultaneously without conflict.

The [Web Animations
API](#web-animations-api)
component of this specification makes some additions to interfaces
defined in HTML
[\[HTML\]](#biblio-html "HTML Standard").

### 1.3. Overview of this specification

This specification begins by defining an abstract model for animation,
the [Web Animations
model](#web-animations-model). This is followed by a programming interface, [Web
Animations API](#web-animations-api), defined in terms of the abstract model. The
programming interface is only relevant to user agents that provide
scripting support.

## 2. Specification conventions

This specification begins by describing abstract concepts---​such as
[animations](#concept-animation) and [animation
effects](#animation-effect)---​and properties that belong to them, such as their
[playback rate](#playback-rate)
or [iteration duration](#iteration-duration). In addition to these properties, there are often
specific procedures for updating these properties, such as the procedure
to [set the playback
rate](#set-the-playback-rate) or the procedure to [set the start
time](#set-the-start-time)
of an animation.

Where this specification does not specifically link to a procedure, text
that requires the user agent to update a property, such as "make
`animation`'s [start
time](#animation-start-time) [unresolved](#unresolved)", should be understood to refer to updating the
property directly *without* invoking any related procedure.

Further conventions not specific to this specification are described in
[Document conventions](#w3c-conventions).

## 3. Web Animations model overview

At a glance, the [Web Animations
model](#web-animations-model) consists of two largely independent pieces: a [timing
model](#timing-model-dfn) and
an [animation model](#animation-model-dfn). The roles of these pieces are as follows:

[timing model]

: Takes a moment in time and converts it to a proportional distance
 within a single iteration of an animation, called the [iteration
 progress](#iteration-progress). The current [iteration
 index](#current-iteration-index) is also recorded since some animations vary each
 time they repeat. The [Web Animations timing
 model](#web-animations-timing-model) is defined in [§ 4 Timing model](#timing-model).

[animation model].

: Takes the [iteration
 progress](#iteration-progress) and [iteration
 index](#current-iteration-index) values produced by the [timing
 model](#timing-model-dfn) and converts them into a series of corresponding
 values to apply to the [target
 properties](#target-property). The [Web Animations animation
 model](#web-animations-animation-model) is defined in [§ 5 Animation
 model](#animation-model).

::: informative-bg
*This section is non-normative*

Graphically, this flow can be represented as follows:

![Overview of the operation of the [Web Animations
model](#web-animations-model).\
The current time is input to the [timing
model](#timing-model-dfn)
which produces an [iteration
progress](#iteration-progress) value and an [iteration
index](#current-iteration-index).\
These parameters are used as input to the [animation
model](#animation-model-dfn) which produces the [target
property](#target-property)
values to
apply.](images/timing-and-animation-models.svg){a
width="600"}

For example, consider an animation that:

- starts after 3 seconds,

- runs twice,

- takes 2 seconds every time, and

- changes the width of a rectangle from 50 pixels to 100 pixels.

The first three points describe the [timing
model](#timing-model-dfn):
at a time of 6 seconds, it calculates that the animation should be
half-way through its second iteration and produces the result 0.5. The
animation model then uses that information to calculate a width.

This specification begins with the [timing model](#timing-model) and
then proceeds to the [animation model](#animation-model).

## 4. Timing model

This section describes and defines the behavior of the [Web Animations
[timing model](#timing-model-dfn)].

Timing in the [Web Animations
model](#web-animations-model) is represented through a hierarchy of relationships
between [timing nodes], in which parent nodes provide timing information to their
child nodes in the form of [time
values](#time-value), ultimately
resulting in an [iteration
progress](#iteration-progress) and [iteration
index](#current-iteration-index) supplied to the [animations
model](#animation-model-dfn)

### 4.1. Timing model characteristics

::: informative-bg
*This section is non-normative*

Two features characterize the Web Animations timing model: it is
*stateless* and it is *hierarchical*.

#### 4.1.1. Stateless

The Web Animations [timing
model](#timing-model-dfn)
operates by taking an input [time
value](#time-value) and producing
an output [iteration
progress](#iteration-progress). Since the output is based solely on the input time and
is independent of previous inputs, the model can be described as
stateless. This gives the model the following properties:

Frame-rate independent

: Since the output is independent of previous inputs, the rate at
 which the model is updated will not affect its progress. Provided
 the input times are proportional to the progress of real-world time,
 animations will progress at an identical rate regardless of the
 capabilities of the device running them.

Direction-agnostic

: Since the sequence of inputs is insignificant, the model is
 directionless. This means that the model can be updated to an
 arbitrary moment without requiring any specialized handling.

Constant-time seeking

: Since each input is independent of the previous input, the
 processing required to perform a seek operation, even far into the
 future, is at least potentially constant.

There are a few exceptions to the stateless behavior of the timing
model.

Firstly, a number of methods defined in the [programming
interface](#programming-interface) to the model provide play control
such as pausing an animation. These methods are defined in terms of the
time at which they are called and are therefore stative. These methods
are provided primarily for convenience and are not part of the core
timing model, but are layered on top.

Similarly, the [finishing behavior](#reaching-the-end) of animations
means that dynamic changes to the end time of the media ([associated
effect](#animation-associated-effect)) of an animation can produce a different result
depending on when the change occurs. This behavior is somewhat
unfortunate but has been deemed intuitive and consistent with HTML. As a
result, the model can only truly be described as stateless *in the
absence of dynamic changes to its timing properties*.

Finally, each time the model is updated, it can be considered to
establish a temporary state. While this temporary state affects the
values returned from the [programming
interface](#programming-interface), it has no influence on the
subsequent updates and hence does not conflict with the stateless
qualities described above.

#### 4.1.2. Hierarchical

The other characteristic feature of the timing model is that time is
inherited. Time begins at a timeline and cascades down a number of steps
to each animation effect. At each step, time can be shifted backwards or
forwards, scaled, reversed, paused, and repeated.

![A hierarchy of timing nodes. Each node in the tree derives its time
from its parent
node.](images/time-hierarchy.svg){a
width="350"}

In this level of the specification the hierarchy is shallow. A
subsequent level of this specification will introduce the concept of
group effects which allows for deeper timing hierarchies.

### 4.2. Time values

A [time value]
in the [Web Animations
model](#web-animations-model) is a value that serves the purpose of synchronization.
[Time values](#time-value) are
real numbers that nominally represent a number of milliseconds from some
moment. However, the connection between [time
values] and wall-clock milliseconds can be
obscured by any number of transformations applied to the value as it
passes through the time hierarchy.

 In the future there could be timelines that are based
on scroll position or UI gestures in which case the connection between
time values and milliseconds will be weakened even further.

A [time value](#time-value) can be
[unresolved],
i.e. represent the absence of a meaningful [time
value]. This can happen if a [timing
node](#timing-nodes) is not in a
state to produce a [time value].

### 4.3. Timelines

A [timeline] is a
[timing node](#timing-nodes)
that provides a source of [time
values](#time-value). At any given
moment, a [timeline](#timeline) has a
single current [time value] known simply as the
timeline's [current time]. Changes in a
[timeline]'s [current
time](#timeline-current-time) are ultimately what drive
[animations](#concept-animation) in the [Web Animations
model](#web-animations-model).

A [timeline](#timeline) might not
always be able to return a meaningful [time
value](#time-value), but only an
[unresolved](#unresolved) time
value. For example, its [current
time](#timeline-current-time) might be defined relative to a moment that has yet to
occur, such as the firing of a document's load event. A
[timeline] is considered to be
[inactive] when its [time value] is
[unresolved], and [active] otherwise.

A [timeline](#timeline) is
[monotonically increasing] if its reported [current
time](#timeline-current-time) is always greater than or equal to its previously
reported [current time].

Specific types of [timelines](#timeline) may define a procedure to [convert a timeline time to
an origin-relative time] for [time
value](#time-value)
`time`, so that the [time values]
produced by wallclock-based timelines can be compared.

A [timeline](#timeline) can be
[associated with a document].

#### 4.3.1. Document timelines

A [document timeline] is a type of
[timeline](#timeline) that is
[associated with a
document](#timeline-associated-with-a-document) and whose [current
time](#timeline-current-time) is calculated as a fixed offset from the
`now` timestamp provided each time the [update animations and
send
events](#update-animations-and-send-events) procedure is run. This fixed offset is equal to the
[current time] of the [default document
timeline](#document-default-document-timeline) when this timeline's [current
time] was zero, and is thus referred to
as the document timeline's [origin time].

There must be a better term than
\"origin time\"--- it's too similar to \"time origin\". [\[Issue
#2079\]](https://github.com/w3c/csswg-drafts/issues/2079)

Prior to establishing the [time
origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-time-origin) for its associated document, a [document
timeline](#document-timeline) is
[inactive](#inactive-timeline).

After a [document
timeline](#document-timeline) becomes
[active](#active-timeline), it
is [monotonically
increasing](#monotonically-increasing-timeline).

A [document timeline](#document-timeline) that is associated with a
[`Document`](https://html.spec.whatwg.org/#document) that is not an [active
document](https://html.spec.whatwg.org/multipage/browsers.html#active-document) is also considered to be
[inactive](#inactive-timeline).

To [convert a timeline time, `timeline time`, to an
origin-relative
time](#timeline-time-to-origin-relative-time) for a document timeline, `timeline`, return
the sum of the `timeline time` and `timeline`'s
[origin time](#origin-time). If
`timeline` is inactive, return an
[unresolved](#unresolved) [time
value](#time-value).

##### 4.3.1.1. The default document timeline

Each
[`Document`](https://html.spec.whatwg.org/#document) has a [document
timeline](#document-timeline) called the [default document
timeline]. The [default document
timeline](#document-default-document-timeline) is unique to each document and persists for the
lifetime of the document, including calls to
[document.open()](https://html.spec.whatwg.org/multipage/webappapis.html#dom-document-open)
[\[HTML\]](#biblio-html "HTML Standard").

The [default document
timeline](#document-default-document-timeline) has an [origin
time](#origin-time) of zero.

##### 4.3.1.2. Relationship to wall-clock time

::: informative-bg
*This section is non-normative*

Since no scaling is applied to the `now` timestamp values
provided to a [document
timeline](#document-timeline), the [time values](#time-value) it produces will be proportional to wall-clock
milliseconds.

Furthermore, since the [time values](#time-value) of the [default document
timeline](#document-default-document-timeline) have a zero offset from the [time
origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-time-origin), `document.timeline.currentTime` will roughly
correspond to
[`Performance.now()`](https://www.w3.org/TR/hr-time/#dom-performance-now)
[\[HR-TIME\]](#biblio-hr-time "High Resolution Time")
with the exception that `document.timeline.currentTime` does not change
in between calls to the [update animations and send
events](#update-animations-and-send-events) procedure.

### 4.4. Animation Frames

When asked to [update animations and send
events] for a
[`Document`](https://html.spec.whatwg.org/#document) `doc` at timestamp `now`, run
these steps:

1. Update the [current
 time](#timeline-current-time) of all timelines [associated with
 `doc`](#timeline-associated-with-a-document) passing `now` as the timestamp.

 :::
 Due to the hierarchical nature of the timing model, updating the
 [current
 time](#timeline-current-time) of a [timeline](#timeline) also involves:
 - Updating the [current
 time](#animation-current-time) of any
 [animations](#concept-animation) [associated
 with](#associated-with-a-timeline) the timeline.

 - Running the [update an animation's finished
 state](#update-an-animations-finished-state) procedure for any animations whose [current
 time](#animation-current-time) has been updated.

 - Queueing [animation
 events](#animation-events) for any such animations.
 :::

2. [Remove replaced
 animations](#remove-replaced-animations) for `doc`.

3. [Perform a microtask
 checkpoint](https://html.spec.whatwg.org/multipage/webappapis.html#perform-a-microtask-checkpoint).

 This is to ensure that any microtasks queued up as
 a result of resolving or rejecting Promise objects as part of
 updating timelines in the previous step, run their callbacks prior
 to dispatching animation events.

4. Let `events to dispatch` be a copy of `doc`'s
 [pending animation event
 queue](#pending-animation-event-queue).

5. Clear `doc`'s [pending animation event
 queue](#pending-animation-event-queue).

6. Perform a stable sort of the [animation
 events](#animation-events) in `events to dispatch` as follows:

 1. Sort the events by their [scheduled event
 time](#scheduled-event-time) such that events that were scheduled to occur
 earlier sort before events scheduled to occur later, and events
 whose scheduled event time is
 [unresolved](#unresolved)
 sort before events with a
 [resolved](https://webidl.spec.whatwg.org/#resolve) scheduled event time.

 2. Within events with equal [scheduled event
 times](#scheduled-event-time), sort by their [composite
 order](#animation-composite-order).

 The purpose of sorting events is to ensure
 that, as best possible, even on devices with differing
 capabilities and hence different frame rates, events are
 dispatched in a consistent order.

 The requirement for the sort to be a stable
 sort is because sometimes multiple events can be queued with the
 same scheduled event time. For example, a CSS animation with a
 duration of zero would dispatch both an `animationstart` and an
 `animationend` event with the same scheuled event time, and the
 order of these events should be preserved.

7. [Dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch) each of the events in
 `events to dispatch` at their corresponding target using
 the order established in the previous step.

It is often convenient to describe each time this procedure is invoked
as establishing a new [animation frame]. Changes to the timing properties
of [animations](#concept-animation) or [animation
effects](#animation-effect),
or the addition and removal of the objects can cause the output of the
timing or animation model to change, but these operations in themselves
do not create a new [animation
frame](#animation-frame);
rather they merely update the current [animation
frame].

### 4.5. Animations

An [animation] is a [timing node](#timing-nodes) that binds an [animation
effect](#animation-effect)
child, called its [associated effect], to a
[timeline](#timeline) parent so that
it runs. Both of these associations are optional and configurable such
that an [animation](#concept-animation) can have no [associated
effect](#animation-associated-effect) or [timeline] at a given moment.

[Animations](#concept-animation) also allow run-time control of the connection between
the [animation effect](#animation-effect) and its [timeline](#timeline), through [playback control] functions such as
[pausing](#pausing-an-animation-section),
[seeking](#setting-the-current-time-of-an-animation), and [speed
control](#speed-control).

[Time values](#time-value) flow
from the [timeline](#timeline)
through the [animation](#concept-animation) to the [associated
effect](#animation-associated-effect). The [time value] provided to an
[animation]'s [associated
effect] is called the
[animation]'s [current
time].

 The relationship between an animation and an [animation
effect](#animation-effect)
is analogous to that of a DVD player and a DVD.

In addition to its [timeline](#timeline), [associated
effect](#animation-associated-effect), and [current
time](#animation-current-time) an
[animation](#concept-animation) has the following:

[document for timing]

: The
 [`Document`](https://html.spec.whatwg.org/#document) with which the
 [animation](#concept-animation)'s [timeline](#timeline) is
 [associated](#timeline-associated-with-a-document). If an animation is not associated with a timeline,
 or its timeline is not associated with a document, then it has no
 [document for
 timing](#animation-document-for-timing).

[start time]

: The [time value](#time-value)
 of its [timeline](#timeline)
 when its [associated
 effect](#animation-associated-effect) is scheduled to begin playback. An animation's
 start time is initially
 [unresolved](#unresolved).

[hold time]

: A [time value](#time-value),
 which is used to freeze the animation's [current
 time](#animation-current-time) output in circumstances such as pausing. The [hold
 time](#animation-hold-time) is initially
 [unresolved](#unresolved).

 Together, the [start
time](#animation-start-time) and [hold
time](#animation-hold-time) of an animation determine both its [current
time](#animation-current-time) (see [§ 4.5.1 Calculating the current time of an
animation](#the-current-time-of-an-animation)) and its [play
state](#animation-play-state) (see [§ 4.5.17 Play states](#play-states)).

In order to establish the relative ordering of conflicting
[animations](#concept-animation), animations are appended to a [global animation
list]
in the order in which they are created. Certain [classes of
animations](#animation-class),
however, may provide alternative means of ordering animations (see
[§ 5.4.1 Animation classes](#animation-classes)).

#### 4.5.1. Calculating the current time of an animation

The [current
time](#animation-current-time) of an
[animation](#concept-animation) is calculated from the first matching condition below:

If the animation's [hold
time](#animation-hold-time) is [resolved](#unresolved),

The [current
time](#animation-current-time) is the animation's [hold
time](#animation-hold-time).

If *any* of the following are true:

- the animation has no associated
 [timeline](#timeline), or

- the associated [timeline](#timeline) is
 [inactive](#inactive-timeline), or

- the animation's [start
 time](#animation-start-time) is [unresolved](#unresolved),

The [current
time](#animation-current-time) is an [unresolved](#unresolved) time value.

Otherwise,

> [`current time`](#animation-current-time)` = (``timeline time`` − `[`start time`](#animation-start-time)`) × `[`playback rate`](#playback-rate)

Where `timeline time` is the current [time
value](#time-value) of the
associated [timeline](#timeline).
The [playback rate](#playback-rate) value is defined in [§ 4.5.15 Speed
control](#speed-control).

#### 4.5.2. Setting the timeline of an animation

The procedure to [set the timeline of an
animation], `animation`,
to `new timeline` which may be null, is as follows:

1. Let `old timeline` be the current
 [timeline](#timeline) of
 `animation`, if any.

2. If `new timeline` is the same object as
 `old timeline`, abort this procedure.

3. Let the [timeline](#timeline)
 of `animation` be `new timeline`.

4. If the [start
 time](#animation-start-time) of `animation` is
 [resolved](#unresolved), make
 `animation`'s [hold
 time](#animation-hold-time) [unresolved].

 This step ensures that the [finished play
 state](#play-state-finished) of `animation` is not "sticky", but is
 re-evaluated based on its updated [current
 time](#animation-current-time).

5. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

#### 4.5.3. Setting the associated effect of an animation

The procedure to [set the associated effect of an
animation],
`animation`, to `new effect` which may be null, is
as follows:

1. Let `old effect` be the current [associated
 effect](#animation-associated-effect) of `animation`, if any.

2. If `new effect` is the same object as
 `old effect`, abort this procedure.

3. If `animation` has a [pending pause
 task](#pending-pause-task), reschedule that task to run as soon as
 `animation` is [ready](#ready).

4. If `animation` has a [pending play
 task](#pending-play-task), reschedule that task to run as soon as
 `animation` is [ready](#ready) to play `new effect`.

5. If `new effect` is not `null` and if
 `new effect` is the [associated
 effect](#animation-associated-effect) of another
 [animation](#concept-animation), `previous animation`, run the procedure
 to [set the associated effect of an
 animation](#animation-set-the-associated-effect-of-an-animation) (this procedure) on
 `previous animation`, passing null as
 `new effect`.

6. Let the [associated
 effect](#animation-associated-effect) of `animation` be
 `new effect`.

7. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

#### 4.5.4. Setting the current time of an animation

The [current
time](#animation-current-time) of an
[animation](#concept-animation) can be set to a new value to [seek] the animation. The procedure
for setting the current time is defined in two parts.

The procedure to [silently set the current
time] of an animation,
`animation`, to `seek time` is as follows:

1. If `seek time` is an
 [unresolved](#unresolved)
 time value, then perform the following steps.

 1. If the [current
 time](#animation-current-time) is
 [resolved](https://webidl.spec.whatwg.org/#resolve), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a [TypeError].

 2. Abort these steps.

2. Update either `animation`'s [hold
 time](#animation-hold-time) or [start
 time](#animation-start-time) as follows:

 If *any* of the following conditions are true:

 - `animation`'s [hold
 time](#animation-hold-time) is [resolved](#unresolved), or

 - `animation`'s [start
 time](#animation-start-time) is
 [unresolved](#unresolved),
 or

 - `animation` has no associated
 [timeline](#timeline) or the
 associated [timeline] is
 [inactive](#inactive-timeline), or

 - `animation`'s [playback
 rate](#playback-rate) is
 0,

 Set `animation`'s [hold
 time](#animation-hold-time) to `seek time`.

 Otherwise,

 Set `animation`'s [start
 time](#animation-start-time) to the result of evaluating
 `timeline time`` − (``seek time`` / `[`playback rate`](#playback-rate)`)` where `timeline time` is the current
 [time value](#time-value) of
 the [timeline](#timeline)
 associated with `animation`.

3. If `animation` has no associated
 [timeline](#timeline) or the
 associated [timeline] is
 [inactive](#inactive-timeline), make `animation`'s [start
 time](#animation-start-time) [unresolved](#unresolved).

 This preserves the invariant that when we don't
 have an active timeline it is only possible to set *either* the
 [start time](#animation-start-time) *or* the animation's [current
 time](#animation-current-time).

4. Make `animation`'s [previous current
 time](#previous-current-time) [unresolved](#unresolved).

The procedure to [set the current time] of an
animation, `animation`, to `seek time` is as
follows:

1. Run the steps to [silently set the current
 time](#animation-silently-set-the-current-time) of `animation` to
 `seek time`.

2. If `animation` has a [pending pause
 task](#pending-pause-task), synchronously complete the pause operation by
 performing the following steps:

 1. Set `animation`'s [hold
 time](#animation-hold-time) to `seek time`.

 2. [Apply any pending playback
 rate](#apply-any-pending-playback-rate) to `animation`.

 3. Make `animation`'s [start
 time](#animation-start-time) [unresolved](#unresolved).

 4. Cancel the [pending pause
 task](#pending-pause-task).

 5. [Resolve](https://webidl.spec.whatwg.org/#resolve) `animation`'s
 [current ready
 promise](#current-ready-promise) with `animation`.

3. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to true, and the
 `synchronously notify` flag set to false.

#### 4.5.5. Setting the start time of an animation

The procedure to [set the start time] of an
[animation](#concept-animation), `animation`, to `new start time`
is as follows:

1. Let `timeline time` be the current [time
 value](#time-value) of the
 [timeline](#timeline) that
 `animation` is associated with. If there is no
 [timeline] associated with
 `animation` or the associated timeline is
 [inactive](#inactive-timeline), let the `timeline time` be
 [unresolved](#unresolved).

2. If `timeline time` is
 [unresolved](#unresolved) and
 `new start time` is [resolved],
 make `animation`'s [hold
 time](#animation-hold-time) [unresolved].

 This preserves the invariant that when we don't
 have an active timeline it is only possible to set *either* the
 [start time](#animation-start-time) *or* the animation's [current
 time](#animation-current-time).

3. Let `previous current time` be `animation`'s
 [current
 time](#animation-current-time).

 This is the [current
 time](#animation-current-time) after applying the changes from the previous step,
 which can cause the current time to become
 [unresolved](#unresolved).

4. [Apply any pending playback
 rate](#apply-any-pending-playback-rate) on `animation`.

5. Set `animation`'s [start
 time](#animation-start-time) to `new start time`.

6. Update `animation`'s [hold
 time](#animation-hold-time) based on the first matching condition from the
 following:

 If `new start time` is [resolved](#unresolved),

 : If `animation`'s [playback
 rate](#playback-rate)
 is not zero, make `animation`'s [hold
 time](#animation-hold-time) [unresolved](#unresolved).

 Otherwise (`new start time` is [unresolved](#unresolved)),

 : Set `animation`'s [hold
 time](#animation-hold-time) to `previous current time` even if
 `previous current time` is
 [unresolved](#unresolved).

7. If `animation` has a [pending play
 task](#pending-play-task) or a [pending pause
 task](#pending-pause-task), cancel that task and
 [resolve](https://webidl.spec.whatwg.org/#resolve) `animation`'s
 [current ready
 promise](#current-ready-promise) with `animation`.

8. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to true, and the
 `synchronously notify` flag set to false.

#### 4.5.6. Waiting for the associated effect

::: informative-bg
*This section is non-normative*

Some operations performed by an
[animation](#concept-animation) might not occur instantaneously. For example, some user
agents might delegate the playback of an animation to a separate process
or to specialized graphics hardware, each of which could incur some
setup overhead.

If such an animation is timed from the moment when the animation was
triggered there can be a significant jump between the first and second
frames of the animation corresponding to the setup time involved.

To avoid this problem, Web Animations typically begins timing animations
from the moment when the first frame of the animation is complete. This
is represented by an [unresolved](#unresolved) [start
time](#animation-start-time) on the
[animation](#concept-animation) which becomes resolved when the animation is
[ready](#ready). Content can opt out of
this behavior by setting the [start
time] to a
[resolved] [time
value](#time-value).

An animation is [ready] at the first moment where *both* of the following
conditions are true:

- the user agent has completed any setup required to begin the playback
 of the animation's [associated
 effect](#animation-associated-effect), including rendering the first frame of any [keyframe
 effect](#keyframe-effect).

- the animation is associated with a
 [timeline](#timeline) that is not
 [inactive](#inactive-timeline).

#### 4.5.7. The current ready promise

Each [animation](#concept-animation) has a [current ready promise]. The [current ready
promise](#current-ready-promise) is initially a resolved
[Promise](http://www.ecma-international.org/ecma-262/6.0/#sec-promise-objects) created using the procedure to [create a new resolved
Promise](https://webidl.spec.whatwg.org/#a-promise-resolved-with) with the animation itself as its value and created in
the [relevant
Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm) of the animation.

The object is replaced with a new [Promise
object](http://www.ecma-international.org/ecma-262/6.0/#sec-promise-objects) every time the animation queues
a [pending play task](#pending-play-task) or a [pending pause
task](#pending-pause-task)
when it previously did not have a pending task, or when the animation is
canceled (see [§ 4.5.14 Canceling an
animation](#canceling-an-animation-section)).

Note that since the same object is used for both pending play and
pending pause requests, authors are advised to check the state of the
animation when the [Promise
object](http://www.ecma-international.org/ecma-262/6.0/#sec-promise-objects) is resolved.

For example, in the following code fragment, the state of the animation
will be [running](#play-state-running) when the [current ready
promise](#current-ready-promise) is resolved. This is because the `play` operation
occurs while a [pending play
task](#pending-play-task)
is still queued and hence the [current ready
promise] is re-used.

``` highlight
animation.pause();
animation.ready.then(function() {
 // Displays 'running'
 alert(animation.playState);
});
animation.play();
```

#### 4.5.8. Playing an animation

The procedure to [play an animation], `animation`, given
a flag `auto-rewind`, is as follows:

1. Let `aborted pause` be a boolean flag that is true if
 `animation` has a [pending pause
 task](#pending-pause-task), and false otherwise.

2. Let `has pending ready promise` be a boolean flag that is
 initially false.

3. Let `seek time` be a [time
 value](#time-value) that is
 initially [unresolved](#unresolved).

4. If the `auto-rewind` flag is true, perform the steps
 corresponding to the *first* matching condition from the following,
 if any:

 If `animation`'s [effective playback
 rate](#effective-playback-rate) ≥ 0, and `animation`'s [current
 time](#animation-current-time) is *either*:

 - [unresolved](#unresolved),
 or

 - less than zero, or

 - greater than or equal to [associated effect
 end](#associated-effect-end),

 Set `seek time` to zero.

 If `animation`'s [effective playback
 rate](#effective-playback-rate) \< 0, and `animation`'s [current
 time](#animation-current-time) is *either*:

 - [unresolved](#unresolved),
 or

 - less than or equal to zero, or

 - greater than [associated effect
 end](#associated-effect-end),

 If [associated effect end](#associated-effect-end) is positive infinity,

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

 Otherwise,

 : Set `seek time` to `animation`'s
 [associated effect
 end](#associated-effect-end).

5. If the following three conditions are *all* satisfied:

 - `seek time` is
 [unresolved](#unresolved),
 and

 - `animation`'s [start
 time](#animation-start-time) is
 [unresolved](#unresolved),
 and

 - `animation`'s [current
 time](#animation-current-time) is
 [unresolved](#unresolved),

 set `seek time` to zero.

 The above step ensures that this procedure will
 play an idle animation regardless of the setting of the
 `auto-rewind` flag.

6. Let `has finite timeline` be true if
 `animation` has an associated
 [timeline](#timeline) that is
 not [monotonically
 increasing](#monotonically-increasing-timeline).

7. If `seek time` is
 [resolved](https://webidl.spec.whatwg.org/#resolve),

 ::: switch

 If `has finite timeline` is true,

 : 1. Set `animation`'s [start
 time](#animation-start-time) to `seek time`.

 2. Let `animation`'s [hold
 time](#animation-hold-time) be
 [unresolved](#unresolved).

 3. [Apply any pending playback
 rate](#apply-any-pending-playback-rate) on `animation`.

 Otherwise,

 : Set `animation`'s [hold
 time](#animation-hold-time) to `seek time`.
 :::

8. If `animation`'s [hold
 time](#animation-hold-time) is [resolved](#unresolved), let its [start
 time](#animation-start-time) be [unresolved].

9. If `animation` has a [pending play
 task](#pending-play-task) or a [pending pause
 task](#pending-pause-task),

 1. Cancel that task.

 2. Set `has pending ready promise` to true.

10. If the following four conditions are *all* satisfied:

 - `animation`'s [hold
 time](#animation-hold-time) is
 [unresolved](#unresolved),
 and

 - `seek time` is
 [unresolved](#unresolved),
 and

 - `aborted pause` is false, and

 - `animation` does *not* have a [pending playback
 rate](#pending-playback-rate),

 abort this procedure.

11. If `has pending ready promise` is false, let
 `animation`'s [current ready
 promise](#current-ready-promise) be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in the [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm) of `animation`.

12. Schedule a task to run as soon as `animation` is
 [ready](#ready). The task shall
 perform the following steps:

 1. Assert that at least one of `animation`'s [start
 time](#animation-start-time) or [hold
 time](#animation-hold-time) is
 [resolved](#unresolved).

 2. Let `ready time` be the [time
 value](#time-value) of
 the [timeline](#timeline)
 associated with `animation` at the moment when
 `animation` became [ready](#ready).

 3. Perform the steps corresponding to the first matching condition
 below, if any:

 If `animation`'s [hold time](#animation-hold-time) is [resolved](#unresolved),

 : 1. [Apply any pending playback
 rate](#apply-any-pending-playback-rate) on `animation`.

 2. Let `new start time` be the result of
 evaluating
 `ready time`` − `[`hold time`](#animation-hold-time)` / `[`playback rate`](#playback-rate) for `animation`. If the
 [playback rate](#playback-rate) is zero, let
 `new start time` be simply
 `ready time`.

 3. Set the [start
 time](#animation-start-time) of `animation` to
 `new start time`.

 4. If `animation`'s [playback
 rate](#playback-rate) is not 0, make `animation`'s
 [hold
 time](#animation-hold-time)
 [unresolved](#unresolved).

 If `animation`'s [start time](#animation-start-time) is resolved and `animation` has a [pending playback rate](#pending-playback-rate),

 : 1. Let `current time to match` be the result of
 evaluating
 `(``ready time`` − `[`start time`](#animation-start-time)`) × `[`playback rate`](#playback-rate) for `animation`.

 2. [Apply any pending playback
 rate](#apply-any-pending-playback-rate) on `animation`.

 3. If `animation`'s [playback
 rate](#playback-rate) is zero, let `animation`'s
 [hold
 time](#animation-hold-time) be `current time to match`.

 4. Let `new start time` be the result of
 evaluating
 `ready time`` − ``current time to match`` / `[`playback rate`](#playback-rate) for `animation`. If the
 [playback rate](#playback-rate) is zero, let
 `new start time` be simply
 `ready time`.

 5. Set the [start
 time](#animation-start-time) of `animation` to
 `new start time`.

 4. [Resolve](https://webidl.spec.whatwg.org/#resolve) `animation`'s
 [current ready
 promise](#current-ready-promise) with `animation`.

 5. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

 The order of the above two steps is important
 since it means that an animation with zero-length [associated
 effect](#animation-associated-effect) will resolve its [current ready
 promise](#current-ready-promise) before its [current finished
 promise](#current-finished-promise).

 So long as the above task is scheduled but has yet to run,
 `animation` is described as having a [pending play
 task]. While the task is running, however,
 `animation` does *not* have a [pending play
 task](#pending-play-task).

 If a user agent determines that `animation` is
 immediately [ready](#ready), it may
 schedule the above task as a microtask such that it runs at the next
 [microtask
 checkpoint](https://html.spec.whatwg.org/multipage/webappapis.html#perform-a-microtask-checkpoint), but it *must not* perform the task synchronously.

 ::::
 The above requirement to run the [pending play
 task](#pending-play-task) asynchronously ensures that code such as the
 following behaves consistently between implementations:

 :::
 (#example-b6f05729)
 ``` highlight
 animation.play();
 animation.ready.then(
 () => { console.log('Playback commenced'); },
 () => { console.log('Playback was canceled'); }
 );
 // Suppose some condition requires playback to be canceled...
 animation.cancel();
 // "Playback was canceled" will be printed to the console.
 ```
 :::

 In the above code, were the [pending play
 task](#pending-play-task) run synchronously, the [current ready
 promise](#current-ready-promise) would not be rejected.
 ::::

13. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

#### 4.5.9. Pausing an animation

Whenever an [animation](#concept-animation) has an [unresolved](#unresolved) [start
time](#animation-start-time), its [current
time](#animation-current-time) will be suspended.

As with [playing an
animation](#play-an-animation), pausing might not happen instantaneously (see [§ 4.5.6
Waiting for the associated effect](#waiting-for-the-associated-effect)).
For example, if animation is performed by a separate process, it might
be necessary to synchronize the [current
time](#animation-current-time) to ensure that it reflects the state drawn by the
animation process.

The procedure to [pause an animation], `animation`, is as
follows:

1. If `animation` has a [pending pause
 task](#pending-pause-task), abort these steps.

2. If the [play
 state](#animation-play-state) of `animation` is
 [paused](#play-state-paused), abort these steps.

3. Let `seek time` be a [time
 value](#time-value) that is
 initially [unresolved](#unresolved).

4. Let `has finite timeline` be true if
 `animation` has an associated
 [timeline](#timeline) that is
 not [monotonically
 increasing](#monotonically-increasing-timeline).

5. If the `animation`'s [current
 time](#animation-current-time) is [unresolved](#unresolved), perform the steps according to the first matching
 condition below:

 If `animation`'s [playback rate](#playback-rate) is ≥ 0,

 : Set `seek time` to zero.

 Otherwise,

 :

 If [associated effect end](#associated-effect-end) for `animation` is positive infinity,

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

 Otherwise,

 : Set `seek time` to `animation`'s
 [associated effect
 end](#associated-effect-end).

6. If `seek time` is
 [resolved](#unresolved),

 ::: switch

 If `has finite timeline` is true,

 : Set `animation`'s [start
 time](#animation-start-time) to `seek time`.

 Otherwise,

 : Set `animation`'s [hold
 time](#animation-hold-time) to `seek time`.
 :::

7. Let `has pending ready promise` be a boolean flag that is
 initially false.

8. If `animation` has a [pending play
 task](#pending-play-task), cancel that task and let
 `has pending ready promise` be true.

9. If `has pending ready promise` is false, set
 `animation`'s [current ready
 promise](#current-ready-promise) to [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in the [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm) of `animation`.

10. Schedule a task to be executed at the first possible moment where
 *both* of the following conditions are true:

 - the user agent has performed any processing necessary to suspend
 the playback of `animation`'s [associated
 effect](#animation-associated-effect), if any.

 - the animation is associated with a
 [timeline](#timeline) that is
 not [inactive](#inactive-timeline).

 The task shall perform the following steps:

 1. Let `ready time` be the time value of the timeline
 associated with `animation` at the moment when the
 user agent completed processing necessary to suspend playback of
 `animation`'s [associated
 effect](#animation-associated-effect).

 2. If `animation`'s [start
 time](#animation-start-time) is
 [resolved](#unresolved)
 and its [hold
 time](#animation-hold-time) is *not* resolved, let `animation`'s
 [hold time] be the result of
 evaluating
 `(``ready time`` − `[`start time`](#animation-start-time)`) × `[`playback rate`](#playback-rate).

 The [hold
 time](#animation-hold-time) might be already set if the animation is
 [finished](#play-state-finished), or if the animation has a [pending play
 task](#pending-play-task). In either case we want to preserve the [hold
 time] as we enter the
 [paused](#play-state-paused) state.

 3. [Apply any pending playback
 rate](#apply-any-pending-playback-rate) on `animation`.

 4. Make `animation`'s [start
 time](#animation-start-time) unresolved.

 5. [Resolve](https://webidl.spec.whatwg.org/#resolve) `animation`'s
 [current ready
 promise](#current-ready-promise) with `animation`.

 6. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

 So long as the above task is scheduled but has yet to run,
 `animation` is described as having a [pending pause
 task]. While the task is running, however,
 `animation` does *not* have a [pending pause
 task](#pending-pause-task).

 As with the [pending play
 task](#pending-play-task), the user agent must run the [pending pause
 task](#pending-pause-task) asynchronously, although that could be as soon as
 the next [microtask
 checkpoint](https://html.spec.whatwg.org/multipage/webappapis.html#perform-a-microtask-checkpoint).

11. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

#### 4.5.10. Reaching the end

::: informative-bg
*This section is non-normative*

DVD players or cassette players typically continue playing until they
reach the end of their media at which point they stop. If such players
are able to play in reverse, they typically stop playing when they reach
the beginning of their media. In order to emulate this behavior, and to
provide consistency with HTML's [media
elements](https://html.spec.whatwg.org/multipage/embedded-content.html#media-element)
[\[HTML\]](#biblio-html "HTML Standard"), the
[current
time](#animation-current-time) of Web Animations\' animations do not play forwards
beyond the [end
time](#animation-effect-end-time) of their [associated
effect](#animation-associated-effect) or play backwards past time zero.

An animation that has reached the natural boundary of its playback range
is said to have *finished*.

Graphically, the effect of limiting the current time is shown below.

![The effect of limiting the [current
time](#animation-current-time) of an
[animation](#concept-animation) with a start time of 1s, an [associated
effect](#animation-associated-effect) of length 3s, and a positive [playback
rate](#playback-rate). After
the current time of the animation reaches the end of the associated
effect, it is capped at
3s.](images/limiting.svg){a
width="500"}

It is possible, however, to [seek](#seek)
the [current
time](#animation-current-time) of an
[animation](#concept-animation) to a time past the end of the [associated
effect](#animation-associated-effect). When doing so, the current time will not progress but
the animation will act as if it had been paused at the seeked time.

This allows, for example, [seeking](#seek) the [current
time](#animation-current-time) of an animation with *no* [associated
effect](#animation-associated-effect) to 5s. If [associated
effect] with an [end
time](#animation-effect-end-time) later than 5s is later associated with the animation,
playback will begin from the 5s mark.

Similar behavior to the above scenario can arise when the length of an
animation's [associated
effect](#animation-associated-effect) changes.

Similarly, when the [playback
rate](#playback-rate) is
negative, the [current
time](#animation-current-time) does not progress past time zero.

#### 4.5.11. The current finished promise

Each animation has a [current finished
promise]. The [current finished
promise](#current-finished-promise) is initially a pending
[Promise](http://www.ecma-international.org/ecma-262/6.0/#sec-promise-objects) object.

The object is replaced with a new
[promise](http://www.ecma-international.org/ecma-262/6.0/#sec-promise-objects) every time the animation leaves the [finished play
state](#play-state-finished).

#### 4.5.12. Updating the finished state

For an animation with a positive [playback
rate](#playback-rate), the
[current
time](#animation-current-time) continues to increase until it reaches the [associated
effect end](#associated-effect-end).

The [associated effect end] of an animation is equal to the [end
time](#animation-effect-end-time) of the animation's [associated
effect](#animation-associated-effect). If the animation has no [associated
effect], the [associated effect
end](#associated-effect-end) is zero.

For an animation with a negative [playback
rate](#playback-rate), the
[current
time](#animation-current-time) continues to decrease until it reaches zero.

A running animation that has reached this boundary (or overshot it) and
has a [resolved](#unresolved)
[start time](#animation-start-time) is said to be
[finished](#play-state-finished).

The crossing of this boundary is checked on each modification to the
animation object or the timing properties of its [associated
effect](#animation-associated-effect) using the procedure to [update an animation's finished
state](#update-an-animations-finished-state) defined below. This procedure is also run as part of
the [update animations and send
events](#update-animations-and-send-events) procedure. Unless otherwise specified, the
`did seek` and `synchronously notify` flags,
defined below, are set to false.

For each animation, the user agent maintains a [previous current
time] [time value](#time-value) that is originally
[unresolved](#unresolved).

Whilst during normal playback the [current
time](#animation-current-time) of an
[animation](#concept-animation) is limited to the boundaries described above, it is
possible to [seek](#seek) the current
time of an animation to times outside those boundaries using the
procedure to [set the current
time](#animation-set-the-current-time) of an animation.

The procedure to [update an animation's finished
state] for `animation`, given a flag
`did seek` (to indicate if the update is being performed
after [setting the current
time](#animation-set-the-current-time)), and a flag `synchronously notify` (to
indicate the update was called in a context where we expect finished
event queueing and finished promise resolution to happen immediately, if
at all) is as follows:

1. Let the `unconstrained current time` be the result of
 calculating the [current
 time](#animation-current-time), substituting an
 [unresolved](#unresolved)
 time value for the [hold
 time](#animation-hold-time) if `did seek` is false. If
 `did seek` is true, the
 `unconstrained current time` is equal to the [current
 time].

 This is required to accommodate timelines that can
 change direction. Without this definition, a once-finished animation
 would remain finished even when its timeline progresses in the
 opposite direction.

2. If *all three* of the following conditions are true,

 - the `unconstrained current time` is
 [resolved](#unresolved),
 *and*

 - `animation`'s [start
 time](#animation-start-time) is [resolved](#unresolved), *and*

 - `animation` does *not* have a [pending play
 task](#pending-play-task) or a [pending pause
 task](#pending-pause-task),

 then update `animation`'s [hold
 time](#animation-hold-time) based on the first matching condition for
 `animation` from below, if any:

 If [playback rate](#playback-rate) \> 0 and `unconstrained current time` is greater than or equal to [associated effect end](#associated-effect-end),

 : If `did seek` is true, let the [hold
 time](#animation-hold-time) be the value of
 `unconstrained current time`.

 If `did seek` is false, let the [hold
 time](#animation-hold-time) be the maximum value of [previous current
 time](#previous-current-time) and [associated effect
 end](#associated-effect-end). If the [previous current
 time] is
 [unresolved](#unresolved), let the [hold
 time] be [associated effect
 end].

 If [playback rate](#playback-rate) \< 0 and `unconstrained current time` is less than or equal to 0,

 : If `did seek` is true, let the [hold
 time](#animation-hold-time) be the value of
 `unconstrained current time`.

 If `did seek` is false, let the [hold
 time](#animation-hold-time) be the minimum value of [previous current
 time](#previous-current-time) and zero. If the [previous current
 time] is
 [unresolved](#unresolved), let the [hold
 time] be zero.

 If [playback rate](#playback-rate) ≠ 0, and `animation` is associated with an [active timeline](#active-timeline),

 : Perform the following steps:

 1. If `did seek` is true and the [hold
 time](#animation-hold-time) is
 [resolved](#unresolved), let `animation`'s [start
 time](#animation-start-time) be equal to the result of evaluating
 `timeline time`` − (`[`hold time`](#animation-hold-time)` / `[`playback rate`](#playback-rate)`)` where `timeline time` is the
 current [time value](#time-value) of the
 [timeline](#timeline)
 associated with `animation`.

 2. Let the [hold
 time](#animation-hold-time) be
 [unresolved](#unresolved).

3. Set the [previous current
 time](#previous-current-time) of `animation` to be the result of
 calculating its [current
 time](#animation-current-time).

4. Let `current finished state` be true if the [play
 state](#animation-play-state) of `animation` is
 [finished](#play-state-finished). Otherwise, let it be false.

5. If `current finished state` is true and the [current
 finished
 promise](#current-finished-promise) is not yet resolved, perform the following steps:

 1. Let [finish notification steps] refer to the following
 procedure:

 1. If `animation`'s [play
 state](#animation-play-state) is not equal to
 [finished](#play-state-finished), abort these steps.

 2. [Resolve](https://webidl.spec.whatwg.org/#resolve)
 `animation`'s [current finished
 promise](#current-finished-promise) object with `animation`.

 3. [Create](https://dom.spec.whatwg.org/#concept-event-create) an
 [`AnimationPlaybackEvent`](#animationplaybackevent), `finishEvent`.

 4. Set `finishEvent`'s
 [`type`](https://dom.spec.whatwg.org/#dom-event-type) attribute to
 [finish](#finish-event).

 5. Set `finishEvent`'s
 [`currentTime`](#dom-animationplaybackevent-currenttime) attribute to the [current
 time](#animation-current-time) of `animation`.

 6. Set `finishEvent`'s
 [`timelineTime`](#dom-animationplaybackevent-timelinetime) attribute to the [current
 time](#timeline-current-time) of the
 [timeline](#timeline)
 with which `animation` is associated. If
 `animation` is not associated with a timeline, or
 the timeline is
 [inactive](#inactive-timeline), let
 [`timelineTime`](#dom-animationplaybackevent-timelinetime) be `null`.

 7. If `animation` has a [document for
 timing](#animation-document-for-timing), then append `finishEvent` to
 its [document for
 timing]'s [pending
 animation event
 queue](#pending-animation-event-queue) along with its target,
 `animation`. For the [scheduled event
 time](#scheduled-event-time), use the result of
 [converting](#animation-time-to-origin-relative-time) `animation`'s [associated effect
 end](#associated-effect-end) to an origin-relative time.

 Otherwise, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to
 [dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch) `finishEvent` at
 `animation`. The task source for this task is the
 [DOM manipulation task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#dom-manipulation-task-source).

 2. If `synchronously notify` is true, cancel any queued
 microtask to run the [finish notification
 steps](#finish-notification-steps) for this `animation`, and run the
 [finish notification steps]
 immediately.

 Otherwise, if `synchronously notify` is false, [queue
 a
 microtask](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-microtask) to run [finish notification
 steps](#finish-notification-steps) for `animation` unless there is
 already a microtask queued to run those steps for
 `animation`.

6. If `current finished state` is false and
 `animation`'s [current finished
 promise](#current-finished-promise) is already resolved, set `animation`'s
 [current finished promise] to [a
 new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in the [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm) of `animation`.

Typically, notification about the finished state of an animation is
performed asynchronously. This allows for the animation to temporarily
enter the [finished play
state](#play-state-finished) without triggering events to be fired or promises to be
resolved.

For example, in the following code fragment, `animation` temporarily
enters the finished state. If notification of the finished state
occurred synchronously, this code would cause the [finish
event](#finish-event) to be
queued and the [current finished
promise](#current-finished-promise) to be resolved. However, if we reverse the order of the
two statements such that the `iterations` is updated first, this would
not happen. To avoid this surprising behavior, notification about the
finished state of an animation is typically performed asynchronously.

``` highlight
var animation = elem.animate({ left: '100px' }, 2000);
animation.playbackRate = 2;
animation.currentTime = 1000; // animation is now finished
animation.effect.updateTiming({ iterations: 2 }); // animation is no longer finished
```

The one exception to this asynchronous behavior is when the [finish an
animation](#finish-an-animation) procedure is performed (typically by calling the
[`finish()`](#dom-animation-finish) method). In this case the author's intention to finish
the animation is clear so the notification about the finished state of
the animation occurs synchronously as demonstrated below.

``` highlight
var animation = elem.animate({ left: '100px' }, 1000);
animation.finish(); // finish event is queued immediately and finished promise
 // is resolved despite the fact that the following statement
 // causes the animation to leave the finished state
animation.currentTime = 0;
```

Note that, like the procedure to [finish an
animation](#finish-an-animation), the procedure to [cancel an
animation](#cancel-an-animation) similarly queues the [cancel
event](#cancel-event) and rejects
the [current finished
promise](#current-finished-promise) and [current ready
promise](#current-ready-promise) in a *synchronous* manner.

#### 4.5.13. Finishing an animation

An animation can be advanced to the natural end of its current playback
direction by using the procedure to [finish an
animation] for `animation` defined below:

1. If `animation`'s [effective playback
 rate](#effective-playback-rate) is zero, or if `animation`'s [effective
 playback rate] \> 0 and
 [associated effect
 end](#associated-effect-end) is infinity,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

2. [Apply any pending playback
 rate](#apply-any-pending-playback-rate) to `animation`.

3. Set `limit` as follows:

 ::: switch

 If [playback rate](#playback-rate) \> 0,

 : Let `limit` be [associated effect
 end](#associated-effect-end).

 Otherwise,

 : Let `limit` be zero.
 :::

4. [Silently set the current
 time](#animation-silently-set-the-current-time) to `limit`.

5. If `animation`'s [start
 time](#animation-start-time) is [unresolved](#unresolved) and `animation` has an associated
 [active timeline](#active-timeline), let the [start
 time] be the result of evaluating
 `timeline time`` − (``limit`` / `[`playback rate`](#playback-rate)`)` where `timeline time` is the current
 [time value](#time-value) of
 the associated [timeline](#timeline).

6. If there is a [pending pause
 task](#pending-pause-task) and [start
 time](#animation-start-time) is [resolved](#unresolved),

 1. Let the [hold
 time](#animation-hold-time) be
 [unresolved](#unresolved).

 Typically the [hold
 time](#animation-hold-time) will already be unresolved except in the case
 when the animation was previously
 [idle](#play-state-idle).

 2. Cancel the [pending pause
 task](#pending-pause-task).

 3. [Resolve](https://webidl.spec.whatwg.org/#resolve) the [current ready
 promise](#current-ready-promise) of `animation` with
 `animation`.

7. If there is a [pending play
 task](#pending-play-task) and [start
 time](#animation-start-time) is [resolved](#unresolved), cancel that task and
 [resolve](https://webidl.spec.whatwg.org/#resolve) the [current ready
 promise](#current-ready-promise) of `animation` with
 `animation`.

8. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to true, and the
 `synchronously notify` flag set to true.

#### 4.5.14. Canceling an animation

An animation can be canceled which causes the [current
time](#animation-current-time) to become
[unresolved](#unresolved), hence
removing any effects caused by the [associated
effect](#animation-associated-effect).

The procedure to [cancel an animation] for `animation` is
as follows:

1. If `animation`'s [play
 state](#animation-play-state) is *not*
 [idle](#play-state-idle),
 perform the following steps:

 1. Run the procedure to [reset an animation's pending
 tasks](#animation-reset-an-animations-pending-tasks) on `animation`.

 2. [Reject](https://webidl.spec.whatwg.org/#reject) the [current finished
 promise](#current-finished-promise) with a
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) named
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\".

 3. Set the \[\[PromiseIsHandled\]\] internal slot of the [current
 finished
 promise](#current-finished-promise) to true.

 4. Let [current finished
 promise](#current-finished-promise) be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in the [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm) of `animation`.

 5. [Create](https://dom.spec.whatwg.org/#concept-event-create) an
 [`AnimationPlaybackEvent`](#animationplaybackevent), `cancelEvent`.

 6. Set `cancelEvent`'s
 [`type`](https://dom.spec.whatwg.org/#dom-event-type) attribute to
 [cancel](#cancel-event).

 7. Set `cancelEvent`'s
 [`currentTime`](#dom-animationplaybackevent-currenttime) to `null`.

 8. Let `timeline time` be the [current
 time](#timeline-current-time) of the
 [timeline](#timeline) with
 which `animation` is associated. If
 `animation` is not associated with an [active
 timeline](#active-timeline), let `timeline time` be an
 [unresolved](#unresolved)
 [time value](#time-value).

 9. Set `cancelEvent`'s
 [`timelineTime`](#dom-animationplaybackevent-timelinetime) to `timeline time`. If
 `timeline time` is
 [unresolved](#unresolved), set it to `null`.

 10. If `animation` has a [document for
 timing](#animation-document-for-timing), then append `cancelEvent` to its
 [document for timing]'s
 [pending animation event
 queue](#pending-animation-event-queue) along with its target, `animation`.
 If `animation` is associated with an [active
 timeline](#active-timeline) that defines a procedure to [convert timeline
 times to origin-relative
 time](#timeline-time-to-origin-relative-time), let the [scheduled event
 time](#scheduled-event-time) be the result of applying that procedure to
 `timeline time`. Otherwise, the [scheduled event
 time] is an
 [unresolved](#unresolved)
 [time value](#time-value).

 Otherwise, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to
 [dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch) `cancelEvent` at
 `animation`. The task source for this task is the
 [DOM manipulation task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#dom-manipulation-task-source).

2. Make `animation`'s [hold
 time](#animation-hold-time) [unresolved](#unresolved).

3. Make `animation`'s [start
 time](#animation-start-time) [unresolved](#unresolved).

The procedure to [reset an animation's pending
tasks] for `animation`
is as follows:

1. If `animation` does not have a [pending play
 task](#pending-play-task) or a [pending pause
 task](#pending-pause-task), abort this procedure.

2. If `animation` has a [pending play
 task](#pending-play-task), cancel that task.

3. If `animation` has a [pending pause
 task](#pending-pause-task), cancel that task.

4. [Apply any pending playback
 rate](#apply-any-pending-playback-rate) on `animation`.

5. [Reject](https://webidl.spec.whatwg.org/#reject) `animation`'s [current ready
 promise](#current-ready-promise) with a
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) named
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\".

6. Set the \[\[PromiseIsHandled\]\] internal slot of
 `animation`'s [current ready
 promise](#current-ready-promise) to true.

7. Let `animation`'s [current ready
 promise](#current-ready-promise) be the result of [creating a new resolved Promise
 object](https://webidl.spec.whatwg.org/#a-promise-resolved-with) with value `animation` in the [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm) of `animation`.

#### 4.5.15. Speed control

::: informative-bg
The rate of play of an animation can be controlled by setting its
[playback rate](#playback-rate). For example, setting a playback rate of 2 will cause
the animation's [current
time](#animation-current-time) to increase at twice the rate of its
[timeline](#timeline). Similarly, a
playback rate of -1 will cause the animation's [current
time] to decrease at the same rate as
the [time values](#time-value)
from its [timeline] increase.

[Animations](#concept-animation) have a [playback rate] that provides a scaling factor from the rate
of change of the associated [timeline](#timeline)'s [time values](#time-value) to the animation's [current
time](#animation-current-time). The [playback
rate](#playback-rate) is
initially 1.

Setting an animation's [playback
rate](#playback-rate) to zero
effectively pauses the animation (however, the [play
state](#animation-play-state) does not necessarily become
[paused](#play-state-paused)).

##### 4.5.15.1. Setting the playback rate of an animation

The procedure to [set the playback rate] of an
[animation](#concept-animation), `animation`, to
`new playback rate` is as follows:

1. Clear any [pending playback
 rate](#pending-playback-rate) on `animation`.

2. Let `previous time` be the value of the [current
 time](#animation-current-time) of `animation` before changing the
 [playback rate](#playback-rate).

3. Let `previous playback rate` be the current [effective
 playback
 rate](#effective-playback-rate) of `animation`.

4. Set the [playback rate](#playback-rate) to `new playback rate`.

5. Perform the steps corresponding to the *first* matching condition
 from the following, if any:

 If `animation` is associated with a [monotonically
 increasing](#monotonically-increasing-timeline) [timeline](#timeline) and the `previous time` is
 [resolved](#unresolved),

 [Set the current
 time](#animation-set-the-current-time) of `animation` to
 `previous time`.

 If `animation` is associated with a non-null
 [timeline](#timeline) that is
 not [monotonically
 increasing](#monotonically-increasing-timeline), the [start
 time](#animation-start-time) of `animation` is
 [resolved](https://webidl.spec.whatwg.org/#resolve), [associated effect
 end](#associated-effect-end) is not infinity, and *either*:

 - the `previous playback rate` \< 0 and the
 `new playback rate` ≥ 0, or

 - the `previous playback rate` ≥ 0 and the
 `new playback rate` \< 0,

 Set `animation`'s [start
 time](#animation-start-time) to the result of evaluating
 [`associated effect end`](#associated-effect-end)` − `[`start time`](#animation-start-time) for `animation`.

 This effectively flips the animation start/end
 times on non-monotonic timelines, preserving the relative offset of
 the start time from the other direction.

6. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to true, and the
 `synchronously notify` flag set to false.

##### 4.5.15.2. Seamlessly updating the playback rate of an animation

For an in-flight animation that is running on another process or thread,
the procedure to [set the playback
rate](#set-the-playback-rate) can cause the animation to jump if the process or
thread running the animation is not currently synchronized with the
process or thread performing the update.

In order to produce seamless changes to the [playback
rate](#playback-rate) of an
[animation](#concept-animation), animations may have a [pending playback
rate] that defines a playback rate to be applied after any
necessary synchronization has taken place (for the case of animations
running in a different thread or process).

Initially the [pending playback
rate](#pending-playback-rate) of an
[animation](#concept-animation) is unset.

The [effective playback rate] of an
[animation](#concept-animation) is its [pending playback
rate](#pending-playback-rate), if set, otherwise it is the animation's [playback
rate](#playback-rate).

When an [animation](#concept-animation), `animation`, is to [apply any pending
playback rate] the following steps are performed:

1. If `animation` does not have a [pending playback
 rate](#pending-playback-rate), abort these steps.

2. Set `animation`'s [playback
 rate](#playback-rate) to
 its [pending playback
 rate](#pending-playback-rate).

3. Clear `animation`'s [pending playback
 rate](#pending-playback-rate).

The procedure to [seamlessly update the playback
rate] of an
[animation](#concept-animation), `animation`, to
`new playback rate` preserving its [current
time](#animation-current-time) is as follows:

1. Let `previous play state` be `animation`'s
 [play state](#animation-play-state).

 It is necessary to record the play state before
 updating `animation`'s [effective playback
 rate](#effective-playback-rate) since, in the following logic, we want to
 immediately apply the [pending playback
 rate](#pending-playback-rate) of `animation` if it is *currently*
 [finished](#play-state-finished) regardless of whether or not it will still be
 finished after we apply the [pending playback
 rate].

2. Let `animation`'s [pending playback
 rate](#pending-playback-rate) be `new playback rate`.

3. Perform the steps corresponding to the first matching condition
 below:

 If `animation` has a [pending play task](#pending-play-task) or a [pending pause task](#pending-pause-task),

 : Abort these steps.

 The different types of pending tasks will apply
 the [pending playback
 rate](#pending-playback-rate) when they run so there is no further action
 required in this case.

 If `previous play state` is [idle](#play-state-idle) or [paused](#play-state-paused), or `animation`'s [current time](#animation-current-time) is [unresolved](#unresolved),

 : [Apply any pending playback
 rate](#apply-any-pending-playback-rate) on `animation`.

 The second condition above is required so that
 if we have a
 [running](#play-state-running) animation with an unresolved current time and
 no pending play task, we do not attempt to play it below.

 If `previous play state` is [finished](#play-state-finished),

 : 1. Let the `unconstrained current time` be the
 result of calculating the [current
 time](#animation-current-time) of `animation` substituting an
 [unresolved](#unresolved) time value for the [hold
 time](#animation-hold-time).

 2. Let `animation`'s [start
 time](#animation-start-time) be the result of evaluating the following
 expression:

 > `timeline time`` − (``unconstrained current time`` / `[`pending playback rate`](#pending-playback-rate)`)`

 Where `timeline time` is the current [time
 value](#time-value)
 of the [timeline](#timeline) associated with `animation`.

 If [pending playback
 rate](#pending-playback-rate) is zero, let `animation`'s
 [start
 time](#animation-start-time) be `timeline time`.

 3. [Apply any pending playback
 rate](#apply-any-pending-playback-rate) on `animation`.

 4. Run the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

 Otherwise,

 : Run the procedure to [play an
 animation](#play-an-animation) for `animation` with the
 `auto-rewind` flag set to false.

#### 4.5.16. Reversing an animation

The procedure to [reverse an animation] of
[animation](#concept-animation) `animation` is as follows:

1. If there is no [timeline](#timeline) associated with `animation`, or the
 associated [timeline] is
 [inactive](#inactive-timeline)
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

2. Let `original pending playback rate` be
 `animation`'s [pending playback
 rate](#pending-playback-rate).

3. Let `animation`'s [pending playback
 rate](#pending-playback-rate) be the additive inverse of its [effective playback
 rate](#effective-playback-rate) (i.e.
 `-`[`effective playback rate`](#effective-playback-rate)).

4. Run the steps to [play an
 animation](#play-an-animation) for `animation` with the
 `auto-rewind` flag set to true.

 If the steps to [play an
 animation](#play-an-animation) throw an exception, set `animation`'s
 [pending playback
 rate](#pending-playback-rate) to `original pending playback rate` and
 propagate the exception.

#### 4.5.17. Play states

An [animation](#concept-animation) can be described as being in one of the following [play
states], for each of which a
non-normative description is also provided:

::: informative-bg

[idle](#play-state-idle)

: The [current
 time](#animation-current-time) of the animation is
 [unresolved](#unresolved) and
 the [start
 time](#animation-start-time) of the animation is
 [unresolved] and there are no pending tasks.
 In this state the animation has no effect.

[running](#play-state-running)

: The animation has a resolved [current
 time](#animation-current-time) that changes on each [animation
 frame](#animation-frame)
 (provided the [playback
 rate](#playback-rate) is
 not zero and the [timeline](#timeline) is
 [active](#active-timeline) and [monotonically
 increasing](#monotonically-increasing-timeline)).

[paused](#play-state-paused)

: The animation has been suspended and the [current
 time](#animation-current-time) is no longer changing.

[finished](#play-state-finished)

: The animation has reached the natural boundary of its playback range
 and the [current
 time](#animation-current-time) is no longer updating.

Since the [current
time](#animation-current-time) of an animation is determined by its [start
time](#animation-start-time) and [hold
time](#animation-hold-time) (see [§ 4.5.1 Calculating the current time of an
animation](#the-current-time-of-an-animation)), and since the [play
state](#animation-play-state) is in turn determined by the [current
time], the four play states
correspond to the four combinations of those two values:

[hold time](#animation-hold-time) is [unresolved](#unresolved)

[hold time](#animation-hold-time) is [resolved](#unresolved)

[start time](#animation-start-time) is [unresolved](#unresolved)

[idle](#play-state-idle)

[paused](#play-state-paused)

[start time](#animation-start-time) is [resolved](#unresolved)

[running](#play-state-running)

[finished](#play-state-finished)

The above table assumes the animation has no pending task. A [pending
pause task](#pending-pause-task) causes an animation to be
[paused](#play-state-paused) regardless of its [start
time](#animation-start-time) and [hold
time](#animation-hold-time), while a [pending play
task](#pending-play-task)
prevents both the [idle play
state](#play-state-idle) and
the [paused play state].

Similarly, an animation whose [playback
rate](#playback-rate) is zero
has a [resolved](#unresolved)
[hold time](#animation-hold-time) without having reached a boundary, and so is
[running](#play-state-running) with a [current
time](#animation-current-time) that never changes.

The [play state](#animation-play-state) of
[animation](#concept-animation), `animation`, at a given moment is the state
corresponding to the *first* matching condition from the following:

*All* of the following conditions are true:

- The [current
 time](#animation-current-time) of `animation` is
 [unresolved](#unresolved),
 *and*

- the [start
 time](#animation-start-time) of `animation` is
 [unresolved](#unresolved),
 *and*

- `animation` does *not* have *either* a [pending play
 task](#pending-play-task) *or* a [pending pause
 task](#pending-pause-task),

→ [idle]

*Either* of the following conditions are true:

- `animation` has a [pending pause
 task](#pending-pause-task), *or*

- *both* the [start
 time](#animation-start-time) of `animation` is
 [unresolved](#unresolved) *and*
 it does *not* have a [pending play
 task](#pending-play-task),

→ [paused]

For `animation`, [current
time](#animation-current-time) is
[resolved](https://webidl.spec.whatwg.org/#resolve) and *either* of the following conditions are true:

- `animation`'s [effective playback
 rate](#effective-playback-rate) \> 0 and [current
 time](#animation-current-time) ≥ [associated effect
 end](#associated-effect-end); *or*

- `animation`'s [effective playback
 rate](#effective-playback-rate) \< 0 and [current
 time](#animation-current-time) ≤ 0,

→ [finished]

Otherwise,

→ [running]

Note that the [paused play
state](#play-state-paused)
effectively "wins" over the [finished play
state](#play-state-finished).

However, an animation that is paused outside of its natural playback
range can be converted from a
[paused](#play-state-paused) animation into a
[finished](#play-state-finished) animation without restarting by setting the [start
time](#animation-start-time) such as below:

``` highlight
animation.effect.updateTiming({ duration: 5000 });
animation.currentTime = 4000;
animation.pause();
animation.ready.then(function() {
 animation.effect.updateTiming({ duration: 3000 });
 alert(animation.playState); // Displays 'paused'
 animation.startTime =
 document.timeline.currentTime - animation.currentTime * animation.playbackRate;
 alert(animation.playState); // Displays 'finished'
});
```

#### 4.5.18. Animation events

[Animation events] include the [animation playback
events](#animation-playback-events) defined in this specification as well as the [events
from CSS
transitions](https://drafts.csswg.org/css-transitions/#transition-events)
[\[CSS-TRANSITIONS-1\]](#biblio-css-transitions-1 "CSS Transitions Module Level 1")
and [events from CSS
animations](https://drafts.csswg.org/css-animations/#events)
[\[CSS-ANIMATIONS-1\]](#biblio-css-animations-1 "CSS Animations Level 1").
Future specifications may extend this set with further types of
[animation events](#animation-events).

Each
[`Document`](https://html.spec.whatwg.org/#document) maintains a [pending animation event
queue] that stores [animation
events](#animation-events)
along with their corresponding event targets and [scheduled event
time]. The [scheduled event
time](#scheduled-event-time) is a [time value](#time-value) relative to the [time
origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-time-origin) representing when the event would ideally have been
dispatched were animations updated at an infinitely high frequency. It
is used by the procedure to [update animations and send
events](#update-animations-and-send-events) to sort queued [animation
events] chronologically. Note that this
value can be [unresolved](#unresolved) if, for example, the
[animation](#concept-animation)'s [timeline](#timeline) produces values that are unrelated to the [time
origin] (e.g. a timeline
that tracks scroll-position) or if the [timeline]
is [inactive](#inactive-timeline).

##### 4.5.18.1. Sorting animation events

The following definitions are provided to assist with sorting queued
events.

To [convert an animation time to timeline
time] a [time
value](#time-value),
`time`, that is relative to the [start
time](#animation-start-time) of an animation, `animation`, perform the
following steps:

1. If `time` is
 [unresolved](#unresolved),
 return `time`.

2. If `time` is infinity, return an
 [unresolved](#unresolved)
 [time value](#time-value).

3. If `animation`'s [playback
 rate](#playback-rate) is
 zero, return an [unresolved](#unresolved) [time value](#time-value).

4. If `animation`'s [start
 time](#animation-start-time) is [unresolved](#unresolved), return an [unresolved]
 [time value](#time-value).

5. Return the result of calculating
 `time`` × (1 / ``playback rate``) + ``start time`,
 where `playback rate` and `start time` are the
 [playback rate](#playback-rate) and [start
 time](#animation-start-time) of `animation`, respectively.

To [convert a timeline time to an origin-relative
time]
a [time value](#time-value),
`time`, that is expressed in the same scale as the [time
values] of a
[timeline](#timeline),
`timeline`, perform the following steps:

1. Let `timeline time` be the result of
 [converting](#animation-time-to-timeline-time) `time` from an animation time to a
 timeline time.

2. If `timeline time` is
 [unresolved](#unresolved),
 return `time`.

3. If `animation` is not associated with a
 [timeline](#timeline), return
 an [unresolved](#unresolved)
 time value.

4. If `animation` is associated with an [inactive
 timeline](#inactive-timeline), return an
 [unresolved](#unresolved)
 time value.

5. If there is no procedure to [convert a timeline time to an
 origin-relative
 time](#timeline-time-to-origin-relative-time) for the timeline associated with
 `animation`, return an
 [unresolved](#unresolved)
 [time value](#time-value).

6. Return the result of
 [converting](#timeline-time-to-origin-relative-time) `timeline time` to an origin-relative
 time using the procedure defined for the
 [timeline](#timeline)
 associated with `animation`.

##### 4.5.18.2. Animation playback events

As [animations](#concept-animation) play, they report changes to their status through
[animation playback events].

[Animation playback
events](#animation-playback-events) are a property of the timing model. As a result they
are dispatched even when the [associated
effect](#animation-associated-effect) of the
[animation](#concept-animation) is absent or has no observable result.

##### 4.5.18.3. Types of animation playback events

[finish]

: Queued whenever an animation enters the [finished play
 state](#play-state-finished).

[cancel]

: Queued whenever an animation enters the [idle play
 state](#play-state-idle)
 from another state. Creating a new
 [animation](#concept-animation) that is initially idle does *not* generate a new
 [cancel event](#cancel-event).

[remove]

: Queued whenever an animation is automatically removed. See [§ 5.5
 Replacing animations](#replacing-animations).

### 4.6. Animation effects

An [animation effect] is a [timing node](#timing-nodes) that provides a static description of some timed
behavior.

All [animation effects](#animation-effect) have the following properties:

- an [active interval](#active-interval), determined by its [start
 delay](#start-delay) and [active
 duration](#active-duration),
 defining the time interval during which its behavior takes effect

- an [iteration
 duration](#iteration-duration), [iteration
 count](#iteration-count),
 and [iteration start](#iteration-start) defining how its behavior repeats within that
 interval

- a [playback
 direction](#playback-direction) applying to each iteration, to allow reversing the
 timing of effects within an iteration

- a [fill mode](#fill-mode) defining
 the application of effects
 [before](#animation-effect-before-phase)/[after](#animation-effect-after-phase) its [active
 interval](#active-interval)

- optionally, an [associated
 animation](#animation-effect-associated-animation) and through it, optionally, an [associated
 timeline](#associated-with-a-timeline), which cause the [animation
 effect](#animation-effect)
 to apply its behavior by driving its [local time
 value](#local-time)

#### 4.6.1. Types of animation effects

This specification defines a single type of [animation
effect](#animation-effect):
[keyframe effects](#keyframe-effect). Subsequent levels of this specification will define
further types of [animation effects].

#### 4.6.2. Associated animation and timeline

An [animation effect](#animation-effect) is [associated with an
animation] when the effect is that animation's [associated
effect](#animation-associated-effect). At a given moment, an [animation
effect] can be
[associated](#animation-effect-associated-animation) with at most one
[animation](#concept-animation).

An [animation effect](#animation-effect), `effect`, is [associated with a
timeline], `timeline`, if `effect` is
[associated with an
animation](#animation-effect-associated-animation) which, in turn, is associated with
`timeline`.

#### 4.6.3. Local time

The [local time] of an [animation
effect](#animation-effect)
represents the [current
time](#animation-current-time) provided by its [associated
animation](#animation-effect-associated-animation), determining the progress of the [animation
effect]. At a given moment, it is based on
the first matching condition below:

If the [animation effect](#animation-effect) is [associated with an animation](#animation-effect-associated-animation),

: the [local time](#local-time)
 is the [current
 time](#animation-current-time) of the
 [animation](#concept-animation).

Otherwise,

: the [local time](#local-time)
 is [unresolved](#unresolved).

#### 4.6.4. Time spaces

::: informative-bg
*This section is non-normative*

In Web Animations all times are relative to some point of reference.
These different points of reference produce different [time
spaces].

This can be compared to coordinate spaces as used in computer graphics.
The zero time of a [time space](#time-spaces) is analogous to the origin of a coordinate space.

Within the [Web Animations
model](#web-animations-model) we define progress of an [animation
effect](#animation-effect)
on the basis of its [active time](#active-time), which is a time relative to the beginning of its
[active interval](#active-interval)---​thus a time in the [active time
space](#active-time-space).

 This time space is internal to the model and not
exposed in the programming interface or in markup.

We can further describe animations that repeat as establishing a new
[time space](#time-spaces) each
time the animation repeats: the [iteration time
space](#iteration-time-space).

The [animation effect](#animation-effect) thus translates the [current
time](#animation-current-time) provided by the [associated
animation](#animation-effect-associated-animation) through a series of [time
spaces](#time-spaces):

- the [local time space], relative to the [start
 time](#animation-start-time) of the [associated
 animation](#animation-effect-associated-animation), yielding the [local
 time](#local-time)

- the [active time space], relative to the start of the [active
 interval](#active-interval), yielding the [active
 time](#active-time)

- the [iteration time space], relative to the start of the [animation
 effect](#animation-effect)'s current iteration, yielding the [iteration
 time]

These time spaces are illustrated below.

![A comparison of [local time](#local-time), [active time](#active-time), and [iteration
time](#iteration-time) for an
animation with an [iteration
duration](#iteration-duration) of 1s and an [iteration
count](#iteration-count) of
2.5. The [start
time](#animation-start-time) defined by the
[animation](#concept-animation) and [end
time](#animation-effect-end-time) defined by the [animation
effect](#animation-effect)
are also
annotated.](images/time-spaces.svg){a
width="600"}

In addition to these time spaces we can also refer to the [document time
space], which is time space of the [time
values](#time-value) of the
[default document
timeline](#document-default-document-timeline) of the
[`Document`](https://html.spec.whatwg.org/#document) of the [current global
object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object).

 While the time spaces themselves are not bounded, Web
Animations defines [active time](#active-time) and the [iteration
progress](#iteration-progress) such that they are clamped to a set range as shown in
the diagram. For example, whilst a time of -1 second is a valid time in
*active time space*, the procedure for calculating the [active
time] defined in [§ 4.7.2 Calculating the active
time](#calculating-the-active-time) will never return a negative value.

#### 4.6.5. The active interval

[Animation effects](#animation-effect) define an [active interval], which is the period of time
during which the effect is scheduled to produce its effect (excepting
[fill modes](#fill-mode), which
apply outside the [active
interval](#active-interval)).
Each [animation effect] has only one such
interval, which is defined by its [start
delay](#start-delay) and [active
duration](#active-duration).

::: informative-bg
The relationship between the [start
time](#animation-start-time), [start delay](#start-delay), and [active
duration](#active-duration)
is illustrated below.

![Examples of the effect of the [start
delay](#start-delay) on the
endpoints of the [active
interval](#active-interval).\
(a) An animation effect with no delay; the [start
time](#animation-start-time) and beginning of the [active
interval] are coincident.\
(b) An animation effect with a positive delay; the beginning of the
[active interval] is deferred by the delay.\
(c) An animation effect with a negative delay; the beginning of the
[active interval] is brought forward by the
delay.](images/active-interval-examples.svg){a
width="600"}

##### 4.6.5.1. The start delay

The lower bound of the [active
interval](#active-interval)
by default corresponds to the [start
time](#animation-start-time) of the [associated
animation](#animation-effect-associated-animation), but can be shifted by the [start delay], which is a signed offset
from the [start time] of the
[animation](#concept-animation).

##### 4.6.5.2. The active duration

The length of the [active
interval](#active-interval)
is called the [active duration], and is determined by the [iteration
duration](#iteration-duration) and [iteration
count](#iteration-count) as
defined below. Its length determines the upper bound of the [active
interval].

> [active duration](#active-duration) =
> [`iteration duration`](#iteration-duration)` × `[`iteration count`](#iteration-count)

If either the [iteration
duration](#iteration-duration) or [iteration
count](#iteration-count) are
zero, the [active duration](#active-duration) is zero.

 This clarification is needed since the result of
infinity multiplied by zero is undefined according to IEEE 754-2008.

##### 4.6.5.3. The end delay and animation effect end time

Similar to the [start delay](#start-delay), an [animation
effect](#animation-effect)
also has an [end delay], which is primarily of use when sequencing one [animation
effect] based on the [end
time](#animation-effect-end-time) of another [animation
effect].

The [end time], of an [animation
effect](#animation-effect)
is the result of evaluating
`max(`[`start delay`](#start-delay)` + `[`active duration`](#active-duration)` + `[`end delay`](#end-delay)`, 0)`.

 Although the [end
delay](#end-delay) is typically
only useful in combination with sequence effects which are introduced in
a subsequent level of this specification, it is included here for the
purpose of representing the
[`min`](https://www.w3.org/TR/SVG/animate.html#MinAttribute) attribute
in SVG
([\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"),
Chapter 19).

#### 4.6.6. Animation effect phases and states

::: informative-bg
*This section is non-normative*

At a given moment, an [animation
effect](#animation-effect)
can be in one of three possible *phases*. If an [animation
effect] has an
[unresolved](#unresolved) [local
time](#local-time) it will not be
in any phase.

The different phases are illustrated below.

![An example of the different phases and states used to describe an
[animation effect](#animation-effect).](images/animation-effect-phases-and-states.svg){width="700"}

The phases are as follows:

[before phase](#animation-effect-before-phase)

: The [animation
 effect](#animation-effect)'s [local time](#local-time) falls before the effect's [active
 interval](#active-interval) and [end
 time](#animation-effect-end-time), *or* occurs during the range when a negative
 [start delay](#start-delay)
 is in effect.

[active phase](#animation-effect-active-phase)

: The [animation
 effect](#animation-effect)'s [local time](#local-time) falls inside the effect's [active
 interval](#active-interval) and outside the range of any negative [start
 delay](#start-delay) or
 negative [end delay](#end-delay).

[after phase](#animation-effect-after-phase)

: The [animation
 effect](#animation-effect)'s [local time](#local-time) falls after the effect's [active
 interval](#active-interval) or after the [end
 time](#animation-effect-end-time) if that comes first (due to a negative [end
 delay](#end-delay)), but *not*
 during the range when a negative [start
 delay](#start-delay) is in
 effect.

In addition to these phases, an [animation
effect](#animation-effect)
can also be described as being in one of several overlapping *states*.
These states are only established for the duration of a single
[animation frame](#animation-frame) and are primarily a convenience for describing stative
parts of the model.

These states and their usage within the model are summarized as follows:

[in play](#in-play)

: Corresponds to an [animation
 effect](#animation-effect) whose [active
 time](#active-time) is
 changing on each frame.

[current](#current)

: Corresponds to an [animation
 effect](#animation-effect) that is either [in
 play](#in-play) or could become
 [in play] in the future based on its
 [animation](#concept-animation)'s current [playback
 rate](#playback-rate).

[in effect](#in-effect)

: Corresponds to an [animation
 effect](#animation-effect) that has a resolved [active
 time](#active-time). This
 occurs when either the [animation
 effect] is in its [active
 phase](#animation-effect-active-phase) or outside the [active
 phase] but at a time where
 the effect's [fill mode](#fill-mode) (see [§ 4.6.8 Fill behavior and fill
 modes](#fill-behavior)) causes its [active
 time] to be resolved. Only [in
 effect](#in-effect) [animation
 effects] apply a result to their
 target.

The normative definition of each of these states follows.

The phase of an [animation
effect](#animation-effect)
depends on the following definitions:

[animation direction]

: "backwards" if the effect is [associated with an
 animation](#animation-effect-associated-animation) *and* the associated
 [animation](#concept-animation)'s [playback
 rate](#playback-rate) is
 less than zero; in all other cases, the [animation
 direction](#animation-direction) is "forward".

[before-active boundary time]

: `max(min(`[`start delay`](#start-delay)`, `[`end time`](#animation-effect-end-time)`), 0)`

[active-after boundary time]

: `max(min(`[`start delay`](#start-delay)` + `[`active duration`](#active-duration)`, `[`end time`](#animation-effect-end-time)`), 0)`

Furthermore, an [endpoint-inclusive active
interval] flag may be specified when determining the
phase. If not specified, it is assumed to be false.

An [animation effect](#animation-effect) is in the [before phase]
if the animation effect's [local time](#local-time) is not [unresolved](#unresolved) and *either* of the following conditions are met:

- the [local time](#local-time)
 is less than the [before-active boundary
 time](#before-active-boundary-time), *or*

- the [animation
 direction](#animation-direction) is "backwards", the [endpoint-inclusive active
 interval](#endpoint-inclusive-active-interval) flag is false, and the [local
 time](#local-time) is equal to
 the [before-active boundary
 time](#before-active-boundary-time).

An [animation effect](#animation-effect) is in the [after phase]
if the animation effect's [local
time](#local-time) is not
[unresolved](#unresolved) and
*either* of the following conditions are met:

- the [local time](#local-time)
 is greater than the [active-after boundary
 time](#active-after-boundary-time), *or*

- the [animation
 direction](#animation-direction) is "forwards", the [endpoint-inclusive active
 interval](#endpoint-inclusive-active-interval) flag is false, and the [local
 time](#local-time) is equal to
 the [active-after boundary
 time](#active-after-boundary-time).

An [animation effect](#animation-effect) is in the [active phase]
if the animation effect's [local
time](#local-time) is not
[unresolved](#unresolved) and it
is neither in the [before
phase](#animation-effect-before-phase) nor in the [after
phase](#animation-effect-after-phase).

Furthermore, it is often convenient to refer to the case when an
animation effect is in none of the above phases as being in the [idle
phase].

An [animation effect](#animation-effect) is [in play] if *all* of the following conditions are met:

- the [animation effect](#animation-effect) is in the [active
 phase](#animation-effect-active-phase), and

- the [animation effect](#animation-effect) is [associated with an
 animation](#animation-effect-associated-animation) that is not
 [finished](#play-state-finished).

An [animation effect](#animation-effect) is [current] if *any* of the following conditions are true:

- the [animation effect](#animation-effect) is [in play](#in-play), or

- the [animation effect](#animation-effect) is in the [before
 phase](#animation-effect-before-phase) and is [associated with an
 animation](#animation-effect-associated-animation) with a [playback
 rate](#playback-rate) \> 0,
 or

- the [animation effect](#animation-effect) is in the [after
 phase](#animation-effect-after-phase) and is [associated with an
 animation](#animation-effect-associated-animation) with a [playback
 rate](#playback-rate) \< 0,
 or

- the [animation effect](#animation-effect) is [associated with an
 animation](#animation-effect-associated-animation) not in the
 [idle](#play-state-idle)
 [play state](#animation-play-state) with a non-null associated
 [timeline](#timeline) that is not
 [monotonically
 increasing](#monotonically-increasing-timeline).

An animation effect is [in effect] if its [active
time](#active-time), as
calculated according to the procedure in [§ 4.7.2 Calculating the active
time](#calculating-the-active-time), is *not*
[unresolved](#unresolved).

#### 4.6.7. Relevant animations

We can define an
[animation](#concept-animation) as being
[relevant](#animation-relevant) based on the [animation
effect](#animation-effect)
[associated](#animation-associated-effect) with it.

An [animation](#concept-animation) is [relevant] if:

- Its [associated
 effect](#animation-associated-effect) is [current](#current) *or* [in effect](#in-effect), *and*

- Its [replace state](#replace-state) is *not*
 [removed](#removed-replace-state).

The [relevant animations] for an element or pseudo-element
`target` is the set of all
[animations](#concept-animation) that contain at least one [animation
effect](#animation-effect)
whose [effect
target](#keyframe-effect-effect-target) is `target`.

The [relevant animations for a
subtree] of an element, pseudo-element,
[document](https://dom.spec.whatwg.org/#concept-document), or [shadow
root](https://dom.spec.whatwg.org/#concept-shadow-root) `target` is the set of all
[animations](#concept-animation) that contain at least one [animation
effect](#animation-effect)
whose [effect
target](#keyframe-effect-effect-target) is an [inclusive
descendant](https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant) (or
[descendant](https://dom.spec.whatwg.org/#concept-tree-descendant), if `target` is a
[document] or [shadow
root]) of `target` or is a
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) of such a descendant.

#### 4.6.8. Fill behavior and fill modes

The effect of an [animation
effect](#animation-effect)
when it is not [in play](#in-play) is
determined by its [fill mode]. The effect of each [fill
mode](#fill-mode) is described
below:

[none]

: The animation effect has no effect when it is not [in
 play](#in-play).

[forwards]

: When the animation effect is in the [after
 phase](#animation-effect-after-phase), the animation effect will produce the same
 [iteration
 progress](#iteration-progress) value as the last moment it is scheduled to be [in
 play](#in-play).

 For all other times that the animation effect is not [in
 play](#in-play), it will have no
 effect.

[backwards]

: When the animation effect is in the [before
 phase](#animation-effect-before-phase), the animation effect will produce the same
 [iteration
 progress](#iteration-progress) value as the earliest moment that it is scheduled
 to be [in play](#in-play).

 For all other times that the animation effect is not [in
 play](#in-play), it will have no
 effect.

[both]

: When the animation effect is in its [before
 phase](#animation-effect-before-phase),
 [backwards](#fill-mode-backwards) fill behavior is used.

 When the animation effect is in its [after
 phase](#animation-effect-after-phase),
 [forwards](#fill-mode-forwards) fill behavior is used.

The normative effect of these modes is incorporated in the calculation
of the [active time](#active-time) in [§ 4.7.2 Calculating the active
time](#calculating-the-active-time).

Some examples of these [fill modes](#fill-mode) are illustrated below.

![Examples of various fill modes and the states produced.\
(a) fill mode [none](#fill-mode-none). The animation effect has no effect outside its active
phase.\
(b) fill mode
[forwards](#fill-mode-forwards). After the active phase has finished, the [iteration
progress](#iteration-progress) value continues to maintain a fill value.\
(c) fill mode
[backwards](#fill-mode-backwards). The animation effect produces a fill value until the
start of the active phase.\
(d) fill mode [both](#fill-mode-both). Both before and after the active phase the animation
effect produces a fill
value.](images/animation-state-and-fill-behavior.svg){a
width="600"}

 Authors are discouraged from using [fill
modes](#fill-mode) to produce
animations whose effect is applied indefinitely. [Fill
modes] were introduced in order to represent the
[animation-fill-mode](https://drafts.csswg.org/css-animations-1/#propdef-animation-fill-mode) property defined by CSS animations
[\[CSS-ANIMATIONS-1\]](#biblio-css-animations-1 "CSS Animations Level 1").
However, they produce situations where animation state would be
accumulated indefinitely, necessitating the automatic removal of
animations (as defined in [§ 5.5 Replacing
animations](#replacing-animations)). Furthermore, indefinitely filling
animations can cause changes to specified styles to be ineffective long
after all animations have completed since the animation style takes
precedence in the CSS cascade.
[\[CSS-CASCADE-3\]](#biblio-css-cascade-3 "CSS Cascading and Inheritance Level 3")

**Where possible, authors should set the final state of the animation
directly in specified styles.**

This can be achieved by waiting for
the animation to finish and then updating the style as illustrated
below:

``` highlight
// In the first frame after the following animation finishes,
// the callback for the `finished` promise will run
// BEFORE style is updated, and hence will NOT flicker.
elem.animate({ transform: 'translateY(100px)' }, 200).finished.then(() => {
 elem.style.transform = 'translateY(100px)';
});
```

More conveniently, an
[`Animation`](#animation)'s
[`commitStyles`](#dom-animation-commitstyles) method can be used to produce the same effect.

``` highlight
elem.animate({ transform: 'translateY(100px)' }, 200).finished.then(() => {
 elem.commitStyles();
});
```

Alternatively, the author can set the
specified style at the start of the animation and then animate *from*
the original value as illustrated below:

``` highlight
elem.style.transform = 'translateY(100px)';
elem.animate({ transform: 'none', offset: 0 }, 200);
```

 Setting a [fill mode](#fill-mode) has no bearing on the endpoints of the [active
interval](#active-interval)
or the boundaries between [phases](#animation-effect-phases-and-states)
However, the fill mode *does* have an effect on various other properties
of the timing model since the [active
time](#active-time) of an
animation effect is only defined (that is, not
[unresolved](#unresolved)) inside
the [active
phase](#animation-effect-active-phase) *or* when a fill is applied.

#### 4.6.9. Repeating

##### 4.6.9.1. Iteration intervals

It is possible to specify that an animation effect should repeat a fixed
number of times or indefinitely. This repetition occurs *within* the
[active interval](#active-interval). The span of time during which a single repetition
takes place is called an [iteration interval].

Unlike the [active
interval](#active-interval),
an animation effect can have multiple [iteration
intervals](#iteration-interval), although typically only the interval corresponding to
the current iteration is of interest.

The length of a single iteration is called the [iteration
duration]. The initial [iteration
duration](#iteration-duration) of an animation effect is zero.

::: informative-bg
*This section is non-normative*

Comparing the [iteration
duration](#iteration-duration) and the [active
duration](#active-duration)
we have:

iteration duration

: The time taken for a single iteration of the animation effect to
 complete.

active duration

: The time taken for the entire animation effect to complete,
 including repetitions. This can be longer or shorter than the
 [iteration
 duration](#iteration-duration).

The relationship between the [iteration
duration](#iteration-duration) and [active
duration](#active-duration)
is illustrated below.

![A comparison of the [iteration
duration](#iteration-duration) and [active
duration](#active-duration)
of an animation effect with an [iteration
count](#iteration-count) of
2.5. Note that the [iteration duration]
for the final iteration does not change; it is simply cut-off by the
[active
duration].](images/iteration-intervals.svg){a
width="600"}

##### 4.6.9.2. Controlling iteration

The number of times an [animation
effect](#animation-effect)
repeats is called its [iteration count]. The [iteration
count](#iteration-count) is a
real number greater than or equal to zero. The [iteration
count] can also be positive infinity to
represent that the [animation effect]
repeats indefinitely.

In addition to the [iteration
count](#iteration-count),
[animation effects](#animation-effect) also have an [iteration start] property which specifies an
offset into the series of iterations at which the [animation
effect] should begin. The [iteration
start](#iteration-start) is a
finite real number greater than or equal to zero.

The behavior of these parameters is defined in the calculations in
[§ 4.7 Calculating progress](#core-animation-effect-calculations).

::: informative-bg
*This section is non-normative*

The effect of the [iteration
count](#iteration-count) and
[iteration start](#iteration-start) parameters is illustrated below.

![The effect of the [iteration
count](#iteration-count) and
[iteration start](#iteration-start) parameters.\
In the first case the [iteration count] is
2.5 resulting in the third iteration being cut off halfway through its
[iteration interval](#iteration-interval).\
The second case is the same but with an [iteration
start] of 0.5. This causes the [animation
effect](#animation-effect)
to begin halfway through the first
iteration.](images/iteration-count-and-start.svg){a
width="600"}

Unlike the [iteration
count](#iteration-count)
parameter, the [iteration
start](#iteration-start)
parameter does not affect the length of the [active
duration](#active-duration).

Note that values of [iteration
start](#iteration-start)
greater than or equal to one are generally not useful unless used in
combination with an [animation
effect](#animation-effect)
that has an [iteration composite
operation](https://drafts.csswg.org/web-animations-2/#iteration-composite-operation) of
[accumulate](https://drafts.csswg.org/web-animations-2/#iteration-composite-operation-accumulate).

##### 4.6.9.3. Interval timing

::: informative-bg
*This section is non-normative*

When an animation effect repeats, the behavior at the iteration
boundaries needs to be defined. For this, and indeed for all interval
timing, Web Animations uses an endpoint-exclusive timing model. This
means that whilst the begin time of an interval is included in the
interval, the end time is not. In interval notation this can written
`[begin, end)`. This model provides sensible behavior when intervals are
repeated and sequenced since there is no overlap between the intervals.

In the examples below, for the repeated effect, at local time 1s, the
iteration time is 0. For the sequenced animations, at timeline time 1s,
only animation B's [associated
effect](#animation-associated-effect) will be [in play](#in-play); there is no overlap.

![Illustration of end-point exclusive timing. For both repeated and
sequenced animation effects there is no overlap at the boundaries
between
intervals.](images/endpoint-exclusive-timing.svg){a
width="600"}

An exception to this behavior is that when performing a
[fill](#fill-behavior), if the fill begins at an interval endpoint, the
endpoint is used. This behavior falls out of the algorithm given in
[§ 4.7.4 Calculating the simple iteration
progress](#calculating-the-simple-iteration-progress) and is illustrated
below.

![After one iteration, the [iteration
progress](#iteration-progress) is 0, but after two iterations (and there onwards), the
[iteration progress] is 1 due to the
special behavior defined when an animation effect
fills.](images/endpoint-exclusive-timing-and-fill.svg){a
width="600"}

#### 4.6.10. Direction control

[Animation effects](#animation-effect) can also be configured to run iterations in alternative
directions using direction control. For this purpose, [animation
effects] have a [playback
direction] parameter which takes one of the following values:

[normal]

: All iterations are played as specified.

[reverse]

: All iterations are played in the reverse direction from the way they
 are specified.

[alternate]

: Even iterations are played as specified; odd iterations are played
 in the reverse direction from the way they are specified.

[alternate-reverse]

: Even iterations are played in the reverse direction from the way
 they are specified; odd iterations are played as specified.

The semantics of these values are incorporated into the calculation of
the [directed progress](#directed-progress) in [§ 4.7.6 Calculating the directed
progress](#calculating-the-directed-progress).

#### 4.6.11. Easing (effect timing transformations)

It is often desirable to control the rate at which an [animation
effect](#animation-effect)
progresses. For example, easing the rate of animation can create a sense
of momentum and produce a more natural effect. The [CSS Easing Functions
Module](https://www.w3.org/TR/css-easing/) defines [easing
functions](https://drafts.csswg.org/css-easing-2/#easing-function) for this purpose.
[\[CSS-EASING-1\]](#biblio-css-easing-1 "CSS Easing Functions Level 1")

[Animation effects](#animation-effect) each have an [effect easing
function], which is an
[easing
function](https://drafts.csswg.org/css-easing-2/#easing-function) used to transform progress across the entirety of each
iteration. See [§ 4.7.7 Calculating the transformed
progress](#calculating-the-transformed-progress).

The default [effect easing
function](#animation-effect-effect-easing-function) is the [linear easing
function](https://drafts.csswg.org/css-easing-2/#linear-easing-function).

 Specific [types of animation
effects](#types-of-animation-effects) may provide additional time
transformations. For example, [keyframe
effects](#keyframe-effect)
can provide [keyframe-specific easing
functions](#keyframe-specific-easing-function) that can apply an [easing
function](https://drafts.csswg.org/css-easing-2/#easing-function) specifically between two adjacent keyframes.

### 4.7. Calculating progress

#### 4.7.1. Overview

::: informative-bg
*This section is non-normative*

At the core of the Web Animations timing model is the process that takes
a [local time](#local-time) value
and converts it to an [iteration
progress](#iteration-progress).

The first step in this process is to calculate the bounds of the [active
interval](#active-interval)
which is determined by the [active
duration](#active-duration).

This process is illustrated below.

![Calculation of the [active
duration](#active-duration)
is based on multiplying the [iteration
duration](#iteration-duration) by the [iteration
count](#iteration-count).](images/active-duration-calculation.svg){a
width="650"}

Having established the [active
duration](#active-duration),
the process for transforming an [animation
effect](#animation-effect)'s [local time](#local-time) into its [transformed
progress](#transformed-progress) ([iteration
progress](#iteration-progress)) is illustrated below.

![An overview of timing model calculations.\
(1) The [local time](#local-time)
is determined from the associated
[animation](#concept-animation).\
(2) The [local time] is converted into an [active
time](#active-time) by
incorporating the [start delay](#start-delay).\
(3) The [active time] is divided by the
[iteration duration](#iteration-duration) incorporating also the [iteration
start](#iteration-start)
property to produce the [overall
progress](#overall-progress).\
(4) The [overall progress] time is then
converted to an offset within a single iteration: the [simple iteration
progress](#simple-iteration-progress).\
(5) The [simple iteration progress]
is converted into a [directed
progress](#directed-progress) by incorporating the [playback
direction](#playback-direction).\
(6) Finally, an [easing
function](https://drafts.csswg.org/css-easing-2/#easing-function) is applied to the [directed
progress] to produce the [transformed
progress](#transformed-progress).](images/time-calculations.svg){a
width="650"}

The first step, calculating the [local
time](#local-time) is described
in [§ 4.6.3 Local time](#local-time-section). Steps 2 to 6 in the
diagram are described in the following sections.

#### 4.7.2. Calculating the active time

The [active time] is based on the [local
time](#local-time) and [start
delay](#start-delay). However,
it is only defined when the [animation
effect](#animation-effect)
should produce an output and hence depends on its [fill
mode](#fill-mode) and phase as
follows:

If the animation effect is in the [before phase](#animation-effect-before-phase),

: The result depends on the first matching condition from the
 following:

 If the [fill mode](#fill-mode) is [backwards](#fill-mode-backwards) or [both](#fill-mode-both),

 : Return the result of evaluating
 `max(`[`local time`](#local-time)` − `[`start delay`](#start-delay)`, 0)`.

 Otherwise,

 : Return an [unresolved](#unresolved) [time value](#time-value).

If the animation effect is in the [active phase](#animation-effect-active-phase),

: Return the result of evaluating
 [`local time`](#local-time)` − `[`start delay`](#start-delay).

If the animation effect is in the [after phase](#animation-effect-after-phase),

: The result depends on the first matching condition from the
 following:

 ::: switch

 If the [fill mode](#fill-mode) is [forwards](#fill-mode-forwards) or [both](#fill-mode-both),

 : Return the result of evaluating
 `max(min(`[`local time`](#local-time)` − `[`start delay`](#start-delay)`, `[`active duration`](#active-duration)`), 0)`.

 Otherwise,

 : Return an [unresolved](#unresolved) [time value](#time-value).
 :::

Otherwise (the [local time](#local-time) is [unresolved](#unresolved)),

: Return an [unresolved](#unresolved) [time value](#time-value).

#### 4.7.3. Calculating the overall progress

The [overall progress] describes the number of iterations that have
completed (including partial iterations) and is defined as follows:

1. If the [active time](#active-time) is [unresolved](#unresolved), return [unresolved].

2. Calculate an initial value for `overall progress` based
 on the first matching condition below:

 ::: switch

 If the [iteration duration](#iteration-duration) is zero,

 : If the animation effect is in the [before
 phase](#animation-effect-before-phase), let `overall progress` be zero;
 otherwise, let it be equal to the [iteration
 count](#iteration-count).

 Otherwise,

 : Let `overall progress` be the result of calculating
 [`active time`](#active-time)` / `[`iteration duration`](#iteration-duration).
 :::

3. Return the result of calculating
 `overall progress`` + `[`iteration start`](#iteration-start).

Tests

- [overallProgress.html](https://wpt.fyi/results/web-animations/interfaces/Animation/overallProgress.html "web-animations/interfaces/Animation/overallProgress.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/overallProgress.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/overallProgress.html)

#### 4.7.4. Calculating the simple iteration progress

The [simple iteration progress] is a fraction of the progress
through the current iteration that ignores transformations to the time
introduced by the [playback
direction](#playback-direction) or [easing
functions](https://drafts.csswg.org/css-easing-2/#easing-function) applied to the effect, and is calculated as follows:

1. If the [overall
 progress](#overall-progress) is [unresolved](#unresolved), return [unresolved].

2. If [overall progress](#overall-progress) is infinity, let the
 `simple iteration progress` be
 [`iteration start`](#iteration-start)` % 1.0`; otherwise, let the
 `simple iteration progress` be
 [`overall progress`](#overall-progress)` % 1.0`.

3. If *all* of the following conditions are true:

 - the `simple iteration progress` calculated above is
 zero, *and*

 - the animation effect is in the [active
 phase](#animation-effect-active-phase) *or* the [after
 phase](#animation-effect-after-phase), *and*

 - the [active time](#active-time) is equal to the [active
 duration](#active-duration), *and*

 - the [iteration count](#iteration-count) is *not* equal to zero.

 Let the `simple iteration progress` be 1.0.

 :::
 The above step implements the behavior that when an animation's
 active interval ends precisely at the end of an iteration, it fills
 by holding the endpoint of the final iteration rather than the start
 of the next iteration.

 The final condition prevents this from applying when we never played
 any iterations of the animation to begin with because the [iteration
 count](#iteration-count)
 was zero.
 :::

4. Return `simple iteration progress`.

#### 4.7.5. Calculating the [current iteration index]
The [current iteration index] can be calculated using the following steps:

1. If the [active time](#active-time) is [unresolved](#unresolved), return [unresolved].

2. If the animation effect is in the [after
 phase](#animation-effect-after-phase) *and* the [iteration
 count](#iteration-count)
 is infinity, return infinity.

3. If the [simple iteration
 progress](#simple-iteration-progress) is 1.0, return
 `floor(`[`overall progress`](#overall-progress)`) − 1`.

4. Otherwise, return
 `floor(`[`overall progress`](#overall-progress)`)`.

#### 4.7.6. Calculating the directed progress

The [directed progress] is calculated from the [simple iteration
progress](#simple-iteration-progress) using the following steps:

1. If the [simple iteration
 progress](#simple-iteration-progress) is [unresolved](#unresolved), return [unresolved].

2. Calculate the `current direction` using the first
 matching condition from the following list:

 If [playback direction](#playback-direction) is [normal](#playback-direction-normal),

 : Let the `current direction` be forwards.

 If [playback direction](#playback-direction) is [reverse](#playback-direction-reverse),

 : Let the `current direction` be reverse.

 Otherwise (the [playback direction](#playback-direction) is [alternate](#playback-direction-alternate) or [alternate-reverse](#playback-direction-alternate-reverse))p,

 : 1. Let `d` be the [current iteration
 index](#current-iteration-index).

 2. If [playback
 direction](#playback-direction) is
 [alternate-reverse](#playback-direction-alternate-reverse) increment `d` by 1.

 3. If `d`` % 2 == 0`, let the
 `current direction` be forwards; otherwise let
 the `current direction` be reverse. If
 `d` is infinity, let the
 `current direction` be forwards.

3. If the `current direction` is forwards then return the
 [simple iteration
 progress](#simple-iteration-progress).

 Otherwise, return
 `1.0 − `[`simple iteration progress`](#simple-iteration-progress).

#### 4.7.7. Calculating the transformed progress

The [transformed progress] is calculated from the [directed
progress](#directed-progress) using the following steps:

1. If the [directed
 progress](#directed-progress) is [unresolved](#unresolved), return [unresolved].

2. Calculate the value of the `before flag` as follows:

 1. Determine the `current direction` using the procedure
 defined in [§ 4.7.6 Calculating the directed
 progress](#calculating-the-directed-progress).

 2. If the `current direction` is
 [forwards], let `going forwards` be
 true; otherwise it is false.

 3. The `before flag` is set if the animation effect is
 in the [before
 phase](#animation-effect-before-phase) and `going forwards` is true; or if
 the animation effect is in the [after
 phase](#animation-effect-after-phase) and `going forwards` is false.

3. Return the result of evaluating the [effect easing
 function](#animation-effect-effect-easing-function) passing [directed
 progress](#directed-progress) as the [input progress
 value](https://drafts.csswg.org/css-easing-2/#easing-function-input-progress-value) and `before flag` as the [before
 flag](https://drafts.csswg.org/css-easing-2/#easing-function-before-flag).

#### 4.7.8. Yielding the iteration progress

The final output [iteration progress] of an [animation
effect](#animation-effect)
is simply its [transformed
progress](#transformed-progress).

## 5. Animation model

::: informative-bg
*This section is non-normative*

For some kinds of [animation
effects](#animation-effect), the [Web Animations [animation
model](#animation-model-dfn)] takes the [iteration
progress](#iteration-progress) and [iteration
index](#current-iteration-index) values produced by the [timing
model](#web-animations-timing-model) and uses them to calculate a corresponding output.

The output of each such animation effect is then combined with that of
others using an [effect stack](#effect-stack) before being applied to the [target
properties](#target-property)
(see [§ 5.4 Combining effects](#combining-effects)).

### 5.1. Introduction

An [animation effect](#animation-effect) has zero or more associated properties that it affects
in response to changes to its timing output. These properties are
referred to as the effect's [target properties].

Given an [iteration
progress](#iteration-progress), an [iteration
index](#current-iteration-index), and an [underlying
value](#underlying-value), an
[animation effect](#animation-effect) produces an [effect value] for each
[animatable](#concept-animatable) [target
property](#target-property)
by applying the procedures from the [animation
type](#animation-type)
appropriate to the property.

### 5.2. Animating properties

Unless otherwise specified, all CSS properties are
[animatable]. How property values combine is defined by the [Animation
type] line
in each property's property definition table:

[not animatable]

: The property is not animatable. It is not processed when listed in
 an animation keyframe, and is not affected by transitions.

 Properties are typically excluded from animation
 because animating them would create excessive complications. For
 example, properties defining animation parameters are [not
 animatable](#not-animatable) since doing so would create complex recursive
 behavior.

 An [animation
 effect](#animation-effect) that targets only properties that are [not
 animatable](#not-animatable) will still exhibit the usual behavior for an
 [animation effect] such as firing
 events and delaying the fulfillment of the
 [animation](#concept-animation)'s [current finished
 promise](#current-finished-promise).

[discrete]

: The property's values cannot be meaningfully combined, thus it is
 [not
 additive](https://drafts.csswg.org/css-values-4/#not-additive).
 [Interpolation](https://drafts.csswg.org/css-values-4/#interpolation) swaps from `V`~`a`~ to
 `V`~`b`~ at 50% (`p=0.5`), i.e.

 :::
 $V_{result} = \begin{cases}
 V_{start} & {\text{if~}p < 0.5} \\
 V_{end} & {\text{if~}p \geq 0.5}
 \end{cases}$
 :::

[by computed value]

: Corresponding individual components of the [computed
 values](https://drafts.csswg.org/css-cascade-5/#computed-value) are combined (interpolated, added, or accumulated)
 using the indicated procedure for that value type (see [CSS Values 4
 § 3 Combining Values: Interpolation, Addition, and
 Accumulation](https://drafts.csswg.org/css-values-4/#combining-values)).
 If the number of components or the types of corresponding components
 do not match, or if any component value uses
 [discrete](#discrete) animation
 and the two corresponding values do not match, then the property
 values combine as [discrete].

[repeatable list]

: Same as [by computed
 value](#by-computed-value) except that if the two lists have differing numbers
 of items, they are first repeated to the least common multiple
 number of items. Each item is then combined [by computed
 value]. If a pair of values cannot be
 combined or if any component value uses
 [discrete](#discrete) animation,
 then the property values combine as [discrete].

 The repeatable list concept ensures that a list
 that is conceptually repeated to a certain length (as
 [background-origin](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-origin) is repeated to the length of
 the
 [background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image) list) or repeated infinitely
 will smoothly transition between any values, and so that the
 computed value will properly represent the result (and potentially
 be inherited correctly).

(See prose)
: Some properties have specific interpolation behavior not covered by
 the above cases; in this case the animation behavior will be
 specified explicitly for that property.

The [animation type](#animation-type) of properties that do not yet include an [Animation
type] line in their property definition, is
defined in [Appendix A: Animation types of existing
properties](#animation-types).

#### 5.2.1. Custom Properties

For [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) registered using the
[`registerProperty()`](https://drafts.css-houdini.org/css-properties-values-api-1/#dom-css-registerproperty) method for the [current global
object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object), the [animation
type](#animation-type) is [by
computed value](#by-computed-value), derived from the type used in the property's [syntax
definition](https://drafts.css-houdini.org/css-properties-values-api-1/#syntax-definition). Where there is no [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) type that corresponds to the property's specified
syntax (e.g. when the syntax is the [universal syntax
definition](https://drafts.css-houdini.org/css-properties-values-api-1/#universal-syntax-definition)) or when the [custom
property] is not registered, the [animation
type] is
[discrete](#discrete).

### 5.3. Keyframe effects

[Keyframe effects] are a kind of [animation
effect](#animation-effect)
that uses the output of the timing model to update CSS properties of an
element or
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) (such as `::before` or `::after`
[\[select\]](#biblio-select "Selectors Level 3"))
referred to as the [effect target].

The [effect
target](#keyframe-effect-effect-target) is comprised of an
[`Element`](https://dom.spec.whatwg.org/#element) known as the [target
element] and a
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) selector known as the [target
pseudo-selector]. If the [effect
target] is an
[`Element`](https://dom.spec.whatwg.org/#element), the [target
element](#effect-target-target-element) is that element and the [target
pseudo-selector](#effect-target-target-pseudo-selector) is null. If the [effect
target] is a
[pseudo-element], the [target
element] is its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) and the [target
pseudo-selector] is one
that specifies that particular
[pseudo-element].

Note that not all [effect
targets](#keyframe-effect-effect-target) specified in this manner (such as
[::part()](https://drafts.csswg.org/css-shadow-1/#selectordef-part) pseudo-elements and unsupported pseudo-elements)
have computed property values defined.

#### 5.3.1. Keyframes

The [effect values](#effect-value) for a [keyframe
effect](#keyframe-effect) are
calculated by interpolating between a series of property values
positioned at fractional offsets. Each set of property values indexed by
an offset is called a [keyframe].

The [offset of a keyframe] is a value in the range
\[0, 1\] or the special value null. The list of
[keyframes](#keyframe) for a
[keyframe effect](#keyframe-effect) must be [loosely sorted by
offset], which means that for each [keyframe]
in the list that has a [keyframe
offset](#keyframe-offset) that
is not null, the offset must be greater than or equal to the offset of
the previous [keyframe] in the list with a [keyframe
offset] that is not null, if any.

The behavior when [keyframes](#keyframe) overlap or have unsupported values is defined in
[§ 5.3.4 The effect value of a keyframe
effect](#the-effect-value-of-a-keyframe-animation-effect).

Each keyframe also has a [keyframe-specific easing
function] associated with it, which is an [easing
function](https://drafts.csswg.org/css-easing-2/#easing-function) that is applied to the period of time between the
keyframe on which it is specified and the *next* keyframe in the list.

 The [easing
function](https://drafts.csswg.org/css-easing-2/#easing-function) specified on the last keyframe in the list is never
applied.

Each [keyframe](#keyframe) may have
a [keyframe-specific composite
operation] that, if set, is applied to all values
specified in that [keyframe]. The possible
operations and their meanings are identical to those defined for the
[composite operation](#composite-operation) associated with the [keyframe
effect](#keyframe-effect) as
a whole in [§ 5.4.4 Effect composition](#effect-composition). If the
[keyframe-specific composite
operation](#keyframe-specific-composite-operation) for a [keyframe] is not set, the
[composite operation] specified for the
[keyframe effect] as a whole is used for
values specified in that keyframe.

Tests

- [applying-interpolated-transform.html](https://wpt.fyi/results/web-animations/animation-model/combining-effects/applying-interpolated-transform.html "web-animations/animation-model/combining-effects/applying-interpolated-transform.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/combining-effects/applying-interpolated-transform.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/combining-effects/applying-interpolated-transform.html)

#### 5.3.2. Computing property values

To [compute a property value] given a property
`property`, a value `value`, and an
[`Element`](https://dom.spec.whatwg.org/#element) `element`: resolve `value`
according to the "Computed Value" line of the `property`'s
definition table, using the [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) of `element` as the context for resolving
dependencies, and return the result.

 The [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) on `element` are not affected by this
algorithm.

This algorithm implies that property values specified in keyframes can
establish order dependencies. When [computing a property
value](#compute-a-property-value), the [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) of dependencies held by `value` must be
calculated *first*.

``` highlight
var animation = elem.animate([{ fontSize: '10px', width: '10em' },
 { fontSize: '20px', width: '20em' }], 1000);
animation.currentTime = 500;
console.log(getComputedStyle(elem).fontSize); // Should be 15px
console.log(getComputedStyle(elem).width); // Should be 225px
```

In this example, in order to [compute a property
value](#compute-a-property-value) for `10em`, we need to know the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) on the [target
element](#effect-target-target-element), which in turn is determined by the [effect
value](#effect-value) for
[font-size], which in turn
depends on computing property values for
[font-size]. Hence, computing
property values are subject to ordering constraints.

#### 5.3.3. Calculating computed keyframes

Before calculating the [effect
value](#effect-value) of a
[keyframe effect](#keyframe-effect), the property values on its
[keyframes](#keyframe) are
[computed](#computing-property-values), and the offset to use for any
keyframes with a null [keyframe
offset](#keyframe-offset) is
computed. The result of resolving these values is a set of [computed
keyframes].

The calculated [keyframe
offsets](#keyframe-offset) of
a set of [keyframe](#keyframe) that
includes suitable values for each null [keyframe
offset] are referred to as the [computed
keyframe offsets].

To produce [computed keyframe
offsets](#computed-keyframe-offsets), we define a procedure to [compute missing keyframe
offsets] that takes a sequence of
[keyframes](#keyframe),
`keyframes`, and has the following steps:

1. For each [keyframe](#keyframe)
 in `keyframes`, let the [computed keyframe
 offset](#computed-keyframe-offsets) of the [keyframe] be equal to
 its [keyframe offset](#keyframe-offset) value.

2. If `keyframes` contains more than one
 [keyframe](#keyframe) and the
 [computed keyframe
 offset](#computed-keyframe-offsets) of the first [keyframe] in
 `keyframes` is null, set the [computed keyframe
 offset] of the first
 [keyframe] to 0.

3. If the [computed keyframe
 offset](#computed-keyframe-offsets) of the last
 [keyframe](#keyframe) in
 `keyframes` is null, set its [computed keyframe
 offset] to 1.

4. For each pair of [keyframes](#keyframe) `A` and `B` where:

 - `A` appears before `B` in
 `keyframes`, and

 - `A` and `B` have a [computed keyframe
 offset](#computed-keyframe-offsets) that is not null, and

 - all [keyframes](#keyframe)
 between `A` and `B` have a null [computed
 keyframe
 offset](#computed-keyframe-offsets),

 calculate the [computed keyframe
 offset](#computed-keyframe-offsets) of each [keyframe](#keyframe) between `A` and `B` as
 follows:

 1. Let [offset~`k`~] be the [computed keyframe
 offset](#computed-keyframe-offsets) of a [keyframe](#keyframe) `k`.

 2. Let `n` be the number of keyframes *between* and
 including `A` and `B` minus 1.

 3. Let `index` refer to the position of
 `keyframe` in the sequence of keyframes between
 `A` and `B` such that the first keyframe
 after `A` has an `index` of 1.

 4. Set the [computed keyframe
 offset](#computed-keyframe-offsets) of `keyframe` to
 [offset](#offsetk)~`A`~ +
 ([offset]~`B`~ −
 [offset]~`A`~) ×
 `index` / `n`.

- [background-shorthand.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/background-shorthand.html "web-animations/animation-model/keyframe-effects/background-shorthand.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/background-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/background-shorthand.html)
- [computed-keyframes-shorthands.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/computed-keyframes-shorthands.html "web-animations/animation-model/keyframe-effects/computed-keyframes-shorthands.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/computed-keyframes-shorthands.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/computed-keyframes-shorthands.html)
- [effect-value-context-filling.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-value-context-filling.html "web-animations/animation-model/keyframe-effects/effect-value-context-filling.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-value-context-filling.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-value-context-filling.html)
- [effect-value-context.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-value-context.html "web-animations/animation-model/keyframe-effects/effect-value-context.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-value-context.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-value-context.html)

[Computed keyframes](#computed-keyframes) are produced using the following procedure. Note that
this procedure is only performed on a [keyframe
effect](#keyframe-effect)
having an [effect
target](#keyframe-effect-effect-target) for which computed property values can be calculated.

1. Let `computed keyframes` be an empty list of
 [keyframes](#keyframe).

2. For each `keyframe` in the list of
 [keyframes](#keyframe)
 specified on this [keyframe
 effect](#keyframe-effect), perform the following steps:

 1. Add a new empty [keyframe](#keyframe), `computed keyframe`, to
 `computed keyframes`.

 2. For each property specified in `keyframe`:

 - [Compute a property
 value](#compute-a-property-value) using the value specified on
 `keyframe` as the value, and the [target
 element](#effect-target-target-element) as the element; then add the property and
 resulting value to `computed keyframe`.

 - For shorthand properties, add the equivalent longhand
 properties.

 - For logical properties
 [\[CSS-LOGICAL-1\]](#biblio-css-logical-1 "CSS Logical Properties and Values Module Level 1"),
 add the [equivalent physical
 properties](https://drafts.csswg.org/css-writing-modes-4/#logical-to-physical)
 [\[CSS-WRITING-MODES-4\]](#biblio-css-writing-modes-4 "CSS Writing Modes Level 4")
 based on the computed value of
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) and/or
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) for the [effect
 target](#keyframe-effect-effect-target).

 For example, if `keyframe` has a value of
 [12pt] for the
 [border-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-width) [shorthand
 property](https://drafts.csswg.org/css-cascade-5/#shorthand-property), the user agent will [compute a property
 value](#compute-a-property-value) of [16px] for each of the [longhand
 properties](https://drafts.csswg.org/css-cascade-5/#longhand):
 [border-bottom-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-bottom-width),
 [border-left-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-left-width),
 [border-right-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-right-width), and
 [border-top-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-width). As a result,
 `computed keyframe` would *not* have a value for the
 [border-width]
 property, but would instead include each of the longhand
 properties, each with the value [16px].

 If conflicts arise when expanding shorthand properties or
 replacing logical properties with physical properties, apply the
 following rules in order until the conflict is resolved:

 1. Longhand properties override shorthand properties (e.g.
 [border-top-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-color) overrides
 [border-top](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top)).

 2. Shorthand properties with fewer longhand components override
 those with more longhand components (e.g.
 [border-top](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top) overrides
 [border-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-color)).

 3. Physical properties override logical properties.

 4. For shorthand properties with an equal number of longhand
 components, properties whose IDL name (see the [CSS property
 to IDL
 attribute](https://drafts.csswg.org/cssom/#css-property-to-idl-attribute) algorithm
 [\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)"))
 appears earlier when sorted in ascending order by the
 Unicode codepoints that make up each IDL name, override
 those who appear later.

3. Apply the procedure to [compute missing keyframe
 offsets](#compute-missing-keyframe-offsets) to `computed keyframes`.

4. Return `computed keyframes`.

#### 5.3.4. The effect value of a keyframe effect

The [effect value](#effect-value) of a single property referenced by a [keyframe
effect](#keyframe-effect) as
one of its [target
properties](#target-property), for a given `iteration progress`,
`iteration index` and `underlying value` is
calculated as follows.

1. If `iteration progress` is
 [unresolved](#unresolved)
 abort this procedure.

2. Let `target property` be the [longhand
 property](https://drafts.csswg.org/css-cascade-5/#longhand) for which the [effect
 value](#effect-value) is to
 be calculated.

3. If [animation type](#animation-type) of the `target property` is [not
 animatable](#not-animatable) abort this procedure since the effect cannot be
 applied.

4. If the [keyframe
 effect](#keyframe-effect) does not have an [effect
 target](#keyframe-effect-effect-target), or if the [effect
 target] cannot have
 computed property values calculated, abort this procedure.

5. Let `property-specific keyframes` be the result of
 getting the set of [computed
 keyframes](#computed-keyframes) for this [keyframe
 effect](#keyframe-effect).

6. Remove any [keyframes](#keyframe) from `property-specific keyframes` that
 do not have a property value for `target property`.

7. If `property-specific keyframes` is empty, return
 `underlying value`.

8. If there is no [keyframe](#keyframe) in `property-specific keyframes` with a
 [computed keyframe
 offset](#computed-keyframe-offsets) of 0, create a new [keyframe]
 with a [computed keyframe
 offset] of 0, a property value
 set to `underlying value`, a [keyframe-specific composite
 operation](#keyframe-specific-composite-operation) of
 [replace](#composite-operation-replace), and a [keyframe-specific easing
 function](#keyframe-specific-easing-function) of the [linear easing
 function](https://drafts.csswg.org/css-easing-2/#linear-easing-function), and prepend it to the beginning of
 `property-specific keyframes`.

9. Similarly, if there is no [keyframe](#keyframe) in `property-specific keyframes` with a
 [computed keyframe
 offset](#computed-keyframe-offsets) of 1, create a new [keyframe]
 with a [computed keyframe
 offset] of 1, a property value
 set to `underlying value`, a [keyframe-specific composite
 operation](#keyframe-specific-composite-operation) of
 [replace](#composite-operation-replace), and a [keyframe-specific easing
 function](#keyframe-specific-easing-function) of the [linear easing
 function](https://drafts.csswg.org/css-easing-2/#linear-easing-function), and append it to the end of
 `property-specific keyframes`.

Other specifications may override the implicit keyframe generation
behavior in the preceding two steps. For example, the [named timeline
range keyframe
selectors](https://drafts.csswg.org/scroll-animations-1/#named-range-keyframes)
defined by Scroll Animations can cause these implicit keyframes not to
be generated.

A future level of this specification should incorporate the overridden
behavior directly into this algorithm.

1. Let `interval endpoints` be an empty sequence of
 keyframes.

2. Populate `interval endpoints` by following the steps from
 the first matching condition below:

 If `iteration progress` \< 0 and there is more than one [keyframe](#keyframe) in `property-specific keyframes` with a [computed keyframe offset](#computed-keyframe-offsets) of 0,

 : Add the first [keyframe](#keyframe) in `property-specific keyframes` to
 `interval endpoints`.

 If `iteration progress` ≥ 1 and there is more than one [keyframe](#keyframe) in `property-specific keyframes` with a [computed keyframe offset](#computed-keyframe-offsets) of 1,

 : Add the last [keyframe](#keyframe) in `property-specific keyframes` to
 `interval endpoints`.

 Otherwise,

 : 1. Append to `interval endpoints` the last
 [keyframe](#keyframe)
 in `property-specific keyframes` whose [computed
 keyframe
 offset](#computed-keyframe-offsets) is less than or equal to
 `iteration progress` and less than 1. If there is
 no such [keyframe] (because, for
 example, the [iteration
 progress](#iteration-progress) is negative), add the last
 [keyframe] whose [computed keyframe
 offset] is 0.

 2. Append to `interval endpoints` the next
 [keyframe](#keyframe)
 in `property-specific keyframes` after the one
 added in the previous step.

3. For each `keyframe` in `interval endpoints`:

 1. If `keyframe` has a [composite
 operation](#composite-operation) that is *not*
 [replace](#composite-operation-replace), or `keyframe` has no [composite
 operation] and the [composite
 operation] of this [keyframe
 effect](#keyframe-effect) is *not*
 [replace], then perform
 the following steps:

 1. Let `composite operation to use` be the
 [composite
 operation](#composite-operation) of `keyframe`, or if it has
 none, the [composite
 operation] of this [keyframe
 effect](#keyframe-effect).

 2. Let `value to combine` be the property value of
 `target property` specified on
 `keyframe`.

 3. Replace the property value of `target property`
 on `keyframe` with the result of combining
 `underlying value` (`V`~a~) and
 `value to combine` (`V`~b~) using the
 procedure for the `composite operation to use`
 corresponding to the `target property`'s
 [animation type](#animation-type).

4. If there is only one keyframe in `interval endpoints`
 return the property value of `target property` on that
 keyframe.

5. Let `start offset` be the [computed keyframe
 offset](#computed-keyframe-offsets) of the first keyframe in
 `interval endpoints`.

6. Let `end offset` be the [computed keyframe
 offset](#computed-keyframe-offsets) of last keyframe in
 `interval endpoints`.

7. Let `interval distance` be the result of evaluating
 `(``iteration progress`` − ``start offset``) / (``end offset`` − ``start offset``)`.

8. Let `transformed distance` be the result of evaluating
 the [easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function) associated with the first keyframe in
 `interval endpoints` passing
 `interval distance` as the input progress.

9. Return the result of applying the [interpolation
 procedure](https://drafts.csswg.org/css-values-4/#interpolation) defined by the [animation
 type](#animation-type) of
 the `target property` to the values of the
 `target property` specified on the two keyframes in
 `interval endpoints`, taking the first such value as
 `V`~start~ and the second as `V`~end~ and
 using `transformed distance` as the interpolation
 parameter `p`.

Tests

- [effect-value-interval-distance.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-value-interval-distance.html "web-animations/animation-model/keyframe-effects/effect-value-interval-distance.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-value-interval-distance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-value-interval-distance.html)
- [effect-value-iteration-composite-operation.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-value-iteration-composite-operation.html "web-animations/animation-model/keyframe-effects/effect-value-iteration-composite-operation.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-value-iteration-composite-operation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-value-iteration-composite-operation.html)
- [effect-value-opacity-replaced-effect-in-shadow-root.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-value-opacity-replaced-effect-in-shadow-root.html "web-animations/animation-model/keyframe-effects/effect-value-opacity-replaced-effect-in-shadow-root.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-value-opacity-replaced-effect-in-shadow-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-value-opacity-replaced-effect-in-shadow-root.html)
- [effect-value-opacity-replaced-effect.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-value-opacity-replaced-effect.html "web-animations/animation-model/keyframe-effects/effect-value-opacity-replaced-effect.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-value-opacity-replaced-effect.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-value-opacity-replaced-effect.html)
- [effect-value-overlapping-keyframes.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-value-overlapping-keyframes.html "web-animations/animation-model/keyframe-effects/effect-value-overlapping-keyframes.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-value-overlapping-keyframes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-value-overlapping-keyframes.html)
- [effect-value-replaced-animations.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-value-replaced-animations.html "web-animations/animation-model/keyframe-effects/effect-value-replaced-animations.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-value-replaced-animations.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-value-replaced-animations.html)
- [effect-value-transformed-distance.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-value-transformed-distance.html "web-animations/animation-model/keyframe-effects/effect-value-transformed-distance.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-value-transformed-distance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-value-transformed-distance.html)

Note that this procedure assumes the following about the list of
[keyframes](#keyframe) specified on
the effect:

- Each [keyframe](#keyframe) has a
 specified [computed keyframe
 offset](#computed-keyframe-offsets) in the range \[0, 1\].

- The list of [keyframes](#keyframe) is sorted in ascending order by [computed keyframe
 offset](#computed-keyframe-offsets).

- For a given property, there is at most one specified property value on
 each keyframe.

It is the responsibility of the user of the model (for example, a
declarative markup or programming interface) to ensure these conditions
are met.

For example, for the [programming interface](#programming-interface)
defined by this specification, these conditions are met by the procedure
to produce the [computed
keyframes](#computed-keyframes) that become the input to this procedure.

 this procedure permits overlapping
[keyframes](#keyframe). The
behavior is that at the point of overlap the output value jumps to the
value of the last defined [keyframe] at that
offset. For overlapping keyframes at 0 or 1, the output value for
[iteration progress](#iteration-progress) values less than 0 or greater than or equal to 1 is the
value of the first [keyframe] or the last
[keyframe] in `keyframes` respectively.

Note that [computed
keyframes](#computed-keyframes) are "live": user-agents behave as if they are recreated
every time the [effect value](#effect-value) is calculated.

For example, if there is an ongoing transition on the
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) property from `10px` to `20px`, a
property value specified as `1em` in a
[keyframe](#keyframe) would during
[keyframe computation](#calculating-computed-keyframes) resolve against
the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) in the range \[`10px`, `20px`\] produced by the
transition on [font-size].

### 5.4. Combining effects

::: informative-bg
*This section is non-normative*

After calculating the [effect
values](#effect-value) for a
[keyframe effect](#keyframe-effect), they are applied to the [animation
effect](#animation-effect)'s [target
properties](#target-property).

Since it is possible for multiple [in
effect](#in-effect) [keyframe
effects](#keyframe-effect)
to target the same property it is often necessary to combine the results
of several [keyframe effects] together. This
process is called [compositing] and is based on
establishing an [effect stack](#effect-stack) for each property targeted by an [in
effect] [animation
effect](#animation-effect).

After [compositing](#composite) the
results of [keyframe
effects](#keyframe-effect)
together, the composited result is combined with other values specified
for the [target property](#target-property).

The arrangement is illustrated below:

![Overview of the application of [effect
values](#effect-value) to their
[target properties](#target-property).\
The results of [keyframe
effects](#keyframe-effect)
targeting the same property are composited together using an [effect
stack](#effect-stack).\
The result of this composition is then inserted into the CSS cascade at
an appropriate
point.](images/animation-cascade.svg){a
width="500"}

For the first part of this operation---​combining [effect
values](#effect-value) that
target the same [property](#target-property)---​it is necessary to determine both *how* [keyframe
effects](#keyframe-effect)
are combined with one another, as well as the *order* in which they are
applied, that is, their relative *composite order*.

The matter of *how* [effect
values](#effect-value) are
combined is governed by the [composite
operation](#composite-operation) of the corresponding [keyframe
effects](#keyframe-effect).

The relative *composite order* of [effect
values](#effect-value) is
determined by an [effect stack](#effect-stack) established for each animated property.

#### 5.4.1. Animation classes

This specification provides a common animation model intended to be used
by other specifications that define markup or programming interfaces on
top of this model. The particular markup or programming interface that
generated an
[animation](#concept-animation) defines its [animation class].

Further specifications may define specialized behavior for composite
ordering between different classes of animations or within a particular
class.

::: informative-bg
*This section is non-normative*

For example, animations whose
[class](#animation-class) is
"CSS animation" are defined as having a *higher* composite order than
animations whose class is "CSS transition" but *lower* than other
animations without a specific class.

Within the set of "CSS animation" objects, specialized composite
ordering is defined based on the
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) property amongst other factors.

#### 5.4.2. The effect stack

An [effect stack] is associated with each property
[targeted](#target-property)
by one or more [keyframe
effects](#keyframe-effect).
The [effect stack](#effect-stack) establishes the relative composite order of [keyframe
effects].

The relative [composite order] of any two [keyframe
effects](#keyframe-effect)
`A` and `B` within an [effect
stack](#effect-stack) is
established by comparing their properties as follows:

1. Sort `A` and `B` by applying the following
 conditions in turn until the order is resolved,

 1. If `A` and `B`'s [associated
 animations](#animation-effect-associated-animation) differ by
 [class](#animation-class), sort by any inter-class composite order as
 defined for the corresponding classes.

 2. If `A` and `B` are still not sorted, sort
 by any [class](#animation-class)-specific composite order defined by the common
 class of `A` and `B`'s [associated
 animations](#animation-effect-associated-animation).

 3. If `A` and `B` are still not sorted, sort
 by the position of their [associated
 animations](#animation-effect-associated-animation) in the [global animation
 list](#global-animation-list).

[Animation effects](#animation-effect) that sort earlier have *lower* composite order.

#### 5.4.3. Calculating the result of an effect stack

In order to calculate the final value of an [effect
stack](#effect-stack), the
[effect values](#effect-value)
of each [keyframe effect](#keyframe-effect) in the stack are combined in composite order.

Each step in the process of evaluating an [effect
stack](#effect-stack) takes an
[underlying value] as input.

For each [keyframe effect](#keyframe-effect) in the stack, the appropriate [effect
value](#effect-value) from the
[keyframe effect] is combined with the
[underlying value](#underlying-value) to produce a new value. This resulting value becomes
the [underlying value] for combining the
next [keyframe effect] in the stack.

The final value of an [effect
stack](#effect-stack), called
the [composited value], is simply the result of combining the
[effect value](#effect-value)
of the final (highest composite order) [keyframe
effect](#keyframe-effect) in
the stack with the [underlying
value](#underlying-value) at
that point.

#### 5.4.4. Effect composition

The specific operation used to combine an [effect
value](#effect-value) with
an[underlying value](#underlying-value) is determined by the [composite
operation] of the [keyframe
effect](#keyframe-effect)
that produced the [effect value].

This specification defines three [composite
operations](#composite-operation) as follows:

[replace]

: The result of compositing the [effect
 value](#effect-value) with
 the [underlying value](#underlying-value) is simply the [effect
 value].

[add]

: The [effect value](#effect-value) is
 [added](https://drafts.csswg.org/css-values-4/#addition) to the [underlying
 value](#underlying-value). For [animation
 types](#animation-type)
 where the [addition operation] is defined such
 that it is not commutative, the order of the operands is
 [`underlying value`](#underlying-value)` + `[`effect value`](#effect-value).

[accumulate]

: The [effect value](#effect-value) is
 [accumulated](https://drafts.csswg.org/css-values-4/#accumulation) onto the [underlying
 value](#underlying-value). For [animation
 types](#animation-type)
 where the [accumulation operation] is
 defined such that it is not commutative, the order of the operands
 is [underlying value] followed by
 [effect value].

Tests

- [effect-composition.html](https://wpt.fyi/results/web-animations/animation-model/combining-effects/effect-composition.html "web-animations/animation-model/combining-effects/effect-composition.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/combining-effects/effect-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/combining-effects/effect-composition.html)

#### 5.4.5. Applying the composited result

Applying a [composited
value](#composited-value) to
a [target property](#target-property) is achieved by adding a specified value to the CSS
cascade.

The level of the cascade to which this specified value is added depends
on the [class](#animation-class) of the
[animation](#concept-animation) [associated
with](#animation-effect-associated-animation) the effect with the highest composite order in the
[effect stack](#effect-stack)
for a given property. By default, the specified value is added to the
[Animation
Origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-animation) of the cascade.
[\[CSS-CASCADE-3\]](#biblio-css-cascade-3 "CSS Cascading and Inheritance Level 3")

Tests

- [applying-the-composited-result.html](https://wpt.fyi/results/web-animations/animation-model/combining-effects/applying-the-composited-result.html "web-animations/animation-model/combining-effects/applying-the-composited-result.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/combining-effects/applying-the-composited-result.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/combining-effects/applying-the-composited-result.html)

For example, if the effect with the
highest composite order is associated with a "CSS transition"-class
animation, the [composited
value](#composited-value)
will be added to the [Transition
Origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-transition) of the cascade.

The [composited value](#composited-value) calculated for a CSS [target
property](#target-property)
is applied using the following process:

1. Calculate the `base value` of the property as the value
 generated for that property by finding the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) for that property in the absence of animations.

2. Establish the [effect stack](#effect-stack) for the property (see [§ 5.4.2 The effect
 stack](#the-effect-stack)).

3. Calculate the [composited
 value](#composited-value) of the [effect
 stack](#effect-stack)
 passing in the `base value` of the property as the
 initial [underlying
 value](#underlying-value) (see [§ 5.4.3 Calculating the result of an effect
 stack](#calculating-the-result-of-an-effect-stack)).

4. Insert the [composited
 value](#composited-value) into the CSS cascade at the level defined for the
 [class](#animation-class)
 of the [animation](#concept-animation) [associated
 with](#animation-effect-associated-animation) the effect at the top of the [effect
 stack](#effect-stack)
 established for the [target
 property](#target-property).

### 5.5. Replacing animations

:::: informative-bg
*This section is non-normative*

Using the programming interface defined in this specification, it is
possible to repeatedly trigger new animations that contribute to an
element's animated style indefinitely.

For example, consider the following code:

``` highlight
elem.addEventListener('mousemove', evt => {
 circle.animate(
 { transform: `translate(${evt.clientX}px, ${evt.clientY}px)` },
 { duration: 500, fill: 'forwards' }
 );
});
```

This will generate a new forwards-filling animation each time the mouse
is moved, quickly producing hundreds, even thousands of forwards-filling
animations.

If the user agent needed to retain *all* such animations, the list of
animations would grow in an unbounded fashion, producing a memory leak.

This section defines a mechanism that causes overridden animations to be
automatically removed unless the author explicitly requests they be
retained.

#### 5.5.1. Replace state

An [animation](#concept-animation) maintains a [replace state] that can be one of the
following values:

- [active]

- [removed]

- [persisted]

The initial value of an
[animation](#concept-animation)'s [replace
state](#replace-state) is
[active](#active-replace-state).

The [animation effects](#animation-effect) of an
[animation](#concept-animation) whose [replace
state](#replace-state) is
[removed](#removed-replace-state) are not included in the [effect
stacks](#effect-stack) of their
[target properties](#target-property).

#### 5.5.2. Removing replaced animations

An [animation](#concept-animation) is [replaceable] if *all* of the following
conditions are true:

- The existence of the
 [animation](#concept-animation) is *not* prescribed by markup. That is, it is *not* a
 CSS animation with an [owning
 element](https://drafts.csswg.org/css-animations-2/#owning-element), nor a CSS transition with an [owning
 element](https://drafts.csswg.org/css-transitions-2/#owning-element).

- The [animation](#concept-animation)'s [play
 state](#animation-play-state) is
 [finished](#play-state-finished).

- The [animation](#concept-animation)'s [replace
 state](#replace-state) is
 *not*
 [removed](#removed-replace-state).

- The [animation](#concept-animation) is associated with a [monotonically
 increasing](#monotonically-increasing-timeline) [timeline](#timeline).

- The [animation](#concept-animation) has an [associated
 effect](#animation-associated-effect).

- The [animation](#concept-animation)'s [associated
 effect](#animation-associated-effect) is [in effect](#in-effect).

- The [animation](#concept-animation)'s [associated
 effect](#animation-associated-effect) has an [effect
 target](#keyframe-effect-effect-target).

When asked to [remove replaced animations] for a
[`Document`](https://html.spec.whatwg.org/#document), `doc`, then for every
[animation](#concept-animation), `animation`, that:

- has an
 [associated](#animation-effect-associated-animation) [animation
 effect](#animation-effect) whose [effect
 target](#keyframe-effect-effect-target) is a
 [descendant](https://dom.spec.whatwg.org/#concept-tree-descendant) of `doc`, and

- is
 [replaceable](#replaceable-animation), and

- has a [replace state](#replace-state) of
 [active](#active-replace-state), and

- for which there exists for each [target
 property](#target-property) of every [animation
 effect](#animation-effect)
 [associated](#animation-effect-associated-animation) with `animation`, an [animation
 effect] associated with a
 [replaceable](#replaceable-animation)
 [animation](#concept-animation) with a higher [composite
 order](#animation-composite-order) than `animation` that includes the same
 [target property]

perform the following steps:

1. Set `animation`'s [replace
 state](#replace-state) to
 [removed](#removed-replace-state).

2. [Create](https://dom.spec.whatwg.org/#concept-event-create) an
 [`AnimationPlaybackEvent`](#animationplaybackevent), `removeEvent`.

3. Set `removeEvent`'s
 [`type`](https://dom.spec.whatwg.org/#dom-event-type) attribute to
 [remove](#remove-event).

4. Set `removeEvent`'s
 [`currentTime`](#dom-animationplaybackevent-currenttime) attribute to the [current
 time](#animation-current-time) of `animation`.

5. Set `removeEvent`'s
 [`timelineTime`](#dom-animationplaybackevent-timelinetime) attribute to the [current
 time](#timeline-current-time) of the [timeline](#timeline) with which `animation` is associated.

6. If `animation` has a [document for
 timing](#animation-document-for-timing), then append `removeEvent` to its
 [document for timing]'s
 [pending animation event
 queue](#pending-animation-event-queue) along with its target, `animation`. For
 the [scheduled event
 time](#scheduled-event-time), use the result of applying the procedure to
 convert [timeline time to origin-relative
 time](#timeline-time-to-origin-relative-time) to the [current
 time](#timeline-current-time) of the [timeline](#timeline) with which `animation` is associated.

 Otherwise, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to
 [dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch) `removeEvent` at `animation`.
 The task source for this task is the [DOM manipulation task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#dom-manipulation-task-source).

### 5.6. Side effects of animation

For every property targeted by at least one [animation
effect](#animation-effect)
that is [current](#current) or [in
effect](#in-effect), and which is
associated with an
[animation](#concept-animation) whose [replace
state](#replace-state) is *not*
[removed](#removed-replace-state), the user agent must act as if the
[will-change](https://drafts.csswg.org/css-will-change-1/#propdef-will-change) property
[\[css-will-change-1\]](#biblio-css-will-change-1 "CSS Will Change Module Level 1")
on the [effect
target](#keyframe-effect-effect-target) includes the property.

Tests

- [side-effects-of-animations-current.html](https://wpt.fyi/results/web-animations/animation-model/side-effects-of-animations-current.html "web-animations/animation-model/side-effects-of-animations-current.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/side-effects-of-animations-current.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/side-effects-of-animations-current.html)
- [side-effects-of-animations-in-effect.html](https://wpt.fyi/results/web-animations/animation-model/side-effects-of-animations-in-effect.html "web-animations/animation-model/side-effects-of-animations-in-effect.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/side-effects-of-animations-in-effect.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/side-effects-of-animations-in-effect.html)
- [side-effects-of-animations-none.html](https://wpt.fyi/results/web-animations/animation-model/side-effects-of-animations-none.html "web-animations/animation-model/side-effects-of-animations-none.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/side-effects-of-animations-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/side-effects-of-animations-none.html)

 As a result of the above requirement, if an animation
targets, for example, the
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) property of an element, a [stacking
context](https://www.w3.org/TR/CSS2/visuren.html#x43) will be created for the [effect
target](#keyframe-effect-effect-target) so long as the
[animation](#concept-animation) is in the [before
phase](#animation-effect-before-phase), the [active
phase](#animation-effect-active-phase) or, if it has a [fill
mode](#fill-mode) of
[forwards](#fill-mode-forwards) or [both](#fill-mode-both), the [after
phase](#animation-effect-after-phase).

## 6. Programming interface

::: informative-bg
*This section is non-normative*

In addition to the abstract model described above, Web Animations also
defines a programming interface to the model. This interface can be used
to inspect and extend animations produced by declarative means or for
directly producing animations when a procedural approach is more
suitable.

Exception annotations in this section list exceptions that originate
from algorithms in this specification. They do not repeat exceptions
produced by converting values according to Web IDL. The procedures for
processing keyframes also propagate exceptions thrown by author-defined
property accessors or iterator methods. Since such exceptions can be of
any type, they are not enumerated in these annotations.

### 6.1. Time values in the programming interface

[Time values](#time-value) are
represented in the programming interface with the type `double`.
[Unresolved](#unresolved) time
values are represented by the value `null`.

### 6.2. The [`AnimationTimeline` interface]
[Timelines](#timeline) are
represented in the Web Animations API by the
[`AnimationTimeline`](#animationtimeline) interface.

```
[Exposed=Window]
interface AnimationTimeline {
 readonly attribute double? currentTime;
};
```

[`currentTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly, nullable

: Returns the [current
 time](#timeline-current-time) for this timeline or `null` if this timeline is
 [inactive](#inactive-timeline).

### 6.3. The [`DocumentTimeline` interface]
[Document timelines](#document-timeline), including the [default document
timeline](#document-default-document-timeline), are represented in the Web Animations API by the
[`DocumentTimeline`](#documenttimeline) interface.

```
dictionary DocumentTimelineOptions {
 DOMHighResTimeStamp originTime = 0;
};

[Exposed=Window]
interface DocumentTimeline : AnimationTimeline {
 constructor(optional DocumentTimelineOptions options = );
};
```

[`originTime`], of type [DOMHighResTimeStamp](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp), defaulting to `0`

: The [origin time](#origin-time) for the timeline specified as a real number of
 milliseconds relative to the [time
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-time-origin).

[`DocumentTimeline (``options``)`]

: Creates a new
 [`DocumentTimeline`](#documenttimeline). The
 [`Document`](https://html.spec.whatwg.org/#document) with which the timeline is associated is the
 [`Document`](https://html.spec.whatwg.org/#document)
 [associated](https://html.spec.whatwg.org/multipage/browsers.html#concept-document-window) with the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) that is the [current global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object).

 ::: parameters

 [`options`]

 : Configuration parameters for the newly-created timeline. This
 specification defines only the
 [`originTime`](#dom-documenttimelineoptions-origintime) member but other specifications may extend this
 set.
 :::

### 6.4. The [`Animation` interface]
[Animations](#concept-animation) are represented in the Web Animations API by the
[`Animation`] interface.

```
[Exposed=Window]
interface Animation : EventTarget {
 constructor(optional AnimationEffect? effect = null,
 optional AnimationTimeline? timeline);
 attribute DOMString id;
 attribute AnimationEffect? effect;
 attribute AnimationTimeline? timeline;
 attribute double? startTime;
 attribute double? currentTime;
 attribute double playbackRate;
 readonly attribute AnimationPlayState playState;
 readonly attribute AnimationReplaceState replaceState;
 readonly attribute boolean pending;
 readonly attribute Promise<Animation> ready;
 readonly attribute Promise<Animation> finished;
 attribute EventHandler onfinish;
 attribute EventHandler oncancel;
 attribute EventHandler onremove;
 undefined cancel();
 undefined finish();
 undefined play();
 undefined pause();
 undefined updatePlaybackRate(double playbackRate);
 undefined reverse();
 undefined persist();
 [CEReactions]
 undefined commitStyles();
};
```

[`Animation (``effect``, ``timeline``)`]

: Creates a new [`Animation`](#animation) object using the following procedure:

 1. Let `animation` be a new
 [`Animation`](#animation) object.

 2. Run the procedure to [set the timeline of an
 animation](#animation-set-the-timeline-of-an-animation) on `animation` passing
 `timeline` as the `new timeline`; or, if
 the `timeline` argument is missing, passing the
 [default document
 timeline](#document-default-document-timeline) of the
 [`Document`](https://html.spec.whatwg.org/#document)
 [associated](https://html.spec.whatwg.org/multipage/browsers.html#concept-document-window) with the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) that is the [current global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object).

 3. Run the procedure to [set the associated effect of an
 animation](#animation-set-the-associated-effect-of-an-animation) on `animation` passing
 `source` as the `new effect`.

 ::: parameters

 [`effect`]

 : An optional value which, if not `null`, specifies the
 [associated
 effect](#animation-associated-effect) to assign to the newly created
 [animation](#concept-animation).

 [`timeline`]

 : An optional value which, if present, specifies the
 [timeline](#timeline) with
 which to associate the newly-created
 [animation](#concept-animation). If missing, the [default document
 timeline](#document-default-document-timeline) of the
 [`Document`](https://html.spec.whatwg.org/#document)
 [associated](https://html.spec.whatwg.org/multipage/browsers.html#concept-document-window) with the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) that is the [current global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object) is used.
 :::

 Tests

 - [constructor.html](https://wpt.fyi/results/web-animations/interfaces/Animation/constructor.html "web-animations/interfaces/Animation/constructor.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/constructor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/constructor.html)

[`id`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)

: A string used to identify the animation.

 Tests

 - [id.html](https://wpt.fyi/results/web-animations/interfaces/Animation/id.html "web-animations/interfaces/Animation/id.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/id.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/id.html)

[`effect`], of type [AnimationEffect](#animationeffect), nullable

: The [associated
 effect](#animation-associated-effect) of this animation. Setting this attribute updates
 the object's [associated
 effect] using the procedure
 to [set the associated effect of an
 animation](#animation-set-the-associated-effect-of-an-animation).

 Tests

 - [effect.html](https://wpt.fyi/results/web-animations/interfaces/Animation/effect.html "web-animations/interfaces/Animation/effect.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/effect.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/effect.html)

[`timeline`], of type [AnimationTimeline](#animationtimeline), nullable

: The [timeline](#timeline)
 associated with this animation. Setting this attribute updates the
 object's [timeline] using the procedure to [set
 the timeline of an
 animation](#animation-set-the-timeline-of-an-animation).

[`startTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), nullable

: Returns the [start
 time](#animation-start-time) of this animation. Setting this attribute updates
 the [start time] using the
 procedure to [set the start
 time](#set-the-start-time) of this object to the new value.

[`currentTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), nullable

: The [current
 time](#animation-current-time) of this animation. Setting this attribute follows
 the procedure to [set the current
 time](#animation-set-the-current-time) of this object to the new value.

[`playbackRate`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: The [playback rate](#playback-rate) of this animation. Setting this attribute follows
 the procedure to [set the playback
 rate](#set-the-playback-rate) of this object to the new value.

 :::
 Setting this attribute performs a synchronous update to the
 [playback rate](#playback-rate) meaning that it does not make any attempt to
 synchronize with the playback state of animations running on a
 separate process or thread. As a result, setting the
 [`playbackRate`](#dom-animation-playbackrate) for an in-flight animation can cause it to jump.

 To set the [playback rate](#playback-rate) for an in-flight animation such that it smoothly
 updates, use the asynchronous
 [`updatePlaybackRate()`](#dom-animation-updateplaybackrate) method.
 :::

[`playState`], of type [AnimationPlayState](#enumdef-animationplaystate), readonly

: The [play
 state](#animation-play-state) of this animation.

[`replaceState`], of type [AnimationReplaceState](#enumdef-animationreplacestate), readonly

: The [replace state](#replace-state) of this animation.

[`pending`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: Returns true if this animation has a [pending play
 task](#pending-play-task) or a [pending pause
 task](#pending-pause-task).

 Tests

 - [pending.html](https://wpt.fyi/results/web-animations/interfaces/Animation/pending.html "web-animations/interfaces/Animation/pending.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/pending.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/pending.html)

[`ready`], of type Promise\<[Animation](#animation)\>, readonly

: Returns the [current ready
 promise](#current-ready-promise) for this object.

 Tests

 - [ready.html](https://wpt.fyi/results/web-animations/interfaces/Animation/ready.html "web-animations/interfaces/Animation/ready.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/ready.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/ready.html)

[`finished`], of type Promise\<[Animation](#animation)\>, readonly

: Returns the [current finished
 promise](#current-finished-promise) for this object.

 Tests

 - [finished.html](https://wpt.fyi/results/web-animations/interfaces/Animation/finished.html "web-animations/interfaces/Animation/finished.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/finished.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/finished.html)

[`onfinish`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event handler for the [finish
 event](#finish-event).

 Tests

 - [onfinish.html](https://wpt.fyi/results/web-animations/interfaces/Animation/onfinish.html "web-animations/interfaces/Animation/onfinish.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/onfinish.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/onfinish.html)

[`oncancel`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event handler for the [cancel
 event](#cancel-event).

 Tests

 - [oncancel.html](https://wpt.fyi/results/web-animations/interfaces/Animation/oncancel.html "web-animations/interfaces/Animation/oncancel.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/oncancel.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/oncancel.html)

[`onremove`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event handler for the [remove
 event](#remove-event).

 Tests

 - [onremove.html](https://wpt.fyi/results/web-animations/interfaces/Animation/onremove.html "web-animations/interfaces/Animation/onremove.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/onremove.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/onremove.html)

[`void cancel()`]

: Clears all effects caused by this animation and aborts its playback
 by running the [cancel an
 animation](#cancel-an-animation) procedure for this object.

 Tests

 - [cancel.html](https://wpt.fyi/results/web-animations/interfaces/Animation/cancel.html "web-animations/interfaces/Animation/cancel.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/cancel.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/cancel.html)

[`void finish()`]

: [Seeks](#seek) the animation to the
 [associated effect
 end](#associated-effect-end) in the current direction by running the [finish an
 animation](#finish-an-animation) procedure for this object.

 ::: exceptions

 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) of type \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"

 : Raised if this animation's [effective playback
 rate](#effective-playback-rate) is zero, or if this animation's [effective
 playback rate] is \> zero
 and the [associated effect
 end](#associated-effect-end) is infinity.
 :::

[`void play()`]

: Begins or resumes playback of the animation by running the procedure
 to [play an
 animation](#play-an-animation) passing true as the value of the
 `auto-rewind` flag.

 ::: exceptions

 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) of type \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"

 : Raised if this animation's [effective playback
 rate](#effective-playback-rate) is negative, the [associated effect
 end](#associated-effect-end) is infinity, and its [current
 time](#animation-current-time) is unresolved or less than or equal to zero.
 :::

[`void pause()`]

: Suspends the playback of this animation by running the procedure to
 [pause an
 animation](#pause-an-animation) for this object.

 ::: exceptions

 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) of type \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"

 : Raised if this animation's [current
 time](#animation-current-time) is unresolved, its [playback
 rate](#playback-rate)
 is negative, and the [associated effect
 end](#associated-effect-end) is infinity.
 :::

 Tests

 - [pause.html](https://wpt.fyi/results/web-animations/interfaces/Animation/pause.html "web-animations/interfaces/Animation/pause.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/pause.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/pause.html)

[`void updatePlaybackRate(``playbackRate``)`]

: Performs an asynchronous update of the [playback
 rate](#playback-rate) of
 this animation by performing the [seamlessly update the playback
 rate](#seamlessly-update-the-playback-rate) procedure, passing
 [`playbackRate`](#dom-animation-updateplaybackrate-playbackrate-playbackrate) as the `new playback rate`.

 ::: parameters

 [`playbackRate`]

 : A finite real number specifying the updated playback rate to
 use.
 :::

[`void reverse()`]

: Inverts the [playback rate](#playback-rate) of this animation and plays it using the [reverse
 an animation](#reverse-an-animation) procedure for this object. As with
 [`play()`](#dom-animation-play), this method unpauses the animation and, if the
 animation has already finished playing in the reversed direction,
 [seeks](#seek) to the start of the
 [associated
 effect](#animation-associated-effect).

 ::: exceptions

 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) of type \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"

 : Raised if this animation has no associated [active
 timeline](#active-timeline), or if its reversed [effective playback
 rate](#effective-playback-rate) would be negative, the [associated effect
 end](#associated-effect-end) is infinity, and its [current
 time](#animation-current-time) is unresolved or less than or equal to zero.
 :::

[`void persist()`]

: Sets this animation's [replace
 state](#replace-state) to
 [persisted](#persisted-replace-state).

[`void commitStyles()`]

: Writes the current [effect
 values](#effect-value)
 produced by this animation's [animation
 effects](#animation-effect) to their corresponding [effect
 targets](#keyframe-effect-effect-target)\' inline style using the [commit computed
 styles](#commit-computed-styles) procedure.

 Unlike most other methods defined on this interface, calling this
 method *does* trigger a [style change
 event](https://drafts.csswg.org/css-transitions-1/#style-change-event) (see [§ 6.13 Model liveness](#model-liveness)).

 ::: exceptions

 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) of type \"[`NoModificationAllowedError`](https://webidl.spec.whatwg.org/#nomodificationallowederror)\"

 : Raised if any [effect
 target](#keyframe-effect-effect-target) is not an element capable of having a [style
 attribute](https://drafts.csswg.org/css-style-attr/#style-attribute).

 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) of type \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"

 : Raised if any [effect
 target](#keyframe-effect-effect-target) is not [being
 rendered](https://html.spec.whatwg.org/multipage/browsers.html#being-rendered).
 :::

 Tests

 - [commitStyles.html](https://wpt.fyi/results/web-animations/interfaces/Animation/commitStyles.html "web-animations/interfaces/Animation/commitStyles.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/commitStyles.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/commitStyles.html)

 :::
 In order to simplify the common case of persisting a completed
 animation, the procedure to [commit computed
 styles](#commit-computed-styles) uses endpoint-*inclusive* timing (see [§ 4.6.9.3
 Interval timing](#interval-timing)) when determining the phase of
 the animation (see [§ 4.6.6 Animation effect phases and
 states](#animation-effect-phases-and-states)).

 As a result, the following code will persist the
 `transform: translateY(100px)` style in specified style despite not
 having a [fill mode](#fill-mode) of
 [forwards](#fill-mode-forwards) or [both](#fill-mode-both).

 ``` highlight
 elem.animate({ transform: 'translateY(100px)' }, 200).finished.then(() => {
 elem.commitStyles();
 });
 ```
 :::

 :::
 Since the procedure to [commit computed
 styles](#commit-computed-styles) includes the [effect
 values](#effect-value) for
 the animation even if it is
 [removed](#removed-replace-state), this method is useful for retaining the effect of
 an animation after it has been replaced (see [§ 5.5.2 Removing
 replaced animations](#removing-replaced-animations)) without
 retaining the actual animation.

 Note that the values committed are the *computed* values produced by
 the [animation
 effects](#animation-effect) at the time when this method is called. Since these
 values are computed values, they do not reflect to changes to
 context such as responding to changes to CSS variables or
 recalculating
 [em](https://drafts.csswg.org/css-values-4/#em) units based on changes to the computed
 [font-size] in the way the values produced by a live animation
 would.

 In order to retain full fidelity of a filling animation's result
 after it has been replaced (see [§ 5.5 Replacing
 animations](#replacing-animations)), the
 [`persist()`](#dom-animation-persist) method can be used, but note that doing so will
 mean the animation continues to consume resources.
 :::

To [commit computed styles] for an
[animation](#concept-animation), `animation`:

1. Let `targets` be the
 [set](https://infra.spec.whatwg.org/#ordered-set) of all [effect
 targets](#keyframe-effect-effect-target) for [animation
 effects](#animation-effect)
 [associated](#animation-effect-associated-animation) with `animation`.

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `target` in `targets`:

 1. If `target` is not an element capable of having a
 [style
 attribute](https://drafts.csswg.org/css-style-attr/#style-attribute)
 [\[CSS-STYLE-ATTR\]](#biblio-css-style-attr "CSS Style Attributes")
 (for example, it is a
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) or is an element in a document format for which
 style attributes are not defined)
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`NoModificationAllowedError`](https://webidl.spec.whatwg.org/#nomodificationallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

 2. If, after applying any pending style changes,
 `target` is not [being
 rendered](https://html.spec.whatwg.org/multipage/browsers.html#being-rendered),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

 (#issue-8f3b970c) The definition of [being
 rendered](https://html.spec.whatwg.org/multipage/browsers.html#being-rendered)
 [\[HTML\]](#biblio-html "HTML Standard")
 with regards to [display:
 contents](https://drafts.csswg.org/css-display-4/#propdef-display) is still [under
 discussion](https://github.com/whatwg/html/issues/1837). For the
 purpose of this procedure, we assume that an element with
 [display: contents] that
 otherwise would have associated layout boxes (i.e. it is
 [connected](https://dom.spec.whatwg.org/#connected) and not part of a [display:
 none] subtree) *is* being
 rendered.

 3. Let `inline style` be the result of getting the [CSS
 declaration
 block](https://drafts.csswg.org/cssom-1/#css-declaration-block) corresponding to `target`'s [style
 attribute](https://drafts.csswg.org/css-style-attr/#style-attribute). If `target` does not
 [have](https://dom.spec.whatwg.org/#concept-element-attribute-has) a [style attribute],
 let `inline style` be a new empty [CSS declaration
 block] with the [owner
 node](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-owner-node) set to `target`.

 4. Let `targeted properties` be the
 [set](https://infra.spec.whatwg.org/#ordered-set) of physical longhand properties that are a
 [target property](#target-property) for at least one [animation
 effect](#animation-effect)
 [associated](#animation-effect-associated-animation) with `animation` whose [effect
 target](#keyframe-effect-effect-target) is `target`.

 5. For each property, `property`, in
 `targeted properties`:

 1. Let `partialEffectStack` be a copy of the [effect
 stack](#effect-stack) for `property` on
 `target`.

 2. If `animation`'s [replace
 state](#replace-state) is
 [removed](#removed-replace-state), add all [animation
 effects](#animation-effect)
 [associated](#animation-effect-associated-animation) with `animation` whose [effect
 target](#keyframe-effect-effect-target) is `target` and that include
 `property` as a [target
 property](#target-property) to `partialEffectStack`.

 3. Remove from `partialEffectStack` any [animation
 effects](#animation-effect) whose
 [associated](#animation-effect-associated-animation)
 [animation](#concept-animation) has a higher [composite
 order](#animation-composite-order) than `animation`.

 4. Let `effect value` be the result of calculating
 the result of `partialEffectStack` for
 `property` using `target`'s computed
 style (see [§ 5.4.3 Calculating the result of an effect
 stack](#calculating-the-result-of-an-effect-stack)) and
 setting the [endpoint-inclusive active
 interval](#endpoint-inclusive-active-interval) flag to true when calculating the animation
 effect phase (see [§ 4.6.6 Animation effect phases and
 states](#animation-effect-phases-and-states)).

 5. [Set a CSS
 declaration](https://drafts.csswg.org/cssom-1/#set-a-css-declaration) of `property` for
 `effect value` in `inline style`.

 6. [Update style attribute
 for](https://drafts.csswg.org/cssom-1/#update-style-attribute-for) `inline style`.

#### 6.4.1. The [`AnimationPlayState` enumeration]
```
enum AnimationPlayState { "idle", "running", "paused", "finished" };
```

[`idle`]

: Corresponds to the [idle play
 state](#play-state-idle).

[`running`]

: Corresponds to the [running play
 state](#play-state-running).

[`paused`]

: Corresponds to the [paused play
 state](#play-state-paused).

[`finished`]

: Corresponds to the [finished play
 state](#play-state-finished).

#### 6.4.2. The [`AnimationReplaceState` enumeration]
```
enum AnimationReplaceState { "active", "removed", "persisted" };
```

[`active`]

: Corresponds to the [active replace
 state](#active-replace-state).

[`removed`]

: Corresponds to the [removed replace
 state](#removed-replace-state).

[`persisted`]

: Corresponds to the [persisted replace
 state](#persisted-replace-state).

### 6.5. The [`AnimationEffect` interface]
[Animation effects](#animation-effect) are represented in the Web Animations API by the
abstract
[`AnimationEffect`](#animationeffect) interface.

```
[Exposed=Window]
interface AnimationEffect {
 EffectTiming getTiming();
 ComputedEffectTiming getComputedTiming();
 undefined updateTiming(optional OptionalEffectTiming timing = );
};
```

 In future, we may expose
`any onupdate (double? progress, double currentIteration, Animatable? target, any underlyingValue)`
so that the animation effects can be driven apart from the timing model.

[`getTiming()`]

: Returns the specified timing properties for this [animation
 effect](#animation-effect).

 For the correspondence between the members of the returned
 [`EffectTiming`](#dictdef-effecttiming) object and properties of the [timing
 model](#timing-model), see the
 [`EffectTiming`](#dictdef-effecttiming) interface.

[`getComputedTiming()`]

: Returns the calculated timing properties for this [animation
 effect](#animation-effect).

 Although some of the attributes of the object returned by
 [`getTiming()`](#dom-animationeffect-gettiming) and
 [`getComputedTiming()`](#dom-animationeffect-getcomputedtiming) are common, their values can differ in the
 following ways:

 - [`duration`](#dom-effecttiming-duration) -- while
 [`getTiming()`](#dom-animationeffect-gettiming) can return the string `auto`,
 [`getComputedTiming()`](#dom-animationeffect-getcomputedtiming) must return a number corresponding to the
 calculated value of the [iteration
 duration](#iteration-duration) as defined in the description of the
 [`duration`](#dom-effecttiming-duration) member of the
 [`EffectTiming`](#dictdef-effecttiming) interface.

 In this level of the specification, that simply means that an
 `auto` value is replaced by zero.

 - [`fill`](#dom-effecttiming-fill) -- likewise, while
 [`getTiming()`](#dom-animationeffect-gettiming) can return the string `auto`,
 [`getComputedTiming()`](#dom-animationeffect-getcomputedtiming) must return the specific
 [`FillMode`](#enumdef-fillmode) used for timing calculations as defined in the
 description of the
 [`fill`](#dom-effecttiming-fill) member of the
 [`EffectTiming`](#dictdef-effecttiming) interface.

 In this level of the specification, that simply means that an
 `auto` value is replaced by the `none`
 [`FillMode`](#enumdef-fillmode).

 It is likely that other timing members could be
 extended in future to include `auto`-like values. When performing
 timing calculations, authors are encouraged to use
 [`getComputedTiming()`](#dom-animationeffect-getcomputedtiming) where possible to avoid incompatibility should the
 range or type of allowed specified values be changed.

 In addition to possible differences in the values returned, compared
 to
 [`getTiming()`](#dom-animationeffect-gettiming),
 [`getComputedTiming()`](#dom-animationeffect-getcomputedtiming) returns additional timing information as defined by
 the
 [`ComputedEffectTiming`](#dictdef-computedeffecttiming) dictionary.

[`updateTiming(``timing``)`]

: Updates the specified timing properties of this [animation
 effect](#animation-effect) by performing the procedure to [update the timing
 properties of an animation
 effect](#update-the-timing-properties-of-an-animation-effect) passing the
 [`timing`](#dom-animationeffect-updatetiming-timing-timing) parameter as `input`.

 ::: parameters

 [`optional `[`OptionalEffectTiming`](#dictdef-optionaleffecttiming)` timing`]

 : The timing properties to update. The timing properties
 corresponding to any members that do not
 [exist](https://infra.spec.whatwg.org/#map-exists) on
 [`timing`](#dom-animationeffect-updatetiming-timing-timing) will *not* be modified.
 :::

 ::: exceptions

 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror)

 : Raised if any of the following conditions applies:

 - [`iterationStart`](#dom-effecttiming-iterationstart) is negative;

 - [`iterations`](#dom-effecttiming-iterations) is negative or `NaN`;

 - [`duration`](#dom-effecttiming-duration) is negative, `NaN`, or a string
 other than `auto`; or

 - [`easing`](#dom-effecttiming-easing) cannot be parsed as an
 [\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function).
 :::

The `remove()` method can be used to
remove an effect from either its parent group or animation. Should we
keep it in level 1 and define it simply as removing the animation effect
from its animation? [\[Issue
#2082\]](https://github.com/w3c/csswg-drafts/issues/2082)

#### 6.5.1. The [`EffectTiming` and [`OptionalEffectTiming`](#dictdef-optionaleffecttiming) dictionaries]
The [`EffectTiming`] dictionary represents the timing
properties of an
[`AnimationEffect`](#animationeffect).

The [`OptionalEffectTiming`] dictionary is a
variant of the
[`EffectTiming`](#dictdef-effecttiming) dictionary that allows some members to not
[exist](https://infra.spec.whatwg.org/#map-exists). This is used by the
[`updateTiming()`](#dom-animationeffect-updatetiming) method of the
[`AnimationEffect`](#animationeffect) interface to perform a delta update to the timing
properties of an [animation
effect](#animation-effect).

```
dictionary EffectTiming {
 double delay = 0;
 double endDelay = 0;
 FillMode fill = "auto";
 double iterationStart = 0.0;
 unrestricted double iterations = 1.0;
 (unrestricted double or DOMString) duration = "auto";
 PlaybackDirection direction = "normal";
 DOMString easing = "linear";
};

dictionary OptionalEffectTiming {
 double delay;
 double endDelay;
 FillMode fill;
 double iterationStart;
 unrestricted double iterations;
 (unrestricted double or DOMString) duration;
 PlaybackDirection direction;
 DOMString easing;
};
```

[`delay`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `0`

: The [start delay](#start-delay), which represents the number of milliseconds from
 the [start
 time](#animation-start-time) of the associated
 [animation](#concept-animation) to the start of the [active
 interval](#active-interval).

[`endDelay`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `0`

: The [end delay](#end-delay),
 which represents the number of milliseconds from the end of an
 [animation effect](#animation-effect)'s [active
 interval](#active-interval) until its [end
 time](#animation-effect-end-time).

[`fill`], of type [FillMode](#enumdef-fillmode), defaulting to `"auto"`

: The [fill mode](#fill-mode),
 which defines the behavior of the [animation
 effect](#animation-effect) outside its [active
 interval](#active-interval).

 When performing timing calculations the special string value `auto`
 is expanded to [none](#fill-mode-none).

 The `auto` value exists as a forwards-compatibility
 measure since future types of [animation
 effects](#animation-effect) are expected to produce a different computed [fill
 mode](#fill-mode).

 **As described in [§ 4.6.8 Fill behavior and fill
 modes](#fill-behavior), authors are discouraged from using
 indefinitely filling animations.**

[`iterationStart`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `0.0`

: The [animation
 effect](#animation-effect)'s [iteration
 start](#iteration-start)
 property, which is a finite real number greater than or equal to
 zero representing the [iteration
 index](#current-iteration-index) at which the [animation
 effect] begins and its progress through
 that iteration.

 For example, a value of 0.5 indicates that the animation effect
 begins halfway through its first iteration. A value of 1.2 indicates
 the animation effect begins 20% of the way through its second
 iteration.

 :::
 Note that the value of
 [`iterations`](#dom-effecttiming-iterations) is effectively *added* to the
 [`iterationStart`](#dom-effecttiming-iterationstart) such that an animation effect with an
 [`iterationStart`](#dom-effecttiming-iterationstart) of \"0.5\" and
 [`iterations`](#dom-effecttiming-iterations) of \"2\" will still repeat twice. However it will
 begin and end halfway through its [iteration
 interval](#iteration-interval).
 [`iterationStart`](#dom-effecttiming-iterationstart) values greater than or equal to 1 are typically
 only useful in combination with an animation effect that has an
 [iteration composite
 operation](https://drafts.csswg.org/web-animations-2/#iteration-composite-operation) of [accumulate] or when the [current
 iteration
 index](#current-iteration-index) is otherwise significant.
 :::

[`iterations`], of type [unrestricted double](https://webidl.spec.whatwg.org/#idl-unrestricted-double), defaulting to `1.0`

: The [animation
 effect](#animation-effect)'s [iteration
 count](#iteration-count)
 property which is a real number greater than or equal to zero
 (including positive infinity) representing the number of times to
 the animation effect repeats.

 This can be set to `+Infinity` to cause the [animation
 effect](#animation-effect) to repeat forever (unless the duration of the
 effect is zero, in which case it will finish immediately).

[`duration`], of type `(unrestricted double or DOMString)`, defaulting to `"auto"`

: The [iteration
 duration](#iteration-duration), which is a real number greater than or equal to
 zero (including positive infinity) representing the time taken to
 complete a single iteration of the [animation
 effect](#animation-effect).

 In this level of this specification, the string value `auto` is
 treated as the value zero for the purpose of timing model
 calculations and for the result of the
 [`duration`](#dom-effecttiming-duration) member returned from
 [`getComputedTiming()`](#dom-animationeffect-getcomputedtiming). If the author specifies the `auto` value, user
 agents must, however, return `auto` for the
 [`duration`](#dom-effecttiming-duration) member returned from
 [`getTiming()`](#dom-animationeffect-gettiming).

 This is a forwards-compatibility measure since a
 future level of this specification is expected to introduce group
 effects where the `auto` value expands to include the duration of
 the child effects.

[`direction`], of type [PlaybackDirection](#enumdef-playbackdirection), defaulting to `"normal"`

: The [playback
 direction](#playback-direction) of the [animation
 effect](#animation-effect), which defines whether playback proceeds forwards,
 backwards, or alternates on each iteration.

[`easing`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `"linear"`

: The [easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function) used to scale the time to produce easing effects.

 The syntax of the string is defined by the
 [\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function) production
 [\[CSS-EASING-1\]](#biblio-css-easing-1 "CSS Easing Functions Level 1").

#### 6.5.2. The [`FillMode` enumeration]
```
enum FillMode { "none", "forwards", "backwards", "both", "auto" };
```

Represents an [animation
effect](#animation-effect)'s [fill mode](#fill-mode).

[`none`]

: No fill. ([Fill mode](#fill-mode) [none](#fill-mode-none).)

[`forwards`]

: Fill [forwards](#fill-mode-forwards).

[`backwards`]

: Fill [backwards](#fill-mode-backwards).

[`both`]

: Fill [both](#fill-mode-both) backwards and forwards.

[`auto`]

: No fill. In a subsequent level of this specification, this may
 produce different behavior for other types of [animation
 effects](#animation-effect).

#### 6.5.3. The [`PlaybackDirection` enumeration]
```
enum PlaybackDirection { "normal", "reverse", "alternate", "alternate-reverse" };
```

[`normal`]

: All iterations are played as specified.

[`reverse`]

: All iterations are played in the reverse direction from the order
 they are specified.

[`alternate`]

: Even iterations are played as specified, odd iterations are played
 in the reverse direction from the order they are specified.

[`alternate-reverse`]

: Even iterations are played in the reverse direction from the order
 they are specified, odd iterations are played as specified.

#### 6.5.4. Updating the timing of an [`AnimationEffect`]
To [update the timing properties of an animation
effect], `effect`, from an
[`EffectTiming`](#dictdef-effecttiming) or
[`OptionalEffectTiming`](#dictdef-optionaleffecttiming) object, `input`, perform the following
steps:

1. If the
 [`iterationStart`](#dom-effecttiming-iterationstart) member of `input`
 [exists](https://infra.spec.whatwg.org/#map-exists) and is less than zero,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort this procedure.

 The reason for using a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) rather than a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) is to mirror the behavior of WebIDL's
 [\[EnforceRange\]](https://webidl.spec.whatwg.org/#EnforceRange) annotation should that annotation be able to be
 used with floating-point values in the future.

2. If the
 [`iterations`](#dom-effecttiming-iterations) member of `input`
 [exists](https://infra.spec.whatwg.org/#map-exists), and is less than zero or is the value
 `NaN`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort this procedure.

3. If the
 [`duration`](#dom-effecttiming-duration) member of `input`
 [exists](https://infra.spec.whatwg.org/#map-exists), and is less than zero, is the value
 `NaN`, or is a string other than the lowercase `auto`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort this procedure.

4. If the
 [`easing`](#dom-effecttiming-easing) member of `input`
 [exists](https://infra.spec.whatwg.org/#map-exists) but cannot be parsed using the
 [\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function) production
 [\[CSS-EASING-1\]](#biblio-css-easing-1 "CSS Easing Functions Level 1"),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort this procedure.

5. Assign each member that
 [exists](https://infra.spec.whatwg.org/#map-exists) in `input` to the corresponding timing
 property of `effect` as follows:

 - [`delay`](#dom-effecttiming-delay) → [start
 delay](#start-delay)

 - [`endDelay`](#dom-effecttiming-enddelay) → [end delay](#end-delay)

 - [`fill`](#dom-effecttiming-fill) → [fill mode](#fill-mode)

 - [`iterationStart`](#dom-effecttiming-iterationstart) → [iteration
 start](#iteration-start)

 - [`iterations`](#dom-effecttiming-iterations) → [iteration
 count](#iteration-count)

 - [`duration`](#dom-effecttiming-duration) → [iteration
 duration](#iteration-duration)

 - [`direction`](#dom-effecttiming-direction) → [playback
 direction](#playback-direction)

 - [`easing`](#dom-effecttiming-easing) → [easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function)

6. If `effect` is [associated with an
 animation](#animation-effect-associated-animation), run the procedure to [update an animation's
 finished
 state](#update-an-animations-finished-state) for its [associated
 animation] with
 the `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

#### 6.5.5. The `ComputedEffectTiming` dictionary

Timing properties calculated by the timing model are exposed using
[`ComputedEffectTiming`](#dictdef-computedeffecttiming) dictionary objects.

```
dictionary ComputedEffectTiming : EffectTiming {
 unrestricted double endTime;
 unrestricted double activeDuration;
 double? localTime;
 double? progress;
 unrestricted double? currentIteration;
};
```

[`endTime`], of type [unrestricted double](https://webidl.spec.whatwg.org/#idl-unrestricted-double)

: The [end
 time](#animation-effect-end-time) of the [animation
 effect](#animation-effect) expressed in milliseconds since zero [local
 time](#local-time) (that is,
 since the associated
 [animation](#concept-animation)'s [start
 time](#animation-start-time) if this [animation
 effect] is [associated with an
 animation](#animation-effect-associated-animation)). This corresponds to the end of the [animation
 effect]'s [active
 interval](#active-interval) plus any [end
 delay](#end-delay).

[`activeDuration`], of type [unrestricted double](https://webidl.spec.whatwg.org/#idl-unrestricted-double)

: The [active duration](#active-duration) of this [animation
 effect](#animation-effect).

[`localTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), nullable

: The [local time](#local-time)
 of this [animation
 effect](#animation-effect).

 This will be `null` if this [animation
 effect](#animation-effect) is not [associated with an
 animation](#animation-effect-associated-animation).

[`progress`], of type [double](https://webidl.spec.whatwg.org/#idl-double), nullable

: The current [iteration
 progress](#iteration-progress) of this [animation
 effect](#animation-effect).

[`currentIteration`], of type [unrestricted double](https://webidl.spec.whatwg.org/#idl-unrestricted-double), nullable

: The [current iteration
 index](#current-iteration-index) beginning with zero for the first iteration.

 In most cases this will be a (positive) integer. However, for a
 zero-duration animation that repeats infinite times, the value will
 be positive `Infinity`.

 As with [unresolved](#unresolved) times, an unresolved [iteration
 index](#current-iteration-index) is represented by a `null` value.

### 6.6. The [`KeyframeEffect` interface]
[Keyframe effects](#keyframe-effect) are represented by the
[`KeyframeEffect`] interface.

```
[Exposed=Window]
interface KeyframeEffect : AnimationEffect {
 constructor(Element? target,
 object? keyframes,
 optional (unrestricted double or KeyframeEffectOptions) options = );
 constructor(KeyframeEffect source);
 attribute Element? target;
 attribute CSSOMString? pseudoElement;
 attribute CompositeOperation composite;
 sequence<object> getKeyframes();
 undefined setKeyframes(object? keyframes);
};
```

Tests

- [effect-in-removed-iframe-crash.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-in-removed-iframe-crash.html "web-animations/animation-model/keyframe-effects/effect-in-removed-iframe-crash.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-in-removed-iframe-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-in-removed-iframe-crash.html)

[` KeyframeEffect (``target``, ``keyframes``, ``options``)`]

: Creates a new
 [`KeyframeEffect`](#keyframeeffect) object using the following procedure:

 1. Create a new
 [`KeyframeEffect`](#keyframeeffect) object, `effect`.

 2. Set the [target
 element](#effect-target-target-element) of `effect` to `target`.

 3. Set the [target
 pseudo-selector](#effect-target-target-pseudo-selector) to the result corresponding to the first
 matching condition below:

 If `options` is a [`KeyframeEffectOptions`](#dictdef-keyframeeffectoptions) object with a [`pseudoElement`](#dom-keyframeeffectoptions-pseudoelement) property,

 : Set the [target
 pseudo-selector](#effect-target-target-pseudo-selector) to the value of the
 [`pseudoElement`](#dom-keyframeeffectoptions-pseudoelement) property.

 When assigning this property, the error-handling defined for
 the
 [`pseudoElement`](#dom-keyframeeffect-pseudoelement) setter on the interface is applied. If the
 setter requires an exception to be thrown, this procedure
 must throw the same exception and abort all further steps.

 Otherwise,

 : Set the [target
 pseudo-selector](#effect-target-target-pseudo-selector) to `null`.

 4. Let `timing input` be the result corresponding to the
 first matching condition below:

 If `options` is a [`KeyframeEffectOptions`](#dictdef-keyframeeffectoptions) object,

 : Let `timing input` be `options`.

 Otherwise (if `options` is a `double`),

 : Let `timing input` be a new
 [`EffectTiming`](#dictdef-effecttiming) object with all members set to their
 default values and
 [`duration`](#dom-effecttiming-duration) set to `options`.

 5. Call the procedure to [update the timing properties of an
 animation
 effect](#update-the-timing-properties-of-an-animation-effect) of `effect` from
 `timing input`.

 If that procedure causes an exception to be thrown, propagate
 the exception and abort this procedure.

 6. If `options` is a
 [`KeyframeEffectOptions`](#dictdef-keyframeeffectoptions) object, assign the
 [`composite`](#dom-keyframeeffect-composite) property of `effect` to the
 corresponding value from `options`.

 When assigning this property, the error-handling defined for the
 corresponding setter on the
 [`KeyframeEffect`](#keyframeeffect) interface is applied. If the setter requires an
 exception to be thrown for the value specified by
 `options`, this procedure must
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) the same exception and abort all further steps.

 7. Initialize the set of [keyframes](#keyframe) by performing the procedure defined for
 [`setKeyframes()`](#dom-keyframeeffect-setkeyframes) passing `keyframes` as the input.

 ::: parameters

 [[`Element`](https://dom.spec.whatwg.org/#element)`? target`]

 : The [target
 element](#effect-target-target-element). This may be `null` for animations that do not
 target a specific element.

 [`object? keyframes`]

 : The set of [keyframes](#keyframe) to use. The format and processing of this
 argument is defined in [§ 6.6.3 Processing a keyframes
 argument](#processing-a-keyframes-argument).

 [`optional `[`KeyframeEffectOptions`](#dictdef-keyframeeffectoptions)` options`]

 : Either a number specifying the [iteration
 duration](#iteration-duration) of the effect, or a collection of properties
 specifying the timing and behavior of the effect.

 Examples of the usage of this constructor are given in [§ 6.6.1
 Creating a new KeyframeEffect
 object](#creating-a-new-keyframeeffect-object).
 :::

[`KeyframeEffect (source)`]

: Creates a new
 [`KeyframeEffect`](#keyframeeffect) object with the same properties as
 [`source`](#dom-keyframeeffect-keyframeeffect-source-source) using the following procedure:

 1. Create a new
 [`KeyframeEffect`](#keyframeeffect) object, `effect`.

 2. Set the following properties of `effect` using the
 corresponding values of `source`:

 - [effect
 target](#keyframe-effect-effect-target),

 - [keyframes](#keyframe),

 - [composite
 operation](#composite-operation), and

 - all specified timing properties:

 - [start delay](#start-delay),

 - [end delay](#end-delay),

 - [fill mode](#fill-mode),

 - [iteration
 start](#iteration-start),

 - [iteration
 count](#iteration-count),

 - [iteration
 duration](#iteration-duration),

 - [playback
 direction](#playback-direction), and

 - [easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function).

 Unlike the
 [`KeyframeEffect(target, keyframes, options)`](#dom-keyframeeffect-keyframeeffect) constructor, we do not need to re-throw
 exceptions since the timing properties specified on
 `source` can be assumed to be valid.

 ::: parameters

 [[`KeyframeEffect`](#keyframeeffect)` source`]

 : The [keyframe
 effect](#keyframe-effect) from which to copy the properties that define
 the new [keyframe effect].
 :::

[`target`], of type [Element](https://dom.spec.whatwg.org/#element), nullable

: The [target
 element](#effect-target-target-element) being animated by this object (either the [effect
 target](#keyframe-effect-effect-target) if it is an
 [`Element`](https://dom.spec.whatwg.org/#element) or its [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element) if it is a pseudo-element). This may be `null` for
 animations that do not target a specific element such as an
 animation that produces a sound using an audio API.

[`pseudoElement`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring), nullable

: The [target
 pseudo-selector](#effect-target-target-pseudo-selector). `null` if this effect has no [effect
 target](#keyframe-effect-effect-target) or if the [effect
 target] is an element
 (i.e. not a pseudo-element). When the [effect
 target] is a
 pseudo-element, this specifies the pseudo-element selector (e.g.
 `::before`).

 On setting, sets the [target
 pseudo-selector](#effect-target-target-pseudo-selector) of the [animation
 effect](#animation-effect) to the result of
 [`pseudo-element parsing`] on the provided value, defined as
 the following:

 1. Given the value `value`, perform the following steps:

 2. If `value` is not `null` and is an
 [invalid](https://drafts.csswg.org/selectors-4/#invalid-selector)
 [\<pseudo-element-selector\>](https://drafts.csswg.org/selectors-4/#typedef-pseudo-element-selector),

 1. [Throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) with error name
 \"[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)\".

 2. Abort.

 In effect, this means that if the result of
 this algorithm is used to set a variable, then that variable
 remains unchanged.

 Invalid in this context follows the definition
 of an [invalid
 selector](https://drafts.csswg.org/selectors-4/#invalid-selector) defined in
 [\[SELECTORS-4\]](#biblio-selectors-4 "Selectors Level 4")
 such that syntactically invalid pseudo-elements as well as
 pseudo-elements for which the user agent has no usable level of
 support are both deemed invalid.

 3. If `value` is one of the legacy Selectors Level 2
 single-colon selectors (\':before\', \':after\',
 \':first-letter\', or \':first-line\'), then return the
 equivalent two-colon selector (e.g. \'::before\').

 4. Otherwise, return `value`.

[`composite`], of type [CompositeOperation](#enumdef-compositeoperation)

: The [composite
 operation](#composite-operation) used to composite this [keyframe
 effect](#keyframe-effect) with the [effect
 stack](#effect-stack), as
 specified by one of the
 [`CompositeOperation`](#enumdef-compositeoperation) enumeration values.

 On setting, sets the [composite
 operation](#composite-operation) property of this [animation
 effect](#animation-effect) to the provided value.

[`sequence<object> getKeyframes()`]

: Returns the keyframes that make up this effect along with their
 [computed keyframe
 offsets](#computed-keyframe-offsets).

 ::: informative-bg
 *This section is non-normative*
 The result of this method is a sequence of objects of the following
 format:

 ``` highlight
 dictionary ComputedKeyframe {
 // ... property-value pairs ...
 // i.e. DOMString propertyName
 double? offset = null;
 double computedOffset;
 DOMString easing = "linear";
 CompositeOperationOrAuto composite = "auto";
 };
 ```

 The meaning and values of each member is as follows:

 `offset`

 : The [keyframe
 offset](#keyframe-offset) of the
 [keyframe](#keyframe)
 specified as a number between 0.0 and 1.0 inclusive, or `null`.

 This will be `null` if the
 [keyframe](#keyframe) is to
 be automatically spaced between adjacent keyframes.

 `computedOffset`

 : The [computed keyframe
 offset](#computed-keyframe-offsets) for this
 [keyframe](#keyframe)
 calculated as part of running the [compute missing keyframe
 offsets](#compute-missing-keyframe-offsets) procedure.

 Unlike the `offset` member, the `computedOffset` is never
 `null`.

 `easing`

 : The [easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function) used to transform the progress of time from
 this keyframe until the next keyframe in the series.

 `composite`

 : The [keyframe-specific composite
 operation](#keyframe-specific-composite-operation) used to combine the values specified in this
 keyframe with the [underlying
 value](#underlying-value).

 This member will be
 [`auto`](#dom-compositeoperationorauto-auto) if the [composite
 operation](#composite-operation) specified on the [keyframe
 effect](#keyframe-effect) is being used.
 :::

 Since [keyframes](#keyframe)
 are represented by a partially open-ended dictionary type that is
 not currently able to be expressed with WebIDL, the procedure used
 to prepare the result of this method is defined in prose below:

 1. Let `result` be an empty sequence of objects.

 2. Let `keyframes` be one of the following:

 If this [keyframe effect](#keyframe-effect) is associated with a [`CSSAnimation`](https://drafts.csswg.org/css-animations-2/#cssanimation), and its [keyframes](#keyframe) have not been replaced by a successful call to [`setKeyframes()`](#dom-keyframeeffect-setkeyframes),

 : the [computed
 keyframes](#computed-keyframes) for this [keyframe
 effect](#keyframe-effect).

 Otherwise,

 : the result of applying the procedure [compute missing
 keyframe
 offsets](#compute-missing-keyframe-offsets) to the
 [keyframes](#keyframe)
 for this [keyframe
 effect](#keyframe-effect).

 We return [computed
 keyframes](#computed-keyframes) for CSS Animations because not all keyframes
 specified in CSS can be represented by a dictionary.

 3. For each `keyframe` in `keyframes` perform
 the following steps:

 1. Initialize a dictionary object,
 `output keyframe`, using the following
 definition:

 ```
 dictionary BaseComputedKeyframe {
 double? offset = null;
 double computedOffset;
 DOMString easing = "linear";
 CompositeOperationOrAuto composite = "auto";
 };
 ```

 2. Set the
 [`offset`](#dom-basecomputedkeyframe-offset),
 [`computedOffset`](#dom-basecomputedkeyframe-computedoffset),
 [`easing`](#dom-basecomputedkeyframe-easing), and
 [`composite`](#dom-basecomputedkeyframe-composite) members of `output keyframe` to
 the respective [keyframe
 offset](#keyframe-offset), [computed keyframe
 offset](#computed-keyframe-offsets), keyframe-specific [easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function), and [keyframe-specific composite
 operation](#keyframe-specific-composite-operation) values of `keyframe`.

 3. For each animation property-value pair
 `declaration` in `keyframe`, perform
 the following steps:

 1. Let `property name` be the result of applying
 the [animation property name to IDL attribute
 name](#animation-property-name-to-idl-attribute-name) algorithm to the property name of
 `declaration`.

 2. Let `IDL value` be the result of serializing
 the property value of `declaration` by
 passing `declaration` to the algorithm to
 [serialize a CSS
 value](https://drafts.csswg.org/cssom/#serialize-a-css-value)
 [\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)").

 3. Let `value` be the result of
 [converting](https://webidl.spec.whatwg.org/#DOMString-to-es) `IDL value` to an ECMAScript
 String value.

 4. Call the
 [\[\[DefineOwnProperty\]\]](http://www.ecma-international.org/ecma-262/6.0/#sec-ordinary-object-internal-methods-and-internal-slots-defineownproperty-p-desc) internal method on
 `output keyframe` with property name
 `property name`, Property Descriptor {
 \[\[Writable\]\]: [true], \[\[Enumerable\]\]:
 [true], \[\[Configurable\]\]:
 [true], \[\[Value\]\]: `value` }
 and Boolean flag [false].

 4. Append `output keyframe` to `result`.

 4. Return `result`.

[`void setKeyframes(object? keyframes)`]

: Replaces the set of [keyframes](#keyframe) that make up this effect.

 :::

 [`object? keyframes`]

 : A series of keyframes whose format and processing is defined by
 [§ 6.6.3 Processing a keyframes
 argument](#processing-a-keyframes-argument).

 This effect's set of [keyframes](#keyframe) is replaced with the result of performing the
 procedure to [process a keyframes
 argument](#process-a-keyframes-argument). If that procedure throws an exception, this
 effect's [keyframes] are not modified.
 :::

 ::: exceptions

 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror)

 : Raised if an iterable yields a value other than `undefined`,
 `null`, or an object; if the keyframes are not [loosely sorted
 by
 offset](#loosely-sorted-by-offset); if a non-null [keyframe
 offset](#keyframe-offset) is outside the range \[0, 1\]; or if an easing
 cannot be parsed as an
 [\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function).
 :::

#### 6.6.1. Creating a new `KeyframeEffect` object

:::::::: informative-bg
*This section is non-normative*

The
[`KeyframeEffect`](#dom-keyframeeffect-keyframeeffect) constructor offers a number of approaches to creating
new [`KeyframeEffect`](#keyframeeffect) objects.

At its simplest, a
[`KeyframeEffect`](#keyframeeffect) object that changes the \"left\" property of `elem` to
100px over three seconds can be constructed as follows:

``` highlight
var effect = new KeyframeEffect(elem, { left: '100px' }, 3000);
```

The second parameter, representing the list of keyframes, may specify
multiple properties. (See [§ 6.6.3 Processing a keyframes
argument](#processing-a-keyframes-argument).)

``` highlight
// Specify multiple properties at once
var effectA = new KeyframeEffect(elem, { left: '100px', top: '300px' }, 3000);

// Specify multiple keyframes
var effectB = new KeyframeEffect(elem, [ { left: '100px' }, { left: '300px' } ], 3000);
```

The third parameter, representing the animation's timing, may simply be
a number representing the [iteration
duration](#iteration-duration) in milliseconds as above, or, to specify further timing
properties such as the [start
delay](#start-delay), an
[`EffectTiming`](#dictdef-effecttiming) object can be used, as follows:

``` highlight
var effect =
 new KeyframeEffect(elem, { left: '100px' }, { duration: 3000, delay: 2000 });
```

If the duration is not specified, a value of zero is used. It is
possible to create an animation that simply sets a property without any
interpolation as follows:

``` highlight
var effect =
 new KeyframeEffect(elem, { visibility: 'hidden' }, { fill: 'forwards' });
```

As described in [§ 4.6.8 Fill behavior and fill modes](#fill-behavior)
however, using indefinitely filling animations in this way is
discouraged.

Having created a
[`KeyframeEffect`](#keyframeeffect), it can be played by adding it to an
[`Animation`](#animation) and
then playing that animation. For simple effects, however, the
[`Element.animate`](#extensions-to-the-element-interface) shortcut is
more convenient since it performs these steps automatically. For
example,

``` highlight
elem.animate({ left: '100px' }, 3000);
```

#### 6.6.2. Property names and IDL names

The [animation property name to IDL attribute
name] algorithm for `property` is as
follows:

1. If `property` follows the
 [\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name) production, return
 `property`.

2. If `property` refers to the CSS
 [float](https://drafts.csswg.org/css2/#propdef-float) property, return the string
 \"cssFloat\".

3. If `property` refers to the CSS
 [offset](https://drafts.csswg.org/motion-1/#propdef-offset) property, return the string
 \"cssOffset\".

4. Otherwise, return the result of applying the [CSS property to IDL
 attribute](https://drafts.csswg.org/cssom/#css-property-to-idl-attribute) algorithm
 [\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
 to `property`.

The [IDL attribute name to animation property
name] algorithm for `attribute` is as
follows:

1. If `attribute` conforms to the
 [\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name) production, return
 `attribute`.

2. If `attribute` is the string \"cssFloat\", then return an
 animation property representing the CSS
 [float](https://drafts.csswg.org/css2/#propdef-float) property.

3. If `attribute` is the string \"cssOffset\", then return
 an animation property representing the CSS
 [offset](https://drafts.csswg.org/motion-1/#propdef-offset) property.

4. Otherwise, return the result of applying the [IDL attribute to CSS
 property](https://drafts.csswg.org/cssom/#idl-attribute-to-css-property) algorithm
 [\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
 to `attribute`.

#### 6.6.3. Processing a `keyframes` argument

::::::: informative-bg
*This section is non-normative*

The following methods all accept a set of keyframes as an argument:

- the
 [`KeyframeEffect(target, keyframes, options)`](#dom-keyframeeffect-keyframeeffect) constructor,

- the
 [`setKeyframes()`](#dom-keyframeeffect-setkeyframes) method on the
 [`KeyframeEffect`](#keyframeeffect) interface,

- the
 [`animate()`](#dom-animatable-animate) method of the
 [`Animatable`](#animatable)
 interface mixin.

This argument can be specified in the one of two forms as illustrated
below:

``` highlight
// The following two expressions produce the same result:
elem.animate([ { color: 'blue' },
 { color: 'green' },
 { color: 'red' },
 { color: 'yellow' } ], 2000);
elem.animate({ color: [ 'blue', 'green', 'red', 'yellow' ] }, 2000);

// Likewise, for a multi-property animation, the following two
// expressions are equivalent:
elem.animate([ { color: 'blue', left: '0px' },
 { color: 'green', left: '-20px' },
 { color: 'red', left: '100px' },
 { color: 'yellow', left: '50px'} ], 2000);
elem.animate({ color: [ 'blue', 'green', 'red', 'yellow' ],
 left: [ '0px', '-20px', '100px', '50px' ] }, 2000);

// Incidentally, the following three expressions are all equivalent:
elem.animate([ { color: 'red' } ], 1000);
elem.animate({ color: [ 'red' ] }, 1000);
elem.animate({ color: 'red' }, 1000);
```

The first form (the array-form) consists of an array of keyframes where
each keyframe may specify at most one value per animation property. The
second form (the object-form) consists of an object where each animation
property may specify a single animation value or an array of animation
values.

The first array-form is the canonical form, and is the form returned by
the
[`getKeyframes()`](#dom-keyframeeffect-getkeyframes) method.

[Keyframe offsets](#keyframe-offset) can be specified using either form as illustrated
below:

``` highlight
// The keyframes without offsets will automatically have offsets computed
// as 0 for the first keyframe, 0.65 for the middle keyframe, and 1 for the
// final keyframe.
elem.animate([ { color: 'blue' },
 { color: 'green', offset: 0.5 },
 { color: 'red' },
 { color: 'yellow', offset: 0.8 },
 { color: 'pink' } ], 2000);

// The following produces the same result. Note that it is not necessary to
// specify the last value: it will automatically be treated as 'null' and then
// the automatic assignment will apply as with the previous case.
elem.animate({ color: [ 'blue', 'green', 'red', 'yellow', 'pink' ],
 offset: [ null, 0.5, null, 0.8 ] }, 2000);
```

Likewise [easing
functions](https://drafts.csswg.org/css-easing-2/#easing-function) and [keyframe-specific composite
operations](#keyframe-specific-composite-operation) may be specified in either form. The array-form allows
specifying different values for each
[keyframe](#keyframe) whilst for
the object-form, the list of values will be repeated as needed until
each keyframe has been assigned a value.

``` highlight
// Since easing functions apply _between_ keyframes, even if we specify a
// an easing function on the last keyframe it will be ignored.
elem.animate([ { color: 'blue', easing: 'ease-in' },
 { color: 'green', easing: 'ease-out' },
 { color: 'yellow' } ], 2000);

// The following produces the same result.
elem.animate({ color: [ 'blue', 'green', 'yellow' ],
 easing: [ 'ease-in', 'ease-out' ] }, 2000);

// The repeating behavior makes assigning the same value to all keyframes
// simple:
elem.animate({ color: [ 'blue', 'green', 'yellow' ],
 easing: 'ease-in-out' }, 2000);
```

Note that the `easing` property in either form sets the
*keyframe-specific [easing
function](https://drafts.csswg.org/css-easing-2/#easing-function)*. This is independent from the [easing
function](https://drafts.csswg.org/css-easing-2/#easing-function) that applies to the entire [iteration
duration](#iteration-duration) of the [keyframe
effect](#keyframe-effect) as
specified using a
[`KeyframeEffectOptions`](#dictdef-keyframeeffectoptions) object (or
[`KeyframeAnimationOptions`](#dictdef-keyframeanimationoptions) object when using the
[`animate()`](#dom-animatable-animate) method of the
[`Animatable`](#animatable)
interface mixin).

In the following example, the two statements produce different results.

``` highlight
// Here, 'ease-in-out' is applied between each color value.
elem.animate({ color: [ 'blue', 'green', 'yellow' ],
 easing: 'ease-in-out' }, 2000);

// However, in this case, 'ease-in-out' is applied across the whole span
// of the animation, that is from 'blue' to 'yellow'.
elem.animate({ color: [ 'blue', 'green', 'yellow' ] },
 { duration: 2000, easing: 'ease-in-out' });
```

The type of the `keyframes` argument cannot be expressed in WebIDL since
it relies on a partially-open dictionary type.

Conceptually, the type of this argument is equivalent to the following
WebIDL-like definition:

``` highlight
dictionary Keyframe {
 // ... property-value pairs ...
 // i.e. DOMString propertyName
 double? offset = null;
 DOMString easing = "linear";
 CompositeOperationOrAuto composite = "auto";
};

dictionary PropertyIndexedKeyframes {
 // ... property-value and property-valuelist pairs ...
 // i.e. (DOMString or sequence<DOMString>) propertyName
 (double? or sequence<double?>) offset = ;
 (DOMString or sequence<DOMString>) easing = ;
 (CompositeOperationOrAuto or sequence<CompositeOperationOrAuto>) composite = ;
};

typedef (sequence<Keyframe?> or PropertyIndexedKeyframes) KeyframeArgument;
```

The meaning and allowed values of each argument is as follows:

`offset`

: The [keyframe offset](#keyframe-offset) of the [keyframe](#keyframe) specified as a number between 0.0 and 1.0 inclusive
 or `null`.

 A `null` value indicates that the
 [keyframe](#keyframe) should be
 automatically spaced between adjacent keyframes.

 Specifying an offset outside the range \[0.0, 1.0\] will cause a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) to be thrown.

 Keyframes that specify an offset must be provided in increasing
 order of offset. Adjacent and equal offsets, however, are permitted.

`easing`

: The [easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function) used to transform the progress of time from this
 keyframe until the next keyframe in the series.

 The syntax and error-handling associated with parsing this string is
 identical to that defined for the
 [`easing`](#dom-effecttiming-easing) attribute of the
 [`EffectTiming`](#dictdef-effecttiming) interface.

`composite`

: The [keyframe-specific composite
 operation](#keyframe-specific-composite-operation) used to combine the values specified in this
 keyframe with the [underlying
 value](#underlying-value).

 If
 [`auto`](#dom-compositeoperationorauto-auto), the [composite
 operation](#composite-operation) specified on the [keyframe
 effect](#keyframe-effect) will be used.

Since this type cannot be expressed in WebIDL, its processing is defined
in prose following.

For each method that takes a `keyframes` argument, the procedure to
[process a keyframes
argument](#process-a-keyframes-argument) is run on the input and the result of that procedure is
retained.

Tests

- [keyframe-exceptions.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/keyframe-exceptions.html "web-animations/animation-model/keyframe-effects/keyframe-exceptions.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/keyframe-exceptions.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/keyframe-exceptions.html)

First we define two supporting definitions:

The instruction [check the completion
record] of `result`, where `result` is a
[completion
record](http://www.ecma-international.org/ecma-262/6.0/#sec-completion-record-specification-type) from calling an ECMAScript operation, is equivalent to
the following steps:

1. If `result` is an [abrupt
 completion](http://www.ecma-international.org/ecma-262/6.0/#sec-completion-record-specification-type),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) the exception contained in the \[\[value\]\] field
 of `result` and abort the procedure.

 (#issue-47a68024) What should we do if the
 \[\[type\]\] is [break], [continue], or
 [return]? Can it be?

2. Replace `result` with the value contained in the
 \[\[value\]\] field of `result`.

The procedure to [process a keyframe-like
object] takes two arguments:

- an ECMAScript object, `null`, or `undefined`,
 `keyframe input`, and

- an `allow lists` boolean flag

and returns a map from either property names to DOMString values if
`allow lists` is false, or from property names to sequences
of DOMString values otherwise, using the following procedure:

1. Run the procedure to [convert an ECMAScript value to a dictionary
 type](https://webidl.spec.whatwg.org/#es-to-dictionary)
 [\[WEBIDL\]](#biblio-webidl "Web IDL Standard")
 with `keyframe input` as the ECMAScript value, and the
 dictionary type depending on the value of the
 `allow lists` flag as follows:

 ::: switch

 If `allow lists` is true,

 : Use the following dictionary type:

 ```
 dictionary BasePropertyIndexedKeyframe {
 (double? or sequence<double?>) offset = ;
 (DOMString or sequence<DOMString>) easing = ;
 (CompositeOperationOrAuto or sequence<CompositeOperationOrAuto>) composite = ;
 };
 ```

 Otherwise,

 : Use the following dictionary type:

 ```
 dictionary BaseKeyframe {
 double? offset = null;
 DOMString easing = "linear";
 CompositeOperationOrAuto composite = "auto";
 };
 ```
 :::

 Store the result of this procedure as `keyframe output`.

2. If `keyframe input` is `null` or `undefined`, return
 `keyframe output`.

3. Build up a list of `animatable properties` as follows:

 1. Let `animatable properties` be a list of property
 names (including shorthand properties that have longhand
 sub-properties that are animatable) that can be animated by the
 UA.

 2. Convert each property name in `animatable properties`
 to the equivalent IDL attribute by applying the [animation
 property name to IDL attribute
 name](#animation-property-name-to-idl-attribute-name) algorithm.

4. Let `input properties` be the result of calling the
 [EnumerableOwnNames](http://www.ecma-international.org/ecma-262/6.0/#sec-enumerableownnames) operation with `keyframe input` as the
 object.

5. Make up a new list `animation properties` that consists
 of all of the properties that are in *both*
 `input properties` and
 `animatable properties`, *or* which are in
 `input properties` and conform to the
 [\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name) production.

6. Sort `animation properties` in ascending order by the
 Unicode codepoints that define each property name.

7. For each `property name` in
 `animation properties`:

 1. Let `raw value` be the result of calling the
 [\[\[Get\]\]](http://www.ecma-international.org/ecma-262/6.0/#sec-ordinary-object-internal-methods-and-internal-slots-get-p-receiver) internal method on `keyframe input`,
 with `property name` as the property key and
 `keyframe input` as the receiver.

 2. [Check the completion
 record](#check-the-completion-record) of `raw value`.

 3. Convert `raw value` to a DOMString or to a sequence
 of DOMStrings `property values` as follows:

 ::: switch

 If `allow lists` is true,

 : Let `property values` be the result of converting
 `raw value` to IDL type
 `(DOMString or sequence<DOMString>)` using the [procedures
 defined for converting an ECMAScript value to an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value)
 [\[WEBIDL\]](#biblio-webidl "Web IDL Standard").

 If `property values` is a single DOMString,
 replace `property values` with a sequence of
 DOMStrings with the original value of
 `property values` as the only element.

 Otherwise,

 : Let `property values` be the result of converting
 `raw value` to a DOMString using the [procedure
 for converting an ECMAScript value to a
 DOMString](https://webidl.spec.whatwg.org/#es-to-DOMString)
 [\[WEBIDL\]](#biblio-webidl "Web IDL Standard").
 :::

 4. Calculate the `normalized property name` as the
 result of applying the [IDL attribute name to animation property
 name](#idl-attribute-name-to-animation-property-name) algorithm to `property name`.

 5. Add a property to `keyframe output` with
 `normalized property name` as the property name, and
 `property values` as the property value.

8. Return `keyframe output`.

The procedure to [process a keyframes
argument] takes a
[nullable](https://webidl.spec.whatwg.org/#dfn-nullable-type) ECMAScript object, `object`, as input, and
returns a sequence of keyframes using the following procedure:

1. If `object` is `null`, return an empty sequence of
 keyframes.

2. Let `processed keyframes` be an empty sequence of
 [keyframes](#keyframe).

3. Let `method` be the result of
 [GetMethod](http://www.ecma-international.org/ecma-262/6.0/#sec-getmethod)(`object`,
 [@@iterator](http://www.ecma-international.org/ecma-262/6.0/#sec-well-known-symbols)).

4. [Check the completion
 record](#check-the-completion-record) of `method`.

5. Perform the steps corresponding to the first matching condition
 below:

 ::: switch

 If `method` is not [undefined],

 : 1. Let `iter` be
 [GetIterator](http://www.ecma-international.org/ecma-262/6.0/#sec-getiterator)(`object`, `method`).

 2. [Check the completion
 record](#check-the-completion-record) of `iter`.

 3. Repeat:

 1. Let `next` be
 [IteratorStep](http://www.ecma-international.org/ecma-262/6.0/#sec-iteratorstep)(`iter`).

 2. [Check the completion
 record](#check-the-completion-record) of `next`.

 3. If `next` is false abort this loop.

 4. Let `nextItem` be
 [IteratorValue](http://www.ecma-international.org/ecma-262/6.0/#sec-iteratorvalue)(next).

 5. [Check the completion
 record](#check-the-completion-record) of `nextItem`.

 6. If
 [Type](http://www.ecma-international.org/ecma-262/6.0/#sec-ecmascript-data-types-and-values)(`nextItem`) is not
 `Undefined`, `Null` or `Object`, then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort these steps.

 7. Append to `processed keyframes` the result of
 running the procedure to [process a keyframe-like
 object](#process-a-keyframe-like-object) passing `nextItem` as the
 `keyframe input` with the
 `allow lists` flag set to false.

 Otherwise,

 : 1. Let `property-indexed keyframe` be the result of
 running the procedure to [process a keyframe-like
 object](#process-a-keyframe-like-object) passing `object` as the
 `keyframe input` with the
 `allow lists` flag set to true.

 2. For each member, `m`, in
 `property-indexed keyframe`, perform the
 following steps:

 1. Let `property name` be the key for
 `m`.

 2. If `property name` is \"composite\",
 \"easing\", or \"offset\", skip the remaining steps in
 this loop and continue from the next member in
 `property-indexed keyframe` after
 `m`.

 3. Let `property values` be the value for
 `m`.

 4. Let `property keyframes` be an empty sequence
 of [keyframes](#keyframe).

 5. For each value, `v`, in
 `property values`, perform the following
 steps:

 1. Let `k` be a new
 [keyframe](#keyframe) with a `null` [keyframe
 offset](#keyframe-offset).

 2. Add the property-value pair,
 `property name` → `v`, to
 `k`.

 3. Append `k` to
 `property keyframes`.

 6. Apply the procedure to [compute missing keyframe
 offsets](#compute-missing-keyframe-offsets) to `property keyframes`.

 7. Add [keyframes](#keyframe) in `property keyframes` to
 `processed keyframes`.

 3. Sort `processed keyframes` by the [computed
 keyframe
 offset](#computed-keyframe-offsets) of each
 [keyframe](#keyframe)
 in increasing order.

 4. Merge adjacent [keyframes](#keyframe) in `processed keyframes` when
 they have equal [computed keyframe
 offsets](#computed-keyframe-offsets).

 5. Let `offsets` be a sequence of
 [nullable](https://webidl.spec.whatwg.org/#dfn-nullable-type) `double` values assigned based on the type
 of the `offset` member of the
 `property-indexed keyframe` as follows:

 ::: switch

 `sequence<double?>`,

 : The value of `offset` as-is.

 `double?`,

 : A sequence of length one with the value of `offset` as
 its single item, i.e. « `offset` »,
 :::

 6. Assign each value in `offsets` to the [keyframe
 offset](#keyframe-offset) of the
 [keyframe](#keyframe)
 with the corresponding position in
 `processed keyframes` until the end of either
 sequence is reached.

 7. Let `easings` be a sequence of
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) values assigned based on the type of the
 `easing` member of the
 `property-indexed keyframe` as follows:

 ::: switch

 `sequence<DOMString>`,

 : The value of `easing` as-is.

 `DOMString`,

 : A sequence of length one with the value of `easing` as
 its single item, i.e. « `easing` »,
 :::

 8. If `easings` is an empty sequence, let it be a
 sequence of length one containing the single value
 \"linear\", i.e. « \"linear\" ».

 9. If `easings` has fewer items than
 `processed keyframes`, repeat the elements in
 `easings` successively starting from the
 beginning of the list until `easings` has as many
 items as `processed keyframes`.

 :::
 (#example-649bc6e3) For example, if
 `processed keyframes` has five items, and
 `easings` is the sequence « \"ease-in\",
 \"ease-out\" », `easings` would be repeated to
 become « \"ease-in\", \"ease-out\", \"ease-in\",
 \"ease-out\", \"ease-in\" ».
 :::

 10. If `easings` has more items than
 `processed keyframes`, store the excess items as
 `unused easings`.

 11. Assign each value in `easings` to a property
 named `easing` on the
 [keyframe](#keyframe)
 with the corresponding position in
 `processed keyframes` until the end of
 `processed keyframes` is reached.

 12. If the `composite` member of the
 `property-indexed keyframe` is *not* an empty
 sequence:

 1. Let `composite modes` be a sequence of
 [`CompositeOperationOrAuto`](#enumdef-compositeoperationorauto) values assigned from the `composite`
 member of `property-indexed keyframe`. If
 that member is a single
 [`CompositeOperationOrAuto`](#enumdef-compositeoperationorauto) value operation, let
 `composite modes` be a sequence of length
 one, with the value of the `composite` as its single
 item.

 2. As with `easings`, if
 `composite modes` has fewer items than
 `processed keyframes`, repeat the elements in
 `composite modes` successively starting from
 the beginning of the list until
 `composite modes` has as many items as
 `processed keyframes`.

 3. Assign each value in `composite modes` that
 is not
 [`auto`](#dom-compositeoperationorauto-auto) to the [keyframe-specific composite
 operation](#keyframe-specific-composite-operation) on the
 [keyframe](#keyframe) with the corresponding position in
 `processed keyframes` until the end of
 `processed keyframes` is reached.
 :::

6. If `processed keyframes` is not [loosely sorted by
 offset](#loosely-sorted-by-offset),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort these steps.

7. If there exist any [keyframe](#keyframe) in `processed keyframes` whose [keyframe
 offset](#keyframe-offset) is non-null and less than zero or greater than one,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort these steps.

8. For each `frame` in `processed keyframes`,
 perform the following steps:

 1. For each property-value pair in `frame`, parse the
 property value using the syntax specified for that property.

 If the property value is invalid according to the syntax for the
 property, discard the property-value pair. User agents that
 provide support for diagnosing errors in content SHOULD produce
 an appropriate warning highlighting the invalid property value.

 2. Let the [easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function) of `frame` be the result of parsing
 the `easing` property on `frame` using the CSS syntax
 defined for the
 [`easing`](#dom-effecttiming-easing) member of the
 [`EffectTiming`](#dictdef-effecttiming) dictionary.

 If parsing the `easing` property fails,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort this procedure.

 Using the CSS parser in both of the above steps
 implies that CSS comments and escaping are allowed, but are not
 retained when the value is successfully parsed.

 In the case where the `easing` property fails
 to parse, it is important that the
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) is thrown *after* all reading the properties
 from `object` since failing to do so would be
 observable and will not match the behavior if partially
 open-ended dictionaries are later supported in WebIDL.

9. Parse each of the values in `unused easings` using the
 CSS syntax defined for the
 [`easing`](#dom-effecttiming-easing) member of the
 [`EffectTiming`](#dictdef-effecttiming) dictionary, and if any of the values fail to parse,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort this procedure.

 :::
 This final step is needed in order to provide consistent behavior
 such that a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) is thrown in all of the following cases:

 ``` highlight
 elem.animate({ easing: 'invalid' });
 elem.animate({ easing: ['invalid'] });
 elem.animate([{ easing: 'invalid' }]);
 ```
 :::

#### 6.6.4. The [`KeyframeEffectOptions` dictionary]
Additional parameters may be passed to the
[`KeyframeEffect(target, keyframes, options)`](#dom-keyframeeffect-keyframeeffect) constructor by providing a
[`KeyframeEffectOptions`](#dictdef-keyframeeffectoptions) object.

```
dictionary KeyframeEffectOptions : EffectTiming {
 CompositeOperation composite = "replace";
 CSSOMString? pseudoElement = null;
};
```

[`composite`], of type [CompositeOperation](#enumdef-compositeoperation), defaulting to `"replace"`

: The [composite
 operation](#composite-operation) used to composite this animation with the [effect
 stack](#effect-stack), as
 specified by one of the
 [`CompositeOperation`](#enumdef-compositeoperation) enumeration values. This is used for all
 [keyframes](#keyframe) that
 specify an
 [`auto`](#dom-compositeoperationorauto-auto) [keyframe-specific composite
 operation](#keyframe-specific-composite-operation).

[`pseudoElement`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring), nullable, defaulting to `null`

: The
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) selector (which must be valid or `null`) used to
 specify the [effect
 target](#keyframe-effect-effect-target) given the [target
 element](#effect-target-target-element).

### 6.7. The [`CompositeOperation` and [`CompositeOperationOrAuto`](#enumdef-compositeoperationorauto) enumerations]
The possible values of an [keyframe
effect](#keyframe-effect)'s
composition behavior are represented by the
[`CompositeOperation`](#enumdef-compositeoperation) enumeration.

```
enum CompositeOperation { "replace", "add", "accumulate" };
```

[`replace`]

: Corresponds to the
 [replace](#composite-operation-replace) [composite
 operation](#composite-operation) value such that the [animation
 effect](#animation-effect) overrides the [underlying
 value](#underlying-value) it is combined with.

[`add`]

: Corresponds to the
 [add](#composite-operation-add) [composite
 operation](#composite-operation) value such that the [animation
 effect](#animation-effect) is
 [added](https://drafts.csswg.org/css-values-4/#addition) to the [underlying
 value](#underlying-value) with which it is combined.

[`accumulate`]

: Corresponds to the
 [accumulate](#composite-operation-accumulate) [composite
 operation](#composite-operation) value such that the [animation
 effect](#animation-effect) is
 [accumulated](https://drafts.csswg.org/css-values-4/#accumulation) onto the [underlying
 value](#underlying-value).

The possible values of a [keyframe](#keyframe)'s composition behavior share the same values as the
[`CompositeOperation`](#enumdef-compositeoperation) enumeration along with the additional
[`auto`](#dom-compositeoperationorauto-auto) value.

```
enum CompositeOperationOrAuto { "replace", "add", "accumulate", "auto" };
```

[`auto`]

: Indicates that the [composite
 operation](#composite-operation) of the associated [keyframe
 effect](#keyframe-effect) should be used.

### 6.8. The `Animatable` interface mixin

Objects that could be the target of an
[`KeyframeEffect`](#keyframeeffect) object implement the
[`Animatable`](#animatable)
interface mixin.

```
interface mixin Animatable {
 Animation animate(object? keyframes,
 optional (unrestricted double or KeyframeAnimationOptions) options = );
 sequence<Animation> getAnimations(optional GetAnimationsOptions options = );
};

dictionary KeyframeAnimationOptions : KeyframeEffectOptions {
 DOMString id = "";
 AnimationTimeline? timeline;
};

dictionary GetAnimationsOptions {
 boolean subtree = false;
 CSSOMString? pseudoElement = null;
};
```

[`Animation animate(``keyframes``, ``options``)`]

: Performs the following steps:

 1. Let `target` be the object on which this method was
 called.

 2. Construct a new
 [`KeyframeEffect`](#keyframeeffect) object `effect` in the [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm) of `target` by using the same
 procedure as the
 [`KeyframeEffect(target, keyframes, options)`](#dom-keyframeeffect-keyframeeffect) constructor, passing `target` as the
 `target` argument, and the `keyframes` and
 `options` arguments as supplied.

 If the above procedure causes an exception to be thrown,
 propagate the exception and abort this procedure.

 3. If `options` is a
 [`KeyframeAnimationOptions`](#dictdef-keyframeanimationoptions) object, let `timeline` be the
 `timeline` member of `options` or, if `timeline`
 member of `options` is missing, the [default document
 timeline](#document-default-document-timeline) of the [node
 document](https://dom.spec.whatwg.org/#concept-node-document) of the element on which this method was called.

 4. Construct a new
 [`Animation`](#animation) object, `animation`, in the
 [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm) of `target` by using the same
 procedure as the
 [`Animation()`](#dom-animation-animation) constructor, passing `effect` and
 `timeline` as arguments of the same name.

 5. If `options` is a
 [`KeyframeAnimationOptions`](#dictdef-keyframeanimationoptions) object, assign the value of the `id` member of
 `options` to `animation`'s
 [`id`](#dom-animation-id) attribute.

 6. Run the procedure to [play an
 animation](#play-an-animation) for `animation` with the
 `auto-rewind` flag set to true.

 7. Return `animation`.

 ::: informative-bg
 *This section is non-normative*
 The following code fragment:

 ``` highlight
 var animation = elem.animate({ opacity: 0 }, 2000);
 ```

 is roughly equivalent to:

 ``` highlight
 var effect = new KeyframeEffect(elem, { opacity: 0 }, 2000);
 var animation = new Animation(effect, elem.ownerDocument.timeline);
 animation.play();
 ```
 :::

 ::: parameters

 [`keyframes`]

 : The [keyframes](#keyframe)
 to use. This value is passed to the
 [`KeyframeEffect(target, keyframes, options)`](#dom-keyframeeffect-keyframeeffect) constructor as the `keyframes`
 parameter and has the same interpretation as defined for that
 constructor.

 [`options`]

 : The timing and animation options for the created
 [`KeyframeEffect`](#keyframeeffect) and
 [`Animation`](#animation).
 :::

 ::: exceptions

 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror)

 : Raised under the conditions described for
 [`updateTiming()`](#dom-animationeffect-updatetiming) or
 [`setKeyframes()`](#dom-keyframeeffect-setkeyframes).

 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) of type \"[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)\"

 : Raised if the
 [`pseudoElement`](#dom-keyframeeffectoptions-pseudoelement) option is not `null` and is an invalid
 [\<pseudo-element-selector\>](https://drafts.csswg.org/selectors-4/#typedef-pseudo-element-selector).
 :::

[`sequence<Animation> getAnimations(``options``)`]

: 1. Let `object` be the object on which this method was
 called.

 2. Let `pseudoElement` be the result of
 [`pseudo-element parsing`](#dom-keyframeeffect-pseudo-element-parsing) applied to
 [`pseudoElement`](#dom-getanimationsoptions-pseudoelement) of
 [`options`](#dom-animatable-getanimations-options-options), or `null` if
 [`options`](#dom-animatable-getanimations-options-options) is not passed.

 3. If `pseudoElement` is not `null`, then let
 `target` be the
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) identified by `pseudoElement` with
 `object` as the originating element. Otherwise, let
 `target` be `object`.

 4. If
 [`options`](#dom-animatable-getanimations-options-options) is passed with
 [`subtree`](#dom-getanimationsoptions-subtree) set to true, then return the set of [relevant
 animations for a
 subtree](#relevant-animations-for-a-subtree) of `target`. Otherwise, return the
 set of [relevant
 animations](#relevant-animations) for `target`.

 The list returned by the above algorithm is sorted using the
 composite order described for the associated
 [animations](#concept-animation) of effects in [§ 5.4.2 The effect
 stack](#the-effect-stack).

 Calling this method triggers a [style change
 event](https://drafts.csswg.org/css-transitions-1/#style-change-event) for the [target
 element](#effect-target-target-element). As a result, the returned list reflects the state
 *after* applying any pending style changes to animation such as
 changes to animation-related style properties that have yet to be
 processed.

 ::: parameters

 [`options`]

 : Parameters governing the set of animations returned by
 [`getAnimations()`](#dom-animatable-getanimations).
 :::

 ::: exceptions

 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) of type \"[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)\"

 : Raised if the
 [`pseudoElement`](#dom-getanimationsoptions-pseudoelement) option is not `null` and is an invalid
 [\<pseudo-element-selector\>](https://drafts.csswg.org/selectors-4/#typedef-pseudo-element-selector).
 :::

[`id`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `""`

: The string to assign to the generated
 [`Animation`](#animation)'s
 [`id`](#dom-animation-id) attribute.

[`timeline`], of type [AnimationTimeline](#animationtimeline), nullable

: An optional value which, if present, specifies the
 [timeline](#timeline) with
 which to associate the newly-created
 [animation](#concept-animation).

[`subtree`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: If true, indicates that
 [animations](#concept-animation) associated with an [animation
 effect](#animation-effect) whose [target
 element](#effect-target-target-element) is a
 [descendant](https://dom.spec.whatwg.org/#concept-tree-descendant) of the object on which
 [`getAnimations()`](#dom-animatable-getanimations) is called should also be included in the result.

[`pseudoElement`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring), nullable, defaulting to `null`

: If set, indicates that the target of the operation is the
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) identified by this pseudo selector (e.g.
 `::before`) with the originating element being the object on which
 the function is called.

### [6.9. ][Extensions to the [`Document`](https://html.spec.whatwg.org/#document) interface]
The following extensions are made to the
[`Document`](https://html.spec.whatwg.org/#document) interface defined in
[\[DOM\]](#biblio-dom "DOM Standard").

```
partial interface Document {
 readonly attribute DocumentTimeline timeline;
};
```

[`timeline`], of type [DocumentTimeline](#documenttimeline), readonly

: The
 [`DocumentTimeline`](#documenttimeline) object representing the [default document
 timeline](#document-default-document-timeline).

### [6.10. ][Extensions to the [`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot) interface mixin]
The following extensions are made to the
[`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot) interface mixin defined in
[\[DOM\]](#biblio-dom "DOM Standard").

```
partial interface mixin DocumentOrShadowRoot {
 sequence<Animation> getAnimations();
};
```

[`sequence<Animation> getAnimations()`]

: Returns the set of [relevant animations for a
 subtree](#relevant-animations-for-a-subtree) for the
 [document](https://dom.spec.whatwg.org/#concept-document) or [shadow
 root](https://dom.spec.whatwg.org/#concept-shadow-root) on which this method is called.

 The returned list is sorted using the composite order described for
 the associated
 [animations](#concept-animation) of effects in [§ 5.4.2 The effect
 stack](#the-effect-stack).

 Calling this method triggers a [style change
 event](https://drafts.csswg.org/css-transitions-1/#style-change-event) for the document. As a result, the returned list
 reflects the state *after* applying any pending style changes to
 animation such as changes to animation-related style properties that
 have yet to be processed.

### [6.11. ][Extensions to the [`Element`](https://dom.spec.whatwg.org/#element) interface]
Since DOM Elements can be the target of an animation, the
[`Element`](https://dom.spec.whatwg.org/#element) interface
[\[DOM\]](#biblio-dom "DOM Standard") is extended as
follows:

```
Element includes Animatable;
```

This allows the following kind of usage.

``` highlight
elem.animate({ color: 'red' }, 2000);
```

### 6.12. The [`AnimationPlaybackEvent` interface]
[Animation playback
events](#animation-playback-events) are represented using the
[`AnimationPlaybackEvent`](#animationplaybackevent) interface.

```
[Exposed=Window]
interface AnimationPlaybackEvent : Event {
 constructor(DOMString type, optional AnimationPlaybackEventInit eventInitDict = );
 readonly attribute double? currentTime;
 readonly attribute double? timelineTime;
};
dictionary AnimationPlaybackEventInit : EventInit {
 double? currentTime = null;
 double? timelineTime = null;
};
```

[` AnimationPlaybackEvent (``type``, ``eventInitDict``)`]

: Constructs a new
 [`AnimationPlaybackEvent`](#animationplaybackevent) object using the procedure defined for
 [constructing
 events](https://dom.spec.whatwg.org/#constructing-events)
 [\[DOM\]](#biblio-dom "DOM Standard").

[`currentTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly, nullable

: The [current
 time](#animation-current-time) of the
 [animation](#concept-animation) that generated the event at the moment the event
 was queued. This will be `null` if the
 [animation] was
 [idle](#play-state-idle)
 at the time the event was generated.

[`timelineTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly, nullable

: The [time value](#time-value)
 of the [timeline](#timeline)
 with which the
 [animation](#concept-animation) that generated the event is associated at the
 moment the event was queued. This will be `null` if the
 [animation] was not associated with an
 [active timeline](#active-timeline) at the time the event was queued.

[`currentTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), nullable, defaulting to `null`

: See the description of the
 [`currentTime`](#dom-animationplaybackevent-currenttime) attribute.

[`timelineTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), nullable, defaulting to `null`

: See the description of the
 [`timelineTime`](#dom-animationplaybackevent-timelinetime) attribute.

### 6.13. Model liveness

Changes made to any part of the model cause the entire timing model to
be updated and any dependent style.

Unless otherwise stated, invoking the methods or constructors, or
getting or setting the members of interfaces defined in the [Web
Animations API](#web-animations-api) does *not* produce a [style change
event](https://drafts.csswg.org/css-transitions-1/#style-change-event).

 Other specifications that extend this specification are
expected to refine the requirements on [style change
events](https://drafts.csswg.org/css-transitions-1/#style-change-event) by introducing circumstances where such events *are*
triggered. For example, when the interfaces in this specification
represent animations defined by CSS markup, many of their methods will
need to trigger [style change events] in
order to reflect changes to the specified style.

::: informative-bg
*This section is non-normative*

Based on the above requirement and normative requirements elsewhere in
this specification, the following invariants can be observed:

Changes made to the [Web Animations model](#web-animations-model) take effect immediately

: For example, if the
 [`KeyframeEffect`](#keyframeeffect) associated with an
 [`Animation`](#animation) is [seeked](#seek)
 (see [§ 4.5.4 Setting the current time of an
 animation](#setting-the-current-time-of-an-animation)) via the [Web
 Animations API](#web-animations-api), the value returned when querying the animation's
 `startTime` will reflect updated state of the model immediately.

 :::
 (#example-f6015dd0)
 ``` highlight
 // Initially animation.effect.getComputedTiming().localTime is 3000
 animation.currentTime += 2000;
 alert(animation.effect.getComputedTiming().localTime); // Displays "5000"
 ```
 :::

Querying the computed style of a property affected by animation returns the fully up-to-date state of the animation

: For example, if the used style of an element is queried immediately
 after applying a new
 [`Animation`](#animation) to that element, the result of the new animation
 will be incorporated in the value returned.

 :::
 (#example-ac9a1207)
 ``` highlight
 // Set opacity to 0 immediately
 elem.animate({ opacity: 0 }, { fill: 'forwards' });
 alert(window.getComputedStyle(elem).opacity); // Displays "0"
 ```
 :::

Changes made within the same task are synchronized such that the whole set of changes is rendered together

: As a result of changes to the model taking effect immediately
 combined with ECMAScript's run-to-completion semantics, there should
 never be a situation where, for example, *only* the changes to
 specified style are rendered without applying animation.

 :::
 (#example-4f302d5c)
 ``` highlight
 // Fade the opacity with fallback for browsers that don't
 // support Element.animate
 elem.style.opacity = '0';
 elem.animate([ { opacity: 1 }, { opacity: 0 } ], 500);
 ```
 :::

 [Note,] however, that in the example above, a user agent
 may render a frame with *none* of the above changes applied. This
 might happen, for example, if rendering occurs in a separate process
 that is scheduled to run shortly after the above task completes but
 before the changes can be communicated to the process.

The value returned by the `currentTime` attribute of a [document timeline](#document-timeline) will not change within a task

: Due to the requirement on [timelines](#timeline) to update their [current
 time](#timeline-current-time) each time the [update animations and send
 events](#update-animations-and-send-events) procedure is run, querying the `currentTime` twice
 within a long block of code that is executed in the same script
 block will return the same value as shown in the following example.

 :::
 (#example-16dafcc0)
 ``` highlight
 var a = document.timeline.currentTime;
 // ... many lines of code ...
 var b = document.timeline.currentTime;
 alert(b - a); // Displays 0
 ```
 :::

The time passed to a `requestAnimationFrame` callback will be equal to `document.timeline.currentTime`

: Since HTML's [event loop processing
 model](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model) defines that the procedure to [update animations
 and send
 events](#update-animations-and-send-events) is performed prior to [running animation frame
 callbacks](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html.html#run-the-animation-frame-callbacks), and since the time passed to such callbacks is the
 same `now` timestamp is passed to both procedures, the
 [current
 time](#timeline-current-time) of a the [default document
 timeline](#document-default-document-timeline) should match the time passed to
 `requestAnimationFrame`.

 :::
 (#example-a0637e5c)
 ``` highlight
 window.requestAnimationFrame(function(now) {
 // Displays 0
 alert(now - document.timeline.currentTime);
 });
 ```
 :::

Calling methods from this programming interface will generally *not* cause transitions to be triggered

: Consider the following example:

 :::
 (#example-a8ba32df)
 ``` highlight
 // Setup transition start point
 div.style.opacity = '1';
 getComputedStyle(div).opacity;

 // Setup transition end point
 div.style.transition = 'opacity 1s';
 div.style.opacity = '0';

 // Fire an animation
 div.animate({ opacity: [0.5, 1] }, 500);

 // Wait for the transition to end -- the following will never be called!
 div.addEventListener('transitionend', () => {
 console.log('transitionend');
 });
 ```
 :::

 In this case, calling
 [`animate()`](#dom-animatable-animate) will *not* trigger a [style change
 event](https://drafts.csswg.org/css-transitions-1/#style-change-event). As a result, the pending style change will be
 processed at the same time as the style change resulting from the
 new animation. Since the animation style will override the
 [before-change
 style](https://drafts.csswg.org/css-transitions-1/#before-change-style) and the [after-change
 style](https://drafts.csswg.org/css-transitions-1/#after-change-style), no transition will be generated and the event
 handler for the
 [transitionend](https://drafts.csswg.org/css-transitions/#transitionend) event will never be called.

## 7. Integration with Media Fragments

The Media Fragments specification
[\[MEDIA-FRAGS\]](#biblio-media-frags "Media Fragments URI 1.0 (basic)")
defines a means for addressing a temporal range of a media resource. The
application of media fragments depends on the MIME type of the resource
on which they are specified. For resources with the [SVG MIME
type](https://svgwg.org/svg2-draft/mimereg.html#mime-registration)
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"),
the application of temporal parameters is defined in the [Animation
Elements](https://svgwg.org/specs/animation-elements/) specification.

 Media fragments are defined to operate on resources
based on their MIME type. As a result, temporal addressing might not be
supported in all situations where Web Animations content is used.

## 8. Implementation requirements

### 8.1. Precision of time values

The internal representation of time values is implementation dependent.
However, it is RECOMMENDED that user agents be able to represent input
time values with microsecond precision so that a [time
value](#time-value) (which
nominally represents milliseconds) of 0.001 is distinguishable from 0.0.

### 8.2. Conformance criteria

This specification defines an abstract model for animation and, as such,
for user agents that do not support scripting, there are no conformance
criteria since there is no testable surface area.

User agents that do not support scripting, however, may implement
additional technologies defined in terms of this specification, in which
case the definitions provided in this specification will form part of
the conformance criteria of the additional technology.

A [conforming scripted Web Animations user
agent] is a user agent that implements the [Web
Animations API](#web-animations-api) defined in [§ 6 Programming
interface](#programming-interface).

## 9. Acknowledgements

Thank you to Steve Block, Michael Giuffrida, Ryan Seys, and Eric
Willigers for their contributions to this specification.

Thank you also to Michiel "Pomax" Kamermans for help with the equations
for a proposed smooth easing function, although this feature has been
deferred to a subsequent specification.

Our deep gratitude goes out to [Southern Star
Animation](http://www.endemolshine.com.au) for their kind generosity and
patience in introducing the editors to the processes and techniques used
in producing broadcast animations.

## 10. Changes since last publication

The following changes have been made since the [5 June 2023 Working
Draft](https://www.w3.org/TR/2023/WD-web-animations-1-20230605/):

- Improved definitions and cross-linking for the Web Animations model,
 and reorganized [§ 4.6 Animation effects](#animation-effects) to
 introduce concepts before the procedures in [§ 4.7 Calculating
 progress](#core-animation-effect-calculations). ([PR
 8965](https://github.com/w3c/csswg-drafts/pull/8965), [PR
 8985](https://github.com/w3c/csswg-drafts/pull/8985))

- Renamed "timing function" to "[easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function)" throughout to match the terminology in
 [\[CSS-EASING-1\]](#biblio-css-easing-1 "CSS Easing Functions Level 1").
 ([PR 9218](https://github.com/w3c/csswg-drafts/pull/9218))

- Corrected the calculation of [active
 time](#active-time) for an
 [animation effect](#animation-effect) in the [after
 phase](#animation-effect-after-phase) with a [fill mode](#fill-mode) of [both](#fill-mode-both). ([Issue
 11613](https://github.com/w3c/csswg-drafts/issues/11613))

- Simplified the implicit [keyframes](#keyframe) generated when calculating the [effect
 value](#effect-value) of a
 [keyframe effect](#keyframe-effect) to use the [underlying
 value](#underlying-value)
 directly rather than adding a neutral value to it. ([Issue
 2914](https://github.com/w3c/csswg-drafts/issues/2914))

- Clarified that the implicit [keyframes](#keyframe) generated when calculating the [effect
 value](#effect-value) of a
 [keyframe effect](#keyframe-effect) use the [linear easing
 function](https://drafts.csswg.org/css-easing-2/#linear-easing-function). ([Issue
 14492](https://github.com/w3c/csswg-drafts/issues/14492))

- Added annotations describing exceptions thrown by methods in the [§ 6
 Programming interface](#programming-interface). ([Issue
 2050](https://github.com/w3c/csswg-drafts/issues/2050))

- Added a non-normative summary of how the [start
 time](#animation-start-time) and [hold
 time](#animation-hold-time) of an
 [animation](#concept-animation) determine its [play
 state](#animation-play-state). ([Issue
 2047](https://github.com/w3c/csswg-drafts/issues/2047))

- Explicitly invoked the procedure to [update an animation's finished
 state](#update-an-animations-finished-state) when updating effect timing or setting the [playback
 rate](#playback-rate), and
 clarified the flags used when updating the finished state. ([Issue
 2555](https://github.com/w3c/csswg-drafts/issues/2555))

- Made
 [`commitStyles()`](#dom-animation-commitstyles) use endpoint-inclusive timing so it can commit the
 endpoint of a completed animation without requiring a forwards [fill
 mode](#fill-mode). ([Issue
 5394](https://github.com/w3c/csswg-drafts/issues/5394))

- Specified that updating
 [`duration`](#dom-effecttiming-duration) with a string other than the lowercase `auto` throws
 a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror). ([Issue
 14206](https://github.com/w3c/csswg-drafts/issues/14206))

- Clarified that array-form keyframes can contain `null` or `undefined`
 entries. ([PR 11594](https://github.com/w3c/csswg-drafts/pull/11594))

- Corrected the procedure to [process a keyframe-like
 object](#process-a-keyframe-like-object) to return the dictionary defaults for `null` or
 `undefined` input before enumerating its properties. ([Issue
 14113](https://github.com/w3c/csswg-drafts/issues/14113))

- Added the
 [`pseudoElement`](#dom-getanimationsoptions-pseudoelement) option to
 [`getAnimations()`](#dom-animatable-getanimations) for requesting animations targeting a particular
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element). ([PR
 11050](https://github.com/w3c/csswg-drafts/pull/11050))

- Removed the \"Interaction with page display\" section since it
 contradicted the relationship of time values to other parts of the
 platform and was not implemented.

The
[changelog](https://github.com/w3c/csswg-drafts/commits/main/web-animations-1)
provides a more detailed history.

## [Appendix A: Animation types of existing properties]
Typically the [animation
type](#animation-type) of a
property is included along with its definition. However, for some
properties defined in older or very mature specifications the [animation
type] information is not included. All such
properties are assumed to have an [animation
type] of [by computed
value](#by-computed-value)
unless they are one of the exceptions listed below.

Tests

- [accumulation-per-property-001.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/accumulation-per-property-001.html "web-animations/animation-model/animation-types/accumulation-per-property-001.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/accumulation-per-property-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/accumulation-per-property-001.html)
- [accumulation-per-property-002.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/accumulation-per-property-002.html "web-animations/animation-model/animation-types/accumulation-per-property-002.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/accumulation-per-property-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/accumulation-per-property-002.html)
- [addition-per-property-001.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/addition-per-property-001.html "web-animations/animation-model/animation-types/addition-per-property-001.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/addition-per-property-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/addition-per-property-001.html)
- [addition-per-property-002.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/addition-per-property-002.html "web-animations/animation-model/animation-types/addition-per-property-002.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/addition-per-property-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/addition-per-property-002.html)
- [discrete.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/discrete.html "web-animations/animation-model/animation-types/discrete.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/discrete.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/discrete.html)
- [interpolation-per-property-001.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/interpolation-per-property-001.html "web-animations/animation-model/animation-types/interpolation-per-property-001.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/interpolation-per-property-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/interpolation-per-property-001.html)
- [interpolation-per-property-002.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/interpolation-per-property-002.html "web-animations/animation-model/animation-types/interpolation-per-property-002.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/interpolation-per-property-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/interpolation-per-property-002.html)
- [scrollbar-interpolation.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/scrollbar-interpolation.html "web-animations/animation-model/animation-types/scrollbar-interpolation.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/scrollbar-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/scrollbar-interpolation.html)
- [visibility.html](https://wpt.fyi/results/web-animations/animation-model/animation-types/visibility.html "web-animations/animation-model/animation-types/visibility.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/animation-types/visibility.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/animation-types/visibility.html)

### [Animation of [font-weight](https://drafts.csswg.org/css-fonts-4/#propdef-font-weight)]
The
[font-weight](https://drafts.csswg.org/css-fonts-4/#propdef-font-weight) property values prior to Level 4
are [combined](https://drafts.csswg.org/css-values-4/#combining-values)
as follows:

- [Interpolated](https://drafts.csswg.org/css-values-4/#interpolation) via discrete steps (multiples of 100). The
 interpolation happens in real number space as for
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value)s, and is converted to an integer by
 rounding to the nearest multiple of 100, with values halfway between
 multiples of 100 rounded towards positive infinity.

- [Addition](https://drafts.csswg.org/css-values-4/#addition) of
 [font-weight](https://drafts.csswg.org/css-fonts-4/#propdef-font-weight) values is defined as
 `V`~`result`~ = `V`~`a`~ +
 `V`~`b`~

 This definition is obsoleted by
[\[CSS-FONTS-4\]](#biblio-css-fonts-4 "CSS Fonts Module Level 4")
where the requirement that a
[font-weight](https://drafts.csswg.org/css-fonts-4/#propdef-font-weight) value be a multiple of 100 is
dropped. At that point the [animation
type](#animation-type) for
[font-weight] is simply [by
computed value](#by-computed-value).

### [Animation of [visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility)]
For the
[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) property,
[visible](https://drafts.csswg.org/css-display-4/#valdef-visibility-visible) is
[interpolated](https://drafts.csswg.org/css-values-4/#interpolation) as a discrete step where values of `p`
between 0 and 1 map to [visible] and other values of `p` map to the closer endpoint. If
neither value is [visible],
then [discrete](#discrete) animation
is used.

### [Animation of [box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow) and [text-shadow](https://drafts.csswg.org/css-text-decor-4/#propdef-text-shadow)]
Animation the
[box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow) or
[text-shadow](https://drafts.csswg.org/css-text-decor-4/#propdef-text-shadow) property follows the procedures for
[combining](https://drafts.csswg.org/css-values-4/#combining-values)
[shadow lists] as
follows:

Each shadow in the list (treating [none] as a 0-length list) is
interpolated component-wise as with [by computed
value](#by-computed-value)
behavior. However, if both input shadows are [inset] or both input
shadows are not [inset], then the interpolated shadow must match
the input shadows in that regard. If any pair of input shadows has one
[inset] and the other not [inset], the entire shadow-list
uses [discrete](#discrete)
animation. If the lists of shadows have different lengths, then the
shorter list is padded at the end with shadows whose color is
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent), whose lengths are all [0], and whose
[inset] (or not) matches the longer list.

[Addition](https://drafts.csswg.org/css-values-4/#addition) of two [shadow
lists](#combining-shadow-lists) `V`~`a`~ and
`V`~`b`~ is defined as
[list](https://infra.spec.whatwg.org/#list) concatenation such that
`V`~`result`~ is equal to
`V`~`a`~
[extended](https://infra.spec.whatwg.org/#list-extend) with `V`~`b`~.

[Accumulation](https://drafts.csswg.org/css-values-4/#accumulation) of [shadow
lists](#combining-shadow-lists) follows the matching rules for interpolation above,
performing addition on each component according to its type, or falling
back to [discrete](#discrete)
animation if the [inset] values do not match.

## 11. Privacy Considerations

No privacy considerations have been reported on this module.

## 12. Security Considerations

No security considerations have been reported on this module.

Tests

non-specific crashers

- [effect-on-marquee-parent-crash.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/effect-on-marquee-parent-crash.html "web-animations/animation-model/keyframe-effects/effect-on-marquee-parent-crash.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/effect-on-marquee-parent-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/effect-on-marquee-parent-crash.html)
- [transform-and-opacity-on-inline-001.html](https://wpt.fyi/results/web-animations/animation-model/keyframe-effects/transform-and-opacity-on-inline-001.html "web-animations/animation-model/keyframe-effects/transform-and-opacity-on-inline-001.html")
 [[(live
 test)]](http://wpt.live/web-animations/animation-model/keyframe-effects/transform-and-opacity-on-inline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/animation-model/keyframe-effects/transform-and-opacity-on-inline-001.html)
- [color-mix-crashtest.html](https://wpt.fyi/results/web-animations/crashtests/color-mix-crashtest.html "web-animations/crashtests/color-mix-crashtest.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/color-mix-crashtest.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/color-mix-crashtest.html)
- [effectively-infinite-timing-parameters.html](https://wpt.fyi/results/web-animations/crashtests/effectively-infinite-timing-parameters.html "web-animations/crashtests/effectively-infinite-timing-parameters.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/effectively-infinite-timing-parameters.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/effectively-infinite-timing-parameters.html)
- [get-computed-timing-crash.html](https://wpt.fyi/results/web-animations/crashtests/get-computed-timing-crash.html "web-animations/crashtests/get-computed-timing-crash.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/get-computed-timing-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/get-computed-timing-crash.html)
- [get-keyframe-fontsize-crash.html](https://wpt.fyi/results/web-animations/crashtests/get-keyframe-fontsize-crash.html "web-animations/crashtests/get-keyframe-fontsize-crash.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/get-keyframe-fontsize-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/get-keyframe-fontsize-crash.html)
- [get-timing-bad-pseudo-crash.html](https://wpt.fyi/results/web-animations/crashtests/get-timing-bad-pseudo-crash.html "web-animations/crashtests/get-timing-bad-pseudo-crash.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/get-timing-bad-pseudo-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/get-timing-bad-pseudo-crash.html)
- [infinite-active-duration.html](https://wpt.fyi/results/web-animations/crashtests/infinite-active-duration.html "web-animations/crashtests/infinite-active-duration.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/infinite-active-duration.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/infinite-active-duration.html)
- [non-interpolable-transition.html](https://wpt.fyi/results/web-animations/crashtests/non-interpolable-transition.html "web-animations/crashtests/non-interpolable-transition.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/non-interpolable-transition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/non-interpolable-transition.html)
- [partially-overlapping-animations-one-not-current-001.html](https://wpt.fyi/results/web-animations/crashtests/partially-overlapping-animations-one-not-current-001.html "web-animations/crashtests/partially-overlapping-animations-one-not-current-001.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/partially-overlapping-animations-one-not-current-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/partially-overlapping-animations-one-not-current-001.html)
- [reparent-animating-element-001.html](https://wpt.fyi/results/web-animations/crashtests/reparent-animating-element-001.html "web-animations/crashtests/reparent-animating-element-001.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/reparent-animating-element-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/reparent-animating-element-001.html)
- [reparent-animating-element-002.html](https://wpt.fyi/results/web-animations/crashtests/reparent-animating-element-002.html "web-animations/crashtests/reparent-animating-element-002.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/reparent-animating-element-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/reparent-animating-element-002.html)
- [set-timeline-undefined-progress.html](https://wpt.fyi/results/web-animations/crashtests/set-timeline-undefined-progress.html "web-animations/crashtests/set-timeline-undefined-progress.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/set-timeline-undefined-progress.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/set-timeline-undefined-progress.html)
- [sibling-index-offset-crash.html](https://wpt.fyi/results/web-animations/crashtests/sibling-index-offset-crash.html "web-animations/crashtests/sibling-index-offset-crash.html")
 [[(live
 test)]](http://wpt.live/web-animations/crashtests/sibling-index-offset-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/crashtests/sibling-index-offset-crash.html)
- [commitStyles-crash.html](https://wpt.fyi/results/web-animations/interfaces/Animation/commitStyles-crash.html "web-animations/interfaces/Animation/commitStyles-crash.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/commitStyles-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/commitStyles-crash.html)
- [commitStyles-svg-crash.html](https://wpt.fyi/results/web-animations/interfaces/Animation/commitStyles-svg-crash.html "web-animations/interfaces/Animation/commitStyles-svg-crash.html")
 [[(live
 test)]](http://wpt.live/web-animations/interfaces/Animation/commitStyles-svg-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/web-animations/interfaces/Animation/commitStyles-svg-crash.html)

------------------------------------------------------------------------
