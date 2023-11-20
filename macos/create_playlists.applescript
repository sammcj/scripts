tell application "Music"
    set playlistInfo to {}
    -- Get playlist names and their tracks in bulk
    repeat with plist in user playlists
        set plistName to name of plist
        set plistTracks to tracks of plist
        set trackInfoList to {}
        repeat with trk in plistTracks
            set end of trackInfoList to (name of trk) & " - " & (artist of trk) & " - " & (album of trk)
        end repeat
        set end of playlistInfo to {plistName, trackInfoList}
    end repeat

    -- Get loved tracks
    set lovedTracks to tracks whose loved is true
    set lovedTrackInfo to {}
    repeat with trk in lovedTracks
        set end of lovedTrackInfo to (name of trk) & " - " & (artist of trk) & " - " & (album of trk)
    end repeat
    set end of playlistInfo to {"Loved Tracks", lovedTrackInfo}

    return playlistInfo
end tell
