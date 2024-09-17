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
 
 /**
 * Simple class defining a 2 dimension mathematical vector with floats
 * as well as helper class to help manipulating them.
 *
 * @author  Roman Miletitch
 * @version 0.7
 *
 **/


public class vec2f {

  public float x, y;

  public vec2f() { 
    x =  0; 
    y =  0;
  }
  
  public vec2f(float _x, float _y) { 
    x = _x; 
    y = _y;
  }

  public void addMe(vec2f _a) { 
    x += _a.x; 
    y += _a.y;
  }
  
  public void multMe(float _k) { 
    x *= _k;   
    y *= _k;
  }
  
  public void divMe(float _k) { 
    x /= _k;   
    y /= _k;
  }

  public vec2f addTo(vec2f _a) { 
    return new vec2f(x + _a.x, y + _a.y);
  }
  
  public vec2f subTo(vec2f _a) { 
    return new vec2f(x - _a.x, y - _a.y);
  }
  
  public vec2f multBy(float _k) { 
    return new vec2f(x * _k, y * _k  );
  }
  
  public vec2f divBy(float _k) { 
    return new vec2f(x / _k, y / _k  );
  }
  
  public float length() {
    return sqrt(x*x + y*y);
  }
  
    
  public String toString() {
    return "(" + x + "," + y + ")";
  }
}