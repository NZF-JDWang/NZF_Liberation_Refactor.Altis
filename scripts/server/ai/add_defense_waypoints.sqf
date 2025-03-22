/*
    Function: add_defense_waypoints
    
    Description:
        Adds defensive waypoints to AI groups around a sector using LAMBS waypoint system
        for improved AI behavior including patrolling, garrisoning and camping
    
    Parameters:
        _grp - The group to add waypoints to
        _flagpos - The position to defend
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2024-10-15
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

// Function to set up defensive waypoints using LAMBS system
private _fnc_setupDefensiveWaypoints = {
    params ["_grp", "_flagpos", "_basepos", "_is_infantry"];
    
    // Clear any existing waypoints
    [_grp] call _fnc_clearWaypoints;
    
    // Make units follow group leader
    {_x doFollow leader _grp} foreach units _grp;
    
    // Create patrol/garrison/camp waypoints based on unit type
    if (_is_infantry) then {
        // Determine if this group should patrol, garrison, or camp based on a weighted random choice
        private _behaviorChoice = selectRandom [
            "patrol", "patrol", "patrol",  // 3/7 chance for patrol
            "garrison", "garrison",        // 2/7 chance for garrison
            "camp", "camp"                 // 2/7 chance for camp
        ];
        
        switch (_behaviorChoice) do {
            case "patrol": {
                // Use LAMBS patrol function if available, otherwise fall back to vanilla
                if (isClass (configFile >> "CfgPatches" >> "lambs_wp")) then {
                    // LAMBS Patrol - infantry patrols within 200m of the sector center
                    [_grp, _flagpos, 200, [], false, true] call lambs_wp_fnc_taskPatrol;
                } else {
                    // Vanilla fallback - create 5 random waypoints in a patrol pattern
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
                        _waypoint setWaypointSpeed "LIMITED";
                    } forEach _wpPositions;
                    
                    // Cycle back to first waypoint
                    _waypoint = _grp addWaypoint [_wpPositions select 0, 10];
                    _waypoint setWaypointType "CYCLE";
                };
            };
            
            case "garrison": {
                // Use LAMBS garrison function if available, otherwise fall back to vanilla
                if (isClass (configFile >> "CfgPatches" >> "lambs_wp")) then {
                    // LAMBS Garrison - occupy buildings within 150m of the sector center
                    [_grp, _flagpos, 150, [], true, false] call lambs_wp_fnc_taskGarrison;
                } else {
                    // Vanilla fallback - assign waypoint to nearest building
                    private _buildings = nearestObjects [_flagpos, ["House"], 150];
                    if (count _buildings > 0) then {
                        private _building = selectRandom _buildings;
                        _waypoint = _grp addWaypoint [getPos _building, 10];
                        _waypoint setWaypointType "HOLD";
                        _waypoint setWaypointBehaviour "SAFE";
                        _waypoint setWaypointCombatMode "YELLOW";
                    } else {
                        // If no buildings, defend position
                        _waypoint = _grp addWaypoint [_flagpos, 10];
                        _waypoint setWaypointType "HOLD";
                        _waypoint setWaypointBehaviour "SAFE";
                        _waypoint setWaypointCombatMode "YELLOW";
                    };
                };
            };
            
            case "camp": {
                // Use LAMBS camp function if available, otherwise fall back to vanilla
                if (isClass (configFile >> "CfgPatches" >> "lambs_wp")) then {
                    // LAMBS Camp - establish a defensive position with static weapons if available
                    [_grp, _flagpos, 50, [], true, true] call lambs_wp_fnc_taskCamp;
                } else {
                    // Vanilla fallback - defend position
                    _waypoint = _grp addWaypoint [_flagpos, 10];
                    _waypoint setWaypointType "HOLD";
                    _waypoint setWaypointBehaviour "SAFE";
                    _waypoint setWaypointCombatMode "YELLOW";
                };
            };
        };
    } else {
        // Vehicle behavior - always use vanilla waypoints
        // Create patrol waypoints in a wider area for vehicles
        private _wpPositions = [
            _flagpos getPos [random 300, random 360],
            _flagpos getPos [random 300, random 360],
            _flagpos getPos [random 300, random 360],
            _flagpos getPos [random 300, random 360],
            _flagpos getPos [random 300, random 360]
        ];
        
        {
            _waypoint = _grp addWaypoint [_x, 10];
            _waypoint setWaypointType "MOVE";
            _waypoint setWaypointBehaviour "SAFE";
            _waypoint setWaypointCombatMode "YELLOW";
            _waypoint setWaypointSpeed "LIMITED";
        } forEach _wpPositions;
        
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
    
    // Use LAMBS task rush if available and this is infantry, otherwise use vanilla waypoints
    if (_is_infantry && isClass (configFile >> "CfgPatches" >> "lambs_wp")) then {
        // Find nearest enemy position
        private _nearestEnemy = (leader _grp) findNearestEnemy (leader _grp);
        if (!isNull _nearestEnemy) then {
            // Use task rush for quick assault
            [_grp, getPos _nearestEnemy, 100] call lambs_wp_fnc_taskRush;
        } else {
            // If no enemy found, hunt in the area
            [_grp, _basepos, 200] call lambs_wp_fnc_taskHunt;
        };
    } else {
        // Vanilla fallback - create search & destroy waypoints
        private _wpPositions = [
            _basepos getPos [random 150, random 360],
            _basepos getPos [random 150, random 360],
            _basepos getPos [random 150, random 360],
            _basepos getPos [random 150, random 360],
            _basepos getPos [random 150, random 360]
        ];
        
        // First waypoint with detailed settings
        _waypoint = _grp addWaypoint [_wpPositions select 0, 10];
        _waypoint setWaypointType "SAD";
        _waypoint setWaypointBehaviour "COMBAT";
        _waypoint setWaypointCombatMode "YELLOW";
        
        // Adjust speed based on unit type
        if (_is_infantry) then {
            _waypoint setWaypointSpeed "NORMAL";
        } else {
            _waypoint setWaypointSpeed "LIMITED";
        };
        
        // Additional SAD waypoints
        {
            _waypoint = _grp addWaypoint [_x, 10];
            _waypoint setWaypointType "SAD";
        } forEach (_wpPositions select [1, 4]);
        
        // Last waypoint cycles back to the first
        _waypoint = _grp addWaypoint [_wpPositions select 0, 10];
        _waypoint setWaypointType "CYCLE";
        
        // Set the current waypoint to the first one
        _grp setCurrentWaypoint [_grp, 0];
    };
};

// Initial delay before setting up waypoints
[{
    params ["_grp", "_flagpos", "_basepos", "_is_infantry", "_fnc_setupDefensiveWaypoints", "_fnc_setupCombatWaypoints", "_fnc_clearWaypoints"];
    
    // Create initial patrol/garrison waypoints
    [_grp, _flagpos, _basepos, _is_infantry] call _fnc_setupDefensiveWaypoints;
    
    // Set up a handler to check for enemies
    [{
        params ["_args", "_idPFH"];
        _args params ["_grp", "_basepos", "_is_infantry", "_fnc_setupCombatWaypoints"];
        
        // If all group members are dead or an enemy is detected
        if (({alive _x} count (units _grp) == 0) || !(isNull ((leader _grp) findNearestEnemy (leader _grp)))) then {
            // Remove the per-frame handler
            [_idPFH] call CBA_fnc_removePerFrameHandler;
            
            // If group has living members, switch to combat waypoints
            if ({alive _x} count (units _grp) > 0) then {
                [_grp, _basepos, _is_infantry] call _fnc_setupCombatWaypoints;
            };
        };
    }, 10, [_grp, _basepos, _is_infantry, _fnc_setupCombatWaypoints]] call CBA_fnc_addPerFrameHandler;
    
}, [_grp, _flagpos, _basepos, _is_infantry, _fnc_setupDefensiveWaypoints, _fnc_setupCombatWaypoints, _fnc_clearWaypoints], 5] call CBA_fnc_waitAndExecute;
