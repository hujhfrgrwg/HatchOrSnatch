---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/open-cloud
retrieved: 2026-10-15
---
# Open Cloud: creating developer products from a script

Creating 20 developer products by hand in the Creator Dashboard is slow and error-prone (typos in prices, missing icons, ids pasted into the wrong config line).

Creating 20 developer products by hand in the Creator Dashboard is slow and error-prone (typos in prices, missing icons, ids pasted into the wrong config line). An Open Cloud API key lets an agent do it, **as long as the key never appears in the conversation, the logs or the repo.**

- [[#Key handling]]
- [[#Endpoints]]
- [[#Workflow]]
- [[#Wiring ids into the game]]
- [[#What Open Cloud cannot do here]]
- [[#Checklist]]

## Key handling

- The developer creates the key in the Creator Dashboard (Open Cloud \> API Keys). For a group-owned game, create it **under the group**, scoped to the one universe, with only the permissions needed (developer products read + write). Add an IP restriction if practical, and an expiry.

- The developer saves it to a file outside the repo and locks it down:

  ``` bash
  # the developer runs this, pasting the key at the prompt (not as an argument)
  read -rs KEY && printf '%s' "$KEY" > ~/.roblox_api_key && chmod 600 ~/.roblox_api_key && unset KEY
  ```

- Agents read it **inside the command** and never echo it:

  ``` bash
  K=$(tr -d '\r\n ' < ~/.roblox_api_key)
  curl -s -H "x-api-key: $K" "https://apis.roblox.com/..."   # never `echo $K`, never `set -x`
  ```

- Never pass the key as a command-line argument to a script (it shows in `ps` and shell history), never write it into a file in the project, never paste it in chat. If it ever leaks, revoke it in the dashboard and make a new one.

- Add the key file pattern to `.gitignore` anyway.

## Endpoints

All requests carry the header `x-api-key: <key>`.

| Action                       | Request                                                                                                                                                                                                                                       |
|------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| List the universe's products | `GET https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products/creator?pageSize=50` (follow `nextPageToken` with `&pageToken=`)                                                                                 |
| Create a product             | `POST https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products` as `multipart/form-data` with `name`, `description`, `price` (Robux, integer), `isForSale` (`true`), and optionally `imageFile` (PNG/JPG icon) |

- The create response includes the new `productId`.
- Updating an existing product (price, icon, description) and game passes have their own Open Cloud endpoints; check the current Open Cloud reference before scripting them, since these APIs change versions.
- The universe id is not the place id. Read it in Studio with `game.GameId`.

## Workflow

[tools/devproducts.py](https://roclicks.gg/resources/code/engineering/tools/devproducts.py) does all of this, refuses a key file that is not chmod 600, and never prints the key.

1.  Write the product list as data (`products.json`): name, description, price, icon path.
2.  `python3 devproducts.py list --universe <id>` to see what already exists.
3.  `python3 devproducts.py create --universe <id> --spec products.json --dry-run`, show the developer the plan (names and prices) and get a yes. Creating products is a real change to a live game.
4.  Run it without `--dry-run`. Names that already exist are skipped, so a re-run after a failure does not create duplicates.
5.  Paste the printed `name -> productId` map into the game's product config.

## Wiring ids into the game

- One `Products` config module maps keys to ids: `{ coinsS = { id = 0, price = 49, ... } }`.
- **Id 0 means inert**: registering id 0 is a no-op, the shop hides or greys the item, and a Studio debug-grant path can still test the flow. This lets the game ship before every product exists.
- Prices in the config are for display only; the real price is whatever the product has on Roblox. Read it with `MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)` if they might drift.
- Receipts go through the single `ProcessReceipt` owner ([[Data and saves|data-and-saves.md]]).

## What Open Cloud cannot do here

- **Audio** cannot be uploaded from tools in most setups; the developer bulk-imports it through Studio's Asset Manager.
- **Images for in-game use** (decals, GUI images) can go through the logged-in Studio session instead (see [[Driving Roblox Studio through MCP|studio-mcp.md]]). Pack many icons into one sprite sheet to cut the upload count.
- Experience settings such as Max Players or "Allow Mesh / Image APIs" are set by hand in Game Settings, and on a group game only by someone with the right group role.

## Checklist

- Key scoped to one universe, minimum permissions, stored in a chmod-600 file outside the repo.
- Key read inside commands only; never printed, never in argv, never committed.
- Dry run shown to the developer before creating anything.
- Re-runs skip existing names.
- Ids pasted into one config; id 0 = inert.

Previous: [[Input]] · Next: [[Engineering tools]]
