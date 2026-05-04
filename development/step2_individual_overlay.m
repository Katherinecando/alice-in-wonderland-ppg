%% STEP 2A: Individual responses with group trend
% H = time x participants

figure('Color','w'); hold on; grid on;

% Plot individuals (light grey)
plot(tCommon, H, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.7);

% Plot smoothed group mean
plot(tCommon, meanSmooth, 'k', 'LineWidth', 3);

xlabel('Time (s)');
ylabel('Heart rate (bpm)');
title('Individual heart rate responses with group trend');

legend({'Individuals','Group trend'}, 'Location','best');
