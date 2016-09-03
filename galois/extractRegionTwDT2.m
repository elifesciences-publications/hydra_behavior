function [trajAll,hofAll,hogAll,mbhxAll,mbhyAll,coordAll] = extractRegionTwDT2...
    (movieParam,filepath,segmat,locs,numRegion,L,nxy,nt,W,N,track_thresh)
% [flows,hofAll,hogAll,mbhxAll,mbhyAll] = extractDT(movieParam)
% Extract the descriptors from Dense Trajectory code, and store them in
% cell arrays for codebook generation later.

% file information
infostr = ['L_' num2str(L) '_W_' num2str(W) '_N_' num2str(N) '_s_' num2str(nxy) '_t_' num2str(nt)];
trackInfo = dir([filepath movieParam.fileName '_' infostr '/*.txt']);
numVideo = size(trackInfo,1);

% DT feature information
numPatch = nxy*nxy*nt;
sTraj = 2*L;
sCoord = 2*L;
sHof = 9*numPatch;
sHog = 8*numPatch;
sMbh = 8*numPatch;
ltraj = floor(2*L/numPatch);

% initialization
trajAll = cell(numVideo,numRegion*numPatch);
hofAll = cell(numVideo,numRegion*numPatch);
hogAll = cell(numVideo,numRegion*numPatch);
mbhxAll = cell(numVideo,numRegion*numPatch);
mbhyAll = cell(numVideo,numRegion*numPatch);
coordAll = cell(numVideo,numRegion*numPatch);

% exclude the error information in the first two lines
locs = [1;locs];
dims = size(segmat);
for i = 2:numVideo % SH tempory change
    
    % if file empty, put NaN
    if trackInfo(i).bytes~=124
        
        dt_features = dlmread([filepath movieParam.fileName '_' infostr...
            '/' trackInfo(i).name],'\t',2,0);
        
        % trajectory coordinates
        crCoord = dt_features(:,11+sTraj:10+sTraj+sCoord);
        crCoord = round(crCoord(~any(isnan(crCoord),2),:));
        crCoord(crCoord<=0) = 1;
        xcoord = crCoord(:,1:2:end);
        ycoord = crCoord(:,2:2:end);
        xcoord(xcoord>dims(1)) = dims(1);
        ycoord(ycoord>dims(2)) = dims(2);
        
        % get segmentation region index
        lind = sub2ind([dims(1) dims(2)],ycoord,xcoord);
        regIndx = zeros(size(lind));
        for j = 1:L
            seg_im = segmat(:,:,locs(i)-1+j);
            regIndx(:,j) = seg_im(lind(:,j));
        end
        regIndx(regIndx==0) = NaN;
        regIndx = mode(regIndx,2);
        
        % descriptors
        crTraj = dt_features(:,11:10+sTraj);
        crTraj = crTraj(~any(isnan(crTraj),2),:);
        
        crHog = dt_features(:,11+sTraj+sCoord:10+sTraj+sCoord+sHog);
        crHog = crHog(~any(isnan(crHog),2),:);

        crHof = dt_features(:,11+sTraj+sCoord+sHog:10+sTraj+sCoord+sHof+sHog);
        crHof = crHof(~any(isnan(crHof),2),:);

        crMbhx = dt_features(:,11+sTraj+sCoord+sHof+sHog:10+sTraj+sCoord+sHof+sHog+sMbh);
        crMbhx = crMbhx(~any(isnan(crMbhx),2),:);
        
        crMbhy = dt_features(:,11+sTraj+sCoord+sHof+sHog+sMbh:10+sTraj+sCoord+sHof+sHog+sMbh*2);
        crMbhy = crMbhy(~any(isnan(crMbhy),2),:);
        
        for j = 1:numRegion
            if sum(regIndx==j)~=0
                for k = 1:numPatch
                    trajAll{i,(j-1)*numPatch+k} = single(crTraj(regIndx==j,(k-1)*ltraj+1:k*ltraj));
                    hofAll{i,(j-1)*numPatch+k} = single(crHof(regIndx==j,(k-1)*9+1:k*9));
                    hogAll{i,(j-1)*numPatch+k} = single(crHog(regIndx==j,(k-1)*8+1:k*8));
                    mbhxAll{i,(j-1)*numPatch+k} = single(crMbhx(regIndx==j,(k-1)*8+1:k*8));
                    mbhyAll{i,(j-1)*numPatch+k} = single(crMbhy(regIndx==j,(k-1)*8+1:k*8));
                    coordAll{i,(j-1)*numPatch+k} = single(crCoord(regIndx==j,(k-1)*ltraj+1:k*ltraj));
                end
            else
                for k = 1:numPatch
                    trajAll{i,(j-1)*numPatch+k} = nan(1,ltraj);
                    hofAll{i,(j-1)*numPatch+k} = nan(1,9);
                    hogAll{i,(j-1)*numPatch+k} = nan(1,8);
                    mbhxAll{i,(j-1)*numPatch+k} = nan(1,8);
                    mbhyAll{i,(j-1)*numPatch+k} = nan(1,8);
                    coordAll{i,(j-1)*numPatch+k} = nan(1,ltraj);
                end
            end
        end
        
    else
        
        fprintf('feature file is empty: %s\n',trackInfo(i).name);
        for j = 1:numRegion
            for k = 1:numPatch
                trajAll{i,(j-1)*numPatch+k} = nan(1,ltraj);
                hofAll{i,(j-1)*numPatch+k} = nan(1,9);
                hogAll{i,(j-1)*numPatch+k} = nan(1,8);
                mbhxAll{i,(j-1)*numPatch+k} = nan(1,8);
                mbhyAll{i,(j-1)*numPatch+k} = nan(1,8);
                coordAll{i,(j-1)*numPatch+k} = nan(1,ltraj);
            end
        end
        
    end
    
end


end