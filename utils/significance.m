function [pval,dist] = significance(estimate,stat,varargin)
%SIGNIFICANCE Significance testing for linear-dependence measures.
%   PVAL = SIGNIFICANCE(ESTIMATE,STATS) returns PVAL, the p-value for the
%   scalar ESTIMATE and statistics STATS using our exact hypothesis tests.
%   Both ESTIMATE and STATS should be computed from either the function <a href="matlab:help mvgc">mvgc</a>
%   <a href="matlab:help mvmi">mvmi</a> in this package.
%
%   [...] = SIGNIFICANCE(...,'PARAM1',VAL1,'PARAM2',VAL2,...) specifies
%   additional parameters and their values.  Valid parameters are the
%   following:
%
%         Parameter                   Value
%          'test'                     'exact' (the default) uses a
%                                     Bartlett-corrected Student's t-test,
%                                     'standard' uses the typical two-tail
%                                     t-test.
%          'surrogates'               Numeric denoting the number of
%                                     surrogates used in generating the
%                                     exact null distributions.
%          'varianceEstimator'        'bartlett' (default) uses Bartlett's
%                                     formula assuming no
%                                     cross-correlations, 'roy' makes no
%                                     assumptions about cross-correlations.
%                                     (N.B. this needs a measure to be run
%                                     with param 'multivariateBartlett' set
%                                     to true.)
%
%   See also <a href="matlab:help mvmi">mvmi</a>, <a href="matlab:help mvgc">mvgc</a>, <a href="matlab:help pcd">pcd</a>

% ------------------------------------------------------------------------------
% Copyright (C) 2020, Oliver M. Cliff <oliver.m.cliff@gmail.com>,
%
% If you use this code for your research, please cite the following paper:
%
% Oliver M. Cliff, Leonardo Novelli, Ben D Fulcher, James M. Shine,
% Joseph T. Lizier, "Exact Inference of Linear Dependence for Multiple
% Autocorrelated Time Series," arXiv preprint arXiv:2003.03887 (2020).
%
% This function is free software: you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free Software
% Foundation, either version 3 of the License, or (at your option) any later
% version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along with
% this program. If not, see <http://www.gnu.org/licenses/>.
% ------------------------------------------------------------------------------

parser = inputParser;

addRequired(parser,'estimate',@isnumeric);
addRequired(parser,'stat',@isstruct);

parser = parseParameters(parser,estimate,stat,varargin{:});

S = parser.Results.surrogates;


if strcmp(parser.Results.test,'asymptotic') || strcmp(parser.Results.test,'standard')
  
  if stat.cmi
    % LR statistic is 2 * nested log ratio * numer of samples (removed the
    % order of autoregression)
    estimate = 2*stat.to_cmi(estimate);

    % Get p-value from quantile function of chi-squared dist
    pval = 1-chi2cdf(estimate*stat.N_o,stat.dof);

    if nargout > 1
      dist = chi2inv(linspace(0,1,S),stat.dof)./stat.N_o;
    end
  else
    t = estimate.*sqrt((stat.N_o-2)./(1-estimate.^2));

    % Get p-value from quantile function of F-dist
    pval = fcdf(t^2,1,stat.N_o-2);
    
    if nargout > 1
      dist = tinv(linspace(0,1,S),stat.N_o-2)./sqrt(stat.N_o-2);
    end
  end
  
% (Our) exact test
elseif strcmp(parser.Results.test,'exact')
  
  switch parser.Results.varianceEstimator
    case 'none'
      correction = 0;
    case 'bartlett'
      correction = 1;
    case 'roy'
      correction = 2;
  end

  if correction > 1 && ~stat.mv
    warning('Roy''s correction only available if CMI is computed with full multivariate setting. Use, e.g., MVMI(X,Y,W,''multivariateBartlett'',true)\n');
  end

  % Initial effective sample size (remove the order of autoregression)
  
  
  % Bartlett-corrected effective sample size
  if correction > 0
%     stat.d_2 = stat.N_o ./ diag(stat.var_r);
    stat.d_2 = diag(stat.N_e);
  else
    stat.d_2 = stat.N_o;
  end
  stat.d_2 = stat.d_2 - stat.cs - 2;

  if any(stat.d_2 < 1)
    sum_lt1 = sum(stat.d_2 < 1);
    warning('%d Effective DOF < 50 (%s).\n',...
              sum_lt1, mat2str(stat.d_2(stat.d_2 < 1)));
  end
  
  % Compute p-value
  if stat.cmi
    
    % Monte carlo sample the t-distributed random variables
    t_rvs = zeros(S,stat.dof);
    for i = 1:stat.dof
      t_rvs(:,i) = trnd(stat.d_2(i),[S,1]);
    end
    
    % Conditional mutual information (sums of log-F dist. RVs)
    f_rvs = t_rvs.^2;
    logf_rvs = log(f_rvs./stat.d_2'+1);
    dist = sum(logf_rvs,2);
    estimate = 2*stat.to_cmi(estimate);
    
    % Proportion of surrogates less than statistic
    pval = mean( estimate <= dist );
    
    if nargout > 1
      dist = sort(dist);
    end
  else
    
    % Sum the partial correlations
    r = estimate;
    nu = stat.d_2;
    
    % Compute t-stat...
    t = r.*sqrt((nu)./(1-r.^2));
    
    % ...and get p-value analytically
    pval = fcdf(t^2,1,nu);
    
    if nargout > 1
      dist = tinv(linspace(0,1,S),stat.d_2)./sqrt(stat.d_2);
    end
  end
end