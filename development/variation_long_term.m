%% Variation around the long-term trend (residual SD)
% Assumes you already computed meanLong (Nx1)
res = H - meanLong;                         % residuals: each participant minus trend
sd_res = std(res, 0, 2, 'omitnan');
sd_res_s = smoothdata(sd_res, 'movmean', 301);

figure('Color','w'); hold on; grid on;
plot(tCommon, sd_res, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
plot(tCommon, sd_res_s, 'k', 'LineWidth', 2.5);

xlabel('Time (s)');
ylabel('SD of residuals (bpm)');
title('Variation around the long-term trend');
legend({'Residual SD (raw)','Residual SD (smoothed ~5 min)'}, 'Location','best');
