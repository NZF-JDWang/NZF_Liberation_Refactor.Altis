/*
    Function: KPLIB_fnc_spawnVehicle
    
    Description:
        Spawns a vehicle with all needed Liberation connections/dependencies.
        Uses CBA functions to work in both scheduled and unscheduled environments.
        All event handlers use non-blocking CBA calls for better performance.
        Uses optimized vehicle spawning at [0,0,0] then setting position.
        Creates vehicle directly on headless client when available.
    
    Parameters:
        _pos        - Position to spawn the vehicle                                         [POSITION, defaults to [0, 0, 0]]
        _classname  - Classname of the vehicle to spawn                                     [STRING, defaults to ""]
        _precise    - Selector if the vehicle should spawned precisely on given position    [BOOL, defaults to false]
        _rndDir     - Selector if the direction should be randomized                        [BOOL, defaults to true]
        _callback   - Optional callback function to execute with vehicle as parameter       [CODE, defaults to {}]
    
    Returns:
        Spawned vehicle [OBJECT]
    
    Examples:
        (begin example)
        _vehicle = [getPos player, "B_MRAP_01_F"] call KPLIB_fnc_spawnVehicle;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-03-25
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

// Get the least loaded headless client for spawning
private _hc = [] call KPLIB_fnc_getLessLoadedHC;
private _owner = if (isNull _hc) then {2} else {owner _hc};

// Log the target machine only in debug mode
if (KP_liberation_debug) then {
    diag_log format ["[KPLIB] Spawning vehicle %1 on machine with ID %2", _classname, _owner];
};

// If this isn't the target machine, use remoteExec to create the vehicle
if (_owner != clientOwner) then {
    // Send the spawn request to the HC/server and get back the vehicle
    private _params = [_pos, _classname, _precise, _rndDir, _callback];
    private _vehicleNetId = _params remoteExecCall ["KPLIB_fnc_spawnVehicleRemote", _owner, true];
    
    // Wait for the vehicle to be created and get a reference to it
    waitUntil {
        _newvehicle = _vehicleNetId call BIS_fnc_objectFromNetId;
        !isNull _newvehicle
    };
    
    if (KP_liberation_debug) then {
        diag_log format ["[KPLIB] Vehicle %1 spawned via remote execution on machine %2", _newvehicle, _owner];
    };
} else {
    // This is the target machine, spawn locally
    
    // If it's a chopper, spawn it flying
    if (_classname in opfor_choppers) then {
        // Create at [0,0,0] first, then set position
        _newvehicle = createVehicle [_classname, [0, 0, 0], [], 0, 'FLY'];
        _newvehicle setPos _spawnpos;
        _newvehicle flyInHeight (80 + (random 120));
        _newvehicle allowDamage false;
        
        if (KP_liberation_debug) then {
            diag_log format ["[KPLIB] Spawned flying vehicle: %1 (Type: %2) at %3", _newvehicle, _classname, _spawnpos];
        };

        // Create crew - use helicopter pilots
        [_newvehicle, true, opfor_heli_pilot] call KPLIB_fnc_spawnMilitiaCrew;

        // Mark crew members with reference to their parent vehicle
        {
            _x setVariable ["KPLIB_parentVehicle", _newvehicle, true];
        } forEach (crew _newvehicle);
    } else {
        if (_classname in opfor_air) then {
            // This is a fixed-wing aircraft
            // Create at [0,0,0] first, then set position
            _newvehicle = createVehicle [_classname, [0, 0, 0], [], 0, 'FLY'];
            _newvehicle setPos _spawnpos;
            _newvehicle flyInHeight (300 + (random 200));
            _newvehicle allowDamage false;
            
            if (KP_liberation_debug) then {
                diag_log format ["[KPLIB] Spawned jet: %1 (Type: %2) at %3", _newvehicle, _classname, _spawnpos];
            };
            
            // Create crew - use jet pilots
            [_newvehicle, true, opfor_jet_pilot] call KPLIB_fnc_spawnMilitiaCrew;
            
            // Mark crew members with reference to their parent vehicle
            {
                _x setVariable ["KPLIB_parentVehicle", _newvehicle, true];
            } forEach (crew _newvehicle);
        } else {
            // Create at [0,0,0] first, then set position
            _newvehicle = createVehicle [_classname, [0, 0, 0], [], 0, ''];
            _newvehicle setPos _spawnpos;
            _newvehicle allowDamage false;

            [_newvehicle] call KPLIB_fnc_allowCrewInImmobile;
            
            if (KP_liberation_debug) then {
                diag_log format ["[KPLIB] Spawned ground vehicle: %1 (Type: %2) at %3", _newvehicle, _classname, _spawnpos];
            };

            // Randomize direction and reset position and vector
            if (_rndDir) then {
                _newvehicle setDir (random 360);
            };
            _newvehicle setPos _spawnpos;
            _newvehicle setVectorUp surfaceNormal position _newvehicle;

            // Mark any existing crew members with reference to their parent vehicle
            {
                _x setVariable ["KPLIB_parentVehicle", _newvehicle, true];
            } forEach (crew _newvehicle);
        };
    };

    // Explicitly set capture status to false
    _newvehicle setVariable ["KPLIB_captured", false, true];
    
    // Track the sector that spawned this vehicle
    private _nearestSector = [1000, _spawnpos] call KPLIB_fnc_getNearestSector;
    if (!isNil "_nearestSector" && {_nearestSector != ""}) then {
        _newvehicle setVariable ["KPLIB_sectorOrigin", _nearestSector, true];
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
            // Check if vehicle is armored using config values
            private _isArmored = false;
            
            // Method 1: Check basic class inheritance
            if (_newvehicle isKindOf "Tank" || {_newvehicle isKindOf "APC"}) then {
                _isArmored = true;
            };
            
            // Method 2: Check config values if still not determined
            if (!_isArmored) then {
                // Check if has armor value exceeding threshold
                private _armorLevel = getNumber (configFile >> "CfgVehicles" >> _classname >> "armor");
                if (_armorLevel > 100) then {
                    _isArmored = true;
                };
                
                // Check if has a turret with weapons
                private _hasTurret = false;
                private _turrets = "true" configClasses (configFile >> "CfgVehicles" >> _classname >> "Turrets");
                
                {
                    private _weapons = getArray (_x >> "weapons");
                    if (count _weapons > 0) exitWith {
                        _hasTurret = true;
                    };
                } forEach _turrets;
                
                // Check if it has HitPoints that suggest armor
                private _hasArmorHitpoints = false;
                private _hitPoints = "true" configClasses (configFile >> "CfgVehicles" >> _classname >> "HitPoints");
                
                {
                    private _hitPointName = configName _x;
                    if (_hitPointName in ["HitHull", "HitTurret", "HitGun", "HitEngine", "HitLTrack", "HitRTrack"]) exitWith {
                        _hasArmorHitpoints = true;
                    };
                } forEach _hitPoints;
                
                // If it has a weapon turret AND either armor value or armor hitpoints, consider it armored
                if (_hasTurret && (_armorLevel > 50 || _hasArmorHitpoints)) then {
                    _isArmored = true;
                };
            };
            
            // Set crew type based on determination
            private _crewType = if (_isArmored) then {
                // Use tank crew for all armored vehicles
                opfor_crewman
            } else {
                // Use rifleman for non-armored vehicles
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
};

// Return the vehicle
_newvehicle
