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
    Date: 2024-04-03
*/

#define GET_VAR(var,default) (missionNamespace getVariable [var, default])

// Only run on players
if (!hasInterface) exitWith {};

// Variables are recalculated each call, so local scope is fine.
private _fobPos = [0, 0, 0];
private _fobDist = 99999;
private _fobName = "";
private _isNearArsenal = false;
private _isNearMobRespawn = false;
private _isNearStart = false;
private _nearProd = [];
private _nearSector = "";

// FOB distance, name and position
if !(GET_VAR("GRLIB_all_fobs", []) isEqualTo []) then {
    _fobPos = [] call KPLIB_fnc_getNearestFob;
    _fobDist = player distance2d _fobPos;
    _fobName = ["", ["FOB", [_fobPos] call KPLIB_fnc_getFobName] joinString " "] select (_fobDist < GET_VAR("GRLIB_fob_range", 250));
} else {
    _fobPos = [0, 0, 0];
    _fobDist = 99999;
    _fobName = "";
};

// Update player variables
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
if (!isNil "startbase") then {
    _isNearStart = (player distance2d startbase) < 200;
    player setVariable ["KPLIB_isNearStart", _isNearStart];
} else {
    diag_log "[KPLIB] [WARNING] fn_updatePlayerNamespace - startbase is nil";
    player setVariable ["KPLIB_isNearStart", false];
};

// Arsenal proximity - handle both array and single object cases
private _arsenalObjects = GET_VAR("KP_liberation_arsenal", []);
if (_arsenalObjects isEqualType []) then {
    {
        if ((player distance2d _x) < 20) exitWith {_isNearArsenal = true;};
    } forEach _arsenalObjects;
} else {
    if (_arsenalObjects isEqualType objNull && {!isNull _arsenalObjects}) then {
        _isNearArsenal = (player distance2d _arsenalObjects) < 20;
    };
};
player setVariable ["KPLIB_isNearArsenal", _isNearArsenal];

// Mobile respawn proximity - handle both array and single object cases
private _mobileRespawnObjects = GET_VAR("KP_liberation_mobile_respawn", []);
if (_mobileRespawnObjects isEqualType []) then {
    {
        if ((player distance2d _x) < 20) exitWith {_isNearMobRespawn = true;};
    } forEach _mobileRespawnObjects;
} else {
    if (_mobileRespawnObjects isEqualType objNull && {!isNull _mobileRespawnObjects}) then {
        _isNearMobRespawn = (player distance2d _mobileRespawnObjects) < 20;
    };
};
player setVariable ["KPLIB_isNearMobRespawn", _isNearMobRespawn];

// Production site proximity
_nearProd = [];
private _productionSites = GET_VAR("KP_liberation_production", []);
if (_productionSites isEqualType []) then {
    {
        if (_x isEqualType objNull && {!isNull _x} && {(player distance2d _x) < 20}) then {
            _nearProd pushBack _x;
        };
    } forEach _productionSites;
};
player setVariable ["KPLIB_nearProd", _nearProd];

// Sector proximity
_nearSector = "";
private _allSectors = GET_VAR("sectors_allSectors", []);
if (_allSectors isEqualType []) then {
    {
        if (_x isEqualType "" && {(player distance2d (markerPos _x)) < 20}) exitWith {
            _nearSector = _x;
        };
    } forEach _allSectors;
};
player setVariable ["KPLIB_nearSector", _nearSector];

// Log state changes for debugging
if (GET_VAR("KP_liberation_debug", false)) then {
    diag_log format [
        "[KPLIB] [DIAGNOSTIC] Player state update - fobDist: %1, isNearStart: %2, hasDirectAccess: %3",
        _fobDist,
        _isNearStart,
        player getVariable ["KPLIB_hasDirectAccess", false]
    ];
};

// Zeus module synced to player
player setVariable ["KPLIB_ownedZeusModule", getAssignedCuratorLogic player];

// Update state in Discord rich presence
[] call KPLIB_fnc_setDiscordState; 