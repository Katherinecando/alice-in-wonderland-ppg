restoredefaultpath; rehash toolboxcache; clc;

rrestFolder = "C:\Users\katyl\OneDrive - City, University of London\year 3\individual project\RRest-master\RRest-master\RRest_v3.0";

addpath(genpath(rrestFolder));
rehash toolboxcache;

disp(which("RRest","-all"));
disp(which("setup_universal_params","-all"));