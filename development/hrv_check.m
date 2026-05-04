p = 1; % or any participant index
nanRMSSD = mean(isnan(RMSSD_mat(:,p))) * 100;
nanSDNN  = mean(isnan(SDNN_mat(:,p))) * 100;
fprintf("Participant %d: RMSSD NaN=%.1f%% | SDNN NaN=%.1f%%\n", p, nanRMSSD, nanSDNN);

