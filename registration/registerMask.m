function [bw_reg,thetas,centroids,as] = registerMask(movieParam,bw,time_step)
% register hydra videos, and calculate the orientation, centroid and length
% SYNOPSIS:
%     [uu_reg,vv_reg,bw_reg,thetas,centroids,as] = registerAll(movieParam,uu,vv,bw,bg,time_step)
% INPUT:
%     movieParam: a struct returned by function paramAll
%     bw: binary mask with segmented region
%     bg: estimated background image (currently not used)
%     time_step: number of frames in each time window
% OUTPUT:
%     bw_reg: registered mask matrix
%     thetas: T-by-1 vector, with the orientations of hydra
%     centroids: T-by-2 matrix, with the centroids of hydra
%     as: T-by-1 vector, with the length of hydra
% 
% Shuting Han, 2015

% initialization
dims = size(bw);
bw_reg = false(dims);
thetas = zeros(dims(3),1);
centroids = zeros(dims(3),2);
as = zeros(dims(3),1);
tt = floor(movieParam.numImages/time_step);

% progress text
fprintf('processed time window:      0/%u',tt);

% register the rest based on the first image
for i = 1:tt
    
    % take the average angle and centroid in the time window
    for k = 1:time_step
        
        % read image
        im = double(imread([movieParam.filePath movieParam.fileName '.tif'],...
            (i-1)*time_step+k));
        im = mat2gray(im);
        
         % align and fit ellipse
        if i==1 && k==1
            [thetas((i-1)*time_step+k),centroids((i-1)*time_step+k,:),...
                as((i-1)*time_step+k),b,rarea] = registerIm(im);
        else
            [thetas((i-1)*time_step+k),centroids((i-1)*time_step+k,:),...
                as((i-1)*time_step+k),b,rarea] = registerIm(im,rareaprev,centroidprev);
        end
        centroidprev = centroids((i-1)*time_step+k,:);
        rareaprev = rarea;
        
        % exclude NaN
        if isnan(thetas((i-1)*time_step+k))
            thetas((i-1)*time_step+k) = 0;
            centroids((i-1)*time_step+k,:) = movieParam.imageSize/2;
        end
        
%         % visualization
        im = double(imread([movieParam.filePath movieParam.fileName '.tif'],...
            (i-1)*time_step+k));
        
        immax = max(im(:));
        im = round(im/immax*255);
        imagesc(im);colormap(gray);title(num2str((i-1)*time_step+k));
        axis equal tight;
        tmp.Centroid = centroids((i-1)*time_step+k,:);
        tmp.MajorAxisLength = as((i-1)*time_step+k);
        tmp.MinorAxisLength = b;
        tmp.Orientation = thetas((i-1)*time_step+k);
        hold on;plot_ellipse2(tmp);
        quiver(tmp.Centroid(1),tmp.Centroid(2),cos(degtorad(tmp.Orientation))*...
            tmp.MajorAxisLength,-sin(degtorad(tmp.Orientation))*tmp.MajorAxisLength);
        xlim([0 movieParam.imageSize(2)]);ylim([0 movieParam.imageSize(1)]);
        hold off
        pause(0.01);
        
    end
    
    cr_theta = 90-trimmean(thetas((i-1)*time_step+1:i*time_step),50);
    cr_cent = trimmean(centroids((i-1)*time_step+1:i*time_step,:),50,1);
    
    % register each frame
    for j = 1:time_step
        f_bw = squeeze(double(bw(:,:,(i-1)*time_step+j)));
        bw_reg(:,:,(i-1)*time_step+j) = logical(imrotate(imtranslate(f_bw,...
            [movieParam.imageSize(1)/2-cr_cent(1) movieParam.imageSize(2)/2-...
            cr_cent(2)]),cr_theta,'crop'));
    end
    
    % update progress text
    fprintf(repmat('\b',1,length(num2str(tt))+length(num2str(i))+1));
    fprintf('%u/%u',i,tt);
    
end

fprintf('\n');

end