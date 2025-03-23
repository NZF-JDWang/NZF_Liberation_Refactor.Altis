/*
    Function: KPLIB_fnc_readinessIncrease
    
    Description:
        Handles combat readiness level changes over time based on sector control.
        Uses non-blocking CBA functions instead of scheduled execution.
    
    Parameters:
        None
    
    Returns:
        None
    
    Examples:
        (begin example)
        [] call KPLIB_fnc_readinessIncrease;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-30
*/

// Wait until the save is loaded
[{
    !isNil "save_is_loaded" && {save_is_loaded}
},
{
    // Start the periodic readiness update
    [{
        // Check if players control almost all sectors
        if ((count blufor_sectors) >= ((count sectors_allSectors) * 0.9)) then {
            // Decrease readiness when players dominate
            if (combat_readiness > 0) then {
                combat_readiness = combat_readiness - 0.25;
            };
        } else {
            // Increase readiness when players don't dominate
            if (
                (combat_readiness < ((count blufor_sectors) * 2) && combat_readiness < 35)
                || (combat_readiness < ((count blufor_sectors) * 1.25) && combat_readiness < 60)
            ) then {
                combat_readiness = combat_readiness + 0.25;
                stats_readiness_earned = stats_readiness_earned + 0.25;
            };
        };
        
        // Cap readiness based on difficulty
        if (combat_readiness > 100.0 && GRLIB_difficulty_modifier < 2) then {
            combat_readiness = 100.0;
        };
        
    }, 180 + (random 180), []] call CBA_fnc_addPerFrameHandler;
}, []] call CBA_fnc_waitUntilAndExecute; 