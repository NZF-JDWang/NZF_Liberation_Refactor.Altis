/*
    File: fn_spawnVehicle.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2019-12-03
    Last Update: 2023-10-15
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Spawns a vehicle with all needed Liberation connections/dependencies.
        Uses CBA functions to work in both scheduled and unscheduled environments.
        All event handlers use non-blocking CBA calls for better performance.

    Parameter(s):
        _pos        - Position to spawn the vehicle                                         [POSITION, defaults to [0, 0, 0]]
        _classname  - Classname of the vehicle to spawn                                     [STRING, defaults to ""]
        _precise    - Selector if the vehicle should spawned precisely on given position    [BOOL, defaults to false]
        _rndDir     - Selector if the direction should be randomized                        [BOOL, defaults to true]
        _callback   - Optional callback function to execute with vehicle as parameter       [CODE, defaults to {}]

    Returns:
        Spawned vehicle [OBJECT]
*/

params [
    ["_pos", [0, 0, 0], [[]], [2, 3]],
    ["_classname", "", [""]],
    ["_precise", false, [false]],
    ["_rndDir", true, [false]],
    ["_callback", {}, [{}]]
];

if (_pos isEqualTo [0, 0, 0]) exitWith {["No or zero pos given"] call BIS_fnc_error; objNull};
if (_classname isEqualTo "") exitWith {["Empty string given"] call BIS_fnc_error; objNull};

private _newvehicle = objNull;
private _spawnpos = [];

if (_precise) then {
    // Directly use given pos, if precise placement is true
    _spawnpos = _pos;
} else {
    // Otherwise find a suitable position for vehicle spawning near given pos
    private _i = 0;
    while {_spawnPos isEqualTo []} do {
        _i = _i + 1;
        _spawnpos = (_pos getPos [random 150, random 360]) findEmptyPosition [10, 100, _classname];
        if (_i isEqualTo 10) exitWith {};
    };
};

if (_spawnPos isEqualTo zeroPos) exitWith {
    ["No suitable spawn position found."] call BIS_fnc_error;
    [format ["Couldn't find spawn position for %1 around position %2", _classname, _pos], "WARNING"] call KPLIB_fnc_log;
    objNull
};

// If it's a chopper, spawn it flying
if (_classname in opfor_choppers) then {
    _newvehicle = createVehicle [_classname, _spawnpos, [], 0, 'FLY'];
    _newvehicle flyInHeight (80 + (random 120));
    _newvehicle allowDamage false;
    
    // Log chopper creation
    diag_log format ["[KPLIB] Spawned flying vehicle: %1 (Type: %2) at %3", _newvehicle, _classname, _spawnpos];

    // Create crew - use helicopter pilots
    [_newvehicle, true, opfor_heli_pilot] call KPLIB_fnc_spawnMilitiaCrew;

    // Mark crew members with reference to their parent vehicle
    {
        _x setVariable ["KPLIB_parentVehicle", _newvehicle, true];
        diag_log format ["[KPLIB] Crew member %1 (Type: %2) assigned to vehicle %3", _x, typeOf _x, _newvehicle];
    } forEach (crew _newvehicle);
} else {
    if (_classname in opfor_air) then {
        // This is a fixed-wing aircraft
        _newvehicle = createVehicle [_classname, _spawnpos, [], 0, 'FLY'];
        _newvehicle flyInHeight (300 + (random 200));
        _newvehicle allowDamage false;
        
        // Log jet creation
        diag_log format ["[KPLIB] Spawned jet: %1 (Type: %2) at %3", _newvehicle, _classname, _spawnpos];
        
        // Create crew - use jet pilots
        [_newvehicle, true, opfor_jet_pilot] call KPLIB_fnc_spawnMilitiaCrew;
        
        // Mark crew members with reference to their parent vehicle
        {
            _x setVariable ["KPLIB_parentVehicle", _newvehicle, true];
            diag_log format ["[KPLIB] Crew member %1 (Type: %2) assigned to vehicle %3", _x, typeOf _x, _newvehicle];
        } forEach (crew _newvehicle);
    } else {
        _newvehicle = _classname createVehicle _spawnpos;
        _newvehicle allowDamage false;

        [_newvehicle] call KPLIB_fnc_allowCrewInImmobile;
        
        // Log ground vehicle creation
        diag_log format ["[KPLIB] Spawned ground vehicle: %1 (Type: %2) at %3", _newvehicle, _classname, _spawnpos];

        // Randomize direction and reset position and vector
        if (_rndDir) then {
            _newvehicle setDir (random 360);
        };
        _newvehicle setPos _spawnpos;
        _newvehicle setVectorUp surfaceNormal position _newvehicle;

        // Mark vehicle for proper crew assignment later
        // (Crew will be created after all vehicle initialization)
        
        // Mark any existing crew members with reference to their parent vehicle
        {
            _x setVariable ["KPLIB_parentVehicle", _newvehicle, true];
            diag_log format ["[KPLIB] Crew member %1 (Type: %2) assigned to vehicle %3", _x, typeOf _x, _newvehicle];
        } forEach (crew _newvehicle);
    };
};

// Explicitly set capture status to false
_newvehicle setVariable ["KPLIB_captured", false, true];
diag_log format ["[KPLIB] Set KPLIB_captured to false for: %1 (Type: %2)", _newvehicle, _classname];

// Track the sector that spawned this vehicle
private _nearestSector = [1000, _spawnpos] call KPLIB_fnc_getNearestSector;
if (!isNil "_nearestSector" && {_nearestSector != ""}) then {
    _newvehicle setVariable ["KPLIB_sectorOrigin", _nearestSector, true];
    diag_log format ["[KPLIB] Vehicle %1 (Type: %2) associated with sector: %3", _newvehicle, _classname, _nearestSector];
};

// Clear cargo, if enabled
[_newvehicle] call KPLIB_fnc_clearCargo;

// Process KP object init
[_newvehicle] call KPLIB_fnc_addObjectInit;

// Spawn crew of vehicle
if (_classname in militia_vehicles) then {
    [_newvehicle] call KPLIB_fnc_spawnMilitiaCrew;
} else {
    // Skip for air vehicles as they already have crews assigned earlier
    if (!(_classname in opfor_choppers) && !(_classname in opfor_air)) then {
        // Create appropriate crew for the ground vehicle type
        private _crewType = if (_newvehicle isKindOf "Tank" || _newvehicle isKindOf "Wheeled_APC_F") then {
            // Use tank crew for armored vehicles
            opfor_crewman
        } else {
            // Use rifleman for other vehicles
            opfor_rifleman
        };
        
        // Create custom crew with appropriate units
        [_newvehicle, true, _crewType] call KPLIB_fnc_spawnMilitiaCrew;
    };
};

// Add MPKilled EH and enable damage
_newvehicle addMPEventHandler ["MPKilled", {[{_this call kill_manager}, _this] call CBA_fnc_directCall}];
_newvehicle allowDamage true;
_newvehicle setDamage 0;

// Execute callback if provided
if (!isNil "_callback" && {_callback isEqualType {}}) then {
    [_callback, [_newvehicle]] call CBA_fnc_directCall;
};

// Return the vehicle
_newvehicle
