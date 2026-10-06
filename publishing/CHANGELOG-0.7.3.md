# Lawkh's Talent Merger 0.7.3

## New since 0.3.0

- A redesigned main window with one column per specialization, native spec icons, build cards, duplicate counts and matching group colors.
- Select one or more specializations for Merge, Clean and Nuke. Merge previews every duplicate group with an editable suggested name; Clean previews exactly what will be kept and removed.
- Hide unique builds to focus on duplicate groups.
- Undo history for the last 10 operations, with Restore buttons per specialization. Restore names and talents while preserving existing copies. Completed restores leave the history; unfinished scopes remain available.
- Nuke affects only selected specializations and accepts either NUKE or 123123 for confirmation. Other specializations and active talents are preserved.
- Open the panel with the button on the right of the talent window, or /tm. A badge shows the last duplicate check.
- Duplicate loadouts are colored in the native dropdown using cached results; the dropdown keeps its original actions.
- Analyze once when opening the panel or pressing Refresh, after a new saved loadout is ready, and once on first opening talents if no check has been attempted. No continuous background talent scans.
- Improved memory usage: remove redundant hidden-list refreshes, reuse interface elements and share reads across Undo history.
- Add the addon-list icon and translate the new controls into all supported WoW languages.

## Fixes

- Launcher input and hover handling use an independent overlay, with the panel brought to the front.
- Opening errors appear in chat; /tm launcher provides click diagnostics and /tm memory reports memory usage.
- Keep loadout validation, combat/death checks and sequential server-confirmed deletion.

## Notes

- WoW Retail 12.1.0.
- Undo restores loadout names and talents; action bars and equipment sets are not included.
- Activate the relevant specialization before restoring its loadouts.
