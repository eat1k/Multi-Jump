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

#define GetCvarDesc(%0) fmt("%l", %0)

new g_iBuyPrice;
new g_iBuyPriceSteam;
new g_iBuyJumps;

public plugin_init()
{
	register_plugin("Multi Jump: Buy", PLUGIN_VERSION, "w0w");
	register_dictionary("multi_jump_buy.ini");

	// say/say_team commands
	register_saycmd("mj", "func_BuyJumps");
	// console command
	register_clcmd("amx_buymj", "func_BuyJumps");

	new pCvar;

	pCvar = create_cvar("mj_buy_price", "30", FCVAR_NONE, GetCvarDesc("MJ_BUY_CVAR_PRICE"), true, 0.0, true, 2147483520.0);
	bind_pcvar_num(pCvar, g_iBuyPrice);

	pCvar = create_cvar("mj_buy_price_steam", "20", FCVAR_NONE, GetCvarDesc("MJ_BUY_CVAR_PRICE_STEAM"), true, 0.0, true, 2147483520.0);
	hook_cvar_change(pCvar, "hook_CvarChange_PriceSteam");

	pCvar = create_cvar("mj_buy_additional_jumps", "1", FCVAR_NONE, GetCvarDesc("MJ_BUY_CVAR_ADDITIONAL_JUMPS"), true, 1.0);
	bind_pcvar_num(pCvar, g_iBuyJumps);

	AutoExecConfig(true, "multi_jump_buy");
}

public OnConfigsExecuted()
{
	if(g_iBuyPriceSteam && !has_reunion())
		set_fail_state("Reunion is not available to use mj_buy_price_steam CVar. Set the CVar to 0 or disable the plugin.");
}

public func_BuyJumps(id)
{
	if(!func_CanBuyJumps(id))
		return PLUGIN_HANDLED;

	new iMoney;

	rg_add_account(id, -(is_user_steam(id) ? g_iBuyPriceSteam : g_iBuyPrice));

	mj_give_user_jumps(id, g_iBuyJumps);
	rg_add_account(id, -iMoney);
	client_print_color(id, print_team_default, "%l", "MJ_BUY_SUCCESS", mj_get_user_jumps(id));

	return PLUGIN_HANDLED;
}

bool:func_CanBuyJumps(id)
{
	if(!is_user_alive(id))
	{
		client_print_color(id, print_team_red, "%l", "MJ_BUY_ERROR_DEAD");
		return false;
	}

	new iMoney = get_member(id, m_iAccount);

	if(iMoney < g_iBuyPrice)
	{
		client_print_color(id, print_team_red, "%l", "MJ_BUY_ERROR_NEED_MONEY", g_iBuyPrice - iMoney);
		return false;
	}
	return true;
}

public hook_CvarChange_PriceSteam(pCvar, const szOldValue[], szNewValue[])
{
	g_iBuyPriceSteam = str_to_num(szNewValue);

	if(g_iBuyPriceSteam && !has_reunion())
		set_fail_state("Reunion is not available to use mj_buy_price_steam CVar. Set the CVar to 0 or disable the plugin.");
}

// thanks to mx?! (BlackSignature)
stock register_saycmd(szSayCmd[], szFunc[])
{
	new const szPrefix[][] = { "say /", "say_team /", "say .", "say_team ." };

	for(new i, szTemp[MAX_NAME_LENGTH]; i < sizeof(szPrefix); i++)
	{
		formatex(szTemp, charsmax(szTemp), "%s%s", szPrefix[i], szSayCmd);
		register_clcmd(szTemp, szFunc);
	}
}