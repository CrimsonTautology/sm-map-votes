SM_NOMGREP
===============
Sourcemod Plugin to connect with the [Map Votes API](https://github.com/CrimsonTautology/map_votes).

INSTALLATION:
-------------
Install the [Socket](http://forums.alliedmods.net/showthread.php?t=67640) Sourcemod extension.

Compile with 
> `spcomp addons/sourcemod/scripting/map_votes.sp`

Move the compiled `map_votes.smx` file to your `/path/to/server/tf2/tf/addons/sourcemod/plugins/` directory.

Generate an api key through the Map Votes webpage.

Set the `sm_map_votes_api_key` cvar to the Api Key you just generated.
Set the `sm_map_votes_url` cvar to the URL of your Map Votes webpage.


USAGE:
------
`sm_vote_menu`      Vote that you like the current map
`sm_vote_up`        Vote that you like the current map
`sm_vote_down`      Vote that you hate the current map
`sm_map_comment`    Comment on the current map
`sm_mc`             Comment on the current map
`sm_view_map`       View the Map Votes web page for this map
`sm_call_vote`      Popup a vote panel to every player on the server that has not yet voted on this map

OTHER:
------
[Code for getting SteamId64s](http://forums.alliedmods.net/showthread.php?t=183443)
[Base64 Library](http://forums.alliedmods.net/showthread.php?t=101764)
[JSON Library](https://github.com/nikkiii/logupload/blob/master/scripting/include/json.inc)

