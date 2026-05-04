clear; clc; close all;

%% ================= USER SETTINGS =================
performanceMinutes = 80;
performanceSeconds = performanceMinutes * 60;

minHR = 40;                  % bpm
maxHR = 130;                 % bpm
minValidPoints = 120;        % minimum valid HR samples

% HRV settings
fsDefault = 25;              % expected WRT waveform sampling rate
hrvWin = 60;                 % seconds (time-domain HRV window)
minBeatsInWin = 20;          % minimum beats required per HRV window
maxBadProp = 0.2;            % max allowed NaNs proportion inside HRV window

%% ================= IMPORT CSV FILES =================
dataFolder = "C:\Users\katyl\OneDrive - City, University of London\year 3\individual project\PPG_data";
files = dir(fullfile(dataFolder, "*.csv"));

% Optional extra filtering
files = files(~startsWith({files.name}, "."));    % remove hidden
files = files(~contains({files.name}, "~"));      % remove temp

if isempty(files)
    error("No CSV files found in: %s", dataFolder);
end

fprintf('Found %d CSV files\n', numel(files));

%% ================= PROCESS EACH FILE =================
HRM_all = {};
T_all = {};
RMSSD_all = {};
SDNN_all  = {};

skipped = 0;
didPlotQC = false;   % ✅ plot first successful participant only

for k = 1:numel(files)

    fname = fullfile(files(k).folder, files(k).name);
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

    % Columns: 1=UTC, 2=DATA (PPG waveform), 3=HRM
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

    % time-from-start for every row (UTC repeats within each second)
    t_allRows = utc - utc(1);

    % -------- HRM SERIES (per-second entries) --------
    validHR = ~isnan(t_allRows) & ~isnan(hrm) & hrm >= minHR & hrm <= maxHR;
    t_hr = t_allRows(validHR);
    hrmV = hrm(validHR);

    % Keep only performance window
    keepHR = t_hr >= 0 & t_hr <= performanceSeconds;
    t_hr = t_hr(keepHR);
    hrmV = hrmV(keepHR);

    if numel(t_hr) < minValidPoints
        warning('Skipping %s (not enough HRM data in 0–80 min)', files(k).name);
        skipped = skipped + 1;
        continue;
    end

    % Remove duplicate timestamps in HRM
    [tUnique, ia] = unique(t_hr, 'stable');
    hrmUnique = hrmV(ia);

    % Lock participant index so arrays stay aligned
    p = numel(HRM_all) + 1;
    T_all{p}   = tUnique;
    HRM_all{p} = hrmUnique;

    % -------- PPG WAVEFORM SERIES (for HRV) --------
    validPPG = ~isnan(t_allRows) & ~isnan(data);
    utc_ppg = utc(validPPG);
    ppg = data(validPPG);

    % Keep only performance window (using time-from-start)
    t_ppg_sec = utc_ppg - utc(1);
    keepPPG = t_ppg_sec >= 0 & t_ppg_sec <= performanceSeconds;

    utc_ppg = utc_ppg(keepPPG);
    ppg = ppg(keepPPG);

    if numel(ppg) < 1000
        warning('No usable PPG waveform in %s -> HRV empty', files(k).name);
        RMSSD_all{p} = nan(performanceSeconds+1, 1);
        SDNN_all{p}  = nan(performanceSeconds+1, 1);
        continue;
    end

    % Estimate fs as mode(samples per UTC second)
    [uS,~,g] = unique(utc_ppg);
    counts = accumarray(g, 1);
    fsEst = mode(counts);
    if isempty(fsEst) || fsEst < 5 || fsEst > 200
        fsEst = fsDefault;
    end

    % Build high-res time vector within each UTC second
    idxWithin = nan(size(utc_ppg));
    for s = 1:numel(uS)
        ii = find(utc_ppg == uS(s));
        idxWithin(ii) = (0:numel(ii)-1).';
    end
    t_ppg = (utc_ppg - utc_ppg(1)) + idxWithin./fsEst;

    % -------- Beat detection -> IBI -> HRV --------
    try
        [beatTimes, IBI, IBIt, usedInversion] = ppg_to_ibi(ppg, fsEst, 0);
        IBI = clean_ibi(IBI);

        % ✅ QC plot: first successful participant only
        if ~didPlotQC
            didPlotQC = true;
            fprintf("QC P=%d | file=%s | fsEst=%gHz | beats=%d | inverted=%d\n", ...
                p, files(k).name, fsEst, numel(beatTimes), usedInversion);

            figure;

            mask30 = t_ppg <= 30;

            subplot(2,1,1);
            plot(t_ppg(mask30), ppg(mask30));
            xlabel('Time (s)'); ylabel('PPG raw (DATA)');
            title('Raw PPG (first 30s)');

            bp = designfilt('bandpassiir','FilterOrder',4, ...
                'HalfPowerFrequency1',0.7,'HalfPowerFrequency2',4.0, ...
                'SampleRate',fsEst);
            xf = filtfilt(bp, double(ppg));
            xf = xf - median(xf);
            d = mad(xf,1); if d==0, d = std(xf); end; if d==0, d=1; end
            xf = xf / d;

            subplot(2,1,2);
            plot(t_ppg(mask30), xf(mask30)); hold on;
            bt = beatTimes(beatTimes <= 30);
            yL = ylim;
            for b = 1:numel(bt)
                line([bt(b) bt(b)], yL, 'LineStyle','--');
            end
            hold off;
            xlabel('Time (s)'); ylabel('Filtered (norm)');
            title('Filtered PPG + detected beats');
        end

        % Align HRV to 1 Hz axis 0..performanceSeconds
        tCommon = (0:performanceSeconds)';
        [RMSSD_all{p}, SDNN_all{p}] = ibi_to_hrv_1Hz(IBI, IBIt, tCommon, hrvWin, minBeatsInWin, maxBadProp);

    catch ME
        warning('HRV failed for %s: %s', files(k).name, ME.message);
        RMSSD_all{p} = nan(performanceSeconds+1, 1);
        SDNN_all{p}  = nan(performanceSeconds+1, 1);
    end
end

fprintf('Loaded %d participants (HR), skipped %d files\n', numel(HRM_all), skipped);

if numel(HRM_all) < 3
    error('Too few valid participants loaded.');
end

%% ================= BUILD MATRICES (4801 x nP) =================
nP = numel(HRM_all);
tCommon = (0:performanceSeconds)';

HRM_mat   = nan(numel(tCommon), nP);
RMSSD_mat = nan(numel(tCommon), nP);
SDNN_mat  = nan(numel(tCommon), nP);

for p = 1:nP
    HRM_mat(:,p)   = interp1(T_all{p}, HRM_all{p}, tCommon, 'linear', NaN);
    RMSSD_mat(:,p) = RMSSD_all{p};
    SDNN_mat(:,p)  = SDNN_all{p};
end

fprintf("Done. HRM_mat=%s, RMSSD_mat=%s, SDNN_mat=%s\n", ...
    mat2str(size(HRM_mat)), mat2str(size(RMSSD_mat)), mat2str(size(SDNN_mat)));

% --- Remove extreme dropouts / spikes (artefact mask) ---
ppg2 = double(ppg);

% Anything far below the running median is a dropout
m = movmedian(ppg2, round(2*fsEst));    % 2s running median
dropMask = (ppg2 < (m - 5*mad(ppg2,1))); % robust threshold

% Also mask sudden jumps
jumpMask = [false; abs(diff(ppg2)) > 8*mad(diff(ppg2),1)];

bad = dropMask | jumpMask;

% Replace bad samples with NaN then interpolate short gaps only
ppg2(bad) = NaN;
ppg2 = fillmissing(ppg2,'linear','MaxGap',round(0.5*fsEst)); % fill gaps <=0.5s

% If too much missing, skip HRV
if mean(isnan(ppg2)) > 0.2
    warning("Too much PPG missing after artefact removal in %s", files(k).name);
    RMSSD_all{p} = nan(performanceSeconds+1,1);
    SDNN_all{p}  = nan(performanceSeconds+1,1);
    continue;
end


%% ================= FUNCTIONS =================

function [beatTimes, IBI, IBIt, usedInversion] = ppg_to_ibi(ppg2, fs, t0)
if nargin < 3, t0 = 0; end

bp = designfilt('bandpassiir','FilterOrder',4, ...
    'HalfPowerFrequency1',0.7,'HalfPowerFrequency2',4.0, ...
    'SampleRate',fs);
x = filtfilt(bp, double(ppg));

x = x - median(x);
sx = mad(x,1);
if sx == 0, sx = std(x); end
if sx == 0, sx = 1; end
x = x / sx;

minPeakDist = round(0.45 * fs);
minProm = 0.8;

[~, locs] = findpeaks(x, 'MinPeakDistance', minPeakDist, 'MinPeakProminence', minProm);
usedInversion = false;

dur_s = numel(ppg)/fs;
expectedMinBeats = max(10, floor(dur_s * 0.5)); % ~30 bpm minimum-ish

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

function IBI2 = clean_ibi(IBI)
IBI2 = IBI;

IBI2(IBI2 < 0.3 | IBI2 > 2.0) = NaN;

med = movmedian(IBI2, 11, 'omitnan');
relDev = abs(IBI2 - med)./med;
IBI2(relDev > 0.2) = NaN;

% extra jump rule
d = abs(diff([NaN; IBI2]));
IBI2(d > 0.3) = NaN;

IBI2 = fillmissing(IBI2,'linear','MaxGap',3);
end

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
    rmssd_1Hz(i) = 1000 * sqrt(mean(d.^2)); % ms
    sdnn_1Hz(i)  = 1000 * std(ibi_w);       % ms
end
end

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