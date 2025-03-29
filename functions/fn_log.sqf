/*
    File: fn_log.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2020-04-16
    Last Update: 2020-04-20
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Logs given string to the rpt of the machine while adding KP Liberation prefix.

    Parameter(s):
        _text   - Text to write into log or format array [STRING or ARRAY, defaults to ""]
        _tag    - Tag to display between KPLIB prefix and text  [STRING, defaults to "INFO"]

    Returns:
        Function reached the end [BOOL]
*/

// Safety check - if the first parameter is an array but not a format array, it might be misused calling params
if (_this isEqualType [] && {count _this > 0} && {_this select 0 isEqualType []}) then {
    // Try to handle incorrect call with just one array argument
    private _msg = "ERROR: Incorrect parameters passed to fn_log. Check your calls to this function.";
    diag_log _msg;
    diag_log format ["DEBUG: Parameters received: %1", _this];
    // Try to extract something meaningful to log
    if (count _this > 0) then {
        private _firstParam = _this select 0;
        if (_firstParam isEqualType [] && {count _firstParam > 0}) then {
            if (_firstParam select 0 isEqualType "" || _firstParam select 0 isEqualType []) then {
                _this = _firstParam;
            };
        };
    };
};

params [
    ["_text", "", ["", []]],
    ["_tag", "INFO", [""]]
];

// Handle format arrays
private _formattedText = if (_text isEqualType []) then {
    format _text
} else {
    _text
};

if (_formattedText isEqualTo "" || _tag isEqualTo "") exitWith {["Empty string given"] call BIS_fnc_error; false};

private _msg = text ([
    "[KPLIB] [",
    _tag,
    "] ",
    _formattedText
] joinString "");

diag_log _msg;

true
