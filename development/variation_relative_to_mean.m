%% Variation over time: CV = SD/Mean
mu_t = mean(H, 2, 'omitnan');
sd_t = std(H, 0, 2, 'omitnan');

cv_t = sd_t ./ mu_t;                       % unitless
cv_t_s = smoothdata(cv_t, 'movmean', 301);

figure('Color','w'); hold on; grid on;
plot(tCommon, cv_t, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
plot(tCommon, cv_t_s, 'k', 'LineWidth', 2.5);

xlabel('Time (s)');
ylabel('CV (SD / mean)');
title('Relative audience variation over time (CV)');
legend({'CV (raw)','CV (smoothed ~5 min)'}, 'Location','best');
