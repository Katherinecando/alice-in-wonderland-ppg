clear; clc; close all;



% ==========================

% USER SETTINGS

% ==========================

csvFolder = fullfile(pwd, "csv_ppg_files");     % your CSV folder

period    = "theatre";                          % dataset name for RRest

fs_target = 25;                                 % must match up.paramSet.filt_resample_fs

minMinutesRequired = 5;                         % skip tiny files

maxSubjectsToProcess = Inf;                       % set Inf for all, 1 for debug

doQC = false;                                    % set false when running all



% ==========================

% FIND CSV FILES

% ==========================

files = dir(fullfile(csvFolder, "*.csv"));

if isempty(files)

    error("No CSVs found in %s", csvFolder);

end



data = struct([]);

subCount = 0;



for f = 1:min(maxSubjectsToProcess, numel(files))

    filename = fullfile(files(f).folder, files(f).name);

    fprintf("\n--- Processing: %s\n", files(f).name);



    % ==========================

    % LOAD CSV (robust)

    % ==========================

    opts = detectImportOptions(filename, 'NumHeaderLines', 0);

    opts.VariableNamingRule = 'preserve';

    opts.Delimiter = {'\t', ',', ';'};

    T = readtable(filename, opts);



    names = string(T.Properties.VariableNames);

    names_clean = lower(strtrim(names));



    utc_idx  = find(names_clean == "utc", 1);

    data_idx = find(names_clean == "data", 1);



    if isempty(utc_idx) || isempty(data_idx)

        warning("Skipping %s: couldn't find UTC/DATA columns.", files(f).name);

        continue;

    end



    utc_raw = T{:, utc_idx};

    ppg_raw = T{:, data_idx};



    utc = force_numeric_column(utc_raw, "UTC");

    ppg = force_numeric_column(ppg_raw, "DATA");

    utc = utc(:); ppg = ppg(:);



    % ==========================

    % Guards

    % ==========================

    if isempty(utc) || isempty(ppg) || all(isnan(utc))

        warning("Skipping %s: UTC/DATA unusable.", files(f).name);

        continue;

    end



    % Remove rows where both are NaN

    valid0 = ~(isnan(utc) & isnan(ppg));

    utc = utc(valid0);

    ppg = ppg(valid0);



    if numel(utc) < 1000

        warning("Skipping %s: too few samples.", files(f).name);

        continue;

    end



    % ==========================

    % Fill missing UTC (carry forward)

    % ==========================

    utc_filled = utc;

    firstGood = find(~isnan(utc_filled), 1, 'first');

    if isempty(firstGood)

        warning("Skipping %s: UTC has no valid timestamps.", files(f).name);

        continue;

    end

    utc_filled(1:firstGood-1) = utc_filled(firstGood);



    for i = 2:numel(utc_filled)

        if isnan(utc_filled(i))

            utc_filled(i) = utc_filled(i-1);

        end

    end



    % ==========================

    % Build coarse seconds-from-start + fix scale (s/ms/us)

    % ==========================

    t_sec_coarse = utc_filled - utc_filled(1);

    t_sec_coarse = t_sec_coarse(:);



    dur_sec = t_sec_coarse(numel(t_sec_coarse)) - t_sec_coarse(1);

    if dur_sec > 6*3600

        t_ms = (utc_filled - utc_filled(1)) / 1000;

        if (t_ms(end)-t_ms(1)) < 6*3600

            t_sec_coarse = t_ms;

            fprintf("UTC looked like ms -> converted to seconds for %s\n", files(f).name);

        else

            t_us = (utc_filled - utc_filled(1)) / 1e6;

            if (t_us(end)-t_us(1)) < 6*3600

                t_sec_coarse = t_us;

                fprintf("UTC looked like us -> converted to seconds for %s\n", files(f).name);

            else

                warning("UTC duration still huge after scaling attempts for %s (%.1f hours).", ...

                    files(f).name, dur_sec/3600);

            end

        end

    end



    % ==========================

    % Rebuild fine time within each repeated-second block

    % ==========================

    t_sec = t_sec_coarse;

    i = 1;

    while i <= numel(t_sec)

        j = i;

        while j < numel(t_sec) && t_sec_coarse(j+1) == t_sec_coarse(i)

            j = j + 1;

        end

        nBlock = j - i + 1;

        if nBlock > 1

            t_sec(i:j) = t_sec_coarse(i) + (0:nBlock-1)'/nBlock;

        end

        i = j + 1;

    end



    % ==========================

    % Clean/sort + ensure unique time

    % ==========================

    mask = isfinite(t_sec) & isfinite(ppg);

    t_sec = t_sec(mask);

    ppg   = ppg(mask);



    [t_sec, ord] = sort(t_sec);

    ppg = ppg(ord);



    % Remove duplicates (interp1 needs unique)

    [t_sec, ia] = unique(t_sec, 'stable');

    ppg = ppg(ia);



    if numel(t_sec) < 1000

        warning("Skipping %s: too few samples after time cleanup.", files(f).name);

        continue;

    end



    % ==========================

    % Resample to uniform 25 Hz

    % ==========================

    t25 = (t_sec(1):1/fs_target:t_sec(end))';

    ppg25_raw = interp1(t_sec, ppg, t25, 'linear', 'extrap');



    duration_min = (t25(end)-t25(1))/60;

    if duration_min < minMinutesRequired

        warning("Skipping %s: only %.2f minutes.", files(f).name, duration_min);

        continue;

    end

    if duration_min > 400

        warning("Skipping %s: duration %.1f min implausible.", files(f).name, duration_min);

        continue;

    end



    % ==========================

    % STRONG CLEANING (this is what you were missing)

    % ==========================

    x = ppg25_raw;



    % 1) Fill any NaNs

    x(~isfinite(x)) = nan;

    x = fillmissing(x, 'linear', 'EndValues', 'nearest');



    % 2) Remove slow drift

    x = detrend(x);



    % 3) Winsorize using percentiles (remove extreme motion)

    p1 = prctile(x, 1);

    p99 = prctile(x, 99);

    x = min(max(x, p1), p99);



    % 4) Z-score (THIS makes std ~ 1)

    x = (x - mean(x,'omitnan')) / std(x,'omitnan');



    % 5) Clip to +-5 SD (final artefact control)

    x = max(min(x, 5), -5);



    % 6) Light median smoothing (200 ms)

    x = movmedian(x, round(fs_target*0.2));



    ppg25 = x;



    fprintf("After cleaning: mean=%.3f, std=%.3f, range=[%.2f, %.2f]\n", ...

        mean(ppg25,'omitnan'), std(ppg25,'omitnan'), min(ppg25), max(ppg25));



    % ==========================

    % QC plots (optional)

    % ==========================

    if doQC

        % respiration band (0.1â0.7 Hz)

        [b,a] = butter(3, [0.1 0.7]/(fs_target/2), 'bandpass');

        resp = filtfilt(b,a, ppg25);



        t_start = 10*60; t_end = 11*60;

        idx = (t25 >= t_start) & (t25 <= t_end);



        figure('Color','w'); plot(t25(idx), ppg25_raw(idx)); grid on;

        xlabel('Time (s)'); ylabel('PPG'); title('Raw resampled PPG (minute 10â11)');



        figure('Color','w'); plot(t25(idx), ppg25(idx)); grid on;

        xlabel('Time (s)'); ylabel('z'); title('Cleaned + z-scored PPG (minute 10â11)');



        figure('Color','w'); plot(t25(idx), resp(idx)); grid on;

        xlabel('Time (s)'); ylabel('a.u.'); title('Respiration-band (0.1â0.7 Hz) (minute 10â11)');

    end



    % ==========================

    % Build subject entry for RRest

    % ==========================

    subCount = subCount + 1;



    data(subCount).group = 1;

    data(subCount).ppg1  = ppg25;             % CLEANED signal

    data(subCount).fs.ppg1 = fs_target;



    % Dummy ref to avoid crashing

    data(subCount).ref = struct();

    data(subCount).ref.resp_sig = struct();

    data(subCount).ref.resp_sig.unknown = [];



    % Keep time if you want

    data(subCount).t = t25;



    fprintf("Added subject %d | duration %.1f min\n", subCount, duration_min);

end



if isempty(data)

    error("No valid subjects were created. Check CSV folder and column names.");

end



% ==========================

% SAVE dataset MAT

% ==========================

outName = period + "_data.mat";

save(outName, "data", "-v7.3");

fprintf("\nSaved dataset: %s (subjects=%d)\n", outName, numel(data));



% Quick preview

figure('Color','w');

plot(data(1).ppg1(1:min(5000,end))); grid on;

title("Subject 1 cleaned PPG preview (first 5000 samples)");

xlabel("Samples"); ylabel("z");



%% ========= Helper =========

function x = force_numeric_column(col, label)

    if isnumeric(col)

        x = double(col);

        return;

    end



    if iscell(col)

        col = string(col);

    end



    if isstring(col) || ischar(col)

        s = string(col);

        s = strtrim(s);

        s = replace(s, ",", ""); % remove thousand separators if any

        s( s=="" | lower(s)=="nan" | lower(s)=="na" | lower(s)=="null" ) = "NaN";



        x = str2double(s);

        fracNaN = mean(isnan(x));



        if fracNaN > 0.5

            % try datetime parsing

            try

                dt = datetime(s, 'InputFormat','yyyy-MM-dd HH:mm:ss', 'TimeZone','UTC');

                x = seconds(dt - dt(1));

                return;

            catch

                try

                    dt = datetime(s, 'TimeZone','UTC');

                    x = seconds(dt - dt(1));

                    return;

                catch

                    error("Couldn't convert %s column to numeric.", label);

                end

            end

        end

        return;

    end



    try

        x = double(col);

    catch

        error("Couldn't convert %s column to numeric (type %s).", label, class(col));

    end

end
