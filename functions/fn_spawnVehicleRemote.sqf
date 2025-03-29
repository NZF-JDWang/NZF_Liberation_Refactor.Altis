/*
    Function: KPLIB_fnc_spawnVehicleRemote
    
    Description:
        Remote execution function for vehicle spawning on headless clients.
        This is designed to be called via remoteExec from fn_spawnVehicle.sqf.
        
    Parameters:
        _pos        - Position to spawn the vehicle                                         [POSITION, defaults to [0, 0, 0]]
        _classname  - Classname of the vehicle to spawn                                     [STRING, defaults to ""]
        _precise    - Selector if the vehicle should spawned precisely on given position    [BOOL, defaults to false]
        _rndDir     - Selector if the direction should be randomized                        [BOOL, defaults to true]
        _callback   - Optional callback function to execute with vehicle as parameter       [CODE, defaults to {}]
    
    Returns:
        NetworkID of the spawned vehicle [STRING]
    
    Author: [NZF] JD Wang
    Date: 2024-11-16
*/

params [
    ["_pos", [0, 0, 0], [[]], [2, 3]],
    ["_classname", "", [""]],
    ["_precise", false, [false]],
    ["_rndDir", true, [false]],
    ["_callback", {}, [{}]]
];

// Log that we're executing on this machine (only in debug mode)
if (KP_liberation_debug) then {
    diag_log format ["[KPLIB][HC] Creating vehicle %1 on machine ID %2", _classname, clientOwner];
};

private _newvehicle = objNull;
private _spawnpos = _pos;

// Spawn the vehicle using the exact same code from the local version
// If it's a chopper, spawn it flying
if (_classname in opfor_choppers) then {
    // Create at [0,0,0] first, then set position
    _newvehicle = createVehicle [_classname, [0, 0, 0], [], 0, 'FLY'];
    _newvehicle setPos _spawnpos;
    _newvehicle flyInHeight (80 + (random 120));
    _newvehicle allowDamage false;
    
    // Log chopper creation only in debug mode
    if (KP_liberation_debug) then {
        diag_log format ["[KPLIB][HC] Spawned flying vehicle: %1 (Type: %2) at %3", _newvehicle, _classname, _spawnpos];
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
        
        // Log jet creation only in debug mode
        if (KP_liberation_debug) then {
            diag_log format ["[KPLIB][HC] Spawned jet: %1 (Type: %2) at %3", _newvehicle, _classname, _spawnpos];
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
        
        // Log ground vehicle creation only in debug mode
        if (KP_liberation_debug) then {
            diag_log format ["[KPLIB][HC] Spawned ground vehicle: %1 (Type: %2) at %3", _newvehicle, _classname, _spawnpos];
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

// Return the networkID of the vehicle, which will be converted back to an object by the caller
_newvehicle call BIS_fnc_netId 