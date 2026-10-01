Import "host_linux.c"

Extern
	Function test_host_present(canvas:Byte Ptr)
	Function test_host_input(canvas:Byte Ptr,field:Byte Ptr)
	Function test_host_detached:Int(canvas:Byte Ptr)
End Extern

Function CheckHostInput(canvas:TGadget,field:TGadget)
	test_host_present(TGTKGadget(canvas).handle)
	For Local i:Int=0 Until 20
		PollSystem()
		Delay(10)
	Next
	While PollEvent()
	Wend
	SetGadgetText(field,"")
	test_host_input(TGTKGadget(canvas).handle,TGTKGadget(field).handle)
	Local downs:Int,ups:Int,paints:Int
	Local deadline:Int=MilliSecs()+500
	Repeat
		While PollEvent()
			If EventSource()<>canvas Then Continue
			Select EventID()
				Case EVENT_MOUSEDOWN
					downs:+1
					Check(EventX()=37 And EventY()=49,"Native GTK mouse coordinates changed")
				Case EVENT_MOUSEUP
					ups:+1
				Case EVENT_GADGETPAINT
					paints:+1
			End Select
		Wend
		Delay(5)
	Until MilliSecs()>=deadline
	Check(downs=1 And ups=1,"Native GTK mouse events lost or duplicated: "+downs+", "+ups)
	Check(paints>0,"GTK canvas paint events were lost")
	Check(GadgetText(field)="z","Native GTK text input was lost")
	SetGadgetText(field,"Native field survives attachment")
End Function
