/*
    Function: add_defense_waypoints
    
    Description:
        Adds defensive waypoints to AI groups around a sector using
        vanilla Arma 3 waypoints for patrolling and defense
    
    Parameters:
        _grp - The group to add waypoints to
        _flagpos - The position to defend
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2024-11-16
*/

params ["_grp", "_flagpos"];

private _basepos = getpos (leader _grp);
private _is_infantry = false;
private _waypoint = [];

if (vehicle (leader _grp) == (leader _grp)) then {_is_infantry = true;};

// Function to clear waypoints
private _fnc_clearWaypoints = {
    params ["_grp"];
    while {(count (waypoints _grp)) != 0} do {
        deleteWaypoint ((waypoints _grp) select 0);
    };
};

// Function to set up defensive waypoints
private _fnc_setupDefensiveWaypoints = {
    params ["_grp", "_flagpos", "_basepos", "_is_infantry"];
    
    // Clear any existing waypoints
    [_grp] call _fnc_clearWaypoints;
    
    // Make units follow group leader
    {_x doFollow leader _grp} foreach units _grp;
    
    // Create patrol waypoints based on unit type
    if (_is_infantry) then {
        // Infantry patrol patterns
        private _searchRadius = GRLIB_sector_size * 0.75;
        
        // Determine behavior type
        private _behaviorChoice = selectRandomWeighted [
            "patrol", 0.4,    // 40% chance for patrol
            "defend", 0.6     // 60% chance for defend
        ];
        
        switch (_behaviorChoice) do {
            case "patrol": {
                // Create 5 random waypoints in a patrol pattern
                private _wpPositions = [
                    _flagpos getPos [random 150, random 360],
                    _flagpos getPos [random 150, random 360],
                    _flagpos getPos [random 150, random 360],
                    _flagpos getPos [random 150, random 360],
                    _flagpos getPos [random 150, random 360]
                ];
                
                {
                    _waypoint = _grp addWaypoint [_x, 10];
                    _waypoint setWaypointType "MOVE";
                    _waypoint setWaypointBehaviour "SAFE";
                    _waypoint setWaypointCombatMode "YELLOW";
                } forEach _wpPositions;
                
                // Cycle back to first waypoint
                _waypoint = _grp addWaypoint [_wpPositions select 0, 10];
                _waypoint setWaypointType "CYCLE";
                
                [format ["Infantry group using vanilla patrol waypoints at %1 with radius %2", _flagpos, _searchRadius], "INFO"] call KPLIB_fnc_log;
            };
            
            case "defend": {
                // Find suitable defensive positions
                private _buildingPositions = [];
                private _buildings = _flagpos nearObjects ["House", _searchRadius];
                
                // Check if we have suitable buildings
                if (count _buildings > 0) then {
                    // Find buildings with good positions
                    {
                        private _positions = [_x] call BIS_fnc_buildingPositions;
                        if (count _positions > 0) then {
                            _buildingPositions pushBack (selectRandom _positions);
                        };
                    } forEach (_buildings select {count ([_x] call BIS_fnc_buildingPositions) > 0});
                };
                
                // Add some open field positions if needed
                if (count _buildingPositions < 3) then {
                    for "_i" from 1 to (3 - (count _buildingPositions)) do {
                        _buildingPositions pushBack (_flagpos getPos [random _searchRadius, random 360]);
                    };
                };
                
                // Use built-in task defend function
                [_grp, _flagpos, _searchRadius] call BIS_fnc_taskDefend;
                [format ["Infantry group using BIS_fnc_taskDefend at %1 with radius %2", _flagpos, _searchRadius], "INFO"] call KPLIB_fnc_log;
            };
        };
    } else {
        // Vehicle patrol patterns
        private _searchRadius = GRLIB_sector_size * 0.75;
        private _wpPositions = [];
        
        // Create waypoints based on vehicle type
        private _veh = vehicle (leader _grp);
        private _vehType = typeOf _veh;
        
        // Different patrol patterns for different vehicle types
        if (_vehType isKindOf "Tank" || _vehType isKindOf "Wheeled_APC_F") then {
            // Armored vehicles - wider patrol pattern with some stationary positions
            _wpPositions = [
                _flagpos,  // Center position
                _flagpos getPos [random _searchRadius, random 360],
                _flagpos getPos [random _searchRadius, random 360],
                _flagpos getPos [random _searchRadius, random 360]
            ];
            
            // Create waypoints
            {
                _waypoint = _grp addWaypoint [_x, 10];
                _waypoint setWaypointType "MOVE";
                _waypoint setWaypointBehaviour "SAFE";
                _waypoint setWaypointCombatMode "YELLOW";
                _waypoint setWaypointSpeed "LIMITED";
                
                // Add a pause at some positions
                if (_forEachIndex > 0 && random 1 > 0.5) then {
                    _waypoint setWaypointType "HOLD";
                    _waypoint setWaypointTimeout [30, 60, 120];
                };
            } forEach _wpPositions;
            
            [format ["Vehicle group (Armor) using vanilla patrol waypoints at %1 with radius %2", _flagpos, _searchRadius], "INFO"] call KPLIB_fnc_log;
        } else {
            // Cars and other vehicles - faster, continuous movement
            _wpPositions = [
                _flagpos getPos [random _searchRadius, random 360],
                _flagpos getPos [random _searchRadius, random 360],
                _flagpos getPos [random _searchRadius, random 360],
                _flagpos getPos [random _searchRadius, random 360],
                _flagpos getPos [random _searchRadius, random 360]
            ];
            
            // Create waypoints
            {
                _waypoint = _grp addWaypoint [_x, 10];
                _waypoint setWaypointType "MOVE";
                _waypoint setWaypointBehaviour "SAFE";
                _waypoint setWaypointCombatMode "YELLOW";
                
                // Cars move faster
                if (_vehType isKindOf "Car") then {
                    _waypoint setWaypointSpeed "NORMAL";
                    [format ["Vehicle group (Car) using vanilla patrol waypoints at %1 with radius %2", _flagpos, _searchRadius], "INFO"] call KPLIB_fnc_log;
                } else {
                    _waypoint setWaypointSpeed "LIMITED";
                    [format ["Vehicle group (Other) using vanilla patrol waypoints at %1 with radius %2", _flagpos, _searchRadius], "INFO"] call KPLIB_fnc_log;
                };
            } forEach _wpPositions;
        };
        
        // Cycle back to first waypoint
        _waypoint = _grp addWaypoint [_wpPositions select 0, 10];
        _waypoint setWaypointType "CYCLE";
    };
    
    // Set the current waypoint to the first one
    if (count waypoints _grp > 0) then {
        _grp setCurrentWaypoint [_grp, 0];
    };
};

// Function to set up combat waypoints when enemies are detected
private _fnc_setupCombatWaypoints = {
    params ["_grp", "_basepos", "_is_infantry"];
    
    // Clear the existing waypoints
    [_grp] call _fnc_clearWaypoints;
    
    // Make units follow group leader
    {_x doFollow leader _grp} foreach units _grp;
    
    // Find nearest enemy position
    private _nearestEnemy = (leader _grp) findNearestEnemy (leader _grp);
    
    if (!isNull _nearestEnemy) then {
        private _enemyPos = getPos _nearestEnemy;
        
        if (_is_infantry) then {
            // Infantry response - use task attack
            [_grp, _enemyPos] call BIS_fnc_taskAttack;
            [format ["Infantry combat group using BIS_fnc_taskAttack at %1", _enemyPos], "INFO"] call KPLIB_fnc_log;
        } else {
            // Vehicle response - create SAD waypoint
            _waypoint = _grp addWaypoint [_enemyPos, 50];
            _waypoint setWaypointType "SAD";
            _waypoint setWaypointBehaviour "COMBAT";
            _waypoint setWaypointCombatMode "RED";
            _waypoint setWaypointSpeed "NORMAL";
            
            [format ["Vehicle combat group using SAD waypoint at %1", _enemyPos], "INFO"] call KPLIB_fnc_log;
        };
    } else {
        // No known enemy position, search in the area
        [_grp, _basepos, 150] call BIS_fnc_taskPatrol;
        [format ["Group using search patrol at %1 - no enemy found", _basepos], "INFO"] call KPLIB_fnc_log;
    };
};

// Initial setup - create defensive waypoints
[_grp, _flagpos, _basepos, _is_infantry] call _fnc_setupDefensiveWaypoints;

// Set up monitoring to change waypoints based on combat situation
private _pfh = [{
    params ["_args", "_handle"];
    _args params ["_grp", "_basepos", "_is_infantry", "_fnc_setupCombatWaypoints"];
    
    // Exit conditions
    if (isNull _grp || {count units _grp == 0} || {!alive leader _grp}) exitWith {
        [_handle] call CBA_fnc_removePerFrameHandler;
    };
    
    // Check if the group is in combat and needs new waypoints
    private _leader = leader _grp;
    private _nearestEnemy = _leader findNearestEnemy _leader;
    
    if (!isNull _nearestEnemy && {_leader knowsAbout _nearestEnemy > 1.5} && {_leader distance _nearestEnemy < 500}) then {
        // Enemy detected - set up combat waypoints
        [_grp, _basepos, _is_infantry] call _fnc_setupCombatWaypoints;
        
        // Remove this PFH
        [_handle] call CBA_fnc_removePerFrameHandler;
        
        // Restart normal patrol after a delay
        [{
            params ["_grp", "_flagpos", "_basepos", "_is_infantry", "_fnc_setupDefensiveWaypoints", "_fnc_setupCombatWaypoints", "_fnc_clearWaypoints"];
            
            [_grp, _flagpos, _basepos, _is_infantry] call _fnc_setupDefensiveWaypoints;
            
            // Set up the combat check again
            [{
                params ["_args", "_handle"];
                _args params ["_grp", "_basepos", "_is_infantry", "_fnc_setupCombatWaypoints"];
                
                // Exit conditions
                if (isNull _grp || {count units _grp == 0} || {!alive leader _grp}) exitWith {
                    [_handle] call CBA_fnc_removePerFrameHandler;
                };
                
                // Check if the group is in combat and needs new waypoints
                private _leader = leader _grp;
                private _nearestEnemy = _leader findNearestEnemy _leader;
                
                if (!isNull _nearestEnemy && {_leader knowsAbout _nearestEnemy > 1.5} && {_leader distance _nearestEnemy < 500}) then {
                    // Enemy detected - set up combat waypoints
                    [_grp, _basepos, _is_infantry] call _fnc_setupCombatWaypoints;
                    
                    // Remove this PFH
                    [_handle] call CBA_fnc_removePerFrameHandler;
                };
            }, 10, [_grp, _basepos, _is_infantry, _fnc_setupCombatWaypoints]] call CBA_fnc_addPerFrameHandler;
            
        }, [_grp, _flagpos, _basepos, _is_infantry, _fnc_setupDefensiveWaypoints, _fnc_setupCombatWaypoints, _fnc_clearWaypoints], 5] call CBA_fnc_waitAndExecute;
    };
}, 10, [_grp, _basepos, _is_infantry, _fnc_setupCombatWaypoints]] call CBA_fnc_addPerFrameHandler;
