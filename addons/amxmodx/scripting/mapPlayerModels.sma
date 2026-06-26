/*
*
*	Map Player Models by RedSMURF
*
*
*	Description:
*
*	Cvars:
*		None
*
*	Commands:
*
*	Changelog:
*       v1.0: Initial release.
*       v1.1: Supports sub-models
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>

#define MAX_SUBMODELS   20
#define SET_MODEL_DELAY 0.5
#define SET_MODEL_TASK  1357

new const PLUGIN_VERSION[] = "1.1"

new Array:g_aModelT, Array:g_aModelCT,
    g_szLastModel[MAX_PLAYERS + 1][32],
    g_szCurrentModel[MAX_PLAYERS + 1][32],
    g_szArgModel[MAX_PLAYERS + 1][32],
    g_iCurrentSubModel[MAX_PLAYERS + 1],
    bool:g_bFileWasRead = false,
    g_iModelT, g_iModelCT,
    bool:g_bFoundMap

enum _:MODEL
{
    MODEL_NAME[32],
    bool:MODEL_SUBMODEL,
    MODEL_SUBMODEL_LIST[MAX_SUBMODELS],
    MODEL_SUBMODEL_LIST_COUNT
}

public plugin_init()
{
    register_plugin("Map Player Models", PLUGIN_VERSION, "RedSMURF")

    register_forward(FM_SetClientKeyValue, "fwdSetKeyValue", 1)
}

public plugin_precache()
{
    g_aModelT = ArrayCreate(MODEL)
    g_aModelCT = ArrayCreate(MODEL)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aModelT)
    ArrayDestroy(g_aModelCT)
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        g_iModelT = 0
        g_iModelCT = 0
        g_bFoundMap = false

        ArrayClear(g_aModelT)
        ArrayClear(g_aModelCT)
    }

    new g_szFileName[128]
    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/MapPlayerModels.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[128], szKey[32], szValue[128],
        eModel[MODEL], szCurrentMap[32], szToken[4]

    get_mapname(szCurrentMap, charsmax(szCurrentMap))

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        if ( g_bFoundMap )
        {
            if ( szData[0] == '[' )
                break

            strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
            trim(szKey)
            trim(szValue)

            if ( equali(szKey, "T") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ',')
                trim(szKey)
                trim(szValue)

                while ( szKey[0] )
                {
                    strtok(szKey, szKey, charsmax(szKey), szData, charsmax(szData), ':')
                    trim(szKey); trim(szData)
                    copy(eModel[MODEL_NAME], charsmax(eModel[MODEL_NAME]), szKey)

                    eModel[MODEL_SUBMODEL] = false
                    eModel[MODEL_SUBMODEL_LIST_COUNT] = 0

                    if ( szData[0] )
                    {
                        eModel[MODEL_SUBMODEL] = true

                        while( szData[0] && eModel[MODEL_SUBMODEL_LIST_COUNT] < MAX_SUBMODELS )
                        {
                            strtok(szData, szToken, charsmax(szToken), szData, charsmax(szData), ' ')
                            eModel[MODEL_SUBMODEL_LIST][eModel[MODEL_SUBMODEL_LIST_COUNT] ++] = str_to_num(szToken)
                        }
                    }

                    formatex(szData, charsmax(szData), "models/player/%s/%s.mdl", szKey, szKey)
                    precache_model(szData)

                    ArrayPushArray(g_aModelT, eModel)
                    g_iModelT ++

                    trim(szValue)
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ',')
                    trim(szKey)
                }
            }
            else if ( equali(szKey, "CT") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ',')
                trim(szKey)
                trim(szValue)

                while ( szKey[0] )
                {
                    strtok(szKey, szKey, charsmax(szKey), szData, charsmax(szData), ':')
                    trim(szKey); trim(szData)
                    copy(eModel[MODEL_NAME], charsmax(eModel[MODEL_NAME]), szKey)

                    eModel[MODEL_SUBMODEL] = false
                    eModel[MODEL_SUBMODEL_LIST_COUNT] = 0

                    if ( szData[0] )
                    {
                        eModel[MODEL_SUBMODEL] = true

                        while( szData[0] && eModel[MODEL_SUBMODEL_LIST_COUNT] < MAX_SUBMODELS )
                        {
                            strtok(szData, szToken, charsmax(szToken), szData, charsmax(szData), ' ')
                            eModel[MODEL_SUBMODEL_LIST][eModel[MODEL_SUBMODEL_LIST_COUNT] ++] = str_to_num(szToken)
                        }
                    }

                    formatex(szData, charsmax(szData), "models/player/%s/%s.mdl", szKey, szKey)
                    precache_model(szData)

                    ArrayPushArray(g_aModelCT, eModel)
                    g_iModelCT ++

                    trim(szValue)
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ',')
                    trim(szKey)
                }
            }
        }
        else
        {
            if ( szData[0] != '['
            || szData[strlen(szData) - 1] != ']' )
                continue

            replace(szData, charsmax( szData ), "[", "")
            replace(szData, charsmax( szData ), "]", "")
            trim(szData)

            if ( !equali(szData, szCurrentMap) )
                continue

            g_bFoundMap = true
        }
    }

    g_bFileWasRead = true
    fclose(iFile)
}

public client_disconnected(id)
{
    g_szLastModel[id][0] = EOS
    g_szCurrentModel[id][0] = EOS
    g_szArgModel[id][0] = EOS

    remove_task(id + SET_MODEL_TASK)
}

public fwdSetKeyValue(id, szInfo[], szKey[], szValue[])
{
    if ( !g_bFoundMap
    || !equal(szKey, "model") )
        return FMRES_IGNORED

    copy(g_szArgModel[id], charsmax(g_szArgModel[]), szValue)
    remove_task(id + SET_MODEL_TASK)
    set_task(SET_MODEL_DELAY, "SetModel", id + SET_MODEL_TASK)
    return FMRES_IGNORED
}

public SetModel(iTask)
{
    new id = iTask - SET_MODEL_TASK
    if ( cs_get_user_team(id) == CS_TEAM_SPECTATOR )
        return;

    new eModel[MODEL], CsTeams:iCurrentTeam
    iCurrentTeam = cs_get_user_team(id)

    if ( !equali(g_szLastModel[id], g_szArgModel[id]) )
    {
        copy(g_szLastModel[id], charsmax(g_szLastModel[]), g_szArgModel[id])

        if ( iCurrentTeam == CS_TEAM_T && g_iModelT > 0 )
        {
            ArrayGetArray(g_aModelT, random(g_iModelT), eModel)
            copy(g_szCurrentModel[id], charsmax(g_szCurrentModel[]), eModel[MODEL_NAME])

            if ( eModel[MODEL_SUBMODEL] && eModel[MODEL_SUBMODEL_LIST_COUNT] > 0 )
                g_iCurrentSubModel[id] = eModel[MODEL_SUBMODEL_LIST][random(eModel[MODEL_SUBMODEL_LIST_COUNT])]
            else
                g_iCurrentSubModel[id] = -1
        }
        else if ( iCurrentTeam == CS_TEAM_CT && g_iModelCT > 0 )
        {
            ArrayGetArray(g_aModelCT, random(g_iModelCT), eModel)
            copy(g_szCurrentModel[id], charsmax(g_szCurrentModel[]), eModel[MODEL_NAME])

            if ( eModel[MODEL_SUBMODEL] && eModel[MODEL_SUBMODEL_LIST_COUNT] > 0 )
                g_iCurrentSubModel[id] = eModel[MODEL_SUBMODEL_LIST][random(eModel[MODEL_SUBMODEL_LIST_COUNT])]
            else
                g_iCurrentSubModel[id] = -1
        }
        else
        {
            return;
        }
    }

    cs_set_user_model(id, g_szCurrentModel[id], true)
    if ( g_iCurrentSubModel[id] != -1 )
        set_pev(id, pev_body, g_iCurrentSubModel[id])
}