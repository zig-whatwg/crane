# Chapter 15: Scripting and Interactivity

::: }}
[Overview](./) · [Previous](pservers.html) · [Next](linking.html) ·
[Elements](eltindex.html) · [Attributes](attindex.html) ·
[Properties](propidx.html)

## Contents

1. 1. [[15.1.] Introduction](interact.html#Introduction)
 2. [[15.2.] Supported events](interact.html#SVGEvents)
 1. [[15.2.1.] Relationship with UI
 Events](interact.html#RelationshipWithUIEVENTS)
 3. [[15.3.] User interface events](interact.html#UIEvents)
 4. [[15.4.] Pointer events](interact.html#PointerEvents)
 5. [[15.5.] Hit-testing and processing order for user
 interface events](interact.html#pointer-processing)
 1. [[15.5.1.] Hit-testing](interact.html#hit-testing)
 2. [[15.5.2.] Event
 processing](interact.html#event-processing)
 6. [[15.6.] The '[pointer-events]'
 property](interact.html#PointerEventsProp)
 7. [[15.7.] Focus](interact.html#Focus)
 8. [[15.8.] Event
 attributes](interact.html#EventAttributes)
 1. [[15.8.1.] Animation event
 attributes](interact.html#AnimationEvents)
 9. [[15.9.] The ['script']
 element](interact.html#ScriptElement)
 10. [[15.10.] DOM interfaces](interact.html#DOMInterfaces)
 1. [[15.10.1.] Interface
 SVGScriptElement](interact.html#InterfaceSVGScriptElement)

## 15.1. Introduction
SVG content can be interactive (i.e., responsive to user-initiated
events) by utilizing the following features in the SVG language:

- User-initiated actions such as button presses on the pointing device
 (e.g., a mouse) can cause
 [animations](https://w3c.github.io/svgwg/specs/animations/) or
 [scripts](interact.html) to execute.
- The user can initiate hyperlinks to new Web pages (see [Links out of
 SVG content: the ['a'] element](linking.html#Links)) by
 actions such as mouse clicks when the pointing device is positioned
 over particular graphics elements.

This chapter describes scripting and DOM
[event](interact.html#SVGEvents) handling in interactive SVG, including
under which circumstances events are triggered.

Related information can be found in other chapters:

- hyperlinks are discussed in [Links](linking.html)
- animation is discussed in [Animating SVG Documents](animate.html)

## 15.2. Supported events
 -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Support anchor change events.
 Resolution: [SVG 2 will consider adding HTML document wide events (including hashchange) apply to SVG documents where they make sense.](https://www.w3.org/2011/12/22-svg-irc#T21-23-17)
 Purpose: To allow authors to use the same set of event listener attributes on a root SVG element that they can on an HTML body or root element.
 Owner: Cameron ([ACTION-3278](https://www.w3.org/Graphics/SVG/WG/track/actions/3278))
 -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Have event listener attributes on an appropriate interface.
 Resolution: [SVG 2 will move all events listener attributes to Element, in accordance with the similar move in HTML.](https://www.w3.org/2011/07/27-svg-minutes.html#item03)
 Purpose: To align with HTML.
 Owner: Cameron ([ACTION-3283](https://www.w3.org/Graphics/SVG/WG/track/actions/3283))
 -------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------

 -------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Introduce evt as an alias to event in event handlers.
 Resolution: [We decide to resolve ISSUE-2176 by introducing evt as an alias to event in event handlers.](https://www.w3.org/2011/07/27-svg-minutes.html#item15)
 Purpose: To align with HTML.
 Owner: Cameron ([ACTION-3093](https://www.w3.org/Graphics/SVG/WG/track/actions/3093))
 -------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------

 -------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Support drag & drop functionality.
 Resolution: [SVG 2 may require drag & drop functionality, and we\'ll investigate HTML5\'s functionality for that.](https://www.w3.org/2011/12/22-svg-irc#T21-31-24)
 Purpose: To allow easier drag & drop in SVG, and to align with HTML.
 Owner: Erik ([ACTION-3328](https://www.w3.org/Graphics/SVG/WG/track/actions/3328))
 -------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------

The following aspects of SVG are affected by events:

- Using [SVG Document Object Model (DOM)](types.html#SVGDOMOverview), a
 script can [add or remove DOM event
 listeners](https://www.w3.org/TR/dom/#dom-eventtarget-addeventlistener)
 (\[[DOM](refs.html#ref-dom)\]) so that script can be invoked or
 ignored when a given event occurs on an event target
- SVG\'s [animation
 elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)
 can be defined to begin or end based on events.

A number of events defined in SVG 1.1, [SVGLoad],
[SVGError] etc, have been replaced with the equivalent
unprefixed events defined in [UI
EVENTS](https://www.w3.org/TR/uievents/#events-uievent-types) and
[HTML](https://html.spec.whatwg.org/multipage/indices.html#events-2).

There should be some more modern examples of
using events in svg, e.g touch events (w reference to touch events
spec). [Device orientation](https://www.w3.org/TR/orientation-event/)
events might also be of interest.

The following table lists the events defined by this specification, or
that have further requirements or clarifications compared to the
specification(s) where they are defined.

The *Event name* in the first column is the name to use within SVG\'s
[animation
elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)
to define the events which can start or end animations. The *UI Event
name* in the second column is the name to use when defining [DOM event
listeners](https://www.w3.org/TR/dom/#dom-eventtarget-addeventlistener)
(\[[DOM](refs.html#ref-dom)\], section 3.6).

For events not listed in the table, such as events introduced in HTML or
UI Events, the respective [event
type](https://dom.spec.whatwg.org/#ref-for-dom-event-type) is the name
to use within SVG\'s [animation
elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement).

Requirements in the table on whether an event of a given type bubbles or
is cancelable apply only to events that are created and dispatched by
the user agent. Events of those types created from script using the
`createEvent` method on the
[Document](https://dom.spec.whatwg.org/#interface-document)
interface can be made to bubble or be cancelable with the
[initEvent](https://www.w3.org/TR/dom/#dom-event-initevent) method.

+--------------------------------------------------------------------------------------------+-----------------+-----------------+-----------------+
| Event name and description | UI Event name | Event category | Event attribute |
| | | | name |
+============================================================================================+=================+=================+=================+
| **load** | (same) | none | onload |
| | | | |
| The load event is dispatched only to [structurally external | | | |
| elements](struct.html#TermStructurallyExternalElement) and to the | | | |
| [Window](https://html.spec.whatwg.org/multipage/window-object.html#window), | | | |
| when the corresponding external resources have finished loading. Note that due to it\'s | | | |
| [relationship](struct.html#SVGElementEventHandlerAttributes) with | | | |
| [Window](https://html.spec.whatwg.org/multipage/window-object.html#window) | | | |
| the load event on ['[svg](struct.html#SVGElement)'] elements is only | | | |
| dispatched when all resources in the document have been completely loaded. | | | |
| | | | |
| The load event and the error event on [structurally external | | | |
| elements](struct.html#TermStructurallyExternalElement) are mutually exclusive, only one of | | | |
| these events must be dispatched when processing the element in question. | | | |
| | | | |
| load events do not bubble and are not cancelable. | | | |
| | | | |
| In previous SVG specifications the load event was called SVGLoad and could be dispatched | | | |
| immediately after parsing an element but before the related resource(s) were fully loaded. | | | |
+--------------------------------------------------------------------------------------------+-----------------+-----------------+-----------------+
| **unload** | (same) | none | onunload |
| | | | |
| Only applicable to [outermost svg elements](struct.html#TermOutermostSVGElement). The | | | |
| unload event occurs when the DOM implementation removes a document from a window or frame. | | | |
| | | | |
| unload events do not bubble and are not cancelable. | | | |
+--------------------------------------------------------------------------------------------+-----------------+-----------------+-----------------+
| **error** | (same) | none | onerror |
| | | | |
| The error event occurs when a [structurally external | | | |
| element](struct.html#TermStructurallyExternalElement) does not load properly or when an | | | |
| error occurs during script execution. | | | |
| | | | |
| error events bubble but are not cancelable. | | | |
+--------------------------------------------------------------------------------------------+-----------------+-----------------+-----------------+
| **beginEvent** | none | none | onbegin |
| | | | |
| Occurs when an animation element begins. For details, see the description of Interface | | | |
| TimeEvent in the [SMIL Animation | | | |
| specification](https://www.w3.org/TR/2001/REC-smil-animation-20010904/). | | | |
+--------------------------------------------------------------------------------------------+-----------------+-----------------+-----------------+
| **endEvent** | none | none | onend |
| | | | |
| Occurs when an animation element ends. For details, see the description of Interface | | | |
| TimeEvent in the [SMIL Animation | | | |
| specification](https://www.w3.org/TR/2001/REC-smil-animation-20010904/). | | | |
+--------------------------------------------------------------------------------------------+-----------------+-----------------+-----------------+
| **repeatEvent** | none | none | onrepeat |
| | | | |
| Occurs when an animation element repeats. It is raised each time the element repeats, | | | |
| after the first iteration. For details, see the description of Interface TimeEvent in the | | | |
| [SMIL Animation specification](https://www.w3.org/TR/2001/REC-smil-animation-20010904/). | | | |
+--------------------------------------------------------------------------------------------+-----------------+-----------------+-----------------+

Details on the parameters passed to event listeners for the event types
for UI Events can be found in the
(\[[uievents](refs.html#ref-uievents)\]) and
(\[[DOM](refs.html#ref-dom)\]) specifications. For other event types,
the parameters passed to event listeners are described elsewhere in this
specification.

Likewise, [event-value timing
specifiers](https://w3c.github.io/svgwg/specs/animations/#EventValueSyntax)
used in [animation
element](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement)
['[begin](https://w3c.github.io/svgwg/specs/animations/#BeginAttribute)']
and
['[end](https://w3c.github.io/svgwg/specs/animations/#EndAttribute)']
attributes are resolved to concrete times only in response to
\"bubbling\" and \"at target\" phase events dispatched to the relevant
element.

### 15.2.1. Relationship with UI Events
The SVG DOM is compatible with all interfaces defined in, and all the
event types from, [UI Events](https://www.w3.org/TR/uievents/), and the
event types defined in [Clipboard API and
events](https://www.w3.org/TR/clipboard-apis/)
(\[[uievents](refs.html#ref-uievents)\],
\[[clipboard-apis](refs.html#ref-clipboard-apis)\]).

All elements in the SVG namespace support [event
attributes](interact.html#TermEventAttribute) for these events; matching
IDL properties are included in the base
[SVGElement](types.html#InterfaceSVGElement) interface
via the
[GlobalEventHandlers](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)
mixin.

As part of SVG DOM support, conforming SVG software must support all
(non-deprecated, non-obsolete) event types defined in these
specifications, if the relevant events could occur in the software\'s
use. SVG software that does not support user
[interaction](conform.html#processing-modes) should nonetheless
implement support for events that can fire without interaction, such as
`load` and `error` events.

SVG animation elements (defined in the [SVG Animations Level
2](https://w3c.github.io/svgwg/specs/animations/) specification) support
additional events and event attributes. The following event types are
triggered due to state changes in animations.

- [beginEvent](interact.html#BeginEvent)
- [endEvent](interact.html#EndEvent)
- [repeatEvent](interact.html#RepeatEvent)

The [event attributes](interact.html#TermEventAttribute) for these
animation events have no effect on other elements.

## 15.3. User interface events
On user agents which support interactivity, it is common for authors to
define SVG documents such that they are responsive to user interface
events. Among the set of possible user events are [pointer
events](interact.html#PointerEvents), keyboard events, and document
events.

In response to user interface (UI) events, the author might start an
animation, perform a hyperlink to another Web page, highlight part of
the document (e.g., change the color of the graphics elements which are
under the pointer), initiate a \"roll-over\" (e.g., cause some
previously hidden graphics elements to appear near the pointer) or
launch a script which communicates with a remote database.

## 15.4. Pointer events
User interface events that occur because of user actions performed on a
pointer device are called pointer events.

Many systems support pointer devices such as a mouse or trackball. On
systems which use a mouse, pointer events consist of actions such as
mouse movements and mouse clicks. On systems with a different pointer
device, the pointing device often emulates the behavior of the mouse by
providing a mechanism for equivalent user actions, such as a button to
press which is equivalent to a mouse click.

For each pointer event, the SVG user agent determines the *target
element* of a given pointer event. The target element is the topmost
graphics element whose relevant graphical content is under the pointer
at the time of the event. (See property
[pointer-events](interact.html#PointerEventsProperty) for a
description of how to determine whether an element\'s relevant graphical
content is under the pointer, and thus in which circumstances that
graphic element can be the target element for a pointer event.) When an
element is not displayed (i.e., when the
[display](render.html#VisibilityControl) property on that
element or one of its ancestors has a value of [none]),
that element cannot be the target of pointer events.

If a target element for the pointer event exists, then the event is
dispatched to that element according to the normal [event
flow](https://www.w3.org/TR/uievents/#event-flow)
(\[[uievents](refs.html#ref-uievents)\], section 3.1). For shadow trees
created by the ['[use](struct.html#UseElement)'] element
or via script, the event must follow [Dispatching
Events](https://dom.spec.whatwg.org/#dispatching-events)
\[[dom](refs.html#ref-dom)\]

If a target element for the pointer event does not exist, then the event
is ignored.

## 15.5. Hit-testing and processing order for user interface events
[hit-testing]
: The process of determining whether a pointer intersects a given
 [graphics element](struct.html#TermGraphicsElement). Hit-testing is
 used in determining which element to dispatch a mouse event to,
 which might be done in response to the user moving the pointing
 device, or by changes in the position, shape and other attributes of
 elements in the document. Hit-testing is also known as *hit
 detection* or *picking*. See also the definition of the
 [pointer-events](interact.html#PointerEventsProperty)
 property.

There are two distinct aspects of pointer-device interaction with an
element or area:

1. hit-testing, to determine if a pointer event (such as a mouse
 movement or mouse click) occurred within the interaction area of an
 element, and the subsequent DOM event flow;
2. functional processing of actions associated with any relevant
 element.

### 15.5.1. Hit-testing
Determining whether a pointer event results in a positive
[hit-test](interact.html#TermHitTesting) depends upon the position of
the pointer, the size and shape of the [graphics
element](struct.html#TermGraphicsElement), and the computed value of the
[pointer-events](interact.html#PointerEventsProperty)
property on the element. The definition of the
[pointer-events](interact.html#PointerEventsProperty)
property below describes the exact region that is sensitive to pointer
events for a given type of graphics element.

Note that the ['[svg](struct.html#SVGElement)'] element
is not a [graphics element](struct.html#TermGraphicsElement), and in a
[Conforming SVG Stand-Alone
File](conform.html#ConformingSVGStandAloneFiles) a [outermost svg
element](struct.html#TermOutermostSVGElement) will never be the target
of pointer events, though events can bubble to this element. If a
pointer event does not result in a positive
[hit-test](interact.html#TermHitTesting) on a [graphics
element](struct.html#TermGraphicsElement), then it should evoke any
user-agent-specific window behavior, such as a presenting a context
menu.

This specification does not define the behavior of pointer events on the
[outermost svg element](struct.html#TermOutermostSVGElement) for SVG
images which are embedded by reference or inclusion within another
document, e.g., whether the [outermost svg
element](struct.html#TermOutermostSVGElement) embedded in an HTML
document intercepts mouse click events; future specifications may define
this behavior, but for the purpose of this specification, the behavior
is implementation-specific.

### 15.5.2. Event processing
An element which is the target of a user interface event may have
particular interaction behaviors, depending upon the type of element and
whether it has explicit associated interactions, such as scripted event
listeners, CSS pseudo-classes matches, or declarative animations with
event-based timing. The algorithm and order for processing user
interface events for a given target element, after dispatching the DOM
event, is as follows:

1. If an event handler registered on this element invokes the
 `preventDefault()` DOM method, then no further processing for this
 element is performed, and the event follows the [event dispatch and
 DOM event flow
 processing](https://www.w3.org/TR/uievents/#event-flow)
 (\[[uievents](refs.html#ref-uievents)\]);
2. If the element has an associated title or description, such as a
 ['[title](struct.html#TitleElement)'] element, and
 the user agent supports the display of such information (e.g. via a
 tooltip or status-bar message), that information should be
 displayed, as appropriate to the type of pointer event;
3. If the element matches any relevant [dynamic pseudo-class
 selectors](https://www.w3.org/TR/2011/REC-CSS2-20110607/selector.html#pseudo-class-selectors)
 appropriate to the type of pointer event, such as `:hover`,
 `:active`, or `:focus` as described in
 \[[CSS2](refs.html#ref-css2)\], section 5.11, then the relevant
 class properties are applied;
4. If the element and the event type are associated with the activation
 or cancelation of declarative animation though the use of
 [event-value](https://w3c.github.io/svgwg/specs/animations/#EventValueSyntax)
 timing specifiers, any corresponding instance times must be
 resolved, and any consequential actions of this instance time
 resolution (such as immediately starting or stopping the animation)
 must be performed;
5. If the element is a hyperlink (e.g., it is a descendant element of
 an ['[a](linking.html#AElement)'] element), and the
 pointer event is of a type that activates that hyperlink (e.g. via a
 mouse click), and if the hyperlink traversal changes the context of
 the content (e.g. opens a different document, or moves the pointer
 away from this element by moving to another part of the same
 document), then no further processing for this element is performed;
6. If the element is a [text content
 element](text.html#TermTextContentElement), and the event type is
 one which the user agent recognizes as part of a text-selection
 operation (e.g., a mouse click and drag, or a double-click), then
 the [text selection](text.html#TextSelection) algorithm is
 performed;
7. If the event type is one which the user agent associates with the
 evocation of special user-interface controls (e.g., a right-click or
 command-click evoking a context menu), the user agent should evoke
 such user-agent-specific behavior, such as presenting a context
 menu.

## 15.6. The '[pointer-events]' property
In different circumstances, authors may want to control under what
conditions particular graphic elements can become the target of pointer
events. For example, the author might want a given element to receive
pointer events only when the pointer is over the stroked perimeter of a
given shape. In other cases, the author might want a given element to
ignore pointer events under all circumstances so that graphical elements
underneath the given element will become the target of pointer events.

The effects of masking and clipping differ with respect to [pointer
events](interact.html#PointerEventsProperty). A clip path is a geometric
boundary, and a given point is clearly either inside or outside that
boundary; thus, pointer events must be captured normally over the
rendered areas of a clipped element, but must not be captured over the
clipped areas, as described in the definition of [clipping
paths](https://drafts.csswg.org/css-masking-1/#clipping-path). By
contrast, a mask is not a binary transition, but a pixel operation, and
different behavior for fully transparent and
almost-but-not-fully-transparent may be confusingly arbitrary; as a
consequence, for elements with a mask applied, pointer events must still
be captured even in areas where the mask goes to zero opacity. If an
author wishes to achieve an effect where the transparent parts of a mask
allow pointer events to pass to an element below, a combination of
masking and clipping may be used.

The
[filter](https://drafts.csswg.org/filter-effects-1/#FilterProperty)
property has no effect on pointer events processing, and must in this
context be treated as if the
[filter](https://drafts.csswg.org/filter-effects-1/#FilterProperty)
wasn\'t specified.

For example, suppose a circle with a
[stroke](painting.html#StrokeProperty) of [red]
(i.e., the outline is solid red) and a
[fill](painting.html#FillProperty) of [none]
(i.e., the interior is not painted) is rendered directly on top of a
rectangle with a [fill](painting.html#FillProperty) of
[blue]. The author might want the circle to be the target
of pointer events only when the pointer is over the perimeter of the
circle. When the pointer is over the interior of the circle, the author
might want the underlying rectangle to be the target element of pointer
events.

The [pointer-events](interact.html#PointerEventsProperty)
property specifies under what circumstances a given element can be the
target element for a pointer event. It affects the circumstances under
which the following are processed:

- user interface events such as mouse clicks
- [dynamic
 pseudo-classes](https://www.w3.org/TR/2011/REC-CSS2-20110607/selector.html#pseudo-class-selectors)
 (i.e., :hover, :active and :focus; \[[CSS2](refs.html#ref-css2)\],
 section 5.11)
- hyperlinks (see [Links out of SVG content: the ['a']
 element](linking.html#Links))

 --------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Name: [pointer-events]
 Value: auto \| bounding-box \| visiblePainted \| visibleFill \| visibleStroke \| visible \| painted \| fill \| stroke \| all \| none
 Initial: auto
 Applies to: [container elements](struct.html#TermContainerElement), [graphics elements](struct.html#TermGraphicsElement) and ['[use](struct.html#UseElement)']
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------

[auto]
: The default behavior, which is the same as for
 [visiblePainted].

[bounding-box]
: The given element can be a target element for pointer events when
 the pointer is over the [bounding box](coords.html#TermBoundingBox)
 of the element.

[visiblePainted]
: The given element can be the target element for pointer events when
 the [visibility](render.html#VisibilityControl) property
 is set to [visible] and when the pointer is over a
 \"painted\" area. The pointer is over a painted area if it is over
 the interior (i.e., fill) of the element and the
 [fill](painting.html#FillProperty) property has an actual
 value other than [none] or it is over the perimeter
 (i.e., stroke) of the element and the
 [stroke](painting.html#StrokeProperty) property is set to
 a value other than [none].

[visibleFill]
: The given element can be the target element for pointer events when
 the [visibility](render.html#VisibilityControl) property
 is set to [visible] and when the pointer is over the
 interior (i.e., fill) of the element. The value of the
 [fill](painting.html#FillProperty) property does not
 affect event processing.

[visibleStroke]
: The given element can be the target element for pointer events when
 the [visibility](render.html#VisibilityControl) property
 is set to [visible] and when the pointer is over the
 perimeter (i.e., stroke) of the element. The value of the
 [stroke](painting.html#StrokeProperty) property does not
 affect event processing.

[visible]
: The given element can be the target element for pointer events when
 the [visibility](render.html#VisibilityControl) property
 is set to [visible] and the pointer is over either the
 interior (i.e., fill) or the perimeter (i.e., stroke) of the
 element. The values of the
 [fill](painting.html#FillProperty) and
 [stroke](painting.html#StrokeProperty) do not affect
 event processing.

[painted]
: The given element can be the target element for pointer events when
 the pointer is over a \"painted\" area. The pointer is over a
 painted area if it is over the interior (i.e., fill) of the element
 and the [fill](painting.html#FillProperty) property has
 an actual value other than [none] or it is over the
 perimeter (i.e., stroke) of the element and the
 [stroke](painting.html#StrokeProperty) property has an
 actual value other than [none]. The value of the
 [visibility](render.html#VisibilityControl) property does
 not affect event processing.

[fill]
: The given element can be the target element for pointer events when
 the pointer is over the interior (i.e., fill) of the element. The
 values of the [fill](painting.html#FillProperty) and
 [visibility](render.html#VisibilityControl) properties do
 not affect event processing.

[stroke]
: The given element can be the target element for pointer events when
 the pointer is over the perimeter (i.e., stroke) of the element. The
 values of the [stroke](painting.html#StrokeProperty) and
 [visibility](render.html#VisibilityControl) properties do
 not affect event processing.

[all]
: The given element can be the target element for pointer events
 whenever the pointer is over either the interior (i.e., fill) or the
 perimeter (i.e., stroke) of the element. The values of the
 [fill](painting.html#FillProperty),
 [stroke](painting.html#StrokeProperty) and
 [visibility](render.html#VisibilityControl) properties do
 not affect event processing.

[none]
: The given element does not receive pointer events.

For text elements, hit-testing is performed on a character cell basis:

- The value [visiblePainted] means that the text string can
 receive events anywhere within the character cell if either the
 [fill](painting.html#FillProperty) property is set to a
 value other than [none] or the
 [stroke](painting.html#StrokeProperty) property is set to a
 value other than [none], with the additional requirement
 that the [visibility](render.html#VisibilityControl)
 property is set to [visible].
- The values [visibleFill], [visibleStroke]
 and [visible] are equivalent and indicate that the text
 string can receive events anywhere within the character cell if the
 [visibility](render.html#VisibilityControl) property is set
 to [visible]. The values of the
 [fill](painting.html#FillProperty) and
 [stroke](painting.html#StrokeProperty) properties do not
 affect event processing.
- The value [painted] means that the text string can
 receive events anywhere within the character cell if either the
 [fill](painting.html#FillProperty) property is set to a
 value other than [none] or the
 [stroke](painting.html#StrokeProperty) property is set to a
 value other than [none]. The value of the
 [visibility](render.html#VisibilityControl) property does
 not affect event processing.
- The values [fill], [stroke] and
 [all] are equivalent and indicate that the text string
 can receive events anywhere within the character cell. The values of
 the [fill](painting.html#FillProperty),
 [stroke](painting.html#StrokeProperty) and
 [visibility](render.html#VisibilityControl) properties do
 not affect event processing.
- The value [none] indicates that the given text does not
 receive pointer events.

For raster images, hit-testing is performed on a whole-image basis
(i.e., the rectangular area for the image is the determinant for whether
the image receives the event):

- The value [visiblePainted] means that the raster image
 can receive events anywhere within the bounds of the image, with the
 additional requirement that the
 [visibility](render.html#VisibilityControl) property is set
 to [visible].
- The values [visibleFill], [visibleStroke]
 and [visible] are equivalent and indicate that the image
 can receive events anywhere within the rectangular area for the image
 if the [visibility](render.html#VisibilityControl) property
 is set to [visible].
- The value [painted] means that the raster image can
 receive events anywhere within the bounds of the image. The value of
 the [visibility](render.html#VisibilityControl) property
 does not affect event processing.
- The values [fill], [stroke] and
 [all] are equivalent and indicate that the image can
 receive events anywhere within the rectangular area for the image. The
 value of the [visibility](render.html#VisibilityControl)
 property does not affect event processing.
- The value [none] indicates that the image does not
 receive pointer events.

For
['[foreignObject](embedded.html#ForeignObjectElement)']
elements, hit-testing is performed on the rectangular area, the [object
bounding box](coords.html#TermObjectBoundingBox), of the element. See
processing for raster images above. Useragents may allow the foreign
content of a
['[foreignObject](embedded.html#ForeignObjectElement)']
element to be target of hit-testing as well.

The values of properties
[opacity](render.html#ObjectAndGroupOpacityProperties),
[fill-opacity](painting.html#FillOpacityProperty),
[stroke-opacity](painting.html#StrokeOpacityProperty),
[fill](painting.html#FillProperty) and
[stroke](painting.html#StrokeProperty) do not affect event
processing.

::::: ready-for-wider-review
## 15.7. Focus
SVG uses the same [focus
model](https://html.spec.whatwg.org/multipage/interaction.html#focus) as
HTML, modified for SVG as described in this section. At most one element
in each document is
[focused](https://html.spec.whatwg.org/multipage/interaction.html#focused)
at a time; if the document as a whole has system focus, this element
becomes the target of all keyboard events.

When an element is focused, the element matches the [CSS `:focus`
pseudo-class](https://www.w3.org/TR/css-selectors-3/#the-user-action-pseudo-classes-hover-act).
Interactive user agents must visually indicate focus (usually with an
outline) when the focus changes because of a user input event from the
keyboard or other non-pointing device and may indicate focus at all
times. Authors may use the `:focus` pseudo-class to replace the visual
indication with one more suitable to the graphic, (such as a stroke on a
shape) but should not use it to remove visual indications of focus
completely.

The following SVG elements are [focusable] in an interactive document. Any
[instance](struct.html#TermElementInstance) of such an element in a
[use-element shadow tree](struct.html#TermUseElementShadowTree) is also
focusable. For the purpose of the HTML focus model, interactive user
agents must treat them as [focusable
areas](https://html.spec.whatwg.org/multipage/interaction.html#focusable)
whose [tabindex focus
flag](https://html.spec.whatwg.org/multipage/interaction.html#specially-focusable)
should be set:

- the document root element
- any element (such as within a
 ['[foreignObject](embedded.html#ForeignObjectElement)'])
 that generates a scrollable region
- any directly [rendered element](render.html#TermRenderedElement) with
 a valid integer
 ['[tabindex](struct.html#SVGElementTabindexAttribute)']
 attribute

In the case of user-agent supplied controls, the element may have more
than one focusable area, for each sub-control.

In addition, all ['[a](linking.html#AElement)'] elements
that are valid links are [focusable](interact.html#TermFocusable), and
their [tabindex focus
flag](https://html.spec.whatwg.org/multipage/interaction.html#specially-focusable)
must be set *unless* the user agent normally provides an alternative
method of keyboard traversal of links.

For compatibility with content that used the [SVG Tiny 1.2
[focusable]
attribute](https://www.w3.org/TR/SVGTiny12/interact.html#focusable-attr),
user agents should treat an element with a value of [true]
for that attribute as focusable. In new content, authors should either
omit the [focusable] attribute or use it only in combination
with a corresponding [tabindex] value of [0].

User agents may treat other elements as focusable, particularly if
keyboard interaction is the only or primary means of user input. In
particular, user agents may support using keyboard focus to reveal
['[title](struct.html#TitleElement)'] element text as
tooltips, and may allow focus to reach elements which have been assigned
listeners for mouse, pointer, or focus events. Authors should not rely
on this behavior; all interactive elements should directly support
keyboard interaction.

The sequential focus order is generated from the set of all
[focusable](interact.html#TermFocusable) elements, processing
['[tabindex](struct.html#SVGElementTabindexAttribute)']
attributes on SVG elements in the same way as [tabindex attributes on
HTML
elements](https://html.spec.whatwg.org/multipage/interaction.html#the-tabindex-attribute).
Content within a [use-element shadow
tree](struct.html#TermUseElementShadowTree) is inserted in the focus
order as if it was child content of the
['[use](struct.html#UseElement)'] element.

A [non-rendered element](render.html#TermNonRenderedElement) can never
receive focus, regardless of the value of the
['[tabindex](struct.html#SVGElementTabindexAttribute)']
attribute, If a script programmatically assigns focus to a non-rendered
or otherwise un-focusable element, the focusing call is aborted. Note,
however, that an element that is not visible or onscreen may still be
[rendered](render.html#TermRenderedElement).

When the user agent supports scrolling or panning of the SVG document,
and focus moves to an element that is currently outside the SVG
viewport, the user agent should scroll or pan the document until the
focused element is within the SVG viewport.

As in HTML, an SVG element that is
[focusable](interact.html#TermFocusable) but does not have a defined
[activation
behavior](https://dom.spec.whatwg.org/#eventtarget-activation-behavior)
has an activation behaviour that does nothing (unless a script
specifically responds to it).

This means that an element that is only focusable because of its
['[tabindex](struct.html#SVGElementTabindexAttribute)']
attribute will fire a `click` event in response to a non-mouse
activation (e.g. hitting the \"enter\" key while the element has
[focus](interact.html#Focus)).

For documents that contain a mix of inline HTML and SVG, focus is
handled for the document as a whole (with a combined sequential focus
order), not with each inline SVG or HTML fragment as an isolated
subdocument.

For example, in the following document, pressing Tab would cycle the
focus between elements A, B and C, in that order.

 <!DOCTYPE html>
 <button id="A" tabindex="1">First thing</button>
 <button id="C" tabindex="2">Third thing</button>
 <svg width="200" height="200">
 <text id="B" tabindex="1" x="100" y="100">Second thing</text>
 </svg>

Note that SVG elements do not have an equivalent of HTML\'s
[accesskey](https://html.spec.whatwg.org/multipage/interaction.html#the-accesskey-attribute)
attribute.

## 15.8. Event attributes
[event attribute]
: An event attribute always has a name that starts with \"on\"
 followed by the name of the event for which it is intended. It
 specifies some script to run when the event of the given type is
 dispatched to the element on which the attribute is specified.

For every [event
type](https://dom.spec.whatwg.org/#ref-for-dom-event-type) that the
[user agent](conform.html#TermUserAgent) supports, SVG supports that as
an event attribute, following the same requirements as for [event
handler content
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-content-attributes)
\[[HTML](refs.html#ref-html)\]. The [event
attributes](interact.html#TermEventAttribute) are available on all [SVG
elements](struct.html#TermSVGElements).

The contents of event attributes are always interpreted as ECMAScript,
as if processed with the media type
[\'application/ecmascript\'].
\[[rfc2046](refs.html#ref-rfc2046)\]\[[rfc4329](refs.html#ref-rfc4329)\]

Event attributes are not
[animatable](https://w3c.github.io/svgwg/specs/animations/#Animatable).

Implementors may view the setting of event attributes as the creation
and registration of an
[EventListener](https://dom.spec.whatwg.org/#callbackdef-eventlistener)
on the
[EventTarget](https://dom.spec.whatwg.org/#interface-eventtarget).
Such event listeners are invoked only for the \"bubbling\" and \"at
target\" phases, as if false were specified for the `useCapture`
argument to `addEventListener`. This
[EventListener](https://dom.spec.whatwg.org/#callbackdef-eventlistener)
behaves in the same manner as any other which may be registered on the
[EventTarget](https://dom.spec.whatwg.org/#interface-eventtarget).

If the attribute representing the event listener is changed, this may be
viewed as the removal of the previously registered
[EventListener](https://dom.spec.whatwg.org/#callbackdef-eventlistener)
and the registration of a new one. Furthermore, no specification is made
as to the order in which event attributes will receive the event with
regards to the other EventListeners on the
[EventTarget](https://dom.spec.whatwg.org/#interface-eventtarget).

In ECMAScript, one way to establish an event listener is to define a
function and pass that function to the `addEventListener` method:

 function myAction1(evt) {
 // process the event
 }
 // ... later ...
 myElement.addEventListener("click", myAction1, false)

In ECMAScript, the character data content of an [event
attribute](interact.html) becomes the definition of the ECMAScript
function which gets invoked in response to the event. As with all
registered ECMAScript event listener functions, this function receives
an [Event](https://dom.spec.whatwg.org/#interface-event)
object as a parameter, and the name of the Event object is **evt**. For
example, it is possible to write:

 <rect onclick="MyClickHandler(evt)" .../>

which will pass the
[Event](https://dom.spec.whatwg.org/#interface-event)
object **evt** into function `MyClickHandler`.

### 15.8.1. Animation event attributes
Below are the definitions for the [animation event
attributes](https://w3c.github.io/svgwg/specs/animations/#TermAnimationEventAttribute).
These can be specified on the [animation
elements](https://w3c.github.io/svgwg/specs/animations/#TermAnimationElement).

*Attribute definitions:*

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ------------- --------------- ------------
 [onbegin], [onend], [onrepeat] (see below) (none) no

Specifies some script to execute when \"bubbling\" or \"at target\"
phase listeners for the corresponding event are fired on the element the
attribute is specified on. See [supported events
table](interact.html#SVGEvents) to determine which event each of these
event attributes corresponds to. There are no restrictions on the values
of this attribute.

## 15.9. The ['script'] element
 -------------------- ---------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Consider allowing async/defer on ['[script](interact.html#ScriptElement)'].
 Resolution: [SVG 2 will allow async/defer on ['script'].](https://www.w3.org/2012/01/05-svg-irc#T21-07-03)
 Purpose: To align with HTML.
 Owner: Cameron ([ACTION-3280](https://www.w3.org/Graphics/SVG/WG/track/actions/3280))
 -------------------- ---------------------------------------------------------------------------------------------------------------

 -------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Incorporate SVG Tiny 1.2 script processing model.
 Resolution: [SVG 2 will define how inline scriptable content will be processed, in a compatible way to HTML5](https://www.w3.org/2012/03/08-svg-irc#T21-09-09)
 Purpose: To have consistent script running behavior across HTML and SVG.
 Owner: Cameron ([ACTION-3282](https://www.w3.org/Graphics/SVG/WG/track/actions/3282))
 -------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------

A ['[script](interact.html#ScriptElement)'] element is
equivalent to the
['[script](interact.html#ScriptElement)'] element in HTML
and thus is the place for scripts (e.g., ECMAScript). Any functions
defined within any
['[script](interact.html#ScriptElement)'] element have a
\"global\" scope across the entire current document.

The script\'s text content is never directly rendered; the
[display](render.html#VisibilityControl) value for the
['[script](interact.html#ScriptElement)'] element must
always be set to [none] by the [user agent style
sheet](styling.html#UAStyleSheet), and this declaration must have
importance over any other CSS rule or presentation attribute.

Before attempting to execute the
['[script](interact.html#ScriptElement)'] element the
resolved media type value for
['[type](interact.html#ScriptElementTypeAttribute)'] must be
inspected. If the [SVG user agent](conform.html#TermUserAgent) does not
support the scripting language then the
['[script](interact.html#ScriptElement)'] element must
not be executed.

This example defines a function `circle_click` which is called by the
['[onclick](interact.html#EventAttributes)'] event attribute
on the ['[circle](shapes.html#CircleElement)'] element.
The drawing below on the left is the initial image. The drawing below on
the right shows the result after clicking on the circle.

``` xml

 <?xml version="1.0" standalone="no"?>
 <svg width="6cm" height="5cm" viewBox="0 0 600 500"
 xmlns="http://www.w3.org/2000/svg">
 <desc>Example script01 - invoke an ECMAScript function from an onclick event
 </desc>
 <!-- ECMAScript to change the radius with each click -->
 <script type="application/ecmascript"> <![CDATA[
 function circle_click(evt) {
 var circle = evt.target;
 var currentRadius = circle.getAttribute("r");
 if (currentRadius == 100)
 circle.setAttribute("r", currentRadius*2);
 else
 circle.setAttribute("r", currentRadius*0.5);
 }
 ]]> </script>

 <!-- Outline the drawing area with a blue line -->
 <rect x="1" y="1" width="598" height="498" fill="none" stroke="blue"/>

 <!-- Act on each click event -->
 <circle onclick="circle_click(evt)" cx="300" cy="225" r="100"
 fill="red"/>

 <text x="300" y="480"
 font-family="Verdana" font-size="35" text-anchor="middle">

 Click on circle to change its size
 </text>
 </svg>

```

 ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ![An example demonstrating how to invoke an ECMAScript function from an onclick event --- before first click](images/script/script01.png)  ![An example demonstrating how to invoke an ECMAScript function from an onclick event --- after first click](images/script/script01-AfterClick.png)
 ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 : An example demonstrating the effect of the
 ['[onclick](interact.html#EventAttributes)'] event handler
 on an SVG shape.

[View this example as SVG (SVG-enabled browsers
only)](images/script/script01.svg)

:::: element-summary
::: element-summary-name
['[script]']

Categories:
: [Never-rendered element](render.html#TermNeverRenderedElement),
 [structurally external
 element](struct.html#TermStructurallyExternalElement)

Content model:
: Character data.

Attributes:

: - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [deprecated xlink attributes](linking.html#XLinkRefAttrs)[ ---
 ['[xlink:href](linking.html#XLinkHrefAttribute)'],
 ['[xlink:title](linking.html#XLinkTitleAttribute)']]
 - ['[type](interact.html#ScriptElementTypeAttribute)']
 - ['[href](interact.html#ScriptElementHrefAttribute)']
 - ['[crossorigin](interact.html#ScriptElementCrossoriginAttribute)']

DOM Interfaces:

: - [SVGScriptElement](interact.html#InterfaceSVGScriptElement)

*Attribute definitions:*

 Name Value Initial value Animatable
 ----------------------------------------------------------------------------------------------------------- ------------------------------------- ------------------------------------ ------------
 [crossorigin] \[ anonymous \| use-credentials \]? (see HTML definition of attribute) yes

The crossorigin attribute is a [CORS settings
attribute](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-settings-attribute),
and unless otherwise specified follows the same processing rules as in
html \[[HTML](refs.html#ref-html)\].

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------------------- ------------- ------------------------ ------------
 [type] (see below) application/ecmascript no

Identifies the scripting language for the given
['[script](interact.html#ScriptElement)'] element. The
value must be a valid media type, per [Multipurpose Internet Mail
Extensions (MIME) Part Two](https://www.ietf.org/rfc/rfc2046.txt)
\[[rfc2046](refs.html#ref-rfc2046)\]. If a
['[type](interact.html#ScriptElementTypeAttribute)'] is not
provided, then the default scripting language assumed is ECMAScript, as
if processed with the ['application/ecmascript'] media type.

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------------------- -------------------------------------------------- --------------- ------------
 [href] URL [\[URL\]](types.html#attribute-url) (none) no

An [URL reference](linking.html#URLReference) to an external resource
containing the script code. Refer to the common handling defined for
[URL reference attributes](linking.html#linkRefAttrs) and [deprecated
XLink attributes](linking.html#XLinkRefAttrs).

The URL is processed and the resource is fetched [as described in the
Linking chapter](linking.html#processingURL).

## 15.10. DOM interfaces
### 15.10.1. Interface SVGScriptElement
An
[SVGScriptElement](interact.html#InterfaceSVGScriptElement)
object represents a
['[script](interact.html#ScriptElement)'] element in the
DOM.

``` idl
[Exposed=Window]
interface SVGScriptElement : SVGElement {
 [Reflect] attribute DOMString type;
 attribute DOMString? crossOrigin;
};

SVGScriptElement includes SVGURIReference;
```

The **crossOrigin** IDL attribute [reflects](types.html#TermReflect) the
['[crossorigin](interact.html#ScriptElementCrossoriginAttribute)']
content attribute.
