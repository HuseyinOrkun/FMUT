%Calculate F-observed and the empirical F-distribution for a
%within-subjects ANOVA with up to three factors. This function calculates a
%one-way ANOVA, two-way interaction, and three-wa interaction. It is
%assumed data is properly reduced before being sent to this function (see
%reduce_data.m).
%
%REQUIRED INPUTS
% data          - An electrode x time points x conditions x subjects array of ERP
%                 data. Array will vary in number of dimensions based on how many
%                 factors there are
% n_perm        - Number of permutations to conduct
%
%OUTPUT
% Fvals         - F-values at each time point and electrode for each
%                 permutation. The first permutation is F-observed.
% df_effect     - numerator degrees of freedom
% df_res        - denominator degrees of freedom
%
%
%VERSION DATE: 22 June 2017
%AUTHOR: Eric Fields, Tufts University (Eric.Fields@tufts.edu)
%
%NOTE: This function is provided "as is" and any express or implied warranties 
%are disclaimed. 
%This is a beta version of this software. It needs additional testing 
%and SHOULD NOT be considered error free.

%Copyright (c) 2017, Eric Fields
%All rights reserved.
%This code is free and open source software made available under the 3-clause BSD license.

%%%%%%%%%%%%%%%%%%%  REVISION LOG   %%%%%%%%%%%%%%%%%%%
% 6/22/17   - First version. Code re-organized from other functions.

function [F_dist, df_effect, df_res] = perm_rbANOVA(data, n_perm)

    %Calculate appropriate ANOVA
    if ndims(data) == 4
        [F_dist, df_effect, df_res] = oneway(data, n_perm);
    elseif ndims(data) == 5
        [F_dist, df_effect, df_res] = twoway_approx_int(data, n_perm);
    elseif ndims(data) == 6
        [F_dist, df_effect, df_res] = threeway_approx_int(data, n_perm);
    end

end

function [F_dist, df_effect, df_res] = oneway(data, n_perm)
%Permutation one-way ANOVA
% 1. Randomly permute conditions within each subject across all time
%    points and electrodes
% 2. For each permutation, perform one-way ANOVA across time points and
%    and electrodes and  save the largest F from each permutation (Fmax)
% 3. Compare Fobs for unpermuted data to distribution of Fmax to reject or 
%    fail to reject null for each time point an electrode

    global VERBLEVEL

    %Make sure there's only one factor
    assert(ndims(data) == 4);
    
    %Some useful numbers
    [n_electrodes, n_time_pts, n_conds, n_subs] = size(data);
    
    %Calculate degrees of freedom
    %(Always the same, so no point calculating in the loop)
    dfA   = n_conds - 1;
    dfBL  = n_subs - 1;
    dfRES = dfA * dfBL;
    
    %Perform n_perm permutations
    F_dist = NaN(n_perm, n_electrodes, n_time_pts);
    for i = 1:n_perm
        
        %Permute the data
        if i ==1
            perm_data = data;
        else
            for n = 1:n_subs
                perm_data(:, :, :, n) = data(:, :, randperm(size(data, 3)), n);
            end
        end
        
        %Calculate sums of squares
        SSyint = (sum(sum(perm_data, 3), 4).^2) / (n_conds * n_subs);
       %SSTO   = sum(sum(perm_data.^2, 3), 4) - SSyint;
        SSA    = (sum(sum(perm_data, 4).^2, 3) / n_subs) - SSyint;
        SSBL   = (sum(sum(perm_data, 3).^2, 4) / n_conds) - SSyint;
        SSRES  = sum(sum(perm_data.^2, 3), 4) - SSA - SSBL - SSyint;
        %assert(all(abs(SSTO(:) - (SSA(:) + SSBL(:) + SSRES(:))) < 1e-9));
        
        %Calculate F
        SSA(SSA < 1e-12) = 0; %Eliminates large F values that result from floating point error 
        F_dist(i, :, :) = (SSA/dfA) ./ (SSRES/dfRES);
        
        if VERBLEVEL
            if i == 1
                fprintf('Permutations completed: ')
            elseif i == n_perm
                fprintf('%d\n', i)
            elseif ~mod(i, 1000)
                fprintf('%d, ', i)
            end
        end
        
    end
    
    %degrees of freedom
    df_effect = dfA;
    df_res    = dfRES;
    
end


function [F_dist, df_effect, df_res] = twoway_approx_int(data, n_perm)
%Use permutation of residuals method to calculate an approximate test of
%an interaction effect in a factorial design
% 1. Subtract main effects within each subject from all data points to obtain permutation residuals
% 2. Randomly permute all conditions within each subject across all time
%    points and electrodes
% 3. For each permutation, perform factorial ANOVA and save the largest F for the 
%    interaction effect across all time points and electrodes (Fmax)
% 4. Compare Fobs for unpermuted data to distribution of Fmax 
%    to reject or fail to reject null for each time point

    global VERBLEVEL

    %Make sure we're dealing with a two-way design
    assert(ndims(data) == 5);

    %Some useful numbers
    [n_electrodes, n_time_pts, n_conds_A, n_conds_B, n_subs] = size(data);

    %Subtract main effects within each subject so that the data is 
    %exchangeable under the null hypothesis for the interaction
    int_res = get_int_res(data);
    
    %Calculate degrees of freedom
    %(Always the same, so no point calculating in the loop)
    dfBL     = n_subs - 1;
    dfA      = n_conds_A - 1;
    %dfAerr   = dfA * dfBL;
    dfB      = n_conds_B - 1;
    %dfBerr   = dfB * dfBL;
    dfAxB    = dfA * dfB;
    dfAxBerr = dfAxB * dfBL;
    %dfRES    = (num_subs - 1) * (num_conds_A * num_conds_B - 1);

    %Re-arrange data for permutation
    flat_data = reshape(int_res, [n_electrodes, n_time_pts, n_conds_A*n_conds_B, n_subs]);

    %Perform n_perm permutations
    F_dist = NaN(n_perm, n_electrodes, n_time_pts);
    flat_perm_data = NaN(size(flat_data));
    for i = 1:n_perm
        %Permute the data
        if i == 1
            perm_data = int_res;
        else
            for s = 1:n_subs
                flat_perm_data(:, :, :, s) = flat_data(:, :, randperm(size(flat_data, 3)), s);
            end
            perm_data = reshape(flat_perm_data, n_electrodes, n_time_pts, n_conds_A, n_conds_B, n_subs);
        end
        %Calculate F at each time point and electrode combination
        
        %Calculate sums of squares
        SSyint   = (sum(sum(sum(perm_data, 3), 4), 5).^2)/(n_conds_A*n_conds_B*n_subs);
        %SSTO     = sum(sum(sum(perm_data.^2, 3), 4), 5) - SSyint;
        SSA      = sum(sum(sum(perm_data, 4), 5).^2, 3)/(n_conds_B*n_subs) - SSyint;
        SSB      = sum(sum(sum(perm_data, 3), 5).^2, 4)/(n_conds_A*n_subs) - SSyint;
        SSBL     = sum(sum(sum(perm_data, 3), 4).^2, 5)/(n_conds_A*n_conds_B) - SSyint;
        SSAxB    = sum(sum(sum(perm_data, 5).^2, 3), 4)/n_subs - SSA - SSB -SSyint;
        SSAxBL   = sum(sum(sum(perm_data, 4).^2, 3), 5)/n_conds_B - SSA - SSBL - SSyint;
        SSBxBL   = sum(sum(sum(perm_data, 3).^2, 4), 5)/n_conds_A - SSB - SSBL - SSyint;
        SSAxBxBL = sum(sum(sum(perm_data.^2, 3), 4), 5) - SSA - SSB - SSBL - SSAxB - SSAxBL - SSBxBL - SSyint;
        %SSRES    = sum(sum(sum(perm_data.^2, 3), 4), 5) - SSA - SSB - SSBL - SSAxB - SSyint;

        %Doublechecking that the numbers match up
        %assert(all(SSRES - (SSAxBL + SSBxBL + SSAxBxBL) < 1e-9)); %SSRES is equal to its three subcomponents
        %assert(all(SSTO  - (SSRES + SSBL + SSA + SSB + SSAxB) < 1e-9)); %sums of squares add up

        %Calculate F
        SSAxB(SSAxB < 1e-12) = 0; %Eliminates large F values that result from floating point error 
        F_dist(i, :, :) = (SSAxB/dfAxB) ./ (SSAxBxBL/dfAxBerr);
        
        if VERBLEVEL
            if i == 1
                fprintf('Permutations completed: ')
            elseif i == n_perm
                fprintf('%d\n', i)
            elseif ~mod(i, 1000)
                fprintf('%d, ', i)
            end
        end

    end

    %degrees of freedom
    df_effect = dfAxB;
    df_res    = dfAxBerr;

end


function [F_dist, df_effect, df_res] = threeway_approx_int(data, n_perm)
%Use permutation of residuals method to calculate an approximate test of
%an interaction effect in a factorial design
% 1. Subtract main effects within each subject from all data points to obtain 
%    interaction residuals
% 2. Subtract two-way interaction effect form residuals calculated above to
%    obtain three-way interaction residuals
% 3. Randomly permute all conditions within each subject across all time
%    points and electrodes
% 4. For each permutation, perform factorial ANOVA and save the largest F for the 
%    three-way interaction effect across all time points and electrodes (Fmax)
% 5. Compare Fobs for the unpermuted data to distribution of Fmax to reject 
%    or fail to reject null for each time point and electrode
    
    global VERBLEVEL

    %Make sure we're dealing with a two-way design
    assert(ndims(data) == 6);

    %Some useful numbers
    [n_electrodes, n_time_pts, n_conds_A, n_conds_B, n_conds_C, n_subs] = size(data);

    %Subtract main effects then two-way effects within each subject so that 
    %the data is exchangeable under the null hypothesis for the three-way
    %interaction
    int_res = get_int_res(data);
    
    %Calculate degrees of freedom
    %(Always the same, so no point calculating in the loop)
    dfBL       = n_subs - 1;
    dfA        = n_conds_A - 1;
   %dfAerr     = dfA * dfBL;
    dfB        = n_conds_B - 1;
   %dfBerr     = dfB * dfBL;
    dfC        = n_conds_C - 1;
   %dfCerr     = dfC * dfBL;
   %dfAxB      = dfA * dfB;
   %dfAxBerr   = dfAxB * dfBL;
   %dfAxC      = dfA * dfC;
   %dfAxCerr   = dfAxC * dfBL;
   %dfBxC      = dfB * dfC;
   %dfBxCerr   = dfBxC * dfBL;
    dfAxBxC    = dfA * dfB * dfC;
    dfAxBxCerr = dfAxBxC * dfBL;
   %dfRES      = (n_subs - 1) * (n_conds_A * n_conds_B * n_conds_C - 1);

    %Re-arrange data for permutation
    flat_data = reshape(int_res, [n_electrodes, n_time_pts, n_conds_A*n_conds_B*n_conds_C, n_subs]);

    %Perform n_perm permutations
    F_dist = NaN(n_perm, n_electrodes, n_time_pts);
    flat_perm_data = NaN(size(flat_data));
    for i = 1:n_perm

        %Permute the data
        if i == 1
            perm_data = int_res;
        else
            for s = 1:n_subs
                flat_perm_data(:, :, :, s) = flat_data(:, :, randperm(size(flat_data, 3)), s);
            end
            perm_data = reshape(flat_perm_data, size(int_res));
        end
        
        %Calculate F at each time point and electrode combination

        %Calculate sums of squares
        SSyint     = (sum(sum(sum(sum(perm_data, 3), 4), 5), 6).^2)/(n_conds_A*n_conds_B*n_conds_C*n_subs);
       %SSTO       = sum(sum(sum(sum(perm_data.^2, 3), 4), 5), 6) - SSyint;
        SSA        = sum(sum(sum(sum(perm_data, 4), 5), 6).^2, 3)/(n_conds_B*n_conds_C*n_subs) - SSyint;
        SSB        = sum(sum(sum(sum(perm_data, 3), 5), 6).^2, 4)/(n_conds_A*n_conds_C*n_subs) - SSyint;
        SSC        = sum(sum(sum(sum(perm_data, 3), 4), 6).^2, 5)/(n_conds_A*n_conds_B*n_subs) - SSyint;
        SSBL       = sum(sum(sum(sum(perm_data, 3), 4), 5).^2, 6)/(n_conds_A*n_conds_B*n_conds_C) - SSyint;
        SSAxB      = sum(sum(sum(sum(perm_data, 5), 6).^2, 3), 4)/(n_conds_C*n_subs) - SSA - SSB -SSyint;
        SSAxC      = sum(sum(sum(sum(perm_data, 4), 6).^2, 3), 5)/(n_conds_B*n_subs) - SSA - SSC -SSyint;
        SSBxC      = sum(sum(sum(sum(perm_data, 3), 6).^2, 4), 5)/(n_conds_A*n_subs) - SSB - SSC -SSyint;
        SSAxBxC    = sum(sum(sum(sum(perm_data, 6).^2, 3), 4), 5)/n_subs - SSA - SSB - SSC - SSAxB - SSAxC - SSBxC - SSyint;
        SSAxBL     = sum(sum(sum(sum(perm_data, 4), 5).^2, 3), 6)/(n_conds_B*n_conds_C) - SSA - SSBL - SSyint;
        SSBxBL     = sum(sum(sum(sum(perm_data, 3), 5).^2, 4), 6)/(n_conds_A*n_conds_C) - SSB - SSBL - SSyint;
        SSCxBL     = sum(sum(sum(sum(perm_data, 3), 4).^2, 5), 6)/(n_conds_A*n_conds_B) - SSC - SSBL - SSyint;
        SSAxBxBL   = sum(sum(sum(sum(perm_data, 5).^2, 3), 4), 6)/n_conds_C - SSA - SSB - SSBL - SSAxB - SSAxBL - SSBxBL - SSyint;
        SSAxCxBL   = sum(sum(sum(sum(perm_data, 4).^2, 3), 5), 6)/n_conds_B - SSA - SSC - SSBL - SSAxC - SSAxBL - SSCxBL - SSyint;
        SSBxCxBL   = sum(sum(sum(sum(perm_data, 3).^2, 4), 5), 6)/n_conds_A - SSB - SSC - SSBL - SSBxC - SSBxBL - SSCxBL - SSyint;
        SSAxBxCxBL = sum(sum(sum(sum(perm_data.^2, 3), 4), 5), 6) - SSA - SSB - SSC - SSBL - SSAxB - SSAxC - SSBxC - SSAxBL - SSBxBL - SSCxBL - SSAxBxC - SSAxBxBL - SSAxCxBL - SSBxCxBL - SSyint;
       %SSRES      = sum(sum(sum(sum(perm_data.^2, 3), 4), 5), 6) - SSA - SSB - SSC - SSBL - SSAxB - SSAxC - SSBxC - SSAxBxC - SSyint;

        %Doublechecking that the numbers match up
        %assert(all(SSRES - (SSAxBL + SSBxBL + SSCxBL + SSAxBxBL + SSAxCxBL + SSBxCxBL + SSAxBxCxBL) < 1e-9)); %SSRES is equal to its three subcomponents
        %assert(all(SSTO  - (SSRES + SSBL + SSA + SSB + SSC + SSAxB + SSAxC + SSBxC + SSAxBxC) < 1e-9)); %sums of squares add up

        SSAxBxC(SSAxBxC < 1e-12) = 0; %Eliminates large F values that result from floating point error 
        F_dist(i, :, :) = (SSAxBxC/dfAxBxC) ./ (SSAxBxCxBL/dfAxBxCerr);
        
        if VERBLEVEL
            if i == 1
                fprintf('Permutations completed: ')
            elseif i == n_perm
                fprintf('%d\n', i)
            elseif ~mod(i, 1000)
                fprintf('%d, ', i)
            end
        end

    end
    
    %degrees of freedom
    df_effect = dfAxBxC;
    df_res    = dfAxBxCerr;

end