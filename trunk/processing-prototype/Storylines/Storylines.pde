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
 *  Main "Storylines" Processing program.
 *
 *  You will need to have the JUNG library (http://jung.sourceforge.net)
 *  installed in your classpath.
 */

import processing.pdf.*;
import java.awt.geom.CubicCurve2D;
import java.awt.*;
import java.awt.geom.*;
import edu.uci.ics.jung.graph.*;
import edu.uci.ics.jung.algorithms.layout.*;
import edu.uci.ics.jung.algorithms.cluster.*;
import edu.uci.ics.jung.visualization.*;
import org.apache.commons.collections15.Transformer;

final String DEFAULT_CONFIG_FILE = "config/default.config";
final String CONFIG_FILE = "config/sample.config";

String REPOSITORY_FILE;
String OUTPUT_PREFIX;
String PROJECT_NAME;

// set manually
boolean WRITE_PDF;
boolean WRITE_SVG;
boolean COLOR_BY_FILE_TYPE = false;

Properties defaultProperties;
Properties properties;

// Defaults
int SCREEN_WIDTH;
int SCREEN_HEIGHT;
int TUBE_WIDTH;
int MIN_TUBE_SPACE;
int TUBE_PADDING;
int INNER_LABEL_SPACING = 200;
int COMMIT_HISTOGRAM_HEIGHT = 100;
int X_OFFSET = 20;
int TUBE_BUS_WIDTH;


final color BACKGROUND_COLOR = color( 255 );
final color TUBE_BACK_COLOR = color( 220 );
ColorAssigner colorAssigner;

final float [] dashes = { 5.0f, 5.0f };
boolean drawConnectors = true;
boolean drawNames = true;

ArrayList timesteps;
HashMap developerMap;
ArrayList developerList; // for picking

TubeBus prevTubeBus = null;
TubeBus prev2TubeBus = null;

Developer selectedDeveloper = null;
LinkedList selectedDevelopers;
int currentTimestepIndex;
int laneCounter = 0;
String longestName = null;
int timestepWidth;
int longestNameWidth;
int neededTimestepsForLabel;
int mostCommits = 0;

PFont font;
PFont titleFont;
PFont yearFont;
PFont boldFont;
int emdash;
BasicStroke dashedStroke;

PImage colorImage;
PImage grayscaleImage;
PGraphics pickImage;
boolean imagesDone = false;

/**
 *  Initialization method. Runs once.
 */
void setup()
{
  // Load Config Values
  loadProperties();

  if ( WRITE_PDF )
    size( SCREEN_WIDTH, SCREEN_HEIGHT, PDF, properties.getProperty("OutputPrefix") + ".pdf" );
  else
    size( SCREEN_WIDTH, SCREEN_HEIGHT );

  smooth();

  TUBE_BUS_WIDTH = height / TUBE_WIDTH;

  timesteps = new ArrayList();
  currentTimestepIndex = 0;
  developerMap = new HashMap();
  developerList = new ArrayList();
  //fileSet = new HashSet();
  selectedDevelopers = new LinkedList();

  //loadRepositoryXMLElement( DATA_DIR + REPOSITORY_FILE );
  loadRepositoryStrings( REPOSITORY_FILE );

  // Create Fonts
  font = createFont( "SansSerif", 12 );
  yearFont = createFont( "SansSerif", 16 );
  titleFont = createFont( "SansSerif", 32 );
  boldFont = createFont( "SansSerif.bold", 12 );
  dashedStroke = new BasicStroke( 1.0f, BasicStroke.CAP_SQUARE, BasicStroke.JOIN_MITER, 10.0f, dashes, 0.0f );

  textFont( font );
  longestNameWidth = ceil( textWidth( longestName ) );

  mostCommits = calculateMostCommits( timesteps );

  timestepWidth = width / timesteps.size();
  neededTimestepsForLabel = ceil( longestNameWidth / (float)timestepWidth ) + 1;

  pickImage = createGraphics( width, height, JAVA2D );
  pickImage.beginDraw();
  pickImage.noSmooth();
  pickImage.background( 0, 0 );

  background( BACKGROUND_COLOR );
}

/**
 *  Drawing method. Runs once.
 */
void draw()
{
  Graphics2D g2 = ((PGraphicsJava2D) g).g2;
  textFont( font );
  int tubeHeight = height / TUBE_BUS_WIDTH;

  if ( currentTimestepIndex < timesteps.size() )
  {
    Timestep timestep = (Timestep)timesteps.get( currentTimestepIndex );
    Timestep prevTimestep = null;
    if ( currentTimestepIndex > 0 )
      prevTimestep = (Timestep)timesteps.get( currentTimestepIndex - 1 );

    int x = currentTimestepIndex * (width - X_OFFSET) / timesteps.size() + X_OFFSET;
    timestep.x = x;
    int px = (currentTimestepIndex-1) * (width - X_OFFSET) / timesteps.size() + X_OFFSET;

    // draw date line and year
    pushStyle();
    strokeWeight( 1 );
    if ( timestep.beginCal.get( Calendar.MONTH ) == 1 )
    {
      stroke( 192 );
      noFill();
      line( x, 0, x, height );

      drawYear( timestep.beginCal.get( Calendar.YEAR ), x );
    }
    else
    {
      stroke( 230 );
      noFill();
      line( x, 0, x, height - 20 );
    }
    popStyle();

    // draw commit number histogram
    pushStyle();
    int numCommits = timestep.commits.size();
    int scaledCommits = (int)( numCommits * COMMIT_HISTOGRAM_HEIGHT / mostCommits );

    noStroke();
    float y = 0;
    for( int bin = 0; bin < timestep.fileBins.length; bin++ )
    {
      int binSize = timestep.fileBins[bin];
      float scaledBinSize = binSize * COMMIT_HISTOGRAM_HEIGHT / (float)mostCommits;

      color col = colorAssigner.getColor( bin );
      fill( colorAssigner.getColor(bin), 128 );
      rectMode( CORNERS );
      rect( x - 4, height - y - 30,
      x + 4, height - y - 30 - scaledBinSize );

      y += scaledBinSize;
    }

    // draw total commit number on top
    textFont( font );
    fill( 0, 128 );
    textAlign( CENTER, BOTTOM );
    if ( numCommits > 1000 )
      text( (numCommits / 1000) + "k", x, height - y - 30 );
    popStyle();

    // graph clustering
    Graph graph = createTimestepGraph( timestep );
    Collection clusters = doCluster( graph );

    // separate devs and files
    ArrayList [] devFileClusters = extractClusters( clusters );
    // devs in [0], files in [1]

    // tube layout
    TubeBus currentTubeBus = new TubeBus();
    if ( prevTubeBus == null )
    {
      currentTubeBus.insert( devFileClusters[0] );
    }
    else
    {
      currentTubeBus.insert( devFileClusters[0], prevTubeBus );
    }
    timestep.tubeBus = currentTubeBus;

    // draw
    pushStyle();
    colorMode( HSB );
    textAlign( LEFT, TOP );
    strokeCap( SQUARE );
    for( int i = 0; i < currentTubeBus.tubes.length; i++ )
    {
      Developer dev = currentTubeBus.tubes[i];
      int y2 = i * tubeHeight + tubeHeight/2;

      if ( dev != null )
      {
        color devColor = devColor( dev );

        if ( prevTubeBus != null )
        {
          int prevIndex = prevTubeBus.getIndexOf( dev );

          int dx = width / timesteps.size() / 2;
          if ( prevIndex != -1 )
          {
            int y1 = prevIndex * tubeHeight + tubeHeight/2;
            DrawableTubeLine drawableTube = new DrawableTubeLine( px, y1, x, y2, dx );
            dev.addTubeSegment( drawableTube );

            // FRONT
            drawableTube.drawFront( devColor );

            // BACK
            drawableTube.drawBack( dev.index | 0xFF000000, pickImage );
          }
          else // prevIndex == -1
          {
            // draw dashed connectors
            if ( drawConnectors && dev.lastPos != null )
            {
              //int lastX = dev.lastPos[0] * width / timesteps.size();
              int lastX = dev.lastPos[0] * (width - X_OFFSET) / timesteps.size() + X_OFFSET;
              int lastY = dev.lastPos[1] * tubeHeight + tubeHeight/2;
              int cdx = ( x - lastX ) / 2;

              DrawableTubeDashedLine dtdl = new DrawableTubeDashedLine( lastX, lastY, x, y2, cdx, g2 );
              dev.addTubeSegment( dtdl );
              dtdl.drawFront( devColor & 0x60FFFFFF );
            }

            // draw start circle
            DrawableTubeDot dtd = new DrawableTubeDot( x, y2 );
            dev.addTubeSegment( dtd );
            dtd.drawFront( devColor );
            dtd.drawBack( dev.index | 0xFF000000, pickImage );

            if ( drawNames && dev.lastLabel + INNER_LABEL_SPACING < x )
            {
              DrawableTubeDiagonalLabel dtdl = new DrawableTubeDiagonalLabel( x, y2, dev.username );
              dev.addTubeSegment( dtdl );
              dtdl.drawFront( devColor );
              dev.lastLabel = x;
            }
          }

          if ( drawNames && currentTimestepIndex > neededTimestepsForLabel && dev.lastLabel + INNER_LABEL_SPACING < x )
          {
            // attempt to draw inner-tube names
            int [] devIndices = new int[ neededTimestepsForLabel ];

            for( int k = 0; k < neededTimestepsForLabel; k++ )
            {
              Timestep prevK = (Timestep)timesteps.get( currentTimestepIndex - k );
              TubeBus tbK = prevK.tubeBus;
              devIndices[k] = tbK.getIndexOf( dev );
            }

            boolean enoughRoom = true;
            for( int k = 1; k < devIndices.length; k++ )
            {
              if ( devIndices[k] == -1 || devIndices[k] != devIndices[k-1] )
              {
                enoughRoom = false;
                break;
              }
            }

            if ( enoughRoom )
            {
              textFont( font );
              int nameWidth = (int)textWidth( dev.username );
              int labelStart = x - (longestNameWidth - nameWidth)/2;
              DrawableTubeHorizontalLabel dthl = new DrawableTubeHorizontalLabel( labelStart, y2, dev.username );
              dev.addTubeSegment( dthl );
              dthl.drawFront( devColor );
              dev.lastLabel = x;
            }
          }

          // set dev's last coords
          dev.lastPos = new int[]{ currentTimestepIndex, i };
        }
        else // prevTubeBus == null (i.e. first timestep)
        {
          // draw start circle
          DrawableTubeDot dtd = new DrawableTubeDot( x, y2 );
          dev.addTubeSegment( dtd );
          dtd.drawFront( devColor );
          dtd.drawBack( dev.index | 0xFF000000, pickImage );

          // draw diagonal label
          if ( drawNames && dev.lastLabel + INNER_LABEL_SPACING < x )
          {
            DrawableTubeDiagonalLabel dtdl = new DrawableTubeDiagonalLabel( x, y2, dev.username );
            dev.addTubeSegment( dtdl );
            dtdl.drawFront( devColor );
            dev.lastLabel = x;
          }
        }
      }
    }
    popStyle();

    // draw end circle
    pushStyle();
    noStroke();
    if ( prevTubeBus != null )
    {
      for( int i = 0; i < prevTubeBus.tubes.length; i++ )
      {
        Developer dev = (Developer)prevTubeBus.tubes[i];
        if ( dev != null )
        {
          int currentDevIndex = currentTubeBus.getIndexOf( dev );
          if ( currentDevIndex == -1 )
          {
            // FRONT
            int y2 = i * tubeHeight + tubeHeight/2;
            color devColor = devColor( dev );
            DrawableTubeDot dtd = new DrawableTubeDot( px, y2 );
            dev.addTubeSegment( dtd );
            dtd.drawFront( devColor );

            // BACK
            dtd.drawBack( dev.index | 0xFF000000, pickImage );
            
            if ( drawNames && dev.lastLabel + INNER_LABEL_SPACING < px )
            {
              DrawableTubeDiagonalLabel dtdl = new DrawableTubeDiagonalLabel( px, y2, dev.username );
              dev.addTubeSegment( dtdl );
              dtdl.drawFront( devColor );
              dev.lastLabel = px;
            }
          }
        }
      }
    }
    popStyle();

    currentTimestepIndex++;
    prevTubeBus = currentTubeBus;
  }
  else
  {
    if ( WRITE_SVG )
    {
      exportSVG( properties.getProperty("OutputPrefix") + ".svg" );
      exit();
    }
      
    if ( WRITE_PDF )
    {
      drawHistogramLegend();
      drawTitle();
      imagesDone = true;
      println( "Done." );
      exit();
    }

    if ( !imagesDone )
    {
      // finalize pickImage
      pickImage.endDraw();

      // load color
      colorImage = get();

      // load grayscale
      fill( 255, 96 );
      noStroke();
      rect( 0, 0, width, height );
      filter( GRAY );
      
      //image( grayscaleImage, 0, 0 );
      drawHistogramLegend();
      drawTitle();
      grayscaleImage = get();
      
      image( colorImage, 0, 0 );
      drawHistogramLegend();
      drawTitle();
      colorImage = get();
      
      imagesDone = true;
    }

    //println( millis() / 1000 + " sec" );
    noLoop();
  }
}

/**
 *  Write SVG file. (A very messy method.)
 */
void exportSVG( String filename )
{
  PrintWriter out = createWriter( filename );
  
  out.println( "<?xml version=\"1.0\" standalone=\"no\"?>" );
  out.println( "<svg width=\"" + width + "\" height=\"" + height + "\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\">" );
  
  // style
  out.println( "  <style>" );
  out.println( "    .YearAxis { stroke: #ccc; stroke-width:1; fill: none; }" );
  out.println( "    .YearLabel { fill: #666; font-family: sans-serif }" );
  out.println( "    .MonthAxis { stroke: #e6e6e6; stroke-width:1; fill:none }" );
  out.println( "    .TubeLineBack { fill:none; stroke-width: " + TUBE_WIDTH + "px; stroke-linecap: butt }" );
  out.println( "    .TubeLineFront { fill:none; stroke-width: " + (TUBE_WIDTH - TUBE_PADDING) + "px; stroke-linecap: round }" );
  out.println( "    .DashedLine { fill: none; stroke-width:1; stroke-dasharray: 5 5; stroke-linecap: round; stroke-opacity: .5; }" );
  out.println( "    .TubeDot { stroke: none; }" );
  out.println( "    .HorizontalLabel { font-family: arial,sans-serif; font-size: 10pt; text-anchor: end; stroke: none; }" );
  out.println( "    .DiagonalMaskInactive { fill: #fff; opacity: 0; stroke:none; visibility:hidden; }" );
  out.println( "    .DiagonalMaskActive { fill: #fff; opacity: .83; stroke:none; }" );
  out.println( "    .DiagonalLabel { font-family: arial,sans-serif; font-size: 10pt; text-anchor: end; alignment-baseline:middle; stroke: none; }" );
  out.println( "    .Title { fill: #000; font-family: sans-serif; font-size: 32pt; text-anchor: middle; alignment-baseline: hanging; }" );
  out.println( "    .Attribution { fill: #888; font-family: sans-serif; font-size: 10pt; text-anchor: end; alignment-baseline: hanging; }" );
  out.println( "    .HistogramBar { stroke: none; fill: " + hexColor(colorAssigner.defaultColor) + "; fill-opacity: 0.5; }" );
  out.println( "    .HistogramCount { font-family: sans-serif; font-size: 10pt; text-anchor: middle; fill: #000; fill-opacity: 0.5; }" );
  out.println( "    .HistogramLegendColor { fill-opacity: 0.5; stroke: #000; }" );
  out.println( "    .HistogramLegendText { font-family: sans-serif; font-size: 10pt; stroke: none; }" );
  for( int i = 0; i < colorAssigner.getNumBins(); i++ )
  {
    ColorTest ct = colorAssigner.getRule(i);
    String label = ct.label;
    out.println( "    .HistogramBar." + label + " { fill: " + hexColor(ct.c) + "; }" );
  }
  out.println( "  </style>\n" );
  
  // print scripts
  out.println( "  <script language=\"JavaScript\" type=\"text/javascript\">" );
  out.println( "    <![CDATA[" );
  
  // array of dev-color pairs
  out.println( "      var devNames = [" );
  for( Iterator itr = developerList.iterator(); itr.hasNext(); )
  {
    Developer dev = (Developer)itr.next();
    out.print( "      [\"" + dev.username + "\", \"" + hexColor( devColor(dev) ) + "\"]" );
    if ( itr.hasNext() )
      out.println( "," );
  }
  out.println( "      ];" );
  
  // on mouse over, set all colors to gray, then normally color selected
  out.println( "      function mouseOverTube(evt) {" );
  out.println( "        var elem = evt.target;" );
  out.println( "        var selectedName = elem.getAttribute(\"name\");" );
  out.println( "        var selectedColor;" );
  out.println( "        for( i = 0; i < devNames.length; i++ ) {" );
  out.println( "          if ( devNames[i][0] != selectedName ) {" );
  out.println( "            var devElems = elem.ownerDocument.getElementsByName( devNames[i][0] );" );
  out.println( "            for( j = 0; j < devElems.length; j++ ) {" );
  out.println( "              devElems[j].setAttribute( \"stroke\", \"gray\" );" );
  out.println( "              devElems[j].setAttribute( \"fill\", \"gray\" );" );
  out.println( "            }" );
  out.println( "          }" );
  out.println( "          else {" );
  out.println( "            selectedColor = devNames[i][1];" );
  out.println( "          }" );
  out.println( "        }" );
  out.println( "        var sameNames = elem.ownerDocument.getElementsByName( selectedName );" );
  out.println( "        for( i = 0; i < sameNames.length; i++ ) {" );
  out.println( "          sameNames[i].setAttribute( \"stroke\", selectedColor );" );
  out.println( "          sameNames[i].setAttribute( \"fill\", selectedColor );" );
  out.println( "          if ( sameNames[i].getAttribute(\"class\") == \"DiagonalMaskInactive\" )" );
  out.println( "            sameNames[i].setAttribute(\"class\", \"DiagonalMaskActive\" )" );
  out.println( "        }" );
  out.println( "      }" );
  
  // on mouse out, restore all colors to normal
  out.println( "      function mouseOutTube(evt) {" );
  out.println( "        for( i = 0; i < devNames.length; i++ ) {" );
  out.println( "          var devElems = evt.target.ownerDocument.getElementsByName( devNames[i][0] );" );
  out.println( "          for( j = 0; j < devElems.length; j++ ) {" );
  out.println( "            devElems[j].setAttribute( \"stroke\", devNames[i][1] );" );
  out.println( "            devElems[j].setAttribute( \"fill\", devNames[i][1] );" );
  out.println( "            if ( devElems[j].getAttribute(\"class\") == \"DiagonalMaskActive\" )" );
  out.println( "              devElems[j].setAttribute(\"class\", \"DiagonalMaskInactive\" )" );
  out.println( "          }" );
  out.println( "        }" );
  out.println( "      }" );
  out.println( "    ]]>" );
  out.println( "  </script>" );
  
  // background element
  out.println( "<rect width=\"100%\" height=\"100%\" fill=\"#FFF\" stroke=\"none\" onmouseover=\"mouseOutTube(evt)\" />" );
  
  // print grid
  for( int t = 0; t < timesteps.size(); t++ )
  {
    Timestep timestep = (Timestep)timesteps.get( t );
    int x = timestep.x;

    // draw date line and year
    if ( timestep.beginCal.get( Calendar.MONTH ) == 1 )
    {
      out.println( "  <line class=\"YearAxis\" x1=\"" + x + "\" y1=\"0\" x2=\"" + x + "\" y2=\"" + height + "\" />" );
      int yr = timestep.beginCal.get( Calendar.YEAR );
      out.println( "  <text class=\"YearLabel\" x=\"" + x + "\" y=\"" + height + "\" >" + yr + "</text>" );
    }
    else
    {
      out.println( "  <line class=\"MonthAxis\" x1=\"" + x + "\" y1=\"0\" x2=\"" + x + "\" y2=\"" + (height - 20) + "\" />" );
    }
    
    // draw commit number histogram
    int numCommits = timestep.commits.size();
    int scaledCommits = (int)( numCommits * COMMIT_HISTOGRAM_HEIGHT / mostCommits );

    float y = 0;
    for( int bin = 0; bin < timestep.fileBins.length; bin++ )
    {
      int binSize = timestep.fileBins[bin];
      float scaledBinSize = binSize * COMMIT_HISTOGRAM_HEIGHT / (float)mostCommits;

      color col = colorAssigner.getColor( bin );
      ColorTest ct = (ColorTest)colorAssigner.getRule(bin);
      String label = "";
      if ( ct != null )
        label = ct.label;
      out.println( "  <rect class=\"HistogramBar " + label + "\" x=\"" + (x - 4) + "\" y=\"" + int(height - y - 30 - scaledBinSize) + "\" width=\"" + 8 + "\" height=\"" + int(scaledBinSize) + "\" />" );
      
      y += scaledBinSize;
    }

    // draw total commit number on top
    if ( numCommits > 1000 )
      out.println( "  <text class=\"HistogramCount\" x=\"" + x + "\" y=\"" + (height - y - 30) + "\">" + (numCommits / 1000) + "k</text>" );
  }
  
  // BEGIN personal histograms
    // draw personal histograms
  for( Iterator ditr = developerList.iterator(); ditr.hasNext(); )
  {
    Developer dev = (Developer)ditr.next();
    for( Iterator itr = dev.timesteps.iterator(); itr.hasNext(); )
    {
      Timestep timestep = (Timestep)itr.next();
      int totalContribs = 0;
      int [] contribs = new int[ colorAssigner.getNumBins() + 1 ];
      for( int i = 0; i < timestep.commits.size(); i++ )
      {
        Commit commit = (Commit)timestep.commits.get(i);
        if ( commit.dev == dev )
        {
          int whichBin = colorAssigner.getBin( commit.file );
          if ( whichBin == -1 )
            contribs[ contribs.length-1 ]++;
          else
            contribs[ whichBin ]++;
          totalContribs++;
        }
      }
  
      //pushStyle();
      //strokeWeight( 1 );
      //rectMode( CORNERS );
  
      float y = 0;
      for( int j = 0; j < contribs.length; j++ )
      {
        float scaledContribSize = contribs[j] * COMMIT_HISTOGRAM_HEIGHT / (float)mostCommits;
        float startY = timestep.fileBins[j] * COMMIT_HISTOGRAM_HEIGHT / (float)mostCommits;
        fill( colorAssigner.getColor( j ), 160 );
        stroke( colorAssigner.getColor( j ) );
        //rect( timestep.x - 4, height - 30 - y - scaledContribSize, timestep.x + 4, height - 30 - y );
        if ( scaledContribSize >= 1 )
          out.println( "  <rect name=\"" + dev.username + "\" x=\"" + (timestep.x-4) + "\" y=\"" + int(height-30-y-scaledContribSize) + "\" width=\"8\" height=\"" + int(scaledContribSize) + "\" visibility=\"hidden\" />" );
        y += startY;
      }
      //popStyle();
    }
  }
  // END personal histograms
  
  // print elements
  for( Iterator itr = developerList.iterator(); itr.hasNext(); )
  {
    Developer dev = (Developer)itr.next();
    
    ArrayList tubeLines = null;
    for( Iterator itr2 = dev.tubeSegments.iterator(); itr2.hasNext(); )
    {
      DrawableTubeSegment drawable = (DrawableTubeSegment)itr2.next();
      if ( drawable instanceof DrawableTubeLine )
      {
        if ( tubeLines == null )
        {
          tubeLines = new ArrayList();
        }
        tubeLines.add( drawable );
      }
      else
      {
        if ( tubeLines != null )
        {
          String pathString = "M ";
          for( int i = 0; i < tubeLines.size(); i++ )
          {
            DrawableTubeLine tl = (DrawableTubeLine)tubeLines.get(i);
            if ( i == 0 )
              pathString += tl.x1 + " " + tl.y1;
            pathString += " C " + (tl.x1 + tl.dx) + " " + tl.y1 + " " + (tl.x2 - tl.dx) + " " + tl.y2 + " " + tl.x2 + " " + tl.y2;
          }
          out.println( "  <path class=\"TubeLineBack\" d=\"" + pathString + "\" color=\"" + hexColor( devColor(dev) ) + "\" stroke=\"" + hexColor(TUBE_BACK_COLOR) + "\" onmouseout=\"mouseOutTube(evt)\" />" );
          out.println( "  <path name=\"" + dev.username + "\" class=\"TubeLineFront\" d=\"" + pathString + "\" color=\"" + hexColor( devColor(dev) ) + "\" stroke=\"" + hexColor( devColor(dev) ) + "\" onmouseover=\"mouseOverTube(evt)\" />" );
        }
        drawable.printSVG( out, dev, devColor(dev) );
        tubeLines = null;
      }
    }
    if ( tubeLines != null )
    {
      String pathString = "M ";
      for( int i = 0; i < tubeLines.size(); i++ )
      {
        DrawableTubeLine tl = (DrawableTubeLine)tubeLines.get(i);
        if ( i == 0 )
          pathString += tl.x1 + " " + tl.y1;
        pathString += " C " + (tl.x1 + tl.dx) + " " + tl.y1 + " " + (tl.x2 - tl.dx) + " " + tl.y2 + " " + tl.x2 + " " + tl.y2;
      }
      out.println( "  <path class=\"TubeLineBack\" d=\"" + pathString + "\" color=\"" + hexColor( devColor(dev) ) + "\" stroke=\"" + hexColor(TUBE_BACK_COLOR) + "\" onmouseout=\"mouseOutTube(evt)\" />" );
      out.println( "  <path name=\"" + dev.username + "\" class=\"TubeLineFront\" d=\"" + pathString + "\" color=\"" + hexColor( devColor(dev) ) + "\" stroke=\"" + hexColor( devColor(dev) ) + "\" onmouseover=\"mouseOverTube(evt)\" />" );
    }
  }
  
  // draw histogram legend
  int x = 100;
  int y = 100;
  textFont( font );
  int w = (int)( textAscent() + textDescent() );
  for( int i = 0; i < colorAssigner.getNumBins(); i++ )
  {
    ColorTest test = (ColorTest)colorAssigner.getRule( i );
    out.println( "  <circle class=\"HistogramLegendColor\" cx=\"" + x + "\" cy=\"" + (height-y-w/2) + "\" r=\"" + (w/2) + "\" fill=\"" + hexColor(test.c) + "\" />" );
    out.println( "  <text class=\"HistogramLegendText\" x=\"" + (x+w/2+4) + "\" y=\"" + (height-y) + "\">" + test.label + "</text>" );
    y += textAscent() + textDescent();
  }
  out.println( "  <circle class=\"HistogramLegendColor\" cx=\"" + x + "\" cy=\"" + (height-y-w/2) + "\" r=\"" + (w/2) + "\" fill=\"" + hexColor(colorAssigner.defaultColor) + "\" />" );
  out.println( "  <text class=\"HistogramLegendText\" x=\"" + (x+w/2+4) + "\" y=\"" + (height-y) + "\">other</text>" );
  
  // draw title and attribution
  String title = PROJECT_NAME + " Storylines";
  String attribution = "Michael Ogawa. cc by-nc";
  out.println( "  <text class=\"Title\" x=\"50%\" y=\"5\" >" + title + "</text>" );
  out.println( "  <text class=\"Attribution\" x=\"" + (width-5) + "\" y=\"2\" >" + attribution + "</text>" );
  
  out.println( "</svg>" );
  
  out.flush();
  out.close();
}

/**
 *  For when one tube is selected.
 */
void drawSingleDevTubeSegments( Developer dev )
{
  color col = devColor( dev );
  for( Iterator itr = dev.tubeSegments.iterator(); itr.hasNext(); )
  {
    DrawableTubeSegment drawable = (DrawableTubeSegment)itr.next();
    drawable.drawSelected( col );
  }
}

/**
 *  For when multiple tubes are selected. (Probably broken and not currently used.)
 */
void drawMultipleDevTubeSegments()
{
  for( Iterator ditr = selectedDevelopers.iterator(); ditr.hasNext(); )
  {
    Developer dev = (Developer)ditr.next();
    drawSingleDevTubeSegments( dev );
  }
}

void drawSingleDevHistogram( Developer dev )
{
  // draw personal histograms
  for( Iterator itr = dev.timesteps.iterator(); itr.hasNext(); )
  {
    Timestep timestep = (Timestep)itr.next();
    int totalContribs = 0;
    int [] contribs = new int[ colorAssigner.getNumBins() + 1 ];
    for( int i = 0; i < timestep.commits.size(); i++ )
    {
      Commit commit = (Commit)timestep.commits.get(i);
      if ( commit.dev == dev )
      {
        int whichBin = colorAssigner.getBin( commit.file );
        if ( whichBin == -1 )
        {
          contribs[ contribs.length-1 ]++;
        }
        else
        {
          contribs[ whichBin ]++;
        }
        totalContribs++;
      }
    }

    pushStyle();
    strokeWeight( 1 );
    rectMode( CORNERS );

    //stroke( 0 );
    //float scaledContribSize;
    float y = 0;
    for( int j = 0; j < contribs.length; j++ )
    {
      float scaledContribSize = contribs[j] * COMMIT_HISTOGRAM_HEIGHT / (float)mostCommits;
      float startY = timestep.fileBins[j] * COMMIT_HISTOGRAM_HEIGHT / (float)mostCommits;
      fill( colorAssigner.getColor( j ), 160 );
      stroke( colorAssigner.getColor( j ) );
      rect( timestep.x - 4, height - 30 - y - scaledContribSize, timestep.x + 4, height - 30 - y );
      y += startY;
    }

    /*
    stroke( 0 );
     noFill();
     scaledContribSize = totalContribs * COMMIT_HISTOGRAM_HEIGHT / (float)mostCommits;
     rect( timestep.x - 4, height - 30 - scaledContribSize, timestep.x + 4, height - 30 );
     */
    popStyle();
  }
}

/**
 *  Assigns a deterministic color to a developer.
 */
color devColor( Developer dev )
{
  if ( COLOR_BY_FILE_TYPE )
  {
    return dev.getSumColor();
  }
  else
  {
    pushStyle();
    colorMode( HSB );
    int hashCode = dev.username.hashCode();

    float devHue = hue( hashCode );
    //float devSat = saturation( dev.username.hashCode() );
    //float devSat = saturation( 255, dev.timesteps.size() * 255 * 1.5 / timesteps.size() );
    //float devSat = hashCode % 50 + 206;
    float devSat = map( hashCode, Integer.MIN_VALUE, Integer.MAX_VALUE, 206, 255 );
    //float devBright = min( 230, brightness( hashCode ) );
    float devBright = map( hashCode, Integer.MIN_VALUE, Integer.MAX_VALUE, 128, 255 );
    //float devBright = 255;
    float devAlpha = min( 255, dev.timesteps.size() * 255 * 1.5 / timesteps.size() );
    color devColor = color( devHue, devSat, devBright );
    popStyle();

    return devColor;
  }
}

/**
 *  Draw one year yr at position x and the bottom of the screen.
 */
void drawYear( int yr, int x )
{
  pushStyle();
  textFont( yearFont );
  fill( 96 );
  textAlign( LEFT, BOTTOM );
  text( yr, x, height );
  popStyle();
}

void drawHistogramLegend()
{
  pushStyle();
  textAlign( LEFT, BOTTOM );
  textFont( font );
  strokeWeight( 1 );

  int x = 100;
  int y = 100;
  int w = (int)( textAscent() + textDescent() );
  for( int i = 0; i < colorAssigner.getNumBins(); i++ )
  {
    ColorTest test = (ColorTest)colorAssigner.getRule( i );
    fill( test.c, 128 );
    stroke( 0 );
    ellipse( x, height - y - w/2, w, w );
    
    fill( 0 );
    text( test.label, x + w/2 + 4, height - y );
    y += textAscent() + textDescent();
  }

  fill( colorAssigner.defaultColor, 128 );
  stroke( 0 );
  ellipse( x, height - y - w/2, w, w );
  fill( 0 );
  text( "other", x + w/2 + 4, height - y );

  popStyle();
}

void drawTitle()
{
  //int dashIndex = REPOSITORY_FILE.indexOf( '-' );
  String title = PROJECT_NAME + " Storylines";
  String attribution = "Michael Ogawa. cc by-nc";
  pushStyle();
  textFont( titleFont );
  textAlign( CENTER, TOP );
  fill( 0 );
  text( title, width/2, 10 );

  textFont( font );
  textAlign( RIGHT, TOP );
  fill( 128 );
  text( attribution, width - 5, 0 );
  popStyle();
}

void loadProperties()
{
  defaultProperties = new Properties();
  try {
    defaultProperties.load( createInput(DEFAULT_CONFIG_FILE) );
  } 
  catch( IOException ex ) {
    System.err.println( "Problem with default config file " + DEFAULT_CONFIG_FILE );
  }

  properties = new Properties( defaultProperties );
  try {
    properties.load( createInput(CONFIG_FILE) );
  } 
  catch ( IOException ex ) {
    ex.printStackTrace();
  }
  //properties.list( System.out );

  PROJECT_NAME = properties.getProperty( "ProjectName" );
  SCREEN_WIDTH = Integer.parseInt( properties.getProperty("ScreenWidth") );
  SCREEN_HEIGHT = Integer.parseInt( properties.getProperty("ScreenHeight") );
  WRITE_PDF = properties.getProperty( "WriteToPDF", "false" ).equalsIgnoreCase("true");
  WRITE_SVG = properties.getProperty( "WriteToSVG", "false" ).equalsIgnoreCase("true");
  REPOSITORY_FILE = properties.getProperty( "RepositoryFile" );
  OUTPUT_PREFIX = properties.getProperty( "OutputPrefix" );

  COMMIT_HISTOGRAM_HEIGHT = Integer.parseInt( properties.getProperty("CommitHistogramHeight") );

  TUBE_WIDTH = Integer.parseInt( properties.getProperty("TubeWidth") );
  MIN_TUBE_SPACE = Integer.parseInt( properties.getProperty("MinTubeSpace") );
  TUBE_PADDING = Integer.parseInt( properties.getProperty("TubePadding") );

  // do color assignment rules
  colorAssigner = new ColorAssigner();
  colorMode( RGB );
  for( int i = 1; i <= 10; i++ )
  {
    String value = properties.getProperty( "ColorAssign" + i );
    if ( value != null )
    {
      String [] tokens = value.split( "," );
      String label = "?", regex;
      int r,g,b;
      int j = 0;

      if ( tokens.length > 4 ) // long
        label = tokens[j++].trim().replaceAll( "\"", "" );
      regex = tokens[j++].trim();
      regex = regex.replaceAll( "\"", "" );
      //println( regex );
      r = Integer.parseInt( tokens[j++].trim() );
      g = int( tokens[j++].trim() );
      b = int( tokens[j++].trim() );
      colorAssigner.addRule( label, regex, color(r,g,b) );
      //println( r + " " + g + " " + b );
    }
  }
}

/**
 *  Use Processing's XMLElement to load DOM.
 */
void loadRepositoryXMLElement( String inputFile )
{  
  Timestep timestep = null;

  XMLElement xml = new XMLElement( this, inputFile );
  for( int i = 0; i < xml.getChildCount(); i++ )
  {
    XMLElement eventXML = xml.getChild(i);
    timestep = processRepEvent( eventXML, timestep );
  }

  xml = null; // garbage collect
}

/**
 *  Load file as strings, then process each line.
 */
void loadRepositoryStrings( String inputFile )
{
  Timestep timestep = null;

  String [] lines = loadStrings( inputFile );
  for( int i = 0; i < lines.length; i++ )
  {
    String line = lines[i].trim();

    if ( line.startsWith( "<event" ) )
    {
      XMLElement eventXML = new XMLElement( line );
      timestep = processRepEvent( eventXML, timestep );
    }
  }
  lines = null;
}

/**
 *  Given an XMLEvent, process it.
 */
Timestep processRepEvent( XMLElement eventXML, Timestep timestep )
{
  if ( eventXML != null && eventXML.getName() != null && eventXML.getName().equals( "event" ) )
  {
    String filename = eventXML.getStringAttribute( "filename" );
    String dateString = eventXML.getStringAttribute( "date" );
    long dateLong = Long.parseLong( dateString );
    Date date = new Date( dateLong );
    Calendar cal = new GregorianCalendar();
    cal.setTime( date );
    String authorString = eventXML.getStringAttribute( "author" );

    if ( longestName == null || authorString.length() > longestName.length() )
      longestName = authorString;

    while ( timestep == null || timestep.endCal.before( cal ) )
    {
      //timestep = new WeekTimestep( date );
      timestep = new MonthTimestep( date );
      //timestep = new YearTimestep( date );
      timesteps.add( timestep );
      //timestep.print();
    }

    // find developer
    Developer dev = (Developer)developerMap.get( authorString );
    if ( dev == null )
    {
      dev = new Developer( authorString );
      developerMap.put( authorString, dev );
      dev.index = developerList.size();
      developerList.add( dev );
    }
    dev.tryAddingTimestep( timestep );
    timestep.addDeveloper( dev );

    // create commit
    Commit commit = new Commit( dev, date, timestep, filename );
    //commit.file = filename;

    timestep.addCommit( commit );
  }

  return timestep;
}

Graph createTimestepGraph( Timestep timestep )
{
  //Graph g = new SparseMultigraph();
  Graph g = new UndirectedSparseMultigraph();
  Set vertexSet = new HashSet();
  Set edgeSet = new HashSet();
  int counter = 0;

  ArrayList commitList = timestep.commits;
  for( int i = 0; i < commitList.size(); i++ )
  {
    Commit commit = (Commit)commitList.get(i);
    g.addVertex( commit.dev );
    //println( "vertex: " + commit.dev.username );
    g.addVertex( commit.file );

    String edgeName = commit.dev.username + "-" + commit.file;
    //if ( edgeSet.contains( edgeName ) )
    {
      //edgeName = edgeName + counter++;
    }
    //edgeSet.add( edgeName );
    //println( edgeName );
    if ( !g.isNeighbor( commit.dev, commit.file ) )
      g.addEdge( edgeName, commit.dev, commit.file );
  }

  return g;
}

/**
 *  Use a JUNG clustering algorithm.
 */
Collection doCluster( Graph g )
{
  return ( new WeakComponentClusterer() ).transform( g );

  //int E = g.getEdgeCount();
  //return ( new EdgeBetweennessClusterer( E / 2 ) ).transform( g );

  //return ( new VoltageClusterer(g, 5) ).cluster( 5 );
  
  /*
  int numNodes = g.getVertexCount();
  int numEdgesToRemove = g.getEdgeCount() / 4;
  Set clusterSet = null;
  while ( clusterSet == null || largestCluster( clusterSet ) > numNodes / 2 )
  {
    EdgeBetweennessClusterer clusterer = new EdgeBetweennessClusterer( numEdgesToRemove );
    clusterSet = clusterer.transform( g );
    numEdgesToRemove += numNodes / 2;
  }
  return clusterSet;
  */
}

int largestCluster( Set clusterSet )
{
  int largestSize = -1;
  for( Iterator itr = clusterSet.iterator(); itr.hasNext(); )
  {
    Set cluster = (Set)itr.next();
    int clusterSize = cluster.size();
    if ( clusterSize > largestSize )
      largestSize = clusterSize;
  }
  println( largestSize );
  return largestSize;
}

/**
 *  Returns the clusters of devs and files.
 *  It ignores clusters without devs.
 */
ArrayList [] extractClusters( Collection clusters )
{
  ArrayList [] retClusters = new ArrayList[2];
  retClusters[0] = new ArrayList();
  retClusters[1] = new ArrayList();

  for( Iterator itr1 = clusters.iterator(); itr1.hasNext(); )
  {
    Set nodes = (Set)itr1.next();
    ArrayList devList = new ArrayList();
    ArrayList fileList = new ArrayList();
    for( Iterator itr2 = nodes.iterator(); itr2.hasNext(); )
    {
      Object obj = itr2.next();
      if ( obj.getClass().getName().equals( "Storylines$Developer" ) )
        devList.add( obj );
      else
        fileList.add( obj );
    }

    if ( !devList.isEmpty() )
    {
      retClusters[0].add( devList );
      retClusters[1].add( fileList );
    }
  }

  return retClusters;
}

/**
 *  Given a bunch of files, what is their commonality?
 */
String commonString( ArrayList fileList )
{
  String common = null;
  for( int i = 0; i < fileList.size(); i++ )
  {
    String file = (String)fileList.get(i);
    if ( common == null )
    {
      common = file;
    }
    else
    {
      int shortest = ( common.length() < file.length() ? common.length() : file.length() );
      int lastIndex = -1;
      for( int j = 0; j < shortest; j++ )
      {
        if ( common.charAt(j) != file.charAt(j) )
        {
          lastIndex = j;
          break;
        }
      }

      if ( lastIndex > 0 )
        common = common.substring( 0, lastIndex );
    }
  }
  return common;
}

/**
 *  Given a bunch of timesteps, find the largest number
 *  of commits within a single timestep.
 */
int calculateMostCommits( ArrayList ts )
{
  int counter = 0;
  for( Iterator itr = ts.iterator(); itr.hasNext(); )
  {
    Timestep t = (Timestep)itr.next();
    if ( t.commits.size() > counter )
      counter = t.commits.size();
  }
  return counter;
}

/**
 *  Utility method to convert an int color into a "rgb(R,G,B)" string.
 */
String rgbIt( color col )
{
  return "rgb(" + (col >> 16 & 0xFF) + "," + (col >> 8 & 0xFF) + "," + (col & 0xFF) + ")";
}

/**
 *  Utility method to convert an int color into a web-friendly "#RRGGBB" string.
 */
String hexColor( color col )
{
  return "#" + hex( col, 6 );
}

/**
 *  Re-initialize so redrawing can take place.
 */
void reset()
{
  imagesDone = false;
  currentTimestepIndex = 0;
  prevTubeBus = null;
  background( BACKGROUND_COLOR );
  for( Iterator itr = developerMap.values().iterator(); itr.hasNext(); )
  {
    Developer dev = (Developer)itr.next();
    dev.reset();
  }
  loop();
}

/**
 *  Keyboard interaction. (Not often used.)
 */
void keyPressed()
{
  switch( key )
  {
    case 's':
      String filename = properties.getProperty("OutputPrefix") + "-" + year() + "." + month() + "." + day() + "-" + hour() + "-" + minute() + "." + second() + ".png";
      save( filename );
      break;
    case 'c':
      //drawConnectors = !drawConnectors;
      COLOR_BY_FILE_TYPE = !COLOR_BY_FILE_TYPE;
      reset();
      break;
    case 'n':
      drawNames = !drawNames;
      reset();
      break;
  }
}

/**
 *  Highlight a developer line when mouse is hovered it.
 *  Go back to normal otherwise.
 */
void mouseMoved()
{
  if ( grayscaleImage != null )
  {
    int index = pickImage.get( mouseX, mouseY );
    if ( (index & 0xFF000000) != 0 )
    {
      Developer dev = (Developer)developerList.get( index & 0x00FFFFFF );
      if ( dev != selectedDeveloper )
      {
        image( grayscaleImage, 0, 0 );
        selectedDeveloper = dev;
        drawSingleDevTubeSegments( dev );
        drawSingleDevHistogram( dev );
        redraw();
      }
    }
    else
    {
      // no dev selected
      if ( selectedDeveloper != null )
      {
        image( colorImage, 0, 0 );
        selectedDeveloper = null;
        redraw();
      }
    }
  }
}

/**
 *  Display a graph visualization when right mouse button is pressed.
 *  For debugging and cluster sanity checks.
 */
void mousePressed()
{
  if ( mouseButton == LEFT )
  {
    
  }
  else if ( mouseButton == RIGHT )
  {
    pushStyle();
    textFont( font );
    //image( grayscaleImage, 0, 0 );
    // find timestep
    //int x = currentTimestepIndex * (width - X_OFFSET) / timesteps.size() + X_OFFSET;
    int timestepIndex = (mouseX - X_OFFSET) * timesteps.size() / (width - X_OFFSET);
    if ( timestepIndex >= 0 && timestepIndex < timesteps.size() )
    {
      Timestep timestep = (Timestep)timesteps.get(timestepIndex);
      Graph graph = createTimestepGraph( timestep );
      Collection clusters = doCluster( graph );

      FRLayout2 layout = new FRLayout2( graph );
      layout.setSize( new Dimension(760,760) );
      layout.setMaxIterations( 2000 );
      
      // separate devs and files
      ArrayList [] devFileClusters = extractClusters( clusters );
      ArrayList devClusters = devFileClusters[0];
      
      HashMap devColorMap = new HashMap();
      colorMode( HSB );
      for( int i = 0; i < devClusters.size(); i++ )
      {
        Collection cluster = (Collection)devClusters.get(i);
        Color c = new Color( color(i * 255 / devClusters.size(), 255, 255) | 0xFF000000 );
        for( Iterator itr = cluster.iterator(); itr.hasNext(); )
        {
          Developer dev = (Developer)itr.next();
          devColorMap.put( dev, c );
        }
      }
      
      BasicVisualizationServer vv = new BasicVisualizationServer( layout );
      vv.setPreferredSize( layout.getSize() );
      
      class VertexPaintTransformer implements Transformer
      {
        HashMap devColorMap;
        public VertexPaintTransformer( HashMap dcMap ) {
          super();
          devColorMap = dcMap;
        }
        
        public Paint transform(Object obj) {
          if ( obj.getClass().getName().equals( "Storylines$Developer" ) ) {
            Developer dev = (Developer)obj;
            return (Color)devColorMap.get(dev);
          }
          else {
            String filename = (String)obj;
            return new Color( colorAssigner.getColor( filename ) );
          }
        }
      };
      Transformer vertexPaint = new VertexPaintTransformer( devColorMap );
      
      Transformer vertexShape = new Transformer() {
        public Shape transform(Object obj) {
          if ( !obj.getClass().getName().equals( "Storylines$Developer" ) ) {
            return new java.awt.geom.Ellipse2D.Float( -2, -2, 4, 4 );
          }
          else {
            return new java.awt.geom.Ellipse2D.Float( -8, -8, 16, 16 );
          }
        }
      };
      
      Transformer vertexLabel = new Transformer() {
        public String transform( Object obj ) {
          if ( obj.getClass().getName().equals( "Storylines$Developer" ) )
            return ((Developer)obj).username;
          else
            return null;
        }
      };
      
      Transformer edgeDraw = new Transformer() {
        public Color transform( Object obj ) {
          return new Color( 0, 0, 0, 64 );
        }
      };
      
      vv.getRenderContext().setVertexFillPaintTransformer(vertexPaint);
      vv.getRenderContext().setVertexShapeTransformer( vertexShape );
      vv.getRenderContext().setVertexLabelTransformer( vertexLabel );
      vv.getRenderContext().setEdgeDrawPaintTransformer( edgeDraw );
      javax.swing.JFrame frame = new javax.swing.JFrame("Simple Graph View");
      frame.setDefaultCloseOperation(javax.swing.JFrame.DISPOSE_ON_CLOSE);
      frame.getContentPane().add(vv);
      frame.pack();
      frame.setVisible(true);
    }
    popStyle();
    redraw();
  }
}

