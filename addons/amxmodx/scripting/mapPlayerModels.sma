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
*       None
*
*	Changelog:
*       v1.0: Initial release.
*       v1.1: Supports sub-models
*       v1.2: Added rank-based model pools (USER/VIP/ADMIN/OWNER)
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 32
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_SUBMODELS   20
#define SET_MODEL_DELAY 1.0
#define SET_MODEL_TASK  310092

new const PLUGIN_VERSION[]          = "1.2"
new const ERROR_FILE[]              = "Charger_ERRORS.log"

enum _:PLAYER_DATA
{
    PDATA_ADMIN_FLAGS,
    PDATA_LAST_MODEL[MAX_VALUE_LENGTH],
    PDATA_CURRENT_MODEL[MAX_VALUE_LENGTH],
    PDATA_ARG_MODEL[MAX_VALUE_LENGTH],
    PDATA_CURRENT_SUBMODEL
}

enum _:RANK
{
    RANK_USER,
    RANK_VIP,
    RANK_ADMIN,
    RANK_OWNER
}

enum
{
    SECTION_NONE,
    SECTION_RANK,
    SECTION_MAP
}

new g_eRank[RANK], Array:g_aModelT[RANK], Array:g_aModelCT[RANK],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
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
    for ( new i = 0; i < RANK; i++ )
    {
        g_aModelT[i] = ArrayCreate(MODEL)
        g_aModelCT[i] = ArrayCreate(MODEL)
    }

    ReadFile()
}

public plugin_end()
{
    for ( new i = 0; i < RANK; i++ )
    {
        ArrayDestroy(g_aModelT[i])
        ArrayDestroy(g_aModelCT[i])
    }
}

ReadFile()
{
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
        szCurrentMap[32], iSection, iLine, iPos

    get_mapname(szCurrentMap, charsmax(szCurrentMap))
    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))
        trim(szData)
        iLine ++

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( g_bFoundMap )
                    break

                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax( szData ), "[", "")
                    replace(szData, charsmax( szData ), "]", "")
                    trim(szData)

                    if ( equali(szData, "Rank") )
                    {
                        iSection = SECTION_RANK
                    }
                    else if ( equali(szData, szCurrentMap) )
                    {
                        iSection = SECTION_MAP
                        g_bFoundMap = true
                    }
                }
            }
            default:
            {
                strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                iPos = contain(szValue, "#")
                if ( iPos != -1 )
                    szValue[iPos] = EOS

                trim(szKey)
                trim(szValue)

                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_RANK:
                    {
                        if ( equali(szKey, "USER") )
                            g_eRank[RANK_USER] = read_flags(szValue)
                        else if ( equali(szKey, "VIP") )
                            g_eRank[RANK_VIP] = read_flags(szValue)
                        else if ( equali(szKey, "ADMIN") )
                            g_eRank[RANK_ADMIN] = read_flags(szValue)
                        else if ( equali(szKey, "OWNER") )
                            g_eRank[RANK_OWNER] = read_flags(szValue)
                    }
                    case SECTION_MAP:
                    {
                        if ( equali(szKey, "T") )
                            parseModel(szValue, charsmax(szValue), g_aModelT[RANK_USER])
                        else if ( equali(szKey, "T_VIP") )
                            parseModel(szValue, charsmax(szValue), g_aModelT[RANK_VIP])
                        else if ( equali(szKey, "T_ADMIN") )
                            parseModel(szValue, charsmax(szValue), g_aModelT[RANK_ADMIN])
                        else if ( equali(szKey, "T_OWNER") )
                            parseModel(szValue, charsmax(szValue), g_aModelT[RANK_OWNER])
                        else if ( equali(szKey, "CT") )
                            parseModel(szValue, charsmax(szValue), g_aModelCT[RANK_USER])
                        else if ( equali(szKey, "CT_VIP") )
                            parseModel(szValue, charsmax(szValue), g_aModelCT[RANK_VIP])
                        else if ( equali(szKey, "CT_ADMIN") )
                            parseModel(szValue, charsmax(szValue), g_aModelCT[RANK_ADMIN])
                        else if ( equali(szKey, "CT_OWNER") )
                            parseModel(szValue, charsmax(szValue), g_aModelCT[RANK_OWNER])
                    }
                }
            }
        }
    }

    fclose(iFile)
}

public client_putinserver(id)
{
    g_ePlayerData[id][PDATA_LAST_MODEL][0] = EOS
    g_ePlayerData[id][PDATA_CURRENT_MODEL][0] = EOS
    g_ePlayerData[id][PDATA_ARG_MODEL][0] = EOS
    g_ePlayerData[id][PDATA_CURRENT_SUBMODEL] = -1
}

public client_disconnected(id)
{
    remove_task(id + SET_MODEL_TASK)
    client_putinserver(id)
}

public fwdSetKeyValue(id, szInfo[], szKey[], szValue[])
{
    if ( !g_bFoundMap
    || !is_user_connected(id)
    || !equal(szKey, "model") )
        return FMRES_IGNORED

    if ( equali(szValue, g_ePlayerData[id][PDATA_CURRENT_MODEL]) )
        return FMRES_IGNORED

    copy(g_ePlayerData[id][PDATA_ARG_MODEL], charsmax(g_ePlayerData[][PDATA_ARG_MODEL]), szValue)
    remove_task(id + SET_MODEL_TASK)
    set_task(SET_MODEL_DELAY, "SetModel", id + SET_MODEL_TASK)
    return FMRES_IGNORED
}

public SetModel(iTask)
{
    new id = iTask - SET_MODEL_TASK
    if ( !is_user_connected(id)
    || cs_get_user_team(id) == CS_TEAM_SPECTATOR )
        return;

    new eModel[MODEL], CsTeams:iCurrentTeam, iRank
    iCurrentTeam = cs_get_user_team(id)
    iRank = getRank(id, iCurrentTeam)

    g_ePlayerData[id][PDATA_ADMIN_FLAGS] = get_user_flags(id)
    if ( !equali(g_ePlayerData[id][PDATA_LAST_MODEL], g_ePlayerData[id][PDATA_ARG_MODEL]) )
    {
        copy(g_ePlayerData[id][PDATA_LAST_MODEL], charsmax(g_ePlayerData[][PDATA_LAST_MODEL]), g_ePlayerData[id][PDATA_ARG_MODEL])

        if ( iCurrentTeam == CS_TEAM_T && ArraySize(g_aModelT[iRank]) )
        {
            ArrayGetArray(g_aModelT[iRank], random(ArraySize(g_aModelT[iRank])), eModel)
            copy(g_ePlayerData[id][PDATA_CURRENT_MODEL], charsmax(g_ePlayerData[][PDATA_CURRENT_MODEL]), eModel[MODEL_NAME])

            if ( eModel[MODEL_SUBMODEL] && eModel[MODEL_SUBMODEL_LIST_COUNT] > 0 )
                g_ePlayerData[id][PDATA_CURRENT_SUBMODEL] = eModel[MODEL_SUBMODEL_LIST][random(eModel[MODEL_SUBMODEL_LIST_COUNT])]
            else
                g_ePlayerData[id][PDATA_CURRENT_SUBMODEL] = -1
        }
        else if ( iCurrentTeam == CS_TEAM_CT && ArraySize(g_aModelCT[iRank]) )
        {
            ArrayGetArray(g_aModelCT[iRank], random(ArraySize(g_aModelCT[iRank])), eModel)
            copy(g_ePlayerData[id][PDATA_CURRENT_MODEL], charsmax(g_ePlayerData[][PDATA_CURRENT_MODEL]), eModel[MODEL_NAME])

            if ( eModel[MODEL_SUBMODEL] && eModel[MODEL_SUBMODEL_LIST_COUNT] > 0 )
                g_ePlayerData[id][PDATA_CURRENT_SUBMODEL] = eModel[MODEL_SUBMODEL_LIST][random(eModel[MODEL_SUBMODEL_LIST_COUNT])]
            else
                g_ePlayerData[id][PDATA_CURRENT_SUBMODEL] = -1
        }
        else
        {
            return;
        }
    }

    cs_set_user_model(id, g_ePlayerData[id][PDATA_CURRENT_MODEL], true)
    if ( g_ePlayerData[id][PDATA_CURRENT_SUBMODEL] != -1 )
        set_pev(id, pev_body, g_ePlayerData[id][PDATA_CURRENT_SUBMODEL])
}

stock getRank(id, CsTeams:iTeam)
{
    for ( new i = RANK_OWNER; i > RANK_USER; i -- )
    {
        if ( g_eRank[i] && g_ePlayerData[id][PDATA_ADMIN_FLAGS] & g_eRank[i]
        && ArraySize(CsTeams:iTeam == CS_TEAM_T ? g_aModelT[i] : g_aModelCT[i]) )
            return i
    }

    return RANK_USER
}

stock parseModel(szValue[], iValueLen, any:aModel)
{
    new szKey[64], szData[64], szToken[8],
        eModel[MODEL]

    strtok(szValue, szKey, charsmax(szKey), szValue, iValueLen, ',')
    trim(szKey)

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

            while ( szData[0] && eModel[MODEL_SUBMODEL_LIST_COUNT] < MAX_SUBMODELS )
            {
                strtok(szData, szToken, charsmax(szToken), szData, charsmax(szData), ' ')
                trim(szToken)
                if ( szToken[0] )
                    eModel[MODEL_SUBMODEL_LIST][eModel[MODEL_SUBMODEL_LIST_COUNT] ++] = str_to_num(szToken)
            }
        }

        if ( strlen(szKey) >= charsmax(eModel[MODEL_NAME]) )
        {
            log_amx("Model name too long: %s", szKey)
        }
        else
        {
            formatex(szData, charsmax(szData), "models/player/%s/%s.mdl", szKey, szKey)

            if ( file_exists(szData) )
            {
                copy(eModel[MODEL_NAME], charsmax(eModel[MODEL_NAME]), szKey)
                precache_model(szData)
                ArrayPushArray(aModel, eModel)
            }
            else
                log_amx("Model not found: %s", szData)
        }

        trim(szValue)
        strtok(szValue, szKey, charsmax(szKey), szValue, iValueLen, ',')
        trim(szKey)
    }
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}