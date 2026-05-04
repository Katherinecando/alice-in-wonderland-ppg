clear; clc; close all;

% ==========================
% USER SETTINGS
% ==========================
csvFolder = fullfile(pwd, "csv_ppg_files");
period    = "theatre";
fs_target = 25;
minMinutesRequired = 5;
maxSubjectsToProcess = Inf;  % set 1 for debugging
doQC = false;                % true for debugging

files = dir(fullfile(csvFolder, "*.csv"));
if isempty(files), error("No CSVs found in %s", csvFolder); end

data = struct([]);
subCount = 0;

for f = 1:min(maxSubjectsToProcess, numel(files))
    filename = fullfile(files(f).folder, files(f).name);
    fprintf("\n--- Processing: %s\n", files(f).name);

    opts = detectImportOptions(filename, 'NumHeaderLines', 0);
    opts.VariableNamingRule = 'preserve';
    opts.Delimiter = {'\t', ',', ';'};
    T = readtable(filename, opts);

    names = lower(strtrim(string(T.Properties.VariableNames)));
    utc_idx  = find(names == "utc", 1);
    data_idx = find(names == "data", 1);

    if isempty(utc_idx) || isempty(data_idx)
        warning("Skipping %s: couldn't find UTC/DATA columns.", files(f).name);
        continue;
    end

    utc = force_numeric_column(T{:, utc_idx}, "UTC"); utc = utc(:);
    ppg = force_numeric_column(T{:, data_idx}, "DATA"); ppg = ppg(:);

    % Guards
    if isempty(utc) || isempty(ppg) || all(isnan(utc))
        warning("Skipping %s: UTC/DATA unusable.", files(f).name);
        continue;
    end

    valid0 = ~(isnan(utc) & isnan(ppg));
    utc = utc(valid0); ppg = ppg(valid0);

    if numel(utc) < 1000
        warning("Skipping %s: too few samples.", files(f).name);
        continue;
    end

    % Fill missing UTC (carry forward)
    utc_filled = utc;
    firstGood = find(~isnan(utc_filled), 1, 'first');
    if isempty(firstGood)
        warning("Skipping %s: UTC has no valid timestamps.", files(f).name);
        continue;
    end
    utc_filled(1:firstGood-1) = utc_filled(firstGood);
    for i = 2:numel(utc_filled)
        if isnan(utc_filled(i)), utc_filled(i) = utc_filled(i-1); end
    end

    % Coarse time + fix scale
    t_sec_coarse = (utc_filled - utc_filled(1));
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
            end
        end
    end

    % Fine time within each repeated-second block
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

    % Clean/sort/unique
    mask = isfinite(t_sec) & isfinite(ppg);
    t_sec = t_sec(mask); ppg = ppg(mask);
    [t_sec, ord] = sort(t_sec); ppg = ppg(ord);
    [t_sec, ia] = unique(t_sec, 'stable'); ppg = ppg(ia);

    if numel(t_sec) < 1000
        warning("Skipping %s: too few samples after cleanup.", files(f).name);
        continue;
    end

    % Resample to 25 Hz
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

    % ===== Cleaning (stable + z-scored) =====
    x = ppg25_raw;
    x(~isfinite(x)) = nan;
    x = fillmissing(x, 'linear', 'EndValues', 'nearest');
    x = detrend(x);

    p1 = prctile(x, 1);
    p99 = prctile(x, 99);
    x = min(max(x, p1), p99);

    x = (x - mean(x,'omitnan')) / std(x,'omitnan');
    x = max(min(x, 5), -5);
    x = movmedian(x, round(fs_target*0.2));

    ppg25 = x;

    fprintf("After cleaning: mean=%.3f, std=%.3f, range=[%.2f, %.2f]\n", ...
        mean(ppg25,'omitnan'), std(ppg25,'omitnan'), min(ppg25), max(ppg25));

    if doQC
        [b,a] = butter(3, [0.1 0.7]/(fs_target/2), 'bandpass');
        resp = filtfilt(b,a, ppg25);
        idx = (t25 >= 10*60) & (t25 <= 11*60);

        figure('Color','w'); plot(t25(idx), ppg25_raw(idx)); grid on;
        title('Raw resampled PPG (10–11 min)'); xlabel('s'); ylabel('PPG');

        figure('Color','w'); plot(t25(idx), ppg25(idx)); grid on;
        title('Cleaned z-scored PPG (10–11 min)'); xlabel('s'); ylabel('z');

        figure('Color','w'); plot(t25(idx), resp(idx)); grid on;
        title('Resp band (0.1–0.7 Hz) (10–11 min)'); xlabel('s'); ylabel('a.u.');
    end

    % ===== Build RRest subject (FORMAT FIX) =====
    subCount = subCount + 1;

    data(subCount).group = 1;

    % IMPORTANT: RRest expects signal structs with fields .v and .fs
    data(subCount).ppg1 = struct();
    data(subCount).ppg1.v  = ppg25;
    data(subCount).ppg1.fs = fs_target;

    % Dummy ref so setup_universal_params doesn't die
    data(subCount).ref = struct();
    data(subCount).ref.resp_sig = struct();
    data(subCount).ref.resp_sig.unknown = [];

    % Optional time
    data(subCount).t = t25;

    fprintf("Added subject %d | duration %.1f min\n", subCount, duration_min);
end

if isempty(data)
    error("No valid subjects were created.");
end

outName = period + "_data.mat";
save(outName, "data", "-v7.3");
fprintf("\nSaved dataset: %s (subjects=%d)\n", outName, numel(data));

% Quick preview
figure('Color','w');
plot(data(1).ppg1.v(1:min(5000,end))); grid on;
title("Subject 1 cleaned PPG preview"); xlabel("Samples"); ylabel("z");

% ========= Helper =========
function x = force_numeric_column(col, label)
    if isnumeric(col), x = double(col); return; end
    if iscell(col), col = string(col); end

    if isstring(col) || ischar(col)
        s = string(col);
        s = strtrim(s);
        s = replace(s, ",", "");
        s( s=="" | lower(s)=="nan" | lower(s)=="na" | lower(s)=="null" ) = "NaN";
        x = str2double(s);

        fracNaN = mean(isnan(x));
        if fracNaN > 0.5
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