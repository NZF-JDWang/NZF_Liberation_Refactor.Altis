/*
    File: fn_spawnMilitiaCrew.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2019-12-03
    Last Update: 2023-07-15
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Spawns a crew for given vehicle.

    Parameter(s):
        _vehicle - Vehicle to spawn the crew for [OBJECT, defaults to objNull]
        _forceRiflemen - Force using custom unit type for crew [BOOL, defaults to false]
        _unitType - Custom unit type to use [STRING, defaults to opfor_rifleman]

    Returns:
        Function reached the end [BOOL]
*/

params [
    ["_vehicle", objNull, [objNull]],
    ["_forceRiflemen", false, [false]],
    ["_specificType", "", [""]]
];

if (isNull _vehicle) exitWith {["Null object given"] call BIS_fnc_error; false};

// Spawn units
private _grp = createGroup [GRLIB_side_enemy, true];
private _units = [];

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

for "_i" from 1 to 3 do {
    _units pushBack ([_unitType, getPos _vehicle, _grp] call KPLIB_fnc_createManagedUnit);
};

// Assign to vehicle
(_units select 0) moveInDriver _vehicle;
(_units select 1) moveInGunner _vehicle;
(_units select 2) moveInCommander _vehicle;

// Remove possible leftovers
{
    if (isNull objectParent _x) then {
        deleteVehicle _x;
    };
} forEach _units;

true
