# HairColourSyncNg
A SKSE64 NG plugin for SSE/AE that synchronizes wig color to its wearer's hair color.
Mod released on [Nexus](https://www.nexusmods.com/skyrimspecialedition/mods/156414)

Ported from [Hair Colour Sync](https://github.com/jgernandt/skyrim-hair-colour-sync) created by [jgernandt](https://github.com/jgernandt) under [MIT license](https://github.com/jgernandt/skyrim-hair-colour-sync/blob/main/LICENSE).

## Build Dependencies
- [CommonLibSSE-NG](https://github.com/alandtse/CommonLibSSE-NG) v11.0.0 (`94faaed0c60eddd8347767f2d4d29a97c93bde8c`), which parses Address Library format 5 and knows runtime 1.7.104.0 by version, not by a hardcoded hook address.
- Windows build: `HairColourSyncNg.vcxproj` (v143, x64, dynamic CRT, static vcpkg libs) pointed at that CommonLib.
- Linux cross build: `CMakeLists.txt` with the CommonLib v11 `clang-cl` + `xwin` toolchain. See `scripts/build-linux-clangcl.sh`.

This fork rebuilds upstream v1.3.1 (`52c51282b2ff61ae06167e3aa2560d97d95f2c3f`) so SMP wigs can be recolored on Skyrim SE 1.7.104.0. The armor hook bytes are checked at runtime and were not disassembled here. Treat the DLL as experimental until it is tried in game.

## License
The plugin source in this repository stays under the MIT License - see [LICENSE.txt](LICENSE.txt).

CommonLibSSE-NG v11 is GPL-3.0-or-later with its Modding Exception and Linking Exception. A DLL that statically links it is a combined work and is conveyed under GPL-3.0-or-later. Corresponding source is this repository plus CommonLibSSE-NG commit `94faaed0c60eddd8347767f2d4d29a97c93bde8c`.

## Credits
- jgernandt for their orginal mod on [Nexus](https://www.nexusmods.com/skyrimspecialedition/mods/121751)
- [Ryan McKenzie](https://github.com/Ryan-rsm-McKenzie) for the [commonlibSSE](https://github.com/Ryan-rsm-McKenzie/CommonLibSSE)
- [Ianpatt et al.](https://github.com/ianpatt) for the [SKSE64](https://github.com/ianpatt/skse64)
- [meh321](https://github.com/meh321) for the [AddressLib](https://www.nexusmods.com/skyrimspecialedition/mods/32444)

## Update log
- [Aug.7.2025] 1.0.1: Initial release

### Special Thanks
Discord user [Kira]() & [某時]() for testing the mod.
