/*
    Function: KPLIB_fnc_updatePlayerNamespace
    
    Description:
        Continuously tracks player state values (proximity to FOBs, start, etc.) 
        and updates variables in the player's namespace. Designed to be called 
        repeatedly by a Per Frame Handler.
    
    Parameters:
        None
    
    Returns:
        Nothing
    
    Examples:
        (begin example)
        [] call KPLIB_fnc_updatePlayerNamespace; 
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-04-03 // Updated during refactor
*/
#define GET_VAR(var,default) (missionNamespace getVariable [var, default])

// Variables are recalculated each call, so local scope is fine.
private _fobPos = [0, 0, 0];
private _fobDist = 99999;
private _fobName = "";
private _isNearArsenal = false;
private _isNearMobRespawn = false;
private _isNearStart = false;
private _nearProd = [];
private _nearSector = -1;

// FOB distance, name and position
if !(GET_VAR("GRLIB_all_fobs", []) isEqualTo []) then {
    _fobPos = [] call KPLIB_fnc_getNearestFob;
    _fobDist = player distance2d _fobPos;
    _fobName = ["", ["FOB", [_fobPos] call KPLIB_fnc_getFobName] joinString " "] select (_fobDist < GET_VAR("GRLIB_fob_range", 250)); // Add default for GRLIB_fob_range just in case
} else {
    _fobPos = [0, 0, 0];
    _fobDist = 99999;
    _fobName = "";
};
player setVariable ["KPLIB_fobDist", _fobDist];
player setVariable ["KPLIB_fobName", _fobName];
player setVariable ["KPLIB_fobPos", _fobPos];

// Direct access due to config, commander or admin
player setVariable [
    "KPLIB_hasDirectAccess", 
    (
        (getPlayerUID player) in GET_VAR("KP_liberation_commander_actions", []) 
        || {player isEqualTo ([] call KPLIB_fnc_getCommander)} 
        || {serverCommandAvailable "#kick"}
    )
];

// Outside of startbase "safezone"
// Ensure startbase exists before calculating distance
if (!isNil "startbase") then {
    private _distToStart = player distance2d startbase;
    diag_log format ["[KPLIB] [DIAGNOSTIC] startbase exists, distance: %1", _distToStart];
    player setVariable ["KPLIB_isAwayFromStart", _distToStart > 1000];
    // Is near startbase
    _isNearStart = _distToStart < 200;
    diag_log format ["[KPLIB] [DIAGNOSTIC] Setting KPLIB_isNearStart to %1", _isNearStart];
} else {
    diag_log "[KPLIB] [DIAGNOSTIC] startbase is nil! Cannot calculate distance.";
    player setVariable ["KPLIB_isAwayFromStart", true]; // Default to away if startbase doesn't exist
    _isNearStart = false; // Default to not near if startbase doesn't exist
};
player setVariable ["KPLIB_isNearStart", _isNearStart];

// Is near an arsenal object
if (GET_VAR("KP_liberation_mobilearsenal", false)) then {
    // Check nearObjects returns objects >= 8 (buildings/statics)
    _isNearArsenal = !(((player nearObjects [GET_VAR("Arsenal_typename", ""), 5]) select {getObjectType _x >= 8}) isEqualTo []);
};
player setVariable ["KPLIB_isNearArsenal", _isNearArsenal];


// Is near a mobile respawn
if (GET_VAR("KP_liberation_mobilerespawn", false)) then {
    _isNearMobRespawn = !((player nearEntities [[GET_VAR("Respawn_truck_typename", ""), GET_VAR("huron_typename", "")], 10]) isEqualTo []);
};
player setVariable ["KPLIB_isNearMobRespawn", _isNearMobRespawn];

// Nearest activated sector and possible production data
_nearSector = [GET_VAR("GRLIB_sector_size", 100)] call KPLIB_fnc_getNearestSector; // Add default for GRLIB_sector_size
_nearProd = GET_VAR("KP_liberation_production", []) param [GET_VAR("KP_liberation_production", []) findIf {(_x select 1) isEqualTo ([100] call KPLIB_fnc_getNearestSector)}, []]; // Fallback needed? This seems complex. Original logic kept.
player setVariable ["KPLIB_nearProd", _nearProd]; 
player setVariable ["KPLIB_nearSector", _nearSector];

// Zeus module synced to player
player setVariable ["KPLIB_ownedZeusModule", getAssignedCuratorLogic player];

// Update state in Discord rich presence (assuming this function handles nil player gracefully if needed)
[] call KPLIB_fnc_setDiscordState; 