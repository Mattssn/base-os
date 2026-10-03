-- Base OS: item flow (items per minute in/out of the ME system)
-- AP has no rate API, so this compares item counts now against ~one window ago.
-- It sees the net change per item: 100 in and 100 out of the same item in one window shows as 0.

local flow = {}

local SAMPLE_EVERY = 5 -- seconds between stored samples

local samples = {}
local lastSample = -math.huge
local names = {}

local function emptyResult(window)
    return {
        ready = false,
        elapsed = 0,
        window = window,
        totalIn = 0,
        totalOut = 0,
        incoming = {},
        outgoing = {}
    }
end

flow.result = emptyResult(60)

-- Item counts merged by registry name
local function countItems(items)
    local counts = {}
    local total = 0

    for _, item in ipairs(items) do
        local name = item.name or "unknown"
        local count = tonumber(item.count) or 0

        counts[name] = (counts[name] or 0) + count
        names[name] = item.displayName or name
        total = total + count
    end

    return counts, total
end

local function compute(base, now, window)
    local result = emptyResult(window)
    local elapsed = now.t - base.t

    result.elapsed = elapsed
    result.ready = elapsed >= window

    if elapsed <= 0 then
        return result
    end

    local scale = 60 / elapsed
    local seen = {}

    local function add(name)
        if seen[name] then
            return
        end

        seen[name] = true

        local delta = (now.counts[name] or 0) - (base.counts[name] or 0)

        if delta ~= 0 then
            local entry = { name = names[name] or name, rate = math.abs(delta) * scale }

            if delta > 0 then
                table.insert(result.incoming, entry)
                result.totalIn = result.totalIn + entry.rate
            else
                table.insert(result.outgoing, entry)
                result.totalOut = result.totalOut + entry.rate
            end
        end
    end

    for name in pairs(now.counts) do
        add(name)
    end

    for name in pairs(base.counts) do
        add(name)
    end

    local function byRate(a, b)
        return a.rate > b.rate
    end

    table.sort(result.incoming, byRate)
    table.sort(result.outgoing, byRate)

    return result
end

-- Call after every ME read. Returns the latest result (recomputed every SAMPLE_EVERY seconds).
function flow.update(s, window)
    if not (s.present and s.connected and s.online) then
        return flow.result
    end

    local t = os.clock()

    if t - lastSample < SAMPLE_EVERY then
        return flow.result
    end

    local counts, total = countItems(s.items)
    local previous = samples[#samples]

    -- An empty read right after a non-empty one is almost always a failed call, not
    -- the whole network emptying. Skip it instead of reporting a huge "out" spike.
    if total == 0 and previous and previous.total > 0 then
        return flow.result
    end

    lastSample = t

    local sample = { t = t, counts = counts, total = total }
    table.insert(samples, sample)

    -- Keep the newest sample that is at least `window` old as the baseline
    while #samples > 2 and t - samples[2].t >= window do
        table.remove(samples, 1)
    end

    flow.result = compute(samples[1], sample, window)

    return flow.result
end

return flow
