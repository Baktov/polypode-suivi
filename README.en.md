# Polypode Tracker (Polypode Suivi)

*Version française : [README.md](README.md)*

**"Team tracker"** window for [Polypode](https://github.com/Baktov/polypode), as a separate addon
(enabled or not in the WoW AddOns list, per character): for each member of the selected team, the
information from the "Expansion summary" that matters to move the whole team forward.

Requires **Polypode 0.51.0** or later.

> **Languages**: French, English, German, Spanish, Italian and Brazilian Portuguese, following the
> language chosen in Polypode (option "Langue / Language"). The translations were made with the help
> of Claude, Anthropic's AI: feedback from native speakers is very welcome
> ([GitHub issue](https://github.com/Baktov/polypode-suivi/issues)).

---

## Installation

1. Install **Polypode** first (required dependency).
2. Put the `Polypode_Suivi` folder in `World of Warcraft/_retail_/Interface/AddOns/`
   (and, for **WoW Forever**, in `World of Warcraft/_forever_/Interface/AddOns/`).
3. Enable "Polypode Tracker" in the AddOns list, **on each character** whose information you want
   to see: each one sends its own.

---

## Usage

The **Tracker** button (title bar of the Polypode window, or module column of the floating bar;
**right-click**: small window of the tracker options, with an **All options** button, Polypode
0.57; otherwise the options panel) or `/poly suivi` (`/poly tracker`) opens a window laid out as a
**borderless table**: a header line (Character, Vault, Runes, crest icons, catalyst icon, Campaign,
Prey, Delves, Dungeons, Raids), then one line per member of the selected team (leader first), with
vertically aligned columns (on the right, as wide as their longest content; the name takes the
remaining room and is cut if the window is narrow; a column empty for everyone is hidden; on hover,
each header says what its column counts: Great Vault, crest name, catalyst...).

**Sorting**: a click on a header sorts the table by that column (largest to smallest;
"Character": by name, A to Z), a second click reverses the order; an arrow marks the sorted
column, characters with no value stay at the bottom. The sort is kept per character; with no sort
chosen, the leader is first.

The columns:

- an **envelope** left of the name if the character has **unread mail**, or mail expiring in less
  than 3 days;
- name in class color;
- **Vault** n/9: unlocked slots of the Great Vault;
- **Runes** n (in green): runes of power points to spend, if any;
- the item upgrade **crests** (icon and amount), from adventurer on the left to myth on the right;
- the available **catalyst charges** (season currency; 0 in grey);
- **Campaign** done/total: completed chapters of the most recent campaign (green if finished, grey
  if not started);
- what was done **this week**: number of prey hunts, delves, dungeons and raids (grey if zero; raids
  = bosses killed).

When hovering a character, the tooltip details:

- **Great Vault**: progress of each slot (raids, dungeons, world), in green once reached;
- **Item upgrade**: each crest;
- owned **Resources** (honor, conquest and the expansion's currencies);
- the expansion's unlocked **Renown** (can be hidden, see Options);
- **Runes of power**: points to spend, and whether a rune can be bought;
- **Campaigns (chapters)**: progress of the current expansion's campaigns, "patch – name:
  done/total" (e.g. "12.1 – ...: 1/6"), and, for a blocked campaign, what to do to resume it (game
  text, in grey). With the option "Campaigns of previous expansions", the previous expansions follow
  (from Mists of Pandaria to The War Within, most recent first): campaigns started but not
  finished, and number of campaigns completed per expansion. Campaigns with variants (Alliance /
  Horde, Shadowlands covenants, Legion class halls) take only one line: the character's;
- the date of another character's information;
- **This week**: prey hunts done per difficulty (Normal, Hard, Nightmare, out of 4), delves per
  tier, heroic / mythic / mythic+ dungeons with key levels, raid bosses per difficulty (LFR, normal,
  heroic, mythic). Reset at the weekly reset. **Normal** and **follower** dungeons are tracked by no
  WoW API (they do not count for the vault): Polypode Tracker counts them **on entering** the
  dungeon (marked *), without counting again a return to the same dungeon within 2 hours (reload,
  logout); an abandoned dungeon thus counts too;
- **Mail**: "Unread mail", then, from the character's last visit to the mailbox, the number of
  unread / total mails and the **nearest expiration** (red under 3 days). WoW only gives these
  details with the mailbox open: they are recorded at each visit and kept, dated (as Altoholic
  does);
- **Exploration** (at the bottom): names of the **delves**, **dungeons** and **raids** the
  character entered this week, with the difficulty (dungeons, raids) and the number of entries.
  Recorded **on entering** the instance (a return to the same instance within 2 hours is not
  counted again; an abandoned instance counts too), reset at the weekly reset.

The list scrolls; the window is **resized** with the bottom-right corner grip (size kept per
character); Escape closes the window; it follows the selected team. The list header shows the
**current season** (e.g. "Midnight, season 2", from the game), and flags in orange "lists to
update" if the crests or activities taken from Plumber do not cover this season (new season or new
expansion).

### Activities

The **Activities** button (top right, Retail only) replaces the summary with the panel of the
**expansion's activities**, filed as in Plumber (Silvermoon City, Delves, Prey, the expansion's
factions and zones...). Each activity has the icon of its quest type (as in Plumber), or a check
mark when every known character has completed it. Right of each activity, the tracked characters
who **did** it (green) or **started** it (yellow, "..."); for a series of quests (renown bonus,
world prey), "name n/total". The usual activities (weekly quests) are always listed; the others
(dailies, bosses, wanted posters...) show as soon as they are active for the current character, or
a tracked character did or started them. The tooltip gives each character's state. On each
**category** line, on the right and in **blue**, the characters who did **all the shown
activities** (on hover: activities done by each one, "3/5"). As for campaigns, a **click on a
category** **collapses** it (only its name stays, preceded by "+") or expands it, and the
**Collapse all** / **Expand all** button, right of the panel header, acts on all of them; the state
is kept from one session to the next. The **Summary** button (in place of the button of the shown
panel, on a soft blue background) goes back to the per-character display.

Titles are the game's. The list of activities is taken from Plumber, which does not share it with
other addons: only activities based on a quest are tracked, and the list needs updating when a
patch changes the activities. Activities are reset at the weekly reset, and dailies each day.

### Quests

The **Quests** button (left of **Campaigns**; hidden when **All characters** is checked), or
`/poly quetes` (`/poly quests`), replaces the summary with **all the quests in progress** for at
least one of the shown characters (the selected team, or every character with the **All
characters** box; the current character is always included), taken over from the old Polypode
Quêtes addon. On the right, four columns each name one or two characters, logged-in first, "+n"
for the others:

- **Turned in or to take** (red): the quest is not in their log; they may have turned it in
  already if their Polypode Tracker has not said so yet;
- **In progress** (yellow): the quest is in their log;
- **Completed** (green): they already turned it in (each Polypode Tracker checks it in the game for
  its character and sends it to the others);
- **Unknown** (grey): no log received for this character (no Polypode, never seen).

A quest stays listed **as long as a character has it in progress**, even logged out: logs are
kept, and a character's log is only updated at their next login. Quests still to take for the most
characters come first; on hover, the tooltip gives every character of each column.

A **click on a quest** opens it in the quest log (world map) and closes the window. Only the quests
in **your own log** can open (WoW limit); for the others, a message says so. Logs are exchanged
through Polypode (at login and on each quest accepted, turned in or abandoned): the panel updates
by itself (requires Polypode 0.58). World quests, bonus objectives and hidden quests are not listed.

### Campaigns

The **Campaigns** button (left of **Activities**, Retail only) replaces the summary with the **list
of all tracked campaigns**, from Mists of Pandaria to Midnight, filed by expansion (current
expansion first, then most recent to oldest), "patch – name". On the right, three columns
**Finished** (green), **In progress** (yellow) and **Not started** (red) each name one or two
characters as examples, **logged-in first**, then "+n" for the others; a character with no
information received yet is not named. On each **expansion** line, in **blue** and aligned on the
"Finished" column, the characters who **finished all its campaigns** (on hover: campaigns finished
by each one, "5/10"); they are then **no longer named** in the columns of that expansion's
campaigns (each campaign's tooltip still shows them). Campaigns some characters cannot do
("Dracthyr, Awaken", reserved to Dracthyr; "Legion Remix", reserved to Remix characters) stay
listed but are **not required** to complete the expansion (their tooltip says so). **On hover** of
a campaign: each character's progress ("2/7 chapters", "not started", "unknown"), with the reason
a blocked campaign is blocked. A **click on an expansion** **collapses** it (only its name, preceded
by "+", and the characters who finished it remain) or expands it; the **Collapse all** / **Expand
all** button, right of the panel header, acts on every expansion. Collapsed expansions stay so from
one session to the next. The **Summary** button goes back to the per-character display.

The **Options** button (left of the title bar) opens the tracker options directly (Options >
AddOns > Polypode > Tracker). The **All characters** box (on its right, also in the options) shows
instead **every character whose information was recorded**, in alphabetical order, with the date
of their information ("2 h ago", "from 09/24 at 21:10"); the window title then becomes **Full
tracker**.

Right of the box, the **Played within** list (also in the options) only keeps the characters played
within **1 day**, **1 week**, **1 month** or **1 year** (date of their last information received),
or **All** (default). It applies to the team as well as to **All characters** and to every panel;
the current character is always shown, and the list header gives the filter ("played within 1
week: 4/12"). The window title follows the list.

### Grid

The **Grid** button (right of the title, left of **Quests** / **Campaigns**, and also in the
Polypode title bar, right of the **Solo** box; or `/poly grille`, `/poly grid`) opens a separate,
resizable window that places **every roster character** in a grid, with two tabs. A character at
**max level** has their cell in **red**; on hover of a cell: account, level, item level, class,
race, professions and team of each character. Mouse wheel: scrolling; Shift + mouse wheel:
horizontal scrolling if the grid is wider than the window.

- **Accounts**: one column per **WoW account** (named in Polypode; number and order of the columns
  in the options, **Others** column for characters with no account or of an account with no
  column). One line per character alone, or per Polypode **team** (2 characters and more; a
  character member of several teams is placed in the largest one), in three blocks: **Solo**
  (grouped by professions), **Multi 2/3**, **Multi 4/5/+**. On the left: **Profession 1** and
  **Profession 2** (can be hidden; for a team, a single cell with its **name**) and the **level**
  ("90 / 308" at max level, with the item level, the lowest of the team); each one's levels if
  those of a team differ.
- **Matrix**: **races** in rows (icon and name), grouped by faction (**Alliance**, **Neutral**,
  **Horde**, then **Others**: races missing from the table, "Unknown race"), with a stripe in the
  faction color; **classes** in columns (icons, name on hover), grouped by **armor** (Cloth,
  Leather, Mail, Plate: one header cell per armor). An occupied cell shows the highest character,
  tinted in their class color, and **"+n"** for the others (all in the tooltip); **gold corner** =
  a character at max level. An impossible combination is crossed by a thin grey diagonal line ("Impossible combination" on hover), a possible but
  empty one dark grey. By default only the races that have a character are shown: check **All
  races** (top right) to see the missing combinations. At the bottom, the collapsible **Free rows**
  section (click its title): "+ Add a row", click on the label to rename it (right-click: delete),
  click on a cell to write a text in it (Enter to confirm, Escape to cancel). These rows are shared
  by all your characters. On **WoW Forever**, the matrix follows Forever's
  races and classes (nine classes; Human, Dwarf, Night Elf, Gnome, High Order Skyborne, Orc, Tauren,
  Troll, Undead, Windshaper Skyborne) and their combinations.

A character's race, item level and professions are recorded by Polypode Tracker (at their next
login with this version); in the meantime, those already recorded by **Polypode Data** (2.1 or
later, if installed; 2.4 or later for a reliable race in any language) are used. Without either: class and level from the roster, "Unknown race"
row of the matrix.

---

## How it works

- The current character is read live. The others send their information through Polypode
  (`SUIVI` message) whenever one of your clients logs in, then 3 seconds after a change (vault,
  currencies, bags, renown, runes), and only what changed. A character without Polypode Tracker,
  or not seen yet, shows "no info".
- The information is **saved** (account file, shared by your accounts if they share their
  `SavedVariables`) with its date: a logged-out character can still be checked with their last
  known information.
- **Weekly reset**: a Great Vault known from before the last reset (Wednesday morning in Europe) is
  shown **reset** (thresholds kept), with a note in the tooltip, until the character sends their new
  information.
- The information is read the way the "Expansion summary" of the **Plumber** addon does it (public
  WoW APIs); the IDs of Midnight's crests and resources are taken from it (crest list chosen by
  Midnight season: season 1 or 2; by client version if the season is unknown). They will need
  updating at the next expansion.
- **Campaigns**: the list of campaigns (game IDs, filed by expansion and patch) comes from a survey
  of every campaign of the game; a chapter is completed when its chain of quests is (as in the
  quest log). It needs completing when a patch adds a campaign; in the meantime, a new campaign
  started shows in "Other campaigns".
- On **WoW Forever**, everything specific to Retail is hidden: **Activities** and **Campaigns**
  buttons (**Quests** takes their place), Retail columns of the summary, season in the header,
  campaign and renown options. The summary follows instead each character's **Legacy**: columns
  **Legacy** (points earned, shared by the account / maximum), **Spent** (points placed in their
  trees / cap per character), **To spend** (in green) and **Challenges** (done / total); tooltip:
  mail, then the same details with the points spent per tree (Professions, Adventure,
  Progression). The game's Legacy panel does not need to be opened.

---

## Options

In **Options > AddOns > Polypode > Tracker** (per-character setting):

| Option | Default | Effect |
|---|---|---|
| All characters | No | The window lists every character whose information was recorded instead of the selected team (same box as in the window's title bar). Always checked (and greyed) in Polypode's **solo mode** |
| Characters played within | All | 1 day, 1 week, 1 month, 1 year or All: only shows the characters played within that time (same list as in the title bar); the current character is always shown |
| Campaigns of previous expansions | No | Adds to each member's tooltip the campaigns of previous expansions (since Mists of Pandaria): those started but not finished, and the number of campaigns completed per expansion |
| Show renown | No | Details the expansion's renown in each member's tooltip. Useless with a single Battle.net account: renown is shared by all characters there |

In **Options > AddOns > Polypode > Tracker > Grid** (settings **shared by all your characters**,
sent to the logged-in clients; also the **Options** button of the Grid window):

| Option | Default | Effect |
|---|---|---|
| Show professions | Yes | Profession 1 and Profession 2 columns of the Accounts tab (team name in the Multi blocks) |
| Number of account columns | All accounts (10 at most) | Number of account columns of the Accounts tab (1 to 10) |
| Column 1 to 10 | Automatic | Account of each column; "Automatic" takes the first account not placed yet, in alphabetical order. Greyed beyond the number of columns |

---

## Credits

Polypode Tracker is **freely inspired** by the "Expansion summary" of the **Plumber** addon, by
**Peterodox**. The code is written for Polypode (no Plumber file is included), but its **data** is
taken over: IDs of Midnight's crests and resources, list and filing of the activities (quest IDs).
The "a rune can be bought" computation follows Blizzard's interface
(`Blizzard_MidnightLandingPage`). Thanks to Peterodox for this survey work.

---

## Languages

Polypode Tracker follows the language chosen in Polypode ("Langue / Language" option,
`/poly language`), by default the game's: French, English, German, Spanish, Italian or Brazilian
Portuguese (English for any other language). Choosing the language requires Polypode 2.9; with an
older Polypode, the module stays in French. The `/poly suivi` command keeps its name, with the
English aliases `/poly tracker`, `/poly grid` and `/poly quests`. On WoW Forever, the two Skyborne
races of the Grid use Blizzard's names (English, German, Spanish); in Italian and Portuguese, no
official translation was found, so they keep their English names.

---

## Versions

The full version history is in the [French README](README.md#version).
