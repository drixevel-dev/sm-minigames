//Pragma
#pragma semicolon 1
#pragma newdecls required

//Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <minigames>
#include <customkeyvalues>

//Defines
#define MAX_MINIGAMES 32
#define MAX_ROOMS 64
#define ENTITY_PREFIX "mg_"

//ConVars
ConVar convar_Enabled;

//Globals
bool g_Late;

//Forwards
GlobalForward g_Forward_OnAdd;
GlobalForward g_Forward_OnAdded;

enum struct Minigame {
	char name[MAX_NAME_LENGTH];
	bool enabled;
	GameType type;
	StringMap logic;

	void Add(const char[] name, bool enabled, GameType type) {
		strcopy(this.name, sizeof(Minigame::name), name);
		this.enabled = enabled;
		this.type = type;
		this.logic = new StringMap();
	}

	void Clear() {
		this.name[0] = '\0';
		this.enabled = false;
		this.type = Type_Single;
		delete this.logic;
	}

	void AddLogic(const char[] logic, Function func) {
		DataPack pack = new DataPack();
		pack.WriteFunction(func);
		this.logic.SetValue(logic, pack);
	}

	void AddClientLogic(const char[] logic, Function func) {
		DataPack pack = new DataPack();
		pack.WriteFunction(func);
		this.logic.SetValue(logic, pack);
	}
}

Minigame g_Minigame[MAX_MINIGAMES + 1];
int g_TotalMinigames;

enum struct Room {
	int entity;
	int minigame;
	bool open;

	//Players inside of a room and playing and their corresponding teams.
	ArrayList players;
	StringMap player_teams; //GameType = Type_Team

	//Players who are outside of the room but queued for it and the corresponding teams they're queued for.
	ArrayList queue;
	StringMap queue_teams;  //GameType = Type_Team
	
	//Entities Data
	ArrayList queue_triggers;
	ArrayList teleport_relays;

	void Add(int entity, int minigame, ArrayList queue_triggers, ArrayList teleport_relays) {
		this.entity = entity;
		this.minigame = minigame;
		this.open = true;
		this.players = new ArrayList();
		this.player_teams = new StringMap();
		this.queue = new ArrayList();
		this.queue_teams = new StringMap();
		this.queue_triggers = queue_triggers;
		this.teleport_relays = teleport_relays;
	}

	void Clear() {
		this.entity = -1;
		this.minigame = -1;
		this.open = false;
		delete this.players;
		delete this.player_teams;
		delete this.queue;
		delete this.queue_teams;
		delete this.queue_triggers;
		delete this.teleport_relays;
	}

	bool AddPlayerToQueue(int client, int team = -1) {
		int userid = GetClientUserId(client);

		if (this.queue.FindValue(client) != -1) {
			return false;
		}

		this.queue.Push(userid);
		char sUserID[64];
		IntToString(userid, sUserID, sizeof(sUserID));
		this.queue_teams.SetValue(sUserID, team);

		return true;
	}

	bool RemovePlayerFromQueue(int client) {
		int userid = GetClientUserId(client);

		int index = this.queue.FindValue(userid);
		if (index == -1) {
			return false;
		}

		this.queue.Erase(index);
		char sUserID[64];
		IntToString(userid, sUserID, sizeof(sUserID));
		this.queue_teams.Remove(sUserID);

		return true;
	}

	int PopQueue(int team) {
		int client = -1;

		for (int i = 0; i < this.queue.Length; i++) {
			char sUserID[64];
			IntToString(this.queue.Get(i), sUserID, sizeof(sUserID));

			int queue_team;
			this.queue_teams.GetValue(sUserID, queue_team);

			if (team == -1 || queue_team == team) {
				client = GetClientOfUserId(this.queue.Get(i));
				this.queue.Erase(i);
				this.queue_teams.Remove(sUserID);
				break;
			}
		}

		return client;
	}

	void Open() {
		this.open = true;
	}

	void Close() {
		this.open = false;
	}
}

Room g_Room[MAX_ROOMS + 1];
int g_TotalRooms;

public Plugin myinfo = {
	name = "[ANY] Minigames",
	author = "Drixevel",
	description = "A minigames plugin for Sourcemod.",
	version = "1.0.0",
	url = "https://drixevel.dev/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	RegPluginLibrary("minigames");
	CSetPrefix("[Minigames] ");

	//Natives
	CreateNative("Minigame_Add", Native_Add);
	CreateNative("Minigames_AddLogic", Native_AddLogic);
	CreateNative("Minigames_AddClientLogic", Native_AddClientLogic);

	//Forwards
	g_Forward_OnAdd = new GlobalForward("Minigames_OnAdd", ET_Event, Param_String, Param_Cell);
	g_Forward_OnAdded = new GlobalForward("Minigames_OnAdded", ET_Ignore, Param_String, Param_Cell);

	g_Late = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	LoadTranslations("minigames.phrases");

	CreateConVar("sm_minigames_version", "1.0.0", "Version control for this plugin.", FCVAR_DONTRECORD);
	convar_Enabled = CreateConVar("sm_minigames_enabled", "1", "Should this plugin be enabled or disabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//AutoExecConfig();

	RegConsoleCmd("sm_minigames", Command_Minigames, "Open the minigames menu.");

	HookEvent("teamplay_round_start", Event_RoundStart);

	if (g_Late) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientConnected(i)) {
				OnClientConnected(i);
			}

			if (IsClientInGame(i)) {
				OnClientPutInServer(i);
			}
		}

		int entity = -1; char clsname[64];
		while ((entity = FindEntityByClassname(entity, "*")) != -1) {
			if (GetEntityClassname(entity, clsname, sizeof(clsname))) {
				OnEntityCreated(entity, clsname);
			}
		}

		g_Late = false;
	}
}

public void OnPluginEnd() {

}

public void OnConfigsExecuted() {
	ParseMinigames();
}

public void OnMapStart() {
	
}

public void OnMapEnd() {

}

public void OnClientConnected(int client) {

}

public void OnClientPutInServer(int client) {

}

public void OnClientDisconnect(int client) {
	
}

public void OnClientDisconnect_Post(int client) {

}

public void OnEntityCreated(int entity, const char[] classname) {
	if (StrEqual(classname, "trigger_multiple")) {
		SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
		SDKHook(entity, SDKHook_EndTouch, OnEndTouch);

		if (g_Late) {

		}
	}
}

public void OnStartTouch(int entity) {
	char sName[MAX_NAME_LENGTH];
	GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

	if (StrContains(sName, ENTITY_PREFIX, false) == -1) {
		return;
	}
}

public void OnEndTouch(int entity) {
	char sName[MAX_NAME_LENGTH];
	GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

	if (StrContains(sName, ENTITY_PREFIX, false) == -1) {
		return;
	}
}

public Action Command_Minigames(int client, int args) {
	if (!convar_Enabled.BoolValue) {
		return Plugin_Continue;
	}

	if (client < 1) {
		CReplyToCommand(client, "%T", "Command is in-game only", client);
		return Plugin_Handled;
	}

	OpenMinigamesMenu(client);

	return Plugin_Handled;
}

void OpenMinigamesMenu(int client) {
	Menu menu = new Menu(Menu_Minigames);
	menu.SetTitle("%T", "minigames menu title", client);

	char sID[16]; char sDisplay[256];
	for (int i = 0; i < g_TotalMinigames; i++) {
		IntToString(i, sID, sizeof(sID));
		FormatEx(sDisplay, sizeof(sDisplay), "%s", g_Minigame[i].name);
		menu.AddItem(sID, sDisplay);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Minigames(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sID[16];
			menu.GetItem(param2, sID, sizeof(sID));
			int i = StringToInt(sID);
			OpenMinigameMenu(param1, i);
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

void OpenMinigameMenu(int client, int i) {
	Menu menu = new Menu(Menu_Minigame, MENU_ACTIONS_ALL);
	menu.SetTitle("%T", "minigame menu title", client, g_Minigame[i].name);

	menu.AddItem("enabled", "Enabled: X");

	PushMenuInt(menu, "i", i);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Minigame(Menu menu, MenuAction action, int param1, int param2) {
	int i = GetMenuInt(menu, "i");

	switch (action) {
		case MenuAction_DisplayItem: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			char sDisplay[64];
			if (StrEqual(sInfo, "enabled")) {
				FormatEx(sDisplay, sizeof(sDisplay), "Enabled: %s", g_Minigame[i].enabled ? "ON" : "OFF");
				return RedrawMenuItem(sDisplay);
			}
		}

		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "enabled")) {
				g_Minigame[i].enabled = !g_Minigame[i].enabled;
			}

			OpenMinigameMenu(param1, i);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenMinigamesMenu(param1);
			}
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

void ParseMinigames() {
	ClearMinigames();

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/minigames.cfg");

	KeyValues kv = new KeyValues("minigames");

	if (!kv.ImportFromFile(sPath) || !kv.GotoFirstSubKey()) {
		delete kv;
		ThrowError("Error while parsing file: %s", sPath);
	}

	LogMessage(" -- Parsing minigames...");

	char sName[MAX_NAME_LENGTH]; bool enabled; GameType type;
	do {
		kv.GetSectionName(sName, sizeof(sName));
		enabled = view_as<bool>(kv.GetNum("enabled", true));
		type = view_as<GameType>(kv.GetNum("type", view_as<int>(Type_Single)));
		AddMinigame(sName, enabled, type);
	} while (kv.GotoNextKey());

	delete kv;
	LogMessage(" -- %i minigames parsed successfully.", g_TotalMinigames);
}

bool AddMinigame(char name[MAX_MINIGAME_NAME_LENGTH], bool &enabled, GameType &type) {
	if (g_TotalMinigames >= MAX_MINIGAMES) {
		LogError(" -- Max minigames reached: %i", MAX_MINIGAMES);
		return false;
	}

	char x_name[MAX_MINIGAME_NAME_LENGTH];
	strcopy(x_name, sizeof(x_name), name);
	bool x_enabled = enabled;
	GameType x_type = type;

	Call_StartForward(g_Forward_OnAdd);
	Call_PushStringEx(name, sizeof(name), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCellRef(enabled);
	Call_PushCellRef(type);
	Action result = Plugin_Continue;
	Call_Finish(result);

	if (result == Plugin_Continue) {
		strcopy(name, sizeof(name), x_name);
		enabled = x_enabled;
		type = x_type;
	} else if (result >= Plugin_Handled) {
		return false;
	}

	g_Minigame[g_TotalMinigames++].Add(name, enabled, type);
	LogMessage(" - Minigame Parsed: %s", name);

	Call_StartForward(g_Forward_OnAdded);
	Call_PushString(name);
	Call_PushCell(enabled);
	Call_PushCell(type);
	Call_Finish();

	return true;
}

void ClearMinigames() {
	for (int i = 0; i < MAX_MINIGAMES; i++) {
		g_Minigame[i].Clear();
	}
	g_TotalMinigames = 0;
}

int GetMinigameByName(const char[] name) {
	for (int i = 0; i < g_TotalMinigames; i++) {
		if (StrEqual(name, g_Minigame[i].name, false)) {
			return i;
		}
	}
	return -1;
}

void AddMinigameLogicFunc(int minigame, const char[] logic, Function func) {
	g_Minigame[minigame].AddLogic(logic, func);
}

void AddMinigameClientLogicFunc(int minigame, const char[] logic, Function func) {
	g_Minigame[minigame].AddClientLogic(logic, func);
}

//Natives
public int Native_Add(Handle plugin, int numParams) {
	char sName[MAX_MINIGAME_NAME_LENGTH];
	GetNativeString(1, sName, sizeof(sName));

	if (GetMinigameByName(sName) != -1) {
		//ThrowNativeError(SP_ERROR_NATIVE, "Minigame %s already exists, couldn't register via native.", sName);
		LogError("Minigame %s already exists, couldn't register via native.", sName);
		return false;
	}

	bool enabled = GetNativeCell(2);
	GameType type = GetNativeCell(3);

	return AddMinigame(sName, enabled, type);
}

public int Native_AddLogic(Handle plugin, int numParams) {
	int minigame = GetNativeCell(1);

	int size;
	GetNativeStringLength(2, size);

	char[] sLogic = new char[size];
	GetNativeString(2, sLogic, size);

	if (minigame < 0 || minigame >= g_TotalMinigames) {
		//ThrowNativeError(SP_ERROR_NATIVE, "Invalid minigame index: %i", minigame);
		LogError("Invalid minigame index: %i", minigame);
		return false;
	}

	Function func = GetNativeFunction(3);

	AddMinigameLogicFunc(minigame, sLogic, func);

	return true;
}

public int Native_AddClientLogic(Handle plugin, int numParams) {
	int minigame = GetNativeCell(1);

	int size;
	GetNativeStringLength(2, size);

	char[] sLogic = new char[size];
	GetNativeString(2, sLogic, size);

	if (minigame < 0 || minigame >= g_TotalMinigames) {
		//ThrowNativeError(SP_ERROR_NATIVE, "Invalid minigame index: %i", minigame);
		LogError("Invalid minigame index: %i", minigame);
		return false;
	}

	Function func = GetNativeFunction(3);

	AddMinigameClientLogicFunc(minigame, sLogic, func);

	return true;
}

//Stocks
stock bool PushMenuInt(Menu menu, const char[] id, int value) {
	if (menu == null || strlen(id) == 0) {
		return false;
	}
	
	char sBuffer[128];
	IntToString(value, sBuffer, sizeof(sBuffer));
	return menu.AddItem(id, sBuffer, ITEMDRAW_IGNORE);
}

stock int GetMenuInt(Menu menu, const char[] id, int defaultvalue = 0) {
	if (menu == null || strlen(id) == 0) {
		return defaultvalue;
	}
	
	char info[128]; char data[128];
	for (int i = 0; i < menu.ItemCount; i++) {
		if (menu.GetItem(i, info, sizeof(info), _, data, sizeof(data)) && StrEqual(info, id)) {
			return StringToInt(data);
		}
	}
	
	return defaultvalue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	ParseRooms();
}

void ParseRooms() {
	ClearRooms();
	LogMessage(" -- Parsing rooms...");
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "info_target")) != -1) {
		char sName[MAX_NAME_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		//Exclude entities which are meant to be minigames oriented by requiring a prefix in the name.
		if (StrContains(sName, ENTITY_PREFIX, false) == -1) {
			continue;
		}

		//Require the text '_room_' somewhere in the name to pin point that this is an entity meant to register a room with triggers and teleporters.
		if (StrContains(sName, "_room_", false) == -1) {
			continue;
		}

		char sMinigame[MAX_MINIGAME_NAME_LENGTH];
		if (!GetCustomKeyValue(entity, "io_minigame", sMinigame, sizeof(sMinigame))) {
			continue;
		}

		int minigame = GetMinigameByName(sMinigame);

		if (minigame < 0 || minigame > MAX_MINIGAMES) {
			continue;
		}

		ArrayList queue_triggers = new ArrayList(ByteCountToCells(64));
		ArrayList teleport_relays = new ArrayList(ByteCountToCells(64));

		char sDisplay[64]; char sOutput[64];
		for (int i = 0; i < 32; i++) {
			FormatEx(sDisplay, sizeof(sDisplay), "io_queue_%i", i);
			if (GetCustomKeyValue(entity, sDisplay, sOutput, sizeof(sOutput)) && strlen(sOutput) > 0) {
				queue_triggers.PushString(sOutput);
			}

			FormatEx(sDisplay, sizeof(sDisplay), "io_teleport_%i", i);
			if (GetCustomKeyValue(entity, sDisplay, sOutput, sizeof(sOutput)) && strlen(sOutput) > 0) {
				teleport_relays.PushString(sOutput);
			}
		}

		g_Room[g_TotalRooms++].Add(entity, minigame, queue_triggers, teleport_relays);
		LogMessage(" - [%i] room with minigame [%i] has been found and added.", entity, minigame);
	}

	LogMessage(" -- %i total rooms found and added.", g_TotalRooms);
}

void ClearRooms() {
	for (int i = 0; i < MAX_ROOMS; i++) {
		g_Room[i].Clear();
	}
	g_TotalRooms = 0;
}