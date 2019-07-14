# misc_scripts
- drive checker uses the lsi.sh script created for MegaRAID to check if megaraid exists and then print any errors from the system 

- internal_backups.sh is just that, a script created to go around to all internal installs (racktables,icinga,observium, librenms) and rsyncs the files to a central location to be pushed to tape. The script uses parallel to copy from multiple locaitons at once. 
