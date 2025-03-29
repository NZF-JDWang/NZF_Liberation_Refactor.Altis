/*
    Function: KPLIB_fnc_spawnBattlegroup
    
    Description:
        Spawns an enemy battlegroup of vehicles or infantry that will attack the nearest blufor objective.
        Uses non-blocking CBA functions instead of scheduled execution.
    
    Parameters:
        _spawn_marker - [String] Marker name for spawn position, can be "" for auto-selection
        _infOnly - [Boolean] True to spawn infantry-only battlegroup (default: false)
    
    Returns:
        Array of created groups
    
    Examples:
        (begin example)
        ["", false] call KPLIB_fnc_spawnBattlegroup;
        (end)
        
        (begin example)
        [_sector_marker, true] call KPLIB_fnc_spawnBattlegroup;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-30
*/

params [
    ["_spawn_marker", "", [""]],
    ["_infOnly", false, [false]]
];

if (GRLIB_endgame == 1) exitWith {[]};

// Find a valid spawn position
_spawn_marker = [[2000, 1000] select _infOnly, 3000, false, markerPos _spawn_marker] call KPLIB_fnc_getOpforSpawnPoint;

if (_spawn_marker isEqualTo "") exitWith {[]};

// Set timestamp and initialize variables
GRLIB_last_battlegroup_time = diag_tickTime;

private _bg_groups = [];
private _selected_opfor_battlegroup = [];
private _target_size = (round (GRLIB_battlegroup_size * ([] call KPLIB_fnc_getOpforFactor) * (sqrt GRLIB_csat_aggressivity))) min 16;
if (combat_readiness < 60) then {_target_size = round (_target_size * 0.65);};

// Notify players of battlegroup
[_spawn_marker] remoteExec ["remote_call_battlegroup"];

// Create terrain clearance if needed
if (worldName in KP_liberation_battlegroup_clearance) then {
    [markerPos _spawn_marker, 15] call KPLIB_fnc_createClearance;
};

// Function to handle the AI behavior assignment
private _fnc_setupBattlegroupAI = {
    params ["_group"];
    
    private _objective = [getPos (leader _group)] call KPLIB_fnc_getNearestBluforObjective;
    
    // Create waypoints using non-blocking approach
    while {!((waypoints _group) isEqualTo [])} do {deleteWaypoint ((waypoints _group) select 0);};
    {_x doFollow (leader _group)} forEach (units _group);
    
    private _waypoint = _group addWaypoint [_objective, 100];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointSpeed "NORMAL";
    _waypoint setWaypointBehaviour "AWARE";
    _waypoint setWaypointCombatMode "YELLOW";
    _waypoint setWaypointCompletionRadius 30;
    
    _waypoint = _group addWaypoint [_objective, 100];
    _waypoint setWaypointType "SAD";
    _waypoint = _group addWaypoint [_objective, 100];
    _waypoint setWaypointType "SAD";
    _waypoint = _group addWaypoint [_objective, 100];
    _waypoint setWaypointType "SAD";
    _waypoint = _group addWaypoint [_objective, 100];
    _waypoint setWaypointType "CYCLE";
    
    // Monitor group status non-blockingly
    [
        {
            params ["_args", "_handle"];
            _args params ["_group"];
            
            if (
                (((units _group) select {alive _x}) isEqualTo []) || 
                {reset_battlegroups_ai} || 
                {GRLIB_endgame == 1}
            ) then {
                // Clean up
                reset_battlegroups_ai = false;
                [_handle] call CBA_fnc_removePerFrameHandler;
                
                // Restart AI if needed
                if (!((units _group) isEqualTo []) && {GRLIB_endgame == 0}) then {
                    [_group] call KPLIB_fnc_spawnBattlegroupAI;
                };
            };
        },
        5,
        [_group]
    ] call CBA_fnc_addPerFrameHandler;
};

// Spawn infantry-only battlegroup
if (_infOnly) then {
    // Infantry units to choose from
    private _infClasses = [KPLIB_o_inf_classes, militia_squad] select (combat_readiness < 50);
    
    // Adjust target size for infantry
    _target_size = 12 max (_target_size * 4);
    
    // Create infantry groups with up to 8 units per squad
    private _grp = [GRLIB_side_enemy] call KPLIB_fnc_createGroupOnHC;
    for "_i" from 0 to (_target_size - 1) do {
        if (_i > 0 && {(_i % 8) isEqualTo 0}) then {
            _bg_groups pushBack _grp;
            _grp = [GRLIB_side_enemy] call KPLIB_fnc_createGroupOnHC;
        };
        [selectRandom _infClasses, markerPos _spawn_marker, _grp] call KPLIB_fnc_createManagedUnit;
    };
    
    // Add the last group if not already added
    if !(_grp in _bg_groups) then {
        _bg_groups pushBack _grp;
    };
    
    // Apply AI to all infantry groups
    {
        [_x] call _fnc_setupBattlegroupAI;
    } forEach _bg_groups;
} else {
    // Vehicle battlegroup
    private _vehicle_pool = [opfor_battlegroup_vehicles, opfor_battlegroup_vehicles_low_intensity] select (combat_readiness < 50);
    
    // Select vehicles for battlegroup
    while {count _selected_opfor_battlegroup < _target_size} do {
        _selected_opfor_battlegroup pushback (selectRandom _vehicle_pool);
    };
    
    // Function to process vehicle spawning sequentially without sleep
    private _fnc_processVehicles = {
        params ["_vehicleTypes", "_index"];
        private _vehicleType = _vehicleTypes select _index;
        
        private _nextgrp = [GRLIB_side_enemy] call KPLIB_fnc_createGroupOnHC;
        private _vehicle = [markerpos _spawn_marker, _vehicleType] call KPLIB_fnc_spawnVehicle;
        
        (crew _vehicle) joinSilent _nextgrp;
        [_nextgrp] call _fnc_setupBattlegroupAI;
        _bg_groups pushback _nextgrp;
        
        if ((_vehicleType in opfor_troup_transports) && ([] call KPLIB_fnc_getOpforCap < GRLIB_battlegroup_cap)) then {
            if (_vehicle isKindOf "Air") then {
                [[markerPos _spawn_marker] call KPLIB_fnc_getNearestBluforObjective, _vehicle] call KPLIB_fnc_sendParatroopers;
            } else {
                // Convert to non-blocking troopTransport function
                [_vehicle] call KPLIB_fnc_troopTransport;
            };
        };
        
        // Process next vehicle or finish
        if (_index + 1 < count _vehicleTypes) then {
            [{
                _this call _fnc_processVehicles;
            }, [_vehicleTypes, _index + 1], 0.5] call CBA_fnc_waitAndExecute;
        } else {
            // All vehicles processed, spawn air support if needed
            if (GRLIB_csat_aggressivity > 0.9) then {
                [[markerPos _spawn_marker] call KPLIB_fnc_getNearestBluforObjective] call KPLIB_fnc_spawnAir;
            };
            
            // Update combat readiness and statistics
            combat_readiness = (combat_readiness - (round ((count _bg_groups) + (random (count _bg_groups))))) max 0;
            stats_hostile_battlegroups = stats_hostile_battlegroups + 1;
            
            // No longer needed: groups are already created on HC
            // [_bg_groups] call KPLIB_fnc_transferGroupsToHC;
        };
    };
    
    // Start processing vehicles
    if (count _selected_opfor_battlegroup > 0) then {
        [_selected_opfor_battlegroup, 0] call _fnc_processVehicles;
    };
};

_bg_groups 