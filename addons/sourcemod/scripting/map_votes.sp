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

new Handle:g_Cvar_MapVotesUrl = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesApiKey = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesVotingEnabled = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesCommentingEnabled = INVALID_HANDLE;

public OnPluginStart()
{

    g_Cvar_MapVotesUrl = CreateConVar("sm_map_votes_url", "", "URL to your Map Votes web page");
    g_Cvar_MapVotesApiKey = CreateConVar("sm_map_votes_api_key", "", "The API key you generated to interact with the Map Votes web page");
    g_Cvar_MapVotesApiKey = CreateConVar("sm_map_votes_voting_enabled", "1", "Whether players are allowed to vote on the current map");
    g_Cvar_MapVotesApiKey = CreateConVar("sm_map_votes_commenting_enabled", "1", "Whether players are allowed to comment on the current map");

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
    //TODO
}

public Action:Command_VoteDown(client, args)
{
    //TODO
}

public Action:Command_MapComment(client, args)
{
    //TODO
}

public Action:Command_CallVote(client, args)
{
    //TODO
}

public OnSocketConnected(Handle:socket, any:headers_pack)
{
    ResetPack(headers_pack)
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

public WriteMessage(client, String:message[])
{
    new Handle:socket = SocketCreate(SOCKET_TCP, OnPostError);
    decl String:hostname[128], String:url[128], String:request[2048], String:authToken[64], String:postdata[2048];
    GetConVarString(djUrlCvar, url, sizeof(url));
    new Handle:pack = CreateDataPack();
    WritePackCell(pack, client);
    WritePackCell(pack, 2); // 1 = adding, 2 = deleting, 3 = modifying
    ReplaceString(url, sizeof(url), "http://", "", false);
    if(SplitString(url, "/", hostname, sizeof(hostname)) == -1) {
        LogError("Bad URL input");
        return;
    }
    ReplaceString(url, sizeof(url), hostname, "", false);
    GetConVarString(authKeyCvar, authToken, sizeof(authToken));
    Format(postdata, sizeof(postdata), "auth=%s&id=%s&method=2", authToken, selection);
    Format(request, sizeof(request), "POST %s/playlist.php HTTP/1.1\r\nHost: %s\r\nContent-Length: %i\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\n\r\n%s", url, hostname, strlen(postdata), postdata);
    WritePackString(pack, request);
    SocketSetArg(socket, pack);
    SocketConnect(socket, OnPostConnected, OnPostReceive, OnPostDisconnected, hostname, GetConVarInt(djUrlPortCvar));
}

public CastVote(client, value)
{
}

public ServerQuery()
{
}
