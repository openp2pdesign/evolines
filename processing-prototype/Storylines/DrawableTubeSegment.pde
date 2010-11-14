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

abstract class DrawableTubeSegment
{
  abstract void drawFront( color col );
  
  void drawSelected( color col )
  {
    drawFront( col );
  }
  
  abstract void printSVG( PrintWriter out, Developer dev, color col );
}

class DrawableTubeDot extends DrawableTubeSegment
{
  int x, y;

  DrawableTubeDot( int x, int y )
  {
    this.x = x;
    this.y = y;
  }

  void drawFront( color col )
  {
    pushStyle();
    fill( col );
    noStroke();
    ellipse( x, y, TUBE_WIDTH - 1, TUBE_WIDTH - 1 );
    popStyle();
  }

  void drawBack( color col, PGraphics pg )
  {
    pg.pushStyle();
    pg.noStroke();
    pg.fill( col );
    pg.ellipse( x, y, TUBE_WIDTH - 1, TUBE_WIDTH - 1 );
    pg.popStyle();
  }
  
  void printSVG( PrintWriter out, Developer dev, color col )
  {
    out.println( "  <circle name=\"" + dev.username + "\" class=\"TubeDot\" cx=\"" + x + "\" cy=\"" + y + "\" r=\"" + (TUBE_WIDTH-1)/2 + "\" color=\"" + hexColor(col) + "\" fill=\"" + hexColor(col) + "\" onmouseover=\"mouseOverTube(evt)\" />" );
  }
}

class DrawableTubeLine extends DrawableTubeSegment
{
  int x1, x2, y1, y2;
  int dx;

  DrawableTubeLine( int x1, int y1, int x2, int y2, int dx )
  {
    this.x1 = x1;
    this.x2 = x2;
    this.y1 = y1;
    this.y2 = y2;
    this.dx = dx;
  }

  void drawFront( color col )
  {
    pushStyle();
    noFill();
    strokeWeight( TUBE_WIDTH );
    strokeCap( SQUARE );
    stroke( TUBE_BACK_COLOR );
    bezier( x1, y1, x1 + dx, y1, x2 - dx, y2, x2, y2 );

    strokeWeight( TUBE_WIDTH - TUBE_PADDING );
    stroke( col, 255 );
    strokeCap( ROUND );
    bezier( x1, y1, x1 + dx, y1, x2 - dx, y2, x2, y2 );
    popStyle();
  }

  void drawBack( color col, PGraphics pg )
  {
    pg.pushStyle();
    pg.strokeWeight( TUBE_WIDTH );
    pg.stroke( col );
    pg.bezier( x1, y1, x1 + dx, y1, x2 - dx, y2, x2, y2 );
    pg.popStyle();
  }
  
  void printSVG( PrintWriter out, Developer dev, color col )
  {
    String pathString = "M " + x1 + " " + y1 + " C " + (x1 + dx) + " " + y1 + " " + (x2 - dx) + " " + y2 + " " + x2 + " " + y2;
    out.println( "  <path class=\"TubeLineBack\" d=\"" + pathString + "\" stroke=\"" + rgbIt(TUBE_BACK_COLOR) + "\" />" );
    out.println( "  <path name=\"" + dev.username + "\" class=\"TubeLineFront\" d=\"" + pathString + "\" color=\"" + rgbIt(col) + "\" stroke=\"" + rgbIt(col) + "\" onmouseover=\"mouseOverTube(evt)\" />" );
  }
}

class DrawableTubeDashedLine extends DrawableTubeSegment
{
  CubicCurve2D curve;

  DrawableTubeDashedLine( int x1, int y1, int x2, int y2, int dx, Graphics2D g2 )
  {
    curve = new CubicCurve2D.Float();
    curve.setCurve( x1, y1, x1 + dx, y1, x2 - dx, y2, x2, y2 );
  }

  void drawFront( color col )
  {
    Graphics2D g2 = ((PGraphicsJava2D) g).g2;
    pushStyle();
    g2.setStroke( dashedStroke );
    g2.setColor( new Color( col, true ) );
    g2.draw( curve );
    popStyle();
  }
  
  void printSVG( PrintWriter out, Developer dev, color col )
  {
    Point2D p1 = curve.getP1();
    Point2D p2 = curve.getP2();
    Point2D cp1 = curve.getCtrlP1();
    Point2D cp2 = curve.getCtrlP2();
    String pathString = "M " + (int)p1.getX() + " " + (int)p1.getY() + 
                        " C " + (int)cp1.getX() + " " + (int)cp1.getY() + 
                        " " + (int)cp2.getX() + " " + (int)cp2.getY() + 
                        " " + (int)p2.getX() + " " + (int)p2.getY();
    
    out.println( "  <path name=\"" + dev.username + "\" class=\"DashedLine\" d=\"" + pathString + "\" stroke=\"" + rgbIt(col) + "\" />" );
  }
}

class DrawableTubeDiagonalLabel extends DrawableTubeSegment
{
  int x, y;
  String label;

  DrawableTubeDiagonalLabel( int x, int y, String label )
  {
    this.x = x;
    this.y = y;
    this.label = label;
  }

  void drawFront( color col )
  {
    pushStyle();
    pushMatrix();
    textAlign( RIGHT, CENTER );
    translate( x - TUBE_WIDTH/2 - 2, y + TUBE_WIDTH/2 - 2 );
    rotate( -HALF_PI/2 );
    fill( col );
    text( label, 0, 0);
    popMatrix();
    popStyle();
  }
  
  void drawSelected( color col )
  {
    pushStyle();
    pushMatrix();
    textFont( font );
    textAlign( RIGHT, CENTER );
    translate( x - TUBE_WIDTH/2 - 2, y + TUBE_WIDTH/2 - 2 );
    rotate( -HALF_PI/2 );
    
    // back rectangle
    noStroke();
    fill( 255, 212 );
    rect( -textWidth( label ), -textDescent(), textWidth( label ) + 2, textAscent() );
    
    // label text
    fill( col );
    text( label, 0, 0);
    
    popMatrix();
    popStyle();
  }
  
  void printSVG( PrintWriter out, Developer dev, color col )
  {
    textFont( font );
    out.println( "  <g transform=\"translate( " + (x - TUBE_WIDTH/2 - 2) + "," +  (y + TUBE_WIDTH/2 - 2) + "),rotate( " + -45 + ")\">" );
    out.println( "    <rect name=\"" + dev.username + "\" class=\"DiagonalMaskInactive\" x=\"" + (-textWidth( label )) + "\" y=\"" + (-textDescent()) + "\" width=\"" + (textWidth( label ) + 2) + "\" height=\"" + textAscent() + "\" />" );
    out.println( "    <text name=\"" + dev.username + "\" class=\"DiagonalLabel\" x=\"1\" y=\"3\" fill=\"" + hexColor(col) + "\" onmouseover=\"mouseOverTube(evt)\" >" + label + "</text>" );
    out.println( "  </g>" );
  }
}

class DrawableTubeHorizontalLabel extends DrawableTubeSegment
{
  int x, y;
  String label;

  DrawableTubeHorizontalLabel( int x, int y, String label )
  {
    this.x = x;
    this.y = y;
    this.label = label;
  }

  void drawFront( color col )
  {
    pushStyle();
    textFont( font );
    int nameWidth = (int)textWidth( label );

    // draw white space
    stroke( TUBE_BACK_COLOR );
    strokeWeight( TUBE_WIDTH );
    strokeCap( ROUND );
    line( x - nameWidth, y, x, y );

    // draw text
    noStroke();
    fill( col );
    textAlign( RIGHT, CENTER );
    text( label, x, y - textDescent() );
    popStyle();
  }
  
  void printSVG( PrintWriter out, Developer dev, color col )
  {
    textFont( font );
    int nameWidth = (int)textWidth( label );
    out.println( "  <line x1=\"" + (x - nameWidth - 1) + "\" y1=\"" + y + "\" x2=\"" + x + "\" y2=\"" + y + "\" stroke=\"" + rgbIt(TUBE_BACK_COLOR) + "\" stroke-width=\"" + TUBE_WIDTH + "\" fill=\"none\" />" );
    out.println( "  <text name=\"" + label + "\" class=\"HorizontalLabel\" x=\"" + x + "\" y=\"" + (y + TUBE_WIDTH/2) + "\" color=\"" + hexColor(col) + "\" fill=\"" + hexColor(col) + "\" onmouseover=\"mouseOverTube(evt)\" >" + label + "</text>"  );
  }
}
