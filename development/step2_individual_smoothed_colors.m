%% STEP 2C: Individual smoothed trends with unique colours (exploratory)

figure('Color','w'); hold on; grid on;

nP = size(H_smooth,2);
cmap = lines(nP);   % MATLAB’s default qualitative colormap

for p = 1:nP
    plot(tCommon, H_smooth(:,p), ...
        'Color', cmap(p,:), ...
        'LineWidth', 1);
end

% Group mean on top
plot(tCommon, meanSmooth, 'k', 'LineWidth', 3);

xlabel('Time (s)');
ylabel('Heart rate (bpm)');
title('Smoothed individual trends (unique colours)');
