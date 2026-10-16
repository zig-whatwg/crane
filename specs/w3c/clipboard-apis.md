## 1. Introduction

*This section is non-normative.*

This specification defines how the system clipboard is exposed to web
applications.

There are two general APIs described in this specification:

- Clipboard Event API - This API provides a way to hook into the common
 clipboard operations of cutting, copying and pasting so that web
 application can adjust the clipboard data as required.

- Async Clipboard API - This API provides direct access to read and
 write the clipboard data. Since this is considered to be a [powerful
 feature](https://w3c.github.io/permissions/#dfn-powerful-feature), access to this API is controlled by a permission.

## 2. Use Cases

*This section is non-normative.*

### 2.1. Changing Default Clipboard Operations

There are many scenarios where it is desireable to change the default
clipboard operations (cut/copy/paste). Here are a few examples:

- **Metadata** When copying text from a repository of documents, it can
 be useful for the copied text to include metadata about the source of
 the copied content.
- **Rich content editing** When copying text which contains hyperlinks
 or other structure, it is often useful to be able to reformat the
 content to preserve important information.
- **Graphics with built-in semantics** In order to make web applications
 which allow the manipulation of rich text, or of graphic content such
 as
 [\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"),
 it is useful to provide a mechanism that allows for copying more than
 just the rendered content.
- **Mathematical information** With content such as mathematics, simply
 copying rendered text and pasting it into another application
 generally leads to most of the semantics being lost. MathML often
 needs to be transformed to be copied as plain text, for example to
 make sure \"to the power of\" is shown with the caret \"\^\" sign in a
 formula plain-text input. The XML source could also be placed in the
 clipboard with the appropriate transformation occurring at paste time.

### 2.2. Remote Clipboard Synchronization

For web applications that communicate with remote devices (e.g., remote
access or remote shell applications), there is often a need for the
clipboard data to be kept in sync between the two devices.

One important aspect of this use case is that it requires access to the
clipboard in the absense of a user gesture or interaction.

To copy the clipboard data from a
remote device to the local clipboard, a web application would take the
remote clipboard data and then
[`write()`](#dom-clipboard-write) the data to the local clipboard.

To copy the local clipboard data to a
remote device, a web application would listen for
[`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange) events,
[`read()`](#dom-clipboard-read) from the clipboard whenever it is updated, and then
send the new clipboard data to the remote device.

### 2.3. Trigger Clipboard Actions

Applications that provide an alternate interface to a user agent
sometimes need to be able to trigger clipboard actions in the user
agent.

As an example, consider a screen reader application that provides a more
accessible interface to a standard web browser. While the reader can
display content and allow the user to interact with it, actions like
clipboard copy need to occur in the underlying browser to ensure that
the clipboard content is set correctly (with any metadata added by the
browser during copy).

## 3. Terminology

The term [editable context] means any element that is either an [editing
host](https://html.spec.whatwg.org/multipage/interaction.html#editing-host), a textarea element, or an input element with its type
attribute set to any of \"text\", \"search\", \"tel\", \"url\",
\"email\", \"password\" or \"number\".

## 4. Model

The platform provides a [system clipboard].

The [system clipboard](#system-clipboard) has a list of [system clipboard
item](#system-clipboard-item)s that are collectively called the [system clipboard
data].

Each [system clipboard item] has a list of [system clipboard
representation](#system-clipboard-representation)s.

Each [system clipboard representation] has a
[name],
which is a string, and [data], which is a sequence of bytes.

The [system clipboard](#system-clipboard) has a [clipboard change count], which is a value that
changes each time the [system clipboard
data](#system-clipboard-data) is modified.

## 5. Clipboard Events

### 5.1. Clipboard event interfaces

The ClipboardEvent interface extends the
[`Event`](https://dom.spec.whatwg.org/#event) interface.

```
dictionary ClipboardEventInit : EventInit {
 DataTransfer? clipboardData = null;
};
```

[clipboardData]

: A
 [`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) object to hold data and meta data related to the
 event.

```
[Exposed=Window]
interface ClipboardEvent : Event {
 constructor(DOMString type, optional ClipboardEventInit eventInitDict = );
 readonly attribute DataTransfer? clipboardData;
};
```

[clipboardData]

: The clipboardData attribute is an instance of the
 [`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) interface which lets a script read and manipulate
 values on the system clipboard during user-initiated copy, cut and
 paste operations. The associated drag data store is a live but
 filtered view of the system clipboard, exposing [mandatory data
 types](#mandatory-data-types) the implementation knows the script can safely
 access. For synthetic events, the drag data store contains the data
 added by the script that created the event.

: The clipboardData object's
 [`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items) and
 [`files`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-files) properties enable processing of multi-part or
 non-textual data from the clipboard.

The interface can be used to [construct
events](https://dom.spec.whatwg.org/#constructing-events). An example is given below:

```
var pasteEvent = new ClipboardEvent('paste');
pasteEvent.clipboardData.items.add('My string', 'text/plain');
document.dispatchEvent(pasteEvent);
```

 Synthetic clipboard events will not actually modify the
clipboard or the document. In other words, while the script above will
fire a paste event, the data will not be pasted into the document.

### 5.2. Clipboard events

#### [5.2.1. ][The [`clipboardchange`] event]
The
[`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange) event fires whenever the contents of the [system
clipboard](#system-clipboard) are changed. These changes could be due to any of the
following (non-exhaustive):

- User-initiated cut or copy actions

- Scripts that use the [§ 7 Asynchronous Clipboard
 API](#async-clipboard-api) to write to the clipboard

- Actions that update the clipboard outside the user agent

##### 5.2.1.1. To fire a clipboardchange event

To [fire a clipboardchange event] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`:

1. If `document` does not have [sticky
 activation](https://html.spec.whatwg.org/multipage/interaction.html#sticky-activation) and `document` does not have permission
 to read from the clipboard, then return.

2. Let `global` be `document`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

3. If `document` has [system
 focus](https://html.spec.whatwg.org/multipage/interaction.html#system-focus):

 1. Let `types` be a list of [mandatory data
 types](#mandatory-data-types) available on the [system
 clipboard](#system-clipboard).

 2. Let `changeId` be the result of running [generate a
 changeId](#generate-a-changeid) given `document`.

 3. Let `eventInit` be a new
 [`ClipboardChangeEventInit`](#dictdef-clipboardchangeeventinit) dictionary with its
 [`types`](#dom-clipboardchangeeventinit-types) member set to `types` and its
 [`changeId`](#dom-clipboardchangeeventinit-changeid) member set to `changeId`.

 4. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange) at `global`, using
 [`ClipboardChangeEvent`](#clipboardchangeevent), with `eventInit`.

4. If `document` does not have [system
 focus](https://html.spec.whatwg.org/multipage/interaction.html#system-focus):

 1. Set `document`'s [clipboardchange pending
 flag] to true.

User agents MAY choose to skip firing
[`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange) events for clipboard changes that have been superseded
by more recent changes before the event would be delivered. This
optimization can improve performance in scenarios where clipboard
changes occur in rapid succession, as delivering obsolete change
notifications provides no value to web applications while consuming
processing resources.

##### 5.2.1.2. Document focus steps

When a
[`Document`](https://dom.spec.whatwg.org/#document) `document` gains [system
focus](https://html.spec.whatwg.org/multipage/interaction.html#system-focus):

1. If `document`'s [clipboardchange pending
 flag](#document-clipboardchange-pending-flag) is true:

 1. Set `document`'s [clipboardchange pending
 flag](#document-clipboardchange-pending-flag) to false.

 2. Let `types` be a list of [mandatory data
 types](#mandatory-data-types) available on the [system
 clipboard](#system-clipboard).

 3. Let `changeId` be the result of running [generate a
 changeId](#generate-a-changeid) given `document`.

 4. Let `eventInit` be a new
 [`ClipboardChangeEventInit`](#dictdef-clipboardchangeeventinit) dictionary with its
 [`types`](#dom-clipboardchangeeventinit-types) member set to `types` and its
 [`changeId`](#dom-clipboardchangeeventinit-changeid) member set to `changeId`.

 5. Let `global` be `document`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

 6. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange) at `global`, using
 [`ClipboardChangeEvent`](#clipboardchangeevent), with `eventInit`.

For documents in nested browsing contexts, the
[`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange) event fires independently in each
[`Document`](https://dom.spec.whatwg.org/#document) based on its own focus state. A clipboard change will
fire an event in the single document that has [system
focus](https://html.spec.whatwg.org/multipage/interaction.html#system-focus) (if that document has [sticky
activation](https://html.spec.whatwg.org/multipage/interaction.html#sticky-activation) or persistent clipboard permissions).

**Note:** The `clipboardchange` event is only available after [sticky
activation](https://html.spec.whatwg.org/multipage/interaction.html#sticky-activation),
unless the document has persistent permission to read from the
clipboard. In user agents that support persistent clipboard permissions,
sites with such permissions can receive `clipboardchange` events without
sticky activation, as the permission already grants access to more
sensitive clipboard data.

The
[`changeId`](#dom-clipboardchangeevent-changeid) provides a unique identifier for each clipboard change
operation. For the same clipboard change, all windows and tabs with the
same [storage
key](https://storage.spec.whatwg.org/#storage-key) will receive events with identical
[`changeId`](#dom-clipboardchangeevent-changeid) values, enabling applications with multiple windows to
deduplicate events and avoid redundant processing. The identifier is
[storage
key](https://storage.spec.whatwg.org/#storage-key)-specific and does not provide cross-[storage
key](https://storage.spec.whatwg.org/#storage-key) correlation capabilities.

The
[`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange) event does not bubble and is not cancelable, as it is
not triggered by a user action but rather by changes to the [system
clipboard](#system-clipboard) state.

```
dictionary ClipboardChangeEventInit : EventInit {
 sequence<DOMString> types = ;
 bigint changeId = 0;
};
```

[types]

: A sequence of
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) representing the [mandatory data
 types](#mandatory-data-types) available on the [system
 clipboard](#system-clipboard).

[changeId]

: A
 [`bigint`](https://webidl.spec.whatwg.org/#idl-bigint) representing a unique identifier for the clipboard
 change operation.

```
[Exposed=Window]
interface ClipboardChangeEvent : Event {
 constructor(DOMString type, optional ClipboardChangeEventInit eventInitDict = );
 readonly attribute FrozenArray<DOMString> types;
 readonly attribute bigint changeId;
};
```

[types]

: Returns a
 [`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array) of
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) objects indicating the [mandatory data
 types](#mandatory-data-types) available on the [system
 clipboard](#system-clipboard) when the event was fired. [Optional data
 types](#optional-data-types) and custom formats are excluded to limit
 fingerprinting surface.

[changeId]

: Returns a
 [`bigint`](https://webidl.spec.whatwg.org/#idl-bigint) representing a unique identifier for this specific
 clipboard change operation. This identifier is consistent across all
 windows and tabs with the same [storage
 key](https://storage.spec.whatwg.org/#storage-key) for the same clipboard change, enabling
 applications to deduplicate events when multiple windows receive the
 same clipboard change notification.

 The
 [`changeId`](#dom-clipboardchangeevent-changeid) is a cryptographically derived 128-bit integer. The
 only guarantee is that after something is written to the clipboard,
 [`changeId`](#dom-clipboardchangeevent-changeid) will yield a different value than it did before the
 write operation.

##### 5.2.1.3. ClipboardChangeEvent constructor steps

The [ClipboardChangeEvent(type,
eventInitDict)] constructor steps are:

1. Set [this](https://webidl.spec.whatwg.org/#this).[`types`](#dom-clipboardchangeevent-types) to a
 [clone](https://infra.spec.whatwg.org/#list-clone) of
 `eventInitDict`\[\"[`types`](#dom-clipboardchangeeventinit-types)\"\].

2. Set [this](https://webidl.spec.whatwg.org/#this).[`changeId`](#dom-clipboardchangeevent-changeid) to
 `eventInitDict`\[\"[`changeId`](#dom-clipboardchangeeventinit-changeid)\"\].

##### 5.2.1.4. ChangeId Generation

To [generate a changeId] for a
[`Document`](https://dom.spec.whatwg.org/#document) `document`:

1. Let `globalChangeId` be a user agent-specific unique
 identifier representing the current state of the [system
 clipboard](#system-clipboard). This identifier changes each time the [system
 clipboard](#system-clipboard) is modified, and is reset when the user agent
 restarts.

2. Let `storageKey` be the result of running [obtain a
 storage key for non-storage
 purposes](https://storage.spec.whatwg.org/#obtain-a-storage-key-for-non-storage-purposes)
 given `document`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

3. Let `storageKeyBytes` be some user agent-specific binary
 representation of `storageKey`.

4. Let `hashedValue` be the result of applying a
 cryptographic hash function (such as SHA-256) to the concatenation
 of `globalChangeId` (as bytes) and
 `storageKeyBytes`.

5. Return a 128-bit integer derived from `hashedValue` (for
 example, by taking the first 128 bits of the hash output).

The above algorithm ensures that documents from the same origin and with
the same partitioning receive identical change IDs for the same
clipboard modification, enabling proper event deduplication across
multiple windows and tabs, while preventing cross-partition correlation
that could be used for tracking. As Client-side Storage Partitioning
changes are incorporated into the storage key definition, this approach
will automatically provide anonymization across partitions.

The
[`changeId`](#dom-clipboardchangeevent-changeid) does not persist across browser restarts, as the
`globalChangeId` counter is reset when the user agent
restarts. Similarly, when a user clears site data, the affected tabs
should be refreshed, which causes event listeners to be re-attached and
only receive future events with new change IDs.

Since synthetic
[`cut`](#eventdef-globaleventhandlers-cut) and
[`copy`](#eventdef-globaleventhandlers-copy) events do not update the [system
clipboard](#system-clipboard), they will not trigger a \"clipboardchange\" event.

The
[`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange) event enables web applications to efficiently monitor
clipboard changes and provide dynamic user interfaces based on available
data formats:

``` javascript
// For applications with multiple windows, track processed change IDs to avoid duplication
const processedChangeIds = new Set();

// Listen for clipboard changes
navigator.clipboard.addEventListener('clipboardchange', (e) => {
 // Deduplicate events across multiple windows using changeId
 if (processedChangeIds.has(e.changeId)) {
 return; // This change has already been processed
 }
 processedChangeIds.add(e.changeId);

 // Check what data types are available on the clipboard
 const hasText = e.types.includes('text/plain');
 const hasHTML = e.types.includes('text/html');
 const hasImage = e.types.includes('image/png');

 // Update UI based on available formats
 document.getElementById('paste-text-btn').disabled = !hasText;
 document.getElementById('paste-html-btn').disabled = !hasHTML;
 document.getElementById('paste-image-btn').disabled = !hasImage;

 // For remote desktop apps, sync clipboard to remote only once per change
 if (hasText || hasHTML || hasImage) {
 syncClipboardToRemote(e.changeId);
 }
});

// Alternatively, you can use the onclipboardchange property
// navigator.clipboard.onclipboardchange = (e) => { ... };
```

This event-driven approach is more efficient than polling the clipboard
with methods like
[`read()`](#dom-clipboard-read) or
[`readText()`](#dom-clipboard-readtext) and works across browsers that require user activation
for clipboard access, as the UI can react instantly to clipboard changes
without waiting for a timer to fire. The
[`changeId`](#dom-clipboardchangeevent-changeid) is particularly useful for applications with multiple
windows, ensuring that each clipboard change is processed only once
across all windows with the same [storage
key](https://storage.spec.whatwg.org/#storage-key).

#### [5.2.2. ][The [`copy`] event]
When the user initiates a copy action, the user agent [fires a clipboard
event](#fire-a-clipboard-event) named
[`copy`](#eventdef-globaleventhandlers-copy).

If the event is not canceled, the currently selected data will be copied
to the [system clipboard](#system-clipboard). The current document selection is not affected.

The
[`copy`](#eventdef-globaleventhandlers-copy) event bubbles, is cancelable, and is composed.

See [§ 8.1 The copy action](#copy-action) for a detailed description of
the processing model for this event.

A synthetic
[`copy`](#eventdef-globaleventhandlers-copy) event can be manually constructed and dispatched, but
it will not affect the contents of the [system
clipboard](#system-clipboard).

#### [5.2.3. ][The [`cut`] event]
When the user initiates a cut action, the user agent [fires a clipboard
event](#fire-a-clipboard-event) named
[`cut`](#eventdef-globaleventhandlers-cut).

In an [editable context](#editable-context), if the event is not canceled the action will place the
currently selected data on the [system
clipboard](#system-clipboard) and remove the selection from the document. The
[`cut`](#eventdef-globaleventhandlers-cut) event fires before the selected data is removed. When
the cut operation is completed, the selection is collapsed.

In a non-[editable
context](#editable-context),
the
[`clipboardData`](#dom-clipboardevent-clipboarddata) will be an empty list. Note that the
[`cut`](#eventdef-globaleventhandlers-cut) event will still be fired in this case.

The
[`cut`](#eventdef-globaleventhandlers-cut) event bubbles, is cancelable, and is composed.

See [§ 8.2 The cut action](#cut-action) for a detailed description of
the processing model for this event.

A synthetic
[`cut`](#eventdef-globaleventhandlers-cut) event can be manually constructed and dispatched, but
it will not affect the contents of the document or of the [system
clipboard](#system-clipboard).

#### [5.2.4. ][The [`paste`] event]
When a user initiates a paste action, the user agent [fires a clipboard
event](#fire-a-clipboard-event) named
[`paste`](#eventdef-globaleventhandlers-paste). The event fires before any clipboard data is inserted
into the document.

If the cursor is in an [editable
context](#editable-context),
the paste action will insert clipboard data in the most suitable format
(if any) supported for the given context.

The paste action has no effect in a non-[editable
context](#editable-context),
but the
[`paste`](#eventdef-globaleventhandlers-paste) event fires regardless.

The
[`paste`](#eventdef-globaleventhandlers-paste) event bubbles, is cancelable, and is composed.

See [§ 8.3 The paste action](#paste-action) for a detailed description
of the processing model for this event.

A synthetic
[`paste`](#eventdef-globaleventhandlers-paste) event can be manually constructed and dispatched, but
it will not affect the contents of the document.

### 5.3. Integration with other scripts and events

#### [5.3.1. ][Event handlers that are [allowed to modify the clipboard]]
Event handlers may write to the clipboard if any of the following is
true:

- The action which triggers the event is invoked from the user-agent's
 own user interface, e.g. from a \"Copy\" menu entry or shortcut key.

- The action which triggers the event is invoked from a scripting thread
 which is [allowed to show a
 popup](http://www.w3.org/TR/html5/browsers.html#allowed-to-show-a-popup).

The implementation *may* allow other trusted event types to modify the
clipboard if the implementation authors believe that those event types
are likely to express user intention. The implementation *may* also
support configuration that trusts specific sites or apps to modify the
clipboard regardless of the origin of the scripting thread.

Synthetic
[`cut`](#eventdef-globaleventhandlers-cut) and
[`copy`](#eventdef-globaleventhandlers-copy) events *must not* modify data on the system clipboard.

#### [5.3.2. ][Event handlers that are [allowed to read from clipboard]]
Event handlers may read data from the system clipboard if either of the
following is true

- The action that triggers the event is invoked from the user-agent's
 own user interface, e.g. a \"Paste\" menu entry or shortcut key.

- The script that triggers the action is running on a site which through
 an implementation-dependant mechanism is given permission to read data
 from the clipboard.

- The action that triggers the event is triggered in an app with
 permissions to read the clipboard.

Synthetic
[`paste`](#eventdef-globaleventhandlers-paste) events *must not* give a script access to data on the
real system clipboard.

#### 5.3.3. Integration with rich text editing APIs

If an implementation supports ways to execute clipboard commands through
scripting, for example by calling the `document.execCommand()` method
with the commands \"cut\", \"copy\" and \"paste\", the implementation
*must* trigger the corresponding action, which again will dispatch the
associated clipboard event.

These are the steps to follow when triggering copy, cut or paste actions
through a scripting API:

1. Execute the corresponding action synchronously.

2. Use the action's return value as the return value for the API call.

 Copy and cut commands triggered through a scripting API
will only affect the contents of the real clipboard if the event is
dispatched from an event that is trusted and triggered by the user, or
if the implementation is configured to allow this. Paste commands
triggered through a scripting API will only fire paste events and give
access to clipboard contents if the implementation is configured to
allow this. How implementations can be configured to allow read or write
access to the clipboard is outside the scope of this specification.

#### 5.3.4. Interaction with other events

If the clipboard operation is triggered by keyboard input, the
implementation *must* fire the corresponding event that initiates the
clipboard operation. The event is asynchronous but *must* be dispatched
before **keyup** events for the relevant keys.

The cut and paste actions *may* cause the implementation to dispatch
other supported events, such as textInput, input, change, validation
events, DOMCharacterDataModified and DOMNodeRemoved / DOMNodeInserted.
Any such events are queued up to fire after processing of the cut/paste
event is finished.

The implementation *must not* dispatch other input-related events like
textInput, input, change, and validation events in response to the copy
operation.

#### 5.3.5. Event listeners that modify selection or focus

If the event listener modifies the selection or [focusable
area](https://html.spec.whatwg.org/multipage/interaction.html#focusable-area), the clipboard action *must* be completed on the
modified selection.

## 6. Clipboard Event API

The Clipboard Event API allows you to override the default cut, copy and
paste behavior of the user agent.

Access to the clipboard is performed using the standard
[`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) methods to mutate the
[`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items) on a
[`ClipboardEvent`](#clipboardevent)'s
[`clipboardData`](#dom-clipboardevent-clipboarddata) attribute. One consequence of this is that these
clipboard APIs can only access clipboard data in the context of a
[`ClipboardEvent`](#clipboardevent) handler.

 If you need to access the clipboard outside of a
clipboard event handler, see [§ 7 Asynchronous Clipboard
API](#async-clipboard-api).

 The Clipboard Event APIs are synchronous, so they are
limited in what they can do. Actions which are potentially blocking
(like asking for permission or transcoding a image) are not supported by
these APIs. See [§ 7 Asynchronous Clipboard API](#async-clipboard-api)
for a more powerful API that can support blocking or other
time-consuming actions.

### 6.1. Overriding the copy event

To override the default
[`copy`](#eventdef-globaleventhandlers-copy) event behavior, a
[`copy`](#eventdef-globaleventhandlers-copy) event handler must be added and this event handler must
call
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) to cancel the event.

Canceling the event is required in order for the [system
clipboard](#system-clipboard) to be updated with the data in
[`clipboardData`](#dom-clipboardevent-clipboarddata). If the
[`ClipboardEvent`](#clipboardevent) is not canceled, then the data from the current
document selection will be copied instead.

```
// Overwrite what is being copied to the clipboard.
document.addEventListener('copy', function(e) {
 // e.clipboardData is initially empty, but we can set it to the
 // data that we want copied onto the clipboard.
 e.clipboardData.setData('text/plain', 'Hello, world!');
 e.clipboardData.setData('text/html', '<b>Hello, world!</b>');

 // This is necessary to prevent the current document selection from
 // being written to the clipboard.
 e.preventDefault();
});
```

### 6.2. Overriding the cut event

To override the default
[`cut`](#eventdef-globaleventhandlers-cut) event behavior, a
[`cut`](#eventdef-globaleventhandlers-cut) event handler must be added and this event handler must
call
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) to cancel the event.

Canceling the event is required in order for the [system
clipboard](#system-clipboard) to be updated with the data in
[`clipboardData`](#dom-clipboardevent-clipboarddata). If the
[`ClipboardEvent`](#clipboardevent) is not canceled, then the data from the current
document selection will be copied instead.

Note that canceling the
[`cut`](#eventdef-globaleventhandlers-cut) event will also prevent the document from being updated
(i.e., the current selection will not be removed). The event handler
will need to manually update the document to remove the currently
selected text.

```
// Overwrite what is copied to the clipboard.
document.addEventListener('cut', function(e) {
 // e.clipboardData is initially empty, but we can set it to the
 // data that we want copied onto the clipboard as part of the cut.
 // Write the data that we want copied onto the clipboard.
 e.clipboardData.setData('text/plain', 'Hello, world!');
 e.clipboardData.setData('text/html', '<b>Hello, world!</b>');

 // Since we will be canceling the cut operation, we need to manually
 // update the document to remove the currently selected text.
 deleteCurrentDocumentSelection();

 // This is necessary to prevent the document selection from being
 // written to the clipboard.
 e.preventDefault();
});
```

### 6.3. Overriding the paste event

To override the default
[`paste`](#eventdef-globaleventhandlers-paste) event behavior, a
[`paste`](#eventdef-globaleventhandlers-paste) event handler must be added and this event handler must
call
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) to cancel the event.

Canceling the event is required so that the user agent does not update
the document with data from the [system
clipboard](#system-clipboard).

Note that canceling the
[`paste`](#eventdef-globaleventhandlers-paste) event will also prevent the document from being updated
(i.e., nothing will be pasted into the document). The event handler will
need to manually paste the data into the document.

Also note that, when pasting, the [drag data store
mode](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-store-mode) flag is
[read-only](https://html.spec.whatwg.org/multipage/interaction.html#concept-dnd-ro), hence calling
[`setData()`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-setdata) from a
[`paste`](#eventdef-globaleventhandlers-paste) event handler will not modify the data that is
inserted, and not modify the data on the clipboard.

```
// Overwrite what is being pasted onto the clipboard.
document.addEventListener('paste', function(e) {
 // e.clipboardData contains the data that is about to be pasted.
 if (e.clipboardData.types.indexOf('text/html') > -1) {
 var oldData = e.clipboardData.getData('text/html');
 var newData = '<b>Ha Ha!</b> ' + oldData;

 // Since we are canceling the paste operation, we need to manually
 // paste the data into the document.
 pasteClipboardData(newData);

 // This is necessary to prevent the default paste action.
 e.preventDefault();
 }
});
```

### [6.4. ][[Mandatory data types]]
The implementation must recognize the native OS clipboard format
description for the following data types, to be able to populate the
[`DataTransferItemList`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitemlist) and
[`ClipboardItem`](#clipboarditem) with the correct description for paste events, and set
the correct data format on the OS clipboard in response to copy and cut
events.

#### 6.4.1. Reading from the clipboard

These data types must be exposed by *paste* events if a corresponding
native type exists on the clipboard:

- text/plain

- text/html

- image/png

#### 6.4.2. Writing to the clipboard

These data types must be placed on the clipboard with a corresponding
native type description if added to a
[`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) object during *copy* and *cut* events.

- text/plain

- text/html

- image/png

**Warning! The data types that untrusted scripts are allowed to write to
the clipboard are limited as a security precaution. Untrusted scripts
can attempt to exploit security vulnerabilities in local software by
placing data known to trigger those vulnerabilities on the clipboard.**

### [6.5. ][[Optional data types]]
The implementation MAY recognize the native OS clipboard format
description for the following data types, to be able to populate the
[`ClipboardItem`](#clipboarditem) with the correct description for paste events, and set
the correct data format on the OS clipboard in response to copy and cut
events.

These data types MAY be exposed by UAs if a corresponding native type
exists on the clipboard:

- text/uri-list

- image/svg+xml

- Custom format [starts
 with](https://infra.spec.whatwg.org/#string-starts-with) \`\"web \"\`(\"web\" followed by U+0020 SPACE) prefix
 and suffix (after stripping out \`\"web \"\`) passes the [parsing a
 MIME
 type](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) check.

### [6.6. ][[Unsanitized data types]]
*This section is non-normative.*

These data types MUST NOT be sanitized by UAs:

- image/png

These data types MAY NOT be sanitized by UAs:

- [optional unsanitized data
 types](#optional-unsanitized-data-types)

[Optional unsanitized data types] are [mime
type](#representation-mime-type)s specified by the web authors that MAY NOT be sanitized
by the user agent. The valid [optional unsanitized data
types](#optional-unsanitized-data-types) are listed below:

- text/html

[optional unsanitized data
types](#optional-unsanitized-data-types) may not be supported by a user agent due to their
privacy requirements.

## 7. Asynchronous Clipboard API

### 7.1. Navigator Interface

```
partial interface Navigator {
 [SecureContext, SameObject] readonly attribute Clipboard clipboard;
};
```

#### [7.1.1. ][[clipboard]]
It is used to execute read/write operations from/to the [system
clipboard](#system-clipboard). The
[`clipboard`](#dom-navigator-clipboard) getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s
[clipboard](#navigator-clipboard) object.

### 7.2. ClipboardItem Interface

```
typedef Promise<(DOMString or Blob)> ClipboardItemData;

[SecureContext, Exposed=Window]
interface ClipboardItem {
 constructor(record<DOMString, ClipboardItemData> items,
 optional ClipboardItemOptions options = );

 readonly attribute PresentationStyle presentationStyle;
 readonly attribute FrozenArray<DOMString> types;

 Promise<Blob> getType(DOMString type);

 static boolean supports(DOMString type);
};

enum PresentationStyle { "unspecified", "inline", "attachment" };

dictionary ClipboardItemOptions {
 PresentationStyle presentationStyle = "unspecified";
};
```

`clipboardItem`` = new ClipboardItem([``items``, ``options``])`

: Creates a new
 [`ClipboardItem`](#clipboarditem) object. `items` denote [list of
 representations](#list-of-representations), each
 [representation](#representation) has a [mime
 type](#representation-mime-type) and a
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) to
 [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob) or
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) corresponding to the [mime
 type](#representation-mime-type), `options` can be used to fill its
 [`ClipboardItemOptions`](#dictdef-clipboarditemoptions), as per the example below.

 ```
 const format1 = 'text/plain';
 const promise_text_blob = Promise.resolve(new Blob(['hello'], {type: format1}));
 const clipboardItemInput = new ClipboardItem(
 {[format1]: promise_text_blob},
 {presentationStyle: "unspecified"});
 ```

`clipboardItem``.getType(``type``)`
: Returns a
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) to the
 [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob) corresponding to the [mime
 type](#representation-mime-type) `type`.

`clipboardItem``.``types`
: Returns the list of [mime
 type](#representation-mime-type)s contained in the [clipboard
 item](#clipboard-item)
 object.

[`ClipboardItem`](#clipboarditem)`.supports(``type``)`
: Returns true if `type` is in [mandatory data
 types](#mandatory-data-types) or [optional data
 types](#optional-data-types), else, returns false.

A [clipboard item] is conceptually data that the user has expressed a desire
to make shareable by invoking a \"cut\" or \"copy\" command. A
[clipboard item](#clipboard-item) serves two purposes. First, it allows a website to read
data copied by a user to the [system
clipboard](#system-clipboard). Second, it allows a website to write data to the
[system clipboard](#system-clipboard).

For example, if a user copies a range of cells from a spreadsheet of a
native application, it will result in one [clipboard
item](#clipboard-item). If a
user copies a set of files from their desktop, that list of files will
be represented by multiple [clipboard
item](#clipboard-item)s.

Some platforms may support having more than one [clipboard
item](#clipboard-item) at a
time on the
[clipboard](#navigator-clipboard), while other platforms replace the previous [clipboard
item](#clipboard-item) with
the new one.

A [clipboard item](#clipboard-item) has a [list of
representations], each [representation] with an associated [MIME
type] (a [MIME
type](https://mimesniff.spec.whatwg.org/#mime-type)), an [isCustom] flag,
initially `false`, that indicates if this
[representation](#representation) should be treated as a [web custom
format](#web-custom-format)
(as opposed to a well-known format of the [system
clipboard](#system-clipboard)), and [data] (a
[`ClipboardItemData`](#typedefdef-clipboarditemdata)).

A [web custom format] has
[isCustom](#representation-iscustom) set to `true`.

In the example where the user copies a range of cells from a
spreadsheet, it may be represented as an image (image/png), an HTML
table (text/html), or plain text (text/plain), or a web custom format
(web text/csv).

Each of these [MIME
type](https://mimesniff.spec.whatwg.org/#mime-type)s describe a different
[representation](#representation) of the same [clipboard
item](#clipboard-item) at
different levels of fidelity and make the [clipboard
item](#clipboard-item) more
consumable by target applications during paste.

Making the range of cells available as an image will allow the user to
paste the cells into a photo editing app, while the text/plain format
can be used by text editor apps.

A [clipboard item](#clipboard-item) has a [presentation style] (a
[`PresentationStyle`](#enumdef-presentationstyle)). It helps distinguish whether apps \"pasting\" a
[clipboard item](#clipboard-item) should insert the contents of an appropriate
[representation](#representation) inline at the point of paste or if it should be treated
as an attachment.

Web apps that support pasting only a single [clipboard
item](#clipboard-item) should
use the first [clipboard
item](#clipboard-item).

[`write()`](#dom-clipboard-write) chooses the last [clipboard
item](#clipboard-item).

Web apps that support pasting more than one [clipboard
item](#clipboard-item) could,
for example, provide a user interface that previews the contents of each
[clipboard item](#clipboard-item) and allow the user to choose which one to paste.
Further, apps are expected to enumerate the [MIME
type](https://mimesniff.spec.whatwg.org/#mime-type)s of the [clipboard
item](#clipboard-item) they
are pasting and select the one best-suited for the app according to some
app-specific algorithm. Alternatively, an app can present the user with
options on how to paste a [clipboard
item](#clipboard-item), e.g.
\"paste as image\" or \"paste formatted text\", etc.

A [`ClipboardItem`](#clipboarditem) object has an associated [clipboard
item], which is a
[clipboard item](#clipboard-item).

A [`ClipboardItem`](#clipboarditem) object has an associated [types
array], which is a
[`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array)\<[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)\>.

A [`ClipboardItem`](#clipboarditem) object has an associated [clipboard change count at
read], which is initially
null.

A [`ClipboardItem`](#clipboarditem) object has an associated [originating system clipboard
item], which is a [system
clipboard item](#system-clipboard-item) or null, initially null.

A [`ClipboardItem`](#clipboarditem) object has an associated [unsanitized MIME
types], which is a
[sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)\>, initially empty.

A [`ClipboardItem`](#clipboarditem) object has an associated [representations with
resolvers], which
is a
[map](https://infra.spec.whatwg.org/#ordered-map) from a string (the [MIME
type](https://mimesniff.spec.whatwg.org/#mime-type) as passed to
[`getType()`](#dom-clipboarditem-gettype), including the \`\"web \"\` prefix when present) to a
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob)\>, initially empty. Each entry represents an OS
clipboard read for that type that has either completed or is currently
in flight.

 This map ensures that concurrent
[`getType()`](#dom-clipboarditem-gettype) calls for the same MIME type on a
[`ClipboardItem`](#clipboarditem) obtained from
[`read()`](#dom-clipboard-read) share a single OS clipboard read. The first call
inserts a pending
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) into the map and initiates the read; subsequent calls
for the same MIME type return the existing
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) without re-reading the [system
clipboard](#system-clipboard).

When a [`ClipboardItem`](#clipboarditem) is created by
[`read()`](#dom-clipboard-read), it acts as a lazy fetcher rather than a data snapshot.
Its [types
array](#clipboarditem-types-array) reflects the formats available on the [system
clipboard](#system-clipboard) at the time of the
[`read()`](#dom-clipboard-read) call, but the actual payload bytes are not read until
[`getType()`](#dom-clipboarditem-gettype) is called. If the [system
clipboard](#system-clipboard) contents change between the
[`read()`](#dom-clipboard-read) call and a subsequent
[`getType()`](#dom-clipboarditem-gettype) call, the
[`getType()`](#dom-clipboarditem-gettype) call will be rejected. A
[`ClipboardItem`](#clipboarditem) constructed directly via the
[`ClipboardItem(items, options)`](#dom-clipboarditem-clipboarditem) constructor is not subject to this behavior.

To [create a
[`ClipboardItem`](#clipboarditem) object], given a [clipboard
item](#clipboard-item)
`clipboardItem` and a Realm `realm`, run these
steps:

1. Let `clipboardItemObject` be a
 [new](https://webidl.spec.whatwg.org/#new)
 [`ClipboardItem`](#clipboarditem) with `realm`.

2. Set `clipboardItemObject`'s [clipboard
 item](#clipboard-item) to
 `clipboardItem`.

The
[`new ClipboardItem(``items``, ``options``)`]
constructor steps are:

1. If `items` is empty, then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. If `options` is empty, then set
 options\[\"presentationStyle\"\] = \"unspecified\".

3. Set [this](https://webidl.spec.whatwg.org/#this)'s [clipboard
 item](#clipboarditem-clipboard-item) to a new [clipboard
 item](#clipboard-item).

4. Set [this](https://webidl.spec.whatwg.org/#this)'s [clipboard
 item](#clipboarditem-clipboard-item)'s [presentation
 style](#presentation-style) to
 `options`\[\"[`presentationStyle`](#dom-clipboarditemoptions-presentationstyle)\"\].

5. Let `types` be a list of
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString).

6. For each (`key`, `value`) in
 `items`:

 1. Let `representation` be a new
 [representation](#representation).

 2. Let `isCustom` be `false`.

 3. If `key` [starts
 with](https://infra.spec.whatwg.org/#string-starts-with) \`\"web \"\` prefix, then

 1. Remove \`\"web \"\` prefix and assign the remaining string
 to `key`.

 2. Set `isCustom` `true`

 4. Set `representation`'s
 [isCustom](#representation-iscustom) flag to `isCustom`.

 5. Let `mimeType` be the result of [parsing a MIME
 type](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) given `key`.

 6. If `mimeType` is failure, then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 7. If [this](https://webidl.spec.whatwg.org/#this)'s [clipboard
 item](#clipboarditem-clipboard-item)'s [list of
 representations](#list-of-representations)
 [contains](https://infra.spec.whatwg.org/#list-contain) a
 [representation](#representation) whose [MIME
 type](#representation-mime-type) is `mimeType` and whose
 \[representation/isCustom\] is `isCustom`, then throw
 a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 The step above prevents collision between mime-types well-known by
 the user agent and those that are intended by the author to be
 treated as a custom type. For example, it would be possible for the
 author's list of items to contain representations for \"text/html\"
 as well as \"web text/html\".

 1. Set `representation`'s [MIME
 type](#representation-mime-type) to `mimeType`.

 2. Set `representation`'s
 [data](#representation-data) to `value`.

 3. Append `representation` to
 [this](https://webidl.spec.whatwg.org/#this)'s [clipboard
 item](#clipboarditem-clipboard-item)'s [list of
 representations](#list-of-representations).

 4. Let `mimeTypeString` be the result of [serializing a
 MIME
 type](https://mimesniff.spec.whatwg.org/#serialize-a-mime-type) with `mimeType`.

 5. If `isCustom` is `true`, prefix
 `mimeTypeString` with \`\"web \"\`.

 6. Add `mimeTypeString` to `types`.

7. Set [this](https://webidl.spec.whatwg.org/#this)'s [types
 array](#clipboarditem-types-array) to the result of running [create a frozen
 array](https://webidl.spec.whatwg.org/#dfn-create-frozen-array) from `types`.

#### 7.2.1. presentationStyle

The
[`presentationStyle`](#dom-clipboarditem-presentationstyle) getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [clipboard
item](#clipboarditem-clipboard-item)'s [presentation
style](#presentation-style).

#### 7.2.2. types

The
[`types`](#dom-clipboarditem-types) getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [types
array](#clipboarditem-types-array).

#### 7.2.3. getType(type)

This method must run the below steps:

1. Let `realm` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

2. Let `isCustom` be `false`.

3. If `type` [starts
 with](https://infra.spec.whatwg.org/#string-starts-with) \`\"web \"\` prefix, then:

 1. Remove \`\"web \"\` prefix and assign the remaining string to
 `type`.

 2. Set `isCustom` to `true`.

4. Let `mimeType` be the result of [parsing a MIME
 type](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) given `type`.

5. If `mimeType` is failure, then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

6. Let `itemTypeList` be
 [this](https://webidl.spec.whatwg.org/#this)'s [clipboard
 item](#clipboarditem-clipboard-item)'s [list of
 representations](#list-of-representations).

7. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in `realm`.

8. For each `representation` in `itemTypeList`:

 1. If `representation`'s [MIME
 type](#representation-mime-type) is `mimeType` and
 `representation`'s
 [isCustom](#representation-iscustom) is `isCustom`, then:

 1. If
 [this](https://webidl.spec.whatwg.org/#this)'s [clipboard change count at
 read](#clipboarditem-clipboard-change-count-at-read) is not null, and the current [clipboard
 change
 count](#clipboard-change-count) is not equal to
 [this](https://webidl.spec.whatwg.org/#this)'s [clipboard change count at
 read](#clipboarditem-clipboard-change-count-at-read), then
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 [`"InvalidStateError"`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`, and return
 `p`.

 This ensures that stale data is never
 returned. If the [system
 clipboard](#system-clipboard) contents have changed since
 [`read()`](#dom-clipboard-read) was called, this MUST fail rather than
 returning data that does not correspond to the current
 [system
 clipboard](#system-clipboard) state.

 A null [clipboard change count at
 read](#clipboarditem-clipboard-change-count-at-read) indicates that this
 [`ClipboardItem`](#clipboarditem) was constructed directly by the author
 (e.g., via
 [`ClipboardItem(items, options)`](#dom-clipboarditem-clipboarditem)), not obtained from
 [`read()`](#dom-clipboard-read). In that case, no stale-data check is
 needed because the data does not originate from the [system
 clipboard](#system-clipboard).

 2. If
 [this](https://webidl.spec.whatwg.org/#this)'s [clipboard change count at
 read](#clipboarditem-clipboard-change-count-at-read) is not null, then:

 This branch covers
 [`ClipboardItem`](#clipboarditem)s obtained from
 [`read()`](#dom-clipboard-read), for which the OS clipboard read is
 deferred to this point. To ensure the read happens at most
 once per type --- even if
 [`getType()`](#dom-clipboarditem-gettype) is called multiple times concurrently for
 the same MIME type --- the resulting
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) is cached in
 [this](https://webidl.spec.whatwg.org/#this)'s [representations with
 resolvers](#clipboarditem-representations-with-resolvers) map, keyed by a normalized type string so
 that \`\"text/html\"\` and \`\"web text/html\"\` are tracked
 independently while differently-cased spellings of the same
 type (e.g., \`\"text/HTML\"\` and \`\"text/html\"\`)
 collapse to a single entry.

 1. Let `key` be `mimeType`'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence). If `isCustom` is true,
 prefix `key` with \`\"web \"\`.

 2. If
 [this](https://webidl.spec.whatwg.org/#this)'s [representations with
 resolvers](#clipboarditem-representations-with-resolvers)\[`key`\]
 [exists](https://infra.spec.whatwg.org/#map-exists), then return
 [this](https://webidl.spec.whatwg.org/#this)'s [representations with
 resolvers](#clipboarditem-representations-with-resolvers)\[`key`\].

 3. [Set](https://infra.spec.whatwg.org/#map-set)
 [this](https://webidl.spec.whatwg.org/#this)'s [representations with
 resolvers](#clipboarditem-representations-with-resolvers)\[`key`\] to `p`.

 4. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `clipboardItem` be
 [this](https://webidl.spec.whatwg.org/#this)'s [originating system clipboard
 item](#clipboarditem-originating-system-clipboard-item).

 2. If `clipboardItem` is null, then [queue a
 global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [clipboard task
 source](#clipboard-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 [`"InvalidStateError"`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`, then abort
 these steps.

 3. If `isCustom` is true, then:

 1. Let `mapName` be the [os specific
 custom map
 name](#os-specific-custom-map-name).

 2. Let `mapRepresentation` be the
 [system clipboard
 representation](#system-clipboard-representation) in `clipboardItem`'s
 list of [system clipboard
 representation](#system-clipboard-representation)s whose
 [name](#system-clipboard-representation-name) is `mapName`. If
 there is no such [system clipboard
 representation](#system-clipboard-representation), then [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [clipboard task
 source](#clipboard-task-source), given `realm`'s
 [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with a
 [`"NotFoundError"`](https://webidl.spec.whatwg.org/#notfounderror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`, then
 abort these steps.

 3. Let `webCustomFormatMapString` be the
 JSON string deserialized from
 `mapRepresentation`'s
 [data](#system-clipboard-representation-data).

 4. Let `osFormatName` be the value in
 `webCustomFormatMapString` whose key
 matches `mimeType`
 [serialized](https://mimesniff.spec.whatwg.org/#serialize-a-mime-type).

 5. If `osFormatName` is not found, then
 [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [clipboard task
 source](#clipboard-task-source), given `realm`'s
 [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with a
 [`"NotFoundError"`](https://webidl.spec.whatwg.org/#notfounderror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`, then
 abort these steps.

 4. Else, let `osFormatName` be the result of
 running [os specific well-known
 format](#os-specific-well-known-format) given `mimeType`.

 5. Let `clipboardRepresentation` be the
 [system clipboard
 representation](#system-clipboard-representation) in `clipboardItem`'s
 list of [system clipboard
 representation](#system-clipboard-representation)s whose
 [name](#system-clipboard-representation-name) is `osFormatName`. If
 there is no such [system clipboard
 representation](#system-clipboard-representation), then [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [clipboard task
 source](#clipboard-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with a
 [`"NotFoundError"`](https://webidl.spec.whatwg.org/#notfounderror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`, then abort
 these steps.

 6. Let `rawData` be
 `clipboardRepresentation`'s
 [data](#system-clipboard-representation-data).

 7. Let `cleanData` be a copy of
 `rawData`.

 8. If `mimeType`'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) is in
 [this](https://webidl.spec.whatwg.org/#this)'s [unsanitized MIME
 types](#clipboarditem-unsanitized-mime-types) and `mimeType`'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) is in the [optional unsanitized
 data
 types](#optional-unsanitized-data-types) list, then do nothing.

 9. Else, if `mimeType`'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) is not \"image/png\", the user
 agent MAY sanitize `cleanData`.

 10. Let `blob` be a
 [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob) whose
 [`type`](https://w3c.github.io/FileAPI/#dfn-type) is `mimeType`
 [serialized](https://mimesniff.spec.whatwg.org/#serialize-a-mime-type) and whose underlying byte sequence
 is `cleanData`.

 11. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [clipboard task
 source](#clipboard-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to resolve `p` with
 `blob`.

 Once `p` has settled, it remains
 in
 [this](https://webidl.spec.whatwg.org/#this)'s [representations with
 resolvers](#clipboarditem-representations-with-resolvers) map. Subsequent
 [`getType()`](#dom-clipboarditem-gettype) calls for the same MIME type will return
 the cached settled
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) without re-reading the [system
 clipboard](#system-clipboard). The stale-data check above still applies
 on every call, however: if the [system
 clipboard](#system-clipboard) has changed since
 [`read()`](#dom-clipboard-read) was called, all
 [`getType()`](#dom-clipboarditem-gettype) calls on this
 [`ClipboardItem`](#clipboarditem) will be rejected with an
 [`"InvalidStateError"`](https://webidl.spec.whatwg.org/#invalidstateerror) --- even for previously cached data.

 1. Return `p`.

 3. Let `representationDataPromise` be the
 `representation`'s
 [data](#representation-data).

 4. [React](https://webidl.spec.whatwg.org/#dfn-perform-steps-once-promise-is-settled) to `representationDataPromise`:

 1. If `representationDataPromise` was fulfilled
 with value `v`, then:

 1. If `v` is a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), then follow the below steps:

 1. Let `dataAsBytes` be the result of
 [UTF-8
 encoding](https://encoding.spec.whatwg.org/#utf-8-encode) `v`.

 2. Let `blobData` be a
 [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob) created using
 `dataAsBytes` with its
 [`type`](https://w3c.github.io/FileAPI/#dfn-type) set to `mimeType`,
 [serialized](https://mimesniff.spec.whatwg.org/#serialize-a-mime-type).

 3. Resolve `p` with
 `blobData`.

 2. If `v` is a
 [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob), then follow the below steps:

 1. Resolve `p` with `v`.

 2. If `representationDataPromise` was rejected,
 then:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotFoundError"`](https://webidl.spec.whatwg.org/#notfounderror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`.

 (#issue-2d83c5ad) Web developers might
 be interested in the underlying rejection reason.

 5. Return `p`.

9. [Reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotFoundError"`](https://webidl.spec.whatwg.org/#notfounderror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`.

10. Return `p`.

#### 7.2.4. supports(type)

This method must run the below steps:

1. If `type` is in [mandatory data
 types](#mandatory-data-types) or [optional data
 types](#optional-data-types), then return true.

2. If not, then return false.

### 7.3. Clipboard Interface

```
typedef sequence<ClipboardItem> ClipboardItems;

[SecureContext, Exposed=Window]
interface Clipboard : EventTarget {
 Promise<ClipboardItems> read(optional ClipboardUnsanitizedFormats formats = );
 Promise<DOMString> readText();
 Promise<undefined> write(ClipboardItems data);
 Promise<undefined> writeText(DOMString data);
};

dictionary ClipboardUnsanitizedFormats {
 sequence<DOMString> unsanitized;
};
```

Some methods of the [`Clipboard`](#clipboard) interface take or return multiple
[`ClipboardItem`](#clipboarditem) objects. However, not all platforms support more than
one [clipboard item](#clipboard-item); on such platforms, the algorithms below will ignore
any [`ClipboardItem`](#clipboarditem) objects beyond the first one that are passed to
[`write()`](#dom-clipboard-write), and
[`read()`](#dom-clipboard-read) and
[`readText()`](#dom-clipboard-readtext) only get one clipboard item from the OS.

A [clipboard items] object is a
[sequence](https://webidl.spec.whatwg.org/#idl-sequence) of [clipboard
item](#clipboard-item)s.

A web author needs to create a `data` which is an array of
[`ClipboardItem`](#clipboarditem)s in order to write content to [system
clipboard](#system-clipboard) using the
[`write(data)`](#dom-clipboard-write) method.
[`read()`](#dom-clipboard-read) returns a
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) to [clipboard
items](#clipboard-items)
object that represents contents of [system clipboard
data](#system-clipboard-data).

[`unsanitized`](#dom-clipboardunsanitizedformats-unsanitized) is a
[sequence](https://webidl.spec.whatwg.org/#idl-sequence) of
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)s corresponding to the [mime
type](#representation-mime-type) that the author wants to be treated as [optional
unsanitized data
types](#optional-unsanitized-data-types).

The
[`unsanitized`](#dom-clipboardunsanitizedformats-unsanitized) option MAY NOT be supported by the user agent. The web
authors shouldn't assume that the content for the MIME types listed in
[`unsanitized`](#dom-clipboardunsanitizedformats-unsanitized) would be unsanitized as there could be privacy modes
where this option may not be allowed.

The [clipboard task source] is triggered in response to reading or
writing of [system clipboard
data](#system-clipboard-data).

#### 7.3.1. read(`formats`)

The
[`read(formats)`](#dom-clipboard-read) method must run these steps:

1. Let `realm` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

2. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in `realm`.

3. If `formats` is not empty, then:

 1. For each `format` in
 `formats`\[\"[`unsanitized`](#dom-clipboardunsanitizedformats-unsanitized)\"\]:

 1. If `format` is not in [optional unsanitized data
 types](#optional-unsanitized-data-types), then
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with `format`
 [`"NotAllowedError"`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`.

4. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `r` be the result of running [check clipboard
 read
 permission](#check-clipboard-read-permission).

 2. If `r` is false, then:

 1. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [permission task
 source](https://w3c.github.io/permissions/#permissions-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotAllowedError"`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`.

 2. Abort these steps.

 3. Let `data` be the [system clipboard
 data](#system-clipboard-data).

 4. Let `snapshotChangeCount` be the current [clipboard
 change
 count](#clipboard-change-count).

 Only the
 [name](#system-clipboard-representation-name)s (format identifiers) from `data`
 are enumerated at this point. The underlying payload bytes for
 each [representation](#representation) are not read until
 [`getType()`](#dom-clipboarditem-gettype) is called.

 5. Let `items` be a
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence) of [ordered
 maps](https://infra.spec.whatwg.org/#ordered-map), each entry having keys \"item\" (a [clipboard
 item](#clipboard-item)) and \"originating\" (a [system clipboard
 item](#system-clipboard-item) or null).

 6. For each `systemClipboardItem` in `data`:

 1. Let `item` be a new [clipboard
 item](#clipboard-item).

 2. For each `systemClipboardRepresentation` in
 `systemClipboardItem`:

 1. Let `mimeType` be the result of running the
 [well-known mime type from os specific
 format](#well-known-mime-type-from-os-specific-format) algorithm given
 `systemClipboardRepresentation`'s
 [name](#system-clipboard-representation-name).

 2. If `mimeType` is null, continue this loop.

 3. Let `representation` be a new
 [representation](#representation).

 4. Set `representation`'s [MIME
 type](#representation-mime-type) to `mimeType`.

 5. Set `representation`'s
 [data](#representation-data) to [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in `realm`.

 The OS clipboard data for this
 [representation](#representation) will not be fetched until the author
 calls
 [`getType()`](#dom-clipboarditem-gettype) on the resulting
 [`ClipboardItem`](#clipboarditem) object.

 6. Append `representation` to
 `item`'s [list of
 representations](#list-of-representations).

 3. If `item`'s [list of
 representations](#list-of-representations) size is greater than 0, append the [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) «\[ \"item\" → `item`,
 \"originating\" → `systemClipboardItem` \]» to
 `items`.

 7. If `items` has a size \> 0, then:

 1. Let `firstItem` be
 `items`\[0\]\[\"item\"\]

 2. Run the [read web custom
 format](#read-web-custom-format) algorithm given `firstItem`.

 8. Else:

 1. Let `customItem` be a new [clipboard
 item](#clipboard-item).

 2. Run the [read web custom
 format](#read-web-custom-format) algorithm given `customItem`.

 3. If `customItem`'s [list of
 representations](#list-of-representations) size is greater than 0, append the [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) «\[ \"item\" → `customItem`,
 \"originating\" → null \]» to `items`.

 9. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [clipboard task
 source](#clipboard-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to perform the below steps:

 1. Let `clipboardItems` be a
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`ClipboardItem`](#clipboarditem)\>.

 2. For each [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) `entry` of `items`:

 1. Let `clipboardItem` be the result of running
 the steps of [create a ClipboardItem
 object](#create-a-clipboarditem-object) given `entry`\[\"item\"\]
 and `realm`.

 2. Set `clipboardItem`'s [clipboard change count
 at
 read](#clipboarditem-clipboard-change-count-at-read) to `snapshotChangeCount`.

 3. Set `clipboardItem`'s [originating system
 clipboard
 item](#clipboarditem-originating-system-clipboard-item) to
 `entry`\[\"originating\"\].

 4. If `formats` is not empty, set
 `clipboardItem`'s [unsanitized MIME
 types](#clipboarditem-unsanitized-mime-types) to
 `formats`\[\"[`unsanitized`](#dom-clipboardunsanitizedformats-unsanitized)\"\].

 5. Append `clipboardItem` to
 `clipboardItems`.

 3. Resolve `p` with `clipboardItems`.

5. Return `p`.

```
// clipboard.read() returns ClipboardItems with type metadata only.
// No OS clipboard data is read at this point.
const items = await navigator.clipboard.read();

// The OS clipboard read happens lazily here, when getType() is called.
const textBlob = await items[0].getType("text/plain");
const text = await (new Response(textBlob)).text();
```

#### 7.3.2. readText()

The
[`readText()`](#dom-clipboard-readtext) method must run these steps:

1. Let `realm` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

2. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in `realm`.

3. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `r` be the result of running [check clipboard
 read
 permission](#check-clipboard-read-permission).

 2. If `r` is false, then:

 1. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [permission task
 source](https://w3c.github.io/permissions/#permissions-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotAllowedError"`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`.

 2. Abort these steps.

 3. Let `data` be a copy of the [system clipboard
 data](#system-clipboard-data).

 (#issue-c148910f) Some OSs contain multiple
 clipboard (e.g. Linux, \"primary\", \"secondary\",
 \"selection\"). Define from which of those data is read.

 (#issue-1755f975) Add definition of sanitized
 copy.

 4. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [clipboard task
 source](#clipboard-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to perform the below steps:

 1. For each `systemClipboardItem` in
 `data`:

 1. For each `systemClipboardRepresentation` in
 `systemClipboardItem`:

 1. Let `mimeType` be the result of running
 the [well-known mime type from os specific
 format](#well-known-mime-type-from-os-specific-format) algorithm given
 `systemClipboardRepresentation`'s
 [name](#system-clipboard-representation-name).

 2. If `mimeType` is null, continue this
 loop.

 3. Let `representation` be a new
 [representation](#representation).

 4. If `representation`'s [MIME
 type](#representation-mime-type)
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) is \"text/plain\", then:

 1. Set `representation`'s [MIME
 type](#representation-mime-type) to `mimeType`.

 2. Let `representationDataPromise` be
 the `representation`'s
 [data](#representation-data).

 3. [React](https://webidl.spec.whatwg.org/#dfn-perform-steps-once-promise-is-settled) to
 `representationDataPromise`:

 1. If `representationDataPromise`
 was fulfilled with value `v`,
 then:

 1. If `v` is a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), then follow the below
 steps:

 1. Resolve `p` with
 `v`.

 2. Return `p`.

 2. If `v` is a
 [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob), then follow the below
 steps:

 1. Let `string` be the
 result of [UTF-8
 decoding](https://encoding.spec.whatwg.org/#utf-8-decode) `v`'s
 underlying byte sequence.

 2. Resolve `p` with
 `string`.

 3. Return `p`.

 2. If `representationDataPromise`
 was rejected, then:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotFoundError"`](https://webidl.spec.whatwg.org/#notfounderror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`.

 2. Return `p`.

 2. [Reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotFoundError"`](https://webidl.spec.whatwg.org/#notfounderror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`.

 3. Return `p`.

```
navigator.clipboard.readText().then(function(data) {
 console.log("Your string: ", data);
});
```

#### 7.3.3. write(`data`)

The
[`write(data)`](#dom-clipboard-write) method must run these steps:

1. Let `realm` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

2. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in `realm`.

3. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `r` be the result of running [check clipboard
 write
 permission](#check-clipboard-write-permission).

 (#issue-1b338371) clipboard-write was removed in
 https://github.com/w3c/clipboard-apis/pull/164.

 2. If `r` is false, then:

 1. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [permission task
 source](https://w3c.github.io/permissions/#permissions-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotAllowedError"`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`.

 2. Abort these steps.

 3. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [clipboard task
 source](#clipboard-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to perform the below steps:

 1. Let `itemList` and `cleanItemList` be
 an empty
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob)\>.

 2. Let `dataList` be a
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`ClipboardItem`](#clipboarditem)\>.

 3. If `data`'s
 [size](https://infra.spec.whatwg.org/#list-size) is greater than 1, and the current
 operating system does not support multiple native clipboard
 items on the [system
 clipboard](#system-clipboard), then add `data`\[0\] to
 `dataList`, else, set `dataList` to
 `data`.

 (#issue-f23cf1e2) when `data`
 contains multiple items and the operating system supports
 multiple native clipboard items, the current algorithm
 writes the items in sequence to the system clipboard instead
 of writing them collectively.

 4. For each `clipboardItem` in
 `dataList`:

 1. For each `representation` in
 `clipboardItem`'s [clipboard
 item](#clipboarditem-clipboard-item)'s [list of
 representations](#list-of-representations):

 1. Let `representationDataPromise` be the
 `representation`'s
 [data](#representation-data).

 2. [React](https://webidl.spec.whatwg.org/#dfn-perform-steps-once-promise-is-settled) to
 `representationDataPromise`:

 1. If `representationDataPromise` was
 fulfilled with value `v`, then:

 1. If `v` is a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), then follow the below
 steps:

 1. Let `dataAsBytes` be the
 result of [UTF-8
 encoding](https://encoding.spec.whatwg.org/#utf-8-encode) `v`.

 2. Let `blobData` be a
 [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob) created using
 `dataAsBytes` with its
 [`type`](https://w3c.github.io/FileAPI/#dfn-type) set to
 `representation`'s [MIME
 type](#representation-mime-type).

 3. Add `blobData` to
 `itemList`.

 2. If `v` is a
 [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob), then add `v` to
 `itemList`.

 2. If `representationDataPromise` was
 rejected, then:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotAllowedError"`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm`.

 2. Abort these steps.

 2. For each `blob` in `itemList`:

 1. Let `type` be the `blob`'s
 [`type`](https://w3c.github.io/FileAPI/#dfn-type).

 2. If `type` is not in the [mandatory data
 types](#mandatory-data-types) or [optional data
 types](#optional-data-types) list, then
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotAllowedError"`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `realm` and abort
 these steps.

 3. Let `cleanItem` be an optionally
 sanitized copy of `blob`.

 (#issue-1755f975①) Add definition of
 sanitized copy.

 4. If sanitization was attempted and was not
 successfully completed, then follow the below steps:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotAllowedError"`](https://webidl.spec.whatwg.org/#notallowederror) DOMException in
 `realm`.

 2. Abort these steps.

 5. Append `cleanItem` to
 `cleanItemList`.

 3. Let `option` be `clipboardItem`'s
 [clipboard
 item](#clipboarditem-clipboard-item)'s [presentation
 style](#presentation-style).

 4. [Write blobs and option to the
 clipboard](#write-blobs-and-option-to-the-clipboard) with `cleanItemList` and
 `option`.

 5. Resolve `p`.

4. Return `p`.

```
var data = [new ClipboardItem({ "text/plain": Promise.resolve(new Blob(["Text data"], { type: "text/plain" })) })];
navigator.clipboard.write(data).then(function() {
 console.log("Copied to clipboard successfully!");
}, function() {
 console.error("Unable to write to clipboard. :-(");
});
```

#### 7.3.4. writeText(`data`)

The
[`writeText(data)`](#dom-clipboard-writetext) method must run these steps:

1. Let `realm` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

2. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in `realm`.

3. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `r` be the result of running [check clipboard
 write
 permission](#check-clipboard-write-permission).

 (#issue-1b338371①) clipboard-write was removed in
 https://github.com/w3c/clipboard-apis/pull/164.

 2. If `r` is false, then:

 1. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [permission task
 source](https://w3c.github.io/permissions/#permissions-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`"NotAllowedError"`](https://webidl.spec.whatwg.org/#notallowederror) DOMException in `realm`.

 2. Abort these steps.

 3. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [clipboard task
 source](#clipboard-task-source), given `realm`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global), to perform the below steps:

 1. Let `itemList` be an empty
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob)\>.

 2. Let `textBlob` be a new
 [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob) created with:
 [`type`](https://w3c.github.io/FileAPI/#dfn-type) attribute set to
 \"`text/plain;charset=utf-8`\", and its underlying byte
 sequence set to the [UTF-8
 encoding](https://encoding.spec.whatwg.org/#utf-8-encode) of `data`.

 On Windows replace \`\\n\` characters with
 \`\\r\\n\` in `data` before creating
 `textBlob`.

 3. Add `textBlob` to `itemList`.

 4. Let `option` be set to \"unspecified\".

 5. [Write blobs and option to the
 clipboard](#write-blobs-and-option-to-the-clipboard) with `itemList` and
 `option`.

 6. Resolve `p`.

4. Return `p`.

```
await navigator.clipboard.writeText("Howdy, partner!");
```

## 8. Clipboard Actions

This section defines clipboard actions and the processing model for
event dispatch.

Each clipboard action has two flags called
[script-triggered](#script-triggered) and
[script-may-access-clipboard](#script-may-access-clipboard).

The [script-triggered] flag is set if the action runs because of a
script, for example a `document.execCommand()` call. Future scripting
APIs that interact with the clipboard should also use these actions, and
the [script-triggered](#script-triggered) flag must be set accordingly.

The [script-may-access-clipboard] flag is set as follows:

1. If action is *copy* or *cut* and the script thread is [allowed to
 modify the
 clipboard](#allowed-to-modify-the-clipboard), then

 1. Set the action's
 [script-may-access-clipboard](#script-may-access-clipboard) flag

2. If action is *paste* and the script thread is [allowed to read from
 clipboard](#allowed-to-read-from-clipboard), then

 1. Set the action's
 [script-may-access-clipboard](#script-may-access-clipboard) flag.

### 8.1. The copy action

The copy action consists of the following steps:

1. If the
 [script-triggered](#script-triggered) flag is set, then

 1. If the
 [script-may-access-clipboard](#script-may-access-clipboard) flag is unset, then

 1. Return false from the copy action, terminate this algorithm

2. [Fire a clipboard
 event](#fire-a-clipboard-event) named
 [`copy`](#eventdef-globaleventhandlers-copy)

3. If the event was not canceled, then

 1. Copy the selected contents, if any, to the clipboard.
 Implementations *should* create alternate text/html and
 text/plain clipboard formats when content in a web page is
 selected.

 2. [Fire a clipboard
 event](#fire-a-clipboard-event) named
 [`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange)

4. Else, if the event was canceled, then

 1. Call the [write content to the
 clipboard](#write-content-to-the-clipboard) algorithm, passing on the
 [`DataTransferItemList`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitemlist) list *items*, a *clear-was-called* flag and a
 *types-to-clear* list.

5. Return true from the copy action

### 8.2. The cut action

The cut action consists of the following steps:

1. If the
 [script-triggered](#script-triggered) flag is set, then

 1. If the
 [script-may-access-clipboard](#script-may-access-clipboard) flag is unset, then

 1. Return false from the cut action, terminate this algorithm

2. [Fire a clipboard
 event](#fire-a-clipboard-event) named
 [`cut`](#eventdef-globaleventhandlers-cut)

3. If the event was not canceled, then

 1. If there is a selection in an [editable
 context](#editable-context) where cutting is enabled, then

 1. Copy the selected contents, if any, to the clipboard.
 Implementations *should* create alternate text/html and
 text/plain clipboard formats when content in a web page is
 selected.

 2. Remove the contents of the selection from the document and
 collapse the selection.

 3. [Fire a clipboard
 event](#fire-a-clipboard-event) named
 [`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange)

 4. Queue tasks to fire any events that should fire due to the
 modification, see [§ 5.3 Integration with other scripts and
 events](#integration-with-other-scripts-and-events) for
 details.

 2. Else, if there is no selection or the context is not editable,
 then

 1. Return false

4. Else, if the event was canceled, then

 1. Call the [write content to the
 clipboard](#write-content-to-the-clipboard) algorithm, passing on the
 [`DataTransferItemList`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitemlist) list *items*, a *clear-was-called* flag and a
 *types-to-clear* list.

 2. [Fire a clipboard
 event](#fire-a-clipboard-event) named
 [`clipboardchange`](#eventdef-globaleventhandlers-clipboardchange)

5. Return true from the cut action

### 8.3. The paste action

For the paste action, the
[script-may-access-clipboard](#script-may-access-clipboard) flag depends on an implementation-specific permission
mechanism for determining what sites or apps may read from the
clipboard. When a paste action is triggered by a script, the
implementation must not make clipboard contents available without the
user's permission. If the permission has not already been granted, the
permission prompt must include the hostname of the document associated
with the script thread.

The paste action consists of the following steps:

1. If the
 [script-triggered](#script-triggered) flag is set, then

 1. If
 [script-may-access-clipboard](#script-may-access-clipboard) is unset, then

 1. Return false from the paste action, terminate this algorithm

2. [Fire a clipboard
 event](#fire-a-clipboard-event)
 named
 [`paste`](#eventdef-globaleventhandlers-paste)

3. If the event was not canceled, then

 1. If there is a selection or cursor in an [editable
 context](#editable-context) where pasting is enabled, then

 1. Insert the most suitable content found on the clipboard, if
 any, into the context.

 2. Queue tasks to fire any events that should fire due to the
 modification, see [§ 5.3 Integration with other scripts and
 events](#integration-with-other-scripts-and-events) for
 details.

 2. Else

 1. Return false

4. Else, if the event was canceled

 1. Return false

5. Return true from the action

## 9. Permissions API Integration

The
[\[permissions\]](#biblio-permissions "Permissions")
API provides a uniform way for websites to access [powerful
feature](https://w3c.github.io/permissions/#dfn-powerful-feature)s like the clipboard. It allows websites to request
permissions from users and query which permissions they have.

For the clipboard, one permission is defined:
[`"clipboard-write"`]

 Clipboard permissions currently only apply to the Async
Clipboard API. Future versions of this specification may be updated to
apply this permission to other Clipboard interactions.

These clipboard permissions are [powerful
feature](https://w3c.github.io/permissions/#dfn-powerful-feature)s permission-related algorithms and types are defined as
follows:

[permission descriptor type](https://w3c.github.io/permissions/#dfn-permission-descriptor-type)

: ```
 dictionary ClipboardPermissionDescriptor : PermissionDescriptor {
 boolean allowWithoutGesture = false;
 };
 ```

There are 4 clipboard permissions:

- { name: \"clipboard-write\", allowWithoutGesture: false }

- { name: \"clipboard-write\", allowWithoutGesture: true }

With the following relationships:

- `{ "clipboard-write" + true }` is stronger than
 `{ "clipboard-write" + false }`

While user agents MUST support the
[`ClipboardPermissionDescriptor`](#dictdef-clipboardpermissiondescriptor) as described in this specification, they, of course,
retain complete control over the default settings and how (or if) they
are exposed to the user.

A user agent that wants to have
separate user-settable write controls over the clipboard and always
require a user gesture would handle each descriptor as follows:

- `{ "clipboard-write" + false }` is exposed for user control

- `{ "clipboard-write" + true }` is always
 [`denied`](https://w3c.github.io/permissions/#dom-permissionstate-denied)

### 9.1. Clipboard read permission

#### [9.1.1. ][[check clipboard read permission]]
1. Let `hasGesture` be true if the [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) of
 [this](https://webidl.spec.whatwg.org/#this) has [transient
 activation](https://html.spec.whatwg.org/multipage/interaction.html#transient-activation), false otherwise.

2. If `hasGesture` then,

 1. Return true if the current script is running as a result of user
 interaction with a \"Paste\" element created by the user agent
 or operating system.

3. Return false.

### 9.2. Clipboard write permission

#### [9.2.1. ][[check clipboard write permission]]
1. Let `writeWithoutGesture` be the [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state) of the
 `{ name: "clipboard-write", allowWithoutGesture: true }` permission.

2. If `writeWithoutGesture` is
 [`granted`](https://w3c.github.io/permissions/#dom-permissionstate-granted), then return true.

3. Let `hasGesture` be true if the [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) of
 [this](https://webidl.spec.whatwg.org/#this) has [transient
 activation](https://html.spec.whatwg.org/multipage/interaction.html#transient-activation), false otherwise.

4. If `hasGesture` then,

 1. Let `systemCopy` be true if the current script is
 running as a result of user interaction with a \"cut\" or
 \"copy\" element created by the user agent or operating system.

 2. If `systemCopy` is true, then return true.

 3. Return the result of [request permission to
 use](https://w3c.github.io/permissions/#dfn-request-permission-to-use) the
 `{ name: "clipboard-write", allowWithoutGesture: false }`
 permission.

 User agents may choose to request a stronger
 permission that will implicitly update this permission.

5. Return the result of [request permission to
 use](https://w3c.github.io/permissions/#dfn-request-permission-to-use) the
 `{ name: "clipboard-write", allowWithoutGesture: true }` permission.

## 10. Security Considerations

Enabling authors to change what is copied by a user, or to make an
automated copy of something that was never selected and allowing
unrestricted calls to paste information can raise various security
concerns.

Some example scenarios include:

- A user selects a link and copies it, but a different link is copied to
 the clipboard. The effect of this can range from an unexpected result
 on pasting to an attempted \"phishing\" attack.

- (Self-XSS) Shell commands or executable script can be placed in the
 clipboard with the intent that the user will run the pasted content.

- An image that is specially crafted to exploit bugs in the core OS
 image handling code can be written to the clipboard.

### 10.1. Pasting HTML and multi-part data

*This section is non-normative.*

There are certain security risks associated with pasting formatted or
multi-part data.

- The user might paste hidden data without realising it is there. This
 may happen if, for example, the markup includes \<input
 type=\"hidden\"\> tags or HTML comments. Such hidden data might
 contain sensitive information.

- The user might paste malicious JavaScript into a trusted page.

- The implementation might grant scripts access to local files the user
 did not intend to expose.

To determine what policies to use, the factors we consider are:

- The origin of the data being pasted

- The origin of data sub-parts such as referenced images

- The origin of the running script

This is an overview of the scenarios and the possible security policies:

Origin of data

Origin of script

Rules

Originates from online source

Same as data

Do not sanitize HTML. Do not access any local files.

Different origin

Optionally sanitize content. Do not access any local files.

Originates from local application

Any

Do not sanitize HTML. Grant access to local files

Some implementations mitigate the risks associated with pasting rich
text by stripping potentially malicious content such as SCRIPT elements
and javascript: links by default when pasting rich text, but allow a
paste event handler to retrieve and process the original, un-sanitized
data.

### 10.2. General security policies

The implementation *must not* download referenced online resources, or
expose their contents in the
[`files`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-files) list or
[`DataTransferItemList`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitemlist).

If the data on the clipboard is not from a local application, the
implementation *must not* give access to any referenced local files. For
example, if the data contains \<img
src=\"file://localhost/example.jpg\"\> but the data's origin is an
online resource, the implementation must not add an entry for
example.jpg to the clipboardData.items list.

### 10.3. Transcoding images

To prevent malicious image data from being placed on the clipboard, the
image data may be transcoded to produce a safe version of the image.
This prevents websites from trying to exploit security vulnerabilities
in other applications.

Implementations should not transcode images being read from the
clipboard. Transcoding images can lose important metadata (such as the
physical resolution of an image). This is also consistent with other
methods in which images can be shared with a website (such as \`\<input
type=file\>\`).

### 10.4. Nuisance considerations

Scripts may use the
[`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) API to annoy and confuse users by altering the data on
the system clipboard from copy and cut events. This specification does
not attempt to prevent such nuisances, though implementations may add
additional restrictions.

Implementations must handle scripts that try to place excessive amounts
of data on the clipboard gracefully.

## 11. Privacy Considerations

Because these APIs provide access to the user's clipboard data, there
are serious privacy concerns due to the possibility that the clipboard
will contain personally-identifiable information (PII) like names,
addresses, or passwords.

In general, user agents *must* ensure that untrusted scripts do not get
uncontrolled access to a user's clipboard data through these APIs.

### 11.1. Privacy and the Clipboard Event API

The Clipboard Event API allows scripts running in the context of a
clipboard event handler to access a copy of the system clipboard and
potentially modify the data being written to the clipboard.

User agents should be aware of the following requirements with regards
to securing the data accessed by the Clipboard Event API:

- Objects implementing the
 [`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) interface to return clipboard data *must not* be
 available outside the ClipboardEvent event handler that the data is
 provided to.

- If a script stores a reference to an object implementing the
 [`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) interface to use from outside the ClipboardEvent
 event handler, all methods *must* be no-ops when called outside the
 expected context.

- Implementations *must not* let scripts create synthetic clipboard
 events to get access to real clipboard data (unless the user has
 configured it to do so).

Even though the Clipboard Event API is not covered by the Clipboard
permission, user agents may choose to provide a method for the user to
disable this API or to configure which sites are allowed to access it.

### 11.2. Privacy and the Asychronous Clipboard API

The Asynchronous Clipboard API is a powerful feature because it can
allow access to the clipboard data from any script (access is not
restricted to Clipboard Event handlers) and data can be accessed in the
absence of a user provided gesture.

To help prevent abuse, this API *must not* be available unless the
script is executing in the context of a document that [has
focus](https://html.spec.whatwg.org/multipage/interaction.html#has-focus-steps).

#### 11.2.1. Privacy and Clipboard Permission

The Clipboard Permission gates access to this API, but user agents get
to choose the permission defaults and which of these permission settings
can be set by the user. For example, a user agent may choose to only
allow access to the Asynchronous Clipboard API when a user gesture is
present and always deny script requests for access without a gesture.

User agents may opt to have this permission automatically expire
sometime after the user grants permission, for example, by having the
permission expire:

- After a set time from when the permission was first granted

- After a set time from the user's last visit to a site

- When the user navigates away from the page

### 11.3. Other Privacy Concerns

If the user agent allows clipboard data to be read using
`document.execCommand("paste")` then the user agent *must* ensure that
the user has explicitly allowed that access to take place.

## 12. Acknowledgements

*This section is non-normative*

The editors would like to acknowledge the contributions of the former
editors who helped shepherd this specification through various meetings
and mailing-list discussions to bring it to its current state.

- Hallvord R. M. Steen

The editors would also like to acknowledge their intellectual debt to
the documentation of Data Transfer functionalities from Microsoft
[\[MICROSOFT-CLIP-OP\]](#biblio-microsoft-clip-op "About DHTML Data Transfer. Microsoft Developer Network.")
and earlier drafts of the
[\[HTML5\]](#biblio-html5 "HTML5") specification. We
are also grateful for the draft \"safe copy and paste\" from Paul
Libbrecht (this draft is no longer available on the Web).

And finally, we would like to acknowledge the contributions made by the
following:

Adam Barth, Shawn Carnell, Daniel Cheng, Daniel Dardailler, Domenic
Denicola, Al Gilman, James Graham, James Greene, Ian Hickson, Darwin
Huang, Lachlan Hunt, Philip Jägenstedt, Anne van Kesteren, Marijn
Kruisselbrink, Aaron Leventhal, Jim Ley, Paul Libbrecht, \"Martijn\",
Glenn Maynard, Chris Mills, ms2ger, Ryosuke Niwa, Robert O'Callahan,
Dave Poehlman, \"ROBO Design\", Janina Sajka, Rich Schwerdtfeger, Jonas
Sicking, Maciej Stachowiak, Mihai Sucan, Dmitry Titov, Ojan Vafai,
Tarquin Wilton-Jones, Tom Wlodkowski, Bo Cupp, mbrodesser and Boris
Zbarsky.

## [Appendix A: Algorithms]
### [[write content to the clipboard]]
Input

: `items`, a
 [`DataTransferItemList`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitemlist) list of items to write

: `clear-was-called`, a boolean

: `types-to-clear`, a list

Output

: None

1. If the `items` list is not empty, then

 1. Clear the clipboard

 2. For each part in the list,

 1. If data type is *text/plain*, then

 1. Ensure encoding is correct per OS and locale conventions

 2. Normalize line endings according to platform conventions

 3. Place text on clipboard with the appropriate OS
 clipboard format description

 2. Else, if data is of a type listed in the [mandatory data
 types](#mandatory-data-types) list, then

 1. Place part on clipboard with the appropriate OS
 clipboard format description

 3. Else

 1. This is left to the implementation\...

 (#issue-77e1973e) It's not good to leave
 things up to the implementation. What should happen
 here?

 Due to limitations in the
 implementation of operating system clipboards, scripts
 should not assume that custom formats will be available
 to other applications on the system. For example, there
 is a limit to how many custom clipboard formats can be
 registered in Microsoft Windows. While it is possible to
 use any string for
 [setData()](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-setdata)'s type argument, sticking to
 the [mandatory data
 types](#mandatory-data-types) is strongly recommended.

2. Else, the `items` list is empty. Follow these steps to
 determine whether to clear the clipboard:

 1. If the list of items is empty and the
 `clear-was-called` flag is *true*, then

 1. If the `types-to-clear` list is empty, then

 1. Clear the clipboard

 2. Else

 1. Remove types in the `types-to-clear` list
 from the clipboard in an operating system and
 implementation-specific way

 (#issue-0a3703dc) The \"remove specific
 types from clipboard\" feature is at risk. It doesn't
 seem all that important, and it's unclear if it can be
 implemented easily across relevant platforms.

### [[write blobs and option to the clipboard]]
Input

: `items`, a
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob)\>

: `presentationStyle`, a [clipboard
 item](#clipboarditem-clipboard-item)'s [presentation
 style](#presentation-style)

Output

: None

1. Let `webCustomFormats` be a
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob)\>.

2. For each `item` in `items`:

 1. Let `formatString` be the result of running [os
 specific well-known
 format](#os-specific-well-known-format) given `item`'s
 [`type`](https://w3c.github.io/FileAPI/#dfn-type).

 2. If `formatString` is empty then follow the below
 steps:

 1. Let `webCustomFormatString` be the
 `item`'s
 [`type`](https://w3c.github.io/FileAPI/#dfn-type).

 2. Let `webCustomFormat` be an empty
 [`type`](https://w3c.github.io/FileAPI/#dfn-type).

 3. If `webCustomFormatString` [starts
 with](https://infra.spec.whatwg.org/#string-starts-with) \`\"web \"\` prefix, then remove the
 \`\"web \"\` prefix and store the remaining string in
 `webMimeTypeString`.

 4. Let `webMimeType` be the result of [parsing a
 MIME
 type](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) given `webMimeTypeString`.

 5. If `webMimeType` is failure, then abort all
 steps.

 6. Let `webCustomFormat`'s
 [`type`](https://w3c.github.io/FileAPI/#dfn-type)'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) equal to `webMimeType`.

 7. Set `item`'s
 [`type`](https://w3c.github.io/FileAPI/#dfn-type) to `webCustomFormat`.

 8. Append `webCustomFormat` to
 `webCustomFormats`.

 3. Let `payload` be the result of [UTF-8
 decoding](https://encoding.spec.whatwg.org/#utf-8-decode) `item`'s underlying byte sequence.

 4. Insert `payload` and `presentationStyle`
 into the [system
 clipboard](#system-clipboard) using `formatString` as the native
 clipboard format.

 (#issue-3887584b) some OSs contain multiple clipboard
 (e.g. Linux, \"primary\", \"secondary\", \"selection\"). Define to
 which of those data is written.

3. [Write web custom
 formats](#write-web-custom-formats) given `webCustomFormats`.

### [[os specific well-known format]]
Input

: `mimeType`, a
 [`type`](https://w3c.github.io/FileAPI/#dfn-type)

Output

: `wellKnownFormat`, a platform specific string type. On
 Mac it's NSPasteboardType, on Windows it's LPCWSTR and Linux it's a
 const char\*.

For Windows see
https://docs.microsoft.com/en-us/windows/win32/dataxchg/standard-clipboard-formats
and
https://docs.microsoft.com/en-us/windows/win32/dataxchg/about-atom-tables?redirectedfrom=MSDN
For Mac see
https://developer.apple.com/documentation/appkit/nspasteboardtype

1. Let `wellKnownFormat` be an empty string.

2. If `mimeType`'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) is \"text/plain\", then

 On Windows, follow the convention described below:

 1. Assign CF_UNICODETEXT to `wellKnownFormat`.

 On MacOS, follow the convention described below:

 1. Assign NSPasteboardTypeString to `wellKnownFormat`.

 On Linux, ChromeOS, and Android, follow the convention described
 below:

 1. Assign \"text/plain\" to `wellKnownFormat`.

3. Else, if `mimeType`'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) is \"text/html\", then

 On Windows, follow the convention described below:

 1. Assign CF_HTML to `wellKnownFormat`.

 On MacOS, follow the convention described below:

 1. Assign NSPasteboardTypeHTML to `wellKnownFormat`.

 On Linux, ChromeOS, and Android, follow the convention described
 below:

 1. Assign \"text/html\" to `wellKnownFormat`.

4. Else, if `mimeType`'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) is \"image/png\", then

 On Windows, follow the convention described below:

 1. Assign \"PNG\" to `wellKnownFormat`.

 On MacOS, follow the convention described below:

 1. Assign NSPasteboardTypePNG to `wellKnownFormat`.

 On Linux, ChromeOS, and Android, follow the convention described
 below:

 1. Assign \"image/png\" to `wellKnownFormat`.

5. Else, if `mimeType`'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) is \"image/svg+xml\", then

 On Windows, follow the convention described below:

 1. Assign CFSTR_MIME_SVG_XML to `wellKnownFormat`.

 On MacOS, follow the convention described below:

 1. Assign UTTypeSVG to `wellKnownFormat`.

 On Linux, ChromeOS, and Android, follow the convention described
 below:

 1. Assign \"image/svg+xml\" to `wellKnownFormat`.

6. Return `wellKnownFormat`.

### [[well-known mime type from os specific format]]
Input

: `osFormatName`, a platform specific string type. On Mac
 it's NSPasteboardType, on Windows it's LPCWSTR and Linux it's a
 const char\*.

Output

: `mimeType`, a [MIME
 type](https://mimesniff.spec.whatwg.org/#mime-type)

For Windows see
https://docs.microsoft.com/en-us/windows/win32/dataxchg/standard-clipboard-formats
and
https://docs.microsoft.com/en-us/windows/win32/dataxchg/about-atom-tables?redirectedfrom=MSDN
For Mac see
https://developer.apple.com/documentation/appkit/nspasteboardtype

On Windows, follow the convention described below:

1. If `osFormatName` \"UnicodeText\", then set
 `mimeTypeString` to \"text/plain\".

2. Else, if `osFormatName` \"HTML Format\", then set
 `mimeTypeString` to \"text/html\".

3. Else, if `osFormatName` \"PNG\", then set
 `mimeTypeString` to \"image/png\".

4. Else, if `osFormatName` CFSTR_MIME_SVG_XML, then set
 `mimeTypeString` to \"image/svg+xml\".

On MacOS, follow the convention described below:

1. If `osFormatName` is NSPasteboardTypeString, then set
 `mimeTypeString` to \"text/plain\".

2. Else, if `osFormatName` is NSPasteboardTypeHTML, then set
 `mimeTypeString` to \"text/html\".

3. Else, if `osFormatName` NSPasteboardTypePNG, then set
 `mimeTypeString` to \"image/png\".

4. Else, if `osFormatName` UTTypeSVG, then set
 `mimeTypeString` to \"image/svg+xml\".

On Linux, ChromeOS, and Android, follow the convention described below:

1. If `osFormatName` is \"text/plain\", then set
 `mimeTypeString` to \"text/plain\".

2. Else, if `osFormatName` \"text/html\", then set
 `mimeTypeString` to \"text/html\".

3. Else, if `osFormatName` \"image/png\", then set
 `mimeTypeString` to \"image/png\".

4. Else, if `osFormatName` \"image/svg+xml\", then set
 `mimeTypeString` to \"image/svg+xml\".

<!-- -->

1. Let `mimeType` be the result of [parsing a MIME
 type](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) given `mimeTypeString`.

2. Return `mimeType`.

### [[read web custom format]]
Input

: `item`, a [clipboard
 item](#clipboard-item)

1. Let `webCustomFormatMap` be the [os specific custom map
 name](#os-specific-custom-map-name).

2. Read `webCustomFormatMap` from the [system
 clipboard](#system-clipboard).

 (#issue-97db4b5a) specify in more detail the process
 of reading a `webCustomFormatMap`.

3. If `webCustomFormatMap` is empty, then return
 `item`.

4. Let `webCustomFormatMapString` be the JSON string
 deserialized from `webCustomFormatMap`.

 Need a JSON reader to deserialize the content from
 the `webCustomFormatMap`.

5. For each (`key`, `value`) in
 `webCustomFormatMapString`:

 1. Let `mimeType` be the result of [parsing a MIME
 type](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) given `key`.

 2. If `mimeType` is failure, then continue the loop.

 3. Let `representation` be a new
 [representation](#representation).

 4. Set `representation`'s [MIME
 type](#representation-mime-type) to `mimeType`.

 5. Set `representation`'s
 [isCustom](#representation-iscustom) flag to `true`.

 6. Set `representation`'s
 [data](#representation-data) to [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 The OS clipboard data for this web custom
 format will not be fetched until the author calls
 [`getType()`](#dom-clipboarditem-gettype) on the resulting
 [`ClipboardItem`](#clipboarditem) object.

 7. Append `representation` to `item`'s [list
 of
 representations](#list-of-representations).

### [[write web custom formats]]
Input

: `items`, a
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob)\>

1. Let `idx` be a number initialized to 0.

2. Let `webCustomFormatMap` be the [os specific custom map
 name](#os-specific-custom-map-name).

3. Let `webCustomFormatMapString` be an empty JSON string.

4. For each `item` in `items`:

 1. Let `webCustomFormat` be the [os specific custom
 name](#os-specific-custom-name).

 2. Let `webCustomFormatIdx` be the result of appending
 `idx` to `webCustomFormat`.

 3. Insert `item`'s
 [`type`](https://w3c.github.io/FileAPI/#dfn-type) as key and `webCustomFormatIdx` as
 value into the `webCustomFormatMapString` using a
 JSON serializer.

 Need a JSON writer to serialize the content
 into the `webCustomFormatMapString`.

 4. Insert the `item` into the [system
 clipboard](#system-clipboard) using `webCustomFormatIdx` as the
 format.

 5. Increment `idx`.

 6. If `idx` is greater than 100, then break from this
 loop.

5. Insert the `webCustomFormatMapString` into the [system
 clipboard](#system-clipboard) using `webCustomFormatMap` as the
 format.

### [[os specific custom map name]]
Output

: `webCustomFormatMap`, a string

On Windows, follow the convention described below:

1. Assign \"Web Custom Format Map\" to `webCustomFormatMap`.

2. Return `webCustomFormatMap`.

On MacOS, follow the convention described below:

1. Assign \"org.w3.web-custom-format.map\" to
 `webCustomFormatMap`.

2. Return `webCustomFormatMap`.

On Linux, ChromeOS, and Android, follow the convention described below:

1. Assign \"application/web;type=\\\"custom/formatmap\\\"\" to
 `webCustomFormatMap`.

2. Return `webCustomFormatMap`.

### [[os specific custom name]]
Output

: `webCustomFormat`, a string

On Windows, follow the convention described below:

1. Assign \"Web Custom Format\" to `webCustomFormat`.

2. Return `webCustomFormat`.

On MacOS, follow the convention described below:

1. Assign \"org.w3.web-custom-format.type-\" to
 `webCustomFormat`.

2. Return `webCustomFormat`.

On Linux, ChromeOS, and Android, follow the convention described below:

1. Assign \"application/web;type=\"custom/format\" to
 `webCustomFormat`.

2. Return `webCustomFormat`.

### [[fire a clipboard event]]
Input

: `e`, the
 [`ClipboardEvent`](#clipboardevent) to fire

Output

: None

1. Let `clear-was-called` be *false*

2. Let `types-to-clear` be an empty list

3. Let `clipboard-event-data` be a new
 [`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) object with an empty
 [`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items) list.

4. Let `clipboard-entry` be the sequence number of the
 current clipboard content, or null if the OS clipboard does not
 support sequence numbers

5. Let `trusted` be *true* if the event is generated by the
 user agent, *false* otherwise

6. Let `target` be set as follows:

 1. If the context is editable, then

 1. Set `target` to be the element that contains the
 start of the visible selection or cursor in document order,
 or [the body
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2) if there is no visible selection or cursor.

 2. Else, if the context is not editable, then

 1. Set `target` to the focused node, or [the body
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2) if no node has focus.

7. Process the event as follows:

 1. If `e` is \"paste\", then

 1. Set the `clipboard-event-data`'s internal [drag
 data store
 mode](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-store-mode) flag to
 [read-only](https://html.spec.whatwg.org/multipage/interaction.html#concept-dnd-ro).

 2. If `trusted` is *true*, or the implementation is
 configured to give script-generated events read access to
 the OS clipboard

 1. For each `clipboard-part` on the OS
 clipboard, carry out these steps:

 1. If `clipboard-part` contains plain text,
 then

 1. Ensure the text is in the encoding the scripting
 engine uses internally

 2. Let `new-data` be a new
 [`DataTransferItem`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitem) with [drag data item
 kind](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-kind) set to *string* and [drag data
 item type
 string](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-type-string) set to *text/plain*.

 3. Set `new-data`'s data to the plain
 text.

 4. Add `new-data` to
 `clipboard-event-data`'s
 [`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items)

 2. If `clipboard-part` represents file
 references, then for each file reference:

 1. Determine MIME type of referenced file

 2. Let `new-data` be a new
 [`DataTransferItem`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitem) with [drag data item
 kind](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-kind) set to *file* and [drag data
 item type
 string](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-type-string) set to the corresponding MIME
 type, or `application/octet-stream` if the
 file's type is unknown.

 3. Set `new-data`'s data to the file
 reference data.

 4. Add `new-data` to
 `clipboard-event-data`'s
 [`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items)

 3. If `clipboard-part` contains HTML- or
 XHTML-formatted text, according to the operating
 system's convention for describing such clipboard
 formats, then

 1. If the implementation supports pasting HTML,
 then the implementation *must* process the
 markup by calling [process an html paste
 event](#process-an-html-paste-event) with
 `clipboard-part` and
 `clipboard-event-data`.

 4. If `clipboard-part` contains data in
 another supported binary or text-based format (see
 [mandatory data
 types](#mandatory-data-types)), then

 1. Determine the MIME type of the data

 2. Let `new-data` be a new
 [`DataTransferItem`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitem) with [drag data item
 kind](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-kind) set to *file*, [drag data item
 type
 string](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-type-string) set to the corresponding MIME
 type

 3. Set `new-data`'s data to be the
 binary or text-based data.

 4. Add `new-data` to
 `clipboard-event-data`'s
 [`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items)

 3. Update `clipboard-event-data`'s
 [`files`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-files) property to match entries in
 `clipboard-event-data`'s
 [`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items).

 4. Update `clipboard-event-data`'s
 [`types`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-types) property to match entries in
 `clipboard-event-data`'s
 [`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items).

 2. If `e` is \"copy\" or \"cut\", then

 1. Set the associated
 [`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) object's internal [drag data store
 mode](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-store-mode) flag to
 [read/write](https://html.spec.whatwg.org/multipage/interaction.html#concept-dnd-rw)

8. Set `e`'s
 [`clipboardData`](#dom-clipboardevent-clipboarddata) to `clipboard-event-data`.

9. Set `e`'s
 [`isTrusted`](https://dom.spec.whatwg.org/#dom-event-istrusted) to `trusted`.

10. Set `e`'s
 [`composed`](https://dom.spec.whatwg.org/#dom-event-composed) to true.

11. Dispatch the event `e` which bubbles and is cancelable,
 and which uses the
 [`ClipboardEvent`](#clipboardevent) interface, at `target`.

 Implementation requirements for access to data during event dispatch
 are defined in
 [\[HTML\]](#biblio-html "HTML Standard"). Some
 additional clipboard event-specific processing rules are given
 below:

 (#issue-7d2ab940) Why here? Why not in the HTML spec?

 1. If a script calls
 [clearData()](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-cleardata) or
 [`clear()`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransferitemlist-clear) and the
 [`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) object's internal [drag data store
 mode](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-store-mode) flag is
 [read/write](https://html.spec.whatwg.org/multipage/interaction.html#concept-dnd-rw), then

 1. Set the `clear-was-called` flag to true. If an
 argument is given, add the argument to the
 `types-to-clear` list.

 2. If a script calls
 [setData()](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-setdata) or modifies items and the
 `clear-was-called` flag is true, then

 1. If the `types-to-clear` list is empty, then

 1. Set the `clear-was-called` flag to false,
 then

 2. Else, if
 [setData()](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-setdata)'s `type` argument or the new item's
 [drag data item type
 string](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-type-string) is found in the `types-to-clear`
 list, then

 1. Remove it from the list. If the list is now empty, set
 the `clear-was-called` flag to false.

 3. If a script calls
 [getData()](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-getdata) or accesses items in the
 [`DataTransferItemList`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitemlist) and `clipboard-entry` is set, then

 1. Check that the clipboard data's sequence number matches
 `clipboard-entry`. If the clipboard no longer
 contains the same entry, set the
 [`DataTransferItemList`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitemlist) object's internal [drag data store
 mode](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-store-mode) to
 [protected](https://html.spec.whatwg.org/multipage/interaction.html#concept-dnd-p).

 **Warning! A malicious script listening to a paste event may set up
 a never-ending loop in order to read what the user places on the
 clipboard in the future. On platforms where a clipboard sequence
 number is not available, other limitations should be implemented.**

### [[process an HTML paste event]]
Input

: `clipboard-part`, the clipboard part to process

: `clipboard-event-data`, the
 [`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) object for this event

Output

: None

1. Let `new-data` be a new
 [`DataTransferItem`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitem) with [drag data item
 kind](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-kind) set to *Plain Unicode string*, [drag data item type
 string](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-type-string) set to *text/html* or *application/xhtml+xml*
 accordingly.

2. Extract the markup from `clipboard-part` and use the
 relevant parser to construct a DOM tree.

3. If the markup's source URL is known, then resolve all relative URLs
 in HREF and SRC attributes using the source URL as base URL, and set
 the respective attributes to the resolved absolute URL.

4. If the markup's origin is from a local application, then check
 whether there are references to local files and/or other parts of
 the OS clipboard's contents. If such references are found,
 references to sub-parts *must* be replaced by content-id references
 using the cid: URL scheme
 [\[RFC2392\]](#biblio-rfc2392 "Content-ID and Message-ID Uniform Resource Locators").
 To do so, process each attribute referencing a local file or
 clipboard part according to the following steps:

 (#issue-096a5049) Are these steps necessary? Do we
 know about native (platform) clipboard implementations that support
 multiple parts with internal references?

 (#issue-6be1122f) This feature is at risk because it's
 unclear whether it is required, and because it's hard to test in a
 cross-platform way.

 1. If `clipboard-event-data`'s
 [`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items) already contains an entry for the referenced
 file or clipboard part, then

 1. Set `itemNumber` to the index of the existing
 entry.

 2. Else,

 1. Let `new-file-data` be a new
 [`DataTransferItem`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitem) with [drag data item
 kind](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-kind) set to \"file\", and [drag data item type
 string](https://html.spec.whatwg.org/multipage/interaction.html#drag-data-item-type-string) set to the MIME type of the file or
 clipboard part if known, or `application/octet-stream` if
 the file's type is unknown.

 2. Let `file-info` be a new
 [`File`](https://w3c.github.io/FileAPI/#dfn-file) object with
 [`name`](https://w3c.github.io/FileAPI/#dfn-name) set to the name part of the HTML attribute
 contents, and
 [`lastModified`](https://w3c.github.io/FileAPI/#dfn-lastModified) set to the timestamp of the referenced file
 or 0 if the entry references a clipboard part.

 3. Set `new-file-data`'s internal
 [`File`](https://w3c.github.io/FileAPI/#dfn-file) object to `file-info`.

 4. Add `new-file-data` to
 `clipboard-event-data`'s
 [`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items) and let `itemNumber` be the
 index of this entry in the
 [`DataTransferItemList`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitemlist).

 3. Update the DOM attribute that referenced the local file or
 clipboard part to contain the string \'cid:\' followed by
 `itemNumber`.

5. Serialize the processed DOM and update `new-data` with
 the resulting HTML code.

6. Add `new-data` to `clipboard-event-data`'s
 [`items`](https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items).
