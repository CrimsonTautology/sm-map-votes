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
#include <morecolors>

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
#define UPDATE_MAP_PLAY_TIME_ROUTE "/v1/api/update_map_play_time"
#define MAPS_ROUTE "/maps"

#define MAX_STEAMID_LENGTH 21 
#define MAX_COMMUNITYID_LENGTH 18 

new Handle:g_Cvar_MapVotesUrl = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesApiKey = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesVotingEnabled = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesCommentingEnabled = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesNominationsName = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesRequestCooldownTime = INVALID_HANDLE;

new bool:g_IsInCooldown[MAXPLAYERS+1];

new g_MapStartTimestamp = 0;

new g_MapFileSerial = -1;
new Handle:g_MapList = INVALID_HANDLE;
new Handle:g_MapTrie = INVALID_HANDLE;

new Handle:g_nominations = INVALID_HANDLE;
new Function:g_Handler_MapSelectMenu = INVALID_FUNCTION;


public OnPluginStart()
{

    LoadTranslations("map_votes.phrases");
    g_Cvar_MapVotesUrl = CreateConVar("sm_map_votes_url", "", "URL to your Map Votes web page.  Remeber the \"http://\" part and to quote the entire url!");
    g_Cvar_MapVotesApiKey = CreateConVar("sm_map_votes_api_key", "", "The API key you generated to interact with the Map Votes web page");
    g_Cvar_MapVotesVotingEnabled = CreateConVar("sm_map_votes_voting_enabled", "1", "Whether players are allowed to vote on the current map");
    g_Cvar_MapVotesCommentingEnabled = CreateConVar("sm_map_votes_commenting_enabled", "1", "Whether players are allowed to comment on the current map");
    g_Cvar_MapVotesNominationsName = CreateConVar("sm_map_votes_nominations_plugin", "nominations.smx", "The nominations plugin used by the server");
    g_Cvar_MapVotesRequestCooldownTime = CreateConVar("sm_map_votes_request_cooldown_time", "2.0", "How long in seconds before a client can send another http request");

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

    new array_size = ByteCountToCells(PLATFORM_MAX_PATH);        
    g_MapList = CreateArray(array_size);
    g_MapTrie = CreateTrie();
    BuildMapListAndTrie();
}

public OnMapStart()
{

    g_MapStartTimestamp = GetTime();
}

public OnMapEnd()
{
    decl String:map[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));
    UpdateMapPlayTime(g_MapStartTimestamp);
}

//Sourcemod 1.4 support
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) { 
    MarkNativeAsOptional("GetUserMessageType"); 
    return APLRes_Success; 
}  

public OnConfigsExecuted()
{
    BuildMapListAndTrie();
}

public OnAllPluginsLoaded() {
    new String:noms[PLATFORM_MAX_PATH];
    GetConVarString(g_Cvar_MapVotesNominationsName, noms, sizeof(noms));
    g_nominations = FindPluginByFile(noms);

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
    if(IsClientInCooldown(client))
    {
        CReplyToCommand(client, "%t", "user_cooldown");
        return Plugin_Handled;
    }

    if(!GetConVarBool(g_Cvar_MapVotesVotingEnabled))
    {
        CReplyToCommand(client, "%t", "voting_not_enabled");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        CallVoteOnClient(client);
    }

    return Plugin_Handled;
}

public Action:Command_VoteUp(client, args)
{
    if(IsClientInCooldown(client))
    {
        CReplyToCommand(client, "%t", "user_cooldown");
        return Plugin_Handled;
    }

    if(!GetConVarBool(g_Cvar_MapVotesVotingEnabled))
    {
        CReplyToCommand(client, "%t", "voting_not_enabled");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        CastVote(client, 1);
    }

    return Plugin_Handled;
}

public Action:Command_VoteDown(client, args)
{
    if(IsClientInCooldown(client))
    {
        CReplyToCommand(client, "%t", "user_cooldown");
        return Plugin_Handled;
    }

    if(!GetConVarBool(g_Cvar_MapVotesVotingEnabled))
    {
        CReplyToCommand(client, "%t", "voting_not_enabled");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        CastVote(client, -1);
    }

    return Plugin_Handled;
}

public Action:Command_Favorite(client, args)
{
    if(IsClientInCooldown(client))
    {
        CReplyToCommand(client, "%t", "user_cooldown");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
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
    if(IsClientInCooldown(client))
    {
        CReplyToCommand(client, "%t", "user_cooldown");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
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
    if(IsClientInCooldown(client))
    {
        CReplyToCommand(client, "%t", "user_cooldown");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
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
    if(IsClientInCooldown(client))
    {
        CReplyToCommand(client, "%t", "user_cooldown");
        return Plugin_Handled;
    }

    if (!GetConVarBool(g_Cvar_MapVotesCommentingEnabled))
    {
        CReplyToCommand(client, "%t", "voting_not_enabled");
        return Plugin_Handled;
    }

    if (args < 1)
    {
        CReplyToCommand(client, "%t", "map_comment_usage");
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
    if(IsClientInCooldown(client))
    {
        CReplyToCommand(client, "%t", "user_cooldown");
        return Plugin_Handled;
    }

    if(!GetConVarBool(g_Cvar_MapVotesVotingEnabled))
    {
        CReplyToCommand(client, "%t", "voting_not_enabled");
        return Plugin_Handled;
    }

    HaveNotVoted(client);

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
    //All MapVotes api calls require this code
    decl String:api_key[128];
    GetConVarString(g_Cvar_MapVotesApiKey, api_key, sizeof(api_key));
    Steam_SetHTTPRequestGetOrPostParameter(request, "access_token", api_key);
}

public HTTPRequestHandle:CreateMapVotesRequest(const String:route[])
{
    decl String:base_url[256], String:url[512];
    GetConVarString(g_Cvar_MapVotesUrl, base_url, sizeof(base_url));
    TrimString(base_url);
    new trim_length = strlen(base_url) - 1;

    if(trim_length < 0)
    {
        //MapVotes Url not set
        return INVALID_HTTP_HANDLE;
    }

    //check for forward slash after base_url;
    if(base_url[trim_length] == '/')
    {
        strcopy(base_url, trim_length + 1, base_url);
    }

    Format(url, sizeof(url),
            "%s%s", base_url, route);

    new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, url);
    SetAccessCode(request);

    return request;
}

public Steam_SetHTTPRequestGetOrPostParameterInt(&HTTPRequestHandle:request, const String:param[], value)
{
    new String:tmp[64];
    IntToString(value, tmp, sizeof(tmp));
    Steam_SetHTTPRequestGetOrPostParameter(request, param, tmp);
}

public StartCooldown(client)
{
    //Ignore the server console
    if (client == 0)
        return;

    g_IsInCooldown[client] = true;
    CreateTimer(GetConVarFloat(g_Cvar_MapVotesRequestCooldownTime), RemoveCooldown, client);
}

public bool:IsClientInCooldown(client)
{
    if(client == 0)
        return false;
    else
        return g_IsInCooldown[client];
}

public Action:RemoveCooldown(Handle:timer, any:client)
{
    g_IsInCooldown[client] = false;
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

    if(request == INVALID_HTTP_HANDLE)
    {
        CReplyToCommand(client, "%t", "url_invalid");
        return;
    }

    Steam_SetHTTPRequestGetOrPostParameter(request, "map", map);
    Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);
    Steam_SetHTTPRequestGetOrPostParameter(request, "comment", base64_url);
    Steam_SetHTTPRequestGetOrPostParameter(request, "base64", "1");
    Steam_SendHTTPRequest(request, ReceiveWriteMessage, GetClientUserId(client));
    StartCooldown(client);
}

public ReceiveWriteMessage(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    new client = GetClientOfUserId(userid);

    if(client && successful)
    {
        CPrintToChat(client, "%t", "comment_added");
    }

    Steam_ReleaseHTTPRequest(request);
}

public CastVote(client, value)
{

    if(!(value == -1 || value == 0 || value == 1)){
        LogError("[MapVotes] invalid vote value %d (client: %d)", value, client);
    }else{
        decl String:map[PLATFORM_MAX_PATH];
        decl String:uid[MAX_COMMUNITYID_LENGTH];
        Steam_GetCSteamIDForClient(client, uid, sizeof(uid));

        GetCurrentMap(map, sizeof(map));

        new HTTPRequestHandle:request = CreateMapVotesRequest(CAST_VOTE_ROUTE);

        if(request == INVALID_HTTP_HANDLE)
        {
            CReplyToCommand(client, "%t", "url_invalid");
            return;
        }

        Steam_SetHTTPRequestGetOrPostParameter(request, "map", map);
        Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);
        Steam_SetHTTPRequestGetOrPostParameterInt(request, "value", value);
        Steam_SendHTTPRequest(request, ReceiveCastVote, GetClientUserId(client));
        StartCooldown(client);
    }

}

public ReceiveCastVote(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    new client = GetClientOfUserId(userid);

    if(client && successful)
    {
        decl String:data[4096];
        Steam_GetHTTPResponseBodyData(request, data, sizeof(data));

        new Handle:json = json_load(data);
        new value = json_object_get_int(json, "value");
        CloseHandle(json);

        new String:name[64];
        GetClientName(client, name, sizeof(name));

        if (value == 1)
        {
            CPrintToChatAll("%t", "announce_up_vote", name);
        }else if(value == -1)
        {
            CPrintToChatAll("%t", "announce_down_vote", name);
        }else
        {
            CPrintToChat(client, "%t", "vote_cast");
        }
    }

    Steam_ReleaseHTTPRequest(request);
}

public Favorite(String:map[PLATFORM_MAX_PATH], client, bool:favorite)
{
    decl String:uid[MAX_COMMUNITYID_LENGTH];
    Steam_GetCSteamIDForClient(client, uid, sizeof(uid));

    new HTTPRequestHandle:request;
    if(favorite)
    {
        request = CreateMapVotesRequest(FAVORITE_ROUTE);
    }else{
        request = CreateMapVotesRequest(UNFAVORITE_ROUTE);
    }

    if(request == INVALID_HTTP_HANDLE)
    {
        CReplyToCommand(client, "%t", "url_invalid");
        return;
    }


    Steam_SetHTTPRequestGetOrPostParameter(request, "map", map);
    Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);
    Steam_SendHTTPRequest(request, ReceiveFavorite, GetClientUserId(client));
    StartCooldown(client);
}

public ReceiveFavorite(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    new client = GetClientOfUserId(userid);

    if(client && successful)
    {
        decl String:data[4096];
        Steam_GetHTTPResponseBodyData(request, data, sizeof(data));

        new Handle:json = json_load(data);
        new bool:favorite = json_object_get_bool(json, "favorite");
        new String:map[PLATFORM_MAX_PATH];
        json_object_get_string(json, "map", map, sizeof(map));
        CloseHandle(json);

        new String:name[64];
        GetClientName(client, name, sizeof(name));

        if (favorite)
        {
            CPrintToChatAll("%t", "announce_favorite", name, map);
        }else
        {
            CPrintToChat(client, "%t", "updated_favorites");
        }
    }

    Steam_ReleaseHTTPRequest(request);
}



public MapSearch(client, String:search_key[PLATFORM_MAX_PATH], Handle:map_list, MenuHandler:handler)
{
    new String:map[PLATFORM_MAX_PATH];
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

    new HTTPRequestHandle:request = CreateMapVotesRequest(GET_FAVORITES_ROUTE);

    if(request == INVALID_HTTP_HANDLE)
    {
        CReplyToCommand(client, "%t", "url_invalid");
        return;
    }

    Steam_SetHTTPRequestGetOrPostParameterInt(request, "player", GetClientUserId(client));
    Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);
    Steam_SendHTTPRequest(request, ReceiveGetFavorites, GetClientUserId(client));
    StartCooldown(client);
}

public ReceiveGetFavorites(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    new client = GetClientOfUserId(userid);
    if(!client)
    {
        //User logged off
        Steam_ReleaseHTTPRequest(request);
        return;
    }
    if(!successful || code != HTTPStatusCode_OK)
    {
        LogError("[MapVotes] Error at RecivedGetFavorites (HTTP Code %d; success %d)", code, successful);
        Steam_ReleaseHTTPRequest(request);
        return;
    }

    decl String:data[4096];
    Steam_GetHTTPResponseBodyData(request, data, sizeof(data));
    Steam_ReleaseHTTPRequest(request);

    new Handle:json = json_load(data);
    new Handle:maps = json_object_get(json, "maps");
    new String:map_buffer[PLATFORM_MAX_PATH];
    new junk;
    new bool:found;

    new Handle:menu = CreateMenu(NominateMapHandler, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem);

    for(new i = 0; i < json_array_size(maps); i++)
    {
        json_array_get_string(maps, i, map_buffer, sizeof(map_buffer));
        TrimString(map_buffer);
        found = GetTrieValue(g_MapTrie, map_buffer, junk);
        if(found)
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
        CReplyToCommand(client, "%t", "no_favorited_maps");
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

public HaveNotVoted(caller)
{
    decl String:uid[MAX_COMMUNITYID_LENGTH];
    decl String:map[PLATFORM_MAX_PATH];
    new player;
    new HTTPRequestHandle:request = CreateMapVotesRequest(HAVE_NOT_VOTED_ROUTE);

    if(request == INVALID_HTTP_HANDLE)
    {
        CReplyToCommand(caller, "%t", "url_invalid");
        return;
    }


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

        Steam_SetHTTPRequestGetOrPostParameter(request, "uids[]", uid);
        Steam_SetHTTPRequestGetOrPostParameterInt(request, "players[]", player);
    }

    
    new userid=GetClientUserId(caller);
    Steam_SendHTTPRequest(request, ReceiveHaveNotVoted, userid);
}

public ReceiveHaveNotVoted(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    new client = GetClientOfUserId(userid);
    if(!successful || code != HTTPStatusCode_OK)
    {
        LogError("[MapVotes] Error at RecivedHaveNotVoted (HTTP Code %d)", code);
        Steam_ReleaseHTTPRequest(request);
        return;
    }

    decl String:data[4096];
    Steam_GetHTTPResponseBodyData(request, data, sizeof(data));
    Steam_ReleaseHTTPRequest(request);

    new Handle:json = json_load(data);
    new Handle:players = json_object_get(json, "players");
    decl p;

    new count=json_array_size(players);
    if(client)
    {
        CPrintToChat(client, "%t", "have_not_voted", count);
    }

    for(new i = 0; i < count; i++)
    {
        p = json_array_get_int(players, i);
        CallVoteOnClient(GetClientOfUserId(p));
    }
    CloseHandle(json);
    CloseHandle(players);
}

public UpdateMapPlayTime(start_time)
{
    new time_played = GetTime() - start_time;

    //Reject way off values
    if(time_played < 0 || time_played > 86400000)
    {
        LogError("[MapVotes] cannot update map time played; time_played=%d", time_played);
        return;
    }

    decl String:map[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));

    new HTTPRequestHandle:request = CreateMapVotesRequest(UPDATE_MAP_PLAY_TIME_ROUTE);

    if(request == INVALID_HTTP_HANDLE)
    {
        LogError("[MapVotes] sm_map_votes_url invalid; cannot create HTTP request");
        return;
    }

    Steam_SetHTTPRequestGetOrPostParameter(request, "map", map);
    Steam_SetHTTPRequestGetOrPostParameterInt(request, "time_played", time_played);
    Steam_SendHTTPRequest(request, ReceiveUpdateMapPlayTime);
}

public ReceiveUpdateMapPlayTime(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    if(!successful || code != HTTPStatusCode_OK)
    {
        LogError("[MapVotes] Error at ReceiveUpdateMapPlayTime (HTTP Code %d; success %d)", code, successful);
        Steam_ReleaseHTTPRequest(request);
        return;
    }

    Steam_ReleaseHTTPRequest(request);
}

public ViewMap(client)
{
    decl String:map[PLATFORM_MAX_PATH], String:url[256], String:base_url[128];
    GetCurrentMap(map, sizeof(map));
    GetConVarString(g_Cvar_MapVotesUrl, base_url, sizeof(base_url));

    TrimString(base_url);
    new trim_length = strlen(base_url) - 1;

    if(base_url[trim_length] == '/')
    {
        strcopy(base_url, trim_length + 1, base_url);
    }

    Format(url, sizeof(url),
            "%s%s/%s", base_url, MAPS_ROUTE, map);

    ShowMOTDPanel(client, "Map Viewer", url, MOTDPANEL_TYPE_URL);

}

