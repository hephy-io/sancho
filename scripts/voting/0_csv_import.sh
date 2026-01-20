# Import data from .csv to goverance.list ready for use in the vote scripts
# Useful during times of high load such as in the event of another omnibus budget cycle
# Based on a .csv table formatted as ACTION_NAME ACTION_ID ROLE VOTE METADATA_FILE

awk -F',' 'NR > 1 {print $2, $3, $4, $5}' voting.csv > governance.list
