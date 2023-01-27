#if defined _minigames_included
  #endinput
#endif
#define _minigames_included

//Globals
#define MAX_MINIGAME_NAME_LENGTH MAX_NAME_LENGTH

enum GameType {
	Type_Single,	//Minigame type revolves around allowing one player in at a time.
	Type_Multi,		//Minigame type revolves around allowing multiple players in at a time.
	Type_Team,		//Minigame type revolves around allowing multiple players in at a time, but with teams.
}

typedef MgLogic = function void (int minigame);
typedef MgClientLogic = function void (int client, int minigame);

////////////////////////////
//Natives

/**
* Add a minigame to the list of minigames manually.
*
* param name		Name of the minigame.
* param enabled		Default status for the minigame.
* param type		Type of minigame.
*
* return types:
*  - True		Minigame successfully added.
*  - False		Minigame failed to be added.
**/
native bool Minigame_Add(const char[] name, bool enabled, GameType type);

/**
* Register general logic for a minigame.
*
* param minigame	Index of the minigame.
* param logic		Logic type to hook via name.
* param func		Function to register and fire.
*
* return types:
*  - True		Logic successfully registered and is in use.
*  - False		Logic unsuccessfully registered for whatever reason.
**/
native bool Minigames_AddLogic(int minigame, const char[] logic, MgLogic func);

/**
* Register client logic for a minigame.
*
* param minigame	Index of the minigame.
* param logic		Logic type to hook via name.
* param func		Function to register and fire.
*
* return types:
*  - True		Logic successfully registered and is in use.
*  - False		Logic unsuccessfully registered for whatever reason.
**/
native bool Minigames_AddClientLogic(int minigame, const char[] logic, MgClientLogic func);

////////////////////////////
//Forwards

/**
* Called right before a minigame is added to the pool.
*
* param name		Name of the minigame.
* param enabled		Default status for the minigame.
* param type		Type of minigame.
* 
* return types:
*  - Plugin_Continue	Continues to add it unchanged.
*  - Plugin_Changed		Continues to add it with changes.
*  - Plugin_Handled		Stops adding the minigame in this one instance.
*  - Plugin_Stop		Stops adding the minigame entirely.
**/
forward Action Minigames_OnAdd(char[] name, bool &enabled, GameType &type);

/**
* Called right after a minigame is added to the pool.
*
* param name		Name of the minigame.
* param enabled		Default status for the minigame.
* param type		Type of minigame.
*
**/
forward void Minigames_OnAdded(const char[] name, bool enabled, GameType type);

////////////////////////////
//Include Logic

#if !defined REQUIRE_PLUGIN
public void __pl_minigames_SetNTVOptional()
{
	MarkNativeAsOptional("Minigame_Add");
	MarkNativeAsOptional("Minigames_AddLogic");
	MarkNativeAsOptional("Minigames_AddClientLogic");
}
#endif

public SharedPlugin __pl_minigames =
{
	name = "minigames",
	file = "minigames.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};