%% Per-participant plots: individual HR + smoothed individual + group mean
% Uses: tCommon (Nx1), H (NxP), meanSmooth (Nx1), fsTarget

t = tCommon(:);
P = size(H,2);

% smoothing for individual traces
win_sec = 60;  % same as before (change if you want)
win = round(win_sec * fsTarget);
if mod(win,2)==0, win = win+1; end

H_s = smoothdata(H, 1, 'movmean', win, 'omitnan');

outDir = 'per_participant_plots';
if ~exist(outDir,'dir'), mkdir(outDir); end

for p = 1:P
    figure('Color','w'); hold on; grid on;

    % individual raw (light)
    plot(t, H(:,p), 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);

    % individual smoothed (blue)
    plot(t, H_s(:,p), 'Color', [0 0.45 0.74], 'LineWidth', 1.8);

    % group mean smoothed (black)
    plot(t, meanSmooth, 'k', 'LineWidth', 2.8);

    xlabel('Time (s)');
    ylabel('Heart rate (bpm)');
    title(sprintf('Participant %d: individual vs group trend', p));
    legend({'Individual raw','Individual smoothed','Group trend (smoothed)'}, ...
        'Location','best');

    % save
    fname = fullfile(outDir, sprintf('P%02d_individual_vs_group.png', p));
    exportgraphics(gcf, fname, 'Resolution', 300);
    close(gcf);
end

disp(['Saved plots to folder: ' outDir]);
