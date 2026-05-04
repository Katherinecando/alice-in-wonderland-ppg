%% Clean HRM plotting for performance window (80 minutes)

% - Robust CSV import (auto delimiter, messy blanks, BOM)

% - Uses ONLY rows where HRM exists (no carry-forward plateaus)

% - Plots all participants + audience mean Â± SD (1 Hz resample)

clear; clc;



dataFolder = fullfile(pwd, "csv_ppg_files");   % folder containing the raw CSV files

perfMinutes = 80;                    % performance duration

perfSec = perfMinutes * 60;



files = dir(fullfile(dataFolder, "*.csv"));

if isempty(files)

    error("No CSV files found in %s", dataFolder);

end



% Store each participant HR series as timetable for group stats

allSeries = {};

plottedNames = strings(0);

skipped = strings(0);



%% ---------- PASS 1: read each file, extract HR points, store series ----------

for i = 1:numel(files)

    fpath = fullfile(files(i).folder, files(i).name);



    % --- read first line to detect delimiter ---

    fid = fopen(fpath, 'r');

    if fid < 0

        skipped(end+1) = files(i).name; %#ok<SAGROW>

        continue;

    end

    headerLine = fgetl(fid);

    fclose(fid);



    if ~ischar(headerLine)

        skipped(end+1) = files(i).name; %#ok<SAGROW>

        continue;

    end



    headerLine = erase(headerLine, char(65279)); % remove BOM if present



    % Detect delimiter by split count

    delims = {sprintf('\t'), ',', ';'};

    counts = zeros(size(delims));

    for d = 1:numel(delims)

        counts(d) = numel(strsplit(headerLine, delims{d}));

    end

    [~, best] = max(counts);

    delim = delims{best};



    % --- read table with detected delimiter ---

    try

        T = readtable(fpath, 'FileType','text', 'Delimiter',delim, ...

            'MultipleDelimsAsOne', true, 'TreatAsEmpty', {''});

    catch

        T = readtable(fpath, 'FileType','text', 'Delimiter',delim);

    end



    if width(T) < 2

        skipped(end+1) = files(i).name; %#ok<SAGROW>

        continue;

    end



    % --- locate columns robustly by name ---

    rawNames = string(T.Properties.VariableNames);

    rawNames = erase(rawNames, char(65279));

    cleanNames = lower(strtrim(rawNames));

    cleanNames = erase(cleanNames, '"');

    cleanNames = regexprep(cleanNames, "[^a-z0-9]", "");



    utcCol = find(contains(cleanNames, "utc"), 1);

    hrmCol = find(contains(cleanNames, "hrm"), 1);



    if isempty(utcCol) || isempty(hrmCol)

        skipped(end+1) = files(i).name; %#ok<SAGROW>

        continue;

    end



    % --- parse numeric with blanks ---

    utc = str2double(string(T{:, utcCol}));

    hrm = str2double(string(T{:, hrmCol}));



    % Forward-fill UTC

    utcFilled = utc;

    last = NaN;

    for k = 1:numel(utcFilled)

        if ~isnan(utcFilled(k))

            last = utcFilled(k);

        else

            utcFilled(k) = last;

        end

    end



    ok = ~isnan(utcFilled);

    utcFilled = utcFilled(ok);

    hrm = hrm(ok);



    if numel(utcFilled) < 50

        skipped(end+1) = files(i).name; %#ok<SAGROW>

        continue;

    end



    % Build time axis: distribute samples within each second

    utc0 = utcFilled(1);

    t = zeros(size(utcFilled));

    uSecs = unique(utcFilled);



    for s = 1:numel(uSecs)

        secVal = uSecs(s);

        idx = find(utcFilled == secVal);

        n = numel(idx);

        if n == 1

            t(idx) = (secVal - utc0);

        else

            t(idx) = (secVal - utc0) + (0:n-1)'/n;

        end

    end



    % Keep ONLY rows where HRM exists and is plausible

    valid = ~isnan(hrm) & hrm > 30 & hrm < 220 & t >= 0 & t <= perfSec;

    t_hr = t(valid);

    hr_hr = hrm(valid);



    if numel(t_hr) < 10

        skipped(end+1) = files(i).name; %#ok<SAGROW>

        continue;

    end



    % Remove duplicate time stamps (can happen); keep last occurrence

    [t_hr_u, ia] = unique(t_hr, 'stable');

    hr_hr_u = hr_hr(ia);



    % Store as timetable (seconds)

    TT = timetable(seconds(t_hr_u), hr_hr_u, 'VariableNames', {'HR'});

    allSeries{end+1} = TT; %#ok<SAGROW>

    plottedNames(end+1) = string(files(i).name); %#ok<SAGROW>

end



fprintf("Loaded %d/%d files (skipped %d).\n", numel(allSeries), numel(files), numel(skipped));



%% ---------- PLOT 1: all participants (HR points) ----------

figure; hold on; grid on;

for k = 1:numel(allSeries)

    tt = allSeries{k};

    tmin = minutes(tt.Time);

    plot(tmin, tt.HR, ".", "MarkerSize", 6);

end

xlabel("Time from start (min)");

ylabel("HRM (bpm)");

title(sprintf("All sessions: HRM points (0â%d min performance window)", perfMinutes));

xlim([0 perfMinutes]);



%% ---------- PLOT 2: audience mean Â± SD (resampled to 1 Hz) ----------

% Common grid: 0..80 min at 1 Hz

tGrid = seconds(0:1:perfSec);



H = NaN(numel(tGrid), numel(allSeries));

for k = 1:numel(allSeries)

    TTk = allSeries{k};



    % Resample to 1 Hz; 'linear' is fine for HRM updates

    try

        TTk2 = retime(TTk, tGrid, 'linear');

    catch

        % older MATLAB: ensure timetable has unique times

        TTk2 = retime(TTk, tGrid, 'nearest');

    end

    H(:,k) = TTk2.HR;

end



mu = mean(H, 2, 'omitnan');

sd = std(H, 0, 2, 'omitnan');



figure; hold on; grid on;

plot(minutes(tGrid), mu, "LineWidth", 2);

plot(minutes(tGrid), mu + sd, "--", "LineWidth", 1);

plot(minutes(tGrid), mu - sd, "--", "LineWidth", 1);

xlabel("Time from start (min)");

ylabel("HRM (bpm)");

title(sprintf("Audience mean HRM Â± SD (1 Hz resample, 0â%d min)", perfMinutes));

xlim([0 perfMinutes]);



%% ---------- Optional: print skipped files ----------

if ~isempty(skipped)

    fprintf("\nSkipped files:\n");

    disp(skipped(:));

end

