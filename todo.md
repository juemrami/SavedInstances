# Todo

- [ ] Add option to ignore characters on servers with a different season (ie dont show SoD characters while on an SoM or Hardcore character unless toggled)


- [ ] Move all the logic relating to tracking instance lockouts out of `Core.lua` and into its own module file. 

- [ ] Add caching for the tooltip scanner, use the hyperlink as a key maybe
    - tooltip scanning used for Quest tooltip, boss names on instance tooltip, and currency tooltip (for classic only).
 

- [ ] Move any building of AceConfig options into their respective module files. ie currency options should be in `Currency.lua`

- [ ] Clean-up SavedVars (currently seems like theres alot of random junk.)
    
    - anything thats super computationally expensive should be saved to SavedVars but thats it. 

- [ ] compare the instance history tracking to something like Nova Instance Tracker, and see if there is anything that can be improved upon.

- [ ] Modify modules to be able to loaded on any client but only functional on the client they are intended for. (ie indexing any function/member on say `Callings` or `Warfront` modules while not SI.isRetail should return nil but still be indexable)

- [ ] Modify the options for showing character columns. 
    - Currently its only "always show" ,"never show", or "show when saved".
    - When something like a trade skill or quest progress is tracked for a character it will create a column for that character even when set to "show when saved".
    - an option for "show when something being tracked is found"
        - ie quest progress/wbuffs/tradeskill/paragon

- [x] add category headers for the currencies in classic, so the options dont look as complicated/messy for it. (since there is alot of currencies to pick from)

- [x] World buff tracking for classic.

- [x] Migrate changes from `/Modules/Wrath/Progress.lua` into `/Modules/Progress.lua`

- [x] Hide and disable unused AceConfig option widgets for classic and wrath
    
    - [x] General Settings: Holidays, random dungeons, and world bosses.
    
    - [x] Indicators
    
- [x] Compare retail functionality between this addon and the original
    - From a quick usage of the addon on retail all seems to be working but its hard to test every feature. (and unit testing feels like too much to implement for an addon)