/*
    File: fn_spawnRegularSquad.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2019-12-03
    Last Update: 2020-05-06
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Spawns a regular enemy squad with given soldier classnames at given sector.
        Uses staggered spawning via CBA to reduce lag spikes.

    Parameter(s):
        _sector     - Sector to spawn the squad at          [STRING, defaults to ""]
        _classnames - Classnames of units to spawn in squad [ARRAY, defaults to []]

    Returns:
        Created squad [GROUP]
*/

params [
    ["_sector", "", [""]],
    ["_classnames", [], [[]]]
];

if (_sector isEqualTo "") exitWith {["Empty string given"] call BIS_fnc_error; grpNull};

// Get spawn position for squad
private _sectorPos = (markerPos _sector) getPos [random 100, random 360];
private _spawnPos = [];
private _i = 0;
while {_spawnPos isEqualTo []} do {
    _i = _i + 1;
    _spawnPos = (_sectorPos getPos [random 50, random 360]) findEmptyPosition [5, 100, "B_Heli_Light_01_F"];
    if (_i isEqualTo 10) exitWith {};
};

if (_spawnPos isEqualTo zeroPos) exitWith {
    ["No suitable spawn position found."] call BIS_fnc_error;
    [format ["Couldn't find infantry spawn position for sector %1", _sector], "WARNING"] call KPLIB_fnc_log;
    grpNull
};

// Calculate corrected amount based on opfor factor
private _corrected_amount = round ((count _classnames) * ([] call KPLIB_fnc_getOpforFactor));
private _grp = createGroup [GRLIB_side_enemy, true];

// Recursive function to spawn units with staggered delay
private _fnc_spawnNextUnit = {
    params ["_args", "_handle"];
    _args params ["_classnames", "_spawnPos", "_grp", "_currentIndex", "_maxIndex"];
    
    // Exit if all units spawned or group no longer exists
    if (_currentIndex >= _maxIndex || isNull _grp) exitWith {
        [_handle] call CBA_fnc_removePerFrameHandler;
    };
    
    // Get next classname to spawn
    private _classname = _classnames select _currentIndex;
    
    // Spawn the unit
    [_classname, _spawnPos, _grp] call KPLIB_fnc_createManagedUnit;
    
    // Update index for next unit
    _args set [3, _currentIndex + 1];
};

// Start the staggered spawning process - one unit every 0.05 seconds
[
    _fnc_spawnNextUnit,
    0.05,
    [_classnames, _spawnPos, _grp, 0, _corrected_amount]
] call CBA_fnc_addPerFrameHandler;

_grp
