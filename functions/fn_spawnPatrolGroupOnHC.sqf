/*
    Function: KPLIB_fnc_spawnPatrolGroupOnHC
    
    Description:
        Spawns a patrol group with LAMBS Danger waypoints directly on a headless client.
        This function is specifically designed to work with LAMBS Danger as waypoints are lost when transferring groups.
        
    Parameters:
        _classnames    - Array of unit classnames to spawn [ARRAY]
        _position      - Position to spawn the group [POSITION]
        _patrolCenter  - Center position for patrol [POSITION]
        _patrolRadius  - Radius for patrol [NUMBER, defaults to 100]
        _side          - Side of the group to create [SIDE, defaults to GRLIB_side_enemy]
        
    Returns:
        The created group [GROUP] - Will be a null reference on machines other than where it was created
    
    Examples:
        (begin example)
        _group = [["O_Soldier_F", "O_Soldier_GL_F"], getPos player, getMarkerPos "patrol_center", 200] call KPLIB_fnc_spawnPatrolGroupOnHC;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-16
*/

params [
    ["_classnames", [], [[]]],
    ["_position", [0,0,0], [[], objNull], [2, 3]],
    ["_patrolCenter", [0,0,0], [[], objNull], [2, 3]],
    ["_patrolRadius", 100, [0]],
    ["_side", GRLIB_side_enemy, [east]]
];

// Verify parameters
if (_classnames isEqualTo []) exitWith {
    ["Empty classnames array provided"] call BIS_fnc_error;
    grpNull
};

// Get the least loaded headless client
private _hc = [] call KPLIB_fnc_getLessLoadedHC;
private _target = if (isNull _hc) then {2} else {_hc}; // 2 = server, HC = headless client object

// This code will run on the HC or server
private _fnc_createPatrolGroup = {
    params ["_classnames", "_position", "_patrolCenter", "_patrolRadius", "_side"];
    
    diag_log format ["[KPLIB][HC] Creating patrol group with %1 units at position %2", count _classnames, _position];
    
    // Create the group
    private _group = createGroup [_side, true];
    
    // Spawn each unit
    {
        private _unit = _group createUnit [_x, _position, [], 20, "FORM"];
        _unit addMPEventHandler ["MPKilled", {_this spawn kill_manager}];
        [_unit] call KPLIB_fnc_addObjectInit;
    } forEach _classnames;
    
    // Set up LAMBS Danger if available
    if (isClass (configFile >> "CfgPatches" >> "lambs_wp")) then {
        // Calculate a weighted random behavior
        private _behavior = selectRandomWeighted [
            "PATROL", 0.4,  // Standard patrol
            "GARRISON", 0.3, // Garrison buildings
            "SENTRY", 0.3    // Act as sentries
        ];
        
        switch (_behavior) do {
            case "PATROL": {
                // Use LAMBS patrol
                [_group, _patrolCenter, _patrolRadius, [], false, true, -1, true] call lambs_wp_fnc_taskPatrol;
                diag_log format ["[KPLIB][HC] Group %1 assigned LAMBS patrol at %2 with radius %3", _group, _patrolCenter, _patrolRadius];
            };
            case "GARRISON": {
                // Use LAMBS garrison
                [_group, _patrolCenter, _patrolRadius, [], false, true] call lambs_wp_fnc_taskGarrison;
                diag_log format ["[KPLIB][HC] Group %1 assigned LAMBS garrison at %2 with radius %3", _group, _patrolCenter, _patrolRadius];
            };
            case "SENTRY": {
                // Use LAMBS camp/sentry
                [_group, _patrolCenter, [], 100, true, true, true, true, true] call lambs_wp_fnc_taskCamp;
                diag_log format ["[KPLIB][HC] Group %1 assigned LAMBS camp/sentry at %2", _group, _patrolCenter];
            };
        };
    } else {
        // Fallback to vanilla patrol if LAMBS is not available
        [_group, _patrolCenter, _patrolRadius] call BIS_fnc_taskPatrol;
        diag_log format ["[KPLIB][HC] Group %1 assigned vanilla patrol at %2 with radius %3", _group, _patrolCenter, _patrolRadius];
    };
    
    // Set the group's combat mode and behavior
    _group setCombatMode "YELLOW";
    _group setBehaviour "AWARE";
    
    // Return the group
    _group
};

// Execute the function on the HC or server
private _group = [_classnames, _position, _patrolCenter, _patrolRadius, _side] remoteExecCall ["BIS_fnc_call", _target, false];

// Return the group (will be null on machines other than where it was created)
_group 