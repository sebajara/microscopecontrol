addpath(genpath('./src/'));

%% =============== INITIALIZE =====================

% Have devices as global variables, makes things easier when using functions
global mmc nis devices;

%% Initialise Micro-manager
configfile = 'C:\Micro-Manager-1.4\MMConfig_Basic_20170608.cfg'; 
mmcfolder = 'C:\Micro-Manager-1.4\';
if(exist(mmcfolder))
    ccd = cd; % current folder
    cd('C:\Micro-Manager-1.4\');
    import mmcorej.*; % import java classes
    mmc = CMMCore;
    mmc.loadSystemConfiguration(configfile);
    % this is useful to set properties of microscopy devices directly
    devices = mmc.getLoadedDevices(); 
    display('MMCore is initialized.');
    % set core properties
    mmc.setProperty('Core','Camera','Andor');
    % further settings for Andor 
    mmc.setProperty('Andor','Binning','1'); %set binning
    mmc.setProperty('Andor','Gain','27'); %set gain
    mmc.setProperty('Andor','CCDTemperatureSetPoint','-90');
    cd(ccd); % come back to current folder
end

%% Initialise National Instrument controlling bfield
nis = daq.createSession('ni');
addDigitalChannel(nis,'Dev1', 'Port1/Line0', 'OutputOnly');
outputSingleScan(nis,0); % turn bfield OFF
display('National Instrument controlling brighfield loaded');

%% =============== Simple examples =====================

%% Turn perfect focus ON/OFF
mmc.setProperty('TIPFSStatus','State','Off'); % turn OFF
mmc.setProperty('TIPFSStatus','State','On');  % turn ON

%% Moving in XY
x = mmc.getXPosition('XYStage'); % get current X
y = mmc.getYPosition('XYStage'); % get current Y

mmc.setXYPosition('XYStage',x+100,y); % move in X
mmc.waitForDevice(mmc.getXYStageDevice()); % wait in between

mmc.setXYPosition('XYStage',x+100,y+100); % move in XY
mmc.waitForDevice(mmc.getXYStageDevice()); % wait in between

%% Moving in Z
z = mmc.getPosition(mmc.getFocusDevice()); % get current Z

mmc.setPosition(mmc.getFocusDevice(),z+2); % move in Z
mmc.waitForDevice(mmc.getFocusDevice()); % wait

%% Taking bfield snapshot
exposure = 20; % in msec
gain     = 5;  % minimal gain
filter   = '5-TRITC'; % filter cube
% set imaging parameters
mmc.setProperty('Andor','Gain',num2str(gain)); % set gain
mmc.setProperty('TIFilterBlock1','Label',filter); % set filter
%%mmc.waitForDevice(gui.filterDevice);
mmc.setExposure(exposure); % set exposure
% take image
outputSingleScan(nis,1); % turn bfiled ON
mmc.snapImage; % acquire a single image
outputSingleScan(nis,0); % turn bfiled OFF
img = flipdim(rot90(reshape(typecast(mmc.getImage,'uint16'), [mmc.getImageWidth, mmc.getImageHeight])),1);
% show it on a figure
figure(); imshow(img,[]);

%% Taking fluorescence snapshot in GFP
exposure = 20; % in msec
gain     = 5;  % minimal gain
filter   = '3-FITC'; 
illumination = 'Cyan'; % lamp
level    = 100; % lamp intensity
% set imaging parameters
mmc.setProperty('Andor','Gain',num2str(gain)); % set gain
mmc.setProperty('TIFilterBlock1','Label',filter); % set filter
%mmc.waitForDevice(gui.filterDevice);
mmc.setExposure(exposure); % set exposure
mmc.setProperty('Spectra',[illumination,'_Level'],num2str(level)); % 
% take image
mmc.setProperty('Spectra',[illumination,'_Enable'],num2str(1)); % Open illumination
mmc.snapImage; % acquire a single image
mmc.setProperty('Spectra',[illumination,'_Enable'],num2str(0)); % Turn OFF
img = flipdim(rot90(reshape(typecast(mmc.getImage,'uint16'), [mmc.getImageWidth, mmc.getImageHeight])),1);
% show it on a figure
figure(); imshow(img,[]);

% Taking fluorescence snapshot in mCherry
filter = '5-TRITC';
illumination = 'Green';
% set imaging parameters
mmc.setProperty('Andor','Gain',num2str(gain)); % set gain
mmc.setProperty('TIFilterBlock1','Label',filter); % set filter
mmc.waitForDevice('TIFilterBlock1');
mmc.setExposure(exposure); % set exposure
mmc.setProperty('Spectra',[illumination,'_Level'],num2str(level)); % 
% take image
mmc.setProperty('Spectra',[illumination,'_Enable'],num2str(1)); % Open illumination
mmc.snapImage; % acquire a single image
mmc.setProperty('Spectra',[illumination,'_Enable'],num2str(0)); % Turn OFF
img = flipdim(rot90(reshape(typecast(mmc.getImage,'uint16'), [mmc.getImageWidth, mmc.getImageHeight])),1);
% show it on a figure
figure(); imshow(img,[]);

% Taking fluorescence snapshot in DAPI
filter = '1-DAPI';
illumination = 'Violet';
% ....
% The rest is idem as for GFP example

%% Getting current settings 
% This is what I save, but there may be a better way to do this
specs = struct;
specs.Clock = clock;
specs.StageXPosition = mmc.getXPosition('XYStage');
specs.StageYPosition = mmc.getYPosition('XYStage');
specs.ZPosition      = mmc.getPosition(mmc.getFocusDevice());
specs.Filter         = char(mmc.getProperty('TIFilterBlock1','Label'));
specs.Gain           = char(mmc.getProperty('Andor','Gain'));
specs.Exposure       = char(mmc.getProperty('Andor','Exposure'));
specs.PerfectFocus   = char(mmc.getProperty('TIPFSStatus','State'));
% get all devices properties
for iDEV = [0:devices.size-1]
    properties = mmc.getDevicePropertyNames(devices.get(iDEV));
    devname = removestructnonchars(char(devices.get(iDEV)));
    for j = [0:properties.size-1]
        s = char(properties.get(j));
        v = mmc.getProperty(devices.get(iDEV),s);
        specs.([devname,'_',removestructnonchars(s)]) = char(v);
    end
end


%% Saving an image
folder   = 'OUTPUT/';
filename = 'IMG_test.mat';
ctime    = clock;
save([folder,filename],'img','specs','ctime'); % in matlab format
filename = 'IMG_test.tif';
imwrite(uint16(img),[folder,filename],'tif','Compression','none'); % save in tif

%% Doing Z stacks
zrange = linspace(-1,1,7); % seven stacks, distance of 1 micron to
                           % current Z
z0 = mmc.getPosition(mmc.getFocusDevice()); % get current Z

mmc.setProperty('TIPFSStatus','State','Off'); % turn PF OFF
img = zeros(mmc.getImageHeight,mmc.getImageWidth,length(zrange)); % allocate matrix
for nz = 1:length(zrange)
    z = z0 + zrange(nz); % target Z
    mmc.setPosition(mmc.getFocusDevice(),z); % move in Z
    mmc.waitForDevice(mmc.getFocusDevice()); % wait    
    mmc.setProperty('Spectra',[illumination,'_Enable'],num2str(1)); % Illuminate sample
    mmc.snapImage; % acquire a single image
    mmc.setProperty('Spectra',[illumination,'_Enable'],num2str(0)); % Turn OFF
    img(:,:,nz) = flipdim(rot90(reshape(typecast(mmc.getImage,'uint16'), [mmc.getImageWidth, mmc.getImageHeight])),1);
end
mmc.setPosition(mmc.getFocusDevice(),z0); % go back to z0
mmc.waitForDevice(mmc.getFocusDevice()); % wait
mmc.setProperty('TIPFSStatus','State','On');  % turn PF ON
% plot maximum projection
mproj    = zeros(mmc.getImageHeight,mmc.getImageWidth);
mproj(:) = max(reshape(img(:,:,:),mmc.getImageHeight*mmc.getImageWidth,length(zrange))');
figure(); imshow(mproj,[]);

%% Plotting on the same figure
figure();
ha = axes();
% take image
mmc.setProperty('Spectra',[illumination,'_Enable'],num2str(1)); % Illuminate sample
mmc.snapImage; % acquire a single image
mmc.setProperty('Spectra',[illumination,'_Enable'],num2str(0)); % Turn OFF
img = flipdim(rot90(reshape(typecast(mmc.getImage,'uint16'), [mmc.getImageWidth, mmc.getImageHeight])),1);
imshow(img,[],'Parent',ha);
% Specifying the axes for imshow will update that figure 

%% NOTE: XY dim follow the movement of the stage
%% Doing LIVE in bfield
fig = figure('MenuBar','none',...
             'Position',[200,200,700,700]);
liveax = axes('Position',[0.05,0.07,0.9,0.9],'Parent',fig);
img    = rand(512,512)*100;
imshow(img,[],'Parent',liveax);
livecontrol = uicontrol(fig,'Style','pushbutton',...
                        'String','LIVE BRIGHTFIELD',...
                        'Callback',@livecontrol_aux,...
                        'Position',[150,5,400,40],...
                        'UserData',liveax);
% see livecontrol_aux for details

%% =============== XY scan example =====================


x1 = mmc.getXPosition('XYStage');  % min X
y1 = mmc.getYPosition('XYStage');  % max X
x2 = x1+8000;  % min Y
y2 = y1+2500;  % max Y

% intervals needs to be >= 100
xgrid = 50; % number of positions in X
ygrid = 7;  % number of positions in Y
xvals = linspace(x1,x2,xgrid); % x values
yvals = linspace(y1,y2,ygrid); % y values

xypairs = [];
count   = 0;
% Make a figure to show the update
fig = figure('MenuBar','none',...
             'Position',[200,200,1400,700]);
% axes to show images
imgax = axes('Position',[0.02,0.07,0.45,0.9],'Parent',fig);
img    = rand(512,512)*100;
imshow(img,[],'Parent',imgax);
% axes to show progression on XY
xysax = axes('Position',[0.03+0.5,0.07,0.45,0.9],'Parent',fig); hold on;
% construct the pairs of XY values
for ny = 1:ygrid
    if(mod(ny,2)==0) % even
        xvals2 = fliplr(xvals);
    else
        xvals2 = xvals;
    end
    for nx = 1:xgrid
        % we are going to alternate the order on Y to reduce the travel distance
        count = count+1;
        xypairs(count,:) = [xvals2(nx),yvals(ny)];
    end
end
% plot the trajectory in XY
plot(xypairs(:,1),xypairs(:,2),'--','Color','black','LineWidth',2);
% make a marker for each position to be adquired with red color
pobjs   = {};
for np = 1:size(xypairs,1)
    pobjs{np} = plot(xypairs(np,1),xypairs(np,2),'o','Color',[1,0,0],'LineWidth',2);
end
% adjust slightly the axis edges
axis([x1-100,x2+100,y1-100,y2+100]);

outfolder = '.\OUTPUT\20190516_test5\';
if(exist(outfolder,'dir'))
    display('Abort! a folder with that prefix already exists');
else
    mkdir(outfolder);
end
prefix  = '20190516_test5';
chanels = {'Brighfield','mCherry','GFP'};
extimes = [20,100,80]; % in msec
gains   = [5,5,5];    % minimal gain
filters = {'5-TRITC','5-TRITC','3-FITC'};
illuminations = {'','Green','Cyan'};
levels = [0,100,100];
% adquire images!
for np = 1:size(xypairs,1)
    mmc.setXYPosition('XYStage',xypairs(np,1),xypairs(np,2)); % move in XY
    mmc.waitForDevice(mmc.getXYStageDevice()); % wait in between
    for ch = 1:3
        % set imaging parameters
        mmc.setProperty('Andor','Gain',num2str(gains(ch))); % set gain
        mmc.setProperty('TIFilterBlock1','Label',filters{ch}); % set filter
        mmc.waitForDevice('TIFilterBlock1');
        mmc.setExposure(extimes(ch)); % set exposure
        if(ch>1) % fluo
            mmc.setProperty('Spectra',[illuminations{ch},'_Level'],num2str(levels(ch))); %
            % take image
            mmc.setProperty('Spectra',[illuminations{ch},'_Enable'],num2str(1)); % Open illumination
            mmc.snapImage; % acquire a single image
            mmc.setProperty('Spectra',[illuminations{ch},'_Enable'],num2str(0)); % Turn OFF
        else % bfield
            outputSingleScan(nis,1); % turn bfiled ON
            mmc.snapImage; % acquire a single image
            outputSingleScan(nis,0); % turn bfiled OFF
        end
        img = flipdim(rot90(reshape(typecast(mmc.getImage,'uint16'), [mmc.getImageWidth, mmc.getImageHeight])),1);
        specs = struct;
        specs.Clock = clock;
        specs.StageXPosition = mmc.getXPosition('XYStage');
        specs.StageYPosition = mmc.getYPosition('XYStage');
        specs.ZPosition      = mmc.getPosition(mmc.getFocusDevice());
        specs.Filter         = char(mmc.getProperty('TIFilterBlock1','Label'));
        specs.Gain           = char(mmc.getProperty('Andor','Gain'));
        specs.Exposure       = char(mmc.getProperty('Andor','Exposure'));
        specs.PerfectFocus   = char(mmc.getProperty('TIPFSStatus','State'));
        filename = [outfolder,...
                    'IMG-',prefix,...
                    '_XY-',num2str(np),...
                    '_CHN-',chanels{ch},...
                    '_IT-',num2str(1,'%04.f'),...
                    '.mat'];
        save(filename,'img','specs');
        if(ch==2)
            imshow(img,[],'Parent',imgax);
            pause(0.1);
        end
    end
    % change color from red to green when visited
    set(pobjs{np},'Color',[0 1 0]);
    pause(0.1);
end
for np = 1:size(xypairs,1)
    % change color from red to green when visited
    set(pobjs{np},'Color',[1 0 0]);
end

%% =============== UN MOUNT =====================
if(~isempty(mmc))
    mmc.unloadAllDevices();
    clear mmc;
    display('MMCore is unloaded.');
end
if(~isempty(nis))
    delete(nis);
    display('National instrument is unloaded.');
end

