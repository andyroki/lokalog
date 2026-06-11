import 'dart:convert';

import 'package:http/http.dart' as http;

import '../widgets/add_location_sheet.dart';
import '../models/lokalog_models.dart';

class GeocodePoint {
  GeocodePoint({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class LocationGeocodingService {
  static Future<GeocodePoint?> lookupCoordinates(AddLocationInput input) async {
    final String query =
        '${input.street.trim()}, ${input.city.trim()}, ${input.state.trim()} ${input.zip.trim()}, USA';
    final Uri uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{
        'q': query,
        'format': 'json',
        'limit': '1',
      },
    );

    try {
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{
          'User-Agent': 'lokalog-app/1.0 (mobile field logging demo)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! List<dynamic> || decoded.isEmpty) {
        return null;
      }

      final dynamic first = decoded.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }

      final double? lat = double.tryParse(first['lat']?.toString() ?? '');
      final double? lng = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lng == null) {
        return null;
      }

      return GeocodePoint(lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }

  static Future<AddLocationInput?> reverseLookupAddress(
    LocationFix fix, {
    required int defaultRequiredMinutes,
  }) async {
    final Uri uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      <String, String>{
        'lat': fix.lat.toString(),
        'lon': fix.lng.toString(),
        'format': 'jsonv2',
        'addressdetails': '1',
      },
    );

    try {
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{
          'User-Agent': 'lokalog-app/1.0 (mobile field logging demo)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final dynamic addressRaw = decoded['address'];
      if (addressRaw is! Map<String, dynamic>) {
        return null;
      }

      final String houseNumber =
          (addressRaw['house_number'] ?? '').toString().trim();
      final String road = ((addressRaw['road'] ??
                  addressRaw['pedestrian'] ??
                  addressRaw['footway'] ??
                  addressRaw['path'] ??
                  addressRaw['residential'] ??
                  '')
              .toString())
          .trim();
      final String street =
          [houseNumber, road].where((String part) => part.isNotEmpty).join(' ');

      final String city = ((addressRaw['city'] ??
                  addressRaw['town'] ??
                  addressRaw['village'] ??
                  addressRaw['hamlet'] ??
                  addressRaw['county'] ??
                  '')
              .toString())
          .trim();

      final String stateCode =
          (addressRaw['state_code'] ?? '').toString().trim().toUpperCase();
      final String stateName = ((addressRaw['state'] ??
                addressRaw['region'] ??
                addressRaw['state_district'] ??
                addressRaw['province'] ??
                '')
            .toString())
          .trim()
          .toUpperCase();
      final String isoStateCode = ((addressRaw['ISO3166-2-lvl4'] ??
                addressRaw['ISO3166-2-lvl5'] ??
                addressRaw['ISO3166-2-lvl6'] ??
                addressRaw['ISO3166-2-lvl7'] ??
                addressRaw['ISO3166-2-lvl8'] ??
                '')
            .toString())
          .trim()
          .toUpperCase();
      String state =
          stateCode.contains('-') ? stateCode.split('-').last : stateCode;
      if (state.isEmpty && isoStateCode.isNotEmpty) {
        state = isoStateCode.contains('-')
            ? isoStateCode.split('-').last
            : isoStateCode;
      }
      if (state.isEmpty) {
        const Map<String, String> usStateCodes = <String, String>{
          'ALABAMA': 'AL',
          'ALASKA': 'AK',
          'ARIZONA': 'AZ',
          'ARKANSAS': 'AR',
          'CALIFORNIA': 'CA',
          'COLORADO': 'CO',
          'CONNECTICUT': 'CT',
          'DELAWARE': 'DE',
          'FLORIDA': 'FL',
          'GEORGIA': 'GA',
          'HAWAII': 'HI',
          'IDAHO': 'ID',
          'ILLINOIS': 'IL',
          'INDIANA': 'IN',
          'IOWA': 'IA',
          'KANSAS': 'KS',
          'KENTUCKY': 'KY',
          'LOUISIANA': 'LA',
          'MAINE': 'ME',
          'MARYLAND': 'MD',
          'MASSACHUSETTS': 'MA',
          'MICHIGAN': 'MI',
          'MINNESOTA': 'MN',
          'MISSISSIPPI': 'MS',
          'MISSOURI': 'MO',
          'MONTANA': 'MT',
          'NEBRASKA': 'NE',
          'NEVADA': 'NV',
          'NEW HAMPSHIRE': 'NH',
          'NEW JERSEY': 'NJ',
          'NEW MEXICO': 'NM',
          'NEW YORK': 'NY',
          'NORTH CAROLINA': 'NC',
          'NORTH DAKOTA': 'ND',
          'OHIO': 'OH',
          'OKLAHOMA': 'OK',
          'OREGON': 'OR',
          'PENNSYLVANIA': 'PA',
          'RHODE ISLAND': 'RI',
          'SOUTH CAROLINA': 'SC',
          'SOUTH DAKOTA': 'SD',
          'TENNESSEE': 'TN',
          'TEXAS': 'TX',
          'UTAH': 'UT',
          'VERMONT': 'VT',
          'VIRGINIA': 'VA',
          'WASHINGTON': 'WA',
          'WEST VIRGINIA': 'WV',
          'WISCONSIN': 'WI',
          'WYOMING': 'WY',
          'DISTRICT OF COLUMBIA': 'DC',
        };
        state = usStateCodes[stateName] ??
            (stateName.length == 2
                ? stateName
                : (stateName.isNotEmpty ? stateName : ''));
      }
      final String zip = (addressRaw['postcode'] ?? '').toString().trim();

      if (street.isEmpty && city.isEmpty && state.isEmpty && zip.isEmpty) {
        return null;
      }

      return AddLocationInput(
        name: '',
        street: street,
        city: city,
        state: state,
        zip: zip,
        requiredMinutes: defaultRequiredMinutes,
      );
    } catch (_) {
      return null;
    }
  }
}
