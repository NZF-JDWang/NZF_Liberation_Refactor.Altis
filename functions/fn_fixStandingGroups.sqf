/*
    Function: KPLIB_fnc_fixStandingGroups
    
    Description:
        Identifies enemy groups that are standing in formation without waypoints
        and reapplies appropriate waypoints to them. This is a fix for when
        LAMBS waypoints or vanilla waypoints fail to apply properly during spawning.
        
    Parameters:
        _sector - Optional sector to focus on (if empty, all sectors are checked) [STRING, defaults to ""]
    
    Returns:
        Number of groups fixed [NUMBER]
    
    Examples:
        (begin example)
        [] call KPLIB_fnc_fixStandingGroups; // Fix all groups
        ["factory_12"] call KPLIB_fnc_fixStandingGroups; // Fix only groups in a specific sector
        (end)
        
    Author: [NZF] JD Wang
    Date: 2024-11-16
*/

params [
    ["_sector", "", [""]]
];

// Count of fixed groups
private _fixedCount = 0;

// Get all enemy groups
private _allGroups = allGroups select {side _x == GRLIB_side_enemy};

// Log the start of the fixing process
diag_log format ["[KPLIB] Starting to fix standing groups - Total enemy groups: %1", count _allGroups];

// Process each group
{
    private _grp = _x;
    
    // Skip if no units in group
    if (count units _grp == 0) then {continue};
    
    // Get group position
    private _pos = getPos (leader _grp);
    
    // Skip if not in the specified sector (if a sector was provided)
    if (_sector != "" && {(_pos distance2D (markerPos _sector)) > (GRLIB_sector_size * 1.5)}) then {continue};
    
    // Check if the group has no waypoints
    if (count waypoints _grp == 0) then {
        // This group probably has no waypoints, so fix it
        diag_log format ["[KPLIB] Found group %1 with no waypoints at %2", _grp, _pos];
        
        // Determine sector for this group
        private _nearestSector = "";
        private _minDist = 999999;
        {
            private _dist = _pos distance2D (markerPos _x);
            if (_dist < _minDist && _dist < GRLIB_sector_size * 1.5) then {
                _nearestSector = _x;
                _minDist = _dist;
            };
        } forEach sectors_allSectors;
        
        // Fix the group by applying AI behavior
        diag_log format ["[KPLIB] Fixing group %1 near sector %2", _grp, _nearestSector];
        
        // Force units to follow their leader
        {
            _x doFollow (leader _grp);
            _x setUnitPos "AUTO";
        } forEach (units _grp);
        
        // Reset group behavior
        _grp setBehaviour "AWARE";
        _grp setCombatMode "YELLOW";
        _grp setSpeedMode "NORMAL";
        
        // Check if this is a vehicle group
        private _vehCount = {vehicle _x != _x} count (units _grp);
        private _unitCount = count (units _grp);
        private _isVehicleGroup = (_vehCount > 0) && (_vehCount >= (_unitCount / 2));
        
        // Apply appropriate waypoints based on group type
        if (_isVehicleGroup) then {
            // Check vehicle specifics for debugging
            private _veh = vehicle (leader _grp);
            private _driver = driver _veh;
            
            // More aggressive fix for vehicle groups
            diag_log format ["[KPLIB] Found stuck vehicle group: %1, Vehicle: %2, Driver: %3", 
                _grp, _veh, _driver];
            
            // Force-refresh driver AI capabilities
            if (!isNull _driver) then {
                // Reset all AI capabilities
                {_driver enableAI _x} forEach ["PATH", "MOVE", "TARGET", "AUTOTARGET"];
                _driver disableAI "AUTOCOMBAT";
                
                // Force driver to follow leader
                _driver doFollow (leader _grp);
                
                diag_log format ["[KPLIB] Reset AI capabilities for driver %1 of vehicle %2", _driver, _veh];
            } else {
                diag_log format ["[KPLIB] No driver found for vehicle %1, attempting to assign one", _veh];
                
                // Try to assign a driver if position is empty
                if (_veh emptyPositions "driver" > 0) then {
                    private _crew = crew _veh;
                    if (count _crew > 0) then {
                        private _unit = _crew select 0;
                        _unit moveInDriver _veh;
                        diag_log format ["[KPLIB] Assigned unit %1 as emergency driver for %2", _unit, _veh];
                    };
                };
            };
            
            // Apply vehicle patrol AI with increased radius to get them moving
            [_grp, markerPos _nearestSector, GRLIB_sector_size] call KPLIB_fnc_applyVehiclePatrol;
            diag_log format ["[KPLIB] Reapplied waypoints to stuck vehicle group %1", _grp];
        } else {
            // Apply normal AI for infantry
            [_grp, markerPos _nearestSector, "patrol", GRLIB_sector_size * 0.75, _nearestSector] call KPLIB_fnc_applySquadAI;
            diag_log format ["[KPLIB] Unstuck infantry group %1 using squad AI function", _grp];
        };
        
        // Increment the fixed count
        _fixedCount = _fixedCount + 1;
    } else {
        // Group has waypoints, check if they're actually following them
        private _isStanding = true;
        
        // Check if any unit is moving - if so, they're probably following waypoints
        {
            if (speed _x > 0.1) exitWith {
                _isStanding = false;
            };
        } forEach (units _grp);
        
        // If all units appear to be standing, and they're not in combat, they might be stuck
        if (_isStanding && behaviour (leader _grp) != "COMBAT") then {
            diag_log format ["[KPLIB] Found potentially stuck group %1 with %2 waypoints", _grp, count waypoints _grp];
            
            // Determine sector for this group
            private _nearestSector = "";
            private _minDist = 999999;
            {
                private _dist = _pos distance2D (markerPos _x);
                if (_dist < _minDist && _dist < GRLIB_sector_size * 1.5) then {
                    _nearestSector = _x;
                    _minDist = _dist;
                };
            } forEach sectors_allSectors;
            
            // Clear existing waypoints
            while {count waypoints _grp > 0} do {
                deleteWaypoint [_grp, 0];
            };
            
            // Force units to follow their leader
            {
                _x doFollow (leader _grp);
                _x setUnitPos "AUTO";
            } forEach (units _grp);
            
            // Check if this is a vehicle group
            private _vehCount = {vehicle _x != _x} count (units _grp);
            private _unitCount = count (units _grp);
            private _isVehicleGroup = (_vehCount > 0) && (_vehCount >= (_unitCount / 2));
            
            // Apply appropriate waypoints based on group type
            if (_isVehicleGroup) then {
                // Check vehicle specifics for debugging
                private _veh = vehicle (leader _grp);
                private _driver = driver _veh;
                
                // More aggressive fix for vehicle groups
                diag_log format ["[KPLIB] Found stuck vehicle group: %1, Vehicle: %2, Driver: %3", 
                    _grp, _veh, _driver];
                
                // Force-refresh driver AI capabilities
                if (!isNull _driver) then {
                    // Reset all AI capabilities
                    {_driver enableAI _x} forEach ["PATH", "MOVE", "TARGET", "AUTOTARGET"];
                    _driver disableAI "AUTOCOMBAT";
                    
                    // Force driver to follow leader
                    _driver doFollow (leader _grp);
                    
                    diag_log format ["[KPLIB] Reset AI capabilities for driver %1 of vehicle %2", _driver, _veh];
                } else {
                    diag_log format ["[KPLIB] No driver found for vehicle %1, attempting to assign one", _veh];
                    
                    // Try to assign a driver if position is empty
                    if (_veh emptyPositions "driver" > 0) then {
                        private _crew = crew _veh;
                        if (count _crew > 0) then {
                            private _unit = _crew select 0;
                            _unit moveInDriver _veh;
                            diag_log format ["[KPLIB] Assigned unit %1 as emergency driver for %2", _unit, _veh];
                        };
                    };
                };
                
                // Apply vehicle patrol AI with increased radius to get them moving
                [_grp, markerPos _nearestSector, GRLIB_sector_size] call KPLIB_fnc_applyVehiclePatrol;
                diag_log format ["[KPLIB] Reapplied waypoints to stuck vehicle group %1", _grp];
            } else {
                // Apply normal AI for infantry
                [_grp, markerPos _nearestSector, "patrol", GRLIB_sector_size * 0.75, _nearestSector] call KPLIB_fnc_applySquadAI;
                diag_log format ["[KPLIB] Unstuck infantry group %1 using squad AI function", _grp];
            };
            
            // Increment the fixed count
            _fixedCount = _fixedCount + 1;
        };
    };
} forEach _allGroups;

// Log the result
diag_log format ["[KPLIB] Fixed %1 standing groups", _fixedCount];

// Return the number of fixed groups
_fixedCount 