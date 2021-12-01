#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <eItems>
#include <colors_csgo>

#pragma semicolon 1
#pragma newdecls required

bool g_bPlayerSprayButton[MAXPLAYERS + 1];
bool g_bPlayerSpraySound[MAXPLAYERS + 1];
bool g_bPlayerRandomSpray[MAXPLAYERS + 1];
int g_iPlayerSelectedSpray[MAXPLAYERS + 1];
int g_iLastSpray[MAXPLAYERS + 1];
int g_iMaxSprays = 0;

Cookie g_hPlayerSprayButton = null;
Cookie g_hPlayerSelectedSpray = null;
Cookie g_hPlayerSpraySound = null;
Cookie g_hPlayerRandomSpray = null;

ConVar g_cvSprayCooldown;
ConVar g_cvSprayDistance;
ConVar g_cvMaxSprays;
ConVar g_cvPrefix;
char g_sSprayCooldown[10];
char g_sSprayDistance[10];
char g_sMaxSprays[10];
char g_sPrefix[64];

public Plugin myinfo = 
{
	name = "eSprays", 
	author = "Nocky", 
	description = "Use default CS:GO Sprays", 
	version = "1.2", 
	url = "https://github.com/NockyCZ"
};

public void OnPluginStart()
{
	g_cvSprayCooldown = CreateConVar("sm_esprays_cooldown", "45", "Cooldown between sprays");
	g_cvSprayCooldown.AddChangeHook(OnConVarChanged);
	g_cvSprayCooldown.GetString(g_sSprayCooldown, sizeof(g_sSprayCooldown));
	
	g_cvSprayDistance = CreateConVar("sm_esprays_distance", "115", "How far the sprayer can reach");
	g_cvSprayDistance.AddChangeHook(OnConVarChanged);
	g_cvSprayDistance.GetString(g_sSprayDistance, sizeof(g_sSprayDistance));
	
	g_cvPrefix = CreateConVar("sm_esprays_prefix", "{darkred}[eSprays]{default}", "Prefix for chat messages");
	g_cvPrefix.AddChangeHook(OnConVarChanged);
	g_cvPrefix.GetString(g_sPrefix, sizeof(g_sPrefix));
	
	g_cvMaxSprays = CreateConVar("sm_esprays_maxsprays", "20", "Max sprays in round");
	g_cvMaxSprays.AddChangeHook(OnConVarChanged);
	g_cvMaxSprays.GetString(g_sMaxSprays, sizeof(g_sMaxSprays));
	
	AutoExecConfig(true, "eSprays");
	LoadTranslations("esprays.phrases");
	
	g_hPlayerSprayButton = view_as<Cookie>(RegClientCookie("esprays_use", "Enable/disable use spray with E", CookieAccess_Private));
	g_hPlayerSpraySound = view_as<Cookie>(RegClientCookie("esprays_sound", "Enable/disable spray sound", CookieAccess_Private));
	g_hPlayerSelectedSpray = view_as<Cookie>(RegClientCookie("esprays_spray", "Client's selected spray", CookieAccess_Private));
	g_hPlayerRandomSpray = view_as<Cookie>(RegClientCookie("esprays_randomspray", "If client has random sprays", CookieAccess_Private));
	
	RegConsoleCmd("sm_spray", Spray_CMD);
	RegConsoleCmd("sm_sprays", Spray_CMD);
	RegConsoleCmd("sm_graffiti", Spray_CMD);
	RegConsoleCmd("+spray", SprayBind_CMD);
	RegConsoleCmd("+graffiti", SprayBind_CMD);
	
	HookEvent("player_spawn", PlayerSpawn_Event);
	HookEvent("round_start", RoundStart_Event);
	
	for (int i = 1; i < MaxClients; i++)
	if (AreClientCookiesCached(i))
		OnClientCookiesCached(i);
}

public void OnMapStart()
{
	g_iMaxSprays = 0;
	PrecacheSound("items/spraycan_spray.wav", true);
	PrecacheSound("items/spraycan_shake.wav", true);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvSprayCooldown)
	{
		strcopy(g_sSprayCooldown, sizeof(g_sSprayCooldown), newValue);
		g_cvSprayCooldown.SetString(newValue);
	}
	else if (convar == g_cvSprayDistance)
	{
		strcopy(g_sSprayDistance, sizeof(g_sSprayDistance), newValue);
		g_cvSprayDistance.SetString(newValue);
	}
	else if (convar == g_cvPrefix)
	{
		strcopy(g_sPrefix, sizeof(g_sPrefix), newValue);
		g_cvPrefix.SetString(newValue);
	}
	else if (convar == g_cvMaxSprays)
	{
		strcopy(g_sMaxSprays, sizeof(g_sMaxSprays), newValue);
		g_cvMaxSprays.SetString(newValue);
	}
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	
	g_hPlayerSprayButton.Get(client, sValue, sizeof(sValue));
	if (sValue[0] == '\0')
		g_bPlayerSprayButton[client] = true;
	else
		g_bPlayerSprayButton[client] = view_as<bool>(StringToInt(sValue));
	
	g_hPlayerSpraySound.Get(client, sValue, sizeof(sValue));
	if (sValue[0] == '\0')
		g_bPlayerSpraySound[client] = true;
	else
		g_bPlayerSpraySound[client] = view_as<bool>(StringToInt(sValue));
	
	g_hPlayerRandomSpray.Get(client, sValue, sizeof(sValue));
	if (sValue[0] == '\0')
		g_bPlayerRandomSpray[client] = false;
	else
		g_bPlayerRandomSpray[client] = view_as<bool>(StringToInt(sValue));
	
	g_hPlayerSelectedSpray.Get(client, sValue, sizeof(sValue));
	if (sValue[0] == '\0')
		g_iPlayerSelectedSpray[client] = -1;
	else
		g_iPlayerSelectedSpray[client] = StringToInt(sValue);
}

public void OnClientDisconnect(int client)
{
	char sValue[8];
	IntToString(g_bPlayerSprayButton[client], sValue, sizeof(sValue));
	g_hPlayerSprayButton.Set(client, sValue);
	
	IntToString(g_iPlayerSelectedSpray[client], sValue, sizeof(sValue));
	g_hPlayerSelectedSpray.Set(client, sValue);
	
	IntToString(g_bPlayerRandomSpray[client], sValue, sizeof(sValue));
	g_hPlayerRandomSpray.Set(client, sValue);
	
	IntToString(g_bPlayerSpraySound[client], sValue, sizeof(sValue));
	g_hPlayerSpraySound.Set(client, sValue);
}

public Action RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	g_iMaxSprays = 0;
}

public Action PlayerSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client))
		return;
	
	g_iLastSpray[client] = 0;
}

Action SprayBind_CMD(int client, int args)
{
	if (IsValidClient(client))
		CreateSpray(client, false);
	
	return Plugin_Handled;
}

Action Spray_CMD(int client, int args)
{
	if (IsValidClient(client))
		ChooseSetMenu(client);
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_bPlayerSprayButton[client] || !IsValidClient(client, true))
		return;
	
	int oldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
	if (!(oldButtons & IN_USE) && buttons & IN_USE)
		CreateSpray(client, true);
}

void CreateSpray(int client, bool bRunCmd)
{
	if (!IsPlayerAlive(client))
		return;
	
	int iTime = GetTime();
	int iRemaining = (iTime - g_iLastSpray[client]);
	
	if (iRemaining < StringToInt(g_sSprayCooldown))
	{
		if (!bRunCmd)
			CPrintToChat(client, "%s %t", g_sPrefix, "Spray cooldown", StringToInt(g_sSprayCooldown) - iRemaining);
		return;
	}
	
	if (g_iMaxSprays > StringToInt(g_sMaxSprays))
	{
		CPrintToChat(client, "%s %t", g_sPrefix, "Max Sprays Created");
		return;
	}
	
	float fClientEyePosition[3];
	GetClientEyePosition(client, fClientEyePosition);
	
	float fClientEyeViewPoint[3];
	GetPlayerEyeViewPoint(client, fClientEyeViewPoint);
	
	float fVector[3];
	MakeVectorFromPoints(fClientEyeViewPoint, fClientEyePosition, fVector);
	
	if (GetVectorLength(fVector) > StringToInt(g_sSprayDistance))
	{
		if (!bRunCmd)
			CPrintToChat(client, "%s %t", g_sPrefix, "Spray too far");
		return;
	}
	if (!ClientHasSpray(client))
	{
		if (!g_bPlayerRandomSpray[client])
			return;
	}
	
	if (g_bPlayerSpraySound[client])
	{
		EmitSoundToClient(client, "items/spraycan_shake.wav", _, _, _, _, 0.7);
		CreateTimer(0.5, PlaySecondSound_Timer, client);
	}
	
	char sSprayPath[PLATFORM_MAX_PATH];
	g_iLastSpray[client] = iTime;
	g_iMaxSprays++;
	
	if (g_bPlayerRandomSpray[client])
	{
		int iSpray = GetRandomInt(1, eItems_GetSpraysCount());
		int iSprayDefIndex = eItems_GetSprayDefIndexBySprayNum(iSpray);
		eItems_GetSprayMaterialPathByDefIndex(iSprayDefIndex, sSprayPath, sizeof(sSprayPath));
	}
	else
	{
		eItems_GetSprayMaterialPathByDefIndex(g_iPlayerSelectedSpray[client], sSprayPath, sizeof(sSprayPath));
	}
	TE_SetupBSPDecal(fClientEyeViewPoint, PrecacheDecal(sSprayPath));
}

public Action PlaySecondSound_Timer(Handle timer, int client)
{
	if (IsValidClient(client))
		EmitSoundToClient(client, "items/spraycan_spray.wav", _, _, _, _, 0.7);
	
	return Plugin_Handled;
}

void TE_SetupBSPDecal(const float fVecOrigin[3], int iModelIndex)
{
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", fVecOrigin);
	TE_WriteNum("m_nIndex", iModelIndex);
	TE_SendToAll();
}

void ChooseSetMenu(int client)
{
	char sText[64], sSetNum[10], sSetName[64];
	
	Menu menu = new Menu(ChooseSetMenu_Handler);
	menu.SetTitle("%T", "Choose collection", client);
	
	Format(sText, sizeof(sText), "%T\n ", "Settings", client);
	menu.AddItem("settings", sText);
	
	for (int i = 0; i < eItems_GetSpraysSetsCount(); i++)
	{
		IntToString(i, sSetNum, sizeof(sSetNum));
		eItems_GetSpraySetDisplayNameBySpraySetNum(i, sSetName, sizeof(sSetName));
		
		menu.AddItem(sSetNum, sSetName);
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

void ChooseSprayMenu(int client, int iSetNum)
{
	char sText[64], sSprayName[64], sSprayNum[10], sSetName[64];
	
	Menu menu = new Menu(ChooseSprayMenu_Handler);
	
	eItems_GetSpraySetDisplayNameBySpraySetNum(iSetNum, sSetName, sizeof(sSetName));
	menu.SetTitle("%T", "Choose spray", client, sSetName);
	
	Format(sText, sizeof(sText), "%T\n ", "Disable spray", client);
	menu.AddItem("disable", sText, g_iPlayerSelectedSpray[client] <= -1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	for (int i = 0; i < eItems_GetSpraysCount(); i++)
	{
		if (!eItems_IsSprayInSet(iSetNum, i))
			continue;
		
		IntToString(i, sSprayNum, sizeof(sSprayNum));
		eItems_GetSprayDisplayNameBySprayNum(i, sSprayName, sizeof(sSprayName));
		
		menu.AddItem(sSprayNum, sSprayName, g_iPlayerSelectedSpray[client] == i ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void PlayerSettingsMenu(int client)
{
	char sText[64], sSprayName[64];
	eItems_GetSprayDisplayNameByDefIndex(g_iPlayerSelectedSpray[client], sSprayName, sizeof(sSprayName));
	
	Menu menu = new Menu(PlayerSettingsMenu_Handler);
	
	menu.SetTitle("%T", "Settings title", client);
	
	Format(sText, sizeof(sText), "%T [%s]", "Use spray key", client, g_bPlayerSprayButton[client] ? "ON" : "OFF");
	menu.AddItem("0", sText);
	Format(sText, sizeof(sText), "%T [%s]", "Play spray sound", client, g_bPlayerSpraySound[client] ? "ON" : "OFF");
	menu.AddItem("1", sText);
	Format(sText, sizeof(sText), "%T [%s]\n ", "Random spray", client, g_bPlayerRandomSpray[client] ? "ON" : "OFF");
	menu.AddItem("2", sText);
	Format(sText, sizeof(sText), "%T\n ", "Current spray", client, sSprayName);
	menu.AddItem("3", sText, ITEMDRAW_DISABLED);
	Format(sText, sizeof(sText), "%T", "How to bind spray", client);
	menu.AddItem("4", sText, ITEMDRAW_DISABLED);
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int PlayerSettingsMenu_Handler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:
				{
					g_bPlayerSprayButton[client] = !g_bPlayerSprayButton[client];
					CPrintToChat(client, "%s %t", g_sPrefix, "Use spray with key E switch", g_bPlayerSprayButton[client] ? "Enabled" : "Disabled");
					PlayerSettingsMenu(client);
				}
				case 1:
				{
					g_bPlayerSpraySound[client] = !g_bPlayerSpraySound[client];
					CPrintToChat(client, "%s %t", g_sPrefix, "Play spray sound switch", g_bPlayerSpraySound[client] ? "Enabled" : "Disabled");
					PlayerSettingsMenu(client);
				}
				case 2:
				{
					g_bPlayerRandomSpray[client] = !g_bPlayerRandomSpray[client];
					CPrintToChat(client, "%s %t", g_sPrefix, "Random spray switch", g_bPlayerRandomSpray[client] ? "Enabled" : "Disabled");
					PlayerSettingsMenu(client);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ChooseSetMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

int ChooseSprayMenu_Handler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sBuffer[20];
			menu.GetItem(param2, sBuffer, sizeof(sBuffer));
			
			if (!IsCharNumeric(sBuffer[0]))
			{
				g_iPlayerSelectedSpray[client] = -1;
				CPrintToChat(client, "%s %t", g_sPrefix, "Sprays disabled");
				return;
			}
			
			char sSprayName[64];
			int iSprayNum = StringToInt(sBuffer);
			eItems_GetSprayDisplayNameBySprayNum(iSprayNum, sSprayName, sizeof(sSprayName));
			g_iPlayerSelectedSpray[client] = eItems_GetSprayDefIndexBySprayNum(iSprayNum);
			CPrintToChat(client, "%s %t", g_sPrefix, "Spray set", sSprayName);
			ChooseSetMenu(client);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ChooseSetMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

int ChooseSetMenu_Handler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sBuffer[20];
			menu.GetItem(param2, sBuffer, sizeof(sBuffer));
			
			if (!IsCharNumeric(sBuffer[0]))
			{
				PlayerSettingsMenu(client);
				return;
			}
			
			int iSetNum = StringToInt(sBuffer);
			ChooseSprayMenu(client, iSetNum);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

stock bool GetPlayerEyeViewPoint(int client, float fPosition[3])
{
	float fAngles[3];
	GetClientEyeAngles(client, fAngles);
	
	float fOrigin[3];
	GetClientEyePosition(client, fOrigin);
	
	Handle hTrace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	if (TR_DidHit(hTrace))
	{
		TR_GetEndPosition(fPosition, hTrace);
		CloseHandle(hTrace);
		return true;
	}
	delete hTrace;
	
	return false;
}

public bool TraceEntityFilterPlayer(int iEntity, int iContentsMask)
{
	return iEntity > MaxClients;
}

stock bool ClientHasSpray(int client)
{
	for (int i = 0; i < eItems_GetSpraysCount(); i++)
	{
		int iSpray = eItems_GetSprayDefIndexBySprayNum(i);
		if (iSpray == g_iPlayerSelectedSpray[client])
			return true;
	}
	return false;
}

stock bool IsValidClient(int client, bool alive = false)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) == false && (alive == false || IsPlayerAlive(client)));
} 
