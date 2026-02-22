# Bee Forest Pollination Migration Notes

## Legacy cash template systems to remove/disable

The place file in this repository is binary (`CashEmpireSimulator.rbxl`), so script internals are not directly diffable in text.
To avoid old economy loops clashing with the new pollination loop, `ServerScriptService/Main.server.lua` now disables scripts whose names include:

- `cash`
- `drop`
- `collector`
- `moneydrop`

This catches common template scripts such as cash droppers and collector pads while preserving unrelated gameplay scripts.

## New server-authoritative flow

1. Bees increase `Bloom` on `PollinationPoints`.
2. At `Bloom >= 100`, `PollinationService` spawns a `MoneyFlower` with a server-side value.
3. Player collects with `ProximityPrompt` or `CollectFlower` remote request.
4. Server validates ownership + distance before awarding coins.
5. Coins, bees, upgrades, and boosts are persisted by `DataService`.
