SuperStrict

Framework SDL3.SDL3Test
Import BRL.StandardIO
Import "test_helpers.bmx"

Check AppArgs.Length = 2, "Pass the expected backend mask: X11=1, Wayland=2, KMSDRM=4"
Check probeVideoBackendMask() = Int(AppArgs[1]), "Unexpected compiled video backend set: " + probeVideoBackendMask()
Print "SDL3 Linux backend selection test passed"
