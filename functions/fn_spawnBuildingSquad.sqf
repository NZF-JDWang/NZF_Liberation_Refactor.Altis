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

// Select positions in advance
for "_i" from 1 to _amount do {
    if (count _positions > 0) then {
        _selectedPositions pushBack (_positions deleteAt (floor (random count _positions)));
    };
};

// Create initial group
private _grp = createGroup [GRLIB_side_enemy, true];
private _pos = markerPos _sector;
private _currentGroup = _grp;
private _currentCount = 0;

// Recursive function to spawn units with staggered delay
private _fnc_spawnNextUnit = {
    params ["_args", "_handle"];
    _args params ["_classnames", "_pos", "_selectedPositions", "_currentGroup", "_currentCount", "_sector", "_units", "_spawnedCount", "_totalToSpawn"];
    
    // Exit if all units spawned
    if (_spawnedCount >= _totalToSpawn || count _selectedPositions == 0) exitWith {
        [_handle] call CBA_fnc_removePerFrameHandler;
    };
    
    // Create new group if needed (max 10 units per group)
    if (_currentCount >= 10) then {
        _currentGroup = createGroup [GRLIB_side_enemy, true];
        _args set [3, _currentGroup];
        _args set [4, 0];
    };
    
    // Get position and spawn unit
    private _unitPos = _selectedPositions deleteAt 0;
    private _unit = [selectRandom _classnames, _pos, _currentGroup] call KPLIB_fnc_createManagedUnit;
    _unit setDir (random 360);
    _unit setPos _unitPos;
    
    // Start building defense AI
    [_unit, _sector] spawn building_defence_ai;
    
    // Add to results and update counters
    _units pushBack _unit;
    _args set [4, _currentCount + 1]; // Update current group count
    _args set [7, _spawnedCount + 1]; // Update total spawned count
};

// Start the staggered spawning process - one unit every 0.05 seconds
[
    _fnc_spawnNextUnit,
    0.05,
    [_classnames, _pos, _selectedPositions, _currentGroup, _currentCount, _sector, _units, 0, _amount]
] call CBA_fnc_addPerFrameHandler;

_units
