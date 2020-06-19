/*
 * Author: https://t.me/twisternick (https://dev-cs.ru/members/444/)
 *
 * Official resource topic: https://dev-cs.ru/resources/451/
 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <multi_jump>

#pragma semicolon 1

new const PLUGIN_VERSION[] = "1.0";

/****************************************************************************************
****************************************************************************************/

new g_szConsoleCmd[]	= "amx_mjgive";
new g_szMenuCmd[]		= "amx_mjmenu";

/****************************************************************************************
****************************************************************************************/

#define GetCvarDesc(%0) fmt("%l", %0)

new g_iAccess = ADMIN_RCON;
new g_iMessages;
new g_iLogs;

new g_szLogFile[PLATFORM_MAX_PATH];

// Menu
new g_iMenuPlayers[MAX_PLAYERS+1][MAX_PLAYERS], g_iMenuPosition[MAX_PLAYERS+1];
new g_iTimeSelected[MAX_PLAYERS+1], g_iJumpsSelected[MAX_PLAYERS+1];

public plugin_init()
{
	register_plugin("Multi Jump: Admin", PLUGIN_VERSION, "w0w");
	register_dictionary("multi_jump_admin.ini");

	register_clcmd(g_szConsoleCmd, "func_ConsoleCmdGive");
	register_clcmd(g_szMenuCmd, "func_MenuCmdGive");

	register_clcmd("mj_set_time", "func_MessageModeSetTime");
	register_clcmd("mj_set_jumps", "func_MessageModeSetJumps");

	register_menu("func_GiveJumpsMenu", (MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0), "func_GiveJumpsMenu_Handler");

	/* Cvars */
	new pCvar;

	pCvar = create_cvar("mj_admin_access", "t", FCVAR_NONE, GetCvarDesc("MJ_ADMIN_CVAR_ACCESS"));
	hook_cvar_change(pCvar, "hook_CvarChange_Access");

	pCvar = create_cvar("mj_admin_console_access", "l", FCVAR_NONE, GetCvarDesc("MJ_ADMIN_CVAR_CONSOLE_ACCESS"));
	hook_cvar_change(pCvar, "hook_CvarChange_Access");

	pCvar = create_cvar("mj_admin_messages", "1", FCVAR_NONE, GetCvarDesc("MJ_ADMIN_CVAR_MESSAGES"), true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar, g_iMessages);

	pCvar = create_cvar("mj_admin_logs", "1", FCVAR_NONE, GetCvarDesc("MJ_ADMIN_CVAR_LOGS"), true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar, g_iLogs);

	AutoExecConfig(true, "multi_jump_admin");

	/* Logs */
	new szLogsDir[PLATFORM_MAX_PATH];
	get_localinfo("amxx_logs", szLogsDir, charsmax(szLogsDir));

	formatex(g_szLogFile, charsmax(g_szLogFile), "%s/multi_jump_admin.log", szLogsDir);
}

public client_putinserver(id)
{
	g_iJumpsSelected[id] = 1;
}

public func_MenuCmdGive(id)
{
	if(g_iAccess > 0 && !(get_user_flags(id) & g_iAccess))
		return PLUGIN_HANDLED;

	func_GiveJumpsMenu(id, 0);

	return PLUGIN_CONTINUE;
}

// Menu command
func_GiveJumpsMenu(id, iPage)
{
	if(iPage < 0)
		return PLUGIN_HANDLED;

	new iPlayerCount;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_alive(i) || is_user_bot(i))
			continue;

		g_iMenuPlayers[id][iPlayerCount++] = i;
	}

	new i = min(iPage * 6, iPlayerCount);
	new iStart = i - (i % 6);
	new iEnd = min(iStart + 6, iPlayerCount);
	g_iMenuPosition[id] = iPage = iStart / 6;

	new szMenu[MAX_MENU_LENGTH], iMenuItem, iKeys = (MENU_KEY_0), iPagesNum = (iPlayerCount / 6 + ((iPlayerCount % 6) ? 1 : 0));

	new iLen = formatex(szMenu, charsmax(szMenu), "\y%l \d\R%d/%d^n^n", "MJ_ADMIN_MENU_TITLE", iPage + 1, iPagesNum);

	for(new a = iStart, iPlayer, iJumpsPlayer; a < iEnd; ++a)
	{
		iPlayer = g_iMenuPlayers[id][a];
		iKeys |= (1<<iMenuItem);

		iJumpsPlayer = mj_get_user_jumps(iPlayer);

		if(!iJumpsPlayer)
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%d. \w%n^n", ++iMenuItem, iPlayer);
		else
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%d. \w%n \d(%d)^n", ++iMenuItem, iPlayer, iJumpsPlayer);
	}

	if(!iMenuItem)
	{
		client_print_color(id, print_team_red, "%l", "MJ_ADMIN_MENU_NO_PLAYERS");
		return PLUGIN_HANDLED;
	}

	if(g_iTimeSelected[id])
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y7. \w%l^n", "MJ_ADMIN_MENU_TIME", g_iTimeSelected[id]);
	else
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y7. \w%l^n", "MJ_ADMIN_MENU_TIME_NOT");
	iKeys |= (MENU_KEY_7);

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y8. \w%l^n", "MJ_ADMIN_MENU_JUMPS", g_iJumpsSelected[id]);
	iKeys |= (MENU_KEY_8);

	if(iEnd != iPlayerCount)
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y9. \w%l^n\y0. \w%l", "MJ_ADMIN_MENU_NEXT", iPage ? "MJ_ADMIN_MENU_BACK" : "MJ_ADMIN_MENU_EXIT");
		iKeys |= (MENU_KEY_9);
	}
	else
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\y0. \w%l", iPage ? "MJ_ADMIN_MENU_BACK" : "MJ_ADMIN_MENU_EXIT");

	show_menu(id, iKeys, szMenu, -1, "func_GiveJumpsMenu");
	return PLUGIN_HANDLED;
}

public func_GiveJumpsMenu_Handler(id, iKey)
{
	switch(iKey)
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
		case 8: func_GiveJumpsMenu(id, ++g_iMenuPosition[id]);
		case 9: func_GiveJumpsMenu(id, --g_iMenuPosition[id]);
		default:
		{
			new iTarget = g_iMenuPlayers[id][(g_iMenuPosition[id] * 6) + iKey];
			if(!is_user_alive(iTarget))
				return func_GiveJumpsMenu(id, g_iMenuPosition[id]);

			mj_give_user_jumps(iTarget, g_iJumpsSelected[id]);

			if(g_iTimeSelected[id])
				set_task(float(g_iTimeSelected[id]), "func_JumpsEndTime", iTarget);

			func_AfterGiveAction(id, iTarget);
			func_GiveJumpsMenu(id, g_iMenuPosition[id]);
		}
	}
	return PLUGIN_HANDLED;
}

func_AfterGiveAction(id, iTarget)
{
	new szTime[32], szTotalJumps[32];

	if(g_iTimeSelected[id])
		formatex(szTime, charsmax(szTime), " %l", "MJ_ADMIN_FOR_TIME", g_iTimeSelected[id]);

	switch(g_iMessages)
	{
		case 1:
		{
			client_print_color(id, iTarget, "%l", "MJ_ADMIN_GIVEN_MSG", g_iJumpsSelected[id], szTime, iTarget);
			if(iTarget != id)
			{
				new iJumpsPlayer = mj_get_user_jumps(iTarget);

				if(iJumpsPlayer > g_iJumpsSelected[id])
					formatex(szTotalJumps, charsmax(szTotalJumps), "%s%l", g_iTimeSelected[id] ? " " : ". ", "MJ_ADMIN_TOTAL_JUMPS", iJumpsPlayer);
				client_print_color(iTarget, print_team_default, "%l", "MJ_ADMIN_GIVEN_PLAYER_TARGET", id, g_iJumpsSelected[id], szTime, szTotalJumps);
			}
		}
		case 2: client_print_color(0, iTarget, "%l", "MJ_ADMIN_GIVEN_MSG_ALL", id, g_iJumpsSelected[id], szTime, iTarget);
	}

	if(g_iLogs)
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

public func_MessageModeSetTime(id)
{
	enum { health = 1 };

	new szArgTime[5];
	read_argv(health, szArgTime, charsmax(szArgTime));

	if(!szArgTime[0])
	{
		client_print_color(id, print_team_red, "%l", "MJ_ADMIN_ERROR_MENU_ZERO");
		return PLUGIN_HANDLED;
	}

	if(szArgTime[0])
	{
		if(!is_digit_arg(szArgTime))
		{
			client_print_color(id, print_team_red, "%l", "MJ_ADMIN_ERROR_MENU_DIGIT");
			return PLUGIN_HANDLED;
		}

		g_iTimeSelected[id] = str_to_num(szArgTime);
		func_GiveJumpsMenu(id, g_iMenuPosition[id]);
	}

	return PLUGIN_HANDLED;
}

public func_MessageModeSetJumps(id)
{
	enum { health = 1 };

	new szJumps[5];
	read_argv(health, szJumps, charsmax(szJumps));

	if(!szJumps[0])
	{
		client_print_color(id, print_team_red, "%l", "MJ_ADMIN_ERROR_MENU_ZERO");
		return PLUGIN_HANDLED;
	}

	if(szJumps[0])
	{
		if(!is_digit_arg(szJumps))
		{
			client_print_color(id, print_team_red, "%l", "MJ_ADMIN_ERROR_MENU_DIGIT");
			return PLUGIN_HANDLED;
		}

		g_iJumpsSelected[id] = str_to_num(szJumps);
		func_GiveJumpsMenu(id, g_iMenuPosition[id]);
	}

	return PLUGIN_HANDLED;
}

// Console command
public func_ConsoleCmdGive(id)
{
	if(g_iAccess > 0 && !(get_user_flags(id) & g_iAccess))
		return PLUGIN_HANDLED;

	enum { name = 1, amount };

	new szArg[MAX_NAME_LENGTH], szArgJumps[10];
	read_argv(name, szArg, charsmax(szArg));
	read_argv(amount, szArgJumps, charsmax(szArgJumps));

	if(!szArg[0] || szArgJumps[0] && (!is_digit_arg(szArgJumps) || szArgJumps[0] < '1'))
	{
		client_print(id, print_console, "%l", "MJ_ADMIN_ERROR_USAGE", g_szConsoleCmd);
		return PLUGIN_HANDLED;
	}

	new iJumps = szArgJumps[0] ? str_to_num(szArgJumps) : 1;

	new szArgTime[5];
	read_argv(3, szArgTime, charsmax(szArgTime));

	new iTime;
	if(szArgTime[0])
	{
		if(!is_digit_arg(szArgTime))
		{
			client_print(id, print_console, "%l", "MJ_ADMIN_ERROR_USAGE", g_szConsoleCmd);
			return PLUGIN_HANDLED;
		}

		iTime = str_to_num(szArgTime);
	}

	new szTime[32], szTotalJumps[64];

	if(iTime)
		formatex(szTime, charsmax(szTime), " %l", "MJ_ADMIN_FOR_TIME", iTime);

	new iPlayers[MAX_PLAYERS], iPlayerCount, i, iPlayer;
	get_players_ex(iPlayers, iPlayerCount, GetPlayers_ExcludeDead|GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV);

	new szTeam[64];

	if(equal(szArg, "T"))
	{
		new iCount;
		for(i = 0; i < iPlayerCount; i++)
		{
			iPlayer = iPlayers[i];

			if(get_member(iPlayer, m_iTeam) != TEAM_TERRORIST)
				continue;

			iCount++;
			mj_give_user_jumps(iPlayer, iJumps);

			if(iTime)
				set_task(float(iTime), "func_JumpsEndTime", iPlayer);

			if(g_iMessages == 1)
			{
				if(iPlayer != id)
				{
					new iJumpsPlayer = mj_get_user_jumps(iPlayer);

					if(iJumpsPlayer > iJumps)
						formatex(szTotalJumps, charsmax(szTotalJumps), "%s%l", iTime ? " " : ". ", "MJ_ADMIN_TOTAL_JUMPS", iJumpsPlayer);
					client_print_color(iPlayer, print_team_default, "%l", "MJ_ADMIN_GIVEN_PLAYER_TARGET", id, iJumps, szTime, szTotalJumps);
				}
			}
		}

		if(!iCount)
		{
			client_print(id, print_console, "%l", "MJ_ADMIN_ERROR_NOPLAYERS");
			return PLUGIN_HANDLED;
		}

		formatex(szTeam, charsmax(szTeam), "%l", "MJ_ADMIN_MSG_T");

		switch(g_iMessages)
		{
			case 0: client_print_color(id, print_team_red, "%l", "MJ_ADMIN_GIVEN_MSG", iJumps, szTime, szTeam);
			case 1: client_print_color(0, print_team_red, "%l", "MJ_ADMIN_GIVEN_MSG_ALL", id, iJumps, szTime, szTeam);
		}

		if(g_iLogs)
		{
			new szAuthID[MAX_AUTHID_LENGTH], szIP[MAX_IP_LENGTH];
			get_user_authid(id, szAuthID, charsmax(szAuthID));
			get_user_ip(id, szIP, charsmax(szIP), 1);

			log_to_file(g_szLogFile, "%l", "MJ_ADMIN_GIVEN_TEAM_LOG", id, szAuthID, szIP, iJumps, szTeam);
		}

		return PLUGIN_HANDLED;
	}
	else if(equal(szArg, "CT"))
	{
		new iCount;
		for(i = 0; i < iPlayerCount; i++)
		{
			iPlayer = iPlayers[i];

			if(get_member(iPlayer, m_iTeam) != TEAM_CT)
				continue;

			iCount++;
			mj_give_user_jumps(iPlayer, iJumps);

			if(iTime)
				set_task(float(iTime), "func_JumpsEndTime", iPlayer);

			if(g_iMessages == 1)
			{
				if(iPlayer != id)
				{
					new iJumpsPlayer = mj_get_user_jumps(iPlayer);

					if(iJumpsPlayer > iJumps)
						formatex(szTotalJumps, charsmax(szTotalJumps), "%s%l", iTime ? " " : ". ", "MJ_ADMIN_TOTAL_JUMPS", iJumpsPlayer);
					client_print_color(iPlayer, print_team_default, "%l", "MJ_ADMIN_GIVEN_PLAYER_TARGET", id, iJumps, szTime, szTotalJumps);
				}
			}
		}

		if(!iCount)
		{
			client_print(id, print_console, "%l", "MJ_ADMIN_ERROR_NOPLAYERS");
			return PLUGIN_HANDLED;
		}

		formatex(szTeam, charsmax(szTeam), "%l", "MJ_ADMIN_MSG_CT");

		switch(g_iMessages)
		{
			case 1: client_print_color(id, print_team_blue, "%l", "MJ_ADMIN_GIVEN_MSG", iJumps, szTime, szTeam);
			case 2: client_print_color(0, print_team_red, "%l", "MJ_ADMIN_GIVEN_MSG_ALL", id, iJumps, szTime, szTeam);
		}

		if(g_iLogs)
		{
			new szAuthID[MAX_AUTHID_LENGTH], szIP[MAX_IP_LENGTH];
			get_user_authid(id, szAuthID, charsmax(szAuthID));
			get_user_ip(id, szIP, charsmax(szIP), 1);

			log_to_file(g_szLogFile, "%l", "MJ_ADMIN_GIVEN_TEAM_LOG", id, szAuthID, szIP, iJumps, szTeam);
		}

		return PLUGIN_HANDLED;
	}
	else if(equal(szArg, "ALL"))
	{
		new iCount;
		for(i = 0; i < iPlayerCount; i++)
		{
			iPlayer = iPlayers[i];

			if(get_member(iPlayer, m_iTeam) == TEAM_SPECTATOR)
				continue;

			iCount++;
			mj_give_user_jumps(iPlayer, iJumps);

			if(iTime)
				set_task(float(iTime), "func_JumpsEndTime", iPlayer);

			if(g_iMessages == 1)
			{
				if(iPlayer != id)
				{
					new iJumpsPlayer = mj_get_user_jumps(iPlayer);

					if(iJumpsPlayer > iJumps)
						formatex(szTotalJumps, charsmax(szTotalJumps), "%s%l", iTime ? " " : ". ", "MJ_ADMIN_TOTAL_JUMPS", iJumpsPlayer);
					client_print_color(iPlayer, print_team_default, "%l", "MJ_ADMIN_GIVEN_PLAYER_TARGET", id, iJumps, szTime, szTotalJumps);
				}
			}
		}

		if(!iCount)
		{
			client_print(id, print_console, "%l", "MJ_ADMIN_ERROR_NOPLAYERS");
			return PLUGIN_HANDLED;
		}

		formatex(szTeam, charsmax(szTeam), "%l", "MJ_ADMIN_MSG_ALL");

		switch(g_iMessages)
		{
			case 0: client_print_color(id, print_team_grey, "%l", "MJ_ADMIN_GIVEN_MSG", iJumps, szTime, szTeam);
			case 1: client_print_color(0, print_team_red, "%l", "MJ_ADMIN_GIVEN_MSG_ALL", id, iJumps, szTime, szTeam);
		}

		if(g_iLogs)
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
		new iTarget = cmd_target(id, szArg, CMDTARGET_ALLOW_SELF);
		if(!iTarget)
			return PLUGIN_HANDLED;

		if(!is_user_alive(iTarget))
		{
			client_print(id, print_console, "%l", "MJ_ADMIN_ERROR_DEAD");
			return PLUGIN_HANDLED;
		}

		mj_give_user_jumps(iTarget, iJumps);

		if(iTime)
			set_task(float(iTime), "func_JumpsEndTime", iTarget);

		switch(g_iMessages)
		{
			case 1:
			{
				client_print_color(id, iTarget, "%l", "MJ_ADMIN_GIVEN_MSG", iJumps, szTime, iTarget);
				if(iTarget != id)
				{
					new iJumpsPlayer = mj_get_user_jumps(iTarget);

					if(iJumpsPlayer > iJumps)
						formatex(szTotalJumps, charsmax(szTotalJumps), "%s%l", iTime ? " " : ". ", "MJ_ADMIN_TOTAL_JUMPS", iJumpsPlayer);
					client_print_color(iTarget, print_team_default, "%l", "MJ_ADMIN_GIVEN_PLAYER_TARGET", id, iJumps, szTime, szTotalJumps);
				}
			}
			case 2: client_print_color(0, iTarget, "%l", "MJ_ADMIN_GIVEN_MSG_ALL", id, iJumps, szTime, iTarget);
		}

		if(g_iLogs)
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
	
public func_JumpsEndTime(id)
{
	if(!is_user_alive(id) || !mj_get_user_jumps(id))
		return PLUGIN_HANDLED;

	mj_set_user_jumps(id, 0);
	client_print_color(id, print_team_default, "%l", "MJ_TIME_ENDED");

	return PLUGIN_HANDLED;
}

public hook_CvarChange_Access(pCvar, const szOldValue[], const szNewValue[])
{
	g_iAccess = read_flags(szNewValue);
}

stock is_digit_arg(szArg[])
{
	new bool:bIsDigit = true;
	new iLen = strlen(szArg);

	for(new iCharacter; iCharacter < iLen; iCharacter++)
	{
		if(!isdigit(szArg[iCharacter]))
		{
			bIsDigit = false;
			break;
		}
	}

	return bIsDigit;
}