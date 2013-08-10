/**
 * vim: set ts=4 :
 * =============================================================================
 * map_votes
 * TODO - Add your project's description
 *
 * Copyright 2013 The Crimson Tautology
 * =============================================================================
 *
 */


#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION 0.1

public Plugin:myinfo =
{
    name = "",
    author = "",
    description = "",
    version = PLUGIN_VERSION,
    url = ""
};

new Handle:g_Cvar_MapVotesUrl = INVALID_HANDLE;
new Handle:g_Cvar_MapVotesApiKey = INVALID_HANDLE;

public OnPluginStart()
{
    
    g_Cvar_MapVotesUrl = CreateConVar(sm_map_votes_url, "1", "TODO - Add a description for this cvar");
    g_Cvar_MapVotesApiKey = CreateConVar(sm_map_votes_api_key, "1", "TODO - Add a description for this cvar");
    
    RegConsoleCmd("sm_vote_down", Command_VoteDown, "TODO - Add a description for this cmd");
    RegConsoleCmd("sm_map_comment", Command_MapComment, "TODO - Add a description for this cmd");
    RegConsoleCmd("sm_call_vote", Command_CallVote, "TODO - Add a description for this cmd");
    
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

