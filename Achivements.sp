
#define PLUGIN_AUTHOR "PyNiO ™"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <clientprefs>
#include <scp>

ConVar g_iWarmupOn;
ConVar g_iPlayerOn;
ConVar g_iPlayerKills;
ConVar g_iPlayerAssists;
ConVar g_iPlayerHeadshots;
ConVar g_iPlayerWin;
ConVar g_iPlayerLose;
ConVar g_iPlayerPlant;
ConVar g_iPlayerDefuse;
ConVar g_iPlayerKnife;
ConVar g_iPlayerTime;

int g_iKills[MAXPLAYERS + 1];
int g_iAssists[MAXPLAYERS + 1];
int g_iHeadshots[MAXPLAYERS + 1];
int g_iWin[MAXPLAYERS + 1];
int g_iLose[MAXPLAYERS + 1];
int g_iPlant[MAXPLAYERS + 1];
int g_iDefuse[MAXPLAYERS + 1];
int g_iKnife[MAXPLAYERS + 1];
int g_iTime[MAXPLAYERS + 1];
int g_iPlayerTag[MAXPLAYERS + 1];

Handle g_hSQL = INVALID_HANDLE;
bool g_bPlayerLoad[MAXPLAYERS + 1];
int g_iConnections;

new Handle:infocd1[MAXPLAYERS + 1];

new String:Error[100];

char g_sNames[][10] = 
{
	"-", 
	"Killer", 
	"Helpful guy", 
	"HeadHunter", 
	"Winner", 
	"Loser", 
	"Planter", 
	"Sapper", 
	"KnifeMaster", 
	"Nolife", 
};

public Plugin myinfo = 
{
	name = "Achievements", 
	author = PLUGIN_AUTHOR, 
	description = "Custom achievements for cs:go server", 
	version = PLUGIN_VERSION, 
	url = "https://steamcommunity.com/id/pynioanime/"
};

public void OnMapStart()
{
	g_iConnections = 0;
	ConnectSQL();
	
	AddFileToDownloadsTable("materials/overlays/achievements/head.vmt");
	AddFileToDownloadsTable("materials/overlays/achievements/head.vtf");
	AddFileToDownloadsTable("materials/overlays/achievements/help.vmt");
	AddFileToDownloadsTable("materials/overlays/achievements/help.vtf");
	AddFileToDownloadsTable("materials/overlays/achievements/killer.vmt");
	AddFileToDownloadsTable("materials/overlays/achievements/killer.vtf");
	AddFileToDownloadsTable("materials/overlays/achievements/loser.vmt");
	AddFileToDownloadsTable("materials/overlays/achievements/loser.vtf");
	AddFileToDownloadsTable("materials/overlays/achievements/planter.vmt");
	AddFileToDownloadsTable("materials/overlays/achievements/planter.vtf");
	AddFileToDownloadsTable("materials/overlays/achievements/sapper.vmt");
	AddFileToDownloadsTable("materials/overlays/achievements/sapper.vtf");
	AddFileToDownloadsTable("materials/overlays/achievements/winnner.vmt");
	AddFileToDownloadsTable("materials/overlays/achievements/winner.vtf");
	AddFileToDownloadsTable("materials/overlays/achievements/knife.vmt");
	AddFileToDownloadsTable("materials/overlays/achievements/knife.vtf");
	AddFileToDownloadsTable("sound/achievements/achievement.mp3");
	PrecacheSound("achievements/achievement.mp3", true);
}

public OnClientConnected(client)
{
	ClientCommand(client, "r_drawscreenoverlay 1");
	infocd1[client] = CreateTimer(60.0, time_server, client, TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
	g_bPlayerLoad[client] = false;
	Load(client);
	givetags(client);
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_achievements", cmd_achivements);
	RegConsoleCmd("sm_tag", cmd_tag);
	RegConsoleCmd("sm_stats", cmd_stats);
	
	HookEvent("player_death", Player_Death);
	HookEvent("round_end", Round_End);
	HookEvent("bomb_planted", BombPlanted);
	HookEvent("bomb_defused", BombDefused);
	
	g_iWarmupOn = CreateConVar("achievements_warmup_on", "0", "Getting achievement on warmup?", _, true, 0.0, true, 1.0);
	g_iPlayerOn = CreateConVar("achievements_players", "2", "How many players for getting achievement?", _, true, 1.0, true, 64.0);
	g_iPlayerKills = CreateConVar("achievements_kills", "20", "How many kills for achievement?", _, true, 1.0, true, 1000.0);
	g_iPlayerKnife = CreateConVar("achievements_knife", "5", "How many knife kills for achievement?", _, true, 1.0, true, 1000.0);
	g_iPlayerAssists = CreateConVar("achievements_assists", "5", "How many assists for achievement?", _, true, 1.0, true, 1000.0);
	g_iPlayerHeadshots = CreateConVar("achivements_headshots", "5", "How many headshots for achievement?", _, true, 1.0, true, 1000.0);
	g_iPlayerWin = CreateConVar("achievements_win", "10", "How many rounds wins for achievement?", _, true, 1.0, true, 1000.0);
	g_iPlayerLose = CreateConVar("achievements_lose", "10", "How many rounds lost for achievement?", _, true, 1.0, true, 1000.0);
	g_iPlayerPlant = CreateConVar("achievements_plant", "5", "How many bomb plants for achievement?", _, true, 1.0, true, 1000.0);
	g_iPlayerDefuse = CreateConVar("achievements_defuse", "5", "How many bomb defuses for achievement?", _, true, 1.0, true, 1000.0);
	g_iPlayerTime = CreateConVar("achievements_time", "5", "How many minutes on server for achievement?", _, true, 1.0, true, 1000.0);
	
	AutoExecConfig(true, "Achievements_Config");
}


////////////////////
////////Menu////////
////////////////////
public Action cmd_achivements(int client, int args)
{
	Handle menu = CreateMenu(MenuAchivementsHand);
	
	SetMenuTitle(menu, "Achievements: Menu");
	
	AddMenuItem(menu, "op1", "My Achievements");
	AddMenuItem(menu, "op2", "My Stats");
	AddMenuItem(menu, "op3", "All Achievements");
	AddMenuItem(menu, "op4", "Achievements Tags");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuAchivementsHand(Handle menu, MenuAction:action, client, itemNum)
{
	if (action == MenuAction_Select && IsValidPlayer(client))
	{
		char info[255];
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		if (StrEqual(info, "op1"))
		{
			PrintToChat(client, " \x02---------------- \x01My Achievements \x02----------------");
			
			if (g_iKills[client] >= g_iPlayerKills.IntValue)
			{
				PrintToChat(client, " \x04%s [Owned]", g_sNames[1]);
			}
			if (g_iAssists[client] >= g_iPlayerAssists.IntValue)
			{
				PrintToChat(client, " \x04%s [Owned]", g_sNames[2]);
			}
			if (g_iHeadshots[client] >= g_iPlayerHeadshots.IntValue)
			{
				PrintToChat(client, " \x04%s [Owned]", g_sNames[3]);
			}
			if (g_iWin[client] >= g_iPlayerWin.IntValue)
			{
				PrintToChat(client, " \x04%s [Owned]", g_sNames[4]);
			}
			if (g_iLose[client] >= g_iPlayerLose.IntValue)
			{
				PrintToChat(client, " \x04%s [Owned]", g_sNames[5]);
			}
			if (g_iPlant[client] >= g_iPlayerPlant.IntValue)
			{
				PrintToChat(client, " \x04%s [Owned]", g_sNames[6]);
			}
			if (g_iDefuse[client] >= g_iPlayerDefuse.IntValue)
			{
				PrintToChat(client, " \x04%s [Owned]", g_sNames[7]);
			}
			if (g_iKnife[client] >= g_iPlayerKnife.IntValue)
			{
				PrintToChat(client, " \x04%s [Owned]", g_sNames[8]);
			}
			if (g_iTime[client] >= g_iPlayerTime.IntValue)
			{
				PrintToChat(client, " \x04%s [Owned]", g_sNames[9]);
			}
			
			PrintToChat(client, " \x02---------------------------------------------");
		}
		if (StrEqual(info, "op2"))
		{
			PrintToChat(client, " \x02---------------- \x01My Statistics \x02----------------");
			PrintToChat(client, " \x04Kills: %i", g_iKills[client]);
			PrintToChat(client, " \x04Assists: %i", g_iAssists[client]);
			PrintToChat(client, " \x04Headshots %i", g_iHeadshots[client]);
			PrintToChat(client, " \x04Win: %i", g_iWin[client]);
			PrintToChat(client, " \x04Lose: %i", g_iLose[client]);
			PrintToChat(client, " \x04Bomb planted: %i", g_iPlant[client]);
			PrintToChat(client, " \x04Bomb defused: %i", g_iDefuse[client]);
			PrintToChat(client, " \x04Knife kills: %i", g_iKnife[client]);
			PrintToChat(client, " \x02---------------------------------------------");
		}
		if (StrEqual(info, "op3"))
		{
			stats(client);
		}
		if (StrEqual(info, "op4"))
		{
			playertag(client);
		}
	}
}

////////////////////
///////Stats////////
////////////////////
public Action cmd_stats(int client, int args)
{
	if (IsValidPlayer(client))
	{
		stats(client);
	}
}

public stats(int client)
{
	if (IsValidPlayer(client))
	{
		PrintToChat(client, " \x02---------------- \x01All Achievements \x02----------------");
		
		PrintToChat(client, " \x04%s: [%i / %i]", g_sNames[1], g_iKills[client], g_iPlayerKills.IntValue);
		PrintToChat(client, " \x04%s: [%i / %i]", g_sNames[2], g_iAssists[client], g_iPlayerAssists.IntValue);
		PrintToChat(client, " \x04%s: [%i / %i]", g_sNames[3], g_iHeadshots[client], g_iPlayerHeadshots.IntValue);
		PrintToChat(client, " \x04%s: [%i / %i]", g_sNames[4], g_iWin[client], g_iPlayerWin.IntValue);
		PrintToChat(client, " \x04%s: [%i / %i]", g_sNames[5], g_iLose[client], g_iPlayerLose.IntValue);
		PrintToChat(client, " \x04%s: [%i / %i]", g_sNames[6], g_iPlant[client], g_iPlayerPlant.IntValue);
		PrintToChat(client, " \x04%s: [%i / %i]", g_sNames[7], g_iDefuse[client], g_iPlayerDefuse.IntValue);
		PrintToChat(client, " \x04%s: [%i / %i]", g_sNames[8], g_iKnife[client], g_iPlayerKnife.IntValue);
		
		PrintToChat(client, " \x02---------------------------------------------");
	}
}

////////////////////
////////Tags////////
////////////////////
public Action cmd_tag(int client, int args)
{
	if (IsValidPlayer(client))
	{
		playertag(client);
	}
}

public playertag(int client)
{
	Menu menu = new Menu(MenuTagHandler, MenuAction_Start | MenuAction_Select | MenuAction_Cancel | MenuAction_End);
	
	SetMenuTitle(menu, "Achievements: Tags");
	
	menu.AddItem("op1", "▸ Killer", g_iKills[client] < g_iPlayerKills.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("op2", "▸ HelpfulGuy", g_iAssists[client] < g_iPlayerAssists.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("op3", "▸ HeadHunter", g_iHeadshots[client] < g_iPlayerHeadshots.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("op4", "▸ Winner", g_iWin[client] < g_iPlayerWin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("op5", "▸ Loser", g_iLose[client] < g_iPlayerLose.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("op6", "▸ Planter", g_iPlant[client] < g_iPlayerPlant.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("op7", "▸ Sapper", g_iDefuse[client] < g_iPlayerDefuse.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("op8", "▸ KnifeMaster", g_iKnife[client] < g_iPlayerKnife.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("op8", "▸ Nolife", g_iTime[client] < g_iPlayerTime.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	menu.ExitButton = true;
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuTagHandler(Handle menu, MenuAction:action, client, itemNum)
{
	if (action == MenuAction_Select && IsValidPlayer(client))
	{
		char info[255];
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		if (StrEqual(info, "op1"))
		{
			g_iPlayerTag[client] = 1;
			givetags(client);
			Save(client);
		}
		else if (StrEqual(info, "op2"))
		{
			g_iPlayerTag[client] = 2;
			givetags(client);
			Save(client);
		}
		else if (StrEqual(info, "op3"))
		{
			g_iPlayerTag[client] = 3;
			givetags(client);
			Save(client);
		}
		else if (StrEqual(info, "op4"))
		{
			g_iPlayerTag[client] = 4;
			givetags(client);
			Save(client);
		}
		else if (StrEqual(info, "op5"))
		{
			g_iPlayerTag[client] = 5;
			givetags(client);
			Save(client);
		}
		else if (StrEqual(info, "op6"))
		{
			g_iPlayerTag[client] = 6;
			givetags(client);
			Save(client);
		}
		else if (StrEqual(info, "op7"))
		{
			g_iPlayerTag[client] = 7;
			givetags(client);
			Save(client);
		}
		else if (StrEqual(info, "op8"))
		{
			g_iPlayerTag[client] = 8;
			givetags(client);
			Save(client);
		}
		else if (StrEqual(info, "op9"))
		{
			g_iPlayerTag[client] = 9;
			givetags(client);
			Save(client);
		}
	}
}

void givetags(int client)
{
	
	if (g_iPlayerTag[client] == 1)
	{
		CS_SetClientClanTag(client, "[Killer] ");
	}
	else if (g_iPlayerTag[client] == 2)
	{
		CS_SetClientClanTag(client, "[HelpfulGuy]");
	}
	else if (g_iPlayerTag[client] == 3)
	{
		CS_SetClientClanTag(client, "[HeadHunter] ");
	}
	else if (g_iPlayerTag[client] == 4)
	{
		CS_SetClientClanTag(client, "[Winner] ");
	}
	else if (g_iPlayerTag[client] == 5)
	{
		CS_SetClientClanTag(client, "[Loser] ");
	}
	else if (g_iPlayerTag[client] == 6)
	{
		CS_SetClientClanTag(client, "[Planter] ");
	}
	else if (g_iPlayerTag[client] == 7)
	{
		CS_SetClientClanTag(client, "[Sapper] ");
	}
	else if (g_iPlayerTag[client] == 8)
	{
		CS_SetClientClanTag(client, "[KnifeMaster] ");
	}
	else if (g_iPlayerTag[client] == 9)
	{
		CS_SetClientClanTag(client, "[Nolife] ");
	}
}

public Action OnChatMessage(&author, Handle recipients, String:name[], String:message[])
{
	if (IsValidPlayer(author))
	{
		if (g_iPlayerTag[author] > 0)
		{
			Format(name, MAXLENGTH_NAME, "%s", name);
			new MaxMessageLength = MAXLENGTH_MESSAGE - strlen(name) - 5;
			Format(name, MaxMessageLength, " \x02[%s] \x01%s", g_sNames[g_iPlayerTag[author]], name);
			return Plugin_Changed;
		}
		else
		{
			Format(name, MAXLENGTH_NAME, "%s", name);
			new MaxMessageLength = MAXLENGTH_MESSAGE - strlen(name) - 5;
			Format(name, MaxMessageLength, " %s", name);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

////////////////////
////Achivements/////
////////////////////
public Action Player_Death(Handle event, char[] name2, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(event, "assister"));
	bool headshot = GetEventBool(event, "headshot");
	int active_weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	char classname[50];
	GetEntityClassname(active_weapon, classname, sizeof(classname));
	
	if (!IsEnableOnWarmup())
		return Plugin_Continue;
	else
	{
		if (client != attacker)
		{
			if (IsValidPlayers() >= g_iPlayerOn.IntValue)
			{
				if (IsValidPlayer(attacker))
				{
					g_iKills[attacker] = g_iKills[attacker] + 1;
					Save(attacker);
					
					if (g_iKills[attacker] == g_iPlayerKills.IntValue)
					{
						sound(attacker);
						ClientCommand(attacker, "r_screenoverlay overlays/achievements/killer");
						CreateTimer(3.0, offover, attacker);
						Save(attacker);
						PrintToChatAll(" \x04Player \x02%N \x04gets achievement: \x02%s \x04!", g_sNames[1], attacker);
					}
					
					if (StrEqual(classname, "weapon_knife") || StrEqual(classname, "weapon_knife_t") || StrEqual(classname, "weapon_knife_css") || StrEqual(classname, "weapon_bayonet") || StrEqual(classname, "weapon_knife_flip") || StrEqual(classname, "weapon_knife_gut") || StrEqual(classname, "weapon_knife_karambit") || StrEqual(classname, "weapon_knife_m9_bayonet") || StrEqual(classname, "weapon_knife_tactical") || StrEqual(classname, "weapon_knife_butterfly") || StrEqual(classname, "weapon_knife_falchion") || StrEqual(classname, "weapon_knife_push") || StrEqual(classname, "weapon_knife_survival_bowie") || StrEqual(classname, "weapon_knife_ursus") || StrEqual(classname, "weapon_knife_gypsy_jackknife") || StrEqual(classname, "weapon_knife_stiletto") || StrEqual(classname, "weapon_knife_widowmaker") || StrEqual(classname, "weapon_knife_outdoor") || StrEqual(classname, "weapon_knife_canis") || StrEqual(classname, "weapon_knife_cord") || StrEqual(classname, "weapon_knife_skeleton"))
					{
						g_iKnife[attacker] = g_iKnife[attacker] + 1;
						Save(attacker);
						
						if (g_iKnife[attacker] == g_iPlayerKnife.IntValue)
						{
							sound(attacker);
							ClientCommand(attacker, "r_screenoverlay overlays/achievements/knife");
							CreateTimer(3.0, offover, attacker);
							Save(attacker);
							PrintToChatAll(" \x04Player \x02%N \x04gets achievement: \x02%s \x04!", g_sNames[8], attacker);
						}
					}
					
				}
				
				if (IsValidPlayer(assister))
				{
					g_iAssists[assister] = g_iAssists[assister] + 1;
					Save(assister);
					
					if (g_iAssists[assister] == g_iPlayerAssists.IntValue)
					{
						sound(assister);
						ClientCommand(assister, "r_screenoverlay overlays/achievements/help");
						CreateTimer(3.0, offover, assister);
						Save(assister);
						PrintToChatAll(" \x04Player \x02%N \x04gets achievement: \x02%s \x04!", g_sNames[2], assister);
					}
				}
				
				if (headshot)
				{
					if (IsValidPlayer(attacker))
					{
						g_iHeadshots[attacker] = g_iHeadshots[attacker] + 1;
						Save(attacker);
						
						if (g_iHeadshots[attacker] == g_iPlayerHeadshots.IntValue)
						{
							sound(attacker);
							ClientCommand(attacker, "r_screenoverlay overlays/achievements/head");
							CreateTimer(3.0, offover, attacker);
							Save(attacker);
							PrintToChatAll(" \x04Player \x02%N \x04gets achievement: \x02%s \x04!", g_sNames[3], attacker);
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
	
}

public BombPlanted(Handle event, const String:name[], bool dontBroadcast)
{
	new userid = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidPlayers() >= g_iPlayerOn.IntValue)
	{
		if (IsValidPlayer(userid))
		{
			g_iPlant[userid] = g_iPlant[userid] + 1;
			Save(userid);
			
			if (g_iPlant[userid] == g_iPlayerPlant.IntValue)
			{
				sound(userid);
				ClientCommand(userid, "r_screenoverlay overlays/achievements/planter");
				CreateTimer(3.0, offover, userid);
				Save(userid);
				PrintToChatAll(" \x04Player \x02%N \x04gets achievement: \x02%s \x04!", g_sNames[6], userid);
			}
		}
	}
}

public BombDefused(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidPlayers() >= g_iPlayerOn.IntValue)
	{
		if (IsValidPlayer(userid))
		{
			g_iDefuse[userid] = g_iDefuse[userid] + 1;
			Save(userid);
			
			if (g_iDefuse[userid] == g_iPlayerDefuse.IntValue)
			{
				sound(userid);
				ClientCommand(userid, "r_screenoverlay overlays/achievements/sapper");
				CreateTimer(3.0, offover, userid);
				Save(userid);
				PrintToChatAll(" \x04Player \x02%N \x04gets achievement: \x02%s \x04!", g_sNames[7], userid);
			}
		}
	}
}

public Round_End(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (IsValidPlayers() >= g_iPlayerOn.IntValue)
	{
		new wygrana_druzyna = GetEventInt(event, "winner");
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;
			
			if (GetClientTeam(i) != ((wygrana_druzyna == 2) ? CS_TEAM_T:CS_TEAM_CT))
			{
				
				if (IsValidPlayer(i))
				{
					g_iLose[i] = g_iLose[i] + 1;
					Save(i);
					
					if (g_iLose[i] == g_iPlayerLose.IntValue)
					{
						sound(i);
						ClientCommand(i, "r_screenoverlay overlays/achievements/loser");
						CreateTimer(3.0, offover, i);
						Save(i);
						PrintToChatAll(" \x04Player \x02%N \x04gets achievement: \x02%s \x04!", g_sNames[4], i);
					}
				}
			}
			else
			{
				if (IsValidPlayer(i))
				{
					g_iWin[i] = g_iWin[i] + 1;
					Save(i);
					
					if (g_iWin[i] == g_iPlayerWin.IntValue)
					{
						sound(i);
						ClientCommand(i, "r_screenoverlay overlays/achievements/winner");
						CreateTimer(3.0, offover, i);
						Save(i);
						PrintToChatAll(" \x04Player \x02%N \x04gets achievement: \x02%s \x04!", g_sNames[5], i);
					}
				}
			}
		}
	}
}

////////////////////
////////SQL/////////
////////////////////
public void ConnectSQL()
{
	if (g_hSQL != null)
	{
		CloseHandle(g_hSQL);
	}
	
	if (SQL_CheckConfig("achievements"))
	{
		char _cError[255];
		
		if (!(g_hSQL = SQL_Connect("achievements", true, _cError, 255)))
		{
			if (g_iConnections < 5)
			{
				g_iConnections++;
				LogError("ERROR: %s", _cError);
				ConnectSQL();
				
				return;
			}
			g_iConnections = 0;
		}
	}
	
	new Handle:queryH = SQL_Query(g_hSQL, "CREATE TABLE IF NOT EXISTS `Players` ( `STEAMID64` VARCHAR(128) NOT NULL UNIQUE , `name` VARCHAR(128) NOT NULL , `killq` INT(11) NOT NULL , `assist` INT(11) NOT NULL , `head` INT(11) NOT NULL , `win` INT(11) NOT NULL , `lose` INT(11) NOT NULL , `plant` INT(11) NOT NULL , `defuse` INT(11) NOT NULL , `tag` INT(11) NOT NULL , `knifeq` INT(11) NOT NULL, `timeq` INT(11) NOT NULL)");
	if (queryH != INVALID_HANDLE)
	{
		PrintToServer("Succesfully create database.");
	}
	else
	{
		SQL_GetError(g_hSQL, Error, sizeof(Error));
		PrintToServer("Database wasn't created. Error: %s", Error);
	}
}

public void Load(int client)
{
	
	if (!IsValidPlayer(client))
		return;
	
	if (!g_hSQL)
	{
		ConnectSQL();
		Load(client);
		return;
	}
	
	
	char _cBuffer[1024];
	char _cSteamID64[64];
	char s_name[64];
	
	GetClientAuthId(client, AuthId_SteamID64, _cSteamID64, sizeof(_cSteamID64));
	Format(_cBuffer, sizeof(_cBuffer), "SELECT * FROM Players WHERE STEAMID64 = '%s'", _cSteamID64);
	GetClientName(client, s_name, sizeof(s_name));
	
	Handle _HQuery = SQL_Query(g_hSQL, _cBuffer);
	
	if (_HQuery != INVALID_HANDLE)
	{
		
		bool _bFetch = SQL_FetchRow(_HQuery);
		if (_bFetch)
		{
			Format(_cSteamID64, sizeof(_cSteamID64), "");
			SQL_FetchString(_HQuery, 0, _cSteamID64, 63);
			
			Format(s_name, sizeof(s_name), "");
			SQL_FetchString(_HQuery, 1, s_name, 64);
			
			g_iKills[client] = SQL_FetchInt(_HQuery, 2);
			g_iAssists[client] = SQL_FetchInt(_HQuery, 3);
			g_iHeadshots[client] = SQL_FetchInt(_HQuery, 4);
			g_iWin[client] = SQL_FetchInt(_HQuery, 5);
			g_iLose[client] = SQL_FetchInt(_HQuery, 6);
			g_iPlant[client] = SQL_FetchInt(_HQuery, 7);
			g_iDefuse[client] = SQL_FetchInt(_HQuery, 8);
			g_iPlayerTag[client] = SQL_FetchInt(_HQuery, 9);
			g_iKnife[client] = SQL_FetchInt(_HQuery, 10);
			g_iTime[client] = SQL_FetchInt(_HQuery, 11);
			
			if (_cSteamID64[0])
			{
				g_bPlayerLoad[client] = true;
			}
			
			CloseHandle(_HQuery);
			return;
		}
	}
	
	CloseHandle(_HQuery);
	Format(_cBuffer, sizeof(_cBuffer), "INSERT IGNORE INTO Players VALUES ('%s', '%s','0','0','0','0','0','0','0','0','0','0')", _cSteamID64, s_name);
	
	SQL_Query(g_hSQL, _cBuffer);
	Load(client);
}

public void Save(int client)
{
	if (!IsValidPlayer(client))
		return;
	
	if (!g_hSQL)
	{
		ConnectSQL();
		return;
	}
	
	char _cBuffer[1024];
	char _cSteamID64[64];
	
	GetClientAuthId(client, AuthId_SteamID64, _cSteamID64, sizeof(_cSteamID64));
	
	
	Format(_cBuffer, sizeof(_cBuffer), "UPDATE Players SET  killq=%i, assist=%i, head=%i, win=%i, lose=%i, plant=%i, defuse=%i, tag=%i, knifeq=%i, timeq=%i  WHERE STEAMID64 = '%s'", g_iKills[client], g_iAssists[client], g_iHeadshots[client], g_iWin[client], g_iLose[client], g_iPlant[client], g_iDefuse[client], g_iPlayerTag[client], g_iKnife[client], g_iTime[client], _cSteamID64);
	
	SQL_Query(g_hSQL, _cBuffer);
	
}

////////////////////
/////Some stuff/////
////////////////////

void sound(int client)
{
	ClientCommand(client, "play *achievements/achievement.mp3");
}
public Action offover(Handle:timer, any:client)
{
	if (IsValidPlayer(client))
	{
		ClientCommand(client, "r_screenoverlay \"\"");
	}
}
public IsValidPlayers()
{
	int players;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		players++;
	}
	
	return players;
}
stock bool IsValidPlayer(int client)
{
	if (client >= 1 && client <= MaxClients && IsClientConnected(client) && !IsFakeClient(client) && IsClientInGame(client))
		return true;
	
	return false;
}
public bool IsEnableOnWarmup()
{
	if (GameRules_GetProp("m_bWarmupPeriod") != 0)
		return g_iWarmupOn.BoolValue;
	return true;
}

public Action time_server(Handle:timer, any:client)
{
	if (IsValidPlayer(client))
	{
		if (!IsEnableOnWarmup())
			return Plugin_Continue;
		else
		{
			g_iTime[client] = g_iTime[client] + 1;
			Save(client);
			
			if (g_iTime[client] == g_iPlayerTime.IntValue)
			{
				sound(client);
				ClientCommand(client, "r_screenoverlay overlays/achievements/time");
				CreateTimer(3.0, offover, client);
				Save(client);
				PrintToChatAll(" \x04Player \x02%N \x04gets achievement: \x02%s \x04!", g_sNames[9], client);
			}
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (client != 0)
	{
		if (infocd1[client] != INVALID_HANDLE)
		{
			KillTimer(infocd1[client]);
			infocd1[client] = INVALID_HANDLE;
		}
	}
}
