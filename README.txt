ZenUI 1.0.25
A standalone Zen-styled UI replacement for World of Warcraft 3.3.5a / Project Ebonhold.

Getting started
- /zenui - open ZenUI settings
- /zenui move - move and align enabled ZenUI elements
- /zenui profiles - manage, import and export profiles
- /zenui bind - enter action-bar and Pet Bar keybind mode
- /zenui bags - toggle unified bags
- /zenui menu - toggle the Zen quick menu
- /zenui build - list or select Ebonhold Echo Saved Builds
- /zenui callboard - open the Callboard cooldown / raid-save tracker

ZenStylingPack appearance
- General -> Appearance is powered by the embedded ZenStylingPack 1.1.0 design system.
- Choose Global (EbonAPI) to share one appearance across compatible Zen addons, or This addon only for an independent ZenUI look. EbonAPI is optional and remains a separate addon.
- Styles: Zen Classic, Obsidian, Glass, Flat, Brutal and Neon, with shared accent, opacity, UI scale and type-style controls.
- Global styling changes are event-driven through EbonAPI; ZenUI layout, movers and per-section scales remain profile-owned.

Minimap raid context
- While inside a raid, the minimap shows the active size/difficulty under the zone name (for example 10, 10h, 25 or 25h).
- Interface -> Minimap -> Show raid size / difficulty toggles the extra line.

Unit-frame auras
- HUD & Combat -> Aura Layout controls Player, Target, Focus and Pet buffs/debuffs.
- Buff and Debuff rows can each be placed independently above or below their frame.

Profiles store ZenUI local appearance fallback, layout/movers, scales and module settings. When Appearance is set to Global, the active ZenStylingPack look is stored account-wide by the standalone EbonAPI shared store instead of inside a ZenUI profile. Export strings deliberately exclude account history such as remembered alt balances and character-specific talent-spec labels/icons.

Zen Mail
- Inbox Open All is paced and waits for Ebonhold/Blizzard to confirm each money/item operation before continuing. C.O.D. and GM/system mail are never auto-opened.
- Select mode supports Open Selected / Return Selected, Shift range selection and Ctrl same-sender selection. Outside Select mode, Shift-click a row collects it and Ctrl-click returns it when allowed.
- Send Mail has a Zen recipient picker for account-wide Contacts, recent recipients, same-realm alts, Friends and Guild members. Successful recipients are remembered automatically.
- Mail settings can reserve regular bag slots during batch collection and optionally report the net gold collected when the mailbox closes.

Echo Saved Builds: if the standalone community EbonAPI 2.1+ addon is enabled, ZenUI consumes its normalized BUILD_LIST / active-build state and live events for the Q-menu build switcher. EbonAPI is optional and is not bundled with ZenUI; without it, ZenUI keeps its existing direct Ebonhold Saved Build service and legacy compatibility fallbacks.

Compatibility note: ZenUI intentionally keeps Blizzard/Ebonhold native secure controls underneath several replacement panels when that is the safest way to preserve protected actions and custom server behavior.
