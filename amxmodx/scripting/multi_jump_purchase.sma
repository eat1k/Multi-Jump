/*
 * Official resource topic: https://dev-cs.ru/resources/930/
 */

#include <amxmodx>
#include <reapi>
#include <multi_jump>

#pragma semicolon 1

public stock const PluginName[] = "Multi Jump: Purchase";
public stock const PluginVersion[] = "2.0.0";
public stock const PluginAuthor[] = "twisterniq";
public stock const PluginURL[] = "https://github.com/twisterniq/amxx-multi-jump";
public stock const PluginDescription[] = "Adds the possibility to purchase multi jumps";

enum _:CVARS
{
	CVAR_PRICE,
	CVAR_PRICE_STEAM,
	CVAR_JUMPS_NUM
};

new g_iCvar[CVARS];

new g_iAccess;

public plugin_init()
{
#if AMXX_VERSION_NUM == 190
	register_plugin(
		.plugin_name = PluginName,
		.version = PluginVersion,
		.author = PluginAuthor
	);
#endif

	register_dictionary("multi_jump_purchase.txt");

	new szCmd[][] = { "mj_purchase", "/mj", "!mj", ".mj" };
	register_clcmd_list(szCmd, "@func_Purchase");

	new pCvarAccess = create_cvar(
		.name = "mj_purchase_access",
		.string = "",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_PURCHASE_CVAR_ACCESS"));
	set_pcvar_string(pCvarAccess, "");
	hook_cvar_change(pCvarAccess, "@OnAccessChange");

	bind_pcvar_num(create_cvar(
		.name = "mj_purchase_price",
		.string = "30",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_PURCHASE_CVAR_PRICE"),
		.has_min = true,
		.min_val = 0.0), g_iCvar[CVAR_PRICE]);

	bind_pcvar_num(create_cvar(
		.name = "mj_purchase_price_steam",
		.string = "20",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_PURCHASE_CVAR_PRICE_STEAM"),
		.has_min = true,
		.min_val = 0.0), g_iCvar[CVAR_PRICE_STEAM]);

	bind_pcvar_num(create_cvar(
		.name = "mj_purchase_additional_jumps",
		.string = "1",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_PURCHASE_CVAR_ADDITIONAL_JUMPS"),
		.has_min = true,
		.min_val = 1.0), g_iCvar[CVAR_JUMPS_NUM]);

	AutoExecConfig(true, "multi_jump_purchase");
}

@func_Purchase(const id)
{
	if (!is_user_alive(id))
	{
		client_print_color(id, print_team_red, "%l", "MJ_PURCHASE_ERROR_DEAD");
		return PLUGIN_HANDLED;
	}

	if (g_iAccess > 0 && !(get_user_flags(id) & g_iAccess))
	{
		client_print_color(id, print_team_red, "%l", "MJ_PURCHASE_ERROR_ACCESS");
		return PLUGIN_HANDLED;
	}

	new iCost = g_iCvar[CVAR_PRICE];

	if (has_reunion() && is_user_steam(id))
	{
		iCost = g_iCvar[CVAR_PRICE_STEAM];
	}

	new iMoney = get_member(id, m_iAccount);

	if (iMoney < iCost)
	{
		client_print_color(id, print_team_red, "%l", "MJ_PURCHASE_ERROR_NEED_MONEY", iCost - iMoney);
		return PLUGIN_HANDLED;
	}

	rg_add_account(id, -iCost);

	mj_give_user_jumps(id, g_iCvar[CVAR_JUMPS_NUM]);
	client_print_color(id, print_team_default, "%l", "MJ_PURCHASE_SUCCESS", mj_get_user_jumps(id));

	return PLUGIN_HANDLED;
}

@OnAccessChange(const iHandle, const szOldValue[], const szNewValue[])
{
	g_iAccess = read_flags(szNewValue);
}

// thx wopox1337 (https://dev-cs.ru/threads/222/page-7#post-76442)
stock register_clcmd_list(const cmd_list[][], const function[], flags = -1, const info[] = "", FlagManager = -1, bool:info_ml = false, const size = sizeof(cmd_list))
{
#pragma unused info
#pragma unused FlagManager
#pragma unused info_ml

    for (new i; i < size; i++)
	{
        register_clcmd(cmd_list[i], function, flags, info, FlagManager, info_ml);
    }
}