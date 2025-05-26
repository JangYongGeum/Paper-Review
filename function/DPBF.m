function [db_IMG] = DPBF(Param)
%% DPBF
disp("DPBF");
for x = 1 : Param.disp.Col
    for z = 1 : Param.disp.Row
        pixel_x_pos = (x - Param.disp.Xctr)*Param.pixelDist; % 현재 픽셀의 x 좌표
        pixel_z_pos = (z - Param.disp.Zstr)*Param.pixelDist; % 현재 픽셀의 z 좌표
        IMG_data(z, x) = 0; 
   
         if(pixel_x_pos >= Param.img.ROI(1) && pixel_x_pos <= Param.img.ROI(2) && pixel_z_pos >= Param.img.ROI(3) && pixel_z_pos <= Param.img.ROI(4))
         
            distance = abs(Param.x_sc - pixel_x_pos);
            idx = find(distance == min(distance));

            for k = 1 : Param.Tr.noChannel

                apo_ch = ones(1, Param.Tr.noChannel);
                apo = [zeros(1, idx-1) apo_ch zeros(1, Param.Tr.noElement - idx - Param.Tr.noChannel+1)]; % 활성화된 element(=1)의 물리적 배열..?
                pos_apo = find(apo);

                Delay_tx = sqrt(( pixel_x_pos - Param.x_sc(idx) )^2 + (pixel_z_pos - Param.z_sc(idx) )^2);
                Delay_rx = sqrt(( pixel_x_pos - Param.x_pos(pos_apo(:,k)))^2 + ( pixel_z_pos - Param.z_pos(pos_apo(:,k)))^2);
                
                Delay = round((Delay_tx + Delay_rx)/Param.Dunit);

                
                
                if Delay <= 0
                    continue;
                end
                if Delay > Param.MinDepth %Param.depth
                    image_das(z,k)=0;
                else
                    image_das(z,k)=Param.RF_data_org(Delay, k, idx);
                end
                IMG_data(z, x) = sum(image_das(z,:));       % delay summation
            end
         
         end
    end
end


xdc_free(Param.Tx);
xdc_free(Param.Rx);


%% Step 6. Back-end
%%% Envelope detection & log compression
QDM_DAS = hilbert(IMG_data);
Env_DAS = abs(QDM_DAS(:,:));

db_IMG=20*log10(Env_DAS./max(max(Env_DAS)));
db_IMG(db_IMG<-Param.DR) = -Param.DR;