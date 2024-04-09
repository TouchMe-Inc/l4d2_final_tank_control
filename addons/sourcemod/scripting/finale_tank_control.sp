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


#define MAP_NAME_MAX_LENGTH     32


enum TankScheme
{
    TankScheme_Default = 0,
    TankScheme_FlowAndSecondEvent,
    TankScheme_FirstEvent,
    TankScheme_SecondEvent,
    TankScheme_FlowAndSecondEventByReplace,
    TankScheme_FirstEventByReplace,
    TankScheme_SecondEventByReplace
};

enum struct TankCmdMap {
    char cmd[64];
    TankScheme scheme;
}

TankCmdMap g_TankCmds[] = {
    {"tank_map_flow_and_second_event",            TankScheme_FlowAndSecondEvent},
    {"tank_map_only_first_event",                 TankScheme_FirstEvent},
    {"tank_map_only_second_event",                TankScheme_SecondEvent},
    {"tank_map_flow_and_second_event_by_replace", TankScheme_FlowAndSecondEventByReplace},
    {"tank_map_only_first_event_by_replace",      TankScheme_FirstEventByReplace},
    {"tank_map_only_second_event_by_replace",     TankScheme_SecondEventByReplace}
};


TankScheme g_eTankScheme = TankScheme_Default;

Handle g_hTankSchemeMaps = null;

int g_iTankNumber = 0;


public void OnPluginStart()
{
    g_hTankSchemeMaps = CreateTrie();

    for (int i = 0; i < sizeof(g_TankCmds); i++) {
        RegServerCmd(g_TankCmds[i].cmd, Cmd_AddMap);
    }

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void Event_RoundStart(Event hEvent, const char[] name, bool dontBroadcast)
{
    char szMapName[MAP_NAME_MAX_LENGTH];
    GetCurrentMap(szMapName, sizeof(szMapName));

    if (!GetTrieValue(g_hTankSchemeMaps, szMapName, g_eTankScheme)) {
        g_eTankScheme = TankScheme_Default;
    }

    g_iTankNumber = 0;

    if (g_eTankScheme != TankScheme_Default) {
        L4D2Direct_SetVSTankToSpawnThisRound(InSecondHalfOfRound(), (g_eTankScheme == TankScheme_FlowAndSecondEvent || g_eTankScheme == TankScheme_FlowAndSecondEventByReplace));
    }
}

public Action Cmd_AddMap(int iArgs)
{
    char szCmd[64];
    GetCmdArg(0, szCmd, sizeof(szCmd));

    if (iArgs != 1)
    {
        LogError("Usage: %s <mapname>", szCmd);

        return Plugin_Handled;
    }

    char szMapName[MAP_NAME_MAX_LENGTH];
    GetCmdArg(1, szMapName, sizeof szMapName);

    for (int i = 0; i < sizeof(g_TankCmds); i++)
    {
        if (StrEqual(szCmd, g_TankCmds[i].cmd, false)) {
            SetTrieValue(g_hTankSchemeMaps, szMapName, g_TankCmds[i].scheme);
            break;
        }
    }

    return Plugin_Handled;
}

public Action L4D2_OnChangeFinaleStage(int &iFinaleType, const char[] arg)
{
    if (!IsTankFinalType(iFinaleType)) {
        return Plugin_Continue;
    }

    if (ShouldHandleTank(g_eTankScheme, ++g_iTankNumber))
    {
        switch (g_eTankScheme) {
            case TankScheme_FirstEventByReplace, TankScheme_SecondEventByReplace,
                TankScheme_FlowAndSecondEventByReplace: {
                iFinaleType = FINALE_HORDE_ATTACK_1;
                return Plugin_Changed;
            }
        }

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

bool ShouldHandleTank(TankScheme scheme, int iTankNumber)
{
    switch (scheme)
    {
        case TankScheme_FirstEvent, TankScheme_FirstEventByReplace:
            return iTankNumber != 1;

        case TankScheme_SecondEvent, TankScheme_FlowAndSecondEvent,
             TankScheme_SecondEventByReplace, TankScheme_FlowAndSecondEventByReplace:
            return iTankNumber != 2;
    }

    return false;
}

bool IsTankFinalType(int iFinaleType) {
    return (iFinaleType == FINALE_CUSTOM_TANK || iFinaleType == FINALE_GAUNTLET_BOSS || iFinaleType == FINALE_GAUNTLET_ESCAPE);
}

bool InSecondHalfOfRound() {
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}
