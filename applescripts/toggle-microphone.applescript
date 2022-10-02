# Toggles your current input device between 50% and 0% (mute)

on getMicrophoneVolume()
	input volume of (get volume settings)
end getMicrophoneVolume

on disableMicrophone()
	set volume input volume 0
end disableMicrophone

on enableMicrophone()
	set volume input volume 50
end enableMicrophone

if getMicrophoneVolume() is greater than 0 then
	disableMicrophone()
else
	enableMicrophone()
end if
