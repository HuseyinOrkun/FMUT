%Test FMUT ANOVA calculations against MATLAB ANOVA calculations
%
%Author: Eric Fields
%Version Date: 12 June 2020

%% RB DESIGNS PARAMETRIC ANOVA

%Simulation parameters
n_electrodes = 32;
n_time_pts = 40;
n_subs = 16;

%Designs to test
anova_designs = {5, ...
                 [2, 2], ...
                 [4, 2], ...
                 [3, 4], ...
                 [2, 2, 2], ...
                 [3, 2, 2], ...
                 [2, 3, 2], ...
                 [2, 2, 3], ...
                 [3, 3, 2], ...
                 [2, 3, 3], ...
                 [4, 2, 5], ...
                 [2, 2, 2, 2], ...
                 [4, 3, 5, 2], ...
                 [2, 2, 3, 2], ...
                 [3, 4, 2, 3]};

sphericity_corrections = {'none', 'GG', 'HF', 'LB'};
             
for m = 1:length(anova_designs)
    
    wg_design = anova_designs{m};
    
    %Choose random sphericity correction
    if sum(wg_design>2) < 2
        sphericity_corr = sphericity_corrections{randi(numel(sphericity_corrections))};
    else
        sphericity_corr = 'none';
    end

    %Simulate data
    data = randn([n_electrodes, n_time_pts, wg_design, n_subs]);
    
    %Choose random electrode and time point for testing
    e = randi([1,n_electrodes]);
    t = randi([1,n_time_pts]);

    %Generic variable names
    var_names = cell(1, length(wg_design));
    for i = 1:length(wg_design)
        var_names{i} = char(64+i);
    end
    [effects, effects_labels] = get_effects(var_names);

    %MATLAB ANOVA
    oneway_data = reshape(data, n_electrodes, n_time_pts, [], n_subs);
    rm_data = squeeze(oneway_data(e,t,:,:))';
    [rm, ranovatbl] = matlab_ANOVA(rm_data, wg_design, var_names);

    %Calculate all effects in model and compare to MATLAB ANOVA
    for i = 1:length(effects)

        %FMUT calculations
        dims = effects{i}+2;
        test_results = calc_param_ANOVA(data, [], dims, 0.05, 'none', sphericity_corr);

        %Check results for a random electrode and time point
        rm_table_row = ['(Intercept):' strrep(effects_labels{i}, 'X', ':')];
        if strcmp(sphericity_corr, 'none')
            suff = '';
        else
            suff = sphericity_corr;
        end
        assert(test_results.p(e,t) - ranovatbl{rm_table_row, ['pValue' suff]} < 1e-9);

    end
    
end


function [rm, ranovatbl] = matlab_ANOVA(rm_data, wg_design, var_names)
%Calculate ANOVA with MATLAB's stats module
%
%INPUTS
% rm_data   - subjects x variables array
% wg_design - number of levels of each factor from slowest to fastest
%             moving in rm_data columns
%
%OUTPUTS
% rm        - RepeatedMeasuresModel object
% ranovatbl - Results of repeated measures anova, returned as a table
    
    n_subs = size(rm_data, 1);
    
    %Within subject design table
    withindesign = cell2table(cell(prod(wg_design), length(wg_design)), 'VariableNames', var_names);
    row = 0;
    if length(wg_design) ==1
        for a = 1:wg_design(1)
            row = row + 1;
            withindesign{row, 'A'} = {sprintf('A%d', a)};
        end
    elseif length(wg_design) == 2
        for b = 1:wg_design(2)
            for a = 1:wg_design(1)
                row = row + 1;
                withindesign{row, 'A'} = {sprintf('A%d', a)};
                withindesign{row, 'B'} = {sprintf('B%d', b)};
            end
        end
    elseif length(wg_design) == 3
        for c = 1:wg_design(3)
            for b = 1:wg_design(2)
                for a = 1:wg_design(1)
                    row = row + 1;
                    withindesign{row, 'A'} = {sprintf('A%d', a)};
                    withindesign{row, 'B'} = {sprintf('B%d', b)};
                    withindesign{row, 'C'} = {sprintf('C%d', c)};
                end
            end
        end
    elseif length(wg_design) == 4
        for d = 1:wg_design(4)
            for c = 1:wg_design(3)
                for b = 1:wg_design(2)
                    for a = 1:wg_design(1)
                        row = row + 1;
                        withindesign{row, 'A'} = {sprintf('A%d', a)};
                        withindesign{row, 'B'} = {sprintf('B%d', b)};
                        withindesign{row, 'C'} = {sprintf('C%d', c)};
                        withindesign{row, 'D'} = {sprintf('D%d', d)};
                    end
                end
            end
        end
    end

    %Column names
    col_names = cell(1, prod(wg_design)+1);
    col_names{1} = 'sub';
    for row = 1:size(withindesign, 1)
        col_names{row+1} = strjoin(withindesign{row, :}, '');
    end

    %Create ANOVA table
    T = [cell2table(cellfun(@(x) sprintf('S%d', x), num2cell(1:n_subs)', 'UniformOutput', false), 'VariableNames', {'sub'}) ...
         array2table(rm_data)];
    T.Properties.VariableNames = col_names;

    %MATLAB repeated measure ANOVA
    model_formula = sprintf('%s-%s~1', T.Properties.VariableNames{2}, T.Properties.VariableNames{end});
    rm = fitrm(T, model_formula, 'WithinDesign', withindesign);
    [~, effects_labels] = get_effects(var_names);
    reg_design = strrep(strjoin(effects_labels, '+'), 'X', '*');
    ranovatbl = ranova(rm, 'WithinModel', reg_design);
    
end
