SuperStrict
Framework SDL3.SDL3AudioAudio
Import BRL.BankStream
Import BRL.StandardIO
If Not SetAudioDriver("SDL3") Then Throw SDL_GetError()
Local stream:TStream = CreateBankStream(CreateBank(44))
If LoadSound(stream, SOUND_STREAM) Then Throw "Unexpected fallback"
If Not SDL_GetError().Contains("No imported streaming decoder") Then Throw SDL_GetError()
SetAudioDriver("Null")
Print "Missing decoder correctly rejected"
