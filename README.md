# Map Votes
[![Build Status](https://travis-ci.org/CrimsonTautology/sm-map-votes.png?branch=master)](https://travis-ci.org/CrimsonTautology/sm-map-votes)

Sourcemod Plugin to connect with the [Map Votes API](https://github.com/CrimsonTautology/map-votes).

##Installation
* Install the [Steam Tools](http://forums.alliedmods.net/showthread.php?t=170630) Sourcemod extension.
* Install the [SMJansson](http://forums.alliedmods.net/showthread.php?t=184604) Sourcemod extension.
* Compile plugins with spcomp (e.g.)
> `spcomp addons/sourcemod/scripting/map_votes.sp`
* Compiled .smx files into your `"<modname>/addons/sourcemod/plugins"` directory.
* Setup the `sm_map_votes_url` cvar to point to the root url of the web interface.  
> sm_map_votes_url "http://mapvotes.example.com"
* Get an api key from the web interface and assign it to the `sm_map_votes_api_key` cvar.  
> sm_map_votes_api_key "apikey"

##Requirements
* [SMJansson](https://forums.alliedmods.net/showthread.php?t=184604)
* [SteamTools](https://forums.alliedmods.net/showthread.php?t=129763)
* [A Web Site Backend](https://github.com/CrimsonTautology/map-votes)

##CVARs

* `sm_map_votes_url` - URL to your Map Votes web page
* `sm_map_votes_api_key` - The API key you generated to interact with the Map Votes web page.
* `sm_map_votes_voting_enabled` - Whether players are allowed to vote on the current map.  Default `1`
* `sm_map_votes_commenting_enabled` - Whether players are allowed to comment on the current map.  Default `1`
* `sm_map_votes_nominations_plugin` - The nominations plugin used by the server.  Defaults to `"nominations.smx"`
* `sm_map_votes_request_cooldown_time` - How long in seconds before a client can send another http request.  Defaults to 2
* `sm_map_votes_call_auto_vote_time` - How long in seconds before a client is automaticly asked to vote on the current map. Defaults to 1200 (20 minutes)



##Usage
* `!votemenu` Vote that you like the current map
* `!voteup`, `!like` Vote that you like the current map
* `!votedown`,`!hate` Vote that you hate the current map

* `!fav [map]` Search for `"map"` and add it to your favorites.  Deafults to current `"map"` if map is not given.
* `!unfav [map]` Search for `"map"` and remove it to your favorites.  Deafults to current `"map"` if map is not given.
* `!nomfav [map]` Nominate for the next map vote from a list of your favorites

* `!mapcomment <message>`, `!mc <message>` Comment on the current map
* `!viewmap` View the Map Votes web page for this map

* `!have_not_voted` (Admin Command)Popup a vote panel to every player on the server that has not yet voted on this map

# Other
[Base64 Library](http://forums.alliedmods.net/showthread.php?t=101764)
[SMJansson](https://github.com/thraaawn/SMJansson)
[Steam Tools](http://forums.alliedmods.net/showthread.php?t=170630)
