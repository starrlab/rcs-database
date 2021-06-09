#!/usr/bin/env bash
cd /Applications/MATLAB_R2019a.app/bin
pwd
echo $$
./matlab -nodisplay -nodesktop -logfile "/Users/roee/Starr Lab Dropbox/RC+S Patient Un-Synced Data/database/logs/logfile.log" -batch "run /Users/roee/Documents/Code/rcsanalysis/matlab/move_and_delete_folders.m"
./matlab -nodisplay -nodesktop -logfile "/Users/roee/Starr Lab Dropbox/RC+S Patient Un-Synced Data/database/logs/logfile.log" -batch "run /Users/roee/Documents/Code/rcsanalysis/matlab/move_and_delete_folders.m"
# print report log 
./matlab -nodisplay -nodesktop -logfile "/Users/roee/Starr Lab Dropbox/RC+S Patient Un-Synced Data/database/logs/database_log.log" -batch "run /Users/roee/Documents/Code/rcsanalysis/matlab/create_database_from_device_settings_files.m"

# print reports from device settings 
./matlab -nodisplay -nodesktop -logfile "/Users/roee/Starr Lab Dropbox/RC+S Patient Un-Synced Data/database/logs/report_log.log" -batch "run /Users/roee/Documents/Code/rcsanalysis/matlab/print_report_from_device_settings_database_file_per_patient.m"

# convert files to .mat 
./matlab -nodisplay -nodesktop -logfile "/Users/roee/Starr Lab Dropbox/RC+S Patient Un-Synced Data/database/logs/convert_to_mat_file_from_json.log" -batch "run /Users/roee/Documents/Code/rcsanalysis/matlab/convert_all_files_from_mat_into_json.m"

# chop up data in 10 min chunk 
./matlab -nodisplay -nodesktop -logfile "/Users/roee/Starr Lab Dropbox/RC+S Patient Un-Synced Data/database/logs/process_data_into_10_min_chunks.log" -batch "run /Users/roee/Documents/Code/rcsanalysis/matlab/process_data_into_10_minute_chunks.m"

# create recording report figures  
./matlab -nodisplay -nodesktop -logfile "/Users/roee/Starr Lab Dropbox/RC+S Patient Un-Synced Data/database/logs/figure_reports.log" -batch "run /Users/roee/Documents/Code/rcsanalysis/matlab/plot_database_figures.m"
