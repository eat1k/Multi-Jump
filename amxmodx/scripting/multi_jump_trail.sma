/*
 * Official resource topic: https://dev-cs.ru/resources/1013/
 *
 * Credits: jesuspunk, Easy Multijump author
 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <multi_jump>

public stock const PluginName[] = "Multi Jump: Trail";
public stock const PluginVersion[] = "1.0.0";
public stock const PluginAuthor[] = "twisterniq";
public stock const PluginURL[] = "https://github.com/twisterniq/amxx-multi-jump";
public stock const PluginDescription[] = "Adds a trail for the player in multi jump";

new g_pSpriteTrail;

enum _:CVARS
{
	CVAR_TRAIL,
	CVAR_TRAIL_EFFECT,
	CVAR_TRAIL_LIFE,
	CVAR_TRAIL_SIZE,
	CVAR_TRAIL_BRIGHTNESS
};

new g_eCvar[CVARS];

const TASK_ID_TRAIL = 100;

new bool:g_bTrailEnabled[MAX_PLAYERS + 1], Float:g_flTrailTime[MAX_PLAYERS + 1];

public plugin_precache()
{
    g_pSpriteTrail = precache_model("sprites/zbeam5.spr");
}

public plugin_init()
{
#if AMXX_VERSION_NUM == 190
	register_plugin(
		.plugin_name = PluginName,
		.version = PluginVersion,
		.author = PluginAuthor
	);
#endif

	register_dictionary("multi_jump_trail.txt");

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

	AutoExecConfig(true, "multi_jump_trail");
}

public client_disconnected(id)
{
    remove_task(id + TASK_ID_TRAIL);
    g_bTrailEnabled[id] = false;
}

public MJ_Jump_Post(const id)
{
	if (!g_eCvar[CVAR_TRAIL])
	{
		return;
	}

	func_TrailMessage(id);
	g_flTrailTime[id] = get_gametime();
}

func_TrailMessage(const id)
{
	if (g_bTrailEnabled[id])
	{
		return;
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
	set_task_ex(1.0, "@task_RemoveTrail", id + TASK_ID_TRAIL, .flags = SetTask_RepeatTimes, .repeat = 1);
}

@task_RemoveTrail(id)
{
	id -= TASK_ID_TRAIL;

	if (!is_user_alive(id))
	{
		remove_task(id + TASK_ID_TRAIL);
		return;
	}

	new Float:flGameTime = get_gametime();

	if (flGameTime - g_flTrailTime[id] < 1.35)
	{
		remove_task(id+TASK_ID_TRAIL);
		set_task_ex(1.0, "@task_RemoveTrail", id + TASK_ID_TRAIL, .flags = SetTask_RepeatTimes, .repeat = 1);
	}
	else
	{
		g_bTrailEnabled[id] = false;

		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		{
			write_byte(TE_KILLBEAM);
			write_short(id);
		}
		message_end();
	}
}