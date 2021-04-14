function MAIN_maintain_database()
%% function to maintain RC+S database in dropbox 
% this function moves files from sycned to unsycned folders 
% and maintains a constantly updated database 

%% move files from synced to unsycned folders 
move_and_delete_folders();
move_and_delete_folders(); % second call is to delete folders that are empty 

%% new way to matinain a database - replaces previous functions - needs to completly replace it 
create_database_from_device_settings_files()

%% print reports using the new device settings file method 
print_report_from_device_settings_database_file_per_patient()

%% convert all .json files to .mat files
convert_all_files_from_mat_into_json();

%% plot some basic states 
plot_database_figures() 


end
