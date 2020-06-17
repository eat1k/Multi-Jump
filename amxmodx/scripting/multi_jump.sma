/*
 * Official resource topic: https://dev-cs.ru/resources/451/
 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>

#pragma semicolon 1

new const PLUGIN_VERSION[] = "2.0.1";

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

#if !defined MAX_AUTHID_LENGTH
	#define MAX_AUTHID_LENGTH 64
#endif

#if !defined MAX_IP_LENGTH
	#define MAX_IP_LENGTH 16
#endif

new g_iJumpsDone[MAX_PLAYERS + 1];
new g_iJumps[MAX_PLAYERS + 1];

enum _:CVARS
{
	CVAR_AUTO_DOUBLE_JUMP,
	Float:CVAR_AUTO_DOUBLE_JUMP_VELOCITY,
	CVAR_ADDITIONAL_JUMPS,

	CVAR_RESET_JUMPS_SPAWN,

	CVAR_TRAIL,
	CVAR_TRAIL_EFFECT,
	CVAR_TRAIL_LIFE,
	CVAR_TRAIL_SIZE,
	CVAR_TRAIL_BRIGHTNESS
};

new g_eCvar[CVARS];

// Trail sprite
new g_pSpriteTrail;
// Trail effect + gametime
new bool:g_bTrailEnabled[MAX_PLAYERS + 1], Float:g_flTrailTime[MAX_PLAYERS + 1];

const TASK_ID_TRAIL = 100;

// Forwards
new g_MFJumpPre, g_MFJumpPost;

public plugin_init()
{
	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "@OnPlayerSpawn_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_Jump, "@OnPlayerJump_Pre", .post = false);

	g_MFJumpPre = CreateMultiForward("MJ_Jump_Pre", ET_CONTINUE, FP_CELL);
	g_MFJumpPost = CreateMultiForward("MJ_Jump_Post", ET_CONTINUE, FP_CELL);
}

public plugin_precache()
{
	register_plugin("Multi Jump", PLUGIN_VERSION, "w0w");
	register_dictionary("multi_jump.txt");

	func_RegisterCvars();

	if (g_eCvar[CVAR_TRAIL])
	{
		g_pSpriteTrail = precache_model("sprites/zbeam5.spr");
	}
}

func_RegisterCvars()
{
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

	bind_pcvar_num(create_cvar(
		.name = "mj_trail",
		.string = "1",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_CVAR_TRAIL"),
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 1.0), g_eCvar[CVAR_TRAIL]);

	bind_pcvar_num(create_cvar(
		.name = "mj_trail_effect",
		.string = "1",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_CVAR_TRAIL_EFFECT"),
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 1.0), g_eCvar[CVAR_TRAIL_EFFECT]);

	bind_pcvar_num(create_cvar(
		.name = "mj_trail_life",
		.string = "2",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_CVAR_TRAIL_LIFE"),
		.has_min = true,
		.min_val = 1.0,
		.has_max = true,
		.max_val = 25.0), g_eCvar[CVAR_TRAIL_LIFE]);

	bind_pcvar_num(create_cvar(
		.name = "mj_trail_size",
		.string = "2",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_CVAR_TRAIL_SIZE"),
		.has_min = true,
		.min_val = 1.0,
		.has_max = true,
		.max_val = 255.0), g_eCvar[CVAR_TRAIL_SIZE]);

	bind_pcvar_num(create_cvar(
		.name = "mj_trail_brightness",
		.string = "150",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_CVAR_TRAIL_BRIGHTNESS"),
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 255.0), g_eCvar[CVAR_TRAIL_BRIGHTNESS]);

	AutoExecConfig(true, "multi_jump");
}

public client_disconnected(id)
{
	g_iJumpsDone[id] = 0;
	g_iJumps[id] = 0;

	if (g_eCvar[CVAR_TRAIL])
	{
		remove_task(id+TASK_ID_TRAIL);
		g_bTrailEnabled[id] = false;
	}
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
	if (!is_user_alive(id))
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

	if (g_eCvar[CVAR_TRAIL])
	{
		func_TrailMessage(id);
		g_flTrailTime[id] = get_gametime();
	}

	if (g_iJumps[id] && g_iJumpsDone[id] > g_eCvar[CVAR_ADDITIONAL_JUMPS])
	{
		g_iJumps[id]--;
	}

	ExecuteForward(g_MFJumpPost, _, id);
	return HC_CONTINUE;
}

// Set/remove a trail (author: jesuspunk) copied from Easy Multijump 
func_TrailMessage(const id)
{
	if (g_bTrailEnabled[id])
	{
		return PLUGIN_CONTINUE;
	}

	static szColor[3];

	enum { RED = 0, GREEN, BLUE };

	if (g_eCvar[CVAR_TRAIL_EFFECT] == 0)
	{
		szColor[RED] = random_num(0, 255);
		szColor[GREEN] = random_num(0, 255);
		szColor[BLUE] = random_num(0, 255);
	}
	else
	{
		switch (get_member(id, m_iTeam))
		{
			case TEAM_TERRORIST:
			{
				szColor = { 255, 0, 0 };
			}
			case TEAM_CT:
			{
				szColor = { 0, 0, 255 };
			}
		}
	}

	g_bTrailEnabled[id] = true;

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	{
		write_byte(TE_BEAMFOLLOW);
		write_short(id);
		write_short(g_pSpriteTrail);
		write_byte(g_eCvar[CVAR_TRAIL_LIFE] * 10);
		write_byte(g_eCvar[CVAR_TRAIL_SIZE]);
		write_byte(szColor[RED]);
		write_byte(szColor[GREEN]);
		write_byte(szColor[BLUE]);
		write_byte(g_eCvar[CVAR_TRAIL_BRIGHTNESS]);
	}
	message_end();

	g_flTrailTime[id] = get_gametime();
	set_task_ex(1.0, "@task_RemoveTrail", id+TASK_ID_TRAIL, .flags = SetTask_RepeatTimes, .repeat = 1);

	return PLUGIN_CONTINUE;
}

@task_RemoveTrail(id)
{
	id -= TASK_ID_TRAIL;

	if (!is_user_alive(id))
	{
		remove_task(id+TASK_ID_TRAIL);
		return;
	}

	new Float:flGameTime = get_gametime();

	if (flGameTime - g_flTrailTime[id] < 1.35)
	{
		remove_task(id+TASK_ID_TRAIL);
		set_task_ex(1.0, "@task_RemoveTrail", id+TASK_ID_TRAIL, .flags = SetTask_RepeatTimes, .repeat = 1);
	}
	else
	{
		g_bTrailEnabled[id] = false;

		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		write_byte(TE_KILLBEAM);
		write_short(id);
		message_end();
	}
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