# migrate_from_winbind_to_sssd

#!/bin/bash
#set -x
#trap read debug

 Subject:  Moderate Client: ALSC Description: Servers joined with Winbind - Not joined
 
 Problem is that we’re maintaining the uid incorrect mapping. 
 Delete home directory folders may help for standalone users, but not for existing applications.
 
 Only option that comes to my mind is to track any uuid that exist previous to the migration. 
 For example, track each owner and uid for each file
 
 User | UUID
 UserA;100010101
 UserB;100010012
 
 After track this do a find for any file with that UUID, and change to user string A.
 
 Regards,
 
 ________________________________________________________________
 Somebody

