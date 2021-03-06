function osc_fit=fit_trap_freq(anal_opts_osc_fit,data)
%using the binned data we fit the trap freq to each shot
%loop over every shot in data.tdc but output nothing if
%data.tdc.all_ok(ii)=false
%for compactness could use max((1:numel(data.tdc.all_ok)).*data.tdc.all_ok');
%find the last good shot, but this will fuck up the mask && mask operations
%later
iimax=size(data.tdc.counts_txy,2); 
 %try and guess the trap freq based on the peak of the fft, needed when the
 %kick amp is changing
%ignore some of the fit errors
warning('off','stats:nlinfit:ModelConstantWRTParam');
warning('off','MATLAB:rankDeficientMatrix');
osc_fit=[]; %clear the output struct
%prealocate so that i can do the logics later
osc_fit.dld_shot_idx=nan(1,iimax);
osc_fit.model_coefs=nan(iimax,8,2);
osc_fit.fit_rmse=nan(1,iimax);
osc_fit.model=cell(1,iimax);
fprintf('Fitting oscillations in shots %04i:%04i',iimax,0)

 if anal_opts_osc_fit.plot_fits
            sfigure(51);
            clf
            set(gcf,'color','w')
 end

for ii=1:iimax
    %position that data appears in data.tdc, not ness shot number
    %specified because we will remove any elements of osc_fit that did not
    %fit because of all_ok condition
    osc_fit.dld_shot_idx(ii)=ii;
    %shot number eg d123.txt as recorded by the tdc computer, not ness lv
    %number
    dld_shot_num=data.tdc.shot_num(ii);
    if data.tdc.all_ok(ii)
        osc_fit.dld_shot_num(ii)=dld_shot_num;
        %construct a more convinent temp variable txyz_tmp wich is the position in mm for use in the fit
        x_tmp=1e3*squeeze(data.tdc.al_pulses.pos_stat(ii,:,2));
        x_tmp=x_tmp-nanmean(x_tmp);
        y_tmp=1e3*squeeze(data.tdc.al_pulses.pos_stat(ii,:,3));
        y_tmp=y_tmp-nanmean(y_tmp);
        z_tmp=data.tdc.al_pulses.time_cen-squeeze(data.tdc.al_pulses.pos_stat(ii,:,1))';
        z_tmp=z_tmp'*anal_opts_osc_fit.global.velocity*1e3;
        z_tmp=z_tmp-nanmean(z_tmp);
        txyz_tmp=[data.tdc.al_pulses.time_cen';x_tmp;y_tmp;z_tmp];
        sqrtn=sqrt(data.tdc.al_pulses.num_counts(ii,:)); %find the statistical uncert in a single shot
        xerr=1e3*squeeze(data.tdc.al_pulses.pos_stat(ii,:,5))./sqrtn;
        yerr=1e3*squeeze(data.tdc.al_pulses.pos_stat(ii,:,6))./sqrtn;
        zerr=1e3*squeeze(data.tdc.al_pulses.pos_stat(ii,:,4))*anal_opts_osc_fit.global.velocity./sqrtn;
        xyzerr_tmp=[xerr;yerr;zerr];
        xyzerr_tmp(:,sqrtn<2)=nan;

        %remove any data pts with nan position
        mask=sum(isnan(txyz_tmp),1)==0;
        xyzerr_tmp=xyzerr_tmp(:,mask);
        txyz_tmp=txyz_tmp(:,mask);

        %try to find the peak osc freq to start the fit there
        if anal_opts_osc_fit.adaptive_freq
            out=fft_tx(txyz_tmp(1,:),txyz_tmp(anal_opts_osc_fit.dimesion+1,:),'padding',10,'window','hamming');
            [~,nearest_idx]=max(abs(out(2,:)));
            fit_freq=out(1,nearest_idx);
            %fft_phase=angle(out(2,nearest_idx))+0.535;
        else
            fit_freq=anal_opts_osc_fit.appr_osc_freq_guess(anal_opts_osc_fit.dimesion);
        end
        modelfun = @(b,x) exp(-x(:,1).*max(0,b(7))).*b(1).*sin(b(2)*x(:,1)*pi*2+b(3)*pi*2)+b(4)+b(8)*x(:,1)+b(5)*x(:,2)+b(6)*x(:,3);
        beta0=[std(txyz_tmp(anal_opts_osc_fit.dimesion+1,:))*8, fit_freq, 0, 1,0,0,2,0.01];
        cof_names={'amp','freq','phase','offset','ycpl','zcpl','damp','grad'};
        opt = statset('TolFun',1e-10,'TolX',1e-10,'MaxIter',1e4,...
            'UseParallel',1);
        %select the aproapriate values to go in the response variable
        idx=1:4;
        idx(anal_opts_osc_fit.dimesion+1)=[];
        predictor=txyz_tmp(idx,:)';
        weights=1./(xyzerr_tmp(anal_opts_osc_fit.dimesion,:).^2);
        weights(isnan(weights))=1e-20; %if nan then set to smallest value you can
        weights=weights/sum(weights);
        %predictor=[tvalues,xvalues,zvalues];
        fitobject=fitnlm(predictor,txyz_tmp(anal_opts_osc_fit.dimesion+1,:)',modelfun,beta0,...
            'Weights',weights,'options',opt,...
            'CoefficientNames',cof_names);
        osc_fit.model{ii}=fitobject;
        fitparam=fitobject.Coefficients;
        osc_fit.model_coefs(ii,:,:)=[fitparam.Estimate,fitparam.SE];
        osc_fit.fit_rmse(ii)=fitobject.RMSE;
        %limiting frequnecy prediction from http://adsabs.harvard.edu/full/1999DSSN...13...28M
        meanwidth=sqrt(mean(squeeze(data.tdc.al_pulses.pos_stat(ii,:,5)).^2))*1e3;
        frequnclim=sqrt(6/sum(data.tdc.al_pulses.num_counts(ii,:)))*...
            (1/(pi*range(data.tdc.al_pulses.time_cen)))*...
            (meanwidth/fitparam{2,1});
        %fprintf('sampling limit %2.3g Hz, fint unc %2.3g Hz, ratio %2.3g \n',[frequnclim,fitparam{2,2},fitparam{2,2}/frequnclim])
        osc_fit.fit_sample_limit{ii}=[frequnclim,fitparam{2,2},fitparam{2,2}/frequnclim];
        %%
        if anal_opts_osc_fit.plot_fits
            font_name='cmr10';
            font_size_global=20;
            folt_size_label=25;
            colors_main=[[255,0,0];[33,188,44];[0,0,0]]./255;
            lch=colorspace('RGB->LCH',colors_main(:,:));
            lch(:,1)=lch(:,1)+20;
            colors_detail=colorspace('LCH->RGB',lch);
            %would prefer to use srgb_2_Jab here
            color_shaded=colorspace('RGB->LCH',colors_main(3,:));
            color_shaded(1)=50;
            color_shaded=colorspace('LCH->RGB',color_shaded);


            tplotvalues=linspace(min(data.tdc.al_pulses.time_cen),...
                max(data.tdc.al_pulses.time_cen),1e5)';
            predictorplot=[tplotvalues,...
                       interp1(predictor(:,1),predictor(:,2),tplotvalues),...
                       interp1(predictor(:,1),predictor(:,3),tplotvalues)];
            [prediction,ci]=predict(fitobject,predictorplot);
            sfigure(51);
            set(gca,'FontSize',font_size_global,'FontName',font_name)
            
            subplot(2,1,1)
            plot(txyz_tmp(1,:),txyz_tmp(2,:),'kx-')
            hold on
            plot(txyz_tmp(1,:),txyz_tmp(3,:),'rx-')
            plot(txyz_tmp(1,:),txyz_tmp(4,:),'bx-')
            hold off
            ylabel('X Pos (mm)')
            xlabel('Time (s)')
            set(gca,'Ydir','normal')
            set(gcf,'Color',[1 1 1]);
            legend('x','y','z')

            subplot(2,1,2)
            shaded_ci_lines=false;
            hold on
            if shaded_ci_lines
                patch([predictorplot(:,1)', fliplr(predictorplot(:,1)')], [ci(:,1)', fliplr(ci(:,2)')], color_shaded,'EdgeColor','none');  %[1,1,1]*0.80
            else
                plot(predictorplot(:,1),ci(:,1),'-','LineWidth',1.5,'Color',color_shaded)
                plot(predictorplot(:,1),ci(:,2),'-','LineWidth',1.5,'Color',color_shaded)
            end  
            plot(predictorplot(:,1),prediction,'-','LineWidth',1.0,'Color',colors_main(3,:))
            ax = gca;
            set(ax, {'XColor', 'YColor'}, {'k', 'k'});
            errorbar(predictor(:,1),txyz_tmp(anal_opts_osc_fit.dimesion+1,:)',xyzerr_tmp(anal_opts_osc_fit.dimesion,:),'o','CapSize',0,'MarkerSize',5,'Color',colors_main(1,:),'MarkerFaceColor',colors_detail(1,:),'LineWidth',1.5) 
            set(gcf,'Color',[1 1 1]);
            xlabel('Time (s)','FontSize',folt_size_label)
            ylabel('X(mm)','FontSize',folt_size_label)
            title(sprintf('amp=%.2f�%.2f mm,omega=%.2f�%.2f Hz,Damp=%.2f�%.2f s',...
                fitobject.Coefficients.Estimate(1),fitobject.Coefficients.SE(1),...
                 fitobject.Coefficients.Estimate(2),fitobject.Coefficients.SE(2),...
                 fitobject.Coefficients.Estimate(7),fitobject.Coefficients.SE(7)))
            hold off
            ax = gca;
            set(ax, {'XColor', 'YColor'}, {'k', 'k'});
            set(gca,'linewidth',1.0)
            saveas(gca,sprintf('%sfit_dld_shot_num%04u.png',anal_opts_osc_fit.global.out_dir,dld_shot_num))
            drawnow
        end% PLOTS
        %%
    end
    if mod(ii,10)==0, fprintf('\b\b\b\b%04u',ii), end
end
fprintf('...Done\n')
%if the above did a fit then set the element in the logic vector to true
osc_fit.ok.did_fits=~cellfun(@(x) isequal(x,[]),osc_fit.model);

%% look for failed fits

%cut based on fit error
%look at the distribution of fit errors
mean_fit_rmse=nanmean(osc_fit.fit_rmse(osc_fit.ok.did_fits));
median_fit_rmse=nanmedian(osc_fit.fit_rmse(osc_fit.ok.did_fits));
std_fit_rmse=nanstd(osc_fit.fit_rmse(osc_fit.ok.did_fits));
fprintf('fit error: median %f mean %f std %f\n',...
   median_fit_rmse,mean_fit_rmse,std_fit_rmse)

%label anything std_cut_fac*std away from the median as a bad fit
std_cut_fac=4;
mask=osc_fit.ok.did_fits;
osc_fit.ok.rmse=mask & osc_fit.fit_rmse...
    < median_fit_rmse+std_cut_fac*std_fit_rmse;
%label the fits with trap freq more than 1hz awaay from the mean as bad
%osc_fit.ok.rmse(osc_fit.ok.rmse)=abs(osc_fit.model_coefs(osc_fit.ok.rmse,2,1)'...
%    -mean(osc_fit.model_coefs(osc_fit.ok.rmse,2,1)))<1;

%cut based on measured freq
median_fit_freq=nanmedian(osc_fit.model_coefs(osc_fit.ok.rmse,2,1));
osc_fit.ok.freq= abs(osc_fit.model_coefs(:,2,1)'-...
    median_fit_freq)<anal_opts_osc_fit.freq_fit_tolerance;


osc_fit.ok.all=osc_fit.ok.freq & osc_fit.ok.rmse;


if anal_opts_osc_fit.plot_err_history
    figure(52)
    clf
    set(gcf,'color','w')
    subplot(2,1,1)
    hist(osc_fit.fit_rmse(osc_fit.ok.did_fits))
    xlabel('RMSE')
    ylabel('counts')
    yl=ylim;
    hold on
    line([1,1]*mean_fit_rmse,yl,'Color','k')
    line([1,1]*median_fit_rmse,yl,'Color','m')
    line([1,1]*(mean_fit_rmse+std_cut_fac*std_fit_rmse),yl,'Color','r')
    line([1,1]*(mean_fit_rmse-std_cut_fac*std_fit_rmse),yl,'Color','r')
    hold off

    subplot(2,1,2)
    plot(osc_fit.fit_rmse(osc_fit.ok.did_fits))
    xlabel('shot idx')
    ylabel('RMSE')
    saveas(gca,sprintf('%sfits_rmse_history.png',anal_opts_osc_fit.global.out_dir))
    
end


if anal_opts_osc_fit.plot_fit_corr
    mask=osc_fit.ok.all;
    sfigure(53);
    clf
    set(gcf,'color','w')
    %see if the fit error depends on the probe freq
    subplot(3,3,1)
    tmp_probe_freq=data.wm_log.proc.probe.freq.act.mean(mask);
    tmp_probe_freq=(tmp_probe_freq-nanmean(tmp_probe_freq))*1e-3;
    plot(tmp_probe_freq,...
        osc_fit.fit_rmse(osc_fit.ok.all),'xk')
    xlabel('probe beam freq (GHz)')
    ylabel('fit error')
    title('Fit Error')
    %see if the damping changes
    subplot(3,3,2)
    plot(tmp_probe_freq,...
       osc_fit.model_coefs(mask,1,1),'xk')
    xlabel('probe beam freq (GHz)')
    ylabel('Osc amp (mm)')
    title('Amp')
    subplot(3,3,3)
    plot(tmp_probe_freq,...
       osc_fit.model_coefs(mask,3,1),'xk')
    xlabel('probe beam freq (GHz)')
    ylabel('Phase (rad)')
    title('Phase')
    subplot(3,3,4)
    plot(tmp_probe_freq,...
       osc_fit.model_coefs(mask,4,1),'xk')
    xlabel('probe beam freq (GHz)')
    ylabel('offset')
    title('offset')
    subplot(3,3,5)
    plot(tmp_probe_freq,...
       osc_fit.model_coefs(mask,5,1),'xk')
    xlabel('probe beam freq (GHz)')
    ylabel('ycpl')
    title('ycpl')
    subplot(3,3,6)
    plot(tmp_probe_freq,...
       osc_fit.model_coefs(mask,6,1),'xk')
    xlabel('probe beam freq (GHz)')
    ylabel('zcpl')
    title('zcpl')
    %see if the amp changes
    subplot(3,3,7)
    plot(tmp_probe_freq,...
       1./osc_fit.model_coefs(mask,7,1),'xk')
    xlabel('probe beam freq (GHz)')
    ylabel('Damping Time (s)')
    title('Damping')
    subplot(3,3,8)
    plot(tmp_probe_freq,...
       osc_fit.model_coefs(mask,8,1),'xk')
    xlabel('probe beam freq (GHz)')
    ylabel('Grad mm/s')
    title('Grad')
    %look for anharminicity with a osc amp/freq correlation
    subplot(3,3,9)
    plot(abs(osc_fit.model_coefs(mask,1,1)),...
        osc_fit.model_coefs(mask,2,1),'xk')
    xlabel('osc (mm)')
    ylabel('fit freq (Hz)')
    title('anharmonicity')

    set(gcf, 'Units', 'pixels', 'Position', [100, 100, 1600, 900])
    plot_name='fit_correlations';
    saveas(gcf,[anal_opts_osc_fit.global.out_dir,plot_name,'.png'])
    saveas(gcf,[anal_opts_osc_fit.global.out_dir,plot_name,'.fig'])
end



end