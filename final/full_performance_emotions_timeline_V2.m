%% =========================
% CLEAN 3-STATE AUDIENCE EXPERIENCE TIMELINE
load('HRV_final.mat')
H = HRM_mat;
meanHR = mean(H, 2, 'omitnan');
peaks_final_analysis

% map variable names for the timeline script
t_mid  = t_sync;                                        % times in seconds
sync_t = sync;                                          % raw synchrony
sync_s = smoothdata(sync, 'movmean', 61, 'omitnan');    % ~1 min smoothed

%% =========================

% 1) Interpolate mean HR onto synchrony timeline
meanHR_mid = interp1(tCommon, meanHR, t_mid, 'linear', 'extrap');

% 2) Smooth HR to match synchrony smoothing
hr_s = movmean(meanHR_mid, 3, 'omitnan');

% 3) Z-score synchrony and HR
zSync = (sync_s - mean(sync_s, 'omitnan')) ./ std(sync_s, 'omitnan');
zHR   = (hr_s   - mean(hr_s,   'omitnan')) ./ std(hr_s,   'omitnan');

% 4) 3-state classification
% State codes:
% 1 = High shared engagement
% 2 = Shared engagement
% 3 = Lower / individual engagement
state3 = NaN(size(t_mid));

for i = 1:length(t_mid)
    if zSync(i) >= 0.5 && zHR(i) >= 0
        state3(i) = 1;   % High shared engagement
    elseif zSync(i) >= 0
        state3(i) = 2;   % Shared engagement
    else
        state3(i) = 3;   % Lower / individual engagement
    end
end

% 5) Clean tiny fragments
minDurSec = 30;   % merge segments shorter than 30 sec
dt = median(diff(t_mid));
minPts = max(1, round(minDurSec / dt));

state3_clean = state3;
startIdx = 1;

while startIdx <= length(state3_clean)
    endIdx = startIdx;
    while endIdx < length(state3_clean) && state3_clean(endIdx+1) == state3_clean(startIdx)
        endIdx = endIdx + 1;
    end

    segLen = endIdx - startIdx + 1;

    if segLen < minPts
        if startIdx > 1
            state3_clean(startIdx:endIdx) = state3_clean(startIdx-1);
        elseif endIdx < length(state3_clean)
            state3_clean(startIdx:endIdx) = state3_clean(endIdx+1);
        end
    end

    startIdx = endIdx + 1;
end

% 6) Plot figure
figure('Color','w','Position',[100 100 1300 750]);

subplot(3,1,1);
plot(t_mid/60, sync_t, 'Color', [0.8 0.8 0.8], 'LineWidth', 0.8); hold on;
plot(t_mid/60, sync_s, 'k', 'LineWidth', 2);
yline(mean(sync_s,'omitnan'), '--', 'Mean');
grid on;
xlabel('Time (min)');
ylabel('Synchrony');
title('PR synchrony over time');

subplot(3,1,2);
plot(t_mid/60, meanHR_mid, 'Color', [0.8 0.8 0.8], 'LineWidth', 0.8); hold on;
plot(t_mid/60, hr_s, 'r', 'LineWidth', 2);
yline(mean(hr_s,'omitnan'), '--', 'Mean');
grid on;
xlabel('Time (min)');
ylabel('Mean HR (bpm)');
title('Group mean PR over time');

subplot(3,1,3);
imagesc(t_mid/60, 1, state3_clean');
set(gca, 'YTick', []);
xlabel('Time (min)');
title('Audience experience timeline');

% Colormap:
% 1 = High shared engagement
% 2 = Shared engagement
% 3 = Lower / individual engagement
cmap3 = [
    1.00 0.40 0.40   % red = high shared engagement
    0.60 0.80 1.00   % blue = shared engagement
    0.85 0.85 0.85   % grey = lower / individual engagement
];
colormap(gca, cmap3);
cb = colorbar;
cb.Ticks = 1:3;
cb.TickLabels = {'High shared eng.','Shared eng.','Lower / individual eng.'};

% 7) Peak detection (same as before)
[pks, locs] = findpeaks(sync_s, ...
    'MinPeakHeight', mean(sync_s,'omitnan') + std(sync_s,'omitnan'), ...
    'MinPeakDistance', round(60/dt));

peakTimes_min = t_mid(locs) / 60;

peakTable = table(peakTimes_min(:), pks(:), zHR(locs), ...
    'VariableNames', {'PeakTime_min','SynchronyPeak','HR_z_at_peak'});

disp(peakTable);

% 8) Extract segments
segments3 = struct('state', {}, 'tStart', {}, 'tEnd', {}, 'durationSec', {});
segCount = 0;
startIdx = 1;

while startIdx <= length(state3_clean)
    endIdx = startIdx;
    while endIdx < length(state3_clean) && state3_clean(endIdx+1) == state3_clean(startIdx)
        endIdx = endIdx + 1;
    end

    segCount = segCount + 1;
    segments3(segCount).state = state3_clean(startIdx);
    segments3(segCount).tStart = t_mid(startIdx);
    segments3(segCount).tEnd = t_mid(endIdx);
    segments3(segCount).durationSec = t_mid(endIdx) - t_mid(startIdx);

    startIdx = endIdx + 1;
end

% 9) Convert to reporting table
stateLabel = strings(length(segments3),1);
startMin = zeros(length(segments3),1);
endMin   = zeros(length(segments3),1);
durMin   = zeros(length(segments3),1);

for k = 1:length(segments3)
    switch segments3(k).state
        case 1
            stateLabel(k) = "High shared engagement";
        case 2
            stateLabel(k) = "Shared engagement";
        case 3
            stateLabel(k) = "Lower / individual engagement";
    end

    startMin(k) = segments3(k).tStart / 60;
    endMin(k)   = segments3(k).tEnd / 60;
    durMin(k)   = segments3(k).durationSec / 60;
end

segmentTable3 = table(stateLabel, startMin, endMin, durMin, ...
    'VariableNames', {'State','Start_min','End_min','Duration_min'});

disp(segmentTable3);
writetable(segmentTable3, 'audience_experience_timeline_3state.csv');