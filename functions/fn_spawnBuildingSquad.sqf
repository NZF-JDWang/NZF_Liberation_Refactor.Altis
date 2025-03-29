/*
    File: fn_spawnBuildingSquad.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2019-12-03
    Last Update: 2020-04-05
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Spawns given amount of infantry in buildings of given sector at given building positions.
        Uses staggered spawning via CBA to reduce lag spikes.

    Parameter(s):
        _type       - Type of infantry. Either "militia" or "army"  [STRING, defaults to "army"]
        _amount     - Amount of infantry units to spawn             [NUMBER, defaults to 0]
        _positions  - Array of building positions                   [ARRAY, defaults to []]
        _sector     - Sector where to spawn the units               [STRING, defaults to ""]

    Returns:
        Spawned units [ARRAY]
*/

params [
    ["_type", "army", [""]],
    ["_amount", 0, [0]],
    ["_positions", [], [[]]],
    ["_sector", "", [""]]
];

if (_sector isEqualTo "") exitWith {["Empty string given"] call BIS_fnc_error; []};

// Get classnames array
private _classnames = [[] call KPLIB_fnc_getSquadComp, militia_squad] select (_type == "militia");

// Adjust amount, if needed
if (_amount > floor ((count _positions) * GRLIB_defended_buildingpos_part)) then {
    _amount = floor ((count _positions) * GRLIB_defended_buildingpos_part)
};

// Create storage for units and positions
private _selectedPositions = [];
private _units = [];

// Get sector marker size to help with position selection variation
private _sectorSize = GRLIB_capture_size;
private _markerSize = getMarkerSize _sector;
if (count _markerSize > 0 && {(_markerSize select 0) > 30}) then {
    _sectorSize = (_markerSize select 0);
};
private _centerPos = markerPos _sector;

// A function to distribute positions across the sector's buildings
// rather than filling one building at a time
private _fnc_selectDistributedPositions = {
    params ["_positions", "_amount", "_centerPos", "_sectorSize"];
    
    // Create an array to store selected positions
    private _selected = [];
    
    // If we have more positions than needed, distribute them
    if (count _positions > _amount) then {
        // Group positions by building to ensure distribution
        private _buildingGroups = [];
        private _currentBuilding = objNull;
        private _currentGroup = [];
        
        // Sort by distance from center to get more significant buildings first
        _positions = [_positions, [], {_centerPos distance _x}, "ASCEND"] call BIS_fnc_sortBy;
        
        {
            private _buildingOfPos = nearestBuilding _x;
            
            // If this is a new building, start a new group
            if (_buildingOfPos != _currentBuilding) then {
                if (count _currentGroup > 0) then {
                    _buildingGroups pushBack _currentGroup;
                };
                _currentGroup = [];
                _currentBuilding = _buildingOfPos;
            };
            
            _currentGroup pushBack _x;
        } forEach _positions;
        
        // Add the last group if it exists
        if (count _currentGroup > 0) then {
            _buildingGroups pushBack _currentGroup;
        };
        
        // Now select positions from different buildings in a distributed fashion
        private _positionCount = 0;
        private _buildingIndex = 0;
        private _maxBuildings = count _buildingGroups;
        
        // Shuffle the building groups for more variation
        _buildingGroups = _buildingGroups call BIS_fnc_arrayShuffle;
        
        // Select positions from different buildings until we have enough
        while {_positionCount < _amount && _maxBuildings > 0} do {
            // Get current building group
            private _currentBuildingPositions = _buildingGroups select (_buildingIndex % _maxBuildings);
            
            // If this building has positions left
            if (count _currentBuildingPositions > 0) then {
                // Select a random position from this building
                private _posIndex = floor random count _currentBuildingPositions;
                private _selectedPos = _currentBuildingPositions deleteAt _posIndex;
                _selected pushBack _selectedPos;
                _positionCount = _positionCount + 1;
            } else {
                // Remove this building from consideration if it has no positions left
                _buildingGroups deleteAt (_buildingIndex % _maxBuildings);
                _maxBuildings = count _buildingGroups;
                
                // Exit if no more buildings
                if (_maxBuildings == 0) exitWith {};
            };
            
            // Move to next building
            _buildingIndex = _buildingIndex + 1;
        };
    } else {
        // Not enough positions, just shuffle and use what we have
        _selected = _positions call BIS_fnc_arrayShuffle;
    };
    
    // Return the selected positions
    _selected
};

// Select positions with better distribution
_selectedPositions = [_positions, _amount, _centerPos, _sectorSize] call _fnc_selectDistributedPositions;

// Get the least loaded headless client for spawning
private _hc = [] call KPLIB_fnc_getLessLoadedHC;
private _owner = if (isNull _hc) then {2} else {owner _hc};

// Create the group on the headless client directly
private _group = [GRLIB_side_enemy] call KPLIB_fnc_createGroupOnHC;

// Log what's happening only in debug mode
if (KP_liberation_debug) then {
    diag_log format ["[KPLIB] Creating building squad in sector %1 on machine %2 - Group: %3", _sector, _owner, _group];
};

// Start with a counter of 0 for the current group
private _currentCount = 0;

// Helper function to create a new group when needed
private _fnc_createNewGroup = {
    // Create using HC function
    private _newGroup = [GRLIB_side_enemy] call KPLIB_fnc_createGroupOnHC;
    if (KP_liberation_debug) then {
        diag_log format ["[KPLIB] Creating new building defense group: %1", _newGroup];
    };
    _newGroup
};

// Update the recursive spawn function
private _fnc_spawnNextUnit = {
    params ["_args", "_handle"];
    _args params ["_classnames", "_pos", "_selectedPositions", "_currentGroup", "_currentCount", "_sector", "_units", "_spawnedCount", "_totalToSpawn", "_owner", "_fnc_createNewGroup"];
    
    // Exit if all units spawned
    if (_spawnedCount >= _totalToSpawn || count _selectedPositions == 0) exitWith {
        [_handle] call CBA_fnc_removePerFrameHandler;
        
        // All units have been spawned, now apply AI behavior to the groups
        // Wait a longer time to ensure all units are properly initialized
        [{
            params ["_units", "_sector", "_pos"];
            
            // Get unique groups from the spawned units
            private _uniqueGroups = [];
            {
                private _group = group _x;
                if (!(_group in _uniqueGroups) && {!isNull _group}) then {
                    _uniqueGroups pushBack _group;
                };
            } forEach _units;
            
            // Log before applying AI (only in debug mode)
            if (KP_liberation_debug) then {
                diag_log format ["[KPLIB] Applying building defense AI behavior to %1 groups in sector %2", count _uniqueGroups, _sector];
            };
            
            // First ensure all units are properly initialized and following their leaders
            // This works regardless of locality
            {
                private _group = _x;
                {
                    _x doFollow (leader _group);
                    _x setUnitPos "AUTO";
                } forEach (units _group);
            } forEach _uniqueGroups;
            
            // Apply appropriate AI behavior to each group
            {
                private _group = _x;
                private _groupOwner = groupOwner _group;
                private _isLocal = _groupOwner == clientOwner;
                
                if (KP_liberation_debug) then {
                    diag_log format ["[KPLIB] Applying AI to building defense group in sector %1 - Local: %2, Owner: %3", 
                                     _sector, _isLocal, _groupOwner];
                };
                
                // This function will handle remote execution if the group is not local
                [_group, markerPos _sector, "building_defense", GRLIB_sector_size * 0.7, _sector] call KPLIB_fnc_applySquadAI;
                
                // Basic commands work across network boundary
                _group setBehaviour "AWARE";
                _group setCombatMode "YELLOW";
            } forEach _uniqueGroups;
            
            // Log after applying AI (only in debug mode)
            if (KP_liberation_debug) then {
                diag_log format ["[KPLIB] Building defense AI behavior applied to all groups in sector %1", _sector];
            };
            
        }, [_units, _sector, _pos], 3.0] call CBA_fnc_waitAndExecute;
    };
    
    // Create new group if needed (max 10 units per group)
    if (_currentCount >= 10) then {
        _currentGroup = call _fnc_createNewGroup;
        _args set [3, _currentGroup];
        _args set [4, 0];
        if (KP_liberation_debug) then {
            diag_log format ["[KPLIB] Created new building squad group on machine %1 - Group: %2", _owner, _currentGroup];
        };
    };
    
    // Get position and spawn unit
    private _unitPos = _selectedPositions deleteAt 0;
    private _unit = [selectRandom _classnames, _pos, _currentGroup] call KPLIB_fnc_createManagedUnit;
    _unit setDir (random 360);
    _unit setPos _unitPos;
    
    // Add to results and update counters
    _units pushBack _unit;
    _args set [4, _currentCount + 1]; // Update current group count
    _args set [7, _spawnedCount + 1]; // Update total spawned count
};

// Start the staggered spawning process - one unit every 0.05 seconds
[
    _fnc_spawnNextUnit,
    0.05,
    [_classnames, _pos, _selectedPositions, _group, _currentCount, _sector, _units, 0, _amount, _owner, _fnc_createNewGroup]
] call CBA_fnc_addPerFrameHandler;

_units
