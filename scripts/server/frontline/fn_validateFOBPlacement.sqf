/*
    Function: NZF_fnc_validateFOBPlacement
    
    Description:
        Checks if a FOB can be placed at the given position based on proximity to friendly sectors
    
    Parameters:
        _position - Position array [x,y,z]
    
    Returns:
        Boolean - True if FOB can be placed, false otherwise
    
    Author: [NZF] JD Wang
    Date: 2023-04-25
*/

params ["_position"];

// If this is the first FOB, allow placement anywhere
if (isNil "NZF_first_fob_placed") then {
    NZF_first_fob_placed = false;
    publicVariable "NZF_first_fob_placed";
};

// If this is the first FOB or GRLIB_all_fobs is empty, allow placement
if (!NZF_first_fob_placed || count GRLIB_all_fobs == 0) exitWith {
    // Note: We don't set NZF_first_fob_placed here anymore
    // This will be set in build_fob_remote_call.sqf after successful placement
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