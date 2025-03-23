/*
    Function: KPLIB_fnc_spawnGroupOnHC
    
    Description:
        Spawns a group directly on the least loaded headless client.
        If no headless client is available, spawns locally on the server.
        This preserves LAMBS Danger waypoints which would otherwise be lost during transfer.
        
    Parameters:
        _classnames - Array of unit classnames to spawn [ARRAY]
        _position   - Position to spawn the group [POSITION]
        _side       - Side of the group to create [SIDE, defaults to GRLIB_side_enemy]
        _waypoints  - Optional array of waypoint data [ARRAY, defaults to []]
        _callback   - Optional callback function to execute on the group post-creation [CODE, defaults to {}]
        
    Returns:
        The created group [GROUP] - Will be a null reference on machines other than where it was created
    
    Examples:
        (begin example)
        _group = [["O_Soldier_F", "O_Soldier_GL_F"], getMarkerPos "myMarker", EAST] call KPLIB_fnc_spawnGroupOnHC;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-16
*/

params [
    ["_classnames", [], [[]]],
    ["_position", [0,0,0], [[], objNull], [2, 3]],
    ["_side", GRLIB_side_enemy, [east]],
    ["_waypoints", [], [[]]],
    ["_callback", {}, [{}]]
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
private _fnc_createGroup = {
    params ["_classnames", "_position", "_side", "_waypoints", "_callback"];
    
    diag_log format ["[KPLIB][HC] Creating group with %1 units at position %2", count _classnames, _position];
    
    // Create the group
    private _group = createGroup [_side, true];
    
    // Spawn each unit
    {
        private _unit = _group createUnit [_x, _position, [], 20, "FORM"];
        _unit addMPEventHandler ["MPKilled", {_this spawn kill_manager}];
        [_unit] call KPLIB_fnc_addObjectInit;
    } forEach _classnames;
    
    // Add waypoints if provided
    if (count _waypoints > 0) then {
        {
            _x params ["_wpPos", "_wpType", "_wpBehavior", "_wpSpeed", "_wpFormation", "_wpScript", "_wpTimeout"];
            
            private _wp = _group addWaypoint [_wpPos, 0];
            _wp setWaypointType _wpType;
            _wp setWaypointBehaviour _wpBehavior;
            _wp setWaypointSpeed _wpSpeed;
            _wp setWaypointFormation _wpFormation;
            
            if (_wpScript != "") then {
                _wp setWaypointScript _wpScript;
            };
            
            _wp setWaypointTimeout _wpTimeout;
        } forEach _waypoints;
    };
    
    // Execute callback if provided
    if (!isNil "_callback") then {
        [_callback, [_group]] call CBA_fnc_directCall;
    };
    
    // Return the group
    _group
};

// Execute the function on the HC or server
private _group = [_classnames, _position, _side, _waypoints, _callback] remoteExecCall ["BIS_fnc_call", _target, false];

// Return the group (will be null on machines other than where it was created)
_group 