#!/usr/bin/osascript

-- stdout is sudo's password pipe; never print diagnostics or the dialog record.
on run argv
    set promptText to "enter your login password to authorize sudo."
    if (count of argv) > 0 then set promptText to item 1 of argv
    set reply to display dialog promptText with title "sudo authentication" default answer "" with hidden answer buttons {"cancel", "authenticate"} default button "authenticate" cancel button "cancel" giving up after 120
    if gave up of reply then error "authentication timed out" number -128
    return text returned of reply
end run
