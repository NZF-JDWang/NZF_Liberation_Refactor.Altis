/*
    File: fn_spawnRegularSquad.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2019-12-03
    Last Update: 2024-11-17
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Spawns a regular enemy squad with given soldier classnames at given sector.
        Uses staggered spawning via CBA to reduce lag spikes.
        Creates both the group and units directly on headless client for proper locality.

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

// Create the group directly on the HC/server using the unified function
private _grp = [GRLIB_side_enemy] call KPLIB_fnc_createGroupOnHC;

// Exit if group creation failed
if (isNull _grp) exitWith {
    diag_log format ["[KPLIB] Failed to create group for sector %1", _sector];
    grpNull
};

// Log what's happening
diag_log format ["[KPLIB] Creating squad for sector %1 - Group: %2", _sector, _grp];

// Recursive function to spawn units with staggered delay
private _fnc_spawnNextUnit = {
    params ["_args", "_handle"];
    _args params ["_classnames", "_spawnPos", "_grp", "_currentIndex", "_maxIndex", "_sector", "_sectorPos"];
    
    // Exit if all units spawned or group no longer exists
    if (_currentIndex >= _maxIndex || isNull _grp) exitWith {
        [_handle] call CBA_fnc_removePerFrameHandler;
        
        // Only proceed if group exists and has units
        if (!isNull _grp && {count units _grp > 0}) then {
            // First ensure all units are set to follow their leader
            // This helps prevent the formation standing issue
            {
                _x doFollow (leader _grp);
                _x setUnitPos "AUTO";
            } forEach (units _grp);
            
            // Wait a longer time to ensure all units are properly initialized
            // This delay is important to avoid race conditions with LAMBS waypoints
            [{
                params ["_group", "_sector", "_sectorPos"];
                
                if (!isNull _group && {count units _group > 0}) then {
                    // Get the group owner ID for proper locality handling
                    private _groupOwner = groupOwner _group;
                    private _isLocal = _groupOwner == clientOwner;
                    
                    // Log before applying AI
                    diag_log format ["[KPLIB] Applying AI behavior to squad in sector %1 with %2 units - Local: %3, Owner: %4", 
                                     _sector, count units _group, _isLocal, _groupOwner];
                    
                    // Apply appropriate AI behavior using our unified function
                    // This function will handle the remote execution if needed
                    [_group, _groupOwner, _sector, "PATROL_DEFAULT"] call KPLIB_fnc_applyAIBehavior;
                    
                    // Basic group state commands will work across network boundary
                    _group setBehaviour "AWARE";
                    _group setCombatMode "YELLOW";
                    
                    // Log after applying AI
                    diag_log format ["[KPLIB] AI behavior applied to squad in sector %1", _sector];
                };
            }, [_grp, _sector, _sectorPos], 3.0] call CBA_fnc_waitAndExecute;
        };
    };
    
    // Get next classname to spawn
    private _classname = _classnames select _currentIndex;
    
    // Spawn the unit directly on the target machine
    [_classname, _spawnPos, _grp] call KPLIB_fnc_createManagedUnit;
    
    // Update index for next unit
    _args set [3, _currentIndex + 1];
};

// Start the staggered spawning process - one unit every 0.05 seconds
[
    _fnc_spawnNextUnit,
    0.05,
    [_classnames, _spawnPos, _grp, 0, _corrected_amount, _sector, _sectorPos]
] call CBA_fnc_addPerFrameHandler;

_grp
