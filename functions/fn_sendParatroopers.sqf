/*
    Function: KPLIB_fnc_sendParatroopers
    
    Description:
        Spawns and manages paratroopers that drop at a specified target position.
        Handles all aspects of the paradrop including vehicle creation, unit spawning,
        and coordinating the drop sequence using non-blocking CBA functions.
        Uses LAMBS AI modules for enhanced AI behavior when available.
    
    Parameters:
        _targetsector - Target sector marker name or position [String or Array]
        _chopper_type - Optional pre-existing chopper to use [Object] (Default: objNull, spawns new chopper)
    
    Returns:
        Boolean - True if paratroopers were spawned successfully, false otherwise
    
    Examples:
        (begin example)
        // Send paratroopers to a sector marker
        [_sectorMarker] call KPLIB_fnc_sendParatroopers;
        
        // Send paratroopers using an existing helicopter
        [_targetPosition, _existingHelicopter] call KPLIB_fnc_sendParatroopers;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-21
*/

params [
    ["_targetsector", "", ["",[]]],
    ["_chopper_type", objNull, [objNull]]
];

if (_targetsector isEqualTo "" || opfor_choppers isEqualTo []) exitWith {false};

private _targetpos = _targetsector;
if (_targetpos isEqualType "") then {
    _targetpos = markerPos _targetsector;
};

// Find suitable spawn sector
private _spawnsector = ([sectors_airspawn, [_targetpos], {(markerpos _x) distance _input0}, "ASCEND"] call BIS_fnc_sortBy) select 0;
private _newvehicle = objNull;
private _pilot_group = grpNull;

// Check if LAMBS AI modules are available
private _lambs_available = isClass (configFile >> "CfgPatches" >> "lambs_wp");

// Function to handle vehicle creation and crew setup
private _fnc_createChopper = {
    private _chopper_type = selectRandom opfor_choppers;

    // Choose a transport chopper
    while {!(_chopper_type in opfor_troup_transports)} do {
        _chopper_type = selectRandom opfor_choppers;
    };

    // Create vehicle at [0,0,0] for better performance and then move to position
    private _newvehicle = createVehicle [_chopper_type, [0,0,0], [], 0, "FLY"];
    _newvehicle setPos (markerpos _spawnsector);
    createVehicleCrew _newvehicle;
    
    private _pilot_group = createGroup [GRLIB_side_enemy, true];
    (crew _newvehicle) joinSilent _pilot_group;

    // Add kill handlers
    _newvehicle addMPEventHandler ["MPKilled", {_this spawn kill_manager}];
    {_x addMPEventHandler ["MPKilled", {_this spawn kill_manager}];} forEach (crew _newvehicle);

    [_newvehicle, _pilot_group]
};

// Handle new vehicle creation or use existing
if (isNull _chopper_type) then {
    private _result = call _fnc_createChopper;
    _result params ["_veh", "_grp"];
    _newvehicle = _veh;
    _pilot_group = _grp;
} else {
    _newvehicle = _chopper_type;
    _pilot_group = group _newvehicle;
};

// Create the paratroop group
private _para_group = createGroup [GRLIB_side_enemy, true];

// Add troops to the group with proper function
private _fnc_addParatrooper = {
    params ["_para_group", "_spawnsector", "_troop_count", "_newvehicle"];
    
    // Get the actual capacity of the helicopter from config instead of empty positions
    private _vehicleConfig = configFile >> "CfgVehicles" >> typeOf _newvehicle;
    private _transportSoldiers = getNumber (_vehicleConfig >> "transportSoldier");
    
    // If config doesn't have capacity info, fall back to emptyPositions
    private _vehicleCapacity = if (_transportSoldiers > 0) then {
        _transportSoldiers
    } else {
        _newvehicle emptyPositions "cargo"
    };
    
    // Add debug info
    diag_log format ["KPLIB_fnc_sendParatroopers: Vehicle %1 has capacity for %2 paratroopers", typeOf _newvehicle, _vehicleCapacity];
    
    private _actualTroopCount = _vehicleCapacity min _troop_count;
    diag_log format ["KPLIB_fnc_sendParatroopers: Will spawn %1 paratroopers", _actualTroopCount];
    
    // Simplify by creating all units at once to avoid recursive issues
    for "_i" from 1 to _actualTroopCount do {
        private _unit = [opfor_paratrooper, [0,0,0], _para_group] call KPLIB_fnc_createManagedUnit;
        
        // Proper assignment sequence to ensure unit stays in vehicle
        _unit assignAsCargo _newvehicle;
        [_unit] orderGetIn true;
        _unit moveInCargo _newvehicle;
        
        // Disable automatic dismounting
        _unit disableAI "MOVE";
        _unit setVariable ["acex_headless_blacklist", true, true]; // Prevent transfer by headless client
        
        diag_log format ["KPLIB_fnc_sendParatroopers: Created paratrooper %1 of %2", _i, _actualTroopCount];
    };
    
    // Set flag that we're done adding paratroopers
    _para_group setVariable ["KPLIB_paradrop_ready", true, true];
    diag_log format ["KPLIB_fnc_sendParatroopers: All paratroopers created: %1", count (units _para_group)];
    
    // Return the actual number of paratroopers created
    count (units _para_group)
};

// Initial call to add paratroopers - using the default 8 but will be limited by actual vehicle capacity
private _paraCount = [_para_group, _spawnsector, 8, _newvehicle] call _fnc_addParatrooper;
diag_log format ["KPLIB_fnc_sendParatroopers: %1 paratroopers added to helicopter", _paraCount];

// Helper function to setup paratrooper loadout and team organization
private _fnc_setupParaTroops = {
    params ["_para_group", "_newvehicle"];
    
    // First assign team colors and roles for better tactical behavior
    private _units = units _para_group;
    private _teamLeader = _units select 0;
    
    // Designate team leader
    _teamLeader setRank "SERGEANT";
    
    if (count _units >= 3) then {
        // First fire team (Red)
        for "_i" from 0 to 3 min (count _units - 1) do {
            private _unit = _units select _i;
            _unit assignTeam "RED";
            if (_i == 1) then { _unit setRank "CORPORAL"; }; // Team leader
        };
        
        // Second fire team (Blue) if enough members
        if (count _units >= 5) then {
            for "_i" from 4 to 7 min (count _units - 1) do {
                private _unit = _units select _i;
                _unit assignTeam "BLUE";
                if (_i == 4) then { _unit setRank "CORPORAL"; }; // Team leader
            };
        };
    };
    
    // Give them parachutes and ensure they stay in the helicopter
    {
        removeBackpack _x;
        _x addBackpack "B_parachute";
        
        // Ensure they're properly assigned to the helicopter and won't get out on their own
        if !(_x in _newvehicle) then {
            _x assignAsCargo _newvehicle;
            [_x] orderGetIn true;
            _x moveInCargo _newvehicle;
        };
        
        // Disable AI movement until jump time
        _x disableAI "MOVE";
    } forEach _units;
};

// Helper function to setup waypoints for the helicopter
private _fnc_setupWaypoints = {
    params ["_pilot_group", "_para_group", "_targetpos", "_newvehicle"];
    
    // Clear existing waypoints
    while {(count (waypoints _pilot_group)) != 0} do {
        deleteWaypoint ((waypoints _pilot_group) select 0);
    };
    while {(count (waypoints _para_group)) != 0} do {
        deleteWaypoint ((waypoints _para_group) select 0);
    };
    
    // Have units follow leaders
    {_x doFollow leader _pilot_group} forEach units _pilot_group;
    {_x doFollow leader _para_group} forEach units _para_group;
    
    // Set helicopter height - higher altitude for safer drop
    _newvehicle flyInHeight 150;
    
    // Use a slightly randomized approach vector
    private _approachVector = _targetpos getPos [400, random 360];
    
    // Set pilot group waypoints
    private _waypoint = _pilot_group addWaypoint [_approachVector, 50];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointSpeed "FULL";
    _waypoint setWaypointBehaviour "CARELESS";
    _waypoint setWaypointCombatMode "BLUE";
    _waypoint setWaypointCompletionRadius 100;
    
    _waypoint = _pilot_group addWaypoint [_targetpos, 25];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointSpeed "NORMAL";
    _waypoint setWaypointBehaviour "CARELESS";
    _waypoint setWaypointCombatMode "BLUE";
    _waypoint setWaypointCompletionRadius 100;
    
    // Add egress waypoints away from the drop zone
    private _egressPos = _targetpos getPos [700, ((_targetpos getDir _approachVector) + 180) % 360];
    
    _waypoint = _pilot_group addWaypoint [_egressPos, 100];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointCompletionRadius 100;
    
    _pilot_group setCurrentWaypoint [_pilot_group, 1];
    
    // Para group only needs a single waypoint to the target initially
    _waypoint = _para_group addWaypoint [_targetpos, 50];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointSpeed "NORMAL";
    _waypoint setWaypointBehaviour "COMBAT";
    _waypoint setWaypointCombatMode "YELLOW";
    _waypoint setWaypointCompletionRadius 50;
    
    // Set helicopter height again to ensure it stays at proper altitude
    _newvehicle flyInHeight 150;
};

// Helper function to stagger paratrooper drops
private _fnc_dropParatroopers = {
    params ["_para_group", "_newvehicle", "_targetpos"];
    
    // Execute staggered jumps from the helicopter's actual position
    private _jumpDelay = 0.3; // Delay between jumps in seconds
    private _jumpIndex = 0;
    
    {
        private _unit = _x;
        
        // Schedule the jump with delay
        [{
            params ["_unit", "_vehicle"];
            
            if (!alive _unit || !alive _vehicle) exitWith {};
            
            // Get current helicopter position when it's time to jump
            if (_unit in _vehicle) then {
                // Re-enable AI movement before jumping
                _unit enableAI "MOVE";
                
                // Proper sequence to exit vehicle
                _unit leaveVehicle _vehicle;
                unassignVehicle _unit;
                [_unit] orderGetIn false;
                moveOut _unit;
                
                // Give unit a small push in a random direction for spacing
                // This helps spread the paratroopers out and prevents collision
                [_unit, [(random 2) - 1, (random 2) - 1, 0]] remoteExec ["setVelocity", _unit];
            };
        }, [_unit, _newvehicle], _jumpIndex * _jumpDelay] call CBA_fnc_waitAndExecute;
        
        _jumpIndex = _jumpIndex + 1;
    } forEach (units _para_group);
};

// Helper function to setup attack waypoints after drop using LAMBS if available
private _fnc_setupAttackWaypoints = {
    params ["_pilot_group", "_para_group", "_targetpos", "_newvehicle", "_lambs_available", "_spawnsector"];
    
    // Clear existing waypoints
    while {(count (waypoints _pilot_group)) != 0} do {
        deleteWaypoint ((waypoints _pilot_group) select 0);
    };
    while {(count (waypoints _para_group)) != 0} do {
        deleteWaypoint ((waypoints _para_group) select 0);
    };
    
    // Have units follow leaders
    {_x doFollow leader _pilot_group} forEach units _pilot_group;
    {_x doFollow leader _para_group} forEach units _para_group;
    
    // Set helicopter height for return flight
    _newvehicle flyInHeight 100;
    
    // Check if helicopter has weapons
    private _hasWeapons = false;
    private _weapons = weapons _newvehicle;
    {
        if (!(_x in ["CMFlareLauncher", "SmokeLauncher"])) exitWith { _hasWeapons = true; };
    } forEach _weapons;
    
    diag_log format ["KPLIB_fnc_sendParatroopers: Helicopter has weapons: %1", _hasWeapons];
    
    // Handle pilot group behavior based on whether chopper has weapons
    if (_hasWeapons) then {
        // Set pilot group attack waypoints - basic SAD behavior for armed helicopters
        private _waypoint = _pilot_group addWaypoint [_targetpos, 200];
        _waypoint setWaypointBehaviour "COMBAT";
        _waypoint setWaypointCombatMode "RED";
        _waypoint setWaypointType "SAD";
        
        _waypoint = _pilot_group addWaypoint [_targetpos, 200];
        _waypoint setWaypointBehaviour "COMBAT";
        _waypoint setWaypointCombatMode "RED";
        _waypoint setWaypointType "SAD";
        
        _pilot_group setCurrentWaypoint [_pilot_group, 1];
    } else {
        // Set pilot group return to base waypoint for unarmed helicopters
        private _spawnPos = markerPos _spawnsector;
        private _returnWP = _pilot_group addWaypoint [_spawnPos, 100];
        _returnWP setWaypointType "MOVE";
        _returnWP setWaypointSpeed "FULL";
        _returnWP setWaypointBehaviour "CARELESS";
        _returnWP setWaypointCombatMode "BLUE";
        _returnWP setWaypointStatements ["true", "
            {deleteVehicle _x} forEach (crew vehicle this); 
            deleteVehicle vehicle this; 
            deleteGroup (group this);
        "];
        
        _pilot_group setCurrentWaypoint [_pilot_group, 0];
    };
    
    // Set para group ground attack behavior - use LAMBS if available
    if (_lambs_available) then {
        // Check if any friendlies (players or AI) are in buildings at or near the target area
        private _friendliesInBuildings = false;
        private _nearBuildings = _targetpos nearObjects ["Building", 150];
        
        if (count _nearBuildings > 0) then {
            // Get all units from BLUFOR or friendly side
            private _friendlyUnits = allUnits select {side _x == GRLIB_side_friendly || side _x == civilian};
            private _nearFriendlies = _friendlyUnits select {_x distance _targetpos < 200};
            
            {
                if ([_x] call BIS_fnc_isInsideBuilding) exitWith {
                    _friendliesInBuildings = true;
                };
            } forEach (_nearFriendlies + (allPlayers select {_x distance _targetpos < 200}));
        };
        
        // Split paratroopers into fire teams if there are enough of them
        private _units = units _para_group;
        
        private _distanceToTarget = leader _para_group distance _targetpos;
        private _enemyStrength = {side _x == GRLIB_side_friendly && _x distance _targetpos < 200} count allUnits;
        private _isUrbanEnvironment = count (_targetpos nearObjects ["Building", 100]) > 5;
        
        // Choose appropriate tactic
        if (_friendliesInBuildings) then {
            // CQB is still best for building clearing
            [_para_group, _targetpos, 150, 3] call lambs_wp_fnc_taskCQB;
        } else if (_isUrbanEnvironment && !_friendliesInBuildings) then {
            // Urban area but enemies not in buildings - use assault
            [_para_group, _targetpos, 150] call lambs_wp_fnc_taskAssault;
        } else if (_enemyStrength > 8 || _distanceToTarget > 300) then {
            // Strong resistance or distance - use methodical hunt
            [_para_group, _targetpos, 200] call lambs_wp_fnc_taskHunt;
        } else {
            // Quick assault for weak enemies or time-critical situations
            [_para_group, _targetpos, 150] call lambs_wp_fnc_taskRush;
        };
    } else {
        // Fallback to vanilla waypoints if LAMBS not available
        // More complex waypoint pattern around the target
        private _searchRadius = 100;
        
        // Create a search pattern
        for "_i" from 0 to 4 do {
            private _searchPos = _targetpos getPos [_searchRadius, _i * 72];
            _waypoint = _para_group addWaypoint [_searchPos, 25];
            _waypoint setWaypointType "SAD";
            _waypoint setWaypointBehaviour "COMBAT";
            _waypoint setWaypointCombatMode "RED";
        };
        
        // Add a cycle waypoint to keep searching
        _waypoint = _para_group addWaypoint [_targetpos, 50];
        _waypoint setWaypointType "CYCLE";
    };
};

// Wait for either the paratroopers to be ready or a timeout (3 seconds)
[{
    params ["_para_group"];
    _para_group getVariable ["KPLIB_paradrop_ready", false] || 
    (time > (_para_group getVariable ["KPLIB_paradrop_startTime", time]) + 3)
}, {
    params ["_para_group", "_newvehicle", "_pilot_group", "_targetpos", "_fnc_setupParaTroops", "_fnc_setupWaypoints", "_fnc_dropParatroopers", "_fnc_setupAttackWaypoints", "_lambs_available", "_spawnsector"];
    
    // Ensure we have at least one unit before proceeding
    if (count (units _para_group) == 0) exitWith {
        // If no units were created, clean up the helicopter and exit
        if (!isNull _newvehicle) then {
            {deleteVehicle _x} forEach (crew _newvehicle);
            deleteVehicle _newvehicle;
        };
        if (!isNull _pilot_group) then {
            deleteGroup _pilot_group;
        };
        deleteGroup _para_group;
    };
    
    // Debug message
    private _unitCount = count (units _para_group);
    diag_log format ["KPLIB_fnc_sendParatroopers: %1 paratroopers ready for deployment", _unitCount];
    
    // Setup paratroopers with parachutes and team organization
    [_para_group, _newvehicle] call _fnc_setupParaTroops;
    
    // Setup approach waypoints
    [_pilot_group, _para_group, _targetpos, _newvehicle] call _fnc_setupWaypoints;
    
    // Wait until chopper is near target or damaged
    [{
        params ["_newvehicle", "_targetpos"];
        !(alive _newvehicle) || (damage _newvehicle > 0.2) || (_newvehicle distance _targetpos < 300)
    }, {
        params ["_newvehicle", "_targetpos", "_para_group", "_pilot_group", "_fnc_setupAttackWaypoints", "_fnc_dropParatroopers", "_lambs_available", "_spawnsector"];
        
        // Execute the staggered drop
        [_para_group, _newvehicle, _targetpos] call _fnc_dropParatroopers;
        
        // After dropping troops, set attack waypoints with a delay to allow landing
        [{
            params ["_pilot_group", "_para_group", "_targetpos", "_newvehicle", "_fnc_setupAttackWaypoints", "_lambs_available", "_spawnsector"];
            [_pilot_group, _para_group, _targetpos, _newvehicle, _lambs_available, _spawnsector] call _fnc_setupAttackWaypoints;
        }, [_pilot_group, _para_group, _targetpos, _newvehicle, _fnc_setupAttackWaypoints, _lambs_available, _spawnsector], 10] call CBA_fnc_waitAndExecute;
        
    }, [_newvehicle, _targetpos, _para_group, _pilot_group, _fnc_setupAttackWaypoints, _fnc_dropParatroopers, _lambs_available, _spawnsector]] call CBA_fnc_waitUntilAndExecute;
    
}, [_para_group, _newvehicle, _pilot_group, _targetpos, _fnc_setupParaTroops, _fnc_setupWaypoints, _fnc_dropParatroopers, _fnc_setupAttackWaypoints, _lambs_available, _spawnsector]] call CBA_fnc_waitUntilAndExecute;

// Set the start time for timeout purposes
_para_group setVariable ["KPLIB_paradrop_startTime", time, true];

true 