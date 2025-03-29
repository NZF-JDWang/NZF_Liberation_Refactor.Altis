/*
    Function: KPLIB_fnc_spawnMilitiaCrew
    
    Description:
        Spawns a crew for given vehicle with optimized crew assignment.
    
    Parameters:
        _vehicle - Vehicle to spawn the crew for [OBJECT, defaults to objNull]
        _forceRiflemen - Force using custom unit type for crew [BOOL, defaults to false]
        _unitType - Custom unit type to use [STRING, defaults to opfor_rifleman]
    
    Returns:
        Function reached the end [BOOL]
    
    Examples:
        (begin example)
        [_vehicle] call KPLIB_fnc_spawnMilitiaCrew;
        [_vehicle, true, "O_Soldier_F"] call KPLIB_fnc_spawnMilitiaCrew;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-11-16
*/

params [
    ["_vehicle", objNull, [objNull]],
    ["_forceRiflemen", false, [false]],
    ["_specificType", "", [""]]
];

if (isNull _vehicle) exitWith {["Null object given"] call BIS_fnc_error; false};

// Get the least loaded headless client for spawning
private _hc = [] call KPLIB_fnc_getLessLoadedHC;
private _owner = if (isNull _hc) then {2} else {owner _hc};

// Remote execution of crew creation and assignment
[_vehicle, _forceRiflemen, _specificType] remoteExecCall ["KPLIB_fnc_spawnMilitiaCrewRemote", _owner];

true
