import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_routes.dart';

class LocationPickerScreen extends StatefulWidget {
  final bool isEdit;
  final String editAddressId;
  final String editLatitude;
  final String editLongitude;
  final String editName;
  final String editPhone;
  final String editAddressDetails;
  final bool forceGPS;

  const LocationPickerScreen({
    super.key,
    this.isEdit = false,
    this.editAddressId = '',
    this.editLatitude = '',
    this.editLongitude = '',
    this.editName = '',
    this.editPhone = '',
    this.editAddressDetails = '',
    this.forceGPS = false,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final String _googleApiKey = "AIzaSyBcHzsB2kgoQa01PHIuYhVYeiCZlSiyXNo";

  LatLng _currentPosition = const LatLng(22.7196, 75.8577); // Indore fallback

  List<dynamic> _suggestions = [];
  bool _isGeocoding = false;
  bool _isCheckingService = false;
  bool _mapLoading = true;

  String _formattedAddress = "Loading address...";
  Map<String, String> _addressDetails = {};
  double? _lastGeocodedLat;
  double? _lastGeocodedLng;
  bool _isFetchingGPS = false;
  bool _isMapMoving = false;

  @override
  void initState() {
    super.initState();
    _detectCurrentLocation(forceGPS: widget.forceGPS);
  }

  Future<void> _detectCurrentLocation({bool forceGPS = false}) async {
    if (forceGPS) {
      setState(() => _isFetchingGPS = true);
    }
    try {
      if (widget.isEdit) {
        final lat = double.tryParse(widget.editLatitude);
        final lng = double.tryParse(widget.editLongitude);
        if (lat != null && lng != null) {
          setState(() {
            _currentPosition = LatLng(lat, lng);
            _mapLoading = false;
          });
          _reverseGeocode(lat, lng);
          return;
        }
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _mapLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _mapLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _mapLoading = false);
        return;
      }

      // Try to get last known location first for instant response
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _updateMapPosition(lastKnown.latitude, lastKnown.longitude);
      }

      final position = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.best,
      );

      _updateMapPosition(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error detecting location: $e');
      setState(() => _mapLoading = false);
    } finally {
      if (forceGPS) {
        setState(() => _isFetchingGPS = false);
      }
    }
  }

  void _updateMapPosition(double lat, double lng) {
    setState(() {
      _currentPosition = LatLng(lat, lng);
      _mapLoading = false;
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 17),
      ),
    );

    _reverseGeocode(lat, lng);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    if (_lastGeocodedLat != null && _lastGeocodedLng != null) {
      final double diffLat = (lat - _lastGeocodedLat!).abs();
      final double diffLng = (lng - _lastGeocodedLng!).abs();
      if (diffLat < 0.00001 && diffLng < 0.00001) {
        return;
      }
    }

    setState(() => _isGeocoding = true);

    try {
      final uri = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey",
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          final firstResult = data['results'][0];
          final addressComponents = firstResult['address_components'] as List;

          final components = _extractAddressComponents(addressComponents);
          final displayArea = components['area']!.isNotEmpty
              ? components['area']!
              : components['city']!;
          final cleanDisplayAddress = [
            displayArea,
            components['city'],
            components['state'],
            components['pincode']
          ].where((s) => s != null && s.isNotEmpty).join(", ");

          setState(() {
            _formattedAddress = cleanDisplayAddress;
            _addressDetails = components;
            _searchController.text = cleanDisplayAddress;
            _lastGeocodedLat = lat;
            _lastGeocodedLng = lng;
          });
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  Map<String, String> _extractAddressComponents(List<dynamic> components) {
    String getComponent(String type) {
      final comp = components.firstWhere(
        (c) => (c['types'] as List).contains(type),
        orElse: () => null,
      );
      return comp != null ? comp['long_name']?.toString() ?? '' : '';
    }

    final pincode = getComponent('postal_code');
    final country = getComponent('country');
    final state = getComponent('administrative_area_level_1');
    final locality = getComponent('locality');
    final tehsil = getComponent('administrative_area_level_3');
    final division = getComponent('administrative_area_level_2');

    final district = division
        .replaceAll(RegExp(r'\s*Division', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*District', caseSensitive: false), '')
        .trim();

    final city = locality.isNotEmpty
        ? locality
        : (district.isNotEmpty ? district : tehsil);

    final sublocality = getComponent('sublocality_level_1');
    final sublocality2 = getComponent('sublocality');
    final neighborhood = getComponent('neighborhood');
    final route = getComponent('route');

    final area = sublocality.isNotEmpty
        ? sublocality
        : (sublocality2.isNotEmpty
            ? sublocality2
            : (neighborhood.isNotEmpty
                ? neighborhood
                : (route.isNotEmpty ? route : locality)));

    return {
      'pincode': pincode,
      'country': country,
      'state': state,
      'city': city,
      'area': area,
    };
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }

    try {
      final uri = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&types=geocode&components=country:in&key=$_googleApiKey",
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _suggestions = data['predictions'] as List? ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Autocomplete suggestions error: $e');
    }
  }

  Future<void> _selectSuggestion(String placeId) async {
    setState(() {
      _suggestions = [];
      FocusScope.of(context).unfocus();
    });

    try {
      final uri = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleApiKey",
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' &&
            data['result']?['geometry']?['location'] != null) {
          final location = data['result']['geometry']['location'];
          final double lat = location['lat'] as double;
          final double lng = location['lng'] as double;
          _updateMapPosition(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('Place details error: $e');
    }
  }

  Future<void> _handleConfirmLocation() async {
    final pincode = _addressDetails['pincode'];
    if (pincode == null || pincode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pincode is missing. Please select a valid location.'),
        ),
      );
      return;
    }

    setState(() => _isCheckingService = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('latitude', _currentPosition.latitude.toString());
      await prefs.setString('longitude', _currentPosition.longitude.toString());

      final uri = Uri.parse(
        "https://welfogapi.welfog.com/api/v2/pincode/info?pincode=$pincode",
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['result'] == true) {
          await prefs.setString('pincodestatus', 'true');

          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.addAddressDetails,
              arguments: {
                'mode': widget.isEdit ? 'edit' : 'add',
                'id': widget.editAddressId,
                'name': widget.editName,
                'phone': widget.editPhone,
                'addressDetails': widget.editAddressDetails,
                'address': _formattedAddress,
                'city':
                    resData['data']?['city'] ?? _addressDetails['city'] ?? '',
                'state':
                    resData['data']?['state'] ?? _addressDetails['state'] ?? '',
                'pincode': pincode,
                'country': resData['data']?['country'] ??
                    _addressDetails['country'] ??
                    '',
              },
            );
          }
        } else {
          await prefs.setString('pincodestatus', 'false');
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Service Unavailable 📍'),
                content: const Text(
                  'Sorry, we do not deliver to this location currently.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error confirming location: $e');
    } finally {
      if (mounted) setState(() => _isCheckingService = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Native Google Map View
            if (!_mapLoading)
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 17,
                  ),
                  minMaxZoomPreference: const MinMaxZoomPreference(15, 20),
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onCameraMoveStarted: () {
                    setState(() {
                      _isMapMoving = true;
                    });
                  },
                  onCameraIdle: () {
                    setState(() {
                      _isMapMoving = false;
                    });
                    _reverseGeocode(
                      _currentPosition.latitude,
                      _currentPosition.longitude,
                    );
                  },
                  onCameraMove: (position) {
                    _currentPosition = position.target;
                    if (!_isMapMoving) {
                      setState(() {
                        _isMapMoving = true;
                      });
                    }
                  },
                ),
              )
            else
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                ),
              ),

            // Pin marker overlay in center of map
            if (!_mapLoading)
              const Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 36.0),
                  child: Icon(
                    Icons.location_pin,
                    color: Color(0xFF0F766E),
                    size: 40,
                  ),
                ),
              ),

            // Top Search Bar
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (text) => _fetchSuggestions(text),
                      decoration: InputDecoration(
                        hintText: "Search for locality, street...",
                        prefixIcon: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black87,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchSuggestions("");
                                },
                              )
                            : const Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  // Autocomplete suggestions list
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (ctx, index) {
                          final suggestion = _suggestions[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFF0F766E),
                            ),
                            title: Text(
                              suggestion['description'] ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                            onTap: () =>
                                _selectSuggestion(suggestion['place_id'] ?? ''),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Detect current location FAB
            if (!_mapLoading)
              Positioned(
                bottom: 180,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F766E),
                  onPressed: () => _detectCurrentLocation(forceGPS: true),
                  child: const Icon(Icons.my_location),
                ),
              ),

            // Bottom Confirmation Card
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_pin,
                          color: Color(0xFF0F766E),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Select Location",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        if (_isMapMoving || _isGeocoding || _isFetchingGPS)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formattedAddress,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 1,
                        ),
                        onPressed: (_isMapMoving ||
                                _isGeocoding ||
                                _isFetchingGPS ||
                                _isCheckingService)
                            ? null
                            : _handleConfirmLocation,
                        child: _isCheckingService
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                "Confirm Location",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
