#!/usr/bin/bash

# -------------------------------------------------------
# 
# File: NPPES_data_fetching.sh
#
# Description: Automate Data fetching with a
# cron-job that fetches NPPES data every month
# and grabs the specific csv files.
#
#
# Developer: Randy Brown
# Developer Email: randybrown9812@gmail.com
# 
# Version 1.0
# Initialed Bash Script for this
#
# Version 1.1
# Add Early Exit if any commands comes with an error
# -------------------------------------------------------

# Perform early exit whenever any of the commands receive an error.
set -e

repository_directory=$(pwd && cd ..)
# Grab the current month and year for NPPES database
MONTH=$(date -d "$(date +%Y-%m-01) -1 month" +%B)
YEAR=$(date +%Y)

info_json_location="$repository_directory/info.json"

# Grab Database information
db_name=$(jq -r '.database' "$info_json_location")
db_username=$(jq -r '.user' "$info_json_location")
db_password=$(jq -r '.password' "$info_json_location")
db_host=$(jq -r '.host' "$info_json_location")
db_port=$(jq -r '.port' "$info_json_location")

# Validate the JSON works for making a connection
pytest "$repository_directory/tests/test_database.py::test_database_connection" || (echo "Database Connection Failed!" && exit 1)

#--> Grab NPPES data first
DATA_LINK="https://download.cms.gov/nppes/NPPES_Data_Dissemination_${MONTH}_${YEAR}_V2.zip"
DEST_ZIP="NPPES_Data_Dissemination_${MONTH}_${YEAR}_V2.zip"

mkdir -p Original_data

# Grab a link to use with curl from the data link site.
curl -o "$repository_directory/Original_data/$DEST_ZIP" "$DATA_LINK"

if [ -f "$repository_directory/Original_data/$DEST_ZIP" ]; then
    unzip "$repository_directory/Original_data/$DEST_ZIP" -d "$repository_directory/Original_data"
fi

if [ -f "$repository_directory/Original_data/$DEST_ZIP" ]; then
    rm "$repository_directory/Original_data/$DEST_ZIP"
fi

# Grab CSV names for each file
npi_csv_filepath=$(find "$repository_directory/Original_data" -type f | grep -E 'npidata_pfile_[0-9]{8}-[0-9]{8}\.csv')
endpoint_csv_filepath=$(find "$repository_directory/Original_data" -type f | grep -E 'endpoint_pfile_[0-9]{8}-[0-9]{8}\.csv')
othername_csv_filepath=$(find "$repository_directory/Original_data" -type f | grep -E 'othername_pfile_[0-9]{8}-[0-9]{8}\.csv')
pl_csv_filepath=$(find "$repository_directory/Original_data" -type f | grep -E 'pl_pfile_[0-9]{8}-[0-9]{8}\.csv')

# Verify all filepaths are found and contain only one path
for filepath in "$npi_csv_filepath" "$endpoint_csv_filepath" "$othername_csv_filepath" "$pl_csv_filepath"; do
    if [[ $filepath == *" "* ]]; then
        echo "Filepath: $filepath contains more than one csv path."
        exit 1
    elif [ ! -f "$filepath" ]; then
        echo "Filepath: $filepath cannot be located by this bash script"
        exit 1
    fi
done

# Load the schema file
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -f "$repository_directory/db/schema.sql"

# Gather CPU information for python files
BYTES_PER_ROW=4500

# Get available RAM in KB
AVAILABLE_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')

# Calculate chunk size (use 25% of available RAM)
CHUNK_SIZE=$(echo "($AVAILABLE_KB * 1024 * 0.25) / $BYTES_PER_ROW" | bc)

# Perform data cleaning for the 4 files
python "$repository_directory/lib/db_staging.py" -i "$npi_csv_filepath" -o "$repository_directory/Original_data/npidata_cleaned.csv" -c "$CHUNK_SIZE"
python "$repository_directory/lib/db_staging.py" -i "$pl_csv_filepath" -o "$repository_directory/Original_data/pl_cleaned.csv" -c "$CHUNK_SIZE"
python "$repository_directory/lib/db_staging.py" -i "$endpoint_csv_filepath" -o "$repository_directory/Original_data/endpoint_cleaned.csv" -c "$CHUNK_SIZE"
python "$repository_directory/lib/db_staging.py" -i "$othername_csv_filepath" -o "$repository_directory/Original_data/othername_cleaned.csv" -c "$CHUNK_SIZE"

# Perform COPY commands
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -c "\COPY STAGING_TABLE_ENDPOINTS FROM '$repository_directory/Original_data/endpoint_cleaned.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '\"')" &
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -c "\COPY STAGING_TABLE_NPI FROM '$repository_directory/Original_data/npidata_cleaned.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '\"')" &
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -c "\COPY STAGING_OTHERNAME_PFILE FROM '$repository_directory/Original_data/othername_cleaned.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '\"')" &

wait 

# Perform data loading
# Start with providers schema first since they load longer and is dependent for other tables
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -f "$repository_directory/db/providers/load_providers.sql"
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -c "\COPY provider_secondary_practice_location (npi, address_line1, address_line2, city_name, state_name, postal_code, country_code, telephone_number, telephone_extension, fax_number) FROM '$repository_directory/Original_data/pl_cleaned.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '\"')"

# Concurrently run other provider tables
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -f "$repository_directory/db/providers/load_providers_taxonomy.sql" &
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -f "$repository_directory/db/providers/load_providers_other_identifier.sql" &
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -f "$repository_directory/db/providers/load_providers_authorized_official.sql" &
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -f "$repository_directory/db/providers/load_providers_address_mailing.sql" &
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -f "$repository_directory/db/providers/load_providers_address_practice.sql" &

wait 

# Run others file as this deletes staging tables and takes a short time
psql "postgresql://$db_username:$db_password@$db_host:$db_port/$db_name" -f "$repository_directory/db/others/load_others.sql"

echo "NPPES_data_fetching.sh has been finished!"
