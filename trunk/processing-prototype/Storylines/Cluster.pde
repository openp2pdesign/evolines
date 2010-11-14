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

class Cluster implements Comparable
{
  java.util.List nodes;
  int bestPlace;
  int place;
  
  ArrayList files;
  
  Cluster( java.util.List nodes, int bestPlace )
  {
    this.nodes = nodes;
    this.bestPlace = bestPlace;
    this.place = -1;
  }
  
  public void findBestPlaces( TubeBus prevTubeBus )
  {
    Collections.sort( nodes );
    Developer [] newPlaces = new Developer[ nodes.size() ];
    Arrays.fill( newPlaces, null );
    
    int numNewcomers = 0;
    int numVeterans = 0;
    for( int i = 0; i < nodes.size(); i++ )
    {
      Developer dev = (Developer)nodes.get(i);
      int prevIndex = prevTubeBus.getIndexOf( dev );
      if ( prevIndex == -1 )
        numNewcomers++;
      else
        numVeterans++;
    }
    
    // place veterans
    if ( numVeterans > 0 )
    {
      int bestTube = -1;
      int bestDistance = Integer.MAX_VALUE;
      for( int i = 0; i < numNewcomers + 1; i++ )
      {
        int startTube = i;
        int distanceAccum = 0;
        int counter = 0;
        for( int j = 0; j < nodes.size(); j++ )
        {
          Developer dev = (Developer)nodes.get(j);
          int prevIndex = prevTubeBus.getIndexOf( dev );
          if ( prevIndex != -1 )
          {
            int distance = abs( this.place + startTube + counter - prevIndex );
            distanceAccum += distance;
            counter++;
          }
        }
        
        if ( distanceAccum < bestDistance )
        {
          bestTube = startTube;
          bestDistance = distanceAccum;
        }
      }
      
      // place veterans at bestTube
      int counter = 0;
      for( int j = 0; j < nodes.size(); j++ )
      {
        Developer dev = (Developer)nodes.get(j);
        int prevIndex = prevTubeBus.getIndexOf( dev );
        if ( prevIndex != -1 )
        {
          newPlaces[ bestTube + counter ] = dev;
          counter++;
        }
      }
    }
      
      /*
      Developer dev = (Developer)nodes.get(i);
      int prevIndex = prevTubeBus.getIndexOf( dev );
      
      if ( prevIndex != -1 )
      {
        int bestTube = -1;
        int bestDistance = Integer.MAX_VALUE;
        for( int j = halfNewcomers; j < nodes.size() - halfNewcomers; j++ )
        {          
          if ( newPlaces[j] == null )
          {
            int tubePlace = this.place + j;
            int distance = abs( tubePlace - prevIndex );
            if ( distance < bestDistance )
            {
              bestDistance = distance;
              bestTube = j;
            }
          }
        }
        
        if ( bestTube != -1 )
          newPlaces[bestTube] = dev;
        else
          println( "Cluster.findBestPlaces():" );
      }
    }
    */
    
    // place newcomers
    for( int i = 0; i < nodes.size(); i++ )
    {
      Developer dev = (Developer)nodes.get(i);
      int prevIndex = prevTubeBus.getIndexOf( dev );
      
      if ( prevIndex == -1 )
      {
        for( int j = 0; j < newPlaces.length; j++ )
        {
          if ( newPlaces[j] == null )
          {
            newPlaces[j] = dev;
            break;
          }
        }
      }
    }
    
    nodes = new ArrayList();
    for( int i = 0; i < newPlaces.length; i++ )
    {
      Developer dev = newPlaces[i];
      if ( dev != null )
        nodes.add( dev );
    }
  }
  
  public int compareTo( Object o )
  {
    Cluster c = (Cluster)o;
    if ( c.bestPlace == -1 )
    {
      if ( this.bestPlace == -1 )
        return c.nodes.size() - this.nodes.size();
      else
        return -1;
    }
    
    if ( this.bestPlace == -1 )
    {
      if ( c.bestPlace == -1 )
        return c.nodes.size() - this.nodes.size();
      else
        return 1;
    }
    
    return c.nodes.size() - this.nodes.size();
  }
  
  void printCluster()
  {
    print( bestPlace + ":{" );
    for( int i = 0; i < nodes.size(); i++ )
    {
      Developer dev = (Developer)nodes.get(i);
      print( dev.username );
      if ( i < nodes.size()-1 )
        print( "," );
    }
    print( "}" );
  }
}
