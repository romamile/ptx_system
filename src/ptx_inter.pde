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



import java.lang.System.*;
import java.awt.event.KeyEvent;

import deadpixel.keystone.*;

public enum globState { PLAY, MIRE, CAMERA, RECOG };
public enum recogState { RECOG_FLASH, RECOG_ROI, RECOG_BACK, RECOG_COL, RECOG_AREA, RECOG_CONTOUR };
public enum cameraState { CAMERA_WHOLE, CAMERA_ROI }; 

/**
 * This class is the main one in the PTX library. It helps you
 * setting up the whole system, diagnosing what goes wrong,
 * and display helpful calibrating GUI. It's also the class that
 * returns the list of all color area recognised.
 *
 * @author  Roman Miletitch
 * @version 0.7
 *
 **/


public class ptx_inter {

	// Version
	String[] version = {"0","8","0"};
	String[] versionExp = {"1","0","0", "Exp"};

  // The states
  globState myGlobState;  
  recogState myRecogState;
  cameraState myCamState;

  // debug
  PFont fDef, fGlob;
  int debugType; // 0 - 1 - 2 - 3
  HashMap<String, PImage> tutoMap;
  boolean showTutorial = false;

  toggle togUI;
  String strUI;
  int[] colUI = {255, 255, 255};

  cam myCam;
  ptx myPtx;
  
  boolean shiftPressed;


  // Scan
  int grayLevelUp, grayLevelDown;
  int whiteCtp;
  boolean withFlash;

  // Thread
  boolean withThread, postThreadAtScanNeeded;
  boolean launchThread;
  toggle toggleThread;

  // Frame Buffer Object
  int wFrameFbo, hFrameFbo;
  PGraphics mFbo;
  
  // F6 mode
  int fIndex;
  String fName;
  
  // Optical deformations. Projo & Cam
  Keystone ks;
  CornerPinSurface surface;
  ProjectiveTransform _keystoneMatrix;
  vec2f[] ROIproj;
  int dotIndex;


  ptx_inter(PApplet _myParent) {

    myGlobState = globState.PLAY;

    myRecogState = recogState.RECOG_FLASH;
    myCamState =  cameraState.CAMERA_WHOLE;

    fDef = createFont("./data/MonospaceTypewriter.ttf", 28);
    fGlob = createFont("./data/MonospaceTypewriter.ttf", 28);
    debugType = 1;

    tutoMap = new HashMap<String, PImage>();

    for (String nameImage : new String[]{"F1", "F2", "F3_1_whole", "F3_2_roi", "F4_1_flash", "F4_2_roi", "F4_3_signal", "F4_4_histogram", "F4_5_area", "F4_6_contour"}) {
        tutoMap.put( nameImage, loadImage("./ptx_system/assets/tuto/"+nameImage+".png") );
    }

    togUI = new toggle();
    togUI.setSpanS(3);
    strUI = "";
    
    toggleThread = new toggle();
    toggleThread.setSpanMs(1000);
    
    shiftPressed = false;

    
//    hFrameFbo = 757;
//    float ratioFbo = (width*1.0)/height; // = 37.f / 50;
//    wFrameFbo = int(hFrameFbo * ratioFbo);

    wFrameFbo = 1280;
    hFrameFbo = 800;

    myPtx = new ptx();

    grayLevelUp   = 126;
    grayLevelDown = 126;
    withFlash = false;
    withThread = false;
    launchThread = false;
    postThreadAtScanNeeded = false;

    fIndex = -1;
    fName = "";
    
    // SCAN
    whiteCtp = 0;

    ks = new Keystone(_myParent);
    surface = ks.createCornerPinSurface(wFrameFbo, hFrameFbo, 20);
    

    // Creation of a config file in case one isn't present
    File f = new File(dataPath("config.json"));
    if (!f.exists())
      saveConfig("data/config.json");


    JSONObject camConfig = loadJSONObject("data/config.json").getJSONObject("camera"); 

    int idCam = camConfig.getInt("id");
    int wCam  = camConfig.getInt("width");
    int hCam  = camConfig.getInt("height");
    boolean withCam = camConfig.getInt("enabled") != 0;

    if(withCam) {
      println("WITH CAMERA");
    } else  {
      println("WITHOUT CAMERA");
    }
    
    mFbo = createGraphics(wFrameFbo, hFrameFbo, P3D);
    
    myCam = new cam(withCam);
    myCam.resize(wFrameFbo, hFrameFbo);
    myCam.startFromId(idCam, wCam, hCam, _myParent);

    // Load configuration file
    loadConfig("data/config.json");
    
    calculateHomographyMatrice(wFrameFbo, hFrameFbo, myCam.ROI);
    
    // First scan (check if not over kill, already one update in file)
    //    myCam.update(); myCam.update(); myCam.update(); myCam.update(); myCam.update();
    scanCam();
    scanClr();
  }


  /** 
   * Helper functions to access all the scanned areas.
   * @return              <code>ArrayList<area></code> corresponding to the list of all Areas
   */
  ArrayList<area> getListArea() {
    return myPtx.listArea;
  }

  area getAreaById(int _id) {
    for (area tmpArea : myPtx.listArea)
      if (tmpArea.id == _id)
        return tmpArea;
    return new area();
  }


  /** 
   * Get another image from the camera, apply geometric correction
   * and update the subsecant images (while not parsing the picture)
   * A full scan would be scanCam + scanClr
   */
  void scanCam() {

    myCam.mImgCroped = createImage(wFrameFbo, hFrameFbo, RGB);

    trapeze(myCam.mImg, myCam.mImgCroped, 
      myCam.mImg.width, myCam.mImg.height, 
      myCam.mImgCroped.width, myCam.mImgCroped.height, myCam.ROI);

    myCam.updateImg();

  }

  /** 
   * Update the subsecant images of the camera and parse the
   * image (while not asking for a new camera picture before that)
   * A full scan would be scanCam + scanClr
   */
  void scanClr() {

    myCam.updateImg();
    myPtx.parseImage(myCam.mImgCroped, myCam.mImgFilter, myCam.mImgRez, wFrameFbo, hFrameFbo, 99);
//    atScan();
  }

  /** 
   * Display the Frame Buffer Object where everything is drawn,
   * following the determined keystone. 
   */
  void displayFBO() {

    surface.render(mFbo);
  }
  
  /** 
   * Main rendering function, that dispatch to the other renderers.
   * Scan, Mire, Camera, Recogintion.
   */
  void generalRender() {

    mFbo.beginDraw();
    mFbo.textFont(fDef); textFont(fGlob);
    mFbo.textSize(28);   textSize(28);
    mFbo.fill(255);
    mFbo.textAlign(LEFT);

    myPtxInter.mFbo.imageMode(CORNER);
    myPtxInter.mFbo.rectMode(CORNER);

    mFbo.background(30);

    if (isScanning) {
      renderScan();
    } else {
      switch (myGlobState) {
      case MIRE:
        renderMire();
        break;
      case CAMERA:
        renderCamera(); 
        if (debugType != 0 && myPtxInter.myGlobState == globState.CAMERA && myPtxInter.myCamState == cameraState.CAMERA_WHOLE) { // display UI directly on screen   
            textAlign(LEFT);
            text("F3: CAMERA 1/2 - WHOLE", 20, 40);
          }
        break;
      case RECOG:
        renderRecog();
        break;
      }
    }

    if ((debugType == 2 || debugType == 3) && !isScanning)
      displayDebugIntel();

    displayTutorial();
    showNotification();
     
    mFbo.endDraw();

    if (! (myPtxInter.myGlobState == globState.CAMERA && myPtxInter.myCamState == cameraState.CAMERA_WHOLE) || isScanning ) {
        displayFBO();
    }

  }
  
  void showNotification() {
    mFbo.textFont(fDef); textFont(fGlob);
    mFbo.textSize(28);   textSize(28);
    mFbo.fill(255);
    mFbo.textAlign(LEFT);
    
    if(togUI.getState()) {
        // UI high level
        
        if(myPtxInter.myGlobState == globState.CAMERA && myPtxInter.myCamState == cameraState.CAMERA_WHOLE) { // display UI directly on screen   
          fill(colUI[0], colUI[1], colUI[2]);     
          textAlign(CENTER);
          text(strUI, width/2, height/2 - 100);           
        } else { // display UI in FBO
          mFbo.fill(colUI[0], colUI[1], colUI[2]);     
          mFbo.textAlign(CENTER);
          mFbo.text(strUI, myPtxInter.mFbo.width/2, myPtxInter.mFbo.height/2 - 100);
        }
    } else {
        togUI.stop(false); 
    } 
  }

  void postGameDraw() {

    mFbo.textFont(fDef); textFont(fGlob);
    mFbo.textSize(28);   textSize(28);
    if(togUI.getState()) {
        // UI high level
        if(myPtxInter.myGlobState == globState.CAMERA && myPtxInter.myCamState == cameraState.CAMERA_WHOLE) { // display UI directly on screen   
          fill(colUI[0], colUI[1], colUI[2]);     
          textAlign(CENTER);
          text(strUI, width/2, height/2 - 100); 
        } else { // display UI in FBO
          mFbo.fill(colUI[0], colUI[1], colUI[2]);     
          mFbo.textAlign(CENTER);
          mFbo.text(strUI, myPtxInter.mFbo.width/2, myPtxInter.mFbo.height/2 - 100);
        }
    } else {
        togUI.stop(false); 
    }

  }

  /** 
   * Sub renderer function, to display the Mire
   */
  void renderMire() {  // F2

    mFbo.stroke(250);
    mFbo.strokeWeight(2);
    mFbo.beginShape(LINES);
    for (int i = 0; i < 7; i++) { //Mire
      mFbo.vertex(wFrameFbo / 6.f*i, 0); //Lignes verticales
      mFbo.vertex(wFrameFbo / 6.f*i, hFrameFbo);

      mFbo.vertex(0, hFrameFbo / 6.f*i); //Lignes horizontales
      mFbo.vertex(wFrameFbo, hFrameFbo / 6.f*i);
    }

    //Bords
    mFbo.vertex(0, hFrameFbo -3); 
    mFbo.vertex(wFrameFbo, hFrameFbo -3);

    mFbo.vertex(0, 2);
    mFbo.vertex(wFrameFbo, 2);

    mFbo.vertex(2, 0);
    mFbo.vertex(2, hFrameFbo);

    mFbo.vertex(wFrameFbo - 2, 0);
    mFbo.vertex(wFrameFbo - 2, hFrameFbo);

    mFbo.endShape();


    mFbo.stroke(255, 255*0.3, 255*0.3);
    mFbo.beginShape(LINES);
    mFbo.vertex(wFrameFbo/2.f, hFrameFbo*0.4); //Lignes verticales
    mFbo.vertex(wFrameFbo/2.f, hFrameFbo*0.6);

    mFbo.vertex(wFrameFbo*0.4, hFrameFbo/2.f); //Lignes horizontales
    mFbo.vertex(wFrameFbo*0.6, hFrameFbo/2.f);

    mFbo.endShape();

    mFbo.stroke(255);
    
    if (debugType != 0) {
      mFbo.text("F2: MIRE - CALIBRATING", 20, 40); 
    }

  }


  /** 
   * Sub renderer function, to display the Camera
   * First mode allows for the whole camera to be displayed, and
   * selection of the 4 corneres of the ROI.
   * Second allows for just the ROI to be displayed and geometric
   * correction to be tested/applied.
   */
  void renderCamera() { // F3

    switch (myCamState) {
    case CAMERA_WHOLE: // Show the whole view of the camera
      push();
      
      scale(myCam.zoomCamera);
      image(myCam.mImg, 0, 0);
      strokeWeight(2/myCam.zoomCamera);
      stroke(255, 130);
      noFill();
      beginShape();
      vertex(myCam.ROI[0].x, myCam.ROI[0].y);
      vertex(myCam.ROI[1].x, myCam.ROI[1].y);
      vertex(myCam.ROI[2].x, myCam.ROI[2].y);
      vertex(myCam.ROI[3].x, myCam.ROI[3].y);
      endShape(CLOSE);
      
      
      if(myCam.dotIndex != -1) {
        float radius = 20/myCam.zoomCamera;
        stroke(255, 200);
        ellipse(myCam.ROI[myCam.dotIndex].x, myCam.ROI[myCam.dotIndex].y, radius, radius);
        ellipse(myCam.ROI[myCam.dotIndex].x, myCam.ROI[myCam.dotIndex].y, 2*radius, 2*radius);
        stroke(255, 50);
        line(myCam.ROI[myCam.dotIndex].x - radius, myCam.ROI[myCam.dotIndex].y, myCam.ROI[myCam.dotIndex].x + radius, myCam.ROI[myCam.dotIndex].y);
        line(myCam.ROI[myCam.dotIndex].x, myCam.ROI[myCam.dotIndex].y - radius, myCam.ROI[myCam.dotIndex].x, myCam.ROI[myCam.dotIndex].y + radius);
      }
      
      
      if (debugType != 0) {
        pushStyle();
          fill(255,130);
          textSize(18/myCam.zoomCamera);
          textAlign(CENTER);
          text( "TopLeft", myCam.ROI[0].x - 50, myCam.ROI[0].y - 50);
          text( "TopRight", myCam.ROI[1].x + 50, myCam.ROI[1].y - 50);
        popStyle();
      }


      fill(255);
      pop();
      
      break;

    case CAMERA_ROI:  // Show the region of interest

      mFbo.image(myCam.mImgCroped, 0, 0);

      mFbo.stroke(0);
      mFbo.strokeWeight(1);
      mFbo.beginShape(LINES);
      for (int i = 0; i < 7; i++) { //Mire
        mFbo.vertex(wFrameFbo / 6.f*i, 0); //Lignes verticales
        mFbo.vertex(wFrameFbo / 6.f*i, hFrameFbo);

        mFbo.vertex(0, hFrameFbo / 6.f*i); //Lignes horizontales
        mFbo.vertex(wFrameFbo, hFrameFbo / 6.f*i);
      }

      //Bords
      mFbo.vertex(0, hFrameFbo -3); 
      mFbo.vertex(wFrameFbo, hFrameFbo -3);

      mFbo.vertex(0, 2);
      mFbo.vertex(wFrameFbo, 2);

      mFbo.vertex(2, 0);
      mFbo.vertex(2, hFrameFbo);

      mFbo.vertex(wFrameFbo - 2, 0);
      mFbo.vertex(wFrameFbo - 2, hFrameFbo);

      mFbo.endShape();


      mFbo.fill(255);


      // Selected Corner

      float radiusROI = 100;
      mFbo.stroke(255, 200);
      mFbo.noFill();
      mFbo.strokeWeight(5);
      switch(myCam.dotIndex) {
      case 0: mFbo.ellipse(0, 0, radiusROI, radiusROI); break;
      case 1: mFbo.ellipse(wFrameFbo, 0, radiusROI, radiusROI); break;
      case 2: mFbo.ellipse(wFrameFbo, hFrameFbo - 20, radiusROI, radiusROI); break;
      case 3: mFbo.ellipse(0, hFrameFbo, radiusROI, radiusROI); break;
      }
      mFbo.strokeWeight(1);

      if (debugType != 0)
        mFbo.text("F3: CAMERA 2/2 - ROI", 20, 40);

      break;
    }
  }

  /** 
   * Sub renderer function, to display the Recognition mode.
   * This mode has a few substate, all to diagnose if the color 
   * recognition is working fine, and to fine tune it if it's not.
   */
  void renderRecog() {  // F4
    background(0);

    switch (myRecogState) {
    case RECOG_FLASH:

      mFbo.noStroke();
      mFbo.beginShape(TRIANGLE_FAN);
      mFbo.fill(grayLevelUp);
      mFbo.vertex(mFbo.width, 0);
      mFbo.vertex(0, 0);  
      mFbo.fill(grayLevelDown);
      mFbo.vertex(0, mFbo.height);
      mFbo.vertex(mFbo.width, mFbo.height);
      mFbo.endShape();
        
      mFbo.fill(255);      
      if (debugType != 0) mFbo.text("F4: RECOG 1/6 - FLASH", 20, 40);
      break;

    case RECOG_ROI:
      mFbo.image(myCam.mImgCroped, 0, 0);
      mFbo.noStroke();
      mFbo.fill(200, 0, 0);

      mFbo.rect(0,0, myPtx.margeScan, mFbo.height);
      mFbo.rect(0,0, mFbo.width, myPtx.margeScan);
      
      mFbo.rect(0, mFbo.height, mFbo.width, mFbo.height-myPtx.margeScan);

      mFbo.rect(mFbo.width-myPtx.margeScan, 0, myPtx.margeScan, mFbo.height);
      mFbo.rect(0, mFbo.height-myPtx.margeScan, mFbo.width, myPtx.margeScan);
      mFbo.fill(255);


      if (debugType != 0) mFbo.text("F4: RECOG 2/6 - ROI", 20, 40);
      break;

    case RECOG_BACK:
      mFbo.image(myCam.mImgFilter, 0, 0);
      mFbo.fill(255);
      if (debugType != 0) mFbo.text("F4: RECOG 3/6 - SIGNAL vs NOISE", 20, 40);
      break;

    case RECOG_COL:
      mFbo.image(myCam.mImgRez, 0, 0);


      //Color Wheel
      mFbo.colorMode(HSB, 360);
      mFbo.noStroke();
      mFbo.pushMatrix();
      mFbo.translate(wFrameFbo/2, hFrameFbo/2);
      mFbo.beginShape(QUADS);
      for (int i = 0; i < 360; i++) {
        mFbo.fill(i, 360, 360, 150);
        mFbo.vertex(100 * cos(2 * PI*float(i)     / 360), 100 * sin(2 * PI*float(i)     / 360));
        mFbo.vertex(100 * cos(2 * PI*float(i + 1) / 360), 100 * sin(2 * PI*float(i + 1) / 360));
        mFbo.vertex(120 * cos(2 * PI*float(i + 1) / 360), 120 * sin(2 * PI*float(i + 1) / 360));
        mFbo.vertex(120 * cos(2 * PI*float(i)     / 360), 120 * sin(2 * PI*float(i)     / 360));
      }
      mFbo.endShape();

      //Histogram
      mFbo.beginShape(QUADS);
      for (int i = 0; i < 360; i++) {
        mFbo.fill(i, 360, 360, 150);
        int val = floor(140 + myPtx.histHue[i] * 0.25);

        mFbo.vertex(140 * cos(2 * PI*float(i)     / 360), 140 * sin(2 * PI*float(i)     / 360));
        mFbo.vertex(140 * cos(2 * PI*float(i + 1) / 360), 140 * sin(2 * PI*float(i + 1) / 360));
        mFbo.vertex(val * cos(2 * PI*float(i + 1) / 360), val * sin(2 * PI*float(i + 1) / 360));
        mFbo.vertex(val * cos(2 * PI*float(i)     / 360), val * sin(2 * PI*float(i)     / 360));
      }
      mFbo.endShape();

      // HueZones
      for (hueInterval myZone : myPtx.listZone) {
        mFbo.beginShape(QUADS);
        mFbo.fill(myZone.getRef(), 360, 360);

        for (int hue : myZone.getRange()) {
          mFbo.vertex(123 * cos(2 * PI*float(hue)     / 360), 123 * sin(2 * PI*float(hue)     / 360));
          mFbo.vertex(123 * cos(2 * PI*float(hue + 1) / 360), 123 * sin(2 * PI*float(hue + 1) / 360));
          mFbo.vertex(137 * cos(2 * PI*float(hue + 1) / 360), 137 * sin(2 * PI*float(hue + 1) / 360));
          mFbo.vertex(137 * cos(2 * PI*float(hue)     / 360), 137 * sin(2 * PI*float(hue)     / 360));
        }
        mFbo.endShape();
      }

      // Cursor
      int indexCol = 0;
      if (myPtx.indexHue%2 == 1)
        indexCol = myPtx.listZone.get(myPtx.indexHue/2).b;
      else
        indexCol = myPtx.listZone.get(myPtx.indexHue/2).a;

      mFbo.beginShape(TRIANGLES);
      mFbo.fill(255);
        mFbo.vertex(153 * cos(2 * PI*float(indexCol-3) / 360), 153 * sin(2 * PI*float(indexCol-3) / 360));
        mFbo.vertex(138 * cos(2 * PI*float(indexCol)   / 360), 138 * sin(2 * PI*float(indexCol)   / 360));
        mFbo.vertex(153 * cos(2 * PI*float(indexCol+3) / 360), 153 * sin(2 * PI*float(indexCol+3) / 360));
      mFbo.endShape();

      mFbo.popMatrix();   
      mFbo.colorMode(RGB, 255);

      mFbo.fill(255);
      if (debugType != 0) mFbo.text("F4: RECOG 4/6 - COLOR HISTOGRAM", 20, 40);
      break;

    case RECOG_AREA:

      mFbo.colorMode(HSB, 360);

      for (area itArea : myPtx.listArea) {
        mFbo.noStroke();
        mFbo.fill(itArea.hue, 360, 360);

        mFbo.beginShape();

        // 1) Exterior part of shape, clockwise winding
        for (vec2i itPos : itArea.listContour.get(0))
          mFbo.vertex(itPos.x, itPos.y);

        // 2) Interior part of shape, counter-clockwise winding
        for (int i = 1; i < itArea.listContour.size();++i) {
          mFbo.beginContour();
          for (vec2i itPos : itArea.listContour.get(i))
            mFbo.vertex(itPos.x, itPos.y);
          mFbo.endContour();
        }
        mFbo.endShape(CLOSE);
      }

      mFbo.colorMode(RGB, 255);
      mFbo.fill(255);
      if (debugType != 0) mFbo.text("F4: RECOG 5/6 - AREAS", 20, 40);
      break;

    case RECOG_CONTOUR:

      mFbo.stroke(50, 0, 0);
      mFbo.beginShape(POINTS);
      for (area itArea : myPtx.listArea)
        for (vec2i itPos : itArea.posXY)
          mFbo.vertex(itPos.x, itPos.y);
      mFbo.endShape();

      mFbo.stroke(255, 0, 0 );
      mFbo.beginShape(POINTS);
      for (area itArea : myPtx.listArea)
        for (ArrayList<vec2i> itContour : itArea.listContour)
          for (vec2i itPos : itContour)
            mFbo.vertex(itPos.x, itPos.y);
      mFbo.endShape();

      for (area itArea : myPtx.listArea) {
        String perSur = "";

        switch(itArea.myShape) {
        case DOT:  
          perSur = "dot";  
          break;
        case LINE: 
          perSur = "line";  
          break;
        case FILL: 
          perSur = "fill";  
          break;
        case GAP:  
          perSur = "gap";  
          break;
        }

        mFbo.text(perSur, itArea.posXY.get(0).x, itArea.posXY.get(0).y);
      }

      mFbo.fill(255);
      if (debugType != 0) mFbo.text("F4: RECOG 6/6 - CONTOURS", 20, 40);
      break;

    }
  }

  /** 
   * Sub renderer function, to display the Scanning white screen
   * when in the process of flashing the drawing
   */
  void renderScan() { // SCAN

    whiteCtp++;

//    if (!withFlash && isInConfig && myGlobState == globState.CAMERA) {
    if (isInConfig && (myGlobState == globState.CAMERA || myGlobState == globState.MIRE) ) {

      mFbo.background(0.3f, 0.3f, 0.3f);

      mFbo.stroke(255);
      mFbo.strokeWeight(2);
      mFbo.beginShape(LINES);
      for (int i = 0; i < 7; i++) { //Mire
        mFbo.vertex(wFrameFbo / 6.f*i, 0); //Lignes verticales
        mFbo.vertex(wFrameFbo / 6.f*i, hFrameFbo);

        mFbo.vertex(0, hFrameFbo / 6.f*i); //Lignes horizontales
        mFbo.vertex(wFrameFbo, hFrameFbo / 6.f*i);
      }

      //Bords
      mFbo.vertex(0, hFrameFbo-1); 
      mFbo.vertex(wFrameFbo-1, hFrameFbo-1);

      mFbo.vertex(0, 0);
      mFbo.vertex(wFrameFbo-1, 0);

      mFbo.vertex(0, 0);
      mFbo.vertex(0, hFrameFbo-1);

      mFbo.vertex(wFrameFbo-1, 0);
      mFbo.vertex(wFrameFbo-1, hFrameFbo-1);

      mFbo.endShape();
    } else {
      
      mFbo.beginShape(TRIANGLE_FAN);
      mFbo.stroke(grayLevelUp);
      mFbo.fill(grayLevelUp);
      mFbo.vertex(mFbo.width, 0);
      mFbo.vertex(0, 0);  
      mFbo.stroke(grayLevelDown);
      mFbo.fill(grayLevelDown);
      mFbo.vertex(0, mFbo.height);
      mFbo.vertex(mFbo.width, mFbo.height);
      mFbo.endShape();
    }
  }

  /**
  * Helper function to display short text for a while on the screen
  *
  */

  void notify(String _str, int _r, int _g, int _b) {
      strUI = _str;
      colUI[0] = _r;
      colUI[1] = _g;
      colUI[2] = _b;
      togUI.reset(true);     
  }


  /** 
   * Helper function to display some of the most often needed
   * parametrs value for the Recognise mode.
   */
  void displayDebugIntel() {

    mFbo.textSize(20);
    textSize(20);
    mFbo.stroke(0);
    stroke(0);
    mFbo.strokeWeight(5);
    strokeWeight(5);

    //Values
    int debugExposure = -999;
    if(myCam.isBrio) {
      debugExposure = myCam.modCam("get", "exposure_time_absolute", 0);
    } else {
      debugExposure = myCam.modCam("get", "exposure_absolute", 0);
    }

    String debugStr = "\n"
      + " --- Flash\n"
      + "p - Gray Top: "   + grayLevelUp + " / 255\n"
      + "o - Gray Down: "  + grayLevelDown + " / 255\n"
      + "i - Margin: "     + myPtx.margeScan + "\n\n"

      + "--- Filtering\n"
      + " a - Luminance: " + myPtx.seuilLuminance + "\n"
      + " z - Saturation: " + int(100*myPtx.seuilSaturation)/100.0 + "\n"
      + " e - dot VS big: " + myPtx.seuil_dotVSbig + "\n"
      + " r - line VS fill: " + myPtx.seuil_lineVSfill + "\n"
      + " t - tooSmall Contour: " + myPtx.tooSmallContour + "\n"
      + " y - tooSmall Surface: " + myPtx.tooSmallSurface + "\n\n"

      + "--- Camera\n"
      + " d - Exposure  : "   + debugExposure + "\n"
      + " f - Saturation  : " + myCam.modCam("get", "saturation", 0)  + "\n"
      + " g - Brightness  : " + myCam.modCam("get", "brightness", 0) + "\n"
      + " h - Contrast    : " + myCam.modCam("get", "contrast", 0) + "\n"
      + " j - Temperature : " + myCam.modCam("get", "white_balance_temperature", 0) + "\n"
      + " c - zoom : "        + myCam.zoomCamera + "\n";


    if (debugType == 2) {
      if (myPtxInter.myGlobState == globState.CAMERA && myPtxInter.myCamState == cameraState.CAMERA_WHOLE && !isScanning ) {
        textAlign(LEFT);
        text(debugStr, 20, 80);    
      } else {
        mFbo.textAlign(LEFT);
        mFbo.text(debugStr, 20, 80);
      }
    } 

    if (debugType == 3) {
      if (myPtxInter.myGlobState == globState.CAMERA && myPtxInter.myCamState == cameraState.CAMERA_WHOLE && !isScanning ) {
        textAlign(RIGHT);
        text(debugStr, wFrameFbo - 20, 80);
      } else {
        mFbo.textAlign(RIGHT);
        mFbo.text(debugStr, wFrameFbo - 20, 80);
      }
    } 

    mFbo.textAlign(LEFT);
    textAlign(LEFT);

    mFbo.noStroke();
    noStroke();

    mFbo.textSize(28);
    textSize(28);

    mFbo.strokeWeight(1);
    strokeWeight(1);
  }

  void displayTutorial() {
    if(!showTutorial || isScanning)
      return;

    PImage imgTuto = tutoMap.get("F1");

    switch (myGlobState) {
      case PLAY:
        imgTuto = tutoMap.get("F1");
        break;
      case MIRE:
        imgTuto = tutoMap.get("F2");
        break;
      case CAMERA:
        switch (myCamState) {
        case CAMERA_WHOLE:  
          imgTuto = tutoMap.get("F3_1_whole");
          break;
        case CAMERA_ROI:
          imgTuto = tutoMap.get("F3_2_roi");
          break;
        }
        break;
      case RECOG:
        switch (myRecogState) {
        case RECOG_FLASH:
          imgTuto = tutoMap.get("F4_1_flash");
          break;
        case RECOG_ROI:
          imgTuto = tutoMap.get("F4_2_roi");
          break;
        case RECOG_BACK:
          imgTuto = tutoMap.get("F4_3_signal");
          break;
        case RECOG_COL:
          imgTuto = tutoMap.get("F4_4_histogram");
          break;
        case RECOG_AREA:
          imgTuto = tutoMap.get("F4_5_area");
          break;
        case RECOG_CONTOUR:
          imgTuto = tutoMap.get("F4_6_contour");
          break;
      }
    }

		if(myGlobState != globState.CAMERA || myCamState != cameraState.CAMERA_WHOLE) {
    	mFbo.image(imgTuto, wFrameFbo / 2 - 600*0.9, hFrameFbo / 2 - 340.f, imgTuto.width, imgTuto.height);
		} else {
    	image(imgTuto, width / 2 - 600*0.9, height / 2 - 340.f, imgTuto.width, imgTuto.height);
		}

		// Version
    mFbo.textFont(fDef);
		mFbo.textSize(22);
		mFbo.text("PTX system - v" + version[0] + "." + version[1] + "." + version[2], 20, hFrameFbo - 30);

		mFbo.text(versionExp[3] + " - v" + versionExp[0]+ "." + versionExp[1] + "." + versionExp[2], 20, hFrameFbo - 70);
  }

  /** 
   * Apply the geometric correction on the camera picture.
   * @param _in     Origine Image
   * @param _out    Destination Image
   * @param  _wBef  width of the origine image 
   * @param  _hBef  height of the origine image 
   * @param  _wAft  width of the destination image 
   * @param  _hAft  height of the destination image 
   * @param  _ROI   the 4 points defining the region of interest
   */
  public void trapeze(PImage _in, PImage _out, int _wBef, int _hBef, int _wAft, int _hAft, vec2f[] _ROI) {

    _in.loadPixels();
    _out.loadPixels();
        
    if (null != _keystoneMatrix) {
      
      vec2f coords;
      for (int i = 0; i < _wAft; ++i) {
        for (int j = 0; j < _hAft; ++j) {
          
          coords = _keystoneMatrix.transform(new vec2f(i, j));
  
          int x = (int) Math.round(coords.x);
          int y = (int) Math.round(coords.y);
          
          // check point is in trapezoid
          if (0 <= x && x < _wBef && 0 <= y && y < _hBef) {
            _out.pixels[j*_wAft + i] = _in.pixels[y*_wBef + x];
          }
        }
      }
    }

    _in.updatePixels();
    _out.updatePixels();
  }

  
  public void calculateHomographyMatrice(int _wAft, int _hAft, vec2f[] _ROI) {    
    
    vec2f[] src = new vec2f[] {
      new vec2f(_ROI[0].x, _ROI[0].y), new vec2f(_ROI[3].x, _ROI[3].y), new vec2f(_ROI[2].x, _ROI[2].y), new vec2f(_ROI[1].x, _ROI[1].y)
    };
    vec2f[] dst = new vec2f[] {
      new vec2f(0., 0.), new vec2f(0., _hAft), new vec2f(_wAft, _hAft), new vec2f(_wAft, 0.)  
    };
        
    // refresh keystone
    _keystoneMatrix = new ProjectiveTransform(dst, src);
  }
  
  /** 
   * Save all parametrs in a predifined file (data/config.json)
   */
  void saveConfig(String _filePath) {
    println("Config Saved!");
    
    // Save keystone config
    ks.save("./data/configKeyStone.xml");

    // Save PTX config
    
    JSONObject config = new JSONObject();

      // 1] Camera
    JSONObject camConfig = new JSONObject();

    camConfig.setInt("id", myCam.id);
    camConfig.setInt("width", myCam.wCam);
    camConfig.setInt("height", myCam.hCam);
    camConfig.setInt("enabled", myCam.withCamera ? 1 : 0);

    if(myCam.isBrio) {
      camConfig.setInt("exposure", myCam.modCam("get", "exposure_time_absolute", 0) );
    } else {
      camConfig.setInt("exposure", myCam.modCam("get", "exposure_absolute", 0) );
    }
    camConfig.setInt("saturation", myCam.modCam("get", "saturation", 0) );
    camConfig.setInt("brightness", myCam.modCam("get", "brightness", 0) );
    camConfig.setInt("contrast", myCam.modCam("get", "contrast", 0) );
    camConfig.setInt("temperature", myCam.modCam("get", "white_balance_temperature", 0) );
    camConfig.setFloat("zoom", myCam.zoomCamera );

    config.setJSONObject("camera", camConfig);


      // 2] Seuil
    JSONObject seuilConfig = new JSONObject();

    seuilConfig.setFloat("saturation", myPtx.seuilSaturation);
    seuilConfig.setFloat("luminance", myPtx.seuilLuminance);
    seuilConfig.setInt("tooSmallSurface", myPtx.tooSmallSurface);
    seuilConfig.setInt("tooSmallContour", myPtx.tooSmallContour);
    seuilConfig.setFloat("lineVSfill", myPtx.seuil_lineVSfill);
    seuilConfig.setFloat("dotVSbig", myPtx.seuil_dotVSbig);

    config.setJSONObject("seuil", seuilConfig);


      // 3] Histogram
    JSONObject histoConfig = new JSONObject();

    histoConfig.setInt("redMin", myPtx.listZone.get(0).getMin());
    histoConfig.setInt("redMax", myPtx.listZone.get(0).getMax());
    histoConfig.setInt("redProto", myPtx.listZone.get(0).getProto());

    histoConfig.setInt("greenMin", myPtx.listZone.get(1).getMin());
    histoConfig.setInt("greenMax", myPtx.listZone.get(1).getMax());
    histoConfig.setInt("greenProto", myPtx.listZone.get(1).getProto());

    histoConfig.setInt("blueMin", myPtx.listZone.get(2).getMin());
    histoConfig.setInt("blueMax", myPtx.listZone.get(2).getMax());
    histoConfig.setInt("blueProto", myPtx.listZone.get(2).getProto());

    histoConfig.setInt("yellowMin", myPtx.listZone.get(3).getMin());
    histoConfig.setInt("yellowMax", myPtx.listZone.get(3).getMax());
    histoConfig.setInt("yellowProto", myPtx.listZone.get(3).getProto());

    config.setJSONObject("histogram", histoConfig);


      // 4] Trapeze
    JSONObject trapezeConfig = new JSONObject();

    trapezeConfig.setFloat("UpperLeftX", myCam.ROI[0].x);
    trapezeConfig.setFloat("UpperLeftY", myCam.ROI[0].y);
    trapezeConfig.setFloat("UpperRightX", myCam.ROI[1].x);
    trapezeConfig.setFloat("UpperRightY", myCam.ROI[1].y);
    trapezeConfig.setFloat("LowerRightX", myCam.ROI[2].x);
    trapezeConfig.setFloat("LowerRightY", myCam.ROI[2].y);
    trapezeConfig.setFloat("LowerLeftX", myCam.ROI[3].x);
    trapezeConfig.setFloat("LowerLeftY", myCam.ROI[3].y);

    config.setJSONObject("trapeze", trapezeConfig);
    

      // 5] Flash
    JSONObject flashConfig = new JSONObject();

    flashConfig.setInt("grayLevelUp", grayLevelUp);
    flashConfig.setInt("grayLevelDown", grayLevelDown);
    flashConfig.setInt("enabled", withFlash ? 1 : 0);
    flashConfig.setInt("margeScan", myPtx.margeScan);

    config.setJSONObject("flash", flashConfig);


      // 6] Misc
    JSONObject miscConfig = new JSONObject();
    miscConfig.setInt("withThread", withThread ? 1 : 0);

    config.setJSONObject("misc", miscConfig);


    saveJSONObject(config, _filePath);
  }


  /** 
   * Load all parametrs from a predifined file (data/config.json)
   */
  void loadConfig(String _filePath) {

    // Load keystone config
    ks.load("./data/configKeyStone.xml");

    // Load PTX config
    
    JSONObject config = loadJSONObject(_filePath);


      // 1] Camera
    JSONObject camConfig = config.getJSONObject("camera"); 

    if(myCam.isBrio) {
      myCam.modCam("set", "exposure_time_absolute", floor(camConfig.getFloat("exposure")) );
    } else {
      myCam.modCam("set", "exposure_absolute", floor(camConfig.getFloat("exposure")) );
    }

    myCam.modCam("set", "saturation", floor(camConfig.getFloat("saturation")) );
    myCam.modCam("set", "brightness", floor(camConfig.getFloat("brightness")) );
    myCam.modCam("set", "contrast",   floor(camConfig.getFloat("contrast")) );
    myCam.modCam("set", "white_balance_temperature", floor(camConfig.getFloat("temperature")) );  
    myCam.zoomCamera = camConfig.getFloat("zoom");

    
      // 2] Seuil
    JSONObject seuilConfig = config.getJSONObject("seuil"); 

    myPtx.seuilSaturation  = seuilConfig.getFloat("saturation");
    myPtx.seuilLuminance   = seuilConfig.getFloat("luminance");
    myPtx.tooSmallSurface  = seuilConfig.getInt("tooSmallSurface");
    myPtx.tooSmallContour  = seuilConfig.getInt("tooSmallContour");
    myPtx.seuil_lineVSfill = seuilConfig.getFloat("lineVSfill");
    myPtx.seuil_dotVSbig   = seuilConfig.getFloat("dotVSbig");


      // 3] Histogram
    JSONObject histoConfig = config.getJSONObject("histogram"); 

    myPtx.listZone.clear();
    myPtx.listZone.add( new hueInterval( histoConfig.getInt("redMin"),    histoConfig.getInt("redMax"),    histoConfig.getInt("redProto")  ) );
    myPtx.listZone.add( new hueInterval( histoConfig.getInt("greenMin"),  histoConfig.getInt("greenMax"),  histoConfig.getInt("greenProto")  ) );
    myPtx.listZone.add( new hueInterval( histoConfig.getInt("blueMin"),   histoConfig.getInt("blueMax"),   histoConfig.getInt("blueProto")  ) );
    myPtx.listZone.add( new hueInterval( histoConfig.getInt("yellowMin"), histoConfig.getInt("yellowMax"), histoConfig.getInt("yellowProto")  ) );

      
      // 4] trapeze
    JSONObject trapezeConfig = config.getJSONObject("trapeze"); 

    myCam.ROI[0].x = trapezeConfig.getFloat("UpperLeftX");
    myCam.ROI[0].y = trapezeConfig.getFloat("UpperLeftY");
    myCam.ROI[1].x = trapezeConfig.getFloat("UpperRightX");
    myCam.ROI[1].y = trapezeConfig.getFloat("UpperRightY");
    myCam.ROI[2].x = trapezeConfig.getFloat("LowerRightX");
    myCam.ROI[2].y = trapezeConfig.getFloat("LowerRightY");
    myCam.ROI[3].x = trapezeConfig.getFloat("LowerLeftX");
    myCam.ROI[3].y = trapezeConfig.getFloat("LowerLeftY");

      
      // 5] Flash
    JSONObject flashConfig = config.getJSONObject("flash"); 

    withFlash     = flashConfig.getInt("enabled") == 1;
    grayLevelUp   = flashConfig.getInt("grayLevelUp");
    grayLevelDown = flashConfig.getInt("grayLevelDown");
    myPtx.margeScan = flashConfig.getInt("margeScan");


      // 6] Misc
    JSONObject miscConfig = config.getJSONObject("misc"); 

    withThread      = miscConfig.getInt("withThread") == 1;

  }

  void managementKeyReleased() {
   if(keyCode == SHIFT) {
     shiftPressed = false;
   }

    switch(keyCode) {
    case (KeyEvent.VK_F9-15):
      showTutorial = false;
      break;  
    }

  }
    
    
  void managementKeyPressed() {      // MANAGEMENT KEYS (FK_F** - 5), the -5 is here because of a weird behavior of P3D for keymanagement

    if(keyCode == SHIFT) {
      shiftPressed = true;
    }
  
    switch(keyCode) {
    case (KeyEvent.VK_F1-15):
      isInConfig = false;
      myPtx.verboseImg = false;
      ks.stopCalibration();
      myCam.dotIndex = -1;
      noCursor();
      myGlobState = globState.PLAY;
      break;
    case (KeyEvent.VK_F2-15):
      ks.startCalibration();
      isInConfig = true;
      myPtx.verboseImg = true;
      myCam.dotIndex = -1;
      if(ks.isCalibrating())
        cursor();
      else
        noCursor();
      myGlobState = globState.MIRE;
      break;
    case (KeyEvent.VK_F3-15):
      ks.stopCalibration();
      isInConfig = true;
      myPtx.verboseImg = true;
      cursor();
      if (myGlobState == globState.CAMERA) {
        switch (myCamState) {
        case CAMERA_WHOLE:  
          noCursor();
          myCamState = cameraState.CAMERA_ROI;  
          break;
        case CAMERA_ROI:
          myCamState = cameraState.CAMERA_WHOLE;  
          break;
        }
      }
      
      if (myCam.dotIndex == -1)
        myCam.dotIndex = 0;

      myGlobState = globState.CAMERA;
      break;
    case (KeyEvent.VK_F4-15):
      noCursor();
      myCam.dotIndex = -1;
      ks.stopCalibration();
      isInConfig = true;
      myPtx.verboseImg = true;
      if ( myGlobState == globState.RECOG) {
        switch(  myRecogState ) {
        case RECOG_FLASH:    myRecogState = recogState.RECOG_ROI;      break;
        case RECOG_ROI:      myRecogState = recogState.RECOG_BACK;     break;
        case RECOG_BACK:     myRecogState = recogState.RECOG_COL;      break;
        case RECOG_COL:      myRecogState = recogState.RECOG_AREA;     break;
        case RECOG_AREA:     myRecogState = recogState.RECOG_CONTOUR;  break;
        case RECOG_CONTOUR:  myRecogState = recogState.RECOG_FLASH;    break;
        }
      }
      myGlobState = globState.RECOG;
      break;

    case (KeyEvent.VK_F5-15):
      cursor();
      debugType = (debugType + 1) % 4; 
      break;
    
    case (KeyEvent.VK_F6-15):
      loadFromGameStation();
      break;

    case (KeyEvent.VK_F7-15):
      if(shiftPressed) {
        myCam.mImgCroped.save("./drawings/img_"+month()+"-"+day()+"_"+hour()+"-"+minute()+"-"+second()+".png");
      } else {
        saveToGameStation();
      }
      break;

    case (KeyEvent.VK_F9-15):
      showTutorial = true;
      break;  

     case (KeyEvent.VK_F10-15): case (KeyEvent.VK_F10):
      if (!isScanning) {
        ks.stopCalibration();
        whiteCtp = 0;
        isScanning = true;
      }
      break;
    }
  }

  /** 
   * Ptx KeyPressed function that highjack most of the keys you could use.
   * Only triggered when in recognision mode.
   */
  void keyPressed() {

    float rotVal = 0.01;

    switch(key) {
    //Save/Load Config
    case 'w': saveConfig("data/config.json"); notify("Config Saved!", 255, 255, 255); break;
    case 'x': loadConfig("data/config.json"); notify("Config Loaded!", 255, 255, 255); break;
    case 'X': loadConfig("data/config_ref_1.json"); notify("Config Loaded!", 255, 255, 255); break;

    // Seuil
    case 'A': case 'a':
      if(key == 'a') myPtx.seuilLuminance  = Math.max(  0.f, myPtx.seuilLuminance + 1);
      else           myPtx.seuilLuminance  = Math.max(  0.f, myPtx.seuilLuminance - 1);
      myCam.updateImg();
      myPtx.parseImage(myCam.mImgCroped, myCam.mImgFilter, myCam.mImgRez, wFrameFbo, hFrameFbo, 2);
      break;

    case 'Z': case 'z':
      if(key == 'z') myPtx.seuilSaturation  = Math.max( 0.f, myPtx.seuilSaturation + 0.01);
      else           myPtx.seuilSaturation  = Math.max( 0.f, myPtx.seuilSaturation - 0.01);
      myCam.updateImg();
      myPtx.parseImage(myCam.mImgCroped, myCam.mImgFilter, myCam.mImgRez, wFrameFbo, hFrameFbo, 2);
      break;
    
    case 'E': case 'e':
      if(key == 'e') myPtx.seuil_dotVSbig  = Math.max( 0, myPtx.seuil_dotVSbig + 1);
      else           myPtx.seuil_dotVSbig  = Math.max( 0, myPtx.seuil_dotVSbig - 1);
      myCam.updateImg();
      myPtx.parseImage(myCam.mImgCroped, myCam.mImgFilter, myCam.mImgRez, wFrameFbo, hFrameFbo, 8);
      break;

    case 'R': case 'r':
      if(key == 'r') myPtx.seuil_lineVSfill  = Math.max( 0, myPtx.seuil_lineVSfill + 0.1);
      else           myPtx.seuil_lineVSfill  = Math.max( 0, myPtx.seuil_lineVSfill - 0.1);
      myCam.updateImg();
      myPtx.parseImage(myCam.mImgCroped, myCam.mImgFilter, myCam.mImgRez, wFrameFbo, hFrameFbo, 8);
      break;

    case 'T': case 't':
      if(key == 't') myPtx.tooSmallContour  = Math.max( 0, myPtx.tooSmallContour + 1);
      else           myPtx.tooSmallContour  = Math.max( 0, myPtx.tooSmallContour - 1);
      myCam.updateImg();
      myPtx.parseImage(myCam.mImgCroped, myCam.mImgFilter, myCam.mImgRez, wFrameFbo, hFrameFbo, 8);
      break;

    case 'Y': case 'y':
      if(key == 'y') myPtx.tooSmallSurface  = Math.max( 0, myPtx.tooSmallSurface + 1);
      else           myPtx.tooSmallSurface  = Math.max( 0, myPtx.tooSmallSurface - 1);
      myCam.updateImg();
      myPtx.parseImage(myCam.mImgCroped, myCam.mImgFilter, myCam.mImgRez, wFrameFbo, hFrameFbo, 8);
      break;


    // Flash
    case 'P': grayLevelUp     = Math.max(  0, grayLevelUp     - 3); break;
    case 'p': grayLevelUp     = Math.min(255, grayLevelUp     + 3); break;
    case 'O': grayLevelDown   = Math.max(  0, grayLevelDown   - 3); break;
    case 'o': grayLevelDown   = Math.min(255, grayLevelDown   + 3); break;
    case 'I': myPtx.margeScan = Math.max(  0, myPtx.margeScan - 1); break;
    case 'i': myPtx.margeScan = Math.min(200, myPtx.margeScan + 1); break;


    // Camera
    case 'd': 
      if(myCam.isBrio) {
        myCam.modCam("add", "exposure_time_absolute",  10);
      } else {
        myCam.modCam("add", "exposure_absolute",  10);
      }
      myCam.update();
      break;
    case 'D': 
      if(myCam.isBrio) {
        myCam.modCam("add", "exposure_time_absolute",  -10);
      } else {
        myCam.modCam("add", "exposure_absolute",  -10);
      }
      myCam.update();
      break;
    case 'f': myCam.modCam("add", "saturation",  2);         myCam.update(); break;
    case 'F': myCam.modCam("add", "saturation", -2);         myCam.update(); break;
    case 'g': myCam.modCam("add", "brightness",  2);         myCam.update(); break;
    case 'G': myCam.modCam("add", "brightness", -2);         myCam.update(); break;
    case 'h': myCam.modCam("add", "contrast",  2);           myCam.update(); break;
    case 'H': myCam.modCam("add", "contrast", -2);           myCam.update(); break;
    case 'j': myCam.modCam("add", "white_balance_temperature", 50);  myCam.update(); break;
    case 'J': myCam.modCam("add", "white_balance_temperature", -50); myCam.update(); break;


    // Histogram
    case 'S': case 's':
      if (myPtx.indexHue%2 != 0)
        myPtx.listZone.get(myPtx.indexHue/2).b =
          (myPtx.listZone.get(myPtx.indexHue/2).b + (key == 's' ? 359 : 1) )%360;
      else
        myPtx.listZone.get(myPtx.indexHue/2).a =
          (myPtx.listZone.get(myPtx.indexHue/2).a + (key == 's' ? 359 : 1) )%360;
          
      myCam.updateImg();
      myPtx.parseImage(myCam.mImgCroped, myCam.mImgFilter, myCam.mImgRez, wFrameFbo, hFrameFbo, 2);
      break;

    case 'Q': case 'q':
      myPtx.indexHue = (myPtx.indexHue + (key == 'q' ? 1 : 7))%8;
      break;


      // Trapeze
    case 'C': myCam.zoomCamera*=1.02;       break;
    case 'c': myCam.zoomCamera/=1.02;       break;

    case ' ': myCam.dotIndex = (myCam.dotIndex + 1)%4; break;

    }

    if (key == CODED && myCam.dotIndex != -1 ) { // conditions should be separated...
      switch(keyCode) {
      case UP    :
				myCam.ROI[myCam.dotIndex].y -= 1;
				calculateHomographyMatrice(wFrameFbo, hFrameFbo, myCam.ROI);
				scanCam();
				break;
      case DOWN  :
				myCam.ROI[myCam.dotIndex].y += 1;
				calculateHomographyMatrice(wFrameFbo, hFrameFbo, myCam.ROI);
				scanCam();
				break;
      case LEFT  :
				myCam.ROI[myCam.dotIndex].x -= 1;
				calculateHomographyMatrice(wFrameFbo, hFrameFbo, myCam.ROI);
				scanCam();
				break;
      case RIGHT :
				myCam.ROI[myCam.dotIndex].x += 1;
				calculateHomographyMatrice(wFrameFbo, hFrameFbo, myCam.ROI);
				scanCam();
				break;
      }
    }

  }
  
  // GAME STATION
  
  void loadFromGameStation() {
    // 1) get list of file in directory
    String fPath = sketchPath() + "/F6_game_station";
    //ArrayList<String> listFileStr = myCam.exeMult("ls "+fPath);
    //fIndex = (fIndex + 1)%listFileStr.size();
    //fName = listFileStr.get(fIndex);
//    String filePath = "./F6_game_station/" + fName;

      
    File folder = new File(fPath);
    File[] files = folder.listFiles();
      
  
    fIndex = (fIndex + 1)%files.length;
    fName = files[fIndex].toString();

//      for(int i = 0; i<listFileStr.size(); ++i) println(listFileStr.get(i));

    // 2) select the "next one"
    String filePath = fName;

//      if(shiftPressed) {
//        filePath = fName;
//        myCam.mImgCroped.save("./drawings/img_"+month()+"-"+day()+"_"+hour()+"-"+minute()+"-"+second()+".png");
//      } else {
      filePath = fName;
//      }
    // 3) launch
    myCam.mImgCroped = loadImage(filePath);

    myCam.mImgFilter.copy(myPtxInter.myCam.mImgCroped, 0, 0, myPtxInter.myCam.wFbo, myPtxInter.myCam.hFbo, 0, 0, myPtxInter.myCam.wFbo, myPtxInter.myCam.hFbo);
    myCam.mImgRez.copy(myPtxInter.myCam.mImgCroped, 0, 0, myPtxInter.myCam.wFbo, myPtxInter.myCam.hFbo, 0, 0, myPtxInter.myCam.wFbo, myPtxInter.myCam.hFbo);
    myCam.mImgCroped = createImage(myPtxInter.myCam.wFbo, myPtxInter.myCam.hFbo, RGB);
    myCam.mImgCroped.copy(myPtxInter.myCam.mImgFilter, 0, 0, myPtxInter.myCam.wFbo, myPtxInter.myCam.hFbo, 0, 0, myPtxInter.myCam.wFbo, myPtxInter.myCam.hFbo);

    scanClr();
    atScan();
    println(fName);
 
    strUI = "Loaded -=" + fName + " =- from GameStation!";
    togUI.reset(true);

  }
  
  void saveToGameStation() {
    myCam.mImgCroped.save("./F6_game_station/img_"+month()+"-"+day()+"_"+hour()+"-"+minute()+"-"+second()+".png");
    
    strUI = "Saved to GameStation!";
    togUI.reset(true);
  }
  
}
