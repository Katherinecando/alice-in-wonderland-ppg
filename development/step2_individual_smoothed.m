%% STEP 2B: Smoothed individual trends

fs = fsTarget;        % 1 Hz
win_sec = 60;
win = round(win_sec * fs);
if mod(win,2)==0, win = win+1; end

H_smooth = smoothdata(H, 1, 'movmean', win, 'omitnan');

figure('Color','w'); hold on; grid on;
plot(tCommon, H_smooth, 'Color', [0.8 0.8 0.8], 'LineWidth', 1);
plot(tCommon, meanSmooth, 'k', 'LineWidth', 3);

xlabel('Time (s)');
ylabel('Heart rate (bpm)');
title('Smoothed individual trends with group mean');
