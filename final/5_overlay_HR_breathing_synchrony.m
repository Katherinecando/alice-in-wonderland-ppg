%% overlay_HR_breathing_synchrony.m

% Overlays pulse rate synchrony and respiratory synchrony on a single timeline.

% Computes cross-correlation between the two synchrony signals.

%

% REQUIRES in workspace (run peaks_final_analysis.m first):

%   t_mid   â time vector for HR synchrony windows (seconds)

%   sync_s  â smoothed HR synchrony timecourse

%

% REQUIRES on disk (in working directory):

%   breathing_synchrony_results.mat  â output from plot_rr_overlay.m



B = load('breathing_synchrony_results.mat');

outB = B.out;



t_sync_b = outB.t_sync(:);

breath_sync = outB.sync_smooth(:);



% Interpolate HR synchrony onto breathing synchrony timestamps

hr_on_b = interp1(t_mid, sync_s, t_sync_b, 'linear', NaN);



figure('Color','w'); hold on; grid on;

plot(t_sync_b/60, breath_sync, 'LineWidth',2);

plot(t_sync_b/60, hr_on_b, 'LineWidth',2);

xlabel('Time (min)');

ylabel('Synchrony (mean pairwise corr)');

title('Breathing vs HR synchrony (same window/step)');

legend({'Breathing','HR'}, 'Location','best');

ylim([-0.2 1]);



% Check around 65 min

target_min = 65;

[~, idx65] = min(abs(t_sync_b/60 - target_min));

xline(t_sync_b(idx65)/60, '--', '65 min');



fprintf("\nAt %.2f min:\n", t_sync_b(idx65)/60);

fprintf("  Breathing synchrony = %.3f\n", breath_sync(idx65));

fprintf("  HR synchrony        = %.3f\n", hr_on_b(idx65));



% Correlation between breathing and HR synchrony

common_idx = ~isnan(hr_on_b) & ~isnan(breath_sync);

r_system = corr(breath_sync(common_idx), hr_on_b(common_idx));



fprintf('\nBreathingâHR synchrony correlation = %.3f\n', r_system);



[xc,lags] = xcorr(breath_sync(common_idx), hr_on_b(common_idx), 50, 'coeff');

[~,imax] = max(xc);

lag_sec = lags(imax);



fprintf('Max cross-corr at lag = %d seconds\n', lag_sec);



fprintf('\nMean breathing synchrony = %.3f\n', mean(breath_sync,'omitnan'));

fprintf('Mean HR synchrony        = %.3f\n', mean(hr_on_b,'omitnan'));
