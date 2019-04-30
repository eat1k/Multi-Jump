#if defined _multi_jump_included
	#endinput
#endif
#define _multi_jump_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib multi_jump
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib multi_jump
	#endif
#else
	#pragma library multi_jump
#endif

/**
 * Returns the number of jumps that a player has.
 *
 * @param id		Client index
 *
 * @return			Number of jumps that a player has
 */
native mj_get_user_jumps(id);

/**
 * Gives to a player a specified number of jumps.
 *
 * @param id		Client index
 * @param amount	Amount of jumps to give
 *
 * @return			Number of given jumps on success
 */
native mj_give_user_jumps(id, amount);

/**
 * Sets to a player a specified number of jumps.
 *
 * @param id		Client index
 * @param amount	Amount of jumps to set
 *
 * @return			Number of set jumps on success
 */
native mj_set_user_jumps(id, amount);

/**
 * Removes a specified number of jumps from a player.
 *
 * @return			Number of removed jumps on success, false otherwise
 */
native mj_remove_user_jumps();

/**
 * Called before doing a multi jump.
 *
 * @return			PLUGIN_CONTINUE to let the client do the multi jump
 *					PLUGIN_HANDLED or higher to not do the multi jump
 */
forward MJ_Jump_Pre(id);

/**
 * Called after doing a multi jump.
 *
 * @noreturn
 */
forward MJ_Jump_Post(id);