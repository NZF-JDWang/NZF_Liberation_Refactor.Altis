/*
    Function: KPLIB_fnc_spawnBattlegroupAI
    
    Description:
        Sets up AI behavior for battlegroup units to attack the nearest blufor objective.
        Uses non-blocking CBA functions instead of scheduled execution.
    
    Parameters:
        _group - [Group] The group to assign AI behavior to
    
    Returns:
        None
    
    Examples:
        (begin example)
        [_group] call KPLIB_fnc_spawnBattlegroupAI;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-30
*/

params [
    ["_grp", grpNull, [grpNull]]
];

if (isNull _grp) exitWith {};
if (isNil "reset_battlegroups_ai") then {reset_battlegroups_ai = false};

// Delay execution without blocking
[{
    params ["_grp"];
    
    if (isNull _grp || {(units _grp) isEqualTo []}) exitWith {};
    
    private _objPos = [getPos (leader _grp)] call KPLIB_fnc_getNearestBluforObjective;
    
    // Notify players of incoming enemies
    [_objPos] remoteExec ["remote_call_incoming"];
    
    private _startpos = getPos (leader _grp);
    
    // Setup waypoints and monitor movement
    private _moveHandle = [{
        params ["_args", "_handle"];
        _args params ["_grp", "_objPos", "_startpos"];
        
        // Check if we need to exit early
        if (
            isNull _grp || 
            {(units _grp) isEqualTo []} || 
            {GRLIB_endgame == 1} || 
            {(getPos (leader _grp)) distance _startpos >= 100}
        ) then {
            [_handle] call CBA_fnc_removePerFrameHandler;
            
            // If we exited because the group moved enough, we're done
            if (!isNull _grp && {!((units _grp) isEqualTo [])} && {GRLIB_endgame == 0}) then {
                // Start monitoring the group for cleanup
                [
                    {
                        params ["_args", "_handle"];
                        _args params ["_grp"];
                        
                        if (
                            isNull _grp || 
                            {(((units _grp) select {alive _x}) isEqualTo [])} || 
                            {reset_battlegroups_ai} || 
                            {GRLIB_endgame == 1}
                        ) then {
                            [_handle] call CBA_fnc_removePerFrameHandler;
                            reset_battlegroups_ai = false;
                            
                            // Restart AI if needed
                            if (!isNull _grp && {!((units _grp) isEqualTo [])} && {GRLIB_endgame == 0}) then {
                                [{
                                    [_this] call KPLIB_fnc_spawnBattlegroupAI;
                                }, _grp, 5 + (random 5)] call CBA_fnc_waitAndExecute;
                            };
                        };
                    },
                    5,
                    [_grp]
                ] call CBA_fnc_addPerFrameHandler;
            };
            
            // Exit early
            if (true) exitWith {};
        };
        
        // If we're still here, recreate waypoints
        while {!((waypoints _grp) isEqualTo [])} do {deleteWaypoint ((waypoints _grp) select 0);};
        {_x doFollow leader _grp} forEach units _grp;
        
        private _waypoint = _grp addWaypoint [_objPos, 100];
        _waypoint setWaypointType "MOVE";
        _waypoint setWaypointSpeed "NORMAL";
        _waypoint setWaypointBehaviour "AWARE";
        _waypoint setWaypointCombatMode "YELLOW";
        _waypoint setWaypointCompletionRadius 30;
        
        _waypoint = _grp addWaypoint [_objPos, 100];
        _waypoint setWaypointType "SAD";
        _waypoint = _grp addWaypoint [_objPos, 100];
        _waypoint setWaypointType "SAD";
        _waypoint = _grp addWaypoint [_objPos, 100];
        _waypoint setWaypointType "SAD";
        _waypoint = _grp addWaypoint [_objPos, 100];
        _waypoint setWaypointType "CYCLE";
        
    }, 90, [_grp, _objPos, _startpos]] call CBA_fnc_addPerFrameHandler;
    
}, [_grp], 5 + (random 5)] call CBA_fnc_waitAndExecute; 