#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <morecolors>
#undef REQUIRE_PLUGIN
#tryinclude <sourcebans>
#tryinclude <sb_admins>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = {
	name		= "Prometheus - Sourcemod Donation System",
	author		= "Nanochip",
	description = "Automatic Donation System",
	version		= PLUGIN_VERSION,
	url			= "https://scriptfodder.com/scripts/view/565"
};

static char KVPath[PLATFORM_MAX_PATH];
static char KVPathAdmins[PLATFORM_MAX_PATH];

ConVar cvarMode;
ConVar cvarBroadcast;
ConVar cvarBroadcastKeys;
ConVar cvarCheckInterval;
ConVar cvarAdminsCfg;

int AdminID;
int GroupID;

bool csgo = false;
bool ccc = false;
//bool store = false;
//bool storeZeph = false;

Handle db = null;

public void OnPluginStart()
{
	if (GetEngineVersion() == Engine_CSGO) csgo = true;
	if (LibraryExists("ccc")) ccc = true;
	//if (LibraryExists("store")) store = true;
	//if (LibraryExists("store_zephyrus")) storeZeph = true;
	
	LoadTranslations("common.phrases");
	
	CreateConVar("sm_prometheus_version", PLUGIN_VERSION, "Prometheus Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cvarMode = CreateConVar("sm_prometheus_mode", "1", "0 = Disable the plugin, 1 = Add the donator to admins.cfg (flatfile), 2 = Add the donator to the MySQL database (uses the 'default' connection info in your databases.cfg), 3 = Add the donator to Sourcebans admin database", 0, true, 0.0, true, 3.0);
	if (csgo)
	{
		cvarBroadcast = CreateConVar("sm_prometheus_message", "[Prometheus] PLAYER_NAME has donated $DONATION_AMOUNT and receives PACKAGE_NAME! Thank you!", "Edit the broadcast message when a player donates. CS:GO detected, no colors available.", 0);
	}
	else
	{
		cvarBroadcast = CreateConVar("sm_prometheus_message", "{fullred}[Prometheus] {haunted}PLAYER_NAME {honeydew}has donated {haunted}$DONATION_AMOUNT{honeydew} and receives {haunted}PACKAGE_NAME{honeydew}! Thank you!", "What do you want the broadcast message to be? List of colors can be found here: https://www.doctormckay.com/morecolors.php", 0);
	}
	if (csgo)
	{
		cvarBroadcastKeys = CreateConVar("sm_prometheus_message_keys", "[Prometheus] PLAYER_NAME has donated DONATION_AMOUNT keys and receives PACKAGE_NAME! Thank you!", "Edit the broadcast message when a player donates. CS:GO detected, no colors available.", 0);
	}
	else
	{
		cvarBroadcastKeys = CreateConVar("sm_prometheus_message_keys", "{fullred}[Prometheus] {haunted}PLAYER_NAME {honeydew}has donated {haunted}DONATION_AMOUNT{honeydew} and receives {haunted}PACKAGE_NAME{honeydew}! Thank you!", "What do you want the broadcast message to be? List of colors can be found here: https://www.doctormckay.com/morecolors.php", 0);
	}
	cvarCheckInterval = CreateConVar("sm_prometheus_checkinterval", "600.0", "Time in seconds to check if the user's rank has expired. Default is every 10 minutes (600 seconds)", 0, true, 60.0);
	cvarAdminsCfg = CreateConVar("sm_prometheus_admcfg", "configs/admins.cfg", "Which flatfile admin config should we use? This convar is only used when sm_prometheus_mode is set to 1.");
	CreateTimer(GetConVarFloat(cvarCheckInterval), Timer_CheckInterval, _, TIMER_REPEAT);
	
	RegAdminCmd("sm_prometheus", Cmd_Prometheus, ADMFLAG_ROOT, "");
	//RegAdminCmd("sm_prometheus_credits", Cmd_Prometheus_Credits, ADMFLAG_ROOT, "");
	RegAdminCmd("sm_prometheus_keys", Cmd_Prometheus_Keys, ADMFLAG_ROOT, "");
	
	if (FileExists("addons/sourcemod/configs/prometheus.cfg"))
	{
		BuildPath(Path_SM, KVPath, sizeof(KVPath), "configs/prometheus.cfg");
	} else {
		LogError("Could not find prometheus.cfg in addons/sourcemod/configs/ folder!");
	}
	if (GetConVarInt(cvarMode) == 1)
	{
		char admCfg[PLATFORM_MAX_PATH];
		GetConVarString(cvarAdminsCfg, admCfg, sizeof(admCfg));
		BuildPath(Path_SM, KVPathAdmins, sizeof(KVPathAdmins), admCfg);
	}
	if (GetConVarInt(cvarMode) == 2)
	{
		ConnectToDB();
	}
	AutoExecConfig(true, "Prometheus");
}

void ConnectToDB()
{
	char errors[255];
	if (SQL_CheckConfig("prometheus"))
	{
		db = SQL_Connect("prometheus", true, errors, sizeof(errors));
	} else {
		db = SQL_Connect("default", true, errors, sizeof(errors));
	}
	if (db == null) LogError("Unable to connect to MySQL database: %s", errors);
}

public Action Timer_CheckInterval(Handle timer)
{
	char strExpires[66], steamid[32];
	Handle kvdb = CreateKeyValues("Prometheus");
	Handle DB = CreateKeyValues("Admins");
	FileToKeyValues(kvdb, KVPath);
	if (!KvGotoFirstSubKey(kvdb)) return Plugin_Continue;
	do
	{
		KvGetString(kvdb, "expire_time", strExpires, sizeof(strExpires));
		if (GetTime() >= StringToInt(strExpires))
		{
			KvGetString(kvdb, "steamid", steamid, sizeof(steamid));
			LogAction(0, -1, "%s is now expired, removing rank...", steamid);
			if (GetConVarInt(cvarMode) == 1)
			{
				FileToKeyValues(DB, KVPathAdmins);
				if (KvJumpToKey(DB, steamid, false))
				{
					KvDeleteThis(DB);
					LogAction(0, -1, "%s's rank has been removed.", steamid);
				}
			}
			
			if (GetConVarInt(cvarMode) == 2)
			{
				if (IsValidAdmin(steamid))
				{
					RemoveAdminFromDB(steamid);
					LogAction(0, -1, "%s's rank has been removed.", steamid);
				}
			}
			
			if (GetConVarInt(cvarMode) == 3)
			{
				SB_DeleteAdmin(0, AUTHMETHOD_STEAM, steamid);
				LogAction(0, -1, "%s's rank has been removed.", steamid);
			}
			KvDeleteThis(kvdb);
		}
	} while (KvGotoNextKey(kvdb));
	
	ServerCommand("sm_reloadadmins");
	if (ccc) CreateTimer(3.0, ReloadCCC);
	
	KvRewind(DB);
	KeyValuesToFile(DB, KVPathAdmins);
	CloseHandle(DB);
	KvRewind(kvdb);
	KeyValuesToFile(kvdb, KVPath);
	CloseHandle(kvdb);
	
	return Plugin_Continue;
}

public void OnMapStart()
{
	if (GetConVarInt(cvarMode) == 2)
	{
		ConnectToDB();
	}
}

public Action Cmd_Prometheus(int client, int args)
{
	//sm_prometheus (name) (steamid) (donation_amount) (expires_unixtime) (flag/group) (package_name)
	if (GetConVarInt(cvarMode) == 0) return Plugin_Handled;
	char name[MAX_NAME_LENGTH], steamid[32], dAmount[32], strExpires[64], flGroup[64], strTime[64], packageName[256];
	
	// Get the info from the command
	GetCmdArg(1, name, sizeof(name));
	GetCmdArg(2, steamid, sizeof(steamid));
	GetCmdArg(3, dAmount, sizeof(dAmount));
	GetCmdArg(4, strExpires, sizeof(strExpires));
	GetCmdArg(5, flGroup, sizeof(flGroup));
	GetCmdArg(6, packageName, sizeof(packageName));
	
	// Store the time of donation and expiration time in prometheus.cfg
	IntToString(GetTime(), strTime, sizeof(strTime));
	if (!StrEqual(strExpires, "0"))
	{
		Handle kvdb = CreateKeyValues("Prometheus");
		FileToKeyValues(kvdb, KVPath);
		if (KvJumpToKey(kvdb, steamid, true))
		{
			KvSetString(kvdb, "donation_time", strTime);
			KvSetString(kvdb, "expire_time", strExpires);
			KvSetString(kvdb, "steamid", steamid);
		}
		KvRewind(kvdb);
		KeyValuesToFile(kvdb, KVPath);
		CloseHandle(kvdb);
	}
	
	// If flatfile mode is enabled, add the donator to admins.cfg
	if (GetConVarInt(cvarMode) == 1)
	{
		Handle DB = CreateKeyValues("Admins");
		FileToKeyValues(DB, KVPathAdmins);
		
		if (KvJumpToKey(DB, steamid, true))
		{
			KvSetString(DB, "auth", "steam");
			KvSetString(DB, "identity", steamid);
			if (FindAdmGroup(flGroup) == INVALID_GROUP_ID)
			KvSetString(DB, "flags", flGroup);
			else
			KvSetString(DB, "group", flGroup);
		}
		KvRewind(DB);
		KeyValuesToFile(DB, KVPathAdmins);
		CloseHandle(DB);
	}
	
	// If MySQL mode is enabled, add them to the database
	if (GetConVarInt(cvarMode) == 2)
	{
		AddAdmin(name, steamid);
		GetAdminID(steamid);
		
		if (IsValidGroup(flGroup))
		{
			GetGroupID(flGroup);
			AddAdminGroupIDs();
		} else {
			RemoveAdminFromDB(steamid);
			Handle hQry;
			char query[1024];
			
			int bufferLen = strlen(name)*2+1;
			char[] newName = new char[bufferLen];
			
			SQL_EscapeString(db, name, newName, bufferLen);
			
			Format(query, sizeof(query), "INSERT INTO sm_admins (authtype, identity, flags, immunity, name) VALUES ('steam', '%s', '%s', 0, '%s')", steamid, flGroup, newName);
			
			if ((hQry = SQL_Query(db, query)) == null)
			{
				char Error[1024];
				SQL_GetError(db, Error, sizeof(Error));
				LogError("An error occurred while fully writing admin to the Database: %s", Error);
				CloseHandle(hQry);
				return Plugin_Handled;
			}
			CloseHandle(hQry);
		}
	}
	
	// If Sourcebans is enabled, add them to the SB database
	if (GetConVarInt(cvarMode) == 3)
	{
		if (LibraryExists("sb_admins")) SB_AddAdmin(0, name, AUTHMETHOD_STEAM, steamid, "", flGroup);
	}
	ServerCommand("sm_reloadadmins");
	if (ccc) CreateTimer(3.0, ReloadCCC);
	
	char broadcast[1024];
	GetConVarString(cvarBroadcast, broadcast, sizeof(broadcast));
	ReplaceString(broadcast, sizeof(broadcast), "PLAYER_NAME", name, true);
	ReplaceString(broadcast, sizeof(broadcast), "DONATION_AMOUNT", dAmount, true);
	ReplaceString(broadcast, sizeof(broadcast), "PACKAGE_NAME", packageName, true);
	if (csgo) PrintToChatAll(broadcast);
	else CPrintToChatAll(broadcast);
	PrintToServer(broadcast);
	
	return Plugin_Handled;
}

//public Action Cmd_Prometheus_Credits(int client, int args)
//{
//	
//}

public Action Cmd_Prometheus_Keys(int client, int args)
{
	//sm_prometheus_keys (name) (steamid) (keys_amount) (expires_unixtime) (flag/group)
	if (GetConVarInt(cvarMode) == 0) return Plugin_Handled;
	char name[MAX_NAME_LENGTH], steamid[32], dAmount[32], strExpires[64], flGroup[64], strTime[64], packageName[256];
	
	// Get the info from the command
	GetCmdArg(1, name, sizeof(name));
	GetCmdArg(2, steamid, sizeof(steamid));
	GetCmdArg(3, dAmount, sizeof(dAmount));
	GetCmdArg(4, strExpires, sizeof(strExpires));
	GetCmdArg(5, flGroup, sizeof(flGroup));
	GetCmdArg(6, packageName, sizeof(packageName));
	
	// Store the time of donation and expiration time in prometheus.cfg
	IntToString(GetTime(), strTime, sizeof(strTime));
	if (!StrEqual(strExpires, "0"))
	{
		Handle kvdb = CreateKeyValues("Prometheus");
		FileToKeyValues(kvdb, KVPath);
		if (KvJumpToKey(kvdb, steamid, true))
		{
			KvSetString(kvdb, "donation_time", strTime);
			KvSetString(kvdb, "expire_time", strExpires);
			KvSetString(kvdb, "steamid", steamid);
		}
		KvRewind(kvdb);
		KeyValuesToFile(kvdb, KVPath);
		CloseHandle(kvdb);
	}
	
	// If flatfile mode is enabled, add the donator to admins.cfg
	if (GetConVarInt(cvarMode) == 1)
	{
		Handle DB = CreateKeyValues("Admins");
		FileToKeyValues(DB, KVPathAdmins);
		
		if (KvJumpToKey(DB, steamid, true))
		{
			KvSetString(DB, "auth", "steam");
			KvSetString(DB, "identity", steamid);
			if (FindAdmGroup(flGroup) == INVALID_GROUP_ID)
				KvSetString(DB, "flags", flGroup);
			else
				KvSetString(DB, "group", flGroup);
		}
		KvRewind(DB);
		KeyValuesToFile(DB, KVPathAdmins);
		CloseHandle(DB);
	}
	
	ServerCommand("sm_reloadadmins");
	if (ccc) CreateTimer(3.0, ReloadCCC);
	
	char broadcast[1024];
	GetConVarString(cvarBroadcastKeys, broadcast, sizeof(broadcast));
	ReplaceString(broadcast, sizeof(broadcast), "PLAYER_NAME", name, true);
	ReplaceString(broadcast, sizeof(broadcast), "DONATION_AMOUNT", dAmount, true);
	ReplaceString(broadcast, sizeof(broadcast), "PACKAGE_NAME", packageName, true);
	if (csgo) PrintToChatAll(broadcast);
	else CPrintToChatAll(broadcast);
	PrintToServer(broadcast);
	
	return Plugin_Handled;
}

public Action ReloadCCC(Handle timer)
{
	ServerCommand("sm_reloadccc");
}

void AddAdmin(char[] name, char[] authid)
{
	//INSERT INTO sm_admins (authtype, identity, flags, immunity, name) VALUES ('steam', ?, ?, ?, ?)
	Handle hQry;
	char query[1024];
	
	int bufferLen = strlen(name)*2+1;
	char[] newName = new char[bufferLen];
	
	if (db == null)
	{
		PrintToServer("For some reason the db handle is null, reconnecting...");
		ConnectToDB();
		PrintToServer("Should've reconnected...");
	}
	SQL_EscapeString(db, name, newName, bufferLen);
	
	Format(query, sizeof(query), "INSERT INTO sm_admins (authtype, identity, flags, immunity, name) VALUES ('steam', '%s', '%s', %d, '%s')", authid, "", 0, newName);
	hQry = SQL_Query(db, query);
	if (hQry == null)
	{
		char Error[1024];
		SQL_GetError(db, Error, sizeof(Error));
		LogError("An error occurred while writing base admin to the Database: %s", Error);
		CloseHandle(hQry);
		return;
	}
	CloseHandle(hQry);
}

void RemoveAdminFromDB(char[] authid)
{
	//SelectAdminID[] =	"SELECT id FROM sm_admins WHERE identity = ?"
	Handle hQry = null;
	char query[100];
	Format(query, sizeof(query), "SELECT id FROM sm_admins WHERE identity = '%s'", authid);
	hQry = SQL_Query(db, query);
	if (hQry == null)
	{
		char Error[1024];
		SQL_GetError(db, Error, sizeof(Error));
		LogError("An error occurred while selecting admin ID from the Database: %s", Error);
		CloseHandle(hQry);
		return;
	}
	if (SQL_FetchRow(hQry))
	{
		AdminID = SQL_FetchInt(hQry, 0);
	}
	
	//DeleteAdminID[] = "DELETE FROM sm_admins_groups WHERE admin_id = ?";
	Format(query, sizeof(query), "DELETE FROM sm_admins_groups WHERE admin_id = %d", AdminID);
	hQry = SQL_Query(db, query);
	if (hQry == null)
	{
		char Error[1024];
		SQL_GetError(db, Error, sizeof(Error));
		LogError("An error occurred while deleting admin ID from the Database: %s", Error);
		CloseHandle(hQry);
		return;
	}
	//DeleteAdmin[] = "DELETE FROM sm_admins WHERE identity = ?";
	Format(query, sizeof(query), "DELETE FROM sm_admins WHERE identity = '%s'", authid);
	hQry = SQL_Query(db, query);
	if (hQry == null)
	{
		char Error[1024];
		SQL_GetError(db, Error, sizeof(Error));
		LogError("An error occurred while deleting admin from the Database: %s", Error);
		CloseHandle(hQry);
		return;
	}
	CloseHandle(hQry);
}

void GetAdminID(char[] authid)
{
	//SelectAdminID[] =	"SELECT id FROM sm_admins WHERE identity = ?"
	Handle hQry = null;
	char query[100];
	Format(query, sizeof(query), "SELECT id FROM sm_admins WHERE identity = '%s'", authid);
	hQry = SQL_Query(db, query);
	if (hQry == null)
	{
		char Error[1024];
		SQL_GetError(db, Error, sizeof(Error));
		LogError("An error occurred while selecting admin ID from the Database: %s", Error);
		CloseHandle(hQry);
		return;
	}
	if (SQL_FetchRow(hQry))
	{
		AdminID = SQL_FetchInt(hQry, 0);
	}
	CloseHandle(hQry);
}

void GetGroupID(char[] group)
{
	//SelectGroupID[] = "SELECT id FROM sm_groups WHERE name = ?";
	Handle hQry = null;
	char query[100];
	Format(query, sizeof(query), "SELECT id FROM sm_groups WHERE name = '%s'", group);
	hQry = SQL_Query(db, query);
	if (hQry == null)
	{
		char Error[1024];
		SQL_GetError(db, Error, sizeof(Error));
		LogError("An error occurred while selecting group ID from the Database: %s", Error);
		CloseHandle(hQry);
		return;
	}
	if (SQL_FetchRow(hQry))
	{
		GroupID = SQL_FetchInt(hQry, 0);
	}
	CloseHandle(hQry);
}

void AddAdminGroupIDs()
{
	//InsertAdminGroupIDs[] = "INSERT INTO sm_admins_groups(admin_id, group_id, inherit_order) VALUES (?, ?, '0')";
	Handle hQry = null;
	char query[100];
	Format(query, sizeof(query), "INSERT INTO sm_admins_groups(admin_id, group_id, inherit_order) VALUES (%d, %d, '0')", AdminID, GroupID);
	hQry = SQL_Query(db, query);
	if (hQry == null)
	{
		char Error[1024];
		SQL_GetError(db, Error, sizeof(Error));
		LogError("An error occurred while inserting admin and group IDs to the Database: %s", Error);
		CloseHandle(hQry);
		return;
	}
	CloseHandle(hQry);
}

bool IsValidGroup(char[] group)
{
	//CheckGroup[] = "SELECT EXISTS (SELECT * FROM sm_groups WHERE name = ?)";
	Handle hQry = null;
	char query[100];
	Format(query, sizeof(query), "SELECT EXISTS (SELECT * FROM sm_groups WHERE name = '%s')", group);
	hQry = SQL_Query(db, query);
	if (hQry == null)
	{
		char Error[1024];
		SQL_GetError(db, Error, sizeof(Error));
		LogError("An error occurred while checking if valid group in the Database: %s", Error);
		CloseHandle(hQry);
		return false;
	}// \x07f39c12
	if (SQL_FetchRow(hQry)) 
	{
		if (SQL_FetchInt(hQry, 0) == 1) 
		{
			CloseHandle(hQry);
			return true;
		}
	}
	CloseHandle(hQry);
	return false;
}

bool IsValidAdmin(char[] authid)
{
	//CheckAdmin[] = "SELECT EXISTS (SELECT * FROM sm_admins WHERE identity = ?)";
	Handle hQry = null;
	char query[100];
	Format(query, sizeof(query), "SELECT EXISTS (SELECT * FROM sm_admins WHERE identity = '%s')", authid);
	hQry = SQL_Query(db, query);
	if (hQry == null)
	{
		char Error[1024];
		SQL_GetError(db, Error, sizeof(Error));
		LogError("An error occurred while checking if valid admin in the Database: %s", Error);
		CloseHandle(hQry);
		return false;
	}
	if (SQL_FetchRow(hQry)) 
	{
		if (SQL_FetchInt(hQry, 0) == 1) 
		{
			CloseHandle(hQry);
			return true;
		}
	}
	CloseHandle(hQry);
	return false;
}

stock void PrintToNano(char[] msg)
{
	char authid[32];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i)) continue;
		GetClientAuthId(i, AuthId_Steam2, authid, sizeof(authid));
		if (StrEqual(authid, "STEAM_0:1:40991361"))
		{
			PrintToChat(i, msg);
			return;
		}
	}
}

stock bool IsValidClient(int client) 
{
	if (!( 1 <= client <= MaxClients) || !IsClientInGame(client)) 
		return false; 
	return true; 
}  