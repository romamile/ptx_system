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
* This class represents an interval of hue over
* the chromatic wheel (between 0 and 360 in value).
* This interval is abritrary defined as
* the smaller interval between the two defined boundaries.
* This wayn there are no interval over 180 in value.
*
* @author  Roman Miletitch
* @version 0.7
*
**/



public class hueInterval {
	
	public int a, b; // change names
		
	public hueInterval()				{ a = 10; b = 20; }
	public hueInterval(int _a, int _b) { a = _a%360; b = _b%360; }

  /** 
  * Helper Function that returns the value of the A hue
  * @return          <code>int</code> between 0 and 359.
  */
	public int getA() { return a % 360; }

  /** 
  * Helper Function that returns the value of the B hue
  * @return          <code>int</code> between 0 and 359.
  */
	public int getB() { return b % 360; }

  /** 
  * Helper Function that returns the value of the max hue
  * @return          <code>int</code> between 0 and 359.
  */
	public int getMax() {return Math.max(a%360, b%360); }

  /** 
  * Helper Function that returns the value of the min hue
  * @return          <code>int</code> between 0 and 359.
  */
	public int getMin() {return Math.min(a%360, b%360); }

  /** 
  * Helper Function that returns the value of the centered hue
  * @return          <code>int</code> between 0 and 359.
  */
	public int getRef() {
		if( getMax() - getMin() < 180 ) {
			return ( (getMax() + getMin()) /2) % 360;
		} else {
			return ( (getMax() + getMin()) /2 + 180 ) % 360;
		}
	}

  /** 
  * Helper Function that returns all the possible hue values in the hue range.
  * @return          <code>ArrayList<Integer></code> of value between 0 and 359
  *                  corresponding to the emcompassing values of the range.
  */
	public ArrayList<Integer> getRange() {
		ArrayList<Integer> returnMe = new ArrayList<Integer>();

		if ( getMax() - getMin() < 180 ) { // Range is not over the edge
			for (int i = getMin(); i <= getMax(); i++)
				returnMe.add(i);
		} else {
			for (int i = getMax(); i <= 360; i++)
				returnMe.add(i);
			for (int i = 0; i <= getMin(); i++)
				returnMe.add(i);
		}

		return returnMe;
	}

  /** 
  * Function to know if a hue value is part of this range.
  * @param  _myHue   <code>int</code> value to test
  * @return          <code>true</code> if the hue is inside the range.
  */
	public boolean contains( int _myHue) {

		if ( getMax() - getMin() < 180 ) // Range is not over the edge
			return (_myHue >= getMin() && _myHue <= getMax());
		else
			return (_myHue >= getMax() && _myHue <= 360) || (_myHue >= 0 && _myHue <= getMin());
	}

}