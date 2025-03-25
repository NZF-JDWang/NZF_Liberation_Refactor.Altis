/*
    Function: NZF_fnc_validateSectorCapture
    
    Description:
        Checks if a sector can be captured based on its proximity to friendly sectors
    
    Parameters:
        _sector - Sector object to validate
    
    Returns:
        Boolean - True if sector can be captured, false otherwise
    
    Author: [NZF] JD Wang
    Date: 2023-04-25
*/

params ["_sector"];

if (isNil "NZF_capturable_sectors") then {
    // Initialize capturable sectors if not already done
    [] call NZF_fnc_updateCapturableSectors;
};

// Return whether the sector is in the capturable sectors list
_sector in NZF_capturable_sectors 