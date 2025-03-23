/*
    KPLIB_fnc_reinforcementsManager

    File: fn_reinforcementsManager.sqf
    Author: [NZF] JD Wang
    Date: 2023-10-02
    Last Update: 2023-12-04
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Manages enemy reinforcements for sectors under attack.

    Parameter(s):
        _targetSector - Target sector marker [STRING, defaults to ""]

    Returns:
        Function reached the end [BOOL]

    Example(s):
        ["sector_1"] call KPLIB_fnc_reinforcementsManager
*/

params [
    ["_targetSector", "", [""]]
];

// Private function to process reinforcements
private _fnc_processReinforcements = {
    params ["_targetSector"];
    
    private _nearestTower = [markerPos _targetSector] call KPLIB_fnc_getNearestTower;
    private _isSmallSector = _targetSector in sectors_capture;
    
    if (_nearestTower != "") then {
        private _distance = (markerPos _nearestTower) distance2D (markerPos _targetSector);
        private _reason = "";
        private _time_limit = -1;
        private _timer = -1;
        
        if (_isSmallSector) then {
            _time_limit = ((_distance / 1000) * (300 / GRLIB_difficulty_modifier));
            _reason = format ["small sector %1 limit: %2", _targetSector, _time_limit];
        } else {
            _time_limit = ((_distance / 1000) * (150 / GRLIB_difficulty_modifier));
            _reason = format ["big sector %1 limit: %2", _targetSector, _time_limit];
        };
        
        [format ["Reinforcements for %1 scheduled after %2 seconds", _targetSector, _time_limit], "REINFORCEMENTS"] call KPLIB_fnc_log;
        
        [
            {
                params ["_targetSector", "_isSmallSector"];
                
                private _sector_status = [markerPos _targetSector] call KPLIB_fnc_getSectorOwnership;
                private _active_sectors = (sectors_allSectors - blufor_sectors - [_targetSector]) select {
                    [markerPos _x] call KPLIB_fnc_getSectorOwnership == GRLIB_side_resistance
                };
                
                if ((_sector_status == GRLIB_side_resistance) && (count _active_sectors == 0)) then {
                    if (!_isSmallSector) then {
                        [format ["Reinforcements dispatched to: %1", _targetSector], "REINFORCEMENTS"] call KPLIB_fnc_log;
                        reinforcements_sector_under_attack = _targetSector;
                        reinforcements_set = true;
                    
                        if (combat_readiness > 20) then {
                            [_targetSector] call KPLIB_fnc_sendParatroopers;
                        };
                    };
                    
                    true
                } else {
                    [format ["Reinforcements cancelled for: %1 - no longer under attack", _targetSector], "REINFORCEMENTS"] call KPLIB_fnc_log;
                    true
                };
            },
            [_targetSector, _isSmallSector],
            _time_limit
        ] call CBA_fnc_waitAndExecute;
    };
};

// Main execution
if (_targetSector != "") then {
    if (combat_readiness >= 15) then {
        [format ["Starting reinforcement manager for %1", _targetSector], "REINFORCEMENTS"] call KPLIB_fnc_log;
        
        private _isSmallSector = _targetSector in sectors_capture;
        
        if (_isSmallSector) then {
            private _unitCount = [getMarkerPos _targetSector, GRLIB_sector_size, GRLIB_side_enemy] call KPLIB_fnc_getUnitsCount;
            
            if (_unitCount >= 5) then {
                [
                    {
                        params ["_targetSector", "_initialCount"];
                        
                        private _currentCount = [getMarkerPos _targetSector, GRLIB_sector_size, GRLIB_side_enemy] call KPLIB_fnc_getUnitsCount;
                        private _threshold = ceil (_initialCount * 0.75);
                        
                        (_currentCount <= _threshold)
                    },
                    {
                        params ["_targetSector", "_initialCount"];
                        [_targetSector] call _fnc_processReinforcements;
                    },
                    [_targetSector, _unitCount]
                ] call CBA_fnc_waitUntilAndExecute;
            } else {
                [_targetSector] call _fnc_processReinforcements;
            };
        } else {
            [_targetSector] call _fnc_processReinforcements;
        };
    };
};

true 