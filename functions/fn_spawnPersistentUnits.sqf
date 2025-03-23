/*
    Function: KPLIB_fnc_spawnPersistentUnits
    
    Description:
        Spawns persistent units in a sector that were previously saved
    
    Parameters:
        _sector - Sector marker name
        _sectorpos - Position of the sector
    
    Returns:
        Array of spawned units
    
    Author: [NZF] JD Wang
    Date: 2024-10-17
*/

params ["_sector", "_sectorpos"];

// Initialize return array
private _spawnedUnits = [];

// Check if persistent data exists
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
private _sectorUnits = KPLIB_persistent_sectors get _sector;
private _totalSpawned = 0;

diag_log format ["[KPLIB] Sector %1 persistence - Found %2 unit data entries to spawn", _sector, count _sectorUnits];

// Create a local copy of the data before processing to prevent race conditions
private _sectorUnitsLocal = +_sectorUnits;

{
    private _unitData = _x;
    if (isNil "_unitData") then {
        diag_log format ["[KPLIB] Sector %1 persistence - Found nil unit data entry at index %2", _sector, _forEachIndex];
        continue;
    };
    
    if (!(_unitData isEqualType [])) then {
        diag_log format ["[KPLIB] Sector %1 persistence - Invalid unit data type at index %2: %3", _sector, _forEachIndex, typeName _unitData];
        continue;
    };
    
    if (count _unitData < 2) then {
        diag_log format ["[KPLIB] Sector %1 persistence - Incomplete unit data at index %2: %3", _sector, _forEachIndex, _unitData];
        continue;
    };
    
    _unitData params ["_type", "_data"];
    
    // Process based on unit type
    switch (_type) do {
        case "GROUP": {
            if (!(_data isEqualType [])) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Invalid GROUP data type: %2", _sector, typeName _data];
                continue;
            };
            
            if (count _data < 4) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Incomplete GROUP data: %2", _sector, _data];
                continue;
            };
            
            _data params ["_leaderPos", "_leaderDir", "_leaderPathDisabled", "_groupData"];
            
            // Create the enemy group
            private _grp = createGroup GRLIB_side_enemy;
            private _groupUnitsSpawned = 0;
            
            {
                if (!(_x isEqualType [])) then {
                    diag_log format ["[KPLIB] Sector %1 persistence - Invalid unit data in GROUP: %2", _sector, typeName _x];
                    continue;
                };
                
                if (count _x < 5) then {
                    diag_log format ["[KPLIB] Sector %1 persistence - Incomplete unit data in GROUP: %2", _sector, _x];
                    continue;
                };
                
                _x params ["_unitType", "_relPos", "_unitDir", "_unitDamage", "_pathDisabled"];
                
                // Validate unit type
                if (!isClass (configFile >> "CfgVehicles" >> _unitType)) then {
                    diag_log format ["[KPLIB] Sector %1 persistence - Invalid unit type in GROUP: %2", _sector, _unitType];
                    continue;
                };
                
                // Create unit with error handling
                private _unit = objNull;
                try {
                    _unit = _grp createUnit [_unitType, [0,0,0], [], 0, "NONE"];
                } catch {
                    diag_log format ["[KPLIB] Sector %1 persistence - Failed to create unit of type %2: %3", _sector, _unitType, _exception];
                    continue;
                };
                
                if (isNull _unit) then {
                    diag_log format ["[KPLIB] Sector %1 persistence - Created null unit of type %2", _sector, _unitType];
                    continue;
                };
                
                // Set unit properties
                if (_forEachIndex == 0) then {
                    // Leader gets absolute position
                    _unit setPosASL _leaderPos;
                } else {
                    // Others get position relative to leader
                    _unit setPosASL (_leaderPos vectorAdd _relPos);
                };
                
                _unit setDir _unitDir;
                _unit setDamage _unitDamage;
                
                // Disable PATH if needed
                if (_pathDisabled) then {
                    _unit disableAI "PATH";
                };
                
                // Track that this unit belongs to this sector for future persistence
                _unit setVariable ["KPLIB_sectorOrigin", _sector, true];
                
                // Add to return array
                _spawnedUnits pushBack _unit;
                _totalSpawned = _totalSpawned + 1;
                _groupUnitsSpawned = _groupUnitsSpawned + 1;
            } forEach _groupData;
            
            diag_log format ["[KPLIB] Sector %1 persistence - Spawned %2 units in GROUP", _sector, _groupUnitsSpawned];
            
            // Only set up waypoints if the group has units
            if (count units _grp > 0) then {
                // Set up defense waypoints for the group
                [_grp, _sectorpos] call add_defense_waypoints;
            } else {
                diag_log format ["[KPLIB] Sector %1 persistence - GROUP had no valid units to spawn", _sector];
                deleteGroup _grp;
            };
        };
        
        case "VEHICLE": {
            if (!(_data isEqualType [])) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Invalid VEHICLE data type: %2", _sector, typeName _data];
                continue;
            };
            
            if (count _data < 5) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Incomplete VEHICLE data: %2", _sector, _data];
                continue;
            };
            
            _data params ["_vehType", "_vehPos", "_vehDir", "_vehDamage", "_crewData"];
            
            // Validate vehicle type
            if (!isClass (configFile >> "CfgVehicles" >> _vehType)) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Invalid vehicle type: %2", _sector, _vehType];
                continue;
            };
            
            // Create the vehicle with error handling
            private _veh = objNull;
            try {
                _veh = createVehicle [_vehType, [0,0,0], [], 0, "NONE"];
            } catch {
                diag_log format ["[KPLIB] Sector %1 persistence - Failed to create vehicle of type %2: %3", _sector, _vehType, _exception];
                continue;
            };
            
            // Ensure vehicle was created properly
            if (isNull _veh) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Created null vehicle of type %2", _sector, _vehType];
                continue;
            };
            
            // Ensure vehicle isn't already dead before proceeding
            if (!alive _veh) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Failed to create vehicle %2 (created dead)", _sector, _vehType];
                deleteVehicle _veh;
                continue;
            };
            
            // Set vehicle properties
            _veh setPosASL _vehPos;
            _veh setDir _vehDir;
            _veh setDamage _vehDamage;
            
            // Mark vehicle as belonging to this sector
            _veh setVariable ["KPLIB_sectorOrigin", _sector, true];
            
            // Create crew
            private _crewSpawned = 0;
            if (count _crewData > 0) then {
                private _grp = createGroup GRLIB_side_enemy;
                
                {
                    if (!(_x isEqualType [])) then {
                        diag_log format ["[KPLIB] Sector %1 persistence - Invalid crew data type: %2", _sector, typeName _x];
                        continue;
                    };
                    
                    if (count _x < 3) then {
                        diag_log format ["[KPLIB] Sector %1 persistence - Incomplete crew data: %2", _sector, _x];
                        continue;
                    };
                    
                    _x params ["_crewType", "_crewDamage", "_pathDisabled"];
                    
                    // Validate crew type
                    if (!isClass (configFile >> "CfgVehicles" >> _crewType)) then {
                        diag_log format ["[KPLIB] Sector %1 persistence - Invalid crew type: %2", _sector, _crewType];
                        continue;
                    };
                    
                    // Create crew member with error handling
                    private _crewMember = objNull;
                    try {
                        _crewMember = _grp createUnit [_crewType, [0,0,0], [], 0, "NONE"];
                    } catch {
                        diag_log format ["[KPLIB] Sector %1 persistence - Failed to create crew of type %2: %3", _sector, _crewType, _exception];
                        continue;
                    };
                    
                    if (isNull _crewMember) then {
                        diag_log format ["[KPLIB] Sector %1 persistence - Created null crew of type %2", _sector, _crewType];
                        continue;
                    };
                    
                    _crewMember setDamage _crewDamage;
                    
                    // Mark crew as belonging to this sector
                    _crewMember setVariable ["KPLIB_sectorOrigin", _sector, true];
                    
                    // Disable PATH if needed
                    if (_pathDisabled) then {
                        _crewMember disableAI "PATH";
                    };
                    
                    // Store reference for return
                    _spawnedUnits pushBack _crewMember;
                    _totalSpawned = _totalSpawned + 1;
                    _crewSpawned = _crewSpawned + 1;
                    
                    // Assign to vehicle based on position availability
                    if (_veh emptyPositions "driver" > 0) then {
                        _crewMember assignAsDriver _veh;
                        _crewMember moveInDriver _veh;
                    } else {
                        if (_veh emptyPositions "gunner" > 0) then {
                            _crewMember assignAsGunner _veh;
                            _crewMember moveInGunner _veh;
                        } else {
                            if (_veh emptyPositions "commander" > 0) then {
                                _crewMember assignAsCommander _veh;
                                _crewMember moveInCommander _veh;
                            } else {
                                _crewMember assignAsCargo _veh;
                                _crewMember moveInCargo _veh;
                            };
                        };
                    };
                } forEach _crewData;
                
                diag_log format ["[KPLIB] Sector %1 persistence - Spawned vehicle %2 with %3 crew members", _sector, _vehType, _crewSpawned];
                
                // Only set up waypoints if the group has units
                if (count units _grp > 0) then {
                    // Set up waypoints for the vehicle group
                    [_grp, _sectorpos] call add_defense_waypoints;
                } else {
                    diag_log format ["[KPLIB] Sector %1 persistence - Vehicle %2 crew group had no valid units", _sector, _vehType];
                    deleteGroup _grp;
                };
            } else {
                diag_log format ["[KPLIB] Sector %1 persistence - Spawned empty vehicle %2", _sector, _vehType];
            };
            
            // Store vehicle reference for return
            _spawnedUnits pushBack _veh;
            _totalSpawned = _totalSpawned + 1;
        };
        
        case "MAN": {
            if (!(_data isEqualType [])) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Invalid MAN data type: %2", _sector, typeName _data];
                continue;
            };
            
            if (count _data < 5) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Incomplete MAN data: %2", _sector, _data];
                continue;
            };
            
            // Handle legacy format if it exists
            _data params ["_unitType", "_unitPos", "_unitDir", "_unitDamage", "_pathDisabled"];
            
            // Validate unit type
            if (!isClass (configFile >> "CfgVehicles" >> _unitType)) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Invalid unit type in MAN: %2", _sector, _unitType];
                continue;
            };
            
            // Create the unit with error handling
            private _grp = createGroup GRLIB_side_enemy;
            private _unit = objNull;
            
            try {
                _unit = _grp createUnit [_unitType, [0,0,0], [], 0, "NONE"];
            } catch {
                diag_log format ["[KPLIB] Sector %1 persistence - Failed to create unit of type %2: %3", _sector, _unitType, _exception];
                deleteGroup _grp;
                continue;
            };
            
            if (isNull _unit) then {
                diag_log format ["[KPLIB] Sector %1 persistence - Created null unit of type %2", _sector, _unitType];
                deleteGroup _grp;
                continue;
            };
            
            // Set unit properties
            _unit setPosASL _unitPos;
            _unit setDir _unitDir;
            _unit setDamage _unitDamage;
            
            // Mark unit as belonging to this sector
            _unit setVariable ["KPLIB_sectorOrigin", _sector, true];
            
            // Disable PATH if needed
            if (_pathDisabled) then {
                _unit disableAI "PATH";
            };
            
            // Set up waypoints
            [_grp, _sectorpos] call add_defense_waypoints;
            
            diag_log format ["[KPLIB] Sector %1 persistence - Spawned single MAN unit of type %2", _sector, _unitType];
            
            // Add to return array
            _spawnedUnits pushBack _unit;
            _totalSpawned = _totalSpawned + 1;
        };
        
        default {
            diag_log format ["[KPLIB] Sector %1 persistence - Unknown unit type: %2", _sector, _type];
        };
    };
} forEach _sectorUnitsLocal;

// Clear the persistence data now that we've used it
KPLIB_persistent_sectors deleteAt _sector;
publicVariable "KPLIB_persistent_sectors";

// Clear the saved flag as well
missionNamespace setVariable [format ["KPLIB_sector_%1_saved", _sector], false, true];
diag_log format ["[KPLIB] Sector %1 persistence - Spawned %2 units", _sector, _totalSpawned];

// Return all spawned units
_spawnedUnits 