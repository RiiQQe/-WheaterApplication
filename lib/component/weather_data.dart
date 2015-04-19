/*  Handles reading from SMHI, and storing the weatherparams in the class WeatherSet
 * WeatherData contains a list of WeatherSets.
 * Right now it also draws the timeline.
 */



library weatherdata_component;

import 'package:angular/application_factory.dart';
import 'package:angular/angular.dart';
import 'package:di/annotations.dart';
import 'package:collection/collection.dart';
import 'dart:html';
import 'dart:html' as dom;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

import 'package:weatherapplication/decorators/image_decorator.dart' show ImageModel;

@Component(
    selector: 'weather-data', 
    templateUrl: 'packages/weatherapplication/component/weather_data.html',
    cssUrl: 'packages/weatherapplication/component/weather_data.css'    
)
  
    
class WeatherDataComponent {

  Map allData;
  double latitude, longitude;
  double currentTemp;
  City currentCity;
  List<WeatherSet> weatherSets = [];
  List<City> allCities = [];
  List<String> cities = ["Norrköping", "Norge", "Rimforsa"];
  Map<String, bool> cityFilterMap;
  WeatherSet currentWeatherSet;
  final DateFormat formatter = new DateFormat('HH:mm d/M');
  static final imageDec = new Expando<ImageModel>();
  String cityName = "";
  
  //Constructor saves coorinates to member variables
  WeatherDataComponent() {
    //var coord = findCoords();
    List<double> coord = [58.1378296, 15.6762024];
    latitude = coord[0];
    longitude = coord[1];
    
    
    _loadData();
  }

  ImageModel ImageDecoratorForWeatherData(WeatherSet ws){
    if(imageDec[ws] == null){
      imageDec[ws] = new ImageModel('http://www.i2symbol.com/images/symbols/weather/white_sun_with_rays_u263C_icon_256x256.png',
                    "I don't have a picture of these recipes, "
                    "so here's one of my cat instead!",
                    100);
    }
    return imageDec[ws];
  }
  
  void name2Coords(String cityName){
      
      cityName = cityName.toLowerCase();
      
      var url = 'http://nominatim.openstreetmap.org/search?q=$cityName&format=json';
      
      currentCity.name = cityName;
      
      HttpRequest.getString(url).then((String responseText){
          Map citySearch = JSON.decode(responseText);
          
          latitude = double.parse(citySearch[1]["lat"]);
          longitude = double.parse(citySearch[1]["lon"]);

          _loadData();
                  
      });
        
        
  }

  //Load data and call all other functions that does anything with the data
  void _loadData() {
    
    print("Loading data");
    
    String latitudeString = latitude.toStringAsPrecision(6);
    String longitudeString = longitude.toStringAsPrecision(6);
    
    var currentCityUrl = 'http://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1';

    //This is used to print current city
    HttpRequest.getString(currentCityUrl).then((String responseText) {
      Map currentData = JSON.decode(responseText);
      
      currentCity = new City(currentData["address"]["village"]); 
  
    });
    
    //Create URL to SMHI-API with longitude and latitude values
    var url = 'http://opendata-download-metfcst.smhi.se/api/category/pmp1.5g/version/1/geopoint/lat/$latitudeString/lon/$longitudeString/data.json';
    
    //Call SMHI-API
    HttpRequest.getString(url).then((String responseText) {

      //Parse response text
      allData = JSON.decode(responseText);
 
      setWeatherParameters();
      
      int timeIndex = getTimeIndex();
      currentWeatherSet = weatherSets[timeIndex];
     
      //Initilize categoryFilterMap with keys:categories and values:bools
      List<bool> defaultBools = [false, false, false];
      cityFilterMap = new Map.fromIterables(cities, defaultBools);
      
      allCities.clear();
      for(int i=0; i <= 2; i++)
       {
         allCities.add(new City(cities[i]));
       }
      
       
      
       drawCanvas();

       
     
  }, onError: (error) => printError(error));


  }

  void printError(error) {
    print("It doesn't work, too bad! Hej code: ${error.code}");
  }
  
  void setWeatherParameters() {
    String cloud, rain, wind, category, timeFormatted;
    int cloudIndex, rainIndex;
    double windIndex, currentTemp;
    DateTime currentTime;
    
    weatherSets.clear();
    
    for (int i = 0; i < allData["timeseries"].length; i++) {
      //Get all parameters to initialize a new WeatherSet
      currentTemp = allData["timeseries"][i]["t"];
      currentTime = DateTime.parse(allData["timeseries"][i]["validTime"]);
      //category = getCategory(currentTime);
      timeFormatted = formatter.format(currentTime);
      
      cloudIndex = allData["timeseries"][i]["tcc"];
      rainIndex = allData["timeseries"][i]["pcat"];
      windIndex = allData["timeseries"][i]["gust"];
     

      //Get description of parameters from parameter index
      cloud = getCloud(cloudIndex);
      rain = getRain(rainIndex, i);
      wind = getWind(windIndex);

      //Add new WeatherSet to the list weatherSets
      weatherSets.add(new WeatherSet(currentTemp, cloud, rain, wind, timeFormatted));
    }
    
  }
  
  int getTimeIndex(){
     DateTime referenceTime = DateTime.parse(allData["referenceTime"]);
     DateTime now = new DateTime.now();
     
     //Difference in hours = timeIndex for current time in allData
     Duration difference = now.difference(referenceTime);
     return difference.inHours;
  }
  //Primitive way of translating parameters from numbers to Strings
  String getCloud(int cloudIndex) {
    String cloud;

    if (cloudIndex < 3) cloud = "Lite moln"; 
    else if (cloudIndex < 6 && cloudIndex > 2) cloud = "Växlande molnighet"; 
    else cloud = "Mulet";

    return cloud;
  }


    String getRain(int rainIndex, int timeIndex) {

    String rain;
    double howMuch;

    switch (rainIndex) {
      case 0:
        rain = "Inget regn";
        break;
      case 1:
        howMuch = allData["timeseries"][timeIndex]["pis"];
        rain = "Snö, $howMuch mm/h";
        break;
      case 2:
        howMuch = allData["timeseries"][timeIndex]["pis"] + allData["timeseries"][timeIndex]["pit"];
        rain = "Snöblandat regn, $howMuch mm/h";
        break;
      case 3:
        howMuch = allData["timeseries"][timeIndex]["pit"];
        rain = "Regn, $howMuch mm/h";
        break;
      case 4:
        rain = "Duggregn";
        break;
      case 5:
        rain = "Hagel";
        break;
      case 6:
        rain = "Smått hagel";
        break;
      default:
        rain = "";
    }

    return rain;
  }

  String getWind(double windIndex) {
    String wind = "";

    if (windIndex <= 0.3)
      wind = "Vindstilla"; 
    else if (windIndex > 0.3 && windIndex <= 3.3) 
      wind = "Svag vind"; 
    else if (windIndex > 3.3 && windIndex <= 13.8) 
      wind = "Blåsigt"; 
    else if (windIndex > 13.8 && windIndex <= 24.4) 
      wind = "Mycket blåsigt"; 
    else if (windIndex > 24.4 && windIndex < 60) 
      wind = "Storm";

    return wind;
  }

  //Function to set the device's geocoordinates
  findCoords() {

    //Get the location of the device
    window.navigator.geolocation.getCurrentPosition().then((Geoposition pos) {

      double lat = pos.coords.latitude;
      double long = pos.coords.longitude;

      var coordinates = [lat, long];
      return coordinates;

    }, onError: (error) => printError(error));

  }
  
  //Used by the filtering function
  String getCity(String typedCity){
    String city;
    
    //Set category so that the data can be filterd
    if(typedCity == "Norrköping")
      city = cities[0];     //Norrköping
    else if(typedCity == "Rimforsa")
      city = cities[1];     //Rimforsa
    else if(typedCity == "Lund")
      city = cities[2];     //Lund
    
    return city;
  }
  //Primitive way of displaying lower Timeline.
  void drawCanvas(){
    
    DateTime now = new DateTime.now();
    
    int hour = now.hour;
    int minute = now.minute;
    
    String min;
    
    //Just so 17:9 -> 17:09 
    min = (minute < 10 ? "0" + minute.toString() : minute.toString());
    
    CanvasElement can = querySelector("#myCanvas");
    var ctx = can.getContext("2d");
    
    double height = can.getBoundingClientRect().height;
    double width = can.getBoundingClientRect().width;
    
    //Draw timeline
    ctx.beginPath();
        ctx.moveTo(100,85);
        ctx.lineTo(100, 1000);
        ctx.lineWidth = 10;
        ctx.stroke();
    ctx.font = "15px serif";
    ctx.fillText("$hour:$min", 85,40);
    
    ImageElement img = new ImageElement(src: 'http://www.i2symbol.com/images/symbols/weather/white_sun_with_rays_u263C_icon_256x256.png');
    
    img.onLoad.listen( (value) => /*ctx.drawImage(img, 0, 0)*/ ctx.drawImageScaled(img, 0, 0, 100, 100) );
        for(int i=1; i < 10; i++){
              
              hour++;;
              
              if(hour > 24) hour = 0;
              //Set text on canvas to hour:min at pos x,y
              //fillText("String", pos x, pos y)
              ctx.fillText("$hour:$min", 10, i * 100);
              //ctx.drawImage(img, 0,i * 50);
             
              ctx.fillText("${weatherSets[i].temp} °C", 150,i *  100);
              
        }
    
  }
}

class WeatherSet {
  double temp;
  String cloud, rain, wind, time;
  
  WeatherSet(this.temp, this.cloud, this.rain, this.wind, this.time);
  
  
  //Can be return a string to ng-repeat in weather_data.html
  String draw(){
    
      CanvasElement can = new CanvasElement();
      can.height = 200;
      can.width = 2000;
    
     return temp.toString();
  }
}

class City {
  String name;
  
  City(String name2)
  {
    this.name = name2;
  }
}




