
The Gamepad specification defines a low-level interface that represents
gamepad devices.

This is a work in progress.

## Introduction

Some \[=user agents=\] have connected gamepad devices. These devices are
desirable and suited to input for gaming applications, and for \"10
foot\" user interfaces (presentations, media viewers).

Currently, the only way for a gamepad to be used as input would be to
emulate mouse or keyboard events, however this would lose information
and require additional software outside of the \[=user agent=\] to
accomplish emulation.

Meanwhile, native applications are capable of accessing these devices
via system APIs.

The Gamepad API provides a solution to this problem by specifying
interfaces that allow web applications to directly act on gamepad data.

## Scope

Interfacing with external devices designed to control games has the
potential to become large and intractable if approached in full
generality. In this specification we explicitly choose to narrow scope
to provide a useful subset of functionality that can be widely
implemented and broadly useful.

Specifically, we choose to only support the functionality required to
support gamepads. Support for gamepads requires two input types: buttons
and axes. Both buttons and axes are reported as analog values, buttons
ranging from \[0 .. 1\], and axes ranging from \[-1 .. 1\].

While the primary goal is support for gamepad devices, supporting these
two types of analog inputs allows support for other similar devices
common to current gaming systems including joysticks, driving wheels,
pedals, and accelerometers. As such, the name \"gamepad\" is exemplary
rather than trying to be a generic name for the entire set of devices
addressed by this specification.

We specifically exclude support for more complex devices that may also
be used in some gaming contexts, including those that that do motion
sensing, depth sensing, video analysis, gesture recognition, and so on.

## Model

A [gamepad] is a collection of input controls and output controls.
An [input control] has a collection of [input values] that
may update over time. Input controls include the buttons, triggers,
joysticks, thumbsticks, and touch surfaces of the \[=gamepad=\]. An
[output control] is a feature that changes the behavior of the
\[=gamepad=\] to provide feedback to the user interacting with the
\[=gamepad=\]. Output controls include the haptic actuators of the
\[=gamepad=\]. A \[=gamepad=\] is [available] if the \[=user
agent=\] can read the current state of its \[=input controls=\]. A
\[=gamepad=\] that is not \[=available=\] is [unavailable]. The
\[=input controls=\] and \[=output controls=\] for a \[=gamepad=\]
cannot change while the \[=gamepad=\] is \[=available=\].

The \[=user agent=\] is responsible for:

- Enumerating \[=available=\] \[=gamepads=\],
- Detecting when \[=gamepads=\] become \[=available=\] or
 \[=unavailable=\],
- Detecting when \[=input controls=\] have updated \[=input values=\],
- Reading the current state of \[=input values=\], and
- Commanding the \[=gamepad=\] to use its \[=output controls=\].

A \[=gamepad=\] has a [gamepad identifier string], a
human-readable string that identifies the brand or style of
\[=gamepad=\]. The content is decided by the \[=user agent=\].

### Input control layout

A \[=gamepad=\] may have an [input control layout] that describes
the position, orientation and type of each \[=input control=\] on the
\[=gamepad=\]. The \[=user agent=\] is responsible for recognizing when
a \[=gamepad=\] [corresponds with a standard layout], meaning the \[=gamepad=\] has an \[=input
control layout=\] that enables it to be used interchangeably with other
\[=gamepads=\] that correspond with the same standard layout. The
\[=user agent=\] SHOULD consider a layout to correspond with a standard
layout if its \[=input controls=\] have approximately the same relative
positions and orientations as \[=input controls=\] described in the
standard layout.

The \[=user agent=\] typically cannot directly inspect the \[=input
control layout=\] for a \[=gamepad=\] and MAY use heuristics to decide
the layout. The \[=user agent=\] SHOULD consider the device identifiers
when deciding whether a \[=gamepad=\] \[=corresponds with a standard
layout=\]. If the system assigns a label to each \[=input control=\] and
the labels imply a particular layout then the \[=user agent=\] SHOULD
consider the \[=gamepad=\] to have that layout. When there is a standard
model and an accessible model with the same \[=input controls=\], the
\[=user agent=\] SHOULD consider the accessible model to have the same
\[=input control layout=\] as the standard model.

An accessible gamepad model is a gamepad where the manufacturer\'s
intent is to provide a swap-in replacement for a gamepad with a standard
layout. For example, Xbox Adaptive Controller and PlayStation Access
Controller are accessible gamepad models. Xbox Wireless Controller and
DualSense are the corresponding standard models.

### Input values

Each input control has one or more associated \[=input values=\], which
are numerical values that represent the current state of the control.
\[=Input values=\] can update at any time. The \[=user agent=\] is
responsible for detecting when \[=input values=\] have updated and
SHOULD try to minimize the delay between the update and when the updated
values are read.

Reading an \[=input value=\] returns its [logical value], an
unscaled numerical representation of the current state. An \[=input
value=\] also has a [logical minimum] and [logical maximum]
which define the minimum and maximum in-bounds \[=logical values=\].

An \[=input value=\] may have an associated [HID usage
identifier], a 32-bit value that identifies the type of data
represented by the input value. A HID usage does not precisely describe
the \[=input control layout=\], but by convention many \[=gamepads=\]
with similar layouts use similar usages. The \[=user agent=\] SHOULD
rely on conventions around \[=HID usage identifiers=\] when deciding the
\[=input control layout=\].

### Axes

A \[=gamepad=\] may have \[=axis=\] inputs. An [axis] is an
\[=input value=\] that represents the current displacement of the
control from a reference position.

A \[=gamepad=\] has an [axis list] which is a \[=list=\]
containing all the \[=axis=\] inputs for the \[=gamepad=\] in some order
determined by the \[=user agent=\].

An \[=input control=\] may be designed to automatically return an
\[=axis=\] to a center position when the user stops interacting with the
\[=input control=\]. If so, the \[=axis=\] has a [preferred axis
state]. An \[=axis=\] with a \[=preferred axis state=\] may also
have an additional \[=input value=\], the [center position value],
which is the \[=logical value=\] when the \[=axis=\] is centered.

### Buttons

A \[=gamepad=\] may have \[=button=\] inputs. A [button] is an
\[=input control=\] that can be pressed to activate. A \[=gamepad=\] has
a [button list] which is a \[=list=\] containing all the
\[=button=\] inputs for the \[=gamepad=\] in some order determined by
the \[=user agent=\].

An \[=input control=\] may be designed to automatically return a
\[=button=\] to an unpressed state when the user stops interacting with
the \[=input control=\]. If so, the \[=button=\] has a [preferred button
state].

A \[=button=\] may have a digital switch to indicate when the
\[=button=\] is activated. If so, the \[=button=\] has an additional
\[=input value=\], the [digital button value], that is \`true\`
when the \[=button=\] is activated and \`false\` otherwise.

A \[=button=\] may have an analog sensor enabling the \[=button=\] to
report the degree to which the \[=button=\] is activated. If so, the
\[=button=\] has:

- An [analog button value], a \[=logical value=\] that represents
 the degree of activation,
- A \[=logical minimum=\], the \[=logical value=\] representing no
 activation, and
- A \[=logical maximum=\], the \[=logical value=\] representing full
 activation.

A \[=button=\] may be capable of detecting touch. If so, the
\[=button=\] has an additional \[=input value=\], the [button touch
value], that is \`true\` when the \[=button=\] is touched and
\`false\` otherwise.

### Touch surfaces

A \[=gamepad=\] may have \[=touch surfaces=\]. A [touch surface]
is an input control that provides 2D position data representing points
of contact. A \[=gamepad=\] has a [touch surface list] which is a
\[=list=\] containing the \[=touch surfaces=\] for the \[=gamepad=\].
The list is ordered such that \[=touch surfaces=\] closer to the left
side of the \[=gamepad=\] appear closer to the start of the list.

A \[=touch surface=\] has an [active touch point list] \[=input
value=\], a \[=list=\] of zero or more \[=touch points=\] representing
the points of contact currently detected by the sensor. A [touch
point] represents a single point of contact at a single point in
time. A \[=touch point=\] has a [touch x coordinate] and a [touch
y coordinate] representing the position in the \[=touch
surface=\]\'s coordinate system. If a \[=touch surface=\] is on the top,
bottom, front, or back side of the \[=gamepad=\] then the \[=touch x
coordinate=\] is measured along the left-right axis, otherwise it is
measured along the top-bottom axis. The \[=touch y coordinate=\] is
measured along the perpendicular axis.

If a \[=touch surface=\] is on the left or right side of a \[=gamepad=\]
then neither of its dimensions will align with the horizontal axis.

A \[=touch surface=\] may have surface dimension \[=input values=\]. The
[surface width] and [surface height] \[=input values=\] are
the dimensions of the \[=touch surface=\] in the same units as the
\[=touch x coordinate=\] and \[=touch y coordinate=\]. A \[=touch
surface=\] has both dimension values or neither value.

A \[=touch point=\] may be a new contact point or a continuation of an
earlier contact. A \[=touch point=\] is [part of an existing active
touch point] if the \[=user agent=\] identifies that it is a
continuation of a \[=touch point=\] represented by an earlier
{{GamepadTouch}}. The [active touch point id] for a \[=touch
point=\] that is \[=part of an existing active touch point=\] is the
{{GamepadTouch/touchId}} of the earlier {{GamepadTouch}}.

### Output controls

A \[=gamepad=\] may have \[=haptic actuators=\]. A [haptic
actuator] is an output control capable of moving the \[=gamepad=\]
in a way that can be felt by the user. A \[=haptic actuator=\] can be
used to generate a [haptic effect] that provides feedback to the
user. Vibrations from multiple actuators are combined to generate more
complex effects. The \[=user agent=\] is responsible for commanding
\[=haptic actuators=\] to play and stop \[=haptic effects=\] on
\[=available=\] \[=gamepads=\].

A \[=gamepad=\] may have a [vibration actuator] which is a
\[=haptic actuator=\] capable of playing a \[=haptic effect=\] to
vibrate the whole \[=gamepad=\].

A \[=haptic actuator=\] has a \[=list=\] of [supported effect
types] containing one or more {{GamepadHapticEffectType}} values,
which cannot change while the \[=gamepad=\] is \[=available=\].

## [Gamepad] Interface

This interface defines an individual gamepad device.

```

 [Exposed=Window]
 interface Gamepad {
 readonly attribute DOMString id;
 readonly attribute long index;
 readonly attribute boolean connected;
 readonly attribute DOMHighResTimeStamp timestamp;
 readonly attribute GamepadMappingType mapping;
 readonly attribute FrozenArray<double> axes;
 readonly attribute FrozenArray<GamepadButton> buttons;
 readonly attribute FrozenArray<GamepadTouch> touches;
 [SameObject] readonly attribute GamepadHapticActuator vibrationActuator;
 };

```

The algorithms used to communicate with the system typically complete
asynchronously, queuing work on the [gamepad task source].

Instances of {{Gamepad}} are created with the internal slots described
in the following table:

 Internal slot Initial value Description (non-normative)
 ------------------------------------------------------- ---------------------------- ------------------------------------------------------------------------------------------------------------------------------------
 [\[\[\\connected\]\]] \`false\` A flag indicating that the device is connected to the system
 [\[\[\\timestamp\]\]] undefined The last time data for this {{Gamepad}} was updated
 [\[\[\\axes\]\]] An empty \[=sequence=\] A \[=sequence=\] of {{double}} values representing the current state of axes exposed by this device
 [\[\[\\buttons\]\]] An empty \[=sequence=\] A \[=sequence=\] of {{GamepadButton}} objects representing the current state of buttons exposed by this device
 [\[\[\\exposed\]\]] \`false\` A flag indicating that the {{Gamepad}} object has been exposed to script
 [\[\[\\axisMapping\]\]] An empty \[=ordered map=\] Mapping from unmapped axis index to an index in the {{Gamepad/axes}} array
 [\[\[\\axisMinimums\]\]] An empty \[=list=\] A \[=list=\] containing the minimum logical value for each axis
 [\[\[\\axisMaximums\]\]] An empty \[=list=\] A \[=list=\] containing the maximum logical value for each axis
 [\[\[\\buttonMapping\]\]] An empty \[=ordered map=\] Mapping from unmapped button index to an index in the {{Gamepad/buttons}} array
 [\[\[\\buttonMinimums\]\]] An empty \[=list=\] A \[=list=\] containing the minimum logical value for each button.
 [\[\[\\buttonMaximums\]\]] An empty \[=list=\] A \[=list=\] containing the maximum logical value for each button
 [\[\[\\touches\]\]] An empty \[=list=\] Holds the list of user-generated touches, if any. If the gamepad does not support touch surfaces, then the list will remain empty.
 [\[\[\\nextTouchId\]\]] 0 {{GamepadTouch/touchId}} value to use for the next incoming touch.
 [\[\[\\vibrationActuator\]\]] undefined A {{GamepadHapticActuator}} object capable of generating a haptic effect that vibrates the entire gamepad

[id] attribute

: An identification string for the gamepad. This string identifies the
 brand or style of connected gamepad device.

 The exact format of the {{Gamepad/id}} string is left unspecified.
 It is RECOMMENDED that the \[=user agent=\] select a string that
 identifies the product without uniquely identifying the device. For
 example, a USB gamepad may be identified by its \`idVendor\` and
 \`idProduct\` values. Unique identifiers like serial numbers or
 Bluetooth device addresses MUST NOT be included in the
 {{Gamepad/id}} string.

[index] attribute
: The index of the gamepad in the {{Navigator}}. When multiple
 gamepads are connected to a \[=user agent=\], indices MUST be
 assigned on a first-come, first-serve basis, starting at zero. If a
 gamepad is disconnected, previously assigned indices MUST NOT be
 reassigned to gamepads that continue to be connected. However, if a
 gamepad is disconnected, and subsequently the same or a different
 gamepad is then connected, the lowest previously used index MUST be
 reused.

[connected] attribute

: Indicates whether the physical device represented by this object is
 still connected to the system. When a gamepad becomes unavailable,
 whether by being physically disconnected, powered off or otherwise
 unusable, the {{Gamepad/connected}} attribute MUST be set to
 \`false\`.

 The {{Gamepad/connected}} getter steps are:

 1. Return \[=this=\].{{Gamepad/\[\[connected\]\]}}.

[timestamp] attribute

: The {{Gamepad/timestamp}} allows the author to determine the last
 time the {{Gamepad/axes}} or {{Gamepad/buttons}} attribute for this
 gamepad was updated. The value MUST be set to the \[=current high
 resolution time=\] each time the system \[=receives new button or
 axis input values=\] from the device. If no data has been received
 from the hardware, {{Gamepad/timestamp}} MUST be the \[=current high
 resolution time=\] at the time when the {{Gamepad}} was first made
 available to script.

 \[=User agents=\] SHOULD set a minimum resolution of the
 {{Gamepad/timestamp}} attribute to 5 microseconds, following
 \[\[HR-TIME\]\]\'s clock resolution recommendation.

 The {{Gamepad/timestamp}} getter steps are:

 1. Return \[=this=\].{{Gamepad/\[\[timestamp\]\]}}.

[mapping] attribute

: The mapping in use for this device. If the \[=user agent=\] has
 knowledge of the layout of the device, then it SHOULD indicate that
 a mapping is in use by setting {{Gamepad/mapping}} to the
 corresponding {{GamepadMappingType}} value.

 To [select a mapping] for a gamepad
 device, run the following steps:

 1. If the button and axis layout of the gamepad device corresponds
 with the \[=Standard Gamepad=\] layout, then return
 {{GamepadMappingType/\"standard\"}}.
 2. Return {{GamepadMappingType/\"\"}}.

[axes] attribute

: Array of values for all axes of the gamepad. All axis values MUST be
 linearly normalized to the range \[-1 .. 1\]. If the controller is
 perpendicular to the ground with the directional stick pointing up,
 -1 SHOULD correspond to \"forward\" or \"left\", and 1 SHOULD
 correspond to \"backward\" or \"right\". Axes that are drawn from a
 2D input device SHOULD appear next to each other in the axes array,
 X then Y. It is RECOMMENDED that axes appear in decreasing order of
 importance, such that element 0 and 1 typically represent the X and
 Y axis of a directional stick. The same object MUST be returned
 until the \[=user agent=\] needs to return different values (or
 values in a different order).

 The {{Gamepad/axes}} getter steps are:

 1. Return \[=this=\].{{Gamepad/\[\[axes\]\]}}.

[buttons] attribute

: Array of button states for all buttons of the gamepad. It is
 RECOMMENDED that buttons appear in decreasing importance such that
 the primary button, secondary button, tertiary button, and so on
 appear as elements 0, 1, 2, \... in the buttons array. The same
 object MUST be returned until the \[=user agent=\] needs to return
 different values (or values in a different order).

 The {{Gamepad/buttons}} getter steps are:

 1. Return \[=this=\].{{Gamepad/\[\[buttons\]\]}}.

[touches] attribute

: A \[=list=\] of {{GamepadTouch}} objects generated from all touch
 surfaces.

 The {{Gamepad/touches}} getter steps are:

 1. Return \[=this=\].{{Gamepad/\[\[touches\]\]}}.

[vibrationActuator] attribute

: A {{GamepadHapticActuator}} object that represents the device\'s
 primary vibration actuator.

 The {{Gamepad/vibrationActuator}} getter steps are:

 1. Return \[=this=\].{{Gamepad/\[\[vibrationActuator\]\]}}.

### Receiving inputs

When the system [receives new button or axis input values], run
the following steps:

1. Let \|gamepad:Gamepad\| be the {{Gamepad}} object representing the
 device that received new button or axis input values.
2. \[=Queue a global task=\] on the \[=gamepad task source=\] with
 \|gamepad\|\'s \[=relevant global object=\] to \[=update gamepad
 state=\] for \|gamepad\|.

To [update gamepad state] for \|gamepad:Gamepad\|, run the
following steps:

1. Let \|now:DOMHighResTimeStamp\| be the \[=current high resolution
 time=\] given \|gamepad\|\'s \[=relevant global object=\].
2. Set \|gamepad\|.{{Gamepad/\[\[timestamp\]\]}} to \|now\|.
3. Run the steps to \[=map and normalize axes=\] for \|gamepad\|.
4. Run the steps to \[=map and normalize buttons=\] for \|gamepad\|.
5. Run the steps to \[=record touches=\] for \|gamepad\|.
6. Let \|navigator:Navigator\| be \|gamepad\|\'s \[=relevant global
 object=\]\'s {{Navigator}} object.
7. Let \|document:Document?\| be \|gamepad\|\'s \[=relevant global
 object=\]\'s \[=associated \`Document\`=\]; otherwise \`null\`.
8. If \|document\| is \`null\`, abort these steps.
9. If \|navigator\|.{{Navigator/\[\[hasGamepadGesture\]\]}} is
 \`false\` and \|document\| is a \[=Document/fully active descendant
 of a top-level traversable with user attention=\] and \|gamepad\|
 \[=contains a gamepad user gesture=\]:
 1. Set \|navigator\|.{{Navigator/\[\[hasGamepadGesture\]\]}} to
 \`true\`.
 2. \[=list/For each=\] \|connectedGamepad:Gamepad?\| of
 \|navigator\|.{{Navigator/\[\[gamepads\]\]}}:
 1. If \|connectedGamepad\| is not equal to \`null\`:
 1. Set \|connectedGamepad\|.{{Gamepad/\[\[exposed\]\]}} to
 \`true\`.
 2. Set \|connectedGamepad\|.{{Gamepad/\[\[timestamp\]\]}}
 to \|now\|.
 3. If \|document\| is not \`null\` and is \[=Document/fully
 active=\], then \[=queue a global task=\] on the
 \[=gamepad task source=\] to \[=fire an event=\] named
 {{gamepadconnected}} at \|gamepad\|\'s \[=relevant
 global object=\] using {{GamepadEvent}} with its
 {{GamepadEvent/gamepad}} attribute initialized to
 \|connectedGamepad\|.

To [map and normalize axes] for \|gamepad:Gamepad\|, run the
following steps:

1. Let \|axisValues:list\| be a \[=list=\] of {{unsigned long}} values
 representing the most recent logical axis input values for each axis
 input of the device represented by \|gamepad\|.
2. Let \|maxRawAxisIndex:long\| be the \[=list/size=\] of
 \|axisValues\| − 1.
3. \[=list/For each=\] \|rawAxisIndex:long\| of \[=the range=\] from 0
 to \|maxRawAxisIndex\|:
 1. Let \|mappedIndex:long\| be
 \|gamepad\|.{{Gamepad/\[\[axisMapping\]\]}}\[\|rawAxisIndex\|\].
 2. Let \|logicalValue:unsigned long\| be
 \|axisValues\|\[\|rawAxisIndex\|\].
 3. Let \|logicalMinimum:unsigned long\| be
 \|gamepad\|.{{Gamepad/\[\[axisMinimums\]\]}}\[\|rawAxisIndex\|\].
 4. Let \|logicalMaximum:unsigned long\| be
 \|gamepad\|.{{Gamepad/\[\[axisMaximums\]\]}}\[\|rawAxisIndex\|\].
 5. Let \|normalizedValue:double\| be 2 (\|logicalValue\| −
 \|logicalMinimum\|) / (\|logicalMaximum\| − \|logicalMinimum\|)
 − 1.
 6. Set \|gamepad\|.{{Gamepad/\[\[axes\]\]}}\[\|axisIndex\|\] to be
 \|normalizedValue\|.

To [map and normalize buttons] for \|gamepad:Gamepad\|, run the
following steps:

1. Let \|buttonValues:list\| be a \[=list=\] of {{unsigned long}}
 values representing the most recent logical button input values for
 each button input of the device represented by \|gamepad\|.
2. Let \|maxRawButtonIndex:long\| be the \[=list/size=\] of
 \|buttonValues\| − 1.
3. \[=list/For each=\] \|rawButtonIndex:long\| of \[=the range=\] from
 0 to \|maxRawButtonIndex\|:
 1. Let \|mappedIndex:long\| be
 \|gamepad\|.{{Gamepad/\[\[buttonMapping\]\]}}\[\|rawButtonIndex\|\].

 2. Let \|logicalValue:unsigned long\| be
 \|buttonValues\|\[\|rawButtonIndex\|\].

 3. Let \|logicalMinimum:unsigned long\| be
 \|gamepad\|.{{Gamepad/\[\[buttonMinimums\]\]}}\[\|rawButtonIndex\|\].

 4. Let \|logicalMaximum:unsigned long\| be
 \|gamepad\|.{{Gamepad/\[\[buttonMaximums\]\]}}\[\|rawButtonIndex\|\].

 5. Let \|normalizedValue:double\| be (\|logicalValue\| −
 \|logicalMinimum\|) / (\|logicalMaximum\| − \|logicalMinimum\|).

 6. Let \|button:GamepadButton\| be
 \|gamepad\|.{{Gamepad/\[\[buttons\]\]}}\[\|mappedIndex\|\].

 7. Set \|button\|.{{GamepadButton/\[\[value\]\]}} to
 \|normalizedValue\|.

 8. If the button has a digital switch to indicate a pure pressed or
 released state, set \|button\|.{{GamepadButton/\[\[pressed\]\]}}
 to \`true\` if the button is pressed or \`false\` if it is not
 pressed.

 Otherwise, set \|button\|.{{GamepadButton/\[\[pressed\]\]}} to
 \`true\` if the value is above the \[=button press threshold=\]
 or \`false\` if it is not above the threshold.

 9. If the button is capable of detecting touch, set
 \|button\|.{{GamepadButton/\[\[touched\]\]}} to \`true\` if the
 button is currently being touched.

 Otherwise, set \|button\|.{{GamepadButton/\[\[touched\]\]}} to
 \|button\|.{{GamepadButton/\[\[pressed\]\]}}.

To [record touches] for \|gamepad:Gamepad\|, run the following
steps:

1. Assert: {{Gamepad}}.{{Gamepad/\[\[touches\]\]}} \[=list/is empty=\].
2. Repeat the following steps for each touch surface on \|gamepad\| in
 touch surface enumeration order:
 1. Let \|surfaceId:unsigned long\| be the current surface
 enumeration index.
 2. If the touch surface exposes maximum surface dimensions in
 device units, then set
 \|touch\|.{{GamepadTouch/surfaceDimensions}} to a
 {{DOMRectReadOnly}} with {{DOMRectReadOnly/width}} and
 {{DOMRectReadOnly/height}} initialized to the maximum X and Y
 dimensions on the touch surface in device units.
 3. Repeat the following steps for each active touch point reported
 by the \|gamepad\| for the current touch surface.
 1. Let \|touch:GamepadTouch\| be a newly created
 {{GamepadTouch}} object.

 2. Set \|touch\|.{{GamepadTouch/surfaceId}} to be
 \|surfaceId\|.

 3. If the touch data is part of an existing active touch point
 tracked by the \[=user agent=\]:
 1. Set \|touch\|.{{GamepadTouch/touchId}} to the
 {{GamepadTouch/touchId}} of the active touch point.

 2. Otherwise, set \|touch\|.{{GamepadTouch/touchId}} to
 \|gamepad\|.{{Gamepad/\[\[nextTouchId\]\]}} and
 increment \|gamepad\|.{{Gamepad/\[\[nextTouchId\]\]}}.

 If the Gamepad has multiple touch surfaces the touch id
 will be unique across surfaces.

 4. Set \|touch\|.{{GamepadTouch/position}} to a \[=new=\]
 {{DOMPointReadOnly}} with {{DOMPointReadOnly/x}} initialized
 to device X coordinate relative to the device touch surface
 and normalized to \[-1 .. 1\] where -1 is the leftmost
 coordinate and 1 is the rightmost coordinate and
 {{DOMPointReadOnly/y}} initialized to the device touch
 surface and normalized to \[-1 .. 1\] where -1 is the
 topmost coordinate and 1 is the bottommost coordinate.

 \`x = (2.0 \* touchData.x / surfaceDimensions.width) - 1\`\
 \`y = (2.0 \* touchData.y / surfaceDimensions.height) - 1\`

 5. \[=list/Append=\] \|touch\| to
 \|gamepad\|.{{Gamepad/\[\[touches\]\]}}.

### Constructing a \`Gamepad\`

[A new \`Gamepad\`] representing a connected gamepad device is
constructed by performing the following steps:

1. Let \|gamepad:Gamepad\| be a newly created {{Gamepad}} instance:
 1. Initialize \|gamepad\|\'s {{Gamepad/id}} attribute to an
 identification string for the gamepad.
 2. Initialize \|gamepad\|\'s {{Gamepad/index}} attribute to the
 result of \[=selecting an unused gamepad index=\] for
 \|gamepad\|.
 3. Initialize \|gamepad\|\'s {{Gamepad/mapping}} attribute to the
 result of \[=selecting a mapping=\] for the gamepad device.
 4. Set \|gamepad\|.{{Gamepad/\[\[connected\]\]}} to \`true\`.
 5. Set \|gamepad\|.{{Gamepad/\[\[timestamp\]\]}} to the \[=current
 high resolution time=\] given \|gamepad\|\'s \[=relevant global
 object=\].
 6. Set \|gamepad\|.{{Gamepad/\[\[axes\]\]}} to the result of
 \[=initializing axes=\] for \|gamepad\|.
 7. Set \|gamepad\|.{{Gamepad/\[\[buttons\]\]}} to the result of
 \[=initializing buttons=\] for \|gamepad\|.
 8. Set \|gamepad\|.{{Gamepad/\[\[vibrationActuator\]\]}} to the
 result of \[=constructing a GamepadHapticActuator=\] for
 \|gamepad\|.
2. Return \|gamepad\|.

To [select an unused gamepad index] for \|gamepad:Gamepad\|, run the
following steps:

1. Let \|navigator:Navigator\| be \|gamepad\|\'s \[=relevant global
 object=\]\'s {{Navigator}} object.
2. Let \|maxGamepadIndex:long\| be the \[=list/size=\] of
 \|navigator\|.{{Navigator/\[\[gamepads\]\]}} − 1.
3. \[=list/For each=\] \|gamepadIndex:long\| of \[=the range=\] from 0
 to \|maxGamepadIndex\|:
 1. If
 \|navigator\|.{{Navigator/\[\[gamepads\]\]}}\[\|gamepadIndex\|\]
 is \`null\`, then return \|gamepadIndex\|.
4. \[=list/Append=\] \`null\` to
 \|navigator\|.{{Navigator/\[\[gamepads\]\]}}.
5. Return the \[=list/size=\] of
 \|navigator\|.{{Navigator/\[\[gamepads\]\]}} − 1.

To [initialize axes] for
\|gamepad:Gamepad\|, run the following steps:

1. Let \|inputCount:long\| be the number of axis inputs exposed by the
 device represented by \|gamepad\|.
2. Set \|gamepad\|.{{Gamepad/\[\[axisMinimums\]\]}} to a \[=list=\] of
 {{unsigned long}} values with \[=list/size=\] equal to
 \|inputCount\| containing minimum logical values for each of the
 axis inputs.
3. Set \|gamepad\|.{{Gamepad/\[\[axisMaximums\]\]}} to a \[=list=\] of
 {{unsigned long}} values with \[=list/size=\] equal to
 \|inputCount\| containing maximum logical values for each of the
 axis inputs.
4. Let \|unmappedInputList\| be an empty \[=list=\].
5. Let \|mappedIndexList\| be an empty \[=list=\].
6. Let \|axesSize:long\| be 0.
7. \[=list/For each=\] \|rawInputIndex:long\| of \[=the range=\] from 0
 to \|inputCount\| − 1:
 1. If the gamepad axis at index \|rawInputIndex\| \[=represents a
 Standard Gamepad axis=\]:

 1. Let \|canonicalIndex:long\| be the \[=canonical index=\] for
 the axis.

 2. If \|mappedIndexList\| \[=list/contains=\]
 \|canonicalIndex\|, then append \|rawInputIndex\| to
 \|unmappedInputList\|.

 Otherwise:

 1. Set
 \|gamepad\|.{{Gamepad/\[\[axisMapping\]\]}}\[\|rawInputIndex\|\]
 to \|canonicalIndex\|.
 2. \[=list/Append=\] \|canonicalIndex\| to
 \|mappedIndexList\|.
 3. If \|canonicalIndex\| + 1 is greater than \|axesSize\|,
 then set \|axesSize\| to \|canonicalIndex\| + 1.

 Otherwise, \[=list/append=\] \|rawInputIndex\| to
 \|unmappedInputList\|.
8. Let \|axisIndex:long\| be 0.
9. \[=list/For each=\] \|rawInputIndex:long\| of \|unmappedInputList\|:
 1. While \|mappedIndexList\| \[=list/contains=\] \|axisIndex\|:
 1. Increment \|axisIndex\|.
 2. Set
 \|gamepad\|.{{Gamepad/\[\[axisMapping\]\]}}\[\|rawInputIndex\|\]
 to \|axisIndex\|.
 3. \[=list/Append=\] \|axisIndex\| to \|mappedIndexList\|.
 4. If \|axisIndex\| + 1 is greater than \|axesSize\|, then set
 \|axesSize\| to \|axisIndex\| + 1.
10. Let \|axes\| be an empty \[=list=\].
11. \[=list/For each=\] \|axisIndex:long\| of \[=the range=\] from 0 to
 \|axesSize\| − 1, \[=list/append=\] 0 to \|axes\|.
12. Return \|axes\|.

To [initialize buttons] for
\|gamepad:Gamepad\|, run the following steps:

1. Let \|inputCount:long\| be the number of button inputs exposed by
 the device represented by \|gamepad\|.
2. Set \|gamepad\|.{{Gamepad/\[\[buttonMinimums\]\]}} to be a
 \[=list=\] of {{unsigned long}} values with \[=list/size=\] equal to
 \|inputCount\| containing minimum logical values for each of the
 button inputs.
3. Set \|gamepad\|.{{Gamepad/\[\[buttonMaximums\]\]}} to be a
 \[=list=\] of {{unsigned long}} values with \[=list/size=\] equal to
 \|inputCount\| containing maximum logical values for each of the
 button inputs.
4. Let \|unmappedInputList\| be an empty \[=list=\].
5. Let \|mappedIndexList\| be an empty \[=list=\].
6. Let \|buttonsSize:long\| be 0.
7. \[=list/For each=\] \|rawInputIndex:long\| of \[=the range=\] from 0
 to \|inputCount\| − 1:
 1. If the gamepad button at index \|rawInputIndex\| \[=represents a
 Standard Gamepad button=\]:

 1. Let \|canonicalIndex:long\| be the \[=canonical index=\] for
 the button.

 2. If \|mappedIndexList\| \[=list/contains=\]
 \|canonicalIndex\|, then append \|rawInputIndex\| to
 \|unmappedInputList\|.

 Otherwise:

 1. Set
 \|gamepad\|.{{Gamepad/\[\[buttonMapping\]\]}}\[\|rawInputIndex\|\]
 to \|canonicalIndex\|.
 2. \[=list/Append=\] \|canonicalIndex\| to
 \|mappedIndexList\|.
 3. If \|canonicalIndex\| + 1 is greater than
 \|buttonsSize\|, then set \|buttonsSize\| to
 \|canonicalIndex\| + 1.

 Otherwise, \[=list/append=\] \|rawInputIndex\| to
 \|unmappedInputList\|.

 2. Increment \|rawInputIndex\|.
8. Let \|buttonIndex:long\| be 0.
9. \[=list/For each=\] \|rawInputIndex:long\| of \|unmappedInputList\|:
 1. While \|mappedIndexList\| \[=list/contains=\] \|buttonIndex\|:
 1. Increment \|buttonIndex\|.
 2. Set
 \|gamepad\|.{{Gamepad/\[\[buttonMapping\]\]}}\[\|rawInputIndex\|\]
 to \|buttonIndex\|.
 3. \[=list/Append=\] \|buttonIndex\| to \|mappedIndexList\|.
 4. If \|buttonIndex\| + 1 is greater than \|buttonsSize\|, then set
 \|buttonsSize\| to \|buttonIndex\| + 1.
10. Let \|buttons\| be an empty \[=list=\].
11. \[=list/For each=\] \|buttonIndex:long\| of \[=the range=\] from 0
 to \|buttonsSize\| − 1, \[=list/append=\] a \[=new=\]
 {{GamepadButton}} to \|buttons\|.
12. Return \|buttons\|.

## [GamepadButton] Interface

This interface defines the state of an individual button on a gamepad
device.

``` idl

 [Exposed=Window]
 interface GamepadButton {
 readonly attribute boolean pressed;
 readonly attribute boolean touched;
 readonly attribute double value;
 };

```

Instances of {{GamepadButton}} are created with the internal slots
described in the following table:

 Internal slot Initial value Description (non-normative)
 --------------------------------------------------- --------------- ---------------------------------------------------------------------------
 [\[\[\\pressed\]\]] \`false\` A flag indicating that the button is pressed
 [\[\[\\touched\]\]] \`false\` A flag indicating that the button is touched
 [\[\[\\value\]\]] 0.0 A {{double}} representing the button value scaled to the range \[0 .. 1\]

[pressed] attribute

: The pressed state of the button. This property MUST be \`true\` if
 the button is currently pressed, and \`false\` if it is not pressed.
 For buttons which do not have a digital switch to indicate a pure
 pressed or released state, the \[=user agent=\] MUST choose a
 [button press threshold] to indicate the button as pressed
 when its value is above a certain amount. If the platform API gives
 a recommended value, the \[=user agent=\] SHOULD use that. In other
 cases, the \[=user agent=\] SHOULD choose some other reasonable
 value.

 The {{GamepadButton/pressed}} getter steps are:

 1. Return \[=this=\].{{GamepadButton/\[\[pressed\]\]}}.

[touched] attribute

: The touched state of the button. If the button is capable of
 detecting touch, this property MUST be \`true\` if the button is
 currently being touched, and \`false\` otherwise. If the button is
 not capable of detecting touch and is capable of reporting an analog
 value, this property MUST be \`true\` if the value property is
 greater than 0, and \`false\` if the value is 0. If the button is
 not capable of detecting touch and can only report a digital value,
 this property MUST mirror the {{GamepadButton/pressed}} attribute.

 The {{GamepadButton/touched}} getter steps are:

 1. Return \[=this=\].{{GamepadButton/\[\[touched\]\]}}.

[value] attribute

: For buttons that have an analog sensor, this property MUST represent
 the amount which the button has been pressed. All button values MUST
 be linearly normalized to the range \[0 .. 1\]. 0 MUST mean fully
 unpressed, and 1 MUST mean fully pressed. For buttons without an
 analog sensor, only the values 0 and 1 for fully unpressed and fully
 pressed respectively, MUST be provided.

 The {{GamepadButton/value}} getter steps are:

 1. Return \[=this=\].{{GamepadButton/\[\[value\]\]}}.

## [GamepadTouch] Interface

This interface defines a touch on a gamepad\'s touch surface that
supports such input. The object consists of a touch
{{GamepadTouch/touchId}} that uniquely identifies the touch point from
the time the input medium (e.g. finger, stylus, etc) makes contact with
the touch device, up to the time the input medium is no longer making
contact with the touch device.

```

 dictionary GamepadTouch {
 unsigned long touchId;
 octet surfaceId;
 DOMPointReadOnly position;
 DOMRectReadOnly? surfaceDimensions;
 };

```

[touchId] attribute
: Unique id of the touch. Range is \[0 .. 4294967295\].

[surfaceId] attribute
: Unique id of the surface that generated the touch.

[position] attribute
: A {{DOMPointReadOnly}} which holds the {{DOMPointReadOnly/x}},
 {{DOMPointReadOnly/y}} coordinates of the touch. The z and w value
 are currently unused. The range of each coordinate is normalized to
 \[-1 .. 1\]. Along the x-axis, -1 references the leftmost coordinate
 and 1 references the rightmost coordinate. Along the y-axis, -1
 references the topmost coordinate and 1 references the bottommost
 coordinate.

[surfaceDimensions] attribute
: A {{DOMRectReadOnly}} initialized with the {{DOMRectReadOnly/width}}
 and {{DOMRectReadOnly/height}} of the touch surface in integer
 units. If not available then \`null\`.

## [GamepadMappingType] Enum

This enum defines the set of known mappings for a Gamepad.

``` idl

 enum GamepadMappingType {
 "",
 "standard",
 "xr-standard",
 };

```

[\"\"]
: The empty string indicates that no mapping is in use for this
 gamepad.

\"[standard]\"
: The Gamepad\'s controls have been mapped to the \[=Standard
 Gamepad=\] layout.

\"[xr-standard]\"
: The Gamepad\'s controls have been mapped to the \[=\"xr-standard\"
 gamepad mapping=\]. This mapping is reserved for use by the
 \[\[\[webxr-gamepads-module-1\]\]\]. {{Gamepad}} objects returned by
 {{Navigator/getGamepads()}} MUST NOT report a {{Gamepad/mapping}} of
 {{GamepadMappingType/\"xr-standard\"}}.

## [GamepadHapticActuator] Interface

A {{GamepadHapticActuator}} corresponds to a configuration of motors or
other actuators that can apply a force for the purposes of haptic
feedback.

``` idl

 [Exposed=Window]
 interface GamepadHapticActuator {
 [SameObject] readonly attribute FrozenArray<GamepadHapticEffectType> effects;
 Promise<GamepadHapticsResult> playEffect(
 GamepadHapticEffectType type,
 optional GamepadEffectParameters params =
 );
 Promise<GamepadHapticsResult> reset();
 };

```

Instances of {{GamepadHapticActuator}} are created with the internal
slots described in the following table:

 Internal slot Initial value Description
 ------------------------------------------------------------------------ ------------------------------------------------------------- ---------------------------------------------------------------------------
 [\[\[\\effects\]\]] An empty \[=list=\] of {{Gamepad/GamepadHapticEffectType}}. Represents the effects supported by the actuator.
 [\[\[\\playingEffectPromise\]\]] \`null\` The {{Promise}} to play some effect, or \`null\` if no effect is playing.

[effects] attribute

: Array of {{Gamepad/GamepadHapticEffectType}} values representing all
 the types of haptic effects that the actuator supports. This
 property lists the {{Gamepad/GamepadHapticEffectType}} values that
 the actuator supports, unless the \[=user agent=\] does not support
 playing effects of that type.

 The {{GamepadHapticActuator/effects}} getter steps are:

 1. Return \[=this=\].{{GamepadHapticActuator/\[\[effects\]\]}}.

[playEffect()] method

: The {{GamepadHapticActuator/playEffect()}} method steps, called with
 {{GamepadHapticEffectType}} \|type:GamepadHapticEffectType\| and
 {{GamepadEffectParameters}} \|params:GamepadEffectParameters\|, are:

 1. If \|params:GamepadEffectParameters\| does not describe a
 \[=valid effect=\] of type \|type:GamepadHapticEffectType\|,
 return \[=a promise rejected with=\] a {{TypeError}}.
 2. Let \|document:Document?\| be the \[=current settings
 object=\]\'s \[=relevant global object=\]\'s \[=associated
 \`Document\`=\].
 3. If \|document\| is \`null\` or \|document\| is not
 \[=Document/fully active=\] or \|document\|\'s
 \[=Document/visibility state=\] is \`\"hidden\"\`, return \[=a
 promise rejected with=\] an \"{{InvalidStateError}}\"
 {{DOMException}}.
 4. If
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 is not \`null\`:
 1. Let \|effectPromise\| be
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}.
 2. Set
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 to \`null\`.
 3. \[=Queue a global task=\] on the \[=gamepad task source=\]
 with the \[=relevant global object=\] of \[=this=\] to
 \[=resolve=\] \|effectPromise\| with
 {{GamepadHapticsResult/\"preempted\"}}.
 5. If \[=this=\] {{GamepadHapticActuator}} cannot \[=play effects
 with type=\] \|type\|, return \[=a promise rejected with=\]
 reason {{NotSupportedError}}.
 6. Let {{GamepadHapticActuator/\[\[playingEffectPromise\]\]}} be
 \[=a new promise=\].
 7. Let \|playEffectTimestamp:DOMHighResTimestamp\| be the
 \[=current high resolution time=\] given the \|document\|\'s
 \[=relevant global object=\].
 8. Do the following steps \[=in parallel=\]:
 1. \[=Issue a haptic effect=\] to the actuator with \|type\|,
 \|params\|, and the \|playEffectTimestamp\|.
 2. When the effect completes, if
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 is not \`null\`, \[=queue a global task=\] on the \[=gamepad
 task source=\] with the \[=relevant global object=\] of
 \[=this=\] to run the following steps:
 1. If
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 is \`null\`, abort these steps.
 2. \[=Resolve=\]
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 with {{GamepadHapticsResult/\"complete\"}}.
 3. Set
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 to \`null\`.
 9. Return {{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}.

[reset()] method

: The {{GamepadHapticActuator/reset()}} method steps are:

 1. Let \|document:Document?\| be the \[=current settings
 object=\]\'s \[=relevant global object=\]\'s \[=associated
 \`Document\`=\].
 2. If \|document\| is \`null\` or \|document\| is not
 \[=Document/fully active=\] or \|document\|\'s
 \[=Document/visibility state=\] is \`\"hidden\"\`, return \[=a
 promise rejected with=\] an \"{{InvalidStateError}}\"
 {{DOMException}}.
 3. Let \|resetResultPromise:Promise\| be \[=a new promise=\].
 4. If
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 is not \`null\`, do the following steps \[=in parallel=\]:
 1. Let \|effectPromise\| be
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}.
 2. \[=Stop haptic effects=\] on \[=this=\]\'s gamepad\'s
 actuator.
 3. If the effect has been successfully stopped, do:
 1. If \|effectPromise\| and
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 are still the same, set
 \[=this=\].{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 to \`null\`.
 2. \[=Queue a global task=\] on the \[=gamepad task
 source=\] with the \[=relevant global object=\] of
 \[=this=\] to \[=resolve=\] \|effectPromise\| with
 {{GamepadHapticsResult/\"preempted\"}}.
 4. \[=Resolve=\] \|resetResultPromise\| with
 {{GamepadHapticsResult/\"complete\"}}
 5. Return \|resetResultPromise\|.

A {{GamepadHapticActuator}} can [play effects with type]
\|type:GamepadHapticEffectType\| if \|type:GamepadHapticEffectType\| can
be found in the {{GamepadHapticActuator/\[\[effects\]\]}} \[=list=\].

To check if an effect with {{GamepadHapticEffectType}}
\|type:GamepadHapticEffectType\| and {{GamepadEffectParameters}}
\|params:GamepadEffectParameters\| describes a [valid effect], run
the following steps:

1. Given the value of {{GamepadHapticEffectType}}
 \|type:GamepadHapticEffectType\|, switch on:

 {{GamepadHapticEffectType/\"dual-rumble\"}}
 : If \|params\| does not describe a \[=valid dual-rumble
 effect=\], return \`false\`.

 {{GamepadHapticEffectType/\"trigger-rumble\"}}
 : If \|params\| does not describe a \[=valid trigger-rumble
 effect=\], return \`false\`.
2. Return \`true\`

To [issue a haptic effect] on an actuator, the \[=user agent=\]
MUST send a command to the device to render an effect of
\|type:GamepadHapticEffectType\| and try to make it use the provided
\|params:GamepadEffectParameters\|. The \[=user agent=\] SHOULD use the
provided \|playEffectTimestamp:DOMHighResTimestamp\| for more precise
playback timing when \|params\|.{{GamepadEffectParameters/startDelay}}
is not \`0.0\`. The \[=user agent=\] MAY modify the effect to increase
compatibility. For example, an effect intended for a rumble motor may be
transformed into a waveform-based effect for a device that supports
waveform haptics but lacks rumble motors.

To [stop haptic effects] on an actuator, the \[=user agent=\] MUST
send a command to the device to abort any effects currently being
played. If a haptic effect was interrupted, the actuator SHOULD return
to a motionless state as quickly as possible.

### Handling visibility change

When the \|document\|\'s \[=Document/visibility state=\] becomes
\`\"hidden\"\`, run these steps for each {{GamepadHapticActuator}}
\|actuator:GamepadHapticActuator\|:

1. If
 \|actuator\|.{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 is \`null\`, abort these steps.
2. \[=Queue a global task=\] on the \[=gamepad task source=\] with the
 \[=relevant global object=\] of \|actuator\| to run the following
 steps:
 1. If
 \|actuator\|.{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 is \`null\`, abort these steps.
 2. \[=Resolve=\]
 \|actuator\|.{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 with {{GamepadHapticsResult/\"preempted\"}}.
 3. Set
 \|actuator\|.{{GamepadHapticActuator/\[\[playingEffectPromise\]\]}}
 to \`null\`.
3. \[=Stop haptic effects=\] on \|actuator\|.

### Constructing a \`GamepadHapticActuator\`

[A new \|gamepadHapticActuator:GamepadHapticActuator\|] representing a {{Gamepad}}\'s
primary vibration actuator is constructed by performing the following
steps:

1. Let \|gamepadHapticActuator:GamepadHapticActuator\| be a newly
 created {{GamepadHapticActuator}} instance.
2. Let \`supportedEffectsList\` be an empty \[=list=\].
3. For each enum value \|type:GamepadHapticEffectType\| of
 {{GamepadHapticEffectType}}, if the \[=user agent=\] can send a
 command to initiate effects of that type on that actuator, append
 \|type\| to \`supportedEffectsList\`.
4. Set
 \|gamepadHapticActuator\|.{{GamepadHapticActuator/\[\[effects\]\]}}
 to \`supportedEffectsList\`.

### [GamepadHapticsResult] Enum

``` idl

 enum GamepadHapticsResult {
 "complete",
 "preempted"
 };

```

[complete]

: The haptic effected completed playing.

[preempted]

: The current effect was stopped or replaced (i.e., \"preempted\") by
 another effect.

### [GamepadHapticEffectType] Enum

The effect type defines how the effect parameters are interpreted by the
actuator.

``` idl

 enum GamepadHapticEffectType {
 "dual-rumble",
 "trigger-rumble"
 };

```

\"[dual-rumble]\" effect type

: {{GamepadHapticEffectType/\"dual-rumble\"}} describes a haptic
 configuration with an eccentric rotating mass (ERM) vibration motor
 in each handle of a standard gamepad. In this configuration, either
 motor is capable of vibrating the whole gamepad. The vibration
 effects created by each motor are unequal so that the effects of
 each can be combined to create more complex haptic effects.

 A {{GamepadHapticEffectType/\"dual-rumble\"}} effect is a
 fixed-duration, constant-intensity vibration effect intended for an
 actuator of this type. {{GamepadHapticEffectType/\"dual-rumble\"}}
 effects are defined by {{GamepadEffectParameters/startDelay}},
 {{GamepadEffectParameters/duration}},
 {{GamepadEffectParameters/strongMagnitude}}, and
 {{GamepadEffectParameters/weakMagnitude}}, none of which are
 required because they default to 0.

 {{GamepadEffectParameters/strongMagnitude}} and
 {{GamepadEffectParameters/weakMagnitude}} set the intensity levels
 for the low-frequency and high-frequency vibrations, normalized to
 the range \[0 .. 1\], defaulting to 0.

 Given {{GamepadEffectParameters}}
 \|params:GamepadEffectParameters\|, a [valid dual-rumble
 effect] must have a \[=valid effect\|valid=\]
 {{GamepadEffectParameters/duration}}, a \[=valid effect\|valid=\]
 {{GamepadEffectParameters/startDelay}}, and both the
 {{GamepadEffectParameters/strongMagnitude}} and the
 {{GamepadEffectParameters/weakMagnitude}} must be in the range \[0
 .. 1\].

\"[trigger-rumble]\" effect type

: {{GamepadHapticEffectType/\"trigger-rumble\"}} describes a haptics
 configuration with a vibration motor in each of the bottom front
 buttons of a \[=Standard Gamepad=\] (buttons with \[=canonical
 indices=\] 6 and 7) in addition to the two handle motors used for
 {{GamepadHapticEffectType/\"dual-rumble\"}}. These buttons most
 commonly take the form of spring-loaded triggers. In this
 configuration, either motor is capable of providing localized haptic
 feedback on the button\'s surface.

 A {{GamepadHapticEffectType/\"trigger-rumble\"}} effect is a
 fixed-duration, constant-intensity vibration effect intended for an
 actuator of this type.
 {{GamepadHapticEffectType/\"trigger-rumble\"}} effects are defined
 by {{GamepadEffectParameters/startDelay}},
 {{GamepadEffectParameters/duration}},
 {{GamepadEffectParameters/strongMagnitude}},
 {{GamepadEffectParameters/weakMagnitude}},
 {{GamepadEffectParameters/leftTrigger}}, and
 {{GamepadEffectParameters/rightTrigger}}, none of which are required
 because they default to 0.

 {{GamepadEffectParameters/startDelay}},
 {{GamepadEffectParameters/duration}},
 {{GamepadEffectParameters/strongMagnitude}},
 {{GamepadEffectParameters/weakMagnitude}} share the same definition
 with {{GamepadHapticEffectType/\"dual-rumble\"}}.
 {{GamepadEffectParameters/leftTrigger}} and
 {{GamepadEffectParameters/rightTrigger}}, respectively, set the
 intensity levels for the left and right bottom front buttons
 vibrations, normalized to the range \[0 .. 1\], defaulting to 0.

 Given {{GamepadEffectParameters}}
 \|params:GamepadEffectParameters\|, a [valid trigger-rumble
 effect] must have a \[=valid effect\|valid=\]
 {{GamepadEffectParameters/duration}}, a \[=valid effect\|valid=\]
 {{GamepadEffectParameters/startDelay}}, and the
 {{GamepadEffectParameters/strongMagnitude}},
 {{GamepadEffectParameters/weakMagnitude}},
 {{GamepadEffectParameters/leftTrigger}}, and
 {{GamepadEffectParameters/rightTrigger}} must be in the range \[0 ..
 1\].

### [GamepadEffectParameters] Dictionary

A \`GamepadEffectParameters\` dictionary contains keys for parameters
used by haptic effects. The meaning of each key is defined by the haptic
effect, and some keys may be unused.

To mitigate unwanted long-running effects, the \[=user agent=\] MAY
limit the total effect duration for a \[=valid effect=\] to some maximum
duration. It is RECOMMENDED that the \[=user agent=\] use a maximum of 5
seconds.

``` idl

 dictionary GamepadEffectParameters {
 unsigned long long duration = 0;
 unsigned long long startDelay = 0;
 double strongMagnitude = 0.0;
 double weakMagnitude = 0.0;
 double leftTrigger = 0.0;
 double rightTrigger = 0.0;
 };

```

[duration] member
: {{GamepadEffectParameters/duration}} sets the duration of the
 vibration effect in milliseconds.

[startDelay] member
: {{GamepadEffectParameters/startDelay}} sets the duration of the
 delay after {{GamepadHapticActuator/playEffect()}} is called until
 vibration is started, in milliseconds. During the delay interval,
 the actuator SHOULD NOT vibrate.

[strongMagnitude] member
: The vibration magnitude for the low frequency rumble in a
 {{GamepadHapticEffectType/\"dual-rumble\"}} or
 {{GamepadHapticEffectType/\"trigger-rumble\"}} effect.

[weakMagnitude] member
: The vibration magnitude for the high frequency rumble in a
 {{GamepadHapticEffectType/\"dual-rumble\"}} or
 {{GamepadHapticEffectType/\"trigger-rumble\"}} effect.

[leftTrigger] member
: The vibration magnitude for the bottom left front button
 (\[=canonical index=\] 6) rumble in a
 {{GamepadHapticEffectType/\"trigger-rumble\"}} effect.

[rightTrigger] member
: The vibration magnitude for the bottom right front button
 (\[=canonical index=\] 7) rumble in a
 {{GamepadHapticEffectType/\"trigger-rumble\"}} effect.

## Extensions to the \`Navigator\` Interface

``` idl

 [Exposed=Window]
 partial interface Navigator {
 sequence<Gamepad?> getGamepads();
 };

```

Instances of {{Navigator}} are created with the internal slots described
in the following table:

 Internal slot Initial value Description (non-normative)
 --------------------------------------------------------- ------------------------------------------------ -------------------------------------------------------------------------------------------------------------------------
 [\[\[\\hasGamepadGesture\]\]] \`false\` A flag indicating that a \[=gamepad user gesture=\] has been observed
 [\[\[\\gamepads\]\]] A empty \[=sequence=\] of {{Gamepad?}} objects Each {{Gamepad}} present at the index specified by its {{Gamepad/index}} attribute, or \`null\` for unassigned indices.

### [getGamepads()] method

The gamepad state returned from {{Navigator/getGamepads()}} does not
reflect disconnection or connection until after the
{{gamepaddisconnected}} or {{gamepadconnected}} events have fired.

To mitigate fingerprinting, {{Navigator/getGamepads()}} returns an empty
\[=list=\] before a \[=gamepad user gesture=\] has been seen.
\[\[FINGERPRINTING-GUIDANCE\]\]

{{Navigator/getGamepads()}} returns a snapshot of the data for the
currently connected and interacted-with gamepads. When a gamepad is no
longer connected, its index in the array should return \`null\`. If
there is one connected {{Gamepad}} with an {{Gamepad/index}} of 1, then
the following code snippet describes the expected behavior:

``` js

 // gamepads should look like [null, [object Gamepad]]
 var gamepads = navigator.getGamepads();
 // The following statements should all evaluate to true.
 gamepads[0] == null;
 gamepads[1].index == 1;
 gamepads.length == 2;

```

The {{Navigator/getGamepads()}} method steps are:

1. Let \|doc:Document?\| be the \[=current global object=\]\'s
 \[=associated \`Document\`=\].
2. If \|doc\| is \`null\` or \|doc\| is not \[=Document/fully
 active=\], then return an empty \[=list=\].
3. If \|doc\| is not \[=allowed to use=\] the \`\"gamepad\"\`
 permission, then \[=exception/throw=\] a {{\"SecurityError\"}}
 {{DOMException}} and abort these steps.
4. If \[=this=\].{{Navigator/\[\[hasGamepadGesture\]\]}} is \`false\`,
 then return an empty \[=list=\].
5. Let \|now:DOMHighResTimeStamp\| be the \[=current high resolution
 time=\] given the \[=current global object=\].
6. Let \|gamepads:sequence\<Gamepad?\>\| be an empty \[=list=\].
7. \[=list/For each=\] \|gamepad:Gamepad\| of
 \[=this=\].{{Navigator/\[\[gamepads\]\]}}:
 1. If \|gamepad\| is not \`null\` and
 \|gamepad\|.{{Gamepad/\[\[exposed\]\]}} is \`false\`:
 1. Set \|gamepad\|.{{Gamepad/\[\[exposed\]\]}} to \`true\`.
 2. Set \|gamepad\|.{{Gamepad/\[\[timestamp\]\]}} to \|now\|.
 2. \[=list/Append=\] \|gamepad\| to \|gamepads\|.
8. Return \|gamepads\|.

A \|gamepad:Gamepad\| [contains a gamepad user gesture] if the current input state indicates that the
user is currently interacting with the gamepad. The \[=user agent=\]
MUST provide an algorithm to check if the input state contains a gamepad
user gesture. For buttons that support a neutral default value and have
reported a {{GamepadButton/pressed}} value of \`false\` at least once, a
{{GamepadButton/pressed}} value of \`true\` SHOULD be considered
interaction. If a button does not support a neutral default value (for
example, a toggle switch), then a {{GamepadButton/pressed}} value of
\`true\` SHOULD NOT be considered interaction. If a button has never
reported a {{GamepadButton/pressed}} value of \`false\` then it SHOULD
NOT be considered interaction. Axis movements SHOULD be considered
interaction if the axis supports a neutral default value, the current
displacement from neutral is greater than a threshold chosen by the
\[=user agent=\], and the axis has reported a value below the threshold
at least once. If an axis does not support a neutral default value (for
example, an axis for a joystick that does not self-center), or an axis
has never reported a value below the axis gesture threshold, then the
axis SHOULD NOT be considered when checking for interaction. The axis
gesture threshold SHOULD be large enough that random jitter is not
considered interaction.

## [GamepadEvent] Interface

```

 [Exposed=Window]

 interface GamepadEvent: Event {
 constructor(DOMString type, optional GamepadEventInit eventInitDict = );
 [SameObject] readonly attribute Gamepad gamepad;
 };

```

[gamepad] attribute
: The {{GamepadEvent/gamepad}} attribute provides access to the
 associated gamepad data for this event.

### [GamepadEventInit] dictionary

```

 dictionary GamepadEventInit : EventInit {
 Gamepad? gamepad = null;
 };

```

[gamepad] member
: The {{Gamepad}} associated with this event.

## Remapping

Each device manufacturer creates many different products and each has
unique styles and layouts of buttons and axes. It is intended that the
\[=user agent=\] support as many of these as possible.

Additionally there are *de facto* standard layouts that have been made
popular by game consoles. When the \[=user agent=\] recognizes the
attached device, it is RECOMMENDED that it be remapped to a canonical
ordering when possible. Devices that are not recognized should still be
exposed in their raw form.

There is currently one canonical layout, the [Standard Gamepad].
When remapping, the indices in {{Gamepad/axes}} and {{Gamepad/buttons}}
should correspond as closely as possible to the physical locations in
the diagram below. Additionally, {{Gamepad/mapping}} SHOULD be set to
{{GamepadMappingType/\"standard\"}}.

The \[=Standard Gamepad=\] buttons are laid out in a left cluster of
four buttons, a right cluster of four buttons, a center cluster of three
buttons, and a pair of front facing buttons on the left and right side
of the gamepad. The four axes of the \"Standard Gamepad\" are associated
with a pair of analog sticks, one on the left and one on the right. The
following table describes the buttons/axes and their physical locations.

An axis input [represents a Standard Gamepad axis] if it reports
the input value for a thumbstick axis, the thumbstick is located in
approximately the same location as the corresponding \[=Standard
Gamepad=\] thumbstick, and the orientation of the axis (up-down or
left-right) matches the orientation of the \[=Standard Gamepad=\] axis.
If there are multiple axes that represent the same \[=Standard
Gamepad=\] axis, then the \[=user agent=\] SHOULD select one to be the
\[=Standard Gamepad=\] axis and assign a different index to the other
axis.

A button input [represents a Standard Gamepad button] if it
reports the input value for a button or trigger, and the button or
trigger is located in approximately the same location as the
corresponding \[=Standard Gamepad=\] button.

If an axis or button input represents a \[=Standard Gamepad=\] axis or
button, then its [canonical index] is the
index of the corresponding \[=Standard Gamepad=\] axis or button.

+--------+-------+-----------------------------------------------------+
| Type | Index | Location |
+========+=======+=====================================================+
| Button | 0 | Bottom button in right cluster |
| +-------+-----------------------------------------------------+
| | 1 | Right button in right cluster |
| +-------+-----------------------------------------------------+
| | 2 | Left button in right cluster |
| +-------+-----------------------------------------------------+
| | 3 | Top button in right cluster |
| +-------+-----------------------------------------------------+
| | 4 | Top left front button |
| +-------+-----------------------------------------------------+
| | 5 | Top right front button |
| +-------+-----------------------------------------------------+
| | 6 | Bottom left front button |
| +-------+-----------------------------------------------------+
| | 7 | Bottom right front button |
| +-------+-----------------------------------------------------+
| | 8 | Left button in center cluster |
| +-------+-----------------------------------------------------+
| | 9 | Right button in center cluster |
| +-------+-----------------------------------------------------+
| | 10 | Left stick pressed button |
| +-------+-----------------------------------------------------+
| | 11 | Right stick pressed button |
| +-------+-----------------------------------------------------+
| | 12 | Top button in left cluster |
| +-------+-----------------------------------------------------+
| | 13 | Bottom button in left cluster |
| +-------+-----------------------------------------------------+
| | 14 | Left button in left cluster |
| +-------+-----------------------------------------------------+
| | 15 | Right button in left cluster |
| +-------+-----------------------------------------------------+
| | 16 | Center button in center cluster |
+--------+-------+-----------------------------------------------------+
| axes | 0 | Horizontal axis for left stick (negative |
| | | left/positive right) |
| +-------+-----------------------------------------------------+
| | 1 | Vertical axis for left stick (negative up/positive |
| | | down) |
| +-------+-----------------------------------------------------+
| | 2 | Horizontal axis for right stick (negative |
| | | left/positive right) |
| +-------+-----------------------------------------------------+
| | 3 | Vertical axis for right stick (negative up/positive |
| | | down) |
+--------+-------+-----------------------------------------------------+

![Visual representation of a \[=Standard Gamepad=\]
layout.](standard_gamepad.svg)

### Fingerprinting mitigation

Inspecting the capabilities of {{Gamepad}} objects can be used as a
means of active fingerprinting. The \[=user agent=\] MAY alter the
device information exposed through the API to reduce the fingerprinting
surface. As an example, an implementation can require that a {{Gamepad}}
object have exactly the number of buttons and axes defined in the
\[=Standard Gamepad=\] layout even if more or fewer inputs are present
on the connected device. \[\[FINGERPRINTING-GUIDANCE\]\]

## Usage Examples

The example below demonstrates typical access to gamepads. Note the
relationship with the {{AnimationFrameProvider/requestAnimationFrame()}}
method.

```

 function runAnimation() {
 window.requestAnimationFrame(runAnimation);
 for (const pad of navigator.getGamepads()) {
 // todo; simple demo of displaying pad.axes and pad.buttons
 console.log(pad);
 }
 }

 window.requestAnimationFrame(runAnimation);

```

[Coordination with \`requestAnimationFrame()\`]

Interactive applications will typically be using the
{{AnimationFrameProvider/requestAnimationFrame()}} method to drive
animation, and will want coordinate animation with user gamepad input.
As such, the gamepad data should be polled as closely as possible to
immediately before the animation callbacks are executed, and with
frequency matching that of the animation. That is, if the animation
callbacks are running at 60Hz, the gamepad inputs should also be sampled
at that rate.

## The [gamepadconnected] event

When a gamepad becomes available on the system, run the following steps:

1. Let \|document:Document?\| be the \[=current global object=\]\'s
 \[=associated \`Document\`=\]; otherwise \`null\`.
2. If \|document\| is not \`null\` and is not \[=allowed to use=\] the
 \`\"gamepad\"\` permission, then abort these steps.
3. \[=Queue a global task=\] on the \[=gamepad task source=\] with the
 \[=current global object=\] to perform the following steps:
 1. Let \|gamepad:Gamepad\| be \[=a new \`Gamepad\`=\] representing
 the gamepad.
 2. Let \|navigator:Navigator\| be \|gamepad\|\'s \[=relevant global
 object=\]\'s {{Navigator}} object.
 3. Set
 \|navigator\|.{{Navigator/\[\[gamepads\]\]}}\[\|gamepad\|.{{Gamepad/index}}\]
 to \|gamepad\|.
 4. If \|navigator\|.{{Navigator/\[\[hasGamepadGesture\]\]}} is
 \`true\`:
 1. Set \|gamepad\|.{{Gamepad/\[\[exposed\]\]}} to \`true\`.
 2. If \|document\| is not \`null\` and is \[=Document/fully
 active=\], then \[=fire an event=\] named
 {{gamepadconnected}} at \|gamepad\|\'s \[=relevant global
 object=\] using {{GamepadEvent}} with its
 {{GamepadEvent/gamepad}} attribute initialized to
 \|gamepad\|.

\[=User agents=\] implementing this specification must provide a new DOM
event, named {{gamepadconnected}}. The corresponding event MUST be of
type {{GamepadEvent}} and MUST fire on the {{Window}} object.

A \[=user agent=\] MUST dispatch this event type to indicate the user
has connected a gamepad. If a gamepad was already connected when the
page was loaded, the {{gamepadconnected}} event SHOULD be dispatched
when the user presses a button or moves an axis.

## The [gamepaddisconnected] event

When a gamepad becomes unavailable on the system, run the following
steps:

1. Let \|gamepad:Gamepad\| be the {{Gamepad}} representing the
 unavailable device.
2. \[=Queue a global task=\] on the \[=gamepad task source=\] with
 \|gamepad\|\'s \[=relevant global object=\] to perform the following
 steps:
 1. Set \|gamepad\|.{{Gamepad/\[\[connected\]\]}} to \`false\`.
 2. Let \|document:Document?\| be \|gamepad\|\'s \[=relevant global
 object=\]\'s \[=associated \`Document\`=\]; otherwise \`null\`.
 3. If \|gamepad\|.{{Gamepad/\[\[exposed\]\]}} is \`true\` and
 \|document\| is not \`null\` and is \[=Document/fully active=\],
 then \[=fire an event=\] named {{gamepaddisconnected}} at
 \|gamepad\|\'s \[=relevant global object=\] using
 {{GamepadEvent}} with its {{GamepadEvent/gamepad}} attribute
 initialized to \|gamepad\|.
 4. Let \|navigator:Navigator\| be \|gamepad\|\'s \[=relevant global
 object=\]\'s {{Navigator}} object.
 5. Set
 \|navigator\|.{{Navigator/\[\[gamepads\]\]}}\[\|gamepad\|.{{Gamepad/index}}\]
 to \`null\`.
 6. While \|navigator\|.{{Navigator/\[\[gamepads\]\]}} \[=list/is
 not empty=\] and the last \[=list/item=\] of
 \|navigator\|.{{Navigator/\[\[gamepads\]\]}} is \`null\`,
 \[=list/remove=\] the last \[=list/item=\] of
 \|navigator\|.{{Navigator/\[\[gamepads\]\]}}.

\[=User agents=\] implementing this specification must provide a new DOM
event, named {{gamepaddisconnected}}. The corresponding event MUST be of
type {{GamepadEvent}} and MUST fire on the {{Window}} object.

When a gamepad is disconnected from the \[=user agent=\], if the \[=user
agent=\] has previously dispatched a {{gamepadconnected}} event for that
gamepad to a {{Window}}, a {{gamepaddisconnected}} event MUST be
dispatched to that same {{Window}}.

## Other events

*More discussion needed, on whether to include or exclude axis and
button changed events, and whether to roll them more together
(\`\"gamepadchanged\"\`?), separate somewhat
(\`\"gamepadaxischanged\"\`?), or separate by individual axis and
button.*

## Extensions to the \`WindowEventHandlers\` Interface Mixin

This specification extends the {{WindowEventHandlers}} interface mixin
from HTML to add \[=event handler IDL attributes=\] to facilitate the
event handler registration.

``` idl

 partial interface mixin WindowEventHandlers {
 attribute EventHandler ongamepadconnected;
 attribute EventHandler ongamepaddisconnected;
 };

```

## Integration with Permissions Policy

This specification defines a policy-controlled feature identified by the
string [\"gamepad\"]. Its \[=policy-controlled
feature/default allowlist=\] is \[=default allowlist/\*=\].

A \[=document=\]\'s \[=Document/permissions policy=\] determines whether
any content in that document is allowed to access
{{Navigator/getGamepads()}}. If disabled in any document, no content in
the document will be \[=allowed to use=\] {{Navigator/getGamepads()}},
nor will the {{gamepadconnected}} and {{gamepaddisconnected}} events
fire.

## Acknowledgements

The following people contributed to the development of this document.

- David Humphrey
- Gregg Tavares
- Marcin Wichary
- Jason Orendorff
- Olli Pettay
- Rick Waldron
