/* //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>// //<>//
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

import java.util.Iterator;
import java.util.LinkedHashSet;
import java.util.LinkedHashMap;
import java.util.Collections;

import java.util.Arrays;
import java.util.Comparator;


public enum DIRECTION { EAST, WEST, NORTH, SOUTH };
class vertex_t { double u, v, x, y; public vertex_t( double _u, double _v, double _x, double _y) {x=_x; y=_y; u=_u; v=_v;} }

/**
 * This class defines the core algorithm for drawing recognition and
 * optical processing.
 *
 *
 * @author  Roman Miletitch
 * @version 0.7
 *
 **/
//<>//
public class ptx {

  ArrayList<area> listArea; 

  // RECOG COLORS
  ArrayList<hueInterval> listZone;
  hueInterval backHue;
  boolean hasBackHue;

  float seuilSaturation, seuilValue;

  // Hues
  int[] histHue;
  int[] hueRef;
  int indexHue;
  
  // Local but not so local
  int[] ids;
  int[] idsArea;
  ArrayList<vec2i> pixest;

  int ww, hh;
  int rMask;
  int margeScan;
  
  ArrayList<Integer> idLabels;
  public int tooSmallThreshold;
  public int tooSmallContourThreshold;

  public boolean verboseImg;
  
  public vec2i specROItl, specROIbr;

  // TEMP
  public float seuil_ratioSurfacePerimetre;
  public float seuil_tailleSurface;
  public int seuil_smallArea;

  public ptx() {

    tooSmallThreshold = 40;
    tooSmallContourThreshold = 33;
    
    backHue = new hueInterval();
    hasBackHue = false;

    margeScan = 0;

    histHue = new int[360];
    hueRef = new int[360];

    listZone = new ArrayList<hueInterval>();
    pixest   = new ArrayList<vec2i>();
    idLabels = new ArrayList<Integer>();
    listArea = new ArrayList<area>();

    verboseImg = false;

    rMask = 270;

    indexHue = 0;

    //showPince = true;

    listZone.add(new hueInterval(350, 50));
    listZone.add(new hueInterval(90, 150));
    listZone.add(new hueInterval(210, 270));
    listZone.add(new hueInterval(60, 80));

    for (int i = 0; i < 360; ++i) {
      hueRef[i] = -1;
      histHue[i] = 0;
    }

    seuilSaturation = 0.32;
    seuilValue = 255;
    
    specROItl = new vec2i(0,0);
    specROIbr = new vec2i(9999, 9999);


    // TEMP
    seuil_ratioSurfacePerimetre = 1.3;
    seuil_tailleSurface = 400;
    seuil_smallArea = 200;
  }
 //<>// //<>// //<>// //<>// //<>// //<>//
  
  /** 
   * Main function that calls other sub function in order to
   * parse the selected image and get the list of areas.
   * @param   in           Origine image
   * @param   outFilter    Filtered image
   * @param   outRez       End result image 
   * @param   _w           width of the image
   * @param   _h           height of the image
   */
  public boolean parseImage(PImage in, PImage outFilter, PImage outRez, int _w, int _h, int stopAt) {

    System.out.println("----------------------------------");
    System.out.println("--- PARSE IMAGE ---");

    long globStart = System.currentTimeMillis();
    long locStart  = System.currentTimeMillis();

    // 0) RESET & CLEAR
    reset(_w, _h);
    System.out.println("0) Reset, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();
    
    if(stopAt == 0) return true;

    // 1) ISOLATE PIXELS OF INTEREST
    if ( ! isolateForeground(in, outFilter, outRez))
      return false;
    System.out.println("1) Isolate foreground, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();
    
    if(stopAt == 1) return true;

    // 2) SMOOTH
    smooth(outFilter, outRez);
    System.out.println("2) Smooth, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();
     
    if(stopAt == 2) return true;

    // 3) AGREGATE IN REGIONS
    extractRegions();
    System.out.println("3) Create Areas, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();
    
    // 3.1) ERASE SMALL AREAS
    removeSmallAreas();
    System.out.println("3.1) Remove small areas, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();
       
    if(stopAt == 3) return true;

    // 4) CONTOUR
    detectContour();
    System.out.println("4) Create & Organise Contour, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();
    
    // 4.1) ERASE SMALL COUNTOUR
    removeAreaWithSmallContour();
    System.out.println("4.1) Remove areas sith small, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();
    System.out.println("Final nbr Area: " + listArea.size() );
    
    // 4.2) DESCRIBE SHAPE
    describeShape();
    System.out.println("4.2) Describe shape, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();

    // 4.3) A l'arrache, idArea ids (colId); !!!REVOIR!!!
    for (area it : listArea)
      for (vec2i itPos : it.posXY) {
        idsArea[itPos.y * _w + itPos.x] = it.id;
        ids[itPos.y * _w + itPos.x] = it.colId;
      }
    System.out.println("4.3) update ids & idAreas, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();
    
    if(stopAt == 4) return true;

    // 5) PROXIMITY SHAPES
    proximityArea();
    System.out.println("5) List proximity shape, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();
    
    if(stopAt == 5) return true;
    
    // 6) Create PSHAPE SHAPES // revoir ou on mets ça
    for (area it : listArea)
      it.createPShape();
      
    System.out.println("6) Create PShape, in: " + (System.currentTimeMillis()-locStart) );
    locStart = System.currentTimeMillis();
    
    if(stopAt == 6) return true;

    System.out.println("------------------------" );
    System.out.println("---- TOTAL, in: " + (System.currentTimeMillis()-globStart) );

    System.out.println("Post nbr Area: " + listArea.size() );


    return true;
  }

  /** 
   * Reset all information from previous scans, allowing for a fresh new one.
   * @param  _w    width of the image
   * @param  _h    height of the image
   */
  public void reset(int _w, int _h) {
    
    ww = _w;
    hh = _h;
    ids = new int[_w*_h];
    idsArea = new int[_w*_h];
    
    pixest.clear();
    listArea.clear();

    Arrays.fill(ids, -1);
    Arrays.fill(hueRef, -1);
    Arrays.fill(histHue, 0);

    for (hueInterval myZone : listZone)
      for (int hue : myZone.getRange())
        hueRef[hue % 360] = myZone.getRef();
  }

  /** 
   * Isolate the color part of the image, mainly based on saturation
   * @param  in          Source Image
   * @param  outFilter   Destination Image Filtered
   * @param  outRez      Destination Image Result
   * @param  _w          width of the image
   * @param  _h          height of the image
   */
  //  public boolean isolateForeground(uint8_t* in, uint8_t* outFilter, uint8_t* outRez, int _w, int _h) {
  public boolean isolateForeground(PImage in, PImage outFilter, PImage outRez) {
    int sizeDrawing = 0;
    int hue;

    in.loadPixels();

    if(verboseImg) {
      outFilter.loadPixels();
      outRez.loadPixels();
    }
    
    // temp
    int marge = 7;
    ptx_color cTN, cT;
    cTN = new ptx_color();

    for (int i = 0; i < ww*hh; i++) {
      cT = new ptx_color(red(in.pixels[i]), green(in.pixels[i]), blue(in.pixels[i])); // use the "++" on pointer.

      if (
        // == Enough Color and not too White
           cT.r + cT.g + cT.b < seuilValue*3
        && cT.getS() >= seuilSaturation 
        
        // == Not on the surface of the pince
        //&& (!showPince || (i / _w > heightPince + marge || i%_w < _w/2 - widthPince/2 - marge || i%_w > _w/2 + widthPince/2 + marge ))
        // == Not touching the edge (because of potential issue wiwth the turtle algo for contour)
        &&  i/ ww != 0 && i/ ww != hh-1 && i%ww != 0 && i%ww != ww-1 // FOR NOW
        // == Margin of scan, because always some issues around...
        && i/ ww > margeScan && i/ ww < hh-margeScan-1 && i%ww > margeScan && i%ww < ww-1-margeScan
        // == Matching hue
        // && hueRef[ int(360 * cT.getH()) ] != -1
        // == Not the color of the "background"
        && ( !hasBackHue || !backHue.contains( floor(360*cT.getH()) ))
        // == Mask Disk
        //        && (i%_w-_w*0.5)*(i%_w-_w*0.5) + (i/_w-_h*0.5)*(i/_w-_h*0.5) < rMask*rMask 
        // == SpecROI
        && specROItl.x < i%ww && i%ww < specROIbr.x && specROItl.y < i/ww && i/ww < specROIbr.y
        ) {

        hue = int(360 * cT.getH());
        histHue[hue]++;

        // Non Matching hue
        if (hueRef[int(360 * cT.getH())] == -1) {
          // OUT OF BONDS
          if(verboseImg) {
            outFilter.pixels[i] = color(60);
            outRez.pixels[i] = color(60);
          }
        } else {
          // GOOD
          sizeDrawing++;
          ids[i] = hueRef[hue];

          pixest.add(new vec2i(i%ww, i / ww));

          if(verboseImg) {
            cTN.fromHSV(ids[i], 1, 1);
            outRez.pixels[i] = color(int(cTN.r * 255), int(cTN.g * 255), int(cTN.b * 255));
          }
        }
        idsArea[i] = -1;
      } else {
        // BAD
        ids[i] = -1;
        idsArea[i] = -1;

        if(verboseImg) {
          outFilter.pixels[i] = color(0);
          outRez.pixels[i] = 0;
        }
      }
    }

    System.out.println("SIZE drawing: " + (sizeDrawing * 1.f / (ww*hh)) );
    if (sizeDrawing  * 1.f / (ww*hh) > 0.75) {
      System.out.println("TOO BIG DRAWING!");
      return false;
    }

    // Weight the color hues
    for (int i = 0; i < 360; ++i)
      histHue[i] /= 1;

    if(verboseImg) {
      outFilter.updatePixels();
      outRez.updatePixels();
    }
    
    return true;
  }

  /** 
   * Smoothing the resulting information (blur algo, black & white)
   * @param  _w          width of the image
   * @param  _h          height of the image
   * @param  outFilter   Image to process
   */
  public void smooth(PImage _outFilter, PImage _outRez) {

    System.out.println("size: " + pixest.size());
    
    if(verboseImg) {
      _outFilter.loadPixels();
      _outRez.loadPixels();
    }
    
    
    int dense = 0, i=0, j=0;

    Iterator<vec2i> myVec = pixest.iterator();
    
    while (myVec.hasNext()) {
      vec2i s = myVec.next(); // must be called before you can call i.remove()

      i = s.x; 
      j = s.y;

      dense = 0;
      if (ids[(j + 1)*ww + (i - 1)] != -1) dense++;
      if (ids[(j)*ww + (i - 1)] != -1) dense++;
      if (ids[(j - 1)*ww + (i - 1)] != -1) dense++;

      if (ids[(j + 1)*ww + (i)] != -1) dense++;
      //
      if (ids[(j - 1)*ww + (i)] != -1) dense++;

      if (ids[(j + 1)*ww + (i + 1)] != -1) dense++;
      if (ids[(j)*ww + (i + 1)] != -1) dense++;
      if (ids[(j - 1)*ww + (i + 1)] != -1) dense++;

      if (dense <= 3) {
        // BAD
        ids[j*ww + i] = -1;
    
        if(verboseImg) {
          _outFilter.pixels[i] = color(0);
          _outRez.pixels[i] = color(0);
        }
        
        myVec.remove();
      }
    }
   
    
    System.out.println("size: " + pixest.size());
    
    if(verboseImg) {
      _outFilter.updatePixels();
      _outRez.updatePixels();
    }
  }


  private int find(ArrayList<Integer> parents, int x) {
    //  return (parents[x]==x) ? x : find(parents,parents[x]);
    if (parents.get(x)==x) {
      return x;
    } else {
      return find(parents, parents.get(x));
    }
  }

  private void unionCC(ArrayList<Integer> parents, int x, int y) {
    int xRoot = find(parents, x);
    int yRoot = find(parents, y);
    parents.set(xRoot, yRoot);
  }

  /** 
   * Extract region as group of pixels for each colors.
   * This functions generate the areas that we will then process further.
   * @param  _w          width of the image
   * @param  _h          height of the image
   */
  public void extractRegions() {

    int[] data = ids.clone();
    //TODO chgeck    idLabels = std::vector<unsigned int>(_w*_h,0);
    idLabels = new ArrayList<Integer>( Collections.nCopies(ww*hh, 0) );

    int mark = 1; //0 is for background pixels

    //to store equivalence between neighboring labels
    ArrayList<Integer> equivalences = new ArrayList<Integer>();
    equivalences.add(0);//to label background

    ArrayList<Integer> neighborsIndex = new ArrayList<Integer>();
    neighborsIndex.add(-1-ww);//north west neighbor
    neighborsIndex.add(-ww);//north neighbor
    neighborsIndex.add(-ww+1);//north-east neighbor
    neighborsIndex.add(-1);//west neighbor

    // Check what is a set, what is a map, and possible stuff in Java.

    //-----------
    // First Pass
    for (int i=0; i<ww*hh; ++i) {
      if (data[i]!=-1) {//is not background

        //get the neighboring elements of the current element
        //  std::set<unsigned int> neighborsLabels;
        //  LinkedHashSet<E> OR HashSet ... ?
        LinkedHashSet<Integer> neighborsLabels = new LinkedHashSet<Integer>();
        for (int j=0; j<neighborsIndex.size(); ++j) {  // Parse through all interesting neighbors
          int neighborsIdx=i+neighborsIndex.get(j);
          if (neighborsIdx>=0 && neighborsIdx<ww*hh) {   // Neighbor is inside range
            if (data[neighborsIdx]==data[i]) {         // Neighbor is not background
              neighborsLabels.add(idLabels.get(neighborsIdx));
            }
          }
        }

        if (neighborsLabels.size()==0) { // No neighbors
          equivalences.add(mark);
          idLabels.set(i, mark);
          mark++;
        } else {

          //find the neighbors with the smallest label & assign it to current label
          int minLabel = Integer.MAX_VALUE;
          for (int it : neighborsLabels)
            minLabel = (it < minLabel) ? it : minLabel;
          idLabels.set(i, minLabel);

          //update equivalences
          for (int it1 : neighborsLabels)
            for (int it2 : neighborsLabels)
              unionCC(equivalences, equivalences.get(it1), it2);
        }
      }
    }


    //second pass
    LinkedHashMap<Integer, Integer> continiousLabel = new LinkedHashMap<Integer, Integer>();
    int nextLabel=1;
    for (int i=0; i<idLabels.size(); ++i) {
      if (idLabels.get(i)>0) {
        int ccId = find(equivalences, idLabels.get(i));
        if (! continiousLabel.containsKey(ccId)) {
          continiousLabel.put(ccId, nextLabel);
          nextLabel++;
        }
        idLabels.set(i, continiousLabel.get(ccId));
      }
    }

    // Create areas
    LinkedHashMap<Integer, Integer> labelToArea = new LinkedHashMap<Integer, Integer>();
    for (int i = 0; i < idLabels.size(); ++i) {
      if (idLabels.get(i) != 0) // We're on foreground
        if (! labelToArea.containsKey(idLabels.get(i))) { // Not known label => add a new area
          labelToArea.put(idLabels.get(i), listArea.size());
          listArea.add( new area(listArea.size(), new vec2i(i%ww, i / ww), ids[i]) );
        } else {
          listArea.get( labelToArea.get(idLabels.get(i)) ).posXY.add( new vec2i(i%ww, i / ww) );
        }
    }

    //associateAreasWithColorId
    for (area it : listArea)
      for (int i = 0; i < listZone.size(); ++i)
        if ( listZone.get(i).contains(it.hue) )
          it.colId = i;

    System.out.println("First nbr Area: " + listArea.size() );
  }


  /** 
   * Removes area which size (surface) is under a threshold
   * @param  _w          width of the image
   * @param  _h          height of the image
   */
  public void removeSmallAreas() {

    Iterator<area> myArea = listArea.iterator();
    while (myArea.hasNext()) {
      area it = myArea.next(); // must be called before you can call i.remove()

      if (it.posXY.size() <= tooSmallThreshold) {
        for (vec2i itPos : it.posXY) {
          ids[itPos.y * ww + itPos.x] = -1; // reset ids
          idsArea[itPos.y * ww + itPos.x] = -1; // reset ids
        }
        myArea.remove();
      }
    }
  }

  /** 
   * Extract controur from the regions previously extracted.
   * Both information is available in the area class.
   * @param  _w          width of the image
   * @param  _h          height of the image
   */
  public void detectContour() {

    // 0 === Compute Center by averaging
    for (area it : listArea) {
      for (vec2i itPx : it.posXY)
        it.center.addMe(itPx);
      it.center.x /= it.posXY.size();
      it.center.y /= it.posXY.size();
    }


    for (area it : listArea) {

      ArrayList<vec2i> disContour = new ArrayList<vec2i>();

      // 1 === Isolate all pixels of contour
      for (vec2i itPx : it.posXY) {

        // If pixel on the boundary of the image => CONTOUR
        if (itPx.x == 0 || itPx.x == ww - 1 || itPx.y == 0 || itPx.y == hh - 1) {
          disContour.add(itPx);
        } else {

          // If one of the neighbor of the pixel has different label => CONTOUR
          int idPx = itPx.y*ww + itPx.x;
          if ((idLabels.get(idPx)
            & idLabels.get(idPx - 1)  & idLabels.get(idPx + 1) //weast and east neighbors
            & idLabels.get(idPx + ww) & idLabels.get(idPx - ww) //south and north neighbors
            ) != idLabels.get(idPx)) {
            disContour.add(itPx);
          }
        }
      }

      // 2 === Orientate and define the sub contours (i.e. holes)
      //uses paper turtle algorithm to find all point on each boundary
      //assertion : pixel is never on image edges...

      while (disContour.size() > 0) {
        ArrayList<vec2i> boundary = new ArrayList<vec2i>(); // aimed oriented boundary

        //get first boundary point
        vec2i firstPoint = disContour.get(0);

        boundary.add(firstPoint);
        disContour.remove(firstPoint);

        DIRECTION dir=DIRECTION.NORTH;

        vec2i currPoint = updateIndex(firstPoint, dir, ww);

        while (currPoint.diffFrom(firstPoint)) { 
          if (idLabels.get(currPoint.y*ww + currPoint.x) == idLabels.get(firstPoint.y*ww + firstPoint.x)) {
            // Pixel on the area's boundary, remove for non oriented & add to oriented.
            if (boundary.get(boundary.size() - 1).diffFrom(currPoint)) //store boundary point (if not just previously stored already) // TODO: CHECK IF ITS EVER TRIGGERED
              boundary.add(currPoint);
            // Get rid of the point in boundariesPoints

            // Remove elements that are same as currPoint from boundariesPoints.
            // No idea why, but issue with ".remove()" so hand coded
            Iterator<vec2i> myVec = disContour.iterator();
            while (myVec.hasNext()) {
              vec2i itV = myVec.next(); // must be called before you can call i.remove()

              if (itV.x == currPoint.x && itV.y == currPoint.y) {
                myVec.remove();
              }
            }

            dir = toTheLeft(dir);
          } else {
            // Pixel NOT on the area's boundary
            dir=toTheRight(dir);
          }
          currPoint = updateIndex(currPoint, dir, ww);
        }

        it.listContour.add(boundary);
      }
    }
  }


  /** 
   * Removes area which perimeter (contour) is under a threshold
   * @param  _w          width of the image
   * @param  _h          height of the image
   */
  public void removeAreaWithSmallContour() {

    for (area it : listArea) {
      Iterator<ArrayList<vec2i>> itContour = it.listContour.iterator();

      while (itContour.hasNext()) {
        ArrayList<vec2i> presContour = itContour.next(); // must be called before you can call i.remove()
        if (presContour.size() < tooSmallContourThreshold) { //not enough to create a real 2D shape
          itContour.remove();
        }
      }
    }


    Iterator<area> myArea = listArea.iterator();
    while (myArea.hasNext()) {
      area it = myArea.next(); // must be called before you can call i.remove()

      if (it.listContour.isEmpty()) {
        for (vec2i itPos : it.posXY) {
          ids[itPos.y * ww + itPos.x] = -1; // reset ids
          idsArea[itPos.y * ww + itPos.x] = -1; // reset ids
        }
        myArea.remove();
      }
    }
  }

  /** 
   * Adding spacial descriptors to all area extracted from the drawing.
   */
  public void describeShape() {

    for (area it : listArea) {

      if (it.listContour.size() > 1) {
        it.myShape = area_shape.GAP;
      } else {

        if (it.posXY.size() < seuil_tailleSurface) {
          it.myShape = area_shape.DOT;
        } else {

          //      if (it->disContour.size() > 1.3 * std::sqrt(4 * 3 * it->posXY.size())) {
          if (it.listContour.get(0).size() > seuil_ratioSurfacePerimetre * Math.sqrt(4 * 3 * it.posXY.size())) {
            it.myShape = area_shape.LINE;
          } else {
            it.myShape = area_shape.FILL;
          }
        }
      }
    }
  }


  void proximityArea() {

    int k = 3;
    ArrayList<vec2i> contA = new ArrayList<vec2i>(), contB = new ArrayList<vec2i>();
    vec2i dist = new vec2i(), temp = new vec2i(), from = new vec2i(), to = new vec2i();

    for (int i = 0; i < listArea.size(); ++i)
      for (int j = i + 1; j < listArea.size(); ++j) {

        contA = listArea.get(i).listContour.get(0);
        contB = listArea.get(j).listContour.get(0);
        dist = contB.get(0).subTo( contA.get(0) );

        from = contA.get(0);
        to = contB.get(0);

        for (int ii = 0; ii < contA.size(); ii+=k)
          for (int jj = 0; jj < contB.size(); jj+=k) {
            temp = contB.get(jj).subTo( contA.get(ii) );
            if (temp.squaredLength() < dist.squaredLength()) {
              dist = temp;
              from = contA.get(ii);
              to = contB.get(jj);
            }
          }

        listArea.get(i).listProx.add(new proxArea(listArea.get(j).id, listArea.get(j).center, dist, from, to));
        listArea.get(j).listProx.add(new proxArea(listArea.get(i).id, listArea.get(i).center, dist.multBy(-1), to, from));
      }


    // Sort by proximity
    //    for (area itA : listArea)
    //      Arrays.sort(itA.listProx, new SortbyDist()); 
    ////      std::sort(itA->listProx.begin(), itA->listProx.end(), &compareDist);


    for (area itA : listArea)
      Collections.sort(itA.listProx, new Comparator<proxArea>() {
        @Override
          public int compare(proxArea _a, proxArea _b) {
          return (_a.pos.x*_a.pos.x + _a.pos.y*_a.pos.y) - (_b.pos.x*_b.pos.x + _b.pos.y*_b.pos.y);
        }
      }
    );
  }


  DIRECTION toTheLeft(DIRECTION currentDir) {
    switch (currentDir) {
    case EAST:  
      return DIRECTION.NORTH;
    case NORTH: 
      return DIRECTION.WEST;
    case WEST:  
      return DIRECTION.SOUTH;
    case SOUTH: 
      return DIRECTION.EAST;
    }
    System.out.println("WARNING, ISSUE!!! in DrawPlay.toTheLeft");
    return DIRECTION.NORTH;
  }

  DIRECTION toTheRight(DIRECTION  currentDir) {
    switch(currentDir) {
    case EAST:  
      return DIRECTION.SOUTH;
    case SOUTH: 
      return DIRECTION.WEST;
    case WEST:  
      return DIRECTION.NORTH;
    case NORTH: 
      return DIRECTION.EAST;
    }
    System.out.println("WARNING, ISSUE!!! in ptx.toTheRight");
    return DIRECTION.NORTH;
  }

  int updateIndex(int idx, DIRECTION dir, int width) {
    switch(dir) {
    case EAST:  
      return idx+1;
    case SOUTH: 
      return idx+width;
    case WEST:  
      return idx-1;
    case NORTH: 
      return idx-width;
    }
    System.out.println("WARNING, ISSUE!!! in ptx.updateIndex");
    return -2;
  }

  vec2i updateIndex(vec2i _v, DIRECTION dir, int width) {
    vec2i _vT = new vec2i();
    _vT.x = _v.x; 
    _vT.y = _v.y;

    switch(dir) {
    case EAST:  
      _vT.x+=1; 
      break;
    case SOUTH: 
      _vT.y+=1; 
      break;
    case WEST:  
      _vT.x-=1; 
      break;
    case NORTH: 
      _vT.y-=1; 
      break;
    }
    return _vT;
  }

}
