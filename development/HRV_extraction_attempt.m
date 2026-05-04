clear; clc; close all;
didPlotQC = false;
%% ================= USER SETTINGS =================
performanceMinutes = 80;
performanceSeconds = performanceMinutes * 60;
fsTarget = 1;                % 1 Hz resample
minHR = 40;                  % bpm
maxHR = 130;                 % bpm
minValidPoints = 120;        % minimum valid HR samples
minParticipants = 15;        % for mean ± SD
% ==================================================
% HRV settings
fsDefault = 25;          % most WRT files are 25 Hz; we'll estimate too
hrvWin = 60;             % seconds (time-domain HRV)
minBeatsInWin = 20;      % minimum beats required per window
maxBadProp = 0.2;        % if too many NaNs in a window, skip

%% ================= IMPORT CSV FILES =================
dataFolder = "C:\Users\katyl\OneDrive - City, University of London\year 3\individual project\PPG_data";
files = dir(fullfile(dataFolder, "*.csv"));

if isempty(files)
    error('No WRT_*.csv files found. Place this script in the same folder as the CSV files.');
end

fprintf('Found %d CSV files\n', numel(files));

%% ================= PROCESS EACH FILE =================
HRM_all = {};
T_all = {};
RMSSD_all = {};
SDNN_all  = {};
skipped = 0;

for k = 1:numel(files)

    fname = fullfile(files(k).folder, files(k).name);   % ✅ full path always
    fprintf('Processing (%d/%d): %s\n', k, numel(files), files(k).name);

    % -------- IMPORT CSV --------
    try
        raw = readcell(fname);
    catch ME
        warning('Skipping %s (cannot read file): %s', files(k).name, ME.message);
        skipped = skipped + 1;
        continue;
    end

    if size(raw,2) < 3
        warning('Skipping %s (less than 3 columns)', files(k).name);
        skipped = skipped + 1;
        continue;
    end

    % Optional: quick column debug for the FIRST file only
    if k == 1
        disp(raw(1:10, 1:min(8,size(raw,2))));
        for c = 1:min(8,size(raw,2))
            x = cellfun(@toScalar, raw(2:end,c));
            if any(~isnan(x))
                fprintf('Col %d: min=%g max=%g\n', c, min(x,[],'omitnan'), max(x,[],'omitnan'));
            end
        end
    end

    % Columns: 1=UTC, 2=DATA (PPG), 3=HRM
    utc  = cellfun(@toScalar, raw(:,1));
    data = cellfun(@toScalar, raw(:,2));
    hrm  = cellfun(@toScalar, raw(:,3));

    % Remove header row if present
    if ~isempty(utc) && isnan(utc(1))
        utc(1)  = [];
        data(1) = [];
        hrm(1)  = [];
    end

    if numel(utc) < 10
        warning('Skipping %s (too few rows)', files(k).name);
        skipped = skipped + 1;
        continue;
    end

    % -------- FORWARD-FILL UTC --------
    for i = 2:numel(utc)
        if isnan(utc(i))
            utc(i) = utc(i-1);
        end
    end

    t_allRows = utc - utc(1);

    % -------- HRM SERIES --------
    validHR = ~isnan(t_allRows) & ~isnan(hrm) & hrm>=minHR & hrm<=maxHR;
    t_hr = t_allRows(validHR);
    hrmV = hrm(validHR);

    keepHR = t_hr >= 0 & t_hr <= performanceSeconds;
    t_hr = t_hr(keepHR);
    hrmV = hrmV(keepHR);

    if numel(t_hr) < minValidPoints
        warning('Skipping %s (not enough HRM data in 0–80 min)', files(k).name);
        skipped = skipped + 1;
        continue;
    end

    [tUnique, ia] = unique(t_hr,'stable');
    hrmUnique = hrmV(ia);

    % ✅ lock participant index so HR and HRV arrays stay aligned
    p = numel(HRM_all) + 1;
    T_all{p}   = tUnique;
    HRM_all{p} = hrmUnique;

    % -------- PPG WAVEFORM SERIES (for HRV) --------
    validPPG = ~isnan(t_allRows) & ~isnan(data);
    utc_ppg = utc(validPPG);
    ppg = data(validPPG);

    keepPPG = (utc_ppg - utc(1)) >= 0 & (utc_ppg - utc(1)) <= performanceSeconds;
    utc_ppg = utc_ppg(keepPPG);
    ppg = ppg(keepPPG);

    if numel(ppg) < 1000
        warning('No usable PPG waveform in %s -> HRV empty', files(k).name);
        RMSSD_all{p} = nan(performanceSeconds+1,1);
        SDNN_all{p}  = nan(performanceSeconds+1,1);
        continue;
    end

    % Estimate fs
    [uS,~,g] = unique(utc_ppg);
    counts = accumarray(g,1);
    fsEst = mode(counts);
    if isempty(fsEst) || fsEst < 5 || fsEst > 200
        fsEst = fsDefault;
    end

    % Build high-res time
    idxWithin = nan(size(utc_ppg));
    for s = 1:numel(uS)
        ii = find(utc_ppg == uS(s));
        idxWithin(ii) = (0:numel(ii)-1).';
    end
    t_ppg = (utc_ppg - utc_ppg(1)) + idxWithin./fsEst;

    % -------- Beat detection -> IBI -> HRV --------
    try
        [~, IBI, IBIt] = ppg_to_ibi(ppg, fsEst, t_ppg(1));
        IBI = clean_ibi(IBI);

        tCommon = (0:performanceSeconds)';
        [RMSSD_all{p}, SDNN_all{p}] = ibi_to_hrv_1Hz(IBI, IBIt, tCommon, hrvWin, minBeatsInWin, maxBadProp);

    catch ME
        warning('HRV failed for %s: %s', files(k).name, ME.message);
        RMSSD_all{p} = nan(performanceSeconds+1,1);
        SDNN_all{p}  = nan(performanceSeconds+1,1);
    end
end
fprintf('Loaded %d participants (HR), skipped %d files\n', numel(HRM_all), skipped);


%% ==================================================
function [beatTimes, IBI, IBIt, usedInversion] = ppg_to_ibi(ppg, fs, t0)
if nargin < 3, t0 = 0; end

% Bandpass PPG pulse band
bp = designfilt('bandpassiir','FilterOrder',4, ...
    'HalfPowerFrequency1',0.7,'HalfPowerFrequency2',4.0, ...
    'SampleRate',fs);
x = filtfilt(bp, double(ppg));

% Normalize
x = x - median(x);
sx = mad(x,1);
if sx == 0, sx = std(x); end
if sx == 0, sx = 1; end
x = x / sx;

minPeakDist = round(0.35 * fs);   % ~171 bpm max
minProm = 0.4;                    % good start for your amplitude range

% Try normal peaks
[~, locs] = findpeaks(x, 'MinPeakDistance', minPeakDist, 'MinPeakProminence', minProm);
usedInversion = false;

% If too few beats, try inverted (troughs)
dur_s = numel(ppg)/fs;
expectedMinBeats = max(10, floor(dur_s * 0.5));  % at least ~30 bpm equivalent
if numel(locs) < expectedMinBeats
    [~, locs2] = findpeaks(-x, 'MinPeakDistance', minPeakDist, 'MinPeakProminence', minProm);
    if numel(locs2) > numel(locs)
        locs = locs2;
        usedInversion = true;
    end
end

beatTimes = t0 + (locs(:)-1)/fs;
IBI  = diff(beatTimes);
IBIt = beatTimes(2:end);
end
%% ==================================================
function IBI2 = clean_ibi(IBI)

IBI2 = IBI;

% Physiological bounds
IBI2(IBI2 < 0.3 | IBI2 > 2.0) = NaN;

% Outlier vs moving median (beats)
med = movmedian(IBI2, 11, 'omitnan');
relDev = abs(IBI2 - med)./med;
IBI2(relDev > 0.2) = NaN;

% Only interpolate short gaps
IBI2 = fillmissing(IBI2,'linear','MaxGap',3);
% After outlier removal:
IBI2(abs(diff([NaN; IBI2])) > 0.3) = NaN;  % removes sudden >300ms jumps
end
%% ==================================================
function [rmssd_1Hz, sdnn_1Hz] = ibi_to_hrv_1Hz(IBI, IBIt, tCommon, win, minBeats, maxBadProp)

rmssd_1Hz = nan(size(tCommon));
sdnn_1Hz  = nan(size(tCommon));

for i = 1:numel(tCommon)
    a = tCommon(i) - win/2;
    b = tCommon(i) + win/2;

    idx = (IBIt >= a) & (IBIt <= b);
    ibi_w = IBI(idx);

    badProp = mean(isnan(ibi_w));
    ibi_w = ibi_w(~isnan(ibi_w));

    if badProp > maxBadProp || numel(ibi_w) < minBeats
        continue
    end

    d = diff(ibi_w);

    rmssd_1Hz(i) = 1000*sqrt(mean(d.^2)); % ms
    sdnn_1Hz(i)  = 1000*std(ibi_w);       % ms
end
end

%% ================= HELPER FUNCTION =================
function y = toScalar(x)
% Converts mixed CSV cell content to numeric scalar or NaN
    if isempty(x)
        y = NaN;
    elseif isnumeric(x)
        y = double(x(1));
    elseif isstring(x) || ischar(x)
        y = str2double(strtrim(string(x)));
        if isnan(y), y = NaN; end
    else
        y = NaN;
    end
end
