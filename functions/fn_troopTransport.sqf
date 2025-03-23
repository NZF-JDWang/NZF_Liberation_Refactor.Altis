/*
    Function: KPLIB_fnc_troopTransport
    
    Description:
        Handles AI troop transport vehicles for enemy battlegroups.
        Uses non-blocking CBA functions instead of scheduled execution.
    
    Parameters:
        _transVeh - [Object] The transport vehicle
    
    Returns:
        None
    
    Examples:
        (begin example)
        [_vehicle] call KPLIB_fnc_troopTransport;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-30
*/

params [
    ["_transVeh", objNull, [objNull]]
];

if (isNull _transVeh) exitWith {};

private _transGrp = group (driver _transVeh);
private _start_pos = getPos _transVeh;
private _objPos = [getPos _transVeh] call KPLIB_fnc_getNearestBluforObjective;
private _unload_distance = 500;
private _crewcount = count crew _transVeh;

// Monitor transport until it reaches destination
[{
    params ["_args", "_handle"];
    _args params ["_transVeh", "_objPos", "_unload_distance", "_crewcount", "_start_pos"];
    
    // Exit if vehicle or driver is destroyed
    if (
        isNull _transVeh || 
        {!alive _transVeh} || 
        {!alive driver _transVeh} ||
        {(_transVeh distance _objPos < _unload_distance) && {!surfaceIsWater (getPos _transVeh)}}
    ) then {
        [_handle] call CBA_fnc_removePerFrameHandler;
        
        // Continue only if vehicle is still alive and in a suitable position
        if (alive _transVeh && {alive driver _transVeh}) then {
            private _transGrp = group (driver _transVeh);
            
            // Create infantry group
            private _infGrp = createGroup [GRLIB_side_enemy, true];
            
            {
                [_x, _start_pos, _infGrp, "PRIVATE", 0.5] call KPLIB_fnc_createManagedUnit;
            } foreach ([] call KPLIB_fnc_getSquadComp);
            
            // Load troops into vehicle
            {_x moveInCargo _transVeh} forEach (units _infGrp);
            
            // Clear existing waypoints
            while {count (waypoints _infGrp) > 0} do {deleteWaypoint ((waypoints _infGrp) select 0);};
            
            // Create synchronized waypoints for unloading troops
            private _transVehWp = _transGrp addWaypoint [getPos _transVeh, 0, 0];
            _transVehWp setWaypointType "TR UNLOAD";
            _transVehWp setWaypointCompletionRadius 200;
            
            private _infWp = _infGrp addWaypoint [getPos _transVeh, 0];
            _infWp setWaypointType "GETOUT";
            _infWp setWaypointCompletionRadius 200;
            
            _infWp synchronizeWaypoint [_transVehWp];
            
            // Make sure troops exit the vehicle
            {unassignVehicle _transVeh} forEach (units _infGrp);
            _infGrp leaveVehicle _transVeh;
            (units _infGrp) allowGetIn false;
            
            // Add waypoint for infantry to move away from the vehicle
            private _infWp_2 = _infGrp addWaypoint [getPos _transVeh, 250];
            _infWp_2 setWaypointType "MOVE";
            _infWp_2 setWaypointCompletionRadius 5;
            
            // Monitor unloading process
            [{
                params ["_args", "_handle"];
                _args params ["_transVeh", "_infGrp", "_transGrp", "_objPos", "_crewcount"];
                
                // Check if unloading is complete
                if (
                    isNull _transVeh || 
                    {!alive _transVeh} || 
                    {_crewcount >= count crew _transVeh}
                ) then {
                    [_handle] call CBA_fnc_removePerFrameHandler;
                    
                    // Vehicle is still alive, give it new orders
                    if (alive _transVeh && {alive driver _transVeh}) then {
                        // Clear transport waypoints and set to attack
                        [{
                            params ["_transGrp", "_objPos"];
                            
                            if (isNull _transGrp) exitWith {};
                            
                            while {count (waypoints _transGrp) > 0} do {
                                deleteWaypoint ((waypoints _transGrp) select 0);
                            };
                            
                            private _transVehWp = _transGrp addWaypoint [_objPos, 100];
                            _transVehWp setWaypointType "SAD";
                            _transVehWp setWaypointSpeed "NORMAL";
                            _transVehWp setWaypointBehaviour "COMBAT";
                            _transVehWp setWaypointCombatMode "RED";
                            _transVehWp setWaypointCompletionRadius 30;
                            
                            _transVehWp = _transGrp addWaypoint [_objPos, 100];
                            _transVehWp setWaypointType "SAD";
                            
                            _transVehWp = _transGrp addWaypoint [_objPos, 100];
                            _transVehWp setWaypointType "CYCLE";
                        }, [_transGrp, _objPos], 5] call CBA_fnc_waitAndExecute;
                    };
                    
                    // Manage infantry group AI with battlegroup behavior
                    if (!isNull _infGrp && {count units _infGrp > 0}) then {
                        [{
                            params ["_infGrp"];
                            if (!isNull _infGrp && {count units _infGrp > 0}) then {
                                [_infGrp] call KPLIB_fnc_spawnBattlegroupAI;
                            };
                        }, [_infGrp], 10] call CBA_fnc_waitAndExecute;
                    };
                };
            }, 0.5, [_transVeh, _infGrp, _transGrp, _objPos, _crewcount]] call CBA_fnc_addPerFrameHandler;
        };
    };
}, 0.2, [_transVeh, _objPos, _unload_distance, _crewcount, _start_pos]] call CBA_fnc_addPerFrameHandler; 