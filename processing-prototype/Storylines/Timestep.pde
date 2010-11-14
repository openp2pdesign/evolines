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
 *  Represents one timestep of arbitrary length.
 */
abstract class Timestep
{
  Calendar beginCal;
  Calendar endCal;
  
  ArrayList commits;
  Set developers;
  
  TubeBus tubeBus;
  
  int [] fileBins;
  int x;
  
  public Timestep()
  {
    commits = new ArrayList();
    developers = new HashSet();
    fileBins = new int[ colorAssigner.getNumBins() + 1 ];
  }
  
  void addCommit( Commit c )
  {
    commits.add( c );
    int bin = colorAssigner.getBin( c.file );
    if ( bin >= 0 )
      fileBins[bin]++;
    else
      fileBins[ fileBins.length - 1 ]++;
  }
  
  void addDeveloper( Developer d )
  {
    developers.add( d );
  }
  
  ArrayList getCommitsByDeveloper( Developer dev )
  {
    ArrayList devCommits = new ArrayList();
    for( Iterator itr = commits.iterator(); itr.hasNext(); )
    {
      Commit com = (Commit)itr.next();
      if ( com.dev == dev )
      {
        devCommits.add( com );
      }
    }
    return devCommits;
  }
  
  void print()
  {
    DateFormat df = DateFormat.getInstance();
    println( df.format(beginCal.getTime()) + " - " + df.format(endCal.getTime()) );
  }
}

/**
 *  One month timestep.
 *  From midnight on the first day of the month to (midnight - 1 msec) on the last day.
 */
class MonthTimestep extends Timestep
{
  MonthTimestep( Date date )
  {
    super();
    initSpans( date );
  }
  
  void initSpans( Date date )
  {
    Calendar cal = new GregorianCalendar();
    cal.setTime( date );
    cal.set( Calendar.DAY_OF_MONTH, 1 );
    cal.set( Calendar.HOUR_OF_DAY, 0 );
    cal.set( Calendar.MINUTE, 0 );
    cal.set( Calendar.SECOND, 0 );
    cal.set( Calendar.MILLISECOND, 0 );
    
    beginCal = (Calendar)cal.clone();
    
    cal.add( Calendar.MONTH, 1 );
    cal.add( Calendar.MILLISECOND, -1 );
    endCal = cal;
  }
}

/**
 *  One week timestep.
 *  From midnight on Sunday to (midnight - 1 msec) on Saturday.
 */
class WeekTimestep extends Timestep
{
  WeekTimestep( Date date )
  {
    super();
    initSpans( date );
  }
  
  void initSpans( Date date )
  {
    Calendar cal = new GregorianCalendar();
    cal.setTime( date );
    cal.set( Calendar.DAY_OF_WEEK, Calendar.SUNDAY );
    cal.set( Calendar.HOUR_OF_DAY, 0 );
    cal.set( Calendar.MINUTE, 0 );
    cal.set( Calendar.SECOND, 0 );
    cal.set( Calendar.MILLISECOND, 0 );
    
    beginCal = (Calendar)cal.clone();
    
    cal.add( Calendar.WEEK_OF_YEAR, 1 );
    cal.add( Calendar.MILLISECOND, -1 );
    endCal = cal;
  }
}

/**
 *  One year timestep.
 *  From midnight on January 1 to (midnight - 1 msec) on December 31.
 */
class YearTimestep extends Timestep
{
  YearTimestep( Date date )
  {
    super();
    initSpans( date );
  }
  
  void initSpans( Date date )
  {
    Calendar cal = new GregorianCalendar();
    cal.setTime( date );
    cal.set( Calendar.DAY_OF_MONTH, 1 );
    cal.set( Calendar.HOUR_OF_DAY, 0 );
    cal.set( Calendar.MINUTE, 0 );
    cal.set( Calendar.SECOND, 0 );
    cal.set( Calendar.MILLISECOND, 0 );
    
    beginCal = (Calendar)cal.clone();
    
    cal.add( Calendar.YEAR, -1 );
    cal.add( Calendar.MILLISECOND, -1 );
    endCal = cal;
  }
}

