/*
    Function: KPLIB_fnc_forceBluforCrew
    
    Description:
        Creates vehicle crew from vehicle config.
        If the crew isn't the same side as the players, it'll create a player side crew.
        Uses optimized crew assignment for better performance.
    
    Parameters:
        _veh - Vehicle to add the blufor crew to [OBJECT, defaults to objNull]
    
    Returns:
        Function reached the end [BOOL]
    
    Examples:
        (begin example)
        [_vehicle] call KPLIB_fnc_forceBluforCrew;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-03-25
*/

params [
    ["_veh", objNull, [objNull]]
];

if (isNull _veh) exitWith {["Null object given"] call BIS_fnc_error; false};

// Create regular config crew
private _grp = createVehicleCrew _veh;

// If the config crew isn't the correct side, replace it with the crew classnames from the preset
if ((side _grp) != GRLIB_side_friendly) then {
    {deleteVehicle _x} forEach (units _grp);

    _grp = createGroup [GRLIB_side_friendly, true];
    private _crew = [];
    
    // Create crew members
    while {count _crew < 3} do {
        _crew pushBack ([crewman_classname, getPos _veh, _grp] call KPLIB_fnc_createManagedUnit);
    };
    
    // Optimized crew assignment function
    private _fnc_assignCrew = {
        params ["_vehicle", "_unit", "_role"];
        
        switch (_role) do {
            case "driver": {
                _unit assignAsDriver _vehicle;
                _unit moveInDriver _vehicle;
            };
            case "gunner": {
                _unit assignAsGunner _vehicle;
                _unit moveInGunner _vehicle;
            };
            case "commander": {
                _unit assignAsCommander _vehicle;
                _unit moveInCommander _vehicle;
            };
        };
    };
    
    // Assign crew to vehicle positions
    if (count _crew > 0) then {
        [_veh, _crew select 0, "driver"] call _fnc_assignCrew;
    };
    
    if (count _crew > 1) then {
        [_veh, _crew select 1, "gunner"] call _fnc_assignCrew;
    };
    
    if (count _crew > 2) then {
        [_veh, _crew select 2, "commander"] call _fnc_assignCrew;
    };
    
    // Verify crew positions and assign to cargo if needed
    private _fnc_verifyCrewPositions = {
        params ["_vehicle", "_crew"];
        {
            if (isNull objectParent _x) then {
                _x assignAsCargo _vehicle;
                _x moveInCargo _vehicle;
            };
        } forEach _crew;
    };
    
    [_veh, _crew] call _fnc_verifyCrewPositions;

    // Delete crew which isn't in the vehicle due to e.g. no commander seat
    {
        if (isNull objectParent _x) then {deleteVehicle _x};
    } forEach (units _grp);
};

// Set the crew to safe behaviour
_grp setBehaviour "SAFE";

true
