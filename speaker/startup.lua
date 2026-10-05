-- Base OS speaker computer boot: runs the speaker program and restarts it if it crashes.
-- Ctrl+T stops it (hold Ctrl+T to break out of a crash loop).

while true do
    if shell.run("/speaker.lua") then
        break
    end

    print("Speaker crashed. Restarting in 5s...")
    sleep(5)
end
