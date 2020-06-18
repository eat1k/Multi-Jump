#if defined _multi_jump_included
	#endinput
#endif
#define _multi_jump_included

#pragma reqlib multi_jump

/**
 * Called before doing a multi jump.
 *
 * @return			PLUGIN_CONTINUE to let the client do the multi jump
 *					PLUGIN_HANDLED or higher to not do the multi jump
 */
forward MJ_Jump_Pre(const id);

/**
 * Called after doing a multi jump.
 *
 * @noreturn
 */
forward MJ_Jump_Post(const id);

/**
 * Returns the number of jumps that a player has.
 *
 * @param id        Client index
 *
 * @return          Number of jumps that a player has
 * @error           If the index is not within the range of 1 to MaxClients,
 *                  an error will be thrown.
 */
native mj_get_user_jumps(const id);

/**
 * Gives to a player a specified number of jumps.
 *
 * @param id        Client index
 * @param amount    Amount of jumps to give
 *
 * @return          Number of given jumps on success
 * @error           If the index is not within the range of 1 to MaxClients,
 *                  or an invalid number of jumps is set, an error will be thrown.
 */
native mj_give_user_jumps(const id, amount);

/**
 * Sets to a player a specified number of jumps.
 *
 * @param id        Client index
 * @param amount    Amount of jumps to set
 *
 * @return          Number of set jumps on success
 * @error           If the index is not within the range of 1 to MaxClients,
 *                  or an invalid number of jumps is set, an error will be thrown.
 */
native mj_set_user_jumps(const id, amount);

/**
 * Removes a specified number of jumps from a player.
 *
 * @param id        Client index
 * @param amount    Amount of jumps to set
 *
 * @return          Number of removed jumps on success, 0 otherwise
 * @error           If the index is not within the range of 1 to MaxClients,
 *                  or an invalid number of jumps is set, an error will be thrown.
 */
native mj_remove_user_jumps(const id, amount);