# 🎭 RC Multicharacter (`rc_multicharacter`)

> **Authentic QBox (`qbx_core`) `ox_lib` Multicharacter experience — engineered to run natively across QBox, QBCore, and ESX Legacy with automatic framework detection, zero-error SQL schemas, and isolated character lifecycle bridging.**

![Version](https://img.shields.io/badge/version-1.0.0-red?style=for-the-badge)
![Lua](https://img.shields.io/badge/Lua-5.4-blue?style=for-the-badge)
![Frameworks](https://img.shields.io/badge/Frameworks-QBox%20%7C%20QBCore%20%7C%20ESX%20Legacy-16a34a?style=for-the-badge)
![Dependencies](https://img.shields.io/badge/Requires-ox__lib%20%2B%20oxmysql-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/License-GPL--3.0-slate?style=for-the-badge)

---

## ✨ Overview

`rc_multicharacter` extracts the clean, lightweight **`qbx_core` `ox_lib` multicharacter system** into a standalone, zero-bloat resource with a dedicated **auto-detecting Framework Bridge** and **idempotent SQL layer** for **QBox**, **QBCore**, and **ESX Legacy (`es_extended`)**.

No third-party React/HTML multicharacter wrappers, no core rewrites, and zero framework lock-in — just the pure `ox_lib` character selector, registration dialog, Depth-of-Field preview camera, and server-authoritative character management working identically on every major FiveM core.

---

## 🧩 Framework & Ecosystem Compatibility

| Layer | Supported Targets | Detection / Integration Notes |
|---|---|---|
| **Core Frameworks** | `qbx_core`, `qb-core`, `es_extended` | Priority detection (`qbx_core` → `qb-core` → `es_extended`) via `bridge/framework.lua`; supports `'auto'` or manual override |
| **Multichar Aliases** | `esx_multicharacter`, `qb-multicharacter` | Declared via `provide` in `fxmanifest.lua` + native `rc_multicharacter` check in `es_extended` |
| **Appearance / Skin** | `illenium-appearance`, `fivem-appearance`, `qb-clothing`, `esx_skin` / `skinchanger` | Automatic preview ped rendering & first-spawn customization with gender-matched freemode fallback |
| **Spawn / Apartments** | `qbx_apartments`, `qbx_spawn`, `qb-apartments`, `qb-spawn`, native fallback | Respects `Config.Client.startingApartment` and `Config.Client.skipSpawnSelection` |
| **Starter Inventory** | `ox_inventory`, `qb-inventory`, ESX native inventory | Distributes `Config.Shared.starterItems` cleanly on brand-new character creation |
| **Database** | MySQL 8.0+ / MariaDB 10.3+ via `oxmysql` | Idempotent DDL scripts (`sql/*.sql`) + runtime `information_schema` verification (`server/database.lua`) |

---

## 🚀 Key Features

- **Authentic QBox (`ox_lib`) UX:**
  - `lib.registerContext` / `lib.showContext` character slot overview & per-character Play / Delete menus
  - `lib.inputDialog` character registration with searchable nationality selector (`data/nationalities.lua`), gender selector, date picker, optional ESX height input, and client + server profanity filtering
  - `lib.alertDialog` confirmation guard before character deletion
  - Depth-of-Field preview camera across 7 curated GTA V locations + solo tutorial session isolation + male/female preview peds
- **Unified Multi-Framework Bridge (`bridge/`):**
  - Clean adapter separation (`bridge/server/*.lua` and `bridge/client/*.lua`) for QBox, QBCore, and ESX Legacy
  - Checks `qbx_core` **before** `qb-core` to handle QBox's `provide 'qb-core'` manifest cleanly
  - Protects against ESX `esx:playerLogout` save races, stale inactive player sessions in `playerConnecting`, and mismatched starter ped genders
- **Zero-Error Auto-Migrating SQL (`server/database.lua` & `sql/`):**
  - Dedicated schemas: [`sql/qbox.sql`](sql/qbox.sql), [`sql/qbcore.sql`](sql/qbcore.sql), [`sql/esx.sql`](sql/esx.sql)
  - Runtime `information_schema` inspection ensures missing columns/tables (`rc_multicharacter_slots`, `users.nationality`, `users.disabled`, `users.ssn`, `users.skin`) never cause unhandled SQL errors
  - Safe dynamic character deletion (`SafeDeleteByTables` & `DiscoverEsxCharacterTables`) only queries verified existing tables/columns
- **Security & Resource Lifecycle Safety:**
  - Per-player `inFlight` locks prevent duplicate spawn/create/delete callbacks
  - Strict slot ownership checks drop unauthorized character load/delete attempts with optional Discord webhook logging
  - `/relog` cooldown protection (`Config.Shared.relogCooldownSeconds`)
  - Deterministic `onResourceStop` cleanup releases preview cameras, tutorial sessions, entity freeze/invincibility, radar state, and open `ox_lib` dialogs

---

## 📦 Dependencies

1. [`oxmysql`](https://github.com/overextended/oxmysql) — **must start before** your framework and `rc_multicharacter`
2. [`ox_lib`](https://github.com/overextended/ox_lib) (`v3.14.0+` recommended) — **must start before** `rc_multicharacter`
3. **OneSync Infinity** (`+set onesync on`)
4. **One active framework**: `qbx_core`, `qb-core`, OR `es_extended`

---

## 🛠️ Installation

### 1. Remove Conflicting Multicharacters
Remove or disable old multicharacter scripts so they do not compete for spawn events:
- `qb-multicharacter`
- `esx_multicharacter`
- `rooney_multicharacter` (if upgrading on ESX)

### 2. Import Your Framework SQL
Import **only** the SQL file matching your active core (all three are 100% idempotent on MySQL 8.0+ and MariaDB 10.3+):

| Framework | SQL File | Notes |
|---|---|---|
| **QBox (`qbx_core`)** | [`sql/qbox.sql`](sql/qbox.sql) | Ensures `users`, `players`, `player_groups`, `playerskins`, and `rc_multicharacter_slots` |
| **QBCore (`qb-core`)** | [`sql/qbcore.sql`](sql/qbcore.sql) | Ensures `players`, `bans`, `player_contacts`, `playerskins`, and `rc_multicharacter_slots` |
| **ESX Legacy (`es_extended`)** | [`sql/esx.sql`](sql/esx.sql) | Ensures `users`, `jobs`, `job_grades`, `rc_multicharacter_slots`, and patches `firstname`/`lastname`/`dateofbirth`/`sex`/`height`/`nationality`/`skin`/`disabled`/`ssn` safely |

### 3. Framework-Specific Setup
- **If using QBox (`qbx_core`):**
  Open `qbx_core/config/client.lua` and disable Qbox's built-in internal multichar UI:
  ```lua
  useExternalCharacters = true
  ```
- **If using ESX Legacy (`es_extended`):**
  `rc_multicharacter` declares `provide 'esx_multicharacter'` in `fxmanifest.lua`, and if you use the paired `es_extended` build, `shared/config/main.lua` also checks `GetResourceState("rc_multicharacter") ~= "missing"` directly so `Config.Multichar` is always `true`.
- **If using QBCore (`qb-core`):**
  Ensure `rc_multicharacter` is ensured in `server.cfg` (it declares `provide 'qb-multicharacter'`).

### 4. `server.cfg` Start Order
```cfg
ensure oxmysql
ensure ox_lib

# Ensure your active framework + inventory + appearance BEFORE rc_multicharacter
ensure es_extended     # OR qbx_core / qb-core
ensure ox_inventory    # OR qb-inventory / default inventory
ensure rc_multicharacter
```

---

## ⚙️ Configuration

All settings are cleanly split across three files:

- **[`config/shared.lua`](config/shared.lua)**
  - `Config.Shared.framework` — `'auto'` (recommended) | `'qbox'` | `'qbcore'` | `'esx'`
  - `Config.Shared.defaultSpawn` — fallback `vec4` spawn coordinates
  - `Config.Shared.esxPrefix` — slot identifier prefix on ESX (`'char'` → `char1:identifier`)
  - `Config.Shared.enableRelogCommand` / `relogCooldownSeconds` — `/relog` toggle & cooldown
  - `Config.Shared.enableAdminCommands` — toggle admin staff commands
  - `Config.Shared.enableDeleteButton` — toggle self-service character deletion (server-enforced)
  - `Config.Shared.starterItems` — items & optional dynamic metadata given to new characters
- **[`config/client.lua`](config/client.lua)**
  - `Config.Client.startingApartment` — trigger apartment/spawn picker for brand-new characters
  - `Config.Client.skipSpawnSelection` — spawn existing characters straight to saved position
  - `Config.Client.limitNationalities` — searchable dropdown from `data/nationalities.lua` vs free text
  - `Config.Client.askHeightOnEsx` / `defaultHeight` — toggle ESX height prompt during registration
  - `Config.Client.locations` — 7 randomized ped + camera `vec4` preview scenes
- **[`config/server.lua`](config/server.lua)**
  - `Config.Server.defaultNumberOfCharacters` — default character slot limit (default: `3`)
  - `Config.Server.playersNumberOfCharacters` — static per-license/identifier slot overrides
  - `Config.Server.autoMigrateSchema` — toggle runtime `information_schema` verification on `MySQL.ready`
  - `Config.Server.giveStarterItems` — enable/disable `starterItems` distribution
  - `Config.Server.logging.webhook` — optional Discord webhook URL for audit & anti-cheat logs
  - `Config.Server.characterDataTables` — per-framework cleanup tables on character deletion

---

## ⌨️ Commands & Permissions

| Command | Arguments | Access | Description |
|---|---|---|---|
| `/relog` | — | Everyone | Safely log out of active character and return to character selection (`relogCooldownSeconds` cooldown) |
| `/logout` | `[id]` *(optional)* | Admin (`group.admin` / ACE) | Force-logout yourself or a target player back to character selection |
| `/deletechar` | `[citizenid_or_id]` | Admin (`group.admin` / ACE) | Force-delete a character by CitizenID / ESX identifier or online player ID |
| `/setslots` | `[identifier] [slots]` | Admin (`group.admin` / ACE) | Grant custom character slot limit persisted in `rc_multicharacter_slots` |
| `/remslots` | `[identifier]` | Admin (`group.admin` / ACE) | Remove a persisted custom character slot override |

Example ACE permission in `server.cfg`:
```cfg
add_ace group.admin command.logout allow
add_ace group.admin command.deletechar allow
add_ace group.admin command.setslots allow
add_ace group.admin command.remslots allow
```

---

## 📁 Resource Structure

```text
rc_multicharacter/
├── fxmanifest.lua              # Cerulean / Lua 5.4 manifest + ox_lib locale + provides
├── config/
│   ├── shared.lua              # Framework mode, relog, delete toggle, starter items
│   ├── client.lua              # Preview camera spots, apartments, nationality/date rules
│   └── server.lua              # Default slots, webhooks, profanity & cleanup tables
├── bridge/
│   ├── framework.lua           # Framework auto-detector, core resolver, Notify & IsAdmin
│   ├── server/
│   │   ├── qbox.lua            # QBox server CRUD, preview skin & starter items
│   │   ├── qbcore.lua          # QBCore server CRUD, preview skin & starter items
│   │   └── esx.lua             # ESX server CRUD, slot parsing & connecting guard
│   └── client/
│       ├── qbox.lua            # QBox preview skin, spawn/apartments & logout hook
│       ├── qbcore.lua          # QBCore preview skin, spawn/apartments & logout hook
│       └── esx.lua             # ESX preview skin, esx:playerLoaded & logout hook
├── server/
│   ├── database.lua            # oxmysql readiness, auto-migration & safe table deletion
│   └── main.lua                # Callbacks, exploit checks, webhooks, admin commands
├── client/
│   └── main.lua                # ox_lib menus, DoF camera, tutorial session & cleanup
├── data/
│   └── nationalities.lua       # Curated searchable nationality dataset
├── locales/
│   └── en.json                 # Localized ox_lib UI strings & notifications
└── sql/
    ├── qbox.sql                # Idempotent QBox schema
    ├── qbcore.sql              # Idempotent QBCore schema
    └── esx.sql                 # Idempotent ESX Legacy schema
```

---

## 📝 License & Credits

- **Original Core UX:** Adapted from [Qbox Project (`qbx_core`)](https://github.com/Qbox-project/qbx_core) character module, distributed under **GNU General Public License v3.0 (GPL-3.0)**.
- **Multi-Framework Bridge & ESX/QBCore Adaptation:** Developed by **Rooney Creations**.
