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
% button1    (line 220) = realtime
% button3    (line 239) = single snap shot
% button2    (line 260) = colorbar
% edit1      (line 269) = set ymin of colorbar
% edit2      (line 292) = set ymax of colorbar
% button4    (line 316) = set caxis to ymin and ymax
% popupmenu1 (line 325) = crop scale (1, 1/2, 1/4, 1/8)
% popupmenu2 (line 351) = crop position (center, left, right)
% button5    (line 386) = plot fft in log scale
% edit6      (line 395) = specify file to save data to (do not include .mat)
% button6    (line 419) = save current data
%           
%
%           IMPLEMENTATION NOTE: Make sure example.m and example.fig are
%           both in the Micro-Manager-1.4 program folder.
%
%##########################################################################



function varargout = speed_up(varargin)
% SPEED_UP MATLAB code for speed_up.fig
%      SPEED_UP, by itself, creates a new SPEED_UP or raises the existing
%      singleton*.
%
%      H = SPEED_UP returns the handle to a new SPEED_UP or the handle to
%      the existing singleton*.
%
%      SPEED_UP('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SPEED_UP.M with the given input arguments.
%
%      SPEED_UP('Property','Value',...) creates a new SPEED_UP or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before speed_up_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to speed_up_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help speed_up

% Last Modified by GUIDE v2.5 25-Apr-2016 11:23:46

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @speed_up_OpeningFcn, ...
                   'gui_OutputFcn',  @speed_up_OutputFcn, ...
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

% --- Executes just before speed_up is made visible.
function speed_up_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to speed_up (see VARARGIN)

% Choose default command line output for speed_up
handles.output = hObject;

cd 'C:\Program Files\Micro-Manager-1.4'

% UIWAIT makes speed_up wait for user response (see UIRESUME)
% uiwait(handles.figure1);
handles.timer = timer(...
    'ExecutionMode', 'fixedRate', ...       % Run timer repeatedly
    'Period', .5, ...                        % Initial period is 1 sec.
    'TimerFcn', {@update_display,hObject}); % Specify callback function
set(handles.popupmenu2, 'String', {'1', '1/2', '1/4', '1/8'});
set(handles.popupmenu3, 'String', {'Center', 'Left', 'Right'});
set(handles.popupmenu4, 'String', {'Gray', 'Jet'});
set(handles.popupmenu5, 'String', {'Jet', 'Gray'});

global core imgWidth imgHeight ax1 ax2 gpu_num h h0 h1 h2 pixelsize labels c l ymin ymax pix smaller crop pos prev_max
%si = StartMMStudio;
%core = si.getCore;

imgWidth = core.getImageWidth;
imgHeight = core.getImageHeight;
pixelsize = core.getPixelSizeUm();
labels = [-256*pixelsize: 255*pixelsize];

crop = 1;
pos = 0;
c = false;
l = false;
ymin = 0;
ymax = 0;

core.snapImage();
img = core.getImage();
pix = imrotate(reshape(img, imgWidth, imgHeight), -90);
smaller = imresize(pix, 1/5);
f = (abs(fftshift(fft2(double(pix)))));
prev_max = max(max(f));

set(handles.slider2, 'min', 0, 'max', prev_max)
set(handles.slider3, 'min', 0, 'max', prev_max)

axes(handles.axes1)
h = imshow(smaller, []);

showaxes('on');
axes(handles.axes2)
h0 = imagesc(labels, labels, f);
colormap(handles.axes2, jet)
figure('Position', [100, 300, 1000, 400]);
ax1 = subplot(1,2,1);
h1 = imshow(smaller, []);
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
global core imgWidth imgHeight ax1 ax2 gpu_num h h0 smaller l c ymin ymax f n
handles = guidata(hfigure);
img = core.getLastImage();
pix = imrotate(reshape(img, imgWidth, imgHeight), -90);
smaller = imresize(pix, 1/5);
histogram(handles.axes3, smaller);
%crop_img(handles);
if gpu_num > 0
    pix1 = gpuArray(pix);
    if l
        f = gpuArray(log(abs(fftshift(fft2(double(pix1))))));
    else 
        f = gpuArray(abs(fftshift(fft2(double(pix1)))));
    end
    if n
        f = gpuArray(f/max(max(f)));
    end
    f = gather(f);
else
    if l
        f = (log(abs(fftshift(fft2(double(pix))))));
    else 
        f = (abs(fftshift(fft2(double(pix)))));
    end
    if n 
        f = f/max(max(f));
    end
end
set(h, 'CData', smaller);
set(h0, 'CData', f);

function update_GUI(handles)
% handles    structure with handles and user data (see GUIDATA)
global h h0 h1 h2 smaller pix f c ymin ymax ax1 ax2 cb cb1
%crop_img(handles);
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

function crop_img(handles)
global pix crop pos smaller
d = size(pix);
b1 = d(1)*crop;
b2 = d(2)*crop;
r1 = ceil(d(2)/2 - b1/2) + 1;
r2 = floor(d(2)/2 + b2/2);
switch pos
    case 0
        c1 = ceil(d(1)/2 - b2/2) + 1;
        c2 = floor(d(1)/2 + b2/2);
        smaller = imresize(pix(r1:r2, c1:c2), 1/5);
    case 1
        smaller = imresize(pix(r1:r2, 1:b2), 1/5);
    case 2
        smaller = imresize(pix(r1:r2, (d(2)-b2 + 1):d(2)), 1/5);
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
    set(handles.text5, 'String', 'Off');
else
    set(handles.text5, 'String', 'On');
    core.startContinuousSequenceAcquisition(1);
    start(handles.timer);
end

% --- Outputs from this function are returned to the command line.
function varargout = speed_up_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



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


% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global period
set(handles.timer, 'Period', period);


% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global core imgWidth imgHeight smaller pix gpu_num f l 
if strcmp(get(handles.timer, 'Running'), 'off')
    core.snapImage()
    img = core.getImage();
    pix = imrotate(reshape(img, imgWidth, imgHeight), -90);
    smaller = imresize(pix, 1/5);
    if gpu_num > 0
        pix1 = gpuArray(pix);
        if l
            f = gpuArray(log(abs(fftshift(fft2(double(pix1))))));
        else    
            f = gpuArray(abs(fftshift(fft2(double(pix1)))));
        end
        f = gather(f);
    else    
        if l
            f = (log(abs(fftshift(fft2(double(pix))))));
        else 
            f = (abs(fftshift(fft2(double(pix)))));
        end
    end
end
update_GUI(handles);

% --- Executes on button press in pushbutton6.
function pushbutton6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton6 (see GCBO)
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

% -- Sets the colorbar scale
% --- Executes on button press in pushbutton7.
function pushbutton7_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ymin ymax cb
caxis(handles.axes2, [ymin ymax]);

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
function pushbutton8_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global pix filename f;
savefile = char(strcat(filename, '.mat'));
save(['C:\Program Files\Micro-Manager-1.4\Data files\',savefile], 'pix', 'f');
set(handles.text15, 'String', ['Data Saved to ', savefile]);

% -- Changes crop scale
% --- Executes on selection change in popupmenu2.
function popupmenu2_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu2
global crop;
contents = cellstr(get(hObject, 'String'));
crop = str2num(contents{get(hObject, 'Value')});
update_GUI(handles)

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

% -- Changes Crop selection
% --- Executes on selection change in popupmenu3.
function popupmenu3_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu3 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu3
global pos
axes(handles.axes1)
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

% -- Normalizes FFT
% --- Executes on button press in checkbox1.
function checkbox1_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox1
global n l prev_max
if get(hObject, 'Value')
    n = true;
    if l
        set(handles.slider2, 'Value', get(handles.slider2, 'Value')/log(prev_max))
        set(handles.slider3, 'Value', get(handles.slider3, 'Value')/log(prev_max))
    else
        set(handles.slider2, 'Value', get(handles.slider2, 'Value')/prev_max)
        set(handles.slider3, 'Value', get(handles.slider3, 'Value')/prev_max)
    end
    set(handles.slider2, 'min', 0, 'max', 1);
    set(handles.slider3, 'min', 0, 'max', 1);
else
    n = false;
    if l
        set(handles.slider2, 'max', log(prev_max));
        set(handles.slider3, 'max', log(prev_max));
        set(handles.slider2, 'Value', get(handles.slider2, 'Value')*log(prev_max))
        set(handles.slider3, 'Value', get(handles.slider3, 'Value')*log(prev_max))
    else
        set(handles.slider2, 'max', prev_max)
        set(handles.slider3, 'max', prev_max)
        set(handles.slider2, 'Value', get(handles.slider2, 'Value')*prev_max)
        set(handles.slider3, 'Value', get(handles.slider3, 'Value')*prev_max)
    end
end

% -- Sets colorbar ymin using slider
% --- Executes on slider movement.
function slider2_Callback(hObject, eventdata, handles)
% hObject    handle to slider2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
global ymin
ymin = get(hObject, 'Value');
set(handles.edit2, 'String', num2str(ymin))


% --- Executes during object creation, after setting all properties.
function slider2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% -- Sets the colorbar ymax with the slider
% --- Executes on slider movement.
function slider3_Callback(hObject, eventdata, handles)
% hObject    handle to slider3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
global ymax
ymax = get(hObject, 'Value');
set(handles.edit3, 'String', num2str(ymax))

% --- Executes during object creation, after setting all properties.
function slider3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% -- Changes Colormap of Image
% --- Executes on selection change in popupmenu4.
function popupmenu4_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu4 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu4
contents = cellstr(get(hObject, 'String'));
val = contents{get(hObject, 'Value')};
colormap(handles.axes1, val);

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

% -- Changes Colormap of FFT
% --- Executes on selection change in popupmenu5.
function popupmenu5_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu5 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu5
contents = cellstr(get(hObject, 'String'));
val = contents{get(hObject, 'Value')};
colormap(handles.axes2, val);


% --- Executes during object creation, after setting all properties.
function popupmenu5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

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
global l prev_max;
if get(hObject, 'Value')
    l = true;
    set(handles.slider2, 'max', log(prev_max))
    set(handles.slider3, 'max', log(prev_max))
else
    l = false;
    set(handles.slider2, 'max', prev_max)
    set(handles.slider3, 'max', prev_max)
end
