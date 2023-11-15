# autoripper
This script is meant to automate (as much as possible) the ripping of video discs (DVD + BluRay) into video files.

Ripping is done via MakeMKV. Encoding is done via Handbrake.

## Current Functionality
- Creates DVD backups using MakeMKV
- Automates encoding DVD backups via Handbrake

## Usage
Encode existing disc rip
```sh
preset_file="presets.json" preset_name="DS9DVDRIP" \
./autoripper.sh dvd.iso
```

Rip disc from drive
```sh
./autoripper.sh rip
```


## References
- [MakeMKV CLI docs](https://www.makemkv.com/developers/usage.txt)
