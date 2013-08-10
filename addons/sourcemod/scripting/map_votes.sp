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
#include <socket>

#define PLUGIN_VERSION "0.1"

public Plugin:myinfo = {
    name = "MapVotes",
    author = "CrimsonTautology",
    description = "Interact with the Map Votes web api",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_map_votes"
};

#define CAST_VOTE_ROUTE "/v1/api/cast_vote/"
#define WRITE_MESSAGE_ROUTE "/v1/api/write_message/"
#define SERVER_QUERY_ROUTE "/v1/api/server_query/"

new Handle:g_Cvar_MapVotesUrl = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesPort = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesApiKey = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesVotingEnabled = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesCommentingEnabled = INVALID_HANDLE;

public OnPluginStart()
{

    g_Cvar_MapVotesUrl = CreateConVar("sm_map_votes_url", "", "URL to your Map Votes web page");
    g_Cvar_MapVotesPort = CreateConVar("sm_map_votes_port", "80", "HTTP Port used");
    g_Cvar_MapVotesApiKey = CreateConVar("sm_map_votes_api_key", "", "The API key you generated to interact with the Map Votes web page");
    g_Cvar_MapVotesVotingEnabled = CreateConVar("sm_map_votes_voting_enabled", "1", "Whether players are allowed to vote on the current map");
    g_Cvar_MapVotesCommentingEnabled = CreateConVar("sm_map_votes_commenting_enabled", "1", "Whether players are allowed to comment on the current map");

    RegConsoleCmd("sm_vote_menu", Command_VoteMenu, "Vote that you like the current map");
    RegConsoleCmd("sm_vote_up", Command_VoteUp, "Vote that you like the current map");
    RegConsoleCmd("sm_vote_down", Command_VoteDown, "Vote that you hate the current map");
    RegConsoleCmd("sm_map_comment", Command_MapComment, "Comment on the current map");
    RegConsoleCmd("sm_call_vote", Command_CallVote, "Popup a vote panel to every player on the server that has not yet voted on this map");

}


public Action:Command_VoteMenu(client, args)
{
    //TODO
}

public Action:Command_VoteUp(client, args)
{
    if(!IsFakeClient(client)){
        CastVote(client, 1);
    }
}

public Action:Command_VoteDown(client, args)
{
    if(!IsFakeClient(client)){
        CastVote(client, -1);
    }
}

public Action:Command_MapComment(client, args)
{
    if(!IsFakeClient(client)){
        //WriteMessage(client, args);
    }
}

public Action:Command_CallVote(client, args)
{
    //TODO
}

public OnSocketConnected(Handle:socket, any:headers_pack)
{
    ResetPack(headers_pack);
    new String:headers[1024];
    ReadPackString(headers_pack, headers, sizeof(headers));

    decl String:request_string[1024];
    decl String:map_votes_url[128], route[128];
    GetConVarString(g_Cvar_MapVotesUrl, map_votes_url, sizeof(map_votes_url));
    //This Formats the headers needed to make a HTTP/1.1 POST request.
    Format(request_string, sizeof(request_string), "POST /%s HTTP/1.1\nHost: %s\nConnection: close\nContent-type: application/x-www-form-urlencoded\nContent-length: %d\n\n%s", route, map_votes_url, strlen(headers), headers);
    //Sends the Request
    SocketSend(socket, request_string);
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:headers_pack) {
    //Used for data received back
}

public OnSocketDisconnected(Handle:socket, any:headers_pack) {
    // Connection: close advises the webserver to close the connection when the transfer is finished
    // we're done here
    CloseHandle(headers_pack);
    CloseHandle(socket);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:headers_pack) {
    // a socket error occured
    LogError("[MapVotes] socket error %d (errno %d)", errorType, errorNum);
    CloseHandle(headers_pack);
    CloseHandle(socket);
}

public MapVotesCall(String:route[128], String:query_params[512])
{
    new port= GetConVarInt(g_Cvar_MapVotesPort);
    decl String:base_url[128], String:api_key[128];
    GetConVarString(g_Cvar_MapVotesUrl, base_url, sizeof(base_url));
    GetConVarString(g_Cvar_MapVotesApiKey, api_key, sizeof(api_key));

    HTTPPost(base_url, route, "test", port);
}
public HTTPPost(String:base_url[128], String:route[128], String:query_params[512], port)
{
    new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
    SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, base_url, port);
}
public WriteMessage(client, String:message[])
{
}

public CastVote(client, value)
{
    //new uid = GetSteamAccountID(client);
    new uid=76561197998903004;

    if(uid <= 0){
        LogError("[MapVotes] invalid user; client(%d) has steamid64 of %ld", client, uid);
    }else if(!(value == -1 || value == 0 || value == 1)){
        LogError("[MapVotes] invalid vote value %d (steam_user: %ld)", value, uid);
    }else{
        decl String:query_params[512], String:map[128];

        GetCurrentMap(map, sizeof(map));

        Format(query_params, sizeof(query_params),
            "map=%s&uid=%s&value=%d", map, uid, value);
        MapVotesCall(CAST_VOTE_ROUTE, query_params);
    }

}

public ServerQuery()
{
}
