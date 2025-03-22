/*
    Function: KPLIB_fnc_saveSectorUnits
    
    Description:
        Saves information about units in a sector before cleanup, for persistence between activations
    
    Parameters:
        _sector - Sector marker name
        _sectorpos - Position of the sector
        _managed_units - Array of units currently in the sector
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2024-10-17
*/

params ["_sector", "_sectorpos", "_managed_units"];

// Initialize persistent sectors global if not already
if (isNil "KPLIB_persistent_sectors") then {
    KPLIB_persistent_sectors = createHashMap;
    diag_log "[KPLIB] Created new KPLIB_persistent_sectors hashmap";
};

private _sectorUnits = [];
private _savedCount = 0;
private _processedGroups = [];

// Get all units in the sector area (including any that might not be in managed_units)
private _sectorRange = 500; // Large enough to catch all units
private _allUnits = _sectorpos nearEntities [["Man", "Car", "Tank", "Air", "Ship"], _sectorRange];

diag_log format ["[KPLIB] Sector %1 persistence - Found %2 units in total to process", _sector, count _allUnits];

{
    private _unit = _x;
    
    // Only process enemy units that are alive
    if (alive _unit && 
        ((side _unit == GRLIB_side_enemy) || 
         (side _unit == GRLIB_side_civilian && {_unit getVariable ["KPLIB_insurgent", false]}))
       ) then {
        // Skip vehicles that have been captured
        if (!(_unit isKindOf "Man") && {(_unit getVariable ["KPLIB_captured", false])}) then {
            continue;
        };
        
        // Handle infantry - group based
        if (_unit isKindOf "Man") then {
            private _group = group _unit;
            
            // Only process each group once
            if (!(_group in _processedGroups)) then {
                _processedGroups pushBack _group;
                
                // Get all living units in the group
                private _groupUnits = units _group select {alive _x};
                private _groupData = [];
                
                // Get group leader information
                private _leader = leader _group;
                private _leaderPos = getPosASL _leader;
                private _leaderDir = getDir _leader;
                private _leaderPathDisabled = !(_leader checkAIFeature "PATH");
                
                // Save each unit in the group relative to the leader
                {
                    private _member = _x;
                    private _relPos = if (_member != _leader) then {
                        getPosASL _member vectorDiff _leaderPos
                    } else {
                        [0,0,0]
                    };
                    
                    _groupData pushBack [
                        typeOf _member,                // Unit type
                        _relPos,                      // Position relative to leader
                        getDir _member,                // Direction
                        damage _member,                // Damage
                        !(_member checkAIFeature "PATH") // Whether PATH is disabled
                    ];
                    
                    _savedCount = _savedCount + 1;
                } forEach _groupUnits;
                
                // Add group data to sector units
                _sectorUnits pushBack ["GROUP", [
                    _leaderPos,        // Leader's absolute position 
                    _leaderDir,        // Leader's direction
                    _leaderPathDisabled, // Leader's PATH status
                    _groupData         // Group members data
                ]];
            };
        } 
        // Handle vehicles
        else {
            private _crew = [];
            
            // Save crew information
            {
                if (alive _x) then {
                    _crew pushBack [
                        typeOf _x,                // Unit type
                        damage _x,                // Damage
                        !(_x checkAIFeature "PATH") // Whether PATH is disabled
                    ];
                };
            } forEach (crew _unit);
            
            // Create a vehicle data array
            private _vehData = [
                typeOf _unit,              // Vehicle type
                getPosASL _unit,           // Position
                getDir _unit,              // Direction
                damage _unit,              // Damage
                _crew                      // Crew data
            ];
            
            _sectorUnits pushBack ["VEHICLE", _vehData];
            _savedCount = _savedCount + 1 + count _crew;
        };
    };
} forEach _allUnits;

// Store the sector units data in the global hashmap
if (count _sectorUnits > 0) then {
    // IMPORTANT: Set the sector saved variable BEFORE storing data
    private _sectorSavedVar = format ["KPLIB_sector_%1_saved", _sector];
    missionNamespace setVariable [_sectorSavedVar, true, true];
    
    // Store the data
    KPLIB_persistent_sectors set [_sector, _sectorUnits];
    
    // Ensure the data is saved after modifying
    publicVariable "KPLIB_persistent_sectors";
    
    diag_log format ["[KPLIB] Sector %1 persistence - Saved %2 units across %3 groups/vehicles - Persistence flag set to: %4", 
                     _sector, _savedCount, count _sectorUnits, true];
} else {
    // If there are no units to save, remove any existing entry
    if (_sector in keys KPLIB_persistent_sectors) then {
        KPLIB_persistent_sectors deleteAt _sector;
        publicVariable "KPLIB_persistent_sectors";
    };
    
    // Mark this sector as not having persistent data
    missionNamespace setVariable [format ["KPLIB_sector_%1_saved", _sector], false, true];
    diag_log format ["[KPLIB] Sector %1 persistence - No units to save, persistence flag set to: %2", _sector, false];
};

// Final debug check to verify everything is set correctly
private _persistenceCheck = {
    params ["_sector"];
    
    private _sectorSavedVar = format ["KPLIB_sector_%1_saved", _sector];
    private _hasFlag = missionNamespace getVariable [_sectorSavedVar, false];
    private _hasData = (!isNil "KPLIB_persistent_sectors") && {_sector in keys KPLIB_persistent_sectors};
    
    diag_log format ["[KPLIB] Sector %1 persistence verification - Has flag: %2, Has data: %3", 
                     _sector, _hasFlag, _hasData];
                     
    if (_hasFlag && !_hasData) then {
        diag_log format ["[KPLIB] WARNING: Sector %1 has persistence flag but no data in KPLIB_persistent_sectors", _sector];
    };
    
    if (!_hasFlag && _hasData) then {
        diag_log format ["[KPLIB] WARNING: Sector %1 has data in KPLIB_persistent_sectors but no persistence flag", _sector];
        // Fix the inconsistency
        missionNamespace setVariable [_sectorSavedVar, true, true];
        diag_log format ["[KPLIB] Fixed inconsistency by setting persistence flag for sector %1", _sector];
    };
};

// Check persistence state after a short delay to ensure all operations have completed
[_persistenceCheck, [_sector], 0.5] call CBA_fnc_waitAndExecute; 