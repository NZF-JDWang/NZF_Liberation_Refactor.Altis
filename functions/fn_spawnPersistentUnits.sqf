/*
    Function: KPLIB_fnc_spawnPersistentUnits
    
    Description:
        Spawns persistent units in a sector that were previously saved.
        Uses optimized vehicle spawning at [0,0,0] then setting position.
    
    Parameters:
        _sector - Sector marker name
        _sectorpos - Position of the sector
        _sectorUnits - (Optional) Local copy of unit data to spawn
    
    Returns:
        Array of spawned units
    
    Author: [NZF] JD Wang
    Date: 2024-03-25
*/

params ["_sector", "_sectorpos", ["_sectorUnits", []]];

// Initialize return array
private _spawnedUnits = [];
private _totalSpawned = 0;

// If sector units were provided directly, use those
if (count _sectorUnits > 0) then {
    diag_log format ["[KPLIB] Sector %1 persistence - Using provided unit data (%2 entries)", _sector, count _sectorUnits];
} else {
    // Otherwise check if persistent data exists
    if (isNil "KPLIB_persistent_sectors") exitWith {
        diag_log format ["[KPLIB] Sector %1 persistence - No persistence data exists", _sector];
        _spawnedUnits
    };
    
    // Check if persistence data is a HashMap
    if !(KPLIB_persistent_sectors isEqualType createHashMap) exitWith {
        diag_log format ["[KPLIB] Sector %1 persistence - KPLIB_persistent_sectors is not a HashMap but a %2", _sector, typeName KPLIB_persistent_sectors];
        _spawnedUnits
    };
    
    // Check if this sector has persistent data
    if !(_sector in keys KPLIB_persistent_sectors) exitWith {
        diag_log format ["[KPLIB] Sector %1 persistence - No data for this sector", _sector];
        _spawnedUnits
    };
    
    // Get the sector units data
    _sectorUnits = KPLIB_persistent_sectors get _sector;
    
    // Debug the content of the sector units data
    if (count _sectorUnits == 0) exitWith {
        diag_log format ["[KPLIB] Sector %1 persistence - Found empty unit data array", _sector];
        // If empty, clear the flag to allow normal unit spawning
        missionNamespace setVariable [format ["KPLIB_sector_%1_saved", _sector], false, true];
        KPLIB_persistent_sectors deleteAt _sector;
        publicVariable "KPLIB_persistent_sectors";
        // Return early 
        _spawnedUnits
    };
};

diag_log format ["[KPLIB] Sector %1 persistence - Processing %2 unit data entries to spawn", _sector, count _sectorUnits];

// Loop through all unit data and spawn them
{
    private _unitData = _x;
    
    // Check data format first (safety)
    if (_unitData isEqualType [] && {count _unitData >= 2}) then {
        private _dataType = _unitData select 0;
        private _data = _unitData select 1;
        
        // Process based on data type
        switch (_dataType) do {
            case "GROUP": {
                if (_data isEqualType [] && {count _data >= 4}) then {
                    private _leaderPos = _data select 0;
                    private _leaderDir = _data select 1;
                    private _leaderPathDisabled = _data select 2;
                    private _groupData = _data select 3;
                    
                    // Create a group for all members
                    private _grp = createGroup [GRLIB_side_enemy, true];
                    private _groupUnits = [];
                    
                    // First, create all units
                    {
                        if (_x isEqualType [] && {count _x >= 5}) then {
                            private _unitType = _x select 0;
                            private _relPos = _x select 1;
                            private _dir = _x select 2;
                            private _damage = _x select 3;
                            private _pathDisabled = _x select 4;
                            
                            // Calculate actual position
                            private _pos = if (_forEachIndex == 0) then {
                                _leaderPos
                            } else {
                                _leaderPos vectorAdd _relPos
                            };
                            
                            // Create the unit
                            private _unit = _grp createUnit [_unitType, ASLToAGL _pos, [], 0, "NONE"];
                            if (!isNull _unit) then {
                                _unit setDir _dir;
                                _unit setDamage _damage;
                                
                                // Disable path if needed
                                if (_pathDisabled) then {
                                    _unit disableAI "PATH";
                                };
                                
                                _groupUnits pushBack _unit;
                                _spawnedUnits pushBack _unit;
                                _totalSpawned = _totalSpawned + 1;
                            };
                        };
                    } forEach _groupData;
                    
                    // Set up defense waypoints for group if units were created
                    if (count units _grp > 0) then {
                        [_grp, _sectorpos] call add_defense_waypoints;
                    } else {
                        deleteGroup _grp;
                    };
                };
            };
            
            case "VEHICLE": {
                if (_data isEqualType [] && {count _data >= 5}) then {
                    private _vehType = _data select 0;
                    private _vehPos = _data select 1;
                    private _vehDir = _data select 2;
                    private _vehDamage = _data select 3;
                    private _crewData = _data select 4;
                    
                    // Create the vehicle using the optimized method
                    // Create at [0,0,0] first
                    private _veh = createVehicle [_vehType, [0, 0, 0], [], 0, "NONE"];
                    if (!isNull _veh) then {
                        // Set position after creation
                        _veh setPos (ASLToAGL _vehPos);
                        _veh setDir _vehDir;
                        _veh setDamage _vehDamage;
                        
                        // Track the original sector for cleanup
                        _veh setVariable ["KPLIB_sectorOrigin", _sector, true];
                        
                        _spawnedUnits pushBack _veh;
                        _totalSpawned = _totalSpawned + 1;
                        
                        // Create the crew if any
                        if (count _crewData > 0) then {
                            private _crewGrp = createGroup [GRLIB_side_enemy, true];
                            private _crew = [];
                            
                            {
                                if (_x isEqualType [] && {count _x >= 3}) then {
                                    private _unitType = _x select 0;
                                    private _damage = _x select 1;
                                    private _pathDisabled = _x select 2;
                                    
                                    // Create the unit
                                    private _unit = _crewGrp createUnit [_unitType, getPos _veh, [], 0, "NONE"];
                                    if (!isNull _unit) then {
                                        _unit setDamage _damage;
                                        
                                        // Disable path if needed
                                        if (_pathDisabled) then {
                                            _unit disableAI "PATH";
                                        };
                                        
                                        _crew pushBack _unit;
                                        _spawnedUnits pushBack _unit;
                                        _totalSpawned = _totalSpawned + 1;
                                    };
                                };
                            } forEach _crewData;
                            
                            // Assign crew to appropriate vehicle positions
                            private _assignedPositions = false;
                            if (count _crew > 0) then {
                                // Try using BIS_fnc_moveIn to assign crew
                                _assignedPositions = [_veh, _crew] call BIS_fnc_moveIn;
                                
                                // If that didn't assign any positions, assign manually
                                if (!_assignedPositions) then {
                                    // Try to find appropriate positions
                                    private _driverPos = _veh emptyPositions "driver";
                                    private _gunnerPos = _veh emptyPositions "gunner";
                                    private _commanderPos = _veh emptyPositions "commander";
                                    private _cargoPos = _veh emptyPositions "cargo";
                                    
                                    private _crewIndex = 0;
                                    
                                    // Assign driver
                                    if (_driverPos > 0 && _crewIndex < count _crew) then {
                                        (_crew select _crewIndex) moveInDriver _veh;
                                        _crewIndex = _crewIndex + 1;
                                    };
                                    
                                    // Assign gunner
                                    if (_gunnerPos > 0 && _crewIndex < count _crew) then {
                                        (_crew select _crewIndex) moveInGunner _veh;
                                        _crewIndex = _crewIndex + 1;
                                    };
                                    
                                    // Assign commander
                                    if (_commanderPos > 0 && _crewIndex < count _crew) then {
                                        (_crew select _crewIndex) moveInCommander _veh;
                                        _crewIndex = _crewIndex + 1;
                                    };
                                    
                                    // Assign remaining crew to cargo
                                    while (_cargoPos > 0 && _crewIndex < count _crew) do {
                                        (_crew select _crewIndex) moveInCargo _veh;
                                        _crewIndex = _crewIndex + 1;
                                        _cargoPos = _cargoPos - 1;
                                    };
                                };
                            };
                            
                            // Set up defense waypoints for vehicle crew
                            if (count units _crewGrp > 0) then {
                                [_crewGrp, _sectorpos] call add_defense_waypoints;
                            } else {
                                deleteGroup _crewGrp;
                            };
                        };
                    };
                };
            };
            
            default {
                diag_log format ["[KPLIB] Sector %1 persistence - Unknown data type: %2", _sector, _dataType];
            };
        };
    } else {
        diag_log format ["[KPLIB] Sector %1 persistence - Invalid data format: %2", _sector, _unitData];
    };
} forEach _sectorUnits;

diag_log format ["[KPLIB] Sector %1 persistence - Spawned %2 units", _sector, _totalSpawned];

// Clear the saved flag since we've processed the data
missionNamespace setVariable [format ["KPLIB_sector_%1_saved", _sector], false, true];

// Perform a final cleanup to remove any invalid units from the return array
_spawnedUnits = _spawnedUnits select {!isNil "_x" && {!isNull _x} && {alive _x}};

// Return all spawned units
_spawnedUnits 