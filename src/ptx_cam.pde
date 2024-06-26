/*
 *  This file is part of the PTX library.
 *
 *  The PTX library is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  the PTX library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with the PTX library.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

import processing.video.*;
import java.io.InputStreamReader;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * This class aims at easing the process of capturing image
 * from the camera in processing, both in its setup and
 * in its usage.
 * On top of that, the class hosts all usefull version
 * of captured image (whole, croped, filtered and final result)
 *
 * @author  Roman Miletitch
 * @version 0.7
 *
 **/

public class cam {
  Capture cpt;
  String camStr;
  int camVideoId, id;
  boolean withCamera;

  boolean hasImage, isFiltered, isRecognised;
  boolean isBrio;

  PImage mImg;          // Whole image
  PImage mImgCroped;    // Image with trapeze done
  PImage mImgFilter;
  PImage mImgRez;
  PImage mImgCoded;

  int wFbo, hFbo;
  int wCam, hCam;

  //Selection of ROI in mImg for mImgCroped
  //0 1
  //3 2
  vec2f[] ROI;
  int dotIndex; // 0->3 & -1 == no editing
  float zoomCamera;


  // max
  int maxSaturation = -999;
  int maxBrightness = -999;
  int maxExposure = -999;
  int maxContrast = -999;
  int maxTemperature = -999;

  cam(boolean _withCamera) {

    withCamera = _withCamera;
    wFbo = 1000;
    hFbo = 1000;
    camVideoId = -1;

    wCam = 0;
    hCam = 0;

    ROI = new vec2f[4];
    mImg = createImage(wFbo, hFbo, RGB);
    mImgCroped = createImage(wFbo, hFbo, RGB);
    mImgFilter = createImage(wFbo, hFbo, RGB);
    mImgRez    = createImage(wFbo, hFbo, RGB);
    mImgCoded = createImage(wFbo, hFbo, RGB);

    zoomCamera = 1;
    dotIndex = -1;
    ROI[0] = new vec2f(200, 200);
    ROI[1] = new vec2f(400, 200);
    ROI[2] = new vec2f(400, 400);
    ROI[3] = new vec2f(200, 400);

    if(!withCamera)
      return;
      
    String[] cameras = Capture.list();
    if (cameras.length == 0) {
      println("There are no cameras available for capture.");
      exit();
    } else {
      println("Available cameras:");
      for (int i = 0; i < cameras.length; i++) {
        println(i + ", " + cameras[i]);
      }
    }
  }  


  /** 
   * Functions that let the user resize the fbo which defines the 
   * playfield.
   * @param _wFbo        width of FBO
   * @param _hFbo        height of FBO
   */
  void resize(int _wFbo, int _hFbo) {

    wFbo = _wFbo;
    hFbo = _hFbo;
    zoomCamera = min(width*1.f/wFbo, height*1.f/hFbo);

    mImgCroped = createImage(wFbo, hFbo, RGB);
    mImgFilter = createImage(wFbo, hFbo, RGB);
    mImgRez    = createImage(wFbo, hFbo, RGB);
    mImgCoded = createImage(wFbo, hFbo, RGB);
  }

  /** 
   * Functions that let the user select which camera to use and which
   * mode of camera to use for the image recognision stream. It then
   * launch it.
   * @param _idCam          the identifiant of the selected camera
   * @param _myGrandParent  a reference to the current PApplet, necessary
   for instancing the Capture class
   */
  void startFromId(int _idCam, int _wwCam, int _hhCam, PApplet _myGrandParent) {
    wCam = _wwCam;
    hCam = _hhCam;
    
    if(!withCamera)
      return;
    
    // 1) Select the camera 
    String[] cameras = Capture.list();
  
    if (cameras.length == 0)
      return;

		for (int i = 0; i < cameras.length; i++) {
      println("" + i + " => " + cameras[i]);
      if(cameras[i].contains("BRIO"))
        isBrio = true;
      if(cameras[i].contains("Logi 4K Stream"))
        isBrio = true;
		}

    if (_idCam < cameras.length) {
      println("FOUND GOOD CAM");
      camStr = cameras[_idCam];
      id = _idCam;
      
           //tmp mod for brio cam
      String camStrv2 = "";
      if(camStr.length() > 5)
        camStrv2 = camStr.substring(0,camStr.length()-4);
      else 
        camStrv2 = camStr;
      
      
      // Get the correct video id from the camera
      ArrayList<String> listCamStr = exeMult("v4l2-ctl --list-device");
      
      for (int i = 0; i < listCamStr.size(); ++i) {
        if(listCamStr.get(i).contains(camStrv2) && i < listCamStr.size() - 1) {
          camVideoId = Integer.parseInt( split(listCamStr.get(i+1), "/dev/video")[1] );
          break;
        }
      }
      
    } else {
      println("DEFAULT CAM");
      camStr = cameras[0];
      id = 0;
      camVideoId = 0;
    }

    println(_idCam + " / Camera: " + camStr);

    // 2) Create the capture object
    //cpt = new Capture(_myGrandParent, cameras[0]);
    cpt = new Capture(_myGrandParent, _wwCam, _hhCam, camStr, 30);

    // 3) Launch
    cpt.start();

    while (cpt.width * cpt.height == 0) {     
      try{Thread.sleep(10);}catch(InterruptedException e){System.out.println(e);}  
      print("Waiting for camera with non null values\n");
      update();
    }


    wCam = cpt.width;
    hCam = cpt.height;
    mImg = createImage(wCam, hCam, RGB);

    loadCamConfig();

    update();
    update();
  }

  void loadCamConfig() {
      
    if(!withCamera)
      return;
    JSONObject camConfig = loadJSONObject("data/config.json").getJSONObject("camera"); 

		modCam("set", "exposure_time_absolute", floor(camConfig.getFloat("exposure")) );
		//modCam("set", "exposure_absolute", floor(camConfig.getFloat("exposure")) );

    modCam("set", "saturation", floor(camConfig.getFloat("saturation")) );
    modCam("set", "brightness", floor(camConfig.getFloat("brightness")) );
    modCam("set", "contrast", floor(camConfig.getFloat("contrast")) );
    modCam("set", "white_balance_temperature", floor(camConfig.getFloat("temperature")) );  


		// Putting stuff in manual (no auto controls)
    modCam("set", "white_balance_temperature_auto", 0);
    modCam("set", "exposure_auto_priority", 0);
    modCam("set", "focus_auto", 0);
    modCam("set", "exposure_auto", 0);
    modCam("set", "gain", 0);

		if(isBrio) {
			modCam("set", "white_balance_automatic", 0);
			modCam("set", "auto_exposure", 1);
			modCam("set", "exposure_dynamic_framerate", 0);
		} else {
			//modCam("set", "white_balance_temperature_auto", 0);
			//modCam("set", "exposure_auto", 1);
			//modCam("set", "exposure_auto_priority", 0);

			modCam("set", "white_balance_automatic", 0);
			modCam("set", "auto_exposure", 1);
			modCam("set", "exposure_dynamic_framerate", 0);
		}


    // max
    String regex = "max=(\\d+)";
    Pattern pattern = Pattern.compile(regex);

    ArrayList<String> listMaxStr = exeMult("v4l2-ctl -d /dev/video" + camVideoId + " --list-ctrls");

      for (int i = 0; i < listMaxStr.size(); ++i) {

        if(listMaxStr.get(i).contains("brightness") ){
          Matcher matcher = pattern.matcher(listMaxStr.get(i));
          if (matcher.find()) {
             maxBrightness = Integer.parseInt(matcher.group(1));
          }
        }
 
        if(listMaxStr.get(i).contains("contrast") ){
          Matcher matcher = pattern.matcher(listMaxStr.get(i));
          if (matcher.find()) {
             maxContrast = Integer.parseInt(matcher.group(1));
          }
        }

        if(listMaxStr.get(i).contains("saturation") ) {
          Matcher matcher = pattern.matcher(listMaxStr.get(i));
          if (matcher.find()) {
             maxSaturation = Integer.parseInt(matcher.group(1));
          }
        }

        if(listMaxStr.get(i).contains("white_balance_temperature") ) {
          Matcher matcher = pattern.matcher(listMaxStr.get(i));
          if (matcher.find()) {
             maxTemperature = Integer.parseInt(matcher.group(1));
          }
        }

        if(listMaxStr.get(i).contains("exposure_time_absolute") ) {
          Matcher matcher = pattern.matcher(listMaxStr.get(i));
          if (matcher.find()) {
             maxExposure = Integer.parseInt(matcher.group(1));
          }
        }

      }


 
  }
  
  /** 
   * Get another image from the camera stream if possible
   * @return          <code>true</code> if the camera is availabe. 
   */
  boolean update() {
    
    if(!withCamera)
      return true;

    if (camVideoId == -1)
      return true;

    long locStart  = System.currentTimeMillis();  
    if (cpt.available()) {
      cpt.read();
      
      // FOLLOWING TWO LINES ARE HERE TO HELP WITH A BUG IN PROCESSING VIDEO
      // APPARENTLY OU NEED TO DISPLAY THE VIDEO ON THE SCREEN IN ORDER TO ACCESS ITS PIXEL WHEN USING "P3D" RENDER... GO FIGURE...
      cpt.loadPixels();
      image(cpt, width, height, width*0.1, height*0.1);

      mImg = cpt.copy();
      mImgCroped = createImage(wFbo, hFbo, RGB);
      mImgCoded = createImage(wFbo, hFbo, RGB);
      return true;
    }
    return false;

 }

  /** 
   * Copy the main image into filter Image and rez Image objects for displaying
   * and/or futur processing.
   */
  void updateImg() {
    mImgFilter.copy(mImgCroped, 0, 0, wFbo, hFbo, 0, 0, wFbo, hFbo);
    mImgRez.copy(mImgCroped, 0, 0, wFbo, hFbo, 0, 0, wFbo, hFbo);
  }

  /** 
   * Function that test if the camera is availabe
   * @return          <code>true</code> if the camera is availabe. 
   */
  boolean isOn() {
     return false;
//    return cpt.available();
  }


  int modCam(String _action, String _param, int _val) {

    if(!withCamera)
      return -999;

    if (  System.getProperty ("os.name").contains("Linux") ) {
      String setCmd = "v4l2-ctl -d /dev/video"+camVideoId+" --set-ctrl ";
      String getCmd = "v4l2-ctl -d /dev/video"+camVideoId+" --get-ctrl ";

      String paramStr = exe(getCmd+_param);
      if ( paramStr.contains("unknown") ) {
        println("Camera doesn't have the parametre " + _param);
        return -1;
      }

      int paramVal = Integer.parseInt( split(paramStr, ' ')[1] );
      
      if(_action.equals("add")) {
        int newval = paramVal + _val;
        exe(setCmd+_param+"=" + newval);
      } else if(_action.equals("set")) {
        exe(setCmd+_param+"="+_val);
      }
      
      paramStr = exe(getCmd+_param);
      return Integer.parseInt( split(paramStr, ' ')[1] );

    }
    
    return -1;
    }  


  String exe(String cmd) {
    String returnedValues = "";
    String rezStr = "";

    try {
      File workingDir = new File("./");  
      Process p = Runtime.getRuntime().exec(cmd, null, workingDir);

      // variable to check if we've received confirmation of the command
      int i = p.waitFor();

      // if we have an output, print to screen
      if (i == 0) {

        // BufferedReader used to get values back from the command
        BufferedReader stdInput = new BufferedReader(new InputStreamReader(p.getInputStream()));

        // read the output from the command
        while ( (returnedValues = stdInput.readLine ()) != null) {
          if (rezStr.equals(""))
            rezStr=returnedValues;
          //println("out/ "+ returnedValues);
        }
      }

      // if there are any error messages but we can still get an output, they print here
      else {
        BufferedReader stdErr = new BufferedReader(new InputStreamReader(p.getErrorStream()));

        // if something is returned (ie: not null) print the result
        while ( (returnedValues = stdErr.readLine ()) != null) {
          if (rezStr.equals(""))
            rezStr=returnedValues;            
          //println("err/ "+returnedValues);
        }
      }
    }

    // if there is an error, let us know
    catch (Exception e) {
      println("Error running command!");  
      println(e);
    } 

    return rezStr;
  }
  
  ArrayList<String> exeMult(String cmd) {
    
    String returnedValues = "";
    ArrayList<String> rezStr = new ArrayList<String>();

    try {
      File workingDir = new File("./");  
      Process p = Runtime.getRuntime().exec(cmd, null, workingDir);

      // variable to check if we've received confirmation of the command
      int i = p.waitFor();

      // if we have an output, print to screen
      if (i == 0) {

        // BufferedReader used to get values back from the command
        BufferedReader stdInput = new BufferedReader(new InputStreamReader(p.getInputStream()));

        // read the output from the command
        while ( (returnedValues = stdInput.readLine ()) != null) {
            rezStr.add(returnedValues);
          //println("out/ "+ returnedValues);
        }
      }

      // if there are any error messages but we can still get an output, they print here
      else {
        BufferedReader stdErr = new BufferedReader(new InputStreamReader(p.getErrorStream()));

        // if something is returned (ie: not null) print the result
        while ( (returnedValues = stdErr.readLine ()) != null) {
            rezStr.add(returnedValues);
            
          //println("err/ "+returnedValues);
        }
      }
    }

    // if there is an error, let us know
    catch (Exception e) {
      println("Error running command!");  
      println(e);
    } 

    return rezStr;
  }
}
