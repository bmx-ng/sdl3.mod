Import "host_win32.c"

Extern
	Function test_host_input(canvas:Byte Ptr,field:Byte Ptr)
	Function test_host_detached:Int(canvas:Byte Ptr)
End Extern

Function CheckHostInput(canvas:TGadget,field:TGadget)
	While PollEvent()
	Wend
	SetGadgetText(field,"")
	test_host_input(QueryGadget(canvas,QUERY_HWND),QueryGadget(field,QUERY_HWND))
	Delay(100)
	Local downs:Int,ups:Int,paints:Int
	While PollEvent()
		If EventSource()<>canvas Then Continue
		Select EventID()
			Case EVENT_MOUSEDOWN
				downs:+1
				Check(EventX()=37 And EventY()=49,"Native mouse coordinates changed")
			Case EVENT_MOUSEUP
				ups:+1
			Case EVENT_GADGETPAINT
				paints:+1
		End Select
	Wend
	Check(downs=1 And ups=1,"Native mouse events lost or duplicated: "+downs+", "+ups)
	Check(paints>0,"SDL consumed MaxGUI paint events")
	Check(GadgetText(field)="Z","Native text input was lost")
	SetGadgetText(field,"Native field survives attachment")
End Function
