/*
 *  Software Evolution Storylines - visualizes developer histories
 *  Copyright (C) 2010 Michael Ogawa
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 *  User-defined utility for assigning colors to file types.
 */
class ColorAssigner
{
  ArrayList tests;
  color defaultColor = color(128, 128, 128);
  
  public ColorAssigner()
  {
    tests = new ArrayList();
  }
  
  void addRule( String label, String expr, color c )
  {
    ColorTest t = new ColorTest();
    t.label = label;
    t.expr = expr;
    t.c = c;
    addRule( t );
  }
  
  void addRule( String expr, color c )
  {
    this.addRule( null, expr, c );
  }
  
  void addRule( ColorTest t )
  {
    tests.add( t );
  }
  
  ColorTest getRule( int i )
  {
    if ( i >= 0 && i < tests.size() )
      return (ColorTest)tests.get(i);
    return null;
  }
  
  color getColor( String s )
  {
    for( int i = 0; i < tests.size(); i++ )
    {
      ColorTest t = (ColorTest)tests.get(i);
      if ( t.passes( s ) )
        return t.assign();
    }
    
    return defaultColor;
  }
  
  color getColor( int bin )
  {
    if ( bin >= 0 && bin < tests.size() )
    {
      ColorTest t = (ColorTest)tests.get(bin);
      if ( t != null )
        return t.assign();
    }
      
    return defaultColor;
  }
  
  int getBin( String s )
  {
    for( int i = 0; i < tests.size(); i++ )
    {
      ColorTest t = (ColorTest)tests.get(i);
      if ( t.passes( s ) )
        return i;
    }
    return -1;
  }
  
  int getNumBins()
  {
    return tests.size();
  }
}

/**
 *  Defines a rule for assigning a color using regular expressions.
 */
class ColorTest
{
  String label;
  String expr;
  color c;
  
  boolean passes( String s )
  {
    return s.matches( expr );
  }
  
  color assign()
  {
    return c;
  }
}

