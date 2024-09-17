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
 * Simple class defining a 2 dimension mathematical vector with integers
 * as well as helper class to help manipulating them.
 *
 * @author  Roman Miletitch
 * @version 0.7
 *
 **/


public class vec2i {

  public int x, y;  

  public vec2i() { 
    x =  0; 
    y =  0;
  }
  
  public vec2i(int _x, int _y) { 
    x = _x; 
    y = _y;
  }
  
  public vec2i(float _x, float _y) { 
    x = (int) Math.floor(_x); 
    y = (int) Math.floor(_y);
  }

  public void addMe(vec2i _a) { 
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

  public vec2i addTo(vec2i _a) { 
    return new vec2i(x + _a.x, y + _a.y);
  }
  
  public vec2i subTo(vec2i _a) { 
    return new vec2i(x - _a.x, y - _a.y);
  }
  
  public vec2i multBy(float _k) { 
    return new vec2i((int) Math.floor(x * _k), (int) Math.floor(y * _k));
  }
  
  public vec2i divBy(float _k) { 
    return new vec2i((int) Math.floor(x / _k), (int) Math.floor(y / _k));
  }

  public boolean equals(vec2i _a) { 
    return  (x == _a.x && y == _a.y);
  }
  
  public boolean diffFrom(vec2i _a) { 
    return !(x == _a.x && y == _a.y);
  }

  public float length() {
    return sqrt(x*x + y*y);
  }

  public float squaredLength() {
    return x*x + y*y;
  }
}