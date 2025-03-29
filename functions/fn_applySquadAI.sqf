/*
    Function: KPLIB_fnc_applySquadAI
    
    Description:
        Applies appropriate AI behavior to a group of units after they've been spawned.
        Uses LAMBS waypoints for infantry AI behavior.
        Uses vanilla waypoints for vehicle groups based on KP-Liberation method.
        Ensures waypoints are applied on the correct machine that owns the group (expected Headless Client).
        Optimizes squad roles based on size - larger groups defend/garrison, smaller groups patrol.
        
    Parameters:
        _grp - The group to apply AI behavior to [GROUP]
        _position - The center position for AI behavior [POSITION ARRAY]
        _type - The type of AI behavior to apply [STRING, defaults to "patrol"]
            - "patrol": Regular patrol behavior
            - "building_defense": Defensive positions in buildings
            - "garrison": Static garrison behavior
            - "defend": Standard defensive behavior 
        _searchRadius - Radius for search/patrol operations [NUMBER, defaults to random 100-300m]
        _sector - Optional sector marker name for building defense [STRING, defaults to ""]
        
    Returns:
        True on successful application of AI behavior [BOOL]
    
    Examples:
        (begin example)
        [_group, getMarkerPos "objective_1", "patrol"] call KPLIB_fnc_applySquadAI;
        [_group, getPos player, "building_defense", 200, "sector_1"] call KPLIB_fnc_applySquadAI;
        (end)
        
    Author: [NZF] JD Wang
    Date: 2024-11-16
*/

params [
    ["_grp", grpNull, [grpNull]],
    ["_position", [0,0,0], [[]], [2,3]],
    ["_type", "patrol", [""]],
    ["_searchRadius", 100 + random 200, [0]],
    ["_sector", "", [""]]
];

// Strictly enforce search radius to be within permitted range
_searchRadius = _searchRadius min 300;
_searchRadius = _searchRadius max 75;

// Exit with failure if group is invalid
if (isNull _grp || {count units _grp == 0}) exitWith {
    diag_log format ["[KPLIB] Error: Cannot apply AI to null or empty group"];
    false
};

// Check if this is a military sector
private _isMilitarySector = false;
if (_sector != "") then {
    _isMilitarySector = _sector in (sectors_military + sectors_tower);
    if (_isMilitarySector) then {
        diag_log format ["[KPLIB] Military sector %1 detected for group %2", _sector, _grp];
    };
};

// CRITICAL: Check if group is local to this machine
private _isLocal = local _grp;
private _groupOwner = groupOwner _grp;

// Check if group is primarily a vehicle group - do this early so it's available for remote calls
private _isVehicleGroup = false;
private _vehCount = {vehicle _x != _x} count (units _grp);
private _unitCount = count (units _grp);

// Enhanced group composition logging
diag_log format ["[KPLIB] Group %1 composition analysis - Total units: %2, In vehicles: %3", _grp, _unitCount, _vehCount];

if (_unitCount > 0) then {
    _isVehicleGroup = (_vehCount > 0) && (_vehCount >= (_unitCount / 2));
    
    // Additional check to catch edge cases where a single unit in a vehicle might not trigger the threshold
    if (!_isVehicleGroup && _vehCount > 0) then {
        private _mainVehicle = vehicle (leader _grp);
        if (_mainVehicle != leader _grp) then {
            // If leader is in a vehicle, treat as vehicle group regardless of count
            _isVehicleGroup = true;
            diag_log format ["[KPLIB] Group %1 marked as vehicle group (leader in vehicle override)", _grp];
        };
    };
    
    // Log detailed group composition
    if (_unitCount == 1) then {
        diag_log format ["[KPLIB] WARNING: Single unit group detected! Group: %1, Unit: %2, Position: %3", 
            _grp, (units _grp) select 0, getPos ((units _grp) select 0)];
    };
};

// Store original type for logging
private _originalType = _type;

// Log initial state with exact position
diag_log format ["[KPLIB] Initial AI call for group %1 - Type: %2, Position: %3, Search Radius: %4, Sector: %5", 
    _grp, _type, _position, _searchRadius, _sector];

// If the group is not local, forward the call to the owner (expected HC)
if (!_isLocal) then {
    // Force all units to follow leader - this works regardless of locality
    {
        if (alive _x) then {
            _x doFollow (leader _grp);
            _x setUnitPos "AUTO";
        };
    } forEach (units _grp);
    
    // Pack parameters for remote execution (using the original _type)
    private _params = [_grp, _position, _type, _searchRadius, _sector];
    
    // Execute the function on the machine that owns the group with JIP enabled
    _params remoteExecCall ["KPLIB_fnc_applySquadAI", _groupOwner, true];
    
    // Log the remote execution
    diag_log format ["[KPLIB] Forwarding AI behavior for group %1 (Owner: %2) from Machine %3", _grp, _groupOwner, clientOwner];
    
    // Return true as we've successfully delegated the task
    true
} else {
    // The group is local to this machine (expected HC), so we can apply the behavior directly
    diag_log format ["[KPLIB] Group %1 is local to this machine (ID: %2), applying AI behavior directly", _grp, clientOwner];
    
    // Optimize group behavior based on size - larger groups defend/garrison, smaller groups patrol
    // IMPORTANT: Only apply this on the local machine that owns the group to avoid recursion
    if (!_isVehicleGroup) then {
        private _isLargeGroup = _unitCount >= 6;
        private _isSmallGroup = _unitCount <= 4;  // Increased threshold from 3 to 4
        
        // Small groups should ALWAYS patrol regardless of original type
        if (_isSmallGroup) then {
            if (_type != "patrol") then {
                diag_log format ["[KPLIB] Forcing small group %1 (%2 units) to patrol instead of %3", _grp, _unitCount, _type];
                _type = "patrol";
            };
        } else {
            // Large groups should defend/garrison if originally set to patrol
            if (_isLargeGroup && _type == "patrol") then {
                _type = "defend";
                diag_log format ["[KPLIB] Optimizing large group %1 (%2 units): changing from patrol to defend", _grp, _unitCount];
            };
        };
    };
    
    // Log final behavior type decision
    if (_type != _originalType) then {
        diag_log format ["[KPLIB] Final behavior for group %1: %2 (changed from %3)", _grp, _type, _originalType];
    };
    
    // Military sector specific handling - prioritize garrison
    if (_isMilitarySector && !_isVehicleGroup) then {
        // For military sectors, enforce garrison behavior with 150m radius
        // Small groups still patrol, but most units should garrison
        private _militaryGarrisonChance = 0.7;
        
        // Increase garrison chance for larger groups
        if (_unitCount >= 4) then {
            _militaryGarrisonChance = 0.85;
        };
        
        if (random 1 < _militaryGarrisonChance) then {
            // Override to garrison behavior
            _type = "garrison";
            // Set search radius to exactly 150m for military sectors
            _searchRadius = 150;
            diag_log format ["[KPLIB] Military sector garrison: Group %1 (%2 units) assigned garrison behavior with 150m radius", 
                _grp, _unitCount];
        } else {
            // Some groups still patrol/defend
            if (_type == "patrol" && _unitCount >= 5) then {
                _type = "defend";
                diag_log format ["[KPLIB] Military sector patrol: Large group %1 (%2 units) assigned defend behavior", 
                    _grp, _unitCount];
            };
        };
    };
    
    // Clear any existing waypoints first to avoid conflicts
    while {count (waypoints _grp) > 0} do {
        deleteWaypoint ((waypoints _grp) select 0);
    };
    
    // Initial setup - set all units to SAFE mode and make them follow the leader
    _grp setBehaviour "SAFE";
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode "NORMAL";
    
    {
        if (alive _x) then {
            _x doFollow (leader _grp);
            _x setUnitPos "AUTO";
        };
    } forEach (units _grp);
    
    // Handle applying waypoints after a short delay to ensure units are in position
    [
        {
            params ["_args", "_handle"];
            _args params ["_grp", "_position", "_type", "_searchRadius", "_sector", "_isVehicleGroup"];
            
            // Exit if group no longer exists
            if (isNull _grp || {count (units _grp) == 0}) exitWith {
                diag_log format ["[KPLIB] Group %1 no longer exists - cancelling waypoint application", _grp];
                [_handle] call CBA_fnc_removePerFrameHandler;
            };
            
            // Skip if group is still at [0,0,0] - they haven't moved to proper position yet
            private _leaderPos = getPos (leader _grp);
            if (_leaderPos distance [0,0,0] < 10) exitWith {
                diag_log format ["[KPLIB] Group %1 still at default position - waiting before applying waypoints", _grp];
            };
            
            // Group has moved to a valid position - apply waypoints and remove the PFH
            [_handle] call CBA_fnc_removePerFrameHandler;
            
            // Use actual leader position if target position is default [0,0,0]
            if (_position distance [0,0,0] < 10) then {
                _position = _leaderPos;
                diag_log format ["[KPLIB] Using leader position %1 for group %2 waypoints", _position, _grp];
            };
            
            // If sector is provided and garrison/defense type, use exact sector position
            if (_sector != "" && {_type in ["building_defense", "garrison", "defend"]}) then {
                private _exactSectorPos = markerPos _sector;
                if (_exactSectorPos distance [0,0,0] > 10) then {
                    _position = _exactSectorPos;
                    diag_log format ["[KPLIB] Using exact sector marker position %1 for %2 behavior in sector %3", 
                        _exactSectorPos, _type, _sector];
                };
            };
            
            // Verify position is valid
            if (_position distance [0,0,0] < 10) then {
                diag_log format ["[KPLIB] ERROR: Invalid position for group %1 - Using leader position as fallback", _grp];
                _position = getPos (leader _grp);
            };
            
            // Proceed with AI setup
            diag_log format ["[KPLIB] Group %1 in position - now applying AI behavior (%2) at position %3 with radius %4", 
                _grp, _type, _position, _searchRadius];
            
            // Set combat behavior - switch from initial SAFE to combat ready
            _grp setBehaviour "AWARE";
            _grp setCombatMode "YELLOW";
            _grp enableAttack true;
            
            // Variable to track waypoint creation success
            private _waypointsCreated = false;
            
            // Special handling for vehicle groups
            if (_isVehicleGroup) then {
                // For vehicle groups, ONLY use dedicated vehicle patrol function - NEVER use LAMBS
                [_grp, _position, _searchRadius] call KPLIB_fnc_applyVehiclePatrol;
                _waypointsCreated = true;
                diag_log format ["[KPLIB] Vehicle group %1 - using dedicated vehicle patrol function", _grp];
            } else {
                // INFANTRY: Use LAMBS for non-vehicle groups
                
                // If a sector is provided, use its marker size to determine search radius
                if (_sector != "") then {
                    // Get the marker size from the sector marker to prevent overlapping groups in buildings
                    private _markerSize = getMarkerSize _sector;
                    if (count _markerSize > 0) then {
                        // Markers are typically ellipses, use average of X and Y size for circular area
                        private _avgMarkerSize = ((_markerSize select 0) + (_markerSize select 1)) / 2;
                        if (_avgMarkerSize > 30) then {
                            // Only use marker size if it's big enough
                            _searchRadius = _avgMarkerSize;
                            diag_log format ["[KPLIB] Using sector marker size (%1) for group %2 search radius", _searchRadius, _grp];
                        };
                    };
                    
                    // For building_defense and garrison in sectors, use a varied radius for each group
                    // This prevents multiple groups from occupying the same buildings
                    if (_type in ["building_defense", "garrison"]) then {
                        // Vary the search radius by +/- 20% based on group ID to create distinct patrol zones
                        private _groupIdVariation = ((groupId _grp) select [count (groupId _grp) - 1, 1]);
                        private _numericVariation = 0;
                        
                        // Convert last character of group ID to a number between 0-9
                        _numericVariation = parseNumber _groupIdVariation;
                        if (_numericVariation == 0) then {
                            // If not a number, use a hash of the group ID
                            _numericVariation = 0;
                            {
                                _numericVariation = _numericVariation + (toArray _x select 0);
                            } forEach (toArray (groupId _grp));
                            _numericVariation = _numericVariation mod 10;
                        };
                        
                        // Apply variation to search radius - scale from 70% to 130% of original
                        private _variationFactor = 0.7 + ((_numericVariation / 10) * 0.6); // Range from 0.7 to 1.3
                        _searchRadius = _searchRadius * _variationFactor;
                        
                        diag_log format ["[KPLIB] Group %1 radius varied by factor %2 to %3m for building distribution", 
                            _grp, _variationFactor toFixed 2, _searchRadius toFixed 0];
                    };
                };
                
                switch (_type) do {
                    case "building_defense": {
                        // Randomly select between taskGarrison and taskDefend
                        private _useLambsGarrison = [true, false] selectRandomWeighted [0.7, 0.3];
                        private _doTeleport = true;
                        private _doSubPatrols = true;
                        
                        if (_useLambsGarrison) then {
                            // Use LAMBS taskGarrison with teleport and exit conditions
                            [_grp, _position, _searchRadius, [], _doTeleport, false, -2, _doSubPatrols] call lambs_wp_fnc_taskGarrison;
                            _waypointsCreated = true;
                            diag_log format ["[KPLIB] Group %1 using LAMBS taskGarrison (building defense) at %2 with radius %3", 
                                _grp, _position, _searchRadius];
                        } else {
                            // Use LAMBS taskDefend with teleport and patrols option
                            [_grp, _position, _searchRadius, [], _doTeleport, true, true, _doSubPatrols] call lambs_wp_fnc_taskDefend;
                            _waypointsCreated = true;
                            diag_log format ["[KPLIB] Group %1 using LAMBS taskDefend (building defense) at %2 with radius %3", 
                                _grp, _position, _searchRadius];
                        };
                    };
                    
                    case "garrison": {
                        // Randomly select between taskGarrison and taskDefend
                        private _useLambsGarrison = [true, false] selectRandomWeighted [0.8, 0.2];
                        private _doTeleport = true;
                        
                        // For military sectors, ensure units stay in buildings and close to marker
                        if (_isMilitarySector) then {
                            // Military sectors should have tighter garrison controls
                            _useLambsGarrison = true;  // Always use garrison for military sectors
                            _doTeleport = true;        // Always teleport to position
                            
                            diag_log format ["[KPLIB] Military sector garrison for group %1 using %2m radius at %3", 
                                _grp, _searchRadius, _position];
                        };
                                               
                        if (_useLambsGarrison) then {
                            // Use LAMBS taskGarrison with teleport and stay put
                            [_grp, _position, _searchRadius, [], _doTeleport, true, 0, false] call lambs_wp_fnc_taskGarrison;
                            _waypointsCreated = true;
                            diag_log format ["[KPLIB] Group %1 using LAMBS taskGarrison (static) at %2 with radius %3", 
                                _grp, _position, _searchRadius];
                        } else {
                            // Use LAMBS taskDefend with teleport but no patrols
                            [_grp, _position, _searchRadius, [], _doTeleport, true, true, false] call lambs_wp_fnc_taskDefend;
                            _waypointsCreated = true;
                            diag_log format ["[KPLIB] Group %1 using LAMBS taskDefend (garrison) at %2 with radius %3", 
                                _grp, _position, _searchRadius];
                        };
                    };
                    
                    case "defend": {
                        // Randomly select between taskGarrison and taskDefend
                        private _useLambsGarrison = [true, false] selectRandomWeighted [0.4, 0.6];
                        private _doTeleport = [true, false] selectRandomWeighted [0.7, 0.3];
                        private _exitCondition = selectRandom [-2, -1, 1, 2, 3]; // Random exit condition
                        
                        if (_useLambsGarrison) then {
                            // Use LAMBS taskGarrison for defense
                            [_grp, _position, _searchRadius, [], _doTeleport, true, _exitCondition, true] call lambs_wp_fnc_taskGarrison;
                            _waypointsCreated = true;
                            if (KP_liberation_debug) then {
                                diag_log format ["[KPLIB] Group %1 using LAMBS taskGarrison (defense) with teleport: %2, exit: %3 at %4 with radius %5", 
                                    _grp, _doTeleport, _exitCondition, _position, _searchRadius];
                            };
                        } else {
                            // Use LAMBS taskDefend for defense
                            [_grp, _position, _searchRadius, [], _doTeleport, true, true, true] call lambs_wp_fnc_taskDefend;
                            _waypointsCreated = true;
                            if (KP_liberation_debug) then {
                                diag_log format ["[KPLIB] Group %1 using LAMBS taskDefend (defense) with teleport: %2 at %3 with radius %4", 
                                    _grp, _doTeleport, _position, _searchRadius];
                            };
                        };
                    };
                    
                    default { // "patrol" and any other unspecified types
                        // Infantry patrol with LAMBS
                        [_grp, _position, _searchRadius] call lambs_wp_fnc_taskPatrol;
                        _waypointsCreated = true;
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Infantry group %1 using LAMBS taskPatrol at %2 with radius %3", 
                                _grp, _position, _searchRadius];
                        };
                    };
                };
            };
            
            // Log warning if LAMBS failed to create waypoints
            private _waypoints = count (waypoints _grp);
            if (_waypoints <= 1) then {
                if (!_isVehicleGroup) then {
                    // Infantry group handling
                    diag_log format ["[KPLIB] CRITICAL WARNING: Failed to create waypoints for group %1 with behavior %2!", _grp, _type];
                    
                    // Clear any failed waypoints
                    while {count (waypoints _grp) > 0} do {
                        deleteWaypoint ((waypoints _grp) select 0);
                    };
                    
                    // Set initial behavior
                    _grp setBehaviour "AWARE";
                    _grp setCombatMode "YELLOW";
                    _grp setSpeedMode "LIMITED";
                    
                    // Try different LAMBS approach first as fallback - only for infantry
                    private _lambsSuccess = false;
                    
                    // Only try LAMBS fallbacks for infantry groups
                    if (_type == "building_defense" || _type == "garrison") then {
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Creating fallback LAMBS garrison for group %1", _grp];
                        };
                        
                        // Try LAMBS task garrison with different parameters
                        try {
                            // Use modified parameters that are more reliable
                            [_grp, _position, _searchRadius, [], true, true, -1, false] call lambs_wp_fnc_taskGarrison;
                            _lambsSuccess = (count (waypoints _grp) > 1);
                            
                            if (KP_liberation_debug) then {
                                if (_lambsSuccess) then {
                                    diag_log format ["[KPLIB] Successfully applied fallback LAMBS garrison to group %1", _grp];
                                } else {
                                    diag_log format ["[KPLIB] Fallback LAMBS garrison failed for group %1", _grp];
                                };
                            };
                        } catch {
                            diag_log format ["[KPLIB] Error in fallback LAMBS garrison for group %1: %2", _grp, _exception];
                        };
                    } else {
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Creating fallback LAMBS defend for group %1", _grp];
                        };
                        
                        // Try LAMBS task defend with different parameters
                        try {
                            // Use modified parameters that are more reliable
                            [_grp, _position, _searchRadius, [], true, true, false, false] call lambs_wp_fnc_taskDefend;
                            _lambsSuccess = (count (waypoints _grp) > 1);
                            
                            if (KP_liberation_debug) then {
                                if (_lambsSuccess) then {
                                    diag_log format ["[KPLIB] Successfully applied fallback LAMBS defend to group %1", _grp];
                                } else {
                                    diag_log format ["[KPLIB] Fallback LAMBS defend failed for group %1", _grp];
                                };
                            };
                        } catch {
                            diag_log format ["[KPLIB] Error in fallback LAMBS defend for group %1: %2", _grp, _exception];
                        };
                    };
                    
                    // If LAMBS still failed, resort to LAMBS patrol as absolute fallback (infantry only)
                    if (!_lambsSuccess) then {
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Both LAMBS defend/garrison approaches failed for group %1, using LAMBS patrol instead", _grp];
                        };
                        
                        // Use LAMBS taskPatrol as a fallback for infantry groups
                        try {
                            [_grp, _position, _searchRadius] call lambs_wp_fnc_taskPatrol;
                            _lambsSuccess = (count (waypoints _grp) > 1);
                            
                            if (_lambsSuccess) then {
                                if (KP_liberation_debug) then {
                                    diag_log format ["[KPLIB] Successfully applied fallback LAMBS patrol to group %1", _grp];
                                };
                            } else {
                                if (KP_liberation_debug) then {
                                    diag_log format ["[KPLIB] All LAMBS AI methods failed for group %1", _grp];
                                };
                                
                                // Last resort - create a single MOVE waypoint to at least get them moving
                                private _wp = _grp addWaypoint [_position, 0];
                                _wp setWaypointType "MOVE";
                                _wp setWaypointCompletionRadius 15;
                                diag_log format ["[KPLIB] Created emergency MOVE waypoint for group %1 to position %2", _grp, _position];
                            };
                        } catch {
                            diag_log format ["[KPLIB] Error in fallback LAMBS patrol for group %1: %2", _grp, _exception];
                            
                            // Emergency single waypoint if everything else fails
                            private _wp = _grp addWaypoint [_position, 0];
                            _wp setWaypointType "MOVE";
                            _wp setWaypointCompletionRadius 15;
                            diag_log format ["[KPLIB] Created emergency MOVE waypoint after exception for group %1", _grp];
                        };
                    };
                } else {
                    // Vehicle group handling
                    // Vehicle group failed to get waypoints - retry with vehicle patrol function
                    if (KP_liberation_debug) then {
                        diag_log format ["[KPLIB] Vehicle group %1 has no waypoints - reapplying vehicle patrol", _grp];
                    };
                    
                    // Clear any failed waypoints
                    while {count (waypoints _grp) > 0} do {
                        deleteWaypoint ((waypoints _grp) select 0);
                    };
                    
                    // Reset basic behavior
                    _grp setBehaviour "AWARE";
                    _grp setCombatMode "YELLOW";
                    _grp setSpeedMode "NORMAL";
                    
                    // Try vehicle patrol again
                    [_grp, _position, _searchRadius] call KPLIB_fnc_applyVehiclePatrol;
                    
                    // Final emergency waypoint if all else fails
                    if (count (waypoints _grp) <= 1) then {
                        diag_log format ["[KPLIB] Vehicle patrol failed again for group %1", _grp];
                        
                        // Emergency waypoint as absolute last resort
                        private _wp = _grp addWaypoint [_position, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointCompletionRadius 30;
                        diag_log format ["[KPLIB] Created emergency MOVE waypoint for vehicle group %1", _grp];
                    };
                };
            };
            
            // Force units to follow leader again after waypoints are set - final safety check
            {
                if (alive _x) then {
                    _x doFollow (leader _grp);
                };
            } forEach (units _grp);
            
            // For vehicle groups, just make a basic check
            if (_isVehicleGroup) then {
                private _veh = vehicle (leader _grp);
                if (_veh != (leader _grp)) then {
                    private _driver = driver _veh;
                    if (isNull _driver) then {
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Warning: Vehicle %1 has no driver, waypoints may not work", _veh];
                        };
                    };
                };
            };
            
            // Log summary of operation
            if (KP_liberation_debug) then {
                diag_log format ["[KPLIB] AI behavior application complete for group %1, Type: %2, Waypoint Count: %3", 
                                _grp, _type, count (waypoints _grp)];
            };
        },
        0.5, // Check every 0.5 seconds
        [_grp, _position, _type, _searchRadius, _sector, _isVehicleGroup]
    ] call CBA_fnc_addPerFrameHandler;
    
    // Return success
    true
}; 