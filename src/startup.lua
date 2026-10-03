-- Base OS boot: runs the OS and restarts it if it crashes.
-- Typing `quit` (or Ctrl+T) in Base OS exits cleanly to the shell. Hold Ctrl+T to break out of a crash loop.

while true do
    if shell.run("/baseos/main.lua") then
        break
    end

    print("Base OS crashed. Restarting in 5s...")
    sleep(5)
end
