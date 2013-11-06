/**
 * vim: set ts=4 :
 * =============================================================================
 * map_votes
 * Interact with the Map Votes web api - https://github.com/CrimsonTautology/map_votes
 *
 * Copyright 2013 The Crimson Tautology
 * =============================================================================
 *
 */


#pragma semicolon 1

#include <sourcemod>
#include <steamtools>
#include <base64>
#include <smjansson>

#define PLUGIN_VERSION "0.1"

public Plugin:myinfo = {
    name = "MapVotes",
    author = "CrimsonTautology",
    description = "Interact with the Map Votes web api",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_map_votes"
};

#define CAST_VOTE_ROUTE "/v1/api/cast_vote"
#define WRITE_MESSAGE_ROUTE "/v1/api/write_message"
#define FAVORITE_ROUTE "/v1/api/favorite"
#define UNFAVORITE_ROUTE "/v1/api/unfavorite"
#define GET_FAVORITES_ROUTE "/v1/api/get_favorites"
#define HAVE_NOT_VOTED_ROUTE "/v1/api/have_not_voted"
#define SERVER_QUERY_ROUTE "/v1/api/server_query"
#define MAPS_ROUTE "/maps"

#define MAX_STEAMID_LENGTH 21 
#define MAX_COMMUNITYID_LENGTH 18 


new Handle:g_Cvar_MapVotesUrl = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesPort = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesApiKey = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesVotingEnabled = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesCommentingEnabled = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesNominationsName = INVALID_HANDLE;

new g_MapFileSerial = -1;
new Handle:g_MapList = INVALID_HANDLE;
new Handle:g_MapTrie = INVALID_HANDLE;

new Handle:g_nominations = INVALID_HANDLE;
new Function:g_Handler_MapSelectMenu = INVALID_FUNCTION;


public OnPluginStart()
{

    g_Cvar_MapVotesUrl = CreateConVar("sm_map_votes_url", "", "URL to your Map Votes web page");
    g_Cvar_MapVotesPort = CreateConVar("sm_map_votes_port", "80", "HTTP Port used");
    g_Cvar_MapVotesApiKey = CreateConVar("sm_map_votes_api_key", "", "The API key you generated to interact with the Map Votes web page");
    g_Cvar_MapVotesVotingEnabled = CreateConVar("sm_map_votes_voting_enabled", "1", "Whether players are allowed to vote on the current map");
    g_Cvar_MapVotesCommentingEnabled = CreateConVar("sm_map_votes_commenting_enabled", "1", "Whether players are allowed to comment on the current map");
    g_Cvar_MapVotesNominationsName = CreateConVar("sm_map_votes_nominations_plugin", "nominations.smx", "The nominations plugin used by the server");

    RegConsoleCmd("sm_votemenu", Command_VoteMenu, "Bring up a menu to vote on the current map");
    RegConsoleCmd("sm_voteup", Command_VoteUp, "Vote that you like the current map");
    RegConsoleCmd("sm_like", Command_VoteUp, "Vote that you like the current map");
    RegConsoleCmd("sm_votedown", Command_VoteDown, "Vote that you hate the current map");
    RegConsoleCmd("sm_hate", Command_VoteDown, "Vote that you hate the current map");

    RegConsoleCmd("sm_fav", Command_Favorite, "Add this map to your favorites");
    RegConsoleCmd("sm_unfav", Command_Unfavorite, "Remove this map to your favorites");
    RegConsoleCmd("sm_nomfav", Command_GetFavorites, "Nominate from a list of your favorites");

    RegConsoleCmd("sm_mapcomment", Command_MapComment, "Comment on the current map");
    RegConsoleCmd("sm_mc", Command_MapComment, "Comment on the current map");

    RegConsoleCmd("sm_viewmap", Command_ViewMap, "View the Map Votes web page for this map");

    RegAdminCmd("sm_have_not_voted", Command_HaveNotVoted, ADMFLAG_VOTE, "Popup a vote panel to every player on the server that has not yet voted on this map");

    RegConsoleCmd("test", Test);

    new array_size = ByteCountToCells(PLATFORM_MAX_PATH);        
    g_MapList = CreateArray(array_size);
    g_MapTrie = CreateTrie();
}

public OnConfigsExecuted()
{
    BuildMapListAndTrie();
}

public OnAllPluginsLoaded() {
    new String:noms[PLATFORM_MAX_PATH];
    GetConVarString(g_Cvar_MapVotesNominationsName, noms, sizeof(noms));
    //g_nominations = FindPluginByFile(noms);
    g_nominations = FindPluginByFile("nominations.smx");

    //Check if nominations.smx is both available and currently running
    if(g_nominations == INVALID_HANDLE || GetPluginStatus(g_nominations) != Plugin_Running){
        SetFailState("[MapVotes] Error, nominations is currently not running");
    }
    else{
        //We should be clear to link the MapSelectMenu function
        g_Handler_MapSelectMenu = GetFunctionByName(g_nominations, "Handler_MapSelectMenu");
    }
}

public Action:Command_VoteMenu(client, args)
{
    if(client && IsClientAuthorized(client) && GetConVarBool(g_Cvar_MapVotesVotingEnabled)){
        CallVoteOnClient(client);
    }

    return Plugin_Handled;
}

public Action:Command_VoteUp(client, args)
{
    if(client && IsClientAuthorized(client) && GetConVarBool(g_Cvar_MapVotesVotingEnabled)){
        CastVote(client, 1);
    }

    return Plugin_Handled;
}

public Action:Command_VoteDown(client, args)
{
    if(client && IsClientAuthorized(client) && GetConVarBool(g_Cvar_MapVotesVotingEnabled)){
        CastVote(client, -1);
    }

    return Plugin_Handled;
}

public Action:Command_Favorite(client, args)
{
    if(client && IsClientAuthorized(client) && GetConVarBool(g_Cvar_MapVotesVotingEnabled)){
        new String:map[PLATFORM_MAX_PATH];
        if (args <= 0)
        {
            GetCurrentMap(map, sizeof(map));
            Favorite(map, client, true);
        }else{
            GetCmdArg(1, map, sizeof(map));
            MapSearch(client, map, g_MapList, FavoriteSearchHandler);
        }
    }

    return Plugin_Handled;
}
public Action:Command_Unfavorite(client, args)
{
    if(client && IsClientAuthorized(client) && GetConVarBool(g_Cvar_MapVotesVotingEnabled)){
        new String:map[PLATFORM_MAX_PATH];
        if (args <= 0)
        {
            GetCurrentMap(map, sizeof(map));
            Favorite(map, client, false);
        }else{
            GetCmdArg(1, map, sizeof(map));
            MapSearch(client, map, g_MapList, UnfavoriteSearchHandler);
        }

    }

    return Plugin_Handled;
}
public Action:Command_GetFavorites(client, args)
{
    if(client && IsClientAuthorized(client) && GetConVarBool(g_Cvar_MapVotesVotingEnabled)){
        GetFavorites(client);
    }

    return Plugin_Handled;
}

public Action:Command_ViewMap(client, args)
{
    if(client && IsClientAuthorized(client)){
        ViewMap(client);
    }

    return Plugin_Handled;
}

public Action:Command_MapComment(client, args)
{
    if (!GetConVarBool(g_Cvar_MapVotesCommentingEnabled))
    {
        return Plugin_Handled;
    }

    if (args < 1)
    {
        ReplyToCommand(client, "[MapVotes] Usage: !map_comment <comment>");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        decl String:comment[256];
        GetCmdArgString(comment, sizeof(comment));
        WriteMessage(client, comment);
    }

    return Plugin_Handled;
}

public Action:Command_HaveNotVoted(client, args)
{
    HaveNotVoted();

    return Plugin_Handled;
}


BuildMapListAndTrie()
{
    //Build the map list
    if (ReadMapList(g_MapList,
                g_MapFileSerial,
                "nominations",
                MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER)
            == INVALID_HANDLE)
    {
        if (g_MapFileSerial == -1)
        {
            SetFailState("Unable to create a valid map list.");
        }else{
            //Build the map trie; note we don't care about the value, just if the map exists in the trie
            ClearTrie(g_MapTrie);
            new String:map[PLATFORM_MAX_PATH];

            for (new i = 0; i < GetArraySize(g_MapList); i++)
            {
                GetArrayString(g_MapList, i, map, sizeof(map));
                SetTrieValue(g_MapTrie, map, 1);
            }
        }
    }
}

public SetAccessCode(&HTTPRequestHandle:request)
{
    decl String:api_key[128];
    GetConVarString(g_Cvar_MapVotesApiKey, api_key, sizeof(api_key));
	Steam_SetHTTPRequestGetOrPostParameter(request, "access_token", api_key);
}

public HTTPRequestHandle:CreateMapVotesRequest(const String:route[])
{
    //TODO - check for forward slash after base_url;
    decl String:base_url[256], String:url[512];
    GetConVarString(g_Cvar_MapVotesUrl, base_url, sizeof(base_url));
    Format(url, sizeof(url),
            "%s%s", base_url, route);

    //ReplaceString(base_url, sizeof(base_url), "http://", "", false);
    //ReplaceString(base_url, sizeof(base_url), "https://", "", false);
    return Steam_CreateHTTPRequest(HTTPMethod_POST, url);

}
public Steam_SetHTTPRequestGetOrPostParameterInt(&HTTPRequestHandle:request, const String:param[], value)
{
    String[64] tmp;
    IntToString(tmp, paramValue);
    Steam_SetHTTPRequestGetOrPostParameter(request, param, tmp);
}

public WriteMessage(client, String:message[256])
{
    //Encode the message to be url safe
    decl String:base64[256], String:base64_url[256];
    EncodeBase64(base64, sizeof(base64), message);
    Base64MimeToUrl(base64_url, sizeof(base64_url), base64);

    decl String:uid[MAX_COMMUNITYID_LENGTH];
    Steam_GetCSteamIDForClient(client, uid, sizeof(uid));

    decl String:map[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));

    new HTTPRequestHandle:request = CreateMapVotesRequest(WRITE_MESSAGE_ROUTE);
	Steam_SetHTTPRequestGetOrPostParameter(request, "map", map);
	Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);
	Steam_SetHTTPRequestGetOrPostParameter(request, "comment", base64_url);
	Steam_SetHTTPRequestGetOrPostParameter(request, "base64", "1");
    SetAccessCode(request);
    Steam_SendHTTPRequest(request, ReceiveWriteMessage, GetClientUserId(client));

    //MapVotesCall(WRITE_MESSAGE_ROUTE, query_params, client, ReceiveWriteMessage);

}

public ReceiveWriteMessage(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid) {
{
    new client = GetClientOfUserId(userid);

    if(client && Successful)
    {
        PrintToChat(client, "[MapVotes] Comment Added");
    }

	Steam_ReleaseHTTPRequest(request);
}

public CastVote(client, value)
{

    if(!(value == -1 || value == 0 || value == 1)){
        LogError("[MapVotes] invalid vote value %d (steam_user: %s)", value, uid);
    }else{
        decl String:map[PLATFORM_MAX_PATH];
        decl String:uid[MAX_COMMUNITYID_LENGTH];
        Steam_GetCSteamIDForClient(client, uid, sizeof(uid));

        GetCurrentMap(map, sizeof(map));

        new HTTPRequestHandle:request = CreateMapVotesRequest(CAST_VOTE_ROUTE);
        Steam_SetHTTPRequestGetOrPostParameter(request, "map", map);
        Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);
        Steam_SetHTTPRequestGetOrPostParameterInt(request, "value", value);
        SetAccessCode(request);
        Steam_SendHTTPRequest(request, ReceiveCastVote, GetClientUserId(client));

        //MapVotesCall(CAST_VOTE_ROUTE, query_params, client, ReceiveCastVote);
    }

}

public ReceiveCastVote(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid) {
{
    new client = GetClientOfUserId(userid);

    if(client && Successful)
    {
        PrintToChat(client, "[MapVotes] Vote Cast");
    }

	Steam_ReleaseHTTPRequest(request);
}

public Favorite(String:map[PLATFORM_MAX_PATH], client, bool:favorite)
{
    decl String:uid[MAX_COMMUNITYID_LENGTH];
    Steam_GetCSteamIDForClient(client, uid, sizeof(uid));

    if(favorite)
    {
        //MapVotesCall(FAVORITE_ROUTE, query_params, client, ReceiveFavorite);
    }else{
        //MapVotesCall(UNFAVORITE_ROUTE, query_params, client, ReceiveFavorite);
    }
    new HTTPRequestHandle:request = CreateMapVotesRequest(FAVORITE_ROUTE);
    Steam_SetHTTPRequestGetOrPostParameter(request, "map", map);
    Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);
    SetAccessCode(request);
    Steam_SendHTTPRequest(request, ReceiveFavorite, GetClientUserId(client));
}

public ReceiveFavorite(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid) {
{
    new client = GetClientOfUserId(userid);

    if(client && Successful)
    {
        PrintToChat(client, "[MapVotes] Updated Favorites");
    }

	Steam_ReleaseHTTPRequest(request);
}



public MapSearch(client, String:search_key[PLATFORM_MAX_PATH], Handle:map_list, MenuHandler:handler)
{
    new String:map[PLATFORM_MAX_PATH], String:info[16];
    new Handle:menu = CreateMenu(handler, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem);
    new bool:found = false;

    for(new i=0; i<GetArraySize(map_list); i++)
    {
        GetArrayString(map_list, i, map, sizeof(map));

        //If this map matches the search key, add it to the menu
        if(StrContains(map, search_key, false) >= 0){
            AddMenuItem(menu, map, map);
            found = true;
        }
    }

    if(found)
    {
        SetMenuTitle(menu, "Found Maps");
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    }

}

public FavoriteSearchHandler(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
    } else if (action == MenuAction_VoteCancel)
    {
    } else if (action == MenuAction_Select)
    {
        new client=param1;
        new String:map[PLATFORM_MAX_PATH];
        GetMenuItem(menu, param2, map, sizeof(map));
        Favorite(map, client, true);
    }
}

public UnfavoriteSearchHandler(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
    } else if (action == MenuAction_VoteCancel)
    {
    } else if (action == MenuAction_Select)
    {
        new client=param1;
        new String:map[PLATFORM_MAX_PATH];
        GetMenuItem(menu, param2, map, sizeof(map));
        Favorite(map, client, false);
    }
}

public GetFavorites(client)
{
    decl String:uid[MAX_COMMUNITYID_LENGTH];
    Steam_GetCSteamIDForClient(client, uid, sizeof(uid));
    decl String:query_params[512];

    //NOTE: uid is the client's steamid64 while player is the client's userid; the index incremented for each client that joined the server
    Format(query_params, sizeof(query_params),
            "player=%i&uid=%s", GetClientUserId(client), uid);

    //MapVotesCall(GET_FAVORITES_ROUTE, query_params, client, ReceiveGetFavorites);
    new HTTPRequestHandle:request = CreateMapVotesRequest(GET_FAVORITES_ROUTE);
    Steam_SetHTTPRequestGetOrPostParameterInt(request, "player", GetClientUserId(client));
    Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);
    SetAccessCode(request);
    Steam_SendHTTPRequest(request, ReceiveGetFavorites, GetClientUserId(client));
}

public ReceiveGetFavorites(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid) {
{
    new client = GetClientOfUserId(userid);
    if(client && Successful)
    {
        //TODO
    }

    
    decl String:data[4096];
    Steam_GetHTTPResponseBodyData(request, data, sizeof(data));
    Steam_ReleaseHTTPRequest(request);

    new Handle:json = json_load(data);
    new Handle:maps = json_object_get(json, "maps");
    new String:map_buffer[PLATFORM_MAX_PATH];
    new junk;

    new Handle:menu = CreateMenu(NominateMapHandler);

    for(new i = 0; i < json_array_size(maps); i++)
    {
        json_array_get_string(maps, i, map_buffer, sizeof(map_buffer));
        if(GetTrieValue(g_MapTrie, map_buffer, junk))
        {
            AddMenuItem(menu, map_buffer, map_buffer);
        }
    }

    CloseHandle(json);
    CloseHandle(maps);

    //If no maps were found don't even bother displaying a menu
    if(GetMenuItemCount(menu) > 0){
        SetMenuTitle(menu, "Favorited Maps");
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    }else{
        PrintToChat(client, "[MapVotes] You have no favorited maps that are on this server.");
    }
}


public NominateMapHandler(Handle:menu, MenuAction:action, param1, param2)
{

    decl result;

    // Start function call
    Call_StartFunction(g_nominations, g_Handler_MapSelectMenu);

    // Push parameters one at a time
    Call_PushCell(menu);
    Call_PushCell(action);
    Call_PushCell(param1);
    Call_PushCell(param2);

    // Finish the call, get the result
    Call_Finish(result);

    return result;
}


public CallVoteOnClient(client)
{
    new Handle:menu = CreateMenu(VoteMenuHandler);
    SetMenuTitle(menu, "Do you like this map?");
    AddMenuItem(menu, "1","Like it.");
    AddMenuItem(menu, "-1","Hate it.");
    AddMenuItem(menu, "0","I have no strong feelings one way or the other.");
    DisplayMenu(menu, client, 20);
}

public VoteMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
    } else if (action == MenuAction_VoteCancel)
    {
    } else if (action == MenuAction_Select)
    {
        new String:info[32];
        GetMenuItem(menu, param2, info, sizeof(info));
        new value = StringToInt(info);

        CastVote(param1, value);
    }
}

public HaveNotVoted()
{
    decl String:uid[MAX_COMMUNITYID_LENGTH];
    new String:query_buffer[512], String:query_params[512], String:map[PLATFORM_MAX_PATH];
    new player;
    new HTTPRequestHandle:request = CreateMapVotesRequest(HAVE_NOT_VOTED_ROUTE);

    GetCurrentMap(map, sizeof(map));
    Steam_SetHTTPRequestGetOrPostParameter(request, "map", map);

    for (new client=1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
        {
            continue;
        }
        Steam_GetCSteamIDForClient(client, uid, sizeof(uid));
        player = GetClientUserId(client);

        Steam_SetHTTPRequestGetOrPostParameter(request, "uids", uid);
        Steam_SetHTTPRequestGetOrPostParameterInt(request, "players", player);
    }

    //MapVotesCall(HAVE_NOT_VOTED_ROUTE, query_params, 0, ReceiveHaveNotVoted);
    SetAccessCode(request);
    Steam_SendHTTPRequest(request, ReceiveHaveNotVoted, GetClientUserId(client));
}

public ReceiveHaveNotVoted(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid) {
{
    new client = GetClientOfUserId(userid);
    if(client && Successful)
    {
        //TODO
    }

    
    decl String:data[4096];
    Steam_GetHTTPResponseBodyData(request, data, sizeof(data));
    Steam_ReleaseHTTPRequest(request);

    new Handle:json = json_load(data);
    new Handle:players = json_object_get(json, "players");
    new p;
    new String:map_buffer[PLATFORM_MAX_PATH];

    for(new i = 0; i < json_array_size(players); i++)
    {
        p = json_array_get_int(players, i);
        CallVoteOnClient(GetClientOfUserId(p));
    }
    CloseHandle(json);
    CloseHandle(players);
}

public ViewMap(client)
{
    decl String:map[PLATFORM_MAX_PATH], String:url[256], String:base_url[128];
    GetCurrentMap(map, sizeof(map));
    GetConVarString(g_Cvar_MapVotesUrl, base_url, sizeof(base_url));
    //TODO
    ReplaceString(base_url, sizeof(base_url), "http://", "", false);
    ReplaceString(base_url, sizeof(base_url), "https://", "", false);

    Format(url, sizeof(url),
            "http://%s%s/%s", base_url, MAPS_ROUTE, map);

    ShowMOTDPanel(client, "Map Viewer", url, MOTDPANEL_TYPE_URL);

}


public Action:Test(client, args)
{
    decl String:query_params[512];

    //NOTE: uid is the client's steamid64 while player is the client's userid; the index incremented for each client that joined the server
    Format(query_params, sizeof(query_params),
            "player=%i&uid=%s", 7, "76561197998903004");

    //MapVotesCall(GET_FAVORITES_ROUTE, query_params, 0, ReceiveGetFavorites);
}

