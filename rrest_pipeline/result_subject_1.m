up = setup_universal_params('theatre');
subj = up.paramSet.subj_list(1);

rrPath = [up.paths.data_save_folder, num2str(subj), up.paths.filenames.rrEsts, '.mat'];
S = load(rrPath);

rr_raw  = S.ppg1_flt_BFi_WCH;
rr_fuse = S.ppg1_flt_BFi_WCH_TFu;

figure('Color','w');
plot(rr_raw.t/60, rr_raw.v, 'DisplayName','WCH'); hold on;
plot(rr_fuse.t/60, rr_fuse.v, 'DisplayName','WCH + TFu');
grid on; xlabel('Time (min)'); ylabel('Breaths/min');
legend; title(sprintf('Subject %d RR', subj));