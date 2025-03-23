/*
    Function: KPLIB_fnc_manageOnePatrol
    
    Description:
        Manages an individual patrol based on combat readiness.
        Creates and maintains a vehicle or infantry patrol.
        Uses CBA non-blocking functions for all timing operations.
    
    Parameters:
        _minimum_readiness - Minimum combat readiness required to spawn this patrol [NUMBER]
        _is_infantry - Whether this is an infantry patrol (true) or vehicle patrol (false) [BOOL]
    
    Returns:
        None
    
    Examples:
        (begin example)
        [50, true] call KPLIB_fnc_manageOnePatrol;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-03-23
*/

params ["_minimum_readiness", "_is_infantry"];

// Wait until mission is initialized
[{
    !isNil "blufor_sectors" && !isNil "combat_readiness"
}, {
    params ["_minimum_readiness", "_is_infantry"];
    
    // Inner function to handle patrol creation and lifecycle
    private _fnc_managePatrol = {
        params ["_minimum_readiness", "_is_infantry"];
        
        // Check if endgame has been triggered
        if (GRLIB_endgame != 0) exitWith {
            ["Patrol management stopped due to endgame", "PATROLS"] call KPLIB_fnc_log;
        };
        
        // Verify we have enough blufor sectors and combat readiness
        if (count blufor_sectors < 3 || combat_readiness < (_minimum_readiness / GRLIB_difficulty_modifier)) exitWith {
            // Re-check conditions after delay
            [{
                _this call _fnc_managePatrol;
            }, [_minimum_readiness, _is_infantry], 30] call CBA_fnc_waitAndExecute;
        };
        
        // Check if we're under the opfor cap, retry if not
        if ([] call KPLIB_fnc_getOpforCap > GRLIB_patrol_cap) exitWith {
            [{
                _this call _fnc_managePatrol;
            }, [_minimum_readiness, _is_infantry], 15 + (random 30)] call CBA_fnc_waitAndExecute;
        };
        
        // Get a valid spawn point
        private _spawn_marker = [2000, 5000, true] call KPLIB_fnc_getOpforSpawnPoint;
        
        // If no spawn marker found, try again later
        if (_spawn_marker == "") exitWith {
            [{
                _this call _fnc_managePatrol;
            }, [_minimum_readiness, _is_infantry], 150 + (random 150)] call CBA_fnc_waitAndExecute;
        };
        
        // Random position near the spawn marker
        private _sector_spawn_pos = [
            (((markerPos _spawn_marker) select 0) - 500) + (random 1000),
            (((markerPos _spawn_marker) select 1) - 500) + (random 1000),
            0
        ];
        
        // Spawn the appropriate patrol type
        private _grp = grpNull;
        
        if (_is_infantry) then {
            // Infantry squad
            private _squad = [] call KPLIB_fnc_getSquadComp;
            
            // For infantry patrols, use our new direct HC spawn method to preserve LAMBS waypoints
            private _grp = [_squad, _sector_spawn_pos, _sector_spawn_pos, _patrol_radius, GRLIB_side_enemy] call KPLIB_fnc_spawnPatrolGroupOnHC;
            
            // Process infantry group immediately if created successfully
            if (!isNull _grp) then {
                // Start monitoring patrol lifetime
                [_grp, diag_tickTime, _minimum_readiness, _is_infantry] call _fnc_monitorPatrol;
            };
        } else {
            // Vehicle patrol
            private _vehicle_object = objNull;
            
            if ((combat_readiness > 75) && ((random 100) > 85) && !(opfor_choppers isEqualTo [])) then {
                // High readiness may spawn a helicopter
                _vehicle_object = [_sector_spawn_pos, selectRandom opfor_choppers] call KPLIB_fnc_spawnVehicle;
            } else {
                // Normal vehicle based on tier
                _vehicle_object = [_sector_spawn_pos, [] call KPLIB_fnc_getAdaptiveVehicle] call KPLIB_fnc_spawnVehicle;
            };
            
            // Wait for crew to be created
            [{
                params ["_vehicle_object"];
                !isNull _vehicle_object && {count (crew _vehicle_object) > 0}
            }, {
                params ["_vehicle_object", "_minimum_readiness", "_is_infantry", "_fnc_monitorPatrol", "_fnc_managePatrol"];
                
                private _grp = group ((crew _vehicle_object) select 0);
                
                // Set up patrol AI
                [_grp] call KPLIB_fnc_patrolAI;
                
                // Transfer to headless client if available
                [_grp] call KPLIB_fnc_transferGroupToHC;
                
                // Start monitoring patrol lifetime
                [_grp, diag_tickTime, _minimum_readiness, _is_infantry] call _fnc_monitorPatrol;
                
            }, [_vehicle_object, _minimum_readiness, _is_infantry, _fnc_monitorPatrol, _fnc_managePatrol]] call CBA_fnc_waitUntilAndExecute;
        };
    };
    
    // Function to monitor patrol lifetime and cleanup
    private _fnc_monitorPatrol = {
        params ["_grp", "_started_time", "_minimum_readiness", "_is_infantry"];
        
        if (isNull _grp || count (units _grp) == 0) then {
            // Group is empty or deleted, recreate patrol after delay
            if (!([] call KPLIB_fnc_isBigtownActive)) then {
                [{
                    _this call _fnc_managePatrol;
                }, [_minimum_readiness, _is_infantry], 600.0 / GRLIB_difficulty_modifier] call CBA_fnc_waitAndExecute;
            } else {
                [{
                    _this call _fnc_managePatrol;
                }, [_minimum_readiness, _is_infantry], 60] call CBA_fnc_waitAndExecute;
            };
        } else {
            // Check if patrol has been active for too long and is far from players
            if (diag_tickTime - _started_time > 900) then {
                if ([getPos (leader _grp), 4000, GRLIB_side_friendly] call KPLIB_fnc_getUnitsCount == 0) then {
                    // Delete patrol that's been active too long and away from players
                    {
                        if (vehicle _x != _x) then {
                            [(vehicle _x)] call KPLIB_fnc_cleanOpforVehicle;
                        };
                        deleteVehicle _x;
                    } forEach (units _grp);
                    
                    // Recreate patrol after delay
                    if (!([] call KPLIB_fnc_isBigtownActive)) then {
                        [{
                            _this call _fnc_managePatrol;
                        }, [_minimum_readiness, _is_infantry], 600.0 / GRLIB_difficulty_modifier] call CBA_fnc_waitAndExecute;
                    } else {
                        [{
                            _this call _fnc_managePatrol;
                        }, [_minimum_readiness, _is_infantry], 60] call CBA_fnc_waitAndExecute;
                    };
                } else {
                    // Check again after delay
                    [{
                        _this call _fnc_monitorPatrol;
                    }, [_grp, _started_time, _minimum_readiness, _is_infantry], 60] call CBA_fnc_waitAndExecute;
                };
            } else {
                // Check again after delay
                [{
                    _this call _fnc_monitorPatrol;
                }, [_grp, _started_time, _minimum_readiness, _is_infantry], 60] call CBA_fnc_waitAndExecute;
            };
        };
    };
    
    // Start the patrol management process
    [_minimum_readiness, _is_infantry] call _fnc_managePatrol;
    
}, [_minimum_readiness, _is_infantry]] call CBA_fnc_waitUntilAndExecute;

true 