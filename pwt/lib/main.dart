import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
  // Probably don't need this: int _counter = 0;
  Database? database;
  Map<String, dynamic>? weatherData;

  // SQLite stuff happens here I guess
  Future<void> initializeDB() async {
    String path = await getDatabasesPath();
    database = await openDatabase(
      join(path, 'weather.db'),
      onCreate: (db, version) async {
        await db.execute (
          "CREATE TABLE weather(id INTEGER PRIMARY KEY AUTOINCREMENT, temperature TEXT, windSpeed TEXT)"
        );
      },
      version: 1,
    );
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
  }

  // Save to local storage
  Future<void> saveWeatherData(Database db, Map<String, dynamic> data) async {
    await db.insert('weather', {
      'temperature': data['properties']['temperature']['value'].toString(),
      'windSpeed': data['properties']['windSpeed']['value'].toString(),
    });
  }

  Future<List<Map<String, dynamic>>> getWeatherData(Database db) async {
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
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
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
                          'Temperature: ${weatherData!['properties']['temperature']['value']}°C'),
                      Text(
                          'Wind Speed: ${weatherData!['properties']['windSpeed']['value']} km/h'),
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
          ],
        ),
      ),
    );
  }
}
