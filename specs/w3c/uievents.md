
## 1. Introduction

### 1.1. Overview

UI Events is designed with two main goals. The first goal is the design
of an
[event](https://dom.spec.whatwg.org/#concept-event) system which allows registration of [event
listeners](https://dom.spec.whatwg.org/#concept-event-listener) and describes event flow through a tree structure.
Additionally, the specification will provide standard modules of events
for user interface control and document mutation notifications,
including defined contextual information for each of these event
modules.

The second goal of UI Events is to provide a common subset of the
current event systems used in existing browsers. This is intended to
foster interoperability of existing scripts and content. It is not
expected that this goal will be met with full backwards compatibility.
However, the specification attempts to achieve this when possible.

#### 1.1.1. Mouse and Wheel Events

The Mouse Events and Wheel Events section of this specification have
been moved to the Pointer Events specification
[\[pointerevents4\]](#biblio-pointerevents4 "Pointer Events").

### 1.2. Conformance

**This section is normative.**

Within this specification, the key words "MUST", "MUST NOT", "REQUIRED",
"SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and
"OPTIONAL" are to be interpreted as described in
[\[RFC2119\]](#biblio-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels").

This specification is to be understood in the context of the DOM Level 3
Core specification
[\[DOM-Level-3-Core\]](#biblio-dom-level-3-core "Document Object Model (DOM) Level 3 Core Specification")
and the general considerations for DOM implementations apply. For
example, handling of [namespace
URIs](#namespace-uris) is
discussed in [*XML
Namespaces*](http://www.w3.org/TR/DOM-Level-3-Core/core.html#Namespaces-Considerations).
For additional information about
[*conformance*](http://www.w3.org/TR/DOM-Level-3-Core/introduction.html#ID-Conformance),
please see the DOM Level 3 Core specification
[\[DOM-Level-3-Core\]](#biblio-dom-level-3-core "Document Object Model (DOM) Level 3 Core Specification").
A [user
agent](https://infra.spec.whatwg.org/#user-agent) is not required to conform to the entirety of another
specification in order to conform to this specification, but it MUST
conform to the specific parts of any other specification which are
called out in this specification (e.g., a conforming UI Events [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST support the `DOMString` data type as defined in
[\[WebIDL\]](#biblio-webidl "Web IDL Standard"), but
need not support every method or data type defined in
[\[WebIDL\]](#biblio-webidl "Web IDL Standard") in
order to conform to UI Events).

This specification defines several classes of conformance for different
[user
agents](https://infra.spec.whatwg.org/#user-agent), specifications, and content authors:

#### [1.2.1. ][Web browsers and other dynamic or interactive [user agents](https://infra.spec.whatwg.org/#user-agent)]
A dynamic or interactive [user
agent](https://infra.spec.whatwg.org/#user-agent), referred to here as a "browser" (be it a Web browser,
AT (Accessibility Technology) application, or other similar program),
conforms to UI Events if it supports:

- the Core module defined in
 [\[DOM-Level-3-Core\]](#biblio-dom-level-3-core "Document Object Model (DOM) Level 3 Core Specification")

- all the interfaces and events with their associated methods,
 attributes, and semantics defined in this specification with the
 exception of those marked as
 [deprecated](#deprecates) (a
 conforming user agent MAY implement the deprecated interfaces, events,
 or APIs for backwards compatibility, but is not required to do so in
 order to be conforming)

- the complete set of `key` and `code` values defined in
 [\[UIEvents-Key\]](#biblio-uievents-key "UI Events KeyboardEvent key Values")
 and
 [\[UIEvents-Code\]](#biblio-uievents-code "UI Events KeyboardEvent code Values")
 (subject to platform availability), and

- all other normative requirements defined in this specification.

A conforming browser MUST
[dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch) events appropriate to the given
[`EventTarget`](https://dom.spec.whatwg.org/#eventtarget) when the conditions defined for that [event
type](#event-type) have been met.

A browser conforms specifically to UI Events if it implements the
interfaces and related [event types](#event-type) specified in this document.

A conforming browser MUST support scripting, declarative interactivity,
or some other means of detecting and dispatching events in the manner
described by this specification, and MUST support the APIs specified for
that [event type](#event-type).

In addition to meeting all other conformance criteria, a conforming
browser MAY implement features of this specification marked as
[deprecated](#deprecates), for
backwards compatibility with existing content, but such implementation
is discouraged.

A conforming browser MAY also support features not found in this
specification, but which use the interfaces, events, or other features
defined in this specification, and MAY implement additional interfaces
and [event types](#event-type)
appropriate to that implementation. Such features can be later
standardized in future specifications.

A browser which does not conform to all required portions of this
specification MUST NOT claim conformance to UI Events. Such an
implementation which does conform to portions of this specification MAY
claim conformance to those specific portions.

A conforming browser MUST also be a *conforming implementation* of the
IDL fragments in this specification, as described in the Web IDL
specification
[\[WebIDL\]](#biblio-webidl "Web IDL Standard").

#### 1.2.2. Authoring tools

A content authoring tool conforms to UI Events if it produces content
which uses the [event types](#event-type), consistent in a manner as defined in this
specification.

A content authoring tool MUST NOT claim conformance to UI Events for
content it produces which uses features of this specification marked as
[deprecated](#deprecates) in this
specification.

A conforming content authoring tool SHOULD provide to the content author
a means to use all [event types](#event-type) and interfaces appropriate to all [host
languages](#host-language) in
the content document being produced.

#### 1.2.3. Content authors and content

A content [author](#author) creates
conforming UI Events content if that content uses the [event
types](#event-type) consistent in
a manner as defined in this specification.

A content author SHOULD NOT use features of this specification marked as
[deprecated](#deprecates), but
SHOULD rely instead upon replacement mechanisms defined in this
specification and elsewhere.

Conforming content MUST use the semantics of the interfaces and [event
types](#event-type) as described
in this specification.

Content authors are advised to follow best practices as described in
[accessibility](http://www.w3.org/TR/WAI-WEBCONTENT/) and
[internationalization](http://www.w3.org/standards/techs/i18n) guideline
specifications.

#### 1.2.4. Specifications and host languages

A specification or [host
language](#host-language)
conforms to UI Events if it references and uses the event flow
mechanism, interfaces, events, or other features defined in
[\[DOM\]](#biblio-dom "DOM Standard"), and does not
extend these features in incompatible ways.

A specification or [host
language](#host-language)
conforms specifically to UI Events if it references and uses the
interfaces and related [event types](#event-type) specified in this document. A conforming specification
MAY define additional interfaces and [event
types](#event-type) appropriate to
that specification, or MAY extend the UI Events interfaces and [event
types](#event-type) in a manner
that does not contradict or conflict with the definitions of those
interfaces and [event types](#event-type) in this specification.

Specifications or [host
languages](#host-language)
which reference UI Events SHOULD NOT use or recommend features of this
specification marked as [deprecated](#deprecates), but SHOULD use or recommend the indicated replacement
for that the feature (if available).

## 2. Stylistic Conventions

This specification follows the [Proposed W3C Specification
Conventions](http://www.w3.org/People/Schepers/spec-conventions.html),
with the following supplemental additions:

- The [*key cap*](#key-legends) printed on a key is shown as
 `↓`, `=` or `Q`. This is used to refer to a
 key from the user's perspective without regard for the
 [`key`](#dom-keyboardevent-key) and
 [`code`](#dom-keyboardevent-code) values in the generated
 [`KeyboardEvent`](#keyboardevent).

- Glyphs representing character are shown as: `"𣧂"`.

- Unicode character encodings are shown as: `U+003d`.

- Names of key values generated by a key press (i.e., the value of
 [`KeyboardEvent`](#keyboardevent).[`key`](#dom-keyboardevent-key)) are shown as:
 `"`[`ArrowDown`](http://www.w3.org/TR/uievents-key/#key-ArrowDown)`"`,
 `"="`, `"q"` or `"Q"`.

- Names of key codes associated with the physical keys (i.e., the value
 of [`KeyboardEvent`](#keyboardevent).[`code`](#dom-keyboardevent-code)) are shown as:
 `"`[`ArrowDown`](http://www.w3.org/TR/uievents-code/#code-ArrowDown)`"`,
 `"`[`Equal`](http://www.w3.org/TR/uievents-code/#code-Equal)`"`
 or
 `"`[`KeyQ`](http://www.w3.org/TR/uievents-code/#code-KeyQ)`"`.

In addition, certain terms are used in this specification with
particular meanings. The term "implementation" applies to a browser,
content authoring tool, or other [user
agent](https://infra.spec.whatwg.org/#user-agent) that implements this specification, while a content
author is a person who writes script or code that takes advantage of the
interfaces, methods, attributes, events, and other features described in
this specification in order to make Web applications, and a user is the
person who uses those Web applications in an implementation.

And finally:

This is a note.

This is an open issue.

This is a warning.

```
interface Example {
 // This is an IDL definition.
};
```

## 3. Basic Event Interfaces

The basic event interfaces defined in
[\[DOM\]](#biblio-dom "DOM Standard") are
fundamental to UI Events. These basic event interfaces MUST always be
supported by the implementation:

- The [`Event`](https://dom.spec.whatwg.org/#event) interface and its following constants, methods and
 attributes:

 - [`NONE`](https://dom.spec.whatwg.org/#dom-event-none) constant

 - [`CAPTURING_PHASE`](https://dom.spec.whatwg.org/#dom-event-capturing_phase) constant

 - [`AT_TARGET`](https://dom.spec.whatwg.org/#dom-event-at_target) constant

 - [`BUBBLING_PHASE`](https://dom.spec.whatwg.org/#dom-event-bubbling_phase) constant

 - [`type`](https://dom.spec.whatwg.org/#dom-event-type) attribute

 - [`target`](https://dom.spec.whatwg.org/#dom-event-target) attribute

 - [`currentTarget`](https://dom.spec.whatwg.org/#dom-event-currenttarget) attribute

 - [`eventPhase`](https://dom.spec.whatwg.org/#dom-event-eventphase) attribute

 - [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) attribute

 - [`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable) attribute

 - [`composed`](https://dom.spec.whatwg.org/#dom-event-composed) attribute

 - [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp) attribute

 - [`defaultPrevented`](https://dom.spec.whatwg.org/#dom-event-defaultprevented) attribute

 - [`isTrusted`](https://dom.spec.whatwg.org/#dom-event-istrusted) attribute

 - [`stopPropagation()`](https://dom.spec.whatwg.org/#dom-event-stoppropagation) method

 - [`stopImmediatePropagation()`](https://dom.spec.whatwg.org/#dom-event-stopimmediatepropagation) method

 - [`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) method

 - [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent) method

- The
 [`CustomEvent`](https://dom.spec.whatwg.org/#customevent) interface and its following method and attribute:

 - [`initCustomEvent()`](https://dom.spec.whatwg.org/#dom-customevent-initcustomevent) method

 - [`detail`](https://dom.spec.whatwg.org/#dom-customevent-detail) attribute

- The
 [`EventTarget`](https://dom.spec.whatwg.org/#eventtarget) interface and its following methods:

 - [`addEventListener()`](https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener) method

 - [`removeEventListener()`](https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener) method

 - [`dispatchEvent()`](https://dom.spec.whatwg.org/#dom-eventtarget-dispatchevent) method

- The
 [`EventListener`](https://dom.spec.whatwg.org/#callbackdef-eventlistener) interface and its
 [`handleEvent()`](https://dom.spec.whatwg.org/#dom-eventlistener-handleevent) method

- The
 [`Document`](https://dom.spec.whatwg.org/#document) interface's
 [`createEvent()`](https://dom.spec.whatwg.org/#dom-document-createevent) method

The event types defined in this specification derive from these basic
interfaces, and MUST inherit all of the attributes, methods, and
constants of the interfaces they derive from.

The following chart describes the inheritance structure of the
interfaces described in this specification.

![Graphical representation of inheritance of interfaces defined by this
specification](images/event-inheritance.svg)

### 3.1. List of Event Types

Each event MUST be associated with a type, called *event type* and
available as the
[`type`](https://dom.spec.whatwg.org/#dom-event-type) attribute on the event object. The event type MUST be
of type `DOMString`.

Depending on the level of DOM support, or the devices used for display
(e.g., screen) or interaction (e.g., mouse, keyboard, touch screen, or
voice), these event types can be generated by the implementation. When
used with an
[\[XML\]](#biblio-xml "Extensible Markup Language (XML) 1.0 (Fifth Edition)")
or [\[HTML5\]](#biblio-html5 "HTML5") application,
the specifications of those languages MAY restrict the semantics and
scope (in particular the possible [event
targets](#event-target))
associated with an event type. Refer to the specification defining the
language used in order to find those restrictions or to find event types
that are not defined in this document.

The following table provides an informative summary of the event types
described in this specification.

Event Type

Sync / Async

Bubbling Phase

Trusted event target types

DOM Interface

Cancelable

Default Action

[`abort`](#abort)

Sync

No

[Window](https://drafts.csswg.org/css-color-3/#window), Element

[`Event`](https://dom.spec.whatwg.org/#event)

No

None

[`beforeinput`](#beforeinput)

Sync

Yes

Element

[`InputEvent`](#inputevent)

Yes

Update the DOM element

[`blur`](#blur)

Sync

No

[Window](https://drafts.csswg.org/css-color-3/#window), Element

[`FocusEvent`](#focusevent)

No

None

[`compositionstart`](#compositionstart)

Sync

Yes

Element

[`CompositionEvent`](#compositionevent)

Yes

Show a [text composition
system](#text-composition-system) candidate window

[`compositionupdate`](#compositionupdate)

Sync

Yes

Element

[`CompositionEvent`](#compositionevent)

No

None

[`compositionend`](#compositionend)

Sync

Yes

Element

[`CompositionEvent`](#compositionevent)

No

None

[`error`](#error)

Async

No

[Window](https://drafts.csswg.org/css-color-3/#window), Element

[`Event`](https://dom.spec.whatwg.org/#event)

No

None

[`focus`](#focus)

Sync

No

[Window](https://drafts.csswg.org/css-color-3/#window), Element

[`FocusEvent`](#focusevent)

No

None

[`focusin`](#focusin)

Sync

Yes

[Window](https://drafts.csswg.org/css-color-3/#window), Element

[`FocusEvent`](#focusevent)

No

None

[`focusout`](#focusout)

Sync

Yes

[Window](https://drafts.csswg.org/css-color-3/#window), Element

[`FocusEvent`](#focusevent)

No

None

[`input`](#input)

Sync

Yes

Element

[`InputEvent`](#inputevent)

No

None

[`keydown`](#keydown)

Sync

Yes

Element

[`KeyboardEvent`](#keyboardevent)

Yes

Varies: trigger [`beforeinput`](#beforeinput) and [`input`](#input)
events; launch [text composition
system](#text-composition-system); [`blur`](#blur) and
[`focus`](#focus) events;
[`keypress`](#keypress) event (if
supported); [activation
behavior](https://dom.spec.whatwg.org/#eventtarget-activation-behavior); other events

[`keyup`](#keyup)

Sync

Yes

Element

[`KeyboardEvent`](#keyboardevent)

Yes

None

[`load`](#load)

Async

No

[Window](https://drafts.csswg.org/css-color-3/#window), Document, Element

[`Event`](https://dom.spec.whatwg.org/#event)

No

None

[`select`](#select)

Sync

Yes

Element

[`Event`](https://dom.spec.whatwg.org/#event)

No

None

[`unload`](#unload)

Sync

No

[Window](https://drafts.csswg.org/css-color-3/#window), Document, Element

[`Event`](https://dom.spec.whatwg.org/#event)

No

None

For a list of events which are deprecated in this specification, see the
[Legacy Event Types](#legacy-event-types) appendix at the end of this
document.

The following is one way to interpret
the above tables: the [`load`](#load)
event will trigger [event
listeners](https://dom.spec.whatwg.org/#concept-event-listener) attached on `Element` nodes for that event and on the
capture and target phases. This event is not cancelable. If an [event
listener](https://dom.spec.whatwg.org/#concept-event-listener) for the [`load`](#load)
event is attached to a node other than
[Window](https://drafts.csswg.org/css-color-3/#window), `Document`, or `Element` nodes, or if it is attached
to the bubbling phase only, this [event
listener](https://dom.spec.whatwg.org/#concept-event-listener) would not be triggered.

Don't interpret the above tables as definitive for the listed event
types. For example, the [`load`](#load)
event is used in other specifications, for example, in XMLHttpRequest.
Similarly,
[`dispatchEvent()`](https://dom.spec.whatwg.org/#dom-eventtarget-dispatchevent) can be used to dispatch untrusted events to listeners
on **any** object that also implements
[`EventTarget`](https://dom.spec.whatwg.org/#eventtarget).

The event objects associated with the event types described above
contain additional context information\--refer to the description of the
DOM interfaces for further information.

### 3.2. User Interface Events

The User Interface event module contains basic event types associated
with user interfaces and document manipulation.

#### 3.2.1. Interface UIEvent

Introduced in DOM Level 2

The [`UIEvent`](#uievent)
interface provides specific contextual information associated with User
Interface events.

To create an instance of the
[`UIEvent`](#uievent)
interface, use the UIEvent constructor, passing an optional
[`UIEventInit`](#dictdef-uieventinit) dictionary.

For newly defined events, you don't have to inherit
[`UIEvent`](#uievent) interface
just because they are related to user interface. Inherit only when
members of
[`UIEventInit`](#dictdef-uieventinit) make sense to those events.

##### 3.2.1.1. UIEvent

```
[Exposed=Window]
interface UIEvent : Event {
 constructor(DOMString type, optional UIEventInit eventInitDict = );
 readonly attribute Window? view;
 readonly attribute long detail;
};
```

`UIEvent . view`

: The `view` attribute identifies the `Window` from which the event
 was generated.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `null`.

`UIEvent . detail`

: Specifies some detail information about the
 [`Event`](https://dom.spec.whatwg.org/#event), depending on the type of event.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `0`.

##### 3.2.1.2. UIEventInit

```
dictionary UIEventInit : EventInit {
 Window? view = null;
 long detail = 0;
};
```

`UIEventInit . view`
: Should be initialized to the Window object of the global environment
 in which this event will be dispatched. If this event will be
 dispatched to an element, the view property should be set to the
 Window object containing the element's `ownerDocument`.

`UIEventInit . detail`
: This value is initialized to a number that is application-specific.

#### 3.2.2. UIEvent Algorithms

##### [3.2.2.1. ][[initialize a UIEvent]]
Input

: `event`, the
 [`UIEvent`](#uievent) to
 initialize

: `eventType`, a DOMString containing the event type

: `eventTarget`, the
 [`EventTarget`](https://dom.spec.whatwg.org/#eventtarget) of the event

: `bubbles`, true if this event bubbles

: `cancelable`, true if this event is cancelable

Output

: None

1. Initialize the base
 [`Event`](https://dom.spec.whatwg.org/#event) attributes:

 1. [Initialize an
 Event](https://dom.spec.whatwg.org/#concept-event-initialize) with `event`,
 `eventType`, `bubbles` and
 `cancelable`

 2. Set
 `event`.[`target`](https://dom.spec.whatwg.org/#dom-event-target) = `eventTarget`

2. Initialize the following public attributes:

 1. Set
 `event`.[`view`](#dom-uievent-view) = the `eventTarget`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object

 2. Set
 `event`.[`detail`](#dom-uievent-detail) = 0

3. Initialize the following historical attributes:

 1. Set
 `event`.[`which`](#dom-uievent-which) = 0 (used by both
 [`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) and
 [`KeyboardEvent`](#keyboardevent))

#### 3.2.3. UIEvent Types

The User Interface event types are listed below. Some of these events
use the [`UIEvent`](#uievent)
interface if generated from a user interface, but the
[`Event`](https://dom.spec.whatwg.org/#event) interface otherwise, as detailed in each event.

##### [3.2.3.1. ][[load]]
Type

**`load`**

Interface

[`UIEvent`](#uievent) if
generated from a user interface,
[`Event`](https://dom.spec.whatwg.org/#event) otherwise.

Sync / Async

Async

Bubbles

No

Trusted Targets

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Document`, `Element`

Cancelable

No

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : common object whose contained resources have loaded
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when the DOM implementation
finishes loading the resource (such as the document) and any dependent
resources (such as images, style sheets, or scripts). Dependent
resources that fail to load MUST NOT prevent this event from firing if
the resource that loaded them is still accessible via the DOM. If this
event type is dispatched, implementations are REQUIRED to dispatch this
event at least on the `Document` node.

For legacy reasons, [`load`](#load)
events for resources inside the document (e.g., images) do not include
the
[Window](https://drafts.csswg.org/css-color-3/#window) in the propagation path in HTML implementations. See
[\[HTML5\]](#biblio-html5 "HTML5") for more
information.

##### [3.2.3.2. ][[unload]]
Type

**`unload`**

Interface

[`UIEvent`](#uievent) if
generated from a user interface,
[`Event`](https://dom.spec.whatwg.org/#event) otherwise.

Sync / Async

Sync

Bubbles

No

Trusted Targets

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Document`, `Element`

Cancelable

No

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : common object whose contained resources have been
 removed
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when the DOM Implementation
removes from the environment the resource (such as the document) or any
dependent resources (such as images, style sheets, scripts). The
document MUST be unloaded after the dispatch of this event type. If this
event type is dispatched, implementations are REQUIRED to dispatch this
event at least on the `Document` node.

##### [3.2.3.3. ][[abort]]
Type

**`abort`**

Interface

[`UIEvent`](#uievent) if
generated from a user interface,
[`Event`](https://dom.spec.whatwg.org/#event) otherwise.

Sync / Async

Sync

Bubbles

No

Trusted Targets

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Element`

Cancelable

No

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : element whose resources have been stopped from
 loading without error
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when the loading of a resource
has been aborted, such as by a user canceling the load while it is still
in progress.

##### [3.2.3.4. ][[error]]
Type

**`error`**

Interface

[`UIEvent`](#uievent) if
generated from a user interface,
[`Event`](https://dom.spec.whatwg.org/#event) otherwise.

Sync / Async

Async

Bubbles

No

Trusted Targets

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Element`

Cancelable

No

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : element whose resources have been stopped from
 loading due to error
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when a resource failed to
load, or has been loaded but cannot be interpreted according to its
semantics, such as an invalid image, a script execution error, or
non-well-formed XML.

##### [3.2.3.5. ][[select]]
Type

**`select`**

Interface

[`UIEvent`](#uievent) if
generated from a user interface,
[`Event`](https://dom.spec.whatwg.org/#event) otherwise.

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

`Element`

Cancelable

No

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : element whose text content has been selected
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when a user selects some text.
This event is dispatched after the selection has occurred.

This specification does not provide contextual information to access the
selected text. Where applicable, a [host
language](#host-language)
SHOULD define rules for how a user MAY select content (with
consideration for international language conventions), at what point the
[`select`](#select) event is
dispatched, and how a content author MAY access the user-selected
content.

In order to access to user-selected content, content authors will use
native capabilities of the [host
languages](#host-language),
such as the `Document.getSelection()` method of the HTML Editing APIs
[\[Editing\]](#biblio-editing "HTML Editing APIs").

The [`select`](#select) event might
not be available for all elements in all languages. For example, in
[\[HTML5\]](#biblio-html5 "HTML5"),
[`select`](#select) events can be
dispatched only on form
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) and
[`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element) elements. Implementations can dispatch
[`select`](#select) events in any
context deemed appropriate, including text selections outside of form
controls, or image or markup selections such as in SVG.

### 3.3. Focus Events

This interface and its associated event types and [§ 3.3.2 Focus Event
Order](#events-focusevent-event-order) were designed in accordance to
the concepts and guidelines defined in [User Agent Accessibility
Guidelines 2.0](http://www.w3.org/WAI/UA/2010/ED-UAAG20-20100308/)
[\[UAAG20\]](#biblio-uaag20 "User Agent Accessibility Guidelines (UAAG) 2.0"),
with particular attention on the [focus
mechanism](http://www.w3.org/WAI/UA/2010/ED-UAAG20-20100308/#gl-focus-mechanism)
and the terms defined in the [glossary entry for
focus](http://www.w3.org/WAI/UA/2010/ED-UAAG20-20100308/#def-focus).

#### 3.3.1. Interface FocusEvent

Introduced in this specification

The [`FocusEvent`](#focusevent) interface provides specific contextual information
associated with Focus events.

To create an instance of the
[`FocusEvent`](#focusevent)
interface, use the FocusEvent constructor, passing an optional
[`FocusEventInit`](#dictdef-focuseventinit) dictionary.

##### 3.3.1.1. FocusEvent

```
[Exposed=Window]
interface FocusEvent : UIEvent {
 constructor(DOMString type, optional FocusEventInit eventInitDict = );
 readonly attribute EventTarget? relatedTarget;
};
```

`FocusEvent . relatedTarget`

: Used to identify a secondary
 [`EventTarget`](https://dom.spec.whatwg.org/#eventtarget) related to a Focus event, depending on the type of
 event.

 For security reasons with nested browsing contexts, when tabbing
 into or out of a nested context, the relevant
 [`EventTarget`](https://dom.spec.whatwg.org/#eventtarget) SHOULD be `null`.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `null`.

##### 3.3.1.2. FocusEventInit

```
dictionary FocusEventInit : UIEventInit {
 EventTarget? relatedTarget = null;
};
```

`FocusEventInit . relatedTarget`
: The
 [`relatedTarget`](#dom-focuseventinit-relatedtarget) should be initialized to the element losing focus
 (in the case of a [`focus`](#focus)
 or [`focusin`](#focusin) event)
 or the element gaining focus (in the case of a
 [`blur`](#blur) or
 [`focusout`](#focusout) event).

#### 3.3.2. Focus Event Order

The focus events defined in this specification occur in a set order
relative to one another. The following is the typical sequence of events
when a focus is shifted between elements (this order assumes that no
element is initially focused):

Event Type

Notes

*User shifts focus*

1

[`focus`](#focus)

Sent after first target element receives focus

2

[`focusin`](#focusin)

Follows the focus event

*User shifts focus*

3

[`blur`](#blur)

Sent after first target element loses focus

4

[`focusout`](#focusout)

Follows the blur event

5

[`focus`](#focus)

Sent after second target element receives focus

6

[`focusin`](#focusin)

Follows the focus event

This specification does not define the behavior of focus events when
interacting with methods such as `focus()` or `blur()`. See the relevant
specifications where those methods are defined for such behavior.

#### 3.3.3. Document Focus and Focus Context

This event module includes event types for notification of changes in
document [focus](#focus). There are
three distinct focus contexts that are relevant to this discussion:

- The *operating system focus context* which MAY be on one of many
 different applications currently running on the computer. One of these
 applications with focus can be a browser.

- When the browser has focus, the user can switch (such as with the tab
 key) the *application focus context* among the different browser user
 interface fields (e.g., the Web site location bar, a search field,
 etc.). One of these user interface fields can be the document being
 shown in a tab.

- When the document itself has focus, the *document focus context* can
 be set to any of the focusable elements in the document.

The event types defined in this specification deal exclusively with
document focus, and the [event
target](#event-target)
identified in the event details MUST only be part of the document or
documents in the window, never a part of the browser or operating
system, even when switching from one focus context to another.

Normally, a document always has a focused element (even if it is the
document element itself) and a persistent [focus
ring](#focus-ring). When switching
between focus contexts, the document's currently focused element and
focus ring normally remain in their current state. For example, if a
document has three focusable elements, with the second element focused,
when a user changes operating system focus to another application and
then back to the browser, the second element will still be focused
within the document, and tabbing will change the focus to the third
element. A [host language](#host-language) MAY define specific elements which might receive focus,
the conditions under which an element MAY receive focus, the means by
which focus MAY be changed, and the order in which the focus changes.
For example, in some cases an element might be given focus by moving a
pointer over it, while other circumstances might require a mouse click.
Some elements might not be focusable at all, and some might be focusable
only by special means (clicking on the element), but not by tabbing to
it. Documents MAY contain multiple focus rings. Other specifications MAY
define a more complex focus model than is described in this
specification, including allowing multiple elements to have the current
focus.

#### 3.3.4. Focus Event Types

The Focus event types are listed below.

##### [3.3.4.1. ][[blur]]
Type

**`blur`**

Interface

[`FocusEvent`](#focusevent)

Sync / Async

Sync

Bubbles

No

Trusted Targets

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Element`

Cancelable

No

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [event
 target](#event-target) losing
 focus
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`FocusEvent`](#focusevent).[`relatedTarget`](#dom-focusevent-relatedtarget) : [event
 target](#event-target)
 receiving focus.

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when an [event
target](#event-target) loses
focus. The focus MUST be taken from the element before the dispatch of
this event type. This event type is similar to
[focusout](#focusout), but does not
bubble.

##### [3.3.4.2. ][[focus]]
Type

**`focus`**

Interface

[`FocusEvent`](#focusevent)

Sync / Async

Sync

Bubbles

No

Trusted Targets

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Element`

Cancelable

No

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [event
 target](#event-target)
 receiving focus
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`FocusEvent`](#focusevent).[`relatedTarget`](#dom-focusevent-relatedtarget) : [event
 target](#event-target) losing
 focus (if any).

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when an [event
target](#event-target) receives
focus. The focus MUST be given to the element before the dispatch of
this event type. This event type is similar to
[focusin](#focusin), but does not
bubble.

##### [3.3.4.3. ][[focusin]]
Type

**`focusin`**

Interface

[`FocusEvent`](#focusevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Element`

Cancelable

No

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [event
 target](#event-target)
 receiving focus
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`FocusEvent`](#focusevent).[`relatedTarget`](#dom-focusevent-relatedtarget) : [event
 target](#event-target) losing
 focus (if any).

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when an [event
target](#event-target) receives
focus. The [event target](#event-target) MUST be the element which received focus. The
[focus](#focus) event MUST fire before
the dispatch of this event type. This event type is similar to
[focus](#focus), but does bubble.

##### [3.3.4.4. ][[focusout]]
Type

**`focusout`**

Interface

[`FocusEvent`](#focusevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Element`

Cancelable

No

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [event
 target](#event-target) losing
 focus
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`FocusEvent`](#focusevent).[`relatedTarget`](#dom-focusevent-relatedtarget) : [event
 target](#event-target)
 receiving focus.

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when an [event
target](#event-target) loses
focus. The [event target](#event-target) MUST be the element which lost focus. The
[blur](#blur) event MUST fire before the
dispatch of this event type. This event type is similar to
[blur](#blur), but does bubble.

### 3.4. Input Events

Input events are sent as notifications whenever the DOM is being updated
(or about to be updated) as a direct result of a user action (e.g.,
keyboard input in an editable region, deleting or formatting text,
\...).

#### 3.4.1. Interface InputEvent

##### 3.4.1.1. InputEvent

Introduced in DOM Level 3

```
[Exposed=Window]
interface InputEvent : UIEvent {
 constructor(DOMString type, optional InputEventInit eventInitDict = );
 readonly attribute USVString? data;
 readonly attribute boolean isComposing;
 readonly attribute DOMString inputType;
};
```

[`data`], of type [USVString](https://webidl.spec.whatwg.org/#idl-USVString), readonly, nullable

: `data` holds the value of the characters generated by an input
 method. This MAY be a single Unicode character or a non-empty
 sequence of Unicode characters
 [\[Unicode\]](#biblio-unicode "The Unicode Standard").
 Characters SHOULD be normalized as defined by the Unicode
 normalization form *NFC*, defined in
 [\[UAX15\]](#biblio-uax15 "Unicode Normalization Forms").
 This attribute MAY contain the [empty
 string](#empty-string).

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `null`.

[`isComposing`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: `true` if the input event occurs as part of a composition session,
 i.e., after a
 [`compositionstart`](#compositionstart) event and before the corresponding
 [`compositionend`](#compositionend) event.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `false`.

[`inputType`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: `inputType` contains a string that identifies the type of input
 associated with the event.

 For a list of valid values for this attribute, refer to the
 [\[Input-Events\]](#biblio-input-events "Input Events Level 2")
 specification.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be the empty string `""`.

##### 3.4.1.2. InputEventInit

```
dictionary InputEventInit : UIEventInit {
 DOMString? data = null;
 boolean isComposing = false;
 DOMString inputType = "";
};
```

[`data`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), nullable, defaulting to `null`
: Initializes the `data` attribute of the InputEvent object.

[`isComposing`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the `isComposing` attribute of the InputEvent object.

[`inputType`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `""`
: Initializes the `inputType` attribute of the InputEvent object.

#### 3.4.2. Input Event Order

The input events defined in this specification MUST occur in a set order
relative to one another.

Event Type

Notes

1

[`beforeinput`](#beforeinput)

*DOM element is updated*

2

[`input`](#input)

#### 3.4.3. Input Event Types

##### [3.4.3.1. ][[beforeinput]]
Type

**`beforeinput`**

Interface

[`InputEvent`](#inputevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

`Element` (specifically: control types such as `HTMLInputElement`, etc.)
or any `Element` with `contenteditable` attribute enabled

Cancelable

Yes

Composed

Yes

Default action

Update the DOM element

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [event
 target](#event-target) that
 is about to be updated
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`InputEvent`](#inputevent).[`data`](#dom-inputevent-data) : the string containing the data that will be added
 to the element, which MAY be `null` if the content will be deleted
- [`InputEvent`](#inputevent).[`isComposing`](#dom-inputevent-iscomposing) : `true` if this event is dispatched during a [dead
 key](#keys-dead) sequence or while an [input method
 editor](#input-method-editor) is active (such that [composition
 events](#composition-events) are being dispatched); `false` otherwise.

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when the DOM is about to be
updated.

##### [3.4.3.2. ][[input]]
Type

**`input`**

Interface

[`InputEvent`](#inputevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

`Element` (specifically: control types such as `HTMLInputElement`, etc.)
or any `Element` with `contenteditable` attribute enabled

Cancelable

No

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [event
 target](#event-target) that
 was just updated
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`InputEvent`](#inputevent).[`data`](#dom-inputevent-data) : the string containing the data that has been added
 to the element, which MAY be the [empty
 string](#empty-string) if the
 content has been deleted
- [`InputEvent`](#inputevent).[`isComposing`](#dom-inputevent-iscomposing) : `true` if this event is dispatched during a [dead
 key](#keys-dead) sequence or while an [input method
 editor](#input-method-editor) is active (such that [composition
 events](#composition-events) are being dispatched); `false` otherwise.

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event immediately after the DOM has
been updated.

### 3.5. Keyboard Events

Keyboard events are device dependent, i.e., they rely on the
capabilities of the input devices and how they are mapped in the
operating systems. Refer to [Keyboard events and key values](#keys) for
more details, including examples on how Keyboard Events are used in
combination with Composition Events. Depending on the character
generation device, keyboard events might not be generated.

Keyboard events are only one modality of providing textual input. For
editing scenarios, consider also using the
[`InputEvent`](#inputevent)
as an alternate to (or in addition to) keyboard events.

#### 3.5.1. Interface KeyboardEvent

Introduced in this specification

The [`KeyboardEvent`](#keyboardevent) interface provides specific contextual information
associated with keyboard devices. Each keyboard event references a key
using a value. Keyboard events are commonly directed at the element that
has the focus.

The [`KeyboardEvent`](#keyboardevent) interface provides convenient attributes for some
common modifiers keys:
[`ctrlKey`](#dom-keyboardevent-ctrlkey),
[`shiftKey`](#dom-keyboardevent-shiftkey),
[`altKey`](#dom-keyboardevent-altkey),
[`metaKey`](#dom-keyboardevent-metakey). These attributes are equivalent to using the method
[`getModifierState()`](#dom-keyboardevent-getmodifierstate) with `Control`, `Shift`,
`Alt`, or `Meta` respectively.

To create an instance of the
[`KeyboardEvent`](#keyboardevent) interface, use the
[`KeyboardEvent`](#keyboardevent) constructor, passing an optional
[`KeyboardEventInit`](#dictdef-keyboardeventinit) dictionary.

##### 3.5.1.1. KeyboardEvent

```
[Exposed=Window]
interface KeyboardEvent : UIEvent {
 constructor(DOMString type, optional KeyboardEventInit eventInitDict = );
 // KeyLocationCode
 const unsigned long DOM_KEY_LOCATION_STANDARD = 0x00;
 const unsigned long DOM_KEY_LOCATION_LEFT = 0x01;
 const unsigned long DOM_KEY_LOCATION_RIGHT = 0x02;
 const unsigned long DOM_KEY_LOCATION_NUMPAD = 0x03;

 readonly attribute DOMString key;
 readonly attribute DOMString code;
 readonly attribute unsigned long location;

 readonly attribute boolean ctrlKey;
 readonly attribute boolean shiftKey;
 readonly attribute boolean altKey;
 readonly attribute boolean metaKey;

 readonly attribute boolean repeat;
 readonly attribute boolean isComposing;

 boolean getModifierState(DOMString keyArg);
};
```

[`DOM_KEY_LOCATION_STANDARD`]

: The key activation MUST NOT be distinguished as the left or right
 version of the key, and (other than the `NumLock` key) did
 not originate from the numeric keypad (or did not originate with a
 virtual key corresponding to the numeric keypad).

 (#example-911fe244) The `Q` key on a PC 101
 Key US keyboard.\
 The `NumLock` key on a PC 101 Key US keyboard.\
 The `1` key on a PC 101 Key US keyboard located in the main
 section of the keyboard.

[`DOM_KEY_LOCATION_LEFT`]

: The key activated originated from the left key location (when there
 is more than one possible location for this key).

 (#example-93f18483) The left `Control` key on
 a PC 101 Key US keyboard.

[`DOM_KEY_LOCATION_RIGHT`]

: The key activation originated from the right key location (when
 there is more than one possible location for this key).

 (#example-39e05464) The right `Shift` key on
 a PC 101 Key US keyboard.

[`DOM_KEY_LOCATION_NUMPAD`]

: The key activation originated on the numeric keypad or with a
 virtual key corresponding to the numeric keypad (when there is more
 than one possible location for this key). Note that the
 `NumLock` key should always be encoded with a
 [`location`](#dom-keyboardevent-location) of
 [`DOM_KEY_LOCATION_STANDARD`](#dom-keyboardevent-dom_key_location_standard).

 (#example-cd3aecaf) The `1` key on a PC 101
 Key US keyboard located on the numeric pad.

[`key`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: `key` holds a [key attribute
 value](https://www.w3.org/TR/uievents-key/#key-attribute-value) corresponding to the key pressed.

 The `key` attribute is not related to the legacy `keyCode` attribute
 and does not have the same set of values.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `""` (the empty string).

[`code`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: `code` holds a string that identifies the physical key being
 pressed. The value is not affected by the current keyboard layout or
 modifier state, so a particular key will always return the same
 value.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `""` (the empty string).

[`location`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The
 [`location`](#dom-keyboardevent-location) attribute contains an indication of the logical
 location of the key on the device.

 This attribute MUST be set to one of the DOM_KEY_LOCATION constants
 to indicate the location of a key on the device.

 If a [user
 agent](https://infra.spec.whatwg.org/#user-agent) allows keys to be remapped, then the
 [`location`](#dom-keyboardevent-location) value for a remapped key MUST be set to a value
 which is appropriate for the new key. For example, if the
 `"`[`ControlLeft`](http://www.w3.org/TR/uievents-code/#code-ControlLeft)`"`
 key is mapped to the
 `"`[`KeyQ`](http://www.w3.org/TR/uievents-code/#code-KeyQ)`"`
 key, then the
 [`location`](#dom-keyboardevent-location) attribute MUST be set to
 [`DOM_KEY_LOCATION_STANDARD`](#dom-keyboardevent-dom_key_location_standard). Conversely, if the
 `"`[`KeyQ`](http://www.w3.org/TR/uievents-code/#code-KeyQ)`"`
 key is remapped to one of the `Control` keys, then the
 [`location`](#dom-keyboardevent-location) attribute MUST be set to either
 [`DOM_KEY_LOCATION_LEFT`](#dom-keyboardevent-dom_key_location_left) or
 [`DOM_KEY_LOCATION_RIGHT`](#dom-keyboardevent-dom_key_location_right).

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `0`.

[`ctrlKey`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: `true` if the `Control` (control) key modifier was active.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `false`.

[`shiftKey`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: `true` if the shift (`Shift`) key modifier was active.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `false`.

[`altKey`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: `true` if the `Alt` (alternative) (or `"Option"`)
 key modifier was active.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `false`.

[`metaKey`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: `true` if the meta (`Meta`) key modifier was active.

 The `"Command"` (`"⌘"`) key modifier on Macintosh
 systems is represented using this key modifier.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `false`.

[`repeat`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: `true` if the key has been pressed in a sustained manner. Holding
 down a key MUST result in the repeating the events
 [`keydown`](#keydown),
 [`beforeinput`](#beforeinput), [`input`](#input)
 in this order, at a rate determined by the system configuration. For
 mobile devices which have *long-key-press* behavior, the first key
 event with a
 [`repeat`](#dom-keyboardevent-repeat) attribute value of `true` MUST serve as an
 indication of a *long-key-press*. The length of time that the key
 MUST be pressed in order to begin repeating is
 configuration-dependent.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `false`.

[`isComposing`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: `true` if the key event occurs as part of a composition session,
 i.e., after a
 [`compositionstart`](#compositionstart) event and before the corresponding
 [`compositionend`](#compositionend) event.

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `false`.

[`getModifierState(keyArg)`]

: Queries the state of a modifier using a key value.

 Returns `true` if it is a modifier key and the modifier is
 activated, `false` otherwise.

 DOMString keyArg

 : A modifier key value. Valid [modifier
 keys](#modifier-key) are
 defined in the [Modifier Keys
 table](https://www.w3.org/TR/uievents-key/#keys-modifier) in
 [\[UIEvents-Key\]](#biblio-uievents-key "UI Events KeyboardEvent key Values").

 If an application wishes to distinguish between right and left
 modifiers, this information could be deduced using keyboard
 events and
 [`location`](#dom-keyboardevent-location).

##### 3.5.1.2. KeyboardEventInit

```
dictionary KeyboardEventInit : EventModifierInit {
 DOMString key = "";
 DOMString code = "";
 unsigned long location = 0;
 boolean repeat = false;
 boolean isComposing = false;
};
```

[`key`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `""`
: Initializes the `key` attribute of the KeyboardEvent object to the
 unicode character string representing the meaning of a key after
 taking into account all keyboard modifiers (such as shift-state).
 This value is the final effective value of the key. If the key is
 not a printable character, then it should be one of the key values
 defined in
 [\[UIEvents-Key\]](#biblio-uievents-key "UI Events KeyboardEvent key Values").

[`code`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `""`
: Initializes the `code` attribute of the KeyboardEvent object to the
 unicode character string representing the key that was pressed,
 ignoring any keyboard modifications such as keyboard layout. This
 value should be one of the code values defined in
 [\[UIEvents-Code\]](#biblio-uievents-code "UI Events KeyboardEvent code Values").

[`location`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `0`
: Initializes the
 [`location`](#dom-keyboardevent-location) attribute of the KeyboardEvent object to one of the
 following location numerical constants:
 - [`DOM_KEY_LOCATION_STANDARD`](#dom-keyboardevent-dom_key_location_standard) (numerical value 0)

 - [`DOM_KEY_LOCATION_LEFT`](#dom-keyboardevent-dom_key_location_left) (numerical value 1)

 - [`DOM_KEY_LOCATION_RIGHT`](#dom-keyboardevent-dom_key_location_right) (numerical value 2)

 - [`DOM_KEY_LOCATION_NUMPAD`](#dom-keyboardevent-dom_key_location_numpad) (numerical value 3)

[`repeat`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the `repeat` attribute of the KeyboardEvent object. This
 attribute should be set to `true` if the the current KeyboardEvent
 is considered part of a repeating sequence of similar events caused
 by the long depression of any single key, `false` otherwise.

[`isComposing`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the `isComposing` attribute of the KeyboardEvent object.
 This attribute should be set to `true` if the event being
 constructed occurs as part of a composition sequence, `false`
 otherwise.

Legacy keyboard event implementations include three additional
attributes, `keyCode`, `charCode`, and `which`. The `keyCode` attribute
indicates a numeric value associated with a particular key on a computer
keyboard, while the `charCode` attribute indicates the [ASCII] value of the character associated with
that key (which might be the same as the `keyCode` value) and is
applicable only to keys that produce a [character
value](#character-value).

In practice, `keyCode` and `charCode` are inconsistent across platforms
and even the same implementation on different operating systems or using
different localizations. This specification does not define values for
either `keyCode` or `charCode`, or behavior for `charCode`. In
conforming UI Events implementations, content authors can instead use
[`key`](#dom-keyboardevent-key) and
[`code`](#dom-keyboardevent-code).

*For more information, see the informative appendix on [Legacy key
attributes](#legacy-key-attributes).*

For compatibility with existing content, virtual keyboards, such as
software keyboards on screen-based input devices, are expected to
produce the normal range of keyboard events, even though they do not
possess physical keys.

In some implementations or system configurations, some key events, or
their values, might be suppressed by the [IME](#ime) in use.

#### 3.5.2. Keyboard Event Key Location

The
[`location`](#dom-keyboardevent-location) attribute can be used to disambiguate between
[`key`](#dom-keyboardevent-key) values that can be generated by different physical keys
on the keyboard, for example, the left and right `Shift` key or
the physical arrow keys vs. the numpad arrow keys (when
`NumLock` is off).

The following table defines the valid
[`location`](#dom-keyboardevent-location) values for the special keys that have more than one
location on the keyboard:

[`KeyboardEvent`](#keyboardevent) .
[`key`](#dom-keyboardevent-key)

Valid
[`location`](#dom-keyboardevent-location) values

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`,
`"`[`Control`](http://www.w3.org/TR/uievents-key/#key-Control)`"`,
`"`[`Alt`](http://www.w3.org/TR/uievents-key/#key-Alt)`"`,
`"`[`Meta`](http://www.w3.org/TR/uievents-key/#key-Meta)`"`

[`DOM_KEY_LOCATION_LEFT`](#dom-keyboardevent-dom_key_location_left),
[`DOM_KEY_LOCATION_RIGHT`](#dom-keyboardevent-dom_key_location_right)

`"`[`ArrowDown`](http://www.w3.org/TR/uievents-key/#key-ArrowDown)`"`,
`"`[`ArrowLeft`](http://www.w3.org/TR/uievents-key/#key-ArrowLeft)`"`,
`"`[`ArrowRight`](http://www.w3.org/TR/uievents-key/#key-ArrowRight)`"`,
`"`[`ArrowUp`](http://www.w3.org/TR/uievents-key/#key-ArrowUp)`"`

[`DOM_KEY_LOCATION_STANDARD`](#dom-keyboardevent-dom_key_location_standard),
[`DOM_KEY_LOCATION_NUMPAD`](#dom-keyboardevent-dom_key_location_numpad)

`"`[`End`](http://www.w3.org/TR/uievents-key/#key-End)`"`,
`"`[`Home`](http://www.w3.org/TR/uievents-key/#key-Home)`"`,
`"`[`PageDown`](http://www.w3.org/TR/uievents-key/#key-PageDown)`"`,
`"`[`PageUp`](http://www.w3.org/TR/uievents-key/#key-PageUp)`"`

[`DOM_KEY_LOCATION_STANDARD`](#dom-keyboardevent-dom_key_location_standard),
[`DOM_KEY_LOCATION_NUMPAD`](#dom-keyboardevent-dom_key_location_numpad)

`"0"`, `"1"`, `"2"`, `"2"`, `"4"`,
`"5"`, `"6"`, `"7"`, `"8"`, `"9"`,
`"."`,
`"`[`Enter`](http://www.w3.org/TR/uievents-key/#key-Enter)`"`,
`"+"`, `"-"`, `"*"`, `"/"`

[`DOM_KEY_LOCATION_STANDARD`](#dom-keyboardevent-dom_key_location_standard),
[`DOM_KEY_LOCATION_NUMPAD`](#dom-keyboardevent-dom_key_location_numpad)

For all other keys not listed in this table, the
[`location`](#dom-keyboardevent-location) attribute MUST always be set to
[`DOM_KEY_LOCATION_STANDARD`](#dom-keyboardevent-dom_key_location_standard).

#### 3.5.3. Event Modifier Initializers

The
[`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) and
[`KeyboardEvent`](#keyboardevent) interfaces share a set of keyboard modifier attributes
and support a mechanism for retrieving additional modifier states. The
following dictionary enables authors to initialize keyboard modifier
attributes of the
[`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) and
[`KeyboardEvent`](#keyboardevent) interfaces, as well as the additional modifier states
queried via
[`getModifierState()`](#dom-keyboardevent-getmodifierstate). The steps for constructing mouse events using this
dictionary are defined in the
[\[pointerevents4\]](#biblio-pointerevents4 "Pointer Events")
specification.

```
dictionary EventModifierInit : UIEventInit {
 boolean ctrlKey = false;
 boolean shiftKey = false;
 boolean altKey = false;
 boolean metaKey = false;

 boolean modifierAltGraph = false;
 boolean modifierCapsLock = false;
 boolean modifierFn = false;
 boolean modifierFnLock = false;
 boolean modifierHyper = false;
 boolean modifierNumLock = false;
 boolean modifierScrollLock = false;
 boolean modifierSuper = false;
 boolean modifierSymbol = false;
 boolean modifierSymbolLock = false;
};
```

[`ctrlKey`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Initializes the `ctrlKey` attribute of the
 [`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) or
 [`KeyboardEvent`](#keyboardevent) objects to `true` if the `Control` key
 modifier is to be considered active, `false` otherwise.

 When `true`, implementations must also initialize the event object's
 key modifier state such that calls to the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter `Control`
 must return `true`.

[`shiftKey`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Initializes the `shiftKey` attribute of the
 [`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) or
 [`KeyboardEvent`](#keyboardevent) objects to `true` if the `Shift` key
 modifier is to be considered active, `false` otherwise.

 When `true`, implementations must also initialize the event object's
 key modifier state such that calls to the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter `Shift`
 must return `true`.

[`altKey`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Initializes the `altKey` attribute of the
 [`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) or
 [`KeyboardEvent`](#keyboardevent) objects to `true` if the `Alt`
 (alternative) (or `Option`) key modifier is to be
 considered active, `false` otherwise.

 When `true`, implementations must also initialize the event object's
 key modifier state such that calls to the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter `Alt`
 must return `true`.

[`metaKey`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Initializes the `metaKey` attribute of the
 [`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) or
 [`KeyboardEvent`](#keyboardevent) objects to `true` if the `Meta` key
 modifier is to be considered active, `false` otherwise.

 When `true`, implementations must also initialize the event object's
 key modifier state such that calls to the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with either the parameter
 `Meta` must return `true`.

[`modifierAltGraph`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the event object's key modifier state such that calls to
 the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter
 `AltGraph` must return `true`.

[`modifierCapsLock`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the event object's key modifier state such that calls to
 the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter
 `CapsLock` must return `true`.

[`modifierFn`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the event object's key modifier state such that calls to
 the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter `Fn` must
 return `true`.

[`modifierFnLock`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the event object's key modifier state such that calls to
 the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter `FnLock`
 must return `true`.

[`modifierHyper`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the event object's key modifier state such that calls to
 the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter `Hyper`
 must return `true`.

[`modifierNumLock`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the event object's key modifier state such that calls to
 the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter `NumLock`
 must return `true`.

[`modifierScrollLock`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the event object's key modifier state such that calls to
 the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter
 `ScrollLock` must return `true`.

[`modifierSuper`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the event object's key modifier state such that calls to
 the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter `Super`
 must return `true`.

[`modifierSymbol`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the event object's key modifier state such that calls to
 the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter `Symbol`
 must return `true`.

[`modifierSymbolLock`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Initializes the event object's key modifier state such that calls to
 the
 [`getModifierState()`](https://w3c.github.io/pointerevents/#dom-mouseevent-getmodifierstate) or
 [`getModifierState()`](#dom-keyboardevent-getmodifierstate) when provided with the parameter
 `SymbolLock` must return `true`.

#### 3.5.4. KeyboardEvent Algorithms

##### 3.5.4.1. Global State for KeyboardEvent

###### 3.5.4.1.1. User Agent-Level State

The UA must maintain the following values that are shared for the entire
User Agent.

A [key modifier state] (initially empty) that keeps track of the
current state of each [modifier
key](#modifier-key) available on
the system.

#### 3.5.5. Keyboard Event Order

The keyboard events defined in this specification occur in a set order
relative to one another, for any given key:

Event Type

Notes

1

[`keydown`](#keydown)

2

[`beforeinput`](#beforeinput)

*(only for keys which produce a [character
value](#character-value))*

*Any [default actions](#default-action) related to this key, such as inserting a character in
to the DOM.*

3

[`input`](#input)

*(only for keys which have updated the DOM)*

*Any events as a result of the key being held for a sustained period
(see below).*

4

[`keyup`](#keyup)

If the key is depressed for a sustained period, the following events MAY
repeat at an environment-dependent rate:

Event Type

Notes

1

[`keydown`](#keydown)

*(with
[`repeat`](#dom-keyboardevent-repeat) attribute set to `true`)*

2

[`beforeinput`](#beforeinput)

*(only for keys which produce a [character
value](#character-value))*

*Any [default actions](#default-action) related to this key, such as inserting a character in
to the DOM.*

3

[`input`](#input)

*(only for keys which have updated the DOM)*

Typically, any [default
actions](#default-action)
associated with any particular key are completed before the
[`keyup`](#keyup) event is dispatched.
This might delay the [`keyup`](#keyup)
event slightly (though this is not likely to be a perceptible delay).

The [event target](#event-target) of a key event is the currently focused element which
is processing the keyboard activity. This is often an HTML `input`
element or a textual element which is editable, but MAY be an element
defined by the [host language](#host-language) to accept keyboard input for non-text purposes, such as
the activation of an accelerator key or trigger of some other behavior.
If no suitable element is in focus, the event target will be the HTML
[body element](#body-element) if
available, otherwise the [root
element](#root-element).

The [event target](#event-target) might change between different key events. For example,
a [`keydown`](#keydown) event for the
`Tab` key will likely have a different [event
target](#event-target) than the
[`keyup`](#keyup) event on the same
keystroke.

#### 3.5.6. Keyboard Event Types

##### [3.5.6.1. ][[keydown]]
Type

**`keydown`**

Interface

[`KeyboardEvent`](#keyboardevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

`Element`

Cancelable

Yes

Composed

Yes

Default action

Varies: [`beforeinput`](#beforeinput) and [`input`](#input)
events; launch [text composition
system](#text-composition-system); [`blur`](#blur) and
[`focus`](#focus) events;
[`keypress`](#keypress) event (if
supported); [activation
behavior](https://dom.spec.whatwg.org/#eventtarget-activation-behavior); other event

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : focused element processing the key event or if no
 element focused, then the [body
 element](#body-element) if
 available, otherwise the [root
 element](#root-element)
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`KeyboardEvent`](#keyboardevent).[`key`](#dom-keyboardevent-key) : the key value of the key pressed.
- [`KeyboardEvent`](#keyboardevent).[`code`](#dom-keyboardevent-code) : the code value associated with the key's physical
 placement on the keyboard.
- [`KeyboardEvent`](#keyboardevent).[`location`](#dom-keyboardevent-location) : the location of the key on the device.
- [`KeyboardEvent`](#keyboardevent).[`altKey`](#dom-keyboardevent-altkey) : `true` if `Alt` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`shiftKey`](#dom-keyboardevent-shiftkey) : `true` if `Shift` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`ctrlKey`](#dom-keyboardevent-ctrlkey) : `true` if `Control` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`metaKey`](#dom-keyboardevent-metakey) : `true` if `Meta` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`repeat`](#dom-keyboardevent-repeat) : `true` if a key has been depressed long enough to
 trigger key repetition, otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`isComposing`](#dom-keyboardevent-iscomposing) : `true` if the key event occurs as part of a
 composition session, otherwise `false`

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when a key is pressed down.
The [`keydown`](#keydown) event type
is device dependent and relies on the capabilities of the input devices
and how they are mapped in the operating system. This event type MUST be
generated after the [key mapping](#key-mapping). This event type MUST be dispatched before the
[`beforeinput`](#beforeinput),
[`input`](#input), and
[`keyup`](#keyup) events associated
with the same key.

The default action of the [`keydown`](#keydown) event depends upon the key:

- If the key is associated with a character, the default action MUST be
 to dispatch a [`beforeinput`](#beforeinput) event followed by an
 [`input`](#input) event. In the case
 where the key which is associated with multiple characters (such as
 with a macro or certain sequences of dead keys), the default action
 MUST be to dispatch one set of
 [`beforeinput`](#beforeinput) /
 [`input`](#input) events for each
 character

- If the key is associated with a [text composition
 system](#text-composition-system), the default action MUST be to launch that system

- If the key is the `Tab` key, the default action MUST be to
 shift the document focus from the currently focused element (if any)
 to the new focused element, as described in [Focus Event
 Types](#events-focusevent)

- If the key is the `Enter` or ` ` (Space) key and the
 current focus is on a state-changing element, the default action MUST
 be to dispatch a
 [`click`](https://w3c.github.io/pointerevents/#dfn-click) event, and a
 [`DOMActivate`](#domactivate)
 event if that event type is supported by the [user
 agent](https://infra.spec.whatwg.org/#user-agent).

If this event is canceled, the associated event types MUST NOT be
dispatched, and the associated actions MUST NOT be performed.

The [`keydown`](#keydown) and
[`keyup`](#keyup) events are
traditionally associated with detecting any key, not just those which
produce a [character value](#character-value).

##### [3.5.6.2. ][[keyup]]
Type

**`keyup`**

Interface

[`KeyboardEvent`](#keyboardevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

`Element`

Cancelable

Yes

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : focused element processing the key event or if no
 element focused, then the [body
 element](#body-element) if
 available, otherwise the [root
 element](#root-element)
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`KeyboardEvent`](#keyboardevent).[`key`](#dom-keyboardevent-key) : the key value of the key pressed.
- [`KeyboardEvent`](#keyboardevent).[`code`](#dom-keyboardevent-code) : the code value associated with the key's physical
 placement on the keyboard.
- [`KeyboardEvent`](#keyboardevent).[`location`](#dom-keyboardevent-location) : the location of the key on the device.
- [`KeyboardEvent`](#keyboardevent).[`altKey`](#dom-keyboardevent-altkey) : `true` if `Alt` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`shiftKey`](#dom-keyboardevent-shiftkey) : `true` if `Shift` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`ctrlKey`](#dom-keyboardevent-ctrlkey) : `true` if `Control` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`metaKey`](#dom-keyboardevent-metakey) : `true` if `Meta` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`repeat`](#dom-keyboardevent-repeat) : `true` if a key has been depressed long enough to
 trigger key repetition, otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`isComposing`](#dom-keyboardevent-iscomposing) : `true` if the key event occurs as part of a
 composition session, otherwise `false`

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when a key is released. The
[`keyup`](#keyup) event type is device
dependent and relies on the capabilities of the input devices and how
they are mapped in the operating system. This event type MUST be
generated after the [key mapping](#key-mapping). This event type MUST be dispatched after the
[`keydown`](#keydown),
[`beforeinput`](#beforeinput),
and [`input`](#input) events
associated with the same key.

The [`keydown`](#keydown) and
[`keyup`](#keyup) events are
traditionally associated with detecting any key, not just those which
produce a [character value](#character-value).

### [3.6. ][[Composition Events]]
Composition Events provide a means for inputing text in a supplementary
or alternate manner than by Keyboard Events, in order to allow the use
of characters that might not be commonly available on keyboard. For
example, Composition Events might be used to add accents to characters
despite their absence from standard US keyboards, to build up logograms
of many Asian languages from their base components or categories, to
select word choices from a combination of key presses on a mobile device
keyboard, or to convert voice commands into text using a speech
recognition processor. Refer to [§ 4 Keyboard events and key
values](#keys) for examples on how Composition Events are used in
combination with keyboard events.

Conceptually, a composition session consists of one
[`compositionstart`](#compositionstart) event, one or more
[`compositionupdate`](#compositionupdate) events, and one
[`compositionend`](#compositionend) event, with the value of the
[`data`](#dom-compositionevent-data) attribute persisting between each "stage" of this event
chain during each session.

**Note:** While a composition session is active, keyboard events can be
dispatched to the DOM if the keyboard is the input device used with the
composition session. See the
[`compositionstart`](#compositionstart) event details and [IME section](#keys-IME) for relevent
event ordering.

Not all [IME](#ime) systems or devices
expose the necessary data to the DOM, so the active composition string
(the "Reading Window" or "candidate selection menu option") might not be
available through this interface, in which case the selection MAY be
represented by the [empty string](#empty-string).

#### 3.6.1. Interface CompositionEvent

Introduced in this specification

The
[`CompositionEvent`](#compositionevent) interface provides specific contextual information
associated with Composition Events.

To create an instance of the
[`CompositionEvent`](#compositionevent) interface, use the
[`CompositionEvent`](#compositionevent) constructor, passing an optional
[`CompositionEventInit`](#dictdef-compositioneventinit) dictionary.

##### 3.6.1.1. CompositionEvent

```
[Exposed=Window]
interface CompositionEvent : UIEvent {
 constructor(DOMString type, optional CompositionEventInit eventInitDict = );
 readonly attribute USVString data;
};
```

[`data`], of type [USVString](https://webidl.spec.whatwg.org/#idl-USVString), readonly

: `data` holds the value of the characters generated by an input
 method. This MAY be a single Unicode character or a non-empty
 sequence of Unicode characters
 [\[Unicode\]](#biblio-unicode "The Unicode Standard").
 Characters SHOULD be normalized as defined by the Unicode
 normalization form *NFC*, defined in
 [\[UAX15\]](#biblio-uax15 "Unicode Normalization Forms").
 This attribute MAY be the [empty
 string](#empty-string).

 The [un-initialized
 value](#un-initialized-value) of this attribute MUST be `""` (the empty string).

##### 3.6.1.2. CompositionEventInit

```
dictionary CompositionEventInit : UIEventInit {
 DOMString data = "";
};
```

[`data`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `""`
: Initializes the `data` attribute of the CompositionEvent object to
 the characters generated by the IME composition.

#### 3.6.2. Composition Event Order

The Composition Events defined in this specification MUST occur in the
following set order relative to one another:

Event Type

Notes

1

[`compositionstart`](#compositionstart)

2

[`compositionupdate`](#compositionupdate)

Multiple events

3

[`compositionend`](#compositionend)

#### 3.6.3. Handwriting Recognition Systems

The following example describes a possible sequence of events when
composing a text passage "text" with a handwriting recognition system,
such as on a pen tablet, as modeled using Composition Events.

Event Type

[`CompositionEvent`](#compositionevent)\
[`data`](#dom-compositionevent-data)

Notes

1

[`compositionstart`](#compositionstart)

`""`

*User writes word on tablet surface*

2

[`compositionupdate`](#compositionupdate)

`"test"`

*User rejects first word-match suggestion, selects different match*

3

[`compositionupdate`](#compositionupdate)

`"text"`

4

[`compositionend`](#compositionend)

`"text"`

#### 3.6.4. Canceling Composition Events

If a [`keydown`](#keydown) event is
canceled then any Composition Events that would have fired as a result
of that [`keydown`](#keydown) SHOULD
not be dispatched:

Event Type

Notes

1

[`keydown`](#keydown)

The [default action](#default-action) is prevented, e.g., by invoking
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault).

*No Composition Events are dispatched*

2

[`keyup`](#keyup)

If the initial
[`compositionstart`](#compositionstart) event is canceled then the text composition session
SHOULD be terminated. Regardless of whether or not the composition
session is terminated, the
[`compositionend`](#compositionend) event MUST be sent.

Event Type

Notes

1

[`keydown`](#keydown)

2

[`compositionstart`](#compositionstart)

The [default action](#default-action) is prevented, e.g., by invoking
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault).

*No Composition Events are dispatched*

3

[`compositionend`](#compositionend)

4

[`keyup`](#keyup)

#### 3.6.5. Key Events During Composition

During the composition session, [`keydown`](#keydown) and [`keyup`](#keyup)
events MUST still be sent, and these events MUST have the
[`isComposing`](#dom-keyboardevent-iscomposing) attribute set to `true`.

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`isComposing`](#dom-keyboardevent-iscomposing)

Notes

1

[`keydown`](#keydown)

false

This is the key event that initiates the composition.

2

[`compositionstart`](#compositionstart)

3

[`compositionupdate`](#compositionupdate)

4

[`keyup`](#keyup)

true

\...

Any key events sent during the composition session MUST have
`isComposing` set to `true`.

5

[`keydown`](#keydown)

true

This is the key event that exits the composition.

6

[`compositionend`](#compositionend)

7

[`keyup`](#keyup)

false

#### 3.6.6. Input Events During Composition

During the composition session, the
[`compositionupdate`](#compositionupdate) MUST be dispatched after the
[`beforeinput`](#beforeinput) is
sent, but before the [`input`](#input)
event is sent.

Event Type

Notes

1

[`beforeinput`](#beforeinput)

2

[`compositionupdate`](#compositionupdate)

*Any DOM updates occur at this point.*

3

[`input`](#input)

Most IMEs do not support canceling updates during a composition session.

The [`beforeinput`](#beforeinput) and [`input`](#input)
events are sent along with the
[`compositionupdate`](#compositionupdate) event whenever the DOM is updated as part of the
composition. Since there are no DOM updates associated with the
[`compositionend`](#compositionend) event,
[`beforeinput`](#beforeinput)
and [`input`](#input) events should
not be sent at that time.

Event Type

Notes

1

[`beforeinput`](#beforeinput)

*Canceling this will prevent the DOM update and the
[`input`](#input) event.*

2

[`compositionupdate`](#compositionupdate)

*Any DOM updates occur at this point.*

3

[`input`](#input)

*Sent only if the DOM was updated.*

4

[`compositionend`](#compositionend)

#### 3.6.7. Composition Event Types

##### [3.6.7.1. ][[compositionstart]]
Type

**`compositionstart`**

Interface

[`CompositionEvent`](#compositionevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

`Element`

Cancelable

Yes

Composed

Yes

Default action

Start a new composition session when a [text composition
system](#text-composition-system) is enabled

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : focused element processing the composition
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`CompositionEvent`](#compositionevent).[`data`](#dom-compositionevent-data) : the original string being edited, otherwise the
 [empty string](#empty-string)

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when a [text composition
system](#text-composition-system) is enabled and a new composition session is about to
begin (or has begun, depending on the [text composition
system](#text-composition-system)) in preparation for composing a passage of text. This
event type is device-dependent, and MAY rely upon the capabilities of
the text conversion system and how it is mapped into the operating
system. When a keyboard is used to feed an input method editor, this
event type is generated after a [`keydown`](#keydown) event, but speech or handwriting recognition systems
MAY send this event type without keyboard events. Some implementations
MAY populate the
[`data`](#dom-compositionevent-data) attribute of the
[`compositionstart`](#compositionstart) event with the text currently selected in the document
(for editing and replacement). Otherwise, the value of the
[`data`](#dom-compositionevent-data) attribute MUST be the [empty
string](#empty-string).

This event MUST be dispatched immediately before a [text composition
system](#text-composition-system) begins a new composition session, and before the DOM is
modified due to the composition process. The default action of this
event is for the [text composition
system](#text-composition-system) to start a new composition session. If this event is
canceled, the [text composition
system](#text-composition-system) SHOULD discard the current composition session.

Canceling the
[`compositionstart`](#compositionstart) *event type* is distinct from canceling the [text
composition
system](#text-composition-system) itself (e.g., by hitting a cancel button or closing an
[IME](#ime) window).

Some IMEs do not support cancelling an in-progress composition session
(e.g., such as GTK which doesn't presently have such an API). In these
cases, calling
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) will not stop this event's default action.

##### [3.6.7.2. ][[compositionupdate]]
Type

**`compositionupdate`**

Interface

[`CompositionEvent`](#compositionevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

`Element`

Cancelable

No

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : focused element processing the composition, `null`
 if not accessible
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`CompositionEvent`](#compositionevent).[`data`](#dom-compositionevent-data) : the string comprising the current results of the
 composition session, which MAY be the [empty
 string](#empty-string) if the
 content has been deleted

A [user
agent](https://infra.spec.whatwg.org/#user-agent) SHOULD dispatch this event during a composition session
when a [text composition
system](#text-composition-system) updates its active text passage with a new character,
which is reflected in the string in
[`data`](#dom-compositionevent-data).

In [text composition
systems](#text-composition-system) which keep the ongoing composition in sync with the
input control, the
[`compositionupdate`](#compositionupdate) event MUST be dispatched before the control is updated.

Some [text composition
systems](#text-composition-system) might not expose this information to the DOM, in which
case this event will not fire during the composition process.

If the composition session is canceled, this event will be fired
immediately before the
[`compositionend`](#compositionend) event, and the
[`data`](#dom-compositionevent-data) attribute will be set to the [empty
string](#empty-string).

##### [3.6.7.3. ][[compositionend]]
Type

**`compositionend`**

Interface

[`CompositionEvent`](#compositionevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

`Element`

Cancelable

No

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : focused element processing the composition
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`CompositionEvent`](#compositionevent).[`data`](#dom-compositionevent-data) : the string comprising the final result of the
 composition session, which MAY be the [empty
 string](#empty-string) if the
 content has been deleted or if the composition process has been
 canceled

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when a [text composition
system](#text-composition-system) completes or cancels the current composition session,
and the [`compositionend`](#compositionend) event MUST be dispatched after the control is updated.

This event is dispatched immediately after the [text composition
system](#text-composition-system) completes the composition session (e.g., the
[IME](#ime) is closed, minimized,
switched out of focus, or otherwise dismissed, and the focus switched
back to the [user
agent](https://infra.spec.whatwg.org/#user-agent)).

## 4. Keyboard events and key values

This section contains necessary information regarding keyboard events:

- Explanation of keyboard layout, mapping, and key values.

- Relations between keys, such as [dead
 keys](#dead-key) or modifiers keys.

- Relations between keyboard events and their default actions.

- The set of `key` values, and guidelines on how to extend this set.

This section uses Serbian and Kanji characters which could be
misrepresented or unavailable in the PDF version or printed version of
this specification.

### 4.1. Keyboard Input

*This section is non-normative*

The relationship of each key to the complete keyboard has three separate
aspects, each of which vary among different models and configurations of
keyboards, particularly for locale-specific reasons:

- **Mechanical layout:** the dimensions, size, and placement of the
 physical keys on the keyboard

- **Visual markings:** the labels (or *legends*) that mark each key

- **Functional mapping:** the abstract key-value association of each
 key.

This specification only defines the functional mapping, in terms of
[`key`](#keys-keyvalues) values and [`code`](#keys-codevalues) values,
but briefly describes [key legends](#key-legends) for background.

#### 4.1.1. Key Legends

*This section is informative*

The key legend is the visual marking that is printed or embossed on the
*key cap* (the rectangular \"cap\" that covers the mechanical switch for
the key). These markings normally consist of one or more characters that
a keystroke on that key will produce (such as `"G"`,
`"8"`, or `"ш"`), or names or symbols which indicate
that key's function (such as an upward-pointing arrow `"⇧"`
indicating `Shift`, or the string `"Enter"`). Keys are often
referred to by this marking (e.g., "Press the `"Shift"` and `"G"`
keys."). Note, however, that the visual appearance of the key has no
bearing on its digital representation, and in many configurations may be
completely inaccurate. Even the control and function keys, such as
`Enter`, may be mapped to different functionality, or even
mapped as character keys.

Many keyboards contain keys that do not normally produce any characters,
even though the symbol might have a Unicode equivalent. For example, the
`Shift` key might bear the symbol `"⇧"`, which has the
Unicode code point `U+21E7`, but pressing the `Shift`
key will not produce this character value, and there is no Unicode code
point for `Shift`.

### 4.2. Key codes

A key
[`code`](#dom-keyboardevent-code) is an attribute of a keyboard event that can be used to
identify the physical key associated with the keyboard event. It is
similar to USB Usage IDs in that it provides a low-level value (similar
to a scancode) that is vendor-neutral.

The primary purpose of the
[`code`](#dom-keyboardevent-code) attribute is to provide a consistent and coherent way
to identify keys based on their physical location. In addition, it also
provides a stable name (unaffected by the current keyboard state) that
uniquely identifies each key on the keyboard.

The list of valid
[`code`](#dom-keyboardevent-code) values is defined in the
[\[UIEvents-Code\]](#biblio-uievents-code "UI Events KeyboardEvent code Values").

#### 4.2.1. Motivation for the [`code` Attribute]
The standard PC keyboard has a set of keys (which we refer to as
*writing system keys*) that generate different
[`key`](#dom-keyboardevent-key) values based on the current keyboard layout selected by
the user. This situation makes it difficult to write code that detects
keys based on their physical location since the code would need to know
which layout is in effect in order to know which
[`key`](#dom-keyboardevent-key) values to check for. A real-world example of this is a
game that wants to use the `"W"`, `"A"`, `"S"`
and `"D"` keys to control player movement. The
[`code`](#dom-keyboardevent-code) attribute solves this problem by providing a stable
value to check that is *not affected by the current keyboard layout*.

In addition, the values in the
[`key`](#dom-keyboardevent-key) attribute depend as well on the current keyboard state.
Because of this, the order in which keys are pressed and released in
relation to modifier keys can affect the values stored in the
[`key`](#dom-keyboardevent-key) attribute. The
[`code`](#dom-keyboardevent-code) attribute solves this problem by providing a stable
value that is *not affected by the current keyboard state*.

#### 4.2.2. The Relationship Between [`key` and [`code`](#dom-keyboardevent-code)]
[`key`](#dom-keyboardevent-key)
: The
 [`key`](#dom-keyboardevent-key) attribute is intended for users who are interested
 in the meaning of the key being pressed, taking into account the
 current keyboard layout (and IME; [dead keys](#keys-dead) are given
 a unique
 [`key`](#dom-keyboardevent-key) value). Example use case: Detecting modified keys
 or bare modifier keys (e.g., to perform an action in response to a
 keyboard shortcut).

[`code`](#dom-keyboardevent-code)
: The
 [`code`](#dom-keyboardevent-code) attribute is intended for users who are interested
 in the key that was pressed by the user, without any layout
 modifications applied. Example use case: Detecting WASD keys (e.g.,
 for movement controls in a game) or trapping all keys (e.g., in a
 remote desktop client to send all keys to the remote host).

#### 4.2.3. `code` Examples

Handling the Left and Right Alt Keys

Keyboard Layout

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`KeyboardEvent`](#keyboardevent)\
[`code`](#dom-keyboardevent-code)

Notes

US

`"`[`Alt`](http://www.w3.org/TR/uievents-key/#key-Alt)`"`

`"`[`AltLeft`](http://www.w3.org/TR/uievents-code/#code-AltLeft)`"`

[`DOM_KEY_LOCATION_LEFT`](#dom-keyboardevent-dom_key_location_left)

French

`"`[`Alt`](http://www.w3.org/TR/uievents-key/#key-Alt)`"`

`"`[`AltLeft`](http://www.w3.org/TR/uievents-code/#code-AltLeft)`"`

[`DOM_KEY_LOCATION_LEFT`](#dom-keyboardevent-dom_key_location_left)

US

`"`[`Alt`](http://www.w3.org/TR/uievents-key/#key-Alt)`"`

`"`[`AltRight`](http://www.w3.org/TR/uievents-code/#code-AltRight)`"`

[`DOM_KEY_LOCATION_RIGHT`](#dom-keyboardevent-dom_key_location_right)

French

`"`[`AltGraph`](http://www.w3.org/TR/uievents-key/#key-AltGraph)`"`

`"`[`AltRight`](http://www.w3.org/TR/uievents-code/#code-AltRight)`"`

[`DOM_KEY_LOCATION_RIGHT`](#dom-keyboardevent-dom_key_location_right)

In this example, checking the
[`key`](#dom-keyboardevent-key) attribute permits matching `Alt` without
worrying about which Alt key (left or right) was pressed. Checking the
[`code`](#dom-keyboardevent-code) attribute permits matching the right Alt key
(`"`[`AltRight`](http://www.w3.org/TR/uievents-code/#code-AltRight)`"`)
without worrying about which layout is currently in effect.

Note that, in the French example, the `Alt` and
`AltGraph` keys retain their left and right location, even
though there is only one of each key.

Handling the Single Quote Key

Keyboard Layout

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`KeyboardEvent`](#keyboardevent)\
[`code`](#dom-keyboardevent-code)

Notes

US

`"'"`

`"`[`Quote`](http://www.w3.org/TR/uievents-code/#code-Quote)`"`

Japanese

`":"`

`"`[`Quote`](http://www.w3.org/TR/uievents-code/#code-Quote)`"`

US Intl

`"`[`Dead`](http://www.w3.org/TR/uievents-key/#key-Dead)`"`

`"`[`Quote`](http://www.w3.org/TR/uievents-code/#code-Quote)`"`

This example shows how dead key values are encoded in the attributes.
The
[`key`](#dom-keyboardevent-key) values vary based on the current locale, whereas the
[`code`](#dom-keyboardevent-code) attribute returns a consistent value.

Handling the `"2"` Key (with and
without Shift pressed) on various keyboard layouts.

Keyboard Layout

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`KeyboardEvent`](#keyboardevent)\
[`code`](#dom-keyboardevent-code)

Notes

US

`"2"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

US

`"@"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

UK

`"2"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

UK

`"""`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

French

`"é"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

French

`"2"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

Regardless of the current locale or the modifier key state, pressing the
key labelled `"2"` on a US keyboard always results in
`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`
in the
[`code`](#dom-keyboardevent-code) attribute.

Sequence of Keyboard Events :
`Shift` and `2`

Compare the attribute values in the following two key event sequences.
They both produce the `"@"` character on a US keyboard, but
differ in the order in which the keys are released. In the first
sequence, the order is: `Shift` (down), `2` (down),
`2` (up), `Shift` (up).

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`KeyboardEvent`](#keyboardevent)\
[`code`](#dom-keyboardevent-code)

Notes

1

[`keydown`](#keydown)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

`"`[`ShiftLeft`](http://www.w3.org/TR/uievents-code/#code-ShiftLeft)`"`

[`DOM_KEY_LOCATION_LEFT`](#dom-keyboardevent-dom_key_location_left)

2

[`keydown`](#keydown)

`"@"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

3

[`keypress`](#keypress)

`"@"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

(if supported)

4

[`keyup`](#keyup)

`"@"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

5

[`keyup`](#keyup)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

`"`[`ShiftLeft`](http://www.w3.org/TR/uievents-code/#code-ShiftLeft)`"`

[`DOM_KEY_LOCATION_LEFT`](#dom-keyboardevent-dom_key_location_left)

In the second sequence, the Shift is released before the 2, resulting in
the following event order: `Shift` (down), `2` (down),
`Shift` (up), `2` (up).

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`KeyboardEvent`](#keyboardevent)\
[`code`](#dom-keyboardevent-code)

Notes

1

[`keydown`](#keydown)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

`"`[`ShiftLeft`](http://www.w3.org/TR/uievents-code/#code-ShiftLeft)`"`

[`DOM_KEY_LOCATION_LEFT`](#dom-keyboardevent-dom_key_location_left)

2

[`keydown`](#keydown)

`"@"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

3

[`keypress`](#keypress)

`"@"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

(if supported)

4

[`keyup`](#keyup)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

`"`[`ShiftLeft`](http://www.w3.org/TR/uievents-code/#code-ShiftLeft)`"`

[`DOM_KEY_LOCATION_LEFT`](#dom-keyboardevent-dom_key_location_left)

5

[`keyup`](#keyup)

`"2"`

`"`[`Digit2`](http://www.w3.org/TR/uievents-code/#code-Digit2)`"`

Note that the values contained in the
[`key`](#dom-keyboardevent-key) attribute does not match between the keydown and keyup
events for the `"2"` key. The
[`code`](#dom-keyboardevent-code) attribute provides a consistent value that is not
affected by the current modifier state.

#### 4.2.4. [`code` and Virtual Keyboards]
The usefulness of the
[`code`](#dom-keyboardevent-code) attribute is less obvious for virtual keyboards (and
also for remote controls and chording keyboards). In general, if a
virtual (or remote control) keyboard is mimicking the layout and
functionality of a standard keyboard, then it MUST also set the
[`code`](#dom-keyboardevent-code) attribute as appropriate. For keyboards which are not
mimicking the layout of a standard keyboard, then the
[`code`](#dom-keyboardevent-code) attribute MAY be set to the closest match on a standard
keyboard or it MAY be left undefined.

For virtual keyboards with keys that produce different values based on
some modifier state, the
[`code`](#dom-keyboardevent-code) value should be the
[`key`](#dom-keyboardevent-key) value generated when the button is pressed while the
device is in its factory-reset state.

### 4.3. Keyboard Event `key` Values

A key value is a `DOMString` that can be used to indicate any given key
on a keyboard, regardless of position or state, by the value it
produces. These key values MAY be used as return values for keyboard
events generated by the implementation, or as input values by the
content author to specify desired input (such as for keyboard
shortcuts).

The list of valid `key` values is defined in
[\[UIEvents-Key\]](#biblio-uievents-key "UI Events KeyboardEvent key Values").

Key values can be used to detect the value of a key which has been
pressed, using the
[`key`](#dom-keyboardevent-key) attribute. Content authors can retrieve the [character
value](#character-value) of
upper- or lower-case letters, number, symbols, or other
character-producing keys, and also the [key
value](#key-value) of control keys,
modifier keys, function keys, or other keys that do not generate
characters. These values can be used for monitoring particular input
strings, for detecting and acting on modifier key input in combination
with other inputs (such as a mouse), for creating virtual keyboards, or
for any number of other purposes.

Key values can also be used by content authors in string comparisons, as
values for markup attributes (such as the HTML `accesskey`) in
conforming [host languages](#host-language), or for other related purposes. A conforming [host
language](#host-language)
SHOULD allow content authors to use either of the two equivalent string
values for a key value: the [character
value](#character-value), or
the [key value](#key-value).

While implementations will use the most relevant value for a key
independently of the platform or keyboard layout mappings, content
authors can not make assumptions on the ability of keyboard devices to
generate them. When using keyboard events and key values for
shortcut-key combinations, content authors can "consider using numbers
and function keys (`F4`, `F5`, and so on) instead of
letters"
([\[DWW95\]](#biblio-dww95 "Developing International Software for Windows 95 and Windows NT: A Handbook for International Software Design"))
given that most keyboard layouts will provide keys for those.

A key value does not indicate a specific key on the physical keyboard,
nor does it reflect the character printed on the key. A key value
indicates the current value of the event with consideration to the
current state of all active keys and key input modes (including shift
modes), as reflected in the operating-system mapping of the keyboard and
reported to the implementation. In other words, the key value for the
key labeled `O` on a [QWERTY](#qwerty) keyboard has the key value `"o"` in an unshifted
state and `"O"` in a shifted state. Because a user can map their
keyboard to an arbitrary custom configuration, the content author is
encouraged not to assume that a relationship exists between the shifted
and unshifted states of a key and the majuscule form (uppercase or
capital letters) and minuscule form (lowercase or small letters) of a
character representation, but is encouraged instead to use the value of
the
[`key`](#dom-keyboardevent-key) attribute. For example, the Standard \"102\" Keyboard
layout depicted in
[\[UIEvents-Code\]](#biblio-uievents-code "UI Events KeyboardEvent code Values")
illustrates one possible set of [key
mappings](#key-mapping) on one
possible keyboard layout. Many others exist, both standard and
idiosyncratic.

To simplify [dead key](#dead-key)
support, when the operating-system mapping of the keyboard is handling a
[dead key](#dead-key) state, the
current state of the dead key sequence is not reported via the
[`key`](#dom-keyboardevent-key) attribute. Rather, a key value of
`"`[`Dead`](http://www.w3.org/TR/uievents-key/#key-Dead)`"`
is reported. Instead, implementations generate [composition
events](#composition-events) which contain the intermediate state of the dead key
sequence reported via the
[`data`](#dom-compositionevent-data) attribute. As in the previous example, the key value
for the key marked `O` on a [QWERTY](#qwerty) keyboard has a
[`data`](#dom-compositionevent-data) value of `"ö"` in an unshifted state during a
dead-key operation to add an umlaut diacritic, and `"Ö"` in a
shifted state during a dead-key operation to add an umlaut diacritic.

It is also important to note that there is not a one-to-one relationship
between key event states and key values. A particular key value might be
associated with multiple keys. For example, many standard keyboards
contain more than one key with the `Shift` key value (normally
distinguished by the
[`location`](#dom-keyboardevent-location) values
[`DOM_KEY_LOCATION_LEFT`](#dom-keyboardevent-dom_key_location_left) and
[`DOM_KEY_LOCATION_RIGHT`](#dom-keyboardevent-dom_key_location_right)) or `8` key value (normally distinguished by
the
[`location`](#dom-keyboardevent-location) values
[`DOM_KEY_LOCATION_STANDARD`](#dom-keyboardevent-dom_key_location_standard) and
[`DOM_KEY_LOCATION_NUMPAD`](#dom-keyboardevent-dom_key_location_numpad)), and user-configured custom keyboard layouts MAY
duplicate any key value in multiple key-state scenarios (note that
[`location`](#dom-keyboardevent-location) is intended for standard keyboard layouts, and cannot
always indicate a meaningful distinction).

Finally, the meaning of any given character representation is
context-dependent and complex. For example, in some contexts, the
asterisk (star) glyph (`"*"`) represents a footnote or emphasis
(when bracketing a passage of text). However, in some documents or
executable programs it is equivalent to the mathematical multiplication
operation, while in other documents or executable programs, that
function is reserved for the multiplication symbol (`"×"`,
Unicode value `U+00D7`) or the Latin small letter `"x"` (due
to the lack of a multiplication key on many keyboards and the
superficial resemblance of the glyphs `"×"` and `"x"`).
Thus, the semantic meaning or function of character representations is
outside the scope of this specification.

#### 4.3.1. Modifier keys

Keyboard input uses modifier keys to change the normal behavior of a
key. Like other keys, modifier keys generate
[`keydown`](#keydown) and
[`keyup`](#keyup) events, as shown in
the example below. Some modifiers are activated while the key is being
pressed down or maintained pressed such as `Alt`,
`Control`, `Shift`, `AltGraph`, or
`Meta`. Other modifiers are activated depending on their state
such as `CapsLock`, `NumLock`, or
`ScrollLock`. Change in the state happens when the modifier key
is being pressed down. The
[`KeyboardEvent`](#keyboardevent) interface provides convenient attributes for some
common modifiers keys:
[`ctrlKey`](#dom-keyboardevent-ctrlkey),
[`shiftKey`](#dom-keyboardevent-shiftkey),
[`altKey`](#dom-keyboardevent-altkey),
[`metaKey`](#dom-keyboardevent-metakey). Some operating systems simulate the
`AltGraph` modifier key with the combination of the
`Alt` and `Control` modifier keys. Implementations are
encouraged to use the `AltGraph` modifier key.

This example describes a possible
sequence of events associated with the generation of the Unicode
character Q (Latin Capital Letter Q, Unicode code point
`U+0051`) on a US keyboard using a US mapping:

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

Modifiers

Notes

1

[`keydown`](#keydown)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

2

[`keydown`](#keydown)

`"Q"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

Latin Capital Letter Q

3

[`beforeinput`](#beforeinput)

4

[`input`](#input)

5

[`keyup`](#keyup)

`"Q"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

6

[`keyup`](#keyup)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

Th example describes an alternate
sequence of keys to the example above, where the `Shift` key is
released before the `Q` key. The key value for the `Q`
key will revert to its unshifted value for the
[`keyup`](#keyup) event:

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

Modifiers

Notes

1

[`keydown`](#keydown)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

2

[`keydown`](#keydown)

`"Q"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

Latin Capital Letter Q

3

[`beforeinput`](#beforeinput)

4

[`input`](#input)

5

[`keyup`](#keyup)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

6

[`keyup`](#keyup)

`"q"`

Latin Small Letter Q

The following example describes a
possible sequence of keys that does not generate a Unicode character
(using the same configuration as the previous example):

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

Modifiers

Notes

1

[`keydown`](#keydown)

`"`[`Control`](http://www.w3.org/TR/uievents-key/#key-Control)`"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey)

2

[`keydown`](#keydown)

`"v"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey)

Latin Small Letter V

*No [`beforeinput`](#beforeinput) or [`input`](#input)
events are generated.*

3

[`keyup`](#keyup)

`"v"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey)

Latin Small Letter V

4

[`keyup`](#keyup)

`"`[`Control`](http://www.w3.org/TR/uievents-key/#key-Control)`"`

The following example shows the
sequence of events when both `Shift` and `Control` are
pressed:

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

Modifiers

Notes

1

[`keydown`](#keydown)

`"`[`Control`](http://www.w3.org/TR/uievents-key/#key-Control)`"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey)

2

[`keydown`](#keydown)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey),
[`shiftKey`](#dom-keyboardevent-shiftkey)

3

[`keydown`](#keydown)

`"V"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey),
[`shiftKey`](#dom-keyboardevent-shiftkey)

Latin Capital Letter V

*No [`beforeinput`](#beforeinput) or [`input`](#input)
events are generated.*

4

[`keyup`](#keyup)

`"V"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey),
[`shiftKey`](#dom-keyboardevent-shiftkey)

Latin Capital Letter V

5

[`keyup`](#keyup)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey)

6

[`keyup`](#keyup)

`"`[`Control`](http://www.w3.org/TR/uievents-key/#key-Control)`"`

For non-US keyboard layouts, the
sequence of events is the same, but the value of the key is based on the
current keyboard layout. This example shows a sequence of events when an
Arabic keyboard layout is used:

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

Modifiers

Notes

1

[`keydown`](#keydown)

`"`[`Control`](http://www.w3.org/TR/uievents-key/#key-Control)`"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey)

2

[`keydown`](#keydown)

`"ر"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey)

Arabic Letter Reh

*No [`beforeinput`](#beforeinput) or [`input`](#input)
events are generated.*

3

[`keyup`](#keyup)

`"ر"`

[`ctrlKey`](#dom-keyboardevent-ctrlkey)

Arabic Letter Reh

4

[`keyup`](#keyup)

`"`[`Control`](http://www.w3.org/TR/uievents-key/#key-Control)`"`

The value in the [`keydown`](#keydown) and [`keyup`](#keyup)
events varies based on the current keyboard layout in effect when the
key is pressed. This means that the `v` key on a US layout and
the `ر` key on an Arabic layout will generate different events
even though they are the same physical key. To identify these events as
coming from the same physical key, you will need to make use of the
[`code`](#dom-keyboardevent-code) attribute.

In some cases, [modifier keys](#modifier-key) change the
[`key`](#dom-keyboardevent-key) value for a key event. For example, on some MacOS
keyboards, the key labeled \"delete\" functions the same as the
`Backspace` key on the Windows OS when unmodified, but when
modified by the `Fn` key, acts as the `Delete` key,
and the value of
[`key`](#dom-keyboardevent-key) will match the most appropriate function of the key in
its current modified state.

#### 4.3.2. Dead keys

Some keyboard input uses [dead keys](#dead-key) for the input of composed character sequences. Unlike
the handwriting sequence, in which users enter the base character first,
keyboard input requires to enter a special state when a [dead
key](#dead-key) is pressed and emit
the character(s) only when one of a limited number of "legal" base
character is entered.

The MacOS and Linux operating systems use input methods to process [dead
keys](#dead-key).

The [dead keys](#dead-key) (across
all keyboard layouts and mappings) are represented by the key value
`Dead`. In response to any dead key press, [composition
events](#composition-events) must be dispatched by the user agent and the
[`compositionupdate`](#compositionupdate) event's
[`data`](#dom-compositionevent-data) value must be the character value of the current state
of the dead key combining sequence.

While Unicode combining characters always follow the handwriting
sequence, with the combining character trailing the corresponding
letter, typical dead key input MAY reverse the sequence, with the
combining character before the corresponding letter. For example, the
word *naïve*, using the combining diacritic *¨*, would be represented
sequentially in Unicode as *nai¨ve*, but MAY be typed *na¨ive*. The
sequence of keystrokes `U+0302` (Combining Circumflex Accent
key) and `U+0065` (key marked with the Latin Small Letter E)
will likely produce (on a French keyboard using a french mapping and
without any modifier activated) the Unicode character `"ê"`
(Latin Small Letter E With Circumflex), as preferred by the Unicode
Normalization Form *NFC*.

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`KeyboardEvent`](#keyboardevent)\
[`isComposing`](#dom-keyboardevent-iscomposing)

[`CompositionEvent`](#compositionevent)\
[`data`](#dom-compositionevent-data)

Notes

1

[`keydown`](#keydown)

`"`[`Dead`](http://www.w3.org/TR/uievents-key/#key-Dead)`"`

`false`

Combining Circumflex Accent (Dead Key)

2

[`compositionstart`](#compositionstart)

`""`

3

[`compositionupdate`](#compositionupdate)

`U+0302`

4

[`keyup`](#keyup)

`"`[`Dead`](http://www.w3.org/TR/uievents-key/#key-Dead)`"`

`true`

5

[`keydown`](#keydown)

`"ê"`

`true`

6

[`compositionupdate`](#compositionupdate)

`"ê"`

7

[`compositionend`](#compositionend)

`"ê"`

8

[`keyup`](#keyup)

`"e"`

`false`

Latin Small Letter E

In the second [`keydown`](#keydown)
event (step 5), the key value (assuming the event is not suppressed)
will *not* be `"e"` (Latin Small Letter E key) under normal
circumstances because the value delivered to the user agent will already
be modified by the dead key operation.

This process might be aborted when a user types an unsupported base
character (that is, a base character for which the active diacritical
mark is not available) after pressing a [dead
key](#dead-key):

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`KeyboardEvent`](#keyboardevent)\
[`isComposing`](#dom-keyboardevent-iscomposing)

[`CompositionEvent`](#compositionevent)\
[`data`](#dom-compositionevent-data)

Notes

1

[`keydown`](#keydown)

`"`[`Dead`](http://www.w3.org/TR/uievents-key/#key-Dead)`"`

`false`

Combining Circumflex Accent (Dead Key)

2

[`compositionstart`](#compositionstart)

`""`

3

[`compositionupdate`](#compositionupdate)

`U+0302`

4

[`keyup`](#keyup)

`"`[`Dead`](http://www.w3.org/TR/uievents-key/#key-Dead)`"`

`true`

5

[`keydown`](#keydown)

`"q"`

`true`

Latin Small Letter Q

6

[`compositionupdate`](#compositionupdate)

`""`

7

[`compositionend`](#compositionend)

`""`

8

[`keyup`](#keyup)

`"q"`

`false`

#### 4.3.3. Input Method Editors

This specification includes a model for [input method
editors](#input-method-editor) (IMEs), through the
[`CompositionEvent`](#compositionevent) interface and events. However, Composition Events and
Keyboard Events do not necessarily map as a one-to-one relationship. As
an example, receiving a [`keydown`](#keydown) for the `Accept` key value does not
necessarily imply that the text currently selected in the
[IME](#ime) is being accepted, but
indicates only that a keystroke happened, disconnected from the
[IME](#ime) Accept functionality (which
would normally result in a
[`compositionend`](#compositionend) event in most [IME](#ime) systems). Keyboard events cannot be used to determine
the current state of the input method editor, which can be obtained
through the
[`data`](#dom-compositionevent-data) attribute of the
[`CompositionEvent`](#compositionevent) interface. Additionally, [IME](#ime) systems and devices vary in their functionality, and in
which keys are used for activating that functionality, such that the
`Convert` and `Accept` keys MAY be represented by
other available keys. Keyboard events correspond to the events generated
by the input device after the keyboard layout mapping.

In some implementations or system configurations, some key events, or
their values, might be suppressed by the [IME](#ime) in use.

The following example describes a possible sequence of keys to generate
the Unicode character `"市"` (Kanji character, part of CJK
Unified Ideographs) using Japanese input methods. This example assumes
that the input method editor is activated and in the Japanese-Romaji
input mode. The keys `Convert` and `Accept` MAY be
replaced by others depending on the input device in use and the
configuration of the IME, e.g., it can be respectively
`U+0020` (Space key) and `Enter`.

`"詩"` ("poem") and `"市"` ("city") are homophones, both
pronounced し ("shi"/"si"), so the user needs to use the
`Convert` key to select the proper option.

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`KeyboardEvent`](#keyboardevent)\
[`isComposing`](#dom-keyboardevent-iscomposing)

[`CompositionEvent`](#compositionevent)\
[`data`](#dom-compositionevent-data)

Notes

1

[`keydown`](#keydown)

`"s"`

`false`

Latin Small Letter S

2

[`compositionstart`](#compositionstart)

`""`

3

[`beforeinput`](#beforeinput)

4

[`compositionupdate`](#compositionupdate)

`"s"`

DOM is updated

5

[`input`](#input)

6

[`keyup`](#keyup)

`"s"`

`true`

7

[`keydown`](#keydown)

`"i"`

`true`

Latin Small Letter I

8

[`beforeinput`](#beforeinput)

9

[`compositionupdate`](#compositionupdate)

`"し"`

*shi*

DOM is updated

10

[`input`](#input)

11

[`keyup`](#keyup)

`"i"`

`true`

12

[`keydown`](#keydown)

`"`[`Convert`](http://www.w3.org/TR/uievents-key/#key-Convert)`"`

`true`

Convert

13

[`beforeinput`](#beforeinput)

14

[`compositionupdate`](#compositionupdate)

`"詩"`

\"poem\"

DOM is updated

15

[`input`](#input)

16

[`keyup`](#keyup)

`"`[`Convert`](http://www.w3.org/TR/uievents-key/#key-Convert)`"`

`true`

17

[`keydown`](#keydown)

`"`[`Convert`](http://www.w3.org/TR/uievents-key/#key-Convert)`"`

`true`

Convert

18

[`beforeinput`](#beforeinput)

19

[`compositionupdate`](#compositionupdate)

`"市"`

\"city\"

DOM is updated

20

[`input`](#input)

21

[`keyup`](#keyup)

`"`[`Convert`](http://www.w3.org/TR/uievents-key/#key-Convert)`"`

`true`

22

[`keydown`](#keydown)

`"`[`Accept`](http://www.w3.org/TR/uievents-key/#key-Accept)`"`

`true`

Accept

23

[`compositionend`](#compositionend)

`"市"`

24

[`keyup`](#keyup)

`"`[`Accept`](http://www.w3.org/TR/uievents-key/#key-Accept)`"`

`false`

IME composition can also be canceled as in the following example, with
conditions identical to the previous example. The key `Cancel`
might also be replaced by others depending on the input device in use
and the configuration of the IME, e.g., it could be `U+001B`
(Escape key).

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`KeyboardEvent`](#keyboardevent)\
[`isComposing`](#dom-keyboardevent-iscomposing)

[`CompositionEvent`](#compositionevent)\
[`data`](#dom-compositionevent-data)

Notes

1

[`keydown`](#keydown)

`"s"`

`false`

Latin Small Letter S

2

[`compositionstart`](#compositionstart)

`""`

3

[`compositionupdate`](#compositionupdate)

`"s"`

4

[`keyup`](#keyup)

`"s"`

`true`

5

[`keydown`](#keydown)

`"i"`

`true`

Latin Small Letter I

6

[`compositionupdate`](#compositionupdate)

`"し"`

*shi*

7

[`keyup`](#keyup)

`"i"`

`true`

8

[`keydown`](#keydown)

`"`[`Convert`](http://www.w3.org/TR/uievents-key/#key-Convert)`"`

`true`

Convert

9

[`compositionupdate`](#compositionupdate)

`"詩"`

\"poem\"

10

[`keyup`](#keyup)

`"`[`Convert`](http://www.w3.org/TR/uievents-key/#key-Convert)`"`

`true`

11

[`keydown`](#keydown)

`"`[`Convert`](http://www.w3.org/TR/uievents-key/#key-Convert)`"`

`true`

Convert

12

[`compositionupdate`](#compositionupdate)

`"市"`

\"city\"

13

[`keyup`](#keyup)

`"`[`Convert`](http://www.w3.org/TR/uievents-key/#key-Convert)`"`

`true`

14

[`keydown`](#keydown)

`"`[`Cancel`](http://www.w3.org/TR/uievents-key/#key-Cancel)`"`

`true`

Cancel

15

[`compositionupdate`](#compositionupdate)

`""`

16

[`compositionend`](#compositionend)

`""`

17

[`keyup`](#keyup)

`"`[`Cancel`](http://www.w3.org/TR/uievents-key/#key-Cancel)`"`

`false`

Some [input method
editors](#input-method-editor) (such as on the MacOS operating system) might set an
[empty string](#empty-string) to
the composition data attribute before canceling a composition.

##### 4.3.3.1. Input Method Editor mode keys

Some keys on certain devices are intended to activate [input method
editor](#input-method-editor) functionality, or to change the mode of an active
[input method
editor](#input-method-editor). Custom keys for this purpose can be defined for
different devices or language modes. The keys defined in this
specification for this purpose are:
`"`[`Alphanumeric`](http://www.w3.org/TR/uievents-key/#key-Alphanumeric)`"`,
`"`[`CodeInput`](http://www.w3.org/TR/uievents-key/#key-CodeInput)`"`,
`"`[`FinalMode`](http://www.w3.org/TR/uievents-key/#key-FinalMode)`"`,
`"`[`HangulMode`](http://www.w3.org/TR/uievents-key/#key-HangulMode)`"`,
`"`[`HanjaMode`](http://www.w3.org/TR/uievents-key/#key-HanjaMode)`"`,
`"`[`Hiragana`](http://www.w3.org/TR/uievents-key/#key-Hiragana)`"`,
`"`[`JunjaMode`](http://www.w3.org/TR/uievents-key/#key-JunjaMode)`"`,
`"`[`KanaMode`](http://www.w3.org/TR/uievents-key/#key-KanaMode)`"`,
`"`[`KanjiMode`](http://www.w3.org/TR/uievents-key/#key-KanjiMode)`"`,
`"`[`Katakana`](http://www.w3.org/TR/uievents-key/#key-Katakana)`"`,
and
`"`[`Romaji`](http://www.w3.org/TR/uievents-key/#key-Romaji)`"`.
When one of these keys is pressed, and no [IME](#ime) is currently active, the appropriate
[IME](#ime) is expected to be activated
in the mode indicated by the key (if available). If an
[IME](#ime) is already active when the
key is pressed, the active [IME](#ime)
might change to the indicated mode, or a different
[IME](#ime) might be launched, or the
might MAY be ignored, on a device- and application-specific basis.

This specification also defines other keys which are intended for
operation specifically with [input method
editors](#input-method-editor):
`"`[`Accept`](http://www.w3.org/TR/uievents-key/#key-Accept)`"`,
`"`[`AllCandidates`](http://www.w3.org/TR/uievents-key/#key-AllCandidates)`"`,
`"`[`Cancel`](http://www.w3.org/TR/uievents-key/#key-Cancel)`"`,
`"`[`Convert`](http://www.w3.org/TR/uievents-key/#key-Convert)`"`,
`"`[`Compose`](http://www.w3.org/TR/uievents-key/#key-Compose)`"`,
`"`[`Zenkaku`](http://www.w3.org/TR/uievents-key/#key-Zenkaku)`"`
(FullWidth),
`"`[`Hankaku`](http://www.w3.org/TR/uievents-key/#key-Hankaku)`"`
(HalfWidth),
`"`[`NextCandidate`](http://www.w3.org/TR/uievents-key/#key-NextCandidate)`"`,
`"`[`NonConvert`](http://www.w3.org/TR/uievents-key/#key-NonConvert)`"`,
and
`"`[`PreviousCandidate`](http://www.w3.org/TR/uievents-key/#key-PreviousCandidate)`"`.
The functions of these keys are not defined in this specification ---
refer to other resources for details on [input method
editor](#input-method-editor) functionality.

Keys with [input method
editor](#input-method-editor) functions are not restricted to that purpose, and can
have other device- or implementation-specific purposes.

#### 4.3.4. Default actions and cancelable keyboard events

Canceling the [default action](#default-action) of a [`keydown`](#keydown) event MUST NOT affect its respective
[`keyup`](#keyup) event, but it MUST
prevent the respective
[`beforeinput`](#beforeinput)
and [`input`](#input) (and
[`keypress`](#keypress) if
supported) events from being generated. The following example describes
a possible sequence of keys to generate the Unicode character Q (Latin
Capital Letter Q) on a US keyboard using a US mapping:

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`InputEvent`](#inputevent)\
[`data`](#dom-inputevent-data)

Modifiers

Notes

1

[`keydown`](#keydown)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

2

[`keydown`](#keydown)

`"Q"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

The [default action](#default-action) is prevented, e.g., by invoking
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault).

*No [`beforeinput`](#beforeinput) or [`input`](#input)
(or [`keypress`](#keypress), if
supported) events are generated*

3

[`keyup`](#keyup)

`"Q"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

4

[`keyup`](#keyup)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

If the key is a modifier key, the keystroke MUST still be taken into
account for the modifiers states. The following example describes a
possible sequence of keys to generate the Unicode character Q (Latin
Capital Letter Q) on a US keyboard using a US mapping:

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`InputEvent`](#inputevent)\
[`data`](#dom-inputevent-data)

Modifiers

Notes

1

[`keydown`](#keydown)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

The [default action](#default-action) is prevented, e.g., by invoking
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault).

2

[`keydown`](#keydown)

`"Q"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

3

[`beforeinput`](#beforeinput)

`"Q"`

4

[`input`](#input)

5

[`keyup`](#keyup)

`"Q"`

[`shiftKey`](#dom-keyboardevent-shiftkey)

6

[`keyup`](#keyup)

`"`[`Shift`](http://www.w3.org/TR/uievents-key/#key-Shift)`"`

If the key is part of a sequence of several keystrokes, whether it is a
[dead key](#dead-key) or it is
contributing to an Input Method Editor sequence, the keystroke MUST be
ignored (not taken into account) only if the [default
action](#default-action) is
canceled on the [`keydown`](#keydown) event. Canceling a [dead
key](#dead-key) on a
[`keyup`](#keyup) event has no effect
on [`beforeinput`](#beforeinput)
or [`input`](#input) events. The
following example uses the dead key
`"`[`Dead`](http://www.w3.org/TR/uievents-key/#key-Dead)`"`
(`U+0302` Combining Circumflex Accent key) and `"e"`
(`U+0065`, Latin Small Letter E key) on a French keyboard
using a French mapping and without any modifier activated:

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`InputEvent`](#inputevent)\
[`data`](#dom-inputevent-data)

Notes

1

[`keydown`](#keydown)

`"`[`Dead`](http://www.w3.org/TR/uievents-key/#key-Dead)`"`

The [default action](#default-action) is prevented, e.g., by invoking
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault).

2

[`keyup`](#keyup)

`"`[`Dead`](http://www.w3.org/TR/uievents-key/#key-Dead)`"`

3

[`keydown`](#keydown)

`"e"`

4

[`beforeinput`](#beforeinput)

`"e"`

5

[`input`](#input)

6

[`keyup`](#keyup)

`"e"`

## 5. External Algorithms

This sections contains algorithms that are required by this
specification, but are more properly hosted by other specifications.

The intent is that this sections serve as a temporary home for these
definitions, and they should eventually be moved into a more appropriate
home so this entire section can be deleted.

### 5.1. Core DOM Algorithms

The following algorithms should be moved\... somewhere.

### 5.2. PointerLock Algorithms

The following algorithm should be moved into the
[\[PointerLock\]](#biblio-pointerlock "Pointer Lock 2.0")
spec.

#### 5.2.1. Global State for PointerLock

##### 5.2.1.1. Window-Level State

The UA must maintain the following values that are shared for the
Window.

A [last mouse move] value (initially undefined) that records the position of
the last mousemove event.

#### [5.2.2. ][[initialize PointerLock attributes for MouseEvent]]
Input

: `event`, a
 [`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent)

Output

: None

1. Set
 `event`.[`movementX`](https://w3c.github.io/pointerlock/#dom-mouseevent-movementx) = 0

2. Set
 `event`.[`movementY`](https://w3c.github.io/pointerlock/#dom-mouseevent-movementy) = 0

#### [5.2.3. ][[set PointerLock attributes for mousemove]]
Input

: `event`, a
 [`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent)

Output

: None

1. If
 `event`.[`type`](https://dom.spec.whatwg.org/#dom-event-type) is not \"mousemove\", then exit

2. If [last mouse move](#last-mouse-move) is not defined, then

 1. Set
 `event`.[`movementX`](https://w3c.github.io/pointerlock/#dom-mouseevent-movementx) = 0

 2. Set
 `event`.[`movementY`](https://w3c.github.io/pointerlock/#dom-mouseevent-movementy) = 0

3. Otherwise,

 1. Set
 `event`.[`movementX`](https://w3c.github.io/pointerlock/#dom-mouseevent-movementx) =
 `event`.[`screenX`](https://w3c.github.io/pointerevents/#dom-mouseevent-screenx) - [last mouse
 move](#last-mouse-move)'s x-coordinate

 2. Set
 `event`.[`movementY`](https://w3c.github.io/pointerlock/#dom-mouseevent-movementy) =
 `event`.[`screenX`](https://w3c.github.io/pointerevents/#dom-mouseevent-screenx) - [last mouse
 move](#last-mouse-move)'s y-coordinate

4. Set [last mouse move](#last-mouse-move) = (
 `event`.[`screenX`](https://w3c.github.io/pointerevents/#dom-mouseevent-screenx),
 `event`.[`screenY`](https://w3c.github.io/pointerevents/#dom-mouseevent-screeny) )

## 6. Legacy Event Initializers

*This section is normative. The following features are obsolete and
should only be implemented by [user
agents](https://infra.spec.whatwg.org/#user-agent) that require compatibility with legacy software.*

Early versions of this specification included an initialization method
on the interface (for example `initMouseEvent`) that required a long
list of parameters that, in most cases, did not fully initialize all
attributes of the event object. Because of this, event interfaces which
were derived from the basic
[`Event`](https://dom.spec.whatwg.org/#event) interface required that the initializer of *each* of
the derived interfaces be called explicitly in order to fully initialize
an event.

Initializing all the attributes of a
UIEvent requires calls to two initializer methods: `initEvent` and
`initUIEvent`.

Due in part to the length of time in the development of this standard,
some implementations MAY have taken a dependency on these (now
deprecated) initializer methods. For completeness, these legacy event
initializers are described in this Appendix.

### 6.1. Legacy Event Initializer Interfaces

*This section is informative*

This section documents legacy initializer methods that were introduced
in earlier versions of this specification.

#### 6.1.1. Initializers for interface UIEvent

```
partial interface UIEvent {
 // Deprecated in this specification
 undefined initUIEvent(DOMString typeArg,
 optional boolean bubblesArg = false,
 optional boolean cancelableArg = false,
 optional Window? viewArg = null,
 optional long detailArg = 0);
};
```

[`initUIEvent(typeArg)`]

: Initializes attributes of an
 [`UIEvent`](#uievent)
 object. This method has the same behavior as
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent).

 The `initUIEvent` method is deprecated, but supported for
 backwards-compatibility with widely-deployed implementations.

 DOMString typeArg
 : Refer to the
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent) method for a description of this parameter.

 boolean bubblesArg
 : Refer to the
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent) method for a description of this parameter.

 boolean cancelableArg
 : Refer to the
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent) method for a description of this parameter.

 Window? viewArg
 : Specifies
 [`view`](#dom-uievent-view). This value MAY be `null`.

 long detailArg
 : Specifies
 [`detail`](#dom-uievent-detail).

#### 6.1.2. Initializers for interface KeyboardEvent

The argument list to this legacy KeyboardEvent initializer does not
include the `detailArg` (present in other initializers) and adds the
`locale` argument; it is necessary to preserve this inconsistency for
compatibility with existing implementations.

```
partial interface KeyboardEvent {
 // Originally introduced (and deprecated) in this specification
 undefined initKeyboardEvent(DOMString typeArg,
 optional boolean bubblesArg = false,
 optional boolean cancelableArg = false,
 optional Window? viewArg = null,
 optional DOMString keyArg = "",
 optional unsigned long locationArg = 0,
 optional boolean ctrlKey = false,
 optional boolean altKey = false,
 optional boolean shiftKey = false,
 optional boolean metaKey = false);
};
```

[`initKeyboardEvent(typeArg)`]

: Initializes attributes of a
 [`KeyboardEvent`](#keyboardevent) object. This method has the same behavior as
 `UIEvent.initUIEvent()`. The value of
 [`detail`](#dom-uievent-detail) remains undefined.

 The `initKeyboardEvent` method is deprecated.

 DOMString typeArg
 : Refer to the
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent) method for a description of this parameter.

 boolean bubblesArg
 : Refer to the
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent) method for a description of this parameter.

 boolean cancelableArg
 : Refer to the
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent) method for a description of this parameter.

 Window? viewArg
 : Specifies
 [`view`](#dom-uievent-view). This value MAY be `null`.

 DOMString keyArg
 : Specifies
 [`key`](#dom-keyboardevent-key).

 unsigned long locationArg
 : Specifies
 [`location`](#dom-keyboardevent-location).

 boolean ctrlKey
 : Specifies whether the Control key modifier is active.

 boolean altKey
 : Specifies whether the Alt key modifier is active.

 boolean shiftKey
 : Specifies whether the Shift key modifier is active.

 boolean metaKey
 : Specifies whether the Meta key modifier is active.

#### 6.1.3. Initializers for interface CompositionEvent

The argument list to this legacy CompositionEvent initializer does not
include the `detailArg` (present in other initializers) and adds the
`locale` argument; it is necessary to preserve this inconsistency for
compatibility with existing implementations.

```
partial interface CompositionEvent {
 // Originally introduced (and deprecated) in this specification
 undefined initCompositionEvent(DOMString typeArg,
 optional boolean bubblesArg = false,
 optional boolean cancelableArg = false,
 optional WindowProxy? viewArg = null,
 optional DOMString dataArg = "");
};
```

[`initCompositionEvent(typeArg)`]

: Initializes attributes of a `CompositionEvent` object. This method
 has the same behavior as `UIEvent.initUIEvent()`. The value of
 [`detail`](#dom-uievent-detail) remains undefined.

 The `initCompositionEvent` method is deprecated.

 DOMString typeArg
 : Refer to the
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent) method for a description of this parameter.

 boolean bubblesArg
 : Refer to the
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent) method for a description of this parameter.

 boolean cancelableArg
 : Refer to the
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent) method for a description of this parameter.

 Window? viewArg
 : Specifies
 [`view`](#dom-uievent-view). This value MAY be `null`.

 DOMString dataArg
 : Specifies
 [`data`](#dom-compositionevent-data).

## 7. Legacy Key & Mouse Event Attributes

*This section is non-normative. The following attributes are obsolete
and should only be implemented by [user
agents](https://infra.spec.whatwg.org/#user-agent) that require compatibility with legacy software that
requires these keyboard events.*

These features were never formally specified and the current browser
implementations vary in significant ways. The large amount of legacy
content, including script libraries, that relies upon detecting the
[user
agent](https://infra.spec.whatwg.org/#user-agent) and acting accordingly means that any attempt to
formalize these legacy attributes and events would risk breaking as much
content as it would fix or enable. Additionally, these attributes are
not suitable for international usage, nor do they address accessibility
concerns.

Therefore, this specification does not normatively define the events and
attributes commonly employed for handling keyboard input, though they
MAY be present in [user
agents](https://infra.spec.whatwg.org/#user-agent) for compatibility with legacy content. Authors SHOULD
use the
[`key`](#dom-keyboardevent-key) attribute instead of the
[`charCode`](#dom-keyboardevent-charcode) and
[`keyCode`](#dom-keyboardevent-keycode) attributes.

However, for the purpose of documenting the current state of these
features and their relation to normative events and attributes, this
section provides an informative description. For implementations which
do support these attributes and events, it is suggested that the
definitions provided in this section be used.

### 7.1. Legacy [`UIEvent` supplemental interface]
*This section is non-normative*

[User
agents](https://infra.spec.whatwg.org/#user-agent) have traditionally included a
[`which`](#dom-uievent-which) attribute so that
[`KeyboardEvent`](#keyboardevent)s and
[`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent)s could record supplemental event info.

Previous versions of this specification defined separate
[`which`](#dom-uievent-which) attributes directly on
[`KeyboardEvent`](#keyboardevent) and
[`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) rather than having a shared
[`which`](#dom-uievent-which) attribute defined on
[`UIEvent`](#uievent).

#### 7.1.1. Interface UIEvent (supplemental)

The partial [`UIEvent`](#uievent) interface is an informative extension of the
[`UIEvent`](#uievent)
interface, which adds the
[`which`](#dom-uievent-which) attribute.

```
partial interface UIEvent {
 // The following support legacy user agents
 readonly attribute unsigned long which;
};
```

[`which`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly
: For
 [`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent)s, this contains a value equal to the value stored
 in
 [`button`](https://w3c.github.io/pointerevents/#dom-mouseevent-button)+1. For
 [`KeyboardEvent`](#keyboardevent)s, this holds a system- and implementation-dependent
 numerical code signifying the unmodified identifier associated with
 the key pressed. In most cases, the value is identical to
 [`keyCode`](#dom-keyboardevent-keycode).

#### 7.1.2. Interface UIEventInit (supplemental)

Browsers that include support for
[`which`](#dom-uievent-which) in [`UIEvent`](#uievent) should also add the following members to the
[`UIEventInit`](#dictdef-uieventinit) dictionary.

The partial
[`UIEventInit`](#dictdef-uieventinit) dictionary is an informative extension of the
[`UIEventInit`](#dictdef-uieventinit) dictionary, which adds the
[`which`](#dom-uievent-which) member to initialize the corresponding
[`UIEvent`](#uievent)
attributes.

```
partial dictionary UIEventInit {
 unsigned long which = 0;
};
```

[`which`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `0`
: Initializes the
 [`which`](#dom-uievent-which) attribute of the
 [`UIEvent`](#uievent).

### 7.2. Legacy [`KeyboardEvent` supplemental interface]
*This section is non-normative*

Browser support for keyboards has traditionally relied on three ad-hoc
attributes,
[`keyCode`](#dom-keyboardevent-keycode),
[`charCode`](#dom-keyboardevent-charcode), and [`UIEvent`](#uievent)'s
[`which`](#dom-uievent-which).

All three of these attributes return a numerical code that represents
some aspect of the key pressed:
[`keyCode`](#dom-keyboardevent-keycode) is an index of the key itself.
[`charCode`](#dom-keyboardevent-charcode) is the ASCII value of the character keys.
[`which`](#dom-uievent-which) is the character value where available and otherwise
the key index. The values for these attributes, and the availability of
the attribute, is inconsistent across platforms, keyboard languages and
layouts, [user
agents](https://infra.spec.whatwg.org/#user-agent), versions, and even event types.

#### 7.2.1. Interface KeyboardEvent (supplemental)

The partial
[`KeyboardEvent`](#keyboardevent) interface is an informative extension of the
[`KeyboardEvent`](#keyboardevent) interface, which adds the
[`charCode`](#dom-keyboardevent-charcode) and
[`keyCode`](#dom-keyboardevent-keycode) attributes.

The partial
[`KeyboardEvent`](#keyboardevent) interface can be obtained by using the
[`createEvent()`](https://dom.spec.whatwg.org/#dom-document-createevent) method call in implementations that support this
extension.

```
partial interface KeyboardEvent {
 // The following support legacy user agents
 readonly attribute unsigned long charCode;
 readonly attribute unsigned long keyCode;
};
```

[`charCode`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly
: [`charCode`](#dom-keyboardevent-charcode) holds a character value, for
 [`keypress`](#keypress) events
 which generate character input. The value is the Unicode reference
 number (code point) of that character (e.g.
 `event.charCode = event.key.charCodeAt(0)` for printable
 characters). For [`keydown`](#keydown) or [`keyup`](#keyup) events, the value of
 [`charCode`](#dom-keyboardevent-charcode) is `0`.

[`keyCode`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: [`keyCode`](#dom-keyboardevent-keycode) holds a system- and implementation-dependent
 numerical code signifying the unmodified identifier associated with
 the key pressed. Unlike the
 [`key`](#dom-keyboardevent-key) attribute, the set of possible values are not
 normatively defined in this specification. Typically, these value of
 the
 [`keyCode`](#dom-keyboardevent-keycode) SHOULD represent the decimal codepoint in ASCII
 [\[RFC20\]](#biblio-rfc20 "ASCII format for network interchange")[\[US-ASCII\]](#biblio-us-ascii "Coded Character Set - 7-Bit American Standard Code for Information Interchange")
 or Windows 1252
 [\[WIN1252\]](#biblio-win1252 "Windows 1252 a Coded Character Set - 8-Bit"),
 but MAY be drawn from a different appropriate character set.
 Implementations that are unable to identify a key use the key value
 `0`.

 See [§ 7.3 Legacy key models](#legacy-key-models) for more details
 on how to determine the values for
 [`keyCode`](#dom-keyboardevent-keycode).

#### 7.2.2. Interface KeyboardEventInit (supplemental)

Browsers that include support for
[`keyCode`](#dom-keyboardevent-keycode) and
[`charCode`](#dom-keyboardevent-charcode) in
[`KeyboardEvent`](#keyboardevent) should also add the following members to the
[`KeyboardEventInit`](#dictdef-keyboardeventinit) dictionary.

The partial
[`KeyboardEventInit`](#dictdef-keyboardeventinit) dictionary is an informative extension of the
[`KeyboardEventInit`](#dictdef-keyboardeventinit) dictionary, which adds
[`charCode`](#dom-keyboardevent-charcode) and
[`keyCode`](#dom-keyboardevent-keycode) members to initialize the corresponding
[`KeyboardEvent`](#keyboardevent) attributes.

```
partial dictionary KeyboardEventInit {
 // The following support legacy user agents
 unsigned long charCode = 0;
 unsigned long keyCode = 0;
};
```

[`charCode`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `0`
: Initializes the
 [`charCode`](#dom-keyboardevent-charcode) attribute of the
 [`KeyboardEvent`](#keyboardevent) to the Unicode code point for the event's
 character.

[`keyCode`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `0`
: Initializes the
 [`keyCode`](#dom-keyboardevent-keycode) attribute of the
 [`KeyboardEvent`](#keyboardevent) to the system- and implementation-dependent
 numerical code signifying the unmodified identifier associated with
 the key pressed.

### 7.3. Legacy key models

*This section is non-normative*

Implementations differ on which values are exposed on these attributes
for different event types. An implementation MAY choose to expose both
virtual key codes and character codes in the
[`keyCode`](#dom-keyboardevent-keycode) property (*conflated model*), or report separate
[`keyCode`](#dom-keyboardevent-keycode) and
[`charCode`](#dom-keyboardevent-charcode) properties (*split model*).

#### 7.3.1. How to determine [`keyCode` for [`keydown`](#keydown) and [`keyup`](#keyup) events]
The
[`keyCode`](#dom-keyboardevent-keycode) for [`keydown`](#keydown) or [`keyup`](#keyup)
events is calculated as follows:

- Read the virtual key code from the operating system's event
 information, if such information is available.

- If an Input Method Editor is processing key input and the event is
 [`keydown`](#keydown), return 229.

- If input key when pressed without modifiers would insert a numerical
 character (0-9), return the ASCII code of that numerical character.

- If input key when pressed without modifiers would insert a lower case
 character in the a-z alphabetical range, return the ASCII code of the
 upper case equivalent.

- If the implementation supports a key code conversion table for the
 operating system and platform, look up the value. If the conversion
 table specifies an alternate virtual key value for the given input,
 return the specified value.

- If the key's function, as determined in an implementation-specific
 way, corresponds to one of the keys in the [§ 7.3.3 Fixed virtual key
 codes](#fixed-virtual-key-codes) table, return the corresponding key
 code.

- Return the virtual key code from the operating system.

- If no key code was found, return 0.

#### 7.3.2. How to determine [`keyCode` for [`keypress`](#keypress) events]
The
[`keyCode`](#dom-keyboardevent-keycode) for [`keypress`](#keypress) events is calculated as follows:

- If the implementation supports a *conflated model*, set
 [`keyCode`](#dom-keyboardevent-keycode) to the Unicode code point of the character being
 entered.

- If the implementation supports a *split model*, set
 [`keyCode`](#dom-keyboardevent-keycode) to 0.

#### 7.3.3. Fixed virtual key codes

The virtual key codes for the following keys do not usually change with
keyboard layouts on desktop systems:

Key

Virtual Key\
Code

Notes

Backspace

8

Tab

9

Enter

13

Shift

16

Control

17

Alt

18

CapsLock

20

Escape

27

Esc

Space

32

PageUp

33

PageDown

34

End

35

Home

36

ArrowLeft

37

ArrowUp

38

ArrowRight

39

ArrowDown

40

Delete

46

Del

#### 7.3.4. Optionally fixed virtual key codes

The following punctuation characters MAY change virtual codes between
keyboard layouts, but reporting these values will likely be more
compatible with legacy content expecting US-English keyboard layout:

Key

Character

Virtual Key\
Code

Semicolon

`";"`

186

Colon

`":"`

186

Equals sign

`"="`

187

Plus

`"+"`

187

Comma

`","`

188

Less than sign

`"<"`

188

Minus

`"-"`

189

Underscore

`"_"`

189

Period

`"."`

190

Greater than sign

`">"`

190

Forward slash

`"/"`

191

Question mark

`"?"`

191

Backtick

`` "`" ``

192

Tilde

`"~"`

192

Opening squace bracket

`"["`

219

Opening curly brace

`"{"`

219

Backslash

`"\"`

220

Pipe

`"|"`

220

Closing square bracket

`"]"`

221

Closing curly brace

`"}"`

221

Single quote

`"'"`

222

Double quote

`"""`

222

## 8. Legacy Event Types

*This section is normative. The following event types are obsolete and
should only be implemented by [user
agents](https://infra.spec.whatwg.org/#user-agent) that require compatibility with legacy software.*

The purpose of this section is to document the current state of these
features and their relation to normative events. For implementations
which do support these events, it is suggested that the definitions
provided in this section be used.

The following table provides an informative summary of the event types
which are deprecated in this specification. They are included here for
reference and completeness.

Event Type

Sync / Async

Bubbling Phase

Trusted event target types

DOM Interface

Cancelable

Composed

Default Action

[`DOMActivate`](#domactivate)

Sync

Yes

`Element`

[`UIEvent`](#uievent)

Yes

Yes

None

[`DOMFocusIn`](#domfocusin)

Sync

Yes

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Element`

[`FocusEvent`](#focusevent)

No

Yes

None

[`DOMFocusOut`](#domfocusout)

Sync

Yes

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Element`

[`FocusEvent`](#focusevent)

No

Yes

None

[`keypress`](#keypress)

Sync

Yes

`Element`

[`KeyboardEvent`](#keyboardevent)

Yes

Yes

Varies: launch [text composition
system](#text-composition-system); [`blur`](#blur) and
[`focus`](#focus) events;
[`DOMActivate`](#domactivate)
event; other event

[`textInput`](#textinput)

Sync

Yes

`Element`

[`TextEvent`](#textevent)

Yes

Yes

See definition

### 8.1. Legacy [`UIEvent` events]
#### 8.1.1. Legacy [`UIEvent` event types]
##### [8.1.1.1. ][[DOMActivate]]
Type

**`DOMActivate`**

Interface

[`UIEvent`](#uievent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

`Element`

Cancelable

Yes

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : element being activated
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when a button, link, or other
state-changing element is activated.

The [`DOMActivate`](#domactivate)
[event type](#event-type) is
defined in this specification for reference and completeness, but this
specification [deprecates](#deprecates) the use of this event type in favor of the related
[event type](#event-type)
[`click`](https://w3c.github.io/pointerevents/#dfn-click). Other specifications MAY define and
maintain their own [`DOMActivate`](#domactivate) [event type](#event-type) for backwards compatibility.

While
[`DOMActivate`](#domactivate) and
[`click`](https://w3c.github.io/pointerevents/#dfn-click) are not completely equivalent, implemented
behavior for the
[`click`](https://w3c.github.io/pointerevents/#dfn-click) [event
type](#event-type) has developed
to encompass the most critical accessibility aspects for which the
[`DOMActivate`](#domactivate)
[event type](#event-type) was
designed, and is more widely implemented. Content authors are encouraged
to use the
[`click`](https://w3c.github.io/pointerevents/#dfn-click) [event
type](#event-type) rather than
the related
[`mousedown`](https://w3c.github.io/pointerevents/#dfn-mousedown) or
[`mouseup`](https://w3c.github.io/pointerevents/#dfn-mouseup) [event
type](#event-type) to ensure
maximum accessibility.

Implementations which support the
[`DOMActivate`](#domactivate)
[event type](#event-type) SHOULD
also dispatch a [`DOMActivate`](#domactivate) event as a [default
action](#default-action) of a
[`click`](https://w3c.github.io/pointerevents/#dfn-click) event which is associated with an
[activation trigger](#activation-trigger). However, such implementations SHOULD only initiate the
associated [activation
behavior](https://dom.spec.whatwg.org/#eventtarget-activation-behavior) once for any given occurrence of an [activation
trigger](#activation-trigger).

The [`DOMActivate`](#domactivate)
[event type](#event-type) is
REQUIRED to be supported for XForms
[\[XFORMS11\]](#biblio-xforms11 "XForms 1.1"), which
is intended for implementation within a [host
language](#host-language). In
a scenario where a plugin or script-based implementation of XForms is
intended for installation in a native implementation of this
specification which does not support the
[`DOMActivate`](#domactivate)
[event type](#event-type), the
XForms [user
agent](https://infra.spec.whatwg.org/#user-agent) has to synthesize and dispatch its own
[`DOMActivate`](#domactivate)
events based on the appropriate [activation
triggers](#activation-trigger).

Thus, when a
[`click`](https://w3c.github.io/pointerevents/#dfn-click) event is dispatched by a [user
agent](https://infra.spec.whatwg.org/#user-agent) conforming to UI Events, the XForms [user
agent](https://infra.spec.whatwg.org/#user-agent) has to determine whether to synthesize a
[`DOMActivate`](#domactivate)
event with the same relevant properties as a [default
action](#default-action) of
that
[`click`](https://w3c.github.io/pointerevents/#dfn-click) event. Appropriate cues might be whether
the
[`click`](https://w3c.github.io/pointerevents/#dfn-click) event
[`isTrusted`](https://dom.spec.whatwg.org/#dom-event-istrusted), or whether its [event
target](#event-target) has a
[`DOMActivate`](#domactivate)
[event
listener](https://dom.spec.whatwg.org/#concept-event-listener) registered.

Don't rely upon the interoperable support of
[`DOMActivate`](#domactivate) in
many [user
agents](https://infra.spec.whatwg.org/#user-agent). Instead, the
[`click`](https://w3c.github.io/pointerevents/#dfn-click) [event
type](#event-type) should be used
since it will provide more accessible behavior due to broader
implementation support.

The [`DOMActivate`](#domactivate) [event type](#event-type) is deprecated in this specification.

#### 8.1.2. Activation event order

If the `DOMActivate` event is supported by the [user
agent](https://infra.spec.whatwg.org/#user-agent), then the events MUST be dispatched in a set order
relative to each other: (with only pertinent events listed):

Event Type

Notes

1

[`click`](https://w3c.github.io/pointerevents/#dfn-click)

2

[`DOMActivate`](#domactivate)

[default action](#default-action), if supported by the [user
agent](https://infra.spec.whatwg.org/#user-agent); synthesized; `isTrusted="true"`

3

*All other [default actions](#default-action), including the [activation
behavior](https://dom.spec.whatwg.org/#eventtarget-activation-behavior)*

If the focused element is activated by a key event, then the following
shows the typical sequence of events (with only pertinent events
listed):

Event Type

Notes

1

[`keydown`](#keydown)

MUST be a key which can activate the element, such as the
`Enter` or `  ` (spacebar) key, or the element is not
activated

2

[`click`](https://w3c.github.io/pointerevents/#dfn-click)

[default action](#default-action); synthesized; `isTrusted="true"`

3

[`DOMActivate`](#domactivate)

[default action](#default-action), if supported by the [user
agent](https://infra.spec.whatwg.org/#user-agent); synthesized; `isTrusted="true"`

4

*All other [default actions](#default-action), including the [activation
behavior](https://dom.spec.whatwg.org/#eventtarget-activation-behavior)*

### 8.2. Legacy [`FocusEvent` events]
#### 8.2.1. Legacy [`FocusEvent` event types]
##### [8.2.1.1. ][[DOMFocusIn]]
Type

**`DOMFocusIn`**

Interface

[`FocusEvent`](#focusevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Element`

Cancelable

No

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [event
 target](#event-target)
 receiving focus
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`FocusEvent`](#focusevent).[`relatedTarget`](#dom-focusevent-relatedtarget) : `null`

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when an [event
target](#event-target) receives
focus. The focus MUST be given to the element before the dispatch of
this event type. This event type MUST be dispatched after the event type
[`focus`](#focus).

The [`DOMFocusIn`](#domfocusin)
event type is defined in this specification for reference and
completeness, but this specification
[deprecates](#deprecates) the use
of this event type in favor of the related event types
[`focus`](#focus) and
[`focusin`](#focusin).

##### [8.2.1.2. ][[DOMFocusOut]]
Type

**`DOMFocusOut`**

Interface

[`FocusEvent`](#focusevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

[`Window`](https://drafts.csswg.org/css-color-3/#window), `Element`

Cancelable

No

Composed

Yes

Default action

None

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : [event
 target](#event-target) losing
 focus
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`FocusEvent`](#focusevent).[`relatedTarget`](#dom-focusevent-relatedtarget) : `null`

A [user
agent](https://infra.spec.whatwg.org/#user-agent) MUST dispatch this event when an [event
target](#event-target) loses
focus. The focus MUST be taken from the element before the dispatch of
this event type. This event type MUST be dispatched after the event type
[`blur`](#blur).

The [`DOMFocusOut`](#domfocusout)
event type is defined in this specification for reference and
completeness, but this specification
[deprecates](#deprecates) the use
of this event type in favor of the related event types
[`blur`](#blur) and
[`focusout`](#focusout).

#### 8.2.2. Legacy FocusEvent event order

The following is the typical sequence of events when a focus is shifted
between elements, including the deprecated
[`DOMFocusIn`](#domfocusin) and
[`DOMFocusOut`](#domfocusout)
events. The order shown assumes that no element is initially focused.

Event Type

Notes

*User shifts focus*

1

[`focusin`](#focusin)

Sent before first target element receives focus

2

[`focus`](#focus)

Sent after first target element receives focus

3

[`DOMFocusIn`](#domfocusin)

If supported

*User shifts focus*

4

[`focusout`](#focusout)

Sent before first target element loses focus

5

[`focusin`](#focusin)

Sent before second target element receives focus

6

[`blur`](#blur)

Sent after first target element loses focus

7

[`DOMFocusOut`](#domfocusout)

If supported

8

[`focus`](#focus)

Sent after second target element receives focus

9

[`DOMFocusIn`](#domfocusin)

If supported

### 8.3. Legacy [`KeyboardEvent` events]
The [`keypress`](#keypress) event
is the traditional method for capturing key events and processing them
before the DOM is updated with the effects of the key press. Code that
makes use of the [`keypress`](#keypress) event typically relies on the legacy
[`charCode`](#dom-keyboardevent-charcode),
[`keyCode`](#dom-keyboardevent-keycode), and
[`which`](#dom-uievent-which) attributes.

Note that the [`keypress`](#keypress) event is specific to key events, and has been replaced
by the more general event sequence of
[`beforeinput`](#beforeinput)
and [`input`](#input) events. These
new `input` events are not specific to keyboard actions and can be used
to capture user input regardless of the original source.

#### 8.3.1. Legacy [`KeyboardEvent` event types]
##### [8.3.1.1. ][[keypress]]
Type

**`keypress`**

Interface

[`KeyboardEvent`](#keyboardevent)

Sync / Async

Sync

Bubbles

Yes

Trusted Targets

`Element`

Cancelable

Yes

Composed

Yes

Default action

Varies: launch [text composition
system](#text-composition-system); [`blur`](#blur) and
[`focus`](#focus) events;
[`DOMActivate`](#domactivate)
event; other event

Context\
(trusted events)

- [`Event`](https://dom.spec.whatwg.org/#event).[`target`](https://dom.spec.whatwg.org/#dom-event-target) : focused element processing the key event or if no
 element focused, then the [body
 element](#body-element) if
 available, otherwise the [root
 element](#root-element)
- [`UIEvent`](#uievent).[`view`](#dom-uievent-view) :
 [`Window`](https://drafts.csswg.org/css-color-3/#window)
- [`UIEvent`](#uievent).[`detail`](#dom-uievent-detail) : `0`
- [`KeyboardEvent`](#keyboardevent).[`which`](#dom-uievent-which) : legacy numerical code for this key
- [`KeyboardEvent`](#keyboardevent).[`charCode`](#dom-keyboardevent-charcode) : legacy character value for this event
- [`KeyboardEvent`](#keyboardevent).[`keyCode`](#dom-keyboardevent-keycode) : legacy numerical code for this key
- [`KeyboardEvent`](#keyboardevent).[`key`](#dom-keyboardevent-key) : the key value of the key pressed.
- [`KeyboardEvent`](#keyboardevent).[`code`](#dom-keyboardevent-code) : the code value associated with the key's physical
 placement on the keyboard.
- [`KeyboardEvent`](#keyboardevent).[`location`](#dom-keyboardevent-location) : the location of the key on the device.
- [`KeyboardEvent`](#keyboardevent).[`altKey`](#dom-keyboardevent-altkey) : `true` if `Alt` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`shiftKey`](#dom-keyboardevent-shiftkey) : `true` if `Shift` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`ctrlKey`](#dom-keyboardevent-ctrlkey) : `true` if `Control` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`metaKey`](#dom-keyboardevent-metakey) : `true` if `Meta` modifier was active,
 otherwise `false`
- [`KeyboardEvent`](#keyboardevent).[`repeat`](#dom-keyboardevent-repeat) : `false`
- [`KeyboardEvent`](#keyboardevent).[`isComposing`](#dom-keyboardevent-iscomposing) : `true` if the key event occurs as part of a
 composition session, otherwise `false`

If supported by a [user
agent](https://infra.spec.whatwg.org/#user-agent), this event MUST be dispatched when a key is pressed
down, if and only if that key normally produces a [character
value](#character-value). The
[`keypress`](#keypress) event type
is device dependent and relies on the capabilities of the input devices
and how they are mapped in the operating system.

This event type MUST be generated after the [key
mapping](#key-mapping). It MUST
NOT be fired when using an [input method
editor](#input-method-editor).

If this event is canceled, it should prevent the
[`input`](#input) event from firing,
in addition to canceling the [default
action](#default-action).

Authors SHOULD use the
[`beforeinput`](#beforeinput)
event instead of the [`keypress`](#keypress) event.

The [`keypress`](#keypress) event
is traditionally associated with detecting a [character
value](#character-value)
rather than a physical key, and might not be available on all keys in
some configurations.

The [`keypress`](#keypress) event
type is defined in this specification for reference and completeness,
but this specification [deprecates](#deprecates) the use of this event type. When in editing contexts,
authors can subscribe to the
[`beforeinput`](#beforeinput)
event instead.

#### 8.3.2. [`keypress` event order]
The [`keypress`](#keypress) event
type MUST be dispatched after the
[`keydown`](#keydown) event and
before the [`keyup`](#keyup) event
associated with the same key.

The [`keypress`](#keypress) event
type MUST be dispatched after the
[`beforeinput`](#beforeinput)
event and before the [`input`](#input)
event associated with the same key.

The sequence of key events for user-agents the support the
[`keypress`](#keypress) event is
demonstrated in the following example:

Event Type

[`KeyboardEvent`](#keyboardevent)\
[`key`](#dom-keyboardevent-key)

[`InputEvent`](#inputevent)\
[`data`](#dom-inputevent-data)

Notes

1

[`keydown`](#keydown)

`"a"`

2

[`beforeinput`](#beforeinput)

`"a"`

3

[`keypress`](#keypress)

`"a"`

*Any [default actions](#default-action) related to this key, such as inserting a character in
to the DOM.*

4

[`input`](#input)

5

[`keyup`](#keyup)

`"a"`

### 8.4. Legacy [`TextEvent` events]
```
[Exposed=Window]
interface TextEvent : UIEvent {
 readonly attribute DOMString data;
 undefined initTextEvent(DOMString type,
 optional boolean bubbles = false,
 optional boolean cancelable = false,
 optional Window? view = null,
 optional DOMString data = "undefined");
};
```

See [Text Event section in UI Events
Algorithms](event-algo.html#textevent) for the
[`TextEvent`](#textevent)
interface and the [textInput] event.

## 9. Extending Events

*This section is non-normative*

### 9.1. Introduction

This specification defines several interfaces and many events, however,
this is not an exhaustive set of events for all purposes. To allow
content authors and implementers to add desired functionality, this
specification provides two mechanisms for extend this set of interfaces
and events without creating conflicts: [custom
events](#extending-events-Custom_Events) and [implementation-specific
extensions](#extending-events-Impl_Extensions).

### 9.2. Custom Events

A script author MAY wish to define an application in terms of functional
components, with event types that are meaningful to the application
architecture. The content author can use the
[`CustomEvent`](https://dom.spec.whatwg.org/#customevent) interface to create their own events appropriate to the
level of abstraction they are using.

A content author might have created an
application which features a dynamically generated bar chart. This bar
chart is meant to be updated every 5 minutes, or when a feed shows new
information, or when the user refreshes it manually by clicking a
button. There are several handlers that have to be called when the chart
needs to be updated: the application has to fetch the most recent data,
show an icon to the user that the event is being updated, and rebuild
the chart. To manage this, the content author can choose to create a
custom "updateChart" event, which is fired whenever one of the trigger
conditions is met:

 var chartData = ...;
 var evt = document.createEvent("CustomEvent");
 evt.initCustomEvent( "updateChart", true, false, { data: chartData });
 document.documentElement.dispatchEvent(evt);

### 9.3. Implementation-Specific Extensions

While a new event is being designed and prototyped, or when an event is
intended for implementation-specific functionality, it is desirable to
distinguish it from standardized events. Implementors SHOULD prefix
event types specific to their implementations with a short string to
distinguish it from the same event in other implementations and from
standardized events. This is similar to the [vendor-specific keyword
prefixes](http://www.w3.org/TR/CSS21/syndata.html#vendor-keywords "CSS 2.1: Syntax and basic data types")
in CSS, though without the dashes (`"-"`) used in CSS, since that can
cause problems when used as an attribute name in Javascript.

A particular browser vendor,
"FooCorp", might wish to introduce a new event, `jump`. This
vendor implements `fooJump` in their browser, using their
vendor-specific prefix: `"foo"`. Early adopters start experimenting with
the event, using
`someElement.addEventListener("fooJump", doJump, false )`, and provide
feedback to FooCorp, who change the behavior of `fooJump`
accordingly.

After some time, another vendor, "BarOrg", decides they also want the
functionality, but implement it slightly differently, so they use their
own vendor-specific prefix, `"bar"` in their event type name:
`barJump`. Content authors experimenting with this version
of the `jump` event type register events with BarOrg's event
type name. Content authors who wish to write code that accounts for both
browsers can either register each event type separately with specific
handlers, or use the same handler and switch on the name of the event
type. Thus, early experiments in different codebases do not conflict,
and the early adopter is able to write easily-maintained code for
multiple implementations.

Eventually, as the feature matures, the behavior of both browsers
stabilizes and might converge due to content author and user feedback or
through formal standardization. As this stabilization occurs, and risk
of conflicts decrease, content authors can remove the forked code, and
use the `jump` event type name (even before it is formally
standardized) using the same event handler and the more generic
registration method
`someElement.addEventListener( "jump", doJump, false)`.

#### 9.3.1. Known Implementation-Specific Prefixes

At the time of writing, the following event-type name prefixes are known
to exist:

Prefix

Web Engine

Organization

`moz`, `Moz`

Gecko

Mozilla

`ms`, `MS`

Trident

Microsoft

`o`, `O`

Presto

Opera Software

`webkit`

WebKit

Apple, Google, others

## 10. Security Considerations

This appendix discusses security considerations for UI Events
implementations. The discussion is limited to security issues that arise
directly from implementation of the event model, APIs and events defined
in this specification. Implementations typically support other features
like scripting languages, other APIs and additional events not defined
in this document. These features constitute an unknown factor and are
out of scope of this document. Implementers SHOULD consult the
specifications of such features for their respective security
considerations.

Many of the event types defined in this specification are dispatched in
response to user actions. This allows malicious [event
listeners](https://dom.spec.whatwg.org/#concept-event-listener) to gain access to information users would typically
consider confidential, e.g., typos they might have made when filling out
a form, if they reconsider their answer to a multiple choice question
shortly before submitting a form, their typing rate or primary input
mechanism. In the worst case, malicious [event
listeners](https://dom.spec.whatwg.org/#concept-event-listener) could capture all user interactions and submit them to
a third party through means (not defined in this specification) that are
generally available in DOM implementations, such as the XMLHttpRequest
interface.

In DOM implementations that support facilities to load external data,
events like the [`error`](#error) event
can provide access to sensitive information about the environment of the
computer system or network. An example would be a malicious HTML
document that attempts to embed a resource on the local network or the
localhost on different ports. An embedded DOM application could then
listen for [`error`](#error) and
[`load`](#load) events to determine
which other computers in a network are accessible from the local system
or which ports are open on the system to prepare further attacks.

An implementation of UI Events alone is generally insufficient to
perform attacks of this kind and the security considerations of the
facilities that possibly support such attacks apply. For conformance
with this specification, DOM implementations MAY take reasonable steps
to ensure that DOM applications do not get access to confidential or
sensitive information. For example, they might choose not to dispatch
[`load`](#load) events to nodes that
attempt to embed resources on the local network.

## 11. Acknowledgements

Many people contributed to the DOM specifications (Level 1, 2 or 3),
including participants of the DOM Working Group, the DOM Interest Group,
the WebAPI Working Group, and the WebApps Working Group. We especially
thank the following:

Andrew Watson (Object Management Group), Andy Heninger (IBM), Angel Diaz
(IBM), Anne van Kesteren (Opera Software), Arnaud Le Hors (W3C and IBM),
Arun Ranganathan (AOL), Ashok Malhotra (IBM and Microsoft), Ben Chang
(Oracle), Bill Shea (Merrill Lynch), Bill Smith (Sun), Björn Höhrmann,
Bob Sutor (IBM), Charles McCathie-Nevile (Opera Software, *Co-Chair*),
Chris Lovett (Microsoft), Chris Wilson (Microsoft), Christophe Jolif
(ILOG), David Brownell (Sun), David Ezell (Hewlett-Packard Company),
David Singer (IBM), Dean Jackson (W3C, *W3C Team Contact*), Dimitris
Dimitriadis (Improve AB and invited expert), Don Park (invited), Doug
Schepers (Vectoreal), Elena Litani (IBM), Eric Vasilik (Microsoft),
Gavin Nicol (INSO), Gorm Haug Eriksen (Opera Software), Ian Davis (Talis
Information Limited), Ian Hickson (Google), Ian Jacobs (W3C), James
Clark (invited), James Davidson (Sun), Jared Sorensen (Novell), Jeroen
van Rotterdam (X-Hive Corporation), Joe Kesselman (IBM), Joe Lapp
(webMethods), Joe Marini (Macromedia), John Robinson (AOL), Johnny
Stenback (Netscape/AOL), Jon Ferraiolo (Adobe), Jonas Sicking (Mozilla
Foundation), Jonathan Marsh (Microsoft), Jonathan Robie (Texcel Research
and Software AG), Kim Adamson-Sharpe (SoftQuad Software Inc.), Lauren
Wood (SoftQuad Software Inc., *former Chair*), Laurence Cable (Sun),
Luca Mascaro (HTML Writers Guild), Maciej Stachowiak (Apple Computer),
Marc Hadley (Sun Microsystems), Mark Davis (IBM), Mark Scardina
(Oracle), Martin Dürst (W3C), Mary Brady (NIST), Michael Shenfield
(Research In Motion), Mick Goulish (Software AG), Mike Champion
(Arbortext and Software AG), Miles Sabin (Cromwell Media), Patti Lutsky
(Arbortext), Paul Grosso (Arbortext), Peter Sharpe (SoftQuad Software
Inc.), Phil Karlton (Netscape), Philippe Le Hégaret (W3C, *W3C Team
Contact and former Chair*), Ramesh Lekshmynarayanan (Merrill Lynch), Ray
Whitmer (iMall, Excite@Home, and Netscape/AOL, *Chair*), Rezaur Rahman
(Intel), Rich Rollman (Microsoft), Rick Gessner (Netscape), Rick
Jelliffe (invited), Rob Relyea (Microsoft), Robin Berjon (Expway,
*Co-Chair*), Scott Hayman (Research In Motion), Scott Isaacs
(Microsoft), Sharon Adler (INSO), Stéphane Sire (IntuiLab), Steve Byrne
(JavaSoft), Tim Bray (invited), Tim Yu (Oracle), Tom Pixley
(Netscape/AOL), T.V. Raman (Google). Vidur Apparao (Netscape) and Vinod
Anupam (Lucent).

**Former editors:** Tom Pixley (Netscape Communications Corporation)
until July 2002; Philippe Le Hégaret (W3C) until November 2003; Björn
Höhrmann (Invited Expert) until January 2008; and Jacob Rossi
(Microsoft) from March 2011 to October 2011.

**Contributors:** In the WebApps Working Group, the following people
made substantial material contributions in the process of refining and
revising this specification: Bob Lund (Cable Laboratories), Cameron
McCormack (Invited Expert / Mozilla), Daniel Danilatos (Google), Gary
Kacmarcik (Google), Glenn Adams (Samsung), Hallvord R. M. Steen (Opera),
Hironori Bono (Google), Mark Vickers (Comcast), Masayuki Nakano
(Mozilla), Olli Pettay (Mozilla), Takayoshi Kochi (Google) and Travis
Leithead (Microsoft).

**Glossary contributors:** Arnaud Le Hors (W3C) and Robert S. Sutor (IBM
Research).

**Test suite contributors:** Carmelo Montanez (NIST), Fred Drake, Mary
Brady (NIST), Neil Delima (IBM), Rick Rivello (NIST), Robert Clary
(Netscape), with a special mention to Curt Arnold.

Thanks to all those who have helped to improve this specification by
sending suggestions and corrections (please, keep bugging us with your
issues!), or writing informative books or Web sites: Al Gilman, Alex
Russell, Alexander J. Vincent, Alexey Proskuryakov, Arkadiusz Michalski,
Brad Pettit, Cameron McCormack, Chris Rebert, Curt Arnold, David
Flanagan, Dylan Schiemann, Erik Arvidsson, Garrett Smith, Giuseppe
Pascale, James Su, Jan Goyvaerts (regular-expressions.info), Jorge
Chamorro, Kazuyuki Ashimura, Ken Rehor, Magnus Kristiansen, Martijn
Wargers, Martin Dürst, Michael B. Allen, Mike Taylor, Misha Wolf, Ojan
Vafai, Oliver Hunt, Paul Irish, Peter-Paul Koch, Richard Ishida, Sean
Hogan, Sergey Ilinsky, Sigurd Lerstad, Steven Pemberton, Tony Chang,
William Edney and Øistein E. Andersen.

## 12. Glossary

Some of the following term definitions have been borrowed or modified
from similar definitions in other W3C or standards documents. See the
links within the definitions for more information.

[activation trigger]

: An event which is defined to initiate an [activation
 behavior](https://dom.spec.whatwg.org/#eventtarget-activation-behavior).

[author]

: In the context of this specification, an *author*, *content author*,
 or *script author* is a person who writes script or other executable
 content that uses the interfaces, events, and event flow defined in
 this specification. See [§ 1.2.3 Content authors and
 content](#conf-authors) conformance category for more details.

[body element]

: In HTML or XHTML
 [documents](https://dom.spec.whatwg.org/#concept-document), the body element represents the contents of the
 document. In a well-formed HTML document, the body element is a
 first descendant of the [root
 element](#root-element).

[character value]

: In the context of key values, a character value is a string
 representing one or more Unicode characters, such as a letter or
 symbol, or a set of letters, each belonging to the set of valid
 [Unicode character
 categories](#unicode-character-categories). In this specification, character values are
 denoted as a unicode string (e.g., `U+0020`) or a glyph
 representation of the same code point (e.g., `" "`), and are
 color coded to help distinguish these two representations.

 In source code, some key values, such as non-graphic characters, can
 be represented using the character escape syntax of the programming
 language in use.

[dead key]

: A dead key is a key or combination of keys which produces no
 character by itself, but which in combination or sequence with
 another key produces a modified character, such as a character with
 diacritical marks (e.g., `"ö"`, `"é"`,
 `"â"`).

[default action]

: A [default action](#default-action) is an OPTIONAL supplementary behavior that an
 implementation MUST perform in combination with the dispatch of the
 event object. Each event type definition, and each specification,
 defines the [default
 action](#default-action)
 for that event type, if it has one. An instance of an event MAY have
 more than one [default
 action](#default-action)
 under some circumstances, such as when associated with an
 [activation
 trigger](#activation-trigger). A [default
 action](#default-action)
 MAY be cancelled through the invocation of the
 [`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) method.

[delta]

: The estimated scroll amount (in pixels, lines, or pages) that the
 user agent will scroll or zoom the page in response to the physical
 movement of an input device that supports the
 [`WheelEvent`](https://w3c.github.io/pointerevents/#dom-wheelevent) interface (such as a mouse wheel or touch pad). The
 value of a [delta](#delta) (e.g.,
 the
 [`deltaX`](https://w3c.github.io/pointerevents/#dom-wheelevent-deltax),
 [`deltaY`](https://w3c.github.io/pointerevents/#dom-wheelevent-deltay), or
 [`deltaZ`](https://w3c.github.io/pointerevents/#dom-wheelevent-deltaz) attributes) is to be interpreted in the context of
 the current
 [`deltaMode`](https://w3c.github.io/pointerevents/#dom-wheelevent-deltamode) property. The relationship between the physical
 movement of a wheel (or other device) and whether the
 [delta](#delta) is positive or
 negative is environment and device dependent. However, if a user
 agent scrolls as the [default
 action](#default-action)
 then the sign of the [delta](#delta) is given by a right-hand coordinate system where
 positive X,Y, and Z axes are directed towards the right-most edge,
 bottom-most edge, and farthest depth (away from the user) of the
 [document](https://dom.spec.whatwg.org/#concept-document), respectively.

[deprecated]

: Features marked as deprecated are included in the specification as
 reference to older implementations or specifications, but are
 OPTIONAL and discouraged. Only features which have existing or
 in-progress replacements MUST be deprecated in this specification.
 Implementations which do not already include support for the feature
 MAY implement deprecated features for reasons of backwards
 compatibility with existing content, but content authors creating
 content SHOULD NOT use deprecated features, unless there is no other
 way to solve a use case. Other specifications which reference this
 specification SHOULD NOT use deprecated features, but SHOULD point
 instead to the replacements of which the feature is deprecated in
 favor. Features marked as deprecated in this specification are
 expected to be dropped from future specifications.

[empty string]

: The empty string is a value of type `DOMString` of length `0`, i.e.,
 a string which contains no characters (neither printing nor control
 characters).

[event focus]

: Event focus is a special state of receptivity and concentration on a
 particular element or other [event
 target](#event-target)
 within a
 [document](https://dom.spec.whatwg.org/#concept-document). Each element has different behavior when focused,
 depending on its functionality, such as priming the element for
 activation (as for a button or hyperlink) or toggling state (as for
 a checkbox), receiving text input (as for a text form field), or
 copying selected text. For more details, see [§ 3.3.3 Document Focus
 and Focus Context](#events-focusevent-doc-focus).

[event focus ring]

: An event focus ring is an ordered set of [event
 focus](#event-focus) targets
 within a
 [document](https://dom.spec.whatwg.org/#concept-document). A [host
 language](#host-language)
 MAY define one or more ways to determine the order of targets, such
 as document order, a numerical index defined per focus target,
 explicit pointers between focus targets, or a hybrid of different
 models. Each document MAY contain multiple focus rings, or
 conditional focus rings. Typically, for document-order or indexed
 focus rings, focus "wraps around" from the last focus target to the
 first.

[event target]

: The object to which an
 [event](https://dom.spec.whatwg.org/#concept-event) is targeted using the event flow. The event target
 is the value of the
 [`target`](https://dom.spec.whatwg.org/#dom-event-target) attribute.

[event type]

: An *event type* is an
 [event](https://dom.spec.whatwg.org/#concept-event) object with a particular name and which defines
 particular trigger conditions, properties, and other characteristics
 which distinguish it from other event types. For example, the
 [`keydown`](#keydown) event type
 has different characteristics than the
 [`blur`](#blur) or
 [`load`](#load) event types. The
 event type is exposed as the
 [`type`](https://dom.spec.whatwg.org/#dom-event-type) attribute on the event object. Also loosely
 referred to as *\"event\"*, such as the
 *[`keydown`](#keydown) event*.

[host language]

: Any language which integrates the features of another language or
 API specification, while normatively referencing the origin
 specification rather than redefining those features, and extending
 those features only in ways defined by the origin specification. An
 origin specification typically is only intended to be implemented in
 the context of one or more host languages, not as a standalone
 language. For example, XHTML, HTML, and SVG are host languages for
 UI Events, and they integrate and extend the objects and models
 defined in this specification.

[IME]\
[input method editor]

: An *input method editor* (IME), also known as a *front end
 processor*, is an application that performs the conversion between
 keystrokes and ideographs or other characters, usually by
 user-guided dictionary lookup, often used in East Asian languages
 (e.g., Chinese, Japanese, Korean). An [IME](#ime) MAY also be used for dictionary-based word
 completion, such as on mobile devices. See [§ 4.3.3 Input Method
 Editors](#keys-IME) for treatment of IMEs in this specification. See
 also [text composition
 system](#text-composition-system).

[key mapping]

: Key mapping is the process of assigning a key value to a particular
 key, and is the result of a combination of several factors,
 including the operating system and the keyboard layout (e.g.,
 [QWERTY](#qwerty), Dvorak,
 Spanish, InScript, Chinese, etc.), and after taking into account all
 [modifier key](#modifier-key) (`Shift`, `Alt`, et al.) and
 [dead key](#dead-key) states.

[key value]

: A key value is a [character
 value](#character-value)
 or multi-character string (such as
 `"`[`Enter`](http://www.w3.org/TR/uievents-key/#key-Enter)`"`,
 `"`[`Tab`](http://www.w3.org/TR/uievents-key/#key-Tab)`"`,
 or
 `"`[`MediaTrackNext`](http://www.w3.org/TR/uievents-key/#key-MediaTrackNext)`"`)
 associated with a key in a particular state. Every key has a key
 value, whether or not it has a [character
 value](#character-value). This includes control keys, function keys,
 [modifier keys](#modifier-key), [dead keys](#dead-key), and any other key. The key value of any given key
 at any given time depends upon the [key
 mapping](#key-mapping).

[modifier key]

: A modifier key changes the normal behavior of a key, such as to
 produce a character of a different case (as with the
 `Shift` key), or to alter what functionality the key
 triggers (as with the `Fn` or `Alt` keys). See
 [§ 4.3.1 Modifier keys](#keys-modifiers) for more information about
 modifier keys and refer to the [Modifier Keys
 table](https://www.w3.org/TR/uievents-key/#keys-modifier) in
 [\[UIEvents-Key\]](#biblio-uievents-key "UI Events KeyboardEvent key Values")
 for a list of valid modifier keys.

[namespace URI]

: A *namespace URI* is a URI that identifies an XML namespace. This is
 called the namespace name in
 [\[XML-Names11\]](#biblio-xml-names11 "Namespaces in XML 1.1 (Second Edition)").
 See also sections 1.3.2 [*DOM
 URIs*](http://www.w3.org/TR/DOM-Level-3-Core/core.html#baseURIs-Considerations)
 and 1.3.3 [*XML
 Namespaces*](http://www.w3.org/TR/DOM-Level-3-Core/core.html#Namespaces-Considerations)
 regarding URIs and namespace URIs handling and comparison in the DOM
 APIs.

[QWERTY]

: QWERTY (pronounced "ˈkwɜrti") is a common keyboard layout, so named
 because the first five character keys on the top row of letter keys
 are Q, W, E, R, T, and Y. There are many other popular keyboard
 layouts (including the Dvorak and Colemak layouts), most designed
 for localization or ergonomics.

[root element]

: The first element node of a
 [document](https://dom.spec.whatwg.org/#concept-document), of which all other elements are children. The
 document element.

[text composition system]

: A software component that interprets some form of alternate input
 (such as a [input method
 editor](#input-method-editor), a speech processor, or a handwriting recognition
 system) and converts it to text.

[Unicode character categories]

: A subset of the General Category values that are defined for each
 Unicode code point. This subset contains all the Letter ([Ll], [Lm],
 [Lo], [Lt], [Lu]),
 Number ([Nd], [Nl], [No]),
 Punctuation ([Pc], [Pd], [Pe],
 [Pf], [Pi], [Po], [Ps])
 and Symbol ([Sc], [Sk], [Sm],
 [So]) category values.

[un-initialized value]

: The value of any event attribute (such as
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) or
 [`currentTarget`](https://dom.spec.whatwg.org/#dom-event-currenttarget)) before the event has been initialized with
 [`initEvent()`](https://dom.spec.whatwg.org/#dom-event-initevent). The un-initialized values of an event apply
 immediately after a new event has been created using the method
 [`createEvent()`](https://dom.spec.whatwg.org/#dom-document-createevent).
