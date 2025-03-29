/*
    Function: KPLIB_fnc_updateMarkerAppearance
    
    Description:
        Updates a marker's appearance on the client side
    
    Parameters:
        _marker - Marker name
        _color - Color to set
        _alpha - Alpha value to set (optional, default 1)
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2024-11-06
*/

params ["_marker", "_color", ["_alpha", 1]];

// Exit if we're on the server without a UI
if (isDedicated) exitWith {};

// Update marker appearance locally
_marker setMarkerColorLocal _color;
_marker setMarkerAlphaLocal _alpha; 