%% Variation over time: SD (raw + smoothed)
t = tCommon(:);

sd_t = std(H, 0, 2, 'omitnan');                 % SD at each time point
sd_t_s = smoothdata(sd_t, 'movmean', 301);      % ~5 min at 1 Hz (change if you want)

figure('Color','w'); hold on; grid on;
plot(t, sd_t, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
plot(t, sd_t_s, 'k', 'LineWidth', 2.5);

xlabel('Time (s)');
ylabel('SD of HR across participants (bpm)');
title('Audience variation over time (SD)');
legend({'SD (raw)','SD (smoothed ~5 min)'}, 'Location','best');
