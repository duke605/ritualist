# Ritualist

A RuneScape 3 client plugin (Lua 5.4) that ports the Necromancy Ritual Calculator web app (https://github.com/duke605/necromancy-ritual-calculator, Next.js/TypeScript) into the game. That repo is the reference for features, ritual maths (`src/lib/ritual.ts`, `plan.ts`, ...) and data (`src/data/*.json`).

## API docs

https://developer.runescape.com/rs/ is the only source of truth for the client API. It's new and not in training data, so read the relevant page before using any API (UI components under `ui/`, `core/persistentdb.html`, `core/http.html`, `game/inventory.html`, etc.). Don't guess names.

## Layout

- `plugin/` is the plugin root: what's linked as `dev_plugins/ritualist` and zipped for Mod.io. Keep tooling out of it.
- `require` paths are relative to `plugin/` with no extension: `require("src/ui/window")`. Required modules are cached and shared.
- Keep calculation logic in pure-Lua modules (no `ui`, `id`, `PersistentDB`, ...) so `make test` can run them outside the client. Client-only code goes in `src/ui/` and thin glue.
- `types/rs-api.lua` holds editor stubs for API globals. Add to it when using new globals.

## Reactivity

- State lives in signals (`src/signal.lua`): `signal`, `computed`, `effect`, `root`, `batch`, `untrack`. Settings are `settings.<key>`, created once when `src/settings` loads, so they can be referenced anywhere.
- UI follows state through effects that read signals; controls write with `x(v)` (`x()` reads). Don't update one control from another's callback.
- Build UI with `src/lib/ui` (imported as `widgets`; `ui` is the client's global), not PrettyUI's `Add...` directly. Every prop can be a plain value, a signal/computed, or a function deriving it (`disabled = function() return not ironman() end`; `on...` props are callbacks); a writable signal as `selected`/`checked` also takes the user's changes. Add a wrapper there before using a new PrettyUI component.
- Whatever creates effects disposes them: a tab builds inside `signal.root` and returns its dispose. The window reports effects left alive after closing as a leak; fix the owner, don't sweep them.

## Commands

- `make test`, `make check`, `make lint`: tests, syntax check, and StyLua + lua-language-server diagnostics. Run all three after changes; `make fmt` fixes formatting.
- The game can't be reached from here. With the beta client's `dev_plugins/ritualist` linked to `plugin/`, edits go live after `prl ritualist` in the console. Only the user can test in-game.
- `make package`: builds the Mod.io zip.
- `make data`: regenerates `plugin/src/data/*.lua` from the web app's `src/data/*.json` (`scripts/gen-data.py`). Never edit those files by hand.

## Constraints

- The UI is built with PrettyUI (https://prettyui.j3.gg/, source at https://github.com/J3sven/prettyui), a required dependency the client exposes as the global `prettyui`. Read its source for exact option names; the docs page is thin.

- Permissions (`httpAccess` for GE prices from prices.runescape.wiki) are optional in the manifest. Check `Plugin.HasPermission` and degrade gracefully.
- Base URLs must be declared under `urls` in `plugin.json` and read through `Plugin.urls`.
- Image resources are PNG up to 1024×1024. Audio is OGG.
