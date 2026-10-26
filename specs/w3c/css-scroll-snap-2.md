## 1. Introduction

*This section is not normative.*

*This is currently a delta spec over Scroll Snap 1.*

Scroll experiences don't always start at the beginning. Interactions
with carousels, swipe controls, and listviews often intend to begin from
some element which might not be positioned at the beginning of the
scroll container. JavaScript is required to make the scroll container
initially scrolled to that element. By enabling CSS to specify that an
element should be initially scrolled to, both users, page authors and
browsers benefit.

In addition to setting an initial scroll target, developers need
insights and events into Scroll Snap. Events like which element is
snapped on which axis, when the snap event is changing, when snap
completes and conveniences for snapping to children programmatically.

### 1.1. First Layout

This event should follow the Animation code path. When animation objects
are created and fire events, this is when a box has it's first layout.

## 2. Motivating Examples

A carousel that starts scrolled to the
middle image:

```
.carousel {
 overflow-inline: auto;
}
.carousel .origin {
 scroll-initial-target: nearest;
}
```

```
<div class="carousel">
 <img src="img1.jpg">
 <img src="img2.jpg">
 <img src="img3.jpg" class="origin">
 <img src="img4.jpg">
 <img src="img5.jpg">
</div>
```

A search bar is available when the
user scrolls back to the top:

```
.scrollport {
 overflow-block: auto;
}

main {
 scroll-initial-target: nearest;
}
```

```
<div class="scrollport">
 <nav>
 ...
 </nav>
 <main>
 ...
 </main>
</div>
```

## 3. Setting Where Scroll Starts

### 3.1. The [scroll-initial-target property]
The name \"scroll-initial-target\" is
chosen as the least worst option which expresses that it should be
scrolled to when its scroll container first shows up on the page. A
better name for the property would be very much welcome. [\[Issue
#11173\]](https://github.com/w3c/csswg-drafts/issues/11173)

#### 3.1.1. Initial scroll target

The [initial scroll
target](#initial-scroll-target) of a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) `scrollcontainer` is an element or
pseudo-element whose
[scroll-initial-target](#propdef-scroll-initial-target)property is
non-[none](#valdef-scroll-initial-target-none) and whose nearest [scroll
container] is `scrollcontainer`.
When multiple such elements or pseudo-elements exist, user-agents should
select the one which comes first in [tree
order](https://dom.spec.whatwg.org/#concept-tree-order). When no such element or pseudo-element exists,
`scrollcontainer`'s [initial scroll
target] is null.

If the [initial scroll
target](#initial-scroll-target) of a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) is not null, it should be used to determine the
[initial scroll
position](https://drafts.csswg.org/css-overflow-3/#initial-scroll-position) of `scrollcontainer` by running the
following steps:

1. Let `target` be the [initial scroll
 target](#initial-scroll-target) for `scrollcontainer`.

2. Let `position` be the result of running the steps to
 [determine the scroll-into-view
 position](https://drafts.csswg.org/cssom-view-1/#determine-the-scroll-into-view-position) of `target` with `behavior`
 set to \"auto\", `block` set to \"start\",
 `inline` set to \"nearest\", and
 `scrolling box` set to `scrollcontainer`.

3. Set `scrollcontainer`'s [initial scroll
 position](https://drafts.csswg.org/css-overflow-3/#initial-scroll-position) to `position`.

#### 3.1.2. scroll-initial-target Property Definition

Name:

[scroll-initial-target]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) nearest

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[none](#valdef-scroll-initial-target-none)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

none

[none]
: The element is not an [initial scroll
 target](#initial-scroll-target).

[nearest]
: The element is potentially an [initial scroll
 target](#initial-scroll-target) for its nearest [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) ancestor.

#### [3.1.3. ][ Interaction with [place-content](https://drafts.csswg.org/css-align-3/#propdef-place-content)]
If a [scroll
container's](https://drafts.csswg.org/css-overflow-3/#scroll-container) [initial scroll
position](https://drafts.csswg.org/css-overflow-3/#initial-scroll-position) is potentially set by both a [content-distribution
property](https://drafts.csswg.org/css-align-3/#content-distribution-properties) and by
[scroll-initial-target](#propdef-scroll-initial-target) on a descendant,
[scroll-initial-target] wins.

#### 3.1.4. Post-first layout arrivals

While the document is being
[updated](https://html.spec.whatwg.org/multipage/browsing-the-web.html#updating-the-document),
a [scroll
container's](https://drafts.csswg.org/css-overflow-3/#scroll-container) [initial scroll
target](#initial-scroll-target) might arrive after that [scroll
container] has been laid out. If this
happens, user agents should still scroll to the [initial scroll
target] unless the user agent has
reason to believe the user is no longer interested in scrolling to the
[initial scroll
position](https://drafts.csswg.org/css-overflow-3/#initial-scroll-position).

## 4. Styling Snapped Items

The \':snapped\' pseudo-class is being
dropped in favor of a [container state
query](https://drafts.csswg.org/css-contain-4/scroll_state_explainer.html)
approach.

### 4.1. The Snapped-element Pseudo-class: [:snapped]
The [:snapped] pseudo-class matches any [snap
targets](#snap-target), regardless
of axis. The longform physical and logical pseudo-class selectors allow
for more finite snapped children styling as they can target an
individual axis.

More specific options are defined as follows:

[:snapped-x]
: Matches the child snapped on the horizontal axis.

[:snapped-y]
: Matches the child snapped on the vertical axis.

[:snapped-inline]
: Matches the child snapped on the
 [inline](https://drafts.csswg.org/css-display-4/#inline) axis.

[:snapped-block]
: Matches the child snapped on the
 [block](https://drafts.csswg.org/css-display-4/#block) axis.

 [Issue
#6985](https://github.com/w3c/csswg-drafts/issues/6985#issuecomment-1049036401)\
Need to figure out resolution of the initial frame.

## 5. Snap Events

### 5.1. [`scrollsnapchange` and [`scrollsnapchanging`](#eventdef-snapevent-scrollsnapchanging)]
CSS scroll snap points are often used as a mechanism to create scroll
interactive \"selection\" components, where selection is determined with
JavaScript intersection observers and a scroll end guestimate. By
creating a built-in event, the invisible state will become actionable,
at the right time, and always correct.

#### 5.1.1. Snap Targets

A [snap target]
is an element or pseudo-element which the user-agent has
[chosen](https://drafts.csswg.org/css-scroll-snap-1/#choosing) to
[snap](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap) a given [snap
container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container) to.

Event

Interface

Targets

Description

[`scrollsnapchange`]

[`SnapEvent`](#snapevent)

scroll containers

Fired at the scrolling element or
[`Document`](https://dom.spec.whatwg.org/#document) at the end of a scroll (before a
[`scrollend`](https://drafts.csswg.org/cssom-view-1/#eventdef-document-scrollend) event) or after a [layout
snap](https://drafts.csswg.org/css-scroll-snap-1/#re-snap) if the [snap
targets](#snap-target) that the
scrolling element or Document is snapped to changed.

[`scrollsnapchanging`]

[`SnapEvent`](#snapevent)

scroll containers

Fired at the scrolling element or
[`Document`](https://dom.spec.whatwg.org/#document) during scrolling (before a
[`scroll`](https://drafts.csswg.org/cssom-view-1/#eventdef-document-scroll) event), if the [snap
targets](#snap-target) that the
scrolling would cause the scroller to snap to are different from the
[snap targets] selected at the last
scrollsnapchanging event that was fired.

#### 5.1.2. [`scrollsnapchange`]
[`scrollsnapchange`](#eventdef-snapevent-scrollsnapchange) indicates that the snap area to which a snap container
is snapped along either axis has changed.
[`scrollsnapchange`](#eventdef-snapevent-scrollsnapchange) is dispatched:

1. when a scrolling operation is
 [completed](https://drafts.csswg.org/cssom-view-1/#scroll-completed) if, for either the block or inline axis, the [snap
 target](#snap-target) which
 the snap container is snapped to is different from the [snap
 target] it most recently snapped to in that
 axis. For snap containers with
 [proximity](https://drafts.csswg.org/css-scroll-snap-1/#valdef-scroll-snap-type-proximity) strictness, the scroll may result in the
 snap container no longer being snapped to any [snap
 target]. [CSS Scroll Snap 1 § 6.2 Choosing
 Snap
 Positions](https://drafts.csswg.org/css-scroll-snap-1/#choosing)
 describes the method a UA follows when choosing between elements or
 pseudo-elements which are [snap
 areas](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-area).
2. if there is a change to a snap container's style such that it goes
 from having a
 non-[none](https://drafts.csswg.org/css-scroll-snap-1/#valdef-scroll-snap-type-none) value for
 [scroll-snap-type](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-snap-type) to having a
 [none] value or vice
 versa.
3. if, after a [layout
 change](https://drafts.csswg.org/css-scroll-snap-1/#re-snap), the
 [snap target](#snap-target)
 to which a snap container is snapped to changes, regardless of
 whether there is a change in scroll position after the layout
 change.

Scrolling operations always lead to
[`scrollend`](https://drafts.csswg.org/cssom-view-1/#eventdef-document-scrollend) events being fired. If a scrolling operation also
results in a
[`scrollsnapchange`](#eventdef-snapevent-scrollsnapchange) event being fired, the
[`scrollsnapchange`](#eventdef-snapevent-scrollsnapchange) event should be fired before the
[`scrollend`](https://drafts.csswg.org/cssom-view-1/#eventdef-document-scrollend) event.

Each [snap
container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container) has one
[scrollsnapchangeTargetBlock] and one
[scrollsnapchangeTargetInline] in the block and inline axes
respectively, each of which can either be null if the container is not
snapped in that axis or the [snap
target](#snap-target) to which
the container is snapped.

When asked to [update scrollsnapchange
targets] for a [snap
container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container), `snapcontainer`, run these steps:

1. Let `doc` be `snapcontainer`'s associated
 [`Document`](https://dom.spec.whatwg.org/#document).

2. Let `blockTarget` be the
 [scrollsnapchangeTargetBlock](#scrollsnapchangetargetblock) associated with `snapcontainer`.

3. Let `inlineTarget` be the
 [scrollsnapchangeTargetInline](#scrollsnapchangetargetinline) associated with `snapcontainer`.

4. Let `blockScrollSnapchangingTarget` be the
 [scrollsnapchanging block-axis
 target](#scrollsnapchanging-block-axis-target) associated with `snapcontainer`.

5. Let `inlineScrollSnapchangingTarget` be the
 [scrollsnapchanging inline-axis
 target](#scrollsnapchanging-inline-axis-target) associated with `snapcontainer`.

6. Let `snap targets changed` be a boolean flag that is
 initially false.

7. If `blockTarget` is not the same [snap
 target](#snap-target) as
 `blockScrollSnapchangingTarget` or

 1. Set the
 [scrollsnapchangeTargetBlock](#scrollsnapchangetargetblock) associated with `snapcontainer` to
 `blockScrollSnapchangingTarget`.

 2. Set `snap targets changed` to true.

8. If `inlineTarget` is not the same [snap
 target](#snap-target) as
 `inlineScrollSnapchangingTarget`:

 1. Set the
 [scrollsnapchangeTargetInline](#scrollsnapchangetargetinline) associated with `snapcontainer` to
 `inlineScrollSnapchangingTarget`.

 2. Set `snap targets changed` to true.

9. If `snap targets changed` is true:

 1. If (`snapcontainer`, `"scrollsnapchange"`) is not
 already in `doc`'s [pending scroll
 events](https://drafts.csswg.org/cssom-view-1/#document-pending-scroll-events):

 1. Append (`snapcontainer`, `"scrollsnapchange"`) to
 `doc`'s [pending scroll
 events](https://drafts.csswg.org/cssom-view-1/#document-pending-scroll-events).

 When snapping occurs on a scroller (either due to a
layout change or a scrolling operation) the [scrollsnapchanging
block-axis
target](#scrollsnapchanging-block-axis-target) and [scrollsnapchanging inline-axis
target](#scrollsnapchanging-inline-axis-target) associated with that scroller are updated and represent
the current snap targets of that scroller. This allows the [update
scrollsnapchange
targets](#document-update-scrollsnapchange-targets) algorithm to use these [snap
targets](#snap-target) to
determine whether a
[`scrollsnapchange`](#eventdef-snapevent-scrollsnapchange) event should be fired.

#### 5.1.3. scrollsnapchanging

[`scrollsnapchanging`](#eventdef-snapevent-scrollsnapchanging) is dispatched:

- during a scrolling operation, if the [snap
 targets](#snap-target) to
 which a [snap
 container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container) would
 [snap](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap) (in either axis) changes, or

- if a [layout
 change](https://drafts.csswg.org/css-scroll-snap-1/#re-snap) occurs
 such that a
 [`scrollsnapchange`](#eventdef-snapevent-scrollsnapchange) event is to be dispatched. In this case, as with the
 scrolling case, the
 [`scrollsnapchanging`](#eventdef-snapevent-scrollsnapchanging) event should be dispatched before the
 [`scrollsnapchange`](#eventdef-snapevent-scrollsnapchange) event.

A scrolling operation might animate towards a particular position (e.g.
scrollbar arrow clicks, arrow key presses, \"behavior: smooth\"
programmatic scrolls) or might directly track a user's input (e.g. touch
scrolling, scrollbar dragging). In either case, the user agent
[chooses](https://drafts.csswg.org/css-scroll-snap-1/#choosing) an
[eventual snap target] in each axis to which the scroller will
[snap](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap) after the scrolling operation reaches its intended
scroll position.

- In the former case, the intended scroll position is the scroll
 animation's target scroll offset.

- In the latter case, the intended scroll position is the current scroll
 offset as determined by the user's input.

[`scrollsnapchanging`](#eventdef-snapevent-scrollsnapchanging) aims to let the web page know, as early as possible,
that the scrolling operation will result in a change in the [snap
target](#snap-target) the snap
container is snapped to. The user agent should evaluate whether to
trigger
[`scrollsnapchanging`](#eventdef-snapevent-scrollsnapchanging) based on the [eventual snap
target](#eventual-snap-target) to which the scroller would
[snap](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap) were the scrolling operation to reach its intended
scroll position.

 Since scrollsnapchanging gives the web page hints about
future snapping, the snapping hinted at by a scrollsnapchanging event
might not materialize since it will be possible for subsequent scrolling
input to further alter the snap container's scroll position and result
in a different eventual snap target.

Each [snap
container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container) has one [scrollsnapchanging block-axis
target] and one [scrollsnapchanging inline-axis
target] in the block and inline axes respectively,
each of which can either be null if the container is not snapping in
that axis or the [snap target](#snap-target) to which the container is snapping.

When asked to [update scrollsnapchanging
targets] for a [snap
container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container), `snapcontainer`, given an [snap
target](#snap-target)
newBlockTarget and an [snap target]
newInlineTarget, run these steps:

1. Let `doc` be `snapcontainer`'s associated
 [`Document`](https://dom.spec.whatwg.org/#document).

2. Let `blockTarget` be the [scrollsnapchanging block-axis
 target](#scrollsnapchanging-block-axis-target) that is associated with `snapcontainer`.

3. Let `inlineTarget` be the [scrollsnapchanging inline-axis
 target](#scrollsnapchanging-inline-axis-target) that is associated with `snapcontainer`.

4. If `newBlockTarget` is not the same [snap
 target](#snap-target) as
 `blockTarget`:

 1. Set the [scrollsnapchanging block-axis
 target](#scrollsnapchanging-block-axis-target) associated with `snapcontainer` to
 `newBlockTarget`.

 2. If (`snapcontainer`, `"scrollsnapchanging"`) is not
 already in `doc`'s [pending scroll
 events](https://drafts.csswg.org/cssom-view-1/#document-pending-scroll-events),

 1. Append (`snapcontainer`, `"scrollsnapchanging"`)
 to `doc`'s [pending scroll
 events](https://drafts.csswg.org/cssom-view-1/#document-pending-scroll-events)

5. If `newInlineTarget` is not the same [snap
 target](#snap-target) as
 `inlineTarget`:

 1. Set the [scrollsnapchanging inline-axis
 target](#scrollsnapchanging-inline-axis-target) associated with `snapcontainer` to
 `newInlineTarget`.

 2. If (`snapcontainer`, `"scrollsnapchanging"`) is not
 already in `doc`'s [pending scroll
 events](https://drafts.csswg.org/cssom-view-1/#document-pending-scroll-events),

 1. Append (`snapcontainer`, `"scrollsnapchanging"`)
 to `doc`'s [pending scroll
 events](https://drafts.csswg.org/cssom-view-1/#document-pending-scroll-events)

#### 5.1.4. Snap Events due to Layout Changes

When a [snap
container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container), `snapcontainer`,
[re-snaps](https://drafts.csswg.org/css-scroll-snap-1/#re-snap), run
these steps:

1. Let `newBlockTarget` be the [snap
 target](#snap-target) that
 `snapcontainer` has
 [snapped](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap) to in the block axis or null if it did not snap to
 any element.

2. Let `newInlineTarget` be the [snap
 target](#snap-target) that
 `snapcontainer` has
 [snapped](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap) to in the inline axis or null if it did not snap to
 any element or pseudo-element.

3. Run the steps to [update scrollsnapchanging
 targets](#document-update-scrollsnapchanging-targets) with `newBlockTarget` as newBlockTarget
 and `newInlineTarget` as newInlineTarget.

4. Run the steps to [update scrollsnapchange
 targets](#document-update-scrollsnapchange-targets) for `snapcontainer`.

### 5.2. SnapEvent interface

```
dictionary SnapEventInit : EventInit {
 Node? snapTargetBlock;
 Node? snapTargetInline;
};

[Exposed=Window]
interface SnapEvent : Event {
 constructor(DOMString type, optional SnapEventInit eventInitDict = );
 readonly attribute Node? snapTargetBlock;
 readonly attribute Node? snapTargetInline;
};
```

[`snapTargetBlock`], of type [Node](https://dom.spec.whatwg.org/#node), readonly, nullable

: The element that the snap container is snapped to in the block axis
 at the [snap
 position](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-position) for the associated snap event. If the [snap
 target](#snap-target)
 corresponding to this was a pseudo-element, this will be the owning
 element of that pseudo-element.

[`snapTargetInline`], of type [Node](https://dom.spec.whatwg.org/#node), readonly, nullable

: The element that the snap container is snapped to in the inline axis
 at the [snap
 position](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-position) for the associated snap event. If the [snap
 target](#snap-target)
 corresponding to this was a pseudo-element, this will be the owning
 element of that pseudo-element.

For
[`scrollsnapchange`](#eventdef-snapevent-scrollsnapchange) events, the snap position is the position already
realized by the snap container after a scroll snap. For
[`scrollsnapchanging`](#eventdef-snapevent-scrollsnapchanging) events it is the snap position that the snap container
will eventually snap to when the scrolling operation ends.

[`SnapEvent`](#snapevent)s do
not bubble except when the event target is the
[`Document`](https://dom.spec.whatwg.org/#document). [`SnapEvent`](#snapevent)s are not cancellable.

## [Appendix A: Event Handlers]
This section should be moved to the HTML
event handler
[specification](https://html.spec.whatwg.org/#event-handlers-on-elements,-document-objects,-and-window-objects).

### [Event handlers on elements, Document objects and Window objects]
The following are additional [event
handlers](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers) (and their corresponding [event handler event
types](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)) that must be supported by all [HTML
elements](https://html.spec.whatwg.org/multipage/infrastructure.html#html-elements) as both [event handler content
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-content-attributes) and [event handler IDL
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes); and that must be supported by all
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) objects and
[`Document`](https://dom.spec.whatwg.org/#document) objects, as [event handler IDL
attributes]:

[Event
handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers)

[Event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)

[`onscrollsnapchange`]

[`scrollsnapchange`](#eventdef-snapevent-scrollsnapchange)

[`onscrollsnapchanging`]

[`scrollsnapchanging`](#eventdef-snapevent-scrollsnapchanging)

### [Extensions to the `GlobalEventHandlers` Interface Mixin]
This specification extends the
[`GlobalEventHandlers`](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers) interface mixin from HTML to add [event handler IDL
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) for [`SnapEvent`](#snapevent)s as defined in [Event handlers on elements, Document
objects and Window
objects](#event-handlers-on-elements-document-and-window-objects).

#### [IDL Definition]
```
partial interface mixin GlobalEventHandlers {
 attribute EventHandler onsnapchanged;
 attribute EventHandler onsnapchanging;
};
```

## 6. Privacy Considerations

The features in this spec have no known privacy implications.

## 7. Security Considerations

The features in this spec have no known security implications.
