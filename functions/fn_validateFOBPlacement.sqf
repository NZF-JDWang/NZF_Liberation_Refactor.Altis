/*
    Function: KPLIB_fnc_validateFOBPlacement
    
    Description:
        Validates if a FOB can be placed at the given position
        based on proximity to friendly sectors
    
    Parameters:
        _position - Position array [x,y,z] for the FOB
    
    Returns:
        Boolean - True if FOB can be placed, false otherwise
    
    Author: [NZF] JD Wang
    Date: 2024-11-08
*/

params ["_position"];

// First FOB can be placed anywhere
if (count GRLIB_all_fobs == 0) exitWith {
    diag_log "[KPLIB] First FOB placement - allowed anywhere";
    true
};

// Check if position is within 1500m of any friendly sector
private _valid = false;
private _closestDistance = 999999;
private _closestSector = "";

{
    private _distance = _position distance2D (markerPos _x);
    
    if (_distance < _closestDistance) then {
        _closestDistance = _distance;
        _closestSector = _x;
    };
    
    if (_distance <= 1500) exitWith {
        _valid = true;
    };
} forEach blufor_sectors;

// If not valid, provide a specific error message
if (!_valid) then {
    private _msg = "";
    if (_closestSector != "") then {
        _msg = format ["Cannot build FOB here! You need to be within 1500m of a friendly sector (Current distance to nearest sector: %1m)", floor _closestDistance];
    } else {
        _msg = "Cannot build FOB here! You need to be within 1500m of a friendly sector (No friendly sectors captured yet)";
    };
    
    // Send the message to all players
    [_msg] remoteExec ["systemChat", 0];
    
    // Force FOB build to be aborted immediately
    FOB_build_in_progress = false;
    publicVariable "FOB_build_in_progress";
};

_valid 