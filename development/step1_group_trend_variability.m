%% LONG-TERM TREND 

fs = fsTarget;      % 1 Hz
win_long_min = 8;   % try 5–10 minutes (start with 8)
win_long = round(win_long_min * 60 * fs);

if mod(win_long,2)==0
    win_long = win_long + 1;
end

meanLong = smoothdata(meanHR, 'movmean', win_long, 'omitnan');

%% STEP 1: Group-level trend and variability
% Uses existing variables from workspace:
% tCommon, meanHR, stdHR, meanSmooth, stdSmooth

t = tCommon(:);

figure('Color','w'); hold on; grid on;

% ---- Raw SD band
x = [t; flipud(t)];
y_raw = [meanHR - stdHR; flipud(meanHR + stdHR)];
f1 = fill(x, y_raw, [0.75 0.85 1], 'EdgeColor','none');
f1.FaceAlpha = 0.35;

% ---- Raw mean
plot(t, meanHR, 'Color', [0 0.45 0.74], 'LineWidth', 1);

% ---- Smoothed SD band
y_s = [meanSmooth - stdSmooth; flipud(meanSmooth + stdSmooth)];
f2 = fill(x, y_s, [0.3 0.6 1], 'EdgeColor','none');
f2.FaceAlpha = 0.25;

% ---- Smoothed mean (trend)
plot(t, meanSmooth, 'Color', [0 0 0.2], 'LineWidth', 2.8);


xlabel('Time (s)');
ylabel('Heart rate (bpm)');
title('Group mean heart rate: trend vs variability');
legend({'Raw \pm SD','Raw mean','Smoothed \pm SD','Smoothed mean'}, ...
       'Location','best');

figure('Color','w'); hold on; grid on;

% Raw mean
plot(tCommon, meanHR, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8);

% Short-term smooth (existing)
plot(tCommon, meanSmooth, 'Color', [0 0.45 0.74], 'LineWidth', 1.5);

% Long-term trend
plot(tCommon, meanLong, 'k', 'LineWidth', 3.5);

xlabel('Time (s)');
ylabel('Heart rate (bpm)');
title(sprintf('Audience heart rate across time scales (long window = %d min)', win_long_min));

legend({'Raw mean','Short-term trend (~1 min)','Long-term trend (~8 min)'}, ...
       'Location','best');

