Import SDL3.SDL3MaxGUI
Import Max2D.SDL3GPUMax2D
Import SDL3.SDL3Timer
Import BRL.EventQueue
Import BRL.PNGLoader
?macos
Import "gpu_glue.m"
?win32 Or linux
Import "gpu_glue.c"
?

Extern
	Function test_gpu_output:Int(device:Byte Ptr,window:Byte Ptr,width:Int Var,height:Int Var)
	Function test_gpu_layers:Int(view:Byte Ptr)
End Extern

Function CanvasHandle:Byte Ptr(canvas:TGadget)
?macos
	Return QueryGadget(canvas,QUERY_NSVIEW_CLIENT)
?win32
	Return QueryGadget(canvas,QUERY_HWND)
?linux
	Return gdk_x11_window_get_xid(gtk_widget_get_window(TGTKGadget(canvas).handle))
?
End Function

?win32
Include "host_win32.bmx"
?linux
Include "host_linux.bmx"
?

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

Check(SystemDriver().Name()<>"SDL3SystemDriver","Native host driver was replaced")
Local window:TGadget=CreateWindow("SDL3 attachment tests",100,100,500,360,Null,WINDOW_TITLEBAR|WINDOW_CLIENTCOORDS)
Local field:TGadget=CreateTextField(10,10,400,28,window)
SetGadgetText(field,"Native field survives attachment")
Local canvas:TGadget=CreateCanvas(10,50,320,240,window)
Local graphics:TGraphics=CanvasGraphics(canvas)
Local second:TGadget=CreateCanvas(350,50,130,150,window)
Local secondGraphics:TGraphics=CanvasGraphics(second)
Check(secondGraphics<>Null,"Second canvas attachment failed")
Check(graphics<>Null,"AttachGraphics failed: "+SDL_GetError())
?win32 Or linux
CheckHostInput(canvas,field)
?
For Local cycle:Int=0 Until 3
	If cycle Then
		CloseGraphics(graphics)
?win32
		Check(test_host_detached(QueryGadget(canvas,QUERY_HWND)),"Canvas was destroyed or hook leaked after detach")
?linux
		Check(test_host_detached(TGTKGadget(canvas).handle),"GTK canvas destroyed or attachment leaked after detach")
?
?macos
		Check(test_gpu_layers(CanvasHandle(canvas))=0,"GPU view leaked after detach")
?
		graphics=AttachGraphics(CanvasHandle(canvas),0)
		Check(graphics<>Null,"Reattachment failed")
	End If
?macos
	Check(test_gpu_layers(CanvasHandle(canvas))=1,"Canvas must own one Metal view")
?
	SetGadgetShape(canvas,10,50,320-cycle*40,240-cycle*30)
	PollSystem()
	SetGraphics(graphics)
	Print "Cycle "+cycle+" gadget "+GadgetWidth(canvas)+","+GadgetHeight(canvas)+" graphics "+GraphicsWidth()+","+GraphicsHeight()
	Check(GraphicsWidth()=ClientWidth(canvas),"Canvas logical width did not follow gadget")
	Check(GraphicsHeight()=ClientHeight(canvas),"Canvas logical height did not follow gadget")
	SetClsColor(20,30,40)
	Cls
	SetColor(240,100,30)
	DrawRect(0,0,GraphicsWidth(),GraphicsHeight())
	FlushMax2D()
	Local w:Int=NativeResolutionWidth(),h:Int=NativeResolutionHeight()
	Local rw:Int,rh:Int
	Check(test_gpu_output(TSDLGPUMax2DContext(TMax2DGraphics.Current().context).GetGPUDevice(),TSDLGraphics(TMax2DGraphics.Current().context.graphics)._context.window.windowPtr,rw,rh),"Could not query drawable size")
	Check(rw=w And rh=h,"GPU swapchain output does not match canvas pixel size")
	Check(Not TMax2DGraphics.Current().context.SupportsFullscreen(),"Attached canvas advertised fullscreen")
	Check(Not TMax2DGraphics.Current().context.SupportsBorderlessFullscreen(),"Attached canvas advertised borderless fullscreen")
	Local pixels:TPixmap=TMax2DGraphics.Current().context.Read(Null,0,0,w,h)
	Check(pixels<>Null,"Canvas readback failed")
	Check(pixels.width=w And pixels.height=h,"Canvas drawable dimensions differ from native dimensions")
	Check((ReadPixel(pixels,w-2,h-2)&$FFFFFF)=$F0641E,"Drawing did not reach the resized canvas edge")
?macos
	If cycle=0 Then SavePixmapPNG(pixels,"/tmp/sdl3-attached-gpu-canvas.png")
?
	Local target:TRenderImage=CreateRenderImage(32,32,0)
	SetRenderImage(target)
	SetClsColor(10,220,90)
	Cls
	SetRenderImage(Null)
	SetColor(255,255,255)
	DrawImage(target,0,0)
	Check((GrabPixmap(4,4,1,1).ReadPixel(0,0)&$FFFFFF)=$0ADC5A,"Render image did not draw into attached GPU canvas")
	target.ReleaseFrames()
	Flip(0)
	Flip(1)
	Flip(0)
	Check(GadgetText(field)="Native field survives attachment","Native field was changed")
Next
SetGraphics(secondGraphics)
SetClsColor(40,180,80)
Cls
Flip(0)
Check(GraphicsWidth()=ClientWidth(second),"Second canvas affected by first canvas reattachment")
CloseGraphics(secondGraphics)
' No native timer drives this wait: only queued SDL timer events can complete it.
While PollEvent()
Wend
Local timer:TTimer=TSDLTimer.Create(20)
Local ticks:Int
While ticks<3
	If WaitEvent()=EVENT_TIMERTICK And EventSource()=timer Then ticks:+1
Wend
StopTimer(timer)
CloseGraphics(graphics)
?macos
Check(test_gpu_layers(CanvasHandle(canvas))=0,"GPU view leaked on shutdown")
?
?win32
Check(test_host_detached(QueryGadget(canvas,QUERY_HWND)),"Canvas was destroyed or hook leaked on shutdown")
?linux
Check(test_host_detached(TGTKGadget(canvas).handle),"GTK canvas destroyed or attachment leaked on shutdown")
?
FreeGadget(window)
Print "SDL3 GPU MaxGUI attachment, resize, readback, reattachment and timer wake tests passed"
