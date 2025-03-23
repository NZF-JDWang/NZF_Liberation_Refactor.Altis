/*
    Function: KPLIB_fnc_attackInProgressFOB
    
    Description:
        Handles the attack logic for FOBs that are under attack.
        Manages the attack timer, defensive spawns, and FOB ownership changes.
        Uses CBA's non-blocking functions for timing operations.
    
    Parameters:
        _position - Position of the FOB under attack [ARRAY]
    
    Returns:
        None
    
    Examples:
        (begin example)
        [getPos myFOB] call KPLIB_fnc_attackInProgressFOB;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-27
*/

params [["_position", [], [[]]]];

// Exit if invalid position provided
if (_position isEqualTo []) exitWith {
    ["Invalid FOB position provided", "ATTACK"] call KPLIB_fnc_log;
    false
};

// Local function to spawn blufor defenders
private _fnc_spawnDefenders = {
    params ["_position"];
    
    private _defenderGroup = grpNull;
    
    if (GRLIB_blufor_defenders) then {
        _defenderGroup = createGroup [GRLIB_side_friendly, true];
        {
            [_x, _position, _defenderGroup] call KPLIB_fnc_createManagedUnit;
        } forEach blufor_squad_inf;
        
        // Set behavior after a short delay
        [{
            params ["_group", "_position"];
            
            _group setBehaviour "COMBAT";
            _group setCombatMode "RED";
            
            // Apply LAMBS waypoints if available
            if (isClass(configFile >> "CfgPatches" >> "lambs_main")) then {
                private _searchRadius = GRLIB_capture_size * 0.7;
                
                // Use LAMBS for defensive behavior
                [_group] call lambs_wp_fnc_taskReset;
                
                // Determine enemy presence
                private _enemyCount = [_position, GRLIB_capture_size, GRLIB_side_enemy] call KPLIB_fnc_getUnitsCount;
                
                if (_enemyCount > 0) then {
                    // Known enemies in sector - actively hunt them
                    [_group, _position, _searchRadius] call lambs_wp_fnc_taskHunt;
                    ["Defender group using LAMBS taskHunt at FOB near %1", _position, "ATTACK"] call KPLIB_fnc_log;
                } else {
                    // No known enemies - use defensive tactics
                    // Randomly select between different LAMBS behaviors
                    private _defensiveTactic = selectRandom [1, 2, 3, 4];
                    
                    switch (_defensiveTactic) do {
                        // Garrison
                        case 1: {
                            [_group, _position, _searchRadius, true, false, 0.4] call lambs_wp_fnc_taskGarrison;
                            ["Defender group using LAMBS taskGarrison at FOB near %1", _position, "ATTACK"] call KPLIB_fnc_log;
                        };
                        // Patrol
                        case 2: {
                            [_group, _position, _searchRadius, [], true, true] call lambs_wp_fnc_taskPatrol;
                            ["Defender group using LAMBS taskPatrol at FOB near %1", _position, "ATTACK"] call KPLIB_fnc_log;
                        };
                        // Creeping patrol
                        case 3: {
                            [_group, _position, _searchRadius] call lambs_wp_fnc_taskCamp;
                            ["Defender group using LAMBS taskCamp at FOB near %1", _position, "ATTACK"] call KPLIB_fnc_log;
                        };
                        // Active defense
                        case 4: {
                            // Primary defensive position at FOB center
                            private _mainDefensePos = _position;
                            
                            // Create a few defensive positions around the FOB
                            private _buildingPositions = [];
                            private _buildings = _position nearObjects ["Building", _searchRadius];
                            
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
                                    _buildingPositions pushBack (_position getPos [random _searchRadius, random 360]);
                                };
                            };
                            
                            // Use taskDefend with these positions
                            [_group, _mainDefensePos, _searchRadius, _buildingPositions, true] call lambs_wp_fnc_taskDefend;
                            ["Defender group using LAMBS taskDefend at FOB near %1", _position, "ATTACK"] call KPLIB_fnc_log;
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
                // Clear existing waypoints
                while {(count (waypoints _group)) > 0} do {
                    deleteWaypoint ((waypoints _group) select 0);
                };
                
                // Add defensive positions around the FOB
                for "_i" from 0 to 3 do {
                    private _defensePos = _position getPos [GRLIB_capture_size * 0.5, 90 * _i];
                    private _wp = _group addWaypoint [_defensePos, 10];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointBehaviour "COMBAT";
                    _wp setWaypointCombatMode "RED";
                    _wp setWaypointSpeed "NORMAL";
                };
                
                // Cycle waypoints
                private _wpCycle = _group addWaypoint [_position, 10];
                _wpCycle setWaypointType "CYCLE";
                
                ["Vanilla defensive waypoints added to defender group at FOB near %1", _position, "ATTACK"] call KPLIB_fnc_log;
            };
        }, [_defenderGroup, _position], 3] call CBA_fnc_waitAndExecute;
    };
    
    _defenderGroup
};

// Local function to start attack timer
private _fnc_startAttackTimer = {
    params ["_position", "_defenderGroup"];
    
    // Add FOB to sectors under attack
    KPLIB_sectorsUnderAttack pushBack _position;
    publicVariable "KPLIB_sectorsUnderAttack";
    
    // Continue with attack after delay
    [{
        params ["_position", "_defenderGroup"];
        
        // Notify players of attack in progress
        [_position, 1] remoteExec ["remote_call_fob"];
        
        // Set up attack timer
        private _attackTime = GRLIB_vulnerability_timer;
        private _pfhHandle = -1;
        
        // Per-frame handler for attack timer countdown
        _pfhHandle = [{
            params ["_args", "_handle"];
            _args params ["_position", "_attackTime", "_defenderGroup", "_pfhHandle"];
            
            // Get current FOB ownership
            private _currentOwnership = [_position] call KPLIB_fnc_getSectorOwnership;
            
            // Check if timer should continue - timer runs while FOB ownership is contested
            if (_attackTime > 0) then {
                // Decrease timer
                _args set [1, _attackTime - 1];
            } else {
                // Timer expired - FOB is lost to enemy
                // Remove PFH as we're done with timing
                [_pfhHandle] call CBA_fnc_removePerFrameHandler;
                
                if (GRLIB_endgame == 0) then {
                    // FOB lost to enemy - 30 minutes have passed
                    [_position, 2] remoteExec ["remote_call_fob"];
                    
                    // Small delay before FOB removal
                    [{
                        params ["_position"];
                        
                        GRLIB_all_fobs = GRLIB_all_fobs - [_position];
                        publicVariable "GRLIB_all_fobs";
                        reset_battlegroups_ai = true;
                        [_position] call KPLIB_fnc_destroyFob;
                        [] call KPLIB_fnc_doSave;
                        stats_fobs_lost = stats_fobs_lost + 1;
                        
                        // Remove FOB from under attack list
                        KPLIB_sectorsUnderAttack = KPLIB_sectorsUnderAttack - [_position];
                        publicVariable "KPLIB_sectorsUnderAttack";
                    }, [_position], 3] call CBA_fnc_waitAndExecute;
                    
                    // Cleanup defenders after a delay
                    [{
                        params ["_defenderGroup"];
                        
                        if (GRLIB_blufor_defenders && {!isNull _defenderGroup}) then {
                            {
                                if (alive _x) then {deleteVehicle _x};
                            } forEach units _defenderGroup;
                        };
                    }, [_defenderGroup], 60] call CBA_fnc_waitAndExecute;
                };
            };
            
            // Check if players have defeated the attack - no enemies in FOB radius
            if (_attackTime > 1 && _currentOwnership == GRLIB_side_friendly) then {
                // Get enemy count near FOB
                private _enemies = ((_position nearEntities ["Man", GRLIB_capture_size * 0.8]) select {side group _x == GRLIB_side_enemy});
                
                // If no enemies left, attack is repelled
                if (count _enemies == 0) then {
                    // Remove PFH as attack is repelled
                    [_pfhHandle] call CBA_fnc_removePerFrameHandler;
                    
                    // Attack repelled
                    [_position, 3] remoteExec ["remote_call_fob"];
                    
                    // Process any remaining enemies as prisoners
                    {
                        [_x] call prisonner_ai;
                    } forEach ((_position nearEntities ["Man", GRLIB_capture_size * 0.8]) select {side group _x == GRLIB_side_enemy});
                    
                    // Remove FOB from under attack list
                    KPLIB_sectorsUnderAttack = KPLIB_sectorsUnderAttack - [_position];
                    publicVariable "KPLIB_sectorsUnderAttack";
                    
                    // Cleanup defenders after a delay
                    [{
                        params ["_defenderGroup"];
                        
                        if (GRLIB_blufor_defenders && {!isNull _defenderGroup}) then {
                            {
                                if (alive _x) then {deleteVehicle _x};
                            } forEach units _defenderGroup;
                        };
                    }, [_defenderGroup], 60] call CBA_fnc_waitAndExecute;
                };
            };
        }, 1, [_position, _attackTime, _defenderGroup, _pfhHandle]] call CBA_fnc_addPerFrameHandler;
    }, [_position, _defenderGroup], 3] call CBA_fnc_waitAndExecute;
};

// Check initial FOB ownership
[{
    params ["_position"];
    
    private _ownership = [_position] call KPLIB_fnc_getSectorOwnership;
    
    // Only proceed if FOB is friendly-owned
    if (_ownership != GRLIB_side_friendly) exitWith {
        ["Attack cancelled - FOB not friendly owned", "ATTACK"] call KPLIB_fnc_log;
    };
    
    // Spawn defenders and start attack timer
    private _defenderGroup = [_position] call _fnc_spawnDefenders;
    [_position, _defenderGroup] call _fnc_startAttackTimer;
    
}, [_position], 5] call CBA_fnc_waitAndExecute;

true 