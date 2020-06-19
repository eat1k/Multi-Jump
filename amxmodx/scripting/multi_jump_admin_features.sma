/*
 * Official resource topic: https://dev-cs.ru/resources/929/
 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <multi_jump>

#pragma semicolon 1

public stock const PluginName[] = "Multi Jump: Admin Features";
public stock const PluginVersion[] = "2.0.1";
public stock const PluginAuthor[] = "twisterniq";
public stock const PluginURL[] = "https://github.com/twisterniq/amxx-multi-jump";
public stock const PluginDescription[] = "Adds such features as giving multi jumps via console command and via menu. Allows to set jumps for X seconds.";

new const CONFIG_NAME[] = "multi_jump_admin_features";

new g_szConsoleCmd[] = "amx_mjgive";
new g_szMenuCmd[] = "amx_mjmenu";

new g_iMenuAccess = ADMIN_BAN;
new g_iConsoleAccess = ADMIN_RCON;

enum _:CVAR_MESSAGE_TYPES
{
	MESSAGE_SHOW_USER_TARGET = 1,
	MESSAGE_SHOW_ALL
};

new g_iMessages;
new g_iLogs;

new g_szLogFile[PLATFORM_MAX_PATH];

new g_iMenuPlayers[MAX_PLAYERS + 1][MAX_PLAYERS], g_iMenuPosition[MAX_PLAYERS + 1];
new g_iTimeSelected[MAX_PLAYERS + 1];
new g_iJumpsSelected[MAX_PLAYERS + 1] = { 1, ... };

public plugin_init()
{
#if AMXX_VERSION_NUM == 190
	register_plugin(
		.plugin_name = PluginName,
		.version = PluginVersion,
		.author = PluginAuthor
	);
#endif

	register_dictionary("multi_jump_admin_features.txt");

	register_clcmd(g_szMenuCmd, "@func_GiveByMenu");
	register_clcmd(g_szConsoleCmd, "@func_GiveByConsole");

	register_clcmd("mj_set_time", "@func_MessageModeSetTime");
	register_clcmd("mj_set_jumps", "@func_MessageModeSetJumps");

	register_menu("func_GiveJumpsMenu", 1023, "@func_GiveJumpsMenu_Handler");

	new pCvarAccess;

	pCvarAccess = create_cvar(
		.name = "mj_admin_menu_access",
		.string = "d",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_ADMIN_CVAR_MENU_ACCESS"));
	set_pcvar_string(pCvarAccess, "");
	hook_cvar_change(pCvarAccess, "@OnMenuAccessChange");

	pCvarAccess = create_cvar(
		.name = "mj_admin_console_access",
		.string = "l",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_ADMIN_CVAR_CONSOLE_ACCESS"));
	set_pcvar_string(pCvarAccess, "");
	hook_cvar_change(pCvarAccess, "@OnConsoleAccessChange");

	bind_pcvar_num(create_cvar(
		"mj_admin_messages",
		.string = "1",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_ADMIN_CVAR_MESSAGES"),
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 2.0), g_iMessages);

	bind_pcvar_num(create_cvar(
		.name = "mj_admin_logs",
		.string = "1",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_ADMIN_CVAR_LOGS"),
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 1.0), g_iLogs);

	AutoExecConfig(true, CONFIG_NAME);

	new szPath[PLATFORM_MAX_PATH];
	get_localinfo("amxx_logs", szPath, charsmax(szPath));
	formatex(g_szLogFile, charsmax(g_szLogFile), "%s/%s.log", szPath, CONFIG_NAME);
}

@OnMenuAccessChange(const iHandle, const szOldValue[], const szNewValue[])
{
	g_iMenuAccess = read_flags(szNewValue);
}

@OnConsoleAccessChange(const iHandle, const szOldValue[], const szNewValue[])
{
	g_iConsoleAccess = read_flags(szNewValue);
}

public client_disconnected(id)
{
	g_iJumpsSelected[id] = 1;
	remove_task(id);
}

@func_GiveByMenu(const id)
{
	if (g_iMenuAccess > 0 && !(get_user_flags(id) & g_iMenuAccess))
	{
		return PLUGIN_HANDLED;
	}

	func_GiveJumpsMenu(id, 0);
	return PLUGIN_HANDLED;
}

func_GiveJumpsMenu(const id, iPage)
{
	if (iPage < 0)
	{
		return;
	}

	new iPlayerCount;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_alive(i) || is_user_bot(i))
		{
			continue;
		}

		g_iMenuPlayers[id][iPlayerCount++] = i;
	}

	SetGlobalTransTarget(id);

	new i = min(iPage * 6, iPlayerCount);
	new iStart = i - (i % 6);
	new iEnd = min(iStart + 6, iPlayerCount);
	g_iMenuPosition[id] = iPage = iStart / 6;

	new szMenu[MAX_MENU_LENGTH], iMenuItem, iKeys = (MENU_KEY_0);
	new iPagesNum = (iPlayerCount / 6 + ((iPlayerCount % 6) ? 1 : 0));
	new iLen = formatex(szMenu, charsmax(szMenu), "\y%l \d\R%d/%d^n^n", "MJ_ADMIN_MENU_TITLE", iPage + 1, iPagesNum);

	for (new a = iStart, iPlayer, iJumpsPlayer; a < iEnd; ++a)
	{
		iPlayer = g_iMenuPlayers[id][a];
		iKeys |= (1<<iMenuItem);

		iJumpsPlayer = mj_get_user_jumps(iPlayer);

		if (!iJumpsPlayer)
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%d. \w%n^n", ++iMenuItem, iPlayer);
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%d. \w%n \d(%d)^n", ++iMenuItem, iPlayer, iJumpsPlayer);
		}
	}

	if (!iMenuItem)
	{
		client_print_color(id, print_team_red, "%l", "MJ_ADMIN_MENU_NO_PLAYERS");
		return;
	}

	if (g_iTimeSelected[id])
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y7. \w%l^n", "MJ_ADMIN_MENU_TIME", g_iTimeSelected[id]);
	}
	else
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y7. \w%l^n", "MJ_ADMIN_MENU_TIME_NOT");
	}
	iKeys |= (MENU_KEY_7);

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y8. \w%l^n", "MJ_ADMIN_MENU_JUMPS", g_iJumpsSelected[id]);
	iKeys |= (MENU_KEY_8);

	if (iEnd != iPlayerCount)
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y9. \w%l^n\y0. \w%l", "MJ_ADMIN_MENU_NEXT", iPage ? "MJ_ADMIN_MENU_BACK" : "MJ_ADMIN_MENU_EXIT");
		iKeys |= (MENU_KEY_9);
	}
	else
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y0. \w%l", iPage ? "MJ_ADMIN_MENU_BACK" : "MJ_ADMIN_MENU_EXIT");
	}

	show_menu(id, iKeys, szMenu, -1, "func_GiveJumpsMenu");
}

@func_GiveJumpsMenu_Handler(const id, iKey)
{
	switch (iKey)
	{
		case 6:
		{
			client_cmd(id, "messagemode mj_set_time");
			func_GiveJumpsMenu(id, g_iMenuPosition[id]);
		}
		case 7:
		{
			client_cmd(id, "messagemode mj_set_jumps");
			func_GiveJumpsMenu(id, g_iMenuPosition[id]);
		}
		case 8:
		{
			func_GiveJumpsMenu(id, ++g_iMenuPosition[id]);
		}
		case 9:
		{
			func_GiveJumpsMenu(id, --g_iMenuPosition[id]);
		}
		default:
		{
			new iTarget = g_iMenuPlayers[id][(g_iMenuPosition[id] * 6) + iKey];

			if (!is_user_alive(iTarget))
			{
				func_GiveJumpsMenu(id, g_iMenuPosition[id]);
				return;
			}

			mj_give_user_jumps(iTarget, g_iJumpsSelected[id]);

			if (g_iTimeSelected[id])
			{
				set_task(float(g_iTimeSelected[id]), "@task_JumpsEndTime", iTarget);
			}

			func_AfterGiveAction(id, iTarget);
			func_GiveJumpsMenu(id, g_iMenuPosition[id]);
		}
	}

}

func_AfterGiveAction(const id, const iTarget)
{
	new szTime[32], szTotalJumps[32];

	if (g_iTimeSelected[id])
	{
		formatex(szTime, charsmax(szTime), " %l", "MJ_ADMIN_FOR_TIME", g_iTimeSelected[id]);
	}

	switch (g_iMessages)
	{
		case MESSAGE_SHOW_USER_TARGET:
		{
			client_print_color(id, iTarget, "%l", "MJ_ADMIN_GIVEN_MSG", g_iJumpsSelected[id], szTime, iTarget);

			if (iTarget != id)
			{
				new iJumpsPlayer = mj_get_user_jumps(iTarget);

				if (iJumpsPlayer > g_iJumpsSelected[id])
				{
					formatex(szTotalJumps, charsmax(szTotalJumps), "%s%l", g_iTimeSelected[id] ? " " : ". ", "MJ_ADMIN_TOTAL_JUMPS", iJumpsPlayer);
				}

				client_print_color(iTarget, print_team_default, "%l", "MJ_ADMIN_GIVEN_PLAYER_TARGET", id, g_iJumpsSelected[id], szTime, szTotalJumps);
			}
		}
		case MESSAGE_SHOW_ALL:
		{
			client_print_color(0, iTarget, "%l", "MJ_ADMIN_GIVEN_MSG_ALL", id, g_iJumpsSelected[id], szTime, iTarget);
		}
	}

	if (g_iLogs)
	{
		new szAuthID[MAX_AUTHID_LENGTH], szIP[MAX_IP_LENGTH];
		get_user_authid(id, szAuthID, charsmax(szAuthID));
		get_user_ip(id, szIP, charsmax(szIP), 1);

		new szTargetAuthID[MAX_AUTHID_LENGTH], szTargetIP[MAX_IP_LENGTH];
		get_user_authid(iTarget, szTargetAuthID, charsmax(szTargetAuthID));
		get_user_ip(iTarget, szTargetIP, charsmax(szTargetIP), 1);

		log_to_file(g_szLogFile, "%l", "MJ_ADMIN_GIVEN_ONE_LOG",
			id, szAuthID, szIP,
			g_iJumpsSelected[id],
			iTarget, szTargetAuthID, szTargetIP);
	}
}

@func_MessageModeSetTime(const id)
{
	enum { arg_health = 1 };

	new szArgTime[5];
	read_argv(arg_health, szArgTime, charsmax(szArgTime));

	if (!szArgTime[0])
	{
		client_print_color(id, print_team_red, "%l", "MJ_ADMIN_ERROR_MENU_ZERO");
		return PLUGIN_HANDLED;
	}

	if (szArgTime[0])
	{
		if (!is_digit_arg(szArgTime))
		{
			client_print_color(id, print_team_red, "%l", "MJ_ADMIN_ERROR_MENU_DIGIT");
			return PLUGIN_HANDLED;
		}

		g_iTimeSelected[id] = str_to_num(szArgTime);
		func_GiveJumpsMenu(id, g_iMenuPosition[id]);
	}

	return PLUGIN_HANDLED;
}

@func_MessageModeSetJumps(const id)
{
	enum { arg_health = 1 };

	new szJumps[5];
	read_argv(arg_health, szJumps, charsmax(szJumps));

	if (!szJumps[0])
	{
		client_print_color(id, print_team_red, "%l", "MJ_ADMIN_ERROR_MENU_ZERO");
		return PLUGIN_HANDLED;
	}

	if (szJumps[0])
	{
		if (!is_digit_arg(szJumps))
		{
			client_print_color(id, print_team_red, "%l", "MJ_ADMIN_ERROR_MENU_DIGIT");
			return PLUGIN_HANDLED;
		}

		g_iJumpsSelected[id] = str_to_num(szJumps);
		func_GiveJumpsMenu(id, g_iMenuPosition[id]);
	}

	return PLUGIN_HANDLED;
}

@func_GiveByConsole(const id)
{
	if (g_iConsoleAccess > 0 && !(get_user_flags(id) & g_iConsoleAccess))
	{
		return PLUGIN_HANDLED;
	}

	enum { arg_name = 1, arg_amount, arg_time };

	new szArgName[MAX_NAME_LENGTH], szArgJumps[10];
	read_argv(arg_name, szArgName, charsmax(szArgName));
	read_argv(arg_amount, szArgJumps, charsmax(szArgJumps));

	if (!szArgName[0] || szArgJumps[0] && (!is_digit_arg(szArgJumps) || szArgJumps[0] < '1'))
	{
		console_print(id, "%l", "MJ_ADMIN_ERROR_USAGE", g_szConsoleCmd);
		return PLUGIN_HANDLED;
	}

	new iJumps = szArgJumps[0] ? str_to_num(szArgJumps) : 1;

	new szArgTime[5];
	read_argv(arg_time, szArgTime, charsmax(szArgTime));

	new iTime;

	if (szArgTime[0])
	{
		if (!is_digit_arg(szArgTime))
		{
			console_print(id, "%l", "MJ_ADMIN_ERROR_USAGE", g_szConsoleCmd);
			return PLUGIN_HANDLED;
		}

		iTime = str_to_num(szArgTime);
	}

	new szTime[32], szTotalJumps[64];

	if (iTime)
	{
		formatex(szTime, charsmax(szTime), " %l", "MJ_ADMIN_FOR_TIME", iTime);
	}

	new iPlayers[MAX_PLAYERS], iPlayerCount, i, iPlayer;
	get_players_ex(iPlayers, iPlayerCount, GetPlayers_ExcludeDead|GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV);

	new iSelected;

	enum { SELECTED_T, SELECTED_CT, SELECTED_ALL, SELECTED_TARGET };

	if (!strcmp(szArgName, "T"))
	{
		iSelected = SELECTED_T;
	}
	else if (!strcmp(szArgName, "CT"))
	{
		iSelected = SELECTED_CT;
	}
	else if (!strcmp(szArgName, "ALL"))
	{
		iSelected = SELECTED_ALL;
	}
	else
	{
		iSelected = SELECTED_TARGET;
	}

	if (SELECTED_T <= iSelected <= SELECTED_ALL)
	{
		new iCount;
		for (i = 0; i < iPlayerCount; i++)
		{
			iPlayer = iPlayers[i];

			switch(iSelected)
			{
				case SELECTED_T:
				{
					if (get_member(iPlayer, m_iTeam) != TEAM_TERRORIST)
					{
						continue;
					}
				}
				case SELECTED_CT:
				{
					if (get_member(iPlayer, m_iTeam) != TEAM_CT)
					{
						continue;
					}
				}
				case SELECTED_ALL:
				{
					if (!(TEAM_TERRORIST <= get_member(iPlayer, m_iTeam) <= TEAM_CT))
					{
						continue;
					}
				}
			}

			iCount++;
			mj_give_user_jumps(iPlayer, iJumps);

			if (iTime)
			{
				set_task(float(iTime), "@task_JumpsEndTime", iPlayer);
			}

			if (g_iMessages == MESSAGE_SHOW_USER_TARGET)
			{
				if (iPlayer != id)
				{
					new iJumpsPlayer = mj_get_user_jumps(iPlayer);

					if (iJumpsPlayer > iJumps)
					{
						formatex(szTotalJumps, charsmax(szTotalJumps), "%s%l", iTime ? " " : ". ", "MJ_ADMIN_TOTAL_JUMPS", iJumpsPlayer);
					}

					client_print_color(iPlayer, print_team_default, "%l", "MJ_ADMIN_GIVEN_PLAYER_TARGET", id, iJumps, szTime, szTotalJumps);
				}
			}
		}

		if (!iCount)
		{
			console_print(id, "%l", "MJ_ADMIN_ERROR_NOPLAYERS");
			return PLUGIN_HANDLED;
		}

		new szTeam[64];

		switch(iSelected)
		{
			case SELECTED_T:
			{
				formatex(szTeam, charsmax(szTeam), "%L", id, "MJ_ADMIN_MSG_T");
			}
			case SELECTED_CT:
			{
				formatex(szTeam, charsmax(szTeam), "%L", id, "MJ_ADMIN_MSG_CT");
			}
			case SELECTED_ALL:
			{
				formatex(szTeam, charsmax(szTeam), "%L", id, "MJ_ADMIN_MSG_ALL");
			}
		}

		switch (g_iMessages)
		{
			case MESSAGE_SHOW_USER_TARGET:
			{
				client_print_color(id, print_team_red, "%l", "MJ_ADMIN_GIVEN_MSG", iJumps, szTime, szTeam);
			}
			case MESSAGE_SHOW_ALL:
			{
				client_print_color(0, print_team_red, "%l", "MJ_ADMIN_GIVEN_MSG_ALL", id, iJumps, szTime, szTeam);
			}
		}

		if (g_iLogs)
		{
			new szAuthID[MAX_AUTHID_LENGTH], szIP[MAX_IP_LENGTH];
			get_user_authid(id, szAuthID, charsmax(szAuthID));
			get_user_ip(id, szIP, charsmax(szIP), 1);

			log_to_file(g_szLogFile, "%l", "MJ_ADMIN_GIVEN_TEAM_LOG", id, szAuthID, szIP, iJumps, szTeam);
		}

		return PLUGIN_HANDLED;
	}
	else
	{
		new iTarget = cmd_target(id, szArgName, CMDTARGET_ALLOW_SELF);

		if (!iTarget)
		{
			return PLUGIN_HANDLED;
		}

		if (!is_user_alive(iTarget))
		{
			console_print(id, "%l", "MJ_ADMIN_ERROR_DEAD");
			return PLUGIN_HANDLED;
		}

		mj_give_user_jumps(iTarget, iJumps);

		if (iTime)
		{
			set_task(float(iTime), "@task_JumpsEndTime", iTarget);
		}

		switch (g_iMessages)
		{
			case MESSAGE_SHOW_USER_TARGET:
			{
				client_print_color(id, iTarget, "%l", "MJ_ADMIN_GIVEN_MSG", iJumps, szTime, iTarget);

				if (iTarget != id)
				{
					new iJumpsPlayer = mj_get_user_jumps(iTarget);

					if (iJumpsPlayer > iJumps)
					{
						formatex(szTotalJumps, charsmax(szTotalJumps), "%s%l", iTime ? " " : ". ", "MJ_ADMIN_TOTAL_JUMPS", iJumpsPlayer);
					}

					client_print_color(iTarget, print_team_default, "%l", "MJ_ADMIN_GIVEN_PLAYER_TARGET", id, iJumps, szTime, szTotalJumps);
				}
			}
			case MESSAGE_SHOW_ALL:
			{
				client_print_color(0, iTarget, "%l", "MJ_ADMIN_GIVEN_MSG_ALL", id, iJumps, szTime, iTarget);
			}
		}

		if (g_iLogs)
		{
			new szAuthID[MAX_AUTHID_LENGTH], szIP[MAX_IP_LENGTH];
			get_user_authid(id, szAuthID, charsmax(szAuthID));
			get_user_ip(id, szIP, charsmax(szIP), 1);

			new szTargetAuthID[MAX_AUTHID_LENGTH], szTargetIP[MAX_IP_LENGTH];
			get_user_authid(iTarget, szTargetAuthID, charsmax(szTargetAuthID));
			get_user_ip(iTarget, szTargetIP, charsmax(szTargetIP), 1);

			log_to_file(g_szLogFile, "%l", "MJ_ADMIN_GIVEN_ONE_LOG",
				id, szAuthID, szIP,
				iJumps,
				iTarget, szTargetAuthID, szTargetIP);
		}
	}

	return PLUGIN_HANDLED;
}

@task_JumpsEndTime(id)
{
	if (!is_user_alive(id) || !mj_get_user_jumps(id))
	{
		remove_task(id);
		return PLUGIN_HANDLED;
	}

	mj_set_user_jumps(id, 0);
	client_print_color(id, print_team_default, "%l", "MJ_TIME_ENDED");

	return PLUGIN_HANDLED;
}

stock is_digit_arg(szArg[])
{
	new bool:bIsDigit = true;
	new iLen = strlen(szArg);

	for (new iCharacter; iCharacter < iLen; iCharacter++)
	{
		if (!isdigit(szArg[iCharacter]))
		{
			bIsDigit = false;
			break;
		}
	}

	return bIsDigit;
}