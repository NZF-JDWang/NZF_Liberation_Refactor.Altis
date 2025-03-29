/*
    Function: KPLIB_fnc_spawnMilitiaCrewRemote
    
    Description:
        Remote execution function that creates a crew for a vehicle.
        This is designed to be called from fn_spawnMilitiaCrew.sqf.
    
    Parameters:
        _vehicle - Vehicle to spawn the crew for [OBJECT]
        _forceRiflemen - Force using custom unit type for crew [BOOL]
        _specificType - Custom unit type to use [STRING]
    
    Returns:
        Function reached the end [BOOL]
    
    Author: [NZF] JD Wang
    Date: 2024-11-16
*/

params [
    ["_vehicle", objNull, [objNull]],
    ["_forceRiflemen", false, [false]],
    ["_specificType", "", [""]]
];

if (isNull _vehicle) exitWith {
    diag_log format ["[KPLIB][ERROR] spawnMilitiaCrewRemote - Null vehicle object received"];
    false
};

// Log that we're executing on this machine only in debug mode
if (KP_liberation_debug) then {
    diag_log format ["[KPLIB][HC] Creating militia crew on machine ID %1", clientOwner];
};

// Spawn units - the group is created locally on whichever machine runs this function
private _grp = createGroup [GRLIB_side_enemy, true];

if (KP_liberation_debug) then {
    diag_log format ["[KPLIB][HC] Created group %1 locally on machine ID %2", _grp, clientOwner];
};

private _crew = [];

// Determine unit type to use
private _unitType = if (_forceRiflemen) then {
    if (_specificType != "") then {
        // Use the specific type provided
        _specificType
    } else {
        // Use standard rifleman from opfor preset
        opfor_rifleman
    };
} else {
    // Use random militia unit
    selectRandom militia_squad
};

// Create the crew members directly in the group
for "_i" from 1 to 3 do {
    private _unit = _grp createUnit [_unitType, getPos _vehicle, [], 5, "NONE"];
    _unit addMPEventHandler ["MPKilled", {_this spawn kill_manager}];
    [_unit] call KPLIB_fnc_addObjectInit;
    _crew pushBack _unit;
};

// Assign crew directly to vehicle positions
if (count _crew > 0) then {
    private _unit = _crew select 0;
    _unit assignAsDriver _vehicle;
    _unit moveInDriver _vehicle;
};

if (count _crew > 1) then {
    private _unit = _crew select 1;
    _unit assignAsGunner _vehicle;
    _unit moveInGunner _vehicle;
};

if (count _crew > 2) then {
    private _unit = _crew select 2;
    _unit assignAsCommander _vehicle;
    _unit moveInCommander _vehicle;
};

// Verify crew positions and assign to cargo if needed
{
    if (isNull objectParent _x) then {
        _x assignAsCargo _vehicle;
        _x moveInCargo _vehicle;
    };
} forEach _crew;

// Remove possible leftovers that couldn't be assigned anywhere
{
    if (isNull objectParent _x) then {
        deleteVehicle _x;
    };
} forEach _crew;

true 