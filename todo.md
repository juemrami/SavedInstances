# Todo

- [x] Compare retail functionality between this addon and the original
    - From a quick usage of the addon on retail all seems to be working but its hard to test every feature. (and unit testing feels like too much to implement for an addon)

- [ ] Move all the logic relating to tracking instance lockouts out of `Core.lua` and into its own module file. 

- [ ] Add caching for the tooltip scanner, use the hyperlink as a key maybe
    - tooltip scanning used for Quest tooltip, boss names on instance tooltip, and currency tooltip (for classic only).
 

- [ ] Move any building of AceConfig options into their respective module files. ie currency options should be in `Currency.lua`

- [ ] Clean-up SavedVars (currently seems like theres alot of random junk.)
    - up whats being saved to
    - anything thats super computationally expensive should be saved to SavedVars but thats it. 

- [ ] Add option to ignore characters on servers with a different season (ie dont show SoD characters while on an SoM or Hardcore character unless toggled)

- [ ] add category headers for the currencies in classic, so the options dont look as complicated/messy for it. (since there is alot of currencies to pick from)

- [ ] compare the instance history tracking to something like Nova Instance Tracker, and see if there is anything that can be improved upon.

- [ ] Migrate changes from `/Modules/Wrath/Progress.lua` into `/Modules/Progress.lua`