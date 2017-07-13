%Test FmaxGND function
%AUTHOR: Eric Fields
%VERSION DATE: 13 July 2017

%Load GRP
if ispc()
    load('R:\Public\GK_lab\Eric\FMUT_development\FMUT\testing\data\Disflu_GroupLevel.GRP', '-mat');
elseif ismac()
    load('/Volumes/as-rsch-ncl1$/Public/GK_lab/Eric/FMUT_development/FMUT/testing/data/Disflu_GroupLevel.GRP', '-mat')
end

%Define some general variables
time_wind = [300, 500];
include_chans = {'Fz', 'Cz', 'Pz'};
[~, start_sample] = min(abs( GRP.time_pts - time_wind(1) ));
[~, end_sample  ] = min(abs( GRP.time_pts - time_wind(2) ));
electrodes = NaN(1, length(include_chans));
for c = 1:length(include_chans)
    electrodes(c) = find(strcmp(include_chans(c), {GRP.chanlocs.labels}));
end

%% Exact interaction

GRP = FmaxGRP(GRP, ... 
              'bins',             4:7, ... 
              'bg_factor_name',   'reliability', ...
              'wg_factor_names',  {'expectedness', 'disfluency'}, ...
              'wg_factor_levels', [2, 2], ... 
              'time_wind',        time_wind, ...
              'include_chans',    include_chans, ... 
              'n_perm',           10, ...
              'alpha',            0.05, ... 
              'output_file',      fullfile('outputs', 'FmaxGRP_test.xlsx'), ...
              'save_GRP',         'no');
