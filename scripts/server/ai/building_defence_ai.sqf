/*
    Function: building_defence_ai
    
    Description:
        Manages AI behavior for building defenders.
        Uses LAMBS AI functions to create dynamic defense patterns if available.
        Falls back to vanilla Arma 3 behavior if LAMBS is not available.
        Changes behavior based on BLUFOR ratio in the sector.
    
    Parameters:
        _unit - The AI unit to control
        _sector - The sector marker name
    
    Returns:
        Nothing
    
    Examples:
        [_unit, _sectorName] spawn building_defence_ai;
    
    Author: [NZF] JD Wang
    Date: 2023-10-21
*/

params ["_unit", ["_sector", ""]];

// Check for LAMBS availability
private _hasLAMBS = (!isNil "lambs_wp_fnc_taskGarrison");
diag_log format ["[KP LIBERATION] Building defence AI - LAMBS availability: %1", _hasLAMBS];

// Initial setup - use LAMBS garrison or vanilla garrison
if (_hasLAMBS) then {
    [(group _unit), _sector, 400, [], true, false, -1, false] call lambs_wp_fnc_taskGarrison;
} else {
    // Vanilla AI building garrison behavior
    private _group = group _unit;
    private _sectorPos = getMarkerPos _sector;
    
    // Set combat mode and behavior
    _group setCombatMode "YELLOW";
    _group setBehaviour "AWARE";
    
    // Find nearby buildings
    private _nearbyBuildings = _sectorPos nearObjects ["Building", 400];
    if (count _nearbyBuildings > 0) then {
        // Assign building positions
        private _buildingPositions = [];
        {
            _buildingPositions append (_x buildingPos -1);
        } forEach _nearbyBuildings;
        
        // Filter valid positions (above ground level)
        _buildingPositions = _buildingPositions select {_x select 2 > 0.5};
        
        if (count _buildingPositions > 0) then {
            // Move unit to building position
            private _pos = selectRandom _buildingPositions;
            _unit doMove _pos;
            _unit setUnitPos "UP";
            
            // Log the action
            diag_log format ["[KP LIBERATION] Unit %1 garrisoned at building (vanilla method)", _unit];
        } else {
            // No suitable positions found, use standard defend
            [_group, _sectorPos, 100] call BIS_fnc_taskDefend;
        };
    } else {
        // No buildings nearby, use standard defend
        [_group, _sectorPos, 100] call BIS_fnc_taskDefend;
    };
};

// Default values
private _ratio = 0.2;
private _pfhHandle = -1;

// Set up the per-frame handler
_pfhHandle = [{
    params ["_args", "_handle"];
    _args params ["_unit", "_sector", "_hasLAMBS"];
    
    // Exit conditions
    if (!local _unit || !alive _unit || captive _unit) exitWith {
        [_handle] call CBA_fnc_removePerFrameHandler;
    };
    
    // Get current blufor ratio in sector
    private _ratio = [_sector] call KPLIB_fnc_getBluforRatio;
    
    // Change tactics if Blufor presence is significant
    if (_ratio > 0.5) then {
        if (_hasLAMBS) then {
            // Reset current taskings
            [(group _unit)] call lambs_wp_fnc_taskReset;
            
            // Randomly select between different tactics
            private _randomChoice = random 100;
            
            if (_randomChoice > 75) then {
                // Tighter garrison - more defensive
                [(group _unit), _sector, 150, [], false, false, -2, true] call lambs_wp_fnc_taskGarrison;
                [format ["Building defender using tighter LAMBS garrison at ratio %1", _ratio], "DEBUG"] call KPLIB_fnc_log;
            } else {
                if (_randomChoice > 50) then {
                    // CQB - building clearing behavior
                    [(group _unit), _sector, 100] call lambs_wp_fnc_taskCQB;
                    [format ["Building defender using LAMBS CQB at ratio %1", _ratio], "DEBUG"] call KPLIB_fnc_log;
                } else {
                    // Rush - aggressive behavior
                    [(group _unit), 500] call lambs_wp_fnc_taskRush;
                    [format ["Building defender using LAMBS Rush at ratio %1", _ratio], "DEBUG"] call KPLIB_fnc_log;
                };
            };
        } else {
            // Vanilla AI response to high blufor presence
            private _group = group _unit;
            private _sectorPos = getMarkerPos _sector;
            private _randomChoice = random 100;
            
            if (_randomChoice > 60) then {
                // More defensive - stay put but be alert
                _group setCombatMode "RED";
                _group setBehaviour "COMBAT";
                _unit setUnitPos "MIDDLE";
                [format ["Building defender using vanilla defensive behavior at ratio %1", _ratio], "DEBUG"] call KPLIB_fnc_log;
            } else {
                // More aggressive - actively seek targets
                [_group, _sectorPos, 150] call BIS_fnc_taskDefend;
                _group setCombatMode "RED";
                _unit setUnitPos "UP";
                [format ["Building defender using vanilla aggressive behavior at ratio %1", _ratio], "DEBUG"] call KPLIB_fnc_log;
            };
        };
        
        // Only change tactics occasionally (wait 30 seconds before allowing another change)
        [_pfhHandle] call CBA_fnc_removePerFrameHandler;
        
        [{
            params ["_unit", "_sector", "_hasLAMBS", "_oldPfhHandle"];
            // Restart the main PFH after the delay
            [_unit, _sector] call building_defence_ai;
        }, [_unit, _sector, _hasLAMBS, _pfhHandle], 120] call CBA_fnc_waitAndExecute;
    };
}, 5, [_unit, _sector, _hasLAMBS]] call CBA_fnc_addPerFrameHandler;
