waitUntil {!isNil "save_is_loaded"};
waitUntil {!isNil "GRLIB_vehicle_to_military_base_links"};
waitUntil {!isNil "blufor_sectors"};
waitUntil {save_is_loaded};

private _vehicle_unlock_markers = [];
private _cfg = configFile >> "cfgVehicles";

{
    _x params ["_vehicle", "_base"];
    private _marker = createMarkerLocal [format ["vehicleunlockmarker%1", _base], [(markerpos _base) select 0, ((markerpos _base) select 1) + 125]];
    _marker setMarkerTextLocal (getText (_cfg >> _vehicle >> "displayName"));
    _marker setMarkerColorLocal GRLIB_color_enemy;
    _marker setMarkerTypeLocal "mil_pickup";
    _vehicle_unlock_markers pushback [_marker, _base];
} forEach GRLIB_vehicle_to_military_base_links;

private _sector_count = -1;

uiSleep 1;

while {true} do {
    waitUntil {
        uiSleep 1;
        count blufor_sectors != _sector_count
    };

    // First set all non-blufor sectors to grey with low alpha
    {
        if !(_x in blufor_sectors) then {
            _x setMarkerColorLocal "ColorGrey";
            _x setMarkerAlphaLocal 0.4;
        };
    } forEach sectors_allSectors;
    
    // Then set blufor sectors to friendly color
    {
        _x setMarkerColorLocal GRLIB_color_friendly;
        _x setMarkerAlphaLocal 1;
    } forEach blufor_sectors;
    
    // If validateSectorCapture function is available, update capturable sectors
    if (!isNil "KPLIB_fnc_validateSectorCapture") then {
        {
            if (!(_x in blufor_sectors) && {[_x] call KPLIB_fnc_validateSectorCapture}) then {
                _x setMarkerColorLocal GRLIB_color_enemy;
                _x setMarkerAlphaLocal 1;
            };
        } forEach sectors_allSectors;
    };

    // Update vehicle unlock markers
    {
        _x params ["_marker", "_base"];
        _marker setMarkerColorLocal ([GRLIB_color_enemy, GRLIB_color_friendly] select (_base in blufor_sectors));
    } forEach _vehicle_unlock_markers;
    
    _sector_count = count blufor_sectors;
};
