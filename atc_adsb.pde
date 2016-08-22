import processing.net.*; 
import java.util.*;

public class Position {
  public float pos_lat;
  public float pos_lon;
}

public class Aircraft {
  public Aircraft() {
    callsign = "";
    pos_lat = 0;
    pos_lon = 0;
    alt = -1;
    vert_rate = 0;
    last_time = -1;
    last_pos_update = -1;
    track = -1;
    speed = -1;
    
    last_positions = new ArrayList<Position>();
    last_pos_save_time = -1;
  }
  
  public String mode_s_reg;
  public String callsign;
  public float pos_lat;
  public float pos_lon;
  public float alt;
  public float vert_rate;
  public long last_time;
  public long last_pos_update;
  public float track;
  public float speed;
  
  //pos history
  public long last_pos_save_time;
  public ArrayList<Position> last_positions;
}


Client c;
ArrayList<Aircraft> aircrafts;
float LAT_CTN = 53.044916;
float LON_CTN = 8.789652;
final int WIDTH = 600;
final int HEIGHT = 600;
final int POS_SAVES = 5;
final int POS_SAVES_INTERV = 5;
String gmapAPI = "AIzaSyBZoFosVL27IeHx57Wujg-v_aW3slJWItA";
PImage map;
float mapRange = 2;

void setup() {
  aircrafts = new ArrayList<Aircraft>();
  
  //udp= new UDP(this, 30003, "127.0.0.1");
  c = new Client(this, "127.0.0.1", 30003);
  //udp.listen(true);
  
  size(600,600);
  rectMode(CENTER);
  
  frameRate(1);
  
  //load map
  int zoom = 9;
  int scale = 1;
  String url = "https://maps.googleapis.com/maps/api/staticmap?style=element:labels|visibility:off&style=feature:water|element:geometry.fill|saturation:-100|invert_lightness:true&style=element:geometry|saturation:-100|lightness:-75&center=" + LAT_CTN + "," + LON_CTN + "&zoom=" + zoom + "&size=" + WIDTH + "x" + HEIGHT + "&scale=" + scale + "&format=png&key=" + gmapAPI;
  map = loadImage(url, "png");
  mapRange = (WIDTH/256)*(360 / pow(2,zoom))/2;
  println("Map Range: " + mapRange*60 + " NM");
}


void draw() {
  //interpolate AC Positions
  interpolatePos();
  
  //fetch data
  if (c.available() > 0) {
    String data = null;
    do {
      data = c.readStringUntil('\n');
      receive(data);
    } while (data != null);
  }
  
  
  fill(255);
  background(0);
  image(map, 0, 0, WIDTH, HEIGHT);
  textSize(10);
  
  stroke(0, 200, 0);
  noFill();
  rect(WIDTH/2, HEIGHT/2, 10, 10);
  text("EDDW", WIDTH/2+10, HEIGHT/2-5); 
  
  long time = System.currentTimeMillis()/1000;
  int remove_id = -1;
  
  //draw each aircraft
  for(int i=0; i < aircrafts.size(); i++) {
    Aircraft ac = aircrafts.get(i);
    
    if (ac.pos_lat != 0 || ac.pos_lon != 0) {
      float my = (1 - (ac.pos_lat-LAT_CTN)/mapRange)*WIDTH/2;
      float mx = (1 + (ac.pos_lon-LON_CTN)/mapRange)*HEIGHT/2;
      
      // prev positions
      for(int j=0; j < ac.last_positions.size(); j++) {
        Position pos = ac.last_positions.get(j);
        float pmy = (1 - (pos.pos_lat-LAT_CTN)/mapRange)*WIDTH/2;
        float pmx = (1 + (pos.pos_lon-LON_CTN)/mapRange)*HEIGHT/2;
        point(pmx, pmy);
      }
      
      //box on AC position
      rect(mx, my, 5, 5); 
      
      //text
      String line1 = ac.mode_s_reg;
      if (ac.callsign.length() > 0) {
        line1 += " (" + ac.callsign + ")";
      }
      text(line1, mx+10, my-5);
      
      String line2 = "";
      if (ac.alt > 0) {
         line2 += (int)round(ac.alt/100); 
         line2 += "  ";
         
         if (ac.vert_rate != 0) {
           if (ac.vert_rate > 0) {
             line2 += "↑";
           }
           if (ac.vert_rate < 0) {
             line2 += "↓";
           }
           
           line2 += (int)round(abs(ac.vert_rate)/100);
         }
      }
      text(line2, mx+10, my+10);
      
      
    }
    
    //draw sidelist of a/c
    if (ac.callsign.length() > 0) {
      text(ac.mode_s_reg + " (" + ac.callsign + ") " + (time-ac.last_time) + "s", 10, 20+i*15);
    } else {
      text(ac.mode_s_reg + " " + (time-ac.last_time) + "s", 10, 20+i*15);
    }
    
    //aircraft removal
    if (remove_id < 0 && (time-ac.last_time) > 300) remove_id = i;
  }
  
  
  //remove idle a/c
  if (remove_id >= 0) aircrafts.remove(remove_id);
}


void receive(String value) {
  if (value == null) return;
  print(value);
  
  String split[] = split(value, ',');
  if (split.length < 9) return;
  
  int id = getAircraftId(split[4].trim());
  if (id < 0) {
      Aircraft ac = new Aircraft();
      ac.mode_s_reg = split[4].trim();
      ac.callsign = "";
      ac.pos_lat = 0;
      ac.pos_lon = 0;
      ac.alt = 0;
      aircrafts.add(ac);
      println("New AC added: " + split[4].trim());
      
      id=aircrafts.indexOf(ac);
  }
  
  try {
    Aircraft ac = aircrafts.get(id);
    
    //set time
    ac.last_time = System.currentTimeMillis()/1000;
    int size = split.length;
    if (size < 17) return;
    
    //search aircraft and set information
    //position
    if (split[14].trim().length() > 0 && split[15].trim().length() > 0) {
      float px = Float.parseFloat(split[14].trim());
      float py = Float.parseFloat(split[15].trim());
      
      ac.pos_lat = px;
      ac.pos_lon = py;
      ac.last_pos_update = System.currentTimeMillis()/1000;
      println("AC Position added lat:" + px + " lon:" + py);
      
      //position save
      if (ac.last_pos_save_time <= 0) {
        ac.last_pos_save_time = System.currentTimeMillis()/1000;
      }
    }
    
    //callsign
    if (split[10].trim().length() > 0) {
      ac.callsign = split[10].trim();
    }
    
    //track
    if (split[13].trim().length() > 0) {
      ac.track = Float.parseFloat(split[13].trim());
    }
    
    //Ground speed
    if (split[12].trim().length() > 0) {
       ac.speed = Float.parseFloat(split[12].trim());
    }
    
    //alt
    if (split[11].trim().length() > 0) {
       ac.alt = Float.parseFloat(split[11].trim());
    }
    
    //vert rate
    if (split[16].trim().length() > 0) {
       ac.vert_rate = Float.parseFloat(split[16].trim());
    }
    
    aircrafts.set(id, ac);
  } catch (Exception e) {
    println("Parse error");
  }
}

int getAircraftId(String adsb_code) {
  for(int i=0; i < aircrafts.size(); i++) {
    Aircraft ac = aircrafts.get(i);
    if (ac.mode_s_reg.equals(adsb_code)) {
      return i;
    }
  }
  return -1;
}

void interpolatePos() {
   for(int i=0; i < aircrafts.size(); i++) {
      Aircraft ac = aircrafts.get(i);
      
      if (ac.track > 0 && ac.speed > 0 && (ac.pos_lat != 0 || ac.pos_lon != 0)) {
        long dt = System.currentTimeMillis()/1000 - ac.last_pos_update;
        float d_lat = ac.speed/60.0/3600.0 * dt * cos(radians(ac.track));
        float d_lon = ac.speed/60.0/3600.0 * dt * sin(radians(ac.track)) / cos(radians(ac.pos_lat));
        float d_alt = ac.vert_rate/60 * dt;
        
        ac.pos_lat += d_lat;
        ac.pos_lon += d_lon;
        ac.alt += d_alt;
        ac.last_pos_update += dt;
        
        //save position
        if (System.currentTimeMillis()/1000 - ac.last_pos_save_time > POS_SAVES_INTERV) {
          Position pos = new Position();
          pos.pos_lat = ac.pos_lat;
          pos.pos_lon = ac.pos_lon;
          ac.last_positions.add(pos);
          ac.last_pos_save_time = System.currentTimeMillis()/1000;
          
          //remove oldest
          if (ac.last_positions.size() > POS_SAVES) {
            ac.last_positions.remove(0);
          }
        }
      }
      
   }
}