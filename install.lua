-- Base OS installer / updater
-- In game: wget run https://raw.githubusercontent.com/Mattssn/base-os/main/install.lua
--
-- Downloads everything under src/ in the repo onto this computer, then reboots.
-- Your settings (baseos.text_scale etc.) are kept.
--
-- Speaker computer (plays Base OS music over a wireless modem, see speaker/):
--   wget run https://raw.githubusercontent.com/Mattssn/base-os/main/install.lua speaker

local REPO = "Mattssn/base-os"
local BRANCH = "main"

-- `wget run <url> speaker` passes the url first, so look at every argument
local speakerMode = false

for _, arg in ipairs({ ... }) do
    if arg == "speaker" then
        speakerMode = true
    end
end

local FOLDER = speakerMode and "speaker/" or "src/"
local NAME = speakerMode and "Base OS Speaker" or "Base OS"

if not http then
    error("HTTP is disabled on this server (CC:Tweaked config: http.enabled)", 0)
end

local function get(url)
    local response, err = http.get(url)

    if not response then
        error("Download failed: " .. url .. "\n" .. tostring(err), 0)
    end

    local body = response.readAll()
    response.close()

    return body
end

local function getJSON(url)
    return textutils.unserializeJSON(get(url))
end

--------------------------------------------------
-- FIND FILES
--------------------------------------------------

if speakerMode and fs.exists("/baseos") then
    printError("This computer runs Base OS.")
    print("A speaker computer replaces startup.lua, so Base OS would stop starting.")
    write("Install the speaker program anyway? (y/n) ")

    if read():lower():sub(1, 1) ~= "y" then
        return
    end
end

print(NAME .. " installer")
print("Fetching file list...")

-- Pin to the exact commit so GitHub's raw-file cache can't serve old files
local branch = getJSON("https://api.github.com/repos/" .. REPO .. "/branches/" .. BRANCH)
local commit = branch.commit.sha
local tree = getJSON("https://api.github.com/repos/" .. REPO .. "/git/trees/" .. commit .. "?recursive=1")

local files = {}

for _, entry in ipairs(tree.tree) do
    if entry.type == "blob" and entry.path:sub(1, #FOLDER) == FOLDER then
        table.insert(files, entry.path)
    end
end

if #files == 0 then
    error("No files found in " .. REPO .. "/" .. FOLDER, 0)
end

--------------------------------------------------
-- DOWNLOAD
--------------------------------------------------

-- Remove the old install so deleted files don't linger
if not speakerMode and fs.exists("/baseos") then
    fs.delete("/baseos")
end

local raw = "https://raw.githubusercontent.com/" .. REPO .. "/" .. commit .. "/"

for i, path in ipairs(files) do
    local target = "/" .. path:sub(#FOLDER + 1)

    print(("[%d/%d] %s"):format(i, #files, target))

    local body = get(raw .. path)
    local dir = fs.getDir(target)

    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local file = fs.open(target, "w")
    file.write(body)
    file.close()
end

print("Installed " .. NAME .. " (" .. commit:sub(1, 7) .. ")")
print("Rebooting in 3s...")
sleep(3)
os.reboot()
