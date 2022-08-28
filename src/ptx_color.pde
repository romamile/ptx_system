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
* This class is a model of color, both on the RGB and HSV space.
*
* @author  Roman Miletitch
* @version 0.7
*
**/

class ptx_color {

	public float r,g,b;

	public ptx_color() 							               { r =  0; g =  0; b =  0; }
	public ptx_color(float _r, float _g, float _b) { r = _r; g = _g; b = _b; }

	public void fromHSV(float _h, float _s, float _v) {
		int i;
		float f, p, q, t;

		if (_s == 0) {
			// achromatic (grey)
			r = g = b = _v;
			return;
		}

		_h /= 60;
		i = (int) Math.floor(_h);
		f = _h - i;
		p = _v * (1 - _s);
		q = _v * (1 - _s * f);
		t = _v * (1 - _s * (1 - f));

		switch (i) {
		case 0:		r = _v; g = t;  b = p;  break;
		case 1:		r = q;  g = _v; b = p;  break;
		case 2:		r = p;  g = _v; b = t;  break;
		case 3:		r = p;  g = q;  b = _v; break;
		case 4:		r = t;  g = p;  b = _v; break;
		default:	r = _v; g = p;  b = q;  break;	// case 5
		}

		return; 
	}
	
  /** 
  * Helper Function that returns the hue of the color.
  * @return          <code>float</code> between 0 and 1.
  */
	public float getH() {
	
		float min, max, delta;
		float h,s,v;

		min = Math.min( r, Math.min(g, b) );
		max = Math.max( r, Math.max(g, b) );
		delta = max - min;

		if( max == 0 ) {
			// r = g = b = 0		// s = 0, h is undefined
			return 0;
		}

		if( r == max )			h = ( g - b ) / delta;		// between yellow & magenta
		else if( g == max )		h = 2 + ( b - r ) / delta;	// between cyan & yellow
		else					h = 4 + ( r - g ) / delta;	// between magenta & cyan

		h *= 60;				// degrees
		if( h < 0 )
			h += 360;
		h /= 360; // Clean later

		return h;
	}

  /** 
  * Helper Function that returns the saturation of the color.
  * @return          <code>float</code> between 0 and 1.
  */
	public float getS() {
	
		float min, max;
		
		min = Math.min( r, Math.min(g, b) );
		max = Math.max( r, Math.max(g, b) );
		
		if( max == 0 )	// r = g = b = 0		// s = 0, h is undefined
			return 0;
		else
			return (max - min) / max;
	}

  /** 
  * Helper Function that returns the value of the color,
  * how bright it is.
  * @return          <code>float</code> between 0 and 1.
  */
	public float getV() {
		return Math.max( r, Math.max(g, b) );
	}

}