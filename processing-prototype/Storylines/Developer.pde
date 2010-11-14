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

class Developer implements Comparable
{
  String username;
  ArrayList timesteps;
  
  //boolean named = false;
  int [] lastPos;
  int lastLabel = Integer.MIN_VALUE;
  int index;
  ArrayList tubeSegments;
  
  private color sumColor = 0;
  
  public Developer( String username )
  {
    timesteps = new ArrayList();
    tubeSegments = new ArrayList();
    this.username = username;
    lastPos = null;
  }
  
  void tryAddingTimestep( Timestep t )
  {
    if ( timesteps.size() <= 0 )
    {
      timesteps.add( t );
      return;
    }
    
    Timestep tail = (Timestep)timesteps.get( timesteps.size()-1 );
    if ( t != tail )
      timesteps.add( t );
  }
  
  void addTubeSegment( DrawableTubeSegment dts )
  {
    tubeSegments.add( dts );
  }
  
  String toString()
  {
    return username;
  }
  
  /**
   *  Sort by veterancy.
   */
  int compareTo( Object o )
  {
    Developer d = (Developer)o;
    if ( this.lastPos != null && d.lastPos != null )
      return this.lastPos[1] - d.lastPos[1];
    else
      return d.timesteps.size() - this.timesteps.size();
  }
  
  void reset()
  {
    lastLabel = Integer.MIN_VALUE;
    lastPos = null;
  }
  
  color getSumColor()
  {
    if ( sumColor == 0 )
    {
      pushStyle();
      colorMode( RGB );
      long r = 0, g = 0, b = 0;
      int n = 0;
      
      for( Iterator titr = timesteps.iterator(); titr.hasNext(); )
      {
        Timestep timestep = (Timestep)titr.next();
        ArrayList commits = timestep.getCommitsByDeveloper( this );
        for( Iterator citr = commits.iterator(); citr.hasNext(); )
        {
          Commit commit = (Commit)citr.next();
          color c = colorAssigner.getColor( commit.file );
          r += red(c);
          g += green(c);
          b += blue(c);
          n++;
        }
      }
      
      if ( n > 0 )
      {
        sumColor = color( r / n, g / n, b / n );
      }
    }
    
    return sumColor;
  }
}
