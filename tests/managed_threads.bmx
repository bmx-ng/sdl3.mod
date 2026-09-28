SuperStrict

Framework SDL3.SDL3Thread
Import BRL.Threads
Import BRL.StandardIO
Import "test_helpers.bmx"

Global threadData:TThreadData = CreateThreadData()

Function worker:Object(data:Object)
	Check GCThreadIsRegistered(), "SDL3 thread is not registered with the GC"
	threadData.SetValue(data)
	Check threadData.GetValue() = data, "BlitzMax thread-local storage is unavailable"
	For Local i:Int = 0 Until 100
		Local value:String = String(data) + String(i)
		Check value.Length > 0
	Next
	GCCollect()
	Return data
End Function

Function failingWorker:Object(data:Object)
	Throw "worker error"
End Function

Function detachedWorker:Object(data:Object)
	Delay(20)
	TThreadEvent(data).Set()
End Function

Local threads:TSDLThread[8]
For Local i:Int = 0 Until threads.Length
	threads[i] = TSDLThread.Create(worker, String(i), "sdl3-gc-test")
	Check threads[i], SDL_GetError()
Next
GCCollect()
For Local i:Int = 0 Until threads.Length
	Check String(threads[i].Wait()) = String(i)
Next

Local failure:TSDLThread = TSDLThread.Create(failingWorker)
Check failure, SDL_GetError()
Local caught:Int
Try
	failure.Wait()
Catch error:Object
	caught = String(error) = "worker error"
End Try
Check caught, "Worker exception was not reported on Wait"

Local done:TThreadEvent = New TThreadEvent
Local detached:TSDLThread = TSDLThread.Create(detachedWorker, done)
Check detached, SDL_GetError()
detached.Detach()
Local refusedWait:Int
Try
	detached.Wait()
Catch error:Object
	refusedWait = True
End Try
Check refusedWait, "Wait accepted a detached thread"
detached = Null
GCCollect()
Check done.Wait(2000), "Detached worker did not finish"
Print "SDL3 managed thread test passed"
