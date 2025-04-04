params ["_sector"];

if (KP_liberation_asymmetric_debug > 0) then {[format ["Sector %1 (%2) - sector_guerilla spawned on: %3", (markerText _sector), _sector, debug_source], "ASYMMETRIC"] remoteExecCall ["KPLIB_fnc_log", 2];};

private _startpos = (markerPos _sector) getPos [(1200 + (round (random 400))), (random 360)];

while {(([_startpos, 500, GRLIB_side_friendly] call KPLIB_fnc_getUnitsCount) > 0) || (surfaceIsWater _startpos)} do {
    _startpos = (markerPos _sector) getPos [(1200 + (round (random 400))), (random 360)];
};

private _incDir = (markerPos _sector) getDir _startpos;
private _incString = "unknown";

if (_incDir < 23) then {
    _incString = "N";
} else {
    if (_incDir < 68) then {
        _incString = "NE";
    } else {
        if (_incDir < 113) then {
            _incString = "E";
        } else {
            if (_incDir < 158) then {
                _incString = "SE";
            } else {
                if (_incDir < 203) then {
                    _incString = "S";
                } else {
                    if (_incDir < 248) then {
                        _incString = "SW";
                    } else {
                        if (_incDir < 293) then {
                            _incString = "W";
                        } else {
                            if (_incDir < 338) then {
                                _incString = "NW";
                            } else {
                                _incString = "N";
                            };
                        };
                    };
                };
            };
        };
    };
};

[5, [(markerText _sector), _incString]] remoteExec ["KPLIB_fnc_crGlobalMsg"];

private _spawnedGroups = [];

// Spawn infantry guerrilla group
private _grp = [_startpos] call KPLIB_fnc_spawnGuerillaGroup;

// Add waypoints to move to the sector
private _waypoint = _grp addWaypoint [markerpos _sector, 100];
_waypoint setWaypointType "MOVE";
_waypoint setWaypointBehaviour "AWARE";
_waypoint = _grp addWaypoint [markerpos _sector, 100];
_waypoint setWaypointType "SAD";
_waypoint = _grp addWaypoint [markerpos _sector, 100];
_waypoint setWaypointType "SAD";
_waypoint = _grp addWaypoint [markerpos _sector, 100];
_waypoint setWaypointType "CYCLE";

_spawnedGroups pushBack _grp;

sleep 30;

// Spawn guerilla vehicle if chance permits
if (((random 100) <= 25) && !(KP_liberation_guerilla_vehicles isEqualTo [])) then {
    private _vehicle = (selectRandom KP_liberation_guerilla_vehicles) createVehicle _startpos;
    [_vehicle] call KPLIB_fnc_allowCrewInImmobile;

    private _grp = [_startpos, 2] call KPLIB_fnc_spawnGuerillaGroup;
    ((units _grp) select 0) moveInDriver _vehicle;
    ((units _grp) select 1) moveInGunner _vehicle;

    // Add vanilla waypoints for vehicle movement
    private _waypoint = _grp addWaypoint [markerpos _sector, 100];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointBehaviour "AWARE";
    _waypoint = _grp addWaypoint [markerpos _sector, 100];
    _waypoint setWaypointType "SAD";
    _waypoint = _grp addWaypoint [markerpos _sector, 100];
    _waypoint setWaypointType "SAD";
    _waypoint = _grp addWaypoint [markerpos _sector, 100];
    _waypoint setWaypointType "CYCLE";

    _spawnedGroups pushBack _grp;
};

waitUntil {sleep 60; !(_sector in active_sectors)};

sleep 60;

private _strengthChanged = false;

{
    if (!isNull _x) then {
        {
            if (alive _x) then {
                deleteVehicle _x;
                KP_liberation_guerilla_strength = KP_liberation_guerilla_strength + 2;
                _strengthChanged = true;
            };
        } forEach (units _x);
    };
} forEach _spawnedGroups;

if (!isServer && _strengthChanged) then {
    publicVariableServer "KP_liberation_guerilla_strength";
};

if (KP_liberation_asymmetric_debug > 0) then {[format ["Sector %1 (%2) - sector_guerilla dropped on: %3", (markerText _sector), _sector, debug_source], "ASYMMETRIC"] remoteExecCall ["KPLIB_fnc_log", 2];};
