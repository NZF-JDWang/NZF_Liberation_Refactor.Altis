/*
    Admin Commands for NZF Liberation
    
    These functions can be run from the debug console to fix issues or manipulate the game state
    
    Author: [NZF] JD Wang
    Date: 2024-11-08
*/

// List all admin commands
NZF_admin_help = {
    private _msg = "Available admin commands:
1. call NZF_admin_help - Show this help message";
    
    _msg remoteExec ["systemChat", remoteExecutedOwner];
    
    true
}; 