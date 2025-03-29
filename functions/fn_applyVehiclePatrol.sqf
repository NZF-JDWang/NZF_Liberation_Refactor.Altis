/*
    Function: KPLIB_fnc_applyVehiclePatrol
    
    Description:
        Applies simple patrol behavior to vehicle groups.
        Creates a basic set of waypoints with some randomization.
        Streamlined specifically for vehicle AI.
        
    Parameters:
        _grp - The group to apply patrol behavior to [GROUP]
        _position - The center position for patrol [POSITION ARRAY]
        _radius - Radius for patrol operations [NUMBER, defaults to 150]
        
    Returns:
        True on successful application [BOOL]
    
    Author: [NZF] JD Wang
    Date: 2024-03-26
*/

params [
    ["_grp", grpNull, [grpNull]],
    ["_position", [0,0,0], [[]], [2,3]],
    ["_radius", 150, [0]]
];

// Exit with failure if group is invalid
if (isNull _grp) exitWith { 
    diag_log "[KPLIB] VEHICLE PATROL ERROR: Cannot apply vehicle patrol to null group";
    false 
};

// Enhanced locality checking with debug output
if (!local _grp) exitWith {
    if (KP_liberation_debug) then {
        diag_log format ["[KPLIB] VEHICLE PATROL: Group %1 is not local (owner: %2) - forwarding vehicle patrol", 
            _grp, groupOwner _grp];
    };
    
    // Use a JIP-enabled remoteExec to ensure the command reaches the target
    private _jipID = format ["vehpatrol_%1_%2", _grp, time];
    [_grp, _position, _radius] remoteExecCall ["KPLIB_fnc_applyVehiclePatrol", groupOwner _grp, _jipID];
    
    true
};

// Get vehicle information for detailed logging
private _veh = vehicle (leader _grp);
private _vehType = typeOf _veh;
private _unitCount = count units _grp;

// Clear any existing waypoints
private _existingWPs = count (waypoints _grp);
while {count (waypoints _grp) > 0} do {
    deleteWaypoint ((waypoints _grp) select 0);
};

// Set basic behavior
_grp setBehaviour "AWARE";
_grp setCombatMode "YELLOW";
_grp setSpeedMode "LIMITED";

// Get appropriate completion radius based on vehicle type
private _isArmored = _veh isKindOf "Tank" || _veh isKindOf "Wheeled_APC_F";
private _completionRadius = if (_isArmored) then {40} else {25};

// Check and log driver information
private _driver = driver _veh;
private _hasDriver = !isNull _driver;

// Ensure there's a driver in the vehicle
if (!_hasDriver && {_veh emptyPositions "driver" > 0}) then {
    // Find a unit in the group to make driver
    {
        if (_x moveInDriver _veh) exitWith {
            _hasDriver = true;
            _driver = _x;
        };
    } forEach (units _grp);
};

// Create first waypoint at current position
private _wp = _grp addWaypoint [_position, 0];
_wp setWaypointType "MOVE";
_wp setWaypointCompletionRadius _completionRadius;

// Create a non-circular patrol pattern (4-6 waypoints)
private _waypointCount = 4 + (floor random 3);

private _createdWPs = 1; // Count initial waypoint
for "_i" from 1 to _waypointCount do {
    // Create randomization factors for non-predictable pattern
    private _angle = random 360;
    private _dist = (_radius * 0.5) + (random (_radius * 0.5));
    private _wpPos = _position getPos [_dist, _angle];
    
    // Try to find road within 100m
    private _road = [_wpPos, 100] call BIS_fnc_nearestRoad;
    private _isRoad = !isNull _road;
    if (_isRoad) then {
        _wpPos = getPos _road;
    };
    
    // Create waypoint
    _wp = _grp addWaypoint [_wpPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius _completionRadius;
    _createdWPs = _createdWPs + 1;
    
    // Add random timeout to some waypoints
    if (_i % 2 == 0) then {
        _wp setWaypointTimeout [10, 30, 45];
    };
};

// Close the cycle
_wp = _grp addWaypoint [_position, 0];
_wp setWaypointType "CYCLE";
_wp setWaypointCompletionRadius _completionRadius;
_createdWPs = _createdWPs + 1;

// Set current waypoint to start movement
_grp setCurrentWaypoint [_grp, 0];

// Force driver to start following waypoints
if (!isNull _driver) then {
    _driver doFollow (leader _grp);
    
    // Ensure all necessary AI features are enabled for driver
    {_driver enableAI _x} forEach ["PATH", "MOVE", "TARGET", "AUTOTARGET"];
    
    // Force driver to accept commands
    _driver setVariable ["BIS_noCoreConversations", true];
    
    // Set speed to ensure movement starts
    _grp setSpeedMode "NORMAL"; 
    
    // Directly order driver to move to first waypoint position
    if (count waypoints _grp > 0) then {
        private _wpPos = waypointPosition [_grp, 0];
        _driver doMove _wpPos;
    };
} else {
    if (KP_liberation_debug) then {
        diag_log format ["[KPLIB] VEHICLE PATROL ERROR: No driver available for %1, waypoints may not work", _veh];
    };
    
    // Emergency driver assignment attempt - last ditch effort
    private _crewMembers = crew _veh;
    if (count _crewMembers > 0 && _veh emptyPositions "driver" > 0) then {
        private _potentialDriver = _crewMembers select 0;
        if (_potentialDriver moveInDriver _veh) then {
            if (KP_liberation_debug) then {
                diag_log format ["[KPLIB] VEHICLE PATROL: Emergency driver assignment of %1 to %2", _potentialDriver, _veh];
            };
            
            // Retry waypoint movement with new driver
            _potentialDriver doFollow (leader _grp);
            {_potentialDriver enableAI _x} forEach ["PATH", "MOVE"];
            
            if (count waypoints _grp > 0) then {
                private _wpPos = waypointPosition [_grp, 0];
                _potentialDriver doMove _wpPos;
            };
        };
    };
};

// Check and verify waypoints were created
private _finalWPCount = count waypoints _grp;
if (KP_liberation_debug && _finalWPCount < _createdWPs) then {
    diag_log format ["[KPLIB] VEHICLE PATROL ERROR: Expected %1 waypoints but only %2 exist for %3", _createdWPs, _finalWPCount, _veh];
};

// Return success
true 