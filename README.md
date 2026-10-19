# Lake Gang

A Warhammer 40,000: Darktide mod that plays "Lake Gang 1" or "Lake Gang 2" when your Psyker quells peril (holds Reload).

By default it only plays while quelling with **Assail**. Every Psyker weapon and blitz can be turned on or off in the mod options.

## Requirements

- [Darktide Mod Loader](https://www.nexusmods.com/warhammer40kdarktide/mods/19)
- [Darktide Mod Framework](https://www.nexusmods.com/warhammer40kdarktide/mods/8)

No other mods are needed. Sounds are played through Windows' built-in audio API.

## Installation

1. Put this folder in `Warhammer 40,000 DARKTIDE\mods\` and name it `LakeGang`, for example:
   ```
   git clone https://github.com/JustMarkDev/LakeGang.git
   ```
   run from inside the `mods` folder.
2. Add `LakeGang` on its own line in `mods\mod_load_order.txt`.

## Options

Found in **Mod Options → Lake Gang**:

| Option | Default | Description |
|---|---|---|
| Play when quelling with | Assail only | Assail, Force swords, Force greatswords, Force staffs, Brain Burst, Smite |
| Playback mode | Random | Random, or Alternate (1, 2, 1, 2…) |
| Volume | 100 | Also scaled by the game's Master and Sound Effects volume |
| Stop when quelling ends | Off | Cut the sound off when you release Reload |
| Debug logging | On | Write each quell and sound to the game's console log |

Type `/lakegang` in chat to play a sound for testing.

## Troubleshooting

Logs are in `%APPDATA%\Fatshark\Darktide\console_logs`. Search the newest file for `[MOD][LakeGang]`.

## Custom sounds

Replace `audio/lake_gang_1.wav` and `audio/lake_gang_2.wav` with your own WAV files, keeping the same names. Opus and other compressed formats aren't supported by the Windows audio API the mod uses.
