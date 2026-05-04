%% plot_rr_overlay.m
% Plots all 32 respiratory rate signals overlaid in a single figure
% with a bold group mean trend on top.
%
% REQUIRES in workspace (already there from your main pipeline):
%   theatre_data.mat  --> struct array 'data' with data(i).ppg1 (25 Hz)
%                         and data(i).t (time vector in seconds)
%
% HOW TO RUN: just run this script in MATLAB.
%   Your working directory should be the PPG_data folder.
%
% OUTPUT: Figure saved as 'RR_overlay_all_subjects.png'

clear; clc; close all;

%% ââ 0) SETTINGS ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
load('theatre_data.mat', 'data');   % loads struct array 'data'

fs_ppg    = 25;          % PPG sampling rate (Hz) â must match your data
win_sec   = 32;          % RR estimation window length (seconds)
step_sec  = 4;           % window step (seconds) â gives ~1 estimate every 4 s
f_lo      = 0.15;        % lower bound of respiration band (Hz) = 9 br/min
f_hi      = 0.55;        % upper bound of respiration band (Hz) = 33 br/min
nanThresh = 0.30;        % skip subjects with >30% NaN in final RR trace

% Common time grid: 0..4800 seconds at 1/step_sec Hz resolution
t_common = (0 : step_sec : 4800)';   % 1201 points

%% ââ 1) BANDPASS FILTER (0.15â0.55 Hz) âââââââââââââââââââââââââââââââââââ
% Build the filter once (applied to each subject's PPG)
[b_bp, a_bp] = butter(3, [f_lo f_hi] / (fs_ppg/2), 'bandpass');

%% ââ 2) EXTRACT RR FOR EACH SUBJECT ââââââââââââââââââââââââââââââââââââââ
nSubj    = numel(data);
RR_all   = nan(numel(t_common), nSubj);   % rows = time, cols = subjects
kept     = false(1, nSubj);

win_samp  = win_sec  * fs_ppg;
step_samp = step_sec * fs_ppg;

for s = 1:nSubj
    ppg = extract_signal(data(s).ppg1);
    t   = extract_signal(data(s).t);

    if numel(ppg) < win_samp * 2
        fprintf('Subject %d: too short â skipped\n', s);
        continue;
    end

    % ââ a) Bandpass filter into respiration band ââ
    % Use zero-phase filtfilt; fill any NaNs first
    ppg = fillmissing(ppg, 'linear', 'EndValues', 'nearest');
    resp = filtfilt(b_bp, a_bp, ppg);

    % ââ b) Sliding-window dominant frequency â RR in breaths/min ââ
    nWin   = floor((numel(resp) - win_samp) / step_samp) + 1;
    rr_bpm = nan(nWin, 1);
    t_mid  = nan(nWin, 1);

    for w = 1:nWin
        idx = (w-1)*step_samp + (1:win_samp);
        seg = resp(idx);

        % Power spectrum in respiration band
        N_fft = 2^nextpow2(numel(seg));
        Xf = abs(fft(seg, N_fft));
        freqs = (0:N_fft-1) * (fs_ppg / N_fft);

        band = (freqs >= f_lo) & (freqs <= f_hi);
        if sum(band) < 3
            continue;
        end
        [~, kmax] = max(Xf(band));

        f_band = freqs(band);
        f_peak = f_band(kmax);

        rr_bpm(w) = f_peak * 60;   % Hz â breaths/min
        t_mid(w)  = t(idx(end/2)); % time at window centre (seconds)
    end

    % ââ c) Remove any RR estimates outside physiological range ââ
    % (6â30 breaths/min during rest/light activity)
    rr_bpm(rr_bpm < 6 | rr_bpm > 30) = NaN;

    % ââ d) Snap onto the common time grid (nearest-neighbor, allow Â±step tolerance) ââ
    if sum(~isnan(rr_bpm)) < 5
        fprintf('Subject %d: too few valid RR estimates â skipped\n', s);
        continue;
    end

    rr_on_common = interp1(t_mid(~isnan(rr_bpm)), rr_bpm(~isnan(rr_bpm)), ...
                            t_common, 'linear', NaN);

    % Quality check: skip if >30% still NaN after interpolation
    if mean(isnan(rr_on_common)) > nanThresh
        fprintf('Subject %d: too many NaNs after alignment â skipped\n', s);
        continue;
    end

    RR_all(:, s) = rr_on_common;
    kept(s) = true;
    fprintf('Subject %d: RR extracted OK  (%.0fâ%.0f br/min, %.0f%% valid)\n', ...
        s, min(rr_bpm,'omitnan'), max(rr_bpm,'omitnan'), ...
        100*mean(~isnan(rr_on_common)));
end

RR_kept = RR_all(:, kept);
nKept   = sum(kept);
fprintf('\n%d / %d subjects kept after QC\n', nKept, nSubj);

if nKept == 0
    error('No subjects passed QC â check your theatre_data.mat and settings.');
end

%% ââ 3) GROUP MEAN (ignoring NaN) ââââââââââââââââââââââââââââââââââââââââ
RR_mean   = mean(RR_kept, 2, 'omitnan');
RR_mean_s = smoothdata(RR_mean, 'movmean', round(60/step_sec), 'omitnan');  % 60 s smooth

%% ââ 4) PLOT ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
t_min = t_common / 60;   % convert to minutes for the x-axis

% Colour palette: thin grey for individuals, bold black for mean
individual_color = [0.70 0.70 0.70];
mean_color       = [0    0    0   ];

fig = figure('Color','w', 'Units','centimeters', 'Position',[2 2 20 10]);

hold on; grid on; box on;

% ââ Individual traces ââ
for s = 1:nKept
    plot(t_min, RR_kept(:,s), ...
        'Color', [individual_color 0.55], ...   % slight transparency
        'LineWidth', 0.8);
end

% ââ Group mean (smoothed) ââ
h_mean = plot(t_min, RR_mean_s, ...
    'Color', mean_color, 'LineWidth', 2.5);

% ââ Axes labels ââ
xlabel('Time (minutes)', 'FontSize', 11, 'FontName', 'Arial');
ylabel('Respiratory rate (breaths min^{-1})', 'FontSize', 11, 'FontName', 'Arial');
title(sprintf('Respiratory rate â all %d participants overlaid (group mean in black)', nKept), ...
    'FontSize', 12, 'FontName', 'Arial');

% ââ Legend ââ
h_ind = plot(nan, nan, 'Color', individual_color, 'LineWidth', 1.2); % dummy for legend
legend([h_ind h_mean], {'Individual participants', 'Group mean (60 s smoothed)'}, ...
    'Location', 'northeast', 'FontSize', 10, 'FontName', 'Arial');

ylim([4 35]);
xlim([0 t_min(end)]);
set(gca, 'FontName', 'Arial', 'FontSize', 10);

%% ââ 5) SAVE FIGURE ââââââââââââââââââââââââââââââââââââââââââââââââââââââ
outFile = fullfile(pwd, 'RR_overlay_all_subjects.png');
exportgraphics(fig, outFile, 'Resolution', 300);
fprintf('\nFigure saved to: %s\n', outFile);

fprintf('\n--- Summary ---\n');
fprintf('Subjects plotted : %d\n', nKept);
fprintf('Time resolution  : every %d seconds\n', step_sec);
fprintf('RR window length : %d seconds\n', win_sec);
fprintf('Group mean RR    : %.1f Â± %.1f breaths/min\n', ...
    mean(RR_mean,'omitnan'), std(RR_mean,'omitnan'));

%% ââ Helper ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
function v = extract_signal(x)
% Safely converts RRest/v7.3 struct field to a double column vector.
    if isnumeric(x)
        v = double(x(:));
    elseif iscell(x)
        v = double(cell2mat(x(:)));
    elseif isstruct(x)
        for candidate = {'v','x','data','ppg','val','signal','values'}
            if isfield(x, candidate{1})
                raw = x.(candidate{1});
                if isnumeric(raw) && numel(raw) > 1
                    v = double(raw(:));
                    return;
                end
            end
        end
        error('struct signal has fields {%s} â none recognised. Check field names match expected format.', ...
              strjoin(fieldnames(x), ', '));
    else
        try
            v = double(x(:));
        catch
            error('Cannot convert signal field (class: %s) to numeric.', class(x));
        end
    end
end
