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
 *  Data type for storing a commit record.
 */
class Commit
{
  Developer dev;
  Date date;
  Timestep timestep;
  String file;
  
  public Commit()
  {
    
  }
  
  public Commit( Developer dev, Date date, Timestep timestep, String filename )
  {
    this();
    this.dev = dev;
    this.date = date;
    this.timestep = timestep;
    this.file = filename;
  }
}

