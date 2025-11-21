-- AppleScript Test for Floating Window Functionality
-- This script tests the three bug fixes for Flow app's floating window

tell application "System Events"
    -- Test Setup
    set testResults to ""
    
    -- Activate Flow app
    tell application "Flow" to activate
    delay 2
    
    -- Test 1: Check that app is running
    if application "Flow" is running then
        set testResults to testResults & "✓ Test 1: Flow app is running" & return
    else
        set testResults to testResults & "✗ Test 1: Flow app failed to start" & return
        return testResults
    end if
    
    -- Test 2: Start timer by clicking play button
    tell process "Flow"
        try
            set frontmost to true
            delay 1
            
            -- Look for the play/pause button (identified by "playpause" accessibility identifier)
            -- We'll try to click the center of the window first
            set windowPosition to position of window 1
            set windowSize to size of window 1
            set centerX to (item 1 of windowPosition) + ((item 1 of windowSize) / 2)
            set centerY to (item 2 of windowPosition) + ((item 2 of windowSize) / 2)
            
            set testResults to testResults & "✓ Test 2: Found Flow window" & return
        on error errMsg
            set testResults to testResults & "✗ Test 2: Could not interact with Flow window - " & errMsg & return
        end try
    end tell
    
    -- Test 3: Switch to another application (TextEdit or Finder)
    delay 1
    tell application "TextEdit" to activate
    delay 2
    
    -- Check if Flow floating window is visible
    tell process "Flow"
        try
            set windowCount to count of windows
            if windowCount > 0 then
                set testResults to testResults & "✓ Test 3: Floating window is visible (found " & windowCount & " window(s))" & return
            else
                set testResults to testResults & "✗ Test 3: No windows found when app is backgrounded" & return
            end if
        on error errMsg
            set testResults to testResults & "✗ Test 3: Error checking windows - " & errMsg & return
        end try
    end tell
    
    -- Test 4: Try to interact with floating window (drag test)
    delay 1
    tell process "Flow"
        try
            if (count of windows) > 0 then
                set floatingWindow to window 1
                set originalPosition to position of floatingWindow
                set testResults to testResults & "✓ Test 4: Can access floating window for drag test" & return
                
                -- Note: Actual dragging via AppleScript is complex
                -- This test just verifies the window is accessible
            else
                set testResults to testResults & "✗ Test 4: No floating window to test dragging" & return
            end if
        on error errMsg
            set testResults to testResults & "✗ Test 4: Error during drag test - " & errMsg & return
        end try
    end tell
    
    -- Return to Flow app
    delay 1
    tell application "Flow" to activate
    delay 1
    
    set testResults to testResults & return & "=== Test Summary ===" & return
    set testResults to testResults & "Manual verification still needed:" & return
    set testResults to testResults & "1. Timer stays visible when maximized and switching apps" & return
    set testResults to testResults & "2. Single-click does NOT expand (only expand button works)" & return
    set testResults to testResults & "3. Dragging works smoothly without disappearing" & return
    
    -- Display results
    display dialog testResults buttons {"OK"} default button "OK"
    
end tell
