/*
    Script: manage_one_civilian_patrol.sqf
    
    Description:
        Manages civilian patrols in sectors where players are present but friendly forces are not.
        Creates civilian foot patrols and civilian vehicles that move between sectors.
        
    Author: [NZF] JD Wang (refactored from original KP Liberation code)
    Date: 2024-11-16
*/

if (!isServer) exitWith {};

// Initialize variables
private [
    "_spawnsector", "_grp", "_usable_sectors", "_civnumber", "_spawnpos", "_civveh", 
    "_sectors_patrol", "_patrol_startpos", "_waypoint", "_grpspeed", "_sectors_patrol_random", 
    "_sectorcount", "_nextsector", "_nearestroad"
];

_civveh = objNull;

// Function to spawn the next civilian patrol
private _fnc_spawnNextPatrol = {
    if (GRLIB_endgame != 0) exitWith {};
    
    // Find usable sectors (no friendly units, players nearby)
    private _usable_sectors = [];
    {
        if ((([markerPos _x, 1000, GRLIB_side_friendly] call KPLIB_fnc_getUnitsCount) == 0) && 
            (count ([markerPos _x, 3500] call KPLIB_fnc_getNearbyPlayers) > 0)) then {
            _usable_sectors pushBack _x;
        }
    } forEach ((sectors_bigtown + sectors_capture + sectors_factory) - (active_sectors));
    
    // If sectors found, spawn a patrol
    if (_usable_sectors isEqualTo []) exitWith {
        // No suitable sectors, try again later
        [_fnc_spawnNextPatrol, [], 150 + (random 150)] call CBA_fnc_waitAndExecute;
    };
    
    // Select a random sector and create the group
    _spawnsector = selectRandom _usable_sectors;
    _grp = createGroup [GRLIB_side_civilian, true];
    
    // Decide if foot patrol or vehicle patrol
    if (random 100 < 33) then {
        // Foot patrol with 1-3 civilians
        _civnumber = 1 + (floor (random 2));
        for "_i" from 1 to _civnumber do {
            [selectRandom civilians, markerPos _spawnsector, _grp, "PRIVATE", 0.5] call KPLIB_fnc_createManagedUnit;
        };
        _grpspeed = "LIMITED";
    } else {
        // Vehicle patrol with driver
        _nearestroad = objNull;
        private _attempts = 0;
        while {(isNull _nearestroad) && (_attempts < 10)} do {
            _nearestroad = [(markerPos _spawnsector) getPos [random 100, random 360], 200, []] call BIS_fnc_nearestRoad;
            _attempts = _attempts + 1;
            if (_attempts < 10 && (isNull _nearestroad)) then {
                [CBA_fnc_directCall, [{}], 0.5] call CBA_fnc_waitAndExecute;
            };
        };
        
        // If we couldn't find a road, use the sector marker position
        if (isNull _nearestroad) then {
            _spawnpos = markerPos _spawnsector;
        } else {
            _spawnpos = getPos _nearestroad;
        };
        
        // Create civilian and vehicle
        [selectRandom civilians, _spawnpos, _grp, "PRIVATE", 0.5] call KPLIB_fnc_createManagedUnit;
        _civveh = (selectRandom civilian_vehicles) createVehicle [0,0,0];
        _civveh setPos _spawnpos;
        _civveh addMPEventHandler ['MPKilled', {_this spawn kill_manager}];
        _civveh addEventHandler ["HandleDamage", { 
            params ["_unit", "_selection", "_damage", "_source"];
            private _actualDamage = _damage;
            if ((side _source != GRLIB_side_friendly) && (side _source != GRLIB_side_enemy)) then {
                _actualDamage = 0;
            };
            _actualDamage
        }];
        
        // Put civilian in vehicle
        private _driver = (units _grp) select 0;
        if (!isNull _driver) then {
            _driver moveInDriver _civveh;
            _driver disableAI "FSM";
            _driver disableAI "AUTOCOMBAT";
        };
        _grpspeed = "LIMITED";
    };
    
    // Add damage handlers to all civilians in group
    {
        _x addEventHandler ["HandleDamage", { 
            params ["_unit", "_selection", "_damage", "_source"];
            private _actualDamage = _damage;
            if ((side _source != GRLIB_side_friendly) && (side _source != GRLIB_side_enemy)) then {
                _actualDamage = 0;
            };
            _actualDamage
        }];
    } forEach (units _grp);
    
    // Find patrol sectors within range of spawn that have players nearby
    _sectors_patrol = [];
    _patrol_startpos = getPos (leader _grp);
    {
        if ((_patrol_startpos distance (markerPos _x) < 5000) && 
            (count ([markerPos _x, 4000] call KPLIB_fnc_getNearbyPlayers) > 0)) then {
            _sectors_patrol pushBack _x;
        };
    } forEach (sectors_bigtown + sectors_capture + sectors_factory);
    
    // Randomize patrol sector order
    _sectors_patrol_random = [];
    _sectorcount = count _sectors_patrol;
    while {count _sectors_patrol_random < _sectorcount} do {
        _nextsector = selectRandom _sectors_patrol;
        _sectors_patrol_random pushBack _nextsector;
        _sectors_patrol = _sectors_patrol - [_nextsector];
    };
    
    // Clear any existing waypoints
    while {(count (waypoints _grp)) != 0} do {
        deleteWaypoint ((waypoints _grp) select 0);
    };
    
    // Make units follow group leader
    {_x doFollow leader _grp} forEach (units _grp);
    
    // Add waypoints to patrol sectors
    {
        _nearestroad = objNull;
        _nearestroad = [(markerPos _x) getPos [random 100, random 360], 200, []] call BIS_fnc_nearestRoad;
        private _waypointPos = markerPos _x;
        
        if (!isNull _nearestroad) then {
            _waypointPos = getPos _nearestroad;
            _waypoint = _grp addWaypoint [_waypointPos, 0];
        } else {
            _waypoint = _grp addWaypoint [_waypointPos, 100];
        };
        
        _waypoint setWaypointType "MOVE";
        _waypoint setWaypointSpeed _grpspeed;
        _waypoint setWaypointBehaviour "SAFE";
        _waypoint setWaypointCombatMode "BLUE";
        _waypoint setWaypointCompletionRadius 100;
    } forEach _sectors_patrol_random;
    
    // Add cycle waypoint to return to start
    _waypoint = _grp addWaypoint [_patrol_startpos, 100];
    _waypoint setWaypointType "CYCLE";
    
    // Monitor patrol for cleanup
    [_fnc_monitorPatrol, [_grp, _civveh], 30 + (random 30)] call CBA_fnc_waitAndExecute;
};

// Function to monitor patrol and clean up when needed
private _fnc_monitorPatrol = {
    params ["_grp", "_civveh"];
    
    // Check if group exists and has members
    if (isNull _grp || {count (units _grp) == 0}) exitWith {
        // Group already gone, spawn next patrol
        [_fnc_spawnNextPatrol, [], 150 + (random 150)] call CBA_fnc_waitAndExecute;
    };
    
    // Check if players are nearby
    if (count ([getPos leader _grp, 4000] call KPLIB_fnc_getNearbyPlayers) == 0) then {
        // No players nearby, clean up
        if (!isNull _civveh) then {
            if ({(alive _x) && (side group _x == GRLIB_side_friendly)} count (crew _civveh) == 0) then {
                deleteVehicle _civveh;
            };
        };
        
        {deleteVehicle _x} forEach (units _grp);
        deleteGroup _grp;
        
        // Spawn next patrol
        [_fnc_spawnNextPatrol, [], 150 + (random 150)] call CBA_fnc_waitAndExecute;
    } else {
        // Players still nearby, check again later
        [_fnc_monitorPatrol, [_grp, _civveh], 30 + (random 30)] call CBA_fnc_waitAndExecute;
    };
};

// Initialize active_sectors array if not defined
if (isNil "active_sectors") then {active_sectors = []};

// Start the civilian patrol system
[_fnc_spawnNextPatrol, [], 150 + (random 150)] call CBA_fnc_waitAndExecute;
