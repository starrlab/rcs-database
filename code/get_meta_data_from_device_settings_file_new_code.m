function metaData = get_meta_data_from_device_settings_file_new_code(deviceSettingsFn)
% this functions gets some meta data from a device settings file
% it depends on having other files that it will also attempt to open in the
% same directory as the device settings file

metaData = table();
% %% set default values
% metaData.deviceId{1}                    = 'NA';
% metaData.patient{1}                     = 'NA';
% metaData.side{1}                        = 'NA';
% metaData.area{1}                        = 'NA';
% metaData.diagnosis{1}                   = 'NA';
% metaData.timeStart(1)                   = NaT;
% metaData.timeStart.TimeZone             = 'America/Los_Angeles';
% metaData.timeEnd(1)                     = NaT;
% metaData.timeEnd.TimeZone               = 'America/Los_Angeles';
% metaData.duration(1)                    = seconds(0);
% metaData.senseSettings{1}               = struct();
% metaData.senseSettingsMultiple{1}       = struct();
% metaData.stimStatus{1}                  = struct();
% metaData.stimState{1}                   = struct();
% metaData.stimStateChanges{1}            = struct();
% metaData.fftTable{1}                    = struct();
% metaData.powerTable{1}                  = struct();
% metaData.adaptiveSettings{1}            = struct();
% metaData.detectionStreaming(1)          = NaN;
% metaData.powerStreaming(1)              = NaN;
% metaData.fftStreaming(1)                = NaN;
% metaData.timeDomainStreaming(1)         = NaN;
% metaData.accelerometryStreaming(1)      = NaN;
% metaData.deviceSettingsFn{1}            = deviceSettingsFn;
% 
% metaData.session{1}                     = 'NA';
% metaData.recordedWithScbs(1)            = NaN;
% metaData.recordedWithResearchApp(1)     = NaN;
% 
% 
% % create some more defaultvariables (that are contained within variables above):
% % these are commonly used for sorting / indexing into database
% metaData.chan1{1}                       = 'NA';
% metaData.chan2{1}                       = 'NA';
% metaData.chan3{1}                       = 'NA';
% metaData.chan4{1}                       = 'NA';
% 
% metaData.stimulation_on(1)              = NaN;
% metaData.electrodes{1}                  = 'NA';
% metaData.amplitude_mA(1)                = NaN;
% metaData.rate_Hz(1)                     = NaN;
% 

% get session name
idxSession = strfind(lower(deviceSettingsFn),'session');
metaData.session{1}                     = deviceSettingsFn( idxSession: idxSession + 19);
% find out if recorded with SCBS or clinician application
if any(strfind(deviceSettingsFn,'SummitContinuousBilateralStreaming'));
    metaData.recordedWithScbs(1)            = 1;
    metaData.recordedWithResearchApp(1)     = 0;
else
    metaData.recordedWithScbs(1)            = 0;
    metaData.recordedWithResearchApp(1)     = 1;
end


%% attempt to get actual values
% get the dirname to load other files that have meta data
[dirname,~] = fileparts(deviceSettingsFn);

% more advances meta data
try
    % load device settings
%     DeviceSettings = jsondecode(fixMalformedJson(fileread(deviceSettingsFn),'DeviceSettings'));
%     % fix issues with device settings sometiems being a cell array and
%     % sometimes not
%     
%     if isstruct(DeviceSettings)
%         DeviceSettings = {DeviceSettings};
%     end
%     
%     % load device settings from the first structure of device settings
%     [senseSettings,stimState,stimStatus,fftTable,powerTable,adaptiveSettings,senseSettingsMultiple,stimStateChanges]  = ...
%         loadDeviceSettingsFromFirstInitialStructure(DeviceSettings);
%     metaData.senseSettings{1}               = senseSettings;
%     metaData.senseSettingsMultiple{1}       = senseSettingsMultiple;
%     metaData.stimStatus{1}                  = stimStatus;
%     metaData.stimState{1}                   = stimState;
%     metaData.stimStateChanges{1}            = stimStateChanges;
%     metaData.fftTable{1}                    = fftTable;
%     metaData.powerTable{1}                  = powerTable;
%     metaData.adaptiveSettings{1}            = adaptiveSettings;
%     
%     
    
    
    
    
    DeviceSettings_fileToLoad = deviceSettingsFn;
    [folderPath ,] = fileparts(deviceSettingsFn);
    if isfile(DeviceSettings_fileToLoad)
        [timeDomainSettings, powerSettings, fftSettings, metaDataIn] = createDeviceSettingsTable(folderPath);
        timeDomainSettings = convertTableToDateTime(timeDomainSettings,metaDataIn);
        powerSettings      = convertTableToDateTime(powerSettings,metaDataIn);
        fftSettings        = convertTableToDateTime(fftSettings,metaDataIn);
        metaData.timeDomainSettings{1} = timeDomainSettings;
        metaData.powerSettings{1} = powerSettings;
        metaData.fftSettings{1} = fftSettings;
        
        
    else
        warning('No DeviceSettings.json file')
    end
    
    
    % get basic meta data
    try
        %     masterDataId                            = get_device_id_return_meta_data(deviceSettingsFn);
        metaData.deviceId{1}                    = 'NA';
        if length(metaDataIn.subjectID) == 6  % after RCS01 evey patient names RCS02L etc. 
            metaDataIn.subjectID = metaDataIn.subjectID(1:end-1);
        end
        metaData.patient{1}                     = metaDataIn.subjectID;
        metaData.patientGender{1}                     = metaDataIn.patientGender;
        leads = metaDataIn.leadLocations(~cellfun(@(x) strcmp(x,'Undefined'), metaDataIn.leadLocations));
        metaData.side{1}                        = unique( [ leads{1}(1)  leads{2}(1)]); % for cases in which same rC+S both sides 
        leadsTargets = metaDataIn.leadTargets(~cellfun(@(x) strcmp(x,' '), metaDataIn.leadTargets));
        metaData.area{1}                        = sprintf('%s ',leadsTargets{:});
        metaData.diagnosis{1}                   = metaDataIn.Diagnosis;
        
%         metaTime = get_time_domain_file_duration(fn);
        
%         metaData.timeStart(1)                   = masterDataId.timeStart(1);
%         metaData.timeEnd(1)                     = masterDataId.timeEnd(1);
%         metaData.duration(1)                    = masterDataId.duration(1);
    catch
    end
    
    


    %%
    % Stimulation settings
    disp('Collecting Stimulation Settings from Device Settings file')
    if isfile(DeviceSettings_fileToLoad)
        [stimSettingsOut, stimMetaData] = createStimSettingsFromDeviceSettings(folderPath);
        if ~isempty(stimSettingsOut)
            stimSettingsOut.HostUnixTime = convertTimeToDateTime(stimSettingsOut.HostUnixTime,metaDataIn);
        end
        metaData.stimSettingsOut{1} = stimSettingsOut;
        metaData.stimMetaData{1} = stimMetaData;
    else
        warning('No DeviceSettings.json file - could not extract stimulation settings')
    end
    
    disp('Collecting Stimulation Settings from Stim Log file')
    StimLog_fileToLoad = [folderPath filesep 'StimLog.json'];
    if isfile(StimLog_fileToLoad)
        [stimLogSettings] = createStimSettingsTable(folderPath,stimMetaData);
        stimLogSettings.HostUnixTime = convertTimeToDateTime(stimLogSettings.HostUnixTime,metaDataIn);
        metaData.stimLogSettings{1} = stimLogSettings;

    else
        warning('No StimLog.json file')
    end
    %%
    % Adaptive Settings
    disp('Collecting Adaptive Settings from Device Settings file')
    if isfile(DeviceSettings_fileToLoad)
            [DetectorSettings,AdaptiveStimSettings,AdaptiveEmbeddedRuns_StimSettings] = createAdaptiveSettingsfromDeviceSettings(folderPath);
            if ~isempty(DetectorSettings)
                DetectorSettings.HostUnixTime = convertTimeToDateTime(DetectorSettings.HostUnixTime,metaDataIn);
            end
            if ~isempty(AdaptiveStimSettings)
            AdaptiveStimSettings.HostUnixTime = convertTimeToDateTime(AdaptiveStimSettings.HostUnixTime,metaDataIn);
            end
            if ~isempty(AdaptiveEmbeddedRuns_StimSettings)
            AdaptiveEmbeddedRuns_StimSettings.HostUnixTime = convertTimeToDateTime(AdaptiveEmbeddedRuns_StimSettings.HostUnixTime,metaDataIn);
            end

        metaData.DetectorSettings{1} = DetectorSettings;
        metaData.AdaptiveStimSettings{1} = AdaptiveStimSettings;
        metaData.AdaptiveEmbeddedRuns_StimSettings{1} = AdaptiveEmbeddedRuns_StimSettings;
    else
        warning('No DeviceSettings.json file - could not extract detector and adaptive stimulation settings')
    end
    %%
    % Event Log
    disp('Collecting Event Information from Event Log file')
    EventLog_fileToLoad = [folderPath filesep 'EventLog.json'];
    if isfile(EventLog_fileToLoad)
        [eventLogTable] = createEventLogTable(folderPath);
        eventLogTable.HostUnixTime = convertTimeToDateTime(eventLogTable.HostUnixTime,metaDataIn);
        metaData.eventLogTable{1} = eventLogTable;
    else
        warning('No EventLog.json file')
    end
    

    
    % get some inital values for database within sense settings:
        metaData.chan1{1} = timeDomainSettings.chan1{end};
        metaData.chan2{1} = timeDomainSettings.chan2{end};
        metaData.chan3{1} = timeDomainSettings.chan3{end};
        metaData.chan4{1} = timeDomainSettings.chan4{end};
    
    % get some initail values for database within stim settings
    if istable(stimLogSettings)
        metaData.stimulation_on(1)  = stimLogSettings.therapyStatus(end);
        metaData.numStimSettings(1) = size(stimLogSettings,1);
        rawStim = strsplit(stimLogSettings.stimParams_prog1{end},',');
        
        metaData.group{1}           = stimLogSettings.activeGroup{end};
        metaData.electrodes{1}      = rawStim{1};
        metaData.amplitude_mA(1)    = str2num(strrep(rawStim{2},'mA',''));
        metaData.rate_Hz(1)         = str2num(strrep(rawStim{4},'Hz',''));
        metaData.fullSettings{1}    = stimLogSettings.stimParams_prog1{1};
    end
    
    % get some embedded details 
    metaData.EmbeddedMode{1} = AdaptiveEmbeddedRuns_StimSettings.adaptiveMode{end};
    % loop on states and get amp for each state 
    statesStr = AdaptiveEmbeddedRuns_StimSettings.states;
    states = 0:1:8;
    cnt = 1;
    for ss = 1:length(states)
        fnuse = sprintf('state%d_isValid',states(ss));
        if statesStr.(fnuse)
            fnuse = sprintf('state%d_AmpInMilliamps',states(ss));
            targetCurrRaw = statesStr.(fnuse)(1); % assumes one programs 
            if targetCurrRaw ~=-1
                targetCur(cnt) = targetCurrRaw;
                cnt = cnt + 1;
            end
        end
    end
    
    metaData.TargetCurrentAdaptive{1} = unique(targetCur);
    
    
    % for each subsequent structure, need to write code that will estimate
    % all settings changes within the file and update the total time for
    % each settings
    %     getSenseSettingsInDeviceSettingsStructure(DeviceSettings,metaData.senseSettings{1});
catch
end

% check if files have data in them by opening
% each text file and looking for a unix time stamp at the start
% and at the end of the files
fileNamesCheck = {'AdaptiveLog','RawDataTD','RawDataPower','RawDataFFT','RawDataAccel'};
fileNamesTable = {'detectionStreaming','timeDomainStreaming','powerStreaming','fftStreaming','accelerometryStreaming'};
for fn = 1:length(fileNamesCheck)
    try
        % first set defaul value
        fnUse = sprintf('%s.json',fileNamesCheck{fn});
        fnCheck = fullfile(dirname,fnUse);
        timeReport = report_start_end_time_td_file_rcs(fnCheck);
        if timeReport.duration > seconds(0)
            metaData.(fileNamesTable{fn})(1)       = 1;
        else
            metaData.(fileNamesTable{fn})(1)       = 0;
        end
        if strcmp(fileNamesCheck{fn},'RawDataTD') % default value for time domain duration
            metaData.duration(1)            = timeReport.duration;
            metaData.timeStart(1)           = timeReport.startTime;
            metaData.timeEnd(1)             = timeReport.endTime;            
        end

    catch
    end
end
metaData.deviceSettingsFn{1} = deviceSettingsFn;
end



function  meta = get_time_domain_file_duration(fn)
%% this function takes a device settings.json file
%% and returns device ID and other meta data about the recording
warning('off','MATLAB:table:RowsAddedExistingVars');
dirSave = '/Users/roee/Starr Lab Dropbox/RC+S Patient Un-Synced Data/database';
load(fullfile(dirSave, 'deviceIdMasterList.mat'),'masterTable');

tic
fid = fopen(fn);
fseek(fid, 0, 'bof');
text = fread(fid, 500,'uint8=>char')';
fileIsEmpty = 0; % assume that file is not empty until proven otherwise
% check that this file is not empty
if length(text)<200 %  this is an empty time domain file
    fileIsEmpty = 1;
end
meta = table();
if ~fileIsEmpty
    
    % get device ID:
    deviceIdRaw = regexp(text,'(?<=,"DeviceId":")[a-zA-Z_0-9]+','match');
    meta.deviceID{1} = deviceIdRaw{1};
    
%     meta = get_patient_side_from_device_id(deviceID{1},masterTable);
    
    % get start time
    rawtime = regexp(text,'(?<=,"HostUnixTime":)[0-9]+','match');
    timenum = str2num(rawtime{1});
    meta.timeStart(1) = datetime(timenum/1000,'ConvertFrom','posixTime','TimeZone','America/Los_Angeles','Format','dd-MMM-yyyy HH:mm:ss.SSS');
    
    
    % now go to end of the file
    fseek(fid, -10000, 'eof');
    filesize = ftell(fid);
    text = fread(fid, 10000,'uint8=>char')';
    rawtime = regexp(text,'(?<=,"HostUnixTime":)[0-9]+','match');
    if ~isempty(rawtime) % can use text based methods (no json structure needed to get time end
        timenum = str2num(rawtime{1});
        meta.timeEnd(1) = datetime(timenum/1000,'ConvertFrom','posixTime','TimeZone','America/Los_Angeles','Format','dd-MMM-yyyy HH:mm:ss.SSS');
    else % need to try and open json file
        DeviceScrettings = jsondecode(fixMalformedJson(fileread(fn),'DeviceSettings'));
        % fix issues with device settings sometiems being a cell array and
        % sometimes not
        
        if isstruct(DeviceSettings)
            DeviceSettings = {DeviceSettings};
            timenum = DeviceSettings{end}.RecordInfo.HostUnixTime;
            meta.timeEnd(1) = datetime(timenum/1000,'ConvertFrom','posixTime','TimeZone','America/Los_Angeles','Format','dd-MMM-yyyy HH:mm:ss.SSS');
        end
    end
    meta.duration(1) = meta.timeEnd - meta.timeStart;

else
    
    meta.deviceID{1} = '';
    meta.timeStart(1) = NaT;
    meta.timeEnd(1) = NaT;
    meta.duration(1) = seconds(0);
    
end

fclose(fid);


end

function metaResults = get_patient_side_from_device_id(deviceId,masterTable)
idxuse = cellfun(@(x) any(strfind(x,lower(deviceId))), masterTable.deviceId);
if sum(idxuse) > 1
    error('more than one match found in master table')
else
    metaResults = masterTable(idxuse,:);
end
end

function tableIn = convertTableToDateTime(tableIn,metaData)
tableIn.timeStart = convertTimeToDateTime(tableIn.timeStart,metaData);
tableIn.timeStop = convertTimeToDateTime(tableIn.timeStop,metaData);
tableIn.duration = tableIn.timeStop - tableIn.timeStart;
end

function timeOut = convertTimeToDateTime(time,metaData)
timeFormat = sprintf('%+03.0f:00',metaData.UTCoffset);
timeOut = datetime(time./1000,'ConvertFrom','posixTime','TimeZone',timeFormat,'Format','dd-MMM-yyyy HH:mm:ss.SSS');
end