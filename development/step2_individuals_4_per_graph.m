%% Small multiples: 4 participants per figure (2x2)
t = tCommon(:);
P = size(H,2);

win_sec = 60;
win = round(win_sec * fsTarget);
if mod(win,2)==0, win = win+1; end
H_s = smoothdata(H, 1, 'movmean', win, 'omitnan');

outDir = 'small_multiples_2x2';
if ~exist(outDir,'dir'), mkdir(outDir); end

perFig = 4;
nFigs = ceil(P/perFig);

for f = 1:nFigs
    figure('Color','w');
    tiledlayout(2,2, 'Padding','compact', 'TileSpacing','compact');

    idxStart = (f-1)*perFig + 1;
    idxEnd   = min(f*perFig, P);
    idx = idxStart:idxEnd;

    for k = 1:numel(idx)
        p = idx(k);
        nexttile; hold on; grid on;

        plot(t, H(:,p), 'Color', [0.8 0.8 0.8], 'LineWidth', 0.7);
        plot(t, H_s(:,p), 'Color', [0 0.45 0.74], 'LineWidth', 1.3);
        plot(t, meanSmooth, 'k', 'LineWidth', 2);

        title(sprintf('P%02d', p));
        xlabel('Time (s)');
        ylabel('PR (bpm)');
    end

    sgtitle(sprintf('Individuals vs group trend (plots %d–%d of %d)', ...
        idxStart, idxEnd, P));

    fname = fullfile(outDir, sprintf('small_multiples_%02d.png', f));
    exportgraphics(gcf, fname, 'Resolution', 300);
end

disp(['Saved small-multiples figures to folder: ' outDir]);
