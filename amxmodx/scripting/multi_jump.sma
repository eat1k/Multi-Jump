/*
 * Official resource topic: https://dev-cs.ru/resources/451/
 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>

#pragma semicolon 1

public stock const PluginName[] = "Multi Jump: Core";
public stock const PluginVersion[] = "3.0.0";
public stock const PluginAuthor[] = "twisterniq";
public stock const PluginURL[] = "https://github.com/twisterniq/amxx-multi-jump";
public stock const PluginDescription[] = "Adds the possibiltity to jump more times. It provides an API.";

#define CHECK_NATIVE_PLAYER(%0) \
    if (!(1 <= %0 <= MaxClients)) \
	{ \
        abort(AMX_ERR_NATIVE, "Player out of range (%d)", %0); \
    }

#define CHECK_NATIVE_AMOUNT(%0) \
    if (%0 < 0) \
	{ \
        abort(AMX_ERR_NATIVE, "Amount must be greater than or equal to zero (%d)", %0); \
    }

new g_iJumpsDone[MAX_PLAYERS + 1];
new g_iJumps[MAX_PLAYERS + 1];

enum _:CVARS
{
	CVAR_ENABLED,
	CVAR_AUTO_DOUBLE_JUMP,
	Float:CVAR_AUTO_DOUBLE_JUMP_VELOCITY,
	CVAR_ADDITIONAL_JUMPS,
	CVAR_RESET_JUMPS_SPAWN
};

new g_eCvar[CVARS];

// Forwards
new g_MFJumpPre, g_MFJumpPost;

public plugin_init()
{
#if AMXX_VERSION_NUM == 190
	register_plugin(
		.plugin_name = PluginName,
		.version = PluginVersion,
		.author = PluginAuthor
	);
#endif

	register_dictionary("multi_jump.txt");

	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "@OnPlayerSpawn_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_Jump, "@OnPlayerJump_Pre", .post = false);

	g_MFJumpPre = CreateMultiForward("MJ_Jump_Pre", ET_CONTINUE, FP_CELL);
	g_MFJumpPost = CreateMultiForward("MJ_Jump_Post", ET_CONTINUE, FP_CELL);

	bind_pcvar_num(create_cvar(
		.name = "mj_enabled",
		.string = "1",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_CVAR_ENABLED"),
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 1.0), g_eCvar[CVAR_ENABLED]);

	bind_pcvar_num(create_cvar(
		.name = "mj_auto_double_jump",
		.string = "0",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_CVAR_AUTO_DOUBLE_JUMP"),
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 1.0), g_eCvar[CVAR_AUTO_DOUBLE_JUMP]);

	bind_pcvar_float(create_cvar(
		.name = "mj_auto_double_jump_velocity",
		.string = "350.0",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_CVAR_AUTO_DOUBLE_JUMP_VELOCITY"),
		.has_min = true,
		.min_val = 0.0), g_eCvar[CVAR_AUTO_DOUBLE_JUMP_VELOCITY]);

	bind_pcvar_num(create_cvar(
		.name = "mj_additional_jumps",
		.string = "1",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_CVAR_ADDITIONAL_JUMPS"),
		.has_min = true,
		.min_val = 1.0), g_eCvar[CVAR_ADDITIONAL_JUMPS]);

	bind_pcvar_num(create_cvar(
		.name = "mj_reset_jumps_spawn",
		.string = "1",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_CVAR_RESET_JUMPS_SPAWN"),
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 1.0), g_eCvar[CVAR_RESET_JUMPS_SPAWN]);

	AutoExecConfig(true, "multi_jump");
}

public client_disconnected(id)
{
	g_iJumpsDone[id] = 0;
	g_iJumps[id] = 0;
}

@OnPlayerSpawn_Post(const id)
{
	if (!is_user_alive(id))
	{
		return HC_CONTINUE;
	}

	g_iJumpsDone[id] = 0;

	if (g_eCvar[CVAR_RESET_JUMPS_SPAWN])
	{
		g_iJumps[id] = 0;
	}

	return HC_CONTINUE;
}

@OnPlayerJump_Pre(id)
{
	if (!g_eCvar[CVAR_ENABLED] || !is_user_alive(id))
	{
		return HC_CONTINUE;
	}

	static iRet;
	ExecuteForward(g_MFJumpPre, iRet, id);

	if (iRet >= PLUGIN_HANDLED)
	{
		return HC_CONTINUE;
	}

	new iFlags = get_entvar(id, var_flags);

	if (g_eCvar[CVAR_AUTO_DOUBLE_JUMP])
	{
		if ((!(get_entvar(id, var_oldbuttons) & IN_JUMP)) && iFlags & FL_ONGROUND)
		{
			new Float:flVelocity[3];
			get_entvar(id, var_velocity, flVelocity);
			flVelocity[2] = g_eCvar[CVAR_AUTO_DOUBLE_JUMP_VELOCITY];

			set_entvar(id, var_velocity, flVelocity);
		}
	}

	static Float:flJumpTime[MAX_PLAYERS + 1];

	if (g_iJumpsDone[id] && (iFlags & FL_ONGROUND))
	{
		g_iJumpsDone[id] = 0;
		flJumpTime[id] = get_gametime();

		return HC_CONTINUE;
	}

	static Float:flGameTime;

	if ((get_entvar(id, var_oldbuttons) & IN_JUMP || iFlags & FL_ONGROUND) || ((flGameTime = get_gametime()) - flJumpTime[id]) < 0.2)
	{
		return HC_CONTINUE;
	}

	if (g_iJumpsDone[id] >= g_eCvar[CVAR_ADDITIONAL_JUMPS] && !g_iJumps[id])
	{
		return HC_CONTINUE;
	}

	flJumpTime[id] = flGameTime;

	new Float:flVelocity[3];
	get_entvar(id, var_velocity, flVelocity);
	flVelocity[2] = random_float(265.0, 285.0);

	set_entvar(id, var_velocity, flVelocity);

	g_iJumpsDone[id]++;

	if (g_iJumps[id] && g_iJumpsDone[id] > g_eCvar[CVAR_ADDITIONAL_JUMPS])
	{
		g_iJumps[id]--;
	}

	ExecuteForward(g_MFJumpPost, _, id);
	return HC_CONTINUE;
}

public plugin_natives()
{
	register_library("multi_jump");

	register_native("mj_get_user_jumps",	"@Native_GetUserJumps");
	register_native("mj_give_user_jumps",	"@Native_GiveUserJumps");
	register_native("mj_set_user_jumps",	"@Native_SetUserJumps");
	register_native("mj_remove_user_jumps",	"@Native_RemoveUserJumps");
}

@Native_GetUserJumps(const iPlugin, const iParams)
{
	enum { arg_player = 1 };

	new iPlayer = get_param(arg_player);

	CHECK_NATIVE_PLAYER(iPlayer)

	return g_iJumps[iPlayer];
}

@Native_GiveUserJumps(const iPlugin, const iParams)
{
	enum { arg_player = 1, arg_amount };

	new iPlayer = get_param(arg_player);

	CHECK_NATIVE_PLAYER(iPlayer)
	
	new iAmount = get_param(arg_amount);

	CHECK_NATIVE_AMOUNT(iAmount)

	return g_iJumps[iPlayer] += iAmount;
}

@Native_SetUserJumps(const iPlugin, const iParams)
{
	enum { arg_player = 1, arg_amount };

	new iPlayer = get_param(arg_player);

	CHECK_NATIVE_PLAYER(iPlayer)
	
	new iAmount = get_param(arg_amount);

	CHECK_NATIVE_AMOUNT(iAmount)

	return g_iJumps[iPlayer] = iAmount;
}

@Native_RemoveUserJumps(const iPlugin, const iParams)
{
	enum { arg_player = 1, arg_amount };

	new iPlayer = get_param(arg_player);

	CHECK_NATIVE_PLAYER(iPlayer)

	if (!g_iJumps[iPlayer])
	{
		return 0;
	}

	new iAmount = get_param(arg_amount);

	CHECK_NATIVE_AMOUNT(iAmount)

	if (g_iJumps[iPlayer] < iAmount)
	{
		iAmount = g_iJumps[iPlayer];
	}

	return g_iJumps[iPlayer] -= iAmount;
}