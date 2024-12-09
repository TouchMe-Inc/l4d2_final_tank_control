#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>


public Plugin myinfo = {
	name = "FinaleTankControl",
	author = "Visor, Electr0",
	description = "Setting up tank spawn in the final chapters",
	version = "build0001",
	url = "https://github.com/TouchMe-Inc/l4d2_final_tank_control"
};


#define CMD_FLOW_AND_SECOND_EVENT "tank_map_flow_and_second_event"
#define CMD_ONLY_FIRST_EVENT    "tank_map_only_first_event"
#define CMD_ONLY_SECOND_EVENT   "tank_map_only_second_event"

#define MAP_NAME_MAX_LENGTH     32


enum TankScheme
{
	TankScheme_Default = 0,
	TankScheme_FlowAndSecondEvent,
	TankScheme_FirstEvent,
	TankScheme_SecondEvent
};

TankScheme g_eTankScheme = TankScheme_Default;

Handle g_hTankSchemeMaps = null;

int g_iTankNumber = 0;


public void OnPluginStart()
{
	g_hTankSchemeMaps = CreateTrie();

	RegServerCmd(CMD_FLOW_AND_SECOND_EVENT, Cmd_AddMap);
	RegServerCmd(CMD_ONLY_FIRST_EVENT, Cmd_AddMap);
	RegServerCmd(CMD_ONLY_SECOND_EVENT, Cmd_AddMap);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void Event_RoundStart(Event hEvent, const char[] name, bool dontBroadcast)
{
	char mapname[MAP_NAME_MAX_LENGTH];
	GetCurrentMap(mapname, sizeof(mapname));

	if (!GetTrieValue(g_hTankSchemeMaps, mapname, g_eTankScheme)) {
		g_eTankScheme = TankScheme_Default;
	}

	g_iTankNumber = 0;

	if (g_eTankScheme != TankScheme_Default) {
		L4D2Direct_SetVSTankToSpawnThisRound(InSecondHalfOfRound() ? 1 : 0, (g_eTankScheme == TankScheme_FlowAndSecondEvent));
	}
}

public Action Cmd_AddMap(int iArgs)
{
	char sCmd[64];
	GetCmdArg(0, sCmd, sizeof(sCmd));

	if (iArgs != 1)
	{
		LogError("Usage: %s <mapname>", sCmd);

		return Plugin_Handled;
	}

	char mapname[MAP_NAME_MAX_LENGTH];
	GetCmdArg(1, mapname, sizeof(mapname));

	if (StrEqual(sCmd, CMD_FLOW_AND_SECOND_EVENT, false)) {
		SetTrieValue(g_hTankSchemeMaps, mapname, TankScheme_FlowAndSecondEvent);
	}
	
	else if (StrEqual(sCmd, CMD_ONLY_FIRST_EVENT, false)) {
		SetTrieValue(g_hTankSchemeMaps, mapname, TankScheme_FirstEvent);
	}

	else if (StrEqual(sCmd, CMD_ONLY_SECOND_EVENT, false)) {
		SetTrieValue(g_hTankSchemeMaps, mapname, TankScheme_SecondEvent);
	}

	return Plugin_Handled;
}

public Action L4D2_OnChangeFinaleStage(int &iFinaleType, const char[] arg)
{
	if (!IsTankFinalType(iFinaleType)) {
		return Plugin_Continue;
	}

	g_iTankNumber ++;

	switch (g_eTankScheme)
	{
		case TankScheme_FirstEvent:
		{
			if (g_iTankNumber != 1)
			{
				iFinaleType = FINALE_HORDE_ATTACK_1;
				return Plugin_Changed;
			}
		}

		case TankScheme_SecondEvent, TankScheme_FlowAndSecondEvent:
		{
			if (g_iTankNumber != 2)
			{
				iFinaleType = FINALE_HORDE_ATTACK_1;
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

bool IsTankFinalType(int iFinaleType) {
	return (iFinaleType == FINALE_CUSTOM_TANK || iFinaleType == FINALE_GAUNTLET_BOSS || iFinaleType == FINALE_GAUNTLET_ESCAPE);
}

bool InSecondHalfOfRound() {
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}
