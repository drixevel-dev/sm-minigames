#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <minigames>

public Plugin myinfo = {
	name = "[Minigame] Lava Pit",
	author = "Drixevel",
	description = "Adds logic to the minigames API for Lava Pit minigames.",
	version = "1.0.0",
	url = "https://drixevel.dev/"
};

public void OnRegisterMinigames() {
	int minigame = Minigame_Add("lava pit", true, Type_Multi);

	if (minigame == -1) {
		return;
	}

	Minigames_AddLogic(minigame, "start", OnStart);
	Minigames_AddLogic(minigame, "stop", OnStop);
	Minigames_AddClientLogic(minigame, "spawn", OnSpawn);
	Minigames_AddClientLogic(minigame, "death", OnDeath);
}

public void OnStart(int minigame) {
	PrintToChatAll("Lava Pit has started!");
}

public void OnStop(int minigame) {
	PrintToChatAll("Lava Pit has stopped!");
}

public void OnSpawn(int client, int minigame) {
	PrintToChat(client, "Cross the lava pit to win.");
}

public void OnDeath(int client, int minigame) {
	PrintToChat(client, "You have failed to cross the lava pit.");
}