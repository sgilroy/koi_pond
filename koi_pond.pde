/*
KOY FISH POND
original code by Ricardo Sanchez (June 2009), 
modified by Xiao Xiao and Michael Bernstein (2010)
 */
 
import processing.serial.*;
import processing.opengl.PGraphicsOpenGL;

// we need to import the TUIO library
// and declare a TuioProcessing client variable
import TUIO.*;
TuioProcessing tuioClient;

int val;
int NUM_BOIDS = 50;
//float BOID_DENSITY = 1 / 12960; // equivalent to 50 boids on a 1080x600 screen
float BOID_DENSITY = 1.0 / 15681; // equivalent to 50 boids on a 1080x600 screen
int lastBirthTimecheck = 0;                // birth time interval
int addKoiCounter = 0;

ArrayList wanderers = new ArrayList();     // stores wander behavior objects
PVector mouseAvoidTarget;                  // use mouse location as object to evade
boolean press = false;                     // check is mouse is press
int minScope = 20;
int maxScope = 300;

int minSkinIndex = 0;
int maxSkinIndex = 10;
String[] skin = new String[maxSkinIndex + 1];

PImage canvas;
Ripple ripples;
boolean isRipplesActive = false;

PImage rocks;
PImage innerShadow;
PImage ripple;

//boolean detectedBall =false;

BallPositionSensor sensor;
PVector ballPosition;
PVector hitPixels = new PVector(0,0);

float pressTime = 0;
int pressInterval = 2000;

String winSerial = "COM7";
String macSerial = "/dev/tty.usbserial-A9005d9p";

float screenMultiplier = 1.1;
boolean showBoidTargetingLines = false;
boolean showTuioCursors = true;

void setup() {
  //size(640,480, OPENGL);
  //size(int(2 * 10 * 54 * screenMultiplier), int(10 * 60 * screenMultiplier), OPENGL);
  //size(screen.width, screen.height, OPENGL);
  //size(int(screen.width * 0.8), int(screen.height * 0.8), OPENGL);
  // note that we undersize by 2 pixels because there is currently some issue with ScalableDispaly which results in flickering
  size(screen.width - 2, screen.height - 2, OPENGL);

  smooth();
  background(0);
  //frameRate(30);  
  
  NUM_BOIDS = round(width * height * BOID_DENSITY);
  println("Using " + NUM_BOIDS + " fish");
  
  sensor = new BallPositionSensor(this, macSerial, "coefficients-left.txt", "coefficients-right.txt");
 
  //rocks = loadImage("rocks.jpg");
  //innerShadow = loadImage("pond.png");
  
  // init skin array images
  for (int n = 0; n < maxSkinIndex + 1; n++) skin[n] = "skin-" + n + ".png";

  // this is the ripples code
  canvas = createImage(width, height, RGB);
  ripples = new Ripple(canvas);
  ripple = loadImage("ripple.png");
  
  // we create an instance of the TuioProcessing client
  // since we add "this" class as an argument the TuioProcessing class expects
  // an implementation of the TUIO callback methods (see below)
  tuioClient  = new TuioProcessing(this);
}


void draw() {
  background(0);
  
  // adds new koi on a interval of time
  if (millis() > lastBirthTimecheck + 200) {
    lastBirthTimecheck = millis();
    if (addKoiCounter <  NUM_BOIDS) addKoi();
  }

  Vector tuioCursorList = tuioClient.getTuioCursors();

  Hit ballLocation = sensor.readHit();
  if (ballLocation != null) {
    hitPixels = ballLocation.getPixelVector();
    println("blah");
    println("Pixels: (" + hitPixels.x + ", " + hitPixels.y + ")");
    println("uploading turned off");

    press = true;
    pressTime = millis();
  }
  
  for (int n = 0; n < wanderers.size(); n++) {
    Boid wanderBoid = (Boid)wanderers.get(n);
    float closestBoidDist = -1;
    PVector closestTargetPosition = null;
    boolean shouldEvade = false;

    // touch/bodies (TUIO)
    for (int i=0;i<tuioCursorList.size();i++) {
      TuioCursor tcur = (TuioCursor)tuioCursorList.elementAt(i);

      // for each tuio cursor, pick objects inside the mouseAvoidScope
      // and convert them in pursuers
      PVector cursorPosition = new PVector(tcur.getScreenX(width), tcur.getScreenY(height));
      
      float boidDist = dist(cursorPosition.x, cursorPosition.y, wanderBoid.location.x, wanderBoid.location.y);
      if (closestTargetPosition == null || boidDist < closestBoidDist)
      {
        closestBoidDist = boidDist;
        closestTargetPosition = cursorPosition;
        shouldEvade = determineTuioCursorShouldEvade(tcur);
      }
    }
    
    // mouse/ball
    if (press) {
      float boidDist = dist(hitPixels.x, hitPixels.y, wanderBoid.location.x, wanderBoid.location.y);
      if (closestTargetPosition == null || boidDist < closestBoidDist)
      {
        closestBoidDist = boidDist;
        closestTargetPosition = hitPixels;
      }
    }

    if ((closestTargetPosition != null) && (closestBoidDist > minScope) && (closestBoidDist < maxScope)) {
      //println("Boid " + n + " pursuing " + closestTargetPosition.x + ", " + closestTargetPosition.y + " at distance of " + closestBoidDist); 
      wanderBoid.timeCount = 0;
      
      if (shouldEvade)
        wanderBoid.evade(closestTargetPosition);
      else
        wanderBoid.pursue(closestTargetPosition);
        
      if (showBoidTargetingLines) {
        // red for evade
        if (shouldEvade)
          stroke(255, 90, 90, 200);
        else
          stroke(255, 200);
          
        noFill();
        strokeWeight(3);
        line(wanderBoid.location.x, wanderBoid.location.y, closestTargetPosition.x, closestTargetPosition.y);
      }
    }
    else {
      wanderBoid.wander();
    }
    wanderBoid.run();
  }

  if (showTuioCursors) {
    // render the touch/bodies cursors (TUIO)
    for (int i=0;i<tuioCursorList.size();i++) {
      TuioCursor tcur = (TuioCursor)tuioCursorList.elementAt(i);
  
      // for each tuio cursor, pick objects inside the mouseAvoidScope
      // and convert them in pursuers
      PVector cursorPosition = new PVector(tcur.getScreenX(width), tcur.getScreenY(height));
  
      boolean shouldEvade = determineTuioCursorShouldEvade(tcur);
      if (shouldEvade)
      {
        // red for evade
        tint(255, 90, 90, 200);
        stroke(255, 90, 90, 200);
      }
      else
      {
        tint(255, 200);
        stroke(255, 200);
      }
      noFill();
      strokeWeight(3);
      float radius1 = 300;
      //ellipse(hitPixels.x, hitPixels.y, radius1, radius1);
      tint(255, 128);
      image(ripple, cursorPosition.x-(radius1/2), cursorPosition.y-(radius1/2), radius1, radius1);
    }
  }


    if (press) {
      stroke(255, 200);
      noFill();
      strokeWeight(3);
      float radius1 = (millis()-pressTime)/4;
      float radius2 = radius1-70;
      float radius3 = radius2-70;
      //tint(255, (pressInterval - (millis() - pressTime)) / pressInterval * 255);
      if ((radius1 > 20) && (radius1 < 300))
      {
        //ellipse(hitPixels.x, hitPixels.y, radius1, radius1);
        tint(255, (300 - radius1) / 300 * 255);
        image(ripple, hitPixels.x-(radius1/2), hitPixels.y-(radius1/2), radius1, radius1);
      }
      if ((radius2 > 20) && (radius2 < 300))
      {
        //ellipse(hitPixels.x, hitPixels.y, radius2, radius2);
        tint(255, (300 - radius2) / 300 * 255);
        image(ripple, hitPixels.x-(radius2/2), hitPixels.y-(radius2/2), radius2, radius2);
      }
      if ((radius3 > 20) && (radius3 < 300))
      {
        //ellipse(hitPixels.x, hitPixels.y, radius3, radius3);
        tint(255, (300 - radius3) / 300 * 255);
        image(ripple, hitPixels.x-(radius3/2), hitPixels.y-(radius3/2), radius3, radius3);  
      }
      if (millis() - pressTime > pressInterval) {
        press = false;
      }
  }
  
  // ripples code
  if (isRipplesActive == true) {
    refreshCanvas();
    ripples.update();
  }
  
  //image(innerShadow, 0, 0);
  
  //println("fps: " + frameRate);
}

// Every other cursor is treated as something to evade or pursue
boolean determineTuioCursorShouldEvade(TuioCursor tcur)
{
  boolean shouldEvade = (tcur.getSessionID() % 2 == 0);
//  float speedSquared = tcur.getXSpeed() * tcur.getXSpeed() + tcur.getYSpeed() * tcur.getYSpeed();
//  shouldEvade = (speedSquared > 1);
//  println("TUIO cursor " + tcur.getSessionID() + " is moving at v * v = " + speedSquared);
  return shouldEvade;
}

// increments number of koi by 1
void addKoi() {
  int id = int(random(minSkinIndex, maxSkinIndex + 1));
  wanderers.add(new Boid(skin[id],
  //new PVector(random(100, width - 100), random(100, height - 100)), random(0.8, 1.9), .5));
  new PVector(random(100, width - 100), random(100, height - 100)), random(.2, 2.5), .2));
  Boid wanderBoid = (Boid)wanderers.get(addKoiCounter);
  // sets opacity to simulate deepth
  wanderBoid.maxOpacity = int(map(addKoiCounter, 0, NUM_BOIDS - 1, 150, 255));

  addKoiCounter++;
}


// use for the ripple effect to refresh the canvas
void refreshCanvas() {
  loadPixels();
  System.arraycopy(pixels, 0, canvas.pixels, 0, pixels.length);
  updatePixels();
}

void mousePressed() {
  //println(mouseX + " " + mouseY);
  hitPixels = new PVector(mouseX, mouseY);
  press = true;
  pressTime = millis();
  mouseAvoidTarget = new PVector(mouseX, mouseY);

  if (isRipplesActive == true) ripples.makeTurbulence(mouseX, mouseY);
}

void mouseDragged() {
  mouseAvoidTarget.x = mouseX;
  mouseAvoidTarget.y = mouseY;

  if (isRipplesActive == true) ripples.makeTurbulence(mouseX, mouseY);
}

void mouseReleased() {
  //press = false;
}

