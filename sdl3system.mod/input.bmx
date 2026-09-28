Rem
bbdoc: Detailed wheel movement, including horizontal and fractional scrolling.
about: extra is a TSDLMouseWheelEvent. One event is emitted per uncaptured SDL wheel event. EVENT_MOUSEWHEEL is also emitted when accumulated vertical movement reaches a whole step; handle one interface or the other to avoid double counting.
End Rem
Global EVENT_SDL3_MOUSE_WHEEL:Int = AllocUserEventId("SDL3 mouse wheel")

Rem
bbdoc: Dropped text. extra is a TSDLTextDropEvent; data is the SDL window ID.
End Rem
Global EVENT_SDL3_TEXT_DROP:Int = AllocUserEventId("SDL3 text drop")

Rem
bbdoc: Common copied input metadata carried in the extra field of SDL3 BRL input events.
about: source remains Null for compatibility. windowID identifies the originating SDL window, not an owned window reference. timestamp is SDL's nanosecond timestamp. Payloads may be retained after polling; no native event pointers are stored.
End Rem
Type TSDLInputEvent
	Field windowID:UInt
	Field timestamp:ULong
End Type

Rem
bbdoc: Native keyboard data attached to key down, up, repeat and control-character events.
End Rem
Type TSDLKeyboardEvent Extends TSDLInputEvent
	Field keyboardID:UInt
	Field scancode:Int
	Field keycode:UInt
	Field modifiers:Int
	Field repeated:Int
End Type

Rem
bbdoc: Mouse motion/button data. Positions and deltas use SDL window coordinates; button uses SDL numbering.
End Rem
Type TSDLMouseEvent Extends TSDLInputEvent
	Field mouseID:UInt
	Field x:Float
	Field y:Float
	Field dx:Float
	Field dy:Float
	Field buttons:UInt
	Field button:Int
	Field clicks:Int
End Type

Rem
bbdoc: Raw SDL wheel values and pointer position. direction is SDL mouse-wheel direction (0 normal, 1 flipped).
End Rem
Type TSDLMouseWheelEvent Extends TSDLInputEvent
	Field mouseID:UInt
	Field x:Float
	Field y:Float
	Field mouseX:Float
	Field mouseY:Float
	Field direction:Int
End Type

Rem
bbdoc: Full-width touch identifiers and normalized position/deltas/pressure. canceled marks a cancellation delivered as EVENT_TOUCHUP.
End Rem
Type TSDLTouchEvent Extends TSDLInputEvent
	Field touchID:ULong
	Field fingerID:ULong
	Field x:Float
	Field y:Float
	Field dx:Float
	Field dy:Float
	Field pressure:Float
	Field canceled:Int
End Type

Rem
bbdoc: Copied committed text. Each legacy UTF-16 KEYCHAR for the commit shares this payload.
End Rem
Type TSDLTextInputEvent Extends TSDLInputEvent
	Field text:String
End Type

Rem
bbdoc: Copied dropped text and its floating-point SDL window coordinates.
End Rem
Type TSDLTextDropEvent Extends TSDLInputEvent
	Field text:String
	Field x:Float
	Field y:Float
End Type

Private
Function _InputKeyboard:TSDLKeyboardEvent(windowID:UInt, timestamp:ULong, keyboardID:UInt, scancode:Int, keycode:UInt, modifiers:Int, repeated:Int)
	Local value:TSDLKeyboardEvent = New TSDLKeyboardEvent
	value.windowID = windowID
	value.timestamp = timestamp
	value.keyboardID = keyboardID
	value.scancode = scancode
	value.keycode = keycode
	value.modifiers = modifiers
	value.repeated = repeated
	Return value
End Function

Function _InputMouse:TSDLMouseEvent(windowID:UInt, timestamp:ULong, mouseID:UInt, x:Float, y:Float, dx:Float, dy:Float, buttons:UInt, button:Int, clicks:Int)
	Local value:TSDLMouseEvent = New TSDLMouseEvent
	value.windowID = windowID
	value.timestamp = timestamp
	value.mouseID = mouseID
	value.x = x
	value.y = y
	value.dx = dx
	value.dy = dy
	value.buttons = buttons
	value.button = button
	value.clicks = clicks
	Return value
End Function

Function _InputWheel:TSDLMouseWheelEvent(windowID:UInt, timestamp:ULong, mouseID:UInt, x:Float, y:Float, mouseX:Float, mouseY:Float, direction:Int)
	Local value:TSDLMouseWheelEvent = New TSDLMouseWheelEvent
	value.windowID = windowID
	value.timestamp = timestamp
	value.mouseID = mouseID
	value.x = x
	value.y = y
	value.mouseX = mouseX
	value.mouseY = mouseY
	value.direction = direction
	Return value
End Function

Function _InputTouch:TSDLTouchEvent(windowID:UInt, timestamp:ULong, touchID:ULong, fingerID:ULong, x:Float, y:Float, dx:Float, dy:Float, pressure:Float, canceled:Int)
	Local value:TSDLTouchEvent = New TSDLTouchEvent
	value.windowID = windowID
	value.timestamp = timestamp
	value.touchID = touchID
	value.fingerID = fingerID
	value.x = x
	value.y = y
	value.dx = dx
	value.dy = dy
	value.pressure = pressure
	value.canceled = canceled
	Return value
End Function

Function _InputTextInput:TSDLTextInputEvent(windowID:UInt, timestamp:ULong, text:String)
	Local value:TSDLTextInputEvent = New TSDLTextInputEvent
	value.windowID = windowID
	value.timestamp = timestamp
	value.text = text
	Return value
End Function

Function _InputTextDrop:TSDLTextDropEvent(windowID:UInt, timestamp:ULong, text:String, x:Float, y:Float)
	Local value:TSDLTextDropEvent = New TSDLTextDropEvent
	value.windowID = windowID
	value.timestamp = timestamp
	value.text = text
	value.x = x
	value.y = y
	Return value
End Function

Function _WheelEvent(payload:TSDLMouseWheelEvent)
	EmitEvent(CreateEvent(EVENT_SDL3_MOUSE_WHEEL, Null, Int(payload.windowID), 0, 0, 0, payload))
End Function

Function _TextDropEvent(payload:TSDLTextDropEvent)
	EmitEvent(CreateEvent(EVENT_SDL3_TEXT_DROP, Null, Int(payload.windowID), 0, Int(payload.x), Int(payload.y), payload))
End Function
Public
