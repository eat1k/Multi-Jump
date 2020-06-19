/*
 * Official resource topic: https://dev-cs.ru/resources/1014/
 */ 

#include <amxmodx>
#include <multi_jump>

public stock const PluginName[] = "Multi Jump: Default Access";
public stock const PluginVersion[] = "1.0.1";
public stock const PluginAuthor[] = "twisterniq";
public stock const PluginURL[] = "https://github.com/twisterniq/amxx-multi-jump";
public stock const PluginDescription[] = "Blocks using multi jumps if player has not specified access.";

new const CONFIG_NAME[] = "multi_jump_default_access";

new g_iAccess = ADMIN_LEVEL_H;

public plugin_init()
{
#if AMXX_VERSION_NUM == 190
	register_plugin(
		.plugin_name = PluginName,
		.version = PluginVersion,
		.author = PluginAuthor
	);
#endif

	register_dictionary("multi_jump_default_access.txt");

	new pCvar = create_cvar(
		.name = "mj_default_access",
		.string = "t",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "MJ_DEFAULT_ACCESS_CVAR"));
	set_pcvar_string(pCvar, "");
	hook_cvar_change(pCvar, "@OnDefaultAccessChange");

	AutoExecConfig(true, CONFIG_NAME);

	new szPath[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	server_cmd("exec %s/plugins/%s.cfg", szPath, CONFIG_NAME);
	server_exec();
}

public MJ_Jump_Pre(const id)
{
	if(g_iAccess > 0 && !(get_user_flags(id) & g_iAccess))
    {
		return PLUGIN_HANDLED;
    }

	return PLUGIN_CONTINUE;
}

@OnDefaultAccessChange(const iHandle, const szOldValue[], const szNewValue[])
{
    g_iAccess = read_flags(szNewValue);
}