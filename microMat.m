%##########################################################################
%           Building a GUI for Micromanager 
%           Author: Chase Porter               
%
%           3/9/16 : Implemented both real time and single snap image
%           taking. For both real time imaging and snap shot you can decide
%           if you want color bar. For single imaging, you can either take
%           a one shot image or you can take a snap shot of the the live
%           stream. 
%           
%           3/11/16: Colorbar, realtime, single image, logscale, and
%           setting values for colorbar are all working. I created a
%           function called update_GUI which I call after every button is
%           pushed that checks the state of all my booleans to make the
%           appropriate changes. Still need to implement cropping and unit
%           handling. Also would like there to be a display of the various
%           states of the booleans I use so we know what is active and what
%           is not. Might do that before I leave today.
%           
%           3/28/16: All features implemented. Think there may be some
%           problems using actual camera and trying to get it to run fast
%           enough. Will try and speed that up later. 
%
%           4/27/16: Cleaned up the GUI and optimized implemenatation.
%           Now, before calculating an FFT, the code will check to see
%           if the computer has a GPU and use that instead of calculating
%           it in RAM. Also added a Histogram as well as a sliding bar to
%           set the colorbar axis. I also resolved the issue that to
%           display realtime updates I had to have a separate figure by
%           setting the data of the GUI figure rather than calling imshow
%           repeatedly. This also sped up the realtime processing. I also
%           added a way to normalize the FFT for the colorbar and changed
%           the interface for adding a colorbar and changing to log scale
%           from buttons to check boxes. 
%
%           5/3/16: Smoothed out bugs with changing the caxis with the
%           sliding bars instead of having to manually input a ymin and
%           ymax. Also fixed an error where normalizing and then
%           denormalizing would cause the values of the sliding bar to
%           become offset. Taking a log scale of a normalized fft and
%           undoing log scale of a normalized log scaled fft didn't make
%           sense so I included warnings to prevent a user from doing this.
%           Also put back in cropping. There is a slight slow down that
%           comes along with setting a different crop scale (because to do
%           this I have to call imshow again) so to prevent Matlab from
%           crashing during realtime from this lag I included a warning to
%           turn off reatime before cropping. Am now using demosaic so the
%           user can run the GUI from a color camera as well. Possible bugs
%           for doing this would be trying to demosaic a camera that only
%           does gray scale, this could cause the program to crash. 
%           
%
%
%
%           IMPLEMENTATION NOTE: Make sure example.m and example.fig are
%           both in the Micro-Manager-1.4 program folder.
%
%##########################################################################


function varargout = microMat(varargin)
% MICROMAT MATLAB code for microMat.fig
%      MICROMAT, by itself, creates a new MICROMAT or raises the existing
%      singleton*.
%
%      H = MICROMAT returns the handle to a new MICROMAT or the handle to
%      the existing singleton*.
%
%      MICROMAT('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MICROMAT.M with the given input arguments.
%
%      MICROMAT('Property','Value',...) creates a new MICROMAT or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before microMat_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to microMat_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help microMat

% Last Modified by GUIDE v2.5 05-May-2016 13:01:01

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @microMat_OpeningFcn, ...
                   'gui_OutputFcn',  @microMat_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before microMat is made visible.
function microMat_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to microMat (see VARARGIN)

% Choose default command line output for microMat
handles.output = hObject;

% UIWAIT makes speed_up wait for user response (see UIRESUME)
% uiwait(handles.figure1);
handles.timer = timer(...
    'ExecutionMode', 'fixedRate', ...       % Run timer repeatedly
    'Period', .5, ...                        % Initial period is 1 sec.
    'TimerFcn', {@update_display,hObject}); % Specify callback function
set(handles.popupmenu1, 'String', {'1', '1/2', '1/4', '1/8'});
set(handles.popupmenu2, 'String', {'Center', 'Left', 'Right'});
set(handles.popupmenu3, 'String', {'Gray', 'Jet'});
set(handles.popupmenu4, 'String', {'Jet', 'Gray'});

global core imgWidth imgHeight ax1 ax2 gpu_num h h0 h1 h2 pixelsize labels c l ymin ymax pix smaller crop pos prev_max f rgb r g b fftchan exp_time
si = StartMMStudio;
core = si.getCore;

imgWidth = core.getImageWidth;
imgHeight = core.getImageHeight;
pixelsize = core.getPixelSizeUm();
labels = [-256*pixelsize: 255*pixelsize];

crop = 1;
pos = 0;
c = false;
l = false;
ymin = 0;
rgb = false;
r = true;
b = true;
g = true;
fftchan = 1;
exp_time = 10;
set(handles.checkbox5, 'Value', 1)
set(handles.checkbox6, 'Value', 1)
set(handles.checkbox7, 'Value', 1)

core.snapImage();
img = core.getImage();
pix = imrotate(reshape(img, imgWidth, imgHeight), -90);
f = (abs(fftshift(fft2(double(pix)))));
ymax = max(max(f));
prev_max = ymax;

set(handles.slider1, 'min', 0, 'max', ymax)
set(handles.slider2, 'min', 0, 'max', ymax)
set(handles.slider2, 'Value', ymax)
set(handles.text17, 'String', num2str(ymax))
set(handles.text18, 'String', num2str(ymax))
set(handles.edit2, 'String', num2str(ymin))
set(handles.edit3, 'String', num2str(ymax))

axes(handles.axes1)
h = imshow(pix, []);
histogram(handles.axes3, pix);
set(handles.text20, 'String', num2str(min(min(pix))))
set(handles.text22, 'String', num2str(max(max(pix))))


showaxes('on');
axes(handles.axes2)
h0 = imagesc(labels, labels, f);
colormap(handles.axes2, jet)
figure('Position', [100, 300, 1000, 400]);
ax1 = subplot(1,2,1);
h1 = imshow(pix, []);
showaxes('on');
ax2 = subplot(1,2,2);
h2 = imagesc(labels, labels, f);

set(handles.axes1, 'xdir', 'reverse');
set(ax1, 'xdir', 'reverse');

try
    gpu_num = gpuDeviceCount; %Determines if there is a CUDA enabled GPU
catch err
    gpu_num = 0;
end

% Update handles structure
guidata(hObject, handles);

function update_display(hObject,eventdata,hfigure)
% Timer timer1 callback, called each time timer iterates.
% END USER CODE
%
global core imgWidth imgHeight ax1 ax2 gpu_num h h0 smaller l c ymin ymax f n prev_max rgb r b g fftchan
handles = guidata(hfigure);
img = uint16(reshape(core.getImage(),imgWidth,imgHeight));
if rgb
   img = demosaic(img, 'rggb'); 
   if ~r
       img(:, :, 1) = 0;
   end
   if ~g
       img(:, :, 2) = 0;
   end
   if ~b
       img(:, :, 3) = 0;
   end
end
pix = rot90(img);
cropimage(pix);
histogram(handles.axes3, smaller);
set(handles.text20, 'String', num2str(min(min(smaller))))
set(handles.text22, 'String', num2str(max(max(smaller))))
if rgb
    pix1 = pix(:, :, fftchan);
else
    pix1 = pix;
end
if gpu_num > 0
    pix1 = gpuArray(pix1);
    if l
        f = gpuArray(log(abs(fftshift(fft2(double(pix1))))));
    else 
        f = gpuArray(abs(fftshift(fft2(double(pix1)))));
    end
    prev_max = max(max(f));
    prev_max = gather(prev_max);
    if n
        f = gpuArray(f/max(max(f)));
    end
    f = gather(f);
else
    if l
        f = (log(abs(fftshift(fft2(double(pix1))))));
    else 
        f = (abs(fftshift(fft2(double(pix1)))));
    end
    prev_max = max(max(f));
    if n 
        f = f/max(max(f));
    end
end
set(h, 'CData', smaller);
set(h0, 'CData', f);


function update_GUI(handles)
% handles    structure with handles and user data (see GUIDATA)
global h h0 h1 h2 smaller pix f c ymin ymax ax1 ax2 cb cb1
cropimage(pix);
smaller = pix;
if strcmp(get(handles.timer, 'Running'), 'off')
    set(h, 'CData', smaller);
    set(h0, 'CData', f);
else
    set(h1, 'CData', smaller);
    showaxes('on');
    set(h2, 'CData', f);
    if c 
        colorbar(ax2);
        if ymin < ymax
        caxis(ax2, [ymin ymax]);
        end
    else
        delete(cb1);
    end
end

% -- Crops an image
function cropimage(image)
global smaller crop pos rgb
d = size(image);
b1 = d(1)*crop;
b2 = d(2)*crop;
r1 = ceil(d(1)/2 - b1/2) + 1;
r2 = floor(d(1)/2 + b1/2);
switch pos
    case 0
        c1 = ceil(d(2)/2 - b2/2) + 1;
        c2 = floor(d(2)/2 + b2/2);
        if rgb
            smaller = image(r1:r2, c1:c2, :);
        else
            smaller = image(r1:r2, c1:c2);
        end
    case 1
        if rgb
            smaller = image(r1:r2, 1:b2, :);
        else
            smaller = image(r1:r2, 1:b2);
        end
    case 2
        if rgb
            smaller = image(r1:r2, (d(2)-b2 + 1):d(2), :);
        else
            smaller = image(r1:r2, (d(2)-b2 + 1):d(2));
        end
end


% -- Sets real time on
% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global core
if strcmp(get(handles.timer, 'Running'), 'on')
    stop(handles.timer);
    core.stopSequenceAcquisition();
    set(handles.text3, 'String', 'Off');
else
    set(handles.text3, 'String', 'On');
    core.startContinuousSequenceAcquisition(1);
    start(handles.timer);
end


% -- Takes a snapshot
% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global core imgWidth imgHeight smaller pix gpu_num f l n prev_max rgb r g b fftchan
if strcmp(get(handles.timer, 'Running'), 'off')
    core.snapImage()
    img = uint16(reshape(core.getImage(),imgWidth,imgHeight));
    if rgb
        img = demosaic(img, 'rggb'); 
        if ~r
            img(:, :, 1) = 0;
        end
        if ~g
            img(:, :, 2) = 0;
        end
        if ~b
            img(:, :, 3) = 0;
        end
    end
    pix = rot90(img);
    if rgb
        pix1 = pix(:, :, fftchan);
    else
        pix1 = pix;
    end
    if gpu_num > 0
        pix1 = gpuArray(pix1);
        if l
            f = gpuArray(log(abs(fftshift(fft2(double(pix1))))));
        else    
            f = gpuArray(abs(fftshift(fft2(double(pix1)))));
        end
        prev_max = max(max(f));
        prev_max = gather(prev_max);
        if n
            f = gpuArray(f/max(max(f)));
        end
        f = gather(f);
    else   
        if l
            f = (log(abs(fftshift(fft2(double(pix1))))));
        else 
            f = (abs(fftshift(fft2(double(pix1)))));
        end
        prev_max = max(max(f));
        if n
            f = f/max(max(f));
        end
    end
end
update_GUI(handles);


% -- Normalizes FFT
% --- Executes on button press in checkbox1.
function checkbox1_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox1
global n l f ymin ymax prev_max
if get(hObject, 'Value')
    n = true;
    ymin = ymin/prev_max;
    ymax = ymax/prev_max;
    set(handles.slider1, 'Value', ymin);
    set(handles.slider2, 'Value', ymax);
    set(handles.slider1, 'min', 0, 'max', 1);
    set(handles.slider2, 'min', 0, 'max', 1);
    set(handles.text17, 'String', '1');
    set(handles.text18, 'String', '1');
else
    n = false;
    ymin = ymin*prev_max;
    ymax = ymax*prev_max;
    set(handles.slider1, 'min', 0, 'max', prev_max);
    set(handles.slider2, 'min', 0, 'max', prev_max);
    set(handles.slider1, 'Value', ymin);
    set(handles.slider2, 'Value', ymax);
    set(handles.text17, 'String', num2str(prev_max));
    set(handles.text18, 'String', num2str(prev_max));
end
set(handles.edit2, 'String', num2str(ymin))
set(handles.edit3, 'String', num2str(ymax))
if ( strcmp(get(handles.timer, 'Running'), 'off'))
    if n
        f = f/(max(max(f)));
    else
        f = f * prev_max;
    end
    update_GUI(handles);
end
caxis(handles.axes2, [ymin ymax]);

% -- Adds colorbar
% --- Executes on button press in checkbox2.
function checkbox2_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox2
global cb c
axes(handles.axes2)
if get(hObject, 'Value')
    c = true;
    cb = colorbar;
else
    c = false;
    delete(cb);
end

% -- Adds Log Scale
% --- Executes on button press in checkbox3.
function checkbox3_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox3
global l pix f n gpu_num prev_max ymin ymax
if n
    set(handles.checkbox3, 'Value', ~get(handles.checkbox3, 'Value'))
    w = warndlg('DeNormalize first and then ReNormalize if desired.');
else
    if get(hObject, 'Value')
        l = true;
        if ymin > 0
            ymin = log(ymin);
        end
        if ymax > 0
            ymax = log(ymax);
        end
        prev_max = log(prev_max);
        set(handles.slider1, 'Value', ymin);
        set(handles.slider2, 'Value', ymax);
        set(handles.slider1, 'max', prev_max);
        set(handles.slider2, 'max', prev_max);
    else
        l = false;
        ymin = exp(ymin);
        ymax = exp(ymax);
        prev_max = exp(prev_max);
        set(handles.slider1, 'max', prev_max);
        set(handles.slider2, 'max', prev_max);
        set(handles.slider1, 'Value', ymin);
        set(handles.slider2, 'Value', ymax);

    end
    set(handles.text17, 'String', num2str(prev_max));
    set(handles.text18, 'String', num2str(prev_max));
    set(handles.edit2, 'String', num2str(ymin))
    set(handles.edit3, 'String', num2str(ymax))
    if strcmp(get(handles.timer, 'Running'), 'off')
        pushbutton3_Callback(hObject, eventdata, handles)
    end
    caxis(handles.axes2, [ymin ymax]);
end

% -- Sets the timer
function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double
global period 
period = str2double(get(hObject, 'String'));

% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% -- Sets the timer. 
% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global period
set(handles.timer, 'Period', period);

% -- Magic Button
% --- Executes on button press in pushbutton4.
function pushbutton4_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global core;
core.stopSequenceAcquisition();

% -- Sets the ymin of the colorbar
function edit2_Callback(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit2 as text
%        str2double(get(hObject,'String')) returns contents of edit2 as a double
global ymin;
ymin = str2double(get(hObject, 'String'));
set(handles.slider1, 'Value', ymin)

% --- Executes during object creation, after setting all properties.
function edit2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% -- Sets the ymax of the colorbar
function edit3_Callback(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit3 as text
%        str2double(get(hObject,'String')) returns contents of edit3 as a double
global ymax;
ymax = str2double(get(hObject, 'String'));
set(handles.slider2, 'Value', ymax)

% --- Executes during object creation, after setting all properties.
function edit3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% -- Sets colorbar ymin using slider
% --- Executes on slider movement.
function slider1_Callback(hObject, eventdata, handles)
% hObject    handle to slider2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
global ymin
ymin = get(hObject, 'Value');
set(handles.edit2, 'String', num2str(ymin))

% --- Executes during object creation, after setting all properties.
function slider1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% -- Sets the colorbar ymax with the slider
% --- Executes on slider movement.
function slider2_Callback(hObject, eventdata, handles)
% hObject    handle to slider3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
global ymax
ymax = get(hObject, 'Value');
set(handles.edit3, 'String', num2str(ymax))

% --- Executes during object creation, after setting all properties.
function slider2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% -- Sets the caxis
% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ymin ymax cb
if (ymin > ymax) 
    w = warndlg('Ymin must be less than Ymax');
else
    caxis(handles.axes2, [ymin ymax]);
end

% - Specifies file to save data to.
function edit4_Callback(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit4 as text
%        str2double(get(hObject,'String')) returns contents of edit4 as a double
global filename;
filename = get(hObject, 'String');

% --- Executes during object creation, after setting all properties.
function edit4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% -- Saves data into a file
% --- Executes on button press in pushbutton8.
function pushbutton6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global pix filename f;
savefile = char(strcat(filename, '.mat'));
save(['C:\Program Files\Micro-Manager-1.4\Data files\',savefile], 'pix', 'f');
set(handles.text15, 'String', ['Data Saved to ', savefile]);

% -- Changes crop scale
% --- Executes on selection change in popupmenu2.
function popupmenu1_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu2
global crop pix smaller h;
if strcmp(get(handles.timer, 'Running'), 'on')
    w = warndlg('Turn off Realtime before setting crop window.');
else
    contents = cellstr(get(hObject, 'String'));
    crop = str2num(contents{get(hObject, 'Value')});
    cropimage(pix)
    axes(handles.axes1)
    h = imshow(smaller, []);
    showaxes('on')
end

% --- Executes during object creation, after setting all properties.
function popupmenu1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% -- Changes Crop selection
% --- Executes on selection change in popupmenu3.
function popupmenu2_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu3 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu3
global pos
if strcmp(get(handles.timer, 'Running'), 'on')
    w = warndlg('Turn off Realtime before setting crop window.');
else
    contents = cellstr(get(hObject, 'String'));
    val = contents{get(hObject, 'Value')};
    switch val
        case 'Center'
            pos = 0;
        case 'Left'
            pos = 1;
        case 'Right'
            pos = 2;
    end
    update_GUI(handles)
end

% --- Executes during object creation, after setting all properties.
function popupmenu2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% -- Changes Colormap of Image
% --- Executes on selection change in popupmenu4.
function popupmenu3_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu4 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu4
contents = cellstr(get(hObject, 'String'));
val = contents{get(hObject, 'Value')};
colormap(handles.axes1, val);

% --- Executes during object creation, after setting all properties.
function popupmenu3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% -- Changes Colormap of FFT
% --- Executes on selection change in popupmenu5.
function popupmenu4_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu5 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu5
contents = cellstr(get(hObject, 'String'));
val = contents{get(hObject, 'Value')};
colormap(handles.axes2, val);


% --- Executes during object creation, after setting all properties.
function popupmenu4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Outputs from this function are returned to the command line.
function varargout = microMat_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


%-- Sets the Pixel Size
function edit5_Callback(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit5 as text
%        str2double(get(hObject,'String')) returns contents of edit5 as a double
global pixelsize
pixelsize = str2double(get(hObject, 'String'));


% --- Executes during object creation, after setting all properties.
function edit5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--Sets the Pixelsize 
% --- Executes on button press in pushbutton7.
function pushbutton7_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global pixelsize
pixelsize = pixelsize;

% -- Sets RGB
% --- Executes on button press in checkbox4.
function checkbox4_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox4
global rgb 
if get(hObject, 'Value')
    rgb = true;
else
    rgb = false;
end

% -- Chooses only R channel
% --- Executes on button press in checkbox5.
function checkbox5_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox5
global r fftchan g 
if get(hObject, 'Value')
    r = true;
    fftchan = 1;
else
    r = false;
    if g 
        fftchan = 2;
    else
        fftchan = 3;
    end
end

% -- Chooses G channel
% --- Executes on button press in checkbox6.
function checkbox6_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox6
global g
if get(hObject, 'Value')
    g = true;
else
    g = false;
end

% -- Chooses only B channel
% --- Executes on button press in checkbox7.
function checkbox7_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox7
global b
if get(hObject, 'Value')
    b = true;
else
    b = false;
end


% -- Sets exposure Time
function edit6_Callback(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit6 as text
%        str2double(get(hObject,'String')) returns contents of edit6 as a double
global exp_time
exp_time = str2double(get(hObject,'String'))

% --- Executes during object creation, after setting all properties.
function edit6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% -- Sets Exposure time 
% --- Executes on button press in pushbutton8.
function pushbutton8_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global exp_time
if strcmp(get(handles.timer, 'Running'), 'off')
    core.setExposure(exp_time);
else
    w = warndlg('Turn off Realtime before setting exposure.');
end
