Database and initial dataflow functions for Starr Lab RC+S data 
==

Summary: 
-------------

This codebase comprises all code that is used in order to move RC+S data off patient computers, database data and search database. Note that this codebase is not currently using the most up to date "OpenMind" code to extract meta data from the data as well as extract the data itself. This is a "to do" element for this codebase.

#### Main functional elements: 

1. Move data: 
All RC+S data sits on a dropbox account owned by a lab "super user" (see passwords on Box). This lab "super user" should only be installed on one computer (admin) to prevent others from accidentally deleting our files (this has happened before if others know the password). If not caught on time the data will be lost. 

The lab dropbox account has a folder for each patient. This folder is synced to each patient computer (e.g. `RCS05` has a synced dropbox folder on their computer and all other patient folders are unsynched). On a periodic basis (depending on how code is deployed) data should be moved (with code) from the "synched" to "unsynced" data folders. This prevents all data recorded by the patient from "living" on patient computer and eventually running out of space (Surface Go patient computers do not have a lot of room). 

To summarize:

* All patient data is saved to a single dropbox folder on patient computer with patient code (e.g. `RCS05`). 
* The patient data is moved to unsycned folder periodically. 

2. Create database and reports 
A loop is created on meta data files (device settings) to extract basic params of data. 
This database is then used in order to create reports about data type (on/off stim for exampel, sense settings used, stim settings used etc.)


3. Data aggregation / database examples 
Sample code is provided to agregate and compared data across different conditions. 


#### Structure of code and main functions: 
This is the main function that can run (on periodic basis) and calls all subfunctions listed below: 

* `move_and_delete_folders` - Move data from all patient folders to patient data. Note that as new patients are added this must be adjusted in two locations (so new folders are searched): 

** Line `8` - add string of patient folder. E.g. `RCS15`... 

**`create_database_from_device_settings_files` This creates the database from device settings. As new patient are added, a meta data file needs to be added and saved here: 

* `save_device_id_master_table` - see examples of previous patient and follow the format. 

* `print_report_from_device_settings_database_file_per_patient` Prints reports and stats of patient settings. See example: 

* `convert_all_files_from_mat_into_json` - converts all .json files into .mat files. This uses the old codebase and needs to be converted to used new OpenMind code but I don't have room on the current database computer to do this for all data. 

* `plot_database_figures` - Plots some database figures. 

#### Database operations: 

The following code has examples of database operations: 

`MAIN_create_subsets_of_home_data_for_analysis`. 

Here is an example of a sample call: 

```
    % off stim 

    idxpat       = strcmp(dbUse.patient,'RCS02');
    idxside      = strcmp(dbUse.side,'L');
    idxsense     = strcmp(dbUse.chan1,'+2-0 lpf1-450Hz lpf2-1700Hz sr-250Hz');
    idxstim      = dbUse.stimulation_on == 0;
    idxTdIsStrm  = dbUse.timeDomainStreaming == 1;
    idxAccIsStrm = dbUse.accelerometryStreaming == 1;
    idxScbsUsed  = dbUse.recordedWithScbs == 1;
    
    idxconcat = idxpat & idxside & idxsense & idxstim & idxTdIsStrm & idxAccIsStrm & idxScbsUsed;
    patDBtoConcat = dbUse(idxconcat,:);
    sum(patDBtoConcat.duration)
```
This call is using logical indexing to find indexes in the database of patient `RCS02` on the `L` side, with these sense channel params on channel 1: `+2-0 lpf1-450Hz lpf2-1700Hz sr-250Hz`. In addition it is looking for data off stim, with time domain and acc strreaming and recorded with the patient facing application. It uses the database to creat a table with this data (in dropbox). Subsequent analysis require opening and looping on that data, and that is best done with current OpenMind code and not legacy code I have used. However, we are waiting on a new computer / computing setup to do this for all code. 

#### Running on schedule:

Currently, a '.sh' file is running on a mac and this runs a job every morning at 3am to move all files in dropbox from patient computer to the dropbox "unsynced" folder. It tuns through (almost) all functions in 'MAIN_maintain_database' described above, and each function is run via Matlab command line and is wrapped with error output for debugging. 
This is daemon is run with on a mac: 
https://www.soma-zone.com/LaunchControl/
It probably makes sense to run this with the task scheduler on windows and a '.cmd' file.
The sample (mac based '.sh') file is: 'runMoveDeleteFolders.sh'
