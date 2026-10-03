# CC: Tweaked: 1.21.1 notes

Source: https://tweaked.cc/

## Globals
`_G colors/colours commands disk fs gps help http io keys multishell os paintutils parallel peripheral pocket rednet redstone settings shell term textutils turtle vector window`

## Modules (`require`)
`cc.audio.dfpwm cc.base64 cc.completion cc.expect cc.image.nft cc.pretty cc.require cc.shell.completion cc.strings`

## Peripherals
`command computer drive modem monitor printer redstone_relay speaker turtle_storage`

**Generic peripherals** work on any block from any mod that has storage:
- `inventory`: `size list getItemDetail getItemLimit pushItems pullItems`
- `fluid_storage`: `tanks pushFluid pullFluid`
- `energy_storage`: `getEnergy getEnergyCapacity`

## redstone_relay (new in 1.114)
It gives you redstone I/O on all 6 sides over a wired modem. It replaces AP's Redstone Integrator, which was removed in 1.21.1.
`getInput/getOutput/setOutput(side[,on])`, `getAnalogInput/getAnalogOutput/setAnalogOutput(side[,n])`, `getBundledInput/getBundledOutput/setBundledOutput(side[,mask])`

## Notes for an OS
- `peripheral.find(type)` / `peripheral.getNames()`. Listen for the `peripheral` and `peripheral_detach` events to support hot-plugging.
- Advanced computers and monitors give you colour and the `mouse_click` / `monitor_touch` events.
- `settings` persists to `/.settings`. Use it for the OS config.
- `startup.lua` (or `/startup/*.lua`) runs on boot.
- `window` + `multishell` let you run more than one program at once.
- You can override `os.pullEvent` to block Ctrl+T termination in an OS shell.
