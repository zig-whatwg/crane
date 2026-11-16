
This specification was published by the [Touch Events Community
Group](https://www.w3.org/community/touchevents/). It is not a W3C
Standard nor is it on the W3C Standards Track.

Please note that under the [W3C Community Final Specification Agreement
(FSA)](https://www.w3.org/community/about/process/final/) other
conditions apply.

This version of the specification includes fixes and improvements to
[Touch Events Level 1](https://www.w3.org/TR/touch-events/), and
incorporates the features previously published as [Touch Event
Extensions](https://www.w3.org/TR/touch-events-extensions/).

There is currently no intention to carry on further work on the Touch
Events specification. This document has been maintained up to this point
to reflect additions and changes made in user agents since the release
of the original [Touch Events Level
1](https://www.w3.org/TR/touch-events/) specification. The Community
Group considers Touch Events a legacy API -- authors are strongly
encouraged to adopt [Pointer
Events](https://www.w3.org/TR/pointerevents/) instead.

The Touch Events specification defines a set of low-level events that
represent one or more points of contact with a touch-sensitive surface,
and changes of those points with respect to the surface and any DOM
elements displayed upon it (e.g. for touch screens) or associated with
it (e.g. for drawing tablets without displays). It also addresses
pen-tablet devices, such as drawing tablets, with consideration toward
stylus capabilities.

## Introduction

User Agents that run on terminals which provide touch input to use web
applications typically use interpreted mouse events to allow users to
access interactive web applications. However, these interpreted events,
being normalized data based on the physical touch input, tend to have
limitations on delivering the intended user experience. Additionally, it
is not possible to handle concurrent input regardless of device
capability, due to constraints of mouse events: both system level
limitations and legacy compatibility.

Meanwhile, native applications are capable of handling both cases with
the provided system APIs.

The Touch Events specification provides a solution to this problem by
specifying interfaces to allow web applications to directly handle touch
events, and multiple touch points for capable devices.

This specification defines conformance criteria that apply to a single
product: the user agent that implements the interfaces that it contains.

WindowProxy is defined in \[\[!HTML5\]\].

### WebIDL Conformance

The IDL blocks in this specification are conforming IDL fragments as
defined by the WebIDL specification \[\[!WEBIDL\]\].

A conforming user agent must also be a [conforming JavaScript
implementation](https://webidl.spec.whatwg.org/#dfn-conforming-javascript-implementation)
of this IDL fragments in this specification, with the following
exception:

- [section 4.4.6 of Web
 IDL](https://www.w3.org/TR/WebIDL/#es-attributes) requires that IDL
 attributes are reflected as accessor properties on interface prototype
 objects. Instead of this, the user agent may reflect IDL attributes as
 data properties on the platform objects that implement the relevant
 interface. These data properties must have the same behavior when
 getting and setting as would be exhibited when invoking the getter and
 setter of the accessor properties on the platform object.

**Note:** Both ways of reflecting IDL attributes allow for simply
getting and setting the property on the platform object to work. For
example, given a `Touch` object `aTouch`, evaluating `aTouch.target`
would return the `EventTarget` for the `Touch` object. If the user agent
implements IDL attributes as accessor properties, then the property
access invokes the getter which returns the `EventTarget`. If the user
agent implements IDL attributes as data properties on the platform
object with the same behavior as would be found with the accessor
properties, then the object would appear to have an own property named
`target` whose value is an `EventTarget` object, and the property access
would return this value.

## [Touch] Interface

This interface describes an individual touch point for a touch event.
`Touch` objects are immutable; after one is created, its attributes must
not change.

``` idl

enum TouchType {
 "direct",
 "stylus"
};

dictionary TouchInit {
 required long identifier;
 required EventTarget target;
 double clientX = 0;
 double clientY = 0;
 double screenX = 0;
 double screenY = 0;
 double pageX = 0;
 double pageY = 0;
 float radiusX = 0;
 float radiusY = 0;
 float rotationAngle = 0;
 float force = 0;
 double altitudeAngle = 0;
 double azimuthAngle = 0;
 TouchType touchType = "direct";
};

[Exposed=Window]
interface Touch {
 constructor(TouchInit touchInitDict);
 readonly attribute long identifier;
 readonly attribute EventTarget target;
 readonly attribute double screenX;
 readonly attribute double screenY;
 readonly attribute double clientX;
 readonly attribute double clientY;
 readonly attribute double pageX;
 readonly attribute double pageY;
 readonly attribute float radiusX;
 readonly attribute float radiusY;
 readonly attribute float rotationAngle;
 readonly attribute float force;
 readonly attribute float altitudeAngle;
 readonly attribute float azimuthAngle;
 readonly attribute TouchType touchType;
};

```

[identifier]

: An identification number for each touch point.

 When a touch point becomes active, it must be assigned an identifier
 that is distinct from any other active touch point. While the touch
 point remains active, all events that refer to it must assign it the
 same identifier.

[target]

: The `EventTarget` on which the touch point started when it was first
 placed on the surface, even if the touch point has since moved
 outside the interactive area of that element.

 Some implementations alter the target element to correct for the
 imprecision of coarse input. Therefore, the target element may not
 necessarily be the element directly at the coordinates of the event.
 The methods used to target/disambiguate coarse input are out of
 scope for this specification.

[screenX]

: The horizontal coordinate of point relative to the screen in pixels

[screenY]

: The vertical coordinate of point relative to the screen in pixels

[clientX]

: The horizontal coordinate of point relative to the viewport in
 pixels, excluding any scroll offset

[clientY]

: The vertical coordinate of point relative to the viewport in pixels,
 excluding any scroll offset

[pageX]

: The horizontal coordinate of point relative to the viewport in
 pixels, including any scroll offset

[pageY]

: The vertical coordinate of point relative to the viewport in pixels,
 including any scroll offset

[radiusX]

: The radius of the ellipse which most closely circumscribes the
 touching area (e.g. finger, stylus) along the axis indicated by
 rotationAngle, in CSS pixels (as defined by \[\[!CSS-VALUES\]\]) of
 the same scale as screenX; `0` if no value is known. The value must
 not be negative.

[radiusY]

: The radius of the ellipse which most closely circumscribes the
 touching area (e.g. finger, stylus) along the axis perpendicular to
 that indicated by rotationAngle, in CSS pixels (as defined by
 \[\[!CSS-VALUES\]\]) of the same scale as screenY; `0` if no value
 is known. The value must not be negative.

[rotationAngle]

: The angle (in degrees) that the ellipse described by radiusX and
 radiusY is rotated clockwise about its center; `0` if no value is
 known. The value must be greater than or equal to `0` and less than
 `90`.

 If the ellipse described by radiusX and radiusY is circular, then
 rotationAngle has no effect. The user agent may use `0` as the value
 in this case, or it may use any other value in the allowed range.
 (For example, the user agent may use the rotationAngle value from
 the previous touch event, to avoid sudden changes.)

[force]

: A relative value of pressure applied, in the range `0` to `1`, where
 `0` is no pressure, and `1` is the highest level of pressure the
 touch device is capable of sensing; `0` if no value is known. In
 environments where force is known, the absolute pressure represented
 by the force attribute, and the sensitivity in levels of pressure,
 may vary.

[altitudeAngle]

: The altitude (in radians) of the transducer (e.g. pen/stylus), in
 the range \[0,π/2\] --- where 0 is parallel to the surface (X-Y
 plane), and π/2 is perpendicular to the surface. For hardware and
 platforms that do not report tilt or angle, the value MUST be 0.

 ::: note
 The default value defined here for `altitudeAngle` is 0. This
 differs from the [Pointer Events - Level
 3](https://w3c.github.io/pointerevents/) \[\[POINTEREVENTS\]\]
 specification\'s definition for the `altitudeAngle` property, which
 has a default value of π/2, which positions the transducer as being
 perpendicular to the surface.
 :::

 ![Example `altitudeAngle` of π/4 (45 degrees from the X-Y
 plane).](images/altitudeAngle.png)

[azimuthAngle]

: The azimuth angle (in radians) of the transducer (e.g. pen/stylus),
 in the range \[0, 2π\] --- where 0 represents a transducer whose cap
 is pointing in the direction of increasing X values (point to \"3
 o\'clock\" if looking straight down) on the X-Y plane, and the
 values progressively increase when going clockwise (π/2 at \"6
 o\'clock\", π at \"9 o\'clock\", 3π/2 at \"12 o\'clock\"). When the
 transducer is perfectly perpendicular to the surface
 (`altitudeAngle` of π/2), the value MUST be 0. For hardware and
 platforms that do not report tilt or angle, the value MUST be 0.

 ![Example `azimuthAngle` of π/6 (\"4
 o\'clock\").](images/azimuthAngle.png)

[touchType]

: The type of device used to trigger the touch.

<!-- -->

[TouchType]

: An enumeration representing the different types of possible touch
 input.

<!-- -->

[direct]

: A direct touch from a finger on the screen.

[stylus]

: A touch from a stylus or pen device.

## [TouchList] Interface

This interface defines a list of individual points of contact for a
touch event. `TouchList` objects are immutable; after one is created,
its contents must not change.

A `TouchList` object\'s *supported property indices* (\[\[!WEBIDL\]\])
are the numbers in the range 0 to one less than the length of the list.

``` idl

[Exposed=Window]
interface TouchList {
 readonly attribute unsigned long length;
 getter Touch? item (unsigned long index);
};

```

[length]

: Returns the number of `Touch` objects in the list

[item]

: Returns the `Touch` at the specified index in the list or null if
 the index is not less than the length of the list.

## [TouchEvent] Interface

This interface defines the `touchstart`, `touchend`, `touchmove`, and
`touchcancel` event types. `TouchEvent` objects are immutable; after one
is created and initialized, its attributes must not change. `TouchEvent`
inherits from the `UIEvent` interface defined in
\[\[!DOM-LEVEL-3-EVENTS\]\].

The [TouchEventInit] dictionary is used by the `TouchEvent`
interface\'s constructor to provide a mechanism by which to construct
untrusted (synthetic) touch events. It inherits from the
`EventModifierInit` dictionary defined in \[\[!DOM-LEVEL-3-EVENTS\]\].
The steps for constructing an event are defined in \[\[!DOM4\]\]. See
the [example](#firing-a-synthetic-touchevent-from-script "examples") for
sample code demonstrating how to fire an untrusted touch event.

``` idl

dictionary TouchEventInit : EventModifierInit {
 sequence<Touch> touches = ;
 sequence<Touch> targetTouches = ;
 sequence<Touch> changedTouches = ;
};

[Exposed=Window]
interface TouchEvent : UIEvent {
 constructor(DOMString type, optional TouchEventInit eventInitDict = );
 readonly attribute TouchList touches;
 readonly attribute TouchList targetTouches;
 readonly attribute TouchList changedTouches;
 readonly attribute boolean altKey;
 readonly attribute boolean metaKey;
 readonly attribute boolean ctrlKey;
 readonly attribute boolean shiftKey;
 getter boolean getModifierState (DOMString keyArg);
};

```

[touches]

: A list of `Touch` objects for every point of contact currently
 touching the surface.

[targetTouches]

: A list of `Touch` objects for every point of contact that is
 touching the surface *and* started on the element that is the target
 of the current event.

[changedTouches]

: A list of `Touch` objects for every point of contact which
 contributed to the event.

 For the `touchstart` event this must be a list of the touch points
 that just became active with the current event. For the `touchmove`
 event this must be a list of the touch points that have moved since
 the last event. For the `touchend` and `touchcancel` events this
 must be a list of the touch points that have just been removed from
 the surface, with the last known coordinates of the touch points
 before they were removed.

[altKey]

: `true` if the alt (Alternate) key modifier is activated; otherwise
 `false`

[metaKey]

: `true` if the meta (Meta) key modifier is activated; otherwise
 `false`. On some platforms this attribute may map to a
 differently-named key modifier.

[ctrlKey]

: `true` if the ctrl (Control) key modifier is activated; otherwise
 `false`

[shiftKey]

: `true` if the shift (Shift) key modifier is activated; otherwise
 `false`

[getModifierState](keyArg)

: Queries the state of a modifier using a key value. Returns `true` if
 it is a modifier key and the modifier is activated, `false`
 otherwise.

## TouchEvent Implementer\'s Note

User agents should ensure that all `Touch` objects available from a
given `TouchEvent` are all associated to the same document that the
`TouchEvent` was dispatched to. To implement this, user agents should
maintain a notion of the current *touch-active* document. On first
touch, this is set to the target document where the touch was created.
When all active touch points are released, the *touch-active* document
is cleared. All `TouchEvent`s are dispatched to the current
*touch-active* document, and each `Touch` object it contains refers only
to DOM elements (and co-ordinates) in that document. If a touch starts
entirely outside the currently *touch-active* document, then it is
ignored entirely.

## Usage Examples

The examples below demonstrate the relations between the different
`TouchList` members defined in a `TouchEvent`.

### `touches` and `targetTouches` of a `TouchEvent`

This example demonstrates the utility and relations between the
`touches` and `targetTouches` members defined in the `TouchEvent`
interface. The following code will generate different output based on
the number of touch points on the touchable element and the document:

``` example

<div id="touchable">This element is touchable.</div>

<script>
document.getElementById('touchable').addEventListener('touchstart', function(ev) {

 if (ev.touches.item(0) == ev.targetTouches.item(0))
 {
 /**
 * If the first touch on the surface is also targeting the
 * "touchable" element, the code below should execute.
 * Since targetTouches is a subset of touches which covers the
 * entire surface, TouchEvent.touches >= TouchEvents.targetTouches
 * is always true.
 */

 document.write('Hello Touch Events!');
 }

 if (ev.touches.length == ev.targetTouches.length)
 {
 /**
 * If all of the active touch points are on the "touchable"
 * element, the length properties should be the same.
 */

 document.write('All points are on target element')
 }

 if (ev.touches.length > 1)
 {
 /**
 * On a single touch input device, there can only be one point
 * of contact on the surface, so the following code can only
 * execute when the terminal supports multiple touches.
 */

 document.write('Hello Multiple Touch!');
 }

}, false);
</script>
```

### `changedTouches` of a `TouchEvent`

This example demonstrates the utility of `changedTouches` and it\'s
relation with the other `TouchList` members of the `TouchEvent`
interface. The code is a example which triggers whenever a touch point
is removed from the defined touchable element:

``` example

<div id="touchable">This element is touchable.</div>

<script>
document.getElementById('touchable').addEventListener('touchend', function(ev) {

 /**
 * Example output when three touch points are on the surface,
 * two of them being on the "touchable" element and one point
 * in the "touchable" element is lifted from the surface:
 *
 * Touch points removed: 1
 * Touch points left on element: 1
 * Touch points left on document: 2
 */

 document.write('Touch points removed: ' + ev.changedTouches.length);
 document.write('Touch points left on element: ' + ev.targetTouches.length);
 document.write('Touch points left on document: ' + ev.touches.length);

}, false);
</script>
```

### Firing a synthetic `TouchEvent` from script

This example demonstrates how to create and fire a `TouchEvent` from
script.

``` example

if (Touch.length < 1 || TouchEvent.length < 1)
 throw "TouchEvent constructors not supported";

var touch = new Touch({
 identifier: 42,
 target: document.body,
 clientX: 200,
 clientY: 200,
 screenX: 300,
 screenY: 300,
 pageX: 200,
 pageY: 200,
 radiusX: 5,
 radiusY: 5
});

var touchEvent = new TouchEvent("touchstart", {
 cancelable: true,
 bubbles: true,
 composed: true,
 touches: [touch],
 targetTouches: [touch],
 changedTouches: [touch]
});

document.body.dispatchEvent(touchEvent);
```

## List of `TouchEvent` types

The following table provides a summary of the `TouchEvent` event types
defined in this specification. All events should accomplish the bubbling
phase. All events should be composed \[\[WHATWG-DOM\]\] events.

 Event Type Sync / Async Bubbling phase Composed Trusted proximal event target types Interface Cancelable Default Action
 --------------- -------------- ---------------- ---------- ------------------------------------- -------------- -------------------------- --------------------------------------------------------------------------
 `touchstart` Sync Yes Yes `Document`, `Element` `TouchEvent` [Varies](#cancelability) undefined
 `touchend` Sync Yes Yes `Document`, `Element` `TouchEvent` [Varies](#cancelability) Varies: user agents may dispatch [mouse and click events](#mouse-events)
 `touchmove` Sync Yes Yes `Document`, `Element` `TouchEvent` [Varies](#cancelability) undefined
 `touchcancel` Sync Yes Yes `Document`, `Element` `TouchEvent` No none

### Cancelability of touch events

[Canceling](#dfn-canceled-event) a touch event can prevent or otherwise
interrupt scrolling (which could be happening in parallel with script
execution). For maximum scroll performance, a user agent may not wait
for each touch event associated with the scroll to be processed to see
if it will be canceled. In such cases the user agent should generate
touch events whose `cancelable` property is `false`, indicating that
`preventDefault` cannot be used to prevent or interrupt scrolling.
Otherwise `cancelable` will be `true`.

In particular, a user agent should generate only uncancelable touch
events when it [observes that there are no non-passive
listeners](https://dom.spec.whatwg.org/#observing-event-listeners) for
the event.

### The [`touchstart`] event

A user agent must dispatch this event type to indicate when the user
places a touch point on the touch surface.

The target of this event must be an `Element`. If the touch point is
within a frame, the event should be dispatched to an element in the
child browsing context of that frame.

If this event is [canceled](#dfn-canceled-event), it should prevent any
default actions caused by any touch events associated with the same
active touch point, including mouse events or scrolling.

### The [`touchend`] event

A user agent must dispatch this event type to indicate when the user
removes a touch point from the touch surface, also including cases where
the touch point physically leaves the touch surface, such as being
dragged off of the screen.

The target of this event must be the same `Element` on which the touch
point started when it was first placed on the surface, even if the touch
point has since moved outside the interactive area of the target
element.

The touch point or points that were removed must be included in the
`changedTouches` attribute of the `TouchEvent`, and must not be included
in the `touches` and `targetTouches` attributes.

If this event is [canceled](#dfn-canceled-event), any sequence of touch
events that includes this event must not be [interpreted as a
click](#click-events).

### The [`touchmove`] event

A user agent must dispatch this event type to indicate when the user
moves a touch point along the touch surface.

The target of this event must be the same `Element` on which the touch
point started when it was first placed on the surface, even if the touch
point has since moved outside the interactive area of the target
element.

Note that the rate at which the user agent sends `touchmove` events is
implementation-defined, and may depend on hardware capabilities and
other implementation details.

A user agent should suppress the default action caused by any
`touchmove` event until at least one `touchmove` event associated with
the same active touch point is not [canceled](#dfn-canceled-event).
Whether the default action is suppressed for `touchmove` events after at
least one `touchmove` event associated with the same active touch point
is not [canceled](#dfn-canceled-event) is implementation dependent.

### The [`touchcancel`] event

A user agent must dispatch this event type to indicate when a touch
point has been disrupted in an implementation-specific manner, such as a
synchronous event or action originating from the UA canceling the touch,
or the touch point leaving the document window into a non-document area
which is capable of handling user interactions (e.g. the UA\'s native
user interface, or an area of the document which is managed by a
plug-in). A user agent may also dispatch this event type when the user
places more touch points on the touch surface than the device or
implementation is configured to store, in which case the earliest
`Touch` object in the `TouchList` should be removed.

The target of this event must be the same `Element` on which the touch
point started when it was first placed on the surface, even if the touch
point has since moved outside the interactive area of the target
element.

The touch point or points that were removed must be included in the
`changedTouches` attribute of the `TouchEvent`, and must not be included
in the `touches` and `targetTouches` attributes.

## Retargeting

The following section describes [retargeting
steps](https://dom.spec.whatwg.org/#retarget), defined in
\[\[!WHATWG-DOM\]\].

`Touch` object has an associated [unadjustedTarget] (null or
`EventTarget`). Unless stated otherwise it is null.

`TouchEvent`\'s [retargeting
steps](https://dom.spec.whatwg.org/#retarget), given a
`touchEvent`, must run these steps:

1. For each `Touch` `touch` in `touchEvent`\'s
 `touches`, `targetTouches`, and `changedTouches` members:

 1. Set `touch`\'s `unadjustedTarget` to
 `touch`\'s `target` if `touch`\'s
 `unadjustedTarget` is null.
 2. Set `touch`\'s `target` to the result of invoking
 [retargeting](https://dom.spec.whatwg.org/#retarget)
 `touch`\'s `unadjustedTarget` against
 `touchEvent`\'s `target`.

## Conditionally exposing legacy touch event APIs

User agents have an associated boolean [expose legacy touch event
APIs] whose value is implementation-defined.

Existing web content often use the existence of these APIs as a signal
that the user agent is a touch-enabled \"mobile\" device, and therefore
exposing these APIs on non-mobile devices, even if they are
touch-enabled, could lead to a suboptimal user experience for such web
content.

## Extensions to the `GlobalEventHandlers` mixin

The following section describes extensions to the existing
[GlobalEventHandlers] mixin,
defined in \[\[!HTML5\]\], to facilitate the event handler registration.
For user agents where expose legacy touch event APIs is false, this
mixin must not be implemented.

``` idl

partial interface mixin GlobalEventHandlers {
 attribute EventHandler ontouchstart;
 attribute EventHandler ontouchend;
 attribute EventHandler ontouchmove;
 attribute EventHandler ontouchcancel;
};

```

[ontouchstart]

: The event handler IDL attribute (see \[\[!HTML5\]\]) for the
 `touchstart` event type.

[ontouchend]

: The event handler IDL attribute (see \[\[!HTML5\]\]) for the
 `touchend` event type.

[ontouchmove]

: The event handler IDL attribute (see \[\[!HTML5\]\]) for the
 `touchmove` event type.

[ontouchcancel]

: The event handler IDL attribute (see \[\[!HTML5\]\]) for the
 `touchcancel` event type.

## Interaction with Mouse Events and `click`

The user agent may dispatch both touch events and (for compatibility
with web content not designed for touch) mouse events
\[\[!DOM-LEVEL-2-EVENTS\]\] in response to the same user input. If the
user agent dispatches both touch events and mouse events in response to
a single user action, then the `touchstart` event type must be
dispatched before any mouse event types for that action. If
`touchstart`, `touchmove`, or `touchend` are
[canceled](#dfn-canceled-event), the user agent should not dispatch any
mouse event that would be a consequential result of the prevented touch
event.

If a Web application can process touch events, it can
[cancel](#dfn-canceled-event) the events, and no corresponding mouse
events would need to be dispatched by the user agent. If the Web
application is not specifically written for touch input devices, it will
react to the subsequent mouse events instead.

User agents will typically dispatch mouse and click events only for
single-finger activation gestures (like tap and long press). Gestures
involving movement of the touch point or multi-touch interactions --
with two or more [active touch points](#dfn-active-touch-point) -- will
usually only generate touch events.

If the user agent interprets a sequence of touch events as a tap
gesture, then it should dispatch `mousemove`, `mousedown`, `mouseup`,
and `click` events (in that order) at the location of the `touchend`
event for the corresponding touch input. If the contents of the document
have changed during processing of the touch events, then the user agent
may dispatch the mouse events to a different target than the touch
events.

The default actions and ordering of any further touch and mouse events
are implementation-defined, except as specified elsewhere.

The activation of an element (e.g., in some implementations, a tap)
would typically produce the following event sequence (though this may
vary slightly, depending on specific user agent behavior):

1. `touchstart`
2. Zero or more `touchmove` events, depending on movement of the finger
3. `touchend`
4. `mousemove` [(for compatibility with legacy mouse-specific
 code)]
5. `mousedown`
6. `mouseup`
7. `click`

If, however, either the `touchstart`, `touchmove` or `touchend` event
has been [canceled](#dfn-canceled-event) during this interaction, no
mouse or click events will be fired, and the resulting sequence of
events would simply be:

1. `touchstart`
2. Zero or more `touchmove` events, depending on movement of the finger
3. `touchend`

Even if a user agent supports Touch Events, this does not necessarily
mean that a touchscreen is the only input mechanism available to users.
Particularly in the case of touch-enabled laptops, or traditional
\"touch only\" devices (such as phones and tablets) with paired external
input devices, users may use the touchscreen in conjunction with a
trackpad, mouse or keyboard. For this reason, developers should avoid
binding event listeners with \"either touch or mouse/keyboard\"
conditional code, as this results in sites/application that become
touch-exclusive, preventing users from being able to use any other input
mechanism.

``` example

// conditional "touch OR mouse/keyboard" event binding
// DON'T DO THIS, as it makes interactions touch-exclusive
// on devices that have both touch and mouse/keyboard

if ('ontouchstart' in window) {
 // set up event listeners for touch
 target.addEventListener('touchend', ...);
 ...
} else {
 // set up event listeners for mouse/keyboard
 target.addEventListener('click', ...);
 ...
}
```

Instead, developers should handle different forms of input concurrently.

``` example

// concurrent "touch AND mouse/keyboard" event binding

// set up event listeners for touch
target.addEventListener('touchend', function(e) {
 // prevent compatibility mouse events and click
 e.preventDefault();
 ...
});
...

// set up event listeners for mouse/keyboard
target.addEventListener('click', ...);
...
```

To avoid processing the same interaction twice for touch (once for the
touch event, and once for the compatibility mouse events), developers
should make sure to [cancel](#dfn-canceled-event) the touch event,
suppressing the generation of any further mouse or click events.
Alternatively, see the [InputDeviceCapabilities
API](https://wicg.github.io/input-device-capabilities/) for a way to
detect mouse events that were generated as a result of touch events.

## Glossary

[active touch point]
: A touch point which is currently on the screen and is being tracked
 by the user agent. The touch point becomes active when the user
 agent first dispatches a `touchstart` event indicating its
 appearance. It ceases to be active after the user agent dispatches a
 `touchend` or `touchcancel` event indicating that the touch point is
 removed from the surface or no longer tracked.

[touch point]
: The coordinate point at which a pointer (e.g finger or stylus)
 intersects the target surface of an interface. This may apply to a
 finger touching a touch-screen, or an digital pen writing on a piece
 of paper.

[canceled event]
: An event whose default action was prevented by means of
 `preventDefault()`, returning `false` in an event handler, or other
 means as defined by \[\[!DOM-LEVEL-3-EVENTS\]\] and \[\[!HTML5\]\].

## Acknowledgements

Many thanks to the WebKit engineers for developing the model used as a
basis for this spec, Neil Roberts (SitePen) for his summary of WebKit
touch events, Peter-Paul Koch (PPK) for his write-ups and suggestions,
Robin Berjon for developing the [ReSpec.js spec authoring
tool](https://dev.w3.org/2009/dap/ReSpec.js/documentation.html), and the
WebEvents WG for their many contributions.

Many others have made additional comments as the spec developed, which
have led to steady improvements. Among them are Matthew Schinckel,
Andrew Grieve, Cathy Chan, Boris Zbarsky, Patrick H. Lauke, and Simon
Pieters. If we inadvertently omitted your name, please let me know.

The group acknowledges the following contributors to this
specification\'s test suite: Matt Brubeck, Olli Pettay, Art Barstow,
Cathy Chan and Rick Byers.

## Changes Since Last Publication

This is a summary of the major changes made since the [10 October 2013
Recommendation](https://www.w3.org/TR/touch-events/) was published.
[Full commit
history](https://github.com/w3c/touch-events/compare/v1...gh-pages) is
also available.

- [Reword altitudeAngle/azimuthAngle descriptions in line with
 PointerEvents, add
 illustrations](https://github.com/w3c/touch-events/pull/125)
- [Add getModifierState
 definition](https://github.com/w3c/touch-events/pull/120)
- [Added force attribute to
 Touch](https://github.com/w3c/touch-events/commit/303b36e1d188a380f9bc0861b175438e596a34b1)
- [Added radiusX and radiusY attributes to
 Touch](https://github.com/w3c/touch-events/commit/6d222fb7f106273bef847ad1d1d7a23569841954)
- [Added rotationAngle attribute to
 Touch](https://github.com/w3c/touch-events/commit/487f6815a9590b72779d4820ff43c2b58d798f92)
- [Upgraded co-ordinates to double type instead of
 long](https://github.com/w3c/touch-events/commit/006274ffada14de504f731afdb5ec1581ff327ca)
- [Update touchmove behavior on
 preventDefault](https://github.com/w3c/touch-events/commit/df620100e48111cf7a30592f344606f8c8b7fe22)
- [Clarify effect of canceling touchend
 event](https://github.com/w3c/touch-events/commit/54a3d1668c4f727d9c6f6d729b28a036041e301f)
- [Add constructor for TouchEvent and
 Touch](https://github.com/w3c/touch-events/commit/219546b80cd148543a5ece656d81ba3c901d2106)
- [Added legacy event initializer
 initTouchEvent](https://github.com/w3c/touch-events/commit/50f51ccacb0d5ad06f9cf6ed44f853d6a3616d10)
- [Added support for uncancelable touch events and described scroll
 performance implications](https://github.com/w3c/touch-events/pull/59)
- [Indicate that all events should be
 \"composed\".](https://github.com/w3c/touch-events/pull/67)
- [Note about avoiding conditional \"touch OR mouse/keyboard\" event
 handling](https://github.com/w3c/touch-events/pull/72)
- [Added TouchEvent\'s retargeting
 steps](https://github.com/w3c/touch-events/pull/73)
- [Add touchType, altitudeAngle, azimuthAngle (Safari iOS 10.3
 extensions for stylus)](https://github.com/w3c/touch-events/pull/81)
- [Add \[Exposed=Window\] to
 Constructor](https://github.com/w3c/touch-events/pull/88)
- [Add note to mention UA might adjusting touch
 target](https://github.com/w3c/touch-events/pull/95)
- [Remove Legacy Event Initializers (createTouch and
 createTouchList)](https://github.com/w3c/touch-events/pull/96) and the
 [note about initTouchEvent /
 createTouchList](https://github.com/w3c/touch-events/pull/100)
- [Conditionally expose legacy touch events
 API](https://github.com/w3c/touch-events/pull/111)
- [Add getModifierState definition to
 TouchEvent](https://github.com/w3c/touch-events/pull/91)
