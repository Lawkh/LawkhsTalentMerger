# Lawkh's Talent Merger

Find and manage duplicate talent loadouts in World of Warcraft Retail.

Lawkh's Talent Merger compares selected talents and ranks, including Hero Talents, and groups identical loadouts using matching colors. The same colors appear in the talent loadout dropdown.

## Features

- **Merge:** choose a duplicate group and enter a name for the resulting loadout. The addon suggests a combined name such as `Raid/Mythic+/PvP`. It renames the first loadout and removes the other identical copies, preserving the first loadout's settings.
- **Clean:** review exactly which loadouts will be kept and deleted. The first loadout in each duplicate group is kept, along with all unique loadouts.
- **Nuke:** review saved loadouts in separate specialization columns, each with its own icon and scrolling list. Select one or more specializations to delete only their saved loadouts; unchecked specializations are preserved. No specialization is selected by default. Type exactly `NUKE` to confirm. Changing the selection clears the confirmation word. Active talents are not reset.
- **One window:** the list, previews, confirmations, progress and errors share the same window.
- **Controlled deletion:** loadouts are deleted one at a time, waiting for WoW confirmation. Additional operations are blocked while deletion is in progress. Use **Stop** to stop further requests.
- **Checks before changing loadouts:** operations are blocked during combat, while dead or a ghost, and while talent changes are pending. The confirmed loadouts are checked again before each deletion.
- **Backups:** original names, specializations and talent export strings are saved for the last 10 operations. Backups can be recovered manually from the character's SavedVariables and imported through WoW's talent interface. There is currently no in-game restore screen.

## How to use

Open the talent loadout dropdown to access **Merge**, **Nuke** and **Clean**, or type `/tm` to open the addon window. Labels are translated to your client's language.

Commands: `/tm`, `/lawkhtm`, `/tm merge`, `/tm clean`, `/tm nuke`, `/tm status`.

## Languages

English, Spanish, German, French, Italian, Brazilian Portuguese, Russian, Korean, Simplified Chinese and Traditional Chinese. The interface automatically follows your WoW client language. Loadout names and the `NUKE` confirmation word are preserved.

## Compatibility and removal

Targets **WoW Retail 12.1.0**. No external libraries are required. TalentTreeTweaks and RaiderIO are optional, not required dependencies.

Disable the addon or remove its `LawkhsTalentMerger` folder and reload the UI. Removing the addon does not undo loadouts you have already renamed or deleted. WoW writes backup SavedVariables when you log out or reload the UI.

Source code and issue reports: [GitHub](https://github.com/Lawkh/LawkhsTalentMerger).
