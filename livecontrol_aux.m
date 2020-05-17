function livecontrol_aux(Hobj,~) 
    
    global mmc nis devices; % devices 
    
    set(Hobj,'BackgroundColor','yellow');
    % find a timer exists
    livetimer = timerfind('Tag','LIVE');
    
    if(~isempty(livetimer)) 
        % Stop previous timer and delete it
        stop(livetimer);
        delete(livetimer);
        set(Hobj,'BackgroundColor',0.94*[1,1,1]);
        
    else
        % get the axes ID where the image should be plotted
        ax = get(Hobj,'UserData');
        
        % parameters
        exposure = 20; % in msec
        gain     = 5;  % minimal gain
        filter   = '5-TRITC'; % filter cube
                              
        % Create a timer for adquiring images
        t = timer;
        t.Tag = 'LIVE';
        t.StartDelay = 0; 
        t.Period = exposure/1000+0.03; % some minimal delay
        t.ExecutionMode = 'fixedRate';
        t.TimerFcn = {@LiveAux,ax}; % pass the axes to plot
        t.StopFcn  = @LiveStop;
        
        % set imaging parameters
        mmc.setProperty('Andor','Gain',num2str(gain)); % set gain
        mmc.setProperty('TIFilterBlock1','Label',filter); % set filter
        mmc.setExposure(exposure); % set exposure

        % Start imagining
        outputSingleScan(nis,1); % turn bfiled ON
        mmc.startContinuousSequenceAcquisition(1); 
        start(t); % also start the timer
    end

    function LiveAux(~,~,ax)
    % get the last image from the sequence and plot it.
        img = flipud(fliplr(flipdim(rot90(reshape(typecast(mmc.getLastImage,'uint16'),... 
                                    [mmc.getImageWidth, mmc.getImageHeight])),1)));
        imshow(img,[],'Parent',ax);
    end
    
    function LiveStop(~,~)
        mmc.stopSequenceAcquisition();
        outputSingleScan(nis,0); % turn bfield OFF
    end
    
end
