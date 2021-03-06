clc;
clear;
if exist('../caffe/matlab/+caffe', 'dir')
    addpath('../caffe/matlab');
else
    error('Please run this demo from caffe/matlab/demo');
end
%%
num_of_points = 19;
imglist = 'aflw_img_list.txt'; 

IMG_DIM = 448; %120;
model_file = '../Models/ALFW/network_aflw_parts.caffemodel';
model_def_file = '../Models/ALFW/network_aflw_parts.prototxt';

gpuDevice = [0];
caffe.set_mode_gpu();
caffe.set_device(gpuDevice);
% Initialize a network
phase = 'test';
net = caffe.Net(model_def_file, model_file, phase);

vis_result = 1;
lists = textread(imglist,'%s');
rct_list = regexprep(lists,'\.jpg','\.rct');
pts_list = regexprep(lists,'\.jpg','\.pts');

num = length(lists);
detected_points = zeros(num_of_points,2,num);
ground_truth = zeros(num_of_points,2,num);
align_errors = zeros(num,1);
for j = 1:num
    
    fprintf('%d/%d\n',j,num);
    try
        src_img = imread(lists{j});
    catch
        error('Image open fail,may the directory is error!');
    end
    if ndims(src_img)==2
        src_img = cat(3,src_img,src_img,src_img);
    end
    
    %% expand face roi
    if 1
        sh_scale = 0.0;
        rct = importdata(rct_list{j});
        src_rct = rct;
        [row, col, ~] = size(src_img);
        w = rct(3) - rct(1) + 1;
        h = rct(4) - rct(2) + 1;
        rct(1) = rct(1) - sh_scale*w;
        rct(2) = rct(2) - sh_scale*h;
        rct(3) = rct(3) + sh_scale*w;
        rct(4) = rct(4) + sh_scale*h;
        rct = round(rct);
        if rct(1)<=0;
            rct(1) = 1;
        end
        if rct(2)<=0;
            rct(2) = 1;
        end
        if rct(3)>col;
            rct(3) = col;
        end
        if rct(4)>row;
            rct(4) = row;
        end
        g_pts = importdata(pts_list{j});
        ground_truth(:,:,j) = g_pts(:,1:2);
    end
    
    %%
    im = src_img(rct(2):rct(4),rct(1):rct(3),:);
    im = imresize(im,[IMG_DIM,IMG_DIM]); %,'bilinear'
    
    im = single(im);
    images = zeros(IMG_DIM,IMG_DIM,3,1,'single');
    im_data = im(:, :, [3, 2, 1]);  % permute channels from RGB to BGR
    images(:,:,:, 1) = permute(im_data, [2, 1, 3]);
    input_data = {images};
    
    tic;
    %     net.reshape_as_input(input_data);
    scores = net.forward(input_data);
    fea = scores{1};
    toc;
    
    %%
    pts = (fea +1) * IMG_DIM/2;
    img = imread(lists{j});
    imshow(img);
    hold on
    scale_x = (rct(3)-rct(1)+1)/IMG_DIM;
    scale_y = (rct(4)-rct(2)+1)/IMG_DIM;
    pre_pts = zeros(num_of_points,2);
    for k=1:num_of_points
        pre_pts(k,1) = pts(2*k-1) * scale_x + rct(1);
        pre_pts(k,2) = pts(2*k) * scale_y + rct(2);
    end
    pre_pts = pre_pts([1:3 7:9 4:6 10:end],:);
    detected_points(:,:,j) = pre_pts;
    %% show result
    if vis_result==1
        imshow(src_img);
        hold on
        w = src_rct(3)-src_rct(1)+1;
        h = src_rct(4)-src_rct(2)+1;
        l_w = min(max(round(w/100),3),5);
        p_w = min(max(5,round(w/15)),20);
        rectangle('Position',[src_rct(1),src_rct(2),w,h],'EdgeColor','b','LineWidth',l_w) ;
        % draw pre pts
        plot(detected_points(:,1,j),detected_points(:,2,j),'g.','LineWidth',2,'MarkerSize',p_w);
        % draw gt pts
        plot(ground_truth(:,1,j),ground_truth(:,2,j),'r.','LineWidth',2,'MarkerSize',p_w);
        pause();        
        close all
    end
    close all
end
caffe.reset_all();
