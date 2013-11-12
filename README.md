SM_MAP_VOTES
===============
[![Build Status](https://travis-ci.org/CrimsonTautology/sm_map_votes.png?branch=master)](https://travis-ci.org/CrimsonTautology/sm_map_votes)
Sourcemod Plugin to connect with the [Map Votes API](https://github.com/CrimsonTautology/map_votes).

INSTALLATION:
-------------
Install the [Steam Tools](http://forums.alliedmods.net/showthread.php?t=170630) Sourcemod extension.
Install the [SMJansson](http://forums.alliedmods.net/showthread.php?t=184604) Sourcemod extension.

Compile with 
> `spcomp addons/sourcemod/scripting/map_votes.sp`

Move the compiled `map_votes.smx` file to your `/path/to/server/tf2/tf/addons/sourcemod/plugins/` directory.

Generate an api key through the Map Votes webpage.

Set the `sm_map_votes_api_key` cvar to the Api Key you just generated.
Set the `sm_map_votes_url` cvar to the URL of your Map Votes webpage.

CVARs:
------
- `sm_map_votes_url` URL to your Map Votes web page
- `sm_map_votes_api_key` The API key you generated to interact with the Map Votes web page
- `sm_map_votes_voting_enabled` Whether players are allowed to vote on the current map
    Default `1`
- `sm_map_votes_commenting_enabled` Whether players are allowed to comment on the current map
    Default `1`
- `sm_map_votes_nominations_plugin` The nominations plugin used by the server
    Defaults to `"nominations.smx"`



USAGE:
------
`!votemenu` Vote that you like the current map
`!voteup`, `!like` Vote that you like the current map
`!votedown`,`!hate` Vote that you hate the current map

`!fav [map]` Search for `"map"` and add it to your favorites.  Deafults to current `"map"` if map is not given.
`!unfav [map]` Search for `"map"` and remove it to your favorites.  Deafults to current `"map"` if map is not given.
`!nomfav [map]` Nominate for the next map vote from a list of your favorites

`!mapcomment <message>`, `!mc <message>` Comment on the current map
`!viewmap` View the Map Votes web page for this map

`!have_not_voted` (Admin Command)Popup a vote panel to every player on the server that has not yet voted on this map

OTHER:
------
[Base64 Library](http://forums.alliedmods.net/showthread.php?t=101764)
[SMJansson](https://github.com/thraaawn/SMJansson)
[Steam Tools](http://forums.alliedmods.net/showthread.php?t=170630)
