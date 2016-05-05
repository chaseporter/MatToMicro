README: realtime.m (UPDATED BETTER VERSION IS NOW speedup.m)
---Explains how to run/use realtime.m, current bugs, set up specific cameras in Micromanager, and get Matlab to communicate with MicroManager.

To run speedup.m, make sure it, along with speedup.fig, is copied in the MicroManager Program Folder (C:\Program Files\Micro-Manager-1.4). If
this is the first time you have run speedup.m, open Matlab and type the following command: 
	edit([prefdir '/javaclasspath.txt']);
Answer yes if prompted. In the javaclasspath.txt file that opens up, copy and paste the text from D:\Chase\MatToMicro\javaclasspasth.txt. Save and close the
javaclasspath.txt file and restart Matlab.

The supported cameras for MicroManager along with set up instructions can be found in the following link: 
	https://micro-manager.org/wiki/Device_Support

To get speedup.m to work for a specific camera, find the folder with the camera's name in D:\Chase\MatToMicro and copy all of that folders contents (the actual 
files inside not the folder itself) into the MicroManager Program Folder. 

The following cameras have been configured in MicroManager: 
--PCO_edge
	* The following files must be in the MicroManager Program folder for the PCO edge camera to work in Micromanager (all can be found in 
	  D:\Chase\MatToMicro\PCO_files): 
		-PCOEDGE.cfg, PCO_CDlg.dll, PCO_Conv.dll, SC2_Cam.dll, sc2_cl_me4.dll
--Basler
	* To use the Basler camera (as well as any other GigE configured camera) in MicroManager, JAI SDK 1.3.0 must be installed. Then copy Basler.cfg from 
	  D:\Chase\MatToMicro\Basler_files 


Open speedup.m from the MicroManager program folder, in Matlab and run it. If asked to change folder, agree. A Micromanager window should open and prompt you to specify a camera configuration. From the drop down menu select the three
dots option which will open up finder. Navigate to the MicroManager Program folder and find the .cfg file corresponding to the camera you want to use (make sure the
camera is on and connected). At this point the GUI should pop up. 

(The current GUI is still in development. There are a few bugs, like if you close the MicroManager window, all of Matlab will close. If you run into any unforseen bugs,
close the GUI and the figure window, but not the MicroManager window, and comment out lines 67 and 68. Then run speedup.m again. If you ever close the MicroManager Window,
make sure these two lines are not commented out. If you run into the following error: 
java.lang.Exception: This operation can not be executed while sequence acquisition is runnning.
Click the Push Button below the set timer button.)