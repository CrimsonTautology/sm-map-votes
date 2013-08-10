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
#include <base64>

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
#define SERVER_QUERY_ROUTE "/v1/api/server_query"

#define MAX_STEAMID_LENGTH 21 
#define MAX_COMMUNITYID_LENGTH 18 


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
    RegConsoleCmd("sm_mc", Command_MapComment, "Comment on the current map");
    RegConsoleCmd("sm_call_vote", Command_CallVote, "Popup a vote panel to every player on the server that has not yet voted on this map");

}


public Action:Command_VoteMenu(client, args)
{
    //TODO
}

public Action:Command_VoteUp(client, args)
{
    if(client && IsClientAuthorized(client)){
        CastVote(client, 1);
    }
}

public Action:Command_VoteDown(client, args)
{
    if(client && IsClientAuthorized(client)){
        CastVote(client, -1);
    }
}

public Action:Command_MapComment(client, args)
{
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

public Action:Command_CallVote(client, args)
{
    //TODO
}

public OnSocketConnected(Handle:socket, any:headers_pack)
{
    decl String:request_string[1024];
    decl String:base_url[128], String:route[128];

    ResetPack(headers_pack);
    new String:headers[1024];
    ReadPackString(headers_pack, headers, sizeof(headers));
    ReadPackString(headers_pack, route, sizeof(route));
    ReadPackString(headers_pack, base_url, sizeof(base_url));


    //This Formats the headers needed to make a HTTP/1.1 POST request.
    Format(request_string, sizeof(request_string), "POST %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\nContent-type: application/x-www-form-urlencoded\r\nContent-length: %d\r\n\r\n%s", route, base_url, strlen(headers), headers);
    //PrintToConsole(0,"%s", request_string);//TODO
    SocketSend(socket, request_string);
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:headers_pack) {
    //Used for data received back
    PrintToConsole(0,"%s", receiveData);//TODO
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


//By 11530
//GetSteamAccountID(client) does not work because we don't have 64 bit types
stock bool:GetCommunityIDString(const String:SteamID[], String:CommunityID[], const CommunityIDSize) 
{ 
    decl String:SteamIDParts[3][11]; 
    new const String:Identifier[] = "76561197960265728"; 

    if ((CommunityIDSize < 1) || (ExplodeString(SteamID, ":", SteamIDParts, sizeof(SteamIDParts), sizeof(SteamIDParts[])) != 3)) 
    { 
        CommunityID[0] = '\0'; 
        return false; 
    } 

    new Current, CarryOver = (SteamIDParts[1][0] == '1'); 
    for (new i = (CommunityIDSize - 2), j = (strlen(SteamIDParts[2]) - 1), k = (strlen(Identifier) - 1); i >= 0; i--, j--, k--) 
    { 
        Current = (j >= 0 ? (2 * (SteamIDParts[2][j] - '0')) : 0) + CarryOver + (k >= 0 ? ((Identifier[k] - '0') * 1) : 0); 
        CarryOver = Current / 10; 
        CommunityID[i] = (Current % 10) + '0'; 
    } 

    CommunityID[CommunityIDSize - 1] = '\0'; 
    return true; 
}  

public MapVotesCall(String:route[128], String:query_params[512])
{
    new port= GetConVarInt(g_Cvar_MapVotesPort);
    decl String:base_url[128], String:api_key[128];
    GetConVarString(g_Cvar_MapVotesUrl, base_url, sizeof(base_url));
    GetConVarString(g_Cvar_MapVotesApiKey, api_key, sizeof(api_key));

    Format(query_params, sizeof(query_params), "%s&access_token=%s", query_params, api_key);

    HTTPPost(base_url, route, query_params, port);
}

public HTTPPost(String:base_url[128], String:route[128], String:query_params[512], port)
{
    new String:host[256];
    new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);

    new Handle:headers_pack = CreateDataPack();
    WritePackString(headers_pack, query_params);
    WritePackString(headers_pack, route);
    WritePackString(headers_pack, base_url);
    SocketSetArg(socket, headers_pack);

    SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, base_url, port);
}
public WriteMessage(client, String:message[256])
{
    //Encode the message to be url safe
    decl String:base64[256], String:base64_url[256];
    EncodeBase64(base64, sizeof(base64), message);
    Base64MimeToUrl(base64_url, sizeof(base64_url), base64);

    decl String:buffer[MAX_STEAMID_LENGTH], String:uid[MAX_COMMUNITYID_LENGTH];
    GetClientAuthString(client, buffer, sizeof(buffer));
    GetCommunityIDString(buffer, uid, sizeof(uid));

    decl String:query_params[512], String:map[128];
    GetCurrentMap(map, sizeof(map));
    Format(query_params, sizeof(query_params),
            "map=%s&uid=%s&comment=%s&base64=true", map, uid, base64);

    MapVotesCall(WRITE_MESSAGE_ROUTE, query_params);
}

public CastVote(client, value)
{
    //new uid = GetClientAuthString(client);
    //38637
    //STEAM_0:0:19318638
    //new String:uid[64]="76561197998903004";

    decl String:buffer[MAX_STEAMID_LENGTH], String:uid[MAX_COMMUNITYID_LENGTH];
    GetClientAuthString(client, buffer, sizeof(buffer));
    GetCommunityIDString(buffer, uid, sizeof(uid));

    if(!(value == -1 || value == 0 || value == 1)){
        LogError("[MapVotes] invalid vote value %d (steam_user: %s)", value, uid);
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
