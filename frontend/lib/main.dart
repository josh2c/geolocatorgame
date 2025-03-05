import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize WebView Platform
  late final PlatformWebViewControllerCreationParams params;
  if (WebViewPlatform.instance is WebKitWebViewPlatform) {
    params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );
  } else {
    params = const PlatformWebViewControllerCreationParams();
  }

  runApp(const GeoLocatorApp());
}

class GeoLocatorApp extends StatelessWidget {
  const GeoLocatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoLocator Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StartMenu(),
    );
  }
}

class StartMenu extends StatelessWidget {
  const StartMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                'GeoLocator',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Test your geography knowledge!',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
              const SizedBox(height: 48),

              // Menu Buttons
              SizedBox(
                width: 250,
                child: Column(
                  children: [
                    _MenuButton(
                      icon: Icons.play_arrow,
                      label: 'Start Game',
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const MapScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _MenuButton(
                      icon: Icons.emoji_events,
                      label: 'High Scores',
                      onPressed: () {
                        // TODO: Implement high scores
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('High scores coming soon!'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _MenuButton(
                      icon: Icons.help_outline,
                      label: 'How to Play',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('How to Play'),
                            content: const SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '1. You\'ll be shown a street-level image from somewhere in the world.'),
                                  SizedBox(height: 8),
                                  Text('2. Look for clues in the image like:'),
                                  Padding(
                                    padding: EdgeInsets.only(left: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('• Architecture'),
                                        Text('• Road signs'),
                                        Text('• Vegetation'),
                                        Text('• Vehicles'),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                      '3. Make your guess by tapping on the world map.'),
                                  SizedBox(height: 8),
                                  Text(
                                      '4. Score points based on how close your guess is!'),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Got it!'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _MenuButton(
                      icon: Icons.settings,
                      label: 'Settings',
                      onPressed: () {
                        // TODO: Implement settings
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Settings coming soon!'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMapController? mapController;
  WebViewController? webViewController;
  Symbol? targetMarker;
  Symbol? guessMarker;
  LatLng? targetLocation;
  bool gameInProgress = false;
  int score = 0;
  int roundsPlayed = 0;
  String? locationImageUrl;
  bool showingImage = false;
  bool isLoading = false;
  String? errorMessage;
  String? imageId;
  bool showingCountdown = true;
  int countdownSeconds = 5;
  Line? distanceLine;
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
    _startCountdown();
  }

  void _initWebViewController() {
    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    webViewController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            developer.log(
                'WebView error: ${error.description}, errorCode: ${error.errorCode}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          developer.log('Message from JavaScript: ${message.message}');
        },
      );

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      (webViewController!.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(false);
    }
  }

  void _startCountdown() {
    setState(() {
      showingCountdown = true;
      countdownSeconds = 5;
    });

    Future.doWhile(() async {
      if (countdownSeconds == 0) {
        if (mounted) {
          setState(() {
            showingCountdown = false;
          });
          _startNewRound();
        }
        return false;
      }

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          countdownSeconds--;
        });
      }
      return true;
    });
  }

  Future<String?> _getMapillaryImage(LatLng location) async {
    final accessToken = dotenv.env['MAPILLARY_ACCESS_TOKEN'];
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Mapillary access token is not configured');
    }

    // Increase search radius and use a more flexible bounding box
    const searchRadius = 0.02; // Roughly 2km at the equator
    final searchUrl = Uri.parse('https://graph.mapillary.com/images')
        .replace(queryParameters: {
      'access_token': accessToken,
      'fields': 'id,thumb_1024_url',
      'limit': '5',
      'bbox': '${location.longitude - searchRadius},${location.latitude - searchRadius},'
          '${location.longitude + searchRadius},${location.latitude + searchRadius}',
      'min_captured_at': '2019-01-01', // Limit to recent images
      'is_pano': 'true' // Get panoramic images for better viewing
    });

    try {
      developer
          .log('Requesting Mapillary images from: ${searchUrl.toString()}');
      final response = await http.get(searchUrl);
      developer.log('Mapillary search response status: ${response.statusCode}');
      developer.log('Mapillary search response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          // Try to find an image that has a thumb_1024_url
          for (final image in data['data']) {
            if (image['thumb_1024_url'] != null) {
              imageId = image['id'];
              return image['thumb_1024_url'];
            }
          }
        }
        throw Exception('No suitable images found at this location');
      } else if (response.statusCode == 400) {
        throw Exception('Invalid request to Mapillary API: ${response.body}');
      } else if (response.statusCode == 401) {
        throw Exception('Invalid or expired Mapillary access token');
      } else {
        throw Exception(
            'Mapillary API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      developer.log('Error getting Mapillary image: $e');
      rethrow;
    }
  }

  // Generate a random location within reasonable bounds
  LatLng _generateRandomLocation() {
    // Cities with good Mapillary coverage
    final cities = [
      LatLng(40.7128, -74.0060), // New York
      LatLng(51.5074, -0.1278), // London
      LatLng(48.8566, 2.3522), // Paris
      LatLng(37.7749, -122.4194), // San Francisco
      LatLng(34.0522, -118.2437), // Los Angeles
      LatLng(41.8781, -87.6298), // Chicago
      LatLng(52.5200, 13.4050), // Berlin
      LatLng(55.6761, 12.5683), // Copenhagen (Mapillary's hometown!)
      LatLng(59.3293, 18.0686), // Stockholm
      LatLng(25.2048, 55.2708), // Dubai
    ];

    final random = Random();
    final baseLocation = cities[random.nextInt(cities.length)];

    // Add some random offset (within roughly 2km)
    final latOffset = (random.nextDouble() - 0.5) * 0.02;
    final lngOffset = (random.nextDouble() - 0.5) * 0.02;

    return LatLng(
      baseLocation.latitude + latOffset,
      baseLocation.longitude + lngOffset,
    );
  }

  // Calculate distance between two points in kilometers
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final dLat = (point2.latitude - point1.latitude) * pi / 180;
    final dLon = (point2.longitude - point1.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Update the image viewer when we have a new image
  void _updateImageViewer() {
    developer.log('Updating image viewer with imageId: $imageId');
    if (imageId != null && webViewController != null) {
      developer.log('Setting up WebView controller');
      webViewController!.loadHtmlString('''
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta http-equiv="Content-Security-Policy" content="default-src * 'unsafe-inline' 'unsafe-eval' data: blob:;">
            <title>Mapillary Viewer</title>
            <style>
              body { margin: 0; padding: 0; background: #000; height: 100vh; width: 100vw; overflow: hidden; }
              #mly { width: 100%; height: 100%; }
              /* Hide play button */
              .mapillary-js-dom .mly-wrapper .mly-sequence-play { display: none !important; }
            </style>
          </head>
          <body>
            <div id="mly"></div>
            <script>
              let retryCount = 0;
              const maxRetries = 5;
              
              function loadMapillary() {
                Flutter.postMessage('Loading Mapillary script...');
                const script = document.createElement('script');
                script.src = 'https://unpkg.com/mapillary-js@4.1.0/dist/mapillary.js';
                script.onload = function() {
                  Flutter.postMessage('Mapillary script loaded successfully');
                  loadMapillaryCSS();
                };
                script.onerror = function() {
                  Flutter.postMessage('Error loading Mapillary script');
                  retryLoadingIfNeeded();
                };
                document.head.appendChild(script);
              }

              function loadMapillaryCSS() {
                const link = document.createElement('link');
                link.rel = 'stylesheet';
                link.href = 'https://unpkg.com/mapillary-js@4.1.0/dist/mapillary.css';
                link.onload = function() {
                  Flutter.postMessage('Mapillary CSS loaded successfully');
                  initializeViewer();
                };
                link.onerror = function() {
                  Flutter.postMessage('Error loading Mapillary CSS');
                  retryLoadingIfNeeded();
                };
                document.head.appendChild(link);
              }

              function retryLoadingIfNeeded() {
                if (retryCount < maxRetries) {
                  retryCount++;
                  Flutter.postMessage('Retrying load... Attempt ' + retryCount);
                  setTimeout(loadMapillary, 1000);
                } else {
                  Flutter.postMessage('Failed to load after ' + maxRetries + ' attempts');
                }
              }

              function initializeViewer() {
                try {
                  if (typeof mapillary === 'undefined') {
                    Flutter.postMessage('Mapillary not loaded yet, retrying...');
                    retryLoadingIfNeeded();
                    return;
                  }

                  Flutter.postMessage('Initializing viewer with imageId: $imageId');
                  const viewer = new mapillary.Viewer({
                    accessToken: '${dotenv.env['MAPILLARY_ACCESS_TOKEN']}',
                    container: 'mly',
                    imageId: '$imageId',
                    component: {
                      cover: false,
                      bearing: true,
                      zoom: true,
                      sequence: false,
                      direction: false,
                      spatial: false
                    }
                  });

                  viewer.on('load', () => {
                    Flutter.postMessage('Viewer loaded successfully');
                  });

                  viewer.on('error', (error) => {
                    Flutter.postMessage('Viewer error: ' + JSON.stringify(error));
                  });
                } catch (error) {
                  Flutter.postMessage('Initialization error: ' + error.toString());
                  retryLoadingIfNeeded();
                }
              }

              window.onerror = function(msg, url, line, col, error) {
                Flutter.postMessage('Global error: ' + msg + ' at ' + url + ':' + line);
                return false;
              };

              // Start loading process
              loadMapillary();
            </script>
          </body>
          </html>
        ''');
    } else {
      developer.log(
          'Cannot update image viewer: imageId or webViewController is null');
    }
  }

  // Add timer methods
  void _startTimer() {
    _elapsedSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Update _startNewRound to handle retries for locations without images
  void _startNewRound() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _elapsedSeconds = 0;
    });

    // Clear previous markers
    if (targetMarker != null) {
      await mapController?.removeSymbol(targetMarker!);
    }
    if (guessMarker != null) {
      await mapController?.removeSymbol(guessMarker!);
    }

    int maxAttempts = 3;
    int currentAttempt = 0;

    while (currentAttempt < maxAttempts) {
      try {
        final newLocation = _generateRandomLocation();
        final imageUrl = await _getMapillaryImage(newLocation);

        if (imageUrl != null) {
          setState(() {
            targetLocation = newLocation;
            locationImageUrl = imageUrl;
            gameInProgress = true;
            showingImage = true;
            isLoading = false;
          });

          _updateImageViewer();
          _startTimer(); // Start the timer when showing the image

          // Reset the map view
          await mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(0, 0),
                zoom: 1,
              ),
            ),
          );
          return; // Success, exit the loop
        }
      } catch (e) {
        developer.log('Attempt ${currentAttempt + 1} failed: $e');
      }
      currentAttempt++;
    }

    // If we get here, all attempts failed
    setState(() {
      isLoading = false;
      errorMessage = 'Unable to find a suitable location. Please try again.';
    });
  }

  // Handle map tap for making guesses
  void _onMapTap(Point<double> point, LatLng coordinates) async {
    if (!gameInProgress || showingImage) return;

    _stopTimer(); // Stop the timer when user makes a guess

    // Remove previous markers and line
    if (guessMarker != null) {
      await mapController?.removeSymbol(guessMarker!);
    }
    if (distanceLine != null) {
      await mapController?.removeLine(distanceLine!);
    }

    // Add new guess marker
    guessMarker = await mapController?.addSymbol(
      SymbolOptions(
        geometry: coordinates,
        iconImage: 'marker-15',
        iconSize: 2,
        iconColor: '#FF0000',
      ),
    );

    // Add target marker
    targetMarker = await mapController?.addSymbol(
      SymbolOptions(
        geometry: targetLocation,
        iconImage: 'marker-15',
        iconSize: 2,
        iconColor: '#00FF00',
      ),
    );

    // Draw line between guess and target
    distanceLine = await mapController?.addLine(
      LineOptions(
        geometry: [coordinates, targetLocation!],
        lineColor: '#FF0000',
        lineWidth: 2,
        lineOpacity: 0.7,
      ),
    );

    // Calculate distance and score
    final distance = _calculateDistance(coordinates, targetLocation!);
    final roundScore = max(0, (10000 - distance * 10).round());

    setState(() {
      score += roundScore;
      roundsPlayed++;
      gameInProgress = false;
    });

    // Animate camera to show both markers
    final bounds = LatLngBounds(
      southwest: LatLng(
        min(coordinates.latitude, targetLocation!.latitude),
        min(coordinates.longitude, targetLocation!.longitude),
      ),
      northeast: LatLng(
        max(coordinates.latitude, targetLocation!.latitude),
        max(coordinates.longitude, targetLocation!.longitude),
      ),
    );

    await mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds,
          left: 50, right: 50, top: 50, bottom: 50),
    );

    // Show result dialog
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Round Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Distance: ${distance.toStringAsFixed(2)} km'),
            const SizedBox(height: 8),
            Text(
              'Round Score: $roundScore',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Total Score: $score'),
            const SizedBox(height: 8),
            Text(
                'Time taken: ${_elapsedSeconds ~/ 60}m ${_elapsedSeconds % 60}s'),
            const SizedBox(height: 16),
            const Text('Red Marker: Your Guess'),
            const Text('Green Marker: Actual Location'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showingCountdown) {
      return Scaffold(
        body: Container(
          color: Colors.white,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get Ready!',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 24),
                Text(
                  '$countdownSeconds',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoLocator Game'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (showingImage)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(
                      'Time: ${_elapsedSeconds ~/ 60}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                Text(
                  'Score: $score',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MapboxMap(
            accessToken: dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '',
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 1,
              bearing: 0.0,
            ),
            onMapCreated: (controller) {
              setState(() {
                mapController = controller;
              });
            },
            onMapClick: _onMapTap,
            compassEnabled: false,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: false,
            scrollGesturesEnabled: false,
            doubleClickZoomEnabled: true,
            tiltGesturesEnabled: false,
            dragEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.None,
            attributionButtonMargins: const Point<double>(-100, -100),
            styleString: MapboxStyles.LIGHT,
            minMaxZoomPreference: const MinMaxZoomPreference(1.0, 20.0),
            myLocationEnabled: false,
            trackCameraPosition: false,
          ),
          if (showingImage)
            Container(
              color: Colors.black87,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const CircularProgressIndicator()
                  else if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _startNewRound,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  else if (locationImageUrl != null &&
                      webViewController != null)
                    Column(
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: WebViewWidget(
                            controller: webViewController!,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              showingImage = false;
                            });
                          },
                          child: const Text('Make Your Guess'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          if (!gameInProgress && !showingImage)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: _startNewRound,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Start New Round'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
