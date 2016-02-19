
%%
clear; clc; cd 'C:\Program Files\Micro-Manager-1.4 (64bit)'
%get pointer to script interface
%si = StartMMStudio('-setup'); %run setup the first time
si = StartMMStudio;

% si.getXYStagePosition
% si.getXYStageName
core = si.getCore
% core.setXYPosition(-12231.0, 43076.0)
% core.setProperty('ZStage','Acceleration',91)


%% run test acquisition
% acqName = 'Test';
% showImgWindow = false;
% saveToDisk = false;
% numFrames = 100;
% 
% si.openAcquisition(acqName, 'D:\Zack\mmtestdata',numFrames,1,1,1,showImgWindow,saveToDisk);
% tic
% for f = 0:numFrames-1
%     si.snapAndAddImage(acqName,f, 0, 0, 0);
%     toc
% end
% 
% si.closeAcquisition(acqName);

%% acquire directly from core
% startSecondaryLogFile(java.lang.String(strcat(pwd,'\testLog.txt')), 1);
core.setExposure(0.5);
%in MB
core.setCircularBufferMemoryFootprint(6000);


tic
core.startSequenceAcquisition(100,0,false)
while core.isSequenceRunning

  pause(0.01) 
end
toc


%number of images buffer can hold...change in tools-option in MM gui
% core.getBufferTotalCapacity;

%N is how many images to go back in buffer to retrieve image
img = core.getNBeforeLastTaggedImage(0);
%TaggedImages have .img and .tags field
imgWidth = core.getImageWidth;
imgHeight = core.getImageHeight;
pix = reshape(img.pix,imgWidth,imgHeight);
smaller = imresize(pix,1/5);
imshow(smaller,[])


%% Arduino Control
core.setProperty('FreeSerialPort','Command','xx')
core.setProperty('FreeSerialPort','Command','dh')

%query metadata
metadata = img.tags
metadata.getString('FreeSerialPort-Command')

