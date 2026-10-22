#!/usr/bin/osascript

-- stdout is sudo's password pipe; never print diagnostics or the dialog record.
on run argv
    set sessionName to system attribute "SUDO_ASKPASS_SESSION"
    set commandText to system attribute "SUDO_ASKPASS_COMMAND"
    if sessionName is "" or commandText is "" then error "use sudo-ask with SUDO_ASKPASS_SESSION set to the current session name" number 1
    set promptText to "enter your login password to authorize sudo."
    if (count of argv) > 0 then set promptText to item 1 of argv
    set promptText to "session: " & sessionName & return & return & "command: " & commandText & return & return & promptText
    set reply to display dialog promptText with title "sudo authentication" default answer "" with hidden answer buttons {"cancel", "authenticate"} default button "authenticate" cancel button "cancel" giving up after 120
    if gave up of reply then error "authentication timed out" number -128
    return text returned of reply
end run
