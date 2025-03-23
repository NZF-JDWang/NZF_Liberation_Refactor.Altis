/*
    Function: KPLIB_fnc_spawnAir
    
    Description:
        Spawns enemy air support to attack a specific objective.
        Uses non-blocking CBA functions instead of scheduled execution.
    
    Parameters:
        _objective - [Position] The position to attack
    
    Returns:
        Boolean - True if planes were spawned, false otherwise
    
    Examples:
        (begin example)
        [getMarkerPos "target_marker"] call KPLIB_fnc_spawnAir;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-30
*/

params [
    ["_first_objective", [0,0,0], [[]]]
];

if (opfor_air isEqualTo []) exitWith {false};
if (_first_objective isEqualTo [0,0,0]) exitWith {false};

private _planes_number = ((floor linearConversion [40, 100, combat_readiness, 1, 3]) min 3) max 0;

if (_planes_number < 1) exitWith {false};

private _class = selectRandom opfor_air;
private _spawnPoint = ([sectors_airspawn, [_first_objective], {(markerPos _x) distance _input0}, "ASCEND"] call BIS_fnc_sortBy) select 0;
private _spawnPos = [];
private _plane = objNull;
private _grp = createGroup [GRLIB_side_enemy, true];

// Spawn planes one at a time with non-blocking approach
private _fnc_spawnNextPlane = {
    params ["_remainingCount", "_class", "_spawnPoint", "_first_objective", "_grp"];
    
    if (_remainingCount <= 0) exitWith {
        // All planes spawned, setup waypoints
        [{
            params ["_grp", "_first_objective"];
            
            if (isNull _grp) exitWith {};
            
            // Clear existing waypoints
            while {!((waypoints _grp) isEqualTo [])} do {
                deleteWaypoint ((waypoints _grp) select 0);
            };
            
            // Make units follow leader
            {_x doFollow leader _grp} forEach (units _grp);
            
            // Create attack waypoints
            private _waypoint = _grp addWaypoint [_first_objective, 500];
            _waypoint setWaypointType "MOVE";
            _waypoint setWaypointSpeed "FULL";
            _waypoint setWaypointBehaviour "AWARE";
            _waypoint setWaypointCombatMode "RED";
            
            _waypoint = _grp addWaypoint [_first_objective, 500];
            _waypoint setWaypointType "MOVE";
            _waypoint setWaypointSpeed "FULL";
            _waypoint setWaypointBehaviour "AWARE";
            _waypoint setWaypointCombatMode "RED";
            
            _waypoint = _grp addWaypoint [_first_objective, 500];
            _waypoint setWaypointType "MOVE";
            _waypoint setWaypointSpeed "FULL";
            _waypoint setWaypointBehaviour "AWARE";
            _waypoint setWaypointCombatMode "RED";
            
            // Add SAD waypoints for patrolling the area
            for "_i" from 1 to 6 do {
                _waypoint = _grp addWaypoint [_first_objective, 500];
                _waypoint setWaypointType "SAD";
            };
            
            _waypoint = _grp addWaypoint [_first_objective, 500];
            _waypoint setWaypointType "CYCLE";
            
            // Set current waypoint
            _grp setCurrentWaypoint [_grp, 2];
            
            // Transfer to headless client if available
            [_grp] call KPLIB_fnc_transferGroupToHC;
        }, [_grp, _first_objective], 1] call CBA_fnc_waitAndExecute;
    };
    
    // Spawn a plane
    private _spawnPos = markerPos _spawnPoint;
    _spawnPos = [(((_spawnPos select 0) + 500) - random 1000), (((_spawnPos select 1) + 500) - random 1000), 200];
    private _plane = createVehicle [_class, _spawnPos, [], 0, "FLY"];
    createVehicleCrew _plane;
    
    _plane flyInHeight (120 + (random 180));
    _plane addMPEventHandler ["MPKilled", {_this spawn kill_manager}];
    [_plane] call KPLIB_fnc_addObjectInit;
    
    {
        _x addMPEventHandler ["MPKilled", {_this spawn kill_manager}];
    } forEach (crew _plane);
    
    (crew _plane) joinSilent _grp;
    
    // Schedule next plane spawn
    if (_remainingCount > 1) then {
        [{
            _this call _fnc_spawnNextPlane;
        }, [_remainingCount - 1, _class, _spawnPoint, _first_objective, _grp], 1] call CBA_fnc_waitAndExecute;
    } else {
        // Last plane spawned, move to waypoint setup
        [0, _class, _spawnPoint, _first_objective, _grp] call _fnc_spawnNextPlane;
    };
};

// Start spawning planes
[_planes_number, _class, _spawnPoint, _first_objective, _grp] call _fnc_spawnNextPlane;

true 