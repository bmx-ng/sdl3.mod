SuperStrict

' Tap or click a field to show the platform keyboard. This example demonstrates
' input type hints, committed Unicode text, IME composition and keyboard state.
Framework Max2D.SDL3RenderMax2D
Import BRL.Hook
Import BRL.PolledInput

Const SCREEN_WIDTH:Int = 800
Const SCREEN_HEIGHT:Int = 450
Const FIELD_X:Int = 120
Const FIELD_WIDTH:Int = 560
Const FIELD_HEIGHT:Int = 54

Global labels:String[3]
Global values:String[3]
Global inputTypes:Int[3]
Global capitalizations:Int[3]
Global composition:String
Global selected:Int = -1
Global touchPending:Int
Global touchX:Float
Global touchY:Float

labels[0] = "Name"
labels[1] = "Email"
labels[2] = "PIN"
inputTypes[0] = SDL_TEXTINPUT_TYPE_TEXT_NAME
inputTypes[1] = SDL_TEXTINPUT_TYPE_TEXT_EMAIL
' The field is invisible to the native control; Max2D draws the masked value.
' Visible mode avoids iOS suppressing secure-field changes before SDL receives them.
inputTypes[2] = SDL_TEXTINPUT_TYPE_NUMBER_PASSWORD_VISIBLE
capitalizations[0] = SDL_CAPITALIZE_WORDS
capitalizations[1] = SDL_CAPITALIZE_NONE
capitalizations[2] = SDL_CAPITALIZE_NONE

Function FieldY:Int(index:Int)
	Return 108 + index * 82
End Function

Function Masked:String(length:Int)
	Local result:String
	For Local i:Int = 0 Until length
		result :+ "*"
	Next
	Return result
End Function

Function UpdateInputArea()
	If selected < 0 Then Return
	Local shown:String = values[selected]
	If selected = 2 Then shown = Masked(shown.Length)
	Local cursor:Int = 110 + Int(TextWidth(shown))
	If cursor >= FIELD_WIDTH Then cursor = FIELD_WIDTH - 1
	SDLSetTextInputArea(FIELD_X, FieldY(selected), FIELD_WIDTH, FIELD_HEIGHT, cursor)
End Function

Function SelectField(index:Int)
	If index < 0 Or index >= values.Length Then
		selected = -1
		composition = ""
		SDLStopTextInput()
		Return
	End If
	selected = index
	composition = ""
	If SDLTextInputActive() Then
		' Change the keyboard properties before moving an already-focused editor.
		If Not SDLStartTextInput(inputTypes[index], capitalizations[index], index <> 2, False) Then Throw SDL_GetError()
		UpdateInputArea()
	Else
		UpdateInputArea()
		If Not SDLStartTextInput(inputTypes[index], capitalizations[index], index <> 2, False) Then Throw SDL_GetError()
	End If
End Function

Function InputHook:Object(id:Int, data:Object, context:Object)
	Local event:TEvent = TEvent(data)
	If Not event Then Return data
	If event.id = EVENT_SDL3_TEXT_EDITING Then
		Local editing:TSDLTextEditingEvent = TSDLTextEditingEvent(event.extra)
		If editing Then composition = editing.text
	Else If event.id = EVENT_TOUCHDOWN Then
		touchX = SCREEN_WIDTH * event.x / 10000.0
		touchY = SCREEN_HEIGHT * event.y / 10000.0
		touchPending = True
	End If
	Return data
End Function

Function HandlePress(x:Float, y:Float)
	For Local i:Int = 0 Until values.Length
		If x >= FIELD_X And x < FIELD_X + FIELD_WIDTH And y >= FieldY(i) And y < FieldY(i) + FIELD_HEIGHT Then
			SelectField(i)
			Return
		End If
	Next
	SelectField(-1)
End Function

?android Or ios
Graphics SCREEN_WIDTH, SCREEN_HEIGHT, 32, 0, GRAPHICS_FULLSCREEN_DESKTOP
?Not android And Not ios
Graphics SCREEN_WIDTH, SCREEN_HEIGHT
?
SetVirtualResolution SCREEN_WIDTH, SCREEN_HEIGHT, VIRTUAL_LETTERBOX
SetClsColor 20, 25, 36
SDLStopTextInput()
AddHook EmitEventHook, InputHook

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	?Not android And Not ios
	If MouseHit(1) Then HandlePress(MouseX(), MouseY())
	?
	If touchPending Then
		HandlePress(touchX, touchY)
		touchPending = False
	End If

	If selected >= 0 Then
		Local character:Int = GetChar()
		While character
			composition = ""
			Select character
				Case 8, 127
					If values[selected].Length Then values[selected] = values[selected][..values[selected].Length - 1]
				Case 13
					If selected + 1 < values.Length Then SelectField(selected + 1) Else SelectField(-1)
					Exit
				Default
					If character >= 32 Then values[selected] :+ Chr(character)
			End Select
			UpdateInputArea()
			character = GetChar()
		Wend
	End If

	Cls
	SetColor 255, 255, 255
	DrawText "On-screen keyboard and text input", FIELD_X, 42
	SetColor 165, 176, 196
	DrawText "Tap a field. Return advances; tap outside to dismiss.", FIELD_X, 68

	For Local i:Int = 0 Until values.Length
		Local y:Int = FieldY(i)
		If i = selected Then SetColor 52, 128, 210 Else SetColor 48, 57, 75
		DrawRect FIELD_X, y, FIELD_WIDTH, FIELD_HEIGHT
		SetColor 177, 190, 213
		DrawText labels[i], FIELD_X + 14, y + 8
		SetColor 255, 255, 255
		Local shown:String = values[i]
		If i = 2 And shown.Length Then shown = Masked(shown.Length)
		If i = selected And composition Then shown :+ " [" + composition + "]"
		DrawText shown, FIELD_X + 110, y + 19
	Next

	SetColor 165, 176, 196
	Local status:String = "Text input: " + SDLTextInputActive()
	If SDLHasScreenKeyboardSupport() Then status :+ "   Keyboard shown: " + SDLScreenKeyboardShown()
	DrawText status, FIELD_X, 375
	Flip
Wend

RemoveHook EmitEventHook, InputHook
SDLStopTextInput()
EndGraphics
