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

import java.util.*;

public enum area_shape { DOT, LINE, GAP, FILL };

public class proxArea {
  proxArea(int _id, vec2i _center, vec2i _pos, vec2i _from, vec2i _to) {
    id =_id;
    pos = _pos;
    from = _from;
    center = _center;
    to = _to;
  }

  int id;
  vec2i pos;
  vec2i center;
  vec2i from, to;
};

/**
 * This class describe what an area is in the context of the ptx library.
 * Area are generated when a picture is scanned, and are defined by 
 * descriptors, center, perimetrs, colorId, and other useful graphical
 * vocabulary.
 *
 *
 * @author  Roman Miletitch
 * @version 0.7
 *
 **/

public class area {

  int id;
  int hue;
  int protoHue;

  int colId;
  area_shape myShape;

  vec2i center;
  ArrayList<vec2i> posXY;
  ArrayList< ArrayList<vec2i> > listContour;

  // Relation to other areas
  ArrayList<proxArea> listProx; // relative positions of other areas
  ArrayList<Integer> listOverMe; // Areas that contains me
  ArrayList<Integer> listInsideMe; // Areas that I contain
  ArrayList<proxArea> listContact; // relative positions of touched areas
  
  // For Drawing purposes
  ptx_color c;
  PShape s;

  public area() {
    center = new vec2i();
    posXY = new ArrayList<vec2i>(); 
    listContour = new ArrayList< ArrayList<vec2i> >(); 
    listProx = new ArrayList<proxArea>();
    listContact  = new ArrayList<proxArea>();
    
    c = new ptx_color();
  }

  public area(int _id, vec2i _pos, int _hue) {
    id = _id;
    hue = _hue;
    colId = -1;
    myShape = area_shape.LINE;

    center = new vec2i();
    posXY = new ArrayList<vec2i>(); 
    posXY.add(_pos);
    listContour = new ArrayList< ArrayList<vec2i> >(); 
    listProx = new ArrayList<proxArea>();
    listContact  = new ArrayList<proxArea>();
    
    
    c = new ptx_color();
  }
  
  // copy constructor 
    area(area a) { 
      id = a.id;
      hue = a.hue;
      colId = a.colId;
      myShape = a.myShape;
    
      center = a.center;
      posXY = a.posXY;
      listContour = a.listContour;
    
      // Relation to other areas
      listProx = a.listProx; // relative positions of other areas
      listOverMe = a.listOverMe; // Areas that contains me
      listInsideMe = a.listInsideMe; // Areas that I contain
      listContact = a.listContact; // relative positions of touched areas
      
      // For Drawing purposes
      c = a.c;
      s = a.s;
    } 

  public int getHue() {
    if(myPtxInter.protoCol)
      return protoHue;
    else
      return hue;

  }

  public void createPShape() {
    c = new ptx_color();
    c.fromHSV(hue, 1, 1);
        
    s = createShape();
    if(listContour.size() == 0)
      return;
      
    s.beginShape();
    s.noStroke();
    s.fill(c.r*255, c.g*255, c.b*255);

    // 1) Exterior part of shape, clockwise winding
    for (vec2i itPos : listContour.get(0))
      s.vertex(itPos.x, itPos.y);
    s.vertex(listContour.get(0).get(0).x, listContour.get(0).get(0).y);
  
      // 2) Interior part of shape, counter-clockwise winding
      for (int i = 1; i < listContour.size(); ++i) {
        s.beginContour();
        for (vec2i itPos : listContour.get(i))
          s.vertex(itPos.x, itPos.y);
        s.endContour();
        s.vertex(listContour.get(i).get(0).x, listContour.get(i).get(0).y);
      }
  
    s.endShape(); 
  }
  
  public void draw(float _k) {
    s.setFill(color(c.r*255, c.g*255, c.b*255, _k*255) );
    myPtxInter.mFbo.shape(s);    
  }
  
}
