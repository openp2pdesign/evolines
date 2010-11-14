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

class TubeBus
{
  Developer [] tubes;
  ArrayList files; // filename Strings
  
  public TubeBus()
  {
    tubes = new Developer[ TUBE_BUS_WIDTH ];
    Arrays.fill( tubes, null );
  }
  
  public int getIndexOf( Developer dev )
  {
    for( int i = 0; i < tubes.length; i++ )
      if ( tubes[i] == dev )
        return i;
        
    return -1;
  }
  
  int countNonzero()
  {
    int count = 0;
    for( int i = 0; i < tubes.length; i++ )
    {
      if ( tubes[i] != null )
        count++;
    }
    return count;
  }
  
  /**
   *  Initial case layout.
   */
  void insert( java.util.List clusters )
  {
    // urinal protocol (seriously)
    int numOccupiedTubes = 0;
    for( int i = 0; i < clusters.size(); i++ )
    {
      java.util.List nodes = (java.util.List)clusters.get(i);
      numOccupiedTubes += nodes.size();
    }
    
    int numEmptyTubes = tubes.length - numOccupiedTubes;
    int spaceBetweenClusters = min( MIN_TUBE_SPACE, numEmptyTubes / max( 1, clusters.size() - 1 ) );
    
    int middleTubes = numOccupiedTubes + ( numOccupiedTubes - 1 ) * spaceBetweenClusters;
    int outerTubes = numEmptyTubes - middleTubes;
    
    int y = outerTubes / 2;
    for( int i = 0; i < clusters.size(); i++ )
    {
      java.util.List nodes = (java.util.List)clusters.get(i);
      for( int j = 0; j < nodes.size(); j++ )
      {
        tubes[y] = (Developer)nodes.get(j);
        y++;
      }
      y += spaceBetweenClusters;
    }
  }
  
  /**
   *  General case layout.
   */
  void insert( java.util.List clusters, TubeBus prevTubeBus )
  {
    ArrayList clusterList = new ArrayList();
    for( int i = 0; i < clusters.size(); i++ )
    {
      java.util.List nodes = (java.util.List)clusters.get(i);
      int bestPlace = findBestPlaceFor( nodes, prevTubeBus );
      clusterList.add( new Cluster( nodes, bestPlace ) );
    }
    
    // space out the clusters
    /*
    int numOccupiedTubes = 0;
    for( int i = 0; i < clusters.size(); i++ )
    {
      java.util.List nodes = (java.util.List)clusters.get(i);
      numOccupiedTubes += nodes.size();
    }
    int numEmptyTubes = tubes.length - numOccupiedTubes;
    int spaceBetweenClusters = min( MIN_TUBE_SPACE, numEmptyTubes / max( 1, clusters.size() - 1 ) );
    */
    
    Collections.sort( clusterList );
    for( int i = 0; i < clusterList.size(); i++ )
    {
      Cluster clust = (Cluster)clusterList.get(i);
      
      clust.place = fitBestPlace( clust );
      //println( clust.bestPlace );
      if ( clust.place == -1 )
        println( "error: no best place" );
        
      clust.findBestPlaces( prevTubeBus );
      for( int j = 0; j < clust.nodes.size(); j++ )
      {
        Developer dev = (Developer)clust.nodes.get(j);
        if ( clust.place + j >= 0 && clust.place + j < tubes.length )
        tubes[ clust.place + j ] = dev;
      }
    }
  }
  
  /**
   *  This is OK now.
   */
  private int findBestPlaceFor( java.util.List nodes, TubeBus prevTubeBus )
  {
    int numCommon = 0;
    for( int i = 0; i < nodes.size(); i++ )
    {
      Developer node = (Developer)nodes.get(i);
      if ( prevTubeBus.getIndexOf( node ) != -1 )
        numCommon++;
    }
    
    if ( numCommon <= 0 )
      return -1;
    
    // for each possible tube position
    int tubeAccum = 0;
    int tubeCount = 0;
    for( int i = 0; i < nodes.size(); i++ )
    {
      Developer node = (Developer)nodes.get(i);
      int prevNodeTube = prevTubeBus.getIndexOf( node );
      if ( prevNodeTube != -1 )
      {
        int weight = node.timesteps.size();
        tubeAccum += prevNodeTube * weight;
        tubeCount += weight;
      }
    }
    int bestTube = tubeAccum / tubeCount;

    return bestTube;
  }
  
  /**
   *  Given a cluster, find the best place to put it.
   */
  private int fitBestPlace( Cluster clust )
  {
    if ( clust.bestPlace == -1 )
    {
      // find first open tube group
      int stride = clust.nodes.size() + MIN_TUBE_SPACE * 2;
      int halfStride = stride/2 - (1 - stride % 2);
      
      for( int i = 1; i < this.tubes.length - stride; i++ )
      {
        int offset = i / 2;
        int startTube = tubes.length / 2 - halfStride;
        
        if ( i % 2 == 0 ) // even
          startTube += offset;
        else // odd
          startTube -= offset;
        
        if ( startTube < 0 || startTube >= tubes.length - stride )
          continue;
        
        boolean empty = true;
        for( int j = startTube; j < startTube + stride; j++ )
        {
          if ( j >= this.tubes.length || j < 0 )
            break;
          
          if ( tubes[j] != null )
          {
            empty = false;
            break;
          }
        }
        
        if ( empty )
        {
          return startTube + MIN_TUBE_SPACE;
        }
      }
    }
    else
    {
      int stride = clust.nodes.size() + ( MIN_TUBE_SPACE * 2 );
      int halfStride = stride/2 - (1 - stride % 2);
      
      for( int i = 1; i < this.tubes.length * 2; i++ )
      {
        int offset = i / 2;
        int startTube = clust.bestPlace - halfStride;
        
        if ( i % 2 == 0 ) // even
          startTube += offset;
        else // odd
          startTube -= offset;
        
        if ( startTube < 0 || startTube >= tubes.length - stride )
          continue;
        
        boolean empty = true;
        for( int j = startTube; j < startTube + stride; j++ )
        {
          if ( j >= this.tubes.length || j < 0 )
            break;
          
          if ( tubes[j] != null )
          {
            empty = false;
            break;
          }
        }
        
        if ( empty == true )
        {
          return startTube + MIN_TUBE_SPACE;
        }
      }
    }
    
    println( "fitBestPlace(): " + clust.bestPlace );
    return -1;
  }
  
  /**
   *  UNFINISHED
   */
  private int [] findLargestOpenRange()
  {
    if ( countNonzero() >= tubes.length )
      return null;
    
    int [] bestCandidate = new int[2];
    for( int i = 0; i < tubes.length; i++ )
    {
      
    }
    
    return bestCandidate;
  }
  
  void printNodes( java.util.List nodes )
  {
    print( "{" );
    for( int i = 0; i < nodes.size(); i++ )
    {
      Developer node = (Developer)nodes.get(i);
      print( node.username );
      if ( i < nodes.size() - 1 )
        print( "," );
    }
    print( "}" );
  }
}

