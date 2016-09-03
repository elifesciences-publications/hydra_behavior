function [movieParam] = paramAllDT_galois(fileind)
% This script is a summary of all parameters

% movie parameters
movieParam = struct;
[movieParam.filePath,movieParam.fileName,movieParam.trackPath,...
    movieParam.numImages,movieParam.fr] = fileinfoDT_galois(fileind);

movieParam.frameStart = 1;
movieParam.frameEnd = movieParam.numImages;

% get movie information
imInfo = imfinfo([movieParam.filePath movieParam.fileName '.tif']);
%movieParam.numSeq = 1:movieParam.numImages;
if imInfo(1).BitDepth~=8
    error('image is not 8 bit');
end
movieParam.imageSize = [imInfo(1).Height,imInfo(1).Width];

end