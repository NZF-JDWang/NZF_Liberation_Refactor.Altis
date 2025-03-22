/*
    File: fn_cleanOpforVehicle.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2019-11-25
    Last Update: 2024-10-15
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Deletes given vehicle, if not an opfor vehicle captured by players.

    Parameter(s):
        _veh - Vehicle to delete if not captured [OBJECT, defaults to objNull]

    Returns:
        Function reached the end [BOOL]
*/

params [
    ["_veh", objNull, [objNull]]
];

if (isNull _veh) exitWith {["Null object given"] call BIS_fnc_error; false};

// Add debug logging
private _captured = _veh getVariable ["KPLIB_captured", false];
private _type = typeOf _veh;
private _pos = getPosASL _veh;
private _sectorOrigin = _veh getVariable ["KPLIB_sectorOrigin", "unknown"];
private _vehInfo = format ["Vehicle: %1 (Type: %2) at position %3 from sector %4", _veh, _type, _pos, _sectorOrigin];

if !(_captured) then {
    diag_log format ["[KPLIB] Deleting %1", _vehInfo];
    deleteVehicle _veh;
} else {
    diag_log format ["[KPLIB] NOT deleting %1 - marked as captured", _vehInfo];
};

true
