
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# Pointer Events

## Level 4

[W3C Working Draft](https://www.w3.org/standards/types#WD) 08 October
2026

More details about this document

This version:
: [https://www.w3.org/TR/2026/WD-pointerevents4-20261008/](https://www.w3.org/TR/2026/WD-pointerevents4-20261008/)

Latest published version:
: <https://www.w3.org/TR/pointerevents4/>

Latest editor\'s draft:
: <https://w3c.github.io/pointerevents/>

History:
: <https://www.w3.org/standards/history/pointerevents4/>
: [Commit history](https://github.com/w3c/pointerevents/commits/)

Test suite:
: <https://wpt.fyi/pointerevents/>

Latest Recommendation:
: <https://www.w3.org/TR/pointerevents3>

Editors:
: [Patrick H. Lauke]
 ([TetraLogical](https://tetralogical.com/))
: [Robert Flack]
 ([Google](https://www.google.com/))

Former editors:
: [Matt Brubeck]
 ([Mozilla](https://www.mozilla.org/))
: [Rick Byers] ([Google](https://www.google.com/))
: [Navid Zolghadr]
 ([Google](https://www.google.com/))

Feedback:
: [GitHub w3c/pointerevents](https://github.com/w3c/pointerevents/)
 ([pull requests](https://github.com/w3c/pointerevents/pulls/), [new
 issue](https://github.com/w3c/pointerevents/issues/new/choose),
 [open issues](https://github.com/w3c/pointerevents/issues/))
: [public-pointer-events@w3.org](mailto:public-pointer-events@w3.org?subject=%5Bpointerevents4%5D%20YOUR%20TOPIC%20HERE)
 with subject line [\[pointerevents4\] *... message topic ...*]
 ([archives](https://lists.w3.org/Archives/Public/public-pointer-events){rel="discussion"})

Browser support:
: [caniuse.com](https://caniuse.com/pointer)

[Copyright](https://www.w3.org/policies/#copyright) © 2026 [World Wide
Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

The Pointer Events specification defines a unified hardware-agnostic
framework for handling input from various devices, including mice,
touchscreens, and pens/styluses. By providing a single set of events
(e.g., pointerdown, pointermove, pointerup), it allows developers to
support diverse input methods without writing device-specific logic for
each.

This specification also defines Mouse and Wheel Events, as well as a
mapping to fire Mouse Events for other pointer device types.

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

This specification is an update to
\[[PointerEvents3](#bib-pointerevents3 "Pointer Events")\] specification. It also includes the Mouse and
Wheel Events, previously in the
\[[UIEVENTS](#bib-uievents "UI Events")\]
specification.

This revision includes new features:

- `persistentDeviceId` to provide a stable identifier for input devices
 across multiple interactions.
- new CSS [`touch-action`
 values](#dfn-touch-action-values): `pan-left`, `pan-right`, `pan-up`,
 `pan-down`

This document was published by the [Pointer Events Working
Group](https://www.w3.org/groups/wg/pointer-events) as a Working Draft
using the [Recommendation
track](https://www.w3.org/policies/process/20250818/#recs-and-notes).

Publication as a Working Draft does not imply endorsement by [W3C] and its Members.

This is a draft document and may be updated, replaced, or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than a work in progress.

This document was produced by a group operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/pointer-events/ipr){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent that the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the
[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

This document is governed by the [18 August 2025 [W3C] Process
Document](https://www.w3.org/policies/process/20250818/).

## Table of Contents

1. [Abstract](#abstract)
2. [Status of This Document](#sotd)
3. [1. Introduction](#intro)
4. [2. Conformance](#conformance)
5. [3. Pointer Events and
 interfaces](#pointer-events-and-interfaces)
 1. [3.1 `PointerEvent`
 interface](#pointerevent-interface)
 1. [3.1.1 Button states](#button-states)
 1. [3.1.1.1 [Chorded button
 interactions]](#chorded-button-interactions)
 2. [3.1.1.2 The `button`
 property](#the-button-property)
 3. [3.1.1.3 The `buttons`
 property](#the-buttons-property)
 2. [3.1.2 The [primary
 pointer]{plurals="primary pointers"}](#the-primary-pointer)
 3. [3.1.3 Firing events using the `PointerEvent`
 interface](#firing-events-using-the-pointerevent-interface)
 1. [3.1.3.1 Attributes and default
 actions](#attributes-and-default-actions)
 2. [3.1.3.2 Process pending pointer
 capture](#process-pending-pointer-capture)
 3. [3.1.3.3 Suppressing a pointer event
 stream](#suppressing-a-pointer-event-stream)
 4. [3.1.4 [Boundary events caused by layout
 changes]](#boundary-events-caused-by-layout-changes)
 5. [3.1.5 Converting between `tiltX` / `tiltY` and
 `altitudeAngle` /
 `azimuthAngle`](#converting-between-tiltx-tilty-and-altitudeangle-azimuthangle)
 2. [3.2 PointerEvent
 Algorithms](#pointerevent-algorithms)
 1. [3.2.1 initialize a [`PointerEvent`]](#initialize-a-pointerevent)
 2. [3.2.2 create a [`PointerEvent`]](#create-a-pointerevent)
 3. [3.2.3 [create `PointerEvent` from `MouseEvent`]](#create-pointerevent-from-mouseevent)
 3. [3.3 Pointer Event types](#pointer-event-types)
 1. [3.3.1 [pointerover]](#pointerover)
 2. [3.3.2 [pointerenter]](#pointerenter)
 3. [3.3.3
 [pointerdown]](#pointerdown)
 4. [3.3.4
 [pointermove]](#pointermove)
 5. [3.3.5
 [pointerrawupdate]](#pointerrawupdate)
 6. [3.3.6 [pointerup]](#pointerup)
 7. [3.3.7
 [pointercancel]](#pointercancel)
 8. [3.3.8
 [pointerout]](#pointerout)
 9. [3.3.9
 [pointerleave]](#pointerleave)
 10. [3.3.10
 [gotpointercapture]](#gotpointercapture)
 11. [3.3.11
 [lostpointercapture]](#lostpointercapture)
 12. [3.3.12 `click`, `auxclick`, and
 `contextmenu`](#click-auxclick-and-contextmenu)
 1. [3.3.12.1 Event attributes](#event-attributes)
 2. [3.3.12.2 Event
 coordinates](#event-coordinates)
 3. [3.3.12.3 Event dispatch](#event-dispatch)
6. [4. Extensions to the `Element`
 interface](#extensions-to-the-element-interface)
7. [5. Extensions to the `GlobalEventHandlers`
 mixin](#extensions-to-the-globaleventhandlers-mixin)
8. [6. Extensions to the `Navigator`
 interface](#extensions-to-the-navigator-interface)
9. [7. [Declaring direct manipulation
 behavior]](#declaring-direct-manipulation-behavior)
 1. [7.1 The `touch-action` CSS
 property](#the-touch-action-css-property)
 2. [7.2 Determining supported direct manipulation
 behavior](#determining-supported-direct-manipulation-behavior)
 3. [7.3 [Details of `touch-action`
 values]](#details-of-touch-action-values)
10. [8. [Pointer capture]](#pointer-capture)
 1. [8.1 Introduction](#introduction)
 2. [8.2 [Setting pointer
 capture]](#setting-pointer-capture)
 3. [8.3 [Releasing pointer
 capture]](#releasing-pointer-capture)
 4. [8.4 Implicit pointer
 capture](#implicit-pointer-capture)
 5. [8.5 [Implicit release of pointer
 capture]](#implicit-release-of-pointer-capture)
11. [9. Coalesced and predicted
 events](#coalesced-and-predicted-events)
 1. [9.1 Coalesced events](#coalesced-events)
 2. [9.2 Predicted events](#predicted-events)
 3. [9.3 Populating and maintaining the coalesced and predicted
 events
 lists](#populating-and-maintaining-the-coalesced-and-predicted-events-lists)
12. [10. [Compatibility mapping with mouse
 events]](#compatibility-mapping-with-mouse-events)
 1. [10.1 Tracking the effective position of the legacy mouse
 pointer](#tracking-the-effective-position-of-the-legacy-mouse-pointer)
 2. [10.2 Mapping for devices that support
 hover](#mapping-for-devices-that-support-hover)
 3. [10.3 Mapping for devices that do not support
 hover](#mapping-for-devices-that-do-not-support-hover)
13. [11. Mouse Events and
 Interfaces](#mouse-events-and-interfaces)
 1. [11.1 `MouseEvent` interface](#mouseevent-interface)
 2. [11.2 MouseEvent Algorithms](#mouseevent-algorithms)
 1. [11.2.1 Native OS
 Requirements](#native-os-requirements)
 2. [11.2.2 Constructing Mouse
 Events](#constructing-mouse-events)
 3. [11.2.3 Global State for
 MouseEvent](#global-state-for-mouseevent)
 1. [11.2.3.1 User Agent-Level
 State](#user-agent-level-state)
 2. [11.2.3.2 Window-Level
 State](#window-level-state)
 4. [11.2.4 Internal State for
 MouseEvent](#internal-state-for-mouseevent)
 5. [11.2.5 hit test](#hit-test)
 6. [11.2.6 initialize a [`MouseEvent`]](#initialize-a-mouseevent)
 7. [11.2.7 set mouse event
 modifiers](#set-mouse-event-modifiers)
 8. [11.2.8 [create a cancelable
 MouseEvent]](#create-a-cancelable-mouseevent)
 9. [11.2.9 [create a non-cancelable
 MouseEvent]](#create-a-non-cancelable-mouseevent)
 10. [11.2.10 calculate MouseEvent button
 attribute](#calculate-mouseevent-button-attribute)
 11. [11.2.11 set MouseEvent attributes from
 native](#set-mouseevent-attributes-from-native)
 12. [11.2.12 handle native mouse
 down](#handle-native-mouse-down)
 13. [11.2.13 handle native mouse
 up](#handle-native-mouse-up)
 14. [11.2.14 handle native mouse
 click](#handle-native-mouse-click)
 15. [11.2.15 send click event](#send-click-event)
 16. [11.2.16 handle native mouse double
 click](#handle-native-mouse-double-click)
 17. [11.2.17 handle native mouse
 move](#handle-native-mouse-move)
 18. [11.2.18 maybe show context
 menu](#maybe-show-context-menu)
 3. [11.3 Mouse Event Order](#mouse-event-order)
 4. [11.4 Mouse Event Types](#mouse-event-types)
 1. [11.4.1 [auxclick]](#auxclick)
 2. [11.4.2 [click]](#click)
 3. [11.4.3 [contextmenu]](#contextmenu)
 4. [11.4.4 [dblclick]](#dblclick)
 5. [11.4.5 [mousedown]](#mousedown)
 6. [11.4.6 [mouseenter]](#mouseenter)
 7. [11.4.7 [mouseleave]](#mouseleave)
 8. [11.4.8 [mousemove]](#mousemove)
 9. [11.4.9 [mouseout]](#mouseout)
 10. [11.4.10 [mouseover]](#mouseover)
 11. [11.4.11 [mouseup]](#mouseup)
14. [12. Wheel Events and interfaces](#events-wheelevents)
 1. [12.1 `WheelEvent` interface](#interface-wheelevent)
 2. [12.2 Wheel Event Types](#events-wheel-types)
 3. [12.3 [wheel]](#wheel)
 1. [12.3.1 cancelability of wheel
 events](#cancelability-of-wheel-events)
15. [13. Examples](#examples)
16. [14. Security and privacy
 considerations](#security-and-privacy-considerations)
17. [15. Glossary](#glossary)
18. [16. Legacy Event
 Initializers](#legacy-event-initializers)
 1. [16.1 Initializers for interface
 MouseEvent](#idl-interface-MouseEvent-initializers)
19. [A. Acknowledgments](#acknowledgments)
20. [B. Revision history](#revision-history)
21. [C. IDL Index](#idl-index)
22. [D. References](#references)
 1. [D.1 Normative references](#normative-references)
 2. [D.2 Informative references](#informative-references)

::: header-wrapper
## 1. Introduction

*This section is non-normative.*

Today, most \[[HTML](#bib-html "HTML Standard")\] content is used with and/or designed for mouse
input. Those that handle input in a custom manner typically code to
Mouse Events. Newer computing devices today, however, incorporate other
forms of input, including touchscreens and pen input. Event types have
been proposed for handling each of these forms of input individually.
However, that approach often incurs unnecessary duplication of logic and
event handling overhead when adding support for a new input type. This
often creates a compatibility problem when content is written with only
one device type in mind. Additionally, for compatibility with existing
mouse-based content, most [user
agents](https://infra.spec.whatwg.org/#user-agent) fire
Mouse Events for all input types. This makes it ambiguous whether a
Mouse Event represents an actual mouse device or is being produced from
another input type for compatibility, which makes it hard to code to
both device types simultaneously.

To reduce the cost of coding to multiple input types and also to help
with the above described ambiguity with Mouse Events, this specification
defines a more abstract form of input, called a
[pointer](#dfn-pointer). A pointer can be any point of contact on the screen
made by a mouse cursor, pen, touch (including multi-touch), or other
pointing input device. This model makes it easier to write sites and
applications that work well no matter what hardware the user has. For
scenarios when device-specific handling is desired, this specification
also defines properties for inspecting the device type which produced
the event. The primary goal is to provide a single set of events and
interfaces that allow for easier authoring for cross-device pointer
input while still allowing for device-specific handling only when
necessary for an augmented experience.

An additional key goal is to enable multi-threaded user agents to handle
[direct
manipulation](#dfn-direct-manipulation) actions for panning and zooming (for
instance, with a finger or stylus on a touchscreen), without blocking on
script execution.

While this specification defines a unified event model for a variety of
pointer inputs, this model does not cover other forms of input such as
keyboards or keyboard-like interfaces (for instance, a screen reader or
similar assistive technology running on a touchscreen-only device, which
allows users sequential navigation through focusable controls and
elements). While user agents might choose to also generate pointer
events in response to these interfaces, this scenario is not covered in
this specification.

In the first instance, authors are encouraged to provide equivalent
functionality for all forms of input by responding to high-level events
such as
[focus](https://html.spec.whatwg.org/multipage/indices.html#event-focus),
[blur](https://html.spec.whatwg.org/multipage/indices.html#event-blur)
and `click`. However, when using low-level events (such as Pointer
Events), authors are encouraged to ensure that all types of input are
supported. In the case of keyboards and keyboard-like interfaces, this
might require the addition of explicit keyboard event handling. See
[Keyboard Accessible](https://www.w3.org/TR/WCAG22/#keyboard-accessible)
\[[WCAG22](#bib-wcag22 "Web Content Accessibility Guidelines (WCAG) 2.2")\] for further details.

![[Figure 1](#figure_martini_glass) [A pointer is a
hardware-agnostic representation of input devices that can target a
specific coordinate (or set of coordinates) on a
screen.]](images/pointer.png)

The events for handling generic pointer input look a lot like those for
mouse: [`pointerdown`](#dfn-pointerdown),
[`pointermove`](#dfn-pointermove),
[`pointerup`](#dfn-pointerup),
[`pointerover`](#dfn-pointerover),
[`pointerout`](#dfn-pointerout), and so on. This facilitates easy
content migration from Mouse Events to Pointer Events. Pointer Events
provide all the usual properties present in Mouse Events (including
client coordinates, target element, button states) in addition to new
properties for other forms of input, such as pressure, contact geometry,
tilt. Authors can easily code to Pointer Events to share logic between
different input types where it makes sense, and customize for a
particular type of input only where necessary to get the best
experience.

While Pointer Events are sourced from a variety of input devices, they
are not defined as being generated from some other set of
device-specific events. While possible and encouraged for compatibility,
this spec does not require other device-specific events be supported
(such as mouse events or touch events). A user agent could support
pointer events without supporting any other device events. For
compatibility with content written to mouse-specific events, this
specification does provide an optional section describing how to
generate [compatibility mouse
events](#dfn-compatibility-mouse-events) based on pointer input from devices other
than a mouse.

This specification does not provide any advice on the expected behavior
of user agents that support both Touch Events (as defined in
\[[TOUCH-EVENTS](#bib-touch-events "Touch Events")\]) and Pointer Events. For more information on the
relationship between these two specifications, see the [Touch Events
Community Group](https://www.w3.org/community/touchevents/).

::: header-wrapper
## 2. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

The key words *MAY*, *MUST*, *MUST NOT*, *OPTIONAL*, and *SHOULD* in
this document are to be interpreted as described in [BCP
14](https://www.rfc-editor.org/info/bcp14)
\[[RFC2119](#bib-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels")\]
\[[RFC8174](#bib-rfc8174 "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words")\] when, and only when, they appear in all capitals,
as shown here.

::: header-wrapper
## 3. Pointer Events and interfaces

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent "The PointerEvent interface represents the state of a DOM event produced by a pointer such as the geometry of the contact point, the device type that generated the event, the amount of pressure that was applied on the contact surface, etc.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/PointerEvent](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/PointerEvent "The PointerEvent() constructor creates a new synthetic and untrusted PointerEvent object instance.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/pointerId](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/pointerId "The pointerId read-only property of the PointerEvent interface is an identifier assigned to a given pointer event. The identifier is unique, being different from the identifiers of all other active pointer events. Since the value may be randomly generated, it is not guaranteed to convey any particular meaning.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/width](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/width "The width read-only property of the PointerEvent interface represents the width of the pointer's contact geometry along the x-axis, measured in CSS pixels. Depending on the source of the pointer device (such as a finger), for a given pointer, each event may produce a different value.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/height](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/height "The height read-only property of the PointerEvent interface represents the height of the pointer's contact geometry, along the y-axis (in CSS pixels). Depending on the source of the pointer device (for example a finger), for a given pointer, each event may produce a different value.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/pressure](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/pressure "The pressure read-only property of the PointerEvent interface indicates the normalized pressure of the pointer input.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/tangentialPressure](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/tangentialPressure "The tangentialPressure read-only property of the PointerEvent interface represents the normalized tangential pressure of the pointer input (also known as barrel pressure or cylinder stress).")

This feature is in all major engines.

 ------------------ -----
 Chrome 57+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/tiltX](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/tiltX "The tiltX read-only property of the PointerEvent interface is the angle (in degrees) between the Y-Z plane of the pointer and the screen. This property is typically only useful for a pen/stylus pointer type.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/tiltY](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/tiltY "The tiltY read-only property of the PointerEvent interface is the angle (in degrees) between the X-Z plane of the pointer and the screen. This property is typically only useful for a pen/stylus pointer type.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/twist](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/twist "The twist read-only property of the PointerEvent interface represents the clockwise rotation of the pointer (e.g., pen stylus) around its major axis, in degrees.")

This feature is in all major engines.

 ------------------ -----
 Chrome 57+
 Chrome Android ?
 Edge 18+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/pointerType](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/pointerType "The pointerType read-only property of the PointerEvent interface indicates the device type (mouse, pen, or touch) that caused a given pointer event.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[PointerEvent/isPrimary](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/isPrimary "The isPrimary read-only property of the PointerEvent interface indicates whether or not the pointer device that created the event is the primary pointer. It returns true if the pointer that caused the event to be fired is the primary one and returns false otherwise.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[ ]{aria-hidden="true"}

[PointerEvent/getCoalescedEvents](https://developer.mozilla.org/en-US/docs/Web/API/PointerEvent/getCoalescedEvents "The getCoalescedEvents() method of the PointerEvent interface returns a sequence of PointerEvent instances that were coalesced (merged) into a single pointermove or pointerrawupdate event. Instead of a stream of many pointermove events, user agents coalesce multiple updates into a single event. This helps with performance as the user agent has less event handling to perform, but there is a reduction in the granularity and accuracy when tracking, especially with fast and large movements.")

 ------------------ -----
 Chrome 58+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

::: header-wrapper
### 3.1 `PointerEvent` interface

```
WebIDLdictionary PointerEventInit : MouseEventInit {
 long pointerId = 0;
 double width = 1;
 double height = 1;
 float pressure = 0;
 float tangentialPressure = 0;
 long tiltX;
 long tiltY;
 long twist = 0;
 double altitudeAngle;
 double azimuthAngle;
 DOMString pointerType = "";
 boolean isPrimary = false;
 long persistentDeviceId = 0;
 sequence<PointerEvent> coalescedEvents = ;
 sequence<PointerEvent> predictedEvents = ;
};

[Exposed=Window]
interface PointerEvent : MouseEvent {
 constructor(DOMString type, optional PointerEventInit eventInitDict = );
 readonly attribute long pointerId;
 readonly attribute double width;
 readonly attribute double height;
 readonly attribute float pressure;
 readonly attribute float tangentialPressure;
 readonly attribute long tiltX;
 readonly attribute long tiltY;
 readonly attribute long twist;
 readonly attribute double altitudeAngle;
 readonly attribute double azimuthAngle;
 readonly attribute DOMString pointerType;
 readonly attribute boolean isPrimary;
 readonly attribute long persistentDeviceId;
 [SecureContext] sequence<PointerEvent> getCoalescedEvents();
 sequence<PointerEvent> getPredictedEvents();
};
```

[`pointerId`]

: A unique identifier for the pointer causing the event. [user
 agents](https://infra.spec.whatwg.org/#user-agent)
 *MAY* reserve a generic
 [`pointerId`](#dom-pointerevent-pointerid) value of `0` or `1` for
 the primary mouse pointer. The
 [`pointerId`](#dom-pointerevent-pointerid) value of `-1` *MUST* be
 reserved and used to indicate events that were generated by
 something other than a pointing device. For any other pointers, user
 agents are free to implement different strategies and approaches in
 how they assign a
 [`pointerId`](#dom-pointerevent-pointerid) value. However, all
 [active pointers](#dfn-active-pointer) in the [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context)
 (as defined by \[[HTML](#bib-html "HTML Standard")\]) must be unique, and the identifier *MUST NOT*
 be influenced by any other top-level browsing context (i.e. one
 top-level browsing context cannot assume that the
 [`pointerId`](#dom-pointerevent-pointerid) of a pointer will be
 the same when the pointer moves outside of the browsing context and
 into another top-level browsing context).

 The [user
 agent](https://infra.spec.whatwg.org/#user-agent)
 *MAY* recycle previously retired values for
 [`pointerId`](#dom-pointerevent-pointerid) from previous active
 pointers, or it *MAY* always reuse the same
 [`pointerId`](#dom-pointerevent-pointerid) for a particular
 pointing device (for instance, to uniquely identify particular
 pen/stylus inputs from a specific user in a multi-user collaborative
 application). However, in the latter case, to minimize the chance of
 fingerprinting and tracking across different pages or domains, the
 [`pointerId`](#dom-pointerevent-pointerid) *MUST* only be
 associated explicitly with that particular pointing device for the
 lifetime of the page / session, and a new randomized
 [`pointerId`](#dom-pointerevent-pointerid) *MUST* be chosen the
 next time that particular pointing device is used again in a new
 session.

 :::::
 :::
 Note
 :::

 :::
 The
 [`pointerId`](#dom-pointerevent-pointerid) selection algorithm is
 implementation specific. Authors cannot assume values convey any
 particular meaning other than an identifier for the pointer that is
 unique from all other active pointers. As an example, user agents
 may simply assign a number, starting from `0`, to any active
 pointers, in the order that they become active --- but these values
 are not guaranteed to be monotonically increasing. As the reuse of
 the same
 [`pointerId`](#dom-pointerevent-pointerid) for a particular
 pointing device is left up to individual implementations, authors
 are strongly discouraged from relying on it, and to refer to
 [`persistentDeviceId`](#dom-pointerevent-persistentdeviceid) instead.
 :::
 :::::

[`width`]

: The width (magnitude on the X axis), in CSS pixels (see
 \[[CSS21](#bib-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\]), of the [contact
 geometry](#dfn-contact-geometry) of the pointer. This value *MAY* be
 updated on each event for a given pointer. For inputs that typically
 lack contact geometry (such as a traditional mouse), and in cases
 where the actual geometry of the input is not detected by the
 hardware, the [user
 agent](https://infra.spec.whatwg.org/#user-agent)
 *MUST* return a default value of `1`.

[`height`]

: The height (magnitude on the Y axis), in CSS pixels (see
 \[[CSS21](#bib-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\]), of the [contact
 geometry](#dfn-contact-geometry) of the pointer. This value *MAY* be
 updated on each event for a given pointer. For inputs that typically
 lack contact geometry (such as a traditional mouse), and in cases
 where the actual geometry of the input is not detected by the
 hardware, the [user
 agent](https://infra.spec.whatwg.org/#user-agent)
 *MUST* return a default value of `1`.

[`pressure`]

: The normalized pressure of the pointer input in the range of
 `[0,1]`, where `0` and `1` represent the minimum and maximum
 pressure the hardware is capable of detecting, respectively. For
 hardware and platforms that do not support pressure, the value
 *MUST* be `0.5` when in the [active buttons
 state](#dfn-active-buttons-state) and `0` otherwise.

[`tangentialPressure`]

: The normalized tangential pressure (also known as barrel pressure),
 typically set by an additional control (e.g. a finger wheel on an
 airbrush stylus), of the pointer input in the range of `[-1,1]`,
 where `0` is the neutral position of the control. Note that some
 hardware may only support positive values in the range of `[0,1]`.
 For hardware and platforms that do not support tangential pressure,
 the value *MUST* be `0`.

 :::::
 :::
 Note
 :::

 :::
 Despite the property\'s name, in practice the hardware
 controls/sensors that generate the values for this property may not
 necessarily be pressure sensitive. As an example, in most cases the
 finger wheel on most airbrush/painting stylus implementations can be
 freely set, rather than requiring the user to apply a constant
 pressure on the wheel to prevent it from returning to the zero
 position.
 :::
 :::::

[`tiltX`]

: The plane angle (in degrees, in the range of `[-90,90]`) between the
 Y-Z plane and the plane containing both the transducer (e.g.
 pen/stylus) axis and the Y axis. A positive `tiltX` is to the right,
 in the direction of increasing X values. `tiltX` can be used along
 with `tiltY` to represent the tilt away from the normal of a
 transducer with the digitizer. For hardware and platforms that do
 not report tilt or angle, the value *MUST* be `0`.

 ![[Figure 2](#figure_tiltX) [Positive
 `tiltX`.]](images/tiltX.png)

[`tiltY`]

: The plane angle (in degrees, in the range of `[-90,90]`) between the
 X-Z plane and the plane containing both the transducer (e.g.
 pen/stylus) axis and the X axis. A positive `tiltY` is towards the
 user, in the direction of increasing Y values. `tiltY` can be used
 along with `tiltX` to represent the tilt away from the normal of a
 transducer with the digitizer. For hardware and platforms that do
 not report tilt or angle, the value *MUST* be `0`.

 ![[Figure 3](#figure_tiltY) [Positive
 `tiltY`.]](images/tiltY.png)

[`twist`]

: The clockwise rotation (in degrees, in the range of `[0,359]`) of a
 transducer (e.g. pen/stylus) around its own major axis. For hardware
 and platforms that do not report twist, the value *MUST* be `0`.

[`altitudeAngle`]

: The altitude (in radians) of the transducer (e.g. pen/stylus), in
 the range `[0,π/2]` --- where `0` is parallel to the surface (X-Y
 plane), and `π/2` is perpendicular to the surface. For hardware and
 platforms that do not report tilt or angle, the value *MUST* be
 `π/2`.

 :::::
 :::
 Note
 :::

 :::
 The default value defined here for `altitudeAngle` is `π/2`, which
 positions the transducer as being perpendicular to the surface. This
 differs from the [Touch Events - Level
 2](https://w3c.github.io/touch-events/) specification\'s definition
 for the `altitudeAngle` property, which has a default value of `0`.
 :::
 :::::

 ![[Figure 4](#figure_altitudeAngle) [Example
 `altitudeAngle` of `π/4` (45 degrees from the X-Y
 plane).]](images/altitudeAngle.png)

[`azimuthAngle`]

: The azimuth angle (in radians) of the transducer (e.g. pen/stylus),
 in the range `[0, 2π]` --- where `0` represents a transducer whose
 cap is pointing in the direction of increasing X values (point to
 \"3 o\'clock\" if looking straight down) on the X-Y plane, and the
 values progressively increase when going clockwise (`π/2` at \"6
 o\'clock\", `π` at \"9 o\'clock\", `3π/2` at \"12 o\'clock\"). When
 the transducer is perfectly perpendicular to the surface
 (`altitudeAngle` of `π/2`), the value *MUST* be `0`. For hardware
 and platforms that do not report tilt or angle, the value *MUST* be
 `0`.

 ![[Figure 5](#figure_azimuthAngle) [Example
 `azimuthAngle` of `π/6` (\"4
 o\'clock\").]](images/azimuthAngle.png)

[`pointerType`]

: Indicates the device type that caused the event (such as mouse, pen,
 touch). If the user agent is to [fire a pointer
 event](#dfn-fire-a-pointer-event) for a mouse, pen/stylus, or touch
 input device, then the value of `pointerType` *MUST* be according to
 the following table:

 Pointer Device Type `pointerType` Value
 --------------------- ---------------------
 Mouse `mouse`
 Pen / stylus `pen`
 Touch contact `touch`

 If the device type cannot be detected by the user agent, then the
 value *MUST* be an empty string. If the user agent supports pointer
 device types other than those listed above, the value of
 `pointerType` *SHOULD* be vendor prefixed to avoid conflicting names
 for different types of devices. Future specifications *MAY* provide
 additional normative values for other device types.

 :::::
 :::
 Note
 :::

 :::
 See [Example 2](#example_2 "examples") for a basic demonstration of
 how the `pointerType` can be used. Also note that developers should
 include some form of default handling to cover user agents that may
 have implemented their own custom `pointerType` values and for
 situations where `pointerType` is simply an empty string.
 :::
 :::::

[`isPrimary`]

: Indicates if the pointer represents the [primary
 pointer](#dfn-primary-pointer) of this pointer type.

[`persistentDeviceId`]

: A unique identifier for the pointing device. If the hardware
 supports multiple pointers, pointer events generated from pointing
 devices *MUST* only get a `persistentDeviceId` if those pointers are
 uniquely identifiable over the session. If the pointer is uniquely
 identifiable, the assigned `persistentDeviceId` to that pointing
 device will remain constant for the remainder of the session. The
 `persistentDeviceId` value of `0` *MUST* be reserved and used to
 indicate events whose generating device could not be identified.
 Like
 [pointerId](#dom-pointerevent-pointerid),
 to minimize the chance of fingerprinting and tracking across
 different pages or domains, the `persistentDeviceId` *MUST* only be
 associated explicitly with that particular pointing device for the
 lifetime of the page / session, and a new randomized
 `persistentDeviceId` *MUST* be chosen the next time that particular
 pointing device is used again in a new session.

 :::::
 :::
 Note
 :::

 :::
 Due to digitizer and pointing device hardware constraints, a
 `persistentDeviceId` is not guaranteed to be available for all
 pointer events from a pointing device. For example, the device may
 not report its hardware id to the digitizer in time for
 `pointerdown` to have a `persistentDeviceId`. In such a case, the
 `persistentDeviceId` may initially be `0` and change to a valid
 value.
 :::
 :::::

[`getCoalescedEvents()`]

: A method that returns the list of [coalesced
 events](#dfn-coalesced-events).

[`getPredictedEvents()`]

: A method that returns the list of [predicted
 events](#dfn-predicted-events).

The [`PointerEventInit`] dictionary is used by
the [`PointerEvent`](#dom-pointerevent) interface\'s constructor
to provide a mechanism by which to construct untrusted (synthetic)
pointer events. It inherits from the
[`MouseEventInit`](#dom-mouseeventinit) dictionary. See the
[examples](#examples "examples") for sample code demonstrating how to
fire an untrusted pointer event.

The [event constructing
steps](https://dom.spec.whatwg.org/#concept-event-constructor-ext)
for [`PointerEvent`] clones
[`PointerEventInit`](#dom-pointereventinit)\'s
[`coalescedEvents`](#dom-pointereventinit-coalescedevents) to [coalesced events
list](#dfn-coalesced-events-list) and clones
[`PointerEventInit`](#dom-pointereventinit)\'s
[`predictedEvents`](#dom-pointereventinit-predictedevents) to [predicted events
list](#dfn-predicted-events-list).

The `PointerEvent` interface inherits from
[`MouseEvent`](#dom-mouseevent). Also note the proposed extension in
[CSSOM View
Module](https://www.w3.org/TR/cssom-view-1/){matched-text="[[[CSSOM-VIEW]]]"},
which changes the various coordinate properties from `long` to `double`
to allow for fractional coordinates. For user agents that already
implement this proposed extension for
[`PointerEvent`](#dom-pointerevent), but *not* for regular
[`MouseEvent`](#dom-mouseevent), there are additional requirements when
it comes to the [`click`, `auxclick`, and
`contextmenu`](#dfn-click-auxclick-and-contextmenu) events.

::: header-wrapper
#### 3.1.1 Button states

::: header-wrapper
##### 3.1.1.1 [Chorded button interactions]

Some pointer devices, such as mouse or pen, support multiple buttons. In
the Mouse Event model, each button press produces a `mousedown` and
`mouseup` event. To better abstract this hardware difference and
simplify cross-device input authoring, Pointer Events do not fire
overlapping [`pointerdown`](#dfn-pointerdown) and
[`pointerup`](#dfn-pointerup) events for chorded button presses
(depressing an additional button while another button on the pointer
device is already depressed).

Instead, chorded button presses can be detected by inspecting changes to
the `button` and `buttons` properties. The `button` and `buttons`
properties are inherited from the
[`MouseEvent`](#dom-mouseevent) interface, but with a change in
semantics and values, as outlined in the following sections.

The modifications to the `button` and `buttons` properties apply only to
pointer events. However for `click`, `auxclick` and `contextmenu` the
value of `button` and `buttons` *MUST* follow the Mouse Event model, as
is the case for [compatibility mouse
events](#dfn-compatibility-mouse-events) .

::: header-wrapper
##### 3.1.1.2 The `button` property

To identify button state transitions in any pointer event (and not just
[`pointerdown`](#dfn-pointerdown) and
[`pointerup`](#dfn-pointerup)), the `button` property indicates the
device button whose state change fired the event.

 -----------------------------------------------------------------------
 Device Button Changes `button`
 ----------------------------------- -----------------------------------
 Neither buttons nor touch/pen -1
 contact changed since last event

 Left Mouse,\ 0
 Touch contact,\
 Pen contact

 Middle Mouse 1

 Right Mouse,\ 2
 Pen barrel button

 X1 (back) Mouse 3

 X2 (forward) Mouse 4

 Pen eraser button 5
 -----------------------------------------------------------------------

During a mouse drag, the value of the `button` property in a
[`pointermove`](#dfn-pointermove) event will be different
from that in a `mousemove` event. For example, while moving the mouse
with the right button pressed, the
[`pointermove`](#dfn-pointermove) events will have the
`button` value -1, but the `mousemove` events will have the `button`
value 2.

::: header-wrapper
##### 3.1.1.3 The `buttons` property

The `buttons` property gives the current state of the device buttons as
a bitmask (same as in `MouseEvent`, but with an expanded set of possible
values).

 -----------------------------------------------------------------------
 Current state of device buttons `buttons`
 ----------------------------------- -----------------------------------
 **Mouse moved with no buttons 0
 pressed**,\
 Pen moved while hovering with no
 buttons pressed

 Left Mouse,\ 1
 Touch contact,\
 Pen contact

 Middle Mouse 4

 Right Mouse,\ 2
 Pen barrel button

 X1 (back) Mouse 8

 X2 (forward) Mouse 16

 Pen eraser button 32
 -----------------------------------------------------------------------

::: header-wrapper
#### 3.1.2 The [primary pointer]

In a multi-pointer (e.g. multi-touch) scenario, the `isPrimary` property
is used to identify a master pointer amongst the set of [active
pointers](#dfn-active-pointer) for each pointer type.

- At any given time, there can only ever be at most one primary pointer
 for each pointer type.
- The first pointer to become active for a particular pointer type (e.g.
 the first finger to touch the screen in a multi-touch interaction)
 becomes the primary pointer for that pointer type.
- Only a primary pointer will produce [compatibility mouse
 events](#dfn-compatibility-mouse-events). In the case where there are multiple
 [primary
 pointers](#dfn-primary-pointer), these pointers will all produce
 [compatibility mouse
 events](#dfn-compatibility-mouse-events).

Authors who desire single-pointer interaction can achieve this by
ignoring non-primary pointers (however, see the note below on [multiple
primary pointers](#multiple-primary-pointers)).

When two or more pointer device types are being used concurrently,
multiple pointers (one for each `pointerType`) are considered primary.
For example, a touch contact and a mouse cursor moved simultaneously
will produce pointers that are both considered primary.

Some devices, operating systems and user agents may ignore the
concurrent use of more than one type of pointer input to avoid
accidental interactions. For instance, devices that support both touch
and pen interactions may ignore touch inputs while the pen is actively
being used, to allow users to rest their hand on the touchscreen while
using the pen (a feature commonly referred to as \"palm rejection\").
Currently, it is not possible for authors to suppress this behavior.

In some cases, it is possible for the user agent to fire pointer events
in which no pointer is marked as a primary pointer. For instance, when
there are multiple active pointers of a particular type, like a
multi-touch interaction, and the primary pointer is removed (e.g. it
leaves the screen), there may end up being no primary pointers. Also on
platforms where the primary pointer is determined using all active
pointers of the same type on the device (including those targeted at an
application other than the user agent), if the first (primary) pointer
is outside of the user agent and other (non-primary) pointers targeted
inside the user agent, then the [user
agent](https://infra.spec.whatwg.org/#user-agent) *MAY*
fire pointer events for the other pointers with a value of `false` for
`isPrimary`.

Current operating systems and user agents don\'t usually have a concept
of multiple mouse inputs. When more than one mouse device is present
(for instance, on a laptop with both a trackpad and an external mouse),
all mouse devices are generally treated as a single device --- movements
on any of the devices are translated to movement of a single mouse
pointer, and there is no distinction between button presses on different
mouse devices. For this reason, there will usually only be a single
mouse pointer, and that pointer will be primary.

::: header-wrapper
#### 3.1.3 Firing events using the `PointerEvent` interface

To [fire a pointer event] named `e` means to
[fire an
event](https://dom.spec.whatwg.org/#concept-event-fire)
named `e` using
[`PointerEvent`](#dom-pointerevent) whose attributes are set as defined in
[`PointerEvent`](#dom-pointerevent) Interface and
[Attributes and Default
Actions](#dfn-attributes-and-default-actions).

If the event is not a
[`gotpointercapture`](#dfn-gotpointercapture),
[`lostpointercapture`](#dfn-lostpointercapture), `click`,
`auxclick` or `contextmenu` event, run the [process pending pointer
capture](#dfn-process-pending-pointer-capture) steps for this `PointerEvent`.

[Determine the target] at which the event is fired as
follows:

- If the [pointer capture target
 override](#dfn-pointer-capture-target-override) has been set for the pointer, set the
 target to [pointer capture target
 override](#dfn-pointer-capture-target-override) object.
- Otherwise, set the target to the object returned by [hit
 test](#dfn-hit-test).

Let `targetDocument` be target\'s [node
document](https://dom.spec.whatwg.org/#concept-node-document)
\[[DOM](#bib-dom "DOM Standard")\].

If the event is
[`pointerdown`](#dfn-pointerdown),
[`pointermove`](#dfn-pointermove), or
[`pointerup`](#dfn-pointerup), set [active
document](#dfn-active-document) for the event\'s
[`pointerId`](#dom-pointerevent-pointerid) to `targetDocument`.

If the event is
[`pointerdown`](#dfn-pointerdown), the associated device is
a direct manipulation device, and the target is an
[`Element`](https://dom.spec.whatwg.org/#element), then [set pointer
capture](#dfn-set-pointer-capture) for this
[`pointerId`](#dom-pointerevent-pointerid) to the target element as described in
[implicit pointer
capture](#dfn-implicit-pointer-capture).

Before firing this event, the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* treat the target as if the pointing device has moved over it
from the `previousTarget` for the purpose of [ensuring event
ordering](#mouse-event-order). If the `needsOverEvent` flag
is set, a [`pointerover`](#dfn-pointerover) event is needed even if
the target element is the same.

Fire the event to the determined target.

Save the determined target as the `previousTarget` for the
given pointer, and reset the `needsOverEvent` flag to
`false`. If the `previousTarget` at any point will no longer
be [connected](https://dom.spec.whatwg.org/#connected)
\[[DOM](#bib-dom "DOM Standard")\], update
the `previousTarget` to the nearest still
[connected](https://dom.spec.whatwg.org/#connected)
\[[DOM](#bib-dom "DOM Standard")\] parent
following the event path corresponding to dispatching events to the
`previousTarget`, and set the `needsOverEvent`
flag to `true`.

Using the [pointer capture target
override](#dfn-pointer-capture-target-override) as the target instead of the normal
hit-test result may fire some boundary events. This is the same as the
pointer leaving its previous target and entering this new capturing
target. When the capture is released, the same scenario may happen, as
the pointer is leaving the capturing target and entering the hit-test
target.

::: header-wrapper
##### 3.1.3.1 [Attributes and default actions]

The `bubbles` and `cancelable` properties and the default actions for
the event types defined in this specification appear in the following
table. Details of each of these event types are provided in [Pointer
Event
types](#dfn-pointer-event-types).

 ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Event Type Bubbles Cancelable Default Action
 ----------------------------------------------------------------------------------- ----------------- ----------------- ------------------------------------------------------------------------------------
 [`pointerover`](#dfn-pointerover)

 [`pointerenter`](#dfn-pointerenter)

 [`pointerdown`](#dfn-pointerdown) Canceling this event also prevents subsequent firing of [compatibility mouse
 events](#dfn-compatibility-mouse-events).

 [`pointermove`](#dfn-pointermove)

 [`pointerrawupdate`](#dfn-pointerrawupdate)

 [`pointerup`](#dfn-pointerup)

 [`pointercancel`](#dfn-pointercancel)

 [`pointerout`](#dfn-pointerout)

 [`pointerleave`](#dfn-pointerleave)

 [`gotpointercapture`](#dfn-gotpointercapture)

 [`lostpointercapture`](#dfn-lostpointercapture)
 ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Viewport manipulations (panning and zooming) --- generally, as a result
of a [direct
manipulation](#dfn-direct-manipulation) interaction --- are intentionally NOT a
default action of pointer events, meaning that these behaviors (e.g.
panning a page as a result of moving a finger on a touchscreen) cannot
be suppressed by canceling a pointer event. Authors must instead use
`touch-action` to explicitly [declare the direct manipulation
behavior](#dfn-direct-manipulation-behavior) for a region of the document. Removing
this dependency on the cancelation of events facilitates performance
optimizations by the user agent.

For [`pointerenter`](#dfn-pointerenter) and
[`pointerleave`](#dfn-pointerleave) events, the
[`composed`](https://dom.spec.whatwg.org/#dom-eventinit-composed)
\[[DOM](#bib-dom "DOM Standard")\] attribute
*SHOULD* be `false`; for all other pointer events in the table above,
the attribute *SHOULD* be `true`.

For all pointer events in the table above, the
[`detail`](https://www.w3.org/TR/uievents/#dom-uievent-detail)
attribute *SHOULD* be 0.

Many user agents expose non-standard attributes `fromElement` and
`toElement` in MouseEvents to support legacy content. We encourage those
user agents to set the values of those (inherited) attributes in
PointerEvents to `null` to transition authors to the use of standardized
alternates (`target` and `relatedTarget`).

Similar to `MouseEvent`
[`relatedTarget`](#dom-mouseeventinit-relatedtarget), the `relatedTarget` should be initialized
to the element whose bounds the pointer just left (in the case of a
[`pointerover`](#dfn-pointerover) or `pointerenter` event)
or the element whose bounds the pointer is entering (in the case of a
[`pointerout`](#dfn-pointerout) or
[`pointerleave`](#dfn-pointerleave)). For other pointer
events, this value will default to null. Note that when an element
receives the pointer capture all the following events for that pointer
are considered to be inside the boundary of the capturing element.

For
[`gotpointercapture`](#dfn-gotpointercapture) and
[`lostpointercapture`](#dfn-lostpointercapture) events, all the
attributes except the ones defined in the table above should be the same
as the Pointer Event that caused the user agent to run the [process
pending pointer
capture](#dfn-process-pending-pointer-capture) steps and fire the
[`gotpointercapture`](#dfn-gotpointercapture) and
[`lostpointercapture`](#dfn-lostpointercapture) events.

::: header-wrapper
##### 3.1.3.2 [Process pending pointer capture]

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* run the following steps when [implicitly releasing pointer
capture](#dfn-implicitly-release-the-pointer-capture) as well as when firing Pointer Events that
are not
[`gotpointercapture`](#dfn-gotpointercapture) or
[`lostpointercapture`](#dfn-lostpointercapture).

1. If the [pointer capture target
 override](#dfn-pointer-capture-target-override) for this pointer is set and is not
 equal to the [pending pointer capture target
 override](#dfn-pending-pointer-capture-target-override), then fire a pointer event named
 [`lostpointercapture`](#dfn-lostpointercapture) at the
 [pointer capture target
 override](#dfn-pointer-capture-target-override) node.
2. If the [pending pointer capture target
 override](#dfn-pending-pointer-capture-target-override) for this pointer is set and is not
 equal to the [pointer capture target
 override](#dfn-pointer-capture-target-override), then fire a pointer event named
 [`gotpointercapture`](#dfn-gotpointercapture) at the [pending
 pointer capture target
 override](#dfn-pending-pointer-capture-target-override).
3. Set the [pointer capture target
 override] to the [pending pointer
 capture target
 override](#dfn-pending-pointer-capture-target-override), if set. Otherwise, clear the [pointer
 capture target
 override](#dfn-pointer-capture-target-override).

As defined in the section for [`click`, `auxclick`, and
`contextmenu`](#dfn-click-auxclick-and-contextmenu) events, even after the
[`lostpointercapture`](#dfn-lostpointercapture) event has been
dispatched, the corresponding `click`, `auxclick` or `contextmenu`
event, if any, would still be dispatched to the capturing target.

::: header-wrapper
##### 3.1.3.3 Suppressing a pointer event stream

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [suppress a pointer event
stream] when it detects that the web page
is unlikely to continue to receive pointer events with a specific
[`pointerId`](#dom-pointerevent-pointerid). Any of the following scenarios satisfy
this condition (there *MAY* be additional scenarios):

- The user agent has opened a modal dialog or menu.
- A pointer input device is physically disconnected, or a hoverable
 pointer input device (e.g. a hoverable pen/stylus) has left the hover
 range detectable by the digitizer.
- The pointer is subsequently used by the user agent to manipulate the
 page viewport (e.g. panning or zooming). See the section on
 [`touch-action`](#dfn-touch-action) CSS property for details.

 :::::
 :::
 Note
 :::

 :::
 User agents can trigger panning or zooming through multiple pointer
 types (such as touch and pen), and therefore the start of a pan or
 zoom action may result in the suppression of various pointers,
 including pointers with different pointer types.
 :::
 :::::
- As part of the drag operation initiation algorithm as defined in the
 [drag and drop processing
 model](https://html.spec.whatwg.org/multipage/#drag-and-drop-processing-model)
 \[[HTML](#bib-html "HTML Standard")\], for
 the pointer that caused the drag operation.

Other scenarios in which the [user
agent](https://infra.spec.whatwg.org/#user-agent) *MAY*
[suppress a pointer event
stream](#dfn-suppress-a-pointer-event-stream) include:

- A device\'s screen orientation is changed while a pointer is active.
- The user attempts to interact using more simultaneous pointer inputs
 than the device supports.
- The user agent interprets the input as accidental (for example, the
 hardware supports palm rejection).

Methods for detecting any of these scenarios are out of scope for this
specification.

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* run the following steps to [suppress a pointer event
stream](#dfn-suppress-a-pointer-event-stream):

- Fire a
 [`pointercancel`](#dfn-pointercancel) event.
- Fire a [`pointerout`](#dfn-pointerout) event.
- Fire a [`pointerleave`](#dfn-pointerleave) event.
- [Implicitly release the pointer
 capture](#dfn-implicitly-release-the-pointer-capture) if the pointer is currently captured.

::: header-wrapper
#### 3.1.4 [Boundary events caused by layout changes]

A pointing device that moved relative to the screen surface or underwent
some change in any of its properties fires various events as defined in
[Pointer Event
types](#dfn-pointer-event-types). For a stationary pointing device (that
neither moved relative to the screen surface nor underwent any change in
any properties), the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* fire certain boundary events after a layout change that affected
the [hit test](#dfn-hit-test) target for the pointer, see
[`pointerover`](#dfn-pointerover),
[`pointerenter`](#dfn-pointerenter),
[`pointerout`](#dfn-pointerout) and
[`pointerleave`](#dfn-pointerleave) for details. The [user
agent](https://infra.spec.whatwg.org/#user-agent) *MAY*
delay the firing of these boundary events because of performance reasons
(e.g. to avoid too many hit-tests or layout changes caused by boundary
event listeners).

A stationary pointing device (that neither moved relative to the screen
surface nor underwent any change in any properties) never fires a
[`pointermove`](#dfn-pointermove) event.

::: header-wrapper
#### 3.1.5 Converting between `tiltX` / `tiltY` and `altitudeAngle` / `azimuthAngle`

Pointer Events include two complementary sets of attributes to express
the orientation of a transducer relative to the X-Y plane: `tiltX` /
`tiltY` (introduced in the original Pointer Events specification), and
`azimuthAngle` / `altitudeAngle` (adopted from the [Touch Events - Level
2](https://w3c.github.io/touch-events/) specification).

Depending on the specific hardware and platform, user agents will likely
only receive one set of values for the transducer orientation relative
to the screen plane --- either `tiltX` / `tiltY` or `altitudeAngle` /
`azimuthAngle`. User agents *MUST* use the following algorithm for
converting these values.

When the user agent calculates `tiltX` / `tiltY` from `azimuthAngle` /
`altitudeAngle` it *SHOULD* round the final integer values using
[Math.round](https://tc39.es/ecma262/multipage/#sec-math.round)
\[[ECMASCRIPT](#bib-ecmascript "ECMAScript Language Specification")\] rules.

[Example 1](#example_6)[: Converting between tiltX/tiltY and
altitudeAngle/azimuthAngle]

 /* Converting between tiltX/tiltY and altitudeAngle/azimuthAngle */

 function spherical2tilt(altitudeAngle, azimuthAngle) {
 const radToDeg = 180/Math.PI;

 let tiltXrad = 0;
 let tiltYrad = 0;

 if (altitudeAngle == 0) {
 // the pen is in the X-Y plane
 if (azimuthAngle == 0 || azimuthAngle == 2*Math.PI) {
 // pen is on positive X axis
 tiltXrad = Math.PI/2;
 }
 if (azimuthAngle == Math.PI/2) {
 // pen is on positive Y axis
 tiltYrad = Math.PI/2;
 }
 if (azimuthAngle == Math.PI) {
 // pen is on negative X axis
 tiltXrad = -Math.PI/2;
 }
 if (azimuthAngle == 3*Math.PI/2) {
 // pen is on negative Y axis
 tiltYrad = -Math.PI/2;
 }
 if (azimuthAngle>0 && azimuthAngle<Math.PI/2) {
 tiltXrad = Math.PI/2;
 tiltYrad = Math.PI/2;
 }
 if (azimuthAngle>Math.PI/2 && azimuthAngle<Math.PI) {
 tiltXrad = -Math.PI/2;
 tiltYrad = Math.PI/2;
 }
 if (azimuthAngle>Math.PI && azimuthAngle<3*Math.PI/2) {
 tiltXrad = -Math.PI/2;
 tiltYrad = -Math.PI/2;
 }
 if (azimuthAngle>3*Math.PI/2 && azimuthAngle<2*Math.PI) {
 tiltXrad = Math.PI/2;
 tiltYrad = -Math.PI/2;
 }
 }

 if (altitudeAngle != 0) {
 const tanAlt = Math.tan(altitudeAngle);

 tiltXrad = Math.atan(Math.cos(azimuthAngle) / tanAlt);
 tiltYrad = Math.atan(Math.sin(azimuthAngle) / tanAlt);
 }

 return {"tiltX":tiltXrad*radToDeg, "tiltY":tiltYrad*radToDeg};
 }

 function tilt2spherical(tiltX, tiltY) {
 const tiltXrad = tiltX * Math.PI/180;
 const tiltYrad = tiltY * Math.PI/180;

 // calculate azimuth angle
 let azimuthAngle = 0;

 if (tiltX == 0) {
 if (tiltY > 0) {
 azimuthAngle = Math.PI/2;
 }
 else if (tiltY < 0) {
 azimuthAngle = 3*Math.PI/2;
 }
 } else if (tiltY == 0) {
 if (tiltX < 0) {
 azimuthAngle = Math.PI;
 }
 } else if (Math.abs(tiltX) == 90 || Math.abs(tiltY) == 90) {
 // not enough information to calculate azimuth
 azimuthAngle = 0;
 } else {
 // Non-boundary case: neither tiltX nor tiltY is equal to 0 or +-90
 const tanX = Math.tan(tiltXrad);
 const tanY = Math.tan(tiltYrad);

 azimuthAngle = Math.atan2(tanY, tanX);
 if (azimuthAngle < 0) {
 azimuthAngle += 2*Math.PI;
 }
 }

 // calculate altitude angle
 let altitudeAngle = 0;

 if (Math.abs(tiltX) == 90 || Math.abs(tiltY) == 90) {
 altitudeAngle = 0
 } else if (tiltX == 0) {
 altitudeAngle = Math.PI/2 - Math.abs(tiltYrad);
 } else if (tiltY == 0) {
 altitudeAngle = Math.PI/2 - Math.abs(tiltXrad);
 } else {
 // Non-boundary case: neither tiltX nor tiltY is equal to 0 or +-90
 altitudeAngle = Math.atan(1.0/Math.sqrt(Math.pow(Math.tan(tiltXrad),2) + Math.pow(Math.tan(tiltYrad),2)));
 }

 return {"altitudeAngle":altitudeAngle, "azimuthAngle":azimuthAngle};
 }

::: header-wrapper
### 3.2 PointerEvent Algorithms

::: header-wrapper
#### 3.2.1 initialize a [`PointerEvent`]
To [initialize a PointerEvent]
with `event`, `eventType` and
`eventTarget`, `bubbles`, and
`cancelable`, run the following steps:

1. [Initialize a
 MouseEvent](#dfn-initialize-a-mouseevent) with `event`,
 `eventType` and `eventTarget`,
 `bubbles` and `cancelable`
2. Initialize all other attributes to default
 [`PointerEvent`](#dom-pointerevent) values.

::: header-wrapper
#### 3.2.2 create a [`PointerEvent`]
To [create a `PointerEvent`] with
`eventType` and `eventTarget`,
`bubbles`, and `cancelable`, run the following
steps:

1. Let `event` be the result of [creating an
 event](https://dom.spec.whatwg.org/#concept-event-create)
 using
 [`PointerEvent`](#dom-pointerevent)
2. [Initialize a
 PointerEvent](#dfn-initialize-a-pointerevent) with `event`,
 `eventType` and `eventTarget`,
 `bubbles` and `cancelable`
3. Return `event`

::: header-wrapper
#### 3.2.3 [create `PointerEvent` from `MouseEvent`]

1. Let `eventType` be a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) containing the event type
2. Let `mouseevent` be the corresponding
 [`MouseEvent`](#dom-mouseevent)
3. Let `event` be the result of [creating an
 event](https://dom.spec.whatwg.org/#concept-event-create)
 using
 [`PointerEvent`](#dom-pointerevent)
4. Let `target` be the
 `mouseevent`.[`target`](https://dom.spec.whatwg.org/#dom-event-target)
5. [Initialize a
 PointerEvent](#dfn-initialize-a-pointerevent) with `event`,
 `eventType` and `target`
6. Copy [`MouseEvent`](#dom-mouseevent) attributes from
 `mouseevent` into `event`
7. Return `event`

::: header-wrapper
### 3.3 [Pointer Event types]

Below are the event types defined in this specification.

In the case of the [primary
pointer](#dfn-primary-pointer), these events (with the exception of
[`gotpointercapture`](#dfn-gotpointercapture) and
[`lostpointercapture`](#dfn-lostpointercapture)) may also fire
[compatibility mouse
events](#dfn-compatibility-mouse-events).

::: header-wrapper
#### 3.3.1 [pointerover]

+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Type | **`pointerover`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [topmost |
| | event target](#dfn-topmost-event-target) |
| | - [`MouseEvent`](#dom-mouseevent).[`relatedTarget`](#dom-mouseevent-relatedtarget) : indicates the |
| | [target](https://dom.spec.whatwg.org/#event-target) a pointing device is entering, if |
| | any. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointerover`](#dfn-pointerover) when any of the following
occurs:

- The step to [determine the
 target](#dfn-determine-the-target) of a pointer detects that the pointer
 has moved into an element.
- A [layout
 change](#dfn-events-from-layout-changes) causes
 the [hit test](#dfn-hit-test) boundaries of an element to move underneath an
 uncaptured pointer of a stationary pointing device.
- Before the user agent fires a
 [`pointerdown`](#dfn-pointerdown) event for a device that
 [does not support
 hover](#mapping-for-devices-that-do-not-support-hover) (see
 [`pointerdown`](#dfn-pointerdown)).

::: header-wrapper
#### 3.3.2 [pointerenter]

+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Type | **`pointerenter`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Bubbles | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Cancelable | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Composed | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [topmost |
| | event target](#dfn-topmost-event-target) |
| | - [`MouseEvent`](#dom-mouseevent).[`relatedTarget`](#dom-mouseevent-relatedtarget) : indicates the |
| | [target](https://dom.spec.whatwg.org/#event-target) a pointing device is entering, if |
| | any. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointerenter`](#dfn-pointerenter) when any of the
following occurs:

- The step to [determine the
 target](#dfn-determine-the-target) of a pointer detects that the pointer
 has moved into an element or one of its descendants.
- A [layout
 change](#dfn-events-from-layout-changes) causes
 the [hit test](#dfn-hit-test) boundaries of an element or one of its descendants to
 move underneath an uncaptured pointer of a stationary pointing device.
- Before the user agent fires a
 [`pointerdown`](#dfn-pointerdown) event for a device that
 [does not support
 hover](#mapping-for-devices-that-do-not-support-hover) (see
 [`pointerdown`](#dfn-pointerdown)).

This event type is similar to
[`pointerover`](#dfn-pointerover) but with two differences:
[`pointerenter`](#dfn-pointerenter) does not bubble, and its
dispatch considers the [hit test](#dfn-hit-test) boundaries of even descendant elements.

There are similarities between this event type, the `mouseenter` event ,
and the CSS `:hover` pseudo-class described in
\[[CSS21](#bib-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\]. See also the
[`pointerleave`](#dfn-pointerleave) event.

::: header-wrapper
#### 3.3.3 [pointerdown]

+-----------------------------------+------------------------------------------------------------------------------------------------+
| Type | **`pointerdown`** |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) |
| | : [topmost event target](#dfn-topmost-event-target) |
+-----------------------------------+------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointerdown`](#dfn-pointerdown) when a pointer enters the
[active buttons
state](#dfn-active-buttons-state). For mouse, this is when the device
transitions from no buttons depressed to at least one button depressed.
For touch, this is when physical contact is made with the
[digitizer](#dfn-digitizer). For pen, this is when the pen either makes physical
contact with the digitizer without any button depressed, or transitions
from no buttons depressed to at least one button depressed while
hovering.

For mouse (or other multi-button pointer devices), this means
[`pointerdown`](#dfn-pointerdown) and
[`pointerup`](#dfn-pointerup) are not fired for all of the same
circumstances as `mousedown` and `mouseup`. See [chorded
buttons](#dfn-chorded-buttons) for more information.

For input [devices that do not support
hover](#mapping-for-devices-that-do-not-support-hover), the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* also [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointerover`](#dfn-pointerover) followed by a pointer
event named
[`pointerenter`](#dfn-pointerenter) prior to dispatching the
[`pointerdown`](#dfn-pointerdown) event.

Authors can prevent the firing of certain [compatibility mouse
events](#dfn-compatibility-mouse-events) by canceling the
[`pointerdown`](#dfn-pointerdown) event (if the `isPrimary`
property is `true`). This sets the `PREVENT MOUSE EVENT` flag on the
pointer. Note, however, that this does not prevent the `mouseover`,
`mouseenter`, `mouseout`, or `mouseleave` events from firing.

::: header-wrapper
#### 3.3.4 [pointermove]

+-----------------------------------+------------------------------------------------------------------------------------------------+
| Type | **`pointermove`** |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) |
| | : [topmost event target](#dfn-topmost-event-target) |
+-----------------------------------+------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointermove`](#dfn-pointermove) when a pointer changes
any properties that don\'t fire
[`pointerdown`](#dfn-pointerdown) or
[`pointerup`](#dfn-pointerup) events. This includes any changes to
coordinates, pressure, tangential pressure, tilt, twist, contact
geometry (`width` and `height`) or [chorded
buttons](#dfn-chorded-buttons).

User agents *MAY* delay dispatch of the
[`pointermove`](#dfn-pointermove) event (for instance, for
performance reasons). The [coalesced
events](#dfn-coalesced-events) information will be exposed via
the[`getCoalescedEvents`](#dom-pointerevent-getcoalescedevents) method for the single dispatched
[`pointermove`](#dfn-pointermove) event. The final
coordinates of such events should be used for finding the target of the
event.

::: header-wrapper
#### 3.3.5 [pointerrawupdate]

+-----------------------------------+------------------------------------------------------------------------------------------------+
| Type | **`pointerrawupdate`** |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Cancelable | No |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) |
| | : [topmost event target](#dfn-topmost-event-target) |
+-----------------------------------+------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointerrawupdate`](#dfn-pointerrawupdate), and only do so
within a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context),
when a pointer changes any properties that don\'t fire `pointerdown` or
`pointerup` events. See `pointermove` event for a list of such
properties.

In contrast with
[`pointermove`](#dfn-pointermove), user agents *SHOULD*
dispatch
[`pointerrawupdate`](#dfn-pointerrawupdate) events as soon as
possible and as frequently as the JavaScript can handle the events.

The `target` of
[`pointerrawupdate`](#dfn-pointerrawupdate) events might be
different from the
[`pointermove`](#dfn-pointermove) events due to the fact
that [`pointermove`](#dfn-pointermove) events might get delayed
or coalesced, and the final position of the event which is used for
finding the `target` could be different from its coalesced events.

Note that if there is already another
[`pointerrawupdate`](#dfn-pointerrawupdate) with the same
[`pointerId`](#dom-pointerevent-pointerid) that hasn\'t been dispatched in the [event
loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop),
the [user
agent](https://infra.spec.whatwg.org/#user-agent) *MAY*
coalesce the new
[`pointerrawupdate`](#dfn-pointerrawupdate) with that event
instead of creating a new
[task](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task).
This may cause
[`pointerrawupdate`](#dfn-pointerrawupdate) to have coalesced
events, and they will all be delivered as [coalesced
events](#dfn-coalesced-events) of one
[`pointerrawupdate`](#dfn-pointerrawupdate) event as soon as the
event is processed in the [event
loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop).
See[`getCoalescedEvents`](#dom-pointerevent-getcoalescedevents) for more information.

In terms of ordering of
[`pointerrawupdate`](#dfn-pointerrawupdate) and
[`pointermove`](#dfn-pointermove), if the user agent
received an update from the platform that causes both
[`pointerrawupdate`](#dfn-pointerrawupdate) and
[`pointermove`](#dfn-pointermove) events, then the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch the
[`pointerrawupdate`](#dfn-pointerrawupdate) event before the
corresponding
[`pointermove`](#dfn-pointermove).

Other than the `target`, the concatenation of coalesced events lists of
all dispatched
[`pointerrawupdate`](#dfn-pointerrawupdate) events since the
last [`pointermove`](#dfn-pointermove) event is the same as the
coalesced events of the next
[`pointermove`](#dfn-pointermove) event in terms of the
other event attributes. The attributes of
[`pointerrawupdate`](#dfn-pointerrawupdate) are mostly the same
as [`pointermove`](#dfn-pointermove), with the exception of
`cancelable` which *MUST* be false for
[`pointerrawupdate`](#dfn-pointerrawupdate).

User agents *SHOULD* not fire [compatibility mouse
events](#dfn-compatibility-mouse-events) for
[`pointerrawupdate`](#dfn-pointerrawupdate).

Adding listeners for the
[`pointerrawupdate`](#dfn-pointerrawupdate) event might
negatively impact the performance of the web page, depending on the
implementation of the user agent. For most use cases the other
pointerevent types should suffice. A
[`pointerrawupdate`](#dfn-pointerrawupdate) listener should only
be added if JavaScript needs high frequency events and can handle them
just as fast. In these cases, there is probably no need to listen to
other types of pointer events.

::: header-wrapper
#### 3.3.6 [pointerup]

+-----------------------------------+------------------------------------------------------------------------------------------------+
| Type | **`pointerup`** |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) |
| | : [topmost event target](#dfn-topmost-event-target) |
+-----------------------------------+------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointerup`](#dfn-pointerup) when a pointer leaves the [active
buttons
state](#dfn-active-buttons-state). For mouse, this is when the device
transitions from at least one button depressed to no buttons depressed.
For touch, this is when physical contact is removed from the
[digitizer](#dfn-digitizer). For pen, this is when the pen is removed from the
physical contact with the digitizer while no button is depressed, or
transitions from at least one button depressed to no buttons depressed
while hovering.

For input [devices that do not support
hover](#mapping-for-devices-that-do-not-support-hover), the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* also [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointerout`](#dfn-pointerout) followed by a pointer event named
[`pointerleave`](#dfn-pointerleave) after dispatching the
[`pointerup`](#dfn-pointerup) event.

All [`pointerup`](#dfn-pointerup) events have a `pressure` value of `0`.

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* also [implicitly release the pointer
capture](#dfn-implicitly-release-the-pointer-capture) if the pointer is currently captured.

For mouse (or other multi-button pointer devices), this means
[`pointerdown`](#dfn-pointerdown) and
[`pointerup`](#dfn-pointerup) are not fired for all of the same
circumstances as `mousedown` and `mouseup`. See [chorded
buttons](#dfn-chorded-buttons) for more information.

::: header-wrapper
#### 3.3.7 [pointercancel]

+-----------------------------------+------------------------------------------------------------------------------------------------+
| Type | **`pointercancel`** |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Cancelable | No |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) |
| | : [topmost event target](#dfn-topmost-event-target) |
+-----------------------------------+------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointercancel`](#dfn-pointercancel) when it detects a
scenario to [suppress a pointer event
stream](#dfn-suppress-a-pointer-event-stream).

The values of the following properties of the
[`pointercancel`](#dfn-pointercancel) event *MUST* match the
values of the last dispatched pointer event with the same
[`pointerId`](#dom-pointerevent-pointerid): `width`, `height`, `pressure`,
`tangentialPressure`, `tiltX`, `tiltY`, `twist`, `altitudeAngle`,
`azimuthAngle`, `pointerType`, `isPrimary`, and the coordinates
inherited from Mouse Events. The `coalescedEvents` and `predictedEvents`
lists in the
[`pointercancel`](#dfn-pointercancel) event *MUST* be empty,
and the event\'s
[`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable)
attribute *MUST* be false.

::: header-wrapper
#### 3.3.8 [pointerout]

+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Type | **`pointerout`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [topmost |
| | event target](#dfn-topmost-event-target) |
| | - [`MouseEvent`](#dom-mouseevent).[`relatedTarget`](#dom-mouseevent-relatedtarget) : indicates the |
| | [target](https://dom.spec.whatwg.org/#event-target) a pointing device is exiting, if |
| | any. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointerout`](#dfn-pointerout) when any of the following occurs:

- The step to [determine the
 target](#dfn-determine-the-target) of a pointer detects that the pointer
 has moved out of an element.
- A [layout
 change](#dfn-events-from-layout-changes) causes
 the [hit test](#dfn-hit-test) boundaries of an element to move away from underneath
 an uncaptured pointer of a stationary pointing device.
- After the user agent fires a
 [`pointerup`](#dfn-pointerup) event for a device that [does not
 support hover](#mapping-for-devices-that-do-not-support-hover) (see
 [`pointerup`](#dfn-pointerup)).
- The user agent has detected a scenario to [suppress a pointer event
 stream](#dfn-suppress-a-pointer-event-stream).

::: header-wrapper
#### 3.3.9 [pointerleave]

+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Type | **`pointerleave`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Bubbles | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Cancelable | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Composed | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [topmost |
| | event target](#dfn-topmost-event-target) |
| | - [`MouseEvent`](#dom-mouseevent).[`relatedTarget`](#dom-mouseevent-relatedtarget) : indicates the |
| | [target](https://dom.spec.whatwg.org/#event-target) a pointing device is entering, if |
| | any. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`pointerleave`](#dfn-pointerleave) when any of the
following occurs:

- The step to [determine the
 target](#dfn-determine-the-target) of a pointer detects that the pointer
 has moved out of an element and all of its descendants.
- A [layout
 change](#dfn-events-from-layout-changes) causes
 the [hit test](#dfn-hit-test) boundaries of an element and all of its descendants
 to move away from underneath an uncaptured pointer of a stationary
 pointing device.
- After the user agent fires the
 [`pointerup`](#dfn-pointerup) event for a device that [does not
 support hover](#mapping-for-devices-that-do-not-support-hover) (see
 [`pointerup`](#dfn-pointerup)).
- The user agent has detected a scenario to [suppress a pointer event
 stream](#dfn-suppress-a-pointer-event-stream).

This event type is similar to
[`pointerout`](#dfn-pointerout) but with two differences:
[`pointerleave`](#dfn-pointerleave) does not bubble, and its
dispatch considers the [hit test](#dfn-hit-test) boundaries of even descendant elements.

There are similarities between this event type, the `mouseleave` event,
and the CSS `:hover` pseudo-class described in
\[[CSS21](#bib-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\]. See also the
[`pointerenter`](#dfn-pointerenter) event.

::: header-wrapper
#### 3.3.10 [gotpointercapture]

+-----------------------------------+------------------------------------------------------------------------------------------------+
| Type | **`gotpointercapture`** |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Cancelable | No |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) |
| | : [topmost event target](#dfn-topmost-event-target) |
+-----------------------------------+------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`gotpointercapture`](#dfn-gotpointercapture) when an element
receives pointer capture. This event is fired at the element that is
receiving pointer capture. Subsequent events for that pointer will be
fired at this element. See the [setting pointer
capture](#dfn-set-pointer-capture) and [process pending pointer
capture](#dfn-process-pending-pointer-capture) sections.

::: header-wrapper
#### 3.3.11 [lostpointercapture]

+-----------------------------------+------------------------------------------------------------------------------------------------+
| Type | **`lostpointercapture`** |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Cancelable | No |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) |
| | : [topmost event target](#dfn-topmost-event-target) |
+-----------------------------------+------------------------------------------------------------------------------------------------+

The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [fire a pointer
event](#dfn-fire-a-pointer-event) named
[`lostpointercapture`](#dfn-lostpointercapture) after pointer
capture is released for a pointer. This event *MUST* be fired prior to
any subsequent events for the pointer after capture was released. This
event is fired at the element from which pointer capture was removed.
All subsequent events for the pointer except [`click`, `auxclick`, and
`contextmenu`](#dfn-click-auxclick-and-contextmenu) events follow normal hit testing
mechanisms (out of scope for this specification) for determining the
event target. See the [releasing pointer
capture](#dfn-release-pointer-capture), [implicit release of pointer
capture](#dfn-implicitly-release-the-pointer-capture), and [process pending pointer
capture](#dfn-process-pending-pointer-capture) sections.

::: header-wrapper
#### 3.3.12 [`click`, `auxclick`, and `contextmenu`]

This section is an addition to the
[`MouseEvent`](#dom-mouseevent) definitions of the `click`, `auxclick`
and `contextmenu` events. These events are typically tied to user
interface activation, and are fired even from non-pointer input devices,
such as keyboards.

These events *MUST* be of type `PointerEvent`, and are subject to the
additional requirements mentioned in the rest of this section.

::: header-wrapper
##### 3.3.12.1 Event attributes

For these events, all `PointerEvent` specific attributes (defined in
this spec) other than
[`pointerId`](#dom-pointerevent-pointerid) and `pointerType` *MUST* have their
default values. In addition:

- If the events are generated by a pointing device, their
 [`pointerId`](#dom-pointerevent-pointerid) and `pointerType` *MUST* be the same as
 the PointerEvents that caused these events.
- If the events are generated by a non-pointing device (such as voice
 recognition software or a keyboard interaction),
 [`pointerId`](#dom-pointerevent-pointerid) *MUST* be `-1` and `pointerType` *MUST*
 be an empty string.

::: header-wrapper
##### 3.3.12.2 Event coordinates

As noted in
[`PointerEvent`](#dom-pointerevent), [CSSOM View
Module](https://www.w3.org/TR/cssom-view-1/){matched-text="[[[CSSOM-VIEW]]]"}
proposes to redefine the various coordinate properties (`screenX`,
`screenY`, `pageX`, `pageY`, `clientX`, `clientY`, `x`, `y`, `offsetX`,
`offsetY`) as `double`, to allow for fractional coordinates. However,
this change --- when applied only to
[`PointerEvent`](#dom-pointerevent), but not to regular
[`MouseEvent`](#dom-mouseevent) --- has proven to lead to web
compatibility issues with legacy code in the case of `click`,
`auxclick`, and `contextmenu`. For this reason, user agents that have
implemented the proposed change in [CSSOM View
Module](https://www.w3.org/TR/cssom-view-1/){matched-text="[[[CSSOM-VIEW]]]"}
only for
[`PointerEvent`](#dom-pointerevent) *MUST* convert the
various coordinate properties for the `click`, `auxclick`, and
`contextmenu` to `long` values (as defined in the original Mouse Events)
using [Math.floor](https://tc39.es/ecma262/multipage/#sec-math.floor)
\[[ECMASCRIPT](#bib-ecmascript "ECMAScript Language Specification")\].

::: header-wrapper
##### 3.3.12.3 Event dispatch

A `click`, `auxclick` or `contextmenu` event *MUST* follow the standard
dispatch process, except that the event target is overridden using the
algorithm below:

1. Let `event` be the `click`, `auxclick` or `contextmenu`
 event being dispatched, and `userEvent` be the user
 interaction event that caused the firing of `event`.

 :::::
 :::
 Note
 :::

 :::
 Event `userEvent` could be a non-`PointerEvent`; for
 example, it is a `KeyboardEvent` when a `click` event dispatch is
 caused by hitting the spacebar on a checkbox element.

 When `userEvent` is a `PointerEvent`,
 `userEvent` is a
 [`pointerup`](#dfn-pointerup) for a `click` or `auxclick` event,
 and either a
 [`pointerdown`](#dfn-pointerdown) or a
 [`pointerup`](#dfn-pointerup) event (depending on native platform
 convention) for a `contextmenu` event.
 :::
 :::::

2. If `userEvent` is not a `PointerEvent`, dispatch
 `event` without overriding `event` target and
 skip the remaining steps below.

3. Define `target` as follows:

 If `event` is a `contextmenu` event, or
 `userEvent` was dispatched while the corresponding
 pointer was captured, then let `target` be the target of
 `userEvent`.

 Otherwise (`event` is a `click` or `auxclick` event for
 which `userEvent` is a `pointerup` event that was
 dispatched uncaptured) let `target` be the nearest common
 inclusive ancestor of the corresponding `pointerdown` and
 `pointerup` targets in the DOM at the moment `event` is
 being dispatched.

4. Dispatch `event` to `target`.

 :::::
 :::
 Note
 :::

 :::
 If `userEvent` was captured, `event` is
 dispatched to the capturing target of `userEvent` even
 though the
 [`lostpointercapture`](#dfn-lostpointercapture) event with the
 same
 [`pointerId`](#dom-pointerevent-pointerid) has been dispatched already.
 :::
 :::::

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element](https://developer.mozilla.org/en-US/docs/Web/API/Element "Element is the most general base class from which all element objects (i.e. objects that represent elements) in a Document inherit. It only has methods and properties common to all kinds of elements. More specific classes inherit from Element.")

This feature is in all major engines.

 ------------------ -------
 Chrome 1+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 1+
 Firefox Android ?
 Opera 8+
 Opera Android 10.1+
 Safari 1+
 Safari iOS ?
 Samsung Internet ?
 WebView Android 37+
 ------------------ -------

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/setPointerCapture](https://developer.mozilla.org/en-US/docs/Web/API/Element/setPointerCapture "The setPointerCapture() method of the Element interface is used to designate a specific element as the capture target of future pointer events. Subsequent events for the pointer will be targeted at the capture element until capture is released (via Element.releasePointerCapture() or the pointerup event is fired).")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/releasePointerCapture](https://developer.mozilla.org/en-US/docs/Web/API/Element/releasePointerCapture "The releasePointerCapture() method of the Element interface releases (stops) pointer capture that was previously set for a specific (PointerEvent) pointer.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/hasPointerCapture](https://developer.mozilla.org/en-US/docs/Web/API/Element/hasPointerCapture "The hasPointerCapture() method of the Element interface checks whether the element on which it is invoked has pointer capture for the pointer identified by the given pointer ID.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

::: header-wrapper
## 4. Extensions to the `Element` interface

The following section describes extensions to the existing
[`Element`](https://dom.spec.whatwg.org/#element) interface to facilitate the setting and releasing of
pointer capture.

```
WebIDLpartial interface Element {
 undefined setPointerCapture (long pointerId);
 undefined releasePointerCapture (long pointerId);
 boolean hasPointerCapture (long pointerId);
};
```

[`setPointerCapture()`]

: [Set pointer
 capture](#dfn-set-pointer-capture) for the pointer identified by the
 argument
 [`pointerId`](#dom-pointerevent-pointerid) to the element on which this method is
 invoked. For subsequent events of the pointer, the capturing target
 will substitute the normal hit testing result as if the pointer is
 always over the capturing target, and they *MUST* always be targeted
 at this element until capture is released. The pointer *MUST* be in
 its [active buttons
 state](#dfn-active-buttons-state) for this method to be effective,
 otherwise it fails silently. When the provided method\'s argument
 does not match any of the [active
 pointers](#dfn-active-pointer),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 \"[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`releasePointerCapture()`]

: [Release pointer
 capture](#dfn-release-pointer-capture) for the pointer identified by the
 argument
 [`pointerId`](#dom-pointerevent-pointerid) from the element on which this method
 is invoked. Subsequent events for the pointer follow normal hit
 testing mechanisms (out of scope for this specification) for
 determining the event target. When the provided method\'s argument
 does not match any of the [active
 pointers](#dfn-active-pointer),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 \"[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`hasPointerCapture`]

: Indicates whether the element on which this method is invoked has
 [pointer
 capture](#dfn-pointer-capture) for the pointer identified by the
 argument
 [`pointerId`](#dom-pointerevent-pointerid). In particular, returns `true` if the
 [pending pointer capture target
 override](#dfn-pending-pointer-capture-target-override) for
 [`pointerId`](#dom-pointerevent-pointerid) is set to the element on which this
 method is invoked, and `false` otherwise.

 :::::
 :::
 Note
 :::

 :::
 This method will return true immediately after a call to
 [`setPointerCapture()`](#dom-element-setpointercapture), even though that element will not yet
 have received a
 [`gotpointercapture`](#dfn-gotpointercapture) event. As a
 result it can be useful for detecting [implicit pointer
 capture](#dfn-implicit-pointer-capture) from inside of a
 [`pointerdown`](#dfn-pointerdown) event listener.
 :::
 :::::

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/pointerover_event](https://developer.mozilla.org/en-US/docs/Web/API/Element/pointerover_event "The pointerover event is fired when a pointing device is moved into an element's hit test boundaries.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/pointerenter_event](https://developer.mozilla.org/en-US/docs/Web/API/Element/pointerenter_event "The pointerenter event fires when a pointing device is moved into the hit test boundaries of an element or one of its descendants, including as a result of a pointerdown event from a device that does not support hover (see pointerdown).")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/pointerdown_event](https://developer.mozilla.org/en-US/docs/Web/API/Element/pointerdown_event "The pointerdown event is fired when a pointer becomes active. For mouse, it is fired when the device transitions from no buttons pressed to at least one button pressed. For touch, it is fired when physical contact is made with the digitizer. For pen, it is fired when the stylus makes physical contact with the digitizer.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/pointermove_event](https://developer.mozilla.org/en-US/docs/Web/API/Element/pointermove_event "The pointermove event is fired when a pointer changes coordinates, and the pointer has not been canceled by a browser touch-action.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[🚫]{ aria-label="This feature has limited support."}

[Element/pointerrawupdate_event](https://developer.mozilla.org/en-US/docs/Web/API/Element/pointerrawupdate_event "The pointerrawupdate PointerEvent is fired when a pointer changes any properties that don't fire pointerdown or pointerup events. See pointermove for a list of these properties.")

This feature has limited support.

 ------------------ -----
 Chrome 77+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox No
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/pointerup_event](https://developer.mozilla.org/en-US/docs/Web/API/Element/pointerup_event "The pointerup event is fired when a pointer is no longer active.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/pointercancel_event](https://developer.mozilla.org/en-US/docs/Web/API/Element/pointercancel_event "The pointercancel event is fired when the browser determines that there are unlikely to be any more pointer events, or if after the pointerdown event is fired, the pointer is then used to manipulate the viewport by panning, zooming, or scrolling.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/pointerout_event](https://developer.mozilla.org/en-US/docs/Web/API/Element/pointerout_event "The pointerout event is fired for several reasons including: pointing device is moved out of the hit test boundaries of an element; firing the pointerup event for a device that does not support hover (see pointerup); after firing the pointercancel event (see pointercancel); when a pen stylus leaves the hover range detectable by the digitizer.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/pointerleave_event](https://developer.mozilla.org/en-US/docs/Web/API/Element/pointerleave_event "The pointerleave event is fired when a pointing device is moved out of the hit test boundaries of an element. For pen devices, this event is fired when the stylus leaves the hover range detectable by the digitizer.")

This feature is in all major engines.

 ------------------ -----
 Chrome 55+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Element/gotpointercapture_event](https://developer.mozilla.org/en-US/docs/Web/API/Element/gotpointercapture_event "The gotpointercapture event is fired when an element captures a pointer using setPointerCapture().")

This feature is in all major engines.

 ------------------ -----
 Chrome 57+
 Chrome Android ?
 Edge 17+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[Document/lostpointercapture_event](https://developer.mozilla.org/en-US/docs/Web/API/Document/lostpointercapture_event "The lostpointercapture event is fired when a captured pointer is released.")

This feature is in all major engines.

 ------------------ -----
 Chrome 57+
 Chrome Android ?
 Edge 17+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

MDN[✅]{ aria-label="This feature is in all major engines."}

[HTMLElement/lostpointercapture_event](https://developer.mozilla.org/en-US/docs/Web/API/HTMLElement/lostpointercapture_event "The lostpointercapture event is fired when a captured pointer is released.")

This feature is in all major engines.

 ------------------ -----
 Chrome 57+
 Chrome Android ?
 Edge 17+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

::: header-wrapper
## 5. Extensions to the `GlobalEventHandlers` mixin

The following section describes extensions to the existing
[`GlobalEventHandlers`](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers) mixin to facilitate the event handler
registration.

```
WebIDLpartial interface mixin GlobalEventHandlers {
 attribute EventHandler onpointerover;
 attribute EventHandler onpointerenter;
 attribute EventHandler onpointerdown;
 attribute EventHandler onpointermove;
 [SecureContext] attribute EventHandler onpointerrawupdate;
 attribute EventHandler onpointerup;
 attribute EventHandler onpointercancel;
 attribute EventHandler onpointerout;
 attribute EventHandler onpointerleave;
 attribute EventHandler ongotpointercapture;
 attribute EventHandler onlostpointercapture;
};
```

[`onpointerover`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the [`pointerover`](#dfn-pointerover) event type.

[`onpointerenter`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the
 [`pointerenter`](#dfn-pointerenter) event type.

[`onpointerdown`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the
 [`pointerdown`](#dfn-pointerdown) event type.

[`onpointermove`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the
 [`pointermove`](#dfn-pointermove) event type.

[`onpointerrawupdate`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the
 [`pointerrawupdate`](#dfn-pointerrawupdate) event type.

[`onpointerup`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the [`pointerup`](#dfn-pointerup) event type.

[`onpointercancel`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the
 [`pointercancel`](#dfn-pointercancel) event type.

[`onpointerout`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the [`pointerout`](#dfn-pointerout) event type.

[`onpointerleave`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the
 [`pointerleave`](#dfn-pointerleave) event type.

[`ongotpointercapture`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the
 [`gotpointercapture`](#dfn-gotpointercapture) event type.

[`onlostpointercapture`]
: The [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the
 [`lostpointercapture`](#dfn-lostpointercapture) event type.

MDN[✅]{ aria-label="This feature is in all major engines."}

[Navigator/maxTouchPoints](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/maxTouchPoints "The maxTouchPoints read-only property of the Navigator interface returns the maximum number of simultaneous touch contact points are supported by the current device.")

This feature is in all major engines.

 ------------------ -----
 Chrome 35+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 59+
 Firefox Android 79+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

::: header-wrapper
## 6. Extensions to the `Navigator` interface

[`Navigator`](https://html.spec.whatwg.org/multipage/system-state.html#navigator) interface is defined in
\[[HTML](#bib-html "HTML Standard")\]. This
specification extends the `Navigator` interface to provide device
detection support.

```
WebIDLpartial interface Navigator {
 readonly attribute long maxTouchPoints;
};
```

[`maxTouchPoints`]

: The getter steps are:

 1. Let `emulated maxTouchPoints` be the result of
 [WebDriver BiDi emulated max touch
 points](https://www.w3.org/TR/webdriver-bidi/#webdriver-bidi-emulated-max-touch-points)
 \[[WEBDRIVER-BIDI](#bib-webdriver-bidi "WebDriver BiDi")\].

 2. If `emulated maxTouchPoints` is not null, return
 `emulated maxTouchPoints`.

 3. Return the maximum number of simultaneous touch contacts
 supported by the device. In the case of devices with multiple
 digitizers (e.g. multiple touchscreens), the value *MUST* be the
 maximum of the set of maximum supported contacts by each
 individual digitizer.

 For example, suppose a device has 3 touchscreens, which support
 2, 5, and 10 simultaneous touch contacts, respectively. The
 value of `maxTouchPoints` should be `10`.

While a `maxTouchPoints` value of greater than `0` indicates the user\'s
device is capable of supporting touch input, it does not necessarily
mean the user *will* use touch input. Authors should be careful to also
consider other input modalities that could be present on the system,
such as mouse, pen, or screen readers.

`maxTouchPoints` is often used to ensure that the interaction model of
the content can be recognized by the current hardware. UI affordances
can be provided to users with less capable hardware. On platforms where
the precise number of touch points is not known, the minimum number
guaranteed to be recognized is provided. Therefore, it is possible for
the number of recognized touch points to exceed the value of
`maxTouchPoints`.

::: header-wrapper
## 7. [Declaring direct manipulation behavior]

As noted in [Attributes and Default
Actions](#dfn-attributes-and-default-actions), viewport manipulations (panning and
zooming) cannot be suppressed by canceling a pointer event. Instead,
authors must declaratively define which of these behaviors they want to
allow, and which they want to suppress, using the `touch-action` CSS
property.

While the issue of pointers used to manipulate the viewport is generally
limited to touch input (where a user\'s finger can both interact with
content and pan/zoom the page), certain user agents may also allow the
same types of (direct or indirect) manipulation for other pointer types.
For instance, on mobile/tablet devices, users may also be able to scroll
using a stylus. While, for historical reasons, the `touch-action` CSS
property defined in this specification appears to refer only to touch
inputs, it does in fact apply to all forms of pointer inputs that allow
[direct
manipulation](#dfn-direct-manipulation) for panning and zooming.

MDN[✅]{ aria-label="This feature is in all major engines."}

[touch-action](https://developer.mozilla.org/en-US/docs/Web/CSS/touch-action "The touch-action CSS property sets how an element's region can be manipulated by a touchscreen user (for example, by zooming features built into the browser).")

This feature is in all major engines.

 ------------------ ------
 Chrome 36+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 52+
 Firefox Android 52+
 Opera ?
 Opera Android ?
 Safari 13+
 Safari iOS 9.3+
 Samsung Internet ?
 WebView Android ?
 ------------------ ------

::: header-wrapper
### 7.1 The [`touch-action`] CSS property

------------------ -------------------------------------------------------------------------------------------------------------------------------------
 Name: `touch-action`
 Value: `auto` \| `none` \| \[ \[ `pan-x` \| `pan-left` \| `pan-right` \] \|\| \[ `pan-y` \| `pan-up` \| `pan-down` \] \] \| `manipulation`
 Initial: `auto`
 Applies to: all elements except: non-replaced inline elements, table rows, row groups, table columns, and column groups
 Inherited: no
 Percentages: N/A
 Media: visual
 Computed value: same as specified value
 Canonical order: per grammar
 Animation type: not animatable
 ------------------ -------------------------------------------------------------------------------------------------------------------------------------

The `touch-action` CSS property determines whether [direct
manipulation](#dfn-direct-manipulation) interactions (which are not limited to
touch, despite the property\'s name) *MAY* trigger the user agent\'s
panning and zooming behavior. See the section on [`touch-action`
values](#dfn-touch-action-values).

Right before starting to pan or zoom, the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* [suppress a pointer event
stream](#dfn-suppress-a-pointer-event-stream) if all of the following conditions are
true:

- The user agent has determined (via methods out of scope for this
 specification) that a direct manipulation interaction is to be
 consumed for panning or zooming,
- a [`pointerdown`](#dfn-pointerdown) event has been sent for
 the pointer, and
- a [`pointerup`](#dfn-pointerup) or
 [`pointercancel`](#dfn-pointercancel) event (following the
 above mentioned
 [`pointerdown`](#dfn-pointerdown)) has not yet been sent
 for the pointer.

Some user agents implement complex gestures for behaviors that involve a
series of separate discrete gestures, but which are all treated as part
of a single continuous gesture. For example, consider a \"fling to
scroll\" gesture on a touchscreen: a user starts panning the document
with a rapid finger movement, lifts the finger from the touchscreen, and
the document continues panning with simulated inertia. While the
document is still moving, the user may place their finger on the
touchscreen and execute another \"fling\" to provide further momentum
for the panning, or counteract the current panning to slow it down, stop
panning altogether, or reverse the direction of the panning. As this
specification does not normatively define how gestures and behaviors are
implemented, it is left up to the user agent to decide whether or not
the second touch (before it is interpreted as a second \"fling\" or
counteraction of the current panning) fires pointer events or not.

`touch-action` does not apply/cascade through to embedded browsing
contexts. For instance, even applying `touch-action` to an `<iframe>`
won\'t have any effect on the behavior of direct manipulation
interactions for panning and zooming within the `<iframe>` itself.

::: header-wrapper
### 7.2 Determining supported direct manipulation behavior

When a user interacts with an element using a [direct
manipulation](#dfn-direct-manipulation) pointer (such as touch or stylus on a
touchscreen), the effect of that input is determined by the value of the
`touch-action` property, and the default direct manipulation behaviors
of the element and its ancestors, as follows:

- A direct manipulation interaction for panning and zooming [conforms to
 an element\'s `touch-action`] if the behavior is
 allowed in the coordinate space of the element. Note that if CSS
 transforms have been applied, the element\'s coordinate space may
 differ from the screen coordinate in a way that affects the conformity
 here; for example, the X axis of an element rotated by 90 degrees with
 respect to the screen will be parallel to the Y-axis of the screen
 coordinate.
- A direct manipulation interaction for panning is supported if it
 [conforms](#dfn-conforming-touch-behavior) to the
 `touch-action` property of each element between the hit tested element
 and its nearest inclusive ancestor that is a [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container)
 (as defined in
 \[[CSS-OVERFLOW-3](#bib-css-overflow-3 "CSS Overflow Module Level 3")\]).
- A direct manipulation interaction for zooming is supported if it
 [conforms](#dfn-conforming-touch-behavior) to the
 `touch-action` property of each element between the hit tested element
 and the `document` element of the [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context)
 (as defined in \[[HTML](#bib-html "HTML Standard")\]).
- Once panning or zooming has been started, and the user agent has
 already determined whether or not the gesture should be handled as a
 user agent direct manipulation behavior, any changes to the relevant
 `touch-action` value will be ignored for the duration of the action.
 For instance, programmatically changing the `touch-action` value for
 an element from `auto` to `none` as part of a
 [`pointerdown`](#dfn-pointerdown) handler script will not
 result in the user agent aborting or suppressing any of the pan or
 zoom behavior for that input for as long as that pointer is active.
- Similarly, in the case of the various `touch-action` values of
 `pan-*`, once the user agent has determined whether to handle a
 gesture directly or not at the start of the gesture, a subsequent
 change in the direction of the same gesture *SHOULD* be ignored by the
 user agent for as long as that pointer is active. For instance, if an
 element has been set to `touch-action: pan-y` (meaning that only
 vertical panning is handled by the user agent), and a touch gesture
 starts off horizontally, no vertical panning should occur if the user
 changes the direction of their gesture to be vertical while their
 finger is still touching the screen.

Some user agents support panning and zooming interactions involving
multiple concurrent pointers (e.g. multi-touch). Methods for processing
or associating the `touch-action` values of multiple concurrent pointers
is out of scope for this specification.

::: header-wrapper
### 7.3 [Details of `touch-action` values]

The `touch-action` property covers direct manipulation behaviors related
to viewport panning and zooming. Any additional user agent behaviors,
such as text selection/highlighting, or activating links and form
controls, *MUST NOT* be affected by this CSS property.

The terms \"panning\" and \"scrolling\" are considered synonymous (or,
more aptly, \"panning\" is \"scrolling\" using a direct manipulation
input). Defining an interaction or gesture for triggering
panning/scrolling, or for triggering behavior for the `auto` or `none`
values, are out of scope for this specification.

: The [user
 agent](https://infra.spec.whatwg.org/#user-agent)
 *MAY* consider any permitted direct manipulation behaviors related
 to panning and zooming of the viewport that begin on the element.

none
: Direct manipulation interactions that begin on the element *MUST
 NOT* trigger behaviors related to viewport panning and zooming.

pan-x\
pan-left\
pan-right\
pan-y\
pan-up\
pan-down
: The [user
 agent](https://infra.spec.whatwg.org/#user-agent)
 *MAY* consider direct manipulation interactions that begin on the
 element only for the purposes of panning that starts in any of the
 directions specified by all of the listed values. Once panning has
 started, the direction may be reversed by the user even if panning
 that starts in the reversed direction is disallowed. In contrast,
 when panning is restricted to a single axis (for instance, with
 `pan-x` or `pan-y`), the axis cannot be changed during panning.

manipulation
: The [user
 agent](https://infra.spec.whatwg.org/#user-agent)
 *MAY* consider direct manipulation interactions that begin on the
 element only for the purposes of panning and **continuous** zooming
 (such as pinch-zoom), but *MUST NOT* trigger other related behaviors
 that rely on multiple activations that must happen within a set
 period of time (such as double-tap to zoom, or double-tap and hold
 for single-finger zoom).

[Additional `touch-action`
values](https://compat.spec.whatwg.org/#touch-action) common in
implementations are defined in
\[[COMPAT](#bib-compat "Compatibility Standard")\].

The `touch-action` property only applies to elements that support both
the CSS `width` and `height` properties (see
\[[CSS21](#bib-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\]). This restriction is designed to facilitate user
agent optimizations for *low-latency* [direct
manipulation](#dfn-direct-manipulation) panning and zooming. For elements not
supported by default, such as `<span>` which is a *non-replaced inline
element*, authors can set the `display` CSS property to a value, such as
`block`, that supports `width` and `height`. Future specifications could
extend this API to all elements.

The direction-specific pan values are useful for customizing some
overscroll behaviors. For example, to implement a simple pull-to-refresh
effect the document\'s `touch-action` can be set to `pan-x pan-down`
whenever the scroll position is `0` and `pan-x pan-y` otherwise. This
allows pointer event handlers to define the behavior for upward
panning/scrolling that start from the top of the document.

The direction-specific pan values can also be used for composing a
component that implements custom panning with pointer event handling
within an element that scrolls natively (or vice-versa). For example, an
image carousel may use `pan-y` to ensure it receives pointer events for
any horizontal pan operations without interfering with vertical panning
of the document. When the carousel reaches its right-most extent, it may
change its `touch-action` to `pan-y pan-right` so that a subsequent
scroll operation beyond its extent can scroll the document within the
viewport if possible. It\'s not possible to change the behavior of a
panning/scrolling operation while it is taking place.

Disabling some default direct manipulation behaviors for panning and
zooming may allow user agents to respond to other behaviors more
quickly. For example, with `auto` user agents typically add 300ms of
delay before `click` to allow for double-tap gestures to be handled. In
these cases, explicitly setting `touch-action: none` or
`touch-action: manipulation` will remove this delay. Note that the
methods for determining a tap or double-tap gesture are out of scope for
this specification.

[Example 2](#example_7)[: Disallowing all direct
manipulation behaviors]

 <div style="touch-action: none;">
 This element receives pointer events for all direct manipulation interactions that otherwise lead to panning or zooming.
 </div>

[Example 3](#example_8)[: Allowing horizontal panning
only]

 <div style="touch-action: pan-x;">
 This element receives pointer events when not panning in the horizontal direction.
 </div>

[Example 4](#example_9)[: Child regions that disallow direct
manipulation behaviors for panning and zooming]

 <div style="overflow: auto;">
 <div style="touch-action: none;">
 This element receives pointer events for all direct manipulation interactions that otherwise lead to panning or zooming.
 </div>
 <div>
 Direct manipulation interactions on this element MAY be consumed for manipulating the parent.
 </div>
 </div>

[Example 5](#example_10)[: Intermediate parent that
disallows direct manipulation behaviors for panning and
zooming]

 <div style="overflow: auto;">
 <div style="touch-action: pan-y;">
 <div style="touch-action: pan-x;">
 This element receives pointer events for all direct manipulation interactions because
 it allows only horizontal panning yet an intermediate ancestor
 (between it and the scrollable element) only allows vertical panning.
 Therefore, no direct manipulation behaviors for panning/zooming are
 handled by the user agent.
 </div>
 </div>
 </div>

[Example 6](#example_11)[: Intermediate parent that
restricts allowed direct manipulation behaviors for panning and
zooming]

 <div style="overflow: auto;">
 <div style="touch-action: pan-y pan-left;">
 <div style="touch-action: pan-x;">
 This element receives pointer events when not panning to the left.
 </div>
 </div>
 </div>

::: header-wrapper
## 8. [Pointer capture]

::: header-wrapper
### 8.1 Introduction

*This section is non-normative.*

Pointer capture allows the events for a particular pointer (including
any [compatibility mouse
events](#dfn-compatibility-mouse-events)) to be retargeted to a particular element
other than the normal [hit test](#dfn-hit-test) result of the pointer\'s location. This is
useful in scenarios like a custom slider control (e.g. similar to the
\[[HTML](#bib-html "HTML Standard")\]
`<input type="range">` control). Pointer capture can be set on the
slider thumb element, allowing the user to slide the control back and
forth even if the pointer slides off of the thumb.

![[Figure 6](#figure_slider) [Example of a custom slider
control that chooses a value by sliding the thumb element back and
forth. After
[`pointerdown`](#dfn-pointerdown) on the thumb, pointer
capture can be used to allow the user to slide the thumb even if the
pointer drifts off of
it.]](images/slider.png)

::: header-wrapper
### 8.2 [Setting pointer capture]

Pointer capture is set on an `element` of type
[`Element`](https://dom.spec.whatwg.org/#element) by calling the `element.setPointerCapture(pointerId)`
method. When this method is invoked, the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* run the following steps:

1. If the
 [`pointerId`](#dom-pointerevent-pointerid) provided as the method\'s argument
 does not match any of the [active
 pointers](#dfn-active-pointer), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 \"[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
2. Let the `pointer` be the [active
 pointer](#dfn-active-pointer) specified by the given
 [`pointerId`](#dom-pointerevent-pointerid).
3. If the `element` is not
 [connected](https://dom.spec.whatwg.org/#connected)
 \[[DOM](#bib-dom "DOM Standard")\],
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
4. If this method is invoked while the `element`\'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)
 \[[DOM](#bib-dom "DOM Standard")\] has a
 locked element
 (\[[PointerLock](#bib-pointerlock "Pointer Lock 2.0")\]
 [`pointerLockElement`](https://www.w3.org/TR/pointerlock-2/#dom-documentorshadowroot-pointerlockelement)),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
5. If the `pointer` is not in the [active buttons
 state](#dfn-active-buttons-state) or the `element`\'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)
 is not the [active
 document](#dfn-active-document) of the `pointer`, then
 terminate these steps.
6. For the specified
 [`pointerId`](#dom-pointerevent-pointerid), set the [pending pointer capture
 target override] to the
 [`Element`](https://dom.spec.whatwg.org/#element) on which this method was invoked.

If a call to set or release a pointer capture is made while a previous
set or release call is in a pending state (see [process pending pointer
capture](#dfn-process-pending-pointer-capture)), the second call overrides the first call
if the second call is successful, otherwise the first call remains
effective. This is true for a failed attempt to release an [implicit
pointer
capture](#dfn-implicit-pointer-capture) at a
[`pointerdown`](#dfn-pointerdown) listener.

::: header-wrapper
### 8.3 [Releasing pointer capture]

Pointer capture is released on an element explicitly by calling the
`element.releasePointerCapture(pointerId)` method. When this method is
called, the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* run the following steps:

1. If the
 [`pointerId`](#dom-pointerevent-pointerid) provided as the method\'s argument
 does not match any of the [active
 pointers](#dfn-active-pointer) and these steps are not being invoked
 as a result of the [implicit release of pointer
 capture](#dfn-implicitly-release-the-pointer-capture), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw)
 a
 \"[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
2. If
 [`hasPointerCapture`](#dom-element-haspointercapture) is false for the
 [`Element`](https://dom.spec.whatwg.org/#element) with the specified
 [`pointerId`](#dom-pointerevent-pointerid), then terminate these steps.
3. For the specified
 [`pointerId`](#dom-pointerevent-pointerid), clear the [pending pointer capture
 target
 override](#dfn-pending-pointer-capture-target-override), if set.

See the note in the section [Setting pointer
capture](#dfn-set-pointer-capture).

::: header-wrapper
### 8.4 [Implicit pointer capture]

Inputs that implement [direct
manipulation](#dfn-direct-manipulation) interactions for panning and zooming (such
as touch or stylus on a touchscreen) *SHOULD* behave exactly as if
[`setPointerCapture`](#dom-element-setpointercapture) was called on the target element just
before the invocation of any
[`pointerdown`](#dfn-pointerdown) listeners. The
[`hasPointerCapture`](#dom-element-haspointercapture) API may be used (for instance, in a
[`pointerdown`](#dfn-pointerdown) listener) to determine
whether this has occurred. If
[`releasePointerCapture`](#dom-element-releasepointercapture) is not called for the pointer before the
next pointer event is fired, then a
[`gotpointercapture`](#dfn-gotpointercapture) event will be
dispatched to the target (as normal) indicating that capture is active.

This is a breaking change from
\[[PointerEvents](#bib-pointerevents "Pointer Events")\], but does not impact the vast majority of existing
content. In addition to matching typical platform UX conventions, this
design for implicit capture enables user agents to make a performance
optimization which prevents the need to invoke hit-testing on touch
movement events without explicit developer opt-in (consistent with the
performance properties of existing dominant native and web APIs for
touch input).

In addition, user agents may implement implicit pointer capture behavior
for all input devices on specific UI widgets such as input range
controls (allowing some finger movement to stray outside of the form
control itself during the interaction).

::: header-wrapper
### 8.5 [Implicit release of pointer capture]

Immediately after firing the
[`pointerup`](#dfn-pointerup) or
[`pointercancel`](#dfn-pointercancel) events, the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* clear the [pending pointer capture target
override](#dfn-pending-pointer-capture-target-override) for the
[`pointerId`](#dom-pointerevent-pointerid) of the
[`pointerup`](#dfn-pointerup) or
[`pointercancel`](#dfn-pointercancel) event that was just
dispatched, and then run [process pending pointer
capture](#dfn-process-pending-pointer-capture) steps to fire
[`lostpointercapture`](#dfn-lostpointercapture) if necessary.
After running [process pending pointer
capture](#dfn-process-pending-pointer-capture) steps, if the pointer supports hover,
[user agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* also send corresponding boundary events necessary to reflect the
current position of the pointer with no capture.

When the [pointer capture target
override](#dfn-pointer-capture-target-override) is no longer
[connected](https://dom.spec.whatwg.org/#connected)
\[[DOM](#bib-dom "DOM Standard")\], the
[pointer capture target
override](#dfn-pointer-capture-target-override) *SHOULD* be set to the document.

When the [pending pointer capture target
override](#dfn-pending-pointer-capture-target-override) is no longer
[connected](https://dom.spec.whatwg.org/#connected)
\[[DOM](#bib-dom "DOM Standard")\], the
[pending pointer capture target
override](#dfn-pending-pointer-capture-target-override) node *SHOULD* be cleared.

The previous two paragraphs result in a
[`lostpointercapture`](#dfn-lostpointercapture) event
corresponding to the captured pointer being fired at the document during
the next [Process pending pointer
capture](#dfn-process-pending-pointer-capture) after the capture node is removed.

When a pointer lock
\[[PointerLock](#bib-pointerlock "Pointer Lock 2.0")\] is successfully applied on an element, the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* run the steps as if the
[`releasePointerCapture`](#dom-element-releasepointercapture) method has been called if any element is
set to be captured or pending to be captured.

::: header-wrapper
## 9. Coalesced and predicted events

This specification does not define how user agents should coalesce or
predict pointer movement data. It only specifies the API for accessing
this information.

::: header-wrapper
### 9.1 [Coalesced events]

For performance reasons, user agents may choose not to send a
[`pointermove`](#dfn-pointermove) event every time a
[measurable
property](#dfn-measurable-property) (such as coordinates, pressure, tangential
pressure, tilt, twist, or contact geometry) of a pointer is updated.
Instead, they may coalesce (combine/merge) multiple changes into a
single [`pointermove`](#dfn-pointermove) or
[`pointerrawupdate`](#dfn-pointerrawupdate) event. While this
approach helps in reducing the amount of event handling the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* perform, it will naturally reduce the granularity and fidelity
when tracking a pointer position, particularly for fast and large
movements. Using the
[`getCoalescedEvents`](#dom-pointerevent-getcoalescedevents) method it is possible for applications to
access the raw, un-coalesced position changes. These allow for a more
precise handling of pointer movement data. In the case of drawing
applications, for instance, the un-coalesced events can be used to draw
smoother curves that more closely match the actual movement of a
pointer.

![[Figure 7](#figure_coalesced) [Example of a curve in a
drawing application --- using only the coalesced coordinates from
[`pointermove`](#dfn-pointermove) events (the grey dots),
the curve is noticeably angular and jagged; the same line drawn using
the more granular points provided by `getCoalescedEvents()` (the red
circles) results in a smoother approximation of the pointer
movement.]](images/coalesced-points.png)

A [`PointerEvent`](#dom-pointerevent) has an associated [coalesced events
list] (a list of zero or more
`PointerEvent`s). For trusted
[`pointermove`](#dfn-pointermove) and
[`pointerrawupdate`](#dfn-pointerrawupdate) events, the list is
a sequence of all `PointerEvent`s that were coalesced into this event.
The \"parent\" trusted
[`pointermove`](#dfn-pointermove) and
[`pointerrawupdate`](#dfn-pointerrawupdate) event represents an
accumulation of these coalesced events, but may have additional
processing (for example to align with the display refresh rate). As a
result, the coalesced events lists for these events always contain at
least one event. For all other trusted event types, it is an empty list.
Untrusted events have their [coalesced events
list](#dfn-coalesced-events-list) initialized to the value passed to the
constructor.

Since a trusted parent event is a summary or aggregation of the
coalesced events, developers should only need to process either the
parent events or all of the coalesced events, but not both.

When a trusted event containing a [coalesced events
list](#dfn-coalesced-events-list) is re-dispatched from JavaScript, the
event dispatch algorithm sets the
[`isTrusted`](https://dom.spec.whatwg.org/#dom-event-istrusted)
bit of the event to `false` but the same bits in the [coalesced events
list](#dfn-coalesced-events-list) remain unchanged from their original
`true` values.

The events in the coalesced events list of a trusted event will have:

- Monotonically increasing
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp)
 values \[[DOM](#bib-dom "DOM Standard")\]
 --- all coalesced events have a
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp)
 that is smaller than or equal to the
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp)
 of the dispatched pointer event that the
 [`getPredictedEvents`](#dom-pointerevent-getpredictedevents) method was called on. The coalesced
 events list *MUST* be chronologically sorted by
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp),
 so the first event will have the smallest
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp).
- The same
 [`pointerId`](#dom-pointerevent-pointerid), `pointerType`, and `isPrimary` as the
 dispatched \"parent\" pointer event.
- Empty [coalesced events
 list](#dfn-coalesced-events-list) and [predicted events
 list](#dfn-predicted-events-list) of their own.

[Example 7](#example_12)[: Basic canvas drawing application
using the coalesced events list]

 <style>
 /* Disable intrinsic user agent direct manipulation behaviors (such as panning or zooming)
 so that all events on the canvas element are given to the application instead. */

 canvas { touch-action: none; }
 </style>

 <canvas id="drawSurface" width="500px" height="500px" style="border:1px solid black;"></canvas>

 <script>
 const canvas = document.getElementById("drawSurface"),
 context = canvas.getContext("2d");

 canvas.addEventListener("pointermove", (e)=> {

 if (e.getCoalescedEvents) {
 for (let coalesced_event of e.getCoalescedEvents()) {
 paint(coalesced_event); // Paint all raw/non-coalesced points
 }
 } else {
 paint(e); // Paint the final coalesced point
 }
 });

 function paint(event) {
 if (event.buttons>0) {
 context.fillRect(event.clientX, event.clientY, 5, 5);
 }
 }

 </script>

The PointerEvent\'s attributes will be initialized in a way that best
represents the events in the coalesced events list. The specific method
by which user agents should do this is not covered by this
specification.

The order of all these dispatched events *MUST* match the actual order
of the original events. For example if a
[`pointerdown`](#dfn-pointerdown) event causes the dispatch
for the coalesced
[`pointermove`](#dfn-pointermove) events the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* first dispatch one
[`pointermove`](#dfn-pointermove) event with all those
coalesced events of a
[`pointerId`](#dom-pointerevent-pointerid) followed by the
[`pointerdown`](#dfn-pointerdown) event.

Here is an example of the actual events happening with increasing
[`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp)
values and the events dispatched by the user agent:

 -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Actual events Dispatched events
 ------------------------------------------------------------------------------------ ------------------------------------------------------------------------------------
 pointer [`pointerrawupdate`](#dfn-pointerrawupdate)
 .internalDFN }=2) coordinate change ([`pointerId`](#dom-pointerevent-pointerid)=2) w/ one coalesced event

 pointer [`pointerrawupdate`](#dfn-pointerrawupdate)
 .internalDFN }=1) coordinate change ([`pointerId`](#dom-pointerevent-pointerid)=1) w/ one coalesced event

 pointer [`pointerrawupdate`](#dfn-pointerrawupdate)
 .internalDFN }=2) coordinate change ([`pointerId`](#dom-pointerevent-pointerid)=2) w/ one coalesced event

 pointer [`pointerrawupdate`](#dfn-pointerrawupdate)
 .internalDFN }=2) coordinate change ([`pointerId`](#dom-pointerevent-pointerid)=2) w/ one coalesced event

 pointer [`pointerrawupdate`](#dfn-pointerrawupdate)
 .internalDFN }=1) coordinate change ([`pointerId`](#dom-pointerevent-pointerid)=1) w/ one coalesced event

 pointer [`pointerrawupdate`](#dfn-pointerrawupdate)
 .internalDFN }=2) coordinate change ([`pointerId`](#dom-pointerevent-pointerid)=2) w/ one coalesced event

 pointer [`pointermove`](#dfn-pointermove)
 .internalDFN }=1) button press ([`pointerId`](#dom-pointerevent-pointerid)=1) w/ two coalesced events\
 [`pointermove`](#dfn-pointermove)
 ([`pointerId`](#dom-pointerevent-pointerid)=2) w/ four coalesced events\
 [`pointerdown`](#dfn-pointerdown)
 ([`pointerId`](#dom-pointerevent-pointerid)=1) w/ zero coalesced events\

 pointer [`pointerrawupdate`](#dfn-pointerrawupdate)
 .internalDFN }=2) coordinate change ([`pointerId`](#dom-pointerevent-pointerid)=2) w/ one coalesced event

 pointer [`pointerrawupdate`](#dfn-pointerrawupdate)
 .internalDFN }=2) coordinate change ([`pointerId`](#dom-pointerevent-pointerid)=2) w/ one coalesced event

 pointer [`pointermove`](#dfn-pointermove)
 .internalDFN }=1) button release ([`pointerId`](#dom-pointerevent-pointerid)=2) w/ two coalesced events\
 [`pointerup`](#dfn-pointerup)
 ([`pointerId`](#dom-pointerevent-pointerid)=1) w/ zero coalesced events\
 -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
### 9.2 [Predicted events]

Some user agents have built-in algorithms which, after a series of
confirmed pointer movements, can make a prediction (based on the
preceding events for the current gesture, and the speed/trajectory of
the movement) what the position of future pointer movements may be.
Applications can use this information with the
[`getPredictedEvents`](#dom-pointerevent-getpredictedevents) method to speculatively \"draw ahead\" to
a predicted position to reduce perceived latency, and then discarding
these predicted points once the actual points are received.

![[Figure 8](#figure_predicted) [Example of a line in a
drawing application (the result of a drawing gesture from the bottom
left to the top right), using the coalesced coordinates from
[`pointermove`](#dfn-pointermove) events, showing the user
agent\'s predicted future points (the grey
circles).]](images/predicted-points.png)

A [`PointerEvent`](#dom-pointerevent) has an associated [predicted events
list] (a list of zero or more
`PointerEvent`s). For trusted
[`pointermove`](#dfn-pointermove) events, it is a sequence
of `PointerEvent`s that the user agent predicts will follow the event in
the future. For all other trusted event types, it is an empty list.
Untrusted events have their [predicted events
list](#dfn-predicted-events-list) initialized to the value passed to the
constructor.

While `pointerrawupdate` events may have a non-empty [coalesced events
list](#dfn-coalesced-events-list), their [predicted events
list](#dfn-predicted-events-list) will, for performance reasons, usually be
an empty list.

When a trusted event containing a [predicted events
list](#dfn-predicted-events-list) is re-dispatched from JavaScript, the
event dispatch algorithm sets the
[`isTrusted`](https://dom.spec.whatwg.org/#dom-event-istrusted)
bit of the event to `false` but the same bits in the [predicted events
list](#dfn-predicted-events-list) remain unchanged from their original
`true` values.

The number of events in the list and how far they are from the current
timestamp are determined by the user agent and the prediction algorithm
it uses.

The events in the predicted events list of a trusted event will have:

- Monotonically increasing
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp)
 values \[[DOM](#bib-dom "DOM Standard")\]
 --- all predicted events have a
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp)
 that is greater than or equal to the
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp)
 of the dispatched pointer event that the
 [`getPredictedEvents`](#dom-pointerevent-getpredictedevents) method was called on. The predicted
 events list *MUST* be chronologically sorted by
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp),
 so the first event will have the smallest
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp).
- The same
 [`pointerId`](#dom-pointerevent-pointerid), `pointerType`, and `isPrimary` as the
 dispatched \"parent\" pointer event.
- Empty [coalesced events
 list](#dfn-coalesced-events-list) and [predicted events
 list](#dfn-predicted-events-list) of their own.

Note that authors should only consider predicted events as valid
predictions until the next pointer event is dispatched. It is possible,
depending on how far into the future the user agent predicts events,
that regular pointer events are dispatched earlier than the timestamp of
one or more of the predicted events.

[Example 8](#example_13)[: Conceptual approach to drawing
using coalesced events and predicted events]

 let predicted_points = ;
 window.addEventListener("pointermove", function(event) {
 // Clear the previously drawn predicted points.
 for (let e of predicted_points.reverse()) {
 clearPoint(e.pageX, e.pageY);
 }

 // Draw the actual movements that happened since the last received event.
 for (let e of event.getCoalescedEvents()) {
 drawPoint(e.pageX, e.pageY);
 }

 // Draw the current predicted points to reduce the perception of latency.
 predicted_points = event.getPredictedEvents();
 for (let e of predicted_points) {
 drawPoint(e.pageX, e.pageY);
 }
 });

::: header-wrapper
### 9.3 Populating and maintaining the coalesced and predicted events lists

When a trusted
[`PointerEvent`](#dom-pointerevent) is created, user agents *SHOULD* run the
following steps for each event in the [coalesced events
list](#dfn-coalesced-events-list) and [predicted events
list](#dfn-predicted-events-list):

1. Set the event\'s
 [`pointerId`](#dom-pointerevent-pointerid), ` pointerType`, `isPrimary` and
 [`isTrusted`](https://dom.spec.whatwg.org/#dom-event-istrusted)
 to match the respective properties of the \"parent\" pointer event.
2. Set the event\'s
 [`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable)
 and
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles)
 to false (as these events will never be dispatched in isolation).
3. Set the event\'s [coalesced events
 list](#dfn-coalesced-events-list) and [predicted events
 list](#dfn-predicted-events-list) to an empty list.
4. Initialize all other attributes to default
 [`PointerEvent`](#dom-pointerevent) values.

When a trusted
[`PointerEvent`](#dom-pointerevent)\'s
[`target`](https://dom.spec.whatwg.org/#dom-event-target)
is changed, user agents *SHOULD*, for each event in the [coalesced
events
list](#dfn-coalesced-events-list) and [predicted events
list](#dfn-predicted-events-list):

1. Set the event\'s
 [`target`](https://dom.spec.whatwg.org/#dom-event-target)
 to match the
 [`target`](https://dom.spec.whatwg.org/#dom-event-target)
 of the \"parent\" pointer event.

::: header-wrapper
## 10. [Compatibility mapping with mouse events]

The vast majority of web content existing today codes only to Mouse
Events. The following describes an algorithm for how the [user
agent](https://infra.spec.whatwg.org/#user-agent) *MAY*
map generic pointer input to mouse events for compatibility with this
content.

The compatibility mapping with mouse events is an *OPTIONAL* feature of
this specification. User agents are encouraged to support the feature
for best compatibility with existing legacy content.

At a high level, compatibility mouse events are intended to be
\"interleaved\" with their respective pointer events. However, this
specific order is not mandatory, and user agents that implement
compatibility mouse events *MAY* decide to delay or group the dispatch
of mouse events, as long as their relative order is consistent.

Particularly in the case of touchscreen inputs, user agents *MAY* apply
additional heuristics for gesture recognition (unless explicitly
suppressed by authors through
[`touch-action`](#dfn-touch-action)). During a sequence of events between a
[`pointerdown`](#dfn-pointerdown) event and a
[`pointerup`](#dfn-pointerup) event, the gesture recognition may have
to wait until the
[`pointerup`](#dfn-pointerup) event to detect or ignore a gesture. As
a result the compatibility mouse events for the whole sequence may be
dispatched together after the last
[`pointerup`](#dfn-pointerup) event, if the user agent determined that
an interaction was not intended as a particular gesture. These specifics
of user agent gesture recognition are not defined in this specification,
and they may differ between implementations.

Regardless of their support for compatibility mouse events, the user
agents *MUST* always support the `click`, `auxclick` and `contextmenu`
events because these events are of type `PointerEvent` and are therefore
not [compatibility mouse
events](#dfn-compatibility-mouse-events). Calling `preventDefault` during a pointer
event *MUST NOT* have an effect on whether `click`, `auxclick`, or
`contextmenu` are fired or not.

The relative order of some of these high-level events (such as
`contextmenu`,
[focus](https://html.spec.whatwg.org/multipage/indices.html#event-focus),
[blur](https://html.spec.whatwg.org/multipage/indices.html#event-blur))
with pointer events is undefined and varies between user agents. For
example, in some user agents `contextmenu` will often follow a
[`pointerup`](#dfn-pointerup), while in others it\'ll often precede a
[`pointerup`](#dfn-pointerup) or
[`pointercancel`](#dfn-pointercancel), and in some situations
it may be fired without any corresponding pointer event (for instance,
as a result of a keyboard interaction).

In addition, user agents may apply their own heuristics to determine
whether or not a `click`, `auxclick`, or `contextmenu` event should be
fired. Some user agents may choose not to fire these events if there are
other (non-primary) pointers of the same type, or other primary pointers
of a different type. User agents may determine that a particular action
was not a \"clean\" tap, click, or long-press (for instance, if an
interaction with a finger on a touch screen includes too much movement
while the finger is in contact with the screen) and decide not to fire a
`click`, `auxclick`, or `contextmenu` event. These aspects of user agent
behavior are not defined in this specification, and they may differ
between implementations.

Unless otherwise noted, the target of any mapped mouse event *SHOULD* be
the same target as the respective pointer event unless the target is no
longer participating in its `ownerDocument`\'s tree. In this case, the
mouse event should be fired at the original target\'s nearest ancestor
node (at the time it was removed from the tree) that still participates
in its `ownerDocument`\'s tree, meaning that a new event path (based on
the new target node) is built for the mouse event.

Authors can prevent the production of certain compatibility mouse events
by canceling the
[`pointerdown`](#dfn-pointerdown) event.

Mouse events can only be prevented when the pointer is down. Hovering
pointers (e.g. a mouse with no buttons pressed) cannot have their mouse
events prevented.

The `mouseover`, `mouseout`, `mouseenter`, and `mouseleave` events are
never prevented (even if the pointer is down).

Compatibility mouse events can\'t be prevented when a pointer event
[`EventListener`](https://dom.spec.whatwg.org/#callbackdef-eventlistener) is set to be
[`passive`](https://dom.spec.whatwg.org/#dom-addeventlisteneroptions-passive)
\[[DOM](#bib-dom "DOM Standard")\].

::: header-wrapper
### 10.1 [Tracking the effective position of the legacy mouse pointer]

While only [primary
pointers](#dfn-primary-pointer) can produce compatibility mouse events,
[multiple primary pointers](#multiple-primary-pointers) can be active
simultaneously, each producing its own compatibility mouse events. For
compatibility with scripts relying on MouseEvents, the mouse transition
events (`mouseover`, `mouseout`, `mouseenter` and `mouseleave`) *SHOULD*
simulate the movement of a *single* legacy mouse input. This means that
the entry/exit state for every event target is valid. User agents
*SHOULD* guarantee this by maintaining the [effective position of the
legacy mouse pointer] in the document as
follows.

Right before firing a
[`pointerdown`](#dfn-pointerdown),
[`pointerup`](#dfn-pointerup) or
[`pointermove`](#dfn-pointermove) event, or a
[`pointerleave`](#dfn-pointerleave) event at the `window`,
the user agent *SHOULD* run the following steps:

1. Let `T` be the target of the
 [`pointerdown`](#dfn-pointerdown),
 [`pointerup`](#dfn-pointerup) or
 [`pointermove`](#dfn-pointermove) event being
 dispatched. For the
 [`pointerleave`](#dfn-pointerleave) event, unset
 `T`.
2. If `T` and current [effective legacy mouse pointer
 position](#dfn-effective-legacy-mouse-pointer-position) are both unset or they are equal,
 terminate these steps.
3. Dispatch `mouseover`, `mouseout`, `mouseenter` and `mouseleave`
 events as per Mouse Events for a mouse moving from the current
 [effective legacy mouse pointer
 position](#dfn-effective-legacy-mouse-pointer-position) to `T`. Consider an unset
 value of either current [effective legacy mouse pointer
 position](#dfn-effective-legacy-mouse-pointer-position) or `T` as an out-of-window
 mouse position.
4. Set [effective legacy mouse pointer
 position](#dfn-effective-legacy-mouse-pointer-position) to `T`.

The [effective position of the legacy mouse
pointer](#dfn-effective-legacy-mouse-pointer-position) models the fact that we cannot always have
a direct mapping from pointer transition events (`pointerover`,
`pointerout`, `pointerenter` and `pointerleave`) to corresponding legacy
mouse transition events (`mouseover`, `mouseout`, `mouseenter` and
`mouseleave`). The following animation illustrates a case where a user
agent needs to dispatch more legacy mouse transition events than pointer
transition events to be able to reconcile two primary pointers using a
single legacy mouse input.

<figure id="legacy-pointer-transition">

<figcaption><a href="#legacy-pointer-transition"
class="self-link">Figure 9</a> <span class="fig-title"> Simultaneous
mouse pointer (white cursor) and touch pointer (white "hand" cursor)
causing the single legacy mouse input (orange cursor) to move between
the two pointers. </span></figcaption>
</figure>

In this animation, note the time period between the mouse click and the
touch tap. Button 1 receives no `pointerout` event (because the \"real\"
mouse pointer didn\'t leave the button rectangle within this period),
but Button 1 receives a `mouseout` event when the [effective position of
the legacy mouse
pointer](#dfn-effective-legacy-mouse-pointer-position) moves to Button 2 on touch tap. Similarly,
in the time period between the touch tap and the moment before the mouse
leaves Button 1, Button 1 receives no `pointerover` event for the same
reason, but Button 1 receives a `mouseover` event when the [effective
position of the legacy mouse
pointer](#dfn-effective-legacy-mouse-pointer-position) moves back inside Button 1.

::: header-wrapper
### 10.2 Mapping for devices that support hover

Whenever the user agent is to dispatch a pointer event for a device that
supports hover, it *SHOULD* run the following steps:

1. If the `isPrimary` property for the pointer event to be dispatched
 is `false` then dispatch the pointer event and terminate these
 steps.
2. If the pointer event to be dispatched is a
 [`pointerdown`](#dfn-pointerdown),
 [`pointerup`](#dfn-pointerup) or
 [`pointermove`](#dfn-pointermove) event, or a
 [`pointerleave`](#dfn-pointerleave) event at the
 `window`, dispatch compatibility mouse transition events as
 described in [Tracking the effective position of the legacy mouse
 pointer](#dfn-tracking-the-effective-position-of-the-legacy-mouse-pointer).
3. Dispatch the pointer event.
4. If the pointer event dispatched was
 [`pointerdown`](#dfn-pointerdown) and event\'s
 [canceled
 flag](https://dom.spec.whatwg.org/#canceled-flag)
 is set, then set the `PREVENT MOUSE EVENT` flag for this
 `pointerType`.
5. If the `PREVENT MOUSE EVENT` flag is **not** set for this
 `pointerType` and the pointer event dispatched was:
 - [`pointerdown`](#dfn-pointerdown), then fire a
 `mousedown` event.
 - [`pointermove`](#dfn-pointermove), then fire a
 `mousemove` event.
 - [`pointerup`](#dfn-pointerup), then fire a
 `mouseup` event.
 - [`pointercancel`](#dfn-pointercancel), then fire a
 `mouseup` event at the `window`.
6. If the pointer event dispatched was
 [`pointerup`](#dfn-pointerup) or
 [`pointercancel`](#dfn-pointercancel), clear the
 `PREVENT MOUSE EVENT` flag for this `pointerType`.

::: header-wrapper
### 10.3 Mapping for devices that do not support hover

Some devices, such as most touchscreens, do not support hovering a
coordinate (or set of coordinates) while not in the active state. Much
existing content coded to mouse events assumes that a mouse is producing
the events and thus certain qualities are generally true:

- The input can hover independently of activation (e.g. moving a mouse
 cursor without any buttons pressed).
- The input will likely produce the `mousemove` event on an element
 before clicking it.

Hover is sometimes used to toggle the visibility of UI elements in
content designed for mouse (e.g. \"hover menus\"). This content is often
incompatible with [devices that do not support
hover](#mapping-for-devices-that-do-not-support-hover). This
specification does not define a mapping or behavior for compatibility
with this scenario. It will be considered in a future version of the
specification.

This requires that user agents provide a different mapping for these
types of input devices. Whenever the user agent is to dispatch a pointer
event for a device that [does not support
hover](#mapping-for-devices-that-do-not-support-hover), it *SHOULD* run
the following steps:

1. If the `isPrimary` property for the pointer event to be dispatched
 is `false` then dispatch the pointer event and terminate these
 steps.
2. If the pointer event to be dispatched is
 [`pointerover`](#dfn-pointerover) and the
 [`pointerdown`](#dfn-pointerdown) event has not yet
 been dispatched for this pointer, then fire a `mousemove` event (for
 compatibility with legacy mouse-specific code).
3. If the pointer event to be dispatched is a
 [`pointerdown`](#dfn-pointerdown),
 [`pointerup`](#dfn-pointerup) or
 [`pointermove`](#dfn-pointermove) event, or a
 [`pointerleave`](#dfn-pointerleave) event at the
 `window`, dispatch compatibility mouse transition events as
 described in [Tracking the effective position of the legacy mouse
 pointer](#dfn-tracking-the-effective-position-of-the-legacy-mouse-pointer).
4. Dispatch the pointer event.
5. If the pointer event dispatched was
 [`pointerdown`](#dfn-pointerdown) and event\'s
 [canceled
 flag](https://dom.spec.whatwg.org/#canceled-flag)
 is set, then set the `PREVENT MOUSE EVENT` flag for this
 `pointerType`.
6. If the `PREVENT MOUSE EVENT` flag is **not** set for this
 `pointerType` and the pointer event dispatched was:
 - [`pointerdown`](#dfn-pointerdown), then fire a
 `mousedown` event.
 - [`pointermove`](#dfn-pointermove), then fire a
 `mousemove` event.
 - [`pointerup`](#dfn-pointerup), then fire a
 `mouseup` event.
 - [`pointercancel`](#dfn-pointercancel), then fire a
 `mouseup` event at the `window`.
7. If the pointer event dispatched was
 [`pointerup`](#dfn-pointerup) or
 [`pointercancel`](#dfn-pointercancel), clear the
 `PREVENT MOUSE EVENT` flag for this `pointerType`.

If the user agent supports both Touch Events (as defined in
\[[TOUCH-EVENTS](#bib-touch-events "Touch Events")\]) and Pointer Events, the [user
agent](https://infra.spec.whatwg.org/#user-agent) *MUST
NOT* generate *both* the compatibility mouse events as described in this
section, and the [fallback mouse
events](https://www.w3.org/TR/touch-events/#mouse-events) outlined in
\[[TOUCH-EVENTS](#bib-touch-events "Touch Events")\].

The activation of an element (`click`) with a primary pointer that [does
not support hover](#mapping-for-devices-that-do-not-support-hover) (e.g.
single finger on a touchscreen) would typically produce the following
event sequence:

1. `mousemove`
2. [`pointerover`](#dfn-pointerover)
3. `pointerenter`
4. `mouseover`
5. `mouseenter`
6. [`pointerdown`](#dfn-pointerdown)
7. `mousedown`
8. Zero or more
 [`pointermove`](#dfn-pointermove) and `mousemove`
 events, depending on movement of the pointer
9. [`pointerup`](#dfn-pointerup)
10. `mouseup`
11. [`pointerout`](#dfn-pointerout)
12. [`pointerleave`](#dfn-pointerleave)
13. `mouseout`
14. `mouseleave`
15. `click`

If, however, the
[`pointerdown`](#dfn-pointerdown) event [canceled
flag](https://dom.spec.whatwg.org/#canceled-flag) is
set during this interaction then the sequence of events would be:

1. `mousemove`
2. [`pointerover`](#dfn-pointerover)
3. `pointerenter`
4. `mouseover`
5. `mouseenter`
6. [`pointerdown`](#dfn-pointerdown)
7. Zero or more
 [`pointermove`](#dfn-pointermove) events, depending on
 movement of the pointer
8. [`pointerup`](#dfn-pointerup)
9. [`pointerout`](#dfn-pointerout)
10. [`pointerleave`](#dfn-pointerleave)
11. `mouseout`
12. `mouseleave`
13. `click`

::: header-wrapper
## 11. Mouse Events and Interfaces

The mouse event module originates from the
\[[HTML401](#bib-html401 "HTML 4.01 Specification")\] `onclick`, `ondblclick`, `onmousedown`,
`onmouseup`, `onmouseover`, `onmousemove`, and `onmouseout` attributes.
This event module is specifically designed for use with pointing input
devices, such as a mouse or a trackball.

Introduced in DOM Level 2, modified in this specification.

The [`MouseEvent`](#dom-mouseevent) interface provides
specific contextual information associated with Mouse events.

In the case of nested elements, mouse events are always targeted at the
most deeply nested element.

Ancestors of the targeted element can use event bubbling to obtain
notifications of mouse events which occur within their descendent
elements.

To create an instance of the
[`MouseEvent`](#dom-mouseevent) interface, use the
[`MouseEvent`](#dom-mouseevent) constructor, passing an optional
[`MouseEventInit`](#dom-mouseeventinit) dictionary.

When initializing
[`MouseEvent`](#dom-mouseevent) objects using `initMouseEvent`,
implementations can use the client coordinates
[`clientX`](#dom-mouseevent-clientx) and
[`clientY`](#dom-mouseevent-clienty) for calculation of other coordinates (such
as target coordinates exposed by DOM Level 0 implementations or other
proprietary attributes, e.g., `pageX`).

::: header-wrapper
### 11.1 `MouseEvent` interface

```
WebIDLdictionary MouseEventInit : EventModifierInit {
 long screenX = 0;
 long screenY = 0;
 long clientX = 0;
 long clientY = 0;

 short button = 0;
 unsigned short buttons = 0;
 EventTarget? relatedTarget = null;
};

[Exposed=Window]
interface MouseEvent : UIEvent {
 constructor(DOMString type, optional MouseEventInit eventInitDict = );
 readonly attribute long screenX;
 readonly attribute long screenY;
 readonly attribute long clientX;
 readonly attribute long clientY;
 readonly attribute long layerX;
 readonly attribute long layerY;

 readonly attribute boolean ctrlKey;
 readonly attribute boolean shiftKey;
 readonly attribute boolean altKey;
 readonly attribute boolean metaKey;

 readonly attribute short button;
 readonly attribute unsigned short buttons;

 readonly attribute EventTarget? relatedTarget;

 boolean getModifierState(DOMString keyArg);
};
```

[`screenX`]

: The horizontal coordinate at which the event occurred relative to
 the origin of the screen coordinate system.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0`.

[`screenY`]

: The vertical coordinate at which the event occurred relative to the
 origin of the screen coordinate system.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0`.

[`clientX`]

: The horizontal coordinate at which the event occurred relative to
 the viewport associated with the event.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0`.

[`clientY`]

: The vertical coordinate at which the event occurred relative to the
 viewport associated with the event.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0`.

[`layerX`]

: The horizontal offset from the nearest
 [ancestor](https://dom.spec.whatwg.org/#concept-tree-ancestor)
 element which is a [stacking
 context](https://www.w3.org/TR/CSS2/visuren.html#x43){
 cite-href="https://www.w3.org/TR/CSS2/visuren.html#x43"}, is
 [positioned](https://www.w3.org/TR/css-position-3/#positioned-box),
 or paints in the positioned phase when [painting a stacking
 context](https://www.w3.org/TR/css-position-3/#paint-a-stacking-context).

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0`.

[`layerY`]

: The vertical offset from the nearest
 [ancestor](https://dom.spec.whatwg.org/#concept-tree-ancestor)
 element which is a [stacking
 context](https://www.w3.org/TR/CSS2/visuren.html#x43){
 cite-href="https://www.w3.org/TR/CSS2/visuren.html#x43"}, is
 [positioned](https://www.w3.org/TR/css-position-3/#positioned-box),
 or paints in the positioned phase when [painting a stacking
 context](https://www.w3.org/TR/css-position-3/#paint-a-stacking-context).

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0`.

[`ctrlKey`]

: Refer to the
 [`KeyboardEvent`](https://www.w3.org/TR/uievents/#keyboardevent)\'s
 [`ctrlKey`](https://www.w3.org/TR/uievents/#dom-keyboardevent-ctrlkey)
 attribute.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `false`.

[`shiftKey`]

: Refer to the
 [`KeyboardEvent`](https://www.w3.org/TR/uievents/#keyboardevent)\'s
 [`shiftKey`](https://www.w3.org/TR/uievents/#dom-keyboardevent-shiftkey)
 attribute.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `false`.

[`altKey`]

: Refer to the
 [`KeyboardEvent`](https://www.w3.org/TR/uievents/#keyboardevent)\'s
 [`altKey`](https://www.w3.org/TR/uievents/#dom-keyboardevent-altkey)
 attribute.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `false`.

[`metaKey`]

: Refer to the
 [`KeyboardEvent`](https://www.w3.org/TR/uievents/#keyboardevent)\'s
 [`metaKey`](https://www.w3.org/TR/uievents/#dom-keyboardevent-metakey)
 attribute.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `false`.

[`button`]

: During mouse events caused by the depression or release of a mouse
 button,
 [`button`](#dom-mouseevent-button) *MUST* be used to indicate which
 pointer device button changed state.

 The value of the
 [`button`](#dom-mouseevent-button) attribute *MUST* be as follows:

 - `0` *MUST* indicate the primary button of the device (in general,
 the left button or the only button on single-button devices, used
 to activate a user interface control or select text) or the
 un-initialized value.
 - `1` *MUST* indicate the auxiliary button (in general, the middle
 button, often combined with a mouse wheel).
 - `2` *MUST* indicate the secondary button (in general, the right
 button, often used to display a context menu).
 - `3` *MUST* indicate the X1 (back) button.
 - `4` *MUST* indicate the X2 (forward) button.

 Some pointing devices provide or simulate more button states, and
 values higher than `2` or lower than `0` *MAY* be used to represent
 such buttons.

 ::::
 :::
 Note
 :::

 The value of
 [`button`](#dom-mouseevent-button) is not updated for events not caused
 by the depression/release of a mouse button. In these scenarios,
 take care not to interpret the value `0` as the left button, but
 rather as the default value.
 ::::

 ::::
 :::
 Note
 :::

 Some [default
 actions](https://www.w3.org/TR/uievents/#default-action)
 related to events such as
 [`mousedown`](#dfn-mousedown) and
 [`mouseup`](#dfn-mouseup) depend on the specific mouse button in
 use.
 ::::

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0`.

[`buttons`]

: During any mouse events,
 [`buttons`](#dom-mouseevent-buttons) *MUST* be used to indicate which
 combination of mouse buttons are currently being pressed, expressed
 as a bitmask.

 ::::
 :::
 Note
 :::

 The
 [`buttons`](#dom-mouseevent-buttons) attribute is a bit-field. If a mask
 value of 1 is true when applied to the value of the bit field, then
 the primary mouse button is down. If a mask value of 2 is true when
 applied to the value of the bit field, then the right mouse button
 is down. If a mask value of 4 is true when applied to the value of
 the bit field, then the auxiliary/middle button is down.
 ::::

 ::::
 :::
 Note
 :::

 Though similarly named, the values for the
 [`buttons`](#dom-mouseevent-buttons) attribute and the
 [`button`](#dom-mouseevent-button) attribute are very different. The
 value of
 [`button`](#dom-mouseevent-button) is assumed to be valid during
 [`mousedown`](#dfn-mousedown) /
 [`mouseup`](#dfn-mouseup) event handlers, whereas the
 [`buttons`](#dom-mouseevent-buttons) attribute reflects the state of the
 mouse\'s buttons for any trusted
 [`MouseEvent`](#dom-mouseevent) object (while it is
 being dispatched), because it can represent the \"no button
 currently active\" state (0).
 ::::

 The value of the
 [`buttons`](#dom-mouseevent-buttons) attribute *MUST* be as follows:

 - `0` *MUST* indicate no button is currently active.
 - `1` *MUST* indicate the primary button of the device (in general,
 the left button or the only button on single-button devices, used
 to activate a user interface control or select text).
 - `2` *MUST* indicate the secondary button (in general, the right
 button, often used to display a context menu), if present.
 - `4` *MUST* indicate the auxiliary button (in general, the middle
 button, often combined with a mouse wheel).

 Some pointing devices provide or simulate more buttons. To represent
 such buttons, the value *MUST* be doubled for each successive button
 (in the binary series `8`, `16`, `32`, \... ).

 ::::
 :::
 Note
 :::

 Because the sum of any set of button values is a unique number, a
 content author can use a bitwise operation to determine how many
 buttons are currently being pressed and which buttons they are, for
 an arbitrary number of mouse buttons on a device. For example, the
 value `3` indicates that the left and right button are currently
 both pressed, while the value `5` indicates that the left and middle
 button are currently both pressed.
 ::::

 ::::
 :::
 Note
 :::

 Some [default
 actions](https://www.w3.org/TR/uievents/#default-action)
 related to events such as
 [`mousedown`](#dfn-mousedown) and
 [`mouseup`](#dfn-mouseup) depend on the specific mouse button in
 use.
 ::::

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0`.

[`relatedTarget`]

: Used to identify a secondary
 [`EventTarget`](https://dom.spec.whatwg.org/#eventtarget) related to a UI event, depending on the type of
 event.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `null`.

 The
 [`relatedTarget`](#dom-mouseevent-relatedtarget) should be initialized to the element
 whose bounds the mouse pointer just left (in the case of a
 [`mouseover`](#dfn-mouseover) or
 [`mouseenter`](#dfn-mouseenter) event) or the element
 whose bounds the mouse pointer is entering (in the case of a
 [`mouseout`](#dfn-mouseout) or
 [`mouseleave`](#dfn-mouseleave) or
 [focusout](https://www.w3.org/TR/uievents/#focusout)
 event). For other events, this value need not be assigned (and will
 default to null).

[`getModifierState(keyArg)`]

: Queries the state of a modifier using a key value.

 Returns `true` if it is a modifier key and the modifier is
 activated, `false` otherwise.

 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) keyArg
 : Refer to the
 [`KeyboardEvent`](https://www.w3.org/TR/uievents/#keyboardevent)\'s
 [`getModifierState`](https://www.w3.org/TR/uievents/#dom-keyboardevent-getmodifierstate)`()` method for a description of this
 parameter.

Implementations *MUST* maintain the [current click
count] when generating mouse events. This *MUST* be a
non-negative integer indicating the number of consecutive clicks of a
pointing device button within a specific time. The delay after which the
count resets is specific to the environment configuration.

::: header-wrapper
### 11.2 MouseEvent Algorithms

::: header-wrapper
#### 11.2.1 Native OS Requirements

The algorithms in this section assume that the native platform OS will
provide the following:

- An event when the mouse is moved (handled by [handle native mouse
 move](#dfn-handle-native-mouse-move))
- An event when a mouse button is pressed (handled by [handle native
 mouse
 down](#dfn-handle-native-mouse-down))
- An event when a mouse button is released (handled by [handle native
 mouse
 up](#dfn-handle-native-mouse-up))
- A way to identify when a mouse button press should be interpreted as a
 \"click\" (handled by [handle native mouse
 click](#dfn-handle-native-mouse-click))
 - For example, as a flag or as a separate event
 - If a separate \"click\" event is fired, then the native OS will fire
 it immediately after the corresponding \"mouse up\" event, with no
 intervening mouse-related events
- A way to identify when a mouse click is a \"double click\" (handled by
 [handle native mouse double
 click](#dfn-handle-native-mouse-double-click))

For these events, the OS will be able to provide the following info:

- The x,y mouse coordinates relative to the native OS desktop
- The x,y mouse coordinates relative to the UA\'s window viewport
- Which keyboard modifiers are currently being held

::: header-wrapper
#### 11.2.2 Constructing Mouse Events

This section needs to be revised.

Generally, when a constructor of an
[`Event`](https://dom.spec.whatwg.org/#event) interface, or of an interface inherited from the
[`Event`](https://dom.spec.whatwg.org/#event) interface, is invoked, the steps described in
\[[DOM](#bib-dom "DOM Standard")\] should be
followed. However the
[`MouseEvent`](#dom-mouseevent) interfaces provide additional
dictionary members for initializing the internal state of the
[`Event`](https://dom.spec.whatwg.org/#event) object\'s key modifiers: specifically, the internal state
queried for using the
[`getModifierState`](#dom-mouseevent-getmodifierstate)`()` methods. This
section supplements the \[[DOM](#bib-dom "DOM Standard")\] steps for intializing a new
[`MouseEvent`](#dom-mouseevent) object with these optional modifier
states.

For the purposes of constructing a
[`MouseEvent`](#dom-mouseevent), or object derived from these objects
using the algorithm below, all
[`MouseEvent`](#dom-mouseevent), and derived objects have [internal key
modifier state] which can be set and retrieved
using the [key modifier
names](https://www.w3.org/TR/uievents/#keys-modifiers) described in the
[Modifier Keys table](https://www.w3.org/TR/uievents-key/#keys-modifier)
in
\[[UIEvents-Key](#bib-uievents-key "UI Events KeyboardEvent key Values")\].

The following steps supplement the algorithm defined for constructing
events in \[[DOM](#bib-dom "DOM Standard")\]:

- If the
 [`Event`](https://dom.spec.whatwg.org/#event) being constructed is a
 [`MouseEvent`](#dom-mouseevent) object or an object that
 derives from it, and a
 [`EventModifierInit`](https://www.w3.org/TR/uievents/#dictdef-eventmodifierinit) argument was provided to the constructor, then
 run the following sub-steps:
 - For each
 [`EventModifierInit`](https://www.w3.org/TR/uievents/#dictdef-eventmodifierinit) argument, if the dictionary member begins
 with the string `"modifier"`, then let the [key modifier
 name] be the
 dictionary member\'s name excluding the prefix `"modifier"`, and set
 the
 [`Event`](https://dom.spec.whatwg.org/#event) object\'s [internal key modifier
 state](#dfn-internal-key-modifier-state) that matches the [key
 modifier
 name](#dfn-key-modifier-name) to the corresponding
 value.

::: header-wrapper
#### 11.2.3 Global State for MouseEvent

This section needs to be revised.

::: header-wrapper
##### 11.2.3.1 User Agent-Level State

The UA must maintain the following values that are shared for the entire
User Agent.

A [mouse button bitmask] that tracks the current state of
the mouse buttons.

::: header-wrapper
##### 11.2.3.2 Window-Level State

The UA must maintain the following values that are shared for the
Window.

A [last mouse element] value (initially undefined) that
keeps track of the last
[`Element`](https://dom.spec.whatwg.org/#element) that we sent a MouseEvent to.

A [last mouse DOM path] value (initially empty) that
contains a snapshot of the ancestors
[`Element`](https://dom.spec.whatwg.org/#element)s of the [last mouse
element](#dfn-last-mouse-element) when the most recent mouse event was sent.

::: header-wrapper
#### 11.2.4 Internal State for MouseEvent

This section needs to be revised.

A [`MouseEvent`](#dom-mouseevent) has the following internal
flags that are used to track the state of various modifier keys: [shift
flag], [control flag], [alt flag], [altgraph
flag], and [meta flag]. These flags are set if the
corresponding modifier key was pressed at the time of the mouse event.

::: header-wrapper
#### 11.2.5 [hit test]

This section needs to be revised.

1. Let `pos` be the x,y coordinates relative to the viewport
2. Return \[[CSSOM-View](#bib-cssom-view "CSSOM View Module")\]\'s
 [`elementFromPoint`](https://www.w3.org/TR/cssom-view-1/#dom-document-elementfrompoint)`()` with `pos` (the frontmost
 DOM element at `pos`)

 ::::
 :::
 Note
 :::

 To account for
 [inert](https://html.spec.whatwg.org/multipage/#inert) or
 [disabled](https://html.spec.whatwg.org/multipage/#concept-fe-disabled)
 elements. this should call
 [`elementsFromPoint`](https://www.w3.org/TR/cssom-view-1/#dom-document-elementsfrompoint)`()` and reject invalid elements.
 ::::

::: header-wrapper
#### 11.2.6 initialize a [`MouseEvent`]
This section needs to be revised.

To [initialize a MouseEvent] with
`event`, `eventType` and `eventTarget`,
`bubbles`, and `cancelable`, run the following
steps:

1. [Initialize a
 UIEvent](https://www.w3.org/TR/uievents/#initialize-a-uievent)
 with `event`, `eventType`,
 `eventTarget`, `bubbles` and
 `cancelable`.
2. Set
 `event`.[`screenX`](#dom-mouseevent-screenx) to the x-coordinate of the position
 where the event occurred relative to the origin of the desktop
3. Set
 `event`.[`screenY`](#dom-mouseevent-screeny) to the y-coordinate of the position
 where the event occurred relative to the origin of the desktop
4. Set
 `event`.[`clientX`](#dom-mouseevent-clientx) to the x-coordinate of the position
 where the event occurred relative to the origin of the
 [viewport](https://www.w3.org/TR/CSS2/visuren.html#x1){
 cite-href="https://www.w3.org/TR/CSS2/visuren.html#x1"}
5. Set
 `event`.[`clientY`](#dom-mouseevent-clienty) to the y-coordinate of the position
 where the event occurred relative to the origin of the
 [viewport](https://www.w3.org/TR/CSS2/visuren.html#x1){
 cite-href="https://www.w3.org/TR/CSS2/visuren.html#x1"}
6. [Set mouse event
 modifiers](#dfn-set-mouse-event-modifiers) with `event`
7. Set
 `event`.[`button`](#dom-mouseevent-button) to 0
8. Set
 `event`.[`buttons`](#dom-mouseevent-buttons) to [mouse button
 bitmask](#dfn-mouse-button-bitmask)
9. [Initialize PointerLock attributes for
 MouseEvent](https://www.w3.org/TR/uievents/#initialize-pointerlock-attributes-for-mouseevent)
 with `event`

 ::::
 :::
 Issue 1
 :::

 We should provide a hook for PointerLock instead of hardcoding it
 here.
 ::::

::: header-wrapper
#### 11.2.7 [set mouse event modifiers]

This section needs to be revised.

1. Let `event` be the
 [`MouseEvent`](#dom-mouseevent) to update
2. Set `event`\'s [shift
 flag](#dfn-shift-flag) if [key modifier
 state](https://www.w3.org/TR/uievents/#key-modifier-state)
 includes \"Shift\", unset it otherwise
3. Set `event`\'s [control
 flag](#dfn-control-flag) if [key modifier
 state](https://www.w3.org/TR/uievents/#key-modifier-state)
 includes \"Control\", unset it otherwise
4. Set `event`\'s [alt
 flag](#dfn-alt-flag) if [key modifier
 state](https://www.w3.org/TR/uievents/#key-modifier-state)
 includes \"Alt\", unset it otherwise
5. Set `event`\'s [altgraph
 flag](#dfn-altgraph-flag) if [key modifier
 state](https://www.w3.org/TR/uievents/#key-modifier-state)
 includes \"AltGraph\", unset it otherwise
6. Set `event`\'s [meta
 flag](#dfn-meta-flag) if [key modifier
 state](https://www.w3.org/TR/uievents/#key-modifier-state)
 includes \"Meta\", unset it otherwise
7. Set
 `event`.[`shiftKey`](#dom-mouseevent-shiftkey) to true if the event\'s [shift
 flag](#dfn-shift-flag) is set, false otherwise
8. Set
 `event`.[`ctrlKey`](#dom-mouseevent-ctrlkey) to true if the event\'s [control
 flag](#dfn-control-flag) is set, false otherwise
9. Set
 `event`.[`altKey`](#dom-mouseevent-altkey) to true if the event\'s [alt
 flag](#dfn-alt-flag) or [altgraph
 flag](#dfn-altgraph-flag) is set, false otherwise
10. Set
 `event`.[`metaKey`](#dom-mouseevent-metakey) to true if the event\'s [meta
 flag](#dfn-meta-flag) is set, false otherwise

::: header-wrapper
#### 11.2.8 [create a cancelable MouseEvent]

This section needs to be revised.

1. Let `eventType` be a DOMString containing a valid
 [`MouseEvent`](#dom-mouseevent) type
2. Let `eventTarget` be the
 [`EventTarget`](https://dom.spec.whatwg.org/#eventtarget) of the event
3. Let `bubbles` be true
4. Let `cancelable` be true
5. Let `event` be the result of [creating an
 event](https://dom.spec.whatwg.org/#concept-event-create)
 using [`MouseEvent`](#dom-mouseevent)
6. [Initialize a
 MouseEvent](#dfn-initialize-a-mouseevent) with `event`,
 `eventType`, `eventTarget`,
 `bubbles` and `cancelable`.
7. Return `event`

::: header-wrapper
#### 11.2.9 [create a non-cancelable MouseEvent]

This section needs to be revised.

1. Let `eventType` be a DOMString containing a valid
 [`MouseEvent`](#dom-mouseevent) type
2. Let `eventTarget` be the
 [`EventTarget`](https://dom.spec.whatwg.org/#eventtarget) of the event
3. Let `bubbles` be \"false\"
4. Let `cancelable` be \"false\"
5. Let `event` be the result of [creating an
 event](https://dom.spec.whatwg.org/#concept-event-create)
 using [`MouseEvent`](#dom-mouseevent)
6. [Initialize a
 MouseEvent](#dfn-initialize-a-mouseevent) with `event`,
 `eventType`, `eventTarget`,
 `bubbles` and `cancelable`.
7. Return `event`

::: header-wrapper
#### 11.2.10 [calculate MouseEvent button attribute]

This section needs to be revised.

This will return a button ID suitable for storing in the
[`MouseEvent`](#dom-mouseevent)\'s
[`button`](#dom-mouseevent-button) attribute.

1. Let `mbutton` be an ID that identifies a mouse button
2. If `mbutton` is the primary mouse button, then return 0
3. If `mbutton` is the auxiliary (middle) mouse button, then
 return 1
4. If `mbutton` is the secondary mouse button, then return 2
5. If `mbutton` is the X1 (back) button, then return 3
6. If `mbutton` is the X2 (forward) button, then return 4

::: header-wrapper
#### 11.2.11 [set MouseEvent attributes from native]

This section needs to be revised.

1. Let `event` be the
 [`MouseEvent`](#dom-mouseevent) to initialize
2. Let `native` be the native mouse event

 ::::
 :::
 Editor\'s note
 :::

 TODO.
 ::::
3. If
 `event`.[`type`](https://dom.spec.whatwg.org/#dom-event-type)
 is one of \[ mousedown, mouseup \], then
 1. Let `mbutton` be an ID from `native` that
 identifies which mouse button was pressed
 2. Set
 `event`.[`button`](#dom-mouseevent-button) to [calculate MouseEvent button
 attribute](#dfn-calculate-mouseevent-button-attribute) with `mbutton`

::: header-wrapper
#### 11.2.12 [handle native mouse down]

This section needs to be revised.

1. Let `native` be the native mousedown
2. Let `mbutton` be an ID from `native` that
 identifies which mouse button was pressed
3. Update the [mouse button
 bitmask](#dfn-mouse-button-bitmask) as follows:
 1. If `mbutton` is the primary mouse button, then set
 the 0x01 bit
 2. If `mbutton` is the secondary mouse button, then set
 the 0x02 bit
 3. If `mbutton` is the auxiliary (middle) mouse button,
 then set the 0x04 bit

 ::::
 :::
 Note
 :::

 Other buttons can be added starting with 0x08 .
 ::::
4. Let `target` be [hit
 test](#dfn-hit-test) with viewport-relative coordinates from
 `native`
5. Let `event` be the result of [creating a cancelable
 MouseEvent](#dfn-creating-a-cancelable-mouseevent) with \"mousedown\",
 `target`
6. [Set MouseEvent attributes from
 native](#dfn-set-mouseevent-attributes-from-native) with `native`
7. Maybe send pointerdown event with `event`
8. Let `result` be
 [dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)
 `event` at `target`
9. If `result` is true and `target` is a
 [focusable
 area](https://html.spec.whatwg.org/multipage/#focusable-area) that
 is [click
 focusable](https://html.spec.whatwg.org/multipage/#click-focusable),
 then
 1. Run the [focusing
 steps](https://html.spec.whatwg.org/multipage/interaction.html#focusing-steps)
 at `target`
10. if `mbutton` is the secondary mouse button, then
 1. [Maybe show context
 menu](#dfn-maybe-show-context-menu) with `native`,
 `target`

::: header-wrapper
#### 11.2.13 [handle native mouse up]

This section needs to be revised.

1. Let `native` be the native mouseup

 ::::
 :::
 Note
 :::

 Other mouse events can occur between the mousedown and mouseup.
 ::::
2. Let `mbutton` be an ID from `native` that
 identifies which mouse button was pressed
3. Update the [mouse button
 bitmask](#dfn-mouse-button-bitmask) as follows:
 1. If `mbutton` is the primary mouse button, then clear
 the 0x01 bit
 2. If `mbutton` is the secondary mouse button, then
 clear the 0x02 bit
 3. If `mbutton` is the auxiliary (middle) mouse button,
 then clear the 0x04 bit
4. Let `target` be [hit
 test](#dfn-hit-test) with viewport-relative coordinates from
 `native`
5. Let `event` be the result of [creating a cancelable
 MouseEvent](#dfn-creating-a-cancelable-mouseevent) with \"mouseup\", `target`
6. [Set MouseEvent attributes from
 native](#dfn-set-mouseevent-attributes-from-native) with `native`
7. Maybe send pointerup event with `event`
8. [dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)
 `event` at `target`

::: header-wrapper
#### 11.2.14 [handle native mouse click]

This section needs to be revised.

1. Let `native` be the native mouse click

 ::::
 :::
 Note
 :::

 The platform should call this immediately after [handle native mouse
 up](#dfn-handle-native-mouse-up) for mouseups that generate clicks.
 ::::
2. Let `target` be [hit
 test](#dfn-hit-test) with viewport-relative coordinates from
 `native`
3. [Send click
 event](#dfn-send-click-event) with `native` and
 `target`.

::: header-wrapper
#### 11.2.15 [send click event]

This section needs to be revised.

1. Let `native` be the native mousedown
2. Let `target` be the
 [`EventTarget`](https://dom.spec.whatwg.org/#eventtarget) of the event
3. Let `mbutton` be 1 (primary mouse button by default)
4. If `native` is valid, then
 1. Let `mbutton` be an ID from `native` that
 identifies which mouse button was pressed
5. Set `eventType` to \"click\" if `mbutton` is
 the primary mouse button, otherwise \"auxclick\"
6. Let `event` be the result of [creating a
 PointerEvent](#dfn-creating-a-pointerevent) with `eventType` and
 `target`
7. If `native` is valid, then
 1. [Set MouseEvent attributes from
 native](#dfn-set-mouseevent-attributes-from-native) with `event`,
 `native`
 2. If
 `event`.[`screenX`](#dom-mouseevent-screenx) is not an integer value, then
 round it.
 3. If
 `event`.[`screenY`](#dom-mouseevent-screeny) is not an integer value, then
 round it.
8. [dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)
 `event` at `target`

 ::::
 :::
 Note
 :::

 See
 [pointerevents/100](https://github.com/w3c/pointerevents/issues/100)
 for info about browsers using PointerEvents and rounded coordinates.
 ::::

 ::::
 :::
 Editor\'s note
 :::

 Any \"default action\" is handled during dispatch by triggering the
 [activation
 behavior](https://dom.spec.whatwg.org/#eventtarget-activation-behavior)
 algorithm for the target. So there is no need for handle that here.
 However, need to verify that the existing spec handles
 disabled/css-pointer-events/inert/\...
 ::::

 ::::
 :::
 Note
 :::

 To handle `HTMLelement.click()`, call this algorithm with
 `native` = null and `target` = `HTMLelement`.
 ::::

 ::::
 :::
 Note
 :::

 To handle keyboard-initiated clicks, call this algorithm with
 `native` = null and `target` = currently
 focused element.
 ::::

::: header-wrapper
#### 11.2.16 [handle native mouse double click]

This section needs to be revised.

1. Let `native` be the native mouse double click

 ::::
 :::
 Note
 :::

 This should be called immediately after handle native mouse click
 for mouse clicks that generate double clicks.
 ::::
2. Let `mbutton` be an ID from `native` that
 identifies which mouse button was pressed
3. If `mbutton` is not the primary mouse button, then return
4. Let `target` be [hit
 test](#dfn-hit-test) with viewport-relative coordinates from
 `native`
5. Let `event` be the result of [creating a
 PointerEvent](#dfn-creating-a-pointerevent) with \"dblclick\" and
 `target`
6. [Set MouseEvent attributes from
 native](#dfn-set-mouseevent-attributes-from-native) with `event`,
 `native`
7. If
 `event`.[`screenX`](#dom-mouseevent-screenx) is not an integer value, then round
 it.
8. If
 `event`.[`screenY`](#dom-mouseevent-screeny) is not an integer value, then round
 it.
9. [dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)
 `event` at `target`

::: header-wrapper
#### 11.2.17 [handle native mouse move]

This section needs to be revised.

1. Let `native` be the native mouse move

 ::::
 :::
 Issue 2
 :::

 This algorithm makes assumptions about the dispatch of PointerEvents
 because they are not currently specified explicitly. Once
 [pointerevents/285](https://github.com/w3c/pointerevents/issues/285)
 is resolved this may need to be updated.
 ::::
2. Let `target` be [hit
 test](#dfn-hit-test) with viewport-relative coordinates from
 `native`
3. Let `targetDomPath` be [inclusive
 ancestors](https://dom.spec.whatwg.org/#concept-tree-inclusive-ancestor)
 of `target`
4. Generate events for leaving the current element:
 1. If [last mouse
 element](#dfn-last-mouse-element) is defined and not equal to
 `target`, then
 1. Let `mouseout` be the result of [creating a
 cancelable
 MouseEvent](#dfn-creating-a-cancelable-mouseevent) with \"mouseout\" and [last
 mouse
 element](#dfn-last-mouse-element)

 ::::
 :::
 Editor\'s note
 :::

 TODO: Set `mouseout` attributes from
 `native`. +CSSOM attributes.
 ::::
 2. Maybe send pointerout event with `mouseout`
 3. [Dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)
 `mouseout` at `target`

 ::::
 :::
 Note
 :::

 Verify behavior when canceled (appears to have no effect).
 ::::
 4. Let `leaveElements` be a copy of [last mouse DOM
 path](#dfn-last-mouse-dom-path) with all elements common to
 `targetDomPath` removed.
 5. For each `element` in `leaveElements`, do

 ::::
 :::
 Editor\'s note
 :::

 Handle case where `element` has been deleted. Also
 case where it has been moved: Should the DOM mutation have
 triggered a mouseleave event? Should we sent it now? Should it
 be dropped? Need to verify what current browsers do.
 ::::

 1. Let `mouseleave` be the result of [creating a
 non-cancelable
 MouseEvent](#dfn-creating-a-non-cancelable-mouseevent) with \"mouseleave\" and
 `element`
 2. Set
 `mouseleave`.[`Event`](https://dom.spec.whatwg.org/#event).[`composed`](https://dom.spec.whatwg.org/#dom-event-composed)
 = false

 ::::
 :::
 Note
 :::

 Check compat: Value of event.composed. Spec says false.
 Chrome/Linux = true. Firefox/Linux = false.
 ::::
 3. Maybe send pointerleave event with `mouseleave`
 4. Let `result` be
 [dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)
 `mouseleave` at `element`
5. Generate events for entering the new element:
 1. If `target` is not [last mouse
 element](#dfn-last-mouse-element), then
 1. Let `mouseover` be the result of [creating a
 cancelable
 MouseEvent](#dfn-creating-a-cancelable-mouseevent) with \"mouseover\" and
 `target`

 ::::
 :::
 Editor\'s note
 :::

 TODO: Set `mouseout` attributes from
 `native`. +CSSOM attributes.
 ::::
 2. Maybe send pointerover event with `mouseover`
 3. [Dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)
 `mouseout` at `target`

 ::::
 :::
 Note
 :::

 Need to verify behavior when canceled (appears to have no
 effect).
 ::::
 4. Let `enterElements` be a copy of
 `targetDomPath` with all elements common to [last
 mouse DOM
 path](#dfn-last-mouse-dom-path) removed.
 5. For each `element` in `enterElements`,
 do

 ::::
 :::
 Note
 :::

 Handle case where `element` has been deleted or
 moved.
 ::::

 1. Let `mouseenter` be the result of [creating a
 non-cancelable
 MouseEvent](#dfn-creating-a-non-cancelable-mouseevent) with \"mouseenter\" and
 `element`
 2. Set
 `mouseenter`.[`Event`](https://dom.spec.whatwg.org/#event).[`composed`](https://dom.spec.whatwg.org/#dom-event-composed)
 = false

 ::::
 :::
 Note
 :::

 Check compat: Value of event.composed. Spec says false.
 Chrome/Linux = true. Firefox/Linux = false.
 ::::
 3. Maybe send pointerenter event with
 `mouseenter`

 ::::
 :::
 Note
 :::

 Check compat for shadow DOM elements. Chrome/Linux fires
 this event at the element and the shadow root.
 ::::
 4. Let `result` be
 [dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)
 `mouseenter` at `element`
 6. Set [last mouse
 element](#dfn-last-mouse-element) to `target`
 7. Set [last mouse DOM
 path](#dfn-last-mouse-dom-path) to `targetDomPath`
6. Let `mousemove` be the result of [creating a cancelable
 MouseEvent](#dfn-creating-a-cancelable-mouseevent) with \"mousemove\" and
 `element`
7. [Set PointerLock attributes for
 mousemove](https://www.w3.org/TR/uievents/#set-pointerlock-attributes-for-mousemove)
8. Maybe send pointermove event with `mousemove`
9. [Dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)
 `mousemove` at `element`

::: header-wrapper
#### 11.2.18 [maybe show context menu]

This section needs to be revised.

1. Let `native` be the native mousedown or pointer event
2. Let `target` be the
 [`EventTarget`](https://dom.spec.whatwg.org/#eventtarget) of the event
 1. Let `menuevent` be the result of [creating a
 PointerEvent](#dfn-creating-a-pointerevent) with \"contextmenu\",
 `target`
 2. If `native` is valid, then
 1. [Set MouseEvent attributes from
 native](#dfn-set-mouseevent-attributes-from-native) with `native`
 3. Let `result` be
 [dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)
 `menuevent` at `target`
 4. If `result` is true, then show the UA context menu

To handle a context menu triggered by the keyboard, call this algorithm
with `native` = null and `target` = currently
focused element.

::: header-wrapper
### 11.3 Mouse Event Order

Certain mouse events defined in this specification *MUST* occur in a set
order relative to one another. The following shows the event sequence
that *MUST* occur when a pointing device\'s cursor is moved over an
element:

 \# Event Type Element Notes
 ---- --------------------------------------------------------------------------------------------------------- --------- ---------------------------------------------------------------------------------------------------------------------
 1 [`mousemove`](#dfn-mousemove)
 *Pointing device is moved into element A\...*
 2 [`mouseover`](#dfn-mouseover) A
 3 [`mouseenter`](#dfn-mouseenter) A
 4 [`mousemove`](#dfn-mousemove) A Multiple [`mousemove`](#dfn-mousemove) events
 *Pointing device is moved out of element A\...*
 5 [`mouseout`](#dfn-mouseout) A
 6 [`mouseleave`](#dfn-mouseleave) A

When a pointing device is moved into an element *A*, and then into a
nested element *B* and then back out again, the following sequence of
events *MUST* occur:

 Event Type Element Notes
 ---- --------------------------------------------------------------------------------------------------------- --------- ----------------------------------------------------------------------------------------------------------------------
 1 [`mousemove`](#dfn-mousemove)
 *Pointing device is moved into element A\...*
 2 [`mouseover`](#dfn-mouseover) A
 3 [`mouseenter`](#dfn-mouseenter) A
 4 [`mousemove`](#dfn-mousemove) A Multiple [`mousemove`](#dfn-mousemove) events
 *Pointing device is moved into nested element B\...*
 5 [`mouseout`](#dfn-mouseout) A
 6 [`mouseover`](#dfn-mouseover) B
 7 [`mouseenter`](#dfn-mouseenter) B
 8 [`mousemove`](#dfn-mousemove) B Multiple [`mousemove`](#dfn-mousemove) events
 *Pointing device is moved from element B into A\...*
 9 [`mouseout`](#dfn-mouseout) B
 10 [`mouseleave`](#dfn-mouseleave) B
 11 [`mouseover`](#dfn-mouseover) A
 12 [`mousemove`](#dfn-mousemove) A Multiple [`mousemove`](#dfn-mousemove) events
 *Pointing device is moved out of element A\...*
 13 [`mouseout`](#dfn-mouseout) A
 14 [`mouseleave`](#dfn-mouseleave) A

Sometimes elements can be visually overlapped using CSS. In the
following example, three elements labeled A, B, and C all have the same
dimensions and absolute position on a web page. Element C is a child of
B, and B is a child of A in the DOM:

![[Figure 10](#figure-mouse-event-stacked-elements)
[Graphical representation of three stacked elements all on top of each
other, with the pointing device moving over the
stack.]](images/stacked-event-mouse-dispatch.svg)

When the pointing device is moved from outside the element stack to the
element labeled C and then moved out again, the following series of
events *MUST* occur:

 Event Type Element Notes
 ---- --------------------------------------------------------------------------------------------------------- --------- ----------------------------------------------------------------------------------------------------------------------
 1 [`mousemove`](#dfn-mousemove)
 *Pointing device is moved into element C, the topmost element in the stack*
 2 [`mouseover`](#dfn-mouseover) C
 3 [`mouseenter`](#dfn-mouseenter) A
 4 [`mouseenter`](#dfn-mouseenter) B
 5 [`mouseenter`](#dfn-mouseenter) C
 6 [`mousemove`](#dfn-mousemove) C Multiple [`mousemove`](#dfn-mousemove) events
 *Pointing device is moved out of element C\...*
 7 [`mouseout`](#dfn-mouseout) C
 8 [`mouseleave`](#dfn-mouseleave) C
 9 [`mouseleave`](#dfn-mouseleave) B
 10 [`mouseleave`](#dfn-mouseleave) A

The [`mouseover`](#dfn-mouseover)/[`mouseout`](#dfn-mouseout) events are only fired once,
while [`mouseenter`](#dfn-mouseenter)/[`mouseleave`](#dfn-mouseleave) events are fired three
times (once to each element).

The following is the typical sequence of events when a button associated
with a pointing device (e.g., a mouse button or trackpad) is pressed and
released over an element:

 Event Type Notes
 ---- ------------------------------------------------------------------------------------------------------ ------------------------------------------
 1 [`mousedown`](#dfn-mousedown)
 2 [`mousemove`](#dfn-mousemove) *OPTIONAL*, multiple events, some limits
 3 [`mouseup`](#dfn-mouseup)
 4 [`click`](#dfn-click)
 5 [`mousemove`](#dfn-mousemove) *OPTIONAL*, multiple events, some limits
 6 [`mousedown`](#dfn-mousedown)
 7 [`mousemove`](#dfn-mousemove) *OPTIONAL*, multiple events, some limits
 8 [`mouseup`](#dfn-mouseup)
 9 [`click`](#dfn-click)
 10 [`dblclick`](#dfn-dblclick)

The lag time, degree, distance, and number of
[`mousemove`](#dfn-mousemove) events allowed between the
[`mousedown`](#dfn-mousedown) and
[`mouseup`](#dfn-mouseup) events while still firing a
[`click`](#dfn-click) or [`dblclick`](#dfn-dblclick) event will be
implementation-, device-, and platform-specific. This tolerance can aid
users that have physical disabilities like unsteady hands when these
users interact with a pointing device.

Each implementation will determine the appropriate
[hysteresis](#dfn-hysteresis) tolerance, but in general *SHOULD* fire
[`click`](#dfn-click) and [`dblclick`](#dfn-dblclick) events when the event target
of the associated [`mousedown`](#dfn-mousedown) and
[`mouseup`](#dfn-mouseup) events is the same element with no
[`mouseout`](#dfn-mouseout) or
[`mouseleave`](#dfn-mouseleave) events intervening, and *SHOULD* fire
[`click`](#dfn-click) and [`dblclick`](#dfn-dblclick) events on the nearest common
inclusive ancestor when the associated
[`mousedown`](#dfn-mousedown) and
[`mouseup`](#dfn-mouseup) event targets are different.

If a [`mousedown`](#dfn-mousedown) event was targeted at an HTML
document\'s [body
element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2), and the corresponding
[`mouseup`](#dfn-mouseup) event was targeted at the [document
element](https://dom.spec.whatwg.org/#document-element),
then the [`click`](#dfn-click) event will be dispatched to the [document
element](https://dom.spec.whatwg.org/#document-element),
since it is the nearest common inclusive ancestor.

If the
[target](https://dom.spec.whatwg.org/#event-target)
(e.g. the target element) is removed from the DOM during the mouse
events sequence, the remaining events of the sequence *MUST NOT* be
fired on that element.

If the target element is removed from the DOM as the result of a
[`mousedown`](#dfn-mousedown) event, no events for that element will
be dispatched for [`mouseup`](#dfn-mouseup),
[`click`](#dfn-click), or [`dblclick`](#dfn-dblclick), nor any default activation
events. However, the [`mouseup`](#dfn-mouseup) event will still be
dispatched on the element that is exposed to the mouse after the removal
of the initial target element. Similarly, if the target element is
removed from the DOM during the dispatch of a
[`mouseup`](#dfn-mouseup) event, the
[`click`](#dfn-click) and subsequent events will not be dispatched.

::: header-wrapper
### 11.4 Mouse Event Types

The Mouse event types are listed below. In the case of nested elements,
mouse event types are always targeted at the most deeply nested element.
Ancestors of the targeted element *MAY* use bubbling to obtain
notification of mouse events which occur within its descendent elements.

::: header-wrapper
#### 11.4.1 [auxclick]

+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Type | **`auxclick`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : |
| | [topmost event target](#dfn-topmost-event-target) |
| | - [`UIEvent`](https://www.w3.org/TR/uievents/#uievent){ |
| | }.[`detail`](https://www.w3.org/TR/uievents/#dom-uievent-detail) |
| | : indicates the [current click count](#dfn-current-click-count); the attribute value *MUST* be `1` when the user begins |
| | this action and increments by `1` for each click. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+

The [`auxclick`](#dfn-auxclick) event type *MUST* be dispatched on the
[topmost event
target](#dfn-topmost-event-target) indicated by the pointer, when the user
presses down and releases the non-primary pointer button, or otherwise
activates the pointer in a manner that simulates such an action. The
actuation method of the mouse button depends upon the pointer device and
the environment configuration, e.g., it *MAY* depend on the screen
location or the delay between the press and release of the pointing
device button.

The [`auxclick`](#dfn-auxclick) event should only be fired for the
non-primary pointer buttons (i.e., when
[`button`](#dom-mouseevent-button) value is not `0`,
[`buttons`](#dom-mouseevent-buttons) value is greater than `1`). The primary
button (like the left button on a standard mouse) *MUST NOT* fire
[`auxclick`](#dfn-auxclick) events. See
[`click`](#dfn-click) for a corresponding event that is associated with the
primary button.

The [`auxclick`](#dfn-auxclick) event *MAY* be preceded by the
[`mousedown`](#dfn-mousedown) and
[`mouseup`](#dfn-mouseup) events on the same element, disregarding
changes between other node types (e.g., text nodes). Depending upon the
environment configuration, the
[`auxclick`](#dfn-auxclick) event *MAY* be dispatched if one or more
of the event types
[`mouseover`](#dfn-mouseover),
[`mousemove`](#dfn-mousemove), and
[`mouseout`](#dfn-mouseout) occur between the press and release of
the pointing device button.

The [default
action](https://www.w3.org/TR/uievents/#default-action)
of the [`auxclick`](#dfn-auxclick) event type varies based on the
[target](https://dom.spec.whatwg.org/#event-target) of
the event and the value of the
[`button`](#dom-mouseevent-button) or
[`buttons`](#dom-mouseevent-buttons) attributes. Typical [default
actions](https://www.w3.org/TR/uievents/#default-action)
of the [`auxclick`](#dfn-auxclick) event type are as follows:

- If the
 [target](https://dom.spec.whatwg.org/#event-target)
 has associated activation behavior, the [default
 action](https://www.w3.org/TR/uievents/#default-action)
 *MUST* be to execute that activation behavior.

[Example
9](#example-receiving-and-handling-auxclick-for-the-middle)[:
Receiving and handling auxclick for the middle]

 myLink.addEventListener("auxclick", function(e) {
 if (e.button === 1) {
 // This would prevent the default behavior which is for example
 // opening a new tab when middle clicking on a link.
 e.preventDefault();
 // Do something else to handle middle button click like taking
 // care of opening link or non-link buttons in new tabs in a way
 // that fits the app. Other actions like closing a tab in a tab-strip
 // which should be done on the click action can be done here too.
 }
 });

In the case of right button, the
[`auxclick`](#dfn-auxclick) event is dispatched after any
[`contextmenu`](#dfn-contextmenu) event. Note that some
user agents swallow all input events while a context menu is being
displayed, so auxclick may not be available to applications in such
scenarios. See [Example 10](#example-auxclick-right) for more
clarification.

[Example 10](#example-auxclick-right)[: Receiving and
handling auxclick for the right button]

 myDiv.addEventListener("contextmenu", function(e) {
 // This call makes sure no context menu is shown
 // to interfere with page receiving the events.
 e.preventDefault();
 });
 myDiv.addEventListener("auxclick", function(e) {
 if (e.button === 2) {
 // Do something else to handle right button click like opening a
 // customized context menu inside the app.
 }
 });

::: header-wrapper
#### 11.4.2 [click]

+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Type | **`click`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : |
| | [topmost event target](#dfn-topmost-event-target) |
| | - [`UIEvent`](https://www.w3.org/TR/uievents/#uievent){ |
| | }.[`detail`](https://www.w3.org/TR/uievents/#dom-uievent-detail) |
| | : indicates the [current click count](#dfn-current-click-count); the attribute value *MUST* be `1` when the user begins |
| | this action and increments by `1` for each click. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+

The [`click`](#dfn-click) event type *MUST* be dispatched on the
[topmost event
target](#dfn-topmost-event-target) indicated by the pointer, when the user
presses down and releases the primary pointer button, or otherwise
activates the pointer in a manner that simulates such an action. The
actuation method of the mouse button depends upon the pointer device and
the environment configuration, e.g., it *MAY* depend on the screen
location or the delay between the press and release of the pointing
device button.

The [`click`](#dfn-click) event should only be fired for the primary
pointer button (i.e., when
[`button`](#dom-mouseevent-button) value is `0`,
[`buttons`](#dom-mouseevent-buttons) value is `1`). Secondary buttons (like the
middle or right button on a standard mouse) *MUST NOT* fire
[`click`](#dfn-click) events. See
[`auxclick`](#dfn-auxclick) for a corresponding event that is
associated with the non-primary buttons.

The [`click`](#dfn-click) event *MAY* be preceded by the
[`mousedown`](#dfn-mousedown) and
[`mouseup`](#dfn-mouseup) events on the same element, disregarding
changes between other node types (e.g., text nodes). Depending upon the
environment configuration, the
[`click`](#dfn-click) event *MAY* be dispatched if one or more of the event types
[`mouseover`](#dfn-mouseover),
[`mousemove`](#dfn-mousemove), and
[`mouseout`](#dfn-mouseout) occur between the press and release of
the pointing device button. The
[`click`](#dfn-click) event *MAY* also be followed by the
[`dblclick`](#dfn-dblclick) event.

If a user mouses down on a text node child of a `<p>` element which has
been styled with a large line-height, shifts the mouse slightly such
that it is no longer over an area containing text but is still within
the containing block of that `<p>` element (i.e., the pointer is between
lines of the same text block, but not over the text node per se), then
subsequently mouses up, this will likely still trigger a
[`click`](#dfn-click) event (if it falls within the normal temporal
[hysteresis](#dfn-hysteresis) for a [`click`](#dfn-click)), since the user has stayed
within the scope of the same element. Note that user-agent-generated
mouse events are not dispatched on text nodes.

In addition to being associated with pointer devices, the
[`click`](#dfn-click) event type *MUST* be dispatched as part of an element
activation.

For maximum accessibility, content authors are encouraged to use the
[`click`](#dfn-click) event type when defining activation behavior for custom
controls, rather than other pointing-device event types such as
[`mousedown`](#dfn-mousedown) or
[`mouseup`](#dfn-mouseup), which are more device-specific. Though
the [`click`](#dfn-click) event type has its origins in pointer
devices (e.g., a mouse), subsequent implementation enhancements have
extended it beyond that association, and it can be considered a
device-independent event type for element activation.

The [default
action](https://www.w3.org/TR/uievents/#default-action)
of the [`click`](#dfn-click) event type varies based on the
[target](https://dom.spec.whatwg.org/#event-target) of
the event and the value of the
[`button`](#dom-mouseevent-button) or
[`buttons`](#dom-mouseevent-buttons) attributes. Typical [default
actions](https://www.w3.org/TR/uievents/#default-action)
of the [`click`](#dfn-click) event type are as follows:

- If the
 [target](https://dom.spec.whatwg.org/#event-target)
 has associated activation behavior, the [default
 action](https://www.w3.org/TR/uievents/#default-action)
 *MUST* be to execute that activation behavior.
- If the
 [target](https://dom.spec.whatwg.org/#event-target)
 is focusable, the [default
 action](https://www.w3.org/TR/uievents/#default-action)
 *MUST* be to give that element document focus.

::: header-wrapper
#### 11.4.3 [contextmenu]

+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Type | **`contextmenu`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Interface | [`PointerEvent`](#dom-pointerevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : |
| | [topmost event target](#dfn-topmost-event-target) |
| | - [`UIEvent`](https://www.w3.org/TR/uievents/#uievent){ |
| | }.[`detail`](https://www.w3.org/TR/uievents/#dom-uievent-detail) |
| | : 0 |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch this event before invoking a context menu.

When the [`contextmenu`](#dfn-contextmenu) event is triggered by
right mouse button, the
[`contextmenu`](#dfn-contextmenu) event *MUST* be
dispatched after the
[`mousedown`](#dfn-mousedown) event.

Depending on the platform, the
[`contextmenu`](#dfn-contextmenu) event may be dispatched
before or after the [`mouseup`](#dfn-mouseup) event.

::: header-wrapper
#### 11.4.4 [dblclick]

+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Type | **`dblclick`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Interface | [`MouseEvent`](#dom-mouseevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Context\ | - [`UIEvent`](https://www.w3.org/TR/uievents/#uievent){ |
| (trusted events) | }.[`detail`](https://www.w3.org/TR/uievents/#dom-uievent-detail) |
| | : indicates the [current click count](#current-click-count) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch this event when the primary button of a pointing device
is clicked twice over an element. The definition of a double click
depends on the environment configuration, except that the event target
*MUST* be the same between
[`mousedown`](#dfn-mousedown),
[`mouseup`](#dfn-mouseup), and
[`dblclick`](#dfn-dblclick). This event type *MUST* be dispatched
after the event type [`click`](#dfn-click) if a click and double click
occur simultaneously, and after the event type
[`mouseup`](#dfn-mouseup) otherwise.

As with the [`click`](#dfn-click) event, the
[`dblclick`](#dfn-dblclick) event should only be fired for the
primary pointer button. Secondary buttons *MUST NOT* fire
[`dblclick`](#dfn-dblclick) events.

Canceling the [`click`](#dfn-click) event does not affect the firing of a
[`dblclick`](#dfn-dblclick) event.

As with the [`click`](#dfn-click) event type, the [default
action](https://www.w3.org/TR/uievents/#default-action)
of the [`dblclick`](#dfn-dblclick) event type varies based on the
[target](https://dom.spec.whatwg.org/#event-target) of
the event and the value of the
[`button`](#dom-mouseevent-button) or
[`buttons`](#dom-mouseevent-buttons) attributes. The typical [default
actions](https://www.w3.org/TR/uievents/#default-action)
of the [`dblclick`](#dfn-dblclick) event type match those of the
[`click`](#dfn-click) event type.

::: header-wrapper
#### 11.4.5 [mousedown]

+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Type | **`mousedown`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Interface | [`MouseEvent`](#dom-mouseevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : |
| | [topmost event target](#dfn-topmost-event-target) |
| | - [`UIEvent`](https://www.w3.org/TR/uievents/#uievent){ |
| | }.[`detail`](https://www.w3.org/TR/uievents/#dom-uievent-detail) |
| | : indicates the [current click count](#current-click-count) incremented by one. For example, if no |
| | click happened before the [`mousedown`](#dfn-mousedown), |
| | [`detail`](https://www.w3.org/TR/uievents/#dom-uievent-detail) will contain |
| | the value `1` |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch this event when a pointing device button is pressed over
an element.

Many implementations use the
[`mousedown`](#dfn-mousedown) event to begin a variety of contextually
dependent [default
actions](https://www.w3.org/TR/uievents/#default-action).
These default actions can be prevented if this event is canceled. Some
of these default actions could include: beginning a drag/drop
interaction with an image or link, starting text selection, etc.
Additionally, some implementations provide a mouse-driven panning
feature that is activated when the middle mouse button is pressed at the
time the [`mousedown`](#dfn-mousedown) event is dispatched.

::: header-wrapper
#### 11.4.6 [mouseenter]

+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Type | **`mouseenter`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Interface | [`MouseEvent`](#dom-mouseevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Bubbles | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Cancelable | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Composed | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [topmost |
| | event target](#dfn-topmost-event-target) |
| | - [`MouseEvent`](#dom-mouseevent).[`relatedTarget`](#dom-mouseevent-relatedtarget) : indicates the |
| | [target](https://dom.spec.whatwg.org/#event-target) a pointing device is entering, if |
| | any. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch this event when a pointing device is moved onto the
boundaries of an element or one of its descendent elements. A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* also dispatch this event when the element or one of its
descendants moves to be underneath the primary pointing device. This
event type is similar to
[`mouseover`](#dfn-mouseover), but differs in that it does not bubble,
and *MUST NOT* be dispatched when the pointer device moves from an
element onto the boundaries of one of its descendent elements.

There are similarities between this event type and the CSS [`:hover`
pseudo-class](https://www.w3.org/TR/CSS2/selector.html#dynamic-pseudo-classes "Selectors")
\[[CSS2](#bib-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\]. See also the
[`mouseleave`](#dfn-mouseleave) event type.

::: header-wrapper
#### 11.4.7 [mouseleave]

+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Type | **`mouseleave`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Interface | [`MouseEvent`](#dom-mouseevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Bubbles | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Cancelable | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Composed | No |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [topmost |
| | event target](#dfn-topmost-event-target) |
| | - [`MouseEvent`](#dom-mouseevent).[`relatedTarget`](#dom-mouseevent-relatedtarget) : indicates the |
| | [target](https://dom.spec.whatwg.org/#event-target) a pointing device is exiting, if |
| | any. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch this event when a pointing device is moved off of the
boundaries of an element and all of its descendent elements. A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* also dispatch this event when the element or one of its
descendants moves to be no longer underneath the primary pointing
device. This event type is similar to
[`mouseout`](#dfn-mouseout), but differs in that does not bubble, and
that it *MUST NOT* be dispatched until the pointing device has left the
boundaries of the element and the boundaries of all of its children.

There are similarities between this event type and the CSS [`:hover`
pseudo-class](https://www.w3.org/TR/CSS2/selector.html#dynamic-pseudo-classes "Selectors")
\[[CSS2](#bib-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\]. See also the
[`mouseenter`](#dfn-mouseenter) event type.

::: header-wrapper
#### 11.4.8 [mousemove]

+-----------------------------------+------------------------------------------------------------------------------------------------+
| Type | **`mousemove`** |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Interface | [`MouseEvent`](#dom-mouseevent) |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) |
| | : [topmost event target](#dfn-topmost-event-target) |
+-----------------------------------+------------------------------------------------------------------------------------------------+

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch this event when a pointing device is moved while it is
over an element. The frequency rate of events while the pointing device
is moved is implementation-, device-, and platform-specific, but
multiple consecutive
[`mousemove`](#dfn-mousemove) events *SHOULD* be fired for sustained
pointer-device movement, rather than a single event for each instance of
mouse movement. Implementations are encouraged to determine the optimal
frequency rate to balance responsiveness with performance.

In some implementation environments, such as a browser,
[`mousemove`](#dfn-mousemove) events can continue to fire if the user
began a drag operation (e.g., a mouse button is pressed) and the
pointing device has left the boundary of the user agent.

This event was formerly specified to be non-cancelable in DOM Level 2
Events, but was changed to reflect existing interoperability between
user agents.

::: header-wrapper
#### 11.4.9 [mouseout]

+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Type | **`mouseout`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Interface | [`MouseEvent`](#dom-mouseevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [topmost |
| | event target](#dfn-topmost-event-target) |
| | - [`MouseEvent`](#dom-mouseevent).[`relatedTarget`](#dom-mouseevent-relatedtarget) : indicates the |
| | [target](https://dom.spec.whatwg.org/#event-target) a pointing device is entering, if |
| | any. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch this event when a pointing device is moved off of the
boundaries of an element or when the element is moved to be no longer
underneath the primary pointing device. This event type is similar to
[`mouseleave`](#dfn-mouseleave), but differs in that does bubble, and
that it *MUST* be dispatched when the pointer device moves from an
element onto the boundaries of one of its descendent elements.

See also the [`mouseover`](#dfn-mouseover) event type.

::: header-wrapper
#### 11.4.10 [mouseover]

+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Type | **`mouseover`** |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Interface | [`MouseEvent`](#dom-mouseevent) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [topmost |
| | event target](#dfn-topmost-event-target) |
| | - [`MouseEvent`](#dom-mouseevent).[`relatedTarget`](#dom-mouseevent-relatedtarget) : indicates the |
| | [target](https://dom.spec.whatwg.org/#event-target) a pointing device is entering, if |
| | any. |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch this event when a pointing device is moved onto the
boundaries of an element or when the element is moved to be underneath
the primary pointing device. This event type is similar to
[`mouseenter`](#dfn-mouseenter), but differs in that it bubbles, and
that it *MUST* be dispatched when the pointer device moves onto the
boundaries of an element whose ancestor element is the
[target](https://dom.spec.whatwg.org/#event-target) for
the same [event
listener](https://dom.spec.whatwg.org/#concept-event-listener)
instance.

See also the [`mouseout`](#dfn-mouseout) event type.

::: header-wrapper
#### 11.4.11 [mouseup]

+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Type | **`mouseup`** |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Interface | [`MouseEvent`](#dom-mouseevent) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Cancelable | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : |
| | [topmost event target](#dfn-topmost-event-target) |
| | - [`UIEvent`](https://www.w3.org/TR/uievents/#uievent){ |
| | }.[`detail`](https://www.w3.org/TR/uievents/#dom-uievent-detail) |
| | : indicates the [current click count](#current-click-count) incremented by one. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------+

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch this event when a pointing device button is released
over an element.

In some implementation environments, such as a browser, a
[`mouseup`](#dfn-mouseup) event can be dispatched even if the
pointing device has left the boundary of the user agent, e.g., if the
user began a drag operation with a mouse button pressed.

::: header-wrapper
## 12. Wheel Events and interfaces

Wheels are devices that can be rotated in one or more spatial
dimensions, and which can be associated with a pointer device. The
coordinate system depends on the environment configuration.

The user\'s environment might be configured to associate vertical
scrolling with rotation along the y-axis, horizontal scrolling with
rotation along the x-axis, and zooming with rotation along the z-axis.

The deltaX, deltaY, and deltaZ attributes of
[`WheelEvent`](#dom-wheelevent) objects indicate a measurement along
their respective axes in units of pixels, lines, or pages. The reported
measurements are provided after an environment-specific algorithm
translates the actual rotation/movement of the wheel device into the
appropriate values and units.

A user\'s environment settings can be customized to interpret actual
rotation/movement of a wheel device in different ways. One movement of a
common "dented" mouse wheel can produce a measurement of 162 pixels (162
is just an example value, actual values can depend on the current screen
dimensions of the user-agent). But a user can change their default
environment settings to speed-up their mouse wheel, increasing this
number. Furthermore, some mouse wheel software can support acceleration
(the faster the wheel is rotated/moved, the greater the
[delta](#dfn-delta)
of each measurement) or even sub-pixel
[rotation](#dfn-rotation) measurements. Because of this, authors can not assume a
given [rotation](#dfn-rotation) amount in one user agent will produce the same
[delta](#dfn-delta)
value in all user agents.

The sign (positive or negative) of the values of the deltaX, deltaY, and
deltaZ attributes *MUST* be consistent between multiple dispatches of
the [`wheel`](#dfn-wheel) event while the motion of the actual wheel
device is rotating/moving in the same direction. If a user agent scrolls
as the default action of the [`wheel`](#dfn-wheel) event then the sign of the
[delta](#dfn-delta)
*SHOULD* be given by a right-hand coordinate system where positive X, Y,
and Z axes are directed towards the right-most edge, bottom-most edge,
and farthest depth (away from the user) of the document, respectively.

Individual user agents can (depending on their environment and hardware
configuration) interpret the same physical user interaction on the wheel
differently. For example, a vertical swipe on the edge of a trackpad
from top to bottom can be interpreted as a wheel action intended to
either scroll the page down or to pan the page up (i.e., resulting in
either a positive or negative deltaY value respectively).

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* create a [wheel event
transaction](#dfn-wheel-event-transaction) when the first wheel event is fired, so
that all subsequent wheel events within a implementation-specific amount
of time can be targetted at the same element. A [wheel event
transaction] is series of wheel events that
are associated with a single user gesture. The [wheel event
transaction](#dfn-wheel-event-transaction) *MUST* have an associated event target
that is the [topmost event
target](#dfn-topmost-event-target) at the time the first wheel event occurs
in the group.

If a series of wheel events targetted in a scrollable element start
above a child element, later events for the same user gesture may occur
over the child element.

::: header-wrapper
### 12.1 `WheelEvent` interface

The [`WheelEvent`](#dom-wheelevent) interface provides
specific contextual information associated with
[`wheel`](#dfn-wheel) events.

To create an instance of the
[`WheelEvent`](#dom-wheelevent) interface, use the
[`WheelEvent`](#dom-wheelevent) constructor, passing an optional
[`WheelEventInit`](#dom-wheeleventinit) dictionary.

```
WebIDLdictionary WheelEventInit : MouseEventInit {
 double deltaX = 0.0;
 double deltaY = 0.0;
 double deltaZ = 0.0;
 unsigned long deltaMode = 0;
 boolean momentum = false;
};

[Exposed=Window]
interface WheelEvent : MouseEvent {
 constructor(DOMString type, optional WheelEventInit eventInitDict = );
 // DeltaModeCode
 const unsigned long DOM_DELTA_PIXEL = 0x00;
 const unsigned long DOM_DELTA_LINE = 0x01;
 const unsigned long DOM_DELTA_PAGE = 0x02;

 readonly attribute double deltaX;
 readonly attribute double deltaY;
 readonly attribute double deltaZ;
 readonly attribute unsigned long deltaMode;
 readonly attribute boolean momentum;
};
```

[`DOM_DELTA_PIXEL`]
: The units of measurement for the
 [delta](#dfn-delta) *MUST* be pixels. This is the most typical case in
 most operating system and implementation configurations.

[`DOM_DELTA_LINE`]
: The units of measurement for the
 [delta](#dfn-delta) *MUST* be individual lines of text. This is the
 case for many form controls.

[`DOM_DELTA_PAGE`]
: The units of measurement for the
 [delta](#dfn-delta) *MUST* be pages, either defined as a single screen
 or as a demarcated page.

[`deltaX`]
: In user agents where the default action of the
 [`wheel`](#dfn-wheel) event is to scroll, the value *MUST* be
 the measurement along the x-axis (in pixels, lines, or pages) to be
 scrolled in the case where the event is not cancelled. Otherwise,
 this is an implementation-specific measurement (in pixels, lines, or
 pages) of the movement of a wheel device around the x-axis. The
 [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0.0`.

[`deltaY`]
: In user agents where the default action of the
 [`wheel`](#dfn-wheel) event is to scroll, the value *MUST* be
 the measurement along the y-axis (in pixels, lines, or pages) to be
 scrolled in the case where the event is not cancelled. Otherwise,
 this is an implementation-specific measurement (in pixels, lines, or
 pages) of the movement of a wheel device around the y-axis. The
 [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0.0`.

[`deltaZ`]

: In user agents where the default action of the
 [`wheel`](#dfn-wheel) event is to scroll, the value *MUST* be
 the measurement along the z-axis (in pixels, lines, or pages) to be
 scrolled in the case where the event is not cancelled. Otherwise,
 this is an implementation-specific measurement (in pixels, lines, or
 pages) of the movement of a wheel device around the z-axis.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0.0`.

 Initializes the
 [`deltaZ`](#dom-wheelevent-deltaz) attribute of the
 [`WheelEvent`](#dom-wheelevent) object. Relative
 positive values for this attribute (as well as the
 [`deltaX`](#dom-wheelevent-deltax) and
 [`deltaY`](#dom-wheelevent-deltay) attributes) are given by a right-hand
 coordinate system where the X, Y, and Z axes are directed towards
 the right-most edge, bottom-most edge, and farthest depth (away from
 the user) of the document, respectively. Negative relative values
 are in the respective opposite directions.

[`deltaMode`]

: The `deltaMode` attribute contains an indication of the units of
 measurement for the [delta](#dfn-delta) values. The default value is
 [`DOM_DELTA_PIXEL`](#dom-wheelevent-dom_delta_pixel) (pixels).

 This attribute *MUST* be set to one of the DOM_DELTA constants to
 indicate the units of measurement for the
 [delta](#dfn-delta) values. The precise measurement is specific to
 device, operating system, and application configurations.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `0`.

[`momentum`]

: This attribute must be `true` if this event is synthesized by the
 platform to simulate scroll inertia after the user has ended the
 physical scroll interaction (e.g. lifted the finger from a trackpad
 after a fling), and `false` otherwise.

 The [un-initialized
 value](https://www.w3.org/TR/uievents/#un-initialized-value)
 of this attribute *MUST* be `false`.

::: header-wrapper
### 12.2 Wheel Event Types

::: header-wrapper
### 12.3 [wheel]

+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Type | **`wheel`** |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Interface | [`WheelEvent`](#dom-wheelevent) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Bubbles | Yes |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Cancelable | [Varies](#cancelability-of-wheel-events) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Composed | Yes |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+
| Context\ | - [`Event`](https://dom.spec.whatwg.org/#event){ |
| (trusted events) | }.[`target`](https://dom.spec.whatwg.org/#dom-event-target) : element |
| | target for the current [wheel event |
| | transaction](#dfn-wheel-event-transaction) |
| | - [`MouseEvent`](#dom-mouseevent).[`relatedTarget`](#dom-mouseevent-relatedtarget) : indicates the |
| | [target](https://dom.spec.whatwg.org/#event-target) the pointing device is pointing at, |
| | if any. |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------+

A [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* dispatch this event when a mouse wheel has been rotated around
any axis, or when an equivalent input device (such as a mouse-ball,
certain tablets or touchpads, etc.) has emulated such an action.
Depending on the platform and input device, diagonal wheel
[deltas](#dfn-delta)
*MAY* be delivered either as a single
[`wheel`](#dfn-wheel) event with multiple non-zero axes or as separate
[`wheel`](#dfn-wheel) events for each non-zero axis.

The typical [default
action](https://www.w3.org/TR/uievents/#default-action)
of the [`wheel`](#dfn-wheel) event type is to scroll (or in some cases,
zoom) the document by the indicated amount. If this event is canceled,
the implementation *MUST NOT* scroll or zoom the document (or perform
whatever other implementation-specific default action is associated with
this event type).

In some [user
agents](https://infra.spec.whatwg.org/#user-agent), or
with some input devices, the speed that the wheel has been turned can
affect the [delta](#dfn-delta) values, with a faster speed producing a higher
[delta](#dfn-delta)
value.

::: header-wrapper
#### 12.3.1 cancelability of wheel events

Calling `preventDefault` on a wheel event can prevent or otherwise
interrupt scrolling. For maximum scroll performance, a user agent may
not wait for each wheel event associated with the scroll to be processed
to see if it will be canceled. In such cases the user agent should
generate `wheel` events whose `cancelable` property is `false`,
indicating that `preventDefault` cannot be used to prevent or interrupt
scrolling. Otherwise `cancelable` will be `true`.

In particular, a user agent should generate only uncancelable `wheel`
events when it [observes that there are no non-passive
listeners](https://dom.spec.whatwg.org/#observing-event-listeners) for
the event.

::: header-wrapper
## 13. Examples

*This section is non-normative.*

The following are basic examples that demonstrate how some of the APIs
in this specification might be used by authors. Further, more specific
examples are provided in the relevant sections of this document.

[Example 11](#example_1)[: Feature detection and event
binding]

 /* Bind to either Pointer Events or traditional touch/mouse */

 if (window.PointerEvent) {
 // if Pointer Events are supported, only listen to pointer events
 target.addEventListener("pointerdown", function(e) {
 // if necessary, apply separate logic based on e.pointerType
 // for different touch/pen/mouse behavior
 ...
 });
 ...
 } else {
 // traditional touch/mouse event handlers
 target.addEventListener('touchstart', function(e) {
 // prevent compatibility mouse events and click
 e.preventDefault();
 ...
 });
 ...
 target.addEventListener('mousedown', ...);
 ...
 }

 // additional event listeners for keyboard handling
 ...

[Example 12](#example_2)[: Detecting the type of input from
a user]

 window.addEventListener("pointerdown", detectInputType);

 function detectInputType(event) {
 switch(event.pointerType) {
 case "mouse":
 /* mouse input detected */
 break;
 case "pen":
 /* pen/stylus input detected */
 break;
 case "touch":
 /* touch input detected */
 break;
 default:
 /* pointerType is empty (could not be detected)
 or UA-specific custom type */
 }
 }

[Example 13](#example_3)[: Resizing an element to match the
contact geometry]

 <div style="position:absolute; top:0px; left:0px; width:100px;height:100px;"></div>
 <script>
 window.addEventListener("pointerdown", checkPointerSize);

 function checkPointerSize(event) {
 event.target.style.width = event.width + "px";
 event.target.style.height = event.height + "px";
 }
 </script>

[Example 14](#example_4)[: Firing untrusted pointer events
from script]

 const event1 = new PointerEvent("pointerover",
 { bubbles: true,
 cancelable: true,
 composed: true,
 pointerId: 42,
 pointerType: "pen",
 clientX: 300,
 clientY: 500
 });
 eventTarget.dispatchEvent(event1);

 let pointerEventInitDict =
 {
 bubbles: true,
 cancelable: true,
 composed: true,
 pointerId: 42,
 pointerType: "pen",
 clientX: 300,
 clientY: 500,
 };
 const p1 = new PointerEvent("pointermove", pointerEventInitDict);
 pointerEventInitDict.clientX += 10;
 const p2 = new PointerEvent("pointermove", pointerEventInitDict);
 pointerEventInitDict.coalescedEvents = [p1, p2];
 const event2 = new PointerEvent("pointermove", pointerEventInitDict);
 eventTarget.dispatchEvent(event2);

[Example 15](#example_5)[: Assigning a pen color on
PointerDown]

 <div style="position:absolute; top:0px; left:0px; width:100px;height:100px;"></div>
 <script>
 window.addEventListener("pointerdown", assignPenColor);
 window.addEventListener("pointermove", assignPenColor);
 const colorMap = new Map();

 function assignPenColor(event) {
 const uniqueId = event.persistentDeviceId;
 // Check if a unique Id exists.
 if (uniqueId == 0) {
 return;
 }
 // Check if a color has been assigned to the device.
 if (map.has(uniqueId)) {
 return;
 }
 // Assign a color to the device.
 let newColor = getNewColor();
 map.set(uniqueId, newColor);
 return newColor;
 }

 function getNewColor() {
 /* return some color value */
 }
 </script>

::: header-wrapper
## 14. Security and privacy considerations

This appendix discusses security and privacy considerations for Pointer
Events implementations. The discussion is limited to security and
privacy issues that arise directly from implementation of the event
model, APIs and events defined in this specification.

Many of the event types defined in this specification are dispatched in
response to user actions. This allows malicious event listeners to gain
access to information users would typically consider confidential, e.g.,
the exact path/movement of a user\'s mouse/stylus/finger while
interacting with a page.

Pointer events contain additional information (where supported by the
user\'s device), such as the angle or tilt at which a pen input is held,
the geometry of the contact surface, and the pressure exerted on the
stylus or touch screen. Information about angle, tilt, geometry and
pressure are directly related to sensors on the user\'s device, meaning
that this specification allows an origin access to these sensors.

This sensor data, as well as the ability to determine the type of input
mechanism (mouse, touch, pen) used, may be used to infer characteristics
of a user, or of the user\'s device and environment. These inferred
characteristics and any device/environment information may themselves be
sensitive --- for instance, they may allow a malicious site to further
infer if a user is using assistive technologies. This information can
also be potentially used for the purposes of building a user profile
and/or attempting to \"fingerprint\" and track a particular user.

As mitigation, user agents may consider including the ability for users
to disable access to particular sensor data (such as angle, tilt,
pressure), and/or to make it available only after an explicit opt-in
from the user.

This specification defines the method by which authors can access
\"predicted events\". The specification does not, itself, define the
algorithms that user agents should use for their prediction. The
specification authors envisage the algorithms to only rely on preceding
pointer events related to the current gesture that a user is performing.
It is the responsibility of user agents to ensure that their specific
implementation of a prediction algorithm does not rely on any additional
data - such as the user\'s full interaction history across different
sites - that could reveal sensitive information about a user or be used
to \"fingerprint\" and track them.

Beyond these considerations, the working group believes that this
specification:

- Does not expose personally-identifiable information.
- Does not deal with high-value data.
- Does not introduce new state for an origin that persists across
 browsing sessions.
- Does not expose persistent, cross-origin state to the web.
- Does not expose any other data to an origin that it doesn't currently
 have access to.
- Does not enable new script execution/loading mechanisms.
- Does not allow an origin access to a user's location.
- Does not require any special handling when the user agent is in
 \"incognito\" mode.
- Does not allow an origin access to other devices.
- Does not allow an origin control over a user agent's native UI.
- Does not expose temporary identifiers to the web.
- Does not distinguish between behavior in first-party and third-party
 contexts.
- Does not persist data to a user's local device.
- Does not allow downgrading default security characteristics.

::: header-wrapper
## 15. Glossary

*This section is non-normative.*

[active buttons state]
: The condition when a pointer has a non-zero value for the `buttons`
 property. For mouse, this is when the device has at least one button
 depressed. For touch, this is when there is physical contact with
 the digitizer. For pen, this is when either the pen has physical
 contact with the digitizer, or at least one button is depressed
 while hovering.

[active document]
: For every [active
 pointer](#dfn-active-pointer), the document that received the last
 event from that pointer.

[active pointer]
: Any touch contact, pen/stylus, mouse cursor, or other pointer that
 can produce events. If it is possible for a given pointer
 (identified by a unique
 [`pointerId`](#dom-pointerevent-pointerid)) to produce additional events within
 the document, then that pointer is still considered active.
 Examples:
 - A mouse connected to the device is always active.
 - A touch contact on the screen is considered active.
 - If a touch contact or pen/stylus is lifted beyond the range of the
 digitizer, then it is no longer considered active.

 :::::
 :::
 Note
 :::

 :::
 On some platforms, the set of active pointers includes all pointer
 input to the device, including any that are not targeted at the user
 agent (e.g. those targeted at other applications).
 :::
 :::::

[contact geometry]
: The bounding box of an input (most commonly, touch) on a digitizer.
 This typically refers to devices with coarser pointer input
 resolution than a single pixel. Some devices do not report this data
 at all.

[delta]
: The estimated scroll amount (in pixels, lines, or pages) that the
 user agent will scroll or zoom the page in response to the physical
 movement of an input device that supports the
 [`WheelEvent`](#dom-wheelevent) interface (such as a
 mouse wheel or touch pad). The value of a
 [delta](#dfn-delta) (e.g., the
 [`deltaX`](#dom-wheelevent-deltax),
 [`deltaY`](#dom-wheelevent-deltay), or
 [`deltaZ`](#dom-wheelevent-deltaz) attributes) is to be interpreted in
 the context of the current
 [`deltaMode`](#dom-wheelevent-deltamode) property. The relationship between the
 physical movement of a wheel (or other device) and whether the
 [delta](#dfn-delta) is positive or negative is environment and device
 dependent. However, if a user agent scrolls as the [default
 action](https://www.w3.org/TR/uievents/#default-action)
 then the sign of the [delta](#dfn-delta) is given by a right-hand coordinate
 system where positive X,Y, and Z axes are directed towards the
 right-most edge, bottom-most edge, and farthest depth (away from the
 user) of the
 [document](https://dom.spec.whatwg.org/#concept-document),
 respectively.

[digitizer]
: A type of input sensing device in which a surface can detect input
 which is in contact and/or in close proximity. Most commonly, this
 is the surface that senses input from the touch contact or a
 pen/stylus.

[direct manipulation]
: Certain user agents (such as browsers on a touchscreen device)
 implement a \"direct manipulation\" metaphor where a pointer not
 only interacts with controls, but is also used to directly pan or
 zoom the current page, providing the illusion of direct physical
 contact. As an example, users on a touchscreen device are generally
 able to use a finger or a stylus to \"grab\" a page and pan it by
 moving the pointer, directly manipulating the page. Contrast this
 with a mouse pointer on a regular desktop/laptop, where panning is
 done by using a scrollbar, rather than by \"dragging\" the page.
 :::::
 :::
 Note
 :::

 :::
 In some cases, touchpads (like those found on a laptop) will allow
 the user to scroll by \"dragging\" on the touchpad. However, this is
 generally achieved by the touchpad generating \"fake\" mouse wheel
 events, so this wouldn\'t count as a direct manipulation.
 :::
 :::::

[hysteresis]
: A feature of human interface design to accept input values within a
 certain range of location or time, in order to improve the user
 experience. For example, allowing for small deviation in the time it
 takes for a user to double-click a mouse button is temporal
 hysteresis, and not immediately closing a nested menu if the user
 mouses out from the parent window when transitioning to the child
 menu is locative hysteresis.

[measurable properties]

: Measurable properties represent values relating to continuous
 pointer sensor data that is expressed using a real number or an
 integer from a large domain. For pointer events, `width`, `height`,
 `pressure`, `tangentialPressure`, `tiltX`, `tiltY`, `twist`,
 `altitudeAngle`, `azimuthAngle`, and the Mouse Event model
 properties `screenX`, `screenY`, `clientX`, `clientY` are measurable
 properties.

 In contrast
 [`pointerId`](#dom-pointerevent-pointerid), `pointerType`, `isPrimary`, and the
 Mouse Event model properties `button`, `buttons`, `ctrlKey`,
 `shiftKey`, `altKey`, and `metaKey` are not considered measurable
 properties, as they don\'t relate to sensor data.

[pointer]
: A hardware-agnostic representation of input devices that can target
 a specific coordinate (or set of coordinates) on a screen, such as a
 mouse, pen, or touch contact.

[rotation]
: An indication of incremental change on an input device using the
 [`WheelEvent`](#dom-wheelevent) interface. On some
 devices this *MAY* be a literal rotation of a wheel, while on
 others, it *MAY* be movement along a flat surface, or pressure on a
 particular button.

[topmost event target]
: The [topmost event
 target](#dfn-topmost-event-target) *MUST* be the element highest in the
 rendering order which is capable of being a
 [target](https://dom.spec.whatwg.org/#event-target).
 In graphical user interfaces this is the element under the user\'s
 pointing device. A user interface\'s "hit testing" facility is used
 to determine the target. For specific details regarding hit testing
 and stacking order, refer to the [host
 language](https://www.w3.org/TR/uievents/#host-language).

::: header-wrapper
## 16. Legacy Event Initializers

*This section is normative. The following features are obsolete and
should only be implemented by [user
agents](https://infra.spec.whatwg.org/#user-agent) that
require compatibility with legacy software. See also the [legacy event
initializers](https://www.w3.org/TR/uievents/#legacy-event-initializers)
in \[[UIEvents](#bib-uievents "UI Events")\].*

::: header-wrapper
### 16.1 Initializers for interface MouseEvent

```
WebIDLpartial interface MouseEvent {
 // Deprecated in this specification
 undefined initMouseEvent(DOMString typeArg,
 optional boolean bubblesArg = false,
 optional boolean cancelableArg = false,
 optional Window? viewArg = null,
 optional long detailArg = 0,
 optional long screenXArg = 0,
 optional long screenYArg = 0,
 optional long clientXArg = 0,
 optional long clientYArg = 0,
 optional boolean ctrlKeyArg = false,
 optional boolean altKeyArg = false,
 optional boolean shiftKeyArg = false,
 optional boolean metaKeyArg = false,
 optional short buttonArg = 0,
 optional EventTarget? relatedTargetArg = null);
};
```

[`initMouseEvent(typeArg)`]
: Initializes attributes of a
 [`MouseEvent`](#dom-mouseevent) object. This method
 has the same behavior as `UIEvent.initUIEvent()`.
 ::::
 :::
 Warning
 :::

 The `initMouseEvent` method is deprecated, but supported for
 backwards-compatibility with widely-deployed implementations.
 ::::

 DOMString typeArg
 : Refer to the
 [`initEvent`](https://dom.spec.whatwg.org/#dom-event-initevent)`()` method for a description of this
 parameter.

 boolean bubblesArg
 : Refer to the
 [`initEvent`](https://dom.spec.whatwg.org/#dom-event-initevent)`()` method for a description of this
 parameter.

 boolean cancelableArg
 : Refer to the
 [`initEvent`](https://dom.spec.whatwg.org/#dom-event-initevent)`()` method for a description of this
 parameter.

 Window? viewArg
 : Specifies
 [`view`](https://www.w3.org/TR/uievents/#dom-uievent-view).
 This value *MAY* be `null`.

 long detailArg
 : Specifies
 [`detail`](https://www.w3.org/TR/uievents/#dom-uievent-detail).

 long screenXArg
 : Specifies
 [`screenX`](#dom-mouseevent-screenx).

 long screenYArg
 : Specifies
 [`screenY`](#dom-mouseevent-screeny).

 long clientXArg
 : Specifies
 [`clientX`](#dom-mouseevent-clientx).

 long clientYArg
 : Specifies
 [`clientY`](#dom-mouseevent-clienty).

 boolean ctrlKeyArg
 : Specifies
 [`ctrlKey`](#dom-mouseevent-ctrlkey).

 boolean altKeyArg
 : Specifies
 [`altKey`](#dom-mouseevent-altkey).

 boolean shiftKeyArg
 : Specifies
 [`shiftKey`](#dom-mouseevent-shiftkey).

 boolean metaKeyArg
 : Specifies
 [`metaKey`](#dom-mouseevent-metakey).

 short buttonArg
 : Specifies
 [`button`](#dom-mouseevent-button).

 EventTarget? relatedTargetArg
 : Specifies
 [`relatedTarget`](#dom-mouseevent-relatedtarget). This value *MAY* be `null`.

::: header-wrapper
## A. Acknowledgments

Many thanks to lots of people for their proposals and recommendations,
some of which are incorporated into this document. The group\'s Chair
acknowledges contributions from the following past and present group
members and participants: Mustaq Ahmed, Arthur Barstow, Ben Boyle, Matt
Brubeck, Rick Byers, Marcos Cáceres, Cathy Chan, Bo Cupp, Domenic
Denicola, Ted Dinklocker, Adam Ettenberger, Robert Flack, Dave Fleck,
Mike Fraser, Ella Ge, Olga Gerchikov, Scott González, Kartikaya Gupta,
Dominique Hazael-Massieux, Philippe Le Hégaret, Hayato Ito, Patrick
Kettner, Patrick H. Lauke, Scott Low, Sangwhan Moon, Masayuki Nakano,
Olli Pettay, Addison Phillips, Alan Pyne, Antoine Quint, Jacob Rossi,
Kagami Sascha Rosylight, Doug Schepers, Ming-Chou Shih, Brenton Simpson,
Dave Tapuska, Liviu Tinta, Asir Vedamuthu, Lan Wei, Jeffrey Yasskin,
Navid Zolghadr.

Thanks to those who took care of mouse and wheel events in the past:
Gary Kacmarcik, Travis Leithead, and the [various contributors over the
years](https://www.w3.org/TR/2024/WD-uievents-20240907/#acknowledgements-contributors).

Special thanks to those that helped pioneer the first edition of this
model, including especially: Charu Chandiram, Peter Freiling, Nathan
Furtwangler, Thomas Olsen, Matt Rakow, Ramu Ramanathan, Justin Rogers,
Jacob Rossi, Reed Townsend and Steve Wright.

::: header-wrapper
## B. Revision history

*This section is non-normative.*

The following is an informative summary of substantial and major
editorial changes between publications of this specification, relative
to the \[[PointerEvents3](#bib-pointerevents3 "Pointer Events")\] specification. See the [complete revision history
of the Editor\'s Drafts of this
specification](https://github.com/w3c/pointerevents/commits).

- [Add `persistentDeviceId` to
 `PointerEvent`](https://github.com/w3c/pointerevents/pull/495)

::: header-wrapper
## C. IDL Index

```
WebIDLdictionary PointerEventInit : MouseEventInit {
 long pointerId = 0;
 double width = 1;
 double height = 1;
 float pressure = 0;
 float tangentialPressure = 0;
 long tiltX;
 long tiltY;
 long twist = 0;
 double altitudeAngle;
 double azimuthAngle;
 DOMString pointerType = "";
 boolean isPrimary = false;
 long persistentDeviceId = 0;
 sequence<PointerEvent> coalescedEvents = ;
 sequence<PointerEvent> predictedEvents = ;
};

[Exposed=Window]
interface PointerEvent : MouseEvent {
 constructor(DOMString type, optional PointerEventInit eventInitDict = );
 readonly attribute long pointerId;
 readonly attribute double width;
 readonly attribute double height;
 readonly attribute float pressure;
 readonly attribute float tangentialPressure;
 readonly attribute long tiltX;
 readonly attribute long tiltY;
 readonly attribute long twist;
 readonly attribute double altitudeAngle;
 readonly attribute double azimuthAngle;
 readonly attribute DOMString pointerType;
 readonly attribute boolean isPrimary;
 readonly attribute long persistentDeviceId;
 [SecureContext] sequence<PointerEvent> getCoalescedEvents();
 sequence<PointerEvent> getPredictedEvents();
};

partial interface Element {
 undefined setPointerCapture (long pointerId);
 undefined releasePointerCapture (long pointerId);
 boolean hasPointerCapture (long pointerId);
};

partial interface mixin GlobalEventHandlers {
 attribute EventHandler onpointerover;
 attribute EventHandler onpointerenter;
 attribute EventHandler onpointerdown;
 attribute EventHandler onpointermove;
 [SecureContext] attribute EventHandler onpointerrawupdate;
 attribute EventHandler onpointerup;
 attribute EventHandler onpointercancel;
 attribute EventHandler onpointerout;
 attribute EventHandler onpointerleave;
 attribute EventHandler ongotpointercapture;
 attribute EventHandler onlostpointercapture;
};

partial interface Navigator {
 readonly attribute long maxTouchPoints;
};

dictionary MouseEventInit : EventModifierInit {
 long screenX = 0;
 long screenY = 0;
 long clientX = 0;
 long clientY = 0;

 short button = 0;
 unsigned short buttons = 0;
 EventTarget? relatedTarget = null;
};

[Exposed=Window]
interface MouseEvent : UIEvent {
 constructor(DOMString type, optional MouseEventInit eventInitDict = );
 readonly attribute long screenX;
 readonly attribute long screenY;
 readonly attribute long clientX;
 readonly attribute long clientY;
 readonly attribute long layerX;
 readonly attribute long layerY;

 readonly attribute boolean ctrlKey;
 readonly attribute boolean shiftKey;
 readonly attribute boolean altKey;
 readonly attribute boolean metaKey;

 readonly attribute short button;
 readonly attribute unsigned short buttons;

 readonly attribute EventTarget? relatedTarget;

 boolean getModifierState(DOMString keyArg);
};

dictionary WheelEventInit : MouseEventInit {
 double deltaX = 0.0;
 double deltaY = 0.0;
 double deltaZ = 0.0;
 unsigned long deltaMode = 0;
 boolean momentum = false;
};

[Exposed=Window]
interface WheelEvent : MouseEvent {
 constructor(DOMString type, optional WheelEventInit eventInitDict = );
 // DeltaModeCode
 const unsigned long DOM_DELTA_PIXEL = 0x00;
 const unsigned long DOM_DELTA_LINE = 0x01;
 const unsigned long DOM_DELTA_PAGE = 0x02;

 readonly attribute double deltaX;
 readonly attribute double deltaY;
 readonly attribute double deltaZ;
 readonly attribute unsigned long deltaMode;
 readonly attribute boolean momentum;
};

partial interface MouseEvent {
 // Deprecated in this specification
 undefined initMouseEvent(DOMString typeArg,
 optional boolean bubblesArg = false,
 optional boolean cancelableArg = false,
 optional Window? viewArg = null,
 optional long detailArg = 0,
 optional long screenXArg = 0,
 optional long screenYArg = 0,
 optional long clientXArg = 0,
 optional long clientYArg = 0,
 optional boolean ctrlKeyArg = false,
 optional boolean altKeyArg = false,
 optional boolean shiftKeyArg = false,
 optional boolean metaKeyArg = false,
 optional short buttonArg = 0,
 optional EventTarget? relatedTargetArg = null);
};
```

[Permalink](#dom-pointereventinit-pointerid)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-width)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-height)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-pressure)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-tangentialpressure)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-tiltx)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-tilty)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-twist)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-altitudeangle)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-azimuthangle)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-pointertype)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-isprimary)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-persistentdeviceid)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointereventinit-coalescedevents)
[exported]

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointereventinit-coalescedevents-1 "§ 3.1 PointerEvent interface")

[Permalink](#dom-pointereventinit-predictedevents)
[exported]

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointereventinit-predictedevents-1 "§ 3.1 PointerEvent interface")

[Permalink](#dom-pointerevent-constructor)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-pointerevent-pointerid)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-pointerid-1 "§ 3.1 PointerEvent interface")
 [(2)](#ref-for-dom-pointerevent-pointerid-2 "Reference 2")
 [(3)](#ref-for-dom-pointerevent-pointerid-3 "Reference 3")
 [(4)](#ref-for-dom-pointerevent-pointerid-4 "Reference 4")
 [(5)](#ref-for-dom-pointerevent-pointerid-5 "Reference 5")
 [(6)](#ref-for-dom-pointerevent-pointerid-6 "Reference 6")
 [(7)](#ref-for-dom-pointerevent-pointerid-7 "Reference 7")
 [(8)](#ref-for-dom-pointerevent-pointerid-8 "Reference 8")
 [(9)](#ref-for-dom-pointerevent-pointerid-9 "Reference 9")
 [(10)](#ref-for-dom-pointerevent-pointerid-10 "Reference 10")
 [(11)](#ref-for-dom-pointerevent-pointerid-11 "Reference 11")
 [(12)](#ref-for-dom-pointerevent-pointerid-12 "Reference 12")
- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dom-pointerevent-pointerid-13 "§ 3.1.3 Firing events using the PointerEvent interface")
 [(2)](#ref-for-dom-pointerevent-pointerid-14 "Reference 2")
- [§ 3.1.3.3 Suppressing a pointer event
 stream](#ref-for-dom-pointerevent-pointerid-15 "§ 3.1.3.3 Suppressing a pointer event stream")
- [§ 3.3.5
 pointerrawupdate](#ref-for-dom-pointerevent-pointerid-16 "§ 3.3.5 pointerrawupdate")
- [§ 3.3.7
 pointercancel](#ref-for-dom-pointerevent-pointerid-17 "§ 3.3.7 pointercancel")
- [§ 3.3.12.1 Event
 attributes](#ref-for-dom-pointerevent-pointerid-18 "§ 3.3.12.1 Event attributes")
 [(2)](#ref-for-dom-pointerevent-pointerid-19 "Reference 2")
 [(3)](#ref-for-dom-pointerevent-pointerid-20 "Reference 3")
- [§ 3.3.12.3 Event
 dispatch](#ref-for-dom-pointerevent-pointerid-21 "§ 3.3.12.3 Event dispatch")
- [§ 4. Extensions to the Element
 interface](#ref-for-dom-pointerevent-pointerid-22 "§ 4. Extensions to the Element interface")
 [(2)](#ref-for-dom-pointerevent-pointerid-23 "Reference 2")
 [(3)](#ref-for-dom-pointerevent-pointerid-24 "Reference 3")
 [(4)](#ref-for-dom-pointerevent-pointerid-25 "Reference 4")
- [§ 8.2 Setting pointer
 capture](#ref-for-dom-pointerevent-pointerid-26 "§ 8.2 Setting pointer capture")
 [(2)](#ref-for-dom-pointerevent-pointerid-27 "Reference 2")
 [(3)](#ref-for-dom-pointerevent-pointerid-28 "Reference 3")
- [§ 8.3 Releasing pointer
 capture](#ref-for-dom-pointerevent-pointerid-29 "§ 8.3 Releasing pointer capture")
 [(2)](#ref-for-dom-pointerevent-pointerid-30 "Reference 2")
 [(3)](#ref-for-dom-pointerevent-pointerid-31 "Reference 3")
- [§ 8.5 Implicit release of pointer
 capture](#ref-for-dom-pointerevent-pointerid-32 "§ 8.5 Implicit release of pointer capture")
- [§ 9.1 Coalesced
 events](#ref-for-dom-pointerevent-pointerid-33 "§ 9.1 Coalesced events")
 [(2)](#ref-for-dom-pointerevent-pointerid-34 "Reference 2")
 [(3)](#ref-for-dom-pointerevent-pointerid-35 "Reference 3")
 [(4)](#ref-for-dom-pointerevent-pointerid-36 "Reference 4")
 [(5)](#ref-for-dom-pointerevent-pointerid-37 "Reference 5")
 [(6)](#ref-for-dom-pointerevent-pointerid-38 "Reference 6")
 [(7)](#ref-for-dom-pointerevent-pointerid-39 "Reference 7")
 [(8)](#ref-for-dom-pointerevent-pointerid-40 "Reference 8")
 [(9)](#ref-for-dom-pointerevent-pointerid-41 "Reference 9")
 [(10)](#ref-for-dom-pointerevent-pointerid-42 "Reference 10")
 [(11)](#ref-for-dom-pointerevent-pointerid-43 "Reference 11")
 [(12)](#ref-for-dom-pointerevent-pointerid-44 "Reference 12")
 [(13)](#ref-for-dom-pointerevent-pointerid-45 "Reference 13")
 [(14)](#ref-for-dom-pointerevent-pointerid-46 "Reference 14")
 [(15)](#ref-for-dom-pointerevent-pointerid-47 "Reference 15")
 [(16)](#ref-for-dom-pointerevent-pointerid-48 "Reference 16")
 [(17)](#ref-for-dom-pointerevent-pointerid-49 "Reference 17")
 [(18)](#ref-for-dom-pointerevent-pointerid-50 "Reference 18")
 [(19)](#ref-for-dom-pointerevent-pointerid-51 "Reference 19")
 [(20)](#ref-for-dom-pointerevent-pointerid-52 "Reference 20")
 [(21)](#ref-for-dom-pointerevent-pointerid-53 "Reference 21")
 [(22)](#ref-for-dom-pointerevent-pointerid-54 "Reference 22")
 [(23)](#ref-for-dom-pointerevent-pointerid-55 "Reference 23")
 [(24)](#ref-for-dom-pointerevent-pointerid-56 "Reference 24")
 [(25)](#ref-for-dom-pointerevent-pointerid-57 "Reference 25")
- [§ 9.2 Predicted
 events](#ref-for-dom-pointerevent-pointerid-58 "§ 9.2 Predicted events")
- [§ 9.3 Populating and maintaining the coalesced and predicted events
 lists](#ref-for-dom-pointerevent-pointerid-59 "§ 9.3 Populating and maintaining the coalesced and predicted events lists")
- [§ 15.
 Glossary](#ref-for-dom-pointerevent-pointerid-60 "§ 15. Glossary")
 [(2)](#ref-for-dom-pointerevent-pointerid-61 "Reference 2")
- [§ C. IDL
 Index](#ref-for-dom-pointerevent-pointerid-62 "§ C. IDL Index")

[Permalink](#dom-pointerevent-width)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-width-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL Index](#ref-for-dom-pointerevent-width-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-height)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-height-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL Index](#ref-for-dom-pointerevent-height-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-pressure)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-pressure-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL
 Index](#ref-for-dom-pointerevent-pressure-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-tangentialpressure)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-tangentialpressure-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL
 Index](#ref-for-dom-pointerevent-tangentialpressure-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-tiltx)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-tiltx-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL Index](#ref-for-dom-pointerevent-tiltx-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-tilty)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-tilty-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL Index](#ref-for-dom-pointerevent-tilty-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-twist)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-twist-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL Index](#ref-for-dom-pointerevent-twist-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-altitudeangle)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-altitudeangle-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL
 Index](#ref-for-dom-pointerevent-altitudeangle-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-azimuthangle)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-azimuthangle-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL
 Index](#ref-for-dom-pointerevent-azimuthangle-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-pointertype)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-pointertype-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL
 Index](#ref-for-dom-pointerevent-pointertype-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-isprimary)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-isprimary-1 "§ 3.1 PointerEvent interface")
- [§ C. IDL
 Index](#ref-for-dom-pointerevent-isprimary-2 "§ C. IDL Index")

[Permalink](#dom-pointerevent-persistentdeviceid)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-persistentdeviceid-1 "§ 3.1 PointerEvent interface")
 [(2)](#ref-for-dom-pointerevent-persistentdeviceid-2 "Reference 2")
- [§ C. IDL
 Index](#ref-for-dom-pointerevent-persistentdeviceid-3 "§ C. IDL Index")

[Permalink](#dom-pointerevent-getcoalescedevents)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-getcoalescedevents-1 "§ 3.1 PointerEvent interface")
- [§ 3.3.4
 pointermove](#ref-for-dom-pointerevent-getcoalescedevents-2 "§ 3.3.4 pointermove")
- [§ 3.3.5
 pointerrawupdate](#ref-for-dom-pointerevent-getcoalescedevents-3 "§ 3.3.5 pointerrawupdate")
- [§ 9.1 Coalesced
 events](#ref-for-dom-pointerevent-getcoalescedevents-4 "§ 9.1 Coalesced events")
- [§ C. IDL
 Index](#ref-for-dom-pointerevent-getcoalescedevents-5 "§ C. IDL Index")

[Permalink](#dom-pointerevent-getpredictedevents)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-getpredictedevents-1 "§ 3.1 PointerEvent interface")
- [§ 9.1 Coalesced
 events](#ref-for-dom-pointerevent-getpredictedevents-2 "§ 9.1 Coalesced events")
- [§ 9.2 Predicted
 events](#ref-for-dom-pointerevent-getpredictedevents-3 "§ 9.2 Predicted events")
 [(2)](#ref-for-dom-pointerevent-getpredictedevents-4 "Reference 2")
- [§ C. IDL
 Index](#ref-for-dom-pointerevent-getpredictedevents-5 "§ C. IDL Index")

[Permalink](#dom-pointereventinit)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointereventinit-1 "§ 3.1 PointerEvent interface")
 [(2)](#ref-for-dom-pointereventinit-2 "Reference 2")
 [(3)](#ref-for-dom-pointereventinit-3 "Reference 3")
 [(4)](#ref-for-dom-pointereventinit-4 "Reference 4")
- [§ C. IDL Index](#ref-for-dom-pointereventinit-5 "§ C. IDL Index")
 [(2)](#ref-for-dom-pointereventinit-6 "Reference 2")

[Permalink](#dom-pointerevent)
[exported]
[IDL](#webidl-1641249507 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-pointerevent-1 "§ 3.1 PointerEvent interface")
 [(2)](#ref-for-dom-pointerevent-2 "Reference 2")
 [(3)](#ref-for-dom-pointerevent-3 "Reference 3")
 [(4)](#ref-for-dom-pointerevent-4 "Reference 4")
 [(5)](#ref-for-dom-pointerevent-5 "Reference 5")
 [(6)](#ref-for-dom-pointerevent-6 "Reference 6")
 [(7)](#ref-for-dom-pointerevent-7 "Reference 7")
- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dom-pointerevent-8 "§ 3.1.3 Firing events using the PointerEvent interface")
 [(2)](#ref-for-dom-pointerevent-9 "Reference 2")
- [§ 3.2.1 initialize a
 PointerEvent](#ref-for-dom-pointerevent-10 "§ 3.2.1 initialize a PointerEvent")
 [(2)](#ref-for-dom-pointerevent-11 "Reference 2")
- [§ 3.2.2 create a
 PointerEvent](#ref-for-dom-pointerevent-12 "§ 3.2.2 create a PointerEvent")
 [(2)](#ref-for-dom-pointerevent-13 "Reference 2")
- [§ 3.2.3 create PointerEvent from
 MouseEvent](#ref-for-dom-pointerevent-14 "§ 3.2.3 create PointerEvent from MouseEvent")
- [§ 3.3.1
 pointerover](#ref-for-dom-pointerevent-15 "§ 3.3.1 pointerover")
- [§ 3.3.2
 pointerenter](#ref-for-dom-pointerevent-16 "§ 3.3.2 pointerenter")
- [§ 3.3.3
 pointerdown](#ref-for-dom-pointerevent-17 "§ 3.3.3 pointerdown")
- [§ 3.3.4
 pointermove](#ref-for-dom-pointerevent-18 "§ 3.3.4 pointermove")
- [§ 3.3.5
 pointerrawupdate](#ref-for-dom-pointerevent-19 "§ 3.3.5 pointerrawupdate")
- [§ 3.3.6 pointerup](#ref-for-dom-pointerevent-20 "§ 3.3.6 pointerup")
- [§ 3.3.7
 pointercancel](#ref-for-dom-pointerevent-21 "§ 3.3.7 pointercancel")
- [§ 3.3.8
 pointerout](#ref-for-dom-pointerevent-22 "§ 3.3.8 pointerout")
- [§ 3.3.9
 pointerleave](#ref-for-dom-pointerevent-23 "§ 3.3.9 pointerleave")
- [§ 3.3.10
 gotpointercapture](#ref-for-dom-pointerevent-24 "§ 3.3.10 gotpointercapture")
- [§ 3.3.11
 lostpointercapture](#ref-for-dom-pointerevent-25 "§ 3.3.11 lostpointercapture")
- [§ 3.3.12.2 Event
 coordinates](#ref-for-dom-pointerevent-26 "§ 3.3.12.2 Event coordinates")
 [(2)](#ref-for-dom-pointerevent-27 "Reference 2")
 [(3)](#ref-for-dom-pointerevent-28 "Reference 3")
- [§ 9.1 Coalesced
 events](#ref-for-dom-pointerevent-29 "§ 9.1 Coalesced events")
- [§ 9.2 Predicted
 events](#ref-for-dom-pointerevent-30 "§ 9.2 Predicted events")
- [§ 9.3 Populating and maintaining the coalesced and predicted events
 lists](#ref-for-dom-pointerevent-31 "§ 9.3 Populating and maintaining the coalesced and predicted events lists")
 [(2)](#ref-for-dom-pointerevent-32 "Reference 2")
 [(3)](#ref-for-dom-pointerevent-33 "Reference 3")
- [§ 11.4.1 auxclick](#ref-for-dom-pointerevent-34 "§ 11.4.1 auxclick")
- [§ 11.4.2 click](#ref-for-dom-pointerevent-35 "§ 11.4.2 click")
- [§ 11.4.3
 contextmenu](#ref-for-dom-pointerevent-36 "§ 11.4.3 contextmenu")
- [§ C. IDL Index](#ref-for-dom-pointerevent-37 "§ C. IDL Index")
 [(2)](#ref-for-dom-pointerevent-38 "Reference 2")
 [(3)](#ref-for-dom-pointerevent-39 "Reference 3")
 [(4)](#ref-for-dom-pointerevent-40 "Reference 4")
 [(5)](#ref-for-dom-pointerevent-41 "Reference 5")

[Permalink](#dfn-chorded-buttons)

**Referenced in:**

- [§ 3.3.3
 pointerdown](#ref-for-dfn-chorded-buttons-1 "§ 3.3.3 pointerdown")
- [§ 3.3.4
 pointermove](#ref-for-dfn-chorded-buttons-2 "§ 3.3.4 pointermove")
- [§ 3.3.6
 pointerup](#ref-for-dfn-chorded-buttons-3 "§ 3.3.6 pointerup")

[Permalink](#dfn-primary-pointer)

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dfn-primary-pointer-1 "§ 3.1 PointerEvent interface")
- [§ 3.1.2 The primary
 pointer](#ref-for-dfn-primary-pointer-2 "§ 3.1.2 The primary pointer")
- [§ 3.3 Pointer Event
 types](#ref-for-dfn-primary-pointer-3 "§ 3.3 Pointer Event types")
- [§ 10.1 Tracking the effective position of the legacy mouse
 pointer](#ref-for-dfn-primary-pointer-4 "§ 10.1 Tracking the effective position of the legacy mouse pointer")

[Permalink](#dfn-fire-a-pointer-event)

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dfn-fire-a-pointer-event-1 "§ 3.1 PointerEvent interface")
- [§ 3.3.1
 pointerover](#ref-for-dfn-fire-a-pointer-event-2 "§ 3.3.1 pointerover")
- [§ 3.3.2
 pointerenter](#ref-for-dfn-fire-a-pointer-event-3 "§ 3.3.2 pointerenter")
- [§ 3.3.3
 pointerdown](#ref-for-dfn-fire-a-pointer-event-4 "§ 3.3.3 pointerdown")
 [(2)](#ref-for-dfn-fire-a-pointer-event-5 "Reference 2")
- [§ 3.3.4
 pointermove](#ref-for-dfn-fire-a-pointer-event-6 "§ 3.3.4 pointermove")
- [§ 3.3.5
 pointerrawupdate](#ref-for-dfn-fire-a-pointer-event-7 "§ 3.3.5 pointerrawupdate")
- [§ 3.3.6
 pointerup](#ref-for-dfn-fire-a-pointer-event-8 "§ 3.3.6 pointerup")
 [(2)](#ref-for-dfn-fire-a-pointer-event-9 "Reference 2")
- [§ 3.3.7
 pointercancel](#ref-for-dfn-fire-a-pointer-event-10 "§ 3.3.7 pointercancel")
- [§ 3.3.8
 pointerout](#ref-for-dfn-fire-a-pointer-event-11 "§ 3.3.8 pointerout")
- [§ 3.3.9
 pointerleave](#ref-for-dfn-fire-a-pointer-event-12 "§ 3.3.9 pointerleave")
- [§ 3.3.10
 gotpointercapture](#ref-for-dfn-fire-a-pointer-event-13 "§ 3.3.10 gotpointercapture")
- [§ 3.3.11
 lostpointercapture](#ref-for-dfn-fire-a-pointer-event-14 "§ 3.3.11 lostpointercapture")

[Permalink](#dfn-determine-the-target)

**Referenced in:**

- [§ 3.3.1
 pointerover](#ref-for-dfn-determine-the-target-1 "§ 3.3.1 pointerover")
- [§ 3.3.2
 pointerenter](#ref-for-dfn-determine-the-target-2 "§ 3.3.2 pointerenter")
- [§ 3.3.8
 pointerout](#ref-for-dfn-determine-the-target-3 "§ 3.3.8 pointerout")
- [§ 3.3.9
 pointerleave](#ref-for-dfn-determine-the-target-4 "§ 3.3.9 pointerleave")

[Permalink](#dfn-attributes-and-default-actions)

**Referenced in:**

- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-attributes-and-default-actions-1 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 7. Declaring direct manipulation
 behavior](#ref-for-dfn-attributes-and-default-actions-2 "§ 7. Declaring direct manipulation behavior")

[Permalink](#dfn-process-pending-pointer-capture)

**Referenced in:**

- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-process-pending-pointer-capture-1 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-process-pending-pointer-capture-2 "§ 3.1.3.1 Attributes and default actions")
- [§ 3.3.10
 gotpointercapture](#ref-for-dfn-process-pending-pointer-capture-3 "§ 3.3.10 gotpointercapture")
- [§ 3.3.11
 lostpointercapture](#ref-for-dfn-process-pending-pointer-capture-4 "§ 3.3.11 lostpointercapture")
- [§ 8.2 Setting pointer
 capture](#ref-for-dfn-process-pending-pointer-capture-5 "§ 8.2 Setting pointer capture")
- [§ 8.5 Implicit release of pointer
 capture](#ref-for-dfn-process-pending-pointer-capture-6 "§ 8.5 Implicit release of pointer capture")
 [(2)](#ref-for-dfn-process-pending-pointer-capture-7 "Reference 2")
 [(3)](#ref-for-dfn-process-pending-pointer-capture-8 "Reference 3")

[Permalink](#dfn-pointer-capture-target-override)

**Referenced in:**

- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-pointer-capture-target-override-1 "§ 3.1.3 Firing events using the PointerEvent interface")
 [(2)](#ref-for-dfn-pointer-capture-target-override-2 "Reference 2")
 [(3)](#ref-for-dfn-pointer-capture-target-override-3 "Reference 3")
- [§ 3.1.3.2 Process pending pointer
 capture](#ref-for-dfn-pointer-capture-target-override-4 "§ 3.1.3.2 Process pending pointer capture")
 [(2)](#ref-for-dfn-pointer-capture-target-override-5 "Reference 2")
 [(3)](#ref-for-dfn-pointer-capture-target-override-6 "Reference 3")
 [(4)](#ref-for-dfn-pointer-capture-target-override-7 "Reference 4")
- [§ 8.5 Implicit release of pointer
 capture](#ref-for-dfn-pointer-capture-target-override-8 "§ 8.5 Implicit release of pointer capture")
 [(2)](#ref-for-dfn-pointer-capture-target-override-9 "Reference 2")

[Permalink](#dfn-suppress-a-pointer-event-stream)

**Referenced in:**

- [§ 3.1.3.3 Suppressing a pointer event
 stream](#ref-for-dfn-suppress-a-pointer-event-stream-1 "§ 3.1.3.3 Suppressing a pointer event stream")
 [(2)](#ref-for-dfn-suppress-a-pointer-event-stream-2 "Reference 2")
- [§ 3.3.7
 pointercancel](#ref-for-dfn-suppress-a-pointer-event-stream-3 "§ 3.3.7 pointercancel")
- [§ 3.3.8
 pointerout](#ref-for-dfn-suppress-a-pointer-event-stream-4 "§ 3.3.8 pointerout")
- [§ 3.3.9
 pointerleave](#ref-for-dfn-suppress-a-pointer-event-stream-5 "§ 3.3.9 pointerleave")
- [§ 7.1 The touch-action CSS
 property](#ref-for-dfn-suppress-a-pointer-event-stream-6 "§ 7.1 The touch-action CSS property")

[Permalink](#dfn-events-from-layout-changes)

**Referenced in:**

- [§ 3.3.1
 pointerover](#ref-for-dfn-events-from-layout-changes-1 "§ 3.3.1 pointerover")
- [§ 3.3.2
 pointerenter](#ref-for-dfn-events-from-layout-changes-2 "§ 3.3.2 pointerenter")
- [§ 3.3.8
 pointerout](#ref-for-dfn-events-from-layout-changes-3 "§ 3.3.8 pointerout")
- [§ 3.3.9
 pointerleave](#ref-for-dfn-events-from-layout-changes-4 "§ 3.3.9 pointerleave")

[Permalink](#dfn-initialize-a-pointerevent)
[exported]

**Referenced in:**

- [§ 3.2.2 create a
 PointerEvent](#ref-for-dfn-initialize-a-pointerevent-1 "§ 3.2.2 create a PointerEvent")
- [§ 3.2.3 create PointerEvent from
 MouseEvent](#ref-for-dfn-initialize-a-pointerevent-2 "§ 3.2.3 create PointerEvent from MouseEvent")

[Permalink](#dfn-creating-a-pointerevent)
[exported]

**Referenced in:**

- [§ 11.2.15 send click
 event](#ref-for-dfn-creating-a-pointerevent-1 "§ 11.2.15 send click event")
- [§ 11.2.16 handle native mouse double
 click](#ref-for-dfn-creating-a-pointerevent-2 "§ 11.2.16 handle native mouse double click")
- [§ 11.2.18 maybe show context
 menu](#ref-for-dfn-creating-a-pointerevent-3 "§ 11.2.18 maybe show context menu")

[Permalink](#dfn-creating-pointerevent-from-mouseevent)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-pointer-event-types)

**Referenced in:**

- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-pointer-event-types-1 "§ 3.1.3.1 Attributes and default actions")
- [§ 3.1.4 Boundary events caused by layout
 changes](#ref-for-dfn-pointer-event-types-2 "§ 3.1.4 Boundary events caused by layout changes")

[Permalink](#dfn-pointerover)
[exported]

**Referenced in:**

- [§ 1. Introduction](#ref-for-dfn-pointerover-1 "§ 1. Introduction")
- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-pointerover-2 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-pointerover-3 "§ 3.1.3.1 Attributes and default actions")
 [(2)](#ref-for-dfn-pointerover-4 "Reference 2")
- [§ 3.1.4 Boundary events caused by layout
 changes](#ref-for-dfn-pointerover-5 "§ 3.1.4 Boundary events caused by layout changes")
- [§ 3.3.1
 pointerover](#ref-for-dfn-pointerover-6 "§ 3.3.1 pointerover")
- [§ 3.3.2
 pointerenter](#ref-for-dfn-pointerover-7 "§ 3.3.2 pointerenter")
- [§ 3.3.3
 pointerdown](#ref-for-dfn-pointerover-8 "§ 3.3.3 pointerdown")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-pointerover-9 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ 10.3 Mapping for devices that do not support
 hover](#ref-for-dfn-pointerover-10 "§ 10.3 Mapping for devices that do not support hover")
 [(2)](#ref-for-dfn-pointerover-11 "Reference 2")
 [(3)](#ref-for-dfn-pointerover-12 "Reference 3")

[Permalink](#dfn-pointerenter)
[exported]

**Referenced in:**

- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-pointerenter-1 "§ 3.1.3.1 Attributes and default actions")
 [(2)](#ref-for-dfn-pointerenter-2 "Reference 2")
- [§ 3.1.4 Boundary events caused by layout
 changes](#ref-for-dfn-pointerenter-3 "§ 3.1.4 Boundary events caused by layout changes")
- [§ 3.3.2
 pointerenter](#ref-for-dfn-pointerenter-4 "§ 3.3.2 pointerenter")
 [(2)](#ref-for-dfn-pointerenter-5 "Reference 2")
- [§ 3.3.3
 pointerdown](#ref-for-dfn-pointerenter-6 "§ 3.3.3 pointerdown")
- [§ 3.3.9
 pointerleave](#ref-for-dfn-pointerenter-7 "§ 3.3.9 pointerleave")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-pointerenter-8 "§ 5. Extensions to the GlobalEventHandlers mixin")

[Permalink](#dfn-pointerdown)

**Referenced in:**

- [§ 1. Introduction](#ref-for-dfn-pointerdown-1 "§ 1. Introduction")
- [§ 3.1.1.1 Chorded button
 interactions](#ref-for-dfn-pointerdown-2 "§ 3.1.1.1 Chorded button interactions")
- [§ 3.1.1.2 The button
 property](#ref-for-dfn-pointerdown-3 "§ 3.1.1.2 The button property")
- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-pointerdown-4 "§ 3.1.3 Firing events using the PointerEvent interface")
 [(2)](#ref-for-dfn-pointerdown-5 "Reference 2")
- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-pointerdown-6 "§ 3.1.3.1 Attributes and default actions")
- [§ 3.3.1
 pointerover](#ref-for-dfn-pointerdown-7 "§ 3.3.1 pointerover")
 [(2)](#ref-for-dfn-pointerdown-8 "Reference 2")
- [§ 3.3.2
 pointerenter](#ref-for-dfn-pointerdown-9 "§ 3.3.2 pointerenter")
 [(2)](#ref-for-dfn-pointerdown-10 "Reference 2")
- [§ 3.3.3
 pointerdown](#ref-for-dfn-pointerdown-11 "§ 3.3.3 pointerdown")
 [(2)](#ref-for-dfn-pointerdown-12 "Reference 2")
 [(3)](#ref-for-dfn-pointerdown-13 "Reference 3")
 [(4)](#ref-for-dfn-pointerdown-14 "Reference 4")
- [§ 3.3.4
 pointermove](#ref-for-dfn-pointerdown-15 "§ 3.3.4 pointermove")
- [§ 3.3.6 pointerup](#ref-for-dfn-pointerdown-16 "§ 3.3.6 pointerup")
- [§ 3.3.12.3 Event
 dispatch](#ref-for-dfn-pointerdown-17 "§ 3.3.12.3 Event dispatch")
- [§ 4. Extensions to the Element
 interface](#ref-for-dfn-pointerdown-18 "§ 4. Extensions to the Element interface")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-pointerdown-19 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ 7.1 The touch-action CSS
 property](#ref-for-dfn-pointerdown-20 "§ 7.1 The touch-action CSS property")
 [(2)](#ref-for-dfn-pointerdown-21 "Reference 2")
- [§ 7.2 Determining supported direct manipulation
 behavior](#ref-for-dfn-pointerdown-22 "§ 7.2 Determining supported direct manipulation behavior")
- [§ 8.1 Introduction](#ref-for-dfn-pointerdown-23 "§ 8.1 Introduction")
- [§ 8.2 Setting pointer
 capture](#ref-for-dfn-pointerdown-24 "§ 8.2 Setting pointer capture")
- [§ 8.4 Implicit pointer
 capture](#ref-for-dfn-pointerdown-25 "§ 8.4 Implicit pointer capture")
 [(2)](#ref-for-dfn-pointerdown-26 "Reference 2")
- [§ 9.1 Coalesced
 events](#ref-for-dfn-pointerdown-27 "§ 9.1 Coalesced events")
 [(2)](#ref-for-dfn-pointerdown-28 "Reference 2")
 [(3)](#ref-for-dfn-pointerdown-29 "Reference 3")
- [§ 10. Compatibility mapping with mouse
 events](#ref-for-dfn-pointerdown-30 "§ 10. Compatibility mapping with mouse events")
 [(2)](#ref-for-dfn-pointerdown-31 "Reference 2")
- [§ 10.1 Tracking the effective position of the legacy mouse
 pointer](#ref-for-dfn-pointerdown-32 "§ 10.1 Tracking the effective position of the legacy mouse pointer")
 [(2)](#ref-for-dfn-pointerdown-33 "Reference 2")
- [§ 10.2 Mapping for devices that support
 hover](#ref-for-dfn-pointerdown-34 "§ 10.2 Mapping for devices that support hover")
 [(2)](#ref-for-dfn-pointerdown-35 "Reference 2")
 [(3)](#ref-for-dfn-pointerdown-36 "Reference 3")
- [§ 10.3 Mapping for devices that do not support
 hover](#ref-for-dfn-pointerdown-37 "§ 10.3 Mapping for devices that do not support hover")
 [(2)](#ref-for-dfn-pointerdown-38 "Reference 2")
 [(3)](#ref-for-dfn-pointerdown-39 "Reference 3")
 [(4)](#ref-for-dfn-pointerdown-40 "Reference 4")
 [(5)](#ref-for-dfn-pointerdown-41 "Reference 5")
 [(6)](#ref-for-dfn-pointerdown-42 "Reference 6")
 [(7)](#ref-for-dfn-pointerdown-43 "Reference 7")

[Permalink](#dfn-pointermove)

**Referenced in:**

- [§ 1. Introduction](#ref-for-dfn-pointermove-1 "§ 1. Introduction")
- [§ 3.1.1.2 The button
 property](#ref-for-dfn-pointermove-2 "§ 3.1.1.2 The button property")
 [(2)](#ref-for-dfn-pointermove-3 "Reference 2")
- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-pointermove-4 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-pointermove-5 "§ 3.1.3.1 Attributes and default actions")
- [§ 3.1.4 Boundary events caused by layout
 changes](#ref-for-dfn-pointermove-6 "§ 3.1.4 Boundary events caused by layout changes")
- [§ 3.3.4
 pointermove](#ref-for-dfn-pointermove-7 "§ 3.3.4 pointermove")
 [(2)](#ref-for-dfn-pointermove-8 "Reference 2")
 [(3)](#ref-for-dfn-pointermove-9 "Reference 3")
- [§ 3.3.5
 pointerrawupdate](#ref-for-dfn-pointermove-10 "§ 3.3.5 pointerrawupdate")
 [(2)](#ref-for-dfn-pointermove-11 "Reference 2")
 [(3)](#ref-for-dfn-pointermove-12 "Reference 3")
 [(4)](#ref-for-dfn-pointermove-13 "Reference 4")
 [(5)](#ref-for-dfn-pointermove-14 "Reference 5")
 [(6)](#ref-for-dfn-pointermove-15 "Reference 6")
 [(7)](#ref-for-dfn-pointermove-16 "Reference 7")
 [(8)](#ref-for-dfn-pointermove-17 "Reference 8")
 [(9)](#ref-for-dfn-pointermove-18 "Reference 9")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-pointermove-19 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ 9.1 Coalesced
 events](#ref-for-dfn-pointermove-20 "§ 9.1 Coalesced events")
 [(2)](#ref-for-dfn-pointermove-21 "Reference 2")
 [(3)](#ref-for-dfn-pointermove-22 "Reference 3")
 [(4)](#ref-for-dfn-pointermove-23 "Reference 4")
 [(5)](#ref-for-dfn-pointermove-24 "Reference 5")
 [(6)](#ref-for-dfn-pointermove-25 "Reference 6")
 [(7)](#ref-for-dfn-pointermove-26 "Reference 7")
 [(8)](#ref-for-dfn-pointermove-27 "Reference 8")
 [(9)](#ref-for-dfn-pointermove-28 "Reference 9")
 [(10)](#ref-for-dfn-pointermove-29 "Reference 10")
- [§ 9.2 Predicted
 events](#ref-for-dfn-pointermove-30 "§ 9.2 Predicted events")
 [(2)](#ref-for-dfn-pointermove-31 "Reference 2")
- [§ 10.1 Tracking the effective position of the legacy mouse
 pointer](#ref-for-dfn-pointermove-32 "§ 10.1 Tracking the effective position of the legacy mouse pointer")
 [(2)](#ref-for-dfn-pointermove-33 "Reference 2")
- [§ 10.2 Mapping for devices that support
 hover](#ref-for-dfn-pointermove-34 "§ 10.2 Mapping for devices that support hover")
 [(2)](#ref-for-dfn-pointermove-35 "Reference 2")
- [§ 10.3 Mapping for devices that do not support
 hover](#ref-for-dfn-pointermove-36 "§ 10.3 Mapping for devices that do not support hover")
 [(2)](#ref-for-dfn-pointermove-37 "Reference 2")
 [(3)](#ref-for-dfn-pointermove-38 "Reference 3")
 [(4)](#ref-for-dfn-pointermove-39 "Reference 4")

[Permalink](#dfn-pointerrawupdate)

**Referenced in:**

- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-pointerrawupdate-1 "§ 3.1.3.1 Attributes and default actions")
- [§ 3.3.5
 pointerrawupdate](#ref-for-dfn-pointerrawupdate-2 "§ 3.3.5 pointerrawupdate")
 [(2)](#ref-for-dfn-pointerrawupdate-3 "Reference 2")
 [(3)](#ref-for-dfn-pointerrawupdate-4 "Reference 3")
 [(4)](#ref-for-dfn-pointerrawupdate-5 "Reference 4")
 [(5)](#ref-for-dfn-pointerrawupdate-6 "Reference 5")
 [(6)](#ref-for-dfn-pointerrawupdate-7 "Reference 6")
 [(7)](#ref-for-dfn-pointerrawupdate-8 "Reference 7")
 [(8)](#ref-for-dfn-pointerrawupdate-9 "Reference 8")
 [(9)](#ref-for-dfn-pointerrawupdate-10 "Reference 9")
 [(10)](#ref-for-dfn-pointerrawupdate-11 "Reference 10")
 [(11)](#ref-for-dfn-pointerrawupdate-12 "Reference 11")
 [(12)](#ref-for-dfn-pointerrawupdate-13 "Reference 12")
 [(13)](#ref-for-dfn-pointerrawupdate-14 "Reference 13")
 [(14)](#ref-for-dfn-pointerrawupdate-15 "Reference 14")
 [(15)](#ref-for-dfn-pointerrawupdate-16 "Reference 15")
 [(16)](#ref-for-dfn-pointerrawupdate-17 "Reference 16")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-pointerrawupdate-18 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ 9.1 Coalesced
 events](#ref-for-dfn-pointerrawupdate-19 "§ 9.1 Coalesced events")
 [(2)](#ref-for-dfn-pointerrawupdate-20 "Reference 2")
 [(3)](#ref-for-dfn-pointerrawupdate-21 "Reference 3")
 [(4)](#ref-for-dfn-pointerrawupdate-22 "Reference 4")
 [(5)](#ref-for-dfn-pointerrawupdate-23 "Reference 5")
 [(6)](#ref-for-dfn-pointerrawupdate-24 "Reference 6")
 [(7)](#ref-for-dfn-pointerrawupdate-25 "Reference 7")
 [(8)](#ref-for-dfn-pointerrawupdate-26 "Reference 8")
 [(9)](#ref-for-dfn-pointerrawupdate-27 "Reference 9")
 [(10)](#ref-for-dfn-pointerrawupdate-28 "Reference 10")
 [(11)](#ref-for-dfn-pointerrawupdate-29 "Reference 11")

[Permalink](#dfn-pointerup)

**Referenced in:**

- [§ 1. Introduction](#ref-for-dfn-pointerup-1 "§ 1. Introduction")
- [§ 3.1.1.1 Chorded button
 interactions](#ref-for-dfn-pointerup-2 "§ 3.1.1.1 Chorded button interactions")
- [§ 3.1.1.2 The button
 property](#ref-for-dfn-pointerup-3 "§ 3.1.1.2 The button property")
- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-pointerup-4 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-pointerup-5 "§ 3.1.3.1 Attributes and default actions")
- [§ 3.3.3 pointerdown](#ref-for-dfn-pointerup-6 "§ 3.3.3 pointerdown")
- [§ 3.3.4 pointermove](#ref-for-dfn-pointerup-7 "§ 3.3.4 pointermove")
- [§ 3.3.6 pointerup](#ref-for-dfn-pointerup-8 "§ 3.3.6 pointerup")
 [(2)](#ref-for-dfn-pointerup-9 "Reference 2")
 [(3)](#ref-for-dfn-pointerup-10 "Reference 3")
 [(4)](#ref-for-dfn-pointerup-11 "Reference 4")
- [§ 3.3.8 pointerout](#ref-for-dfn-pointerup-12 "§ 3.3.8 pointerout")
 [(2)](#ref-for-dfn-pointerup-13 "Reference 2")
- [§ 3.3.9
 pointerleave](#ref-for-dfn-pointerup-14 "§ 3.3.9 pointerleave")
 [(2)](#ref-for-dfn-pointerup-15 "Reference 2")
- [§ 3.3.12.3 Event
 dispatch](#ref-for-dfn-pointerup-16 "§ 3.3.12.3 Event dispatch")
 [(2)](#ref-for-dfn-pointerup-17 "Reference 2")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-pointerup-18 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ 7.1 The touch-action CSS
 property](#ref-for-dfn-pointerup-19 "§ 7.1 The touch-action CSS property")
- [§ 8.5 Implicit release of pointer
 capture](#ref-for-dfn-pointerup-20 "§ 8.5 Implicit release of pointer capture")
 [(2)](#ref-for-dfn-pointerup-21 "Reference 2")
- [§ 9.1 Coalesced
 events](#ref-for-dfn-pointerup-22 "§ 9.1 Coalesced events")
- [§ 10. Compatibility mapping with mouse
 events](#ref-for-dfn-pointerup-23 "§ 10. Compatibility mapping with mouse events")
 [(2)](#ref-for-dfn-pointerup-24 "Reference 2")
 [(3)](#ref-for-dfn-pointerup-25 "Reference 3")
 [(4)](#ref-for-dfn-pointerup-26 "Reference 4")
 [(5)](#ref-for-dfn-pointerup-27 "Reference 5")
- [§ 10.1 Tracking the effective position of the legacy mouse
 pointer](#ref-for-dfn-pointerup-28 "§ 10.1 Tracking the effective position of the legacy mouse pointer")
 [(2)](#ref-for-dfn-pointerup-29 "Reference 2")
- [§ 10.2 Mapping for devices that support
 hover](#ref-for-dfn-pointerup-30 "§ 10.2 Mapping for devices that support hover")
 [(2)](#ref-for-dfn-pointerup-31 "Reference 2")
 [(3)](#ref-for-dfn-pointerup-32 "Reference 3")
- [§ 10.3 Mapping for devices that do not support
 hover](#ref-for-dfn-pointerup-33 "§ 10.3 Mapping for devices that do not support hover")
 [(2)](#ref-for-dfn-pointerup-34 "Reference 2")
 [(3)](#ref-for-dfn-pointerup-35 "Reference 3")
 [(4)](#ref-for-dfn-pointerup-36 "Reference 4")
 [(5)](#ref-for-dfn-pointerup-37 "Reference 5")

[Permalink](#dfn-pointercancel)

**Referenced in:**

- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-pointercancel-1 "§ 3.1.3.1 Attributes and default actions")
- [§ 3.1.3.3 Suppressing a pointer event
 stream](#ref-for-dfn-pointercancel-2 "§ 3.1.3.3 Suppressing a pointer event stream")
- [§ 3.3.7
 pointercancel](#ref-for-dfn-pointercancel-3 "§ 3.3.7 pointercancel")
 [(2)](#ref-for-dfn-pointercancel-4 "Reference 2")
 [(3)](#ref-for-dfn-pointercancel-5 "Reference 3")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-pointercancel-6 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ 7.1 The touch-action CSS
 property](#ref-for-dfn-pointercancel-7 "§ 7.1 The touch-action CSS property")
- [§ 8.5 Implicit release of pointer
 capture](#ref-for-dfn-pointercancel-8 "§ 8.5 Implicit release of pointer capture")
 [(2)](#ref-for-dfn-pointercancel-9 "Reference 2")
- [§ 10. Compatibility mapping with mouse
 events](#ref-for-dfn-pointercancel-10 "§ 10. Compatibility mapping with mouse events")
- [§ 10.2 Mapping for devices that support
 hover](#ref-for-dfn-pointercancel-11 "§ 10.2 Mapping for devices that support hover")
 [(2)](#ref-for-dfn-pointercancel-12 "Reference 2")
- [§ 10.3 Mapping for devices that do not support
 hover](#ref-for-dfn-pointercancel-13 "§ 10.3 Mapping for devices that do not support hover")
 [(2)](#ref-for-dfn-pointercancel-14 "Reference 2")

[Permalink](#dfn-pointerout)

**Referenced in:**

- [§ 1. Introduction](#ref-for-dfn-pointerout-1 "§ 1. Introduction")
- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-pointerout-2 "§ 3.1.3.1 Attributes and default actions")
 [(2)](#ref-for-dfn-pointerout-3 "Reference 2")
- [§ 3.1.3.3 Suppressing a pointer event
 stream](#ref-for-dfn-pointerout-4 "§ 3.1.3.3 Suppressing a pointer event stream")
- [§ 3.1.4 Boundary events caused by layout
 changes](#ref-for-dfn-pointerout-5 "§ 3.1.4 Boundary events caused by layout changes")
- [§ 3.3.6 pointerup](#ref-for-dfn-pointerout-6 "§ 3.3.6 pointerup")
- [§ 3.3.8 pointerout](#ref-for-dfn-pointerout-7 "§ 3.3.8 pointerout")
- [§ 3.3.9
 pointerleave](#ref-for-dfn-pointerout-8 "§ 3.3.9 pointerleave")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-pointerout-9 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ 10.3 Mapping for devices that do not support
 hover](#ref-for-dfn-pointerout-10 "§ 10.3 Mapping for devices that do not support hover")
 [(2)](#ref-for-dfn-pointerout-11 "Reference 2")

[Permalink](#dfn-pointerleave)

**Referenced in:**

- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-pointerleave-1 "§ 3.1.3.1 Attributes and default actions")
 [(2)](#ref-for-dfn-pointerleave-2 "Reference 2")
 [(3)](#ref-for-dfn-pointerleave-3 "Reference 3")
- [§ 3.1.3.3 Suppressing a pointer event
 stream](#ref-for-dfn-pointerleave-4 "§ 3.1.3.3 Suppressing a pointer event stream")
- [§ 3.1.4 Boundary events caused by layout
 changes](#ref-for-dfn-pointerleave-5 "§ 3.1.4 Boundary events caused by layout changes")
- [§ 3.3.2
 pointerenter](#ref-for-dfn-pointerleave-6 "§ 3.3.2 pointerenter")
- [§ 3.3.6 pointerup](#ref-for-dfn-pointerleave-7 "§ 3.3.6 pointerup")
- [§ 3.3.9
 pointerleave](#ref-for-dfn-pointerleave-8 "§ 3.3.9 pointerleave")
 [(2)](#ref-for-dfn-pointerleave-9 "Reference 2")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-pointerleave-10 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ 10.1 Tracking the effective position of the legacy mouse
 pointer](#ref-for-dfn-pointerleave-11 "§ 10.1 Tracking the effective position of the legacy mouse pointer")
 [(2)](#ref-for-dfn-pointerleave-12 "Reference 2")
- [§ 10.2 Mapping for devices that support
 hover](#ref-for-dfn-pointerleave-13 "§ 10.2 Mapping for devices that support hover")
- [§ 10.3 Mapping for devices that do not support
 hover](#ref-for-dfn-pointerleave-14 "§ 10.3 Mapping for devices that do not support hover")
 [(2)](#ref-for-dfn-pointerleave-15 "Reference 2")
 [(3)](#ref-for-dfn-pointerleave-16 "Reference 3")

[Permalink](#dfn-gotpointercapture)

**Referenced in:**

- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-gotpointercapture-1 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-gotpointercapture-2 "§ 3.1.3.1 Attributes and default actions")
 [(2)](#ref-for-dfn-gotpointercapture-3 "Reference 2")
 [(3)](#ref-for-dfn-gotpointercapture-4 "Reference 3")
- [§ 3.1.3.2 Process pending pointer
 capture](#ref-for-dfn-gotpointercapture-5 "§ 3.1.3.2 Process pending pointer capture")
 [(2)](#ref-for-dfn-gotpointercapture-6 "Reference 2")
- [§ 3.3 Pointer Event
 types](#ref-for-dfn-gotpointercapture-7 "§ 3.3 Pointer Event types")
- [§ 3.3.10
 gotpointercapture](#ref-for-dfn-gotpointercapture-8 "§ 3.3.10 gotpointercapture")
- [§ 4. Extensions to the Element
 interface](#ref-for-dfn-gotpointercapture-9 "§ 4. Extensions to the Element interface")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-gotpointercapture-10 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ 8.4 Implicit pointer
 capture](#ref-for-dfn-gotpointercapture-11 "§ 8.4 Implicit pointer capture")

[Permalink](#dfn-lostpointercapture)

**Referenced in:**

- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-lostpointercapture-1 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-lostpointercapture-2 "§ 3.1.3.1 Attributes and default actions")
 [(2)](#ref-for-dfn-lostpointercapture-3 "Reference 2")
 [(3)](#ref-for-dfn-lostpointercapture-4 "Reference 3")
- [§ 3.1.3.2 Process pending pointer
 capture](#ref-for-dfn-lostpointercapture-5 "§ 3.1.3.2 Process pending pointer capture")
 [(2)](#ref-for-dfn-lostpointercapture-6 "Reference 2")
 [(3)](#ref-for-dfn-lostpointercapture-7 "Reference 3")
- [§ 3.3 Pointer Event
 types](#ref-for-dfn-lostpointercapture-8 "§ 3.3 Pointer Event types")
- [§ 3.3.11
 lostpointercapture](#ref-for-dfn-lostpointercapture-9 "§ 3.3.11 lostpointercapture")
- [§ 3.3.12.3 Event
 dispatch](#ref-for-dfn-lostpointercapture-10 "§ 3.3.12.3 Event dispatch")
- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dfn-lostpointercapture-11 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ 8.5 Implicit release of pointer
 capture](#ref-for-dfn-lostpointercapture-12 "§ 8.5 Implicit release of pointer capture")
 [(2)](#ref-for-dfn-lostpointercapture-13 "Reference 2")

[Permalink](#dfn-click-auxclick-and-contextmenu)

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dfn-click-auxclick-and-contextmenu-1 "§ 3.1 PointerEvent interface")
- [§ 3.1.3.2 Process pending pointer
 capture](#ref-for-dfn-click-auxclick-and-contextmenu-2 "§ 3.1.3.2 Process pending pointer capture")
- [§ 3.3.11
 lostpointercapture](#ref-for-dfn-click-auxclick-and-contextmenu-3 "§ 3.3.11 lostpointercapture")

[Permalink](#dom-element-setpointercapture)
[exported]
[IDL](#webidl-1931716547 "Jump to IDL declaration")

**Referenced in:**

- [§ 4. Extensions to the Element
 interface](#ref-for-dom-element-setpointercapture-1 "§ 4. Extensions to the Element interface")
 [(2)](#ref-for-dom-element-setpointercapture-2 "Reference 2")
- [§ 8.4 Implicit pointer
 capture](#ref-for-dom-element-setpointercapture-3 "§ 8.4 Implicit pointer capture")
- [§ C. IDL
 Index](#ref-for-dom-element-setpointercapture-4 "§ C. IDL Index")

[Permalink](#dom-element-releasepointercapture)
[exported]
[IDL](#webidl-1931716547 "Jump to IDL declaration")

**Referenced in:**

- [§ 4. Extensions to the Element
 interface](#ref-for-dom-element-releasepointercapture-1 "§ 4. Extensions to the Element interface")
- [§ 8.4 Implicit pointer
 capture](#ref-for-dom-element-releasepointercapture-2 "§ 8.4 Implicit pointer capture")
- [§ 8.5 Implicit release of pointer
 capture](#ref-for-dom-element-releasepointercapture-3 "§ 8.5 Implicit release of pointer capture")
- [§ C. IDL
 Index](#ref-for-dom-element-releasepointercapture-4 "§ C. IDL Index")

[Permalink](#dom-element-haspointercapture)
[exported]
[IDL](#webidl-1931716547 "Jump to IDL declaration")

**Referenced in:**

- [§ 4. Extensions to the Element
 interface](#ref-for-dom-element-haspointercapture-1 "§ 4. Extensions to the Element interface")
- [§ 8.3 Releasing pointer
 capture](#ref-for-dom-element-haspointercapture-2 "§ 8.3 Releasing pointer capture")
- [§ 8.4 Implicit pointer
 capture](#ref-for-dom-element-haspointercapture-3 "§ 8.4 Implicit pointer capture")
- [§ C. IDL
 Index](#ref-for-dom-element-haspointercapture-4 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-onpointerover)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-onpointerover-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-onpointerover-2 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-onpointerenter)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-onpointerenter-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-onpointerenter-2 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-onpointerdown)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-onpointerdown-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-onpointerdown-2 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-onpointermove)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-onpointermove-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-onpointermove-2 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-onpointerrawupdate)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-onpointerrawupdate-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-onpointerrawupdate-2 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-onpointerup)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-onpointerup-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-onpointerup-2 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-onpointercancel)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-onpointercancel-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-onpointercancel-2 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-onpointerout)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-onpointerout-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-onpointerout-2 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-onpointerleave)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-onpointerleave-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-onpointerleave-2 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-ongotpointercapture)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-ongotpointercapture-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-ongotpointercapture-2 "§ C. IDL Index")

[Permalink](#dom-globaleventhandlers-onlostpointercapture)
[exported]
[IDL](#webidl-2079438067 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the GlobalEventHandlers
 mixin](#ref-for-dom-globaleventhandlers-onlostpointercapture-1 "§ 5. Extensions to the GlobalEventHandlers mixin")
- [§ C. IDL
 Index](#ref-for-dom-globaleventhandlers-onlostpointercapture-2 "§ C. IDL Index")

[Permalink](#dom-navigator-maxtouchpoints)
[exported]
[IDL](#webidl-1577842999 "Jump to IDL declaration")

**Referenced in:**

- [§ 6. Extensions to the Navigator
 interface](#ref-for-dom-navigator-maxtouchpoints-1 "§ 6. Extensions to the Navigator interface")
- [§ C. IDL
 Index](#ref-for-dom-navigator-maxtouchpoints-2 "§ C. IDL Index")

[Permalink](#dfn-direct-manipulation-behavior)

**Referenced in:**

- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-direct-manipulation-behavior-1 "§ 3.1.3.1 Attributes and default actions")

[Permalink](#dfn-touch-action)

**Referenced in:**

- [§ 3.1.3.3 Suppressing a pointer event
 stream](#ref-for-dfn-touch-action-1 "§ 3.1.3.3 Suppressing a pointer event stream")
- [§ 10. Compatibility mapping with mouse
 events](#ref-for-dfn-touch-action-2 "§ 10. Compatibility mapping with mouse events")

[Permalink](#dfn-conforming-touch-behavior)

**Referenced in:**

- [§ 7.2 Determining supported direct manipulation
 behavior](#ref-for-dfn-conforming-touch-behavior-1 "§ 7.2 Determining supported direct manipulation behavior")
 [(2)](#ref-for-dfn-conforming-touch-behavior-2 "Reference 2")

[Permalink](#dfn-touch-action-values)

**Referenced in:**

- [§ Status of This
 Document](#ref-for-dfn-touch-action-values-1 "§ Status of This Document")
- [§ 7.1 The touch-action CSS
 property](#ref-for-dfn-touch-action-values-2 "§ 7.1 The touch-action CSS property")

[Permalink](#dfn-pointer-capture)
[exported]

**Referenced in:**

- [§ 4. Extensions to the Element
 interface](#ref-for-dfn-pointer-capture-1 "§ 4. Extensions to the Element interface")

[Permalink](#dfn-set-pointer-capture)

**Referenced in:**

- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-set-pointer-capture-1 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 3.3.10
 gotpointercapture](#ref-for-dfn-set-pointer-capture-2 "§ 3.3.10 gotpointercapture")
- [§ 4. Extensions to the Element
 interface](#ref-for-dfn-set-pointer-capture-3 "§ 4. Extensions to the Element interface")
- [§ 8.3 Releasing pointer
 capture](#ref-for-dfn-set-pointer-capture-4 "§ 8.3 Releasing pointer capture")

[Permalink](#dfn-pending-pointer-capture-target-override)

**Referenced in:**

- [§ 3.1.3.2 Process pending pointer
 capture](#ref-for-dfn-pending-pointer-capture-target-override-1 "§ 3.1.3.2 Process pending pointer capture")
 [(2)](#ref-for-dfn-pending-pointer-capture-target-override-2 "Reference 2")
 [(3)](#ref-for-dfn-pending-pointer-capture-target-override-3 "Reference 3")
 [(4)](#ref-for-dfn-pending-pointer-capture-target-override-4 "Reference 4")
- [§ 4. Extensions to the Element
 interface](#ref-for-dfn-pending-pointer-capture-target-override-5 "§ 4. Extensions to the Element interface")
- [§ 8.3 Releasing pointer
 capture](#ref-for-dfn-pending-pointer-capture-target-override-6 "§ 8.3 Releasing pointer capture")
- [§ 8.5 Implicit release of pointer
 capture](#ref-for-dfn-pending-pointer-capture-target-override-7 "§ 8.5 Implicit release of pointer capture")
 [(2)](#ref-for-dfn-pending-pointer-capture-target-override-8 "Reference 2")
 [(3)](#ref-for-dfn-pending-pointer-capture-target-override-9 "Reference 3")

[Permalink](#dfn-release-pointer-capture)

**Referenced in:**

- [§ 3.3.11
 lostpointercapture](#ref-for-dfn-release-pointer-capture-1 "§ 3.3.11 lostpointercapture")
- [§ 4. Extensions to the Element
 interface](#ref-for-dfn-release-pointer-capture-2 "§ 4. Extensions to the Element interface")

[Permalink](#dfn-implicit-pointer-capture)

**Referenced in:**

- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-implicit-pointer-capture-1 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 4. Extensions to the Element
 interface](#ref-for-dfn-implicit-pointer-capture-2 "§ 4. Extensions to the Element interface")
- [§ 8.2 Setting pointer
 capture](#ref-for-dfn-implicit-pointer-capture-3 "§ 8.2 Setting pointer capture")

[Permalink](#dfn-implicitly-release-the-pointer-capture)

**Referenced in:**

- [§ 3.1.3.2 Process pending pointer
 capture](#ref-for-dfn-implicitly-release-the-pointer-capture-1 "§ 3.1.3.2 Process pending pointer capture")
- [§ 3.1.3.3 Suppressing a pointer event
 stream](#ref-for-dfn-implicitly-release-the-pointer-capture-2 "§ 3.1.3.3 Suppressing a pointer event stream")
- [§ 3.3.6
 pointerup](#ref-for-dfn-implicitly-release-the-pointer-capture-3 "§ 3.3.6 pointerup")
- [§ 3.3.11
 lostpointercapture](#ref-for-dfn-implicitly-release-the-pointer-capture-4 "§ 3.3.11 lostpointercapture")
- [§ 8.3 Releasing pointer
 capture](#ref-for-dfn-implicitly-release-the-pointer-capture-5 "§ 8.3 Releasing pointer capture")

[Permalink](#dfn-coalesced-events)

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dfn-coalesced-events-1 "§ 3.1 PointerEvent interface")
- [§ 3.3.4
 pointermove](#ref-for-dfn-coalesced-events-2 "§ 3.3.4 pointermove")
- [§ 3.3.5
 pointerrawupdate](#ref-for-dfn-coalesced-events-3 "§ 3.3.5 pointerrawupdate")

[Permalink](#dfn-coalesced-events-list)

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dfn-coalesced-events-list-1 "§ 3.1 PointerEvent interface")
- [§ 9.1 Coalesced
 events](#ref-for-dfn-coalesced-events-list-2 "§ 9.1 Coalesced events")
 [(2)](#ref-for-dfn-coalesced-events-list-3 "Reference 2")
 [(3)](#ref-for-dfn-coalesced-events-list-4 "Reference 3")
 [(4)](#ref-for-dfn-coalesced-events-list-5 "Reference 4")
- [§ 9.2 Predicted
 events](#ref-for-dfn-coalesced-events-list-6 "§ 9.2 Predicted events")
 [(2)](#ref-for-dfn-coalesced-events-list-7 "Reference 2")
- [§ 9.3 Populating and maintaining the coalesced and predicted events
 lists](#ref-for-dfn-coalesced-events-list-8 "§ 9.3 Populating and maintaining the coalesced and predicted events lists")
 [(2)](#ref-for-dfn-coalesced-events-list-9 "Reference 2")
 [(3)](#ref-for-dfn-coalesced-events-list-10 "Reference 3")

[Permalink](#dfn-predicted-events)

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dfn-predicted-events-1 "§ 3.1 PointerEvent interface")

[Permalink](#dfn-predicted-events-list)

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dfn-predicted-events-list-1 "§ 3.1 PointerEvent interface")
- [§ 9.1 Coalesced
 events](#ref-for-dfn-predicted-events-list-2 "§ 9.1 Coalesced events")
- [§ 9.2 Predicted
 events](#ref-for-dfn-predicted-events-list-3 "§ 9.2 Predicted events")
 [(2)](#ref-for-dfn-predicted-events-list-4 "Reference 2")
 [(3)](#ref-for-dfn-predicted-events-list-5 "Reference 3")
 [(4)](#ref-for-dfn-predicted-events-list-6 "Reference 4")
 [(5)](#ref-for-dfn-predicted-events-list-7 "Reference 5")
- [§ 9.3 Populating and maintaining the coalesced and predicted events
 lists](#ref-for-dfn-predicted-events-list-8 "§ 9.3 Populating and maintaining the coalesced and predicted events lists")
 [(2)](#ref-for-dfn-predicted-events-list-9 "Reference 2")
 [(3)](#ref-for-dfn-predicted-events-list-10 "Reference 3")

[Permalink](#dfn-compatibility-mouse-events)

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dfn-compatibility-mouse-events-1 "§ 1. Introduction")
- [§ 3.1.1.1 Chorded button
 interactions](#ref-for-dfn-compatibility-mouse-events-2 "§ 3.1.1.1 Chorded button interactions")
- [§ 3.1.2 The primary
 pointer](#ref-for-dfn-compatibility-mouse-events-3 "§ 3.1.2 The primary pointer")
 [(2)](#ref-for-dfn-compatibility-mouse-events-4 "Reference 2")
- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-compatibility-mouse-events-5 "§ 3.1.3.1 Attributes and default actions")
- [§ 3.3 Pointer Event
 types](#ref-for-dfn-compatibility-mouse-events-6 "§ 3.3 Pointer Event types")
- [§ 3.3.3
 pointerdown](#ref-for-dfn-compatibility-mouse-events-7 "§ 3.3.3 pointerdown")
- [§ 3.3.5
 pointerrawupdate](#ref-for-dfn-compatibility-mouse-events-8 "§ 3.3.5 pointerrawupdate")
- [§ 8.1
 Introduction](#ref-for-dfn-compatibility-mouse-events-9 "§ 8.1 Introduction")
- [§ 10. Compatibility mapping with mouse
 events](#ref-for-dfn-compatibility-mouse-events-10 "§ 10. Compatibility mapping with mouse events")

[Permalink](#dfn-tracking-the-effective-position-of-the-legacy-mouse-pointer)

**Referenced in:**

- [§ 10.2 Mapping for devices that support
 hover](#ref-for-dfn-tracking-the-effective-position-of-the-legacy-mouse-pointer-1 "§ 10.2 Mapping for devices that support hover")
- [§ 10.3 Mapping for devices that do not support
 hover](#ref-for-dfn-tracking-the-effective-position-of-the-legacy-mouse-pointer-2 "§ 10.3 Mapping for devices that do not support hover")

[Permalink](#dfn-effective-legacy-mouse-pointer-position)

**Referenced in:**

- [§ 10.1 Tracking the effective position of the legacy mouse
 pointer](#ref-for-dfn-effective-legacy-mouse-pointer-position-1 "§ 10.1 Tracking the effective position of the legacy mouse pointer")
 [(2)](#ref-for-dfn-effective-legacy-mouse-pointer-position-2 "Reference 2")
 [(3)](#ref-for-dfn-effective-legacy-mouse-pointer-position-3 "Reference 3")
 [(4)](#ref-for-dfn-effective-legacy-mouse-pointer-position-4 "Reference 4")
 [(5)](#ref-for-dfn-effective-legacy-mouse-pointer-position-5 "Reference 5")
 [(6)](#ref-for-dfn-effective-legacy-mouse-pointer-position-6 "Reference 6")
 [(7)](#ref-for-dfn-effective-legacy-mouse-pointer-position-7 "Reference 7")

[Permalink](#dom-mouseeventinit)
[exported]

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-mouseeventinit-1 "§ 3.1 PointerEvent interface")
 [(2)](#ref-for-dom-mouseeventinit-2 "Reference 2")
- [§ 11. Mouse Events and
 Interfaces](#ref-for-dom-mouseeventinit-3 "§ 11. Mouse Events and Interfaces")
- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseeventinit-4 "§ 11.1 MouseEvent interface")
- [§ 12.1 WheelEvent
 interface](#ref-for-dom-mouseeventinit-5 "§ 12.1 WheelEvent interface")
- [§ C. IDL Index](#ref-for-dom-mouseeventinit-6 "§ C. IDL Index")
 [(2)](#ref-for-dom-mouseeventinit-7 "Reference 2")
 [(3)](#ref-for-dom-mouseeventinit-8 "Reference 3")

[Permalink](#dom-mouseeventinit-screenx)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mouseeventinit-screeny)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mouseeventinit-clientx)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mouseeventinit-clienty)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mouseeventinit-button)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mouseeventinit-buttons)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mouseeventinit-relatedtarget)
[exported]

**Referenced in:**

- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dom-mouseeventinit-relatedtarget-1 "§ 3.1.3.1 Attributes and default actions")

[Permalink](#dom-mouseevent)
[exported]
[IDL](#webidl-651575932 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dom-mouseevent-1 "§ 3.1 PointerEvent interface")
 [(2)](#ref-for-dom-mouseevent-2 "Reference 2")
 [(3)](#ref-for-dom-mouseevent-3 "Reference 3")
- [§ 3.1.1.1 Chorded button
 interactions](#ref-for-dom-mouseevent-4 "§ 3.1.1.1 Chorded button interactions")
- [§ 3.2.3 create PointerEvent from
 MouseEvent](#ref-for-dom-mouseevent-5 "§ 3.2.3 create PointerEvent from MouseEvent")
 [(2)](#ref-for-dom-mouseevent-6 "Reference 2")
- [§ 3.3.1 pointerover](#ref-for-dom-mouseevent-7 "§ 3.3.1 pointerover")
- [§ 3.3.2
 pointerenter](#ref-for-dom-mouseevent-8 "§ 3.3.2 pointerenter")
- [§ 3.3.8 pointerout](#ref-for-dom-mouseevent-9 "§ 3.3.8 pointerout")
- [§ 3.3.9
 pointerleave](#ref-for-dom-mouseevent-10 "§ 3.3.9 pointerleave")
- [§ 3.3.12 click, auxclick, and
 contextmenu](#ref-for-dom-mouseevent-11 "§ 3.3.12 click, auxclick, and contextmenu")
- [§ 3.3.12.2 Event
 coordinates](#ref-for-dom-mouseevent-12 "§ 3.3.12.2 Event coordinates")
- [§ 11. Mouse Events and
 Interfaces](#ref-for-dom-mouseevent-13 "§ 11. Mouse Events and Interfaces")
 [(2)](#ref-for-dom-mouseevent-14 "Reference 2")
 [(3)](#ref-for-dom-mouseevent-15 "Reference 3")
 [(4)](#ref-for-dom-mouseevent-16 "Reference 4")
- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-17 "§ 11.1 MouseEvent interface")
- [§ 11.2.2 Constructing Mouse
 Events](#ref-for-dom-mouseevent-18 "§ 11.2.2 Constructing Mouse Events")
 [(2)](#ref-for-dom-mouseevent-19 "Reference 2")
 [(3)](#ref-for-dom-mouseevent-20 "Reference 3")
 [(4)](#ref-for-dom-mouseevent-21 "Reference 4")
 [(5)](#ref-for-dom-mouseevent-22 "Reference 5")
- [§ 11.2.4 Internal State for
 MouseEvent](#ref-for-dom-mouseevent-23 "§ 11.2.4 Internal State for MouseEvent")
- [§ 11.2.6 initialize a
 MouseEvent](#ref-for-dom-mouseevent-24 "§ 11.2.6 initialize a MouseEvent")
- [§ 11.2.7 set mouse event
 modifiers](#ref-for-dom-mouseevent-25 "§ 11.2.7 set mouse event modifiers")
- [§ 11.2.8 create a cancelable
 MouseEvent](#ref-for-dom-mouseevent-26 "§ 11.2.8 create a cancelable MouseEvent")
 [(2)](#ref-for-dom-mouseevent-27 "Reference 2")
- [§ 11.2.9 create a non-cancelable
 MouseEvent](#ref-for-dom-mouseevent-28 "§ 11.2.9 create a non-cancelable MouseEvent")
 [(2)](#ref-for-dom-mouseevent-29 "Reference 2")
- [§ 11.2.10 calculate MouseEvent button
 attribute](#ref-for-dom-mouseevent-30 "§ 11.2.10 calculate MouseEvent button attribute")
- [§ 11.2.11 set MouseEvent attributes from
 native](#ref-for-dom-mouseevent-31 "§ 11.2.11 set MouseEvent attributes from native")
- [§ 11.4.4 dblclick](#ref-for-dom-mouseevent-32 "§ 11.4.4 dblclick")
- [§ 11.4.5 mousedown](#ref-for-dom-mouseevent-33 "§ 11.4.5 mousedown")
- [§ 11.4.6
 mouseenter](#ref-for-dom-mouseevent-34 "§ 11.4.6 mouseenter")
 [(2)](#ref-for-dom-mouseevent-35 "Reference 2")
- [§ 11.4.7
 mouseleave](#ref-for-dom-mouseevent-36 "§ 11.4.7 mouseleave")
 [(2)](#ref-for-dom-mouseevent-37 "Reference 2")
- [§ 11.4.8 mousemove](#ref-for-dom-mouseevent-38 "§ 11.4.8 mousemove")
- [§ 11.4.9 mouseout](#ref-for-dom-mouseevent-39 "§ 11.4.9 mouseout")
 [(2)](#ref-for-dom-mouseevent-40 "Reference 2")
- [§ 11.4.10
 mouseover](#ref-for-dom-mouseevent-41 "§ 11.4.10 mouseover")
 [(2)](#ref-for-dom-mouseevent-42 "Reference 2")
- [§ 11.4.11 mouseup](#ref-for-dom-mouseevent-43 "§ 11.4.11 mouseup")
- [§ 12.1 WheelEvent
 interface](#ref-for-dom-mouseevent-44 "§ 12.1 WheelEvent interface")
- [§ 12.3 wheel](#ref-for-dom-mouseevent-45 "§ 12.3 wheel")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-46 "§ 16.1 Initializers for interface MouseEvent")
 [(2)](#ref-for-dom-mouseevent-47 "Reference 2")
- [§ C. IDL Index](#ref-for-dom-mouseevent-48 "§ C. IDL Index")
 [(2)](#ref-for-dom-mouseevent-49 "Reference 2")
 [(3)](#ref-for-dom-mouseevent-50 "Reference 3")

[Permalink](#dom-mouseevent-constructor)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mouseevent-screenx)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-screenx-1 "§ 11.1 MouseEvent interface")
- [§ 11.2.6 initialize a
 MouseEvent](#ref-for-dom-mouseevent-screenx-2 "§ 11.2.6 initialize a MouseEvent")
- [§ 11.2.15 send click
 event](#ref-for-dom-mouseevent-screenx-3 "§ 11.2.15 send click event")
- [§ 11.2.16 handle native mouse double
 click](#ref-for-dom-mouseevent-screenx-4 "§ 11.2.16 handle native mouse double click")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-screenx-5 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL Index](#ref-for-dom-mouseevent-screenx-6 "§ C. IDL Index")

[Permalink](#dom-mouseevent-screeny)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-screeny-1 "§ 11.1 MouseEvent interface")
- [§ 11.2.6 initialize a
 MouseEvent](#ref-for-dom-mouseevent-screeny-2 "§ 11.2.6 initialize a MouseEvent")
- [§ 11.2.15 send click
 event](#ref-for-dom-mouseevent-screeny-3 "§ 11.2.15 send click event")
- [§ 11.2.16 handle native mouse double
 click](#ref-for-dom-mouseevent-screeny-4 "§ 11.2.16 handle native mouse double click")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-screeny-5 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL Index](#ref-for-dom-mouseevent-screeny-6 "§ C. IDL Index")

[Permalink](#dom-mouseevent-clientx)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11. Mouse Events and
 Interfaces](#ref-for-dom-mouseevent-clientx-1 "§ 11. Mouse Events and Interfaces")
- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-clientx-2 "§ 11.1 MouseEvent interface")
- [§ 11.2.6 initialize a
 MouseEvent](#ref-for-dom-mouseevent-clientx-3 "§ 11.2.6 initialize a MouseEvent")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-clientx-4 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL Index](#ref-for-dom-mouseevent-clientx-5 "§ C. IDL Index")

[Permalink](#dom-mouseevent-clienty)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11. Mouse Events and
 Interfaces](#ref-for-dom-mouseevent-clienty-1 "§ 11. Mouse Events and Interfaces")
- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-clienty-2 "§ 11.1 MouseEvent interface")
- [§ 11.2.6 initialize a
 MouseEvent](#ref-for-dom-mouseevent-clienty-3 "§ 11.2.6 initialize a MouseEvent")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-clienty-4 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL Index](#ref-for-dom-mouseevent-clienty-5 "§ C. IDL Index")

[Permalink](#dom-mouseevent-layerx)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-layerx-1 "§ 11.1 MouseEvent interface")
- [§ C. IDL Index](#ref-for-dom-mouseevent-layerx-2 "§ C. IDL Index")

[Permalink](#dom-mouseevent-layery)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-layery-1 "§ 11.1 MouseEvent interface")
- [§ C. IDL Index](#ref-for-dom-mouseevent-layery-2 "§ C. IDL Index")

[Permalink](#dom-mouseevent-ctrlkey)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-ctrlkey-1 "§ 11.1 MouseEvent interface")
- [§ 11.2.7 set mouse event
 modifiers](#ref-for-dom-mouseevent-ctrlkey-2 "§ 11.2.7 set mouse event modifiers")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-ctrlkey-3 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL Index](#ref-for-dom-mouseevent-ctrlkey-4 "§ C. IDL Index")

[Permalink](#dom-mouseevent-shiftkey)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-shiftkey-1 "§ 11.1 MouseEvent interface")
- [§ 11.2.7 set mouse event
 modifiers](#ref-for-dom-mouseevent-shiftkey-2 "§ 11.2.7 set mouse event modifiers")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-shiftkey-3 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL Index](#ref-for-dom-mouseevent-shiftkey-4 "§ C. IDL Index")

[Permalink](#dom-mouseevent-altkey)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-altkey-1 "§ 11.1 MouseEvent interface")
- [§ 11.2.7 set mouse event
 modifiers](#ref-for-dom-mouseevent-altkey-2 "§ 11.2.7 set mouse event modifiers")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-altkey-3 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL Index](#ref-for-dom-mouseevent-altkey-4 "§ C. IDL Index")

[Permalink](#dom-mouseevent-metakey)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-metakey-1 "§ 11.1 MouseEvent interface")
- [§ 11.2.7 set mouse event
 modifiers](#ref-for-dom-mouseevent-metakey-2 "§ 11.2.7 set mouse event modifiers")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-metakey-3 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL Index](#ref-for-dom-mouseevent-metakey-4 "§ C. IDL Index")

[Permalink](#dom-mouseevent-button)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-button-1 "§ 11.1 MouseEvent interface")
 [(2)](#ref-for-dom-mouseevent-button-2 "Reference 2")
 [(3)](#ref-for-dom-mouseevent-button-3 "Reference 3")
 [(4)](#ref-for-dom-mouseevent-button-4 "Reference 4")
 [(5)](#ref-for-dom-mouseevent-button-5 "Reference 5")
 [(6)](#ref-for-dom-mouseevent-button-6 "Reference 6")
- [§ 11.2.6 initialize a
 MouseEvent](#ref-for-dom-mouseevent-button-7 "§ 11.2.6 initialize a MouseEvent")
- [§ 11.2.10 calculate MouseEvent button
 attribute](#ref-for-dom-mouseevent-button-8 "§ 11.2.10 calculate MouseEvent button attribute")
- [§ 11.2.11 set MouseEvent attributes from
 native](#ref-for-dom-mouseevent-button-9 "§ 11.2.11 set MouseEvent attributes from native")
- [§ 11.4.1
 auxclick](#ref-for-dom-mouseevent-button-10 "§ 11.4.1 auxclick")
 [(2)](#ref-for-dom-mouseevent-button-11 "Reference 2")
- [§ 11.4.2 click](#ref-for-dom-mouseevent-button-12 "§ 11.4.2 click")
 [(2)](#ref-for-dom-mouseevent-button-13 "Reference 2")
- [§ 11.4.4
 dblclick](#ref-for-dom-mouseevent-button-14 "§ 11.4.4 dblclick")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-button-15 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL Index](#ref-for-dom-mouseevent-button-16 "§ C. IDL Index")

[Permalink](#dom-mouseevent-buttons)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-buttons-1 "§ 11.1 MouseEvent interface")
 [(2)](#ref-for-dom-mouseevent-buttons-2 "Reference 2")
 [(3)](#ref-for-dom-mouseevent-buttons-3 "Reference 3")
 [(4)](#ref-for-dom-mouseevent-buttons-4 "Reference 4")
 [(5)](#ref-for-dom-mouseevent-buttons-5 "Reference 5")
 [(6)](#ref-for-dom-mouseevent-buttons-6 "Reference 6")
- [§ 11.2.6 initialize a
 MouseEvent](#ref-for-dom-mouseevent-buttons-7 "§ 11.2.6 initialize a MouseEvent")
- [§ 11.4.1
 auxclick](#ref-for-dom-mouseevent-buttons-8 "§ 11.4.1 auxclick")
 [(2)](#ref-for-dom-mouseevent-buttons-9 "Reference 2")
- [§ 11.4.2 click](#ref-for-dom-mouseevent-buttons-10 "§ 11.4.2 click")
 [(2)](#ref-for-dom-mouseevent-buttons-11 "Reference 2")
- [§ 11.4.4
 dblclick](#ref-for-dom-mouseevent-buttons-12 "§ 11.4.4 dblclick")
- [§ C. IDL Index](#ref-for-dom-mouseevent-buttons-13 "§ C. IDL Index")

[Permalink](#dom-mouseevent-relatedtarget)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.3.1
 pointerover](#ref-for-dom-mouseevent-relatedtarget-1 "§ 3.3.1 pointerover")
- [§ 3.3.2
 pointerenter](#ref-for-dom-mouseevent-relatedtarget-2 "§ 3.3.2 pointerenter")
- [§ 3.3.8
 pointerout](#ref-for-dom-mouseevent-relatedtarget-3 "§ 3.3.8 pointerout")
- [§ 3.3.9
 pointerleave](#ref-for-dom-mouseevent-relatedtarget-4 "§ 3.3.9 pointerleave")
- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-relatedtarget-5 "§ 11.1 MouseEvent interface")
 [(2)](#ref-for-dom-mouseevent-relatedtarget-6 "Reference 2")
- [§ 11.4.6
 mouseenter](#ref-for-dom-mouseevent-relatedtarget-7 "§ 11.4.6 mouseenter")
- [§ 11.4.7
 mouseleave](#ref-for-dom-mouseevent-relatedtarget-8 "§ 11.4.7 mouseleave")
- [§ 11.4.9
 mouseout](#ref-for-dom-mouseevent-relatedtarget-9 "§ 11.4.9 mouseout")
- [§ 11.4.10
 mouseover](#ref-for-dom-mouseevent-relatedtarget-10 "§ 11.4.10 mouseover")
- [§ 12.3
 wheel](#ref-for-dom-mouseevent-relatedtarget-11 "§ 12.3 wheel")
- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-relatedtarget-12 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL
 Index](#ref-for-dom-mouseevent-relatedtarget-13 "§ C. IDL Index")

[Permalink](#dom-mouseevent-getmodifierstate)
[exported]
[IDL](#webidl-553761302 "Jump to IDL declaration")

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dom-mouseevent-getmodifierstate-1 "§ 11.1 MouseEvent interface")
- [§ 11.2.2 Constructing Mouse
 Events](#ref-for-dom-mouseevent-getmodifierstate-2 "§ 11.2.2 Constructing Mouse Events")
- [§ C. IDL
 Index](#ref-for-dom-mouseevent-getmodifierstate-3 "§ C. IDL Index")

[Permalink](#dfn-current-click-count)

**Referenced in:**

- [§ 11.4.1
 auxclick](#ref-for-dfn-current-click-count-1 "§ 11.4.1 auxclick")
- [§ 11.4.2 click](#ref-for-dfn-current-click-count-2 "§ 11.4.2 click")

[Permalink](#dfn-internal-key-modifier-state)

**Referenced in:**

- [§ 11.2.2 Constructing Mouse
 Events](#ref-for-dfn-internal-key-modifier-state-1 "§ 11.2.2 Constructing Mouse Events")

[Permalink](#dfn-key-modifier-name)

**Referenced in:**

- [§ 11.2.2 Constructing Mouse
 Events](#ref-for-dfn-key-modifier-name-1 "§ 11.2.2 Constructing Mouse Events")

[Permalink](#dfn-mouse-button-bitmask)

**Referenced in:**

- [§ 11.2.6 initialize a
 MouseEvent](#ref-for-dfn-mouse-button-bitmask-1 "§ 11.2.6 initialize a MouseEvent")
- [§ 11.2.12 handle native mouse
 down](#ref-for-dfn-mouse-button-bitmask-2 "§ 11.2.12 handle native mouse down")
- [§ 11.2.13 handle native mouse
 up](#ref-for-dfn-mouse-button-bitmask-3 "§ 11.2.13 handle native mouse up")

[Permalink](#dfn-last-mouse-element)

**Referenced in:**

- [§ 11.2.3.2 Window-Level
 State](#ref-for-dfn-last-mouse-element-1 "§ 11.2.3.2 Window-Level State")
- [§ 11.2.17 handle native mouse
 move](#ref-for-dfn-last-mouse-element-2 "§ 11.2.17 handle native mouse move")
 [(2)](#ref-for-dfn-last-mouse-element-3 "Reference 2")
 [(3)](#ref-for-dfn-last-mouse-element-4 "Reference 3")
 [(4)](#ref-for-dfn-last-mouse-element-5 "Reference 4")

[Permalink](#dfn-last-mouse-dom-path)

**Referenced in:**

- [§ 11.2.17 handle native mouse
 move](#ref-for-dfn-last-mouse-dom-path-1 "§ 11.2.17 handle native mouse move")
 [(2)](#ref-for-dfn-last-mouse-dom-path-2 "Reference 2")
 [(3)](#ref-for-dfn-last-mouse-dom-path-3 "Reference 3")

[Permalink](#dfn-shift-flag)

**Referenced in:**

- [§ 11.2.7 set mouse event
 modifiers](#ref-for-dfn-shift-flag-1 "§ 11.2.7 set mouse event modifiers")
 [(2)](#ref-for-dfn-shift-flag-2 "Reference 2")

[Permalink](#dfn-control-flag)

**Referenced in:**

- [§ 11.2.7 set mouse event
 modifiers](#ref-for-dfn-control-flag-1 "§ 11.2.7 set mouse event modifiers")
 [(2)](#ref-for-dfn-control-flag-2 "Reference 2")

[Permalink](#dfn-alt-flag)

**Referenced in:**

- [§ 11.2.7 set mouse event
 modifiers](#ref-for-dfn-alt-flag-1 "§ 11.2.7 set mouse event modifiers")
 [(2)](#ref-for-dfn-alt-flag-2 "Reference 2")

[Permalink](#dfn-altgraph-flag)

**Referenced in:**

- [§ 11.2.7 set mouse event
 modifiers](#ref-for-dfn-altgraph-flag-1 "§ 11.2.7 set mouse event modifiers")
 [(2)](#ref-for-dfn-altgraph-flag-2 "Reference 2")

[Permalink](#dfn-meta-flag)

**Referenced in:**

- [§ 11.2.7 set mouse event
 modifiers](#ref-for-dfn-meta-flag-1 "§ 11.2.7 set mouse event modifiers")
 [(2)](#ref-for-dfn-meta-flag-2 "Reference 2")

[Permalink](#dfn-hit-test)

**Referenced in:**

- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-hit-test-1 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 3.1.4 Boundary events caused by layout
 changes](#ref-for-dfn-hit-test-2 "§ 3.1.4 Boundary events caused by layout changes")
- [§ 3.3.1 pointerover](#ref-for-dfn-hit-test-3 "§ 3.3.1 pointerover")
- [§ 3.3.2 pointerenter](#ref-for-dfn-hit-test-4 "§ 3.3.2 pointerenter")
 [(2)](#ref-for-dfn-hit-test-5 "Reference 2")
- [§ 3.3.8 pointerout](#ref-for-dfn-hit-test-6 "§ 3.3.8 pointerout")
- [§ 3.3.9 pointerleave](#ref-for-dfn-hit-test-7 "§ 3.3.9 pointerleave")
 [(2)](#ref-for-dfn-hit-test-8 "Reference 2")
- [§ 8.1 Introduction](#ref-for-dfn-hit-test-9 "§ 8.1 Introduction")
- [§ 11.2.12 handle native mouse
 down](#ref-for-dfn-hit-test-10 "§ 11.2.12 handle native mouse down")
- [§ 11.2.13 handle native mouse
 up](#ref-for-dfn-hit-test-11 "§ 11.2.13 handle native mouse up")
- [§ 11.2.14 handle native mouse
 click](#ref-for-dfn-hit-test-12 "§ 11.2.14 handle native mouse click")
- [§ 11.2.16 handle native mouse double
 click](#ref-for-dfn-hit-test-13 "§ 11.2.16 handle native mouse double click")
- [§ 11.2.17 handle native mouse
 move](#ref-for-dfn-hit-test-14 "§ 11.2.17 handle native mouse move")

[Permalink](#dfn-initialize-a-mouseevent)
[exported]

**Referenced in:**

- [§ 3.2.1 initialize a
 PointerEvent](#ref-for-dfn-initialize-a-mouseevent-1 "§ 3.2.1 initialize a PointerEvent")
- [§ 11.2.8 create a cancelable
 MouseEvent](#ref-for-dfn-initialize-a-mouseevent-2 "§ 11.2.8 create a cancelable MouseEvent")
- [§ 11.2.9 create a non-cancelable
 MouseEvent](#ref-for-dfn-initialize-a-mouseevent-3 "§ 11.2.9 create a non-cancelable MouseEvent")

[Permalink](#dfn-set-mouse-event-modifiers)

**Referenced in:**

- [§ 11.2.6 initialize a
 MouseEvent](#ref-for-dfn-set-mouse-event-modifiers-1 "§ 11.2.6 initialize a MouseEvent")

[Permalink](#dfn-creating-a-cancelable-mouseevent)

**Referenced in:**

- [§ 11.2.12 handle native mouse
 down](#ref-for-dfn-creating-a-cancelable-mouseevent-1 "§ 11.2.12 handle native mouse down")
- [§ 11.2.13 handle native mouse
 up](#ref-for-dfn-creating-a-cancelable-mouseevent-2 "§ 11.2.13 handle native mouse up")
- [§ 11.2.17 handle native mouse
 move](#ref-for-dfn-creating-a-cancelable-mouseevent-3 "§ 11.2.17 handle native mouse move")
 [(2)](#ref-for-dfn-creating-a-cancelable-mouseevent-4 "Reference 2")
 [(3)](#ref-for-dfn-creating-a-cancelable-mouseevent-5 "Reference 3")

[Permalink](#dfn-creating-a-non-cancelable-mouseevent)

**Referenced in:**

- [§ 11.2.17 handle native mouse
 move](#ref-for-dfn-creating-a-non-cancelable-mouseevent-1 "§ 11.2.17 handle native mouse move")
 [(2)](#ref-for-dfn-creating-a-non-cancelable-mouseevent-2 "Reference 2")

[Permalink](#dfn-calculate-mouseevent-button-attribute)

**Referenced in:**

- [§ 11.2.11 set MouseEvent attributes from
 native](#ref-for-dfn-calculate-mouseevent-button-attribute-1 "§ 11.2.11 set MouseEvent attributes from native")

[Permalink](#dfn-set-mouseevent-attributes-from-native)

**Referenced in:**

- [§ 11.2.12 handle native mouse
 down](#ref-for-dfn-set-mouseevent-attributes-from-native-1 "§ 11.2.12 handle native mouse down")
- [§ 11.2.13 handle native mouse
 up](#ref-for-dfn-set-mouseevent-attributes-from-native-2 "§ 11.2.13 handle native mouse up")
- [§ 11.2.15 send click
 event](#ref-for-dfn-set-mouseevent-attributes-from-native-3 "§ 11.2.15 send click event")
- [§ 11.2.16 handle native mouse double
 click](#ref-for-dfn-set-mouseevent-attributes-from-native-4 "§ 11.2.16 handle native mouse double click")
- [§ 11.2.18 maybe show context
 menu](#ref-for-dfn-set-mouseevent-attributes-from-native-5 "§ 11.2.18 maybe show context menu")

[Permalink](#dfn-handle-native-mouse-down)

**Referenced in:**

- [§ 11.2.1 Native OS
 Requirements](#ref-for-dfn-handle-native-mouse-down-1 "§ 11.2.1 Native OS Requirements")

[Permalink](#dfn-handle-native-mouse-up)

**Referenced in:**

- [§ 11.2.1 Native OS
 Requirements](#ref-for-dfn-handle-native-mouse-up-1 "§ 11.2.1 Native OS Requirements")
- [§ 11.2.14 handle native mouse
 click](#ref-for-dfn-handle-native-mouse-up-2 "§ 11.2.14 handle native mouse click")

[Permalink](#dfn-handle-native-mouse-click)

**Referenced in:**

- [§ 11.2.1 Native OS
 Requirements](#ref-for-dfn-handle-native-mouse-click-1 "§ 11.2.1 Native OS Requirements")

[Permalink](#dfn-send-click-event)

**Referenced in:**

- [§ 11.2.14 handle native mouse
 click](#ref-for-dfn-send-click-event-1 "§ 11.2.14 handle native mouse click")

[Permalink](#dfn-handle-native-mouse-double-click)

**Referenced in:**

- [§ 11.2.1 Native OS
 Requirements](#ref-for-dfn-handle-native-mouse-double-click-1 "§ 11.2.1 Native OS Requirements")

[Permalink](#dfn-handle-native-mouse-move)

**Referenced in:**

- [§ 11.2.1 Native OS
 Requirements](#ref-for-dfn-handle-native-mouse-move-1 "§ 11.2.1 Native OS Requirements")

[Permalink](#dfn-maybe-show-context-menu)

**Referenced in:**

- [§ 11.2.12 handle native mouse
 down](#ref-for-dfn-maybe-show-context-menu-1 "§ 11.2.12 handle native mouse down")

[Permalink](#dfn-auxclick)
[exported]

**Referenced in:**

- [§ 11.4.1 auxclick](#ref-for-dfn-auxclick-1 "§ 11.4.1 auxclick")
 [(2)](#ref-for-dfn-auxclick-2 "Reference 2")
 [(3)](#ref-for-dfn-auxclick-3 "Reference 3")
 [(4)](#ref-for-dfn-auxclick-4 "Reference 4")
 [(5)](#ref-for-dfn-auxclick-5 "Reference 5")
 [(6)](#ref-for-dfn-auxclick-6 "Reference 6")
 [(7)](#ref-for-dfn-auxclick-7 "Reference 7")
 [(8)](#ref-for-dfn-auxclick-8 "Reference 8")
- [§ 11.4.2 click](#ref-for-dfn-auxclick-9 "§ 11.4.2 click")

[Permalink](#dfn-click)
[exported]

**Referenced in:**

- [§ 11.3 Mouse Event
 Order](#ref-for-dfn-click-1 "§ 11.3 Mouse Event Order")
 [(2)](#ref-for-dfn-click-2 "Reference 2")
 [(3)](#ref-for-dfn-click-3 "Reference 3")
 [(4)](#ref-for-dfn-click-4 "Reference 4")
 [(5)](#ref-for-dfn-click-5 "Reference 5")
 [(6)](#ref-for-dfn-click-6 "Reference 6")
 [(7)](#ref-for-dfn-click-7 "Reference 7")
 [(8)](#ref-for-dfn-click-8 "Reference 8")
- [§ 11.4.1 auxclick](#ref-for-dfn-click-9 "§ 11.4.1 auxclick")
- [§ 11.4.2 click](#ref-for-dfn-click-10 "§ 11.4.2 click")
 [(2)](#ref-for-dfn-click-11 "Reference 2")
 [(3)](#ref-for-dfn-click-12 "Reference 3")
 [(4)](#ref-for-dfn-click-13 "Reference 4")
 [(5)](#ref-for-dfn-click-14 "Reference 5")
 [(6)](#ref-for-dfn-click-15 "Reference 6")
 [(7)](#ref-for-dfn-click-16 "Reference 7")
 [(8)](#ref-for-dfn-click-17 "Reference 8")
 [(9)](#ref-for-dfn-click-18 "Reference 9")
 [(10)](#ref-for-dfn-click-19 "Reference 10")
 [(11)](#ref-for-dfn-click-20 "Reference 11")
 [(12)](#ref-for-dfn-click-21 "Reference 12")
 [(13)](#ref-for-dfn-click-22 "Reference 13")
- [§ 11.4.4 dblclick](#ref-for-dfn-click-23 "§ 11.4.4 dblclick")
 [(2)](#ref-for-dfn-click-24 "Reference 2")
 [(3)](#ref-for-dfn-click-25 "Reference 3")
 [(4)](#ref-for-dfn-click-26 "Reference 4")
 [(5)](#ref-for-dfn-click-27 "Reference 5")

[Permalink](#dfn-contextmenu)
[exported]

**Referenced in:**

- [§ 11.4.1 auxclick](#ref-for-dfn-contextmenu-1 "§ 11.4.1 auxclick")
- [§ 11.4.3
 contextmenu](#ref-for-dfn-contextmenu-2 "§ 11.4.3 contextmenu")
 [(2)](#ref-for-dfn-contextmenu-3 "Reference 2")
 [(3)](#ref-for-dfn-contextmenu-4 "Reference 3")

[Permalink](#dfn-dblclick)
[exported]

**Referenced in:**

- [§ 11.3 Mouse Event
 Order](#ref-for-dfn-dblclick-1 "§ 11.3 Mouse Event Order")
 [(2)](#ref-for-dfn-dblclick-2 "Reference 2")
 [(3)](#ref-for-dfn-dblclick-3 "Reference 3")
 [(4)](#ref-for-dfn-dblclick-4 "Reference 4")
 [(5)](#ref-for-dfn-dblclick-5 "Reference 5")
- [§ 11.4.2 click](#ref-for-dfn-dblclick-6 "§ 11.4.2 click")
- [§ 11.4.4 dblclick](#ref-for-dfn-dblclick-7 "§ 11.4.4 dblclick")
 [(2)](#ref-for-dfn-dblclick-8 "Reference 2")
 [(3)](#ref-for-dfn-dblclick-9 "Reference 3")
 [(4)](#ref-for-dfn-dblclick-10 "Reference 4")
 [(5)](#ref-for-dfn-dblclick-11 "Reference 5")
 [(6)](#ref-for-dfn-dblclick-12 "Reference 6")

[Permalink](#dfn-mousedown)
[exported]

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dfn-mousedown-1 "§ 11.1 MouseEvent interface")
 [(2)](#ref-for-dfn-mousedown-2 "Reference 2")
 [(3)](#ref-for-dfn-mousedown-3 "Reference 3")
- [§ 11.3 Mouse Event
 Order](#ref-for-dfn-mousedown-4 "§ 11.3 Mouse Event Order")
 [(2)](#ref-for-dfn-mousedown-5 "Reference 2")
 [(3)](#ref-for-dfn-mousedown-6 "Reference 3")
 [(4)](#ref-for-dfn-mousedown-7 "Reference 4")
 [(5)](#ref-for-dfn-mousedown-8 "Reference 5")
 [(6)](#ref-for-dfn-mousedown-9 "Reference 6")
 [(7)](#ref-for-dfn-mousedown-10 "Reference 7")
- [§ 11.4.1 auxclick](#ref-for-dfn-mousedown-11 "§ 11.4.1 auxclick")
- [§ 11.4.2 click](#ref-for-dfn-mousedown-12 "§ 11.4.2 click")
 [(2)](#ref-for-dfn-mousedown-13 "Reference 2")
- [§ 11.4.3
 contextmenu](#ref-for-dfn-mousedown-14 "§ 11.4.3 contextmenu")
- [§ 11.4.4 dblclick](#ref-for-dfn-mousedown-15 "§ 11.4.4 dblclick")
- [§ 11.4.5 mousedown](#ref-for-dfn-mousedown-16 "§ 11.4.5 mousedown")
 [(2)](#ref-for-dfn-mousedown-17 "Reference 2")
 [(3)](#ref-for-dfn-mousedown-18 "Reference 3")

[Permalink](#dfn-mouseenter)
[exported]

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dfn-mouseenter-1 "§ 11.1 MouseEvent interface")
- [§ 11.3 Mouse Event
 Order](#ref-for-dfn-mouseenter-2 "§ 11.3 Mouse Event Order")
 [(2)](#ref-for-dfn-mouseenter-3 "Reference 2")
 [(3)](#ref-for-dfn-mouseenter-4 "Reference 3")
 [(4)](#ref-for-dfn-mouseenter-5 "Reference 4")
 [(5)](#ref-for-dfn-mouseenter-6 "Reference 5")
 [(6)](#ref-for-dfn-mouseenter-7 "Reference 6")
 [(7)](#ref-for-dfn-mouseenter-8 "Reference 7")
- [§ 11.4.7 mouseleave](#ref-for-dfn-mouseenter-9 "§ 11.4.7 mouseleave")
- [§ 11.4.10
 mouseover](#ref-for-dfn-mouseenter-10 "§ 11.4.10 mouseover")

[Permalink](#dfn-mouseleave)
[exported]

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dfn-mouseleave-1 "§ 11.1 MouseEvent interface")
- [§ 11.3 Mouse Event
 Order](#ref-for-dfn-mouseleave-2 "§ 11.3 Mouse Event Order")
 [(2)](#ref-for-dfn-mouseleave-3 "Reference 2")
 [(3)](#ref-for-dfn-mouseleave-4 "Reference 3")
 [(4)](#ref-for-dfn-mouseleave-5 "Reference 4")
 [(5)](#ref-for-dfn-mouseleave-6 "Reference 5")
 [(6)](#ref-for-dfn-mouseleave-7 "Reference 6")
 [(7)](#ref-for-dfn-mouseleave-8 "Reference 7")
 [(8)](#ref-for-dfn-mouseleave-9 "Reference 8")
- [§ 11.4.6
 mouseenter](#ref-for-dfn-mouseleave-10 "§ 11.4.6 mouseenter")
- [§ 11.4.9 mouseout](#ref-for-dfn-mouseleave-11 "§ 11.4.9 mouseout")

[Permalink](#dfn-mousemove)
[exported]

**Referenced in:**

- [§ 11.3 Mouse Event
 Order](#ref-for-dfn-mousemove-1 "§ 11.3 Mouse Event Order")
 [(2)](#ref-for-dfn-mousemove-2 "Reference 2")
 [(3)](#ref-for-dfn-mousemove-3 "Reference 3")
 [(4)](#ref-for-dfn-mousemove-4 "Reference 4")
 [(5)](#ref-for-dfn-mousemove-5 "Reference 5")
 [(6)](#ref-for-dfn-mousemove-6 "Reference 6")
 [(7)](#ref-for-dfn-mousemove-7 "Reference 7")
 [(8)](#ref-for-dfn-mousemove-8 "Reference 8")
 [(9)](#ref-for-dfn-mousemove-9 "Reference 9")
 [(10)](#ref-for-dfn-mousemove-10 "Reference 10")
 [(11)](#ref-for-dfn-mousemove-11 "Reference 11")
 [(12)](#ref-for-dfn-mousemove-12 "Reference 12")
 [(13)](#ref-for-dfn-mousemove-13 "Reference 13")
 [(14)](#ref-for-dfn-mousemove-14 "Reference 14")
 [(15)](#ref-for-dfn-mousemove-15 "Reference 15")
 [(16)](#ref-for-dfn-mousemove-16 "Reference 16")
 [(17)](#ref-for-dfn-mousemove-17 "Reference 17")
- [§ 11.4.1 auxclick](#ref-for-dfn-mousemove-18 "§ 11.4.1 auxclick")
- [§ 11.4.2 click](#ref-for-dfn-mousemove-19 "§ 11.4.2 click")
- [§ 11.4.8 mousemove](#ref-for-dfn-mousemove-20 "§ 11.4.8 mousemove")
 [(2)](#ref-for-dfn-mousemove-21 "Reference 2")

[Permalink](#dfn-mouseout)
[exported]

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dfn-mouseout-1 "§ 11.1 MouseEvent interface")
- [§ 11.3 Mouse Event
 Order](#ref-for-dfn-mouseout-2 "§ 11.3 Mouse Event Order")
 [(2)](#ref-for-dfn-mouseout-3 "Reference 2")
 [(3)](#ref-for-dfn-mouseout-4 "Reference 3")
 [(4)](#ref-for-dfn-mouseout-5 "Reference 4")
 [(5)](#ref-for-dfn-mouseout-6 "Reference 5")
 [(6)](#ref-for-dfn-mouseout-7 "Reference 6")
 [(7)](#ref-for-dfn-mouseout-8 "Reference 7")
- [§ 11.4.1 auxclick](#ref-for-dfn-mouseout-9 "§ 11.4.1 auxclick")
- [§ 11.4.2 click](#ref-for-dfn-mouseout-10 "§ 11.4.2 click")
- [§ 11.4.7 mouseleave](#ref-for-dfn-mouseout-11 "§ 11.4.7 mouseleave")
- [§ 11.4.10 mouseover](#ref-for-dfn-mouseout-12 "§ 11.4.10 mouseover")

[Permalink](#dfn-mouseover)
[exported]

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dfn-mouseover-1 "§ 11.1 MouseEvent interface")
- [§ 11.3 Mouse Event
 Order](#ref-for-dfn-mouseover-2 "§ 11.3 Mouse Event Order")
 [(2)](#ref-for-dfn-mouseover-3 "Reference 2")
 [(3)](#ref-for-dfn-mouseover-4 "Reference 3")
 [(4)](#ref-for-dfn-mouseover-5 "Reference 4")
 [(5)](#ref-for-dfn-mouseover-6 "Reference 5")
 [(6)](#ref-for-dfn-mouseover-7 "Reference 6")
- [§ 11.4.1 auxclick](#ref-for-dfn-mouseover-8 "§ 11.4.1 auxclick")
- [§ 11.4.2 click](#ref-for-dfn-mouseover-9 "§ 11.4.2 click")
- [§ 11.4.6 mouseenter](#ref-for-dfn-mouseover-10 "§ 11.4.6 mouseenter")
- [§ 11.4.9 mouseout](#ref-for-dfn-mouseover-11 "§ 11.4.9 mouseout")

[Permalink](#dfn-mouseup)
[exported]

**Referenced in:**

- [§ 11.1 MouseEvent
 interface](#ref-for-dfn-mouseup-1 "§ 11.1 MouseEvent interface")
 [(2)](#ref-for-dfn-mouseup-2 "Reference 2")
 [(3)](#ref-for-dfn-mouseup-3 "Reference 3")
- [§ 11.3 Mouse Event
 Order](#ref-for-dfn-mouseup-4 "§ 11.3 Mouse Event Order")
 [(2)](#ref-for-dfn-mouseup-5 "Reference 2")
 [(3)](#ref-for-dfn-mouseup-6 "Reference 3")
 [(4)](#ref-for-dfn-mouseup-7 "Reference 4")
 [(5)](#ref-for-dfn-mouseup-8 "Reference 5")
 [(6)](#ref-for-dfn-mouseup-9 "Reference 6")
 [(7)](#ref-for-dfn-mouseup-10 "Reference 7")
 [(8)](#ref-for-dfn-mouseup-11 "Reference 8")
 [(9)](#ref-for-dfn-mouseup-12 "Reference 9")
- [§ 11.4.1 auxclick](#ref-for-dfn-mouseup-13 "§ 11.4.1 auxclick")
- [§ 11.4.2 click](#ref-for-dfn-mouseup-14 "§ 11.4.2 click")
 [(2)](#ref-for-dfn-mouseup-15 "Reference 2")
- [§ 11.4.3 contextmenu](#ref-for-dfn-mouseup-16 "§ 11.4.3 contextmenu")
- [§ 11.4.4 dblclick](#ref-for-dfn-mouseup-17 "§ 11.4.4 dblclick")
 [(2)](#ref-for-dfn-mouseup-18 "Reference 2")
- [§ 11.4.11 mouseup](#ref-for-dfn-mouseup-19 "§ 11.4.11 mouseup")

[Permalink](#dfn-wheel-event-transaction)

**Referenced in:**

- [§ 12. Wheel Events and
 interfaces](#ref-for-dfn-wheel-event-transaction-1 "§ 12. Wheel Events and interfaces")
 [(2)](#ref-for-dfn-wheel-event-transaction-2 "Reference 2")
- [§ 12.3 wheel](#ref-for-dfn-wheel-event-transaction-3 "§ 12.3 wheel")

[Permalink](#dom-wheeleventinit)
[exported]

**Referenced in:**

- [§ 12.1 WheelEvent
 interface](#ref-for-dom-wheeleventinit-1 "§ 12.1 WheelEvent interface")
 [(2)](#ref-for-dom-wheeleventinit-2 "Reference 2")
- [§ C. IDL Index](#ref-for-dom-wheeleventinit-3 "§ C. IDL Index")

[Permalink](#dom-wheeleventinit-deltax)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-wheeleventinit-deltay)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-wheeleventinit-deltaz)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-wheeleventinit-deltamode)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-wheeleventinit-momentum)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-wheelevent)
[exported]

**Referenced in:**

- [§ 12. Wheel Events and
 interfaces](#ref-for-dom-wheelevent-1 "§ 12. Wheel Events and interfaces")
- [§ 12.1 WheelEvent
 interface](#ref-for-dom-wheelevent-2 "§ 12.1 WheelEvent interface")
 [(2)](#ref-for-dom-wheelevent-3 "Reference 2")
 [(3)](#ref-for-dom-wheelevent-4 "Reference 3")
 [(4)](#ref-for-dom-wheelevent-5 "Reference 4")
- [§ 12.3 wheel](#ref-for-dom-wheelevent-6 "§ 12.3 wheel")
- [§ 15. Glossary](#ref-for-dom-wheelevent-7 "§ 15. Glossary")
 [(2)](#ref-for-dom-wheelevent-8 "Reference 2")

[Permalink](#dom-wheelevent-constructor)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-wheelevent-dom_delta_pixel)
[exported]
[IDL](#webidl-143293587 "Jump to IDL declaration")

**Referenced in:**

- [§ 12.1 WheelEvent
 interface](#ref-for-dom-wheelevent-dom_delta_pixel-1 "§ 12.1 WheelEvent interface")
 [(2)](#ref-for-dom-wheelevent-dom_delta_pixel-2 "Reference 2")
- [§ C. IDL
 Index](#ref-for-dom-wheelevent-dom_delta_pixel-3 "§ C. IDL Index")

[Permalink](#dom-wheelevent-dom_delta_line)
[exported]
[IDL](#webidl-143293587 "Jump to IDL declaration")

**Referenced in:**

- [§ 12.1 WheelEvent
 interface](#ref-for-dom-wheelevent-dom_delta_line-1 "§ 12.1 WheelEvent interface")
- [§ C. IDL
 Index](#ref-for-dom-wheelevent-dom_delta_line-2 "§ C. IDL Index")

[Permalink](#dom-wheelevent-dom_delta_page)
[exported]
[IDL](#webidl-143293587 "Jump to IDL declaration")

**Referenced in:**

- [§ 12.1 WheelEvent
 interface](#ref-for-dom-wheelevent-dom_delta_page-1 "§ 12.1 WheelEvent interface")
- [§ C. IDL
 Index](#ref-for-dom-wheelevent-dom_delta_page-2 "§ C. IDL Index")

[Permalink](#dom-wheelevent-deltax)
[exported]
[IDL](#webidl-143293587 "Jump to IDL declaration")

**Referenced in:**

- [§ 12.1 WheelEvent
 interface](#ref-for-dom-wheelevent-deltax-1 "§ 12.1 WheelEvent interface")
 [(2)](#ref-for-dom-wheelevent-deltax-2 "Reference 2")
- [§ 15. Glossary](#ref-for-dom-wheelevent-deltax-3 "§ 15. Glossary")
- [§ C. IDL Index](#ref-for-dom-wheelevent-deltax-4 "§ C. IDL Index")

[Permalink](#dom-wheelevent-deltay)
[exported]
[IDL](#webidl-143293587 "Jump to IDL declaration")

**Referenced in:**

- [§ 12.1 WheelEvent
 interface](#ref-for-dom-wheelevent-deltay-1 "§ 12.1 WheelEvent interface")
 [(2)](#ref-for-dom-wheelevent-deltay-2 "Reference 2")
- [§ 15. Glossary](#ref-for-dom-wheelevent-deltay-3 "§ 15. Glossary")
- [§ C. IDL Index](#ref-for-dom-wheelevent-deltay-4 "§ C. IDL Index")

[Permalink](#dom-wheelevent-deltaz)
[exported]
[IDL](#webidl-143293587 "Jump to IDL declaration")

**Referenced in:**

- [§ 12.1 WheelEvent
 interface](#ref-for-dom-wheelevent-deltaz-1 "§ 12.1 WheelEvent interface")
 [(2)](#ref-for-dom-wheelevent-deltaz-2 "Reference 2")
- [§ 15. Glossary](#ref-for-dom-wheelevent-deltaz-3 "§ 15. Glossary")
- [§ C. IDL Index](#ref-for-dom-wheelevent-deltaz-4 "§ C. IDL Index")

[Permalink](#dom-wheelevent-deltamode)
[exported]
[IDL](#webidl-143293587 "Jump to IDL declaration")

**Referenced in:**

- [§ 12.1 WheelEvent
 interface](#ref-for-dom-wheelevent-deltamode-1 "§ 12.1 WheelEvent interface")
- [§ 15. Glossary](#ref-for-dom-wheelevent-deltamode-2 "§ 15. Glossary")
- [§ C. IDL Index](#ref-for-dom-wheelevent-deltamode-3 "§ C. IDL Index")

[Permalink](#dom-wheelevent-momentum)
[exported]
[IDL](#webidl-143293587 "Jump to IDL declaration")

**Referenced in:**

- [§ 12.1 WheelEvent
 interface](#ref-for-dom-wheelevent-momentum-1 "§ 12.1 WheelEvent interface")
- [§ C. IDL Index](#ref-for-dom-wheelevent-momentum-2 "§ C. IDL Index")

[Permalink](#dfn-wheel)
[exported]

**Referenced in:**

- [§ 12. Wheel Events and
 interfaces](#ref-for-dfn-wheel-1 "§ 12. Wheel Events and interfaces")
 [(2)](#ref-for-dfn-wheel-2 "Reference 2")
- [§ 12.1 WheelEvent
 interface](#ref-for-dfn-wheel-3 "§ 12.1 WheelEvent interface")
 [(2)](#ref-for-dfn-wheel-4 "Reference 2")
 [(3)](#ref-for-dfn-wheel-5 "Reference 3")
 [(4)](#ref-for-dfn-wheel-6 "Reference 4")
- [§ 12.3 wheel](#ref-for-dfn-wheel-7 "§ 12.3 wheel")
 [(2)](#ref-for-dfn-wheel-8 "Reference 2")
 [(3)](#ref-for-dfn-wheel-9 "Reference 3")

[Permalink](#dfn-active-buttons-state)

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dfn-active-buttons-state-1 "§ 3.1 PointerEvent interface")
- [§ 3.3.3
 pointerdown](#ref-for-dfn-active-buttons-state-2 "§ 3.3.3 pointerdown")
- [§ 3.3.6
 pointerup](#ref-for-dfn-active-buttons-state-3 "§ 3.3.6 pointerup")
- [§ 4. Extensions to the Element
 interface](#ref-for-dfn-active-buttons-state-4 "§ 4. Extensions to the Element interface")
- [§ 8.2 Setting pointer
 capture](#ref-for-dfn-active-buttons-state-5 "§ 8.2 Setting pointer capture")

[Permalink](#dfn-active-document)

**Referenced in:**

- [§ 3.1.3 Firing events using the PointerEvent
 interface](#ref-for-dfn-active-document-1 "§ 3.1.3 Firing events using the PointerEvent interface")
- [§ 8.2 Setting pointer
 capture](#ref-for-dfn-active-document-2 "§ 8.2 Setting pointer capture")

[Permalink](#dfn-active-pointer)

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dfn-active-pointer-1 "§ 3.1 PointerEvent interface")
- [§ 3.1.2 The primary
 pointer](#ref-for-dfn-active-pointer-2 "§ 3.1.2 The primary pointer")
- [§ 4. Extensions to the Element
 interface](#ref-for-dfn-active-pointer-3 "§ 4. Extensions to the Element interface")
 [(2)](#ref-for-dfn-active-pointer-4 "Reference 2")
- [§ 8.2 Setting pointer
 capture](#ref-for-dfn-active-pointer-5 "§ 8.2 Setting pointer capture")
 [(2)](#ref-for-dfn-active-pointer-6 "Reference 2")
- [§ 8.3 Releasing pointer
 capture](#ref-for-dfn-active-pointer-7 "§ 8.3 Releasing pointer capture")
- [§ 15. Glossary](#ref-for-dfn-active-pointer-8 "§ 15. Glossary")

[Permalink](#dfn-contact-geometry)

**Referenced in:**

- [§ 3.1 PointerEvent
 interface](#ref-for-dfn-contact-geometry-1 "§ 3.1 PointerEvent interface")
 [(2)](#ref-for-dfn-contact-geometry-2 "Reference 2")

[Permalink](#dfn-delta)

**Referenced in:**

- [§ 12. Wheel Events and
 interfaces](#ref-for-dfn-delta-1 "§ 12. Wheel Events and interfaces")
 [(2)](#ref-for-dfn-delta-2 "Reference 2")
 [(3)](#ref-for-dfn-delta-3 "Reference 3")
- [§ 12.1 WheelEvent
 interface](#ref-for-dfn-delta-4 "§ 12.1 WheelEvent interface")
 [(2)](#ref-for-dfn-delta-5 "Reference 2")
 [(3)](#ref-for-dfn-delta-6 "Reference 3")
 [(4)](#ref-for-dfn-delta-7 "Reference 4")
 [(5)](#ref-for-dfn-delta-8 "Reference 5")
- [§ 12.3 wheel](#ref-for-dfn-delta-9 "§ 12.3 wheel")
 [(2)](#ref-for-dfn-delta-10 "Reference 2")
 [(3)](#ref-for-dfn-delta-11 "Reference 3")
- [§ 15. Glossary](#ref-for-dfn-delta-12 "§ 15. Glossary")
 [(2)](#ref-for-dfn-delta-13 "Reference 2")
 [(3)](#ref-for-dfn-delta-14 "Reference 3")

[Permalink](#dfn-digitizer)

**Referenced in:**

- [§ 3.3.3 pointerdown](#ref-for-dfn-digitizer-1 "§ 3.3.3 pointerdown")
- [§ 3.3.6 pointerup](#ref-for-dfn-digitizer-2 "§ 3.3.6 pointerup")

[Permalink](#dfn-direct-manipulation)

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dfn-direct-manipulation-1 "§ 1. Introduction")
- [§ 3.1.3.1 Attributes and default
 actions](#ref-for-dfn-direct-manipulation-2 "§ 3.1.3.1 Attributes and default actions")
- [§ 7. Declaring direct manipulation
 behavior](#ref-for-dfn-direct-manipulation-3 "§ 7. Declaring direct manipulation behavior")
- [§ 7.1 The touch-action CSS
 property](#ref-for-dfn-direct-manipulation-4 "§ 7.1 The touch-action CSS property")
- [§ 7.2 Determining supported direct manipulation
 behavior](#ref-for-dfn-direct-manipulation-5 "§ 7.2 Determining supported direct manipulation behavior")
- [§ 7.3 Details of touch-action
 values](#ref-for-dfn-direct-manipulation-6 "§ 7.3 Details of touch-action values")
- [§ 8.4 Implicit pointer
 capture](#ref-for-dfn-direct-manipulation-7 "§ 8.4 Implicit pointer capture")

[Permalink](#dfn-hysteresis)

**Referenced in:**

- [§ 11.3 Mouse Event
 Order](#ref-for-dfn-hysteresis-1 "§ 11.3 Mouse Event Order")
- [§ 11.4.2 click](#ref-for-dfn-hysteresis-2 "§ 11.4.2 click")

[Permalink](#dfn-measurable-property)

**Referenced in:**

- [§ 9.1 Coalesced
 events](#ref-for-dfn-measurable-property-1 "§ 9.1 Coalesced events")

[Permalink](#dfn-pointer)

**Referenced in:**

- [§ 1. Introduction](#ref-for-dfn-pointer-1 "§ 1. Introduction")

[Permalink](#dfn-rotation)

**Referenced in:**

- [§ 12. Wheel Events and
 interfaces](#ref-for-dfn-rotation-1 "§ 12. Wheel Events and interfaces")
 [(2)](#ref-for-dfn-rotation-2 "Reference 2")

[Permalink](#dfn-topmost-event-target)
[exported]

**Referenced in:**

- [§ 3.3.1
 pointerover](#ref-for-dfn-topmost-event-target-1 "§ 3.3.1 pointerover")
- [§ 3.3.2
 pointerenter](#ref-for-dfn-topmost-event-target-2 "§ 3.3.2 pointerenter")
- [§ 3.3.3
 pointerdown](#ref-for-dfn-topmost-event-target-3 "§ 3.3.3 pointerdown")
- [§ 3.3.4
 pointermove](#ref-for-dfn-topmost-event-target-4 "§ 3.3.4 pointermove")
- [§ 3.3.5
 pointerrawupdate](#ref-for-dfn-topmost-event-target-5 "§ 3.3.5 pointerrawupdate")
- [§ 3.3.6
 pointerup](#ref-for-dfn-topmost-event-target-6 "§ 3.3.6 pointerup")
- [§ 3.3.7
 pointercancel](#ref-for-dfn-topmost-event-target-7 "§ 3.3.7 pointercancel")
- [§ 3.3.8
 pointerout](#ref-for-dfn-topmost-event-target-8 "§ 3.3.8 pointerout")
- [§ 3.3.9
 pointerleave](#ref-for-dfn-topmost-event-target-9 "§ 3.3.9 pointerleave")
- [§ 3.3.10
 gotpointercapture](#ref-for-dfn-topmost-event-target-10 "§ 3.3.10 gotpointercapture")
- [§ 3.3.11
 lostpointercapture](#ref-for-dfn-topmost-event-target-11 "§ 3.3.11 lostpointercapture")
- [§ 11.4.1
 auxclick](#ref-for-dfn-topmost-event-target-12 "§ 11.4.1 auxclick")
 [(2)](#ref-for-dfn-topmost-event-target-13 "Reference 2")
- [§ 11.4.2
 click](#ref-for-dfn-topmost-event-target-14 "§ 11.4.2 click")
 [(2)](#ref-for-dfn-topmost-event-target-15 "Reference 2")
- [§ 11.4.3
 contextmenu](#ref-for-dfn-topmost-event-target-16 "§ 11.4.3 contextmenu")
- [§ 11.4.5
 mousedown](#ref-for-dfn-topmost-event-target-17 "§ 11.4.5 mousedown")
- [§ 11.4.6
 mouseenter](#ref-for-dfn-topmost-event-target-18 "§ 11.4.6 mouseenter")
- [§ 11.4.7
 mouseleave](#ref-for-dfn-topmost-event-target-19 "§ 11.4.7 mouseleave")
- [§ 11.4.8
 mousemove](#ref-for-dfn-topmost-event-target-20 "§ 11.4.8 mousemove")
- [§ 11.4.9
 mouseout](#ref-for-dfn-topmost-event-target-21 "§ 11.4.9 mouseout")
- [§ 11.4.10
 mouseover](#ref-for-dfn-topmost-event-target-22 "§ 11.4.10 mouseover")
- [§ 11.4.11
 mouseup](#ref-for-dfn-topmost-event-target-23 "§ 11.4.11 mouseup")
- [§ 12. Wheel Events and
 interfaces](#ref-for-dfn-topmost-event-target-24 "§ 12. Wheel Events and interfaces")
- [§ 15.
 Glossary](#ref-for-dfn-topmost-event-target-25 "§ 15. Glossary")

[Permalink](#dom-mouseevent-initmouseevent)
[exported]
[IDL](#webidl-651575932 "Jump to IDL declaration")

**Referenced in:**

- [§ 16.1 Initializers for interface
 MouseEvent](#ref-for-dom-mouseevent-initmouseevent-1 "§ 16.1 Initializers for interface MouseEvent")
- [§ C. IDL
 Index](#ref-for-dom-mouseevent-initmouseevent-2 "§ C. IDL Index")

::: header-wrapper
## D. References

::: header-wrapper
### D.1 Normative references

\[CSS-OVERFLOW-3\]
: [CSS Overflow Module Level
 3](https://www.w3.org/TR/css-overflow-3/). Elika Etemad; Florian
 Rivoal. W3C. 7 October 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-overflow-3/>

\[css-position\]
: [CSS Positioned Layout Module Level
 3](https://www.w3.org/TR/css-position-3/). Elika Etemad; Tab Atkins
 Jr. W3C. 7 October 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/css-position-3/>

\[CSS21\]
: [Cascading Style Sheets Level 2 Revision 1 (CSS 2.1)
 Specification](https://www.w3.org/TR/CSS2/). Bert Bos; Tantek Çelik;
 Ian Hickson; Håkon Wium Lie. W3C. 7 June 2011. W3C Recommendation.
 URL: <https://www.w3.org/TR/CSS2/>

\[CSSOM-View\]
: [CSSOM View Module](https://www.w3.org/TR/cssom-view-1/). Simon
 Fraser; Emilio Cobos Álvarez. W3C. 16 September 2025. W3C Working
 Draft. URL: <https://www.w3.org/TR/cssom-view-1/>

\[DOM\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[ECMASCRIPT\]
: [ECMAScript Language
 Specification](https://tc39.es/ecma262/multipage/). Ecma
 International. URL: <https://tc39.es/ecma262/multipage/>

\[HTML\]
: [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
 Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
 Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
 <https://html.spec.whatwg.org/multipage/>

\[HTML401\]
: [HTML 4.01 Specification](https://www.w3.org/TR/html401/). Dave
 Raggett; Arnaud Le Hors; Ian Jacobs. W3C. 27 March 2018. W3C
 Recommendation. URL: <https://www.w3.org/TR/html401/>

\[infra\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[PointerLock\]
: [Pointer Lock 2.0](https://www.w3.org/TR/pointerlock-2/). Mustaq
 Ahmed; Vincent Scheib. W3C. 25 February 2026. W3C Working Draft.
 URL: <https://www.w3.org/TR/pointerlock-2/>

\[RFC2119\]
: [Key words for use in RFCs to Indicate Requirement
 Levels](https://www.rfc-editor.org/info/rfc2119/). S. Bradner. IETF.
 March 1997. Best Current Practice. URL:
 <https://www.rfc-editor.org/info/rfc2119/>

\[RFC8174\]
: [Ambiguity of Uppercase vs Lowercase in RFC 2119 Key
 Words](https://www.rfc-editor.org/info/rfc8174/). B. Leiba. IETF.
 May 2017. Best Current Practice. URL:
 <https://www.rfc-editor.org/info/rfc8174/>

\[TOUCH-EVENTS\]
: [Touch Events](https://www.w3.org/TR/touch-events/). Doug Schepers;
 Sangwhan Moon; Matt Brubeck; Arthur Barstow. W3C. 10 October 2013.
 W3C Recommendation. URL: <https://www.w3.org/TR/touch-events/>

\[UIEvents\]
: [UI Events](https://www.w3.org/TR/uievents/). Xiaoqian Wu. W3C. 21
 February 2026. W3C Working Draft. URL:
 <https://www.w3.org/TR/uievents/>

\[UIEvents-Key\]
: [UI Events KeyboardEvent key
 Values](https://www.w3.org/TR/uievents-key/). Travis Leithead; Gary
 Kacmarcik. W3C. 22 April 2025. W3C Recommendation. URL:
 <https://www.w3.org/TR/uievents-key/>

\[WEBDRIVER-BIDI\]
: [WebDriver BiDi](https://www.w3.org/TR/webdriver-bidi/). James
 Graham; Alex Rudenko; Maksim Sadym. W3C. 8 October 2026. W3C Working
 Draft. URL: <https://www.w3.org/TR/webdriver-bidi/>

\[WEBIDL\]
: [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
 Timothy Gu. WHATWG. Living Standard. URL:
 <https://webidl.spec.whatwg.org/>

::: header-wrapper
### D.2 Informative references

\[COMPAT\]
: [Compatibility Standard](https://compat.spec.whatwg.org/). Mike
 Taylor. WHATWG. Living Standard. URL:
 <https://compat.spec.whatwg.org/>

\[PointerEvents\]
: [Pointer Events](https://www.w3.org/TR/pointerevents4/). Patrick
 Lauke; Robert Flack. W3C. 5 October 2026. W3C Working Draft. URL:
 <https://www.w3.org/TR/pointerevents4/>

\[PointerEvents3\]
: [Pointer Events](https://www.w3.org/TR/pointerevents3/). Patrick
 Lauke; Robert Flack. W3C. 30 June 2026. W3C Recommendation. URL:
 <https://www.w3.org/TR/pointerevents3/>

\[WCAG22\]
: [Web Content Accessibility Guidelines (WCAG)
 2.2](https://www.w3.org/TR/WCAG22/). Michael Cooper; Andrew
 Kirkpatrick; Alastair Campbell; Rachael Bradley Montgomery; Charles
 Adams. W3C. 12 December 2024. W3C Recommendation. URL:
 <https://www.w3.org/TR/WCAG22/>

[[↑]](#title)
