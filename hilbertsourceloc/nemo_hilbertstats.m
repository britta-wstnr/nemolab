% perform stats on Hilbert source data
if(isfield(cfgnemo,'ergchan'))
    % if ERG channel is present, pretend that ERG is the first voxel
    for jj=1:length(source_hilbtmp{ii}.trial)
        source_hilbtmp{ii}.trial(jj).mom{1} = erghilb{ii}.trial{jj};
    end
    source_hilbtmp{ii}.inside(1) = 1; % and that voxel needs to be considered "inside"
end

inside_idx = find(source_hilbtmp{ii}.inside);

%%
disp(freqbands(ii,:));
% initialize trials, aph, and aa
trials = zeros(length(source_hilbtmp{ii}.trial),length(inside_idx),length(source_hilbtmp{ii}.trial(1).mom{inside_idx(1)}));
aph = trials;
aa = trials;
for jj=1:length(source_hilbtmp{ii}.trial)
    trials(jj,:,:) = cell2mat(source_hilbtmp{ii}.trial(jj).mom);
end
aph = angle(trials);
aa = abs(trials);

if(saveRAM)
    source_hilbtmp{ii} = []; % don't use "clear" since this is a for loop!!
    clear trials
end

phvar=squeeze(circ_var(aph,[],[],1));
aamean=squeeze(mean(aa,1)); % Hilbert analytic amplitude
evokedmean = squeeze(mean(trials,1));

%aabaseline = mean(aamean(:,baselinewindow_idx(1):baselinewindow_idx(2)),2);
%aameannorm = 20*log10(diag(1./aabaseline)*aamean);  % normalize against baseline

source_hilb{ii} = source_bp{ii}; % initialize source_hilb
source_hilb{ii}.avg.itc = source_hilb{ii}.avg.mom; % initialize itc
source_hilb{ii}.avg.aa = source_hilb{ii}.avg.mom; % initialize aa
for jj=1:length(inside_idx)
    source_hilb{ii}.avg.itc{inside_idx(jj)} = 1 - phvar(jj,:);
    source_hilb{ii}.avg.mom{inside_idx(jj)} = evokedmean(jj,:);
    source_hilb{ii}.avg.aa{inside_idx(jj)} = aamean(jj,:);
end
%%
if(cfgnemo.tfstats)
    % TODO: FDR correction? cluster analysis?
    p = ones(size(aa,2),size(aa,3));
    zval = zeros(size(aa,2),size(aa,3));
    
    pitc = p;
    zitc = zval;
    %     pks = p; ksval = zval;
    
    switch('ttest')
        case 'ranksum'  % this is slow and perhaps not necessary...
            ft_progress('init','etf');
            
            
            Nsamples = size(aa,3); % need to pre-define to make 'parfor' happy...
            for jj=1:size(aa,2) % Nvoxels
                aabl = squeeze(aa(:,jj,baselinewindow_idx(1):baselinewindow_idx(2)));
                aabl = aabl(:);
                
                aphbl = squeeze(aph(:,jj,baselinewindow_idx(1):baselinewindow_idx(2)));
                aphbl = aphbl(:);
                
                parfor kk=1:Nsamples % much faster to put parfor here than for jj
                    [p(jj,kk),~,stats]=ranksum(aa(:,jj,kk),aabl);
                    zval(jj,kk)=stats.zval;
                    
                    
                    [pitc(jj,kk),zitc(jj,kk)] = circ_kuipertest(aph(:,jj,kk),aphbl);
                    
                    %             [~,pks(jj,kk),ksval(jj,kk)] = kstest2(aa(:,jj,kk),aabl);
                end
                ft_progress(jj/size(aa,2),'%d of %d',jj,size(aa,2));
            end
            ft_progress('close');
        case 'ttest'
            ft_progress('init','etf');
            
            % log10(aa) yields a Gaussian distribution compatible with the t-test
            logaa = log10(aa);
            
            
            Nsamples = size(logaa,3); % need to pre-define to make 'parfor' happy...
            for jj=1:size(logaa,2) % Nvoxels
                aabl = squeeze(logaa(:,jj,baselinewindow_idx(1):baselinewindow_idx(2)));
                aabl = aabl(:);
                
%                aphbl = squeeze(aph(:,jj,baselinewindow_idx(1):baselinewindow_idx(2)));
%                aphbl = aphbl(:);
                
                parfor kk=1:Nsamples % much faster to put parfor here than for jj
                    [~,p(jj,kk),~,stats]=ttest2(logaa(:,jj,kk),aabl);
                    zval(jj,kk)=stats.tstat;
                    
                    
           %         [pitc(jj,kk),zitc(jj,kk)] = circ_kuipertest(aph(:,jj,kk),aphbl);
                    
                    %             [~,pks(jj,kk),ksval(jj,kk)] = kstest2(aa(:,jj,kk),aabl);
                end
                ft_progress(jj/size(aa,2),'%d of %d',jj,size(aa,2));
            end
            ft_progress('close');
        case 'signrank'
            aabl = squeeze(mean(aa(:,:,baselinewindow_idx(1):baselinewindow_idx(2)),3)); % single-trial means of baseline window per voxel
            Nsamples = size(aa,3); % need to pre-define to make 'parfor' happy...
            parfor jj=1:size(aa,2) % Nvoxels
                for kk=1:Nsamples
                    [p(jj,kk),~,stats]=signrank(aa(:,jj,kk),aabl(:,jj));
                    zval(jj,kk)=stats.zval;
                end
            end
    end
    
    source_hilb{ii}.stat = source_hilb{ii}.avg.mom; % initialize with 'mom' since it's the same size
    source_hilb{ii}.pval = source_hilb{ii}.stat;
    source_hilb{ii}.statitc = source_hilb{ii}.stat; % TODO: THIS IS JUST A PLACEHOLDER!!
    source_hilb{ii}.pitc = source_hilb{ii}.stat; % TODO: THIS IS JUST A PLACEHOLDER!!
    
    for jj=1:length(inside_idx)
        source_hilb{ii}.stat{inside_idx(jj)} = zval(jj,:);
        source_hilb{ii}.pval{inside_idx(jj)} = log10(p(jj,:));
%        source_hilb{ii}.statitc{inside_idx(jj)} = zitc(jj,:);
%        source_hilb{ii}.pitc{inside_idx(jj)} = log10(pitc(jj,:));
    end
end

clear trials zval p aa aph phvar