/*
    File: fn_applyAIBehavior.sqf
    Author: [NZF] JD Wang
    Date: 2024-03-29
    Description:
        Applies the appropriate LAMBS AI task to a group based on an assigned role and sector context.
        Handles roles like garrisoning, patrolling (inner/outer), defending, and setting up camps.
        This function MUST execute on the machine where the group is local (HC or Server).
        Assumes LAMBS is active.

    Parameter(s):
        _groupNetID   - The NetID of the group to apply AI behavior to [STRING]
        _sectorName   - Name of the sector (marker name) [STRING]
        _assignedRole - The specific role for this squad (e.g., "GARRISON_CENTER", "PATROL_OUTER", "DEFEND_AREA", "CAMP_SECTOR") [STRING]
        _taskCenterOverride - Optional position to use as the task center instead of the sector marker [ARRAY, defaults to [0,0,0]]

    Returns:
        None
*/

params [
    ["_groupNetID", "", [""]],
    ["_sectorName", "", [""]],
    ["_assignedRole", "PATROL_DEFAULT", [""]],
    ["_taskCenterOverride", [0,0,0], [[]]]
];

// Resolve group from NetID
private _group = groupFromNetId _groupNetID;

// Check for null group early
if (isNull _group) exitWith {
    diag_log format ["[KPLIB] Error: Cannot apply AI behavior to null group resolved from NetID %1. Sector: %2, Role: %3", _groupNetID, _sectorName, _assignedRole];
    false
};

// Get initial group info
private _groupID = groupId _group;

// Log the start of function execution, noting that group reference might change after reset
diag_log format ["[KPLIB] fn_applyAIBehavior: Starting for initial Group %1 (NetID: %2, Local: %3) with role '%4' in sector '%5'", 
    _groupID, _groupNetID, local _group, _assignedRole, _sectorName];

// Exit if group is not local
if (!(local _group)) exitWith {
    diag_log format ["[KPLIB] Error: Trying to apply AI behavior for non-local group %1 (NetID %2) - Must run where group is local", _groupID, _groupNetID];
    false
};

// Get sector position or use override
private _taskCenter = if !(_taskCenterOverride isEqualTo [0,0,0]) then {
    diag_log format ["[KPLIB] fn_applyAIBehavior: Using provided override task center %1 for Group %2", _taskCenterOverride, _groupID];
    _taskCenterOverride
} else {
    markerPos _sectorName
};

// Get marker size and calculate effective radius
private _markerSizeArr = getMarkerSize _sectorName;
private _markerRadius = 0;
if (count _markerSizeArr == 2) then {
    _markerRadius = ((_markerSizeArr select 0) + (_markerSizeArr select 1)) / 2; // Average marker radius
};
private _captureRadius = missionNamespace getVariable ["GRLIB_capture_size", 175]; // Get GRLIB_capture_size, default 175
private _sectorRadius = [_captureRadius, _markerRadius] call BIS_fnc_max; // Use the larger of capture radius or marker radius
diag_log format ["[KPLIB] fn_applyAIBehavior: Sector %1 - Center: %2, CaptureRadius: %3, MarkerRadius: %4, EffectiveRadius: %5", _sectorName, _taskCenter, _captureRadius, _markerRadius, _sectorRadius];

// Force small groups (3 or fewer units) to patrol instead of using certain roles
private _unitCount = count (units _group);
private _originalAssignedRole = _assignedRole;
if (_unitCount <= 3 && (_assignedRole in ["DEFEND_AREA", "GARRISON_CENTER", "CAMP_SECTOR", "building_defense", "garrison_outer"])) then {
    _assignedRole = "PATROL_DEFAULT";
    diag_log format ["[KPLIB] Forcing small group %1 (%2 units) to patrol instead of %3", _groupID, _unitCount, _originalAssignedRole];
};

// Reset waypoints and get potentially new group reference
// IMPORTANT: _group variable is reassigned here!
_group = [_group] call lambs_wp_fnc_taskReset;

// Update group info after reset, check if still valid
if (isNull _group) exitWith {
    diag_log format ["[KPLIB] CRITICAL ERROR: Group became null immediately after lambs_wp_fnc_taskReset for role %1 in sector %2.", _assignedRole, _sectorName];
    false
};
_groupID = groupId _group; 

// Determine behavior based on role
private _behaviorApplied = false; // Flag to track if a specific behavior was set

switch (toLower _assignedRole) do {
    case "garrison_center": {
        private _searchRadius = 75;
        private _allBuildings = nearestObjects [_taskCenter, ["House"], _searchRadius];
        private _suitableBuildings = _allBuildings select { (count ([_x] call BIS_fnc_buildingPositions)) >= 8 };
        private _targetBuilding = objNull;

        diag_log format ["[KPLIB] Garrison Center: Found %1 buildings nearby, %2 have >= 8 positions.", count _allBuildings, count _suitableBuildings];

        if (count _suitableBuildings > 0) then {
            _targetBuilding = selectRandom _suitableBuildings;
        } else {
            if (count _allBuildings > 0) then {
                 diag_log format ["[KPLIB] Garrison Center: No suitable (>=8 pos) building found. Falling back to random nearby building."];
                 _targetBuilding = selectRandom _allBuildings;
            } else {
                 diag_log format ["[KPLIB] Garrison Center: No buildings found nearby. Falling back to garrisoning task center position."];
                 // Leave _targetBuilding as objNull, will garrison position
            };
        };

        private _garrisonPos = if (!isNull _targetBuilding) then { getPos _targetBuilding } else { _taskCenter };
        private _radius = if (!isNull _targetBuilding) then { 20 } else { 50 }; // Smaller radius for building, larger for area
        private _exitMode = 1 + floor (random 4); 
        diag_log format ["[KPLIB] Applying taskGarrison (Center) for Group %1 %2 (Radius: %3, ExitMode: %4)", 
            _groupID, 
            (if (!isNull _targetBuilding) then { format ["in building %1 near %2", _targetBuilding, _garrisonPos] } else { format ["at position %1", _garrisonPos] }), 
            _radius, _exitMode];
        [_group, _garrisonPos, _radius, [], true, false, _exitMode, false] call lambs_wp_fnc_taskGarrison;
        _behaviorApplied = true;
    };
    case "patrol_inner": {
        private _radius = 75; // Inner patrol radius
        private _wpCount = 4 + floor(random 3);
        diag_log format ["[KPLIB] Applying taskPatrol (Inner) for Group %1 near %2 (Radius: %3, WPs: %4)", _groupID, _taskCenter, _radius, _wpCount];
        [_group, _taskCenter, _radius, _wpCount, [], true, true, true] call lambs_wp_fnc_taskPatrol;
        _behaviorApplied = true;
    };
    case "garrison_outer": {
        private _peripheralPos = [_sectorName, _taskCenter, _sectorRadius] call KPLIB_fnc_findPeripheralBuildingPos;
        private _taskPos = [0,0,0];
        private _taskRadius = 15;
        private _targetBuilding = objNull;
        private _logMsgPrefix = "[KPLIB] Garrison Outer:";

        if (!(_peripheralPos isEqualTo [0,0,0])) then {
            // Try suitable peripheral building first
            private _nearbyBuildings = nearestObjects [_peripheralPos, ["House"], 50]; 
            private _suitableBuildings = _nearbyBuildings select { (count ([_x] call BIS_fnc_buildingPositions)) >= 8 };
            diag_log format ["%1 Found %2 peripheral buildings nearby %3, %4 have >= 8 positions.", _logMsgPrefix, count _nearbyBuildings, _peripheralPos, count _suitableBuildings];
            
            if (count _suitableBuildings > 0) then {
                 _targetBuilding = selectRandom _suitableBuildings;
                 _taskPos = getPos _targetBuilding;
            } else {
                 // Try *any* peripheral building
                 if (count _nearbyBuildings > 0) then {
                     diag_log format ["%1 No suitable (>=8 pos) peripheral building found. Falling back to random peripheral building.", _logMsgPrefix];
                     _targetBuilding = selectRandom _nearbyBuildings;
                     _taskPos = getPos _targetBuilding;
                 } else {
                      diag_log format ["%1 No peripheral buildings found near %2.", _logMsgPrefix, _peripheralPos];
                 };
             };
        };
        
        // If no peripheral building found/used, try edge position
        if (isNull _targetBuilding) then {
            diag_log format ["%1 No peripheral building assigned. Trying edge position.", _logMsgPrefix];
            _taskPos = [_taskCenter, _sectorRadius * 0.7, _sectorRadius * 0.9, 10, 0, 0.2, 0] call BIS_fnc_findSafePos;
            if (!(_taskPos isEqualTo [0,0,0]) && (_taskPos distance2D _taskCenter > _sectorRadius * 0.6)) then {
                 // Try suitable edge building
                 private _nearbyBuildingsEdge = nearestObjects [_taskPos, ["House"], 50]; 
                 private _suitableBuildingsEdge = _nearbyBuildingsEdge select { (count ([_x] call BIS_fnc_buildingPositions)) >= 8 };
                 diag_log format ["%1 Found %2 edge buildings nearby %3, %4 have >= 8 positions.", _logMsgPrefix, count _nearbyBuildingsEdge, _taskPos, count _suitableBuildingsEdge];

                 if (count _suitableBuildingsEdge > 0) then {
                    _targetBuilding = selectRandom _suitableBuildingsEdge;
                    _taskPos = getPos _targetBuilding;
                 } else {
                     // Try *any* edge building
                     if (count _nearbyBuildingsEdge > 0) then {
                         diag_log format ["%1 No suitable (>=8 pos) edge building found. Falling back to random edge building.", _logMsgPrefix];
                         _targetBuilding = selectRandom _nearbyBuildingsEdge;
                         _taskPos = getPos _targetBuilding;
                     } else {
                         diag_log format ["%1 No edge buildings found near %2. Will garrison position directly.", _logMsgPrefix, _taskPos];
                         // Leave _targetBuilding null, garrison position
                     };
                 };
            } else {
                diag_log format ["%1 No valid edge position found. Falling back to garrisoning task center.", _logMsgPrefix];
                 _taskPos = _taskCenter; // Fallback to center if edge fails
                 // Leave _targetBuilding null
            };
        };

        // Apply garrison based on final _taskPos and whether _targetBuilding is valid
        private _garrisonPosFinal = if (!isNull _targetBuilding) then { getPos _targetBuilding } else { _taskPos };
        _taskRadius = if (!isNull _targetBuilding) then { 15 } else { 50 }; // Smaller radius for building, larger for area
        private _exitMode = 1 + floor (random 4);
        diag_log format ["[KPLIB] Applying taskGarrison (Outer) for Group %1 %2 (Radius: %3, ExitMode: %4)", 
            _groupID, 
            (if (!isNull _targetBuilding) then { format ["in building %1 near %2", _targetBuilding, _garrisonPosFinal] } else { format ["at position %1", _garrisonPosFinal] }), 
            _taskRadius, _exitMode];
        [_group, _garrisonPosFinal, _taskRadius, [], true, false, _exitMode, false] call lambs_wp_fnc_taskGarrison;
        _behaviorApplied = true;
    };
    case "defend_area": {
        private _peripheralPos = [_sectorName, _taskCenter, _sectorRadius] call KPLIB_fnc_findPeripheralBuildingPos;
        private _taskPos = [0,0,0];
        private _taskRadius = 50;

        if (!(_peripheralPos isEqualTo [0,0,0])) then {
            _taskPos = _peripheralPos;
            diag_log format ["[KPLIB] Applying taskDefend for Group %1 at peripheral building position %2 (Radius: %3)", _groupID, _taskPos, _taskRadius];
            [_group, _taskPos, _taskRadius, [], true, true, true, true] call lambs_wp_fnc_taskDefend;
            _behaviorApplied = true;
        } else {
            diag_log format ["[KPLIB] WARNING: No peripheral building found for taskDefend (Group %1). Trying edge position.", _groupID];
            _taskPos = [_taskCenter, _sectorRadius * 0.7, _sectorRadius * 0.9, 10, 0, 0.2, 0] call BIS_fnc_findSafePos;
            if (!(_taskPos isEqualTo [0,0,0]) && (_taskPos distance2D _taskCenter > _sectorRadius * 0.6)) then {
                 diag_log format ["[KPLIB] Applying taskDefend for Group %1 at edge position %2 (Radius: %3)", _groupID, _taskPos, _taskRadius];
                 [_group, _taskPos, _taskRadius, [], true, true, true, true] call lambs_wp_fnc_taskDefend;
                 _behaviorApplied = true;
            } else {
                diag_log format ["[KPLIB] WARNING: No edge position found for taskDefend (Group %1). Falling back to central patrol.", _groupID];
                 // Fall through to default patrol case below
            };
        };
    };
    case "camp_sector": {
        private _minRadius = 150;
        private _maxRadius = 300;
        private _maxDistanceThreshold = 500; // Max acceptable distance from taskCenter
        private _taskPos = [0,0,0];
        private _taskRadius = 50;
        private _foundSuitablePos = false;

        // --- Attempt 1: Standard parameters ---
        diag_log format ["[KPLIB] Camp Sector (Group %1): Attempt 1 - Finding safe pos near %2 (Radius: %3-%4m, Grad: 0, Shore: 0.3)", _groupID, _taskCenter, _minRadius, _maxRadius];
        _taskPos = [_taskCenter, _minRadius, _maxRadius, 3, 0, 0.3, 0] call BIS_fnc_findSafePos;
        
        if (!(_taskPos isEqualTo [0,0,0]) && (_taskPos distance2D _taskCenter < _maxDistanceThreshold)) then {
            diag_log format ["[KPLIB] Camp Sector (Group %1): Attempt 1 SUCCESS - Found position %2", _groupID, _taskPos];
            _foundSuitablePos = true;
        } else {
            diag_log format ["[KPLIB] Camp Sector (Group %1): Attempt 1 FAILED or position too far (%1m).", _groupID, round (_taskPos distance2D _taskCenter)];

            // --- Attempt 2: Relaxed parameters ---
            private _maxRadiusRelaxed = _maxRadius + 50; // 250m
            private _shoreModeRelaxed = 0.5;
            diag_log format ["[KPLIB] Camp Sector (Group %1): Attempt 2 - Finding safe pos near %2 (Radius: %3-%4m, Grad: 0, Shore: %5)", 
                _groupID, _taskCenter, _minRadius, _maxRadiusRelaxed, _shoreModeRelaxed];
            _taskPos = [_taskCenter, _minRadius, _maxRadiusRelaxed, 3, 0, _shoreModeRelaxed, 0] call BIS_fnc_findSafePos;

            if (!(_taskPos isEqualTo [0,0,0]) && (_taskPos distance2D _taskCenter < _maxDistanceThreshold)) then {
                 diag_log format ["[KPLIB] Camp Sector (Group %1): Attempt 2 SUCCESS - Found position %2", _groupID, _taskPos];
                 _foundSuitablePos = true;
            } else {
                 diag_log format ["[KPLIB] Camp Sector (Group %1): Attempt 2 FAILED or position too far (%1m).", _groupID, round (_taskPos distance2D _taskCenter)];
            };
        };

        // --- Apply Task if Suitable Position Found ---
        if (_foundSuitablePos) then {
            diag_log format ["[KPLIB] Applying taskCamp for Group %1 at position %2 (Radius: %3)", _groupID, _taskPos, _taskRadius];

            // --- DEBUG: Create a local marker at the target camp position ---
            private _markerName = format ["dbg_camp_pos_%1", netId _group]; // Use NetID for uniqueness
            _marker = createMarkerLocal [_markerName, _taskPos];
            _marker setMarkerTypeLocal "mil_dot";
            _marker setMarkerColorLocal "ColorRed";
            _marker setMarkerTextLocal format ["Camp Pos %1", groupId _group]; // Use GroupID for display
            diag_log format ["[KPLIB] DEBUG: Created local marker '%1' at %2 for Group %3 Camp", _markerName, _taskPos, groupId _group];
            // --- END DEBUG ---

            // Assign taskCamp
            [_group, _taskPos, _taskRadius, [], true, true] call lambs_wp_fnc_taskCamp;
            _behaviorApplied = true;
        } else {
            diag_log format ["[KPLIB] WARNING: Could not find suitable camp position for Group %1 near %2 after two attempts. Falling back to default patrol.", _groupID, _taskCenter];
            _behaviorApplied = false; // Ensure fallback patrol is triggered
        };
    };
    case "patrol_outer": {
         private _patrolRadius = _sectorRadius * 0.9;
         private _numWaypoints = 6 + floor(random 3); // 6-8 waypoints
         diag_log format ["[KPLIB] Generating %1 custom outer patrol waypoints for Group %2 around %3 at %4m radius.", _numWaypoints, _groupID, _taskCenter, _patrolRadius];

         // Waypoints have already been cleared by taskReset

         private _waypointsAdded = 0;
         for "_i" from 0 to (_numWaypoints - 1) do {
             private _angle = (_i / _numWaypoints) * 360;
             private _roughPos = _taskCenter getPos [_patrolRadius, _angle];
             // Find a safe position near the calculated point on the circle
             private _wpPos = [_roughPos, 0, 50, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;
             if (!isNull _wpPos && !(_wpPos isEqualTo [0,0,0]) && (_wpPos distance2D _roughPos < 100)) then { // Added distance check
                 _group addWaypoint [_wpPos, 0];
                 _waypointsAdded = _waypointsAdded + 1;
             } else {
                 diag_log format ["[KPLIB] WARNING: Could not find safe outer patrol waypoint near %1 for Group %2 (angle %3)", _roughPos, _groupID, _angle];
             };
         };

        if (_waypointsAdded > 1) then { // Need at least 2 waypoints for a cycle
             // Set last WP to CYCLE
             private _lastWPIndex = _waypointsAdded - 1;
             private _lastWP = (waypoints _group) select _lastWPIndex; 
             _lastWP setWaypointType "CYCLE";
             
             // Set first WP speed to FULL
             private _firstWP = (waypoints _group) select 0;
             _firstWP setWaypointSpeed "FULL";
             
             diag_log format ["[KPLIB] Added %1 custom outer patrol waypoints for Group %2. First WP speed FULL.", _waypointsAdded, _groupID];
             // Set specific group properties (overall speed LIMITED)
             _group setBehaviour "SAFE";
             _group setCombatMode "RED";
             _group setSpeedMode "LIMITED";
             _behaviorApplied = true;
         } else {
             // Fallback if not enough waypoints could be added
             diag_log format ["[KPLIB] ERROR: Failed to add enough (%1) custom outer patrol waypoints for Group %2. Falling back to central patrol.", _waypointsAdded, _groupID];
             // Fall through to default patrol case below
         };
     };
     default { _behaviorApplied = false; }; // Explicitly state no behavior applied for default case initially
};

// Default behavior if no specific case applied or if a case fell through
if (!_behaviorApplied) then {
    if (!((toLower _assignedRole) isEqualTo "patrol_default")) then {
         diag_log format ["[KPLIB] Applying default central patrol for Group %1 (Original Role: %2)", _groupID, _originalAssignedRole];
    };
    private _radius = 100 + (random 50);
    private _wpCount = 4;
    diag_log format ["[KPLIB] Applying taskPatrol (Default/Fallback) for Group %1 near %2 (Radius: %3, WPs: %4)", _groupID, _taskCenter, _radius, _wpCount];
    [_group, _taskCenter, _radius, _wpCount, [], true, true, true] call lambs_wp_fnc_taskPatrol;
    _behaviorApplied = true; // Mark that default behavior was applied
};

// Set default combat/behaviour modes ONLY if a specific mode wasn't set (e.g., by PATROL_OUTER)
if (!(_group getVariable ["KPLIB_AIBehaviorModeSet", false])) then {
    if (isNull _group) then {
        diag_log format ["[KPLIB] CRITICAL WARNING: Group %1 (NetID: %2) became NULL before setting final combat/behaviour modes!", _groupID, _groupNetID];
    } else {
        // Default modes for LAMBS tasks unless overridden
        if (!((toLower _assignedRole) isEqualTo "patrol_outer")) then {
             diag_log format ["[KPLIB] Setting default combat modes for Group %1 (Role: %2)", _groupID, _assignedRole];
             _group setCombatMode "RED";
             _group setBehaviour "SAFE";
             _group setSpeedMode "LIMITED";
             _group setVariable ["KPLIB_AIBehaviorModeSet", true]; // Mark modes as set
        } else {
             diag_log format ["[KPLIB] Skipping default combat modes for Group %1 (Role: %2, custom modes already set)", _groupID, _assignedRole];
             _group setVariable ["KPLIB_AIBehaviorModeSet", true]; // Mark modes as set (even though custom)
        }
    };
};

// Log success and waypoint count (check group validity again)
private _wpCount = 0;
if (!isNull _group) then {
    _wpCount = count waypoints _group;
} else {
    // Log again if null here, shouldn't happen if initial check passed but safety first
    diag_log format ["[KPLIB] CRITICAL WARNING: Group %1 (NetID: %2) became NULL before final logging!", _groupID, _groupNetID];
};

diag_log format ["[KPLIB] fn_applyAIBehavior: FINISHED applying behavior '%1' for group %2 (NetID: %3) with %4 waypoints in sector '%5'", 
    toLower _assignedRole, _groupID, _groupNetID, _wpCount, _sectorName];

// Store the successfully applied role on the group for persistence
if (!isNull _group) then {
    _group setVariable ["KPLIB_assignedRole", _assignedRole, true];
    diag_log format ["[KPLIB] fn_applyAIBehavior: Stored role '%1' on Group %2 (NetID: %3)", _assignedRole, _groupID, _groupNetID];
};

true // Return success 