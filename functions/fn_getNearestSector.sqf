/*
    Function: KPLIB_fnc_getNearestSector
    
    Description:
        Gets the marker of the nearest sector from a position within a given radius.
    
    Parameters:
        _radius - Search radius [NUMBER, defaults to 1000]
        _pos - Position to search from [ARRAY, defaults to player position]
    
    Returns:
        Marker of nearest sector [STRING]
    
    Example:
        (begin example)
        // Search near player
        _nearestSector = [1000] call KPLIB_fnc_getNearestSector
        
        // Search near a specific position
        _nearestSector = [1000, getPos vehicle1] call KPLIB_fnc_getNearestSector
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-22
*/

params [
    ["_radius", 1000, [0]],
    ["_pos", getPos player, [[]], [2, 3]]
];

private _sectors = [];

{
    private _dist = (markerPos _x) distance2D _pos;
    if (_dist < _radius) then {
        _sectors pushBack [_dist, _x];
    };
} forEach sectors_allSectors;

if (_sectors isEqualTo []) exitWith {""};

_sectors sort true;
(_sectors select 0) select 1
