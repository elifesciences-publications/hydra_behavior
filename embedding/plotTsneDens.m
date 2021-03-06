function [] = plotTsneDens(xx,dens,im_mask,cmax)
% plotTsneDens(xx,dens,im_mask,cmax)
% plot the given density map matrix on current axis handle

% fill empty regions with NaNs
im = dens;
% im(im_mask==0) = NaN;
im(im_mask==0) = min(dens(:))-(cmax-min(dens(:)))/63;

% plot
% pcolor(xx,xx,im)
imagesc(xx,xx,im);
% colormap(jet);
colormap([[1 1 1];jet(63)]);
pos = get(gca,'position');
shading flat
axis equal tight xy
caxis([min(im(:)) cmax])
colorbar
set(gca,'position',pos)

end