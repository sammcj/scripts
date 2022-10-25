(* How to use this script:

This script will split the selection into two albums -
- one album with pictures with the largest dimension smaller or equal than the given pixel size
- one album with pictures with the largest dimension larger than the given pixel size (disabled)

Open this script in Script Editor. Launch Photos.
Select the Photos you want to distribute between the albums.

When all all photo are selected, press the "Run" button in Script Editor.

Original Author: léonie
*)

set defaultSizeThreshold to 75 -- change this to the pixel size threshold  you want for a photo to be counted as small

set dialogResult to display dialog ¬
	"Enter the pixel size threshold for small photos: " buttons {"Cancel", "OK"} ¬
	default answer (defaultSizeThreshold as text)
set AspectRatioThreshold to (text returned of dialogResult) as integer


set smallAlbumName to "smallerThan" & AspectRatioThreshold -- the album to collect the small photos

-- set largeAlbumName to "largerThan" & AspectRatioThreshold -- the album to collect the larger photosphotos

tell application "Photos"
	activate
	-- Ensure that the albums do exist

	try
		if not (exists container smallAlbumName) then
			make new album named smallAlbumName
		end if
		set theSmallAlbum to container smallAlbumName

		-- if not (exists container largeAlbumName) then
		-- 	make new album named largeAlbumName
		-- end if
		-- set theLargeAlbum to container largeAlbumName

		if not (exists container "SkippedPhotos") then
			make new album named "SkippedPhotos"
		end if
		set theSkippedAlbum to container "SkippedPhotos"


	on error errTexttwo number errNumtwo
		display dialog "Cannot open albums: " & errNumtwo & return & errTexttwo
	end try

	-- process the selected photos from the All Photos album
	try
		set imageSel to (get selection)
	on error errTexttwo number errNumtwo
		display dialog "Cannot get the selection: " & errNumtwo & return & errTexttwo
	end try

	set smallPhotos to {} -- the list of small photos
	set largePhotos to {} -- the list of larger photos
	set skippedPhotos to {} -- the list of skipped  photos


	--	check, if the album or the selected photos do contain images

	if imageSel is {} then
		error "Please select some images."
	else
		repeat with im in imageSel
			try

				tell im --get the pixel size
					set h to its height
					set w to its width
				end tell
			on error errText number errNum
				display dialog "Error: " & errNum & return & errText & "Trying again"
				try
					delay 2
					tell im
						set h to its height
						set w to its width
					end tell
				on error errTexttwo number errNumtwo
					display dialog "Skipping image due to repeated error: " & errNumtwo & return & errTexttwo
				end try

			end try
			set noDimensions to (w is missing value) or (h is missing value)
			if noDimensions then
				set skippedPhotos to {im} & skippedPhotos
			else
				if (w ≤ h) then
					set largestDimension to h
				else
					set largestDimension to w

				end if
				if (largestDimension ≤ AspectRatioThreshold) then
					set smallPhotos to {im} & smallPhotos
				else
					-- set largePhotos to {im} & largePhotos

				end if
			end if

		end repeat

		add smallPhotos to theSmallAlbum
		-- add largePhotos to theLargeAlbum
		add skippedPhotos to theSkippedAlbum

		return "small photos: " & (length of smallPhotos) & ", skipped: " & (length of skippedPhotos)
		-- return "small photos: " & (length of smallPhotos) & ", larger photos : " & (length of largePhotos) & ", skipped: " & (length of skippedPhotos)

	end if

end tell
