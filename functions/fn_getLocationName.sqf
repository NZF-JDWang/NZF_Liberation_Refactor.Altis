/*
    File: fn_getLocationName.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2019-11-25
    Last Update: 2019-12-06
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Gets the name of the nearest FOB/sector from given position.

    Parameter(s):
        _pos - Position to get the location name from [POSITION, defaults to [0, 0, 0]]

    Returns:
        Location name [STRING]
*/

// Validate input parameters with error handling
private _pos = [0, 0, 0];

// Safely handle parameter parsing
if (_this isEqualType []) then {
    if (count _this > 0) then {
        if (_this select 0 isEqualType []) then {
            _pos = _this select 0;
        } else {
            _pos = _this;
        };
    };
} else {
    diag_log format ["[KPLIB] ERROR in fn_getLocationName: Invalid parameter type: %1", typeName _this];
};

// Ensure position is valid
if !(_pos isEqualType [] && {count _pos >= 2}) then {
    diag_log format ["[KPLIB] ERROR in fn_getLocationName: Invalid position format: %1", _pos];
    _pos = [0, 0, 0];
};

// Get FOB name safely
private _name = "";
try {
    _name = [_pos] call KPLIB_fnc_getFobName;
} catch {
    diag_log format ["[KPLIB] ERROR in fn_getLocationName when calling KPLIB_fnc_getFobName: %1", _exception];
    _name = "";
};

// Return appropriate location name
if (_name isEqualTo "") then {
    private _sector = "";
    try {
        _sector = [50, _pos] call KPLIB_fnc_getNearestSector;
        markerText _sector
    } catch {
        diag_log format ["[KPLIB] ERROR in fn_getLocationName when getting sector name: %1", _exception];
        "Unknown Location"
    };
} else {
    ["FOB", _name] joinString " "
};
