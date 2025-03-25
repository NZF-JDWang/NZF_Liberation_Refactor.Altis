/*
    Function: KPLIB_fnc_attackInProgressSector
    
    Description:
        Handles the attack logic for sectors that are under attack.
        Manages the attack timer, defensive spawns, and sector ownership changes.
        Uses CBA's non-blocking functions for timing operations.
    
    Parameters:
        _sector - Sector marker name [STRING]
    
    Returns:
        None
    
    Examples:
        (begin example)
        ["sector_1"] call KPLIB_fnc_attackInProgressSector;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-27
*/

params [["_sector", "", [""]]];

// Exit if invalid sector provided
if (_sector isEqualTo "") exitWith {
    ["Invalid sector marker provided", "ATTACK"] call KPLIB_fnc_log;
    false
};

// Local function to spawn blufor defenders
private _fnc_spawnDefenders = {
    params ["_sector"];
    
    private _squadType = blufor_squad_inf_light;
    if (_sector in sectors_military) then {
        _squadType = blufor_squad_inf;
    };
    
    private _defenderGroup = grpNull;
    
    if (GRLIB_blufor_defenders) then {
        _defenderGroup = createGroup [GRLIB_side_friendly, true];
        {
            [_x, markerPos _sector, _defenderGroup] call KPLIB_fnc_createManagedUnit;
        } forEach _squadType;
        
        // Set behavior after a short delay
        [{
            params ["_group", "_sector"];
            
            _group setBehaviour "COMBAT";
            _group setCombatMode "RED";
            
            // Apply LAMBS waypoints if available
            if (isClass(configFile >> "CfgPatches" >> "lambs_main")) then {
                private _sectorPos = markerPos _sector;
                private _searchRadius = GRLIB_capture_size * 0.7;
                
                // Use LAMBS for defensive behavior
                [_group] call lambs_wp_fnc_taskReset;
                
                // Determine enemy presence
                private _enemyCount = [_sectorPos, GRLIB_sector_size, GRLIB_side_enemy] call KPLIB_fnc_getUnitsCount;
                
                if (_enemyCount > 0) then {
                    // Known enemies in sector - actively hunt them
                    [_group, _sectorPos, _searchRadius] call lambs_wp_fnc_taskHunt;
                    ["Defender group using LAMBS taskHunt at sector %1", _sector, "ATTACK"] call KPLIB_fnc_log;
                } else {
                    // No known enemies - use defensive tactics
                    // Randomly select between different LAMBS behaviors
                    private _defensiveTactic = selectRandom [1, 2, 3, 4];
                    
                    switch (_defensiveTactic) do {
                        // Garrison
                        case 1: {
                            [_group, _sectorPos, _searchRadius, true, false, 0.4] call lambs_wp_fnc_taskGarrison;
                            ["Defender group using LAMBS taskGarrison at sector %1", _sector, "ATTACK"] call KPLIB_fnc_log;
                        };
                        // Patrol
                        case 2: {
                            [_group, _sectorPos, _searchRadius, [], true, true] call lambs_wp_fnc_taskPatrol;
                            ["Defender group using LAMBS taskPatrol at sector %1", _sector, "ATTACK"] call KPLIB_fnc_log;
                        };
                        // Creeping patrol
                        case 3: {
                            [_group, _sectorPos, _searchRadius] call lambs_wp_fnc_taskCamp;
                            ["Defender group using LAMBS taskCamp at sector %1", _sector, "ATTACK"] call KPLIB_fnc_log;
                        };
                        // Active defense
                        case 4: {
                            // Primary defensive position at sector center
                            private _mainDefensePos = _sectorPos;
                            
                            // Create a few defensive positions around the sector
                            private _buildingPositions = [];
                            private _buildings = _sectorPos nearObjects ["Building", _searchRadius];
                            
                            // Check if we have suitable buildings
                            if (count _buildings > 0) then {
                                // Find buildings with good positions
                                {
                                    private _positions = [_x] call BIS_fnc_buildingPositions;
                                    if (count _positions > 0) then {
                                        _buildingPositions pushBack (selectRandom _positions);
                                    };
                                } forEach _buildings;
                            };
                            
                            // Add some open field positions if needed
                            if (count _buildingPositions < 3) then {
                                for "_i" from 1 to (3 - (count _buildingPositions)) do {
                                    _buildingPositions pushBack (_sectorPos getPos [random _searchRadius, random 360]);
                                };
                            };
                            
                            // Use taskDefend with these positions
                            [_group, _mainDefensePos, _searchRadius, _buildingPositions, true] call lambs_wp_fnc_taskDefend;
                            ["Defender group using LAMBS taskDefend at sector %1", _sector, "ATTACK"] call KPLIB_fnc_log;
                        };
                    };
                    
                    // Add rush order in case of contact
                    [_group, {
                        params ["_group"];
                        if (behaviour (leader _group) isEqualTo "COMBAT") then {
                            [_group, getPosATL (leader _group), 50] call lambs_wp_fnc_taskRush;
                        };
                    }, nil, 15, {behaviour (leader _group) isEqualTo "COMBAT"}] call CBA_fnc_addPerFrameHandler;
                };
            } else {
                // Fallback to vanilla waypoints if LAMBS not available
                private _sectorPos = markerPos _sector;
                
                // Clear existing waypoints
                while {(count (waypoints _group)) > 0} do {
                    deleteWaypoint ((waypoints _group) select 0);
                };
                
                // Add defensive positions around the sector
                for "_i" from 0 to 3 do {
                    private _defensePos = _sectorPos getPos [GRLIB_capture_size * 0.5, 90 * _i];
                    private _wp = _group addWaypoint [_defensePos, 10];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointBehaviour "COMBAT";
                    _wp setWaypointCombatMode "RED";
                    _wp setWaypointSpeed "NORMAL";
                };
                
                // Cycle waypoints
                private _wpCycle = _group addWaypoint [_sectorPos, 10];
                _wpCycle setWaypointType "CYCLE";
                
                ["Vanilla defensive waypoints added to defender group at sector %1", _sector, "ATTACK"] call KPLIB_fnc_log;
            };
        }, [_defenderGroup, _sector], 3] call CBA_fnc_waitAndExecute;
    };
    
    _defenderGroup
};

// Local function to start attack timer
private _fnc_startAttackTimer = {
    params ["_sector", "_defenderGroup"];
    
    // Initial check of sector ownership
    private _ownership = [markerPos _sector] call KPLIB_fnc_getSectorOwnership;
    
    // Exit if sector is already friendly
    if (_ownership == GRLIB_side_friendly) exitWith {
        // Clean up defenders if sector already captured
        if (GRLIB_blufor_defenders && {!isNull _defenderGroup}) then {
            {
                if (alive _x) then {deleteVehicle _x};
            } forEach units _defenderGroup;
        };
        ["Sector attack cancelled - sector already friendly", "ATTACK"] call KPLIB_fnc_log;
    };
    
    // Continue with attack after delay
    [{
        params ["_sector", "_defenderGroup"];
        
        // Check sector ownership again after delay
        private _ownership = [markerPos _sector] call KPLIB_fnc_getSectorOwnership;
        
        // Only proceed if sector is still enemy or resistance
        if (_ownership == GRLIB_side_enemy || _ownership == GRLIB_side_resistance) then {
            // Notify players of attack in progress
            [_sector, 1] remoteExec ["remote_call_sector"];
            
            // Set up attack timer
            private _attackTime = GRLIB_vulnerability_timer;
            private _pfhHandle = -1;
            
            // Per-frame handler for attack timer countdown
            _pfhHandle = [{
                params ["_args", "_handle"];
                _args params ["_sector", "_attackTime", "_defenderGroup", "_pfhHandle"];
                
                // Get current sector ownership
                private _currentOwnership = [markerPos _sector] call KPLIB_fnc_getSectorOwnership;
                
                // Check if timer should continue
                if (_attackTime > 0 && (_currentOwnership == GRLIB_side_enemy || _currentOwnership == GRLIB_side_resistance)) then {
                    // Decrease timer
                    _args set [1, _attackTime - 1];
                } else {
                    // Remove PFH as we're done with timing
                    [_pfhHandle] call CBA_fnc_removePerFrameHandler;
                    
                    // Wait until sector is no longer in resistance state
                    [
                        {
                            params ["_sector"];
                            [markerPos _sector] call KPLIB_fnc_getSectorOwnership != GRLIB_side_resistance
                        },
                        {
                            params ["_sector", "_attackTime", "_defenderGroup"];
                            
                            // Process results based on attack outcome
                            if (GRLIB_endgame == 0) then {
                                if (_attackTime <= 1 && {[markerPos _sector] call KPLIB_fnc_getSectorOwnership == GRLIB_side_enemy}) then {
                                    // Sector lost to enemy
                                    blufor_sectors = blufor_sectors - [_sector];
                                    publicVariable "blufor_sectors";
                                    [_sector, 2] remoteExec ["remote_call_sector"];
                                    reset_battlegroups_ai = true;
                                    [] call KPLIB_fnc_doSave;
                                    stats_sectors_lost = stats_sectors_lost + 1;
                                    
                                    // Fire the sector_lost event for frontline mechanic
                                    ["sector_lost", [_sector]] call CBA_fnc_localEvent;
                                    
                                    // Handle production buildings in lost sector
                                    {
                                        if (_sector in _x) exitWith {
                                            if ((count (_x select 3)) == 3) then {
                                                {
                                                    detach _x;
                                                    deleteVehicle _x;
                                                } forEach (attachedObjects ((nearestObjects [((_x select 3) select 0), [KP_liberation_small_storage_building], 10]) select 0));
                                                
                                                deleteVehicle ((nearestObjects [((_x select 3) select 0), [KP_liberation_small_storage_building], 10]) select 0);
                                            };
                                            KP_liberation_production = KP_liberation_production - [_x];
                                        };
                                    } forEach KP_liberation_production;
                                } else {
                                    // Attack repelled
                                    [_sector, 3] remoteExec ["remote_call_sector"];
                                    
                                    // Process prisoners
                                    private _enemies = ((markerPos _sector) nearEntities ["Man", GRLIB_capture_size * 0.8]) select {side group _x == GRLIB_side_enemy};
                                    
                                    {
                                        [_x] call prisonner_ai;
                                    } forEach _enemies;
                                };
                            };
                            
                            // Cleanup defenders after a delay
                            [{
                                params ["_defenderGroup"];
                                
                                if (GRLIB_blufor_defenders && {!isNull _defenderGroup}) then {
                                    {
                                        if (alive _x) then {deleteVehicle _x};
                                    } forEach units _defenderGroup;
                                };
                            }, [_defenderGroup], 60] call CBA_fnc_waitAndExecute;
                        },
                        [_sector, _attackTime, _defenderGroup]
                    ] call CBA_fnc_waitUntilAndExecute;
                };
            }, 1, [_sector, _attackTime, _defenderGroup, _pfhHandle]] call CBA_fnc_addPerFrameHandler;
        };
    }, [_sector, _defenderGroup], 60] call CBA_fnc_waitAndExecute;
};

// Check initial sector ownership
[{
    params ["_sector"];
    
    private _ownership = [markerPos _sector] call KPLIB_fnc_getSectorOwnership;
    
    // Only proceed if sector is friendly-owned
    if (_ownership != GRLIB_side_friendly) exitWith {
        ["Attack cancelled - sector not friendly owned", "ATTACK"] call KPLIB_fnc_log;
    };
    
    // Spawn defenders and start attack timer
    private _defenderGroup = [_sector] call _fnc_spawnDefenders;
    [_sector, _defenderGroup] call _fnc_startAttackTimer;
    
}, [_sector], 5] call CBA_fnc_waitAndExecute;

true 