function data=match_labview_log(data,anal_opts)
%% Match Labview data
%because the mcp-dld detector has no direct communication with the bec computer
% the data.labview.shot_num does not nessesarily correspond to data.mcp_tdc.shot_num
%try and match up the file with if it is a calibaration using the time
%it is slightly overkill here to search each one, but just being extra
%cautious/flexible
time_thresh=10; %4how close for the times to be considered the same shot
%lets examine what the time difference does

data.mcp_tdc.labview_shot_num=[];
data.mcp_tdc.probe.calibration=[];

imax=min([size(data.labview.time,2),size(data.mcp_tdc.time_create_write,1)]);
%imax=5000;

%TODO: this next line assumes that everything is in sync, it would be
%better to find the min diff time for each
time_diff=data.mcp_tdc.time_create_write(1:imax,2)'-anal_opts.dld_aquire-anal_opts.trig_dld-...
    data.labview.time(1:imax);

med_time=median(time_diff);
if med_time<anal_opts.dld_aquire && med_time*2>time_thresh
    warning('times are not synced check that computers are syncing clocks')
    mean_delay_labview_tdc=med_time;%median(time_diff);
else
    mean_delay_labview_tdc=0;
end
    
stfig('diagnostics and veto','add_stack',1);
subplot(4,1,2)
plot(data.mcp_tdc.shot_num(1:imax),time_diff-mean_delay_labview_tdc,'k')
xlabel('shot number')
ylabel('corrected time between labview and mcp tdc')
title('raw time diff')
drawnow
%to do include ai_log
iimax=size(data.mcp_tdc.time_create_write(:,1),1);
data.mcp_tdc.probe.calibration=nan(iimax,1);
data.mcp_tdc.labview_shot_num=nan(iimax,1);
%loop over all the tdc_files 
for ii=1:iimax
    %predict the labview master trig time
    %use the write time to handle being unpacked from 7z
    tmp_est_labview_start=data.mcp_tdc.time_create_write(ii,2)...
        -anal_opts.trig_dld-anal_opts.dld_aquire-mean_delay_labview_tdc;
    [tval,nearest_idx]=closest_value(data.labview.time...
        ,tmp_est_labview_start);
    if abs(tval-tmp_est_labview_start)<time_thresh
        data.mcp_tdc.labview_shot_num(ii)=data.labview.shot_num(nearest_idx);
        data.mcp_tdc.probe.calibration(ii)=data.labview.calibration(nearest_idx);
    end 
end
clear('tmp_est_labview_start')


end