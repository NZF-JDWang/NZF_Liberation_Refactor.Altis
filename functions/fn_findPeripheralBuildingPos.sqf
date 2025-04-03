/*
    File: fn_findPeripheralBuildingPos.sqf
    Author: [NZF] JD Wang
    Date: 2024-07-28
    Description:
        Finds a safe position near a building located in the peripheral area of a sector.
        Peripheral area is defined as being outside a central zone (e.g., 40% of sector radius).

    Parameter(s):
        _sectorName   - Name of the sector (marker name) [STRING]
        _sectorCenter - Pre-calculated center position of the sector [ARRAY]
        _sectorRadius - Pre-calculated effective radius of the sector [NUMBER]

    Returns:
        A safe position [ARRAY] near a peripheral building, or [0,0,0] if none found.
*/

params [
    ["_sectorName", "", [""]],
    ["_sectorCenter", [0,0,0], [[]]],
    ["_sectorRadius", 175, [0]] // Default to GRLIB_capture_size typical value
];

if (_sectorName isEqualTo "" || _sectorCenter isEqualTo [0,0,0] || _sectorRadius <= 0) exitWith {
    diag_log format ["[KPLIB] fn_findPeripheralBuildingPos: Invalid parameters provided (Sector: %1, Center: %2, Radius: %3).", _sectorName, _sectorCenter, _sectorRadius];
    [0,0,0]
};

private _centralRadius = _sectorRadius * 0.4;
diag_log format ["[KPLIB] fn_findPeripheralBuildingPos: Searching for peripheral buildings in %1 (Radius: %2m, Central Zone: %3m)", _sectorName, _sectorRadius, _centralRadius];

// Find all house-type buildings within the sector radius
private _allBuildings = nearestObjects [_sectorCenter, ["House"], _sectorRadius, true]; // Sort by distance initially

// Filter out buildings within the central zone
private _peripheralBuildings = _allBuildings select {
    (_x distance2D _sectorCenter) > _centralRadius
};

diag_log format ["[KPLIB] fn_findPeripheralBuildingPos: Found %1 total buildings, %2 peripheral buildings.", count _allBuildings, count _peripheralBuildings];

private _foundPos = [0,0,0];

if (count _peripheralBuildings > 0) then {
    // Try a few times to find a safe position near a random peripheral building
    for "_i" from 1 to 5 do {
        private _targetBuilding = selectRandom _peripheralBuildings;
        private _searchPos = getPos _targetBuilding;

        // Look for a safe spot 5-15m away from the building
        private _potentialPos = [_searchPos, 5, 15, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;

        if (!isNull _potentialPos && !(_potentialPos isEqualTo _searchPos) && (_potentialPos distance2D _searchPos > 1)) then {
            _foundPos = _potentialPos;
            diag_log format ["[KPLIB] fn_findPeripheralBuildingPos: Found safe position %1 near building %2 (Try %3)", _foundPos, _targetBuilding, _i];
            break; // Exit loop once a position is found
        };
    };

    if (_foundPos isEqualTo [0,0,0]) then {
        diag_log format ["[KPLIB] fn_findPeripheralBuildingPos: Could not find a safe position near any peripheral buildings after 5 attempts."];
    };
} else {
    diag_log format ["[KPLIB] fn_findPeripheralBuildingPos: No peripheral buildings found in sector %1.", _sectorName];
};

_foundPos // Return the found position or [0,0,0] 