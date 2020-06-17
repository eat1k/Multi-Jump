/*
 * Author contact: http://t.me/twisternick or:
 *	- Official topic of the resource in Russian forum: https://dev-cs.ru/threads/2572/
 *	- Official topic of the resource in English forum: https://forums.alliedmods.net/showthread.php?p=2626246#post2626246
 *	- Official topic of the resource in Spanish forum: https://amxmodx-es.com/Thread-Multi-Jump-v1-0?pid=192145#pid192145
 *
 * Changelog:
 *	- 2.0: A lot of fixes. Some code was separated. Now we have this plugin as a core with natives and forwards to create other plugins. Also, I added mj_set_user_jumps native.
 *	- 1.0.1: mj_console_cmd_messages_mode was removed. Now use mj_console_cmd_messages. 0 - disabled; 1 - show messages only to who used the command and who has received multi jumps; 2 - show to everyone.
 *	- 1.0:
 *		- Removed AMX Mod X 1.8.2/1.8.3 support.
 *		- Defines are replaced by CVars.
 *		- Added automatic creation and execution of a configuration file with CVars: "amxmodx/configs/plugins/multi_jump.cfg".
 *		- When buying multi jumps (if CVar mj_purchase_cmd = 1), they are no longer set but added to the current ones.
 *		- New CVars: mj_trail, mj_trail_effect, mj_trail_life, mj_trail_size, mj_trail_brightness (copied from Easy Multijump).
 *		- Added natives: mj_get_user_jumps(id), mj_give_user_jumps(id), mj_remove_user_jumps(id, amount).
 *		- Added a forward: mjfwd_BuyMultiJumps(id) (called when a player buys multi jumps).
 *	- 0.4: Fixed an error.
 *	- 0.3: Fixed a compilation error when defines "MJ_BUY" and "MJ_CONSOLE_CMD" were commented.
 *	- 0.2: Added a pause for a jump during a jump, that is, by scrolling the mouse wheel with a bind +jump in the air, if there are many jumps, they could immediately disappear (thanks to mx?!).
 *	- 0.1: Release.
 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>

#pragma semicolon 1

new const PLUGIN_VERSION[] = "2.0";

/****************************************************************************************
****************************************************************************************/

#define IsPlayerValid(%0) (1 <= %0 <= MaxClients)
#define GetCvarDesc(%0) fmt("%l", %0)

#if !defined MAX_AUTHID_LENGTH
	#define MAX_AUTHID_LENGTH 64
#endif

#if !defined MAX_IP_LENGTH
	#define MAX_IP_LENGTH 16
#endif

new bool:g_bAlive[MAX_PLAYERS+1];
new g_iJumpsDone[MAX_PLAYERS+1];
new g_iJumps[MAX_PLAYERS+1];

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
new bool:g_bTrailEnabled[MAX_PLAYERS+1], Float:g_flTrailTime[MAX_PLAYERS+1];

enum (+= 100)
{
	TASK_ID_TRAIL
};

// Forwards
new g_MFJumpPre, g_MFJumpPost;

public plugin_init()
{
	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "refwd_PlayerSpawn_Post", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "refwd_PlayerKilled_Post", true);
	RegisterHookChain(RG_CBasePlayer_Jump, "refwd_PlayerJump_Pre");

	g_MFJumpPre = CreateMultiForward("MJ_Jump_Pre", ET_CONTINUE, FP_CELL);
	g_MFJumpPost = CreateMultiForward("MJ_Jump_Post", ET_CONTINUE, FP_CELL);
}


public plugin_precache()
{
	register_plugin("Multi Jump", PLUGIN_VERSION, "w0w");
	register_dictionary("multi_jump.ini");

	func_RegisterCvars();

	if(g_eCvar[CVAR_TRAIL])
		g_pSpriteTrail = precache_model("sprites/zbeam5.spr");
}

/****************************************************************************************
****************************************************************************************/

public client_disconnected(id)
{
	g_bAlive[id] = false;
	g_iJumpsDone[id] = 0;
	g_iJumps[id] = 0;

	if(g_eCvar[CVAR_TRAIL])
	{
		remove_task(id);
		g_bTrailEnabled[id] = false;
	}
}

public refwd_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id))
		return HC_CONTINUE;

	g_bAlive[id] = true;
	g_iJumpsDone[id] = 0;

	if(g_eCvar[CVAR_RESET_JUMPS_SPAWN])
		g_iJumps[id] = 0;

	return HC_CONTINUE;
}

public refwd_PlayerKilled_Post(iVictim)
{
	g_bAlive[iVictim] = false;
}

public refwd_PlayerJump_Pre(id)
{
	if(!g_bAlive[id])
		return HC_CONTINUE;

	static iRet;
	ExecuteForward(g_MFJumpPre, iRet, id);

	if(iRet >= PLUGIN_HANDLED)
		return HC_CONTINUE;

	new iFlags = get_entvar(id, var_flags);

	if(g_eCvar[CVAR_AUTO_DOUBLE_JUMP])
	{
		if((!(get_entvar(id, var_oldbuttons) & IN_JUMP)) && iFlags & FL_ONGROUND)
		{
			new Float:flVelocity[3]; get_entvar(id, var_velocity, flVelocity);
			flVelocity[2] = g_eCvar[CVAR_AUTO_DOUBLE_JUMP_VELOCITY];
			set_entvar(id, var_velocity, flVelocity);
		}
	}

	static Float:flJumpTime[MAX_PLAYERS+1];

	if(g_iJumpsDone[id] && (iFlags & FL_ONGROUND))
	{
		g_iJumpsDone[id] = 0;
		flJumpTime[id] = get_gametime();
		return HC_CONTINUE;
	}

	static Float:flGameTime;
	if((get_entvar(id, var_oldbuttons) & IN_JUMP || iFlags & FL_ONGROUND) || ((flGameTime = get_gametime()) - flJumpTime[id]) < 0.2)
		return HC_CONTINUE;

	if(g_iJumpsDone[id] >= g_eCvar[CVAR_ADDITIONAL_JUMPS] && !g_iJumps[id])
		return HC_CONTINUE;

	flJumpTime[id] = flGameTime;
	new Float:flVelocity[3]; get_entvar(id, var_velocity, flVelocity);
	flVelocity[2] = random_float(265.0, 285.0);

	set_entvar(id, var_velocity, flVelocity);
	g_iJumpsDone[id]++;

	if(g_eCvar[CVAR_TRAIL])
	{
		func_TrailMessage(id);
		g_flTrailTime[id] = get_gametime();
	}

	if(g_iJumps[id] && g_iJumpsDone[id] > g_eCvar[CVAR_ADDITIONAL_JUMPS])
		g_iJumps[id]--;

	ExecuteForward(g_MFJumpPost, _, id);

	return HC_CONTINUE;
}

// Set/remove a trail (author: jesuspunk) copied from Easy Multijump 
func_TrailMessage(id)
{
	if(g_bTrailEnabled[id])
		return PLUGIN_CONTINUE;

	static szColor[3];

	enum { RED = 0, GREEN, BLUE };

	if(g_eCvar[CVAR_TRAIL_EFFECT] == 0)
	{
		szColor[RED] = random_num(0, 255);
		szColor[GREEN] = random_num(0, 255);
		szColor[BLUE] = random_num(0, 255);
	}
	else
	{
		switch(get_member(id, m_iTeam))
		{
			case TEAM_TERRORIST: szColor = { 255, 0, 0 };
			case TEAM_CT: szColor = { 0, 0, 255 };
		}
	}

	g_bTrailEnabled[id] = true;

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(id);
	write_short(g_pSpriteTrail);
	write_byte(g_eCvar[CVAR_TRAIL_LIFE] * 10);
	write_byte(g_eCvar[CVAR_TRAIL_SIZE]);
	write_byte(szColor[RED]);
	write_byte(szColor[GREEN]);
	write_byte(szColor[BLUE]);
	write_byte(g_eCvar[CVAR_TRAIL_BRIGHTNESS]);
	message_end();

	g_flTrailTime[id] = get_gametime();
	set_task_ex(1.0, "task_RemoveTrail", id+TASK_ID_TRAIL, .flags = SetTask_RepeatTimes, .repeat = 1);

	return PLUGIN_CONTINUE;
}

public task_RemoveTrail(id)
{
	id -= TASK_ID_TRAIL;

	if(!is_user_alive(id))
	{
		remove_task(id);
		return;
	}

	new Float:flGameTime = get_gametime();

	if(flGameTime - g_flTrailTime[id] < 1.35)
	{
		remove_task(id);
		set_task_ex(1.0, "task_RemoveTrail", id+TASK_ID_TRAIL, .flags = SetTask_RepeatTimes, .repeat = 1);
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

/****************************************************************************************
****************************************************************************************/

func_RegisterCvars()
{
	new pCvar;

	/* Main */
	pCvar = create_cvar("mj_auto_double_jump", "0", FCVAR_NONE, GetCvarDesc("MJ_CVAR_AUTO_DOUBLE_JUMP"), true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar, g_eCvar[CVAR_AUTO_DOUBLE_JUMP]);

	pCvar = create_cvar("mj_auto_double_jump_velocity", "350.0", FCVAR_NONE, GetCvarDesc("MJ_CVAR_AUTO_DOUBLE_JUMP_VELOCITY"), true, 0.0);
	bind_pcvar_float(pCvar, g_eCvar[CVAR_AUTO_DOUBLE_JUMP_VELOCITY]);

	pCvar = create_cvar("mj_additional_jumps", "1", FCVAR_NONE, GetCvarDesc("MJ_CVAR_ADDITIONAL_JUMPS"), true, 1.0);
	bind_pcvar_num(pCvar, g_eCvar[CVAR_ADDITIONAL_JUMPS]);

	pCvar = create_cvar("mj_reset_jumps_spawn", "1", FCVAR_NONE, GetCvarDesc("MJ_CVAR_RESET_JUMPS_SPAWN"), true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar, g_eCvar[CVAR_RESET_JUMPS_SPAWN]);

	/* Trail */
	pCvar = create_cvar("mj_trail", "1", FCVAR_NONE, GetCvarDesc("MJ_CVAR_TRAIL"), true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar, g_eCvar[CVAR_TRAIL]);

	pCvar = create_cvar("mj_trail_effect", "1", FCVAR_NONE, GetCvarDesc("MJ_CVAR_TRAIL_EFFECT"), true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar, g_eCvar[CVAR_TRAIL_EFFECT]);

	pCvar = create_cvar("mj_trail_life", "2", FCVAR_NONE, GetCvarDesc("MJ_CVAR_TRAIL_LIFE"), true, 1.0, true, 25.0);
	bind_pcvar_num(pCvar, g_eCvar[CVAR_TRAIL_LIFE]);

	pCvar = create_cvar("mj_trail_size", "2", FCVAR_NONE, GetCvarDesc("MJ_CVAR_TRAIL_SIZE"), true, 1.0, true, 255.0);
	bind_pcvar_num(pCvar, g_eCvar[CVAR_TRAIL_SIZE]);

	pCvar = create_cvar("mj_trail_brightness", "150", FCVAR_NONE, GetCvarDesc("MJ_CVAR_TRAIL_BRIGHTNESS"), true, 0.0, true, 255.0);
	bind_pcvar_num(pCvar, g_eCvar[CVAR_TRAIL_BRIGHTNESS]);

	AutoExecConfig(true, "multi_jump");
}

/****************************************************************************************
****************************************************************************************/

public plugin_natives()
{
	register_library("multi_jump");

	register_native("mj_get_user_jumps", "__get_user_jumps");
	register_native("mj_give_user_jumps", "__give_user_jumps");
	register_native("mj_set_user_jumps", "__set_user_jumps");
	register_native("mj_remove_user_jumps", "__remove_user_jumps");
}

public __get_user_jumps(amxx, params)
{
	enum { player = 1 };

	new iPlayer = get_param(player);

	if(!IsPlayerValid(iPlayer))
		abort(AMX_ERR_NATIVE, "Player out of range (%d)", iPlayer);

	return g_iJumps[iPlayer];
}

public __give_user_jumps(amxx, params)
{
	enum { player = 1, amount };

	new iPlayer = get_param(player);

	if(!IsPlayerValid(iPlayer))
		abort(AMX_ERR_NATIVE, "Player out of range (%d)", iPlayer);
	
	new iAmount = get_param(amount);

	if(iAmount < 0)
		abort(AMX_ERR_NATIVE, "Amount should be more or equal than zero (%d)", iAmount);

	return g_iJumps[iPlayer] += iAmount;
}

public __set_user_jumps(amxx, params)
{
	enum { player = 1, amount };

	new iPlayer = get_param(player);

	if(!IsPlayerValid(iPlayer))
		abort(AMX_ERR_NATIVE, "Player out of range (%d)", iPlayer);
	
	new iAmount = get_param(amount);

	if(iAmount < 0)
		abort(AMX_ERR_NATIVE, "Amount should be more or equal than zero (%d)", iAmount);

	return g_iJumps[iPlayer] = iAmount;
}

public __remove_user_jumps(amxx, params)
{
	enum { player = 1, amount };

	new iPlayer = get_param(player);

	if(!IsPlayerValid(iPlayer))
		abort(AMX_ERR_NATIVE, "Player out of range (%d)", iPlayer);

	if(!g_iJumps[iPlayer])
		return false;

	new iAmount = get_param(amount);

	if(iAmount < 0)
		abort(AMX_ERR_NATIVE, "Amount should be more than zero (%d)", iAmount);

	if(g_iJumps[iPlayer] < iAmount)
		iAmount = g_iJumps[iPlayer];

	return g_iJumps[iPlayer] -= iAmount;
}