function [db_IMG] = DAS(Param)
%% DAS - Rx Focusing
disp("DSC");
[depth, ~, ~] = size(Param.RF_data_org);

x_ch = Param.x_pos(Param.Tr.noElement/2-Param.Tr.noChannel/2+1 : Param.Tr.noElement/2+Param.Tr.noChannel/2);
z_ch = Param.z_pos(Param.Tr.noElement/2-Param.Tr.noChannel/2+1 : Param.Tr.noElement/2+Param.Tr.noChannel/2);

%%% delay and sum process
for j = 1: Param.BF.noScanline
    %disp([ num2str(j) ' Scanline processing ...']);
    for k = 1:Param.MinDepth
        R = k*Param.Dunit/2;
        for ch = 1:length(x_ch)
                    Delay = round((sqrt((x_ch(ch))^2 + R^2) + R) / Param.Dunit);
            if Delay <=0
                continue;
            end
            if Delay > Param.MinDepth
                image_das(k, ch) = 0;
            else
                image_das(k, ch) = Param.RF_data_org(Delay,ch,j);
            end
        end
        IMG_DATA(k, j) = sum(image_das(k,:));       % delay summation
    end
end

QDM_DAS = hilbert(IMG_DATA);
Env_DAS = abs(QDM_DAS(:,:));

db_IMG=20*log10(Env_DAS./max(max(Env_DAS)));
db_IMG(db_IMG<-Param.DR) = -Param.DR;

 figure,
 imagesc(db_IMG);
 colormap gray; colorbar; axis image;
 title(['B-mode (DAS) ' num2str(Param.DR) 'dB'])


%% DSC
IMG_DSC = zeros(Param.disp.Row, Param.disp.Col);
for x = 1 : Param.disp.Col
    for z = 1 : Param.disp.Row
        
        pixel_x_pos = (x - Param.disp.Xctr)*Param.pixelDist; % 현재 픽셀의 x 좌표
        pixel_z_pos = (z - Param.disp.Zstr)*Param.pixelDist; % 현재 픽셀의 z 좌표
        
        
        if(pixel_x_pos >= Param.img.ROI(1) && pixel_x_pos <= Param.img.ROI(2) && pixel_z_pos >= Param.img.ROI(3) && pixel_z_pos <= Param.img.ROI(4)) % 여기서 문제?
            
            


            pixel_z_sc = round( pixel_z_pos  / Param.Dunit);


            % define scanline
            % 좌우 방향
            distance_x = abs(Param.x_sc - pixel_x_pos);
            sorted_distance = sort(distance_x);

            S_L.idx = find(distance_x == sorted_distance(1));
            S_R.idx = find(distance_x == sorted_distance(2));
            
            S_L.dis = sorted_distance(1);
            S_R.dis = sorted_distance(2);
            
            % 상하 방향
            S_U.idx = pixel_z_sc + 1;
            S_D.idx = pixel_z_sc - 1;

            S_U.dis = (S_U.idx * Param.Dunit) - R;
            S_D.dis = (S_D.idx * Param.Dunit) - R;
            

            if(S_L.idx > S_R.idx) 
                temp = S_R.idx;
                S_R.idx = S_L.idx;
                S_L.idx = temp;

                temp = S_R.dis;
                S_R.dis = S_L.dis;
                S_L.dis = temp;
            end

            if(S_U.idx <= Param.MinDepth && S_D.idx <= Param.MinDepth && S_U.idx > 0 && S_D.idx > 0)
                assignin('base', 'SD_idx', S_D.idx);
                assignin('base', 'SL_idx', S_L.idx);
                S_UL = IMG_DATA(S_U.idx, S_L.idx);
                S_UR = IMG_DATA(S_U.idx, S_R.idx);
                S_DL = IMG_DATA(S_D.idx, S_L.idx);
                S_DR = IMG_DATA(S_D.idx, S_R.idx);
    
                Z_L = S_D.dis*S_UL + S_U.dis*S_DL;
                Z_R = S_D.dis*S_UR + S_U.dis*S_DR;
    
                Z = S_L.dis*Z_R + S_R.dis*Z_L;

                IMG_DSC(z,x) = Z;
            else IMG_DSC(z,x) = 0;
            end

            
          
        end
    
    
    
    end
end



%% Step 6. Back-end
%%% Envelope detection & log compression
QDM_DAS = hilbert(IMG_DSC);
Env_DAS = abs(QDM_DAS(:,:));

db_IMG=20*log10(Env_DAS./max(max(Env_DAS)));
db_IMG(db_IMG<-Param.DR) = -Param.DR;