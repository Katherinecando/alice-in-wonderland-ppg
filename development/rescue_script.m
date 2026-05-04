% restoredefaultpath; rehash toolboxcache; clear functions; clc;
% 
% rrestFolder = 'C:\Users\katyl\OneDrive - City, University of London\year 3\individual project\RRest-master\RRest-master\RRest_v3.0\Algorithms';
% addpath(genpath(rrestFolder));
% rehash toolboxcache;
% 
% disp('RRest path:');
% disp(which('RRest','-all'));
% 
% disp('setup_universal_params path:');
% disp(which('setup_universal_params','-all'));
% 
% root_folder = 'C:\Users\katyl\OneDrive - City, University of London\year 3\individual project\RRest_data\';
% dst = fullfile(root_folder, 'theatre', 'Analysis_files', 'Data_for_Analysis', 'theatre_data.mat');
% 
% disp('Checking theatre_data.mat:');
% disp(dst);
% disp(exist(dst,'file'));
% if exist(dst,'file')
%     whos('-file', dst)
% end

restoredefaultpath; rehash toolboxcache; clear; clc;

rrestFolder = 'C:\Users\katyl\OneDrive - City, University of London\year 3\individual project\RRest-master\RRest-master\RRest_v3.0\Algorithms';
addpath(genpath(rrestFolder));

rehash toolboxcache;

disp('Check paths:')
which RRest
which setup_universal_params