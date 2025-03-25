/*
    Function: attack_in_progress_fob
    
    Description:
        Handles an enemy attack on a FOB, including spawn of defenders, capturing or destruction.
    
    Parameters:
        _thispos - Position of the FOB being attacked
    
    Returns:
        Nothing
    
    Examples:
        (begin example)
        [_fobPosition] spawn attack_in_progress_fob;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2023-10-15
*/

params ["_thispos"];

// Initialize the attack by checking sector ownership after a delay
[
    {
        params ["_thispos"];
        private _ownership = [_thispos] call KPLIB_fnc_getSectorOwnership;
        
        if (_ownership != GRLIB_side_enemy) exitWith {
            ["FOB attack cancelled - sector no longer controlled by enemy", "ATTACK"] call KPLIB_fnc_log;
        };
        
        // Continue to defender spawn phase
        [_thispos] call KPLIB_fnc_fobAttackSpawnDefenders;
    },
    [_thispos],
    5
] call CBA_fnc_waitAndExecute;

/*
    Function: KPLIB_fnc_fobAttackSpawnDefenders
    
    Description:
        Spawns friendly defenders if GRLIB_blufor_defenders is enabled
    
    Parameters:
        _thispos - Position of the FOB being attacked
    
    Returns:
        Nothing
*/
KPLIB_fnc_fobAttackSpawnDefenders = {
    params ["_thispos"];
    private ["_grp"];
    
    if (GRLIB_blufor_defenders) then {
        _grp = creategroup [GRLIB_side_friendly, true];
        {
            [_x, _thispos, _grp] call KPLIB_fnc_createManagedUnit;
        } foreach blufor_squad_inf;
        
        [
            {
                params ["_grp"];
                _grp setBehaviour "COMBAT";
                
                // Store group in namespace for later cleanup
                if (isNil "KPLIB_fobAttackGroups") then {
                    KPLIB_fobAttackGroups = [];
                };
                KPLIB_fobAttackGroups pushBack _grp;
            },
            [_grp],
            3
        ] call CBA_fnc_waitAndExecute;
    };
    
    // Continue to attack phase
    [
        {
            params ["_thispos"];
            [_thispos] call KPLIB_fnc_fobAttackStartPhase;
        },
        [_thispos],
        60
    ] call CBA_fnc_waitAndExecute;
};

/*
    Function: KPLIB_fnc_fobAttackStartPhase
    
    Description:
        Starts the attack phase, adding the position to sectors under attack
    
    Parameters:
        _thispos - Position of the FOB being attacked
    
    Returns:
        Nothing
*/
KPLIB_fnc_fobAttackStartPhase = {
    params ["_thispos"];
    
    // Add to sectors under attack
    KPLIB_sectorsUnderAttack pushBack _thispos;
    publicVariable "KPLIB_sectorsUnderAttack";
    
    private _ownership = [_thispos] call KPLIB_fnc_getSectorOwnership;
    if (_ownership == GRLIB_side_friendly) exitWith {
        // FOB already recaptured, cleanup and exit
        [_thispos] call KPLIB_fnc_fobAttackCleanup;
    };
    
    // Start the attack countdown
    [_thispos, 1] remoteExec ["remote_call_fob"];
    [_thispos, GRLIB_vulnerability_timer] call KPLIB_fnc_fobAttackCountdown;
};

/*
    Function: KPLIB_fnc_fobAttackCountdown
    
    Description:
        Manages the attack countdown and checks sector ownership
    
    Parameters:
        _thispos - Position of the FOB being attacked
        _attacktime - Time remaining for the attack
    
    Returns:
        Nothing
*/
KPLIB_fnc_fobAttackCountdown = {
    params ["_thispos", "_attacktime"];
    
    private _ownership = [_thispos] call KPLIB_fnc_getSectorOwnership;
    
    // If sector is friendly, end the attack
    if (_ownership == GRLIB_side_friendly) exitWith {
        [_thispos] call KPLIB_fnc_fobAttackCleanup;
    };
    
    // If timer expired and still enemy controlled, destroy FOB
    if (_attacktime <= 1 && (_ownership == GRLIB_side_enemy || _ownership == GRLIB_side_resistance)) exitWith {
        // Wait until sector is not resistance-controlled before resolving
        [
            {
                params ["_thispos"];
                [_thispos] call KPLIB_fnc_getSectorOwnership != GRLIB_side_resistance
            },
            {
                params ["_thispos"];
                [_thispos] call KPLIB_fnc_fobAttackResolve;
            },
            [_thispos]
        ] call CBA_fnc_waitUntilAndExecute;
    };
    
    // Decrement timer and continue countdown
    [
        {
            params ["_thispos", "_attacktime"];
            [_thispos, _attacktime - 1] call KPLIB_fnc_fobAttackCountdown;
        },
        [_thispos, _attacktime],
        1
    ] call CBA_fnc_waitAndExecute;
};

/*
    Function: KPLIB_fnc_fobAttackResolve
    
    Description:
        Resolves the FOB attack based on sector ownership
    
    Parameters:
        _thispos - Position of the FOB being attacked
    
    Returns:
        Nothing
*/
KPLIB_fnc_fobAttackResolve = {
    params ["_thispos"];
    
    if (GRLIB_endgame != 0) exitWith {
        [_thispos] call KPLIB_fnc_fobAttackCleanup;
    };
    
    private _ownership = [_thispos] call KPLIB_fnc_getSectorOwnership;
    
    // FOB destroyed
    if (_ownership == GRLIB_side_enemy) then {
        [_thispos, 2] remoteExec ["remote_call_fob"];
        
        [
            {
                params ["_thispos"];
                GRLIB_all_fobs = GRLIB_all_fobs - [_thispos];
                publicVariable "GRLIB_all_fobs";
                reset_battlegroups_ai = true;
                [_thispos] call KPLIB_fnc_destroyFob;
                [] spawn KPLIB_fnc_doSave;
                stats_fobs_lost = stats_fobs_lost + 1;
            },
            [_thispos],
            3
        ] call CBA_fnc_waitAndExecute;
    } else {
        // FOB defended
        [_thispos, 3] remoteExec ["remote_call_fob"];
        
        // Process nearby enemy units as prisoners
        {
            [_x] spawn prisonner_ai;
        } foreach ((_thispos nearEntities ["Man", GRLIB_capture_size * 0.8]) select {side group _x == GRLIB_side_enemy});
    };
    
    [_thispos] call KPLIB_fnc_fobAttackCleanup;
};

/*
    Function: KPLIB_fnc_fobAttackCleanup
    
    Description:
        Cleans up after FOB attack is resolved
    
    Parameters:
        _thispos - Position of the FOB being attacked
    
    Returns:
        Nothing
*/
KPLIB_fnc_fobAttackCleanup = {
    params ["_thispos"];
    
    // Remove from sectors under attack
    KPLIB_sectorsUnderAttack = KPLIB_sectorsUnderAttack - [_thispos];
    publicVariable "KPLIB_sectorsUnderAttack";
    
    // Clean up defenders after a delay
    [
        {
            params ["_thispos"];
            
            if (GRLIB_blufor_defenders && {!isNil "KPLIB_fobAttackGroups"}) then {
                {
                    private _grp = _x;
                    {
                        if (alive _x) then { deleteVehicle _x };
                    } foreach units _grp;
                } foreach KPLIB_fobAttackGroups;
                KPLIB_fobAttackGroups = [];
            };
        },
        [_thispos],
        60
    ] call CBA_fnc_waitAndExecute;
};
