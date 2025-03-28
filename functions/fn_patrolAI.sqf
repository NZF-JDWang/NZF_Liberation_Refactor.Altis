/*
    Function: KPLIB_fnc_patrolAI
    
    Description:
        Manages AI behavior for patrols.
        Sets waypoints for normal patrol or reinforcements when sectors are under attack.
        Uses LAMBS waypoint modules for enhanced AI behavior where available.
        Falls back to standard waypoints if LAMBS is not present.
        Uses CBA non-blocking functions to monitor reinforcement needs and update waypoints.
    
    Parameters:
        _grp - The patrol group [GROUP]
    
    Returns:
        None
    
    Examples:
        (begin example)
        [_group] call KPLIB_fnc_patrolAI;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-03-23
*/

params ["_grp"];

if (isNull _grp) exitWith {false};

// Check if reinforcements_sector_under_attack variable exists
if (isNil "reinforcements_sector_under_attack") then {
    reinforcements_sector_under_attack = "";
};

// Check if LAMBS waypoints are available
private _hasLAMBS = isClass (configFile >> "CfgPatches" >> "lambs_wp");
private _isVehicleGroup = false;

// Determine if this is primarily a vehicle group
if (!isNull _grp) then {
    private _vehCount = {vehicle _x != _x} count (units _grp);
    private _unitCount = count (units _grp);
    _isVehicleGroup = (_vehCount > 0) && (_vehCount >= (_unitCount / 2));
};

// Log patrol creation
[format ["Creating patrol with LAMBS: %1 | Vehicle Group: %2", _hasLAMBS, _isVehicleGroup], "PATROLS"] call KPLIB_fnc_log;

// Create a PFH to monitor the patrol and update waypoints
private _pfh = [{
    params ["_args", "_handle"];
    _args params ["_grp", "_hasLAMBS", "_isVehicleGroup", "_lastWaypointUpdate"];
    
    // Exit if group is empty or null
    if (isNull _grp || {count (units _grp) == 0}) exitWith {
        ["Removing patrol PFH - group no longer valid", "PATROLS"] call KPLIB_fnc_log;
        [_handle] call CBA_fnc_removePerFrameHandler;
    };
    
    // Check if a sector is under attack and needs reinforcements
    if (reinforcements_sector_under_attack != "") then {
        // Log reinforcement
        [format ["Patrol group %1 responding to sector: %2", _grp, reinforcements_sector_under_attack], "PATROLS"] call KPLIB_fnc_log;
        
        // Clear all existing waypoints
        while {count (waypoints _grp) > 0} do {
            deleteWaypoint [_grp, 0];
        };
        
        // Make units follow the leader again
        {_x doFollow (leader _grp)} forEach (units _grp);
        
        private _attackPos = markerPos reinforcements_sector_under_attack;
        
        // Use LAMBS enhanced behavior if available
        if (_hasLAMBS) then {
            if (_isVehicleGroup) then {
                // Vehicle reinforcement with LAMBS - use patrol instead of Rush
                _grp setSpeedMode "FULL";
                _grp setBehaviour "AWARE";
                _grp setCombatMode "RED";
                
                // Use taskPatrol with tight radius to search the area without omniscience
                [_grp, getPos (leader _grp), 200] call lambs_wp_fnc_taskPatrol;
                [format ["Vehicle reinforcement using LAMBS taskPatrol at: %1", reinforcements_sector_under_attack], "PATROLS"] call KPLIB_fnc_log;
            } else {
                // Infantry reinforcement with LAMBS - tactical approach without Rush/Hunt
                _grp setSpeedMode "FULL";
                _grp setBehaviour "AWARE";
                _grp setCombatMode "RED";
                
                // Check if buildings are available for assault
                private _nearBuildings = _attackPos nearObjects ["House", 300];
                
                if (count _nearBuildings > 3) then {
                    // Use taskAssault for dynamic building clearing if buildings present
                    [_grp, _attackPos, 250, true, true] call lambs_wp_fnc_taskAssault;
                    [format ["Infantry reinforcement using LAMBS taskAssault at: %1", reinforcements_sector_under_attack], "PATROLS"] call KPLIB_fnc_log;
                } else {
                    // Use taskPatrol with tight radius in open areas
                    [_grp, getPos (leader _grp), 150] call lambs_wp_fnc_taskPatrol;
                    [format ["Infantry reinforcement using LAMBS taskPatrol at: %1", reinforcements_sector_under_attack], "PATROLS"] call KPLIB_fnc_log;
                };
            }
        } else {
            // Fallback to vanilla waypoints if LAMBS not available
            private _wp = _grp addWaypoint [_attackPos, 50];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "FULL";
            _wp setWaypointBehaviour "AWARE";
            _wp setWaypointCombatMode "RED";
            _wp setWaypointCompletionRadius 30;
            
            _wp = _grp addWaypoint [_attackPos, 50];
            _wp setWaypointSpeed "NORMAL";
            _wp setWaypointType "SAD";
            
            _wp = _grp addWaypoint [_attackPos, 50];
            _wp setWaypointSpeed "NORMAL";
            _wp setWaypointType "SAD";
            
            _wp = _grp addWaypoint [_attackPos, 50];
            _wp setWaypointSpeed "NORMAL";
            _wp setWaypointType "CYCLE";
        };
        
        // Update the last waypoint time
        _args set [3, diag_tickTime + 300];
    } else {
        // Get current time
        private _currentTime = diag_tickTime;
        
        // Only update patrol waypoints if it's been at least 5 minutes since last update
        // or we don't have any waypoints
        if (_currentTime > _lastWaypointUpdate || count (waypoints _grp) == 0) then {
            // Create patrol waypoints around current position
            private _sectors_patrol = [];
            private _patrol_startpos = getPos (leader _grp);
            
            // Find nearby enemy-controlled sectors to patrol
            {
                if (_patrol_startpos distance (markerPos _x) < 2500) then {
                    _sectors_patrol pushBack _x;
                };
            } forEach (sectors_allSectors - blufor_sectors);
            
            // Clear all existing waypoints
            while {count (waypoints _grp) > 0} do {
                deleteWaypoint [_grp, 0];
            };
            
            // Make units follow the leader again
            {_x doFollow (leader _grp)} forEach (units _grp);
            
            // Use LAMBS waypoints if available
            if (_hasLAMBS) then {
                if (_isVehicleGroup) then {
                    // Vehicle groups should NEVER use LAMBS waypoints
                    private _patrolRadius = 800; // Larger radius for vehicles
                    
                    if (count _sectors_patrol > 0) then {
                        // Patrol between sectors if available
                        private _sectorPos = markerPos (selectRandom _sectors_patrol);
                        [_grp, _sectorPos, _patrolRadius] call KPLIB_fnc_applyVehiclePatrol;
                        [format ["Vehicle patrol using dedicated vehicle patrol function near sector"], "PATROLS"] call KPLIB_fnc_log;
                    } else {
                        // Patrol around current position if no sectors nearby
                        [_grp, _patrol_startpos, _patrolRadius] call KPLIB_fnc_applyVehiclePatrol;
                        [format ["Vehicle patrol using dedicated vehicle patrol function at current position"], "PATROLS"] call KPLIB_fnc_log;
                    };
                } else {
                    // Infantry patrol with LAMBS - random strategy selection for variety
                    private _patrolRadius = 400;
                    private _randomBehavior = selectRandom [1, 2, 3]; // Different patrol behaviors (removed Hunt)
                    
                    // Select a patrol position - either a sector or current position
                    private _patrolPos = if (count _sectors_patrol > 0) then {
                        markerPos (selectRandom _sectors_patrol)
                    } else {
                        _patrol_startpos
                    };
                    
                    switch (_randomBehavior) do {
                        case 1: {
                            // Standard patrol behavior
                            [_grp, _patrolPos, _patrolRadius] call lambs_wp_fnc_taskPatrol;
                            [format ["Infantry patrol using LAMBS taskPatrol"], "PATROLS"] call KPLIB_fnc_log;
                        };
                        case 2: {
                            // Garrison nearby buildings
                            private _nearBuildings = _patrolPos nearObjects ["House", 300];
                            if (count _nearBuildings > 2) then {
                                [_grp, _patrolPos, 200, true, false] call lambs_wp_fnc_taskGarrison;
                                ["Infantry patrol using LAMBS taskGarrison", "PATROLS"] call KPLIB_fnc_log;
                            } else {
                                [_grp, _patrolPos, _patrolRadius] call lambs_wp_fnc_taskPatrol;
                                [format ["Infantry patrol using LAMBS taskPatrol (no buildings)"], "PATROLS"] call KPLIB_fnc_log;
                            };
                        };
                        case 3: {
                            // Camping behavior - stay in one area and watch
                            [_grp, _patrolPos, 100, true, false] call lambs_wp_fnc_taskCamp;
                            ["Infantry patrol using LAMBS taskCamp", "PATROLS"] call KPLIB_fnc_log;
                        };
                    };
                }
            } else {
                // Fallback to vanilla waypoints if LAMBS not available
                
                // Add waypoints for each nearby sector, customized for infantry/vehicles
                {
                    private _wp = _grp addWaypoint [markerPos _x, if (_isVehicleGroup) then {400} else {200}];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed (if (_isVehicleGroup) then {"NORMAL"} else {"LIMITED"});
                    _wp setWaypointBehaviour "SAFE";
                    _wp setWaypointCombatMode "YELLOW";
                    _wp setWaypointCompletionRadius (if (_isVehicleGroup) then {60} else {30});
                } forEach _sectors_patrol;
                
                // Return to start position and cycle
                private _wp = _grp addWaypoint [_patrol_startpos, 300];
                _wp setWaypointType "MOVE";
                _wp setWaypointCompletionRadius (if (_isVehicleGroup) then {150} else {100});
                
                _wp = _grp addWaypoint [_patrol_startpos, 300];
                _wp setWaypointType "CYCLE";
            };
            
            // Update last waypoint update time
            _args set [3, _currentTime + 300]; // Update every 5 minutes
        };
    };
    
}, 60, [_grp, _hasLAMBS, _isVehicleGroup, 0]] call CBA_fnc_addPerFrameHandler;

// Return true to indicate success
true 