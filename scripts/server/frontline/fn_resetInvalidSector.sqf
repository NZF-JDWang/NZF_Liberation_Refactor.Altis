/*
    Function: NZF_fnc_resetInvalidSector
    
    Description:
        Resets a sector to its original state after an invalid capture attempt
    
    Parameters:
        _sector - Sector to reset
    
    Returns:
        None
    
    Author: [NZF] JD Wang
    Date: 2023-04-25
*/

params ["_sector"];

diag_log format ["[KPLIB] Resetting invalid sector capture attempt for %1", _sector];

// Get sector position
private _sectorpos = markerPos _sector;
private _radius = GRLIB_sector_size;

// Remove sector from active sectors list if it's there
if (_sector in active_sectors) then {
    active_sectors = active_sectors - [_sector];
    publicVariable "active_sectors";
    diag_log format ["[KPLIB] Removed %1 from active_sectors", _sector];
};

// Find all player-spawned units in the sector
private _units_to_remove = [];
private _groups_to_remove = [];
private _vehicles_to_remove = [];

// Find all units and vehicles in the sector
{
    if ((side group _x) == GRLIB_side_friendly) then {
        if (!isPlayer _x) then {
            _units_to_remove pushBack _x;
            if !(group _x in _groups_to_remove) then {
                _groups_to_remove pushBack (group _x);
            };
        };
    };
} forEach (_sectorpos nearEntities ["Man", _radius]);

// Find all vehicles in the sector
{
    if ((side group _x) == GRLIB_side_friendly) then {
        _vehicles_to_remove pushBack _x;
    };
} forEach (_sectorpos nearEntities [["Car", "Tank", "Air", "Ship"], _radius]);

// Delete units and vehicles
{
    deleteVehicle _x;
} forEach _units_to_remove;

{
    deleteVehicle _x;
} forEach _vehicles_to_remove;

// Delete groups
{
    if (count units _x == 0) then {
        deleteGroup _x;
    };
} forEach _groups_to_remove;

// Mark the sector as invalid again (prevent persistence)
if (!(_sector in NZF_invalid_capture_sectors)) then {
    NZF_invalid_capture_sectors pushBack _sector;
    publicVariable "NZF_invalid_capture_sectors";
};

// Send notification to all players
[6] remoteExec ["KPLIB_fnc_crGlobalMsg", 0]; 