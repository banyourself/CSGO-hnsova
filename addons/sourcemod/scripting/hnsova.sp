#include <sourcemod>
#include <protobuf>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <adminmenu>
#include <clientprefs>
#include <ripext>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION                "1.0.2"
#define AUTHOR                        "ceLoFaN + Kevin"

// Discord embed sidebar colors, read through the natives at the bottom. hnsmix owns the embed.
#define HNS_EMBED_COLOR               3447003     // blue
#define OVA_EMBED_COLOR               10181046    // purple

// hnsmix exposes this during mix setup or play. Optional, so hidenseek still loads without it.
native int kev_isMixActive();

// KevFJ exposes this while funjump runs. Practice mode: knives do nothing and fast knife is on.
native int kev_isFJActive();

// ConVar Defines
#define HIDENSEEK_ENABLED             "1"
#define COUNTDOWN_TIME                "5.0"
#define MAXIMUM_WIN_STREAK            "5"
#define FLASHBANG_CHANCE              "1.0"
#define MOLOTOV_CHANCE                "0.1"
#define SMOKE_CHANCE                  "0.3"
#define DECOY_CHANCE                  "1.0"
#define HE_CHANCE                     "0.2"
#define FLASHBANG_MAXIMUM_AMOUNT      "2"
#define MOLOTOV_MAXIMUM_AMOUNT        "1"
#define SMOKE_MAXIMUM_AMOUNT          "1"
#define DECOY_MAXIMUM_AMOUNT          "1"
#define HE_MAXIMUM_AMOUNT             "1"
#define COUNTDOWN_FADE                "0"
#define NO_FLASH_BLIND                "2"
#define BLOCK_JOIN_TEAM               "1"
#define ATTACK_WHILE_FROZEN           "0"
#define FROSTNADES                    "1"
#define SELF_FREEZE                   "0"
#define FREEZE_GLOW                   "1"
#define FROSTNADES_TRAIL              "1"
#define FREEZE_DURATION               "3.0"
#define FREEZE_FADE                   "0"
#define FREEZE_RADIUS                 "175.0"
#define DETONATION_RING               "1"
#define BLOCK_CONSOLE_KILL            "1"
#define MOLOTOV_FRIENDLY_FIRE         "0"
#define HIDE_RADAR                    "1"
#define WELCOME_MESSAGE               "1"
#define DAMAGE_SLOWDOWN               "0"
#define FAST_KNIFE                    "0"
#define WINS_FOR_FAST_KNIFE           "3"
#define GRENADE_NO_BLOCK              "0"
#define ALLOW_WEAPONS                 "1"
#define ADMINMENU                     "1"
#define SCORE_CRASH_FIX               "1"

// Fade Defines
#define FFADE_IN               0x0001
#define FFADE_OUT              0x0002
#define FFADE_MODULATE         0x0004
#define FFADE_STAYOUT          0x0008
#define FFADE_PURGE            0x0010
#define COUNTDOWN_COLOR        {0,0,0,232}
#define FROST_COLOR            {20,63,255,255}
#define FREEZE_COLOR           {20,63,255,167}

// In-game Team Defines
#define JOINTEAM_RND       0
#define JOINTEAM_SPEC      1
#define JOINTEAM_T         2
#define JOINTEAM_CT        3

// Grenade Defines
#define NADE_FLASHBANG    0
#define NADE_MOLOTOV      1
#define NADE_SMOKE        2
#define NADE_HE           3
#define NADE_DECOY        4
#define NADE_INCENDIARY   5

// Freeze Type Defines
#define COUNTDOWN    0
#define FROSTNADE    1

// Sound Defines
#define SOUND_UNFREEZE             "physics/glass/glass_impact_bullet4.wav"
#define SOUND_FROSTNADE_EXPLODE    "ui/freeze_cam.wav"

#define HIDE_RADAR_CSGO 1<<12

#define RESPAWN_PROTECTION_TIME_ADDON 2.0

#define COLLISION_GROUP_DEBRIS_TRIGGER 2 // from public/const.h

// Mode Defines
#define HNSMODE_NORMAL      0
#define HNSMODE_RESPAWN     1

public Plugin myinfo =
{
    name = "HNS with OVA",
    author = AUTHOR,
    description = "CTs with only knives chase the Ts",
    version = PLUGIN_VERSION,
    url = "id/iamarealplayer"
};

//API vars
Handle g_hOnCountdownEndForward;

ConVar g_hEnabled;
ConVar g_hCountdownTime;
ConVar g_hCountdownFade;
ConVar g_hSkipCountdown;
ConVar g_hMaximumWinStreak;
ConVar g_hFlashbangChance;
ConVar g_hMolotovChance;
ConVar g_hSmokeGrenadeChance;
ConVar g_hDecoyChance;
ConVar g_hHEGrenadeChance;
ConVar g_hFlashbangMaximumAmount;
ConVar g_hMolotovMaximumAmount;
ConVar g_hSmokeGrenadeMaximumAmount;
ConVar g_hDecoyMaximumAmount;
ConVar g_hHEGrenadeMaximumAmount;
ConVar g_hFlashBlindDisable;
ConVar g_hBlockJoinTeam;
ConVar g_hFrostNades;
ConVar g_hSelfFreeze;
ConVar g_hAttackWhileFrozen;
ConVar g_hFreezeGlow;
ConVar g_hFreezeDuration;
ConVar g_hFreezeFade;
ConVar g_hFrostNadesTrail;
ConVar g_hFreezeRadius;
ConVar g_hFrostNadesDetonationRing;
ConVar g_hBlockConsoleKill;
ConVar g_hMolotovFriendlyFire;
ConVar g_hHideRadar;
ConVar g_hHideHudBits;
ConVar g_hWelcomeMessage;
ConVar g_hDamageSlowdown;
ConVar g_hFastKnife;
ConVar g_hWinsForFastKnife;
ConVar g_hTKnife;
ConVar g_hStabThroughMates;
ConVar g_hStabThroughRange;
ConVar g_hGrenadeNoBlock;
ConVar g_hAllowWeapons;
ConVar g_hLoadoutAccess;

Handle g_hToggleKnifeCookie;

// !hns cosmetic loadout: a gun and/or pistol per team, given on spawn and immediately
// ammo-stripped (OnWeaponEquipPost), so they are pure cosmetics. 0 = None, otherwise
// index+1. WARNING: only APPEND to these arrays, saved cookies store indices.
#define COSMETIC_CT 0
#define COSMETIC_T  1

static const char g_saCosmeticGuns[][] = {
    "weapon_ak47", "weapon_m4a1", "weapon_m4a1_silencer", "weapon_famas",
    "weapon_galilar", "weapon_aug", "weapon_sg556", "weapon_awp",
    "weapon_ssg08", "weapon_scar20", "weapon_g3sg1", "weapon_mp9",
    "weapon_mac10", "weapon_mp7", "weapon_mp5sd", "weapon_ump45",
    "weapon_p90", "weapon_bizon", "weapon_nova", "weapon_xm1014",
    "weapon_mag7", "weapon_sawedoff", "weapon_m249", "weapon_negev"
};
static const char g_saCosmeticGunNames[][] = {
    "AK-47", "M4A4", "M4A1-S", "FAMAS",
    "Galil AR", "AUG", "SG 553", "AWP",
    "SSG 08", "SCAR-20", "G3SG1", "MP9",
    "MAC-10", "MP7", "MP5-SD", "UMP-45",
    "P90", "PP-Bizon", "Nova", "XM1014",
    "MAG-7", "Sawed-Off", "M249", "Negev"
};
static const char g_saCosmeticPistols[][] = {
    "weapon_glock", "weapon_usp_silencer", "weapon_hkp2000", "weapon_p250",
    "weapon_elite", "weapon_fiveseven", "weapon_tec9", "weapon_cz75a",
    "weapon_deagle", "weapon_revolver"
};
static const char g_saCosmeticPistolNames[][] = {
    "Glock-18", "USP-S", "P2000", "P250",
    "Dual Berettas", "Five-SeveN", "Tec-9", "CZ75-Auto",
    "Desert Eagle", "R8 Revolver"
};

int g_iaCosmeticGun[MAXPLAYERS + 1][2];
int g_iaCosmeticPistol[MAXPLAYERS + 1][2];
int g_iaCosmeticMenuTeam[MAXPLAYERS + 1];      // team being configured while browsing
bool g_baCosmeticMenuPistols[MAXPLAYERS + 1];  // category being browsed
bool g_baCosmeticsAnnounced[MAXPLAYERS + 1];   // loadout summary shown this connection
Handle g_hCosmeticsCookie;

bool g_bEnabled;
float g_fCountdownTime;
bool g_bCountdownFade;
bool g_bSkipCountdown;
int g_iMaximumWinStreak;
int g_iFlashBlindDisable;
bool g_bBlockJoinTeam;
bool g_bAttackWhileFrozen;
bool g_bFrostNades;
bool g_bSelfFreeze;
float g_fFreezeDuration;
bool g_bFreezeFade;
bool g_bFreezeGlow;
bool g_bFrostNadesTrail;
float g_fFreezeRadius;
bool g_bFrostNadesDetonationRing;
bool g_bBlockConsoleKill;
bool g_bMolotovFriendlyFire;
float g_faGrenadeChance[6] = {0.0, ...};
int g_iaGrenadeMaximumAmounts[6] = {0, ...};
bool g_bHideRadar;
bool g_bWelcomeMessage;
bool g_bDamageSlowdown;
int g_iFastKnife;
int g_iWinsForFastKnife;
bool g_bTKnife; // Ts may knife-damage CTs (hnsmix knife rounds)
bool g_bGrenadeNoBlock;
bool g_bAllowWeapons;
bool g_bAdminMenu = true;

// hnsmix changes both cvars before restarting a knife round. Treat either as active so the two cannot disagree.
bool IsKnifeRoundCombatEnabled()
{
    return g_bTKnife || g_bSkipCountdown;
}
bool g_bScoreCrashFix = true;

//Spawn protection vars (protects freshly spawned CTs during the countdown)
bool g_baRespawnProtection[MAXPLAYERS + 1] = {true, ...};

// ---- OVA (One Versus All) ----
ConVar g_hOvaGameMode;
ConVar g_hOvaRoundTime;
ConVar g_hOvaNoBlock;
ConVar g_hOvaTProtect;
ConVar g_hOvaDiscordLbWebhook, g_hOvaDiscordName, g_hOvaDiscordPrefix, g_hOvaDiscordLbEntries, g_hOvaDiscordLbColor;
ConVar g_hOvaFlashbangChance, g_hOvaMolotovChance, g_hOvaSmokeChance, g_hOvaDecoyChance, g_hOvaHEChance;
ConVar g_hOvaFlashbangMax, g_hOvaMolotovMax, g_hOvaSmokeMax, g_hOvaDecoyMax, g_hOvaHEMax;

bool  g_bOvaActive;             // the mode running right now
bool  g_bOvaDefault;            // ova_gamemode, restored on every map
bool  g_bOvaVotedThisMap;
bool  g_bOvaSuspendedForMix;    // OVA stood down for a mix and owes a restore
bool  g_bOvaVoteWantsOva;
int   g_iOvaCurrentT;
int   g_iOvaLastStabber;
float g_fOvaTStart;
float g_faOvaRoundSurvival[MAXPLAYERS + 1];
float g_faOvaBestStint[MAXPLAYERS + 1];     // longest single stint this round
int   g_iaOvaStabsGiven[MAXPLAYERS + 1];    // times this player stabbed the T
int   g_iaOvaStabsTaken[MAXPLAYERS + 1];    // times this player was stabbed as T
float g_faOvaProtectUntil[MAXPLAYERS + 1];  // damage immunity after taking the T role

// Leaderboard categories.
#define OVA_LB_SURVIVAL     0
#define OVA_LB_STABS_GIVEN  1
#define OVA_LB_STABS_TAKEN  2
#define OVA_LB_CATEGORIES   3
Handle g_hOvaRoundTimer = null;
Database g_hOvaDb = null;
bool  g_bOvaDbSQLite = false;

Handle g_haRespawnProtectionTimer[MAXPLAYERS + 1] = {null, ...};

//Roundstart vars
float g_fRoundStartTime;    // Records the time when the round started
bool g_bBombFound;            // Records if the bomb has been found
float g_fCountdownOverTime;    // The time when the countdown should be over
Handle g_hStartCountdown = null;
Handle g_hShowCountdownMessage = null;
int g_iCountdownCount;

//Mapstart vars
int g_iTWinsInARow;    // How many rounds the terrorist won in a row
int g_iConnectedClients;     // How many clients are currently connected
int g_iGlowSprite;
int g_iBeamSprite;
int g_iHaloSprite;

//Pluginstart vars
float g_fGrenadeSpeedMultiplier;
char g_sGameDirName[10];

//Realtime vars
  //frostnades
Handle g_haFreezeTimer[MAXPLAYERS + 1] = {null, ...};
bool g_baFrozen[MAXPLAYERS + 1] = {false, ...};

  //game
bool g_baToggleKnife[MAXPLAYERS + 1] = {true, ...};
bool g_baToggleKnifeLoaded[MAXPLAYERS + 1] = {false, ...}; // saved value arrived from the cookie (or an explicit toggle)
float g_faLastSpawnHandled[MAXPLAYERS + 1]; // debounce for double player_spawn events
int g_iaInitialTeamTrack[MAXPLAYERS + 1] = {0, ...};
bool g_baWelcomeMsgShown[MAXPLAYERS + 1] = {false, ...};
bool g_bTeamSwap;

//Grenade consts
char g_saGrenadeWeaponNames[][] = {
    "weapon_flashbang",
    "weapon_molotov",
    "weapon_smokegrenade",
    "weapon_hegrenade",
    "weapon_decoy",
    "weapon_incgrenade"
};
char g_saGrenadeChatNames[][] = {
    "Flashbang",
    "Molotov",
    "Smoke Grenade",
    "HE Grenade",
    "Decoy Grenade",
    "Incendiary Grenade"
};
int g_iaGrenadeOffsets[sizeof(g_saGrenadeWeaponNames)];

//Add your Preset ConVars here!
char g_saPresetConVars[][] = {
    "sv_airaccelerate",
    "mp_limitteams",
    "mp_freezetime",
    "sv_alltalk",
    "mp_playerid",
    "mp_solid_teammates",
    "mp_halftime",
    "mp_playercashawards",
    "mp_teamcashawards",
    "mp_friendlyfire",
    "ammo_grenade_limit_default",
    "ammo_grenade_limit_flashbang",
    "ammo_grenade_limit_total",
    "sv_staminajumpcost",
    "sv_staminalandcost",
    "mp_spectators_max"
};
int g_iaDefaultValues[] = {
    300,      // sv_airaccelerate  (was 100; every KevAC capture header records
              //                    the live server running 300, and this list
              //                    is enforced after the gamemode cfg now)
    1,        // mp_limitteams
    0,        // mp_freezetime
    1,        // sv_alltalk
    1,        // mp_playerid
    0,        // mp_solid_teammates
    0,        // mp_halftime
    0,        // mp_playercashawards
    0,        // mp_teamcashawards
    0,        // mp_friendlyfire
    9999,     // ammo_grenade_limit_default
    9999,     // ammo_grenade_limit_flashbang
    9999,     // ammo_grenade_limit_total
    0,        // sv_staminajumpcost
    0,        // sv_staminalandcost
    64,       // mp_spectators_max
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("HNS_IsEnabled", Native_HNS_IsEnabled);
    CreateNative("HNS_GetMode", Native_HNS_GetMode);
    CreateNative("HNS_IsOvaActive", Native_HNS_IsOvaActive);
    CreateNative("HNS_GetGameModeColor", Native_HNS_GetGameModeColor);

    MarkNativeAsOptional("kev_isMixActive");
    MarkNativeAsOptional("kev_isFJActive");

    // Library name kept as hidenseek: nothing queries it today, but the rename should not break a future consumer.
    RegPluginLibrary("hnsova");
    RegPluginLibrary("hidenseek");

    return APLRes_Success;
}

public void OnPluginStart()
{
    //Load Translations
    LoadTranslations("hidenseek.phrases");

    //Setup API
    g_hOnCountdownEndForward = CreateGlobalForward("HNS_OnCountdownEnd", ET_Event);

    //ConVars here
    CreateConVar("hnsova_version", PLUGIN_VERSION, "Version of HNSOVA", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
    g_hEnabled = CreateConVar("hns_enabled", HIDENSEEK_ENABLED, "Turns the mod On/Off (0=OFF, 1=ON)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCountdownTime = CreateConVar("hns_countdown_time", COUNTDOWN_TIME, "The countdown duration during which CTs are frozen", _, true, 0.0, true, 15.0);
    g_hCountdownFade = CreateConVar("hns_countdown_fade", COUNTDOWN_FADE, "Fades the screen for CTs during countdown (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hSkipCountdown = CreateConVar("hns_skip_countdown", "0", "Skips HideNSeek's CT countdown freeze for the current round. Controlled by hnsmix during knife rounds.", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
    g_hMaximumWinStreak = CreateConVar("hns_maximum_win_streak", MAXIMUM_WIN_STREAK, "The number of consecutive rounds won by T before the teams get swapped (0=DSBL)", _, true, 0.0);
    g_hFlashbangChance = CreateConVar("hns_flashbang_chance", FLASHBANG_CHANCE, "The chance of getting a Flashbang as a Terrorist", _, true, 0.0, true, 1.0);
    g_hMolotovChance = CreateConVar("hns_molotov_chance", MOLOTOV_CHANCE, "The chance of getting a Molotov as a Terrorist", _, true, 0.0, true, 1.0);
    g_hSmokeGrenadeChance = CreateConVar("hns_smoke_grenade_chance", SMOKE_CHANCE, "The chance of getting a Smoke Grenade as a Terrorist", _, true, 0.0, true, 1.0);
    g_hDecoyChance = CreateConVar("hns_decoy_chance", DECOY_CHANCE, "The chance of getting a Decoy as a Terrorist", _, true, 0.0, true, 1.0);
    g_hHEGrenadeChance = CreateConVar("hns_he_grenade_chance", HE_CHANCE, "The chance of getting a HE Grenade as a Terrorist", _, true, 0.0, true, 1.0);
    g_hFlashbangMaximumAmount = CreateConVar("hns_flashbang_maximum_amount", FLASHBANG_MAXIMUM_AMOUNT, "The maximum number of Flashbang a T can receive", _, true, 0.0, true, 10.0);
    g_hMolotovMaximumAmount = CreateConVar("hns_molotov_maximum_amount", MOLOTOV_MAXIMUM_AMOUNT, "The maximum number of Molotovs a T can receive", _, true, 0.0, true, 10.0);
    g_hSmokeGrenadeMaximumAmount = CreateConVar("hns_smoke_grenade_maximum_amount", SMOKE_MAXIMUM_AMOUNT, "The maximum number of Smoke Grenades a T can receive", _, true, 0.0, true, 10.0);
    g_hDecoyMaximumAmount = CreateConVar("hns_decoy_maximum_amount", DECOY_MAXIMUM_AMOUNT, "The maximum number of Decoy Grenades a T can receive", _, true, 0.0, true, 10.0);
    g_hHEGrenadeMaximumAmount = CreateConVar("hns_he_grenade_maximum_amount", HE_MAXIMUM_AMOUNT, "The maximum number of HE Grenades a T can receive", _, true, 0.0, true, 10.0);
    g_hFlashBlindDisable = CreateConVar("hns_flash_blind_disable", NO_FLASH_BLIND, "Removes the flashbang blind effect for Ts and Spectators (0=NONE, 1=T, 2=T&SPEC)", _, true, 0.0, true, 2.0);
    g_hBlockJoinTeam = CreateConVar("hns_block_jointeam", BLOCK_JOIN_TEAM, "Blocks the players' ability of changing teams", _, true, 0.0, true, 1.0);
    g_hFrostNades = CreateConVar("hns_frostnades", FROSTNADES, "Turns Decoys into FrostNades (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hSelfFreeze = CreateConVar("hns_self_freeze", SELF_FREEZE, "Allows players to freeze themselves (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hFreezeRadius = CreateConVar("hns_freeze_radius", FREEZE_RADIUS, "The radius in which the players can get frozen (units)", _, true, 0.0, true, 500.0);
    g_hAttackWhileFrozen = CreateConVar("hns_attack_while_frozen", ATTACK_WHILE_FROZEN, "Allows frozen players to attack (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hFreezeDuration = CreateConVar("hns_freeze_duration", FREEZE_DURATION, "Freeze duration caused by FrostNades", _, true, 0.0, true, 15.0);
    g_hFreezeFade = CreateConVar("hns_freeze_fade", FREEZE_FADE, "Fades the screen for frozen player (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hFreezeGlow = CreateConVar("hns_freeze_glow", FREEZE_GLOW, "Creates a glowing sprite around frozen players (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hFrostNadesTrail = CreateConVar("hns_frostnades_trail", FROSTNADES_TRAIL, "Leaves a trail on the FrostNades path (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hFrostNadesDetonationRing = CreateConVar("hns_frostnades_detonation_ring", DETONATION_RING, "Adds a detonation effect to FrostNades (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hBlockConsoleKill = CreateConVar("hns_block_console_kill", BLOCK_CONSOLE_KILL, "Blocks the kill command (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hMolotovFriendlyFire = CreateConVar("hns_molotov_friendly_fire", MOLOTOV_FRIENDLY_FIRE, "Allows molotov friendly fire (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hHideRadar = CreateConVar("hns_hide_radar", HIDE_RADAR, "Hide radar (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hHideHudBits = CreateConVar("hns_hide_hud_bits", "0", "Extra m_iHideHUD bits OR'd onto every player on spawn, for HUD elements with no convar of their own (the money panel being the one this exists for). CS:GO has no documented money flag, so set this live with sm_cvar and keep what works: 8 = health/armour cluster, 1 = ammo and weapon selection, 4096 = radar, 4 = the whole HUD. Bits combine. 0 = off.", FCVAR_NOTIFY, true, 0.0, true, 65535.0);
    g_hWelcomeMessage = CreateConVar("hns_welcome_message", WELCOME_MESSAGE, "Displays a welcome message when a player first joins a team (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hDamageSlowdown = CreateConVar("hns_damage_slowdown", DAMAGE_SLOWDOWN, "Toggles the slowdown from getting damage (0=DSBL, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hFastKnife = CreateConVar("hns_fast_knife", FAST_KNIFE, "Can use left-click knife (0=DIBS, 1=ENBL, 2=After X rounds in row for T)", _, true, 0.0, true, 2.0);
    g_hWinsForFastKnife = CreateConVar("hns_wins_for_fast_knife", WINS_FOR_FAST_KNIFE, "Wins in row for allow fast knife if hns_fast_knife 2", _, true, 1.0);
    g_hTKnife = CreateConVar("hns_t_knife", "0", "Ts can knife-damage CTs, slow-stab only (0=DIBS, 1=ENBL) - hnsmix sets this during knife rounds", _, true, 0.0, true, 1.0);
    g_hStabThroughMates = CreateConVar("hns_stab_through_teammates", "0", "Let a knife hit an enemy standing behind a teammate. The engine's knife trace stops on the first solid entity, so a teammate in the way eats a swing that would otherwise have connected. (0=off, 1=on)", _, true, 0.0, true, 1.0);
    g_hOvaGameMode = CreateConVar("ova_gamemode", "1", "Default gamemode on every map: 1 = One Versus All, 0 = regular Hide N Seek. Players can vote the other way for the current map only.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hOvaRoundTime = CreateConVar("ova_round_time", "10.0", "OVA round length in minutes.", FCVAR_NOTIFY, true, 1.0, true, 60.0);
    g_hOvaNoBlock = CreateConVar("ova_noblock", "0", "Remove ALL player collision during OVA, T included. Collision groups are not team-aware, so this cannot be limited to teammates - mp_solid_teammates 0 already handles teammate pass-through and keeps T-versus-CT collision. Leave at 0 unless you want the T uncatchable by body-blocking.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hOvaTProtect = CreateConVar("ova_t_protection", "2.0", "Seconds of damage immunity a player gets on taking the T role, so the CT stood next to them cannot stab it straight back off. 0 disables it.", FCVAR_NOTIFY, true, 0.0, true, 10.0);

    // Discord settings the embed will read, laid out the same way hnsmix names its own.
    g_hOvaDiscordLbWebhook = CreateConVar("ova_discord_lb_webhook", "", "Webhook the OVA leaderboard embed posts to. Empty = disabled. Needs the REST in Pawn extension.", FCVAR_PROTECTED);
    g_hOvaDiscordName = CreateConVar("ova_discord_name", "HNS OVA", "Username the OVA webhook posts as.");
    g_hOvaDiscordPrefix = CreateConVar("ova_discord_prefix", "Kevin", "Community name shown in OVA embed titles, e.g. \"Kevin OVA - Leaderboard\".");
    g_hOvaDiscordLbEntries = CreateConVar("ova_discord_lb_entries", "10", "How many players the OVA leaderboard embed lists.", FCVAR_NOTIFY, true, 1.0, true, 25.0);
    g_hOvaDiscordLbColor = CreateConVar("ova_discord_lb_color", "10181046", "Decimal sidebar color for the OVA leaderboard embed. Default 10181046 is purple; hnsmix uses gold for its own board.", FCVAR_NOTIFY, true, 0.0, true, 16777215.0);
    g_hOvaFlashbangChance = CreateConVar("ova_flashbang_chance", "0.0", "OVA: chance of the T getting a Flashbang.", _, true, 0.0, true, 1.0);
    g_hOvaMolotovChance = CreateConVar("ova_molotov_chance", "0.0", "OVA: chance of the T getting a Molotov.", _, true, 0.0, true, 1.0);
    g_hOvaSmokeChance = CreateConVar("ova_smoke_grenade_chance", "0.0", "OVA: chance of the T getting a Smoke Grenade.", _, true, 0.0, true, 1.0);
    g_hOvaDecoyChance = CreateConVar("ova_decoy_chance", "0.0", "OVA: chance of the T getting a Decoy.", _, true, 0.0, true, 1.0);
    g_hOvaHEChance = CreateConVar("ova_he_grenade_chance", "0.0", "OVA: chance of the T getting a HE Grenade.", _, true, 0.0, true, 1.0);
    g_hOvaFlashbangMax = CreateConVar("ova_flashbang_maximum_amount", "0", "OVA: maximum Flashbangs the T can receive.", _, true, 0.0, true, 10.0);
    g_hOvaMolotovMax = CreateConVar("ova_molotov_maximum_amount", "0", "OVA: maximum Molotovs the T can receive.", _, true, 0.0, true, 10.0);
    g_hOvaSmokeMax = CreateConVar("ova_smoke_grenade_maximum_amount", "0", "OVA: maximum Smoke Grenades the T can receive.", _, true, 0.0, true, 10.0);
    g_hOvaDecoyMax = CreateConVar("ova_decoy_maximum_amount", "0", "OVA: maximum Decoys the T can receive.", _, true, 0.0, true, 10.0);
    g_hOvaHEMax = CreateConVar("ova_he_grenade_maximum_amount", "0", "OVA: maximum HE Grenades the T can receive.", _, true, 0.0, true, 10.0);

    g_hStabThroughRange = CreateConVar("hns_stab_through_range", "48.0", "Reach in units for the pass-through re-trace. 48 is the engine's own knife range - raising this hands out hits the engine would never have given.", _, true, 16.0, true, 96.0);
    g_hGrenadeNoBlock = CreateConVar("hns_grenade_no_block", GRENADE_NO_BLOCK, "Grenades don't collide with players (0=DIBS, 1=ENBL)", _, true, 0.0, true, 1.0);
    g_hAllowWeapons = CreateConVar("hns_allow_weapons", ALLOW_WEAPONS, "Keep admin-given guns as cosmetic items: zero ammo, no shooting, no dropping. When 0, guns are removed on acquisition. Picking guns up from the ground is always blocked.", _, true, 0.0, true, 1.0);
    g_hLoadoutAccess = CreateConVar("hns_loadout_access", "0", "Who may use !hns: 0=admins, 1=both teams, 2=Ts, 3=CTs. !clearhns is always available.", _, true, 0.0, true, 3.0);
    CreateConVar("hns_adminmenu", ADMINMENU, "(0=DIBS, 1=ENBL)", _, true, 0.0, true, 1.0).AddChangeHook(OnCvarChange);
    CreateConVar("hns_score_crash_fix", SCORE_CRASH_FIX, "(0=DIBS, 1=ENBL)", _, true, 0.0, true, 1.0).AddChangeHook(OnCvarChange);
    // Remember to add HOOKS to OnCvarChange and modify OnConfigsExecuted
    AutoExecConfig(true, "hnsova");

    g_hEnabled.AddChangeHook(OnCvarChange);
    g_hCountdownTime.AddChangeHook(OnCvarChange);
    g_hCountdownFade.AddChangeHook(OnCvarChange);
    g_hSkipCountdown.AddChangeHook(OnCvarChange);
    g_hMaximumWinStreak.AddChangeHook(OnCvarChange);
    g_hFlashbangChance.AddChangeHook(OnCvarChange);
    g_hMolotovChance.AddChangeHook(OnCvarChange);
    g_hSmokeGrenadeChance.AddChangeHook(OnCvarChange);
    g_hDecoyChance.AddChangeHook(OnCvarChange);
    g_hHEGrenadeChance.AddChangeHook(OnCvarChange);
    g_hFlashbangMaximumAmount.AddChangeHook(OnCvarChange);
    g_hMolotovMaximumAmount.AddChangeHook(OnCvarChange);
    g_hSmokeGrenadeMaximumAmount.AddChangeHook(OnCvarChange);
    g_hDecoyMaximumAmount.AddChangeHook(OnCvarChange);
    g_hHEGrenadeMaximumAmount.AddChangeHook(OnCvarChange);
    g_hFlashBlindDisable.AddChangeHook(OnCvarChange);
    g_hBlockJoinTeam.AddChangeHook(OnCvarChange);
    g_hFrostNades.AddChangeHook(OnCvarChange);
    g_hSelfFreeze.AddChangeHook(OnCvarChange);
    g_hAttackWhileFrozen.AddChangeHook(OnCvarChange);
    g_hFreezeDuration.AddChangeHook(OnCvarChange);
    g_hFreezeFade.AddChangeHook(OnCvarChange);
    g_hFreezeGlow.AddChangeHook(OnCvarChange);
    g_hFrostNadesTrail.AddChangeHook(OnCvarChange);
    g_hFreezeRadius.AddChangeHook(OnCvarChange);
    g_hFrostNadesDetonationRing.AddChangeHook(OnCvarChange);
    g_hBlockConsoleKill.AddChangeHook(OnCvarChange);
    g_hMolotovFriendlyFire.AddChangeHook(OnCvarChange);
    g_hHideRadar.AddChangeHook(OnCvarChange);
    g_hWelcomeMessage.AddChangeHook(OnCvarChange);
    g_hDamageSlowdown.AddChangeHook(OnCvarChange);
    g_hFastKnife.AddChangeHook(OnCvarChange);
    g_hWinsForFastKnife.AddChangeHook(OnCvarChange);
    g_hTKnife.AddChangeHook(OnCvarChange);
    g_hGrenadeNoBlock.AddChangeHook(OnCvarChange);
    g_hAllowWeapons.AddChangeHook(OnCvarChange);

    g_hToggleKnifeCookie = RegClientCookie("hns_toggleknife", "Store toggleknife status.", CookieAccess_Private);
    g_hCosmeticsCookie = RegClientCookie("hns_cosmetics", "Cosmetic loadout: ct gun, ct pistol, t gun, t pistol.", CookieAccess_Private);

    //Hooked'em
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", OnRoundEnd);
    HookEvent("item_pickup", OnItemPickUp);
    HookEvent("player_death", OnPlayerDeath);
    HookEvent("player_blind", OnPlayerFlash, EventHookMode_Pre);
    HookEvent("weapon_fire", OnWeaponFire, EventHookMode_Pre);
    HookEvent("player_team", OnPlayerTeam);
    HookEvent("player_team", OnPlayerTeam_Pre, EventHookMode_Pre);
    HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);

    AddCommandListener(Command_JoinTeam, "jointeam");

    RegConsoleCmd("sm_voteova", Command_VoteOva, "Vote to switch to One Versus All for this map");
    RegConsoleCmd("sm_votehns", Command_VoteHns, "Vote to switch back to Hide N Seek for this map");
    RegConsoleCmd("sm_ovalb", Command_OvaLeaderboard, "OVA leaderboard");
    RegConsoleCmd("sm_lbova", Command_OvaLeaderboard, "OVA leaderboard (alias)");
    RegConsoleCmd("sm_leaderboardova", Command_OvaLeaderboard, "OVA leaderboard (alias)");
    RegConsoleCmd("sm_ovaleaderboard", Command_OvaLeaderboard, "OVA leaderboard (alias)");
    RegAdminCmd("sm_ovatopdiscord", Command_OvaTopDiscord, ADMFLAG_GENERIC, "Post the OVA leaderboard to Discord");
    RegAdminCmd("sm_ovareset", Command_OvaReset, ADMFLAG_ROOT, "Reset every OVA stat for one player or all players");
    RegAdminCmd("sm_ovaresetstat", Command_OvaResetStat, ADMFLAG_ROOT, "Reset one OVA stat for one player or all players");
    RegConsoleCmd("sm_ova", Command_Ova, "Gamemode menu for admins, command list for everyone else");
    RegConsoleCmd("sm_ovahelp", Command_OvaHelp, "List the OVA commands");
    RegConsoleCmd("sm_helpova", Command_OvaHelp, "List the OVA commands (alias)");
    RegAdminCmd("sm_ovamenu", Command_OvaMenu, ADMFLAG_GENERIC, "Open the gamemode toggle menu");

    OvaDbConnect();

    // A mix can begin at any point, not just on a round boundary, so this is polled rather
    // than driven off round events. NO_MAPCHANGE is deliberately absent: it kills a timer on
    // map change and this one is only created here, so with the flag it died at the first map
    // change, taking the mix suspend/restore and the round-clock self-heal with it.
    CreateTimer(1.0, Timer_OvaMixWatch, _, TIMER_REPEAT);
    AddCommandListener(Command_Kill, "kill");
    AddCommandListener(Command_Kill, "explode");
    AddCommandListener(Command_Spectate, "spectate");

    g_fGrenadeSpeedMultiplier = 250.0 / 245.0;
    g_bEnabled = true;

    RegConsoleCmd("toggleknife", Command_ToggleKnife);
    RegConsoleCmd("sm_hns", Command_HNSLoadout, "Choose the cosmetic gun/pistol you spawn with.");
    RegConsoleCmd("sm_clearhns", Command_ClearHNSLoadout, "Clears your cosmetic gun and pistol selections for both teams.");

    // Don't work in 1.7 and fixed in 1.8
    // FindConVar("mp_backup_round_file").SetString("");
    // FindConVar("mp_backup_round_file_last").SetString("");
    // FindConVar("mp_backup_round_file_pattern").SetString("");
    SetConVarString(FindConVar("mp_backup_round_file"), "");
    SetConVarString(FindConVar("mp_backup_round_file_last"), "");
    SetConVarString(FindConVar("mp_backup_round_file_pattern"), "");
    FindConVar("mp_backup_round_auto").IntValue = 0;

    // Radar hide. Get game folder name and do hook for css if it needed.
    GetGameFolderName(g_sGameDirName, 10);
    if(StrContains(g_sGameDirName, "cstrike") != -1)
        HookEvent("player_blind", OnPlayerFlash_Post);

    TopMenu topmenu = GetAdminTopMenu();
    if (topmenu != null)
        OnAdminMenuCreated(topmenu);
}

public void OnPluginEnd()
{
    delete g_hToggleKnifeCookie;
}

// The engine executes server.cfg and the gamemode cfg AFTER OnMapStart, so anything set
// there won mp_playercashawards back to 1 and the money panel reappeared. Re-applied from
// OnConfigsExecuted, which runs after them. The same was happening to every preset here.
void ApplyPresetConVars()
{
    for(int i = 0; i < sizeof(g_saPresetConVars); i++)
    {
        ConVar cvar = FindConVar(g_saPresetConVars[i]);
        if(cvar != null)
            cvar.IntValue = g_iaDefaultValues[i];
    }
}

public void OnConfigsExecuted()
{
    ApplyPresetConVars();

    // ova_gamemode is re-read here because OnMapStart runs BEFORE hnsova.cfg executes, so the
    // convar still holds the compiled default - which is why the mode sometimes did not come
    // up on a map change. A vote already held this map wins, and a mix suspension is left alone.
    if(!g_bOvaVotedThisMap && !g_bOvaSuspendedForMix)
    {
        g_bOvaDefault = g_hOvaGameMode.BoolValue;
        if(g_bOvaActive != g_bOvaDefault)
        {
            g_bOvaActive = g_bOvaDefault;
            RefreshGrenadeSettings();
        }
        if(g_bOvaActive)
            OvaApplyRoundCvars();
    }

    g_bEnabled = g_hEnabled.BoolValue;
	// Also covers a live plugin reload, where existing clients never get OnClientConnected again.
    g_iConnectedClients = GetClientCount(true);
    GameModeSetup();
    g_fCountdownTime = g_hCountdownTime.FloatValue;
    g_bCountdownFade = g_hCountdownFade.BoolValue;
    g_bSkipCountdown = g_hSkipCountdown.BoolValue;

    g_iMaximumWinStreak = g_hMaximumWinStreak.IntValue;

    g_bHideRadar = g_hHideRadar.BoolValue;
    g_bWelcomeMessage = g_hWelcomeMessage.BoolValue;
    g_bDamageSlowdown = g_hDamageSlowdown.BoolValue;
    g_iFastKnife = g_hFastKnife.IntValue;
    g_iWinsForFastKnife = g_hWinsForFastKnife.IntValue;
    g_bTKnife = g_hTKnife.BoolValue;
    g_bGrenadeNoBlock = g_hGrenadeNoBlock.BoolValue;
    g_bAllowWeapons = g_hAllowWeapons.BoolValue;

    RefreshGrenadeSettings();

    g_iFlashBlindDisable = g_hFlashBlindDisable.IntValue;
    g_bBlockJoinTeam = g_hBlockJoinTeam.BoolValue;
    g_bFrostNades = g_hFrostNades.BoolValue;
    g_bSelfFreeze = g_hSelfFreeze.BoolValue;
    g_fFreezeRadius = g_hFreezeRadius.FloatValue;
    g_bAttackWhileFrozen = g_hAttackWhileFrozen.BoolValue;
    g_fFreezeDuration = g_hFreezeDuration.FloatValue;
    g_bFreezeFade = g_hFreezeFade.BoolValue;
    g_bFreezeGlow = g_hFreezeGlow.BoolValue;
    g_bFrostNadesDetonationRing = g_hFrostNadesDetonationRing.BoolValue;
    g_bFrostNadesTrail = g_hFrostNadesTrail.BoolValue;
    g_bBlockConsoleKill = g_hBlockConsoleKill.BoolValue;
    g_bMolotovFriendlyFire = g_hMolotovFriendlyFire.BoolValue;
}

public void OnCvarChange(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
    char sConVarName[64];
    hConVar.GetName(sConVarName, sizeof(sConVarName));

    if(StrEqual("hns_enabled", sConVarName)) {
        if(g_bEnabled != hConVar.BoolValue) {
            g_bEnabled = hConVar.BoolValue;
            GameModeSetup();
        }
    } else
    if(StrEqual("hns_countdown_time", sConVarName))
        g_fCountdownTime = StringToFloat(sNewValue); else
    if(StrEqual("hns_countdown_fade", sConVarName))
        g_bCountdownFade = hConVar.BoolValue; else
    if(StrEqual("hns_skip_countdown", sConVarName))
        g_bSkipCountdown = hConVar.BoolValue; else
    if(StrEqual("hns_maximum_win_streak", sConVarName))
        g_iMaximumWinStreak = StringToInt(sNewValue); else
    if(StrEqual("hns_flashbang_chance", sConVarName))
        g_faGrenadeChance[NADE_FLASHBANG] = StringToFloat(sNewValue); else
    if(StrEqual("hns_molotov_chance", sConVarName))
        g_faGrenadeChance[NADE_MOLOTOV] = StringToFloat(sNewValue); else
    if(StrEqual("hns_smoke_grenade_chance", sConVarName))
        g_faGrenadeChance[NADE_SMOKE] = StringToFloat(sNewValue); else
    if(StrEqual("hns_decoy_chance", sConVarName))
        g_faGrenadeChance[NADE_DECOY] = StringToFloat(sNewValue); else
    if(StrEqual("hns_he_grenade_chance", sConVarName))
        g_faGrenadeChance[NADE_HE] = StringToFloat(sNewValue); else
    if(StrEqual("hns_flashbang_maximum_amount", sConVarName))
        g_iaGrenadeMaximumAmounts[NADE_FLASHBANG] = StringToInt(sNewValue); else
    if(StrEqual("hns_molotov_maximum_amount", sConVarName))
        g_iaGrenadeMaximumAmounts[NADE_MOLOTOV] = StringToInt(sNewValue); else
    if(StrEqual("hns_smoke_grenade_maximum_amount", sConVarName))
        g_iaGrenadeMaximumAmounts[NADE_SMOKE] = StringToInt(sNewValue); else
    if(StrEqual("hns_decoy_maximum_amount", sConVarName))
        g_iaGrenadeMaximumAmounts[NADE_DECOY] = StringToInt(sNewValue); else
    if(StrEqual("hns_he_grenade_maximum_amount", sConVarName))
        g_iaGrenadeMaximumAmounts[NADE_HE] = StringToInt(sNewValue); else
    if(StrEqual("hns_flash_blind_disable", sConVarName))
        g_iFlashBlindDisable = StringToInt(sNewValue); else
    if(StrEqual("hns_attack_while_frozen", sConVarName))
        g_bAttackWhileFrozen = hConVar.BoolValue; else
    if(StrEqual("hns_frostnades", sConVarName))
        g_bFrostNades = hConVar.BoolValue; else
    if(StrEqual("hns_self_freeze", sConVarName))
        g_bSelfFreeze = hConVar.BoolValue; else
    if(StrEqual("hns_freeze_glow", sConVarName))
        g_bFreezeGlow = hConVar.BoolValue; else
    if(StrEqual("hns_freeze_duration", sConVarName))
        g_fFreezeDuration = StringToFloat(sNewValue); else
    if(StrEqual("hns_freeze_fade", sConVarName))
        g_bFreezeFade = hConVar.BoolValue; else
    if(StrEqual("hns_frostnades_trail", sConVarName))
        g_bFrostNadesTrail = hConVar.BoolValue; else
    if(StrEqual("hns_freeze_radius", sConVarName))
        g_fFreezeRadius = StringToFloat(sNewValue); else
    if(StrEqual("hns_frostnades_detonation_ring", sConVarName))
        g_bFrostNadesDetonationRing = hConVar.BoolValue; else
    if(StrEqual("hns_block_console_kill", sConVarName))
        g_bBlockConsoleKill = hConVar.BoolValue; else
    if(StrEqual("hns_molotov_friendly_fire", sConVarName))
        g_bMolotovFriendlyFire = hConVar.BoolValue; else
    if (StrEqual("hns_hide_radar", sConVarName))
        g_bHideRadar = hConVar.BoolValue; else
    if (StrEqual("hns_welcome_message", sConVarName))
        g_bWelcomeMessage = hConVar.BoolValue; else
    if (StrEqual("hns_damage_slowdown", sConVarName))
        g_bDamageSlowdown = hConVar.BoolValue; else
    if (StrEqual("hns_fast_knife", sConVarName))
        g_iFastKnife = hConVar.IntValue; else
    if (StrEqual("hns_wins_for_fast_knife", sConVarName))
        g_iWinsForFastKnife = hConVar.IntValue; else
    if (StrEqual("hns_t_knife", sConVarName))
        g_bTKnife = hConVar.BoolValue; else
    if (StrEqual("hns_grenade_no_block", sConVarName))
        g_bGrenadeNoBlock = hConVar.BoolValue; else
    if (StrEqual("hns_allow_weapons", sConVarName))
        g_bAllowWeapons = hConVar.BoolValue; else
    if (StrEqual("hns_adminmenu", sConVarName)) {
        g_bAdminMenu = StringToInt(sNewValue) != 0;
        TopMenu topmenu = GetAdminTopMenu();
        if (topmenu != null)
            if (g_bAdminMenu)
                AddHNSCategory(topmenu);
            else
                topmenu.Remove(topmenu.FindCategory("hnsova"));
    } else
    if (StrEqual("hns_score_crash_fix", sConVarName))
        g_bScoreCrashFix = StringToInt(sNewValue) != 0;
}

public void OnMapStart()
{
    // A voted gamemode lasts for that map only.
    g_bOvaDefault = g_hOvaGameMode.BoolValue;
    g_bOvaActive = g_bOvaDefault;
    g_bOvaVotedThisMap = false;
    // A mix spanning a map change must not leave a restore owing on a map that already reset to its defaults.
    g_bOvaSuspendedForMix = false;
    g_iOvaCurrentT = 0;
    g_iOvaLastStabber = 0;
    g_fOvaTStart = 0.0;
    OvaClearRoundTimer();

    //Precaches
    g_iGlowSprite = PrecacheModel("sprites/blueglow1.vmt");
    g_iBeamSprite = PrecacheModel("materials/sprites/physbeam.vmt");
    g_iHaloSprite = PrecacheModel("materials/sprites/halo.vmt");
    PrecacheSound(SOUND_UNFREEZE);
    PrecacheSound(SOUND_FROSTNADE_EXPLODE);

    if (!g_iaGrenadeOffsets[0]) {
        int end = sizeof(g_saGrenadeWeaponNames);
        for (int i=0; i<end; i++) {
            int entindex = CreateEntityByName(g_saGrenadeWeaponNames[i]);
            DispatchSpawn(entindex);
            g_iaGrenadeOffsets[i] = GetEntProp(entindex, Prop_Send, "m_iPrimaryAmmoType");
            AcceptEntityInput(entindex, "Kill");
        }
    }

    g_fCountdownOverTime = 0.0;

    //Set some server ConVars
    ApplyPresetConVars();

    if(g_bEnabled) {
        FindConVar("mp_autoteambalance").IntValue = 1;

        // Applied last: the preset loop resets mp_limitteams and this forces auto-balance back on,
        // both of which would drag players onto T against OVA's one-T rule.
        if(g_bOvaActive)
            OvaApplyRoundCvars();
        else
            FindConVar("mp_ignore_round_win_conditions").IntValue = 0;

        g_iTWinsInARow = 0;
        // Existing clients persist across map changes and emit no new OnClientConnected. Recount rather than reset.
        g_iConnectedClients = GetClientCount(true);

        CreateHostageRescue();    // Make sure T wins when the time runs out
        RemoveBombsites();
    }
}

public void OnMapEnd()
{
    // TIMER_FLAG_NO_MAPCHANGE: SourceMod kills it with the map, leaving the handle dangling.
    // Without this, OnMapStart's OvaClearRoundTimer() threw an invalid-handle error and aborted
    // the callback, so from the second map on no round timer was ever created: the clock hit
    // 0:00, nothing ended the round, no results printed. Null it here, do NOT kill it.
    g_hOvaRoundTimer = null;

    if(g_hStartCountdown != null) {
        KillTimer(g_hStartCountdown);
        g_hStartCountdown = null;
    }
    if(g_hShowCountdownMessage != null) {
        KillTimer(g_hShowCountdownMessage);
        g_hShowCountdownMessage = null;
    }
    g_iCountdownCount = 0;

    for(int iClient = 1; iClient <= MaxClients; iClient++) {
        if(g_haFreezeTimer[iClient] != null) {
            KillTimer(g_haFreezeTimer[iClient]);
            g_haFreezeTimer[iClient] = null;
        }
        if(g_haRespawnProtectionTimer[iClient] != null) {
            KillTimer(g_haRespawnProtectionTimer[iClient]);
            g_haRespawnProtectionTimer[iClient] = null;
        }
        g_baFrozen[iClient] = false;
        g_baRespawnProtection[iClient] = false;
    }
}

public void OnClientCookiesCached(int iClient)
{
    LoadToggleKnifeCookie(iClient);
    LoadCosmeticsCookie(iClient);
}

void LoadToggleKnifeCookie(int iClient)
{
    char sBuffer[2];
    GetClientCookie(iClient, g_hToggleKnifeCookie, sBuffer, sizeof(sBuffer));
    if (strlen(sBuffer) && IsCharNumeric(sBuffer[0])) {
        int iToggleKnife = StringToInt(sBuffer);
        if (iToggleKnife == 0 || iToggleKnife == 1)
            g_baToggleKnife[iClient] = view_as<bool>(iToggleKnife);
    }
    g_baToggleKnifeLoaded[iClient] = true;
}

public void OnRoundStart(Event hEvent, const char[] sName, bool dontBroadcast)
{
    if(!g_bEnabled)
        return;

    g_bBombFound = false;
    RemoveHostages();

    // Deferred one frame on purpose. OvaRoundStart respawns everyone and every spawn reads
    // g_fCountdownOverTime for its freeze duration, but that is not recalculated until further
    // down this function. Inline froze players against the previous round's countdown.
    if(OvaActive())
        CreateTimer(0.0, Timer_OvaRoundSetup, _, TIMER_FLAG_NO_MAPCHANGE);

    // hnsmix knife rounds are a real fight for both teams. Do not rely on hns_countdown_time
    // being changed elsewhere: this guard also stops a cached countdown freezing CTs after the restart.
    if(g_bSkipCountdown) {
        g_fRoundStartTime = GetGameTime();
        g_fCountdownOverTime = g_fRoundStartTime;
        if(g_hStartCountdown != null) {
            KillTimer(g_hStartCountdown);
            g_hStartCountdown = null;
        }
        if(g_hShowCountdownMessage != null) {
            KillTimer(g_hShowCountdownMessage);
            g_hShowCountdownMessage = null;
        }
        g_iCountdownCount = 0;
        Call_HNS_OnCountdownEnd();
        return;
    }

    float fFraction = g_fCountdownTime - RoundToFloor(g_fCountdownTime);
    g_fRoundStartTime = GetGameTime();
    g_fCountdownOverTime = g_fRoundStartTime + g_fCountdownTime + 0.1;

    if(g_fCountdownTime > 0.0 && (g_fCountdownOverTime - GetGameTime() + 0.1) < g_fCountdownTime + 1.0) {
        if(g_hStartCountdown != null) {
            KillTimer(g_hStartCountdown);
            g_hStartCountdown = null;
        }
        g_hStartCountdown = CreateTimer(fFraction, StartCountdown);
    } else
        Call_HNS_OnCountdownEnd();
    return;
}

public Action StartCountdown(Handle hTimer)
{
    g_hStartCountdown = null;
    for(int iClient = 1; iClient <= MaxClients; iClient++) {
        CreateTimer(0.1, FirstCountdownMessage, iClient, TIMER_FLAG_NO_MAPCHANGE);
    }
    if(g_hShowCountdownMessage != null) {
        KillTimer(g_hShowCountdownMessage);
        g_iCountdownCount = 0;
    }
    g_iCountdownCount = 0;
    g_hShowCountdownMessage = CreateTimer(1.0, ShowCountdownMessage, _, TIMER_REPEAT);
    return Plugin_Stop;
}

public Action FirstCountdownMessage(Handle hTimer, any iClient)
{
    int iCountdownTimeFloor = RoundToFloor(g_fCountdownTime);
    if(IsClientInGame(iClient))
        PrintCenterText(iClient, "\n  %t", "Start Countdown", iCountdownTimeFloor, (iCountdownTimeFloor == 1) ? "" : "s");
    return Plugin_Stop;
}

public Action ShowCountdownMessage(Handle hTimer, any iTarget)
{
    int iCountdownTimeFloor = RoundToFloor(g_fCountdownTime);
    g_iCountdownCount++;
    if(g_iCountdownCount < g_fCountdownTime) {
        for(int iClient = 1; iClient <= MaxClients; iClient++) {
            if(IsClientInGame(iClient)) {
                int iTimeDelta = iCountdownTimeFloor - g_iCountdownCount;
                PrintCenterText(iClient, "\n  %t", "Start Countdown", iTimeDelta, (iTimeDelta == 1) ? "" : "s");
            }
        }
        return Plugin_Continue;
    }
    else {
        g_iCountdownCount = 0;
        for(int iClient = 1; iClient <= MaxClients; iClient++) {
            if(IsClientInGame(iClient))
                PrintCenterText(iClient, "\n  %t", "Round Start");
        }
        //EmitSoundToAll(SOUND_GOGOGO);
        g_hShowCountdownMessage = null;
        Call_HNS_OnCountdownEnd();
        return Plugin_Stop;
    }
}

void Call_HNS_OnCountdownEnd()
{
    Call_StartForward(g_hOnCountdownEndForward);
    Call_Finish();
}

public void OnWeaponFire(Event hEvent, const char[] name, bool dontBroadcast)
{
    int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
    if(iClient < 1)
        return;

    int iWeapon = GetEntPropEnt(iClient, Prop_Data, "m_hActiveWeapon");
    if(IsValidEntity(iWeapon)) {
        char sWeaponName[64];
        GetEntityClassname(iWeapon, sWeaponName, sizeof(sWeaponName));
        if(IsWeaponGrenade(sWeaponName)) {
            int i;
            for(i = 0; i < sizeof(g_saGrenadeWeaponNames) && !StrEqual(sWeaponName, g_saGrenadeWeaponNames[i]); i++) {}
            int iCount = GetEntProp(iClient, Prop_Send, "m_iAmmo", _, g_iaGrenadeOffsets[i]) - 1;
            DataPack hPack;
            CreateDataTimer(0.2, SwapToNade, hPack);
            hPack.WriteCell(iClient);
            hPack.WriteCell(iWeapon);
            hPack.WriteCell(iCount);
        }
    }
}

public Action SwapToNade(Handle hTimer, DataPack hPack)
{
    hPack.Reset();
    int iClient = hPack.ReadCell();
    int iWeaponThrown = hPack.ReadCell();
    int iCount = hPack.ReadCell();
    if(!IsClientInGame(iClient))
        return Plugin_Continue;

    int iWeaponTemp = -1;

    if(!iCount) {
        if(IsValidEntity(iWeaponThrown)) {
            RemovePlayerItem(iClient, iWeaponThrown);
            RemoveEdict(iWeaponThrown);
        }
        iWeaponTemp = GetPlayerWeaponSlot(iClient, 3);
    }

    if(iWeaponThrown == iWeaponTemp)
        return Plugin_Continue; //won't even get here but eh, you nevah know

    if(iCount)
        iWeaponTemp = iWeaponThrown;

    if(!IsValidEntity(iWeaponTemp))
        return Plugin_Continue;

    char sWeaponName[64];
    GetEntityClassname(iWeaponTemp, sWeaponName, sizeof(sWeaponName));

    int i;
    for(i = 0; i < sizeof(g_saGrenadeWeaponNames) && !StrEqual(sWeaponName, g_saGrenadeWeaponNames[i]); i++) {}

    iCount = GetEntProp(iClient, Prop_Send, "m_iAmmo", _, g_iaGrenadeOffsets[i]);

    RemovePlayerItem(iClient, iWeaponTemp);
    RemoveEdict(iWeaponTemp);

    iWeaponTemp = GivePlayerItem(iClient, sWeaponName);
    SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeaponTemp);
    SetEntProp(iClient, Prop_Send, "m_iAmmo", iCount, _, g_iaGrenadeOffsets[i]);
    SetEntPropFloat(iWeaponTemp, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 1.1);
    SetEntPropFloat(iWeaponTemp, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.1);

    return Plugin_Continue;
}

public Action Command_ToggleKnife(int iClient, int args)
{
    if(iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient)) {
        g_baToggleKnife[iClient] = !g_baToggleKnife[iClient];
        PrintToChat(iClient, " \x04[HNS] %t", g_baToggleKnife[iClient] ? "Toggle Knife On" : "Toggle Knife Off");

        // Persist immediately: an explicit toggle is authoritative and must survive an early disconnect.
        char sCookie[2];
        IntToString(g_baToggleKnife[iClient], sCookie, sizeof(sCookie));
        SetClientCookie(iClient, g_hToggleKnifeCookie, sCookie);
        g_baToggleKnifeLoaded[iClient] = true;

        int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
        if(!IsValidEntity(iWeapon))
            return Plugin_Handled;
        char sWeaponName[64];
        GetEntityClassname(iWeapon, sWeaponName, sizeof(sWeaponName));
        if(IsWeaponKnife(sWeaponName))
            SetViewmodelVisibility(iClient, g_baToggleKnife[iClient]);
    }
    return Plugin_Handled;
}

void SetViewmodelVisibility(int iClient, bool bVisible)
{
    SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", bVisible);
}

// ------------------- !hns cosmetic loadout -------------------

public Action Command_HNSLoadout(int iClient, int args)
{
    if(iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient)) {
        if(!CanUseHNSLoadout(iClient)) {
            PrintToChat(iClient, " \x04[HNS]\x01 You cannot use \x0B!hns\x01 on your current team.");
            return Plugin_Handled;
        }
        OpenCosmeticTeamMenu(iClient);
    }
    return Plugin_Handled;
}

public Action Command_ClearHNSLoadout(int iClient, int args)
{
    if(iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient)) {
        // Clearing a saved cosmetic must always be available. Gating this behind hns_loadout_access
        // can strand a player with a selection they no longer have permission to edit.
        ClearCosmeticSelections(iClient, COSMETIC_CT, true);
        ClearCosmeticSelections(iClient, COSMETIC_T, true);
        PrintToChat(iClient, " \x04[HNS]\x01 Cleared all of your cosmetic gun and pistol selections.");
    }
    return Plugin_Handled;
}

bool CanUseHNSLoadout(int iClient)
{
    switch(g_hLoadoutAccess.IntValue) {
        case 0: return CheckCommandAccess(iClient, "hns_loadout", ADMFLAG_GENERIC);
        case 1: return true;
        case 2: return GetClientTeam(iClient) == CS_TEAM_T;
        case 3: return GetClientTeam(iClient) == CS_TEAM_CT;
    }
    return false;
}

void OpenCosmeticTeamMenu(int iClient)
{
    Menu menu = new Menu(MenuHandler_CosmeticTeam);
    menu.SetTitle("HNS Loadout | Choose a team:");
    menu.AddItem("ct", "Counter-Terrorists");
    menu.AddItem("t", "Terrorists");
    menu.AddItem("clear_ct", "Clear CT Selections");
    menu.AddItem("clear_t", "Clear T Selections");
    menu.AddItem("clear_all", "Clear ALL Selections");
    menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_CosmeticTeam(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action) {
        case MenuAction_Select: {
            char sInfo[8];
            menu.GetItem(param2, sInfo, sizeof(sInfo));
            if(StrEqual(sInfo, "clear_all")) {
                ClearCosmeticSelections(param1, COSMETIC_CT, true);
                ClearCosmeticSelections(param1, COSMETIC_T, true);
                PrintToChat(param1, " \x04[HNS]\x01 Cleared all of your cosmetic gun and pistol selections.");
            }
            else {
                g_iaCosmeticMenuTeam[param1] = StrEqual(sInfo, "ct") || StrEqual(sInfo, "clear_ct") ? COSMETIC_CT : COSMETIC_T;
                if(StrContains(sInfo, "clear_") == 0)
                    OpenCosmeticClearMenu(param1);
                else
                    OpenCosmeticCategoryMenu(param1);
            }
        }
        case MenuAction_End: {
            delete menu;
        }
    }
    return 0;
}

void OpenCosmeticClearMenu(int iClient)
{
    Menu menu = new Menu(MenuHandler_CosmeticClear);
    menu.SetTitle("Clear %s Selections:", g_iaCosmeticMenuTeam[iClient] == COSMETIC_CT ? "Counter-Terrorist" : "Terrorist");
    menu.AddItem("guns", "Guns");
    menu.AddItem("pistols", "Pistols");
    menu.AddItem("both", "Both");
    menu.ExitBackButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_CosmeticClear(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action) {
        case MenuAction_Select: {
            char sInfo[8];
            menu.GetItem(param2, sInfo, sizeof(sInfo));
            bool bBoth = StrEqual(sInfo, "both");
            ClearCosmeticSelections(param1, g_iaCosmeticMenuTeam[param1], bBoth, StrEqual(sInfo, "pistols"));
            PrintToChat(param1, " \x04[HNS]\x01 Cleared your %s selection%s.",
                g_iaCosmeticMenuTeam[param1] == COSMETIC_CT ? "CT" : "T", bBoth ? "s" : "");
        }
        case MenuAction_Cancel: {
            if(param2 == MenuCancel_ExitBack)
                OpenCosmeticTeamMenu(param1);
        }
        case MenuAction_End: {
            delete menu;
        }
    }
    return 0;
}

void ClearCosmeticSelections(int iClient, int iTeam, bool bBoth, bool bPistols = false)
{
    if(bBoth || !bPistols)
        g_iaCosmeticGun[iClient][iTeam] = 0;
    if(bBoth || bPistols)
        g_iaCosmeticPistol[iClient][iTeam] = 0;
    SaveCosmeticsCookie(iClient);

    // Clearing takes effect immediately: strip the live weapons too when the cleared side is
    // the current team, instead of waiting for the next spawn.
    if(IsPlayerAlive(iClient)
    && iTeam == (GetClientTeam(iClient) == CS_TEAM_CT ? COSMETIC_CT : COSMETIC_T)) {
        bool bStripped = false;
        if((bBoth || !bPistols) && RemoveWeaponBySlot(iClient, 0))
            bStripped = true;
        if((bBoth || bPistols) && RemoveWeaponBySlot(iClient, 1))
            bStripped = true;
        if(bStripped) {
            // The removed weapon may have been in hand - deploy the knife.
            int iKnife = GetPlayerWeaponSlot(iClient, 2);
            if(IsValidEntity(iKnife)) {
                char sKnifeName[64];
                GetEntityClassname(iKnife, sKnifeName, sizeof(sKnifeName));
                FakeClientCommand(iClient, "use %s", sKnifeName);
            }
        }
    }
}

void OpenCosmeticCategoryMenu(int iClient)
{
    Menu menu = new Menu(MenuHandler_CosmeticCategory);
    menu.SetTitle("HNS Loadout | %s:", g_iaCosmeticMenuTeam[iClient] == COSMETIC_CT ? "Counter-Terrorists" : "Terrorists");
    menu.AddItem("guns", "Guns");
    menu.AddItem("pistols", "Pistols");
    menu.ExitBackButton = true; // Back -> team selection
    menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_CosmeticCategory(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action) {
        case MenuAction_Select: {
            char sInfo[8];
            menu.GetItem(param2, sInfo, sizeof(sInfo));
            g_baCosmeticMenuPistols[param1] = StrEqual(sInfo, "pistols");
            OpenCosmeticWeaponMenu(param1);
        }
        case MenuAction_Cancel: {
            if(param2 == MenuCancel_ExitBack)
                OpenCosmeticTeamMenu(param1);
        }
        case MenuAction_End: {
            delete menu;
        }
    }
    return 0;
}

void OpenCosmeticWeaponMenu(int iClient)
{
    int iTeam = g_iaCosmeticMenuTeam[iClient];
    bool bPistols = g_baCosmeticMenuPistols[iClient];
    int iCurrent = bPistols ? g_iaCosmeticPistol[iClient][iTeam] : g_iaCosmeticGun[iClient][iTeam];

    Menu menu = new Menu(MenuHandler_CosmeticWeapon);
    menu.SetTitle("HNS Loadout | %s %s:", iTeam == COSMETIC_CT ? "CT" : "T", bPistols ? "Pistol" : "Gun");

    char sInfo[8]; char sDisplay[64];
    FormatEx(sDisplay, sizeof(sDisplay), "None %s", (iCurrent == 0) ? "[X]" : "");
    menu.AddItem("0", sDisplay);

    int iCount = bPistols ? sizeof(g_saCosmeticPistols) : sizeof(g_saCosmeticGuns);
    for(int i = 0; i < iCount; i++) {
        IntToString(i + 1, sInfo, sizeof(sInfo));
        FormatEx(sDisplay, sizeof(sDisplay), "%s %s", bPistols ? g_saCosmeticPistolNames[i] : g_saCosmeticGunNames[i], (iCurrent == i + 1) ? "[X]" : "");
        menu.AddItem(sInfo, sDisplay);
    }

    menu.ExitBackButton = true; // Back -> guns/pistols selection
    menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_CosmeticWeapon(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action) {
        case MenuAction_Select: {
            char sInfo[8];
            menu.GetItem(param2, sInfo, sizeof(sInfo));
            int iChoice = StringToInt(sInfo);

            int iTeam = g_iaCosmeticMenuTeam[param1];
            bool bPistols = g_baCosmeticMenuPistols[param1];

            if(bPistols)
                g_iaCosmeticPistol[param1][iTeam] = iChoice;
            else
                g_iaCosmeticGun[param1][iTeam] = iChoice;

            SaveCosmeticsCookie(param1);

            char sName[32];
            if(iChoice == 0)
                strcopy(sName, sizeof(sName), "None");
            else
                strcopy(sName, sizeof(sName), bPistols ? g_saCosmeticPistolNames[iChoice - 1] : g_saCosmeticGunNames[iChoice - 1]);

            // Color convention: body white, CT blue, T red, weapons green.
            PrintToChat(param1, " \x04[HNS]\x01 Your %s\x01 %s is now: \x04%s\x01. It applies on your next spawn.",
                iTeam == COSMETIC_CT ? "\x0BCT" : "\x07T", bPistols ? "pistol" : "gun", sName);
            // Menu closes here by design - no reopen.
        }
        case MenuAction_Cancel: {
            if(param2 == MenuCancel_ExitBack)
                OpenCosmeticCategoryMenu(param1);
        }
        case MenuAction_End: {
            delete menu;
        }
    }
    return 0;
}

void SaveCosmeticsCookie(int iClient)
{
    char sBuffer[32];
    FormatEx(sBuffer, sizeof(sBuffer), "%d %d %d %d",
        g_iaCosmeticGun[iClient][COSMETIC_CT], g_iaCosmeticPistol[iClient][COSMETIC_CT],
        g_iaCosmeticGun[iClient][COSMETIC_T], g_iaCosmeticPistol[iClient][COSMETIC_T]);
    SetClientCookie(iClient, g_hCosmeticsCookie, sBuffer);
}

void LoadCosmeticsCookie(int iClient)
{
    char sBuffer[32];
    GetClientCookie(iClient, g_hCosmeticsCookie, sBuffer, sizeof(sBuffer));
    if(sBuffer[0] == '\0')
        return; // never configured - stays at the "None" defaults

    char saParts[4][8];
    if(ExplodeString(sBuffer, " ", saParts, 4, 8) != 4)
        return;

    g_iaCosmeticGun[iClient][COSMETIC_CT] = ClampCosmetic(StringToInt(saParts[0]), sizeof(g_saCosmeticGuns));
    g_iaCosmeticPistol[iClient][COSMETIC_CT] = ClampCosmetic(StringToInt(saParts[1]), sizeof(g_saCosmeticPistols));
    g_iaCosmeticGun[iClient][COSMETIC_T] = ClampCosmetic(StringToInt(saParts[2]), sizeof(g_saCosmeticGuns));
    g_iaCosmeticPistol[iClient][COSMETIC_T] = ClampCosmetic(StringToInt(saParts[3]), sizeof(g_saCosmeticPistols));
}

int ClampCosmetic(int iValue, int iMax)
{
    return (iValue < 0 || iValue > iMax) ? 0 : iValue;
}

public Action Timer_AnnounceCosmetics(Handle hTimer, any iId)
{
    int iClient = GetClientOfUserId(iId);
    if(iClient > 0 && IsClientInGame(iClient))
        AnnounceCosmetics(iClient);
    return Plugin_Stop;
}

void AnnounceCosmetics(int iClient)
{
    if(!g_iaCosmeticGun[iClient][COSMETIC_CT] && !g_iaCosmeticPistol[iClient][COSMETIC_CT]
    && !g_iaCosmeticGun[iClient][COSMETIC_T] && !g_iaCosmeticPistol[iClient][COSMETIC_T]) {
        PrintToChat(iClient, " \x04[HNS]\x01 You have not selected any \x07Guns\x01 or \x07Pistols\x01 from \x0B!hns\x01.");
        return;
    }

    char sCT[64], sT[64];
    BuildLoadoutString(iClient, COSMETIC_CT, sCT, sizeof(sCT));
    BuildLoadoutString(iClient, COSMETIC_T, sT, sizeof(sT));
    PrintToChat(iClient, " \x04[HNS]\x01 Your \x0B!hns\x01 loadout - \x0BCT\x01: \x04%s\x01 | \x07T\x01: \x04%s\x01.", sCT, sT);
}

void BuildLoadoutString(int iClient, int iCfg, char[] sBuffer, int iLength)
{
    int iGun = g_iaCosmeticGun[iClient][iCfg];
    int iPistol = g_iaCosmeticPistol[iClient][iCfg];
    FormatEx(sBuffer, iLength, "%s + %s",
        iGun ? g_saCosmeticGunNames[iGun - 1] : "None",
        iPistol ? g_saCosmeticPistolNames[iPistol - 1] : "None");
}

// Give the chosen cosmetics for the team spawned on. Ammo is stripped by OnWeaponEquipPost on equip.
void GiveCosmeticLoadout(int iClient, int iTeam)
{
    int iCfg = (iTeam == CS_TEAM_CT) ? COSMETIC_CT : COSMETIC_T;

    // Both gun slots were emptied in OnPlayerSpawnDelay; only explicit choices are given back.
    int iGun = g_iaCosmeticGun[iClient][iCfg];
    if(iGun > 0 && iGun <= sizeof(g_saCosmeticGuns))
        GivePlayerItem(iClient, g_saCosmeticGuns[iGun - 1]);

    int iPistol = g_iaCosmeticPistol[iClient][iCfg];
    if(iPistol > 0 && iPistol <= sizeof(g_saCosmeticPistols))
        GivePlayerItem(iClient, g_saCosmeticPistols[iPistol - 1]);

    // The knife is put back in hand by OnPlayerSpawnDelay after this returns.
}
// ----------------- end !hns cosmetic loadout -----------------

public void OnEntityCreated(int iEntity, const char[] sClassName)
{
    if(g_bEnabled) {
        if(g_bFrostNades) {
            if(StrEqual(sClassName, "decoy_projectile")) {
                SDKHook(iEntity, SDKHook_StartTouch, StartTouch_Decoy);
                SDKHook(iEntity, SDKHook_SpawnPost, SpawnPost_Decoy);

                if(g_bFrostNadesTrail)
                    CreateBeamFollow(iEntity, g_iBeamSprite, FROST_COLOR);
            }
        }
        if(g_bGrenadeNoBlock)
            if (StrContains(sClassName, "_projectile") != -1)
                CreateTimer(0.0, GrenadeThrown, EntIndexToEntRef(iEntity));

        // Gun entities (not knives/grenades/c4) still ownerless shortly after spawning are world
        // guns, map-placed or orphaned. Delete them so there is never a gun to pick up.
        // Admin-given guns get an owner instantly and are left alone.
        if(StrContains(sClassName, "weapon_") == 0
        && !IsWeaponKnife(sClassName) && !IsWeaponGrenade(sClassName) && !StrEqual(sClassName, "weapon_c4"))
            CreateTimer(0.2, KillOrphanGun, EntIndexToEntRef(iEntity), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action KillOrphanGun(Handle hTimer, any iRef)
{
    int iEntity = EntRefToEntIndex(iRef);
    if(iEntity != INVALID_ENT_REFERENCE && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == -1)
        AcceptEntityInput(iEntity, "Kill");
    return Plugin_Stop;
}

public Action StartTouch_Decoy(int iEntity)
{
    if(!g_bEnabled || !g_bFrostNades)
        return Plugin_Continue;
    SetEntProp(iEntity, Prop_Data, "m_nNextThinkTick", -1);

    int iRef = EntIndexToEntRef(iEntity);
    CreateTimer(1.0, DecoyDetonate, iRef);
    return Plugin_Continue;
}

public Action SpawnPost_Decoy(int iEntity)
{
    if(!g_bEnabled || !g_bFrostNades)
        return Plugin_Continue;
    SetEntProp(iEntity, Prop_Data, "m_nNextThinkTick", -1);
    SetEntityRenderColor(iEntity, 20, 200, 255, 255);

    int iRef = EntIndexToEntRef(iEntity);
    CreateTimer(1.5, DecoyDetonate, iRef);
    CreateTimer(0.5, Redo_Tick, iRef);
    CreateTimer(1.0, Redo_Tick, iRef);
    CreateTimer(1.5, Redo_Tick, iRef);
    return Plugin_Continue;
}

public Action Redo_Tick(Handle hTimer, any iRef)
{
    int iEntity = EntRefToEntIndex(iRef);
    if(iEntity != INVALID_ENT_REFERENCE)
        SetEntProp(iEntity, Prop_Data, "m_nNextThinkTick", -1);
    return Plugin_Stop;
}

public Action DecoyDetonate(Handle hTimer, any iRef)
{
    int iEntity = EntRefToEntIndex(iRef);
    if(iEntity != INVALID_ENT_REFERENCE) {
        float faDecoyCoord[3];
        GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", faDecoyCoord);
        EmitAmbientSound(SOUND_FROSTNADE_EXPLODE, faDecoyCoord, iEntity, SNDLEVEL_NORMAL);
        int iThrower = GetEntPropEnt(iEntity, Prop_Send, "m_hThrower");
        AcceptEntityInput(iEntity, "Kill");

        // The thrower may have disconnected mid-flight and GetClientTeam on an invalid index throws.
        if(iThrower >= 1 && iThrower <= MaxClients && IsClientInGame(iThrower)) {
            int ThrowerTeam = GetClientTeam(iThrower);

            for(int iClient = 1; iClient <= MaxClients; iClient++) {
                if(IsClientInGame(iClient)) {
                    if(IsPlayerAlive(iClient) && !g_baRespawnProtection[iClient] && ((GetClientTeam(iClient) != ThrowerTeam) ||
                    (g_bSelfFreeze && iClient == iThrower))) {
                        float targetCoord[3];
                        GetClientAbsOrigin(iClient, targetCoord);
                        if (GetVectorDistance(faDecoyCoord, targetCoord) <= g_fFreezeRadius)
                            Freeze(iClient, g_fFreezeDuration, FROSTNADE, iThrower);
                    }
                }
            }
        }
        if(g_bFrostNadesDetonationRing) {
            TE_SetupBeamRingPoint(faDecoyCoord, 10.0, g_fFreezeRadius * 2, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.3, 8.0, 0.0, FROST_COLOR, 10, 0);
            TE_SendToAll();
        }
    }
    return Plugin_Stop;
}

public Action GrenadeThrown(Handle timer, any iEntityRef)
{
    int iEntity = EntRefToEntIndex(iEntityRef);
    if (IsValidEntity(iEntity))
        SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
    return Plugin_Stop;
}

public void OnClientConnected(int iClient)
{
    g_iConnectedClients++;
    g_iaInitialTeamTrack[iClient] = 0;
}

public void OnClientDisconnect(int iClient)
{
    if(OvaActive())
        OvaOnClientDisconnect(iClient);
    if(g_iConnectedClients > 0)
        g_iConnectedClients--;
    SDKUnhook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    SDKUnhook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);
    SDKUnhook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
    SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKUnhook(iClient, SDKHook_TraceAttack, TraceAttack_StabThrough);

    if(g_baFrozen[iClient]) {
        if(g_haFreezeTimer[iClient] != null) {
            KillTimer(g_haFreezeTimer[iClient]);
            g_haFreezeTimer[iClient] = null;
        }
        g_baFrozen[iClient] = false;
    }
    // Only write back a value that came from the cookie or an explicit toggle, or a player
    // leaving before cookies loaded gets their saved choice wiped by the default.
    if(g_baToggleKnifeLoaded[iClient]) {
        char sBuffer[2];
        IntToString(g_baToggleKnife[iClient], sBuffer, sizeof(sBuffer));
        SetClientCookie(iClient, g_hToggleKnifeCookie, sBuffer);
    }
    g_baToggleKnife[iClient] = true;
    g_baToggleKnifeLoaded[iClient] = false;

    // Spawn Protection
    if(g_haRespawnProtectionTimer[iClient] != null) {
        KillTimer(g_haRespawnProtectionTimer[iClient]);
        g_haRespawnProtectionTimer[iClient] = null;
    }
    g_baRespawnProtection[iClient] = false;
}

public Action OnWeaponCanUse(int iClient, int iWeapon)
{
    if(!g_bEnabled)
        return Plugin_Continue;
    char sWeaponName[64];
    GetEntityClassname(iWeapon, sWeaponName, sizeof(sWeaponName));

    // Knife rounds are knife-only fights. hnsmix sets hns_t_knife, so block both team pickups
    // even if a late plugin spawns a grenade after the spawn loadout is stripped.
    if(IsWeaponGrenade(sWeaponName))
        return (!IsKnifeRoundCombatEnabled() && GetClientTeam(iClient) == CS_TEAM_T) ? Plugin_Continue : Plugin_Handled;

    // Guns must pass: GivePlayerItem equips through this hook, so blocking here bounces
    // admin-given weapons onto the floor. No guns from the ground is instead enforced by there
    // never BEING one: drops are blocked and ownerless gun entities are deleted after spawn.
    return Plugin_Continue;
}

public void OnPlayerSpawn(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    if(!g_bEnabled)
        return;
    int iId =  hEvent.GetInt("userid");
    int iClient = GetClientOfUserId(iId);
    if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient))
        return;

    int iTeam = GetClientTeam(iClient);

    if(OvaActive()) {
        // Nobody is protected in OVA, and an empty T slot is filled by whoever turns up.
        if(g_haRespawnProtectionTimer[iClient] != null) {
            KillTimer(g_haRespawnProtectionTimer[iClient]);
            g_haRespawnProtectionTimer[iClient] = null;
        }
        g_baRespawnProtection[iClient] = false;
        OvaApplyNoBlock(iClient, true);

        // Safety net: anyone spawning without an active immunity window must be damageable. One
        // stuck flag makes a player unkillable for the rest of the map, invisibly.
        if(g_faOvaProtectUntil[iClient] <= GetGameTime())
            SetEntProp(iClient, Prop_Data, "m_takedamage", 2, 1);

        OvaOnClientJoinedTeam(iClient);
        OvaEnforceSingleT();
    }

    if(IsKnifeRoundCombatEnabled()) {
        // hnsmix knife rounds have no countdown or spawn protection; clear a timer made before a restart.
        if(g_haRespawnProtectionTimer[iClient] != null) {
            KillTimer(g_haRespawnProtectionTimer[iClient]);
            g_haRespawnProtectionTimer[iClient] = null;
        }
        g_baRespawnProtection[iClient] = false;
    }
    else if(iTeam == CS_TEAM_CT) {
        // Spawn Protection
        g_baRespawnProtection[iClient] = true;
    }

    // Round transitions can fire player_spawn twice for the same player (a mix respawn then the
    // round restart). Process only the first, or grenades get rolled and announced twice.
    float fNow = GetGameTime();
    if(fNow - g_faLastSpawnHandled[iClient] < 0.5)
        return;
    g_faLastSpawnHandled[iClient] = fNow;

    CreateTimer(0.1, OnPlayerSpawnDelay, iId, TIMER_FLAG_NO_MAPCHANGE);

    CreateTimer(0.0, RemoveRadar, iId, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.0, ApplyHideHudBits, iId, TIMER_FLAG_NO_MAPCHANGE);

    return;
}

public Action OnPlayerSpawnDelay(Handle hTimer, any iId)
{
    int iClient = GetClientOfUserId(iId);
    if(iClient == 0 || iClient > MaxClients)
        return Plugin_Continue;

    if(IsClientInGame(iClient) && IsPlayerAlive(iClient)) {
        float fDefreezeTime = g_fCountdownOverTime - GetGameTime() + 0.1;

        SetEntProp(iClient, Prop_Send, "m_iAccount", 0);    //Set spawn money to 0$
        RemoveNades(iClient);

        int iEntity = GetPlayerWeaponSlot(iClient, 2);
        if(IsValidEdict(iEntity)) {
            char sWeaponName[64];
            GetEntityClassname(iEntity, sWeaponName, sizeof(sWeaponName));
            RemovePlayerItem(iClient, iEntity);
            AcceptEntityInput(iEntity, "Kill");
            GivePlayerItem(iClient, sWeaponName);
        }
        else
            GivePlayerItem(iClient, "weapon_knife");        //prevents a visual bug

        SetViewmodelVisibility(iClient, g_baToggleKnife[iClient]);  //might fix a game bug

        // Game-issued loadout guns (CT P2000 / T Glock) are never kept: None means no gun at all,
        // and chosen !hns cosmetics are re-given below.
        for(int i = 0; i < 2; i++)
            RemoveWeaponBySlot(iClient, i);

        if(g_baFrozen[iClient])
            SilentUnfreeze(iClient);
        int iTeam = GetClientTeam(iClient);

        // Chosen cosmetics replace the default loadout guns. Needs hns_allow_weapons 1.
        if(g_bAllowWeapons && (iTeam == CS_TEAM_T || iTeam == CS_TEAM_CT))
            GiveCosmeticLoadout(iClient, iTeam);

        // The game pistol was active and was just removed (and giving a cosmetic auto-switches to
        // it), so force the knife out or players spawn empty-handed. Must be a real use switch:
        // writing m_hActiveWeapon directly skips the deploy and leaves an invisible viewmodel.
        int iKnife = GetPlayerWeaponSlot(iClient, 2);
        if(IsValidEntity(iKnife)) {
            char sKnifeName[64];
            GetEntityClassname(iKnife, sKnifeName, sizeof(sKnifeName));
            FakeClientCommand(iClient, "use %s", sKnifeName);
        }

        RepairSpawnView(iClient);

        // Once per connection: tell the player their saved !hns loadout a few seconds after spawn,
        // so the message does not drown in round-start spam.
        if(!g_baCosmeticsAnnounced[iClient] && AreClientCookiesCached(iClient)) {
            g_baCosmeticsAnnounced[iClient] = true;
            CreateTimer(5.0, Timer_AnnounceCosmetics, iId, TIMER_FLAG_NO_MAPCHANGE);
        }

        if(iTeam == CS_TEAM_T) {
            GiveGrenades(iClient);
        }
        else if(iTeam == CS_TEAM_CT) {
            // hns_skip_countdown is the authoritative hand-off from hnsmix. Re-checked at spawn because
            // a restart can cross the two plugins' callbacks in either order.
            if(!IsKnifeRoundCombatEnabled() && g_fCountdownTime > 0.0 && fDefreezeTime > 0.0 && (fDefreezeTime < g_fCountdownTime + 1.0)) {
                if(g_iConnectedClients > 1) {
                    Freeze(iClient, fDefreezeTime, COUNTDOWN);
                    // Respawn Protection
                    if(g_haRespawnProtectionTimer[iClient] != null) {
                        KillTimer(g_haRespawnProtectionTimer[iClient]);
                        g_haRespawnProtectionTimer[iClient] = null;
                    }
                    g_haRespawnProtectionTimer[iClient] = CreateTimer(fDefreezeTime+RESPAWN_PROTECTION_TIME_ADDON, RemoveRespawnProtection, iClient);
                } else {
                    // Respawn Protection
                    if(g_haRespawnProtectionTimer[iClient] != null) {
                        KillTimer(g_haRespawnProtectionTimer[iClient]);
                        g_haRespawnProtectionTimer[iClient] = null;
                    }
                    g_haRespawnProtectionTimer[iClient] = CreateTimer(RESPAWN_PROTECTION_TIME_ADDON, RemoveRespawnProtection, iClient);
                }
            }
            else if(!IsKnifeRoundCombatEnabled() && GetEntityMoveType(iClient) == MOVETYPE_NONE) {
                SetEntityMoveType(iClient, MOVETYPE_WALK);
                // Respawn Protection
                if(g_haRespawnProtectionTimer[iClient] != null) {
                    KillTimer(g_haRespawnProtectionTimer[iClient]);
                    g_haRespawnProtectionTimer[iClient] = null;
                }
                g_haRespawnProtectionTimer[iClient] = CreateTimer(RESPAWN_PROTECTION_TIME_ADDON, RemoveRespawnProtection, iClient);
            }
        }
    }
    return Plugin_Continue;
}

// A forced respawn can leave the view attached to a stale entity, so this runs after the
// spawn settles. Do not write observer or view-offset SendProps here: those are engine-owned
// while spawning and can destabilise forced respawns.
void RepairSpawnView(int iClient)
{
    if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
        return;

    SetClientViewEntity(iClient, iClient);
}

void GameModeSetup() {
    FindConVar("mp_randomspawn").BoolValue = false;
    // Guns are cosmetic-only: they never drop, on death or manually, and cannot be picked up.
    FindConVar("mp_death_drop_gun").IntValue = 0;
    FindConVar("mp_death_drop_grenade").IntValue = 1;
    // OVA runs on its own clock; a single stabbed T must not end the round.
    FindConVar("mp_ignore_round_win_conditions").IntValue = g_bOvaActive ? 1 : 0;

    // Nobody spawns with a gun. The loadout is suppressed at the source rather than stripped a
    // tick later, which left a pistol icon overhead, the draw sound, and a brief window holding
    // a real gun. Chosen cosmetics come from GiveCosmeticLoadout; the strip stays as a net.
    FindConVar("mp_ct_default_primary").SetString("");
    FindConVar("mp_t_default_primary").SetString("");
    FindConVar("mp_ct_default_secondary").SetString("");
    FindConVar("mp_t_default_secondary").SetString("");
}

public void OnClientPutInServer(int iClient)
{
    SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    SDKHook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);
    SDKHook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
    SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(iClient, SDKHook_TraceAttack, TraceAttack_StabThrough);

    g_baWelcomeMsgShown[iClient] = false;
    OvaResetClient(iClient);

    // Fresh slot: default on, then the saved choice overrides. Cookies may cache before or after this forward.
    g_baToggleKnife[iClient] = true;
    g_baToggleKnifeLoaded[iClient] = false;
    g_faLastSpawnHandled[iClient] = 0.0; // GetGameTime() restarts each map - never carry a stale stamp

    // Cosmetic loadout defaults to None/None for both teams.
    g_iaCosmeticGun[iClient][COSMETIC_CT] = 0;
    g_iaCosmeticGun[iClient][COSMETIC_T] = 0;
    g_iaCosmeticPistol[iClient][COSMETIC_CT] = 0;
    g_iaCosmeticPistol[iClient][COSMETIC_T] = 0;
    g_baCosmeticsAnnounced[iClient] = false;

    if (AreClientCookiesCached(iClient)) {
        LoadToggleKnifeCookie(iClient);
        LoadCosmeticsCookie(iClient);
    }
}

public Action HandlePlayerSpectateRequest(int iClient) {
    int iTeam = GetClientTeam(iClient);
    if(iTeam == CS_TEAM_CT || iTeam == CS_TEAM_T) {
        if(IsPlayerAlive(iClient)) {
            PrintToConsole(iClient, "[HNS] %t", "Spectate Deny Alive");
            return Plugin_Stop;
        }
        else {
            g_iaInitialTeamTrack[iClient] = iTeam;
            SilentUnfreeze(iClient);
            return Plugin_Continue;
        }
    }
    return Plugin_Continue;
}

public Action Command_Spectate(int iClient, const char[] sCommand, int iArgCount)
{
    if(!g_bEnabled)
        return Plugin_Continue;
    if(!g_bBlockJoinTeam || iClient == 0 || iClient > MaxClients)
        return Plugin_Continue;

    return HandlePlayerSpectateRequest(iClient);
}

public Action Command_JoinTeam(int iClient, const char[] sCommand, int iArgCount)
{
    if(!g_bEnabled)
        return Plugin_Continue;

    int iTeam = GetClientTeam(iClient);
    char sChosenTeam[2];
    GetCmdArg(1, sChosenTeam, sizeof(sChosenTeam));
    int iChosenTeam = StringToInt(sChosenTeam);

    // OVA has exactly one T and it is never chosen. Anyone asking for T while the slot is filled goes CT.
    if(OvaActive() && iClient > 0 && iClient <= MaxClients
        && (iChosenTeam == JOINTEAM_T || iChosenTeam == JOINTEAM_RND)) {
        if(g_iOvaCurrentT > 0 && g_iOvaCurrentT != iClient) {
            FakeClientCommand(iClient, "jointeam %d", JOINTEAM_CT);
            PrintToChat(iClient, " \x04[OVA]\x01 There is already a \x02T\x01. Stab them to take the role.");
            return Plugin_Stop;
        }
    }

    // OVA has no team balance worth protecting: everyone except the single T belongs on CT. A
    // spectator asking for CT is always let in, whatever the headcount, or the balance checks
    // below would refuse them or force them onto T.
    if(OvaActive() && iClient > 0 && iClient <= MaxClients
        && iTeam == CS_TEAM_SPECTATOR && iChosenTeam == JOINTEAM_CT) {
        g_iaInitialTeamTrack[iClient] = CS_TEAM_CT;
        return Plugin_Continue;
    }

    if(!g_bBlockJoinTeam || iClient == 0 || iClient > MaxClients)
        return Plugin_Continue;

    int iLimitTeams = FindConVar("mp_limitteams").IntValue;
    int iDelta = GetTeamPlayerCount(CS_TEAM_T) - GetTeamPlayerCount(CS_TEAM_CT);
    if(iTeam == CS_TEAM_T || iTeam == CS_TEAM_CT) {
        if(iChosenTeam == JOINTEAM_T || iChosenTeam == JOINTEAM_CT || iChosenTeam == JOINTEAM_RND) {
            if(IsPlayerAlive(iClient)) {
                PrintToChat(iClient, " \x04[HNS] %t", "Team Change Deny Alive");
                return Plugin_Stop;
            }
            else if(iDelta > iLimitTeams || -iDelta > iLimitTeams) {
                g_iaInitialTeamTrack[iClient] = iChosenTeam;
                return Plugin_Continue;
            }
            else {
                PrintToChat(iClient, " \x04[HNS] %t", "Team Change Deny Balanced");
                return Plugin_Stop;
            }
        }
        else if(iChosenTeam == JOINTEAM_SPEC) {
            return HandlePlayerSpectateRequest(iClient);
        }
        else {
            PrintToConsole(iClient, "[HNS] %T", "Invalid Team Console", iClient);
            return Plugin_Stop;
        }
    }
    else if(iTeam == CS_TEAM_SPECTATOR) {
        if(iDelta > iLimitTeams || -iDelta > iLimitTeams) {
            if(iChosenTeam == JOINTEAM_T || iChosenTeam == JOINTEAM_CT || iChosenTeam == JOINTEAM_RND) {
                g_iaInitialTeamTrack[iClient] = iChosenTeam;
            }
            return Plugin_Continue;
        }
        else if(g_iaInitialTeamTrack[iClient]) {
            PrintToChat(iClient, " \x04[HNS] %t", (g_iaInitialTeamTrack[iClient] == CS_TEAM_T) ? "Assigned To Team T" : "Assigned To Team CT");
            CS_SwitchTeam(iClient, g_iaInitialTeamTrack[iClient]);
            return Plugin_Stop;
        }
        if(iChosenTeam == JOINTEAM_T || iChosenTeam == JOINTEAM_CT || iChosenTeam == JOINTEAM_RND)
            return Plugin_Continue;
    }
    SilentUnfreeze(iClient);
    return Plugin_Continue;
}

public Action Command_Kill(int iClient, const char[] sCommand, int iArgCount)
{
    if(!g_bEnabled)
        return Plugin_Continue;
    if (!g_bBlockConsoleKill || iClient == 0 || iClient > MaxClients)
        return Plugin_Continue;
    PrintToConsole(iClient, "[HNS] %T", "Kill Deny", iClient);
    return Plugin_Stop;
}

public void OnItemPickUp(Event hEvent, const char[] szName, bool bDontBroadcast)
{
    if(!g_bEnabled)
        return;
    char sItem[64];
    int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
    hEvent.GetString("item", sItem, sizeof(sItem));
    if(!g_bBombFound)
        if(StrEqual(sItem, "weapon_c4", false)) {
            RemovePlayerItem(iClient, GetPlayerWeaponSlot(iClient, 4));    //Remove the bomb
            g_bBombFound = true;
            return;
        }

    // Guns reaching an inventory (/give, spawn loadout; ground pickup is blocked in
    // OnWeaponCanUse): hns_allow_weapons 1 keeps them as cosmetics with no ammo, 0 removes them.
    for(int i = 0; i < 2; i++) {
        if(g_bAllowWeapons)
            NeuterWeaponBySlot(iClient, i);
        else
            RemoveWeaponBySlot(iClient, i);
    }
    return;
}

// Strip every bullet - chamber, clip and reserve - so a gun can be waved but never fired or reloaded.
void NeuterGun(int iWeapon)
{
    SetEntProp(iWeapon, Prop_Send, "m_iClip1", 0);
    SetEntProp(iWeapon, Prop_Send, "m_iClip2", 0);
    if(HasEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount"))
        SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
    if(HasEntProp(iWeapon, Prop_Send, "m_iSecondaryReserveAmmoCount"))
        SetEntProp(iWeapon, Prop_Send, "m_iSecondaryReserveAmmoCount", 0);
}

void NeuterWeaponBySlot(int iClient, int iSlot)
{
    int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
    if(IsValidEdict(iWeapon))
        NeuterGun(iWeapon);
}

// Runs for every weapon received by any path. The game may still be filling the clip during
// the equip - notably the spawn pistol, which refills AFTER item_pickup - so the strip is
// deferred one frame to always run last.
public void OnWeaponEquipPost(int iClient, int iWeapon)
{
    if(!g_bEnabled || !g_bAllowWeapons || !IsValidEntity(iWeapon))
        return;

    char sWeaponName[64];
    GetEntityClassname(iWeapon, sWeaponName, sizeof(sWeaponName));
    if(IsWeaponKnife(sWeaponName) || IsWeaponGrenade(sWeaponName) || StrEqual(sWeaponName, "weapon_c4"))
        return;

    CreateTimer(0.0, Timer_NeuterGun, EntIndexToEntRef(iWeapon), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_NeuterGun(Handle hTimer, any iRef)
{
    int iWeapon = EntRefToEntIndex(iRef);
    if(iWeapon != INVALID_ENT_REFERENCE)
        NeuterGun(iWeapon);
    return Plugin_Stop;
}

// Players can never drop weapons; death drops are disabled via mp_death_drop_gun in GameModeSetup.
public Action CS_OnCSWeaponDrop(int iClient, int iWeapon)
{
    if(!g_bEnabled)
        return Plugin_Continue;

    char sWeaponName[64];
    GetEntityClassname(iWeapon, sWeaponName, sizeof(sWeaponName));

    // Grenade "drops" are part of throwing them; knives can't drop anyway.
    if(IsWeaponKnife(sWeaponName) || IsWeaponGrenade(sWeaponName) || StrEqual(sWeaponName, "weapon_c4"))
        return Plugin_Continue;

    return Plugin_Handled;
}

public void OnWeaponSwitchPost(int iClient, int iWeapon)
{
    if(g_bEnabled) {
        char sWeaponName[64];
        GetEntityClassname(iWeapon, sWeaponName, sizeof(sWeaponName));
        if(IsWeaponGrenade(sWeaponName)) {
            SetClientSpeed(iClient, g_fGrenadeSpeedMultiplier);
            SetViewmodelVisibility(iClient, true);
        }
        else {
            SetClientSpeed(iClient, 1.0);
            if(IsWeaponKnife(sWeaponName))
                SetViewmodelVisibility(iClient, g_baToggleKnife[iClient]);
        }

        // Only CTs (the frozen seekers) get weapons locked during the countdown. Ts stay free to knife and boost.
        float fCurrentTime = GetGameTime();
        if(!IsKnifeRoundCombatEnabled() && fCurrentTime < g_fCountdownOverTime && GetClientTeam(iClient) == CS_TEAM_CT) {
            SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", g_fCountdownOverTime);
            SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", g_fCountdownOverTime);
        }
    }
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &iDamage, int &iDamageType)
{
    if(!g_bEnabled)
        return Plugin_Continue;
    if(iVictim == 0)
        return Plugin_Continue;

    // Funjump is a practice mode: no player damages another, either direction. Sits above
    // KevFJ's godmode toggle deliberately, so turning your own godmode off still cannot be stabbed.
    if(FJRunning() && iAttacker > 0 && iAttacker <= MaxClients && iAttacker != iVictim)
        return Plugin_Handled;

    {
        if(!g_bMolotovFriendlyFire)
            if(iDamageType & DMG_BURN) {
                if(!iAttacker || iAttacker > MaxClients)
                    return Plugin_Handled;
                if(!IsClientInGame(iAttacker))
                    if(GetClientTeam(iVictim) == g_iaInitialTeamTrack[iAttacker])
                        return Plugin_Handled;
                if(GetClientTeam(iVictim) == GetClientTeam(iAttacker))
                    return Plugin_Handled;
            }
        // Ts may swing but deal no damage to CTs. With hns_t_knife on (mix knife rounds) it is a flat 50.
        if(iAttacker > 0 && iAttacker <= MaxClients && IsClientInGame(iAttacker)) {
            if(GetClientTeam(iAttacker) == CS_TEAM_T && GetClientTeam(iVictim) == CS_TEAM_CT) {
                int iActiveWeapon = GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon");
                if(IsValidEntity(iActiveWeapon)) {
                    char sWeaponName[64];
                    GetEntityClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
                    if(IsWeaponKnife(sWeaponName)) {
                        if(!IsKnifeRoundCombatEnabled())
                            return Plugin_Handled;
                        // Kevlar absorbs 15% of knife damage, so compensate for exactly 50 landing (59 * 0.85).
                        iDamage = (GetClientArmor(iVictim) > 0) ? 59.0 : 50.0;
                        return Plugin_Changed;
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

/* int EnemyTeam(int iTeam)
{
    if(iTeam == CS_TEAM_CT)
        return CS_TEAM_T;
    else if(iTeam == CS_TEAM_T)
        return CS_TEAM_CT;

    return -1;
} */

public void OnPlayerDeath(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    if(!g_bEnabled)
        return;
    int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
    int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));

    if(iVictim > 0 && iVictim <= MaxClients) {
        if(GetClientTeam(iVictim) == CS_TEAM_T) {
            if(iAttacker > 0 && iAttacker <= MaxClients && GetClientTeam(iAttacker) == CS_TEAM_CT)
                SetEntProp(iAttacker, Prop_Send, "m_iAccount", 0);    //Make sure the player doesn't get the money
        }

        if(g_baFrozen[iVictim])
            SilentUnfreeze(iVictim);

        if(OvaActive())
            OvaOnPlayerDeath(iVictim, iAttacker);
    }
    return;
}

public Action OnPlayerFlash(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    if(!g_bEnabled)
        return Plugin_Continue;
    int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
    if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient))
        return Plugin_Continue;
    int iTeam = GetClientTeam(iClient);

    if(g_iFlashBlindDisable) {
        if(iTeam == CS_TEAM_T)
            SetEntPropFloat(iClient, Prop_Send, "m_flFlashMaxAlpha", 0.5);
        else
            if(g_iFlashBlindDisable == 2 && iTeam == CS_TEAM_SPECTATOR)
                SetEntPropFloat(iClient, Prop_Send, "m_flFlashMaxAlpha", 0.5);
    }

    if(g_baRespawnProtection[iClient])
        SetEntPropFloat(iClient, Prop_Send, "m_flFlashMaxAlpha", 0.5);

    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float faVelocity[3], float faAngles[3], int &iWeapon)
{
    if(!g_bEnabled)
        return Plugin_Continue;

    if(!g_bAttackWhileFrozen && g_baFrozen[iClient]) {
        iButtons &= ~(IN_ATTACK | IN_ATTACK2);
        return Plugin_Changed;
    }

    float fCurrentTime = GetGameTime();
    int iTeam = GetClientTeam(iClient);

    // Cosmetic guns can never fire, so keep attack timers pushed ahead and the client will not
    // try - killing the empty-clip click. A one-time push would not survive re-deploys.
    if(g_bAllowWeapons) {
        int iGun = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
        if(IsValidEntity(iGun)) {
            char sGunName[64];
            GetEntityClassname(iGun, sGunName, sizeof(sGunName));
            if(!IsWeaponKnife(sGunName) && !IsWeaponGrenade(sGunName) && !StrEqual(sGunName, "weapon_c4")) {
                // Re-push only as the window shrinks - not every tick.
                if(GetEntPropFloat(iGun, Prop_Send, "m_flNextPrimaryAttack") < fCurrentTime + 1.0) {
                    SetEntPropFloat(iGun, Prop_Send, "m_flNextPrimaryAttack", fCurrentTime + 5.0);
                    SetEntPropFloat(iGun, Prop_Send, "m_flNextSecondaryAttack", fCurrentTime + 5.0);
                }
                if(iButtons & (IN_ATTACK | IN_ATTACK2)) {
                    iButtons &= ~(IN_ATTACK | IN_ATTACK2);
                    return Plugin_Changed;
                }
                return Plugin_Continue;
            }
        }
    }

    if(iTeam == CS_TEAM_T) {
        // hns_t_knife: Ts stab like CTs, so left click is the cooldown-limited stab, never a fast knife.
        if(IsKnifeRoundCombatEnabled()) {
            int iTKnife = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
            if(IsValidEntity(iTKnife)) {
                char sTKnifeName[64];
                GetEntityClassname(iTKnife, sTKnifeName, sizeof(sTKnifeName));
                if(IsWeaponKnife(sTKnifeName)) {
                    SyncStabCooldown(iTKnife);
                    if (iButtons & IN_ATTACK) {
                        iButtons &= ~(IN_ATTACK);
                        iButtons |= IN_ATTACK2;
                        return Plugin_Changed;
                    }
                }
            }
        }
        if (iButtons & (IN_ATTACK | IN_ATTACK2)) {
            int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
            if(IsValidEntity(iActiveWeapon)) {
                char sWeaponName[64];
                GetEntityClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
                if(IsWeaponGrenade(sWeaponName) && fCurrentTime < g_fCountdownOverTime) {
                    SetEntPropFloat(iActiveWeapon, Prop_Send, "m_flNextPrimaryAttack", g_fCountdownOverTime);
                    SetEntPropFloat(iActiveWeapon, Prop_Send, "m_flNextSecondaryAttack", g_fCountdownOverTime);
                    iButtons &= ~(IN_ATTACK | IN_ATTACK2);    //Block attacks for Ts
                    return Plugin_Changed;
                }
            }
            else
                return Plugin_Continue;
        }
    }
    else if(iTeam == CS_TEAM_CT) {
        int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
        if(IsValidEntity(iActiveWeapon)) {
            char sWeaponName[64];
            GetEntityClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
            if(IsWeaponKnife(sWeaponName))
                // OVA follows hns_fast_knife like HNS. Funjump always allows it: knives deal no damage there.
                if (!FJRunning() && (g_iFastKnife == 0 || (g_iFastKnife == 2 && g_iTWinsInARow < g_iWinsForFastKnife))) {
                    SyncStabCooldown(iActiveWeapon);
                    if (iButtons & IN_ATTACK) {
                        iButtons &= ~(IN_ATTACK);    //Block attack1 for CTs but use attack2 instead
                        iButtons |= IN_ATTACK2;
                        return Plugin_Changed;
                    }
                }
        }
    }

    return Plugin_Continue;
}

stock int GetTeamScoreS(int team)
{
    return g_bScoreCrashFix ? GetTeamScore(team) : CS_GetTeamScore(team);
}

#define CS_GetTeamScore(%1) GetTeamScoreS(%1)
public void OnRoundEnd(Event hEvent, const char[] name, bool dontBroadcast)
{
    if(!g_bEnabled)
        return;

    // OVA has no winning team and must never hit SwapTeams or the win streak. A round ending
    // here that the OVA timer did not start still needs the current stint banked.
    if(OvaActive()) {
        OvaClearRoundTimer();
        OvaCreditStint();
        return;
    }

    int iWinningTeam = hEvent.GetInt("winner");
    int iCTScore = CS_GetTeamScore(CS_TEAM_CT);

    if(iWinningTeam == CS_TEAM_T) {
        g_iTWinsInARow++;
        if(!g_iMaximumWinStreak || g_iTWinsInARow < g_iMaximumWinStreak)
            PrintToChatAll(" \x04[HNS] %t", "T Win");
        else {
            SwapTeams();
            g_iTWinsInARow = 0;
            //Set the team scores
            if (!g_bScoreCrashFix) CS_SetTeamScore(CS_TEAM_CT, CS_GetTeamScore(CS_TEAM_T) + 1);
            SetTeamScore(CS_TEAM_CT, CS_GetTeamScore(CS_TEAM_T) + 1);
            if (!g_bScoreCrashFix) CS_SetTeamScore(CS_TEAM_T, iCTScore);
            SetTeamScore(CS_TEAM_T, iCTScore);
            if(g_iMaximumWinStreak)
                PrintToChatAll(" \x04[HNS] %t", "T Win Team Swap");
        }
    }
    else if(iWinningTeam == CS_TEAM_CT)
    {
        SwapTeams();
        PrintToChatAll(" \x04[HNS] %t", "CT Win");
        g_iTWinsInARow = 0;
        //Set the team scores
        if (!g_bScoreCrashFix) CS_SetTeamScore(CS_TEAM_CT, CS_GetTeamScore(CS_TEAM_T));
        SetTeamScore(CS_TEAM_CT, CS_GetTeamScore(CS_TEAM_T));
        if (!g_bScoreCrashFix) CS_SetTeamScore(CS_TEAM_T, iCTScore);
        SetTeamScore(CS_TEAM_T, iCTScore);
    }
    return;
}
#undef CS_GetTeamScore

void RemoveNades(int iClient)
{
    // Bounded. RemoveWeaponBySlot reports success from IsValidEdict, not RemovePlayerItem, so a
    // weapon the engine declines to detach leaves the slot occupied and the old unbounded loop
    // spun forever, freezing the server on spawn with no crash.
    for(int i = 0; i < 16 && RemoveWeaponBySlot(iClient, 3); i++) {}
    for(int i = 0; i < 6; i++)
        SetEntProp(iClient, Prop_Send, "m_iAmmo", 0, _, g_iaGrenadeOffsets[i]);
}

stock void GiveGrenades(int iClient)
{
    // hns_t_knife is controlled by hnsmix for knife rounds. Do not rely on chance/max cvars
    // alone: a cached cvar update can still hand a T a real flashbang during the restart.
    if(IsKnifeRoundCombatEnabled()) {
        RemoveNades(iClient);
        return;
    }

    int iaReceived[6] = {0, ...};
    int iLastType = -1;
    int iFirstType = -1;
    bool bAtLeastTwo = false;
    for(int i = 0; i < sizeof(iaReceived); i++) {
        for(int j = 0; j < g_iaGrenadeMaximumAmounts[i]; j++)
            if(GetRandomFloat(0.0, 1.0) < g_faGrenadeChance[i])
                iaReceived[i]++;
        if(iaReceived[i]) {
            GivePlayerItem(iClient, g_saGrenadeWeaponNames[i]);
            SetEntProp(iClient, Prop_Send, "m_iAmmo", iaReceived[i], _, g_iaGrenadeOffsets[i]);
            if(iLastType != -1)
                bAtLeastTwo = true;
            if(iFirstType == -1)
                iFirstType = i;
            iLastType = i;
        }
    }

    if(iLastType == -1)
        PrintToChat(iClient, " \x04[HNS] %t", "No Grenades");
    else {
        char sGrenadeMessage[256];
        for(int i = 0; i < sizeof(iaReceived); i++) {
            if(iaReceived[i]) {
                if(bAtLeastTwo && i != iFirstType) {
                    if(i == iLastType)
                        Format(sGrenadeMessage, sizeof(sGrenadeMessage), "%s %T ", sGrenadeMessage, "And", iClient);
                    else
                        StrCat(sGrenadeMessage, sizeof(sGrenadeMessage), ", ");
                }
                char sNumberTemp[5];
                IntToString(iaReceived[i], sNumberTemp, sizeof(sNumberTemp));
                StrCat(sGrenadeMessage, sizeof(sGrenadeMessage), sNumberTemp);
                StrCat(sGrenadeMessage, sizeof(sGrenadeMessage), " ");
                if(i == NADE_DECOY && g_bFrostNades)
                    Format(sGrenadeMessage, sizeof(sGrenadeMessage), "%s%T", sGrenadeMessage, "FrostNade", iClient);
                else
                    Format(sGrenadeMessage, sizeof(sGrenadeMessage), "%s%T", sGrenadeMessage, g_saGrenadeChatNames[i], iClient);
                if(iaReceived[i] > 1)
                    Format(sGrenadeMessage, sizeof(sGrenadeMessage), "%s%T", sGrenadeMessage, "Plural", iClient);
                else
                    Format(sGrenadeMessage, sizeof(sGrenadeMessage), "%s%T", sGrenadeMessage, "Singular", iClient);
            }
        }
        PrintToChat(iClient, " \x04[HNS] %t", "Grenades Received", sGrenadeMessage);
    }
}

void SwapTeams()
{
    g_bTeamSwap = true;
    for(int iClient = 1; iClient <= MaxClients; iClient++) {
        if(IsClientInGame(iClient)) {
            int team = GetClientTeam(iClient);
            if(team == CS_TEAM_T) {
                CS_SwitchTeam(iClient, CS_TEAM_CT);
                g_iaInitialTeamTrack[iClient] = CS_TEAM_CT;
            }
            else if(team == CS_TEAM_CT) {
                CS_SwitchTeam(iClient, CS_TEAM_T);
                g_iaInitialTeamTrack[iClient] = CS_TEAM_T;
            }
            else {
                if(g_iaInitialTeamTrack[iClient] == CS_TEAM_T)
                    g_iaInitialTeamTrack[iClient] = CS_TEAM_CT;
                else if(g_iaInitialTeamTrack[iClient] == CS_TEAM_CT)
                    g_iaInitialTeamTrack[iClient] = CS_TEAM_T;
            }
        }
    }
    g_bTeamSwap = false;
}

void ScreenFade(int iClient, int iFlags = FFADE_PURGE, const int iaColor[4] = {0, 0, 0, 0}, int iDuration = 0, int iHoldTime = 0)
{
    Handle hScreenFade = StartMessageOne("Fade", iClient);
    PbSetInt(hScreenFade, "duration", iDuration * 500);
    PbSetInt(hScreenFade, "hold_time", iHoldTime * 500);
    PbSetInt(hScreenFade, "flags", iFlags);
    PbSetColor(hScreenFade, "clr", iaColor);
    EndMessage();
}

bool RemoveWeaponBySlot(int iClient, int iSlot)
{
    int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
    if(IsValidEdict(iEntity)) {
        RemovePlayerItem(iClient, iEntity);
        AcceptEntityInput(iEntity, "Kill");
        return true;
    }
    return false;
}

void CreateHostageRescue()
{
    int iEntity = -1;
    if((iEntity = FindEntityByClassname(iEntity, "func_hostage_rescue")) == -1) {
        int iHostageRescueEnt = CreateEntityByName("func_hostage_rescue");
        DispatchKeyValue(iHostageRescueEnt, "targetname", "fake_hostage_rescue");
        DispatchKeyValue(iHostageRescueEnt, "origin", "-3141 -5926 -5358");
        DispatchSpawn(iHostageRescueEnt);
    }
}

void RemoveHostages()
{
    int iEntity = -1;
    while((iEntity = FindEntityByClassname(iEntity, "hostage_entity")) != -1)     //Find hostages
        AcceptEntityInput(iEntity, "kill");
}

void RemoveBombsites()
{
    int iEntity = -1;
    while((iEntity = FindEntityByClassname(iEntity, "func_bomb_target")) != -1)    //Find bombsites
        AcceptEntityInput(iEntity, "kill");    //Destroy the entity
}

bool IsWeaponKnife(const char[] sWeaponName)
{
    return StrContains(sWeaponName, "knife", false) != -1;
}

// ---- Stab through teammates ----------------------------------------------
//
// CKnife::Swing traces forward and stops at the FIRST solid entity. Friendly fire is off, so
// a teammate in the lane silently eats a swing meant for the enemy behind them. This
// re-traces with teammates transparent and applies the damage the engine already computed.
// Why this is safe where the rejected supplemental trace was not: TraceAttack runs inside
// CKnife::Swing, which the engine calls from PlayerRunCommand BETWEEN StartLagCompensation
// and FinishLagCompensation. Every other player is still rewound to where the attacker saw
// them, so this reads the same world the engine's trace just read. A trace from a timer or
// post-frame hook would read present-time positions. Do not move this out of TraceAttack.
int g_iaStabThroughTick[MAXPLAYERS + 1];

public Action TraceAttack_StabThrough(int iVictim, int &iAttacker, int &iInflictor, float &fDamage,
                                      int &iDamageType, int &iAmmoType, int iHitbox, int iHitGroup)
{
    if(!g_bEnabled || !g_hStabThroughMates.BoolValue)
        return Plugin_Continue;

    if(iAttacker < 1 || iAttacker > MaxClients || iVictim < 1 || iVictim > MaxClients || iAttacker == iVictim)
        return Plugin_Continue;
    if(!IsClientInGame(iAttacker) || !IsClientInGame(iVictim) || IsFakeClient(iAttacker))
        return Plugin_Continue;

    // Only a teammate blocking the lane is worth re-tracing; an enemy in front is a normal hit.
    if(GetClientTeam(iAttacker) != GetClientTeam(iVictim))
        return Plugin_Continue;

    int iWeapon = GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon");
    if(!IsValidEntity(iWeapon))
        return Plugin_Continue;

    char sWeaponName[64];
    GetEntityClassname(iWeapon, sWeaponName, sizeof(sWeaponName));
    if(!IsWeaponKnife(sWeaponName))
        return Plugin_Continue;

    // One pass-through per swing: the line and hull traces can both land on a teammate in the same tick.
    int iTick = GetGameTickCount();
    if(g_iaStabThroughTick[iAttacker] == iTick)
        return Plugin_Continue;
    g_iaStabThroughTick[iAttacker] = iTick;

    float fEye[3], fAngles[3], fForward[3], fEnd[3];
    GetClientEyePosition(iAttacker, fEye);
    GetClientEyeAngles(iAttacker, fAngles);
    GetAngleVectors(fAngles, fForward, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(fForward, fForward);
    ScaleVector(fForward, g_hStabThroughRange.FloatValue);
    AddVectors(fEye, fForward, fEnd);

    TR_TraceRayFilter(fEye, fEnd, MASK_SOLID, RayType_EndPoint, TraceFilter_StabThrough, iAttacker);
    if(!TR_DidHit())
        return Plugin_Continue;

    int iThrough = TR_GetEntityIndex();
    if(iThrough < 1 || iThrough > MaxClients)
        return Plugin_Continue; // world or a prop behind them: the swing was blocked for real
    if(!IsClientInGame(iThrough) || !IsPlayerAlive(iThrough))
        return Plugin_Continue;
    if(GetClientTeam(iThrough) == GetClientTeam(iAttacker))
        return Plugin_Continue; // filter should have skipped them, but never damage a teammate

    // MUST run the normal OnTakeDamage chain so hidenseek's own rules and hns_antifrag's victim
    // protection still apply to the pass-through hit. On this SourceMod the native has no
    // bypassHooks parameter and always routes through the real TakeDamage.
    // UPGRADE WARNING: SourceMod 1.11 added a 9th bypassHooks argument defaulting to TRUE. If
    // this bundle is updated, add , NULL_VECTOR, NULL_VECTOR, false or antifrag is bypassed.
    SDKHooks_TakeDamage(iThrough, iInflictor, iAttacker, fDamage, iDamageType, iWeapon);

    return Plugin_Continue;
}

// Teammates are transparent; world, props and enemies still block, so a swing into a wall stays one.
public bool TraceFilter_StabThrough(int iEntity, int iContentsMask, any iAttacker)
{
    if(iEntity == iAttacker)
        return false;

    if(iEntity >= 1 && iEntity <= MaxClients)
    {
        if(!IsClientInGame(iEntity) || !IsPlayerAlive(iEntity))
            return false;
        return GetClientTeam(iEntity) != GetClientTeam(iAttacker);
    }

    return true;
}

// The slow-stab rewrite (IN_ATTACK -> IN_ATTACK2) is server-side only: the client predicts a
// PRIMARY swing gated by m_flNextPrimaryAttack (~0.4s) while the server executes a SECONDARY
// stab gated by m_flNextSecondaryAttack (~1.0s). Clicks in that window were silently eaten,
// and the window scales with ping. Mirror the stab timer onto the primary timer so client
// and server gate on the same value. Locks always set both equal, so this never weakens them.
void SyncStabCooldown(int iKnife)
{
    float fNext = GetEntPropFloat(iKnife, Prop_Send, "m_flNextSecondaryAttack");
    if(GetEntPropFloat(iKnife, Prop_Send, "m_flNextPrimaryAttack") != fNext)
        SetEntPropFloat(iKnife, Prop_Send, "m_flNextPrimaryAttack", fNext);
}

bool IsWeaponGrenade(const char[] sWeaponName)
{
    for(int i = 0; i < sizeof(g_saGrenadeWeaponNames); i++)
        if(StrEqual(g_saGrenadeWeaponNames[i], sWeaponName))
            return true;
    return false;
}

void SetClientSpeed(int iClient, float speed)
{
    SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", speed);
}

void Freeze(int iClient, float fDuration, int iType, int iAttacker = 0)
{
    SetEntityMoveType(iClient, MOVETYPE_NONE);
    if(!g_bAttackWhileFrozen && (GetClientTeam(iClient) == CS_TEAM_CT)) {
        float defreezetime = GetGameTime() + fDuration;
        int knife = GetPlayerWeaponSlot(iClient, 2);
        if(IsValidEntity(knife)) {
            SetEntPropFloat(knife, Prop_Send, "m_flNextPrimaryAttack", defreezetime);
            SetEntPropFloat(knife, Prop_Send, "m_flNextSecondaryAttack", defreezetime);
        }
    }
    if(iType == FROSTNADE && g_bFreezeGlow) {
        float coord[3];
        GetClientEyePosition(iClient, coord);
        coord[2] -= 32.0;
        CreateGlowSprite(g_iGlowSprite, coord, fDuration);
        LightCreate(coord, fDuration);
    }
    if(iAttacker == 0) {
        // No chat spam for world or countdown freezes - the freeze itself is feedback enough.
    }
    else if(iAttacker == iClient) {
        PrintToChat(iClient, " \x04[HNS] %t", "Frozen Yourself", fDuration);
    }
    else if(iAttacker <= MaxClients) {
        if(IsClientInGame(iAttacker)) {
            char sAttackerName[MAX_NAME_LENGTH];
            GetClientName(iAttacker, sAttackerName, sizeof(sAttackerName));
            PrintToChat(iClient, " \x04[HNS] %t", "Frozen By", sAttackerName, fDuration);
        }
    }
    if(g_baFrozen[iClient]) {
        if(g_haFreezeTimer[iClient] != null) {
            KillTimer(g_haFreezeTimer[iClient]);
            if(iType == FROSTNADE)
                g_haFreezeTimer[iClient] = CreateTimer(fDuration, Unfreeze, iClient);
            else if(iType == COUNTDOWN)
                g_haFreezeTimer[iClient] = CreateTimer(fDuration, UnfreezeCountdown, iClient);
        }
    }
    else {
        g_baFrozen[iClient] = true;
        if(iType == FROSTNADE)
            g_haFreezeTimer[iClient] = CreateTimer(fDuration, Unfreeze, iClient);
        else if(iType == COUNTDOWN)
            g_haFreezeTimer[iClient] = CreateTimer(fDuration, UnfreezeCountdown, iClient);
    }
    if(iType == FROSTNADE && g_bFreezeFade)
        ScreenFade(iClient, FFADE_IN|FFADE_PURGE|FFADE_MODULATE, FREEZE_COLOR, 2, RoundToFloor(fDuration - 0.5));
    else if(iType == COUNTDOWN && g_bCountdownFade)
        ScreenFade(iClient, FFADE_IN|FFADE_PURGE, COUNTDOWN_COLOR, 2, RoundToFloor(fDuration));
}

public Action Unfreeze(Handle hTimer, any iClient)
{
    if(iClient && IsClientInGame(iClient)) {
        if(g_baFrozen[iClient]) {
            SetEntityMoveType(iClient, MOVETYPE_WALK);
            g_baFrozen[iClient] = false;
            g_haFreezeTimer[iClient] = null;
            float faCoord[3];
            GetClientEyePosition(iClient, faCoord);
            EmitAmbientSound(SOUND_UNFREEZE, faCoord, iClient, 55);
            if(IsPlayerAlive(iClient))
                PrintToChat(iClient, " \x04[HNS] %t", "Unfreeze");
        }
    }
    return Plugin_Continue;
}

public Action UnfreezeCountdown(Handle hTimer, any iClient)
{
    if(iClient && IsClientInGame(iClient)) {
        SetEntityMoveType(iClient, MOVETYPE_WALK);
        g_baFrozen[iClient] = false;
        g_haFreezeTimer[iClient] = null;
        if(IsPlayerAlive(iClient))
            PrintToChat(iClient, " \x04[HNS] %t", "Round Start");
    }
    return Plugin_Continue;
}

void SilentUnfreeze(int iClient)
{
    g_baFrozen[iClient] = false;
    SetEntityMoveType(iClient, MOVETYPE_WALK);
    if(g_haFreezeTimer[iClient] != null) {
        KillTimer(g_haFreezeTimer[iClient]);
        g_haFreezeTimer[iClient] = null;
    }
    ScreenFade(iClient);
}

void CreateBeamFollow(int iEntity, int iSprite, const int iaColor[4] = {0, 0, 0, 255})
{
    TE_SetupBeamFollow(iEntity, iSprite, 0, 1.5, 3.0, 3.0, 2, iaColor);
    TE_SendToAll();
}

void CreateGlowSprite(int iSprite, const float faCoord[3], const float fDuration)
{
    TE_SetupGlowSprite(faCoord, iSprite, fDuration, 2.2, 180);
    TE_SendToAll();
}

void LightCreate(const float faCoord[3], float fDuration)
{
    int iEntity = CreateEntityByName("light_dynamic");
    DispatchKeyValue(iEntity, "inner_cone", "0");
    DispatchKeyValue(iEntity, "cone", "90");
    DispatchKeyValue(iEntity, "brightness", "1");
    DispatchKeyValueFloat(iEntity, "spotlight_radius", 150.0);
    DispatchKeyValue(iEntity, "pitch", "90");
    DispatchKeyValue(iEntity, "style", "1");
    DispatchKeyValue(iEntity, "_light", "20 63 255 255");
    DispatchKeyValueFloat(iEntity, "distance", 150.0);

    DispatchSpawn(iEntity);
    TeleportEntity(iEntity, faCoord, NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput(iEntity, "TurnOn");
    CreateTimer(fDuration, DeleteEntity, iEntity, TIMER_FLAG_NO_MAPCHANGE);
}

public Action DeleteEntity(Handle hTimer, any iEntity)
{
    if(IsValidEdict(iEntity))
        AcceptEntityInput(iEntity, "kill");
    return Plugin_Stop;
}

int GetTeamPlayerCount(int iTeam)
{
    int iCount = 0;
    for(int iClient = 1; iClient <= MaxClients; iClient++)
        if(IsClientInGame(iClient))
            if(GetClientTeam(iClient) == iTeam)
                iCount++;
    return iCount;
}

// Extra m_iHideHUD bits, applied on spawn like the radar hide.
// CS:GO has no documented flag for the money panel, and mp_playercashawards 0 does not
// remove it on this build, so the mask is a convar rather than a constant: set it live
// with sm_cvar and keep what works. Known Source HUD flags:
//   8    (1<<3)  health and armour cluster - most likely to take money with it
//   1    (1<<0)  ammo count and weapon selection
//   4096 (1<<12) radar (hns_hide_radar already does this)
//   4    (1<<2)  the entire HUD
// Bits combine, so 9 is health plus ammo. 0 disables this entirely.
public Action ApplyHideHudBits(Handle hTimer, any iId)
{
    int iClient = GetClientOfUserId(iId);
    if(iClient < 1 || !IsClientInGame(iClient))
        return Plugin_Stop;

    int iBits = g_hHideHudBits.IntValue;
    if(iBits > 0)
        SetEntProp(iClient, Prop_Send, "m_iHideHUD", GetEntProp(iClient, Prop_Send, "m_iHideHUD") | iBits);

    return Plugin_Stop;
}

public Action RemoveRadar(Handle hTimer, any iId)
{
    int iClient = GetClientOfUserId(iId);
    if(!g_bHideRadar || iClient < 1 || !IsClientInGame(iClient))
        return Plugin_Stop;

    if(StrContains(g_sGameDirName, "csgo") != -1)
        SetEntProp(iClient, Prop_Send, "m_iHideHUD", GetEntProp(iClient, Prop_Send, "m_iHideHUD") | HIDE_RADAR_CSGO);
    else
        if(StrContains(g_sGameDirName, "cstrike") != -1) {
            SetEntPropFloat(iClient, Prop_Send, "m_flFlashDuration", 3600.0);
            SetEntPropFloat(iClient, Prop_Send, "m_flFlashMaxAlpha", 0.5);
        }
    return Plugin_Stop;
}

public void OnPlayerFlash_Post(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    int iId = hEvent.GetInt("userid");
    int iClient = GetClientOfUserId(iId);
    if(iClient && GetClientTeam(iClient) > CS_TEAM_SPECTATOR) {
        float fDuration = GetEntPropFloat(iClient, Prop_Send, "m_flFlashDuration");
        CreateTimer(fDuration, RemoveRadar, iId, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void OnPlayerTeam(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    int iId = hEvent.GetInt("userid");
    int iClient = GetClientOfUserId(iId);
    if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient))
        return;
    if(!g_bEnabled) {
        g_baWelcomeMsgShown[iClient] = true;
    }
    if(g_bWelcomeMessage && !g_baWelcomeMsgShown[iClient]) {
        g_baWelcomeMsgShown[iClient] = true;
        WriteWelcomeMessage(iClient);
    }

    // OVA rounds run ten minutes, so a late joiner would sit dead for most of one. Put them
    // straight into play and check nobody landed on T who should not be there.
    if(OvaActive())
        CreateTimer(0.2, Timer_OvaJoinRespawn, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_OvaJoinRespawn(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    if(!OvaActive() || iClient < 1 || !IsClientInGame(iClient) || IsFakeClient(iClient))
        return Plugin_Stop;
    if(GetClientTeam(iClient) <= CS_TEAM_SPECTATOR)
        return Plugin_Stop;

    if(!IsPlayerAlive(iClient))
        CS_RespawnPlayer(iClient);

    // An empty T slot is filled by whoever turns up.
    if(g_iOvaCurrentT < 1)
        OvaPromoteToT(iClient, false);

    SetEntProp(iClient, Prop_Send, "m_iAccount", 0);
    OvaEnforceSingleT();
    return Plugin_Stop;
}

public Action OnPlayerTeam_Pre(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    if(g_bTeamSwap) {
        hEvent.SetBool("silent", true);
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

void WriteWelcomeMessage(int iClient)
{
    PrintToChat(iClient, " \x04[HNS] %t", "Welcome Msg", PLUGIN_VERSION, AUTHOR, "Normal Mode");
}

public Action RemoveRespawnProtection(Handle hTimer, any iClient)
{
    if(iClient < 1 || iClient > MaxClients)
        return Plugin_Stop;

    g_haRespawnProtectionTimer[iClient] = null;
    g_baRespawnProtection[iClient] = false;
    return Plugin_Stop;
}

public Action OnPlayerHurt(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    int iVictimId = hEvent.GetInt("userid");
    int iVictimClient = GetClientOfUserId(iVictimId);
    int iAttackerId = hEvent.GetInt("attacker");
    int iAttackerClient = GetClientOfUserId(iAttackerId);

    if(g_baRespawnProtection[iVictimClient] && iAttackerClient != 0) {
        bDontBroadcast = true;
        return Plugin_Changed;
    }

    if(!g_bDamageSlowdown)
        SetEntPropFloat(iVictimClient, Prop_Send, "m_flVelocityModifier", 1.0);

    return Plugin_Continue;
}

public void OnAdminMenuCreated(Handle topmenu)
{
    if (g_bAdminMenu)
        AddHNSCategory(TopMenu.FromHandle(topmenu));
}

void AddHNSCategory(TopMenu topmenu)
{
    TopMenuObject obj = topmenu.AddCategory("hnsova", TopMenuHandler_HNSCategory, "sm_hidenseek_amenu");
    if (obj == INVALID_TOPMENUOBJECT)
        ThrowError("Failed to create HNS category object.");

    static Handle fwd = null;
    if (fwd == null)
        fwd = CreateGlobalForward("HNS_OnCategoryAdded", ET_Ignore, Param_Cell, Param_Cell);

    Call_StartForward(fwd);
    Call_PushCell(topmenu);
    Call_PushCell(obj);
    Call_Finish();
}

public void HNS_OnCategoryAdded(TopMenu topmenu, TopMenuObject obj)
{
    topmenu.AddItem("hns_hnsswitch", TopMenuHandler_HNSSwitch, obj, _, ADMFLAG_CONVARS);
}

public void TopMenuHandler_HNSCategory(Handle topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
    switch (action) {
        case TopMenuAction_DisplayTitle:
            strcopy(buffer, maxlength, "HNSOVA");
        case TopMenuAction_DisplayOption:
            strcopy(buffer, maxlength, "HNSOVA");
    }
}

public void TopMenuHandler_HNSSwitch(Handle topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
    switch (action) {
        case TopMenuAction_DisplayOption: Format(buffer, maxlength, "Turn %s HNS", g_bEnabled ? "off" : "on");
        case TopMenuAction_SelectOption: {
            PrintToChatAll(" \x04[HNS] Hide'N'Seek turned %s.", g_bEnabled ? "off" : "on");
            LogAction(param, -1, "%L turned %s Hide'N'Seek plugin.", param, g_bEnabled ? "off" : "on");
            g_hEnabled.BoolValue = !g_bEnabled;
        }
    }
}

public int Native_HNS_IsEnabled(Handle plugin, int numParams)
{
    return g_bEnabled;
}

public int Native_HNS_GetMode(Handle plugin, int numParams)
{
    // Respawn mode has been removed from the plugin entirely.
    return HNSMODE_NORMAL;
}

// ============================================================================
// OVA - One Versus All
// Same knife-only ruleset as HNS, different shape: exactly one T, everyone else CT, and the
// CT who stabs the T takes the role on the spot. Scored on how long you hold T, not on
// winning the round.
// ============================================================================

bool OvaActive()
{
    // A mix owns the teams, rounds and spawns, so OVA stands down for the whole of one - and it
    // must do so the instant a mix exists, not when the watcher gets round to it. That gap let
    // OvaEnforceSingleT move a freshly picked T captain onto CT.
    // FJ owns them the same way. It runs on an extended warmup, and OVA was drafting a T,
    // forcing teams and re-pinning round cvars straight through it, cutting a 30 minute session
    // to a couple of minutes. Nothing to restore afterwards: FJ ending starts a round.
    return g_bOvaActive && !OvaMixRunning() && !FJRunning();
}

// Both gamemodes feed the same cached arrays, so downstream grenade paths keep working. Re-run on mode change.
void RefreshGrenadeSettings()
{
    if(g_bOvaActive) {
        g_faGrenadeChance[NADE_FLASHBANG] = g_hOvaFlashbangChance.FloatValue;
        g_faGrenadeChance[NADE_MOLOTOV] = g_hOvaMolotovChance.FloatValue;
        g_faGrenadeChance[NADE_SMOKE] = g_hOvaSmokeChance.FloatValue;
        g_faGrenadeChance[NADE_DECOY] = g_hOvaDecoyChance.FloatValue;
        g_faGrenadeChance[NADE_HE] = g_hOvaHEChance.FloatValue;
        g_iaGrenadeMaximumAmounts[NADE_FLASHBANG] = g_hOvaFlashbangMax.IntValue;
        g_iaGrenadeMaximumAmounts[NADE_MOLOTOV] = g_hOvaMolotovMax.IntValue;
        g_iaGrenadeMaximumAmounts[NADE_SMOKE] = g_hOvaSmokeMax.IntValue;
        g_iaGrenadeMaximumAmounts[NADE_DECOY] = g_hOvaDecoyMax.IntValue;
        g_iaGrenadeMaximumAmounts[NADE_HE] = g_hOvaHEMax.IntValue;
        return;
    }

    g_faGrenadeChance[NADE_FLASHBANG] = g_hFlashbangChance.FloatValue;
    g_faGrenadeChance[NADE_MOLOTOV] = g_hMolotovChance.FloatValue;
    g_faGrenadeChance[NADE_SMOKE] = g_hSmokeGrenadeChance.FloatValue;
    g_faGrenadeChance[NADE_DECOY] = g_hDecoyChance.FloatValue;
    g_faGrenadeChance[NADE_HE] = g_hHEGrenadeChance.FloatValue;
    g_iaGrenadeMaximumAmounts[NADE_FLASHBANG] = g_hFlashbangMaximumAmount.IntValue;
    g_iaGrenadeMaximumAmounts[NADE_MOLOTOV] = g_hMolotovMaximumAmount.IntValue;
    g_iaGrenadeMaximumAmounts[NADE_SMOKE] = g_hSmokeGrenadeMaximumAmount.IntValue;
    g_iaGrenadeMaximumAmounts[NADE_DECOY] = g_hDecoyMaximumAmount.IntValue;
    g_iaGrenadeMaximumAmounts[NADE_HE] = g_hHEGrenadeMaximumAmount.IntValue;
}

// hnsmix owns the server during a mix. Same gate KevFJ uses.
bool OvaMixRunning()
{
    return (GetFeatureStatus(FeatureType_Native, "kev_isMixActive") == FeatureStatus_Available && kev_isMixActive() != 0);
}

bool FJRunning()
{
    return (GetFeatureStatus(FeatureType_Native, "kev_isFJActive") == FeatureStatus_Available && kev_isFJActive() != 0);
}

int OvaCountPlayers()
{
    int iCount = 0;
    for(int iClient = 1; iClient <= MaxClients; iClient++) {
        if(IsClientInGame(iClient) && !IsFakeClient(iClient) && GetClientTeam(iClient) > CS_TEAM_SPECTATOR)
            iCount++;
    }
    return iCount;
}

// Seconds to m:ss, matching the survival times hnsmix prints.
void OvaFormatTime(float fSeconds, char[] sOut, int iMaxLen)
{
    int iTotal = RoundToFloor(fSeconds);
    FormatEx(sOut, iMaxLen, "%d:%02d", iTotal / 60, iTotal % 60);
}

// ---------------------------------------------------------------- mode state

// A mix owns the teams, rounds and spawns for its whole run. OVA fights all of that, so it
// steps aside for the duration and comes back afterwards if it was on before.
public Action Timer_OvaMixWatch(Handle hTimer)
{
    bool bMix = OvaMixRunning();

    // Self-healing round clock. Plugin load order and the warmup-to-live transition both decide
    // who pins m_iRoundTime last, and losing that race left the HUD on 2:30 until an FJ toggle
    // forced a fresh round. Re-asserting is a no-op when the value matches, and setting it does
    // not restart the countdown (the HUD reads start + length - now).
    // OvaActive(), not the raw flag: FJ owns the clock for an hour and this runs every second,
    // so it would have stomped that back to OVA's ten minutes within the first FJ round.
    if(OvaActive())
    {
        int iWant = RoundToNearest(g_hOvaRoundTime.FloatValue * 60.0);
        if(GameRules_GetProp("m_iRoundTime") != iWant)
            GameRules_SetProp("m_iRoundTime", iWant);
    }

    if(bMix && g_bOvaActive) {
        g_bOvaSuspendedForMix = true;
        OvaSetMode(false, "mix starting", false);
        return Plugin_Continue;
    }

    if(!bMix && g_bOvaSuspendedForMix) {
        g_bOvaSuspendedForMix = false;

        // A cancelled mix can leave the server parked in warmup - FJ extends it and a mix restart
        // does not always clear it. Ending it here means the restart below produces a live round
        // with a drafted T rather than an endless warmup.
        ServerCommand("mp_warmup_end");

        // The flag is only set when OVA was already running, so it is the record of what to restore.
        // g_bOvaVotedThisMap was wrong here: it is true after a vote to switch AWAY from OVA too,
        // which would turn OVA back on against the players' vote.
        OvaSetMode(true, "mix ended", true);
    }

    return Plugin_Continue;
}

// bRestart is false when something else owns the round flow; restarting underneath a mix breaks its setup.
void OvaSetMode(bool bOva, const char[] sReason, bool bRestart = true)
{
    if(g_bOvaActive == bOva)
        return;

    g_bOvaActive = bOva;
    RefreshGrenadeSettings();

    if(bOva) {
        OvaApplyRoundCvars();
    }
    else {
        FindConVar("mp_ignore_round_win_conditions").IntValue = 0;
        OvaClearRoundTimer();

        // Hand collision back, or HNS inherits pass-through players.
        for(int iClient = 1; iClient <= MaxClients; iClient++) {
            if(IsClientInGame(iClient))
                OvaApplyNoBlock(iClient, false);
        }
    }

    PrintToChatAll(" \x04[%s]\x01 Gamemode is now \x04%s\x01 (%s).%s", bOva ? "OVA" : "HNS", bOva ? "One Versus All" : "Hide N Seek", sReason, bRestart ? " Restarting round." : "");

    if(bRestart)
        ServerCommand("mp_restartgame 2");
}

// The T team is a single player, so a stab would normally wipe it and end the round. OVA runs its own clock.
void OvaApplyRoundCvars()
{
    FindConVar("mp_ignore_round_win_conditions").IntValue = 1;
    FindConVar("mp_roundtime").SetFloat(g_hOvaRoundTime.FloatValue);
    FindConVar("mp_roundtime_defuse").SetFloat(g_hOvaRoundTime.FloatValue);
    FindConVar("mp_roundtime_hostage").SetFloat(g_hOvaRoundTime.FloatValue);

    // 1 versus everyone is the mode, so the engine must stop evening the sides up. Auto-balance
    // moves players onto T at round start and a team limit of 1 blocks CT joins.
    FindConVar("mp_autoteambalance").IntValue = 0;
    FindConVar("mp_limitteams").IntValue = 0;

    // Rounds run ten minutes, so an engine-side join window would lock spectators out for most of one.
    ConVar cvGrace = FindConVar("mp_join_grace_time");
    if(cvGrace != null)
        cvGrace.IntValue = 0;
}

void OvaClearRoundTimer()
{
    if(g_hOvaRoundTimer != null) {
        KillTimer(g_hOvaRoundTimer);
        g_hOvaRoundTimer = null;
    }
}

// ------------------------------------------------------------- round control

public Action Timer_OvaRoundSetup(Handle hTimer)
{
    if(OvaActive())
        OvaRoundStart();

    return Plugin_Stop;
}

void OvaRoundStart()
{
    OvaClearRoundTimer();

    // Reapplied every round, not just on a mode switch: a map load sets g_bOvaActive directly.
    OvaApplyRoundCvars();

    // mp_roundtime only takes effect from the NEXT round, so the HUD counted down the old 2:30
    // while the real round ran ten minutes. The clock reads (m_fRoundStartTime + m_iRoundTime
    // - now), so pin the round length on the game rules entity for the round that just began.
    GameRules_SetProp("m_iRoundTime", RoundToNearest(g_hOvaRoundTime.FloatValue * 60.0));
    GameRules_SetPropFloat("m_fRoundStartTime", GetGameTime());

    g_iOvaCurrentT = 0;
    g_iOvaLastStabber = 0;
    g_fOvaTStart = 0.0;
    // Death spots included: a stale one would teleport a demoted player to where they died on another layout.
    for(int iClient = 1; iClient <= MaxClients; iClient++)
        OvaResetClient(iClient);

    // Nothing in OVA freezes anyone, and a stuck freeze strips both attack buttons and glows green.
    for(int iClient = 1; iClient <= MaxClients; iClient++) {
        if(IsClientInGame(iClient) && g_baFrozen[iClient])
            SilentUnfreeze(iClient);
    }

    // Everyone starts CT, then one is drafted, so a leftover T from last round never survives the reset.
    for(int iClient = 1; iClient <= MaxClients; iClient++) {
        if(IsClientInGame(iClient) && !IsFakeClient(iClient) && GetClientTeam(iClient) == CS_TEAM_T)
            OvaSetTeam(iClient, CS_TEAM_CT);
    }

    int iT = OvaPickRandomT(0);
    if(iT > 0)
        OvaPromoteToT(iT, false);

    // Spawn points are chosen when the engine spawns you, not on team change. Without this the
    // new T stands at a CT spawn and last round's T stands at the T spawn as a CT.
    for(int iClient = 1; iClient <= MaxClients; iClient++) {
        if(IsClientInGame(iClient) && !IsFakeClient(iClient) && GetClientTeam(iClient) > CS_TEAM_SPECTATOR)
            CS_RespawnPlayer(iClient);
    }

    // Respawning resets health and the damage flag, so the drafted T is armed after the loop -
    // otherwise the promotion's health reset and immunity were thrown away a line later.
    if(g_iOvaCurrentT > 0 && IsClientInGame(g_iOvaCurrentT) && IsPlayerAlive(g_iOvaCurrentT)) {
        SetEntityHealth(g_iOvaCurrentT, 100);
        OvaGiveProtection(g_iOvaCurrentT);
    }

    float fRound = g_hOvaRoundTime.FloatValue * 60.0;
    g_hOvaRoundTimer = CreateTimer(fRound, Timer_OvaRoundOver, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_OvaRoundOver(Handle hTimer)
{
    g_hOvaRoundTimer = null;
    if(!OvaActive())
        return Plugin_Stop;

    OvaRoundOver();
    return Plugin_Stop;
}

void OvaRoundOver()
{
    OvaCreditStint();
    OvaShowRoundResults();
    OvaFlushRoundStats();

    // mp_ignore_round_win_conditions stops a stabbed T ending the round, but it also swallows
    // this termination, leaving the clock parked at 0:00. Lift it for the call; OvaApplyRoundCvars
    // puts it back on the next round start.
    FindConVar("mp_ignore_round_win_conditions").IntValue = 0;

    // CT "wins" is cosmetic here; the round has to end somehow.
    CS_TerminateRound(3.0, CSRoundEnd_CTWin, false);
}

// ------------------------------------------------------------ the T role

int OvaPickRandomT(int iExclude)
{
    int iAlive[MAXPLAYERS + 1], iAny[MAXPLAYERS + 1];
    int iAliveCount = 0, iAnyCount = 0;

    for(int iClient = 1; iClient <= MaxClients; iClient++) {
        if(iClient == iExclude || !IsClientInGame(iClient) || IsFakeClient(iClient))
            continue;
        if(GetClientTeam(iClient) <= CS_TEAM_SPECTATOR)
            continue;

        iAny[iAnyCount++] = iClient;
        if(IsPlayerAlive(iClient))
            iAlive[iAliveCount++] = iClient;
    }

    // A living player takes the role where they stand. A dead one has no position to keep, so
    // promoting them means a respawn at a T spawn - only acceptable with nobody alive to pick.
    if(iAliveCount > 0)
        return iAlive[GetRandomInt(0, iAliveCount - 1)];

    if(iAnyCount > 0)
        return iAny[GetRandomInt(0, iAnyCount - 1)];

    return 0;
}

// CS_SwitchTeam moves a player without killing them, which is the point of the handover, but
// it leaves the old team's agent model on them. Nothing respawns them on the in-place paths,
// so the model is refreshed by hand and every OVA team change goes through here.
// mp_solid_teammates 0 stops teammates blocking each other horizontally but still lets you
// land on their head, which is the part that gets abused; the collision group is what
// actually removes player-on-player contact. 2 is COLLISION_GROUP_DEBRIS_TRIGGER: passes
// through every player while still colliding with the world, 5 is the player default.
// Collision groups are not team-aware, which is the right answer in OVA anyway.
void OvaApplyNoBlock(int iClient, bool bEnable)
{
    if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
        return;

    // Always writes a value rather than returning early when the cvar is off. The old version
    // left group 2 on anyone who had it, so a CT kept passing through everyone after becoming T.
    bool bWant = bEnable && g_hOvaNoBlock.BoolValue;
    SetEntProp(iClient, Prop_Send, "m_CollisionGroup", bWant ? 2 : 5);
}

// Short immunity on taking the T role. Without it the CT who just stabbed is standing on the
// new T and any second CT nearby takes the role straight back.
void OvaGiveProtection(int iClient)
{
    float fDuration = g_hOvaTProtect.FloatValue;
    if(fDuration <= 0.0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
        return;

    g_faOvaProtectUntil[iClient] = GetGameTime() + fDuration;
    SetEntProp(iClient, Prop_Data, "m_takedamage", 0, 1);

    CreateTimer(fDuration, Timer_OvaEndProtection, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
    PrintToChat(iClient, " \x04[OVA]\x01 You are protected for \x04%.1f\x01 seconds.", fDuration);
}

void OvaClearProtection(int iClient)
{
    g_faOvaProtectUntil[iClient] = 0.0;

    // Always restores the damage flag. The old version returned early when the tracker was
    // already zero, so any path clearing the tracker FIRST left m_takedamage stuck at 0 - and
    // OvaResetClient does exactly that. The result was a T nobody could stab, permanently.
    if(iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && IsPlayerAlive(iClient))
        SetEntProp(iClient, Prop_Data, "m_takedamage", 2, 1);
}

public Action Timer_OvaEndProtection(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    if(iClient < 1 || !IsClientInGame(iClient))
        return Plugin_Stop;

    // A later promotion may have restarted the window; let its own timer end it rather than cutting it short.
    if(GetGameTime() < g_faOvaProtectUntil[iClient] - 0.05)
        return Plugin_Stop;

    OvaClearProtection(iClient);
    return Plugin_Stop;
}

void OvaSetTeam(int iClient, int iTeam)
{
    if(GetClientTeam(iClient) != iTeam)
        CS_SwitchTeam(iClient, iTeam);

    g_iaInitialTeamTrack[iClient] = iTeam;
    CS_UpdateClientModel(iClient);

    // OVA hands out kills constantly and switches teams without a normal spawn, so spawn-time zeroing is not enough.
    SetEntProp(iClient, Prop_Send, "m_iAccount", 0);
    OvaApplyNoBlock(iClient, true);
}

// bInPlace keeps the new T where they are, which is the feel of the handover: the killer becomes the hunted.
void OvaPromoteToT(int iClient, bool bInPlace)
{
    if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient))
        return;

    float fOrigin[3], fAngles[3];
    bool bAlive = IsPlayerAlive(iClient);
    if(bInPlace && bAlive) {
        GetClientAbsOrigin(iClient, fOrigin);
        GetClientEyeAngles(iClient, fAngles);
    }

    OvaSetTeam(iClient, CS_TEAM_T);

    if(!IsPlayerAlive(iClient))
        CS_RespawnPlayer(iClient);

    if(bInPlace && bAlive)
        TeleportEntity(iClient, fOrigin, fAngles, NULL_VECTOR);

    // The new T keeps their position but not their damage. A CT who chipped themselves on a fall
    // would otherwise inherit the role on low health and lose it to the next stab.
    if(IsPlayerAlive(iClient))
        SetEntityHealth(iClient, 100);

    // hidenseek's own spawn protection stays off; the T role carries its own short immunity.
    g_baRespawnProtection[iClient] = false;
    OvaGiveProtection(iClient);

    g_iOvaCurrentT = iClient;
    g_iOvaLastStabber = 0;
    g_fOvaTStart = GetGameTime();

    PrintToChatAll(" \x04[OVA]\x01 \x04%N\x01 is now the \x02T\x01.", iClient);
}

// Bank the current T's time. Called on every handover and at round end, so three stints all count.
void OvaCreditStint()
{
    if(g_iOvaCurrentT < 1 || g_fOvaTStart <= 0.0)
        return;

    float fHeld = GetGameTime() - g_fOvaTStart;
    if(fHeld > 0.0 && IsClientInGame(g_iOvaCurrentT)) {
        g_faOvaRoundSurvival[g_iOvaCurrentT] += fHeld;
        if(fHeld > g_faOvaBestStint[g_iOvaCurrentT])
            g_faOvaBestStint[g_iOvaCurrentT] = fHeld;
    }

    g_fOvaTStart = 0.0;
}

// ------------------------------------------------------------------- events

void OvaOnPlayerDeath(int iVictim, int iAttacker)
{
    if(iVictim < 1 || iVictim > MaxClients)
        return;

    bool bVictimWasT = (iVictim == g_iOvaCurrentT);

    if(!bVictimWasT) {
        // CTs cannot be knifed by the T, so this is fall damage or a hazard. Straight back into play.
        // 0.1s was not always enough for the engine to finish killing them, silently skipping the respawn.
        CreateTimer(0.2, Timer_OvaRespawnCt, GetClientUserId(iVictim), TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    OvaCreditStint();

    bool bStabbed = (iAttacker > 0 && iAttacker <= MaxClients && iAttacker != iVictim
        && IsClientInGame(iAttacker) && GetClientTeam(iAttacker) == CS_TEAM_CT);

    // Only a real CT kill counts on either side. Falling to your death is not a stab taken.
    if(bStabbed) {
        g_iaOvaStabsGiven[iAttacker]++;
        g_iaOvaStabsTaken[iVictim]++;
    }

    // Remembered so a T who disconnects right after being stabbed still hands the role to whoever earned it.
    g_iOvaLastStabber = bStabbed ? iAttacker : 0;

    int iNext = bStabbed ? iAttacker : OvaPickRandomT(iVictim);

    g_iOvaCurrentT = 0;

    // Nobody else to hand it to, so keep the role rather than leaving the round with no T at all.
    if(iNext < 1) {
        CreateTimer(0.2, Timer_OvaRespawnCt, GetClientUserId(iVictim), TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(0.3, Timer_OvaReclaimT, GetClientUserId(iVictim), TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    // The dead T comes back as a CT where they fell rather than at spawn.
    CreateTimer(0.2, Timer_OvaDemoteToCt, GetClientUserId(iVictim), TIMER_FLAG_NO_MAPCHANGE);
    OvaPromoteToT(iNext, true);
}

public Action Timer_OvaRespawnCt(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    if(!OvaActive() || iClient < 1 || !IsClientInGame(iClient) || IsFakeClient(iClient))
        return Plugin_Stop;

    // Any live team, not CS_TEAM_CT specifically: a player caught mid-handover can still be on T this tick.
    if(GetClientTeam(iClient) > CS_TEAM_SPECTATOR && !IsPlayerAlive(iClient))
        CS_RespawnPlayer(iClient);

    SetEntProp(iClient, Prop_Send, "m_iAccount", 0);
    return Plugin_Stop;
}

// Sole survivor: they died with nobody to pass the role to, so they get it back after the respawn.
public Action Timer_OvaReclaimT(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    if(!OvaActive() || g_iOvaCurrentT > 0 || iClient < 1 || !IsClientInGame(iClient))
        return Plugin_Stop;
    if(GetClientTeam(iClient) <= CS_TEAM_SPECTATOR)
        return Plugin_Stop;

    OvaPromoteToT(iClient, false);
    return Plugin_Stop;
}

public Action Timer_OvaDemoteToCt(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    if(!OvaActive() || iClient < 1 || !IsClientInGame(iClient))
        return Plugin_Stop;

    // Losing the role loses the immunity that came with it.
    OvaClearProtection(iClient);
    OvaSetTeam(iClient, CS_TEAM_CT);

    // Plain respawn, so they return at a CT spawn. Only the killer keeps their position.
    if(!IsPlayerAlive(iClient))
        CS_RespawnPlayer(iClient);

    return Plugin_Stop;
}

// Client indexes are recycled, so every OVA array is cleared here or the next player inherits the stats.
void OvaResetClient(int iClient)
{
    // Goes through the clearer so the damage flag comes back with the tracker.
    OvaClearProtection(iClient);
    g_faOvaRoundSurvival[iClient] = 0.0;
    g_faOvaBestStint[iClient] = 0.0;
    g_iaOvaStabsGiven[iClient] = 0;
    g_iaOvaStabsTaken[iClient] = 0;
}

void OvaOnClientDisconnect(int iClient)
{
    OvaResetClient(iClient);

    if(iClient != g_iOvaCurrentT)
        return;

    OvaCreditStint();
    g_iOvaCurrentT = 0;

    // Whoever last stabbed them has first claim, otherwise draft at random. Both take the role where they stand.
    int iNext = 0;
    if(g_iOvaLastStabber > 0 && IsClientInGame(g_iOvaLastStabber)
        && g_iOvaLastStabber != iClient && IsPlayerAlive(g_iOvaLastStabber))
        iNext = g_iOvaLastStabber;
    else
        iNext = OvaPickRandomT(iClient);

    if(iNext > 0)
        OvaPromoteToT(iNext, true);
}

// A T slot must always be filled: if the server emptied out and someone joins, they take the role.
void OvaOnClientJoinedTeam(int iClient)
{
    if(!OvaActive() || g_iOvaCurrentT > 0)
        return;
    if(!IsClientInGame(iClient) || GetClientTeam(iClient) <= CS_TEAM_SPECTATOR)
        return;

    OvaPromoteToT(iClient, false);
}

// Last line of defense against a second T. Auto-balance, a team limit or another plugin can
// produce one and the mode silently stops working. g_iOvaCurrentT is the authority, so the
// legitimate T is never the player moved.
void OvaEnforceSingleT()
{
    // No tracked T means the round has not drafted one; moving people now would fight the draft.
    if(!OvaActive() || g_iOvaCurrentT < 1 || !IsClientInGame(g_iOvaCurrentT))
        return;

    for(int iClient = 1; iClient <= MaxClients; iClient++) {
        if(!IsClientInGame(iClient) || IsFakeClient(iClient))
            continue;
        if(iClient == g_iOvaCurrentT || GetClientTeam(iClient) != CS_TEAM_T)
            continue;

        float fOrigin[3], fAngles[3];
        bool bAlive = IsPlayerAlive(iClient);
        if(bAlive) {
            GetClientAbsOrigin(iClient, fOrigin);
            GetClientEyeAngles(iClient, fAngles);
        }

        OvaClearProtection(iClient);
        OvaSetTeam(iClient, CS_TEAM_CT);

        if(!IsPlayerAlive(iClient))
            CS_RespawnPlayer(iClient);
        if(bAlive)
            TeleportEntity(iClient, fOrigin, fAngles, NULL_VECTOR);

        PrintToChat(iClient, " \x04[OVA]\x01 There can only be one \x02T\x01. You were moved to \x0BCT\x01.");
    }
}

// ------------------------------------------------------------------ results

void OvaShowRoundResults()
{
    int iTop[3] = {0, 0, 0};

    for(int iRank = 0; iRank < 3; iRank++) {
        float fBest = 0.0;
        int iBest = 0;

        for(int iClient = 1; iClient <= MaxClients; iClient++) {
            if(!IsClientInGame(iClient) || g_faOvaRoundSurvival[iClient] <= 0.0)
                continue;
            if(iClient == iTop[0] || iClient == iTop[1] || iClient == iTop[2])
                continue;
            if(g_faOvaRoundSurvival[iClient] > fBest) {
                fBest = g_faOvaRoundSurvival[iClient];
                iBest = iClient;
            }
        }

        iTop[iRank] = iBest;
    }

    if(iTop[0] < 1) {
        PrintToChatAll(" \x04[OVA]\x01 Round Ended. Nobody held \x02T\x01 long enough to score.");
        return;
    }

    PrintToChatAll(" \x04[OVA]\x01 \x04Round Ended\x01 - longest survival as \x02T\x01:");

    // Rank lines carry no tag: the header established it and the repeat only pushes names right.
    char sTime[16];
    for(int iRank = 0; iRank < 3; iRank++) {
        if(iTop[iRank] < 1)
            break;
        OvaFormatTime(g_faOvaRoundSurvival[iTop[iRank]], sTime, sizeof(sTime));
        PrintToChatAll(" \x04#%d\x01 %N \x02%s\x01", iRank + 1, iTop[iRank], sTime);
    }
}

// ----------------------------------------------------------------- database

void OvaDbConnect()
{
    if(SQL_CheckConfig("ova"))
        Database.Connect(OnOvaDbConnected, "ova");
    else
        Database.Connect(OnOvaDbConnected, "default");
}

public void OnOvaDbConnected(Database hDb, const char[] sError, any data)
{
    if(hDb == null) {
        LogError("[OVA] Database connection failed: %s", sError);
        return;
    }

    g_hOvaDb = hDb;

    char sDriver[32];
    hDb.Driver.GetIdentifier(sDriver, sizeof(sDriver));
    g_bOvaDbSQLite = StrEqual(sDriver, "sqlite");
    if(!g_bOvaDbSQLite)
        g_hOvaDb.SetCharset("utf8mb4");

    char sQuery[768];
    FormatEx(sQuery, sizeof(sQuery),
        "CREATE TABLE IF NOT EXISTS `ova_stats` (\
        `steamid` VARCHAR(32) NOT NULL, \
        `name` VARCHAR(64) NOT NULL DEFAULT '', \
        `total_time` INT NOT NULL DEFAULT 0, \
        `best_stint` INT NOT NULL DEFAULT 0, \
        `t_stints` INT NOT NULL DEFAULT 0, \
        `stabs_given` INT NOT NULL DEFAULT 0, \
        `stabs_taken` INT NOT NULL DEFAULT 0, \
        `rounds` INT NOT NULL DEFAULT 0, \
        `last_played` INT NOT NULL DEFAULT 0, \
        PRIMARY KEY (`steamid`))");
    g_hOvaDb.Query(SqlCallback_OvaGeneric, sQuery);

    // Schema evolution for tables made before the stab columns existed; the duplicate-column error is expected.
    g_hOvaDb.Query(SqlCallback_OvaSilent, "ALTER TABLE `ova_stats` ADD COLUMN `stabs_given` INT NOT NULL DEFAULT 0");
    g_hOvaDb.Query(SqlCallback_OvaSilent, "ALTER TABLE `ova_stats` ADD COLUMN `stabs_taken` INT NOT NULL DEFAULT 0");
}

public void SqlCallback_OvaSilent(Database hDb, DBResultSet hResults, const char[] sError, any data)
{
}

public void SqlCallback_OvaGeneric(Database hDb, DBResultSet hResults, const char[] sError, any data)
{
    if(hResults == null && sError[0] != '\0')
        LogError("[OVA] Query failed: %s", sError);
}

void OvaFlushRoundStats()
{
    if(g_hOvaDb == null)
        return;

    for(int iClient = 1; iClient <= MaxClients; iClient++) {
        if(!IsClientInGame(iClient) || IsFakeClient(iClient))
            continue;
        int iSeconds = RoundToFloor(g_faOvaRoundSurvival[iClient]);
        int iBest = RoundToFloor(g_faOvaBestStint[iClient]);
        int iGiven = g_iaOvaStabsGiven[iClient];
        int iTaken = g_iaOvaStabsTaken[iClient];

        // A CT who only ever stabbed still played the round, so time alone is not the test for writing.
        if(iSeconds <= 0 && iGiven <= 0 && iTaken <= 0)
            continue;

        char sAuth[32];
        if(!GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth)))
            continue;

        char sName[64], sSafeName[145], sSafeAuth[65];
        GetClientName(iClient, sName, sizeof(sName));
        g_hOvaDb.Escape(sName, sSafeName, sizeof(sSafeName));
        g_hOvaDb.Escape(sAuth, sSafeAuth, sizeof(sSafeAuth));

        // MySQL and SQLite spell upsert differently; everything else matches.
        char sQuery[1400];
        FormatEx(sQuery, sizeof(sQuery),
            "INSERT INTO `ova_stats` (`steamid`, `name`, `total_time`, `best_stint`, `t_stints`, `stabs_given`, `stabs_taken`, `rounds`, `last_played`) \
            VALUES ('%s', '%s', %d, %d, %d, %d, %d, 1, %d) \
            %s `name` = '%s', `total_time` = `total_time` + %d, \
            `best_stint` = CASE WHEN `best_stint` < %d THEN %d ELSE `best_stint` END, \
            `t_stints` = `t_stints` + %d, `stabs_given` = `stabs_given` + %d, \
            `stabs_taken` = `stabs_taken` + %d, `rounds` = `rounds` + 1, `last_played` = %d",
            sSafeAuth, sSafeName, iSeconds, iBest, (iSeconds > 0) ? 1 : 0, iGiven, iTaken, GetTime(),
            g_bOvaDbSQLite ? "ON CONFLICT(`steamid`) DO UPDATE SET" : "ON DUPLICATE KEY UPDATE",
            sSafeName, iSeconds, iBest, iBest, (iSeconds > 0) ? 1 : 0, iGiven, iTaken, GetTime());

        g_hOvaDb.Query(SqlCallback_OvaGeneric, sQuery);
    }
}

// -------------------------------------------------------------- leaderboard

char g_saOvaLbTitles[OVA_LB_CATEGORIES][] = {
    "Survival Time",
    "Stabs Given",
    "Stabs Taken"
};

// One cell carries the whole request through the async query. UserIDs climb past 4095, so they get 16 bits.
int OvaLbPack(int iUserId, int iCategory, int iPage)
{
    return (iUserId & 0xFFFF) | (iCategory << 16) | (iPage << 20);
}

public Action Command_OvaLeaderboard(int iClient, int iArgs)
{
    if(iClient == 0) {
        ReplyToCommand(iClient, "[OVA] This command must be used in-game.");
        return Plugin_Handled;
    }
    if(g_hOvaDb == null) {
        PrintToChat(iClient, " \x04[OVA]\x01 Leaderboard is unavailable (no database).");
        return Plugin_Handled;
    }

    OvaLbCategoryMenu(iClient);
    return Plugin_Handled;
}

void OvaLbCategoryMenu(int iClient)
{
    Menu hMenu = new Menu(OvaLbCategoryHandler);
    hMenu.SetTitle("[OVA] Leaderboard System");
    hMenu.AddItem("0", g_saOvaLbTitles[OVA_LB_SURVIVAL]);
    hMenu.AddItem("1", g_saOvaLbTitles[OVA_LB_STABS_GIVEN]);
    hMenu.AddItem("2", g_saOvaLbTitles[OVA_LB_STABS_TAKEN]);
    hMenu.ExitButton = true;
    hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int OvaLbCategoryHandler(Menu hMenu, MenuAction action, int iClient, int iItem)
{
    if(action == MenuAction_End) {
        delete hMenu;
        return 0;
    }
    if(action != MenuAction_Select)
        return 0;

    OvaLbQuery(iClient, iItem, 0);
    return 0;
}

void OvaLbQuery(int iClient, int iCategory, int iPage)
{
    if(g_hOvaDb == null || iCategory < 0 || iCategory >= OVA_LB_CATEGORIES)
        return;
    if(iPage < 0)
        iPage = 0;

    int iPerPage = g_hOvaDiscordLbEntries.IntValue;
    int iOffset = iPage * iPerPage;

    // One row past the page tells the menu whether "Next" is worth drawing.
    char sOrder[64];
    switch(iCategory) {
        case OVA_LB_STABS_GIVEN: strcopy(sOrder, sizeof(sOrder), "`stabs_given` DESC, `total_time` DESC");
        case OVA_LB_STABS_TAKEN: strcopy(sOrder, sizeof(sOrder), "`stabs_taken` DESC, `total_time` DESC");
        default:                 strcopy(sOrder, sizeof(sOrder), "`total_time` DESC, `rounds` DESC");
    }

    char sQuery[512];
    FormatEx(sQuery, sizeof(sQuery),
        "SELECT `name`, `total_time`, `stabs_given`, `stabs_taken`, `rounds` \
        FROM `ova_stats` ORDER BY %s LIMIT %d OFFSET %d", sOrder, iPerPage + 1, iOffset);

    g_hOvaDb.Query(SqlCallback_OvaLeaderboard, sQuery, OvaLbPack(GetClientUserId(iClient), iCategory, iPage));
}

public void SqlCallback_OvaLeaderboard(Database hDb, DBResultSet hResults, const char[] sError, any data)
{
    int iUserId = data & 0xFFFF;
    int iCategory = (data >> 16) & 0xF;
    int iPage = (data >> 20) & 0xFF;

    int iClient = GetClientOfUserId(iUserId);
    if(iClient < 1 || !IsClientInGame(iClient))
        return;

    if(hResults == null) {
        LogError("[OVA] Leaderboard query failed: %s", sError);
        PrintToChat(iClient, " \x04[OVA]\x01 Leaderboard query failed.");
        return;
    }

    // Same shape as hnsmix: rows go to chat where they can be scrolled back, the menu is the on-screen copy.
    int iPerPage = g_hOvaDiscordLbEntries.IntValue;
    int iOffset = iPage * iPerPage;

    Menu hMenu = new Menu(OvaLeaderboardHandler);
    char sTitle[96];
    FormatEx(sTitle, sizeof(sTitle), "[OVA] %s - Page %d", g_saOvaLbTitles[iCategory], iPage + 1);
    hMenu.SetTitle(sTitle);

    PrintToChat(iClient, " \x04[OVA]\x01 \x04%s\x01 - Page %d", g_saOvaLbTitles[iCategory], iPage + 1);

    int iRow = 0;
    bool bMore = false;
    char sName[64], sLine[192], sTotal[16];

    while(hResults.FetchRow()) {
        iRow++;
        // The extra row is only a lookahead, never displayed.
        if(iRow > iPerPage) {
            bMore = true;
            break;
        }

        hResults.FetchString(0, sName, sizeof(sName));
        OvaFormatTime(float(hResults.FetchInt(1)), sTotal, sizeof(sTotal));
        int iGiven = hResults.FetchInt(2);
        int iTaken = hResults.FetchInt(3);
        int iRounds = hResults.FetchInt(4);
        int iRank = iOffset + iRow;

        switch(iCategory) {
            case OVA_LB_STABS_GIVEN: {
                FormatEx(sLine, sizeof(sLine), "#%d %s - %d given (%d rounds)", iRank, sName, iGiven, iRounds);
                PrintToChat(iClient, " \x04[OVA]\x01 \x04#%d\x01 %s \x02%d\x01 stabs given \x01(%d rounds)", iRank, sName, iGiven, iRounds);
            }
            case OVA_LB_STABS_TAKEN: {
                FormatEx(sLine, sizeof(sLine), "#%d %s - %d taken (%d rounds)", iRank, sName, iTaken, iRounds);
                PrintToChat(iClient, " \x04[OVA]\x01 \x04#%d\x01 %s \x02%d\x01 stabs taken \x01(%d rounds)", iRank, sName, iTaken, iRounds);
            }
            default: {
                FormatEx(sLine, sizeof(sLine), "#%d %s - %s (%d rounds)", iRank, sName, sTotal, iRounds);
                PrintToChat(iClient, " \x04[OVA]\x01 \x04#%d\x01 %s \x02%s\x01 as T \x01(%d rounds)", iRank, sName, sTotal, iRounds);
            }
        }

        hMenu.AddItem("", sLine, ITEMDRAW_DISABLED);
    }

    if(iRow == 0) {
        hMenu.AddItem("", "No results recorded yet.", ITEMDRAW_DISABLED);
        PrintToChat(iClient, " \x04[OVA]\x01 No results recorded yet.");
    }

    // Pager. Info strings carry the destination so the handler stays stateless.
    char sInfo[16];
    if(iPage > 0) {
        FormatEx(sInfo, sizeof(sInfo), "p:%d:%d", iCategory, iPage - 1);
        hMenu.AddItem(sInfo, "Previous page");
    }
    if(bMore) {
        FormatEx(sInfo, sizeof(sInfo), "p:%d:%d", iCategory, iPage + 1);
        hMenu.AddItem(sInfo, "Next page");
    }
    hMenu.AddItem("back", "Back to categories");

    hMenu.ExitButton = true;
    hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int OvaLeaderboardHandler(Menu hMenu, MenuAction action, int iClient, int iItem)
{
    if(action == MenuAction_End) {
        delete hMenu;
        return 0;
    }
    if(action != MenuAction_Select || !IsClientInGame(iClient))
        return 0;

    char sInfo[16];
    hMenu.GetItem(iItem, sInfo, sizeof(sInfo));

    if(StrEqual(sInfo, "back")) {
        OvaLbCategoryMenu(iClient);
        return 0;
    }

    if(strncmp(sInfo, "p:", 2) == 0) {
        char sParts[3][8];
        if(ExplodeString(sInfo, ":", sParts, sizeof(sParts), sizeof(sParts[])) == 3)
            OvaLbQuery(iClient, StringToInt(sParts[1]), StringToInt(sParts[2]));
    }

    return 0;
}

// ------------------------------------------------------------- stat resets
// Irreversible, so both commands are ROOT and the server-wide form needs an explicit confirm
// word. The usage line prints the exact string, since a prompt that does not match is worse than none.

#define OVA_RESET_ALL_COLUMNS "`total_time` = 0, `best_stint` = 0, `t_stints` = 0, `stabs_given` = 0, `stabs_taken` = 0, `rounds` = 0"

// The engine tokenizer splits an unquoted STEAM_1:0:X on its colons, so GetCmdArg would hand
// back STEAM_1 and never match a row. Args are re-split from the raw string on whitespace.
int OvaSplitRawArgs(char[][] sOut, int iMaxArgs, int iMaxLen)
{
    char sRaw[256];
    GetCmdArgString(sRaw, sizeof(sRaw));
    TrimString(sRaw);

    if(!sRaw[0])
        return 0;

    return ExplodeString(sRaw, " ", sOut, iMaxArgs, iMaxLen);
}

// CS:GO reports STEAM_1 but admin tools and profile scrapers commonly hand out STEAM_0.
// Rewriting the universe digit stops a valid-looking id silently matching nothing.
void OvaNormalizeSteamId(char[] sAuth)
{
    if(strncmp(sAuth, "STEAM_", 6, false) == 0 && sAuth[6] != '\0' && sAuth[7] == ':')
        sAuth[6] = '1';
}

bool OvaIsConfirm(const char[] sArg)
{
    return StrEqual(sArg, "confirm", false);
}

// Accepts all, an online player, or a literal STEAM_ id so offline players can be cleared too.
bool OvaResolveResetTarget(int iAdmin, const char[] sArg, char[] sAuthOut, int iAuthLen, char[] sNameOut, int iNameLen, bool &bEveryone)
{
    bEveryone = StrEqual(sArg, "all", false);
    if(bEveryone) {
        sAuthOut[0] = '\0';
        strcopy(sNameOut, iNameLen, "everyone");
        return true;
    }

    // Offline players are reachable by id alone; nothing here needs them connected.
    if(strncmp(sArg, "STEAM_", 6, false) == 0) {
        strcopy(sAuthOut, iAuthLen, sArg);
        OvaNormalizeSteamId(sAuthOut);
        strcopy(sNameOut, iNameLen, sAuthOut);
        return true;
    }

    int iTarget = FindTarget(iAdmin, sArg, true, false);
    if(iTarget < 1)
        return false; // FindTarget already explained why

    if(!GetClientAuthId(iTarget, AuthId_Steam2, sAuthOut, iAuthLen)) {
        ReplyToCommand(iAdmin, "[OVA] Could not read that player's SteamID.");
        return false;
    }

    GetClientName(iTarget, sNameOut, iNameLen);

    // Their live round tally is dropped too, or it would be written back at round end and undo the reset.
    OvaResetClient(iTarget);
    return true;
}

void OvaRunReset(int iAdmin, const char[] sAuth, const char[] sName, bool bEveryone, const char[] sColumns, const char[] sWhat)
{
    if(g_hOvaDb == null) {
        ReplyToCommand(iAdmin, "[OVA] No database connection.");
        return;
    }

    char sQuery[512];
    if(bEveryone) {
        // Every online player's live tally goes as well, same reason.
        for(int iClient = 1; iClient <= MaxClients; iClient++) {
            if(IsClientInGame(iClient))
                OvaResetClient(iClient);
        }
        FormatEx(sQuery, sizeof(sQuery), "UPDATE `ova_stats` SET %s", sColumns);
    }
    else {
        char sSafe[80];
        g_hOvaDb.Escape(sAuth, sSafe, sizeof(sSafe));
        FormatEx(sQuery, sizeof(sQuery), "UPDATE `ova_stats` SET %s WHERE `steamid` = '%s'", sColumns, sSafe);
    }

    g_hOvaDb.Query(SqlCallback_OvaGeneric, sQuery);

    LogAction(iAdmin, -1, "[OVA] reset %s for %s", sWhat, sName);
    ReplyToCommand(iAdmin, "[OVA] Reset %s for %s.", sWhat, sName);
}

public Action Command_OvaReset(int iClient, int iArgs)
{
    char sArgs[3][80];
    int iCount = OvaSplitRawArgs(sArgs, sizeof(sArgs), sizeof(sArgs[]));

    if(iCount < 1) {
        ReplyToCommand(iClient, "[OVA] Usage: sm_ovareset <player|STEAM_ID|all>");
        ReplyToCommand(iClient, "[OVA] Wipes survival time, best stint, stabs given, stabs taken and rounds.");
        ReplyToCommand(iClient, "[OVA] Works on offline players by SteamID. Server-wide: sm_ovareset all confirm");
        ReplyToCommand(iClient, "[OVA] To clear one stat only, use sm_ovaresetstat.");
        return Plugin_Handled;
    }

    char sAuth[64], sName[MAX_NAME_LENGTH];
    bool bEveryone;
    if(!OvaResolveResetTarget(iClient, sArgs[0], sAuth, sizeof(sAuth), sName, sizeof(sName), bEveryone))
        return Plugin_Handled;

    if(bEveryone && (iCount < 2 || !OvaIsConfirm(sArgs[1]))) {
        ReplyToCommand(iClient, "[OVA] This wipes EVERY player's OVA stats and cannot be undone.");
        ReplyToCommand(iClient, "[OVA] Type: sm_ovareset all confirm");
        return Plugin_Handled;
    }

    OvaRunReset(iClient, sAuth, sName, bEveryone, OVA_RESET_ALL_COLUMNS, "all stats");
    return Plugin_Handled;
}

public Action Command_OvaResetStat(int iClient, int iArgs)
{
    char sArgs[4][80];
    int iCount = OvaSplitRawArgs(sArgs, sizeof(sArgs), sizeof(sArgs[]));

    if(iCount < 2) {
        ReplyToCommand(iClient, "[OVA] Usage: sm_ovaresetstat <player|STEAM_ID|all> <stat>");
        ReplyToCommand(iClient, "  time    - survival time and T-stint count");
        ReplyToCommand(iClient, "  given   - stabs given");
        ReplyToCommand(iClient, "  taken   - stabs taken");
        ReplyToCommand(iClient, "  rounds  - rounds played");
        ReplyToCommand(iClient, "[OVA] Works on offline players by SteamID. Server-wide: sm_ovaresetstat all <stat> confirm");
        ReplyToCommand(iClient, "[OVA] To clear everything at once, use sm_ovareset instead.");
        return Plugin_Handled;
    }

    char sColumns[160], sWhat[32];
    char sStat[16];
    strcopy(sStat, sizeof(sStat), sArgs[1]);

    if(StrEqual(sStat, "time", false) || StrEqual(sStat, "survival", false)) {
        // Stint count goes with it: rounds held as T with no time held reads as corrupt.
        strcopy(sColumns, sizeof(sColumns), "`total_time` = 0, `best_stint` = 0, `t_stints` = 0");
        strcopy(sWhat, sizeof(sWhat), "survival time");
    }
    else if(StrEqual(sStat, "given", false)) {
        strcopy(sColumns, sizeof(sColumns), "`stabs_given` = 0");
        strcopy(sWhat, sizeof(sWhat), "stabs given");
    }
    else if(StrEqual(sStat, "taken", false)) {
        strcopy(sColumns, sizeof(sColumns), "`stabs_taken` = 0");
        strcopy(sWhat, sizeof(sWhat), "stabs taken");
    }
    else if(StrEqual(sStat, "rounds", false)) {
        strcopy(sColumns, sizeof(sColumns), "`rounds` = 0");
        strcopy(sWhat, sizeof(sWhat), "rounds played");
    }
    else {
        ReplyToCommand(iClient, "[OVA] Unknown stat '%s'. Valid: time, given, taken, rounds.", sStat);
        return Plugin_Handled;
    }

    char sAuth[64], sName[MAX_NAME_LENGTH];
    bool bEveryone;
    if(!OvaResolveResetTarget(iClient, sArgs[0], sAuth, sizeof(sAuth), sName, sizeof(sName), bEveryone))
        return Plugin_Handled;

    if(bEveryone && (iCount < 3 || !OvaIsConfirm(sArgs[2]))) {
        ReplyToCommand(iClient, "[OVA] This resets %s for EVERY player and cannot be undone.", sWhat);
        ReplyToCommand(iClient, "[OVA] Type: sm_ovaresetstat all %s confirm", sStat);
        return Plugin_Handled;
    }

    OvaRunReset(iClient, sAuth, sName, bEveryone, sColumns, sWhat);
    return Plugin_Handled;
}

// ------------------------------------------------------- discord leaderboard
// One embed, three categories side by side, plus rounds played. Unlike hnsmix there is no
// ELO and no per-category embed: everything lands in a single post.

public Action Command_OvaTopDiscord(int iClient, int iArgs)
{
    char sWebhook[256];
    g_hOvaDiscordLbWebhook.GetString(sWebhook, sizeof(sWebhook));
    if(!sWebhook[0]) {
        ReplyToCommand(iClient, "[OVA] ova_discord_lb_webhook is not set.");
        return Plugin_Handled;
    }
    if(GetFeatureStatus(FeatureType_Native, "HTTPRequest.HTTPRequest") != FeatureStatus_Available) {
        ReplyToCommand(iClient, "[OVA] REST in Pawn is not loaded.");
        return Plugin_Handled;
    }
    if(g_hOvaDb == null) {
        ReplyToCommand(iClient, "[OVA] No database connection.");
        return Plugin_Handled;
    }

    // One ranking, not three: every stat a player has sits under their name, like the mix leaderboard.
    char sQuery[512];
    FormatEx(sQuery, sizeof(sQuery),
        "SELECT `name`, `total_time`, `stabs_given`, `stabs_taken`, `rounds` \
        FROM `ova_stats` ORDER BY `total_time` DESC, `stabs_given` DESC LIMIT %d",
        g_hOvaDiscordLbEntries.IntValue);
    g_hOvaDb.Query(SqlCallback_OvaTopDiscord, sQuery, (iClient > 0) ? GetClientUserId(iClient) : 0);

    ReplyToCommand(iClient, "[OVA] Leaderboard sent to Discord.");
    return Plugin_Handled;
}

// hnsmix's duration style: "1h 45m", "35m 49s", "14s".
void FormatOvaDuration(int iSeconds, char[] sOut, int iMaxLen)
{
    int h = iSeconds / 3600;
    int m = (iSeconds % 3600) / 60;
    int s = iSeconds % 60;

    if(h > 0)
        FormatEx(sOut, iMaxLen, "%dh %dm", h, m);
    else if(m > 0)
        FormatEx(sOut, iMaxLen, "%dm %ds", m, s);
    else
        FormatEx(sOut, iMaxLen, "%ds", s);
}

public void SqlCallback_OvaTopDiscord(Database hDb, DBResultSet hResults, const char[] sError, any data)
{
    int iClient = GetClientOfUserId(data);

    if(hResults == null) {
        LogError("[OVA] Discord leaderboard query failed: %s", sError);
        if(iClient > 0 && IsClientInGame(iClient))
            PrintToChat(iClient, " \x04[OVA]\x01 Leaderboard query failed, nothing was posted.");
        return;
    }

    // First half of the entries in the left column, the rest in the right, so it reads as two aligned blocks.
    int iSplit = (g_hOvaDiscordLbEntries.IntValue + 1) / 2;
    char sColA[1024], sColB[1024];
    sColA[0] = '\0';
    sColB[0] = '\0';

    int iRank = 0;
    char sName[64], sDuration[24], sEntry[320];

    while(hResults.FetchRow()) {
        iRank++;
        hResults.FetchString(0, sName, sizeof(sName));
        FormatOvaDuration(hResults.FetchInt(1), sDuration, sizeof(sDuration));
        int iGiven = hResults.FetchInt(2);
        int iTaken = hResults.FetchInt(3);
        int iRounds = hResults.FetchInt(4);

        FormatEx(sEntry, sizeof(sEntry),
            "`#%d` **%s**\n\xE2\x80\xA2 %s s/t \xC2\xB7 %d rounds\n\xE2\x80\xA2 %d stabs taken \xC2\xB7 %d stabs given\n\n",
            iRank, sName, sDuration, iRounds, iTaken, iGiven);

        // Discord caps a field value at 1024 characters.
        if(iRank <= iSplit) {
            if(strlen(sColA) + strlen(sEntry) < sizeof(sColA) - 1)
                StrCat(sColA, sizeof(sColA), sEntry);
        }
        else {
            if(strlen(sColB) + strlen(sEntry) < sizeof(sColB) - 1)
                StrCat(sColB, sizeof(sColB), sEntry);
        }
    }

    if(iRank == 0) {
        if(iClient > 0 && IsClientInGame(iClient))
            PrintToChat(iClient, " \x04[OVA]\x01 No ranked players yet, nothing was posted.");
        return;
    }

    OvaPostDiscordLeaderboard(sColA, sColB, iRank, iSplit);
}

void OvaPostDiscordLeaderboard(const char[] sColA, const char[] sColB, int iRows, int iSplit)
{
    char sWebhook[256], sPrefix[64], sBotName[64], sTitle[128];
    g_hOvaDiscordLbWebhook.GetString(sWebhook, sizeof(sWebhook));
    g_hOvaDiscordPrefix.GetString(sPrefix, sizeof(sPrefix));
    g_hOvaDiscordName.GetString(sBotName, sizeof(sBotName));
    if(!sWebhook[0])
        return;

    FormatEx(sTitle, sizeof(sTitle), "\xF0\x9F\x94\xAA %s OVA - Leaderboard (Top %d)", sPrefix, iRows);

    // Two inline fields give the side-by-side columns, named the same way the mix leaderboard does.
    char sColAName[32], sColBName[32];
    FormatEx(sColAName, sizeof(sColAName), "Ranks 1-%d", (iRows < iSplit) ? iRows : iSplit);
    FormatEx(sColBName, sizeof(sColBName), "Ranks %d-%d", iSplit + 1, iRows);

    JSONArray hFields = new JSONArray();

    JSONObject hFieldA = new JSONObject();
    hFieldA.SetString("name", sColAName);
    hFieldA.SetString("value", sColA);
    hFieldA.SetBool("inline", true);
    hFields.Push(hFieldA);
    delete hFieldA;

    if(sColB[0] != '\0') {
        JSONObject hFieldB = new JSONObject();
        hFieldB.SetString("name", sColBName);
        hFieldB.SetString("value", sColB);
        hFieldB.SetBool("inline", true);
        hFields.Push(hFieldB);
        delete hFieldB;
    }

    char sFooter[128], sStamp[64];
    FormatTime(sStamp, sizeof(sStamp), "%Y-%m-%d | Time: %H:%M:%S (UTC)", GetTime());
    FormatEx(sFooter, sizeof(sFooter), "Updated: %s", sStamp);

    JSONObject hFooter = new JSONObject();
    hFooter.SetString("text", sFooter);

    JSONObject hEmbed = new JSONObject();
    hEmbed.SetString("title", sTitle);
    hEmbed.SetInt("color", g_hOvaDiscordLbColor.IntValue);
    hEmbed.Set("fields", hFields);
    hEmbed.Set("footer", hFooter);

    JSONArray hEmbeds = new JSONArray();
    hEmbeds.Push(hEmbed);

    JSONObject hPayload = new JSONObject();
    hPayload.Set("embeds", hEmbeds);
    if(sBotName[0])
        hPayload.SetString("username", sBotName);

    HTTPRequest hRequest = new HTTPRequest(sWebhook);
    hRequest.Post(hPayload, OnOvaDiscordPosted);

    // ripext Set/Push do not take ownership, so everything created here is deleted here.
    delete hPayload;
    delete hEmbeds;
    delete hEmbed;
    delete hFooter;
    delete hFields;
}

public void OnOvaDiscordPosted(HTTPResponse hResponse, any value, const char[] sError)
{
    if(sError[0] != '\0')
        LogError("[OVA] Discord leaderboard post failed: %s", sError);
}

// --------------------------------------------------------------- votes

public Action Command_VoteOva(int iClient, int iArgs)
{
    return OvaStartVote(iClient, true);
}

public Action Command_VoteHns(int iClient, int iArgs)
{
    return OvaStartVote(iClient, false);
}

Action OvaStartVote(int iClient, bool bWantOva)
{
    if(iClient == 0) {
        ReplyToCommand(iClient, "[OVA] This command must be used in-game.");
        return Plugin_Handled;
    }
    if(!g_bEnabled) {
        PrintToChat(iClient, " \x04[OVA]\x01 The mod is disabled.");
        return Plugin_Handled;
    }
    if(bWantOva == g_bOvaActive) {
        PrintToChat(iClient, " \x04[OVA]\x01 That gamemode is already running.");
        return Plugin_Handled;
    }
    if(OvaMixRunning()) {
        PrintToChat(iClient, " \x04[OVA]\x01 A mix is running, the gamemode cannot be changed now.");
        return Plugin_Handled;
    }
    // Same reason as a mix: switching mode restarts the round, cutting an FJ session's clock off partway.
    if(FJRunning()) {
        PrintToChat(iClient, " \x04[OVA]\x01 Funjump is running, the gamemode cannot be changed now.");
        return Plugin_Handled;
    }
    if(g_bOvaVotedThisMap) {
        PrintToChat(iClient, " \x04[OVA]\x01 A gamemode vote has already been held on this map.");
        return Plugin_Handled;
    }
    if(IsVoteInProgress()) {
        PrintToChat(iClient, " \x04[OVA]\x01 A vote is already running.");
        return Plugin_Handled;
    }

    g_bOvaVoteWantsOva = bWantOva;

    Menu hMenu = new Menu(OvaVoteHandler, MenuAction_End|MenuAction_VoteEnd|MenuAction_VoteCancel);
    hMenu.SetTitle(bWantOva ? "Switch to One Versus All?" : "Switch back to Hide N Seek?");
    hMenu.AddItem("y", "Yes");
    hMenu.AddItem("n", "No");
    hMenu.ExitButton = false;
    hMenu.DisplayVoteToAll(20);

    PrintToChatAll(" \x04[OVA]\x01 \x04%N\x01 started a vote to switch to \x04%s\x01.", iClient, bWantOva ? "OVA" : "HNS");
    return Plugin_Handled;
}

public int OvaVoteHandler(Menu hMenu, MenuAction action, int iParam1, int iParam2)
{
    switch(action) {
        case MenuAction_End: delete hMenu;

        case MenuAction_VoteCancel: {
            if(iParam1 == VoteCancel_NoVotes)
                PrintToChatAll(" \x04[OVA]\x01 Nobody voted, the gamemode stays.");
        }

        case MenuAction_VoteEnd: {
            int iVotes, iTotal;
            GetMenuVoteInfo(iParam2, iVotes, iTotal);
            if(iParam1 == 1)
                iVotes = iTotal - iVotes;

            // Strict majority of everyone in game, so ignoring the menu is a no.
            int iPlayers = OvaCountPlayers();
            if(iPlayers < 1)
                iPlayers = 1;
            int iNeeded = (iPlayers / 2) + 1;

            g_bOvaVotedThisMap = true;

            // Re-checked when the vote lands, not just when it started: a mix or FJ can begin while the menu is open.
            if(iVotes >= iNeeded && !OvaMixRunning() && !FJRunning()) {
                char sReason[48];
                FormatEx(sReason, sizeof(sReason), "vote passed %d/%d", iVotes, iPlayers);
                OvaSetMode(g_bOvaVoteWantsOva, sReason);
            }
            else {
                PrintToChatAll(" \x04[OVA]\x01 Vote failed: \x04%d\x01 of %d voted yes, \x04%d\x01 needed.", iVotes, iPlayers, iNeeded);
            }
        }
    }
    return 0;
}

// ---------------------------------------------------------------- admin menu

// /ova is the entry point people remember, so it does what each side expects: the toggle menu
// for admins, the command list for everyone else. !ovahelp always gives the list.
public Action Command_Ova(int iClient, int iArgs)
{
    if(iClient > 0 && CheckCommandAccess(iClient, "sm_ovamenu", ADMFLAG_GENERIC, false))
        return Command_OvaMenu(iClient, iArgs);

    return Command_OvaHelp(iClient, iArgs);
}

// Everyone sees the whole list. Admin-only entries are tagged rather than hidden, so players know who to ask.
public Action Command_OvaHelp(int iClient, int iArgs)
{
    if(iClient == 0) {
        ReplyToCommand(iClient, "[OVA] This command must be used in-game.");
        return Plugin_Handled;
    }

    PrintToChat(iClient, " \x04[OVA]\x01 Gamemode right now: \x04%s\x01", g_bOvaActive ? "One Versus All" : "Hide N Seek");
    PrintToChat(iClient, " \x04[OVA]\x01 Commands (\x04!ovahelp\x01 or \x04!helpova\x01 to see this again):");
    PrintToChat(iClient, "  \x04!ovalb\x01 - leaderboard (also \x04!lbova\x01, \x04!leaderboardova\x01, \x04!ovaleaderboard\x01)");
    PrintToChat(iClient, "  \x04!voteova\x01 - vote to switch to One Versus All for this map");
    PrintToChat(iClient, "  \x04!votehns\x01 - vote to switch to Hide N Seek for this map");
    PrintToChat(iClient, "  \x04!ovamenu\x01 - force the gamemode, also \x04!ova\x01 \x02(ADMIN)\x01");
    PrintToChat(iClient, "  \x04!ovatopdiscord\x01 - post the leaderboard to Discord \x02(ADMIN)\x01");
    PrintToChat(iClient, "  \x04!ovareset\x01 - wipe all stats for a player or everyone \x02(ADMIN)\x01");
    PrintToChat(iClient, "  \x04!ovaresetstat\x01 - reset one stat for a player or everyone \x02(ADMIN)\x01");

    return Plugin_Handled;
}

public Action Command_OvaMenu(int iClient, int iArgs)
{
    if(iClient == 0) {
        ReplyToCommand(iClient, "[OVA] This command must be used in-game.");
        return Plugin_Handled;
    }

    Menu hMenu = new Menu(OvaAdminHandler);
    hMenu.SetTitle("Gamemode");
    hMenu.AddItem("hns", "Hide N Seek", g_bOvaActive ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    hMenu.AddItem("ova", "One Versus All", g_bOvaActive ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    hMenu.ExitButton = true;
    hMenu.Display(iClient, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int OvaAdminHandler(Menu hMenu, MenuAction action, int iClient, int iItem)
{
    if(action == MenuAction_End) {
        delete hMenu;
        return 0;
    }
    if(action != MenuAction_Select)
        return 0;

    char sInfo[8];
    hMenu.GetItem(iItem, sInfo, sizeof(sInfo));

    if(OvaMixRunning()) {
        PrintToChat(iClient, " \x04[OVA]\x01 A mix is running, the gamemode cannot be changed now.");
        return 0;
    }

    OvaSetMode(StrEqual(sInfo, "ova"), "admin");
    return 0;
}

// ------------------------------------------------- discord embed seams
// No embed code here. hnsmix owns the status embed and picks its color at
// RefreshMixStatusEmbed; these two let it show the running gamemode without hidenseek
// knowing anything about Discord.

// OvaActive(), not g_bOvaActive: callers are asking whether OVA owns the round right now, and
// a mix owns it from the instant it exists, a second before the watcher flips the flag. In
// that second hnsmix skipped its own m_iRoundTime pin, so a knife round could start on
// OVA's ten minute clock instead of five.
public int Native_HNS_IsOvaActive(Handle plugin, int numParams)
{
    return OvaActive() ? 1 : 0;
}

public int Native_HNS_GetGameModeColor(Handle plugin, int numParams)
{
    return OvaActive() ? OVA_EMBED_COLOR : HNS_EMBED_COLOR;
}
