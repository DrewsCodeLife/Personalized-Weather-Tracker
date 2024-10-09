import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:units_converter/units_converter.dart';

// https://api.weather.gov/stations/KCIC/observations/latest

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Weather Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'KCIC Wx'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Database? database;
  Map<String, dynamic>? weatherData;
  int dbSize = 0;

  // SQLite stuff happens here I guess
  Future<void> initializeDB() async {
    String path = await getDatabasesPath();
    database = await openDatabase(
      join(path, 'weather.db'),
      onCreate: (db, version) async {
        await db.execute (
          "CREATE TABLE weather(id INTEGER PRIMARY KEY AUTOINCREMENT, temperature REAL, windSpeed REAL, windGust REAL)"
        );
      },
      version: 1,
    );
  }

  Future<int> getWeatherTableSize(Database? db) async {
    if (db != null) {
      var result = await db.rawQuery('SELECT COUNT(*) FROM weather');
      int count = Sqflite.firstIntValue(result) ?? 0;
      return count;
    }
    return 0;
  }

  Future<void> fetchWeatherData() async {
    if (database == null) {
      print("Database not initialized (fwd).");
      return;
    }

    final String apiUrl = 'https://api.weather.gov/stations/KCIC/observations/latest';
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      setState(() {
        weatherData = jsonDecode(response.body);
      });
      await saveWeatherData(database!, weatherData!);
    } else {
      print("Failed to fetch weather data");
    }

    int count = await getWeatherTableSize(database);
    setState(() {
      dbSize = count;
    });
    
    if (count > 504) {
      var oldestRow = await database!.query('weather', orderBy: 'id ASC', limit: 1);
      if (oldestRow.isNotEmpty) {
        int oldestId = oldestRow.first['id'] as int;
        await database!.delete('weather', where: 'id = ?', whereArgs: [oldestId]);
      }
    }
  }

  // Save to local storage
  Future<void> saveWeatherData(Database db, Map<String, dynamic> data) async {
    num? temp;
    num? windS;
    num? windG;
    var pTemp = data['properties']['temperature']['value'];
    var pWindS = data['properties']['windSpeed']['value'];
    var pWindG = data['properties']['windGust']['value'];

    if (pTemp is String) {
      temp = double.parse(pTemp).convertFromTo(TEMPERATURE.celsius, TEMPERATURE.fahrenheit);
    } else if (pTemp is num) {
      temp = pTemp.toDouble().convertFromTo(TEMPERATURE.celsius, TEMPERATURE.fahrenheit);
    } else {
      temp = 0.0;
    }
    if (pWindS is String) {
      windS = double.parse(pWindS).convertFromTo(SPEED.kilometersPerHour, SPEED.milesPerHour);
    } else if (pWindS is num) {
      windS = pWindS.toDouble().convertFromTo(SPEED.kilometersPerHour, SPEED.milesPerHour);
    } else {
      windS = 0.0;
    }
    if (pWindG is String) {
      windG = double.parse(pWindG).convertFromTo(SPEED.kilometersPerHour, SPEED.milesPerHour);
    } else if (pWindG is num) {
      windG = pWindG.toDouble().convertFromTo(SPEED.kilometersPerHour, SPEED.milesPerHour);
    } else {
      windG = 0.0;
    }

    await db.insert('weather', {
      'temperature': temp,
      'windSpeed': windS,
      'windGust': windG
    });
  }

  Future<List<Map<String, dynamic>>> getWeatherData(Database db) async {
    fetchWeatherData();
    return await db.query('weather');
  }

  @override
  void initState() {
    super.initState();
    initializeDB().then((_) {
      if (database != null) {
        fetchWeatherData();
      } else {
        print("Database initialization failed.");
      }
    }).catchError((e) {
      print("Error initializing database: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 20),
            weatherData == null
              ? CircularProgressIndicator()
              : Column(
                  children: [
                    Text(
                          'Temperature: ${weatherData!['properties']['temperature']['value']}°F'),
                    Text(
                          'Wind Speed: ${weatherData!['properties']['windSpeed']['value']} Mph'),
                    Text(
                          'Wind Gust: $weatherData![]'
                    )
                    Text(
                          'Database size: $dbSize'),
                  ],
                ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                List<Map<String, dynamic>> data =
                  await getWeatherData(database!);
                print(data); // Bug fixing
              },
              child: const Text('Show Saved Data'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (database != null) {
                  await database!.delete('weather');
                  print("Weather data cleared");
                  setState(() {
                    weatherData = null;
                  });
                }
              },
              child: const Text('Clear Data'),
            ),
          ],
        ),
      ),
    );
  }
}
