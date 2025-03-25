/*
    File: fn_potatoScan.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2019-12-03
    Last Update: 2019-12-07
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Returns the current Potato 01 object, which is the huron (heavy transport helicopter).
        Also known as SPARTAN 6.

    Parameter(s):
        NONE

    Returns:
        SPARTAN 6 [OBJECT]
*/

private _potatoes = vehicles select {typeof _x == huron_typename && alive _x};
if !(_potatoes isEqualTo []) then {
    _potatoes select 0
} else {
    objNull
};
