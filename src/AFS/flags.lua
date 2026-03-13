--[[
===== memory management =====

':' = write in buffer
'@' = pass to function
'=.' = point to

===== buffers =====
STDOUT
STDERR
NULL
VOID

===== buffer management =====
F@"FileName"  -- create a new buffer
f@"FileName"  -- load a buffer from the user file system
-- now "FileName" if a global buffer just like STDOUT or STDERR

FileName=.VOID -- destroy buffer (make the reference point to VOID)

-- save buffer exemple
SAVE@"FileName"

-- save multiples buffer
SAVE@"FileName"@"AnotherBuffer"@"Buffer64"

===== built-in functions ===== 
E -- error system (when the function is called, it writes the contents of a message to a buffer)
W -- warn system (when the function is called, it writes the contents of a message to a buffer)
N -- notification system (when the function is called, it writes the contents of a message to a buffer)

SAVE -- save system (saves any buffer to a file when the main program end or crash. It will not save if Lua raises a error, only if the program call the save function)

--NO-NULL -- any flag that becomes NULL raises a error


F@"FileName"  -- create a new buffer
f@"FileName"  -- load a buffer from the user file system
-- now "FileName" if a global buffer just like STDOUT or STDERR

FileName=.VOID -- destroy buffer (make the reference point to VOID)

-- save buffer exemple
SAVE@"FileName"

When the user uses
E:STDERR, every time the built-in function E is called and it writes something to a buffer, the buffer it will write to will be STDERR.

F@"FileName", now "FileName" is a buffer that can be used.

W:"FileName", now all warnings go to "FileName".
F@"Big File Name"
BIGF=."Big File Name".

W:BIGF, now all warnings go to "Big File Name".

SAVE@BIGF saves the buffer as "Big File Name" in the user's file system.

NULL is only for pointers.

"TEST=." Now TEST points to NULL, so it ceases to exist.

If the object it was pointing to is also not being pointed to by anyone, then it ceases to exist and becomes NULL.

"TEST=.VOID" is only for buffers; it causes all the contents of the buffer to be discarded.

If there is an attempt to get something that does not exist, it returns NULL. TEST=.VARIABLE_THAT_DOES_NOT_EXIST -- TEST is NULL.

All flags are executed before the program starts.
The program only sees the built-in functions and flags defined in the command.

TEST=.STDOUT -- the TEST flag is visible to the program; if the program tries to get the TEST flag, it ends up receiving STDOUT.

Custom flags are declared with a '-' at the beginning: `-my_flag`

Internally, the flag is true:

`-my_flag@this is a test@"`

`my_flag` now has a value assigned.

Custom flags are only visible to the main program.

]]

local FLAGS = {

}
