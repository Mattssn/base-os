# Advanced Peripherals: 1.21.1 notes

Source: https://docs.advanced-peripherals.de/0.7/

## ⚠ The type names changed in 1.21.1
In 1.21.1, every peripheral type name changed from camelCase to **snake_case**. Older scripts break because `peripheral.find("meBridge")` now returns nil.

| Block | ≤1.20.1 | **1.21.1** |
|---|---|---|
| ME Bridge | meBridge | `me_bridge` |
| RS Bridge | rsBridge | `rs_bridge` |
| Player Detector | playerDetector | `player_detector` |
| Chat Box | chatBox | `chat_box` |
| Environment Detector | environmentDetector | `environment_detector` |
| Inventory Manager | inventoryManager | `inventory_manager` |
| Energy Detector | energyDetector | `energy_detector` |
| Geo Scanner | geoScanner | `geo_scanner` |
| Block Reader | blockReader | `block_reader` |
| Redstone Integrator | redstoneIntegrator | **removed** in 1.21.1-0.7.50b. Use CC:T's `redstone_relay` instead |

Other peripherals: NBT Storage, Colony Integrator (MineColonies), AR Controller.
Turtle upgrades: Chatty, Chunky, Environment, Player, Geoscanning, Metaphysics (Weak/Husbandry/End/Overpowered Automata).
Directions can be relative (`left`, `front`...) or cardinal (`north`, `up`...).

## ME Bridge (`me_bridge`) + RS Bridge (`rs_bridge`): 1.21.1 API
Source: https://docs.advanced-peripherals.de/0.7/guides/storage_system_functions/
Item/stack fields: https://docs.advanced-peripherals.de/0.7/guides/objects/

> ⚠ The per-peripheral pages (`/peripherals/me_bridge/`, `/peripherals/rs_bridge/`) default to the
> **legacy 1.20.1 tab** (`listItems`, `listCells`, `getEnergyStorage`, `crafting` event...). On 1.21.1 both bridges use
> the shared "storage system" API below instead.

**Status:** `isConnected()`, `isOnline()`

**Read** (filter `{}` = everything; returns `table | nil, err`):
`getItem(f)`, `getFluid(f)`, `getChemical(f)`, `getItems(f)`, `getFluids(f)`, `getChemicals(f)`,
`getCraftableItems(f)`, `getCraftableFluids(f)`, `getCraftableChemicals(f)`, `getCells()`, `getDrives()`
- Item stack fields: `name`, `count`, `displayName`, `isCraftable`, … (it's **`count`**, not `amount`)

**Move** (target = a direction OR a peripheral name on the network; default 64 items / 1000 mB, override with `count`):
`importItem(f, target)`, `exportItem(f, target)`, `importFluid`, `exportFluid`, `importChemical`, `exportChemical`
- The inventory you move items to or from must be next to the **bridge**, not the computer.

**Energy:** `getStoredEnergy()`, `getEnergyCapacity()`, `getEnergyUsage()`, `getAvgPowerInjection()` (ME only)

**Storage.** Internal is in **bytes for AE2** and items for RS. External (storage bus) is in **items** (or mB):
- `getTotal/Used/Available` + `ItemStorage | FluidStorage | ChemicalStorage`
- `getTotal/Used/Available` + `ExternItemStorage | ExternFluidStorage | ExternChemicalStorage` (the RS bridge doesn't support external storage yet)

**Crafting** (runs async):
- `craftItem(f)`, `craftFluid(f)`, `craftChemical(f)` return a Crafting Job object, or `nil, err`
- `getCraftingTasks()`, `getCraftingJob(id)`, `cancelCraftingTasks(f)`, `getPatterns({input=?, output=?})`, `isCraftable(f)`, `isCrafting(f)`
- `getCraftingCPUs()` (AE2): `{storage, coProcessors, isBusy, craftingJob, name, selectionMode}`
- Event: `me_crafting` / `rs_crafting` gives you `(error, id, debug_message)`. The messages include `CRAFTING_STARTED`, `MISSING_ITEMS`, …
- Job object methods: `getId isDone isCanceled isCraftingStarted isCalculationStarted isCalculationNotSuccessful hasErrorOccurred getDebugMessage getRequestedItem getElapsedTime getTotalItems getItemProgress getEmittedItems getUsedItems getMissingItems hasMultiplePaths getFinalOutput cancel getUsedBytes`
- Job details (from getCraftingTasks): `bridge_id, id, quantity, resource, completion (0-1), crafted, cpu`

**AE2 cell** (getCells): `item, usedBytes, totalBytes (types, usually 63), bytes, bytesPerType, type, fuzzyMode`

## Player Detector (`player_detector`)
- `getOnlinePlayers()`, `getPlayerPos(name)` (returns pos, health and rotation, or nil)
- `getPlayersInRange(r)`, `isPlayerInRange(r, name)`, `isPlayersInRange(r)`
- `getPlayersInCoords(p1, p2)`, `isPlayerInCoords(p1, p2, name)`, `getPlayersInCubic(w,h,d)`, `isPlayerInCubic(w,h,d)`
- Events: `playerClick(user, device)`, `playerJoin(user, dim)`, `playerLeave(user, dim)`, `playerChangedDimension(user, from, to)`
- Ranges are limited by server config (`playerDetMaxRange`, `playerDetMultiDimensional`)

## Chat Box (`chat_box`)
- `sendMessage(msg, [prefix, brackets, bracketColor, range, utf8])`
- `sendMessageToPlayer(msg, user, ...)`, `sendToastToPlayer(msg, title, user, ...)`
- `sendFormattedMessage(json, ...)`, `sendFormattedMessageToPlayer(json, user, ...)`, `sendFormattedToastToPlayer(msgJson, titleJson, user, ...)`
- Returns `true` or `nil, err`. Calls have a cooldown.
- Event: `chat(username, message, uuid, isHidden, messageUtf8)`. A message that starts with `$` fires the event but stays out of public chat, which makes it useful for commands.

## Environment Detector (`environment_detector`)
`getBiome`, `getBlockLightLevel`, `getDayLightLevel`, `getSkyLightLevel`, `getDimension`, `getDimensionPaN`, `getDimensionProvider`, `getMoonId`, `getMoonName`, `getTime`, `getRadiation`, `getRadiationRaw`, `isDimension(d)`, `isMoon(id)`, `isRaining`, `isSunny`, `isThunder`, `isSlimeChunk`, `listDimensions`, `scanEntities(range)`

## Inventory Manager (`inventory_manager`)
Needs a Memory Card that is bound to a player.
`addItemToPlayer(dir, item)`, `removeItemFromPlayer(dir, item)`, `getArmor`, `getItems`, `getOwner`, `isPlayerEquipped`, `isWearing(slot)`, `getItemInHand`, `getItemInOffHand`, `getFreeSlot`, `isSpaceAvailable`, `getEmptySpace`

## Energy Detector (`energy_detector`)
`getTransferRate()`, `getTransferRateLimit()`, `setTransferRateLimit(n)`. It measures FE flow and can also cap it.

## Geo Scanner (`geo_scanner`)
`scan(radius)` returns a list of `{name, tags, x, y, z}`, or `nil, err`. Also `chunkAnalyze()` (ore counts), `cost(radius)` and `getMaxFuelLevel()`. Scans have a cooldown.

## Block Reader (`block_reader`)
`getBlockName()`, `getBlockData()` (NBT table or nil), `getBlockStates()`, `isTileEntity()`

## Integrations (generic methods added to other mods' blocks)
Vanilla (Beacon, Note Block), Botania (flowers, mana pool, spreader), Create (basin, blaze burner, tank, mixer, scroll-value blocks), Draconic Evolution, Immersive Engineering, Integrated Dynamics, Mekanism, Powah, Storage Drawers.
