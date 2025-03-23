params ["_sector", "_radius", "_number"];

if (_number <= 0) exitWith {};

if (KP_liberation_asymmetric_debug > 0) then {[format ["ied_manager.sqf for %1 spawned on: %2", markerText _sector, debug_source], "ASYMMETRIC"] remoteExecCall ["KPLIB_fnc_log", 2];};

_number = round _number;

private _activation_radius_infantry = 6.66;
private _activation_radius_vehicles = 10;

private _spread = 7;
private _infantry_trigger = 1 + (ceil (random 2));
private _ultra_strong = false;
if (random 100 < 12) then {
    _ultra_strong = true;
};
private _vehicle_trigger = 1;
private _ied_type = selectRandom ["IEDLandBig_F","IEDLandSmall_F","IEDUrbanBig_F","IEDUrbanSmall_F"];
private _ied_obj = objNull;
private _roadobj = [(markerPos _sector) getPos [random _radius, random 360], _radius, []] call BIS_fnc_nearestRoad;
private _ied_marker = "";

if (KP_liberation_asymmetric_debug > 0) then {[format ["ied_manager.sqf -> spawning IED %1 at %2", _number, markerText _sector], "ASYMMETRIC"] remoteExecCall ["KPLIB_fnc_log", 2];};

if (_number > 0) then {
    [_sector, _radius, _number - 1] spawn ied_manager;
};

if (!(isnull _roadobj)) then {
    _roadpos = getpos _roadobj;
    _ied_obj = createMine [_ied_type, _roadpos getPos [_spread, random 360], [], 0];
    _ied_obj setdir (random 360);

    if (KP_liberation_asymmetric_debug > 0) then {[format ["ied_manager.sqf -> IED %1 spawned at %2", _number, markerText _sector], "ASYMMETRIC"] remoteExecCall ["KPLIB_fnc_log", 2];};

    // IED checking function
    private _fnc_checkIED = {
        params ["_args", "_idPFH"];
        _args params ["_ied_obj", "_sector", "_infantry_trigger", "_vehicle_trigger", "_activation_radius_infantry", "_activation_radius_vehicles", "_ultra_strong", "_number"];
        
        if (!(_sector in active_sectors) || !(mineActive _ied_obj)) then {
            // Exit condition met, remove PFH
            [_idPFH] call CBA_fnc_removePerFrameHandler;
            
            if ((KP_liberation_asymmetric_debug > 0) && !(isNull _ied_obj)) then {
                [format ["ied_manager.sqf -> exited IED %1 loop at %2", _number, markerText _sector], "ASYMMETRIC"] remoteExecCall ["KPLIB_fnc_log", 2];
            };
            
            // Schedule cleanup after 30 minutes
            [
                {
                    params ["_ied_obj"];
                    if (!(isNull _ied_obj)) then {deleteVehicle _ied_obj;};
                },
                [_ied_obj],
                1800
            ] call CBA_fnc_waitAndExecute;
        } else {
            // Check for nearby units
            private _nearinfantry = ((getpos _ied_obj) nearEntities ["Man", _activation_radius_infantry]) select {side _x == GRLIB_side_friendly};
            private _nearvehicles = ((getpos _ied_obj) nearEntities [["Car", "Tank", "Air"], _activation_radius_vehicles]) select {side _x == GRLIB_side_friendly};
            
            if (count _nearinfantry >= _infantry_trigger || count _nearvehicles >= _vehicle_trigger) then {
                if (_ultra_strong) then {
                    "Bomb_04_F" createVehicle (getpos _ied_obj);
                    deleteVehicle _ied_obj;
                } else {
                    _ied_obj setDamage 1;
                };
                stats_ieds_detonated = stats_ieds_detonated + 1; publicVariable "stats_ieds_detonated";
                
                // Detonated, remove PFH
                [_idPFH] call CBA_fnc_removePerFrameHandler;
                
                if (KP_liberation_asymmetric_debug > 0) then {
                    [format ["ied_manager.sqf -> IED %1 detonated at %2", _number, markerText _sector], "ASYMMETRIC"] remoteExecCall ["KPLIB_fnc_log", 2];
                };
            };
        };
    };
    
    // Start the PFH to check IED status every second
    [
        _fnc_checkIED,
        1,
        [_ied_obj, _sector, _infantry_trigger, _vehicle_trigger, _activation_radius_infantry, _activation_radius_vehicles, _ultra_strong, _number]
    ] call CBA_fnc_addPerFrameHandler;
    
} else {
    if (KP_liberation_asymmetric_debug > 0) then {[format ["ied_manager.sqf -> _roadobj is Null for IED %1 at %2", _number, markerText _sector], "ASYMMETRIC"] remoteExecCall ["KPLIB_fnc_log", 2];};
    
    // Schedule cleanup after 30 minutes even if road object is null
    [
        {
            params ["_ied_obj"];
            if (!(isNull _ied_obj)) then {deleteVehicle _ied_obj;};
        },
        [_ied_obj],
        1800
    ] call CBA_fnc_waitAndExecute;
};
